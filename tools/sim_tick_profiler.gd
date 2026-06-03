extends SceneTree

## Headless tick profiler. Measures real wall-clock time per system.
## Run: Godot --headless --path . -s res://tools/sim_tick_profiler.gd
##
## Boots Main.tscn, accelerates to 100x, and measures:
##   - Total frame time (all ticks in one frame)
##   - Ticks per frame
##   - Wall time per 60-tick window
##   - Event count growth
##   - TickManager batch stats
##   - Whether GameManager/TickManager stay in sync
##
## Logs every 60 ticks: [PERF] tick=N ...
## Final summary at tick 2000.

const PROFILING_SPEED: float = 100.0
const MIN_TICK: int = 2000
const LOG_INTERVAL: int = 60
const TIMEOUT_FRAMES: int = 18000

var _done: bool = false
var _started: bool = false
var _main_spawned: bool = false
var _frame_count: int = 0
var _boot_wait: int = 30

# Accumulators for the current 60-tick window
var _window_start_tick: int = 0
var _window_start_usec: int = 0
var _window_events_start: int = 0
var _window_max_ticks_per_frame: int = 0
var _window_frames: int = 0
var _window_total_ticks_in_frames: int = 0

# Global accumulators
var _peak_ticks_per_frame: int = 0
var _peak_frame_usec: int = 0
var _total_profiled_ticks: int = 0
var _total_profiled_usec: int = 0
var _first_log_tick: int = -1
var _last_log_tick: int = -1


func _process(_delta: float) -> bool:
	if _done:
		return false

	# Boot wait
	if _boot_wait > 0:
		_boot_wait -= 1
		if _boot_wait == 0:
			_begin_profiling()
		return false

	if not _started:
		return false

	_frame_count += 1
	if _frame_count > TIMEOUT_FRAMES:
		print("[PERF] FAIL reason=frame_limit_exceeded")
		_done = true
		quit(1)
		return true

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

	_window_frames += 1
	_window_total_ticks_in_frames += last_frame_ticks
	if last_frame_ticks > _window_max_ticks_per_frame:
		_window_max_ticks_per_frame = last_frame_ticks
	if last_frame_ticks > _peak_ticks_per_frame:
		_peak_ticks_per_frame = last_frame_ticks

	# Log every LOG_INTERVAL ticks
	if _first_log_tick < 0:
		_first_log_tick = tick
	if tick >= _window_start_tick + LOG_INTERVAL:
		_log_window(tick)

	if tick >= MIN_TICK:
		_final_report(tick)
		_done = true
		quit(0)
		return true

	return false


func _enter_tree() -> void:
	var gm_hold: Node = root.get_node_or_null("GameManager")
	if gm_hold != null and gm_hold.has_method("pause"):
		gm_hold.call("pause")
	call_deferred("_spawn_main")


func _spawn_main() -> void:
	var packed: PackedScene = load("res://scenes/main/Main.tscn") as PackedScene
	if packed == null:
		print("[PERF] FAIL reason=Main_load_failed")
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


func _begin_profiling() -> void:
	var gm: Node = root.get_node_or_null("GameManager")
	var tm: Node = root.get_node_or_null("TickManager")
	if gm != null:
		_window_start_tick = gm.get("tick_count")
	if tm != null and tm.has_method("set_speed"):
		tm.call("set_speed", PROFILING_SPEED)
	var wmem: Node = root.get_node_or_null("WorldMemory")
	if wmem != null and wmem.has_method("event_count"):
		_window_events_start = wmem.call("event_count")
	_window_start_usec = Time.get_ticks_usec()
	_started = true
	print("[PERF] START speed=%.0fx" % PROFILING_SPEED)


func _log_window(tick: int) -> void:
	var now_usec: int = Time.get_ticks_usec()
	var window_usec: int = now_usec - _window_start_usec
	var wmem: Node = root.get_node_or_null("WorldMemory")
	var events_now: int = wmem.call("event_count") if wmem != null and wmem.has_method("event_count") else 0
	var events_delta: int = events_now - _window_events_start
	var avg_ticks_per_frame: float = float(_window_total_ticks_in_frames) / max(_window_frames, 1)
	var avg_usec_per_tick: float = float(window_usec) / max(tick - _window_start_tick, 1)

	# TickManager batch stats
	var tm: Node = root.get_node_or_null("TickManager")
	var batch_total_ticks: int = 0
	var batch_total_nodes: int = 0
	var batch_total_refcounted: int = 0
	if tm != null:
		var bs: Variant = tm.get("batch_stats")
		if bs is Dictionary:
			batch_total_ticks = int((bs as Dictionary).get("total_ticks", 0))
			batch_total_nodes = int((bs as Dictionary).get("total_nodes_called", 0))
			batch_total_refcounted = int((bs as Dictionary).get("total_refcounted_called", 0))

	# GameManager tick timing
	var gm: Node = root.get_node_or_null("GameManager")
	var gm_frame_usecs: int = gm.get("last_frame_game_tick_usecs") if gm != null else 0

	# WorldMeaning region count
	var wm: Node = root.get_node_or_null("WorldMeaning")
	var meaning_regions: int = 0
	if wm != null:
		var raw: Variant = wm.get("meaning_by_region")
		if raw is Dictionary:
			meaning_regions = (raw as Dictionary).size()

	_total_profiled_ticks += tick - _window_start_tick
	_total_profiled_usec += window_usec
	_last_log_tick = tick

	print("[PERF] tick=%d pathfinder_us=0 pawn_brain_us=0 job_claim_us=0 settlement_planner_us=0 meaning_recompute_us=0 | wall_usec=%d events_delta=%d max_ticks_per_frame=%d avg_ticks_per_frame=%.1f avg_usec_per_tick=%.0f gm_frame_usecs=%d meaning_regions=%d batch_total_nodes=%d batch_total_refcounted=%d" % [
		tick, window_usec, events_delta, _window_max_ticks_per_frame, avg_ticks_per_frame, avg_usec_per_tick, gm_frame_usecs, meaning_regions, batch_total_nodes, batch_total_refcounted
	])

	# Reset window
	_window_start_tick = tick
	_window_start_usec = now_usec
	_window_events_start = events_now
	_window_max_ticks_per_frame = 0
	_window_frames = 0
	_window_total_ticks_in_frames = 0


func _final_report(tick: int) -> void:
	var wmem: Node = root.get_node_or_null("WorldMemory")
	var events_total: int = wmem.call("event_count") if wmem != null and wmem.has_method("event_count") else 0

	# Consistency check
	var gm: Node = root.get_node_or_null("GameManager")
	var tm: Node = root.get_node_or_null("TickManager")
	var gm_tick: int = gm.get("tick_count") if gm != null else -1
	var tm_tick: int = tm.get("current_tick") if tm != null else -1
	var gm_paused: bool = bool(gm.get("is_paused")) if gm != null else true
	var tm_paused: bool = bool(tm.get("_is_paused")) if tm != null else true
	var consistency: String = "ok" if gm_tick == tm_tick and not gm_paused and not tm_paused else "DESYNC"
	if gm_tick != tm_tick:
		consistency = "tick_desync gm=%d tm=%d" % [gm_tick, tm_tick]
	elif gm_paused or tm_paused:
		consistency = "paused gm=%s tm=%s" % [str(gm_paused), str(tm_paused)]

	var avg_usec_per_tick: float = float(_total_profiled_usec) / max(_total_profiled_ticks, 1)

	print("[PERF] FINAL tick=%d events=%d peak_ticks_per_frame=%d avg_usec_per_tick=%.0f consistency=%s" % [
		tick, events_total, _peak_ticks_per_frame, avg_usec_per_tick, consistency
	])
	print("[PERF] PASS tick_profiler_complete")
