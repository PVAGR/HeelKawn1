# HEELKAWN — COMPLETING THE SIMULATION

## OBJECTIVE
Get the HeelKawn world simulating so you can watch HeelKawnians live, die, build, and be remembered.

## CONTEXT SUMMARY

**Current State:**
- Kernel systems implemented (WorldMemory, WorldMeaning, WorldPersistence)
- Settlement lifecycle machine exists (Active → Abandoned → Reviving → Ruin)
- Pawn AI with Matrix behavior exists
- ~164 autoloads (consolidating toward ~30)
- Many systems marked "Implemented but Needs Runtime Verification"

**Blockers:**
1. ✅ SurvivalSystem.gd was broken (parse errors from `data.get(key, default)`) - FIXED May 22
2. ⏳ Runtime truth pass not completed in Godot editor
3. ⏳ Performance issues at 1x speed (tick_batch ~47ms, budget=12ms)
4. ✅ Construction seed already optimized May 22

## APPROACH OVERVIEW

1. **Verify all systems compile and load** (determinism check, pathing check, scene check)
2. **Fix critical parse/runtime errors** (SurvivalSystem.gd already fixed, check others)
3. **Optimize hot paths** (construction seed already done, check other bottlenecks)
4. **Run smoke tests** (boot, settlement, worldmeaning, performance)
5. **Validate F10 diagnostics** (verify all panels render)
6. **Player can launch and watch simulation**

## IMPLEMENTATION STEPS

### Step 1: Determinism & Sanity Scan
- **Goal:** Ensure no global RNG in critical systems, no legacy world dimension fields
- **Method:**
  - Run `rg -nP '(?<!\.)\b(?:randf|randi|rand_range)'` on critical autoloads
  - Run `rg -n 'map_width|map_height'` on key systems
  - Check project.godot has main_scene configured
- **Reference:** `tools/ai/sim-quality-gate.sh` (lines 27-46)

### Step 2: Source Code Parse Audit
- **Goal:** Find and fix all parse errors before Godot loads
- **Method:**
  - Check `autoloads/*.gd` for common GDScript 4.6 issues:
    - `data.get(key, default)` → use `"key" in data` guard + `data.key`
    - `append_text()` → use `text +=`
    - Duplicate variable declarations
  - Fix all occurrences
- **Reference:** `autoloads/SurvivalSystem.gd` (fixed May 22)

### Step 3: Performance Hotspot Fixes
- **Goal:** Reduce tick_batch from ~47ms to <12ms at 1x speed
- **Method:**
  - Already done May 22: construction seed optimization (12→~33ms expected)
  - Check other hot spots: SurvivalSystem pawn iteration, MeaningAmbianceController, pawn pathfinding
  - Consider additional scan radius reductions at 1x
  - Add more caching where safe
- **Reference:** `scenes/main/Main.gd` (tick_batch), `docs/STATE_VERIFICATION_2026-05-22.md`

### Step 4: Headless Smoke Tests
- **Goal:** Verify simulation boots, settlements appear, worldmeaning computes, performance is smooth
- **Method:**
  - Run `tools/sim_boot_smoke.gd` — verify boot without errors
  - Run `tools/sim_settlement_public_state_smoke.gd` — verify settlements exist
  - Run `tools/sim_worldmeaning_region_tags_smoke.gd` — verify meaning tags
  - Run `tools/sim_performance_smoothness_smoke.gd` — verify `consistency=ok`
- **Reference:** `tools/ai/sim-quality-gate.sh` (lines 48-88)

### Step 5: F10 Diagnostic Validation
- **Goal:** All debug panels render without errors
- **Method:**
  - Open Main.tscn in Godot editor
  - Press F10, scroll through all menu items
  - Check Output panel for red errors
  - Fix any panel that crashes or shows empty/wrong data
- **Reference:** `scenes/ui/CreatorDebugMenu.gd`, `docs/HEELKAWN_STATE.md` (Runtime Truth Pass)

### Step 6: Playable Baseline Verification
- **Goal:** Player can launch game and watch simulation
- **Method:**
  - Launch game at 1x speed
  - Verify: pawns moving, jobs being posted/claimed, buildings being built
  - Verify: settlements forming, food being stored, deaths being recorded
  - Verify: HUD updating, tick counter advancing
- **Reference:** `scenes/main/Main.tscn`, `scripts/pawn/HeelKawnian.gd`

## TESTING AND VALIDATION

**Success Criteria:**
1. ✅ `bash tools/ai/sim-quality-gate.sh` passes all 4 checks
2. ✅ Game launches in Godot editor without parse errors
3. ✅ F10 menu shows all diagnostic panels (47+ items)
4. ✅ At 1x speed: tick_batch < 12ms, FPS > 50
5. ✅ At 100x speed: tick_batch < 100ms, simulation keeps up
6. ✅ Settlements spawn within first 1000 ticks
7. ✅ Pawns perform jobs (gather, build, rest, teach)
8. ✅ Deaths are recorded in WorldMemory
9. ✅ Chronicle export produces readable output

**Verification Commands:**
```bash
# Determinism check
rg -nP '(?<!\.)\b(?:randf|randi|rand_range)' autoloads/ | head -20

# Project scene check
rg -n '^run/main_scene=' project.godot

# Headless smoke (if Godot available)
godot --headless --path . --script tools/sim_boot_smoke.gd
```

## LORE EXPANSION (AFTER WORLD WORKS)

Once the simulation runs cleanly, expand:
1. **Factions** — make house-per-zone actually meaningful
2. **Religion** — Asha/DRUJ currents as subtle world pressures
3. **Metaphysics** — Life-Death-Veil-Pergatory cycle effects
4. **Timeline** — Era markers and historical playback
5. **Characters** — Notable HeelKawnians beyond anonymous pawns

## NOTES
- Smallest reversible change is the rule
- Document all fixes in `docs/STATE_VERIFICATION_YYYY-MM-DD.md`
- Update `CHANGELOG.md` after each session
- Don't add features until the base simulation is stable
