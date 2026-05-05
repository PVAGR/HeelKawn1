class_name CommandMode
extends Node

## Right-click command system for selected pawns.
## Context-sensitive: right-clicking ground = move, resource = harvest, enemy = attack.
## Also handles zone designation painting (forage/build/defend zones).

signal command_issued(pawn: Pawn, order_type: String, target_tile: Vector2i)
signal zone_painted(zone_type: String, rect: Rect2i)

## Zone types for designation painting
enum ZoneType {
	NONE,
	FORAGE_ZONE,   # prioritize forage jobs in this area
	BUILD_ZONE,    # prioritize build jobs in this area
	DEFEND_ZONE,   # warriors patrol this area
	STORAGE_ZONE,  # stockpile zone (existing behavior)
}

const ZONE_MAX_AREA: int = 400  # 20x20 max
const COMMAND_COOLDOWN_TICKS: int = 5

var _world: World = null
var _camera: Camera2D = null
var _pawn_spawner: PawnSpawner = null
var _selected_pawn: Pawn = null
var _last_command_tick: int = -COMMAND_COOLDOWN_TICKS
var _zone_type: int = ZoneType.NONE
var _is_painting: bool = false
var _paint_start: Vector2i = Vector2i(-1, -1)
var _paint_current: Vector2i = Vector2i(-1, -1)
## Callback set by Main: Callable(target: Pawn) -> bool. Returns true if the
## player is allowed to command the given pawn (God mode = always, Incarnated =
## must outrank, Spectator = never). If null, commands are always allowed.
var can_command_callback: Callable = Callable()


func initialize(world_ref: World, camera_ref: Camera2D, spawner_ref: PawnSpawner) -> void:
	_world = world_ref
	_camera = camera_ref
	_pawn_spawner = spawner_ref


func set_selected_pawn(pawn: Pawn) -> void:
	_selected_pawn = pawn


func set_zone_type(zone_type: int) -> void:
	_zone_type = zone_type
	_is_painting = false


## Handle right-click with a selected pawn: issue context command
func handle_right_click(world_pos: Vector2) -> bool:
	if _world == null or _selected_pawn == null or not is_instance_valid(_selected_pawn):
		return false
	if _selected_pawn.data == null:
		return false
	# Authority check: can the player command this pawn?
	if can_command_callback.is_valid():
		if not can_command_callback.call(_selected_pawn):
			return false

	var tick: int = GameManager.tick_count
	if tick - _last_command_tick < COMMAND_COOLDOWN_TICKS:
		return false

	var tile: Vector2i = _world.world_to_tile(world_pos)
	if not _world.data.in_bounds(tile.x, tile.y):
		return false

	var order_type: String = _determine_order(tile)
	if order_type.is_empty():
		return false

	_execute_order(order_type, tile)
	_last_command_tick = tick
	command_issued.emit(_selected_pawn, order_type, tile)
	return true


## Determine what order to give based on target tile context
func _determine_order(tile: Vector2i) -> String:
	var feature: int = _world.data.get_feature(tile.x, tile.y)
	var biome: int = _world.data.get_biome(tile.x, tile.y)

	# Check for enemies at tile
	var enemies: Array = _world.get_tree().get_nodes_in_group("enemies")
	for e in enemies:
		if e == null or not is_instance_valid(e):
			continue
		var e_tile: Vector2i = _world.world_to_tile(e.global_position)
		if e_tile == tile:
			return "defend"

	# Feature-based orders
	match feature:
		TileFeature.Type.FERTILE_SOIL:
			return "forage"
		TileFeature.Type.ORE_VEIN:
			return "mine"
		TileFeature.Type.TREE:
			return "chop"
		TileFeature.Type.RABBIT, TileFeature.Type.DEER:
			return "hunt"
		TileFeature.Type.RUIN:
			return "move"  # Ruins are interesting — move there to investigate
		TileFeature.Type.NONE:
			# Check biome for forage opportunities
			match biome:
				Biome.Type.FOREST, Biome.Type.PLAINS:
					# If passable, just move. If there's a tree adjacent, forage.
					if _world.pathfinder.is_passable(tile):
						return "move"
					return "move"
				_:
					if _world.pathfinder.is_passable(tile):
						return "move"
					return ""

	# Default: move to tile if passable
	if _world.pathfinder.is_passable(tile):
		return "move"
	return ""


## Execute the order on the selected pawn
func _execute_order(order_type: String, tile: Vector2i) -> void:
	if _selected_pawn == null or not is_instance_valid(_selected_pawn):
		return

	match order_type:
		"move":
			_selected_pawn.draft_goto(tile)
		"forage":
			_post_job_for_pawn(Job.Type.FORAGE, tile)
		"mine":
			_post_job_for_pawn(Job.Type.MINE, tile)
		"chop":
			_post_job_for_pawn(Job.Type.CHOP, tile)
		"hunt":
			_post_job_for_pawn(Job.Type.HUNT, tile)
		"defend":
			# Path toward the threat location
			_selected_pawn.draft_goto(tile)
		_:
			_selected_pawn.draft_goto(tile)


## Post a specific job and assign it to the selected pawn
func _post_job_for_pawn(job_type: int, tile: Vector2i) -> void:
	# Release any current job first to avoid leaking it in JobManager._claimed
	if _selected_pawn._current_job != null:
		_selected_pawn.release_job_if_any()

	# Use JobManager.post() which handles dedup, ID assignment, and registration
	var work_tile: Vector2i = _find_work_tile(tile, job_type)
	var ticks: int = _work_ticks_for_type(job_type)
	var job: Job = JobManager.post(job_type, tile, 10, ticks)
	if job == null:
		# Tile already has a job — just move the pawn there
		_selected_pawn.draft_goto(work_tile)
		return

	# Set work_tile after post (post defaults to tile)
	job.work_tile = work_tile

	# Immediately claim for the selected pawn
	if _selected_pawn != null and is_instance_valid(_selected_pawn):
		var claimed: Job = JobManager.claim_by_id_for(_selected_pawn, job.id)
		if claimed != null:
			_selected_pawn._begin_job(claimed)


func _find_work_tile(tile: Vector2i, job_type: int) -> Vector2i:
	# For forage/chop, the pawn works on the tile itself
	if job_type == Job.Type.FORAGE or job_type == Job.Type.CHOP:
		return tile
	# For mine, find adjacent passable tile
	if job_type == Job.Type.MINE:
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				if dx == 0 and dy == 0:
					continue
				var neighbor: Vector2i = Vector2i(tile.x + dx, tile.y + dy)
				if _world.data.in_bounds(neighbor.x, neighbor.y) and _world.pathfinder.is_passable(neighbor):
					return neighbor
	return tile


func _work_ticks_for_type(job_type: int) -> int:
	match job_type:
		Job.Type.FORAGE: return 20
		Job.Type.MINE: return 30
		Job.Type.CHOP: return 25
		Job.Type.HUNT: return 35
		Job.Type.MINE_WALL: return 35
		_: return 20


## Zone painting: start drag
func start_zone_paint(screen_pos: Vector2) -> void:
	if _world == null or _zone_type == ZoneType.NONE:
		return
	var tile: Vector2i = _world.world_to_tile(_camera.get_global_mouse_position())
	if not _world.data.in_bounds(tile.x, tile.y):
		return
	_is_painting = true
	_paint_start = tile
	_paint_current = tile


## Zone painting: update drag
func update_zone_paint(screen_pos: Vector2) -> void:
	if not _is_painting or _world == null:
		return
	var tile: Vector2i = _world.world_to_tile(_camera.get_global_mouse_position())
	if _world.data.in_bounds(tile.x, tile.y):
		_paint_current = tile


## Zone painting: commit drag
func commit_zone_paint() -> void:
	if not _is_painting or _world == null:
		_is_painting = false
		return
	_is_painting = false

	var rect: Rect2i = _normalize_rect(_paint_start, _paint_current)
	if rect.size.x * rect.size.y > ZONE_MAX_AREA:
		return
	if rect.size.x <= 0 or rect.size.y <= 0:
		return

	var zone_name: String = ""
	match _zone_type:
		ZoneType.FORAGE_ZONE:
			zone_name = "forage"
			ZoneRegistry.register(ZoneRegistry.ZoneType.FORAGE, rect)
		ZoneType.BUILD_ZONE:
			zone_name = "build"
			ZoneRegistry.register(ZoneRegistry.ZoneType.BUILD, rect)
		ZoneType.DEFEND_ZONE:
			zone_name = "defend"
			ZoneRegistry.register(ZoneRegistry.ZoneType.DEFEND, rect)
		ZoneType.STORAGE_ZONE:
			zone_name = "storage"
			# Storage zone handled by existing _commit_zone_rect

	zone_painted.emit(zone_name, rect)
	if OS.is_debug_build():
		print("[CommandMode] Zone %s painted at %s (%dx%d)" % [zone_name, rect.position, rect.size.x, rect.size.y])


func _normalize_rect(a: Vector2i, b: Vector2i) -> Rect2i:
	var x: int = mini(a.x, b.x)
	var y: int = mini(a.y, b.y)
	var w: int = absi(b.x - a.x) + 1
	var h: int = absi(b.y - a.y) + 1
	return Rect2i(x, y, w, h)


## Get the current paint rect for visual feedback
func get_paint_rect() -> Rect2i:
	if not _is_painting:
		return Rect2i()
	return _normalize_rect(_paint_start, _paint_current)
