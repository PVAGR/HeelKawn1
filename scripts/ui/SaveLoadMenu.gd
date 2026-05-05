class_name SaveLoadMenu
extends CanvasLayer

## Save/Load slot menu. Shows 3 save slots with metadata.
## Accessible via F4 hotkey or ESC menu.

signal save_requested(slot: int)
signal load_requested(slot: int)
signal new_game_requested
signal close_requested

const SLOT_COUNT: int = 3
const BG_COLOR: Color = Color(0.05, 0.06, 0.08, 0.92)
const BORDER_COLOR: Color = Color(0.85, 0.78, 0.40, 0.50)
const SLOT_BG: Color = Color(0.08, 0.09, 0.12, 0.80)
const SLOT_HOVER: Color = Color(0.12, 0.13, 0.18, 0.90)
const SLOT_EMPTY_BG: Color = Color(0.06, 0.07, 0.09, 0.60)
const TEXT_COLOR: Color = Color(0.88, 0.84, 0.72, 1.0)
const MUTED_COLOR: Color = Color(0.5, 0.5, 0.5, 0.6)

var _panel: PanelContainer
var _slot_rows: Array[PanelContainer] = []
var _current_slot: int = 1  # Last used slot


func _ready() -> void:
	layer = 15
	visible = false

	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", _make_panel_style())
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP

	# Center on screen
	_panel.anchor_left = 0.5
	_panel.anchor_top = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_bottom = 0.5
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_panel.offset_left = -200.0
	_panel.offset_top = -180.0
	_panel.offset_right = 200.0
	_panel.offset_bottom = 180.0

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)

	# Title
	var title: Label = Label.new()
	title.text = "Save / Load"
	title.add_theme_font_size_override("font_size", 18)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	# Separator
	var sep: HSeparator = HSeparator.new()
	vbox.add_child(sep)

	# Slot rows
	for slot in range(1, SLOT_COUNT + 1):
		var row: PanelContainer = _make_slot_row(slot)
		_slot_rows.append(row)
		vbox.add_child(row)

	# Bottom buttons
	var btn_hbox: HBoxContainer = HBoxContainer.new()
	btn_hbox.add_theme_constant_override("separation", 8)
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER

	var new_btn: Button = Button.new()
	new_btn.text = "New Game"
	new_btn.pressed.connect(func(): new_game_requested.emit(); visible = false)
	btn_hbox.add_child(new_btn)

	var back_btn: Button = Button.new()
	back_btn.text = "Back"
	back_btn.pressed.connect(func(): visible = false; close_requested.emit())
	btn_hbox.add_child(back_btn)

	vbox.add_child(btn_hbox)

	margin.add_child(vbox)
	_panel.add_child(margin)
	add_child(_panel)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F4:
			toggle()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE and visible:
			visible = false
			close_requested.emit()
			get_viewport().set_input_as_handled()


func toggle() -> void:
	visible = not visible
	if visible:
		_refresh_slots()


func _refresh_slots() -> void:
	for i in range(SLOT_COUNT):
		var slot: int = i + 1
		var meta: Dictionary = GameSave.get_slot_metadata(slot)
		_update_slot_row(i, slot, meta)


func _make_slot_row(slot: int) -> PanelContainer:
	var row: PanelContainer = PanelContainer.new()
	row.add_theme_stylebox_override("panel", _make_slot_style())
	row.custom_minimum_size = Vector2(360, 60)

	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)

	# Slot number
	var num_label: Label = Label.new()
	num_label.name = "SlotNum"
	num_label.text = "Slot %d" % slot
	num_label.add_theme_font_size_override("font_size", 14)
	num_label.custom_minimum_size = Vector2(60, 0)
	hbox.add_child(num_label)

	# Info
	var info: VBoxContainer = VBoxContainer.new()
	info.name = "Info"
	info.add_theme_constant_override("separation", 2)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var name_label: Label = Label.new()
	name_label.name = "NameLabel"
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.text = "Empty"
	info.add_child(name_label)

	var detail_label: Label = Label.new()
	detail_label.name = "DetailLabel"
	detail_label.add_theme_font_size_override("font_size", 10)
	detail_label.text = ""
	detail_label.add_theme_color_override("font_color", MUTED_COLOR)
	info.add_child(detail_label)

	hbox.add_child(info)

	# Buttons
	var save_btn: Button = Button.new()
	save_btn.name = "SaveBtn"
	save_btn.text = "Save"
	save_btn.add_theme_font_size_override("font_size", 11)
	save_btn.custom_minimum_size = Vector2(55, 28)
	save_btn.pressed.connect(func(): _on_save_slot(slot))
	hbox.add_child(save_btn)

	var load_btn: Button = Button.new()
	load_btn.name = "LoadBtn"
	load_btn.text = "Load"
	load_btn.add_theme_font_size_override("font_size", 11)
	load_btn.custom_minimum_size = Vector2(55, 28)
	load_btn.pressed.connect(func(): _on_load_slot(slot))
	hbox.add_child(load_btn)

	var del_btn: Button = Button.new()
	del_btn.name = "DelBtn"
	del_btn.text = "✕"
	del_btn.add_theme_font_size_override("font_size", 11)
	del_btn.custom_minimum_size = Vector2(28, 28)
	del_btn.pressed.connect(func(): _on_delete_slot(slot))
	hbox.add_child(del_btn)

	row.add_child(hbox)
	return row


func _update_slot_row(row_idx: int, slot: int, meta: Dictionary) -> void:
	if row_idx >= _slot_rows.size():
		return
	var row: PanelContainer = _slot_rows[row_idx]
	var info: VBoxContainer = row.find_child("Info") as VBoxContainer
	if info == null:
		return
	var name_label: Label = info.get_node("NameLabel") as Label
	var detail_label: Label = info.get_node("DetailLabel") as Label
	var load_btn: Button = row.find_child("LoadBtn") as Button
	var del_btn: Button = row.find_child("DelBtn") as Button

	if bool(meta.get("empty", true)):
		name_label.text = "Empty Slot"
		name_label.add_theme_color_override("font_color", MUTED_COLOR)
		detail_label.text = "No save data"
		load_btn.disabled = true
		del_btn.disabled = true
		row.add_theme_stylebox_override("panel", _make_slot_style(SLOT_EMPTY_BG))
	else:
		name_label.text = str(meta.get("settlement_name", "Unknown"))
		name_label.add_theme_color_override("font_color", TEXT_COLOR)
		var tick: int = int(meta.get("tick", 0))
		var pawns: int = int(meta.get("pawn_count", 0))
		var ts: String = str(meta.get("timestamp", ""))
		detail_label.text = "Tick %d · %d pawns · %s" % [tick, pawns, ts]
		load_btn.disabled = false
		del_btn.disabled = false
		row.add_theme_stylebox_override("panel", _make_slot_style(SLOT_BG))


func _on_save_slot(slot: int) -> void:
	_current_slot = slot
	save_requested.emit(slot)
	_refresh_slots()


func _on_load_slot(slot: int) -> void:
	_current_slot = slot
	load_requested.emit(slot)
	visible = false


func _on_delete_slot(slot: int) -> void:
	var path: String = GameSave.get_save_path(slot)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	_refresh_slots()


func _make_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = BG_COLOR
	style.border_color = BORDER_COLOR
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_width_left = 2
	style.border_width_right = 2
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	return style


func _make_slot_style(bg: Color = SLOT_BG) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = Color(0.4, 0.38, 0.3, 0.3)
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_width_left = 1
	style.border_width_right = 1
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style
