extends Node

## Emitted once per simulation tick. All simulation systems should listen to this
## instead of running on _process, so pause/speed affects everything uniformly.
signal game_tick(tick_count: int)

## Emitted whenever the speed or pause state changes. UI can listen to update icons.
signal speed_changed(new_speed: float, is_paused: bool)

## Real seconds per tick at 1x speed. Kept low so the sim feels responsive.
const TICK_INTERVAL_SECONDS: float = 0.008
const MIN_TICK_INTERVAL_SECONDS: float = 0.008
const MAX_TICK_INTERVAL_SECONDS: float = 0.05
const BENCHMARK_DEFAULT_TARGET_TICK: int = 1_000_000
const BENCHMARK_DEFAULT_SPEED: float = 16384.0

## Time scale: 60 ticks = 1 real minute = 1 simulation minute
## 1,440 ticks = 1 simulation hour
## 34,560 ticks = 1 simulation day
const TICKS_PER_MINUTE: int = 60
const TICKS_PER_HOUR: int = 1440
const TICKS_PER_DAY: int = 34560

## Allowed speed multipliers with finer granularity for smooth control.
const SPEED_STEPS: Array[float] = [1.0, 4.0, 16.0, 64.0, 256.0, 1024.0, 4096.0, 16384.0]
## Set true only when actively debugging pawn/animal internals.
const VERBOSE_SIM_LOGS: bool = false
## Hard caps to keep the simulation from monopolizing the render frame.
const MAX_TICKS_PER_FRAME: int = 64
const MAX_ACCUMULATED_TICKS: int = 128
const MAX_TICK_PROCESS_TIME_USEC: int = 9000

var tick_interval: float = TICK_INTERVAL_SECONDS
var adaptive_tick_rate: bool = true
var target_fps: float = 60.0

var game_speed: float = 1.0
var is_paused: bool = false
var tick_count: int = 0
var simulation_worker_mode: bool = false
var lightweight_simulation_mode: bool = false

## Optional macro pressure (LivingWorldController and future systems). Not tied to
## a single UI yet; keeps a bounded running total.
var global_stress: int = 0

var _tick_accumulator: float = 0.0
var _tick_pressure: float = 0.0
var _tick_step: int = 1
var _benchmark_enabled: bool = false
var _benchmark_target_tick: int = 0
var _benchmark_start_msec: int = 0
var _benchmark_started: bool = false


func verbose_logs() -> bool:
	return VERBOSE_SIM_LOGS


## Lightweight read-only snapshot for HUD / tooling (tick backlog estimate in sim steps).
func sim_diag() -> Dictionary:
	var queued_ticks_est: float = _tick_accumulator / TICK_INTERVAL_SECONDS
	return {
		"tick_count": tick_count,
		"speed": game_speed,
		"paused": is_paused,
		"tick_step": _tick_step,
		"max_ticks_per_frame": MAX_TICKS_PER_FRAME,
		"max_accumulated_ticks": MAX_ACCUMULATED_TICKS,
		"accumulator_sec": _tick_accumulator,
		"queued_ticks_est": queued_ticks_est,
	}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_apply_benchmark_args()


func _process(delta: float) -> void:
	if is_paused:
		return
	_tick_step = _tick_step_for_speed(game_speed)
	var effective_interval: float = tick_interval * float(_tick_step)
	
	_tick_accumulator += delta * game_speed
	var max_accumulator: float = effective_interval * float(MAX_ACCUMULATED_TICKS)
	if _tick_accumulator > max_accumulator:
		_tick_accumulator = max_accumulator
	
	var ticks_this_frame: int = 0
	var process_start_usec: int = Time.get_ticks_usec()
	var hit_budget_limit: bool = false
	while _tick_accumulator >= effective_interval and ticks_this_frame < MAX_TICKS_PER_FRAME:
		if Time.get_ticks_usec() - process_start_usec >= MAX_TICK_PROCESS_TIME_USEC:
			hit_budget_limit = true
			break
		if _benchmark_enabled and not _benchmark_started:
			_benchmark_started = true
			_benchmark_start_msec = Time.get_ticks_msec()
		_tick_accumulator -= effective_interval
		tick_count += _tick_step
		game_tick.emit(tick_count)
		ticks_this_frame += 1
	if adaptive_tick_rate:
		_adjust_tick_rate_after_frame(ticks_this_frame, hit_budget_limit, Time.get_ticks_usec() - process_start_usec)
	if _benchmark_enabled and tick_count >= _benchmark_target_tick:
		_finish_benchmark_and_quit()

func _adjust_tick_rate_after_frame(ticks_this_frame: int, hit_budget_limit: bool, elapsed_usec: int) -> void:
	var frame_tick_pressure: float = float(ticks_this_frame) / float(MAX_TICKS_PER_FRAME) if MAX_TICKS_PER_FRAME > 0 else 0.0
	var frame_time_pressure: float = float(elapsed_usec) / float(MAX_TICK_PROCESS_TIME_USEC) if MAX_TICK_PROCESS_TIME_USEC > 0 else 0.0
	var pressure: float = max(frame_tick_pressure, frame_time_pressure)
	if hit_budget_limit or pressure >= 0.9:
		_tick_pressure = min(_tick_pressure + 0.18, 1.0)
	elif pressure <= 0.45:
		_tick_pressure = max(_tick_pressure - 0.05, 0.0)
	else:
		_tick_pressure = lerpf(_tick_pressure, pressure, 0.08)
	var target_interval: float = lerpf(MIN_TICK_INTERVAL_SECONDS, MAX_TICK_INTERVAL_SECONDS, _tick_pressure)
	tick_interval = clamp(lerpf(tick_interval, target_interval, 0.22), MIN_TICK_INTERVAL_SECONDS, MAX_TICK_INTERVAL_SECONDS)

# Public interface for dynamic tick control
func set_tick_interval(interval: float) -> void:
	tick_interval = clamp(interval, MIN_TICK_INTERVAL_SECONDS, MAX_TICK_INTERVAL_SECONDS)
	_tick_pressure = 0.0


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


func _tick_step_for_speed(speed: float) -> int:
	if speed >= 16384.0:
		return 2048
	if speed >= 4096.0:
		return 512
	if speed >= 1024.0:
		return 128
	if speed >= 256.0:
		return 32
	if speed >= 64.0:
		return 8
	if speed >= 16.0:
		return 2
	return 1


func _apply_benchmark_args() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.is_empty():
		return
	for arg in args:
		if arg == "--tick-benchmark":
			_benchmark_enabled = true
		elif arg == "--simulation-worker" or arg == "--sim-worker":
			simulation_worker_mode = true
			lightweight_simulation_mode = true
		elif arg == "--lightweight-sim" or arg == "--lite-sim":
			lightweight_simulation_mode = true
		elif arg.begins_with("--tick-target="):
			_benchmark_target_tick = max(1, int(arg.trim_prefix("--tick-target=")))
		elif arg.begins_with("--tick-speed="):
			game_speed = max(1.0, float(arg.trim_prefix("--tick-speed=")))
	if not _benchmark_enabled:
		return
	if _benchmark_target_tick <= 0:
		_benchmark_target_tick = BENCHMARK_DEFAULT_TARGET_TICK
	if game_speed < 1.0:
		game_speed = BENCHMARK_DEFAULT_SPEED
	if simulation_worker_mode:
		lightweight_simulation_mode = true
	is_paused = false
	adaptive_tick_rate = false
	tick_interval = MIN_TICK_INTERVAL_SECONDS
	_tick_pressure = 0.0
	_benchmark_start_msec = -1
	_benchmark_started = false
	print("[TICK_BENCH] start target=%d speed=%.1f" % [_benchmark_target_tick, game_speed])


func is_simulation_worker_mode() -> bool:
	return simulation_worker_mode


func is_tick_benchmark_enabled() -> bool:
	return _benchmark_enabled


func is_lightweight_simulation_mode() -> bool:
	return lightweight_simulation_mode


## Time conversion helpers for UI and simulation systems
func ticks_to_minutes(ticks: int) -> float:
	return float(ticks) / float(TICKS_PER_MINUTE)

func ticks_to_hours(ticks: int) -> float:
	return float(ticks) / float(TICKS_PER_HOUR)

func ticks_to_days(ticks: int) -> float:
	return float(ticks) / float(TICKS_PER_DAY)

func get_simulation_time() -> Dictionary:
	var days: int = tick_count / TICKS_PER_DAY
	var remaining: int = tick_count % TICKS_PER_DAY
	var hours: int = remaining / TICKS_PER_HOUR
	var minutes: int = (remaining % TICKS_PER_HOUR) / TICKS_PER_MINUTE
	return {
		"days": days,
		"hours": hours,
		"minutes": minutes,
		"total_ticks": tick_count
	}

func get_simulation_time_string() -> String:
	var time = get_simulation_time()
	return "Day %d, %02d:%02d" % [time.days, time.hours, time.minutes]


func _finish_benchmark_and_quit() -> void:
	if not _benchmark_enabled:
		return
	_benchmark_enabled = false
	var elapsed_msec: int = maxi(1, Time.get_ticks_msec() - _benchmark_start_msec)
	var elapsed_sec: float = float(elapsed_msec) / 1000.0
	var tps: float = float(tick_count) / elapsed_sec
	print("[TICK_BENCH] done tick=%d elapsed=%.3fs tps=%.1f" % [tick_count, elapsed_sec, tps])
	get_tree().quit()
