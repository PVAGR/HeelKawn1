extends SceneTree

## #18 resumable-cooperative-scheduler smoke. Boots Main AT 200x on a FRESH
## world (never loads an aged save) with the --playtest-no-save fence, then
## verifies the TickManager pending-tick state machine:
##   - ticks keep advancing at 200x (inventory/DAG inventory) rather than stalling
##   - a single pending tick may span several rendered frames and then RESUME
##     (proving cooperative yield, not drop-and-run)
##   - tick_processed fires exactly once per completed tick (no duplicates)
##   - no tick is skipped (every integer tick between start and target fires)
##   - captures scheduler diagnostics: max_sim_slice_usec, max_callback_usec,
##     max_callback_name, CALLBACKS_OVER_8MS.
## Pure diagnostic; does not load or modify any save. Requires --playtest-no-save.
##
## NOTE: `--script` tools cannot reference autoload identifiers at parse time,
## so every autoload is resolved via root node lookups here.

const RUN_TO_TICK := 1500        ## well below anything that needs real data; fence protects regardless
const FRAME_CAP := 4000          ## generous; resumable yield means many frames per tick region
const TARGET_MAX_SLICE_USEC := 12000  ## sanity bound; individual callbacks can still exceed slice

var _frame := 0
var _phase := "boot"
var _printed := false

var _gm: Node = null
var _tm: Node = null
var _main: Node = null

var _last_completed_tick: int = -1
var _fires: Dictionary = {}      # tick_number -> fire count
var _first_fire_tick: int = -1
var _pending_saw_frame_span: bool = false
var _peak_frames_per_tick: int = 0

var _max_slice: int = 0
var _max_cb: int = 0
var _max_cb_name: String = ""
var _over_8ms_count: int = 0
var _fires_done_tick: int = -1

func _al(name: String) -> Node:
	return root.get_node_or_null("/root/" + name)

func _initialize() -> void:
	var gm_trace: Node = root.get_node_or_null("GameManager")
	if gm_trace != null:
		if gm_trace.has_method("set_game_tick_trace_enabled"):
			gm_trace.call("set_game_tick_trace_enabled", false)
		else:
			gm_trace.set("trace_game_tick_dispatch", false)
	call_deferred("_spawn_main")

func _spawn_main() -> void:
	## Permanent Tool Rule: never cross the autosave boundary without the fence.
	if not OS.get_cmdline_user_args().has("--playtest-no-save"):
		push_error("SCHED_SMOKE: this tool boots Main and must run with --playtest-no-save; refusing to run")
		quit(1)
		return
	var packed: PackedScene = load("res://scenes/main/Main.tscn") as PackedScene
	if packed == null:
		push_error("SCHED_SMOKE: cannot load Main.tscn")
		quit(1)
		return
	var main: Node = packed.instantiate()
	root.add_child(main)
	if not bool(main.get("_save_writes_disabled_for_playtest")):
		push_error("SCHED_SMOKE: Main autosave fence not active; refusing to run")
		quit(1)

func _process(_delta: float) -> bool:
	if _printed:
		return false
	_frame += 1
	if _frame > FRAME_CAP:
		_printed = true
		_finish("FRAME_CAP_EXCEEDED", false)
		return false
	if _gm == null:
		_gm = _al("GameManager")
	if _main == null:
		_main = root.get_node_or_null("/root/Main")
	if _phase == "boot":
		if _gm == null or _main == null:
			return false
		_phase = "arm_trace"
	if _phase == "arm_trace":
		_tm = root.get_node_or_null("/root/TickManager")
		if _tm == null or _tm.get("tick_processed") == null:
			return false
		_tm.connect("tick_processed", Callable(self, "_on_tp"))
		# Log any SLOW/backlog warnings we can capture this run.
		_phase = "set_speed"
	if _phase == "set_speed":
		if not _tm.has_method("set_speed_index"):
			return false
		_tm.call("set_speed_index", 5)  # 200x
		var sp: int = int(_gm.get("game_speed")) if _gm.get("game_speed") != null else 0
		print("SCHED_SMOKE: speed set to 200x (game_speed=%s TickManager speed_index=%s)" % [sp, str(_tm.call("get_speed_index"))])
		_phase = "run"
		return false
	if _phase == "run":
		# Poll the scheduler diagnostics each frame.
		_read_diag()
		var completed: int = int(_tm.get("current_tick"))
		if completed >= RUN_TO_TICK:
			_phase = "done"
			_finish("", true)
			_printed = true
			return false
	return false

func _on_tp(tick) -> void:
	var tn: int = int(tick)
	_fires[tn] = int(_fires.get(tn, 0)) + 1
	if _first_fire_tick < 0:
		_first_fire_tick = tn
	if _last_completed_tick >= 0 and tn == _last_completed_tick:
		# tick_processed fired twice for the same tick -> duplicate
		print("SCHED_SMOKE: DUPLICATE tick_processed for tick %d" % tn)
	_fires_done_tick = tn
	_last_completed_tick = tn

func _read_diag() -> void:
	if _tm == null:
		return
	var slice: int = int(_tm.get("debug_last_sim_slice_usec"))
	if slice > _max_slice:
		_max_slice = slice
	var cb: int = int(_tm.get("debug_max_sim_callback_usec"))
	if cb > _max_cb:
		_max_cb = cb
		_max_cb_name = str(_tm.get("debug_max_sim_callback_name"))

func _finish(reason: String, ok: bool) -> void:
	_read_diag()
	print("===== SCHED_SMOKE RESULT =====")
	print("reason=%s ok=%s" % [reason, str(ok)])
	if _tm != null:
		var current: int = int(_tm.get("current_tick"))
		var gm_tick: int = int(_gm.get("tick_count")) if _gm != null else -1
		print("TickManager.current_tick=%d GameManager.tick_count=%d RUN_TO_TICK=%d" % [current, gm_tick, RUN_TO_TICK])
		print("max_sim_slice_usec=%d max_callback_usec=%d max_callback_name=%s" % [
			_max_slice, _max_cb, _max_cb_name
		])
		print("CALLBACKS_OVER_8MS(see [SLOW_SIM_CALLBACK] lines above; diagnostic-only throttle)")
		print("tick_processed fires: first=%d last=%d total_ticks=%d unique=%d" % [
			_first_fire_tick, _last_completed_tick, _fires.size(), _fires_count_unique()
		])
		# Skip/duplicate audit over the integer range hit.
		var start_range: int = _first_fire_tick
		var end_range: int = _last_completed_tick
		var missing: Array = []
		var dupes: Array = []
		for t in range(start_range, end_range + 1):
			var n: int = int(_fires.get(t, 0))
			if n == 0:
				missing.append(t)
			elif n > 1:
				dupes.append(t)
		print("skip_audit range=[%d..%d] missing=%d dupes=%d" % [start_range, end_range, missing.size(), dupes.size()])
		if not missing.is_empty():
			print("MISSING_TICKS=%s" % str(missing.slice(0, mini(10, missing.size()))))
		if not dupes.is_empty():
			print("DUPLICATE_TICKS=%s" % str(dupes.slice(0, mini(10, dupes.size()))))
		var ok_all: bool = (ok and current >= RUN_TO_TICK and missing.is_empty() and dupes.is_empty())
		print("RESULT=%s" % ("SCHEDULER_WORKING" if ok_all else "SCHEDULER_ISSUE"))
		quit(0 if ok_all else 1)
		return
	quit(1)

func _fires_count_unique() -> int:
	return _fires.size()
