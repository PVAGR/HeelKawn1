extends Node

class_name FoliageSystem

## Procedural foliage overlay for livable feel (grass/flowers sway).
## Tick-driven, deterministic per tile.

const FOLIAGE_SEED_SALT: int = 0x4f6c69 # "Foli"

static func apply_foliage_tint(c: Color, x: int, y: int, biome: int) -> Color:
	if biome not in [Biome.Type.PLAINS, Biome.Type.FOREST]:
		return c
	var sway_phase: float = sin((float(GameManager.tick_count) * 0.03 + float(x * 17 + y * 31) / 256.0))
	var grass_blend: float = 0.08 + 0.04 * sway_phase
	var grass_tint: Color = Color(0.45, 0.62, 0.38, 1.0) # Earthy green
	return c.lerp(grass_tint, grass_blend)

static func foliage_density(x: int, y: int) -> float:
	var seed_value: int = x * 123 + y * 456
	var rng = WorldRNG.stream_seed(str(FOLIAGE_SEED_SALT + seed_value))
	return 0.2 + 0.3 * rng.randf() # 20-50% tiles


