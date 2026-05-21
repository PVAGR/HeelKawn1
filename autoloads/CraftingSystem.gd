extends Node
## CraftingSystem - Multi-step recipes and workshops
##
## Pawns can craft items from raw materials:
## - Tools (pickaxes, axes, spears)
## - Weapons (swords, bows, armor)
## - Furniture (tables, chairs, decorations)
## - Medicine (herbal remedies, bandages)
##
## Requires:
## - Smith profession for metalworking
## - Healer profession for medicine
## - Workshop building for advanced crafting

# Recipe data structure
## {
##   "recipe_id": String,
##   "name": String,
##   "category": String,  # "tool", "weapon", "furniture", "medicine"
##   "ingredients": Dictionary,  # {item_type: quantity}
##   "craft_ticks": int,
##   "required_profession": int,  # Profession enum
##   "required_skill": int,  # Skill enum
##   "min_skill_level": int,
##   "output_item": int,  # Item.Type
##   "output_quantity": int,
##   "required_tools": Array[int],  # Item.Type values for required tools/buildings (optional)
## }
var recipes: Dictionary = {}

# Active crafting jobs
## {
##   "job_id": int,
##   "recipe_id": String,
##   "craftsman_id": int,  # pawn_id
##   "progress": float,  # 0.0 to 1.0
##   "workshop_tile": Vector2i,
##   "started_tick": int
## }
var active_crafting_jobs: Array[Dictionary] = []
var _next_job_id: int = 1

## Gear inventory: GearItem instances stored in the stockpile, ready for equipping.
## Key = item_id (String), Value = GearItem instance
var _gear_inventory: Dictionary = {}

# References
@onready var _world_memory: Node = null
@onready var _world: Node = null
@onready var _job_manager: Node = null
@onready var _stockpile_manager: Node = null
@onready var _pawn_spawner: Node = null


func _ready() -> void:
	GameManager.game_tick.connect(_on_game_tick)
	_world_memory = get_node_or_null("/root/WorldMemory")
	_world = get_node_or_null("/root/Main/World")
	_job_manager = get_node_or_null("/root/JobManager")
	_stockpile_manager = get_node_or_null("/root/StockpileManager")
	_pawn_spawner = get_node_or_null("/root/Main/WorldViewport/PawnSpawner")
	
	# Initialize recipes
	_initialize_recipes()


func _on_game_tick(tick: int) -> void:
	# Throttle: crafting progress doesn't need per-tick updates at high speed
	var interval: int = 1
	if GameManager != null:
		var gs: float = GameManager.game_speed
		if gs >= 100.0:
			interval = 5
		elif gs >= 50.0:
			interval = 3
		elif gs >= 26.0:
			interval = 2
	if tick % interval != 0:
		return
	# Update active crafting jobs
	_update_crafting_progress(tick)


func _initialize_recipes() -> void:
	# ===== AMMUNITION =====
	_add_recipe({
		"recipe_id": "stone_arrow",
		"name": "Stone Arrow",
		"category": "ammunition",
		"ingredients": {"flint": 1, "stick": 1},
		"craft_ticks": 20,
		"required_profession": -1,
		"required_skill": 4,  # HUNTING
		"min_skill_level": 1,
		"output_item": Item.Type.STONE_ARROW,
		"output_quantity": 5
	})
	
	_add_recipe({
		"recipe_id": "bone_arrow",
		"name": "Bone Arrow",
		"category": "ammunition",
		"ingredients": {"bone": 1, "stick": 1},
		"craft_ticks": 25,
		"required_profession": -1,
		"required_skill": 4,  # HUNTING
		"min_skill_level": 2,
		"output_item": Item.Type.BONE_ARROW,
		"output_quantity": 5
	})
	
	# ===== TOOLS =====
	_add_recipe({
		"recipe_id": "flint_knife",
		"name": "Flint Knife",
		"category": "tool",
		"ingredients": {"flint": 2, "stick": 1},
		"craft_ticks": 50,
		"required_profession": -1,  # Any profession
		"required_skill": 2,  # CHOPPING
		"min_skill_level": 1,
		"output_item": 10,  # FLINT_KNIFE
		"output_quantity": 1
	})
	
	_add_recipe({
		"recipe_id": "flint_pickaxe",
		"name": "Flint Pickaxe",
		"category": "tool",
		"ingredients": {"flint": 3, "stick": 2, "wood": 1},
		"craft_ticks": 80,
		"required_profession": -1,
		"required_skill": 1,  # MINING
		"min_skill_level": 2,
		"output_item": 13,  # FLINT_PICK
		"output_quantity": 1
	})
	
	_add_recipe({
		"recipe_id": "wooden_spear",
		"name": "Wooden Spear",
		"category": "tool",
		"ingredients": {"wood": 2, "stick": 1},
		"craft_ticks": 60,
		"required_profession": -1,
		"required_skill": 4,  # HUNTING
		"min_skill_level": 2,
		"output_item": 14,  # WOODEN_SPEAR
		"output_quantity": 1
	})
	
	# ===== WEAPONS (Smith only) =====
	_add_recipe({
		"recipe_id": "iron_sword",
		"name": "Iron Sword",
		"category": "weapon",
		"ingredients": {"iron": 3, "wood": 1},
		"craft_ticks": 150,
		"required_profession": 7,  # SMITH
		"required_skill": 1,  # MINING
		"min_skill_level": 5,
		"output_item": 20,  # IRON_SWORD (new)
		"output_quantity": 1,
		"required_tools": [Item.Type.FLINT_PICK],  # Needs hammer/striking tool
		"required_buildings": [TileFeature.Type.SMELTER],  # Must be near smelter
	})
	
	# ===== FURNITURE =====
	_add_recipe({
		"recipe_id": "wooden_table",
		"name": "Wooden Table",
		"category": "furniture",
		"ingredients": {"wood": 4},
		"craft_ticks": 100,
		"required_profession": -1,
		"required_skill": 3,  # BUILDING
		"min_skill_level": 3,
		"output_item": 30,  # FURNITURE_TABLE
		"output_quantity": 1
	})
	
	# ===== MEDICINE (Healer only) =====
	_add_recipe({
		"recipe_id": "herbal_remedy",
		"name": "Herbal Remedy",
		"category": "medicine",
		"ingredients": {"herbs": 3},
		"craft_ticks": 40,
		"required_profession": 8,  # HEALER
		"required_skill": 0,  # FORAGING
		"min_skill_level": 3,
		"output_item": 40,  # HERBAL_MEDICINE
		"output_quantity": 2
	})
	
	_add_recipe({
		"recipe_id": "bandages",
		"name": "Bandages",
		"category": "medicine",
		"ingredients": {"cloth": 2},
		"craft_ticks": 30,
		"required_profession": 8,  # HEALER
		"required_skill": 0,  # FORAGING
		"min_skill_level": 2,
		"output_item": 41,  # BANDAGES
		"output_quantity": 3
	})

	# ===== KNOWLEDGE (Phase 5: Book System) =====
	_add_recipe({
		"recipe_id": "paper",
		"name": "Paper",
		"category": "knowledge",
		"ingredients": {"stick": 3},
		"craft_ticks": 40,
		"required_profession": -1,
		"required_skill": 0,  # FORAGING
		"min_skill_level": 1,
		"output_item": Item.Type.PAPER,
		"output_quantity": 5
	})
	
	_add_recipe({
		"recipe_id": "leather_binding",
		"name": "Leather Binding",
		"category": "knowledge",
		"ingredients": {"meat": 2},
		"craft_ticks": 60,
		"required_profession": -1,
		"required_skill": 4,  # HUNTING
		"min_skill_level": 2,
		"output_item": Item.Type.LEATHER,
		"output_quantity": 1
	})
	
	_add_recipe({
		"recipe_id": "ink",
		"name": "Ink",
		"category": "knowledge",
		"ingredients": {"berry": 2},
		"craft_ticks": 30,
		"required_profession": -1,
		"required_skill": 0,  # FORAGING
		"min_skill_level": 1,
		"output_item": Item.Type.INK,
		"output_quantity": 2
	})
	
	_add_recipe({
		"recipe_id": "quill_pen",
		"name": "Quill Pen",
		"category": "knowledge",
		"ingredients": {"stick": 1},
		"craft_ticks": 20,
		"required_profession": -1,
		"required_skill": 0,  # FORAGING
		"min_skill_level": 1,
		"output_item": Item.Type.PEN,
		"output_quantity": 1
	})
	
	_add_recipe({
		"recipe_id": "blank_book",
		"name": "Blank Book",
		"category": "knowledge",
		"ingredients": {"paper": 5, "leather": 1},
		"craft_ticks": 100,
		"required_profession": -1,
		"required_skill": 3,  # BUILDING
		"min_skill_level": 3,
		"output_item": Item.Type.BOOK,
		"output_quantity": 1
	})


func _add_recipe(recipe_data: Dictionary) -> void:
	recipes[recipe_data.recipe_id] = recipe_data


## Returns a list of recipes that can be crafted given the available materials.
## inventory: Dictionary {item_type (String/int): quantity (int)}
func get_available_recipes(inventory: Dictionary) -> Array[Dictionary]:
	var available: Array[Dictionary] = []
	for recipe_id in recipes:
		var recipe: Dictionary = recipes[recipe_id]
		var can_craft: bool = true
		var ingredients: Dictionary = recipe.get("ingredients", {})
		
		for resource in ingredients:
			var required_qty: int = ingredients[resource]
			var available_qty: int = inventory.get(resource, 0)
			if available_qty < required_qty:
				can_craft = false
				break
		
		if can_craft:
			available.append(recipe)
	return available


func get_recipe(recipe_id: String) -> Dictionary:
	return recipes.get(recipe_id, {})


func _update_crafting_progress(tick: int) -> void:
	for i in range(active_crafting_jobs.size() - 1, -1, -1):
		var job: Dictionary = active_crafting_jobs[i]
		
		# Get recipe
		var recipe: Dictionary = recipes.get(job.recipe_id, {})
		if recipe.is_empty():
			active_crafting_jobs.remove_at(i)
			continue
		
		# Calculate progress increment
		var progress_increment: float = 1.0 / float(recipe.craft_ticks)
		
		# Apply craftsman skill bonus
		var craftsman: HeelKawnian = _get_pawn_by_id(job.craftsman_id)
		if craftsman != null and craftsman.data != null:
			var skill_level: int = craftsman.data.get_skill_level(recipe.required_skill)
			progress_increment *= (1.0 + float(skill_level) * 0.05)  # +5% per level
		
		# Water mill bonus: if a WATER_MILL is within 2 tiles of the workshop, +50% speed
		if _is_near_water_mill(job.workshop_tile):
			progress_increment *= 1.5
		
		# Update progress
		job.progress += progress_increment
		
		# Check if complete
		if job.progress >= 1.0:
			_complete_crafting_job(job, tick)
			active_crafting_jobs.remove_at(i)


func _complete_crafting_job(job: Dictionary, tick: int) -> void:
	var recipe: Dictionary = recipes[job.recipe_id]

	# CRITICAL: Consume ingredients from stockpile
	_consume_ingredients(recipe.ingredients)

	# Determine if this recipe produces equippable gear
	var category: String = str(recipe.get("category", ""))
	var is_equippable: bool = (category == "tool" or category == "weapon" or category == "armor")

	if is_equippable:
		# Create a GearItem with quality from the crafter
		var craftsman_data: HeelKawnianData = null
		var craftsman: HeelKawnian = _get_pawn_by_id(job.craftsman_id)
		if craftsman != null and craftsman.data != null:
			craftsman_data = craftsman.data
		var _GearItem = load("res://scripts/items/GearItem.gd")
		if _GearItem != null:
			var gear = _GearItem.from_item_type(int(recipe.get("output_item", 0)), craftsman_data)
			# Store gear in stockpile gear inventory
			_store_gear_item(gear)
			# Also add raw item to stockpile for backward compatibility
			if _stockpile_manager != null:
				_stockpile_manager.add_item(int(recipe.get("output_item", 0)), int(recipe.get("output_quantity", 1)))
		else:
			# Fallback: just add raw item
			if _stockpile_manager != null:
				_stockpile_manager.add_item(int(recipe.get("output_item", 0)), int(recipe.get("output_quantity", 1)))
	else:
		# Add crafted items to stockpile (non-equippable)
		if _stockpile_manager != null:
			_stockpile_manager.add_item(int(recipe.get("output_item", 0)), int(recipe.get("output_quantity", 1)))

	# Record crafting event
	if _world_memory != null:
		_world_memory.record_event({
			"type": "item_crafted",
			"recipe_id": job.recipe_id,
			"item_name": recipe.name,
			"quantity": recipe.output_quantity,
			"craftsman_id": job.craftsman_id,
			"workshop_tile": {"x": job.workshop_tile.x, "y": job.workshop_tile.y},
			"tick": tick
		})

	if OS.is_debug_build():
		print("[Crafting] Completed: %s x%d" % [recipe.name, recipe.output_quantity])


func _get_pawn_by_id(pawn_id: int) -> HeelKawnian:
	if _pawn_spawner == null:
		return null
	
	for pawn in _pawn_spawner.pawns:
		if pawn != null and is_instance_valid(pawn) and int(pawn.data.id) == pawn_id:
			return pawn
	
	return null


# ==================== Public API ====================

## Get all recipes
func get_all_recipes() -> Dictionary:
	return recipes.duplicate()

## Get recipes by category
func get_recipes_by_category(category: String) -> Array:
	var result: Array = []
	for recipe in recipes.values():
		if recipe.category == category:
			result.append(recipe.duplicate())
	return result

## Check if a pawn can craft a recipe
func can_craft_recipe(pawn: HeelKawnian, recipe_id: String, workshop_tile: Vector2i = Vector2i.ZERO) -> Dictionary:
	var result: Dictionary = {
		"can_craft": false,
		"reason": ""
	}
	
	if pawn == null or pawn.data == null:
		result.reason = "Invalid pawn"
		return result
	
	var recipe: Dictionary = recipes.get(recipe_id, {})
	if recipe.is_empty():
		result.reason = "Unknown recipe"
		return result
	
	# Check profession
	if recipe.required_profession >= 0:
		if int(pawn.data.current_profession) != recipe.required_profession:
			result.reason = "Wrong profession"
			return result
	
	# Check skill level
	var skill_level: int = pawn.data.get_skill_level(recipe.required_skill)
	if skill_level < recipe.min_skill_level:
		result.reason = "Skill level too low (%d < %d)" % [skill_level, recipe.min_skill_level]
		return result
	
	# Check ingredients
	if not _has_ingredients(recipe.ingredients):
		result.reason = "Missing ingredients"
		return result
	
	# Check required tools (carried or in stockpile)
	if not _has_required_tools(pawn, recipe):
		result.reason = "Missing required tools"
		return result
	
	# Check required buildings (near workshop)
	var check_tile: Vector2i = workshop_tile if workshop_tile != Vector2i.ZERO else pawn.data.tile_pos
	if not _has_required_buildings(recipe, check_tile):
		result.reason = "Missing required workshop building"
		return result
	
	result.can_craft = true
	return result


func _has_ingredients(ingredients: Dictionary) -> bool:
	if _stockpile_manager == null:
		return false

	# Check if stockpile has all required ingredients
	for resource in ingredients:
		var required_qty: int = ingredients[resource]
		var available_qty: int = _get_stockpile_quantity(resource)
		if available_qty < required_qty:
			return false
	return true

func _get_stockpile_quantity(resource: String) -> int:
	# Map resource names to Item.Type enums
	var resource_to_item: Dictionary = {
		"flint": Item.Type.FLINT,
		"stick": Item.Type.STICK,
		"wood": Item.Type.WOOD,
		"iron": 4,
		"herbs": 5,
		"cloth": 6,
		"meat": Item.Type.MEAT,
		"berry": Item.Type.BERRY,
		"paper": Item.Type.PAPER,
		"leather": Item.Type.LEATHER,
		"bone": Item.Type.BONE,
	}
	
	var item_type: int = resource_to_item.get(resource, -1)
	if item_type < 0 or _stockpile_manager == null:
		return 0
	
	# Use StockpileManager's total_count_of method
	if _stockpile_manager.has_method("total_count_of"):
		return int(_stockpile_manager.call("total_count_of", item_type))
	
	return 0


## Check if pawn has all required tools for a recipe.
## Tools can be carried by the pawn or available in stockpile.
func _has_required_tools(pawn: HeelKawnian, recipe: Dictionary) -> bool:
	var required: Array = recipe.get("required_tools", [])
	if required.is_empty():
		return true
	
	for tool_type in required:
		var tt: int = int(tool_type)
		if tt <= 0:
			continue
		# Check if pawn is carrying the tool
		if pawn.data != null and pawn.data.carrying == tt and pawn.data.carrying_qty > 0:
			continue
		# Check if pawn has the tool equipped as gear
		if pawn.data != null and pawn.data.has_method("is_equipped"):
			if pawn.data.call("is_equipped", tt):
				continue
		# Check stockpile for the tool
		if _stockpile_manager != null and _stockpile_manager.has_method("total_count_of"):
			if int(_stockpile_manager.call("total_count_of", tt)) > 0:
				continue
		# Tool not found
		return false
	return true


## Check if required buildings are near the given tile.
func _has_required_buildings(recipe: Dictionary, near_tile: Vector2i) -> bool:
	var required: Array = recipe.get("required_buildings", [])
	if required.is_empty():
		return true
	if _world == null or _world.data == null:
		return required.is_empty()
	
	var wd = _world.data
	var search_radius: int = 3
	for building_type in required:
		var bt: int = int(building_type)
		if bt <= 0:
			continue
		var found: bool = false
		for dx in range(-search_radius, search_radius + 1):
			for dy in range(-search_radius, search_radius + 1):
				var nx: int = near_tile.x + dx
				var ny: int = near_tile.y + dy
				if not wd.in_bounds(nx, ny):
					continue
				if wd.get_feature(nx, ny) == bt:
					found = true
					break
			if found:
				break
		if not found:
			return false
	return true

func _consume_ingredients(ingredients: Dictionary) -> bool:
	if _stockpile_manager == null:
		return false
	
	# Map resource names to Item.Type enums
	var resource_to_item: Dictionary = {
		"flint": Item.Type.FLINT,
		"stick": Item.Type.STICK,
		"wood": Item.Type.WOOD,
		"iron": 4,
		"herbs": 5,
		"cloth": 6,
		"meat": Item.Type.MEAT,
		"berry": Item.Type.BERRY,
		"paper": Item.Type.PAPER,
		"leather": Item.Type.LEATHER,
		"bone": Item.Type.BONE,
	}
	
	# Consume each ingredient from stockpile
	for resource in ingredients:
		var required_qty: int = ingredients[resource]
		var item_type: int = resource_to_item.get(resource, -1)
		if item_type < 0:
			continue
		
		# Remove from stockpile
		if _stockpile_manager.has_method("remove_item"):
			_stockpile_manager.call("remove_item", item_type, required_qty)
		elif _stockpile_manager.has_method("take_item"):
			_stockpile_manager.call("take_item", item_type, required_qty)
	
	return true


## Start a crafting job
func start_crafting(recipe_id: String, craftsman_id: int, workshop_tile: Vector2i) -> int:
	var recipe: Dictionary = recipes.get(recipe_id, {})
	if recipe.is_empty():
		return -1
	
	# Create job
	var job: Dictionary = {
		"job_id": _next_job_id,
		"recipe_id": recipe_id,
		"craftsman_id": craftsman_id,
		"progress": 0.0,
		"workshop_tile": workshop_tile,
		"started_tick": GameManager.tick_count
	}
	
	active_crafting_jobs.append(job)
	_next_job_id += 1
	
	return job.job_id


## Get active crafting jobs
func get_active_jobs() -> Array[Dictionary]:
	return active_crafting_jobs.duplicate()

## Get crafting statistics
func get_stats() -> Dictionary:
	var stats: Dictionary = {
		"total_recipes": recipes.size(),
		"active_jobs": active_crafting_jobs.size(),
		"by_category": {}
	}
	
	for recipe in recipes.values():
		var category: String = recipe.category
		stats.by_category[category] = stats.by_category.get(category, 0) + 1
	
	return stats

## Debug: Complete all active jobs
func debug_complete_all_jobs() -> void:
	for job in active_crafting_jobs:
		job.progress = 1.0
	print("[Crafting] Debug: Completed %d jobs" % active_crafting_jobs.size())

## Debug: Add recipe
func debug_add_recipe(recipe_data: Dictionary) -> void:
	_add_recipe(recipe_data)
	print("[Crafting] Debug: Added recipe %s" % recipe_data.get("recipe_id", "unknown"))


## Store a GearItem in the stockpile gear inventory
func _store_gear_item(gear: Variant) -> void:
	if gear == null or not gear.has_method("to_dict"):
		return
	_gear_inventory[str(gear.item_id)] = gear


## Get all available gear items in the stockpile
func get_available_gear() -> Array:
	var result: Array = []
	for gear_id in _gear_inventory:
		var gear: Variant = _gear_inventory[gear_id]
		if gear != null and not gear.is_broken():
			result.append(gear)
	return result


## Get gear items for a specific slot
func get_gear_for_slot(slot: int) -> Array:
	var result: Array = []
	for gear_id in _gear_inventory:
		var gear: Variant = _gear_inventory[gear_id]
		if gear != null and not gear.is_broken() and int(gear.slot) == slot:
			result.append(gear)
	return result


## Remove a gear item from inventory (after equipping)
func remove_gear_from_inventory(item_id: String) -> Variant:
	var gear: Variant = _gear_inventory.get(item_id, null)
	if gear != null:
		_gear_inventory.erase(item_id)
	return gear


## Try to equip a pawn with better gear from the stockpile.
## Called periodically by the pawn AI.
func try_equip_from_stockpile(pawn_data: HeelKawnianData) -> bool:
	if pawn_data == null:
		return false
	var equipped_any: bool = false
	# Check each slot
	for slot_idx in range(5):
		var current_gear: Variant = pawn_data.equipped_gear.get(slot_idx, null)
		var best_gear: Variant = null
		var best_score: float = -1.0
		# Find best available gear for this slot
		var candidates: Array = get_gear_for_slot(slot_idx)
		for candidate in candidates:
			if candidate == null:
				continue
			var score: float = _gear_score(candidate)
			# Must be better than current
			if current_gear != null and current_gear.has_method("is_broken"):
				if not current_gear.is_broken():
					var current_score: float = _gear_score(current_gear)
					if score <= current_score:
						continue
			if score > best_score:
				best_score = score
				best_gear = candidate
		# Equip if found something better
		if best_gear != null and best_score > 0.0:
			var old: Variant = pawn_data.equip_gear(best_gear)
			remove_gear_from_inventory(str(best_gear.item_id))
			# Put old gear back in inventory
			if old != null and old.has_method("is_broken") and not old.is_broken():
				_store_gear_item(old)
			equipped_any = true
	return equipped_any


## Score a gear item for comparison (higher = better)
func _gear_score(gear: Variant) -> float:
	if gear == null:
		return -1.0
	return float(gear.attack) + float(gear.defense) * 1.5 + float(gear.work_speed) * 10.0 + float(gear.warmth) * 2.0 + float(gear.quality) * 5.0


## Check if a workshop tile has a WATER_MILL within 2 tiles.
func _is_near_water_mill(workshop_tile: Vector2i) -> bool:
	if _world == null or _world.data == null:
		return false
	var wd = _world.data
	for dx in range(-2, 3):
		for dy in range(-2, 3):
			if dx == 0 and dy == 0:
				continue
			var nx: int = workshop_tile.x + dx
			var ny: int = workshop_tile.y + dy
			if not wd.in_bounds(nx, ny):
				continue
			if wd.get_feature(nx, ny) == TileFeature.Type.WATER_MILL:
				return true
	return false
