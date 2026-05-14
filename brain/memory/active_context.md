# Active Context

**Last updated:** 2026-05-14
**Current phase:** Phase 5A — Emergent Life foundation (Consolidation)
**Kernel status:** Complete

---

## What We're Working On Now

### Active Tasks
- Autoload consolidation — continue migrating old autoloads to 11 new managers
  - ✅ DONE: SettlementPlanner → SettlementManager (removed from project.godot)
  - ✅ DONE: SettlementRebirth → SettlementManager.process() (removed from project.godot)
  - ✅ DONE: SettlementArchitect → SettlementManager.process_architect() (removed)
  - ✅ DONE: FactionRegistry → FactionManager (removed from project.godot)
  - 🔶 PENDING: GrudgeManager, GossipManager, BloodlineSystem → SocialManager (needs forwarding methods in 8+ files)
  - 🔶 PENDING: ChronicleLog, IntentMemory, AgeMemory → MemoryManager (needs save/load forwarding)
  - 🔶 PENDING: PlayerIntentQueue → PlayerManager (API mismatch—needs redesign)
  - 🔶 PENDING: WorldEvents, WorldEventSeedManager → EventManager (constant refs)
  - 🔶 PENDING: FogOfDiscovery, DiscoveryGate → ObserverManager (field refs)
- Phase 5A integration testing — CivilizationStage, HeelKawnian profiles, Matrix AI
- Headless smoke test verification (passed May 7 — confirm stable)

### Completed This Session (May 14, 2026)
- Documentation truth sweep: fixed phase numbering, completion %, autoload counts across 35+ files
- Autoload consolidation: 4 old autoloads removed from project.godot (164→160), Main.gd refs updated
- HeelKawnian terminology sweep: standardized "HeelKawnian" across docs (README, AI_README, etc.)
- Moved FREE_LLM_SETUP.md → brain/plans/ (aspirational design doc)
- Updated brain memory files to reflect current state
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
- 11 consolidated managers (pending integration)

### DEFERRED Systems
- Full SimVision grand-strategy map
- Dedicated tool items
- TechnologySystem full diffusion
- Online/PVABazaar integration

---

## Next Targets (from HEELKAWN.txt)

1. Complete autoload consolidation (164 → ~30 autoloads)
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
