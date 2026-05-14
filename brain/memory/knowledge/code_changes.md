# Code Changes

Changelog of all AI-assisted edits made through the Universe Brain system.

## Format
```
YYYY-MM-DD | System | What changed | Why
```

## 2026-05-14 | Multiple | May 12 Letta disconnection audit — 15 critical bugs fixed across 12 files | Fixed disconnection-related crashes and logic errors following Letta API changes
## 2026-05-14 | Autoload | 11 consolidated managers created | SettlementManager, AIManager, MemoryManager, SocialManager, FactionManager, UIManager, EventManager, EconomyManager, PlayerManager, PawnManager, ObserverManager — first pass of autoload consolidation
## 2026-05-14 | Phase 5A | CivilizationStage.gd added | Civilization development stage lens for tracking settlement progress
## 2026-05-14 | Phase 5A | HeelKawnianManager.gd created | Central manager for HeelKawnian pawn identity and development profiles
## 2026-05-14 | Phase 5A | HeelKawnianIdentity.gd created | Per-pawn identity tracking with cultural and personal development
## 2026-05-14 | Phase 5A | HeelKawnianMind.gd created | Matrix AI behavior wiring for HeelKawnian pawns
## 2026-05-12 | Build | Headless smoke test | Godot 4.6.2 headless mode verified — project loads without errors
## 2026-05-01 | Universe Brain | Created brain/ folder structure and memory system | Foundation for persistent AI memory and cross-session continuity

---

## Historical Changes (pre-Brain)

These were made before the Universe Brain existed. Recorded here for continuity.

### 2026-04-30 | Multiple | Performance smoothing passes | Planner spike guardrails, night hitch trim, claim-scan throttle, wildlife tick cost optimization
### 2026-04-29 | Multiple | Major perf overhaul | Adaptive tick caps, speed-aware cadences, regrowth/mining budgets, social chronicle budget
### 2026-04-29 | WorldEvents/Stockpile | API fix | Replaced nonexistent count_item with count_of; added total_item_count()
### 2026-04-29 | AI | Policy hardwire | Removed F10 AI toggle; AIAgentManager boots always-on from tick 0
### 2026-04-29 | SettlementAI | Parse fix | Fixed Godot 4.6 RefCounted autoload lookup pattern
### 2026-04-27 | Multiple | Phase 4 playtest slice | ColonyHUD, wildlife, rebirth, social/reproduction, UI polish
### 2026-04-27 | Multiple | Observer UX | HUD toggle, camera follow, font sizing, window stretch
### 2026-04-27 | Multiple | Canon shift | Emergence/seeded variety made official; WorldRNG autoload added
