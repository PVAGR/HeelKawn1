extends CanvasLayer
## HeelKawnUIManager - Centralized UI layout, layering, and visibility management
##
## Provides:
## - Proper CanvasLayer hierarchy (HUD, Debug, Modals)
## - Container-based layout (no overlapping panels)
## - Consolidated WorldMemory/Chronicle log
## - Compact, collapsible inspector panels
## - Debug overlay toggle (F12)
##
## Layer Structure:
## - Layer 0: Game World
## - Layer 10: Main HUD (Chronicle, Inspector, Toolbar)
## - Layer 20: Modals/Popups
## - Layer 30: Debug Overlay (F12 toggle)

# UI Modes
enum UIMode { CLEAN, DEBUG, MINIMAL }
var current_mode: UIMode = UIMode.CLEAN

# Panel references
var chronicle_panel: Control
var inspector_panel: Control
var debug_overlay: Control
var modal_layer: Control

# Consolidated log
var world_memory_log: RichTextLabel


func _ready() -> void:
	layer = 10  # Main HUD layer
	_setup_ui_hierarchy()
	_apply_theme()
	_connect_signals()


func _setup_ui_hierarchy() -> void:
	# Get viewport
	var viewport: Node = get_node_or_null("/root/Main")
	if viewport == null:
		return
	
	# Find existing UI panels
	chronicle_panel = _find_node_by_type(viewport, "ChronicleFeed")
	inspector_panel = _find_node_by_type(viewport, "ColonyHUD")
	debug_overlay = _find_node_by_type(viewport, "CreatorDebugMenu")
	
	# Create consolidated WorldMemory log if it doesn't exist
	_create_world_memory_log()
	
	# Reposition all panels
	_reposition_panels()


func _find_node_by_type(parent: Node, type_name: String) -> Control:
	for child in parent.get_children():
		if child is Control:
			if child.name.contains(type_name):
				return child as Control
			var found: Control = _find_node_by_type(child, type_name)
			if found != null:
				return found
	return null


func _create_world_memory_log() -> void:
	# Create consolidated log container
	var log_container: PanelContainer = PanelContainer.new()
	log_container.name = "WorldMemoryLog"
	log_container.custom_minimum_size = Vector2(350, 300)
	
	# Style
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.03, 0.05, 0.85)
	style.border_color = Color(0.85, 0.78, 0.40, 0.5)
	style.border_width_left = 2
	style.set_corner_radius_all(4)
	log_container.add_theme_stylebox_override("panel", style)
	
	# RichTextLabel for log
	world_memory_log = RichTextLabel.new()
	world_memory_log.name = "LogText"
	world_memory_log.scroll_active = true
	world_memory_log.bbcode_enabled = true
	world_memory_log.add_theme_font_size_override("normal_font_size", 11)
	world_memory_log.add_theme_color_override("default_color", Color(0.85, 0.82, 0.75, 0.95))
	log_container.add_child(world_memory_log)
	
	# Add to right side
	add_child(log_container)
	chronicle_panel = log_container


func _reposition_panels() -> void:
	if chronicle_panel:
		# Top-right: WorldMemory/Chronicle
		chronicle_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		chronicle_panel.offset_left = -370
		chronicle_panel.offset_top = 10
		chronicle_panel.offset_right = -10
		chronicle_panel.offset_bottom = 320
	
	if inspector_panel:
		# Bottom-left: Inspector (compact)
		inspector_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
		inspector_panel.offset_left = 10
		inspector_panel.offset_top = -180
		inspector_panel.offset_right = 380
		inspector_panel.offset_bottom = -10


func _apply_theme() -> void:
	# Apply consistent theme to all panels
	var panels: Array = [chronicle_panel, inspector_panel]
	for panel in panels:
		if panel == null:
			continue
		
		# Ensure proper background opacity
		if panel is PanelContainer:
			var style: StyleBoxFlat = panel.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
			if style != null:
				style.bg_color.a = 0.85
				panel.add_theme_stylebox_override("panel", style)


func _connect_signals() -> void:
	# Listen for WorldMemory events to update log
	var world_memory: Node = get_node_or_null("/root/WorldMemory")
	if world_memory != null and world_memory.has_signal("event_appended"):
		world_memory.event_appended.connect(_on_world_memory_event)


func _on_world_memory_event(event: Dictionary) -> void:
	if world_memory_log == null:
		return
	
	# Consolidate all events into single log
	var event_text: String = _format_event_for_log(event)
	world_memory_log.append_text(event_text + "\n")
	
	# Auto-scroll to bottom
	world_memory_log.scroll_to_line(world_memory_log.get_line_count() - 1)


func _format_event_for_log(event: Dictionary) -> String:
	var tick: int = int(event.get("tick", 0))
	var day: int = tick / 600
	var event_type: String = str(event.get("type", "unknown"))
	
	match event_type:
		"pawn_death":
			var name: String = str(event.get("pawn_name", "Unknown"))
			var cause: String = str(event.get("cause", "unknown"))
			return "[color=#FF6B6B][b]Day %d:[/b] %s died (%s)[/color]" % [day, name, cause]
		"pawn_birth":
			var name: String = str(event.get("pawn_name", "Unknown"))
			return "[color=#6BFF8E][b]Day %d:[/b] %s born[/color]" % [day, name]
		"settlement_founded":
			var name: String = str(event.get("settlement_name", "Unnamed"))
			return "[color=#6BB3FF][b]Day %d:[/b] Settlement founded: %s[/color]" % [day, name]
		"innovation":
			var result: String = str(event.get("result_name", "something"))
			return "[color=#FFD966][b]Day %d:[/b] Discovered: %s[/color]" % [day, result]
		_:
			return "[color=#AAAAAA][b]Day %d:[/b] %s[/color]" % [day, event_type]


## Toggle debug overlay (F12)
func toggle_debug_overlay() -> void:
	if debug_overlay:
		debug_overlay.visible = not debug_overlay.visible
		current_mode = UIMode.DEBUG if debug_overlay.visible else UIMode.CLEAN
		print("[UIManager] Debug overlay: %s" % ("ON" if debug_overlay.visible else "OFF"))


## Set UI mode
func set_ui_mode(mode: UIMode) -> void:
	current_mode = mode
	
	match mode:
		UIMode.CLEAN:
			_show_clean_ui()
		UIMode.DEBUG:
			_show_debug_ui()
		UIMode.MINIMAL:
			_show_minimal_ui()


func _show_clean_ui() -> void:
	# Show only essential HUD
	if chronicle_panel:
		chronicle_panel.visible = true
	if inspector_panel:
		inspector_panel.visible = true
	if debug_overlay:
		debug_overlay.visible = false


func _show_debug_ui() -> void:
	# Show all panels including debug
	if chronicle_panel:
		chronicle_panel.visible = true
	if inspector_panel:
		inspector_panel.visible = true
	if debug_overlay:
		debug_overlay.visible = true


func _show_minimal_ui() -> void:
	# Hide all UI for screenshots
	if chronicle_panel:
		chronicle_panel.visible = false
	if inspector_panel:
		inspector_panel.visible = false
	if debug_overlay:
		debug_overlay.visible = false


## Add custom log entry
func log_message(message: String, color: Color = Color(0.85, 0.82, 0.75, 0.95)) -> void:
	if world_memory_log == null:
		return
	
	var formatted: String = "[color=#%s]%s[/color]\n" % [color.to_html(false), message]
	world_memory_log.append_text(formatted)
	world_memory_log.scroll_to_line(world_memory_log.get_line_count() - 1)


## Clear log
func clear_log() -> void:
	if world_memory_log:
		world_memory_log.clear()
