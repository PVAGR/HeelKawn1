extends Node
## AI Agent Manager - Coordinates multiple AI agents and integrates with game loop
## Provides NPC-player parity by managing AI decision-making cycles

signal agent_spawned(agent_id: int, agent_type: AIAgent.AgentType)
signal agent_goal_completed(agent_id: int, goal_type: String)
signal agent_action_executed(agent_id: int, action_type: String, success: bool)

var agents: Dictionary = {}  # agent_id -> AIAgent
var civilization_agents: Dictionary = {}  # agent_id -> CivilizationAgent
var agent_text_overlays: Dictionary = {}  # agent_id -> Node
var next_agent_id: int = 1000  # Start AI agent IDs at 1000 to avoid conflicts
var max_agents: int = 10
var update_frequency: int = 15  # Update agents every N ticks (faster)
var last_update_tick: int = 0
var enabled: bool = true
var show_agent_overlays: bool = true

# Enhanced AI systems (temporarily disabled for stable testing)
# var WorldAIClass = preload("res://scripts/ai/WorldAI.gd")
# var SettlementAIClass = preload("res://scripts/ai/SettlementAI.gd")
# var CivilizationAgentClass = preload("res://scripts/ai/CivilizationAgent.gd")

# var world_ai: WorldAI
# var settlement_ai_system: Dictionary = {}  # settlement_id -> SettlementAI
var civilization_mode: bool = false  # Enhanced AI systems disabled for testing

# Agent spawning configuration
var strategic_agent_count: int = 2
var tactical_agent_count: int = 4
var reactive_agent_count: int = 2

func _ready() -> void:
	GameManager.game_tick.connect(_on_game_tick)
	
	# Initialize enhanced AI systems (disabled for testing)
	if civilization_mode:
		pass
		# world_ai = WorldAIClass.new()
		# _initialize_settlement_system()
	
	_spawn_initial_agents()

func _on_game_tick(tick: int) -> void:
	if not enabled:
		return
	
	# Update enhanced AI systems (disabled for testing)
	if civilization_mode:
		pass
		# if world_ai:
		#	world_ai.update()
		# 
		# for settlement_id in settlement_ai_system:
		#	var settlement: SettlementAI = settlement_ai_system[settlement_id]
		#	settlement.update()
	
	# Update agents at specified frequency
	if tick - last_update_tick >= update_frequency:
		_update_all_agents()
		last_update_tick = tick
	
	# Spawn new agents if under limit and conditions are met
	if tick % 600 == 0:  # Check every 600 ticks (~10 minutes at 1x speed)
		_maintain_agent_population()

func _spawn_initial_agents() -> void:
	var AIAgentClass = preload("res://scripts/ai/AIAgent.gd")
	
	# Spawn strategic agents
	for i in range(strategic_agent_count):
		_spawn_agent(AIAgentClass.AgentType.STRATEGIC)
	
	# Spawn tactical agents
	for i in range(tactical_agent_count):
		_spawn_agent(AIAgentClass.AgentType.TACTICAL)
	
	# Spawn reactive agents
	for i in range(reactive_agent_count):
		_spawn_agent(AIAgentClass.AgentType.REACTIVE)

func _spawn_agent(agent_type: AIAgent.AgentType) -> int:
	if agents.size() >= max_agents:
		return -1
	
	var agent_id: int = next_agent_id
	next_agent_id += 1
	
	var AIAgentClass = preload("res://scripts/ai/AIAgent.gd")
	var agent: AIAgent = AIAgentClass.new(agent_id, agent_type)
	
	# if civilization_mode:
	#	agent = CivilizationAgentClass.new(agent_id, agent_type)
	#	civilization_agents[agent_id] = agent
	
	agents[agent_id] = agent
	
	# Try to incarnate the agent if there are available pawns
	_try_incarnate_agent(agent)
	
	# Add to settlement if civilization mode
	# if civilization_mode and agent.controlled_pawn_id >= 0:
	#	_add_agent_to_settlement(agent_id)
	
	agent_spawned.emit(agent_id, agent_type)
	return agent_id

func _create_agent_text_overlay(agent_id: int) -> void:
	# Simplified text overlay system - disabled for now to avoid type issues
	# Will be implemented in a future update
	pass

func _try_incarnate_agent(agent: RefCounted) -> void:
	# Temporarily disabled incarnation system to prevent crashes
	# TODO: Fix ObservationAPI initialization and re-enable
	pass

func _select_pawn_for_agent(agent: AIAgent, candidates: Array) -> Dictionary:
	match agent.agent_type:
		AIAgent.AgentType.STRATEGIC:
			# Prefer pawns with high influence or in leadership positions
			var best_candidate: Dictionary = {}
			var best_score: float = -1.0
			
			for candidate in candidates:
				var score: float = 0.0
				var health: int = candidate.get("health_percentage", 0)
				var skills: Dictionary = candidate.get("skills", {})
				
				# Health is important for strategic agents
				score += float(health) / 100.0 * 0.3
				
				# Leadership skills
				var leadership: int = skills.get("leadership", 0)
				score += float(leadership) / 100.0 * 0.4
				
				# Age and experience
				var age: float = candidate.get("age_years", 0)
				if age > 30 and age < 60:
					score += 0.3
				
				if score > best_score:
					best_score = score
					best_candidate = candidate
			
			return best_candidate
		
		AIAgent.AgentType.TACTICAL:
			# Prefer healthy, capable workers
			var best_candidate: Dictionary = {}
			var best_score: float = -1.0
			
			for candidate in candidates:
				var score: float = 0.0
				var health: int = candidate.get("health_percentage", 0)
				var mood: float = candidate.get("mood", 50.0)
				var skills: Dictionary = candidate.get("skills", {})
				
				# Health and mood for tactical effectiveness
				score += float(health) / 100.0 * 0.4
				score += (100.0 - mood) / 100.0 * 0.2  # Lower mood = more driven
				
				# Work skills
				var construction: int = skills.get("construction", 0)
				var mining: int = skills.get("mining", 0)
				score += float(max(construction, mining)) / 100.0 * 0.4
				
				if score > best_score:
					best_score = score
					best_candidate = candidate
			
			return best_candidate
		
		AIAgent.AgentType.REACTIVE:
			# Prefer survivors with high self-preservation traits
			var best_candidate: Dictionary = {}
			var best_score: float = -1.0
			
			for candidate in candidates:
				var score: float = 0.0
				var health: int = candidate.get("health_percentage", 0)
				
				# Health is most important for reactive agents
				score += float(health) / 100.0 * 0.8
				
				# Some experience helps
				var age: float = candidate.get("age_years", 0)
				if age > 25:
					score += 0.2
				
				if score > best_score:
					best_score = score
					best_candidate = candidate
			
			return best_candidate
	
	return {}

func _is_pawn_controlled(pawn_id: int) -> bool:
	for agent in agents.values():
		if agent.controlled_pawn_id == pawn_id:
			return true
	return false

func _update_all_agents() -> void:
	for agent in agents.values():
		if agent != null:
			agent.update()

func _maintain_agent_population() -> void:
	# Remove dead agents
	var agents_to_remove: Array[int] = []
	
	for agent_id in agents:
		var agent: AIAgent = agents[agent_id]
		if agent.controlled_pawn_id >= 0:
			var pawn_obs: Dictionary = ObservationAPI.observe_pawn(agent.controlled_pawn_id)
			if not pawn_obs.has("error"):
				var health: int = pawn_obs.get("health_percentage", 0)
				if health <= 0:
					agents_to_remove.append(agent_id)
	
	# Remove dead agents
	for agent_id in agents_to_remove:
		# Clean up text overlay
		if agent_text_overlays.has(agent_id):
			var overlay: Node = agent_text_overlays[agent_id]
			if overlay != null:
				overlay.queue_free()
			agent_text_overlays.erase(agent_id)
		
		agents.erase(agent_id)
	
	# Spawn new agents if under population
	var current_count: int = agents.size()
	if current_count < max_agents:
		var deficit: int = max_agents - current_count
		for i in range(deficit):
			var agent_type: AIAgent.AgentType = _determine_agent_type_to_spawn()
			_spawn_agent(agent_type)

func _determine_agent_type_to_spawn() -> AIAgent.AgentType:
	# Count current agent types
	var strategic_count: int = 0
	var tactical_count: int = 0
	var reactive_count: int = 0
	
	for agent in agents.values():
		match agent.agent_type:
			AIAgent.AgentType.STRATEGIC:
				strategic_count += 1
			AIAgent.AgentType.TACTICAL:
				tactical_count += 1
			AIAgent.AgentType.REACTIVE:
				reactive_count += 1
	
	# Spawn type that's most underrepresented
	var ratios: Dictionary = {
		AIAgent.AgentType.STRATEGIC: float(strategic_count) / float(strategic_agent_count),
		AIAgent.AgentType.TACTICAL: float(tactical_count) / float(tactical_agent_count),
		AIAgent.AgentType.REACTIVE: float(reactive_count) / float(reactive_agent_count)
	}
	
	var lowest_ratio: float = 1.0
	var spawn_type: AIAgent.AgentType = AIAgent.AgentType.TACTICAL
	
	for agent_type in ratios:
		var ratio: float = ratios[agent_type]
		if ratio < lowest_ratio:
			lowest_ratio = ratio
			spawn_type = agent_type
	
	return spawn_type

# === Public Interface ===

func get_agent_count() -> int:
	return agents.size()

func get_agent_status(agent_id: int) -> Dictionary:
	if agents.has(agent_id):
		return agents[agent_id].get_status()
	return {"error": "Agent not found", "agent_id": agent_id}

func get_all_agent_status() -> Array[Dictionary]:
	var status: Array[Dictionary] = []
	for agent_id in agents:
		status.append(get_agent_status(agent_id))
	return status

func spawn_agent(agent_type: AIAgent.AgentType) -> int:
	return _spawn_agent(agent_type)

func remove_agent(agent_id: int) -> bool:
	if agents.has(agent_id):
		agents.erase(agent_id)
		return true
	return false

func set_enabled(enabled_state: bool) -> void:
	enabled = enabled_state

func get_controlled_pawns() -> Array[int]:
	var controlled_pawns: Array[int] = []
	for agent in agents.values():
		if agent.controlled_pawn_id >= 0:
			controlled_pawns.append(agent.controlled_pawn_id)
	return controlled_pawns

func get_agent_for_pawn(pawn_id: int) -> AIAgent:
	for agent in agents.values():
		if agent.controlled_pawn_id == pawn_id:
			return agent
	return null

# === Debug and Testing ===

func force_spawn_agent(agent_type: AIAgent.AgentType) -> int:
	return _spawn_agent(agent_type)

func force_incarnate_agent(agent_id: int, pawn_id: int) -> bool:
	if not agents.has(agent_id):
		return false
	
	var agent: AIAgent = agents[agent_id]
	if _is_pawn_controlled(pawn_id):
		return false
	
	agent.set_controlled_pawn(pawn_id)
	return true

func get_agent_memory(agent_id: int) -> AIAgent.Memory:
	if agents.has(agent_id):
		return agents[agent_id].memory
	return null

func add_agent_goal(agent_id: int, goal_type: String, priority: AIAgent.GoalPriority, target_data: Dictionary) -> bool:
	if not agents.has(agent_id):
		return false
	
	var agent: AIAgent = agents[agent_id]
	var goal: AIAgent.Goal = AIAgent.Goal.new(goal_type, priority, target_data)
	agent.add_goal(goal)
	return true

func set_agent_overlays_enabled(enabled: bool) -> void:
	show_agent_overlays = enabled
	
	# Toggle existing overlays
	for overlay in agent_text_overlays.values():
		if overlay != null:
			overlay.set_enabled(enabled)

func get_agent_text_overlay(agent_id: int) -> Node:
	return agent_text_overlays.get(agent_id, null)

# === Enhanced AI System Methods (Temporarily Disabled) ===

# func _initialize_settlement_system() -> void:
#	# Create initial settlement if none exist
#	if settlement_ai_system.size() == 0:
#		_create_initial_settlement()

# func _create_initial_settlement() -> void:
#	var initial_settlement: SettlementAI = SettlementAIClass.new(1, "First Settlement", Vector2i(127, 127))
#	settlement_ai_system[1] = initial_settlement
#	
#	if world_ai:
#		world_ai.register_settlement(initial_settlement)

# func _add_agent_to_settlement(agent_id: int) -> void:
#	# Find nearest settlement or add to existing
#	var nearest_settlement_id: int = _find_nearest_settlement(agent_id)
#	if nearest_settlement_id >= 0:
#		var settlement: SettlementAI = settlement_ai_system[nearest_settlement_id]
#		settlement.add_resident(agent_id)

# func _find_nearest_settlement(agent_id: int) -> int:
#	# Simple implementation - return first settlement
#	# In full implementation, would calculate distances
#	for settlement_id in settlement_ai_system:
#		return settlement_id
#	return -1
