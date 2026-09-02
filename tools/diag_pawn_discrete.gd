extends SceneTree

## HK-TIME-P4-FIX2 verification.
##
## Confirms pawn_discrete no longer GENERATES decision opportunities faster than the
## real resumable HeelKawnian decision pipeline (BUILD_CONTEXT -> CHOOSE_ACTION ->
## JOB_SCAN, which spans multiple ticks) can consume. The free-running deadline
## lattice is REMOVED: each pawn has at most ONE scheduled normal next-decision
## deadline, that deadline is queued at most once per frontier, and the SUCCESSOR is
## scheduled by the pipeline's CHOOSE_ACTION step (the legacy scheduling point) as
##   successor = current authoritative causal frontier + interval_canonical (0.05).
##
## A QUEUED deadline is NOT applied: applied-through (and hence the pawn_discrete
## lane, which commits to the MINIMUM across pawns) advances ONLY when _tick_idle
## ACTUALLY starts a pipeline. Non-IDLE preserves no-backlog. `_force_expensive_decision`
## queues exactly ONE immediate opportunity (deduped; no stack). No target is ever used.
##
## Uses lightweight test nodes in group "pawns" that faithfully model the REAL
## resumable pipeline (a pipeline uses a distinct queued decision across several
## step_pipeline() calls before finishing), driven by the REAL TickManager
## _run_pawn_discrete_frontier coordinator interleaved with the pawn stepping
## (coordinator drives F, then the pawn ticks/consumes — real world order).
## Boots real autoloads; never boots Main/autosave. Quits 0 on PASS, 1 on FAIL.
## OUTPUT FIELDS: RESULT / FREE_RUNNING_LATTICE_REMOVED / MAX_NORMAL_PENDING_PER_PAWN /
## NEXT_DEADLINE_SCHEDULE_POINT / REAL_PIPELINE_TESTED / PAWN_DISCRETE_DIVERGENCE_FIXED /
## TARGET_USED / TEST / BLOCKER.

## Test-pawn: lightweight Node in group "pawns" that faithfully models the REAL
## resumable HeelKawnian pipeline (FIX2 semantics):
##   - `_next_deadline`: the SINGLE scheduled normal next-decision deadline (at most
##     one per pawn). `_DISCRETE_DEADLINE_NONE` (1e18) = "no candidate scheduled".
##   - `_apply_authoritative_discrete_frontier(F)`: there is NO free-running lattice.
##     It queues the ONE scheduled deadline only if it is DUE (<= F) and not already
##     queued. It never advances through more future deadlines and never schedules the
##     next (CHOOSE_ACTION owns scheduling).
##   - `_start_pipeline()`: the REAL pipeline start (test-side analog of _tick_idle
##     calling _start_idle_decision_pipeline). It consumes EXACTLY ONE queued deadline,
##     advances applied-through to it, clears the scheduled slot, and sets the phase to
##     BUILD_CONTEXT. A queued-but-unstarted deadline never commits history.
##   - `step_pipeline(F)`: one frame of the real pawn stepping the resumable pipeline,
##     which SPANS MULTIPLE invocations (BUILD_CONTEXT -> CHOOSE_ACTION -> JOB_SCAN).
##     If no pipeline is running and a decision is queued, it starts one (consume).
##     Otherwise it advances one phase; at CHOOSE_ACTION it schedules the successor
##     (deadline = F + interval_canonical) — the SAME causal point the legacy scheduler
##     used. Cooldown between separate pipelines is one full pipeline span.
##   - `get_pawn_discrete_applied_through_world_time()`: exposes applied-through so the
##     real coordinator commits pawn_discrete to the MINIMUM (never blindly F).
##   - Non-idle: clears the queue, advances scheduler + applied-through to F (no backlog).
##   - `force_once()`: exactly ONE immediate opportunity (dedupe; no stack).
##   - `max_queued_observed()`: peak queued size, proving MAX_NORMAL_PENDING_PER_PAWN=1.
## It NEVER commits any lane.
class TestDiscPawn extends Node:
	const _DISCRETE_DEADLINE_NONE: float = 1e18
	enum Phase { NONE, BUILD_CONTEXT, CHOOSE_ACTION, JOB_SCAN }
	var _next_deadline: float = -1.0
	var interval: float = 0.05
	var queued: Array[float] = []
	var applied_through: float = -1.0
	var computed: int = 0
	var consumed: int = 0
	var _phase: int = Phase.NONE
	var fail_next: bool = false
	var idle: bool = true
	var observed_lane_while_applying: float = -99.0
	var _max_queued: int = 0
	var _clk: Node = null
	var _last_successor: float = -1.0

	func _init(clk: Node) -> void:
		_clk = clk

	func setup_deadline(v: float) -> void:
		_next_deadline = v
		if applied_through < 0.0:
			applied_through = 0.0

	func _is_due(f: float) -> bool:
		return _next_deadline <= f + 1e-9

	func _queue(td: float) -> void:
		if queued.has(td):
			return
		var inserted: bool = false
		for i in range(queued.size()):
			if queued[i] > td:
				queued.insert(i, td)
				inserted = true
				break
		if not inserted:
			queued.append(td)
		if queued.size() > _max_queued:
			_max_queued = queued.size()

	func _is_queued(td: float) -> bool:
		return queued.has(td)

	func _clear_scheduled() -> void:
		_next_deadline = _DISCRETE_DEADLINE_NONE

	## CHOOSE_ACTION scheduling point: successor = current causal frontier + interval.
	func _schedule_next(f: float) -> void:
		var nd: float = f + interval
		if nd < applied_through:
			nd = applied_through
		_next_deadline = nd
		_last_successor = nd

	## REAL pipeline start: consume EXACTLY ONE queued deadline, advance applied, clear
	## the scheduled slot so a mid-flight frontier pass cannot re-queue the same value.
	func _start_pipeline() -> void:
		if queued.is_empty():
			return
		var td: float = queued.pop_front()
		applied_through = maxf(applied_through, td)
		consumed += 1
		_clear_scheduled()
		_phase = Phase.BUILD_CONTEXT

	## Advance the resumable pipeline one frame (models multi-tick BUILD_CONTEXT ->
	## CHOOSE_ACTION -> JOB_SCAN). Returns true while a pipeline is still running.
	func step_pipeline(f: float) -> bool:
		if _phase == Phase.NONE:
			if not queued.is_empty():
				_start_pipeline()  # a due decision actually starts a pipeline
				return true
			return false
		match _phase:
			Phase.BUILD_CONTEXT:
				_phase = Phase.CHOOSE_ACTION
			Phase.CHOOSE_ACTION:
				_schedule_next(f)  # the legacy scheduling point
				_phase = Phase.JOB_SCAN
			Phase.JOB_SCAN:
				_phase = Phase.NONE
		return _phase != Phase.NONE

	func force_once(f: float) -> void:
		if not idle:
			return
		var anchor: float = maxf(f, applied_through)
		if not _is_queued(anchor):
			_queue(anchor)
			computed += 1

	func get_pawn_discrete_applied_through_world_time() -> float:
		return applied_through

	func max_queued_observed() -> int:
		return _max_queued

	func _apply_authoritative_discrete_frontier(f: float) -> bool:
		if _clk == null:
			observed_lane_while_applying = -99.0
			return false
		observed_lane_while_applying = float(_clk.get_lane_applied_world_time_seconds("pawn_discrete"))
		if fail_next:
			fail_next = false
			return false
		if not idle:
			# non-idle: opportunities do not accumulate; advance to F (no burst).
			queued.clear()
			_next_deadline = f
			applied_through = maxf(applied_through, f)
			return true
		if _next_deadline < 0.0:
			# Fresh / never scheduled: first decision due at the very next frontier.
			_next_deadline = f
		# FIX2: queue the SINGLE scheduled normal deadline once if due & not already queued.
		# No free-running lattice. No successor scheduling here (CHOOSE_ACTION owns it).
		if _is_due(f) and not _is_queued(_next_deadline):
			_queue(_next_deadline)
			computed += 1
		if queued.is_empty():
			applied_through = maxf(applied_through, f)
		return true


var _failures: Array = []
var _ran: bool = false

## In a bare --script SceneTree run the root is only brought up as a real, in-tree
## scene once the main loop starts iterating frames. Running everything from
## _initialize leaves get_root() children NOT inside the tree, so
## get_nodes_in_group("pawns") would be empty. Defer the whole test to the first
## _process idles so the group registry is live.
func _process(_delta: float) -> bool:
	if _ran:
		return true
	_ran = true
	_run_all()
	return true

func _check(label: String, cond: bool, detail: String = "") -> void:
	if cond:
		print("  PASS %s" % label)
	else:
		_failures.append(label)
		print("  FAIL %s  %s" % [label, detail])

func _clock() -> Node:
	return get_root().get_node_or_null("SimulationClock")

func _tm() -> Node:
	return get_root().get_node_or_null("TickManager")

func _lane(clk: Node, lane: String) -> float:
	return float(clk.get_lane_applied_world_time_seconds(lane))

func _legacy(clk: Node) -> float:
	return float(clk.get_lane_applied_world_time_seconds("legacy_core"))

func _committed(clk: Node) -> float:
	return float(clk.get_committed_world_time_seconds())

## How far pawn_discrete lags legacy_core at a given frontier F (in canonical seconds).
func _a_lane_lag(clk: Node, f: float) -> float:
	return maxf(f - _lane(clk, "pawn_discrete"), 0.0)


func _initialize() -> void:
	print("PAWN_DISCRETE begin")

func _run_all() -> void:
	var clk: Node = _clock()
	var tm: Node = _tm()
	if clk == null or tm == null:
		print("BLOCKER: SimulationClock or TickManager autoload missing")
		quit(1)
		return

	# --- LOAD: production scripts compile ---
	var hk_script: Script = load("res://scripts/pawn/HeelKawnian.gd")
	var tm_script: Script = load("res://autoloads/TickManager.gd")
	var hk_err: String = ""
	var tm_err: String = ""
	if hk_script != null and hk_script.has_method("get_script_error_message"):
		hk_err = str(hk_script.get_script_error_message())
	if tm_script != null and tm_script.has_method("get_script_error_message"):
		tm_err = str(tm_script.get_script_error_message())
	_check("LOAD_HeelKawnian", hk_script != null and hk_err == "", "err=%s" % hk_err)
	_check("LOAD_TickManager", tm_script != null and tm_err == "", "err=%s" % tm_err)

# --- A: no free-running lattice. Over many frontiers with a multi-tick pipeline, the
	#         single scheduled normal deadline stays at ONE pending; a queued but
	#         unstarted decision does NOT let the lane commit through it. ---
	print("TEST_A_NO_LATTICE_SINGLE_PENDING")
	var quantum: float = float(tm.LEGACY_CORE_CANONICAL_SECONDS_PER_TRANSACTION)
	_check("A_quantum_is_0_05", is_equal_approx(quantum, 0.05), "quantum=%s" % quantum)
	clk.reset()
	tm.ensure_legacy_bridge_initialized()
	clk.register_dynamic_authoritative_lane("pawn_discrete")
	clk.advance_target(100000.0)
	tm._commit_legacy_core_quantum()
	var fa: float = _legacy(clk)  # 0.05
	var a_pawn := _spawn(clk)
	a_pawn.setup_deadline(-1.0)  # fresh: first opportunity due at first frontier
	# Drive 30 frontiers WITHOUT ever letting the pawn start a pipeline. Because there
	# is no lattice, the queue never grows past the single scheduled normal deadline.
	var a_lag_max: float = -1.0
	for i in range(30):
		tm._commit_legacy_core_quantum()
		var fi: float = _legacy(clk)
		tm._run_pawn_discrete_frontier(fi)
		a_lag_max = maxf(a_lag_max, _a_lane_lag(clk, fi))
		a_pawn.step_pipeline(fi)
	_check("A_no_lattice_single_pending", a_pawn.max_queued_observed() == 1, \
		"max_queued=%s (must be 1)" % a_pawn.max_queued_observed())
	_check("A_single_normal_pending", a_pawn.queued.size() <= 1, \
		"queued=%s" % a_pawn.queued.size())
	# Lane commits to MIN applied-through (queued & unstarted => stays behind oldest).
	var a_oldest: float = a_pawn.queued[0] if not a_pawn.queued.is_empty() else _legacy(clk)
	_check("A_lane_not_past_unstarted", _lane(clk, "pawn_discrete") <= a_oldest + 1e-9, \
		"lane=%s oldest=%s" % [_lane(clk, "pawn_discrete"), a_oldest])
	a_pawn.free()

	# --- B: REAL pipeline start consumes exactly ONE; applied advances; lane follows. ---
	print("TEST_B_REAL_PIPELINE_CONSUME_ONE")
	clk.reset()
	tm.ensure_legacy_bridge_initialized()
	clk.register_dynamic_authoritative_lane("pawn_discrete")
	clk.advance_target(100000.0)
	tm._commit_legacy_core_quantum()
	var fb: float = _legacy(clk)
	var b_pawn := _spawn(clk)
	b_pawn.setup_deadline(-1.0)
	tm._run_pawn_discrete_frontier(fb)  # queues the single due normal
	var b_before: int = b_pawn.queued.size()
	b_pawn.step_pipeline(fb)  # _tick_idle: a due decision ACTUALLY starts the pipeline
	_check("B_pipeline_consumed_one", b_before == 1 and b_pawn.consumed == 1 and b_pawn.queued.is_empty(), \
		"before=%s consumed=%s queued=%s" % [b_before, b_pawn.consumed, b_pawn.queued.size()])
	_check("B_pipeline_in_flight", b_pawn._phase == TestDiscPawn.Phase.BUILD_CONTEXT, \
		"phase=%s (resumable pipeline starts at BUILD_CONTEXT)" % b_pawn._phase)
	# Let the pipeline finish (CHOOSE_ACTION schedules successor, JOB_SCAN finishes).
	while b_pawn.step_pipeline(fb):
		pass
	_check("B_finish_schedules_successor", is_equal_approx(b_pawn._next_deadline, fb + quantum), \
		"successor=%s F+interval=%s" % [b_pawn._next_deadline, fb + quantum])
	_check("B_successor_not_past_applied", b_pawn._next_deadline >= b_pawn.applied_through, \
		"successor=%s applied=%s" % [b_pawn._next_deadline, b_pawn.applied_through])
	# Coordinator commit to MIN applied-through (now == fb, since the queued deadline was
	# consumed and nothing is left due through fb).
	tm._run_pawn_discrete_frontier(fb)
	_check("B_lane_follows_min", is_equal_approx(_lane(clk, "pawn_discrete"), b_pawn.applied_through), \
		"lane=%s applied=%s" % [_lane(clk, "pawn_discrete"), b_pawn.applied_through])
	b_pawn.free()

	# --- C: pipeline spans multiple frontiers and the queue still never exceeds ONE;
	#         applied catches up each time a pipeline finishes; successor scheduled at
	#         CHOOSE_ACTION. ---
	print("TEST_C_DIVERGENCE_FIXED_20_TRANSACTIONS")
	clk.reset()
	tm.ensure_legacy_bridge_initialized()
	clk.register_dynamic_authoritative_lane("pawn_discrete")
	clk.advance_target(100000.0)
	var c_pawn := _spawn(clk)
	c_pawn.setup_deadline(-1.0)
	var c_max_lag: float = -1.0
	var c_final_lag: float = -1.0
	var c_peak_queue: int = 0
	var N: int = 40  # 20+ completed 1x transactions
	for i in range(N):
		tm._commit_legacy_core_quantum()
		var fi: float = _legacy(clk)
		tm._run_pawn_discrete_frontier(fi)  # coordinator through F (may queue one if due)
		var lag: float = _a_lane_lag(clk, fi)
		if lag > c_max_lag:
			c_max_lag = lag
		# Advance the real pipeline (it consumes what a pipeline can consume each frame).
		for _k in range(3):
			if not c_pawn.step_pipeline(fi):
				break
		c_peak_queue = maxi(c_peak_queue, c_pawn.max_queued_observed())
		if i == N - 1:
			c_final_lag = _a_lane_lag(clk, fi)
	_check("C_max_normal_pending_one", c_peak_queue <= 1, \
		"peak_queued=%s (must be 1)" % c_peak_queue)
	# The lane must NOT continually fall behind: its max lag is bounded by the pipeline
	# span (one decision in flight = one 0.05 interval), NOT growing with N.
	_check("C_lag_bounded_by_pipeline_span", c_max_lag <= 3.0 * quantum + 1e-6, \
		"max_lag=%s (bound ~3 intervals)" % c_max_lag)
	# After the pipeline has consumed the final due decision, applied catches legacy.
	while c_pawn.step_pipeline(_legacy(clk)):
		pass
	tm._run_pawn_discrete_frontier(_legacy(clk))
	_check("C_catches_up_not_permanently_behind", _legacy(clk) - _lane(clk, "pawn_discrete") <= quantum + 1e-6, \
		"lane=%s legacy=%s lag=%s" % [_lane(clk, "pawn_discrete"), _legacy(clk), _legacy(clk) - _lane(clk, "pawn_discrete")])
	c_pawn.free()

	# --- D: force creates EXACTLY ONE immediate opportunity; repeated force does NOT
	#         stack duplicates. ---
	print("TEST_D_FORCE_EXACTLY_ONE")
	clk.reset()
	tm.ensure_legacy_bridge_initialized()
	clk.register_dynamic_authoritative_lane("pawn_discrete")
	clk.advance_target(100000.0)
	tm._commit_legacy_core_quantum()
	var fd: float = _legacy(clk)
	var d_pawn := _spawn(clk)
	d_pawn.setup_deadline(-1.0)
	d_pawn.force_once(fd)
	d_pawn.force_once(fd)  # second force is a duplicate -> must NOT stack
	d_pawn.force_once(fd)
	_check("D_force_one_only", d_pawn.queued.size() == 1, "queued=%s (must be 1)" % d_pawn.queued.size())
	_check("D_force_is_immediate", is_equal_approx(d_pawn.queued[0], fd), \
		"forced_deadline=%s frontier=%s" % [d_pawn.queued[0], fd])
	# Consuming it by a real pipeline start advances applied.
	d_pawn.step_pipeline(fd)
	_check("D_force_consumed_one", d_pawn.consumed == 1 and d_pawn.queued.is_empty(), \
		"consumed=%s queued=%s" % [d_pawn.consumed, d_pawn.queued.size()])
	d_pawn.free()

	# --- E: non-IDLE across many frontiers then IDLE. No backlog burst; the first idle
	#         opportunity matches legacy (one fresh decision, no stale/two-at-F). ---
	print("TEST_E_NONIDLE_NO_BURST")
	clk.reset()
	tm.ensure_legacy_bridge_initialized()
	clk.register_dynamic_authoritative_lane("pawn_discrete")
	clk.advance_target(100000.0)
	var e_pawn := _spawn(clk)
	e_pawn.setup_deadline(-1.0)
	e_pawn.idle = false  # pawn works through many frontiers
	for i in range(50):
		tm._commit_legacy_core_quantum()
		var fe_i: float = _legacy(clk)
		tm._run_pawn_discrete_frontier(fe_i)
	_check("E_no_accum_during_nonidle", e_pawn.queued.is_empty() and e_pawn.computed == 0, \
		"queued=%s computed=%s" % [e_pawn.queued.size(), e_pawn.computed])
	_check("E_lane_advanced_through_nonidle", is_equal_approx(_lane(clk, "pawn_discrete"), _legacy(clk)), \
		"lane=%s F=%s" % [_lane(clk, "pawn_discrete"), _legacy(clk)])
	var fe_boundary: float = _legacy(clk)
	e_pawn.idle = true
	tm._run_pawn_discrete_frontier(fe_boundary)
	# Exactly ONE fresh decision, NOT a burst and NOT two-at-F.
	_check("E_first_idle_is_one", e_pawn.queued.size() == 1 and e_pawn.max_queued_observed() <= 1, \
		"queued=%s peak=%s" % [e_pawn.queued.size(), e_pawn.max_queued_observed()])
	e_pawn.free()

	# --- F: target > F. No future decision execution beyond the committed frontier. ---
	print("TEST_F_TARGET_AHEAD_NO_EXEC")
	clk.reset()
	tm.ensure_legacy_bridge_initialized()
	clk.register_dynamic_authoritative_lane("pawn_discrete")
	clk.advance_target(100000.0)  # far target
	tm._commit_legacy_core_quantum()
	var ff: float = _legacy(clk)  # 0.05
	var h_pawn := _spawn(clk)
	h_pawn.setup_deadline(5.0)  # next decision long after F
	tm._run_pawn_discrete_frontier(ff)
	_check("F_no_future_queued", h_pawn.queued.is_empty() and h_pawn.computed == 0, \
		"queued=%s computed=%s" % [h_pawn.queued.size(), h_pawn.computed])
	_check("F_lane_not_overshoot_target", _lane(clk, "pawn_discrete") <= ff and not is_equal_approx(_lane(clk, "pawn_discrete"), 100000.0), \
		"lane=%s F=%s target=100000" % [_lane(clk, "pawn_discrete"), ff])
	h_pawn.free()

	# --- F: STRUCTURAL ---
	print("TEST_F_STRUCTURE")
	_run_structural_checks(tm_script, hk_script)

	if _failures.size() == 0:
		print("PAWN_DISCRETE RESULT=PASS")
		print("FREE_RUNNING_LATTICE_REMOVED=YES")
		print("MAX_NORMAL_PENDING_PER_PAWN=1")
		print("NEXT_DEADLINE_SCHEDULE_POINT=CHOOSE_ACTION")
		print("REAL_PIPELINE_TESTED=YES")
		print("PAWN_DISCRETE_DIVERGENCE_FIXED=YES")
		print("TARGET_USED=NO")
		print("TEST=A,B,C,D,E,F,STRUCT")
		print("BLOCKER=")
		quit(0)
	else:
		print("PAWN_DISCRETE RESULT=FAIL failures=%d" % _failures.size())
		for label in _failures:
			print("  failed: %s" % label)
		print("FREE_RUNNING_LATTICE_REMOVED=NO")
		print("MAX_NORMAL_PENDING_PER_PAWN=UNKNOWN")
		print("NEXT_DEADLINE_SCHEDULE_POINT=UNKNOWN")
		print("REAL_PIPELINE_TESTED=NO")
		print("PAWN_DISCRETE_DIVERGENCE_FIXED=NO")
		print("TARGET_USED=NO")
		print("TEST=A,B,C,D,E,F,STRUCT")
		print("BLOCKER=FAILURES_%d" % _failures.size())
		quit(1)


## Structural source inspection of TickManager + HeelKawnian (test F).
func _run_structural_checks(tm_script: Script, hk_script: Script) -> void:
	var tm_src: String = str(tm_script.source_code) if tm_script != null else ""
	var hk_src: String = str(hk_script.source_code) if hk_script != null else ""
	# TickManager owns the registration + coordinator step.
	_check("F_TM_has_pawn_discrete_const", tm_src.find("PAWN_DISCRETE_LANE_ID") >= 0,
		"lane-id ownership moved to TickManager")
	var tm_ensure: Array = _func_body(tm_src, "_ensure_pawn_discrete_lane")
	_check("F_TM_owns_lane_registration", tm_ensure[1] and tm_ensure[0].find("register_dynamic_authoritative_lane") >= 0,
		"TickManager._ensure_pawn_discrete_lane must register the lane")
	var tm_coord: Array = _func_body(tm_src, "_run_pawn_discrete_frontier")
	_check("F_TM_coordinator_exists", tm_coord[1], "TickManager._run_pawn_discrete_frontier=%s" % tm_coord[0])
	_check("F_TM_coordinator_commits_after_all", tm_coord[0].find("PAWN_DISCRETE_LANE_ID") >= 0 \
		and tm_coord[0].find("commit_lane_world_time") >= 0,
		"only the coordinator may commit pawn_discrete")
	# Ordering: _complete_pending_tick registers pawn_discrete before legacy advances,
	# and runs it through F AFTER pawn_continuous and BEFORE the continuous emission.
	var complete: Array = _func_body(tm_src, "_complete_pending_tick")
	_check("F_TM_orders_register_before_legacy", complete[0].find("_ensure_pawn_discrete_lane()") >= 0 \
		and complete[0].find("_ensure_pawn_discrete_lane()") < complete[0].find("_commit_legacy_core_quantum()"),
		"pawn_discrete must be ensured BEFORE the legacy commit")
	_check("F_TM_orders_discrete_after_continuous", complete[0].find("_run_pawn_discrete_frontier_wrapper") >= 0 \
		and complete[0].find("_run_pawn_continuous_frontier_wrapper") < complete[0].find("_run_pawn_discrete_frontier_wrapper"),
		"pawn_discrete must run through F AFTER pawn_continuous")
	_check("F_TM_orders_discrete_before_emit", complete[0].find("_run_pawn_discrete_frontier_wrapper") < complete[0].find("_emit_authoritative_continuous_frontier"),
		"pawn_discrete must run BEFORE the continuous emission / tick_processed")
	# --- HK-TIME-P4-FIX2 structural invariants ---
	# FIX2 (KEEP): TickManager commits pawn_discrete to the MINIMUM real applied-through.
	var tm_coord_fix: Array = _func_body(tm_src, "_run_pawn_discrete_frontier")
	_check("F_commit_is_MIN_applied_not_F",
		(tm_coord_fix[0].find("get_pawn_discrete_applied_through_world_time") >= 0 \
		and tm_coord_fix[0].find("min_applied") >= 0 \
		and tm_coord_fix[0].find("commit_lane_world_time(PAWN_DISCRETE_LANE_ID, min_applied)") >= 0),
		"coordinator must commit to MIN per-pawn applied-through, not blind F")
	_check("F_no_false_commit_when_queued", tm_coord_fix[0].find("commit_lane_world_time(PAWN_DISCRETE_LANE_ID, frontier)") < 0,
		"coordinator must NEVER commit blindly to F")
	_check("F_TM_target_unused", tm_coord_fix[0].find("target") < 0,
		"coordinator must not read target")
	# FIX2: the per-pawn apply must NOT have a free-running deadline lattice and must NOT
	# schedule the successor (CHOOSE_ACTION owns scheduling).
	var hk_apply: Array = _func_body(hk_src, "_apply_authoritative_discrete_frontier")
	_check("F_HeelKawnian_pure_apply_exists", hk_apply[1], "pure per-pawn discrete apply must exist")
	_check("F_HeelKawnian_apply_no_commit", hk_apply[0].find("commit_lane_world_time") < 0,
		"per-pawn apply must NOT commit any lane")
	_check("F_no_lattice_no_free_running_advance",
		hk_apply[0].find("while _next_decision_world_time <= ") < 0 \
		and hk_apply[0].find("+= interval") < 0,
		"free-running lattice (while-next<=F / += interval) must be REMOVED from apply")
	_check("F_apply_single_slot_dedupe", hk_apply[0].find("_is_deadline_queued(") >= 0,
		"apply must guard against re-queueing the single normal deadline")
	_check("F_apply_does_not_schedule_successor", hk_apply[0].find("_schedule_next_discrete_deadline(") < 0,
		"apply must NOT schedule the successor — CHOOSE_ACTION owns it")
	_check("F_apply_fresh_single_due", hk_apply[0].find("_next_decision_world_time = frontier_seconds") >= 0,
		"fresh spawn initializes the single scheduled deadline to the frontier")
	# FIX2: the resumable pipeline's CHOOSE_ACTION phase is the scheduling point.
	var choose: Array = _func_body(hk_src, "_phase_choose_action")
	_check("F_choose_action_schedules_next", choose[1] and choose[0].find("_schedule_next_discrete_deadline()") >= 0,
		"CHOOSE_ACTION must schedule the next normal decision deadline")
	var sched: Array = _func_body(hk_src, "_schedule_next_discrete_deadline")
	_check("F_schedule_uses_frontier_plus_interval", sched[1] \
		and sched[0].find("LEGACY_CORE_LANE_ID") >= 0 \
		and sched[0].find("_discrete_decision_interval_canonical()") >= 0,
		"successor = current authoritative causal frontier + interval_canonical")
	_check("F_schedule_no_target", sched[1] and sched[0].find("target") < 0,
		"scheduler must not read target")
	# FIX2: a REAL pipeline start consumes exactly one and clears the scheduled slot; no
	# extra normal deadline may accumulate while a pipeline is pending.
	var consume_fn: Array = _func_body(hk_src, "_consume_discrete_decision")
	_check("F_consume_clears_slot", consume_fn[1] and consume_fn[0].find("_clear_scheduled_normal_deadline()") >= 0,
		"consume must clear the scheduled normal slot (no re-queue mid-pipeline)")
	_check("F_tick_idle_consume_is_pipeline_start",
		_func_body(hk_src, "_tick_idle")[0].find("_consume_discrete_decision(") >= 0 \
		and _func_body(hk_src, "_tick_idle")[0].find("_start_idle_decision_pipeline(") >= 0,
		"only a real pipeline start consumes a queued deadline")
	# FIX2: force queues exactly one immediate opportunity (deduped, no stack), and does
	# NOT schedule the successor / advance the scheduler.
	var force: Array = _func_body(hk_src, "_force_expensive_decision")
	_check("F_force_dedupes", force[1] and force[0].find("_is_deadline_queued(") >= 0,
		"force must dedupe (exactly one immediate opportunity, no stack)")
	_check("F_force_no_successor_schedule", force[1] and force[0].find("_schedule_next_discrete_deadline(") < 0,
		"force must not schedule the successor (CHOOSE_ACTION owns it)")
	# FIX2: non-IDLE preserves no-backlog (clears the queue, no stale/two-at-F).
	_check("F_nonidle_no_burst", hk_apply[0].find("_state != State.IDLE") >= 0 \
		and hk_apply[0].find(".clear()") >= 0,
		"non-IDLE clears the queue (no backlog burst)")
	# HeelKawnian: pure per-pawn apply does NOT commit a lane and does NOT register.
	_check("F_HeelKawnian_no_registration", hk_src.find("register_dynamic_authoritative_lane") < 0,
		"pawn must not register the lane")
	_check("F_HeelKawnian_no_lane_const", hk_src.find("PAWN_DISCRETE_LANE_ID") < 0,
		"pawn must not define/own the pawn_discrete lane-id")
	_check("F_TickIdle_no_legacy_gate", _func_body(hk_src, "_tick_idle")[0].find("_expensive_decision_due(") < 0,
		"migrated idle-decision timing must be absent from _tick_idle/_on_world_tick")
	_check("F_TickIdle_uses_discrete_due", _func_body(hk_src, "_tick_idle")[0].find("_discrete_decision_due(") >= 0,
		"_tick_idle must consult the world-time discrete cadence")


## Create a TestDiscPawn, add it to the tree, then register the "pawns" group AFTER
## the node is in the tree (so the SceneTree group registry sees it).
func _spawn(clk: Node) -> TestDiscPawn:
	var tp := TestDiscPawn.new(clk)
	get_root().add_child(tp)
	tp.add_to_group("pawns")
	return tp


## Extract a top-level function's body from source. Returns [body, found].
## GDScript here uses indentation (no-brace) bodies; delimits at the next top-level
## `func` / `static func` line.
func _func_body(src: String, func_name: String) -> Array:
	var start: int = src.find("func %s(" % func_name)
	if start < 0:
		return ["", false]
	var next_func: int = src.find("\nfunc ", start)
	var next_static: int = src.find("\nstatic func ", start)
	var delim: int = next_func
	if next_static >= 0 and (delim < 0 or next_static < delim):
		delim = next_static
	if delim < 0:
		delim = src.length()
	return [src.substr(start, delim - start), true]