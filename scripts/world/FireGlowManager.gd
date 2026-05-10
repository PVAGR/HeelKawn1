extends Node2D
## Manages PointLight2D nodes for fire pits.
## Creates warm orange lights at each fire pit location.
## Caps at MAX_LIGHTS for performance; closest to camera get priority.

const MAX_LIGHTS: int = 20
const REFRESH_EVERY_N_TICKS: int = 60
const LIGHT_COLOR: Color = Color(1.0, 0.75, 0.35, 1.0)
const LIGHT_ENERGY_DAY: float = 0.4
const LIGHT_ENERGY_NIGHT: float = 1.2
const LIGHT_RANGE: float = 40.0  # ~4 tiles at TILE_PIXELS=10

var _world: World = null
var _camera: Camera2D = null
var _tick_counter: int = 0
var _active_lights: Array[PointLight2D] = []
var _light_pool: Array[PointLight2D] = []
var _fire_pit_tiles: Array[Vector2i] = []
var _light_texture: GradientTexture2D


func initialize(world_ref: World, camera_ref: Camera2D) -> void:
	_world = world_ref
	_camera = camera_ref
	z_index = 4  # Above terrain, below WorldOverlay
	# Create light texture: radial gradient from white center to transparent edge
	_light_texture = GradientTexture2D.new()
	var grad: Gradient = Gradient.new()
	grad.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	grad.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	_light_texture.gradient = grad
	_light_texture.width = 64
	_light_texture.height = 64
	_light_texture.fill = GradientTexture2D.FILL_RADIAL
	_light_texture.fill_from = Vector2(0.5, 0.5)
	_light_texture.fill_to = Vector2(1.0, 0.5)
	# Pre-create light pool
	for i in range(MAX_LIGHTS):
		var light: PointLight2D = PointLight2D.new()
		light.color = LIGHT_COLOR
		light.energy = LIGHT_ENERGY_DAY
		light.texture_scale = LIGHT_RANGE
		light.texture = _light_texture
		light.enabled = false
		light.visible = false
		add_child(light)
		_light_pool.append(light)


func _process(_delta: float) -> void:
	_tick_counter += 1
	if _tick_counter % REFRESH_EVERY_N_TICKS == 0:
		_refresh_lights()
	# Update light energy based on day/night
	var is_night: bool = DayNightCycle.is_night_for_tick(GameManager.tick_count) if DayNightCycle != null else false
	var target_energy: float = LIGHT_ENERGY_NIGHT if is_night else LIGHT_ENERGY_DAY
	for light in _active_lights:
		light.energy = target_energy


func _refresh_lights() -> void:
	if _world == null or _world.data == null:
		return
	# Collect fire pit tiles
	_fire_pit_tiles.clear()
	var data: WorldData = _world.data
	# Only scan tiles in camera viewport for performance
	var cam_rect: Rect2i = _camera_viewport_tiles()
	for y in range(cam_rect.position.y, cam_rect.end.y):
		for x in range(cam_rect.position.x, cam_rect.end.x):
			if not data.in_bounds(x, y):
				continue
			if data.features[data.index(x, y)] == TileFeature.Type.FIRE_PIT:
				_fire_pit_tiles.append(Vector2i(x, y))
	# Sort by distance to camera (closest first)
	var cam_tile: Vector2 = _camera.global_position / World.TILE_PIXELS if _camera != null else Vector2.ZERO
	_fire_pit_tiles.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var da: float = (Vector2(a.x, a.y) - cam_tile).length_squared()
		var db: float = (Vector2(b.x, b.y) - cam_tile).length_squared()
		return da < db
	)
	# Disable all current lights
	for light in _active_lights:
		light.enabled = false
		light.visible = false
	_active_lights.clear()
	# Enable lights for closest fire pits
	var count: int = mini(_fire_pit_tiles.size(), MAX_LIGHTS)
	for i in range(count):
		if i >= _light_pool.size():
			break
		var light: PointLight2D = _light_pool[i]
		var tile: Vector2i = _fire_pit_tiles[i]
		var world_pos: Vector2 = _world.tile_to_world(tile)
		light.position = world_pos
		light.enabled = true
		light.visible = true
		_active_lights.append(light)


func _camera_viewport_tiles() -> Rect2i:
	if _camera == null or _world == null:
		return Rect2i(0, 0, WorldData.WIDTH, WorldData.HEIGHT)
	var cam_pos: Vector2 = _camera.global_position
	var zoom: float = _camera.zoom.x if _camera.zoom.x > 0 else 1.0
	var viewport_size: Vector2 = _camera.get_viewport().get_visible_rect().size
	var half_tiles: Vector2 = viewport_size / (2.0 * zoom * World.TILE_PIXELS)
	var min_x: int = int(cam_pos.x / World.TILE_PIXELS - half_tiles.x) - 4
	var min_y: int = int(cam_pos.y / World.TILE_PIXELS - half_tiles.y) - 4
	var max_x: int = int(cam_pos.x / World.TILE_PIXELS + half_tiles.x) + 4
	var max_y: int = int(cam_pos.y / World.TILE_PIXELS + half_tiles.y) + 4
	return Rect2i(
		maxi(0, min_x), maxi(0, min_y),
		mini(WorldData.WIDTH, max_x) - maxi(0, min_x),
		mini(WorldData.HEIGHT, max_y) - maxi(0, min_y)
	)
