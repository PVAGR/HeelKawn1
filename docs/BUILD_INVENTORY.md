# HEELKAWN UNIVERSE — BUILD STATUS INVENTORY

> Comprehensive analysis of what is built vs. what the master plan requires

**Last Updated:** 2026-04-30  
**Analysis Scope:** All autoloads, scripts, docs, and feature specs

---

## SECTION 1: COMPLETED KERNEL SYSTEMS ✅

| System | File | Status | Notes |
|--------|------|--------|-------|
| World Memory | `autoloads/WorldMemory.gd` | ✅ DONE | Append-only factual history |
| World Meaning | `autoloads/WorldMeaning.gd` | ✅ DONE | Derived regional interpretation |
| World Persistence | `autoloads/WorldPersistence.gd` | ✅ DONE | Scars, ruins, abandonment |
| Land Recovery | `autoloads/SettlementPersistenceManager.gd` | ✅ DONE | Visual healing |
| Cultural Memory | `autoloads/CulturalMemory.gd` | ✅ DONE | Inherited reputation |
| Settlement Memory | `autoloads/SettlementMemory.gd` | ✅ DONE | Clustered regions → places |
| Settlement Planner | `autoloads/SettlementPlanner.gd` | ✅ DONE | Autonomous building |
| Settlement Architect | `autoloads/SettlementArchitect.gd` | ✅ DONE | Building placement logic |
| Settlement Registry | `autoloads/SettlementRegistry.gd` | ✅ DONE | Settlement tracking |
| Settlement Rebirth | `autoloads/SettlementRebirth.gd` | ✅ DONE | Revival with gates |
| Animal Spawner/Population | `autoloads/AnimalSpawner.gd`, `autoloads/AnimalPopulation.gd` | ✅ DONE | Seeded ecology |
| Pawn Behavior | `scripts/pawn/Pawn.gd`, `scripts/pawn/PawnData.gd` | ✅ DONE | Jobs, pathfinding, needs |
| Job Manager | `autoloads/JobManager.gd` | ✅ DONE | Job queue system |
| Stockpile System | `autoloads/StockpileManager.gd` | ✅ DONE | Resource storage |
| Trade Planner | `autoloads/TradePlanner.gd` | ✅ DONE | Trade routes |
| World Clock | `autoloads/WorldClock.gd` | ✅ DONE | Tick/time management |
| World RNG | `autoloads/WorldRNG.gd` | ✅ DONE | Seeded randomness |
| Faction Registry | `autoloads/FactionRegistry.gd` | ⚠️ STUB | House stub per zone only |
| Religion Lens | `autoloads/ReligionLens.gd` | ⚠️ STUB | Read-only overlay |
| Meaning Ambiance Controller | `autoloads/MeaningAmbianceController.gd` | ✅ DONE | Audio/visual cues |

---

## SECTION 2: COMPLETED PHASE 4 FEATURES ✅

| Feature | Implementation | Status |
|---------|----------------|--------|
| Cultural divergence (OPEN/CAUTIOUS/DEFENSIVE) | `SettlementPlanner` constants | ✅ DONE |
| Architecture signature constants | GLOSSARY.md table | ✅ DONE |
| Revival/rebirth system | `SettlementRebirth.gd` + gates | ✅ DONE |
| Player-readable meaning (audio) | `MeaningAudioCue.gd` | ✅ DONE |
| Settlement identity depth | `SettlementMemory` state curve | ✅ DONE |
| Wildlife HUD trends | `ColonyHUD` / `Main` | ✅ DONE |
| Scar system | `WorldPersistence` + regional tracking | ✅ DONE |
| Peace gating | Per-culture peace tick thresholds | ✅ DONE |

---

## SECTION 3: INCOMPLETE SYSTEMS — PRIORITY分类

### 🔴 CRITICAL (v1 Essential - Not Yet Implemented)

| System | File | Gap | Priority |
|--------|------|-----|----------|
| **Skill Trees** | `scripts/pawn/PawnData.gd` | TODO slots at levels 5/10/15/20 - basic/intermediate/advanced/mastery branches not implemented | P0 |
| **Parent Data Lookup** | `scripts/pawn/PawnData.gd` | TODO - proper `PawnManager` lookup for lineage | P0 |
| **Child Creation** | `scripts/pawn/Pawn.gd` | TODO stub - `_spawn_child_pawn` placeholder | P0 |
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
| Birth and death | ⚠️ Basic | No lineage depth |
| Basic kinship | ⚠️ Stub | No full tree |
| Food and storage | ✅ DONE | — |
| Fire and shelter | ⚠️ Stub | No heating system |
| Trade and travel | ⚠️ Stub | No travel system |
| Conflict and raids | ⚠️ Basic | — |
| Local reputation | ⚠️ Partial | — |
| Region history panel | ⚠️ Focus inspector | — |
| **Chronicle export** | ��� NOT | No auto-summary |
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
1. **Skill Tree System** - `PawnData.gd` skill branching (levels 5/10/15/20)
2. **Lineage/Kinship System** - Full `KinshipSystem` - parents, children, inheritance
3. **Embodied Player** - Create player pawn on incarnation entry

### P1 - High Priority
4. **Crafting Integration** - Connect `_consume_pawn_material` to inventory/stockpile
5. **Tool/Item System** - Ground items, tool requirements check
6. **Chronicle Auto-Summary** - Generate readable summaries from WorldMemory
7. **Exports** - World seed + chronicle export functions
8. **Governance Forms** - Implement actual leadership selection

### P2 - Medium Priority
9. **Knowledge Propagation** - Connect `KnowledgeSystem` to teaching
10. **Full Faction System** - Extend stub to real CK3-style houses
11. **Taboo System** - Law and custom accumulation
12. **Diplomacy** - Messenger/treaty foundation

### P3 - Future Vision
13. **Asha/DRUJ Currents**
14. **Echoes of Dead**
15. **Era Stack**
16. **Grand Campaigns**

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

### Stub classes (5)
- `SimVision.gd` - Roadmap design surface
- `FactionRegistry.gd` - House stub
- `ReligionLens.gd` - Read-only
- `SacredMemory.gd` - Stub
- `MythMemory.gd` - Stub

---

## CONCLUSION

The **kernel is solid and deterministic**. The simulation runs well.

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

**Recommended next step:** Build the skill tree system and kinship graph to give NPCs real heritage and progression depth.
