extends Node
## AIAutoBuild - WorldBox-style autonomous construction
##
## When pawns spawn, they autonomously:
## 1. Scan nearby resources
## 2. Create intents based on needs (shelter, storage, food, etc.)
## 3. Builders choose jobs from deterministic priority
## 4. Record important construction in WorldMemory
##
## Priority order (sacred civilizational order):
## 1. Survival (immediate threats)
## 2. Shelter (protection from elements)
## 3. Storage (preserve resources)
## 4. Hearth (cooking, warmth, gathering point)
## 5. Tools (efficiency improvements)
## 6. Defense (protection from threats)
## 7. Comfort (quality of life)
## 8. Identity (cultural markers)
## 9. Ambition (long-term projects)

# Build priority enum
enum BuildPriority {
	SURVIVAL,      # 0 - Immediate threats
	SHELTER,       # 1 - Protection from elements
	STORAGE,       # 2 - Preserve resources
	HEARTH,        # 3 - Cooking, warmth
	TOOLS,         # 4 - Efficiency
	DEFENSE,       # 5 - Protection
	COMFORT,       # 6 - Quality of life
	IDENTITY,      # 7 - Cultural markers
	AMBITION       # 8 - Long-term projects
}

# Build intent data structure
## {
##   "intent_id": int,
##   "priority": int,  # BuildPriority enum
##   "build_type": String,  # "shelter", "storage", "hearth", etc.
##   "tile": Vector2i,  # Target location
##   "required_resources": Dictionary,  # {resource_type: quantity}
##   "created_tick": int,
##   "assigned_pawn_id": int,
##   "completed": bool
## }
var build_intents: Array[Dictionary] = []
var _next_intent_id: int = 1

# Resource scan cache
var _resource_cache: Dictionary = {}  # {tile: resource_type}
var _cache_tick: int = 0
const CACHE_DURATION_TICKS: int = 100  # Cache lasts 100 ticks

# References
@onready var _world: Node = null
@onready var _job_manager: Node = null
@onready var _world_memory: Node = null
@onready var _settlement_memory: Node = null


func _ready() -> void:
	GameManager.game_tick.connect(_on_game_tick)
	await get_tree().process_frame
	_world = get_node_or_null("/root/Main/World")
	_job_manager = get_node_or_null("/root/JobManager")
	_world_memory = get_node_or_null("/root/WorldMemory")
	_settlement_memory = get_node_or_null("/root/SettlementMemory")


func _on_game_tick(tick: int) -> void:
	# Clear old resource cache periodically
	if tick - _cache_tick > CACHE_DURATION_TICKS:
		_resource_cache.clear()
	
	# Process build intents
	_process_build_intents(tick)
	
	# Scan for new pawns that need direction
	_scan_for_new_pawns(tick)


# ==================== RESOURCE SCANNING ====================

## Scan resources around a tile
func scan_resources(tile: Vector2i, radius: int = 20) -> Dictionary:
	var resources: Dictionary = {
		"wood": 0,
		"stone": 0,
		"food": 0,
		"metal": 0,
		"fertile_soil": false,
		"water_nearby": false,
		"shelter_exists": false,
		"storage_exists": false,
		"hearth_exists": false
	}
	
	# Check cache first
	for x in range(tile.x - radius, tile.x + radius):
		for y in range(tile.y - radius, tile.y + radius):
			var _check_tile: Vector2i = Vector2i(x, y)
			if _resource_cache.has(_check_tile):
				var cached: String = _resource_cache[_check_tile]
				if cached in resources:
					resources[cached] += 1

	# If cache miss, scan world
	if _world != null and _world.data != null:
		for x in range(tile.x - radius, tile.x + radius):
			for y in range(tile.y - radius, tile.y + radius):
				var _check_tile: Vector2i = Vector2i(x, y)
				if _world.data.in_bounds(x, y):
					var biome: int = _world.data.get_biome(x, y)
					var feature: int = _world.data.get_feature(x, y)
					
					# Classify resources
					if biome == 1:  # PLAINS
						resources.food += 1
						resources.fertile_soil = true
					elif biome == 2:  # FOREST
						resources.wood += 1
					elif biome == 3:  # MOUNTAIN
						resources.stone += 1
						resources.metal += 1
					
					# Check for water
					if feature == 5:  # WATER
						resources.water_nearby = true
	
	# Update cache
	_cache_tick = GameManager.tick_count
	
	return resources


# ==================== BUILD INTENT CREATION ====================

## Create build intents for a pawn/settlement
func create_build_intents(_pawn_id: int, tile: Vector2i, settlement_id: int = -1) -> void:
	var resources: Dictionary = scan_resources(tile, 20)
	
	# Check what already exists
	_check_existing_structures(tile, resources, settlement_id)
	
	# Create intents in priority order
	
	# 1. SURVIVAL - Immediate threats
	if not resources.shelter_exists:
		_create_build_intent(BuildPriority.SURVIVAL, "shelter", tile, settlement_id)
	
	# 2. SHELTER - Protection
	if resources.shelter_exists and resources.wood > 0:
		_create_build_intent(BuildPriority.SHELTER, "expand_shelter", tile, settlement_id)
	
	# 3. STORAGE - Preserve resources
	if not resources.storage_exists and resources.food > 0:
		_create_build_intent(BuildPriority.STORAGE, "storage", tile, settlement_id)
	
	# 4. HEARTH - Cooking, warmth
	if not resources.hearth_exists and resources.stone > 0:
		_create_build_intent(BuildPriority.HEARTH, "hearth", tile, settlement_id)
	
	# 5. TOOLS - Efficiency
	if resources.wood > 5 and resources.stone > 3:
		_create_build_intent(BuildPriority.TOOLS, "workshop", tile, settlement_id)
	
	# 6. DEFENSE - Protection
	if resources.wood > 10:
		_create_build_intent(BuildPriority.DEFENSE, "wall", tile, settlement_id)
	
	# 7. COMFORT - Quality of life
	if resources.shelter_exists and resources.storage_exists:
		_create_build_intent(BuildPriority.COMFORT, "bed", tile, settlement_id)
	
	# 8. IDENTITY - Cultural markers
	if settlement_id >= 0 and resources.stone > 20:
		_create_build_intent(BuildPriority.IDENTITY, "monument", tile, settlement_id)
	
	# 9. AMBITION - Long-term projects
	if resources.wood > 50 and resources.stone > 50:
		_create_build_intent(BuildPriority.AMBITION, "great_hall", tile, settlement_id)


func _check_existing_structures(tile: Vector2i, resources: Dictionary, _settlement_id: int) -> void:
	# Check for existing structures in area
	if _settlement_memory != null:
		var buildings: Array = _settlement_memory.get_buildings_near(tile, 20)
		for building in buildings:
			var type: String = building.get("type", "")
			if type == "shelter" or type == "house":
				resources.shelter_exists = true
			elif type == "storage" or type == "granary":
				resources.storage_exists = true
			elif type == "hearth" or type == "fire_pit" or type == "kitchen":
				resources.hearth_exists = true


func _create_build_intent(priority: int, build_type: String, tile: Vector2i, settlement_id: int) -> void:
	# Check if intent already exists for this type
	for intent in build_intents:
		if intent.build_type == build_type and not intent.completed:
			return  # Already have this intent
	
	# Determine required resources
	var required: Dictionary = _get_required_resources(build_type)
	
	# Create intent
	var intent: Dictionary = {
		"intent_id": _next_intent_id,
		"priority": priority,
		"build_type": build_type,
		"tile": tile,
		"required_resources": required,
		"created_tick": GameManager.tick_count,
		"assigned_pawn_id": -1,
		"completed": false,
		"settlement_id": settlement_id
	}
	
	build_intents.append(intent)
	_next_intent_id += 1
	
	# Record in WorldMemory
	if _world_memory != null:
		_world_memory.record_event({
			"type": "build_intent_created",
			"build_type": build_type,
			"priority": priority,
			"tile": {"x": tile.x, "y": tile.y},
			"settlement_id": settlement_id,
			"tick": GameManager.tick_count
		})


func _get_required_resources(build_type: String) -> Dictionary:
	match build_type:
		"shelter":
			return {"wood": 10}
		"expand_shelter":
			return {"wood": 15}
		"storage":
			return {"wood": 20, "stone": 5}
		"hearth":
			return {"stone": 10}
		"workshop":
			return {"wood": 25, "stone": 10}
		"wall":
			return {"wood": 5, "stone": 5}
		"bed":
			return {"wood": 5}
		"monument":
			return {"stone": 50}
		"great_hall":
			return {"wood": 100, "stone": 100}
		_:
			return {"wood": 10}


# ==================== INTENT PROCESSING ====================

func _process_build_intents(_tick: int) -> void:
	# Sort intents by priority (lower = higher priority)
	build_intents.sort_custom(func(a, b): return a.priority < b.priority)
	
	# Process each intent
	for intent in build_intents:
		if intent.completed:
			continue
		
		if intent.assigned_pawn_id < 0:
			# Try to assign a pawn
			_assign_pawn_to_intent(intent)
		
		# Check if resources are available
		if _has_required_resources(intent):
			# Mark as ready to build
			intent.ready = true


func _assign_pawn_to_intent(intent: Dictionary) -> void:
	# Find nearby builder pawns
	if _job_manager == null:
		return
	
	# Post a job for this build intent
	var job_data: Dictionary = {
		"type": "build",
		"build_intent_id": intent.intent_id,
		"tile": intent.tile,
		"priority": 10 - intent.priority,  # Higher priority = lower number
		"required_resources": intent.required_resources
	}
	
	_job_manager.post_from_dict(job_data)


func _has_required_resources(intent: Dictionary) -> bool:
	# Check stockpile for required resources
	var stockpile: Node = get_node_or_null("/root/StockpileManager")
	if stockpile == null:
		return true  # Assume yes if we can't check
	
	# TODO: Implement actual stockpile checking
	return true


# ==================== PAWN SCANNING ====================

func _scan_for_new_pawns(tick: int) -> void:
	var pawn_spawner: Node = get_node_or_null("/root/Main/WorldViewport/PawnSpawner")
	if pawn_spawner == null:
		return
	
	# Check for pawns without assigned tasks
	for pawn in pawn_spawner.pawns:
		if pawn == null or not is_instance_valid(pawn):
			continue

		var data: Node = pawn.get("data")
		if data == null:
			continue

		# Check if pawn is idle and needs direction
		var state: String = ""
		if pawn.has_method("get_state"):
			state = pawn.get_state()
		elif pawn.has_meta("state"):
			state = pawn.get_meta("state")
		
		if state == "idle" or state == "wandering":
			var profession: int = -1
			if data.has_method("get_current_profession"):
				profession = data.get_current_profession()
			elif data.has_meta("current_profession"):
				profession = data.get_meta("current_profession")
			
			if profession == 1:  # BUILDER
				_direct_builder_pawn(pawn, data)


func _direct_builder_pawn(pawn: Node, data: Node) -> void:
	var tile: Vector2i = Vector2i.ZERO
	var settlement_id: int = -1
	
	if data.has_method("get_tile_pos"):
		tile = data.get_tile_pos()
	elif data.has_meta("tile_pos"):
		tile = data.get_meta("tile_pos")
	
	if data.has_method("get_settlement_id"):
		settlement_id = data.get_settlement_id()
	elif data.has_meta("settlement_id"):
		settlement_id = data.get_meta("settlement_id")

	# Create build intents for this builder
	create_build_intents(int(data.id), tile, settlement_id)


# ==================== PUBLIC API ====================

## Get all build intents
func get_all_intents() -> Array[Dictionary]:
	return build_intents.duplicate()

## Get intents by priority
func get_intents_by_priority(priority: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for intent in build_intents:
		if intent.priority == priority and not intent.completed:
			result.append(intent.duplicate())
	return result

## Get intents by settlement
func get_intents_for_settlement(settlement_id: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for intent in build_intents:
		if intent.settlement_id == settlement_id and not intent.completed:
			result.append(intent.duplicate())
	return result

## Mark intent as completed
func complete_intent(intent_id: int) -> void:
	for intent in build_intents:
		if intent.intent_id == intent_id:
			intent.completed = true
			# Record completion
			if _world_memory != null:
				_world_memory.record_event({
					"type": "build_intent_completed",
					"build_type": intent.build_type,
					"intent_id": intent_id,
					"tick": GameManager.tick_count
				})
			return

## Clear all intents (for world reroll)
func clear() -> void:
	build_intents.clear()
	_next_intent_id = 1
	_resource_cache.clear()

## Get statistics
func get_stats() -> Dictionary:
	var stats: Dictionary = {
		"total_intents": build_intents.size(),
		"completed": 0,
		"pending": 0,
		"by_priority": {}
	}
	
	for intent in build_intents:
		if intent.completed:
			stats.completed += 1
		else:
			stats.pending += 1
		
		var priority_name: String = BuildPriority.keys()[intent.priority]
		stats.by_priority[priority_name] = stats.by_priority.get(priority_name, 0) + 1
	
	return stats
