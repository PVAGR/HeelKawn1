# HeelKawn State Management

This document outlines the state management strategies for the HeelKawn simulation, ensuring that all systems operate deterministically and without random elements.

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

## Implementation

### WorldMemory
