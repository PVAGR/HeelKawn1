class_name PawnSpawner
extends Node

## Spawns the starting group of pawns. Main drives the lifecycle (spawn order
## relative to world + stockpile placement is important), so this script no
## longer auto-spawns on _ready.
##
## Spawns are restricted to a single connected component when requested, which
## guarantees every pawn can reach the stockpile and pick up jobs on its own
## landmass. Otherwise falls back to any plains/forest tile.

const STARTER_COUNT: int = 5
const MAX_PLACEMENT_ATTEMPTS: int = 2000

const FIRST_NAMES: Array[String] = [
	"Aldric", "Brenna", "Cormac", "Dena", "Elric", "Fiona", "Garrick",
	"Hilda", "Ivor", "Jora", "Kenan", "Lira", "Morven", "Nessa",
	"Osric", "Petra", "Quinn", "Rhea", "Silas", "Tess", "Ulric",
	"Vera", "Wren", "Xara", "Yorick", "Zella",
]

const PAWN_COLORS: Array[Color] = [
	Color("#29b6f6"),  # light blue
	Color("#ef5350"),  # red
	Color("#ffee58"),  # yellow
	Color("#ab47bc"),  # purple
	Color("#26a69a"),  # teal
	Color("#ff7043"),  # orange
	Color("#ec407a"),  # pink
]

const APPAREL_COLORS: Array[Color] = [
	Color("#5d7ea8"),
	Color("#6d9259"),
	Color("#9d6f49"),
	Color("#725e9a"),
	Color("#aa5454"),
]

const HAIR_COLORS: Array[Color] = [
	Color("#2b1e17"),
	Color("#5f4630"),
	Color("#9b6b3a"),
	Color("#d5b06f"),
	Color("#3f3128"),
]

const SPAWNABLE_BIOMES: Array[int] = [Biome.Type.PLAINS, Biome.Type.FOREST]

@export var pawn_scene: PackedScene

var pawns: Array[Pawn] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()


## Free existing pawns (releasing any claimed jobs) and spawn a fresh set.
## required_component_id defaults to -1 (no constraint); pass a component id
## to confine spawning to a specific landmass (e.g. the one containing the
## stockpile).
func respawn(world: World, required_component_id: int = -1) -> void:
	clear_pawns()
	spawn_starters(world, required_component_id)


func clear_pawns() -> void:
	for p in pawns:
		if p != null and is_instance_valid(p):
			p.release_job_if_any()
			p.queue_free()
	pawns.clear()


## Remove a pawn from the spawner (when it dies). Cleans up the reference.
func remove_pawn(pawn: Pawn) -> void:
	pawns.erase(pawn)
	if pawn != null and is_instance_valid(pawn):
		pawn.release_job_if_any()
		pawn.queue_free()


## Dump a needs + skills table for all pawns. Hotkeyed to T by Main.gd.
func print_stats() -> void:
	print("[Stats] --- pawn needs (tick %d) ---" % GameManager.tick_count)
	print("[Stats]   Name               Age  Hunger  Rest   Mood   Carrying          Skills (Fo/Mi/Ch/Bu/Hu)   Tile")
	for p in pawns:
		var d := p.data
		var carry_str: String = "-"
		if d.is_carrying():
			carry_str = "%s x%d" % [Item.name_for(d.carrying), d.carrying_qty]
		var skills_str: String = "%2d/%2d/%2d/%2d/%2d" % [
			d.get_skill_level(PawnData.Skill.FORAGING),
			d.get_skill_level(PawnData.Skill.MINING),
			d.get_skill_level(PawnData.Skill.CHOPPING),
			d.get_skill_level(PawnData.Skill.BUILDING),
			d.get_skill_level(PawnData.Skill.HUNTING),
		]
		print("[Stats]   %-18s %3d  %5.1f   %5.1f  %5.1f  %-16s  %-25s (%d,%d)" %
			[d.display_name, d.age, d.hunger, d.rest, d.mood, carry_str,
			 skills_str, d.tile_pos.x, d.tile_pos.y])


func spawn_starters(world: World, required_component_id: int = -1) -> void:
	var used_tiles: Dictionary = {}
	var placed: int = 0
	for attempt in range(MAX_PLACEMENT_ATTEMPTS):
		if placed >= STARTER_COUNT:
			break
		var tile := Vector2i(
			_rng.randi_range(0, WorldData.WIDTH - 1),
			_rng.randi_range(0, WorldData.HEIGHT - 1)
		)
		if used_tiles.has(tile):
			continue
		var biome: int = world.data.get_biome(tile.x, tile.y)
		if not SPAWNABLE_BIOMES.has(biome):
			continue
		if required_component_id >= 0 and world.pathfinder.component_of(tile) != required_component_id:
			continue
		used_tiles[tile] = true

		var data := PawnData.new()
		data.display_name = _pick_name(used_tiles)
		data.age = _rng.randi_range(18, 55)
		data.gender = _rng.randi_range(0, 1)
		data.tile_pos = tile
		data.color = PAWN_COLORS[placed % PAWN_COLORS.size()]
		data.body_type = _rng.randi_range(PawnData.BodyType.SLIM, PawnData.BodyType.BROAD)
		data.hair_style = _rng.randi_range(PawnData.HairStyle.NONE, PawnData.HairStyle.BUN)
		data.hair_color = HAIR_COLORS[_rng.randi_range(0, HAIR_COLORS.size() - 1)]
		data.apparel_color = APPAREL_COLORS[_rng.randi_range(0, APPAREL_COLORS.size() - 1)]
		
		# Assign 0-2 random traits to this pawn
		_assign_random_traits(data)

		var pawn: Pawn = pawn_scene.instantiate()
		add_child(pawn)
		pawn.bind(data, world.tile_to_world(tile), world)
		pawns.append(pawn)
		placed += 1

		print("[Spawn] #%d %s  tile=(%d,%d) biome=%s" %
			[placed, data.describe(), tile.x, tile.y, Biome.name_for(biome)])

	if placed < STARTER_COUNT:
		if OS.is_debug_build():
			push_warning(
					"[PawnSpawner] Only placed %d / %d pawns (component=%d)" %
					[placed, STARTER_COUNT, required_component_id]
			)


## Place one additional pawn (same rules as `spawn_starters`). Used by
## LivingWorldController after Main has bootstrapped. No-op if placement fails.
## One arrival without RNG: fixed young-adult age, first free name, cosmetic
## indices from tick_seed. Used for generational turnover (v1).
func spawn_generational_pawn(
		world: World,
		tile: Vector2i,
		tick_seed: int
) -> bool:
	if world == null or world.data == null or world.pathfinder == null or pawn_scene == null:
		return false
	if not world.data.in_bounds(tile.x, tile.y):
		return false
	if not SPAWNABLE_BIOMES.has(world.data.get_biome(tile.x, tile.y)):
		return false
	if not world.pathfinder.is_passable(tile):
		return false
	var main_comp: int = world.pathfinder.largest_component_id()
	if main_comp < 0 or world.pathfinder.component_of(tile) != main_comp:
		return false
	for p in pawns:
		if p != null and is_instance_valid(p) and p.data != null and p.data.tile_pos == tile:
			return false
	var data := PawnData.new()
	data.display_name = _pick_name_deterministic()
	data.age = 20 + (int(tick_seed) % 5)
	data.gender = PawnData.Gender.MALE if (int(tick_seed) + pawns.size()) % 2 == 0 else PawnData.Gender.FEMALE
	data.tile_pos = tile
	data.color = PAWN_COLORS[pawns.size() % PAWN_COLORS.size()]
	data.body_type = (int(tick_seed) + pawns.size()) % 3
	var hs: int = int(int(tick_seed) / 3.0) % 4
	data.hair_style = hs
	data.hair_color = HAIR_COLORS[(int(tick_seed) + 1) % HAIR_COLORS.size()]
	data.apparel_color = APPAREL_COLORS[(int(tick_seed) + 2) % APPAREL_COLORS.size()]
	var pawn: Pawn = pawn_scene.instantiate() as Pawn
	add_child(pawn)
	pawn.bind(data, world.tile_to_world(tile), world)
	pawns.append(pawn)
	print("[Spawn] generational: %s  tile=(%d,%d) age=%d" % [
		data.display_name, tile.x, tile.y, data.age,
	])
	return true


## Deterministic: alias for [method spawn_generational_pawn] (Settlement Rebirth, etc.).
func spawn_pawn_at_tile(world: World, tile: Vector2i, tick_seed: int) -> bool:
	return spawn_generational_pawn(world, tile, tick_seed)


## Same as [method spawn_pawn_at_tile].
func spawn_pawn_at(world: World, tile: Vector2i, tick_seed: int) -> bool:
	return spawn_pawn_at_tile(world, tile, tick_seed)


func _pick_name_deterministic() -> String:
	var used: Dictionary = {}
	for p in pawns:
		if p != null and p.data != null and p.data.display_name != "":
			used[p.data.display_name] = true
	for n in FIRST_NAMES:
		if not used.has(n):
			return n
	return "Settler-%d" % pawns.size()


func spawn_pawn() -> void:
	var main_n: Node = get_parent()
	if main_n == null:
		return
	var world: World = main_n.get_node_or_null("World") as World
	if world == null or world.data == null or world.pathfinder == null:
		return
	var required_component_id: int = world.pathfinder.largest_component_id()
	if required_component_id < 0:
		return
	var used_tiles: Dictionary = {}
	for p in pawns:
		if p != null and is_instance_valid(p) and p.data != null:
			used_tiles[p.data.tile_pos] = true
	for attempt in range(MAX_PLACEMENT_ATTEMPTS):
		var tile := Vector2i(
			_rng.randi_range(0, WorldData.WIDTH - 1),
			_rng.randi_range(0, WorldData.HEIGHT - 1)
		)
		if used_tiles.has(tile):
			continue
		var biome: int = world.data.get_biome(tile.x, tile.y)
		if not SPAWNABLE_BIOMES.has(biome):
			continue
		if world.pathfinder.component_of(tile) != required_component_id:
			continue
		used_tiles[tile] = true
		var data := PawnData.new()
		data.display_name = _pick_name(used_tiles)
		data.age = _rng.randi_range(18, 55)
		data.gender = _rng.randi_range(0, 1)
		data.tile_pos = tile
		data.color = PAWN_COLORS[pawns.size() % PAWN_COLORS.size()]
		data.body_type = _rng.randi_range(PawnData.BodyType.SLIM, PawnData.BodyType.BROAD)
		data.hair_style = _rng.randi_range(PawnData.HairStyle.NONE, PawnData.HairStyle.BUN)
		data.hair_color = HAIR_COLORS[_rng.randi_range(0, HAIR_COLORS.size() - 1)]
		data.apparel_color = APPAREL_COLORS[_rng.randi_range(0, APPAREL_COLORS.size() - 1)]
		_assign_random_traits(data)
		var pawnc: Pawn = pawn_scene.instantiate()
		add_child(pawnc)
		pawnc.bind(data, world.tile_to_world(tile), world)
		pawns.append(pawnc)
		print("[Spawn] living: %s  tile=(%d,%d)" % [data.describe(), tile.x, tile.y])
		return
	if OS.is_debug_build():
		push_warning("[PawnSpawner] spawn_pawn: could not place a pawn")


## Reconstruct one pawn from `PawnData` (e.g. after `PawnData.from_save_dict`). Does
## not check component — caller must ensure the tile is passable.
func spawn_from_data(d: PawnData, world: World) -> void:
	var p: Pawn = pawn_scene.instantiate()
	add_child(p)
	p.bind(d, world.tile_to_world(d.tile_pos), world)
	pawns.append(p)
	print("[Spawn] load: %s @(%d,%d)" % [d.display_name, d.tile_pos.x, d.tile_pos.y])


## Pick a name we haven't used yet this run.
func _pick_name(used_tiles: Dictionary) -> String:
	var used_names: Dictionary = {}
	for p in pawns:
		used_names[p.data.display_name] = true
	var available: Array[String] = []
	for n in FIRST_NAMES:
		if not used_names.has(n):
			available.append(n)
	if available.is_empty():
		return "Settler-%d" % used_tiles.size()
	return available[_rng.randi() % available.size()]


## Assign 0-2 random traits to a pawn. Called at spawn time.
func _assign_random_traits(pawn_data: PawnData) -> void:
	var num_traits: int = _rng.randi_range(0, 2)  # 0, 1, or 2 traits
	var trait_types: Array = Trait.Type.values()
	var assigned: Dictionary = {}
	
	for _i in range(num_traits):
		if trait_types.is_empty():
			break
		var trait_type = trait_types[_rng.randi() % trait_types.size()]
		# Avoid duplicate traits
		if not assigned.has(trait_type):
			assigned[trait_type] = true
			var trait_item := Trait.new(trait_type)
			pawn_data.add_trait(trait_item)
			print("[Spawn] trait: %s -> %s" % [pawn_data.display_name, trait_item.display_name])

