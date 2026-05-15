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
		pawns = PawnAccess.find_pawns()
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
	# Basic sim snapshot
	var sim_diag_str: String = ""
	if GameManager != null and GameManager.has_method("sim_diag"):
		var sd: Dictionary = GameManager.call("sim_diag")
		if sd != null:
			sim_diag_str = " sim_diag(tick=%s speed=%s paused=%s queued=%.2f ticks_last=%s)" % [str(sd.get("tick_count")), str(sd.get("speed")), str(sd.get("paused")), float(sd.get("queued_ticks_est", 0.0)), str(sd.get("ticks_emitted_last_frame"))]

	# TickManager snapshot (if present)
	var tm_str: String = ""
	if has_node("/root/TickManager"):
		var tm = get_node("/root/TickManager")
		if tm != null:
			var sp = "?"
			var si = "?"
			var paused = "?"
			var last_frame_ticks = "?"
			var accum = "?"
			if tm.has_method("get_speed_multiplier"):
				sp = str(tm.call("get_speed_multiplier"))
			if tm.has_method("get_speed_index"):
				si = str(tm.call("get_speed_index"))
			if tm.has_method("is_paused"):
				paused = str(tm.call("is_paused"))
			if "_last_frame_ticks" in tm:
				last_frame_ticks = str(tm.get("_last_frame_ticks"))
			if "_accumulated_time" in tm:
				accum = str(tm.get("_accumulated_time"))
			tm_str = " TickMgr(speed=%s idx=%s paused=%s last_frame_ticks=%s accum=%s)" % [sp, si, paused, last_frame_ticks, accum]

	print("[TickMonitor] tick=%s tickables=%d pawns=%d moving=%d%s%s" % [str(tick), tickables.size(), pawns.size(), moving_count, sim_diag_str, tm_str])
