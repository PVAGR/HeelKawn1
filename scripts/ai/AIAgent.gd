extends RefCounted
class_name AIAgent
## AI Agent Framework - NPC-player parity using Phase 5 APIs
## Provides decision-making, observation, and command execution capabilities

enum AgentType {
	STRATEGIC = 0,  # Long-term planning, settlement management
	TACTICAL = 1,   # Short-term decisions, combat, resource management
	REACTIVE = 2,   # Immediate responses, survival instincts
}

enum GoalPriority {
	CRITICAL = 0,    # Life/death, immediate threats
	HIGH = 1,       # Important objectives, resource needs
	MEDIUM = 2,     # Standard tasks, maintenance
	LOW = 3         # Optional activities, exploration
}

class Goal extends RefCounted:
	var type: String
	var priority: GoalPriority
	var target_data: Dictionary
	var deadline_tick: int = -1  # -1 = no deadline
	var progress: float = 0.0
	var completed: bool = false
	
	func _init(goal_type: String, goal_priority: GoalPriority, target: Dictionary, deadline: int = -1):
		type = goal_type
		priority = goal_priority
		target_data = target
		deadline_tick = deadline

class Memory extends RefCounted:
	var observations: Dictionary = {}  # tick -> observation data
	var outcomes: Dictionary = {}     # action -> result
	var relationships: Dictionary = {}  # pawn_id -> relationship_score
	var locations: Dictionary = {}    # region_key -> familiarity
	var last_update_tick: int = 0
	
	func add_observation(tick: int, observation: Dictionary):
		observations[tick] = observation
		last_update_tick = tick
	
	func add_outcome(action: String, result: Dictionary):
		outcomes[action] = result
	
	func get_recent_observations(ticks_back: int = 100) -> Array:
		var recent: Array = []
		var current_tick: int = GameManager.tick_count
		for tick in range(max(0, current_tick - ticks_back), current_tick + 1):
			if observations.has(tick):
				recent.append(observations[tick])
		return recent

# Agent properties
var agent_id: int
var agent_type: AgentType
var controlled_pawn_id: int = -1  # -1 = spectator mode
var memory: Memory
var current_goals: Array[Goal] = []
var decision_frequency: int = 30  # Make decisions every N ticks
var last_decision_tick: int = 0

# Personality parameters (0.0 to 1.0)
var aggressiveness: float = 0.5
var caution: float = 0.5
var social_tendency: float = 0.5
var exploration_drive: float = 0.5
var self_preservation: float = 0.7

func _init(id: int, type: AgentType = AgentType.TACTICAL):
	agent_id = id
	agent_type = type
	memory = Memory.new()
	_generate_personality()

func _generate_personality() -> void:
	# Generate personality based on agent type
	match agent_type:
		AgentType.STRATEGIC:
			aggressiveness = randf_range(0.2, 0.6)
			caution = randf_range(0.6, 0.9)
			social_tendency = randf_range(0.4, 0.8)
			exploration_drive = randf_range(0.3, 0.7)
			self_preservation = randf_range(0.8, 1.0)
		AgentType.TACTICAL:
			aggressiveness = randf_range(0.4, 0.8)
			caution = randf_range(0.3, 0.7)
			social_tendency = randf_range(0.5, 0.9)
			exploration_drive = randf_range(0.5, 0.8)
			self_preservation = randf_range(0.6, 0.9)
		AgentType.REACTIVE:
			aggressiveness = randf_range(0.1, 0.5)
			caution = randf_range(0.7, 1.0)
			social_tendency = randf_range(0.3, 0.6)
			exploration_drive = randf_range(0.2, 0.5)
			self_preservation = randf_range(0.9, 1.0)

# === Main Agent Loop ===

func update() -> void:
	var current_tick: int = GameManager.tick_count
	
	# Update memory with current observation
	_update_memory()
	
	# Check goal completion and update progress
	_update_goals()
	
	# Make decisions at specified frequency
	if current_tick - last_decision_tick >= decision_frequency:
		_make_decisions()
		last_decision_tick = current_tick

func _update_memory() -> void:
	if controlled_pawn_id == -1:
		# Spectator mode - observe camera view
		var obs: Dictionary = {}
		if ObservationAPI != null:
			obs = ObservationAPI.observe_camera_view()
		else:
			obs = {"error": "ObservationAPI not available"}
		memory.add_observation(GameManager.tick_count, obs)
	else:
		# Incarnated mode - observe controlled pawn
		var obs: Dictionary = {}
		if ObservationAPI != null:
			obs = ObservationAPI.observe_pawn(controlled_pawn_id)
		else:
			obs = {"error": "ObservationAPI not available"}
		if not obs.has("error"):
			memory.add_observation(GameManager.tick_count, obs)

func _update_goals() -> void:
	var goals_to_remove: Array[int] = []
	
	for i in range(current_goals.size()):
		var goal: Goal = current_goals[i]
		
		# Check if goal is completed
		if _is_goal_completed(goal):
			goal.completed = true
			goals_to_remove.append(i)
		# Check deadline
		elif goal.deadline_tick > 0 and GameManager.tick_count >= goal.deadline_tick:
			goals_to_remove.append(i)
		# Update progress
		else:
			goal.progress = _calculate_goal_progress(goal)
	
	# Remove completed/expired goals (reverse order to maintain indices)
	goals_to_remove.reverse()
	for i in goals_to_remove:
		current_goals.remove_at(i)

func _make_decisions() -> void:
	# Generate new goals if needed
	_generate_goals()
	
	# Sort goals by priority
	current_goals.sort_custom(func(a: Goal, b: Goal) -> bool: return a.priority < b.priority)
	
	# Execute highest priority actionable goal
	for goal in current_goals:
		if goal.completed:
			continue
		
		var action: Dictionary = _plan_action_for_goal(goal)
		if not action.is_empty():
			_execute_action(action)
			break  # Execute one action per decision cycle

# === Goal Generation ===

func _generate_goals() -> void:
	# Remove completed goals and check if we need new ones
	current_goals = current_goals.filter(func(g: Goal) -> bool: return not g.completed)
	
	if current_goals.size() >= 3:  # Limit concurrent goals
		return
	
	if controlled_pawn_id == -1:
		_generate_spectator_goals()
	else:
		_generate_pawn_goals()

func _generate_spectator_goals() -> void:
	# Spectator goals: find interesting pawns to observe, monitor settlements
	var obs: Dictionary = {}
	if ObservationAPI != null:
		obs = ObservationAPI.observe_camera_view()
	else:
		obs = {"error": "ObservationAPI not available"}
	
	if obs.has("error"):
		return
	
	# Goal: Find pawn to incarnate
	if randf() < 0.1:  # 10% chance per decision cycle
		var candidates: Array = []
		if ObservationAPI != null:
			candidates = ObservationAPI.observe_pawns_in_region(obs.get("camera_region_key", 0))
		if not candidates.is_empty():
			var target: Dictionary = candidates[randi() % candidates.size()]
			current_goals.append(Goal.new(
				"incarnate_pawn",
				GoalPriority.MEDIUM,
				{"pawn_id": target.get("pawn_id", -1)},
				GameManager.tick_count + 200  # Deadline in 200 ticks
			))

func _generate_pawn_goals() -> void:
	var pawn_obs: Dictionary = ObservationAPI.observe_pawn(controlled_pawn_id)
	if pawn_obs.has("error"):
		return
	
	var health_pct: int = pawn_obs.get("health_percentage", 100)
	var hunger: float = pawn_obs.get("hunger", 0.0)
	var mood: float = pawn_obs.get("mood", 50.0)
	var current_job: String = pawn_obs.get("current_job", "None")
	
	# Critical: Survival needs
	if health_pct < 30:
		current_goals.append(Goal.new(
			"heal_self",
			GoalPriority.CRITICAL,
			{"target_health": 80},
			GameManager.tick_count + 50
		))
	elif hunger > 70:
		current_goals.append(Goal.new(
			"find_food",
			GoalPriority.CRITICAL,
			{"target_hunger": 30},
			GameManager.tick_count + 30
		))
	elif mood < 20:
		current_goals.append(Goal.new(
			"improve_mood",
			GoalPriority.HIGH,
			{"target_mood": 60},
			GameManager.tick_count + 100
		))
	
	# High priority: Productivity
	elif current_job == "None":
		current_goals.append(Goal.new(
			"find_work",
			GoalPriority.HIGH,
			{"job_type": "any"},
			GameManager.tick_count + 60
		))
	
	# Medium priority: Social/exploration based on personality
	elif randf() < social_tendency:
		current_goals.append(Goal.new(
			"socialize",
			GoalPriority.MEDIUM,
			{"interaction_type": "casual"},
			GameManager.tick_count + 150
		))
	elif randf() < exploration_drive:
		current_goals.append(Goal.new(
			"explore",
			GoalPriority.MEDIUM,
			{"radius": 20},
			GameManager.tick_count + 200
		))

# === Action Planning ===

func _plan_action_for_goal(goal: Goal) -> Dictionary:
	match goal.type:
		"incarnate_pawn":
			return _plan_incarnation(goal)
		"heal_self":
			return _plan_healing(goal)
		"find_food":
			return _plan_food_acquisition(goal)
		"improve_mood":
			return _plan_mood_improvement(goal)
		"find_work":
			return _plan_work_finding(goal)
		"socialize":
			return _plan_social_interaction(goal)
		"explore":
			return _plan_exploration(goal)
		_:
			return {}

func _plan_incarnation(goal: Goal) -> Dictionary:
	var pawn_id: int = goal.target_data.get("pawn_id", -1)
	if pawn_id < 0:
		return {}
	
	var command: CommandAPI.Command = CommandAPI.Command.new(
		CommandAPI.CommandType.REQUEST_INCARNATION,
		-1,  # Spectator actor
		{"pawn_id": pawn_id}
	)
	
	return {
		"type": "incarnate",
		"command": command,
		"confidence": 0.8
	}

func _plan_healing(goal: Goal) -> Dictionary:
	var pawn_obs: Dictionary = ObservationAPI.observe_pawn(controlled_pawn_id)
	if pawn_obs.has("error"):
		return {}
	
	# Look for beds or safe locations to rest
	var current_tile: Dictionary = pawn_obs.get("tile_pos", {"x": 0, "y": 0})
	var tile_obs: Dictionary = ObservationAPI.observe_tile(current_tile.x, current_tile.y)
	
	if tile_obs.get("feature_name") == "Bed":
		return {
			"type": "rest",
			"action": "perform_presence",
			"confidence": 0.9
		}
	
	# Move towards settlement center or safe area
	var settlement: Dictionary = tile_obs.get("settlement", {})
	if not settlement.is_empty():
		var center_region: int = settlement.get("center_region", -1)
		if center_region >= 0:
			return {
				"type": "move_to_safety",
				"action": "move",
				"target_region": center_region,
				"confidence": 0.7
			}
	
	return {}

func _plan_food_acquisition(goal: Goal) -> Dictionary:
	var pawn_obs: Dictionary = ObservationAPI.observe_pawn(controlled_pawn_id)
	if pawn_obs.has("error"):
		return {}
	
	# Look for forage jobs or food sources
	var current_tile: Dictionary = pawn_obs.get("tile_pos", {"x": 0, "y": 0})
	var tile_obs: Dictionary = ObservationAPI.observe_tile(current_tile.x, current_tile.y)
	
	if tile_obs.get("forage", 0) > 0:
		return {
			"type": "forage",
			"action": "perform_presence",
			"confidence": 0.8
		}
	
	# Look for existing forage jobs
	# This would require job observation API extension
	return {
		"type": "search_food",
		"action": "explore",
		"confidence": 0.5
	}

func _plan_work_finding(goal: Goal) -> Dictionary:
	# This would require job observation API
	# For now, perform presence action to look for opportunities
	return {
		"type": "seek_work",
		"action": "perform_presence",
		"confidence": 0.6
	}

func _plan_mood_improvement(goal: Goal) -> Dictionary:
	var pawn_obs: Dictionary = ObservationAPI.observe_pawn(controlled_pawn_id)
	if pawn_obs.has("error"):
		return {}
	
	# Social interaction or exploration based on personality
	if social_tendency > exploration_drive:
		return {
			"type": "social_mood_boost",
			"action": "explore",
			"confidence": 0.5
		}
	else:
		return {
			"type": "exploration_mood_boost",
			"action": "explore",
			"confidence": 0.5
		}

func _plan_social_interaction(goal: Goal) -> Dictionary:
	return {
		"type": "social_exploration",
		"action": "explore",
		"confidence": 0.6
	}

func _plan_exploration(goal: Goal) -> Dictionary:
	var pawn_obs: Dictionary = ObservationAPI.observe_pawn(controlled_pawn_id)
	if pawn_obs.has("error"):
		return {}
	
	var current_tile: Dictionary = pawn_obs.get("tile_pos", {"x": 0, "y": 0})
	var radius: int = goal.target_data.get("radius", 10)
	
	# Pick random direction within radius
	var angle: float = randf() * 2.0 * PI
	var distance: float = randf() * radius
	var target_x: int = current_tile.x + int(cos(angle) * distance)
	var target_y: int = current_tile.y + int(sin(angle) * distance)
	
	return {
		"type": "explore_area",
		"action": "move",
		"target_tile": {"x": target_x, "y": target_y},
		"confidence": 0.7
	}

# === Action Execution ===

func _execute_action(action: Dictionary) -> void:
	if action.is_empty():
		return
	
	var action_type: String = action.get("type", "")
	var confidence: float = action.get("confidence", 0.0)
	
	# Only execute if confidence meets personality threshold
	var threshold: float = 1.0 - caution
	if confidence < threshold:
		return
	
	match action.get("action", ""):
		"incarnate":
			_execute_incarnation(action)
		"move":
			_execute_move(action)
		"perform_presence":
			_execute_presence(action)
		"explore":
			_execute_explore(action)

func _execute_incarnation(action: Dictionary) -> void:
	var command: CommandAPI.Command = action.get("command", null)
	if command != null:
		var result: Dictionary = CommandAPI.execute_command(command)
		if result.get("success", false):
			controlled_pawn_id = action.get("target_pawn_id", -1)

func _execute_move(action: Dictionary) -> void:
	var target_tile: Dictionary = action.get("target_tile", {})
	if target_tile.is_empty():
		return
	
	var command: CommandAPI.Command = CommandAPI.Command.new(
		CommandAPI.CommandType.MOVE_PAWN,
		controlled_pawn_id,
		target_tile
	)
	
	var result: Dictionary = CommandAPI.execute_command(command)
	memory.add_outcome("move_to_" + str(target_tile.x) + "," + str(target_tile.y), result)

func _execute_presence(action: Dictionary) -> void:
	var command: CommandAPI.Command = CommandAPI.Command.new(
		CommandAPI.CommandType.PERFORM_PRESENCE,
		controlled_pawn_id,
		{}
	)
	
	var result: Dictionary = CommandAPI.execute_command(command)
	memory.add_outcome("perform_presence", result)

func _execute_explore(action: Dictionary) -> void:
	# Exploration is just movement with exploration intent
	_execute_move(action)

# === Goal Assessment ===

func _is_goal_completed(goal: Goal) -> bool:
	match goal.type:
		"incarnate_pawn":
			return controlled_pawn_id == goal.target_data.get("pawn_id", -1)
		"heal_self":
			var pawn_obs: Dictionary = ObservationAPI.observe_pawn(controlled_pawn_id)
			if not pawn_obs.has("error"):
				return pawn_obs.get("health_percentage", 0) >= goal.target_data.get("target_health", 50)
		"find_food":
			var pawn_obs: Dictionary = ObservationAPI.observe_pawn(controlled_pawn_id)
			if not pawn_obs.has("error"):
				return pawn_obs.get("hunger", 100) <= goal.target_data.get("target_hunger", 50)
		"find_work":
			var pawn_obs: Dictionary = ObservationAPI.observe_pawn(controlled_pawn_id)
			if not pawn_obs.has("error"):
				return pawn_obs.get("current_job", "None") != "None"
		_:
			return false
	return false

func _calculate_goal_progress(goal: Goal) -> float:
	# Simple progress calculation based on goal type
	match goal.type:
		"incarnate_pawn":
			return 1.0 if controlled_pawn_id == goal.target_data.get("pawn_id", -1) else 0.0
		"heal_self":
			var pawn_obs: Dictionary = ObservationAPI.observe_pawn(controlled_pawn_id)
			if not pawn_obs.has("error"):
				var current: int = pawn_obs.get("health_percentage", 0)
				var target: int = goal.target_data.get("target_health", 50)
				return float(current) / float(target)
			return 0.0
		"find_food":
			var pawn_obs: Dictionary = ObservationAPI.observe_pawn(controlled_pawn_id)
			if not pawn_obs.has("error"):
				var current: float = pawn_obs.get("hunger", 100)
				var target: float = goal.target_data.get("target_hunger", 50)
				return 1.0 - (float(current - target) / 100.0)
			return 0.0
		_:
			return 0.0

# === Public Interface ===

func set_controlled_pawn(pawn_id: int) -> void:
	controlled_pawn_id = pawn_id

func get_status() -> Dictionary:
	return {
		"agent_id": agent_id,
		"agent_type": agent_type,
		"controlled_pawn_id": controlled_pawn_id,
		"current_goals": current_goals.size(),
		"personality": {
			"aggressiveness": aggressiveness,
			"caution": caution,
			"social_tendency": social_tendency,
			"exploration_drive": exploration_drive,
			"self_preservation": self_preservation
		},
		"memory_size": memory.observations.size(),
		"last_decision_tick": last_decision_tick
	}

func get_active_goals() -> Array[Goal]:
	return current_goals.filter(func(g: Goal) -> bool: return not g.completed)

func add_goal(goal: Goal) -> void:
	current_goals.append(goal)
