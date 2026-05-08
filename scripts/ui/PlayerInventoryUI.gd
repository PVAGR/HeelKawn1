extends PanelContainer
## PlayerInventoryUI - Player inventory display and management
##
## Shows:
## - All carried resources with icons
## - Stack quantities
## - Resource categories (food, materials, tools)
## - Quick actions (eat, craft, drop)

var _player_gathering: Node = null
var _player_building: Node = null

@onready var items_grid: GridContainer = $MarginContainer/VBoxContainer/ItemsGrid
@onready var action_buttons: VBoxContainer = $MarginContainer/VBoxContainer/ActionButtons

var _craft_button: Button = null
var _selected_item: String = ""
var _update_timer: float = 0.0


func _ready() -> void:
	_player_gathering = get_node_or_null("/root/PlayerGathering")
	_player_building = get_node_or_null("/root/PlayerBuilding")
	
	_setup_craft_button()
	# Hide by default
	visible = false


func _setup_craft_button() -> void:
	if action_buttons == null:
		return
	_craft_button = Button.new()
	_craft_button.text = "Open Crafting Menu"
	_craft_button.pressed.connect(_on_craft_button_pressed)
	action_buttons.add_child(_craft_button)


func _process(delta: float) -> void:
	_update_timer += delta
	
	# Update every 1 second
	if _update_timer >= 1.0:
		_update_timer = 0.0
		_refresh_inventory()


func _refresh_inventory() -> void:
	if _player_gathering == null:
		return
	
	# Clear existing items
	for child in items_grid.get_children():
		child.queue_free()
	
	# Get inventory
	var inventory: Dictionary = _player_gathering.get_inventory()
	
	# Add items to grid
	for resource in inventory:
		var quantity: int = inventory[resource]
		if quantity <= 0:
			continue
		
		var item_box: VBoxContainer = _create_item_box(resource, quantity)
		items_grid.add_child(item_box)


func _create_item_box(resource: String, quantity: int) -> VBoxContainer:
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	
	# Get resource info
	var icon: String = _get_resource_icon(resource)
	var name: String = _get_resource_name(resource)
	var category: String = _get_resource_category(resource)
	
	# Icon label
	var icon_label: Label = Label.new()
	icon_label.text = icon
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_label.add_theme_font_size_override("font_size", 24)
	box.add_child(icon_label)
	
	# Name label
	var name_label: Label = Label.new()
	name_label.text = name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 10)
	box.add_child(name_label)
	
	# Quantity label
	var qty_label: Label = Label.new()
	qty_label.text = "x" + str(quantity)
	qty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	qty_label.add_theme_font_size_override("font_size", 12)
	box.add_child(qty_label)
	
	# Category label (small)
	var cat_label: Label = Label.new()
	cat_label.text = category
	cat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cat_label.add_theme_color_override("font_color", Color.GRAY)
	cat_label.add_theme_font_size_override("font_size", 8)
	box.add_child(cat_label)
	
	return box


func _get_resource_icon(resource: String) -> String:
	var icons: Dictionary = {
		"wood": "🪵",
		"stone": "🪨",
		"berries": "🫐",
		"flint": "🔩",
		"stick": "🥢",
		"iron_ore": "⛏️",
		"copper_ore": "🟠",
		"meat_raw": "🥩",
		"hide": "🟫",
		"flint_knife": "🔪",
		"flint_pickaxe": "⛏️",
		"wooden_axe": "🪓",
		"torch": "🔥"
	}
	return icons.get(resource, "❓")


func _get_resource_name(resource: String) -> String:
	var names: Dictionary = {
		"wood": "Wood",
		"stone": "Stone",
		"berries": "Berries",
		"flint": "Flint",
		"stick": "Stick",
		"iron_ore": "Iron Ore",
		"copper_ore": "Copper Ore",
		"meat_raw": "Raw Meat",
		"hide": "Hide",
		"flint_knife": "Flint Knife",
		"flint_pickaxe": "Flint Pick",
		"wooden_axe": "Wood Axe",
		"torch": "Torch"
	}
	return names.get(resource, resource)


func _get_resource_category(resource: String) -> String:
	if _player_gathering == null:
		return "unknown"
	
	var types: Dictionary = _player_gathering.RESOURCE_TYPES
	if types.has(resource):
		return types[resource].get("category", "material")
	
	return "material"


## Show inventory
func show_inventory() -> void:
	visible = true
	_refresh_inventory()


## Hide inventory
func hide_inventory() -> void:
	visible = false


## Toggle inventory
func toggle_inventory() -> void:
	visible = not visible
	if visible:
		_refresh_inventory()


func _on_craft_button_pressed() -> void:
	if _player_gathering == null:
		return
	
	# Open crafting menu using the current inventory
	var inventory: Dictionary = _player_gathering.get_inventory()
	_open_crafting_dialog(inventory)


func _open_crafting_dialog(inventory: Dictionary) -> void:
	if CraftingSystem == null:
		return
	
	var available_recipes: Array[Dictionary] = CraftingSystem.get_available_recipes(inventory)
	
	# In a real implementation, this would open a new Sub-Menu.
	# For now, we'll log it and pick the first one as a proof-of-concept.
	print("[PlayerInventory] Available recipes: ", available_recipes.size())
	for recipe in available_recipes:
		print(" - ", recipe.name)
