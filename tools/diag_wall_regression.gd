extends SceneTree
var _gm: Node = null
var _main: Node = null
var _phase := "boot"
var _printed := false
func _al(n: String) -> Node: return root.get_node_or_null("/root/" + n)
func _initialize() -> void: call_deferred("_spawn_main")
func _spawn_main() -> void:
	if not OS.get_cmdline_user_args().has("--playtest-no-save"): push_error("need fence"); quit(1); return
	var packed: PackedScene = load("res://scenes/main/Main.tscn") as PackedScene
	var m: Node = packed.instantiate()
	root.add_child(m)
	if not bool(m.get("_save_writes_disabled_for_playtest")): push_error("fence not active"); quit(1)
func _process(_d: float) -> bool:
	if _printed: return false
	if _gm == null: _gm = _al("GameManager"); return false
	if _phase == "boot":
		_main = root.get_node_or_null("/root/Main")
		if _main == null or _main.get("_world") == null: return false
		if _main.get("_pawn_spawner") == null or _main.get("_pawn_spawner").get("pawns").is_empty(): return false
		_gm.call("set_speed", 1.0)
		_phase = "test_wall"
		print("WALL_REGRESSION start 1x")
		return false
	if _phase == "test_wall":
		var world: Node = _main.get("_world")
		# Test 1: entrapment check should not crash with no settlements
		var ok1: bool = false
		var ok2: bool = false
		var ok3: bool = false
		var err: String = ""
		# Call _wall_would_cause_entrapment at a safe tile
		if world.has_method("_wall_would_cause_entrapment"):
			var res: Variant = world.call("_wall_would_cause_entrapment", 10, 10)
			if res is bool:
				ok1 = true
				print("PASS entrapment call at (10,10) returned %s" % str(res))
			else:
				err += "entrapment not bool; "
		else:
			err += "no method; "
		# Test 2: try building walls at several positions (should not crash)
		var built: int = 0
		for pos in [Vector2i(20,20), Vector2i(21,20), Vector2i(22,20), Vector2i(20,21)]:
			var res2: Variant = world.call("build_wall", pos.x, pos.y)
			if res2 is bool:
				ok2 = true
				if bool(res2):
					built += 1
				print("build_wall at %s -> %s" % [str(pos), str(res2)])
			else:
				err += "build_wall not bool at %s; " % str(pos)
		# Test 3: try trapping check at settlement center if exists
		var sm: Node = _al("SettlementMemory")
		if sm != null and sm.has_method("get_formal_settlements"):
			var formal: Array = sm.call("get_formal_settlements")
			if not formal.is_empty():
				var s: Dictionary = formal[0] as Dictionary
				var crk: int = int(s.get("center_region", -1))
				if crk >= 0 and world.has_method("_wall_would_cause_entrapment"):
					# Convert center region to tile via SettlementPlanner if available
					var sp: Node = _al("SettlementPlanner")
					var ct: Vector2i = Vector2i(crk & 0xFFFF, (crk >> 16) & 0xFFFF)
					if sp != null and sp.has_method("_center_tile_of_region_key"):
						ct = sp.call("_center_tile_of_region_key", crk)
					var res3: Variant = world.call("_wall_would_cause_entrapment", ct.x, ct.y)
					if res3 is bool:
						ok3 = true
						print("PASS entrapment at settlement center %s -> %s" % [str(ct), str(res3)])
		if ok1 and ok2:
			print("WALL_REGRESSION PASS built=%d err='%s'" % [built, err])
			# Test genuine trapping: try to enclose a pawn
			var pa: Node = _al("PawnAccess")
			if pa != null and pa.has_method("find_alive_pawns"):
				var pawns: Array = pa.call("find_alive_pawns")
				if not pawns.is_empty():
					var p: Node = pawns[0]
					var pd: Variant = p.get("data") if p.has_method("get_pawn_data") else null
					if pd != null:
						var pt: Vector2i = pd.get("tile_pos")
						# Try building wall around pawn (should be refused if trapping)
						var trap_pos: Vector2i = pt + Vector2i(1,0)
						var trap_res: Variant = world.call("_wall_would_cause_entrapment", trap_pos.x, trap_pos.y)
						print("trap check near pawn at %s wall at %s -> %s (false means safe, true means would trap)" % [str(pt), str(trap_pos), str(trap_res)])
		else:
			print("WALL_REGRESSION FAIL err='%s' ok1=%s ok2=%s" % [err, str(ok1), str(ok2)])
			_printed = true
			quit(1)
			return false
		_phase = "soak"
		_gm.call("set_speed", 1.0)
		return false
	if _phase == "soak":
		# Let simulation run a bit to ensure no crash on wall completion via pawn jobs
		var tick: int = int(_gm.get("tick_count"))
		if tick >= 500:
			print("WALL_REGRESSION soak tick=%d done" % tick)
			_phase = "done"
			return false
		return false
	if _phase == "done":
		print("WALL_REGRESSION FINAL PASS")
		_printed = true
		quit(0)
	return false
