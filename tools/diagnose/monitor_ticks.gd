extends Node

# Lightweight runtime probe to inspect tick delivery and pawn movement.
# Usage (in Godot remote/Console):
#   var m = TickMonitor.new(); get_tree().root.add_child(m); m.monitor_start(1.0)

var _timer: Timer = null
var _last_positions: Dictionary = {}

func monitor_start(interval_sec: float = 1.0) -> void:
	if _timer != null:
		return
	_timer = Timer.new()
	_timer.one_shot = false
	_timer.wait_time = interval_sec
	add_child(_timer)
	_timer.timeout.connect(Callable(self, "_on_timeout"))
	_timer.start()
	print("[TickMonitor] started (interval=%.2fs)" % interval_sec)

func monitor_stop() -> void:
	if _timer != null:
		_timer.stop()
		_timer.queue_free()
		_timer = null
		print("[TickMonitor] stopped")

func _on_timeout() -> void:
	var tick: int = -1
	if GameManager != null:
		tick = GameManager.tick_count
	var tickables: Array = []
	var pawns: Array = []
	var moving_count: int = 0
	var tree := get_tree()
	if tree != null:
		tickables = tree.get_nodes_in_group("tickable")
		pawns = tree.get_nodes_in_group("pawns")
		for p in pawns:
			if p == null or not is_instance_valid(p):
				continue
			var id = str(p.get_instance_id())
			var pos = Vector2.ZERO
			if typeof(p) == TYPE_OBJECT and p is Node2D:
				pos = p.position
			var last = _last_positions.get(id, null)
			if last != null and pos != null:
				if pos != last:
					moving_count += 1
			_last_positions[id] = pos
	print("[TickMonitor] tick=%s tickables=%d pawns=%d moving=%d" % [str(tick), tickables.size(), pawns.size(), moving_count])
