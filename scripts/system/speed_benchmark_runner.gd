extends SceneTree

const TICKS_PER_SAMPLE_DEFAULT: int = 120
const STALL_TIMEOUT_MS: int = 30000
const MAIN_SCENE_PATH: String = "res://scenes/main/Main.tscn"
const REPORT_DIR_PATH: String = "res://logs/observer"
const REPORT_PASS_RATIO: float = 2.0

var _speeds: Array[float] = []
var _index: int = -1
var _start_tick: int = 0
var _start_ms: int = 0
var _last_tick_ms: int = 0
var _results: Array[Dictionary] = []
var _finished: bool = false
var _gm: Node = null
var _tick_manager: Node = null
var _main_node: Node = null
var _settlement_memory: Node = null
var _job_manager: Node = null
var _last_heartbeat_bucket: int = -1
var _sample_active: bool = false
var _timeline: Array[Dictionary] = []
var _ticks_per_sample: int = TICKS_PER_SAMPLE_DEFAULT
var _last_day_within_year: int = -1
var _last_year_index: int = -1
var _settlement_state_cache: Dictionary = {}
var _last_open_jobs_bucket: int = -1
var _canon_guard_results: Array[Dictionary] = []
var _session_id: String = ""
var _report_json_abs_path: String = ""
var _report_md_abs_path: String = ""
var _bench_mode: String = "worker" # "worker" or "normal"


func _initialize() -> void:
	_bench_mode = _parse_bench_mode()
	_ticks_per_sample = _parse_ticks_per_sample()
	_gm = root.get_node_or_null("GameManager")
	if _gm == null:
		push_error("[SPEED_BENCH] GameManager autoload not found.")
		quit(2)
		return
	_tick_manager = root.get_node_or_null("TickManager")
	_gm.call("set_simulation_worker_mode", _bench_mode == "worker")
	if _gm.has_method("set_lightweight_simulation_mode"):
		_gm.call("set_lightweight_simulation_mode", _bench_mode == "worker")
	_gm.call("set_tick_benchmark_enabled", true)
	var packed: PackedScene = load(MAIN_SCENE_PATH) as PackedScene
	if packed == null:
		push_error("[SPEED_BENCH] Failed to load main scene: %s" % MAIN_SCENE_PATH)
		quit(2)
		return
	var main_node: Node = packed.instantiate()
	root.add_child(main_node)
	_main_node = main_node
	_settlement_memory = root.get_node_or_null("SettlementMemory")
	_job_manager = root.get_node_or_null("JobManager")
	_session_id = _build_session_id()
	_prepare_report_paths()
	_speeds = Array(_gm.get("SPEED_STEPS")).duplicate()
	_speeds.sort()
	_gm.connect("game_tick", Callable(self, "_on_game_tick"))
	_run_canon_guards()
	call_deferred("_advance_to_next_speed")


func _process(_delta: float) -> bool:
	if _finished:
		return false
	if _index < 0 or _index >= _speeds.size():
		return false
	var now_ms: int = Time.get_ticks_msec()
	if now_ms - _last_tick_ms > STALL_TIMEOUT_MS:
		var speed: float = _speeds[_index]
		var progressed_ticks: int = int(_gm.get("tick_count")) - _start_tick
		_timeline_event("stall_timeout", {
			"speed": speed,
			"progressed_ticks": progressed_ticks,
			"timeout_ms": STALL_TIMEOUT_MS,
		})
		_results.append({
			"speed": speed,
			"elapsed_s": float(now_ms - _start_ms) / 1000.0,
			"expected_s": _expected_seconds_for(speed),
			"ratio": -1.0,
			"status": "STALL",
			"ticks": progressed_ticks,
			"perf": _collect_perf_counters(),
		})
		print("[SPEED_BENCH] speed=%.1fx status=STALL ticks=%d timeout_ms=%d" % [speed, progressed_ticks, STALL_TIMEOUT_MS])
		call_deferred("_advance_to_next_speed")
	return false


func _advance_to_next_speed() -> void:
	_index += 1
	if _index >= _speeds.size():
		_emit_summary_and_quit()
		return
	var speed: float = _speeds[_index]
	_gm.call("set_speed", speed)
	_start_tick = int(_gm.get("tick_count"))
	_start_ms = Time.get_ticks_msec()
	_last_tick_ms = _start_ms
	_last_heartbeat_bucket = -1
	_sample_active = true
	print("[SPEED_BENCH] begin speed=%.1fx start_tick=%d target_ticks=%d" % [speed, _start_tick, _ticks_per_sample])
	_timeline_event("speed_begin", {
		"speed": speed,
		"start_tick": _start_tick,
		"target_ticks": _ticks_per_sample,
	})


func _on_game_tick(tick: int) -> void:
	if _index < 0 or _index >= _speeds.size():
		return
	_update_timeline_state(tick)
	if not _sample_active:
		return
	_last_tick_ms = Time.get_ticks_msec()
	var progressed: int = tick - _start_tick
	var hb_bucket: int = int(progressed / 100)
	if hb_bucket != _last_heartbeat_bucket:
		_last_heartbeat_bucket = hb_bucket
		print("[SPEED_BENCH] heartbeat speed=%.1fx progressed_ticks=%d current_tick=%d" % [_speeds[_index], progressed, tick])
	if progressed < _ticks_per_sample:
		return
	var speed: float = _speeds[_index]
	var elapsed_s: float = float(Time.get_ticks_msec() - _start_ms) / 1000.0
	var expected_s: float = _expected_seconds_for(speed)
	var ratio: float = elapsed_s / maxf(0.001, expected_s)
	var status: String = "PASS" if ratio <= REPORT_PASS_RATIO else "SLOW"
	_sample_active = false
	var perf: Dictionary = _collect_perf_counters()
	_results.append({
		"speed": speed,
		"elapsed_s": elapsed_s,
		"expected_s": expected_s,
		"ratio": ratio,
		"status": status,
		"ticks": progressed,
		"perf": perf,
	})
	print("[SPEED_BENCH] speed=%.1fx ticks=%d elapsed=%.3fs expected=%.3fs ratio=%.2f status=%s" % [
		speed, progressed, elapsed_s, expected_s, ratio, status
	])
	_print_perf_counters_for_speed(speed, perf)
	_timeline_event("speed_end", {
		"speed": speed,
		"ticks": progressed,
		"elapsed_s": elapsed_s,
		"expected_s": expected_s,
		"ratio": ratio,
		"status": status,
		"perf": perf,
	})
	call_deferred("_advance_to_next_speed")


func _expected_seconds_for(speed: float) -> float:
	return (float(_ticks_per_sample) * float(_gm.get("TICK_INTERVAL_SECONDS"))) / maxf(0.001, speed)


func _resolve_pathfinder() -> Object:
	if _main_node == null or not is_instance_valid(_main_node):
		return null
	var world: Node = _main_node.get_node_or_null("WorldViewport/World")
	if world == null:
		return null
	var pf: Variant = world.get("pathfinder")
	if pf is Object:
		return pf as Object
	return null


func _counter_value(source: Object, property_name: String) -> int:
	if source == null:
		return 0
	var value: Variant = source.get(property_name)
	if value == null:
		return 0
	return int(value)


func _collect_perf_counters() -> Dictionary:
	var tick_manager: Object = _tick_manager as Object
	if tick_manager == null:
		tick_manager = _gm as Object
	var pathfinder: Object = _resolve_pathfinder()
	return {
		"tick_manager": {
			"ticks_processed_last_frame": _counter_value(tick_manager, "ticks_processed_last_frame"),
			"tickables_called_last_frame": _counter_value(tick_manager, "tickables_called_last_frame"),
			"max_ticks_processed_seen": _counter_value(tick_manager, "max_ticks_processed_seen"),
			"backlog_protection_hits": _counter_value(tick_manager, "backlog_protection_hits"),
		},
		"pathfinder": {
			"max_paths_solved_in_tick": _counter_value(pathfinder, "max_paths_solved_in_tick"),
			"total_paths_solved": _counter_value(pathfinder, "total_paths_solved"),
			"plain_paths_solved_total": _counter_value(pathfinder, "plain_paths_solved_total"),
			"historic_paths_solved_total": _counter_value(pathfinder, "historic_paths_solved_total"),
			"path_cache_hits": _counter_value(pathfinder, "path_cache_hits"),
			"path_cache_misses": _counter_value(pathfinder, "path_cache_misses"),
		},
	}


func _print_perf_counters_for_speed(speed: float, perf: Dictionary) -> void:
	var tm: Dictionary = perf.get("tick_manager", {}) as Dictionary
	var pf: Dictionary = perf.get("pathfinder", {}) as Dictionary
	print("[SPEED_BENCH][COUNTERS] speed=%.1fx tick_last_frame=%d tickables_last_frame=%d max_ticks_frame=%d backlog_hits=%d paths_max_tick=%d paths_total=%d paths_plain=%d paths_historic=%d path_cache_hits=%d path_cache_misses=%d" % [
		speed,
		int(tm.get("ticks_processed_last_frame", 0)),
		int(tm.get("tickables_called_last_frame", 0)),
		int(tm.get("max_ticks_processed_seen", 0)),
		int(tm.get("backlog_protection_hits", 0)),
		int(pf.get("max_paths_solved_in_tick", 0)),
		int(pf.get("total_paths_solved", 0)),
		int(pf.get("plain_paths_solved_total", 0)),
		int(pf.get("historic_paths_solved_total", 0)),
		int(pf.get("path_cache_hits", 0)),
		int(pf.get("path_cache_misses", 0)),
	])


func _parse_bench_mode() -> String:
	var args: PackedStringArray = _benchmark_args()
	# Godot passes script args separately; accept both:
	#  --bench-mode normal
	#  --bench_mode=normal
	for i in range(args.size()):
		var a: String = str(args[i])
		if a == "--bench-mode" and i + 1 < args.size():
			return str(args[i + 1])
		if a.begins_with("--bench-mode=") or a.begins_with("--bench_mode="):
			var eq: int = a.find("=")
			if eq >= 0 and eq + 1 < a.length():
				return a.substr(eq + 1)
	return "worker"


func _parse_ticks_per_sample() -> int:
	var args: PackedStringArray = _benchmark_args()
	for i in range(args.size()):
		var a: String = str(args[i])
		if a == "--ticks-per-sample" and i + 1 < args.size():
			return maxi(1, int(args[i + 1]))
		if a.begins_with("--ticks-per-sample="):
			var eq: int = a.find("=")
			if eq >= 0 and eq + 1 < a.length():
				return maxi(1, int(a.substr(eq + 1)))
	return TICKS_PER_SAMPLE_DEFAULT


func _benchmark_args() -> PackedStringArray:
	var args: PackedStringArray = OS.get_cmdline_args()
	for user_arg in OS.get_cmdline_user_args():
		args.append(user_arg)
	return args


func _emit_summary_and_quit() -> void:
	if _finished:
		return
	_finished = true
	var failures: int = 0
	print("[SPEED_BENCH] summary_begin")
	for row in _results:
		print("[SPEED_BENCH] summary speed=%.1fx status=%s elapsed=%.3fs expected=%.3fs ratio=%.2f ticks=%d" % [
			float(row.get("speed", 0.0)),
			str(row.get("status", "UNKNOWN")),
			float(row.get("elapsed_s", 0.0)),
			float(row.get("expected_s", 0.0)),
			float(row.get("ratio", -1.0)),
			int(row.get("ticks", 0)),
		])
		var perf: Dictionary = row.get("perf", {}) as Dictionary
		if not perf.is_empty():
			_print_perf_counters_for_speed(float(row.get("speed", 0.0)), perf)
		var st: String = str(row.get("status", "UNKNOWN"))
		if st != "PASS":
			failures += 1
	print("[SPEED_BENCH] summary_end failures=%d" % failures)
	_write_reports(failures)
	_gm.call("set_tick_benchmark_enabled", false)
	_gm.call("set_simulation_worker_mode", false)
	if _gm.has_method("set_lightweight_simulation_mode"):
		_gm.call("set_lightweight_simulation_mode", false)
	quit(0 if failures == 0 else 1)


func _update_timeline_state(tick: int) -> void:
	var year_idx: int = SimTime.sim_year_index(tick)
	var day_in_year: int = SimTime.calendar_day_within_sim_year(tick)
	if year_idx != _last_year_index or day_in_year != _last_day_within_year:
		_last_year_index = year_idx
		_last_day_within_year = day_in_year
		_timeline_event("calendar_day", {
			"year": year_idx,
			"day_within_year": day_in_year,
			"tick": tick,
		})
	_update_settlement_state_timeline(tick)
	_update_job_pressure_timeline(tick)


func _update_settlement_state_timeline(tick: int) -> void:
	if _settlement_memory == null:
		return
	var rows: Array = _settlement_memory.get("settlements")
	for any_row in rows:
		if not (any_row is Dictionary):
			continue
		var st: Dictionary = any_row as Dictionary
		var center: int = int(st.get("center_region", -1))
		if center < 0:
			continue
		var snapshot: String = "%s|%s|%s" % [
			str(st.get("state", "unknown")),
			str(st.get("governance_type", "unknown")),
			str((st.get("war_status", {"state": "peace"}) as Dictionary).get("state", "peace")),
		]
		var prev: String = str(_settlement_state_cache.get(center, ""))
		if snapshot == prev:
			continue
		_settlement_state_cache[center] = snapshot
		_timeline_event("settlement_state_change", {
			"tick": tick,
			"center_region": center,
			"snapshot": snapshot,
		})


func _timeline_event(kind: String, payload: Dictionary) -> void:
	var event: Dictionary = {
		"type": kind,
		"tick": int(_gm.get("tick_count")) if _gm != null else -1,
		"time_ms": Time.get_ticks_msec(),
		"payload": payload,
	}
	_timeline.append(event)


func _update_job_pressure_timeline(tick: int) -> void:
	if _job_manager == null or not _job_manager.has_method("open_count"):
		return
	var open_jobs: int = int(_job_manager.call("open_count"))
	var bucket: int = int(open_jobs / 25)
	if bucket == _last_open_jobs_bucket:
		return
	_last_open_jobs_bucket = bucket
	_timeline_event("job_pressure_bucket", {
		"tick": tick,
		"open_jobs": open_jobs,
		"bucket": bucket,
	})


func _run_canon_guards() -> void:
	_canon_guard_results.clear()
	var max_speed: float = 0.0
	for s in _speeds:
		max_speed = maxf(max_speed, float(s))
	_add_guard_result("speed_cap_100x", max_speed <= 100.0, "max_speed=%.1f" % max_speed)
	var tick_interval: float = float(_gm.get("TICK_INTERVAL_SECONDS"))
	_add_guard_result("simtime_tick_interval_match", is_equal_approx(tick_interval, SimTime.TICK_INTERVAL_SECONDS), "gm=%.3f simtime=%.3f" % [tick_interval, SimTime.TICK_INTERVAL_SECONDS])
	_add_guard_result("settlement_memory_autoload_present", _settlement_memory != null, "present=%s" % (_settlement_memory != null))


func _add_guard_result(name: String, passed: bool, detail: String) -> void:
	_canon_guard_results.append({
		"name": name,
		"pass": passed,
		"detail": detail,
	})
	print("[SPEED_BENCH][CANON_GUARD] %s pass=%s detail=%s" % [name, passed, detail])


func _build_session_id() -> String:
	return "observer_%d" % Time.get_unix_time_from_system()


func _prepare_report_paths() -> void:
	var abs_dir: String = ProjectSettings.globalize_path(REPORT_DIR_PATH)
	DirAccess.make_dir_recursive_absolute(abs_dir)
	_report_json_abs_path = "%s/%s.json" % [abs_dir, _session_id]
	_report_md_abs_path = "%s/%s.md" % [abs_dir, _session_id]


func _write_reports(failures: int) -> void:
	var ended_at_tick: int = int(_gm.get("tick_count")) if _gm != null else -1
	var report: Dictionary = {
		"session_id": _session_id,
		"created_unix": int(Time.get_unix_time_from_system()),
		"ticks_per_sample": _ticks_per_sample,
		"stall_timeout_ms": STALL_TIMEOUT_MS,
		"pass_ratio_threshold": REPORT_PASS_RATIO,
		"results": _results,
		"timeline": _timeline,
		"canon_guards": _canon_guard_results,
		"summary": {
			"failures": failures,
			"ended_at_tick": ended_at_tick,
		},
	}
	var jf: FileAccess = FileAccess.open(_report_json_abs_path, FileAccess.WRITE)
	if jf != null:
		jf.store_string(JSON.stringify(report, "\t"))
		jf.close()
	var mf: FileAccess = FileAccess.open(_report_md_abs_path, FileAccess.WRITE)
	if mf != null:
		mf.store_string(_build_markdown_report(report))
		mf.close()
	print("[SPEED_BENCH] report_json=%s" % _report_json_abs_path)
	print("[SPEED_BENCH] report_md=%s" % _report_md_abs_path)


func _build_markdown_report(report: Dictionary) -> String:
	var lines: PackedStringArray = PackedStringArray()
	lines.append("# HeelKawn Observer Report")
	lines.append("")
	lines.append("- session_id: `%s`" % str(report.get("session_id", "")))
	lines.append("- failures: `%d`" % int((report.get("summary", {}) as Dictionary).get("failures", -1)))
	lines.append("- pass_ratio_threshold: `%.2f`" % float(report.get("pass_ratio_threshold", 0.0)))
	lines.append("")
	lines.append("## Speed Results")
	for row_any in report.get("results", []):
		if not (row_any is Dictionary):
			continue
		var row: Dictionary = row_any as Dictionary
		lines.append(
			"- %.1fx -> %s (ticks=%d, elapsed=%.3fs, expected=%.3fs, ratio=%.2f)"
			% [
				float(row.get("speed", 0.0)),
				str(row.get("status", "UNKNOWN")),
				int(row.get("ticks", 0)),
				float(row.get("elapsed_s", 0.0)),
				float(row.get("expected_s", 0.0)),
				float(row.get("ratio", -1.0)),
			]
		)
		var perf: Dictionary = row.get("perf", {}) as Dictionary
		if not perf.is_empty():
			var tm: Dictionary = perf.get("tick_manager", {}) as Dictionary
			var pf: Dictionary = perf.get("pathfinder", {}) as Dictionary
			lines.append(
				"  - counters: tick_last_frame=%d, tickables_last_frame=%d, max_ticks_frame=%d, backlog_hits=%d, paths_max_tick=%d, paths_total=%d, paths_plain=%d, paths_historic=%d, path_cache_hits=%d, path_cache_misses=%d"
				% [
					int(tm.get("ticks_processed_last_frame", 0)),
					int(tm.get("tickables_called_last_frame", 0)),
					int(tm.get("max_ticks_processed_seen", 0)),
					int(tm.get("backlog_protection_hits", 0)),
					int(pf.get("max_paths_solved_in_tick", 0)),
					int(pf.get("total_paths_solved", 0)),
					int(pf.get("plain_paths_solved_total", 0)),
					int(pf.get("historic_paths_solved_total", 0)),
					int(pf.get("path_cache_hits", 0)),
					int(pf.get("path_cache_misses", 0)),
				]
			)
	lines.append("")
	lines.append("## Canon Guards")
	for guard_any in report.get("canon_guards", []):
		if not (guard_any is Dictionary):
			continue
		var guard: Dictionary = guard_any as Dictionary
		lines.append(
			"- %s: %s (%s)"
			% [
				str(guard.get("name", "unknown")),
				"PASS" if guard.get("pass", false) == true else "FAIL",
				str(guard.get("detail", "")),
			]
		)
	lines.append("")
	lines.append("## Timeline")
	for event_any in report.get("timeline", []):
		if not (event_any is Dictionary):
			continue
		var event: Dictionary = event_any as Dictionary
		var payload: Variant = event.get("payload", {})
		lines.append("- t=%d %s %s" % [int(event.get("tick", -1)), str(event.get("type", "event")), JSON.stringify(payload)])
	return "\n".join(lines) + "\n"
