extends SceneTree

## Headless tick performance profiler.
## Run: Godot --path . -s res://tools/sim_tick_profiler.gd --headless --no-game-tick-trace
##
## Outputs timing markers at configurable intervals:
## [PERF] tick=N frame_ms=X pathfinder_us=Y pawn_us=Z jobclaim_us=W memory_us=M recompute_us=R

const REPORT_INTERVAL_TICKS: int = 100
const WARMUP_TICKS: int = 10

var _started: bool = false
var _first_tick_time: int = 0
var _last_report_tick: int = 0
var _tick_times: Array[int] = []


func _ready() -> void:
	# Disable tracing to get clean profiler output
	var gm: Node = root.get_node_or_null("GameManager")
	if gm != null and gm.has_method("set_game_tick_trace_enabled"):
		gm.call("set_game_tick_trace_enabled", false)
	
	# Hold until Main is ready
	var gm_pause: Node = root.get_node_or_null("GameManager")
	if gm_pause != null and gm_pause.has_method("pause"):
		gm_pause.call("pause")
	
	call_deferred("_spawn_main_and_profile")


func _spawn_main_and_profile() -> void:
	var packed: PackedScene = load("res://scenes/main/Main.tscn") as PackedScene
	if packed == null:
		push_error("[PERF] Failed to load Main.tscn")
		quit(1)
		return
	
	var main: Node = packed.instantiate()
	root.add_child(main)
	
	# Resume simulation
	var gm: Node = root.get_node_or_null("GameManager")
	if gm != null and gm.has_method("resume"):
		gm.call("resume")
	
	print("[PERF] Profiler initialized; starting warmup ticks...")
	_started = true


func _process(_delta: float) -> bool:
	if not _started:
		return false
	
	var gm: Node = root.get_node_or_null("GameManager")
	if gm == null:
		return false
	
	var tick: int = int(gm.get("tick_count", 0))
	
	# Warmup phase
	if tick < WARMUP_TICKS:
		return false
	
	# First real tick - start timing
	if _first_tick_time == 0:
		_first_tick_time = Time.get_ticks_usec()
		_last_report_tick = tick
	
	# Collect frame timing at tick boundaries
	var t0: int = Time.get_ticks_usec()
	
	# Report at intervals
	if tick >= _last_report_tick + REPORT_INTERVAL_TICKS:
		_report_perf(tick)
		_last_report_tick = tick
	
	# Exit after enough samples
	if tick >= WARMUP_TICKS + (REPORT_INTERVAL_TICKS * 3):
		print("[PERF] Profiler complete; exiting.")
		quit(0)
	
	return false


func _report_perf(current_tick: int) -> void:
	var gm: Node = root.get_node_or_null("GameManager")
	if gm == null:
		return
	
	# Get diagnostics from GameManager
	var diag: Dictionary = {}
	if gm.has_method("sim_diag"):
		diag = gm.call("sim_diag")
	
	var frame_ms: float = float(gm.get("last_frame_game_tick_usecs", 0)) / 1000.0
	var ticks_this_frame: int = int(gm.get("ticks_emitted_last_frame", 0))
	
	# Get system stats
	var pathfinder_us: int = 0
	var pawn_count: int = 0
	var job_open: int = 0
	var memory_events: int = 0
	var meaning_regions: int = 0
	
	# PathFinder stats
	var pf: Node = root.get_node_or_null("/root/World")
	if pf != null and pf.has_method("get_pathfinder"):
		var pfr = pf.call("get_pathfinder")
		if pfr != null and pfr.has_method("component_of"):
			# Sample component lookup cost
			var t_pf: int = Time.get_ticks_usec()
			for i in range(100):
				_ = pfr.call("component_of", Vector2i(32, 32))
			pathfinder_us = Time.get_ticks_usec() - t_pf
	
	# Pawn count
	var pawns: Array = root.get_nodes_in_group("pawns")
	pawn_count = pawns.size()
	
	# Job stats
	var jm: Node = root.get_node_or_null("JobManager")
	if jm != null:
		job_open = int(jm.call("open_count"))
	
	# WorldMemory stats
	var wm: Node = root.get_node_or_null("WorldMemory")
	if wm != null and wm.has_method("event_count"):
		memory_events = int(wm.call("event_count"))
	
	# WorldMeaning stats  
	var wme: Node = root.get_node_or_null("WorldMeaning")
	if wme != null and wme.has_method("get_tracked_region_count"):
		meaning_regions = int(wme.call("get_tracked_region_count"))
	
	print("[PERF] tick=%d frame_ms=%.2f pathfinder_us=%d pawns=%d job_open=%d memory_events=%d meaning_regions=%d" % [
		current_tick, frame_ms, pathfinder_us, pawn_count, job_open, memory_events, meaning_regions
	])
	print("[PERF]   ticks_per_frame=%d backlog=%.1f" % [
		ticks_this_frame,
		diag.get("queued_ticks_est", 0.0)
	])