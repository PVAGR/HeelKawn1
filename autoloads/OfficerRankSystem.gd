extends Node
## OfficerRankSystem — Dynasty Warriors/Bannerlord-style officer emergence and rank progression.
##
## Warriors rise through ranks organically based on:
## - Combat performance (kills, survival, victories)
## - Leadership (commanding units, morale boosting)
## - Loyalty to their settlement/nation
## - Charisma and reputation
## - Experience from battles
##
## Design principles:
## - Ranks are earned, not assigned
## - Every soldier can become a general
## - Officers inspire loyalty in nearby troops
## - Famous warriors become legends
## - Rank affects combat effectiveness and command authority

# ============================================================
# CONSTANTS
# ============================================================

## Rank levels
enum Rank {
	RECRUIT,      # Fresh soldier
	SOLDIER,      # Basic fighter
	VETERAN,      # Experienced fighter
	SERGEANT,     # Squad leader
	CAPTAIN,      # Company commander
	OFFICER,      # Field officer
	COMMANDER,    # Battle commander
	GENERAL,      # Army leader
	WARLORD,      # Legendary leader
	CHAMPION,     # Mythic warrior
}

const RANK_NAMES: PackedStringArray = [
	"Recruit", "Soldier", "Veteran", "Sergeant", "Captain",
	"Officer", "Commander", "General", "Warlord", "Champion",
]

const RANK_TITLES: PackedStringArray = [
	"", "", "", "the Steadfast", "the Bold",
	"the Wise", "the Victor", "the Mighty", "the Conqueror", "the Legend",
]

## XP thresholds for each rank
const RANK_XP_THRESHOLDS: PackedInt32Array = [
	0,      # Recruit
	100,    # Soldier
	500,    # Veteran
	1500,   # Sergeant
	4000,   # Captain
	10000,  # Officer
	25000,  # Commander
	60000,  # General
	150000, # Warlord
	400000, # Champion
]

## XP rewards
const XP_KILL: int = 50
const XP_SURVIVE_BATTLE: int = 25
const XP_VICTORY: int = 100
const XP_COMMAND_BONUS: int = 10  # Per unit commanded
const XP_WOUND: int = 15  # Surviving a wound
const XP_LEADERSHIP: int = 5  # Per tick of leadership

## How often to check for rank promotions (ticks)
const PROMOTION_CHECK_INTERVAL: int = 500

## How often to update officer influence (ticks)
const INFLUENCE_UPDATE_INTERVAL: int = 120

## Morale boost radius for officers (tiles)
const OFFICER_MORALE_RADIUS: int = 8

## Loyalty decay rate (per tick without battle)
const LOYALTY_DECAY_RATE: float = 0.001

# ============================================================
# OFFICER DATA
# ============================================================

## pawn_id -> officer data
## {
##   "pawn_id": int,
##   "rank": int,
##   "xp": int,
##   "kills": int,
##   "battles_fought": int,
##   "battles_won": int,
##   "battles_lost": int,
##   "wounds_sustained": int,
##   "units_commanded": int,
##   "loyalty": float,  # 0.0-1.0
##   "reputation": float,  # -100 to 100
##   "specialization": String,  # "melee", "ranged", "tactics", "command"
##   "titles": Array[String],
##   "last_battle_tick": int,
##   "morale_boost": float,  # How much morale they provide to nearby troops
##   "command_radius": float,
## }
var officers: Dictionary = {}

## Famous warriors (rank >= COMMANDER)
var famous_warriors: Array[Dictionary] = []

## Officer influence zones: officer_id -> {radius: float, affected_pawns: Array[int]}
var officer_influence: Dictionary = {}

# ============================================================
# INITIALIZATION
# ============================================================

func _ready() -> void:
	if GameManager != null:
		GameManager.game_tick.connect(_on_game_tick)


func _on_game_tick(tick: int) -> void:
	# Check for promotions
	if tick % PROMOTION_CHECK_INTERVAL == 0:
		_check_promotions(tick)
	# Update officer influence
	if tick % INFLUENCE_UPDATE_INTERVAL == 0:
		_update_officer_influence(tick)
	# Decay loyalty for inactive officers
	_decay_officer_loyalty(tick)


# ============================================================
# COMBAT XP TRACKING
# ============================================================

func record_kill(pawn_id: int, tick: int) -> void:
	"""Record a kill for a pawn."""
	_ensure_officer_record(pawn_id)
	if not officers.has(pawn_id):
		return
	var officer: Dictionary = officers[pawn_id]
	officer["xp"] += XP_KILL
	officer["kills"] += 1
	officer["last_battle_tick"] = tick
	# Reputation boost
	officer["reputation"] = minf(100.0, float(officer.get("reputation", 0.0)) + 2.0)


func record_battle_survival(pawn_id: int, victory: bool, tick: int) -> void:
	"""Record surviving a battle."""
	_ensure_officer_record(pawn_id)
	if not officers.has(pawn_id):
		return
	var officer: Dictionary = officers[pawn_id]
	officer["xp"] += XP_SURVIVE_BATTLE
	officer["battles_fought"] += 1
	if victory:
		officer["xp"] += XP_VICTORY
		officer["battles_won"] += 1
	else:
		officer["battles_lost"] += 1
	officer["last_battle_tick"] = tick
	# Loyalty boost for fighting for their side
	officer["loyalty"] = minf(1.0, float(officer.get("loyalty", 0.5)) + 0.02)


func record_wound(pawn_id: int, tick: int) -> void:
	"""Record surviving a wound."""
	_ensure_officer_record(pawn_id)
	if not officers.has(pawn_id):
		return
	var officer: Dictionary = officers[pawn_id]
	officer["xp"] += XP_WOUND
	officer["wounds_sustained"] += 1


func record_command(pawn_id: int, units_count: int, tick: int) -> void:
	"""Record commanding units in battle."""
	_ensure_officer_record(pawn_id)
	if not officers.has(pawn_id):
		return
	var officer: Dictionary = officers[pawn_id]
	officer["xp"] += XP_COMMAND_BONUS * units_count
	officer["units_commanded"] = maxi(officer.get("units_commanded", 0), units_count)


# ============================================================
# PROMOTION SYSTEM
# ============================================================

func _check_promotions(tick: int) -> void:
	"""Check all officers for rank promotions."""
	for pawn_id in officers.keys():
		var officer: Dictionary = officers[pawn_id]
		var current_rank: int = int(officer.get("rank", Rank.RECRUIT))
		var xp: int = int(officer.get("xp", 0))
		# Check if eligible for next rank
		var next_rank: int = current_rank + 1
		if next_rank >= RANK_XP_THRESHOLDS.size():
			continue  # Max rank
		var threshold: int = RANK_XP_THRESHOLDS[next_rank]
		if xp >= threshold:
			_promote_officer(pawn_id, next_rank, tick)


func _promote_officer(pawn_id: int, new_rank: int, tick: int) -> void:
	"""Promote an officer to a new rank."""
	var officer: Dictionary = officers.get(pawn_id, {})
	if officer.is_empty():
		return
	var old_rank: int = int(officer.get("rank", Rank.RECRUIT))
	officer["rank"] = new_rank
	# Add title for significant promotions
	if new_rank >= Rank.SERGEANT:
		var title: String = RANK_TITLES[new_rank]
		if title != "" and not title in officer.get("titles", []):
			officer["titles"].append(title)
	# Update morale boost based on rank
	officer["morale_boost"] = _calculate_morale_boost(new_rank)
	officer["command_radius"] = _calculate_command_radius(new_rank)
	# Update specialization based on combat history
	officer["specialization"] = _determine_specialization(officer)
	# Log promotion
	var pawn_name: String = _get_pawn_name(pawn_id)
	var rank_name: String = RANK_NAMES[new_rank]
	if ChronicleLog != null:
		ChronicleLog.append_entry(tick, "world", "%s has been promoted to %s!" % [pawn_name, rank_name],
			PackedStringArray(["promotion", pawn_name, rank_name]))
	# Track famous warriors
	if new_rank >= Rank.COMMANDER:
		_add_to_famous_warriors(pawn_id, tick)


func _calculate_morale_boost(rank: int) -> float:
	"""Calculate morale boost based on rank."""
	match rank:
		Rank.RECRUIT: return 0.0
		Rank.SOLDIER: return 2.0
		Rank.VETERAN: return 5.0
		Rank.SERGEANT: return 10.0
		Rank.CAPTAIN: return 15.0
		Rank.OFFICER: return 20.0
		Rank.COMMANDER: return 30.0
		Rank.GENERAL: return 40.0
		Rank.WARLORD: return 50.0
		Rank.CHAMPION: return 60.0
		_: return 0.0


func _calculate_command_radius(rank: int) -> float:
	"""Calculate command radius based on rank."""
	match rank:
		Rank.RECRUIT, Rank.SOLDIER: return 0.0
		Rank.VETERAN: return 3.0
		Rank.SERGEANT: return 5.0
		Rank.CAPTAIN: return 8.0
		Rank.OFFICER: return 12.0
		Rank.COMMANDER: return 16.0
		Rank.GENERAL: return 24.0
		Rank.WARLORD: return 32.0
		Rank.CHAMPION: return 48.0
		_: return 0.0


func _determine_specialization(officer: Dictionary) -> String:
	"""Determine officer's combat specialization."""
	var kills: int = int(officer.get("kills", 0))
	var battles: int = int(officer.get("battles_fought", 0))
	var commanded: int = int(officer.get("units_commanded", 0))
	var wounds: int = int(officer.get("wounds_sustained", 0))
	# Determine based on combat style
	if commanded > battles * 5:
		return "command"
	elif kills > battles * 10:
		return "melee"
	elif wounds > battles * 2:
		return "tactics"  # Survived many battles through strategy
	else:
		return "melee"


# ============================================================
# OFFICER INFLUENCE
# ============================================================

func _update_officer_influence(tick: int) -> void:
	"""Update officer influence zones for nearby troops."""
	if PawnAccess == null:
		return
	var pawns: Array = PawnAccess.find_alive_pawns()
	# Clear old influence
	officer_influence.clear()
	# Build influence zones for each officer
	for pawn_id in officers.keys():
		var officer: Dictionary = officers[pawn_id]
		var rank: int = int(officer.get("rank", Rank.RECRUIT))
		if rank < Rank.VETERAN:
			continue  # Only veterans and above have influence
		var pawn: Node = _get_pawn_by_id(pawn_id)
		if pawn == null or pawn.data == null:
			continue
		var pos: Vector2i = pawn.data.tile_pos
		var radius: float = float(officer.get("command_radius", 0.0))
		if radius <= 0:
			continue
		# Find pawns in range
		var affected: Array[int] = []
		for other in pawns:
			if other == null or not is_instance_valid(other) or other.data == null:
				continue
			var other_id: int = int(other.data.id)
			if other_id == pawn_id:
				continue
			var other_pos: Vector2i = other.data.tile_pos
			if pos.distance_to(other_pos) <= radius:
				affected.append(other_id)
		officer_influence[pawn_id] = {
			"radius": radius,
			"affected_pawns": affected,
			"morale_boost": float(officer.get("morale_boost", 0.0)),
		}


func get_morale_boost_for_pawn(pawn_id: int) -> float:
	"""Get morale boost for a pawn from nearby officers."""
	var total_boost: float = 0.0
	for officer_id in officer_influence.keys():
		var influence: Dictionary = officer_influence[officer_id]
		if pawn_id in influence.get("affected_pawns", []):
			total_boost += float(influence.get("morale_boost", 0.0))
	return total_boost


# ============================================================
# LOYALTY SYSTEM
# ============================================================

func _decay_officer_loyalty(tick: int) -> void:
	"""Decay loyalty for officers who haven't fought recently."""
	for pawn_id in officers.keys():
		var officer: Dictionary = officers[pawn_id]
		var last_battle: int = int(officer.get("last_battle_tick", 0))
		if last_battle > 0:
			var ticks_since_battle: int = tick - last_battle
			if ticks_since_battle > 5000:
				officer["loyalty"] = maxf(0.0, float(officer.get("loyalty", 0.5)) - LOYALTY_DECAY_RATE)


# ============================================================
# FAMOUS WARRIORS
# ============================================================

func _add_to_famous_warriors(pawn_id: int, tick: int) -> void:
	"""Add a warrior to the famous warriors list."""
	var officer: Dictionary = officers.get(pawn_id, {})
	if officer.is_empty():
		return
	var entry: Dictionary = {
		"pawn_id": pawn_id,
		"name": _get_pawn_name(pawn_id),
		"rank": int(officer.get("rank", 0)),
		"rank_name": RANK_NAMES[int(officer.get("rank", 0))],
		"kills": int(officer.get("kills", 0)),
		"battles": int(officer.get("battles_fought", 0)),
		"specialization": str(officer.get("specialization", "unknown")),
		"recorded_tick": tick,
	}
	# Check if already in list
	for i in range(famous_warriors.size()):
		if int(famous_warriors[i].get("pawn_id", -1)) == pawn_id:
			famous_warriors[i] = entry
			return
	famous_warriors.append(entry)
	# Log famous warrior
	if ChronicleNarrativeSystem != null:
		ChronicleNarrativeSystem._add_narrative(tick, "immediate", "warrior",
			"%s has risen to the rank of %s with %d kills in %d battles. They are known as %s." % [
				entry["name"], entry["rank_name"], entry["kills"], entry["battles"],
				str(officer.get("specialization", "a warrior")),
			],
			["famous_warrior", entry["name"]])


# ============================================================
# HELPERS
# ============================================================

func _ensure_officer_record(pawn_id: int) -> void:
	"""Ensure an officer record exists for a pawn."""
	if officers.has(pawn_id):
		return
	officers[pawn_id] = {
		"pawn_id": pawn_id,
		"rank": Rank.RECRUIT,
		"xp": 0,
		"kills": 0,
		"battles_fought": 0,
		"battles_won": 0,
		"battles_lost": 0,
		"wounds_sustained": 0,
		"units_commanded": 0,
		"loyalty": 0.5,
		"reputation": 0.0,
		"specialization": "melee",
		"titles": [],
		"last_battle_tick": 0,
		"morale_boost": 0.0,
		"command_radius": 0.0,
	}


func _get_pawn_name(pawn_id: int) -> String:
	"""Get a pawn's name."""
	var pawn: Node = _get_pawn_by_id(pawn_id)
	if pawn == null or pawn.data == null:
		return "Unknown"
	return str(pawn.data.get("name", "Unknown"))


func _get_pawn_by_id(pawn_id: int) -> Node:
	if PawnAccess == null:
		return null
	var pawns: Array = PawnAccess.find_alive_pawns()
	for p in pawns:
		if p != null and is_instance_valid(p) and p.data != null:
			if int(p.data.id) == pawn_id:
				return p
	return null


# ============================================================
# PUBLIC API
# ============================================================

func get_officer_data(pawn_id: int) -> Dictionary:
	return officers.get(pawn_id, {})


func get_rank_for_pawn(pawn_id: int) -> int:
	var officer: Dictionary = officers.get(pawn_id, {})
	return int(officer.get("rank", Rank.RECRUIT))


func get_rank_name(rank: int) -> String:
	if rank < 0 or rank >= RANK_NAMES.size():
		return "Unknown"
	return RANK_NAMES[rank]


func get_famous_warriors() -> Array[Dictionary]:
	return famous_warriors.duplicate()


func get_officer_count() -> int:
	return officers.size()


func get_officers_by_rank(rank: int) -> Array[int]:
	var result: Array[int] = []
	for pawn_id in officers.keys():
		if int(officers[pawn_id].get("rank", 0)) == rank:
			result.append(pawn_id)
	return result


func get_xp_for_rank(rank: int) -> int:
	if rank < 0 or rank >= RANK_XP_THRESHOLDS.size():
		return 0
	return RANK_XP_THRESHOLDS[rank]


func get_progress_to_next_rank(pawn_id: int) -> float:
	var officer: Dictionary = officers.get(pawn_id, {})
	if officer.is_empty():
		return 0.0
	var current_rank: int = int(officer.get("rank", 0))
	var next_rank: int = current_rank + 1
	if next_rank >= RANK_XP_THRESHOLDS.size():
		return 1.0
	var current_xp: int = int(officer.get("xp", 0))
	var current_threshold: int = RANK_XP_THRESHOLDS[current_rank]
	var next_threshold: int = RANK_XP_THRESHOLDS[next_rank]
	if next_threshold <= current_threshold:
		return 1.0
	return clampf(float(current_xp - current_threshold) / float(next_threshold - current_threshold), 0.0, 1.0)
