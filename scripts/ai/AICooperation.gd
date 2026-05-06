extends Node
## AICooperation - Player-AI task sharing and cooperation
##
## Enables:
## - AI can request player help for critical tasks
## - Player can assign AI tasks
## - Shared goals with shared rewards
## - Reputation system for cooperation
##
## ECO-style: Sovereignty + interdependence

# Cooperation request data structure
## {
##   "request_id": int,
##   "requester_type": String,  # "ai" or "player"
##   "task_type": String,
##   "description": String,
##   "priority": int,  # 1-10
##   "reward": Dictionary,
##   "accepted": bool,
##   "completed": bool,
##   "created_tick": int
## }
var cooperation_requests: Array[Dictionary] = []
var _next_request_id: int = 1

# Reputation data per player/faction
## {
##   "entity_id": int,
##   "reputation": float,  # -100 to 100
##   "completed_tasks": int,
##   "failed_tasks": int,
##   "last_interaction_tick": int
## }
var reputation_records: Dictionary = {}

# Configuration
const MIN_REPUTATION_FOR_COOPERATION: int = -50  # Below this, AI won't cooperate
const REPUTATION_GAIN_PER_TASK: int = 10
const REPUTATION_LOSS_PER_FAILURE: int = 5
const MAX_REPUTATION: int = 100
const MIN_REPUTATION: int = -100

# References
@onready var _world_memory: Node = null
@onready var _settlement_memory: Node = null


func _ready() -> void:
	GameManager.game_tick.connect(_on_game_tick)
	_world_memory = get_node_or_null("/root/WorldMemory")
	_settlement_memory = get_node_or_null("/root/SettlementMemory")


func _on_game_tick(tick: int) -> void:
	# Process active requests
	_process_cooperation_requests(tick)
	
	# Clean old completed requests
	if tick % 1000 == 0:
		_clean_old_requests(tick)


# ==================== AI REQUESTS PLAYER HELP ====================

## AI requests player assistance for critical task
func ai_request_help(requester_id: int, task_type: String, description: String, priority: int, reward: Dictionary) -> int:
	var request: Dictionary = {
		"request_id": _next_request_id,
		"requester_type": "ai",
		"requester_id": requester_id,
		"task_type": task_type,
		"description": description,
		"priority": priority,
		"reward": reward,
		"accepted": false,
		"completed": false,
		"created_tick": GameManager.tick_count,
		"accepted_by": -1,
		"completed_tick": -1
	}
	
	cooperation_requests.append(request)
	_next_request_id += 1
	
	# Record request
	if _world_memory != null:
		_world_memory.record_event({
			"type": "ai_cooperation_request",
			"request_id": request.request_id,
			"task_type": task_type,
			"priority": priority,
			"tick": GameManager.tick_count
		})
	
	return request.request_id


## Get all pending AI requests for player
func get_pending_ai_requests() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for request in cooperation_requests:
		if request.requester_type == "ai" and not request.accepted and not request.completed:
			result.append(request.duplicate())
	return result


## Player accepts an AI request
func player_accept_request(request_id: int, player_id: int) -> bool:
	for request in cooperation_requests:
		if request.request_id == request_id:
			if request.accepted:
				return false  # Already accepted
			
			# Check reputation
			if not _check_reputation(request.requester_id, player_id):
				return false  # Reputation too low
			
			request.accepted = true
			request.accepted_by = player_id
			
			# Update reputation
			_modify_reputation(player_id, 5)  # Small bonus for accepting
			
			return true
	return false


# ==================== PLAYER ASSIGNS AI TASKS ====================

## Player assigns task to AI
func player_assign_task(player_id: int, settlement_id: int, task_type: String, description: String, priority: int, reward: Dictionary) -> int:
	# Check if AI will accept based on reputation
	if not _check_reputation(player_id, settlement_id):
		return -1  # Reputation too low
	
	var request: Dictionary = {
		"request_id": _next_request_id,
		"requester_type": "player",
		"requester_id": player_id,
		"settlement_id": settlement_id,
		"task_type": task_type,
		"description": description,
		"priority": priority,
		"reward": reward,
		"accepted": true,  # Auto-accepted if reputation OK
		"completed": false,
		"created_tick": GameManager.tick_count,
		"accepted_by": settlement_id,
		"completed_tick": -1
	}
	
	cooperation_requests.append(request)
	_next_request_id += 1
	
	# Record assignment
	if _world_memory != null:
		_world_memory.record_event({
			"type": "player_ai_assignment",
			"request_id": request.request_id,
			"task_type": task_type,
			"settlement_id": settlement_id,
			"tick": GameManager.tick_count
		})
	
	return request.request_id


# ==================== TASK COMPLETION ====================

## Mark request as completed
func complete_request(request_id: int) -> void:
	for request in cooperation_requests:
		if request.request_id == request_id:
			request.completed = true
			request.completed_tick = GameManager.tick_count
			
			# Grant reward
			_grant_reward(request)
			
			# Update reputation
			if request.requester_type == "ai":
				_modify_reputation(int(request.accepted_by), REPUTATION_GAIN_PER_TASK)
			else:
				_modify_reputation(request.requester_id, REPUTATION_GAIN_PER_TASK)
			
			# Record completion
			if _world_memory != null:
				_world_memory.record_event({
					"type": "cooperation_completed",
					"request_id": request_id,
					"success": true,
					"tick": GameManager.tick_count
				})
			
			return


## Mark request as failed
func fail_request(request_id: int) -> void:
	for request in cooperation_requests:
		if request.request_id == request_id:
			request.completed = true
			request.completed_tick = GameManager.tick_count
			
			# Penalty to reputation
			if request.requester_type == "ai":
				_modify_reputation(int(request.accepted_by), -REPUTATION_LOSS_PER_FAILURE)
			else:
				_modify_reputation(request.requester_id, -REPUTATION_LOSS_PER_FAILURE)
			
			# Record failure
			if _world_memory != null:
				_world_memory.record_event({
					"type": "cooperation_failed",
					"request_id": request_id,
					"success": false,
					"tick": GameManager.tick_count
				})
			
			return


# ==================== REPUTATION SYSTEM ====================

func _check_reputation(entity_id: int, target_id: int) -> bool:
	var key: String = "%d_%d" % [entity_id, target_id]
	if not reputation_records.has(key):
		return true  # No record = neutral = OK
	
	var record: Dictionary = reputation_records[key]
	return record.reputation >= MIN_REPUTATION_FOR_COOPERATION


func _modify_reputation(entity_id: int, amount: int) -> void:
	var key: String = "player_%d" % entity_id
	if not reputation_records.has(key):
		reputation_records[key] = {
			"entity_id": entity_id,
			"reputation": 0,
			"completed_tasks": 0,
			"failed_tasks": 0,
			"last_interaction_tick": GameManager.tick_count
		}
	
	var record: Dictionary = reputation_records[key]
	record.reputation += amount
	record.reputation = clampi(record.reputation, MIN_REPUTATION, MAX_REPUTATION)
	record.last_interaction_tick = GameManager.tick_count
	
	if amount > 0:
		record.completed_tasks += 1
	else:
		record.failed_tasks += 1


## Get reputation with an entity
func get_reputation(entity_id: int) -> int:
	var key: String = "player_%d" % entity_id
	if not reputation_records.has(key):
		return 0  # Neutral
	
	return reputation_records[key].reputation


## Get full reputation record
func get_reputation_record(entity_id: int) -> Dictionary:
	var key: String = "player_%d" % entity_id
	if not reputation_records.has(key):
		return {
			"reputation": 0,
			"completed_tasks": 0,
			"failed_tasks": 0,
			"status": "neutral"
		}
	
	var record: Dictionary = reputation_records[key]
	var status: String = "neutral"
	if record.reputation > 50:
		status = "trusted"
	elif record.reputation > 0:
		status = "friendly"
	elif record.reputation > -50:
		status = "neutral"
	else:
		status = "untrusted"
	
	return {
		"reputation": record.reputation,
		"completed_tasks": record.completed_tasks,
		"failed_tasks": record.failed_tasks,
		"status": status
	}


# ==================== REWARD SYSTEM ====================

func _grant_reward(request: Dictionary) -> void:
	var reward: Dictionary = request.reward
	
	# Grant resource rewards
	if reward.has("resources"):
		var stockpile: Node = get_node_or_null("/root/StockpileManager")
		if stockpile != null:
			for resource_type in reward.resources:
				var quantity: int = reward.resources[resource_type]
				# stockpile.add_item(resource_type, quantity)
	
	# Grant reputation rewards
	if reward.has("reputation"):
		if request.requester_type == "ai":
			_modify_reputation(int(request.accepted_by), reward.reputation)
		else:
			_modify_reputation(request.requester_id, reward.reputation)


# ==================== REQUEST PROCESSING ====================

func _process_cooperation_requests(tick: int) -> void:
	# Auto-complete requests that are past their time
	for request in cooperation_requests:
		if not request.completed and request.accepted:
			var age: int = tick - request.created_tick
			
			# Simple auto-completion based on priority and age
			var max_age: int = 1000 - (request.priority * 100)  # Higher priority = faster completion
			if age > max_age:
				complete_request(request.request_id)


func _clean_old_requests(tick: int) -> void:
	for i in range(cooperation_requests.size() - 1, -1, -1):
		var request: Dictionary = cooperation_requests[i]
		if request.completed and tick - request.completed_tick > 5000:
			cooperation_requests.remove_at(i)


# ==================== PUBLIC API ====================

## Get all requests
func get_all_requests() -> Array[Dictionary]:
	return cooperation_requests.duplicate()

## Get request by ID
func get_request(request_id: int) -> Dictionary:
	for request in cooperation_requests:
		if request.request_id == request_id:
			return request.duplicate()
	return {}

## Clear all data (for world reroll)
func clear() -> void:
	cooperation_requests.clear()
	reputation_records.clear()
	_next_request_id = 1

## Get statistics
func get_stats() -> Dictionary:
	var completed: int = 0
	var pending: int = 0
	for request in cooperation_requests:
		if request.completed:
			completed += 1
		else:
			pending += 1
	
	return {
		"total_requests": cooperation_requests.size(),
		"completed": completed,
		"pending": pending,
		"reputation_records": reputation_records.size()
	}
