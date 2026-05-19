extends Node
## PlayerGathering - Player gathers resources with their own hands
##
## Minecraft ease + Vintage Story depth:
## - Click tree → gather wood
## - Click rock → gather stone
## - Click bush → gather berries
## - Player inventory (carry what you gather)
## - Craft tools from gathered resources
##
## This is the foundation of player survival in HeelKawn.

# Player inventory
var player_inventory: Dictionary = {}  # {resource_type: quantity}

# Gathering configuration
const GATHERING_CONFIG: Dictionary = {
	"tree": {
		"base_quantity": [2, 5],  # [min, max] wood per gather
		"tool_required": false,  # Can punch trees
		"tool_bonus": "axe",  # Axe gives +50% yield
		"regrow_time": 10000,  # Ticks to regrow
		"skill": "chopping"
	},
	"rock": {
		"base_quantity": [1, 3],  # [min, max] stone per gather
		"tool_required": false,  # Can pick up loose stones
		"tool_bonus": "pickaxe",  # Pickaxe gives +100% yield
		"regrow_time": -1,  # Doesn't regrow (finite resource)
		"skill": "mining"
	},
	"bush": {
		"base_quantity": [1, 4],  # [min, max] berries per gather
		"tool_required": false,  # Can pick by hand
		"tool_bonus": "basket",  # Basket gives +25% yield
		"regrow_time": 3000,  # Ticks to regrow
		"skill": "foraging"
	},
	"flint": {
		"base_quantity": [1, 2],
		"tool_required": false,
		"tool_bonus": "none",
		"regrow_time": -1,
		"skill": "foraging"
	},
	"stick": {
		"base_quantity": [1, 3],
		"tool_required": false,
		"tool_bonus": "none",
		"regrow_time": 5000,
		"skill": "foraging"
	},
	"ore": {
		"base_quantity": [2, 8],
		"tool_required": true,
		"tool_bonus": "pickaxe",
		"regrow_time": -1,
		"skill": "mining"
	}
}

# Resource types
const RESOURCE_TYPES: Dictionary = {
	"wood": {"name": "Wood", "stack_size": 99, "category": "material"},
	"stone": {"name": "Stone", "stack_size": 99, "category": "material"},
	"berries": {"name": "Berries", "stack_size": 20, "category": "food", "nutrition": 5},
	"flint": {"name": "Flint", "stack_size": 50, "category": "material"},
	"stick": {"name": "Stick", "stack_size": 50, "category": "material"},
	"iron_ore": {"name": "Iron Ore", "stack_size": 50, "category": "ore"},
	"copper_ore": {"name": "Copper Ore", "stack_size": 50, "category": "ore"},
	"meat_raw": {"name": "Raw Meat", "stack_size": 10, "category": "food", "nutrition": 15},
	"hide": {"name": "Animal Hide", "stack_size": 20, "category": "material"},
}

# References
@onready var _world: Node = null
@onready var _world_memory: Node = null
@onready var _survival_system: Node = null
@onready var _player_pawn: Node = null
@onready var _stockpile_manager: Node = null


func _ready() -> void:
	_world = get_node_or_null("/root/Main/World")
	_world_memory = get_node_or_null("/root/WorldMemory")
	_survival_system = get_node_or_null("/root/SurvivalSystem")
	_stockpile_manager = get_node_or_null("/root/StockpileManager")
	
	# Initialize player inventory with starting items
	_init_player_inventory()


func _init_player_inventory() -> void:
	# Give player minimal starting resources
	player_inventory = {
		"wood": 0,
		"stone": 0,
		"berries": 5,  # Starting food
		"stick": 2,
		"flint": 0
	}


# ==================== GATHERING ACTIONS ====================

## Gather from tree (wood)
func gather_tree(tile: Vector2i) -> Dictionary:
	return _gather_resource(tile, "tree", "wood")


## Gather from rock (stone)
func gather_rock(tile: Vector2i) -> Dictionary:
	return _gather_resource(tile, "rock", "stone")


## Gather from bush (berries)
func gather_bush(tile: Vector2i) -> Dictionary:
	return _gather_resource(tile, "bush", "berries")


## Gather flint
func gather_flint(tile: Vector2i) -> Dictionary:
	return _gather_resource(tile, "flint", "flint")


## Gather sticks
func gather_stick(tile: Vector2i) -> Dictionary:
	return _gather_resource(tile, "stick", "stick")


## Gather ore
func gather_ore(tile: Vector2i, ore_type: String = "iron_ore") -> Dictionary:
	return _gather_resource(tile, "ore", ore_type)


# ==================== CORE GATHERING LOGIC ====================

func _gather_resource(tile: Vector2i, resource_type: String, output_resource: String) -> Dictionary:
	var result: Dictionary = {
		"success": false,
		"quantity": 0,
		"message": "",
		"skill_xp": 0
	}
	
	# Check if tile is valid
	if not _is_valid_gather_tile(tile, resource_type):
		result.message = "Nothing to gather here"
		return result
	
	# Get gathering config
	var config: Dictionary = GATHERING_CONFIG.get(resource_type, {})
	if config.is_empty():
		result.message = "Unknown resource type"
		return result
	
	# Calculate quantity
	var quantity: int = _calculate_gather_quantity(config, tile)
	if quantity <= 0:
		result.message = "Resource depleted"
		return result
	
	# Check tool requirement
	if config.get("tool_required", false):
		var has_tool: bool = _has_required_tool(config.get("tool_bonus", ""))
		if not has_tool:
			result.message = "Requires tool: " + config.get("tool_bonus", "unknown")
			return result
	
	# Apply to inventory
	_add_to_inventory(output_resource, quantity)
	
	# Gain skill XP
	var skill: String = config.get("skill", "foraging")
	var xp: int = quantity * 2
	_gain_skill_xp(skill, xp)
	result.skill_xp = xp
	
	# Remove or deplete resource from world
	_deplete_resource(tile, resource_type, config.get("regrow_time", -1))
	
	# Record gathering event
	_record_gather_event(output_resource, quantity, tile)
	
	result.success = true
	result.quantity = quantity
	result.message = "Gathered %d %s" % [quantity, output_resource]
	
	return result


func _is_valid_gather_tile(tile: Vector2i, resource_type: String) -> bool:
	if _world == null or _world.data == null:
		return false

	if not _world.data.in_bounds(tile.x, tile.y):
		return false

	# Check tile feature
	var feature: int = _world.data.get_feature(tile.x, tile.y)
	var biome: int = _world.data.get_biome(tile.x, tile.y)

	match resource_type:
		"tree":
			return feature == TileFeature.Type.TREE
		"rock":
			# Rocks: MOUNTAIN biome or RUIN feature
			return biome == Biome.Type.MOUNTAIN or feature == TileFeature.Type.RUIN
		"bush":
			# Bushes: FERTILE_SOIL biome or FARM_VEGETABLES feature
			return biome == Biome.Type.FERTILE_SOIL or feature == TileFeature.Type.FARM_VEGETABLES
		"flint":
			return feature == TileFeature.Type.FLINT or biome == Biome.Type.MOUNTAIN
		"stick":
			return feature == TileFeature.Type.TREE or biome == Biome.Type.FOREST
		"ore":
			return feature == TileFeature.Type.ORE_VEIN

	return false


func _calculate_gather_quantity(config: Dictionary, tile: Vector2i) -> int:
	var base_range: Array = config.get("base_quantity", [1, 1])
	var min_qty: int = base_range[0]
	var max_qty: int = base_range[1]
	
	# Base quantity (random within range) using deterministic WorldRNG
	var quantity: int = WorldRNG.rangei(min_qty, max_qty, 0, &"gather_quantity")
	
	# Tool bonus
	var tool_bonus: String = config.get("tool_bonus", "none")
	if tool_bonus != "none" and _has_required_tool(tool_bonus):
		if tool_bonus == "axe":
			quantity = int(quantity * 1.5)  # +50% wood
		elif tool_bonus == "pickaxe":
			quantity = quantity * 2  # +100% stone/ore
		elif tool_bonus == "basket":
			quantity = int(quantity * 1.25)  # +25% berries
	
	# Skill bonus (if player pawn has gathering skill)
	if _player_pawn != null and _player_pawn.data != null:
		var skill_level: int = _get_skill_level(config.get("skill", "foraging"))
		quantity += int(quantity * float(skill_level) * 0.05)  # +5% per skill level
	
	return quantity


func _has_required_tool(tool_name: String) -> bool:
	if _player_pawn == null or _player_pawn.data == null:
		return false
	if tool_name == "none" or tool_name.is_empty():
		return true

	# Map tool bonus names to actual Item.Type values
	var tool_to_item: Dictionary = {
		"axe": Item.Type.FLINT_KNIFE,       # closest to axe: cutting tool
		"pickaxe": Item.Type.FLINT_PICK,    # mining tool
		"basket": Item.Type.NONE,           # no basket item yet — allow without
	}
	var item_type: int = tool_to_item.get(tool_name.to_lower(), Item.Type.NONE)
	if item_type == Item.Type.NONE:
		# No specific item required for this tool bonus
		return true

	# Check if player pawn is carrying the tool
	if _player_pawn.data.carried_item == item_type:
		return true

	# Check stockpile for the tool
	if StockpileManager != null and StockpileManager.has_method("get_item_count"):
		return int(StockpileManager.call("get_item_count", item_type)) > 0

	return false


func _get_skill_level(skill_name: String) -> int:
	if _player_pawn == null or _player_pawn.data == null:
		return 0
	var data: HeelKawnianData = _player_pawn.data
	# Map skill names to HeelKawnianData.Skill enum
	var skill_map: Dictionary = {
		"foraging": 0,  # FORAGING
		"chopping": 1,  # WOODCUTTING
		"mining": 2,    # MINING
		"hunting": 4,   # HUNTING
		"building": 3,  # BUILDING
	}
	var skill_enum: int = skill_map.get(skill_name.to_lower(), 0)
	if data.has_method("get_skill_level"):
		return int(data.call("get_skill_level", skill_enum))
	# Fallback: check skill_xp dict
	var xp: int = int(data.skill_xp.get(skill_enum, 0))
	return xp / 100  # Level = total XP / 100


func _gain_skill_xp(skill_name: String, xp: int) -> void:
	if _player_pawn == null or _player_pawn.data == null:
		return
	var data: HeelKawnianData = _player_pawn.data
	var skill_map: Dictionary = {
		"foraging": 0,
		"chopping": 1,
		"mining": 2,
		"hunting": 4,
		"building": 3,
	}
	var skill_enum: int = skill_map.get(skill_name.to_lower(), 0)
	if data.has_method("add_skill_xp"):
		data.call("add_skill_xp", skill_enum, xp)
	elif data.has_method("gain_xp"):
		data.call("gain_xp", skill_enum, xp)
	else:
		# Direct dict update as fallback
		var current: int = int(data.skill_xp.get(skill_enum, 0))
		data.skill_xp[skill_enum] = current + xp
		data.level = _calculate_level_from_xp(data.skill_xp)
		if data.has_method("recalculate_perception"):
			data.call("recalculate_perception")


func _calculate_level_from_xp(skill_xp: Dictionary) -> int:
	var total: int = 0
	for v in skill_xp.values():
		total += int(v)
	return maxi(1, total / 100)


func _deplete_resource(tile: Vector2i, resource_type: String, regrow_time: int) -> void:
	if _world == null or _world.data == null:
		return
	if not _world.data.in_bounds(tile.x, tile.y):
		return

	# Map resource type to feature to remove
	var feature_to_remove: int = -1
	var feature_to_regrow: int = -1
	match resource_type:
		"tree":
			feature_to_remove = TileFeature.Type.TREE
			feature_to_regrow = TileFeature.Type.TREE
		"rock":
			# Rocks are biome-based (MOUNTAIN), not a feature — can't deplete
			return
		"bush":
			# Bushes may be FERTILE_SOIL biome or FARM_VEGETABLES feature
			var feature: int = _world.data.get_feature(tile.x, tile.y)
			if feature == TileFeature.Type.FARM_VEGETABLES:
				feature_to_remove = TileFeature.Type.FARM_VEGETABLES
				feature_to_regrow = TileFeature.Type.FARM_VEGETABLES
			else:
				# Biome-based bush — don't remove, just record
				pass
		"flint":
			feature_to_remove = TileFeature.Type.FLINT
			# Flint doesn't regrow (finite)
		"stick":
			# Sticks come from trees — don't remove the tree
			return
		"ore":
			feature_to_remove = TileFeature.Type.ORE_VEIN
			# Ore doesn't regrow (finite)

	# Remove the feature from the world tile if applicable
	if feature_to_remove >= 0:
		_world.data.set_feature(tile.x, tile.y, TileFeature.Type.NONE)

		# Schedule regrow if applicable (renewable resources only)
		if regrow_time > 0 and feature_to_regrow >= 0:
			var main: Node = get_node_or_null("/root/Main")
			if main != null and main.has_method("_queue_regrowth"):
				main.call("_queue_regrowth", tile, feature_to_regrow, regrow_time)

	# Record depletion in WorldMemory for persistence tracking
	if WorldMemory != null:
		WorldMemory.record_event({
			"type": "resource_depleted",
			"resource": resource_type,
			"tile_x": tile.x,
			"tile_y": tile.y,
			"regrow_ticks": regrow_time,
		})


func _record_gather_event(resource: String, quantity: int, tile: Vector2i) -> void:
	if _world_memory == null:
		return
	
	_world_memory.record_event({
		"type": "player_gathered",
		"resource": resource,
		"quantity": quantity,
		"tile": {"x": tile.x, "y": tile.y},
		"tick": GameManager.tick_count
	})


# ==================== INVENTORY MANAGEMENT ====================

func _add_to_inventory(resource: String, quantity: int) -> void:
	if not player_inventory.has(resource):
		player_inventory[resource] = 0
	
	var max_stack: int = RESOURCE_TYPES.get(resource, {}).get("stack_size", 99)
	player_inventory[resource] = mini(player_inventory[resource] + quantity, max_stack * 10)  # Allow multiple stacks


func remove_from_inventory(resource: String, quantity: int) -> bool:
	if not player_inventory.has(resource):
		return false
	
	if player_inventory[resource] < quantity:
		return false
	
	player_inventory[resource] -= quantity
	return true


func get_inventory_quantity(resource: String) -> int:
	return player_inventory.get(resource, 0)


func has_resource(resource: String, quantity: int) -> bool:
	return get_inventory_quantity(resource) >= quantity


func get_inventory() -> Dictionary:
	return player_inventory.duplicate()


func clear_inventory() -> void:
	player_inventory.clear()
	_init_player_inventory()


# ==================== CRAFTING FROM GATHERED RESOURCES ====================

## Craft basic tools from gathered resources
func craft_basic_tool(tool_type: String) -> Dictionary:
	var recipes: Dictionary = {
		"flint_knife": {"flint": 2, "stick": 1},
		"flint_pickaxe": {"flint": 3, "wood": 2},
		"wooden_axe": {"wood": 3, "stick": 2},
		"stone_pickaxe": {"stone": 5, "wood": 3},
		"torch": {"wood": 1, "stick": 1}
	}
	
	if not recipes.has(tool_type):
		return {"success": false, "message": "Unknown recipe"}
	
	var recipe: Dictionary = recipes[tool_type]
	
	# Check if player has resources
	for resource in recipe:
		if not has_resource(resource, recipe[resource]):
			return {
				"success": false,
				"message": "Missing %d %s" % [recipe[resource], resource]
			}
	
	# Remove resources
	for resource in recipe:
		remove_from_inventory(resource, recipe[resource])
	
	# Add crafted tool to inventory
	_add_to_inventory(tool_type, 1)
	
	# Record crafting event
	if _world_memory != null:
		_world_memory.record_event({
			"type": "player_crafted",
			"item": tool_type,
			"quantity": 1,
			"tick": GameManager.tick_count
		})
	
	return {"success": true, "message": "Crafted " + tool_type}


## Eat food from inventory
func eat_food(food_type: String) -> Dictionary:
	if not RESOURCE_TYPES.has(food_type):
		return {"success": false, "message": "Unknown food"}
	
	var food_data: Dictionary = RESOURCE_TYPES[food_type]
	if food_data.get("category") != "food":
		return {"success": false, "message": "Not edible"}
	
	if not has_resource(food_type, 1):
		return {"success": false, "message": "No food in inventory"}
	
	# Remove food
	remove_from_inventory(food_type, 1)
	
	# Feed player pawn
	if _player_pawn != null and _player_pawn.data != null and _survival_system != null:
		_survival_system.feed_pawn(_player_pawn, food_data.get("nutrition", 10))
	
	# Record eating event
	if _world_memory != null:
		_world_memory.record_event({
			"type": "player_ate",
			"food": food_type,
			"nutrition": food_data.get("nutrition", 0),
			"tick": GameManager.tick_count
		})
	
	return {"success": true, "message": "Ate " + food_type}


# ==================== PUBLIC API ====================

## Get player inventory display
func get_inventory_display() -> Array[Dictionary]:
	var display: Array[Dictionary] = []
	
	for resource in player_inventory:
		if player_inventory[resource] > 0:
			var data: Dictionary = RESOURCE_TYPES.get(resource, {})
			display.append({
				"resource": resource,
				"name": data.get("name", resource),
				"quantity": player_inventory[resource],
				"category": data.get("category", "material"),
				"icon": _get_resource_icon(resource)
			})
	
	return display


func _get_resource_icon(resource: String) -> String:
	# Return emoji icon for resource
	var icons: Dictionary = {
		"wood": "🪵",
		"stone": "🪨",
		"berries": "🫐",
		"flint": "🔩",
		"stick": "🥢",
		"iron_ore": "ite",
		"meat_raw": "🥩",
		"hide": "🟫"
	}
	return icons.get(resource, "❓")


## Get gathering hints for tile
func get_gathering_hint(tile: Vector2i) -> String:
	if _world == null or _world.data == null:
		return "Unknown"
	
	if not _world.data.in_bounds(tile.x, tile.y):
		return "Out of bounds"
	
	var feature: int = _world.data.get_feature(tile.x, tile.y)
	var biome: int = _world.data.get_biome(tile.x, tile.y)
	
	match feature:
		2: return "Tree (Gather Wood)"
		3, 4: return "Rock (Gather Stone)"
		6: return "Bush (Gather Berries)"
		7: return "Rocky ground (Search for Flint)"
		8: return "Ore vein (Mine for ore)"
	
	match biome:
		1: return "Plains (Forage for sticks)"
		2: return "Forest (Gather wood, sticks)"
		3: return "Mountains (Mine stone, ore)"
	
	return "Empty ground"


## Clear all data (for world reroll)
func clear() -> void:
	player_inventory.clear()
	_init_player_inventory()
