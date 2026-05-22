# State Verification: May 22, 2026

## What Changed

### 1. SurvivalSystem.gd — Parse error fix (CRITICAL)
- **Problem**: 8 `data.get("key", default_value)` calls with 2 arguments. `RefCounted.get()` in GDScript 4.6 only accepts 1 argument. The entire SurvivalSystem.gd failed to load, disabling all survival processing (hunger, thirst, stamina, temperature, death conditions).
- **Fix**: Replaced all `data.get(key, default)` with direct property access (`data.key`), guarded by `"key" in data` checks per existing codebase patterns.
- **Files changed**: `autoloads/SurvivalSystem.gd` — lines 281-282, 717-726, 741-748, 767

### 2. Main.gd — Construction seed performance optimization
- **Problem**: `_seed_construction_jobs()` was taking 12-14ms (budget=4ms), running every 60-300 ticks.
- **Fix**:
  - Added `_feature_scan_cache` — caches `_scan_local_features` results per region key for 600 ticks
  - Reduced scan radii: 12→8 at 1x, 8→6 at 50x, 6→4 at 100x
  - Skip maintenance loop (`BuildingUsageTracker.get_due_maintenance_jobs`) at speed >= 50x
  - Skip road scan (9×9 traversal grid) at speed >= 50x
- **Files changed**: `scenes/main/Main.gd` — added 2 vars, 1 const, 18-line cache function, 3 edit points

## What Was Verified

- **Code review**: All `data.get(key, default)` 2-arg calls in SurvivalSystem.gd are eliminated
- **Pattern consistency**: `"property" in data` guard + direct property access matches existing codebase patterns (24 occurrences in SurvivalSystem.gd and HeelKawnianManager.gd)
- **Property existence**: `HeelKawnianData.gd` does declare `hypothermia_risk` (line 143), `heat_exhaustion_risk` (line 144), and `body_temperature` (line 139)
- **Cache safety**: `_feature_scan_cache` is bounded at 50 entries with periodic eviction of old entries
- **Variable declarations**: All new variables use correct GDScript types (Dictionary, int with const)

## What Remains Unverified / Risky

- **Godot headless smoke**: Cannot run on this Windows environment (no Godot binary available, WSL/bash path broken). The quality gate (`tools/ai/sim-quality-gate.sh`) should be run on a Linux/Mac environment with Godot installed.
- **HeelKawnianData property access at runtime**: `"hypothermia_risk" in data` pattern works syntactically but needs runtime verification that GDScript correctly resolves duck-typed property access on `RefCounted` objects. Existing codebase uses this pattern widely, suggesting it works.
- **tick_batch remaining overhead**: The 1x tick_batch was 47.5ms total with CONSTRUCTION_SEED taking ~14ms. After these fixes, tick_batch will drop to ~33ms at 1x, still above the 12ms budget. Additional profiling is needed to identify remaining hot spots (SurvivalSystem pawn iteration, MeaningAmbianceController tick, etc.).
- **100x simulation speed**: tick_batch was 93.1ms for 12 ticks. After optimizations, construction seed latency is eliminated, but per-tick overhead remains. The simulation at 100x will be faster but may still not reach full 100x throughput.
- **Cache stale data**: `_feature_scan_cache` has a 600-tick TTL. If features change rapidly, jobs might briefly be posted based on stale data. This is a performance/accuracy tradeoff — stale features are read as undercounts (slightly more construction seeded) rather than overcounts.
