extends ScrollContainer
class_name ChronicleUI

var _vbox: VBoxContainer
var _rebuilding: bool = false
var _header: HBoxContainer = null
var _summary_label: Label = null
var _visible: bool = false


func _ready() -> void:
	_vbox = VBoxContainer.new()
	_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_vbox.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	add_child(_vbox)

	# Build header with controls
	_build_header()

	if not ChronicleLog.entry_added.is_connected(_on_entry_added):
		ChronicleLog.entry_added.connect(_on_entry_added)
	if not ChronicleLog.entries_reloaded.is_connected(_on_entries_reloaded):
		ChronicleLog.entries_reloaded.connect(_on_entries_reloaded)
	_rebuilding = true
	_rebuild_ui()
	_update_summary()
	_rebuilding = false
	_scroll_to_bottom()

	# F10 toggle
	set_process_input(true)
	_visible = false
	visible = false


func _build_header() -> void:
	_header = HBoxContainer.new()
	_header.add_theme_constant_override("separation", 4)
	_vbox.add_child(_header)

	var title = Label.new()
	title.text = "CHRONICLE"
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color(0.96, 0.96, 0.98))
	_header.add_child(title)

	var export_btn = Button.new()
	export_btn.text = "Export Seed"
	export_btn.custom_minimum_size = Vector2(80, 22)
	export_btn.pressed.connect(_on_export_pressed)
	_header.add_child(export_btn)

	var summary_btn = Button.new()
	summary_btn.text = "Summary"
	summary_btn.custom_minimum_size = Vector2(60, 22)
	summary_btn.pressed.connect(_on_summary_pressed)
	_header.add_child(summary_btn)

	# Summary label (collapsible)
	_summary_label = Label.new()
	_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_summary_label.visible = false
	_summary_label.add_theme_font_size_override("font_size", 9)
	_summary_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	_vbox.add_child(_summary_label)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F10:
			toggle_visible()


func toggle_visible() -> void:
	_visible = not _visible
	visible = _visible
	if _visible:
		_update_summary()


func _on_export_pressed() -> void:
	if get_node_or_null("/root/WorldMemory") == null:
		push_warning("WorldMemory not available")
		return
	var wm = get_node_or_null("/root/WorldMemory")
	if wm and wm.has_method("export_world_seed"):
		var path = "user://world_seed_%d.json" % Time.get_unix_time_from_system()
		var ok = wm.export_world_seed(path)
		if ok:
			print("[ChronicleUI] Exported world seed to: " + path)
		else:
			push_error("[ChronicleUI] Failed to export world seed")


func _on_summary_pressed() -> void:
	_summary_label.visible = not _summary_label.visible
	_update_summary()


func _update_summary() -> void:
	if _summary_label == null or not _summary_label.visible:
		return
	var wm = get_node_or_null("/root/WorldMemory")
	if wm and wm.has_method("get_chronicle_summary"):
		_summary_label.text = wm.get_chronicle_summary()
	else:
		_summary_label.text = "WorldMemory not available"


func _on_entries_reloaded() -> void:
	_rebuilding = true
	_rebuild_ui()
	_rebuilding = false
	_scroll_to_bottom()


func _on_entry_added(entry: Dictionary) -> void:
	var label: Label = Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text = "[Tick %s] %s — %s" % [str(entry.get("tick", 0)), entry.get("zone_id", ""), entry.get("message", "")]
	var tv: Variant = entry.get("tags", PackedStringArray())
	var tag_parts: Array[String] = []
	if tv is PackedStringArray:
		for ti in range((tv as PackedStringArray).size()):
			tag_parts.append(str((tv as PackedStringArray)[ti]))
	elif tv is Array:
		for t in tv as Array:
			tag_parts.append(str(t))
	if not tag_parts.is_empty():
		var tag_s: String = tag_parts[0]
		for kj in range(1, tag_parts.size()):
			tag_s += ", " + tag_parts[kj]
		label.text += "  [%s]" % tag_s
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_vbox.add_child(label)
	if not _rebuilding:
		_scroll_to_bottom()


func _rebuild_ui() -> void:
	# Clear only entry labels, preserve header and summary
	for child in _vbox.get_children():
		if child != _header and child != _summary_label:
			child.queue_free()
	for entry in ChronicleLog.entries:
		_on_entry_added(entry)


func _scroll_to_bottom() -> void:
	call_deferred("_defer_scroll")


func _defer_scroll() -> void:
	await get_tree().process_frame
	var vbar: ScrollBar = get_v_scroll_bar()
	if vbar != null:
		scroll_vertical = int(vbar.max_value)
