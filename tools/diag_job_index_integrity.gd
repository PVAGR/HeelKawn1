extends SceneTree
## DIAGNOSTIC: Verify JobManager index integrity across mutations.
## Posts 100 jobs, claims at various indices, verifies after each.

func _al(n: String) -> Node:
	return root.get_node_or_null("/root/" + n)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var jm: Node = _al("JobManager")
	if jm == null:
		push_error("no JobManager")
		quit(1)
		return
	print("=== JOB INDEX INTEGRITY CHECK ===")
	jm.call("clear_all")
	var res: Dictionary = jm.call("_verify_index_integrity")
	print("A init valid=%s errors=%d open=%d idx=%d" % [str(res.get("valid",false)), (res.get("errors",[]) as Array).size(), int((jm.get("_open") as Array).size()), int((jm.get("_open_index_by_id") as Dictionary).size())])
	# Post 100 jobs at distinct tiles
	for i in range(100):
		var tile := Vector2i(i, 0)
		var job: Variant = jm.call("post", 0, tile, 1, 20) # FORAGE
		if job == null:
			print("post failed at %d" % i)
	# B
	res = jm.call("_verify_index_integrity")
	print("B after 100 posts valid=%s errors=%d open=%d idx=%d" % [str(res.get("valid",false)), (res.get("errors",[]) as Array).size(), int((jm.get("_open") as Array).size()), int((jm.get("_open_index_by_id") as Dictionary).size())])
	if not bool(res.get("valid",false)):
		_print_errors(res)
		quit(1)
		return
	# Helper to get pawn dummy
	var dummy_pawn: Node = _make_dummy_pawn(9999)
	var pd: Variant = dummy_pawn.call("get_pawn_data") if dummy_pawn.has_method("get_pawn_data") else null
	# C claim middle via claim_from_snapshot
	print("C claim middle via snapshot")
	_claim_snapshot_and_verify(jm, dummy_pawn, pd, 50)
	# D after 5 claims
	for i in range(4):
		_claim_snapshot_and_verify(jm, dummy_pawn, pd, -1) # auto best
	res = jm.call("_verify_index_integrity")
	print("D after 5 claims valid=%s open=%d idx=%d" % [str(res.get("valid",false)), int((jm.get("_open") as Array).size()), int((jm.get("_open_index_by_id") as Dictionary).size())])
	if not bool(res.get("valid",false)):
		_print_errors(res)
	# E after 25 claims total
	for i in range(20):
		_claim_snapshot_and_verify(jm, dummy_pawn, pd, -1)
	res = jm.call("_verify_index_integrity")
	print("E after 25 claims valid=%s open=%d idx=%d" % [str(res.get("valid",false)), int((jm.get("_open") as Array).size()), int((jm.get("_open_index_by_id") as Dictionary).size())])
	if not bool(res.get("valid",false)):
		_print_errors(res)
	# F cancel some
	print("F cancelling 10 remaining at various indices")
	var open_arr: Array = jm.get("_open")
	# cancel first, middle, last etc
	var to_cancel: Array = []
	if open_arr.size() >= 10:
		to_cancel.append(open_arr[0])
		to_cancel.append(open_arr[open_arr.size()/2])
		to_cancel.append(open_arr[open_arr.size()-1])
		for k in range(3, 10):
			if k < open_arr.size():
				to_cancel.append(open_arr[k])
	for j in to_cancel:
		jm.call("cancel", j, "test_cancel")
	res = jm.call("_verify_index_integrity")
	print("F after cancels valid=%s open=%d idx=%d" % [str(res.get("valid",false)), int((jm.get("_open") as Array).size()), int((jm.get("_open_index_by_id") as Dictionary).size())])
	if not bool(res.get("valid",false)):
		_print_errors(res)
	# G mature save not applicable here (fresh test)
	# H claim via snapshot after cancels
	print("H claim after cancels via snapshot")
	for i in range(5):
		_claim_snapshot_and_verify(jm, dummy_pawn, pd, -1)
	res = jm.call("_verify_index_integrity")
	print("H final valid=%s open=%d idx=%d" % [str(res.get("valid",false)), int((jm.get("_open") as Array).size()), int((jm.get("_open_index_by_id") as Dictionary).size())])
	if not bool(res.get("valid",false)):
		_print_errors(res)
		quit(1)
		return
	print("=== ALL INTEGRITY CHECKS PASS ===")
	quit(0)

func _make_dummy_pawn(pid: int) -> Node:
	# Create a minimal HeelKawnian-like dummy with required methods
	# Use HeelKawnianData + a Node that returns it
	var n: Node = Node.new()
	n.set_script(load("res://scripts/pawn/HeelKawnian.gd"))
	# Instead, just create a Node with get_pawn_data that returns a Dictionary-like object
	# Simpler: use a plain Node and add methods via meta
	# We'll create a custom script
	var s: GDScript = GDScript.new()
	s.source_code = """
extends Node
var _pd: Variant = null
func get_pawn_data():
	return _pd
func _ready():
	pass
"""
	s.reload()
	var dummy: Node = Node.new()
	dummy.set_script(s)
	# Create HeelKawnianData
	var pd_script: GDScript = load("res://scripts/pawn/HeelKawnianData.gd") as GDScript
	var pd = pd_script.new()
	pd.id = pid
	pd.tile_pos = Vector2i(0,0)
	pd.household_id = -1
	# Ensure can_work true (adult)
	pd.age = 25
	pd.age_years = 25.0
	pd.life_stage = 2 # adult?
	dummy.set("_pd", pd)
	root.add_child(dummy)
	return dummy

func _claim_snapshot_and_verify(jm: Node, pawn: Node, pd: Variant, target_idx: int) -> void:
	var snap: Dictionary = jm.call("get_indexed_candidate_snapshot", pawn, pd)
	var cands: Array = snap.get("candidates", [])
	if cands.is_empty():
		print("  snapshot empty rej=%s" % str(snap.get("rejection_reasons",{})))
		return
	var job: Variant = null
	if target_idx >= 0 and target_idx < cands.size():
		job = cands[target_idx]
	else:
		job = cands[0]
	# Try claim_from_snapshot with filter that selects this job
	var filter := func(j): return j.id == job.id
	var res_claim: Dictionary = jm.call("claim_from_snapshot", pawn, pd, snap, filter, Callable())
	var claimed: Variant = res_claim.get("job")
	if claimed == null:
		print("  claim failed rej=%s map_idx=%s actual_find=%s" % [str(res_claim.get("rejection_reason","")), str(jm.get("_open_index_by_id").get(job.id, -1)), str((jm.get("_open") as Array).find(job))])
		var ver: Dictionary = jm.call("_verify_index_integrity")
		if not bool(ver.get("valid",false)):
			print("  INTEGRITY BROKEN after failed claim")
			_print_errors(ver)
	else:
		# success
		pass
	var ver2: Dictionary = jm.call("_verify_index_integrity")
	if not bool(ver2.get("valid",false)):
		print("  INTEGRITY BROKEN after claim success open=%d" % int((jm.get("_open") as Array).size()))
		_print_errors(ver2)

func _print_errors(res: Dictionary) -> void:
	var errs: Array = res.get("errors", [])
	print("  ERRORS %d:" % errs.size())
	for e in errs.slice(0, 20):
		print("    %s" % str(e))
	# Detailed map check
