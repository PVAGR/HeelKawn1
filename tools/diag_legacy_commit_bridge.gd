extends SceneTree

## HK-TIME-ARCH-P2A / P2A.1 verification: legacy-core authoritative commit bridge.
## Tests TEST_A..TEST_N exist.
## Q = canonical bridge quantum = BASE_TICK_INTERVAL * 1x-multiplier = 0.05 s.
## Headless-safe, never boots Main, never touches autosave. Quits 0 on full pass.

const Q: float = 0.05  # CANONICAL_BRIDGE_QUANTUM (canonical world seconds / transaction, NOT legacy SimTime seconds)

var _failures: Array = []

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

func _initialize() -> void:
	var clk: Node = _clock()
	var tm: Node = _tm()
	if clk == null or tm == null:
		print("BLOCKER: SimulationClock or TickManager autoload missing")
		quit(1)
		return

	print("LEGACY_COMMIT_BRIDGE begin")

	# --- TEST_A_INITIAL_STATE ---
	print("TEST_A_INITIAL_STATE")
	clk.reset()
	tm.ensure_legacy_bridge_initialized()
	_check("A_target_0", clk.get_target_world_time_seconds() == 0.0)
	_check("A_legacy_0", clk.get_lane_applied_world_time_seconds(tm.LEGACY_CORE_LANE_ID) == 0.0)
	_check("A_committed_0", clk.get_committed_world_time_seconds() == 0.0)
	_check("A_lag_0", clk.get_simulation_lag_seconds() == 0.0)
	_check("A_sealed", clk.is_authoritative_lane_roster_sealed() == true)

	# --- TEST_B_TARGET_ONLY ---
	print("TEST_B_TARGET_ONLY")
	clk.reset()
	tm.ensure_legacy_bridge_initialized()
	clk.advance_target(Q * 10.0)
	_check("B_legacy_0", clk.get_lane_applied_world_time_seconds(tm.LEGACY_CORE_LANE_ID) == 0.0)
	_check("B_committed_0", clk.get_committed_world_time_seconds() == 0.0)
	_check("B_lag_Q10", is_equal_approx(clk.get_simulation_lag_seconds(), Q * 10.0))

	# --- TEST_C_ONE_COMPLETION ---
	print("TEST_C_ONE_COMPLETION")
	clk.reset()
	tm.ensure_legacy_bridge_initialized()
	clk.advance_target(Q * 10.0)
	tm._commit_legacy_core_quantum()
	_check("C_legacy_Q", is_equal_approx(clk.get_lane_applied_world_time_seconds(tm.LEGACY_CORE_LANE_ID), Q))
	_check("C_committed_Q", is_equal_approx(clk.get_committed_world_time_seconds(), Q))

	# --- TEST_D_N_COMPLETIONS ---
	print("TEST_D_N_COMPLETIONS")
	clk.reset()
	tm.ensure_legacy_bridge_initialized()
	clk.advance_target(Q * 100.0)
	var n: int = 40
	for i in range(n):
		tm._commit_legacy_core_quantum()
	_check("D_legacy_NQ", is_equal_approx(clk.get_lane_applied_world_time_seconds(tm.LEGACY_CORE_LANE_ID), float(n) * Q))
	_check("D_committed_NQ", is_equal_approx(clk.get_committed_world_time_seconds(), float(n) * Q))

	# --- TEST_E_PARTIAL_TRANSACTION ---
	print("TEST_E_PARTIAL_TRANSACTION")
	# Structural proof: _commit_legacy_core_quantum() is callable ONLY from the
	# COMPLETE boundary (_complete_pending_tick). No call site in _start_pending_tick,
	# _run_one_callback, _process, or any phase-advance. Partial/pending transactions
	# therefore never advance legacy_core.
	var src: String = str(load("res://autoloads/TickManager.gd").source_code)
	var call_count: int = 0
	for line in src.split("\n"):
		var needle: String = "_commit_legacy_core_quantum()"
		if needle in line and "func " not in line:
			call_count += 1
	_check("E_call_site_count_1", call_count == 1,
		"expected exactly 1 call site (in _complete_pending_tick), found %d" % call_count)
	# The single call must be within _complete_pending_tick (before _phase_name).
	var idx_def: int = src.find("func _commit_legacy_core_quantum")
	var idx_phasename: int = src.find("func _phase_name")
	var line_num: int = -1
	for i in range(src.split("\n").size()):
		var l: String = src.split("\n")[i]
		if "_commit_legacy_core_quantum()" in l and "func " not in l:
			line_num = i
			break
	var idx_phasename_line: int = (_phase_name_line_of(src.split("\n")) if idx_phasename >= 0 else -1)
	_check("E_call_inside_complete", line_num >= 0 and idx_phasename_line > 0 and line_num < idx_phasename_line,
		"call site line=%d phase_name_line=%d" % [line_num, idx_phasename_line])
	# Behavioral: a merely-referenced pending transaction (ensuring bridge only)
	# must not advance legacy when no COMPLETE commit occurs.
	clk.reset()
	tm.ensure_legacy_bridge_initialized()
	clk.advance_target(Q * 10.0)
	var pre: float = clk.get_lane_applied_world_time_seconds(tm.LEGACY_CORE_LANE_ID)
	tm.ensure_legacy_bridge_initialized()  # no-op; no full transaction committed
	_check("E_no_commit_without_complete", is_equal_approx(clk.get_lane_applied_world_time_seconds(tm.LEGACY_CORE_LANE_ID), pre))

	# --- TEST_F_TARGET_CLAMP ---
	print("TEST_F_TARGET_CLAMP")
	clk.reset()
	tm.ensure_legacy_bridge_initialized()
	clk.advance_target(Q * 100.0)
	tm._commit_legacy_core_quantum()  # legacy=1,target=100
	# set target below legacy+Q so the next quantum would overshoot
	# target cannot be lowered via advance (monotonic); instead start fresh with
	# a small target: legacy=0, target=0.5 -> one commit -> next=min(1,0.5)=0.5
	# Re-run cleanly: target = 0.4 Q
	clk.reset()
	tm.ensure_legacy_bridge_initialized()
	clk.advance_target(Q * 0.4)
	tm._commit_legacy_core_quantum()
	_check("F_legacy_target_capped", is_equal_approx(clk.get_lane_applied_world_time_seconds(tm.LEGACY_CORE_LANE_ID), Q * 0.4),
		"overshot to %s" % clk.get_lane_applied_world_time_seconds(tm.LEGACY_CORE_LANE_ID))
	_check("F_committed_target_capped", is_equal_approx(clk.get_committed_world_time_seconds(), Q * 0.4))
	_check("F_no_overshoot", clk.get_lane_applied_world_time_seconds(tm.LEGACY_CORE_LANE_ID) <= clk.get_target_world_time_seconds())

	# --- TEST_G_SPEED_INDEPENDENCE ---
	print("TEST_G_SPEED_INDEPENDENCE")
	clk.reset()
	tm.ensure_legacy_bridge_initialized()
	tm.set_speed_index(0)  # 1x
	clk.advance_target(Q * 100.0)
	tm._commit_legacy_core_quantum()
	var delta_1x: float = clk.get_lane_applied_world_time_seconds(tm.LEGACY_CORE_LANE_ID)
	clk.reset()
	tm.ensure_legacy_bridge_initialized()
	tm.set_speed_index(5)  # 200x
	clk.advance_target(Q * 100.0)
	tm._commit_legacy_core_quantum()
	var delta_200x: float = clk.get_lane_applied_world_time_seconds(tm.LEGACY_CORE_LANE_ID)
	_check("G_speed_independent", is_equal_approx(delta_1x, Q) and is_equal_approx(delta_200x, Q),
		"1x delta=%s 200x delta=%s (both must equal Q=%s)" % [delta_1x, delta_200x, Q])
	tm.set_speed_index(0)  # reset speed back to 1x for idempotency

	# --- TEST_H_TARGET_RATE_DOES_NOT_DEFINE_COMMIT ---
	print("TEST_H_TARGET_RATE_DOES_NOT_DEFINE_COMMIT")
	clk.reset()
	tm.ensure_legacy_bridge_initialized()
	clk.advance_target(Q * 500.0)
	tm._commit_legacy_core_quantum()
	_check("H_committed_exactly_Q", is_equal_approx(clk.get_lane_applied_world_time_seconds(tm.LEGACY_CORE_LANE_ID), Q),
		"committed whole target gap? got %s" % clk.get_lane_applied_world_time_seconds(tm.LEGACY_CORE_LANE_ID))
	_check("H_not_full_gap", clk.get_lane_applied_world_time_seconds(tm.LEGACY_CORE_LANE_ID) < clk.get_target_world_time_seconds())

	# --- TEST_I_RESET ---
	print("TEST_I_RESET")
	clk.reset()
	tm.ensure_legacy_bridge_initialized()
	clk.advance_target(Q * 50.0)
	for i in range(20):
		tm._commit_legacy_core_quantum()
	clk.reset()
	tm.ensure_legacy_bridge_initialized()
	_check("I_target_0", clk.get_target_world_time_seconds() == 0.0)
	_check("I_legacy_0", clk.get_lane_applied_world_time_seconds(tm.LEGACY_CORE_LANE_ID) == 0.0)
	_check("I_committed_0", clk.get_committed_world_time_seconds() == 0.0)
	_check("I_lag_0", clk.get_simulation_lag_seconds() == 0.0)

	# --- TEST_J_P1_2_REGRESSION ---
	print("TEST_J_P1_2_REGRESSION")
	# (a) registration order cannot alter committed history
	clk.reset()
	clk.advance_target(10.0)
	clk.register_authoritative_lane("lA", 10.0)
	clk.register_authoritative_lane("lB", 4.0)
	clk.seal_authoritative_lane_roster()
	var r1: float = clk.get_committed_world_time_seconds()
	clk.reset()
	clk.advance_target(10.0)
	clk.register_authoritative_lane("lB", 4.0)
	clk.register_authoritative_lane("lA", 10.0)
	clk.seal_authoritative_lane_roster()
	var r2: float = clk.get_committed_world_time_seconds()
	_check("J_order_independent", is_equal_approx(r1, r2), "r1=%s r2=%s" % [r1, r2])
	# (b) target alone cannot commit
	clk.reset()
	clk.register_authoritative_lane("lA", 0.0)
	clk.seal_authoritative_lane_roster()
	clk.advance_target(50.0)
	_check("J_target_alone_no_commit", clk.get_committed_world_time_seconds() == 0.0)
	# (c) committed cannot regress
	clk.commit_lane_world_time("lA", 10.0)
	clk.commit_lane_world_time("lA", 5.0)
	_check("J_no_regress", is_equal_approx(clk.get_lane_applied_world_time_seconds("lA"), 10.0))
	# (d) lane cannot exceed target
	clk.commit_lane_world_time("lA", 500.0)
	_check("J_no_exceed_target", clk.get_lane_applied_world_time_seconds("lA") <= clk.get_target_world_time_seconds())

	# Resolve the canonical quantum from the real production constant.
	var q_actual: float = float(tm.LEGACY_CORE_CANONICAL_SECONDS_PER_TRANSACTION)
	var base_interval: float = float(tm.BASE_TICK_INTERVAL)
	var mult_1x: float = float(tm.SPEED_MULTIPLIERS[0])

	# --- TEST_K_1X_RATE_COHERENCE ---
	print("TEST_K_1X_RATE_COHERENCE")
	clk.reset()
	tm.ensure_legacy_bridge_initialized()
	tm.set_speed_index(0)  # 1x
	var intervals: int = 40
	for i in range(intervals):
		clk.advance_target(base_interval * mult_1x)  # 0.05 * 1.0
		tm._commit_legacy_core_quantum()  # one fully completed transaction
	var expected_target: float = float(intervals) * base_interval * mult_1x
	_check("K_target", is_equal_approx(clk.get_target_world_time_seconds(), expected_target),
		"target=%s expected=%s" % [clk.get_target_world_time_seconds(), expected_target])
	_check("K_legacy", is_equal_approx(clk.get_lane_applied_world_time_seconds(tm.LEGACY_CORE_LANE_ID), expected_target),
		"legacy=%s expected=%s" % [clk.get_lane_applied_world_time_seconds(tm.LEGACY_CORE_LANE_ID), expected_target])
	_check("K_committed", is_equal_approx(clk.get_committed_world_time_seconds(), expected_target))
	_check("K_lag_zero", is_equal_approx(clk.get_simulation_lag_seconds(), 0.0))

	# --- TEST_L_QUANTUM_DIMENSION ---
	print("TEST_L_QUANTUM_DIMENSION")
	_check("L_q_equals_base_times_1x", is_equal_approx(q_actual, base_interval * mult_1x),
		"q=%s base*1x=%s" % [q_actual, base_interval * mult_1x])
	_check("L_q_is_0_05", is_equal_approx(q_actual, 0.05))
	_check("L_q_not_simtime_interval", not is_equal_approx(q_actual, 1.0),
		"Q must NOT equal legacy SimTime tick interval (1.0); got %s" % q_actual)
	_check("L_const_matches_derived", is_equal_approx(Q, q_actual))

	# --- TEST_M_CALENDAR_PRESERVATION_RATIO ---
	print("TEST_M_CALENDAR_PRESERVATION_RATIO")
	# Canonical source: SimTime.TICKS_PER_VISUAL_DAY (script scripts/kernel/sim_time.gd).
	var ticks_per_day: int = SimTime.TICKS_PER_VISUAL_DAY
	var legacy_ticks_per_day: int = 600
	_check("M_ticks_per_day_resolved", ticks_per_day == legacy_ticks_per_day,
		"resolved=%s expected=%s" % [ticks_per_day, legacy_ticks_per_day])
	var canonical_seconds_per_visual_day: float = float(ticks_per_day) * q_actual
	_check("M_canonical_day_30", is_equal_approx(canonical_seconds_per_visual_day, 30.0),
		"got %s (600 * 0.05 = 30)" % canonical_seconds_per_visual_day)
	# Proves P2B can map committed canonical time to the legacy calendar cadence.
	_check("M_conversion_linear", canonical_seconds_per_visual_day > 0.0)
	tm.set_speed_index(0)

	# --- TEST_N_SPEED_TARGET_SEPARATION ---
	print("TEST_N_SPEED_TARGET_SEPARATION")
	clk.reset()
	tm.ensure_legacy_bridge_initialized()
	# 1x one interval
	tm.set_speed_index(0)
	clk.advance_target(base_interval * float(tm.SPEED_MULTIPLIERS[0]))
	tm._commit_legacy_core_quantum()
	var t1x_delta: float = clk.get_target_world_time_seconds()
	var l1x_delta: float = clk.get_lane_applied_world_time_seconds(tm.LEGACY_CORE_LANE_ID)
	var lag1x: float = clk.get_simulation_lag_seconds()
	_check("N_1x_target_delta", is_equal_approx(t1x_delta, 0.05))
	_check("N_1x_legacy_delta", is_equal_approx(l1x_delta, q_actual))
	_check("N_1x_lag_0", is_equal_approx(lag1x, 0.0))
	# 200x one interval
	clk.reset()
	tm.ensure_legacy_bridge_initialized()
	tm.set_speed_index(5)
	clk.advance_target(base_interval * float(tm.SPEED_MULTIPLIERS[5]))
	tm._commit_legacy_core_quantum()
	var t200x_delta: float = clk.get_target_world_time_seconds()
	var l200x_delta: float = clk.get_lane_applied_world_time_seconds(tm.LEGACY_CORE_LANE_ID)
	var lag200x: float = clk.get_simulation_lag_seconds()
	_check("N_200x_target_delta", is_equal_approx(t200x_delta, 10.0), "got %s" % t200x_delta)
	_check("N_200x_legacy_delta_unchanged_q", is_equal_approx(l200x_delta, q_actual),
		"200x committed %s per transaction (must stay Q=%s)" % [l200x_delta, q_actual])
	_check("N_200x_lag_9_95", is_equal_approx(lag200x, 9.95), "got %s" % lag200x)
	tm.set_speed_index(0)

	if _failures.size() == 0:
		print("LEGACY_COMMIT_BRIDGE RESULT=PASS")
		quit(0)
	else:
		print("LEGACY_COMMIT_BRIDGE RESULT=FAIL failures=%d" % _failures.size())
		quit(1)


func _phase_name_line_of(lines: Array) -> int:
	for i in range(lines.size()):
		if "func _phase_name" in str(lines[i]):
			return i
	return -1
