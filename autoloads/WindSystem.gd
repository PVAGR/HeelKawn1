extends Node

## Global wind tracking for sky motion, particle drift, and weather-facing visuals.
## Wind is deterministic: the same world seed and tick schedule produce the same
## direction/strength sequence.

const UPDATE_INTERVAL_TICKS: int = 240
const MIN_STRENGTH: float = 0.12
const MAX_STRENGTH: float = 0.85
const DIRECTION_SWAY_DEGREES: float = 35.0

var _current_direction: Vector2 = Vector2.RIGHT
var _current_strength: float = 0.3
var _last_update_step: int = -1


func _ready() -> void:
	if GameManager != null:
		GameManager.game_tick.connect(_on_game_tick)
		_refresh_for_tick(GameManager.tick_count)


func _on_game_tick(tick: int) -> void:
	_refresh_for_tick(tick)


func _refresh_for_tick(tick: int) -> void:
	if tick < 0:
		return
	var step: int = int(tick / UPDATE_INTERVAL_TICKS)
	if step == _last_update_step:
		return
	_last_update_step = step

	var stream_name: StringName = &"wind:%d" % step
	var seed_salt: int = step * 97 + int(WorldRNG.current_seed()) * 13
	var base_angle: float = WorldRNG.range_for(stream_name, 0.0, TAU, seed_salt)
	var sway: float = sin(float(step) * 0.73 + float(WorldRNG.current_seed()) * 0.00031)
	var sway_radians: float = deg_to_rad(DIRECTION_SWAY_DEGREES) * sway
	var angle: float = base_angle + sway_radians
	_current_direction = Vector2.from_angle(angle).normalized()

	var seasonal_bias: float = 0.0
	if Biome != null and Biome.has_method("season_for_tick"):
		var season: int = int(Biome.season_for_tick(tick))
		match season:
			Biome.Season.WINTER:
				seasonal_bias = 0.08
			Biome.Season.SUMMER:
				seasonal_bias = 0.12
			Biome.Season.SPRING:
				seasonal_bias = 0.04
			Biome.Season.AUTUMN:
				seasonal_bias = 0.06
			_:
				seasonal_bias = 0.0
	_current_strength = clampf(WorldRNG.range_for(stream_name, MIN_STRENGTH, MAX_STRENGTH, seed_salt + 17) + seasonal_bias, MIN_STRENGTH, MAX_STRENGTH)


func get_wind_direction() -> Vector2:
	return _current_direction


func get_wind_strength() -> float:
	return _current_strength


func get_wind_vector() -> Vector2:
	return _current_direction * _current_strength


func get_wind_angle_degrees() -> float:
	return rad_to_deg(_current_direction.angle())


func get_wind_sway_degrees() -> float:
	return get_wind_angle_degrees() * _current_strength * 0.08


func get_wind_bias() -> Vector2:
	return get_wind_vector()


func is_blowing_from(direction: Vector2) -> bool:
	if direction.is_zero_approx():
		return false
	return _current_direction.dot(direction.normalized()) > 0.75
