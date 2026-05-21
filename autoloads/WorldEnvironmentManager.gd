extends Node

## WorldEnvironmentManager - Consolidated environmental systems.
## Houses Weather, Wind, Ecology, and Disaster logic.

# === Wind System ===
const WIND_UPDATE_INTERVAL_TICKS: int = 240
const WIND_MIN_STRENGTH: float = 0.12
const WIND_MAX_STRENGTH: float = 0.85
const WIND_DIRECTION_SWAY_DEGREES: float = 35.0

var _wind_direction: Vector2 = Vector2.RIGHT
var _wind_strength: float = 0.3
var _last_wind_update_step: int = -1

# === Weather System ===
var _weather_blend: float = 0.02
var _fog_tint: Color = Color(0.95, 0.96, 0.98, 1.0)

func _ready() -> void:
	if GameManager != null:
		GameManager.game_tick.connect(_on_game_tick)
		_refresh_wind_for_tick(GameManager.tick_count)

func _on_game_tick(tick: int) -> void:
	_refresh_wind_for_tick(tick)
	_update_weather_state(tick)

# --- Wind Logic ---
func _refresh_wind_for_tick(tick: int) -> void:
	if tick < 0: return
	var step: int = int(tick / WIND_UPDATE_INTERVAL_TICKS)
	if step == _last_wind_update_step: return
	_last_wind_update_step = step

	var stream_name: StringName = &"wind:%d" % step
	var seed_salt: int = step * 97 + int(WorldRNG.current_seed()) * 13
	var base_angle: float = WorldRNG.range_for(stream_name, 0.0, TAU, seed_salt)
	var sway: float = sin(float(step) * 0.73 + float(WorldRNG.current_seed()) * 0.00031)
	var sway_radians: float = deg_to_rad(WIND_DIRECTION_SWAY_DEGREES) * sway
	var angle: float = base_angle + sway_radians
	_wind_direction = Vector2.from_angle(angle).normalized()

	var seasonal_bias: float = 0.0
	if Biome != null:
		var season: int = int(Biome.season_for_tick(tick))
		match season:
			Biome.Season.WINTER: seasonal_bias = 0.08
			Biome.Season.SUMMER: seasonal_bias = 0.12
			Biome.Season.SPRING: seasonal_bias = 0.04
			Biome.Season.AUTUMN: seasonal_bias = 0.06
	_wind_strength = clampf(WorldRNG.range_for(stream_name, WIND_MIN_STRENGTH, WIND_MAX_STRENGTH, seed_salt + 17) + seasonal_bias, WIND_MIN_STRENGTH, WIND_MAX_STRENGTH)

func get_wind_direction() -> Vector2: return _wind_direction
func get_wind_strength() -> float: return _wind_strength
func get_wind_vector() -> Vector2: return _wind_direction * _wind_strength

# --- Weather Logic ---
func _update_weather_state(_tick: int) -> void:
	# Future: More complex weather state transitions
	pass

static func apply_weather_tint(c: Color, x: int, y: int) -> Color:
	# Note: This is a static helper that doesn't use the singleton instance directly
	# to allow usage in shaders or low-level loops if needed.
	# But we can also provide a member-aware version.
	var inst = Engine.get_singleton("WorldEnvironmentManager")
	var now: int = GameManager.tick_count if GameManager != null else 0
	var phase: float = sin(float(now * 0.001 + x * 0.01 + y * 0.02))
	var blend: float = 0.02 + 0.03 * max(0.0, phase)
	var tint: Color = Color(0.95, 0.96, 0.98, 1.0)
	return c.lerp(tint, blend)
