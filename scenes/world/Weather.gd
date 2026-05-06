extends Node

static func apply_weather_tint(c: Color, x: int, y: int) -> Color:
	var now: int = GameManager.tick_count
	var phase: float = sin(float(now * 0.001 + x * 0.01 + y * 0.02))
	var weather_blend: float = 0.02 + 0.03 * max(0.0, phase) # Fog 2-5%
	var fog_tint: Color = Color(0.95, 0.96, 0.98, 1.0) # Cool mist
	return c.lerp(fog_tint, weather_blend)

