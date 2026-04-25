extends Node
## v1: Derived, not saved — "birth" Age per tile for RUIN / WALL / DOOR / T2 trade routes; [tile_age_delta] = current - birth.
## Timestamps are not stored; first sighting + Age transitions only.

const BIRTH_NONE: int = -1

## Path weight: delta>=1; extra for T2 with delta>=2.
const PATH_D1: float = 1.04
const PATH_D2: float = 1.04
const PATH_T2_OLD: float = 1.05

## Planner: manhattan is scaled by a small per-delta add for expansion sorts.
const PLANNER_PEN: int = 5

## birth Age index at first marking (0 = current or seed era).
var _birth: PackedInt32Array = PackedInt32Array()


func _ready() -> void:
	_ensure_birth_size()


func _ensure_birth_size() -> void:
	if _birth.size() == WorldData.TILE_COUNT:
		return
	_birth.resize(WorldData.TILE_COUNT)
	_clear_birth_to_none()


func _clear_birth_to_none() -> void:
	for i in range(_birth.size()):
		_birth[i] = BIRTH_NONE


func clear() -> void:
	_ensure_birth_size()
	_clear_birth_to_none()


## After load or first world, treat all extant remnant art as "this" Age 0.
func seed_births_from_current_world(w: World) -> void:
	if w == null or w.data == null:
		return
	_ensure_birth_size()
	var age0: int = AgeMemory.get_current_age_index()
	for y in range(WorldData.HEIGHT):
		for x in range(WorldData.WIDTH):
			var f: int = int(w.data.get_feature(x, y))
			var i0: int = y * WorldData.WIDTH + x
			_birth[i0] = BIRTH_NONE
			if f == int(TileFeature.Type.RUIN) or f == int(TileFeature.Type.WALL) or f == int(
					TileFeature.Type.DOOR
			):
				_birth[i0] = age0
			elif TradeMemory.get_route_tier_at(x, y) >= TradeMemory.TIER_ROUTE_2:
				_birth[i0] = age0


## On Age transition, everything still un-dated (world gen carry-over) becomes [ended_age] (one era old next tick).
func on_age_ended(ended_age: int, w: World) -> void:
	if w == null or w.data == null:
		return
	_ensure_birth_size()
	for y1 in range(WorldData.HEIGHT):
		for x1 in range(WorldData.WIDTH):
			var i1: int = y1 * WorldData.WIDTH + x1
			if not _is_remnant_tile(x1, y1, w):
				continue
			if int(_birth[i1]) != BIRTH_NONE:
				continue
			_birth[i1] = ended_age


## First time a feature becomes a tracked structure.
func on_feature_set(w: World, x: int, y: int, new_feature: int) -> void:
	_ensure_birth_size()
	if not w.data.in_bounds(x, y):
		return
	var i2: int = y * WorldData.WIDTH + x
	if not _feature_is_remnant(new_feature):
		_birth[i2] = BIRTH_NONE
		return
	if int(_birth[i2]) != BIRTH_NONE:
		return
	_birth[i2] = AgeMemory.get_current_age_index()


## [TradeMemory] T2 paint on passable path tiles.
func on_t2_painted(x: int, y: int) -> void:
	_ensure_birth_size()
	if x < 0 or y < 0 or x >= WorldData.WIDTH or y >= WorldData.HEIGHT:
		return
	var i3: int = y * WorldData.WIDTH + x
	if int(_birth[i3]) != BIRTH_NONE:
		return
	_birth[i3] = AgeMemory.get_current_age_index()


static func _feature_is_remnant(f: int) -> bool:
	return (
			f == int(TileFeature.Type.RUIN)
			or f == int(TileFeature.Type.WALL)
			or f == int(TileFeature.Type.DOOR)
	)


func _is_remnant_tile(x: int, y: int, w: World) -> bool:
	if not w.data.in_bounds(x, y):
		return false
	var f0: int = int(w.data.get_feature(x, y))
	if _feature_is_remnant(f0):
		return true
	return TradeMemory.get_route_tier_at(x, y) >= TradeMemory.TIER_ROUTE_2


func get_birth_at(x: int, y: int) -> int:
	_ensure_birth_size()
	if x < 0 or y < 0 or x >= WorldData.WIDTH or y >= WorldData.HEIGHT:
		return BIRTH_NONE
	return int(_birth[y * WorldData.WIDTH + x])


## 0 = current-era patina, 1+ = prior Ages (approximate).
func get_tile_rem_delta(x: int, y: int, w: World) -> int:
	if w == null or w.data == null or not w.data.in_bounds(x, y):
		return 0
	var f1: int = int(w.data.get_feature(x, y))
	var t2: bool = TradeMemory.get_route_tier_at(x, y) >= TradeMemory.TIER_ROUTE_2
	if not _feature_is_remnant(f1) and not t2:
		return 0
	var b0: int = get_birth_at(x, y)
	if b0 == BIRTH_NONE:
		return 0
	var cur: int = AgeMemory.get_current_age_index()
	return maxi(0, cur - b0)


## Extra cost on pawn A*; stacked after scar, road, trade; does not cap scar.
func get_remnant_path_mul(x: int, y: int, w: World) -> float:
	var d0: int = get_tile_rem_delta(x, y, w)
	if d0 < 1:
		return 1.0
	var m0: float = PATH_D1
	if d0 >= 2:
		m0 *= PATH_D2
		if TradeMemory.get_route_tier_at(x, y) >= TradeMemory.TIER_ROUTE_2 and d0 >= 2:
			m0 *= PATH_T2_OLD
	return m0


## Ruins that read as "fully" prior-era (v1: never spawn / reclaim targets).
func is_ruin_ancient_block(x: int, y: int, w: World) -> bool:
	if w == null or w.data == null:
		return false
	if int(w.data.get_feature(x, y)) != int(TileFeature.Type.RUIN):
		return false
	return get_tile_rem_delta(x, y, w) >= 2


## [SettlementPlanner] manhattan add-on; higher = older = worse to build on/expand to.
func get_planner_penalty(t: Vector2i, w: World) -> int:
	if w == null:
		return 0
	return get_tile_rem_delta(t.x, t.y, w) * PLANNER_PEN
