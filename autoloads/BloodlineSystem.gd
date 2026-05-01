extends Node
## BloodlineSystem.gd — Tracks bloodlines and descendants across generations
## Integrates with PawnData children_ids and WorldPersistence family memory

@onready var WorldMemory = get_node_or_null("/root/WorldMemory")
@onready var WorldPersistence = get_node_or_null("/root/WorldPersistence")
@onready var GameManager = get_node_or_null("/root/GameManager")

const BLOODLINE_CLEANUP_INTERVAL_TICKS: int = 10000
const BLOODLINE_CLEANUP_PHASE_OFFSET_TICKS: int = 1151
const BLOODLINE_PRIDE_PER_LIVING_MEMBER: float = 0.006

# Bloodline data: bloodline_id -> bloodline info
var bloodlines: Dictionary = {}

# Pawn to bloodline mapping: pawn_id -> bloodline_id
var pawn_to_bloodline: Dictionary = {}

# Generation tracking: bloodline_id -> generation_data
var generation_data: Dictionary = {}

func _ready() -> void:
	GameManager.game_tick.connect(_on_game_tick)

func _on_game_tick(tick: int) -> void:
	# Periodic cleanup of empty bloodlines
	if GameManager.periodic_phase_due(tick, BLOODLINE_CLEANUP_INTERVAL_TICKS, BLOODLINE_CLEANUP_PHASE_OFFSET_TICKS):
		_cleanup_empty_bloodlines()

# === Bloodline Creation ===

func create_bloodline(founder_id: int, founder_name: String = "", specialization_key: String = "") -> int:
	var bloodline_id: int = GameManager.tick_count * 1000 + bloodlines.size()
	
	bloodlines[bloodline_id] = {
		"bloodline_id": bloodline_id,
		"founder_id": founder_id,
		"founder_name": founder_name,
		"founding_tick": GameManager.tick_count,
		"current_generation": 1,
		"total_members": 1,
		"living_members": 1,
		"historical_deaths": 0,
		"specialization_key": specialization_key,
		"genetic_traits": [],
		"extinct": false,
		"extinction_tick": -1,
	}
	
	generation_data[bloodline_id] = {
		1: {"members": [founder_id], "count": 1}
	}
	
	pawn_to_bloodline[founder_id] = bloodline_id
	
	# Record in WorldMemory
	var event: Dictionary = {
		"type": "bloodline_founded",
		"bloodline_id": bloodline_id,
		"founder_id": founder_id,
		"founder_name": founder_name,
		"tick": GameManager.tick_count,
	}
	if WorldMemory:
		WorldMemory.record_event(event)
	
	# Record in WorldPersistence family memory
	if WorldPersistence:
		WorldPersistence.record_family_event(
			bloodline_id,
			"founded",
			GameManager.tick_count,
			"Bloodline founded by %s" % founder_name,
			[founder_id]
		)
	
	return bloodline_id


func assign_birth_bloodline(newborn_id: int, newborn_name: String, parent_a_id: int = -1, parent_b_id: int = -1, specialization_key: String = "") -> int:
	var bloodline_id: int = -1
	var parent_id: int = parent_a_id if parent_a_id >= 0 else parent_b_id
	if parent_id >= 0:
		bloodline_id = get_bloodline_for_pawn(parent_id)
	if bloodline_id < 0:
		bloodline_id = create_bloodline(newborn_id, newborn_name, specialization_key)
	else:
		add_pawn_to_bloodline(newborn_id, bloodline_id, parent_id)
		if specialization_key != "":
			_update_bloodline_specialization(bloodline_id, specialization_key)
	return bloodline_id


func get_inbreeding_penalty(parent_a_id: int, parent_b_id: int) -> float:
	if parent_a_id < 0 or parent_b_id < 0:
		return 0.0
	if parent_a_id == parent_b_id:
		return 0.35
	var bloodline_a: int = get_bloodline_for_pawn(parent_a_id)
	var bloodline_b: int = get_bloodline_for_pawn(parent_b_id)
	if bloodline_a < 0 or bloodline_b < 0 or bloodline_a != bloodline_b:
		return 0.0
	var generation_gap: int = abs(get_generation_for_pawn(parent_a_id) - get_generation_for_pawn(parent_b_id))
	var penalty: float = 0.20 - 0.03 * float(generation_gap)
	return clampf(penalty, 0.05, 0.20)

# === Bloodline Membership ===

func add_pawn_to_bloodline(pawn_id: int, bloodline_id: int, parent_id: int = -1, genetic_traits: Array = []) -> void:
	if not bloodlines.has(bloodline_id):
		return
	
	pawn_to_bloodline[pawn_id] = bloodline_id
	
	var bloodline: Dictionary = bloodlines[bloodline_id]
	bloodline["total_members"] += 1
	bloodline["living_members"] += 1
	for trait_any in genetic_traits:
		var trait_name: String = str(trait_any).strip_edges()
		if trait_name.is_empty():
			continue
		if not trait_name in bloodline["genetic_traits"]:
			bloodline["genetic_traits"].append(trait_name)
	
	# Determine generation
	var generation: int = 1
	if parent_id >= 0 and pawn_to_bloodline.has(parent_id):
		var parent_bloodline_id: int = pawn_to_bloodline[parent_id]
		if parent_bloodline_id == bloodline_id:
			# Find parent's generation
			for gen in generation_data[bloodline_id].keys():
				var gen_data: Dictionary = generation_data[bloodline_id][gen]
				if parent_id in gen_data.get("members", []):
					generation = gen + 1
					break
	
	# Update generation data
	if not generation_data[bloodline_id].has(generation):
		generation_data[bloodline_id][generation] = {"members": [], "count": 0}
	
	var gen_data: Dictionary = generation_data[bloodline_id][generation]
	if not pawn_id in gen_data.get("members", []):
		gen_data["members"].append(pawn_id)
		gen_data["count"] += 1
	
	# Update current generation if needed
	if generation > bloodline.get("current_generation", 1):
		bloodline["current_generation"] = generation
	
	# Record in WorldMemory
	var event: Dictionary = {
		"type": "bloodline_member_added",
		"bloodline_id": bloodline_id,
		"pawn_id": pawn_id,
		"parent_id": parent_id,
		"generation": generation,
		"tick": GameManager.tick_count,
	}
	if WorldMemory:
		WorldMemory.record_event(event)


func record_pawn_death(pawn_id: int) -> void:
	if not pawn_to_bloodline.has(pawn_id):
		return
	var bloodline_id: int = int(pawn_to_bloodline[pawn_id])
	if not bloodlines.has(bloodline_id):
		return
	var bloodline: Dictionary = bloodlines[bloodline_id]
	bloodline["historical_deaths"] = int(bloodline.get("historical_deaths", 0)) + 1
	bloodline["living_members"] = maxi(0, int(bloodline.get("living_members", 0)) - 1)
	if bloodline["living_members"] <= 0 and not bool(bloodline.get("extinct", false)):
		bloodline["extinct"] = true
		bloodline["extinction_tick"] = GameManager.tick_count
		if WorldMemory:
			WorldMemory.record_event({
				"type": "bloodline_extinct",
				"bloodline_id": bloodline_id,
				"tick": GameManager.tick_count,
			})
		if WorldPersistence:
			WorldPersistence.record_family_event(
				bloodline_id,
				"extinct",
				GameManager.tick_count,
				"Bloodline went extinct",
				[]
			)


func get_bloodline_pride_mood_bonus(bloodline_id: int) -> float:
	if not bloodlines.has(bloodline_id):
		return 0.0
	var bloodline: Dictionary = bloodlines[bloodline_id]
	var living: int = int(bloodline.get("living_members", 0))
	var pride: float = BLOODLINE_PRIDE_PER_LIVING_MEMBER * float(mini(living, 10))
	if bloodline.get("extinct", false):
		pride *= 0.5
	return pride


func get_bloodline_specialization_multiplier(bloodline_id: int, skill: int) -> float:
	if not bloodlines.has(bloodline_id):
		return 1.0
	var bloodline: Dictionary = bloodlines[bloodline_id]
	var spec: String = str(bloodline.get("specialization_key", ""))
	if spec.is_empty():
		return 1.0
	var cat: String = PawnData.tree_skill_category_for_job_skill(skill)
	if cat.is_empty():
		return 1.0
	if spec == cat:
		return 1.08
	return 1.0


func get_generation_for_pawn(pawn_id: int) -> int:
	if not pawn_to_bloodline.has(pawn_id):
		return 1
	var bloodline_id: int = int(pawn_to_bloodline[pawn_id])
	if not generation_data.has(bloodline_id):
		return 1
	for generation in generation_data[bloodline_id].keys():
		var generation_block: Dictionary = generation_data[bloodline_id][generation]
		if pawn_id in generation_block.get("members", []):
			return int(generation)
	return 1


func _update_bloodline_specialization(bloodline_id: int, specialization_key: String) -> void:
	if not bloodlines.has(bloodline_id):
		return
	var bloodline: Dictionary = bloodlines[bloodline_id]
	if str(bloodline.get("specialization_key", "")).is_empty():
		bloodline["specialization_key"] = specialization_key

func remove_pawn_from_bloodline(pawn_id: int, died: bool = false) -> void:
	if not pawn_to_bloodline.has(pawn_id):
		return
	
	var bloodline_id: int = pawn_to_bloodline[pawn_id]
	if not bloodlines.has(bloodline_id):
		pawn_to_bloodline.erase(pawn_id)
		return
	
	var bloodline: Dictionary = bloodlines[bloodline_id]
	
	if died:
		bloodline["living_members"] -= 1
		
		# Check for extinction
		if bloodline["living_members"] <= 0:
			bloodline["extinct"] = true
			bloodline["extinction_tick"] = GameManager.tick_count
			
			# Record extinction
			var event: Dictionary = {
				"type": "bloodline_extinct",
				"bloodline_id": bloodline_id,
				"tick": GameManager.tick_count,
			}
			if WorldMemory:
				WorldMemory.record_event(event)
			
			if WorldPersistence:
				WorldPersistence.record_family_event(
					bloodline_id,
					"extinct",
					GameManager.tick_count,
					"Bloodline went extinct",
					[]
				)

# === Descendant Tracking ===

func get_descendants(pawn_id: int, max_generations: int = -1) -> Array[int]:
	var descendants: Array[int] = []
	
	if not pawn_to_bloodline.has(pawn_id):
		return descendants
	
	var bloodline_id: int = pawn_to_bloodline[pawn_id]
	if not bloodlines.has(bloodline_id):
		return descendants
	
	# Find pawn's generation
	var pawn_generation: int = 1
	for gen in generation_data[bloodline_id].keys():
		var gen_data: Dictionary = generation_data[bloodline_id][gen]
		if pawn_id in gen_data.get("members", []):
			pawn_generation = gen
			break
	
	# Collect descendants from later generations
	for gen in generation_data[bloodline_id].keys():
		if gen <= pawn_generation:
			continue
		if max_generations >= 0 and gen > pawn_generation + max_generations:
			continue
		
		var gen_data: Dictionary = generation_data[bloodline_id][gen]
		for member_id in gen_data.get("members", []):
			if _is_descendant_of(pawn_id, member_id, bloodline_id):
				descendants.append(member_id)
	
	return descendants

func get_ancestors(pawn_id: int, max_generations: int = -1) -> Array[int]:
	var ancestors: Array[int] = []
	
	if not pawn_to_bloodline.has(pawn_id):
		return ancestors
	
	var bloodline_id: int = pawn_to_bloodline[pawn_id]
	if not bloodlines.has(bloodline_id):
		return ancestors
	
	# Find pawn's generation
	var pawn_generation: int = 1
	for gen in generation_data[bloodline_id].keys():
		var gen_data: Dictionary = generation_data[bloodline_id][gen]
		if pawn_id in gen_data.get("members", []):
			pawn_generation = gen
			break
	
	# Collect ancestors from earlier generations
	for gen in generation_data[bloodline_id].keys():
		if gen >= pawn_generation:
			continue
		if max_generations >= 0 and gen < pawn_generation - max_generations:
			continue
		
		var gen_data: Dictionary = generation_data[bloodline_id][gen]
		for member_id in gen_data.get("members", []):
			if _is_ancestor_of(member_id, pawn_id, bloodline_id):
				ancestors.append(member_id)
	
	return ancestors

func _is_descendant_of(ancestor_id: int, descendant_id: int, bloodline_id: int) -> bool:
	# Check if descendant_id is a child of ancestor_id (through PawnData)
	var main: Node2D = Engine.get_main_loop().current_scene as Node2D
	if main == null:
		return false
	
	var spawner: PawnSpawner = main.get("_pawn_spawner") as PawnSpawner
	if spawner == null:
		return false
	
	# Find ancestor pawn
	var ancestor_pawn: Pawn = null
	for p in spawner.pawns:
		if p != null and is_instance_valid(p) and p.data != null and int(p.data.id) == ancestor_id:
			ancestor_pawn = p
			break
	
	if ancestor_pawn == null:
		return false
	
	# Check if descendant_id is in ancestor's children
	return descendant_id in ancestor_pawn.data.children_ids

func _is_ancestor_of(ancestor_id: int, descendant_id: int, bloodline_id: int) -> bool:
	# Check if ancestor_id is a parent of descendant_id
	var main: Node2D = Engine.get_main_loop().current_scene as Node2D
	if main == null:
		return false
	
	var spawner: PawnSpawner = main.get("_pawn_spawner") as PawnSpawner
	if spawner == null:
		return false
	
	# Find descendant pawn
	var descendant_pawn: Pawn = null
	for p in spawner.pawns:
		if p != null and is_instance_valid(p) and p.data != null and int(p.data.id) == descendant_id:
			descendant_pawn = p
			break
	
	if descendant_pawn == null:
		return false
	
	# Check if ancestor_id is in descendant's parents (would need parent tracking in PawnData)
	# For now, use the inverse of descendant check
	return _is_descendant_of(ancestor_id, descendant_id, bloodline_id)

# === Query Functions ===

func get_bloodline_for_pawn(pawn_id: int) -> int:
	if pawn_to_bloodline.has(pawn_id):
		return pawn_to_bloodline[pawn_id]
	return -1

func get_bloodline_info(bloodline_id: int) -> Dictionary:
	if bloodlines.has(bloodline_id):
		return bloodlines[bloodline_id].duplicate(true)
	return {}

func get_bloodline_members(bloodline_id: int) -> Array[int]:
	var members: Array[int] = []
	if generation_data.has(bloodline_id):
		for gen in generation_data[bloodline_id].keys():
			var gen_data: Dictionary = generation_data[bloodline_id][gen]
			members.append_array(gen_data.get("members", []))
	return members

func get_generation_count(bloodline_id: int) -> int:
	if bloodlines.has(bloodline_id):
		return int(bloodlines[bloodline_id].get("current_generation", 1))
	return 0

func is_bloodline_extinct(bloodline_id: int) -> bool:
	if bloodlines.has(bloodline_id):
		return bool(bloodlines[bloodline_id].get("extinct", false))
	return true

# === Cleanup ===

func _cleanup_empty_bloodlines() -> void:
	var to_remove: Array[int] = []
	
	for bloodline_id in bloodlines.keys():
		var bloodline: Dictionary = bloodlines[bloodline_id]
		if bool(bloodline.get("extinct", false)):
			# Keep extinct bloodlines for historical record
			continue
		
		if int(bloodline.get("living_members", 0)) <= 0:
			to_remove.append(bloodline_id)
	
	for bloodline_id in to_remove:
		bloodlines.erase(bloodline_id)
		generation_data.erase(bloodline_id)

# === Save/Load ===

func to_save_dict() -> Dictionary:
	return {
		"bloodlines": bloodlines.duplicate(true),
		"pawn_to_bloodline": pawn_to_bloodline.duplicate(true),
		"generation_data": generation_data.duplicate(true),
	}

func from_save_dict(d: Dictionary) -> void:
	bloodlines.clear()
	pawn_to_bloodline.clear()
	generation_data.clear()
	
	if d.has("bloodlines"):
		bloodlines = d["bloodlines"].duplicate(true)
	if d.has("pawn_to_bloodline"):
		pawn_to_bloodline = d["pawn_to_bloodline"].duplicate(true)
	if d.has("generation_data"):
		generation_data = d["generation_data"].duplicate(true)

func clear() -> void:
	bloodlines.clear()
	pawn_to_bloodline.clear()
	generation_data.clear()
