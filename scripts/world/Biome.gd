class_name Biome
extends RefCounted

## Biome types used by WorldGenerator and WorldData.
## Stored as a single byte per tile in WorldData.biomes.
enum Type {
	PLAINS,
	FOREST,
	DESERT,
	TUNDRA,
	MOUNTAIN,
	WATER,
	STONE_FLOOR,  # mined-out mountain rock; passable, slow, leaves a visible scar
}

## Seasons: 4 per sim year, each ~12-13 visual days
enum Season {
	SPRING,
	SUMMER,
	AUTUMN,
	WINTER,
}

## Display color for each biome in the v1 pixel-rendered world (base = summer).
const COLORS: Dictionary = {
	Type.PLAINS:      Color8(124, 179,  66),
	Type.FOREST:      Color8( 46, 125,  50),
	Type.DESERT:      Color8(253, 216,  53),
	Type.TUNDRA:      Color8(224, 242, 241),
	Type.MOUNTAIN:    Color8(109,  76,  65),
	Type.WATER:       Color8( 25, 118, 210),
	Type.STONE_FLOOR: Color8(158, 142, 130),  # cool light gray-brown, distinct from mountain
}

## Seasonal color modifiers: lerp toward these from base color
## Each season shifts the palette: spring=brighter green, summer=base, autumn=amber, winter=desaturated blue
const SEASON_TINT: Dictionary = {
	Season.SPRING: {  # +green, +bright
		Type.PLAINS:      Color(0.15, 0.25, 0.0),
		Type.FOREST:      Color(0.1, 0.2, 0.0),
		Type.DESERT:      Color(0.0, 0.05, 0.0),
		Type.TUNDRA:      Color(0.05, 0.1, 0.05),
		Type.MOUNTAIN:    Color(0.05, 0.05, 0.0),
		Type.WATER:       Color(0.0, 0.1, 0.05),
		Type.STONE_FLOOR: Color(0.0, 0.0, 0.0),
	},
	Season.SUMMER: {  # base colors, no shift
		Type.PLAINS:      Color(0.0, 0.0, 0.0),
		Type.FOREST:      Color(0.0, 0.0, 0.0),
		Type.DESERT:      Color(0.0, 0.0, 0.0),
		Type.TUNDRA:      Color(0.0, 0.0, 0.0),
		Type.MOUNTAIN:    Color(0.0, 0.0, 0.0),
		Type.WATER:       Color(0.0, 0.0, 0.0),
		Type.STONE_FLOOR: Color(0.0, 0.0, 0.0),
	},
	Season.AUTUMN: {  # +amber, -green
		Type.PLAINS:      Color(0.2, 0.05, -0.15),
		Type.FOREST:      Color(0.15, 0.0, -0.15),
		Type.DESERT:      Color(0.05, -0.05, -0.1),
		Type.TUNDRA:      Color(0.1, 0.0, -0.05),
		Type.MOUNTAIN:    Color(0.05, 0.0, -0.02),
		Type.WATER:       Color(0.0, -0.05, -0.05),
		Type.STONE_FLOOR: Color(0.03, 0.0, -0.02),
	},
	Season.WINTER: {  # +blue, -saturation
		Type.PLAINS:      Color(-0.15, -0.2, 0.1),
		Type.FOREST:      Color(-0.1, -0.15, 0.08),
		Type.DESERT:      Color(-0.05, -0.1, 0.05),
		Type.TUNDRA:      Color(-0.05, -0.05, 0.1),
		Type.MOUNTAIN:    Color(-0.05, -0.05, 0.08),
		Type.WATER:       Color(-0.05, -0.05, 0.1),
		Type.STONE_FLOOR: Color(-0.05, -0.05, 0.05),
	},
}

const NAMES: Dictionary = {
	Type.PLAINS:      "Plains",
	Type.FOREST:      "Forest",
	Type.DESERT:      "Desert",
	Type.TUNDRA:      "Tundra",
	Type.MOUNTAIN:    "Mountain",
	Type.WATER:       "Water",
	Type.STONE_FLOOR: "Stone Floor",
}

const SEASON_NAMES: Dictionary = {
	Season.SPRING: "Spring",
	Season.SUMMER: "Summer",
	Season.AUTUMN: "Autumn",
	Season.WINTER: "Winter",
}

## Seasonal migration offset for wildlife: summer=hot areas, winter=warm areas
static func seasonal_migration_bias(season: String, biome: int) -> float:
	match biome:
		Type.PLAINS, Type.FOREST:
			if season == "winter": return -0.3
			if season == "spring": return 0.2
			if season == "summer": return 0.1
			if season == "fall": return 0.0
		Type.MOUNTAIN:
			if season == "winter": return -0.5
			if season == "spring": return 0.0
			if season == "summer": return 0.3
		Type.DESERT:
			if season == "winter": return 0.3
			if season == "summer": return -0.4
		Type.TUNDRA:
			if season == "summer": return 0.2
			if season == "winter": return -0.6
	return 0.0


## Movement cost multiplier. Biomes with IMPASSABLE must be cleared (mined,
## bridged, etc.) before they can be traversed. This is why the pawn
## pathfinder will refuse to route paths through mountains -- they're raw
## rock that has to be mined out, RimWorld-style.
const IMPASSABLE: float = 9999.0
const MOVEMENT_COST: Dictionary = {
	Type.PLAINS:      1.0,
	Type.FOREST:      1.4,
	Type.DESERT:      1.2,
	Type.TUNDRA:      1.3,
	Type.MOUNTAIN:    IMPASSABLE,
	Type.WATER:       IMPASSABLE,
	Type.STONE_FLOOR: 1.6,
}


static func color_for(biome: int) -> Color:
	return COLORS.get(biome, Color.MAGENTA)


static func color_for_season(biome: int, season: int) -> Color:
	var base: Color = COLORS.get(biome, Color.MAGENTA)
	var tint_dict: Dictionary = SEASON_TINT.get(season, {})
	var tint: Color = tint_dict.get(biome, Color(0, 0, 0))
	return Color(
		clampf(base.r + tint.r, 0.0, 1.0),
		clampf(base.g + tint.g, 0.0, 1.0),
		clampf(base.b + tint.b, 0.0, 1.0),
		1.0
	)


static func season_for_tick(tick: int) -> int:
	## 50 visual days per sim year → 4 seasons of ~12-13 days each
	var day_in_year: int = SimTime.visual_day_within_sim_year(tick) - 1  # 0-based
	var days_per_season: int = SimTime.visual_days_per_sim_year() / 4
	var season_idx: int = day_in_year / days_per_season
	return clampi(season_idx, 0, 3)


static func season_name(season: int) -> String:
	return SEASON_NAMES.get(season, "Unknown")


static func name_for(biome: int) -> String:
	return NAMES.get(biome, "Unknown")


static func is_passable(biome: int) -> bool:
	return MOVEMENT_COST.get(biome, IMPASSABLE) < IMPASSABLE
