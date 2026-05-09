extends Node
## GuildSystem - The Ultimate Guild System for HeelKawn
##
## Features:
## - 12 guild types for all playstyles
## - Guild XP, levels (1-100), and 5 rank tiers
## - Unlockable guild perks
## - Guild quests (daily/weekly)
## - Guild prestige & reputation
## - Guild halls (physical buildings)
## - Clean, professional UI
## - Recorded in WorldMemory

# Guild types (all playstyles supported)
enum GuildType {
	FARMERS,      # Food production
	WARRIORS,     # Combat, defense
	BUILDERS,     # Construction
	SCHOLARS,     # Research, knowledge
	TRADERS,      # Commerce, trade
	SAILORS,      # Naval, fishing
	ADVENTURERS,  # Exploration, ruins
	CRAFTERS,     # Crafting, smithing
	HUNTERS,      # Hunting, tracking
	HEALERS,      # Medicine, healthcare
	MINERS,       # Mining, quarrying
	GENERAL       # Mixed-purpose guild
}

# Guild member data structure
## {
##   "pawn_id": int,
##   "guild_xp": int,
##   "guild_level": int,
##   "guild_rank": int,  # 0-4 (Initiate to Grandmaster)
##   "joined_tick": int,
##   "quests_completed": int,
##   "prestige": int  # Personal prestige with guild
## }

# Guild data structure
## {
##   "guild_id": int,
##   "name": String,
##   "type": int,  # GuildType enum
##   "guild_type": String,  # For event logging
##   "leader_id": int,
##   "officers": Array[int],  # pawn_ids
##   "members": Array[int],  # pawn_ids
##   "member_data": Dictionary,  # {pawn_id: member_data}
##   "guild_xp": int,
##   "guild_level": int,
##   "reputation": int,  # -1000 to 1000
##   "trust": float,  # 0-100 (internal cohesion)
##   "treasury": Dictionary,  # {resource: quantity}
##   "memory": Array[Dictionary],  # guild history
##   "perks_unlocked": Array[int],  # Unlocked perk IDs
##   "quests": Array[Dictionary],  # Active quests
##   "created_tick": int,
##   "status": String  # "active", "disbanded", "destroyed"
## }
var guilds: Array[Dictionary] = []
var _next_guild_id: int = 1

# Guild ranks (5 tiers)
const GUILD_RANKS: Array[String] = [
	"Initiate",      # 0
	"Apprentice",    # 1
	"Journeyman",    # 2
	"Master",        # 3
	"Grandmaster"    # 4
]

# Guild levels & XP
const GUILD_LEVEL_CAP: int = 100
const XP_PER_LEVEL_BASE: int = 100
const XP_CURVE: float = 1.15  # Each level needs 15% more XP

# Member rank XP requirements
const MEMBER_RANK_XP: Array[int] = [
	0,      # Initiate
	500,    # Apprentice
	2000,   # Journeyman
	10000,  # Master
	50000   # Grandmaster
]

# Guild perks (unlock at guild levels 10, 20, 30, 50, 100)
const GUILD_PERKS: Array[Dictionary] = [
	{"level": 10, "name": "Guild Discount", "effect": "shop_discount", "value": 0.1},
	{"level": 20, "name": "Shared Knowledge", "effect": "xp_bonus", "value": 0.15},
	{"level": 30, "name": "Guild Hall", "effect": "unlock_hall", "value": 1},
	{"level": 50, "name": "Master Craftsmen", "effect": "quality_bonus", "value": 0.25},
	{"level": 100, "name": "Legendary Status", "effect": "prestige_bonus", "value": 0.5}
]

# Guild type names
const GUILD_TYPE_NAMES: Dictionary = {
	GuildType.FARMERS: "Farmers Guild",
	GuildType.WARRIORS: "Warriors Guild",
	GuildType.BUILDERS: "Builders Guild",
	GuildType.SCHOLARS: "Scholars Guild",
	GuildType.TRADERS: "Traders Guild",
	GuildType.SAILORS: "Sailors Guild",
	GuildType.ADVENTURERS: "Adventurers Guild",
	GuildType.CRAFTERS: "Crafters Guild",
	GuildType.HUNTERS: "Hunters Guild",
	GuildType.HEALERS: "Healers Guild",
	GuildType.MINERS: "Miners Guild",
	GuildType.GENERAL: "Guild"
}

# Guild type icons (emoji for UI)
const GUILD_TYPE_ICONS: Dictionary = {
	GuildType.FARMERS: "🌾",
	GuildType.WARRIORS: "⚔️",
	GuildType.BUILDERS: "🔨",
	GuildType.SCHOLARS: "📚",
	GuildType.TRADERS: "💰",
	GuildType.SAILORS: "⚓",
	GuildType.ADVENTURERS: "🗺️",
	GuildType.CRAFTERS: "⚒️",
	GuildType.HUNTERS: "🏹",
	GuildType.HEALERS: "💚",
	GuildType.MINERS: "⛏️",
	GuildType.GENERAL: "🏛️"
}

# Configuration
const MAX_GUILD_SIZE: int = 100
const MIN_TRUST_FOR_COOPERATION: float = 30.0
const TRUST_GAIN_PER_SUCCESS: float = 5.0
const TRUST_LOSS_PER_FAILURE: float = 10.0
const TRUST_DECAY_PER_TICK: float = 0.001  # Slow decay over time

# References
@onready var _world_memory: Node = null
@onready var _settlement_memory: Node = null


func _ready() -> void:
	GameManager.game_tick.connect(_on_game_tick)
	_world_memory = get_node_or_null("/root/WorldMemory")
	_settlement_memory = get_node_or_null("/root/SettlementMemory")


func _on_game_tick(tick: int) -> void:
	# Slow trust decay (relationships need maintenance)
	if tick % 1000 == 0:
		_decay_guild_trust()


# ==================== GUILD CREATION ====================

## Create a new guild
func create_guild(leader_id: int, guild_type: int, name: String = "") -> int:
	# Validate leader
	if not _is_valid_leader(leader_id):
		return -1
	
	# Generate name if not provided
	if name == "":
		name = _generate_guild_name(guild_type, leader_id)
	
	# Create guild
	var guild: Dictionary = {
		"guild_id": _next_guild_id,
		"name": name,
		"type": guild_type,
		"guild_type": _guild_type_to_string(guild_type),
		"leader_id": leader_id,
		"officers": [],
		"members": [leader_id],
		"member_data": {
			str(leader_id): {
				"pawn_id": leader_id,
				"guild_xp": 0,
				"guild_level": 1,
				"guild_rank": 0,  # Initiate
				"joined_tick": GameManager.tick_count,
				"quests_completed": 0,
				"prestige": 0
			}
		},
		"guild_xp": 0,
		"guild_level": 1,
		"reputation": 0,
		"trust": 50.0,
		"treasury": {},
		"memory": [],
		"perks_unlocked": [],
		"quests": [],
		"created_tick": GameManager.tick_count,
		"status": "active"
	}
	
	guilds.append(guild)
	_next_guild_id += 1
	
	# Record creation
	if _world_memory != null:
		_world_memory.record_event({
			"type": "guild_created",
			"guild_id": guild.guild_id,
			"name": guild.name,
			"guild_type": _guild_type_to_string(guild_type),
			"leader_id": leader_id,
			"tick": GameManager.tick_count
		})
	
	return guild.guild_id


func _is_valid_leader(leader_id: int) -> bool:
	# Check if pawn exists and is capable
	# For now, allow any pawn to lead
	return true


func _generate_guild_name(guild_type: int, leader_id: int) -> String:
	var type_name: String = GUILD_TYPE_NAMES.get(guild_type, "Guild")
	var leader_name: String = _get_pawn_name(leader_id)
	
	# Generate thematic names
	match guild_type:
		GuildType.WARRIORS:
			return "%s's Warriors" % leader_name
		GuildType.FARMERS:
			return "%s's Farmers Collective" % leader_name
		GuildType.ADVENTURERS:
			return "%s's Explorers" % leader_name
		_:
			return "%s's %s" % [leader_name, type_name]


# ==================== GUILD MANAGEMENT ====================

## Add member to guild
func add_member(guild_id: int, pawn_id: int) -> bool:
	var guild: Dictionary = _get_guild(guild_id)
	if guild == null or guild.status != "active":
		return false
	
	if guild.members.has(pawn_id):
		return false  # Already a member
	
	if guild.members.size() >= MAX_GUILD_SIZE:
		return false  # Guild full
	
	guild.members.append(pawn_id)
	guild.trust = minf(100.0, guild.trust + 1.0)
	
	# Record joining
	_add_guild_memory(guild_id, "member_joined", {
		"pawn_id": pawn_id,
		"tick": GameManager.tick_count
	})
	
	return true


## Remove member from guild
func remove_member(guild_id: int, pawn_id: int) -> bool:
	var guild: Dictionary = _get_guild(guild_id)
	if guild == null:
		return false
	
	var idx: int = guild.members.find(pawn_id)
	if idx < 0:
		return false  # Not a member
	
	# Can't remove leader this way (must disband or succession)
	if pawn_id == guild.leader_id:
		return false
	
	guild.members.remove_at(idx)
	
	# Remove from officers if present
	var officer_idx: int = guild.officers.find(pawn_id)
	if officer_idx >= 0:
		guild.officers.remove_at(officer_idx)
	
	guild.trust = maxf(0.0, guild.trust - 5.0)
	
	# Record departure
	_add_guild_memory(guild_id, "member_left", {
		"pawn_id": pawn_id,
		"tick": GameManager.tick_count
	})
	
	return true


## Promote member to officer
func promote_to_officer(guild_id: int, pawn_id: int) -> bool:
	var guild: Dictionary = _get_guild(guild_id)
	if guild == null or guild.status != "active":
		return false
	
	if not guild.members.has(pawn_id):
		return false  # Not a member
	
	if guild.officers.has(pawn_id):
		return false  # Already officer
	
	guild.officers.append(pawn_id)
	
	# Record promotion
	_add_guild_memory(guild_id, "officer_promoted", {
		"pawn_id": pawn_id,
		"tick": GameManager.tick_count
	})
	
	return true


## Demote officer
func demote_officer(guild_id: int, pawn_id: int) -> bool:
	var guild: Dictionary = _get_guild(guild_id)
	if guild == null:
		return false
	
	var idx: int = guild.officers.find(pawn_id)
	if idx < 0:
		return false  # Not an officer
	
	guild.officers.remove_at(idx)
	guild.trust = maxf(0.0, guild.trust - 3.0)
	
	# Record demotion
	_add_guild_memory(guild_id, "officer_demoted", {
		"pawn_id": pawn_id,
		"tick": GameManager.tick_count
	})

	return true


# ==================== GUILD XP & LEVELS ====================

## Award XP to guild
func award_guild_xp(guild_id: int, xp: int, reason: String = "") -> void:
	var guild: Dictionary = _get_guild(guild_id)
	if guild == null or guild.status != "active":
		return
	
	guild.guild_xp += xp
	
	# Check for level up
	var old_level: int = guild.guild_level
	var new_level: int = _calculate_guild_xp(guild.guild_xp)
	
	if new_level > old_level:
		guild.guild_level = new_level
		_on_guild_level_up(guild_id, old_level, new_level)
	
	# Record XP gain
	if _world_memory != null and xp >= 10:
		_world_memory.record_event({
			"type": "guild_xp_gained",
			"guild_id": guild_id,
			"xp": xp,
			"reason": reason,
			"tick": GameManager.tick_count
		})


## Award XP to guild member
func award_member_xp(guild_id: int, pawn_id: int, xp: int, reason: String = "") -> void:
	var guild: Dictionary = _get_guild(guild_id)
	if guild == null or guild.status != "active":
		return
	
	if not guild.member_data.has(str(pawn_id)):
		return
	
	var member_data: Dictionary = guild.member_data[str(pawn_id)]
	member_data.guild_xp += xp
	
	# Check for member level up
	var old_level: int = member_data.guild_level
	var new_level: int = _calculate_member_level(member_data.guild_xp)
	
	if new_level > old_level:
		member_data.guild_level = new_level
		_on_member_level_up(guild_id, pawn_id, old_level, new_level)
	
	# Check for rank up
	var new_rank: int = _calculate_member_rank(member_data.guild_xp)
	if new_rank > member_data.guild_rank:
		member_data.guild_rank = new_rank
		_on_member_rank_up(guild_id, pawn_id, new_rank)


## Calculate guild level from XP
func _calculate_guild_xp(total_xp: int) -> int:
	var level: int = 1
	var xp_required: int = XP_PER_LEVEL_BASE
	
	while total_xp >= xp_required and level < GUILD_LEVEL_CAP:
		total_xp -= xp_required
		level += 1
		xp_required = int(xp_required * XP_CURVE)
	
	return level


## Calculate member level from XP
func _calculate_member_level(total_xp: int) -> int:
	var level: int = 1
	var xp_required: int = XP_PER_LEVEL_BASE
	
	while total_xp >= xp_required and level < GUILD_LEVEL_CAP:
		total_xp -= xp_required
		level += 1
		xp_required = int(xp_required * XP_CURVE)
	
	return level


## Calculate member rank from XP
func _calculate_member_rank(total_xp: int) -> int:
	for i in range(MEMBER_RANK_XP.size() - 1, -1, -1):
		if total_xp >= MEMBER_RANK_XP[i]:
			return i
	return 0


## Handle guild level up
func _on_guild_level_up(guild_id: int, old_level: int, new_level: int) -> void:
	var guild: Dictionary = _get_guild(guild_id)
	if guild == null:
		return
	
	# Unlock perks
	for perk in GUILD_PERKS:
		if new_level >= perk.level and old_level < perk.level:
			if not guild.perks_unlocked.has(perk.level):
				guild.perks_unlocked.append(perk.level)
				_on_perk_unlocked(guild_id, perk)
	
	# Record level up
	if _world_memory != null:
		_world_memory.record_event({
			"type": "guild_level_up",
			"guild_id": guild_id,
			"old_level": old_level,
			"new_level": new_level,
			"tick": GameManager.tick_count
		})


## Handle member level up
func _on_member_level_up(guild_id: int, pawn_id: int, old_level: int, new_level: int) -> void:
	if _world_memory != null:
		_world_memory.record_event({
			"type": "guild_member_level_up",
			"guild_id": guild_id,
			"pawn_id": pawn_id,
			"old_level": old_level,
			"new_level": new_level,
			"tick": GameManager.tick_count
		})


## Handle member rank up
func _on_member_rank_up(guild_id: int, pawn_id: int, new_rank: int) -> void:
	if _world_memory != null:
		_world_memory.record_event({
			"type": "guild_member_rank_up",
			"guild_id": guild_id,
			"pawn_id": pawn_id,
			"new_rank": GUILD_RANKS[new_rank],
			"tick": GameManager.tick_count
		})


## Handle perk unlocked
func _on_perk_unlocked(guild_id: int, perk: Dictionary) -> void:
	if _world_memory != null:
		_world_memory.record_event({
			"type": "guild_perk_unlocked",
			"guild_id": guild_id,
			"perk_name": perk.name,
			"perk_level": perk.level,
			"tick": GameManager.tick_count
		})


## Disband guild
func disband_guild(guild_id: int) -> void:
	var guild: Dictionary = _get_guild(guild_id)
	if guild == null:
		return
	
	guild.status = "disbanded"
	
	# Record disbandment
	_add_guild_memory(guild_id, "guild_disbanded", {
		"tick": GameManager.tick_count,
		"reason": "manual"
	})
	
	if _world_memory != null:
		_world_memory.record_event({
			"type": "guild_disbanded",
			"guild_id": guild_id,
			"name": guild.name,
			"tick": GameManager.tick_count
		})


# ==================== TRUST SYSTEM ====================

func _decay_guild_trust() -> void:
	for guild in guilds:
		if guild.status != "active":
			continue
		
		# Slow decay (relationships need maintenance)
		guild.trust = maxf(0.0, guild.trust - TRUST_DECAY_PER_TICK)
		
		# Check for guild breakup
		if guild.trust < 10.0:
			_guild_betrayal(guild)


## Award trust bonus (successful cooperation)
func award_trust(guild_id: int, amount: float = TRUST_GAIN_PER_SUCCESS) -> void:
	var guild: Dictionary = _get_guild(guild_id)
	if guild == null:
		return
	
	guild.trust = minf(100.0, guild.trust + amount)


## Apply trust penalty (failure, betrayal)
func apply_trust_penalty(guild_id: int, amount: float = TRUST_LOSS_PER_FAILURE) -> void:
	var guild: Dictionary = _get_guild(guild_id)
	if guild == null:
		return
	
	guild.trust = maxf(0.0, guild.trust - amount)


func _guild_betrayal(guild: Dictionary) -> void:
	# Guild may break apart due to low trust
	if _world_memory != null:
		_world_memory.record_event({
			"type": "guild_betrayal",
			"guild_id": guild.guild_id,
			"name": guild.name,
			"trust": guild.trust,
			"tick": GameManager.tick_count
		})
	
	# Disband guild
	guild.status = "disbanded"


# ==================== REPUTATION SYSTEM ====================

## Modify guild reputation
func modify_reputation(guild_id: int, amount: int) -> void:
	var guild: Dictionary = _get_guild(guild_id)
	if guild == null:
		return
	
	guild.reputation += amount
	guild.reputation = clampi(guild.reputation, -1000, 1000)
	
	# Record reputation change
	_add_guild_memory(guild_id, "reputation_changed", {
		"amount": amount,
		"new_reputation": guild.reputation,
		"tick": GameManager.tick_count
	})


## Get guild reputation level
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


# ==================== GUILD MEMBER FUNCTIONS ====================

## Join a guild
func join_guild(guild_id: int, pawn_id: int) -> bool:
	var guild: Dictionary = _get_guild(guild_id)
	if guild == null or guild.status != "active":
		return false
	
	if guild.members.has(pawn_id):
		return false  # Already a member
	
	if guild.members.size() >= MAX_GUILD_SIZE:
		return false  # Guild full
	
	# Add member
	guild.members.append(pawn_id)
	guild.member_data[str(pawn_id)] = {
		"pawn_id": pawn_id,
		"guild_xp": 0,
		"guild_level": 1,
		"guild_rank": 0,  # Initiate
		"joined_tick": GameManager.tick_count,
		"quests_completed": 0,
		"prestige": 0
	}
	
	guild.trust = minf(100.0, guild.trust + 5.0)
	
	# Record joining
	_add_guild_memory(guild_id, "member_joined", {
		"pawn_id": pawn_id,
		"tick": GameManager.tick_count
	})
	
	# Award joining XP
	award_guild_xp(guild_id, 50, "new_member")
	
	return true


## Leave a guild
func leave_guild(guild_id: int, pawn_id: int) -> bool:
	var guild: Dictionary = _get_guild(guild_id)
	if guild == null:
		return false
	
	var member_id_str: String = str(pawn_id)
	if not guild.member_data.has(member_id_str):
		return false  # Not a member
	
	# Can't remove leader this way
	if pawn_id == guild.leader_id:
		return false  # Must disband or transfer leadership
	
	# Remove member data
	guild.member_data.erase(member_id_str)
	
	# Remove from members array
	var idx: int = guild.members.find(pawn_id)
	if idx >= 0:
		guild.members.remove_at(idx)
	
	# Remove from officers if present
	var officer_idx: int = guild.officers.find(pawn_id)
	if officer_idx >= 0:
		guild.officers.remove_at(officer_idx)
	
	guild.trust = maxf(0.0, guild.trust - 10.0)
	
	# Record departure
	_add_guild_memory(guild_id, "member_left", {
		"pawn_id": pawn_id,
		"tick": GameManager.tick_count
	})
	
	return true


## Get member data
func get_member_data(guild_id: int, pawn_id: int) -> Dictionary:
	var guild: Dictionary = _get_guild(guild_id)
	if guild == null:
		return {}
	
	if not guild.member_data.has(str(pawn_id)):
		return {}
	
	return guild.member_data[str(pawn_id)].duplicate()


## Get member rank name
func get_member_rank_name(guild_id: int, pawn_id: int) -> String:
	var member_data: Dictionary = get_member_data(guild_id, pawn_id)
	if member_data.is_empty():
		return ""
	
	var rank_index: int = member_data.get("guild_rank", 0)
	if rank_index >= 0 and rank_index < GUILD_RANKS.size():
		return GUILD_RANKS[rank_index]
	return ""


## Get perk data
func get_perk_data(perk_level: int) -> Dictionary:
	for perk in GUILD_PERKS:
		if perk.level == perk_level:
			return perk.duplicate()
	return {}


## Get guild type icon
func get_guild_type_icon(guild_id: int) -> String:
	var guild: Dictionary = _get_guild(guild_id)
	if guild.is_empty():
		return "🏛️"
	
	var guild_type: int = guild.get("type", GuildType.GENERAL)
	return GUILD_TYPE_ICONS.get(guild_type, "🏛️")


# ==================== REPUTATION SYSTEM ====================

func _add_guild_memory(guild_id: int, event_type: String, data: Dictionary) -> void:
	var guild: Dictionary = _get_guild(guild_id)
	if guild == null:
		return
	
	guild.memory.append({
		"type": event_type,
		"data": data,
		"tick": GameManager.tick_count
	})
	
	# Limit memory size
	while guild.memory.size() > 100:
		guild.memory.pop_front()


## Get guild memory
func get_guild_memory(guild_id: int, limit: int = 10) -> Array[Dictionary]:
	var guild: Dictionary = _get_guild(guild_id)
	if guild == null:
		return []
	var start: int = max(0, guild.memory.size() - limit)
	var result: Array[Dictionary] = []
	for i in range(start, guild.memory.size()):
		if guild.memory[i] is Dictionary:
			result.append(guild.memory[i])
	return result


# ==================== TREASURY SYSTEM ====================

## Deposit resources to guild treasury
func deposit_to_treasury(guild_id: int, resource_type: String, quantity: int) -> void:
	var guild: Dictionary = _get_guild(guild_id)
	if guild == null:
		return
	
	if not guild.treasury.has(resource_type):
		guild.treasury[resource_type] = 0
	
	guild.treasury[resource_type] += quantity


## Withdraw from treasury
func withdraw_from_treasury(guild_id: int, resource_type: String, quantity: int) -> bool:
	var guild: Dictionary = _get_guild(guild_id)
	if guild == null:
		return false
	
	if not guild.treasury.has(resource_type):
		return false
	
	if guild.treasury[resource_type] < quantity:
		return false
	
	guild.treasury[resource_type] -= quantity
	return true


# ==================== GUILD BONUSES ====================

## Get guild cooperation bonus (emerges from coordination, skill, tools, location, memory)
func get_cooperation_bonus(guild_id: int, task_type: String) -> float:
	var guild: Dictionary = _get_guild(guild_id)
	if guild == null:
		return 0.0
	
	var bonus: float = 0.0
	
	# Trust bonus (internal cohesion)
	bonus += (guild.trust / 100.0) * 0.2  # Up to +20%
	
	# Reputation bonus (external recognition)
	bonus += (float(guild.reputation) / 1000.0) * 0.15  # Up to +15%
	
	# Memory bonus (learned from experience)
	var relevant_memories: int = 0
	for memory in guild.memory:
		if memory.type == "task_completed" and memory.data.get("task_type") == task_type:
			relevant_memories += 1
	bonus += mini(0.15, float(relevant_memories) * 0.01)  # Up to +15%
	
	# Officer bonus (leadership structure)
	bonus += float(guild.officers.size()) * 0.02  # +2% per officer
	
	return minf(0.5, bonus)  # Cap at +50%


# ==================== UTILITY ====================

func _get_guild(guild_id: int) -> Dictionary:
	for guild in guilds:
		if guild.guild_id == guild_id:
			return guild
	return {}


func _get_pawn_name(pawn_id: int) -> String:
	var pawn_spawner: Node = get_node_or_null("/root/Main/WorldViewport/PawnSpawner")
	if pawn_spawner != null and pawn_spawner.has_method("pawn_data_for_id"):
		var data: Node = pawn_spawner.call("pawn_data_for_id", pawn_id)
		if data != null and data.has_method("get_display_name"):
			return data.get_display_name()
	
	return "HeelKawnian #%d" % pawn_id


func _guild_type_to_string(guild_type: int) -> String:
	return GUILD_TYPE_NAMES.get(guild_type, "Unknown Guild")


# ==================== PUBLIC API ====================

## Get guild data
func get_guild(guild_id: int) -> Dictionary:
	var guild: Dictionary = _get_guild(guild_id)
	if guild == null:
		return {}
	return guild.duplicate()

## Get all active guilds
func get_all_guilds() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for guild in guilds:
		if guild.status == "active":
			result.append(guild.duplicate())
	return result

## Get guilds by type
func get_guilds_by_type(guild_type: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for guild in guilds:
		if guild.type == guild_type and guild.status == "active":
			result.append(guild.duplicate())
	return result

## Get guilds by member
func get_guilds_by_member(pawn_id: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for guild in guilds:
		if guild.members.has(pawn_id) and guild.status == "active":
			result.append(guild.duplicate())
	return result

## Check if pawn is in any guild
func is_pawn_in_guild(pawn_id: int) -> bool:
	for guild in guilds:
		if guild.members.has(pawn_id) and guild.status == "active":
			return true
	return false

## Clear all data (for world reroll)
func clear() -> void:
	guilds.clear()
	_next_guild_id = 1

## Get statistics
func get_stats() -> Dictionary:
	var active: int = 0
	var disbanded: int = 0
	var total_members: int = 0
	
	for guild in guilds:
		if guild.status == "active":
			active += 1
			total_members += guild.members.size()
		else:
			disbanded += 1
	
	return {
		"total_guilds": guilds.size(),
		"active": active,
		"disbanded": disbanded,
		"total_members": total_members,
		"average_trust": _calculate_average_trust(),
		"by_type": _count_by_type()
	}


func _calculate_average_trust() -> float:
	var total: float = 0.0
	var count: int = 0
	for guild in guilds:
		if guild.status == "active":
			total += guild.trust
			count += 1
	return total / float(count) if count > 0 else 0.0


func _count_by_type() -> Dictionary:
	var counts: Dictionary = {}
	for guild in guilds:
		if guild.status == "active":
			var type_name: String = _guild_type_to_string(guild.type)
			counts[type_name] = counts.get(type_name, 0) + 1
	return counts
