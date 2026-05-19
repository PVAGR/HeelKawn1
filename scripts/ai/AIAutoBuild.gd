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

const BUILD_TO_JOB_TYPE: Dictionary = {
	"shelter": Job.Type.BUILD_SHELTER,
	"expand_shelter": Job.Type.BUILD_SHELTER,
	"storage": Job.Type.BUILD_STORAGE_HUT,
	"hearth": Job.Type.BUILD_FIRE_PIT,
	"workshop": Job.Type.TOOL_MAKING,
	"wall": Job.Type.BUILD_WALL,
	"bed": Job.Type.BUILD_BED,
	"monument": Job.Type.BUILD_MARKER_STONE,
	"great_hall": Job.Type.BUILD_WALL
}


func _ready() -> void:
	GameManager.game_tick.connect(_on_game_tick)
	await get_tree().process_frame
	_world = get_node_or_null("/root/Main/World")
	_job_manager = get_node_or_null("/root/JobManager")
	_world_memory = get_node_or_null("/root/WorldMemory")
	_settlement_memory = get_node_or_null("/root/SettlementMemory")


func _on_game_tick(tick: int) -> void:
	# Throttle: auto-build doesn't need to run every tick.
	# Build intents and pawn scanning are not time-critical.
	if tick % 10 != 0:
		return
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

	var survival_met: bool = _colony_survival_needs_met()

	# Create intents in priority order

	# 1. SURVIVAL - shelter only when housing pressure (or first proto shelter with no beds)
	var needs_shelter: bool = not resources.shelter_exists
	if needs_shelter and ColonySimServices != null:
		needs_shelter = ColonySimServices.get_housing_pressure() > 0.12
	if needs_shelter:
		_create_build_intent(BuildPriority.SURVIVAL, "shelter", tile, settlement_id)

	# 3. STORAGE - when stock pressure warrants it
	var needs_storage: bool = not resources.storage_exists and resources.food > 0
	if needs_storage and ColonySimServices != null:
		var center_rk: int = settlement_id
		if center_rk < 0 and WorldMemory != null:
			center_rk = WorldMemory._region_key(tile.x, tile.y)
		needs_storage = ColonySimServices.get_storage_pressure(center_rk) > 0.14 \
				or ColonySimServices.get_food_pressure() > 0.28
	if needs_storage:
		_create_build_intent(BuildPriority.STORAGE, "storage", tile, settlement_id)

	# 4. HEARTH - Cooking, warmth (need-driven)
	if not resources.hearth_exists and resources.stone > 0:
		var needs_hearth: bool = true
		if ColonySimServices != null:
			needs_hearth = ColonySimServices.get_warmth_pressure() > 0.15 \
					or ColonySimServices.get_cooking_pressure() > 0.1
		if needs_hearth:
			_create_build_intent(BuildPriority.HEARTH, "hearth", tile, settlement_id)

	if not survival_met:
		return
	if ColonySimServices != null and ColonySimServices.should_block_ambition_tier_build():
		return

	# 2. SHELTER - expansion only after survival needs met
	if resources.shelter_exists and resources.wood > 0:
		_create_build_intent(BuildPriority.SHELTER, "expand_shelter", tile, settlement_id)

	# 5. TOOLS - Efficiency
	if resources.wood > 5 and resources.stone > 3:
		_create_build_intent(BuildPriority.TOOLS, "workshop", tile, settlement_id)

	# 7. COMFORT - Quality of life
	if resources.shelter_exists and resources.storage_exists:
		_create_build_intent(BuildPriority.COMFORT, "bed", tile, settlement_id)

	# 8. IDENTITY - Cultural markers
	if settlement_id >= 0 and resources.stone > 20:
		_create_build_intent(BuildPriority.IDENTITY, "monument", tile, settlement_id)

	# 6. DEFENSE / 9. AMBITION — defer until fed, housed, and warm
	if resources.wood > 10:
		_create_build_intent(BuildPriority.DEFENSE, "wall", tile, settlement_id)

	if resources.wood > 50 and resources.stone > 50:
		_create_build_intent(BuildPriority.AMBITION, "great_hall", tile, settlement_id)


func _check_existing_structures(tile: Vector2i, resources: Dictionary, _settlement_id: int) -> void:
	# Check for existing structures in area
	if _settlement_memory != null and _settlement_memory.has_method("get_buildings_near"):
		var buildings: Array = _settlement_memory.get_buildings_near(tile, 20)
		for building in buildings:
			var type: String = building.get("type", "")
			if type == "shelter" or type == "house":
				resources.shelter_exists = true
			elif type == "storage" or type == "granary":
				resources.storage_exists = true
			elif type == "hearth" or type == "fire_pit" or type == "kitchen":
				resources.hearth_exists = true
	else:
		# Fallback scan from world features if settlement building API is not present.
		if _world == null or _world.data == null:
			return
		for x in range(tile.x - 12, tile.x + 12):
			for y in range(tile.y - 12, tile.y + 12):
				if not _world.data.in_bounds(x, y):
					continue
				var feature: int = _world.data.get_feature(x, y)
				if feature == TileFeature.Type.BED:
					resources.shelter_exists = true
				elif feature == TileFeature.Type.FIRE_PIT:
					resources.hearth_exists = true
				elif feature == TileFeature.Type.STORAGE_HUT:
					resources.storage_exists = true


func _create_build_intent(priority: int, build_type: String, tile: Vector2i, settlement_id: int) -> void:
	if not _auto_build_post_allowed(build_type, tile, settlement_id):
		return
	# Skip if this structure type already exists nearby.
	var probe: Dictionary = scan_resources(tile, 12)
	_check_existing_structures(tile, probe, settlement_id)
	match build_type:
		"shelter", "expand_shelter":
			if probe.shelter_exists and build_type == "expand_shelter":
				return
		"storage":
			if probe.storage_exists:
				return
		"hearth":
			if probe.hearth_exists:
				return
		"great_hall", "wall":
			if priority >= BuildPriority.DEFENSE and not _colony_survival_needs_met():
				return
	# Check if intent already exists for this type
	for intent in build_intents:
		if intent.build_type == build_type and int(intent.get("settlement_id", -9999)) == settlement_id and not bool(intent.get("completed", false)):
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
	if not _has_required_resources(intent):
		return
	var build_type: String = str(intent.get("build_type", ""))
	if build_type in ["expand_shelter", "wall", "great_hall"] and not _colony_survival_needs_met():
		return
	var job_type: int = int(BUILD_TO_JOB_TYPE.get(build_type, -1))
	if job_type < 0:
		return
	# Post a concrete deterministic job for this build intent.
	if ColonySimServices != null and ColonySimServices.is_hearth_build_job(job_type):
		var center_rk: int = -1
		if _settlement_memory != null:
			var tile: Vector2i = intent.tile
			center_rk = SettlementMemory.get_center_region_for_region(
					WorldMemory._region_key(tile.x, tile.y)
			) if WorldMemory != null else -1
		if center_rk >= 0 and not ColonySimServices.can_seed_fire_pit(center_rk, intent.tile, 0, 1):
			return
	if ColonySimServices != null:
		var slot_rk: int = SettlementMemory.get_center_region_for_region(
				WorldMemory._region_key(intent.tile.x, intent.tile.y)
		) if WorldMemory != null and SettlementMemory != null else -1
		if slot_rk >= 0 and not ColonySimServices.try_consume_settlement_build_slot(slot_rk, 3):
			return
	if not _auto_build_post_allowed(build_type, intent.tile, int(intent.get("settlement_id", -1))):
		return
	var posted: Job = null
	if _job_manager.has_method("post_build_deduped"):
		posted = _job_manager.post_build_deduped(
			job_type,
			intent.tile,
			10 - int(intent.priority),
			20,
			intent.tile,
		)
		if posted != null and _job_manager.has_method("stamp_seeder_metadata"):
			_job_manager.stamp_seeder_metadata(
				posted, "auto_build_%s" % build_type, "settlement"
			)
	else:
		posted = _job_manager.post_stamped(
			job_type,
			intent.tile,
			10 - int(intent.priority),
			20,
			"auto_build_%s" % build_type,
			"settlement",
		)
	if posted != null:
		intent.assigned_pawn_id = -2  # queued marker (claimed pawn id comes later in JobManager)
		_mark_auto_build_intent_posted(build_type, intent.tile, int(intent.get("settlement_id", -1)))


func _has_required_resources(intent: Dictionary) -> bool:
	var stockpile: Node = get_node_or_null("/root/StockpileManager")
	if stockpile == null or not stockpile.has_method("total_count_of"):
		return false
	var required: Dictionary = intent.get("required_resources", {})
	for key in required:
		var item_type: int = _resource_key_to_item_type(str(key))
		if item_type < 0:
			continue
		if int(stockpile.total_count_of(item_type)) < int(required[key]):
			return false
	return true


func _resource_key_to_item_type(key: String) -> int:
	match key:
		"wood":  return Item.Type.WOOD
		"stone": return Item.Type.STONE
		"food":  return Item.Type.BERRY
		"metal": return Item.Type.IRON_ORE
	return -1


func _settlement_dict_for_id(settlement_id: int, tile: Vector2i) -> Dictionary:
	if settlement_id < 0:
		return {}
	if _settlement_memory != null and _settlement_memory.has_method("get_formal_settlements"):
		for st in _settlement_memory.get_formal_settlements():
			if st is Dictionary and int(st.get("id", -1)) == settlement_id:
				return st as Dictionary
			if st is Dictionary and int(st.get("center_region", -1)) == settlement_id:
				return st as Dictionary
	var center_rk: int = settlement_id
	if center_rk < 0 and WorldMemory != null:
		center_rk = WorldMemory._region_key(tile.x, tile.y)
	if center_rk >= 0:
		return {"center_region": center_rk}
	return {}


func _auto_build_post_allowed(build_type: String, tile: Vector2i, settlement_id: int) -> bool:
	var planner: Node = get_node_or_null("/root/SettlementPlanner")
	var settlement: Dictionary = _settlement_dict_for_id(settlement_id, tile)
	if planner != null and planner.has_method("can_post_build_intent"):
		var job_type: int = int(BUILD_TO_JOB_TYPE.get(build_type, -1))
		return bool(planner.call("can_post_build_intent", settlement, build_type, job_type, tile))
	return true


func _mark_auto_build_intent_posted(build_type: String, tile: Vector2i, settlement_id: int) -> void:
	var planner: Node = get_node_or_null("/root/SettlementPlanner")
	if planner == null or not planner.has_method("mark_build_intent_posted"):
		return
	planner.call("mark_build_intent_posted", _settlement_dict_for_id(settlement_id, tile), build_type)


func _colony_survival_needs_met() -> bool:
	if ColonySimServices == null:
		return true
	if ColonySimServices.get_food_pressure() > 0.65:
		return false
	if ColonySimServices.get_housing_pressure() > 0.75:
		return false
	if ColonySimServices.get_warmth_pressure() > 0.45:
		return false
	return true


# ==================== PAWN SCANNING ====================

func _scan_for_new_pawns(_tick: int) -> void:
	# Check for pawns without assigned tasks
	for pawn in PawnAccess.find_pawns():
		if pawn == null or not is_instance_valid(pawn):
			continue

		var data: RefCounted = pawn.data
		if data == null:
			continue

		# Check if pawn is idle and needs direction
		var pawn_state: int = -1
		if pawn.has_method("get_state"):
			pawn_state = int(pawn.get_state())

		if pawn_state == 0 or pawn_state == -1:  # HeelKawnian.State.IDLE = 0
			var profession: int = -1
			if data.has_method("profession_name"):
				profession = int(data.get("current_profession"))
			elif data.has_meta("current_profession"):
				profession = int(data.get_meta("current_profession"))
			
			if profession == int(HeelKawnianData.Profession.BUILDER):
				_direct_builder_pawn(pawn, data)


func _direct_builder_pawn(pawn: Node, data: RefCounted) -> void:
	var tile: Vector2i = Vector2i.ZERO
	var settlement_id: int = -1

	if data.has_method("get"):
		var tile_v: Variant = data.get("tile_pos")
		if tile_v is Vector2i:
			tile = tile_v
		settlement_id = int(data.get("settlement_id"))
	elif data.has_meta("tile_pos"):
		tile = data.get_meta("tile_pos")
		settlement_id = int(data.get_meta("settlement_id"))

	# Create build intents for this builder
	create_build_intents(int(data.id), tile, settlement_id)


# ==================== PUBLIC API ====================

## Get all build intents
func get_all_intents() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for intent in build_intents:
		result.append(intent.duplicate() if intent is Dictionary else intent)
	return result

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
