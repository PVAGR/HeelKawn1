extends SceneTree

## Phase 1.2 clock-contract finalization (roster atomicity). Runs TEST_A..TEST_O
## from HK-TIME-ARCH-P1.2 against the real SimulationClock autoload.
## Headless-safe, never boots Main, never touches autosave. Quits 0 on full pass.

var _failures: Array = []

func _check(label: String, cond: bool, detail: String = "") -> void:
	if cond:
		print("  PASS %s" % label)
	else:
		_failures.append(label)
		print("  FAIL %s  %s" % [label, detail])

func _clock() -> Node:
	return get_root().get_node_or_null("SimulationClock")

func _initialize() -> void:
	var clk: Node = _clock()
	if clk == null:
		print("BLOCKER: SimulationClock autoload not found under /root")
		quit(1)
		return

	print("CLOCK_CONTRACT begin")

	# --- TEST_A_RESET ---
	print("TEST_A_RESET")
	clk.reset()
	_check("A_target_zero", clk.get_target_world_time_seconds() == 0.0)
	_check("A_committed_zero", clk.get_committed_world_time_seconds() == 0.0)
	_check("A_lag_zero", clk.get_simulation_lag_seconds() == 0.0)
	_check("A_roster_unsealed", clk.is_authoritative_lane_roster_sealed() == false)

	# --- TEST_B_TARGET_ONLY ---
	print("TEST_B_TARGET_ONLY")
	clk.reset()
	clk.advance_target(10.0)
	_check("B_target_10", is_equal_approx(clk.get_target_world_time_seconds(), 10.0))
	_check("B_committed_0", clk.get_committed_world_time_seconds() == 0.0)
	_check("B_lag_10", is_equal_approx(clk.get_simulation_lag_seconds(), 10.0))

	# --- TEST_C_REGISTRATION_DOES_NOT_COMMIT ---
	print("TEST_C_REGISTRATION_DOES_NOT_COMMIT")
	clk.reset()
	clk.advance_target(10.0)
	var ok_a: bool = clk.register_authoritative_lane("lane_A", 10.0)
	_check("C_register_A_ok", ok_a == true)
	_check("C_A_at_10", is_equal_approx(clk.get_lane_applied_world_time_seconds("lane_A"), 10.0))
	_check("C_committed_still_0_after_A", clk.get_committed_world_time_seconds() == 0.0,
		"registration advanced committed to %s" % clk.get_committed_world_time_seconds())
	var ok_b: bool = clk.register_authoritative_lane("lane_B", 0.0)
	_check("C_register_B_ok", ok_b == true)
	_check("C_B_at_0", is_equal_approx(clk.get_lane_applied_world_time_seconds("lane_B"), 0.0))
	_check("C_committed_still_0_after_B", clk.get_committed_world_time_seconds() == 0.0,
		"registration order must NOT commit history; got %s" % clk.get_committed_world_time_seconds())

	# --- TEST_D_REVERSED_REGISTRATION_ORDER ---
	print("TEST_D_REVERSED_REGISTRATION_ORDER")
	clk.reset()
	clk.advance_target(10.0)
	clk.register_authoritative_lane("lane_B", 0.0)
	clk.register_authoritative_lane("lane_A", 10.0)
	_check("D_committed_0_after_register", clk.get_committed_world_time_seconds() == 0.0)
	clk.seal_authoritative_lane_roster()
	_check("D_committed_0_after_seal", clk.get_committed_world_time_seconds() == 0.0,
		"got %s (min(0,10)=0 expected)" % clk.get_committed_world_time_seconds())

	# --- TEST_E_SEAL ---
	print("TEST_E_SEAL")
	clk.reset()
	clk.advance_target(10.0)
	clk.register_authoritative_lane("lane_A", 10.0)
	clk.register_authoritative_lane("lane_B", 0.0)
	clk.seal_authoritative_lane_roster()
	_check("E_sealed_true", clk.is_authoritative_lane_roster_sealed() == true)
	_check("E_committed_0", clk.get_committed_world_time_seconds() == 0.0,
		"got %s (B at 0 holds committed at 0)" % clk.get_committed_world_time_seconds())

	# --- TEST_F_PARTIAL_PROGRESS ---
	print("TEST_F_PARTIAL_PROGRESS")
	clk.commit_lane_world_time("lane_B", 4.0)
	_check("F_committed_4", is_equal_approx(clk.get_committed_world_time_seconds(), 4.0))
	_check("F_lag_6", is_equal_approx(clk.get_simulation_lag_seconds(), 6.0))

	# --- TEST_G_COMPLETE_PROGRESS ---
	print("TEST_G_COMPLETE_PROGRESS")
	clk.commit_lane_world_time("lane_B", 10.0)
	_check("G_committed_10", is_equal_approx(clk.get_committed_world_time_seconds(), 10.0))
	_check("G_lag_0", clk.get_simulation_lag_seconds() == 0.0)

	# --- TEST_H_PRESEAL_COMMITS ---
	print("TEST_H_PRESEAL_COMMITS")
	clk.reset()
	clk.advance_target(10.0)
	clk.register_authoritative_lane("lane_A", 0.0)
	clk.register_authoritative_lane("lane_B", 0.0)
	clk.commit_lane_world_time("lane_A", 10.0)
	clk.commit_lane_world_time("lane_B", 5.0)
	_check("H_committed_0_while_open", clk.get_committed_world_time_seconds() == 0.0,
		"preseal commit advanced committed to %s" % clk.get_committed_world_time_seconds())
	clk.seal_authoritative_lane_roster()
	_check("H_committed_5_after_seal", is_equal_approx(clk.get_committed_world_time_seconds(), 5.0),
		"got %s (min(10,5)=5)" % clk.get_committed_world_time_seconds())

	# --- TEST_I_STARTUP_INITIAL_ABOVE_TARGET ---
	print("TEST_I_STARTUP_INITIAL_ABOVE_TARGET")
	clk.reset()
	clk.advance_target(10.0)
	var ok_c: bool = clk.register_authoritative_lane("lane_C", 20.0)
	_check("I_register_C_failed", ok_c == false)
	_check("I_C_not_authoritative", clk.get_lane_applied_world_time_seconds("lane_C") == 0.0)
	_check("I_committed_unchanged", clk.get_committed_world_time_seconds() == 0.0)

	# --- TEST_J_LATE_MISSING_STARTUP_LANE ---
	print("TEST_J_LATE_MISSING_STARTUP_LANE")
	clk.reset()
	clk.advance_target(20.0)
	clk.register_authoritative_lane("lane_A", 0.0)
	clk.seal_authoritative_lane_roster()
	clk.commit_lane_world_time("lane_A", 10.0)
	_check("J_pre_committed_10", is_equal_approx(clk.get_committed_world_time_seconds(), 10.0))
	var ok_d: bool = clk.register_authoritative_lane("lane_D", 0.0)  # late startup lane
	_check("J_register_D_failed", ok_d == false)
	_check("J_D_not_clamped_forward", clk.get_lane_applied_world_time_seconds("lane_D") == 0.0,
		"D was clamped to %s" % clk.get_lane_applied_world_time_seconds("lane_D"))
	_check("J_committed_unchanged", is_equal_approx(clk.get_committed_world_time_seconds(), 10.0))

	# --- TEST_K_DYNAMIC_LANE ---
	print("TEST_K_DYNAMIC_LANE")
	clk.reset()
	clk.advance_target(20.0)
	clk.register_authoritative_lane("lane_A", 0.0)
	clk.register_authoritative_lane("lane_B", 0.0)
	clk.seal_authoritative_lane_roster()
	clk.commit_lane_world_time("lane_A", 10.0)
	clk.commit_lane_world_time("lane_B", 10.0)
	_check("K_pre_committed_10", is_equal_approx(clk.get_committed_world_time_seconds(), 10.0))
	var ok_new: bool = clk.register_dynamic_authoritative_lane("NEW_ENTITY")
	_check("K_dynamic_ok", ok_new == true)
	_check("K_new_applied_10", is_equal_approx(clk.get_lane_applied_world_time_seconds("NEW_ENTITY"), 10.0),
		"NEW_ENTITY frontier=%s" % clk.get_lane_applied_world_time_seconds("NEW_ENTITY"))
	_check("K_committed_still_10", is_equal_approx(clk.get_committed_world_time_seconds(), 10.0))
	clk.commit_lane_world_time("lane_A", 20.0)
	clk.commit_lane_world_time("lane_B", 20.0)
	_check("K_committed_held_10_by_new", is_equal_approx(clk.get_committed_world_time_seconds(), 10.0),
		"NEW_ENTITY at 10 should hold committed at 10; got %s" % clk.get_committed_world_time_seconds())
	clk.commit_lane_world_time("NEW_ENTITY", 20.0)
	_check("K_committed_20", is_equal_approx(clk.get_committed_world_time_seconds(), 20.0))

	# --- TEST_L_NONAUTHORITATIVE ---
	print("TEST_L_NONAUTHORITATIVE")
	clk.reset()
	clk.advance_target(10.0)
	clk.register_authoritative_lane("lane_A", 0.0)
	clk.register_authoritative_lane("lane_B", 0.0)
	clk.seal_authoritative_lane_roster()
	clk.commit_lane_world_time("lane_A", 10.0)
	clk.commit_lane_world_time("lane_B", 10.0)
	clk.commit_lane_world_time("UI", 0.0)
	_check("L_committed_10", is_equal_approx(clk.get_committed_world_time_seconds(), 10.0),
		"non-authoritative UI froze committed at %s" % clk.get_committed_world_time_seconds())

	# --- TEST_M_BACKWARD_COMMIT ---
	print("TEST_M_BACKWARD_COMMIT")
	clk.reset()
	clk.advance_target(10.0)
	clk.register_authoritative_lane("lane_A", 0.0)
	clk.seal_authoritative_lane_roster()
	clk.commit_lane_world_time("lane_A", 10.0)
	_check("M_pre_A_10", is_equal_approx(clk.get_lane_applied_world_time_seconds("lane_A"), 10.0))
	var m_result: bool = clk.commit_lane_world_time("lane_A", 5.0)
	_check("M_backward_rejected", m_result == false)
	_check("M_A_stays_10", is_equal_approx(clk.get_lane_applied_world_time_seconds("lane_A"), 10.0))
	_check("M_committed_not_regressed", is_equal_approx(clk.get_committed_world_time_seconds(), 10.0))

	# --- TEST_N_COMMIT_ABOVE_TARGET ---
	print("TEST_N_COMMIT_ABOVE_TARGET")
	clk.reset()
	clk.advance_target(10.0)
	clk.register_authoritative_lane("lane_A", 0.0)
	clk.seal_authoritative_lane_roster()
	clk.commit_lane_world_time("lane_A", 5.0)
	var n_result: bool = clk.commit_lane_world_time("lane_A", 20.0)
	_check("N_overshoot_rejected", n_result == false)
	_check("N_A_not_exceed_target", clk.get_lane_applied_world_time_seconds("lane_A") <= 10.0,
		"A exceeded target: %s" % clk.get_lane_applied_world_time_seconds("lane_A"))

	# --- TEST_O_REGISTRATION_ORDER_EQUIVALENCE ---
	print("TEST_O_REGISTRATION_ORDER_EQUIVALENCE")
	# Scenario 1: A=10 then B=4
	clk.reset()
	clk.advance_target(10.0)
	clk.register_authoritative_lane("lane_A", 10.0)
	clk.register_authoritative_lane("lane_B", 4.0)
	clk.seal_authoritative_lane_roster()
	var s1: float = clk.get_committed_world_time_seconds()
	# Scenario 2: B=4 then A=10
	clk.reset()
	clk.advance_target(10.0)
	clk.register_authoritative_lane("lane_B", 4.0)
	clk.register_authoritative_lane("lane_A", 10.0)
	clk.seal_authoritative_lane_roster()
	var s2: float = clk.get_committed_world_time_seconds()
	_check("O_order_equiv_identical", is_equal_approx(s1, s2),
		"scenario1 committed=%s scenario2 committed=%s" % [s1, s2])
	_check("O_order_equiv_value", is_equal_approx(s1, 4.0), "base committed=%s" % s1)

	if _failures.size() == 0:
		print("CLOCK_CONTRACT RESULT=PASS")
		quit(0)
	else:
		print("CLOCK_CONTRACT RESULT=FAIL failures=%d" % _failures.size())
		quit(1)
