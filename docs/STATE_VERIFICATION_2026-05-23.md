# State Verification: May 23, 2026

## What Changed

### FIX: Settlement Formalization Not Triggering

**Root Cause Identified**: `_seed_starting_supplies()` and `_seed_initial_fire_pits()` existed in `Main.gd` but were **never called** during bootstrap or world reroll. This meant:
1. No starting materials were added to the stockpile
2. No fire pits were pre-placed
3. Pawns could not satisfy the formalization gate (requires hearth OR 2+beds + hearth + storage)
4. 18 proto_sites existed but 0 formal settlements formed

**Fix Applied**: Added calls to both `_bootstrap_colony()` and `_reroll_world()`:
```gdscript
# In _bootstrap_colony() (line ~2432):
_place_stockpile(main_component)
_seed_starting_supplies()
_seed_initial_fire_pits(main_component)

# In _reroll_world() (line ~6382):
_seed_starting_supplies()
_seed_initial_fire_pits(main_component)
```

**Files Modified**:
- `scenes/main/Main.gd`: +5 lines (3 function calls + 2 comment lines)

## What Was Verified

### Static Analysis — ALL PASSED

| Check | Result | Details |
|-------|--------|---------|
| Determinism (critical autoloads) | ✅ PASS | No `randf`/`randi`/`rand_range` in `DisasterSystem.gd`, `CataclysmSystem.gd`, `KnowledgeSystem.gd` |
| Legacy world dimensions | ✅ PASS | No `map_width`/`map_height` in `DisasterSystem.gd`, `WildlifePopulation.gd`, `FarmingSystem.gd` |
| Main scene configured | ✅ PASS | `run/main_scene="res://scenes/main/Main.tscn"` (line 19 of `project.godot`) |
| Safe data access | ✅ PASS | All `SurvivalSystem.gd` property accesses use existing codebase pattern: `data.hunger`, `data.thirst`, `data.body_temperature` direct property access (no 2-arg `.get()`) |
| All smoke scripts exist | ✅ PASS | `sim_boot_smoke.gd` (59L), `sim_settlement_public_state_smoke.gd` (304L), `sim_worldmeaning_region_tags_smoke.gd` (194L), `sim_performance_smoothness_smoke.gd` (190L) |
| Required docs exist | ✅ PASS | `docs/AI_RUNTIME_MANDATE.md`, `docs/HEELKAWN_STATE.md` |

### Quality Gate Script

- `tools/ai/sim-quality-gate.sh` is well-structured but requires `rg` (ripgrep) which is not installed in this environment
- The 3 static checks in the script were manually verified and all pass
- Godot binary not available → headless smoke tests deferred to user's machine

### Performance Architecture

- **TickBudgetManager**: Hard budget is 16ms (`TICK_BUDGET_MS`), not 12ms as in the plan (plan is stale)
- **Budget gates** are distributed throughout `_on_game_tick()` with early-returns at 6 critical points
- **`_high_speed_interval()`**: Adaptive cadence stretches non-critical intervals at 26x/50x/100x speeds
- **Construction seed**: `CONSTRUCTION_JOB_SEED_INTERVAL_TICKS = 30`, now cached with `_feature_scan_cache` (600-tick TTL)

## What Remains Unverified / Risky

- **Runtime smoke tests**: Cannot run without Godot binary — defer to user
- **F10 diagnostic menu**: Needs Godot editor to validate 47+ panels
- **Playable baseline**: Needs Godot editor to verify pawns, settlements, HUD
- **Tick batch performance**: PLAN.md claims 12ms budget, but actual code is 16ms — the plan may be outdated. Actual tick_batch was ~33ms per STATE_VERIFICATION_2026-05-22.md

---

## Verification Commands (for user to run on their machine)

```bash
# Pre-flight static checks (no Godot needed)
cd HeelKawn1
grep -En '(?<!\.)\b(?:randf|randi|rand_range)\(' autoloads/DisasterSystem.gd scripts/world/CataclysmSystem.gd autoloads/KnowledgeSystem.gd  # Should be empty
grep -n 'map_width\|map_height' autoloads/DisasterSystem.gd autoloads/WildlifePopulation.gd autoloads/FarmingSystem.gd  # Should be empty
grep '^run/main_scene=' project.godot  # Should show Main.tscn

# Headless smoke tests (requires Godot binary)
godot --headless --path . -s res://tools/sim_boot_smoke.gd
godot --headless --path . -s res://tools/sim_settlement_public_state_smoke.gd
godot --headless --path . -s res://tools/sim_worldmeaning_region_tags_smoke.gd
godot --headless --path . -s res://tools/sim_performance_smoothness_smoke.gd

# Full quality gate
bash tools/ai/sim-quality-gate.sh
```