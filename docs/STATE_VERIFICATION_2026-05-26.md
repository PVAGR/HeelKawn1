# HeelKawn Verification Snapshot — 2026-05-26

## Scope
- Wire Matrix preservation and learning target decisions into live HeelKawnian runtime behavior.
- Keep behavior deterministic and bounded at both `1x` and `100x` lanes.

## Repository Snapshot
- Branch: `main`
- Verification date: 2026-05-26 (UTC)
- Main scene: `res://scenes/main/Main.tscn`

## Implemented In This Pass

1. Matrix preservation actions now execute in pawn runtime
- File: `scripts/pawn/HeelKawnian.gd`
- Added `_try_heelkawnian_matrix_preservation_action()` and medium-lane call site.
- Action mapping from `HeelKawnianManager.get_preservation_choice_for_pawn(...)`:
  - `teach`: direct deterministic teaching when close, otherwise autonomous draft-walk toward target.
  - `inscribe_stone`: post deduped `CARVE_KNOWLEDGE_STONE` job with seeder metadata.
  - `write_book`: write directly via `KnowledgeSystem.write_knowledge_in_book(...)` when close, otherwise seed `BOOK_BINDING`.
- Added throttles:
  - tick lane gate: `posmod(tick + pawn_id*13, 41)`
  - cooldown gate: `_next_matrix_preservation_tick`
- Added audit event: `matrix_preservation_action`.

2. Matrix learning targets now seed live teaching/apprenticeship jobs
- File: `scripts/pawn/HeelKawnian.gd`
- Added `_try_heelkawnian_matrix_learning_seed()` and medium-lane call site.
- Reads `HeelKawnianManager.get_learning_target_for_pawn(...)`.
- Seeds bounded jobs:
  - `APPRENTICESHIP` when knowledge target exists.
  - `TEACH_SKILL` when skill target path is active.
- Added local dedupe via `JobManager.count_pending_jobs_near(...)` to prevent queue spam.
- Added throttles:
  - tick lane gate: `posmod(tick + pawn_id*5, 37)`
  - cooldown gate: `_next_matrix_learning_tick`
- Added audit event: `matrix_learning_seed`.

## Determinism / Stability Notes
- No new unseeded RNG was introduced.
- No frame-time dependent world-truth branching was added.
- New actions are deterministic from existing state + tick and use explicit cooldown gates.

## Verification Evidence
- Ran compile check:
  - `bash tools/ai/verify-compile.sh`
  - Result: Godot binary unavailable in this environment (`godot: command not found`).
- Ran required quality gate:
  - `bash tools/ai/sim-quality-gate.sh`
  - Result: PASS
  - Runtime smoke skipped by gate because Godot binary is unavailable.

## Residual Risk
- Runtime behavior and perf impact at `1x` and `100x` still need in-engine headless/live validation on a machine with Godot installed.
- `write_book` direct-write path currently occurs immediately when in-range; if this proves too strong, convert to fully job-mediated transcription flow.

## Stability Hardening Update (same date, follow-up pass)

3. Added speed-tier backpressure for new Matrix posting paths
- File: `scripts/pawn/HeelKawnian.gd`
- Preservation path:
  - Added speed-tier global caps for `CARVE_KNOWLEDGE_STONE` and `BOOK_BINDING` pending counts.
  - Added speed-tier fail/success cooldown scaling for `12x/26x/50x/100x`.
- Learning path:
  - Added global cap on combined pending `TEACH_SKILL + APPRENTICESHIP`.
  - Retained local near-tile dedupe and added speed-tier cooldown scaling.
- Result:
  - Reduced risk of medium-lane autonomy posting bursts during fast-forward stress.
  - Keeps deterministic lane behavior and replay consistency.

Verification:
- Re-ran `bash tools/ai/sim-quality-gate.sh` after hardening changes: PASS.

## Household Coordination Stabilization Update (same date, follow-up pass)

4. Made household plan execution deterministic and side-effect safe
- Files:
  - `autoloads/HeelKawnianManager.gd`
  - `scripts/pawn/HeelKawnian.gd`
- Changes:
  - `get_household_ambition_for_pawn(...)` now supports `consume_cooldown: bool`.
  - Matrix decision path now calls household ambition in read-only mode (`consume_cooldown=false`) so profile scans do not mutate plan timers/state.
  - Matrix ambition seeding path now calls household ambition in write mode and posts concrete household jobs first.
  - Added household ambition event logging (`matrix_household_ambition`) with plan metadata.
  - Added speed-tier local/global pending backpressure to both household and settlement ambition posting.
- Effect:
  - Household objective chains now have a clear writer path.
  - Reduced coordination churn from read-path cooldown consumption.
  - Lower queue amplification risk under `26x`/`50x`/`100x`.

Verification:
- Re-ran `bash tools/ai/sim-quality-gate.sh` after household stabilization changes: PASS.

## Settlement Chain Reliability Update (same date, follow-up pass)

5. Added deterministic anti-stall recovery for settlement ambition chains
- File:
  - `autoloads/HeelKawnianManager.gd`
- Changes:
  - `_active_ambition_chains` entries now carry `step_started_tick` and `stall_strikes`.
  - `_ambition_chain_for_settlement(...)` now:
    - advances steps only when `_chain_step_completed(...)` confirms local feature truth;
    - boosts step priority with deterministic retry markers when a step is stalled;
    - advances past a blocked step after repeated stall windows (`CHAIN_STEP_STALL_STRIKES_MAX`) to avoid permanent chain deadlock.
  - Added `_chain_step_stall_ticks_for_speed()` so stall window scales with simulation speed tiers (`12x/26x/50x/100x`).
- Effect:
  - Chains remain truth-driven but no longer freeze indefinitely on blocked steps.
  - Recovery behavior remains deterministic and bounded under fast-forward stress.

Verification:
- Re-ran `bash tools/ai/sim-quality-gate.sh` after chain reliability changes: PASS.

## Settlement Chain Observability Update (same date, follow-up pass)

6. Added explicit chain lifecycle diagnostics for deadlock visibility
- File:
  - `autoloads/HeelKawnianManager.gd`
- Changes:
  - Added settlement-chain event logging helper to record lifecycle events into `WorldMemory` (`type=heelkawnian_development`, `event_type=settlement_chain`).
  - `_ambition_chain_for_settlement(...)` now logs:
    - `chain_start`
    - `step_complete`
    - `step_retry`
    - `step_skip_after_stall`
    - `chain_complete`
    - `chain_cleared_invalid`
  - Added `get_active_ambition_chains_debug()` for direct inspection of active per-settlement chain state.
- Effect:
  - 1x and 100x chain behavior can now be traced from world events instead of inferred indirectly.
  - Deadlock/stall patterns are diagnosable with explicit retry/skip markers.

Verification:
- Re-ran `bash tools/ai/sim-quality-gate.sh` after observability changes: PASS.
