extends Node

## BuildingRegistry — Data-driven building definitions.
##
## Every building type is defined here as a dictionary entry. The code reads
## from this registry instead of hardcoded match blocks. Adding a new building
## is one entry here + one TileFeature.Type enum value + one Job.Type enum value.
##
## Each entry: { name, description, color, feature_type, job_type, cost, buffs,
##              requires_tech, work_ticks, category, passable, requires_water }

# Category constants for grouping
const CAT_HOUSING: String = "housing"
const CAT_AGRICULTURE: String = "agriculture"
const CAT_PRODUCTION: String = "production"
const CAT_MARITIME: String = "maritime"
const CAT_MEDICINE: String = "medicine"
const CAT_KNOWLEDGE: String = "knowledge"
const CAT_MILITARY: String = "military"
const CAT_TRADE: String = "trade"
const CAT_INFRASTRUCTURE: String = "infrastructure"
const CAT_STORAGE: String = "storage"
const CAT_CULTURAL: String = "cultural"
const CAT_RECORD: String = "record"

## Master building table. Key = building string ID.
## feature_type and job_type are filled at _ready() from TileFeature/Job enums.
var BUILDINGS: Dictionary = {}


func _ready() -> void:
	_init_buildings()


func _init_buildings() -> void:
	BUILDINGS = {
		# === HOUSING (original buildings) ===
		"bed": {
			"name": "Bed",
			"description": "Rest place. +3 rest recovery per tick.",
			"feature_type": TileFeature.Type.BED,
			"job_type": Job.Type.BUILD_BED,
			"cost": {"wood": 1},
			"buffs": {"rest_recovery": 3.0},
			"requires_tech": [],
			"work_ticks": 20,
			"category": CAT_HOUSING,
			"passable": true,
			"requires_water": false,
		},
		"wall": {
			"name": "Wall",
			"description": "Wooden barrier. Blocks movement and line of sight.",
			"feature_type": TileFeature.Type.WALL,
			"job_type": Job.Type.BUILD_WALL,
			"cost": {"wood": 2},
			"buffs": {"blocks_movement": true, "blocks_los": true},
			"requires_tech": [],
			"work_ticks": 25,
			"category": CAT_HOUSING,
			"passable": false,
			"requires_water": false,
		},
		"door": {
			"name": "Door",
			"description": "Passable entrance. Allows controlled access.",
			"feature_type": TileFeature.Type.DOOR,
			"job_type": Job.Type.BUILD_DOOR,
			"cost": {"wood": 1},
			"buffs": {"passable_entry": true},
			"requires_tech": [],
			"work_ticks": 20,
			"category": CAT_HOUSING,
			"passable": true,
			"requires_water": false,
		},
		"fire_pit": {
			"name": "Fire Pit",
			"description": "Warmth and cooking hub. +8 warmth, enables cooking.",
			"feature_type": TileFeature.Type.FIRE_PIT,
			"job_type": Job.Type.BUILD_FIRE_PIT,
			"cost": {"wood": 1, "stone": 1},
			"buffs": {"warmth": 8.0, "enables_cooking": true},
			"requires_tech": [],
			"work_ticks": 25,
			"category": CAT_HOUSING,
			"passable": true,
			"requires_water": false,
		},
		"storage_hut": {
			"name": "Storage Hut",
			"description": "Expanded storage. +4 capacity, slower spoilage.",
			"feature_type": TileFeature.Type.STORAGE_HUT,
			"job_type": Job.Type.BUILD_STORAGE_HUT,
			"cost": {"wood": 2},
			"buffs": {"storage_capacity": 4, "spoilage_reduction": 0.25},
			"requires_tech": [],
			"work_ticks": 30,
			"category": CAT_STORAGE,
			"passable": true,
			"requires_water": false,
		},
		"marker_stone": {
			"name": "Marker Stone",
			"description": "Territorial marker. Boosts morale, navigation aid.",
			"feature_type": TileFeature.Type.MARKER_STONE,
			"job_type": Job.Type.BUILD_MARKER_STONE,
			"cost": {"stone": 1, "stick": 1},
			"buffs": {"morale": 1.0, "navigation": true},
			"requires_tech": [],
			"work_ticks": 25,
			"category": CAT_CULTURAL,
			"passable": true,
			"requires_water": false,
		},
		"shrine": {
			"name": "Shrine",
			"description": "Ritual site. Cultural memory anchor, mood recovery.",
			"feature_type": TileFeature.Type.SHRINE,
			"job_type": Job.Type.BUILD_SHRINE,
			"cost": {"wood": 1, "stone": 2},
			"buffs": {"mood_recovery": 2.0, "cultural_anchor": true},
			"requires_tech": [],
			"work_ticks": 30,
			"category": CAT_CULTURAL,
			"passable": true,
			"requires_water": false,
		},
		"shelter": {
			"name": "Shelter",
			"description": "Basic shelter. +4 warmth, protects from weather.",
			"feature_type": TileFeature.Type.BED,  # Shelter uses BED feature internally
			"job_type": Job.Type.BUILD_SHELTER,
			"cost": {"wood": 3},
			"buffs": {"warmth": 4.0, "weather_protection": true},
			"requires_tech": [],
			"work_ticks": 35,
			"category": CAT_HOUSING,
			"passable": true,
			"requires_water": false,
		},
		"hearth": {
			"name": "Hearth",
			"description": "Central fire. +6 warmth, community gathering point.",
			"feature_type": TileFeature.Type.FIRE_PIT,  # Hearth uses FIRE_PIT feature
			"job_type": Job.Type.BUILD_HEARTH,
			"cost": {"wood": 2, "stone": 1},
			"buffs": {"warmth": 6.0, "gathering_point": true},
			"requires_tech": [],
			"work_ticks": 30,
			"category": CAT_HOUSING,
			"passable": true,
			"requires_water": false,
		},

		# === AGRICULTURE ===
		"farm_wheat": {
			"name": "Wheat Farm",
			"description": "Grows wheat. Yields 4 wheat per harvest. 2400 ticks to mature.",
			"feature_type": TileFeature.Type.FARM_WHEAT,
			"job_type": Job.Type.BUILD_FARM_WHEAT,
			"cost": {"wood": 1, "seeds": 1},
			"buffs": {"crop_type": "wheat", "yield": 4, "growth_ticks": 2400, "nutrition": 50},
			"requires_tech": ["farming"],
			"work_ticks": 30,
			"category": CAT_AGRICULTURE,
			"passable": true,
			"requires_water": false,
		},
		"farm_corn": {
			"name": "Corn Farm",
			"description": "Grows corn. Yields 6 corn per harvest. 3200 ticks to mature.",
			"feature_type": TileFeature.Type.FARM_CORN,
			"job_type": Job.Type.BUILD_FARM_CORN,
			"cost": {"wood": 1, "seeds": 1},
			"buffs": {"crop_type": "corn", "yield": 6, "growth_ticks": 3200, "nutrition": 60},
			"requires_tech": ["farming"],
			"work_ticks": 30,
			"category": CAT_AGRICULTURE,
			"passable": true,
			"requires_water": false,
		},
		"farm_vegetables": {
			"name": "Vegetable Garden",
			"description": "Grows vegetables. Yields 5 veg per harvest. 2000 ticks to mature.",
			"feature_type": TileFeature.Type.FARM_VEGETABLES,
			"job_type": Job.Type.BUILD_FARM_VEGETABLES,
			"cost": {"wood": 1, "seeds": 1},
			"buffs": {"crop_type": "vegetables", "yield": 5, "growth_ticks": 2000, "nutrition": 75},
			"requires_tech": ["farming"],
			"work_ticks": 30,
			"category": CAT_AGRICULTURE,
			"passable": true,
			"requires_water": false,
		},
		"herb_garden": {
			"name": "Herb Garden",
			"description": "Grows herbs. Yields 3 herbs per harvest. 1600 ticks. Medicine ingredient.",
			"feature_type": TileFeature.Type.HERB_GARDEN,
			"job_type": Job.Type.BUILD_HERB_GARDEN,
			"cost": {"wood": 1, "seeds": 1},
			"buffs": {"crop_type": "herbs", "yield": 3, "growth_ticks": 1600, "nutrition": 15, "medicine_bonus": true},
			"requires_tech": ["herbalism"],
			"work_ticks": 30,
			"category": CAT_AGRICULTURE,
			"passable": true,
			"requires_water": false,
		},

		# === PRODUCTION ===
		"workshop": {
			"name": "Workshop",
			"description": "Crafting workspace. Enables advanced crafting, +1 craft speed.",
			"feature_type": TileFeature.Type.WORKSHOP,
			"job_type": Job.Type.BUILD_WORKSHOP,
			"cost": {"wood": 3, "stone": 1},
			"buffs": {"enables_advanced_crafting": true, "craft_speed_bonus": 1.0},
			"requires_tech": ["woodworking"],
			"work_ticks": 40,
			"category": CAT_PRODUCTION,
			"passable": true,
			"requires_water": false,
		},
		"loom": {
			"name": "Loom",
			"description": "Weaving loom. Enables cloth production from plant fibers.",
			"feature_type": TileFeature.Type.LOOM,
			"job_type": Job.Type.BUILD_LOOM,
			"cost": {"wood": 2, "stick": 2},
			"buffs": {"enables_cloth": true, "cloth_yield": 2},
			"requires_tech": ["weaving"],
			"work_ticks": 35,
			"category": CAT_PRODUCTION,
			"passable": true,
			"requires_water": false,
		},
		"kiln": {
			"name": "Kiln",
			"description": "Pottery kiln. Enables pottery from clay, +1 storage efficiency.",
			"feature_type": TileFeature.Type.KILN,
			"job_type": Job.Type.BUILD_KILN,
			"cost": {"stone": 3, "wood": 1},
			"buffs": {"enables_pottery": true, "storage_efficiency": 1.0},
			"requires_tech": ["pottery"],
			"work_ticks": 40,
			"category": CAT_PRODUCTION,
			"passable": true,
			"requires_water": false,
		},
		"smelter": {
			"name": "Smelter",
			"description": "Ore smelter. Enables metal tools from ore, +1 mining yield.",
			"feature_type": TileFeature.Type.SMELTER,
			"job_type": Job.Type.BUILD_SMELTER,
			"cost": {"stone": 4, "wood": 2},
			"buffs": {"enables_metal_tools": true, "mining_yield_bonus": 1.0},
			"requires_tech": ["metallurgy"],
			"work_ticks": 50,
			"category": CAT_PRODUCTION,
			"passable": true,
			"requires_water": false,
		},

		# === MARITIME ===
		"boatyard": {
			"name": "Boatyard",
			"description": "Ship construction. Enables water trade routes and fishing boats.",
			"feature_type": TileFeature.Type.BOATYARD,
			"job_type": Job.Type.BUILD_BOATYARD,
			"cost": {"wood": 4, "stone": 2},
			"buffs": {"enables_water_trade": true, "enables_fishing": true},
			"requires_tech": ["boatbuilding"],
			"work_ticks": 60,
			"category": CAT_MARITIME,
			"passable": true,
			"requires_water": true,
		},
		"dock": {
			"name": "Dock",
			"description": "Landing dock. Enables trade unloading, +2 trade speed.",
			"feature_type": TileFeature.Type.DOCK,
			"job_type": Job.Type.BUILD_DOCK,
			"cost": {"wood": 3, "stone": 1},
			"buffs": {"enables_trade_unloading": true, "trade_speed_bonus": 2.0},
			"requires_tech": ["boatbuilding"],
			"work_ticks": 45,
			"category": CAT_MARITIME,
			"passable": true,
			"requires_water": true,
		},
		"fisherman_hut": {
			"name": "Fisherman Hut",
			"description": "Fishing shelter. Enables fishing jobs, +1 fish yield.",
			"feature_type": TileFeature.Type.FISHERMAN_HUT,
			"job_type": Job.Type.BUILD_FISHERMAN_HUT,
			"cost": {"wood": 2, "stick": 1},
			"buffs": {"enables_fishing": true, "fish_yield_bonus": 1.0},
			"requires_tech": ["fishing"],
			"work_ticks": 30,
			"category": CAT_MARITIME,
			"passable": true,
			"requires_water": true,
		},

		# === MEDICINE ===
		"apothecary": {
			"name": "Apothecary",
			"description": "Herb preparation. +2 healing rate, enables herbal remedies.",
			"feature_type": TileFeature.Type.APOTHECARY,
			"job_type": Job.Type.BUILD_APOTHECARY,
			"cost": {"wood": 2, "stone": 1, "herbs": 2},
			"buffs": {"healing_rate": 2.0, "enables_herbal": true},
			"requires_tech": ["herbalism"],
			"work_ticks": 40,
			"category": CAT_MEDICINE,
			"passable": true,
			"requires_water": false,
		},

		# === KNOWLEDGE ===
		"library": {
			"name": "Library",
			"description": "Book storage. +2 knowledge spread, enables scholarship.",
			"feature_type": TileFeature.Type.LIBRARY,
			"job_type": Job.Type.BUILD_LIBRARY,
			"cost": {"wood": 3, "stone": 2, "paper": 2},
			"buffs": {"knowledge_spread": 2.0, "enables_scholarship": true},
			"requires_tech": ["writing"],
			"work_ticks": 50,
			"category": CAT_KNOWLEDGE,
			"passable": true,
			"requires_water": false,
		},
		"school": {
			"name": "School",
			"description": "Teaching space. +3 teaching speed, enables apprenticeship.",
			"feature_type": TileFeature.Type.SCHOOL,
			"job_type": Job.Type.BUILD_SCHOOL,
			"cost": {"wood": 2, "stone": 1},
			"buffs": {"teaching_speed": 3.0, "enables_apprenticeship": true},
			"requires_tech": ["writing"],
			"work_ticks": 40,
			"category": CAT_KNOWLEDGE,
			"passable": true,
			"requires_water": false,
		},

		# === MILITARY ===
		"barracks": {
			"name": "Barracks",
			"description": "Military housing. +2 defense, enables warrior profession.",
			"feature_type": TileFeature.Type.BARRACKS,
			"job_type": Job.Type.BUILD_BARRACKS,
			"cost": {"wood": 3, "stone": 2},
			"buffs": {"defense": 2.0, "enables_warrior": true},
			"requires_tech": ["warfare"],
			"work_ticks": 45,
			"category": CAT_MILITARY,
			"passable": true,
			"requires_water": false,
		},
		"watchtower": {
			"name": "Watchtower",
			"description": "Elevated guard. +4 detection range, +1 defense.",
			"feature_type": TileFeature.Type.WATCHTOWER,
			"job_type": Job.Type.BUILD_WATCHTOWER,
			"cost": {"wood": 2, "stone": 1},
			"buffs": {"detection_range": 4.0, "defense": 1.0},
			"requires_tech": ["warfare"],
			"work_ticks": 35,
			"category": CAT_MILITARY,
			"passable": true,
			"requires_water": false,
		},

		# === TRADE ===
		"market": {
			"name": "Market",
			"description": "Trade hub. +2 trade income, enables merchant profession.",
			"feature_type": TileFeature.Type.MARKET,
			"job_type": Job.Type.BUILD_MARKET,
			"cost": {"wood": 3, "stone": 1},
			"buffs": {"trade_income": 2.0, "enables_merchant": true},
			"requires_tech": ["commerce"],
			"work_ticks": 40,
			"category": CAT_TRADE,
			"passable": true,
			"requires_water": false,
		},
		"trading_post": {
			"name": "Trading Post",
			"description": "Inter-settlement trade. Enables caravan routes.",
			"feature_type": TileFeature.Type.TRADING_POST,
			"job_type": Job.Type.BUILD_TRADING_POST,
			"cost": {"wood": 2, "stone": 1},
			"buffs": {"enables_caravans": true},
			"requires_tech": ["commerce"],
			"work_ticks": 35,
			"category": CAT_TRADE,
			"passable": true,
			"requires_water": false,
		},

		# === INFRASTRUCTURE ===
		"road": {
			"name": "Road",
			"description": "Paved path. +1.5 movement speed for all pawns.",
			"feature_type": TileFeature.Type.ROAD,
			"job_type": Job.Type.BUILD_ROAD,
			"cost": {"stone": 1},
			"buffs": {"movement_speed": 1.5},
			"requires_tech": ["stoneworking"],
			"work_ticks": 15,
			"category": CAT_INFRASTRUCTURE,
			"passable": true,
			"requires_water": false,
		},

		# === STORAGE ===
		"granary": {
			"name": "Granary",
			"description": "Food storage. +4 food capacity, -50% spoilage rate.",
			"feature_type": TileFeature.Type.GRANARY,
			"job_type": Job.Type.BUILD_GRANARY,
			"cost": {"wood": 3, "stone": 1},
			"buffs": {"food_capacity": 4, "spoilage_reduction": 0.5},
			"requires_tech": ["farming"],
			"work_ticks": 35,
			"category": CAT_STORAGE,
			"passable": true,
			"requires_water": false,
		},
		"cellar": {
			"name": "Cellar",
			"description": "Underground storage. +6 capacity, -75% spoilage rate.",
			"feature_type": TileFeature.Type.CELLAR,
			"job_type": Job.Type.BUILD_CELLAR,
			"cost": {"stone": 3, "wood": 1},
			"buffs": {"storage_capacity": 6, "spoilage_reduction": 0.75},
			"requires_tech": ["stoneworking"],
			"work_ticks": 40,
			"category": CAT_STORAGE,
			"passable": true,
			"requires_water": false,
		},

		# === RECORD CARRIERS (original) ===
		"grave_marker": {
			"name": "Grave Marker",
			"description": "Preserves memory of the dead. Knowledge marker.",
			"feature_type": TileFeature.Type.GRAVE_MARKER,
			"job_type": Job.Type.CARVE_GRAVE_MARKER,
			"cost": {"stone": 1},
			"buffs": {"memory_preservation": true},
			"requires_tech": [],
			"work_ticks": 25,
			"category": CAT_RECORD,
			"passable": true,
			"requires_water": false,
		},
		"knowledge_stone": {
			"name": "Knowledge Stone",
			"description": "Carved stone storing knowledge for rediscovery.",
			"feature_type": TileFeature.Type.KNOWLEDGE_STONE,
			"job_type": Job.Type.CARVE_KNOWLEDGE_STONE,
			"cost": {"stone": 1},
			"buffs": {"knowledge_storage": true},
			"requires_tech": [],
			"work_ticks": 30,
			"category": CAT_RECORD,
			"passable": true,
			"requires_water": false,
		},
		"ledger_stone": {
			"name": "Ledger Stone",
			"description": "Record stone. Stores settlement history and teachings.",
			"feature_type": TileFeature.Type.LEDGER_STONE,
			"job_type": Job.Type.CARVE_LEDGER_STONE,
			"cost": {"stone": 1},
			"buffs": {"history_storage": true},
			"requires_tech": [],
			"work_ticks": 30,
			"category": CAT_RECORD,
			"passable": true,
			"requires_water": false,
		},
	}


## Get a building definition by its string ID.
func get_building(building_id: String) -> Dictionary:
	return BUILDINGS.get(building_id, {})


## Get a building definition by its Job.Type.
func get_building_by_job_type(job_type: int) -> Dictionary:
	for id in BUILDINGS:
		var b: Dictionary = BUILDINGS[id]
		if int(b.get("job_type", -1)) == job_type:
			return b
	return {}


## Get a building definition by its TileFeature.Type.
func get_building_by_feature(feature_type: int) -> Dictionary:
	for id in BUILDINGS:
		var b: Dictionary = BUILDINGS[id]
		if int(b.get("feature_type", -1)) == feature_type:
			return b
	return {}


## Get all buildings in a category.
func get_buildings_by_category(category: String) -> Array:
	var result: Array = []
	for id in BUILDINGS:
		var b: Dictionary = BUILDINGS[id]
		if str(b.get("category", "")) == category:
			result.append(b)
	return result


## Get the feature type to place for a given job type.
func feature_type_for_job(job_type: int) -> int:
	var b: Dictionary = get_building_by_job_type(job_type)
	return int(b.get("feature_type", TileFeature.Type.NONE))


## Get the cost dictionary for a building by job type.
func cost_for_job(job_type: int) -> Dictionary:
	var b: Dictionary = get_building_by_job_type(job_type)
	return b.get("cost", {})


## Get the buffs dictionary for a building by feature type.
func buffs_for_feature(feature_type: int) -> Dictionary:
	var b: Dictionary = get_building_by_feature(feature_type)
	return b.get("buffs", {})


## Get the description for a building by feature type.
func description_for_feature(feature_type: int) -> String:
	var b: Dictionary = get_building_by_feature(feature_type)
	return str(b.get("description", ""))


## Check if a building requires water adjacency.
func requires_water(building_id: String) -> bool:
	var b: Dictionary = BUILDINGS.get(building_id, {})
	return bool(b.get("requires_water", false))


## Get total building count.
func total_building_count() -> int:
	return BUILDINGS.size()
