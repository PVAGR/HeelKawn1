extends CanvasLayer

## Cosmetic editor for the **selected / player pawn** — same `HeelKawnianData` fields NPCs use
## (circle colors today; future sprite binds here). Does not grant build powers.

signal panel_closed()

var _picker_body: ColorPickerButton
var _picker_hair: ColorPickerButton
var _picker_apparel: ColorPickerButton
var _opt_body: OptionButton
var _opt_hair: OptionButton
var _pawn: HeelKawnian = null


func _ready() -> void:
	layer = 115
	visible = false
	_build_ui()


func open_for_pawn(p: HeelKawnian) -> void:
	_pawn = p
	if p == null or not is_instance_valid(p) or p.data == null:
		visible = false
		return
	_fill_from_data(p.data)
	visible = true


func close_panel() -> void:
	visible = false
	_pawn = null
	panel_closed.emit()


func _fill_from_data(d: HeelKawnianData) -> void:
	_picker_body.color = d.color
	_picker_hair.color = d.hair_color
	_picker_apparel.color = d.apparel_color
	_opt_body.select(clampi(int(d.body_type), 0, _opt_body.item_count - 1))
	_opt_hair.select(clampi(int(d.hair_style), 0, _opt_hair.item_count - 1))


func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.45)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(dim)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -200.0
	panel.offset_top = -220.0
	panel.offset_right = 200.0
	panel.offset_bottom = 220.0
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var pstyle := StyleBoxFlat.new()
	pstyle.bg_color = Color(0.07, 0.08, 0.1, 0.96)
	pstyle.border_color = Color(0.75, 0.65, 0.35, 0.75)
	pstyle.set_border_width_all(1)
	pstyle.set_corner_radius_all(6)
	pstyle.content_margin_left = 12
	pstyle.content_margin_right = 12
	pstyle.content_margin_top = 10
	pstyle.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", pstyle)
	root.add_child(panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)

	var title := Label.new()
	title.text = "Your appearance (NPC-same data)"
	title.add_theme_font_size_override("font_size", 14)
	v.add_child(title)

	var hint := Label.new()
	hint.text = "Uses HeelKawnianData colors + body/hair enums. Select a pawn (yours is auto-picked at start)."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(0.72, 0.74, 0.78))
	v.add_child(hint)

	_picker_body = ColorPickerButton.new()
	_picker_body.text = "Body / skin tone"
	v.add_child(_picker_body)

	_picker_hair = ColorPickerButton.new()
	_picker_hair.text = "Hair color"
	v.add_child(_picker_hair)

	_picker_apparel = ColorPickerButton.new()
	_picker_apparel.text = "Apparel trim"
	v.add_child(_picker_apparel)

	_opt_body = OptionButton.new()
	var body_labels: PackedStringArray = PackedStringArray(["Slim", "Average", "Broad"])
	for i in range(body_labels.size()):
		_opt_body.add_item(body_labels[i], i)
	v.add_child(_opt_body)

	_opt_hair = OptionButton.new()
	var hair_labels: PackedStringArray = PackedStringArray(["None", "Short", "Mohawk", "Bun"])
	for i in range(hair_labels.size()):
		_opt_hair.add_item(hair_labels[i], i)
	v.add_child(_opt_hair)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var apply_btn := Button.new()
	apply_btn.text = "Apply"
	apply_btn.pressed.connect(_on_apply_pressed)
	row.add_child(apply_btn)
	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.pressed.connect(close_panel)
	row.add_child(close_btn)
	v.add_child(row)


func _on_apply_pressed() -> void:
	if _pawn == null or not is_instance_valid(_pawn) or _pawn.data == null:
		close_panel()
		return
	var d: HeelKawnianData = _pawn.data
	d.color = _picker_body.color
	d.hair_color = _picker_hair.color
	d.apparel_color = _picker_apparel.color
	d.body_type = _opt_body.get_selected_id()
	d.hair_style = _opt_hair.get_selected_id()
	_pawn.queue_redraw()
	close_panel()
