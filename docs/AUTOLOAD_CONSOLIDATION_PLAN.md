# Autoload Consolidation Plan

**Created:** May 10, 2026  
**Last Updated:** May 14, 2026  
**Current Autoload Count:** 164 (CRITICAL - way too many)  
**Target:** 15-20 essential autoloads  
**Impact:** Reduce startup time, memory usage, complexity, and potential circular dependencies

---

## Current Autoload Inventory (164 total)

### **Core Memory & Persistence (8)** - KEEP ESSENTIAL
1. WorldMemory - Deterministic append-only fact log (ESSENTIAL)
2. WorldMeaning - Derived meaning from facts (ESSENTIAL)
3. WorldPersistence - Save/load state (ESSENTIAL)
4. WorldRNG - Seeded deterministic RNG (ESSENTIAL - determinism requirement)
5. SettlementMemory - Settlement state (ESSENTIAL)
6. SettlementRegistry - Settlement tracking (ESSENTIAL)
7. CulturalMemory - Cultural knowledge (KEEP - core feature)
8. WorldClock - Time tracking (ESSENTIAL)

### **Core Gameplay Systems (6)** - KEEP ESSENTIAL
9. GameManager - Game loop, speed control (ESSENTIAL)
10. JobManager - Job queue (ESSENTIAL)
11. StockpileManager - Resource management (ESSENTIAL)
12. ZoneRegistry - Zone tracking (ESSENTIAL)
13. BuildingRegistry - Building tracking (ESSENTIAL)
14. ColonySimServices - Colony-wide metrics (ESSENTIAL)

### **Tick & Time (1)** - KEEP ESSENTIAL
15. TickManager - Tick coordination (ESSENTIAL)

### **Settlement Systems (7)** - CONSOLIDATE TO 2-3
16. SettlementPlanner - Autonomous build intents
17. SettlementRebirth - Settlement revival logic
18. SettlementArchitect - Visual decay for abandoned
19. SettlementIdentity - Settlement identity (scripts/kernel)
20. SettlementPersistence - Settlement persistence (scripts/kernel)
21. SettlementPersistenceManager - Duplicate of above?
22. SettlementAIBridge - AI bridge

**Action:** Consolidate SettlementPlanner, SettlementRebirth, SettlementArchitect into single SettlementManager. Remove duplicates.

### **AI Systems (15)** - CONSOLIDATE TO 3-4
23. WorldAI - Neural network matrix (KEEP - core feature)
24. AIAgentManager - AI agent management
25. AIAutoBuild - AI auto-build (scripts/ai)
26. AILearning - AI learning (scripts/ai)
27. AICooperation - AI cooperation (scripts/ai)
28. AICombatProgression - Combat progression (scripts/ai)
29. CombatNarrative - Combat narrative (scripts/ai)
30. SquadSystem - Squad system (scripts/ai)
31. BattleReporter - Battle reporter (scripts/ai)
32. GuildSystem - Guild system (scripts/ai)
33. GeneticsSystem - Genetics system (scripts/ai)
34. NameGenerator - Name generator (scripts/ai)
35. GovernorSystem - Governor system (scripts/ai)
36. HeelKawnAIOrchestrator - AI orchestrator (scripts/ai)
37. HeelKawnianMind - HeelKawnian mind

**Action:** Keep WorldAI (core), consolidate others into AIManager. Move non-essential to on-demand.

### **Memory Systems (9)** - CONSOLIDATE TO 2-3
38. AgeMemory - Age-related memory
39. IntentMemory - Intent memory
40. RemnantMemory - Remnant memory
41. MythMemory - Myth memory
42. RoadMemory - Road memory
43. SacredMemory - Sacred memory
44. FootpathMemory - Footpath memory
45. ChronicleLog - Chronicle log

**Action:** Consolidate into MemoryManager. Most are niche features that don't need global access.

### **Social Systems (6)** - CONSOLIDATE TO 1-2
46. KinshipSystem - Kinship tracking
47. GrudgeManager - Grudge tracking
48. GossipManager - Gossip tracking
49. RelationalGraph - Social graph
50. BloodlineSystem - Bloodline system (scripts/ai)
51. LegacySystem - Legacy tracking

**Action:** Consolidate into SocialManager. Keep KinshipSystem (core feature).

### **Knowledge & Technology (3)** - KEEP
52. KnowledgeSystem - Knowledge management (KEEP - core feature)
53. TechnologySystem - Technology tracking (KEEP - core feature)
54. CraftingSystem - Crafting (KEEP - core feature)

### **Faction & Politics (3)** - CONSOLIDATE TO 1
55. FactionRegistry - Faction registry
56. FactionSystem - Faction system (duplicate?)
57. AuthoritySystem - Authority system

**Action:** Consolidate into FactionManager.

### **Religion & Myth (3)** - CONSOLIDATE TO 1
58. ReligionLens - Religion lens
59. MythMemory - Myth memory (already in memory systems)
60. SacredMemory - Sacred memory (already in memory systems)
61. SacredGeography - Sacred geography
62. MythAge - Myth age

**Action:** Consolidate into ReligionManager. **NOTE: ReligionManager.gd does not exist yet — planned but not implemented.** Mark as non-essential for v1.

### **Civilization & Progression (4)** - KEEP
63. ProgressionSystem - Progression tracking (KEEP - core feature)
64. CivilizationStage - Civilization stage (KEEP - core feature)
65. GeneticEvolution - Genetic evolution
66. HistoricalSimulation - Historical simulation

**Action:** Keep ProgressionSystem and CivilizationStage. Move others to on-demand.

### **Combat & Military (5)** - CONSOLIDATE TO 1
67. SquadCoordinator - Squad coordination
68. BodyRiskManager - Body risk management
69. AICombatProgression - Combat progression (scripts/ai)
70. CombatNarrative - Combat narrative (scripts/ai)
71. SquadSystem - Squad system (scripts/ai)

**Action:** Consolidate into CombatManager. **NOTE: CombatManager.gd does not exist yet — planned but not implemented.** Mark as non-essential for v1.

### **Export & Data (4)** - CONVERT TO ON-DEMAND
72. ChronicleExport - Chronicle export
73. WorldSeedExport - World seed export
74. CharacterExport - Character export
75. WorldActionLedger - Action ledger

**Action:** These are export utilities - load only when needed.

### **Player Systems (4)** - CONSOLIDATE TO 1-2
76. PlayerIntentQueue - Player intent queue
77. PlayerGathering - Player gathering
78. PlayerBuilding - Player building
79. IncarnationManager - Incarnation management

**Action:** Consolidate into PlayerManager.

### **UI Systems (6)** - CONSOLIDATE TO 1-2
80. HeelKawnUIManager - UI manager
81. UILayoutManager - UI layout manager
82. PawnMoodUI - Pawn mood UI (scripts/ui)
83. EventNotificationOverlay - Event overlay (scripts/ui)
84. ModernTheme - Theme (scripts/ui)
85. PawnChatterBubbles - Chatter bubbles

**Action:** Consolidate into UIManager. UI systems should be scene-local, not autoloads.

### **Spatial & Environment (5)** - CONSOLIDATE TO 2
86. SpatialManager - Spatial management
87. SpatialGrid - Spatial grid
88. SnowAccumulation - Snow accumulation
89. Weather - Weather (scenes/world)
90. SacredGeography - Sacred geography

**Action:** Keep SpatialManager and SpatialGrid. Move others to on-demand.

### **World Events (3)** - CONSOLIDATE TO 1
91. WorldEvents - World events
92. WorldEventSystem - World event system (duplicate?)
93. WorldEventSeedManager - Event seed manager

**Action:** Consolidate into EventManager.

### **Economy & Resources (4)** - CONSOLIDATE TO 1
94. TradePlanner - Trade planner
95. TradeMemory - Trade memory
96. FoodChainManager - Food chain manager
97. ToolManager - Tool manager

**Action:** Consolidate into EconomyManager. Mark Trade as non-essential for v1.

### **Disaster & Collapse (3)** - CONSOLIDATE TO 1
98. DisasterSystem - Disaster system
99. CollapseSystem - Collapse system
100. CataclysmSystem - Cataclysm system (scripts/world)

**Action:** Consolidate into DisasterManager. **NOTE: DisasterManager.gd does not exist yet — planned but not implemented.** Mark as non-essential for v1.

### **Farming & Wildlife (2)** - KEEP
101. FarmingSystem - Farming system
102. WildlifePopulation - Wildlife population

**Action:** Keep both - core gameplay systems.

### **Debug & Diagnostic (5)** - CONVERT TO ON-DEMAND
103. CrashTrap - Crash detection
104. TickMonitor - Tick monitoring (tools/diagnose)
105. PlaytestRecorder - Playtest recording
106. PlaytestInputRecorder - Input recording
107. PawnCommunicationLog - Communication log

**Action:** These are debug tools - load only when debugging.

### **Observer & Vision (4)** - CONSOLIDATE TO 1
108. ObserverLens - Observer lens (scripts/kernel)
109. SimVision - Sim vision
110. ObservationAPI - Observation API
111. DiscoveryGate - Discovery gate
112. FogOfDiscovery - Fog of discovery

**Action:** Consolidate into ObserverManager. Mark as non-essential for v1.

### **Cultural & Style (2)** - KEEP
113. CulturalMemory - Already listed above
114. CulturalStyleManager - Cultural style manager

**Action:** Keep CulturalStyleManager.

### **Fragmentation & Schism (2)** - CONSOLIDATE TO 1
115. FragmentationManager - Fragmentation manager
116. SchismManager - Schism manager

**Action:** Consolidate into PoliticsManager. **NOTE: PoliticsManager.gd does not exist yet — planned but not implemented.** Mark as non-essential for v1.

### **Pawn Systems (3)** - CONSOLIDATE TO 1
117. PawnConsciousness - Pawn consciousness
118. PawnDialogue - Pawn dialogue
119. PawnBrainBridge - Pawn brain bridge
120. HeelKawnianMind - Already listed above
121. HeelKawnianIdentity - HeelKawnian identity
122. HeelKawnianManager - HeelKawnian manager
123. HeelKawnianVoice - HeelKawnian voice

**Action:** Consolidate into PawnManager.

### **Time & Recording (3)** - CONSOLIDATE TO 1
124. TimeLapseRecorder - Time lapse recording
125. MemorialSystem - Memorial system
126. WorldActionLedger - Already listed above

**Action:** Consolidate into RecordingManager. **NOTE: RecordingManager.gd does not exist yet — planned but not implemented.** Mark as non-essential for v1.

### **Victory & Onboarding (2)** - CONVERT TO ON-DEMAND
127. VictorySystem - Victory system
128. OnboardingSystem - Onboarding system

**Action:** These are session-specific - load only when needed.

### **Other (1)**
129. GameSettings - Game settings (KEEP - essential for UI)

---

## Consolidation Strategy

### **Phase 1: Identify Essential Autoloads (15-20)**

**Must Keep (Core Kernel):**
1. WorldMemory - Deterministic fact log
2. WorldMeaning - Derived meaning
3. WorldPersistence - Save/load
4. WorldRNG - Deterministic RNG
5. GameManager - Game loop
6. JobManager - Job queue
7. StockpileManager - Resources
8. TickManager - Tick coordination
9. WorldClock - Time tracking
10. GameSettings - Settings

**Must Keep (Core Gameplay):**
11. SettlementMemory - Settlement state
12. SettlementRegistry - Settlement tracking
13. ZoneRegistry - Zone tracking
14. BuildingRegistry - Building tracking
15. ColonySimServices - Colony metrics

**Must Keep (Core Features):**
16. KnowledgeSystem - Knowledge (core feature)
17. TechnologySystem - Technology (core feature)
18. CraftingSystem - Crafting (core feature)
19. ProgressionSystem - Progression (core feature)
20. CivilizationStage - Civilization stage (core feature)

**Total Essential: 20 autoloads**

### **Phase 2: Create Consolidated Managers**

Instead of 100+ niche autoloads, create consolidated managers:

1. **SettlementManager** - Consolidates SettlementPlanner, SettlementRebirth, SettlementArchitect
2. **AIManager** - Consolidates all AI systems except WorldAI
3. **MemoryManager** - Consolidates all niche memory systems
4. **SocialManager** - Consolidates social systems (grudges, gossip, relationships)
5. **FactionManager** - Consolidates faction and authority systems
6. **CombatManager** - Consolidates combat and military systems
7. **PlayerManager** - Consolidates player systems
8. **UIManager** - Consolidates UI systems
9. **EventManager** - Consolidates world event systems
10. **EconomyManager** - Consolidates trade and economy systems
11. **PawnManager** - Consolidates pawn consciousness and dialogue
12. **ObserverManager** - Consolidates observer and vision systems

### **Phase 3: Convert Non-Essential to On-Demand**

**Debug Tools (load only when debugging):**
- CrashTrap, TickMonitor, PlaytestRecorder, PlaytestInputRecorder, PawnCommunicationLog

**Export Utilities (load only when exporting):**
- ChronicleExport, WorldSeedExport, CharacterExport, WorldActionLedger

**Session-Specific (load only when needed):**
- VictorySystem, OnboardingSystem

**Non-Essential Features (mark as v1.1):**
- ReligionManager, DisasterManager, CombatManager, ObserverManager

### **Phase 4: Update References**

For each removed autoload:
1. Search for all references using grep
2. Replace global access with get_node() or consolidate into new manager
3. Test that game still launches
4. Verify no circular dependencies

---

## Execution Plan

### **Step 1: Create Consolidated Managers (2-3 hours)**
- [ ] Create SettlementManager.gd
- [ ] Create AIManager.gd
- [ ] Create MemoryManager.gd
- [ ] Create SocialManager.gd
- [ ] Create FactionManager.gd
- [ ] Create CombatManager.gd
- [ ] Create PlayerManager.gd
- [ ] Create UIManager.gd
- [ ] Create EventManager.gd
- [ ] Create EconomyManager.gd
- [ ] Create PawnManager.gd
- [ ] Create ObserverManager.gd

### **Step 2: Migrate Code to New Managers (4-6 hours)**
- [ ] Migrate SettlementPlanner code to SettlementManager
- [ ] Migrate SettlementRebirth code to SettlementManager
- [ ] Migrate SettlementArchitect code to SettlementManager
- [ ] Migrate AI systems to AIManager
- [ ] Migrate memory systems to MemoryManager
- [ ] Migrate social systems to SocialManager
- [ ] Continue for all consolidated managers

### **Step 3: Remove Old Autoloads from project.godot (1 hour)**
- [ ] Remove non-essential autoloads from [autoload] section
- [ ] Keep only 20 essential autoloads
- [ ] Add 12 consolidated managers

### **Step 4: Update All References (4-6 hours)**
- [ ] Search and replace autoload references
- [ ] Update get_node() calls
- [ ] Fix any compilation errors
- [ ] Test that game launches

### **Step 5: Verify and Test (2-3 hours)**
- [ ] Run game in Godot editor
- [ ] Check console for errors
- [ ] Test core gameplay loop
- [ ] Verify save/load works
- [ ] Check performance improvement

---

## Expected Results

**Before:**
- 164 autoloads
- Slow startup (all autoloads load at start)
- High memory usage (all autoloads in memory)
- Complex dependencies
- Risk of circular dependencies

**After (target):**
- 20 essential autoloads + 12 consolidated managers = 32 total
- Fast startup (only essential systems load)
- Lower memory usage (non-essential loaded on-demand)
- Clearer architecture
- Reduced dependency complexity

---

## Risk Mitigation

**High Risk:** Breaking references when removing autoloads
- **Mitigation:** Use git checkpoints, test after each removal, grep for references first

**Medium Risk:** Consolidated managers become too complex
- **Mitigation:** Keep managers focused, add clear documentation, modular design

**Low Risk:** Performance regression
- **Mitigation:** Profile before and after, measure actual improvements

---

## Success Criteria

- [ ] Autoload count reduced from 164 to ≤32
- [ ] Game launches without errors
- [ ] Core gameplay loop works
- [ ] Save/load functions correctly
- [ ] No circular dependencies
- [ ] Startup time improved by ≥50%
- [ ] Memory usage reduced by ≥30%

---

**Next Action:** Begin Step 1 - Create consolidated managers. Start with SettlementManager as it has clear consolidation targets.
