extends Node
## Consolidated UI Manager
## Combines UI systems into one autoload
## Reduces autoload count while preserving UI functionality

# Child nodes for UI subsystems (loaded on-demand)
var _heelkawn_ui_manager: Node
var _ui_layout_manager: Node
var _pawn_mood_ui: Node
var _event_notification_overlay: Node
var _modern_theme: Node
var _pawn_chatter_bubbles: Node

var _subsystems_loaded: bool = false

func _ready() -> void:
	print("[UIManager] Initialized")

## Load UI subsystems on-demand (not at startup)
func _load_subsystems() -> void:
	if _subsystems_loaded:
		return
	
	# Load UI subsystems as children
	if FileAccess.file_exists("res://autoloads/HeelKawnUIManager.gd"):
		_heelkawn_ui_manager = load("res://autoloads/HeelKawnUIManager.gd").new()
		_heelkawn_ui_manager.name = "HeelKawnUIManager"
		add_child(_heelkawn_ui_manager)
	
	if FileAccess.file_exists("res://autoloads/UILayoutManager.gd"):
		_ui_layout_manager = load("res://autoloads/UILayoutManager.gd").new()
		_ui_layout_manager.name = "UILayoutManager"
		add_child(_ui_layout_manager)
	
	if FileAccess.file_exists("res://scripts/ui/PawnMoodUI.gd"):
		_pawn_mood_ui = load("res://scripts/ui/PawnMoodUI.gd").new()
		_pawn_mood_ui.name = "PawnMoodUI"
		add_child(_pawn_mood_ui)
	
	if FileAccess.file_exists("res://scripts/ui/EventNotificationOverlay.gd"):
		_event_notification_overlay = load("res://scripts/ui/EventNotificationOverlay.gd").new()
		_event_notification_overlay.name = "EventNotificationOverlay"
		add_child(_event_notification_overlay)
	
	if FileAccess.file_exists("res://scripts/ui/ModernTheme.gd"):
		_modern_theme = load("res://scripts/ui/ModernTheme.gd").new()
		_modern_theme.name = "ModernTheme"
		add_child(_modern_theme)
	
	if FileAccess.file_exists("res://autoloads/PawnChatterBubbles.gd"):
		_pawn_chatter_bubbles = load("res://autoloads/PawnChatterBubbles.gd").new()
		_pawn_chatter_bubbles.name = "PawnChatterBubbles"
		add_child(_pawn_chatter_bubbles)
	
	_subsystems_loaded = true
	print("[UIManager] UI subsystems loaded")

## Get a specific UI subsystem (loads if not already loaded)
func get_subsystem(name: String) -> Node:
	_load_subsystems()
	match name:
		"heelkawn_ui_manager": return _heelkawn_ui_manager
		"ui_layout_manager": return _ui_layout_manager
		"pawn_mood_ui": return _pawn_mood_ui
		"event_notification_overlay": return _event_notification_overlay
		"modern_theme": return _modern_theme
		"pawn_chatter_bubbles": return _pawn_chatter_bubbles
		_: return null

## Show event notification (delegates to EventNotificationOverlay if available)
func show_event_notification(event: Dictionary) -> void:
	if _event_notification_overlay == null:
		_load_subsystems()
	if _event_notification_overlay != null and _event_notification_overlay.has_method("show_notification"):
		_event_notification_overlay.show_notification(event)

## Update pawn mood UI (delegates to PawnMoodUI if available)
func update_pawn_mood(pawn_id: int, mood: float) -> void:
	if _pawn_mood_ui == null:
		_load_subsystems()
	if _pawn_mood_ui != null and _pawn_mood_ui.has_method("update_mood"):
		_pawn_mood_ui.update_mood(pawn_id, mood)

## Show chatter bubble (delegates to PawnChatterBubbles if available)
func show_chatter_bubble(pawn_id: int, text: String) -> void:
	if _pawn_chatter_bubbles == null:
		_load_subsystems()
	if _pawn_chatter_bubbles != null and _pawn_chatter_bubbles.has_method("show_bubble"):
		_pawn_chatter_bubbles.show_bubble(pawn_id, text)

## Forward getters for subsystems
func get_heelkawn_ui_manager() -> Node:
	return get_subsystem("heelkawn_ui_manager")

func get_ui_layout_manager() -> Node:
	return get_subsystem("ui_layout_manager")

func get_pawn_mood_ui() -> Node:
	return get_subsystem("pawn_mood_ui")

func get_event_notification_overlay() -> Node:
	return get_subsystem("event_notification_overlay")

func get_modern_theme() -> Node:
	return get_subsystem("modern_theme")

func get_pawn_chatter_bubbles() -> Node:
	return get_subsystem("pawn_chatter_bubbles")
