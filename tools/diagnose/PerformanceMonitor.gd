extends CanvasLayer
class_name PerformanceMonitorUI

## Real-time performance monitoring overlay
## Toggle with F7 in-game. Shows FPS, tick throughput, and simulation health.

const UPDATE_INTERVAL: float = 0.25  # Update display every 250ms

var _label: RichTextLabel = null
var _visible: bool = false
var _timer: float = 0.0
var _fps_history: Array[float] = []
var _tick_history: Array[int] = []
const HISTORY_SIZE: int = 40

var _fps_font: Font = null
var _fps_font_size: int = 14


func _ready() -> void:
	layer = 100  # Render on top
	_create_overlay()


func _create_overlay() -> void:
	_label = RichTextLabel.new()
	_label.anchor_left = 0.0
	_label.anchor_top = 0.0
	_label.anchor_right = 1.0
	_label.offset_bottom = 180.0
	_label.offset_left = 10.0
	_label.offset_right = 400.0
	# Godot 4.x API: Use add_theme_font_override instead of theme_override_fonts
	_label.add_theme_font_override("normal_font", _fps_font if _fps_font != null else ThemeDB.fallback_font)
	_label.add_theme_font_size_override("normal_font_size", _fps_font_size)
    # bbcode_enabled disabled for runtime stability
    # _label.bbcode_enabled = true
	_label.scroll_following = false
	_label.text = "[color=gray]Performance Monitor[/color]\nInitializing..."
	add_child(_label)


func toggle() -> void:
	_visible = not _visible
	_label.visible = _visible
	if _visible:
		print("[PerformanceMonitor] enabled")
	else:
		print("[PerformanceMonitor] disabled")


func set_visible_custom(visible: bool) -> void:
	_visible = visible
	_label.visible = _visible


func _process(delta: float) -> void:
	if not _visible:
		return

	_timer += delta
	if _timer < UPDATE_INTERVAL:
		return
	_timer = 0.0

	_update_display()


func _update_display() -> void:
	if _label == null or not is_instance_valid(_label):
		return

	# FPS
	var fps: int = Engine.get_frames_per_second()
	_fps_history.append(fps)
	if _fps_history.size() > HISTORY_SIZE:
		_fps_history.pop_front()
	var avg_fps: float = _fps_history.reduce(func(a, b): return a + b) / float(_fps_history.size())

	# Tick throughput
	var ticks_last_frame: int = 0
	var accum_time: float = 0.0
	var speed: float = 1.0
	var tm: Node = get_node_or_null("/root/TickManager")
	if tm != null:
		ticks_last_frame = tm.get("_last_frame_ticks") if tm.has_method("get") else 0
		accum_time = tm.get("_accumulated_time") if tm.has_method("get") else 0.0
		speed = tm.get_speed_multiplier() if tm.has_method("get_speed_multiplier") else 1.0

	_tick_history.append(ticks_last_frame)
	if _tick_history.size() > HISTORY_SIZE:
		_tick_history.pop_front()
	var avg_ticks: float = _tick_history.reduce(func(a, b): return a + b) / float(_tick_history.size())

	# HeelKawnian count
	var pawn_count: int = 0
	var main_node: Node = get_tree().get_root().get_node_or_null("Main")
	if main_node != null:
		var ps: Node = main_node.get_node_or_null("WorldViewport/PawnSpawner")
		if ps != null and ps.has_method("find_pawns"):
			var pawns: Array = ps.call("find_pawns")
			pawn_count = pawns.size()

	# Memory (approximate)
	var mem_mb: float = Performance.get_monitor(Performance.MEMORY_STATIC) / (1024.0 * 1024.0)
	var obj_count: int = Performance.get_monitor(Performance.OBJECT_COUNT)

	# Build display
	var fps_color: String = "lime" if avg_fps >= 55.0 else ("yellow" if avg_fps >= 30.0 else "red")
	var tick_color: String = "lime" if avg_ticks <= 50.0 else ("yellow" if avg_ticks <= 150.0 else "red")

	var text: String = "[color=gray][b]Performance Monitor[/b][/color]\n"
	text += "\n"
	text += "[color=%s]FPS: %.1f[/color]  (avg: %.1f, target: 60)\n" % [fps_color, float(fps), avg_fps]
	text += "[color=%s]Ticks/Frame: %.1f[/color]  (avg: %.1f)\n" % [tick_color, float(ticks_last_frame), avg_ticks]
	text += "Speed: %.1fx  |  Accum: %.1f ticks\n" % [speed, accum_time]
	text += "\n"
	text += "Pawns: %d  |  Objects: %d  |  Mem: %.1f MB\n" % [pawn_count, obj_count, mem_mb]

	# Performance grade
	var grade: String = _calculate_grade(fps, avg_fps, ticks_last_frame, avg_ticks, speed)
	text += "\n[color=%s][b]%s[/b][/color]" % [
		"lime" if grade.begins_with("GOOD") else ("yellow" if grade.begins_with("OK") else "red"),
		grade
	]

	_label.text = text


func _calculate_grade(fps: int, avg_fps: float, ticks: float, avg_ticks: float, speed: float) -> String:
	# Grade based on smoothness and throughput
	if avg_fps >= 55.0 and avg_ticks <= 100.0:
		return "GOOD - Running Smoothly"
	elif avg_fps >= 40.0 and avg_ticks <= 200.0:
		return "OK - Acceptable Performance"
	elif avg_fps >= 25.0:
		return "FAIR - Consider Lowering Speed"
	else:
		return "POOR - Performance Issues Detected"


## Static helper to get global performance monitor
static func get_instance() -> PerformanceMonitorUI:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	for child in tree.root.get_children():
		if child is PerformanceMonitorUI:
			return child as PerformanceMonitorUI
	return null
