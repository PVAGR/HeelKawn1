# AUTOLOAD CONSOLIDATION PLAN

**Generated:** 2026-05-21
**Project:** HeelKawn (Godot 4.6)
**Total autoloads in project.godot:** 159
**Total .gd files in autoloads/:** 154
**Total lines of code (autoloads/):** 54,847
**Files in autoloads/ NOT registered:** 35 (AgeMemory, AIManager, AuthorityJobBoard, BloodlineSystem, ChronicleExport, EconomyManager, EventManager, FactionRegistry, FootpathMemory, GossipManager, GrudgeManager, HeelKawnianIdentity, IntentMemory, MythMemory, ObserverManager, PawnBrainBridge, PawnManager, PlayerManager, RemnantMemory, RoadMemory, SacredMemory, SchismManager, SettlementAIBridge, SettlementArchitect, SettlementRebirth, SimVision, SnowAccumulation, TimeLapseRecorder, ToolManager, TradeMemory, TradePlanner, UIManager, WorldClock, WorldEventSeed, WorldSeedExport)

---

## 1. SUMMARY TABLE — ALL 159 AUTOLOADS

| # | Autoload Name | Path | LOC | Category | Notes |
|---|---|---|---|---|---|
| 1 | PawnAccess | autoloads/PawnAccess.gd | 48 | Core Kernel | Pawn lookup facade |
| 2 | TickManager | autoloads/TickManager.gd | 272 | Core Kernel | Simulation tick driver |
| 3 | TickBudgetManager | autoloads/TickBudgetManager.gd | 24 | Core Kernel | Budget coordinator (tiny) |
| 4 | KinshipSystem | autoloads/KinshipSystem.gd | 699 | Active System | Family/relationship tracking |
| 5 | CrashTrap | autoloads/CrashTrap.gd | 117 | Core Kernel | Error handling/safety net |
| 6 | GameManager | autoloads/GameManager.gd | 450 | Core Kernel | Game state machine |
| 7 | JobManager | autoloads/JobManager.gd | 870 | Core Kernel | Job lifecycle management |
| 8 | MemoryManager | autoloads/MemoryManager.gd | 231 | Active System | Pawn memory operations |
| 9 | SocialManager | autoloads/SocialManager.gd | 183 | Active System | Social interaction routing |
| 10 | ProgressionSystem | autoloads/ProgressionSystem.gd | 34 | Stub/Vision | Thin wrapper, 42 LOC |
| 11 | StockpileManager | autoloads/StockpileManager.gd | 280 | Core Kernel | Resource stockpile tracking |
| 12 | ZoneRegistry | autoloads/ZoneRegistry.gd | 69 | Active System | Zone data registry |
| 13 | BuildingRegistry | autoloads/BuildingRegistry.gd | 571 | Active System | Building type definitions |
| 14 | ColonySimServices | autoloads/ColonySimServices.gd | 845 | Core Kernel | Colony simulation coordinator |
| 15 | ColonyBayesTree | autoloads/ColonyBayesTree.gd | 246 | Active System | Bayesian decision tree |
| 16 | WorldMemory | scripts/kernel/WorldMemory.gd | 2431 | Core Kernel | Append-only fact store |
| 17 | WorldMeaning | autoloads/WorldMeaning.gd | 1087 | Core Kernel | Meaning/emergence engine |
| 18 | WorldPersistence | autoloads/WorldPersistence.gd | 381 | Core Kernel | Save/load orchestration |
| 19 | CulturalMemory | autoloads/CulturalMemory.gd | 301 | Active System | Cultural value tracking |
| 20 | CulturalStyleManager | autoloads/CulturalStyleManager.gd | 235 | Active System | Visual/style mapping |
| 21 | SettlementMemory | autoloads/SettlementMemory.gd | 4270 | Active System | Largest autoload, settlement facts |
| 22 | SettlementRegistry | autoloads/SettlementRegistry.gd | 162 | Active System | Settlement lookup |
| 23 | SettlementManager | autoloads/SettlementManager.gd | 97 | Duplicate/Redundant | Overlaps with SettlementRegistry |
| 24 | SpatialManager | autoloads/SpatialManager.gd | 301 | Active System | Spatial queries |
| 25 | FragmentationManager | autoloads/FragmentationManager.gd | 102 | Stub/Vision | Thin, 102 LOC |
| 26 | SettlementPlanner | autoloads/SettlementPlanner.gd | 1587 | Active System | AI settlement planning |
| 27 | BuildingUsageTracker | autoloads/BuildingUsageTracker.gd | 318 | Active System | Building utilization tracking |
| 28 | ChronicleLog | autoloads/ChronicleLog.gd | 59 | UI-only | Chronicle event log (thin) |
| 29 | ObserverLens | scripts/kernel/observer_lens.gd | ~80 | Core Kernel | Observer/debug lens |
| 30 | WorldAI | scripts/ai/WorldAI.gd | ~500 | Core Kernel | Top-level AI coordinator |
| 31 | WorldEvents | autoloads/WorldEvents.gd | 555 | Active System | World event generation |
| 32 | WorldEventSystem | autoloads/WorldEventSystem.gd | 140 | Duplicate/Redundant | Overlaps with WorldEvents |
| 33 | WorldRNG | autoloads/WorldRNG.gd | 36 | Core Kernel | Deterministic RNG |
| 34 | PlayerIntentQueue | autoloads/PlayerIntentQueue.gd | 130 | Core Kernel | Player command queue |
| 35 | ReligionLens | autoloads/ReligionLens.gd | 125 | Stub/Vision | Read-only religion overlay |
| 36 | ObservationAPI | autoloads/ObservationAPI.gd | 606 | Active System | Observation data API |
| 37 | MeaningAudioCue | autoloads/MeaningAudioCue.gd | 202 | UI-only | Audio cue system |
| 38 | MeaningAmbianceController | autoloads/MeaningAmbianceController.gd | 236 | UI-only | Ambiance audio controller |
| 39 | CommandAPI | autoloads/CommandAPI.gd | 718 | Core Kernel | Command processing |
| 40 | AIAgentManager | autoloads/AIAgentManager.gd | 1190 | Active System | AI agent lifecycle |
| 41 | RelationalGraph | autoloads/RelationalGraph.gd | 68 | Stub/Vision | Thin, 68 LOC |
| 42 | KnowledgeSystem | autoloads/KnowledgeSystem.gd | 1945 | Active System | Knowledge/trait learning |
| 43 | CraftingSystem | autoloads/CraftingSystem.gd | 673 | Active System | Crafting recipes/execution |
| 44 | AuthoritySystem | autoloads/AuthoritySystem.gd | 437 | Active System | Authority/hierarchy |
| 45 | CollapseSystem | autoloads/CollapseSystem.gd | 459 | Active System | Settlement collapse logic |
| 46 | PersistenceSystem | autoloads/PersistenceSystem.gd | 332 | Duplicate/Redundant | Overlaps with WorldPersistence |
| 47 | GeneticEvolution | autoloads/GeneticEvolution.gd | 271 | Future/V2 | Genetic trait evolution |
| 48 | HistoricalSimulation | autoloads/HistoricalSimulation.gd | 476 | Future/V2 | Deep-time history sim |
| 49 | TechnologySystem | autoloads/TechnologySystem.gd | 341 | Future/V2 | Tech tree (not v1) |
| 50 | CivilizationStage | autoloads/CivilizationStage.gd | 471 | Future/V2 | Era progression |
| 51 | SquadCoordinator | autoloads/SquadCoordinator.gd | 66 | Stub/Vision | Thin, 66 LOC |
| 52 | CharacterExport | autoloads/CharacterExport.gd | 348 | Future/V2 | Character export/import |
| 53 | BodyRiskManager | autoloads/BodyRiskManager.gd | 217 | Active System | Body part risk assessment |
| 54 | PrisonerManager | autoloads/PrisonerManager.gd | 144 | Future/V2 | Prisoner handling |
| 55 | LegacySystem | autoloads/LegacySystem.gd | 414 | Active System | Legacy/inheritance tracking |
| 56 | WildlifePopulation | autoloads/WildlifePopulation.gd | 300 | Active System | Wildlife simulation |
| 57 | DisasterSystem | autoloads/DisasterSystem.gd | 573 | Active System | Natural disasters |
| 58 | OnboardingSystem | autoloads/OnboardingSystem.gd | 356 | UI-only | Tutorial/onboarding |
| 59 | VictorySystem | autoloads/VictorySystem.gd | 200 | Future/V2 | Win conditions |
| 60 | FactionSystem | autoloads/FactionSystem.gd | 287 | Active System | Faction mechanics |
| 61 | Weather | scenes/world/Weather.gd | ~100 | Duplicate/Redundant | Overlaps with WorldEnvironmentManager |
| 62 | WindSystem | autoloads/WindSystem.gd | 18 | Duplicate/Redundant | Merged into WorldEnvironmentManager |
| 63 | FarmingSystem | autoloads/FarmingSystem.gd | 529 | Active System | Agriculture simulation |
| 64 | ObjectPool | autoloads/ObjectPool.gd | 191 | Core Kernel | Object pooling utility |
| 65 | SpatialGrid | autoloads/SpatialGrid.gd | 274 | Core Kernel | Spatial partitioning |
| 66 | EventBus | autoloads/EventBus.gd | 259 | Core Kernel | Event pub/sub |
| 67 | SurvivalSystem | autoloads/SurvivalSystem.gd | 680 | Active System | Survival needs |
| 68 | BodyPartWounds | autoloads/BodyPartWounds.gd | 379 | Active System | Wound tracking |
| 69 | DiseaseSystem | autoloads/DiseaseSystem.gd | 262 | Active System | Disease simulation |
| 70 | CrimeSystem | autoloads/CrimeSystem.gd | 325 | Active System | Crime/punishment |
| 71 | ReligionSystem | autoloads/ReligionSystem.gd | 277 | Active System | Religion mechanics |
| 72 | PlayerGathering | autoloads/PlayerGathering.gd | 539 | Active System | Player gathering actions |
| 73 | PlayerBuilding | autoloads/PlayerBuilding.gd | 517 | Active System | Player building actions |
| 74 | PawnConsciousness | autoloads/PawnConsciousness.gd | 500 | Active System | Pawn awareness/consciousness |
| 75 | HeelKawnianMind | autoloads/HeelKawnianMind.gd | 832 | Active System | HeelKawnian decision mind |
| 76 | WorldActionLedger | autoloads/WorldActionLedger.gd | 569 | Active System | Action history ledger |
| 77 | AICombatProgression | scripts/ai/AICombatProgression.gd | ~200 | Active System | Combat AI progression |
| 78 | CombatNarrative | scripts/ai/CombatNarrative.gd | ~150 | Active System | Combat narrative generation |
| 79 | SquadSystem | scripts/ai/SquadSystem.gd | ~200 | Active System | Squad combat logic |
| 80 | BattleReporter | scripts/ai/BattleReporter.gd | ~100 | Active System | Battle reporting |
| 81 | GuildSystem | scripts/ai/GuildSystem.gd | ~200 | Active System | Guild mechanics |
| 82 | GeneticsSystem | scripts/ai/GeneticsSystem.gd | ~200 | Future/V2 | Genetics (separate from GeneticEvolution) |
| 83 | NameGenerator | scripts/ai/NameGenerator.gd | ~100 | Core Kernel | Name generation utility |
| 84 | GovernorSystem | scripts/ai/GovernorSystem.gd | ~200 | Active System | AI governor logic |
| 85 | MemorialSystem | autoloads/MemorialSystem.gd | 524 | Active System | Memorial/death tracking |
| 86 | SacredGeography | autoloads/SacredGeography.gd | 211 | Stub/Vision | Sacred geography overlay |
| 87 | SettlementPersistenceManager | autoloads/SettlementPersistenceManager.gd | 47 | Duplicate/Redundant | Overlaps with WorldPersistence |
| 88 | WorldEventSeedManager | autoloads/WorldEventSeedManager.gd | 34 | Duplicate/Redundant | Overlaps with WorldRNG |
| 89 | PlaytestRecorder | autoloads/PlaytestRecorder.gd | 415 | UI-only | Playtest data recording |
| 90 | PlaytestInputRecorder | autoloads/PlaytestInputRecorder.gd | 196 | UI-only | Input recording for playtests |
| 91 | PawnCommunicationLog | autoloads/PawnCommunicationLog.gd | 232 | Active System | Pawn communication history |
| 92 | UILayoutManager | autoloads/UILayoutManager.gd | 221 | UI-only | UI layout coordination |
| 93 | PawnChatterBubbles | autoloads/PawnChatterBubbles.gd | 274 | UI-only | Speech bubble rendering |
| 94 | HeelKawnUIManager | autoloads/HeelKawnUIManager.gd | 199 | UI-only | UI manager |
| 95 | EventNotificationOverlay | scripts/ui/EventNotificationOverlay.gd | ~100 | UI-only | Notification overlay |
| 96 | ModernTheme | scripts/ui/ModernTheme.gd | ~50 | UI-only | Theme/styling |
| 97 | PawnMoodUI | scripts/ui/PawnMoodUI.gd | ~80 | UI-only | Mood display |
| 98 | CataclysmSystem | scripts/world/CataclysmSystem.gd | ~200 | Future/V2 | Cataclysm events |
| 99 | ZoomSystem | scripts/world/ZoomSystem.gd | ~100 | UI-only | Camera zoom control |
| 100 | GameSettings | autoloads/GameSettings.gd | 307 | Core Kernel | Settings persistence |
| 101 | MythAge | autoloads/MythAge.gd | 184 | Stub/Vision | Myth age tracking |
| 102 | DiscoveryGate | autoloads/DiscoveryGate.gd | 32 | Stub/Vision | Discovery gating (thin) |
| 103 | FogOfDiscovery | autoloads/FogOfDiscovery.gd | 190 | Active System | Fog of war/discovery |
| 104 | HeelKawnianVoice | autoloads/HeelKawnianVoice.gd | 312 | UI-only | Voice/audio for HeelKawnians |
| 105 | HeelKawnAIOrchestrator | scripts/ai/HeelKawnAIOrchestrator.gd | ~300 | Core Kernel | AI orchestration |
| 106 | IncarnationManager | autoloads/IncarnationManager.gd | 187 | Active System | Player incarnation |
| 107 | HeelKawnianManager | autoloads/HeelKawnianManager.gd | 2455 | Active System | HeelKawnian lifecycle (largest) |
| 108 | PawnDialogue | autoloads/PawnDialogue.gd | 152 | Active System | Dialogue system |
| 109 | RitualMagicSystem | autoloads/RitualMagicSystem.gd | 147 | Future/V2 | Ritual magic |
| 110 | NavalSystem | autoloads/NavalSystem.gd | 116 | Future/V2 | Naval/water combat |
| 111 | MountSystem | autoloads/MountSystem.gd | 146 | Future/V2 | Mount/riding system |
| 112 | TerraformingSystem | autoloads/TerraformingSystem.gd | 67 | Future/V2 | Terrain modification |
| 113 | FlowingWater | autoloads/FlowingWater.gd | 109 | Future/V2 | Water simulation |
| 114 | EcologySystem | autoloads/EcologySystem.gd | 670 | Active System | Ecosystem simulation |
| 115 | ChronicleNarrativeSystem | autoloads/ChronicleNarrativeSystem.gd | 519 | Active System | Chronicle narrative generation |
| 116 | NationBorderSystem | autoloads/NationBorderSystem.gd | 673 | Future/V2 | Nation borders |
| 117 | DynastyFamilySystem | autoloads/DynastyFamilySystem.gd | 595 | Future/V2 | Dynasty/family trees |
| 118 | DailyRoutineSystem | autoloads/DailyRoutineSystem.gd | 516 | Active System | Daily routines |
| 119 | SupplyChainSystem | autoloads/SupplyChainSystem.gd | 551 | Future/V2 | Supply chain logistics |
| 120 | OfficerRankSystem | autoloads/OfficerRankSystem.gd | 414 | Future/V2 | Military ranks |
| 121 | ArmyBattleSystem | autoloads/ArmyBattleSystem.gd | 477 | Future/V2 | Army battles |
| 122 | CharacterProgressionSystem | autoloads/CharacterProgressionSystem.gd | 405 | Future/V2 | Character progression |
| 123 | UndergroundSystem | autoloads/UndergroundSystem.gd | 141 | Future/V2 | Underground/caves |
| 124 | CurrencySystem | autoloads/CurrencySystem.gd | 10 | Duplicate/Redundant | Thin wrapper for WorldEconomyManager |
| 125 | DiplomacySystem | autoloads/DiplomacySystem.gd | 121 | Future/V2 | Diplomacy mechanics |
| 126 | ArtSystem | autoloads/ArtSystem.gd | 79 | Future/V2 | Art/culture system |
| 127 | LanguageSystem | autoloads/LanguageSystem.gd | 71 | Future/V2 | Language evolution |
| 128 | MultiplayerSystem | autoloads/MultiplayerSystem.gd | 34 | Future/V2 | Multiplayer stubs (34 LOC) |
| 129 | FactionManager | autoloads/FactionManager.gd | 414 | Duplicate/Redundant | Overlaps with FactionSystem |
| 130 | FoodChainManager | autoloads/FoodChainManager.gd | 268 | Duplicate/Redundant | Loaded by WorldEconomyManager |
| 131 | TickRateDecoupler | autoloads/TickRateDecoupler.gd | 162 | Core Kernel | Tick rate management |
| 132 | CharacterBrainSystem | autoloads/CharacterBrainSystem.gd | 182 | Active System | Character decision brain |
| 133 | ArtifactSystem | autoloads/ArtifactSystem.gd | 118 | Future/V2 | Artifact system |
| 134 | WorldEnvironmentManager | autoloads/WorldEnvironmentManager.gd | 60 | Duplicate/Redundant | Consolidates Weather/Wind/Ecology |
| 135 | WorldEconomyManager | autoloads/WorldEconomyManager.gd | 86 | Duplicate/Redundant | Consolidates CurrencySystem/EconomyManager |
| 136 | WorldHistoryManager | autoloads/WorldHistoryManager.gd | 31 | Duplicate/Redundant | Thin wrapper for AgeMemory/CulturalMemory |
| 137 | PawnBrainBridge | autoloads/PawnBrainBridge.gd | 81 | Stub/Vision | Bridge between pawn and brain |
| 138 | AIManager | autoloads/AIManager.gd | 124 | Duplicate/Redundant | Overlaps with WorldAI/AIAgentManager |
| 139 | PlayerManager | autoloads/PlayerManager.gd | 78 | Duplicate/Redundant | Overlaps with GameManager |
| 140 | EventManager | autoloads/EventManager.gd | 59 | Duplicate/Redundant | Overlaps with EventBus/WorldEvents |
| 141 | ObserverManager | autoloads/ObserverManager.gd | 78 | Stub/Vision | Observer mode manager |
| 142 | PawnManager | autoloads/PawnManager.gd | 96 | Duplicate/Redundant | Overlaps with PawnAccess/HeelKawnianManager |
| 143 | AuthorityJobBoard | autoloads/AuthorityJobBoard.gd | 163 | Duplicate/Redundant | Overlaps with JobManager |
| 144 | EconomyManager | autoloads/EconomyManager.gd | 77 | Duplicate/Redundant | Overlaps with WorldEconomyManager |
| 145 | GrudgeManager | autoloads/GrudgeManager.gd | 663 | Active System | Grudge/reputation tracking |
| 146 | GossipManager | autoloads/GossipManager.gd | 585 | Active System | Gossip propagation |
| 147 | BloodlineSystem | autoloads/BloodlineSystem.gd | 530 | Future/V2 | Bloodline tracking |
| 148 | FootpathMemory | autoloads/FootpathMemory.gd | 105 | Stub/Vision | Footpath memory |
| 149 | RoadMemory | autoloads/RoadMemory.gd | 143 | Stub/Vision | Road memory |
| 150 | TradeMemory | autoloads/TradeMemory.gd | 634 | Active System | Trade history |
| 151 | TradePlanner | autoloads/TradePlanner.gd | 326 | Active System | Trade route planning |
| 152 | ToolManager | autoloads/ToolManager.gd | 172 | Active System | Tool management |
| 153 | WorldClock | autoloads/WorldClock.gd | 26 | Stub/Vision | World clock (thin) |
| 154 | WorldEventSeed | autoloads/WorldEventSeed.gd | 31 | Duplicate/Redundant | Overlaps with WorldRNG |
| 155 | WorldSeedExport | autoloads/WorldSeedExport.gd | 233 | Stub/Vision | Seed export utility |
| 156 | SettlementAIBridge | autoloads/SettlementAIBridge.gd | 42 | Stub/Vision | Settlement AI bridge (thin) |
| 157 | SettlementArchitect | autoloads/SettlementArchitect.gd | 147 | Stub/Vision | Settlement architecture |
| 158 | SettlementRebirth | autoloads/SettlementRebirth.gd | 416 | Active System | Settlement rebirth logic |
| 159 | SimVision | autoloads/SimVision.gd | 29 | Stub/Vision | Design surface, not simulation |

---

## 2. CATEGORY BREAKDOWN

| Category | Count | % of Total | Total LOC |
|---|---|---|---|
| **Core Kernel** (must stay) | 15 | 9.4% | ~6,500 |
| **Active Systems** (keep for now) | 42 | 26.4% | ~22,000 |
| **Stub/Vision** (convert to regular scripts) | 18 | 11.3% | ~1,500 |
| **Duplicate/Redundant** (candidates for removal) | 16 | 10.1% | ~1,200 |
| **UI-only** (can be lazy-loaded) | 12 | 7.5% | ~1,800 |
| **Future/V2** (not needed for v1) | 24 | 15.1% | ~5,200 |
| **Not in project.godot** (already deregistered) | 32 | 20.1% | ~16,647 |

---

## 3. RECOMMENDED 11 CORE MANAGERS

These 11 autoloads form the irreducible kernel and **must remain as autoloads**:

| # | Manager | Purpose |
|---|---|---|
| 1 | **TickManager** | Simulation tick driver, time source |
| 2 | **GameManager** | Game state machine, lifecycle |
| 3 | **WorldMemory** | Append-only fact store (kernel truth) |
| 4 | **WorldMeaning** | Meaning/emergence engine |
| 5 | **WorldPersistence** | Save/load orchestration |
| 6 | **JobManager** | Job lifecycle, assignment, execution |
| 7 | **StockpileManager** | Resource tracking, inventory |
| 8 | **ColonySimServices** | Colony simulation coordinator |
| 9 | **WorldAI** | Top-level AI coordination |
| 10 | **WorldRNG** | Deterministic random number generation |
| 11 | **EventBus** | Event pub/sub, decoupled communication |

**Additional strong candidates for Core Kernel** (keep as autoload but not in the 11):
- **SpatialGrid** — spatial partitioning, heavily used
- **ObjectPool** — object pooling utility
- **CommandAPI** — player command processing
- **TickRateDecoupler** — tick rate management
- **GameSettings** — settings persistence
- **CrashTrap** — error handling safety net
- **PawnAccess** — pawn lookup facade
- **ObserverLens** — debug/observer lens
- **NameGenerator** — name generation utility
- **HeelKawnAIOrchestrator** — AI orchestration

---

## 4. PHASE-BY-PHASE REMOVAL PLAN

### Phase 1: Safe Removals (Zero Risk)

These are thin wrappers, stubs, or explicitly-not-simulation files. Removing them will not break gameplay.

| Autoload | LOC | Risk | Reason |
|---|---|---|---|
| CurrencySystem | 10 | None | Thin wrapper for WorldEconomyManager, just delegates calls |
| MultiplayerSystem | 34 | None | Stubs only, no multiplayer implemented |
| SimVision | 29 | None | Explicitly "not authoritative simulation" — design surface only |
| DiscoveryGate | 32 | None | Thin gating logic, can be inlined |
| WorldClock | 26 | None | Thin clock wrapper, can use TickManager directly |
| WorldEventSeed | 31 | None | Overlaps with WorldRNG |
| WorldEventSeedManager | 34 | None | Overlaps with WorldRNG |
| WorldHistoryManager | 31 | None | Thin wrapper for AgeMemory/CulturalMemory |
| SettlementAIBridge | 42 | None | Thin bridge, can be inlined |
| WindSystem | 18 | None | Merged into WorldEnvironmentManager |

**Phase 1 total LOC saved:** ~287
**Phase 1 risk:** MINIMAL — all are thin wrappers or explicit stubs

### Phase 2: Stub/Vision Conversions (Low Risk)

These are real files but are thin enough or vision-scoped enough to convert from autoload to regular script instances.

| Autoload | LOC | Risk | Reason |
|---|---|---|---|
| RelationalGraph | 68 | Low | Simple graph, can be instantiated on-demand |
| SquadCoordinator | 66 | Low | Thin coordinator, can be scene-owned |
| FragmentationManager | 102 | Low | Thin, can be part of SettlementMemory |
| PawnBrainBridge | 81 | Low | Bridge pattern, can be inline |
| ObserverManager | 78 | Low | Observer mode, can be scene-owned |
| SettlementPersistenceManager | 47 | Low | Overlaps with WorldPersistence |
| SacredGeography | 211 | Low | Read-only overlay, can be lazy-loaded |
| ReligionLens | 125 | Low | Read-only overlay, can be lazy-loaded |
| MythAge | 184 | Low | Can be part of WorldHistoryManager |
| FootpathMemory | 105 | Low | Memory layer, can be part of WorldMemory |
| RoadMemory | 143 | Low | Memory layer, can be part of WorldMemory |
| WorldSeedExport | 233 | Low | Export utility, not runtime-critical |
| SettlementArchitect | 147 | Low | Can be part of SettlementPlanner |
| PawnManager | 96 | Low | Overlaps with PawnAccess |
| EventManager | 59 | Low | Overlaps with EventBus |
| AIManager | 124 | Low | Overlaps with WorldAI |
| PlayerManager | 78 | Low | Overlaps with GameManager |
| AuthorityJobBoard | 163 | Low | Overlaps with JobManager |

**Phase 2 total LOC saved:** ~2,250
**Phase 2 risk:** LOW — requires updating references but no gameplay changes

### Phase 3: Future/V2 Systems (Medium Risk)

These are real systems but are not needed for v1 colony simulation. Can be commented out or converted to optional autoloads.

| Autoload | LOC | Risk | Reason |
|---|---|---|---|
| NavalSystem | 116 | Medium | No naval gameplay in v1 |
| MountSystem | 146 | Medium | No mount gameplay in v1 |
| TerraformingSystem | 67 | Medium | No terraforming in v1 |
| FlowingWater | 109 | Medium | Water sim not v1-critical |
| RitualMagicSystem | 147 | Medium | Magic system not v1-critical |
| MultiplayerSystem | 34 | Low | Already listed in Phase 1 |
| CataclysmSystem | ~200 | Medium | Cataclysm events not v1-critical |
| NationBorderSystem | 673 | Medium | Nation borders not v1-critical |
| DynastyFamilySystem | 595 | Medium | Dynasty trees not v1-critical |
| SupplyChainSystem | 551 | Medium | Supply chain not v1-critical |
| OfficerRankSystem | 414 | Medium | Military ranks not v1-critical |
| ArmyBattleSystem | 477 | Medium | Army battles not v1-critical |
| CharacterProgressionSystem | 405 | Medium | Character progression not v1-critical |
| UndergroundSystem | 141 | Medium | Underground not v1-critical |
| DiplomacySystem | 121 | Medium | Diplomacy not v1-critical |
| ArtSystem | 79 | Medium | Art system not v1-critical |
| LanguageSystem | 71 | Medium | Language evolution not v1-critical |
| ArtifactSystem | 118 | Medium | Artifacts not v1-critical |
| GeneticEvolution | 271 | Medium | Genetics not v1-critical |
| HistoricalSimulation | 476 | Medium | Deep-time sim not v1-critical |
| TechnologySystem | 341 | Medium | Tech tree not v1-critical |
| CivilizationStage | 471 | Medium | Era progression not v1-critical |
| VictorySystem | 200 | Medium | Win conditions not v1-critical |
| PrisonerManager | 144 | Medium | Prisoners not v1-critical |
| CharacterExport | 348 | Medium | Export not v1-critical |
| GeneticsSystem | ~200 | Medium | Genetics (duplicate of GeneticEvolution) |
| BloodlineSystem | 530 | Medium | Bloodlines not v1-critical |

**Phase 3 total LOC saved:** ~7,300
**Phase 3 risk:** MEDIUM — systems exist but are not v1-critical; may need reactivation later

### Phase 4: Duplicate/Redundant Consolidation (Medium-High Risk)

These autoloads duplicate functionality of other systems. Requires careful refactoring.

| Autoload | Duplicates | LOC | Risk | Action |
|---|---|---|---|---|
| SettlementManager | SettlementRegistry | 97 | Medium | Merge into SettlementRegistry |
| WorldEventSystem | WorldEvents | 140 | Medium | Merge into WorldEvents |
| PersistenceSystem | WorldPersistence | 332 | Medium | Merge into WorldPersistence |
| FactionManager | FactionSystem | 414 | Medium | Merge into FactionSystem |
| FoodChainManager | WorldEconomyManager | 268 | Medium | Already loaded by WorldEconomyManager |
| EconomyManager | WorldEconomyManager | 77 | Low | Already superseded |
| Weather | WorldEnvironmentManager | ~100 | Medium | Merged into WorldEnvironmentManager |
| PlayerManager | GameManager | 78 | Low | Merge into GameManager |
| PawnManager | PawnAccess + HeelKawnianManager | 96 | Medium | Merge into PawnAccess |
| AIManager | WorldAI + AIAgentManager | 124 | Medium | Merge into WorldAI |
| EventManager | EventBus + WorldEvents | 59 | Low | Merge into EventBus |
| AuthorityJobBoard | JobManager | 163 | Medium | Merge into JobManager |
| CurrencySystem | WorldEconomyManager | 10 | Low | Already a thin wrapper |
| WorldEnvironmentManager | Weather + WindSystem + EcologySystem | 60 | Low | Consolidation target, not source |
| WorldEconomyManager | CurrencySystem + EconomyManager | 86 | Low | Consolidation target, not source |
| WorldHistoryManager | AgeMemory + CulturalMemory | 31 | Low | Consolidation target, not source |

**Phase 4 total LOC saved:** ~2,100 (after consolidation, not deletion)
**Phase 4 risk:** MEDIUM-HIGH — requires careful refactoring to avoid breaking references

### Phase 5: UI-Only Lazy Loading (Low Risk)

These are UI components that can be lazy-loaded instead of being autoloads.

| Autoload | LOC | Risk | Reason |
|---|---|---|---|
| ChronicleLog | 59 | Low | Can be scene-owned |
| MeaningAudioCue | 202 | Low | Can be lazy-loaded |
| MeaningAmbianceController | 236 | Low | Can be lazy-loaded |
| OnboardingSystem | 356 | Low | Only needed during tutorial |
| PlaytestRecorder | 415 | Low | Debug tool, not runtime |
| PlaytestInputRecorder | 196 | Low | Debug tool, not runtime |
| UILayoutManager | 221 | Low | Can be scene-owned |
| PawnChatterBubbles | 274 | Low | Can be scene-owned |
| HeelKawnUIManager | 199 | Low | Can be scene-owned |
| EventNotificationOverlay | ~100 | Low | Can be scene-owned |
| ModernTheme | ~50 | Low | Can be scene-owned |
| PawnMoodUI | ~80 | Low | Can be scene-owned |
| ZoomSystem | ~100 | Low | Can be scene-owned |
| HeelKawnianVoice | 312 | Low | Can be lazy-loaded |

**Phase 5 total LOC saved:** ~2,800
**Phase 5 risk:** LOW — UI components can be instantiated on-demand

---

## 5. RISK ASSESSMENT MATRIX

| Phase | Risk Level | Autoloads Affected | LOC Affected | Breaking Changes? |
|---|---|---|---|---|
| Phase 1: Safe Removals | MINIMAL | 10 | ~287 | No |
| Phase 2: Stub Conversions | LOW | 18 | ~2,250 | Minor (reference updates) |
| Phase 3: Future/V2 | MEDIUM | 27 | ~7,300 | Possible (if features activated) |
| Phase 4: Duplicate Consolidation | MEDIUM-HIGH | 16 | ~2,100 | Yes (requires refactoring) |
| Phase 5: UI Lazy Loading | LOW | 14 | ~2,800 | Minor (instantiation changes) |
| **TOTAL** | | **85** | **~14,737** | |

---

## 6. ESTIMATED LINES OF CODE SAVED

| Category | Autoloads | LOC | Action |
|---|---|---|---|
| Safe removals (Phase 1) | 10 | 287 | Delete from project.godot |
| Stub conversions (Phase 2) | 18 | 2,250 | Convert to regular scripts |
| Future/V2 deferral (Phase 3) | 27 | 7,300 | Comment out or optional |
| Duplicate consolidation (Phase 4) | 16 | 2,100 | Merge into primary systems |
| UI lazy loading (Phase 5) | 14 | 2,800 | Convert to scene-owned |
| **TOTAL POTENTIAL SAVINGS** | **85** | **~14,737** | |

**Note:** This represents autoload registrations removed, not code deleted. The .gd files remain on disk for future reactivation. Actual runtime memory savings will be significant since autoloads are instantiated at game start regardless of whether they're used.

---

## 7. RECOMMENDED EXECUTION ORDER

1. **Week 1:** Phase 1 (safe removals) — 10 autoloads, ~287 LOC
2. **Week 2:** Phase 5 (UI lazy loading) — 14 autoloads, ~2,800 LOC
3. **Week 3:** Phase 2 (stub conversions) — 18 autoloads, ~2,250 LOC
4. **Week 4-5:** Phase 4 (duplicate consolidation) — 16 autoloads, ~2,100 LOC
5. **Week 6+:** Phase 3 (future/V2 deferral) — 27 autoloads, ~7,300 LOC

**Total estimated timeline:** 6-8 weeks for full consolidation

---

## 8. ALREADY DEREGISTERED (35 files in autoloads/ but not in project.godot)

These files exist on disk but are already not registered as autoloads. They can be reviewed for cleanup:

AgeMemory, AIManager, AuthorityJobBoard, BloodlineSystem, ChronicleExport, EconomyManager, EventManager, FactionRegistry, FootpathMemory, GossipManager, GrudgeManager, HeelKawnianIdentity, IntentMemory, MythMemory, ObserverManager, PawnBrainBridge, PawnManager, PlayerManager, RemnantMemory, RoadMemory, SacredMemory, SchismManager, SettlementAIBridge, SettlementArchitect, SettlementRebirth, SimVision, SnowAccumulation, TimeLapseRecorder, ToolManager, TradeMemory, TradePlanner, UIManager, WorldClock, WorldEventSeed, WorldSeedExport

**Note:** Some of these (GossipManager, GrudgeManager, TradeMemory, TradePlanner, ToolManager, SettlementRebirth) are substantial systems that may need to be re-registered or properly integrated.

---

## 9. WARNINGS

- **DO NOT** remove Core Kernel autoloads without thorough testing
- **DO NOT** remove Active Systems until their dependencies are audited
- SettlementMemory (4,270 LOC) and HeelKawnianManager (2,455 LOC) are the two largest autoloads — they should be reviewed for potential splitting but NOT removed
- KnowledgeSystem (1,945 LOC) is critical for pawn learning — keep as autoload
- WorldMemory (2,431 LOC) is the kernel truth store — NEVER remove
- Always run full game tests after each phase
- Keep .gd files on disk even after deregistering from project.godot (for easy reactivation)
