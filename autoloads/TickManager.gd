extends Node
signal tick_processed(tick_number: int)
signal speed_changed(speed_multiplier: float, is_paused: bool)
## HK-TIME-P3: authoritative causal frontier for the completed legacy transaction.
## Emitted AFTER _commit_legacy_core_quantum() and BEFORE tick_processed; the value
## is legacy_core applied world-seconds (NEVER target). Continuous pawn lanes
## integrate against this frontier, never against target.
signal authoritative_continuous_frontier(legacy_core_applied_world_seconds: float)

const SPEED_MULTIPLIERS: Array = [1.0, 6.0, 26.0, 50.0, 100.0, 200.0]
const SPEED_LABELS: Array      = ["1x", "6x", "26x", "50x", "100x", "200x"]
const BASE_TICK_INTERVAL: float = 0.05
const MAX_ACCUMULATOR_SEC: float = 5.0

## P1: HIGH-SPEED BATCHING (coalescing). 
## REAL 200× IMPLEMENTATION: All batch factors set to 1.
## Speed changes how quickly the observer experiences canonical time,
## NOT the amount of discrete behavior per canonical day.
## Discrete systems (job selection, pawn decisions, etc.) run once per
## canonical tick regardless of speed. Speed only affects target rate.
## The committed-target lag will grow at high speeds when CPU cannot
## process all requested ticks - this is honest accounting, not a bug.
## The renderer stays responsive via the slice budget; backlog accumulates.
## Batch factor per speed index (0=1x .. 5=200x). All set to 1.
const SPEED_BATCH_FACTOR: Dictionary = {0:1, 1:1, 2:1, 3:1, 4:1, 5:1}

## ---------------------------------------------------------------------------
## LEGACY-CORE AUTHORITATIVE COMMIT BRIDGE (HK-TIME-ARCH-P2A / P2A.1)
##
## THREE DISTINCT TIME UNITS — never conflate them (unit-conversion contract):
##
##  1. BASE_TICK_INTERVAL (0.05) = REAL scheduler cadence: how often compatibility
##     work is ATTEMPTED per real second. This is NOT simulated world time.
##
##  2. LEGACY_DOMAIN_TICK_INTERVAL (SimTime.TICK_INTERVAL_SECONDS = 1.0) = the OLD
##     tick-domain simulation time unit (one legacy tick == one legacy "sim
##     second", and 600 legacy ticks == one visual day). This value MUST NOT be
##     copied into SimulationClock canonical seconds. SimTime.TICK_INTERVAL_SECONDS
##     SHALL NOT be used directly as a SimulationClock-second conversion.
##
##  3. CANONICAL world seconds (SimulationClock) = the new authoritative world-time
##     unit. Target production: target += real_delta * requested_speed. At 1x one
##     canonical second corresponds to ~1 real second of requested progression.
##
## The bridge converts ONE completed compatibility transaction into CANONICAL
## SimulationClock world seconds. Because the canonical target produces 1.0 s per
## real second at 1x, and the scheduler completes ~BASE_TICK_INTERVAL (0.05 s) of
## real time per transaction at nominal cadence, the canonical quantum is:
##
##   CANONICAL_BRIDGE_QUANTUM = BASE_TICK_INTERVAL * 1x_multiplier = 0.05 * 1.0
##                            = 0.05 canonical world seconds / transaction
##
## Dimensional proof at 1x:
##   20 transactions / real second  *  0.05 canonical s / transaction
##     = 1.0 canonical second / real second  ==  SimulationClock target rate at 1x.
##
## Legacy calendar conversion (NOT migrated here; proves P2B mapping):
##   canonical_seconds_per_visual_day = TICKS_PER_VISUAL_DAY * Q_CANONICAL
##                                     = 600 * 0.05 = 30 s  (preserves old 1x day).
##
## `legacy_core` is the temporary authoritative lane standing in for ALL legacy
## gameplay work still executed through the compatibility pipeline. At COMPLETE
## of a fully-finished transaction it commits exactly CANONICAL_BRIDGE_QUANTUM
## (never more, never the target gap, never speed-scaled). Requested speed changes
## TARGET production, NOT the canonical causal work a single completed transaction
## represents — at high speed target races ahead and committed lag grows, which is
## CORRECT accounting, not a bug to hide.
## ---------------------------------------------------------------------------
const LEGACY_CORE_LANE_ID: StringName = &"legacy_core"
## HK-TIME-P3-FIX2: the ONE system-level authoritative lane that every pawn's
## continuous state integrates through. TickManager owns its registration and
## coordination (never the pawns).
const PAWN_CONTINUOUS_LANE_ID: StringName = &"pawn_continuous"
## HK-TIME-P4: the authoritative lane that owns the IDLE/AI DECISION cadence of
## every pawn. Each pawn schedules its next expensive idle deliberation as a
## per-pawn decision DEADLINE in canonical world-seconds (_next_decision_world_time)
## and advances it by a fixed canonical interval after each due decision. This lane
## is registered BEFORE legacy_core advances (exactly like pawn_continuous) and is
## driven through F (and committed ONLY after EVERY live pawn succeeds) by this
## TickManager-owned coordinator. The pawn's per-pawn apply is PURE: it enumerates
## ACTUAL DUE DECISION deadlines <= F and NEVER commits any lane itself.
const PAWN_DISCRETE_LANE_ID: StringName = &"pawn_discrete"
const LEGACY_DOMAIN_TICK_INTERVAL: float = 1.0  # old tick-domain notation ONLY — NOT canonical seconds
const LEGACY_CORE_CANONICAL_SECONDS_PER_TRANSACTION: float = \
	BASE_TICK_INTERVAL * float(SPEED_MULTIPLIERS[0])  # 0.05 canonical world s / transaction @1x

## P1: effective batch factor for the CURRENT speed index (1 when not batching).
var _batch_factor: int = 1

## Read the configured batch factor for the current speed index.
func get_batch_factor() -> int:
	return _batch_factor

## Recompute _batch_factor from the current speed index. Idempotent; called on
## set_speed_index and at first bridge init. Never below 1.
func _update_batch_factor() -> void:
	_batch_factor = maxi(1, int(SPEED_BATCH_FACTOR.get(_speed_index, 1)))

## The canonical world-seconds represented by ONE completed transaction at the
## current speed (after P1 batching). Continuous lanes coalesce this whole gap.
func canonical_seconds_per_transaction() -> float:
	return LEGACY_CORE_CANONICAL_SECONDS_PER_TRANSACTION * float(get_batch_factor())

## The per-transaction accumulator cost (real-time scheduler units). A batched
## transaction consumes `batch` base-units so the accumulator unwinds at the
## requested speed while emitting fewer (larger) ticks.
func base_units_per_transaction() -> float:
	return BASE_TICK_INTERVAL * float(get_batch_factor())
## Maximum cap per speed index (0=1x through 5=200x). These are maximum caps,
## not targets — the actual number of ticks per frame is further reduced by
## budget-based throttling via [_max_ticks_per_frame_for_speed()].
const MAX_TICKS_PER_FRAME: Dictionary = {0:2, 1:4, 2:8, 3:16, 4:32, 5:64}
const MAX_FRAME_TIME_MS: int = 32

## Resumable cooperative scheduler slice budget (wall-clock, microseconds).
## The simulation gets roughly this much main-thread time per rendered frame
## before yielding back to Godot so rendering/input can proceed. Kept well
## below the 16.67ms 60-FPS frame budget because Godot/render itself needs time.
const SIM_SLICE_BUDGET_USEC: int = 6000
## Any single simulation callback exceeding this is flagged (throttled log).
## A callback itself cannot be preempted, so these identify the NEXT split targets.
const SLOW_CALLBACK_WARN_USEC: int = 8000

## Scheduler phases for the pending-tick state machine.
enum { PHASE_TICKABLES = 0, PHASE_REFCOUNTED = 1, PHASE_GAME_TICK = 2, PHASE_COMPLETE = 3 }

## COMPATIBILITY/SCHEDULER TICK IS NOT SIMULATED WORLD TIME.
## `current_tick` is a monotonic scheduler sequence/heartbeat number used for
## deterministic listener dispatch ordering and legacy compat interfaces during
## migration. It is NOT seconds, NOT days, and NEVER an authoritative measure of
## elapsed world time. Elapsed simulated world time lives ONLY in SimulationClock
## (target / lane-applied / committed). Do not document current_tick as time, do
## not multiply it by game speed, and do not derive committed world time from it.
var current_tick: int = 0
## Game-speed compatibility-tick accumulator. The legacy tick bus accrues
## SPEED-scaled time (sim_delta = real_delta * multiplier), so it emits more
## compat ticks per real second at higher speeds — 100x/200x genuinely do more
## discrete simulation work than 50x, bounded only by the per-frame slice budget
## and the MAX_ACCUMULATOR_SEC backlog cap (kept responsive). The SimulationClock
## continuous lane remains the authoritative world-time source.
var _accumulated_time: float = 0.0
var _speed_index: int = 0

## Diagnostics: measured real-time compatibility tick rate (compat ticks / real s).
var _compat_rate_window_start_msec: int = 0
var _compat_rate_window_ticks: int = 0
var _compat_ticks_emitted: int = 0
var compat_tick_rate_per_real_second: float = 0.0
## P1: measured EFFECTIVE world-time throughput (canonical world-seconds of committed
## causal work per real second). Unlike the compat-tick rate (which counts raw ticks,
## misleading under batching), this reflects how much world history the sim actually
## produced per real second. At 1x it is ~1.0; at 200x with CPU headroom it approaches
## the requested multiplier but is CPU-bounded. Honest ceiling for the F10 snapshot.
var _eff_rate_window_start_msec: int = 0
var _eff_rate_window_committed_start: float = 0.0
var _eff_rate_window_set: bool = false
var effective_world_speed: float = 0.0
## REAL 200×: Committed-target lag in canonical seconds
## How far behind the committed world time is from the target time.
## At high speeds with CPU constraints, this will grow - honest accounting.
var committed_target_lag_seconds: float = 0.0
var _refcounted_tickables: Array = []
var _tickable_cache: Array = []
var _tickable_callables: Array = []
var _tickable_cache_dirty: bool = true
var _prev_speed_index: int = 0

# --- Resumable pending-tick state ---
# A single simulation tick may span several rendered frames. The scheduler
# freezes each listener collection at tick START (membership changes during
# tick N take effect beginning tick N+1), steps one listener per unit of work,
# and yields to the render loop whenever the slice budget is exhausted. The
# pending tick only completes (and only THEN emits tick_processed) after every
# scheduled listener has run exactly once, so tick ordering is preserved and no
# tick is dropped merely for FPS.
var _pending_tick_active: bool = false
var _pending_tick_number: int = -1
var _pending_emit_tick: int = -1
var _pending_tickable_callbacks: Array = []
var _pending_tickable_index: int = 0
var _pending_refcounted_callbacks: Array = []
var _pending_refcounted_index: int = 0
var _pending_phase: int = PHASE_TICKABLES
var _pending_tick_work_usec: int = 0
var _pending_tick_wall_start_usec: int = 0

# --- Truthful timing metrics ---
# debug_last_tick_work_usec: accumulated CPU work actually spent on a sim tick
#   (excludes render-wait / yield time).
# debug_last_tick_wall_usec: real elapsed wall time from tick start to completion
#   (includes yield gaps across frames).
# debug_last_sim_slice_usec: synchronous work consumed by the most recent slice.
# debug_max_sim_callback_usec/name: the single most expensive callback observed.
# debug_last_tick_batch_usec is KEPT as an alias of the per-tick work for legacy
#   readers, but it now reports true CPU work, never render-wait time.
var debug_last_tick_work_usec: int = 0
var debug_last_tick_wall_usec: int = 0
var debug_last_sim_slice_usec: int = 0
var debug_max_sim_callback_usec: int = 0
var debug_max_sim_callback_name: String = ""
var debug_last_tick_batch_usec: int = 0
var _last_tick_usec: int = 0
var _slice_cb_count: int = 0
var _pending_split: Dictionary = {"tickable": 0, "refcounted": 0, "emit": 0}
var _diag_last_slow_callback_msec: int = 0
const _DIAG_SLOW_CALLBACK_THROTTLE_MSEC: int = 2000

var _profile_accum: Dictionary = {
	"neural": 0,
	"jobs": 0,
	"memory": 0,
	"meaning": 0,
	"pathfind": 0,
	"settlement": 0,
}
var _profile_total: int = 0
var _profile_tick_count: int = 0
var _profile_per_path: Dictionary = {}

# --- DIAGNOSTICS: per-tick sub-phase splitting (set _split_mode=true externally) ---
var _split_mode: bool = false
var _split_accum: Dictionary = {"tickable": 0, "refcounted": 0, "emit": 0, "bookkeep": 0}
var _split_count: int = 0
var _split_max: Dictionary = {"tickable": 0, "refcounted": 0, "emit": 0}

# --- DIAGNOSTICS: throttled slow-tick logging (real-time throttle) ---
var _diag_last_slow_warn_msec: int = 0
const _DIAG_SLOW_TICK_THRESH_USEC: int = 16_000  # 16 ms
const _DIAG_SLOW_WARN_THROTTLE_MSEC: int = 3000  # 3 seconds real time

# --- DIAGNOSTICS: tick backlog warning ---
const _DIAG_BACKLOG_WARN_THROTTLE_MSEC: int = 10_000  # 10 s real time
var _diag_last_backlog_warn_msec: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(delta: float) -> void:
	# Pause is a SINGLE authority held by GameManager (GameManager.is_paused).
	# TickManager holds no pause state of its own and simply asks whether the
	# simulation may advance. This is a query, never a synchronized copy.
	if GameManager != null and GameManager.is_paused:
		return
	# Bridge the legacy authoritative lane to SimulationClock's committed contract
	# for the current clock epoch BEFORE any authoritative work advances.
	ensure_legacy_bridge_initialized()
	var sim_delta: float = delta * SPEED_MULTIPLIERS[_speed_index]
	# Advance the authoritative simulated world-clock (multi-rate foundation).
	# World time flows at game speed regardless of how many compat ticks are
	# emitted. advance_target is the canonical writer; advance_sim_time kept as
	# a fallback for older trees.
	if SimulationClock != null:
		if SimulationClock.has_method("advance_target"):
			SimulationClock.advance_target(sim_delta)
		elif SimulationClock.has_method("advance_sim_time"):
			SimulationClock.advance_sim_time(sim_delta)
	# Compatibility-tick bus: bounded to game SPEED (sim_delta), so higher speeds
	# request proportionally more legacy full-world ticks per real second. This is
	# what makes 100x/200x produce materially more simulation progression than
	# 50x when CPU capacity exists. The real per-frame SLICE budget
	# (SIM_SLICE_BUDGET_USEC), the MAX_ACCUMULATOR_SEC backlog cap, and the
	# MAX_TICKS_PER_FRAME/_max_ticks_per_frame_for_speed per-frame caps all remain
	# and keep the render loop responsive under load (the slice yields to Godot).
	_accumulated_time += sim_delta
	# Cap accumulator to prevent death spiral if frame takes too long.
	# The cap bounds backlog; it does NOT drop already-requested sim time below
	# a reasonable overload bound so the sim still catches up without freezing
	# rendering (excess remains pending and carries forward across frames).
	_accumulated_time = minf(_accumulated_time, MAX_ACCUMULATOR_SEC)
	_maybe_warn_backlog()
	var slice_start: int = Time.get_ticks_usec()
	_slice_cb_count = 0
	while true:
		var budget_hit: bool = _run_pending_slice(slice_start)
		if budget_hit:
			break
		# Budget was NOT hit on this slice-run. If the pending tick just
		# completed within budget, try to start the next tick (accumulator keeps
		# unwinding at 200x). Otherwise a bare phase-advance happened; loop to
		# run the next phase's first callback within the same slice.
		if not _pending_tick_active:
			if _accumulated_time < base_units_per_transaction():
				break
			_start_pending_tick()
	debug_last_sim_slice_usec = Time.get_ticks_usec() - slice_start


## Run as many pending-tick steps as the slice budget allows. Returns true when
## the slice budget is exhausted (yield to render). Never drops or reorders any
## listener and never lets tick_processed fire before the tick completes.
func _run_pending_slice(slice_start: int) -> bool:
	var budget: int = SIM_SLICE_BUDGET_USEC
	while _pending_tick_active:
		var dispatched: int = _run_one_callback()
		if dispatched > 0:
			_slice_cb_count += 1
		if Time.get_ticks_usec() - slice_start >= budget:
			return true
		if not _pending_tick_active:
			break
	return false


## Advance the pending tick by exactly ONE unit of work:
## - a single sorted tickable-group callback, OR
## - a single refcounted callback, OR
## - a single game_tick cascade callback, OR
## - a bare phase-advance, OR
## - completion (fires tick_processed once).
## Returns 1 if a real callback ran, 0 otherwise.
func _run_one_callback() -> int:
	match _pending_phase:
		PHASE_TICKABLES:
			if _pending_tickable_index >= _pending_tickable_callbacks.size():
				_pending_phase = PHASE_REFCOUNTED
				_pending_refcounted_index = 0
				return 0
			_dispatch_tickable(_pending_tick_number, _pending_tickable_index)
			_pending_tickable_index += 1
			return 1
		PHASE_REFCOUNTED:
			if _pending_refcounted_index >= _pending_refcounted_callbacks.size():
				if GameManager != null and GameManager.has_method("game_tick_step"):
					_pending_phase = PHASE_GAME_TICK
				else:
					_pending_phase = PHASE_COMPLETE
				return 0
			_dispatch_refcounted(_pending_tick_number, _pending_refcounted_index)
			_pending_refcounted_index += 1
			return 1
		PHASE_GAME_TICK:
			if GameManager != null and GameManager.has_method("game_tick_step"):
				var more: bool = GameManager.game_tick_step(_pending_tick_number)
				if more:
					return 1
			_pending_phase = PHASE_COMPLETE
			return 0
		PHASE_COMPLETE:
			_complete_pending_tick()
			return 0
	return 0


func _start_pending_tick() -> void:
	_accumulated_time -= base_units_per_transaction()
	current_tick += 1
	if _tickable_cache_dirty:
		_rebuild_tickable_cache()
	_pending_tick_active = true
	_pending_tick_number = current_tick
	_pending_emit_tick = current_tick
	_pending_tickable_callbacks = _tickable_callables
	_pending_tickable_index = 0
	# Freeze refcounted membership for THIS tick (changes take effect next tick).
	_pending_refcounted_callbacks = _refcounted_tickables.duplicate()
	_pending_refcounted_index = 0
	_pending_phase = PHASE_TICKABLES
	_pending_tick_work_usec = 0
	_pending_tick_wall_start_usec = Time.get_ticks_usec()
	_pending_split = {"tickable": 0, "refcounted": 0, "emit": 0}
	if GameManager != null and GameManager.has_method("begin_game_tick_dispatch"):
		GameManager.begin_game_tick_dispatch(_pending_tick_number)


func _dispatch_tickable(tick: int, idx: int) -> void:
	var cb: Callable = _pending_tickable_callbacks[idx]
	if cb.is_valid():
		var obj = cb.get_object()
		var t0: int = Time.get_ticks_usec()
		cb.call(tick)
		var dt: int = Time.get_ticks_usec() - t0
		_pending_tick_work_usec += dt
		_pending_split["tickable"] = int(_pending_split["tickable"]) + dt
		if TickProfiler != null and TickProfiler.is_enabled():
			var sys_name: String = _get_system_name(obj)
			var path_str: String = str(obj.get_path())
			TickProfiler.record_callback(dt, path_str)
			if sys_name != "":
				_profile_accum[sys_name] += dt
			_profile_total += dt
			_profile_per_path[path_str] = int(_profile_per_path.get(path_str, 0)) + dt


func _dispatch_refcounted(tick: int, idx: int) -> void:
	var ref: Variant = _pending_refcounted_callbacks[idx]
	if ref != null and ref.has_method("_on_world_tick"):
		var t1: int = Time.get_ticks_usec()
		ref._on_world_tick(tick)
		var dt: int = Time.get_ticks_usec() - t1
		_pending_tick_work_usec += dt
		_pending_split["refcounted"] = int(_pending_split["refcounted"]) + dt
		if TickProfiler != null and TickProfiler.is_enabled():
			var name: String = str(ref.get_path()) if ref is Node else str(ref)
			TickProfiler.record_callback(dt, name)
			_profile_total += dt


## Record per-callback timing and flag any single callback over SLOW_CALLBACK_WARN_USEC.
func _track_callback(dt: int, name: String) -> void:
	if dt > debug_max_sim_callback_usec:
		debug_max_sim_callback_usec = dt
		debug_max_sim_callback_name = name
	if dt > SLOW_CALLBACK_WARN_USEC:
		var now_ms: int = Time.get_ticks_msec()
		if now_ms - _diag_last_slow_callback_msec >= _DIAG_SLOW_CALLBACK_THROTTLE_MSEC:
			_diag_last_slow_callback_msec = now_ms
			print("[SLOW_SIM_CALLBACK] tick=%d phase=%s listener=%s elapsed_us=%d" % [
				_pending_tick_number, _phase_name(_pending_phase), name, dt
			])


## Called once when the final scheduled listener for a tick has run. This is the
## single moment tick_processed may fire, and only after every listener for the
## tick has completed exactly once.
func _complete_pending_tick() -> void:
	_compat_ticks_emitted += 1
	_compat_rate_window_ticks += 1
	var now_ms: int = Time.get_ticks_msec()
	if _compat_rate_window_start_msec == 0:
		_compat_rate_window_start_msec = now_ms
	var elapsed_ms: int = now_ms - _compat_rate_window_start_msec
	if elapsed_ms >= 1000:
		compat_tick_rate_per_real_second = float(_compat_rate_window_ticks) / (float(elapsed_ms) / 1000.0)
		_compat_rate_window_ticks = 0
		_compat_rate_window_start_msec = 0
	# P1: effective world-time throughput (committed canonical seconds per real second).
	var comm_sec: float = 0.0
	var target_sec: float = 0.0
	if SimulationClock != null:
		if SimulationClock.has_method("get_committed_world_time_seconds"):
			comm_sec = float(SimulationClock.get_committed_world_time_seconds())
		if SimulationClock.has_method("get_target_world_time_seconds"):
			target_sec = float(SimulationClock.get_target_world_time_seconds())
	# REAL 200×: Track committed-target lag
	committed_target_lag_seconds = target_sec - comm_sec
	if committed_target_lag_seconds < 0.0:
		committed_target_lag_seconds = 0.0  # Should not happen, but guard
	
	if not _eff_rate_window_set:
		_eff_rate_window_set = true
		_eff_rate_window_start_msec = now_ms
		_eff_rate_window_committed_start = comm_sec
	else:
		var eff_elapsed_ms: int = now_ms - _eff_rate_window_start_msec
		if eff_elapsed_ms >= 1000:
			var d_comm: float = comm_sec - _eff_rate_window_committed_start
			effective_world_speed = d_comm / (float(eff_elapsed_ms) / 1000.0)
			_eff_rate_window_start_msec = now_ms
			_eff_rate_window_committed_start = comm_sec
	var wall: int = Time.get_ticks_usec() - _pending_tick_wall_start_usec
	debug_last_tick_wall_usec = wall
	debug_last_tick_work_usec = _pending_tick_work_usec
	debug_last_tick_batch_usec = _pending_tick_work_usec
	_last_tick_usec = maxi(1, _pending_tick_work_usec)
	var emit_tick: int = _pending_emit_tick
	# Clear pending state BEFORE emitting so any re-entrancy is safe.
	_pending_tick_active = false
	_pending_tick_number = -1
	_pending_emit_tick = -1
	if _split_mode:
		for key in ["tickable", "refcounted", "emit"]:
			var v: int = int(_pending_split[key])
			_split_accum[key] = int(_split_accum[key]) + v
			if v > int(_split_max[key]):
				_split_max[key] = v
		_split_count += 1
		if _split_count >= 60:
			var l: String = ""
			for k in ["tickable", "refcounted", "emit"]:
				var avg: float = float(int(_split_accum[k])) / 60.0
				l += "%s=%.2fms(avg)/%.2fms(max) " % [k, avg / 1000.0, float(int(_split_max[k])) / 1000.0]
			print("[SPLIT] %s" % l)
			for k in _split_accum:
				_split_accum[k] = 0
			for k in _split_max:
				_split_max[k] = 0
			_split_count = 0
	_profile_tick_count += 1
	if _profile_tick_count >= 60:
		_profile_tick_count = 0
		_emit_tick_profile()
	# DIAGNOSTICS: throttled slow-tick warning using TRUE per-tick work time.
	if debug_last_tick_work_usec > _DIAG_SLOW_TICK_THRESH_USEC:
		var now_ms_2: int = Time.get_ticks_msec()
		if now_ms_2 - _diag_last_slow_warn_msec >= _DIAG_SLOW_WARN_THROTTLE_MSEC:
			_diag_last_slow_warn_msec = now_ms_2
			var listener_count: int = _pending_tickable_callbacks.size() + _pending_refcounted_callbacks.size()
			var speed_label: String = SPEED_LABELS[_speed_index] if _speed_index >= 0 and _speed_index < SPEED_LABELS.size() else "?"
			print("[TICK_DIAG] tick=%d work_us=%d wall_us=%d listeners=%d speed=%s" % [
				emit_tick, debug_last_tick_work_usec, debug_last_tick_wall_usec, listener_count, speed_label
			])
	# Only a FULLY completed compatibility transaction commits legacy world
	# history. This is the COMPLETE boundary — every scheduled listener ran
	# exactly once. A transaction that spans frames changes nothing until here.
	# HK-TIME-P3-FIX2 + HK-TIME-P4 ordering per completed transaction:
	#   ensure legacy bridge                      (seals roster, then)
	#   ensure pawn_continuous lane exists        (starts at OLD committed frontier)
	#   ensure pawn_discrete lane exists          (registers BEFORE legacy advances)
	#   commit legacy_core by one quantum         (advances F = legacy_core applied)
	#   run ALL pawn continuous consumers through F; commit pawn_continuous once
	#     after ALL succeed (any failure leaves it at OLD committed)
	#   run ALL pawn discrete decision deadlines <= F; commit pawn_discrete once
	#     after ALL succeed (any failure leaves it at OLD committed)
	#   emit authoritative_continuous_frontier(F)  -> tick_processed
	ensure_legacy_bridge_initialized()
	_ensure_pawn_continuous_lane()
	_ensure_pawn_discrete_lane()
	_commit_legacy_core_quantum()
	_run_pawn_continuous_frontier_wrapper()
	_run_pawn_discrete_frontier_wrapper()
	_emit_authoritative_continuous_frontier()
	tick_processed.emit(emit_tick)


## Idempotent legacy-core bridge initialization for the current clock epoch.
## After a SimulationClock.reset() the roster is unsealed and all lanes are
## cleared; the next epoch that attempts authoritative work re-registers
## legacy_core at frontier 0 and seals the roster. Registration NEVER advances
## committed (P1.2 roster atomicity), and initializing at 0 NEVER fabricates
## processed history. If the roster is already sealed, this is a no-op.
func ensure_legacy_bridge_initialized() -> void:
	if SimulationClock == null:
		return
	if not SimulationClock.has_method("is_authoritative_lane_roster_sealed"):
		return
	_update_batch_factor()
	if SimulationClock.is_authoritative_lane_roster_sealed():
		return  # already bridged for this epoch — idempotent, no reseal, no reset
	SimulationClock.register_authoritative_lane(LEGACY_CORE_LANE_ID, 0.0)
	SimulationClock.seal_authoritative_lane_roster()


## Commit exactly one legacy world-time quantum (in CANONICAL SimulationClock
## seconds) for one completed compatibility transaction. Formula:
##   current = legacy_core applied
##   target  = SimulationClock target
##   next    = min(current + CANONICAL_BRIDGE_QUANTUM, target)
## Commits only if next > current. Never commits to target directly, never
## commits the whole target gap, never advances on a partial/pending transaction,
## never from target advancement. With legacy_core the sole authoritative lane,
## committed follows it via the sealed min rule. The quantum is the canonical
## conversion of one completed transaction (BASE_TICK_INTERVAL * 1x-multiplier),
## NOT the legacy tick-domain SimTime interval.
func _commit_legacy_core_quantum() -> void:
	if SimulationClock == null:
		return
	if not SimulationClock.has_method("get_lane_applied_world_time_seconds") \
			or not SimulationClock.has_method("get_target_world_time_seconds") \
			or not SimulationClock.has_method("commit_lane_world_time"):
		return
	var current: float = float(SimulationClock.get_lane_applied_world_time_seconds(LEGACY_CORE_LANE_ID))
	var target: float = float(SimulationClock.get_target_world_time_seconds())
	var candidate: float = current + canonical_seconds_per_transaction()
	var next: float = minf(candidate, target)
	if next > current:
		SimulationClock.commit_lane_world_time(LEGACY_CORE_LANE_ID, next)


## HK-TIME-P3-FIX2: ensure the pawn_continuous authoritative lane exists for the
## current clock epoch. Called BEFORE the legacy_core commit so that after a
## SimulationClock.reset() (or at start) the lane is registered at the OLD
## committed frontier (0 after reset), NEVER at the newly-advanced F. Idempotent:
## register_dynamic_authoritative_lane returns false when it already exists.
func _ensure_pawn_continuous_lane() -> void:
	if SimulationClock == null:
		return
	if not SimulationClock.has_method("register_dynamic_authoritative_lane"):
		return
	SimulationClock.register_dynamic_authoritative_lane(PAWN_CONTINUOUS_LANE_ID)


## HK-TIME-P3-FIX2: wrapper that computes F = legacy_core applied and drives the
## coordinator over the live "pawns" group. Kept as the direct call site so the
## real coordinator (_run_pawn_continuous_frontier) is trivially testable.
func _run_pawn_continuous_frontier_wrapper() -> void:
	if SimulationClock == null:
		return
	if not SimulationClock.has_method("get_lane_applied_world_time_seconds"):
		return
	var frontier: float = float(SimulationClock.get_lane_applied_world_time_seconds(LEGACY_CORE_LANE_ID))
	_run_pawn_continuous_frontier(frontier)


## HK-TIME-P3-FIX2: the REAL system coordinator. Reads F = legacy_core applied and
## runs EVERY currently-authoritative live pawn in the "pawns" group through F by
## calling its pure _apply_authoritative_continuous_frontier(F). Commits the
## pawn_continuous lane to F ONCE, and ONLY AFTER ALL pawns returned true; ANY
## failed pawn leaves the lane at its OLD applied value and returns false.
func _run_pawn_continuous_frontier(frontier: float) -> bool:
	if SimulationClock == null:
		return false
	if not SimulationClock.has_method("commit_lane_world_time"):
		return false
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var all_ok: bool = true
	var pawns: Array = []
	if tree != null:
		pawns = tree.get_nodes_in_group("pawns")
	for pawn in pawns:
		if pawn == null:
			continue
		if not pawn.has_method("_apply_authoritative_continuous_frontier"):
			continue
		if not pawn._apply_authoritative_continuous_frontier(frontier):
			all_ok = false  # a required pawn failed -> do NOT commit the lane
	if all_ok:
		SimulationClock.commit_lane_world_time(PAWN_CONTINUOUS_LANE_ID, frontier)
	return all_ok


## HK-TIME-P3-FIX2: broadcast the just-committed legacy-core applied frontier (the
## canonical world-seconds this completed transaction causally advanced) so any
## non-pawn continuous consumers can observe it. The pawn_continuous lane has
## ALREADY been driven to F by _run_pawn_continuous_frontier (or left at OLD
## committed when a pawn failed). Reads legacy_core applied -- NEVER target.
func _emit_authoritative_continuous_frontier() -> void:
	var frontier: float = 0.0
	if SimulationClock != null and SimulationClock.has_method("get_lane_applied_world_time_seconds"):
		frontier = float(SimulationClock.get_lane_applied_world_time_seconds(LEGACY_CORE_LANE_ID))
	authoritative_continuous_frontier.emit(frontier)


## HK-TIME-P4: ensure the pawn_discrete authoritative lane exists for the current
## clock epoch. Called BEFORE the legacy_core commit — i.e. REGISTERED BEFORE the
## legacy core advances, exactly like pawn_continuous — so that after a clock
## reset the lane is re-established at the OLD committed frontier, never at the
## newly-advanced F. Idempotent: register_dynamic_authoritative_lane returns false
## when it already exists.
func _ensure_pawn_discrete_lane() -> void:
	if SimulationClock == null:
		return
	if not SimulationClock.has_method("register_dynamic_authoritative_lane"):
		return
	SimulationClock.register_dynamic_authoritative_lane(PAWN_DISCRETE_LANE_ID)


## HK-TIME-P4: wrapper that computes F = legacy_core applied and drives the discrete
## coordinator over the live "pawns" group. Kept as the direct call site so the real
## coordinator (_run_pawn_discrete_frontier) is trivially testable.
func _run_pawn_discrete_frontier_wrapper() -> void:
	if SimulationClock == null:
		return
	if not SimulationClock.has_method("get_lane_applied_world_time_seconds"):
		return
	var frontier: float = float(SimulationClock.get_lane_applied_world_time_seconds(LEGACY_CORE_LANE_ID))
	_run_pawn_discrete_frontier(frontier)


## HK-TIME-P4-FIX: the REAL discrete coordinator. Reads F = legacy_core applied and
## lets EVERY currently-authoritative live pawn in the "pawns" group DISCOVER every
## ACTUAL DUE DECISION deadline <= F via its pure _apply_authoritative_discrete_frontier(F).
## A discovered (queued) deadline is NOT an applied decision — applied-through only
## advances when a pawn truly starts a decision pipeline. Therefore the coordinator
## commits pawn_discrete NOT blindly to F, but to the MINIMUM per-pawn
## get_pawn_discrete_applied_through_world_time() across all live pawns. A pawn whose
## due decisions are unconsumed reports an applied-through BEFORE its oldest unconsumed
## deadline, so the lane stays behind it. Any failed pawn leaves the lane at its OLD
## applied value and returns false. Running it AFTER _run_pawn_continuous_frontier
## (both through the same F) and BEFORE the continuous emission satisfies the ordering
## contract: ensure lanes -> legacy commit -> F -> pawn_continuous through F ->
## pawn_discrete due decisions through F -> authoritative_continuous_frontier ->
## tick_processed.
func _run_pawn_discrete_frontier(frontier: float) -> bool:
	if SimulationClock == null:
		return false
	if not SimulationClock.has_method("commit_lane_world_time"):
		return false
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var all_ok: bool = true
	var min_applied: float = INF
	var pawns: Array = []
	if tree != null:
		pawns = tree.get_nodes_in_group("pawns")
	for pawn in pawns:
		if pawn == null:
			continue
		if not pawn.has_method("_apply_authoritative_discrete_frontier"):
			continue
		if not pawn._apply_authoritative_discrete_frontier(frontier):
			all_ok = false  # a required pawn failed -> do NOT commit the lane
			continue
		if pawn.has_method("get_pawn_discrete_applied_through_world_time"):
			var pa: float = float(pawn.get_pawn_discrete_applied_through_world_time())
			if pa < min_applied:
				min_applied = pa
	# Commit to the MINIMUM real applied-through (never blindly F). If any pawn is
	# invalid or no pawn reported applied-through, leave the lane where it is.
	if all_ok and min_applied < INF:
		SimulationClock.commit_lane_world_time(PAWN_DISCRETE_LANE_ID, min_applied)
	return all_ok


func _phase_name(phase: int) -> String:
	match phase:
		PHASE_TICKABLES: return "tickables"
		PHASE_REFCOUNTED: return "refcounted"
		PHASE_GAME_TICK: return "game_tick"
		PHASE_COMPLETE: return "complete"
	return "?"


func _rebuild_tickable_cache() -> void:
	_tickable_cache = get_tree().get_nodes_in_group("tickable")
	_tickable_cache.sort_custom(func(a, b): return str(a.get_path()) < str(b.get_path()))
	_tickable_callables.clear()
	for node in _tickable_cache:
		if is_instance_valid(node) and node.has_method("_on_world_tick"):
			_tickable_callables.append(Callable(node, "_on_world_tick"))
	_tickable_cache_dirty = false


func _maybe_warn_backlog() -> void:
	var queued_ticks_est: float = _accumulated_time / base_units_per_transaction()
	if _pending_tick_active:
		queued_ticks_est += 1.0
	if queued_ticks_est > 200.0:
		var now_ms: int = Time.get_ticks_msec()
		if now_ms - _diag_last_backlog_warn_msec >= _DIAG_BACKLOG_WARN_THROTTLE_MSEC:
			_diag_last_backlog_warn_msec = now_ms
			var speed_label: String = SPEED_LABELS[_speed_index] if _speed_index >= 0 and _speed_index < SPEED_LABELS.size() else "?"
			print("[TICK_BACKLOG] WARNING: %.1f ticks queued at %s speed. Sim may be falling behind." % [
				queued_ticks_est, speed_label
			])


func _get_system_name(node) -> String:
	if node == null:
		return ""
	var path = str(node.get_path())
	match path:
		"/root/WorldAI": return "neural"
		"/root/JobManager": return "jobs"
		"/root/WorldMemory": return "memory"
		"/root/WorldMeaning": return "meaning"
		"/root/SettlementMemory": return "settlement"
	if node is PathFinder:
		return "pathfind"
	return ""


func _emit_tick_profile() -> void:
	if TickProfiler != null and not TickProfiler.is_enabled():
		return
	var known_total: int = 0
	for key in _profile_accum:
		known_total += int(_profile_accum[key])
	var other_usec: int = _profile_total - known_total
	var entries: Array = []
	for path_str in _profile_per_path:
		entries.append({"path": path_str, "usec": int(_profile_per_path[path_str])})
	entries.sort_custom(func(a, b): return int(a["usec"]) > int(b["usec"]))
	var top3_str: String = ""
	for i in range(mini(entries.size(), 3)):
		var e: Dictionary = entries[i]
		if i > 0:
			top3_str += " | "
		top3_str += "%s=%.2fms" % [e["path"], float(e["usec"]) / 1000.0]
	print("[TICK-PROFILE] neural=%.2fms | jobs=%.2fms | memory=%.2fms | meaning=%.2fms | pathfind=%.2fms | settlement=%.2fms | other=%.2fms | total=%.2fms" % [
		float(_profile_accum["neural"]) / 1000.0,
		float(_profile_accum["jobs"]) / 1000.0,
		float(_profile_accum["memory"]) / 1000.0,
		float(_profile_accum["meaning"]) / 1000.0,
		float(_profile_accum["pathfind"]) / 1000.0,
		float(_profile_accum["settlement"]) / 1000.0,
		float(other_usec) / 1000.0,
		float(_profile_total) / 1000.0
	])
	print("[TICK-PROFILE] TOP3: %s" % top3_str)
	for key in _profile_accum:
		_profile_accum[key] = 0
	_profile_total = 0
	_profile_per_path.clear()

func mark_tickable_cache_dirty() -> void:
	_tickable_cache_dirty = true

func register_refcounted_tickable(obj) -> void:
	if obj not in _refcounted_tickables:
		_refcounted_tickables.append(obj)
func unregister_refcounted_tickable(obj) -> void:
	_refcounted_tickables.erase(obj)

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
	var budget_cap: int = speed_cap
	if _last_tick_usec > 0:
		var budget_usec: int = _frame_budget_usec()
		var raw_budget_cap: int = maxi(1, int((float(budget_usec) * 0.9) / float(_last_tick_usec)))
		# CRITICAL FIX: budget cap can never reduce below 50% of speed_cap
		# to prevent the death-spiral where a single slow tick permanently
		# crushes throughput for every subsequent frame.
		budget_cap = maxi(int(speed_cap * 0.5), raw_budget_cap)
	return maxi(1, mini(mini(speed_cap, configured_cap), budget_cap))

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
	var prev_index: int = _speed_index
	_speed_index = clampi(index, 0, SPEED_MULTIPLIERS.size() - 1)
	_update_batch_factor()
	# CRITICAL: Reset accumulator when decelerating to prevent event flood
	# when going from high speed (e.g. 200x) back to low speed (e.g. 1x).
	if _speed_index < prev_index:
		_accumulated_time = 0.0
	_prev_speed_index = prev_index
	var gm_paused: bool = false
	if GameManager != null:
		gm_paused = GameManager.is_paused
	# Speed change never touches pause state; the payload merely reports the
	# current pause (read-only, sourced from GameManager — the single authority).
	speed_changed.emit(SPEED_MULTIPLIERS[_speed_index], gm_paused)
func get_speed_multiplier() -> float: return SPEED_MULTIPLIERS[_speed_index]
func get_speed_label() -> String: return SPEED_LABELS[_speed_index]
func get_speed_index() -> int: return _speed_index

## Authoritative simulated world-time (seconds), delegated to SimulationClock.
## 0.0 if the clock autoload is unavailable (e.g. minimal tooling).
func get_world_time_seconds() -> float:
	if SimulationClock != null and SimulationClock.has_method("get_world_time_seconds"):
		return float(SimulationClock.get_world_time_seconds())
	return 0.0
## Measured real-time compatibility tick rate (compat ticks / real second).
func get_compat_tick_rate_per_real_second() -> float:
	return compat_tick_rate_per_real_second
## P1: measured EFFECTIVE world-time throughput (committed canonical world-seconds
## per real second). CPU-bounded honest ceiling — at 200x it will be < 200 when the
## simulator cannot replay full ticks fast enough.
func get_effective_world_speed() -> float:
	return effective_world_speed
## P1: the currently active batch factor (canonical world-seconds per transaction
## ÷ base quantum) for the F10 snapshot.
func get_batch_factor_active() -> int:
	return get_batch_factor()
## REAL 200×: Committed-target lag in canonical seconds
## How far behind the committed world time is from the target time.
func get_committed_target_lag_seconds() -> float:
	return committed_target_lag_seconds
## Total compatibility ticks emitted (session lifetime). Diagnostic only.
func get_compat_ticks_emitted() -> int:
	return _compat_ticks_emitted
## Pause is owned SOLELY by GameManager. TickManager holds no pause boolean;
## these surface methods route to GameManager (the single pause authority) so
## legacy callers remain consistent without duplicating state. None of this is
## a synchronized copy of GameManager state.
func pause() -> void:
	if GameManager != null and GameManager.has_method("pause"):
		GameManager.pause()
func resume() -> void:
	if GameManager != null and GameManager.has_method("resume"):
		GameManager.resume()
func toggle_pause() -> void:
	if GameManager != null and GameManager.has_method("toggle_pause"):
		GameManager.toggle_pause()
## Read-only query against the single authority (never a stored value).
func is_paused() -> bool:
	return GameManager.is_paused if GameManager != null else false
func is_high_speed() -> bool: return _speed_index >= 3
func verbose_logs() -> bool: return false

## Reset steady-state maximum diagnostics (called after warmup by smoke tool).
func reset_steady_max_diagnostics() -> void:
	debug_max_sim_callback_usec = 0
	debug_max_sim_callback_name = ""
	# Note: debug_last_sim_slice_usec is per-frame, not cumulative max.
	# The smoke tool tracks its own max from the per-frame values.
