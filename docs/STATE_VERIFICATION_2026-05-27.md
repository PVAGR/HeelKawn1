# HeelKawn Verification Snapshot - 2026-05-27

## Scope
- Prune stale faction records after settlement downgrade.
- Make trade route seeding and renewal depend on formal settlements only.
- Replace the global stockpile fallback in infrastructure formalization with a settlement-local stockpile check.

## Implemented In This Pass
- `autoloads/FactionRegistry.gd`: `sync_from_settlements()` now removes houses for zones that are no longer formal settlements before rebuilding the live registry.
- `autoloads/FactionSystem.gd`: added `sync_from_settlements()` plus on-tick pruning so live faction pairs cannot keep stale endpoints.
- `autoloads/TradeMemory.gd`: trade creation now uses formal settlements only, stale routes are removed when endpoints stop being formal, and route caches rebuild from the current live route set.
- `autoloads/SettlementMemory.gd`: infrastructure formalization now checks for a local stockpile owned by the candidate settlement instead of any global stockpile.

## Validation
- `get_errors` on the touched GDScript files passed with no errors.
- `tools/ai/verify-compile.ps1` reached Godot compile checks successfully; the script exited non-zero because of a pre-existing warning about `res://scripts/ai/AISettlementManager.gd` not being found.

## Residual Risk
- Full runtime behavior still needs editor playtest validation.
- The compile script warning appears unrelated to this change, but it remains an existing repo issue.

## 100x Frame-Cap Adjustment

## Scope
- Reduce the 100x tick burst cap so long simulation batches stop overrunning a rendered frame.
- Keep the `GameManager` diagnostics aligned with the active tick cap so performance reads are truthful.

## Implemented In This Pass
- `autoloads/TickManager.gd`: lowered the 100x tick burst cap from 12 to 4 on desktop and mobile paths, reducing the amount of simulation work done in a single rendered frame.
- `autoloads/GameManager.gd`: updated the 100x diagnostic cap to match the new active cap.
- `docs/HEELKAWN_STATE.md`: recorded the performance change in the current state log.

## Validation
- `get_errors` on the touched GDScript files reported only pre-existing unrelated warnings; the edited cap lines themselves were clean.
- `bash tools/ai/sim-quality-gate.sh` could not run in this shell because `/bin/bash` is unavailable here.

## Residual Risk
- This change should reduce frame-time spikes at 100x, but I could not complete the full Godot smoothness gate in this environment.
- The unrelated compile warnings already present in `GameManager.gd` and `TickManager.gd` remain outside this change.