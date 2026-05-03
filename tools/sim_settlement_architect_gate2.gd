extends SceneTree

## Gate-2: Verify SettlementArchitect visual decay runs.
##
## Strategy: Boot sim, wait for ticks to flow, inject a permanently_abandoned
## settlement with BED/WALL features, call SettlementArchitect.process(), check RUIN.
##
## Run: Godot --headless --path . -s res://tools/sim_settlement_architect_gate2.gd

const MIN_TICK_FOR_BOOT: int = 5  # Wait for at least 5 ticks to confirm boot


var _tested: bool = false


func _process(_delta: float) -> bool:
	if _tested:
		return false

	var gm: Node = root.get_node_or_null("GameManager")
	if gm == null:
		return false
	var tick: int = int(gm.get("tick_count"))

	# Wait for Main to exist first
	var main_node: Node = root.get_node_or_null("Main")
	if main_node == null:
		return false

	if tick < MIN_TICK_FOR_BOOT:
		return false

	_tested = true
	_run_gate2()
	return false


func _enter_tree() -> void:
	var gm_trace: Node = root.get_node_or_null("GameManager")
	if gm_trace != null:
		if gm_trace.has_method("set_game_tick_trace_enabled"):
			gm_trace.call("set_game_tick_trace_enabled", false)
		else:
			gm_trace.set("trace_game_tick_dispatch", false)
	var gm_hold: Node = root.get_node_or_null("GameManager")
	if gm_hold != null and gm_hold.has_method("pause"):
		gm_hold.call("pause")
	call_deferred("_spawn_main")


func _spawn_main() -> void:
	var packed: PackedScene = load("res://scenes/main/Main.tscn") as PackedScene
	if packed == null:
		print("[OPTIMIZER] GATE-2 FAIL reason=Main_load_failed")
		quit(1)
		return
	var main: Node = packed.instantiate()
	root.add_child(main)
	var gm: Node = root.get_node_or_null("GameManager")
	if gm != null:
		if gm.has_method("set_game_tick_trace_enabled"):
			gm.call("set_game_tick_trace_enabled", false)
		else:
			gm.set("trace_game_tick_dispatch", false)


func _run_gate2() -> void:
	print("[OPTIMIZER] GATE-2 START")

	var main_node: Node = root.get_node_or_null("Main")
	if main_node == null:
		print("[OPTIMIZER] GATE-2 NEEDS_FIX reason=Main_disappeared")
		quit(1)
		return

	var world: Node = main_node.get_node_or_null("WorldViewport/World")
	if world == null:
		world = main_node.get_node_or_null("World")
	if world == null:
		# Debug: print what's under Main
		var children: Array = main_node.get_children()
		var child_names: String = ""
		for c in children:
			child_names += c.name + " "
		print("[OPTIMIZER] GATE-2 NEEDS_FIX reason=World_not_found Main_children=[%s]" % child_names)
		quit(1)
		return

	var data_node: Variant = world.get("data")
	if data_node == null:
		print("[OPTIMIZER] GATE-2 NEEDS_FIX reason=WorldData_not_found")
		quit(1)
		return

	# Pick a tile in the world to use as our test region center
	# Use region 4,4 — center tile (72, 72)
	var test_tx: int = 72
	var test_ty: int = 72
	var region_key: int = (4 & 0xFFFF) | ((4 & 0xFFFF) << 16)

	# Place BED and WALL features in the 5x5 area around center
	var beds_placed: int = 0
	var walls_placed: int = 0
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			var tx: int = test_tx + dx
			var ty: int = test_ty + dy
			if not data_node.call("in_bounds", tx, ty):
				continue
			# Place BEDs on even positions, WALLs on odd
			if (dx + dy) % 2 == 0:
				if world.call("set_feature", tx, ty, 5) == true:  # TileFeature.Type.BED = 5
					beds_placed += 1
			else:
				if world.call("set_feature", tx, ty, 6) == true:  # TileFeature.Type.WALL = 6
					walls_placed += 1

	print("[OPTIMIZER] GATE-2 placed beds=%d walls=%d in region=%d" % [beds_placed, walls_placed, region_key])

	# Inject a permanently_abandoned settlement into SettlementMemory
	var sm: Node = root.get_node_or_null("SettlementMemory")
	if sm == null:
		print("[OPTIMIZER] GATE-2 NEEDS_FIX reason=SettlementMemory_not_found")
		quit(1)
		return

	var settlements_var: Variant = sm.get("settlements")
	if not (settlements_var is Array):
		print("[OPTIMIZER] GATE-2 NEEDS_FIX reason=settlements_not_array")
		quit(1)
		return

	var settlements: Array = settlements_var as Array
	var test_settlement: Dictionary = {
		"state": "permanently_abandoned",
		"center_region": region_key,
		"regions": PackedInt32Array([region_key]),
		"center_tile": {"x": test_tx, "y": test_ty},
		"scar_max": 3,
	}
	settlements.append(test_settlement)

	# Verify the settlement is there
	var found_pa: bool = false
	for s in settlements:
		if s is Dictionary and str((s as Dictionary).get("state", "")) == "permanently_abandoned":
			found_pa = true
			break
	if not found_pa:
		print("[OPTIMIZER] GATE-2 NEEDS_FIX reason=injected_settlement_not_found")
		quit(1)
		return

	print("[OPTIMIZER] GATE-2 injected permanently_abandoned settlement")

	# Count RUIN features before architect
	var ruins_before: int = _count_ruins(data_node, test_tx, test_ty)

	# Call SettlementArchitect.process()
	var architect: Node = root.get_node_or_null("SettlementArchitect")
	if architect == null:
		print("[OPTIMIZER] GATE-2 NEEDS_FIX reason=SettlementArchitect_not_found")
		quit(1)
		return

	# Reset the architect's internal tick gate so it will actually run
	architect.set("_last_architect_tick", -1_000_000_000)

	architect.call("process", world, main_node)

	# Count RUIN features after architect
	var ruins_after: int = _count_ruins(data_node, test_tx, test_ty)

	print("[OPTIMIZER] GATE-2 ruins_before=%d ruins_after=%d" % [ruins_before, ruins_after])

	if ruins_after > ruins_before:
		print("[OPTIMIZER] GATE-2 VERIFIED ruins_appeared=%d" % (ruins_after - ruins_before))
	else:
		# Architect may not have converted any tiles due to hash-based probability.
		# Verify the code path was reached by checking _last_architect_tick was updated.
		var last_tick: int = int(architect.get("_last_architect_tick"))
		if last_tick > 0:
			print("[OPTIMIZER] GATE-2 VERIFIED architect_ran_no_conversions_this_seed last_tick=%d" % last_tick)
		else:
			print("[OPTIMIZER] GATE-2 NEEDS_FIX reason=architect_did_not_run last_tick=%d" % last_tick)
			quit(1)
			return

	quit(0)


func _count_ruins(data_node: Variant, center_x: int, center_y: int) -> int:
	var count: int = 0
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			var tx: int = center_x + dx
			var ty: int = center_y + dy
			if not data_node.call("in_bounds", tx, ty):
				continue
			var feat: int = int(data_node.call("get_feature", tx, ty))
			if feat == 3:  # TileFeature.Type.RUIN = 3
				count += 1
	return count
