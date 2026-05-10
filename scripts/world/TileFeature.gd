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
	# --- Agriculture (Phase 6: Civilization Progression) ---
	FARM_WHEAT,        # wheat field: yields 4 wheat per harvest, 2400 ticks
	FARM_CORN,         # corn field: yields 6 corn per harvest, 3200 ticks
	FARM_VEGETABLES,   # vegetable garden: yields 5 veg per harvest, 2000 ticks
	HERB_GARDEN,       # herb garden: yields 3 herbs per harvest, 1600 ticks
	# --- Production (Phase 6) ---
	WORKSHOP,          # crafting workshop: enables advanced crafting, +1 craft speed
	LOOM,              # weaving loom: enables cloth production from plant fibers
	KILN,              # pottery kiln: enables pottery from clay, +1 storage
	SMELTER,           # ore smelter: enables metal tools from ore, +1 mining yield
	# --- Maritime (Phase 6) ---
	BOATYARD,          # ship construction: enables water trade routes and fishing
	DOCK,              # landing dock: enables trade unloading, +2 trade speed
	FISHERMAN_HUT,     # fishing hut: enables fishing jobs, +1 fish yield
	# --- Medicine (Phase 6) ---
	APOTHECARY,        # herb preparation: +2 healing rate, enables herbal remedies
	# --- Knowledge (Phase 6) ---
	LIBRARY,           # book storage: +2 knowledge spread, enables scholarship
	SCHOOL,            # teaching space: +3 teaching speed, enables apprenticeship
	# --- Military (Phase 6) ---
	BARRACKS,          # military housing: +2 defense, enables warrior profession
	WATCHTOWER,        # elevated guard: +4 detection range, +1 defense
	# --- Trade (Phase 6) ---
	MARKET,            # trade hub: +2 trade income, enables merchant profession
	TRADING_POST,      # inter-settlement trade: enables caravan routes
	# --- Infrastructure (Phase 6) ---
	ROAD,              # paved path: +1.5 movement speed, passable
	# --- Storage (Phase 6) ---
	GRANARY,           # food storage: +4 food capacity, -50% spoilage
	CELLAR,            # underground storage: +6 capacity, -75% spoilage
	# --- Terrain Features ---
	RIVER,             # river tile: enables fishing, fishing hut proximity, water movement
	# --- River Crossings ---
	FORD,              # shallow ford: passable water crossing, low movement cost
	# --- Production (Phase 6) ---
	WATER_MILL,        # water mill: +crafting speed when adjacent to river
	# --- Transient terrain effects ---
	FLOOD_DEPOSIT,     # flood nutrient deposit: temporary fertility boost after overflow
}

## Colors used for the v1 pixel renderer. Chosen to pop against the biome below.
const COLORS: Dictionary = {
	Type.NONE:         Color(0, 0, 0, 0),
	Type.ORE_VEIN:     Color8(255, 111,   0),
	Type.FERTILE_SOIL: Color8( 51, 105,  30),
	Type.RUIN:         Color8(88,  72,  66),  # rubble / collapsed (proc + historical)
	Type.TREE:         Color8( 27,  73,  29),  # very dark forest green
	Type.BED:          Color8(220, 180, 120),  # warm wheat -- reads as built furniture
	Type.WALL:         Color8(120,  75,  40),  # visible wood-brown plank (brighter for perimeter visibility)
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
	# Agriculture
	Type.FARM_WHEAT:      Color8(200, 180,  60),  # golden wheat
	Type.FARM_CORN:       Color8(220, 190,  40),  # bright corn yellow
	Type.FARM_VEGETABLES: Color8( 60, 160,  60),  # fresh green
	Type.HERB_GARDEN:     Color8( 80, 140,  60),  # herbal green
	# Production
	Type.WORKSHOP:        Color8(160, 120,  80),  # warm wood workshop
	Type.LOOM:            Color8(180, 150, 170),  # soft cloth purple
	Type.KILN:            Color8(200, 100,  50),  # fired orange
	Type.SMELTER:         Color8(140,  80,  60),  # dark smelt brown
	# Maritime
	Type.BOATYARD:        Color8(120,  80,  40),  # dark wood dock
	Type.DOCK:            Color8(100,  70,  35),  # weathered wood
	Type.FISHERMAN_HUT:   Color8( 90, 120, 140),  # sea blue-gray
	# Medicine
	Type.APOTHECARY:      Color8( 60, 150,  80),  # medicinal green
	# Knowledge
	Type.LIBRARY:         Color8(100,  80, 140),  # scholarly purple
	Type.SCHOOL:          Color8(130, 110, 150),  # lighter purple
	# Military
	Type.BARRACKS:        Color8(160,  60,  50),  # military red-brown
	Type.WATCHTOWER:      Color8(140, 100,  70),  # wood tower
	# Trade
	Type.MARKET:          Color8(220, 180,  50),  # gold market
	Type.TRADING_POST:    Color8(180, 150,  80),  # tan trade
	# Infrastructure
	Type.ROAD:            Color8(160, 150, 130),  # paved gray
	# Storage
	Type.GRANARY:         Color8(180, 160,  80),  # grain gold
	Type.CELLAR:          Color8(100,  90,  80),  # dark cellar
	Type.RIVER:           Color8( 40,  80, 140),  # blue river
	Type.FORD:            Color8( 60, 100, 120),  # shallow crossing
	Type.WATER_MILL:      Color8(160, 140, 100),  # mill wood-brown
	Type.FLOOD_DEPOSIT:   Color8( 90, 120,  70),  # fertile green-brown
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
	# Agriculture
	Type.FARM_WHEAT:      "Wheat Farm",
	Type.FARM_CORN:       "Corn Farm",
	Type.FARM_VEGETABLES: "Vegetable Garden",
	Type.HERB_GARDEN:     "Herb Garden",
	# Production
	Type.WORKSHOP:        "Workshop",
	Type.LOOM:            "Loom",
	Type.KILN:            "Kiln",
	Type.SMELTER:         "Smelter",
	# Maritime
	Type.BOATYARD:        "Boatyard",
	Type.DOCK:            "Dock",
	Type.FISHERMAN_HUT:   "Fisherman Hut",
	# Medicine
	Type.APOTHECARY:      "Apothecary",
	# Knowledge
	Type.LIBRARY:         "Library",
	Type.SCHOOL:          "School",
	# Military
	Type.BARRACKS:        "Barracks",
	Type.WATCHTOWER:      "Watchtower",
	# Trade
	Type.MARKET:          "Market",
	Type.TRADING_POST:    "Trading Post",
	# Infrastructure
	Type.ROAD:            "Road",
	# Storage
	Type.GRANARY:         "Granary",
	Type.CELLAR:          "Cellar",
	Type.RIVER:           "River",
	Type.FORD:            "Ford",
	Type.WATER_MILL:      "Water Mill",
	Type.FLOOD_DEPOSIT:   "Flood Deposit",
}


## True if a feature is huntable wildlife. Centralizes the rabbit/deer test
## so callers (job seeding, regrowth, validation) don't have to enumerate.
static func is_wildlife(f: int) -> bool:
	return f == Type.RABBIT or f == Type.DEER


static func color_for(f: int) -> Color:
	return COLORS.get(f, Color.MAGENTA)


static func name_for(f: int) -> String:
	return NAMES.get(f, "Unknown")


## Subtle deterministic tint for built furniture (read-only render; [SettlementManager] branch ints).
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
	elif culture_type == SettlementManager.CULTURE_CAUTIOUS:
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
	elif culture_type == SettlementManager.CULTURE_CAUTIOUS:
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
