extends CanvasLayer
## EventNotificationOverlay - Beautiful popup notifications for important game events.
## NOTE: Not using class_name to avoid conflict with autoload singleton

## Phase 5: Rich Event Notifications
## Beautiful popup notifications for important game events.
## Displays with fade-in/fade-out animations and rich text formatting.

const NOTIFICATION_LIFETIME_SEC: float = 8.0
const FADE_IN_SEC: float = 0.5
const FADE_OUT_SEC: float = 1.0
const MAX_VISIBLE_NOTIFICATIONS: int = 3

# PERFORMANCE: Throttle notifications to prevent spam and frame drops
const NOTIFICATION_THROTTLE_SEC: float = 0.3  # Minimum time between notifications
const NOTIFICATION_BATCH_SIMILAR: bool = true  # Group similar events together

# Notification types with visual styles
const NOTIFICATION_STYLES: Dictionary = {
	"birth": {"color": Color8(87, 197, 182), "icon": "👶", "priority": 1},
	"death": {"color": Color8(255, 107, 107), "icon": "⚰", "priority": 1},
	"legacy": {"color": Color8(255, 209, 102), "icon": "⭐", "priority": 2},
	"succession": {"color": Color8(255, 209, 102), "icon": "👑", "priority": 2},
	"knowledge": {"color": Color8(176, 132, 208), "icon": "📜", "priority": 1},
	"building": {"color": Color8(255, 209, 102), "icon": "🏗", "priority": 0},
	"discovery": {"color": Color8(176, 132, 208), "icon": "✨", "priority": 1},
	"milestone": {"color": Color8(255, 159, 107), "icon": "💕", "priority": 1},
	"settlement": {"color": Color8(255, 209, 102), "icon": "🏰", "priority": 2},
}

var _notification_container: VBoxContainer
var _active_notifications: Array[Dictionary] = []
var _notification_id_counter: int = 0
var _last_notification_time: float = 0.0  # PERFORMANCE: Throttle notification spam
var _pending_notifications: Array[Dictionary] = []  # PERFORMANCE: Batch similar events


func _ready() -> void:
	layer = 90  # Below F10 menu (100) but above game UI
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()


func _process(delta: float) -> void:
	_update_notifications(delta)


func _build_ui() -> void:
	# Main container - right side, middle of screen
	_notification_container = VBoxContainer.new()
	_notification_container.name = "EventNotificationContainer"
	_notification_container.add_theme_constant_override("separation", 8)
	
	# Position on right side of screen
	_notification_container.anchor_left = 1.0
	_notification_container.anchor_right = 1.0
	_notification_container.anchor_top = 0.5
	_notification_container.anchor_bottom = 0.5
	_notification_container.offset_left = -420  # Width + margin
	_notification_container.offset_top = -200   # Half of typical height
	_notification_container.size_flags_horizontal = Control.SIZE_SHRINK_END
	
	add_child(_notification_container)


func _update_notifications(delta: float) -> void:
	var now: float = Time.get_ticks_msec() / 1000.0

	# PERFORMANCE: Try to process pending notifications if throttle allows
	if not _pending_notifications.is_empty() and (now - _last_notification_time) >= NOTIFICATION_THROTTLE_SEC:
		var next: Dictionary = _pending_notifications.pop_front()
		show_notification(
			next.type,
			next.title,
			next.description,
			next.get("icon", ""),
			next.get("pawn_id", -1)
		)

	# Remove expired notifications
	for i in range(_active_notifications.size() - 1, -1, -1):
		var notif: Dictionary = _active_notifications[i]
		var age: float = now - notif.start_time

		if age > NOTIFICATION_LIFETIME_SEC:
			# Fade out
			var fade_progress: float = (age - NOTIFICATION_LIFETIME_SEC) / FADE_OUT_SEC
			if fade_progress >= 1.0:
				_remove_notification(i)
			else:
				_set_notification_alpha(i, 1.0 - fade_progress)
		elif age < FADE_IN_SEC:
			# Fade in
			var fade_progress: float = age / FADE_IN_SEC
			_set_notification_alpha(i, fade_progress)


func _set_notification_alpha(index: int, alpha: float) -> void:
	if index >= _active_notifications.size():
		return
	
	var notif: Dictionary = _active_notifications[index]
	if notif.has("panel"):
		var panel: PanelContainer = notif.panel
		if panel != null and is_instance_valid(panel):
			panel.modulate.a = alpha


func _remove_notification(index: int) -> void:
	if index >= _active_notifications.size():
		return
	
	var notif: Dictionary = _active_notifications[index]
	if notif.has("panel"):
		var panel: PanelContainer = notif.panel
		if panel != null and is_instance_valid(panel):
			panel.queue_free()
	
	_active_notifications.remove_at(index)


## Show a rich event notification.
## @param event_type Type of event (birth, death, legacy, etc.)
## @param title Main title text (e.g., pawn name)
## @param description Detailed description (e.g., "died of old age at 67")
## @param icon_override Optional custom icon emoji
## @param pawn_id Optional pawn ID for clickable biographies
func show_notification(event_type: String, title: String, description: String, icon_override: String = "", pawn_id: int = -1) -> void:
	# PERFORMANCE: Throttle notifications to prevent spam and frame drops
	var now: float = Time.get_ticks_msec() / 1000.0
	if (now - _last_notification_time) < NOTIFICATION_THROTTLE_SEC:
		# Queue for later if throttled
		_pending_notifications.append({
			"type": event_type,
			"title": title,
			"description": description,
			"icon": icon_override,
			"pawn_id": pawn_id,
			"queued_at": now
		})
		# Limit queue size to prevent memory buildup
		if _pending_notifications.size() > 10:
			_pending_notifications.pop_front()
		return
	
	_last_notification_time = now
	
	# PERFORMANCE: Process any pending notifications of same type
	if NOTIFICATION_BATCH_SIMILAR and not _pending_notifications.is_empty():
		var to_process: Array[Dictionary] = []
		for i in range(_pending_notifications.size() - 1, -1, -1):
			if _pending_notifications[i].type == event_type:
				to_process.append(_pending_notifications[i])
				_pending_notifications.remove_at(i)
		
		if not to_process.is_empty():
			title = "%s (+%d more)" % [title, to_process.size()]
	
	var style: Dictionary = NOTIFICATION_STYLES.get(event_type, {
		"color": Color.WHITE,
		"icon": "📢",
		"priority": 0
	})

	var icon: String = icon_override if icon_override != "" else style.icon
	var color: Color = style.color
	var priority: int = style.priority

	# Enforce max visible notifications
	while _active_notifications.size() >= MAX_VISIBLE_NOTIFICATIONS:
		# Remove lowest priority notification
		var lowest_idx: int = 0
		var lowest_priority: int = 999
		for i in range(_active_notifications.size()):
			if _active_notifications[i].priority < lowest_priority:
				lowest_priority = _active_notifications[i].priority
				lowest_idx = i
		_remove_notification(lowest_idx)

	# Create notification panel
	var panel: PanelContainer = _create_notification_panel(title, description, icon, color)
	_notification_container.add_child(panel)

	# Add to active list
	var notif_id: int = _notification_id_counter
	_notification_id_counter += 1

	_active_notifications.append({
		"id": notif_id,
		"panel": panel,
		"start_time": Time.get_ticks_msec() / 1000.0,
		"priority": priority,
		"pawn_id": pawn_id
	})


func _create_notification_panel(title: String, description: String, icon: String, color: Color) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(400, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP  # Enable clicks
	
	# StyleBox for panel
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.06, 0.08, 0.95)
	style.border_color = color
	style.border_width_left = 3
	style.border_width_right = 0
	style.border_width_top = 0
	style.border_width_bottom = 0
	style.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", style)
	
	# Content container
	var content: HBoxContainer = HBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	panel.add_child(content)
	
	# Icon (large emoji-style)
	var icon_label: Label = Label.new()
	icon_label.text = icon
	icon_label.add_theme_font_size_override("font_size", 32)
	icon_label.custom_minimum_size = Vector2(40, 40)
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	content.add_child(icon_label)
	
	# Text container
	var text_container: VBoxContainer = VBoxContainer.new()
	text_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(text_container)
	
	# Title (bold, colored)
	var title_label: Label = Label.new()
	title_label.text = title
	title_label.add_theme_font_size_override("font_size", 14)
	title_label.add_theme_color_override("font_color", color)
	text_container.add_child(title_label)
	
	# Description (smaller, gray)
	var desc_label: Label = Label.new()
	desc_label.text = description
	desc_label.add_theme_font_size_override("font_size", 11)
	desc_label.add_theme_color_override("font_color", Color8(180, 180, 190))
	text_container.add_child(desc_label)
	
	# Add click handler for death notifications
	panel.gui_input.connect(_on_notification_clicked.bind(panel))
	
	return panel


func _on_notification_clicked(event: InputEvent, panel: PanelContainer) -> void:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			# Find the notification data
			for notif in _active_notifications:
				if notif.panel == panel:
					# Check if this is a death notification
					if notif.has("pawn_id"):
						# Show biography for this pawn
						_show_pawn_biography(int(notif.pawn_id))
					break


func _get_pawn_spawner() -> Node:
	var _main: Node = get_tree().get_root().get_node_or_null("Main")
	if _main == null:
		return null
	return _main.get_node_or_null("WorldViewport/PawnSpawner")

func _show_pawn_biography(pawn_id: int) -> void:
	# Get pawn data
	var ps: Node = _get_pawn_spawner()
	if ps == null:
		return
	
	var pawn_data: PawnData = ps.call("pawn_data_for_id", pawn_id)
	if pawn_data == null:
		return
	
	# Generate biography using WorldMemory's function
	var wmem: Node = get_node_or_null("/root/WorldMemory")
	if wmem == null or not wmem.has_method("_generate_pawn_biography"):
		return
	
	var biography: String = wmem.call("_generate_pawn_biography", pawn_data, "clicked_notification")
	
	# Show in dialog
	var dialog: AcceptDialog = AcceptDialog.new()
	dialog.title = "Biography: %s" % pawn_data.display_name
	dialog.dialog_text = biography
	dialog.exclusive = false
	dialog.resizable = true
	dialog.size = Vector2(600, 500)
	
	# Add close button
	dialog.add_button("Close", true, "close")
	
	# Add to scene
	get_tree().root.add_child(dialog)
	dialog.popup_centered()


# ==================== PRESET NOTIFICATION HELPERS ====================

func notify_birth(pawn_name: String, settlement_name: String) -> void:
	show_notification(
		"birth",
		"👶 %s Born" % pawn_name,
		"in %s" % settlement_name
	)


func notify_death(pawn_name: String, age: float, cause: String, pawn_id: int = -1) -> void:
	show_notification(
		"death",
		"⚰ %s Died" % pawn_name,
		"Age %.1f - %s" % [age, cause],
		"",
		pawn_id
	)


func notify_legacy_milestone(pawn_name: String, score: int, milestone: String) -> void:
	show_notification(
		"legacy",
		"⭐ %s - Legacy %d" % [pawn_name, score],
		milestone
	)


func notify_succession(heir_name: String, ancestor_name: String, knowledge_gained: int) -> void:
	show_notification(
		"succession",
		"👑 Succession: %s" % heir_name,
		"Inherited from %s (+%d knowledge)" % [ancestor_name, knowledge_gained]
	)


func notify_knowledge_inscribed(pawn_name: String, knowledge_types: Array) -> void:
	var kt_text: String = "%d type%s" % [knowledge_types.size(), "s" if knowledge_types.size() > 1 else ""]
	show_notification(
		"knowledge",
		"📜 Knowledge Inscribed",
		"%s preserved %s on stone" % [pawn_name, kt_text]
	)


func notify_knowledge_read(pawn_name: String, knowledge_gained: int) -> void:
	show_notification(
		"discovery",
		"✨ %s Reads Ancient Stone" % pawn_name,
		"Gained %d knowledge type%s" % [knowledge_gained, "s" if knowledge_gained > 1 else ""]
	)


func notify_building_constructed(building_name: String, settlement_name: String) -> void:
	show_notification(
		"building",
		"🏗 %s Built" % building_name,
		"in %s" % settlement_name
	)


func notify_friendship_milestone(pawn_a: String, pawn_b: String, milestone: int) -> void:
	show_notification(
		"milestone",
		"💕 Friendship Milestone",
		"%s & %s reached %d" % [pawn_a, pawn_b, milestone]
	)


func notify_settlement_founded(settlement_name: String, founder_name: String) -> void:
	show_notification(
		"settlement",
		"🏰 %s Founded" % settlement_name,
		"by %s" % founder_name
	)


func notify_settlement_revived(settlement_name: String) -> void:
	show_notification(
		"settlement",
		"🏰 %s Revived" % settlement_name,
		"Settlement returns to active state"
	)


func notify_settlement_abandoned(settlement_name: String, reason: String) -> void:
	show_notification(
		"death",
		"💀 %s Abandoned" % settlement_name,
		reason
	)
