extends Node
## SquadSystem - Bannerlord-style squad formations and tactics
##
## Features:
## - Squad creation (5-20 pawns per squad)
## - Formations: Phalanx, Skirmish, Charge, Defensive
## - Squad morale tracking
## - Squad XP sharing
## - Officer assignments (Captain, Lieutenant, Sergeant)

# Squad formation types
enum Formation {
	PHALANX,      # Tight formation, +defense, -mobility
	SKIRMISH,     # Loose formation, +mobility, -defense
	CHARGE,       # Aggressive formation, +attack, -defense
	DEFENSIVE,    # Defensive formation, +morale, -attack
	MARCH,        # Travel formation, +speed, -combat
	CIRCLE,       # All-around defense (vs surrounded)
}

# Squad data structure
## {
##   "squad_id": int,
##   "name": String,
##   "leader_id": int,
##   "members": Array[int],  # pawn_ids
##   "formation": int,  # Formation enum
##   "morale": float,  # 0-100
##   "cohesion": float,  # 0-100
##   "squad_xp": int,
##   "battles_won": int,
##   "battles_fought": int,
##   "created_tick": int,
##   "status": String  # "active", "disbanded", "destroyed"
## }
var squads: Array[Dictionary] = []
var _next_squad_id: int = 1

# Formation bonuses
const FORMATION_BONUSES: Dictionary = {
	Formation.PHALANX: {
		"defense": 0.5,
		"mobility": -0.3,
		"attack": 0.1,
		"morale": 0.1
	},
	Formation.SKIRMISH: {
		"defense": -0.2,
		"mobility": 0.4,
		"attack": 0.1,
		"morale": 0.0
	},
	Formation.CHARGE: {
		"defense": -0.3,
		"mobility": 0.2,
		"attack": 0.5,
		"morale": 0.2
	},
	Formation.DEFENSIVE: {
		"defense": 0.3,
		"mobility": -0.2,
		"attack": -0.2,
		"morale": 0.4
	},
	Formation.MARCH: {
		"defense": -0.4,
		"mobility": 0.5,
		"attack": -0.2,
		"morale": 0.0
	},
	Formation.CIRCLE: {
		"defense": 0.4,
		"mobility": -0.5,
		"attack": 0.0,
		"morale": 0.3
	}
}

# Configuration
const MIN_SQUAD_SIZE: int = 3
const MAX_SQUAD_SIZE: int = 20
const MORALE_BREAK_THRESHOLD: float = 20.0

# References
@onready var _world_memory: Node = null
@onready var _combat_progression: Node = null


func _ready() -> void:
	GameManager.game_tick.connect(_on_game_tick)
	_world_memory = get_node_or_null("/root/WorldMemory")
	_combat_progression = get_node_or_null("/root/AICombatProgression")


func _on_game_tick(tick: int) -> void:
	# Update squad morale periodically
	if tick % 100 == 0:
		_update_squad_morale(tick)


# ==================== SQUAD CREATION ====================

## Create a new squad
func create_squad(leader_id: int, name: String = "", initial_members: Array[int] = []) -> int:
	# Validate leader
	if not _is_valid_leader(leader_id):
		return -1
	
	# Generate name if not provided
	if name == "":
		name = _generate_squad_name(leader_id)
	
	# Create squad
	var squad: Dictionary = {
		"squad_id": _next_squad_id,
		"name": name,
		"leader_id": leader_id,
		"members": [leader_id] + initial_members,
		"formation": Formation.PHALANX,
		"morale": 50.0,
		"cohesion": 50.0,
		"squad_xp": 0,
		"battles_won": 0,
		"battles_fought": 0,
		"created_tick": GameManager.tick_count,
		"status": "active"
	}
	
	squads.append(squad)
	_next_squad_id += 1
	
	# Record creation
	if _world_memory != null:
		_world_memory.record_event({
			"type": "squad_created",
			"squad_id": squad.squad_id,
			"name": squad.name,
			"leader_id": leader_id,
			"size": squad.members.size(),
			"tick": GameManager.tick_count
		})
	
	return squad.squad_id


func _is_valid_leader(leader_id: int) -> bool:
	# Check if pawn has leadership capacity
	if _combat_progression != null and _combat_progression.has_method("get_leadership_capacity"):
		var capacity: int = _combat_progression.get_leadership_capacity(leader_id)
		return capacity > 0
	
	# Fallback: allow any pawn to lead small squads
	return true


func _generate_squad_name(leader_id: int) -> String:
	# Get leader name
	var leader_name: String = _get_pawn_name(leader_id)
	return "%s's Squad" % leader_name


# ==================== SQUAD MANAGEMENT ====================

## Add member to squad
func add_member(squad_id: int, pawn_id: int) -> bool:
	var squad: Dictionary = _get_squad(squad_id)
	if squad == null or squad.status != "active":
		return false
	
	if squad.members.size() >= MAX_SQUAD_SIZE:
		return false
	
	if squad.members.has(pawn_id):
		return false  # Already a member
	
	squad.members.append(pawn_id)
	squad.cohesion = minf(100.0, squad.cohesion + 2.0)
	
	return true


## Remove member from squad
func remove_member(squad_id: int, pawn_id: int) -> bool:
	var squad: Dictionary = _get_squad(squad_id)
	if squad == null:
		return false
	
	var idx: int = squad.members.find(pawn_id)
	if idx < 0:
		return false
	
	# Can't remove leader (must disband instead)
	if pawn_id == squad.leader_id:
		return false
	
	squad.members.remove_at(idx)
	squad.cohesion = maxf(0.0, squad.cohesion - 5.0)
	
	# Disband if too small
	if squad.members.size() < MIN_SQUAD_SIZE:
		disband_squad(squad_id)
	
	return true


## Set squad formation
func set_formation(squad_id: int, formation: int) -> bool:
	var squad: Dictionary = _get_squad(squad_id)
	if squad == null or squad.status != "active":
		return false
	
	squad.formation = formation
	
	# Record formation change
	if _world_memory != null:
		_world_memory.record_event({
			"type": "squad_formation_changed",
			"squad_id": squad_id,
			"formation": _formation_to_string(formation),
			"tick": GameManager.tick_count
		})
	
	return true


## Disband squad
func disband_squad(squad_id: int) -> void:
	var squad: Dictionary = _get_squad(squad_id)
	if squad == null:
		return
	
	squad.status = "disbanded"
	
	# Record disbandment
	if _world_memory != null:
		_world_memory.record_event({
			"type": "squad_disbanded",
			"squad_id": squad_id,
			"reason": "too_small" if squad.members.size() < MIN_SQUAD_SIZE else "manual",
			"tick": GameManager.tick_count
		})


# ==================== MORALE SYSTEM ====================

func _update_squad_morale(tick: int) -> void:
	for squad in squads:
		if squad.status != "active":
			continue
		
		# Morale changes based on battle outcomes
		if squad.battles_fought > 0:
			var win_rate: float = float(squad.battles_won) / float(squad.battles_fought)
			var target_morale: float = 30.0 + (win_rate * 70.0)
			squad.morale = lerpf(squad.morale, target_morale, 0.1)
		
		# Cohesion affects morale
		squad.morale = lerpf(squad.morale, squad.cohesion, 0.05)
		
		# Clamp
		squad.morale = clampf(squad.morale, 0.0, 100.0)
		
		# Check for morale break
		if squad.morale < MORALE_BREAK_THRESHOLD:
			_on_morale_break(squad)


func _on_morale_break(squad: Dictionary) -> void:
	# Squad may flee or surrender
	if _world_memory != null:
		_world_memory.record_event({
			"type": "squad_morale_broken",
			"squad_id": squad.squad_id,
			"name": squad.name,
			"morale": squad.morale,
			"tick": GameManager.tick_count
		})


## Award morale bonus
func award_morale(squad_id: int, amount: float) -> void:
	var squad: Dictionary = _get_squad(squad_id)
	if squad == null:
		return
	
	squad.morale = minf(100.0, squad.morale + amount)


## Apply morale penalty
func apply_morale_penalty(squad_id: int, amount: float) -> void:
	var squad: Dictionary = _get_squad(squad_id)
	if squad == null:
		return
	
	squad.morale = maxf(0.0, squad.morale - amount)


# ==================== COMBAT SYSTEM ====================

## Award XP to squad (shared among members)
func award_squad_xp(squad_id: int, xp: int, reason: String = "") -> void:
	var squad: Dictionary = _get_squad(squad_id)
	if squad == null:
		return
	
	squad.squad_xp += xp
	
	# Share XP with members
	if _combat_progression != null and _combat_progression.has_method("award_xp"):
		var share: int = xp / squad.members.size()
		for member_id in squad.members:
			_combat_progression.award_xp(member_id, share, "squad_" + reason)


## Record battle victory
func record_victory(squad_id: int) -> void:
	var squad: Dictionary = _get_squad(squad_id)
	if squad == null:
		return
	
	squad.battles_won += 1
	squad.battles_fought += 1
	squad.cohesion = minf(100.0, squad.cohesion + 10.0)
	award_morale(squad_id, 15.0)
	
	# Record victory
	if _world_memory != null:
		_world_memory.record_event({
			"type": "squad_victory",
			"squad_id": squad_id,
			"name": squad.name,
			"total_battles": squad.battles_fought,
			"tick": GameManager.tick_count
		})


## Record battle defeat
func record_defeat(squad_id: int) -> void:
	var squad: Dictionary = _get_squad(squad_id)
	if squad == null:
		return
	
	squad.battles_fought += 1
	squad.cohesion = maxf(0.0, squad.cohesion - 15.0)
	apply_morale_penalty(squad_id, 20.0)
	
	# Record defeat
	if _world_memory != null:
		_world_memory.record_event({
			"type": "squad_defeat",
			"squad_id": squad_id,
			"name": squad.name,
			"total_battles": squad.battles_fought,
			"tick": GameManager.tick_count
		})


# ==================== FORMATION BONUSES ====================

## Get formation bonus for a squad
func get_formation_bonus(squad_id: int, bonus_type: String) -> float:
	var squad: Dictionary = _get_squad(squad_id)
	if squad == null:
		return 0.0
	
	if not FORMATION_BONUSES.has(squad.formation):
		return 0.0
	
	var bonuses: Dictionary = FORMATION_BONUSES[squad.formation]
	return bonuses.get(bonus_type, 0.0)


## Get all formation bonuses for a squad
func get_all_formation_bonuses(squad_id: int) -> Dictionary:
	var squad: Dictionary = _get_squad(squad_id)
	if squad == null:
		return {}
	
	if not FORMATION_BONUSES.has(squad.formation):
		return {}
	
	return FORMATION_BONUSES[squad.formation].duplicate()


# ==================== UTILITY ====================

func _get_squad(squad_id: int) -> Dictionary:
	for squad in squads:
		if squad.squad_id == squad_id:
			return squad
	return {}


func _get_pawn_name(pawn_id: int) -> String:
	var pawn_spawner: Node = get_node_or_null("/root/Main/WorldViewport/PawnSpawner")
	if pawn_spawner != null and pawn_spawner.has_method("pawn_data_for_id"):
		var data: Node = pawn_spawner.call("pawn_data_for_id", pawn_id)
		if data != null and data.has_method("get_display_name"):
			return data.get_display_name()
	
	return "HeelKawnian #%d" % pawn_id


func _formation_to_string(formation: int) -> String:
	match formation:
		Formation.PHALANX: return "Phalanx"
		Formation.SKIRMISH: return "Skirmish"
		Formation.CHARGE: return "Charge"
		Formation.DEFENSIVE: return "Defensive"
		Formation.MARCH: return "March"
		Formation.CIRCLE: return "Circle"
		_: return "Unknown"


# ==================== PUBLIC API ====================

## Get squad data
func get_squad(squad_id: int) -> Dictionary:
	var squad: Dictionary = _get_squad(squad_id)
	if squad == null:
		return {}
	return squad.duplicate()

## Get all active squads
func get_all_squads() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for squad in squads:
		if squad.status == "active":
			result.append(squad.duplicate())
	return result

## Get squads by leader
func get_squads_by_leader(leader_id: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for squad in squads:
		if squad.leader_id == leader_id and squad.status == "active":
			result.append(squad.duplicate())
	return result

## Clear all data (for world reroll)
func clear() -> void:
	squads.clear()
	_next_squad_id = 1


## Find which squad a pawn belongs to. Returns -1 if not in any squad.
func get_squad_id_for_pawn(pawn_id: int) -> int:
	for squad in squads:
		if squad.status != "active":
			continue
		if pawn_id in squad.members or pawn_id == squad.leader_id:
			return int(squad.squad_id)
	return -1

## Get statistics
func get_stats() -> Dictionary:
	var active: int = 0
	var disbanded: int = 0
	var total_members: int = 0
	
	for squad in squads:
		if squad.status == "active":
			active += 1
			total_members += squad.members.size()
		else:
			disbanded += 1
	
	return {
		"total_squads": squads.size(),
		"active": active,
		"disbanded": disbanded,
		"total_members": total_members,
		"average_morale": _calculate_average_morale()
	}


func _calculate_average_morale() -> float:
	var total: float = 0.0
	var count: int = 0
	for squad in squads:
		if squad.status == "active":
			total += squad.morale
			count += 1
	return total / float(count) if count > 0 else 0.0
