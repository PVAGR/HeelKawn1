# Active Context

**Last updated:** 2026-05-19
**Current phase:** Phase 5A — Emergent Life foundation (Consolidation)
**Kernel status:** Complete

---

## What We're Working On Now

### Active Tasks
- Autoload consolidation — migrating old autoloads to 11 new managers
  - ✅ DONE (15 removed): SettlementPlanner, SettlementRebirth, SettlementArchitect, FactionRegistry, BloodlineSystem, GrudgeManager, GossipManager, FootpathMemory, AIAutoBuild, AILearning, AICooperation, PawnBrainBridge, SettlementAIBridge, ChronicleExport, WorldSeedExport
  - 🔶 PENDING: ChronicleLog → MemoryManager (needs signal forwarding + save/load)
  - 🔶 PENDING: IntentMemory, AgeMemory, RemnantMemory, MythMemory, SacredMemory → MemoryManager
  - 🔶 PENDING: TradeMemory, TradePlanner, FoodChainManager, ToolManager → EconomyManager
  - 🔶 PENDING: PlayerIntentQueue, PlayerGathering, PlayerBuilding, IncarnationManager → PlayerManager
  - 🔶 PENDING: WorldEvents, WorldEventSeedManager, WorldEventSystem → EventManager
  - 🔶 PENDING: FogOfDiscovery, DiscoveryGate, ObservationAPI, ObserverLens → ObserverManager
  - 🔶 PENDING: RoadMemory → MemoryManager (complex API, many files)
- Phase 5A integration testing — CivilizationStage, HeelKawnian profiles, Matrix AI
- Headless smoke test verification (passed May 7 — confirm stable)

### Completed This Session (May 19, 2026)
- Needs-driven construction: `SettlementPlanner` uses `compute_settlement_build_priorities` for hearth/storage gates; `ColonySimServices` 500–2000 tick build-kind cooldowns; `AIAutoBuild` shares planner dedupe
- Matrix AI: recovery-drive ambitions; `teach_seek` transfers knowledge on arrival
- Settlement truth: formal-only territory overlay; mind panel + country view gated on infrastructure formal gate
- `FactionManager` sync fix in `SettlementMemory._ruler_house_key_for_settlement`

### Completed Prior Session (May 14, 2026)
- Documentation truth sweep: fixed phase numbering, completion %, autoload counts across 35+ files
- Autoload consolidation: 15 old autoloads removed from project.godot (164→149)
  - SettlementPlanner/Rebirth/Architect → SettlementManager
  - FactionRegistry → FactionManager
  - BloodlineSystem, GrudgeManager, GossipManager → SocialManager
  - FootpathMemory → MemoryManager
  - AIAutoBuild, AILearning, AICooperation → AIManager (lazy-load)
  - PawnBrainBridge → PawnManager (lazy-load)
  - SettlementAIBridge, ChronicleExport, WorldSeedExport (unused)
- Added forwarding methods to SocialManager (12), MemoryManager (3), SettlementManager (6)
- Updated 10+ script files (Main.gd, CrimeSystem, HeelKawnianMind, HeelKawnianVoice, HeelKawnian, WorldOverlay, NameGenerator, PawnInfoPanel, GrudgeManager)
- HeelKawnian terminology sweep: standardized across docs
- Moved FREE_LLM_SETUP.md → brain/plans/ (aspirational design doc)
- Updated brain memory files
- Resolved internal contradictions in GODOT_LIMITATION_ANALYSIS.md, CHANGELOG.md, QWEN.md

---

## Project State Summary

- **Overall completion:** ~55-60%
- **Current Phase:** Consolidation + Phase 5A foundation (NOT Phase 4 — Identity & Meaning done)
- **Engine:** Godot 4.6.2
- **Type:** Deterministic 2D world simulation
- **Player role:** Observer/chronicler
- **Core loop:** Settlements evolve autonomously, player watches and records
- **Save system:** Append-only memory (WorldMemory → WorldMeaning → WorldPersistence)

### LIVE Systems
- Kernel (memory → meaning → persistence → culture)
- Colony simulation loop
- Pawn behavior and AI (including Matrix AI wiring)
- Settlement identity and divergence
- CivilizationStage lens
- HeelKawnian Development Profiles
- Literature & Knowledge Preservation
- Wildlife and ecology
- Social bonds and reproduction
- Faction and religion stubs
- Observer HUD (F9)
- Creator debug menu (F10)
- 11 consolidated managers (SettlementManager live, others with lazy-load forwarding)

### DEFERRED Systems
- Full SimVision grand-strategy map
- Dedicated tool items
- TechnologySystem full diffusion
- Online/PVABazaar integration

---

## Next Targets (from HEELKAWN.txt)

1. Complete autoload consolidation (149 → ~30 autoloads; 15 removed so far)
2. Phase 5A integration and testing
3. Continue toward playable prototype (v1 readiness, NOT release candidate)

---

## Known Issues / Watch List

- Godot 4.6 static autoload warnings (benign, ignore)
- Planner spike guardrails in place — monitor at 50x/100x speeds
- 1x claim-scan throttle active — watch for idle pawn behavior changes
- **May 12 Letta audit:** 15 critical bugs fixed across 12 files — watch for regressions

---

## AI Notes

- This project has extensive existing AI tooling (Cursor, Roo Code, Copilot)
- AI_README.md at root is the master AI instruction file (520 lines)
- All lore lives in docs/WORLD_BIBLE/
- Determinism is sacred — no unseeded RNG in world history
- Smallest reversible change is the rule
