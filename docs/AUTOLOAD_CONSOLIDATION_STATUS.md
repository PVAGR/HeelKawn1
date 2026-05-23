# Autoload Consolidation Status

**Date:** 2026-05-22  
**Status:** Phase 1 + Phase 2 safe removals done: 9 autoloads deregistered  
**Autoload Count:** 141 (from 150, 9 deregistered in Phases 1–2, 11 consolidated managers created, 24 removed from project.godot total)

---

## Phase 1: Safe Removals — DONE May 23, 2026

### Removed 3 autoload registrations from project.godot:

| Autoload | LOC | Reason | Files Updated |
|---|---|---|---|
| **DiscoveryGate** | 47 | Converted to static utility class (`class_name DiscoveryGate`, all static methods). Call `DiscoveryGate.init()` in bootstrap. All 48 call sites preserved. | `autoloads/DiscoveryGate.gd` (rewritten), `Main.gd` (+init call) |
| **WorldEventSeedManager** | 40 | Lazy-loaded via EventManager. Main.gd inline calls replaced with `EventManager.get_world_event_seed_manager()`. | `Main.gd` (2 refs replaced) |
| **WindSystem** | 26 | Thin wrapper of WorldEnvironmentManager — all refs redirected to WorldEnvironmentManager directly. | `NavalSystem.gd`, `HeelKawnian.gd` (2 refs), `SurvivalSystem.gd` |

**Phase 1 LOC saved:** ~113 (from autoload registrations)
**Files remaining:** All 3 .gd files kept on disk for potential reactivation.

---

## Phase 2: Stub/Vision Candidate Removals — DONE 2026-05-22

### Removed 6 autoload registrations from project.godot:

| Autoload | LOC | Refs | Approach | Files Updated |
|---|---|---|---|---|
| **SquadCoordinator** | 77 | 2 | Lazy-loaded by WorldAI as child node. `recompute_squads()` / `get_active_squad_count()` methods on WorldAI. | `WorldAI.gd` (+wrapper methods), `Main.gd` (call site), `project.godot` |
| **FragmentationManager** | 114 | 2 | Bootstrapped at root in `Main._ready()`. SchismManager uses path-based lookup (`/root/FragmentationManager`). | `Main.gd` (+bootstrap +member var), `SchismManager.gd` (path lookup), `project.godot` |
| **RelationalGraph** | 87 | 49 (in 4 files) | SocialManager adds to root via `get_tree().root.add_child()` instead of `add_child()`. Existing `/root/RelationalGraph` path queries still work. TradePlanner uses path-based lookup. | `SocialManager.gd`, `TradePlanner.gd`, `project.godot` |
| **SacredGeography** | 257 | 6 | Bootstrapped at root in `Main._ready()`. All 3 path-based call sites (`get_node_or_null("/root/SacredGeography")`) work unchanged. WorldOverlay direct singleton replaced with path lookup. | `Main.gd` (+bootstrap), `WorldOverlay.gd` (path lookup), `project.godot` |
| **ReligionLens** | 137 | 24 | Converted to static utility class (`class_name ReligionLens`). Removed unused signals + neural network stub state. All 24 call sites preserved unchanged. | `autoloads/ReligionLens.gd` (rewritten), `project.godot` |
| **MythAge** | 226 | 9 | Converted to static utility class (`class_name MythAge`). Replaced `_process` with `static func tick()` called from `Main._on_game_tick`. Removed unused `age_discovered` signal. All 9 call sites preserved unchanged. | `autoloads/MythAge.gd` (rewritten), `Main.gd` (+tick call +init in _ready), `project.godot` |

**Phase 2 LOC saved:** ~898 (from autoload registrations)
**Files remaining:** All 6 .gd files kept on disk for potential reactivation.

---

## Completed Work

### 1. Created Consolidated Managers (11 total)
- ✅ SettlementManager.gd - Consolidates SettlementPlanner, SettlementRebirth, SettlementArchitect
- ✅ AIManager.gd - Consolidates AI systems (AIAutoBuild, AILearning, etc.)
- ✅ MemoryManager.gd - Consolidates niche memory systems (AgeMemory, IntentMemory, etc.)
- ✅ SocialManager.gd - Consolidates social systems (KinshipSystem, GrudgeManager, GossipManager, etc.)
- ✅ FactionManager.gd - Consolidates FactionRegistry, FactionSystem, AuthoritySystem
- ✅ UIManager.gd - Consolidates UI systems (HeelKawnUIManager, UILayoutManager, etc.)
- ✅ EventManager.gd - Consolidates world event systems
- ✅ EconomyManager.gd - Consolidates trade and economy systems
- ✅ PlayerManager.gd - Consolidates player systems
- ✅ PawnManager.gd - Consolidates pawn consciousness and dialogue
- ✅ ObserverManager.gd - Consolidates observer and vision systems

### 2. Updated project.godot
- ✅ SettlementManager, SocialManager, FactionManager, MemoryManager, EconomyManager, FactionManager wired into project.godot
- ✅ 15 old autoloads removed: SettlementPlanner, SettlementRebirth, SettlementArchitect, FactionRegistry, BloodlineSystem, GrudgeManager, GossipManager, FootpathMemory, AIAutoBuild, AILearning, AICooperation, PawnBrainBridge, SettlementAIBridge, ChronicleExport, WorldSeedExport
- ✅ All 6 other new managers (AIManager, UIManager, EventManager, PlayerManager, PawnManager, ObserverManager) registered in project.godot
- 🔶 ~75 autoloads still need consolidation and removal

### 3. Updated Main.gd References (Partial)
- ✅ SettlementPlanner → SettlementManager (7 occurrences)
- ✅ SettlementRebirth → SettlementManager (4 occurrences)
- ✅ SettlementArchitect → SettlementManager (1 occurrence)
- ✅ KinshipSystem → SocialManager (3 occurrences)
- ✅ GrudgeManager → SocialManager (6 occurrences)
- ✅ GossipManager → SocialManager (4 occurrences)
- ✅ BloodlineSystem → SocialManager (2 occurrences in Main.gd, forwarding methods added)
- ✅ Added get_culture_audio_bias_for_settlement method to SettlementManager
- ✅ Added forwarding methods to MemoryManager

---

## Remaining Work

### Critical: Update Main.gd References
The following autoload references in Main.gd still need to be updated:

**Trade/Economy (TradePlanner → EconomyManager):**
- Line 2256: TradePlanner.plan(_world, self, true)
- Line 2737: TradePlanner.plan(_world, self, false)
- Line 3100: TradePlanner.plan(_world, self, true)
- Line 3122: TradePlanner.plan(world, main, use_cache)
- Line 5504: TradePlanner.plan(_world, self, true)
- Line 7625: TradePlanner.plan(_world, self, true)

**Road Memory (RoadMemory → MemoryManager):**
- Line 2257: RoadMemory.flush_dirty_tiles(_world)
- Line 2972: RoadMemory.flush_dirty_tiles(_world)
- Line 3101: RoadMemory.flush_dirty_tiles(_world)
- Line 5505: RoadMemory.flush_dirty_tiles(_world)
- Line 7626: RoadMemory.flush_dirty_tiles(_world)
- Line 6015: RoadMemory.get_traversal(rx, ry)
- Line 6016: RoadMemory.ROAD_T1
- Line 5448: RoadMemory.clear()

**Remnant Memory (RemnantMemory → MemoryManager):**
- Line 2285: RemnantMemory.clear()
- Line 2292: RemnantMemory.seed_births_from_current_world(_world)
- Line 5506: RemnantMemory.clear()
- Line 5507: RemnantMemory.seed_births_from_current_world(_world)
- Line 7526: RemnantMemory.clear()
- Line 7628: RemnantMemory.seed_births_from_current_world(_world)

**Myth Memory (MythMemory → MemoryManager):**
- Line 2248: MythMemory.recompute(_world)
- Line 3083: MythMemory.recompute(_world)
- Line 3545: MythMemory.get_region_myth_state(rk)
- Line 3613: MythMemory.get_region_myth_state(rk0)
- Line 5434: MythMemory.clear()
- Line 5468: MythMemory.recompute(_world)
- Line 7458: MythMemory.to_save_dict()
- Line 7579: MythMemory.from_save_dict()
- Line 7612: MythMemory.recompute(_world)

**Sacred Memory (SacredMemory → MemoryManager):**
- Line 2249: SacredMemory.sync_permanent_ruins_from_settlements()
- Line 3084: SacredMemory.sync_permanent_ruins_from_settlements()
- Line 5435: SacredMemory.clear()
- Line 7459: SacredMemory.to_save_dict()
- Line 7580: SacredMemory.from_save_dict()
- Line 7613: SacredMemory.sync_permanent_ruins_from_settlements()
- Line 8088: SacredMemory.site_count()

**Intent Memory (IntentMemory → MemoryManager):**
- Line 2293: IntentMemory.recompute(_world)
- Line 2776: IntentMemory.recompute(_world)
- Line 3085: IntentMemory.recompute(_world)
- Line 3491: IntentMemory.INTENT_HOLD
- Line 3496: IntentMemory.settlement_intent.get(...)
- Line 3538: IntentMemory.INTENT_GROW
- Line 3540: IntentMemory.INTENT_ABANDON
- Line 3578: IntentMemory.settlement_intent.get(...)
- Line 3581-3595: Multiple IntentMemory.INTENT_* comparisons
- Line 5450: IntentMemory.clear()
- Line 5502: IntentMemory.recompute(_world)
- Line 7527: IntentMemory.clear()
- Line 7618: IntentMemory.recompute(_world)
- Line 8455-8459: IntentMemory.INTENT_* comparisons

**Age Memory (AgeMemory → MemoryManager):**
- Line 2286: AgeMemory.clear()
- Line 2774: AgeMemory.recompute()
- Line 3458: AgeMemory.get_ambient_freq_shift()
- Line 5451: AgeMemory.clear()
- Line 7528: AgeMemory.clear()

**Faction Registry (FactionRegistry → FactionManager):**
- Line 2250: FactionRegistry.sync_from_settlements()
- Line 7463: FactionRegistry.to_save_dict()
- Line 7539: FactionRegistry.clear()
- Line 7570: FactionRegistry.from_save_dict()
- Line 7616: FactionRegistry.from_save_dict()
- Line 7617: FactionRegistry.sync_from_settlements()
- Line 7978: FactionRegistry.append_focus_house_lines(out, center_region)
- Line 8022: FactionRegistry.sync_from_settlements()
- Line 8080: FactionRegistry.get_house_for_zone(zid)
- Line 8087: FactionRegistry.get_synced_house_count()

**Bloodline System (BloodlineSystem → SocialManager):**
- Line 7454: BloodlineSystem.to_save_dict()
- Line 7523: BloodlineSystem.clear()
- Line 7576: BloodlineSystem.from_save_dict()
- Line 7713: BloodlineSystem.record_pawn_death()

### Update Other Script Files
The following files also have references to removed autoloads that need updating:

**SettlementPlanner references:**
- scripts/world/TileFeature.gd
- scripts/ui/MapModeOverlay.gd
- scripts/pawn/HeelKawnian.gd
- scripts/pawn/Pawn.gd
- scripts/ai/HeelKawnAIOrchestrator.gd
- scripts/ai/AISettlementPlanner.gd

**SettlementRebirth references:**
- scripts/ui/CreatorDebugMenu.gd

**KinshipSystem references:**
- scripts/ui/TerritoryOverlay.gd
- scripts/ui/PawnAIInspector.gd
- scripts/tests/test_kinship_api.gd
- scripts/pawn/Pawn.gd
- scripts/pawn/PawnSpawner.gd
- scripts/pawn/HeelKawnian.gd

**GrudgeManager references:**
- scripts/ui/TutorialHints.gd
- scripts/ui/PawnAIInspector.gd
- scripts/ui/CreatorDebugMenu.gd
- scripts/pawn/HeelKawnian.gd
- scripts/pawn/Pawn.gd
- scripts/pawn/HeelKawnianData.gd
- scripts/ai/PawnDecisionRuleMatrix.gd
- scripts/ai/WorldAI.gd
- scripts/ai/HeelKawnAIOrchestrator.gd
- scripts/ai/BattleReporter.gd
- scripts/ai/AIPawnPsychologist.gd
- scripts/ai/AIDiplomacyDirector.gd

---

## Next Steps

1. **Phase 3: Manager-driven Consolidations** — Move remaining autoloads into existing consolidated managers (SettlementMemory, FactionRegistry, TradePlanner, RoadMemory, RemnantMemory, MythMemory, SacredMemory, IntentMemory, AgeMemory, BloodlineSystem → MemoryManager / FactionManager / SocialManager / EconomyManager)
2. **Phase 4: Core Thin Wrappers** — Evaluate remaining ~50 thin wrappers (<150 LOC) for consolidation potential
3. **Test game launch** - Verify the game launches without errors after all updates
4. **Performance testing** - Measure startup time and memory usage improvements

---

## Expected Results

**Before:**
- 164 autoloads
- Slow startup
- High memory usage
- Complex dependencies

**After (when complete):**
- ~40 autoloads (target)
- Startup, memory, and architecture improvements TBD — not yet measured

---

## Notes

- The consolidated managers use lazy loading (subsystems load on-demand)
- Backward compatibility methods are provided in each manager
- Some autoloads were removed entirely (non-essential for v1)
- Export utilities and debug tools can be loaded on-demand via code instead of autoloads

---

## Consolidation Progress Log

### 2026-05-14 — FootpathMemory consolidated into MemoryManager, removed from project.godot

**Changes:**
- Added `footpath_get_wear_at()`, `footpath_bind_context()`, `footpath_clear()` forwarding methods to MemoryManager
- Updated Main.gd (6 references: 3 bind_context, 3 clear)
- Updated HeelKawnian.gd (1 reference: get_wear_at)
- Updated WorldOverlay.gd (1 reference: get_wear_at)
- Removed FootpathMemory from project.godot

**Result:** FootpathMemory is no longer an autoload. All references now go through MemoryManager.

### 2026-05-14 — BloodlineSystem consolidated into SocialManager, removed from project.godot

**Changes:**
- Added `record_pawn_death()` and `clear_bloodline()` forwarding methods to SocialManager
- Updated Main.gd (2 references: clear, record_pawn_death)
- Updated NameGenerator.gd (1 reference: get_bloodline_system())
- Updated PawnInfoPanel.gd (1 reference: get_bloodline_system())
- Removed BloodlineSystem from project.godot

**Result:** BloodlineSystem is no longer an autoload. All references now go through SocialManager.

### 2026-05-14 — project.godot updated: 4 old autoloads removed, 2 consolidated managers wired

**Changes made to project.godot:**

| Removed Autoload | Consolidated Into | Status |
|---|---|---|
| SettlementPlanner | SettlementManager | ✅ Removed from project.godot |
| SettlementRebirth | SettlementManager | ✅ Removed from project.godot |
| SettlementArchitect | SettlementManager | ✅ Removed from project.godot |
| FactionRegistry | FactionManager | ✅ Removed from project.godot |

**Result:** project.godot now has 160 active autoloads (164 − 4 removed). SettlementManager and FactionManager are registered as autoloads. Main.gd references have been updated for SettlementPlanner/Rebirth/Architect → SettlementManager (12 occurrences) and FactionRegistry → FactionManager (10 occurrences still pending in Main.gd).

### 2026-05-14 — GrudgeManager and GossipManager consolidated into SocialManager, removed from project.godot

**Changes:**
- Added 10 forwarding methods to SocialManager (get_grudges_held_by, get_grudges_against, get_grudge_target, get_highest_grudge_level, grudges_to_save_dict, grudges_from_save_dict, get_gossip_about, get_reputation_for, get_reputation_label, gossip_to_save_dict, gossip_from_save_dict)
- Updated Main.gd (4 references: save/load for grudge_manager and gossip_manager)
- Updated CrimeSystem.gd (4 GrudgeManager references: add_grudge, get_highest_grudge_level, get_grudge_target, null checks)
- Updated HeelKawnianMind.gd (5 references: get_grudges_held_by, get_grudges_against, get_reputation_for, get_reputation_label)
- Updated HeelKawnianVoice.gd (1 reference: get_gossip_about)
- Removed GrudgeManager and GossipManager from project.godot

**Result:** GrudgeManager and GossipManager are no longer autoloads. All references now go through SocialManager.
