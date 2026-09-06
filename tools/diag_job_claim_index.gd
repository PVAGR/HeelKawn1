extends SceneTree
## Claim via snapshot with real pawn, verify index integrity.

var _gm: Node = null
var _main: Node = null
var _phase := "boot"
var _printed := false

func _al(n: String) -> Node:
	return root.get_node_or_null("/root/" + n)

func _initialize() -> void:
	call_deferred("_spawn_main")

func _spawn_main() -> void:
	if not OS.get_cmdline_user_args().has("--playtest-no-save"):
		push_error("need fence")
		quit(1)
		return
	var packed: PackedScene = load("res://scenes/main/Main.tscn") as PackedScene
	var m: Node = packed.instantiate()
	root.add_child(m)
	if not bool(m.get("_save_writes_disabled_for_playtest")):
		push_error("fence not active")
		quit(1)

func _process(_d: float) -> bool:
	if _printed:
		return false
	if _gm == null:
		_gm = _al("GameManager")
		return false
	if _phase == "boot":
		_main = root.get_node_or_null("/root/Main")
		if _main == null or _main.get("_pawn_spawner") == null:
			return false
		var pawns: Array = _main.get("_pawn_spawner").get("pawns")
		if pawns.is_empty():
			return false
		_phase = "test"
		_run_test()
		_printed = true
		quit(0)
	return false

func _run_test() -> void:
	var jm: Node = _al("JobManager")
	if jm == null:
		print("no jm")
		return
	jm.call("clear_all")
	print("=== CLAIM INDEX TEST WITH REAL PAWN ===")
	var r: Dictionary = jm.call("_verify_index_integrity")
	print("init valid=%s open=%d" % [str(r.get("valid",false)), int((jm.get("_open") as Array).size())])
	var pawn: Node = _main.get("_pawn_spawner").get("pawns")[0]
	var pd: Variant = pawn.call("get_pawn_data")
	print("pawn %s id=%d tile=%s" % [str(pd.get("display_name")), int(pd.get("id")), str(pd.get("tile_pos"))])
	# post 50 jobs near pawn
	var base_tile: Vector2i = pd.get("tile_pos")
	for i in range(50):
		var t: Vector2i = base_tile + Vector2i(i % 10, int(i / 10))
		jm.call("post", 0, t, 5, 20)
	r = jm.call("_verify_index_integrity")
	print("after 50 posts valid=%s open=%d" % [str(r.get("valid",false)), int((jm.get("_open") as Array).size())])
	var successes := 0
	var fails := 0
	for k in range(20):
		var snap: Dictionary = jm.call("get_indexed_candidate_snapshot", pawn, pd)
		var cands: Array = snap.get("candidates", [])
		if cands.is_empty():
			print("iter %d snapshot empty rej=%s" % [k, str(snap.get("rejection_reasons",{}))])
			fails += 1
			continue
		var job: Variant = cands[0]
		var filter := func(j): return j.id == job.id
		var res_claim: Dictionary = jm.call("claim_from_snapshot", pawn, pd, snap, filter, Callable())
		var claimed: Variant = res_claim.get("job")
		if claimed != null:
			successes += 1
			# immediately complete to free pawn for next iteration (abandon would re-add)
			jm.call("complete", claimed)
		else:
			fails += 1
			print("iter %d claim failed rej=%s map_idx=%s find=%d" % [k, str(res_claim.get("rejection_reason","")), str(jm.get("_open_index_by_id").get(job.id, -1)), int((jm.get("_open") as Array).find(job))])
			var rej: Dictionary = jm.call("stats").get("rejection_reasons", {})
			print("  rejection_reasons=%s" % str(rej))
		r = jm.call("_verify_index_integrity")
		if not bool(r.get("valid",false)):
			print("INTEGRITY FAIL at iter %d" % k)
			var errs: Array = r.get("errors", [])
			for e in errs.slice(0, 5):
				print("  %s" % str(e))
			return
		# re-add pawn to allow next claim (if completed, pawn is free; if we completed, need to reset pawn state? just keep looping)
	r = jm.call("_verify_index_integrity")
	print("final valid=%s open=%d successes=%d fails=%d" % [str(r.get("valid",false)), int((jm.get("_open") as Array).size()), successes, fails])
	var stats: Dictionary = jm.call("stats")
	print("stats claim_attempts=%d succ=%d race=%d" % [int(stats.get("claim_attempts",0)), int(stats.get("claim_successes",0)), int(stats.get("rejection_reasons",{}).get("race_condition",0))])
	# check sub-reasons
	var rej2: Dictionary = stats.get("rejection_reasons", {})
	for k in rej2.keys():
		if str(k).find("CORRUPT") >= 0:
			print("CORRUPT sub-reason %s=%d" % [str(k), int(rej2[k])])
	if rej2.has("mapped_index_points_to_different_job_CORRUPT_actual") or rej2.has("mapped_index_missing_but_job_still_open_CORRUPT"):
		print("FAIL: corrupt races still present")
	else:
		print("PASS: no corrupt races")
	print("=== DONE ===")
