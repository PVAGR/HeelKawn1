extends Node
## DisasterSystem - Random catastrophic events for emergent storytelling
##
## Disasters make the world feel dangerous and dynamic.
## Pawns must respond to crises, creating memorable stories.
##
## Types:
## - Fire (spreads, destroys buildings)
## - Plague (spreads between pawns, reduces work efficiency)
## - Famine (food spoilage, wildlife depletion)
## - Earthquake (terrain damage, building destruction)

# Disaster data structure
## {
##   "disaster_id": int,
##   "type": String,  # "fire", "plague", "famine", "earthquake"
##   "region": int,
##   "tile": Vector2i,
##   "severity": int,  # 1-10 scale
##   "start_tick": int,
##   "duration_ticks": int,
##   "affected_pawns": Array,  # pawn IDs
##   "affected_buildings": Array,  # tile positions
##   "status": String  # "active", "contained", "resolved"
## }
var active_disasters: Array[Dictionary] = []
var _next_disaster_id: int = 1

# Statistics
var stats: Dictionary = {
	"total_disasters": 0,
	"fires": 0,
	"plagues": 0,
	"famines": 0,
	"earthquakes": 0,
	"pawns_affected": 0,
	"buildings_destroyed": 0
}

# Configuration
const DISASTER_CHECK_INTERVAL: int = 10000  # Check every 10000 ticks
const BASE_DISASTER_CHANCE: float = 0.15  # 15% base chance per check
const SEVERITY_SCALE: float = 1.0  # Scales with game progress
const EARLY_PROTECTION_DAYS: int = 35

# Disaster type probabilities
const DISASTER_PROBABILITIES: Dictionary = {
	"fire": 0.35,      # 35% of disasters
	"plague": 0.25,    # 25% of disasters
	"famine": 0.25,    # 25% of disasters
	"earthquake": 0.15  # 15% of disasters
}

# References
@onready var _world: Node = null
@onready var _pawn_spawner: Node = null
@onready var _world_memory: Node = null
@onready var _stockpile_manager: Node = null


func _ready() -> void:
	GameManager.game_tick.connect(_on_game_tick)
	await get_tree().process_frame
	_world = get_node_or_null("/root/Main/World")
	_pawn_spawner = get_node_or_null("/root/Main/WorldViewport/PawnSpawner")
	_world_memory = get_node_or_null("/root/WorldMemory")
	_stockpile_manager = get_node_or_null("/root/StockpileManager")


func _on_game_tick(tick: int) -> void:
	# Check for new disasters periodically
	if tick % DISASTER_CHECK_INTERVAL == 0:
		_try_spawn_disaster(tick)

	# Update active disasters every tick
	_update_disasters(tick)
	_cleanup_resolved_disasters(tick)


func _try_spawn_disaster(tick: int) -> void:
	if _early_protection_active(tick):
		return
	# Roll for disaster
	var rng = RandomNumberGenerator.new()
	rng.seed = tick + 719  # Deterministic seed
	
	if rng.randf() > BASE_DISASTER_CHANCE:
		return  # No disaster this check
	
	# Choose disaster type
	var disaster_type: String = _choose_disaster_type(rng)
	
	# Spawn disaster
	match disaster_type:
		"fire":
			_spawn_fire(tick, rng)
		"plague":
			_spawn_plague(tick, rng)
		"famine":
			_spawn_famine(tick, rng)
		"earthquake":
			_spawn_earthquake(tick, rng)


func _choose_disaster_type(rng: RandomNumberGenerator) -> String:
	var roll: float = rng.randf()
	var cumulative: float = 0.0
	
	for type_key in DISASTER_PROBABILITIES.keys():
		cumulative += DISASTER_PROBABILITIES[type_key]
		if roll <= cumulative:
			return type_key
	
	return "fire"  # Default fallback


func _spawn_fire(tick: int, rng: RandomNumberGenerator) -> void:
	if _world == null or _world.data == null:
		return
	
	# Find a settlement region
	var settlement_regions: Array = _get_settlement_regions()
	if settlement_regions.is_empty():
		return
	
	var target_region: int = settlement_regions[rng.randi() % settlement_regions.size()]
	
	# Find a tile in the region with flammable features
	var target_tile: Vector2i = _find_flammable_tile_in_region(target_region, rng)
	if target_tile.x < 0:
		return  # No suitable tile
	
	# Create fire disaster
	var severity: int = rng.randi_range(3, 8)
	var duration: int = 2000 + (severity * 200)  # 2000-3600 ticks
	
	var disaster: Dictionary = {
		"disaster_id": _next_disaster_id,
		"type": "fire",
		"region": target_region,
		"tile": target_tile,
		"severity": severity,
		"start_tick": tick,
		"duration_ticks": duration,
		"affected_pawns": [],
		"affected_buildings": [],
		"status": "active",
		"spread_chance": 0.3  # 30% chance to spread per update
	}
	
	active_disasters.append(disaster)
	_next_disaster_id += 1
	stats.total_disasters += 1
	stats.fires += 1
	
	# Record event
	_world_memory.record_event({
		"type": "disaster_fire",
		"region": target_region,
		"tile": {"x": target_tile.x, "y": target_tile.y},
		"severity": severity,
		"tick": tick
	})
	
	if OS.is_debug_build():
		print("[Disaster] Fire started at (%d,%d) severity %d" % [
			target_tile.x, target_tile.y, severity
		])


func _spawn_plague(tick: int, rng: RandomNumberGenerator) -> void:
	if _pawn_spawner == null:
		return

	# Build fresh list of eligible living candidates
	var candidates: Array = []
	for pawn in _pawn_spawner.pawns:
		if pawn == null or not is_instance_valid(pawn):
			continue
		if pawn.data == null:
			continue
		if pawn.data.is_dead:
			continue
		# Skip already infected
		if pawn.data.get_meta("plague_infected", false):
			continue
		candidates.append(pawn)

	if candidates.size() < 3:
		return  # Need minimum population

	# Infect 1-3 random pawns, clamped to candidate count
	var infect_count: int = mini(rng.randi_range(1, 3), candidates.size())
	var affected_pawns: Array = []

	for i in range(infect_count):
		if candidates.is_empty():
			break
		# randi_range upper bound is inclusive, so size-1 is correct
		var index: int = rng.randi_range(0, candidates.size() - 1)
		var pawn: HeelKawnian = candidates[index]
		candidates.remove_at(index)

		if pawn == null or not is_instance_valid(pawn) or pawn.data == null:
			continue

		affected_pawns.append(int(pawn.data.id))
		pawn.data.set_meta("plague_infected", true)
		pawn.data.set_meta("plague_start_tick", tick)

	if affected_pawns.is_empty():
		return

	# Find region where plague started — resolve ID to pawn via lookup, NOT array index
	var first_pawn: HeelKawnian = _get_pawn_by_id(affected_pawns[0])
	var region: int = 0
	if first_pawn != null and first_pawn.data != null:
		region = _world_memory._region_key(first_pawn.data.tile_pos.x, first_pawn.data.tile_pos.y)
	
	# Create plague disaster
	var severity: int = affected_pawns.size()
	var duration: int = 5000  # Plagues last longer
	
	var disaster: Dictionary = {
		"disaster_id": _next_disaster_id,
		"type": "plague",
		"region": region,
		"tile": first_pawn.data.tile_pos if first_pawn != null and first_pawn.data != null else Vector2i.ZERO,
		"severity": severity,
		"start_tick": tick,
		"duration_ticks": duration,
		"affected_pawns": affected_pawns,
		"affected_buildings": [],
		"status": "active",
		"spread_chance": 0.1  # 10% chance to spread to nearby pawns
	}
	
	active_disasters.append(disaster)
	_next_disaster_id += 1
	stats.total_disasters += 1
	stats.plagues += 1
	stats.pawns_affected += affected_pawns.size()
	
	# Record event
	_world_memory.record_event({
		"type": "disaster_plague",
		"region": region,
		"pawns_infected": affected_pawns.size(),
		"severity": severity,
		"tick": tick
	})
	
	if OS.is_debug_build():
		print("[Disaster] Plague started: %d pawns infected" % affected_pawns.size())


func _spawn_famine(tick: int, rng: RandomNumberGenerator) -> void:
	if _stockpile_manager == null:
		return
	if _early_protection_active(tick):
		return
	
	# Reduce food stockpiles
	var total_food: int = _stockpile_manager.total_food()
	if total_food < 10:
		return  # Already low on food
	
	# Spoil 30-60% of food
	var spoil_percent: float = rng.randf_range(0.3, 0.6)
	var spoiled_amount: int = int(total_food * spoil_percent)
	
	# Find settlement regions
	var settlement_regions: Array = _get_settlement_regions()
	if settlement_regions.is_empty():
		return
	
	var target_region: int = settlement_regions[rng.randi() % settlement_regions.size()]
	
	# Create famine disaster
	var severity: int = int(spoiled_amount / 5.0)
	var duration: int = 3000  # Famine lasts 3000 ticks
	
	var disaster: Dictionary = {
		"disaster_id": _next_disaster_id,
		"type": "famine",
		"region": target_region,
		"tile": Vector2i.ZERO,
		"severity": severity,
		"start_tick": tick,
		"duration_ticks": duration,
		"affected_pawns": [],
		"affected_buildings": [],
		"status": "active",
		"food_spoiled": spoiled_amount
	}
	
	active_disasters.append(disaster)
	_next_disaster_id += 1
	stats.total_disasters += 1
	stats.famines += 1
	
	# Record event
	_world_memory.record_event({
		"type": "disaster_famine",
		"region": target_region,
		"food_spoiled": spoiled_amount,
		"severity": severity,
		"tick": tick
	})
	
	if OS.is_debug_build():
		print("[Disaster] Famine started: %d food spoiled" % spoiled_amount)


func _early_protection_active(tick: int) -> bool:
	return tick < EARLY_PROTECTION_DAYS * SimTime.TICKS_PER_VISUAL_DAY


func _spawn_earthquake(tick: int, rng: RandomNumberGenerator) -> void:
	if _world == null or _world.data == null:
		return
	
	# Find a settlement region
	var settlement_regions: Array = _get_settlement_regions()
	if settlement_regions.is_empty():
		return
	
	var target_region: int = settlement_regions[rng.randi() % settlement_regions.size()]
	
	# Find center tile of region
	var center_tile: Vector2i = _region_center(target_region)
	
	# Create earthquake disaster
	var severity: int = rng.randi_range(4, 10)
	var duration: int = 500  # Earthquakes are short but destructive
	var affected_radius: int = severity  # Tiles affected = severity
	
	var disaster: Dictionary = {
		"disaster_id": _next_disaster_id,
		"type": "earthquake",
		"region": target_region,
		"tile": center_tile,
		"severity": severity,
		"start_tick": tick,
		"duration_ticks": duration,
		"affected_pawns": [],
		"affected_buildings": [],
		"status": "active",
		"affected_radius": affected_radius
	}
	
	active_disasters.append(disaster)
	_next_disaster_id += 1
	stats.total_disasters += 1
	stats.earthquakes += 1
	
	# Destroy buildings in radius
	_destroy_buildings_in_radius(center_tile, affected_radius, tick)
	
	# Record event
	_world_memory.record_event({
		"type": "disaster_earthquake",
		"region": target_region,
		"tile": {"x": center_tile.x, "y": center_tile.y},
		"severity": severity,
		"radius": affected_radius,
		"tick": tick
	})
	
	if OS.is_debug_build():
		print("[Disaster] Earthquake at (%d,%d) severity %d" % [
			center_tile.x, center_tile.y, severity
		])


func _update_disasters(tick: int) -> void:
	for disaster in active_disasters:
		if disaster.status != "active":
			continue
		
		# Update based on disaster type
		match disaster.type:
			"fire":
				_update_fire(disaster, tick)
			"plague":
				_update_plague(disaster, tick)
			"famine":
				_update_famine(disaster, tick)
			"earthquake":
				# Earthquakes are instant, no ongoing update
				pass


func _update_fire(disaster: Dictionary, tick: int) -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = tick + disaster.disaster_id
	
	# Chance to spread
	if rng.randf() < disaster.spread_chance:
		_spread_fire(disaster, tick, rng)
	
	# Check if fire is contained
	var elapsed: int = tick - disaster.start_tick
	if elapsed > disaster.duration_ticks:
		disaster.status = "resolved"


func _update_plague(disaster: Dictionary, tick: int) -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = tick + disaster.disaster_id + 1000
	
	# Chance to spread to nearby pawns
	if rng.randf() < disaster.spread_chance:
		_spread_plague(disaster, tick, rng)
	
	# Check if plague has run its course
	var elapsed: int = tick - disaster.start_tick
	if elapsed > disaster.duration_ticks:
		# Cure infected pawns
		for pawn_id in disaster.affected_pawns:
			var pawn: HeelKawnian = _get_pawn_by_id(pawn_id)
			if pawn != null and pawn.data != null:
				pawn.data.set_meta("plague_infected", false)
				pawn.data.set_meta("plague_start_tick", 0)
		
		disaster.status = "resolved"


func _update_famine(disaster: Dictionary, tick: int) -> void:
	var elapsed: int = tick - disaster.start_tick
	if elapsed > disaster.duration_ticks:
		disaster.status = "resolved"


func _spread_fire(disaster: Dictionary, tick: int, rng: RandomNumberGenerator) -> void:
	# Find nearby flammable tiles
	var center: Vector2i = disaster.tile
	var spread_radius: int = 3
	
	for dx in range(-spread_radius, spread_radius + 1):
		for dy in range(-spread_radius, spread_radius + 1):
			if dx == 0 and dy == 0:
				continue
			
			var target: Vector2i = center + Vector2i(dx, dy)
			if _is_flammable_tile(target):
				# Add to affected buildings
				if not disaster.affected_buildings.has(target):
					disaster.affected_buildings.append(target)
					stats.buildings_destroyed += 1
				
				# Record building destruction
				_world_memory.record_event({
					"type": "building_destroyed",
					"cause": "fire",
					"tile": {"x": target.x, "y": target.y},
					"disaster_id": disaster.disaster_id,
					"tick": tick
				})
				
				break  # Only spread to one tile per update


func _spread_plague(disaster: Dictionary, tick: int, rng: RandomNumberGenerator) -> void:
	if _pawn_spawner == null:
		return
	
	# Find pawns near infected pawns
	for infected_id in disaster.affected_pawns:
		var infected_pawn: HeelKawnian = _get_pawn_by_id(infected_id)
		if infected_pawn == null or not is_instance_valid(infected_pawn):
			continue
		
		for pawn in _pawn_spawner.pawns:
			if pawn == null or not is_instance_valid(pawn) or pawn.data == null:
				continue
			
			var pawn_id: int = int(pawn.data.id)
			if disaster.affected_pawns.has(pawn_id):
				continue  # Already infected
			
			# Check distance
			var dist: float = infected_pawn.position.distance_to(pawn.position)
			if dist < 64.0:  # Within infection range
				# 50% chance to infect
				if rng.randf() < 0.5:
					disaster.affected_pawns.append(pawn_id)
					pawn.data.set_meta("plague_infected", true)
					pawn.data.set_meta("plague_start_tick", tick)
					stats.pawns_affected += 1


func _destroy_buildings_in_radius(center: Vector2i, radius: int, tick: int) -> void:
	if _world == null:
		return
	
	for dx in range(-radius, radius + 1):
		for dy in range(-radius, radius + 1):
			var target: Vector2i = center + Vector2i(dx, dy)
			if not _world.data.in_bounds(target.x, target.y):
				continue
			
			# Destroy buildings at this tile
			var feature: int = _world.data.get_feature(target.x, target.y)
			if feature != TileFeature.Type.NONE:
				# Record destruction
				_world_memory.record_event({
					"type": "building_destroyed",
					"cause": "earthquake",
					"tile": {"x": target.x, "y": target.y},
					"tick": tick
				})
				
				stats.buildings_destroyed += 1


func _cleanup_resolved_disasters(tick: int) -> void:
	for i in range(active_disasters.size() - 1, -1, -1):
		var disaster: Dictionary = active_disasters[i]
		
		if disaster.status == "resolved":
			# Record resolution event
			_world_memory.record_event({
				"type": "disaster_resolved",
				"disaster_type": disaster.type,
				"disaster_id": disaster.disaster_id,
				"tick": tick
			})
			
			active_disasters.remove_at(i)


# ==================== Helper Functions ====================

func _get_settlement_regions() -> Array:
	var regions: Array = []
	if SettlementMemory == null or SettlementMemory.settlements.is_empty():
		return regions
	
	for st in SettlementMemory.settlements:
		if st is Dictionary:
			var center: int = int(st.get("center_region", -1))
			if center >= 0:
				regions.append(center)
	
	return regions


func _find_flammable_tile_in_region(region: int, rng: RandomNumberGenerator) -> Vector2i:
	# Simplified: just return a random tile in the region
	# In full implementation, would scan for wooden buildings
	return Vector2i(rng.randi_range(0, 100), rng.randi_range(0, 100))


func _is_flammable_tile(tile: Vector2i) -> bool:
	# Check if tile has flammable feature
	if _world == null:
		return false
	
	var feature: int = _world.data.get_feature(tile.x, tile.y)
	# WALL and DOOR are wooden (flammable) in early game
	return feature == TileFeature.Type.WALL or feature == TileFeature.Type.DOOR or feature == TileFeature.Type.TREE


func _region_center(region: int) -> Vector2i:
	# Return approximate center of region
	# Simplified implementation
	return Vector2i((region * 32) % 256, (region / 32) * 32)


func _get_pawn_by_id(pawn_id: int) -> HeelKawnian:
	if _pawn_spawner == null:
		return null
	
	for pawn in _pawn_spawner.pawns:
		if pawn != null and is_instance_valid(pawn) and pawn.data != null:
			if int(pawn.data.id) == pawn_id:
				return pawn
	
	return null


# ==================== Public API ====================

## Get all active disasters
func get_active_disasters() -> Array[Dictionary]:
	return active_disasters

## Get disaster statistics
func get_stats() -> Dictionary:
	return stats.duplicate()

## Get disaster risk for a region (for UI hints)
func get_disaster_risk(region: int) -> String:
	# Based on recent disaster history
	var recent_count: int = 0
	for disaster in active_disasters:
		if disaster.region == region:
			recent_count += 1
	
	if recent_count >= 3:
		return "Very High"
	elif recent_count >= 2:
		return "High"
	elif recent_count >= 1:
		return "Moderate"
	else:
		return "Low"

## Manually trigger a disaster (for testing)
func debug_trigger_disaster(type: String, _region: int = -1) -> void:
	var tick: int = GameManager.tick_count
	var rng = RandomNumberGenerator.new()
	rng.seed = tick + 99999
	
	match type:
		"fire":
			_spawn_fire(tick, rng)
		"plague":
			_spawn_plague(tick, rng)
		"famine":
			_spawn_famine(tick, rng)
		"earthquake":
			_spawn_earthquake(tick, rng)
	
	print("[Disaster] Debug triggered: %s" % type)
