extends Node
## BloodlineSystem - CK3-style family trees and lineage
##
## Features:
## - Track parents, children, bloodlines
## - Inherited traits (deterministic propagation)
## - Family reputation, feuds, alliances
## - Names and naming customs
## - Lost heirs, forgotten branches
## - Skills preserved through teaching

# Bloodline data structure
## {
##   "bloodline_id": int,
##   "name": String,
##   "founder_id": int,
##   "members": Array[int],  # pawn_ids
##   "living_members": Array[int],
##   "family_tree": Dictionary,  # {pawn_id: {parents: [], children: []}}
##   "reputation": int,  # -1000 to 1000
##   "feuds": Array[int],  # bloodline_ids
##   "alliances": Array[int],  # bloodline_ids
##   "inherited_traits": Array[String],
##   "skills_preserved": Array[String],
##   "created_tick": int,
##   "status": String  # "active", "extinct", "forgotten"
## }
var bloodlines: Array[Dictionary] = []
var _next_bloodline_id: int = 1

# Pawn family data
## {
##   "pawn_id": int,
##   "bloodline_id": int,
##   "father_id": int,
##   "mother_id": int,
##   "children": Array[int],
##   "spouse_id": int,
##   "generation": int,
##   "heir_status": String,  # "heir", "spare", "none"
##   "legitimacy": float  # 0-100 (for succession disputes)
## }
var pawn_family_data: Dictionary = {}

# Configuration
const MAX_BLOODLINE_MEMORY_TICKS: int = 50000  # Remember bloodlines for 50k ticks
const INBREEDING_PENALTY_THRESHOLD: int = 3  # Generations of separation minimum

# References
@onready var _world_memory: Node = null
@onready var _pawn_spawner: Node = null
@onready var _genetics_system: Node = null


func _ready() -> void:
	GameManager.game_tick.connect(_on_game_tick)
	_world_memory = get_node_or_null("/root/WorldMemory")
	_pawn_spawner = get_node_or_null("/root/Main/WorldViewport/PawnSpawner")
	_genetics_system = get_node_or_null("/root/GeneticsSystem")


func _on_game_tick(tick: int) -> void:
	# Clean old/extinct bloodlines periodically
	if tick % 5000 == 0:
		_clean_old_bloodlines(tick)


# ==================== BLOODLINE CREATION ====================

## Create a new bloodline (usually at pawn birth)
func create_bloodline(founder_id: int, bloodline_name: String = "") -> int:
	if bloodline_name == "":
		bloodline_name = _generate_bloodline_name(founder_id)
	
	var bloodline: Dictionary = {
		"bloodline_id": _next_bloodline_id,
		"name": bloodline_name,
		"founder_id": founder_id,
		"members": [founder_id],
		"living_members": [founder_id],
		"family_tree": {
			str(founder_id): {
				"parents": [],
				"children": [],
				"spouse": null,
				"generation": 1
			}
		},
		"reputation": 0,
		"feuds": [],
		"alliances": [],
		"inherited_traits": [],
		"skills_preserved": [],
		"created_tick": GameManager.tick_count,
		"status": "active"
	}
	
	bloodlines.append(bloodline)
	
	# Initialize pawn family data
	_initialize_pawn_family(founder_id, _next_bloodline_id, 1)
	
	_next_bloodline_id += 1
	
	# Record bloodline creation
	if _world_memory != null:
		_world_memory.record_event({
			"type": "bloodline_created",
			"bloodline_id": bloodline.bloodline_id,
			"name": bloodline.name,
			"founder_id": founder_id,
			"tick": GameManager.tick_count
		})
	
	return bloodline.bloodline_id


func _initialize_pawn_family(pawn_id: int, bloodline_id: int, generation: int) -> void:
	pawn_family_data[pawn_id] = {
		"pawn_id": pawn_id,
		"bloodline_id": bloodline_id,
		"father_id": -1,
		"mother_id": -1,
		"children": [],
		"spouse_id": -1,
		"generation": generation,
		"heir_status": "heir" if generation == 1 else "none",
		"legitimacy": 100.0
	}


func _generate_bloodline_name(founder_id: int) -> String:
	var founder_name: String = _get_pawn_name(founder_id)
	
	# Generate family name from founder's name
	# E.g., "Gorne" → "House of Gorne" or "Gorne bloodline"
	return "House of %s" % founder_name


# ==================== FAMILY RELATIONSHIPS ====================

## Record parent-child relationship
func record_parent_child(child_id: int, father_id: int, mother_id: int) -> void:
	# Get child's bloodline
	var child_bloodline: int = _get_pawn_bloodline(child_id)
	
	# Add to father's bloodline if exists
	if father_id >= 0:
		var father_bloodline: int = _get_pawn_bloodline(father_id)
		if father_bloodline >= 0 and father_bloodline == child_bloodline:
			_add_to_bloodline(child_bloodline, child_id)
			_add_to_family_tree(child_bloodline, child_id, [father_id, mother_id])
		
		# Record father relationship
		if pawn_family_data.has(father_id):
			pawn_family_data[father_id].children.append(child_id)
	
	# Add to mother's bloodline if exists
	if mother_id >= 0:
		if pawn_family_data.has(mother_id):
			pawn_family_data[mother_id].children.append(child_id)
	
	# Update child's family data
	if pawn_family_data.has(child_id):
		pawn_family_data[child_id].father_id = father_id
		pawn_family_data[child_id].mother_id = mother_id
		
		# Calculate generation
		var parent_generation: int = 1
		if father_id >= 0 and pawn_family_data.has(father_id):
			parent_generation = pawn_family_data[father_id].generation
		elif mother_id >= 0 and pawn_family_data.has(mother_id):
			parent_generation = pawn_family_data[mother_id].generation
		
		pawn_family_data[child_id].generation = parent_generation + 1
	
	# Record birth
	if _world_memory != null:
		_world_memory.record_event({
			"type": "birth_recorded",
			"child_id": child_id,
			"father_id": father_id,
			"mother_id": mother_id,
			"bloodline_id": child_bloodline,
			"tick": GameManager.tick_count
		})


## Record marriage/spouse relationship
func record_marriage(pawn1_id: int, pawn2_id: int) -> void:
	# Update spouse data
	if pawn_family_data.has(pawn1_id):
		pawn_family_data[pawn1_id].spouse_id = pawn2_id
	
	if pawn_family_data.has(pawn2_id):
		pawn_family_data[pawn2_id].spouse_id = pawn1_id
	
	# Add to family tree
	var bloodline: int = _get_pawn_bloodline(pawn1_id)
	if bloodline >= 0:
		_add_spouse_to_family_tree(bloodline, pawn1_id, pawn2_id)
	
	# Record marriage
	if _world_memory != null:
		_world_memory.record_event({
			"type": "marriage_recorded",
			"pawn1_id": pawn1_id,
			"pawn2_id": pawn2_id,
			"bloodline_id": bloodline,
			"tick": GameManager.tick_count
		})


## Record death in bloodline
func record_death(pawn_id: int) -> void:
	var bloodline: int = _get_pawn_bloodline(pawn_id)
	if bloodline < 0:
		return
	
	var bloodline_data: Dictionary = _get_bloodline(bloodline)
	if bloodline_data == null:
		return
	
	# Remove from living members
	var idx: int = bloodline_data.living_members.find(pawn_id)
	if idx >= 0:
		bloodline_data.living_members.remove_at(idx)
	
	# Check for heir succession
	_succession(bloodline_data, pawn_id)
	
	# Check if bloodline is extinct
	if bloodline_data.living_members.size() == 0:
		bloodline_data.status = "extinct"
	
	# Record death
	if _world_memory != null:
		_world_memory.record_event({
			"type": "death_recorded",
			"pawn_id": pawn_id,
			"bloodline_id": bloodline,
			"tick": GameManager.tick_count
		})


func _succession(bloodline: Dictionary, deceased_id: int) -> void:
	# Find new heir
	var heir_id: int = _find_heir(bloodline, deceased_id)
	
	if heir_id >= 0 and pawn_family_data.has(heir_id):
		pawn_family_data[heir_id].heir_status = "heir"
		
		# Record succession
		if _world_memory != null:
			_world_memory.record_event({
				"type": "succession",
				"bloodline_id": bloodline.bloodline_id,
				"deceased_id": deceased_id,
				"heir_id": heir_id,
				"tick": GameManager.tick_count
			})


func _find_heir(bloodline: Dictionary, exclude_id: int) -> int:
	# Primogeniture: eldest child inherits
	# Simplified: just find first living member who isn't excluded
	for member_id in bloodline.members:
		if member_id != exclude_id and bloodline.living_members.has(member_id):
			return member_id
	
	return -1  # No heir found


# ==================== BLOODLINE MANAGEMENT ====================

func _add_to_bloodline(bloodline_id: int, pawn_id: int) -> void:
	var bloodline: Dictionary = _get_bloodline(bloodline_id)
	if bloodline == null:
		return
	
	if not bloodline.members.has(pawn_id):
		bloodline.members.append(pawn_id)
	
	if not bloodline.living_members.has(pawn_id):
		bloodline.living_members.append(pawn_id)


func _add_to_family_tree(bloodline_id: int, pawn_id: int, parents: Array[int]) -> void:
	var bloodline: Dictionary = _get_bloodline(bloodline_id)
	if bloodline == null:
		return
	
	var generation: int = 1
	if parents.size() > 0 and pawn_family_data.has(parents[0]):
		generation = pawn_family_data[parents[0]].generation + 1
	
	bloodline.family_tree[str(pawn_id)] = {
		"parents": parents,
		"children": [],
		"spouse": null,
		"generation": generation
	}


func _add_spouse_to_family_tree(bloodline_id: int, pawn_id: int, spouse_id: int) -> void:
	var bloodline: Dictionary = _get_bloodline(bloodline_id)
	if bloodline == null:
		return
	
	if bloodline.family_tree.has(str(pawn_id)):
		bloodline.family_tree[str(pawn_id)].spouse = spouse_id


# ==================== INHERITANCE ====================

## Inherit traits from parents
func inherit_traits(child_id: int, father_id: int, mother_id: int) -> Array[String]:
	var inherited: Array[String] = []
	
	if _genetics_system != null and _genetics_system.has_method("calculate_inheritance"):
		inherited = _genetics_system.calculate_inheritance(child_id, father_id, mother_id)
	
	# Record inherited traits
	if inherited.size() > 0 and pawn_family_data.has(child_id):
		var bloodline: int = _get_pawn_bloodline(child_id)
		if bloodline >= 0:
			var bloodline_data: Dictionary = _get_bloodline(bloodline)
			var i: int = 0
			while i < inherited.size():
				var t: String = inherited[i]
				if not bloodline_data.inherited_traits.has(t):
					bloodline_data.inherited_traits.append(t)
				i += 1

	return inherited


## Preserve skill through teaching (parent to child)
func preserve_skill(bloodline_id: int, skill_name: String) -> void:
	var bloodline: Dictionary = _get_bloodline(bloodline_id)
	if bloodline == null:
		return
	
	if not bloodline.skills_preserved.has(skill_name):
		bloodline.skills_preserved.append(skill_name)
		
		# Record preservation
		if _world_memory != null:
			_world_memory.record_event({
				"type": "skill_preserved",
				"bloodline_id": bloodline_id,
				"skill": skill_name,
				"tick": GameManager.tick_count
			})


# ==================== FEUDS & ALLIANCES ====================

## Start feud between bloodlines
func start_feud(bloodline1_id: int, bloodline2_id: int, reason: String = "") -> void:
	var bloodline1: Dictionary = _get_bloodline(bloodline1_id)
	var bloodline2: Dictionary = _get_bloodline(bloodline2_id)
	
	if bloodline1 == null or bloodline2 == null:
		return
	
	# Add to feuds
	if not bloodline1.feuds.has(bloodline2_id):
		bloodline1.feuds.append(bloodline2_id)
	
	if not bloodline2.feuds.has(bloodline1_id):
		bloodline2.feuds.append(bloodline1_id)
	
	# Record feud
	if _world_memory != null:
		_world_memory.record_event({
			"type": "bloodline_feud",
			"bloodline1_id": bloodline1_id,
			"bloodline2_id": bloodline2_id,
			"reason": reason,
			"tick": GameManager.tick_count
		})


## Form alliance between bloodlines
func form_alliance(bloodline1_id: int, bloodline2_id: int, alliance_type: String = "marriage") -> void:
	var bloodline1: Dictionary = _get_bloodline(bloodline1_id)
	var bloodline2: Dictionary = _get_bloodline(bloodline2_id)
	
	if bloodline1 == null or bloodline2 == null:
		return
	
	# Add to alliances
	if not bloodline1.alliances.has(bloodline2_id):
		bloodline1.alliances.append(bloodline2_id)
	
	if not bloodline2.alliances.has(bloodline1_id):
		bloodline2.alliances.append(bloodline1_id)
	
	# Record alliance
	if _world_memory != null:
		_world_memory.record_event({
			"type": "bloodline_alliance",
			"bloodline1_id": bloodline1_id,
			"bloodline2_id": bloodline2_id,
			"alliance_type": alliance_type,
			"tick": GameManager.tick_count
		})


# ==================== REPUTATION ====================

## Modify bloodline reputation
func modify_reputation(bloodline_id: int, amount: int, reason: String = "") -> void:
	var bloodline: Dictionary = _get_bloodline(bloodline_id)
	if bloodline == null:
		return
	
	bloodline.reputation += amount
	bloodline.reputation = clampi(bloodline.reputation, -1000, 1000)
	
	# Record reputation change
	if _world_memory != null:
		_world_memory.record_event({
			"type": "bloodline_reputation_changed",
			"bloodline_id": bloodline_id,
			"amount": amount,
			"reason": reason,
			"tick": GameManager.tick_count
		})


## Get reputation level
func get_reputation_level(reputation: int) -> String:
	if reputation >= 500:
		return "Legendary"
	elif reputation >= 200:
		return "Renowned"
	elif reputation >= 50:
		return "Respected"
	elif reputation >= 0:
		return "Neutral"
	elif reputation >= -50:
		return "Disliked"
	elif reputation >= -200:
		return "Hated"
	else:
		return "Infamous"


# ==================== UTILITY ====================

func _get_bloodline(bloodline_id: int) -> Dictionary:
	for bloodline in bloodlines:
		if bloodline.bloodline_id == bloodline_id:
			return bloodline
	return null


func _get_pawn_bloodline(pawn_id: int) -> int:
	if pawn_family_data.has(pawn_id):
		return pawn_family_data[pawn_id].bloodline_id
	return -1


func _get_pawn_name(pawn_id: int) -> String:
	if _pawn_spawner == null or not _pawn_spawner.has_method("pawn_data_for_id"):
		return "Pawn #%d" % pawn_id
	
	var data: Node = _pawn_spawner.call("pawn_data_for_id", pawn_id)
	if data != null and data.has_method("get_display_name"):
		return data.get_display_name()
	
	return "Pawn #%d" % pawn_id


func _clean_old_bloodlines(tick: int) -> void:
	for i in range(bloodlines.size() - 1, -1, -1):
		var bloodline: Dictionary = bloodlines[i]
		
		# Clean extinct bloodlines after memory period
		if bloodline.status == "extinct":
			if tick - bloodline.created_tick > MAX_BLOODLINE_MEMORY_TICKS:
				bloodlines.remove_at(i)


# ==================== PUBLIC API ====================

## Get bloodline data
func get_bloodline(bloodline_id: int) -> Dictionary:
	var bloodline: Dictionary = _get_bloodline(bloodline_id)
	if bloodline == null:
		return {}
	return bloodline.duplicate()

## Get pawn's bloodline
func get_pawn_bloodline(pawn_id: int) -> Dictionary:
	var bloodline_id: int = _get_pawn_bloodline(pawn_id)
	if bloodline_id < 0:
		return {}
	return get_bloodline(bloodline_id)

## Get family data for a pawn
func get_pawn_family(pawn_id: int) -> Dictionary:
	if pawn_family_data.has(pawn_id):
		return pawn_family_data[pawn_id].duplicate()
	return {}

## Get all bloodlines
func get_all_bloodlines() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for bloodline in bloodlines:
		result.append(bloodline.duplicate())
	return result

## Get living bloodlines
func get_living_bloodlines() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for bloodline in bloodlines:
		if bloodline.status == "active":
			result.append(bloodline.duplicate())
	return result

## Check if two pawns are related
func are_related(pawn1_id: int, pawn2_id: int, max_generations: int = 5) -> bool:
	if not pawn_family_data.has(pawn1_id) or not pawn_family_data.has(pawn2_id):
		return false
	
	var bloodline1: int = pawn_family_data[pawn1_id].bloodline_id
	var bloodline2: int = pawn_family_data[pawn2_id].bloodline_id
	
	# Same bloodline = related
	if bloodline1 == bloodline2 and bloodline1 >= 0:
		return true
	
	# TODO: Check cross-bloodline relations (marriage, etc.)
	
	return false

## Get generations of separation (for inbreeding check)
func get_generations_of_separation(pawn1_id: int, pawn2_id: int) -> int:
	if not pawn_family_data.has(pawn1_id) or not pawn_family_data.has(pawn2_id):
		return 999  # Unrelated
	
	var gen1: int = pawn_family_data[pawn1_id].generation
	var gen2: int = pawn_family_data[pawn2_id].generation
	
	return abs(gen1 - gen2) + 1

## Clear all data (for world reroll)
func clear() -> void:
	bloodlines.clear()
	pawn_family_data.clear()
	_next_bloodline_id = 1

## Get statistics
func get_stats() -> Dictionary:
	var active: int = 0
	var extinct: int = 0
	var total_members: int = 0
	
	for bloodline in bloodlines:
		if bloodline.status == "active":
			active += 1
			total_members += bloodline.living_members.size()
		else:
			extinct += 1
	
	return {
		"total_bloodlines": bloodlines.size(),
		"active": active,
		"extinct": extinct,
		"total_members": total_members,
		"average_reputation": _calculate_average_reputation()
	}


func _calculate_average_reputation() -> float:
	var total: int = 0
	var count: int = 0
	for bloodline in bloodlines:
		if bloodline.status == "active":
			total += bloodline.reputation
			count += 1
	return float(total) / float(count) if count > 0 else 0.0
