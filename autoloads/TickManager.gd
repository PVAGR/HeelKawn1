extends Node

signal tick_processed(tick_number: int)

var current_tick: int = 0
var accumulated_time: float = 0.0
var base_interval: float = 0.1
var speed_multiplier: float = 1.0
var _is_paused: bool = false

## Hard cap per frame prevents spiral-of-death on long frames.
const MAX_TICKS_PER_FRAME: int = 16

func _process(delta: float) -> void:
	if _is_paused:
		return
	accumulated_time += delta
	var interval: float = base_interval / maxf(0.0001, speed_multiplier)
	var processed: int = 0
	while accumulated_time >= interval and processed < MAX_TICKS_PER_FRAME:
		accumulated_time -= interval
		current_tick += 1
		tick_processed.emit(current_tick)
		processed += 1
	# Drop overflow backlog to keep simulation real-time and stable under stalls.
	if processed >= MAX_TICKS_PER_FRAME and accumulated_time >= interval:
		accumulated_time = fmod(accumulated_time, interval)


func set_speed(multiplier: float) -> void:
	speed_multiplier = maxf(0.0001, multiplier)

func pause() -> void:
	_is_paused = true

func resume() -> void:
	_is_paused = false

func is_paused() -> bool:
	return _is_paused

func get_tick() -> int:
	return current_tick
