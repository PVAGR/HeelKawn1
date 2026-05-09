extends Node
## UILayoutManager - Manages UI panel positions, sizes, and visibility modes
##
## Provides three UI modes:
## - CLEAN_PLAYTEST: Minimal HUD, no debug overlays, maximum world visibility
## - DEBUG: Full debug info, all panels visible
## - MINIMAL_SCREENSHOT: Only essential HUD, no text overlays
##
## Ensures panels don't overlap by enforcing safe screen zones

const UI_MODES: Dictionary = {
	"CLEAN_PLAYTEST": 0,
	"DEBUG": 1,
	"MINIMAL_SCREENSHOT": 2
}

var current_ui_mode: int = UI_MODES.CLEAN_PLAYTEST

# Safe screen zones (percentages of screen)
# Top-left: Watch panel (compact)
# Top-right: Chronicle (small)
# Bottom: Toolbar + minimap
# Left: HeelKawnian sheet (only when pawn selected)
# Center: World view (untouched)

# Zone definitions
var ZONE_WATCH: Dictionary = {
	"anchor": Vector2(0, 0),  # Top-left
	"max_size": Vector2(380, 220),  # Compact size
	"margin": Vector2(10, 10)
}

var ZONE_CHRONICLE: Dictionary = {
	"anchor": Vector2(1, 0),  # Top-right
	"max_size": Vector2(320, 280),  # Taller, narrower
	"margin": Vector2(10, 10)
}

var ZONE_PAWN_SHEET: Dictionary = {
	"anchor": Vector2(0, 0),  # Left side
	"max_size": Vector2(350, 600),  # Tall panel
	"margin": Vector2(10, 240),  # Below watch panel
	"visible_only_when": "pawn_selected"
}

var ZONE_BOTTOM_BAR: Dictionary = {
	"anchor": Vector2(0, 1),  # Bottom
	"max_size": Vector2(1920, 120),  # Full width
	"margin": Vector2(10, 10)
}

var ZONE_MINIMAP: Dictionary = {
	"anchor": Vector2(1, 1),  # Bottom-right
	"max_size": Vector2(200, 200),
	"margin": Vector2(10, 10)
}

var ZONE_TOOLTIPS: Dictionary = {
	"follow_cursor": true,
	"max_size": Vector2(400, 150),
	"margin": Vector2(20, 20)  # Offset from cursor
}


func _ready() -> void:
	# Apply UI mode on startup
	apply_ui_mode(current_ui_mode)


## Set UI mode and reposition all panels
func apply_ui_mode(mode: int) -> void:
	current_ui_mode = mode
	
	match mode:
		UI_MODES.CLEAN_PLAYTEST:
			_configure_clean_playtest()
		UI_MODES.DEBUG:
			_configure_debug()
		UI_MODES.MINIMAL_SCREENSHOT:
			_configure_minimal()
	
	# Notify all UI panels to reposition
	_reposition_all_panels()


func _configure_clean_playtest() -> void:
	# Minimal HUD for playtesting
	# Show only: Watch (compact), Chronicle (small), Bottom bar, Minimap
	# Hide: Debug overlays, AI panels, backbone text
	
	var watch: Node = _get_node_safe("/root/Main/UI_Viewport/ColonyHUD")
	if watch:
		watch.visible = true
		_set_panel_size(watch, ZONE_WATCH.max_size)
	
	var chronicle: Node = _get_node_safe("/root/Main/UI_Viewport/ChronicleFeed")
	if chronicle:
		chronicle.visible = true
		_set_panel_size(chronicle, ZONE_CHRONICLE.max_size)
	
	var bottom: Node = _get_node_safe("/root/Main/UI_Viewport/BuildingToolbar")
	if bottom:
		bottom.visible = true
	
	var minimap: Node = _get_node_safe("/root/Main/UI_Viewport/Minimap")
	if minimap:
		minimap.visible = true
		_set_panel_size(minimap, ZONE_MINIMAP.max_size)
	
	# Hide debug panels
	_hide_debug_panels()


func _configure_debug() -> void:
	# Full debug mode - all panels visible
	var watch: Node = _get_node_safe("/root/Main/UI_Viewport/ColonyHUD")
	if watch:
		watch.visible = true
		# Larger size for debug info
		watch.custom_minimum_size = Vector2(500, 400)
	
	var chronicle: Node = _get_node_safe("/root/Main/UI_Viewport/ChronicleFeed")
	if chronicle:
		chronicle.visible = true
		chronicle.custom_minimum_size = Vector2(400, 400)
	
	# Show debug panels
	_show_debug_panels()


func _configure_minimal() -> void:
	# Screenshot mode - only world view
	_hide_all_panels_temporarily()


func _reposition_all_panels() -> void:
	# Reposition panels to their safe zones
	_position_panel("/root/Main/UI_Viewport/ColonyHUD", ZONE_WATCH)
	_position_panel("/root/Main/UI_Viewport/ChronicleFeed", ZONE_CHRONICLE)
	_position_panel("/root/Main/UI_Viewport/BuildingToolbar", ZONE_BOTTOM_BAR)
	_position_panel("/root/Main/UI_Viewport/Minimap", ZONE_MINIMAP)
	
	# HeelKawnian sheet only visible when pawn selected
	var pawn_sheet: Node = _get_node_safe("/root/Main/UI_Viewport/PawnInfoPanel")
	if pawn_sheet:
		var main: Node = _get_node_safe("/root/Main")
		if main != null and main.has_method("_get_selected_pawn"):
			var selected: Node = main.call("_get_selected_pawn")
			pawn_sheet.visible = (selected != null)
			if selected != null:
				_position_panel("/root/Main/UI_Viewport/PawnInfoPanel", ZONE_PAWN_SHEET)


func _position_panel(panel_path: String, zone: Dictionary) -> void:
	var panel: Node = _get_node_safe(panel_path)
	if panel == null or not (panel is Control):
		return
	
	var control: Control = panel as Control
	
	# Set anchors based on zone
	match zone.anchor:
		Vector2(0, 0):  # Top-left
			control.set_anchors_preset(Control.PRESET_TOP_LEFT)
			control.offset_left = zone.margin.x
			control.offset_top = zone.margin.y
		Vector2(1, 0):  # Top-right
			control.set_anchors_preset(Control.PRESET_TOP_RIGHT)
			control.offset_right = -zone.margin.x
			control.offset_top = zone.margin.y
		Vector2(0, 1):  # Bottom-left
			control.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
			control.offset_left = zone.margin.x
			control.offset_bottom = -zone.margin.y
		Vector2(1, 1):  # Bottom-right
			control.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
			control.offset_right = -zone.margin.x
			control.offset_bottom = -zone.margin.y
	
	# Apply max size if specified
	if zone.has("max_size"):
		var max_size: Vector2 = zone.max_size
		if control.custom_minimum_size.x > max_size.x:
			control.custom_minimum_size.x = max_size.x
		if control.custom_minimum_size.y > max_size.y:
			control.custom_minimum_size.y = max_size.y


func _hide_debug_panels() -> void:
	# Hide F10 debug menu (only accessible via F10 key)
	var debug_menu: Node = _get_node_safe("/root/Main/UI_Viewport/CreatorDebugMenu")
	if debug_menu:
		debug_menu.visible = false
	
	# Hide AI control panel
	var ai_panel: Node = _get_node_safe("/root/Main/UI_Viewport/AIControlPanel")
	if ai_panel:
		ai_panel.visible = false
	
	# Hide backbone/debug text overlays
	var backbone: Node = _get_node_safe("/root/Main/UI_Viewport/ObserverLensPanel")
	if backbone:
		backbone.visible = false


func _show_debug_panels() -> void:
	# Show all debug panels
	var debug_menu: Node = _get_node_safe("/root/Main/UI_Viewport/CreatorDebugMenu")
	if debug_menu:
		debug_menu.visible = true


func _hide_all_panels_temporarily() -> void:
	# Hide all UI for clean screenshots
	var viewports: Node = _get_node_safe("/root/Main/UI_Viewport")
	if viewports:
		for child in viewports.get_children():
			if child is Control:
				child.visible = false


func _get_node_safe(path: String) -> Node:
	var node: Node = get_node_or_null(path)
	if node == null:
		node = get_node_or_null("/root/" + path.trim_prefix("/root/"))
	return node


func _set_panel_size(panel: Node, size: Vector2) -> void:
	if panel is Control:
		var control: Control = panel as Control
		control.custom_minimum_size = size


## Toggle UI mode (called by F9 key)
func toggle_ui_mode() -> void:
	current_ui_mode = (current_ui_mode + 1) % 3
	apply_ui_mode(current_ui_mode)
	
	var mode_name: String = "CLEAN_PLAYTEST"
	if current_ui_mode == UI_MODES.DEBUG:
		mode_name = "DEBUG"
	elif current_ui_mode == UI_MODES.MINIMAL_SCREENSHOT:
		mode_name = "MINIMAL"
	
	print("[UILayoutManager] UI mode: %s" % mode_name)


## Get current UI mode name
func get_mode_name() -> String:
	match current_ui_mode:
		UI_MODES.CLEAN_PLAYTEST:
			return "CLEAN_PLAYTEST"
		UI_MODES.DEBUG:
			return "DEBUG"
		UI_MODES.MINIMAL_SCREENSHOT:
			return "MINIMAL"
	return "UNKNOWN"
