class_name MainMenu
extends CanvasLayer

## Title screen shown on game start. "HEELKAWN" title, New Game / Load Game /
## Settings / Quit buttons. Semi-transparent overlay over the running world.

signal new_game_pressed
signal load_game_pressed
signal settings_pressed
signal quit_pressed

const BG_COLOR: Color = Color(0.03, 0.04, 0.06, 0.88)
const TITLE_COLOR: Color = Color(0.85, 0.78, 0.40, 1.0)
const SUBTITLE_COLOR: Color = Color(0.6, 0.58, 0.50, 0.7)
const BTN_COLOR: Color = Color(0.12, 0.13, 0.18, 0.90)
const BTN_HOVER: Color = Color(0.18, 0.19, 0.25, 0.95)
const BTN_TEXT: Color = Color(0.88, 0.84, 0.72, 1.0)

var _bg: ColorRect
var _visible: bool = true


func _ready() -> void:
	layer = 25  # Above everything

	_bg = ColorRect.new()
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.color = BG_COLOR
	_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_bg)

	var center: VBoxContainer = VBoxContainer.new()
	center.set_anchors_preset(Control.PRESET_CENTER)
	center.grow_horizontal = Control.GROW_DIRECTION_BOTH
	center.grow_vertical = Control.GROW_DIRECTION_BOTH
	center.offset_left = -150.0
	center.offset_top = -120.0
	center.offset_right = 150.0
	center.offset_bottom = 120.0
	center.add_theme_constant_override("separation", 12)
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.mouse_filter = Control.MOUSE_FILTER_STOP

	# Title
	var title: Label = Label.new()
	title.text = "HEELKAWN"
	title.add_theme_font_size_override("font_size", 36)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", TITLE_COLOR)
	center.add_child(title)

	# Subtitle
	var subtitle: Label = Label.new()
	subtitle.text = "A Myth Engine"
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override("font_color", SUBTITLE_COLOR)
	center.add_child(subtitle)

	# Spacer
	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	center.add_child(spacer)

	# Buttons
	var btn_vbox: VBoxContainer = VBoxContainer.new()
	btn_vbox.add_theme_constant_override("separation", 8)
	btn_vbox.alignment = BoxContainer.ALIGNMENT_CENTER

	var new_btn: Button = _make_menu_button("New Game")
	new_btn.pressed.connect(func(): new_game_pressed.emit(); hide_menu())
	btn_vbox.add_child(new_btn)

	var load_btn: Button = _make_menu_button("Load Game")
	load_btn.pressed.connect(func(): load_game_pressed.emit())
	btn_vbox.add_child(load_btn)

	var settings_btn: Button = _make_menu_button("Settings")
	settings_btn.pressed.connect(func(): settings_pressed.emit())
	btn_vbox.add_child(settings_btn)

	var quit_btn: Button = _make_menu_button("Quit")
	quit_btn.pressed.connect(func(): quit_pressed.emit())
	btn_vbox.add_child(quit_btn)

	center.add_child(btn_vbox)

	# Version
	var ver: Label = Label.new()
	ver.text = "v0.5 — Phase 5: Emergent Life"
	ver.add_theme_font_size_override("font_size", 9)
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ver.add_theme_color_override("font_color", MUTED_COLOR)
	center.add_child(ver)

	add_child(center)


const MUTED_COLOR: Color = Color(0.4, 0.4, 0.4, 0.5)


func show_menu() -> void:
	_visible = true
	_bg.visible = true
	# Show all children except bg
	for child in get_children():
		if child != _bg:
			child.visible = true


func hide_menu() -> void:
	_visible = false
	_bg.visible = false
	for child in get_children():
		if child != _bg:
			child.visible = false


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE and not _visible:
			show_menu()
			get_viewport().set_input_as_handled()


func _make_menu_button(text: String) -> Button:
	var btn: Button = Button.new()
	btn.text = text
	btn.add_theme_font_size_override("font_size", 15)
	btn.add_theme_color_override("font_color", BTN_TEXT)
	btn.custom_minimum_size = Vector2(200, 40)
	var style := StyleBoxFlat.new()
	style.bg_color = BTN_COLOR
	style.border_color = Color(0.4, 0.38, 0.3, 0.3)
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_width_left = 1
	style.border_width_right = 1
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	btn.add_theme_stylebox_override("normal", style)

	var hover_style := style.duplicate() as StyleBoxFlat
	hover_style.bg_color = BTN_HOVER
	hover_style.border_color = Color(0.85, 0.78, 0.40, 0.50)
	btn.add_theme_stylebox_override("hover", hover_style)

	var pressed_style := style.duplicate() as StyleBoxFlat
	pressed_style.bg_color = Color(0.2, 0.2, 0.28, 0.95)
	btn.add_theme_stylebox_override("pressed", pressed_style)

	return btn
