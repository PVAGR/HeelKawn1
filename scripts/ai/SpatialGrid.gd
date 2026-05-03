class_name SpatialGrid
extends RefCounted

## WorldBox-scale spatial partitioning for O(n) pawn lookups
## Replaces O(n²) scans when finding nearby enemies/social targets
## Grid cell size: 128px (8×8 tiles) — balances granularity vs overhead

const CELL_SIZE_PX: int = 128
const WORLD_SIZE_PX: int = 8192  # 512 regions × 16 tiles × 1px (assume 1px = 1 tile)
const GRID_DIMS: int = WORLD_SIZE_PX / CELL_SIZE_PX  # ~64×64 grid

var _grid: Array = []  # 2D array: _grid[x][y] = PackedInt32Array of pawn_ids
var _pawn_pos: Dictionary = {}  # pawn_id -> Vector2 (pixel coords)
var _dirty: bool = true
var _last_rebuild_tick: int = -100000

func _ready() -> void:
	_init_grid()

func _init_grid() -> void:
	_grid = []
	for x in range(GRID_DIMS):
		_grid.append([])
		for y in range(GRID_DIMS):
			_grid[x].append(PackedInt32Array())

func rebuild(pawns: Array) -> void:
	## Rebuild grid from live pawn list (call every ~200 ticks or on pawn death/spawn)
	_clear_grid()
	for p in pawns:
		if p == null or not is_instance_valid(p):
			continue
		if p.data == null:
			continue
		var pid: int = int(p.data.id)
		var pos: Vector2 = p.position
		_pawn_pos[pid] = pos
		_insert_into_grid(pid, pos)
	_dirty = false
	_last_rebuild_tick = GameManager.tick_count if GameManager != null else 0

func _clear_grid() -> void:
	for x in range(GRID_DIMS):
		for y in range(GRID_DIMS):
			(_grid[x][y] as PackedInt32Array).clear()
	_pawn_pos.clear()

func _insert_into_grid(pawn_id: int, pos: Vector2) -> void:
	var gx: int = clampi(int(pos.x / CELL_SIZE_PX), 0, GRID_DIMS - 1)
	var gy: int = clampi(int(pos.y / CELL_SIZE_PX), 0, GRID_DIMS - 1)
	if gx < 0 or gx >= GRID_DIMS or gy < 0 or gy >= GRID_DIMS:
		return
	var cell: PackedInt32Array = _grid[gx][gy] as PackedInt32Array
	cell.append(pawn_id)
	_grid[gx][gy] = cell

func get_nearby_pawns(pos: Vector2, radius_px: float) -> Array[int]:
	## O(1) grid lookup + O(k) scan of neighboring cells (k = cells in radius)
	## Returns array of pawn_ids within radius_px of pos
	var result: Array[int] = []
	var center_gx: int = int(pos.x / CELL_SIZE_PX)
	var center_gy: int = int(pos.y / CELL_SIZE_PX)
	var cell_radius: int = ceili(float(radius_px) / float(CELL_SIZE_PX))
	
	for dx in range(-cell_radius, cell_radius + 1):
		var gx: int = center_gx + dx
		if gx < 0 or gx >= GRID_DIMS:
			continue
		for dy in range(-cell_radius, cell_radius + 1):
			var gy: int = center_gy + dy
			if gy < 0 or gy >= GRID_DIMS:
				continue
			var cell: PackedInt32Array = _grid[gx][gy] as PackedInt32Array
			for pid_any in cell:
				var pid: int = int(pid_any)
				var ppos_v: Variant = _pawn_pos.get(pid, null)
				if ppos_v == null:
					continue
				var ppos: Vector2 = ppos_v as Vector2
				if ppos.distance_to(pos) <= radius_px:
					result.append(pid)
	return result

func get_nearby_pawns_excluding(pos: Vector2, radius_px: float, exclude_id: int) -> Array[int]:
	## Same as get_nearby_pawns but excludes one pawn (self)
	var raw: Array[int] = get_nearby_pawns(pos, radius_px)
	var result: Array[int] = []
	for pid in raw:
		if pid != exclude_id:
			result.append(pid)
	return result

func update_pawn_position(pawn_id: int, new_pos: Vector2) -> void:
	## Incrementally update one pawn's position (call on significant movement)
	## Falls back to full rebuild if position unknown
	var old_pos_v: Variant = _pawn_pos.get(pawn_id, null)
	if old_pos_v == null:
		_dirty = true
		return
	var old_pos: Vector2 = old_pos_v as Vector2
	var old_gx: int = int(old_pos.x / CELL_SIZE_PX)
	var old_gy: int = int(old_pos.y / CELL_SIZE_PX)
	var new_gx: int = int(new_pos.x / CELL_SIZE_PX)
	var new_gy: int = int(new_pos.y / CELL_SIZE_PX)
	if old_gx == new_gx and old_gy == new_gy:
		_pawn_pos[pawn_id] = new_pos
		return
	## Remove from old cell
	if old_gx >= 0 and old_gx < GRID_DIMS and old_gy >= 0 and old_gy < GRID_DIMS:
		var old_cell: PackedInt32Array = _grid[old_gx][old_gy] as PackedInt32Array
		var new_cell: PackedInt32Array = PackedInt32Array()
		for v in old_cell:
			if int(v) != pawn_id:
				new_cell.append(v)
		_grid[old_gx][old_gy] = new_cell
	## Insert into new cell
	if new_gx >= 0 and new_gx < GRID_DIMS and new_gy >= 0 and new_gy < GRID_DIMS:
		var new_cell2: PackedInt32Array = _grid[new_gx][new_gy] as PackedInt32Array
		new_cell2.append(pawn_id)
		_grid[new_gx][new_gy] = new_cell2
	_pawn_pos[pawn_id] = new_pos

func should_rebuild() -> bool:
	## Returns true if grid hasn't been rebuilt in 200+ ticks (stale)
	if GameManager == null:
		return _dirty
	return _dirty or (GameManager.tick_count - _last_rebuild_tick) > 200

static func pixel_from_tile(tile: Vector2i) -> Vector2:
	## Convert tile coords to pixel coords (assume 1 tile = 1px for grid purposes)
	return Vector2(tile.x, tile.y)
