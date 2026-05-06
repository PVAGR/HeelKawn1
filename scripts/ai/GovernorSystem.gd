extends Node
## GovernorSystem - Songs of Syx-style city management
##
## Features:
## - Player or NPC can be governor
## - Zone designation (residential, industrial, agricultural)
## - Worker assignment priorities
## - Resource allocation
## - Policy system (tax, trade, defense, culture)

# Governor data structure
## {
##   "governor_id": int,
##   "settlement_id": int,
##   "is_player": bool,
##   "appointed_tick": int,
##   "policies": Dictionary,
##   "zone_priorities": Dictionary,
##   "worker_assignments": Dictionary,
##   "approval_rating": float,  # 0-100
##   "term_length_ticks": int
## }
var governors: Dictionary = {}  # {settlement_id: governor_data}

# Zone types
enum ZoneType {
	RESIDENTIAL,    # Housing, homes
	INDUSTRIAL,     # Workshops, crafting
	AGRICULTURAL,   # Farms, fields
	COMMERCIAL,     # Markets, trade
	MILITARY,       # Barracks, defenses
	CULTURAL,       # Temples, monuments
	STORAGE,        # Granaries, stockpiles
	ADMINISTRATIVE  # Governor hall, offices
}

# Policy categories
const POLICY_CATEGORIES: Dictionary = {
	"tax": {
		"none": {"tax_rate": 0.0, "approval": 0.1},
		"low": {"tax_rate": 0.1, "approval": 0.05},
		"medium": {"tax_rate": 0.2, "approval": -0.05},
		"high": {"tax_rate": 0.3, "approval": -0.15}
	},
	"trade": {
		"isolationist": {"trade_bonus": -0.2, "approval": 0.05},
		"free": {"trade_bonus": 0.0, "approval": 0.0},
		"mercantile": {"trade_bonus": 0.3, "approval": -0.05}
	},
	"defense": {
		"peaceful": {"defense": -0.1, "approval": 0.1},
		"neutral": {"defense": 0.0, "approval": 0.0},
		"fortified": {"defense": 0.3, "approval": -0.05},
		"militaristic": {"defense": 0.5, "approval": -0.15}
	},
	"culture": {
		"none": {"culture_rate": 0.0, "approval": 0.0},
		"patron": {"culture_rate": 0.2, "approval": 0.05},
		"theocratic": {"culture_rate": 0.3, "approval": -0.05}
	}
}

# Configuration
const DEFAULT_TERM_LENGTH: int = 10000  # Ticks per governor term
const APPROVAL_DECAY_RATE: float = 0.001  # Approval decay per tick

# References
@onready var _world_memory: Node = null
@onready var _settlement_memory: Node = null
@onready var _stockpile_manager: Node = null


func _ready() -> void:
	GameManager.game_tick.connect(_on_game_tick)
	_world_memory = get_node_or_null("/root/WorldMemory")
	_settlement_memory = get_node_or_null("/root/SettlementMemory")
	_stockpile_manager = get_node_or_null("/root/StockpileManager")


func _on_game_tick(tick: int) -> void:
	# Decay approval over time
	_decay_approval()
	
	# Check for term endings
	if tick % 1000 == 0:
		_check_term_endings(tick)


# ==================== GOVERNOR APPOINTMENT ====================

## Appoint a governor for a settlement
func appoint_governor(settlement_id: int, governor_id: int, 
 is_player: bool = false, term_length: int = DEFAULT_TERM_LENGTH) -> bool:
	
	# Check if governor already exists
	if governors.has(settlement_id):
		return false  # Already has governor
	
	# Create governor data
	var governor_data: Dictionary = {
		"governor_id": governor_id,
		"settlement_id": settlement_id,
		"is_player": is_player,
		"appointed_tick": GameManager.tick_count,
		"policies": {
			"tax": "medium",
			"trade": "free",
			"defense": "neutral",
			"culture": "none"
		},
		"zone_priorities": {},
		"worker_assignments": {},
		"approval_rating": 50.0,
		"term_length_ticks": term_length
	}
	
	governors[settlement_id] = governor_data
	
	# Record appointment
	if _world_memory != null:
		_world_memory.record_event({
			"type": "governor_appointed",
			"settlement_id": settlement_id,
			"governor_id": governor_id,
			"is_player": is_player,
			"tick": GameManager.tick_count
		})
	
	return true


## Remove governor from settlement
func remove_governor(settlement_id: int) -> void:
	if not governors.has(settlement_id):
		return
	
	var governor_data: Dictionary = governors[settlement_id]
	
	# Record removal
	if _world_memory != null:
		_world_memory.record_event({
			"type": "governor_removed",
			"settlement_id": settlement_id,
			"governor_id": governor_data.governor_id,
			"tick": GameManager.tick_count
		})
	
	governors.erase(settlement_id)


# ==================== POLICY SYSTEM ====================

## Set policy for a settlement
func set_policy(settlement_id: int, category: String, policy: String) -> bool:
	if not governors.has(settlement_id):
		return false
	
	if not POLICY_CATEGORIES.has(category):
		return false
	
	if not POLICY_CATEGORIES[category].has(policy):
		return false
	
	governors[settlement_id].policies[category] = policy
	
	# Record policy change
	if _world_memory != null:
		_world_memory.record_event({
			"type": "policy_changed",
			"settlement_id": settlement_id,
			"category": category,
			"policy": policy,
			"tick": GameManager.tick_count
		})
	
	return true


## Get policy effects for a settlement
func get_policy_effects(settlement_id: int) -> Dictionary:
	if not governors.has(settlement_id):
		return {}
	
	var governor_data: Dictionary = governors[settlement_id]
	var effects: Dictionary = {}
	
	# Combine all policy effects
	for category in governor_data.policies:
		var policy: String = governor_data.policies[category]
		if POLICY_CATEGORIES.has(category) and POLICY_CATEGORIES[category].has(policy):
			var policy_effects: Dictionary = POLICY_CATEGORIES[category][policy]
			for effect in policy_effects:
				effects[effect] = effects.get(effect, 0.0) + policy_effects[effect]
	
	return effects


## Get all available policies for a category
func get_available_policies(category: String) -> Array[String]:
	if not POLICY_CATEGORIES.has(category):
		return []
	
	return POLICY_CATEGORIES[category].keys()


# ==================== ZONE MANAGEMENT ====================

## Set zone priority for a settlement
func set_zone_priority(settlement_id: int, zone_type: int, priority: int) -> bool:
	if not governors.has(settlement_id):
		return false
	
	governors[settlement_id].zone_priorities[str(zone_type)] = priority
	return true


## Get zone priorities for a settlement
func get_zone_priorities(settlement_id: int) -> Dictionary:
	if not governors.has(settlement_id):
		return {}
	
	return governors[settlement_id].zone_priorities.duplicate()


## Get recommended zone based on needs
func get_recommended_zone(settlement_id: int) -> int:
	if not governors.has(settlement_id):
		return ZoneType.RESIDENTIAL
	
	var settlement_data: Dictionary = _get_settlement_data(settlement_id)
	if settlement_data.is_empty():
		return ZoneType.RESIDENTIAL
	
	# Check settlement needs
	if settlement_data.homeless > 0:
		return ZoneType.RESIDENTIAL
	elif settlement_data.food_days < 7:
		return ZoneType.AGRICULTURAL
	elif settlement_data.storage_full:
		return ZoneType.STORAGE
	elif settlement_data.threat_level > 5:
		return ZoneType.MILITARY
	else:
		return ZoneType.INDUSTRIAL


func _get_settlement_data(settlement_id: int) -> Dictionary:
	if _settlement_memory == null or not _settlement_memory.has_method("get_settlement_data"):
		return {}
	
	return _settlement_memory.call("get_settlement_data", settlement_id)


# ==================== WORKER ASSIGNMENT ====================

## Assign workers to a task
func assign_workers(settlement_id: int, task_type: String, count: int) -> bool:
	if not governors.has(settlement_id):
		return false
	
	governors[settlement_id].worker_assignments[task_type] = count
	return true


## Get worker assignments for a settlement
func get_worker_assignments(settlement_id: int) -> Dictionary:
	if not governors.has(settlement_id):
		return {}
	
	return governors[settlement_id].worker_assignments.duplicate()


## Get recommended worker distribution
func get_recommended_worker_distribution(settlement_id: int) -> Dictionary:
	var distribution: Dictionary = {
		"farmers": 30,
		"builders": 20,
		"gatherers": 15,
		"warriors": 10,
		"scholars": 5,
		"traders": 5,
		"crafters": 10,
		"unassigned": 5
	}
	
	if not governors.has(settlement_id):
		return distribution
	
	# Adjust based on policies
	var effects: Dictionary = get_policy_effects(settlement_id)
	
	if effects.get("defense", 0.0) > 0.2:
		distribution.warriors += 10
		distribution.farmers -= 5
		distribution.builders -= 5
	
	if effects.get("trade_bonus", 0.0) > 0.1:
		distribution.traders += 5
		distribution.unassigned -= 5
	
	return distribution


# ==================== RESOURCE ALLOCATION ====================

## Allocate resources from stockpile
func allocate_resources(settlement_id: int, resource_type: String, 
 quantity: int, purpose: String) -> bool:
	
	if _stockpile_manager == null:
		return false
	
	# Check if governor has authority
	if not governors.has(settlement_id):
		return false
	
	# Attempt withdrawal
	if _stockpile_manager.has_method("remove_item"):
		return _stockpile_manager.call("remove_item", resource_type, quantity)
	
	return false


## Get resource allocation priorities
func get_resource_priorities(settlement_id: int) -> Dictionary:
	var priorities: Dictionary = {
		"food": 5,
		"wood": 3,
		"stone": 3,
		"metal": 2,
		"tools": 4
	}
	
	if not governors.has(settlement_id):
		return priorities
	
	var governor_data: Dictionary = governors[settlement_id]
	
	# Adjust based on policies
	var effects: Dictionary = get_policy_effects(settlement_id)
	
	if effects.get("defense", 0.0) > 0.2:
		priorities.metal += 2
		priorities.wood += 1
	
	if effects.get("culture_rate", 0.0) > 0.1:
		priorities.stone += 2
	
	return priorities


# ==================== APPROVAL SYSTEM ====================

func _decay_approval() -> void:
	for settlement_id in governors:
		var governor_data: Dictionary = governors[settlement_id]
		
		# Natural decay
		governor_data.approval_rating -= APPROVAL_DECAY_RATE
		
		# Policy effects
		var effects: Dictionary = get_policy_effects(settlement_id)
		governor_data.approval_rating += effects.get("approval", 0.0) * 0.01
		
		# Clamp
		governor_data.approval_rating = clampf(governor_data.approval_rating, 0.0, 100.0)


func _check_term_endings(tick: int) -> void:
	for settlement_id in governors:
		var governor_data: Dictionary = governors[settlement_id]
		
		# Check if term ended
		if tick - governor_data.appointed_tick >= governor_data.term_length_ticks:
			# Record term ending
			if _world_memory != null:
				_world_memory.record_event({
					"type": "governor_term_ended",
					"settlement_id": settlement_id,
					"governor_id": governor_data.governor_id,
					"approval": governor_data.approval_rating,
					"tick": tick
				})
			
			# Remove governor (election/reappointment would happen elsewhere)
			remove_governor(settlement_id)


## Modify approval rating
func modify_approval(settlement_id: int, amount: float, reason: String = "") -> void:
	if not governors.has(settlement_id):
		return
	
	var governor_data: Dictionary = governors[settlement_id]
	governor_data.approval_rating += amount
	governor_data.approval_rating = clampf(governor_data.approval_rating, 0.0, 100.0)
	
	# Record approval change
	if _world_memory != null:
		_world_memory.record_event({
			"type": "governor_approval_changed",
			"settlement_id": settlement_id,
			"amount": amount,
			"reason": reason,
			"tick": GameManager.tick_count
		})


# ==================== PUBLIC API ====================

## Get governor for a settlement
func get_governor(settlement_id: int) -> Dictionary:
	if governors.has(settlement_id):
		return governors[settlement_id].duplicate()
	return {}

## Check if settlement has governor
func has_governor(settlement_id: int) -> bool:
	return governors.has(settlement_id)

## Get all governors
func get_all_governors() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for settlement_id in governors:
		result.append(governors[settlement_id].duplicate())
	return result

## Get player governors
func get_player_governors() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for settlement_id in governors:
		if governors[settlement_id].is_player:
			result.append(governors[settlement_id].duplicate())
	return result

## Clear all data (for world reroll)
func clear() -> void:
	governors.clear()

## Get statistics
func get_stats() -> Dictionary:
	var player_governors: int = 0
	var npc_governors: int = 0
	var avg_approval: float = 0.0
	
	for settlement_id in governors:
		var governor_data: Dictionary = governors[settlement_id]
		if governor_data.is_player:
			player_governors += 1
		else:
			npc_governors += 1
		avg_approval += governor_data.approval_rating
	
	var total: int = player_governors + npc_governors
	
	return {
		"total_governors": total,
		"player_governors": player_governors,
		"npc_governors": npc_governors,
		"average_approval": avg_approval / float(total) if total > 0 else 0.0
	}
