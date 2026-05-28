extends RefCounted
class_name BuildPlacementChecker

static func wall_is_safe(tile: Vector2i, world: Node) -> bool:
	if world == null: return true
	var pf = _get_pathfinder(world)
	if pf == null: return true
	if not _tile_is_passable(tile, world): return true
	var passable_neighbors: Array[Vector2i] = []
	for offset in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
		var nb: Vector2i = tile + offset
		if _tile_is_passable(nb, world):
			passable_neighbors.append(nb)
	if passable_neighbors.size() <= 1: return true
	var anchor: Vector2i = passable_neighbors[0]
	var reachable: Dictionary = _flood_fill_excluding(anchor, tile, world)
	for i in range(1, passable_neighbors.size()):
		if not reachable.has(passable_neighbors[i]):
			return false
	return true

static func _get_pathfinder(world: Node):
	if world.has_method("get_pathfinder"): return world.get_pathfinder()
	if world.get("_path_finder") != null: return world._path_finder
	return null

static func _tile_is_passable(tile: Vector2i, world: Node) -> bool:
	var pf = _get_pathfinder(world)
	if pf != null and pf.has_method("is_passable"): return pf.is_passable(tile)
	if world.has_method("is_tile_passable"): return world.is_tile_passable(tile)
	if world.has_method("is_walkable"): return world.is_walkable(tile)
	return true

static func _flood_fill_excluding(start: Vector2i, blocked: Vector2i, world: Node) -> Dictionary:
	var visited: Dictionary = {}
	var queue: Array[Vector2i] = [start]
	var DIRS: Array[Vector2i] = [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]
	var limit: int = 4096
	while queue.size() > 0 and limit > 0:
		limit -= 1
		var current: Vector2i = queue.pop_front()
		if visited.has(current): continue
		visited[current] = true
		for d in DIRS:
			var nb: Vector2i = current + d
			if nb == blocked or visited.has(nb): continue
			if _tile_is_passable(nb, world): queue.append(nb)
	return visited
