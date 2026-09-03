extends Node
## Deep tick-cost profiler. Aggregates per-category timings over
## PROFILE_WINDOW_TICKS and prints ranked summaries. Debug-only.

const PROFILE_WINDOW_TICKS: int = 300

## Enabled by --profile-sim flag. All record_* methods and time-guards
## in HeelKawnian/TickManager/PathFinder check this before calling
## Time.get_ticks_usec().
var _profile_sim_enabled: bool = false

var _window_start_tick: int = -1
var _window_count: int = 0

# ── Pawn tick top-level categories (microseconds) ──
var cat_bookkeeping: int = 0
var cat_needs: int = 0
var cat_survival_health: int = 0
var cat_cognition: int = 0
var cat_awareness: int = 0
var cat_matrix_ai: int = 0
var cat_social: int = 0
var cat_household: int = 0
var cat_settlement: int = 0
var cat_state_dispatch: int = 0
var cat_misc: int = 0
var cat_total_heelkawnian: int = 0
var cat_worst_heelkawnian: int = 0
var _pawn_times: Array[int] = []

# ── State totals (calls + microseconds) ──
var st_idle_calls: int = 0; var st_idle_us: int = 0
var st_working_calls: int = 0; var st_working_us: int = 0
var st_walking_calls: int = 0; var st_walking_us: int = 0
var st_eating_calls: int = 0; var st_eating_us: int = 0
var st_sleeping_calls: int = 0; var st_sleeping_us: int = 0
var st_teaching_calls: int = 0; var st_teaching_us: int = 0
var st_challenge_calls: int = 0; var st_challenge_us: int = 0
var st_crafting_calls: int = 0; var st_crafting_us: int = 0
var st_gathering_calls: int = 0; var st_gathering_us: int = 0
var st_fleeing_calls: int = 0; var st_fleeing_us: int = 0
var st_hiding_calls: int = 0; var st_hiding_us: int = 0
var st_passthrough_calls: int = 0  # HAULING/GOING_*/etc that are pass

# ── IDLE subcategories (calls + microseconds) ──
var idle_emergency_calls: int = 0; var idle_emergency_us: int = 0
var idle_food_calls: int = 0; var idle_food_us: int = 0
var idle_rest_calls: int = 0; var idle_rest_us: int = 0
var idle_awareness_calls: int = 0; var idle_awareness_us: int = 0
var idle_social_calls: int = 0; var idle_social_us: int = 0
var idle_matrix_ai_calls: int = 0; var idle_matrix_ai_us: int = 0
var idle_cognition_calls: int = 0; var idle_cognition_us: int = 0
var idle_job_search_calls: int = 0; var idle_job_search_us: int = 0
var idle_job_scoring_calls: int = 0; var idle_job_scoring_us: int = 0
var idle_job_claim_calls: int = 0; var idle_job_claim_us: int = 0
var idle_pathfinding_calls: int = 0; var idle_pathfinding_us: int = 0
var idle_wander_calls: int = 0; var idle_wander_us: int = 0
var idle_combat_calls: int = 0; var idle_combat_us: int = 0
var idle_misc_calls: int = 0; var idle_misc_us: int = 0

# ── WORKING subcategories (calls + microseconds) ──
var work_validation_calls: int = 0; var work_validation_us: int = 0
var work_efficiency_calls: int = 0; var work_efficiency_us: int = 0
var work_progress_calls: int = 0; var work_progress_us: int = 0
var work_completion_calls: int = 0; var work_completion_us: int = 0
var work_hazard_calls: int = 0; var work_hazard_us: int = 0
var work_misc_calls: int = 0; var work_misc_us: int = 0

# ── Call counts ──
var cnt_awareness_refresh: int = 0
var cnt_alive_pawn_scans: int = 0
var cnt_relationship_queries: int = 0
var cnt_job_searches: int = 0
var cnt_path_requests: int = 0
var cnt_path_recalculations: int = 0
var cnt_settlement_queries: int = 0
var cnt_household_queries: int = 0
var cnt_matrix_ai_evals: int = 0
var cnt_neural_evals: int = 0
var cnt_worldmemory_queries: int = 0

# ── AIAgentManager breakdown ──
var cat_ai_world_ai: int = 0
var cat_ai_settlement_ai: int = 0
var cat_ai_agent_update: int = 0
var cat_ai_maintenance: int = 0
var cat_ai_total: int = 0

## Per-listener callback timing (microseconds), keyed by node path / listener
## name. Fed by TickManager._dispatch_tickable/_dispatch_refcounted via
## record_callback(). Read via get_callback_profile(). Diagnostic only.
var cat_callback_us: Dictionary = {}

# ── Main dispatch ──
var cat_main_dispatch: int = 0

# ── Pawn frame work ──
var cat_pawn_process: int = 0
var cat_pawn_draw: int = 0
var _pawn_process_samples: int = 0
var _pawn_draw_samples: int = 0

# ── Visibility ──
var vis_total_pawns: int = 0
var vis_pawns_ticking: int = 0
var vis_pawns_process_active: int = 0
var vis_pawns_with_path: int = 0
var vis_pawns_redrawing: int = 0


func _ready() -> void:
	_profile_sim_enabled = OS.get_cmdline_args().has("--profile-sim") \
			or OS.get_cmdline_user_args().has("--profile-sim")


func begin_window(tick: int) -> void:
	if _window_start_tick < 0:
		_window_start_tick = tick
	_window_count += 1


## Read-only peak into the current measurement window. Counters are CUMULATIVE
## totals over `get_window_count()` ticks since the last window reset, NOT
## single-tick samples. Exposed so diagnostics can label them truthfully.
func get_window_count() -> int:
	return _window_count


func get_window_start_tick() -> int:
	return _window_start_tick


func get_pawn_sample_count() -> int:
	return _pawn_times.size()


func is_enabled() -> bool:
	return _profile_sim_enabled

func record_pawn_time(us: int) -> void:
	if not _profile_sim_enabled: return
	_pawn_times.append(us)
	cat_total_heelkawnian += us
	if us > cat_worst_heelkawnian:
		cat_worst_heelkawnian = us


func record_category(cat: String, us: int) -> void:
	if not _profile_sim_enabled: return
	match cat:
		"bookkeeping": cat_bookkeeping += us
		"needs": cat_needs += us
		"survival_health": cat_survival_health += us
		"cognition": cat_cognition += us
		"awareness": cat_awareness += us
		"matrix_ai": cat_matrix_ai += us
		"social": cat_social += us
		"household": cat_household += us
		"settlement": cat_settlement += us
		"state_dispatch": cat_state_dispatch += us
		_: cat_misc += us


func record_state(state: String, us: int) -> void:
	if not _profile_sim_enabled: return
	match state:
		"IDLE": st_idle_calls += 1; st_idle_us += us
		"WORKING": st_working_calls += 1; st_working_us += us
		"WALKING": st_walking_calls += 1; st_walking_us += us
		"EATING": st_eating_calls += 1; st_eating_us += us
		"SLEEPING": st_sleeping_calls += 1; st_sleeping_us += us
		"TEACHING": st_teaching_calls += 1; st_teaching_us += us
		"CHALLENGE": st_challenge_calls += 1; st_challenge_us += us
		"CRAFTING": st_crafting_calls += 1; st_crafting_us += us
		"GATHERING": st_gathering_calls += 1; st_gathering_us += us
		"FLEEING": st_fleeing_calls += 1; st_fleeing_us += us
		"HIDING": st_hiding_calls += 1; st_hiding_us += us
		"PASSTHROUGH": st_passthrough_calls += 1


func record_idle(cat: String, us: int) -> void:
	if not _profile_sim_enabled: return
	match cat:
		"emergency": idle_emergency_calls += 1; idle_emergency_us += us
		"food": idle_food_calls += 1; idle_food_us += us
		"rest": idle_rest_calls += 1; idle_rest_us += us
		"awareness": idle_awareness_calls += 1; idle_awareness_us += us
		"social": idle_social_calls += 1; idle_social_us += us
		"matrix_ai": idle_matrix_ai_calls += 1; idle_matrix_ai_us += us
		"cognition": idle_cognition_calls += 1; idle_cognition_us += us
		"job_search": idle_job_search_calls += 1; idle_job_search_us += us
		"job_scoring": idle_job_scoring_calls += 1; idle_job_scoring_us += us
		"job_claim": idle_job_claim_calls += 1; idle_job_claim_us += us
		"pathfinding": idle_pathfinding_calls += 1; idle_pathfinding_us += us
		"wander": idle_wander_calls += 1; idle_wander_us += us
		"combat": idle_combat_calls += 1; idle_combat_us += us
		_: idle_misc_calls += 1; idle_misc_us += us


func record_work(cat: String, us: int) -> void:
	if not _profile_sim_enabled: return
	match cat:
		"validation": work_validation_calls += 1; work_validation_us += us
		"efficiency": work_efficiency_calls += 1; work_efficiency_us += us
		"progress": work_progress_calls += 1; work_progress_us += us
		"completion": work_completion_calls += 1; work_completion_us += us
		"hazard": work_hazard_calls += 1; work_hazard_us += us
		_: work_misc_calls += 1; work_misc_us += us


func record_counter(counter: String, delta: int = 1) -> void:
	if not _profile_sim_enabled: return
	match counter:
		"awareness_refresh": cnt_awareness_refresh += delta
		"alive_pawn_scans": cnt_alive_pawn_scans += delta
		"relationship_queries": cnt_relationship_queries += delta
		"job_searches": cnt_job_searches += delta
		"path_requests": cnt_path_requests += delta
		"path_recalculations": cnt_path_recalculations += delta
		"settlement_queries": cnt_settlement_queries += delta
		"household_queries": cnt_household_queries += delta
		"matrix_ai_evals": cnt_matrix_ai_evals += delta
		"neural_evals": cnt_neural_evals += delta
		"worldmemory_queries": cnt_worldmemory_queries += delta


func record_ai_agent(us: int) -> void:
	if not _profile_sim_enabled: return
	cat_ai_total += us


## Per-callback time (microseconds) accumulation, keyed by listener name/path.
## Called by TickManager for every tickable/refcounted listener when profiling
## is enabled. Supersedes the previously-nonexistent method (fixed to stop the
## script-error spam under --profile-sim) and feeds the F10 diagnostic layer.
func record_callback(us: int, name: String) -> void:
	if not _profile_sim_enabled: return
	cat_callback_us[name] = int(cat_callback_us.get(name, 0)) + us


## Read-only accessor: copy of the per-callback accumulators (us by listener).
func get_callback_profile() -> Dictionary:
	return cat_callback_us.duplicate()


func record_ai_subcategory(cat: String, us: int) -> void:
	if not _profile_sim_enabled: return
	match cat:
		"world_ai": cat_ai_world_ai += us
		"settlement_ai": cat_ai_settlement_ai += us
		"agent_update": cat_ai_agent_update += us
		"maintenance": cat_ai_maintenance += us


func record_main_dispatch(us: int) -> void:
	if not _profile_sim_enabled: return
	cat_main_dispatch += us


func record_pawn_process(us: int) -> void:
	if not _profile_sim_enabled: return
	cat_pawn_process += us
	_pawn_process_samples += 1


func record_pawn_draw(us: int) -> void:
	if not _profile_sim_enabled: return
	cat_pawn_draw += us
	_pawn_draw_samples += 1


func set_visibility_metrics(total: int, ticking: int, process_active: int, with_path: int, redrawing: int) -> void:
	vis_total_pawns = total
	vis_pawns_ticking = ticking
	vis_pawns_process_active = process_active
	vis_pawns_with_path = with_path
	vis_pawns_redrawing = redrawing


func end_window(tick: int) -> void:
	if _window_count <= 0:
		return
	if tick - _window_start_tick < PROFILE_WINDOW_TICKS:
		return
	var n_pawns: int = _pawn_times.size()
	var avg: float = float(cat_total_heelkawnian) / float(maxi(n_pawns, 1)) / 1000.0
	var worst_ms: float = float(cat_worst_heelkawnian) / 1000.0
	var total_ms: float = float(cat_total_heelkawnian) / 1000.0
	var cat_sum: int = cat_bookkeeping + cat_needs + cat_survival_health + cat_cognition \
		+ cat_awareness + cat_matrix_ai + cat_social + cat_household + cat_settlement \
		+ cat_state_dispatch + cat_misc
	var unattributed: int = cat_total_heelkawnian - cat_sum

	print("[PROFILER] === Tick Profile (%d ticks, %d pawn-samples) ===" % [_window_count, n_pawns])
	print("[PROFILER]  HeelKawnian total: %.1f ms  avg: %.2f ms  worst: %.2f ms" % [total_ms, avg, worst_ms])
	print("[PROFILER]  AIAgentManager: %.1f ms  Main dispatch: %.1f ms" % [float(cat_ai_total)/1000.0, float(cat_main_dispatch)/1000.0])
	print("[PROFILER]  Pawn categories (ms): bookkeeping=%.1f needs=%.1f survival=%.1f cognition=%.1f awareness=%.1f matrix_ai=%.1f social=%.1f household=%.1f settlement=%.1f state_dispatch=%.1f misc=%.1f unattributed=%.1f" % [
		float(cat_bookkeeping)/1000.0, float(cat_needs)/1000.0, float(cat_survival_health)/1000.0,
		float(cat_cognition)/1000.0, float(cat_awareness)/1000.0, float(cat_matrix_ai)/1000.0,
		float(cat_social)/1000.0, float(cat_household)/1000.0, float(cat_settlement)/1000.0,
		float(cat_state_dispatch)/1000.0, float(cat_misc)/1000.0, float(unattributed)/1000.0])

	# ── STATE PROFILE ──
	print("[STATE_PROFILE] (calls / total ms / avg ms)")
	_print_state("IDLE", st_idle_calls, st_idle_us)
	_print_state("WORKING", st_working_calls, st_working_us)
	_print_state("WALKING", st_walking_calls, st_walking_us)
	_print_state("EATING", st_eating_calls, st_eating_us)
	_print_state("SLEEPING", st_sleeping_calls, st_sleeping_us)
	_print_state("TEACHING", st_teaching_calls, st_teaching_us)
	_print_state("CHALLENGE", st_challenge_calls, st_challenge_us)
	_print_state("CRAFTING", st_crafting_calls, st_crafting_us)
	_print_state("GATHERING", st_gathering_calls, st_gathering_us)
	_print_state("FLEEING", st_fleeing_calls, st_fleeing_us)
	_print_state("HIDING", st_hiding_calls, st_hiding_us)
	print("[STATE_PROFILE] PASSTHROUGH calls=%d (haul/go/etc pass-through)" % st_passthrough_calls)

	# ── IDLE PROFILE (sorted by total ms) ──
	print("[IDLE_PROFILE] (calls / total ms / avg ms)")
	var idle_entries: Array = []
	_add_idle_entry(idle_entries, "idle_emergency", idle_emergency_calls, idle_emergency_us)
	_add_idle_entry(idle_entries, "idle_food", idle_food_calls, idle_food_us)
	_add_idle_entry(idle_entries, "idle_rest", idle_rest_calls, idle_rest_us)
	_add_idle_entry(idle_entries, "idle_awareness", idle_awareness_calls, idle_awareness_us)
	_add_idle_entry(idle_entries, "idle_social", idle_social_calls, idle_social_us)
	_add_idle_entry(idle_entries, "idle_matrix_ai", idle_matrix_ai_calls, idle_matrix_ai_us)
	_add_idle_entry(idle_entries, "idle_cognition", idle_cognition_calls, idle_cognition_us)
	_add_idle_entry(idle_entries, "idle_job_search", idle_job_search_calls, idle_job_search_us)
	_add_idle_entry(idle_entries, "idle_job_scoring", idle_job_scoring_calls, idle_job_scoring_us)
	_add_idle_entry(idle_entries, "idle_job_claim", idle_job_claim_calls, idle_job_claim_us)
	_add_idle_entry(idle_entries, "idle_pathfinding", idle_pathfinding_calls, idle_pathfinding_us)
	_add_idle_entry(idle_entries, "idle_wander", idle_wander_calls, idle_wander_us)
	_add_idle_entry(idle_entries, "idle_combat", idle_combat_calls, idle_combat_us)
	_add_idle_entry(idle_entries, "idle_misc", idle_misc_calls, idle_misc_us)
	idle_entries.sort_custom(func(a, b): return a[1] > b[1])
	for entry in idle_entries:
		var calls: int = entry[2]
		var us_total: int = entry[1]
		var avg_ms: float = float(us_total) / float(maxi(calls, 1)) / 1000.0
		print("[IDLE_PROFILE]  %-20s calls=%-6d total=%8.1fms avg=%.3fms" % [entry[0], calls, float(us_total)/1000.0, avg_ms])

	# ── WORKING PROFILE ──
	print("[WORKING_PROFILE] (calls / total ms / avg ms)")
	_print_work("validation", work_validation_calls, work_validation_us)
	_print_work("efficiency", work_efficiency_calls, work_efficiency_us)
	_print_work("progress", work_progress_calls, work_progress_us)
	_print_work("completion", work_completion_calls, work_completion_us)
	_print_work("hazard", work_hazard_calls, work_hazard_us)
	_print_work("misc", work_misc_calls, work_misc_us)

	# ── CALL COUNTS ──
	print("[CALL_COUNTS] awareness=%d alive_scans=%d rel_queries=%d job_searches=%d path_req=%d path_recalc=%d settlement=%d household=%d matrix_ai=%d neural=%d worldmem=%d" % [
		cnt_awareness_refresh, cnt_alive_pawn_scans, cnt_relationship_queries,
		cnt_job_searches, cnt_path_requests, cnt_path_recalculations,
		cnt_settlement_queries, cnt_household_queries, cnt_matrix_ai_evals,
		cnt_neural_evals, cnt_worldmemory_queries])

	# ── AIAgent ──
	print("[AI_AGENT] world_ai=%.1fms settlement_ai=%.1fms agent_update=%.1fms maintenance=%.1fms total=%.1fms" % [
		float(cat_ai_world_ai)/1000.0, float(cat_ai_settlement_ai)/1000.0,
		float(cat_ai_agent_update)/1000.0, float(cat_ai_maintenance)/1000.0,
		float(cat_ai_total)/1000.0])

	# ── Pawn frame ──
	print("[PAWN_FRAME] process=%.1fms (%d samples) draw=%.1fms (%d samples)" % [
		float(cat_pawn_process)/1000.0, _pawn_process_samples,
		float(cat_pawn_draw)/1000.0, _pawn_draw_samples])

	# ── Visibility ──
	print("[VISIBILITY] total=%d ticking=%d process_active=%d with_path=%d redrawing=%d" % [
		vis_total_pawns, vis_pawns_ticking, vis_pawns_process_active,
		vis_pawns_with_path, vis_pawns_redrawing])

	print("[PROFILER] === End Profile ===")
	reset()


func _print_state(label: String, calls: int, us: int) -> void:
	if calls > 0:
		var avg_ms: float = float(us) / float(calls) / 1000.0
		print("[STATE_PROFILE]  %-12s calls=%-6d total=%8.1fms avg=%.3fms" % [label, calls, float(us)/1000.0, avg_ms])


func _print_work(label: String, calls: int, us: int) -> void:
	if calls > 0:
		var avg_ms: float = float(us) / float(calls) / 1000.0
		print("[WORKING_PROFILE]  %-14s calls=%-6d total=%8.1fms avg=%.3fms" % [label, calls, float(us)/1000.0, avg_ms])


func _add_idle_entry(arr: Array, label: String, calls: int, us: int) -> void:
	arr.append([label, us, calls])


func reset() -> void:
	cat_bookkeeping = 0; cat_needs = 0; cat_survival_health = 0
	cat_cognition = 0; cat_awareness = 0; cat_matrix_ai = 0
	cat_social = 0; cat_household = 0; cat_settlement = 0
	cat_state_dispatch = 0; cat_misc = 0
	cat_total_heelkawnian = 0; cat_worst_heelkawnian = 0
	_pawn_times.clear()
	st_idle_calls = 0; st_idle_us = 0; st_working_calls = 0; st_working_us = 0
	st_walking_calls = 0; st_walking_us = 0; st_eating_calls = 0; st_eating_us = 0
	st_sleeping_calls = 0; st_sleeping_us = 0; st_teaching_calls = 0; st_teaching_us = 0
	st_challenge_calls = 0; st_challenge_us = 0; st_crafting_calls = 0; st_crafting_us = 0
	st_gathering_calls = 0; st_gathering_us = 0; st_fleeing_calls = 0; st_fleeing_us = 0
	st_hiding_calls = 0; st_hiding_us = 0; st_passthrough_calls = 0
	idle_emergency_calls = 0; idle_emergency_us = 0; idle_food_calls = 0; idle_food_us = 0
	idle_rest_calls = 0; idle_rest_us = 0; idle_awareness_calls = 0; idle_awareness_us = 0
	idle_social_calls = 0; idle_social_us = 0; idle_matrix_ai_calls = 0; idle_matrix_ai_us = 0
	idle_cognition_calls = 0; idle_cognition_us = 0; idle_job_search_calls = 0; idle_job_search_us = 0
	idle_job_scoring_calls = 0; idle_job_scoring_us = 0; idle_job_claim_calls = 0; idle_job_claim_us = 0
	idle_pathfinding_calls = 0; idle_pathfinding_us = 0; idle_wander_calls = 0; idle_wander_us = 0
	idle_combat_calls = 0; idle_combat_us = 0; idle_misc_calls = 0; idle_misc_us = 0
	work_validation_calls = 0; work_validation_us = 0; work_efficiency_calls = 0; work_efficiency_us = 0
	work_progress_calls = 0; work_progress_us = 0; work_completion_calls = 0; work_completion_us = 0
	work_hazard_calls = 0; work_hazard_us = 0; work_misc_calls = 0; work_misc_us = 0
	cnt_awareness_refresh = 0; cnt_alive_pawn_scans = 0; cnt_relationship_queries = 0
	cnt_job_searches = 0; cnt_path_requests = 0; cnt_path_recalculations = 0
	cnt_settlement_queries = 0; cnt_household_queries = 0; cnt_matrix_ai_evals = 0
	cnt_neural_evals = 0; cnt_worldmemory_queries = 0
	cat_ai_world_ai = 0; cat_ai_settlement_ai = 0; cat_ai_agent_update = 0
	cat_ai_maintenance = 0; cat_ai_total = 0; cat_main_dispatch = 0
	cat_callback_us.clear()
	cat_pawn_process = 0; cat_pawn_draw = 0
	_pawn_process_samples = 0; _pawn_draw_samples = 0
	vis_total_pawns = 0; vis_pawns_ticking = 0; vis_pawns_process_active = 0
	vis_pawns_with_path = 0; vis_pawns_redrawing = 0
	_window_start_tick = -1; _window_count = 0
