extends CanvasLayer
class_name IncarnationPicker

signal entry_confirmed(pawn_id: int)
signal closed()

var _selected_pawn_id: int = -1
var _title_label: Label = null
var _subtitle_label: Label = null
var _list_container: VBoxContainer = null
var _confirm_button: Button = null
var _return_button: Button = null
var _close_button: Button = null
var _candidate_rows: Dictionary = {}


func _ready() -> void:
	layer = 118
	visible = false
	_build_ui()


func open_with_candidates(candidates: Array, current_mode_label: String) -> void:
	_selected_pawn_id = -1
	visible = true
	if _title_label != null:
		_title_label.text = "Incarnation Entry"
	if _subtitle_label != null:
		_subtitle_label.text = "Current mode: %s | ranked by life stage, settlement vitality, and region context" % current_mode_label
	_rebuild_candidate_rows(candidates)
	_update_action_state()


func close_picker() -> void:
	if not visible:
		return
	visible = false
	_selected_pawn_id = -1
	_candidate_rows.clear()
	closed.emit()


func set_candidate_selection(pawn_id: int) -> void:
	_selected_pawn_id = pawn_id
	for key in _candidate_rows.keys():
		var btn: Button = _candidate_rows[key] as Button
		if btn != null:
			btn.button_pressed = int(key) == pawn_id
	_update_action_state()


func get_selected_pawn_id() -> int:
	return _selected_pawn_id


func _build_ui() -> void:
	var root: Control = Control.new()
	root.name = "Root"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)

	var dim: ColorRect = ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.5)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(dim)

	var panel: PanelContainer = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -310.0
	panel.offset_top = -240.0
	panel.offset_right = 310.0
	panel.offset_bottom = 240.0
	var pstyle: StyleBoxFlat = StyleBoxFlat.new()
	pstyle.bg_color = Color(0.06, 0.07, 0.09, 0.97)
	pstyle.border_color = Color(0.70, 0.60, 0.30, 0.90)
	pstyle.set_border_width_all(1)
	pstyle.set_corner_radius_all(6)
	pstyle.content_margin_left = 14
	pstyle.content_margin_right = 14
	pstyle.content_margin_top = 12
	pstyle.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", pstyle)
	root.add_child(panel)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	_title_label = Label.new()
	_title_label.text = "Incarnation Entry"
	_title_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(_title_label)

	_subtitle_label = Label.new()
	_subtitle_label.text = "Choose a living pawn"
	_subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle_label.add_theme_font_size_override("font_size", 11)
	_subtitle_label.add_theme_color_override("font_color", Color(0.78, 0.80, 0.84))
	vbox.add_child(_subtitle_label)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(580, 260)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	_list_container = VBoxContainer.new()
	_list_container.add_theme_constant_override("separation", 6)
	scroll.add_child(_list_container)

	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	vbox.add_child(buttons)

	_confirm_button = Button.new()
	_confirm_button.text = "Incarnate"
	_confirm_button.disabled = true
	_confirm_button.pressed.connect(_on_confirm_pressed)
	buttons.add_child(_confirm_button)

	_return_button = Button.new()
	_return_button.text = "Return to Spectator"
	_return_button.pressed.connect(_on_return_pressed)
	buttons.add_child(_return_button)

	_close_button = Button.new()
	_close_button.text = "Close"
	_close_button.pressed.connect(close_picker)
	buttons.add_child(_close_button)


func _rebuild_candidate_rows(candidates: Array) -> void:
	_candidate_rows.clear()
	if _list_container == null:
		return
	for child in _list_container.get_children():
		child.queue_free()
	if candidates.is_empty():
		var empty_label: Label = Label.new()
		empty_label.text = "No living pawns are eligible right now."
		empty_label.add_theme_color_override("font_color", Color(0.80, 0.58, 0.58))
		_list_container.add_child(empty_label)
		return
	for c in candidates:
		if not (c is Dictionary):
			continue
		var cand: Dictionary = c as Dictionary
		var pawn_id: int = int(cand.get("pawn_id", -1))
		var row: Button = Button.new()
		row.toggle_mode = true
		row.text = _format_candidate(cand)
		row.focus_mode = Control.FOCUS_ALL
		row.pressed.connect(func() -> void:
			set_candidate_selection(pawn_id)
		)
		_candidate_rows[pawn_id] = row
		_list_container.add_child(row)
	if not _candidate_rows.is_empty():
		if _selected_pawn_id < 0 or not _candidate_rows.has(_selected_pawn_id):
			var first_key: int = int(_candidate_rows.keys()[0])
			set_candidate_selection(first_key)
		else:
			set_candidate_selection(_selected_pawn_id)


func _format_candidate(cand: Dictionary) -> String:
	var name: String = str(cand.get("name", "Unnamed"))
	var pawn_id: int = int(cand.get("pawn_id", -1))
	var age: int = int(cand.get("age", 0))
	var region: int = int(cand.get("region", -1))
	var profession: String = str(cand.get("profession", "None"))
	var state: String = str(cand.get("state", "alive"))
	var role: String = str(cand.get("role", "citizen"))
	var priority_score: int = int(cand.get("priority_score", 0))
	var reason: String = str(cand.get("priority_reason", ""))
	var needs: String = "H %.0f | R %.0f | M %.0f" % [float(cand.get("hunger", 0.0)), float(cand.get("rest", 0.0)), float(cand.get("mood", 0.0))]
	var line: String = "%s  [#%d]  age %d  region %d  %s  | %s | %s | score %d | %s" % [name, pawn_id, age, region, profession, role, state, priority_score, needs]
	if not reason.is_empty():
		line += " | %s" % reason
	return line


func _update_action_state() -> void:
	if _confirm_button != null:
		_confirm_button.disabled = _selected_pawn_id < 0


func _on_confirm_pressed() -> void:
	if _selected_pawn_id < 0:
		return
	entry_confirmed.emit(_selected_pawn_id)


func _on_return_pressed() -> void:
	entry_confirmed.emit(-1)