extends Node

const DECAY_INTERVAL_TICKS: int = 90
const DECAY_MULTIPLIER: float = 0.992
const WORN_BUILDING_THRESHOLD: int = 36
const EARLY_DECAY_PROTECTION_DAYS: int = 35
const FIRST_WORN_AGE_TICKS: int = 150_000  # 5 sim years before any structure decay at current 30k tick years
const CONDITION_DECAY_INTERVAL_TICKS: int = 600
const CONDITION_HEALTHY_MIN: float = 70.0
const CONDITION_WORN_MIN: float = 40.0
const CONDITION_DAMAGED_MIN: float = 12.0
## Usage count below this on an existing fire pit → regional duplicate posts are dampened.
const HEARTH_UNDERUSE_USAGE: int = 8
const HEARTH_SCAN_RADIUS: int = 14

var _world: World = null
var _pawn_spawner: PawnSpawner = null
var _usage: Dictionary = {}  # Vector2i -> {count: int, last_tick: int}
var _condition: Dictionary = {} # Vector2i -> structure condition record
var _last_decay_tick: int = 0
var _last_condition_decay_tick: int = 0


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
	_condition.clear()
	_last_decay_tick = 0
	_last_condition_decay_tick = 0


func record_usage(tile: Vector2i, weight: int = 1, tick: int = -1) -> void:
	if tile == Vector2i.ZERO and weight <= 0:
		return
	if _world != null and _world.data != null and _world.data.in_bounds(tile.x, tile.y):
		var feature_type: int = int(_world.data.get_feature(tile.x, tile.y))
		if _building_features.has(feature_type):
			register_structure(tile, feature_type, -1, _settlement_for_tile(tile))
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


const SAMPLE_INTERVAL: int = 6

func _on_game_tick(tick: int) -> void:
	if _pawn_spawner == null or _world == null or _world.data == null:
		return
	if tick % SAMPLE_INTERVAL == 0:
		_sample_building_usage(tick)
	if tick - _last_decay_tick >= DECAY_INTERVAL_TICKS:
		_decay_usage()
		_last_decay_tick = tick
	if tick - _last_condition_decay_tick >= CONDITION_DECAY_INTERVAL_TICKS:
		_decay_structure_conditions(tick)
		_last_condition_decay_tick = tick


func register_structure(tile: Vector2i, feature_type: int, builder_id: int = -1, settlement_id: int = -1) -> void:
	if tile.x < 0 or tile.y < 0:
		return
	if not _building_features.has(feature_type):
		return
	var now: int = GameManager.tick_count if GameManager != null else 0
	var entry: Dictionary = _condition.get(tile, {})
	if entry.is_empty():
		entry = {
			"feature_type": int(feature_type),
			"builder_id": int(builder_id),
			"settlement_id": int(settlement_id),
			"created_tick": now,
			"last_maintained_tick": now,
			"condition": 100.0,
		}
	else:
		entry["feature_type"] = int(feature_type)
		if builder_id >= 0:
			entry["builder_id"] = int(builder_id)
		if settlement_id >= 0:
			entry["settlement_id"] = int(settlement_id)
	_condition[tile] = entry


func record_maintenance(tile: Vector2i, pawn_id: int = -1) -> void:
	if _world == null or _world.data == null or not _world.data.in_bounds(tile.x, tile.y):
		return
	var feature_type: int = int(_world.data.get_feature(tile.x, tile.y))
	register_structure(tile, feature_type, -1, _settlement_for_tile(tile))
	var entry: Dictionary = _condition.get(tile, {})
	if entry.is_empty():
		return
	entry["condition"] = 100.0
	entry["last_maintained_tick"] = GameManager.tick_count if GameManager != null else 0
	_condition[tile] = entry
	if WorldMemory != null:
		WorldMemory.record_event({
			"type": "structure_maintained",
			"k": WorldMemory.Kind.BUILDING_CONSTRUCTED,
			"pawn_id": int(pawn_id),
			"tile": {"x": tile.x, "y": tile.y},
			"feature_type": int(feature_type),
			"tick": GameManager.tick_count if GameManager != null else 0,
			"r": WorldMemory._region_key(tile.x, tile.y),
		})


func get_condition(tile: Vector2i) -> float:
	_refresh_condition_for_tile(tile)
	var entry: Dictionary = _condition.get(tile, {})
	if entry.is_empty():
		return 100.0
	return float(entry.get("condition", 100.0))


func get_visual_state(tile: Vector2i) -> String:
	var c: float = get_condition(tile)
	if c >= CONDITION_HEALTHY_MIN:
		return "healthy"
	if c >= CONDITION_WORN_MIN:
		return "worn"
	if c >= CONDITION_DAMAGED_MIN:
		return "damaged"
	return "ruin"


func get_due_maintenance_jobs(max_count: int = 8) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if _world == null or _world.data == null:
		return out
	if _early_protection_active():
		return out
	for tile_v in _condition.keys():
		if out.size() >= max_count:
			break
		if not (tile_v is Vector2i):
			continue
		var tile: Vector2i = tile_v
		if not _world.data.in_bounds(tile.x, tile.y):
			continue
		var feature_type: int = int(_world.data.get_feature(tile.x, tile.y))
		if not _building_features.has(feature_type):
			continue
		var cond: float = get_condition(tile)
		if cond >= CONDITION_HEALTHY_MIN:
			continue
		out.append({
			"tile": tile,
			"feature_type": feature_type,
			"priority": 8 if cond < CONDITION_WORN_MIN else 5,
			"condition": cond,
		})
	return out


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


func _decay_structure_conditions(tick: int) -> void:
	if _early_protection_active():
		return
	if _condition.is_empty():
		return
	for tile_v in _condition.keys():
		if not (tile_v is Vector2i):
			continue
		var tile: Vector2i = tile_v
		_refresh_condition_for_tile(tile, tick)


func _refresh_condition_for_tile(tile: Vector2i, tick: int = -1) -> void:
	if not _condition.has(tile):
		return
	var now: int = tick if tick >= 0 else (GameManager.tick_count if GameManager != null else 0)
	var entry: Dictionary = _condition[tile]
	var created: int = int(entry.get("created_tick", now))
	if now - created < FIRST_WORN_AGE_TICKS:
		entry["condition"] = maxf(float(entry.get("condition", 100.0)), CONDITION_HEALTHY_MIN)
		_condition[tile] = entry
		return
	var maintained: int = int(entry.get("last_maintained_tick", created))
	var unattended_ticks: int = maxi(now - max(created + FIRST_WORN_AGE_TICKS, maintained), 0)
	var one_and_half_years: float = float(maxi(1, FIRST_WORN_AGE_TICKS))
	var decay: float = float(unattended_ticks) / one_and_half_years * 30.0
	var condition_now: float = clampf(100.0 - decay, 0.0, 100.0)
	entry["condition"] = minf(float(entry.get("condition", 100.0)), condition_now)
	_condition[tile] = entry


func _early_protection_active() -> bool:
	if GameManager == null:
		return false
	var day_ticks: int = 600
	if ClassDB.class_exists("SimTime"):
		day_ticks = SimTime.TICKS_PER_VISUAL_DAY
	return GameManager.tick_count < EARLY_DECAY_PROTECTION_DAYS * day_ticks


func _settlement_for_tile(tile: Vector2i) -> int:
	if SettlementMemory == null or WorldMemory == null:
		return -1
	var rk: int = WorldMemory._region_key(tile.x, tile.y)
	return SettlementMemory.get_center_region_for_region(rk)


## True when every fire pit in [param center_region] sees little foot traffic — skip new hearth posts.
func should_dampen_additional_hearth_post(center_region: int) -> bool:
	if center_region < 0 or _world == null or _world.data == null:
		return false
	var crx: int = center_region & 0xFFFF
	var cry: int = (center_region >> 16) & 0xFFFF
	var center: Vector2i = Vector2i(crx * 16 + 8, cry * 16 + 8)
	var underused: int = 0
	var total: int = 0
	for dy in range(-HEARTH_SCAN_RADIUS, HEARTH_SCAN_RADIUS + 1):
		for dx in range(-HEARTH_SCAN_RADIUS, HEARTH_SCAN_RADIUS + 1):
			var tx: int = center.x + dx
			var ty: int = center.y + dy
			if not _world.data.in_bounds(tx, ty):
				continue
			if int(_world.data.get_feature(tx, ty)) != TileFeature.Type.FIRE_PIT:
				continue
			var tile: Vector2i = Vector2i(tx, ty)
			var rk: int = WorldMemory._region_key(tx, ty)
			if SettlementMemory != null and SettlementMemory.get_center_region_for_region(rk) != center_region:
				continue
			total += 1
			if get_usage_at(tile) < HEARTH_UNDERUSE_USAGE:
				underused += 1
	if total <= 0:
		return false
	return underused >= total
