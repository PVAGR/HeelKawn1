extends SceneTree

## Headless performance smoothness probe.
## Run: Godot --headless --path . -s res://tools/sim_performance_smoothness_smoke.gd
##
## Measures tick throughput, event accumulation, and recompute pressure
## at both 1x and 100x speeds. Reports whether the simulation can sustain
## smooth tick flow without frame budget overruns or event backlog.
##
## No mutation of WorldMemory / SettlementMemory. Observation only.

const TICKS_1X: int = 50          # ~50 seconds at 1x
const TICKS_100X: int = 2000     # reach first recompute boundary
const TIMEOUT_FRAMES_1X: int = 600
const TIMEOUT_FRAMES_100X: int = 18000

var _phase: String = "idle"  # idle, 1x, 100x, done
var _frame_count: int = 0
var _tick_start: int = 0
var _tick_end: int = 0
var _events_start: int = 0
var _events_end: int = 0
var _max_ticks_in_frame: int = 0
var _total_ticks_in_phase: int = 0
var _frames_in_phase: int = 0
var _main_spawned: bool = false
var _boot_wait_frames: int = 0


func _process(_delta: float) -> bool:
	# Boot wait: count frames after Main spawned before starting measurement
	if _boot_wait_frames > 0:
		_boot_wait_frames -= 1
		if _boot_wait_frames == 0:
			_begin_phase_1x()
		return false

	if _phase == "idle":
		return false

	if _phase == "done":
		return false

	_frame_count += 1
	_frames_in_phase += 1

	var gm: Node = root.get_node_or_null("GameManager")
	if gm == null:
		return false

	var tick: int = gm.get("tick_count")
	var tm: Node = root.get_node_or_null("TickManager")
	var last_frame_ticks: int = 0
	if tm != null:
		var raw_last_frame_ticks: Variant = tm.get("_last_frame_ticks")
		if raw_last_frame_ticks is int:
			last_frame_ticks = raw_last_frame_ticks
	if last_frame_ticks > _max_ticks_in_frame:
		_max_ticks_in_frame = last_frame_ticks
	_total_ticks_in_phase += last_frame_ticks

	# Check timeout
	var timeout: int = TIMEOUT_FRAMES_1X if _phase == "1x" else TIMEOUT_FRAMES_100X
	if _frames_in_phase > timeout:
		print("[PERF_SMOOTHNESS_FAIL] phase=%s reason=frame_limit_exceeded tick=%d frames=%d" % [
			_phase, tick, _frames_in_phase
		])
		_phase = "done"
		quit(1)
		return true

	# Check phase completion
	if _phase == "1x" and tick >= _tick_start + TICKS_1X:
		_end_phase("1x", tick)
		_begin_phase_100x(tick)
		return false

	if _phase == "100x" and tick >= _tick_start + TICKS_100X:
		_end_phase("100x", tick)
		_report_final()
		_phase = "done"
		quit(0)
		return true

	return false


func _enter_tree() -> void:
	# Pause GameManager before spawning Main
	var gm_hold: Node = root.get_node_or_null("GameManager")
	if gm_hold != null and gm_hold.has_method("pause"):
		gm_hold.call("pause")
	call_deferred("_spawn_main")


func _spawn_main() -> void:
	var packed: PackedScene = load("res://scenes/main/Main.tscn") as PackedScene
	if packed == null:
		print("[PERF_SMOOTHNESS_FAIL] reason=Main_load_failed")
		quit(1)
		return
	var main: Node = packed.instantiate()
	root.add_child(main)
	# Resume TickManager (set_speed in Main._ready unpauses GameManager but not TickManager)
	var tm: Node = root.get_node_or_null("TickManager")
	if tm != null and tm.has_method("resume"):
		tm.call("resume")
	var gm: Node = root.get_node_or_null("GameManager")
	if gm != null and gm.has_method("resume"):
		gm.call("resume")
	_main_spawned = true
	# Wait a few frames for boot to settle, then begin 1x phase
	# (SceneTree scripts don't have get_tree(); use a frame counter instead)
	_boot_wait_frames = 30


func _begin_phase_1x() -> void:
	var gm: Node = root.get_node_or_null("GameManager")
	var tm: Node = root.get_node_or_null("TickManager")
	if gm != null:
		_tick_start = gm.get("tick_count")
	if tm != null and tm.has_method("set_speed"):
		tm.call("set_speed", 1.0)
	var wmem: Node = root.get_node_or_null("WorldMemory")
	if wmem != null and wmem.has_method("event_count"):
		_events_start = wmem.call("event_count")
	_max_ticks_in_frame = 0
	_total_ticks_in_phase = 0
	_frames_in_phase = 0
	_phase = "1x"
	print("[PERF_SMOOTHNESS] START")


func _begin_phase_100x(tick: int) -> void:
	var tm: Node = root.get_node_or_null("TickManager")
	var gm: Node = root.get_node_or_null("GameManager")
	if gm != null:
		_tick_start = gm.get("tick_count")
	if tm != null and tm.has_method("set_speed"):
		tm.call("set_speed", 100.0)
	var wmem: Node = root.get_node_or_null("WorldMemory")
	if wmem != null and wmem.has_method("event_count"):
		_events_start = wmem.call("event_count")
	_max_ticks_in_frame = 0
	_total_ticks_in_phase = 0
	_frames_in_phase = 0
	_phase = "100x"


func _end_phase(label: String, tick: int) -> void:
	var wmem: Node = root.get_node_or_null("WorldMemory")
	_events_end = wmem.call("event_count") if wmem != null and wmem.has_method("event_count") else 0
	_tick_end = tick
	var events_delta: int = _events_end - _events_start
	var avg_ticks_per_frame: float = float(_total_ticks_in_phase) / max(_frames_in_phase, 1)

	print("[PERF_SMOOTHNESS] speed=%s tick_start=%d tick_end=%d frames=%d events_delta=%d max_ticks_per_frame=%d avg_ticks_per_frame=%.1f" % [
		label, _tick_start, _tick_end, _frames_in_phase, events_delta, _max_ticks_in_frame, avg_ticks_per_frame
	])


func _report_final() -> void:
	# Check TickManager/Gamanager consistency
	var gm: Node = root.get_node_or_null("GameManager")
	var tm: Node = root.get_node_or_null("TickManager")
	var gm_tick: int = gm.get("tick_count") if gm != null else -1
	var tm_tick: int = tm.get("current_tick") if tm != null else -1
	var gm_paused: bool = bool(gm.get("is_paused")) if gm != null else true
	var tm_paused: bool = bool(tm.get("_is_paused")) if tm != null else true

	var consistency: String = "ok" if gm_tick == tm_tick and not gm_paused and not tm_paused else "MISMATCH"
	if gm_tick != tm_tick:
		consistency = "tick_desync gm=%d tm=%d" % [gm_tick, tm_tick]
	elif gm_paused or tm_paused:
		consistency = "paused gm=%s tm=%s" % [str(gm_paused), str(tm_paused)]

	# Event count
	var wmem: Node = root.get_node_or_null("WorldMemory")
	var event_count: int = wmem.call("event_count") if wmem != null and wmem.has_method("event_count") else 0

	# WorldMeaning region count
	var wm: Node = root.get_node_or_null("WorldMeaning")
	var region_count: int = 0
	if wm != null:
		var raw: Variant = wm.get("meaning_by_region")
		if raw is Dictionary:
			region_count = (raw as Dictionary).size()

	print("[PERF_SMOOTHNESS] final_tick=%d events=%d meaning_regions=%d consistency=%s" % [
		gm_tick, event_count, region_count, consistency
	])
	print("[PERF_SMOOTHNESS_PASS] smoothness_probe_complete")
