class_name BuildToolbar
extends CanvasLayer

## Bottom bar: time + save/load + appearance. Player does **not** stamp walls
## or zones here — autonomous planner + pawn jobs own construction.

## Emitted when the player clicks a speed button. Index into SPEED_STEPS.
signal speed_index_requested(idx: int)

## Emitted when the player clicks pause. Main routes to GameManager.toggle_pause.
signal pause_toggled()

## Legacy compatibility signal: older Main wiring still connects this even
## though build stamping is disabled in the current toolbar layout.
signal mode_requested(mode: int)

## Legacy compatibility signal: retained so Main can connect safely.
signal reroll_requested()

## Legacy compatibility signal: retained so Main can connect safely.
signal zone_filter_cycle_requested()

## Open cosmetic editor for the selected pawn (same HeelKawnianData fields as NPCs).
signal appearance_edit_requested()

## Persist colony (F5) / restore last save (F8). Mirrors keyboard shortcuts.
signal save_requested()
signal load_requested()
signal ui_layout_edit_toggled(enabled: bool)

## Emitted when building type is selected.
signal structure_type_requested(type: String)

# Keep these mode ints in sync with Main.DesignationMode.
const MODE_NONE: int = 0
const MODE_BED:  int = 1
const MODE_WALL: int = 2
const MODE_DOOR: int = 3
const MODE_ZONE: int = 4

const PANEL_BG:     Color = Color(0.05, 0.06, 0.08, 0.88)
const PANEL_BORDER: Color = Color(0.85, 0.78, 0.40, 0.65)
const ACCENT_TIME:  Color = Color8(120, 200, 255)  # cool blue for time cluster
const ACCENT_SAVE:  Color = Color8(100, 200, 140)  # save (disk)
const ACCENT_LOAD:  Color = Color8(200, 160, 100)  # load / recall
const ACCENT_YOU:  Color = Color8(200, 140, 220)
const ACCENT_BUILD: Color = Color8(220, 180, 100)
const ACCENT_VIEW:  Color = Color8(160, 200, 220)

const FONT_SIZE_BUTTON: int = 11
const FONT_SIZE_LABEL:  int = 9

var _panel: PanelContainer = null
var _speed_buttons: Array = []        # parallel to GameManager.SPEED_STEPS
var _pause_button: Button = null

var _active_mode: int = MODE_NONE
var _view_buttons: Dictionary = {}  # panel_name -> Button
var _ui_edit_button: Button = null


func _ready() -> void:
	layer = 100  # above the world, in line with ColonyHUD
	_build_ui()
	GameManager.speed_changed.connect(_on_speed_changed)
	get_viewport().size_changed.connect(_recenter)
	_refresh_speed_buttons(GameManager.game_speed, GameManager.is_paused)


# ==================== layout ====================

func _build_ui() -> void:
	# Full-rect Control as anchor surface, doesn't eat input itself.
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_panel = PanelContainer.new()
	# STOP so clicks on the bar don't fall through and place a tile underneath.
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.add_theme_stylebox_override("panel", _make_panel_style())
	root.add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",  10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top",   6)
	margin.add_theme_constant_override("margin_bottom", 6)
	_panel.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	margin.add_child(row)

	_build_speed_cluster(row)
	row.add_child(_make_separator())
	_build_save_load_cluster(row)
	row.add_child(_make_separator())
	_build_appearance_cluster(row)
	row.add_child(_make_separator())
	_build_build_cluster(row)
	row.add_child(_make_separator())
	_build_view_cluster(row)

	_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	# Defer position so layout settles and we can read the actual minimum size.
	call_deferred("_recenter")


func _build_speed_cluster(row: HBoxContainer) -> void:
	var label := _make_cluster_label("Time")
	row.add_child(label)
	_pause_button = _make_button("Pause [Space]", ACCENT_TIME)
	_pause_button.toggle_mode = true
	_pause_button.pressed.connect(func(): pause_toggled.emit())
	row.add_child(_pause_button)
	_speed_buttons.clear()
	for i in range(GameManager.SPEED_STEPS.size()):
		var s: float = GameManager.SPEED_STEPS[i]
		var btn := _make_button("%dx [%d]" % [int(s), i + 1], ACCENT_TIME)
		btn.toggle_mode = true
		btn.pressed.connect(_on_speed_pressed.bind(i))
		_speed_buttons.append(btn)
		row.add_child(btn)


func _build_appearance_cluster(row: HBoxContainer) -> void:
	var label := _make_cluster_label("You")
	row.add_child(label)
	var btn := _make_button("Sprite [K]", ACCENT_YOU)
	btn.pressed.connect(func(): appearance_edit_requested.emit())
	row.add_child(btn)


func _build_build_cluster(row: HBoxContainer) -> void:
	var label := _make_cluster_label("Build")
	row.add_child(label)
	
	# Mini dropdown or set of buttons for structures
	# For now, we'll list core ones to keep the bar compact.
	var items := ["Foundation", "Wall", "Door", "Shelter", "Fire Pit"]
	for item in items:
		var btn := _make_button(item, ACCENT_BUILD)
		btn.pressed.connect(func(): _on_build_item_pressed(item.to_lower().replace(" ", "_")))
		row.add_child(btn)


func _on_build_item_pressed(type: String) -> void:
	structure_type_requested.emit(type)


func _build_view_cluster(row: HBoxContainer) -> void:
	var label := _make_cluster_label("View")
	row.add_child(label)
	_ui_edit_button = _make_button("UI Edit", ACCENT_VIEW)
	_ui_edit_button.toggle_mode = true
	_ui_edit_button.set_pressed_no_signal(false)
	_ui_edit_button.pressed.connect(_on_ui_layout_edit_toggle)
	row.add_child(_ui_edit_button)
	# Each button toggles a UI panel. Default state: ColonyHUD on, others off.
	var panels: Array = [
		{"name": "ColonyHUD", "label": "Colony", "default_on": true},
		{"name": "SurvivalHUD", "label": "Survival", "default_on": false},
		{"name": "ObserverHUD", "label": "Realm", "default_on": false},
		{"name": "Minimap", "label": "Map", "default_on": true},
		{"name": "PawnInfoPanel", "label": "Info", "default_on": true},
	]
	for p in panels:
		var btn := _make_button(p["label"], ACCENT_VIEW)
		btn.toggle_mode = true
		var panel_name: String = p["name"]
		var default_on: bool = p["default_on"]
		btn.set_pressed_no_signal(default_on)
		btn.pressed.connect(_on_view_toggle.bind(panel_name, btn))
		_view_buttons[panel_name] = btn
		row.add_child(btn)
		# Apply initial state
		_set_panel_visible(panel_name, default_on)


func _on_ui_layout_edit_toggle() -> void:
	if _ui_edit_button == null:
		return
	ui_layout_edit_toggled.emit(_ui_edit_button.is_pressed())


func _on_view_toggle(panel_name: String, btn: Button) -> void:
	_set_panel_visible(panel_name, btn.is_pressed())


func _set_panel_visible(panel_name: String, visible: bool) -> void:
	# Find the panel in the UI_Viewport
	var ui_viewport = get_tree().get_root().get_node_or_null("Main/UI_Viewport")
	if ui_viewport == null:
		return
	var panel = ui_viewport.get_node_or_null(panel_name)
	if panel == null:
		return
	panel.visible = visible
	# Also handle PawnInfoPanel which is a CanvasLayer
	if panel is CanvasLayer:
		for child in panel.get_children():
			if child is Control:
				child.visible = visible


func _build_save_load_cluster(row: HBoxContainer) -> void:
	var label := _make_cluster_label("Colony")
	row.add_child(label)
	var save_btn := _make_button("Save [F5]", ACCENT_SAVE)
	_apply_persist_button_style(save_btn, ACCENT_SAVE)
	save_btn.pressed.connect(func(): save_requested.emit())
	row.add_child(save_btn)
	var load_btn := _make_button("Load [F8]", ACCENT_LOAD)
	_apply_persist_button_style(load_btn, ACCENT_LOAD)
	load_btn.pressed.connect(func(): load_requested.emit())
	row.add_child(load_btn)


func _apply_persist_button_style(btn: Button, accent: Color) -> void:
	var n := StyleBoxFlat.new()
	n.bg_color = Color(0.09, 0.1, 0.13, 0.9)
	n.set_border_width_all(1)
	n.border_color = Color(accent.r, accent.g, accent.b, 0.45)
	n.set_corner_radius_all(3)
	var h := StyleBoxFlat.new()
	h.bg_color = n.bg_color.lerp(accent, 0.15)
	h.set_border_width_all(1)
	h.border_color = Color(accent.r, accent.g, accent.b, 0.8)
	h.set_corner_radius_all(3)
	var p := StyleBoxFlat.new()
	p.bg_color = n.bg_color.lerp(accent, 0.28)
	p.set_border_width_all(2)
	p.border_color = accent
	p.set_corner_radius_all(3)
	btn.add_theme_stylebox_override("normal", n)
	btn.add_theme_stylebox_override("hover", h)
	btn.add_theme_stylebox_override("pressed", p)
	btn.add_theme_color_override("font_color", Color(0.88, 0.9, 0.92))
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", Color.WHITE)


func _make_cluster_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", FONT_SIZE_LABEL)
	l.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	# Right padding via a margin container would be heavier than just spacing.
	return l


func _make_separator() -> VSeparator:
	var s := VSeparator.new()
	s.custom_minimum_size = Vector2(2, 0)
	return s


func _make_button(text: String, accent: Color) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.add_theme_font_size_override("font_size", FONT_SIZE_BUTTON)
	# Subtle accent on the toggled-on state by recoloring the font when pressed.
	btn.add_theme_color_override("font_pressed_color", accent)
	btn.add_theme_color_override("font_focus_color", accent)
	btn.focus_mode = Control.FOCUS_NONE  # don't let TAB bounce around the bar
	return btn


func _make_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_BG
	style.border_color = PANEL_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 4
	style.content_margin_right = 4
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	return style


func _recenter() -> void:
	if _panel == null:
		return
	# Position the panel at bottom-center with an 8px inset.
	var view: Vector2 = get_viewport().get_visible_rect().size
	var size: Vector2 = _panel.get_combined_minimum_size()
	_panel.position = Vector2((view.x - size.x) * 0.5, view.y - size.y - 8)
	_panel.size = size


# ==================== signals out ====================

func _on_speed_pressed(idx: int) -> void:
	speed_index_requested.emit(idx)


# ==================== external sync ====================

## Legacy hook: build modes removed from shipped play — always NONE.
func set_active_mode(mode: int) -> void:
	_active_mode = MODE_NONE
	if mode != MODE_NONE:
		pass


## No-op: Main still cycles zone filter state for internal consistency; UI removed.
func set_zone_filter_label(_label_text: String) -> void:
	pass


func _on_speed_changed(speed: float, paused: bool) -> void:
	_refresh_speed_buttons(speed, paused)


func _refresh_speed_buttons(speed: float, paused: bool) -> void:
	if _pause_button != null:
		_pause_button.set_pressed_no_signal(paused)
	for i in range(_speed_buttons.size()):
		var s: float = GameManager.SPEED_STEPS[i]
		var is_active: bool = (not paused) and is_equal_approx(speed, s)
		_speed_buttons[i].set_pressed_no_signal(is_active)
