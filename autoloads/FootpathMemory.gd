extends Node

const DECAY_INTERVAL_TICKS: int = 60
const DECAY_MULTIPLIER: float = 0.985
const WORN_TILE_THRESHOLD: int = 24

var _world: World = null
var _pawn_spawner: PawnSpawner = null
var _traffic: Dictionary = {}  # Vector2i -> {count: int, last_tick: int}
var _last_decay_tick: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if has_node("/root/GameManager"):
		GameManager.game_tick.connect(_on_game_tick)


func bind_context(world_ref: World, pawn_spawner_ref: PawnSpawner) -> void:
	_world = world_ref
	_pawn_spawner = pawn_spawner_ref


func clear() -> void:
	_traffic.clear()
	_last_decay_tick = 0


func record_traffic(tile: Vector2i, weight: int = 1, tick: int = -1) -> void:
	if tile == Vector2i.ZERO and weight <= 0:
		return
	var entry: Dictionary = _traffic.get(tile, {"count": 0, "last_tick": tick})
	entry["count"] = maxi(0, int(entry.get("count", 0)) + maxi(1, weight))
	entry["last_tick"] = tick if tick >= 0 else GameManager.tick_count
	_traffic[tile] = entry


func get_traffic_at(tile: Vector2i) -> int:
	var entry: Dictionary = _traffic.get(tile, {})
	return int(entry.get("count", 0))


func get_wear_at(tile: Vector2i) -> float:
	var count: int = get_traffic_at(tile)
	if count <= 0:
		return 0.0
	return clampf(float(count) / float(WORN_TILE_THRESHOLD), 0.0, 1.0)


const SAMPLE_INTERVAL: int = 20

func _on_game_tick(tick: int) -> void:
	if _pawn_spawner == null or _world == null or _world.data == null:
		return
	if tick % SAMPLE_INTERVAL == 0:
		_sample_pawns(tick)
	if tick - _last_decay_tick >= DECAY_INTERVAL_TICKS:
		_decay_paths()
		_last_decay_tick = tick


func _sample_pawns(tick: int) -> void:
	for pawn in _pawn_spawner.pawns:
		if pawn == null or not is_instance_valid(pawn) or pawn.data == null:
			continue
		var tile: Vector2i = _pawn_tile(pawn)
		if tile == Vector2i.ZERO and not _is_valid_tile(tile):
			continue
		var weight: int = 1
		if _is_road_tile(tile):
			weight += 2
		if pawn.has_method("_is_moving") or int(pawn.get("_state")) != 0:
			weight += 1
		record_traffic(tile, weight, tick)
		# Faint wear spreads to adjacent tiles for trails and doorways.
		for offset in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if _is_valid_tile(tile + offset) and _is_road_tile(tile + offset):
				record_traffic(tile + offset, 1, tick)


func _pawn_tile(pawn: Node) -> Vector2i:
	if pawn != null and pawn.has_method("get_tile_pos"):
		var maybe_tile: Variant = pawn.call("get_tile_pos")
		if maybe_tile is Vector2i:
			return maybe_tile
	if pawn != null and pawn.data != null and "tile_pos" in pawn.data:
		return pawn.data.tile_pos
	if pawn != null and pawn.has_method("get_global_position"):
		var pos: Vector2 = pawn.global_position
		return Vector2i(int(round(pos.x / World.TILE_PIXELS)), int(round(pos.y / World.TILE_PIXELS)))
	return Vector2i.ZERO


func _is_road_tile(tile: Vector2i) -> bool:
	if _world == null or _world.data == null:
		return false
	if not _world.data.in_bounds(tile.x, tile.y):
		return false
	var idx: int = _world.data.index(tile.x, tile.y)
	return int(_world.data.features[idx]) == int(TileFeature.Type.ROAD)


func _is_valid_tile(tile: Vector2i) -> bool:
	if _world == null or _world.data == null:
		return false
	return _world.data.in_bounds(tile.x, tile.y)


func _decay_paths() -> void:
	var erase_tiles: Array[Vector2i] = []
	for tile in _traffic:
		var entry: Dictionary = _traffic[tile]
		var count: int = int(entry.get("count", 0))
		count = int(floor(float(count) * DECAY_MULTIPLIER))
		if count <= 0:
			erase_tiles.append(tile)
		else:
			entry["count"] = count
			_traffic[tile] = entry
	for tile in erase_tiles:
		_traffic.erase(tile)
