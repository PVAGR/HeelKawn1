extends Node

## SimulationClock — authoritative simulated world-time (multi-rate foundation).
##
## HeelKawn's world-clock advances according to requested game speed, decoupled
## from HOW MANY simulation ticks the scheduler happens to emit. The job of this
## clock is to be the single source of truth for *elapsed simulated world time*:
##
##     sim_delta = real_elapsed * game_speed
##     target_world_time_seconds += sim_delta
##
## `target_world_time_seconds` is the world-time coordinate the simulation is
## ASKED to be at. Individual systems/spawns may lag behind the target while they
## catch up (or be deliberately paced on a slower multi-rate cadence); each such
## lane tracks its OWN applied cursor so the *lag* between a lane and the target
## is always observable and never silently conflated with 'the world clock'.
##
## The scheduler (TickManager) is the ONLY writer of the target: it advances the
## target once per rendered frame at the top of its step. Lanes read the target
## and commit their own applied cursor via [method commit_lane_time]. This keeps
## one authoritative writer and many read/commit consumers, so every lane
## observes the same monotonic target.

## World-time coordinate the simulation is ASKED to reach (seconds, 1x == real s).
## `world_time_seconds` is kept as an alias for legacy readers — it IS the target.
var world_time_seconds: float = 0.0

## Per-lane applied cursors: lane_name -> world-time (seconds) the lane has
## actually consumed/applied. A lane's lag = target - applied.
var _lane_cursors: Dictionary = {}

## Authoritative-lane registration: lane_name -> { applied, initial }. Only lanes
## registered here contribute to the GLOBAL COMMITTED world-time frontier
## ([method get_committed_world_time_seconds]). Presentation / debug / UI lanes
## MUST NOT be registered, so they can never freeze committed history. Each
## authoritative lane also stores an authoritative-applied flag so commits on an
## unknown lane never perturb the committed frontier.
var _authoritative_lanes: Dictionary = {}

## EXPLICIT MONOTONIC COMMITTED FRONTIER. This is the causal-history frontier:
## the latest world-time for which every REQUIRED authoritative lane has
## COMPLETED all causal work. It advances ONLY from explicit authoritative lane
## progress ([method commit_lane_world_time] / [method seal_authoritative_lane_roster]
## / [method set_lane_time] on a registered authoritative lane); it NEVER advances
## because [method advance_target] moved the requested frontier. Target
## advancement alone MUST NOT commit history.
var _committed_world_time_seconds: float = 0.0

## Authoritative-roster lifecycle. OPEN at reset: startup lanes register and
## commit WITHOUT advancing global committed (registration/commit order must not
## alter history). After [method seal_authoritative_lane_roster], committed may
## advance from the min applied cursor of all registered lanes; new dynamic lanes
## register at current committed.
var _authoritative_roster_sealed: bool = false

## Target world-time the simulation is asked to be at.
func get_target_world_time_seconds() -> float:
	return world_time_seconds

## Legacy alias — returns the target. Kept so existing callers keep working.
func get_world_time_seconds() -> float:
	return world_time_seconds

## Advance the target clock by `dt` simulated seconds. Only TickManager calls this.
## `dt` is already scaled by game speed by the caller.
func advance_target(dt: float) -> void:
	if dt <= 0.0:
		return
	world_time_seconds += dt

## Backward-compatible alias of [method advance_target].
func advance_sim_time(dt: float) -> void:
	advance_target(dt)

## ---------------------------------------------------------------------------
## CANONICAL SIMULATION TIME CONTRACT (Phase 1)
##
## Three distinct quantities must never be conflated:
##
##   TARGET world time   = requested simulation frontier (elapsed real time *
##                         game speed). The scheduler is the ONLY writer.
##   LANE applied time   = per-lane frontier fully consumed by one authoritative
##                         lane (monotonic, never beyond target).
##   COMMITTED world time = min over ALL REGISTERED AUTHORITATIVE LANES of their
##                         applied cursor. The earliest lagging authoritative lane
##                         bounds committed history.
##
## Non-authoritative (presentation / debug / UI) lanes never block committed.
## `get_world_time_seconds()` returns the TARGET, NOT committed — never read it
## as "history that has causally applied".
## ---------------------------------------------------------------------------

## Latest world-time frontier fully consumed by the named authoritative lane.
## 0.0 if the lane never committed (a registered lane that never commits blocks
## committed history at 0, by design).
func get_lane_applied_world_time_seconds(lane: String) -> float:
	return float(_lane_cursors.get(lane, 0.0))

## Unapplied world-time the named lane still owes = max(0, target - lane applied).
func get_lane_unapplied_seconds(lane: String) -> float:
	return maxf(0.0, world_time_seconds - float(_lane_cursors.get(lane, 0.0)))

## How far the named lane trails the target (seconds of world time). >= 0.
func get_lane_lag(lane: String) -> float:
	return get_lane_unapplied_seconds(lane)

## Register a STARTUP authoritative lane with an explicit initial applied frontier.
## Valid only while the roster is OPEN. `initial_applied` is the world-time the
## lane has ALREADY causally processed on entry (0 for lanes responsible for
## history from simulation start). This call initializes the lane cursor EXACTLY
## to the supplied value and NEVER advances global committed, so registration
## order cannot change history.
##
## Valid initial range while OPEN: 0 <= initial_applied <= target.
## Invalid values (initial < 0 or initial > target) FAIL — no silent clamp.
## After the roster is SEALED, this is a late missing startup lane and always
## FAILS (configuration error) — never silently clamped forward.
## Re-registering an existing lane is a deterministic no-op returning false.
##
## Returns true on success, false on failure.
func register_authoritative_lane(lane: String, initial_applied_world_time_seconds: float) -> bool:
	if _authoritative_lanes.has(lane):
		return false  # already registered — no-op, deterministic status
	if _authoritative_roster_sealed:
		return false  # late missing startup lane — reject, do not conceal
	var initial: float = initial_applied_world_time_seconds
	if initial < 0.0 or initial > world_time_seconds:
		return false  # invalid causal frontier — fail loudly
	_authoritative_lanes[lane] = {"applied": initial, "authoritative": true}
	_lane_cursors[lane] = initial
	return true  # NO committed advance during startup registration

## Seal the startup authoritative roster. After this, global committed may
## advance. candidate = min(applied cursor of every startup authoritative lane);
## committed advances ONLY if candidate > current committed; never regresses;
## never exceeds target. Zero registered lanes => no committed advance (roster
## still becomes sealed).
func seal_authoritative_lane_roster() -> void:
	if _authoritative_roster_sealed:
		return
	_authoritative_roster_sealed = true
	_recompute_committed()

## True once the startup authoritative roster has been sealed.
func is_authoritative_lane_roster_sealed() -> bool:
	return _authoritative_roster_sealed

## Register a DYNAMIC authoritative lane created mid-world (after seal). Its
## causal responsibility begins at the current committed frontier: lane_applied
## == current_global_committed. Never uses target, never below/above committed,
## never changes global committed.
##
## Returns true on success, false if not sealed or already registered.
func register_dynamic_authoritative_lane(lane: String) -> bool:
	if not _authoritative_roster_sealed:
		return false
	if _authoritative_lanes.has(lane):
		return false
	_authoritative_lanes[lane] = {"applied": _committed_world_time_seconds, "authoritative": true}
	_lane_cursors[lane] = _committed_world_time_seconds
	return true  # committed unchanged

## Explicit monotonic committed frontier: the latest world-time for which every
## REQUIRED authoritative lane has completed all causal work. NEVER advances just
## because the target advanced. With zero registered authoritative lanes, no
## causal progress exists, so committed stays 0. INVARIANT: 0 <= committed <= target.
func get_committed_world_time_seconds() -> float:
	return _committed_world_time_seconds

## simulation_lag = target - committed (>= 0).
func get_simulation_lag_seconds() -> float:
	return maxf(0.0, world_time_seconds - _committed_world_time_seconds)

## Recompute candidate = min(applied over registered authoritative lanes) and
## advance the global committed frontier ONLY when candidate > current committed.
## Never regresses. Only called after the roster is sealed; commits on
## non-authoritative lanes never reach here.
func _recompute_committed() -> void:
	if not _authoritative_roster_sealed:
		return
	if _authoritative_lanes.is_empty():
		return
	var candidate: float = world_time_seconds
	for lane in _authoritative_lanes:
		var applied: float = float(_lane_cursors.get(lane, 0.0))
		if applied < candidate:
			candidate = applied
	if candidate > _committed_world_time_seconds:
		_committed_world_time_seconds = candidate

## World-time the named lane has applied so far. 0.0 if the lane never committed.
func get_lane_time(lane: String) -> float:
	return get_lane_applied_world_time_seconds(lane)

## Unapplied world-time the named lane still owes = target - lane applied.
func get_lane_delta(lane: String) -> float:
	return get_lane_unapplied_seconds(lane)

## Mark the named lane's applied cursor as equal to the target *right now*.
## Call after a lane consumed all elapsed world-time it was owed. Invalid
## (backward / beyond-target) commits are rejected/no-op.
func commit_lane_time(lane: String) -> void:
	commit_lane_world_time(lane, world_time_seconds)

## Commit the named lane's applied cursor to an explicit world-time value.
## Requirements: current_lane_applied <= new <= target; backward or above-target
## commits are REJECTED (return false) for authoritative lanes, never silently
## clamped or hidden. Unknown / non-authoritative lanes MAY keep their own cursor
## for diagnostics but NEVER move the committed frontier.
##
## While the roster is OPEN, an authoritative commit updates the cursor but does
## NOT advance global committed (startup dependency set incomplete). After seal,
## an authoritative commit may advance committed (min rule).
##
## Returns true on success, false on invalid/no-op commit.
func commit_lane_world_time(lane: String, committed_time_seconds: float) -> bool:
	var current: float = float(_lane_cursors.get(lane, 0.0))
	if committed_time_seconds < current:
		return false  # backward — reject, never regress.
	if committed_time_seconds > world_time_seconds:
		return false  # above target — reject, never overshoot.
	_lane_cursors[lane] = committed_time_seconds
	if _authoritative_lanes.has(lane):
		_recompute_committed()
	return true

## Set a lane's applied cursor to an explicit value (used when a lane is born at
## some world-time, e.g. a pawn spawned mid-window). Never beyond target, never
## backward. Authoritative lanes restart the committed frontier only once the
## roster is sealed; non-authoritative lanes never do.
func set_lane_time(lane: String, value: float) -> void:
	var capped: float = minf(value, world_time_seconds)
	capped = maxf(capped, 0.0)
	var current: float = float(_lane_cursors.get(lane, 0.0))
	if capped < current:
		capped = current
	_lane_cursors[lane] = capped
	if _authoritative_lanes.has(lane) and _authoritative_roster_sealed:
		_recompute_committed()

## Reset the clock, explicit committed frontier, all per-lane cursors, ALL
## authoritative-lane registrations, and the roster to OPEN so no state from a
## previous world instance remains. Deterministic: target == 0, committed == 0,
## lag == 0, roster_sealed == false.
func reset() -> void:
	world_time_seconds = 0.0
	_committed_world_time_seconds = 0.0
	_lane_cursors.clear()
	_authoritative_lanes.clear()
	_authoritative_roster_sealed = false
