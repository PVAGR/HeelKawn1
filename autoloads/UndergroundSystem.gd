extends Node
## UndergroundSystem — Cave layers, mines, and underground rivers.
## The world has 3 underground layers:
##   - Layer 1 (shallow): small caves, clay, gravel. Accessible by stairs.
##   - Layer 2 (deep): ore veins, gems, larger caverns. Requires mining.
##   - Layer 3 (deepest): magma, ancient ruins, underground rivers. Extremely dangerous.
## Each layer is a separate 2D grid. Pawns can descend via stairs or cave entrances.
## All deterministic: cave generation uses WorldRNG with world seed.

enum Layer {
	SHALLOW,  # 0-50m: small caves, clay
	DEEP,     # 50-200m: ore, gems, caverns
	DEEPER,   # 200-500m: magma, ruins, underground rivers
}

const LAYER_NAMES: Dictionary = {
	Layer.SHALLOW: "Shallow",
	Layer.DEEP: "Deep",
	Layer.DEEPER: "Deeper",
}

# Tile types for underground layers
enum UGTile {
	EMPTY,      # excavated/empty space
	DIRT,       # soft earth, easy to dig
	STONE,      # hard rock, slow to dig
	CLAY,       # clay deposit
	GRAVEL,     # gravel/sand
	COAL,       # coal seam
	IRON_ORE,   # iron ore
	GOLD_ORE,   # gold ore
	GEM,        # precious gems
	MAGMA,      # molten rock
	UNDERGROUND_RIVER, # subterranean water
	ANCIENT_RUIN, # ancient structure
}

var layers: Dictionary = {}  # layer_int -> data
var stair_tiles: Dictionary = {}  # tile_key -> connected_layer
var cave_entrances: Array = []

func _ready() -> void:
	if GameManager != null:
		GameManager.game_tick.connect(_on_game_tick)
	_generate_caves()

func _generate_caves() -> void:
	if WorldRNG == null:
		return
	for layer_int in range(3):
		var data: Array = []
		for x in range(WorldData.WIDTH):
			data.append([])
			for y in range(WorldData.HEIGHT):
				data[x].append(UGTile.STONE)
		layers[layer_int] = data
	_generate_cave_tunnels(Layer.SHALLOW, 30)
	_generate_cave_tunnels(Layer.DEEP, 20)
	_generate_cave_tunnels(Layer.DEEPER, 10)
	_place_stairs()
	_record_entrances()

func _generate_cave_tunnels(layer_int: int, iterations: int) -> void:
	var data: Array = layers.get(layer_int, [])
	if data.is_empty():
		return
	for i in range(iterations):
		var cx: int = WorldRNG.rangei(&"cave_x_%d" % layer_int, 3, WorldData.WIDTH - 3, i * 2)
		var cy: int = WorldRNG.rangei(&"cave_y_%d" % layer_int, 3, WorldData.HEIGHT - 3, i * 2 + 1)
		var radius: int = WorldRNG.rangei(&"cave_r_%d" % layer_int, 2, 6, i)
		for dx in range(-radius, radius + 1):
			for dy in range(-radius, radius + 1):
				var tx: int = cx + dx
				var ty: int = cy + dy
				if tx >= 0 and tx < WorldData.WIDTH and ty >= 0 and ty < WorldData.HEIGHT:
					if dx * dx + dy * dy <= radius * radius:
						if layer_int == Layer.DEEPER and WorldRNG.chance_for(&"cave_special", 0.3, tx * WorldData.HEIGHT + ty):
							if WorldRNG.chance_for(&"cave_magma", 0.5, tx + ty):
								data[tx][ty] = UGTile.MAGMA
							elif WorldRNG.chance_for(&"cave_river", 0.5, tx * ty):
								data[tx][ty] = UGTile.UNDERGROUND_RIVER
							else:
								data[tx][ty] = UGTile.ANCIENT_RUIN
						else:
							data[tx][ty] = UGTile.EMPTY
		_place_deposits(data, layer_int, i)

func _place_deposits(data: Array, layer_int: int, seed_offset: int) -> void:
	var deposit_count: int = WorldRNG.rangei(&"deposit_count_%d" % layer_int, 3, 8, seed_offset)
	for d in range(deposit_count):
		var dx: int = WorldRNG.rangei(&"dep_x_%d_%d" % [layer_int, d], 1, WorldData.WIDTH - 1, seed_offset)
		var dy: int = WorldRNG.rangei(&"dep_y_%d_%d" % [layer_int, d], 1, WorldData.HEIGHT - 1, seed_offset + 1)
		if data[dx][dy] == UGTile.EMPTY:
			var deposit_type: int
			match layer_int:
				Layer.SHALLOW:
					deposit_type = WorldRNG.rangei(&"dep_type_shallow", 1, 3, d)
					if deposit_type == 1: data[dx][dy] = UGTile.CLAY
					elif deposit_type == 2: data[dx][dy] = UGTile.GRAVEL
					else: data[dx][dy] = UGTile.COAL
				Layer.DEEP:
					deposit_type = WorldRNG.rangei(&"dep_type_deep", 1, 4, d)
					if deposit_type == 1: data[dx][dy] = UGTile.IRON_ORE
					elif deposit_type == 2: data[dx][dy] = UGTile.COAL
					elif deposit_type == 3: data[dx][dy] = UGTile.GOLD_ORE
					else: data[dx][dy] = UGTile.GEM
				Layer.DEEPER:
					deposit_type = WorldRNG.rangei(&"dep_type_deeper", 1, 3, d)
					if deposit_type == 1: data[dx][dy] = UGTile.GOLD_ORE
					elif deposit_type == 2: data[dx][dy] = UGTile.GEM
					else: data[dx][dy] = UGTile.MAGMA

func _place_stairs() -> void:
	if WorldRNG == null:
		return
	for i in range(5):
		var sx: int = WorldRNG.rangei(&"stair_x", 5, WorldData.WIDTH - 5, i)
		var sy: int = WorldRNG.rangei(&"stair_y", 5, WorldData.HEIGHT - 5, i + 1)
		stair_tiles["%d,%d" % [sx, sy]] = Layer.SHALLOW

func _record_entrances() -> void:
	cave_entrances = []
	for key in stair_tiles:
		var parts: Array = key.split(",")
		cave_entrances.append(Vector2i(int(parts[0]), int(parts[1])))

func get_tile(layer_int: int, x: int, y: int) -> int:
	var data: Array = layers.get(layer_int, [])
	if data.is_empty():
		return UGTile.EMPTY
	if x < 0 or x >= data.size() or y < 0 or y >= data[0].size():
		return UGTile.STONE
	return data[x][y]

func dig_tile(layer_int: int, x: int, y: int) -> bool:
	var data: Array = layers.get(layer_int, [])
	if data.is_empty():
		return false
	if x < 0 or x >= data.size() or y < 0 or y >= data[0].size():
		return false
	var tile: int = data[x][y]
	if tile == UGTile.MAGMA or tile == UGTile.UNDERGROUND_RIVER:
		return false
	data[x][y] = UGTile.EMPTY
	return true

func get_entrances() -> Array:
	return cave_entrances

func is_stair_at(tile: Vector2i) -> bool:
	return stair_tiles.has("%d,%d" % [tile.x, tile.y])

func get_stair_layer(tile: Vector2i) -> int:
	return stair_tiles.get("%d,%d" % [tile.x, tile.y], -1)

func _on_game_tick(tick: int) -> void:
	_ = tick
