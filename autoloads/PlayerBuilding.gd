extends Node
## PlayerBuilding - Player builds structures with their own hands
##
## Minecraft ease + Vintage Story depth + Kenshi realism:
## - Player places foundation, walls, roof, door
## - HeelKawnians (pawns) can do EVERYTHING player can do
## - Building requirements (need resources, proper foundation)
## - Building stability (poor foundations collapse)
## - Building decay (structures age naturally)
##
## CRITICAL: Every action available to player is also available to HeelKawnians.
## This is not a player-only system - it's the universal building system.

# Building configuration
const BUILDING_CONFIG: Dictionary = {
	"foundation": {
		"resources": {"stone": 5},
		"build_time": 50,  # ticks
		"skill": "building",
		"stability_base": 100,
		"decay_rate": 0.001,
		"required_tile": "any"
	},
	"wall_wood": {
		"resources": {"wood": 3},
		"build_time": 30,
		"skill": "building",
		"stability_base": 50,
		"decay_rate": 0.002,
		"required_tile": "foundation"
	},
	"wall_stone": {
		"resources": {"stone": 5},
		"build_time": 60,
		"skill": "building",
		"stability_base": 150,
		"decay_rate": 0.0005,
		"required_tile": "foundation"
	},
	"door_wood": {
		"resources": {"wood": 2},
		"build_time": 20,
		"skill": "building",
		"stability_base": 30,
		"decay_rate": 0.003,
		"required_tile": "wall_wood"
	},
	"roof_wood": {
		"resources": {"wood": 4, "stick": 2},
		"build_time": 40,
		"skill": "building",
		"stability_base": 40,
		"decay_rate": 0.004,
		"required_tile": "walls"
	},
	"shelter": {
		"resources": {"wood": 10, "stone": 5},
		"build_time": 100,
		"skill": "building",
		"stability_base": 80,
		"decay_rate": 0.002,
		"required_tile": "foundation"
	},
	"storage_hut": {
		"resources": {"wood": 15, "stone": 10},
		"build_time": 150,
		"skill": "building",
		"stability_base": 100,
		"decay_rate": 0.0015,
		"required_tile": "foundation"
	},
	"fire_pit": {
		"resources": {"stone": 8, "wood": 3},
		"build_time": 60,
		"skill": "building",
		"stability_base": 60,
		"decay_rate": 0.001,
		"required_tile": "any"
	},
	"workshop": {
		"resources": {"wood": 20, "stone": 15, "flint": 5},
		"build_time": 200,
		"skill": "building",
		"stability_base": 120,
		"decay_rate": 0.001,
		"required_tile": "foundation"
	}
}

# Building structures in the world
## {
##   "structure_id": int,
##   "type": String,
##   "tile": Vector2i,
##   "builder_id": int,  # pawn_id who built it (player or HeelKawnian)
##   "built_tick": int,
##   "stability": float,  # 0-100 (0 = collapsed)
##   "health": float,  # 0-100
##   "last_maintained_tick": int
## }
var building_structures: Array[Dictionary] = []
var _next_structure_id: int = 1

# Building queue (for multi-tick construction)
## {
##   "build_id": int,
##   "type": String,
##   "tile": Vector2i,
##   "builder_id": int,
##   "progress": float,  # 0-100
##   "resources_committed": Dictionary
## }
var building_queue: Array[Dictionary] = []
var _next_build_id: int = 1

# References
var _world: Node = null
var _world_memory: Node = null
var _player_gathering: Node = null
var _pawn_spawner: Node = null


func _ready() -> void:
	GameManager.game_tick.connect(_on_game_tick)


func _ensure_references() -> void:
	if _world == null:
		_world = get_node_or_null("/root/Main/World")
	if _world_memory == null:
		_world_memory = get_node_or_null("/root/WorldMemory")
	if _player_gathering == null:
		_player_gathering = get_node_or_null("/root/PlayerGathering")
	if _pawn_spawner == null:
		var main = get_node_or_null("/root/Main")
		if main != null and main.has_method("get_pawn_spawner"):
			_pawn_spawner = main.call("get_pawn_spawner")
		else:
			_pawn_spawner = get_node_or_null("/root/Main/WorldViewport/PawnSpawner")


func _on_game_tick(tick: int) -> void:
	# Process building queue
	_process_building_queue(tick)
	
	# Decay existing structures
	_decay_structures(tick)


# ==================== PLAYER BUILDING ACTIONS ====================

## Player places foundation
func place_foundation(tile: Vector2i) -> Dictionary:
	return _start_building(tile, "foundation")


## Player builds wooden wall
func build_wall_wood(tile: Vector2i) -> Dictionary:
	return _start_building(tile, "wall_wood")


## Player builds stone wall
func build_wall_stone(tile: Vector2i) -> Dictionary:
	return _start_building(tile, "wall_stone")


## Player places wooden door
func build_door_wood(tile: Vector2i) -> Dictionary:
	return _start_building(tile, "door_wood")


## Player builds shelter
func build_shelter(tile: Vector2i) -> Dictionary:
	return _start_building(tile, "shelter")


## Player builds storage hut
func build_storage_hut(tile: Vector2i) -> Dictionary:
	return _start_building(tile, "storage_hut")


## Player builds fire pit
func build_fire_pit(tile: Vector2i) -> Dictionary:
	return _start_building(tile, "fire_pit")


## Player builds workshop
func build_workshop(tile: Vector2i) -> Dictionary:
	return _start_building(tile, "workshop")


# ==================== CORE BUILDING LOGIC ====================

func _start_building(tile: Vector2i, building_type: String) -> Dictionary:
	var result: Dictionary = {
		"success": false,
		"message": "",
		"build_id": -1,
		"started": false
	}
	
	# Check if building type exists
	var config: Dictionary = BUILDING_CONFIG.get(building_type, {})
	if config.is_empty():
		result.message = "Unknown building type"
		return result
	
	# Check if tile is valid
	if not _is_valid_build_tile(tile, config.get("required_tile", "any")):
		result.message = "Invalid build location"
		return result
	
	# Check if player has resources
	var resources: Dictionary = config.get("resources", {})
	if not _has_resources(resources):
		result.message = "Missing resources"
		return result
	
	# Get player pawn ID
	var player_pawn_id: int = _get_player_pawn_id()
	
	# Start building (instant for simple structures, queued for complex)
	var build_time: int = config.get("build_time", 50)
	
	if build_time <= 20:
		# Instant build
		_complete_building(tile, building_type, player_pawn_id, resources)
		result.success = true
		result.message = "Built " + building_type
	else:
		# Queued build (multi-tick)
		var build_id: int = _add_to_building_queue(tile, building_type, player_pawn_id, resources)
		result.success = true
		result.build_id = build_id
		result.started = true
		result.message = "Started building " + building_type + " (" + str(build_time) + " ticks)"
	
	return result


func _is_valid_build_tile(tile: Vector2i, required_tile: String) -> bool:
	if _world == null or _world.data == null:
		return false
	
	if not _world.data.in_bounds(tile.x, tile.y):
		return false
	
	# Check if tile is passable (can't build inside mountains)
	if not _world.data.is_passable(tile.x, tile.y):
		return false
	
	# Check required tile condition
	match required_tile:
		"any":
			return true
		"foundation":
			return _has_structure_at(tile, "foundation")
		"wall_wood", "wall_stone":
			return _has_structure_at(tile, required_tile)
		"walls":
			return _has_adjacent_walls(tile)
	
	return true


func _has_structure_at(tile: Vector2i, structure_type: String) -> bool:
	for structure in building_structures:
		if structure.tile == tile and structure.type == structure_type and structure.stability > 0:
			return true
	return false


func _has_adjacent_walls(tile: Vector2i) -> bool:
	var adjacent: Array[Vector2i] = [
		tile + Vector2i(1, 0),
		tile + Vector2i(-1, 0),
		tile + Vector2i(0, 1),
		tile + Vector2i(0, -1)
	]
	
	for adj_tile in adjacent:
		if _has_structure_at(adj_tile, "wall_wood") or _has_structure_at(adj_tile, "wall_stone"):
			return true
	
	return false


func _has_resources(required: Dictionary) -> bool:
	if _player_gathering == null:
		return false
	
	for resource in required:
		if not _player_gathering.has_resource(resource, required[resource]):
			return false
	
	return true


func _consume_resources(required: Dictionary) -> void:
	if _player_gathering == null:
		return
	
	for resource in required:
		_player_gathering.remove_from_inventory(resource, required[resource])


func _get_player_pawn_id() -> int:
	_ensure_references()
	var main = get_node_or_null("/root/Main")
	if main != null and main.has_method("get_player_pawn_id"):
		return main.call("get_player_pawn_id")
	
	# Fallback (Legacy/Spectator)
	if _pawn_spawner != null and _pawn_spawner.pawns.size() > 0:
		return int(_pawn_spawner.pawns[0].data.id)
	return -1
	return 1


func _add_to_building_queue(tile: Vector2i, building_type: String, builder_id: int, resources: Dictionary) -> int:
	var build: Dictionary = {
		"build_id": _next_build_id,
		"type": building_type,
		"tile": tile,
		"builder_id": builder_id,
		"progress": 0,
		"resources_committed": resources.duplicate()
	}
	
	# Consume resources upfront
	_consume_resources(resources)
	
	building_queue.append(build)
	_next_build_id += 1
	
	return build.build_id


## Called by Main.gd to check if a structure can be placed at this tile
func can_place_structure(tile: Vector2i, type: String) -> Dictionary:
	_ensure_references()
	var config = BUILDING_CONFIG.get(type, {})
	if config.is_empty():
		return {"success": false, "message": "Unknown type"}
	
	if not _is_valid_build_tile(tile, config.get("required_tile", "any")):
		return {"success": false, "message": "Invalid location"}
	
	if not _has_resources(config.get("resources", {})):
		return {"success": false, "message": "Missing resources"}
	
	return {"success": true, "message": "Valid"}


func _process_building_queue(tick: int) -> void:
	for i in range(building_queue.size() - 1, -1, -1):
		var build: Dictionary = building_queue[i]
		var config: Dictionary = BUILDING_CONFIG.get(build.type, {})
		
		# Get builder's skill level
		var skill_level: int = _get_builder_skill_level(build.builder_id, config.get("skill", "building"))
		
		# Calculate progress (base 2% per tick, +0.5% per skill level)
		var progress_gain: float = 2.0 + (float(skill_level) * 0.5)
		build.progress += progress_gain
		
		# Check if complete
		if build.progress >= 100:
			_complete_building(build.tile, build.type, build.builder_id, build.resources_committed)
			building_queue.remove_at(i)


func _complete_building(tile: Vector2i, building_type: String, builder_id: int, resources: Dictionary) -> void:
	var config: Dictionary = BUILDING_CONFIG.get(building_type, {})
	
	# Create structure
	var structure: Dictionary = {
		"structure_id": _next_structure_id,
		"type": building_type,
		"tile": tile,
		"builder_id": builder_id,
		"built_tick": GameManager.tick_count,
		"stability": float(config.get("stability_base", 100)),
		"health": 100.0,
		"last_maintained_tick": GameManager.tick_count
	}
	
	building_structures.append(structure)
	_next_structure_id += 1
	
	# Record building event
	_record_building_event(building_type, tile, builder_id)


func _record_building_event(building_type: String, tile: Vector2i, builder_id: int) -> void:
	if _world_memory == null:
		return
	
	_world_memory.record_event({
		"type": "structure_built",
		"structure_type": building_type,
		"tile": {"x": tile.x, "y": tile.y},
		"builder_id": builder_id,
		"tick": GameManager.tick_count
	})


func _get_builder_skill_level(builder_id: int, skill_name: String) -> int:
	# Get skill level from builder pawn
	# TODO: Implement proper skill system integration
	return 0


func _decay_structures(tick: int) -> void:
	for structure in building_structures:
		var config: Dictionary = BUILDING_CONFIG.get(structure.type, {})
		var decay_rate: float = config.get("decay_rate", 0.001)
		
		# Decay stability over time
		structure.stability = maxf(0.0, structure.stability - decay_rate)
		
		# Check for collapse
		if structure.stability <= 0:
			_collapse_structure(structure)


func _collapse_structure(structure: Dictionary) -> void:
	# Record collapse event
	if _world_memory != null:
		_world_memory.record_event({
			"type": "structure_collapsed",
			"structure_type": structure.type,
			"tile": {"x": structure.tile.x, "y": structure.tile.y},
			"tick": GameManager.tick_count
		})
	
	# Remove structure
	var idx: int = building_structures.find(structure)
	if idx >= 0:
		building_structures.remove_at(idx)


# ==================== MAINTENANCE & REPAIR ====================

## Repair a damaged structure
func repair_structure(structure_id: int, repair_amount: float = 20.0) -> bool:
	var structure: Dictionary = _get_structure(structure_id)
	if structure == null:
		return false
	
	var config: Dictionary = BUILDING_CONFIG.get(structure.type, {})
	var repair_cost: Dictionary = _calculate_repair_cost(structure.type, repair_amount)
	
	# Check if builder has resources
	if not _has_resources(repair_cost):
		return false
	
	# Consume resources
	_consume_resources(repair_cost)
	
	# Repair structure
	structure.stability = minf(100.0, structure.stability + repair_amount)
	structure.health = minf(100.0, structure.health + repair_amount)
	structure.last_maintained_tick = GameManager.tick_count
	
	# Record maintenance event
	if _world_memory != null:
		_world_memory.record_event({
			"type": "structure_repaired",
			"structure_id": structure_id,
			"structure_type": structure.type,
			"repair_amount": repair_amount,
			"tick": GameManager.tick_count
		})
	
	return true


func _calculate_repair_cost(structure_type: String, repair_amount: float) -> Dictionary:
	var config: Dictionary = BUILDING_CONFIG.get(structure_type, {})
	var base_cost: Dictionary = config.get("resources", {})
	
	# Repair costs proportional to build costs and repair amount
	var repair_cost: Dictionary = {}
	for resource in base_cost:
		repair_cost[resource] = int(float(base_cost[resource]) * (repair_amount / 100.0))
	
	return repair_cost


# ==================== PUBLIC API ====================

## Get structure by ID
func get_structure(structure_id: int) -> Dictionary:
	return _get_structure(structure_id)


func _get_structure(structure_id: int) -> Dictionary:
	for structure in building_structures:
		if structure.structure_id == structure_id:
			return structure.duplicate()
	return {}


## Get all structures
func get_all_structures() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for structure in building_structures:
		result.append(structure.duplicate())
	return result


## Get structures at tile
func get_structures_at(tile: Vector2i) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for structure in building_structures:
		if structure.tile == tile:
			result.append(structure.duplicate())
	return result


## Get building progress for queued builds
func get_building_progress(build_id: int) -> Dictionary:
	for build in building_queue:
		if build.build_id == build_id:
			return {
				"progress": build.progress,
				"type": build.type,
				"tile": build.tile
			}
	return {}


## Cancel queued building
func cancel_building(build_id: int) -> bool:
	for i in range(building_queue.size()):
		if building_queue[i].build_id == build_id:
			# Refund resources (50% refund)
			var build: Dictionary = building_queue[i]
			for resource in build.resources_committed:
				var refund: int = int(float(build.resources_committed[resource]) * 0.5)
				if _player_gathering != null:
					_player_gathering._add_to_inventory(resource, refund)
			
			building_queue.remove_at(i)
			return true
	
	return false


## Get building hints for tile
func get_building_hint(tile: Vector2i) -> String:
	if not _is_valid_build_tile(tile, "any"):
		return "Cannot build here"
	
	var structures: Array[Dictionary] = get_structures_at(tile)
	if structures.size() > 0:
		var types: PackedStringArray = []
		for s in structures:
			types.append(s.type)
		return "Structures: " + ", ".join(types)
	
	return "Empty ground - ready to build"


## Get all available building types
func get_available_buildings() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	
	for type_name in BUILDING_CONFIG:
		var config: Dictionary = BUILDING_CONFIG[type_name]
		result.append({
			"type": type_name,
			"resources": config.get("resources", {}),
			"build_time": config.get("build_time", 50),
			"stability": config.get("stability_base", 100),
			"required_tile": config.get("required_tile", "any")
		})
	
	return result


## Clear all data (for world reroll)
func clear() -> void:
	building_structures.clear()
	building_queue.clear()
	_next_structure_id = 1
	_next_build_id = 1
