class_name DayNightCycle
extends CanvasModulate

## Tints the entire canvas layer based on in-game time.
##
## AUTHORITATIVE SOURCE (HK-TIME-ARCH-P2B): CURRENT calendar state derives from
## SimulationClock COMMITTED canonical world time, converted back to an
## equivalent legacy tick via the canonical bridge quantum, then fed through the
## existing SimTime calendar functions. It MUST NOT be derived from the legacy
## compatibility tick counter / the TARGET time / any frame delta / any local
## elapsed counter. Current-state updates run on TickManager.tick_processed,
## which fires AFTER legacy_core commits, so a current update always sees the
## just-committed frontier (CURRENT_UPDATE_AFTER_COMMIT).
##
## Two API families:
##   CURRENT API  — no legacy-tick argument; derives NOW from committed time:
##                  get_current_legacy_calendar_tick() / is_night().
##   HISTORICAL API — take an explicit legacy tick argument: is_night_for_tick(),
##                  phase_for_tick(), sync_to_tick(), etc. Their argument is a
##                  legacy calendar tick, NEVER canonical seconds. Retained for
##                  unmigrated gameplay systems.
##
## Visual day length in ticks. See [SimTime] and [code]docs/TIME_SCALE.md[/code]
## for the canonical tick/calendar/wall-clock map.
const TICKS_PER_DAY: int = SimTime.TICKS_PER_VISUAL_DAY

## Canonical bridge quantum = canonical SimulationClock world seconds per one
## completed legacy compatibility transaction. Resolved from the production
## constant (HK-TIME-ARCH-P2A.1); NEVER from SimTime.TICK_INTERVAL_SECONDS (the
## old legacy tick-domain unit is NOT a canonical second). No hardcoded fallback.
##
## Autoloads (TickManager/SimulationClock) are resolved at call time via the
## SceneTree root so this script compiles in any context (scene boot or a
## headless --script tool) without relying on bare autoload identifiers.
static func _autoload(name: StringName) -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null(NodePath(name))

static func _bridge_quantum() -> float:
	var tm: Node = _autoload(&"TickManager")
	if tm == null or not ("LEGACY_CORE_CANONICAL_SECONDS_PER_TRANSACTION" in tm):
		push_error("DayNightCycle: TickManager canonical bridge quantum unavailable")
		return 0.0
	return float(tm.LEGACY_CORE_CANONICAL_SECONDS_PER_TRANSACTION)

## CURRENT API — the ONLY canonical -> legacy-tick conversion.
## committed canonical seconds -> equivalent legacy calendar tick (integer).
## Deterministic floor with a tiny epsilon proportional to q (not a large
## arbitrary epsilon) to keep exact multiples stable. Invalid q is rejected.
##   with Q=0.05: 0.00->0, 0.05->1, 29.95->599, 30.00->600, 1499.95->29999, 1500.00->30000
static func canonical_seconds_to_legacy_tick(committed_seconds: float) -> int:
	var q: float = _bridge_quantum()
	if q <= 0.0:
		push_error("DayNightCycle: invalid canonical bridge quantum")
		return 0
	return int(floorf((maxf(0.0, committed_seconds) + q * 0.000001) / q))

## CURRENT API — current equivalent legacy calendar tick derived from
## SimulationClock COMMITTED canonical world time (the frontier at which every
## authoritative lane has completed its causal work), converted via the canonical
## bridge quantum. HK-SCHED-P1 (comitted-based calendar): this is the ONLY
## causal-soundness-satisfying source for the PUBLIC day — it never advances to a
## tick whose work has not been applied. It is clamped to the live compatibility
## tick (TickManager.current_tick) so it can never roll past what the scheduler
## has actually begun, and it can never regress (committed is monotonic).
static func get_current_legacy_calendar_tick() -> int:
	var tm: Node = _autoload(&"TickManager")
	if tm == null:
		return 0
	var clock: Node = _autoload(&"SimulationClock")
	if clock == null or not clock.has_method("get_committed_world_time_seconds"):
		return 0
	var committed: float = float(clock.get_committed_world_time_seconds())
	var tick: int = canonical_seconds_to_legacy_tick(committed)
	# Never present a day ahead of the scheduler heartbeat that has actually begun.
	var live: int = int(tm.current_tick) if ("current_tick" in tm) else tick
	if tick > live:
		tick = live
	return maxi(0, tick)

## Four key colors around the clock.
## Phase 0.00 = midnight, 0.25 = dawn, 0.50 = noon, 0.75 = dusk.
const COLOR_MIDNIGHT: Color = Color(0.18, 0.22, 0.38)
const COLOR_DAWN:     Color = Color(1.00, 0.75, 0.60)
const COLOR_NOON:     Color = Color(1.00, 1.00, 1.00)
const COLOR_DUSK:     Color = Color(1.00, 0.55, 0.42)

enum TimeBand {
	NIGHT,
	DAWN,
	DAY,
	DUSK,
}

const DAWN_START: float = 0.22
const DAWN_END: float = 0.32
const DUSK_START: float = 0.68
const DUSK_END: float = 0.78

var _last_day: int = -1


func _ready() -> void:
	# Update AFTER legacy_core commits: tick_processed fires after _commit_legacy_core_quantum().
	var tm: Node = _autoload(&"TickManager")
	if tm != null and tm.has_signal("tick_processed"):
		tm.tick_processed.connect(_on_tick)
	_apply_for_tick(get_current_legacy_calendar_tick())


# _emit_tick is the compatibility emit counter (diagnostic); the calendar reads
# committed canonical time, NOT this argument.
func _on_tick(_emit_tick: int) -> void:
	var current: int = get_current_legacy_calendar_tick()
	_apply_for_tick(current)
	var day: int = int(current / float(TICKS_PER_DAY))
	# Cache state machine for day-boundary detection. `_last_day` is
	# change-detection cache ONLY, never a time authority.
	if _last_day < 0:
		# initial observation: initialize cache (preserve initial rollover log).
		_last_day = day
		_log_day_begins(day)
	elif day > _last_day:
		# normal forward causal progression: enumerate ONLY crossed boundaries.
		for d in range(_last_day + 1, day + 1):
			_last_day = d
			_log_day_begins(d)
	elif day < _last_day:
		# new epoch / explicit rewind or reset sync: do NOT emit historical
		# forward boundaries, do not loop backward. Cache follows committed.
		_last_day = day
	# else day == _last_day: no boundary action.


## Log a day rollover (presentation only). `day` is the 0-based day being begun;
## the visual day begins at legacy tick day * TICKS_PER_DAY.
func _log_day_begins(day: int) -> void:
	var display_day: int = day + 1
	if not _should_log_day_rollover(display_day):
		return
	var begin_tick: int = day * TICKS_PER_DAY
	var yr: int = SimTime.sim_year_index(begin_tick)
	var din: int = SimTime.visual_day_within_sim_year(begin_tick)
	var dmx: int = SimTime.visual_days_per_sim_year()
	print("[DayNight] Year %d · Day %d/%d begins (tick %d)" % [yr, din, dmx, begin_tick])


func _should_log_day_rollover(display_day: int) -> bool:
	## At 26x+ each real second spans many visual days — avoid flooding stdout.
	var gm: Node = _autoload(&"GameManager")
	var speed: float = float(gm.game_speed) if gm != null else 1.0
	if speed < 26.0:
		return true
	if not OS.is_debug_build():
		return false
	return display_day == 1 or (display_day % 14 == 0)


## HISTORICAL API: takes an explicit legacy tick (NOT canonical seconds).
## After loading a save: snap visuals + day counter to `tick` without re-printing
## spurious "Day 1" lines.
func sync_to_tick(tick: int) -> void:
	_last_day = int(tick / float(TICKS_PER_DAY))
	_apply_for_tick(tick)


func _apply_for_tick(tick: int) -> void:
	var phase: float = phase_for_tick(tick)
	color = _color_for_phase(phase)


static func phase_for_tick(tick: int) -> float:
	return float(tick % TICKS_PER_DAY) / float(TICKS_PER_DAY)


## Phase boundaries used by gameplay (sleep schedule, future: nocturnal mobs).
## Anything in [NIGHT_START, 1) ∪ [0, NIGHT_END) is considered nighttime.
const NIGHT_START: float = 0.78  # late dusk
const NIGHT_END:   float = 0.22  # pre-dawn / early morning


## Static convenience: is the given tick during nighttime?
static func is_night_for_tick(tick: int) -> bool:
	var phase: float = phase_for_tick(tick)
	return phase >= NIGHT_START or phase < NIGHT_END


static func is_dawn_for_tick(tick: int) -> bool:
	var phase: float = phase_for_tick(tick)
	return phase >= DAWN_START and phase < DAWN_END


static func is_dusk_for_tick(tick: int) -> bool:
	var phase: float = phase_for_tick(tick)
	return phase >= DUSK_START and phase < DUSK_END


static func is_day_for_tick(tick: int) -> bool:
	return not is_night_for_tick(tick) and not is_dawn_for_tick(tick) and not is_dusk_for_tick(tick)


static func time_band_for_tick(tick: int) -> int:
	if is_night_for_tick(tick):
		return TimeBand.NIGHT
	if is_dawn_for_tick(tick):
		return TimeBand.DAWN
	if is_dusk_for_tick(tick):
		return TimeBand.DUSK
	return TimeBand.DAY


## CURRENT API: is "right now" nighttime, according to committed canonical time?
func is_night() -> bool:
	return is_night_for_tick(get_current_legacy_calendar_tick())


static func _color_for_phase(t: float) -> Color:
	if t < 0.25:
		return COLOR_MIDNIGHT.lerp(COLOR_DAWN, t / 0.25)
	if t < 0.50:
		return COLOR_DAWN.lerp(COLOR_NOON, (t - 0.25) / 0.25)
	if t < 0.75:
		return COLOR_NOON.lerp(COLOR_DUSK, (t - 0.50) / 0.25)
	return COLOR_DUSK.lerp(COLOR_MIDNIGHT, (t - 0.75) / 0.25)
