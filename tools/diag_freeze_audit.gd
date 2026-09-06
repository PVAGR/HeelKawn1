extends SceneTree

## Frozen-pawn audit (day-41 200x freeze reproduction).
##
## Boots Main, loads the mature autosave (fenced, hash-safe), runs at a chosen
## speed (default 200x, override with --speed N), and samples every WINDOW_SEC
## real seconds:
##   - day / compat tick / SimulationClock target / committed / lag
##   - scheduler pending phase + accumulator backlog
##   - living pawn count + # whose tile_pos changed since last window
##   - per-state histogram
##   - jobs open/claimed/completed
##   - pawns with non-empty path whose path_index advanced
##   - pawns "stuck" (non-empty path, same tile for >= STUCK_WINDOWS windows)
##
## Detects a TRUE freeze: calendar/clock advances a meaningful window while ZERO
## living pawns change tile, state, path index, or decision deadline.
##
## args:
##   --speed 50|100|200       (default 200)
##   --target-day 45          (default 45)
##   --window 5               (default 5 real seconds)
##   --switch-to-1x           after reaching target day, switch to 1x and sample
##                            one more window to prove pawns resume (with a small
##                            dwell first)
##
## NOTE: --script tools cannot reference autoloads/class_name at parse time; all
## resolution is via /root lookups + .get()/.call().

const SAVE_PATH := "user://heelkawn_colony_autosave.sav"
const TICKS_PER_DAY := 600
const STATE_NAMES := [
	"IDLE", "WAKE", "WORK", "SOCIAL", "SLEEP", "WALKING_TO_JOB", "WORKING",
	"HAULING", "GOING_TO_EAT", "EATING", "SLEEPING", "FETCHING_MATERIAL",
	"GOING_TO_BED", "TEACHING", "CHALLENGE", "DRAFT_WALK", "GATHERING",
	"CRAFTING", "FLEEING", "HIDING", "PILGRIMAGE", "DIRECT_FORAGING",
	"GOING_TO_DRINK", "MOUNTING", "RIDING", "DISEMBARKING", "GOING_TO_BOAT",
	"SAILING", "DISEMBARKING_BOAT",
]
const FRAME_CAP := 4000000
const WALL_BUDGET_US := 4_100_000_000_000

var _frame := 0
var _phase := "boot"
var _printed := false
var _wall0 := 0
var _saved_tick := 0

var _gm: Node = null
var _main: Node = null
var _world: Node = null
var _spawner: Node = null

var _speed := 200.0
var _target_day := 45
var _window_sec := 5.0
var _switch_to_1x := false

var _last_sample_wall_us := 0
var _window := 0
var _prev: Dictionary = {}  # pawn_id -> {tile_x, tile_y, state, path_idx, dec}
var _stuck: Dictionary = {} # pawn_id -> windows stuck with a path

## Scheduler/lag last values for one-line windows. Guarded by what tick # this
## window's frames actually processed (some ticks span frames).
var _last_clock_target := 0.0
var _last_clock_committed := 0.0
var _last_backlog := 0.0
var _last_phase := -1
var _cur_tick := -1
var _cur_day := -1

func _al(name: String) -> Node:
	return root.get_node_or_null("/root/" + name)

func _tick() -> int:
	if _gm != null:
		return int(_gm.get("tick_count"))
	return -1

func _jk(obj, key: String, default: Variant) -> Variant:
	if obj == null or not ("get" in obj):
		return default
	var v = obj.get(key)
	if v == null:
		return default
	return v

func _initialize() -> void:
	_collect_args()
	call_deferred("_spawn_main")

func _collect_args() -> void:
	var user := OS.get_cmdline_user_args()
	for i in range(user.size()):
		var a: String = user[i]
		var val: String = ""
		var has_eq := a.contains("=")
		if has_eq:
			var parts := a.split("=")
			val = parts[1]
			a = parts[0]
		elif i + 1 < user.size() and not user[i + 1].begins_with("--"):
			val = user[i + 1]
		if a == "--speed":
			_speed = float(val)
		elif a == "--target-day":
			_target_day = int(val)
		elif a == "--window":
			_window_sec = float(val)
		elif a == "--switch-to-1x":
			_switch_to_1x = true

func _spawn_main() -> void:
	if not OS.get_cmdline_user_args().has("--playtest-no-save"):
		push_error("FREEZE: must run with --playtest-no-save (loads+advances production autosave); refusing")
		quit(1)
		return
	var packed: PackedScene = load("res://scenes/main/Main.tscn") as PackedScene
	if packed == null:
		push_error("FREEZE: cannot load Main.tscn")
		quit(1)
		return
	var main: Node = packed.instantiate()
	root.add_child(main)
	if not bool(main.get("_save_writes_disabled_for_playtest")):
		push_error("FREEZE: autosave fence not active; refusing")
		quit(1)

func _process(_delta: float) -> bool:
	if _printed:
		return false
	_frame += 1
	if _frame == 1:
		_wall0 = Time.get_ticks_usec()
		_last_sample_wall_us = _wall0
	if _gm == null:
		_gm = _al("GameManager")
	if _gm == null:
		return false
	var used: int = Time.get_ticks_usec() - _wall0
	if _phase == "boot":
		_main = root.get_node_or_null("/root/Main")
		if _main == null:
			return false
		_spawner = _main.get("_pawn_spawner")
		if _spawner == null:
			return false
		_phase = "load"
		print("FREEZE: Main ready, speed=%.0fx target_day=%d window=%.1fs" % [_speed, _target_day, _window_sec])
		return false
	if _phase == "load":
		var gs: GDScript = load("res://scripts/save/GameSave.gd") as GDScript
		var d: Dictionary = gs.call("read_file", SAVE_PATH)
		if d.is_empty():
			print("FREEZE: FATAL save empty/missing")
			_printed = true
			quit(1)
			return false
		_saved_tick = int(_jk(d, "tick", -1))
		_main.call("_apply_save_dict", d)
		_phase = "run"
		if _gm.has_method("resume"):
			_gm.call("resume")
		_gm.call("set_speed", _speed)
		var target_tick: int = _saved_tick + _target_day * TICKS_PER_DAY
		print("FREEZE: loaded tick=%d day=%d -> target_tick=%d day=%d (speed %.0fx)" % [
			_saved_tick, _saved_tick / TICKS_PER_DAY, target_tick, _target_day + _saved_tick / TICKS_PER_DAY, _speed])
		# Prime prev positions.
		_capture_prev_state()
		print("FREEZE: WINDOW day tick target committed lag backlog phase moved states jobsopen stuck")
		return false
	if _phase == "run":
		_cur_tick = _tick()
		_cur_day = _cur_tick / TICKS_PER_DAY
		if _frontier_reached():
			_begin_switch_or_done()
			return false
		if used > WALL_BUDGET_US:
			print("FREEZE: wall budget expired @tick=%d day=%d" % [_cur_tick, _cur_day])
			_final_dump()
			_printed = true
			quit(0)
			return false
		if _frame > FRAME_CAP:
			print("FREEZE: frame cap expired @tick=%d day=%d" % [_cur_tick, _cur_day])
			_final_dump()
			_printed = true
			quit(0)
			return false
		var now_us: int = Time.get_ticks_usec()
		if now_us - _last_sample_wall_us >= int(_window_sec * 1000000.0):
			_last_sample_wall_us = now_us
			_window += 1
			_sample_window()
		return false
	if _phase == "dwell1x":
		# After switching to 1x, dwell briefly then sample once to prove pawns move.
		_cur_tick = _tick()
		_cur_day = _cur_tick / TICKS_PER_DAY
		var now_us: int = Time.get_ticks_usec()
		if now_us - _switch_at_wall >= int(2.0 * 1000000.0):
			_last_sample_wall_us = now_us
			_window += 1
			_sample_window()
			_phase = "done"
		return false
	if _phase == "done":
		_final_dump()
		_printed = true
		quit(0)
		return false
	return false

var _switch_at_wall := 0

func _frontier_reached() -> bool:
	return _cur_tick >= _saved_tick + _target_day * TICKS_PER_DAY

func _begin_switch_or_done() -> void:
	if _switch_to_1x:
		print("FREEZE: reached target day, switching 200x->1x")
		_gm.call("set_speed", 1.0)
		_switch_at_wall = Time.get_ticks_usec()
		_capture_prev_state()
		_phase = "dwell1x"
	else:
		# still sample the final window then dump
		var now_us: int = Time.get_ticks_usec()
		if now_us - _last_sample_wall_us >= int(_window_sec * 1000000.0):
			_last_sample_wall_us = now_us
			_window += 1
			_sample_window()
		_phase = "done"

func _capture_prev_state() -> void:
	_prev.clear()
	for p in _pawns():
		if not is_instance_valid(p):
			continue
		var pd = p.get("data")
		if pd == null:
			continue
		var tile: Vector2i = _jk(pd, "tile_pos", Vector2i(-1, -1))
		var path: Array = p.get("_path") if ("_path" in p) else []
		_prev[int(_jk(pd, "id", -1))] = {
			"tile": tile,
			"state": int(_jk(p, "_state", 0)),
			"path_idx": int(_jk(p, "_path_index", 0)),
			"has_path": not path.is_empty(),
			"dec": _decision_deadline_count(p),
		}
	_stuck.clear()

func _decision_deadline_count(p: Node) -> int:
	if p == null or not ("_discrete_due_deadlines" in p):
		return -1
	return int(p.get("_discrete_due_deadlines").size())

func _sample_window() -> void:
	var now: Dictionary = {}
	for p in _pawns():
		if not is_instance_valid(p):
			continue
		var pd = p.get("data")
		if pd == null:
			continue
		var pid: int = int(_jk(pd, "id", -1))
		var tile: Vector2i = _jk(pd, "tile_pos", Vector2i(-1, -1))
		var path: Array = p.get("_path") if ("_path" in p) else []
		now[pid] = {
			"tile": tile,
			"state": int(_jk(p, "_state", 0)),
			"path_idx": int(_jk(p, "_path_index", 0)),
			"has_path": not path.is_empty(),
			"dec": _decision_deadline_count(p),
		}
	var moved: int = 0
	var state_moved: int = 0
	var path_advanced: int = 0
	var with_path: int = 0
	var stuck: int = 0
	var states: Dictionary = {}
	var unblocked_decision_progress: int = 0
	for pid in now:
		var c: Dictionary = now[pid]
		var sname: String = _state_name(int(c["state"]))
		states[sname] = int(states.get(sname, 0)) + 1
		var pr: Dictionary = _prev.get(pid, {})
		if not pr.is_empty():
			if c["tile"] != pr.get("tile", c["tile"]):
				moved += 1
			if c["state"] != pr.get("state", c["state"]):
				state_moved += 1
			if bool(c["has_path"]):
				with_path += 1
				if int(c["path_idx"]) != int(pr.get("path_idx", c["path_idx"])):
					path_advanced += 1
				if c["tile"] == pr.get("tile", c["tile"]):
					_stuck[pid] = int(_stuck.get(pid, 0)) + 1
				else:
					_stuck[pid] = 0
				if int(_stuck.get(pid, 0)) >= 3:
					stuck += 1
			if int(c["dec"]) != int(pr.get("dec", c["dec"])):
				unblocked_decision_progress += 1
	_prev = now
	# clock/lag/backlog
	var sc = _al("SimulationClock")
	var tm = _al("TickManager")
	var target: float = float(sc.call("get_target_world_time_seconds")) if sc != null and sc.has_method("get_target_world_time_seconds") else -1.0
	var committed: float = float(sc.call("get_committed_world_time_seconds")) if sc != null and sc.has_method("get_committed_world_time_seconds") else -1.0
	var lag: float = target - committed
	var backlog: float = float(tm.get("_accumulated_time")) if tm != null else -1.0
	var phase: int = int(tm.get("_pending_phase")) if tm != null and tm.get("_pending_phase") != null else -1
	var lc: float = float(sc.call("get_lane_applied_world_time_seconds", &"legacy_core")) if sc != null and sc.has_method("get_lane_applied_world_time_seconds") else -1.0
	var pc: float = float(sc.call("get_lane_applied_world_time_seconds", &"pawn_continuous")) if sc != null and sc.has_method("get_lane_applied_world_time_seconds") else -1.0
	var pd: float = float(sc.call("get_lane_applied_world_time_seconds", &"pawn_discrete")) if sc != null and sc.has_method("get_lane_applied_world_time_seconds") else -1.0
	var jobs_open: int = 0
	var jm = _al("JobManager")
	if jm != null and jm.has_method("open_count"):
		jobs_open = int(jm.call("open_count"))
	var state_seq: String = ""
	for k in states.keys():
		state_seq += "%s=%d " % [k, states[k]]
	var day: int = _cur_day
	var tick: int = _cur_tick
	print("FREEZE: W%d day=%d tick=%d target=%.1f committed=%.1f lag=%.1f backlog=%.2f phase=%d lc=%.1f pc=%.1f pdc=%.1f moved=%d states_moved=%d path_walked=%d jobs_open=%d stuck=%d | %s| %s%ddeadline_change=%d" % [
		_window, day, tick, target, committed, lag, backlog, phase, lc, pc, pd, moved, state_moved, path_advanced, jobs_open, stuck,
		state_seq, "@", with_path, unblocked_decision_progress])
	_last_clock_target = target
	_last_clock_committed = committed
	_last_backlog = backlog
	_last_phase = phase
	# FREEZE DETECTION: clock advanced but zero movement/state/path/decision progress.
	if _window >= 2 and _prev_sample_tick >= 0:
		if _cur_tick > _prev_sample_tick:
			if moved == 0 and state_moved == 0 and path_advanced == 0 and unblocked_decision_progress == 0:
				print("FREEZE: *** DETECTED FREEZE at window %d: compat tick advanced %d ticks but ZERO pawns moved/state/path/decision ***" % [_window, _cur_tick - _prev_sample_tick])
				_dump_freeze_pawns()
				_final_dump()
				_printed = true
				quit(0)
				return
	_prev_sample_tick = _cur_tick
	_prev_committed = committed

var _prev_committed: float = -1.0
var _prev_sample_tick: int = -1

func _state_name(s: int) -> String:
	if s >= 0 and s < STATE_NAMES.size():
		return STATE_NAMES[s]
	return "S%d" % s

func _dump_freeze_pawns() -> void:
	print("FREEZE: --- per-pawn freeze snapshot ---")
	for p in _pawns():
		if not is_instance_valid(p):
			continue
		var pd = p.get("data")
		if pd == null:
			continue
		var pid: int = int(_jk(pd, "id", -1))
		var tile: Vector2i = _jk(pd, "tile_pos", Vector2i(-1, -1))
		var state: String = _state_name(int(_jk(p, "_state", 0)))
		var path: Array = p.get("_path") if ("_path" in p) else []
		var has_path: bool = not path.is_empty()
		var path_idx: int = int(_jk(p, "_path_index", -1))
		var dd_size: int = -1
		var nxt: float = -1.0
		var applied: float = -1.0
		if "_discrete_due_deadlines" in p:
			dd_size = int(p.get("_discrete_due_deadlines").size())
		if "_next_decision_world_time" in p:
			nxt = float(p.get("_next_decision_world_time"))
		if p.has_method("get_pawn_discrete_applied_through_world_time"):
			applied = float(p.call("get_pawn_discrete_applied_through_world_time"))
		var job: String = "none"
		var j = p.get("_current_job")
		if j != null:
			job = "%s" % (j.get("type") if j.get("type") != null else "?")
		var hunger: float = float(_jk(pd, "hunger", -1.0))
		var rest: float = float(_jk(pd, "rest", -1.0))
		print("FREEZE:  pawn#%d state=%s tile=%s hunger=%.0f rest=%.0f has_path=%s path_idx=%d due_q=%d nxt_t=%.2f applied=%.2f job=%s" % [
			pid, state, tile, hunger, rest, has_path, path_idx, dd_size, nxt, applied, job])
	print("FREEZE: --- /per-pawn freeze snapshot ---")

func _pawns() -> Array:
	if _spawner == null:
		return []
	return _spawner.get("pawns")

func _final_dump() -> void:
	var living: int = 0
	var by_state: Dictionary = {}
	for p in _pawns():
		if not is_instance_valid(p):
			continue
		var pd = p.get("data")
		if pd == null:
			continue
		living += 1
		var sname: String = _state_name(int(_jk(p, "_state", 0)))
		by_state[sname] = int(by_state.get(sname, 0)) + 1
	# settlements
	var sm = _al("SettlementMemory")
	var formal: int = sm.get_formal_settlements().size() if sm != null and sm.has_method("get_formal_settlements") else -1
	var proto: int = sm.get_proto_sites().size() if sm != null and sm.has_method("get_proto_sites") else -1
	var sc = _al("SimulationClock")
	var target: float = float(sc.call("get_target_world_time_seconds")) if sc != null and sc.has_method("get_target_world_time_seconds") else -1.0
	var committed: float = float(sc.call("get_committed_world_time_seconds")) if sc != null and sc.has_method("get_committed_world_time_seconds") else -1.0
	print("FREEZE: FINAL day=%d tick=%d living=%d formal=%d proto=%d target=%.1f committed=%.1f lag=%.1f" % [
		_cur_day, _cur_tick, living, formal, proto, target, committed, target - committed])
	print("FREEZE: FINAL states %s" % str(by_state))
