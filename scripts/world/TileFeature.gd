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
	# --- Shelter / Storage / Hearth / Marker (sacred early order) ---
	FIRE_PIT,      # hearth: warmth, cooking, gathering point; prevents hypothermia
	STORAGE_HUT,   # expanded storage: higher capacity, slower spoilage
	MARKER_STONE,  # carved stone: territorial marker, boosts morale, navigation aid
	SHRINE,        # ritual site: cultural memory anchor, mood recovery
	# --- Record Carriers (Phase 5: Knowledge Ecology) ---
	GRAVE_MARKER,      # grave: preserves memory of dead, knowledge marker
	KNOWLEDGE_STONE,   # carved stone: stores knowledge for rediscovery
	LEDGER_STONE,      # record stone: stores settlement history, teachings
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
	Type.FIRE_PIT:     Color8(255, 140,  30),  # warm fire orange
	Type.STORAGE_HUT:  Color8(150, 120,  70),  # tan/brown -- reads as storage
	Type.MARKER_STONE: Color8(140, 140, 150),  # carved gray stone
	Type.SHRINE:       Color8(180, 160, 200),  # muted purple -- sacred feel
	# Record Carriers
	Type.GRAVE_MARKER:    Color8(120, 120, 130),  # somber gray grave
	Type.KNOWLEDGE_STONE: Color8(100, 140, 180),  # blue-ish knowledge stone
	Type.LEDGER_STONE:    Color8(160, 140, 100),  # tan/brown record stone
}

const NAMES: Dictionary = {
	Type.NONE:           "None",
	Type.ORE_VEIN:       "Ore Vein",
	Type.FERTILE_SOIL:   "Fertile Soil",
	Type.RUIN:           "Ruin",
	Type.TREE:           "Tree",
	Type.BED:            "Bed",
	Type.WALL:           "Wall",
	Type.DOOR:           "Door",
	Type.RABBIT:         "Rabbit",
	Type.DEER:           "Deer",
	Type.FIRE_PIT:       "Fire Pit",
	Type.STORAGE_HUT:    "Storage Hut",
	Type.MARKER_STONE:   "Marker Stone",
	Type.SHRINE:         "Shrine",
	# Record Carriers
	Type.GRAVE_MARKER:    "Grave Marker",
	Type.KNOWLEDGE_STONE: "Knowledge Stone",
	Type.LEDGER_STONE:    "Ledger Stone",
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
## Extended for cultural architectural styles: fire pits, markers, shrines get stronger tints.
static func apply_culture_tint_to_built_color(base: Color, culture_type: int) -> Color:
	var tint_strength: float = 0.075
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
	return base.lerp(base * mul, tint_strength)


## Stronger cultural tint for landmark buildings (fire pits, shrines, markers).
static func apply_culture_landmark_tint(base: Color, culture_type: int) -> Color:
	const TINT: float = 0.15  # Stronger than regular buildings
	var warm: Color = Color(1.08, 1.04, 0.92, 1.0)   # golden warmth
	var cool: Color = Color(0.88, 0.92, 1.08, 1.0)   # steely cool
	var neut: Color = Color(1.0, 1.0, 1.0, 1.0)
	var mul: Color = neut
	if culture_type == SettlementPlanner.CULTURE_OPEN:
		mul = warm
	elif culture_type == SettlementPlanner.CULTURE_DEFENSIVE:
		mul = cool
	elif culture_type == SettlementPlanner.CULTURE_CAUTIOUS:
		mul = Color(1.02, 1.0, 0.99, 1.0)
	return base.lerp(base * mul, TINT)


## Apply settlement state-based tint (Phase 4: posture visual indicators)
## Adds desaturation/darkening based on settlement lifecycle state (active/reviving/abandoned/permanent_ruin)
## while keeping the legacy labels accepted for back-compat.
static func apply_settlement_state_tint(base: Color, settlement_state: String) -> Color:
	const STATE_TINT: float = 0.15
	var state_mul: Color = Color(1.0, 1.0, 1.0, 1.0)
	
	match settlement_state:
		"active":
			# No additional tint - use culture tint only
			return base
		"reviving", "revivable":
			# Slightly worn/faded
			state_mul = Color(0.95, 0.93, 0.90, 1.0)
		"abandoned", "recovering":
			# Gray-brown, muted
			state_mul = Color(0.85, 0.82, 0.78, 1.0)
		"permanent_ruin", "permanently_abandoned":
			# Cold gray, near-black
			state_mul = Color(0.55, 0.55, 0.50, 1.0)
		_:
			# Default: no state tint
			return base
	
	return base.lerp(base * state_mul, STATE_TINT)
