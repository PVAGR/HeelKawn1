class_name UrgentAlert
extends CanvasLayer

## Screen-edge pulsing alerts for severity-3 events (deaths, fires, starvation,
## knowledge loss, social schisms). Red pulse border + icon + text.
## Click to jump camera to event location. Auto-dismiss after 8 seconds.

const MAX_ALERTS: int = 2
const ALERT_LIFETIME_SEC: float = 8.0
const PULSE_SPEED: float = 3.0
const POLL_EVERY_N_TICKS: int = 5
const SEVERITY_THRESHOLD: int = 3

const BORDER_COLOR: Color = Color(1.0, 0.15, 0.1, 1.0)
const BG_COLOR: Color = Color(0.12, 0.04, 0.04, 0.85)
const TEXT_COLOR: Color = Color(1.0, 0.85, 0.8, 1.0)

# Severity-3 event types from WorldMemory._severity_for_type
const URGENT_TYPES: Dictionary = {
	"pawn_death": true,
	"starvation_death": true,
	"knowledge_loss": true,
	"social_schism": true,
	"fire_started": true,
	"fire_destroyed_building": true,
	"war_battle_spawned": true,
}

var _alerts: Array[Dictionary] = []  # {event: Dictionary, spawn_time: float, panel: PanelContainer}
var _border_rect: ColorRect
var _last_polled_event_id: int = -1
var _tick_counter: int = 0
var _world: World = null
var _camera: Camera2D = null


func _ready() -> void:
	layer = 20  # Above everything

	# Full-screen pulsing border
	_border_rect = ColorRect.new()
	_border_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_border_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_border_rect.color = Color(1.0, 0.0, 0.0, 0.0)
	add_child(_border_rect)

	# Alert container (top-center) — compact
	var container: VBoxContainer = VBoxContainer.new()
	container.anchor_left = 0.5
	container.anchor_top = 0.0
	container.anchor_right = 0.5
	container.anchor_bottom = 0.0
	container.grow_horizontal = Control.GROW_DIRECTION_BOTH
	container.offset_left = -120.0
	container.offset_right = 120.0
	container.offset_top = 40.0
	container.add_theme_constant_override("separation", 2)
	container.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(container)

	# Store container for adding/removing alert panels
	_alert_container = container


var _alert_container: VBoxContainer


func initialize(world_ref: World, camera_ref: Camera2D) -> void:
	_world = world_ref
	_camera = camera_ref


func _process(delta: float) -> void:
	_tick_counter += 1
	if _tick_counter % POLL_EVERY_N_TICKS == 0:
		_poll_urgent_events()
	_update_alerts(delta)


func _poll_urgent_events() -> void:
	if WorldMemory == null:
		return
	var total: int = WorldMemory.event_count()
	if total == 0:
		return

	var recent: Array = WorldMemory.get_recent_events(mini(20, total))
	if recent.is_empty():
		return

	if _last_polled_event_id < 0:
		var latest: Dictionary = recent[recent.size() - 1] as Dictionary
		_last_polled_event_id = int(latest.get("eid", 0))
		return

	var new_urgent: Array[Dictionary] = []
	for e in recent:
		var eid: int = int(e.get("eid", 0))
		if eid <= _last_polled_event_id:
			continue
		var typ: String = str(e.get("type", ""))
		var sev: int = int(e.get("severity", 0))
		if sev >= SEVERITY_THRESHOLD or URGENT_TYPES.has(typ):
			new_urgent.append(e)

	if new_urgent.is_empty():
		return

	var max_eid: int = _last_polled_event_id
	for e in new_urgent:
		max_eid = maxi(max_eid, int(e.get("eid", 0)))
	_last_polled_event_id = max_eid

	# Show up to 2 urgent alerts
	for i in range(mini(2, new_urgent.size())):
		_add_alert(new_urgent[i])


func _add_alert(event: Dictionary) -> void:
	var typ: String = str(event.get("type", "event"))
	var icon: String = _icon_for_type(typ)
	var text: String = _format_alert(typ, event)

	var panel: PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _make_alert_style())
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.custom_minimum_size = Vector2(220, 24)

	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)

	var icon_label: Label = Label.new()
	icon_label.text = icon
	icon_label.add_theme_font_size_override("font_size", 12)
	icon_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var body_label: RichTextLabel = RichTextLabel.new()
	body_label.bbcode_enabled = true
	body_label.fit_content = true
	body_label.scroll_active = false
	body_label.add_theme_font_size_override("normal_font_size", 10)
	body_label.text = text
	body_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var click_btn: Button = Button.new()
	click_btn.text = "→"
	click_btn.add_theme_font_size_override("font_size", 9)
	click_btn.custom_minimum_size = Vector2(28, 18)
	click_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	# Wire click to focus camera on event
	var ev_copy: Dictionary = event.duplicate()
	click_btn.pressed.connect(_on_focus_pressed.bind(ev_copy))

	hbox.add_child(icon_label)
	hbox.add_child(body_label)
	hbox.add_child(click_btn)
	panel.add_child(hbox)
	_alert_container.add_child(panel)

	_alerts.append({
		"event": event,
		"spawn_time": Time.get_ticks_msec() / 1000.0,
		"panel": panel,
	})

	# Prune old alerts
	while _alerts.size() > MAX_ALERTS:
		_remove_oldest()


func _update_alerts(delta: float) -> void:
	var now: float = Time.get_ticks_msec() / 1000.0
	var has_active: bool = false

	var i: int = 0
	while i < _alerts.size():
		var entry: Dictionary = _alerts[i]
		var age: float = now - entry.get("spawn_time", 0.0)
		var panel: PanelContainer = entry.get("panel") as PanelContainer
		if panel == null or not is_instance_valid(panel):
			_alerts.remove_at(i)
			continue
		if age > ALERT_LIFETIME_SEC:
			panel.queue_free()
			_alerts.remove_at(i)
			continue
		has_active = true
		i += 1

	# Pulse the border when alerts are active
	if has_active:
		var pulse: float = (sin(Time.get_ticks_msec() / 1000.0 * PULSE_SPEED) + 1.0) * 0.5
		_border_rect.color = Color(1.0, 0.0, 0.0, pulse * 0.15)
	else:
		_border_rect.color = Color(1.0, 0.0, 0.0, 0.0)


func _on_focus_pressed(event: Dictionary) -> void:
	if _camera == null or _world == null:
		return
	# Try to get tile position from event
	var tile: Vector2i = Vector2i(-1, -1)
	if event.has("x") and event.has("y"):
		tile = Vector2i(int(event.get("x", -1)), int(event.get("y", -1)))
	elif event.has("tile"):
		var tv: Variant = event.get("tile")
		if tv is Vector2i:
			tile = tv as Vector2i
		elif tv is Dictionary:
			tile = Vector2i(int(tv.get("x", -1)), int(tv.get("y", -1)))
	elif event.has("r"):
		# Region key → approximate center tile
		var rk: int = int(event.get("r", -1))
		if rk >= 0:
			var nrx: int = WorldData.WIDTH / 16
			tile = Vector2i((rk % nrx) * 16 + 8, (rk / nrx) * 16 + 8)

	if tile.x >= 0 and tile.y >= 0:
		tile.x = clampi(tile.x, 0, WorldData.WIDTH - 1)
		tile.y = clampi(tile.y, 0, WorldData.HEIGHT - 1)
		_camera.global_position = _world.tile_to_world(tile)


func _icon_for_type(typ: String) -> String:
	match typ:
		"pawn_death", "starvation_death":
			return "✕"
		"fire_started", "fire_destroyed_building":
			return "🔥"
		"knowledge_loss":
			return "★✕"
		"social_schism":
			return "⚡"
		"war_battle_spawned":
			return "⚔"
		_:
			return "!"


func _format_alert(typ: String, e: Dictionary) -> String:
	match typ:
		"pawn_death", "starvation_death":
			var nm: String = str(e.get("n", e.get("name", "someone"))).strip_edges()
			if nm.is_empty():
				nm = "someone"
			return "[color=#ef5350]%s died[/color]" % nm
		"fire_started":
			return "[color=#ff5722]Fire broke out![/color]"
		"fire_destroyed_building":
			return "[color=#ff5722]Fire destroyed a building![/color]"
		"knowledge_loss":
			return "[color=#b39ddb]Knowledge was lost![/color]"
		"social_schism":
			return "[color=#ffab91]Social schism![/color]"
		"war_battle_spawned":
			return "[color=#ef5350]Battle began![/color]"
		_:
			return typ.replace("_", " ")


func _remove_oldest() -> void:
	if _alerts.is_empty():
		return
	var entry: Dictionary = _alerts.pop_front()
	var panel: PanelContainer = entry.get("panel") as PanelContainer
	if panel != null and is_instance_valid(panel):
		panel.queue_free()


func _make_alert_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = BG_COLOR
	style.border_color = Color(1.0, 0.2, 0.15, 0.8)
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_width_left = 2
	style.border_width_right = 1
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 5
	style.content_margin_right = 5
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	return style
