extends Node
## FlowingWater — Water flow simulation across the map.
## Water flows downhill from higher tiles to lower tiles.
## Rivers form naturally from water sources. Dams block flow.
## Underwater current affects boat movement and pawn swimming speed.
## Deterministic: each tick, water is processed in a fixed order.

const EVAPORATION_RATE: float = 0.001
const FLOW_SPEED: float = 0.1
const MAX_WATER_LEVEL: float = 10.0

var water_levels: Dictionary = {}
var flow_directions: Dictionary = {}

func _ready() -> void:
	if GameManager != null:
		GameManager.game_tick.connect(_on_game_tick)
	_initialize_water()

func _initialize_water() -> void:
	var _wd = WorldData.current
	if _wd == null:
		return
	for x in range(WorldData.WIDTH):
		for y in range(WorldData.HEIGHT):
			var biome: int = _wd.get_biome(x, y)
			var feature: int = _wd.get_feature(x, y)
			if biome == Biome.Type.WATER or feature == TileFeature.Type.RIVER:
				water_levels["%d,%d" % [x, y]] = MAX_WATER_LEVEL
			elif biome == Biome.Type.OCEAN or feature == TileFeature.Type.OCEAN:
				water_levels["%d,%d" % [x, y]] = MAX_WATER_LEVEL * 2

func get_water_level(tile: Vector2i) -> float:
	return water_levels.get("%d,%d" % [tile.x, tile.y], 0.0)

func set_water_level(tile: Vector2i, level: float) -> void:
	var key: String = "%d,%d" % [tile.x, tile.y]
	if level <= 0.0:
		water_levels.erase(key)
	else:
		water_levels[key] = minf(level, MAX_WATER_LEVEL * 2)

func _on_game_tick(tick: int) -> void:
	if tick % 10 != 0:
		return
	_flow_water(tick)

func _flow_water(_tick: int) -> void:
	var changes: Dictionary = {}
	var all_keys: Array = water_levels.keys()
	all_keys.sort()
	for key in all_keys:
		var parts: Array = key.split(",")
		var x: int = int(parts[0])
		var y: int = int(parts[1])
		var level: float = water_levels.get(key, 0.0)
		if level <= 0.0:
			continue
		var feat: int = 0
		var _wd2 = WorldData.current
		if _wd2 != null:
			feat = _wd2.get_feature(x, y)
		if feat == TileFeature.Type.DAM:
			continue
		var neighbors: Array = [
			Vector2i(x, y - 1),
			Vector2i(x, y + 1),
			Vector2i(x - 1, y),
			Vector2i(x + 1, y),
		]
		neighbors.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			if a.y != b.y:
				return a.y < b.y
			return a.x < b.x
		)
		for n in neighbors:
			if n.x < 0 or n.x >= WorldData.WIDTH or n.y < 0 or n.y >= WorldData.HEIGHT:
				continue
			var nkey: String = "%d,%d" % [n.x, n.y]
			var nlevel: float = water_levels.get(nkey, 0.0)
			if nlevel >= MAX_WATER_LEVEL:
				continue
			var flow: float = minf(level * FLOW_SPEED, MAX_WATER_LEVEL - nlevel)
			if flow < 0.01:
				continue
			if not changes.has(key):
				changes[key] = 0.0
			if not changes.has(nkey):
				changes[nkey] = 0.0
			changes[key] = float(changes.get(key, 0.0)) - flow
			changes[nkey] = float(changes.get(nkey, 0.0)) + flow
			break
	for key in changes:
		var current: float = water_levels.get(key, 0.0)
		var new_level: float = current + float(changes[key])
		if new_level <= 0.0:
			water_levels.erase(key)
		else:
			water_levels[key] = new_level

func get_flow_direction(tile: Vector2i) -> Vector2:
	var level: float = get_water_level(tile)
	if level <= 0.0:
		return Vector2.ZERO
	var lowest: Vector2i = tile
	var lowest_level: float = level
	var neighbors: Array = [
		Vector2i(tile.x, tile.y - 1),
		Vector2i(tile.x, tile.y + 1),
		Vector2i(tile.x - 1, tile.y),
		Vector2i(tile.x + 1, tile.y),
	]
	for n in neighbors:
		if n.x < 0 or n.x >= WorldData.WIDTH or n.y < 0 or n.y >= WorldData.HEIGHT:
			continue
		var nl: float = get_water_level(n)
		if nl < lowest_level:
			lowest_level = nl
			lowest = n
	if lowest != tile:
		return Vector2(lowest.x - tile.x, lowest.y - tile.y)
	return Vector2.ZERO
