class_name EventToast
extends CanvasLayer

## Scrolling event feed — shows what's happening in the world in real time.
## Polls WorldMemory on a tick cadence, surfaces new events as toast lines
## that fade in, scroll up, and expire. Gives the player a living sense of
## the colony without reading the HUD numbers.
##
## Position: bottom-left, above the hotkey bar. Stacks upward.

const MAX_VISIBLE: int = 6
const LINE_LIFETIME_SEC: float = 8.0
const FADE_OUT_SEC: float = 2.0
const POLL_EVERY_N_TICKS: int = 5
const FONT_SIZE: int = 12
const LINE_SPACING: int = 2
const MARGIN_LEFT: float = 10.0
const MARGIN_BOTTOM: float = 40.0

const BG_COLOR: Color = Color(0.05, 0.06, 0.08, 0.55)
const TEXT_COLOR: Color = Color(0.88, 0.84, 0.72, 1.0)
const FADED_COLOR: Color = Color(0.88, 0.84, 0.72, 0.0)

# Event type → icon prefix for quick visual scanning
const TYPE_ICONS: Dictionary = {
	"pawn_birth": "[color=#aed581]+[/color]",
	"birth": "[color=#aed581]+[/color]",
	"pawn_death": "[color=#ef5350]✕[/color]",
	"starvation_death": "[color=#ef5350]✕[/color]",
	"animal_killed": "[color=#ff8a65]◆[/color]",
	"enemy_killed": "[color=#ce93d8]⚔[/color]",
	"building_constructed": "[color=#ffd54f]▲[/color]",
	"bed_built": "[color=#ffd54f]▲[/color]",
	"wall_built": "[color=#ffd54f]▲[/color]",
	"door_built": "[color=#ffd54f]▲[/color]",
	"structure_built": "[color=#ffd54f]▲[/color]",
	"cooperative_build": "[color=#ffd54f]▲▲[/color]",
	"fire_started": "[color=#ff5722]🔥[/color]",
	"fire_extinguished": "[color=#4fc3f7]💧[/color]",
	"fire_destroyed_building": "[color=#ff5722]🔥✕[/color]",
	"food_spoiled": "[color=#ff8a65]~[/color]",
	"seeds_planted": "[color=#81c784]🌱[/color]",
	"crop_harvested": "[color=#c5e1a5]✓[/color]",
	"job_completed": "[color=#90caf9]·[/color]",
	"knowledge_discovery": "[color=#b39ddb]★[/color]",
	"knowledge_rediscovery": "[color=#b39ddb]★[/color]",
	"knowledge_sealed": "[color=#b39ddb]✕★[/color]",
	"cultural_exposure": "[color=#ce93d8]↗[/color]",
	"social_bond_milestone": "[color=#80cbc4]♥[/color]",
	"social_meeting": "[color=#80cbc4]→[/color]",
	"governance_change": "[color=#fff176]⚖[/color]",
	"settlement_intent_shift": "[color=#fff176]↔[/color]",
	"war_proposed": "[color=#ef5350]⚔[/color]",
	"war_battle_spawned": "[color=#ef5350]⚔⚔[/color]",
	"diaspora_exile": "[color=#ffab91]→→[/color]",
	"diaspora_grief": "[color=#ffab91]~[/color]",
	"player_intent": "[color=#ffffff]✎[/color]",
}

var _vbox: VBoxContainer
var _panel: PanelContainer
var _margin: MarginContainer
var _lines: Array[Dictionary] = []  # {label: RichTextLabel, spawn_time: float, event_id: int}
var _last_polled_event_id: int = -1
var _tick_counter: int = 0


func _ready() -> void:
	layer = 10  # Above HUD (default layer 1)

	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", _make_panel_style())
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_margin = MarginContainer.new()
	_margin.add_theme_constant_override("margin_left", 6)
	_margin.add_theme_constant_override("margin_right", 6)
	_margin.add_theme_constant_override("margin_top", 4)
	_margin.add_theme_constant_override("margin_bottom", 4)

	_vbox = VBoxContainer.new()
	_vbox.add_theme_constant_override("separation", LINE_SPACING)
	_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_margin.add_child(_vbox)
	_panel.add_child(_margin)
	add_child(_panel)

	# Anchor to bottom-left
	_panel.anchor_left = 0.0
	_panel.anchor_top = 1.0
	_panel.anchor_right = 0.0
	_panel.anchor_bottom = 1.0
	_panel.grow_horizontal = Control.GROW_DIRECTION_END
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_panel.offset_left = MARGIN_LEFT
	_panel.offset_top = -300.0  # Will grow upward from bottom
	_panel.offset_bottom = -MARGIN_BOTTOM
	_panel.offset_right = MARGIN_LEFT + 380.0

	# Start invisible until events arrive
	_panel.visible = false


func _process(delta: float) -> void:
	_tick_counter += 1
	if _tick_counter % POLL_EVERY_N_TICKS == 0:
		_poll_new_events()
	_expire_lines(delta)


func _poll_new_events() -> void:
	if WorldMemory == null:
		return
	var total: int = WorldMemory.event_count()
	if total == 0:
		return

	# Find events we haven't shown yet
	var recent: Array = WorldMemory.get_recent_events(mini(20, total))
	if recent.is_empty():
		return

	# Get the highest event ID we've seen
	if _last_polled_event_id < 0:
		# First poll: skip everything, just record the latest ID
		var latest: Dictionary = recent[recent.size() - 1] as Dictionary
		_last_polled_event_id = int(latest.get("eid", 0))
		return

	# Collect new events (eid > last seen)
	var new_events: Array[Dictionary] = []
	for e in recent:
		var eid: int = int(e.get("eid", 0))
		if eid > _last_polled_event_id:
			new_events.append(e)

	if new_events.is_empty():
		return

	# Update the high-water mark
	var max_eid: int = _last_polled_event_id
	for e in new_events:
		max_eid = maxi(max_eid, int(e.get("eid", 0)))
	_last_polled_event_id = max_eid

	# Show up to 3 new events per poll to avoid flood
	var show_count: int = mini(3, new_events.size())
	for i in range(show_count):
		_add_toast(new_events[i])


func _add_toast(event: Dictionary) -> void:
	var typ: String = str(event.get("type", "event"))
	var tick: int = int(event.get("t", 0))
	var icon: String = TYPE_ICONS.get(typ, "[color=#888888]·[/color]")
	var body: String = _format_event_body(typ, event)
	var text: String = "%s %s" % [icon, body]

	var label: RichTextLabel = RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("normal_font_size", FONT_SIZE)
	label.text = text
	label.modulate = TEXT_COLOR

	_vbox.add_child(label)
	_lines.append({
		"label": label,
		"spawn_time": Time.get_ticks_msec() / 1000.0,
		"event_id": int(event.get("eid", 0)),
	})

	_panel.visible = true

	# Prune if too many visible
	while _lines.size() > MAX_VISIBLE:
		_remove_oldest()


func _format_event_body(typ: String, e: Dictionary) -> String:
	match typ:
		"pawn_birth", "birth":
			var child_name: String = str(e.get("pawn_name", "a child")).strip_edges()
			if child_name.is_empty():
				child_name = "a child"
			var pa: String = str(e.get("parent_a_name", "")).strip_edges()
			var pb: String = str(e.get("parent_b_name", "")).strip_edges()
			if not pa.is_empty() and not pb.is_empty():
				return "[color=#aed581]%s[/color] born to %s + %s" % [child_name, pa, pb]
			return "[color=#aed581]%s[/color] was born" % child_name
		"pawn_death", "starvation_death":
			var nm: String = str(e.get("n", e.get("name", "someone"))).strip_edges()
			if nm.is_empty():
				nm = "someone"
			return "[color=#ef5350]%s[/color] died" % nm
		"animal_killed":
			return "wildlife was culled"
		"enemy_killed":
			return "an enemy was slain"
		"building_constructed", "bed_built", "wall_built", "door_built", "structure_built":
			return "new structures were completed"
		"cooperative_build":
			return "crews raised structures together"
		"fire_started":
			return "[color=#ff5722]fire broke out[/color]"
		"fire_extinguished":
			return "[color=#4fc3f7]fire was put out[/color]"
		"fire_destroyed_building":
			return "[color=#ff5722]fire destroyed a building[/color]"
		"food_spoiled":
			return "food spoiled"
		"seeds_planted":
			return "seeds were planted"
		"crop_harvested":
			return "crops were harvested"
		"job_completed":
			var r: String = str(e.get("r", "")).strip_edges()
			if not r.is_empty():
				return "job finished (%s)" % r.replace("_", " ")
			return "a job was completed"
		"knowledge_discovery":
			var kt: String = str(e.get("knowledge_type", "?")).replace("_", " ")
			return "[color=#b39ddb]new knowledge: %s[/color]" % kt
		"knowledge_rediscovery":
			return "[color=#b39ddb]lost knowledge was rediscovered[/color]"
		"knowledge_sealed":
			var nm: String = str(e.get("carrier_name", "a scholar")).strip_edges()
			return "[color=#b39ddb]%s died with unfulfilled teaching[/color]" % nm
		"cultural_exposure":
			return "[color=#ce93d8]outsider absorbed local custom[/color]"
		"social_bond_milestone":
			var an: String = str(e.get("a_name", "A"))
			var bn: String = str(e.get("b_name", "B"))
			return "%s + %s bond deepened" % [an, bn]
		"social_meeting":
			var ma: String = str(e.get("a_name", "A"))
			var mb: String = str(e.get("b_name", "B"))
			return "%s met %s" % [ma, mb]
		"governance_change":
			var g: String = str(e.get("governance_type", "anarchy")).replace("_", " ")
			return "governance became [color=#fff176]%s[/color]" % g
		"settlement_intent_shift":
			var old_i: String = str(e.get("old_intent", "?")).to_lower()
			var new_i: String = str(e.get("new_intent", "?")).to_lower()
			return "intent shifted [color=#fff176]%s → %s[/color]" % [old_i, new_i]
		"war_proposed":
			return "[color=#ef5350]war was proposed[/color]"
		"war_battle_spawned":
			return "[color=#ef5350]a battle began[/color]"
		"diaspora_exile":
			var exiles: int = int(e.get("exile_pawn_ids", []) if e.get("exile_pawn_ids") is Array else 0)
			return "[color=#ffab91]%d exiled to found new settlement[/color]" % maxi(exiles, 1)
		"diaspora_grief":
			return "[color=#ffab91]exile grieved for lost home[/color]"
		"player_intent":
			return "chronicler note recorded"
		_:
			if bool(e.get("first_of_type", false)):
				return "first: %s" % typ.replace("_", " ")
			return typ.replace("_", " ")


func _expire_lines(delta: float) -> void:
	var now: float = Time.get_ticks_msec() / 1000.0
	var i: int = 0
	while i < _lines.size():
		var entry: Dictionary = _lines[i]
		var age: float = now - entry.get("spawn_time", 0.0)
		var label: RichTextLabel = entry.get("label") as RichTextLabel
		if label == null or not is_instance_valid(label):
			_lines.remove_at(i)
			continue
		if age > LINE_LIFETIME_SEC:
			# Fade out
			var fade_age: float = age - LINE_LIFETIME_SEC
			var alpha: float = clampf(1.0 - fade_age / FADE_OUT_SEC, 0.0, 1.0)
			label.modulate = Color(TEXT_COLOR.r, TEXT_COLOR.g, TEXT_COLOR.b, alpha)
			if alpha <= 0.0:
				label.queue_free()
				_lines.remove_at(i)
				continue
		i += 1

	# Hide panel if no lines
	if _lines.is_empty():
		_panel.visible = false


func _remove_oldest() -> void:
	if _lines.is_empty():
		return
	var entry: Dictionary = _lines.pop_front()
	var label: RichTextLabel = entry.get("label") as RichTextLabel
	if label != null and is_instance_valid(label):
		label.queue_free()


func _make_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = BG_COLOR
	style.border_color = Color(0.85, 0.78, 0.40, 0.30)
	style.border_width_bottom = 1
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	return style
