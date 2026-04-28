extends Node

## Emitted once per simulation tick. All simulation systems should listen to this
## instead of running on _process, so pause/speed affects everything uniformly.
signal game_tick(tick_count: int)

## Emitted whenever the speed or pause state changes. UI can listen to update icons.
signal speed_changed(new_speed: float, is_paused: bool)

## Real seconds per tick at 1x speed. Optimized for smoother AI processing.
const TICK_INTERVAL_SECONDS: float = 0.02  # Much faster for smoother gameplay

## Allowed speed multipliers with finer granularity for smooth control.
const SPEED_STEPS: Array[float] = [1.0, 2.0, 4.0, 8.0, 16.0, 32.0, 64.0, 128.0]
## Set true only when actively debugging pawn/animal internals.
const VERBOSE_SIM_LOGS: bool = false
## Optimized caps for enhanced AI processing
const MAX_TICKS_PER_FRAME: int = 64  # Increased for faster catch-up
const MAX_ACCUMULATED_TICKS: int = 64  # Increased for smoother catch-up

## Dynamic tick rate adjustment
var tick_interval: float = TICK_INTERVAL_SECONDS
var adaptive_tick_rate: bool = true
var target_fps: float = 60.0

var game_speed: float = 1.0
var is_paused: bool = false
var tick_count: int = 0

## Optional macro pressure (LivingWorldController and future systems). Not tied to
## a single UI yet; keeps a bounded running total.
var global_stress: int = 0

var _tick_accumulator: float = 0.0


func verbose_logs() -> bool:
	return VERBOSE_SIM_LOGS


## Lightweight read-only snapshot for HUD / tooling (tick backlog estimate in sim steps).
func sim_diag() -> Dictionary:
	var queued_ticks_est: float = _tick_accumulator / TICK_INTERVAL_SECONDS
	return {
		"tick_count": tick_count,
		"speed": game_speed,
		"paused": is_paused,
		"max_ticks_per_frame": MAX_TICKS_PER_FRAME,
		"max_accumulated_ticks": MAX_ACCUMULATED_TICKS,
		"accumulator_sec": _tick_accumulator,
		"queued_ticks_est": queued_ticks_est,
	}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	if is_paused:
		return
	
	# Adaptive tick rate adjustment for smoother performance
	if adaptive_tick_rate:
		_adjust_tick_rate(delta)
	
	_tick_accumulator += delta * game_speed
	var max_accumulator: float = tick_interval * float(MAX_ACCUMULATED_TICKS)
	if _tick_accumulator > max_accumulator:
		_tick_accumulator = max_accumulator
	
	var ticks_this_frame: int = 0
	while _tick_accumulator >= tick_interval and ticks_this_frame < MAX_TICKS_PER_FRAME:
		_tick_accumulator -= tick_interval
		tick_count += 1
		game_tick.emit(tick_count)
		ticks_this_frame += 1

func _adjust_tick_rate(delta: float) -> void:
	# Adjust tick interval based on current performance
	var current_fps: float = 1.0 / delta if delta > 0.0 else 60.0
	
	if current_fps < target_fps * 0.8:  # Performance dropping
		tick_interval = min(tick_interval * 1.1, TICK_INTERVAL_SECONDS * 2.0)
	elif current_fps > target_fps * 1.1:  # Performance good
		tick_interval = max(tick_interval * 0.95, TICK_INTERVAL_SECONDS * 0.5)

# Public interface for dynamic tick control
func set_tick_interval(interval: float) -> void:
	tick_interval = clamp(interval, 0.01, 0.2)  # 100x to 5x speed


func set_speed(new_speed: float) -> void:
	game_speed = max(new_speed, 0.0001)
	is_paused = false
	speed_changed.emit(game_speed, is_paused)


func set_speed_index(i: int) -> void:
	if i < 0 or i >= SPEED_STEPS.size():
		return
	set_speed(SPEED_STEPS[i])


func pause() -> void:
	if is_paused:
		return
	is_paused = true
	speed_changed.emit(game_speed, is_paused)


func resume() -> void:
	if not is_paused:
		return
	is_paused = false
	speed_changed.emit(game_speed, is_paused)


func toggle_pause() -> void:
	if is_paused:
		resume()
	else:
		pause()


func add_global_stress(amount: int) -> void:
	global_stress = clampi(global_stress + amount, 0, 1_000_000)


## Used by `GameSave` on load. Preserves the loaded tick; resets accumulator
## so a save mid-frame doesn't double-fire the next sim step.
func set_state_from_load(tick: int, speed: float, paused: bool) -> void:
	tick_count = max(0, tick)
	_tick_accumulator = 0.0
	game_speed = max(speed, 0.0001)
	is_paused = paused
	speed_changed.emit(game_speed, is_paused)
