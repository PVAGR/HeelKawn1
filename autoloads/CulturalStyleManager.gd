extends Node
## Biome-driven cultural architectural system.
## Settlements adopt visual styles based on their founding biome, with deterministic variation.
## Styles define material choices for buildings (e.g., stone_slab vs thatch vs ice_block).

## Maps Biome.Type (int) -> cultural style traits
const BIOME_STYLES: Dictionary = {
	# PLAINS: Wood-based, clustered layouts (settlers optimize for walkability)
	0: {  # Biome.Type.PLAINS
		"style_name": "Plains Settler",
		"roof_material": "thatch",
		"wall_material": "wood_log",
		"layout_pattern": "clustered",
		"base_build_material": 0,  # Item.Type.WOOD (see below for fallback)
	},
	# FOREST: Also wood-based but with stone accents (wood plenty, stone for durability)
	1: {  # Biome.Type.FOREST
		"style_name": "Forest Lodge",
		"roof_material": "thatch",
		"wall_material": "wood_log",
		"layout_pattern": "linear",
		"base_build_material": 0,  # Item.Type.WOOD
	},
	# DESERT: Mud brick and stone, linear for shade/trade routes
	2: {  # Biome.Type.DESERT
		"style_name": "Desert Mud-brick",
		"roof_material": "mud_brick",
		"wall_material": "mud_brick",
		"layout_pattern": "linear",
		"base_build_material": 3,  # Item.Type.STONE (substitute if no mud)
	},
	# TUNDRA: Ice and stone, radial for thermal efficiency
	3: {  # Biome.Type.TUNDRA
		"style_name": "Tundra Ice-lodge",
		"roof_material": "ice_block",
		"wall_material": "snow_block",
		"layout_pattern": "radial",
		"base_build_material": 3,  # Item.Type.STONE (backup)
	},
	# MOUNTAIN: Pure stone, defensive radial or clustered
	4: {  # Biome.Type.MOUNTAIN
		"style_name": "Mountain Stronghold",
		"roof_material": "stone_slab",
		"wall_material": "stone_block",
		"layout_pattern": "clustered",
		"base_build_material": 3,  # Item.Type.STONE
	},
	# WATER: Not spawnable; fallback to plains
	5: {  # Biome.Type.WATER
		"style_name": "Shoreline Camp",
		"roof_material": "thatch",
		"wall_material": "wood_log",
		"layout_pattern": "linear",
		"base_build_material": 0,  # Item.Type.WOOD
	},
	# STONE_FLOOR (mined-out): Stone/cave dwelling aesthetic
	6: {  # Biome.Type.STONE_FLOOR
		"style_name": "Stone Cavern",
		"roof_material": "stone_slab",
		"wall_material": "stone_block",
		"layout_pattern": "clustered",
		"base_build_material": 3,  # Item.Type.STONE
	},
}

## Hybrid (rare) cultural styles for flavor.
## When a settlement gets the 5% hybrid chance, it picks one of these instead of biome default.
const HYBRID_STYLES: Array[Dictionary] = [
	{
		"style_name": "Nomad Blend",
		"roof_material": "thatch",
		"wall_material": "wood_log",
		"layout_pattern": "linear",
		"base_build_material": 0,  # WOOD
	},
	{
		"style_name": "Trade Post",
		"roof_material": "mud_brick",
		"wall_material": "stone_block",
		"layout_pattern": "linear",
		"base_build_material": 3,  # STONE
	},
	{
		"style_name": "Fortress Hybrid",
		"roof_material": "stone_slab",
		"wall_material": "stone_block",
		"layout_pattern": "clustered",
		"base_build_material": 3,  # STONE
	},
]

## Per-settlement style tracking. settlement_id(int) -> style_dict
var settlement_styles: Dictionary = {}


## Get or assign a cultural style for a settlement.
## If not yet assigned, samples the biome and creates a deterministic style.
func get_or_assign_style(settlement_id: int, world: World, region_key: int) -> Dictionary:
	var sid: String = str(settlement_id)
	if settlement_styles.has(sid):
		return (settlement_styles[sid] as Dictionary).duplicate()
	
	# Sample biome at the center region
	var biome: int = _sample_biome_at_region(world, region_key)
	var style: Dictionary = _determine_style_for_biome(settlement_id, biome)
	settlement_styles[sid] = style
	return style.duplicate()


## Determine which architectural style based on biome + settlement determinism.
func _determine_style_for_biome(settlement_id: int, biome: int) -> Dictionary:
	# 5% chance for a hybrid style (deterministic based on settlement ID)
	var hybrid_chance: float = float((settlement_id * 37 + 11) % 100) / 100.0
	if hybrid_chance < 0.05:
		var hybrid_idx: int = abs((settlement_id * 41 + 17) % HYBRID_STYLES.size())
		var chosen: Dictionary = HYBRID_STYLES[hybrid_idx]
		return chosen.duplicate()
	
	# Otherwise, use biome-default style
	var default_style: Dictionary = BIOME_STYLES.get(biome, BIOME_STYLES[0]).duplicate()
	return default_style


## Sample the dominant biome in the region.
func _sample_biome_at_region(world: World, region_key: int) -> int:
	if world == null or world.data == null:
		return 0  # Default to PLAINS
	
	# Get tile coordinates for region center
	var region_x: int = (region_key % 256) * 16
	var region_y: int = (region_key / 256) * 16
	
	# Scan a 3x3 region block and count biome frequency
	var biome_count: Dictionary = {}
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var tx: int = region_x + dx * 16 + 8
			var ty: int = region_y + dy * 16 + 8
			if tx < 0 or ty < 0:
				continue
			var b: int = int(world.data.get_biome(tx, ty))
			biome_count[b] = int(biome_count.get(b, 0)) + 1
	
	# Return most frequent biome
	if biome_count.is_empty():
		return 0
	var dominant: int = 0
	var max_count: int = 0
	for b_any in biome_count.keys():
		var b: int = int(b_any)
		var count: int = int(biome_count[b])
		if count > max_count:
			max_count = count
			dominant = b
	return dominant


## Get the build material for a job type based on settlement's cultural style.
## Returns Item.Type (int) that should be consumed for this build job.
## Falls back to standard material if the style-material isn't available.
func get_build_material_for_settlement(settlement_id: int, job_type: int) -> int:
	var sid: String = str(settlement_id)
	var style: Dictionary = settlement_styles.get(sid, {})
	if style.is_empty():
		# Fall back to default (WOOD)
		return 0  # Item.Type.WOOD
	
	# For now, use base_build_material from the style
	# Future: could differentiate by job type (e.g., WALL vs BED)
	return int(style.get("base_build_material", 0))


## Get style description for display/debugging.
func describe_settlement_style(settlement_id: int) -> String:
	var sid: String = str(settlement_id)
	var style: Dictionary = settlement_styles.get(sid, {})
	if style.is_empty():
		return "Unknown"
	return str(style.get("style_name", "Unknown"))


## Clear all stored styles (call on new game or reload).
func clear() -> void:
	settlement_styles.clear()


## Save/load for persistence.
func to_dict() -> Dictionary:
	return {"settlement_styles": settlement_styles.duplicate(true)}


func from_dict(data: Dictionary) -> void:
	settlement_styles = (data.get("settlement_styles", {}) as Dictionary).duplicate(true)
