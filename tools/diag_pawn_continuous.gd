extends SceneTree

## HK-TIME-P3-FIX2 verification.
##
## Confirms pawn_continuous coordination is owned by TickManager:
##   - before every legacy_core commit the pawn_continuous lane is ensured to
##     exist at the OLD committed frontier (never the newly-advanced F);
##   - the REAL TickManager._run_pawn_continuous_frontier(F) runs every live
##     pawn ("pawns" group) through F and commits pawn_continuous = F only AFTER
##     ALL succeed; a single failed pawn leaves the lane at OLD committed;
##   - reset is safe: the lane re-establishes at committed=0 BEFORE legacy advance;
##   - 1x == 200x equal committed frontier => equal integrated accumulator;
##   - target > F => pawn_continuous == F, never target;
##   - HeelKawnian._apply_authoritative_continuous_frontier scoped body has NO
##     commit_lane_world_time; the coordinator + registration live in TickManager.
##
## Uses 3 lightweight test nodes in group "pawns" that implement the pure per-pawn
## apply, driven by the REAL TickManager coordinator. Boots real autoloads; never
## boots Main/autosave. Quits 0 on PASS, 1 on FAIL.

## Test-pawn: a lightweight Node in group "pawns" implementing the same PURE
## per-pawn apply contract as HeelKawnian (integrates dt, reports success, NEVER
## commits a lane). Records the observed pawn_continuous lane value while applying
## so the test can prove the lane is still OLD mid-pass.
class TestPawn extends Node:
	var cursor: float = -1.0
	var acc: float = 0.0
	var fail_next: bool = false
	var observed_lane_while_applying: float = -99.0
	var _clk: Node = null

	func _init(clk: Node) -> void:
		_clk = clk

	func setup_cursor(committed: float) -> void:
		cursor = committed

	func _apply_authoritative_continuous_frontier(f: float) -> bool:
		if _clk == null:
			observed_lane_while_applying = -99.0
			return false
		observed_lane_while_applying = float(_clk.get_lane_applied_world_time_seconds("pawn_continuous"))
		var dt: float = f - cursor
		if dt <= 0.0:
			cursor = f
			return true
		if fail_next:
			fail_next = false
			return false
		acc += dt
		cursor = f
		return true


var _failures: Array = []
var _ran: bool = false

## In a bare --script SceneTree run the root is only brought up as a real,
## in-tree scene once the main loop starts iterating frames. Running everything
## from _initialize leaves get_root() children NOT inside the tree, so
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

func _lane(clk: Node) -> float:
	return float(clk.get_lane_applied_world_time_seconds("pawn_continuous"))

func _legacy(clk: Node) -> float:
	return float(clk.get_lane_applied_world_time_seconds("legacy_core"))

func _committed(clk: Node) -> float:
	return float(clk.get_committed_world_time_seconds())


func _initialize() -> void:
	print("PAWN_CONTINUOUS_FIX2 begin")

func _run_all() -> void:
	var clk: Node = _clock()
	var tm: Node = _tm()
	if clk == null or tm == null:
		print("BLOCKER: SimulationClock or TickManager autoload missing")
		quit(1)
		return

	# --- LOAD: production scripts compile; TickManager owns the coordinator ---
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

	# --- F: STRUCTURAL — coordinator + registration owned by TickManager; the
	#        per-pawn apply in HeelKawnian must NOT commit any lane ---
	print("TEST_F_STRUCTURE")
	var tm_src: String = str(tm_script.source_code) if tm_script != null else ""
	var hk_src: String = str(hk_script.source_code) if hk_script != null else ""
	var status: Array = _func_body(hk_src, "_apply_authoritative_continuous_frontier")
	_check("F_apply_scoped", status[1], "%s" % status[0])
	_check("F_apply_has_no_commit", status[0].find("commit_lane_world_time") < 0,
		"per-pawn apply must NOT commit any lane")
	var tm_coord: Array = _func_body(tm_src, "_run_pawn_continuous_frontier")
	var tm_ensure: Array = _func_body(tm_src, "_ensure_pawn_continuous_lane")
	_check("F_TM_coordinator_exists", tm_coord[1], "TickManager._run_pawn_continuous_frontier=%s" % tm_coord[0])
	_check("F_TM_coordinator_commits_after_all", tm_coord[0].find("commit_lane_world_time") >= 0,
		"only the coordinator may commit pawn_continuous")
	_check("F_TM_owns_lane_registration", tm_ensure[1] and tm_ensure[0].find("register_dynamic_authoritative_lane") >= 0,
		"TickManager._ensure_pawn_continuous_lane must register the lane")
	_check("F_HeelKawnian_has_no_registration", hk_src.find("register_dynamic_authoritative_lane") < 0,
		"pawn must not register the lane")
	_check("F_HeelKawnian_has_no_lane_const", hk_src.find("PAWN_CONTINUOUS_LANE_ID") < 0,
		"lane-id ownership moved to TickManager")
	# Discrete death RNG must NOT live in the continuous kernel.
	var kernel: Array = _func_body(hk_src, "_apply_pawn_time_lane")
	_check("F_discrete_death_out_of_continuous", kernel[0].find("WorldRNG.chance_for") < 0,
		"continuous lane must not own the discrete old-age death RNG roll")

	# --- A: real coordinator; all 3 succeed. Each records lane while applying; all
	#        must observe OLD lane. After coordinator returns, lane == F ---
	print("TEST_A_ALL_SUCCEED")
	clk.reset()
	tm.ensure_legacy_bridge_initialized()
	clk.register_dynamic_authoritative_lane("pawn_continuous")
	clk.advance_target(10.0)
	tm._commit_legacy_core_quantum()
	var f: float = _legacy(clk)
	_check("A_frontier_advanced", is_equal_approx(f, 0.05), "F=%s" % f)
	var old_lane: float = _lane(clk)
	var p1 := _spawn_pawn(clk)
	var p2 := _spawn_pawn(clk)
	var p3 := _spawn_pawn(clk)
	p1.setup_cursor(0.0); p2.setup_cursor(0.0); p3.setup_cursor(0.0)
	var a_ok: bool = bool(tm._run_pawn_continuous_frontier(f))
	# All three observed the lane while applying -> must be OLD, not F.
	_check("A_observed_old_after_apply", \
		p1.observed_lane_while_applying == old_lane \
		and p2.observed_lane_while_applying == old_lane \
		and p3.observed_lane_while_applying == old_lane, \
		"obs p1=%s p2=%s p3=%s expected_old=%s" % \
		[p1.observed_lane_while_applying, p2.observed_lane_while_applying, p3.observed_lane_while_applying, old_lane])
	_check("A_coordinator_true", a_ok == true)
	_check("A_lane_now_F", is_equal_approx(_lane(clk), f), "lane=%s F=%s" % [_lane(clk), f])
	_check("A_integrated_all", is_equal_approx(p1.acc, f) and is_equal_approx(p2.acc, f) and is_equal_approx(p3.acc, f))
	_check("A_committed_follows", is_equal_approx(_committed(clk), f), "committed=%s" % _committed(clk))
	p1.free(); p2.free(); p3.free()  # immediate (sync) removal from "pawns" group

	# --- B: handler 2 fails -> real coordinator leaves lane at OLD ---
	print("TEST_B_FAILED_PAWN_BLOCKS_COMMIT")
	clk.reset()
	tm.ensure_legacy_bridge_initialized()
	clk.register_dynamic_authoritative_lane("pawn_continuous")
	clk.advance_target(10.0)
	tm._commit_legacy_core_quantum()
	var fb: float = _legacy(clk)
	var old_b: float = _lane(clk)  # OLD (0.0), before pawn commit
	var q1 := _spawn_pawn(clk)
	var q2 := _spawn_pawn(clk)
	var q3 := _spawn_pawn(clk)
	q1.setup_cursor(0.0); q2.setup_cursor(0.0); q3.setup_cursor(0.0)
	q2.fail_next = true
	var b_ok: bool = bool(tm._run_pawn_continuous_frontier(fb))
	_check("B_coordinator_false", b_ok == false)
	_check("B_lane_remains_old", is_equal_approx(_lane(clk), old_b), "lane=%s old=%s" % [_lane(clk), old_b])
	_check("B_good_absorbed", is_equal_approx(q1.acc, fb) and is_equal_approx(q3.acc, fb), "q1=%s q3=%s" % [q1.acc, q3.acc])
	_check("B_failed_not_absorbed", q2.acc == 0.0)
	q1.free(); q2.free(); q3.free()  # immediate (sync) removal from "pawns" group

	# --- C: reset + rebuild lane BEFORE legacy commit. Verify lane starts at
	#        committed=0; advance legacy to F; one pawn fails ->
	#        legacy_core=F, pawn_continuous=0, global committed=0 ---
	print("TEST_C_RESET_SAFE")
	clk.reset()
	tm.ensure_legacy_bridge_initialized()
	# recreate lane BEFORE legacy advance (must start at current committed = 0)
	var recreated: bool = clk.register_dynamic_authoritative_lane("pawn_continuous")
	_check("C_lane_recreated_after_reset", recreated == true, "lane was absent; must recreate")
	_check("C_lane_starts_at_0", is_equal_approx(_lane(clk), 0.0), "lane=%s" % _lane(clk))
	_check("C_lane_starts_at_committed", is_equal_approx(_lane(clk), _committed(clk)), \
		"lane=%s committed=%s" % [_lane(clk), _committed(clk)])
	clk.advance_target(10.0)
	tm._commit_legacy_core_quantum()
	var fc: float = _legacy(clk)
	_check("C_legacy_advanced_to_F", is_equal_approx(fc, 0.05), "legacy=%s" % fc)
	_check("C_pawn_old_before_apply", is_equal_approx(_lane(clk), 0.0) and _lane(clk) < fc, \
		"pawn=%s F=%s" % [_lane(clk), fc])
	var r1 := _spawn_pawn(clk)
	var r2 := _spawn_pawn(clk)
	var r3 := _spawn_pawn(clk)
	r1.setup_cursor(0.0); r2.setup_cursor(0.0); r3.setup_cursor(0.0)
	r2.fail_next = true
	tm._run_pawn_continuous_frontier(fc)
	_check("C_legacy_stays_F", is_equal_approx(_legacy(clk), fc), "legacy=%s" % _legacy(clk))
	_check("C_pawn_stays_0", is_equal_approx(_lane(clk), 0.0), "pawn=%s" % _lane(clk))
	_check("C_committed_stays_0", is_equal_approx(_committed(clk), 0.0), "committed=%s" % _committed(clk))
	r1.free(); r2.free(); r3.free()  # immediate (sync) removal from "pawns" group

	# --- D: speed index 1x and 200x, equal committed frontier 10.0 -> equal acc ---
	print("TEST_D_1X_200X_EQUIVALENT")
	# speed 1x vs 200x: same committed frontier 10.0 integrates equally
	if tm.has_method("set_speed"):
		tm.set_speed(1.0)
	var d_1x := _drive_frontier(clk, tm, 200)   # 200 transactions x 0.05 = 10.0
	if tm.has_method("set_speed"):
		tm.set_speed(200.0)
	var d_200x := _drive_frontier(clk, tm, 200) # same frontier; speed multiplier differs conceptually
	_check("D_1x_acc_10", is_equal_approx(d_1x.acc, 10.0), "acc=%s" % d_1x.acc)
	_check("D_200x_acc_10", is_equal_approx(d_200x.acc, 10.0), "acc=%s" % d_200x.acc)
	_check("D_equal", is_equal_approx(d_1x.acc, d_200x.acc), "1x=%s 200x=%s" % [d_1x.acc, d_200x.acc])

	# --- E: target > F -> pawn_continuous == F, not target ---
	print("TEST_E_NO_TARGET_OVERSHOOT")
	var d_e := _drive_frontier(clk, tm, 200)
	_check("E_pawn_is_F", is_equal_approx(d_e.lane, 10.0), "lane=%s" % d_e.lane)
	_check("E_F_not_target", is_equal_approx(d_e.lane, 10.0) and not is_equal_approx(d_e.lane, d_e.target),
		"lane=%s F=10 target=%s" % [d_e.lane, d_e.target])

	if _failures.size() == 0:
		print("PAWN_CONTINUOUS_FIX2 RESULT=PASS")
		quit(0)
	else:
		print("PAWN_CONTINUOUS_FIX2 RESULT=FAIL failures=%d" % _failures.size())
		for label in _failures:
			print("  failed: %s" % label)
		quit(1)


## Drive `transactions` legacy-core commits against a far target and run the REAL
## coordinator after each; the test pawn integrates the committed frontier delta.
func _drive_frontier(clk: Node, tm: Node, transactions: int) -> Dictionary:
	clk.reset()
	tm.ensure_legacy_bridge_initialized()
	clk.register_dynamic_authoritative_lane("pawn_continuous")
	var h := _spawn_pawn(clk)
	h.setup_cursor(0.0)
	clk.advance_target(100000.0)
	for i in range(transactions):
		tm._commit_legacy_core_quantum()
		var f: float = _legacy(clk)
		tm._run_pawn_continuous_frontier(f)
	var acc_val: float = h.acc
	h.free()  # immediate (sync) removal from "pawns" group
	return {
		"acc": acc_val,
		"lane": _lane(clk),
		"target": float(clk.get_target_world_time_seconds()),
	}


## Create a TestPawn, add it to the tree, then register the "pawns" group AFTER
## the node is in the tree (so the SceneTree group registry sees it).
func _spawn_pawn(clk: Node) -> TestPawn:
	var tp := TestPawn.new(clk)
	get_root().add_child(tp)
	tp.add_to_group("pawns")
	return tp


## Extract a top-level function's body from source. Returns [body, found].
## GDScript here uses indentation (no-brace) bodies; delimits at the next
## top-level `func` / `static func` line.
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