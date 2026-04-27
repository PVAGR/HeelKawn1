class_name TileFeature
extends RefCounted

## Resource / point-of-interest overlays that sit on top of a tile's biome.
## Stored as one byte per tile in WorldData.features. NONE means "bare biome".
enum Type {
	NONE,
	ORE_VEIN,
	FERTILE_SOIL,
	RUIN,
	TREE,
	BED,           # built by pawns from wood; passable; speeds up sleep recovery
	WALL,          # built by pawns from wood; impassable; blocks pathing + LoS
	DOOR,          # built by pawns from wood; passable; future: open/close state
	RABBIT,        # passive wildlife; HUNT yields 1 meat; respawns
	DEER,          # passive wildlife; HUNT yields 2 meat; slower hunt; respawns
}

## Colors used for the v1 pixel renderer. Chosen to pop against the biome below.
const COLORS: Dictionary = {
	Type.NONE:         Color(0, 0, 0, 0),
	Type.ORE_VEIN:     Color8(255, 111,   0),
	Type.FERTILE_SOIL: Color8( 51, 105,  30),
	Type.RUIN:         Color8(88,  72,  66),  # rubble / collapsed (proc + historical)
	Type.TREE:         Color8( 27,  73,  29),  # very dark forest green
	Type.BED:          Color8(220, 180, 120),  # warm wheat -- reads as built furniture
	Type.WALL:         Color8( 90,  60,  35),  # dark wood-brown plank
	Type.DOOR:         Color8(160, 100,  45),  # lighter wood, slightly orange
	Type.RABBIT:       Color8(245, 240, 230),  # off-white; reads against grass + sand
	Type.DEER:         Color8(170, 110,  55),  # warm tan; obvious "animal" sprite
}

const NAMES: Dictionary = {
	Type.NONE:         "None",
	Type.ORE_VEIN:     "Ore Vein",
	Type.FERTILE_SOIL: "Fertile Soil",
	Type.RUIN:         "Ruin",
	Type.TREE:         "Tree",
	Type.BED:          "Bed",
	Type.WALL:         "Wall",
	Type.DOOR:         "Door",
	Type.RABBIT:       "Rabbit",
	Type.DEER:         "Deer",
}


## True if a feature is huntable wildlife. Centralizes the rabbit/deer test
## so callers (job seeding, regrowth, validation) don't have to enumerate.
static func is_wildlife(f: int) -> bool:
	return f == Type.RABBIT or f == Type.DEER


static func color_for(f: int) -> Color:
	return COLORS.get(f, Color.MAGENTA)


static func name_for(f: int) -> String:
	return NAMES.get(f, "Unknown")


## Subtle deterministic tint for built furniture (read-only render; [SettlementPlanner] branch ints).
static func apply_culture_tint_to_built_color(base: Color, culture_type: int) -> Color:
	const TINT: float = 0.075
	var warm: Color = Color(1.03, 1.01, 0.96, 1.0)
	var cool: Color = Color(0.94, 0.97, 1.04, 1.0)
	var neut: Color = Color(1.0, 1.0, 1.0, 1.0)
	var mul: Color = neut
	if culture_type == SettlementPlanner.CULTURE_OPEN:
		mul = warm
	elif culture_type == SettlementPlanner.CULTURE_DEFENSIVE:
		mul = cool
	elif culture_type == SettlementPlanner.CULTURE_CAUTIOUS:
		mul = Color(1.01, 1.0, 0.995, 1.0)
	return base.lerp(base * mul, TINT)
