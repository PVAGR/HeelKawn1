# HeelKawn State Management

**⚠️ IMPORTANT:** HeelKawn is **NEVER FINISHED**. It is a living, evolving simulation.
We are always building, always refining, always expanding. This document captures the
**CURRENT STATE** of an ongoing creative journey.

**Last Updated:** May 22, 2026
**Current Phase:** Consolidation + Phase 5A indefinite evolution foundation
**Overall Status:** Deep playable prototype with a stable kernel; not yet a final release candidate

**Read first:** [HEELKAWN_PROJECT_COMPASS.md](HEELKAWN_PROJECT_COMPASS.md) and [HEELKAWN_BLUEPRINT.md](HEELKAWN_BLUEPRINT.md) and [HEELKAWN_STATE.md](HEELKAWN_STATE.md) (this file)

---

## AI AGENT CROSS-REFERENCE

**Read order for AI agents (handoff sequence):**
1. `AI_README.md` — Core philosophy, kernel rules, forbidden patterns
2. `HEELKAWN.txt` — Quick-context orientation
3. **`docs/HEELKAWN_STATE.md`** — THIS FILE. Authoritative current status
4. `docs/BUILD_INVENTORY.md` — Honest built-vs-missing inventory
5. `docs/HEELKAWN_PROJECT_COMPASS.md` — Orientation compass
6. `docs/HEELKAWN_BLUEPRINT.md` — Full PSUni blueprint

**Related docs (always refer to for canon/system context):**
- `docs/WORLD_BIBLE/CANON_SYSTEMS_FEATURE_QUEUE.md` — Canon execution queue
- `docs/WORLD_BIBLE/MASTER_INDEX.md` — World bible master index
- `docs/WORLD_BIBLE/GLOSSARY.md` — Canon glossary with implementation anchors
- `.cursor/rules/heelkawn-canonical-repo.mdc` — Canonical repo policy
- `.cursor/rules/heelkawn-handoff.mdc` — Handoff read order (enforced by cursor rules)

**Truth hierarchy (when docs conflict):**
1. Source code and Godot runtime checks (highest truth)
2. `docs/BUILD_INVENTORY.md` — Built-vs-missing inventory
3. `docs/HEELKAWN_STATE.md` — This file (current working state)
4. `docs/HEELKAWN_PROJECT_COMPASS.md` — Project compass
5. `AI_README.md` — Kernel philosophy (non-negotiable)
6. Historical docs / AI session notes — Evidence, not authority

---

## Current Status

- **Current Phase:** Consolidation + Phase 5A indefinite evolution foundation
- **Kernel Health:** 🟢 Stable enough for headless smoke
- **Compilation:** ✅ Headless Godot smoke passed on May 7, 2026 (re-run locally after May 19 construction/UI changes)
- **Project Shape:** Many live systems, some partial systems, and several design stubs
- **Truth Source:** Code/runtime first, then `BUILD_INVENTORY.md`, then this file
- Resolved Blockers:
  - Fixed Pawn parse errors that were cascading into job-system and UI dependency failures.
  - Verified `ProceduresPawnVisualizer` exists, exposes `class_name ProceduresPawnVisualizer`, and compiles cleanly.
  - Confirmed `Job.gd` and `JobManager.gd` compile cleanly after the Pawn dependency chain is restored.
  - Added the Phase 4 settlement lifecycle machine with active / abandoned / reviving / permanent ruin states.
  - Fixed profession lock bug (pawns were permanently locked into first profession, preventing role diversity).
  - Fixed event schema gap (FoodChainManager events now reach WorldMeaning via _infer_kind_from_type).
  - Relaxed neural bias speed gate from 50x to 200x so neural matrix contributes at normal play speeds.
  - Added profession reassignment so pawns can change roles when a non-primary skill outpaces their current profession.
  - Added colony role balance rules to dampen overrepresented professions.
  - Added infrastructure + security job posting to SettlementPlanner (fire pit, storage hut, protect, defend).
  - Added warrior peacetime patrol for visible perimeter presence.
  - Added display settings (resolution, window mode, vsync) to GameSettings.
  - Performance optimizations: spatial grid for social proximity, redraw throttle, meaning throttle, caches.
  - Added `TickBudgetManager.gd` as a shared 12ms simulation budget coordinator and throttled high-frequency debug logs in the main tick path.
  - **FEAT: Literature & Knowledge Preservation (Phase 5)**:
    - Implemented Book crafting recipes (Paper, Leather, Ink, Pen, Book) in `CraftingSystem.gd`.
    - Expanded `WorldMeaning.gd` with deterministic tags for literate regions (`great_library`, `scriptorium`, `literate`).
    - Integrated Literature recording into the `WorldMeaning` recompute pipeline.
    - Verified `KnowledgeSystem.gd` uses deterministic `WorldRNG` for rediscovery checks.
  - **FEAT: Civilization Stage Lens (Phase 5A initial live)**:
    - Added `CivilizationStage.gd` as a read-only autoload.
    - Derives era/stage from live technology, knowledge carriers, settlement infrastructure, profession diversity, and quality-of-life proxies.
    - Exposes F10 `03B · Civilization Stage` and adds era text to the HUD identity strip.
  - **FEAT: HeelKawnian Development Profiles (Phase 5A initial live)**:
    - Expanded `HeelKawnianIdentity.gd` into a memory-bearing identity resource with deterministic traits and profile history.
    - Expanded `HeelKawnianManager.gd` into a derived per-pawn development intelligence layer.
    - Each pawn profile now summarizes soul id, phase, drive, next need, era context, skills, knowledge, social signal, preservation pressure, and trauma pressure.
    - Exposes F10 `49 · HeelKawnians` for sample individual sprite profiles.
  - **FEAT: HeelKawnian Matrix AI Behavior Wiring (Phase 5A initial live)**:
    - `HeelKawnianManager.gd` now turns each pawn's derived profile into deterministic job priority biases.
    - `Pawn.gd` consumes those Matrix biases during normal `JobManager` claiming, so identity/memory/development drive nudges actual work without overriding job legality.
    - Strong Matrix-influenced job choices are logged back through `heelkawnian_development` events for auditability and replay-facing inspection.
    - F10 `49 · HeelKawnians` now prints top Matrix job pulls and rationale for sampled sprites.
  - **FEAT: AIAutoBuild need gates (May 19, 2026)**:
    - Shelter/storage intents now require `ColonySimServices` housing/storage/food pressure (same thresholds as `SettlementPlanner.can_post_build_intent`).
    - Reduces autonomous build spam before formal settlement pressures exist.
  - **FEAT: Matrix Social Intent Bridge + AutoBuild Job Wiring (Phase 5A extension)**:
    - `HeelKawnianManager.gd` now exposes deterministic social intent suggestions (`social_seek`, `teach_seek`, `grudge_confront`) based on trust/rapport, grudge intensity, reputation, proximity, and settlement.
    - `Pawn.gd` now checks the Matrix social intent layer during idle autonomy, including `teach_seek` handling that writes rapport/social/neural memory traces.
    - `JobManager.gd` now includes a `post_from_dict(...)` compatibility adapter so older dict-post callers can map into concrete `Job.Type` entries safely.
    - `AIAutoBuild.gd` now posts concrete build jobs via `JobManager.post(...)`, includes settlement-aware intent dedupe, and safely falls back when advanced settlement building queries are unavailable.
  - **FEAT: Matrix Settlement Ambition Seeding (Phase 5A extension)**:
    - `HeelKawnianManager.gd` now derives periodic local ambitions (hearth, storage, beds, walls/door, marker stone, food, tooling, teaching) from drive + local settlement feature pressure.
    - `Pawn.gd` now runs a throttled ambition seed hook in idle to inject one strategic job into `JobManager` without overriding normal job legality or claim flow.
    - Ambition seeding is throttled per pawn and per settlement region to avoid queue spam at high simulation speed.
    - Ambition posts are logged via `heelkawnian_development` as `matrix_settlement_ambition` for deterministic audit and replay tracing.
  - **FEAT: Mode Contract Enforcement (Watch / Sprite / Observer)**:
    - `WATCH` mode is now non-interactive with world command/edit input.
    - `INCARNATED` mode is embodied sprite play (not full-command mode).
    - `OBSERVER` mode is the sole full edit/command authority path.
    - Placement/command gates in `Main.gd` now enforce observer-only control for world editing and pawn command routing.
  - **FIX: Gentle onboarding runtime blocker**:
    - Replaced the bad `Label.bbcode_enabled` path with an attached `RichTextLabel` in `OnboardingSystem.gd`.
    - Updated visible language from tutorial rewards to first-body orientation.
    - Verified Godot headless smoke passes after the fix on May 7, 2026.
- **FEAT: Need-driven build gating (May 19, 2026)**:
  - `SettlementPlanner.gd`: `_build_pressure_ok`, per-settlement+type cooldown (`BUILD_INTENT_COOLDOWN_TICKS` = 1200), `can_post_build_intent` / `mark_build_intent_posted` gate bed, fire pit, storage hut, and farm planner posts from `ColonySimServices` pressure signals.
  - `AIAutoBuild.gd`: delegates to planner gating before creating intents and before posting jobs; uses `JobManager.post_build_deduped`.
  - `JobManager.gd`: `has_pending_build_near` and `post_build_deduped` for settlement-scoped construction dedupe.
- Next Task: deepen from first ambition seeding into true household membership logic, coordinated group plans, and longer-horizon settlement objective chains while continuing the v1 consolidation loop.

## May 22, 2026 Session Completion

- **FIX: Wire `post_build_deduped` into `Main._post_seeded_job`**:
  - Added `settlement_center` parameter to `_post_seeded_job()` for construction job deduplication
  - Construction jobs now check `JobManager._is_construction_type()` and use `post_build_deduped()` when settlement center is valid
  - Prevents duplicate construction postings near settlements during bootstrap phase

- **FEAT: ChronicleExport F10 Menu Integration**:
  - Added menu item #76: "Chronicle Export (to file)" to CreatorDebugMenu.gd
  - Added `_report_chronicle_export()` function that calls `ChronicleExport.export_chronicle()`
  - Players can now export chronicle history to file via F10 debug menu

- **DOCS: Updated tracking files**:
  - Updated TASKS.md, TODO.md, brain/memory/active_context.md, brain/memory/knowledge/tasks.md
  - Created brain/memory/sessions/2026-05-22.md session log

- **CLEANUP: Repository hygiene**:
  - Removed accidental `$null` file from root directory
  - Fixed `.gitignore` (removed duplicate `$null` entry)

## Blockers

- None currently reproducible in headless source validation.
- Documentation drift remains a project risk: older docs may overstate completion compared with `BUILD_INVENTORY.md`.
- Historical note: a `ProceduresPawnVisualizer` dependency failure was previously reported at `Pawn.gd:5785`; if it reappears, inspect `scripts/utils/ProceduresPawnVisualizer.gd` first, then the `Pawn.gd` call site.

## Action Plan

- Keep `ProceduresPawnVisualizer` as a compiled dependency unless a future regression proves it is the blocker.
- Keep the settlement lifecycle machine deterministic and centered on region bounds plus stockpile food thresholds.
- Continue kernel validation for deterministic, staggered pawn behavior.
- Treat "complete" as "compiles, runs, and has a verification path."
- Prioritize integration over expansion until the v1 foundation is trustworthy.

## Immediate Path

1. Runtime truth pass in Godot: verify F10 diagnostics, UI panels, and red errors.
2. HeelKawnian Matrix AI deepening: expand from job bias into teaching target selection, cooperation, recovery, household intent, and settlement ambitions.
3. Lineage/progression: finish parent lookup, child creation, inheritance hooks, and skill branches.
4. Material reality: connect crafting consumption to inventory/stockpile and tool requirements.
5. Knowledge preservation: unify stones, books, teaching, literacy, and rediscovery.
6. Civilization stage foundation: initial derived lens is live; deepen with per-settlement tech diffusion, literacy, lifespan, and institution data.
7. Readable exports: chronicle export and world seed/state export.

## Phase 4 Settlement Lifecycle

- Lifecycle labels now come from `SettlementMemory` as `active`, `abandoned`, `reviving`, and `permanent_ruin`.
- Revival trigger: a pawn entering the settlement bounds or local stockpile food rising above 10 units.
- Permanent ruin threshold: 60000 ticks spent empty and below the revival food threshold.
- Legacy settlement meaning states remain in place for compatibility, but the new lifecycle drives the region tint path.

## Core Principles

1. **Deterministic Kernel**: All operations must be deterministic based on input parameters and the current tick count.
2. **WorldRNG**: Use seeded streams from WorldRNG for any random-like behavior.
3. **Event-Driven State Changes**: Record all state changes as events in WorldMemory to ensure reproducibility.

## Key Components

### 1. WorldMemory

- **Purpose**: Stores all historical events and current state data.
- **Functions**:
  - `record_event(event: Dictionary)`: Records a single event.
  - `get_events_for_tile(target_pos: Vector2i)`: Retrieves events for a specific tile.

### 2. WorldMeaning

- **Purpose**: Manages the meaning and significance of events within the world.
- **Functions**:
  - `assign_meaning(event_id: int, meaning_type: String)`: Assigns a meaningful type to an event.
  - `get_meaning(event_id: int) -> String`: Retrieves the meaning of an event.

### 3. WorldPersistence

- **Purpose**: Handles saving and loading the world state.
- **Functions**:
  - `save_state() -> Dictionary`: Saves the current state as a dictionary.
  - `load_state(state_dict: Dictionary)`: Loads the state from a dictionary.

### 4. LandRecovery

- **Purpose**: Manages the recovery of land after events like abandonment or destruction.
- **Functions**:
  - `recover_land(event_id: int) -> bool`: Attempts to recover land affected by an event.
  - `is_recoverable(event_id: int) -> bool`: Checks if land can be recovered.

### 5. CulturalMemory

- **Purpose**: Stores and manages cultural knowledge and traditions.
- **Functions**:
  - `record_cultural_event(event_id: int, culture_type: String)`: Records a cultural event.
  - `get_cultural_events(culture_type: String) -> Array`: Retrieves cultural events of a specific type.

### 6. ProgressionSystem (KERNEL)

- **Purpose**: Tracks pawn significance through impact points earned from actions (building, teaching, etc.).
- **Phase**: Phase 5 - Emergent Life
- **Signal**: `progression_changed(pawn_id: int)` - emitted when a pawn gains impact.
- **Functions**:
  - `record_impact(pawn_id, amount, reason)`: Add impact points to a pawn.
  - `get_tier(pawn_id: int) -> int`: Get tier index (0-5).
  - `get_tier_name(pawn_id: int) -> String`: Get tier name.
  - `get_impact(pawn_id: int) -> int`: Get current impact points.
- **Tiers**:
  - Unknown: 0 impact
  - Known: 10 impact
  - Remembered: 50 impact
  - Noticed: 200 impact
  - Influential: 1000 impact
  - Legendary: 5000 impact
- **Integration**: PawnInfoPanel.gd reads live tier data; reacts to `progression_changed` signal.

## Implementation

### WorldMemory
