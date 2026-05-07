extends Node
## PlaytestInputRecorder — Records ALL player input during playtest sessions
##
## Captures:
## - Mouse clicks (position, button, target UI element)
## - Key presses (keycode, modifiers, target)
## - Camera movement (pan, zoom, rotation)
## - UI interactions (button clicks, slider changes, selections)
## - Pawn selections
## - Building placements
## - Command mode actions

const MAX_INPUT_RECORDS: int = 50000

var input_records: Array[Dictionary] = []
var _record_count: int = 0
var _mouse_position: Vector2 = Vector2.ZERO
var _camera_position: Vector2 = Vector2.ZERO
var _camera_zoom: float = 1.0


func _ready() -> void:
	# Connect to input events
	set_process_unhandled_input(true)
	
	# Connect to camera for position tracking
	var camera: Node = get_node_or_null("/root/Main/Camera2D")
	if camera != null:
		_camera_position = camera.position
		_camera_zoom = camera.zoom.x


func _unhandled_input(event: InputEvent) -> void:
	var playtest_recorder: Node = get_node_or_null("/root/PlaytestRecorder")
	if playtest_recorder == null or not playtest_recorder.is_recording:
		return
	
	# Record mouse button presses
	if event is InputEventMouseButton:
		_record_mouse_button(event)
	
	# Record key presses
	if event is InputEventKey and event.pressed:
		_record_key_press(event)
	
	# Record mouse motion
	if event is InputEventMouseMotion:
		_mouse_position = event.position


func _record_mouse_button(event: InputEventMouseButton) -> void:
	if _record_count >= MAX_INPUT_RECORDS:
		return
	
	var target_ui: String = _get_ui_element_at_position(event.position)
	var world_tile: Vector2i = _screen_to_tile(event.position)
	
	var record: Dictionary = {
		"tick": GameManager.tick_count if GameManager != null else 0,
		"timestamp": Time.get_ticks_msec(),
		"input_type": "mouse_button",
		"button_index": event.button_index,
		"pressed": event.pressed,
		"position": {"x": event.position.x, "y": event.position.y},
		"world_tile": {"x": world_tile.x, "y": world_tile.y},
		"target_ui": target_ui,
		"modifiers": {
			"shift": event.shift_pressed,
			"ctrl": event.ctrl_pressed,
			"alt": event.alt_pressed
		}
	}
	
	input_records.append(record)
	_record_count += 1
	
	# Notify PlaytestRecorder
	var playtest_recorder: Node = get_node_or_null("/root/PlaytestRecorder")
	if playtest_recorder != null and playtest_recorder.has_method("log_player_action"):
		playtest_recorder.log_player_action("mouse_button", record)


func _record_key_press(event: InputEventKey) -> void:
	if _record_count >= MAX_INPUT_RECORDS:
		return
	
	var record: Dictionary = {
		"tick": GameManager.tick_count if GameManager != null else 0,
		"timestamp": Time.get_ticks_msec(),
		"input_type": "key_press",
		"keycode": event.keycode,
		"key_label": event.key_label,
		"unicode": event.unicode,
		"modifiers": {
			"shift": event.shift_pressed,
			"ctrl": event.ctrl_pressed,
			"alt": event.alt_pressed
		}
	}
	
	input_records.append(record)
	_record_count += 1
	
	# Notify PlaytestRecorder
	var playtest_recorder: Node = get_node_or_null("/root/PlaytestRecorder")
	if playtest_recorder != null and playtest_recorder.has_method("log_player_action"):
		playtest_recorder.log_player_action("key_press", record)


func _get_ui_element_at_position(pos: Vector2) -> String:
	# Check common UI elements
	var ui_elements: Array = [
		{"name": "SurvivalHUD", "path": "/root/Main/UI_Viewport/SurvivalHUD"},
		{"name": "PlayerInventory", "path": "/root/Main/UI_Viewport/PlayerInventory"},
		{"name": "BuildingToolbar", "path": "/root/Main/UI_Viewport/BuildingToolbar"},
		{"name": "CraftingMenu", "path": "/root/Main/UI_Viewport/CraftingMenu"},
		{"name": "KnowledgePanel", "path": "/root/Main/UI_Viewport/KnowledgePanel"},
		{"name": "PawnInfoPanel", "path": "/root/Main/UI_Viewport/PawnInfoPanel"},
		{"name": "ColonyHUD", "path": "/root/Main/UI_Viewport/ColonyHUD"},
		{"name": "F10_DebugMenu", "path": "/root/Main/UI_Viewport/CreatorDebugMenu"}
	]
	
	for ui in ui_elements:
		var node: Node = get_node_or_null(ui.path)
		if node != null and node is Control:
			var control: Control = node as Control
			if control.visible and control.get_global_rect().has_point(pos):
				return ui.name
	
	return "game_world"


func _screen_to_tile(screen_pos: Vector2) -> Vector2i:
	var world: Node = get_node_or_null("/root/Main/WorldViewport/World")
	if world == null or not world.has_method("world_to_tile"):
		return Vector2i.ZERO
	
	# Get camera
	var camera: Camera2D = get_node_or_null("/root/Main/Camera2D")
	if camera == null:
		return Vector2i.ZERO
	
	# Convert screen position to world position
	var world_pos: Vector2 = camera.get_global_transform().xform_inv(screen_pos)
	
	# Convert to tile
	return world.world_to_tile(world_pos) if world.has_method("world_to_tile") else Vector2i.ZERO


func record_camera_movement(camera_pos: Vector2, camera_zoom: float) -> void:
	if _camera_position == camera_pos and abs(_camera_zoom - camera_zoom) < 0.01:
		return  # No significant movement
	
	_camera_position = camera_pos
	_camera_zoom = camera_zoom
	
	var playtest_recorder: Node = get_node_or_null("/root/PlaytestRecorder")
	if playtest_recorder != null and playtest_recorder.has_method("log_player_action"):
		playtest_recorder.log_player_action("camera_movement", {
			"position": {"x": camera_pos.x, "y": camera_pos.y},
			"zoom": camera_zoom,
			"tick": GameManager.tick_count if GameManager != null else 0
		})


func record_pawn_selection(pawn_id: int, pawn_name: String, tile: Vector2i) -> void:
	var playtest_recorder: Node = get_node_or_null("/root/PlaytestRecorder")
	if playtest_recorder == null:
		return
	
	playtest_recorder.log_player_action("pawn_selection", {
		"pawn_id": pawn_id,
		"pawn_name": pawn_name,
		"tile": {"x": tile.x, "y": tile.y},
		"tick": GameManager.tick_count if GameManager != null else 0
	})


func record_building_placement(building_type: String, tile: Vector2i, resources_spent: Dictionary) -> void:
	var playtest_recorder: Node = get_node_or_null("/root/PlaytestRecorder")
	if playtest_recorder == null:
		return
	
	playtest_recorder.log_player_action("building_placement", {
		"building_type": building_type,
		"tile": {"x": tile.x, "y": tile.y},
		"resources_spent": resources_spent,
		"tick": GameManager.tick_count if GameManager != null else 0
	})


func record_command_mode_action(action_type: String, target_tile: Vector2i, data: Dictionary) -> void:
	var playtest_recorder: Node = get_node_or_null("/root/PlaytestRecorder")
	if playtest_recorder == null:
		return
	
	playtest_recorder.log_player_action("command_mode", {
		"action_type": action_type,
		"target_tile": {"x": target_tile.x, "y": target_tile.y},
		"data": data,
		"tick": GameManager.tick_count if GameManager != null else 0
	})


func get_input_summary() -> Dictionary:
	var mouse_clicks: int = 0
	var key_presses: int = 0
	
	for record in input_records:
		if record.input_type == "mouse_button":
			mouse_clicks += 1
		elif record.input_type == "key_press":
			key_presses += 1
	
	return {
		"total_inputs": _record_count,
		"mouse_clicks": mouse_clicks,
		"key_presses": key_presses,
		"avg_inputs_per_minute": float(_record_count) / maxf(1.0, float(Time.get_ticks_msec()) / 60000.0)
	}
