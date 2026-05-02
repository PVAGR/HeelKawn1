extends Node

# Dev debug UI: on-screen buttons to control diagnostics and inspect runtime state.
# Autoload this script as `DevDebugUI` for dev runs.

var _log: TextEdit = null
var _autostart_monitor: bool = true

func _ready() -> void:
    _create_ui()
    if _autostart_monitor:
        # attempt to start TickMonitor if available
        if typeof(self).has_property("TickMonitor"):
            pass
        # best-effort call (TickMonitor is an autoload)
        if TickMonitor != null:
            TickMonitor.monitor_start(1.0)

func _create_ui() -> void:
    var layer = CanvasLayer.new()
    add_child(layer)

    var panel = Panel.new()
    panel.rect_min_size = Vector2(260, 220)
    panel.margin_left = 10
    panel.margin_top = 10
    layer.add_child(panel)

    var v = VBoxContainer.new()
    v.anchor_right = 0
    v.anchor_bottom = 0
    panel.add_child(v)

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

    var h = HSeparator.new()
    v.add_child(h)

    _log = TextEdit.new()
    _log.readonly = true
    _log.rect_min_size = Vector2(240, 80)
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
    return s.replace("[", "\[").replace("]", "\]")
