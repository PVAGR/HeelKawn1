# SpatialManager Architecture Guide

## Overview
The **SpatialManager** is the "Nerves" system for HeelKawn's infinite world. It partitions the world into **32×32 tile chunks** and tracks which chunks are "active" (contain entities). Pawns in inactive chunks skip their tick loop entirely (spatial sleep), reducing CPU cost by orders of magnitude in large worlds.

---

## Core Concepts

### Chunk System
- **Chunk Size**: 32×32 tiles (1,024 tiles per chunk)
- **Storage**: Dictionary mapping `Vector2i(chunk_x, chunk_y)` → `ChunkData`
- **Memory Model**: Chunks are created on-demand and cleaned up when empty

### Active Chunks
A chunk is **active** if:
1. It contains at least one Pawn, Settlement, or active Job, OR
2. It is within **WAKE_RADIUS_CHUNKS (2)** of a chunk that contains entities

### Wake Radius
- Pawns within 2 chunks of activity will "wake up" automatically
- This prevents harsh frame-rate stutters when activity moves to nearby areas
- Tunable: adjust `WAKE_RADIUS_CHUNKS` constant to trade responsiveness vs CPU savings

---

## Key Methods

### Entity Registration
```gdscript
register_entity(entity_id: int, entity_type: String, world_pos: Vector2i) -> void
```
- Called when a Pawn spawns, a Job posts, or a Settlement forms
- Moves entity from old chunk to new chunk if it moves
- Marks chunk as active

### Entity Unregistration
```gdscript
unregister_entity(entity_id: int) -> void
```
- Called when a Pawn dies, Job completes, or Settlement abandons
- Removes entity from chunk
- Marks chunk inactive if now empty

### Chunk Activity Check
```gdscript
is_chunk_active(chunk_coord: Vector2i) -> bool
```
- Returns `true` if chunk has entities or is near active chunks
- Used by Pawn._on_game_tick() to gate tick execution

### Position Sync
```gdscript
update_pawn_position(pawn_id: int, new_tile_pos: Vector2i) -> void
```
- Call every N ticks to sync Pawn chunk registration after movement
- Only updates if Pawn actually crossed chunk boundary

### Bulk Syncs
```gdscript
sync_all_job_chunks() -> void
sync_all_settlement_chunks() -> void
```
- Called from JobManager and SettlementMemory tick hooks
- Rebuilds job/settlement spatial index each tick

---

## Pawn Integration

### 1. **Spatial Culling Gate** (in `_on_game_tick`)
```gdscript
if SpatialManager != null:
    var pawn_chunk: Vector2i = SpatialManager.tile_to_chunk(data.tile_pos)
    var chunk_is_active: bool = SpatialManager.is_chunk_active(pawn_chunk)
    
    if not chunk_is_active:
        # Skip entire tick loop (spatial sleep)
        if not _spatial_sleeping:
            _spatial_sleeping = true
            print("[Spatial] Chunk (%d,%d) sleeping — pawn #%d" % ...)
        return
```

### 2. **Spatial Registration** (in `bind()`)
```gdscript
if SpatialManager != null and data != null:
    SpatialManager.register_entity(int(data.id), "pawn", data.tile_pos)
```

### 3. **Spatial Unregistration** (in `_exit_tree()`)
```gdscript
if SpatialManager != null and data != null:
    SpatialManager.unregister_entity(int(data.id))
```

### 4. **Position Syncing** (in `_on_game_tick` at 8-tick intervals)
```gdscript
if posmod(GameManager.tick_count + pid, 8) == 0:
    if SpatialManager != null and data != null:
        SpatialManager.update_pawn_position(int(data.id), data.tile_pos)
```

---

## Debug & Telemetry

### Enable Debug Logging
```gdscript
SpatialManager.set_debug_enabled(true)
```

### Debug Output Format
```
[Spatial] Chunk (x,y) waking up — registered pawn #id
[Spatial] Chunk (x,y) sleeping — now empty
[Spatial] Cleaned up N empty chunks
```

### Get Performance Stats
```gdscript
var stats: Dictionary = SpatialManager.get_stats()
# {
#   "total_chunks": 523,
#   "active_chunks": 18,
#   "total_pawns": 147,
#   "total_jobs": 892,
#   "total_settlements": 3,
#   "chunk_size": 32,
# }
```

---

## Performance Expectations

### CPU Savings
- **Baseline**: Full tick for every Pawn, every frame
- **With SpatialManager**: Only Pawns in active chunks run their AI
- **Scaling**: At 10×10 chunks active (100 chunks), with ~50 pawns total, expect **~8-15× CPU reduction** for distant areas

### Memory Overhead
- **Per Chunk**: ~200 bytes (Vector2i + small arrays + metadata)
- **Per Active Chunk**: varies with entity count, typically <1KB
- **Total System**: minimal (<10MB for 1000+ chunks)

### Chunk Boundary Crossings
- Pawn moving between chunks causes re-registration (~microseconds)
- Staggered every 8 ticks per pawn to smooth out batch updates
- No gameplay impact (Pawn state retained)

---

## Integration Checklist

- [ ] SpatialManager.gd created and in autoloads/
- [ ] Pawn.gd: Add `_spatial_sleeping` state variable
- [ ] Pawn.gd: Insert culling gate in `_on_game_tick()` (right after guards)
- [ ] Pawn.gd: Register entity in `bind()`
- [ ] Pawn.gd: Unregister entity in `_exit_tree()`
- [ ] Pawn.gd: Add position sync call (8-tick cadence)
- [ ] JobManager: Call `SpatialManager.sync_all_job_chunks()` on job mutation
- [ ] SettlementMemory: Call `SpatialManager.sync_all_settlement_chunks()` on settlement update
- [ ] Main.gd: Call `SpatialManager.clear()` on save load
- [ ] Test: Run game with SpatialManager.set_debug_enabled(true) and observe chunk wake/sleep events

---

## Future Enhancements

1. **Chunk Preloading**: Load chunks ahead of pawn movement to smooth transitions
2. **Priority Queueing**: Sort job scans to prioritize active chunks first
3. **Visibility Culling**: Extend to rendering (skip draw calls for inactive chunks)
4. **Nested Chunks**: Multi-level hierarchy (256×256 super-chunks containing 32×32 chunks)
5. **Async Pathfinding**: Run pathfinding for distant chunks on a separate tick cadence
6. **Persistent Chunk State**: Save/restore chunk activity snapshots for determinism

---

## Thread Safety & Determinism

- **Single-Threaded**: Current design assumes Godot's single-threaded game loop
- **Deterministic**: Chunk activation is frame-independent; depends only on entity positions
- **Save/Load Safe**: `SpatialManager.clear()` resets state; pawns re-register on bind()

---

## Debug Commands (for console/testing)

```gdscript
# Get stats
print(SpatialManager.get_stats())

# Enable debug logging
SpatialManager.set_debug_enabled(true)

# Get specific chunk info
var info = SpatialManager.get_chunk_info(Vector2i(0, 0))
print(info)

# Get all active chunks
var active = SpatialManager.get_active_chunks()
print("Active chunks: %s" % [active.size()])
```

---

## Testing Strategy

1. **Unit Test**: Spawn 10 pawns, move them between chunks, verify wake/sleep logs
2. **Integration Test**: Run with full settlement + job system active
3. **Stress Test**: Generate 100+ pawns across 20 chunks, measure frame time delta
4. **Edge Cases**: 
   - Pawn at chunk boundary
   - Rapid chunk crossings (fast movement)
   - Job completion near chunk edge
   - Settlement formation at chunk center

---

## References
- Region system: `WorldMemory._region_key()`
- Job system: `JobManager.get_active_jobs_union()`
- Settlement system: `SettlementMemory.get_settlements()`
- Pawn movement: `Pawn.data.tile_pos` (updated per tick)
