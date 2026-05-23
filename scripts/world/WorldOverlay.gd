extends Node2D
## Draws multi-pixel building sprites, tree/vegetation sprites, road autotiling,
## construction progress bars, terrain micro-textures, fire pit smoke,
## building chimney smoke, night window glow, and construction scaffolding
## on top of the terrain Image.

const REFRESH_EVERY_N_TICKS: int = 30
const MAX_DRAW_TILES: int = 8000  # Performance cap: don't draw more than this per frame
const MAX_TERRAIN_DETAIL_TILES: int = 4000  # Cap for terrain micro-texture drawing
const TERRAIN_DETAIL_INTERVAL: int = 2  # Only draw every Nth tile for performance
const MOBILE_REFRESH_EVERY_N_TICKS: int = 55
const MOBILE_MAX_DRAW_TILES: int = 4200
const MOBILE_MAX_TERRAIN_DETAIL_TILES: int = 1400
const MOBILE_TERRAIN_DETAIL_INTERVAL: int = 4

var _world: World = null
var _camera: Camera2D = null
var _tick_counter: int = 0
var _dirty: bool = true  # Redraw on first frame
var _refresh_every_n_ticks: int = REFRESH_EVERY_N_TICKS
var _max_draw_tiles: int = MAX_DRAW_TILES
var _max_terrain_detail_tiles: int = MAX_TERRAIN_DETAIL_TILES
var _terrain_detail_interval: int = TERRAIN_DETAIL_INTERVAL

# Cache: which features exist and where (rebuilt every REFRESH_EVERY_N_TICKS)
var _feature_tiles: Dictionary = {}  # feature_type -> Array[Vector2i]

# Cache: biome tiles for terrain micro-textures (rebuilt every REFRESH_EVERY_N_TICKS)
var _biome_tiles: Dictionary = {}  # biome_type -> Array[Vector2i]

# Construction progress: job_id -> {tile: Vector2i, progress: float}
var _build_progress: Dictionary = {}
var _build_sites: Dictionary = {}

# Smoke particle systems: persistent GPUParticles2D for fire pits and chimneys
var _smoke_systems: Array[GPUParticles2D] = []
var _smoke_positions: Array[Vector2] = []  # World positions for each smoke system
const MAX_SMOKE_SYSTEMS: int = 24

# Cultural tint cache: tile -> settlement_id (rebuilt with feature cache)
var _tile_settlement: Dictionary = {}  # Vector2i -> int (settlement_id)
var _settlement_color_cache: Dictionary = {}  # int (settlement_id) -> Color


func initialize(world_ref: World, camera_ref: Camera2D) -> void:
	_world = world_ref
	_camera = camera_ref
	z_index = 5  # Above terrain (0), below pawns (10)
	if OS.has_feature("mobile") or DisplayServer.is_touchscreen_available():
		_refresh_every_n_ticks = MOBILE_REFRESH_EVERY_N_TICKS
		_max_draw_tiles = MOBILE_MAX_DRAW_TILES
		_max_terrain_detail_tiles = MOBILE_MAX_TERRAIN_DETAIL_TILES
		_terrain_detail_interval = MOBILE_TERRAIN_DETAIL_INTERVAL


func mark_dirty() -> void:
	_dirty = true


func _process(_delta: float) -> void:
	_tick_counter += 1
	if _tick_counter % _refresh_every_n_ticks == 0 or _dirty:
		_rebuild_feature_cache()
		_refresh_build_progress()
		_refresh_smoke_positions()
		_dirty = false
		queue_redraw()


func _rebuild_feature_cache() -> void:
	_feature_tiles.clear()
	_biome_tiles.clear()
	_tile_settlement.clear()
	_settlement_color_cache.clear()
	if _world == null or _world.data == null:
		return
	var data: WorldData = _world.data
	# Only scan tiles in camera viewport for performance
	var cam_rect: Rect2i = _camera_viewport_tiles()
	for y in range(cam_rect.position.y, cam_rect.end.y):
		for x in range(cam_rect.position.x, cam_rect.end.x):
			if not data.in_bounds(x, y):
				continue
			var idx: int = data.index(x, y)
			var f: int = data.features[idx]
			if f != TileFeature.Type.NONE:
				if not _feature_tiles.has(f):
					_feature_tiles[f] = []
				_feature_tiles[f].append(Vector2i(x, y))
				# Cultural tint: look up settlement for this tile
				if SettlementMemory != null and SettlementMemory.has_method("get_settlement_id_for_region"):
					var rx: int = x >> 4
					var ry: int = y >> 4
					var rkey: int = (rx & 0xFFFF) | ((ry & 0xFFFF) << 16)
					var sid: int = SettlementMemory.get_settlement_id_for_region(rkey)
					if sid >= 0:
						_tile_settlement[Vector2i(x, y)] = sid
						if not _settlement_color_cache.has(sid):
							if CulturalStyleManager != null and CulturalStyleManager.has_method("get_cultural_color_for_settlement"):
								_settlement_color_cache[sid] = CulturalStyleManager.get_cultural_color_for_settlement(sid)
			else:
				# Cache biome for terrain micro-textures (sparse sampling)
				if (x + y) % _terrain_detail_interval == 0:
					var b: int = data.biomes[idx]
					if not _biome_tiles.has(b):
						_biome_tiles[b] = []
					_biome_tiles[b].append(Vector2i(x, y))


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
	_build_sites.clear()
	if JobManager == null:
		return
	var jobs: Array = JobManager.get_active_jobs_union()
	for job in jobs:
		if job == null:
			continue
		# Only show progress for build jobs
		var is_build: bool = _is_build_job_type(job.type)
		if not is_build:
			continue
		var progress: float = 0.0
		if job.work_ticks_needed > 0:
			progress = clampf(float(job.work_ticks_done) / float(job.work_ticks_needed), 0.0, 1.0)
		var claimed: bool = int(job.state) == Job.State.CLAIMED
		_build_sites[job.tile] = {"type": int(job.type), "progress": progress, "claimed": claimed}
		if claimed:
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
		or t == Job.Type.BUILD_CELLAR or t == Job.Type.BUILD_FORD
		or t == Job.Type.BUILD_WATER_MILL
	)


func _draw() -> void:
	if _world == null or _world.data == null:
		return
	var drawn: int = 0
	var is_night: bool = DayNightCycle.is_night_for_tick(GameManager.tick_count) if DayNightCycle != null else false

	# --- Terrain micro-textures: per-biome detail pixels ---
	drawn = 0
	for b_type in _biome_tiles:
		var tiles: Array = _biome_tiles[b_type]
		for tile_pos in tiles:
			if drawn >= _max_terrain_detail_tiles:
				break
			var wp: Vector2 = _world.tile_to_world(tile_pos)
			_draw_terrain_detail(wp, int(b_type), int(tile_pos.x), int(tile_pos.y))
			drawn += 1

	# --- Draw each feature type with its sprite + cultural tint ---
	drawn = 0
	for f_type in _feature_tiles:
		var tiles: Array = _feature_tiles[f_type]
		for tile_pos in tiles:
			if drawn >= _max_draw_tiles:
				return
			var wp: Vector2 = _world.tile_to_world(tile_pos)
			var cultural_tint: Color = _get_cultural_tint(tile_pos)
			_draw_feature_sprite(wp, int(f_type), cultural_tint)
			drawn += 1

	# --- Autonomous construction plans: make open jobs visible before completion ---
	for tile_pos in _build_sites:
		var site: Dictionary = _build_sites[tile_pos]
		var wp: Vector2 = _world.tile_to_world(tile_pos)
		_draw_build_plan(wp, int(site.get("type", -1)), bool(site.get("claimed", false)))

	# --- Night window glow: warm light on occupied buildings ---
	if is_night:
		for f_type in _feature_tiles:
			var ft: int = int(f_type)
			if ft == TileFeature.Type.BED or ft == TileFeature.Type.LIBRARY or ft == TileFeature.Type.SCHOOL or ft == TileFeature.Type.APOTHECARY:
				for tile_pos in _feature_tiles[f_type]:
					var wp: Vector2 = _world.tile_to_world(tile_pos)
					_draw_window_glow(wp, ft)

	# --- Construction scaffolding: visual build stages ---
	for tile_pos in _build_progress:
		var progress: float = _build_progress[tile_pos]
		var wp: Vector2 = _world.tile_to_world(tile_pos)
		_draw_build_progress(wp, progress)
		_draw_scaffolding(wp, progress)

	# --- Footpaths: worn trails from foot traffic ---
	drawn = 0
	var cam_rect: Rect2i = _camera_viewport_tiles()
	for y in range(cam_rect.position.y, cam_rect.end.y, 3):
		for x in range(cam_rect.position.x, cam_rect.end.x, 3):
			if drawn >= 500:
				break
			var wear: float = MemoryManager.footpath_get_wear_at(Vector2i(x, y))
			if wear > 0.1:
					var wp: Vector2 = _world.tile_to_world(Vector2i(x, y))
					var alpha: float = clampf(wear, 0.1, 0.6)
					var path_c: Color = Color(0.45, 0.35, 0.2, alpha)
					draw_rect(Rect2(wp + Vector2(-1.5, -1.5), Vector2(3.0, 3.0)), path_c, true)
					drawn += 1

	# --- Sacred glow: tiles with memorial significance ---
	var _sg: Node = get_node_or_null("/root/SacredGeography")
	if _sg != null and _sg.has_method("get_all_sacred_tiles"):
		var sacred_list: Array = _sg.get_all_sacred_tiles()
		for sacred_data in sacred_list:
			var tile: Variant = sacred_data.get("tile", null)
			if tile == null:
				continue
			var significance: String = str(sacred_data.get("significance", ""))
			if significance == "":
				continue
			var wp: Vector2 = _world.tile_to_world(tile)
			var glow_color: Color
			if significance == "holy_ground":
				glow_color = Color(0.5, 0.7, 1.0, 0.35)
			elif significance == "sacred":
				glow_color = Color(0.7, 0.8, 1.0, 0.2)
			else:
				glow_color = Color(0.9, 0.9, 1.0, 0.1)
			draw_rect(Rect2(wp + Vector2(-2.0, -2.0), Vector2(4.0, 4.0)), glow_color, true)

	# --- Update smoke particle positions ---
	_update_smoke_particles()


## Get cultural tint color for a tile. Returns Color.WHITE if no settlement.
func _get_cultural_tint(tile_pos: Vector2i) -> Color:
	var sid: int = _tile_settlement.get(tile_pos, -1)
	if sid < 0:
		return Color.WHITE
	return _settlement_color_cache.get(sid, Color.WHITE)


## Apply a subtle cultural tint to a base color. The tint is blended at 25% strength
## so the building's original color is still recognizable but shifted toward the settlement's hue.
func _apply_cultural_tint(base: Color, tint: Color) -> Color:
	if tint == Color.WHITE:
		return base
	return base.lerp(tint, 0.25)


func _draw_feature_sprite(wp: Vector2, feature: int, cultural_tint: Color = Color.WHITE) -> void:
	match feature:
		TileFeature.Type.FIRE_PIT:
			_draw_fire_pit(wp)
		TileFeature.Type.BED:
			_draw_bed(wp)
		TileFeature.Type.WALL:
			_draw_wall(wp, cultural_tint)
		TileFeature.Type.DOOR:
			_draw_door(wp)
		TileFeature.Type.STORAGE_HUT:
			_draw_storage_hut(wp, cultural_tint)
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
			_draw_workshop(wp, cultural_tint)
		TileFeature.Type.LOOM:
			_draw_building_3x3(wp, _apply_cultural_tint(Color8(180, 150, 170), cultural_tint), _apply_cultural_tint(Color8(140, 110, 130), cultural_tint))
		TileFeature.Type.KILN:
			_draw_building_3x3(wp, _apply_cultural_tint(Color8(200, 100, 50), cultural_tint), _apply_cultural_tint(Color8(160, 70, 30), cultural_tint))
		TileFeature.Type.SMELTER:
			_draw_building_3x3(wp, _apply_cultural_tint(Color8(140, 80, 60), cultural_tint), _apply_cultural_tint(Color8(100, 50, 35), cultural_tint))
		TileFeature.Type.BOATYARD:
			_draw_building_3x3(wp, _apply_cultural_tint(Color8(120, 80, 40), cultural_tint), _apply_cultural_tint(Color8(80, 50, 25), cultural_tint))
		TileFeature.Type.DOCK:
			_draw_building_3x3(wp, _apply_cultural_tint(Color8(100, 70, 35), cultural_tint), _apply_cultural_tint(Color8(70, 45, 20), cultural_tint))
		TileFeature.Type.FISHERMAN_HUT:
			_draw_building_3x3(wp, _apply_cultural_tint(Color8(90, 120, 140), cultural_tint), _apply_cultural_tint(Color8(60, 85, 100), cultural_tint))
		TileFeature.Type.APOTHECARY:
			_draw_building_3x3(wp, _apply_cultural_tint(Color8(60, 150, 80), cultural_tint), _apply_cultural_tint(Color8(40, 110, 55), cultural_tint))
		TileFeature.Type.LIBRARY:
			_draw_library(wp, cultural_tint)
		TileFeature.Type.SCHOOL:
			_draw_building_3x3(wp, _apply_cultural_tint(Color8(130, 110, 150), cultural_tint), _apply_cultural_tint(Color8(95, 80, 115), cultural_tint))
		TileFeature.Type.BARRACKS:
			_draw_barracks(wp, cultural_tint)
		TileFeature.Type.WATCHTOWER:
			_draw_watchtower(wp, cultural_tint)
		TileFeature.Type.MARKET:
			_draw_market(wp, cultural_tint)
		TileFeature.Type.TRADING_POST:
			_draw_building_3x3(wp, _apply_cultural_tint(Color8(180, 150, 80), cultural_tint), _apply_cultural_tint(Color8(140, 115, 55), cultural_tint))
		TileFeature.Type.ROAD:
			_draw_road(wp)
		TileFeature.Type.GRANARY:
			_draw_building_3x3(wp, _apply_cultural_tint(Color8(180, 160, 80), cultural_tint), _apply_cultural_tint(Color8(140, 120, 55), cultural_tint))
		TileFeature.Type.CELLAR:
			_draw_cellar(wp)
		TileFeature.Type.BREWERY:
			_draw_building_3x3(wp, _apply_cultural_tint(Color8(180, 140, 40), cultural_tint), _apply_cultural_tint(Color8(140, 100, 20), cultural_tint))
		TileFeature.Type.TAVERN:
			_draw_building_3x3(wp, _apply_cultural_tint(Color8(160, 100, 50), cultural_tint), _apply_cultural_tint(Color8(120, 65, 30), cultural_tint))
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


func _draw_wall(p: Vector2, cultural_tint: Color = Color.WHITE) -> void:
	# Solid brown rectangle with darker border
	var wall_c: Color = _apply_cultural_tint(Color8(120, 75, 40), cultural_tint)
	draw_rect(Rect2(p + Vector2(-1.5, -1.5), Vector2(3.0, 3.0)), wall_c, true)
	# Brick lines
	var brick_c: Color = _apply_cultural_tint(Color8(90, 55, 30), cultural_tint)
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


func _draw_build_plan(p: Vector2, job_type: int, claimed: bool) -> void:
	var alpha: int = 115 if claimed else 70
	match job_type:
		Job.Type.BUILD_WALL:
			# Full-tile ghost so settlement borders read from zoomed-out play.
			var fill_c: Color = Color8(150, 95, 48, alpha)
			var edge_c: Color = Color8(255, 210, 110, 170 if claimed else 115)
			draw_rect(Rect2(p + Vector2(-4.3, -4.3), Vector2(8.6, 8.6)), fill_c, true)
			draw_rect(Rect2(p + Vector2(-4.3, -4.3), Vector2(8.6, 8.6)), edge_c, false, 0.9)
			draw_line(p + Vector2(-3.4, 0.0), p + Vector2(3.4, 0.0), edge_c, 0.45, true)
		Job.Type.BUILD_DOOR:
			var door_c: Color = Color8(230, 150, 60, alpha + 35)
			draw_rect(Rect2(p + Vector2(-3.0, -4.2), Vector2(6.0, 8.4)), door_c, true)
			draw_rect(Rect2(p + Vector2(-3.0, -4.2), Vector2(6.0, 8.4)), Color8(255, 230, 140, 150), false, 0.9)
		Job.Type.BUILD_BED, Job.Type.BUILD_SHELTER:
			draw_rect(Rect2(p + Vector2(-3.8, -2.2), Vector2(7.6, 4.4)), Color8(230, 190, 120, alpha), true)
			draw_rect(Rect2(p + Vector2(-3.8, -2.2), Vector2(7.6, 4.4)), Color8(255, 235, 170, 120), false, 0.7)
		Job.Type.BUILD_FIRE_PIT, Job.Type.BUILD_HEARTH:
			var hearth_c: Color = Color8(255, 140, 40, alpha + 40)
			draw_rect(Rect2(p + Vector2(-2.2, -2.2), Vector2(4.4, 4.4)), hearth_c, true)
			draw_rect(Rect2(p + Vector2(-2.2, -2.2), Vector2(4.4, 4.4)), Color8(255, 220, 120, 150), false, 0.8)
		Job.Type.BUILD_STORAGE_HUT:
			draw_rect(Rect2(p + Vector2(-2.5, -2.5), Vector2(5.0, 5.0)), Color8(180, 140, 70, alpha + 25), true)
			draw_rect(Rect2(p + Vector2(-2.5, -2.5), Vector2(5.0, 5.0)), Color8(255, 230, 160, 130), false, 0.7)
		_:
			draw_circle(p, 3.6, Color8(140, 190, 255, alpha))
			draw_circle(p, 3.8, Color8(220, 240, 255, 95))


func _draw_storage_hut(p: Vector2, cultural_tint: Color = Color.WHITE) -> void:
	# Base: tan rectangle
	var base_c: Color = _apply_cultural_tint(Color8(150, 120, 70), cultural_tint)
	draw_rect(Rect2(p + Vector2(-1.5, -1.5), Vector2(3.0, 3.0)), base_c, true)
	# Roof line: darker
	var roof_c: Color = _apply_cultural_tint(Color8(110, 85, 45), cultural_tint)
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
	# Seasonal canopy color
	var season: int = Biome.season_for_tick(GameManager.tick_count)
	var canopy_c: Color
	var highlight_c: Color
	var shadow_c: Color
	match season:
		Biome.Season.SPRING:
			canopy_c = Color8(40, 110, 35)
			highlight_c = Color8(60, 140, 50)
			shadow_c = Color8(25, 80, 25)
		Biome.Season.SUMMER:
			canopy_c = Color8(27, 73, 29)
			highlight_c = Color8(40, 95, 35)
			shadow_c = Color8(20, 55, 22)
		Biome.Season.AUTUMN:
			canopy_c = Color8(140, 90, 25)
			highlight_c = Color8(180, 120, 30)
			shadow_c = Color8(100, 65, 18)
		Biome.Season.WINTER:
			canopy_c = Color8(80, 90, 80)
			highlight_c = Color8(110, 115, 105)
			shadow_c = Color8(60, 65, 60)
		_:
			canopy_c = Color8(27, 73, 29)
			highlight_c = Color8(40, 95, 35)
			shadow_c = Color8(20, 55, 22)
	# Canopy: dark circle
	draw_circle(p + Vector2(0.0, -0.5), 1.8, canopy_c)
	# Canopy highlight: lighter on top
	draw_circle(p + Vector2(-0.3, -0.8), 1.0, highlight_c)
	# Shadow under canopy
	draw_circle(p + Vector2(0.3, 0.0), 0.8, shadow_c)
	# Winter: snow cap on canopy
	if season == Biome.Season.WINTER:
		draw_circle(p + Vector2(0.0, -1.2), 0.8, Color8(230, 240, 245, 120))


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


func _draw_workshop(p: Vector2, cultural_tint: Color = Color.WHITE) -> void:
	_draw_building_3x3(p, _apply_cultural_tint(Color8(160, 120, 80), cultural_tint), _apply_cultural_tint(Color8(120, 85, 50), cultural_tint))
	# Anvil: darker center shape
	draw_rect(Rect2(p + Vector2(-0.5, -0.3), Vector2(1.0, 0.6)), Color8(80, 80, 90), true)


func _draw_library(p: Vector2, cultural_tint: Color = Color.WHITE) -> void:
	_draw_building_3x3(p, _apply_cultural_tint(Color8(100, 80, 140), cultural_tint), _apply_cultural_tint(Color8(70, 55, 100), cultural_tint))
	# Book lines on shelf
	var book_c: Color = Color8(200, 180, 160)
	draw_line(p + Vector2(-0.8, -0.5), p + Vector2(-0.8, 0.5), book_c, 0.3, true)
	draw_line(p + Vector2(-0.3, -0.5), p + Vector2(-0.3, 0.5), book_c, 0.3, true)
	draw_line(p + Vector2(0.3, -0.5), p + Vector2(0.3, 0.5), book_c, 0.3, true)
	draw_line(p + Vector2(0.8, -0.5), p + Vector2(0.8, 0.5), book_c, 0.3, true)


func _draw_barracks(p: Vector2, cultural_tint: Color = Color.WHITE) -> void:
	_draw_building_3x3(p, _apply_cultural_tint(Color8(160, 60, 50), cultural_tint), _apply_cultural_tint(Color8(120, 40, 35), cultural_tint))
	# Chevron: military mark
	var chev_c: Color = Color8(220, 200, 160)
	draw_line(p + Vector2(-0.6, -0.3), p + Vector2(0.0, -0.8), chev_c, 0.5, true)
	draw_line(p + Vector2(0.0, -0.8), p + Vector2(0.6, -0.3), chev_c, 0.5, true)


func _draw_watchtower(p: Vector2, cultural_tint: Color = Color.WHITE) -> void:
	# Tall narrow tower
	var tower_c: Color = _apply_cultural_tint(Color8(140, 100, 70), cultural_tint)
	draw_rect(Rect2(p + Vector2(-0.5, -1.5), Vector2(1.0, 3.0)), tower_c, true)
	# Platform at top
	var plat_c: Color = _apply_cultural_tint(Color8(160, 120, 80), cultural_tint)
	draw_rect(Rect2(p + Vector2(-0.8, -1.5), Vector2(1.6, 0.5)), plat_c, true)
	# Flag
	draw_rect(Rect2(p + Vector2(0.3, -2.0), Vector2(0.2, 0.5)), Color8(100, 70, 45), true)
	draw_rect(Rect2(p + Vector2(0.5, -1.9), Vector2(0.5, 0.3)), Color8(200, 50, 50), true)


func _draw_market(p: Vector2, cultural_tint: Color = Color.WHITE) -> void:
	_draw_building_3x3(p, _apply_cultural_tint(Color8(220, 180, 50), cultural_tint), _apply_cultural_tint(Color8(180, 145, 35), cultural_tint))
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
# Terrain Micro-Textures
# ============================================================

func _draw_terrain_detail(p: Vector2, biome: int, tx: int, ty: int) -> void:
	# Deterministic per-tile hash for varied detail placement
	var h: int = (tx * 19349663 + ty * 73856093) & 0xFFFF
	var tick_phase: float = fmod(float(GameManager.tick_count) * 0.02, TAU)
	match biome:
		Biome.Type.PLAINS:
			# Grass blades: tiny vertical lines
			var blade_c: Color = Color8(90, 160, 50, 120)
			if (h & 0x03) == 0:
				draw_line(p + Vector2(-1.0, 1.0), p + Vector2(-1.0, -0.5), blade_c, 0.4, true)
			if (h & 0x07) == 1:
				draw_line(p + Vector2(1.5, 1.0), p + Vector2(1.5, 0.0), blade_c, 0.4, true)
			if (h & 0x0F) == 3:
				# Tiny flower dot
				draw_rect(Rect2(p + Vector2(0.5, -0.5), Vector2(0.3, 0.3)), Color8(220, 180, 60, 100), true)
		Biome.Type.FOREST:
			# Forest floor: scattered leaf litter and undergrowth
			var leaf_c: Color = Color8(35, 90, 30, 100)
			if (h & 0x03) == 0:
				draw_rect(Rect2(p + Vector2(-1.0, 0.5), Vector2(0.5, 0.3)), leaf_c, true)
			if (h & 0x07) == 2:
				draw_rect(Rect2(p + Vector2(0.5, -0.5), Vector2(0.4, 0.4)), Color8(50, 100, 35, 90), true)
			if (h & 0x0F) == 5:
				# Fern: tiny curved line
				draw_line(p + Vector2(-0.5, 1.0), p + Vector2(-0.5, -0.3), Color8(30, 110, 25, 110), 0.3, true)
		Biome.Type.DESERT:
			# Sand ripples: horizontal wavy lines
			var ripple_c: Color = Color8(240, 200, 80, 80)
			if (h & 0x03) == 0:
				draw_line(p + Vector2(-1.5, 0.3), p + Vector2(1.5, 0.3), ripple_c, 0.3, true)
			if (h & 0x07) == 3:
				draw_line(p + Vector2(-1.0, -0.5), p + Vector2(1.0, -0.5), ripple_c, 0.3, true)
			if (h & 0x0F) == 7:
				# Tiny sand dune curve
				draw_line(p + Vector2(-1.0, 0.8), p + Vector2(0.0, 0.3), Color8(230, 190, 60, 90), 0.4, true)
		Biome.Type.TUNDRA:
			# Frost crystals: tiny bright dots
			var frost_c: Color = Color8(200, 230, 240, 100)
			if (h & 0x03) == 0:
				draw_rect(Rect2(p + Vector2(-0.5, -0.5), Vector2(0.3, 0.3)), frost_c, true)
			if (h & 0x07) == 2:
				draw_rect(Rect2(p + Vector2(0.8, 0.3), Vector2(0.3, 0.3)), frost_c, true)
			if (h & 0x0F) == 4:
				# Ice crack line
				draw_line(p + Vector2(-1.0, 0.0), p + Vector2(0.5, -0.5), Color8(180, 220, 235, 70), 0.3, true)
		Biome.Type.MOUNTAIN:
			# Stone grain: tiny dark specks
			var grain_c: Color = Color8(80, 55, 45, 90)
			if (h & 0x03) == 0:
				draw_rect(Rect2(p + Vector2(-0.5, 0.0), Vector2(0.3, 0.3)), grain_c, true)
			if (h & 0x07) == 1:
				draw_rect(Rect2(p + Vector2(0.5, -0.5), Vector2(0.3, 0.3)), grain_c, true)
			if (h & 0x0F) == 6:
				# Moss patch
				draw_rect(Rect2(p + Vector2(-0.8, 0.5), Vector2(0.5, 0.3)), Color8(60, 90, 45, 80), true)
		Biome.Type.WATER:
			# Water caustics: animated bright lines
			var caustic_phase: float = tick_phase + float(h) * 0.01
			var caustic_alpha: int = int(40 + 30 * sin(caustic_phase))
			var caustic_c: Color = Color8(80, 160, 255, caustic_alpha)
			if (h & 0x03) == 0:
				draw_line(p + Vector2(-1.0, 0.0), p + Vector2(1.0, 0.3), caustic_c, 0.3, true)
			if (h & 0x07) == 3:
				draw_line(p + Vector2(0.0, -0.5), p + Vector2(0.5, 0.5), caustic_c, 0.3, true)
		Biome.Type.STONE_FLOOR:
			# Stone tile cracks
			var crack_c: Color = Color8(130, 115, 100, 80)
			if (h & 0x03) == 0:
				draw_line(p + Vector2(-0.5, -0.5), p + Vector2(0.5, 0.5), crack_c, 0.3, true)


# ============================================================
# Night Window Glow
# ============================================================

func _draw_window_glow(p: Vector2, feature: int) -> void:
	# Warm light emanating from building windows at night
	var glow_c: Color = Color8(255, 200, 100, 60)  # Warm amber, subtle
	var glow_r: float = 2.5
	match feature:
		TileFeature.Type.BED:
			# Bed: small warm glow (someone sleeping)
			glow_c = Color8(255, 180, 80, 50)
			glow_r = 2.0
		TileFeature.Type.LIBRARY:
			# Library: cool blue glow (scholar studying)
			glow_c = Color8(140, 160, 255, 55)
			glow_r = 3.0
		TileFeature.Type.SCHOOL:
			# School: warm white glow
			glow_c = Color8(255, 240, 200, 50)
			glow_r = 2.5
		TileFeature.Type.APOTHECARY:
			# Apothecary: green glow
			glow_c = Color8(100, 255, 140, 45)
			glow_r = 2.0
	# Draw soft glow circle
	draw_circle(p, glow_r, glow_c)
	# Bright center pixel
	draw_rect(Rect2(p + Vector2(-0.3, -0.3), Vector2(0.6, 0.6)), Color8(glow_c.r8, glow_c.g8, glow_c.b8, int(glow_c.a8 * 1.5)), true)


# ============================================================
# Construction Scaffolding
# ============================================================

func _draw_scaffolding(p: Vector2, progress: float) -> void:
	if progress >= 1.0:
		return  # Complete, no scaffolding
	# Scaffolding: wooden poles around the building site
	var pole_c: Color = Color8(160, 120, 60, 180)
	# Vertical poles: fade out as progress increases
	var pole_alpha: float = 1.0 - progress
	pole_c = Color8(pole_c.r8, pole_c.g8, pole_c.b8, int(pole_c.a8 * pole_alpha))
	# Left pole
	draw_line(p + Vector2(-2.0, 2.0), p + Vector2(-2.0, -2.5), pole_c, 0.5, true)
	# Right pole
	draw_line(p + Vector2(2.0, 2.0), p + Vector2(2.0, -2.5), pole_c, 0.5, true)
	# Horizontal crossbar at top
	draw_line(p + Vector2(-2.0, -2.0), p + Vector2(2.0, -2.0), pole_c, 0.4, true)
	# Mid crossbar (only in early stages)
	if progress < 0.5:
		draw_line(p + Vector2(-2.0, 0.0), p + Vector2(2.0, 0.0), pole_c, 0.3, true)
	# Diagonal brace (only in early stages)
	if progress < 0.3:
		draw_line(p + Vector2(-2.0, 2.0), p + Vector2(2.0, -2.0), pole_c, 0.3, true)


# ============================================================
# Smoke Particle System
# ============================================================

func _refresh_smoke_positions() -> void:
	_smoke_positions.clear()
	if _world == null or _world.data == null:
		return
	var data: WorldData = _world.data
	var cam_rect: Rect2i = _camera_viewport_tiles()
	# Fire pit smoke
	if _feature_tiles.has(TileFeature.Type.FIRE_PIT):
		for tile_pos in _feature_tiles[TileFeature.Type.FIRE_PIT]:
			_smoke_positions.append(_world.tile_to_world(tile_pos) + Vector2(0.0, -2.0))
	# Chimney smoke: workshops, kilns, smelters
	var chimney_types: Array[int] = [TileFeature.Type.WORKSHOP, TileFeature.Type.KILN, TileFeature.Type.SMELTER]
	for ct in chimney_types:
		if _feature_tiles.has(ct):
			for tile_pos in _feature_tiles[ct]:
				_smoke_positions.append(_world.tile_to_world(tile_pos) + Vector2(0.0, -2.5))
	# Ensure enough smoke systems exist
	while _smoke_systems.size() < mini(_smoke_positions.size(), MAX_SMOKE_SYSTEMS):
		var ps: GPUParticles2D = _make_smoke_system()
		add_child(ps)
		_smoke_systems.append(ps)


func _make_smoke_system() -> GPUParticles2D:
	var p: GPUParticles2D = GPUParticles2D.new()
	p.name = "Smoke_%d" % _smoke_systems.size()
	p.amount = 4
	p.lifetime = 1.5
	p.one_shot = false
	p.emitting = false
	p.explosiveness = 0.0
	p.randomness = 0.7
	p.local_coords = false
	p.z_index = 6
	var mat: ParticleProcessMaterial = ParticleProcessMaterial.new()
	mat.direction = Vector3(0.0, -1.0, 0.0)
	mat.spread = 15.0
	mat.gravity = Vector3(0.0, -8.0, 0.0)
	mat.initial_velocity_min = 3.0
	mat.initial_velocity_max = 8.0
	mat.scale_min = 0.3
	mat.scale_max = 0.8
	p.process_material = mat
	p.modulate = Color8(180, 170, 160, 60)
	return p


func _update_smoke_particles() -> void:
	# Position smoke systems at their targets, enable/disable
	for i in range(_smoke_systems.size()):
		var ps: GPUParticles2D = _smoke_systems[i]
		if i < _smoke_positions.size():
			ps.position = _smoke_positions[i]
			ps.emitting = true
		else:
			ps.emitting = false


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
