# HeelKawn Verification Snapshot — 2026-05-24

## Scope
- Remove fake starting systems (seed stockpile, supplies, fire pits) when ORGANIC_CIVILIZATION_ENABLED=true
- Add road-like organic stockpile/settlement formation from repeated pawn activity
- Wire Inner Fire/Hearth Spark drives to the Matrix AI
- Fix SettlementMemory proto-site eligibility that was creating 16 empty settlements at dawn of time

## Repository Snapshot
- Branch: `main`
- Verification date: 2026-05-24 (UTC)
- `project.godot` main scene: `res://scenes/main/Main.tscn`
- `ORGANIC_CIVILIZATION_ENABLED = true` in `Main.gd`

## Implemented In This Pass

### 1. New Autoload: HearthMemory.gd
- **File:** `autoloads/HearthMemory.gd` (NEW)
- **Pattern:** Exact same architecture as RoadMemory — deterministic pressure accumulation from repeated activity
- **Pressure types:**
  - Pile pressure: `record_pile_deposit(tile, item_type)` — called when pawns haul with no accepting stockpile
  - Hearth pressure: `record_hearth_activity(tile)` — fire/warmth usage
  - Shelter pressure: `record_shelter_usage(tile)` — bed usage
- **Thresholds (like road tiers):**
  - `PILE_T1 = 3`: organic pile candidate
  - `PILE_T2 = 8`: strong pile location
  - `PILE_FORMAL = 15`: formal stockpile threshold
  - `HEARTH_T1 = 5`, `HEARTH_T2 = 12` for hearth activity
- **Decay:** `ACTIVITY_DECAY_TICKS = 20000` — all pressures decay by 1 every 20000 ticks
- **Inner Fire drive computation:** `get_inner_fire_for_pawn(tile, data)` returns:
  - `hearth_drive`: night (0.3) + inverse hearth proximity (0.5) + warmth pressure (0.5)
  - `storage_drive`: is_carrying (0.6) + pile pressure (0.3)
  - `shelter_drive`: rest < 30 + night with low hearth coverage
  - `survival_drive`: hunger + health < 50
  - Plus raw `hearth_pressure`, `pile_pressure` for inspection
- **DiscoveryGate unlocks:** `first_pile` at PILE_T1, `first_formal_stockpile` at PILE_FORMAL, `first_hearth_cluster` at HEARTH_T1
- **Region tracking:** `_formal_pile_regions` tracks which regions have crossed PILE_T1

### 2. HearthMemory added to autoloads
- **File:** `project.godot`
- **Change:** Added `HearthMemory="*res://autoloads/HearthMemory.gd"` right after `RoadMemory`
- **Ordering:** Follows the RoadMemory pattern intentionally — both are pressure-tracking autoloads

### 3. Hauling now records pile pressure before emergency drop
- **File:** `scripts/pawn/HeelKawnian.gd` line ~7211
- **Change:** In `_begin_haul_to_stockpile()`, when `sp == null` (no accepting stockpile zone):
  - BEFORE: just increment `_haul_retry_count`, emergency-drop at MAX_HAUL_RETRIES
  - AFTER: first call `HearthMemory.record_pile_deposit(data.tile_pos, data.carrying)` to build pressure
- **Impact:** Every time a pawn tries and fails to find a stockpile for hauling, that location accumulates pressure. After enough failures (3+), Main.gd will create an organic pile there.

### 4. ORGANIC_CIVILIZATION_ENABLED flag disables seeded bootstrap
- **File:** `scenes/main/Main.gd`
- **Change:** Added `ORGANIC_CIVILIZATION_ENABLED = true` constant with documentation
- **3 locations wrapped:**
  1. `_bootstrap_colony()`: initial world start — skips `_place_stockpile()`, `_seed_starting_supplies()`, `_seed_initial_fire_pits()`
  2. `_reroll_world()`: same bootstrap skipped on reroll; still calls `_ensure_validation_session_seed_stockpile_overlaps_settlement()`
  3. `_apply_save_dict()`: when save has no stockpile zones, legacy forced `_place_stockpile()` — now only does this if `!ORGANIC_CIVILIZATION_ENABLED`
- **When false:** Legacy behavior guaranteed — seed stockpile at world center, starting supplies, 5 fire pits, 10 beds (for testing/debugging)
- **When true:** World starts dormant. No free infrastructure. Civilization must emerge from:
  - Pawns foraging for berries (DIRECT_FORAGING already handles eating on spot)
  - Pawns trying to haul items with no stockpile → pressure builds
  - Pressure reaches threshold → organic pile forms
  - Organic pile creates feedback loop → more activity → more pressure

### 5. Organic pile creation from pressure
- **File:** `scenes/main/Main.gd`
- **New helpers:**
  - `_find_highest_pressure_pile_location(center, radius)`: scans radius around center, returns tile with highest `HearthMemory.get_pile_level()` (must be >= 1 = PILE_T1)
  - `_ensure_organic_pile(center)`: creates 1x1 stockpile at buildable tile near center, with minimal starter items: 3 BERRY, 2 WOOD, 1 STONE
- **Integration point:** `_seed_bootstrap_jobs_near_pawn_cluster()`
  - Before: always called `_ensure_settlement_stockpile(center)` when no zones existed
  - After: first calls `_find_highest_pressure_pile_location(center, 12)`. If found (>= PILE_T1), creates organic pile there. Otherwise falls back to arbitrary center.

### 6. Inner Fire drives wired to Matrix AI job biases
- **File:** `autoloads/HeelKawnianManager.gd`
- **New function:** `_apply_inner_fire_bias_to_biases(biases, data, pawn)`
- **Drive → bias mapping (deterministic, no RNG):**
  - `hearth_drive` (0.0-1.0) → bias 0-8:
    - +bias: BUILD_FIRE_PIT, BUILD_HEARTH
    - +bias/2: CHOP, GATHER_STICK
  - `storage_drive` (0.0-1.0) → bias 0-8:
    - +bias: BUILD_STORAGE_HUT
    - +bias/2: BUILD_GRANARY, BUILD_CELLAR
  - `shelter_drive` (0.0-1.0) → bias 0-8:
    - +bias: BUILD_BED, BUILD_SHELTER
    - +bias/2: BUILD_WALL
  - `survival_drive` (0.0-1.0) → bias 0-6:
    - +bias: FORAGE, HUNT, FISH, GROW_FOOD
    - -bias: TEACH_SKILL, APPRENTICESHIP, CARVE_KNOWLEDGE_STONE (deprioritize during crisis)
- **Integration:** Called in `get_matrix_decision_for_pawn()` right before skill-tree/work-speed biases
- **Contract:** These are BIASES, not overrides. Job legality checks, survival gates, and normal claim flow still apply. Inner Fire only nudges priorities.

### 7. SettlementMemory proto-site eligibility FIX (critical)
- **File:** `autoloads/SettlementMemory.gd` lines ~418-440
- **Root cause:** Original code had two bugs:
  1. `if has_deaths and has_scar: eligible.append(rk)` came FIRST — this caused 16 empty proto-settlements at tick 30000, because worldgen creates historical death locations and scar levels during terrain generation. These are "ruins waiting to happen" at dawn of time, not active civilization.
  2. After that early return, there were duplicate `elif has_buildings:` and `elif has_community:` blocks that were UNREACHABLE dead code.
- **Fix:** Reordered logic to require ACTIVE CURRENT CIVILIZATION:
  1. `if has_buildings:` → eligible (actual infrastructure built by current pawns)
  2. `elif has_community:` → eligible (actual pawns living/working together: >= 2 per region)
  3. `elif has_deaths and has_scar:` → COMMENTED OUT. This is for RUIN REVIVAL, which should only trigger AFTER a settlement has collapsed and been abandoned, not at world initialization.
- **Also fixed:** The unreachable `elif` blocks after `has_deaths and has_scar` are now inside the else branch of the organic civilization logic (or rather, the logic was restructured so has_buildings and has_community are checked first).

## Static Verification In This Environment
- No Godot binary available for headless smoke.
- Code inspection verification:
  1. `HearthMemory.gd` pattern matches `RoadMemory.gd` exactly (static `_get_instance()`, per-tile PackedInt32Array pressure, decay on timer, deterministic)
  2. No `randf()/randi()` in HearthMemory — all deterministic from pawn actions
  3. `project.godot` autoload order: HearthMemory right after RoadMemory (correct)
  4. `HeelKawnian.gd` haul path: `record_pile_deposit()` called BEFORE emergency drop (pressure accumulates on every failed haul, not just final drop)
  5. `Main.gd`: All 3 bootstrap locations correctly wrapped with `if not ORGANIC_CIVILIZATION_ENABLED:`
  6. `HeelKawnianManager.gd`: `_apply_inner_fire_bias_to_biases()` uses `_add_bias()` like all other bias functions — correctly integrates with Matrix AI
  7. `SettlementMemory.gd`: Fixed logic is correct — has_buildings and has_community now checked before any ruin-based eligibility

## Playtest Verification Checklist (run in Godot editor)
- **[ ] Boot smoke:** No parse errors, no crashes, F10 menu opens
- **[ ] Organic start:** Verify no seed stockpile at (127,127) on fresh world
- **[ ] Pressure accumulation:** Let sim run at 50x-100x. F10/HearthMemory should show pile pressure building where pawns cluster
- **[ ] Organic pile formation:** Verify that after enough haul failures (~3+ at same location), a 1x1 stockpile appears with minimal starter items
- **[ ] No empty proto-settlements:** At tick ~1000-5000, check F10/SettlementMemory count. Should be 0 or 1 (where pawns actually are), not 16
- **[ ] Inner Fire biases:** With cold night + pawns carrying items + tired, F10/49 HeelKawnians should show Matrix biases toward BUILD_FIRE_PIT, BUILD_STORAGE_HUT, BUILD_BED
- **[ ] Determinism:** Same seed + same inputs → same pressure accumulation → same organic pile locations across runs
- **[ ] Legacy toggle:** Set `ORGANIC_CIVILIZATION_ENABLED = false` temporarily, verify seed stockpile returns at (127,127)

## Residual Risk
- **Playtest required:** Full runtime behavior verification needs Godot editor. Static verification confirms code structure is correct.
- **Pile feedback loop:** The 1x1 organic pile has only 3 berry, 2 wood, 1 stone. This may not be enough to bootstrap a full settlement. Tuning likely needed after playtest.
- **Pressure thresholds:** PILE_T1=3 may be too low (false positives) or too high (pawns give up before pile forms). Needs calibration.
- **Ruin revival disabled:** The `has_deaths AND has_scar` path is commented out. Ruin revival needs to be re-enabled with a guard that only applies after a settlement has actually collapsed (not at world init).
- **Decay timing:** ACTIVITY_DECAY_TICKS=20000 may be too fast (pressure gone before pile forms) or too slow (pressure accumulates across unrelated events).
- **Matrix bias strength:** Inner Fire biases at 0-8 range are calibrated relative to other Matrix biases. May need tuning after observing actual job selection.

## Files Changed
- NEW: `autoloads/HearthMemory.gd`
- MODIFIED: `project.godot` (HearthMemory autoload)
- MODIFIED: `scripts/pawn/HeelKawnian.gd` (haul pressure recording)
- MODIFIED: `scenes/main/Main.gd` (ORGANIC_CIVILIZATION_ENABLED flag, organic pile helpers)
- MODIFIED: `autoloads/HeelKawnianManager.gd` (Inner Fire → Matrix AI wiring)
- MODIFIED: `autoloads/SettlementMemory.gd` (proto-site eligibility fix)
- MODIFIED: `docs/HEELKAWN_STATE.md` (updated with May 24 changes)
- NEW: `docs/STATE_VERIFICATION_2026-05-24.md` (this file)
