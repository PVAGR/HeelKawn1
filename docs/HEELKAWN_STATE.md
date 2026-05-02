# HeelKawn State Management

This document outlines the state management strategies for the HeelKawn simulation, ensuring that all systems operate deterministically and without random elements.

## Current Status

- Current Phase: Phase 4 - Identity & Meaning
- Kernel Health: 🟢
- Compilation: PASS
- Resolved Blockers:
  - Fixed Pawn parse errors that were cascading into job-system and UI dependency failures.
  - Verified `ProceduresPawnVisualizer` exists, exposes `class_name ProceduresPawnVisualizer`, and compiles cleanly.
  - Confirmed `Job.gd` and `JobManager.gd` compile cleanly after the Pawn dependency chain is restored.
  - Added the Phase 4 settlement lifecycle machine with active / abandoned / reviving / permanent ruin states.
- Next Task: Validate settlement lifecycle transitions in a full headless run.

## Blockers

- None currently reproducible in source validation.
- Historical note: a `ProceduresPawnVisualizer` dependency failure was previously reported at `Pawn.gd:5785`; if it reappears, inspect `scripts/utils/ProceduresPawnVisualizer.gd` first, then the `Pawn.gd` call site.

## Action Plan

- Keep `ProceduresPawnVisualizer` as a compiled dependency unless a future regression proves it is the blocker.
- Keep the settlement lifecycle machine deterministic and centered on region bounds plus stockpile food thresholds.
- Continue kernel validation for deterministic, staggered pawn behavior.

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
- **Phase**: Phase 4 - Identity & Meaning
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
