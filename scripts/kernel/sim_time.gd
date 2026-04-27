class_name SimTime
extends RefCounted

## Canonical simulation calendar and wall-clock mapping for HeelKawn.
## GameManager.TICK_INTERVAL_SECONDS must match [member TICK_INTERVAL_SECONDS].

## Wall-clock seconds per simulation tick at 1x speed.
const TICK_INTERVAL_SECONDS: float = 0.1

## Length of the **visual** day/night cycle in ticks (also used for "Day N" in HUD).
## At 1x this is TICKS_PER_VISUAL_DAY * TICK_INTERVAL_SECONDS real seconds (600 * 0.1 = 60s).
const TICKS_PER_VISUAL_DAY: int = 600

## In-world **year** for milestones, exports, and kernel diagnostics (~30k ticks).
## Wall time at 1x: TICKS_PER_SIM_YEAR * TICK_INTERVAL_SECONDS (30000 * 0.1 = 3000s ≈ 50 min).
const TICKS_PER_SIM_YEAR: int = 30000

## Single-shot kernel validation aligned with end of sim year.
const KERNEL_DIAGNOSTIC_TICK: int = TICKS_PER_SIM_YEAR

## Visual days per in-world year (30_000 / 600 = 50). Keeps HUD “Day” aligned with [DayNightCycle].
const VISUAL_DAYS_PER_SIM_YEAR: int = TICKS_PER_SIM_YEAR / TICKS_PER_VISUAL_DAY

static func sim_year_index(tick: int) -> int:
	return int(tick / TICKS_PER_SIM_YEAR) + 1


static func tick_within_sim_year(tick: int) -> int:
	return int(tick % TICKS_PER_SIM_YEAR)


## 1-based day index within the current sim year (same cycle length as day/night tint).
static func calendar_day_within_sim_year(tick: int) -> int:
	return int((tick % TICKS_PER_SIM_YEAR) / float(TICKS_PER_VISUAL_DAY)) + 1


## 1-based count of visual days since tick 0 (matches [DayNightCycle] “Day N begins” numbering).
static func calendar_absolute_visual_day(tick: int) -> int:
	return int(tick / float(TICKS_PER_VISUAL_DAY)) + 1


static func visual_days_per_sim_year() -> int:
	return VISUAL_DAYS_PER_SIM_YEAR


static func divergence_milestone_ticks() -> Array[int]:
	## Debug summaries at key long-run checkpoints (includes pre-year stress window).
	return [20000, 30000, 40000, 100000]


static func long_run_checkpoints() -> Array[int]:
	return [10000, 25000, 50000, 75000, 100000, 150000, 200000]


static func wall_seconds_at_1x_for_ticks(ticks: int) -> float:
	return float(ticks) * TICK_INTERVAL_SECONDS
