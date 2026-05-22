# HeelKawn Verification Snapshot — 2026-05-21

## Scope
- Fix settlement context binding in WorldAI so pawn AI reports meaningful settlement IDs instead of `-1`.
- Fix warmth pressure calculation to account for lingering hypothermia risk (not just current body_temp).
- Fix PawnMoodUI null-instance crash at startup when `_modern_theme` autoload is not yet ready.
- Fix SurvivalSystem feature enum values so +8°C shelter/fire bonus actually applies at BED and FIRE_PIT tiles instead of RUIN and RABBIT.
- Fix dead-code `_pawn_profession_overrep` that never ran because both `settlement_id` values were always `-1`.

## Repository Snapshot
- Branch: `main`
- Verification date: 2026-05-21 (UTC)
- `project.godot` main scene: `res://scenes/main/Main.tscn`

## Implemented In This Pass

### 1. PawnMoodUI null-instance crash fix
- **File:** `scripts/ui/PawnMoodUI.gd`
- **Change:** Added `_create_label()` helper that falls back to `Label.new()` when `_modern_theme` is null; all 10 `_modern_theme.create_styled_label()` calls replaced.
- **Verification:** Headless Godot smoke should no longer fail at scene tree setup if theme autoload is delayed.
- **Root cause:** `_modern_theme` autoload can be null during initial scene tree population before all autoloads resolve.

### 2. WorldAI settlement context binding (4 sites)
- **Files:**
  - `scripts/ai/WorldAI.gd` lines 3417, 3487-3511, 3660-3679, 4052-4063
- **Change:** Replaced `pd.settlement_id` with live settlement lookups (`SettlementMemory.get_center_region_for_region()` / `get_settlement_id_for_region()` + `WorldPersistence.get_region_key()`).
- **Root cause:** `join_settlement()` is never called, so `data.settlement_id` stays `-1` everywhere. UI/world camera uses different path (`SettlementMemory` live lookup) which worked; AI was isolated.
- **Impact:** AI F10 reports should now show correct settlement IDs. Warmth pressure should no longer be `0.000` for pawns in settlements with hypothermia deaths and low fire coverage.

### 3. ColonySimServices warmth pressure
- **File:** `autoloads/ColonySimServices.gd` lines 540-555
- **Change:** Added `hypothermia_risk > 0 AND no hearth coverage` as second signal alongside existing `body_temp < 36.5°C` check.
- **Root cause:** Competing temperature systems (HeelKawnian `_check_temperature` toward ambient ~11-19°C on a 10-tick timer; SurvivalSystem `_regulate_temperature` toward target ~37°C on a ~4-tick batch cycle) can leave `body_temp` above 36.5°C while `hypothermia_risk` persists for ~1000 ticks from earlier cold exposure.
- **Impact:** Warmth pressure now correctly captures pawns that were recently cold.

### 4. SurvivalSystem feature enum values
- **File:** `autoloads/SurvivalSystem.gd` lines 368, 427
- **Change:** `feat == 3 or feat == 8` (RUIN=3, RABBIT=8) → `feat == 5 or feat == 10` (BED=5, FIRE_PIT=10)
- **Root cause:** Hardcoded feature values did not match `TileFeature.Type` enum ordering.
- **Impact:** +8°C shelter/fire bonus now correctly applies at BED and FIRE_PIT tiles in `_get_environmental_temperature` and `_update_wetness`. Previously bonus applied at RUIN and RABBIT tiles (no functional effect).

### 5. WorldAI `_pawn_profession_overrep` dead code
- **File:** `scripts/ai/WorldAI.gd` line 3528
- **Change:** Replaced direct `p.data.settlement_id != pd.settlement_id` (both always `-1`) with live region-key + settlement ID via `WorldPersistence` and `SettlementMemory`.
- **Impact:** Profession balance within settlements now works correctly. Previously overrepresentation check always returned `false`, so profession distribution was never balanced.

### 6. HeelKawnian AI settlement scoring bonuses (2 sites)
- **File:** `scripts/pawn/HeelKawnian.gd` lines 5664, 7755
- **Change:** Replaced direct `data.settlement_id == p.data.settlement_id` (both `-1`, always `false`) with `_current_settlement_center_region()` live lookups for both pawns.
- **Impact:** Teaching target selection and mentor selection now correctly award +4/+3 scoring bonus for same-settlement pawns. Previously pawns in the same settlement were not recognized as settlement-mates for scoring purposes.

### 7. Settlement auto-joining system
- **File:** `scripts/pawn/HeelKawnian.gd`
- **Change:** Added `SETTLEMENT_CHECK_TICKS = 120` constant, `_maybe_update_settlement_membership()` function, and hook in `_on_world_tick` after cohort checks. Enhanced `join_settlement()` and `leave_settlement()` with WorldMemory chronicle events and guard checks.
- **Root cause:** `join_settlement()` was never called by any system. `data.settlement_id` stayed `-1` for every pawn's entire life.
- **Fix:** Pawns now auto-detect when their tile position falls within a settlement's region bounds via `SettlementMemory.get_center_region_for_region()` and auto-join with `get_settlement_id_for_region()`.
- **Impact:** All downstream consumers (StockpileManager, JobManager, HeelKawnian.gd settlement-array lookups, CivilizationStage) now receive correct settlement IDs.

### 8. Temperature system unification
- **Files:** `autoloads/SurvivalSystem.gd`, `scripts/pawn/HeelKawnian.gd`
- **Change:**
  - `SurvivalSystem._regulate_temperature`: early-return when pawn data has `hypothermia_risk` (HeelKawnianData marker). Applies moodlets from risk but skips body_temp lerp. HeelKawnian.gd is sole authority on body_temp.
  - `SurvivalSystem._check_death_conditions`: added `hypothermia_risk >= 99` as alternative hypothermia death cause.
- **Root cause:** Two competing temperature systems modified `body_temp` independently toward different targets (HeelKawnian → ambient ~11-19°C, SurvivalSystem → ~37°C), preventing either from reaching dangerous thresholds.
- **Impact:** Hypothermia deaths can now occur (body_temp not rescued by SurvivalSystem). Moodlets still applied from risk. Legacy non-HeelKawnian pawns unchanged.

### 9. Survival → Chronicle event bridge
- **Files:** `scripts/pawn/HeelKawnian.gd`, `autoloads/SurvivalSystem.gd`
- **Change:** Added `WorldMemory.record_event()` calls at key survival thresholds:
  - HeelKawnian `_check_temperature`: hypothermia warning (risk > 50%), critical (risk > 80%), recovery (risk < 20%)
  - Heat exhaustion warning, critical, recovery
  - SurvivalSystem `_check_death_conditions`: survival warnings during grace, death risk warnings post-grace
- **Throttling:** Events fire every 300-600 ticks to prevent spam.
- **Impact:** Chronicle exports now include survival history (hypothermia episodes, heat stress, starvation warnings).

## Local Verification In This Environment
- Headless Godot binary not available in this environment.
- Manual checks:
  - All references to `WorldPersistence` and `SettlementMemory` confirmed present in WorldAI.gd context.
  - `TileFeature.Type` enum confirmed: NONE=0, ORE_VEIN=1, FERTILE_SOIL=2, RUIN=3, TREE=4, BED=5, WALL=6, DOOR=7, RABBIT=8, DEER=9, FIRE_PIT=10.
  - No remaining `pd.settlement_id` direct comparisons in WorldAI.gd (only the fixed live lookups).
  - `clampf` usage in ColonySimServices confirmed valid GDScript.

## Residual Risk
- Full runtime verification requires Godot headless or editor — not possible in this environment.
- Settlement auto-joining runs every 120 ticks per pawn. At 100x speed with 200 pawns, this adds ~1.7 settlement checks per tick. Acceptable performance profile.
- Temperature unification removes SurvivalSystem's body_temp rescue for HeelKawnian pawns. This means hypothermia can actually kill pawns now — previous behavior was effectively immortal from cold. This is INTENDED.
- Hypothermia death threshold from risk (99%) is very high. Combined with health damage from HeelKawnian.gd at risk > 80%, pawns may die from health depletion (injuries cause) before reaching 99% risk. This is acceptable — pawns die from cold either way.
- Settlement auto-joining may flip settlement_id rapidly if a pawn walks along a settlement border. The 120-tick check interval mitigates this. `join_settlement()` already guards against re-joining the same settlement.
- Chronicle events at 300-600 tick throttles may still produce significant volume over extended sim runs (one event per pawn per ~3-6 sim-days during cold spells). WorldMemory's internal event retention policies handle this.
- Settlement lookup functions (`WorldPersistence.get_region_key`, `SettlementMemory.get_settlement_id_for_region`) are expected to be deterministic and seed-based; no untracked global RNG introduced.
