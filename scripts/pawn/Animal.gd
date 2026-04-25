## Animal.gd — Simple animal entity (rabbit, deer) with movement, flocking, breeding.
## Animals spawn naturally, move around, breed when well-fed, and can be hunted.
extends Node2D
class_name Animal

enum Type { RABBIT, DEER }

const SPECIES_DATA: Dictionary = {
	Type.RABBIT: {
		"name": "Rabbit",
		"color": Color("#d4a574"),
		"speed": 40.0,       # pixels per second
		"size": 4.0,         # sprite radius
		"meat_amount": 2,
		"vision_range": 60.0,
		"breeding_cooldown": 600,  # ticks between breeding
		"breeding_hunger_threshold": 60.0,  # must be this well-fed to breed
	},
	Type.DEER: {
		"name": "Deer",
		"color": Color("#8b5a2b"),
		"speed": 60.0,
		"size": 6.0,
		"meat_amount": 5,
		"vision_range": 100.0,
		"breeding_cooldown": 900,
		"breeding_hunger_threshold": 70.0,
	},
}

@export var animal_type: Type = Type.RABBIT

var tile_pos: Vector2i = Vector2i.ZERO
var world_pos: Vector2 = Vector2.ZERO
var hunger: float = 100.0  # 0..100, higher is better
var age_ticks: int = 0
var breeding_cooldown: int = 0
var _world: World = null
var _target_tile: Vector2i = Vector2i.ZERO
var _current_path: Array[Vector2i] = []
var _path_index: int = 0
var _nearby_animals: Array[Animal] = []
var _dead: bool = false

func _ready() -> void:
	add_to_group("animals")
	queue_redraw()


func bind(p_animal_type: Type, p_tile: Vector2i, p_world: World) -> void:
	animal_type = p_animal_type
	tile_pos = p_tile
	world_pos = p_world.tile_to_world(tile_pos)
	position = world_pos
	_world = p_world
	hunger = 100.0
	age_ticks = 0
	breeding_cooldown = 0
	# Once per instance: do not connect from _process (would duplicate every frame).
	if not GameManager.game_tick.is_connected(_on_game_tick):
		GameManager.game_tick.connect(_on_game_tick)


func _physics_process(delta: float) -> void:
	if _dead or _world == null:
		return
	
	# Move along current path
	if not _current_path.is_empty() and _path_index < _current_path.size():
		var target_world: Vector2 = _world.tile_to_world(_current_path[_path_index])
		var direction: Vector2 = (target_world - position).normalized()
		var spec = SPECIES_DATA[animal_type]
		position += direction * spec.speed * delta
		
		# Check if reached tile
		if position.distance_to(target_world) < spec.size * 2:
			tile_pos = _current_path[_path_index]
			position = target_world
			_path_index += 1
			if _path_index >= _current_path.size():
				_current_path.clear()
				_path_index = 0


func _exit_tree() -> void:
	if GameManager.game_tick.is_connected(_on_game_tick):
		GameManager.game_tick.disconnect(_on_game_tick)


func _on_game_tick(_tick: int) -> void:
	if _dead or _world == null:
		return
	
	# Decay hunger
	hunger = max(0.0, hunger - 0.5)
	age_ticks += 1
	
	# Death from starvation (unchanged timing; does not use [_die] stabilization guard)
	if hunger <= 0.0:
		_apply_death()
		return
	
	# Breeding cooldown
	if breeding_cooldown > 0:
		breeding_cooldown -= 1
	
	# Random action each tick: move, forage, breed, or idle
	var action: int = randi() % 4
	match action:
		0:  # Move (45% chance)
			_wander()
		1:  # Forage/rest (35% chance)
			_forage()
		2:  # Try to breed (15% chance)
			_try_breed()
		3:  # Idle (5% chance)
			pass


func _wander() -> void:
	# Pick a random nearby tile and pathfind to it
	var spec = SPECIES_DATA[animal_type]
	var range_tiles: int = int(spec.vision_range / 8.0)  # Convert to tile distance
	
	var target_x: int = tile_pos.x + randi_range(-range_tiles, range_tiles)
	var target_y: int = tile_pos.y + randi_range(-range_tiles, range_tiles)
	target_x = clampi(target_x, 0, WorldData.WIDTH - 1)
	target_y = clampi(target_y, 0, WorldData.HEIGHT - 1)
	_target_tile = Vector2i(target_x, target_y)
	
	# Simple pathfinding
	_current_path = _world.pathfinder.find_path(tile_pos, _target_tile)
	_path_index = 0


func _forage() -> void:
	# Animals eat forage resources in forest/plains
	var biome: int = _world.data.get_biome(tile_pos.x, tile_pos.y)
	if biome == Biome.Type.FOREST or biome == Biome.Type.PLAINS:
		# Find forage at this location
		var forage_count: int = _world.data.forage_at(tile_pos.x, tile_pos.y)
		if forage_count > 0:
			hunger = min(100.0, hunger + 8.0)
			_world.data.consume_forage(tile_pos.x, tile_pos.y, 1)
	else:
		# Move to find forage
		_wander()


func _try_breed() -> void:
	## Population v1: reproduction is deterministic in [AnimalSpawner] only (no RNG births here).
	pass


## Non-starvation removal (e.g. future hunt wiring). Starvation uses [_apply_death] directly.
func _die() -> void:
	if (
			Main._world_stabilization_until_tick >= 0
			and GameManager.tick_count < Main._world_stabilization_until_tick
	):
		return
	_apply_death()


func _apply_death() -> void:
	_dead = true
	# Drop meat at this tile
	var spec = SPECIES_DATA[animal_type]
	var sp: Stockpile = StockpileManager.find_drop_zone(Item.Type.MEAT, tile_pos, _world.pathfinder)
	if sp != null:
		sp.add_item(Item.Type.MEAT, spec.meat_amount)
		print("[Animal] %s died at (%d,%d), dropped %d meat" % 
			[spec.name, tile_pos.x, tile_pos.y, spec.meat_amount])
	WorldMemory.record_animal_death(
		GameManager.tick_count, tile_pos, int(animal_type), get_species_name()
	)
	remove_from_group("animals")
	queue_free()


func _find_nearby_animals() -> void:
	_nearby_animals.clear()
	var spec = SPECIES_DATA[animal_type]
	var range_sq: float = spec.vision_range * spec.vision_range
	
	for animal in get_tree().get_nodes_in_group("animals"):
		if animal == self or not is_instance_valid(animal):
			continue
		var dist_sq: float = (animal.position - position).length_squared()
		if dist_sq < range_sq:
			_nearby_animals.append(animal)


func _draw() -> void:
	if _dead:
		return
	var spec = SPECIES_DATA[animal_type]
	var color: Color = spec.color
	# Hunger affects color saturation
	var hunger_factor: float = clamp(hunger * 0.01, 0.3, 1.0)
	color = color.lerp(Color.GRAY, 1.0 - hunger_factor)
	draw_circle(Vector2.ZERO, spec.size, color)


func get_species_name() -> String:
	return SPECIES_DATA[animal_type].name
