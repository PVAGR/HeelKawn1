extends Node
## SpatialManager.gd — Chunk-based spatial partitioning for infinite world culling
## Tracks active chunks (containing Pawns, Settlements, or active Jobs)
## Pawns in inactive chunks skip their tick loop (sleep state) to reduce CPU cost

@onready var GameManager = get_node_or_null("/root/GameManager")
@onready var JobManager = get_node_or_null("/root/JobManager")
@onready var SettlementMemory = get_node_or_null("/root/SettlementMemory")

## Chunk size in tiles (32x32 = 1024 tiles per chunk)
const CHUNK_SIZE: int = 32

## Minimum distance threshold for "wake-up" notification (in chunks)
## Pawns within this radius of active zones will receive wake signals
const WAKE_RADIUS_CHUNKS: int = 2

## Chunk storage: Vector2i(chunk_x, chunk_y) -> ChunkData dictionary
var chunks: Dictionary = {}

## Entity to chunk mapping: entity_id -> Vector2i (chunk_coord)
var entity_chunks: Dictionary = {}

## Debug tracking: enable with set_debug_enabled(true)
var debug_enabled: bool = false


class ChunkData:
	var coord: Vector2i
	var pawns: Array[int] = []
	var settlements: Array[int] = []
	var jobs: Array[int] = []
	var last_activity_tick: int = 0
	var is_active: bool = false
	
	func _init(chunk_coord: Vector2i) -> void:
		coord = chunk_coord
		last_activity_tick = 0
		is_active = false
	
	func is_empty() -> bool:
		return pawns.is_empty() and settlements.is_empty() and jobs.is_empty()
	
	func entity_count() -> int:
		return pawns.size() + settlements.size() + jobs.size()


func _ready() -> void:
	# ARCHITECT T006: Connect to central TickManager for updates.
	# Retain GameManager connection for backwards compatibility / direct scene run if needed.
	if GameManager != null:
		GameManager.game_tick.connect(_on_game_tick)
	if TickManager != null:
		TickManager.tick_processed.connect(_on_game_tick)


func _on_game_tick(_tick: int) -> void:
	# Periodic chunk cleanup: remove empty chunks to prevent memory bloat
	if GameManager.periodic_phase_due(_tick, 5000, 1147):
		_cleanup_empty_chunks()


## Convert world tile position to chunk coordinate
func tile_to_chunk(tile_pos: Vector2i) -> Vector2i:
	return Vector2i(
		int(tile_pos.x) / CHUNK_SIZE,
		int(tile_pos.y) / CHUNK_SIZE
	)


## Convert chunk coordinate to world tile position (top-left corner)
func chunk_to_tile(chunk_coord: Vector2i) -> Vector2i:
	return chunk_coord * CHUNK_SIZE


## Get or create chunk data for a coordinate
func _get_or_create_chunk(chunk_coord: Vector2i) -> ChunkData:
	if not chunks.has(chunk_coord):
		chunks[chunk_coord] = ChunkData.new(chunk_coord)
	return chunks[chunk_coord]


## Register an entity (pawn, settlement, or job) at a world position
## entity_id: unique identifier (pawn.data.id, settlement center_region, or job.id)
## entity_type: "pawn", "settlement", or "job"
## world_pos: Vector2i tile position
func register_entity(entity_id: int, entity_type: String, world_pos: Vector2i) -> void:
	# Unregister from old chunk if already registered
	if entity_chunks.has(entity_id):
		_unregister_from_chunk(entity_id, entity_chunks[entity_id])
	
	var chunk_coord: Vector2i = tile_to_chunk(world_pos)
	var chunk: ChunkData = _get_or_create_chunk(chunk_coord)
	
	# Add to appropriate list based on entity type
	match entity_type:
		"pawn":
			if entity_id not in chunk.pawns:
				chunk.pawns.append(entity_id)
		"settlement":
			if entity_id not in chunk.settlements:
				chunk.settlements.append(entity_id)
		"job":
			if entity_id not in chunk.jobs:
				chunk.jobs.append(entity_id)
	
	entity_chunks[entity_id] = chunk_coord
	chunk.is_active = true
	chunk.last_activity_tick = GameManager.tick_count
	
	if debug_enabled:
		print("[Spatial] Chunk (%d,%d) waking up — registered %s #%d" % [
			chunk_coord.x, chunk_coord.y, entity_type, entity_id
		])


## Unregister an entity from all chunks (e.g., when a pawn dies or job completes)
func unregister_entity(entity_id: int) -> void:
	if entity_chunks.has(entity_id):
		var chunk_coord: Vector2i = entity_chunks[entity_id]
		_unregister_from_chunk(entity_id, chunk_coord)
		entity_chunks.erase(entity_id)


## Internal: remove entity from a specific chunk
func _unregister_from_chunk(entity_id: int, chunk_coord: Vector2i) -> void:
	if chunks.has(chunk_coord):
		var chunk: ChunkData = chunks[chunk_coord]
		
		if entity_id in chunk.pawns:
			chunk.pawns.erase(entity_id)
		if entity_id in chunk.settlements:
			chunk.settlements.erase(entity_id)
		if entity_id in chunk.jobs:
			chunk.jobs.erase(entity_id)
		
		# If chunk is now empty, mark it inactive (will be cleaned up later)
		if chunk.is_empty():
			chunk.is_active = false
			if debug_enabled:
				print("[Spatial] Chunk (%d,%d) sleeping — now empty" % [
					chunk_coord.x, chunk_coord.y
				])


## Check if a chunk is active (contains entities or is within wake radius of active chunk)
func is_chunk_active(chunk_coord: Vector2i) -> bool:
	if chunks.has(chunk_coord):
		var chunk: ChunkData = chunks[chunk_coord]
		if not chunk.is_empty():
			return true
	
	# Check if any neighboring chunk within WAKE_RADIUS_CHUNKS has entities
	for dx in range(-WAKE_RADIUS_CHUNKS, WAKE_RADIUS_CHUNKS + 1):
		for dy in range(-WAKE_RADIUS_CHUNKS, WAKE_RADIUS_CHUNKS + 1):
			if dx == 0 and dy == 0:
				continue
			var neighbor: Vector2i = chunk_coord + Vector2i(dx, dy)
			if chunks.has(neighbor):
				var neighbor_chunk: ChunkData = chunks[neighbor]
				if not neighbor_chunk.is_empty():
					return true
	
	return false


## Get all active chunks (for debug visualization or broad queries)
func get_active_chunks() -> Array[Vector2i]:
	var active: Array[Vector2i] = []
	for coord in chunks.keys():
		var chunk: ChunkData = chunks[coord]
		if not chunk.is_empty():
			active.append(coord)
	return active


## Get chunk data for inspection (returns a copy for safety)
func get_chunk_info(chunk_coord: Vector2i) -> Dictionary:
	if not chunks.has(chunk_coord):
		return {}
	
	var chunk: ChunkData = chunks[chunk_coord]
	return {
		"coord": chunk.coord,
		"pawn_count": chunk.pawns.size(),
		"settlement_count": chunk.settlements.size(),
		"job_count": chunk.jobs.size(),
		"is_active": chunk.is_active,
		"last_activity_tick": chunk.last_activity_tick,
		"total_entities": chunk.entity_count(),
	}


## Sync a pawn's chunk registration when it moves
## Call this from Pawn._on_game_tick or whenever tile_pos changes significantly
func update_pawn_position(pawn_id: int, new_tile_pos: Vector2i) -> void:
	if entity_chunks.has(pawn_id):
		var old_chunk: Vector2i = entity_chunks[pawn_id]
		var new_chunk: Vector2i = tile_to_chunk(new_tile_pos)
		
		# Only update if chunk actually changed (avoid thrashing on movement within chunk)
		if old_chunk != new_chunk:
			_unregister_from_chunk(pawn_id, old_chunk)
			register_entity(pawn_id, "pawn", new_tile_pos)
	else:
		# Fallback: register if not already tracked
		register_entity(pawn_id, "pawn", new_tile_pos)


## Update all active jobs in the spatial grid (called from JobManager tick)
func sync_all_job_chunks() -> void:
	if JobManager == null:
		return
	
	var active_jobs: Array[Job] = JobManager.get_active_jobs_union()
	
	# First, unregister all current job entries (they may have moved or been completed)
	var old_job_ids: Array[int] = []
	for entity_id in entity_chunks.keys():
		var chunk_coord: Vector2i = entity_chunks[entity_id]
		if chunks.has(chunk_coord):
			var chunk: ChunkData = chunks[chunk_coord]
			if entity_id in chunk.jobs:
				old_job_ids.append(entity_id)
	
	for job_id in old_job_ids:
		unregister_entity(job_id)
	
	# Re-register all active jobs at their current tile
	for job_any in active_jobs:
		var job: Job = job_any as Job
		if job == null:
			continue
		register_entity(int(job.id), "job", job.tile)


## Update all settlements in the spatial grid
func sync_all_settlement_chunks() -> void:
	if SettlementMemory == null:
		return
	
	var settlements: Array = SettlementMemory.get_settlements()
	
	# Unregister old settlements
	var old_settlement_ids: Array[int] = []
	for entity_id in entity_chunks.keys():
		var chunk_coord: Vector2i = entity_chunks[entity_id]
		if chunks.has(chunk_coord):
			var chunk: ChunkData = chunks[chunk_coord]
			if entity_id in chunk.settlements:
				old_settlement_ids.append(entity_id)
	
	for settlement_id in old_settlement_ids:
		unregister_entity(settlement_id)
	
	# Re-register all settlements at their center region
	for settlement_any in settlements:
		var settlement: Dictionary = settlement_any as Dictionary
		if settlement == null:
			continue
		
		var center_region: int = int(settlement.get("center_region", -1))
		if center_region < 0:
			continue
		
		# Convert region key to tile coordinate (center of region)
		# Region key: (rx & 0xFFFF) | ((ry & 0xFFFF) << 16)
		var rx: int = center_region & 0xFFFF
		var ry: int = (center_region >> 16) & 0xFFFF
		
		# Sign-extend if needed (for negative regions in sign-magnitude representation)
		if rx & 0x8000:
			rx = -(0x10000 - rx)
		if ry & 0x8000:
			ry = -(0x10000 - ry)
		
		# Tile at center of 16x16 region (each region is 16 tiles)
		var settlement_tile: Vector2i = Vector2i(rx * 16 + 8, ry * 16 + 8)
		register_entity(center_region, "settlement", settlement_tile)


## Internal cleanup: remove empty chunks to prevent unbounded memory growth
func _cleanup_empty_chunks() -> void:
	var empty_chunks: Array[Vector2i] = []
	
	for coord in chunks.keys():
		var chunk: ChunkData = chunks[coord]
		if chunk.is_empty():
			empty_chunks.append(coord)
	
	for coord in empty_chunks:
		chunks.erase(coord)
	
	if debug_enabled and not empty_chunks.is_empty():
		print("[Spatial] Cleaned up %d empty chunks" % empty_chunks.size())


## Enable/disable debug logging
func set_debug_enabled(enabled: bool) -> void:
	debug_enabled = enabled


## Get total stats (for HUD or diagnostics)
func get_stats() -> Dictionary:
	var active_chunks: int = 0
	var total_pawns: int = 0
	var total_jobs: int = 0
	var total_settlements: int = 0
	
	for chunk_any in chunks.values():
		var chunk: ChunkData = chunk_any as ChunkData
		if not chunk.is_empty():
			active_chunks += 1
		total_pawns += chunk.pawns.size()
		total_jobs += chunk.jobs.size()
		total_settlements += chunk.settlements.size()
	
	return {
		"total_chunks": chunks.size(),
		"active_chunks": active_chunks,
		"total_pawns": total_pawns,
		"total_jobs": total_jobs,
		"total_settlements": total_settlements,
		"chunk_size": CHUNK_SIZE,
	}


## Performance profile for debug HUDs: emphasizes how much of the grid is still active.
func get_performance_profile() -> Dictionary:
	var stats: Dictionary = get_stats()
	var total_chunks: int = int(stats.get("total_chunks", 0))
	var active_chunks: int = int(stats.get("active_chunks", 0))
	var dormant_chunks: int = maxi(0, total_chunks - active_chunks)
	var active_ratio: float = 0.0
	if total_chunks > 0:
		active_ratio = float(active_chunks) / float(total_chunks)
	stats["dormant_chunks"] = dormant_chunks
	stats["active_ratio"] = active_ratio
	stats["culled_ratio"] = 1.0 - active_ratio if total_chunks > 0 else 0.0
	stats["wake_radius_chunks"] = WAKE_RADIUS_CHUNKS
	return stats


## Clear all spatial data (e.g., on new save/load)
func clear() -> void:
	chunks.clear()
	entity_chunks.clear()
