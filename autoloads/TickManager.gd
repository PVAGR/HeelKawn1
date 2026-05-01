extends Node
## Central deterministic tick manager. Drives ALL simulation logic via fixed-step
## accumulation. Emits `tick_processed` and calls `_on_world_tick()` on all
## nodes in the "tickable" group.

signal tick_processed(tick_number: int)

const BASE_TICK_INTERVAL: float = 1.0

var current_tick: int = 0
var _accumulated_time: float = 0.0
var _target_interval: float = BASE_TICK_INTERVAL
var _is_paused: bool = false
var _speed_multiplier: float = 1.0

## Speed presets: 0.5x, 1x, 4x, 16x, 64x
const SPEED_PRESETS: Array[float] = [0.5, 1.0, 4.0, 16.0, 64.0]
var _current_speed_index: int = 1  # Start at 1x (index 1)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(delta: float) -> void:
	if _is_paused:
		return
	_accumulated_time += delta * _speed_multiplier
	while _accumulated_time >= _target_interval:
		_accumulated_time -= _target_interval
		current_tick += 1
		_dispatch_tick(current_tick)

func _dispatch_tick(tick: int) -> void:
	tick_processed.emit(tick)
	_call_tick_on_tickables(tick)
	# Keep GameManager in sync for systems that still read tick_count
	if GameManager != null:
		GameManager.tick_count = tick

func _call_tick_on_tickables(tick: int) -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	for node in tree.get_nodes_in_group("tickable"):
		if node != null and is_instance_valid(node) and node.has_method("_on_world_tick"):
			node._on_world_tick(tick)

## Set speed by multiplier (0.5, 1, 4, 16, 64).
func set_speed(multiplier: float) -> void:
	_speed_multiplier = max(multiplier, 0.0001)
	_target_interval = BASE_TICK_INTERVAL / _speed_multiplier
	# Update GameManager speed for UI compatibility
	if GameManager != null:
		GameManager.game_speed = _speed_multiplier
		GameManager.speed_changed.emit(_speed_multiplier, _is_paused)

## Set speed by preset index: 0=0.5x, 1=1x, 2=4x, 3=16x, 4=64x.
func set_speed_index(index: int) -> void:
	if index < 0 or index >= SPEED_PRESETS.size():
		return
	_current_speed_index = index
	set_speed(SPEED_PRESETS[index])

## Cycle to next speed preset.
func next_speed() -> void:
	var next: int = (_current_speed_index + 1) % SPEED_PRESETS.size()
	set_speed_index(next)

## Cycle to previous speed preset.
func prev_speed() -> void:
	var prev: int = (_current_speed_index - 1 + SPEED_PRESETS.size()) % SPEED_PRESETS.size()
	set_speed_index(prev)

func pause() -> void:
	_is_paused = true
	if GameManager != null:
		GameManager.is_paused = true
		GameManager.speed_changed.emit(_speed_multiplier, true)

func resume() -> void:
	_is_paused = false
	if GameManager != null:
		GameManager.is_paused = false
		GameManager.speed_changed.emit(_speed_multiplier, false)

func toggle_pause() -> void:
	if _is_paused:
		resume()
	else:
		pause()

func is_paused() -> bool:
	return _is_paused

func get_speed_multiplier() -> float:
	return _speed_multiplier

func get_speed_index() -> int:
	return _current_speed_index

func reset() -> void:
	current_tick = 0
	_accumulated_time = 0.0
