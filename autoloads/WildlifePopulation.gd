extends Node
## Wildlife Population System
## Manages deer and rabbit populations across the world map
## 
## Features:
## - Biome-based spawning (rabbits in forests, deer in plains)
## - Population dynamics (birth/death cycles)
## - Hunting jobs for pawns
## - Meat resource for food variety

# Animal species types
enum Species { RABBIT, DEER }

# Population data per region
## {
##   "region_key": int,
##   "species": int,  # Species enum
##   "population": int,
##   "last_birth_tick": int,
##   "last_death_tick": int,
##   "max_population": int
## }
var wildlife_populations: Array[Dictionary] = []

# Configuration
const POPULATION_CHECK_INTERVAL: int = 500  # Check population dynamics every 500 ticks
const BIRTH_RATE_PER_CHECK: float = 0.15  # 15% chance to birth per check
const DEATH_RATE_PER_CHECK: float = 0.08  # 8% chance to die per check
const MIN_POPULATION: int = 5  # Minimum viable population
const MAX_POPULATION_PER_REGION: int = 50  # Carrying capacity
const RABBIT_BIOME_MULTIPLIER: float = 1.5  # Rabbits thrive in forests
const DEER_BIOME_MULTIPLIER: float = 1.2  # Deer prefer plains

# Hunting configuration
const HUNTING_SUCCESS_RATE: float = 0.4  # 40% base success rate
const WARRIOR_HUNTING_BONUS: float = 0.2  # Warriors get +20% success
const MEAT_PER_RABBIT: int = 1
const MEAT_PER_DEER: int = 4

# References
@onready var _world: Node = null
@onready var _pawn_spawner: Node = null
@onready var _job_manager: Node = null
@onready var _stockpile_manager: Node = null
@onready var _world_memory: Node = null


func _ready() -> void:
	GameManager.game_tick.connect(_on_game_tick)
	# Wait for world to be available
	await get_tree().process_frame
	_world = get_node_or_null("/root/Main/World")
	_pawn_spawner = get_node_or_null("/root/Main/WorldViewport/PawnSpawner")
	_job_manager = get_node_or_null("/root/JobManager")
	_stockpile_manager = get_node_or_null("/root/StockpileManager")
	_world_memory = get_node_or_null("/root/WorldMemory")


func _on_game_tick(tick: int) -> void:
	# Update population dynamics periodically
	if tick % POPULATION_CHECK_INTERVAL == 0:
		_update_population_dynamics(tick)
	
	# Initial spawn on first check
	if tick == POPULATION_CHECK_INTERVAL:
		_initial_wildlife_spawn()


func _initial_wildlife_spawn() -> void:
	if _world == null or _world.data == null:
		return
	
	# Spawn rabbits in forest biomes
	_spawn_species_in_biome(Species.RABBIT, TileFeature.Biome.FOREST, 20)
	
	# Spawn deer in plains biomes
	_spawn_species_in_biome(Species.DEER, TileFeature.Biome.PLAINS, 15)
	
	if OS.is_debug_build():
		print("[Wildlife] Initial wildlife spawned")


func _spawn_species_in_biome(species: Species, biome: int, base_count: int) -> void:
	var spawn_count: int = 0
	var rng = RandomNumberGenerator.new()
	rng.seed = _world.data.world_seed
	
	# Find suitable regions
	var suitable_regions: PackedInt32Array = _find_regions_with_biome(biome)
	
	for region in suitable_regions:
		if spawn_count >= base_count:
			break
		
		# Add population to this region
		_add_wildlife_population(region, species, rng.randi_range(3, 8))
		spawn_count += 1


func _find_regions_with_biome(biome: int) -> PackedInt32Array:
	var regions: PackedInt32Array = []
	if _world == null or _world.data == null:
		return regions
	
	# Sample regions across the map
	for x in range(0, _world.data.map_width, 32):
		for y in range(0, _world.data.map_height, 32):
			if _world.data.get_biome(x, y) == biome:
				var region: int = _world_memory._region_key(x, y)
				if not regions.has(region):
					regions.append(region)
	
	return regions


func _add_wildlife_population(region: int, species: Species, count: int) -> void:
	# Check if population already exists for this region/species
	for pop in wildlife_populations:
		if pop.region_key == region and pop.species == species:
			pop.population += count
			return
	
	# Create new population entry
	wildlife_populations.append({
		"region_key": region,
		"species": species,
		"population": count,
		"last_birth_tick": GameManager.tick_count,
		"last_death_tick": GameManager.tick_count,
		"max_population": MAX_POPULATION_PER_REGION
	})


func _update_population_dynamics(tick: int) -> void:
	for pop in wildlife_populations:
		# Birth cycle
		if _should_give_birth(pop, tick):
			_wildlife_birth(pop)
		
		# Death cycle
		if _should_die(pop, tick):
			_wildlife_death(pop, tick)
		
		# Record animal death events for WorldMemory
		if pop.get("deaths_this_cycle", 0) > 0:
			_record_wildlife_deaths(pop, tick)
			pop["deaths_this_cycle"] = 0


func _should_give_birth(pop: Dictionary, tick: int) -> bool:
	# Population must be below max
	if pop.population >= pop.max_population:
		return false
	
	# Minimum population for breeding
	if pop.population < MIN_POPULATION:
		return false
	
	# Random chance based on birth rate
	var rng = RandomNumberGenerator.new()
	rng.seed = tick + pop.region_key + pop.species
	
	return rng.randf() < BIRTH_RATE_PER_CHECK


func _should_die(pop: Dictionary, tick: int) -> bool:
	# Random chance based on death rate
	var rng = RandomNumberGenerator.new()
	rng.seed = tick + pop.region_key + pop.species + 1000
	
	return rng.randf() < DEATH_RATE_PER_CHECK


func _wildlife_birth(pop: Dictionary) -> void:
	# Add 1-3 new animals
	var birth_count: int = randi_range(1, 3)
	pop.population += birth_count
	pop.last_birth_tick = GameManager.tick_count
	
	if OS.is_debug_build():
		print("[Wildlife] Birth in region %d: +%d animals (now %d)" % [
			pop.region_key, birth_count, pop.population
		])


func _wildlife_death(pop: Dictionary, tick: int) -> void:
	# Remove 1-2 animals
	var death_count: int = randi_range(1, 2)
	pop.population = maxi(0, pop.population - death_count)
	pop.last_death_tick = tick
	pop["deaths_this_cycle"] = pop.get("deaths_this_cycle", 0) + death_count


func _record_wildlife_deaths(pop: Dictionary, tick: int) -> void:
	if _world_memory == null:
		return
	
	var species_name: String = "rabbit" if pop.species == Species.RABBIT else "deer"
	var death_count: int = pop.get("deaths_this_cycle", 0)
	
	if death_count > 0:
		_world_memory.record_event({
			"type": "animal_death",
			"species": species_name,
			"region": pop.region_key,
			"count": death_count,
			"tick": tick
		})


# ==================== HUNTING SYSTEM ====================

## Check if a region has huntable wildlife
func has_wildlife_in_region(region: int) -> bool:
	for pop in wildlife_populations:
		if pop.region_key == region and pop.population > 0:
			return true
	return false


## Get wildlife count in region
func get_wildlife_count(region: int, species: Species = -1) -> int:
	var total: int = 0
	for pop in wildlife_populations:
		if pop.region_key == region:
			if species == -1 or pop.species == species:
				total += pop.population
	return total


## Calculate hunting success chance for a pawn
func get_hunting_success_chance(pawn: Node) -> float:
	if pawn == null or not is_instance_valid(pawn) or pawn.data == null:
		return HUNTING_SUCCESS_RATE
	
	var chance: float = HUNTING_SUCCESS_RATE
	
	# Warrior profession bonus
	if pawn.data.current_profession == pawn.data.Profession.WARRIOR:
		chance += WARRIOR_HUNTING_BONUS
	
	# Hunting skill bonus
	var hunting_level: int = pawn.data.get_skill_level(pawn.data.Skill.HUNTING)
	chance += float(hunting_level) * 0.02  # +2% per level
	
	return minf(0.95, chance)  # Cap at 95%


## Process a successful hunt
func process_hunt(pawn: Node, region: int) -> Dictionary:
	var result: Dictionary = {
		"success": false,
		"meat_gained": 0,
		"species_hunted": ""
	}
	
	# Check success chance
	var rng = RandomNumberGenerator.new()
	rng.seed = GameManager.tick_count + int(pawn.data.id)
	
	if rng.randf() > get_hunting_success_chance(pawn):
		return result  # Hunt failed
	
	# Find wildlife in region
	var targets: Array = []
	for pop in wildlife_populations:
		if pop.region_key == region and pop.population > 0:
			targets.append(pop)
	
	if targets.is_empty():
		return result  # No wildlife
	
	# Pick random target
	var target: Dictionary = targets[randi() % targets.size()]
	
	# Determine meat gain
	var meat: int = MEAT_PER_RABBIT if target.species == Species.RABBIT else MEAT_PER_DEER
	var species_name: String = "rabbit" if target.species == Species.RABBIT else "deer"
	
	# Reduce wildlife population
	target.population -= 1
	
	# Record success
	result.success = true
	result.meat_gained = meat
	result.species_hunted = species_name
	
	# Add meat to pawn's carrying
	if pawn.data != null:
		pawn.data.carrying = 100  # Item.Type.MEAT (assuming 100)
		pawn.data.carrying_qty += meat
	
	# Record hunt event
	if _world_memory != null:
		_world_memory.record_event({
			"type": "animal_hunted",
			"pawn_id": int(pawn.data.id),
			"species": species_name,
			"region": region,
			"meat": meat,
			"tick": GameManager.tick_count
		})
	
	if OS.is_debug_build():
		print("[Wildlife] %s hunted %s: +%d meat" % [
			pawn.data.display_name, species_name, meat
		])
	
	return result


# ==================== PUBLIC API ====================

## Get all wildlife populations (for debugging)
func get_all_populations() -> Array[Dictionary]:
	return wildlife_populations.duplicate()


## Get wildlife statistics
func get_stats() -> Dictionary:
	var stats: Dictionary = {
		"total_populations": wildlife_populations.size(),
		"total_animals": 0,
		"rabbit_count": 0,
		"deer_count": 0
	}
	
	for pop in wildlife_populations:
		stats.total_animals += pop.population
		if pop.species == Species.RABBIT:
			stats.rabbit_count += pop.population
		else:
			stats.deer_count += pop.population
	
	return stats


## Manually spawn wildlife (for testing)
func debug_spawn_wildlife(region: int, species: Species, count: int) -> void:
	_add_wildlife_population(region, species, count)
	print("[Wildlife] Debug spawn: %d %s in region %d" % [
		count, "rabbits" if species == Species.RABBIT else "deer", region
	])


## Clear all wildlife (for testing)
func debug_clear_all() -> void:
	wildlife_populations.clear()
	print("[Wildlife] All wildlife cleared")
