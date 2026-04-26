# HEELKAWN SESSION LOG

Use this file as cross-LLM handoff memory.
Each session adds one entry at the top.

---

## 2026-04-25 - Debug log throttling for smoother editor runtime

Date: 2026-04-25
Agent/Model: Codex (Cursor)
Goal: Reduce run-time stutter caused by heavy console spam during simulation.

Changes made:
- Added global verbose logging switch in `autoloads/GameManager.gd` (`VERBOSE_SIM_LOGS`, default false).
- Wrapped noisy hot-path logs behind `GameManager.verbose_logs()` in:
  - `scripts/pawn/Pawn.gd`
  - `scripts/pawn/Animal.gd`
  - `scripts/pawn/PawnSpawner.gd`
  - `scripts/pawn/AnimalSpawner.gd`

Decisions:
- Keep important behavior unchanged; only suppress spam logs by default.
- Leave verbose tracing available with a single toggle.

Open questions:
- Should we expose verbose toggle via HUD/debug hotkey instead of code constant?

Next concrete step:
- Clean static-call warnings (`STATIC_CALLED_ON_INSTANCE`) to reduce editor warning load.

Files touched:
- autoloads/GameManager.gd
- scripts/pawn/Pawn.gd
- scripts/pawn/Animal.gd
- scripts/pawn/PawnSpawner.gd
- scripts/pawn/AnimalSpawner.gd
- docs/SESSION_LOG.md

---

## 2026-04-25 - Tick smoothing pass (frame spike guard)

Date: 2026-04-25
Agent/Model: Codex (Cursor)
Goal: Reduce gameplay stutter when simulation runs at high speed.

Changes made:
- Added `MAX_TICKS_PER_FRAME` guard in `autoloads/GameManager.gd`.
- Updated tick loop to process at most 6 ticks per rendered frame.
- Kept deterministic tick order and existing speed model intact.

Decisions:
- Prefer smooth frame pacing over aggressive single-frame catch-up bursts.

Open questions:
- Should we expose max ticks/frame as a player setting in UI for low-end machines?

Next concrete step:
- Profile `Main._on_game_tick` heavy branches and add optional staggered update buckets.

Files touched:
- autoloads/GameManager.gd
- docs/SESSION_LOG.md

---

## 2026-04-25 - Safe runtime wiring for imported memory systems

Date: 2026-04-25
Agent/Model: Codex (Cursor)
Goal: Activate imported systems in low-risk path so testing covers merged content.

Changes made:
- Registered new autoloads in `project.godot`: `SacredMemory`, `ChronicleLog`, `WorldClock`.
- Wired sacred-site sync into world-derivative recompute flow in `scenes/main/Main.gd`.
- Added `sacred` and `chronicle` persistence fields to save/load payload in `scenes/main/Main.gd`.
- Added explicit clear/reset for sacred/chronicle state on reroll/load prep.

Decisions:
- Integrate only safe deterministic memory systems first; defer high-risk social migration managers until APIs are aligned.

Open questions:
- Should sacred-site state drive immediate visual overlays, or remain a logic-only layer for now?

Next concrete step:
- Add first ChronicleLog producers from existing deterministic events (settlement collapse/revival markers).

Files touched:
- project.godot
- scenes/main/Main.gd
- docs/SESSION_LOG.md

---

## 2026-04-25 - Legacy project import and stabilization

Date: 2026-04-25
Agent/Model: Codex (Cursor)
Goal: Merge richer non-git OneDrive project into GitHub repo and keep runtime safe.

Changes made:
- Synced old project content from OneDrive into repo (addons/assets/resources/new systems).
- Kept git safety by excluding `.git`, `.godot`, `.cursor`, and `.sixth` folders.
- Fixed imported scripts using nonexistent `GameManager.sim_tick` to `GameManager.tick_count`.
- Removed leaked addon secret config and replaced with `config.example.cfg`.
- Added ignore rule for local addon secret config in `.gitignore`.

Decisions:
- Import all useful content first, then integrate runtime systems in controlled slices.
- Do not commit real API keys or local secret config files.

Open questions:
- Which imported addon/plugin folders should remain part of the game repo versus dev-only tooling?

Next concrete step:
- Validate imported runtime scripts in-editor and integrate new systems one at a time (Chronicle/Sacred/Fragmentation path).

Files touched:
- .gitignore
- autoloads/ChronicleLog.gd
- scripts/kernel/history_compressor.gd
- scripts/kernel/settlement_persistence.gd
- addons/godotassistant/config.example.cfg
- docs/SESSION_LOG.md

---

## 2026-04-25 - Settlement style expression pass

Date: 2026-04-25
Agent/Model: Codex (Cursor)
Goal: Advance Phase 4 identity target with deeper non-text settlement expression.

Changes made:
- Added public culture helpers to `autoloads/SettlementPlanner.gd` (`get_culture_type_for_settlement`, `get_culture_name_for_settlement`, `get_culture_audio_bias_for_settlement`).
- Wired settlement style into ambient generation in `scenes/main/Main.gd` with subtle deterministic bias (open vs defensive tonal shift).
- Added `docs/WORLD_BIBLE/GAME_VISION.md` to preserve long-horizon design direction.

Decisions:
- Keep expression subtle and non-intrusive (no text overlays, no gameplay stat changes).
- Derive style strictly from existing deterministic settlement data.

Open questions:
- Should style also influence architectural material palettes (future visual pass) or remain behavior/audio only?

Next concrete step:
- Add deterministic architectural palette/rule variants per style (open/cautious/defensive) beyond current placement order differences.

Files touched:
- autoloads/SettlementPlanner.gd
- autoloads/SettlementMemory.gd
- scenes/main/Main.gd
- docs/WORLD_BIBLE/GAME_VISION.md
- docs/WORLD_BIBLE/MASTER_INDEX.md
- docs/SESSION_LOG.md

---

## 2026-04-25 - Cross-LLM continuity baseline

Date: 2026-04-25
Agent/Model: Codex (Cursor)
Goal: Stop rebuild loops and establish stable memory/canon workflow.

Changes made:
- Expanded `docs/LLM_ONBOARDING.md` with free-forever stack and required session workflow.
- Created `docs/WORLD_BIBLE/` with index, timeline, regions, factions, characters, glossary, and canon changelog.
- Updated `README.md` to point to continuity docs.

Decisions:
- Repo files are the memory system; chat threads are temporary.
- Canon changes must be tracked explicitly.

Open questions:
- Which first culture/architecture style should be treated as canonical seed?

Next concrete step:
- Implement first cultural architecture pass in code and mirror outcomes in world bible files.

Files touched:
- README.md
- docs/LLM_ONBOARDING.md
- docs/SESSION_LOG.md
- docs/WORLD_BIBLE/*

---

## SESSION TEMPLATE

Date:
Agent/Model:
Goal:

Changes made:
- 

Decisions:
- 

Open questions:
- 

Next concrete step:
- 

Files touched:
- 
