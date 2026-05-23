# HeelKawn Verification Snapshot — 2026-05-22

## Scope
- Replace the unconditional settlement job tech gate stub with a real requirement check.
- Record the current local verification status for this pass.

## Repository Snapshot
- Branch: `main`
- Verification date: 2026-05-22 (UTC)
- `project.godot` main scene: `res://scenes/main/Main.tscn`

## Implemented In This Pass

### 1. Settlement job tech gate
- **File:** `autoloads/TechnologySystem.gd`
- **Change:** `can_settle_perform_job_type()` now inspects `BuildingRegistry.get_building_by_job_type(job_type)` and checks each `requires_tech` requirement.
- **Resolution path:**
  - Direct completion in `TechnologySystem` for research-tree tech IDs.
  - Settlement knowledge security lookup in `KnowledgeSystem` for requirement names that map to existing knowledge categories.
  - Unknown requirement names remain permissive so the gate does not block future content by accident.
- **Impact:** The live job claim paths in `JobManager` and `HeelKawnian` no longer pass every registered settlement build unconditionally.

## Local Verification In This Environment
- Full Godot execution is not available in this environment.
- Source-level change only; runtime validation still requires editor/headless execution.

## Residual Risk
- The knowledge mapping for some registry requirements uses the closest currently available knowledge category proxy, not a perfect one-to-one taxonomy.
- If a future job/build requirement is added to `BuildingRegistry` without a matching tech-tree or knowledge mapping, it will remain permissive until the mapping is extended.# State Verification: May 22, 2026

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

---

## May 22, 2026 — QA Review (OpenHands)

### PR #20 → #21 Cleanup
- **PR #20**: Had broken `.gitignore` (removed `.godot/` exclusion = would track project cache)
- **PR #21**: Clean version with only spatial grid performance fix
- **Merged**: Direct push to main, commit `8d2b62af`

### Source Code Verification

| Check | Status |
|-------|--------|
| Determinism (global RNG) | ✅ CLEAN - only in WildlifePopulation.gd (acceptable) |
| Main scene configured | ✅ `res://scenes/main/Main.tscn` |
| Legacy map dimensions | ✅ None found |
| Parse errors | ✅ None detected |
| Critical files exist | ✅ All verified |

### Performance Infrastructure
- Adaptive tick budgets: 8ms (1x) → 5ms (50x) → 3ms (100x)
- Planner budget gate: 12ms skip threshold
- Social system budget: 70% of max pairs
- World meaning budget: 55% reduction under load

### Runtime Verification (Pending Godot)
- `tools/sim_boot_smoke.gd` - ready
- `tools/sim_settlement_public_state_smoke.gd` - ready
- `tools/sim_worldmeaning_region_tags_smoke.gd` - ready
- `tools/sim_performance_smoothness_smoke.gd` - ready

**To run**: `godot --headless --path . -s res://tools/sim_boot_smoke.gd`

---

## Late Add: Autoload Consolidation Phase 2 (2026-05-22)

### What Changed
- **6 autoloads deregistered**: SquadCoordinator, FragmentationManager, RelationalGraph, SacredGeography, ReligionLens, MythAge
- **Autoload count**: 150 → 141 (9 total across Phases 1 + 2)

### Conversion Strategies

| System | Strategy | Call Sites |
|--------|----------|------------|
| ReligionLens | Static class (`class_name ReligionLens`) | 24 refs — all preserved unchanged |
| MythAge | Static class (`class_name MythAge`), `tick()` called from Main | 9 refs — all preserved unchanged |
| SquadCoordinator | Lazy-loaded by WorldAI, wrapper methods | 2 refs — updated to WorldAI |
| FragmentationManager | Bootstrapped at root in `Main._ready()` | 2 refs — updated to path/member lookup |
| RelationalGraph | SocialManager adds to root | 49 refs — path lookups (KinshipSystem, AuthoritySystem) work unchanged; TradePlanner updated |
| SacredGeography | Bootstrapped at root in `Main._ready()` | 6 refs — 3 path lookups work unchanged; WorldOverlay updated to path lookup |

### What Was Verified (Static Analysis)
- No remaining `Engine.has_singleton` or `Engine.get_singleton` calls for deregistered autoloads
- All 24 ReligionLens + 9 MythAge call sites preserved via static class pattern
- `/root/SacredGeography` and `/root/RelationalGraph` path lookups still work (nodes added to root)
- `Main._on_game_tick` now calls `MythAge.tick()` every tick (handles 50-ticks interval internally)
- `Main._ready()` bootstraps FragmentationManager and SacredGeography
- `project.godot` autoload count: 141 entries

### What Remains Unverified / Risky
- Runtime: Godot binary unavailable — cannot test boot smoke or runtime references
- `SocialManager._load_subsystem` function has a fallback that checks `/root/+sub`; if RelationalGraph (now at root) is queried by this path by another subsystem, it will be found — this is correct behavior
- MythAge static tick relies on `CivilizationStage.get_world_score()` and `SettlementMemory.get_formal_settlements()` being available at call time — both are still autoloads, so this is safe
