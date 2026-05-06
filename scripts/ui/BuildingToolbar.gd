extends CanvasLayer
## BuildingToolbar.gd — Player building placement UI
##
## Shows 9 building types with resource requirements.
## Player clicks button, then clicks map to place.
## Resources auto-deducted from player inventory.

const BUILDING_CONFIG: Dictionary = {
	"foundation": {
		"name": "Foundation",
		"icon": "🪨",
		"resources": {"stone": 5},
		"description": "Basic foundation for structures"
	},
	"wall_wood": {
		"name": "Wood Wall",
		"icon": "🪵",
		"resources": {"wood": 3},
		"description": "Wooden wall section"
	},
	"wall_stone": {
		"name": "Stone Wall",
		"icon": "🪨",
		"resources": {"stone": 5},
		"description": "Stone wall section (more durable)"
	},
	"door_wood": {
		"name": "Wood Door",
		"icon": "🚪",
		"resources": {"wood": 2},
		"description": "Wooden door (requires wall)"
	},
	"roof_wood": {
		"name": "Wood Roof",
		"icon": "🏠",
		"resources": {"wood": 4, "stick": 2},
		"description": "Wooden roof (requires walls)"
	},
	"shelter": {
		"name": "Shelter",
		"icon": "⛺",
		"resources": {"wood": 10, "stone": 5},
		"description": "Basic shelter (sleep, storage)"
	},
	"storage_hut": {
		"name": "Storage Hut",
		"icon": "📦",
		"resources": {"wood": 15, "stone": 10},
		"description": "Dedicated storage building"
	},
	"fire_pit": {
		"name": "Fire Pit",
		"icon": "🔥",
		"resources": {"stone": 8, "wood": 3},
		"description": "Cooking, warmth, light"
	},
	"workshop": {
		"name": "Workshop",
		"icon": "🛠️",
		"resources": {"wood": 20, "stone": 15, "flint": 5},
		"description": "Crafting station (tools, weapons)"
	},
}

var _player_gathering: Node = null
var _player_building: Node = null
var _selected_building_type: String = ""
var _is_placing: bool = false

@onready var _tooltip: Label = $Tooltip
@onready var _panel: PanelContainer = $Panel

# Button references
var _buttons: Dictionary = {}


func _ready() -> void:
	_player_gathering = get_node_or_null("/root/PlayerGathering")
	_player_building = get_node_or_null("/root/PlayerBuilding")
	
	# Connect buttons
	_buttons["foundation"] = $Panel/MarginContainer/HBoxContainer/FoundationBtn
	_buttons["wall_wood"] = $Panel/MarginContainer/HBoxContainer/WallWoodBtn
	_buttons["wall_stone"] = $Panel/MarginContainer/HBoxContainer/WallStoneBtn
	_buttons["door_wood"] = $Panel/MarginContainer/HBoxContainer/DoorBtn
	_buttons["roof_wood"] = $Panel/MarginContainer/HBoxContainer/RoofBtn
	_buttons["shelter"] = $Panel/MarginContainer/HBoxContainer/ShelterBtn
	_buttons["storage_hut"] = $Panel/MarginContainer/HBoxContainer/StorageBtn
	_buttons["fire_pit"] = $Panel/MarginContainer/HBoxContainer/FirePitBtn
	_buttons["workshop"] = $Panel/MarginContainer/HBoxContainer/WorkshopBtn
	
	var close_btn: Button = $Panel/MarginContainer/HBoxContainer/CloseBtn
	close_btn.pressed.connect(_on_close_pressed)
	
	# Connect building buttons
	for building_type in _buttons:
		var btn: Button = _buttons[building_type]
		btn.pressed.connect(_on_building_selected.bind(building_type))
		btn.mouse_entered.connect(_on_building_hovered.bind(building_type))
	
	# Hide by default
	visible = false


func _input(event: InputEvent) -> void:
	if not visible:
		return
	
	# Toggle with B key
	if event is InputEventKey and event.pressed and event.keycode == KEY_B:
		visible = not visible
		_is_placing = false
		_selected_building_type = ""
		_update_tooltip()


## Show/hide toolbar
func toggle_toolbar() -> void:
	visible = not visible
	if visible:
		_update_all_buttons()


## Select a building type
func _on_building_selected(building_type: String) -> void:
	_selected_building_type = building_type
	_is_placing = true
	
	var config: Dictionary = BUILDING_CONFIG[building_type]
	_update_tooltip()
	
	# Highlight selected button
	for btn_type in _buttons:
		var btn: Button = _buttons[btn_type]
		if btn_type == building_type:
			btn.pressed = true
		else:
			btn.pressed = false


## Show tooltip with building info
func _on_building_hovered(building_type: String) -> void:
	var config: Dictionary = BUILDING_CONFIG[building_type]
	var resources: String = _format_resources(config.resources)
	_tooltip.text = "[b]%s[/b]\n%s\n\n[color=#FFD166]Requires:[/color]\n%s" % [
		config.name,
		config.description,
		resources
	]


func _update_tooltip() -> void:
	if _selected_building_type == "":
		_tooltip.text = "Select a building type, then click on the map to place."
		return
	
	var config: Dictionary = BUILDING_CONFIG[_selected_building_type]
	var resources: String = _format_resources(config.resources)
	
	# Check if player has resources
	var has_resources: bool = _check_resources(config.resources)
	var color: String = "#44FF44" if has_resources else "#FF4444"
	var status: String = "Ready to place" if has_resources else "Missing resources!"
	
	_tooltip.text = "[b]Placing: %s[/b]\n%s\n\n[color=%s]Requires:[/color]\n%s\n\n[color=%s]%s[/color]" % [
		config.name,
		config.description,
		color,
		resources,
		color,
		status
	]


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
	}
	return icons.get(resource, "❓")


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


func _update_all_buttons() -> void:
	for building_type in _buttons:
		var btn: Button = _buttons[building_type]
		var config: Dictionary = BUILDING_CONFIG[building_type]
		var can_afford: bool = _check_resources(config.resources)
		btn.disabled = not can_afford
		btn.modulate = Color(1, 1, 1, 1.0 if can_afford else 0.5)


func _on_close_pressed() -> void:
	visible = false
	_is_placing = false
	_selected_building_type = ""


## Try to place building at tile
func try_place_building(tile: Vector2i) -> bool:
	if not _is_placing or _selected_building_type == "":
		return false
	
	if _player_building == null:
		return false
	
	var config: Dictionary = BUILDING_CONFIG[_selected_building_type]
	
	# Check resources
	if not _check_resources(config.resources):
		_tooltip.text = "[color=#FF4444]Missing resources![/color]"
		return false
	
	# Call PlayerBuilding to place
	var result: Dictionary = {}
	if _player_building.has_method("place_" + _selected_building_type):
		result = _player_building.call("place_" + _selected_building_type, tile)
	else:
		# Generic placement
		result = _player_building._start_building(tile, _selected_building_type)
	
	if result.get("success", false):
		# Deduct resources
		_deduct_resources(config.resources)
		_tooltip.text = "[color=#44FF44]Building placed![/color]"
		_is_placing = false
		_selected_building_type = ""
		_update_all_buttons()
		return true
	else:
		var error: String = result.get("message", "Unknown error")
		_tooltip.text = "[color=#FF4444]Failed: %s[/color]" % error
		return false


func _deduct_resources(resources: Dictionary) -> void:
	if _player_gathering == null:
		return
	
	for resource in resources:
		var amount: int = resources[resource]
		var inventory: Dictionary = _player_gathering.get("player_inventory", {})
		if inventory.has(resource):
			inventory[resource] = max(0, inventory[resource] - amount)
