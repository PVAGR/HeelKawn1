class_name DayNightCycle
extends CanvasModulate

## Tints the entire canvas layer based on in-game time. Drives off
## GameManager.game_tick so pause and speed multipliers behave automatically.
##
## Visual day length in ticks. See [SimTime] and [code]docs/TIME_SCALE.md[/code]
## for the canonical tick/calendar/wall-clock map.
const TICKS_PER_DAY: int = SimTime.TICKS_PER_VISUAL_DAY

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
	GameManager.game_tick.connect(_on_tick)
	_apply_for_tick(GameManager.tick_count)


func _on_tick(tick: int) -> void:
	_apply_for_tick(tick)
	var day: int = int(tick / float(TICKS_PER_DAY))
	if day != _last_day:
		_last_day = day
		var display_day: int = day + 1
		if _should_log_day_rollover(display_day):
			var yr: int = SimTime.sim_year_index(tick)
			var din: int = SimTime.visual_day_within_sim_year(tick)
			var dmx: int = SimTime.visual_days_per_sim_year()
			print("[DayNight] Year %d · Day %d/%d begins (tick %d)" % [yr, din, dmx, tick])


func _should_log_day_rollover(display_day: int) -> bool:
	## At 26x+ each real second spans many visual days — avoid flooding stdout.
	if GameManager.game_speed < 26.0:
		return true
	if not OS.is_debug_build():
		return false
	return display_day == 1 or (display_day % 14 == 0)


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


## Instance accessor: is "right now" nighttime, according to GameManager's clock?
func is_night() -> bool:
	return is_night_for_tick(GameManager.tick_count)


static func _color_for_phase(t: float) -> Color:
	if t < 0.25:
		return COLOR_MIDNIGHT.lerp(COLOR_DAWN, t / 0.25)
	if t < 0.50:
		return COLOR_DAWN.lerp(COLOR_NOON, (t - 0.25) / 0.25)
	if t < 0.75:
		return COLOR_NOON.lerp(COLOR_DUSK, (t - 0.50) / 0.25)
	return COLOR_DUSK.lerp(COLOR_MIDNIGHT, (t - 0.75) / 0.25)
