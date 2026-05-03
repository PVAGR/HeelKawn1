extends Node

## ToolManager — manages tool crafting, equipping, durability, and tool-job generation.
##
## This autoload provides:
## - Crafting validation (checks stockpile for materials)
## - Auto-equip after crafting
## - Tool-job spawning based on settlement needs
## - Tool availability tracking per settlement

var _tool_job_cooldown_ticks: int = 200
var _last_tool_job_tick: int = -9999


func _ready() -> void:
	if GameManager != null:
		GameManager.game_tick.connect(_on_game_tick)


func _on_game_tick(_tick: int) -> void:
	# Periodically spawn tool-gathering jobs if settlement lacks tools
	if GameManager.tick_count - _last_tool_job_tick >= _tool_job_cooldown_ticks:
		_last_tool_job_tick = GameManager.tick_count
		_spawn_tool_jobs_if_needed()


## Returns true if the stockpile has enough materials to craft the given tool.
func can_craft(tool_type: int, stockpile: Stockpile = null) -> bool:
	if not Item.is_craftable(tool_type):
		return false
	var recipe: Array = Item.get_recipe(tool_type)
	if recipe.is_empty():
		return false
	
	var sp: Stockpile = stockpile if stockpile != null else _get_primary_stockpile()
	if sp == null:
		return false
	
	for ingredient in recipe:
		var item_type: int = int(ingredient["type"])
		var qty: int = int(ingredient["qty"])
		if sp.count_of(item_type) < qty:
			return false
	return true


## Consume materials from stockpile and craft the tool. Returns the crafted item type on success.
func craft_tool(tool_type: int, pawn: Pawn, stockpile: Stockpile = null) -> bool:
	if not Item.is_craftable(tool_type):
		return false
	if not can_craft(tool_type, stockpile):
		return false
	
	var sp: Stockpile = stockpile if stockpile != null else _get_primary_stockpile()
	if sp == null:
		return false
	
	var recipe: Array = Item.get_recipe(tool_type)
	for ingredient in recipe:
		var item_type: int = int(ingredient["type"])
		var qty: int = int(ingredient["qty"])
		sp.take_item(item_type, qty)
	
	# Equip the tool on the pawn
	var pd = pawn.get_pawn_data()
	pd.equip_tool(tool_type)
	
	WorldMemory.record_event({
		"type": "tool_crafted",
		"pawn_id": int(pd.id),
		"pawn_name": pd.display_name,
		"tool": tool_type,
		"tool_name": Item.name_for(tool_type),
		"tick": GameManager.tick_count,
		"tile": {"x": pd.tile_pos.x, "y": pd.tile_pos.y},
	})
	
	if GameManager.verbose_logs():
		print("[ToolManager] %s crafted %s (durability=%d)" % [
			pd.display_name, Item.name_for(tool_type), pd.equipped_tool_durability
		])
	
	return true


## Returns tool priority score for a pawn (higher = more desperate for a tool).
## Used to decide which pawns should craft first.
func get_tool_need_score(pawn: Pawn) -> float:
	var pd = pawn.get_pawn_data()
	if pd == null:
		return 0.0
	
	# If already has a working tool, lower priority
	if pd.is_equipped_tool_valid():
		# But if durability is low, still need a replacement
		var durability_ratio: float = float(pd.equipped_tool_durability) / float(Item.tool_durability(pd.equipped_tool))
		if durability_ratio < 0.3:
			return 3.0  # tool almost broken
		return 0.5  # tool is fine
	
	# No tool — check skill levels to determine what tool would help most
	var best_skill_score: float = 0.0
	for skill_key in pd.skill_xp:
		var xp: float = float(pd.skill_xp[skill_key])
		if xp > best_skill_score:
			best_skill_score = xp
	
	# Higher skill = higher priority to get a tool
	return minf(best_skill_score / 50.0, 5.0)


## Spawn tool-gathering/crafting jobs if the settlement needs them.
func _spawn_tool_jobs_if_needed() -> void:
	if JobManager == null:
		return
	
	# Count how many pawns lack tools
	var toolless_count: int = 0
	var total_pawns: int = 0
	
	var pawns: Array[Pawn] = PawnSpawner.find_pawns()
	for p in pawns:
		total_pawns += 1
		var pd = p.get_pawn_data()
		if not pd.is_equipped_tool_valid():
			toolless_count += 1
	
	if total_pawns == 0:
		return
	
	var toolless_ratio: float = float(toolless_count) / float(total_pawns)
	
	# If >30% of pawns lack tools, spawn gathering/crafting jobs
	if toolless_ratio > 0.3:
		# Spawn flint gathering jobs
		_spawn_gather_jobs(Job.Type.GATHER_FLINT, Item.Type.FLINT)
		# Spawn stick gathering jobs
		_spawn_gather_jobs(Job.Type.GATHER_STICK, Item.Type.STICK)
		
		# If we have materials, spawn crafting jobs
		var sp: Stockpile = _get_primary_stockpile()
		if sp != null:
			if sp.count_of(Item.Type.FLINT) >= 1 and sp.count_of(Item.Type.STICK) >= 1:
				JobManager.post(Job.Type.CRAFT_KNIFE, Vector2i.ZERO, 5, Job.tool_job_work_ticks(Job.Type.CRAFT_KNIFE))
			if sp.count_of(Item.Type.WOOD) >= 1 and sp.count_of(Item.Type.STICK) >= 1:
				JobManager.post(Job.Type.CRAFT_TORCH, Vector2i.ZERO, 4, Job.tool_job_work_ticks(Job.Type.CRAFT_TORCH))


## Spawn gather jobs for flint/stick on appropriate tiles.
func _spawn_gather_jobs(job_type: int, feature_type: int) -> void:
	var world: World = _get_world()
	if world == null or world.data == null:
		return
	
	var jobs_spawned: int = 0
	var max_jobs: int = 3
	
	# Scan for suitable tiles (simplified — just pick random passable tiles near settlement)
	var center: Vector2i = Vector2i(world.data.width / 2, world.data.height / 2)
	var search_radius: int = 30
	
	for _attempt in range(50):
		if jobs_spawned >= max_jobs:
			break
		
		var rx: int = center.x + WorldRNG.index_for(StringName("tool_gather_x:%d" % GameManager.tick_count), -search_radius, search_radius)
		var ry: int = center.y + WorldRNG.index_for(StringName("tool_gather_y:%d" % GameManager.tick_count), -search_radius, search_radius)
		var tile: Vector2i = Vector2i(rx, ry)
		
		if not world.data.in_bounds(tile.x, tile.y):
			continue
		if not world.pathfinder.is_passable(tile):
			continue
		
		JobManager.post(job_type, tile, 3, Job.tool_job_work_ticks(job_type))
		jobs_spawned += 1


func _get_world() -> World:
	var nodes = get_tree().get_nodes_in_group("world")
	if nodes.is_empty():
		return null
	return nodes[0] as World


func _get_primary_stockpile() -> Stockpile:
	if StockpileManager == null:
		return null
	var zones: Array[Stockpile] = StockpileManager.zones()
	if zones.is_empty():
		return null
	return zones[0]
