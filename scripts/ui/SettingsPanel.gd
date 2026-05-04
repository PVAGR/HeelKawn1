extends CanvasLayer
## In-game Settings panel (ESC). Builds UI from GameSettings.SCHEMA so new
## settings appear automatically. Pauses the game while open, resumes on close.

const PANEL_W: int = 420
const PANEL_H: int = 720
const PAD: int = 12
const SECTION_GAP: int = 18
const ROW_H: int = 32
const LABEL_W: int = 160

const BG_COLOR: Color = Color(0.06, 0.07, 0.09, 0.97)
const BORDER_COLOR: Color = Color(0.70, 0.60, 0.30, 0.90)
const SECTION_COLOR: Color = Color(0.85, 0.78, 0.40, 0.90)
const LABEL_COLOR: Color = Color(0.88, 0.88, 0.88, 1.0)
const VALUE_COLOR: Color = Color(1.0, 0.92, 0.18, 1.0)

var _root: Control = null
var _dim: ColorRect = null
var _panel: PanelContainer = null
var _scroll: ScrollContainer = null
var _content: VBoxContainer = null
var _close_btn: Button = null
var _resume_btn: Button = null
var _was_paused: bool = false
var _widgets: Dictionary = {}  # key -> Control (for live updates)


func _ready() -> void:
	layer = 120
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	if GameSettings != null:
		GameSettings.setting_changed.connect(_on_setting_changed)


func open() -> void:
	if visible:
		return
	_was_paused = GameManager.is_paused
	if not _was_paused:
		GameManager.toggle_pause()
	visible = true
	_sync_widgets_from_settings()


func close() -> void:
	if not visible:
		return
	visible = false
	if not _was_paused and GameManager.is_paused:
		GameManager.toggle_pause()


func toggle() -> void:
	if visible:
		close()
	else:
		open()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == Key.KEY_ESCAPE:
			close()
			get_viewport().set_input_as_handled()


# ────────────────────────── UI construction ──────────────────────────

func _build_ui() -> void:
	_root = Control.new()
	_root.name = "SettingsRoot"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	# Dim backdrop
	_dim = ColorRect.new()
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.color = Color(0, 0, 0, 0.55)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_dim)

	# Centered panel
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.offset_left = -PANEL_W / 2.0
	_panel.offset_top = -PANEL_H / 2.0
	_panel.offset_right = PANEL_W / 2.0
	_panel.offset_bottom = PANEL_H / 2.0
	var pstyle: StyleBoxFlat = StyleBoxFlat.new()
	pstyle.bg_color = BG_COLOR
	pstyle.border_color = BORDER_COLOR
	pstyle.set_border_width_all(2)
	pstyle.set_corner_radius_all(6)
	pstyle.content_margin_left = PAD
	pstyle.content_margin_right = PAD
	pstyle.content_margin_top = PAD
	pstyle.content_margin_bottom = PAD
	_panel.add_theme_stylebox_override("panel", pstyle)
	_root.add_child(_panel)

	# Inner VBox: title + scroll + buttons
	var inner: VBoxContainer = VBoxContainer.new()
	inner.add_theme_constant_override("separation", 8)
	_panel.add_child(inner)

	# Title row
	var title_row: HBoxContainer = HBoxContainer.new()
	var title: Label = _make_label("Settings", SECTION_COLOR, 18)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title_row.add_child(title)
	title_row.add_spacer(true)
	_close_btn = _make_button("X", _on_close_pressed)
	_close_btn.custom_minimum_size = Vector2(28, 28)
	title_row.add_child(_close_btn)
	inner.add_child(title_row)

	# Scrollable content
	_scroll = ScrollContainer.new()
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	inner.add_child(_scroll)

	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 4)
	_scroll.add_child(_content)

	# Build sections from schema
	if GameSettings != null:
		for section in GameSettings.get_sections():
			_build_section(section)

	# Resume button
	inner.add_child(HSeparator.new())
	var btn_row: HBoxContainer = HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_resume_btn = _make_button("Resume", _on_close_pressed)
	_resume_btn.custom_minimum_size = Vector2(160, 36)
	btn_row.add_child(_resume_btn)
	inner.add_child(btn_row)


func _build_section(section: String) -> void:
	# Section heading
	var heading: Label = _make_label(section, SECTION_COLOR, 14)
	_content.add_child(heading)

	# Separator
	var sep: HSeparator = HSeparator.new()
	sep.add_theme_stylebox_override("separator", _make_sep_style())
	_content.add_child(sep)

	# Settings rows
	if GameSettings == null:
		return
	for entry in GameSettings.get_entries_for_section(section):
		_build_row(entry)

	# Gap after section
	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0, SECTION_GAP)
	_content.add_child(spacer)


func _build_row(entry: Dictionary) -> void:
	var key: String = str(entry["key"])
	var type: String = str(entry.get("type", "bool"))
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	# Label
	var label: Label = _make_label(str(entry.get("label", key)), LABEL_COLOR, 12)
	label.custom_minimum_size = Vector2(LABEL_W, 0)
	row.add_child(label)

	# Widget
	match type:
		"bool":
			var cb: CheckBox = CheckBox.new()
			cb.button_pressed = bool(GameSettings.get_value(key))
			cb.toggled.connect(func(_v): _on_widget_bool(key, cb))
			row.add_child(cb)
			_widgets[key] = cb
		"int":
			var hbox: HBoxContainer = HBoxContainer.new()
			var slider: HSlider = HSlider.new()
			slider.min_value = float(entry.get("min", 0))
			slider.max_value = float(entry.get("max", 100))
			slider.step = float(entry.get("step", 1))
			slider.value = float(int(GameSettings.get_value(key)))
			slider.custom_minimum_size = Vector2(140, 0)
			slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var val_label: Label = _make_label(str(int(GameSettings.get_value(key))), VALUE_COLOR, 12)
			val_label.custom_minimum_size = Vector2(40, 0)
			val_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			val_label.name = "ValueLabel"
			slider.value_changed.connect(func(_v): _on_widget_int(key, slider, val_label))
			hbox.add_child(slider)
			hbox.add_child(val_label)
			row.add_child(hbox)
			_widgets[key] = {"slider": slider, "label": val_label}
		"float":
			var hbox: HBoxContainer = HBoxContainer.new()
			var slider: HSlider = HSlider.new()
			slider.min_value = float(entry.get("min", 0.0))
			slider.max_value = float(entry.get("max", 1.0))
			slider.step = float(entry.get("step", 0.01))
			slider.value = float(GameSettings.get_value(key))
			slider.custom_minimum_size = Vector2(140, 0)
			slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var val_label: Label = _make_label("%.2f" % float(GameSettings.get_value(key)), VALUE_COLOR, 12)
			val_label.custom_minimum_size = Vector2(40, 0)
			val_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			val_label.name = "ValueLabel"
			slider.value_changed.connect(func(_v): _on_widget_float(key, slider, val_label))
			hbox.add_child(slider)
			hbox.add_child(val_label)
			row.add_child(hbox)
			_widgets[key] = {"slider": slider, "label": val_label}
		"enum":
			var opts: OptionButton = OptionButton.new()
			for opt_label in entry.get("options", []):
				opts.add_item(str(opt_label))
			opts.selected = int(GameSettings.get_value(key))
			opts.item_selected.connect(func(_idx): _on_widget_enum(key, opts))
			row.add_child(opts)
			_widgets[key] = opts

	_content.add_child(row)


# ────────────────────────── Widget callbacks ──────────────────────────

func _on_widget_bool(key: String, cb: CheckBox) -> void:
	GameSettings.set_value(key, cb.button_pressed)

func _on_widget_int(key: String, slider: HSlider, val_label: Label) -> void:
	var v: int = int(slider.value)
	val_label.text = str(v)
	GameSettings.set_value(key, v)

func _on_widget_float(key: String, slider: HSlider, val_label: Label) -> void:
	var v: float = slider.value
	val_label.text = "%.2f" % v
	GameSettings.set_value(key, v)

func _on_widget_enum(key: String, opts: OptionButton) -> void:
	GameSettings.set_value(key, opts.selected)

func _on_close_pressed() -> void:
	close()


# ────────────────────────── Sync from settings ──────────────────────────

func _sync_widgets_from_settings() -> void:
	if GameSettings == null:
		return
	for key in _widgets:
		var w: Variant = _widgets[key]
		var val: Variant = GameSettings.get_value(key)
		if w is CheckBox:
			w.button_pressed = bool(val)
		elif w is OptionButton:
			w.selected = int(val)
		elif w is Dictionary:
			var slider: HSlider = w.get("slider") as HSlider
			var label: Label = w.get("label") as Label
			if slider != null:
				slider.value = float(val)
			if label != null:
				if val is float:
					label.text = "%.2f" % float(val)
				else:
					label.text = str(val)


func _on_setting_changed(key: String, _new_value: Variant) -> void:
	# If the change came from outside (e.g. code), sync the widget
	if not _widgets.has(key):
		return
	var w: Variant = _widgets[key]
	if w is CheckBox:
		w.button_pressed = bool(GameSettings.get_value(key))
	elif w is OptionButton:
		w.selected = int(GameSettings.get_value(key))
	elif w is Dictionary:
		var slider: HSlider = w.get("slider") as HSlider
		var label: Label = w.get("label") as Label
		if slider != null:
			slider.value = float(GameSettings.get_value(key))
		if label != null:
			var v: Variant = GameSettings.get_value(key)
			if v is float:
				label.text = "%.2f" % float(v)
			else:
				label.text = str(v)


# ────────────────────────── Helpers ──────────────────────────

func _make_label(text: String, color: Color, font_size: int) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_size_override("font_size", font_size)
	return l


func _make_button(text: String, callback: Callable) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.pressed.connect(callback)
	return b


func _make_sep_style() -> StyleBoxFlat:
	var s: StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = Color(0.5, 0.45, 0.25, 0.4)
	s.content_margin_top = 2
	s.content_margin_bottom = 2
	return s
