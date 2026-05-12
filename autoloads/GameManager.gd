extends Node

## Emitted once per simulation tick. All simulation systems should listen to this
## instead of running on _process, so pause/speed affects everything uniformly.
## NOTE: This signal is now emitted by TickManager.tick_processed via _on_tick_manager_tick().
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
## NOTE: TickManager is now the authoritative source for speed control.
## These steps are kept for reference and backward compatibility.
const SPEED_STEPS: Array[float] = [1.0, 3.0, 6.0, 12.0, 26.0, 50.0, 100.0]
## Set true only when actively debugging pawn/animal internals.
const VERBOSE_SIM_LOGS: bool = false
## Hard cap to prevent "catch-up storms" where one slow frame triggers hundreds
## of ticks and causes visible stutter. Extra accumulated time stays buffered
## and is processed over subsequent frames.
## Keep caps modest at 26x–100x: each tick runs full colony AI + settlement passes;
## a catch-up frame with 32 ticks was freezing the renderer at extreme speeds.
const MAX_TICKS_PER_FRAME: int = 3
const MAX_TICKS_PER_FRAME_FAST: int = 6
const MAX_TICKS_PER_FRAME_ULTRA: int = 10
const MAX_TICKS_PER_FRAME_EXTREME: int = 14
## At 1x we preserve "real-life cadence" feel: never run more than one
## deterministic tick inside a single rendered frame.
const MAX_TICKS_PER_FRAME_AT_1X: int = 1
## Prevent runaway catch-up after a hitch. We keep sim responsive by dropping
## excessive backlog instead of trying to replay seconds of queued ticks.
## At 1x the game should feel like a visible clock, not a catch-up reel:
## after a stall, run the next owed tick and discard extra real-time debt.
const MAX_ACCUMULATED_TICKS_AT_1X: int = 1
## 3x can tolerate a small cushion, but not the long post-hitch burst that
## makes first-play pacing look rubber-banded.
const MAX_ACCUMULATED_TICKS_LOW: int = 6
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
## Lightweight mode caps broad queues and gates advanced jobs for benchmark/dev runs.
var lightweight_simulation_mode: bool = false
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

## GDScript has no try/catch for runtime faults. When true, each [signal game_tick] slot is
## invoked in order with a console line naming the target — the **last line printed** before
## a hard stop identifies the crashing listener. Enable with CLI [code]--game-tick-trace[/code]
## (see [method _apply_command_line_flags]); [method set_game_tick_trace_enabled] for tooling.
var trace_game_tick_dispatch: bool = false
## Path / object id and method of the listener currently running (for post-mortem in the editor).
var last_game_tick_listener_label: String = ""

## Pre-allocated variables for performance
var _conns_cache: Array = []
var _slots_cache: Array[Callable] = []


func _reset_frame_pacing_history() -> void:
	ticks_emitted_last_frame = 0
	last_frame_game_tick_usecs = 0
	last_frame_tick_cap_backlog = false
	adaptive_ticks_cap_last_frame = 0


func set_game_tick_trace_enabled(on: bool) -> void:
	trace_game_tick_dispatch = on


func verbose_logs() -> bool:
	if GameSettings != null:
		return bool(GameSettings.get_value("verbose_logs"))
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
	var spd: float = game_speed
	if spd <= 1.0:   return 1
	if spd <= 3.0:   return 3
	if spd <= 6.0:   return 5
	if spd <= 12.0:  return 8
	if spd <= 26.0:  return 12
	if spd <= 50.0:  return 18
	return 28  # 100x - User wants 100x to be much faster than 50x


func _max_accumulated_ticks_for_speed() -> int:
	var spd: float = game_speed
	if spd <= 1.0:   return 2
	if spd <= 3.0:   return 8
	if spd <= 6.0:   return 16
	if spd <= 12.0:  return 32
	if spd <= 26.0:  return 64
	if spd <= 50.0:  return 96
	return 128  # 100x


## Deterministic phase helper for maintenance systems. A positive offset runs
## a task shortly before its old round-number boundary, spreading work while
## preserving a fixed interval and tick-order causality.
func periodic_phase_due(tick: int, interval: int, offset: int = 0) -> bool:
	if tick <= 0 or interval <= 0:
		return false
	var shifted_tick: int = tick + offset
	if shifted_tick < interval:
		return false
	return shifted_tick % interval == 0


func _adaptive_frame_tick_cap(base_cap: int) -> int:
	# Reduced throttling since pf_components performance issue is fixed
	if GameManager == null:
		return base_cap
	var gs: float = GameManager.game_speed
	if gs >= 100.0:
		return maxi(1, base_cap / 2)  # Reduced from /8 to /2
	if gs >= 50.0:
		return maxi(1, base_cap / 1.5)  # Reduced from /4 to /1.5
	if gs >= 26.0:
		return maxi(1, base_cap / 1.2)  # Reduced from /2 to /1.2
	if gs >= 12.0:
		return maxi(1, base_cap / 1.1)  # Reduced from /1.5 to /1.1
	if gs >= 6.0:
		return maxi(1, base_cap / 1.1)  # Reduced from /1.2 to /1.1
	return base_cap


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	## Connect to TickManager for central tick processing
	if has_node("/root/TickManager"):
		var tick_mgr = get_node("/root/TickManager")
		if tick_mgr != null and tick_mgr.has_signal("tick_processed"):
			tick_mgr.tick_processed.connect(_on_tick_manager_tick)
	## Headless [code]-s res://tools/diagnose_tick1.gd[/code] must not advance ticks before that script pauses; start paused when diagnose is on the command line.
	if _cmdline_contains_substring("diagnose_tick1"):
		pause()
	_apply_command_line_flags()


func _on_tick_manager_tick(tick_number: int) -> void:
	## Re-emit as game_tick for backward compatibility
	tick_count = tick_number
	_dispatch_game_tick(tick_number)


func _cmdline_contains_substring(needle: String) -> bool:
	var n: String = needle.to_lower()
	for raw_arg in OS.get_cmdline_args():
		if String(raw_arg).to_lower().find(n) >= 0:
			return true
	return false


func _apply_command_line_flags() -> void:
	## Off by default: debug/editor startup order can run a custom [SceneTree] [code]_ready[/code]
	## before autoload [code]_ready[/code], so a "disable trace" step in boot scripts would be
	## overwritten if we tied this to [code]OS.is_debug_build()[/code]. Use [code]--game-tick-trace[/code]
	## when hunting a crashing [signal game_tick] listener; [code]--no-game-tick-trace[/code] forces off.
	trace_game_tick_dispatch = false
	var args: PackedStringArray = OS.get_cmdline_args()
	for raw_arg in args:
		var arg: String = str(raw_arg)
		match arg:
			"--simulation-worker", "--sim-worker":
				simulation_worker_mode = true
			"--lightweight-sim", "--lite-sim":
				lightweight_simulation_mode = true
			"--game-tick-trace":
				trace_game_tick_dispatch = true
			"--no-game-tick-trace":
				trace_game_tick_dispatch = false


func _format_game_tick_callable(cb: Callable, ordinal: int, total: int) -> String:
	var obj: Object = cb.get_object()
	var mid: StringName = cb.get_method()
	var mid_str: String = str(mid)
	if obj == null:
		return "[%d/%d] <null> :: %s" % [ordinal, total, mid_str]
	if not is_instance_valid(obj):
		return "[%d/%d] <freed> :: %s" % [ordinal, total, mid_str]
	if obj is Node:
		return "[%d/%d] %s :: %s" % [ordinal, total, str((obj as Node).get_path()), mid_str]
	return "[%d/%d] %s :: %s" % [ordinal, total, str(obj), mid_str]


## Invokes [signal game_tick] listeners in engine order. Traced mode logs each slot first
## (GDScript cannot try/catch most runtime faults — see [member trace_game_tick_dispatch]).
## [CrashTrap] can add tick-1 per-listener ENTER/EXIT when [method CrashTrap.should_trace_game_tick_dispatch] is true.
func _dispatch_game_tick(tick: int) -> void:
	var ct_slots: bool = CrashTrap.should_trace_game_tick_dispatch(tick)
	var trace_slots: bool = trace_game_tick_dispatch or ct_slots
	if not trace_slots:
		game_tick.emit(tick)
		return
	# Use pre-allocated cache arrays
	_conns_cache.clear()
	_slots_cache.clear()
	_conns_cache = get_signal_connection_list(&"game_tick")
	var n: int = 0
	for entry_any in _conns_cache:
		if not entry_any is Dictionary:
			continue
		var entry: Dictionary = entry_any as Dictionary
		var cb_var: Variant = entry.get("callable", null)
		if not cb_var is Callable:
			continue
		var cb: Callable = cb_var as Callable
		if not cb.is_valid():
			continue
		_slots_cache.append(cb)
		n += 1
	var slots: Array[Callable] = _slots_cache
	if ct_slots:
		CrashTrap.log_tick_event("dispatch_start", "tick=%d listeners=%d" % [tick, n])
	for idx in range(n):
		var cb2: Callable = slots[idx]
		var label: String = _format_game_tick_callable(cb2, idx + 1, n)
		last_game_tick_listener_label = label
		if trace_game_tick_dispatch:
			print("[GameManager] game_tick(%d) dispatch %s" % [tick, label])
		if ct_slots:
			CrashTrap.enter_system("listener:%s" % label)
		var cb_start_us: int = Time.get_ticks_usec()
		cb2.call(tick)
		var cb_elapsed_us: int = Time.get_ticks_usec() - cb_start_us
		if trace_game_tick_dispatch and cb_elapsed_us >= 1000:
			var debug_suffix: String = ""
			var cb_obj: Object = cb2.get_object()
			if cb_obj != null and is_instance_valid(cb_obj):
				if cb_obj.has_method("get_state_name"):
					var st: String = str(cb_obj.call("get_state_name"))
					var job_lbl: String = ""
					if cb_obj.has_method("get_current_job_label"):
						job_lbl = str(cb_obj.call("get_current_job_label"))
					debug_suffix = " state=%s job=%s" % [st, job_lbl]
			print(
					"[GameManager] game_tick(%d) timing %s = %.2fms%s"
					% [tick, label, float(cb_elapsed_us) / 1000.0, debug_suffix]
			)
		if ct_slots:
			CrashTrap.exit_system("listener:%s" % label)
	if ct_slots:
		CrashTrap.log_tick_event("dispatch_end", "processed %d listeners" % n)


func _process(delta: float) -> void:
	## Tick processing is now handled by TickManager.
	## This _process() only handles pause state updates.
	if is_paused:
		ticks_emitted_last_frame =0
		last_frame_game_tick_usecs = 0
		last_frame_tick_cap_backlog = false
		return
	## If TickManager is active, we don't do tick processing here.
	## TickManager._process() handles the accumulator and emits tick_processed.
	## We just update diagnostics if needed.
	if has_node("/root/TickManager"):
		var tick_mgr = get_node("/root/TickManager")
		if tick_mgr != null and "current_tick" in tick_mgr:
			ticks_emitted_last_frame = 0  # Updated by TickManager
			last_frame_game_tick_usecs = 0  # Updated by TickManager
			last_frame_tick_cap_backlog = false
			return
	## Fallback: if TickManager not active, use legacy tick processing
	var desired_add: float = delta * game_speed
	var max_accumulator: float = TICK_INTERVAL_SECONDS * float(_max_accumulated_ticks_for_speed())
	if DROP_BACKLOG_WHEN_OVER_CAP:
		_tick_accumulator += desired_add
		if _tick_accumulator > max_accumulator:
			_tick_accumulator = max_accumulator
	else:
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
		_dispatch_game_tick(tick_count)
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
	_reset_frame_pacing_history()
	# Keep authoritative TickManager in sync when present
	if typeof(TickManager) != TYPE_NIL and TickManager != null:
		TickManager.set_speed(game_speed)
	# Emit UI notification
	speed_changed.emit(game_speed, is_paused)


func set_simulation_worker_mode(enabled: bool) -> void:
	simulation_worker_mode = enabled


func set_lightweight_simulation_mode(enabled: bool) -> void:
	lightweight_simulation_mode = enabled


func is_lightweight_simulation_mode() -> bool:
	return lightweight_simulation_mode


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
	_reset_frame_pacing_history()
	# Propagate to TickManager so tick emission actually pauses
	if typeof(TickManager) != TYPE_NIL and TickManager != null:
		TickManager.pause()
	speed_changed.emit(game_speed, is_paused)


func resume() -> void:
	if not is_paused:
		return
	is_paused = false
	_reset_frame_pacing_history()
	# Propagate to TickManager so tick emission actually resumes
	if typeof(TickManager) != TYPE_NIL and TickManager != null:
		TickManager.resume()
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
	_reset_frame_pacing_history()
	# Sync TickManager to loaded state when present
	if typeof(TickManager) != TYPE_NIL and TickManager != null:
		TickManager.set_speed(game_speed)
		if is_paused:
			TickManager.pause()
		else:
			TickManager.resume()
	speed_changed.emit(game_speed, is_paused)
