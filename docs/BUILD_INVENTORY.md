# HEELKAWN UNIVERSE — BUILD STATUS INVENTORY

> Comprehensive analysis of what is built vs. what the master plan requires

**Last Updated:** 2026-05-17
**Analysis Scope:** All autoloads, scripts, docs, and feature specs
**Authority:** This is the repo's built-vs-missing reality check. See `HEELKAWN_PROJECT_COMPASS.md` for the full truth hierarchy.

**Status label rule:** use **Verified Runtime Complete**, **Implemented but Needs Runtime Verification**, **Partial / Prototype**, or **Vision / TODO**. Older `DONE` language in historical docs should be interpreted as "implemented, then verify in the current runtime" unless this inventory explicitly marks a system verified.

---

## SECTION 1: KERNEL SYSTEMS — IMPLEMENTED, VERIFY CURRENT RUNTIME

| System | File | Status | Notes |
|--------|------|--------|-------|
| World Memory | `autoloads/WorldMemory.gd` | Implemented but Needs Runtime Verification | Append-only factual history |
| World Meaning | `autoloads/WorldMeaning.gd` | Implemented but Needs Runtime Verification | Derived regional interpretation |
| World Persistence | `autoloads/WorldPersistence.gd` | Implemented but Needs Runtime Verification | Scars, ruins, abandonment |
| Land Recovery | `autoloads/SettlementPersistenceManager.gd` | Implemented but Needs Runtime Verification | Visual healing |
| Cultural Memory | `autoloads/CulturalMemory.gd` | Implemented but Needs Runtime Verification | Inherited reputation |
| Settlement Memory | `autoloads/SettlementMemory.gd` | Implemented but Needs Runtime Verification | Clustered regions → places |
| Settlement Planner | `autoloads/SettlementPlanner.gd` | Implemented but Needs Runtime Verification | Autonomous building |
| Settlement Architect | `autoloads/SettlementArchitect.gd` | Implemented but Needs Runtime Verification | Building placement logic |
| Settlement Registry | `autoloads/SettlementRegistry.gd` | Implemented but Needs Runtime Verification | Settlement tracking |
| Settlement Rebirth | `autoloads/SettlementRebirth.gd` | Implemented but Needs Runtime Verification | Revival with gates |
| Animal Spawner/Population | `autoloads/AnimalSpawner.gd`, `autoloads/AnimalPopulation.gd` | Implemented but Needs Runtime Verification | Seeded ecology |
| Pawn Behavior | `scripts/pawn/Pawn.gd`, `scripts/pawn/PawnData.gd` | Implemented but Needs Runtime Verification | Jobs, pathfinding, needs |
| HeelKawnian Matrix AI | `autoloads/HeelKawnianManager.gd`, `scripts/pawn/Pawn.gd` | Implemented but Needs Runtime Verification | Derived per-pawn phase/drive/next need now biases real job choice; includes initial social intent bridge (`social_seek` / `teach_seek` / `grudge_confront`); strong decisions log back to WorldMemory. `HeelKawnianIdentity.gd` is a `class_name` Resource (not an autoload) — accessed via `HeelKawnianIdentity.new()` |
| Job Manager | `autoloads/JobManager.gd` | Implemented but Needs Runtime Verification | Job queue system with dict compatibility adapter (`post_from_dict`) for legacy callers |
| Stockpile System | `autoloads/StockpileManager.gd` | Implemented but Needs Runtime Verification | Resource storage |
| Trade Planner | `autoloads/TradePlanner.gd` | Implemented but Needs Runtime Verification | Trade routes |
| World Clock | `autoloads/WorldClock.gd` | Implemented but Needs Runtime Verification | Tick/time management |
| World RNG | `autoloads/WorldRNG.gd` | Implemented but Needs Runtime Verification | Seeded randomness |
| Faction Registry | `autoloads/FactionRegistry.gd` | Partial / Prototype | House stub per zone only |
| Religion Lens | `autoloads/ReligionLens.gd` | Partial / Prototype | Read-only overlay |
| Meaning Ambiance Controller | `autoloads/MeaningAmbianceController.gd` | Implemented but Needs Runtime Verification | Audio/visual cues |

---

## SECTION 2: PHASE 4 FEATURES — IMPLEMENTED, VERIFY CURRENT RUNTIME

| Feature | Implementation | Status |
|---------|----------------|--------|
| Cultural divergence (OPEN/CAUTIOUS/DEFENSIVE) | `SettlementPlanner` constants | Implemented but Needs Runtime Verification |
| Architecture signature constants | (table — docs/GLOSSARY.md does not exist) | Implemented but Needs Runtime Verification |
| Revival/rebirth system | `SettlementRebirth.gd` + gates | Implemented but Needs Runtime Verification |
| Player-readable meaning (audio) | `MeaningAudioCue.gd` | Implemented but Needs Runtime Verification |
| Settlement identity depth | `SettlementMemory` state curve | Implemented but Needs Runtime Verification |
| Wildlife HUD trends | `ColonyHUD` / `Main` | Implemented but Needs Runtime Verification |
| Scar system | `WorldPersistence` + regional tracking | Implemented but Needs Runtime Verification |
| Peace gating | Per-culture peace tick thresholds | Implemented but Needs Runtime Verification |

---

## SECTION 3: INCOMPLETE SYSTEMS — PRIORITY

### 🔴 CRITICAL (v1 Essential - Not Yet Implemented)

| System | File | Gap | Priority |
|--------|------|-----|----------|
| **Skill Trees** | `scripts/pawn/PawnData.gd` | TODO slots at levels 5/10/15/20 - basic/intermediate/advanced/mastery branches not implemented | P0 |
| **Parent Data Lookup** | `scripts/pawn/PawnData.gd` | TODO - proper `PawnManager` lookup for lineage | P0 |
| **Child Creation** | `scripts/pawn/Pawn.gd` | TODO stub - `_spawn_child_pawn` placeholder | P0 |
| **HeelKawnian Matrix AI Deepening** | `scripts/pawn/Pawn.gd`, `autoloads/HeelKawnianManager.gd` | Job-bias bridge and initial social/teaching/grudge intent selection are live; still needs household intent, coordinated group goals, and long-horizon ambitions | P0 |
| **Crafting System** | `autoloads/CraftingSystem.gd` | Placeholder - material consumption not connected to inventory | P1 |
| **Material Consumption** | `autoloads/CraftingSystem.gd` | TODO - consume from pawn inventory/stockpile | P1 |
| **Tool/Item Check** | `scripts/pawn/Pawn.gd` | TODO - check if pawn has required tool equipped | P1 |
| **Household System** | `scripts/pawn/Pawn.gd` | Stub - household_id returns deterministic placeholder | P1 |
| **Leadership Challenge** | `scripts/pawn/Pawn.gd` | TODO comment - authority mechanics not implemented | P1 |
| **Technology Lookup** | `autoloads/TechnologySystem.gd` | TODO stub - settlement neighbor lookup returns random | P2 |
| **Knowledge Propagation** | `autoloads/KnowledgeSystem.gd` | Not connected to pawn teaching system | P2 |
| **FactionRegistry Real** | `autoloads/FactionRegistry.gd` | STUB - "house stub per zone" only, not full CK3-style | P1 |

### 🟡 SPECTATOR FEATURES (v1 - Partial)

| Feature | Status | Gap |
|---------|-------|
| Living World Map | ✅ EXISTS - zoomable |
| Timeline scrubbing | ❌ NOT - can pause/speed but no backward scrub |
| Region Inspection | ✅ EXISTS - Focus Inspector |
| Entity Watchlist | ❌ NOT |
| Historical Playback | ❌ NOT - no time travel |
| Chronicle Auto-Summary | ❌ NOT - no auto-generate |
| Export: World Seed | ❌ NOT |
| Export: Chronicle | ❌ NOT - F10 report but no auto-gen |

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
| Religion Lens | `autoloads/ReligionLens.gd` | Read-only stub only |
| Sacred Memory | `autoloads/SacredMemory.gd` | Stub only |
| Myth Memory | `autoloads/MythMemory.gd` | Stub only |
| Asha/DRUJ Currents | ❌ NOT | No morality currents |
| Echoes of Dead | ❌ NOT | No dreams/ghosts |
| Veil-Aware Sites | ❌ NOT | No thin places |
| Asha Gift | ❌ NOT | No subtle boons |

### 🟢 LONG-VISION STUBS (From SimVision)

| Stub | Status |
|------|--------|
| Player Travel | ❌ NOT - netcode not built |
| Foundation Placement | ❌ NOT - player can't place buildings |
| Clans/Dynasties | ❌ NOT - identity graph stub only |
| Grand Campaigns | ❌ NOT - no war goals/banners |
| Era Stack | ❌ NOT - no prehistory→modern |
| Player-founded places | ❌ NOT |

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
| NPC households | ⚠️ Stub only | Placeholder ID |
| Professions by doing | ⚠️ Basic | No skill tree |
| WorldMemory expanded | ✅ DONE | — |
| WorldMeaning prototype | ✅ DONE | — |
| Historical ruins | ✅ DONE | — |
| Civilization stage lens | ✅ INITIAL LIVE | Derived era score, not full era simulation |
| Per-pawn HeelKawnian development AI | ✅ INITIAL LIVE | Derived profile/readout exists and now biases job selection; needs in-editor runtime verification and deeper social/ambition steering |
| Birth and death | ⚠️ Basic | No lineage depth |
| Basic kinship | ⚠️ Stub | No full tree |
| Food and storage | ✅ DONE | — |
| Fire and shelter | ✅ Partial (verify runtime) | `BuildingRegistry` fire pit/hearth warmth + cooking; `ColonySimServices` warmth/light pressure; formal settlement gate requires hearth or warmth |
| Trade and travel | ⚠️ Stub | No travel system |
| Conflict and raids | ⚠️ Basic | — |
| Local reputation | ⚠️ Partial | — |
| Region history panel | ⚠️ Focus inspector | — |
| **Chronicle export** | ❌ NOT | No auto-summary |
| **World seed export** | ❌ NOT | — |

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
2. **HeelKawnian Matrix AI Deepening** - expand the initial job-bias bridge into learning targets, teaching targets, preservation choices, household goals, cooperation, and recovery behavior.
3. **Skill Tree System** - `PawnData.gd` skill branching (levels 5/10/15/20).
4. **Lineage/Kinship System** - full parents, children, inheritance, and real child creation.

### P1 - High Priority
5. **Crafting Integration** - connect `_consume_pawn_material` to inventory/stockpile.
6. **Tool/Item System** - ground items and tool requirement checks.
7. **Knowledge Preservation Loop** - stones, books, teaching, literacy, and rediscovery.
8. **Chronicle Auto-Summary** - generate readable summaries from WorldMemory.
9. **Exports** - world seed + chronicle export functions.

### P2 - Medium Priority
10. **Civilization Stage Deepening** - initial derived lens is live; add per-settlement tech diffusion, literacy, lifespan, and institution signals.
11. **Knowledge Propagation** - connect `KnowledgeSystem` to teaching.
12. **Governance Forms** - implement actual leadership selection.
13. **Full Faction System** - extend stub to real CK3-style houses.

### P3 - Future Vision
14. **Taboo System** - law and custom accumulation.
15. **Diplomacy** - messenger/treaty foundation.
16. **Asha/DRUJ Currents**
17. **Echoes of Dead**
18. **Grand Campaigns**

---

## SECTION 7: FILES WITH TODOS/STUBS

### TODO patterns found (37 instances)
- `scripts/pawn/PawnData.gd` - 4 skill tree placeholders
- `scripts/pawn/Pawn.gd` - 7 placeholders (tools, children, leadership, items)
- `autoloads/CraftingSystem.gd` - 2 material placeholders
- `autoloads/KnowledgeSystem.gd` - 1 connection placeholder
- `autoloads/TechnologySystem.gd` - 1 neighbor lookup placeholder
- `autoloads/AIAgentManager.gd` - 1 observation placeholder
- `scripts/pawn/PawnData.gd` - parent lookup placeholder
- `autoloads/CivilizationStage.gd` - initial derived era lens; deepen with future institution metrics
- `autoloads/HeelKawnianManager.gd` - derived individual profile lens plus deterministic Matrix job-bias generation

### Stub classes (5)
- `SimVision.gd` - Roadmap design surface
- `FactionRegistry.gd` - House stub
- `ReligionLens.gd` - Read-only
- `SacredMemory.gd` - Stub
- `MythMemory.gd` - Stub

---

## CONCLUSION

The kernel has a strong deterministic foundation and currently passes headless smoke checks. Full editor/runtime validation remains the gate for "Verified Runtime Complete" labels.

**What's built:**
- Core world simulation (tick, memory, persistence)
- Settlement lifecycle (birth, death, revival)
- Cultural identity divergence
- Pawn behavior and jobs
- Trade and animals

**What's missing for v1:**
- Skill trees and lineage depth for NPCs
- Player incarnation capability
- Export functions (world seed, chronicle)
- Governance and law systems
- Religion/metaphysics hooks
- Long-vision (travel, clans, eras)

**Recommended next step:** Run the runtime truth pass, then deepen the HeelKawnian Matrix AI from job bias into social target selection, teaching targets, household goals, and settlement ambitions before expanding the skill tree and kinship graph.
