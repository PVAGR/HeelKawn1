# SpatialManager Implementation Guide

## Quick Start: Step-by-Step Integration

### Step 1: Add SpatialManager to Autoload
**Status**: ✅ DONE — SpatialManager.gd is created in `autoloads/`

### Step 2: Add State Variable to Pawn.gd
**File**: `scripts/pawn/Pawn.gd`  
**Location**: Near the top with other state variables (around line 300–400)

```gdscript
## Spatial culling: true if this pawn is in an inactive chunk
var _spatial_sleeping: bool = false
```

---

### Step 3: Add Spatial Culling Gate to Pawn._on_game_tick()
**File**: `scripts/pawn/Pawn.gd`  
**Location**: In `_on_game_tick()` right after the existing guards (after line 1334)

**Before** (current code at line 1324):
```gdscript
func _on_game_tick(_tick: int) -> void:
	# Hard guard: no sim until bind + _ready + deferred connect completed.
	if not is_instance_valid(self):
		return
	if not _pawn_sim_tick_armed:
		return
	if data == null:
		push_warning("Pawn: game_tick skipped - data not ready (path=%s)" % str(get_path()))
		return
	var pid: int = int(data.id)
	# ... continues with _hit_flash_ticks and rest of logic
```

**After** (add spatial gate):
```gdscript
func _on_game_tick(_tick: int) -> void:
	# Hard guard: no sim until bind + _ready + deferred connect completed.
	if not is_instance_valid(self):
		return
	if not _pawn_sim_tick_armed:
		return
	if data == null:
		push_warning("Pawn: game_tick skipped - data not ready (path=%s)" % str(get_path()))
		return
	
	# ========== SPATIAL CULLING GATE ==========
	var SpatialManager = get_node_or_null("/root/SpatialManager")
	if SpatialManager != null:
		var pawn_chunk: Vector2i = SpatialManager.tile_to_chunk(data.tile_pos)
		var chunk_is_active: bool = SpatialManager.is_chunk_active(pawn_chunk)
		
		if not chunk_is_active:
			if not _spatial_sleeping:
				_spatial_sleeping = true
				if GameManager.verbose_logs():
					print("[Spatial] Chunk (%d,%d) sleeping — pawn #%d (%s)" % [
						pawn_chunk.x, pawn_chunk.y, int(data.id), data.display_name
					])
			return
		else:
			if _spatial_sleeping:
				_spatial_sleeping = false
				if GameManager.verbose_logs():
					print("[Spatial] Chunk (%d,%d) waking up — pawn #%d (%s)" % [
						pawn_chunk.x, pawn_chunk.y, int(data.id), data.display_name
					])
	# ========== END SPATIAL CULLING GATE ==========
	
	var pid: int = int(data.id)
	# ... rest of existing code unchanged
```

---

### Step 4: Register Pawn in SpatialManager on Spawn
**File**: `scripts/pawn/Pawn.gd`  
**Location**: In `bind()` method (around line 770)

**Add this after the PawnData registration**:
```gdscript
func bind(p_data: PawnData, world_pos: Vector2, world: World) -> void:
	data = p_data
	# Register pawn data for global lookups (lineage, parent lookup)
	PawnData.register_pawn_data(data)
	
	# ========== SPATIAL REGISTRATION ==========
	var SpatialManager = get_node_or_null("/root/SpatialManager")
	if SpatialManager != null and data != null:
		SpatialManager.register_entity(int(data.id), "pawn", data.tile_pos)
	# ========== END SPATIAL REGISTRATION ==========
	
	_reset_behavior_profile()
	_world = world
	# ... rest of bind() unchanged
```

---

### Step 5: Unregister Pawn on Death/Removal
**File**: `scripts/pawn/Pawn.gd`  
**Location**: In `_exit_tree()` method (around line 880)

**Add this before/after PawnData unregister**:
```gdscript
func _exit_tree() -> void:
	_pawn_sim_tick_armed = false
	if GameManager != null and GameManager.game_tick.is_connected(_on_game_tick):
		GameManager.game_tick.disconnect(_on_game_tick)
	# Unregister pawn data so static registry stays accurate
	if data != null:
		PawnData.unregister_pawn_data(int(data.id))
	
	# ========== SPATIAL UNREGISTRATION ==========
	var SpatialManager = get_node_or_null("/root/SpatialManager")
	if SpatialManager != null and data != null:
		SpatialManager.unregister_entity(int(data.id))
	# ========== END SPATIAL UNREGISTRATION ==========
```

---

### Step 6: Add Position Sync to _on_game_tick()
**File**: `scripts/pawn/Pawn.gd`  
**Location**: In `_on_game_tick()` (around line 1350, after needs/threshold checks)

**Add this periodic update**:
```gdscript
	# Stagger needs/threshold upkeep by pawn id so not every pawn runs this
	# bookkeeping on the same sim tick.
	if posmod(GameManager.tick_count + pid, 5) == 0:
		if _trace_ai_slice:
			CrashTrap.enter_system("pawn_tick:%d:needs" % pid)
		_decay_needs()
		_check_thresholds()
		if _trace_ai_slice:
			CrashTrap.exit_system("pawn_tick:%d:needs" % pid)
	
	# ========== SPATIAL POSITION UPDATE ==========
	if posmod(GameManager.tick_count + pid, 8) == 0:
		var SpatialManager = get_node_or_null("/root/SpatialManager")
		if SpatialManager != null and data != null:
			SpatialManager.update_pawn_position(int(data.id), data.tile_pos)
	# ========== END SPATIAL POSITION UPDATE ==========
```

---

### Step 7: Register Jobs with SpatialManager
**File**: `autoloads/JobManager.gd`  
**Location**: In the `_on_game_tick()` method (add at end of tick)

```gdscript
func _on_game_tick(tick: int) -> void:
	# ... existing job management logic ...
	
	# ========== SPATIAL SYNC: JOBS ==========
	var SpatialManager = get_node_or_null("/root/SpatialManager")
	if SpatialManager != null:
		SpatialManager.sync_all_job_chunks()
	# ========== END SPATIAL SYNC: JOBS ==========
```

---

### Step 8: Register Settlements with SpatialManager
**File**: `autoloads/SettlementMemory.gd`  
**Location**: After settlement updates (in `recompute()` or similar)

```gdscript
	# After settlement recompute/update logic
	var SpatialManager = get_node_or_null("/root/SpatialManager")
	if SpatialManager != null:
		SpatialManager.sync_all_settlement_chunks()
```

---

### Step 9: Clear SpatialManager on Save/Load
**File**: `scenes/main/Main.gd`  
**Location**: In `_apply_save_dict()` before/after clearing other systems

**Add after other clears**:
```gdscript
func _apply_save_dict(save_dict: Dictionary) -> void:
	JobManager.clear_all()
	if KinshipSystem != null and KinshipSystem.has_method("clear"):
		KinshipSystem.clear()
	if BloodlineSystem != null and BloodlineSystem.has_method("clear"):
		BloodlineSystem.clear()
	
	# ========== SPATIAL CLEAR ==========
	var SpatialManager = get_node_or_null("/root/SpatialManager")
	if SpatialManager != null and SpatialManager.has_method("clear"):
		SpatialManager.clear()
	# ========== END SPATIAL CLEAR ==========
	
	TradeMemory.clear()
	# ... rest of save restoration
```

---

## Testing Checklist

### Quick Test (5 minutes)
1. Enable debug logging: Add to a console command or debug panel
   ```gdscript
   SpatialManager.set_debug_enabled(true)
   ```
2. Spawn 5 pawns far apart
3. Watch console for `[Spatial] Chunk (x,y) waking up` messages
4. Move camera away → should see `[Spatial] Chunk (x,y) sleeping` logs
5. Move camera back → should see wake messages again

### Integration Test (20 minutes)
1. Run full colony simulation (10-20 pawns, 3-5 jobs, 1-2 settlements)
2. Enable spatial debug logging
3. Zoom out to see global view
4. Watch debug output confirm chunks activate/deactivate as camera moves
5. Measure frame time with and without SpatialManager enabled (compare via profiler)

### Performance Stress Test (30 minutes)
1. Create scenario with 100+ pawns spread across 50+ chunks
2. Run at 50x speed for 10,000+ ticks
3. Compare frame time:
   - **Without SpatialManager**: smooth at 1x, stutters at 50x+
   - **With SpatialManager**: smooth even at 100x (distant chunks sleep)
4. Use `SpatialManager.get_stats()` to verify active chunk count stays low

---

## Example: Minimal Test Scenario

```gdscript
# In a test script or console:

# 1. Get reference
var sm = get_node("/root/SpatialManager")

# 2. Enable logging
sm.set_debug_enabled(true)

# 3. Spawn a pawn
var spawner = get_tree().get_first_node_in_group("spawners") as PawnSpawner
# (spawner will call SpatialManager.register_entity automatically)

# 4. Check stats
print(sm.get_stats())
# Output:
# {
#   "total_chunks": 1,
#   "active_chunks": 1,
#   "total_pawns": 1,
#   "total_jobs": 0,
#   "total_settlements": 0,
#   "chunk_size": 32,
# }

# 5. Move pawn far away (manually teleport via editor or code)
# pawn.data.tile_pos = Vector2i(1000, 1000)
# sm.update_pawn_position(int(pawn.data.id), pawn.data.tile_pos)

# 6. Verify chunk changed
print(sm.get_stats())
# Output: Now shows a different chunk with the pawn

# 7. Turn off debug
sm.set_debug_enabled(false)
```

---

## Debugging: Common Issues

### Issue 1: "SpatialManager is null"
**Cause**: SpatialManager autoload not registered  
**Fix**: Add `SpatialManager` to `project.godot` autoloads list

### Issue 2: Pawns never wake up after chunk becomes active
**Cause**: Pawns not unregistering on death, orphaning chunks  
**Fix**: Ensure `_exit_tree()` calls `SpatialManager.unregister_entity()`

### Issue 3: High memory usage despite culling
**Cause**: Empty chunks not being cleaned up  
**Fix**: Ensure periodic cleanup runs; check `_cleanup_empty_chunks()` cadence

### Issue 4: Pawns stutter when crossing chunk boundaries
**Cause**: Position sync too frequent or expensive  
**Fix**: Increase stagger interval (current: 8 ticks); only sync on chunk change

---

## Performance Tuning Knobs

```gdscript
# In SpatialManager.gd:

## Chunk Size (tiles per dimension)
const CHUNK_SIZE: int = 32  # Smaller = more chunks, less sleep; larger = fewer chunks, more sleep

## Wake Radius (chunks around active areas)
const WAKE_RADIUS_CHUNKS: int = 2  # Smaller = responsive but less sleep; larger = less responsive but more sleep

## Cleanup Cadence (in _on_game_tick)
const CLEANUP_INTERVAL: int = 5000  # Run cleanup every N ticks
```

### Tuning Strategy
- **CPU-constrained (potato PC)**: Increase `CHUNK_SIZE` to 48–64, reduce `WAKE_RADIUS_CHUNKS` to 1
- **High-end (RTX 4090)**: Keep defaults, increase `WAKE_RADIUS_CHUNKS` to 3 for smoother transitions
- **Memory-constrained**: Increase cleanup frequency, reduce `WAKE_RADIUS_CHUNKS`

---

## Next Steps

1. **Implement all 9 steps above**
2. **Run quick test** to verify logging works
3. **Run integration test** with full colony
4. **Profile frame time** to measure CPU savings
5. **Document results** in SPATIAL_MANAGER_RESULTS.md
6. **Tune knobs** based on your performance targets
7. **Commit** when stable
