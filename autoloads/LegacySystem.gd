extends Node
## Phase 7: Dynasty & Legacy System
## Tracks player significance across generations and enables succession mechanics.
##
## Core Features:
## - Legacy scoring: measures player's impact on the world
## - Dynasty tracking: follows bloodlines across generations
## - Succession: inherit traits, knowledge, and status from ancestors
## - Endgame conditions: determines when a "run" is complete

# ---- Signals ----
signal legacy_score_changed(new_score: int)
signal dynasty_member_added(member_id: int, ancestor_id: int)
signal succession_available(ancestor_id: int, heir_id: int)

# ---- Constants ----
const LEGACY_TICK_INTERVAL: int = 100  # Check legacy every 100 ticks
const LEGACY_PHASE_OFFSET: int = 23
const SUCCESSION_MIN_AGE: int = 16  # Minimum age to inherit
const SUCCESSION_MAX_DISTANCE_TILES: int = 50  # Max distance to inherit from ancestor

# ---- Legacy Score Components ----
const LEGACY_CHILDREN_WEIGHT: int = 10      # Points per child
const LEGACY_GRANDCHILDREN_WEIGHT: int = 5  # Points per grandchild
const LEGACY_KNOWLEDGE_WEIGHT: int = 20     # Points per knowledge type preserved
const LEGACY_BUILDING_WEIGHT: int = 2       # Points per building constructed
const LEGACY_TEACHING_WEIGHT: int = 15      # Points per student taught
const LEGACY_SURVIVAL_WEIGHT: int = 1       # Points per 100 ticks survived

# ---- Data Structures ----

## Legacy entry for a pawn
## {
##   "pawn_id": int,
##   "player_incarnated": bool,  # Was this pawn player-controlled?
##   "legacy_score": int,
##   "children_count": int,
##   "grandchildren_count": int,
##   "knowledge_preserved": Array[int],  # Knowledge types that survived
##   "buildings_constructed": int,
##   "students_taught": int,
##   "ticks_survived": int,
##   "death_tick": int,
##   "death_cause": String,
##   "settlement_id": int,
##   "dynasty_id": int
## }
var legacy_entries: Dictionary = {}  # pawn_id -> legacy entry

## Dynasty tracking
## {
##   "dynasty_id": int,
##   "founder_id": int,
##   "founder_name": String,
##   "founded_tick": int,
##   "member_ids": Array[int],  # All descendants
##   "current_generation": int,
##   "total_members": int,
##   "legacy_score_total": int
## }
var dynasties: Dictionary = {}  # dynasty_id -> dynasty data
var pawn_to_dynasty: Dictionary = {}  # pawn_id -> dynasty_id

## Current player legacy
var _current_player_legacy_id: int = -1
var _current_dynasty_id: int = -1
var _legacy_score: int = 0

## Autoload references
@onready var WorldMemory = get_node_or_null("/root/WorldMemory")
@onready var KnowledgeSystem = get_node_or_null("/root/KnowledgeSystem")
@onready var SettlementMemory = get_node_or_null("/root/SettlementMemory")
@onready var PawnSpawnerRef = get_node_or_null("/root/PawnSpawner")


func _ready() -> void:
	GameManager.game_tick.connect(_on_game_tick)


func _on_game_tick(tick: int) -> void:
	# Legacy scoring runs periodically
	if GameManager.periodic_phase_due(tick, LEGACY_TICK_INTERVAL, LEGACY_PHASE_OFFSET):
		_update_legacy_scores()
	
	# Check for succession opportunities
	if tick % 200 == 0:
		_check_succession_opportunities()


# ==================== LEGACY SCORING ====================

## Record a pawn's legacy when they die
func record_legacy(pawn_id: int, pawn_data: PawnData, death_cause: String) -> void:
	var entry: Dictionary = {
		"pawn_id": pawn_id,
		"player_incarnated": _is_former_player_pawn(pawn_id),
		"legacy_score": 0,
		"children_count": pawn_data.children_count if pawn_data else 0,
		"grandchildren_count": 0,  # Calculated below
		"knowledge_preserved": _get_preserved_knowledge(pawn_id),
		"buildings_constructed": _count_buildings(pawn_id),
		"students_taught": _count_students(pawn_id),
		"ticks_survived": GameManager.tick_count - (pawn_data.birth_tick if pawn_data else 0),
		"death_tick": GameManager.tick_count,
		"death_cause": death_cause,
		"settlement_id": pawn_data.settlement_id if pawn_data else -1,
		"dynasty_id": pawn_to_dynasty.get(pawn_id, -1)
	}
	
	# Calculate grandchildren
	entry.grandchildren_count = _count_grandchildren(pawn_id)
	
	# Calculate legacy score
	entry.legacy_score = _calculate_legacy_score(entry)
	
	legacy_entries[pawn_id] = entry
	
	# Update dynasty total
	if entry.dynasty_id >= 0 and dynasties.has(entry.dynasty_id):
		dynasties[entry.dynasty_id].legacy_score_total += entry.legacy_score
	
	# Record to WorldMemory
	_record_legacy_event(entry)
	
	# Emit signal if this was player's pawn
	if entry.player_incarnated:
		legacy_score_changed.emit(_legacy_score)


## Calculate total legacy score for a pawn
func _calculate_legacy_score(entry: Dictionary) -> int:
	var score: int = 0
	
	# Children contribute most
	score += entry.children_count * LEGACY_CHILDREN_WEIGHT
	
	# Grandchildren show multi-generational impact
	score += entry.grandchildren_count * LEGACY_GRANDCHILDREN_WEIGHT
	
	# Knowledge preservation is critical
	score += entry.knowledge_preserved.size() * LEGACY_KNOWLEDGE_WEIGHT
	
	# Buildings show physical impact
	score += entry.buildings_constructed * LEGACY_BUILDING_WEIGHT
	
	# Teaching spreads knowledge
	score += entry.students_taught * LEGACY_TEACHING_WEIGHT
	
	# Survival shows resilience
	score += (entry.ticks_survived / 100) * LEGACY_SURVIVAL_WEIGHT
	
	# Player incarnation bonus (lived intentionally)
	if entry.player_incarnated:
		score = int(score * 1.5)
	
	return score


## Periodically update legacy scores for all dead pawns
func _update_legacy_scores() -> void:
	# This runs every LEGACY_TICK_INTERVAL ticks
	# For now, we just ensure consistency - scores are calculated at death
	pass


# ==================== DYNASTY TRACKING ====================

## Add pawn to a dynasty (called when pawn is born)
func add_to_dynasty(pawn_id: int, parent_a_id: int, parent_b_id: int, pawn_name: String) -> void:
	var dynasty_id: int = -1
	
	# Inherit dynasty from parents
	if parent_a_id >= 0 and pawn_to_dynasty.has(parent_a_id):
		dynasty_id = pawn_to_dynasty[parent_a_id]
	elif parent_b_id >= 0 and pawn_to_dynasty.has(parent_b_id):
		dynasty_id = pawn_to_dynasty[parent_b_id]
	
	# Create new dynasty if no parent dynasty
	if dynasty_id < 0:
		dynasty_id = _create_dynasty(pawn_id, pawn_name)
	
	# Add pawn to dynasty
	pawn_to_dynasty[pawn_id] = dynasty_id
	
	if dynasties.has(dynasty_id):
		var dynasty: Dictionary = dynasties[dynasty_id]
		if not dynasty.member_ids.has(pawn_id):
			dynasty.member_ids.append(pawn_id)
			dynasty.total_members += 1
		
		# Update generation
		var parent_gen: int = 0
		if parent_a_id >= 0 and dynasties.has(dynasty_id):
			# Simplified: assume first generation is 1
			parent_gen = 1
		dynasty.current_generation = maxi(dynasty.current_generation, parent_gen + 1)
	
	# Emit signal
	dynasty_member_added.emit(pawn_id, maxi(parent_a_id, parent_b_id))


## Create a new dynasty
func _create_dynasty(founder_id: int, founder_name: String) -> int:
	var dynasty_id: int = dynasties.size()
	
	dynasties[dynasty_id] = {
		"dynasty_id": dynasty_id,
		"founder_id": founder_id,
		"founder_name": founder_name,
		"founded_tick": GameManager.tick_count,
		"member_ids": [founder_id],
		"current_generation": 1,
		"total_members": 1,
		"legacy_score_total": 0
	}
	
	pawn_to_dynasty[founder_id] = dynasty_id
	
	return dynasty_id


## Get dynasty info for a pawn
func get_dynasty_info(pawn_id: int) -> Dictionary:
	if not pawn_to_dynasty.has(pawn_id):
		return {}
	
	var dynasty_id: int = pawn_to_dynasty[pawn_id]
	if not dynasties.has(dynasty_id):
		return {}
	
	return dynasties[dynasty_id]


## Get all dynasty members
func get_dynasty_members(dynasty_id: int) -> Array[int]:
	if not dynasties.has(dynasty_id):
		return []
	
	return dynasties[dynasty_id].member_ids


# ==================== SUCCESSION SYSTEM ====================

## Check if succession is available (player can inherit from ancestor)
func _check_succession_opportunities() -> void:
	if _current_player_legacy_id < 0:
		return
	
	# Find available heirs (dead player pawns with legacy)
	for pawn_id in legacy_entries:
		var entry: Dictionary = legacy_entries[pawn_id]
		if entry.player_incarnated and entry.legacy_score > 100:
			# Check if there's a valid heir
			var heir_id: int = _find_valid_heir(pawn_id)
			if heir_id >= 0:
				succession_available.emit(pawn_id, heir_id)


## Find a valid heir for succession
func _find_valid_heir(ancestor_id: int) -> int:
	# Look for living descendants
	var ancestor_entry: Dictionary = legacy_entries.get(ancestor_id, {})
	if ancestor_entry.is_empty():
		return -1
	
	var dynasty_id: int = ancestor_entry.get("dynasty_id", -1)
	if dynasty_id < 0:
		return -1
	
	var dynasty: Dictionary = dynasties.get(dynasty_id, {})
	for member_id in dynasty.member_ids:
		# Check if member is alive and meets requirements
		if _is_pawn_alive(member_id) and _meets_succession_requirements(member_id):
			return member_id
	
	return -1


## Check if pawn meets succession requirements
func _meets_succession_requirements(pawn_id: int) -> bool:
	# Check age
	var pawn_data: PawnData = _get_pawn_data(pawn_id)
	if pawn_data == null or pawn_data.age < SUCCESSION_MIN_AGE:
		return false
	
	# Check distance (heir must be reachable)
	# Simplified for now
	
	return true


## Player succeeds to an ancestor's legacy
func player_succeed(ancestor_id: int, heir_id: int) -> void:
	var ancestor_entry: Dictionary = legacy_entries.get(ancestor_id, {})
	if ancestor_entry.is_empty():
		return
	
	# Transfer some legacy benefits
	_current_player_legacy_id = heir_id
	
	# Inherit knowledge (if KnowledgeSystem exists)
	if KnowledgeSystem != null:
		for knowledge_type in ancestor_entry.get("knowledge_preserved", []):
			KnowledgeSystem.add_knowledge_carrier(heir_id, knowledge_type)
	
	# Record succession event
	_record_succession_event(ancestor_id, heir_id)


# ==================== HELPER FUNCTIONS ====================

## Check if pawn was ever player-controlled
func _is_former_player_pawn(_pawn_id: int) -> bool:
	# This would need to track player incarnations
	# For now, simplified check
	return false


## Get knowledge types preserved by this pawn
func _get_preserved_knowledge(pawn_id: int) -> Array[int]:
	if KnowledgeSystem == null:
		return []

	var preserved: Array[int] = []

	# Check record carriers inscribed by this pawn (Node-safe access)
	if KnowledgeSystem.has_method("get"):
		var carriers: Variant = KnowledgeSystem.get("record_carriers")
		if carriers != null and carriers is Dictionary:
			for tile_key in carriers:
				var carrier: Dictionary = carriers[tile_key]
				if int(carrier.get("inscriber_id", -1)) == pawn_id:
					for kt in carrier.get("knowledge_types", []):
						if not preserved.has(int(kt)):
							preserved.append(int(kt))

	return preserved


## Count buildings constructed by pawn
func _count_buildings(pawn_id: int) -> int:
	# Would need to track building construction per pawn
	# For now, simplified
	return 0


## Count students taught by pawn
func _count_students(pawn_id: int) -> int:
	# Would need to track teaching events
	# Simplified for now
	return 0


## Count grandchildren
func _count_grandchildren(pawn_id: int) -> int:
	# Would need kinship tracking
	# Simplified for now
	return 0


## Check if pawn is alive
func _is_pawn_alive(pawn_id: int) -> bool:
	# Check if pawn_id is in legacy_entries (dead) or not
	return not legacy_entries.has(pawn_id)


## Get pawn data
func _get_pawn_data(pawn_id: int) -> PawnData:
	if PawnSpawnerRef == null:
		return null
	
	if PawnSpawnerRef.has_method("pawn_data_for_id"):
		return PawnSpawnerRef.call("pawn_data_for_id", pawn_id)
	
	return null


## Record legacy event to WorldMemory
func _record_legacy_event(entry: Dictionary) -> void:
	if WorldMemory == null:
		return
	
	WorldMemory.record_event({
		"type": "legacy_record",
		"pawn_id": entry.pawn_id,
		"legacy_score": entry.legacy_score,
		"children": entry.children_count,
		"grandchildren": entry.grandchildren_count,
		"knowledge": entry.knowledge_preserved.size(),
		"buildings": entry.buildings_constructed,
		"students": entry.students_taught,
		"ticks": entry.ticks_survived,
		"tick": GameManager.tick_count
	})


## Record succession event
func _record_succession_event(ancestor_id: int, heir_id: int) -> void:
	if WorldMemory == null:
		return
	
	WorldMemory.record_event({
		"type": "succession",
		"ancestor_id": ancestor_id,
		"heir_id": heir_id,
		"tick": GameManager.tick_count
	})


# ==================== PUBLIC API ====================

## Get current player legacy score
func get_player_legacy_score() -> int:
	return _legacy_score


## Get legacy entry for a pawn
func get_legacy_entry(pawn_id: int) -> Dictionary:
	return legacy_entries.get(pawn_id, {})


## Get all legacy entries
func get_all_legacy_entries() -> Array:
	var entries: Array = []
	for pawn_id in legacy_entries:
		entries.append(legacy_entries[pawn_id])
	return entries


## Get dynasty summary
func get_dynasty_summary(dynasty_id: int) -> Dictionary:
	if not dynasties.has(dynasty_id):
		return {}
	
	var dynasty: Dictionary = dynasties[dynasty_id]
	return {
		"name": "%s Dynasty" % dynasty.founder_name,
		"generations": dynasty.current_generation,
		"members": dynasty.total_members,
		"legacy_score": dynasty.legacy_score_total,
		"founded_tick": dynasty.founded_tick
	}


## Set current player pawn for legacy tracking
func set_current_player_pawn(pawn_id: int) -> void:
	_current_player_legacy_id = pawn_id
	
	# Get or create dynasty
	if pawn_to_dynasty.has(pawn_id):
		_current_dynasty_id = pawn_to_dynasty[pawn_id]


## Get endgame status
func get_endgame_status() -> Dictionary:
	# Calculate total dynasty members manually (Godot 4.x doesn't support list comprehension)
	var total_members: int = 0
	for d in dynasties.values():
		if d is Dictionary:
			total_members += int(d.get("total_members", 0))
	
	return {
		"total_legacy": _legacy_score,
		"dynasty_count": dynasties.size(),
		"total_dynasty_members": total_members,
		"player_incarnations": _count_player_incarnations()
	}


func _count_player_incarnations() -> int:
	var count: int = 0
	for entry in legacy_entries.values():
		if entry.get("player_incarnated", false):
			count += 1
	return count


func sum(arr: Array) -> int:
	var total: int = 0
	for val in arr:
		total += val
	return total
