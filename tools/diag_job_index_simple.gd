extends SceneTree
## Simple deterministic index repair test without pawn.
func _al(n: String) -> Node:
	return root.get_node_or_null("/root/" + n)
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var jm: Node = _al("JobManager")
	if jm == null:
		push_error("no jm")
		quit(1)
		return
	print("=== SIMPLE INDEX TEST ===")
	jm.call("clear_all")
	var r: Dictionary = jm.call("_verify_index_integrity")
	print("init valid=%s open=%d" % [str(r.get("valid",false)), int((jm.get("_open") as Array).size())])
	# post 100
	for i in range(100):
		var job = jm.call("post", 0, Vector2i(i, 0), 1, 20)
		if job == null:
			print("post %d failed" % i)
	r = jm.call("_verify_index_integrity")
	print("after 100 posts valid=%s errors=%d open=%d idx=%d" % [str(r.get("valid",false)), (r.get("errors",[]) as Array).size(), int((jm.get("_open") as Array).size()), int((jm.get("_open_index_by_id") as Dictionary).size())])
	if not bool(r.get("valid",false)):
		_print(r)
		quit(1)
		return
	# Remove at beginning
	var open_arr: Array = jm.get("_open")
	var job0: Variant = open_arr[0]
	print("remove at 0 id=%d" % int(job0.id))
	jm.call("cancel", job0, "test")
	r = jm.call("_verify_index_integrity")
	print("after remove 0 valid=%s open=%d" % [str(r.get("valid",false)), int((jm.get("_open") as Array).size())])
	if not bool(r.get("valid",false)):
		_print(r)
		quit(1)
		return
	# Remove at middle
	open_arr = jm.get("_open")
	var mid: Variant = open_arr[open_arr.size()/2]
	print("remove mid id=%d idx=%d" % [int(mid.id), open_arr.size()/2])
	jm.call("cancel", mid, "test")
	r = jm.call("_verify_index_integrity")
	print("after mid valid=%s open=%d" % [str(r.get("valid",false)), int((jm.get("_open") as Array).size())])
	if not bool(r.get("valid",false)):
		_print(r)
		quit(1)
		return
	# Remove at near end
	open_arr = jm.get("_open")
	var last: Variant = open_arr[open_arr.size()-1]
	print("remove last id=%d" % int(last.id))
	jm.call("cancel", last, "test")
	r = jm.call("_verify_index_integrity")
	print("after last valid=%s open=%d" % [str(r.get("valid",false)), int((jm.get("_open") as Array).size())])
	if not bool(r.get("valid",false)):
		_print(r)
		quit(1)
		return
	# Alternating removals
	for k in range(5):
		open_arr = jm.get("_open")
		if open_arr.size() < 10:
			break
		var idx: int = (k * 7) % open_arr.size()
		var j: Variant = open_arr[idx]
		print("alternating remove idx=%d id=%d" % [idx, int(j.id)])
		jm.call("cancel", j, "test")
		r = jm.call("_verify_index_integrity")
		print("  valid=%s open=%d" % [str(r.get("valid",false)), int((jm.get("_open") as Array).size())])
		if not bool(r.get("valid",false)):
			_print(r)
			quit(1)
			return
	# Complete some via claim simulation: directly use remove_at via cancel to simulate
	print("post 10 more then complete via complete()")
	for i in range(10):
		jm.call("post", 0, Vector2i(200+i, 0), 1, 20)
	r = jm.call("_verify_index_integrity")
	print("after 10 more valid=%s open=%d" % [str(r.get("valid",false)), int((jm.get("_open") as Array).size())])
	open_arr = jm.get("_open")
	# complete first 3 via complete (they are open, complete should remove from open)
	for i in range(3):
		if open_arr.size() == 0:
			break
		var j2: Variant = open_arr[0]
		print("complete id=%d" % int(j2.id))
		jm.call("complete", j2)
		r = jm.call("_verify_index_integrity")
		print("  valid=%s open=%d" % [str(r.get("valid",false)), int((jm.get("_open") as Array).size())])
		if not bool(r.get("valid",false)):
			_print(r)
			quit(1)
			return
		open_arr = jm.get("_open")
	print("=== ALL SIMPLE CHECKS PASS ===")
	quit(0)

func _print(r: Dictionary) -> void:
	var errs: Array = r.get("errors", [])
	print("ERRORS %d" % errs.size())
	for e in errs.slice(0, 10):
		print("  %s" % str(e))
