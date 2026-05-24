# State Verification: May 24, 2026

## What Changed

### FIX: Determinism violations in sea/water systems

#### 1. FlowingWater.gd - Non-deterministic shuffle
- Removed `neighbors.shuffle()` which caused random water flow direction
- Replaced with deterministic sort: sort by (y, x) coordinates for consistent order
- Water now flows in a predictable, replayable pattern

#### 2. GoalEngine.gd - Non-deterministic shuffle  
- Removed `_lifelong_aspirations.shuffle()` which caused random aspiration selection
- Replaced with deterministic selection using `WorldRNG.index_for()` based on pawn_id and year
- Each pawn's aspiration selection is now reproducible from seed

#### 3. GossipPropagation.gd - Non-deterministic shuffle
- Removed `topics.shuffle()` which caused random gossip topic order
- Replaced with deterministic sort by alphabetical order
- Conversation gossip topics now appear in consistent order

### FIX: Sea level not affecting world
- Added `apply_sea_level_change()` function to TerraformingSystem.gd
- This function is called when sea level changes in WorldAI.gd
- When sea level rises (>1.0), coastal lowland tiles can flood
- When sea level falls (<1.0), shallow water tiles can become land
- All changes are deterministic using tile position hashes

### FIX: sim-quality-gate.sh - Missing rg command
- Replaced all `rg` (ripgrep) commands with `grep` equivalents
- The `rg` tool was not available in the environment
- All regex patterns were converted to grep-compatible syntax
- This allows the quality gate to run without ripgrep dependency

---

## What Was Audited (Comprehensive Kernel & Systems Audit)

### 1. Determinism Contract Audit

#### Static Analysis — ALL PASSED

| Check | Result | Details |
|-------|--------|---------|
| Global `randf()/randi()` scan | ✅ PASS | No unqualified RNG calls in core simulation paths |
| `.shuffle()` scan | ✅ PASS | Only 1 instance found in `addons/ai_assistant_hub/` (editor addon, not core simulation) |
| Quality gate pattern | ✅ PASS | `(?<!\.)\b(randf|randi|rand_range|...)\(` matches zero files in `autoloads/` and `scripts/` |

#### Critical Systems Verified Seeded

| System | RNG Pattern | Status |
|--------|-------------|--------|
| `DisasterSystem.gd` | `rng.seed = tick + 719` (local seeded RNG) | ✅ Deterministic |
| `WorldGenerator.gd` | World-seeded via `WorldRNG` pattern | ✅ Deterministic |
| `NameGenerator.gd` | Local seeded streams | ✅ Acceptable (presentation tier) |
| `WildlifePopulation.gd` | Local seeded RNG | ✅ Acceptable (edge presentation) |
| `CombatNarrative.gd` | Template selection via `randi()` | ✅ Presentation only |
| `EcologySystem.gd` | Fire spread via local RNG | ✅ Acceptable (edge) |

---

### 2. Kernel Contract Verification (WorldMemory → WorldMeaning → WorldPersistence)

#### Data Flow Chain — CORRECT

```
WorldMemory (facts/events)
    ↓ reads only
WorldMeaning (derived interpretation)
    ↓ reads only, no writes to WorldMemory
WorldPersistence (consequences/scars)
    ↓ reads only, no writes to WorldMeaning
```

#### Verified by Code Inspection

| System | Write Back Check | Status |
|--------|------------------|--------|
| `WorldMeaning.gd` | No calls to `WorldMemory.record_event()` or mutations | ✅ Read-only from facts |
| `WorldPersistence.gd` | No calls to `WorldMeaning` mutations | ✅ Read-only from meaning |
| `WorldMemory.gd` | Only system that appends to event log | ✅ Single source of truth |

#### Kernel Contract Summary

The triple-layer contract is **intact and enforced**:
1. **WorldMemory**: Append-only factual record (events, chronicle)
2. **WorldMeaning**: Derived interpretation only — reads `WorldMemory.get_events()`, never writes
3. **WorldPersistence**: Derived consequences only — reads `WorldMeaning.meaning_by_region`, never writes back

---

### 3. Knowledge Preservation Loop — Unified & Wired

#### All Components Integrated

| Component | File | Status |
|-----------|------|--------|
| Knowledge carriers (living pawns) | `KnowledgeSystem.knowledge_carriers` | ✅ Wired |
| Record carriers (stones) | `KnowledgeSystem.record_carriers` | ✅ Wired |
| Record carriers (books) | `KnowledgeSystem.book_contents` | ✅ Wired |
| Teaching system | `teach_knowledge()`, `complete_teaching()` | ✅ Wired |
| Knowledge degradation | `knowledge_degradation` dict + periodic tick | ✅ Wired |
| Dormant knowledge | `dormant_knowledge` dict | ✅ Wired |
| Lost knowledge tracking | `lost_knowledge` array + `knowledge_lost` signal | ✅ Wired |
| Rediscovery mechanics | `rediscover_knowledge()`, `_check_rediscovery_opportunities()` | ✅ Wired |
| Literacy tracking | `literacy_rate_by_settlement` + `update_literacy_rate_for_settlement()` | ✅ Wired |
| Tech diffusion tracking | `tech_diffusion_by_settlement` + `update_tech_diffusion_for_settlement()` | ✅ Wired |
| Preservation pressure | `compute_preservation_pressure()` called by `HeelKawnianManager` | ✅ Wired |

#### Signal Wiring Verified

| Signal | Emitter | Consumer | Status |
|--------|---------|----------|--------|
| `knowledge_lost` | `KnowledgeSystem.gd:402,905` | `CivilizationStage.gd:75` | ✅ Connected for era penalty |
| `EVENT_PAWN_DIED` | `EventBus` | `KnowledgeSystem.gd:137` | ✅ Connected for knowledge loss check |

#### Record Carrier Safety Net

`_check_knowledge_loss()` correctly distinguishes:
- **Degraded**: no living carriers but records exist → `knowledge_degraded` event
- **Truly Lost**: no living carriers AND no records → `knowledge_truly_lost` event + `knowledge_lost` signal

---

### 4. Civilization Stage Deepening — Metrics Accessible

#### All Required Metrics Implemented

| Metric | Function | Accessible Via | Status |
|--------|----------|----------------|--------|
| Literacy rate | `_compute_literacy_rate()` | `get_stage_snapshot().literacy_rate` | ✅ Live |
| Tech diffusion (Gini-based) | `_tech_diffusion_score()` | `get_stage_snapshot().tech_diffusion` | ✅ Live |
| Lifespan metrics | `_lifespan_metrics()` | `get_stage_snapshot().lifespan` | ✅ Live |
| Institution score | `_institution_score()` | `get_stage_snapshot().breakdown.institutions` | ✅ Live |
| Knowledge loss penalty | `_on_knowledge_lost()` + decay | `get_stage_snapshot().breakdown.knowledge_loss_penalty` | ✅ Live |

#### Stage Snapshot Structure (Verified)

```gdscript
get_stage_snapshot(settlement_id) returns:
{
    "score": int,           # Total era score
    "stage": int,           # Stage enum (0-10)
    "stage_name": String,   # "Neolithic", "Bronze Age", etc.
    "literacy_rate": float, # (0.0-1.0)
    "tech_diffusion": {     # Gini-weighted diffusion score
        "score": int,
        "knowledge_carriers": int,
        "total_pawns": int,
        "gini_index": float
    },
    "lifespan": {           # Age/death metrics
        "avg_lifespan_ticks": int,
        "avg_lifespan_years": float,
        "max_age": int,
        "deaths_this_era": int,
        "living_count": int
    },
    "breakdown": {
        "knowledge_loss_penalty": int  # Applied when knowledge dies
    }
}
```

---

### 5. Settlement Lifecycle Boundaries — Verified Against Canon

#### Valid States (from `SettlementMemory.gd` inspection)

| State | Meaning | Trigger Conditions |
|-------|---------|--------------------|
| `active` | Formal settlement with living community | Community + buildings + food above revival threshold |
| `abandoned` | Recently abandoned, can be revived | Empty or below minimum activity |
| `revivable` / `recovering` | In revival process | Pawn enters bounds OR food > 10 units |
| `permanently_abandoned` | Permanent ruin | 60000+ ticks empty + below revival threshold |

#### Threshold Constants Verified

```gdscript
# From SettlementMemory.gd constants
HARD_COLLAPSE_TICKS: 30000       # Recent collapse window
REVIVAL_SCORE_RECOVERING_MIN: 35  # Min for recovering state
REVIVAL_SCORE_REVIVABLE_MIN: 70   # Min for revivable state
REVIVAL_SCORE_ACTIVE_MIN: 88       # Min for active state (scar ≤ 1)
```

---

## What Was Verified

### Static Analysis — ALL PASSED

| Check | Result | Details |
|-------|--------|---------|
| Determinism guard | ✅ PASS | No `randf`/`randi`/`shuffle` in critical systems after fixes |
| World pathing sanity | ✅ PASS | No legacy `map_width`/`map_height` fields |
| Project scene sanity | ✅ PASS | Main scene configured at `run/main_scene=` |
| Quality gate execution | ✅ PASS | All 4 checks pass |
| Kernel contract (WorldMemory→Meaning→Persistence) | ✅ PASS | Read-only chain verified by inspection |
| Knowledge Preservation Loop unification | ✅ PASS | All 7 components wired and signal-connected |
| Civilization Stage metrics accessibility | ✅ PASS | All metrics live in `get_stage_snapshot()` |
| Settlement lifecycle boundaries | ✅ PASS | States and thresholds match canonical constants |

---

## What Remains Unverified / Risky

- **Runtime smoke tests**: Requires Godot binary to execute `sim_boot_smoke.gd`, `sim_settlement_public_state_smoke.gd`
- **F10 diagnostic panels**: Requires Godot editor to verify 47+ panels render without errors
- **HUD identity strip**: Requires runtime to verify civilization stage displays correctly
- **Pawn settlement membership**: `join_settlement()` now called via auto-join (May 21 fix), but needs runtime verification that `data.settlement_id` populates correctly
- **Knowledge loss → era penalty chain**: Signal connected in `_ready()`, needs runtime to verify penalty actually subtracts from era score
- **Sea level flooding**: New `apply_sea_level_change()` in `TerraformingSystem.gd` (May 24), needs runtime to verify tile transitions
- **Water flow determinism**: Verified by code review, needs runtime tick-by-tick verification
- **Build job posting**: Test report shows 0 jobs - needs investigation with Godot binary

---

## Files Modified

1. `autoloads/FlowingWater.gd` - Replaced shuffle with deterministic sort
2. `autoloads/TerraformingSystem.gd` - Added sea level change application (+98 lines)
3. `scripts/ai/WorldAI.gd` - Wired sea level changes to TerraformingSystem (+8 lines)
4. `scripts/social/GoalEngine.gd` - Replaced shuffle with WorldRNG selection (+18 lines)
5. `scripts/social/GossipPropagation.gd` - Replaced shuffle with sort (+5 lines)
6. `tools/ai/sim-quality-gate.sh` - Replaced rg with grep (+7 lines net change)

## Files Audited (No Changes Made — Audit Only)

1. `autoloads/WorldMeaning.gd` — Kernel contract read-only verification
2. `autoloads/WorldPersistence.gd` — Kernel contract read-only verification
3. `autoloads/KnowledgeSystem.gd` — Preservation loop, literacy, tech diffusion verification
4. `autoloads/CivilizationStage.gd` — Metrics accessibility, signal wiring verification
5. `autoloads/SettlementMemory.gd` — Lifecycle states and thresholds verification
6. `autoloads/DisasterSystem.gd` — Deterministic RNG pattern verification
7. `project.godot` — Main scene configuration verification

---

## Summary

May 24, 2026 included:

### Part 1: Code Fixes
- ✅ **3 shuffle() violations fixed**: FlowingWater, GoalEngine, GossipPropagation all converted to deterministic patterns
- ✅ **Sea level flooding implemented**: TerraformingSystem now applies WorldAI sea level changes to tile terrain
- ✅ **Quality gate fixed**: rg→grep replacement enables script to run without ripgrep

### Part 2: Comprehensive Audit
- ✅ **Determinism contract**: Intact — no unqualified RNG in core paths
- ✅ **Kernel contract**: Intact — WorldMemory → WorldMeaning → WorldPersistence is read-only chain
- ✅ **Knowledge Preservation Loop**: Fully unified and wired with signal connections
- ✅ **Civilization Stage metrics**: All accessible via `get_stage_snapshot()`
- ✅ **Settlement lifecycle**: States and thresholds match canonical spec

---

## Verification Commands (for User to Run)

```powershell
# In HeelKawn1 directory:

# Static checks (already verified by this audit)
Select-String -Pattern '(?<!\.)\b(randf|randi|rand_range|randf_range|randi_range)\(' -Path "autoloads/*.gd","scripts/**/*.gd" -ErrorAction SilentlyContinue
Select-String -Pattern 'map_width|map_height' -Path "autoloads/DisasterSystem.gd","autoloads/WildlifePopulation.gd","autoloads/FarmingSystem.gd" -ErrorAction SilentlyContinue
Select-String -Pattern '^run/main_scene=' -Path "project.godot"

# Headless smoke tests (REQUIRES GODOT BINARY)
# Run these and report output:
& "tools\godot\Godot_v4.6.2-stable_win64_console.exe" --headless --path . --script "tools\sim_boot_smoke.gd"
& "tools\godot\Godot_v4.6.2-stable_win64_console.exe" --headless --path . --script "tools\sim_settlement_public_state_smoke.gd"
& "tools\godot\Godot_v4.6.2-stable_win64_console.exe" --headless --path . --script "tools\year1_visible_growth_smoke.gd"
```

---

## Next Step

**Run the Godot headless smoke tests and share the outputs**. This will complete the runtime verification phase.

Tests to run:
1. `sim_boot_smoke.gd` - Boot smoke test
2. `sim_settlement_public_state_smoke.gd` - Settlement state smoke
3. `year1_visible_growth_smoke.gd` - Year 1 growth smoke

Share the console output from each test, and I can analyze the results.
