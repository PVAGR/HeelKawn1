extends Node

# Dev debug UI: on-screen buttons to control diagnostics and inspect runtime state.
# Autoload this script as `DevDebugUI` for dev runs.

var _log: RichTextLabel = null
var _status_label: Label = null
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

	_status_label = Label.new()
	_status_label.text = "Status: --"
	v.add_child(_status_label)

	var h_controls = HBoxContainer.new()
	v.add_child(h_controls)

	var btn_pause = Button.new()
	btn_pause.text = "Pause / Resume"
	btn_pause.connect("pressed", Callable(self, "_on_pause_toggle_pressed"))
	h_controls.add_child(btn_pause)

	var btn_speed_half = Button.new()
	btn_speed_half.text = "0.5x"
	btn_speed_half.connect("pressed", Callable(self, "_on_speed_pressed").bind(0.5))
	h_controls.add_child(btn_speed_half)

	var btn_speed_one = Button.new()
	btn_speed_one.text = "1x"
	btn_speed_one.connect("pressed", Callable(self, "_on_speed_pressed").bind(1.0))
	h_controls.add_child(btn_speed_one)

	var btn_speed_four = Button.new()
	btn_speed_four.text = "4x"
	btn_speed_four.connect("pressed", Callable(self, "_on_speed_pressed").bind(4.0))
	h_controls.add_child(btn_speed_four)

	var btn_speed_sixteen = Button.new()
	btn_speed_sixteen.text = "16x"
	btn_speed_sixteen.connect("pressed", Callable(self, "_on_speed_pressed").bind(16.0))
	h_controls.add_child(btn_speed_sixteen)

	var btn_speed_sixtyfour = Button.new()
	btn_speed_sixtyfour.text = "64x"
	btn_speed_sixtyfour.connect("pressed", Callable(self, "_on_speed_pressed").bind(64.0))
	h_controls.add_child(btn_speed_sixtyfour)

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
    # bbcode_enabled disabled for runtime stability
    # _log.bbcode_enabled = true
	_log.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_log.custom_minimum_size = Vector2(240, 100)
	_log.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_log.scroll_active = true
	v.add_child(_log)

	_append_log("DevDebugUI ready")
	_refresh_status()

func _append_log(s: String) -> void:
	if _log:
		_log.append_bbcode(escape_bbcode(s) + "\n")
	print("[DevDebugUI] " + s)
	_refresh_status()


func _refresh_status() -> void:
	if _status_label == null:
		return
	var speed_text: String = "?"
	var paused_text: String = "?"
	var tick_text: String = "?"
	if has_node("/root/TickManager"):
		var tm = get_node("/root/TickManager")
		if tm != null:
			if tm.has_method("get_speed_multiplier"):
				speed_text = str(tm.call("get_speed_multiplier")) + "x"
			if tm.has_method("is_paused"):
				paused_text = "yes" if bool(tm.call("is_paused")) else "no"
	if GameManager != null:
		tick_text = str(GameManager.tick_count)
	_status_label.text = "Status: tick=%s speed=%s paused=%s" % [tick_text, speed_text, paused_text]


func _on_pause_toggle_pressed() -> void:
	_append_log("Pause / Resume pressed")
	if has_node("/root/TickManager"):
		var tm = get_node("/root/TickManager")
		if tm != null and tm.has_method("toggle_pause"):
			tm.call("toggle_pause")
			_append_log("TickManager.toggle_pause() called")
			_refresh_status()
			return
	if GameManager != null:
		if GameManager.has_method("toggle_pause"):
			GameManager.call("toggle_pause")
			_append_log("GameManager.toggle_pause() called")
			_refresh_status()
			return
	_append_log("Pause control not available")


func _on_speed_pressed(multiplier: float) -> void:
	_append_log("Speed pressed: %sx" % str(multiplier))
	if has_node("/root/TickManager"):
		var tm = get_node("/root/TickManager")
		if tm != null and tm.has_method("set_speed"):
			tm.call("set_speed", multiplier)
			_append_log("TickManager.set_speed(%s) called" % str(multiplier))
			_refresh_status()
			return
	if GameManager != null and GameManager.has_method("set_speed"):
		GameManager.call("set_speed", multiplier)
		_append_log("GameManager.set_speed(%s) called" % str(multiplier))
		_refresh_status()
		return
	_append_log("Speed control not available")

func _on_start_pressed() -> void:
	_append_log("Start Monitor pressed")
	if typeof(TickMonitor) != TYPE_NIL and TickMonitor != null:
		TickMonitor.monitor_start(1.0)
		_append_log("TickMonitor.monitor_start() called")
	else:
		_append_log("TickMonitor not available")
	_refresh_status()

func _on_stop_pressed() -> void:
	_append_log("Stop Monitor pressed")
	if typeof(TickMonitor) != TYPE_NIL and TickMonitor != null:
		TickMonitor.monitor_stop()
		_append_log("TickMonitor.monitor_stop() called")
	else:
		_append_log("TickMonitor not available")
	_refresh_status()
	

func _on_diag_once_pressed() -> void:
	_append_log("Diag Once pressed")
	# Prefer autoload Main instance if it provides the diagnostic helper
	var main_node: Node = get_node_or_null("/root/Main")
	if main_node != null and main_node.has_method("heelkawn_diag_once"):
		main_node.call("heelkawn_diag_once")
		_append_log("Main.heelkawn_diag_once() called")
		return
	# Fallback: use TickMonitor autoload instance if present and call its timeout handler
	var tm: Node = get_node_or_null("/root/TickMonitor")
	if tm != null:
		if tm.has_method("_on_timeout"):
			tm.call("_on_timeout")
			_append_log("TickMonitor._on_timeout() called")
			return
		elif tm.has_method("monitor_start"):
			# As a last resort start a one-shot monitor briefly
			tm.call("monitor_start", 1.0)
			_append_log("TickMonitor.monitor_start(1.0) called (use Stop Monitor to stop)")
			return
	_append_log("Diagnostic helper not found; run heelkawn_diag_once() from remote console")
	_refresh_status()


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
	_refresh_status()

func _on_dump_pawns() -> void:
	var tree = get_tree()
	if tree == null:
		_append_log("No SceneTree")
		return
	var arr: Array[Pawn] = PawnSpawner.find_pawns()
	_append_log("Pawns: %d" % arr.size())
	for p in arr:
		var pos = "?"
		if p is Node2D:
			pos = str(p.position)
		_append_log(" - %s id=%d pos=%s" % [p.name if p else "<null>", p.get_instance_id() if p else -1, pos])
	_refresh_status()

func _on_count_moving_pressed() -> void:
	var tree = get_tree()
	if tree == null:
		_append_log("No SceneTree")
		return
	var pawns: Array[Pawn] = PawnSpawner.find_pawns()
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
	_refresh_status()

func escape_bbcode(s: String) -> String:
	return s.replace("[", "\\[").replace("]", "\\]")
