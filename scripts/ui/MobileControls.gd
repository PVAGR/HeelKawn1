extends CanvasLayer

var _main: Main = null
var _camera: Camera2D = null
var _toolbar: Node = null
var _hud: Node = null
var _inventory: Node = null
var _save_load: Node = null
var _main_menu: Node = null

func _ready() -> void:
	layer = 80
	_build_ui()

func bind(main: Node) -> void:
	_main = main as Main
	if _main == null:
		return
	_camera = _main.get_node_or_null("WorldViewport/Camera") as Camera2D
	_toolbar = _main.get_node_or_null("UI_Viewport/BuildToolbar")
	_hud = _main.get_node_or_null("UI_Viewport/SurvivalHUD")
	_inventory = _main.get_node_or_null("UI_Viewport/PlayerInventory")
	_save_load = _main.get_node_or_null("UI_Viewport/SaveLoadMenu")
	_main_menu = _main.get_node_or_null("UI_Viewport/MainMenu")

func _build_ui() -> void:
	var root := Control.new()
	root.name = "MobileRoot"
	root.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	root.offset_left = 12.0
	root.offset_right = -12.0
	root.offset_top = -188.0
	root.offset_bottom = -12.0
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(panel)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.05, 0.07, 0.84)
	style.border_color = Color(0.85, 0.78, 0.40, 0.75)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", style)

	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 10)
	pad.add_theme_constant_override("margin_top", 10)
	pad.add_theme_constant_override("margin_right", 10)
	pad.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(pad)

	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	pad.add_child(grid)

	_add_button(grid, "Pause", _on_pause_pressed)
	_add_button(grid, "1x", _on_speed_1_pressed)
	_add_button(grid, "3x", _on_speed_3_pressed)
	_add_button(grid, "6x", _on_speed_6_pressed)
	_add_button(grid, "12x", _on_speed_12_pressed)
	_add_button(grid, "Zoom-", _on_zoom_out_pressed)
	_add_button(grid, "Zoom+", _on_zoom_in_pressed)
	_add_button(grid, "Home", _on_home_pressed)
	_add_button(grid, "HUD", _on_hud_pressed)
	_add_button(grid, "Build", _on_build_pressed)
	_add_button(grid, "Inv", _on_inventory_pressed)
	_add_button(grid, "Save", _on_save_pressed)
	_add_button(grid, "Menu", _on_menu_pressed)

func _show_main_menu() -> void:
	if _main_menu == null:
		return
	if _main_menu.has_method("show_menu"):
		_main_menu.call("show_menu", true)
	else:
		_main_menu.visible = true

func _on_pause_pressed() -> void:
	GameManager.toggle_pause()

func _on_speed_1_pressed() -> void:
	GameManager.set_speed_index(0)

func _on_speed_3_pressed() -> void:
	GameManager.set_speed_index(1)

func _on_speed_6_pressed() -> void:
	GameManager.set_speed_index(2)

func _on_speed_12_pressed() -> void:
	GameManager.set_speed_index(3)

func _on_zoom_out_pressed() -> void:
	if _camera != null and _camera.has_method("zoom_out"):
		_camera.call("zoom_out")

func _on_zoom_in_pressed() -> void:
	if _camera != null and _camera.has_method("zoom_in"):
		_camera.call("zoom_in")

func _on_home_pressed() -> void:
	if _camera == null or _main == null:
		return
	var world: Node = _main.get_node_or_null("WorldViewport/World")
	if world != null and _camera.has_method("reset_to_world_bounds"):
		_camera.call("reset_to_world_bounds", world)

func _on_hud_pressed() -> void:
	if _hud != null and _hud.has_method("toggle_hud"):
		_hud.call("toggle_hud")

func _on_build_pressed() -> void:
	if _toolbar != null and _toolbar.has_method("toggle_toolbar"):
		_toolbar.call("toggle_toolbar")

func _on_inventory_pressed() -> void:
	if _inventory != null and _inventory.has_method("toggle_inventory"):
		_inventory.call("toggle_inventory")

func _on_save_pressed() -> void:
	if _save_load != null and _save_load.has_method("toggle"):
		_save_load.call("toggle")

func _on_menu_pressed() -> void:
	_show_main_menu()

func _add_button(row: Container, text: String, pressed_cb: Callable) -> void:
	var btn := Button.new()
	btn.text = text
	btn.focus_mode = Control.FOCUS_NONE
	btn.custom_minimum_size = Vector2(68, 34)
	btn.pressed.connect(pressed_cb)
	row.add_child(btn)
