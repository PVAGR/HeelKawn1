## CODE BLOCK FOR INSERTION INTO Pawn.gd — _on_game_tick() method
## Insert at the VERY START of _on_game_tick(), right after the hard guards and before _hit_flash_ticks

## --- SPATIAL CULLING: Sleep inactive chunks ---
@onready var SpatialManager = get_node_or_null("/root/SpatialManager")

## Add this variable to Pawn class (near other state variables like _pawn_sim_tick_armed):
var _spatial_sleeping: bool = false

## Add this inside _on_game_tick(), right after the existing guards:
func _on_game_tick(_tick: int) -> void:
	# Hard guard: no sim until bind + _ready + deferred connect completed.
	if not is_instance_valid(self):
		return
	if not _pawn_sim_tick_armed:
		return
	if data == null:
		push_warning("Pawn: game_tick skipped - data not ready (path=%s)" % str(get_path()))
		return
	
	## ============ SPATIAL CULLING GATE (NEW) ============
	## Check if this pawn's current chunk is active.
	## If not, skip the entire tick loop (sleep mode) but retain all state.
	if SpatialManager != null:
		var pawn_chunk: Vector2i = SpatialManager.tile_to_chunk(data.tile_pos)
		var chunk_is_active: bool = SpatialManager.is_chunk_active(pawn_chunk)
		
		if not chunk_is_active:
			## Chunk inactive — skip this tick entirely (spatial sleep).
			if not _spatial_sleeping:
				_spatial_sleeping = true
				if GameManager.verbose_logs():
					print("[Spatial] Chunk (%d,%d) sleeping — pawn #%d (%s)" % [
						pawn_chunk.x, pawn_chunk.y, int(data.id), data.display_name
					])
			return
		else:
			## Chunk active — wake up if we were sleeping.
			if _spatial_sleeping:
				_spatial_sleeping = false
				if GameManager.verbose_logs():
					print("[Spatial] Chunk (%d,%d) waking up — pawn #%d (%s)" % [
						pawn_chunk.x, pawn_chunk.y, int(data.id), data.display_name
					])
	## ============ END SPATIAL CULLING GATE ============
	
	# Continue with the rest of _on_game_tick() as before...
	var pid: int = int(data.id)
	var _trace_ai_slice: bool = CrashTrap.should_trace_game_tick_dispatch(_tick)
	if _hit_flash_ticks > 0:
		_hit_flash_ticks -= 1
	
	# ... rest of existing code unchanged ...


## ALSO ADD THIS INSIDE the bind() method to register the pawn with SpatialManager:
func bind(p_data: PawnData, world_pos: Vector2, world: World) -> void:
	data = p_data
	# Register pawn data for global lookups (lineage, parent lookup)
	PawnData.register_pawn_data(data)
	_reset_behavior_profile()
	_world = world
	position = world_pos
	
	## ============ SPATIAL REGISTRATION (NEW) ============
	if SpatialManager != null and data != null:
		SpatialManager.register_entity(int(data.id), "pawn", data.tile_pos)
	## ============ END SPATIAL REGISTRATION ============
	
	_state = State.IDLE
	# ... rest of bind() as before ...


## ALSO ADD THIS INSIDE _exit_tree() to unregister the pawn:
func _exit_tree() -> void:
	_pawn_sim_tick_armed = false
	if GameManager != null and GameManager.game_tick.is_connected(_on_game_tick):
		GameManager.game_tick.disconnect(_on_game_tick)
	# Unregister pawn data so static registry stays accurate
	if data != null:
		PawnData.unregister_pawn_data(int(data.id))
	
	## ============ SPATIAL UNREGISTRATION (NEW) ============
	if SpatialManager != null and data != null:
		SpatialManager.unregister_entity(int(data.id))
	## ============ END SPATIAL UNREGISTRATION ============


## ALSO ADD THIS INSIDE the main movement/state change loop to keep chunk registration in sync:
## When a pawn moves to a new tile (typically in _process during HAULING/WALKING states):
## Add this periodic call to _on_game_tick() to sync position:
	if posmod(GameManager.tick_count + pid, 8) == 0:  # Every 8 ticks, staggered by pawn ID
		if SpatialManager != null and data != null:
			SpatialManager.update_pawn_position(int(data.id), data.tile_pos)
