extends Node

const DECAY_INTERVAL_TICKS: int = 90
const DECAY_MULTIPLIER: float = 0.992
const WORN_BUILDING_THRESHOLD: int = 36

var _world: World = null
var _pawn_spawner: PawnSpawner = null
var _usage: Dictionary = {}  # Vector2i -> {count: int, last_tick: int}
var _last_decay_tick: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_building_feature_set()
	if has_node("/root/GameManager"):
		GameManager.game_tick.connect(_on_game_tick)


func bind_context(world_ref: World, pawn_spawner_ref: PawnSpawner) -> void:
	_world = world_ref
	_pawn_spawner = pawn_spawner_ref


func clear() -> void:
	_usage.clear()
	_last_decay_tick = 0


func record_usage(tile: Vector2i, weight: int = 1, tick: int = -1) -> void:
	if tile == Vector2i.ZERO and weight <= 0:
		return
	var entry: Dictionary = _usage.get(tile, {"count": 0, "last_tick": tick})
	entry["count"] = maxi(0, int(entry.get("count", 0)) + maxi(1, weight))
	entry["last_tick"] = tick if tick >= 0 else GameManager.tick_count
	_usage[tile] = entry


func get_usage_at(tile: Vector2i) -> int:
	var entry: Dictionary = _usage.get(tile, {})
	return int(entry.get("count", 0))


func get_wear_at(tile: Vector2i) -> float:
	var count: int = get_usage_at(tile)
	if count <= 0:
		return 0.0
	return clampf(float(count) / float(WORN_BUILDING_THRESHOLD), 0.0, 1.0)


func _on_game_tick(tick: int) -> void:
	if _pawn_spawner == null or _world == null or _world.data == null:
		return
	# Throttle: sample pawns less frequently at high speed
	var sample_interval: int = 1
	if GameManager != null:
		var gs: float = GameManager.game_speed
		if gs >= 100.0:
			sample_interval = 10
		elif gs >= 50.0:
			sample_interval = 6
		elif gs >= 26.0:
			sample_interval = 4
		elif gs >= 12.0:
			sample_interval = 2
	if tick % sample_interval == 0:
		_sample_building_usage(tick)
	if tick - _last_decay_tick >= DECAY_INTERVAL_TICKS:
		_decay_usage()
		_last_decay_tick = tick


func _sample_building_usage(tick: int) -> void:
	for pawn in _pawn_spawner.pawns:
		if pawn == null or not is_instance_valid(pawn) or pawn.data == null:
			continue
		var tile: Vector2i = _pawn_tile(pawn)
		if not _is_valid_tile(tile):
			continue
		if not _is_building_tile(tile):
			continue
		var weight: int = 1
		var state: int = int(pawn.get("_state"))
		if state == 6 or state == 7:
			weight += 2
		elif state == 2 or state == 5 or state == 8:
			weight += 1
		record_usage(tile, weight, tick)
		# Doorways and shared spaces wear faster than the exact occupied tile.
		for offset in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var adj_tile: Vector2i = tile + offset
			if _is_valid_tile(adj_tile) and _is_building_tile(adj_tile):
				record_usage(adj_tile, 1, tick)


func _pawn_tile(pawn: Node) -> Vector2i:
	if pawn != null and pawn.data != null and "tile_pos" in pawn.data:
		return pawn.data.tile_pos
	if pawn != null and pawn is Node2D:
		var pos: Vector2 = (pawn as Node2D).global_position
		return Vector2i(int(round(pos.x / World.TILE_PIXELS)), int(round(pos.y / World.TILE_PIXELS)))
	return Vector2i.ZERO


func _is_valid_tile(tile: Vector2i) -> bool:
	if _world == null or _world.data == null:
		return false
	return _world.data.in_bounds(tile.x, tile.y)


# Pre-built lookup set for building feature types (populated in _ready)
var _building_features: Dictionary = {}


func _build_building_feature_set() -> void:
	var features: Array = [
		TileFeature.Type.RUIN,
		TileFeature.Type.BED,
		TileFeature.Type.WALL,
		TileFeature.Type.DOOR,
		TileFeature.Type.FIRE_PIT,
		TileFeature.Type.STORAGE_HUT,
		TileFeature.Type.MARKER_STONE,
		TileFeature.Type.SHRINE,
		TileFeature.Type.GRAVE_MARKER,
		TileFeature.Type.KNOWLEDGE_STONE,
		TileFeature.Type.LEDGER_STONE,
		TileFeature.Type.FARM_WHEAT,
		TileFeature.Type.FARM_CORN,
		TileFeature.Type.FARM_VEGETABLES,
		TileFeature.Type.HERB_GARDEN,
		TileFeature.Type.WORKSHOP,
		TileFeature.Type.LOOM,
		TileFeature.Type.KILN,
		TileFeature.Type.SMELTER,
		TileFeature.Type.BOATYARD,
		TileFeature.Type.DOCK,
		TileFeature.Type.FISHERMAN_HUT,
		TileFeature.Type.APOTHECARY,
		TileFeature.Type.LIBRARY,
		TileFeature.Type.SCHOOL,
		TileFeature.Type.BARRACKS,
		TileFeature.Type.WATCHTOWER,
		TileFeature.Type.MARKET,
		TileFeature.Type.TRADING_POST,
		TileFeature.Type.ROAD,
		TileFeature.Type.GRANARY,
		TileFeature.Type.CELLAR,
	]
	for f in features:
		_building_features[f] = true


func _is_building_tile(tile: Vector2i) -> bool:
	if _world == null or _world.data == null:
		return false
	if not _world.data.in_bounds(tile.x, tile.y):
		return false
	var idx: int = _world.data.index(tile.x, tile.y)
	var feature: int = int(_world.data.features[idx])
	return _building_features.has(feature)


func _decay_usage() -> void:
	var erase_tiles: Array[Vector2i] = []
	for tile in _usage:
		var entry: Dictionary = _usage[tile]
		var count: int = int(entry.get("count", 0))
		count = int(floor(float(count) * DECAY_MULTIPLIER))
		if count <= 0:
			erase_tiles.append(tile)
		else:
			entry["count"] = count
			_usage[tile] = entry
	for tile in erase_tiles:
		_usage.erase(tile)
