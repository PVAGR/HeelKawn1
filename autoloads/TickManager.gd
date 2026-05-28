extends Node
signal tick_processed(tick_number: int)
signal speed_changed(speed_multiplier: float, is_paused: bool)

const SPEED_MULTIPLIERS: Array = [1.0, 6.0, 26.0, 50.0, 100.0, 200.0]
const SPEED_LABELS: Array      = ["1x", "6x", "26x", "50x", "100x", "200x"]
const BASE_TICK_INTERVAL: float = 0.05
const MAX_TICKS_PER_FRAME: Dictionary = {0:2, 1:4, 2:8, 3:16, 4:28, 5:48}

var current_tick: int = 0
var _accumulated_time: float = 0.0
var _speed_index: int = 0
var _is_paused: bool = false
var _refcounted_tickables: Array = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(delta: float) -> void:
	if _is_paused:
		return
	_accumulated_time += delta * SPEED_MULTIPLIERS[_speed_index]
	var max_ticks: int = MAX_TICKS_PER_FRAME.get(_speed_index, 4)
	var ticks_this_frame: int = 0
	while _accumulated_time >= BASE_TICK_INTERVAL and ticks_this_frame < max_ticks:
		_accumulated_time -= BASE_TICK_INTERVAL
		current_tick += 1
		_fire_tick(current_tick)
		ticks_this_frame += 1

func _fire_tick(tick: int) -> void:
	var tickables: Array = get_tree().get_nodes_in_group("tickable")
	tickables.sort_custom(func(a, b): return str(a.get_path()) < str(b.get_path()))
	for node in tickables:
		if is_instance_valid(node) and node.has_method("_on_world_tick"):
			node._on_world_tick(tick)
	for ref in _refcounted_tickables:
		if ref != null and ref.has_method("_on_world_tick"):
			ref._on_world_tick(tick)
	tick_processed.emit(tick)

func register_refcounted_tickable(obj) -> void:
	if obj not in _refcounted_tickables:
		_refcounted_tickables.append(obj)
func unregister_refcounted_tickable(obj) -> void:
	_refcounted_tickables.erase(obj)
func set_speed_index(index: int) -> void:
	_speed_index = clampi(index, 0, SPEED_MULTIPLIERS.size() - 1)
	speed_changed.emit(SPEED_MULTIPLIERS[_speed_index], _is_paused)
func get_speed_multiplier() -> float: return SPEED_MULTIPLIERS[_speed_index]
func get_speed_label() -> String: return SPEED_LABELS[_speed_index]
func get_speed_index() -> int: return _speed_index
func pause() -> void:
	_is_paused = true
	speed_changed.emit(SPEED_MULTIPLIERS[_speed_index], _is_paused)
func resume() -> void:
	_is_paused = false
	speed_changed.emit(SPEED_MULTIPLIERS[_speed_index], _is_paused)
func toggle_pause() -> void:
	if _is_paused: resume()
	else: pause()
func is_paused() -> bool: return _is_paused
func is_high_speed() -> bool: return _speed_index >= 3
func verbose_logs() -> bool: return false
