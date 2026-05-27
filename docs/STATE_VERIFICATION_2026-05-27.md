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