extends PanelContainer
## CraftingMenu.gd — Player tool crafting UI
##
## Shows craftable tools with recipes.
## Player clicks craft button, resources auto-deducted.
## Crafted items added to player inventory.

const RECIPES: Dictionary = {
	"flint_knife": {
		"name": "Flint Knife",
		"icon": "🔪",
		"resources": {"flint": 2, "stick": 1},
		"description": "Basic cutting tool (butchery, crafting)",
		"craft_time": 30  # ticks
	},
	"flint_pickaxe": {
		"name": "Flint Pickaxe",
		"icon": "⛏️",
		"resources": {"flint": 3, "stick": 2, "wood": 1},
		"description": "Mining tool (+50% stone yield)",
		"craft_time": 50
	},
	"wooden_axe": {
		"name": "Wooden Axe",
		"icon": "🪓",
		"resources": {"wood": 5, "stick": 2},
		"description": "Chopping tool (+50% wood yield)",
		"craft_time": 40
	},
	"wooden_spear": {
		"name": "Wooden Spear",
		"icon": "🔱",
		"resources": {"wood": 3, "stick": 2, "flint": 1},
		"description": "Hunting weapon (range, damage)",
		"craft_time": 60
	},
	"torch": {
		"name": "Torch",
		"icon": "🔥",
		"resources": {"wood": 1, "stick": 1},
		"description": "Light source (lasts 1000 ticks)",
		"craft_time": 10
	},
	"basket": {
		"name": "Basket",
		"icon": "🧺",
		"resources": {"stick": 5},
		"description": "Foraging tool (+25% berry yield)",
		"craft_time": 30
	},
}

var _player_gathering: Node = null
var _player_building: Node = null

@onready var _recipes_list: VBoxContainer = $MarginContainer/VBoxContainer/ScrollContainer/RecipesList
@onready var _close_button: Button = $MarginContainer/VBoxContainer/CloseButton


func _ready() -> void:
	_player_gathering = get_node_or_null("/root/PlayerGathering")
	_player_building = get_node_or_null("/root/PlayerBuilding")
	
	_close_button.pressed.connect(_on_close_pressed)
	
	# Hide by default
	visible = false
	
	# Build recipe list
	_build_recipe_list()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	
	# Toggle with C key
	if event is InputEventKey and event.pressed and event.keycode == KEY_C:
		visible = not visible
		if visible:
			_refresh_recipes()


## Build recipe buttons
func _build_recipe_list() -> void:
	# Clear existing
	for child in _recipes_list.get_children():
		child.queue_free()
	
	# Add recipe buttons
	for recipe_key in RECIPES:
		var recipe: Dictionary = RECIPES[recipe_key]
		var btn: Button = Button.new()
		btn.name = recipe_key
		btn.custom_minimum_size = Vector2(360, 60)
		btn.text_alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.pressed.connect(_on_craft_pressed.bind(recipe_key))
		btn.mouse_entered.connect(_on_recipe_hovered.bind(recipe_key))
		_recipes_list.add_child(btn)


## Refresh recipe buttons (enable/disable based on resources)
func _refresh_recipes() -> void:
	for recipe_key in RECIPES:
		var recipe: Dictionary = RECIPES[recipe_key]
		var btn: Button = get_node_or_null("MarginContainer/VBoxContainer/ScrollContainer/RecipesList/" + recipe_key)
		if btn == null:
			continue
		
		var can_craft: bool = _check_resources(recipe.resources)
		btn.disabled = not can_craft
		btn.modulate = Color(1, 1, 1, 1.0 if can_craft else 0.5)
		
		var tooltip: String = "[b]%s[/b]\n%s\n\n[color=#FFD166]Requires:[/color]\n%s" % [
			recipe.name,
			recipe.description,
			_format_resources(recipe.resources)
		]
		btn.tooltip_text = tooltip


func _on_craft_pressed(recipe_key: String) -> void:
	var recipe: Dictionary = RECIPES[recipe_key]
	
	# Check resources
	if not _check_resources(recipe.resources):
		push_notification("Missing resources for %s!" % recipe.name)
		return
	
	# Craft the item
	_craft_item(recipe_key, recipe)


func _craft_item(recipe_key: String, recipe: Dictionary) -> void:
	# Deduct resources
	_deduct_resources(recipe.resources)

	# Add crafted item to inventory
	if _player_gathering != null:
		var inventory: Dictionary = _player_gathering.player_inventory if _player_gathering.has("player_inventory") else {}
		inventory[recipe_key] = (inventory[recipe_key] if inventory.has(recipe_key) else 0) + 1

		# Refresh recipe list
		_refresh_recipes()

		push_notification("Crafted %s!" % recipe.name)


func _on_recipe_hovered(recipe_key: String) -> void:
	var recipe: Dictionary = RECIPES[recipe_key]
	# Tooltip already set in _refresh_recipes


func _check_resources(resources: Dictionary) -> bool:
	if _player_gathering == null:
		return false

	var inventory: Dictionary = _player_gathering.player_inventory if _player_gathering.has("player_inventory") else {}
	for resource in resources:
		var required: int = resources[resource]
		var has: int = inventory[resource] if inventory.has(resource) else 0
		if has < required:
			return false
	return true


func _has_resource(resource: String, amount: int) -> bool:
	if _player_gathering == null:
		return false

	var inventory: Dictionary = _player_gathering.player_inventory if _player_gathering.has("player_inventory") else {}
	return (inventory[resource] if inventory.has(resource) else 0) >= amount


func _format_resources(resources: Dictionary) -> String:
	var text: String = ""
	for resource in resources:
		var amount: int = resources[resource]
		var icon: String = _get_resource_icon(resource)
		var has_it: bool = _has_resource(resource, amount)
		var color: String = "#44FF44" if has_it else "#FF4444"
		text += "  [color=%s]%s %d[/color]\n" % [color, icon, amount]
	return text


func _get_resource_icon(resource: String) -> String:
	var icons: Dictionary = {
		"wood": "🪵",
		"stone": "🪨",
		"flint": "🔩",
		"stick": "🥢",
		"flint_knife": "🔪",
		"flint_pickaxe": "⛏️",
		"wooden_axe": "🪓",
		"wooden_spear": "🔱",
		"torch": "🔥",
		"basket": "🧺",
	}
	return icons.get(resource, "❓")


func _deduct_resources(resources: Dictionary) -> void:
	if _player_gathering == null:
		return

	for resource in resources:
		var amount: int = resources[resource]
		var inventory: Dictionary = _player_gathering.player_inventory if _player_gathering.has("player_inventory") else {}
		if inventory.has(resource):
			inventory[resource] = max(0, inventory[resource] - amount)


func _on_close_pressed() -> void:
	visible = false


func push_notification(message: String) -> void:
	# Simple notification via tooltip update
	_close_button.tooltip_text = message
	_close_button.tooltip_delay = 0.0


## Toggle menu visibility
func toggle_menu() -> void:
	visible = not visible
	if visible:
		_refresh_recipes()
