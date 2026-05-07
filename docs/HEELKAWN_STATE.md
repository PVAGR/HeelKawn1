# HeelKawn State Management

**⚠️ IMPORTANT:** HeelKawn is **NEVER FINISHED**. It is a living, evolving simulation.
We are always building, always refining, always expanding. This document captures the
**CURRENT STATE** of an ongoing creative journey.

**Last Updated:** May 7, 2026
**Current Phase:** Consolidation + Phase 5A indefinite evolution foundation
**Overall Status:** Deep playable prototype with a stable kernel; not yet a final release candidate

**Read first:** [HEELKAWN_PROJECT_COMPASS.md](HEELKAWN_PROJECT_COMPASS.md) and [HEELKAWN_BLUEPRINT.md](HEELKAWN_BLUEPRINT.md)

---

## Current Status

- **Current Phase:** Consolidation + Phase 5A indefinite evolution foundation
- **Kernel Health:** 🟢 Stable enough for headless smoke
- **Compilation:** ✅ Headless Godot smoke passed on May 7, 2026
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
  - **FIX: Gentle onboarding runtime blocker**:
    - Replaced the bad `Label.bbcode_enabled` path with an attached `RichTextLabel` in `OnboardingSystem.gd`.
    - Updated visible language from tutorial rewards to first-body orientation.
    - Verified Godot headless smoke passes after the fix on May 7, 2026.
- Next Task: Wire HeelKawnian development profiles into real pawn behavior while continuing the v1 consolidation loop.

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
2. HeelKawnian behavior wiring: let development profiles bias learn/teach/preserve/practice/innovate/recover choices.
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
