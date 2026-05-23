extends Node
class_name RemnantMemory
## v1: Derived, not saved — "birth" Age per tile for RUIN / WALL / DOOR / T2 trade routes; [tile_age_delta] = current - birth.
## Timestamps are not stored; first sighting + Age transitions only.

const BIRTH_NONE: int = -1

## Path weight: delta>=1; extra for T2 with delta>=2.
const PATH_D1: float = 1.04
const PATH_D2: float = 1.04
const PATH_T2_OLD: float = 1.05
const PATH_ABANDONED: float = 1.03
const PATH_PERM_ABANDONED: float = 1.07

## Planner: manhattan is scaled by a small per-delta add for expansion sorts.
const PLANNER_PEN: int = 5
const PLANNER_ABANDONED_PEN: int = 4
const PLANNER_PERM_ABANDONED_PEN: int = 9

## birth Age index at first marking (0 = current or seed era).
var _birth: PackedInt32Array = PackedInt32Array()
var _remnant_regions: Dictionary = {}  # Cache: region_key → true for regions with remnant tiles


static func _get_instance() -> RemnantMemory:
	var main_loop: MainLoop = Engine.get_main_loop()
	if main_loop is SceneTree:
		var tree: SceneTree = main_loop as SceneTree
		var inst_v: Variant = tree.get_root().get_node_or_null("RemnantMemory")
		if inst_v is RemnantMemory:
			return inst_v as RemnantMemory
	return null


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
	_remnant_regions.clear()


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
				_track_remnant_region(x, y)
			elif EconomyManager.get_trade_route_tier_at(x, y) >= EconomyManager.TIER_ROUTE_2:
				_birth[i0] = age0
				_track_remnant_region(x, y)


## On Age transition, everything still un-dated (world gen carry-over) becomes [ended_age] (one era old next tick).
static func on_age_ended(ended_age: int, w: World) -> void:
	var inst: RemnantMemory = _get_instance()
	if inst == null:
		return
	inst._on_age_ended_impl(ended_age, w)


func _on_age_ended_impl(ended_age: int, w: World) -> void:
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
			_track_remnant_region(x1, y1)


## First time a feature becomes a tracked structure.
static func on_feature_set(w: World, x: int, y: int, new_feature: int) -> void:
	var inst: RemnantMemory = _get_instance()
	if inst == null:
		return
	inst._on_feature_set_impl(w, x, y, new_feature)


func _on_feature_set_impl(w: World, x: int, y: int, new_feature: int) -> void:
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
	_track_remnant_region(x, y)


## [TradeMemory] T2 paint on passable path tiles.
func on_t2_painted(x: int, y: int) -> void:
	_ensure_birth_size()
	if x < 0 or y < 0 or x >= WorldData.WIDTH or y >= WorldData.HEIGHT:
		return
	var i3: int = y * WorldData.WIDTH + x
	if int(_birth[i3]) != BIRTH_NONE:
		return
	_birth[i3] = AgeMemory.get_current_age_index()
	_track_remnant_region(x, y)
	# DORMANT WORLD: Unlock ruin gate when first remnant structure appears
	if DiscoveryGate != null:
		DiscoveryGate.unlock("first_ruin")


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
	return EconomyManager.get_trade_route_tier_at(x, y) >= EconomyManager.TIER_ROUTE_2


func get_birth_at(x: int, y: int) -> int:
	_ensure_birth_size()
	if x < 0 or y < 0 or x >= WorldData.WIDTH or y >= WorldData.HEIGHT:
		return BIRTH_NONE
	return int(_birth[y * WorldData.WIDTH + x])


## 0 = current-era patina, 1+ = prior Ages (approximate).
static func get_tile_rem_delta(x: int, y: int, w: World) -> int:
	var inst: RemnantMemory = _get_instance()
	if inst == null:
		return 0
	return inst._get_tile_rem_delta_impl(x, y, w)


func _get_tile_rem_delta_impl(x: int, y: int, w: World) -> int:
	if w == null or w.data == null or not w.data.in_bounds(x, y):
		return 0
	var f1: int = int(w.data.get_feature(x, y))
	var t2: bool = EconomyManager.get_trade_route_tier_at(x, y) >= EconomyManager.TIER_ROUTE_2
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
	var m0: float = 1.0
	if d0 >= 1:
		m0 *= PATH_D1
		if d0 >= 2:
			m0 *= PATH_D2
			if EconomyManager.get_trade_route_tier_at(x, y) >= EconomyManager.TIER_ROUTE_2:
				m0 *= PATH_T2_OLD
	var rk: int = WorldMemory._region_key(x, y)
	var st: String = SettlementMemory.get_state_at_region(rk)
	if st == "abandoned":
		m0 *= PATH_ABANDONED
	elif st == "permanently_abandoned":
		m0 *= PATH_PERM_ABANDONED
	return m0


## PERFORMANCE: Return regions that have remnant tiles.
## Uses incrementally maintained cache.
func get_regions_with_remnants() -> Dictionary:
	return _remnant_regions


## Track a region as having a remnant tile.
func _track_remnant_region(x: int, y: int) -> void:
	var rk: int = WorldMemory._region_key(x, y)
	_remnant_regions[rk] = true


## Ruins that read as "fully" prior-era (v1: never spawn / reclaim targets).
func is_ruin_ancient_block(x: int, y: int, w: World) -> bool:
	if w == null or w.data == null:
		return false
	if int(w.data.get_feature(x, y)) != int(TileFeature.Type.RUIN):
		return false
	return get_tile_rem_delta(x, y, w) >= 2


## [SettlementPlanner] manhattan add-on; higher = older = worse to build on/expand to.
static func get_planner_penalty(t: Vector2i, w: World) -> int:
	var inst: RemnantMemory = _get_instance()
	if inst == null:
		return 0
	return inst._get_planner_penalty_impl(t, w)


func _get_planner_penalty_impl(t: Vector2i, w: World) -> int:
	if w == null:
		return 0
	var out: int = get_tile_rem_delta(t.x, t.y, w) * PLANNER_PEN
	var rk: int = WorldMemory._region_key(t.x, t.y)
	var st: String = SettlementMemory.get_state_at_region(rk)
	if st == "abandoned":
		out += PLANNER_ABANDONED_PEN
	elif st == "permanently_abandoned":
		out += PLANNER_PERM_ABANDONED_PEN
	return out
