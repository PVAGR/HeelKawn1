# Architecture Decisions

## T006 — Spatial Manager Integration

### Objective
Integrate `SpatialManager` with key simulation systems (`TickManager`, `SettlementPlanner`, `PawnSpawner`) to enable spatial culling and optimize performance for inactive areas of the world. Ensure all integrations respect the deterministic kernel and existing coding patterns.

### SpatialManager API (Relevant for Integration)
- `tile_to_chunk(tile_pos: Vector2i) -> Vector2i`: Converts a world tile coordinate to a chunk coordinate.
- `register_entity(entity_id: int, entity_type: String, world_pos: Vector2i)`: Registers an entity (pawn, settlement, job) in the spatial grid at its world position. Marks the chunk as active.
- `unregister_entity(entity_id: int)`: Removes an entity from the spatial grid. If the chunk becomes empty and has no active neighbors within `WAKE_RADIUS_CHUNKS`, it may become inactive.
- `update_pawn_position(pawn_id: int, new_tile_pos: Vector2i)`: Optimizes pawn position updates by only re-registering if the pawn has moved to a new chunk.
- `is_chunk_active(chunk_coord: Vector2i) -> bool`: Returns `true` if the chunk contains entities or is within the `WAKE_RADIUS_CHUNKS` of an active chunk. This is the primary API for culling decisions.
- `sync_all_job_chunks()`: Re-registers all active jobs with their current positions. Called periodically by `JobManager`.
- `sync_all_settlement_chunks()`: Re-registers all settlements with their current center region positions. Called periodically by `SettlementMemory`.

### Integration Details

#### 1. TickManager Integration
- **SpatialManager Modification**: `SpatialManager` will now connect to `TickManager.tick_processed` instead of `GameManager.game_tick` for its periodic cleanup (`_on_game_tick`). This aligns `SpatialManager` with the central, deterministic tick system.
- **Dependency**: `SpatialManager` will add `@onready var TickManager = get_node_or_null("/root/TickManager")`.
- **Reasoning**: Ensures `SpatialManager`'s internal periodic updates (like `_cleanup_empty_chunks`) are driven by the authoritative `TickManager`.

#### 2. SettlementPlanner Integration
- **SettlementPlanner Modification**: The `plan()` method in `SettlementPlanner` will add a check using `SpatialManager.is_chunk_active()` *before* detailed planning for a given settlement.
    - It will get the `center_region` of the settlement, convert it to a tile, then to a chunk coordinate.
    - If `SpatialManager.is_chunk_active()` returns `false` for that chunk, the planner will skip that settlement for the current planning pass.
- **Dependency**: `SettlementPlanner` will add `@onready var SpatialManager = get_node_or_null("/root/SpatialManager")`.
- **Reasoning**: Prevents `SettlementPlanner` from spending CPU cycles generating build intents for settlements in areas of the world that are currently inactive and not being simulated in detail. This provides spatial culling for planning.

#### 3. PawnSpawner Integration
- **PawnSpawner Modification**:
    - Upon spawning a new pawn, `PawnSpawner` will call `SpatialManager.register_entity(pawn_id, "pawn", pawn_initial_tile_pos)`. This includes `spawn_starters`, `spawn_generational_pawn`, `spawn_pawn`, `spawn_from_data`, and `spawn_child_pawn`.
    - Upon a pawn's death or removal, `PawnSpawner` will call `SpatialManager.unregister_entity(pawn_id)`. This includes `remove_pawn` and `clear_pawns`.
- **Pawn.gd Modification**:
    - In the `bind` method, `Pawn` will register itself with `SpatialManager`.
    - In the `_exit_tree` method, `Pawn` will unregister itself from `SpatialManager`.
    - In the `_process` method, `Pawn` will call `SpatialManager.update_pawn_position(self.id, self.data.tile_pos)` if its tile position has changed, ensuring the spatial grid is kept up-to-date.
    - In the `_die` method, `Pawn` will unregister itself from `SpatialManager`.
- **Dependency**: `PawnSpawner` and `Pawn` will add `@onready var SpatialManager = get_node_or_null("/root/SpatialManager")`.
- **Reasoning**: Ensures pawns are accurately tracked within the spatial grid, allowing `SpatialManager` to correctly determine active chunks and potentially cull pawn AI ticks in inactive areas.

### Determinism Check
All integrations rely on existing deterministic APIs (`tile_to_chunk`, `is_chunk_active` derived from entity positions, `TickManager`'s tick count). No new unseeded RNG is introduced. State changes are driven by the deterministic tick.

### Compile Check
`powershell -ExecutionPolicy Bypass -File "tools/ai/verify-compile.ps1"` will be run after all code changes.
````

````gdscript
autoloads/SpatialManager.gd
<<<<<<< SEARCH
@onready var JobManager = get_node_or_null("/root/JobManager")
@onready var SettlementMemory = get_node_or_null("/root/SettlementMemory")

## Chunk size in tiles (32x32 = 1024 tiles per chunk)
const CHUNK_SIZE: int = 32
