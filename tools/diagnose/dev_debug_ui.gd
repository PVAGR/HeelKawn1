extends Node

# Dev debug UI: on-screen buttons to control diagnostics and inspect runtime state.
# Autoload this script as `DevDebugUI` for dev runs.

var _log: RichTextLabel = null
var _autostart_monitor: bool = true
# Toggle to show/hide the dev UI (set false to hide)
var _dev_ui_enabled: bool = true
var _panel: Panel = null

func _ready() -> void:
	_create_ui()
	if _autostart_monitor:
		# best-effort call: start TickMonitor if autoloaded
		if typeof(TickMonitor) != TYPE_NIL and TickMonitor != null:
			TickMonitor.monitor_start(1.0)

func _create_ui() -> void:
	var layer = CanvasLayer.new()
	add_child(layer)

	_panel = Panel.new()
	_panel.custom_minimum_size = Vector2(260, 240)
	_panel.position = Vector2(10, 10)
	layer.add_child(_panel)

	var v = VBoxContainer.new()
	_panel.add_child(v)

	var btn_start = Button.new()
	btn_start.text = "Start Monitor"
	btn_start.connect("pressed", Callable(self, "_on_start_pressed"))
	v.add_child(btn_start)

	var btn_stop = Button.new()
	btn_stop.text = "Stop Monitor"
	btn_stop.connect("pressed", Callable(self, "_on_stop_pressed"))
	v.add_child(btn_stop)

	var btn_dump_tickables = Button.new()
	btn_dump_tickables.text = "Dump Tickables"
	btn_dump_tickables.connect("pressed", Callable(self, "_on_dump_tickables"))
	v.add_child(btn_dump_tickables)

	var btn_dump_pawns = Button.new()
	btn_dump_pawns.text = "Dump Pawns"
	btn_dump_pawns.connect("pressed", Callable(self, "_on_dump_pawns"))
	v.add_child(btn_dump_pawns)

	var btn_dump_moving = Button.new()
	btn_dump_moving.text = "Count Moving Pawns"
	btn_dump_moving.connect("pressed", Callable(self, "_on_count_moving_pressed"))
	v.add_child(btn_dump_moving)

	var btn_diag_once = Button.new()
	btn_diag_once.text = "Diag Once"
	btn_diag_once.connect("pressed", Callable(self, "_on_diag_once_pressed"))
	v.add_child(btn_diag_once)

	var h = HSeparator.new()
	v.add_child(h)

	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_log.custom_minimum_size = Vector2(240, 100)
	_log.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_log.scroll_active = true
	v.add_child(_log)

	_append_log("DevDebugUI ready")

func _append_log(s: String) -> void:
	if _log:
		_log.append_bbcode(escape_bbcode(s) + "\n")
	print("[DevDebugUI] " + s)

func _on_start_pressed() -> void:
	_append_log("Start Monitor pressed")
	if typeof(TickMonitor) != TYPE_NIL and TickMonitor != null:
		TickMonitor.monitor_start(1.0)
		_append_log("TickMonitor.monitor_start() called")
	else:
		_append_log("TickMonitor not available")

func _on_stop_pressed() -> void:
	_append_log("Stop Monitor pressed")
	if typeof(TickMonitor) != TYPE_NIL and TickMonitor != null:
		TickMonitor.monitor_stop()
		_append_log("TickMonitor.monitor_stop() called")
	else:
		_append_log("TickMonitor not available")
	

func _on_diag_once_pressed() -> void:
	_append_log("Diag Once pressed")
	# Prefer autoload Main if it provides the diagnostic helper
	if typeof(Main) != TYPE_NIL and Main != null and Main.has_method("heelkawn_diag_once"):
		Main.heelkawn_diag_once()
		_append_log("Main.heelkawn_diag_once() called")
		return
	if typeof(TickMonitor) != TYPE_NIL and TickMonitor != null and TickMonitor.has_method("monitor_once"):
		TickMonitor.monitor_once()
		_append_log("TickMonitor.monitor_once() called")
		return
	_append_log("Diagnostic helper not found; run heelkawn_diag_once() from remote console")


func _unhandled_input(event: InputEvent) -> void:
	if not _dev_ui_enabled:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		# Toggle UI with F10
		if event.keycode == KEY_F10:
			if _panel != null:
				_panel.visible = not _panel.visible
				_append_log("DevDebugUI %s" % ("shown" if _panel.visible else "hidden"))

func _on_dump_tickables() -> void:
	var tree = get_tree()
	if tree == null:
		_append_log("No SceneTree")
		return
	var arr = tree.get_nodes_in_group("tickable")
	_append_log("Tickables: %d" % arr.size())
	for n in arr:
		_append_log(" - %s (%s)" % [n.name if n else "<null>", n.get_class() if n else "?"])

func _on_dump_pawns() -> void:
	var tree = get_tree()
	if tree == null:
		_append_log("No SceneTree")
		return
	var arr = tree.get_nodes_in_group("pawns")
	_append_log("Pawns: %d" % arr.size())
	for p in arr:
		var pos = "?"
		if p is Node2D:
			pos = str(p.position)
		_append_log(" - %s id=%d pos=%s" % [p.name if p else "<null>", p.get_instance_id() if p else -1, pos])

func _on_count_moving_pressed() -> void:
	var tree = get_tree()
	if tree == null:
		_append_log("No SceneTree")
		return
	var pawns = tree.get_nodes_in_group("pawns")
	var moving = 0
	for p in pawns:
		if p == null or not is_instance_valid(p):
			continue
		if p is Node2D:
			var vel = Vector2.ZERO
			if p.has_method("get_velocity"):
				vel = p.get_velocity()
			else:
				# best-effort: compare position to last frame using a temporary cache stored on node
				if not p.has_meta("__dev_prev_pos"):
					p.set_meta("__dev_prev_pos", p.position)
				else:
					var prev = p.get_meta("__dev_prev_pos")
					if p.position != prev:
						moving += 1
					p.set_meta("__dev_prev_pos", p.position)
	_append_log("Moving pawns: %d" % moving)

func escape_bbcode(s: String) -> String:
	return s.replace("[", "\\[").replace("]", "\\]")
