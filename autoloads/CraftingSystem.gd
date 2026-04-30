extends Node
## CraftingSystem.gd — Handles tool creation, crafting recipes, and item production
## Integrates with Pawn skills, materials, and job system

@onready var WorldMemory = get_node_or_null("/root/WorldMemory")
@onready var GameManager = get_node_or_null("/root/GameManager")
@onready var JobManager = get_node_or_null("/root/JobManager")

enum ToolType {
	SIMPLE_AXE = 0,
	SIMPLE_PICKAXE = 1,
	SIMPLE_KNIFE = 2,
	SIMPLE_BOW = 3,
	SIMPLE_FISHING_ROD = 4,
	BASIC_SHOVEL = 5,
	STONE_HAMMER = 6,
}

enum MaterialType {
	WOOD = 0,
	STONE = 1,
	BONE = 2,
	FIBER = 3,
	LEATHER = 4,
}

# Crafting recipes: recipe_id -> recipe data
var recipes: Dictionary = {}

# Active crafting jobs: job_id -> crafting data
var active_crafting: Dictionary = {}

# Tool durability: tool_id -> remaining uses
var tool_durability: Dictionary = {}

func _ready() -> void:
	_initialize_recipes()
	GameManager.game_tick.connect(_on_game_tick)

func _initialize_recipes() -> void:
	# Simple Axe: 2 wood + 1 stone
	recipes["simple_axe"] = {
		"result": ToolType.SIMPLE_AXE,
		"materials": {MaterialType.WOOD: 2, MaterialType.STONE: 1},
		"skill_required": "crafting",
		"skill_level": 10,
		"crafting_ticks": 200,
		"durability": 50,
	}
	
	# Simple Pickaxe: 2 wood + 2 stone
	recipes["simple_pickaxe"] = {
		"result": ToolType.SIMPLE_PICKAXE,
		"materials": {MaterialType.WOOD: 2, MaterialType.STONE: 2},
		"skill_required": "crafting",
		"skill_level": 15,
		"crafting_ticks": 250,
		"durability": 60,
	}
	
	# Simple Knife: 1 wood + 1 stone
	recipes["simple_knife"] = {
		"result": ToolType.SIMPLE_KNIFE,
		"materials": {MaterialType.WOOD: 1, MaterialType.STONE: 1},
		"skill_required": "crafting",
		"skill_level": 5,
		"crafting_ticks": 100,
		"durability": 30,
	}
	
	# Simple Bow: 2 wood + 1 fiber
	recipes["simple_bow"] = {
		"result": ToolType.SIMPLE_BOW,
		"materials": {MaterialType.WOOD: 2, MaterialType.FIBER: 1},
		"skill_required": "crafting",
		"skill_level": 20,
		"crafting_ticks": 300,
		"durability": 40,
	}
	
	# Simple Fishing Rod: 1 wood + 1 fiber
	recipes["simple_fishing_rod"] = {
		"result": ToolType.SIMPLE_FISHING_ROD,
		"materials": {MaterialType.WOOD: 1, MaterialType.FIBER: 1},
		"skill_required": "crafting",
		"skill_level": 10,
		"crafting_ticks": 150,
		"durability": 35,
	}
	
	# Basic Shovel: 1 wood + 2 stone
	recipes["basic_shovel"] = {
		"result": ToolType.BASIC_SHOVEL,
		"materials": {MaterialType.WOOD: 1, MaterialType.STONE: 2},
		"skill_required": "crafting",
		"skill_level": 12,
		"crafting_ticks": 180,
		"durability": 45,
	}
	
	# Stone Hammer: 1 stone + 1 wood
	recipes["stone_hammer"] = {
		"result": ToolType.STONE_HAMMER,
		"materials": {MaterialType.STONE: 1, MaterialType.WOOD: 1},
		"skill_required": "crafting",
		"skill_level": 8,
		"crafting_ticks": 120,
		"durability": 40,
	}

func _on_game_tick(tick: int) -> void:
	# Update active crafting jobs
	var to_remove: Array[int] = []
	for job_id in active_crafting.keys():
		var crafting_data: Dictionary = active_crafting[job_id]
		crafting_data["ticks_remaining"] -= 1
		
		if crafting_data["ticks_remaining"] <= 0:
			_complete_crafting(job_id, crafting_data)
			to_remove.append(job_id)
	
	for job_id in to_remove:
		active_crafting.erase(job_id)

# === Crafting Operations ===

func can_craft(pawn_id: int, recipe_name: String) -> Dictionary:
	var result: Dictionary = {"can_craft": false, "error": "", "missing_materials": []}
	
	if not recipes.has(recipe_name):
		result.error = "Unknown recipe: %s" % recipe_name
		return result
	
	var recipe: Dictionary = recipes[recipe_name]
	
	# Check skill level
	var skill_level: int = _get_pawn_skill_level(pawn_id, recipe.get("skill_required", "crafting"))
	var required_level: int = recipe.get("skill_level", 0)
	
	if skill_level < required_level:
		result.error = "Skill level too low (have %d, need %d)" % [skill_level, required_level]
		return result
	
	# Check materials
	var materials: Dictionary = recipe.get("materials", {})
	for material_type in materials.keys():
		var required_amount: int = materials[material_type]
		var available_amount: int = _get_pawn_material_count(pawn_id, material_type)
		
		if available_amount < required_amount:
			result.missing_materials.append({
				"type": material_type,
				"required": required_amount,
				"available": available_amount,
			})
	
	if not result.missing_materials.is_empty():
		result.error = "Missing materials"
		return result
	
	result.can_craft = true
	return result

func start_crafting(pawn_id: int, recipe_name: String, tile_pos: Vector2i) -> int:
	var check: Dictionary = can_craft(pawn_id, recipe_name)
	if not check.get("can_craft", false):
		return -1
	
	if not recipes.has(recipe_name):
		return -1
	
	var recipe: Dictionary = recipes[recipe_name]
	
	# Consume materials
	var materials: Dictionary = recipe.get("materials", {})
	for material_type in materials.keys():
		var amount: int = materials[material_type]
		_consume_pawn_material(pawn_id, material_type, amount)
	
	# Create crafting job
	var job_id: int = GameManager.tick_count * 1000 + active_crafting.size()
	active_crafting[job_id] = {
		"pawn_id": pawn_id,
		"recipe_name": recipe_name,
		"ticks_remaining": recipe.get("crafting_ticks", 100),
		"tile_pos": tile_pos,
		"started_tick": GameManager.tick_count,
	}
	
	# Record in WorldMemory
	var event: Dictionary = {
		"type": "crafting_started",
		"pawn_id": pawn_id,
		"recipe": recipe_name,
		"job_id": job_id,
		"tick": GameManager.tick_count,
	}
	if WorldMemory:
		WorldMemory.record_event(event)
	
	return job_id

func _complete_crafting(job_id: int, crafting_data: Dictionary) -> void:
	var pawn_id: int = crafting_data.get("pawn_id", -1)
	var recipe_name: String = crafting_data.get("recipe_name", "")
	
	if not recipes.has(recipe_name):
		return
	
	var recipe: Dictionary = recipes[recipe_name]
	var tool_type: int = recipe.get("result", -1)
	var durability: int = recipe.get("durability", 30)
	
	# Create tool
	var tool_id: int = GameManager.tick_count * 10000 + tool_durability.size()
	tool_durability[tool_id] = durability
	
	# Grant tool to pawn (would need PawnData integration)
	# For now, record the creation
	
	# Grant skill XP
	_grant_crafting_xp(pawn_id, recipe.get("skill_required", "crafting"), 10)
	
	# Record in WorldMemory
	var event: Dictionary = {
		"type": "crafting_completed",
		"pawn_id": pawn_id,
		"recipe": recipe_name,
		"tool_type": tool_type,
		"tool_id": tool_id,
		"tick": GameManager.tick_count,
	}
	if WorldMemory:
		WorldMemory.record_event(event)

# === Tool Usage ===

func use_tool(tool_id: int) -> bool:
	if not tool_durability.has(tool_id):
		return false
	
	tool_durability[tool_id] -= 1
	
	if tool_durability[tool_id] <= 0:
		tool_durability.erase(tool_id)
		return false
	
	return true

func get_tool_durability(tool_id: int) -> int:
	if tool_durability.has(tool_id):
		return tool_durability[tool_id]
	return 0

# === Helper Functions ===

func _get_pawn_skill_level(pawn_id: int, skill_name: String) -> int:
	var main: Node2D = Engine.get_main_loop().current_scene as Node2D
	if main == null:
		return 0
	
	var spawner: PawnSpawner = main.get("_pawn_spawner") as PawnSpawner
	if spawner == null:
		return 0
	
	for p in spawner.pawns:
		if p != null and is_instance_valid(p) and p.data != null and int(p.data.id) == pawn_id:
			# Get skill level from PawnData
			if skill_name == "crafting":
				return p.data.get_skill_level(Job.Type.CRAFTING)
			return 0
	
	return 0

func _get_pawn_material_count(pawn_id: int, material_type: int) -> int:
	# Placeholder: would need to check pawn inventory or nearby stockpiles
	# For now, assume materials are available
	return 10

func _consume_pawn_material(pawn_id: int, material_type: int, amount: int) -> void:
	# Placeholder: would need to actually consume from inventory
	pass

func _grant_crafting_xp(pawn_id: int, skill_name: String, xp_amount: int) -> void:
	var main: Node2D = Engine.get_main_loop().current_scene as Node2D
	if main == null:
		return
	
	var spawner: PawnSpawner = main.get("_pawn_spawner") as PawnSpawner
	if spawner == null:
		return
	
	for p in spawner.pawns:
		if p != null and is_instance_valid(p) and p.data != null and int(p.data.id) == pawn_id:
			# Grant XP to appropriate skill
			if skill_name == "crafting":
				p.data.add_skill_xp(Job.Type.CRAFTING, xp_amount)
			break

# === Query Functions ===

func get_recipe(recipe_name: String) -> Dictionary:
	if recipes.has(recipe_name):
		return recipes[recipe_name].duplicate(true)
	return {}

func get_all_recipes() -> Dictionary:
	return recipes.duplicate(true)

func get_tool_name(tool_type: int) -> String:
	match tool_type:
		ToolType.SIMPLE_AXE:
			return "Simple Axe"
		ToolType.SIMPLE_PICKAXE:
			return "Simple Pickaxe"
		ToolType.SIMPLE_KNIFE:
			return "Simple Knife"
		ToolType.SIMPLE_BOW:
			return "Simple Bow"
		ToolType.SIMPLE_FISHING_ROD:
			return "Simple Fishing Rod"
		ToolType.BASIC_SHOVEL:
			return "Basic Shovel"
		ToolType.STONE_HAMMER:
			return "Stone Hammer"
		_:
			return "Unknown Tool"

func get_material_name(material_type: int) -> String:
	match material_type:
		MaterialType.WOOD:
			return "Wood"
		MaterialType.STONE:
			return "Stone"
		MaterialType.BONE:
			return "Bone"
		MaterialType.FIBER:
			return "Fiber"
		MaterialType.LEATHER:
			return "Leather"
		_:
			return "Unknown Material"

# === Save/Load ===

func to_save_dict() -> Dictionary:
	return {
		"active_crafting": active_crafting.duplicate(true),
		"tool_durability": tool_durability.duplicate(true),
	}

func from_save_dict(d: Dictionary) -> void:
	active_crafting.clear()
	tool_durability.clear()
	
	if d.has("active_crafting"):
		active_crafting = d["active_crafting"].duplicate(true)
	if d.has("tool_durability"):
		tool_durability = d["tool_durability"].duplicate(true)

func clear() -> void:
	active_crafting.clear()
	tool_durability.clear()
