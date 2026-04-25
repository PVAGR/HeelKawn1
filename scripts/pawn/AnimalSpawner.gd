## AnimalSpawner.gd — Deterministic per-region population v1: spawn, ledger, no RNG.
## Deaths read from [WorldMemory] only; [SettlementMemory] / [WorldPersistence] gate spawns.
class_name AnimalSpawner
extends Node

const INITIAL_RABBITS: int = 8
const INITIAL_DEER: int = 4
const MAX_ANIMALS: int = 50

## Interval for [method update_population_dynamics] (not every tick).
const POPULATION_CHECK_TICKS: int = 2000
## Reproduction: no [WorldMemory] animal death in (rk, sp) for this many ticks, then +1.
const REPRO_TICKS: int = 8000
## Legacy: external / HUD; v1 uses [const POPULATION_CHECK_TICKS].
const SPAWN_RATE_CHECK_INTERVAL: int = 100

var animals: Array[Animal] = []

## [method spawn_initial] only: counts per (region#species) key.
var _initial_placed: Dictionary = {}
## Births from [method _spawn_from_population_system] (reproduction + recovery).
var _system_births: Dictionary = {}
## [code]rsk -> true[/code] when the species is locally gone and recovery is blocked.
var _local_extinct: Dictionary = {}
## [code]rsk -> tick[/code] when we last ran a population spawn for that pair.
var _last_system_spawn_tick: Dictionary = {}


static func _rsk(rk: int, species: int) -> String:
	return "%d#%d" % [rk, species]


static func _live_count_in_region(animals_arr: Array, world: World, rk: int, species: int) -> int:
	var n: int = 0
	for a in animals_arr:
		if a == null or not is_instance_valid(a):
			continue
		if int(a.animal_type) != species:
			continue
		var t: Vector2i = a.tile_pos
		if not world.data.in_bounds(t.x, t.y):
			continue
		if WorldMemory._region_key(t.x, t.y) == rk:
			n += 1
	return n


static func _collect_region_keys(animals_arr: Array, world: World) -> Array[int]:
	var seen: Dictionary = {}
	for a in animals_arr:
		if a == null or not is_instance_valid(a):
			continue
		var t: Vector2i = a.tile_pos
		if not world.data.in_bounds(t.x, t.y):
			continue
		seen[WorldMemory._region_key(t.x, t.y)] = true
	var out: Array[int] = []
	for k in seen:
		out.append(int(k))
	out.sort()
	return out


## New world: clear derived state (call before [method spawn_initial] if you reuse the node).
func reset_population_derived_state() -> void:
	_initial_placed.clear()
	_system_births.clear()
	_local_extinct.clear()
	_last_system_spawn_tick.clear()


func spawn_initial(world: World) -> void:
	reset_population_derived_state()
	_spawn_group_scan(world, int(Animal.Type.RABBIT), INITIAL_RABBITS, true)
	_spawn_group_scan(world, int(Animal.Type.DEER), INITIAL_DEER, true)
	print(
			"[AnimalSpawner] Initial: %d rabbits, %d deer (deterministic, max %d)"
			% [INITIAL_RABBITS, INITIAL_DEER, MAX_ANIMALS]
	)


func _spawn_group_scan(world: World, species: int, need: int, initial: bool) -> void:
	var left: int = need
	if left <= 0:
		return
	for y in range(WorldData.HEIGHT):
		for x in range(WorldData.WIDTH):
			if left <= 0 or animals.size() >= MAX_ANIMALS:
				return
			var t := Vector2i(x, y)
			if not _is_valid_tile_for_spawn(world, t, species, initial):
				continue
			_spawn_node_at(t, species, world)
			var rk0: int = WorldMemory._region_key(t.x, t.y)
			var h: String = _rsk(rk0, species)
			_initial_placed[h] = int(_initial_placed.get(h, 0)) + 1
			left -= 1


func _is_valid_tile_for_spawn(world: World, t: Vector2i, species: int, initial: bool) -> bool:
	if not world.data.in_bounds(t.x, t.y):
		return false
	var biome: int = world.data.get_biome(t.x, t.y)
	if species == int(Animal.Type.RABBIT):
		if not biome in [Biome.Type.FOREST, Biome.Type.PLAINS]:
			return false
	elif species == int(Animal.Type.DEER):
		if biome != Biome.Type.FOREST:
			return false
	else:
		return false
	if not world.pathfinder.is_passable(t):
		return false
	var rk: int = WorldMemory._region_key(t.x, t.y)
	if SettlementMemory.is_region_in_permanently_abandoned_settlement(rk):
		return false
	var sl: int = int(WorldPersistence.get_region_persistence(rk).get("scar_level", 0))
	if initial:
		return sl < 2
	return sl <= 1


func _spawn_node_at(t: Vector2i, species: int, world: World) -> void:
	if animals.size() >= MAX_ANIMALS:
		return
	var animal: Animal = Animal.new()
	add_child(animal)
	animal.bind(species, t, world)
	animals.append(animal)


## Population rules: +1; increments [member _system_births]; deterministic tile in region.
func _spawn_from_population_system(world: World, rk: int, species: int) -> bool:
	if animals.size() >= MAX_ANIMALS:
		return false
	var t: Vector2i = _find_first_valid_tile_in_region(world, rk, species, false)
	if t.x < 0:
		return false
	_spawn_node_at(t, species, world)
	var key: String = _rsk(rk, species)
	_system_births[key] = int(_system_births.get(key, 0)) + 1
	_last_system_spawn_tick[key] = GameManager.tick_count
	return true


## Scan 16x16 for [param rk] in (dy, dx) order, skip occupied.
func _find_first_valid_tile_in_region(
		world: World, rk: int, species: int, initial: bool
) -> Vector2i:
	var rx: int = int(rk) & 0xFFFF
	var ry: int = (int(rk) >> 16) & 0xFFFF
	for dy in 16:
		for dx in 16:
			var t: Vector2i = Vector2i(rx * 16 + dx, ry * 16 + dy)
			if not _is_valid_tile_for_spawn(world, t, species, initial):
				continue
			if _any_animal_on_tile(animals, t):
				continue
			return t
	return Vector2i(-1, -1)


static func _any_animal_on_tile(animals_arr: Array, t: Vector2i) -> bool:
	for a in animals_arr:
		if a == null or not is_instance_valid(a):
			continue
		if a.tile_pos == t:
			return true
	return false


## v1: random breeding disabled — population comes only from [method update_population_dynamics].
func spawn_animal(_animal_type: int, _tile: Vector2i, _world: World = null) -> void:
	pass


func cleanup_dead_animals() -> void:
	animals = animals.filter(func(e): return is_instance_valid(e) and e != null)


func derived_population_count(rk: int, species: int) -> int:
	return population_count(rk, species)


## v1 model: [code]initial_spawn_count + births - WorldMemory deaths[/code] (derived, not saved).
func population_count(rk: int, species: int) -> int:
	var k: String = _rsk(rk, species)
	var ini0: int = int(_initial_placed.get(k, 0))
	var br0: int = int(_system_births.get(k, 0))
	var d0: int = WorldMemory.get_animal_death_count_in_region(rk, species)
	return ini0 + br0 - d0


## v1: last [method _spawn_from_population_system] tick for (rk, species), or -1.
func get_last_spawn_tick(rk: int, species: int) -> int:
	var k: String = _rsk(rk, species)
	if not _last_system_spawn_tick.has(k):
		return -1
	return int(_last_system_spawn_tick[k])


## v1: from [WorldMemory] only; -1 = no death recorded for (rk, species).
func get_last_death_tick(rk: int, species: int) -> int:
	return WorldMemory.get_last_animal_death_tick_in_region(rk, species)


## Every [const POPULATION_CHECK_TICKS] from [Main] only.
func update_population_dynamics(world: World) -> void:
	if world == null or not is_instance_valid(world) or world.data == null:
		return
	cleanup_dead_animals()
	var tick0: int = GameManager.tick_count
	var rset: Dictionary = {}
	for rk in _collect_region_keys(animals, world):
		rset[rk] = true
	for s in _initial_placed.keys():
		var parts: PackedStringArray = str(s).split("#")
		if parts.size() == 2:
			rset[int(parts[0])] = true
	for k in _local_extinct:
		if _local_extinct.get(k) == true:
			var p2: PackedStringArray = str(k).split("#")
			if p2.size() == 2:
				rset[int(p2[0])] = true
	for rk0 in WorldMemory.get_region_keys_with_animal_deaths():
		rset[rk0] = true
	var all_r: Array[int] = []
	for z in rset:
		all_r.append(int(z))
	all_r.sort()
	for rk2 in all_r:
		if SettlementMemory.is_region_in_permanently_abandoned_settlement(rk2):
			continue
		_process_one_region_species(world, tick0, rk2, int(Animal.Type.RABBIT))
		_process_one_region_species(world, tick0, rk2, int(Animal.Type.DEER))


func _process_one_region_species(world: World, tick0: int, rk2: int, sp0: int) -> void:
	var key: String = _rsk(rk2, sp0)
	var live: int = _live_count_in_region(animals, world, rk2, sp0)
	var scar: int = int(WorldPersistence.get_region_persistence(rk2).get("scar_level", 0))
	var last_d: int = WorldMemory.get_last_animal_death_tick_in_region(rk2, sp0)
	var ini: int = int(_initial_placed.get(key, 0))
	var deaths: int = WorldMemory.get_animal_death_count_in_region(rk2, sp0)
	var had_ever: bool = (ini > 0) or (deaths > 0)
	if live > 0:
		if _local_extinct.get(key) == true:
			_local_extinct.erase(key)
		## 2) suppression: scar >= 2 => no reproduction
		if scar >= 2:
			return
		## 1) reproduction: need 2+ and no [WorldMemory] death in (rk, sp) for [const REPRO_TICKS]
		if live < 2:
			return
		if last_d >= 0 and (tick0 - last_d) < REPRO_TICKS:
			return
		## At most one system birth per (rk, sp) per [const REPRO_TICKS] (stable herd growth, not a burst)
		if _last_system_spawn_tick.has(key) and (tick0 - int(_last_system_spawn_tick[key])) < REPRO_TICKS:
			return
		_spawn_from_population_system(world, rk2, sp0)
		return
	## live == 0
	if not had_ever:
		return
	_local_extinct[key] = true
	## 3) extinction: no recovery while scar > 1
	if scar > 1:
		return
	## Recovery: scar <= 1, re-seed +1
	if _spawn_from_population_system(world, rk2, sp0):
		_local_extinct.erase(key)


func get_animal_count_by_type(animal_type: int) -> int:
	var count: int = 0
	for animal in animals:
		if is_instance_valid(animal) and animal.animal_type == animal_type:
			count += 1
	return count


func describe() -> String:
	var rabbits: int = get_animal_count_by_type(Animal.Type.RABBIT)
	var deer: int = get_animal_count_by_type(Animal.Type.DEER)
	return "Animals: %d rabbits, %d deer (total %d / %d)" % [rabbits, deer, animals.size(), MAX_ANIMALS]
