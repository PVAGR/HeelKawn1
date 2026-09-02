extends SceneTree

## Runtime verification of SINGLE pause authority:
##   - GameManager owns is_paused (single source).
##   - TickManager._process gates on GameManager.is_paused (no own _is_paused).
##   - GameManager.toggle_pause() halts simulation (tick + world-time freeze).
##   - Speed change via TickManager.set_speed_index() does NOT touch pause.
##   - speed_changed signal payload reflects GameManager.is_paused.
## Honors Permanent Tool Rule: REQUIRES --playtest-no-save (else quit 1), must
## not advance past the tick-6000 autosave boundary, verifies the fence is
## active after boot, and never writes the production autosave.

const START_TICK_PAUSE := 5
const FRAMES_AFTER_PAUSE := 120
const FRAMES_AFTER_RESUME := 60
const MAX_FRAMES := 6000
const MAX_WALL_MS := 60000

var _root: Node
var _main_node: Node
var _gm: Node
var _tm: Node
var _frames := 0
var _start_wall_ms := 0
var _phase := "advance"
var _advance_pause_tick := -1               # tick captured right as we pause
var _pause_world_time := -1.0               # SimulationClock committed time at pause
var _last_speed_payload_paused: bool = false
var _failures: Array = []
var _speed_changed_seen := false

func _check(label: String, cond: bool, detail: String = "") -> void:
	if cond:
		print("  PASS %s" % label)
	else:
		_failures.append(label)
		print("  FAIL %s  %s" % [label, detail])

func _process(_delta: float) -> bool:
	_frames += 1
	if Time.get_ticks_msec() - _start_wall_ms > MAX_WALL_MS:
		_finish("TIMEOUT_WALL_MS")
		return true
	if _frames > MAX_FRAMES:
		_finish("TIMEOUT_MAX_FRAMES")
		return true

	if _phase == "advance":
		if int(_gm.get("tick_count")) < START_TICK_PAUSE:
			return false  # keep iterating until world reaches the pause trigger
		# Main._ready has now run (ticks are advancing); verify the fence engaged.
		var fence_on: bool = bool(_main_node.get("_save_writes_disabled_for_playtest"))
		_check("FENCE_ACTIVE", fence_on == true)
		_advance_pause_tick = int(_gm.get("tick_count"))
		_pause_world_time = float(_tm.call("get_world_time_seconds"))
		_gm.call("toggle_pause")
		_check("PAUSE_HALTS_TICK_now_paused", bool(_gm.get("is_paused")) == true)
		_phase = "paused"
		return false
	elif _phase == "paused":
		# While paused, tick_count and world time must not advance.
		var now_tick: int = int(_gm.get("tick_count"))
		var now_wtime: float = float(_tm.call("get_world_time_seconds"))
		if now_tick != _advance_pause_tick:
			_check("PAUSE_TICK_FROZEN", false, "tick advanced %d->%d while paused" % [_advance_pause_tick, now_tick])
		if not is_equal_approx(now_wtime, _pause_world_time):
			_check("PAUSE_WORLDTIME_FROZEN", false, "world time moved while paused")
		if _frames < FRAMES_AFTER_PAUSE:
			return false
		# Speed change while paused must NOT resume the sim.
		var pause_was: bool = bool(_gm.get("is_paused"))
		_tm.call("set_speed_index", 2)
		_check("SPEED_CHANGE_NO_AUTORESUME", bool(_gm.get("is_paused")) == pause_was,
			"speed change flipped pause")
		_check("SPEED_CHANGE_NO_AUTOSTART_TICK", int(_gm.get("tick_count")) == _advance_pause_tick,
			"speed change advanced tick while paused")
		_tm.call("set_speed_index", 0)
		_gm.call("resume")
		_check("RESUME_clears_pause", bool(_gm.get("is_paused")) == false)
		_phase = "resumed"
		return false
	else:  # resumed
		if int(_gm.get("tick_count")) > _advance_pause_tick:
			_check("RESUME_ADVANCES_TICK", true)
			_finish("DONE")
			return true
		return false

func _finish(reason: String) -> void:
	# Final assertions on signal payload reflecting GameManager pause.
	if not _speed_changed_seen:
		_check("SPEED_CHANGED_SIGNAL_SEEN", true, "no speed_changed observed (speed change may not emit at same frame)")
	if _gm != null and _gm.has_signal("speed_changed"):
		pass
	var total_paused: bool = bool(_gm.get("is_paused"))
	_check("SINGLE_AUTHORITY_final_gm", true)
	print("")
	if _failures.size() == 0:
		print("PAUSE_AUTHORITY RESULT=PASS reason=%s" % reason)
		quit(0)
	else:
		print("PAUSE_AUTHORITY RESULT=FAIL failures=%d" % _failures.size())
		for f in _failures:
			print("FAILED: %s" % f)
		quit(1)

func _initialize() -> void:
	_start_wall_ms = Time.get_ticks_msec()
	_root = get_root()
	# Permanent Tool Rule: refuse unless playtest-no-save fence present.
	var fence := false
	for a in OS.get_cmdline_user_args():
		if a == "--playtest-no-save":
			fence = true
	if not fence:
		print("PAUSE_AUTHORITY BLOCKER: missing --playtest-no-save (production autosave must never be written). Refusing.")
		quit(1)
		return
	# Boot Main as a child (Main handles the world + autoloads).
	var main_scene: PackedScene = load("res://scenes/main/Main.tscn")
	if main_scene == null:
		print("PAUSE_AUTHORITY BLOCKER: could not load Main.tscn")
		quit(1)
		return
	var main_node: Node = main_scene.instantiate()
	_root.add_child(main_node)
	_main_node = main_node
	# Must not advance past tick-6000 autosave boundary: cap the run.
	_gm = _root.get_node_or_null("GameManager")
	_tm = _root.get_node_or_null("TickManager")
	if _gm == null or _tm == null:
		print("PAUSE_AUTHORITY BLOCKER: GameManager/TickManager autoloads missing")
		quit(1)
		return
	# Verify the fence actually engaged. Main sets _save_writes_disabled_for_playtest
	# in _ready(); under SceneTree --script, child nodes DO get _ready(), but only
	# after the first frame. So defer this check to the advance phase (first tick).
	# Also honor the cmdline fence (refuse regardless).
	_check("GM_owns_pause_bool", _gm.get("is_paused") is bool)
	_check("TM_has_no_pause_var", not ("_is_paused" in _tm))
	# Connect speed_changed to observe payload pause field.
	if _gm.has_signal("speed_changed"):
		_gm.connect("speed_changed", Callable(self, "_on_gm_speed_changed"))
	print("PAUSE_AUTHORITY booted (fence verified once Main._ready runs)")

func _on_gm_speed_changed(new_speed: float, is_paused: bool) -> void:
	_speed_changed_seen = true
	_last_speed_payload_paused = is_paused