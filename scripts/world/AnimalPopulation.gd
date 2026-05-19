## Deterministic regional ecology: pressure + local food availability gate mortality (no RNG).
## Called from [AnimalSpawner] on population check cadence — not a per-frame loop.
class_name AnimalPopulation
extends Object

const _WM = preload("res://autoloads/WorldMemory.gd")

## 0.0 = no usable vegetation in scan; 1.0 = all scanned tiles are forest/plains with forage signal.
static func get_food_availability_at(world: World, tile: Vector2i) -> float:
	if world == null or world.data == null or not world.data.in_bounds(tile.x, tile.y):
		return 0.0
	var r: int = 2
	var good: int = 0
	var total: int = 0
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var x: int = tile.x + dx
			var y: int = tile.y + dy
			if not world.data.in_bounds(x, y):
				continue
			total += 1
			var bio: int = int(world.data.get_biome(x, y))
			if bio != int(Biome.Type.FOREST) and bio != int(Biome.Type.PLAINS):
				continue
			good += 1
			if int(world.data.forage_at(x, y)) > 0:
				good += 1
	if total <= 0:
		return 0.0
	return clampf(float(good) / float(total), 0.0, 1.0)


static func _pressure_for_animal_at(world: World, tile: Vector2i) -> float:
	var rk: int = _WM._region_key(tile.x, tile.y)
	var intent_mem: Node = MemoryManager.get_intent_memory()
	if intent_mem == null:
		return 0.5
	var pr: float = float(intent_mem.global_pressure)
	var ckr: int = SettlementMemory.get_center_region_for_region(rk)
	if ckr >= 0 and intent_mem.settlement_pressure.has(ckr):
		pr = maxf(pr, float(intent_mem.settlement_pressure[ckr]))
	return clampf(pr, 0.0, 1.0)


## Only applies when [pressure] is extreme AND local forage/vegetation is nearly gone (deterministic cull).
static func apply_regional_mortality(spawner: AnimalSpawner, world: World) -> void:
	if spawner == null or world == null or not is_instance_valid(world) or world.data == null:
		return
	for animal in spawner.animals:
		if animal == null or not is_instance_valid(animal):
			continue
		if not (animal is Animal):
			continue
		var t: Vector2i = (animal as Animal).tile_pos
		var p: float = _pressure_for_animal_at(world, t)
		var food: float = get_food_availability_at(world, t)
		if p > 0.85 and food < 0.2:
			(animal as Animal).die()
