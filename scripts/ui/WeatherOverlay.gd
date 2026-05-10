class_name WeatherOverlay
extends CanvasLayer

## Atmospheric weather overlay: rain in forests/plains, snow in tundra,
## heat shimmer in desert, sand particles in desert wind.
## Driven by DayNightCycle phase and camera biome.
## Also provides gameplay effects: fire suppression, crop growth modifier,
## temperature effects on pawns. Exposes get_current_weather() for other systems.

const RAIN_COLOR: Color = Color(0.55, 0.65, 0.85, 0.35)
const SNOW_COLOR: Color = Color(0.9, 0.92, 0.98, 0.5)
const SAND_COLOR: Color = Color(0.85, 0.75, 0.55, 0.3)
const EMBER_COLOR: Color = Color(0.9, 0.4, 0.1, 0.25)
const RAIN_AMOUNT: int = 60
const SNOW_AMOUNT: int = 40
const SAND_AMOUNT: int = 25
const EMBER_AMOUNT: int = 15
const REFRESH_EVERY_N_TICKS: int = 60

var _world: World = null
var _camera: Camera2D = null
var _rain: GPUParticles2D = null
var _snow: GPUParticles2D = null
var _sand: GPUParticles2D = null
var _embers: GPUParticles2D = null
var _tick_counter: int = 0
var _current_weather: String = ""

## Fog of war overlay texture
var _fog_image: Image = null
var _fog_texture: ImageTexture = null
var _fog_sprite: Sprite2D = null
var _fog_dirty: bool = false


func _ready() -> void:
	layer = 3
	# Create all particle systems upfront, disabled
	_rain = _make_weather_system("Rain", RAIN_COLOR, RAIN_AMOUNT, 1.2, Vector3(0.0, 200.0, 0.0), Vector3(0.0, 1.0, 0.0), 5.0, 80.0, 120.0, 0.5, 1.5, 10.0)
	_snow = _make_weather_system("Snow", SNOW_COLOR, SNOW_AMOUNT, 2.5, Vector3(-5.0, 40.0, 0.0), Vector3(0.0, 1.0, 0.0), 2.0, 15.0, 30.0, 0.8, 2.0, 5.0)
	_sand = _make_weather_system("Sand", SAND_COLOR, SAND_AMOUNT, 1.5, Vector3(50.0, 5.0, 0.0), Vector3(1.0, 0.0, 0.0), 15.0, 30.0, 60.0, 0.3, 0.8, 0.0)
	_embers = _make_weather_system("Embers", EMBER_COLOR, EMBER_AMOUNT, 2.0, Vector3(0.0, -30.0, 0.0), Vector3(0.0, -1.0, 0.0), 5.0, 10.0, 25.0, 0.2, 0.5, -5.0)

	add_child(_rain)
	add_child(_snow)
	add_child(_sand)
	add_child(_embers)

	# Initialize fog overlay (same size as world: 256x256 scaled by TILE_PIXELS=10)
	_fog_image = Image.create(WorldData.WIDTH, WorldData.HEIGHT, false, Image.FORMAT_RGBA8)
	_fog_image.fill(Color(0, 0, 0, 0))
	_fog_texture = ImageTexture.create_from_image(_fog_image)
	_fog_sprite = Sprite2D.new()
	_fog_sprite.texture = _fog_texture
	_fog_sprite.scale = Vector2(10, 10)  # TILE_PIXELS
	_fog_sprite.z_index = 100
	add_child(_fog_sprite)


func initialize(world_ref: World, camera_ref: Camera2D) -> void:
	_world = world_ref
	_camera = camera_ref


func _process(_delta: float) -> void:
	_tick_counter += 1
	if _tick_counter % REFRESH_EVERY_N_TICKS == 0:
		_update_weather()
		_update_fog()


func get_current_weather() -> String:
	return _current_weather


## Returns true if current weather affects gameplay (rain suppresses fires, snow slows)
func is_precipitating() -> bool:
	return _current_weather == "rain" or _current_weather == "snow"


## Fire suppression multiplier during rain (0 = no spread, 1 = normal)
func fire_spread_multiplier() -> float:
	match _current_weather:
		"rain": return 0.0
		"snow": return 0.2
		_: return 1.0


## Crop growth speed multiplier
func crop_growth_multiplier() -> float:
	match _current_weather:
		"rain": return 1.5
		_: return 1.0


func _update_weather() -> void:
	if _camera == null or _world == null:
		return

	var cam_tile: Vector2i = _world.world_to_tile(_camera.global_position)
	if not _world.data.in_bounds(cam_tile.x, cam_tile.y):
		return

	var biome: int = _world.data.get_biome(cam_tile.x, cam_tile.y)
	var is_night: bool = DayNightCycle.is_night_for_tick(GameManager.tick_count)
	var tick: int = GameManager.tick_count if GameManager != null else 0

	# Determine weather based on biome + time + tick variation (long-term patterns)
	var target: String = "none"
	var pattern: int = (tick / 6000) % 4  # Weather pattern changes every ~10 days
	match biome:
		Biome.Type.FOREST, Biome.Type.PLAINS:
			if pattern == 0 or pattern == 2:
				target = "rain" if not is_night else "rain"
			else:
				target = "none"
		Biome.Type.TUNDRA:
			if pattern == 0:
				target = "none"
			else:
				target = "snow"
		Biome.Type.DESERT:
			if pattern == 0:
				target = "sand"
			elif pattern == 2:
				target = "embers"
			else:
				target = "none"
		Biome.Type.MOUNTAIN:
			target = "snow"
		_:
			target = "none"

	if target == _current_weather:
		return

	_current_weather = target
	_rain.emitting = (target == "rain")
	_snow.emitting = (target == "snow")
	_sand.emitting = (target == "sand")
	_embers.emitting = (target == "embers")


## Update fog of war overlay: darken undiscovered tiles
func _update_fog() -> void:
	if _world == null or _world.data == null:
		return
	if _fog_image == null:
		return
	if not _fog_dirty and _tick_counter % (REFRESH_EVERY_N_TICKS * 10) != 0:
		return
	_fog_dirty = false
	var fog: Node = get_node_or_null("/root/FogOfDiscovery")
	if fog == null:
		return
	var cam_tile: Vector2i = _world.world_to_tile(_camera.global_position) if _camera != null else Vector2i(128, 128)
	var view_radius: int = 15
	# Only update tiles near camera for performance
	for dx in range(-view_radius, view_radius + 1):
		for dy in range(-view_radius, view_radius + 1):
			var tx: int = cam_tile.x + dx
			var ty: int = cam_tile.y + dy
			if not _world.data.in_bounds(tx, ty):
				continue
			var discovered: bool = false
			if fog.has_method("is_discovered"):
				discovered = fog.call("is_discovered", tx, ty)
			var alpha: float = 0.0 if discovered else 0.65
			var current: Color = _fog_image.get_pixel(tx, ty)
			if abs(current.a - alpha) > 0.01:
				_fog_image.set_pixel(tx, ty, Color(0, 0, 0, alpha))
	_fog_texture.update(_fog_image)


func _make_weather_system(
	name: String,
	color: Color,
	amount: int,
	lifetime: float,
	gravity: Vector3,
	direction: Vector3,
	spread: float,
	speed_min: float,
	speed_max: float,
	scale_min: float,
	scale_max: float,
	turbulence: float,
) -> GPUParticles2D:
	var p: GPUParticles2D = GPUParticles2D.new()
	p.name = name
	p.amount = amount
	p.lifetime = lifetime
	p.one_shot = false
	p.emitting = false
	p.explosiveness = 0.0
	p.randomness = 0.5
	p.local_coords = true

	# Position at top of viewport, cover screen
	p.position = Vector2.ZERO

	var mat: ParticleProcessMaterial = ParticleProcessMaterial.new()
	mat.direction = direction
	mat.spread = spread
	mat.gravity = gravity
	mat.initial_velocity_min = speed_min
	mat.initial_velocity_max = speed_max
	mat.scale_min = scale_min
	mat.scale_max = scale_max
	if turbulence > 0.0:
		mat.turbulence_enabled = true
		if "turbulence_strength" in mat:
			mat.turbulence_strength = turbulence

	p.process_material = mat
	p.modulate = color
	return p
