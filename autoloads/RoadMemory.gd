extends Node
class_name RoadMemory
## Roads & Path Memory v1: traversal from pawn steps only; not saved; no RNG.
## Stacked with [PathFinder] historic weights (roads ease travel slightly).

const ROAD_T1: int = 3
const ROAD_T2: int = 10
const ROAD_DECAY_TICKS: int = 10_000
const PATH_W_T1: float = 0.86
const PATH_W_T2: float = 0.68
const MAX_PATCH_PER_FLUSH: int = 256

var _trav: PackedInt32Array = PackedInt32Array()
var _dirty_tiles: PackedInt32Array = PackedInt32Array()
var _ready_connected: bool = false
var _road_regions: Dictionary = {}  # Cache: region_key → true for regions with road tiles
## When true, skip batch tile repaints; traversal memory still updates. For profiling.
var debug_disable_visuals: bool = false


func _ready() -> void:
	if not _ready_connected:
		_ready_connected = true
		GameManager.game_tick.connect(_on_game_tick)
	_ensure_size()


func clear() -> void:
	_ensure_size()
	for i3 in range(WorldData.TILE_COUNT):
		_trav[i3] = 0
	_dirty_tiles.clear()


func _ensure_size() -> void:
	if _trav.size() != WorldData.TILE_COUNT:
		_trav.resize(WorldData.TILE_COUNT)
		for i0 in range(WorldData.TILE_COUNT):
			_trav[i0] = 0


## Movement A → B: count step onto B (read-only rule).
func record_step(from_tile: Vector2i, to_tile: Vector2i, world: World) -> void:
	_ensure_size()
	if from_tile == to_tile:
		return
	if to_tile.x < 0 or to_tile.y < 0 or to_tile.x >= WorldData.WIDTH or to_tile.y >= WorldData.HEIGHT:
		return
	var i1: int = to_tile.y * WorldData.WIDTH + to_tile.x
	if i1 < 0 or i1 >= _trav.size():
		return
	_trav[i1] = _trav[i1] + 1
	_trav[i1] = mini(_trav[i1], ROAD_T2 + 20)
	_dirty_tiles.append(i1)
	# Track region for PathFinder optimization
	if _trav[i1] >= ROAD_T1:
		var rk: int = WorldMemory._region_key(to_tile.x, to_tile.y)
		_road_regions[rk] = true
		# DORMANT WORLD: Unlock road gate when first road forms
		if DiscoveryGate != null:
			DiscoveryGate.unlock("first_road")


func flush_dirty_tiles(world: World) -> void:
	if _dirty_tiles.is_empty() or world == null or not is_instance_valid(world):
		return
	if debug_disable_visuals:
		_dirty_tiles.clear()
		return
	var w0: World = world as World
	var n1: int = mini(MAX_PATCH_PER_FLUSH, _dirty_tiles.size())
	for k in range(n1):
		w0.patch_road_tile_at_index(int(_dirty_tiles[k]))
	if n1 < _dirty_tiles.size():
		_dirty_tiles = _dirty_tiles.slice(n1, _dirty_tiles.size())
	else:
		_dirty_tiles.clear()


## Move-cost tier from a traversal count (see [method get_path_weight_mul]).
func _path_mul_from_count(t: int) -> float:
	if t >= ROAD_T2:
		return PATH_W_T2
	if t >= ROAD_T1:
		return PATH_W_T1
	return 1.0


func get_traversal(x: int, y: int) -> int:
	if x < 0 or y < 0 or x >= WorldData.WIDTH or y >= WorldData.HEIGHT:
		return 0
	if _trav.size() != WorldData.TILE_COUNT:
		return 0
	return int(_trav[y * WorldData.WIDTH + x])


## Multiplier to movement cost: lower = easier. Never below scar handling (PathFinder order).
func get_path_weight_mul(x: int, y: int) -> float:
	var t: int = get_traversal(x, y)
	if t >= ROAD_T2:
		return PATH_W_T2
	if t >= ROAD_T1:
		return PATH_W_T1
	return 1.0


## PERFORMANCE: Return regions that have road tiles (traversal >= ROAD_T1).
func get_regions_with_roads() -> Dictionary:
	return _road_regions


func _on_game_tick(tick: int) -> void:
	_ensure_size()
	if (int(tick) % ROAD_DECAY_TICKS) != 0:
		return
	_decay_step()
	var tree0: SceneTree = get_tree()
	if tree0 == null:
		return
	var wn2: Node = tree0.get_first_node_in_group("colony_world")
	if wn2 != null and is_instance_valid(wn2) and (wn2 is World):
		flush_dirty_tiles(wn2 as World)


func _decay_step() -> void:
	var any_changed: bool = false
	for i2 in range(WorldData.TILE_COUNT):
		if _trav[i2] <= 0:
			continue
		var before: int = _trav[i2]
		var after: int = before - 1
		_trav[i2] = after
		if _path_mul_from_count(before) != _path_mul_from_count(after):
			any_changed = true
	if not any_changed:
		return
	var tree0: SceneTree = get_tree()
	if tree0 == null:
		return
	var wn: Node = tree0.get_first_node_in_group("colony_world")
	if wn != null and is_instance_valid(wn) and (wn is World):
		var w0: World = wn as World
		w0.refresh_road_memory_terrain()
		w0.refresh_pawn_historic_path_weights()
