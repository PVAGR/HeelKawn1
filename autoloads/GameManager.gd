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
const MAX_TICKS_PER_FRAME: int = 24  # Safety limit: prevents render starvation

## Allowed speed multipliers. Index into this with set_speed_index().
## NOTE: TickManager is now the authoritative source for speed control.
## These steps are kept for reference and backward compatibility.
const SPEED_STEPS: Array[float] = [1.0, 6.0, 26.0, 50.0, 100.0, 200.0]
## Set true only when actively debugging pawn/animal internals.
const VERBOSE_SIM_LOGS: bool = false

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
var _guild_audit_last_tick: int = -1

# --- DIAGNOSTICS: throttled slow-tick logging for game_tick signal ---
var _diag_last_gm_slow_warn_msec: int = 0
const _DIAG_GM_SLOW_THRESH_USEC: int = 16_000  # 16 ms
const _DIAG_GM_SLOW_WARN_THROTTLE_MSEC: int = 3000  # 3 s real time

# --- DIAGNOSTICS: per-listener game_tick profiling (--profile-game-tick) ---
var _gt_profile_enabled: bool = false
var _gt_profile_accum: Dictionary = {}
var _gt_profile_max: Dictionary = {}
var _gt_profile_count: int = 0

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

## --- Resumable game_tick cascade state (driven by TickManager's scheduler) ---
## The heavy ~99-listener game_tick fan-out is now dispatched one callback at a
## time by TickManager (scheduler phase 3), so the full cascade can no longer
## block one rendered frame. Membership is frozen at tick start (tick_processed
## completion semantics); changes during tick N take effect beginning tick N+1.
var _gt_pending_active: bool = false
var _gt_pending_tick: int = -1
var _gt_pending_slots: Array = []
var _gt_pending_index: int = 0
var _gt_pending_total_usec: int = 0
var _gt_pending_ct_slots: bool = false


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
	var active_ticks_per_frame_cap: int = 0
	if TickManager != null and TickManager.has_method("_max_ticks_per_frame_for_speed"):
		active_ticks_per_frame_cap = TickManager._max_ticks_per_frame_for_speed()
	else:
		active_ticks_per_frame_cap = MAX_TICKS_PER_FRAME
	return {
		"tick_count": tick_count,
		"speed": game_speed,
		"paused": is_paused,
		"max_ticks_per_frame": active_ticks_per_frame_cap,
		"max_accumulated_ticks": -1,  # uncapped — TickManager is sole authority
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
	if TickBudgetManager == null:
		return
	var now_ms: int = Time.get_ticks_msec()
	var slow_ms: float = tick_chain_usecs / 1000.0
	if slow_ms >= 25.0:
		if now_ms - _last_slow_tick_log_msec < 3000:
			return
		_last_slow_tick_log_msec = now_ms
		TickBudgetManager.log_throttled(
			"GameManager.sim_hitch.slow",
			"[SIM_HITCH] %.1f ms inside game_tick this frame | ticks=%d at %.0fx (cap %d/tick) | cause: slow listeners (pawn AI, Main, jobs, memory…)"
			% [slow_ms, ticks_this_frame, game_speed, frame_tick_cap]
		)
		TickBudgetManager.log_throttled(
			"GameManager.sim_hitch.tip",
			"[SIM_HITCH] tip: F10 → ERROR report; reduce speed; check sim_diag.last_frame_game_tick_ms & queued_ticks_est."
		)
		return
	if last_frame_tick_cap_backlog:
		if now_ms - _last_catchup_hint_log_msec < 10000:
			return
		_last_catchup_hint_log_msec = now_ms
		TickBudgetManager.log_throttled(
			"GameManager.sim_hitch.catchup",
			"[SIM_CATCHUP] max %d sim ticks this frame at %.0fx; ~%.1f ticks still queued (spread across frames — not a single frozen tick)."
			% [frame_tick_cap, game_speed, _tick_accumulator / TICK_INTERVAL_SECONDS]
		)



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
	## NOTE: The heavy game_tick fan-out is now dispatched by TickManager's
	## resumable scheduler (phase 3) via begin_game_tick_dispatch()/game_tick_step()
	## so it can no longer block one rendered frame. This handler only syncs
	## tick_count (and fires on the lightweight tick_processed completion signal).
	## Do NOT call _dispatch_game_tick() here, or the cascade would run twice.
	return


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
			"--profile-game-tick":
				_gt_profile_enabled = true


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


## Robust invokability guard for a [signal game_tick] listener Callable.
## [method Callable.is_valid] alone is NOT sufficient: a Callable whose bound
## object was freed / queued for deletion (or nulled by the engine) can still
## round-trip [code]is_valid() == true[/code], and invoking it is exactly what
## produced the "Attempt to call function 'null::_on_game_tick (Callable)' on a
## null instance" crash (TickManager._run_one_callback -> GameManager.game_tick_step).
## Checks structural validity, a non-null live object, node/refcount liveness, and
## that the bound method still exists on the target.
func _is_game_tick_cb_invokable(cb: Callable) -> bool:
	if not cb.is_valid():
		return false
	var obj: Object = cb.get_object()
	if obj == null:
		return false
	if not is_instance_valid(obj):
		return false
	if obj is Node and (obj as Node).is_queued_for_deletion():
		return false
	var m: StringName = cb.get_method()
	if m == StringName():
		return false
	if not obj.has_method(m):
		return false
	return true


## Remove a stale [signal game_tick] listener from the PERSISTENT signal so it
## cannot re-enter future dispatches. Does NOT touch the active snapshot — callers
## remove from the snapshot at their own exact cursor to guarantee no listener is
## skipped or double-called. Disconnect is guarded: a freed / null-object Callable
## that `disconnect` cannot address natively is skipped (the engine auto-severs
## connections of really-freed objects; our snapshot guard handles the window).
func _prune_stale_game_tick_cb(cb: Callable) -> void:
	var obj: Object = cb.get_object()
	if obj == null:
		return
	if not is_instance_valid(obj):
		return
	if obj is Node and (obj as Node).is_queued_for_deletion():
		return
	if game_tick.is_connected(cb):
		game_tick.disconnect(cb)



## the resumable cascade. Called by TickManager at sim-tick start (scheduler
## phase 3). Also sets [member tick_count] so game_tick listeners read the
## current tick exactly as the previous synchronous path did.
func begin_game_tick_dispatch(tick: int) -> void:
	_gt_pending_tick = tick
	_gt_pending_slots.clear()
	_gt_pending_index = 0
	_gt_pending_total_usec = 0
	_gt_pending_ct_slots = CrashTrap.should_trace_game_tick_dispatch(tick)
	var conns: Array = get_signal_connection_list(&"game_tick")
	for entry_any in conns:
		if not entry_any is Dictionary:
			continue
		var cb_var: Variant = (entry_any as Dictionary).get("callable", null)
		if not cb_var is Callable:
			continue
		var cb: Callable = cb_var as Callable
		# Prune stale (freed / queued-for-deletion / null-object) callables at
		# snapshot time so a freed listener cannot be retained into the dispatch.
		if not _is_game_tick_cb_invokable(cb):
			_prune_stale_game_tick_cb(cb)
			continue
		_gt_pending_slots.append(cb)
	tick_count = tick
	_gt_pending_active = _gt_pending_slots.size() > 0
	if _gt_pending_ct_slots:
		CrashTrap.log_tick_event("dispatch_start", "tick=%d listeners=%d" % [tick, _gt_pending_slots.size()])


## Dispatch EXACTLY ONE pending game_tick callback (scheduler phase 3 step).
## Returns true if more callbacks remain for this tick, false when the cascade
## (and thus the tick's game_tick phase) is complete.
func game_tick_step(_tick: int) -> bool:
	if not _gt_pending_active:
		if _gt_pending_ct_slots and _gt_pending_tick >= 0:
			CrashTrap.log_tick_event("dispatch_end", "processed %d listeners" % _gt_pending_slots.size())
			_gt_pending_ct_slots = false
		return false
	var cb: Callable = _gt_pending_slots[_gt_pending_index]
	# Staleness guard: if this listener's target was freed / queued for deletion /
	# nulled since the snapshot was taken, prune it at the CURRENT index (so the
	# next valid listener shifts into place and is NOT skipped / double-called)
	# and continue the cascade. Never invoke a freed-object Callable.
	if not _is_game_tick_cb_invokable(cb):
		if trace_game_tick_dispatch:
			print("[GameManager] game_tick(%d) prune stale listener %s" % [_gt_pending_tick, _format_game_tick_callable(cb, _gt_pending_index + 1, _gt_pending_slots.size())])
		_prune_stale_game_tick_cb(cb)
		_gt_pending_slots.pop_at(_gt_pending_index)
		if _gt_pending_slots.is_empty():
			_gt_pending_active = false
			if _gt_pending_ct_slots and _gt_pending_tick >= 0:
				CrashTrap.log_tick_event("dispatch_end", "processed %d listeners (pruned)" % 0)
				_gt_pending_ct_slots = false
			return false
		return true
	var label: String = _format_game_tick_callable(cb, _gt_pending_index + 1, _gt_pending_slots.size())
	last_game_tick_listener_label = label
	if trace_game_tick_dispatch:
		print("[GameManager] game_tick(%d) dispatch %s" % [_gt_pending_tick, label])
	if _gt_pending_ct_slots:
		CrashTrap.enter_system("listener:%s" % label)
	var cb_start_us: int = Time.get_ticks_usec()
	cb.call(_gt_pending_tick)
	var cb_elapsed_us: int = Time.get_ticks_usec() - cb_start_us
	_gt_pending_total_usec += cb_elapsed_us
	if _gt_profile_enabled:
		_gt_profile_accum[label] = int(_gt_profile_accum.get(label, 0)) + cb_elapsed_us
		_gt_profile_max[label] = maxi(int(_gt_profile_max.get(label, 0)), cb_elapsed_us)
	if trace_game_tick_dispatch and cb_elapsed_us >= 1000:
		var debug_suffix: String = ""
		var cb_obj: Object = cb.get_object()
		if cb_obj != null and is_instance_valid(cb_obj):
			if cb_obj.has_method("get_state_name"):
				var st: String = str(cb_obj.call("get_state_name"))
				var job_lbl: String = ""
				if cb_obj.has_method("get_current_job_label"):
					job_lbl = str(cb_obj.call("get_current_job_label"))
				debug_suffix = " state=%s job=%s" % [st, job_lbl]
		print(
				"[GameManager] game_tick(%d) timing %s = %.2fms%s"
				% [_gt_pending_tick, label, float(cb_elapsed_us) / 1000.0, debug_suffix]
		)
	if _gt_pending_ct_slots:
		CrashTrap.exit_system("listener:%s" % label)
	_gt_pending_index += 1
	if _gt_pending_index >= _gt_pending_slots.size():
		_gt_pending_active = false
		if _gt_pending_ct_slots:
			CrashTrap.log_tick_event("dispatch_end", "processed %d listeners" % _gt_pending_slots.size())
			_gt_pending_ct_slots = false
		# DIAGNOSTICS: throttled slow-tick warning for the full game_tick cascade.
		if _gt_pending_total_usec > _DIAG_GM_SLOW_THRESH_USEC:
			var now_ms: int = Time.get_ticks_msec()
			if now_ms - _diag_last_gm_slow_warn_msec >= _DIAG_GM_SLOW_WARN_THROTTLE_MSEC:
				_diag_last_gm_slow_warn_msec = now_ms
				var speed_str: String = "%sx" % str(game_speed)
				var cap_val: int = (TickManager._max_ticks_per_frame_for_speed() if TickManager != null and TickManager.has_method("_max_ticks_per_frame_for_speed") else MAX_TICKS_PER_FRAME)
				print("[GM_DIAG] tick=%d elapsed=%dus listeners=%d speed=%s cap=%d" % [
					_gt_pending_tick, _gt_pending_total_usec, _gt_pending_slots.size(), speed_str, cap_val
				])
		return false
	return true


## Invokes [signal game_tick] listeners in engine order. Traced mode logs each slot first
## (GDScript cannot try/catch most runtime faults — see [member trace_game_tick_dispatch]).
## [CrashTrap] can add tick-1 per-listener ENTER/EXIT when [method CrashTrap.should_trace_game_tick_dispatch] is true.
func _dispatch_game_tick(tick: int) -> void:
	var ct_slots: bool = CrashTrap.should_trace_game_tick_dispatch(tick)
	var trace_slots: bool = trace_game_tick_dispatch or ct_slots
	if not trace_slots and not _gt_profile_enabled:
		var _gm_t0: int = Time.get_ticks_usec()
		game_tick.emit(tick)
		var _gm_elapsed: int = Time.get_ticks_usec() - _gm_t0
		# DIAGNOSTICS: throttled slow-tick warning for game_tick listeners
		if _gm_elapsed > _DIAG_GM_SLOW_THRESH_USEC:
			var now_ms: int = Time.get_ticks_msec()
			if now_ms - _diag_last_gm_slow_warn_msec >= _DIAG_GM_SLOW_WARN_THROTTLE_MSEC:
				_diag_last_gm_slow_warn_msec = now_ms
				var conn_list: Array = get_signal_connection_list(&"game_tick")
				var listener_count: int = 0
				for entry in conn_list:
					if entry is Dictionary:
						listener_count += 1
				var speed_str: String = "%sx" % str(game_speed)
				var cap_val: int = (TickManager._max_ticks_per_frame_for_speed() if TickManager != null and TickManager.has_method("_max_ticks_per_frame_for_speed") else MAX_TICKS_PER_FRAME)
				print("[GM_DIAG] tick=%d elapsed=%dus listeners=%d speed=%s cap=%d" % [
					tick, _gm_elapsed, listener_count, speed_str, cap_val
				])
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
		# Prune stale (freed / queued-for-deletion / null-object) callables so the
		# synchronous fallback never invokes a freed listener either.
		if not _is_game_tick_cb_invokable(cb):
			_prune_stale_game_tick_cb(cb)
			continue
		_slots_cache.append(cb)
		n += 1
	var slots: Array[Callable] = _slots_cache
	if ct_slots:
		CrashTrap.log_tick_event("dispatch_start", "tick=%d listeners=%d" % [tick, n])
	for idx in range(n):
		var cb2: Callable = slots[idx]
		if not _is_game_tick_cb_invokable(cb2):
			_prune_stale_game_tick_cb(cb2)
			continue
		var label: String = _format_game_tick_callable(cb2, idx + 1, n)
		last_game_tick_listener_label = label
		if trace_game_tick_dispatch:
			print("[GameManager] game_tick(%d) dispatch %s" % [tick, label])
		if ct_slots:
			CrashTrap.enter_system("listener:%s" % label)
		var cb_start_us: int = Time.get_ticks_usec()
		cb2.call(tick)
		var cb_elapsed_us: int = Time.get_ticks_usec() - cb_start_us
		if _gt_profile_enabled:
			_gt_profile_accum[label] = int(_gt_profile_accum.get(label, 0)) + cb_elapsed_us
			_gt_profile_max[label] = maxi(int(_gt_profile_max.get(label, 0)), cb_elapsed_us)
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
	if _gt_profile_enabled:
		_gt_profile_count += 1
		if _gt_profile_count >= 1000:
			_gt_profile_count = 0
			var prof_entries: Array = []
			for pl in _gt_profile_accum:
				prof_entries.append({"label": str(pl), "usec": int(_gt_profile_accum[pl])})
			prof_entries.sort_custom(func(a, b): return int(a["usec"]) > int(b["usec"]))
			for pi in range(mini(prof_entries.size(), 10)):
				var pe: Dictionary = prof_entries[pi]
				print("[GT_PROFILE] %s=%.2fms" % [str(pe["label"]), float(pe["usec"]) / 1000.0])
			var max_entries: Array = []
			for pl in _gt_profile_max:
				max_entries.append({"label": str(pl), "usec": int(_gt_profile_max[pl])})
			max_entries.sort_custom(func(a, b): return int(a["usec"]) > int(b["usec"]))
			for pi in range(mini(max_entries.size(), 8)):
				var me: Dictionary = max_entries[pi]
				print("[GT_MAX] %s=%.2fms" % [str(me["label"]), float(me["usec"]) / 1000.0])
			_gt_profile_accum.clear()
			_gt_profile_max.clear()


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
	## Fallback: if TickManager not active, process accumulated ticks with safety cap
	var desired_add: float = delta * game_speed
	_tick_accumulator += desired_add
	var ticks_this_frame: int = 0
	var tick_chain_usecs: int = 0
	var frame_cap: int = MAX_TICKS_PER_FRAME
	if has_node("/root/TickManager"):
		var tm = get_node("/root/TickManager")
		if tm != null and tm.has_method("_max_ticks_per_frame_for_speed"):
			frame_cap = tm._max_ticks_per_frame_for_speed()
	while _tick_accumulator >= TICK_INTERVAL_SECONDS and ticks_this_frame < frame_cap:
		_tick_accumulator -= TICK_INTERVAL_SECONDS
		tick_count += 1
		var t0: int = Time.get_ticks_usec()
		_dispatch_game_tick(tick_count)
		tick_chain_usecs += Time.get_ticks_usec() - t0
		ticks_this_frame += 1
	ticks_emitted_last_frame = ticks_this_frame
	if has_node("/root/TickManager"):
		var tm = get_node("/root/TickManager")
		if tm != null and tm.has_method("_max_ticks_per_frame_for_speed"):
			adaptive_ticks_cap_last_frame = tm._max_ticks_per_frame_for_speed()
		else:
			adaptive_ticks_cap_last_frame = MAX_TICKS_PER_FRAME
	else:
		adaptive_ticks_cap_last_frame = MAX_TICKS_PER_FRAME
	last_frame_game_tick_usecs = tick_chain_usecs
	last_frame_tick_cap_backlog = false


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
		# Clear accumulated backlog on deceleration to prevent event flood.
		# This ensures instant smooth playback at the new speed without
		# catch-up bursts from previously queued time.
		_tick_accumulator = 0.0
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


func get_speed_index() -> int:
	var best_idx: int = 0
	var best_dist: float = 999999.0
	for i in range(SPEED_STEPS.size()):
		var d: float = absf(SPEED_STEPS[i] - game_speed)
		if d < best_dist:
			best_dist = d
			best_idx = i
	return best_idx


func pause() -> void:
	if is_paused:
		return
	is_paused = true
	_reset_frame_pacing_history()
	# GameManager is the SINGLE pause authority. There is nothing to push to
	# TickManager: TickManager asks GameManager.is_paused each frame.
	speed_changed.emit(game_speed, is_paused)


func resume() -> void:
	if not is_paused:
		return
	is_paused = false
	_reset_frame_pacing_history()
	# GameManager is the SINGLE pause authority. There is nothing to push to
	# TickManager: TickManager asks GameManager.is_paused each frame.
	speed_changed.emit(game_speed, is_paused)


func toggle_pause() -> void:
	if is_paused:
		resume()
	else:
		pause()


enum StartState {
	NAKED,       # alone, no tools, no shelter — pure survival
	PIONEER,     # small group, basic tools, some food
	ESTABLISHED, # larger group, full tools, shelter, stockpile
	LEGACY,      # existing world continuation
}

var start_state: int = StartState.PIONEER

func set_start_state(state: int) -> void:
	start_state = state
	WorldMemory.record_event({
		"kind": WorldMemory.Kind.LIFE_EVENT,
		"tick": tick_count,
		"start_state": state,
	})

func get_start_state() -> int:
	return start_state

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
	# Sync TickManager's SPEED to the loaded value (speed authority stays with
	# TickManager). Pause is NOT propagated: GameManager is the single pause
	# authority and TickManager reads GameManager.is_paused directly, so the
	# loaded is_paused above is already authoritative.
	if typeof(TickManager) != TYPE_NIL and TickManager != null:
		TickManager.set_speed(game_speed)
	speed_changed.emit(game_speed, is_paused)
