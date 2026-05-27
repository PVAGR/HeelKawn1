extends Resource
class_name StructureCatalog

## Visual-only catalog for the construction overlay.
## It describes how to draw a completed structure and how to recognize the
## matching build job, but it never mutates simulation state.

const STRUCTURES: Dictionary = {
	"storage_hut": {
		"label": "Storage Hut",
		"feature_type": TileFeature.Type.STORAGE_HUT,
		"job_type": Job.Type.BUILD_STORAGE_HUT,
		"sprite_kind": "hut",
		"footprint": Vector2i(1, 1),
		"placement": {"requires_passable": true, "min_clearance": 1},
	},
	"bed": {
		"label": "Bed",
		"feature_type": TileFeature.Type.BED,
		"job_type": Job.Type.BUILD_BED,
		"sprite_kind": "bed",
		"footprint": Vector2i(1, 1),
		"placement": {"requires_passable": true, "min_clearance": 1},
	},
	"fire_pit": {
		"label": "Fire Pit",
		"feature_type": TileFeature.Type.FIRE_PIT,
		"job_type": Job.Type.BUILD_FIRE_PIT,
		"sprite_kind": "fire_pit",
		"footprint": Vector2i(1, 1),
		"placement": {"requires_passable": true, "min_clearance": 1},
	},
	"workshop": {
		"label": "Workshop",
		"feature_type": TileFeature.Type.WORKSHOP,
		"job_type": Job.Type.BUILD_WORKSHOP,
		"sprite_kind": "workshop",
		"footprint": Vector2i(2, 2),
		"placement": {"requires_passable": true, "min_clearance": 2},
	},
	"wall": {
		"label": "Wall",
		"feature_type": TileFeature.Type.WALL,
		"job_type": Job.Type.BUILD_WALL,
		"sprite_kind": "wall",
		"footprint": Vector2i(1, 1),
		"placement": {"requires_passable": false, "min_clearance": 1},
	},
	"door": {
		"label": "Door",
		"feature_type": TileFeature.Type.DOOR,
		"job_type": Job.Type.BUILD_DOOR,
		"sprite_kind": "door",
		"footprint": Vector2i(1, 1),
		"placement": {"requires_passable": true, "min_clearance": 1},
	},
	"barracks": {
		"label": "Barracks",
		"feature_type": TileFeature.Type.BARRACKS,
		"job_type": Job.Type.BUILD_BARRACKS,
		"sprite_kind": "barracks",
		"footprint": Vector2i(2, 2),
		"placement": {"requires_passable": true, "min_clearance": 2},
	},
	"granary": {
		"label": "Granary",
		"feature_type": TileFeature.Type.GRANARY,
		"job_type": Job.Type.BUILD_GRANARY,
		"sprite_kind": "granary",
		"footprint": Vector2i(2, 2),
		"placement": {"requires_passable": true, "min_clearance": 2},
	},
	"apothecary": {
		"label": "Apothecary",
		"feature_type": TileFeature.Type.APOTHECARY,
		"job_type": Job.Type.BUILD_APOTHECARY,
		"sprite_kind": "apothecary",
		"footprint": Vector2i(2, 2),
		"placement": {"requires_passable": true, "min_clearance": 2},
	},
	"library": {
		"label": "Library",
		"feature_type": TileFeature.Type.LIBRARY,
		"job_type": Job.Type.BUILD_LIBRARY,
		"sprite_kind": "library",
		"footprint": Vector2i(2, 2),
		"placement": {"requires_passable": true, "min_clearance": 2},
	},
	"road": {
		"label": "Road",
		"feature_type": TileFeature.Type.ROAD,
		"job_type": Job.Type.BUILD_ROAD,
		"sprite_kind": "road",
		"footprint": Vector2i(1, 1),
		"placement": {"requires_passable": true, "min_clearance": 1},
	},
	"cellar": {
		"label": "Cellar",
		"feature_type": TileFeature.Type.CELLAR,
		"job_type": Job.Type.BUILD_CELLAR,
		"sprite_kind": "cellar",
		"footprint": Vector2i(2, 2),
		"placement": {"requires_passable": true, "min_clearance": 2},
	},
	"market": {
		"label": "Market",
		"feature_type": TileFeature.Type.MARKET,
		"job_type": Job.Type.BUILD_MARKET,
		"sprite_kind": "market",
		"footprint": Vector2i(2, 2),
		"placement": {"requires_passable": true, "min_clearance": 2},
	},
}


static func has_feature(feature_type: int) -> bool:
	for key in STRUCTURES.keys():
		if int((STRUCTURES[key] as Dictionary).get("feature_type", -1)) == feature_type:
			return true
	return false


static func entry_for_feature(feature_type: int) -> Dictionary:
	for key in STRUCTURES.keys():
		var entry: Dictionary = STRUCTURES[key] as Dictionary
		if int(entry.get("feature_type", -1)) == feature_type:
			return entry.duplicate(true)
	return {}


static func entry_for_job(job_type: int) -> Dictionary:
	for key in STRUCTURES.keys():
		var entry: Dictionary = STRUCTURES[key] as Dictionary
		if int(entry.get("job_type", -1)) == job_type:
			return entry.duplicate(true)
	return {}


static func feature_for_job(job_type: int) -> int:
	return int(entry_for_job(job_type).get("feature_type", -1))


static func label_for_feature(feature_type: int) -> String:
	var entry: Dictionary = entry_for_feature(feature_type)
	return str(entry.get("label", TileFeature.name_for(feature_type)))


static func sprite_kind_for_feature(feature_type: int) -> String:
	var entry: Dictionary = entry_for_feature(feature_type)
	return str(entry.get("sprite_kind", "generic"))


static func placement_rule_for_feature(feature_type: int) -> Dictionary:
	var entry: Dictionary = entry_for_feature(feature_type)
	return (entry.get("placement", {}) as Dictionary).duplicate(true)
