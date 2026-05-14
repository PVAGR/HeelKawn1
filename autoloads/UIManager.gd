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

var _heelkawn_ui_loaded: bool = false
var _ui_layout_loaded: bool = false
var _pawn_mood_ui_loaded: bool = false
var _event_overlay_loaded: bool = false
var _modern_theme_loaded: bool = false
var _chatter_bubbles_loaded: bool = false

func _ready() -> void:
	pass

func _load_sub(name: String, path: String) -> Node:
	var existing: Node = get_node_or_null("/root/" + name)
	if existing != null:
		return existing
	if FileAccess.file_exists(path):
		var loaded: Node = load(path).new()
		loaded.name = name
		add_child(loaded)
		return loaded
	return null

func _ensure_heelkawn_ui() -> void:
	if not _heelkawn_ui_loaded:
		_heelkawn_ui_manager = _load_sub("HeelKawnUIManager", "res://autoloads/HeelKawnUIManager.gd")
		_heelkawn_ui_loaded = true

func _ensure_ui_layout() -> void:
	if not _ui_layout_loaded:
		_ui_layout_manager = _load_sub("UILayoutManager", "res://autoloads/UILayoutManager.gd")
		_ui_layout_loaded = true

func _ensure_pawn_mood_ui() -> void:
	if not _pawn_mood_ui_loaded:
		_pawn_mood_ui = _load_sub("PawnMoodUI", "res://scripts/ui/PawnMoodUI.gd")
		_pawn_mood_ui_loaded = true

func _ensure_event_overlay() -> void:
	if not _event_overlay_loaded:
		_event_notification_overlay = _load_sub("EventNotificationOverlay", "res://scripts/ui/EventNotificationOverlay.gd")
		_event_overlay_loaded = true

func _ensure_modern_theme() -> void:
	if not _modern_theme_loaded:
		_modern_theme = _load_sub("ModernTheme", "res://scripts/ui/ModernTheme.gd")
		_modern_theme_loaded = true

func _ensure_chatter_bubbles() -> void:
	if not _chatter_bubbles_loaded:
		_pawn_chatter_bubbles = _load_sub("PawnChatterBubbles", "res://autoloads/PawnChatterBubbles.gd")
		_chatter_bubbles_loaded = true

## Get a specific UI subsystem (loads if not already loaded)
func get_subsystem(name: String) -> Node:
	match name:
		"heelkawn_ui_manager": _ensure_heelkawn_ui(); return _heelkawn_ui_manager
		"ui_layout_manager": _ensure_ui_layout(); return _ui_layout_manager
		"pawn_mood_ui": _ensure_pawn_mood_ui(); return _pawn_mood_ui
		"event_notification_overlay": _ensure_event_overlay(); return _event_notification_overlay
		"modern_theme": _ensure_modern_theme(); return _modern_theme
		"pawn_chatter_bubbles": _ensure_chatter_bubbles(); return _pawn_chatter_bubbles
		_: return null

## Show event notification (delegates to EventNotificationOverlay if available)
func show_event_notification(event: Dictionary) -> void:
	_ensure_event_overlay()
	if _event_notification_overlay != null and _event_notification_overlay.has_method("show_notification"):
		_event_notification_overlay.show_notification(event)

## Update pawn mood UI (delegates to PawnMoodUI if available)
func update_pawn_mood(pawn_id: int, mood: float) -> void:
	_ensure_pawn_mood_ui()
	if _pawn_mood_ui != null and _pawn_mood_ui.has_method("update_mood"):
		_pawn_mood_ui.update_mood(pawn_id, mood)

## Show chatter bubble (delegates to PawnChatterBubbles if available)
func show_chatter_bubble(pawn_id: int, text: String) -> void:
	_ensure_chatter_bubbles()
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
