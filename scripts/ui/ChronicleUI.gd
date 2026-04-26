extends ScrollContainer
class_name ChronicleUI

var _vbox: VBoxContainer
var _rebuilding: bool = false


func _ready() -> void:
	_vbox = VBoxContainer.new()
	_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_vbox.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	add_child(_vbox)

	if not ChronicleLog.entry_added.is_connected(_on_entry_added):
		ChronicleLog.entry_added.connect(_on_entry_added)
	if not ChronicleLog.entries_reloaded.is_connected(_on_entries_reloaded):
		ChronicleLog.entries_reloaded.connect(_on_entries_reloaded)
	_rebuilding = true
	_rebuild_ui()
	_rebuilding = false
	_scroll_to_bottom()


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
	for child in _vbox.get_children():
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
