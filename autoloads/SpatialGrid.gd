extends Node
## SpatialGrid - Grid-based spatial partitioning for O(1) neighbor queries
##
## Divides the world into grid cells. Objects only check neighbors in
## their cell and adjacent cells, reducing complexity from O(N²) to O(N*k)
## where k is a small constant.
##
## Usage:
##   SpatialGrid.insert(pawn, pawn.data.tile_pos)
##   var neighbors = SpatialGrid.query_radius(pawn.data.tile_pos, 5)
##   SpatialGrid.remove(pawn)

# Grid configuration
const CELL_SIZE: int = 16  # Tiles per cell
const CELL_CACHE_SIZE: int = 8  # Cache this many cells

# Grid data: cell_key -> Array of objects
var grid: Dictionary = {}

# Object tracking: object_id -> {object, tile, cell_key}
var object_positions: Dictionary = {}

# Performance tracking
var stats: Dictionary = {
	"total_objects": 0,
	"total_cells": 0,
	"queries_this_frame": 0,
	"average_query_time_us": 0.0,
	"inserts": 0,
	"removes": 0
}

# Cell cache for performance
var _cell_cache: Dictionary = {}
var _cache_hits: int = 0
var _cache_misses: int = 0


func _ready() -> void:
	GameManager.game_tick.connect(_on_game_tick)


func _on_game_tick(tick: int) -> void:
	# Reset per-frame stats
	stats.queries_this_frame = 0
	
	# Clear cell cache periodically (every 100 ticks)
	if tick % 100 == 0:
		_cell_cache.clear()
		_cache_hits = 0
		_cache_misses = 0


## Convert tile position to cell key
static func _tile_to_cell_key(tile: Vector2i) -> String:
	var cell_x: int = int(floor(float(tile.x) / float(CELL_SIZE)))
	var cell_y: int = int(floor(float(tile.y) / float(CELL_SIZE)))
	return "%d,%d" % [cell_x, cell_y]


## Get cell key from coordinates
static func _coords_to_cell_key(x: int, y: int) -> String:
	var cell_x: int = int(floor(float(x) / float(CELL_SIZE)))
	var cell_y: int = int(floor(float(y) / float(CELL_SIZE)))
	return "%d,%d" % [cell_x, cell_y]


## Insert an object into the grid
func insert(object: Node, tile: Vector2i) -> void:
	if object == null:
		return
	
	var cell_key: String = _tile_to_cell_key(tile)
	
	# Get or create cell
	var cell: Array
	if grid.has(cell_key):
		cell = grid[cell_key]
	else:
		cell = []
		grid[cell_key] = cell
		stats.total_cells += 1
	
	# Add object to cell
	cell.append(object)
	
	# Track object position
	var object_id: int = _get_object_id(object)
	object_positions[object_id] = {
		"object": object,
		"tile": tile,
		"cell_key": cell_key
	}
	
	stats.total_objects = object_positions.size()
	stats.inserts += 1


## Remove an object from the grid
func remove(object: Node) -> void:
	if object == null:
		return
	
	var object_id: int = _get_object_id(object)
	
	if not object_positions.has(object_id):
		return  # Object not in grid
	
	var info: Dictionary = object_positions[object_id]
	var cell_key: String = info.cell_key
	
	if grid.has(cell_key):
		var cell: Array = grid[cell_key]
		var idx: int = cell.find(object)
		if idx >= 0:
			cell.remove_at(idx)
		
		# Remove empty cells
		if cell.is_empty():
			grid.erase(cell_key)
			stats.total_cells -= 1
	
	object_positions.erase(object_id)
	stats.total_objects = object_positions.size()
	stats.removes += 1


## Update an object's position
func update_position(object: Node, new_tile: Vector2i) -> void:
	if object == null:
		return
	
	var object_id: int = _get_object_id(object)
	
	if not object_positions.has(object_id):
		# Object not in grid, insert it
		insert(object, new_tile)
		return
	
	var old_info: Dictionary = object_positions[object_id]
	var old_cell_key: String = old_info.cell_key
	
	if old_cell_key == _tile_to_cell_key(new_tile):
		# Same cell, just update tile
		old_info.tile = new_tile
		return
	
	# Different cell, remove and re-insert
	remove(object)
	insert(object, new_tile)


## Query objects in a radius around a tile
func query_radius(tile: Vector2i, radius: int) -> Array:
	var start_time: int = Time.get_ticks_usec()
	stats.queries_this_frame += 1
	
	var results: Array = []
	var seen: Dictionary = {}  # Avoid duplicates
	
	# Calculate cell range
	var cell_radius: int = int(ceil(float(radius) / float(CELL_SIZE)))
	var center_cell_x: int = int(floor(float(tile.x) / float(CELL_SIZE)))
	var center_cell_y: int = int(floor(float(tile.y) / float(CELL_SIZE)))
	
	# Query all cells in range
	for dx in range(-cell_radius, cell_radius + 1):
		for dy in range(-cell_radius, cell_radius + 1):
			var cell_key: String = "%d,%d" % [center_cell_x + dx, center_cell_y + dy]
			
			# Check cache first
			var cell: Array
			if _cell_cache.has(cell_key):
				cell = _cell_cache[cell_key]
				_cache_hits += 1
			elif grid.has(cell_key):
				cell = grid[cell_key]
				_cell_cache[cell_key] = cell
				if _cell_cache.size() > CELL_CACHE_SIZE:
					# Remove oldest entry
					var oldest_key: String = _cell_cache.keys()[0]
					_cell_cache.erase(oldest_key)
				_cache_misses += 1
			else:
				continue  # Empty cell
			
			# Check objects in cell
			for obj in cell:
				if obj == null or not is_instance_valid(obj):
					continue
				
				var obj_id: int = _get_object_id(obj)
				if seen.has(obj_id):
					continue
				
				# Check actual distance
				if object_positions.has(obj_id):
					var obj_tile: Vector2i = object_positions[obj_id].tile
					var dist: int = abs(tile.x - obj_tile.x) + abs(tile.y - obj_tile.y)
					
					if dist <= radius:
						results.append(obj)
						seen[obj_id] = true
	
	# Track query time
	var query_time: int = Time.get_ticks_usec() - start_time
	stats.average_query_time_us = lerp(stats.average_query_time_us, float(query_time), 0.1)
	
	return results


## Query objects in a specific cell
func query_cell(cell_key: String) -> Array:
	if not grid.has(cell_key):
		return []
	
	# Return copy to prevent modification during iteration
	return grid[cell_key].duplicate()


## Query objects at a specific tile
func query_tile(tile: Vector2i) -> Array:
	var cell_key: String = _tile_to_cell_key(tile)
	return query_cell(cell_key)


## Get all objects in the grid
func get_all_objects() -> Array:
	return object_positions.values().map(func(info): return info.object)


## Get object count
func get_object_count() -> int:
	return stats.total_objects


## Get cell count
func get_cell_count() -> int:
	return stats.total_cells


## Clear the entire grid
func clear() -> void:
	grid.clear()
	object_positions.clear()
	_cell_cache.clear()
	stats = {
		"total_objects": 0,
		"total_cells": 0,
		"queries_this_frame": 0,
		"average_query_time_us": 0.0,
		"inserts": 0,
		"removes": 0
	}


func _get_object_id(object: Node) -> int:
	# Try to get unique ID from object
	if object.has_method("get_pawn_data") and object.get_pawn_data() != null:
		return int(object.get_pawn_data().id)
	
	if object.has_meta("object_id"):
		return object.get_meta("object_id")
	
	# Fallback: use instance ID
	return object.get_instance_id()


## Get statistics
func get_stats() -> Dictionary:
	return stats.duplicate()


## Get cache statistics
func get_cache_stats() -> Dictionary:
	var total: int = _cache_hits + _cache_misses
	return {
		"hits": _cache_hits,
		"misses": _cache_misses,
		"hit_rate": float(_cache_hits) / float(total) * 100.0 if total > 0 else 0.0,
		"cache_size": _cell_cache.size()
	}


## Debug: Print statistics
func debug_print_stats() -> void:
	if not OS.is_debug_build():
		return
	
	print("\n=== SPATIAL GRID STATISTICS ===")
	print("Total Objects: %d" % stats.total_objects)
	print("Total Cells: %d" % stats.total_cells)
	print("Queries This Frame: %d" % stats.queries_this_frame)
	print("Average Query Time: %.2f µs" % stats.average_query_time_us)
	print("Inserts: %d | Removes: %d" % [stats.inserts, stats.removes])
	
	var cache_stats: Dictionary = get_cache_stats()
	print("Cache Hit Rate: %.1f%% (%d/%d)" % [
		cache_stats.hit_rate,
		cache_stats.hits,
		cache_stats.hits + cache_stats.misses
	])
	
	# Calculate complexity improvement
	if stats.total_objects > 0:
		var naive_complexity: int = stats.total_objects * stats.total_objects
		var grid_complexity: int = stats.total_objects * 9  # Assume avg 9 cells queried
		var improvement: float = float(naive_complexity - grid_complexity) / float(naive_complexity) * 100.0
		print("Complexity Reduction: %.1f%% (%d → %d operations)" % [
			improvement,
			naive_complexity,
			grid_complexity
		])
	
	print("=== END STATISTICS ===\n")
