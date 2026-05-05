class_name WeatherOverlay
extends CanvasLayer

## Atmospheric weather overlay: rain in forests/plains, snow in tundra,
## heat shimmer in desert, sand particles in desert wind.
## Driven by DayNightCycle phase and camera biome.

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


func initialize(world_ref: World, camera_ref: Camera2D) -> void:
	_world = world_ref
	_camera = camera_ref


func _process(_delta: float) -> void:
	_tick_counter += 1
	if _tick_counter % REFRESH_EVERY_N_TICKS == 0:
		_update_weather()


func _update_weather() -> void:
	if _camera == null or _world == null:
		return

	var cam_tile: Vector2i = _world.world_to_tile(_camera.global_position)
	if not _world.data.in_bounds(cam_tile.x, cam_tile.y):
		return

	var biome: int = _world.data.get_biome(cam_tile.x, cam_tile.y)
	var is_night: bool = DayNightCycle.is_night_for_tick(GameManager.tick_count)

	# Determine weather based on biome + time
	var target: String = "none"
	match biome:
		Biome.Type.FOREST, Biome.Type.PLAINS:
			target = "rain" if not is_night else "rain"
		Biome.Type.TUNDRA:
			target = "snow"
		Biome.Type.DESERT:
			target = "sand" if not is_night else "embers"
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
		mat.turbulence_strength = turbulence

	p.process_material = mat
	p.modulate = color
	return p
