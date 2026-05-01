extends Node
## Spatial Partitioning System for Infinite World Scaling
## Manages chunk-based entity culling to prevent performance degradation

const CHUNK_SIZE: int = 32  # 32x32 tiles per chunk
const ACTIVATION_RADIUS: int = 2  # Chunks within 2 of active area stay awake

## chunk_key (Vector2i) -> {entities: Array, last_active_tick: int, is_active: bool}
var _chunks: Dictionary = {}
## entity_id -> chunk_key
var _entity_chunk_map: Dictionary = {}
## settlement_id -> center_chunk_key
var _settlement_chunks: Dictionary = {}

var _cleanup_counter: int = 0
const CLEANUP_INTERVAL: int = 600  # Clean up empty chunks every 600 ticks

func _ready() -> void:
	pass

## === CORE API ===

func register_entity(entity_id: Variant, tile_pos: Vector2i, entity_type: String = "pawn") -> void:
	var chunk_key = _tile_to_chunk(tile_pos)
	
	if not _chunks.has(chunk_key):
		_chunks[chunk_key] = {
			"entities": [],
			"last_active_tick": GameManager.tick_count if GameManager else 0,
			"is_active": true
		}
	
	var chunk_data = _chunks[chunk_key] as Dictionary
	if entity_id not in chunk_data.entities:
		chunk_data.entities.append(entity_id)
	
	_entity_chunk_map[entity_id] = chunk_key
	_update_chunk_activity(chunk_key)

func unregister_entity(entity_id: Variant) -> void:
	if not _entity_chunk_map.has(entity_id):
		return
	
	var chunk_key = _entity_chunk_map[entity_id] as Vector2i
	_entity_chunk_map.erase(entity_id)
	
	if _chunks.has(chunk_key):
		var chunk_data = _chunks[chunk_key] as Dictionary
		chunk_data.entities.erase(entity_id)

func update_entity_position(entity_id: Variant, new_tile_pos: Vector2i) -> void:
	if not _entity_chunk_map.has(entity_id):
		register_entity(entity_id, new_tile_pos)
		return
	
	var old_chunk_key = _entity_chunk_map[entity_id] as Vector2i
	var new_chunk_key = _tile_to_chunk(new_tile_pos)
	
	if old_chunk_key != new_chunk_key:
		unregister_entity(entity_id)
		register_entity(entity_id, new_tile_pos)

func is_chunk_active(tile_pos: Vector2i) -> bool:
	var chunk_key = _tile_to_chunk(tile_pos)
	if not _chunks.has(chunk_key):
		return true  # Unregistered chunks are active by default
	
	var chunk_data = _chunks[chunk_key] as Dictionary
	return chunk_data.is_active

func should_entity_tick(entity_id: Variant) -> bool:
	if not _entity_chunk_map.has(entity_id):
		return true
	
	var chunk_key = _entity_chunk_map[entity_id] as Vector2i
	if not _chunks.has(chunk_key):
		return true
	
	var chunk_data = _chunks[chunk_key] as Dictionary
	return chunk_data.is_active

## === SETTLEMENT TRACKING ===

func register_settlement(settlement_id: int, center_tile: Vector2i) -> void:
	var chunk_key = _tile_to_chunk(center_tile)
	_settlement_chunks[settlement_id] = chunk_key
	_update_chunk_activity(chunk_key)

func unregister_settlement(settlement_id: int) -> void:
	_settlement_chunks.erase(settlement_id)

## === INTERNAL HELPERS ===

func _tile_to_chunk(tile_pos: Vector2i) -> Vector2i:
	return Vector2i(
		floori(float(tile_pos.x) / float(CHUNK_SIZE)),
		floori(float(tile_pos.y) / float(CHUNK_SIZE))
	)

func _update_chunk_activity(center_chunk: Vector2i) -> void:
	# Mark all chunks within activation radius as active
	for dx in range(-ACTIVATION_RADIUS, ACTIVATION_RADIUS + 1):
		for dy in range(-ACTIVATION_RADIUS, ACTIVATION_RADIUS + 1):
			var neighbor_key = Vector2i(center_chunk.x + dx, center_chunk.y + dy)
			if _chunks.has(neighbor_key):
				var chunk_data = _chunks[neighbor_key] as Dictionary
				chunk_data.is_active = true
				chunk_data.last_active_tick = GameManager.tick_count if GameManager else 0

func _tick(_delta: float) -> void:
	if GameManager == null:
		return
	
	_cleanup_counter += 1
	
	# Update chunk activity based on settlements
	for settlement_id in _settlement_chunks.keys():
		var center_chunk = _settlement_chunks[settlement_id] as Vector2i
		_update_chunk_activity(center_chunk)
	
	# Deactivate distant chunks after timeout
	var current_tick = GameManager.tick_count
	for chunk_key in _chunks.keys():
		var chunk_data = _chunks[chunk_key] as Dictionary
		
		# Skip if chunk has entities or is near settlement
		if not chunk_data.entities.is_empty():
			chunk_data.is_active = true
			continue
		
		var has_nearby_settlement = false
		for settlement_chunk in _settlement_chunks.values():
			if _chunk_distance(chunk_key, settlement_chunk) <= ACTIVATION_RADIUS:
				has_nearby_settlement = true
				break
		
		if has_nearby_settlement:
			chunk_data.is_active = true
			continue
		
		# Deactivate if inactive for too long
		if current_tick - chunk_data.last_active_tick > 300:
			chunk_data.is_active = false
	
	# Periodic cleanup of empty, inactive chunks
	if _cleanup_counter >= CLEANUP_INTERVAL:
		_cleanup_counter = 0
		_cleanup_empty_chunks()

func _chunk_distance(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))

func _cleanup_empty_chunks() -> void:
	var chunks_to_remove: Array = []
	
	for chunk_key in _chunks.keys():
		var chunk_data = _chunks[chunk_key] as Dictionary
		if chunk_data.entities.is_empty() and not chunk_data.is_active:
			chunks_to_remove.append(chunk_key)
	
	for chunk_key in chunks_to_remove:
		_chunks.erase(chunk_key)

## === DEBUG & UTILS ===

func get_chunk_stats() -> Dictionary:
	var total_chunks = _chunks.size()
	var active_chunks = 0
	var total_entities = 0
	
	for chunk_key in _chunks.keys():
		var chunk_data = _chunks[chunk_key] as Dictionary
		if chunk_data.is_active:
			active_chunks += 1
		total_entities += chunk_data.entities.size()
	
	return {
		"total_chunks": total_chunks,
		"active_chunks": active_chunks,
		"sleeping_chunks": total_chunks - active_chunks,
		"total_entities": total_entities,
		"avg_entities_per_chunk": float(total_entities) / float(maxi(1, total_chunks))
	}

func debug_print_status() -> void:
	var stats = get_chunk_stats()
	print("[SpatialManager] Chunks: %d total, %d active, %d sleeping" % [
		stats.total_chunks, stats.active_chunks, stats.sleeping_chunks
	])
	print("[SpatialManager] Entities: %d total, %.2f avg/chunk" % [
		stats.total_entities, stats.avg_entities_per_chunk
	])

func to_dict() -> Dictionary:
	return {
		"chunks": _chunks,
		"entity_chunk_map": _entity_chunk_map,
		"settlement_chunks": _settlement_chunks
	}

func from_dict(data: Dictionary) -> void:
	_chunks = data.get("chunks", {})
	_entity_chunk_map = data.get("entity_chunk_map", {})
	_settlement_chunks = data.get("settlement_chunks", {})
