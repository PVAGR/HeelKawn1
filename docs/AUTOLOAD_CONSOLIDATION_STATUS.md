# Autoload Consolidation Status

**Date:** May 10, 2026  
**Status:** Partially Complete  
**Autoload Count:** 128 → 40 (69% reduction)

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
- ✅ Reduced autoloads from 128 to 40
- ✅ Kept 20 essential core autoloads
- ✅ Kept 5 core features (KnowledgeSystem, TechnologySystem, etc.)
- ✅ Kept 4 gameplay systems (FarmingSystem, WildlifePopulation, Weather, ObjectPool)
- ✅ Added 11 consolidated managers
- ✅ Removed 88 autoloads (consolidated or non-essential)

### 3. Updated Main.gd References (Partial)
- ✅ SettlementPlanner → SettlementManager (7 occurrences)
- ✅ SettlementRebirth → SettlementManager (4 occurrences)
- ✅ SettlementArchitect → SettlementManager (1 occurrence)
- ✅ KinshipSystem → SocialManager (3 occurrences)
- ✅ GrudgeManager → SocialManager (2 occurrences)
- ✅ GossipManager → SocialManager (2 occurrences)
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

1. **Complete Main.gd updates** - Update all remaining autoload references in Main.gd to use consolidated managers
2. **Update script files** - Update references in the 20+ script files that reference old autoloads
3. **Test game launch** - Verify the game launches without errors after all updates
4. **Performance testing** - Measure startup time and memory usage improvements

---

## Expected Results

**Before:**
- 128 autoloads
- Slow startup
- High memory usage
- Complex dependencies

**After (when complete):**
- 40 autoloads (69% reduction)
- Expected 50-70% faster startup
- Expected 30-40% lower memory usage
- Clearer architecture

---

## Notes

- The consolidated managers use lazy loading (subsystems load on-demand)
- Backward compatibility methods are provided in each manager
- Some autoloads were removed entirely (non-essential for v1)
- Export utilities and debug tools can be loaded on-demand via code instead of autoloads
