extends Node

## Emitted once per simulation tick. All simulation systems should listen to this
## instead of running on _process, so pause/speed affects everything uniformly.
signal game_tick(tick_count: int)

## Emitted whenever the speed or pause state changes. UI can listen to update icons.
signal speed_changed(new_speed: float, is_paused: bool)

## Real seconds per tick at 1x. Must match [member SimTime.TICK_INTERVAL_SECONDS] (autoloads load before [class_name] resolution; keep numerically in sync).
const TICK_INTERVAL_SECONDS: float = 0.1

## Allowed speed multipliers. Index into this with set_speed_index(). 12x is the
## "overnight farming" tier -- fine for running an established colony, but at
## this rate a single _process frame can queue many sim ticks so any per-tick
## work (pathing, allocations) amplifies. Keep hot paths cheap.
const SPEED_STEPS: Array[float] = [1.0, 3.0, 6.0, 12.0, 26.0, 50.0, 100.0]
## Set true only when actively debugging pawn/animal internals.
const VERBOSE_SIM_LOGS: bool = false
## Hard cap to prevent "catch-up storms" where one slow frame triggers hundreds
## of ticks and causes visible stutter. Extra accumulated time stays buffered
## and is processed over subsequent frames.
const MAX_TICKS_PER_FRAME: int = 6
## Prevent runaway catch-up after a hitch. We keep sim responsive by dropping
## excessive backlog instead of trying to replay seconds of queued ticks.
const MAX_ACCUMULATED_TICKS: int = 16
## HeelKawn feel target prefers ordered causality over hitch masking.
## When false, we never discard queued sim time; ticks are processed in order.
const DROP_BACKLOG_WHEN_OVER_CAP: bool = false

var game_speed: float = 1.0
var is_paused: bool = false
var tick_count: int = 0
## Worker mode disables play/UI-heavy codepaths for deterministic headless runs.
var simulation_worker_mode: bool = false
var _tick_benchmark_enabled: bool = false

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
	var desired_add: float = delta * game_speed
	var max_accumulator: float = TICK_INTERVAL_SECONDS * float(MAX_ACCUMULATED_TICKS)
	if DROP_BACKLOG_WHEN_OVER_CAP:
		_tick_accumulator += desired_add
		if _tick_accumulator > max_accumulator:
			_tick_accumulator = max_accumulator
	else:
		# Soft clamp: never discard already-queued sim time (no tick skipping),
		# but also never let the backlog grow without bound (prevents rubber banding).
		if _tick_accumulator >= max_accumulator:
			desired_add = 0.0
		elif _tick_accumulator + desired_add > max_accumulator:
			desired_add = maxf(0.0, max_accumulator - _tick_accumulator)
		_tick_accumulator += desired_add
	var ticks_this_frame: int = 0
	while _tick_accumulator >= TICK_INTERVAL_SECONDS and ticks_this_frame < MAX_TICKS_PER_FRAME:
		_tick_accumulator -= TICK_INTERVAL_SECONDS
		tick_count += 1
		game_tick.emit(tick_count)
		ticks_this_frame += 1


func set_speed(new_speed: float) -> void:
	game_speed = max(new_speed, 0.0001)
	is_paused = false
	speed_changed.emit(game_speed, is_paused)


func set_simulation_worker_mode(enabled: bool) -> void:
	simulation_worker_mode = enabled


func set_tick_benchmark_enabled(enabled: bool) -> void:
	_tick_benchmark_enabled = enabled


func is_tick_benchmark_enabled() -> bool:
	return _tick_benchmark_enabled


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
