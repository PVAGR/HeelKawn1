extends SceneTree

## HK-TIME-ARCH-P2B verification: calendar/day-night uses SimulationClock COMMITTED
## canonical time (not compatibility tick / not target / not frame delta).
## Executes in a headless --script run; never boots Main, never touches autosave.
## Quits 0 on full PASS, 1 on failure.

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

	var q: float = float(tm.LEGACY_CORE_CANONICAL_SECONDS_PER_TRANSACTION)
	var base: float = float(tm.BASE_TICK_INTERVAL)
	var mult: float = float(tm.SPEED_MULTIPLIERS[0])
	var day_scale: int = SimTime.TICKS_PER_VISUAL_DAY
	var year_scale: int = SimTime.TICKS_PER_SIM_YEAR

	print("COMMITTED_CALENDAR begin")

	# Load-validation of BOTH edited production scripts (COMMAND_1 did not parse
	# ColonyHUD). A null result here means a parse/load error in the edit.
	var daynight_script: Script = load("res://scripts/world/DayNightCycle.gd")
	var hud_script: Script = load("res://scripts/ui/ColonyHUD.gd")
	_check("LOAD_DayNightCycle", daynight_script != null)
	_check("LOAD_ColonyHUD", hud_script != null)

	# --- TEST_A_QUANTUM ---
	print("TEST_A_QUANTUM")
	_check("A_q_formula", is_equal_approx(q, base * mult), "q=%s base*1x=%s" % [q, base * mult])
	_check("A_q_0_05", is_equal_approx(q, 0.05))

	# --- TEST_B_DAY_SCALE ---
	print("TEST_B_DAY_SCALE")
	var canonical_day: float = float(day_scale) * q
	_check("B_canonical_day_30", is_equal_approx(canonical_day, 30.0), "got %s" % canonical_day)

	# --- TEST_C_YEAR_SCALE ---
	print("TEST_C_YEAR_SCALE")
	var canonical_year: float = float(year_scale) * q
	_check("C_canonical_year_1500", is_equal_approx(canonical_year, 1500.0), "got %s" % canonical_year)

	# --- TEST_D_BOUNDARY_CONVERSION ---
	print("TEST_D_BOUNDARY_CONVERSION")
	_check("D_0_00->0", DayNightCycle.canonical_seconds_to_legacy_tick(0.00) == 0)
	_check("D_0_05->1", DayNightCycle.canonical_seconds_to_legacy_tick(0.05) == 1)
	_check("D_29_95->599", DayNightCycle.canonical_seconds_to_legacy_tick(29.95) == 599)
	_check("D_30_00->600", DayNightCycle.canonical_seconds_to_legacy_tick(30.00) == 600)
	_check("D_1499_95->29999", DayNightCycle.canonical_seconds_to_legacy_tick(1499.95) == 29999)
	_check("D_1500_00->30000", DayNightCycle.canonical_seconds_to_legacy_tick(1500.00) == 30000)

	# --- TEST_E_SIMTIME_EQUIVALENCE ---
	print("TEST_E_SIMTIME_EQUIVALENCE")
	var rep_ticks: Array[int] = [0, 1, 599, 600, 601, 29999, 30000, 30001]
	var e_ok: bool = true
	for t in rep_ticks:
		var canon: float = float(t) * q
		var converted: int = DayNightCycle.canonical_seconds_to_legacy_tick(canon)
		if converted != t:
			_check("E_tick_%d" % t, false, "converted=%d" % converted)
			e_ok = false
			continue
		var yr_a: int = SimTime.sim_year_index(t)
		var yr_b: int = SimTime.sim_year_index(converted)
		var day_a: int = SimTime.visual_day_within_sim_year(t)
		var day_b: int = SimTime.visual_day_within_sim_year(converted)
		var ph_a: float = DayNightCycle.phase_for_tick(t)
		var ph_b: float = DayNightCycle.phase_for_tick(converted)
		var hour_a: int = int(ph_a * 24.0) % 24
		var hour_b: int = int(ph_b * 24.0) % 24
		var night_a: bool = DayNightCycle.is_night_for_tick(t)
		var night_b: bool = DayNightCycle.is_night_for_tick(converted)
		if yr_a != yr_b or day_a != day_b or ph_a != ph_b or hour_a != hour_b or night_a != night_b:
			_check("E_equiv_%d" % t, false, "yr %d/%d day %d/%d ph %s/%s hour %d/%d night %s/%s" % [
				yr_a, yr_b, day_a, day_b, ph_a, ph_b, hour_a, hour_b, night_a, night_b
			])
			e_ok = false
	if e_ok:
		print("  PASS E_all_equiv")

	# --- TEST_F_TARGET_ONLY ---
	print("TEST_F_TARGET_ONLY")
	clk.reset()
	tm.ensure_legacy_bridge_initialized()
	clk.advance_target(300.0)  # target advances a lot
	var f_committed: float = clk.get_committed_world_time_seconds()
	var f_cal: int = DayNightCycle.get_current_legacy_calendar_tick()
	_check("F_committed_unchanged", f_committed == 0.0)
	_check("F_calendar_unchanged_0", f_cal == 0, "cal=%d (must not move with target)" % f_cal)

	# --- TEST_G_COMMITTED_ADVANCE ---
	# Advance committed through LEGITIMATE legacy bridge progress (real commit
	# path), not a direct lane commit.
	print("TEST_G_COMMITTED_ADVANCE")
	clk.reset()
	tm.ensure_legacy_bridge_initialized()
	clk.advance_target(300.0)
	for gi in range(10):
		tm._commit_legacy_core_quantum()
	var g_committed: float = clk.get_committed_world_time_seconds()
	_check("G_committed_advanced", is_equal_approx(g_committed, 10.0 * q), "committed=%s expected=0.5" % g_committed)
	var g_cal: int = DayNightCycle.get_current_legacy_calendar_tick()
	_check("G_calendar_advances", g_cal == 10, "cal=%d expected=10" % g_cal)

	# --- TEST_H_DAY_BOUNDARY ---
	print("TEST_H_DAY_BOUNDARY")
	var h599: int = DayNightCycle.canonical_seconds_to_legacy_tick(599.0 * q)
	var h600: int = DayNightCycle.canonical_seconds_to_legacy_tick(600.0 * q)
	_check("H_599", h599 == 599)
	_check("H_600", h600 == 600)
	_check("H_day_transition", SimTime.visual_day_within_sim_year(h600) == SimTime.visual_day_within_sim_year(h599) + 1,
		"day599=%d day600=%d" % [SimTime.visual_day_within_sim_year(h599), SimTime.visual_day_within_sim_year(h600)])

	# --- TEST_I_YEAR_BOUNDARY ---
	print("TEST_I_YEAR_BOUNDARY")
	var i_a: int = DayNightCycle.canonical_seconds_to_legacy_tick(29999.0 * q)
	var i_b: int = DayNightCycle.canonical_seconds_to_legacy_tick(30000.0 * q)
	_check("I_29999", i_a == 29999)
	_check("I_30000", i_b == 30000)
	_check("I_year_transition", SimTime.sim_year_index(i_b) == SimTime.sim_year_index(i_a) + 1,
		"yrA=%d yrB=%d" % [SimTime.sim_year_index(i_a), SimTime.sim_year_index(i_b)])

	# --- TEST_J_NIGHT_EQUIVALENCE ---
	print("TEST_J_NIGHT_EQUIVALENCE")
	var j_ok: bool = true
	for t in rep_ticks:
		var canon: float = float(t) * q
		var conv: int = DayNightCycle.canonical_seconds_to_legacy_tick(canon)
		var via_canon: bool = DayNightCycle.is_night_for_tick(conv)
		var direct: bool = DayNightCycle.is_night_for_tick(t)
		if via_canon != direct:
			_check("J_night_%d" % t, false, "via=%s direct=%s" % [via_canon, direct])
			j_ok = false
	if j_ok:
		print("  PASS J_all_night")

	# --- TEST_K_CURRENT_NOT_TARGET ---
	print("TEST_K_CURRENT_NOT_TARGET")
	clk.reset()
	tm.ensure_legacy_bridge_initialized()
	clk.advance_target(300.0)  # target => 300/0.05 = 6000 equivalent ticks
	# Advance committed through 600 real completed legacy transactions => 30.0
	# canonical seconds => 600 equivalent legacy ticks. No direct lane commit.
	for kk in range(600):
		tm._commit_legacy_core_quantum()
	var k_committed: float = clk.get_committed_world_time_seconds()
	var k_target: float = clk.get_target_world_time_seconds()
	var k_cal: int = DayNightCycle.get_current_legacy_calendar_tick()
	var k_expected_committed: int = DayNightCycle.canonical_seconds_to_legacy_tick(k_committed)
	var k_expected_target: int = DayNightCycle.canonical_seconds_to_legacy_tick(k_target)
	_check("K_committed_is_30", is_equal_approx(k_committed, 30.0), "committed=%s" % k_committed)
	_check("K_committed_neq_target_tick", k_expected_committed != k_expected_target,
		"committedTick=%d targetTick=%d" % [k_expected_committed, k_expected_target])
	_check("K_cal_equals_committed", k_cal == k_expected_committed, "cal=%d expectedCommitted=%d" % [k_cal, k_expected_committed])
	_check("K_cal_not_target", k_cal != k_expected_target, "cal=%d must NOT be target=%d" % [k_cal, k_expected_target])
	_check("K_cal_is_600", k_cal == 600, "cal=%d expected=600" % k_cal)

	# --- TEST_L_NO_CURRENT_COMPAT_SOURCE ---
	print("TEST_L_NO_CURRENT_COMPAT_SOURCE")
	var dnc_src: String = str(load("res://scripts/world/DayNightCycle.gd").source_code)
	var l_no_gm_tick: bool = not ("GameManager.tick_count" in dnc_src)
	var l_no_cur_tick: bool = not ("TickManager.current_tick" in dnc_src)
	var l_uses_committed: bool = ("get_committed_world_time_seconds" in dnc_src)
	_check("L_no_gm_tick_count_in_daynight", l_no_gm_tick)
	_check("L_no_cur_tick_in_daynight", l_no_cur_tick)
	_check("L_uses_committed", l_uses_committed)

	# --- TEST_M_TRIGGER_ORDER ---
	print("TEST_M_TRIGGER_ORDER")
	# Scope to JUST the _complete_pending_tick body so the _commit_legacy_core_quantum
	# FUNCTION DEFINITION later in the file is NOT counted as ordering evidence.
	var tm_src: String = str(load("res://autoloads/TickManager.gd").source_code)
	var complete_start: int = tm_src.find("func _complete_pending_tick")
	_check("M_complete_function_found", complete_start >= 0)
	var m_scoped: bool = complete_start >= 0
	var complete_end: int = tm_src.find("\nfunc ", complete_start + 1) if m_scoped else -1
	if complete_end < 0:
		complete_end = tm_src.length()
	var complete_body: String = tm_src.substr(complete_start, complete_end - complete_start)
	var commit_pos: int = complete_body.find("_commit_legacy_core_quantum()") if m_scoped else -1
	var emit_pos: int = complete_body.find("tick_processed.emit") if m_scoped else -1
	_check("M_commit_call_in_complete", commit_pos >= 0)
	_check("M_emit_in_complete", emit_pos >= 0)
	_check("M_commit_before_emit", commit_pos >= 0 and emit_pos >= 0 and commit_pos < emit_pos,
		"commit=%d emit=%d" % [commit_pos, emit_pos])
	_check("M_daynight_uses_tick_processed", "tick_processed.connect" in dnc_src)
	_check("M_daynight_not_game_tick", not ("game_tick.connect" in dnc_src))
	_check("M_current_from_committed", "get_current_legacy_calendar_tick" in dnc_src)

	# New-epoch cache reset: cache must not remain on a previous epoch/day after
	# committed resets backward (2026-08-XX P2B-FINALIZE). Instance-level check.
	var m_epoch: String = "STRUCTURAL_PASS"
	var dnc_instance: Object = DayNightCycle.new()
	if dnc_instance != null:
		clk.reset()
		tm.ensure_legacy_bridge_initialized()
		dnc_instance.set("_last_day", 10)
		dnc_instance.call("_on_tick", 0)
		var last_day: int = int(dnc_instance.get("_last_day"))
		if last_day == 0:
			m_epoch = "PASS"
		else:
			m_epoch = "FAIL last_day=%d expected=0" % last_day
		_check("M_epoch_cache_reset", last_day == 0, "last_day=%d expected=0" % last_day)
		dnc_instance.free()
	else:
		_check("M_epoch_cache_reset", false, "could not instantiate DayNightCycle")

	# --- TEST_N_P2A_REGRESSION ---
	print("TEST_N_P2A_REGRESSION")
	clk.reset()
	tm.set_speed_index(0)
	tm.ensure_legacy_bridge_initialized()
	clk.advance_target(q)
	tm._commit_legacy_core_quantum()
	var n1_legacy: float = clk.get_lane_applied_world_time_seconds(tm.LEGACY_CORE_LANE_ID)
	var n1_committed: float = clk.get_committed_world_time_seconds()
	_check("N_1x_advances_Q", is_equal_approx(n1_legacy, q) and is_equal_approx(n1_committed, q),
		"legacy=%s committed=%s" % [n1_legacy, n1_committed])
	var n_q_before: float = q
	tm.set_speed_index(5)
	var n_q_200: float = float(tm.LEGACY_CORE_CANONICAL_SECONDS_PER_TRANSACTION)
	_check("N_speed_does_not_change_q", is_equal_approx(n_q_before, n_q_200))
	clk.reset()
	tm.ensure_legacy_bridge_initialized()
	clk.advance_target(q * 20.0)
	tm._commit_legacy_core_quantum()
	var n_t_only_committed: float = clk.get_committed_world_time_seconds()
	_check("N_target_only_does_not_commit_all", is_equal_approx(n_t_only_committed, q),
		"committed=%s (must be exactly Q, not the target gap)" % n_t_only_committed)
	tm.set_speed_index(0)

	if _failures.size() == 0:
		print("COMMITTED_CALENDAR RESULT=PASS")
		quit(0)
	else:
		print("COMMITTED_CALENDAR RESULT=FAIL failures=%d" % _failures.size())
		for f in _failures:
			print("  failed: %s" % f)
		quit(1)
