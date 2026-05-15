# HeelKawn — time scale (canonical)

Authoritative mapping between **simulation ticks**, the **visual day/night cycle**, **in-world years**, and **real wall clock** at speed 1x.

## Constants (code)

| Concept | Constant | Value |
|--------|----------|--------|
| Real seconds per tick at 1x | `GameManager.TICK_INTERVAL_SECONDS` / `SimTime.TICK_INTERVAL_SECONDS` | 1.0 s |
| Ticks per visual day/night cycle | `SimTime.TICKS_PER_VISUAL_DAY` | 600 |
| Ticks per in-world **year** | `SimTime.TICKS_PER_SIM_YEAR` | 30 000 |
| Kernel diagnostic tick | `SimTime.KERNEL_DIAGNOSTIC_TICK` | 30 000 (same as year length) |

Implementation: `scripts/kernel/sim_time.gd` (`class_name SimTime`).

## Derived wall times at 1x

- One **visual day** ≈ `600 × 1.0` = **600 s** real (10 minutes).
- One **in-world year** ≈ `30 000 × 1.0` = **30 000 s** real (~8.3 hours).

## Semantics

- **Tick**: Smallest deterministic sim step; `GameManager` emits `game_tick` once per tick. Higher game speed multiplies how many ticks are processed per real-time second (bounded per frame — see `GameManager` caps).
- **Visual day**: The canvas **day/night tint** repeats every `TICKS_PER_VISUAL_DAY` ticks. HUD “Day N” counts these cycles (not the 30 k-year day index).
- **Sim year**: Used for **milestones**, **age progression** (pawn biological years per sim year), **export headers**, and **creator verification** targets (“~30 k ticks per year”).

## High speed (e.g. 100x)

Catch-up is limited by `MAX_TICKS_PER_FRAME` and `MAX_ACCUMULATED_TICKS`. Fast-forward may stutter until work per tick is throttled; 100x is a **stress / burst** mode, not guaranteed smooth real-time.
