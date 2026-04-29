class_name SimTime
extends RefCounted

## Canonical simulation calendar and wall-clock mapping for HeelKawn.
## GameManager.TICK_INTERVAL_SECONDS must match [member TICK_INTERVAL_SECONDS].

## Wall-clock seconds per simulation tick at 1x speed.
## Canon target: one tick per real second at 1x.
const TICK_INTERVAL_SECONDS: float = 1.0

## Length of the **visual** day/night cycle in ticks (also used for "Day N" in HUD).
## At 1x this is TICKS_PER_VISUAL_DAY * TICK_INTERVAL_SECONDS real seconds (600 * 1.0 = 600s).
const TICKS_PER_VISUAL_DAY: int = 600

## In-world **year** for milestones, exports, and kernel diagnostics (~30k ticks).
## Wall time at 1x: TICKS_PER_SIM_YEAR * TICK_INTERVAL_SECONDS (30000 * 1.0 = 30000s ≈ 8.3 hours).
const TICKS_PER_SIM_YEAR: int = 30000

## Single-shot kernel validation aligned with end of sim year.
const KERNEL_DIAGNOSTIC_TICK: int = TICKS_PER_SIM_YEAR


static func sim_year_index(tick: int) -> int:
	return int(tick / TICKS_PER_SIM_YEAR) + 1


static func tick_within_sim_year(tick: int) -> int:
	return int(tick % TICKS_PER_SIM_YEAR)


## Visual days (day/night cycles) per full sim year — must divide evenly (30000 / 600 = 50).
static func visual_days_per_sim_year() -> int:
	return TICKS_PER_SIM_YEAR / TICKS_PER_VISUAL_DAY


## 1-based index of the current visual day **within** the current sim year (1 … visual_days_per_sim_year()).
static func visual_day_within_sim_year(tick: int) -> int:
	var ytick: int = tick_within_sim_year(tick)
	return int(ytick / TICKS_PER_VISUAL_DAY) + 1


## Compatibility alias used by debug/reporting surfaces.
static func calendar_day_within_sim_year(tick: int) -> int:
	return visual_day_within_sim_year(tick)


## 1-based visual-day count from simulation start.
static func calendar_absolute_visual_day(tick: int) -> int:
	return int(tick / TICKS_PER_VISUAL_DAY) + 1


## Shared deterministic long-run checkpoint ticks.
static func long_run_checkpoints() -> Array[int]:
	return divergence_milestone_ticks()


static func divergence_milestone_ticks() -> Array[int]:
	## Debug summaries at key long-run checkpoints (includes pre-year stress window).
	return [20000, 30000, 40000]


static func wall_seconds_at_1x_for_ticks(ticks: int) -> float:
	return float(ticks) * TICK_INTERVAL_SECONDS
