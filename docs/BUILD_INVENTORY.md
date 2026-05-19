# HEELKAWN UNIVERSE — BUILD STATUS INVENTORY

> Comprehensive analysis of what is built vs. what the master plan requires

**Last Updated:** 2026-05-18
**Analysis Scope:** All autoloads, scripts, docs, and feature specs
**Authority:** This is the repo's built-vs-missing reality check. See `HEELKAWN_PROJECT_COMPASS.md` for the full truth hierarchy.

**Status label rule:** use **Verified Runtime Complete**, **Implemented but Needs Runtime Verification**, **Partial / Prototype**, or **Vision / TODO**. Older `DONE` language in historical docs should be interpreted as "implemented, then verify in the current runtime" unless this inventory explicitly marks a system verified.

---

## SECTION 1: KERNEL SYSTEMS — IMPLEMENTED, VERIFY CURRENT RUNTIME

| System | File | Status | Notes |
|--------|------|--------|-------|
| World Memory | `autoloads/WorldMemory.gd` | Implemented but Needs Runtime Verification | Append-only factual history, constitution validator, dirty tracking |
| World Meaning | `autoloads/WorldMeaning.gd` | Implemented but Needs Runtime Verification | Derived regional interpretation |
| World Persistence | `autoloads/WorldPersistence.gd` | Implemented but Needs Runtime Verification | Scars, ruins, abandonment, ironman save |
| Land Recovery | `autoloads/SettlementPersistenceManager.gd` | Implemented but Needs Runtime Verification | Visual healing |
| Cultural Memory | `autoloads/CulturalMemory.gd` | Implemented but Needs Runtime Verification | Inherited reputation |
| Settlement Memory | `autoloads/SettlementMemory.gd` | Implemented but Needs Runtime Verification | Clustered regions → places, lifecycle machine |
| Settlement Planner | `autoloads/SettlementPlanner.gd` | Implemented but Needs Runtime Verification | Autonomous building, pressure-driven construction |
| Settlement Architect | `autoloads/SettlementArchitect.gd` | Implemented but Needs Runtime Verification | Building placement logic |
| Settlement Registry | `autoloads/SettlementRegistry.gd` | Implemented but Needs Runtime Verification | Settlement tracking |
| Settlement Rebirth | `autoloads/SettlementRebirth.gd` | Implemented but Needs Runtime Verification | Revival with gates |
| Pawn Behavior | `scripts/pawn/HeelKawnian.gd`, `scripts/pawn/HeelKawnianData.gd` | Implemented but Needs Runtime Verification | Jobs, pathfinding, needs, skill trees, lineage |
| HeelKawnian Matrix AI | `autoloads/HeelKawnianManager.gd`, `scripts/pawn/HeelKawnian.gd` | Implemented but Needs Runtime Verification | Job-bias bridge, social intent, settlement ambition, household goals |
| Job Manager | `autoloads/JobManager.gd` | Implemented but Needs Runtime Verification | Job queue with dict compatibility adapter |
| Stockpile System | `autoloads/StockpileManager.gd` | Implemented but Needs Runtime Verification | Resource storage |
| Trade Planner | `autoloads/TradePlanner.gd` | Implemented but Needs Runtime Verification | Trade routes |
| World RNG | `autoloads/WorldRNG.gd` | Implemented but Needs Runtime Verification | Seeded randomness |
| Faction Registry | `autoloads/FactionRegistry.gd` | Partial / Prototype | House-per-zone with deterministic names, not full CK3-style |
| Religion Lens | `autoloads/ReligionLens.gd` | Partial / Prototype | Read-only overlay, composes SacredMemory + MythMemory |
| Meaning Ambiance Controller | `autoloads/MeaningAmbianceController.gd` | Implemented but Needs Runtime Verification | Audio/visual cues |
| Sacred Memory | `autoloads/SacredMemory.gd` | Implemented but Needs Runtime Verification | Tile-based sacred site tracking |
| Myth Memory | `autoloads/MythMemory.gd` | Implemented but Needs Runtime Verification | Region myth states, conflict intensity, rebirth tracking |

---

## SECTION 2: PHASE 4 FEATURES — IMPLEMENTED, VERIFY CURRENT RUNTIME

| Feature | Implementation | Status |
|---------|----------------|--------|
| Cultural divergence (OPEN/CAUTIOUS/DEFENSIVE) | `SettlementPlanner` constants | Implemented but Needs Runtime Verification |
| Revival/rebirth system | `SettlementRebirth.gd` + gates | Implemented but Needs Runtime Verification |
| Player-readable meaning (audio) | `MeaningAudioCue.gd` | Implemented but Needs Runtime Verification |
| Settlement identity depth | `SettlementMemory` state curve | Implemented but Needs Runtime Verification |
| Scar system | `WorldPersistence` + regional tracking | Implemented but Needs Runtime Verification |
| Peace gating | Per-culture peace tick thresholds | Implemented but Needs Runtime Verification |
| Profession reassignment | `HeelKawnianData.add_skill_xp` auto-assigns | Implemented but Needs Runtime Verification |
| Colony role balance | Diversity pressure when one profession dominates | Implemented but Needs Runtime Verification |
| Warrior peacetime patrol | Visible perimeter presence | Implemented but Needs Runtime Verification |
| Mode contract (Watch/Sprite/Observer) | `Main.gd` placement/command gates | Implemented but Needs Runtime Verification |

---

## SECTION 3: INCOMPLETE SYSTEMS — PRIORITY

### 🔴 CRITICAL (v1 Essential - Not Yet Implemented)

| System | File | Gap | Priority |
|--------|------|-----|----------|
| **HeelKawnian Matrix AI Deepening** | `scripts/pawn/HeelKawnian.gd`, `autoloads/HeelKawnianManager.gd` | Job-bias bridge live; needs preservation choices, recovery behavior, longer-horizon ambitions | P0 |
| **Knowledge Preservation Loop** | `autoloads/KnowledgeSystem.gd` | Stones/books/teaching exist but not unified; lost/rediscovered mechanics incomplete | P1 |
| **Civilization Stage Deepening** | `autoloads/CivilizationStage.gd` | Initial derived lens live; needs per-settlement tech diffusion, literacy, lifespan, institutions | P1 |
| **Readable Chronicle Export** | `scripts/system/ChronicleExport.gd` | Created but not wired into F10 menu | P1 |
| **FactionRegistry Real** | `autoloads/FactionRegistry.gd` | House-per-zone works; needs CK3-style politics, diplomacy, inter-faction relations | P1 |

### 🟡 SPECTATOR FEATURES (v1 - Partial)

| Feature | Status | Gap |
|---------|-------|
| Living World Map | ✅ EXISTS - zoomable |
| Timeline scrubbing | ❌ NOT - can pause/speed but no backward scrub |
| Region Inspection | ✅ EXISTS - Focus Inspector |
| Entity Watchlist | ❌ NOT |
| Historical Playback | ❌ NOT - no time travel |
| Chronicle Auto-Summary | ✅ EXISTS - F10 #36, `WorldMemory.build_readable_chronicle_summary()` |
| Export: World Seed | ✅ EXISTS - `ExportSystem.export_promotion_bundle()` writes world_seed.json |
| Export: Chronicle | ✅ EXISTS - `ExportSystem.export_chronicle()` writes chronicle.json |

### 🟡 INCARNATION FEATURES (v1 - NOT IMPLEMENTED)

| Feature | Status | Gap |
|---------|-------|
| Incarnation Entry | ❌ NOT - player is OBSERVER only |
| Embodied Control | ❌ NOT - player can't move a pawn |
| Human bodily needs | ⚠️ NPC only - not player |
| Local Knowledge Fog | ❌ NOT - no player pawn exists |
| Occupation Through Doing | ❌ NOT |

### 🟢 GOVERNANCE & POLITICS (v2 - Most Stubs)

| Feature | File | Status |
|---------|------|--------|
| Governance Forms | `SettlementMemory.gd` | Stub - "governance_placeholder" |
| Law & Custom | ❌ NOT | No taboo system |
| Diplomacy | ❌ NOT | No messenger/treaty system |
| War Campaigns | `SettlementMemory.gd` | Stub only |
| Marriage Rules | ❌ NOT | Random mate selection |
| Taboo Enforcement | ❌ NOT |

### 🟢 RELIGION & METAPHYSICS (v2 - All Stubs)

| Feature | File | Status |
|---------|------|--------|
| Religion Lens | `autoloads/ReligionLens.gd` | Read-only overlay, composes SacredMemory + MythMemory |
| Sacred Memory | `autoloads/SacredMemory.gd` | Tile-based sacred site tracking (functional) |
| Myth Memory | `autoloads/MythMemory.gd` | Region myth states, conflict intensity (functional) |
| Asha/DRUJ Currents | ❌ NOT | No morality currents |
| Echoes of Dead | ❌ NOT | No dreams/ghosts |
| Veil-Aware Sites | ❌ NOT | No thin places |
| Asha Gift | ❌ NOT | No subtle boons |

---

## SECTION 4: MASTER PLAN V1 REQUIREMENTS CHECK

From `docs/HEELKAWN_STANDALONE_MASTER_PLAN.md` **Section 7** (Must-have v1):

| Required | Current Status | Gap |
|----------|----------------|-----|
| Deterministic world tick | ✅ DONE | — |
| Spectator mode | ✅ DONE | — |
| **Incarnation mode** | ❌ NOT | Player cannot enter world as pawn |
| **Human bodily needs** | ⚠️ NPC only | Not for player |
| Settlement simulation | ✅ DONE | — |
| NPC households | ✅ IMPLEMENTED | `household_id` tracking, `SocialManager.create_household` |
| Professions by doing | ✅ IMPLEMENTED | Auto-assign via `add_skill_xp`, profession reassignment |
| WorldMemory expanded | ✅ DONE | — |
| WorldMeaning prototype | ✅ DONE | — |
| Historical ruins | ✅ DONE | — |
| Civilization stage lens | ✅ INITIAL LIVE | Derived era score, not full era simulation |
| Per-pawn HeelKawnian development AI | ✅ INITIAL LIVE | Job-bias bridge, social intent, ambition seeding |
| Birth and death | ✅ IMPLEMENTED | Lineage via `PawnSpawner.spawn_child_pawn` |
| Basic kinship | ✅ IMPLEMENTED | `KinshipSystem`, `family_bonds`, `children_ids` |
| Food and storage | ✅ DONE | — |
| Fire and shelter | ✅ IMPLEMENTED | `BuildingRegistry` fire pit/hearth warmth + cooking |
| Trade and travel | ⚠️ Stub | No travel system |
| Conflict and raids | ⚠️ Basic | — |
| Local reputation | ⚠️ Partial | — |
| Region history panel | ⚠️ Focus inspector | — |
| **Chronicle export** | ✅ IMPLEMENTED | `ExportSystem.export_promotion_bundle()` |
| **World seed export** | ✅ IMPLEMENTED | `ExportSystem.export_promotion_bundle()` writes world_seed.json |

---

## SECTION 5: CANON QUEUE STATUS

From `docs/WORLD_BIBLE/CANON_SYSTEMS_FEATURE_QUEUE.md`:

### Immediate Queue (All DONE 2026-04-30)
- ✅ Canon glossary normalization pass
- ✅ Era hooks to simulation events
- ✅ Region-to-faction canon bridge

### Near-Term Queue
- ✅ Cultural architecture signature set - DOCUMENTED
- ✅ Player-readable meaning refinement - DONE (audio implemented)
- ✅ Revival storyline constraints - DONE

---

## SECTION 6: TOP PRIORITY BUILDS

Based on gaps + master plan v1 requirements:

### P0 - Must Build Next
1. **Runtime Truth Pass** - verify UI panels, F10 diagnostics, and red errors in Godot.
2. **HeelKawnian Matrix AI Deepening** - expand into preservation choices, recovery behavior, longer-horizon ambitions.
3. **Knowledge Preservation Loop** - unify stones, books, teaching, literacy; add lost/rediscovered mechanics.

### P1 - High Priority
4. **Civilization Stage Deepening** - add per-settlement tech diffusion, literacy, lifespan, institutions.
5. **Readable Chronicle Export** - wire `ChronicleExport.gd` into F10 menu.
6. **FactionRegistry Real** - extend house-per-zone to CK3-style politics.
7. **Tool/Item System** - ground items and tool requirement checks (PlayerGathering.gd fixed May 18).

### P2 - Medium Priority
8. **Governance Forms** - implement actual leadership selection.
9. **Knowledge Propagation** - connect `KnowledgeSystem` to teaching.
10. **Exports** - world seed import path for sharing worlds.

### P3 - Future Vision
11. **Taboo System** - law and custom accumulation.
12. **Diplomacy** - messenger/treaty foundation.
13. **Asha/DRUJ Currents**
14. **Echoes of Dead**
15. **Grand Campaigns**

---

## SECTION 7: FILES WITH TODOS/STUBS

### TODO patterns found (updated May 18, 2026)
- `autoloads/SettlementPlanner.gd` - terrain moisture check for crops
- `autoloads/TradeMemory.gd` - trade route logic stubs
- `scripts/pawn/HeelKawnianData.gd` - perk effects application
- `scripts/ui/TutorialHints.gd` - social tracking
- `autoloads/BodyRiskManager.gd` - healer profession integration
- `autoloads/AIAgentManager.gd` - ObservationAPI initialization
- `scripts/world/CataclysmSystem.gd` - EnemySpawner integration
- `scripts/ai/BattleReporter.gd` - battle effects on settlements
- `scripts/ai/HeelKawnPawnBrain.gd` - SpatialGrid population
- `autoloads/TechnologySystem.gd` - settlement job type checking
- `scripts/ai/BloodlineSystem.gd` - cross-bloodline relations
- `scripts/ui/ActionMenu.gd` - notification system
- `scripts/ui/GuildUI.gd` - player pawn tracking

### Previously marked TODOs — NOW IMPLEMENTED (May 18, 2026)
- ~~`scripts/pawn/PawnData.gd` - skill tree placeholders~~ → `HeelKawnianData.gd` skill_trees fully implemented
- ~~`scripts/pawn/Pawn.gd` - child creation stub~~ → `PawnSpawner.spawn_child_pawn` with inheritance
- ~~`scripts/pawn/Pawn.gd` - parent lookup~~ → `HeelKawnianData._get_parent_data` via static registry
- ~~`autoloads/CraftingSystem.gd` - material consumption~~ → `_consume_ingredients` removes from stockpile
- ~~`autoloads/PlayerGathering.gd` - tool checks~~ → `_has_required_tool` checks carried item + stockpile
- ~~`autoloads/PlayerGathering.gd` - skill XP~~ → `_get_skill_level` / `_gain_skill_xp` wired to HeelKawnianData
- ~~`autoloads/PlayerGathering.gd` - resource depletion~~ → `_deplete_resource` removes features, schedules regrow

### Stub classes (5)
- `SimVision.gd` - Roadmap design surface
- `FactionRegistry.gd` - House-per-zone (functional but basic)
- `ReligionLens.gd` - Read-only overlay (functional)
- `SacredMemory.gd` - Tile-based tracking (functional)
- `MythMemory.gd` - Region myth states (functional)

---

## CONCLUSION

The kernel has a strong deterministic foundation and currently passes headless smoke checks. Full editor/runtime validation remains the gate for "Verified Runtime Complete" labels.

**What's built:**
- Core world simulation (tick, memory, persistence)
- Settlement lifecycle (birth, death, revival)
- Cultural identity divergence
- Pawn behavior, jobs, skill trees, and lineage
- HeelKawnian Matrix AI (job bias, social intent, ambition seeding, household goals)
- Knowledge system (18 types, inscribed stones, book crafting)
- Trade and animals
- Export system (promotion bundle with world seed, chronicle, bloodlines, artifacts)
- PlayerGathering (tool checks, skill XP, resource depletion — fixed May 18, 2026)

**What's missing for v1:**
- Player incarnation capability
- Governance and law systems
- Religion/metaphysics hooks (Asha/DRUJ currents)
- Long-vision (travel, clans, eras)
- Runtime truth pass in Godot editor

**Recommended next step:** Run the runtime truth pass in Godot, then deepen the HeelKawnian Matrix AI into preservation choices and recovery behavior before expanding the knowledge preservation loop and civilization stage tracking.
