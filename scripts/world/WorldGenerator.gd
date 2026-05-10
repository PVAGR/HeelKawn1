class_name WorldGenerator
extends RefCounted

## Seeded procedural world generator.
## Step 1: two Perlin fields (elevation + moisture).
## Step 2: percentile-based biome classification (stable distribution regardless
##         of how tightly FastNoiseLite's fractal layers compress the output).
## Step 3: scatter TileFeatures (ore veins, fertile soil, ruins) on valid biomes.

const ELEVATION_FREQUENCY: float = 0.012
const ELEVATION_OCTAVES: int = 4

const MOISTURE_FREQUENCY: float = 0.010
const MOISTURE_OCTAVES: int = 3

## Percentile splits for elevation (ascending percentiles).
## water | tundra | (plains/desert/forest middle band) | mountain
const P_ELEV_WATER:    float = 0.10   # bottom 10%  -> water       (~10% of map)
const P_ELEV_TUNDRA:   float = 0.22   # 10..22%    -> tundra      (~12% of map)
const P_ELEV_MOUNTAIN: float = 0.88   # top 12%    -> mountain    (~12% of map)
                                      # middle 66% -> moisture-based biomes

## Percentile splits for moisture within the middle elevation band.
## Because elevation and moisture are independent noise fields, global moisture
## percentiles map cleanly onto the middle-elevation subset.
const P_MOIST_DESERT: float = 0.25    # bottom 25% moisture -> desert
const P_MOIST_PLAINS: float = 0.75    # 25..75% moisture   -> plains
                                      # top 25% moisture   -> forest
##
## Expected final distribution:
##   water ~10%, tundra ~12%, mountain ~12%,
##   desert ~16%, plains ~33%, forest ~16%.

## Feature scatter tuning.
## Mountain ore: bigger clusters than v1 because most of these are sealed and
## need MINE_WALL to reach -- you want plenty of payoff once a tunnel breaks
## through. Bumped ~2x from the original.
const ORE_CLUSTERS: int = 20
const ORE_CLUSTER_SIZE_MIN: int = 5
const ORE_CLUSTER_SIZE_MAX: int = 14

## Surface ore: small loose deposits scattered onto plains/desert. These give
## the colony a steady stone supply even before they tunnel. Used to be missing
## entirely, which is why pawns leveled Mining 0 -- there was nothing to mine.
const SURFACE_ORE_CLUSTERS: int = 14
const SURFACE_ORE_CLUSTER_SIZE_MIN: int = 1
const SURFACE_ORE_CLUSTER_SIZE_MAX: int = 4

const FERTILE_CLUSTERS: int = 18
const FERTILE_CLUSTER_SIZE_MIN: int = 4
const FERTILE_CLUSTER_SIZE_MAX: int = 12

const RUIN_COUNT: int = 6

## Per-tile chance to receive a TREE feature, by biome. Trees only land on
## tiles that don't already have a feature, so existing FERTILE_SOIL clusters
## are preserved. Net result: dense (but not solid) forests + scattered
## woodlots in plains.
const TREE_CHANCE_FOREST: float = 0.35
const TREE_CHANCE_PLAINS: float = 0.04

## Wildlife counts. Rabbits are common chip-shots (1 meat each); deer are
## scarcer big-game targets (2 meat each, slower hunt). Both only spawn on
## empty tiles so they never overwrite ore / fertile / trees / ruins.
const RABBIT_COUNT: int = 28
const DEER_COUNT:   int = 10


static func generate(world_seed: int) -> WorldData:
	var data := WorldData.new()
	data.world_seed = world_seed

	var elev_noise := FastNoiseLite.new()
	elev_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	elev_noise.seed = world_seed
	elev_noise.frequency = ELEVATION_FREQUENCY
	elev_noise.fractal_octaves = ELEVATION_OCTAVES

	var moist_noise := FastNoiseLite.new()
	moist_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	moist_noise.seed = world_seed ^ 0x5A5A5A5A
	moist_noise.frequency = MOISTURE_FREQUENCY
	moist_noise.fractal_octaves = MOISTURE_OCTAVES

	# Pass 1: sample both noise fields into the data arrays.
	for y in range(WorldData.HEIGHT):
		for x in range(WorldData.WIDTH):
			var i: int = data.index(x, y)
			data.elevation[i] = (elev_noise.get_noise_2d(x, y) + 1.0) * 0.5
			data.moisture[i] = (moist_noise.get_noise_2d(x, y) + 1.0) * 0.5

	# Pass 2: derive percentile thresholds from the actual sampled distribution.
	var elev_sorted: PackedFloat32Array = data.elevation.duplicate()
	elev_sorted.sort()
	var moist_sorted: PackedFloat32Array = data.moisture.duplicate()
	moist_sorted.sort()

	var water_t: float = _percentile(elev_sorted, P_ELEV_WATER)
	var tundra_t: float = _percentile(elev_sorted, P_ELEV_TUNDRA)
	var mountain_t: float = _percentile(elev_sorted, P_ELEV_MOUNTAIN)
	var desert_t: float = _percentile(moist_sorted, P_MOIST_DESERT)
	var plains_t: float = _percentile(moist_sorted, P_MOIST_PLAINS)

	# Pass 3: classify using the derived thresholds.
	for i in range(WorldData.TILE_COUNT):
		data.biomes[i] = _classify(
			data.elevation[i], data.moisture[i],
			water_t, tundra_t, mountain_t, desert_t, plains_t
		)

	_scatter_features(data, world_seed)
	_scatter_rivers(data, world_seed)
	return data


static func _percentile(sorted_values: PackedFloat32Array, p: float) -> float:
	var n: int = sorted_values.size()
	if n == 0:
		return 0.0
	var idx: int = clamp(int(p * n), 0, n - 1)
	return sorted_values[idx]


static func _classify(
	e: float, m: float,
	water_t: float, tundra_t: float, mountain_t: float,
	desert_t: float, plains_t: float
) -> int:
	if e < water_t:
		return Biome.Type.WATER
	if e > mountain_t:
		return Biome.Type.MOUNTAIN
	if e < tundra_t:
		return Biome.Type.TUNDRA
	if m < desert_t:
		return Biome.Type.DESERT
	if m < plains_t:
		return Biome.Type.PLAINS
	return Biome.Type.FOREST


static func _scatter_features(data: WorldData, world_seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed ^ 0xABCD1234

	_scatter_cluster(
		data, rng, ORE_CLUSTERS,
		ORE_CLUSTER_SIZE_MIN, ORE_CLUSTER_SIZE_MAX,
		[Biome.Type.MOUNTAIN],
		TileFeature.Type.ORE_VEIN
	)
	# Surface ore on passable land -- pawns can mine these directly without
	# tunneling, so they always have *some* mining work available.
	_scatter_cluster(
		data, rng, SURFACE_ORE_CLUSTERS,
		SURFACE_ORE_CLUSTER_SIZE_MIN, SURFACE_ORE_CLUSTER_SIZE_MAX,
		[Biome.Type.PLAINS, Biome.Type.DESERT, Biome.Type.TUNDRA],
		TileFeature.Type.ORE_VEIN
	)
	_scatter_cluster(
		data, rng, FERTILE_CLUSTERS,
		FERTILE_CLUSTER_SIZE_MIN, FERTILE_CLUSTER_SIZE_MAX,
		[Biome.Type.PLAINS, Biome.Type.FOREST],
		TileFeature.Type.FERTILE_SOIL
	)
	_scatter_single(
		data, rng, RUIN_COUNT,
		[Biome.Type.PLAINS, Biome.Type.FOREST, Biome.Type.DESERT, Biome.Type.TUNDRA],
		TileFeature.Type.RUIN
	)
	_scatter_trees(data, rng)
	# Wildlife last so we can cleanly skip any tile that already has a feature.
	_scatter_wildlife(data, rng)


## Place RABBIT_COUNT rabbits + DEER_COUNT deer on random empty tiles in
## plains/forest. We sample candidate tiles instead of trying to find an
## empty one in a tight loop -- the world is mostly empty so this converges
## fast and never overwrites existing features. Deer prefer forest, rabbits
## prefer plains, but both can appear in either.
static func _scatter_wildlife(data: WorldData, rng: RandomNumberGenerator) -> void:
	_scatter_animal(
		data, rng, RABBIT_COUNT,
		[Biome.Type.PLAINS, Biome.Type.FOREST],
		TileFeature.Type.RABBIT
	)
	_scatter_animal(
		data, rng, DEER_COUNT,
		[Biome.Type.FOREST, Biome.Type.PLAINS],
		TileFeature.Type.DEER
	)


## Place `count` of `feature` on random tiles whose biome is in `allowed_biomes`
## AND whose feature slot is currently NONE. Up to 80 attempts per animal --
## if we can't find an empty matching tile that fast the map is full enough
## that one fewer rabbit doesn't matter.
static func _scatter_animal(
	data: WorldData,
	rng: RandomNumberGenerator,
	count: int,
	allowed_biomes: Array,
	feature: int
) -> void:
	for _i in range(count):
		var placed: bool = false
		for _try in range(80):
			var tx: int = rng.randi_range(0, WorldData.WIDTH - 1)
			var ty: int = rng.randi_range(0, WorldData.HEIGHT - 1)
			var idx: int = data.index(tx, ty)
			if data.features[idx] != TileFeature.Type.NONE:
				continue
			if not (data.biomes[idx] in allowed_biomes):
				continue
			data.features[idx] = feature
			placed = true
			break
		if not placed:
			break  # map is saturated; stop trying so we don't burn cycles


## Probabilistic per-tile tree placement. Runs AFTER cluster scatter so it
## doesn't overwrite fertile soil / ore / ruins. Stays out of impassable
## biomes (you can't grow a tree on a lake or a mountain).
static func _scatter_trees(data: WorldData, rng: RandomNumberGenerator) -> void:
	for y in range(WorldData.HEIGHT):
		for x in range(WorldData.WIDTH):
			var i: int = data.index(x, y)
			if data.features[i] != TileFeature.Type.NONE:
				continue
			var biome: int = data.biomes[i]
			var chance: float = 0.0
			if biome == Biome.Type.FOREST:
				chance = TREE_CHANCE_FOREST
			elif biome == Biome.Type.PLAINS:
				chance = TREE_CHANCE_PLAINS
			else:
				continue
			if rng.randf() < chance:
				data.features[i] = TileFeature.Type.TREE


## Drop `count` clusters of `feature` onto tiles whose biome is in `allowed_biomes`.
## Each cluster is a small random walk so it looks organic, not circular.
static func _scatter_cluster(
	data: WorldData,
	rng: RandomNumberGenerator,
	count: int,
	size_min: int,
	size_max: int,
	allowed_biomes: Array,
	feature: int
) -> void:
	for _i in range(count):
		var seed_pos := _find_random_tile_of_biomes(data, rng, allowed_biomes)
		if seed_pos.x < 0:
			continue
		var size: int = rng.randi_range(size_min, size_max)
		var cx: int = seed_pos.x
		var cy: int = seed_pos.y
		for _j in range(size):
			if data.in_bounds(cx, cy) and data.biomes[data.index(cx, cy)] in allowed_biomes:
				data.features[data.index(cx, cy)] = feature
			cx += rng.randi_range(-1, 1)
			cy += rng.randi_range(-1, 1)


## Drop `count` single-tile features on tiles of the allowed biomes.
static func _scatter_single(
	data: WorldData,
	rng: RandomNumberGenerator,
	count: int,
	allowed_biomes: Array,
	feature: int
) -> void:
	for _i in range(count):
		var pos := _find_random_tile_of_biomes(data, rng, allowed_biomes)
		if pos.x < 0:
			continue
		data.features[data.index(pos.x, pos.y)] = feature


## River quality cache: maps river tile -> quality (0.3-1.0) for fishing yield.
## Populated during _scatter_rivers, read by fishing code for deep-pool bonuses.
static var _river_quality_cache: Dictionary = {}

## Get river quality for a tile, or 0.5 if not a river.
static func river_quality(tile: Vector2i) -> float:
	return float(_river_quality_cache.get(tile, 0.5))


## Generate rivers flowing from mountain/highland areas toward the coast (WATER tiles).
## Uses a simple flow model: start at mountain ridge, follow steepest descent.
static func _scatter_rivers(data: WorldData, world_seed: int) -> void:
	_river_quality_cache.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed ^ 0xFEEDBEEF
	var river_count: int = 4 + rng.randi() % 4  # 4-7 rivers

	for ri in range(river_count):
		# Find a starting point in mountains or high-elevation plains
		var start: Vector2i = _find_river_start(data, rng)
		if start.x < 0:
			continue
		var cx: int = start.x
		var cy: int = start.y
		var length: int = 0
		var max_length: int = 60 + rng.randi() % 40
		var avoid: Array = [start]
		
		while length < max_length:
			var idx: int = data.index(cx, cy)
			# Don't carve through buildings
			if data.features[idx] != TileFeature.Type.NONE and data.features[idx] < TileFeature.Type.RIVER:
				break
			# Mark as river.
			data.features[idx] = TileFeature.Type.RIVER
			# Store river quality (deep pool vs shallow) in a deterministic way.
			var quality: float = 0.3 + float((cx * 73856093 + cy * 19349663 + ri * 83492791) % 1000) / 1000.0 * 0.7
			_river_quality_cache[Vector2i(cx, cy)] = quality
			# Find lowest neighbor (flow downhill).
			var best: Vector2i = Vector2i(-1, -1)
			var best_elev: float = 1.0
			for dx in [-1, 0, 1]:
				for dy in [-1, 0, 1]:
					if dx == 0 and dy == 0:
						continue
					var nx: int = cx + dx
					var ny: int = cy + dy
					if not data.in_bounds(nx, ny):
						continue
					if Vector2i(nx, ny) in avoid:
						continue
					var nidx: int = data.index(nx, ny)
					var elev: float = data.elevation[nidx]
					if elev < best_elev:
						best_elev = elev
						best = Vector2i(nx, ny)
			if best.x < 0 or best_elev >= 0.15:  # Flowing into water or reached coast
				# At coast, set the last tile as river mouth
				for dx in [-1, 0, 1]:
					for dy in [-1, 0, 1]:
						var nx: int = cx + dx
						var ny: int = cy + dy
						if not data.in_bounds(nx, ny):
							continue
						if data.biomes[data.index(nx, ny)] == Biome.Type.WATER:
							data.features[data.index(nx, ny)] = TileFeature.Type.RIVER
							length = max_length  # End
							best = Vector2i(-1, -1)
							break
				if best.x < 0:
					break
			# Add some randomness - occasionally don't follow strict gradient
			if rng.randf() < 0.15:
				best = Vector2i(cx + rng.randi_range(-1, 1), cy + rng.randi_range(-1, 1))
				if not data.in_bounds(best.x, best.y):
					best = Vector2i(cx, cy + 1)
			avoid.append(best)
			cx = best.x
			cy = best.y
			length += 1


## Find a good starting tile for a river (mountain edge or high elevation)
static func _find_river_start(data: WorldData, rng: RandomNumberGenerator) -> Vector2i:
	for _try in range(120):
		var tx: int = rng.randi_range(5, WorldData.WIDTH - 6)
		var ty: int = rng.randi_range(5, WorldData.HEIGHT - 6)
		var idx: int = data.index(tx, ty)
		if data.biomes[idx] == Biome.Type.MOUNTAIN or data.elevation[idx] > 0.75:
			# Check that there's a lower-elevation neighbor (water or plains)
			for dx in [-1, 0, 1]:
				for dy in [-1, 0, 1]:
					if dx == 0 and dy == 0:
						continue
					var nx: int = tx + dx
					var ny: int = ty + dy
					if not data.in_bounds(nx, ny):
						continue
					if data.elevation[data.index(nx, ny)] < data.elevation[idx] * 0.8:
						return Vector2i(tx, ty)
	return Vector2i(-1, -1)


static func _find_random_tile_of_biomes(
	data: WorldData,
	rng: RandomNumberGenerator,
	allowed_biomes: Array
) -> Vector2i:
	for _try in range(80):
		var tx: int = rng.randi_range(0, WorldData.WIDTH - 1)
		var ty: int = rng.randi_range(0, WorldData.HEIGHT - 1)
		if data.biomes[data.index(tx, ty)] in allowed_biomes:
			return Vector2i(tx, ty)
	return Vector2i(-1, -1)
