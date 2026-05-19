class_name TradeOverviewPanel
extends CanvasLayer

## Player-facing trade overview showing active caravan routes,
## goods in transit, and trade statistics. Built entirely in code
## so no .tscn scene file is needed.

signal closed

var _panel: PanelContainer = null
var _stats_label: Label = null
var _routes_container: VBoxContainer = null
var _visible: bool = false


func _init() -> void:
	layer = 80
	_build_ui()


func _ready() -> void:
	_panel.visible = false


func show_panel() -> void:
	_visible = true
	_panel.visible = true
	_refresh()


func hide_panel() -> void:
	_visible = false
	_panel.visible = false


func toggle() -> void:
	if _visible:
		hide_panel()
	else:
		show_panel()


func _unhandled_key_input(event: InputEvent) -> void:
	if not _visible:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		hide_panel()
		closed.emit()
		get_viewport().set_input_as_handled()


func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(520, 360)

	var pstyle := StyleBoxFlat.new()
	pstyle.bg_color = Color(0.04, 0.05, 0.07, 0.94)
	pstyle.border_color = Color(0.55, 0.72, 0.35, 0.85)
	pstyle.set_border_width_all(2)
	pstyle.set_corner_radius_all(8)
	_panel.add_theme_stylebox_override("panel", pstyle)
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	# Header
	var header := HBoxContainer.new()
	var title := Label.new()
	title.text = "Trade Overview"
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", Color(0.94, 0.85, 0.63, 1.0))
	header.add_child(title)
	header.add_spacer(true)
	var close_btn := Button.new()
	close_btn.text = "X"
	close_btn.pressed.connect(_on_close_pressed)
	header.add_child(close_btn)
	vbox.add_child(header)

	# Stats
	var stats_container := PanelContainer.new()
	var sstyle := StyleBoxFlat.new()
	sstyle.bg_color = Color(0.07, 0.08, 0.10, 0.95)
	sstyle.border_color = Color(0.35, 0.45, 0.25, 0.4)
	sstyle.set_border_width_all(1)
	sstyle.set_corner_radius_all(4)
	stats_container.add_theme_stylebox_override("panel", sstyle)

	_stats_label = Label.new()
	_stats_label.add_theme_font_size_override("font_size", 10)
	_stats_label.add_theme_color_override("font_color", Color(0.65, 0.62, 0.58, 1.0))
	stats_container.add_child(_stats_label)
	vbox.add_child(stats_container)

	# Routes list
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 200)
	vbox.add_child(scroll)

	_routes_container = VBoxContainer.new()
	_routes_container.add_theme_constant_override("separation", 4)
	scroll.add_child(_routes_container)


func _on_close_pressed() -> void:
	hide_panel()
	closed.emit()


func _refresh() -> void:
	var trade_mem: Node = EconomyManager.get_trade_memory()
	if trade_mem == null:
		return
	var s: Dictionary = trade_mem.get_stats()
	_stats_label.text = "Routes created: %d  |  Active: %d  |  Completed: %d  |  Goods traded: %d  |  Knowledge spread: %d" % [
		s.get("total_routes", 0),
		s.get("active_routes", 0),
		s.get("completed_routes", 0),
		s.get("total_goods_traded", 0),
		s.get("knowledge_spread_count", 0),
	]

	for child in _routes_container.get_children():
		child.queue_free()

	var routes: Array[Dictionary] = trade_mem.get_active_routes()
	if routes.is_empty():
		var empty_label := Label.new()
		empty_label.text = "No active trade routes. Build a Trading Post and establish settlements to begin trade."
		empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_label.add_theme_color_override("font_color", Color(0.65, 0.62, 0.58, 1.0))
		_routes_container.add_child(empty_label)
		return

	for route in routes:
		_routes_container.add_child(_build_route_row(route))


func _build_route_row(route: Dictionary) -> Control:
	var row := PanelContainer.new()
	var row_style := StyleBoxFlat.new()
	row_style.bg_color = Color(0.09, 0.10, 0.13, 0.96)
	row_style.border_color = Color(0.35, 0.45, 0.25, 0.6)
	row_style.set_border_width_all(1)
	row_style.set_corner_radius_all(4)
	row.add_theme_stylebox_override("panel", row_style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	row.add_child(hbox)

	var from_name: String = _settlement_name(route.get("from_settlement", -1))
	var to_name: String = _settlement_name(route.get("to_settlement", -1))

	var label := Label.new()
	label.text = "%s  →  %s" % [from_name, to_name]
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color(0.82, 0.80, 0.76, 1.0))
	label.custom_minimum_size = Vector2(160, 0)
	hbox.add_child(label)

	var pct: float = route.get("progress", 0.0) * 100.0
	var goods: Dictionary = route.get("goods", {})
	var parts: Array[String] = []
	for item in goods.keys():
		parts.append("%s×%d" % [item.capitalize(), goods[item]])
	var goods_str: String = ", ".join(parts)

	var progress_label := Label.new()
	progress_label.text = "%d%%  [%s]" % [pct, goods_str]
	progress_label.add_theme_font_size_override("font_size", 10)
	progress_label.add_theme_color_override("font_color", Color(0.55, 0.72, 0.35, 1.0))
	hbox.add_child(progress_label)
	return row


func _settlement_name(region_key: int) -> String:
	if SettlementMemory == null:
		return "Region %d" % region_key
	var st: Variant = SettlementMemory.get_settlement_at_region(region_key)
	if st is Dictionary:
		return str(st.get("name", "Settlement"))
	return "Region %d" % region_key
