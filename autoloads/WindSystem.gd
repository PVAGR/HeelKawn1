extends Node

## Wrapper for WorldEnvironmentManager.

func get_wind_direction() -> Vector2:
	return WorldEnvironmentManager.get_wind_direction()

func get_wind_strength() -> float:
	return WorldEnvironmentManager.get_wind_strength()

func get_wind_vector() -> Vector2:
	return WorldEnvironmentManager.get_wind_vector()

func get_wind_angle_degrees() -> float:
	return rad_to_deg(get_wind_direction().angle())

func get_wind_sway_degrees() -> float:
	return get_wind_angle_degrees() * get_wind_strength() * 0.08

func get_wind_bias() -> Vector2:
	return get_wind_vector()

func is_blowing_from(direction: Vector2) -> bool:
	if direction.is_zero_approx():
		return false
	return get_wind_direction().dot(direction.normalized()) > 0.75
