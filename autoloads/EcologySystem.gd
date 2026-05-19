extends Node
## EcologySystem â€” unified environmental simulation for HeelKawn.
##
## Manages: seasons, weather, plant growth, resource regrowth, fire spread,
## water flow, erosion, pollution, and animal migration. All subsystems
## are deterministic (seeded RNG, tick-based) and interdependent.
##
## Design principles:
## - Ecological regrowth, not timer-based respawn
## - Seasons affect everything: temperature, agriculture, wildlife, weather
## - Player actions have lasting environmental impact
## - Systems interact: rain â†’ soil moisture â†’ plant growth â†’ animal attraction
##
## Vintage Story influence: time-intensive, seasonal, realistic progression.

# ============================================================
# CONSTANTS
# ============================================================

## Ticks per sim year (matches SimTime)
const TICKS_PER_YEAR: int = 48000

## Ticks per season
const TICKS_PER_SEASON: int = TICKS_PER_YEAR / 4

## Soil quality range (0.0 = dead, 1.0 = pristine)
const SOIL_MIN: float = 0.0
const SOIL_MAX: float = 1.0

## Moisture range (0.0 = arid, 1.0 = saturated)
const MOISTURE_MIN: float = 0.0
const MOISTURE_MAX: float = 1.0

## Vegetation density range (0.0 = barren, 1.0 = dense forest)
const VEGETATION_MIN: float = 0.0
const VEGETATION_MAX: float = 1.0

## Pollution range (0.0 = clean, 1.0 = heavily polluted)
const POLLUTION_MIN: float = 0.0
const POLLUTION_MAX: float = 1.0

## How often to run full ecology update (ticks)
const ECOLOGY_UPDATE_INTERVAL: int = 120

## How often to run plant growth (ticks)
const PLANT_GROWTH_INTERVAL: int = 240

## How often to run fire spread (ticks)
const FIRE_SPREAD_INTERVAL: int = 30

## How often to run erosion (ticks)
const EROSION_INTERVAL: int = 2000

## How often to run pollution diffusion (ticks)
const POLLUTION_INTERVAL: int = 500

## How often to run animal migration (ticks)
const MIGRATION_INTERVAL: int = 3000

## Max fire sources tracked simultaneously
const MAX_FIRE_SOURCES: int = 64

## Fire spread probability base (per adjacent tile, per interval)
const FIRE_SPREAD_BASE_CHANCE: float = 0.15

## Fire spread chance multiplier for dry vegetation
const FIRE_DRY_MULTIPLIER: float = 2.5

## Fire spread chance multiplier for wind
const FIRE_WIND_MULTIPLIER: float = 1.8

## Soil recovery rate per ecology update (pristine conditions)
const SOIL_RECOVERY_RATE: float = 0.002

## Soil degradation from over-harvesting
const SOIL_DEGRADATION_HARVEST: float = 0.05

## Soil degradation from deforestation
const SOIL_DEGRADATION_DEFOREST: float = 0.08

## Soil degradation from pollution
const SOIL_DEGRADATION_POLLUTION: float = 0.01

## Moisture gain from rain per weather update
const MOISTURE_RAIN_GAIN: float = 0.15

## Moisture loss from evaporation per ecology update
const MOISTURE_EVAPORATION_RATE: float = 0.005

## Moisture loss from desert biome
const MOISTURE_DESERT_LOSS: float = 0.02

## Vegetation growth rate per plant update (optimal conditions)
const VEGETATION_GROWTH_RATE: float = 0.008

## Tree regrowth minimum vegetation density required
const TREE_REGROWTH_MIN_VEG: float = 0.3

## Pollution diffusion rate per pollution update
const POLLUTION_DIFFUSION_RATE: float = 0.05

## Pollution decay rate (natural cleanup)
const POLLUTION_DECAY_RATE: float = 0.003

## Pollution from fire pits per source
const POLLUTION_FIRE_PIT: float = 0.01

## Pollution from settlement (per pawn in region)
const POLLUTION_PER_PAWN: float = 0.001

# ============================================================
# PER-TILE ECOLOGY STATE
# ============================================================

## Compact ecology state per tile. Stored as parallel arrays for cache efficiency.
var _soil_quality: PackedFloat32Array = PackedFloat32Array()
var _moisture: PackedFloat32Array = PackedFloat32Array()
var _vegetation: PackedFloat32Array = PackedFloat32Array()
var _pollution: PackedFloat32Array = PackedFloat32Array()
var _temperature: PackedFloat32Array = PackedFloat32Array()
var _initialized: bool = false

# ============================================================
# FIRE TRACKING
# ============================================================

## Active fire sources: Array of {"pos": Vector2i, "intensity": float, "tick_started": int}
var _active_fires: Array[Dictionary] = []
var _fire_spread_rng: RandomNumberGenerator = RandomNumberGenerator.new()

# ============================================================
# SEASONAL STATE
# ============================================================

## Current season temperature offset per biome type
var _biome_temp_offset: Dictionary = {}

## Agricultural window: true when conditions allow planting/growth
var _agriculture_active: bool = true

## Seasonal severity (0.0 = mild, 1.0 = harsh winter / extreme summer)
var _season_severity: float = 0.0

# ============================================================
# ECOLOGY EVENTS (for Chronicle/WorldMemory)
# ============================================================

## Pending ecology events to report
var _pending_events: Array[Dictionary] = []

## Last tick a wildfire was logged (prevents spam)
var _last_wildfire_log_tick: int = 0

## Last tick a drought was logged
var _last_drought_log_tick: int = 0

## Last tick a flood was logged
var _last_flood_log_tick: int = 0

# ============================================================
# INITIALIZATION
# ============================================================

func _ready() -> void:
	if GameManager != null:
		GameManager.game_tick.connect(_on_game_tick)
	_initialize_fire_rng()


func _initialize_fire_rng() -> void:
	var seed_val: int = 42
	if WorldRNG != null and WorldRNG.has_method("get_seed"):
		seed_val = WorldRNG.get_seed()
	_fire_spread_rng.seed = seed_val


func initialize_for_world(world: Node) -> void:
	"""Initialize ecology arrays for the given world's dimensions."""
	if world == null or world.data == null:
		return
	var tile_count: int = WorldData.WIDTH * WorldData.HEIGHT
	if _soil_quality.size() == tile_count:
		return  # Already initialized
	_soil_quality.resize(tile_count)
	_moisture.resize(tile_count)
	_vegetation.resize(tile_count)
	_pollution.resize(tile_count)
	_temperature.resize(tile_count)
	# Initialize from world data
	for i in range(tile_count):
		var x: int = i % WorldData.WIDTH
		var y: int = i / WorldData.WIDTH
		var biome: int = world.data.get_biome(x, y)
		_soil_quality[i] = _default_soil_for_biome(biome)
		_moisture[i] = _default_moisture_for_biome(biome)
		_vegetation[i] = _default_vegetation_for_biome(biome)
		_pollution[i] = 0.0
		_temperature[i] = _base_temperature_for_biome(biome)
	_initialized = true


func _default_soil_for_biome(biome: int) -> float:
	match biome:
		Biome.Type.FERTILE_SOIL: return 0.9
		Biome.Type.PLAINS: return 0.7
		Biome.Type.FOREST: return 0.75
		Biome.Type.DESERT: return 0.2
		Biome.Type.TUNDRA: return 0.4
		Biome.Type.GRASS: return 0.65
		_: return 0.5


func _default_moisture_for_biome(biome: int) -> float:
	match biome:
		Biome.Type.FERTILE_SOIL: return 0.7
		Biome.Type.PLAINS: return 0.5
		Biome.Type.FOREST: return 0.6
		Biome.Type.DESERT: return 0.1
		Biome.Type.TUNDRA: return 0.5
		Biome.Type.WATER, Biome.Type.OCEAN: return 1.0
		Biome.Type.GRASS: return 0.45
		_: return 0.4


func _default_vegetation_for_biome(biome: int) -> float:
	match biome:
		Biome.Type.FOREST: return 0.85
		Biome.Type.PLAINS: return 0.4
		Biome.Type.DESERT: return 0.05
		Biome.Type.TUNDRA: return 0.15
		Biome.Type.GRASS: return 0.5
		Biome.Type.FERTILE_SOIL: return 0.3
		_: return 0.0


func _base_temperature_for_biome(biome: int) -> float:
	"""Base temperature in Celsius for biome at season neutral point."""
	match biome:
		Biome.Type.DESERT: return 30.0
		Biome.Type.PLAINS: return 18.0
		Biome.Type.FOREST: return 16.0
		Biome.Type.GRASS: return 17.0
		Biome.Type.FERTILE_SOIL: return 18.0
		Biome.Type.TUNDRA: return -5.0
		Biome.Type.MOUNTAIN: return 5.0
		Biome.Type.WATER: return 12.0
		Biome.Type.OCEAN: return 10.0
		_: return 15.0


# ============================================================
# TICK HANDLER
# ============================================================

func _on_game_tick(tick: int) -> void:
	if not _initialized:
		return
	# Update seasonal temperature
	if tick % 60 == 0:
		_update_seasonal_temperatures(tick)
	# Full ecology update (soil, moisture, vegetation interactions)
	if tick % ECOLOGY_UPDATE_INTERVAL == 0:
		_update_ecology(tick)
	# Plant growth
	if tick % PLANT_GROWTH_INTERVAL == 0:
		_update_plant_growth(tick)
	# Fire spread
	if tick % FIRE_SPREAD_INTERVAL == 0 and not _active_fires.is_empty():
		_update_fire_spread(tick)
	# Erosion
	if tick % EROSION_INTERVAL == 0:
		_update_erosion(tick)
	# Pollution diffusion
	if tick % POLLUTION_INTERVAL == 0:
		_update_pollution(tick)
	# Animal migration
	if tick % MIGRATION_INTERVAL == 0:
		_update_migration(tick)


# ============================================================
# SEASONAL TEMPERATURE
# ============================================================

func _update_seasonal_temperatures(tick: int) -> void:
	var season: int = Biome.season_for_tick(tick)
	var day_in_season: float = float((SimTime.tick_within_sim_year(tick) % (SimTime.TICKS_PER_SIM_YEAR / 4))) / float(TICKS_PER_SEASON)
	# Season severity peaks mid-season
	_season_severity = sin(day_in_season * PI)
	# Temperature offsets per season
	var temp_offsets: Dictionary = {
		Biome.Season.SPRING: {
			Biome.Type.DESERT: 5.0, Biome.Type.PLAINS: 3.0, Biome.Type.FOREST: 2.0,
			Biome.Type.TUNDRA: 8.0, Biome.Type.MOUNTAIN: 4.0, Biome.Type.GRASS: 3.0,
			Biome.Type.FERTILE_SOIL: 3.0,
		},
		Biome.Season.SUMMER: {
			Biome.Type.DESERT: 15.0, Biome.Type.PLAINS: 8.0, Biome.Type.FOREST: 6.0,
			Biome.Type.TUNDRA: 12.0, Biome.Type.MOUNTAIN: 8.0, Biome.Type.GRASS: 8.0,
			Biome.Type.FERTILE_SOIL: 8.0,
		},
		Biome.Season.AUTUMN: {
			Biome.Type.DESERT: 0.0, Biome.Type.PLAINS: -2.0, Biome.Type.FOREST: -3.0,
			Biome.Type.TUNDRA: -5.0, Biome.Type.MOUNTAIN: -4.0, Biome.Type.GRASS: -2.0,
			Biome.Type.FERTILE_SOIL: -2.0,
		},
		Biome.Season.WINTER: {
			Biome.Type.DESERT: -8.0, Biome.Type.PLAINS: -12.0, Biome.Type.FOREST: -10.0,
			Biome.Type.TUNDRA: -20.0, Biome.Type.MOUNTAIN: -15.0, Biome.Type.GRASS: -12.0,
			Biome.Type.FERTILE_SOIL: -12.0,
		},
	}
	var offsets: Dictionary = temp_offsets.get(season, {})
	_biome_temp_offset = offsets
	# Agricultural window: active in spring/summer, limited in autumn, closed in winter
	_agriculture_active = season != Biome.Season.WINTER


func get_temperature_at_tile(x: int, y: int) -> float:
	"""Get current temperature at tile (base + seasonal offset + weather)."""
	if not _initialized or x < 0 or y < 0 or x >= WorldData.WIDTH or y >= WorldData.HEIGHT:
		return 15.0
	var idx: int = y * WorldData.WIDTH + x
	var base: float = _temperature[idx]
	var biome: int = _get_biome_at(x, y)
	var offset: float = float(_biome_temp_offset.get(biome, 0.0))
	# Weather modifier
	var weather_mod: float = _get_weather_temp_modifier(x, y)
	return base + offset + weather_mod


func _get_weather_temp_modifier(x: int, y: int) -> float:
	var weather_overlay: Node = _get_weather_overlay()
	if weather_overlay == null:
		return 0.0
	var weather: String = weather_overlay.get_current_weather() if weather_overlay.has_method("get_current_weather") else "none"
	match weather:
		"snow": return -5.0
		"rain": return -2.0
		"sand": return 3.0
		"embers": return 5.0
		_: return 0.0


func get_season_severity() -> float:
	return _season_severity


func is_agriculture_active() -> bool:
	return _agriculture_active


func get_current_season() -> int:
	if GameManager == null:
		return Biome.Season.SPRING
	return Biome.season_for_tick(GameManager.tick_count)


# ============================================================
# ECOLOGY UPDATE (soil, moisture, vegetation interactions)
# ============================================================

func _update_ecology(tick: int) -> void:
	var tile_count: int = _soil_quality.size()
	var weather_overlay: Node = _get_weather_overlay()
	var is_raining: bool = weather_overlay != null and weather_overlay.has_method("is_precipitating") and weather_overlay.is_precipitating()
	for i in range(tile_count):
		var x: int = i % WorldData.WIDTH
		var y: int = i / WorldData.WIDTH
		var biome: int = _get_biome_at(x, y)
		# Moisture update
		if is_raining:
			_moisture[i] = minf(MOISTURE_MAX, _moisture[i] + MOISTURE_RAIN_GAIN)
		else:
			var evap: float = MOISTURE_EVAPORATION_RATE
			if biome == Biome.Type.DESERT:
				evap += MOISTURE_DESERT_LOSS
			_moisture[i] = maxf(MOISTURE_MIN, _moisture[i] - evap)
		# Soil recovery (slow, depends on moisture and vegetation)
		if _moisture[i] > 0.3 and _vegetation[i] > 0.1:
			var recovery: float = SOIL_RECOVERY_RATE * _moisture[i] * (1.0 - _pollution[i])
			_soil_quality[i] = minf(SOIL_MAX, _soil_quality[i] + recovery)
		# Soil degradation from pollution
		if _pollution[i] > 0.3:
			_soil_quality[i] = maxf(SOIL_MIN, _soil_quality[i] - SOIL_DEGRADATION_POLLUTION * _pollution[i])


func get_soil_quality_at(x: int, y: int) -> float:
	if not _initialized or x < 0 or y < 0:
		return 0.5
	var idx: int = _tile_index(x, y)
	if idx < 0:
		return 0.5
	return _soil_quality[idx]


func get_moisture_at(x: int, y: int) -> float:
	if not _initialized or x < 0 or y < 0:
		return 0.4
	var idx: int = _tile_index(x, y)
	if idx < 0:
		return 0.4
	return _moisture[idx]


func get_vegetation_at(x: int, y: int) -> float:
	if not _initialized or x < 0 or y < 0:
		return 0.0
	var idx: int = _tile_index(x, y)
	if idx < 0:
		return 0.0
	return _vegetation[idx]


func get_pollution_at(x: int, y: int) -> float:
	if not _initialized or x < 0 or y < 0:
		return 0.0
	var idx: int = _tile_index(x, y)
	if idx < 0:
		return 0.0
	return _pollution[idx]


# ============================================================
# PLANT GROWTH
# ============================================================

func _update_plant_growth(tick: int) -> void:
	var tile_count: int = _vegetation.size()
	var season: int = get_current_season()
	for i in range(tile_count):
		var x: int = i % WorldData.WIDTH
		var y: int = i / WorldData.WIDTH
		var biome: int = _get_biome_at(x, y)
		# Skip non-growable biomes
		if biome == Biome.Type.WATER or biome == Biome.Type.OCEAN or biome == Biome.Type.MOUNTAIN:
			continue
		# Growth rate depends on: soil quality, moisture, season, pollution
		var growth_factor: float = _soil_quality[i] * 0.4 + _moisture[i] * 0.4 + (1.0 - _pollution[i]) * 0.2
		# Seasonal modifier
		var season_mod: float = _season_growth_modifier(season, biome)
		growth_factor *= season_mod
		# Apply growth
		var growth: float = VEGETATION_GROWTH_RATE * growth_factor
		_vegetation[i] = minf(VEGETATION_MAX, _vegetation[i] + growth)
		# Natural vegetation decay in harsh conditions
		if _moisture[i] < 0.1 or _soil_quality[i] < 0.1:
			_vegetation[i] = maxf(VEGETATION_MIN, _vegetation[i] - 0.005)


func _season_growth_modifier(season: int, biome: int) -> float:
	match season:
		Biome.Season.SPRING:
			return 1.2  # Growth surge
		Biome.Season.SUMMER:
			return 1.0 if biome != Biome.Type.DESERT else 0.5  # Desert summer is harsh
		Biome.Season.AUTUMN:
			return 0.6  # Slowing down
		Biome.Season.WINTER:
			return 0.0 if biome != Biome.Type.TUNDRA else 0.1  # Winter dormancy
	return 1.0


func get_crop_growth_multiplier_at(x: int, y: int) -> float:
	"""Get crop growth multiplier for tile (for farming system integration)."""
	if not _initialized:
		return 1.0
	var idx: int = _tile_index(x, y)
	if idx < 0:
		return 1.0
	var soil_factor: float = _soil_quality[idx]
	var moisture_factor: float = _moisture[idx]
	var season: int = get_current_season()
	var season_mod: float = _season_growth_modifier(season, _get_biome_at(x, y))
	var weather_overlay: Node = _get_weather_overlay()
	var weather_mod: float = 1.0
	if weather_overlay != null and weather_overlay.has_method("crop_growth_multiplier"):
		weather_mod = weather_overlay.crop_growth_multiplier()
	return soil_factor * 0.5 + moisture_factor * 0.3 + season_mod * 0.2 * weather_mod


# ============================================================
# FIRE SPREAD
# ============================================================

func _update_fire_spread(tick: int) -> void:
	if _active_fires.is_empty():
		return
	var weather_overlay: Node = _get_weather_overlay()
	var fire_suppression: float = 1.0
	if weather_overlay != null and weather_overlay.has_method("fire_spread_multiplier"):
		fire_suppression = weather_overlay.fire_spread_multiplier()
	var wind_factor: float = _get_wind_factor()
	var new_fires: Array[Dictionary] = []
	var fires_to_remove: Array[int] = []
	for fi in range(_active_fires.size()):
		var fire: Dictionary = _active_fires[fi]
		var pos: Vector2i = fire.get("pos", Vector2i.ZERO)
		var intensity: float = fire.get("intensity", 1.0)
		# Decay intensity over time
		intensity -= 0.05
		if intensity <= 0.0:
			fires_to_remove.append(fi)
			continue
		# Try to spread to adjacent tiles
		if fire_suppression > 0.0 and _fire_spread_rng.randf() < 0.3:
			for dx in range(-1, 2):
				for dy in range(-1, 2):
					if dx == 0 and dy == 0:
						continue
					var nx: int = pos.x + dx
					var ny: int = pos.y + dy
					if not _is_valid_tile(nx, ny):
						continue
					var nidx: int = _tile_index(nx, ny)
					if nidx < 0:
						continue
					# Spread chance depends on vegetation dryness
					var veg_dryness: float = 1.0 - _moisture[nidx]
					var spread_chance: float = FIRE_SPREAD_BASE_CHANCE * intensity * veg_dryness * fire_suppression
					if veg_dryness > 0.6:
						spread_chance *= FIRE_DRY_MULTIPLIER
					spread_chance *= (1.0 + wind_factor * FIRE_WIND_MULTIPLIER)
					if _fire_spread_rng.randf() < spread_chance and _vegetation[nidx] > 0.2:
						# Check not already on fire
						var already_burning: bool = false
						for ef in _active_fires:
							if ef.get("pos") == Vector2i(nx, ny):
								already_burning = true
								break
						if not already_burning:
							new_fires.append({"pos": Vector2i(nx, ny), "intensity": intensity * 0.7, "tick_started": tick})
							# Reduce vegetation at new fire location
							_vegetation[nidx] = maxf(VEGETATION_MIN, _vegetation[nidx] - 0.3)
		# Update fire intensity
		_active_fires[fi]["intensity"] = intensity
	# Remove extinguished fires
	for fi in range(fires_to_remove.size() - 1, -1, -1):
		_active_fires.remove_at(fires_to_remove[fi])
	# Add new fires
	for nf in new_fires:
		if _active_fires.size() < MAX_FIRE_SOURCES:
			_active_fires.append(nf)
	# Log significant wildfires
	if not new_fires.is_empty() and tick - _last_wildfire_log_tick > 5000:
		_last_wildfire_log_tick = tick
		_pending_events.append({
			"type": "wildfire",
			"tick": tick,
			"new_fires": new_fires.size(),
			"total_active": _active_fires.size(),
		})


func start_fire_at(x: int, y: int, intensity: float = 1.0) -> void:
	"""Start a fire at the given tile (for fire pits, lightning strikes, etc.)."""
	if not _initialized or not _is_valid_tile(x, y):
		return
	# Check not already on fire
	for fire in _active_fires:
		if fire.get("pos") == Vector2i(x, y):
			return
	if _active_fires.size() >= MAX_FIRE_SOURCES:
		return
	_active_fires.append({"pos": Vector2i(x, y), "intensity": intensity, "tick_started": GameManager.tick_count if GameManager != null else 0})


func extinguish_fire_at(x: int, y: int) -> void:
	"""Extinguish fire at the given tile."""
	for i in range(_active_fires.size() - 1, -1, -1):
		if _active_fires[i].get("pos") == Vector2i(x, y):
			_active_fires.remove_at(i)
			return


func is_tile_on_fire(x: int, y: int) -> bool:
	for fire in _active_fires:
		if fire.get("pos") == Vector2i(x, y):
			return true
	return false


func get_active_fire_count() -> int:
	return _active_fires.size()


func _get_wind_factor() -> float:
	"""Get wind factor for fire spread (0.0 = calm, 1.0 = strong wind)."""
	var weather_overlay: Node = _get_weather_overlay()
	if weather_overlay == null:
		return 0.0
	var weather: String = weather_overlay.get_current_weather() if weather_overlay.has_method("get_current_weather") else "none"
	match weather:
		"storm": return 1.0
		"gusty": return 0.6
		"rain": return 0.2
		_: return 0.3


# ============================================================
# EROSION
# ============================================================

func _update_erosion(tick: int) -> void:
	"""Erosion: soil degradation from water flow, deforestation, overuse."""
	var tile_count: int = _soil_quality.size()
	var weather_overlay: Node = _get_weather_overlay()
	var is_raining: bool = weather_overlay != null and weather_overlay.has_method("is_precipitating") and weather_overlay.is_precipitating()
	for i in range(tile_count):
		var x: int = i % WorldData.WIDTH
		var y: int = i / WorldData.WIDTH
		var biome: int = _get_biome_at(x, y)
		# Rain erosion: bare soil erodes faster
		if is_raining and _vegetation[i] < 0.2:
			var erosion_rate: float = 0.01 * (1.0 - _vegetation[i])
			_soil_quality[i] = maxf(SOIL_MIN, _soil_quality[i] - erosion_rate)
			# Eroded soil flows downhill (simplified: spread to adjacent)
			_spread_erosion_to_neighbors(x, y, erosion_rate * 0.5)
		# Deforestation accelerates erosion
		if _vegetation[i] < 0.1 and biome == Biome.Type.FOREST:
			_soil_quality[i] = maxf(SOIL_MIN, _soil_quality[i] - 0.005)


func _spread_erosion_to_neighbors(x: int, y: int, amount: float) -> void:
	"""Spread eroded soil to adjacent tiles (simplified water flow)."""
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			var nx: int = x + dx
			var ny: int = y + dy
			if not _is_valid_tile(nx, ny):
				continue
			var nidx: int = _tile_index(nx, ny)
			if nidx < 0:
				continue
			# Lower tiles receive more eroded soil
			_soil_quality[nidx] = minf(SOIL_MAX, _soil_quality[nidx] + amount * 0.25)


# ============================================================
# POLLUTION
# ============================================================

func _update_pollution(tick: int) -> void:
	"""Pollution diffusion and decay."""
	var tile_count: int = _pollution.size()
	# Pollution from fire pits
	for fire in _active_fires:
		var pos: Vector2i = fire.get("pos", Vector2i.ZERO)
		var fidx: int = _tile_index(pos.x, pos.y)
		if fidx >= 0:
			_pollution[fidx] = minf(POLLUTION_MAX, _pollution[fidx] + POLLUTION_FIRE_PIT)
	# Pollution diffusion (spread to neighbors)
	var old_pollution: PackedFloat32Array = _pollution.duplicate()
	for i in range(tile_count):
		var x: int = i % WorldData.WIDTH
		var y: int = i / WorldData.WIDTH
		var diffusion: float = 0.0
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				if dx == 0 and dy == 0:
					continue
				var nx: int = x + dx
				var ny: int = y + dy
				if not _is_valid_tile(nx, ny):
					continue
				var nidx: int = _tile_index(nx, ny)
				if nidx < 0:
					continue
				diffusion += (old_pollution[nidx] - _pollution[i]) * POLLUTION_DIFFUSION_RATE * 0.125
		_pollution[i] = clampf(_pollution[i] + diffusion, POLLUTION_MIN, POLLUTION_MAX)
		# Natural decay
		_pollution[i] = maxf(POLLUTION_MIN, _pollution[i] - POLLUTION_DECAY_RATE)


func add_pollution_at(x: int, y: int, amount: float) -> void:
	"""Add pollution at a tile (from settlement activity, industry, etc.)."""
	if not _initialized or not _is_valid_tile(x, y):
		return
	var idx: int = _tile_index(x, y)
	if idx < 0:
		return
	_pollution[idx] = minf(POLLUTION_MAX, _pollution[idx] + amount)


# ============================================================
# ANIMAL MIGRATION
# ============================================================

func _update_migration(tick: int) -> void:
	"""Update animal migration patterns based on season and ecology."""
	# Migration is handled by AnimalSpawner, but we provide ecology data
	# This method exists for future integration
	pass


func get_migration_bias_for_biome(biome: int) -> float:
	"""Get migration bias for biome (positive = attractive, negative = repulsive)."""
	var season: int = get_current_season()
	var season_name: String = Biome.season_name(season).to_lower()
	return Biome.seasonal_migration_bias(season_name, biome)


# ============================================================
# RESOURCE REGROWTH (ecological, not timer-based)
# ============================================================

func can_resource_regrow_at(x: int, y: int) -> bool:
	"""Check if a resource (tree, ore, etc.) can regrow at this tile."""
	if not _initialized or not _is_valid_tile(x, y):
		return false
	var idx: int = _tile_index(x, y)
	if idx < 0:
		return false
	# Trees need sufficient vegetation, soil, and moisture
	var biome: int = _get_biome_at(x, y)
	if biome == Biome.Type.FOREST or biome == Biome.Type.PLAINS or biome == Biome.Type.GRASS:
		return _vegetation[idx] >= TREE_REGROWTH_MIN_VEG and _soil_quality[idx] > 0.3 and _moisture[idx] > 0.2
	return false


func get_regrowth_probability_at(x: int, y: int) -> float:
	"""Get probability (0.0-1.0) that a resource will regrow at this tile."""
	if not can_resource_regrow_at(x, y):
		return 0.0
	var idx: int = _tile_index(x, y)
	var soil_factor: float = _soil_quality[idx]
	var moisture_factor: float = _moisture[idx]
	var veg_factor: float = _vegetation[idx]
	var season: int = get_current_season()
	var season_mod: float = _season_growth_modifier(season, _get_biome_at(x, y))
	return (soil_factor * 0.3 + moisture_factor * 0.3 + veg_factor * 0.2 + season_mod * 0.2)


# ============================================================
# ECOLOGY EVENTS
# ============================================================

func get_pending_events() -> Array[Dictionary]:
	var events: Array[Dictionary] = _pending_events.duplicate()
	_pending_events.clear()
	return events


# ============================================================
# IMPACT TRACKING (player actions affect ecology)
# ============================================================

func on_tile_harvested(x: int, y: int) -> void:
	"""Called when a tile is harvested (foraging, farming)."""
	if not _initialized or not _is_valid_tile(x, y):
		return
	var idx: int = _tile_index(x, y)
	if idx < 0:
		return
	_soil_quality[idx] = maxf(SOIL_MIN, _soil_quality[idx] - SOIL_DEGRADATION_HARVEST)
	_vegetation[idx] = maxf(VEGETATION_MIN, _vegetation[idx] - 0.1)


func on_tree_chopped(x: int, y: int) -> void:
	"""Called when a tree is chopped."""
	if not _initialized or not _is_valid_tile(x, y):
		return
	var idx: int = _tile_index(x, y)
	if idx < 0:
		return
	_soil_quality[idx] = maxf(SOIL_MIN, _soil_quality[idx] - SOIL_DEGRADATION_DEFOREST)
	_vegetation[idx] = maxf(VEGETATION_MIN, _vegetation[idx] - 0.4)


func on_settlement_activity(x: int, y: int, pawn_count: int) -> void:
	"""Called for settlement activity (pollution from population)."""
	if not _initialized or not _is_valid_tile(x, y):
		return
	var idx: int = _tile_index(x, y)
	if idx < 0:
		return
	var pollution_amount: float = float(pawn_count) * POLLUTION_PER_PAWN
	_pollution[idx] = minf(POLLUTION_MAX, _pollution[idx] + pollution_amount)


# ============================================================
# HELPERS
# ============================================================

func _tile_index(x: int, y: int) -> int:
	if x < 0 or y < 0 or x >= WorldData.WIDTH or y >= WorldData.HEIGHT:
		return -1
	return y * WorldData.WIDTH + x


func _is_valid_tile(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < WorldData.WIDTH and y < WorldData.HEIGHT


func _get_biome_at(x: int, y: int) -> int:
	var world: Node = _get_world()
	if world == null or world.data == null:
		return Biome.Type.PLAINS
	return world.data.get_biome(x, y)


func _get_world() -> Node:
	var main: Node = get_node_or_null("/root/Main")
	if main == null:
		return null
	return main.get_node_or_null("World") if main.has_node("World") else null


func _get_weather_overlay() -> Node:
	var main: Node = get_node_or_null("/root/Main")
	if main == null:
		return null
	return main.get_node_or_null("WeatherOverlay") if main.has_node("WeatherOverlay") else null
