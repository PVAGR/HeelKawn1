class_name WorldData
extends RefCounted

## Source of truth for the colony map. Rendering, AI, pathfinding, and save/load
## all read from here. Packed arrays are used so a 256x256 world stays under a
## few hundred KB and iterates fast.

const WIDTH: int = 256
const HEIGHT: int = 256
const TILE_COUNT: int = WIDTH * HEIGHT

## One byte per tile, values are Biome.Type.
var biomes: PackedByteArray

## One byte per tile, values are TileFeature.Type. Most tiles will be NONE (0).
var features: PackedByteArray

## 0.0..1.0, higher = mountains, lower = lowlands.
var elevation: PackedFloat32Array

## 0.0..1.0, higher = wetter.
var moisture: PackedFloat32Array

var world_seed: int = 0

static var current: WorldData = null

func _init() -> void:
	biomes.resize(TILE_COUNT)
	features.resize(TILE_COUNT)
	elevation.resize(TILE_COUNT)
	moisture.resize(TILE_COUNT)


func index(x: int, y: int) -> int:
	return y * WIDTH + x


func in_bounds(x: int, y: int) -> bool:
	return x >= 0 and x < WIDTH and y >= 0 and y < HEIGHT


func get_biome(x: int, y: int) -> int:
	return biomes[index(x, y)]


## Overwrite a tile's biome. Used when a wall is mined out (MOUNTAIN ->
## STONE_FLOOR), and any future "build wall" / terraforming systems.
## Caller is responsible for refreshing the visual + pathfinder state.
func set_biome(x: int, y: int, biome: int) -> void:
	if not in_bounds(x, y):
		return
	biomes[index(x, y)] = biome


func get_feature(x: int, y: int) -> int:
	return features[index(x, y)]


func set_feature(x: int, y: int, val: int) -> void:
	features[index(x, y)] = val


func get_elevation(x: int, y: int) -> float:
	return elevation[index(x, y)]


func get_moisture(x: int, y: int) -> float:
	return moisture[index(x, y)]


## Walkability for pathing: passable biomes, no solid built walls. Doors and
## beds (and all other current features) count as walk-through for v1
## (doors stay passable; beds are not terrain blocks).
static func is_tile_walkable(data: WorldData, x: int, y: int) -> bool:
	if not data.in_bounds(x, y):
		return false
	var i: int = data.index(x, y)
	if int(data.features[i]) == TileFeature.Type.FORD:
		return true  # Ford makes any tile crossable
	if not Biome.is_passable(data.biomes[i]):
		return false
	if int(data.features[i]) == TileFeature.Type.WALL:
		return false
	return true


## For `GameSave` / `store_var`. Packed arrays round-trip in the snapshot dict.
func to_save_dict() -> Dictionary:
	return {
		"world_seed": world_seed,
		"biomes": biomes,
		"features": features,
		"elevation": elevation,
		"moisture": moisture,
	}


## Rebuilds map data on load. Returns `null` if arrays are wrong size or type.
static func from_save_dict(d: Dictionary) -> Variant:
	if d.is_empty():
		return null
	var w := WorldData.new()
	w.world_seed = int(d.get("world_seed", 0))
	if not _fill_byte_array(w.biomes, d.get("biomes", null)):
		return null
	if not _fill_byte_array(w.features, d.get("features", null)):
		return null
	if not _fill_float32_array(w.elevation, d.get("elevation", null)):
		return null
	if not _fill_float32_array(w.moisture, d.get("moisture", null)):
		return null
	return w


static func _fill_byte_array(into: PackedByteArray, v: Variant) -> bool:
	if v is PackedByteArray:
		if v.size() != TILE_COUNT:
			return false
		for i in range(TILE_COUNT):
			into[i] = v[i]
		return true
	if v is Array:
		if v.size() != TILE_COUNT:
			return false
		for i in range(TILE_COUNT):
			into[i] = int(v[i]) & 0xFF
		return true
	return false


static func _fill_float32_array(into: PackedFloat32Array, v: Variant) -> bool:
	if v is PackedFloat32Array:
		if v.size() != TILE_COUNT:
			return false
		for i in range(TILE_COUNT):
			into[i] = v[i]
		return true
	if v is Array:
		if v.size() != TILE_COUNT:
			return false
		for i in range(TILE_COUNT):
			into[i] = float(v[i])
		return true
	return false


func forage_at(x: int, y: int) -> int:
	# Dynamic neural network matrix connection to HeelKawn Universe
	if not in_bounds(x, y):
		return 0
	
	var idx: int = index(x, y)
	var biome: int = biomes[idx]
	var feature: int = features[idx]
	var moisture: float = moisture[idx]
	var elevation: float = elevation[idx]
	
	# Connect to neural network matrix for forage calculation
	var base_forage: int = 0
	var biome_multiplier: float = 1.0
	var moisture_multiplier: float = 1.0
	var elevation_multiplier: float = 1.0
	
	# Biome-based forage calculation
	match biome:
		Biome.Type.FOREST:
			base_forage = 8
			biome_multiplier = 1.2
		Biome.Type.PLAINS:
			base_forage = 6
			biome_multiplier = 1.0
		Biome.Type.DESERT:
			base_forage = 1
			biome_multiplier = 0.3
		Biome.Type.TUNDRA:
			base_forage = 2
			biome_multiplier = 0.4
		_:
			base_forage = 0
			biome_multiplier = 0.1
	
	# Feature-based modifications
	if feature == TileFeature.Type.FERTILE_SOIL:
		biome_multiplier *= 1.5
	
	# Environmental factors
	moisture_multiplier = 0.5 + (moisture * 0.5)
	elevation_multiplier = max(0.3, 1.0 - (elevation * 0.3))
	
	# Neural network matrix signature for forage tracking
	var forage_signature: String = "NM_FORAGE_%08X" % [x * 1000 + y + GameManager.tick_count]
	
	# Calculate final forage amount
	var final_forage: int = int(base_forage * biome_multiplier * moisture_multiplier * elevation_multiplier)
	
	# Store forage data in neural network matrix
	if WorldMemory != null:
		WorldMemory.store_forage_data(x, y, final_forage, forage_signature)
	
	return max(0, final_forage)


func consume_forage(x: int, y: int, amount: int = 1) -> void:
	# Dynamic neural network matrix connection to HeelKawn Universe
	if not in_bounds(x, y) or amount <= 0:
		return
	
	var idx: int = index(x, y)
	var current_forage: int = forage_at(x, y)
	
	if current_forage <= 0:
		return
	
	# Calculate consumption impact
	var consumption_ratio: float = float(amount) / float(current_forage)
	var biome: int = biomes[idx]
	
	# Connect to neural network matrix for ecological impact
	var ecological_impact: float = consumption_ratio * 0.1  # 10% of consumption ratio affects ecosystem
	var regeneration_delay: int = int(100 * consumption_ratio)  # Ticks to regenerate
	
	# Update forage availability in neural network matrix
	if WorldMemory != null:
		WorldMemory.consume_forage(x, y, amount, ecological_impact, regeneration_delay)
	
	# Trigger ecosystem response
	if ecological_impact > 0.05:  # Significant ecological impact
		_trigger_ecosystem_response(x, y, ecological_impact)


func _trigger_ecosystem_response(x: int, y: int, impact: float) -> void:
	# Dynamic neural network matrix ecosystem response
	var response_type: String = ""
	var response_magnitude: float = impact
	
	if impact > 0.2:
		response_type = "ecological_stress"
	elif impact > 0.1:
		response_type = "forage_depletion"
	else:
		response_type = "minor_consumption"
	
	# Connect to neural network matrix for ecosystem tracking
	if WorldMemory != null:
		var ecosystem_data: Dictionary = {
			"location": Vector2i(x, y),
			"impact": impact,
			"type": response_type,
			"tick": GameManager.tick_count,
			"neural_signature": "NM_ECOSYSTEM_%08X" % [x * 1000 + y + GameManager.tick_count]
		}
		WorldMemory.record_ecosystem_event(ecosystem_data)
	
	# Affect nearby wildlife behavior (neural network matrix tracking only)
	# AnimalPopulation.adjust_foraging_pressure(x, y, impact) - method not yet implemented
