extends ScrollContainer
class_name ChronicleUI

var _vbox: VBoxContainer
var _rebuilding: bool = false
var _header: HBoxContainer = null
var _summary_label: Label = null
var _visible: bool = false
var _export_history_vbox: VBoxContainer = null
var _export_status_label: Label = null


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
	export_btn.text = "Export Chronicle"
	export_btn.custom_minimum_size = Vector2(100, 22)
	export_btn.pressed.connect(_on_export_chronicle_pressed)
	_header.add_child(export_btn)

	var summary_btn = Button.new()
	summary_btn.text = "Summary"
	summary_btn.custom_minimum_size = Vector2(60, 22)
	summary_btn.pressed.connect(_on_summary_pressed)
	_header.add_child(summary_btn)

	var history_btn = Button.new()
	history_btn.text = "Export History"
	history_btn.custom_minimum_size = Vector2(110, 22)
	history_btn.pressed.connect(_on_history_pressed)
	_header.add_child(history_btn)

	_export_status_label = Label.new()
	_export_status_label.visible = false
	_export_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_export_status_label.add_theme_font_size_override("font_size", 9)
	_vbox.add_child(_export_status_label)

	# Summary label (collapsible)
	_summary_label = Label.new()
	_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_summary_label.visible = false
	_summary_label.add_theme_font_size_override("font_size", 9)
	_summary_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	_vbox.add_child(_summary_label)

	# Export history panel (hidden by default)
	_export_history_vbox = VBoxContainer.new()
	_export_history_vbox.visible = false
	_export_history_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_vbox.add_child(_export_history_vbox)


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
	# Legacy seed export left intact
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


func _on_export_chronicle_pressed() -> void:
	var wm: Node = get_node_or_null("/root/WorldMemory")
	if wm == null:
		push_warning("[ChronicleUI] WorldMemory not available")
		_flash_export_status("Export failed: WorldMemory missing", false)
		return
	var da := DirAccess.open("user://")
	if da == null:
		push_error("[ChronicleUI] Cannot open user:// for chronicle export")
		_flash_export_status("Export failed: cannot open user storage", false)
		return
	var mk_err: Error = da.make_dir_recursive("exports")
	if mk_err != OK:
		push_error("[ChronicleUI] Could not create user://exports (%s)" % error_string(mk_err))
		_flash_export_status("Export failed: could not create exports folder", false)
		return
	var tick: int = 0
	if Engine.has_singleton("GameManager") and GameManager != null:
		tick = GameManager.tick_count
	var path: String = "user://exports/chronicle_%d.md" % tick
	var body: String = _build_chronicle_narrative_markdown(wm)
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		var ferr: Error = FileAccess.get_open_error()
		push_error("[ChronicleUI] Failed to write %s (%s)" % [path, error_string(ferr)])
		_flash_export_status("Export failed: cannot write file", false)
		return
	f.store_string(body)
	f.close()
	print("[ChronicleUI] Exported chronicle narrative to: ", ProjectSettings.globalize_path(path))
	_flash_export_status("Saved chronicle_%d.md under user://exports/" % tick, true)
	_refresh_export_history()


func _build_chronicle_narrative_markdown(wm: Node) -> String:
	var parts: Array[String] = []
	parts.append("# HeelKawn — Chronicle export")
	parts.append("")
	if wm.has_method("get_chronicle_summary"):
		parts.append("## World snapshot")
		parts.append(wm.get_chronicle_summary())
		parts.append("")
	var sm: Node = get_node_or_null("/root/SettlementMemory")
	if sm != null and sm.has_method("get_settlements"):
		var sts: Array = sm.get_settlements()
		if not sts.is_empty():
			parts.append("## Settlements")
			for st_any in sts:
				if st_any is Dictionary:
					var st: Dictionary = st_any as Dictionary
					var zid: String = str(int(st.get("center_region", -1)))
					var st_state: String = str(st.get("state", ""))
					parts.append("- **Zone %s** — %s" % [zid, st_state])
			parts.append("")
	if wm.has_method("build_readable_chronicle_summary"):
		parts.append("## World memory (events)")
		parts.append("```")
		parts.append(wm.build_readable_chronicle_summary(28))
		parts.append("```")
		parts.append("")
	parts.append("## Player chronicle log")
	if ChronicleLog.entries.is_empty():
		parts.append("_(no entries)_")
	else:
		for e in ChronicleLog.entries:
			parts.append(
					"- [Tick %s] **%s** — %s"
					% [str(e.get("tick", 0)), str(e.get("zone_id", "")), str(e.get("message", ""))]
			)
	return "\n".join(parts)


func _flash_export_status(message: String, ok: bool) -> void:
	if _export_status_label == null:
		return
	_export_status_label.visible = true
	_export_status_label.text = message
	_export_status_label.add_theme_color_override(
			"font_color", Color(0.55, 0.92, 0.62) if ok else Color(0.95, 0.42, 0.42)
	)
	# `create_timer()` returns a single-shot timer; connect with a Callable.
	get_tree().create_timer(5.0).timeout.connect(Callable(self, "_clear_export_status_once"))


func _clear_export_status_once() -> void:
	if _export_status_label != null:
		_export_status_label.visible = false


func _on_history_pressed() -> void:
	_export_history_vbox.visible = not _export_history_vbox.visible
	if _export_history_vbox.visible:
		_refresh_export_history()


func _refresh_export_history() -> void:
	# Clear existing children
	for c in _export_history_vbox.get_children():
		c.queue_free()
	var da := DirAccess.open("user://exports")
	if da == null:
		var lbl = Label.new()
		lbl.text = "No exports directory"
		_export_history_vbox.add_child(lbl)
		return
	var files: Array = []
	da.list_dir_begin()
	var fname = da.get_next()
	while fname != "":
		if not da.current_is_dir():
			files.append(fname)
		fname = da.get_next()
	da.list_dir_end()
	files.sort()
	if files.size() == 0:
		var lbl = Label.new()
		lbl.text = "No exports found"
		_export_history_vbox.add_child(lbl)
		return
	for f in files:
		var h = HBoxContainer.new()
		var l = Label.new()
		l.text = f
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(l)
		var open_btn = Button.new()
		open_btn.text = "Open"
		open_btn.connect("pressed", Callable(self, "_on_open_export_pressed").bind(f))
		h.add_child(open_btn)
		_export_history_vbox.add_child(h)


func _on_open_export_pressed(file_name: String) -> void:
	var full = "user://exports/%s" % file_name
	print("[ChronicleUI] Export file: %s" % full)


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
	# Clear only entry labels, preserve header, summary, export status, and history panel
	for child in _vbox.get_children():
		if (
				child != _header
				and child != _summary_label
				and child != _export_status_label
				and child != _export_history_vbox
		):
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
