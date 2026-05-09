extends Node
## AICombatProgression - Kenshi-style combat ranks (nobody → general)
##
## Combat experience → ranks:
## NOBODY → RECRUIT → SOLDIER → VETERAN → CHAMPION → GENERAL
##
## Features:
## - XP from damage dealt, enemies killed, battles survived
## - Rank unlocks based on XP + leadership demonstrations
## - Legacy traits for high-rank commanders
## - Battle reports saved to WorldMemory

# Combat rank enum
enum CombatRank {
	NOBODY,      # 0: "Just a farmer"
	RECRUIT,     # 1: "Can hold a sword"
	SOLDIER,     # 2: "Battle veteran"
	VETERAN,     # 3: "Feared warrior"
	CHAMPION,    # 4: "Legendary fighter"
	GENERAL      # 5: "Commands armies"
}

# Rank configuration
const RANK_CONFIG: Dictionary = {
	CombatRank.NOBODY: {
		"min_xp": 0,
		"name": "Nobody",
		"description": "Just a farmer",
		"combat_bonus": 0.0,
		"leadership_slots": 0
	},
	CombatRank.RECRUIT: {
		"min_xp": 50,
		"name": "Recruit",
		"description": "Can hold a sword",
		"combat_bonus": 0.1,
		"leadership_slots": 0
	},
	CombatRank.SOLDIER: {
		"min_xp": 200,
		"name": "Soldier",
		"description": "Battle veteran",
		"combat_bonus": 0.25,
		"leadership_slots": 2
	},
	CombatRank.VETERAN: {
		"min_xp": 500,
		"name": "Veteran",
		"description": "Feared warrior",
		"combat_bonus": 0.5,
		"leadership_slots": 5
	},
	CombatRank.CHAMPION: {
		"min_xp": 1000,
		"name": "Champion",
		"description": "Legendary fighter",
		"combat_bonus": 1.0,
		"leadership_slots": 10
	},
	CombatRank.GENERAL: {
		"min_xp": 2000,
		"name": "General",
		"description": "Commands armies",
		"combat_bonus": 2.0,
		"leadership_slots": 999
	}
}

# HeelKawnian combat data storage
## {
##   "pawn_id": int,
##   "combat_xp": int,
##   "rank": int,  # CombatRank enum
##   "enemies_killed": int,
##   "damage_dealt": int,
##   "damage_taken": int,
##   "battles_fought": int,
##   "battles_won": int,
##   "leadership_demonstrated": bool,
##   "legacy_trait": String
## }
var pawn_combat_data: Dictionary = {}

# References
@onready var _world_memory: Node = null
@onready var _pawn_spawner: Node = null


func _ready() -> void:
	GameManager.game_tick.connect(_on_game_tick)
	_world_memory = get_node_or_null("/root/WorldMemory")
	_pawn_spawner = get_node_or_null("/root/Main/WorldViewport/PawnSpawner")


func _on_game_tick(tick: int) -> void:
	# Auto-check rank promotions
	if tick % 100 == 0:
		_check_rank_promotions()


# ==================== XP AWARDING ====================

## Award combat XP to a pawn
func award_xp(pawn_id: int, amount: int, reason: String = "") -> void:
	if not pawn_combat_data.has(pawn_id):
		_initialize_pawn_data(pawn_id)
	
	var data: Dictionary = pawn_combat_data[pawn_id]
	data.combat_xp += amount
	
	# Record XP gain
	if _world_memory != null and amount >= 10:  # Only record significant XP gains
		_world_memory.record_event({
			"type": "combat_xp_gained",
			"pawn_id": pawn_id,
			"amount": amount,
			"reason": reason,
			"total_xp": data.combat_xp,
			"tick": GameManager.tick_count
		})


## Award XP for damage dealt
func award_damage_xp(pawn_id: int, damage: int) -> void:
	var xp: int = damage  # 1 XP per damage
	award_xp(pawn_id, xp, "damage_dealt")
	
	if pawn_combat_data.has(pawn_id):
		pawn_combat_data[pawn_id].damage_dealt += damage


## Award XP for enemy killed
func award_kill_xp(pawn_id: int, enemy_rank: int = 0) -> void:
	# Base XP + bonus based on enemy rank
	var base_xp: int = 20
	var rank_bonus: int = enemy_rank * 10
	var total_xp: int = base_xp + rank_bonus
	
	award_xp(pawn_id, total_xp, "enemy_killed")
	
	if pawn_combat_data.has(pawn_id):
		pawn_combat_data[pawn_id].enemies_killed += 1


## Award XP for surviving battle
func award_survival_xp(pawn_id: int, battle_won: bool) -> void:
	var xp: int = 10 if battle_won else 5
	award_xp(pawn_id, xp, "battle_survived")
	
	if pawn_combat_data.has(pawn_id):
		var data: Dictionary = pawn_combat_data[pawn_id]
		data.battles_fought += 1
		if battle_won:
			data.battles_won += 1


# ==================== RANK SYSTEM ====================

func _initialize_pawn_data(pawn_id: int) -> void:
	pawn_combat_data[pawn_id] = {
		"pawn_id": pawn_id,
		"combat_xp": 0,
		"rank": CombatRank.NOBODY,
		"enemies_killed": 0,
		"damage_dealt": 0,
		"damage_taken": 0,
		"battles_fought": 0,
		"battles_won": 0,
		"leadership_demonstrated": false,
		"legacy_trait": ""
	}


func _check_rank_promotions() -> void:
	for pawn_id in pawn_combat_data:
		var data: Dictionary = pawn_combat_data[pawn_id]
		var new_rank: int = _calculate_rank(data.combat_xp, data)
		
		if new_rank > data.rank:
			_promote_pawn(pawn_id, data.rank, new_rank)
			data.rank = new_rank


func _calculate_rank(xp: int, data: Dictionary) -> int:
	# Find highest rank with XP requirement met
	var rank: int = CombatRank.NOBODY
	
	for r in RANK_CONFIG.keys():
		if xp >= RANK_CONFIG[r].min_xp:
			rank = r
	
	# GENERALS must demonstrate leadership
	if rank == CombatRank.GENERAL and not data.leadership_demonstrated:
		rank = CombatRank.CHAMPION  # Cap at Champion until leadership shown
	
	return rank


func _promote_pawn(pawn_id: int, old_rank: int, new_rank: int) -> void:
	var old_name: String = RANK_CONFIG[old_rank].name
	var new_name: String = RANK_CONFIG[new_rank].name
	
	# Get pawn name for logging
	var pawn_name: String = _get_pawn_name(pawn_id)
	
	# Record promotion
	if _world_memory != null:
		_world_memory.record_event({
			"type": "combat_rank_promotion",
			"pawn_id": pawn_id,
			"pawn_name": pawn_name,
			"old_rank": old_name,
			"new_rank": new_name,
			"tick": GameManager.tick_count
		})
	
	# Award legacy trait for high ranks
	if new_rank >= CombatRank.VETERAN:
		_award_legacy_trait(pawn_id, new_rank)


func _award_legacy_trait(pawn_id: int, rank: int) -> void:
	if not pawn_combat_data.has(pawn_id):
		return
	
	var data: Dictionary = pawn_combat_data[pawn_id]
	
	# Assign legacy trait based on rank and combat style
	if data.enemies_killed > 50:
		data.legacy_trait = "Slayer"
	elif data.damage_dealt > 1000:
		data.legacy_trait = "Warrior"
	elif data.battles_won > 20:
		data.legacy_trait = "Tactician"
	elif rank == CombatRank.GENERAL:
		data.legacy_trait = "Commander"
	else:
		data.legacy_trait = "Veteran"


# ==================== LEADERSHIP SYSTEM ====================

## Mark that a pawn demonstrated leadership (required for General rank)
func demonstrate_leadership(pawn_id: int) -> void:
	if not pawn_combat_data.has(pawn_id):
		_initialize_pawn_data(pawn_id)
	
	pawn_combat_data[pawn_id].leadership_demonstrated = true
	
	# Check if eligible for General promotion now
	var data: Dictionary = pawn_combat_data[pawn_id]
	if data.combat_xp >= RANK_CONFIG[CombatRank.GENERAL].min_xp:
		_promote_pawn(pawn_id, data.rank, CombatRank.GENERAL)
		data.rank = CombatRank.GENERAL


## Get how many units a pawn can lead based on rank
func get_leadership_capacity(pawn_id: int) -> int:
	if not pawn_combat_data.has(pawn_id):
		return 0
	
	var rank: int = pawn_combat_data[pawn_id].rank
	return RANK_CONFIG[rank].leadership_slots


# ==================== COMBAT BONUSES ====================

## Get combat bonus multiplier for a pawn
func get_combat_bonus(pawn_id: int) -> float:
	if not pawn_combat_data.has(pawn_id):
		return 0.0
	
	var rank: int = pawn_combat_data[pawn_id].rank
	return RANK_CONFIG[rank].combat_bonus


## Get rank name for a pawn
func get_rank_name(pawn_id: int) -> String:
	if not pawn_combat_data.has(pawn_id):
		return RANK_CONFIG[CombatRank.NOBODY].name
	
	var rank: int = pawn_combat_data[pawn_id].rank
	return RANK_CONFIG[rank].name


## Get rank description for a pawn
func get_rank_description(pawn_id: int) -> String:
	if not pawn_combat_data.has(pawn_id):
		return RANK_CONFIG[CombatRank.NOBODY].description
	
	var rank: int = pawn_combat_data[pawn_id].rank
	return RANK_CONFIG[rank].description


# ==================== UTILITY ====================

func _get_pawn_name(pawn_id: int) -> String:
	if _pawn_spawner == null:
		return "Unknown"
	
	var data: Node = _pawn_spawner.call("pawn_data_for_id", pawn_id)
	if data != null and data.has_method("get_display_name"):
		return data.get_display_name()
	
	return "HeelKawnian #%d" % pawn_id


# ==================== PUBLIC API ====================

## Get combat data for a pawn
func get_combat_data(pawn_id: int) -> Dictionary:
	if not pawn_combat_data.has(pawn_id):
		_initialize_pawn_data(pawn_id)
	return pawn_combat_data[pawn_id].duplicate()

## Get all combat data
func get_all_combat_data() -> Dictionary:
	return pawn_combat_data.duplicate()

## Reset combat data for a pawn (for testing)
func reset_pawn_data(pawn_id: int) -> void:
	if pawn_combat_data.has(pawn_id):
		pawn_combat_data.erase(pawn_id)

## Clear all data (for world reroll)
func clear() -> void:
	pawn_combat_data.clear()

## Get statistics
func get_stats() -> Dictionary:
	var stats: Dictionary = {
		"total_pawns": pawn_combat_data.size(),
		"by_rank": {},
		"total_kills": 0,
		"generals": 0
	}
	
	# Initialize rank counts
	for rank in RANK_CONFIG.keys():
		stats.by_rank[RANK_CONFIG[rank].name] = 0
	
	# Count by rank
	for pawn_id in pawn_combat_data:
		var data: Dictionary = pawn_combat_data[pawn_id]
		var rank_name: String = RANK_CONFIG[data.rank].name
		stats.by_rank[rank_name] += 1
		stats.total_kills += data.enemies_killed
		if data.rank == CombatRank.GENERAL:
			stats.generals += 1
	
	return stats
