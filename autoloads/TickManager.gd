extends Node
signal tick_processed(tick_number: int)
signal speed_changed(speed_multiplier: float, is_paused: bool)

const SPEED_MULTIPLIERS: Array = [1.0, 6.0, 26.0, 50.0, 100.0, 200.0]
const SPEED_LABELS: Array      = ["1x", "6x", "26x", "50x", "100x", "200x"]
const BASE_TICK_INTERVAL: float = 0.05
const MAX_TICKS_PER_FRAME: Dictionary = {0:2, 1:4, 2:8, 3:12, 4:16, 5:32}

var current_tick: int = 0
var _accumulated_time: float = 0.0
var _speed_index: int = 0
var _is_paused: bool = false
var _refcounted_tickables: Array = []
var _tickable_cache: Array = []
var _tickable_cache_dirty: bool = true
var debug_last_tick_batch_usec: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(delta: float) -> void:
	if _is_paused:
		return
	_accumulated_time += delta * SPEED_MULTIPLIERS[_speed_index]
	var max_ticks: int = _max_ticks_per_frame_for_speed()
	var frame_budget_usec: int = _frame_budget_usec()
	var frame_start_usec: int = Time.get_ticks_usec()
	var ticks_this_frame: int = 0
	while _accumulated_time >= BASE_TICK_INTERVAL and ticks_this_frame < max_ticks:
		if ticks_this_frame > 0 and Time.get_ticks_usec() - frame_start_usec >= frame_budget_usec:
			break
		_accumulated_time -= BASE_TICK_INTERVAL
		current_tick += 1
		_fire_tick(current_tick)
		ticks_this_frame += 1

func _fire_tick(tick: int) -> void:
	var start: int = Time.get_ticks_usec()
	if _tickable_cache_dirty:
		_tickable_cache = get_tree().get_nodes_in_group("tickable")
		_tickable_cache.sort_custom(func(a, b): return str(a.get_path()) < str(b.get_path()))
		_tickable_cache_dirty = false
	for node in _tickable_cache:
		if is_instance_valid(node) and node.has_method("_on_world_tick"):
			node._on_world_tick(tick)
	for ref in _refcounted_tickables:
		if ref != null and ref.has_method("_on_world_tick"):
			ref._on_world_tick(tick)
	tick_processed.emit(tick)
	debug_last_tick_batch_usec = Time.get_ticks_usec() - start

func mark_tickable_cache_dirty() -> void:
	_tickable_cache_dirty = true

func _frame_budget_usec() -> int:
	var budget_ms: int = 16
	if GameSettings != null and GameSettings.has_method("get_value"):
		budget_ms = maxi(1, int(GameSettings.get_value("frame_budget_ms")))
	return budget_ms * 1000

func _max_ticks_per_frame_for_speed() -> int:
	var speed_cap: int = MAX_TICKS_PER_FRAME.get(_speed_index, 4)
	var configured_cap: int = speed_cap
	if GameSettings != null and GameSettings.has_method("get_value"):
		configured_cap = maxi(1, int(GameSettings.get_value("max_ticks_per_frame")))
	return maxi(1, mini(speed_cap, configured_cap))

func register_refcounted_tickable(obj) -> void:
	if obj not in _refcounted_tickables:
		_refcounted_tickables.append(obj)
func unregister_refcounted_tickable(obj) -> void:
	_refcounted_tickables.erase(obj)
func set_speed(multiplier: float) -> void:
	var best: int = 0
	var best_diff: float = INF
	for i in range(SPEED_MULTIPLIERS.size()):
		var diff: float = absf(SPEED_MULTIPLIERS[i] - multiplier)
		if diff < best_diff:
			best_diff = diff
			best = i
	set_speed_index(best)
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
