extends Node
## ArmyBattleSystem — Total War-style army management and battle resolution.
##
## Features:
## - Army formation from individual soldiers
## - Pre-battle strategy (positioning, formations, terrain)
## - Battle resolution with morale, flanking, supply
## - Officer command effects
## - Battle aftermath (casualties, prisoners, loot)
## - Strategic army movement on the world map
##
## Design principles:
## - Every soldier is an individual with stats
## - Battles are resolved deterministically
## - Strategy matters as much as numbers
## - Officers significantly impact battle outcomes
## - Battles have lasting consequences

# ============================================================
# CONSTANTS
# ============================================================

## Formation types
enum Formation {
	LINE,       # Standard line formation
	PHALANX,    # Dense defensive formation
	WEDGE,      # Offensive wedge
	SKIRMISH,   # Loose ranged formation
	CIRCLE,     # Defensive circle
	AMBUSCADE,  # Hidden ambush
}

const FORMATION_NAMES: PackedStringArray = [
	"Line", "Phalanx", "Wedge", "Skirmish", "Circle", "Ambuscade",
]

## Formation bonuses
const FORMATION_BONUSES: Dictionary = {
	Formation.LINE: {"melee_defense": 1.0, "ranged_defense": 1.0, "morale": 1.0, "mobility": 1.0},
	Formation.PHALANX: {"melee_defense": 1.5, "ranged_defense": 0.7, "morale": 1.2, "mobility": 0.6},
	Formation.WEDGE: {"melee_defense": 0.8, "ranged_defense": 0.9, "morale": 1.3, "mobility": 1.2},
	Formation.SKIRMISH: {"melee_defense": 0.5, "ranged_defense": 1.5, "morale": 0.8, "mobility": 1.4},
	Formation.CIRCLE: {"melee_defense": 1.3, "ranged_defense": 1.2, "morale": 1.1, "mobility": 0.5},
	Formation.AMBUSCADE: {"melee_defense": 1.0, "ranged_defense": 1.0, "morale": 1.5, "mobility": 0.8},
}

## Battle phases
enum BattlePhase {
	MARCHING,     # Armies moving to battle
	DEPLOYING,    # Setting up formations
	ENGAGING,     # Initial clash
	MELEE,        # Main combat
	RESOLVE,      # Morale breaking
	AFTERMATH,    # Casualties, prisoners
}

## How often to update battle state (ticks)
const BATTLE_UPDATE_INTERVAL: int = 30

## How often to check for new battles (ticks)
const BATTLE_CHECK_INTERVAL: int = 500

## Base morale loss per casualty
const MORALE_LOSS_PER_CASUALTY: float = 0.5

## Flanking bonus multiplier
const FLANKING_BONUS: float = 1.5

## Terrain bonuses
const TERRAIN_BONUSES: Dictionary = {
	"high_ground": {"defense": 1.3, "ranged": 1.2},
	"forest": {"defense": 1.2, "mobility": 0.7},
	"river": {"defense": 1.5, "mobility": 0.5},
	"open": {"mobility": 1.3},
}

# ============================================================
# ARMY DATA
# ============================================================

## armies: army_id -> Dictionary
## {
##   "id": int,
##   "name": String,
##   "commander_id": int,  # pawn_id of army commander
##   "nation_id": int,
##   "soldiers": Array[int],  # pawn_ids
##   "formation": int,
##   "position": Vector2,
##   "target": Vector2,
##   "morale": float,  # 0.0-100.0
##   "supply": float,  # 0.0-1.0
##   "status": String,  # "marching", "engaged", "retreating", "routed"
##   "created_tick": int,
## }
var armies: Dictionary = {}
var _next_army_id: int = 1

## battles: battle_id -> Dictionary
## {
##   "id": int,
##   "attacker_id": int,
##   "defender_id": int,
##   "location": Vector2,
##   "phase": int,
##   "tick_started": int,
##   "tick_ended": int,
##   "attacker_casualties": int,
##   "defender_casualties": int,
##   "attacker_prisoners": int,
##   "defender_prisoners": int,
##   "outcome": String,  # "attacker_victory", "defender_victory", "draw", "rout"
##   "narrative": String,
## }
var battles: Dictionary = {}
var _next_battle_id: int = 1

# ============================================================
# INITIALIZATION
# ============================================================

func _ready() -> void:
	if GameManager != null:
		GameManager.game_tick.connect(_on_game_tick)


func _on_game_tick(tick: int) -> void:
	# Update active battles
	_update_battles(tick)
	# Check for new battles
	if tick % BATTLE_CHECK_INTERVAL == 0:
		_check_battle_encounters(tick)
	# Update army positions
	_update_army_positions(tick)


# ============================================================
# ARMY MANAGEMENT
# ============================================================

func create_army(commander_id: int, nation_id: int, soldiers: Array[int], position: Vector2, tick: int) -> int:
	"""Create a new army."""
	var army_id: int = _next_army_id
	_next_army_id += 1
	var commander_name: String = _get_pawn_name(commander_id)
	armies[army_id] = {
		"id": army_id,
		"name": "%s's Army" % commander_name,
		"commander_id": commander_id,
		"nation_id": nation_id,
		"soldiers": soldiers,
		"formation": Formation.LINE,
		"position": position,
		"target": position,
		"morale": 80.0,
		"supply": 1.0,
		"status": "marching",
		"created_tick": tick,
	}
	# Set commander rank bonus
	if OfficerRankSystem != null:
		OfficerRankSystem.record_command(commander_id, soldiers.size(), tick)
	return army_id


func set_army_formation(army_id: int, formation: int) -> void:
	"""Set an army's formation."""
	var army: Dictionary = armies.get(army_id, {})
	if army.is_empty():
		return
	army["formation"] = formation


func set_army_target(army_id: int, target: Vector2) -> void:
	"""Set an army's movement target."""
	var army: Dictionary = armies.get(army_id, {})
	if army.is_empty():
		return
	army["target"] = target
	army["status"] = "marching"


# ============================================================
# BATTLE DETECTION
# ============================================================

func _check_battle_encounters(tick: int) -> void:
	"""Check if armies have encountered each other."""
	var army_ids: Array = armies.keys()
	for i in range(army_ids.size()):
		var army_a: Dictionary = armies.get(army_ids[i], {})
		if army_a.is_empty():
			continue
		for j in range(i + 1, army_ids.size()):
			var army_b: Dictionary = armies.get(army_ids[j], {})
			if army_b.is_empty():
				continue
			# Check if opposing nations
			if int(army_a.get("nation_id", -1)) == int(army_b.get("nation_id", -1)):
				continue
			# Check if at war
			if NationBorderSystem != null:
				var nation_a: Dictionary = NationBorderSystem.get_nation_by_id(int(army_a.get("nation_id", -1)))
				if nation_a.is_empty():
					continue
				var nation_b_id: int = int(army_b.get("nation_id", -1))
				if not nation_b_id in nation_a.get("at_war_with", []):
					continue
			# Check proximity
			var pos_a: Vector2 = army_a.get("position", Vector2.ZERO)
			var pos_b: Vector2 = army_b.get("position", Vector2.ZERO)
			if pos_a.distance_to(pos_b) < 5.0:
				_start_battle(army_a["id"], army_b["id"], tick)


func _start_battle(attacker_id: int, defender_id: int, tick: int) -> void:
	"""Start a battle between two armies."""
	var battle_id: int = _next_battle_id
	_next_battle_id += 1
	var attacker: Dictionary = armies.get(attacker_id, {})
	var defender: Dictionary = armies.get(defender_id, {})
	if attacker.is_empty() or defender.is_empty():
		return
	battles[battle_id] = {
		"id": battle_id,
		"attacker_id": attacker_id,
		"defender_id": defender_id,
		"location": attacker.get("position", Vector2.ZERO),
		"phase": BattlePhase.DEPLOYING,
		"tick_started": tick,
		"tick_ended": -1,
		"attacker_casualties": 0,
		"defender_casualties": 0,
		"attacker_prisoners": 0,
		"defender_prisoners": 0,
		"outcome": "",
		"narrative": "",
	}
	# Set armies to engaged
	attacker["status"] = "engaged"
	defender["status"] = "engaged"
	# Reset morale for battle
	attacker["morale"] = 80.0
	defender["morale"] = 80.0
	# Log battle start
	var attacker_name: String = str(attacker.get("name", "Unknown army"))
	var defender_name: String = str(defender.get("name", "Unknown army"))
	if ChronicleLog != null:
		ChronicleLog.append_entry(tick, "world", "Battle begins: %s vs %s!" % [attacker_name, defender_name],
			PackedStringArray(["battle_start", attacker_name, defender_name]))


# ============================================================
# BATTLE RESOLUTION
# ============================================================

func _update_battles(tick: int) -> void:
	"""Update all active battles."""
	if tick % BATTLE_UPDATE_INTERVAL != 0:
		return
	for battle_id in battles.keys():
		var battle: Dictionary = battles[battle_id]
		if str(battle.get("outcome", "")) != "":
			continue  # Already resolved
		# Advance battle phase
		var phase: int = int(battle.get("phase", BattlePhase.DEPLOYING))
		var tick_elapsed: int = tick - int(battle.get("tick_started", tick))
		if tick_elapsed < 60:
			battle["phase"] = BattlePhase.DEPLOYING
		elif tick_elapsed < 180:
			battle["phase"] = BattlePhase.ENGAGING
		elif tick_elapsed < 600:
			battle["phase"] = BattlePhase.MELEE
			_resolve_melee_phase(battle_id, tick)
		else:
			battle["phase"] = BattlePhase.RESOLVE
			_resolve_battle(battle_id, tick)


func _resolve_melee_phase(battle_id: int, tick: int) -> void:
	"""Resolve the melee phase of a battle."""
	var battle: Dictionary = battles.get(battle_id, {})
	if battle.is_empty():
		return
	var attacker: Dictionary = armies.get(int(battle.get("attacker_id", -1)), {})
	var defender: Dictionary = armies.get(int(battle.get("defender_id", -1)), {})
	if attacker.is_empty() or defender.is_empty():
		return
	# Calculate combat strength
	var attacker_strength: float = _calculate_army_strength(attacker)
	var defender_strength: float = _calculate_army_strength(defender)
	# Apply terrain bonuses
	var terrain: String = _get_terrain_at(battle.get("location", Vector2.ZERO))
	if TERRAIN_BONUSES.has(terrain):
		var bonus: Dictionary = TERRAIN_BONUSES[terrain]
		if bonus.has("defense"):
			defender_strength *= float(bonus["defense"])
	# Apply formation bonuses
	var attacker_formation: int = int(attacker.get("formation", Formation.LINE))
	var defender_formation: int = int(defender.get("formation", Formation.LINE))
	if FORMATION_BONUSES.has(attacker_formation):
		var fbonus: Dictionary = FORMATION_BONUSES[attacker_formation]
		attacker_strength *= float(fbonus.get("melee_defense", 1.0))
	if FORMATION_BONUSES.has(defender_formation):
		var fbonus: Dictionary = FORMATION_BONUSES[defender_formation]
		defender_strength *= float(fbonus.get("melee_defense", 1.0))
	# Apply officer bonuses
	var attacker_commander: int = int(attacker.get("commander_id", -1))
	var defender_commander: int = int(defender.get("commander_id", -1))
	if OfficerRankSystem != null:
		var attacker_rank: int = OfficerRankSystem.get_rank_for_pawn(attacker_commander)
		var defender_rank: int = OfficerRankSystem.get_rank_for_pawn(defender_commander)
		attacker_strength *= (1.0 + float(attacker_rank) * 0.1)
		defender_strength *= (1.0 + float(defender_rank) * 0.1)
	# Calculate casualties
	var ratio: float = attacker_strength / maxf(defender_strength, 1.0)
	var attacker_loss: float = 0.0
	var defender_loss: float = 0.0
	if ratio > 1.5:
		attacker_loss = 0.02
		defender_loss = 0.08
	elif ratio > 1.0:
		attacker_loss = 0.04
		defender_loss = 0.05
	elif ratio > 0.7:
		attacker_loss = 0.05
		defender_loss = 0.04
	else:
		attacker_loss = 0.08
		defender_loss = 0.02
	# Apply supply penalty
	if float(attacker.get("supply", 1.0)) < 0.5:
		attacker_loss *= 1.5
	if float(defender.get("supply", 1.0)) < 0.5:
		defender_loss *= 1.5
	# Update casualties
	var attacker_soldiers: int = attacker.get("soldiers", []).size()
	var defender_soldiers: int = defender.get("soldiers", []).size()
	battle["attacker_casualties"] += int(attacker_soldiers * attacker_loss)
	battle["defender_casualties"] += int(defender_soldiers * defender_loss)
	# Update morale
	attacker["morale"] = maxf(0.0, float(attacker.get("morale", 80.0)) - defender_loss * 20.0)
	defender["morale"] = maxf(0.0, float(defender.get("morale", 80.0)) - attacker_loss * 20.0)
	# Record XP for survivors
	_record_battle_xp(attacker, defender, tick)


func _calculate_army_strength(army: Dictionary) -> float:
	"""Calculate an army's combat strength."""
	var soldiers: Array = army.get("soldiers", [])
	var base_strength: float = float(soldiers.size())
	# Officer morale boost
	var commander_id: int = int(army.get("commander_id", -1))
	if OfficerRankSystem != null:
		var morale_boost: float = OfficerRankSystem.get_morale_boost_for_pawn(commander_id)
		base_strength *= (1.0 + morale_boost / 100.0)
	# Morale effect
	var morale: float = float(army.get("morale", 80.0))
	base_strength *= (morale / 100.0)
	return base_strength


func _resolve_battle(battle_id: int, tick: int) -> void:
	"""Resolve the final outcome of a battle."""
	var battle: Dictionary = battles.get(battle_id, {})
	if battle.is_empty():
		return
	var attacker: Dictionary = armies.get(int(battle.get("attacker_id", -1)), {})
	var defender: Dictionary = armies.get(int(battle.get("defender_id", -1)), {})
	if attacker.is_empty() or defender.is_empty():
		return
	# Determine outcome
	var attacker_morale: float = float(attacker.get("morale", 0.0))
	var defender_morale: float = float(defender.get("morale", 0.0))
	var outcome: String = ""
	if attacker_morale <= 0:
		outcome = "defender_victory"
		attacker["status"] = "routed"
	elif defender_morale <= 0:
		outcome = "attacker_victory"
		defender["status"] = "routed"
	elif attacker_morale > defender_morale + 20:
		outcome = "attacker_victory"
		defender["status"] = "retreating"
	elif defender_morale > attacker_morale + 20:
		outcome = "defender_victory"
		attacker["status"] = "retreating"
	else:
		outcome = "draw"
		attacker["status"] = "retreating"
		defender["status"] = "retreating"
	battle["outcome"] = outcome
	battle["tick_ended"] = tick
	# Generate narrative
	battle["narrative"] = _generate_battle_narrative(battle, attacker, defender)
	# Record battle results for officers
	_record_battle_results(battle, attacker, defender, tick)
	# Log battle end
	var attacker_name: String = str(attacker.get("name", "Unknown"))
	var defender_name: String = str(defender.get("name", "Unknown"))
	if ChronicleLog != null:
		ChronicleLog.append_entry(tick, "world", "Battle ended: %s. %s vs %s. %s" % [
			outcome.replace("_", " ").capitalize(), attacker_name, defender_name, battle.get("narrative", "")],
			PackedStringArray(["battle_end", outcome, attacker_name, defender_name]))


func _generate_battle_narrative(battle: Dictionary, attacker: Dictionary, defender: Dictionary) -> String:
	"""Generate a narrative description of the battle."""
	var attacker_cas: int = int(battle.get("attacker_casualties", 0))
	var defender_cas: int = int(battle.get("defender_casualties", 0))
	var outcome: String = battle.get("outcome", "")
	var narrative: String = ""
	if outcome == "attacker_victory":
		narrative += "%s broke through %s's lines. " % [attacker.get("name", "The attackers"), defender.get("name", "the defenders")]
	elif outcome == "defender_victory":
		narrative += "%s held firm against %s's assault. " % [defender.get("name", "The defenders"), attacker.get("name", "the attackers")]
	else:
		narrative += "Neither side could gain the upper hand. "
	if attacker_cas > defender_cas * 2:
		narrative += "Heavy losses on both sides."
	elif defender_cas > attacker_cas * 2:
		narrative += "A decisive victory with minimal losses."
	else:
		narrative += "Both sides suffered comparable losses."
	return narrative


func _record_battle_xp(attacker: Dictionary, defender: Dictionary, tick: int) -> void:
	"""Record XP for soldiers in battle."""
	var attacker_commander: int = int(attacker.get("commander_id", -1))
	var defender_commander: int = int(defender.get("commander_id", -1))
	if OfficerRankSystem != null:
		# Commander XP
		OfficerRankSystem.record_command(attacker_commander, attacker.get("soldiers", []).size(), tick)
		OfficerRankSystem.record_command(defender_commander, defender.get("soldiers", []).size(), tick)


func _record_battle_results(battle: Dictionary, attacker: Dictionary, defender: Dictionary, tick: int) -> void:
	"""Record battle results for officer ranks."""
	var outcome: String = battle.get("outcome", "")
	var victory: bool = outcome == "attacker_victory" or outcome == "defender_victory"
	var attacker_commander: int = int(attacker.get("commander_id", -1))
	var defender_commander: int = int(defender.get("commander_id", -1))
	if OfficerRankSystem != null:
		OfficerRankSystem.record_battle_survival(attacker_commander, outcome == "attacker_victory" or outcome == "draw", tick)
		OfficerRankSystem.record_battle_survival(defender_commander, outcome == "defender_victory" or outcome == "draw", tick)


# ============================================================
# ARMY MOVEMENT
# ============================================================

func _update_army_positions(tick: int) -> void:
	"""Update army positions based on movement."""
	for army_id in armies.keys():
		var army: Dictionary = armies[army_id]
		if str(army.get("status", "")) != "marching":
			continue
		var pos: Vector2 = army.get("position", Vector2.ZERO)
		var target: Vector2 = army.get("target", Vector2.ZERO)
		var speed: float = 0.3  # Base movement speed
		# Formation affects speed
		var formation: int = int(army.get("formation", Formation.LINE))
		if FORMATION_BONUSES.has(formation):
			speed *= float(FORMATION_BONUSES[formation].get("mobility", 1.0))
		# Supply affects speed
		var supply: float = float(army.get("supply", 1.0))
		if supply < 0.3:
			speed *= 0.5
		# Move toward target
		var direction: Vector2 = (target - pos).normalized()
		var new_pos: Vector2 = pos + direction * speed
		army["position"] = new_pos
		# Check if arrived
		if new_pos.distance_to(target) < 1.0:
			army["status"] = "deployed"


# ============================================================
# HELPERS
# ============================================================

func _get_pawn_name(pawn_id: int) -> String:
	var pawn: Node = _get_pawn_by_id(pawn_id)
	if pawn == null or pawn.data == null:
		return "Unknown"
	var _name = pawn.data.get("name")
	if _name == null:
		return "Unknown"
	return str(_name)


func _get_pawn_by_id(pawn_id: int) -> Node:
	if PawnAccess == null:
		return null
	var pawns: Array = PawnAccess.find_alive_pawns()
	for p in pawns:
		if p != null and is_instance_valid(p) and p.data != null:
			if int(p.data.id) == pawn_id:
				return p
	return null


func _get_terrain_at(pos: Vector2) -> String:
	"""Determine terrain type at a position."""
	# Simplified terrain detection
	# In full implementation, this would query the world data
	return "open"


# ============================================================
# PUBLIC API
# ============================================================

func get_army(army_id: int) -> Dictionary:
	return armies.get(army_id, {})


func get_battle(battle_id: int) -> Dictionary:
	return battles.get(battle_id, {})


func get_active_armies() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for army_id in armies.keys():
		result.append(armies[army_id])
	return result


func get_active_battles() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for battle_id in battles.keys():
		var battle: Dictionary = battles[battle_id]
		if str(battle.get("outcome", "")) == "":
			result.append(battle)
	return result


func get_army_count() -> int:
	return armies.size()


func get_battle_count() -> int:
	return battles.size()
