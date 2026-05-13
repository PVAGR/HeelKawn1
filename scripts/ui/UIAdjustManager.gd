extends Node
class_name UIAdjustManager

const SCALE_STEPS: Array[float] = [0.75, 1.0, 1.25, 1.5]

var _edit_mode: bool = false
var _entries: Dictionary = {}
var _dragging_id: int = -1
var _drag_offset: Vector2 = Vector2.ZERO

func set_edit_mode(enabled: bool) -> void:
	_edit_mode = enabled
	for id_key in _entries.keys():
		var entry: Dictionary = _entries[id_key]
		var chrome: Control = entry.get("chrome")
		if chrome != null:
			chrome.visible = enabled

func is_edit_mode() -> bool:
	return _edit_mode

func register_container(target: Control) -> void:
	if target == null or not is_instance_valid(target):
		return
	var id_key: int = target.get_instance_id()
	if _entries.has(id_key):
		return
	var chrome: PanelContainer = _build_chrome(target)
	target.add_child(chrome)
	chrome.visible = _edit_mode
	_entries[id_key] = {
		"target": target,
		"chrome": chrome,
		"collapsed": false,
		"scale_idx": 1,
		"saved_size": target.size,
		"saved_visibility": {},
	}

func _build_chrome(target: Control) -> PanelContainer:
	var chrome := PanelContainer.new()
	chrome.name = "UIAdjustChrome"
	chrome.z_index = 4096
	chrome.mouse_filter = Control.MOUSE_FILTER_STOP
	chrome.anchor_left = 1.0
	chrome.anchor_right = 1.0
	chrome.anchor_top = 0.0
	chrome.anchor_bottom = 0.0
	chrome.offset_left = -114.0
	chrome.offset_right = -6.0
	chrome.offset_top = 6.0
	chrome.offset_bottom = 28.0

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.09, 0.9)
	style.border_color = Color(0.9, 0.8, 0.45, 0.7)
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	chrome.add_theme_stylebox_override("panel", style)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	chrome.add_child(row)

	var drag_btn := Button.new()
	drag_btn.text = "Drag"
	drag_btn.focus_mode = Control.FOCUS_NONE
	drag_btn.custom_minimum_size = Vector2(44, 20)
	drag_btn.button_down.connect(_on_drag_start.bind(target))
	drag_btn.button_up.connect(_on_drag_end.bind(target))
	row.add_child(drag_btn)

	var size_btn := Button.new()
	size_btn.text = "Size"
	size_btn.focus_mode = Control.FOCUS_NONE
	size_btn.custom_minimum_size = Vector2(30, 20)
	size_btn.pressed.connect(_on_cycle_size.bind(target))
	row.add_child(size_btn)

	var min_btn := Button.new()
	min_btn.text = "_"
	min_btn.focus_mode = Control.FOCUS_NONE
	min_btn.custom_minimum_size = Vector2(20, 20)
	min_btn.pressed.connect(_on_toggle_minimize.bind(target))
	row.add_child(min_btn)

	var reset_btn := Button.new()
	reset_btn.text = "R"
	reset_btn.focus_mode = Control.FOCUS_NONE
	reset_btn.custom_minimum_size = Vector2(20, 20)
	reset_btn.pressed.connect(_on_reset.bind(target))
	row.add_child(reset_btn)

	return chrome

func _on_drag_start(target: Control) -> void:
	if not _edit_mode or target == null:
		return
	_dragging_id = target.get_instance_id()
	_drag_offset = target.global_position - target.get_global_mouse_position()

func _on_drag_end(_target: Control) -> void:
	_dragging_id = -1

func _process(_delta: float) -> void:
	if _dragging_id < 0:
		return
	if not _entries.has(_dragging_id):
		_dragging_id = -1
		return
	var target: Control = _entries[_dragging_id].get("target")
	if target == null or not is_instance_valid(target):
		_dragging_id = -1
		return
	target.global_position = target.get_global_mouse_position() + _drag_offset

func _on_cycle_size(target: Control) -> void:
	if target == null:
		return
	var id_key: int = target.get_instance_id()
	if not _entries.has(id_key):
		return
	var entry: Dictionary = _entries[id_key]
	var idx: int = int(entry.get("scale_idx", 1))
	idx = (idx + 1) % SCALE_STEPS.size()
	entry["scale_idx"] = idx
	target.scale = Vector2.ONE * float(SCALE_STEPS[idx])
	_entries[id_key] = entry

func _on_toggle_minimize(target: Control) -> void:
	if target == null:
		return
	var id_key: int = target.get_instance_id()
	if not _entries.has(id_key):
		return
	var entry: Dictionary = _entries[id_key]
	var collapsed: bool = bool(entry.get("collapsed", false))
	var chrome: Control = entry.get("chrome")
	if not collapsed:
		entry["saved_size"] = target.size
		var vis: Dictionary = {}
		for child in target.get_children():
			if child == chrome:
				continue
			if child is CanvasItem:
				vis[child.get_instance_id()] = child.visible
				child.visible = false
		target.size = Vector2(maxf(160.0, target.size.x), 30.0)
		entry["saved_visibility"] = vis
		entry["collapsed"] = true
	else:
		var vis_restore: Dictionary = entry.get("saved_visibility", {})
		for child in target.get_children():
			if child == chrome:
				continue
			if child is CanvasItem:
				var child_id: int = child.get_instance_id()
				if vis_restore.has(child_id):
					child.visible = bool(vis_restore[child_id])
		target.size = entry.get("saved_size", target.size)
		entry["collapsed"] = false
	_entries[id_key] = entry

func _on_reset(target: Control) -> void:
	if target == null:
		return
	var id_key: int = target.get_instance_id()
	if not _entries.has(id_key):
		return
	var entry: Dictionary = _entries[id_key]
	entry["scale_idx"] = 1
	target.scale = Vector2.ONE
	if bool(entry.get("collapsed", false)):
		_on_toggle_minimize(target)
	_entries[id_key] = entry
