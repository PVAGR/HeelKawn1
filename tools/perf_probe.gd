extends SceneTree

## Headless FPS/smoothness probe for the REAL game (Main.tscn loaded).
## Measures per-frame CPU cost (≈ attainable FPS) and per-tick sim cost at
## both 200x and 1x, plus captures the built-in [TICK-PROFILE] listener data.
## Run: Godot --headless --path . -s res://tools/perf_probe.gd --profile-game-tick

const SPEED_IDX_200: int = 5
const SPEED_IDX_1: int = 0
const BOOT_WAIT_FRAMES: int = 30
const P200_WARM_TICK: int = 2500
const P200_MEASURE_TICKS: int = 2500
const P1_MEASURE_FRAMES: int = 1200

var _phase: String = "boot"
var _spawned: bool = false
var _boot_wait: int = -1
var _frame_start_usec: int = 0
var _last_tick_seen: int = -1
var _p200_warm_tick: int = -1
var _p200_frame_us: Array[int] = []
var _p200_tick_us: Array[int] = []
var _p1_frame_us: Array[int] = []
var _p1_tick_us: Array[int] = []
var _p200_ticks_s: float = 0.0
var _p200_startusec: int = 0
var _p200_endusec: int = 0
var _prof_start_p200: Dictionary = {}
var _prof_start_p1: Dictionary = {}
var _p200_measure_begun: bool = false

func _process(_delta: float) -> bool:
	var now: int = Time.get_ticks_usec()
	if _frame_start_usec > 0:
		var dt: int = now - _frame_start_usec
		match _phase:
			"p200":
				_p200_frame_us.append(dt)
				var tk: int = _cur_tick()
				if tk > _last_tick_seen:
					_p200_tick_us.append(int(_last_tick_cost_usec()))
					_last_tick_seen = tk
			"p1":
				_p1_frame_us.append(dt)
				var tk1: int = _cur_tick()
				if tk1 > _last_tick_seen:
					_p1_tick_us.append(int(_last_tick_cost_usec()))
					_last_tick_seen = tk1
	_frame_start_usec = now

	if not _spawned:
		_spawned = true
		_spawn_main()
		return false
	if _boot_wait > 0:
		_boot_wait -= 1
		if _boot_wait == 0:
			_begin_200x()
		return false

	match _phase:
		"p200":
			var t: int = _cur_tick()
			if _p200_warm_tick < 0:
				_p200_warm_tick = t
				if _p200_startusec == 0:
					_p200_startusec = Time.get_ticks_usec()
				return false
			if t - _p200_warm_tick < P200_WARM_TICK:
				return false
			if not _p200_measure_begun:
				_p200_measure_begun = true
				_prof_start_p200 = _profiler_snapshot()
			if t - _p200_warm_tick >= P200_WARM_TICK + P200_MEASURE_TICKS:
				_p200_endusec = Time.get_ticks_usec()
				var elapsed_s: float = float(_p200_endusec - _p200_startusec) / 1e6
				_p200_ticks_s = float(P200_MEASURE_TICKS) / elapsed_s
				_print_stats("P200", "p200")
				_print_prof_delta("P200", _prof_start_p200, _profiler_snapshot())
				_dump_gt_profile("P200")
				_switch_to_1x()
				return false
		"p1":
			if _p1_frame_us.size() >= P1_MEASURE_FRAMES:
				_print_stats("P1", "p1")
				_print_prof_delta("P1", _prof_start_p1, _profiler_snapshot())
				_dump_gt_profile("P1")
				_dump_extra_state()
				quit(0)
				return true
	return false

func _last_tick_cost_usec() -> int:
	var tm: Node = root.get_node_or_null("TickManager")
	return int(tm.get("_last_tick_usec")) if tm != null and tm.get("_last_tick_usec") != null else 0

func _cur_tick() -> int:
	var gm: Node = root.get_node_or_null("GameManager")
	return int(gm.get("tick_count")) if gm != null else -1

func _spawn_main() -> void:
	var packed: PackedScene = load("res://scenes/main/Main.tscn") as PackedScene
	if packed == null:
		print("[PERF] FAIL reason=Main_load_failed")
		quit(1)
		return
	root.add_child(packed.instantiate())
	var tm: Node = root.get_node_or_null("TickManager")
	if tm != null and tm.has_method("resume"):
		tm.call("resume")
	var gm: Node = root.get_node_or_null("GameManager")
	if gm != null and gm.has_method("resume"):
		gm.call("resume")
	_boot_wait = BOOT_WAIT_FRAMES

func _begin_200x() -> void:
	var gm: Node = root.get_node_or_null("GameManager")
	if gm != null and gm.has_method("set_speed_index"):
		gm.call("set_speed_index", SPEED_IDX_200)
	var tm: Node = root.get_node_or_null("TickManager")
	if tm != null and tm.has_method("set_speed_index"):
		tm.call("set_speed_index", SPEED_IDX_200)
	_phase = "p200"
	_last_tick_seen = -1
	print("[PERF] PHASE p200 start (200x)")

func _switch_to_1x() -> void:
	var gm: Node = root.get_node_or_null("GameManager")
	if gm != null and gm.has_method("set_speed_index"):
		gm.call("set_speed_index", SPEED_IDX_1)
	var tm: Node = root.get_node_or_null("TickManager")
	if tm != null and tm.has_method("set_speed_index"):
		tm.call("set_speed_index", SPEED_IDX_1)
	_phase = "p1"
	_last_tick_seen = -1
	_p1_frame_us.clear()
	_p1_tick_us.clear()
	_prof_start_p1 = _profiler_snapshot()
	print("[PERF] PHASE p1 start (1x)")

func _print_stats(label: String, bucket: String) -> void:
	var frames: Array[int] = _p200_frame_us if bucket == "p200" else _p1_frame_us
	var ticks_us: Array[int] = _p200_tick_us if bucket == "p200" else _p1_tick_us
	if frames.is_empty():
		return
	var sum_f: int = 0
	var max_f: int = 0
	var over8: int = 0
	var over16: int = 0
	for f in frames:
		sum_f += f
		if f > max_f:
			max_f = f
		if f > 8000:
			over8 += 1
		if f > 16000:
			over16 += 1
	var avg_f: float = float(sum_f) / float(frames.size())
	frames.sort()
	var p95: int = frames[clampi(int(float(frames.size()) * 0.95), 0, frames.size() - 1)]
	var sum_t: int = 0
	var max_t: int = 0
	for t in ticks_us:
		sum_t += t
		if t > max_t:
			max_t = t
	var avg_t: float = float(sum_t) / float(maxi(ticks_us.size(), 1))
	var fps: float = 1e6 / avg_f if avg_f > 0 else 0.0
	print("[PERF] === %s === frames=%d fps_est=%.0f avg_frame=%.2fms p95_frame=%.2fms max_frame=%.2fms over8ms=%d over16ms=%d" % [
		label, frames.size(), fps, avg_f / 1000.0, float(p95) / 1000.0, float(max_f) / 1000.0, over8, over16,
	])
	print("[PERF] ticks_measured=%d avg_tick=%.2fms max_tick=%.2fms" % [ticks_us.size(), avg_t / 1000.0, float(max_t) / 1000.0])
	if bucket == "p200":
		print("[PERF] p200_throughput=%.1f ticks/s" % _p200_ticks_s)
	print("[PERF] tick_now=%d" % _cur_tick())

const _TP_FIELDS: Array[String] = [
	"st_idle_calls", "st_idle_us", "st_working_calls", "st_working_us",
	"st_walking_calls", "st_walking_us", "st_eating_calls", "st_eating_us",
	"st_sleeping_calls", "st_sleeping_us", "st_teaching_calls", "st_teaching_us",
	"st_crafting_calls", "st_crafting_us", "st_gathering_calls", "st_gathering_us",
	"st_fleeing_calls", "st_fleeing_us", "st_hiding_calls", "st_hiding_us",
	"st_passthrough_calls",
	"idle_emergency_calls", "idle_emergency_us", "idle_food_calls", "idle_food_us",
	"idle_rest_calls", "idle_rest_us", "idle_awareness_calls", "idle_awareness_us",
	"idle_social_calls", "idle_social_us", "idle_cognition_calls", "idle_cognition_us",
	"idle_job_search_calls", "idle_job_search_us", "idle_job_scoring_calls", "idle_job_scoring_us",
	"idle_job_claim_calls", "idle_job_claim_us", "idle_pathfinding_calls", "idle_pathfinding_us",
	"idle_wander_calls", "idle_wander_us", "idle_misc_calls", "idle_misc_us",
	"cnt_awareness_refresh", "cnt_job_searches", "cnt_path_requests", "cnt_path_recalculations",
	"cnt_settlement_queries", "cnt_household_queries", "cnt_matrix_ai_evals", "cnt_neural_evals",
	"cnt_worldmemory_queries",
	"cat_ai_world_ai", "cat_ai_settlement_ai", "cat_ai_agent_update", "cat_ai_maintenance", "cat_ai_total",
	"cat_pawn_process", "cat_pawn_draw", "_pawn_process_samples", "_pawn_draw_samples",
	"vis_total_pawns", "vis_pawns_ticking", "vis_pawns_process_active",
]

func _profiler_snapshot() -> Dictionary:
	var tp: Node = root.get_node_or_null("TickProfiler")
	if tp == null:
		return {}
	var snap: Dictionary = {}
	for f in _TP_FIELDS:
		snap[f] = int(tp.get(f))
	return snap

func _print_prof_delta(label: String, start: Dictionary, end: Dictionary) -> void:
	if start.is_empty() or end.is_empty():
		print("[PROF] %s: TickProfiler snapshot empty (is /root/TickProfiler an autoload?)" % label)
		return
	var name_to_key: Dictionary = {
		"st_idle": "idle_us", "st_working": "working_us", "st_walking": "walking_us",
		"st_eating": "eating_us", "st_sleeping": "sleeping_us", "st_teaching": "teaching_us",
		"st_crafting": "crafting_us", "st_gathering": "gathering_us", "st_fleeing": "fleeing_us",
		"st_hiding": "hiding_us", "st_passthrough": "passthrough_calls",
	}
	var rows: Array = []
	for prefix in name_to_key:
		var calls_d: int = int(end.get("st_%s_calls" % prefix if name_to_key[prefix] != "passthrough_calls" else "st_%s_calls" % prefix, 0)) - int(start.get("st_%s_calls" % prefix, 0))
		rows.append([prefix, calls_d, int(end.get("st_%s_us" % prefix, 0)) - int(start.get("st_%s_us" % prefix, 0))])
	var unk: Array[String] = [
		"idle_emergency", "idle_food", "idle_rest", "idle_awareness", "idle_social",
		"idle_cognition", "idle_job_search", "idle_job_scoring", "idle_job_claim",
		"idle_pathfinding", "idle_wander", "idle_misc", "idle_matrix_ai"
	]
	var idle_rows: Array = []
	for p in unk:
		var cd: int = int(end.get(p + "_calls", 0)) - int(start.get(p + "_calls", 0))
		var ud: int = int(end.get(p + "_us", 0)) - int(start.get(p + "_us", 0))
		idle_rows.append([p, cd, ud])
	idle_rows.sort_custom(func(a, b): return a[2] > b[2])
	print("[PROF] === %s profiler deltas ===" % label)
	for r in rows:
		if r[1] > 0:
			var avg_ms: float = float(r[2]) / float(r[1]) / 1000.0
			print("[PROF]  %-12s calls=%-6d total=%9.1fms avg=%.3fms" % [r[0], r[1], float(r[2]) / 1000.0, avg_ms])
	print("[PROF]  IDLE subcats (sorted by total ms):")
	for r in idle_rows:
		if r[1] > 0:
			var avg_ms: float = float(r[2]) / float(r[1]) / 1000.0
			print("[PROF]   %-20s calls=%-6d total=%9.1fms avg=%.3fms" % [r[0], r[1], float(r[2]) / 1000.0, avg_ms])
	var ai_total: int = int(end.get("cat_ai_total", 0)) - int(start.get("cat_ai_total", 0))
	print("[PROF]  AIAgent total=%.1fms (world_ai=%.1f settlement_ai=%.1f agent_update=%.1f maintenance=%.1f)" % [
		float(ai_total) / 1000.0,
		float(int(end.get("cat_ai_world_ai", 0)) - int(start.get("cat_ai_world_ai", 0))) / 1000.0,
		float(int(end.get("cat_ai_settlement_ai", 0)) - int(start.get("cat_ai_settlement_ai", 0))) / 1000.0,
		float(int(end.get("cat_ai_agent_update", 0)) - int(start.get("cat_ai_agent_update", 0))) / 1000.0,
		float(int(end.get("cat_ai_maintenance", 0)) - int(start.get("cat_ai_maintenance", 0))) / 1000.0,
	])
	print("[PROF]  PawnFrame: process=%.1fms samples=%d draw=%.1fms samples=%d" % [
		float(int(end.get("cat_pawn_process", 0)) - int(start.get("cat_pawn_process", 0))) / 1000.0,
		int(end.get("_pawn_process_samples", 0)) - int(start.get("_pawn_process_samples", 0)),
		float(int(end.get("cat_pawn_draw", 0)) - int(start.get("cat_pawn_draw", 0))) / 1000.0,
		int(end.get("_pawn_draw_samples", 0)) - int(start.get("_pawn_draw_samples", 0)),
	])
	print("[PROF]  Visibility: total=%d ticking=%d process_active=%d" % [
		int(end.get("vis_total_pawns", 0)), int(end.get("vis_pawns_ticking", 0)), int(end.get("vis_pawns_process_active", 0)),
	])
	print("[PROF]  counters: job_searches=%d path_req=%d path_recalc=%d settlement_q=%d household_q=%d matrix_ai=%d neural=%d worldmem=%d" % [
		int(end.get("cnt_job_searches", 0)) - int(start.get("cnt_job_searches", 0)),
		int(end.get("cnt_path_requests", 0)) - int(start.get("cnt_path_requests", 0)),
		int(end.get("cnt_path_recalculations", 0)) - int(start.get("cnt_path_recalculations", 0)),
		int(end.get("cnt_settlement_queries", 0)) - int(start.get("cnt_settlement_queries", 0)),
		int(end.get("cnt_household_queries", 0)) - int(start.get("cnt_household_queries", 0)),
		int(end.get("cnt_matrix_ai_evals", 0)) - int(start.get("cnt_matrix_ai_evals", 0)),
		int(end.get("cnt_neural_evals", 0)) - int(start.get("cnt_neural_evals", 0)),
		int(end.get("cnt_worldmemory_queries", 0)) - int(start.get("cnt_worldmemory_queries", 0)),
	])

func _dump_gt_profile(label: String) -> void:
	var gm: Node = root.get_node_or_null("GameManager")
	if gm == null:
		return
	var accum: Dictionary = gm.get("_gt_profile_accum")
	if accum == null:
		return
	var entries: Array = []
	var total_us: int = 0
	for pl in accum:
		var u: int = int(accum[pl])
		entries.append({"label": str(pl), "usec": u})
		total_us += u
	entries.sort_custom(func(a, b): return int(a["usec"]) > int(b["usec"]))
	print("[PROF] === %s game_tick listeners (total=%.1fms, %d listeners, accumulator window) ===" % [label, float(total_us) / 1000.0, entries.size()])
	for e in entries:
		print("[PROF]  %-70s %9.2fms" % [str(e["label"]), float(e["usec"]) / 1000.0])

func _dump_extra_state() -> void:
	var sm: Node = root.get_node_or_null("SettlementMemory")
	var jm: Node = root.get_node_or_null("JobManager")
	var ps: Node = root.get_node_or_null("Main/WorldViewport/PawnSpawner")
	var formal: int = int(sm.call("get_formal_settlement_count")) if sm != null and sm.has_method("get_formal_settlement_count") else -1
	var proto: int = (sm.call("get_proto_sites") as Array).size() if sm != null and sm.has_method("get_proto_sites") else -1
	var open_jobs: int = int(jm.call("open_count")) if jm != null and jm.has_method("open_count") else -1
	print("[PERF] state pawns=%d formal=%d proto=%d open_jobs=%d" % [
		ps.get_child_count() if ps != null else -1, formal, proto, open_jobs,
	])