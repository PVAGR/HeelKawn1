extends PanelContainer
## ActionMenu - Context menu for player actions (gather, build, craft)
##
## Right-click on tile to show available actions:
## - Gather (if resource present)
## - Build (if valid location)
## - Cancel

var _world: Node = null
var _player_gathering: Node = null
var _player_building: Node = null
var _target_tile: Vector2i = Vector2i.ZERO

@onready var action_list: VBoxContainer = $MarginContainer/VBoxContainer/ActionList

var _update_timer: float = 0.0


func _ready() -> void:
	_world = get_node_or_null("/root/Main/World")
	_player_gathering = get_node_or_null("/root/PlayerGathering")
	_player_building = get_node_or_null("/root/PlayerBuilding")
	
	# Hide by default
	visible = false
	
	# Connect to input
	get_viewport().gui_input.connect(_on_gui_input)


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			# Right-click to show menu at mouse position
			var mouse_pos: Vector2 = get_global_mouse_position()
			var tile: Vector2i = _screen_to_tile(mouse_pos)
			
			if tile != _target_tile:
				_target_tile = tile
				_show_action_menu(tile)


func _screen_to_tile(screen_pos: Vector2) -> Vector2i:
	# Convert screen position to world tile
	# TODO: Implement proper screen-to-world conversion
	# For now, return placeholder
	return Vector2i(int(screen_pos.x / 16), int(screen_pos.y / 16))


func _show_action_menu(tile: Vector2i) -> void:
	# Clear existing actions
	for child in action_list.get_children():
		child.queue_free()
	
	# Get available actions
	var actions: Array[Dictionary] = _get_available_actions(tile)
	
	if actions.size() == 0:
		visible = false
		return
	
	# Add action buttons
	for action in actions:
		var button: Button = Button.new()
		button.text = action.icon + " " + action.name
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_on_action_pressed.bind(action))
		action_list.add_child(button)
	
	# Position menu
	position = get_global_mouse_position()
	visible = true


func _get_available_actions(tile: Vector2i) -> Array[Dictionary]:
	var actions: Array[Dictionary] = []
	
	if _world == null or _world.data == null:
		return actions
	
	if not _world.data.in_bounds(tile.x, tile.y):
		return actions
	
	# Check for gatherable resources
	var feature: int = _world.data.get_feature(tile.x, tile.y)
	
	match feature:
		2:  # Tree
			actions.append({
				"name": "Gather Wood",
				"icon": "🪵",
				"type": "gather",
				"resource": "tree",
				"tile": tile
			})
		3, 4:  # Rock/Boulder
			actions.append({
				"name": "Gather Stone",
				"icon": "🪨",
				"type": "gather",
				"resource": "rock",
				"tile": tile
			})
		6:  # Bush
			actions.append({
				"name": "Gather Berries",
				"icon": "🫐",
				"type": "gather",
				"resource": "bush",
				"tile": tile
			})
	
	# Check for buildable structures
	if _player_building != null:
		var hint: String = _player_building.get_building_hint(tile)
		if "Empty ground" in hint:
			# Add build options
			actions.append({
				"name": "Build Foundation",
				"icon": "🏗️",
				"type": "build",
				"structure": "foundation",
				"tile": tile
			})
			actions.append({
				"name": "Build Fire Pit",
				"icon": "🔥",
				"type": "build",
				"structure": "fire_pit",
				"tile": tile
			})
	
	# Add cancel option
	actions.append({
		"name": "Cancel",
		"icon": "❌",
		"type": "cancel",
		"tile": tile
	})
	
	return actions


func _on_action_pressed(action: Dictionary) -> void:
	match action.type:
		"gather":
			_perform_gather(action.resource, action.tile)
		"build":
			_perform_build(action.structure, action.tile)
		"cancel":
			pass
	
	visible = false


func _perform_gather(resource_type: String, tile: Vector2i) -> void:
	if _player_gathering == null:
		return
	
	var result: Dictionary = {}
	
	match resource_type:
		"tree":
			result = _player_gathering.gather_tree(tile)
		"rock":
			result = _player_gathering.gather_rock(tile)
		"bush":
			result = _player_gathering.gather_bush(tile)
	
	# Show result
	if result.success:
		_show_notification("✅ " + result.message)
	else:
		_show_notification("❌ " + result.message)


func _perform_build(structure_type: String, tile: Vector2i) -> void:
	if _player_building == null:
		return
	
	var result: Dictionary = {}
	
	match structure_type:
		"foundation":
			result = _player_building.place_foundation(tile)
		"fire_pit":
			result = _player_building.build_fire_pit(tile)
	
	# Show result
	if result.success:
		_show_notification("✅ " + result.message)
	else:
		_show_notification("❌ " + result.message)


func _show_notification(message: String) -> void:
	# TODO: Implement notification system
	print(message)


## Hide action menu
func hide_menu() -> void:
	visible = false
