extends Node
## GuildSystem - BG3/WOW/ECO-style groups for ALL roles
##
## Features:
## - Guilds for all roles (farmers, warriors, sailors, etc.)
## - Social institutions (not just buff machines)
## - Memory, reputation, internal trust
## - Leaders can fail
## - Groups break under hunger, betrayal, death, distance
## - Recorded in WorldMemory when historically meaningful

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

# Guild data structure
## {
##   "guild_id": int,
##   "name": String,
##   "type": int,  # GuildType enum
##   "leader_id": int,
##   "officers": Array[int],  # pawn_ids
##   "members": Array[int],  # pawn_ids
##   "reputation": int,  # -1000 to 1000
##   "trust": float,  # 0-100 (internal cohesion)
##   "treasury": Dictionary,  # {resource: quantity}
##   "memory": Array[Dictionary],  # guild history
##   "created_tick": int,
##   "status": String  # "active", "disbanded", "destroyed"
## }
var guilds: Array[Dictionary] = []
var _next_guild_id: int = 1

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
		"leader_id": leader_id,
		"officers": [],
		"members": [leader_id],
		"reputation": 0,
		"trust": 50.0,
		"treasury": {},
		"memory": [],
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
			"type": _guild_type_to_string(guild_type),
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


# ==================== GUILD MEMORY ====================

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
	return guild.memory.slice(start)


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
	return null


func _get_pawn_name(pawn_id: int) -> String:
	var pawn_spawner: Node = get_node_or_null("/root/Main/WorldViewport/PawnSpawner")
	if pawn_spawner != null and pawn_spawner.has_method("pawn_data_for_id"):
		var data: Node = pawn_spawner.call("pawn_data_for_id", pawn_id)
		if data != null and data.has_method("get_display_name"):
			return data.get_display_name()
	
	return "Pawn #%d" % pawn_id


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
