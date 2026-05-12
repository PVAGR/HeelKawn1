class_name PathFinder
extends RefCounted

## Wrapper around Godot's built-in AStarGrid2D plus a flood-filled
## connected-components map. Two jobs:
##   1. find_path(start, goal) -> actual walkable route avoiding mountains/water.
##   2. component_of(tile)     -> O(1) reachability test so pawns don't claim
##                                jobs stranded on another landmass.
##
## Call `rebuild` after every world load/generate. For terrain updates use
## `sync_tile_from_data` / `set_job_construction_reservation` (see `World` helpers).

const NEIGHBOR_OFFSETS: Array[Vector2i] = [
	Vector2i( 1,  0), Vector2i(-1,  0), Vector2i( 0,  1), Vector2i( 0, -1),
	Vector2i( 1,  1), Vector2i(-1,  1), Vector2i( 1, -1), Vector2i(-1, -1),
]
const PATH_CACHE_MAX_ENTRIES: int = 512

const _WM = preload("res://autoloads/WorldMemory.gd")

var _astar: AStarGrid2D

## Per-tile connected component id. -1 = impassable tile. Same non-negative
## value on two tiles == you can walk from one to the other.
var _component_id: PackedInt32Array
var _largest_component_id_cached: int = -1

## Pending BUILD_WALL jobs: treat cell as impassable so paths route around
## planned walls. Cleared on job complete/cancel/world regen.
var _resv_job: PackedByteArray = PackedByteArray()
## Transient: drag preview for wall mode. Cleared each preview update.
var _resv_preview: PackedByteArray = PackedByteArray()
var _last_preview_tiles: Array[Vector2i] = []

# --- HeelKawnian historical-scar aversion (v1) ---
# Refreshed when WorldMemory records new history and Main reruns
# `WorldPersistence.recompute()`; applied only around
# `find_path_pawn_historic_aversion` so animals/enemies keep default 1.0 costs.
var _pawn_hist_scale: PackedFloat32Array = PackedFloat32Array()
var _pawn_hist_dirty: Array[int] = []
var _last_refresh_tick: int = -1

## Dirty flag for deferred component computation.
## sync_tile_from_data sets this instead of recomputing immediately.
## Call flush_component_dirty() once per tick to batch the recompute.
var _components_dirty: bool = false

var _path_cache: Dictionary = {}
var _path_cache_order: Array[String] = []
var _nav_version: int = 0
var path_cache_hits: int = 0
var path_cache_misses: int = 0
var paths_solved_this_tick: int = 0
var paths_solved_last_tick: int = 0
var max_paths_solved_in_tick: int = 0
var total_paths_solved: int = 0
var historic_paths_solved_total: int = 0
var plain_paths_solved_total: int = 0
var _path_solve_counter_tick: int = -1


func _init() -> void:
	_astar = AStarGrid2D.new()
	_astar.region = Rect2i(0, 0, WorldData.WIDTH, WorldData.HEIGHT)
	_astar.cell_size = Vector2.ONE
	# ONLY_IF_NO_OBSTACLES: diagonal move is forbidden unless BOTH adjacent cardinals
	# are walkable. This prevents "corner-cutting" where the straight-line lerp
	# between two diagonal tile centers would clip through a solid neighbor.
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_astar.update()
	_component_id.resize(WorldData.TILE_COUNT)
	_resv_job.resize(WorldData.TILE_COUNT)
	_resv_preview.resize(WorldData.TILE_COUNT)


## Rebuild solidity map + connected components for a freshly generated world.
## Uses `WorldData` features + biomes, plus any construction reservations.
func rebuild(data: WorldData) -> void:
	for i in range(WorldData.TILE_COUNT):
		_resv_job[i] = 0
		_resv_preview[i] = 0
	_last_preview_tiles.clear()
	for y in range(WorldData.HEIGHT):
		for x in range(WorldData.WIDTH):
			_refresh_one_tile(x, y, data)
	_compute_components(data)
	_bump_nav_version()


## After changing terrain in `data` (wall, door, mine-out), re-sync A* for one tile.
## Component computation is deferred — call flush_component_dirty() once per tick.
func sync_tile_from_data(x: int, y: int, data: WorldData) -> void:
	_refresh_one_tile(x, y, data)
	_components_dirty = true
	_bump_nav_version()


## Reserve / release a future wall cell for the job queue. `on=true` when a
## BUILD_WALL job is posted; `on=false` when it finishes or is cancelled.
func set_job_construction_reservation(x: int, y: int, on: bool, data: WorldData) -> void:
	if not _astar.region.has_point(Vector2i(x, y)):
		return
	var i: int = y * WorldData.WIDTH + x
	_resv_job[i] = 1 if on else 0
	_refresh_one_tile(x, y, data)
	_components_dirty = true
	_bump_nav_version()


## Reserve / release many future construction cells and recompute components once.
## This keeps autonomous wall blueprints from rebuilding the flood-fill for every tile.
func set_job_construction_reservations_batch(tiles: Array, enabled: bool, data: WorldData, _source: String = "") -> void:
	if data == null:
		return
	var touched: bool = false
	for v in tiles:
		if not (v is Vector2i):
			continue
		var t: Vector2i = v
		if not _astar.region.has_point(t):
			continue
		var i: int = t.y * WorldData.WIDTH + t.x
		_resv_job[i] = 1 if enabled else 0
		_refresh_one_tile(t.x, t.y, data)
		touched = true
	if touched:
		_components_dirty = true
		_bump_nav_version()


## Flush deferred component computation. Call once per tick (or once per frame).
## Returns true if a recompute happened.
func flush_component_dirty(data: WorldData) -> bool:
	if not _components_dirty:
		return false
	_components_dirty = false
	_compute_components(data)
	return true


## Update drag-preview for planned walls. Pass tile coords of cells that
## *would* get a valid wall job. Cleared when `tiles` is empty.
func set_preview_wall_tiles(tiles: Array, data: WorldData) -> void:
	for t in _last_preview_tiles:
		var i: int = t.y * WorldData.WIDTH + t.x
		_resv_preview[i] = 0
	_last_preview_tiles.clear()
	for v in tiles:
		if v is Vector2i:
			var t: Vector2i = v
			if not _astar.region.has_point(t):
				continue
			var i2: int = t.y * WorldData.WIDTH + t.x
			if _resv_job[i2] == 0:
				_resv_preview[i2] = 1
			_last_preview_tiles.append(t)
	for t2 in _last_preview_tiles:
		_refresh_one_tile(t2.x, t2.y, data)
	# Also recompute neighbors? Full recompute is fine at preview rate.
	_compute_components(data)
	_bump_nav_version()


## Legacy entry point: prefer `sync_tile_from_data` after data edits.
## Forces one tile from explicit passability (used by older call sites only).
## Deprecated: use `WorldData` + `sync_tile_from_data`.
func set_passable(x: int, y: int, passable: bool, data: WorldData) -> void:
	_astar.set_point_solid(Vector2i(x, y), not passable)
	_components_dirty = true
	_bump_nav_version()


func _refresh_one_tile(x: int, y: int, data: WorldData) -> void:
	var p := Vector2i(x, y)
	if not _astar.region.has_point(p):
		return
	var i3: int = y * WorldData.WIDTH + x
	var base_walk: bool = WorldData.is_tile_walkable(data, x, y)
	var block: bool = (not base_walk) or (_resv_job[i3] > 0) or (_resv_preview[i3] > 0)
	_astar.set_point_solid(p, block)


## Return the list of tiles to visit AFTER start to reach goal. Empty if:
##   - start == goal (already there),
##   - start or goal out of bounds,
##   - goal is solid,
##   - no path exists.
func find_path(start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	var cache_key: String = _path_cache_key(start, goal, &"plain")
	if _path_cache.has(cache_key):
		path_cache_hits += 1
		return _duplicate_path(_path_cache[cache_key])
	path_cache_misses += 1
	var out: Array[Vector2i] = _find_path_uncached(start, goal, &"plain")
	_store_path_cache(cache_key, out)
	return _duplicate_path(out)


func _find_path_uncached(start: Vector2i, goal: Vector2i, mode: StringName = &"plain") -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if start == goal:
		return out
	if not _astar.region.has_point(start) or not _astar.region.has_point(goal):
		return out
	if _astar.is_point_solid(goal):
		return out
	# Fast reject: different components means no hope of a path.
	if component_of(start) != component_of(goal):
		return out
	_record_path_solve(mode)
	var packed: PackedVector2Array = _astar.get_id_path(start, goal)
	if packed.size() <= 1:
		return out
	for i in range(1, packed.size()):
		out.append(Vector2i(packed[i]))
	return out


## Same as find_path, but pawns get higher move costs through WorldPersistence
## "scarred" map regions. Deterministic; no writes to persistence. Does not change
## passability; only A* point weight scales (see refresh_pawn_historic_scar_weights).
func find_path_pawn_historic_aversion(start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	for idx in _pawn_hist_dirty:
		var p: Vector2i = _idx_to_point(idx)
		if _astar.region.has_point(p):
			_astar.set_point_weight_scale(p, _pawn_hist_scale[idx])
	var out: Array[Vector2i] = _find_path_uncached(start, goal, &"historic")
	for idx2 in _pawn_hist_dirty:
		var p2: Vector2i = _idx_to_point(idx2)
		if _astar.region.has_point(p2):
			_astar.set_point_weight_scale(p2, 1.0)
	return out


## Rebuild per-tile move-cost multipliers from WorldMemory and WorldPersistence
## (read-only). Call after WorldPersistence recompute when history changed.
func refresh_pawn_historic_scar_weights(p_world: World) -> void:
	if GameManager.tick_count == _last_refresh_tick:
		return
	_last_refresh_tick = GameManager.tick_count
	_pawn_hist_dirty.clear()
	if _pawn_hist_scale.size() != WorldData.TILE_COUNT:
		_pawn_hist_scale.resize(WorldData.TILE_COUNT)
	# PERFORMANCE: Only iterate regions that have non-default weights.
	# Most of the map has scar_level=0, no roads, no trade, no myth state.
	# Instead of 65,536 tile iterations, only scan the ~100-300 affected regions.
	var dirty_regions: Dictionary = {}
	# Collect regions with scar levels
	if WorldPersistence != null:
		var scar_regions: Dictionary = WorldPersistence.get_regions_with_scar()
		for rk in scar_regions:
			dirty_regions[int(rk)] = true
	# Collect regions with myth states
	if MythMemory != null:
		var myth_regions: Dictionary = MythMemory.get_regions_with_myth_state()
		for rk in myth_regions:
			dirty_regions[int(rk)] = true
	# Collect regions with roads
	if RoadMemory != null:
		var road_regions: Dictionary = RoadMemory.get_regions_with_roads()
		for rk in road_regions:
			dirty_regions[int(rk)] = true
	# Collect regions with trade routes
	if TradeMemory != null:
		var trade_regions: Dictionary = TradeMemory.get_regions_with_trade()
		for rk in trade_regions:
			dirty_regions[int(rk)] = true
	# Collect regions with remnants
	if RemnantMemory != null and p_world != null and is_instance_valid(p_world) and p_world.data != null:
		var remnant_regions: Dictionary = RemnantMemory.get_regions_with_remnants()
		for rk in remnant_regions:
			dirty_regions[int(rk)] = true
	# Collect regions with abandoned settlements
	if SettlementMemory != null:
		var abandoned_regions: Dictionary = SettlementMemory.get_abandoned_regions()
		for rk in abandoned_regions:
			dirty_regions[int(rk)] = true
	# If no dirty regions, skip entirely
	if dirty_regions.is_empty():
		return
	# Only iterate tiles in dirty regions (16×16 tiles per region)
	for rk_any in dirty_regions:
		var rk: int = int(rk_any)
		var rx: int = rk & 0xFFFF
		var ry: int = (rk >> 16) & 0xFFFF
		var tx_start: int = rx * 16
		var ty_start: int = ry * 16
		var tx_end: int = mini(tx_start + 16, WorldData.WIDTH)
		var ty_end: int = mini(ty_start + 16, WorldData.HEIGHT)
		for ty in range(ty_start, ty_end):
			for tx in range(tx_start, tx_end):
				var i: int = ty * WorldData.WIDTH + tx
				_pawn_hist_scale[i] = 1.0
				if _astar.is_point_solid(Vector2i(tx, ty)):
					continue
				var tile_rk: int = _WM._region_key(tx, ty)
				# Only process tiles in dirty regions
				if not dirty_regions.has(tile_rk):
					continue
				var w: float = 1.0
				var sl: int = int(WorldPersistence.get_region_scar_level(tile_rk))
				if sl > 0:
					match sl:
						1:
							w = 1.10
						2:
							w = 1.36
						3:
							w = 1.78
						_:
							w = 1.0
					var mst: int = MythMemory.get_region_myth_state(tile_rk)
					if mst == 1:
						w *= 1.08
					elif mst == -1:
						w *= 0.95
				w *= RoadMemory.get_path_weight_mul(tx, ty)
				w *= TradeMemory.get_trade_path_weight_mul(tx, ty)
				if p_world != null and is_instance_valid(p_world) and p_world.data != null:
					if int(p_world.data.get_feature(tx, ty)) == TileFeature.Type.ROAD:
						w *= RoadMemory.PATH_W_T2
					w *= RemnantMemory.get_remnant_path_mul(tx, ty, p_world)
				_pawn_hist_scale[i] = w
				if not is_equal_approx(w, 1.0):
					_pawn_hist_dirty.append(i)


func _idx_to_point(i: int) -> Vector2i:
	# Integer row index (float div + int is stable for i in 0..TILE_COUNT-1).
	return Vector2i(
		i % WorldData.WIDTH,
		int(i / float(WorldData.WIDTH))
	)


func _clear_path_cache() -> void:
	_path_cache.clear()
	_path_cache_order.clear()


func _bump_nav_version() -> void:
	_nav_version += 1
	_clear_path_cache()


func _roll_path_solve_tick() -> void:
	var tick: int = GameManager.tick_count if GameManager != null else -1
	if tick == _path_solve_counter_tick:
		return
	if _path_solve_counter_tick >= 0:
		paths_solved_last_tick = paths_solved_this_tick
	paths_solved_this_tick = 0
	_path_solve_counter_tick = tick


func _record_path_solve(mode: StringName) -> void:
	_roll_path_solve_tick()
	paths_solved_this_tick += 1
	max_paths_solved_in_tick = maxi(max_paths_solved_in_tick, paths_solved_this_tick)
	total_paths_solved += 1
	if mode == &"historic":
		historic_paths_solved_total += 1
	else:
		plain_paths_solved_total += 1


func _path_cache_key(start: Vector2i, goal: Vector2i, mode: StringName) -> String:
	return "%s:%d:%d:%d:%d:%d" % [str(mode), _nav_version, start.x, start.y, goal.x, goal.y]


func _store_path_cache(cache_key: String, path: Array[Vector2i]) -> void:
	if _path_cache.has(cache_key):
		return
	if _path_cache_order.size() >= PATH_CACHE_MAX_ENTRIES:
		var old_key: String = _path_cache_order.pop_front()
		_path_cache.erase(old_key)
	_path_cache[cache_key] = _duplicate_path(path)
	_path_cache_order.append(cache_key)


func _duplicate_path(path: Array) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for v in path:
		if v is Vector2i:
			out.append(v)
	return out


## Find a passable tile next to `tile` (8-way). Used to park a pawn next to
## an impassable target (e.g. an ore vein on a mountain). Returns (-1,-1)
## if the tile is surrounded by impassable terrain.
func find_adjacent_passable(tile: Vector2i) -> Vector2i:
	for offset in NEIGHBOR_OFFSETS:
		var t: Vector2i = tile + offset
		if not _astar.region.has_point(t):
			continue
		if not _astar.is_point_solid(t):
			return t
	return Vector2i(-1, -1)


func is_passable(tile: Vector2i) -> bool:
	if not _astar.region.has_point(tile):
		return false
	return not _astar.is_point_solid(tile)


## Component id for a tile, or -1 if tile is impassable / out of bounds.
func component_of(tile: Vector2i) -> int:
	if tile.x < 0 or tile.x >= WorldData.WIDTH or tile.y < 0 or tile.y >= WorldData.HEIGHT:
		return -1
	return _component_id[tile.y * WorldData.WIDTH + tile.x]


## Return true if two tiles are in the same walkable component.
func are_reachable(a: Vector2i, b: Vector2i) -> bool:
	var ca: int = component_of(a)
	if ca < 0:
		return false
	return ca == component_of(b)


## Which connected component has the most tiles? Used to pick the "main
## continent" for placing the colony's stockpile and restricting pawn spawns
## to the same landmass.
func largest_component_id() -> int:
	return _largest_component_id_cached


## Find a tile belonging to `comp_id` closest to `center`. Used to place the
## stockpile at world center while guaranteeing it's on the main landmass.
## Returns (-1,-1) if the component has no tile within max_radius of center.
func find_tile_in_component_near(comp_id: int, center: Vector2i, max_radius: int = 128) -> Vector2i:
	if component_of(center) == comp_id:
		return center
	for r in range(1, max_radius + 1):
		# Check the ring of distance r (Chebyshev) around center.
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if abs(dx) != r and abs(dy) != r:
					continue
				var t: Vector2i = center + Vector2i(dx, dy)
				if component_of(t) == comp_id:
					return t
	return Vector2i(-1, -1)


# -------------------- internals --------------------

## Drives off A* solidity (set_point_solid), NOT raw biome data, so anything
## that flips passability after generation -- mined-out walls, built walls,
## bridges -- shows up in the component map. Otherwise pawns would happily
## try to path through a wall they just built.
func _compute_components(_data: WorldData) -> void:
	_component_id.resize(WorldData.TILE_COUNT)
	for i in range(_component_id.size()):
		_component_id[i] = -1
	var current_id: int = 0
	var best_id: int = -1
	var best_size: int = 0
	var queue: Array[Vector2i] = []
	for y in range(WorldData.HEIGHT):
		for x in range(WorldData.WIDTH):
			var idx: int = y * WorldData.WIDTH + x
			if _component_id[idx] != -1:
				continue
			var here := Vector2i(x, y)
			if _astar.is_point_solid(here):
				continue
			queue.clear()
			queue.append(here)
			_component_id[idx] = current_id
			var comp_size: int = 1
			while not queue.is_empty():
				var t: Vector2i = queue.pop_back()
				for offset in NEIGHBOR_OFFSETS:
					var nx: int = t.x + offset.x
					var ny: int = t.y + offset.y
					if nx < 0 or nx >= WorldData.WIDTH or ny < 0 or ny >= WorldData.HEIGHT:
						continue
					var nidx: int = ny * WorldData.WIDTH + nx
					if _component_id[nidx] != -1:
						continue
					var n := Vector2i(nx, ny)
					if _astar.is_point_solid(n):
						continue
					# Diagonal step: mirror AStarGrid2D DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES.
					# Both cardinal neighbors must also be walkable, otherwise A*
					# will refuse this diagonal and the two tiles are really in
					# different components for path purposes.
					if offset.x != 0 and offset.y != 0:
						if _astar.is_point_solid(Vector2i(nx, t.y)):
							continue
						if _astar.is_point_solid(Vector2i(t.x, ny)):
							continue
					_component_id[nidx] = current_id
					comp_size += 1
					queue.append(n)
			if comp_size > best_size:
				best_size = comp_size
				best_id = current_id
			current_id += 1
	_largest_component_id_cached = best_id
