extends Node

## Emitted once per simulation tick. All simulation systems should listen to this
## instead of running on _process, so pause/speed affects everything uniformly.
signal game_tick(tick_count: int)

## Emitted whenever the speed or pause state changes. UI can listen to update icons.
signal speed_changed(new_speed: float, is_paused: bool)

## Real seconds per tick at 1x. Must match [member SimTime.TICK_INTERVAL_SECONDS]
## (autoloads load before [class_name] resolution; keep numerically in sync).
## HeelKawn feel target: 1x = one deterministic tick each real second.
const TICK_INTERVAL_SECONDS: float = 1.0

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
## Keep caps modest at 26x–100x: each tick runs full colony AI + settlement passes;
## a catch-up frame with 32 ticks was freezing the renderer at extreme speeds.
const MAX_TICKS_PER_FRAME: int = 6
const MAX_TICKS_PER_FRAME_FAST: int = 10
const MAX_TICKS_PER_FRAME_ULTRA: int = 14
const MAX_TICKS_PER_FRAME_EXTREME: int = 16
## At 1x we preserve "real-life cadence" feel: never run more than one
## deterministic tick inside a single rendered frame.
const MAX_TICKS_PER_FRAME_AT_1X: int = 1
## Prevent runaway catch-up after a hitch. We keep sim responsive by dropping
## excessive backlog instead of trying to replay seconds of queued ticks.
const MAX_ACCUMULATED_TICKS: int = 16
## At high game speeds, allow a larger time buffer so fast-forward does not
## stall waiting on the accumulator cap.
const MAX_ACCUMULATED_TICKS_FAST: int = 128
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
## How many [signal game_tick] emissions ran in the last _process frame (diagnostics).
var ticks_emitted_last_frame: int = 0
## Wall time spent inside [signal game_tick] listeners last frame (microseconds).
var last_frame_game_tick_usecs: int = 0
## True if we stopped emitting this frame only because we hit [member MAX_TICKS_PER_FRAME]
## (or speed-tier cap) while sim time was still owed — catch-up continues next frames.
var last_frame_tick_cap_backlog: bool = false
## Adaptive per-frame cap used this frame after hitch smoothing.
var adaptive_ticks_cap_last_frame: int = 0
var _last_slow_tick_log_msec: int = -1_000_000
var _last_catchup_hint_log_msec: int = -1_000_000


func verbose_logs() -> bool:
	return VERBOSE_SIM_LOGS


## Lightweight read-only snapshot for HUD / tooling (tick backlog estimate in sim steps).
func sim_diag() -> Dictionary:
	var queued_ticks_est: float = _tick_accumulator / TICK_INTERVAL_SECONDS
	var active_ticks_per_frame_cap: int = _max_ticks_per_frame_for_speed()
	var acc_cap: int = _max_accumulated_ticks_for_speed()
	return {
		"tick_count": tick_count,
		"speed": game_speed,
		"paused": is_paused,
		"max_ticks_per_frame": active_ticks_per_frame_cap,
		"max_accumulated_ticks": acc_cap,
		"accumulator_sec": _tick_accumulator,
		"queued_ticks_est": queued_ticks_est,
		"ticks_emitted_last_frame": ticks_emitted_last_frame,
		"last_frame_game_tick_ms": last_frame_game_tick_usecs / 1000.0,
		"last_frame_tick_cap_backlog": last_frame_tick_cap_backlog,
		"adaptive_ticks_cap_last_frame": adaptive_ticks_cap_last_frame,
	}


## Debug: explain visible freezes — heavy [signal game_tick] work vs normal catch-up cap.
func _maybe_log_sim_hitch(ticks_this_frame: int, frame_tick_cap: int, tick_chain_usecs: int) -> void:
	if not OS.is_debug_build():
		return
	var now_ms: int = Time.get_ticks_msec()
	var slow_ms: float = tick_chain_usecs / 1000.0
	if slow_ms >= 25.0:
		if now_ms - _last_slow_tick_log_msec < 3000:
			return
		_last_slow_tick_log_msec = now_ms
		print(
				"[SIM_HITCH] %.1f ms inside game_tick this frame | ticks=%d at %.0fx (cap %d/tick) | cause: slow listeners (pawn AI, Main, jobs, memory…)"
				% [slow_ms, ticks_this_frame, game_speed, frame_tick_cap]
		)
		print(
				"[SIM_HITCH] tip: F10 → ERROR report; reduce speed; check sim_diag.last_frame_game_tick_ms & queued_ticks_est."
		)
		return
	if last_frame_tick_cap_backlog:
		if now_ms - _last_catchup_hint_log_msec < 10000:
			return
		_last_catchup_hint_log_msec = now_ms
		print(
				"[SIM_CATCHUP] max %d sim ticks this frame at %.0fx; ~%.1f ticks still queued (spread across frames — not a single frozen tick)."
				% [frame_tick_cap, game_speed, _tick_accumulator / TICK_INTERVAL_SECONDS]
		)


func _max_ticks_per_frame_for_speed() -> int:
	if game_speed <= 1.0:
		return MAX_TICKS_PER_FRAME_AT_1X
	if game_speed >= 100.0:
		return MAX_TICKS_PER_FRAME_EXTREME
	if game_speed >= 50.0:
		return MAX_TICKS_PER_FRAME_ULTRA
	if game_speed >= 26.0:
		return MAX_TICKS_PER_FRAME_FAST
	return MAX_TICKS_PER_FRAME


func _max_accumulated_ticks_for_speed() -> int:
	if game_speed >= 50.0:
		return MAX_ACCUMULATED_TICKS_FAST
	if game_speed >= 26.0:
		return max(MAX_ACCUMULATED_TICKS, 48)
	return MAX_ACCUMULATED_TICKS


func _adaptive_frame_tick_cap(base_cap: int) -> int:
	if game_speed < 26.0:
		return base_cap
	if ticks_emitted_last_frame <= 0 or last_frame_game_tick_usecs <= 0:
		return base_cap
	var avg_tick_ms: float = (last_frame_game_tick_usecs / 1000.0) / float(maxi(1, ticks_emitted_last_frame))
	if avg_tick_ms <= 0.0:
		return base_cap
	# Keep each rendered frame around this sim-listener budget.
	var target_ms: float = 24.0
	var allowed: int = int(floor(target_ms / avg_tick_ms))
	allowed = maxi(1, allowed)
	# Hard guardrails for smoothness at ultra speeds: avoid sudden "14 ticks in one frame" bursts.
	var speed_guard_cap: int = base_cap
	if game_speed >= 100.0:
		speed_guard_cap = 6
	elif game_speed >= 50.0:
		speed_guard_cap = 8
	elif game_speed >= 26.0:
		speed_guard_cap = 10
	return mini(mini(base_cap, speed_guard_cap), allowed)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	if is_paused:
		ticks_emitted_last_frame = 0
		last_frame_game_tick_usecs = 0
		last_frame_tick_cap_backlog = false
		return
	var desired_add: float = delta * game_speed
	var max_accumulator: float = TICK_INTERVAL_SECONDS * float(_max_accumulated_ticks_for_speed())
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
	var frame_tick_cap_base: int = _max_ticks_per_frame_for_speed()
	var frame_tick_cap: int = _adaptive_frame_tick_cap(frame_tick_cap_base)
	var ticks_this_frame: int = 0
	var tick_chain_usecs: int = 0
	while _tick_accumulator >= TICK_INTERVAL_SECONDS and ticks_this_frame < frame_tick_cap:
		_tick_accumulator -= TICK_INTERVAL_SECONDS
		tick_count += 1
		var t0: int = Time.get_ticks_usec()
		game_tick.emit(tick_count)
		tick_chain_usecs += Time.get_ticks_usec() - t0
		ticks_this_frame += 1
	ticks_emitted_last_frame = ticks_this_frame
	adaptive_ticks_cap_last_frame = frame_tick_cap
	last_frame_game_tick_usecs = tick_chain_usecs
	last_frame_tick_cap_backlog = (
			ticks_this_frame >= frame_tick_cap
			and _tick_accumulator >= TICK_INTERVAL_SECONDS
	)
	_maybe_log_sim_hitch(ticks_this_frame, frame_tick_cap, tick_chain_usecs)


func set_speed(new_speed: float) -> void:
	var clamped_speed: float = max(new_speed, 0.0001)
	var prev_speed: float = game_speed
	var nearest_idx: int = 0
	var nearest_dist: float = 1.0e20
	for i in range(SPEED_STEPS.size()):
		var d: float = absf(SPEED_STEPS[i] - clamped_speed)
		if d < nearest_dist:
			nearest_dist = d
			nearest_idx = i
	# Snap all speed changes to explicit toolbar tiers so no hidden fractional or
	# unintended values can leak into runtime.
	game_speed = SPEED_STEPS[nearest_idx]
	if game_speed < prev_speed:
		# If the player drops from ultra speed (50x/100x) to a lower tier, stale
		# queued time can stay far above the new cap and make 1x feel frozen for
		# a long drain window. Clamp to the current tier cap on explicit slowdown.
		var max_accumulator: float = TICK_INTERVAL_SECONDS * float(_max_accumulated_ticks_for_speed())
		if _tick_accumulator > max_accumulator:
			_tick_accumulator = max_accumulator
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
