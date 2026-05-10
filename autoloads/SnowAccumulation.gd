extends Node

const ACCUMULATION_STEP: float = 0.02
const MELT_STEP: float = 0.01

var _world: World = null
var _snow_levels: Dictionary = {}  # Vector2i -> float


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func bind_world(world_ref: World) -> void:
	_world = world_ref


func clear(_tile: Vector2i = Vector2i(-1, -1)) -> void:
	_snow_levels.clear()


func clear_snow_at(tile: Vector2i) -> void:
	_snow_levels.erase(tile)


func get_snow_at(tile: Vector2i) -> float:
	if _world == null or _world.data == null:
		return 0.0
	var current: float = float(_snow_levels.get(tile, _initial_snow(tile)))
	var target: float = _snow_target(tile)
	var step: float = ACCUMULATION_STEP if target >= current else MELT_STEP
	current = move_toward(current, target, step)
	_snow_levels[tile] = current
	return clampf(current, 0.0, 1.0)


func get_snow_depth(tile: Vector2i) -> float:
	return get_snow_at(tile)


func _initial_snow(tile: Vector2i) -> float:
	if _world == null or _world.data == null:
		return 0.0
	var biome: int = int(_world.data.get_biome(tile.x, tile.y))
	if biome == Biome.Type.TUNDRA or biome == Biome.Type.MOUNTAIN:
		return 0.25
	if biome == Biome.Type.WATER:
		return 0.0
	var noise: float = WorldRNG.unit_for(&"snow:init", tile.x * 131 + tile.y * 197)
	return clampf(noise * 0.12, 0.0, 0.2)


func _snow_target(tile: Vector2i) -> float:
	if _world == null or _world.data == null:
		return 0.0
	var biome: int = int(_world.data.get_biome(tile.x, tile.y))
	if biome == Biome.Type.WATER:
		return 0.0
	var winter_wave: float = 0.5 + 0.5 * sin(float(GameManager.tick_count) / 9000.0)
	var biome_bias: float = 0.15
	match biome:
		Biome.Type.TUNDRA:
			biome_bias = 0.85
		Biome.Type.MOUNTAIN:
			biome_bias = 0.75
		Biome.Type.FOREST:
			biome_bias = 0.35
		Biome.Type.PLAINS:
			biome_bias = 0.25
		Biome.Type.DESERT:
			biome_bias = 0.05
		Biome.Type.STONE_FLOOR:
			biome_bias = 0.20
		_:
			biome_bias = 0.15
	var altitude_bonus: float = WorldRNG.unit_for(&"snow:alt", tile.x * 73 + tile.y * 91) * 0.15
	var target: float = clampf((winter_wave * biome_bias) + altitude_bonus - 0.1, 0.0, 1.0)
	return target
