extends Node2D
## Draws multi-pixel building sprites, tree/vegetation sprites, road autotiling,
## and construction progress bars on top of the terrain Image.
## This avoids changing the core 256×256 terrain pipeline.

const REFRESH_EVERY_N_TICKS: int = 30
const MAX_DRAW_TILES: int = 8000  # Performance cap: don't draw more than this per frame

var _world: World = null
var _camera: Camera2D = null
var _tick_counter: int = 0
var _dirty: bool = true  # Redraw on first frame

# Cache: which features exist and where (rebuilt every REFRESH_EVERY_N_TICKS)
var _feature_tiles: Dictionary = {}  # feature_type -> Array[Vector2i]

# Construction progress: job_id -> {tile: Vector2i, progress: float}
var _build_progress: Dictionary = {}


func initialize(world_ref: World, camera_ref: Camera2D) -> void:
	_world = world_ref
	_camera = camera_ref
	z_index = 5  # Above terrain (0), below pawns (10)


func mark_dirty() -> void:
	_dirty = true


func _process(_delta: float) -> void:
	_tick_counter += 1
	if _tick_counter % REFRESH_EVERY_N_TICKS == 0 or _dirty:
		_rebuild_feature_cache()
		_refresh_build_progress()
		_dirty = false
		queue_redraw()


func _rebuild_feature_cache() -> void:
	_feature_tiles.clear()
	if _world == null or _world.data == null:
		return
	var data: WorldData = _world.data
	# Only scan tiles in camera viewport for performance
	var cam_rect: Rect2i = _camera_viewport_tiles()
	for y in range(cam_rect.position.y, cam_rect.end.y):
		for x in range(cam_rect.position.x, cam_rect.end.x):
			if not data.in_bounds(x, y):
				continue
			var f: int = data.features[data.index(x, y)]
			if f == TileFeature.Type.NONE:
				continue
			if not _feature_tiles.has(f):
				_feature_tiles[f] = []
			_feature_tiles[f].append(Vector2i(x, y))


func _camera_viewport_tiles() -> Rect2i:
	if _camera == null or _world == null:
		return Rect2i(0, 0, WorldData.WIDTH, WorldData.HEIGHT)
	var cam_pos: Vector2 = _camera.global_position
	var zoom: float = _camera.zoom.x if _camera.zoom.x > 0 else 1.0
	# Approximate visible area in tiles
	var viewport_size: Vector2 = _camera.get_viewport().get_visible_rect().size
	var half_tiles: Vector2 = viewport_size / (2.0 * zoom * World.TILE_PIXELS)
	var min_x: int = int(cam_pos.x / World.TILE_PIXELS - half_tiles.x) - 2
	var min_y: int = int(cam_pos.y / World.TILE_PIXELS - half_tiles.y) - 2
	var max_x: int = int(cam_pos.x / World.TILE_PIXELS + half_tiles.x) + 2
	var max_y: int = int(cam_pos.y / World.TILE_PIXELS + half_tiles.y) + 2
	return Rect2i(
		maxi(0, min_x), maxi(0, min_y),
		mini(WorldData.WIDTH, max_x) - maxi(0, min_x),
		mini(WorldData.HEIGHT, max_y) - maxi(0, min_y)
	)


func _refresh_build_progress() -> void:
	_build_progress.clear()
	if JobManager == null:
		return
	var claimed: Array = JobManager.get_claimed_jobs()
	for job in claimed:
		if job == null:
			continue
		# Only show progress for build jobs
		var is_build: bool = _is_build_job_type(job.type)
		if not is_build:
			continue
		var progress: float = 0.0
		if job.work_ticks_needed > 0:
			progress = clampf(float(job.work_ticks_done) / float(job.work_ticks_needed), 0.0, 1.0)
		_build_progress[job.tile] = progress


func _is_build_job_type(t: int) -> bool:
	return (
		t == Job.Type.BUILD_BED or t == Job.Type.BUILD_WALL or t == Job.Type.BUILD_DOOR
		or t == Job.Type.BUILD_FIRE_PIT or t == Job.Type.BUILD_STORAGE_HUT
		or t == Job.Type.BUILD_MARKER_STONE or t == Job.Type.BUILD_SHRINE
		or t == Job.Type.BUILD_SHELTER or t == Job.Type.BUILD_HEARTH
		or t == Job.Type.BUILD_FARM_WHEAT or t == Job.Type.BUILD_FARM_CORN
		or t == Job.Type.BUILD_FARM_VEGETABLES or t == Job.Type.BUILD_HERB_GARDEN
		or t == Job.Type.BUILD_WORKSHOP or t == Job.Type.BUILD_LOOM
		or t == Job.Type.BUILD_KILN or t == Job.Type.BUILD_SMELTER
		or t == Job.Type.BUILD_BOATYARD or t == Job.Type.BUILD_DOCK
		or t == Job.Type.BUILD_FISHERMAN_HUT or t == Job.Type.BUILD_APOTHECARY
		or t == Job.Type.BUILD_LIBRARY or t == Job.Type.BUILD_SCHOOL
		or t == Job.Type.BUILD_BARRACKS or t == Job.Type.BUILD_WATCHTOWER
		or t == Job.Type.BUILD_MARKET or t == Job.Type.BUILD_TRADING_POST
		or t == Job.Type.BUILD_ROAD or t == Job.Type.BUILD_GRANARY
		or t == Job.Type.BUILD_CELLAR
	)


func _draw() -> void:
	if _world == null or _world.data == null:
		return
	var drawn: int = 0
	# Draw each feature type with its sprite
	for f_type in _feature_tiles:
		var tiles: Array = _feature_tiles[f_type]
		for tile_pos in tiles:
			if drawn >= MAX_DRAW_TILES:
				return
			var wp: Vector2 = _world.tile_to_world(tile_pos)
			_draw_feature_sprite(wp, int(f_type))
			drawn += 1
	# Draw construction progress bars
	for tile_pos in _build_progress:
		var progress: float = _build_progress[tile_pos]
		var wp: Vector2 = _world.tile_to_world(tile_pos)
		_draw_build_progress(wp, progress)


func _draw_feature_sprite(wp: Vector2, feature: int) -> void:
	match feature:
		TileFeature.Type.FIRE_PIT:
			_draw_fire_pit(wp)
		TileFeature.Type.BED:
			_draw_bed(wp)
		TileFeature.Type.WALL:
			_draw_wall(wp)
		TileFeature.Type.DOOR:
			_draw_door(wp)
		TileFeature.Type.STORAGE_HUT:
			_draw_storage_hut(wp)
		TileFeature.Type.SHRINE:
			_draw_shrine(wp)
		TileFeature.Type.MARKER_STONE:
			_draw_marker_stone(wp)
		TileFeature.Type.TREE:
			_draw_tree(wp)
		TileFeature.Type.FERTILE_SOIL:
			_draw_fertile_soil(wp)
		TileFeature.Type.ORE_VEIN:
			_draw_ore_vein(wp)
		TileFeature.Type.RABBIT:
			_draw_rabbit(wp)
		TileFeature.Type.DEER:
			_draw_deer(wp)
		TileFeature.Type.FARM_WHEAT:
			_draw_farm(wp, Color8(200, 180, 60))
		TileFeature.Type.FARM_CORN:
			_draw_farm(wp, Color8(220, 190, 40))
		TileFeature.Type.FARM_VEGETABLES:
			_draw_farm(wp, Color8(60, 160, 60))
		TileFeature.Type.HERB_GARDEN:
			_draw_farm(wp, Color8(80, 140, 60))
		TileFeature.Type.WORKSHOP:
			_draw_workshop(wp)
		TileFeature.Type.LOOM:
			_draw_building_3x3(wp, Color8(180, 150, 170), Color8(140, 110, 130))
		TileFeature.Type.KILN:
			_draw_building_3x3(wp, Color8(200, 100, 50), Color8(160, 70, 30))
		TileFeature.Type.SMELTER:
			_draw_building_3x3(wp, Color8(140, 80, 60), Color8(100, 50, 35))
		TileFeature.Type.BOATYARD:
			_draw_building_3x3(wp, Color8(120, 80, 40), Color8(80, 50, 25))
		TileFeature.Type.DOCK:
			_draw_building_3x3(wp, Color8(100, 70, 35), Color8(70, 45, 20))
		TileFeature.Type.FISHERMAN_HUT:
			_draw_building_3x3(wp, Color8(90, 120, 140), Color8(60, 85, 100))
		TileFeature.Type.APOTHECARY:
			_draw_building_3x3(wp, Color8(60, 150, 80), Color8(40, 110, 55))
		TileFeature.Type.LIBRARY:
			_draw_library(wp)
		TileFeature.Type.SCHOOL:
			_draw_building_3x3(wp, Color8(130, 110, 150), Color8(95, 80, 115))
		TileFeature.Type.BARRACKS:
			_draw_barracks(wp)
		TileFeature.Type.WATCHTOWER:
			_draw_watchtower(wp)
		TileFeature.Type.MARKET:
			_draw_market(wp)
		TileFeature.Type.TRADING_POST:
			_draw_building_3x3(wp, Color8(180, 150, 80), Color8(140, 115, 55))
		TileFeature.Type.ROAD:
			_draw_road(wp)
		TileFeature.Type.GRANARY:
			_draw_building_3x3(wp, Color8(180, 160, 80), Color8(140, 120, 55))
		TileFeature.Type.CELLAR:
			_draw_cellar(wp)
		TileFeature.Type.GRAVE_MARKER:
			_draw_grave_marker(wp)
		TileFeature.Type.KNOWLEDGE_STONE:
			_draw_knowledge_stone(wp)
		TileFeature.Type.LEDGER_STONE:
			_draw_ledger_stone(wp)
		TileFeature.Type.RUIN:
			_draw_ruin(wp)


# ============================================================
# Building Sprites
# ============================================================

func _draw_fire_pit(p: Vector2) -> void:
	# Stone ring
	var ring_c: Color = Color8(100, 90, 80)
	draw_rect(Rect2(p + Vector2(-1.5, -1.5), Vector2(3.0, 3.0)), ring_c, true)
	# Fire glow center
	var fire_c: Color = Color8(255, 140, 30)
	draw_rect(Rect2(p + Vector2(-0.8, -0.8), Vector2(1.6, 1.6)), fire_c, true)
	# Flicker: bright yellow center
	var flicker: float = fmod(float(GameManager.tick_count) * 0.3, 1.0)
	var yellow_c: Color = Color8(255, 220, 80, int(150 + 105 * flicker))
	draw_rect(Rect2(p + Vector2(-0.4, -0.4), Vector2(0.8, 0.8)), yellow_c, true)
	# Ember dots
	draw_rect(Rect2(p + Vector2(0.5, -1.0), Vector2(0.3, 0.3)), Color8(255, 80, 20, 180), true)
	draw_rect(Rect2(p + Vector2(-1.0, 0.3), Vector2(0.3, 0.3)), Color8(255, 100, 30, 160), true)


func _draw_bed(p: Vector2) -> void:
	# Frame: horizontal rectangle
	var frame_c: Color = Color8(160, 120, 60)
	draw_rect(Rect2(p + Vector2(-1.5, -0.5), Vector2(3.0, 1.0)), frame_c, true)
	# Mattress: lighter wheat
	var mattress_c: Color = Color8(220, 180, 120)
	draw_rect(Rect2(p + Vector2(-1.2, -0.3), Vector2(2.4, 0.6)), mattress_c, true)
	# Pillow: white dot at one end
	draw_rect(Rect2(p + Vector2(0.8, -0.3), Vector2(0.5, 0.6)), Color8(240, 235, 220), true)


func _draw_wall(p: Vector2) -> void:
	# Solid brown rectangle with darker border
	var wall_c: Color = Color8(120, 75, 40)
	draw_rect(Rect2(p + Vector2(-1.5, -1.5), Vector2(3.0, 3.0)), wall_c, true)
	# Brick lines
	var brick_c: Color = Color8(90, 55, 30)
	draw_line(p + Vector2(-1.5, -0.5), p + Vector2(1.5, -0.5), brick_c, 0.5, true)
	draw_line(p + Vector2(-1.5, 0.5), p + Vector2(1.5, 0.5), brick_c, 0.5, true)
	# Vertical mortar
	draw_line(p + Vector2(0.0, -1.5), p + Vector2(0.0, -0.5), brick_c, 0.3, true)
	draw_line(p + Vector2(-0.7, -0.5), p + Vector2(-0.7, 0.5), brick_c, 0.3, true)
	draw_line(p + Vector2(0.7, -0.5), p + Vector2(0.7, 0.5), brick_c, 0.3, true)


func _draw_door(p: Vector2) -> void:
	# Lighter wood rectangle
	var door_c: Color = Color8(160, 100, 45)
	draw_rect(Rect2(p + Vector2(-1.0, -1.5), Vector2(2.0, 3.0)), door_c, true)
	# Horizontal planks
	var plank_c: Color = Color8(130, 80, 35)
	draw_line(p + Vector2(-1.0, -0.5), p + Vector2(1.0, -0.5), plank_c, 0.5, true)
	draw_line(p + Vector2(-1.0, 0.5), p + Vector2(1.0, 0.5), plank_c, 0.5, true)
	# Handle
	draw_rect(Rect2(p + Vector2(0.5, -0.1), Vector2(0.2, 0.2)), Color8(200, 180, 100), true)


func _draw_storage_hut(p: Vector2) -> void:
	# Base: tan rectangle
	var base_c: Color = Color8(150, 120, 70)
	draw_rect(Rect2(p + Vector2(-1.5, -1.5), Vector2(3.0, 3.0)), base_c, true)
	# Roof line: darker
	var roof_c: Color = Color8(110, 85, 45)
	draw_rect(Rect2(p + Vector2(-1.5, -1.5), Vector2(3.0, 0.8)), roof_c, true)
	# Door: dark opening
	draw_rect(Rect2(p + Vector2(-0.3, 0.0), Vector2(0.6, 1.5)), Color8(60, 45, 25), true)


func _draw_shrine(p: Vector2) -> void:
	# Base: purple
	var base_c: Color = Color8(180, 160, 200)
	draw_rect(Rect2(p + Vector2(-1.0, -1.5), Vector2(2.0, 3.0)), base_c, true)
	# Altar top: lighter
	draw_rect(Rect2(p + Vector2(-1.2, -1.5), Vector2(2.4, 0.5)), Color8(200, 185, 220), true)
	# Sacred flame: white dot
	draw_circle(p + Vector2(0.0, -1.0), 0.4, Color8(255, 255, 240))


func _draw_marker_stone(p: Vector2) -> void:
	# Vertical stone slab
	var stone_c: Color = Color8(140, 140, 150)
	draw_rect(Rect2(p + Vector2(-0.4, -1.5), Vector2(0.8, 3.0)), stone_c, true)
	# Top: rounded (circle)
	draw_circle(p + Vector2(0.0, -1.5), 0.4, stone_c)
	# Carving: darker line
	draw_line(p + Vector2(0.0, -1.0), p + Vector2(0.0, 0.5), Color8(100, 100, 110), 0.3, true)


# ============================================================
# Nature Sprites
# ============================================================

func _draw_tree(p: Vector2) -> void:
	# Trunk: brown center pixel
	draw_rect(Rect2(p + Vector2(-0.3, 0.0), Vector2(0.6, 1.0)), Color8(100, 65, 30), true)
	# Canopy: dark green circle
	draw_circle(p + Vector2(0.0, -0.5), 1.8, Color8(27, 73, 29))
	# Canopy highlight: lighter green on top
	draw_circle(p + Vector2(-0.3, -0.8), 1.0, Color8(40, 95, 35))
	# Shadow under canopy
	draw_circle(p + Vector2(0.3, 0.0), 0.8, Color8(20, 55, 22))


func _draw_fertile_soil(p: Vector2) -> void:
	# Base: dark green
	draw_rect(Rect2(p + Vector2(-1.5, -1.5), Vector2(3.0, 3.0)), Color8(51, 105, 30), true)
	# Seedling dots: tiny lighter green
	var dot_c: Color = Color8(70, 140, 45)
	draw_rect(Rect2(p + Vector2(-0.5, -0.5), Vector2(0.4, 0.4)), dot_c, true)
	draw_rect(Rect2(p + Vector2(0.3, 0.2), Vector2(0.4, 0.4)), dot_c, true)
	draw_rect(Rect2(p + Vector2(-0.8, 0.5), Vector2(0.4, 0.4)), dot_c, true)


func _draw_ore_vein(p: Vector2) -> void:
	# Gray rock base
	draw_rect(Rect2(p + Vector2(-1.0, -1.0), Vector2(2.0, 2.0)), Color8(130, 130, 130), true)
	# Orange sparkle
	draw_rect(Rect2(p + Vector2(-0.3, -0.5), Vector2(0.5, 0.5)), Color8(255, 111, 0), true)
	draw_rect(Rect2(p + Vector2(0.2, 0.1), Vector2(0.4, 0.4)), Color8(255, 140, 30), true)


func _draw_rabbit(p: Vector2) -> void:
	# White body
	draw_circle(p + Vector2(0.0, 0.0), 0.8, Color8(245, 240, 230))
	# Dark eye
	draw_rect(Rect2(p + Vector2(0.2, -0.3), Vector2(0.2, 0.2)), Color8(40, 30, 30), true)


func _draw_deer(p: Vector2) -> void:
	# Tan body
	_draw_ellipse_shape(p + Vector2(0.0, 0.0), 1.2, 0.8, Color8(170, 110, 55))
	# Darker head
	draw_circle(p + Vector2(0.8, -0.3), 0.5, Color8(140, 90, 40))
	# Antler dots
	draw_rect(Rect2(p + Vector2(1.0, -0.8), Vector2(0.2, 0.4)), Color8(120, 80, 35), true)


# ============================================================
# Farm + Production Sprites
# ============================================================

func _draw_farm(p: Vector2, crop_c: Color) -> void:
	# Soil base
	draw_rect(Rect2(p + Vector2(-1.5, -1.5), Vector2(3.0, 3.0)), Color8(90, 65, 35), true)
	# Crop rows: 3 horizontal lines
	draw_line(p + Vector2(-1.2, -0.8), p + Vector2(1.2, -0.8), crop_c, 0.6, true)
	draw_line(p + Vector2(-1.2, 0.0), p + Vector2(1.2, 0.0), crop_c, 0.6, true)
	draw_line(p + Vector2(-1.2, 0.8), p + Vector2(1.2, 0.8), crop_c, 0.6, true)


func _draw_workshop(p: Vector2) -> void:
	_draw_building_3x3(p, Color8(160, 120, 80), Color8(120, 85, 50))
	# Anvil: darker center shape
	draw_rect(Rect2(p + Vector2(-0.5, -0.3), Vector2(1.0, 0.6)), Color8(80, 80, 90), true)


func _draw_library(p: Vector2) -> void:
	_draw_building_3x3(p, Color8(100, 80, 140), Color8(70, 55, 100))
	# Book lines on shelf
	var book_c: Color = Color8(200, 180, 160)
	draw_line(p + Vector2(-0.8, -0.5), p + Vector2(-0.8, 0.5), book_c, 0.3, true)
	draw_line(p + Vector2(-0.3, -0.5), p + Vector2(-0.3, 0.5), book_c, 0.3, true)
	draw_line(p + Vector2(0.3, -0.5), p + Vector2(0.3, 0.5), book_c, 0.3, true)
	draw_line(p + Vector2(0.8, -0.5), p + Vector2(0.8, 0.5), book_c, 0.3, true)


func _draw_barracks(p: Vector2) -> void:
	_draw_building_3x3(p, Color8(160, 60, 50), Color8(120, 40, 35))
	# Chevron: military mark
	var chev_c: Color = Color8(220, 200, 160)
	draw_line(p + Vector2(-0.6, -0.3), p + Vector2(0.0, -0.8), chev_c, 0.5, true)
	draw_line(p + Vector2(0.0, -0.8), p + Vector2(0.6, -0.3), chev_c, 0.5, true)


func _draw_watchtower(p: Vector2) -> void:
	# Tall narrow tower
	draw_rect(Rect2(p + Vector2(-0.5, -1.5), Vector2(1.0, 3.0)), Color8(140, 100, 70), true)
	# Platform at top
	draw_rect(Rect2(p + Vector2(-0.8, -1.5), Vector2(1.6, 0.5)), Color8(160, 120, 80), true)
	# Flag
	draw_rect(Rect2(p + Vector2(0.3, -2.0), Vector2(0.2, 0.5)), Color8(100, 70, 45), true)
	draw_rect(Rect2(p + Vector2(0.5, -1.9), Vector2(0.5, 0.3)), Color8(200, 50, 50), true)


func _draw_market(p: Vector2) -> void:
	_draw_building_3x3(p, Color8(220, 180, 50), Color8(180, 145, 35))
	# Awning: triangular top
	draw_colored_polygon(
		PackedVector2Array([
			p + Vector2(-1.5, -1.5),
			p + Vector2(1.5, -1.5),
			p + Vector2(0.0, -2.2),
		]),
		Color8(240, 60, 60)
	)


func _draw_road(p: Vector2) -> void:
	# Base: paved gray
	var road_c: Color = Color8(160, 150, 130)
	draw_rect(Rect2(p + Vector2(-1.5, -1.5), Vector2(3.0, 3.0)), road_c, true)
	# Connect to neighboring road tiles
	var data: WorldData = _world.data
	var tx: int = int(p.x / World.TILE_PIXELS) if _world != null else 0
	var ty: int = int(p.y / World.TILE_PIXELS) if _world != null else 0
	# Check 4 neighbors for road
	var center_c: Color = Color8(140, 130, 110)
	# Always draw center line
	draw_rect(Rect2(p + Vector2(-0.3, -0.3), Vector2(0.6, 0.6)), center_c, true)
	# Extend to neighbors
	if data.in_bounds(tx, ty - 1) and data.features[data.index(tx, ty - 1)] == TileFeature.Type.ROAD:
		draw_rect(Rect2(p + Vector2(-0.3, -1.5), Vector2(0.6, 1.2)), center_c, true)
	if data.in_bounds(tx, ty + 1) and data.features[data.index(tx, ty + 1)] == TileFeature.Type.ROAD:
		draw_rect(Rect2(p + Vector2(-0.3, 0.3), Vector2(0.6, 1.2)), center_c, true)
	if data.in_bounds(tx - 1, ty) and data.features[data.index(tx - 1, ty)] == TileFeature.Type.ROAD:
		draw_rect(Rect2(p + Vector2(-1.5, -0.3), Vector2(1.2, 0.6)), center_c, true)
	if data.in_bounds(tx + 1, ty) and data.features[data.index(tx + 1, ty)] == TileFeature.Type.ROAD:
		draw_rect(Rect2(p + Vector2(0.3, -0.3), Vector2(1.2, 0.6)), center_c, true)


func _draw_cellar(p: Vector2) -> void:
	# Dark rectangle with trap door
	draw_rect(Rect2(p + Vector2(-1.5, -1.5), Vector2(3.0, 3.0)), Color8(100, 90, 80), true)
	# Trap door: lighter rectangle
	draw_rect(Rect2(p + Vector2(-0.8, -0.8), Vector2(1.6, 1.6)), Color8(130, 115, 95), true)
	# Handle
	draw_rect(Rect2(p + Vector2(-0.1, -0.1), Vector2(0.2, 0.2)), Color8(180, 160, 120), true)


func _draw_grave_marker(p: Vector2) -> void:
	# Stone slab
	draw_rect(Rect2(p + Vector2(-0.5, -1.0), Vector2(1.0, 2.0)), Color8(120, 120, 130), true)
	# Cross
	draw_line(p + Vector2(0.0, -0.8), p + Vector2(0.0, 0.3), Color8(80, 80, 90), 0.3, true)
	draw_line(p + Vector2(-0.3, -0.3), p + Vector2(0.3, -0.3), Color8(80, 80, 90), 0.3, true)


func _draw_knowledge_stone(p: Vector2) -> void:
	# Blue stone
	draw_rect(Rect2(p + Vector2(-0.5, -1.0), Vector2(1.0, 2.0)), Color8(100, 140, 180), true)
	# Glow
	draw_circle(p + Vector2(0.0, -0.5), 0.6, Color8(140, 180, 220, 120))


func _draw_ledger_stone(p: Vector2) -> void:
	# Tan stone
	draw_rect(Rect2(p + Vector2(-0.6, -1.0), Vector2(1.2, 2.0)), Color8(160, 140, 100), true)
	# Writing lines
	draw_line(p + Vector2(-0.3, -0.5), p + Vector2(0.3, -0.5), Color8(120, 100, 70), 0.3, true)
	draw_line(p + Vector2(-0.3, 0.0), p + Vector2(0.3, 0.0), Color8(120, 100, 70), 0.3, true)
	draw_line(p + Vector2(-0.3, 0.5), p + Vector2(0.3, 0.5), Color8(120, 100, 70), 0.3, true)


func _draw_ruin(p: Vector2) -> void:
	# Rubble: scattered gray-brown blocks
	draw_rect(Rect2(p + Vector2(-1.0, -1.0), Vector2(1.0, 1.0)), Color8(88, 72, 66), true)
	draw_rect(Rect2(p + Vector2(0.2, -0.5), Vector2(0.8, 0.8)), Color8(78, 65, 58), true)
	draw_rect(Rect2(p + Vector2(-0.5, 0.3), Vector2(0.6, 0.6)), Color8(95, 80, 72), true)


# ============================================================
# Generic Building Helper
# ============================================================

func _draw_building_3x3(p: Vector2, wall_c: Color, roof_c: Color) -> void:
	# Walls
	draw_rect(Rect2(p + Vector2(-1.5, -1.5), Vector2(3.0, 3.0)), wall_c, true)
	# Roof: darker top strip
	draw_rect(Rect2(p + Vector2(-1.5, -1.5), Vector2(3.0, 0.8)), roof_c, true)
	# Door: dark opening
	draw_rect(Rect2(p + Vector2(-0.3, 0.0), Vector2(0.6, 1.5)), Color8(40, 30, 20), true)


# ============================================================
# Construction Progress Bar
# ============================================================

func _draw_build_progress(p: Vector2, progress: float) -> void:
	# Background: dark gray bar
	var bar_y: float = p.y - 2.5
	var bar_w: float = 3.0
	var bar_h: float = 0.6
	draw_rect(Rect2(p.x - bar_w * 0.5, bar_y, bar_w, bar_h), Color8(30, 30, 30, 180), true)
	# Fill: green proportional to progress
	var fill_w: float = bar_w * progress
	var fill_c: Color = Color8(80, 220, 80) if progress < 0.9 else Color8(255, 220, 50)
	draw_rect(Rect2(p.x - bar_w * 0.5, bar_y, fill_w, bar_h), fill_c, true)
	# Border
	draw_rect(Rect2(p.x - bar_w * 0.5, bar_y, bar_w, bar_h), Color8(200, 200, 200, 100), false)


# ============================================================
# Utility
# ============================================================

func _draw_ellipse_shape(center: Vector2, rx: float, ry: float, color: Color) -> void:
	draw_colored_polygon(_ellipse_points(center, rx, ry, 12), color)


func _ellipse_points(center: Vector2, rx: float, ry: float, segments: int) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	for i in range(segments):
		var angle: float = TAU * float(i) / float(segments)
		pts.append(center + Vector2(cos(angle) * rx, sin(angle) * ry))
	return pts
