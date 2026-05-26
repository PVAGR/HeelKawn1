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
