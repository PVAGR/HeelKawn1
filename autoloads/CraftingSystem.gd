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
##   "output_quantity": int
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

# References
@onready var _world_memory: Node = null
@onready var _job_manager: Node = null
@onready var _stockpile_manager: Node = null
@onready var _pawn_spawner: Node = null


func _ready() -> void:
	GameManager.game_tick.connect(_on_game_tick)
	_world_memory = get_node_or_null("/root/WorldMemory")
	_job_manager = get_node_or_null("/root/JobManager")
	_stockpile_manager = get_node_or_null("/root/StockpileManager")
	_pawn_spawner = get_node_or_null("/root/Main/WorldViewport/PawnSpawner")
	
	# Initialize recipes
	_initialize_recipes()


func _on_game_tick(tick: int) -> void:
	# Update active crafting jobs
	_update_crafting_progress(tick)


func _initialize_recipes() -> void:
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
		"output_quantity": 1
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
		var craftsman: Pawn = _get_pawn_by_id(job.craftsman_id)
		if craftsman != null and craftsman.data != null:
			var skill_level: int = craftsman.data.get_skill_level(recipe.required_skill)
			progress_increment *= (1.0 + float(skill_level) * 0.05)  # +5% per level
		
		# Update progress
		job.progress += progress_increment
		
		# Check if complete
		if job.progress >= 1.0:
			_complete_crafting_job(job, tick)
			active_crafting_jobs.remove_at(i)


func _complete_crafting_job(job: Dictionary, tick: int) -> void:
	var recipe: Dictionary = recipes[job.recipe_id]
	
	# Add crafted items to stockpile
	if _stockpile_manager != null:
		_stockpile_manager.add_item(recipe.output_item, recipe.output_quantity)
	
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


func _get_pawn_by_id(pawn_id: int) -> Pawn:
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
func can_craft_recipe(pawn: Pawn, recipe_id: String) -> Dictionary:
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
	
	result.can_craft = true
	return result


func _has_ingredients(ingredients: Dictionary) -> bool:
	if _stockpile_manager == null:
		return false
	
	# Simplified check - would need actual item tracking
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
