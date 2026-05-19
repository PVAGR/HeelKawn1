class_name PawnSpawner
extends Node

## Spawns the starting group of pawns. Main drives the lifecycle (spawn order
## relative to world + stockpile placement is important), so this script no
## longer auto-spawns on _ready.
##
## Spawns are restricted to a single connected component when requested, which
## guarantees every pawn can reach the stockpile and pick up jobs on its own
## landmass. Otherwise falls back to any plains/forest tile.

# PERFORMANCE: SpatialGrid integration for O(1) neighbor queries
@onready var _spatial_grid: Node = get_node_or_null("/root/SpatialGrid")

const STARTER_COUNT: int = 18
const MOBILE_STARTER_COUNT: int = 8
const MOBILE_LOW_END_STARTER_COUNT: int = 6
const MAX_PLACEMENT_ATTEMPTS: int = 2000

const FIRST_NAMES: Array[String] = [
	"Aldric", "Brenna", "Cormac", "Dena", "Elric", "Fiona", "Garrick",
	"Hilda", "Ivor", "Jora", "Kenan", "Lira", "Morven", "Nessa",
	"Osric", "Petra", "Quinn", "Rhea", "Silas", "Tess", "Ulric",
	"Vera", "Wren", "Xara", "Yorick", "Zella",
]
const FIRST_NAMES_NORDIC: Array[String] = [
	"Aldric", "Brenna", "Cormac", "Dena", "Elric", "Fiona", "Garrick",
	"Hilda", "Ivor", "Jora", "Kenan", "Lira", "Morven", "Nessa",
	"Osric", "Petra", "Quinn", "Rhea", "Silas", "Tess", "Ulric",
	"Vera", "Wren", "Xara", "Yorick", "Zella",
]
const FIRST_NAMES_LATIN: Array[String] = [
	"Marcus", "Livia", "Titus", "Claudia", "Lucius", "Aurelia", "Gaius",
	"Sabina", "Flavius", "Julia", "Caius", "Octavia", "Cassius", "Drusa",
	"Felix", "Marcia", "Quintus", "Rufina", "Severus", "Valeria",
]
const FIRST_NAMES_HIGHLAND: Array[String] = [
	"Alastair", "Brigid", "Callum", "Deirdre", "Ewan", "Fiona", "Gregor",
	"Isla", "Kieran", "Moira", "Niall", "Rowan", "Sorcha", "Torin",
	"Una", "Keir", "Maeve", "Tavish", "Iona", "Brodie",
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

@onready var SpatialManager = get_node_or_null("/root/SpatialManager") # ARCHITECT T006

var pawns: Array[HeelKawnian] = []

# OPTIMIZATION: pawn_id → pawn instance dictionary for O(1) lookup
var _pawn_by_id: Dictionary = {}
var _pawn_by_id_dirty: bool = true
var _next_pawn_id: int = 1

## Return the cached pawn registry. This is the preferred way to iterate all pawns
## instead of get_nodes_in_group("pawns"), which traverses the entire scene tree.
## The array is maintained on spawn/death — no per-tick allocation.
func get_all_pawns() -> Array[HeelKawnian]:
	_prune_invalid_pawns()
	return pawns


func get_pawns() -> Array[HeelKawnian]:
	_prune_invalid_pawns()
	var out: Array[HeelKawnian] = []
	out.append_array(pawns)
	return out


func get_alive_pawns() -> Array[HeelKawnian]:
	_prune_invalid_pawns()
	var alive: Array[HeelKawnian] = []
	for p in pawns:
		if p != null and is_instance_valid(p) and p.data != null and not bool(p.data.is_dead):
			alive.append(p)
	return alive


## OPTIMIZATION: Get pawn by ID in O(1) time
func get_pawn_by_id(pawn_id: int) -> HeelKawnian:
	if _pawn_by_id_dirty:
		_rebuild_pawn_dict()
	return _pawn_by_id.get(pawn_id, null)

## OPTIMIZATION: Rebuild pawn dictionary only when pawns change
func _rebuild_pawn_dict() -> void:
	_pawn_by_id.clear()
	for p in pawns:
		if p != null and p.data != null:
			_pawn_by_id[int(p.data.id)] = p
	_pawn_by_id_dirty = false

## OPTIMIZATION: Mark pawn dict as dirty (call when pawns spawn/despawn)
func invalidate_pawn_dict() -> void:
	_pawn_by_id_dirty = true


func _prune_invalid_pawns() -> void:
	var changed: bool = false
	var i: int = pawns.size() - 1
	while i >= 0:
		var p: HeelKawnian = pawns[i]
		if p == null or not is_instance_valid(p):
			pawns.remove_at(i)
			changed = true
		i -= 1
	if changed:
		invalidate_pawn_dict()


## Static: find the PawnSpawner and return its cached pawn list.
## Returns empty array if PawnSpawner not found (e.g. during early boot).
## Use this from autoloads that don't have a direct reference to PawnSpawner.
## Caches the spawner reference after first lookup to avoid repeated group queries.
static var _cached_spawner: PawnSpawner = null

static func find_pawns() -> Array[HeelKawnian]:
	if _cached_spawner != null and is_instance_valid(_cached_spawner):
		_cached_spawner._prune_invalid_pawns()
		return _cached_spawner.pawns
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return []
	var spawner_node: Node = tree.get_first_node_in_group("pawn_spawner")
	if spawner_node == null:
		return []
	var ps: PawnSpawner = spawner_node as PawnSpawner
	if ps == null:
		return []
	_cached_spawner = ps
	ps._prune_invalid_pawns()
	return ps.pawns


static func find_alive_pawns() -> Array[HeelKawnian]:
	if _cached_spawner != null and is_instance_valid(_cached_spawner):
		return _cached_spawner.get_alive_pawns()
	find_pawns()
	if _cached_spawner != null and is_instance_valid(_cached_spawner):
		return _cached_spawner.get_alive_pawns()
	return []

## OPTIMIZATION: Static O(1) pawn lookup by ID
static func find_pawn_by_id(pawn_id: int) -> HeelKawnian:
	if _cached_spawner != null and is_instance_valid(_cached_spawner):
		return _cached_spawner.get_pawn_by_id(pawn_id)
	# Fallback to slow path if cache not warm
	var pawns: Array[HeelKawnian] = find_pawns()
	for p in pawns:
		if p != null and p.data != null and int(p.data.id) == pawn_id:
			return p
	return null


func _ready() -> void:
	add_to_group("pawn_spawner")
	if pawn_scene == null:
		print("[ERROR] PawnSpawner: pawn_scene is null - check Main.tscn configuration")
	elif OS.is_debug_build():
		print("[INFO] PawnSpawner: pawn_scene loaded successfully: ", pawn_scene.resource_path)


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
			if SpatialManager != null and p.data != null: # ARCHITECT T006
				SpatialManager.unregister_entity(int(p.data.id))
			p.queue_free()
	pawns.clear()


## Remove a pawn from the spawner (when it dies). Cleans up the reference.
func remove_pawn(pawn: HeelKawnian) -> void:
	pawns.erase(pawn)
	invalidate_pawn_dict()  # OPTIMIZATION: Mark dict dirty
	if pawn != null and is_instance_valid(pawn):
		pawn.release_job_if_any()
		if SpatialManager != null and pawn.data != null: # ARCHITECT T006
			SpatialManager.unregister_entity(int(pawn.data.id))
		pawn.queue_free()


func pawn_data_for_id(pid: int) -> HeelKawnianData:
	if pid < 0:
		return null
	for p in pawns:
		if p != null and is_instance_valid(p) and p.data != null and p.data.id == pid:
			return p.data
	return null


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
			d.get_skill_level(HeelKawnianData.Skill.FORAGING),
			d.get_skill_level(HeelKawnianData.Skill.MINING),
			d.get_skill_level(HeelKawnianData.Skill.CHOPPING),
			d.get_skill_level(HeelKawnianData.Skill.BUILDING),
			d.get_skill_level(HeelKawnianData.Skill.HUNTING),
		]
		print("[Stats]   %-18s %3d  %5.1f   %5.1f  %5.1f  %-16s  %-25s (%d,%d)" %
			[d.display_name, d.age, d.hunger, d.rest, d.mood, carry_str,
			skills_str, d.tile_pos.x, d.tile_pos.y])


func spawn_starters(world: World, required_component_id: int = -1) -> void:
	var target_starter_count: int = STARTER_COUNT
	var mobile_runtime: bool = OS.has_feature("mobile") or DisplayServer.is_touchscreen_available()
	if mobile_runtime:
		target_starter_count = MOBILE_STARTER_COUNT
		var vp: Vector2i = DisplayServer.window_get_size()
		if vp.x <= 1280 or vp.y <= 720:
			target_starter_count = MOBILE_LOW_END_STARTER_COUNT
	# Use the largest connected component if no specific component required
	var target_component_id: int = required_component_id
	if target_component_id < 0:
		target_component_id = world.pathfinder.largest_component_id()
	
	var used_tiles: Dictionary = {}
	var placed: int = 0
	
	# Generate candidate tiles distributed across the component
	var candidate_tiles: Array[Vector2i] = []
	var world_rng: RandomNumberGenerator = WorldRNG.rng_for(&"pawn_spawn_candidates")
	
	# Sample enough passable candidates for the current spawn target.
	var candidate_sample_count: int = maxi(20, target_starter_count * 2)
	for i in range(candidate_sample_count):
		var attempts: int = 0
		while attempts < 100:
			var tile := Vector2i(
				world_rng.randi_range(0, WorldData.WIDTH - 1),
				world_rng.randi_range(0, WorldData.HEIGHT - 1),
			)
			attempts += 1
			
			# Check if tile is in target component and spawnable
			if world.pathfinder.component_of(tile) != target_component_id:
				continue
			var biome: int = world.data.get_biome(tile.x, tile.y)
			if not SPAWNABLE_BIOMES.has(biome):
				continue
			
			candidate_tiles.append(tile)
			break
	
	# Place each pawn using pawn-specific RNG for determinism
	var min_spawn_distance: int = 15
	if mobile_runtime:
		min_spawn_distance = 9
	for pawn_id in range(target_starter_count):
		if pawn_id >= candidate_tiles.size():
			break  # Not enough candidates for all pawns
		
		var pawn_rng: RandomNumberGenerator = WorldRNG.rng_for("pawn_spawn_" + str(pawn_id))
		var best_tile: Vector2i = candidate_tiles[pawn_id % candidate_tiles.size()]
		
		# Try to find a tile at least N tiles away from other pawns
		var found_tile: bool = false
		for attempt in range(50):
			var test_tile := Vector2i(
				pawn_rng.randi_range(maxi(0, best_tile.x - 15), mini(WorldData.WIDTH - 1, best_tile.x + 15)),
				pawn_rng.randi_range(maxi(0, best_tile.y - 15), mini(WorldData.HEIGHT - 1, best_tile.y + 15)),
			)
			
			# Check if this tile is valid and far enough from other pawns
			if world.pathfinder.component_of(test_tile) != target_component_id:
				continue
			var biome: int = world.data.get_biome(test_tile.x, test_tile.y)
			if not SPAWNABLE_BIOMES.has(biome):
				continue
			
			# Check distance from already placed pawns
			var too_close: bool = false
			for other_tile in used_tiles.keys():
				var distance: int = abs(test_tile.x - other_tile.x) + abs(test_tile.y - other_tile.y)
				if distance < min_spawn_distance:
					too_close = true
					break
			
			if not too_close:
				best_tile = test_tile
				found_tile = true
				break
		
		used_tiles[best_tile] = true

		var data := HeelKawnianData.new()
		# DEAD BRAIN REVIVED: NameGenerator generates culture-aware names
		if NameGenerator != null:
			data.display_name = NameGenerator.generate_full_name(int(data.id), "nordic", data.gender)
		else:
			data.display_name = _pick_name(used_tiles, pawn_rng)
		data.age = pawn_rng.randi_range(18, 55)
		data.gender = pawn_rng.randi_range(0, 1)
		data.tile_pos = best_tile
		data.color = PAWN_COLORS[placed % PAWN_COLORS.size()]
		data.body_type = pawn_rng.randi_range(HeelKawnianData.BodyType.SLIM, HeelKawnianData.BodyType.BROAD)
		data.hair_style = pawn_rng.randi_range(HeelKawnianData.HairStyle.NONE, HeelKawnianData.HairStyle.BUN)
		data.hair_color = HAIR_COLORS[pawn_rng.randi_range(0, HAIR_COLORS.size() - 1)]
		data.apparel_color = APPAREL_COLORS[pawn_rng.randi_range(0, APPAREL_COLORS.size() - 1)]
		_assign_random_traits(data, pawn_rng)
		
		# DORMANT WORLD: First-generation pawns are pioneers
		data.is_pioneer = true
		data.pioneer_ticks_remaining = 5000
		# PHASE 4: Assign heterogeneous profession (NOT all farmers!)
		_assign_heterogeneous_profession(data, pawn_rng)

		var bloodline_sys: Node = get_node_or_null("/root/SocialManager")
		if bloodline_sys != null and bloodline_sys.has_method("create_bloodline"):
			var bloodline_name: String = "Bloodline_%s" % str(data.id)
			var result: Variant = bloodline_sys.callv("create_bloodline", [data.id, bloodline_name])
			if typeof(result) == TYPE_INT:
				data.bloodline_id = result

		var pawn: HeelKawnian = pawn_scene.instantiate() as HeelKawnian
		pawn.data = data
		pawn.position = world.tile_to_world(best_tile)
		pawn._world = world
		add_child(pawn)
		pawns.append(pawn)
		invalidate_pawn_dict()  # OPTIMIZATION: Mark dict dirty
		HeelKawnianData.register_pawn_data(data)
		if SpatialManager != null: # ARCHITECT T006
			SpatialManager.register_entity(int(data.id), "pawn", data.tile_pos)
		placed += 1

		var kin: Node = get_node_or_null("/root/SocialManager")
		if kin != null and kin.has_method("add_person"):
			kin.call("add_person", data.id, {"display_name": data.display_name, "age": data.age, "gender": data.gender})

	if placed < target_starter_count and OS.is_debug_build():
		push_warning(
			"[PawnSpawner] Only placed %d / %d pawns (component=%d)" %
			[placed, target_starter_count, required_component_id]
		)


## Place one additional pawn (same rules as `spawn_starters`). Used by
## LivingWorldController after Main has bootstrapped. No-op if placement fails.
## One arrival without RNG: fixed young-adult age, first free name, cosmetic
## indices from tick_seed. Used for generational turnover (v1).
func spawn_generational_pawn(
		   world: World,
		   tile: Vector2i,
		   tick_seed: int,
		   parent_id: int = -1,
		   household_id: int = -1,
		   settlement_context: Dictionary = {},
		   birth_kind: String = "generational"
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
	var parent_data: HeelKawnianData = null
	if parent_id >= 0:
		parent_data = pawn_data_for_id(parent_id)
		if parent_data != null:
			parent_data.ensure_soul_identity()
	var data := HeelKawnianData.new()
	var naming_convention: String = "nordic"
	var taboo_jobs: Array = []
	var preferred_branch: String = ""
	if not settlement_context.is_empty():
		var tradition_v: Variant = settlement_context.get("tradition", {})
		if tradition_v is Dictionary:
			var tradition: Dictionary = tradition_v as Dictionary
			naming_convention = str(tradition.get("naming_convention", "nordic")).to_lower()
			taboo_jobs = (tradition.get("taboo_jobs", []) as Array).duplicate(true)
			preferred_branch = str(tradition.get("preferred_tech_branch", "")).to_lower()
	# DEAD BRAIN REVIVED: NameGenerator for birth names with culture awareness
	if NameGenerator != null:
		data.display_name = NameGenerator.generate_full_name(int(data.id), naming_convention, data.gender)
	else:
		data.display_name = _pick_name_deterministic(naming_convention)
	data.age = 20 + (int(tick_seed) % 5)
	data.gender = HeelKawnianData.Gender.MALE if (int(tick_seed) + pawns.size()) % 2 == 0 else HeelKawnianData.Gender.FEMALE
	data.tile_pos = tile
	data.color = PAWN_COLORS[pawns.size() % PAWN_COLORS.size()]
	data.body_type = (int(tick_seed) + pawns.size()) % 3
	var hs: int = int(int(tick_seed) / 3.0) % 4
	data.hair_style = hs
	data.hair_color = HAIR_COLORS[(int(tick_seed) + 1) % HAIR_COLORS.size()]
	data.apparel_color = APPAREL_COLORS[(int(tick_seed) + 2) % APPAREL_COLORS.size()]
	
	# PHASE 4: Assign heterogeneous profession (NOT all farmers!)
	# Children have 70% chance to inherit parent's profession, 30% random
	if parent_data != null and parent_data.current_profession != HeelKawnianData.Profession.NONE:
		_inherit_profession_from_parents(data, parent_data, null, GameManager.tick_count)
	else:
		_assign_heterogeneous_profession(data, WorldRNG.rng_for(&"pawn_profession_assignment"))
	
	if parent_data != null:
		data.lineage_id = parent_data.unique_id
	var bloodline_sys_birth: Node = get_node_or_null("/root/SocialManager")
	if bloodline_sys_birth != null and bloodline_sys_birth.has_method("assign_birth_bloodline"):
		var spec_hint: String = parent_data.highest_affinity_skill() if parent_data != null else data.highest_affinity_skill()
		data.bloodline_id = int(bloodline_sys_birth.call("assign_birth_bloodline", data.id, data.display_name, parent_id, -1, spec_hint))
	if not settlement_context.is_empty():
		var center_region: int = int(settlement_context.get("center_region", -1))
		var culture_name: String = str(settlement_context.get("culture_name", ""))
		if center_region >= 0:
			var rep: float = float(CulturalMemory.get_region_reputation(center_region))
			data.settlement_reputation[str(center_region)] = rep
			# Record birth settlement for lineage tracking and cultural revival naming
			data.birth_settlement = center_region  # Already int, matches HeelKawnianData type
		if not culture_name.is_empty():
			data.cultural_affinity[culture_name] = 100.0
	var taboo_job_names: Array[String] = []
	for j_any in taboo_jobs:
		var j_str: String = str(j_any).strip_edges().to_upper()
		if not j_str.is_empty() and not taboo_job_names.has(j_str):
			taboo_job_names.append(j_str)
	data.set_meta("tradition_taboo_jobs", taboo_job_names)
	data.set_meta("tradition_preferred_tech_branch", preferred_branch)
	data.set_meta("tradition_mood_bonus", 4.0)
	data.set_meta("tradition_mood_penalty", -6.0)
	var pawn: HeelKawnian = pawn_scene.instantiate() as HeelKawnian
	pawn.data = data
	pawn.position = world.tile_to_world(tile)
	pawn._world = world
	add_child(pawn)
	pawns.append(pawn)
	invalidate_pawn_dict()  # OPTIMIZATION: Mark dict dirty
	HeelKawnianData.register_pawn_data(data)
	if SpatialManager != null: # ARCHITECT T006
		SpatialManager.register_entity(int(data.id), "pawn", data.tile_pos)
	
	# PERFORMANCE: Register in SpatialGrid for O(1) neighbor queries
	if _spatial_grid != null:
		_spatial_grid.insert(pawn, data.tile_pos)
	
	WorldMemory.record_event({
		"type": "pawn_birth",
		"birth_kind": str(birth_kind),  # Ensure String type
		"tick": GameManager.tick_count,
		"pawn_id": int(data.id),
		"pawn_name": data.display_name,
		"tile": {"x": tile.x, "y": tile.y},
		"region": WorldMemory._region_key(tile.x, tile.y),
		"birth_settlement": str(data.birth_settlement),  # Ensure String type
	})
	
	# TEXT-RICH: Show birth notification
	var event_overlay: Node = get_node_or_null("/root/EventNotificationOverlay")
	if event_overlay != null and event_overlay.has_method("notify_birth"):
		var settlement_name: String = "the wilderness"
		if data.birth_settlement >= 0:
			# Look up settlement name from SettlementMemory
			if SettlementMemory != null and SettlementMemory.has_method("get"):
				var settlements: Variant = SettlementMemory.get("settlements")
				if settlements != null and settlements is Array:
					for s in settlements:
						if s is Dictionary and int(s.get("center_region", -1)) == data.birth_settlement:
							settlement_name = str(s.get("name", "Unnamed"))
							break
		event_overlay.call("notify_birth", data.display_name, settlement_name)
	if str(birth_kind) == "rebirth":
		WorldMemory.record_event({
			"type": "generational_birth",
			"birth_kind": str(birth_kind),
			"tick": GameManager.tick_count,
			"pawn_id": int(data.id),
			"pawn_name": data.display_name,
			"tile": {"x": tile.x, "y": tile.y},
			"region": WorldMemory._region_key(tile.x, tile.y),
			"center_region": int(settlement_context.get("center_region", -1)),
			"culture_name": str(settlement_context.get("culture_name", "")),
			"birth_settlement": str(data.birth_settlement),
		})
	var kin: Node = get_node_or_null("/root/SocialManager")
	if kin != null:
		if kin.has_method("add_person"):
			kin.call("add_person", data.id, {"display_name": data.display_name, "age": data.age, "gender": data.gender})
		if parent_id != -1 and kin.has_method("add_parent_child"):
			kin.call("add_parent_child", parent_id, data.id)
		if household_id != -1 and kin.has_method("add_household_member"):
			kin.call("add_household_member", data.id, household_id)
	return true


## Deterministic: alias for [method spawn_generational_pawn] (Settlement Rebirth, etc.).
func spawn_pawn_at_tile(
		world: World,
		tile: Vector2i,
		tick_seed: int,
		settlement_context: Dictionary = {},
		birth_kind: String = "generational"
) -> bool:
	return spawn_generational_pawn(world, tile, tick_seed, -1, -1, settlement_context, birth_kind)


## Same as [method spawn_pawn_at_tile].
func spawn_pawn_at(
		world: World,
		tile: Vector2i,
		tick_seed: int,
		settlement_context: Dictionary = {},
		birth_kind: String = "generational"
) -> bool:
	return spawn_pawn_at_tile(world, tile, tick_seed, settlement_context, birth_kind)


func _pick_name_deterministic(naming_convention: String = "nordic") -> String:
	var used: Dictionary = {}
	for p in pawns:
		if p != null and p.data != null and p.data.display_name != "":
			used[p.data.display_name] = true
	var pool: Array[String] = _name_pool_for_convention(naming_convention)
	for n in pool:
		if not used.has(n):
			return n
	return "Settler-%d" % pawns.size()


func _name_pool_for_convention(naming_convention: String) -> Array[String]:
	match naming_convention.to_lower():
		"latin":
			return FIRST_NAMES_LATIN
		"highland":
			return FIRST_NAMES_HIGHLAND
		_:
			return FIRST_NAMES_NORDIC


## HETEROGENEOUS PROFESSION ASSIGNMENT
## Assign diverse professions at spawn based on weighted random (deterministic)
## This ensures pawns are NOT all farmers - they're HeelKawnians with diverse roles
func _assign_heterogeneous_profession(data: HeelKawnianData, rng: RandomNumberGenerator) -> void:
	# Weight distribution for starter pawns - diverse community (Phase 6: Added SMITH, HEALER)
	# Builder: 18% (housing pressure relief)
	# Gatherer: 18% (food diversity)
	# Warrior: 15% (defense, hunting)
	# Scholar: 10% (knowledge, research)
	# Trader: 5% (inter-settlement commerce)
	# Smith: 5% (crafting, metalworking) - NEW
	# Healer: 5% (healthcare, medicine) - NEW
	# Farmer: 24% (food baseline)
	var roll: float = rng.randf()

	if roll < 0.18:
		data.current_profession = HeelKawnianData.Profession.BUILDER
	elif roll < 0.36:
		data.current_profession = HeelKawnianData.Profession.GATHERER
	elif roll < 0.51:
		data.current_profession = HeelKawnianData.Profession.WARRIOR
	elif roll < 0.61:
		data.current_profession = HeelKawnianData.Profession.SCHOLAR
	elif roll < 0.66:
		data.current_profession = HeelKawnianData.Profession.TRADER
	elif roll < 0.71:
		data.current_profession = HeelKawnianData.Profession.SMITH
	elif roll < 0.76:
		data.current_profession = HeelKawnianData.Profession.HEALER
	else:
		data.current_profession = HeelKawnianData.Profession.FARMER

	# Grant initial skill XP based on profession (deterministic bonus)
	# Note: Using HeelKawnianData.Skill enum values - FORAGING, MINING, CHOPPING, BUILDING, HUNTING
	match data.current_profession:
		HeelKawnianData.Profession.BUILDER:
			data.add_skill_xp(HeelKawnianData.Skill.BUILDING, 50.0)
		HeelKawnianData.Profession.GATHERER:
			data.add_skill_xp(HeelKawnianData.Skill.FORAGING, 50.0)
			data.add_skill_xp(HeelKawnianData.Skill.HUNTING, 30.0)
		HeelKawnianData.Profession.WARRIOR:
			data.add_skill_xp(HeelKawnianData.Skill.HUNTING, 50.0)
		HeelKawnianData.Profession.SCHOLAR:
			# Scholars get bonus to all skills (no specific research skill exists)
			data.add_skill_xp(HeelKawnianData.Skill.BUILDING, 30.0)
			data.add_skill_xp(HeelKawnianData.Skill.FORAGING, 20.0)
		HeelKawnianData.Profession.TRADER:
			# Traders get balanced skills for versatility
			data.add_skill_xp(HeelKawnianData.Skill.FORAGING, 30.0)
			data.add_skill_xp(HeelKawnianData.Skill.HUNTING, 30.0)
		HeelKawnianData.Profession.SMITH:
			# Smiths get mining and building for metalworking
			data.add_skill_xp(HeelKawnianData.Skill.MINING, 40.0)
			data.add_skill_xp(HeelKawnianData.Skill.BUILDING, 20.0)
		HeelKawnianData.Profession.HEALER:
			# Healers get foraging (herbs) and hunting (precision)
			data.add_skill_xp(HeelKawnianData.Skill.FORAGING, 30.0)
			data.add_skill_xp(HeelKawnianData.Skill.HUNTING, 20.0)
		HeelKawnianData.Profession.FARMER:
			data.add_skill_xp(HeelKawnianData.Skill.FORAGING, 50.0)


## PROFESSION INHERITANCE - children inherit profession tendencies from parents
func _inherit_profession_from_parents(data: HeelKawnianData, parent_a: HeelKawnianData, parent_b: HeelKawnianData, birth_tick: int) -> void:
	# 70% chance to inherit one parent's profession, 30% random
	var rng: RandomNumberGenerator = WorldRNG.rng_for(&"living_inherit_profession")
	var inherit_roll: float = float((birth_tick * 31337) % 1000) / 1000.0  # Deterministic roll
	
	if inherit_roll < 0.70:
		# Inherit from one parent (50/50)
		var parent_prof: int = parent_a.current_profession if (birth_tick % 2 == 0) else parent_b.current_profession
		if parent_prof != HeelKawnianData.Profession.NONE:
			data.current_profession = parent_prof
			# Grant 25 XP in profession-related skill
			match parent_prof:
				HeelKawnianData.Profession.BUILDER:
					data.add_skill_xp(HeelKawnianData.Skill.BUILDING, 25.0)
				HeelKawnianData.Profession.GATHERER, HeelKawnianData.Profession.FARMER:
					data.add_skill_xp(HeelKawnianData.Skill.FORAGING, 25.0)
				HeelKawnianData.Profession.WARRIOR:
					data.add_skill_xp(HeelKawnianData.Skill.HUNTING, 25.0)
				HeelKawnianData.Profession.SCHOLAR:
					data.add_skill_xp(HeelKawnianData.Skill.BUILDING, 15.0)
					data.add_skill_xp(HeelKawnianData.Skill.FORAGING, 10.0)
	else:
		# 30% - random heterogeneous assignment (community needs)
		_assign_heterogeneous_profession(data, rng)


func spawn_pawn() -> void:
	var rng: RandomNumberGenerator = WorldRNG.rng_for(&"living_spawn_v1")
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
			rng.randi_range(0, WorldData.WIDTH - 1),
			rng.randi_range(0, WorldData.HEIGHT - 1)
		)
		if used_tiles.has(tile):
			continue
		var biome: int = world.data.get_biome(tile.x, tile.y)
		if not SPAWNABLE_BIOMES.has(biome):
			continue
		if world.pathfinder.component_of(tile) != required_component_id:
			continue
		used_tiles[tile] = true
		var data := HeelKawnianData.new()
		data.display_name = _pick_name(used_tiles, rng)
		data.age = rng.randi_range(18, 55)
		data.gender = rng.randi_range(0, 1)
		data.tile_pos = tile
		data.color = PAWN_COLORS[pawns.size() % PAWN_COLORS.size()]
		data.body_type = rng.randi_range(HeelKawnianData.BodyType.SLIM, HeelKawnianData.BodyType.BROAD)
		data.hair_style = rng.randi_range(HeelKawnianData.HairStyle.NONE, HeelKawnianData.HairStyle.BUN)
		data.hair_color = HAIR_COLORS[rng.randi_range(0, HAIR_COLORS.size() - 1)]
		data.apparel_color = APPAREL_COLORS[rng.randi_range(0, APPAREL_COLORS.size() - 1)]
		_assign_random_traits(data, rng)
		# HETEROGENEOUS PROFESSION - NOT all farmers!
		_assign_heterogeneous_profession(data, rng)
		var pawnc: HeelKawnian = pawn_scene.instantiate() as HeelKawnian
		pawnc.data = data
		pawnc.position = world.tile_to_world(tile)
		pawnc._world = world
		add_child(pawnc)
		pawns.append(pawnc)
		invalidate_pawn_dict()  # OPTIMIZATION: Mark dict dirty
		HeelKawnianData.register_pawn_data(data)
		if SpatialManager != null: # ARCHITECT T006
			SpatialManager.register_entity(int(data.id), "pawn", data.tile_pos)
		return
	if OS.is_debug_build():
		push_warning("[PawnSpawner] spawn_pawn: could not place a pawn")


## Reconstruct one pawn from `HeelKawnianData` (e.g. after `HeelKawnianData.from_save_dict`). Does
## not check component — caller must ensure the tile is passable.
func spawn_from_data(d: HeelKawnianData, world: World) -> void:
	var p: HeelKawnian = pawn_scene.instantiate() as HeelKawnian
	p.data = d
	p.position = world.tile_to_world(d.tile_pos)
	p._world = world
	add_child(p)
	pawns.append(p)
	invalidate_pawn_dict()  # OPTIMIZATION: Mark dict dirty
	HeelKawnianData.register_pawn_data(d)
	if SpatialManager != null: # ARCHITECT T006
		SpatialManager.register_entity(int(d.id), "pawn", d.tile_pos)


func spawn_child_pawn(
		world: World,
		tile: Vector2i,
		parent_a: HeelKawnianData,
		parent_b: HeelKawnianData,
		birth_tick: int
) -> HeelKawnian:
	if world == null or world.data == null or world.pathfinder == null or pawn_scene == null:
		return null
	var main_comp: int = world.pathfinder.largest_component_id()
	if main_comp < 0:
		return null
	var candidates: Array[Vector2i] = [tile]
	var neigh: Array[Vector2i] = [
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
		Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1),
	]
	for d in neigh:
		candidates.append(tile + d)
	var spawn_tile: Vector2i = Vector2i(-1, -1)
	for t in candidates:
		if not world.data.in_bounds(t.x, t.y):
			continue
		if not SPAWNABLE_BIOMES.has(world.data.get_biome(t.x, t.y)):
			continue
		if not world.pathfinder.is_passable(t):
			continue
		if world.pathfinder.component_of(t) != main_comp:
			continue
		var occupied: bool = false
		for p in pawns:
			if p != null and is_instance_valid(p) and p.data != null and p.data.tile_pos == t:
				occupied = true
				break
		if occupied:
			continue
		spawn_tile = t
		break
	if spawn_tile.x < 0:
		return null
	tile = spawn_tile
	var data := HeelKawnianData.new()
	data.display_name = _pick_name_deterministic()
	data.age = 0
	data.age_years = 0.0
	var morph_mix: int = int((birth_tick + parent_a.id * 13 + parent_b.id * 17) & 0x7FFFFFFF)
	data.gender = HeelKawnianData.Gender.MALE if morph_mix % 2 == 0 else HeelKawnianData.Gender.FEMALE
	data.tile_pos = tile
	data.color = parent_a.color.lerp(parent_b.color, 0.5)
	data.body_type = morph_mix % 3
	data.hair_style = int(morph_mix / 3.0) % 4
	data.hair_color = parent_a.hair_color.lerp(parent_b.hair_color, 0.5)
	data.apparel_color = parent_a.apparel_color.lerp(parent_b.apparel_color, 0.5)
	data.initialize_affinities(birth_tick, parent_a.id, parent_b.id)
	data.parent_a_id = parent_a.id
	data.parent_b_id = parent_b.id
	HeelKawnian._inherit_affinities(data, parent_a, parent_b, birth_tick)
	data.affinity_birth_snapshot = data.affinities.duplicate(true)
	data._initialize_personality(birth_tick, parent_a.id, parent_b.id)
	data._initialize_neural_network()
	
	# PROFESSION INHERITANCE - children tend toward parent professions but with variation
	_inherit_profession_from_parents(data, parent_a, parent_b, birth_tick)
	
	# BLOODLINE ASSIGNMENT - child inherits from both parents
	var bloodline_sys: Node = get_node_or_null("/root/SocialManager")
	if bloodline_sys != null and bloodline_sys.has_method("assign_birth_bloodline"):
		data.bloodline_id = int(bloodline_sys.call("assign_birth_bloodline", data.id, data.display_name, int(parent_a.id), int(parent_b.id), ""))

	# HOUSEHOLD ASSIGNMENT - keep newborns inside a real family unit when possible
	var kinship_sys: Node = get_node_or_null("/root/SocialManager")
	if kinship_sys != null and kinship_sys.has_method("add_to_household"):
		var parent_a_household: int = int(parent_a.data.household_id)
		var parent_b_household: int = int(parent_b.data.household_id)
		var chosen_household: int = -1
		if parent_a_household >= 0:
			chosen_household = parent_a_household
		elif parent_b_household >= 0:
			chosen_household = parent_b_household
		else:
			chosen_household = int(kinship_sys.call("create_household", int(parent_a.id)))
		if chosen_household >= 0:
			data.household_id = chosen_household
			kinship_sys.call("add_to_household", chosen_household, int(data.id))
			if parent_a_household < 0 and chosen_household == parent_b_household:
				kinship_sys.call("add_to_household", chosen_household, int(parent_a.id))
			elif parent_b_household < 0 and chosen_household == parent_a_household:
				kinship_sys.call("add_to_household", chosen_household, int(parent_b.id))
	
	var inbreeding_penalty: float = 0.0
	if bloodline_sys != null and bloodline_sys.has_method("get_inbreeding_penalty"):
		inbreeding_penalty = float(bloodline_sys.call("get_inbreeding_penalty", int(parent_a.id), int(parent_b.id)))
	if inbreeding_penalty > 0.0:
		data.health = clampf(data.health - 35.0 * inbreeding_penalty, 15.0, 100.0)
		data.mood = clampf(data.mood - 20.0 * inbreeding_penalty, 20.0, 100.0)
	for sk in parent_a.skills.keys():
		var inherited: int = int((int(parent_a.skills[sk]) + int(parent_b.skills.get(sk, 0))) * 0.2)
		data.skills[sk] = inherited
	# Generational trauma inheritance: transfer 20-40% of parent trauma to child
	data.parent_id = parent_a.id
	var pc: Node = get_node_or_null("/root/PawnConsciousness")
	if pc != null and pc.has_method("get_trauma_level"):
		var parent_a_trauma: float = float(pc.call("get_trauma_level", int(parent_a.id)))
		var parent_b_trauma: float = float(pc.call("get_trauma_level", int(parent_b.id)))
		var avg_trauma: float = (parent_a_trauma + parent_b_trauma) / 2.0
		var transfer_ratio: float = 0.2 + (absi(birth_tick * 13 + parent_a.id * 7 + parent_b.id * 11) % 21) / 100.0
		transfer_ratio = clampf(transfer_ratio, 0.2, 0.4)
		var child_trauma: float = avg_trauma * transfer_ratio
		data.inherited_trauma["starvation_fear"] = clampf(child_trauma / 100.0, 0.0, 1.0)
		data.inherited_trauma["violence_aversion"] = clampf((child_trauma * 0.8) / 100.0, 0.0, 1.0)
		data.inherited_trauma["loss_grief"] = clampf((child_trauma * 1.2) / 100.0, 0.0, 1.0)
	var pawn: HeelKawnian = pawn_scene.instantiate() as HeelKawnian
	pawn.data = data
	pawn.position = world.tile_to_world(tile)
	pawn._world = world
	add_child(pawn)
	pawns.append(pawn)
	invalidate_pawn_dict()  # OPTIMIZATION: Mark dict dirty
	HeelKawnianData.register_pawn_data(data)
	if SpatialManager != null: # ARCHITECT T006
		SpatialManager.register_entity(int(data.id), "pawn", data.tile_pos)
	parent_a.children_count += 1
	parent_b.children_count += 1
	var cid: int = int(data.id)
	if not parent_a.children_ids.has(cid):
		parent_a.children_ids.append(cid)
	if not parent_b.children_ids.has(cid):
		parent_b.children_ids.append(cid)
	WorldMemory.record_event({
		"type": "pawn_birth",
		"birth_kind": "child",
		"tick": GameManager.tick_count,
		"pawn_id": int(data.id),
		"pawn_name": data.display_name,
		"parent_a_id": int(parent_a.id),
		"parent_b_id": int(parent_b.id),
		"parent_a_name": str(parent_a.display_name),
		"parent_b_name": str(parent_b.display_name),
		"household_id": int(data.household_id),
		"inbreeding_penalty": inbreeding_penalty,
		"tile": {"x": tile.x, "y": tile.y},
		"region": WorldMemory._region_key(tile.x, tile.y),
	})
	WorldMemory.record_event({
		"type": "dynasty_line",
		"tick": GameManager.tick_count,
		"pawn_id": int(data.id),
		"pawn_name": data.display_name,
		"parent_a_name": str(parent_a.display_name),
		"parent_b_name": str(parent_b.display_name),
		"parent_a_id": int(parent_a.id),
		"parent_b_id": int(parent_b.id),
		"narrative": "%s born to %s and %s" % [data.display_name, parent_a.display_name, parent_b.display_name],
	})
	if GameManager.verbose_logs():
		print("[Spawn] child: %s at (%d,%d) from #%d + #%d" % [
			data.display_name, tile.x, tile.y, parent_a.id, parent_b.id,
		])
	return pawn


## Pick a name we haven't used yet this run.
func _pick_name(used_tiles: Dictionary, rng: RandomNumberGenerator) -> String:
	var used_names: Dictionary = {}
	for p in pawns:
		used_names[p.data.display_name] = true
	var available: Array[String] = []
	for n in FIRST_NAMES:
		if not used_names.has(n):
			available.append(n)
	if available.is_empty():
		return "Settler-%d" % used_tiles.size()
	return available[rng.randi() % available.size()]


## Assign 0-2 random traits to a pawn. Called at spawn time.
func _assign_random_traits(pawn_data: HeelKawnianData, rng: RandomNumberGenerator) -> void:
	var num_traits: int = rng.randi_range(0, 2)  # 0, 1, or 2 traits
	var trait_types: Array = Trait.Type.values()
	var assigned: Dictionary = {}
	
	for _i in range(num_traits):
		if trait_types.is_empty():
			break
		var trait_type = trait_types[rng.randi() % trait_types.size()]
		# Avoid duplicate traits
		if not assigned.has(trait_type):
			assigned[trait_type] = true
			var trait_item := Trait.new(trait_type)
			pawn_data.add_trait(trait_item)


## Spawn a migrant HeelKawnian at the edge of the map.
## They walk toward the nearest settlement. Population grows from without.
func spawn_migrant(world: World) -> HeelKawnian:
	if world == null:
		return null
	# Find a passable tile at the map edge
	var rng: RandomNumberGenerator = WorldRNG.rng_for(&"migrant_spawn")
	var edge_tiles: Array[Vector2i] = []
	# Try edges: top, bottom, left, right
	for x in range(0, WorldData.WIDTH, 4):
		if world.pathfinder.is_passable(Vector2i(x, 0)):
			edge_tiles.append(Vector2i(x, 0))
		if world.pathfinder.is_passable(Vector2i(x, WorldData.HEIGHT - 1)):
			edge_tiles.append(Vector2i(x, WorldData.HEIGHT - 1))
	for y in range(0, WorldData.HEIGHT, 4):
		if world.pathfinder.is_passable(Vector2i(0, y)):
			edge_tiles.append(Vector2i(0, y))
		if world.pathfinder.is_passable(Vector2i(WorldData.WIDTH - 1, y)):
			edge_tiles.append(Vector2i(WorldData.WIDTH - 1, y))
	if edge_tiles.is_empty():
		return null
	# Pick a random edge tile
	var spawn_tile: Vector2i = edge_tiles[rng.randi() % edge_tiles.size()]
	# Create the pawn
	var pawn_data: HeelKawnianData = HeelKawnianData.new()
	pawn_data.id = _next_pawn_id
	_next_pawn_id += 1
	pawn_data.display_name = _pick_name({}, rng)
	pawn_data.gender = rng.randi_range(0, 2)  # MALE, FEMALE, OTHER
	pawn_data.tile_pos = spawn_tile
	pawn_data.birth_tick = GameManager.tick_count if GameManager != null else 0
	pawn_data.age_years = float(rng.randi_range(18, 40))  # Adult migrant
	pawn_data.life_stage = pawn_data.compute_life_stage()
	pawn_data.age = int(pawn_data.age_years)
	pawn_data.is_pioneer = false
	_assign_random_traits(pawn_data, rng)
	# Create the pawn scene
	var pawn_scene: PackedScene = load("res://scenes/pawn/HeelKawnian.tscn")
	var pawn: HeelKawnian = pawn_scene.instantiate()
	pawn.data = pawn_data
	pawn.position = world.tile_to_world(spawn_tile)
	pawns.append(pawn)
	add_child(pawn)
	# Record migration event
	WorldMemory.record_event({
		"kind": WorldMemory.Kind.MIGRATION,
		"tick": GameManager.tick_count if GameManager != null else 0,
		"pawn_id": int(pawn_data.id),
		"pawn_name": pawn_data.display_name,
		"migrant": true,
		"tile": {"x": spawn_tile.x, "y": spawn_tile.y},
	})
	if GameManager != null and GameManager.verbose_logs():
		print("[Migrant] %s arrived at (%d, %d)" % [pawn_data.display_name, spawn_tile.x, spawn_tile.y])
	return pawn
