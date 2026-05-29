# HeelKawn Verification Snapshot — 2026-05-23

## Scope
- Improve autonomous settlement planning stability at high simulation speeds.
- Reduce planner-driven job flood risk without removing deterministic behavior.
- Verify Matrix AI deepening wiring and the new ambition-chain logic.

## Repository Snapshot
- Branch: `main`
- Verification date: 2026-05-23 (UTC)
- Main scene: `res://scenes/main/Main.tscn`

## Implemented In This Pass

1. Learning target biasing wired into job selection
- File: `autoloads/HeelKawnianManager.gd`
- Change:
  - Added `_apply_learning_target_biases(biases, data, pawn)` in `HeelKawnianManager.gd`.
  - Called from `_matrix_job_biases()` between `_apply_learning_biases` and `_add_identity_trait_biases`.
  - When a pawn has a target knowledge type, biases are added toward apprenticeship/teaching and domain-specific jobs.
  - When a pawn has a target skill, biases are added toward jobs that exercise that skill.
- Effect:
  - Learning targets already computed by `get_learning_target_for_pawn()` now actually influence job choice.

2. Preservation choices verified already wired
- File: `autoloads/HeelKawnianManager.gd`
- Change:
  - Confirmed `get_preservation_choice_for_pawn()` is called from `_matrix_job_biases`.
  - Three preservation actions (`teach`, `inscribe_stone`, `write_book`) have correct bias mappings.
- Effect:
  - No change needed; this path was already operational.

3. Settlement ambition chains made general
- File: `autoloads/HeelKawnianManager.gd`
- Change:
  - `get_settlement_ambition_for_pawn()` now checks `_ambition_chain_for_settlement()` as a fallback for all drives.
- Effect:
  - All settlements now pursue multi-step strategic chains when no immediate pressure exists.

4. Five new ambition chain types added
- File: `autoloads/HeelKawnianManager.gd`
- Change:
  - Added `Rebuild from Ruin`, `Healing & Care`, `Defense Network`, `Trade Route`, and `Cultural Renaissance` chain types.
  - Updated `_select_new_chain`, `_chain_step_completed`, `_ambition_from_chain_step`, and `_chain_name_for_steps`.
- Effect:
  - Settlement chains now cover more civic, defensive, and cultural growth paths.

5. Settlement planner cadence now scales with simulation speed
- File: `autoloads/SettlementPlanner.gd`
- Change:
  - Added `PLANNING_INTERVAL_TICKS_FAST = 900`
  - Added `PLANNING_INTERVAL_TICKS_VERY_FAST = 1400`
  - Added `_planner_interval_ticks()` and switched planner gate to use it.
- Effect:
  - At high speeds, planner runs less frequently per tick, reducing hitch pressure.

6. Settlement planner queue backpressure is now active
- File: `autoloads/SettlementPlanner.gd`
- Change:
  - Replaced disabled backpressure (`-1`) with speed-aware open-job caps:
    - `>=26x`: `200`
    - `>=12x`: `280`
    - `>=6x`: `340`
    - otherwise: `420`
- Effect:
  - Planner stops posting additional build intents when queue is already saturated.
  - Prevents runaway planner amplification during stress simulation.

## What Was Verified

### Static Analysis
- New function signatures matched existing patterns.
- All knowledge enum references were valid.
- All skill enum references were valid.
- All job type references pointed at existing job types.
- Chain data integrity held for all chain types.
- No `randi()` / `randf()` calls were introduced in the reviewed paths.
- Preservation wiring existed in `_matrix_job_biases`.
- General chain fallback existed for all drives.

## Why This Matters
- Keeps observer/autonomous civilization growth active while improving smoothness at `100x`.
- Preserves deterministic world rules: no random throttles or hidden behavior changes.

## Local Verification In This Environment
- Static inspection confirmed the new constants and helper methods were present.
- Runtime smoke could not run here because the Godot binary is unavailable in this environment.

## Residual Risk
- Full frame-time impact still needs runtime validation on a machine with Godot installed.
- Caps may need tuning after observing long-run `100x` scenarios with large settlement counts.

## Verification Commands

```bash
cd HeelKawn1

# Pre-flight static checks
grep -n 'KnowledgeSystem.KnowledgeType\.' autoloads/HeelKawnianManager.gd | head -30
grep -n 'HeelKawnianData.Skill\.' autoloads/HeelKawnianManager.gd | head -10
grep -n '_select_new_chain\|_chain_step_completed\|_ambition_from_chain_step\|_chain_name_for_steps' autoloads/HeelKawnianManager.gd

# Headless smoke tests (requires Godot binary)
godot --headless --path . -s res://tools/sim_boot_smoke.gd
godot --headless --path . -s res://tools/sim_settlement_public_state_smoke.gd

# Full quality gate
bash tools/ai/sim-quality-gate.sh
```
