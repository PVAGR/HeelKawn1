extends RefCounted
class_name PlayerIncarnation
## Player Incarnation System - Allows players to temporarily inhabit NPC sprites
## Players can experience the world from within and influence it through direct action

enum IncarnationMode {
	SPECTATOR = 0,      # Observing only, no control
	POSSESS = 1,        # Full control of NPC
	GUIDE = 2,          # Influence NPC decisions
	TEACH = 3           # Teach NPC new skills
}

class IncarnationRecord extends RefCounted:
	var player_id: String
	var npc_id: int
	var incarnation_start_tick: int
	var incarnation_end_tick: int = -1
	var actions_taken: Array[String] = []
	var skills_taught: Array[String] = []
	var influence_gained: float = 0.0
	var legacy_created: bool = false
	var experiences: Array[String] = []
	
	func _init(pid: String, nid: int, start_tick: int):
		player_id = pid
		npc_id = nid
		incarnation_start_tick = start_tick

class PlayerInfluence extends RefCounted:
	var player_id: String
	var total_incarnations: int = 0
	var total_influence: float = 0.0
	var skills_taught: int = 0
	var civilizations_helped: Array[int] = []
	var legendary_actions: Array[String] = []
	var reputation_score: float = 0.0
	var last_incarnation_tick: int = 0
	
	func add_incarnation(record: IncarnationRecord) -> void:
		total_incarnations += 1
		total_influence += record.influence_gained
		skills_taught += record.skills_taught.size()
		last_incarnation_tick = record.incarnation_end_tick
		
		# Check for legendary actions
		for action in record.actions_taken:
			if _is_legendary_action(action):
				legendary_actions.append(action)
				reputation_score += 10.0
	
	func _is_legendary_action(action: String) -> bool:
	var legendary_actions = [
		"discovered_fire",
		"invented_writing",
		"founded_city",
		"ended_war",
		"created_art_masterpiece",
		"achieved_enlightenment"
	]
	
	return action in legendary_actions

# Incarnation properties
var current_incarnation: IncarnationRecord = null
var incarnation_mode: IncarnationMode = IncarnationMode.SPECTATOR
var max_incarnation_duration: int = 1000  # ticks
var current_duration: int = 0
var player_influence_data: Dictionary = {}  # player_id -> PlayerInfluence

# Influence and legacy parameters
var base_influence_rate: float = 0.1  # Influence gained per tick
var teaching_multiplier: float = 2.0
var legendary_threshold: float = 50.0  # Influence needed for legendary status
var reincarnation_cooldown: int = 500  # ticks between incarnations

# Experience tracking
var shared_experiences: Array[String] = []
var world_impacts: Array[String] = []
var cultural_contributions: Array[String] = []

func _ready() -> void:
	# Initialize with default settings
	pass

# === Incarnation Management ===

func start_incarnation(player_id: String, npc_id: int, mode: IncarnationMode = IncarnationMode.POSSESS) -> bool:
	# Check if player can incarnate
	if not _can_incarnate(player_id):
		return false
	
	# Check if NPC is available
	if not _is_npc_available(npc_id):
		return false
	
	# Create incarnation record
	var current_tick: int = GameManager.tick_count
	current_incarnation = IncarnationRecord.new(player_id, npc_id, current_tick)
	current_incarnation_mode = mode
	current_duration = 0
	
	# Get player influence data
	if not player_influence_data.has(player_id):
		player_influence_data[player_id] = PlayerInfluence.new()
	
	# Connect to NPC systems
	_connect_to_npc(npc_id)
	
	# Record incarnation start
	_record_experience("Player %s incarnated as NPC %d" % [player_id, npc_id])
	
	return true

func end_incarnation() -> void:
	if current_incarnation == null:
		return
	
	# Finalize incarnation record
	current_incarnation.incarnation_end_tick = GameManager.tick_count
	current_duration = GameManager.tick_count - current_incarnation.incarnation_start_tick
	
	# Update player influence data
	var player_data: PlayerInfluence = player_influence_data[current_incarnation.player_id]
	player_data.add_incarnation(current_incarnation)
	
	# Check for legacy creation
	if current_incarnation.influence_gained >= legendary_threshold:
		current_incarnation.legacy_created = true
		_create_legacy(current_incarnation)
	
	# Disconnect from NPC
	_disconnect_from_npc(current_incarnation.npc_id)
	
	# Record incarnation end
	_record_experience("Player %s ended incarnation with %.1f influence" % [
		current_incarnation.player_id, current_incarnation.influence_gained])
	
	current_incarnation = null
	incarnation_mode = IncarnationMode.SPECTATOR

func _can_incarnate(player_id: String) -> bool:
	if current_incarnation != null:
		return false  # Already incarnating
	
	var player_data: PlayerInfluence = player_influence_data.get(player_id)
	if player_data != null:
		var cooldown_remaining: int = player_data.last_incarnation_tick + reincarnation_cooldown - GameManager.tick_count
		if cooldown_remaining > 0:
			return false  # Still in cooldown
	
	return true

func _is_npc_available(npc_id: int) -> bool:
	# Check if NPC exists and is not already controlled
	var pawn_obs: Dictionary = ObservationAPI.observe_pawn(npc_id)
	if pawn_obs.has("error"):
		return false
	
	# Check if NPC is already controlled by AI agent
	var ai_manager: AIAgentManager = GameManager.get_node("/root/AIAgentManager")
	if ai_manager != null:
		for agent_id in ai_manager.agents:
			var agent: AIAgent = ai_manager.agents[agent_id]
			if agent.controlled_pawn_id == npc_id:
				return false  # Already controlled by AI
	
	return true

func _connect_to_npc(npc_id: int) -> void:
	# Connect to NPC's systems for control and influence
	# This would integrate with the pawn's action systems
	pass

func _disconnect_from_npc(npc_id: int) -> void:
	# Disconnect from NPC's systems
	pass

# === Incarnation Actions ===

func execute_action(action_type: String, target_data: Dictionary = {}) -> bool:
	if current_incarnation == null or incarnation_mode != IncarnationMode.POSSESS:
		return false
	
	# Execute action through NPC
	var success: bool = _execute_npc_action(current_incarnation.npc_id, action_type, target_data)
	
	if success:
		current_incarnation.actions_taken.append(action_type)
		_gain_influence(base_influence_rate)
		_record_action(action_type, target_data)
	
	return success

func teach_skill(skill_name: String, target_agent_id: int = -1) -> bool:
	if current_incarnation == null or incarnation_mode != IncarnationMode.TEACH:
		return false
	
	var success: bool = false
	
	if target_agent_id >= 0:
		# Teach specific AI agent
		success = _teach_ai_agent(target_agent_id, skill_name)
	else:
		# Teach current NPC
		success = _teach_current_npc(skill_name)
	
	if success:
		current_incarnation.skills_taught.append(skill_name)
		_gain_influence(base_influence_rate * teaching_multiplier)
		_record_experience("Taught skill: %s" % skill_name)
	
	return success

func guide_decision(guidance: String) -> bool:
	if current_incarnation == null or incarnation_mode != IncarnationMode.GUIDE:
		return false
	
	# Influence NPC's decision-making process
	var success: bool = _influence_npc_decision(current_incarnation.npc_id, guidance)
	
	if success:
		_gain_influence(base_influence_rate * 0.5)
		_record_experience("Provided guidance: %s" % guidance)
	
	return success

func _execute_npc_action(npc_id: int, action_type: String, target_data: Dictionary) -> bool:
	# Execute action through CommandAPI
	var command_data: Dictionary = {
		"action": action_type,
		"pawn_id": npc_id,
		"target": target_data
	}
	
	var result: Dictionary = CommandAPI.execute_command(command_data)
	return not result.has("error")

func _teach_ai_agent(agent_id: int, skill_name: String) -> bool:
	var ai_manager: AIAgentManager = GameManager.get_node("/root/AIAgentManager")
	if ai_manager == null:
		return false
	
	var agent: AIAgent = ai_manager.agents.get(agent_id)
	if agent == null:
		return false
	
	# If it's a civilization agent, teach the skill
	if agent is CivilizationAgent:
		var civ_agent: CivilizationAgent = agent as CivilizationAgent
		var skill_category: int = _get_skill_category(skill_name)
		civ_agent.practice_skill(skill_category, "teaching")
		return true
	
	return false

func _teach_current_npc(skill_name: String) -> bool:
	# Teach skill to the currently incarnated NPC
	# This would integrate with the pawn's skill system
	return true

func _influence_npc_decision(npc_id: int, guidance: String) -> bool:
	# Influence NPC's next decision
	# This would integrate with the AI agent's goal system
	return true

func _get_skill_category(skill_name: String) -> int:
	# Map skill names to categories
	match skill_name.to_lower():
		"hunting", "gathering", "fishing":
			return CivilizationAgent.SkillCategory.SURVIVAL
		"crafting", "building", "toolmaking":
			return CivilizationAgent.SkillCategory.CRAFTING
		"communication", "leadership", "diplomacy":
			return CivilizationAgent.SkillCategory.SOCIAL
		"reading", "writing", "research":
			return CivilizationAgent.SkillCategory.KNOWLEDGE
		"engineering", "invention", "technology":
			return CivilizationAgent.SkillCategory.TECHNOLOGY
		"art", "music", "storytelling":
			return CivilizationAgent.SkillCategory.ARTISTIC
		_:
			return CivilizationAgent.SkillCategory.SURVIVAL

# === Influence and Legacy ===

func _gain_influence(amount: float) -> void:
	if current_incarnation == null:
		return
	
	current_incarnation.influence_gained += amount
	
	# Check for significant influence milestones
	if current_incarnation.influence_gained >= 25.0 and not current_incarnation.experiences.has("notable_influence"):
		_record_experience("Gained notable influence (%.1f)" % current_incarnation.influence_gained)
		current_incarnation.experiences.append("notable_influence")
	
	if current_incarnation.influence_gained >= legendary_threshold and not current_incarnation.experiences.has("legendary_status"):
		_record_experience("Achieved legendary status (%.1f influence)" % current_incarnation.influence_gained)
		current_incarnation.experiences.append("legendary_status")

func _create_legacy(record: IncarnationRecord) -> void:
	# Create lasting legacy in the world
	var legacy_description: String = "Player %s became legendary through %s" % [
		record.player_id, _summarize_actions(record.actions_taken)
	]
	
	# Add to world memory
	WorldMemory.add_event("player_legacy", {
		"player_id": record.player_id,
		"npc_id": record.npc_id,
		"legacy": legacy_description,
		"tick": record.incarnation_end_tick,
		"influence": record.influence_gained
	})
	
	# Add to cultural contributions
	cultural_contributions.append(legacy_description)
	
	# Record world impact
	world_impacts.append("Legendary player influence: %s" % legacy_description)

func _summarize_actions(actions: Array[String]) -> String:
	if actions.size() == 0:
		return "mysterious means"
	
	var action_counts: Dictionary = {}
	for action in actions:
		action_counts[action] = action_counts.get(action, 0) + 1
	
	var summary_parts: Array[String] = []
	for action in action_counts:
		var count: int = action_counts[action]
		if count == 1:
			summary_parts.append(action)
		else:
			summary_parts.append("%s x%d" % [action, count])
	
	return ", ".join(summary_parts)

# === Experience Recording ===

func _record_experience(experience: String) -> void:
	shared_experiences.append(experience)
	
	# Keep only recent experiences
	if shared_experiences.size() > 100:
		shared_experiences = shared_experiences.slice(-50)
	
	# Add to world memory if significant
	if "legendary" in experience.to_lower() or "discovered" in experience.to_lower():
		WorldMemory.add_event("player_experience", {
			"experience": experience,
			"tick": GameManager.tick_count
		})

func _record_action(action_type: String, target_data: Dictionary) -> void:
	var action_description: String = "Player action: %s" % action_type
	if not target_data.is_empty():
		action_description += " (%s)" % str(target_data)
	
	_record_experience(action_description)

# === Public Interface ===

func get_incarnation_status() -> Dictionary:
	if current_incarnation == null:
		return {
			"incarnating": false,
			"mode": "spectator",
			"duration": 0
		}
	
	return {
		"incarnating": true,
		"player_id": current_incarnation.player_id,
		"npc_id": current_incarnation.npc_id,
		"mode": IncarnationMode.keys()[incarnation_mode],
		"duration": current_duration,
		"influence": current_incarnation.influence_gained,
		"actions": current_incarnation.actions_taken.size(),
		"skills_taught": current_incarnation.skills_taught.size()
	}

func get_player_influence(player_id: String) -> Dictionary:
	var player_data: PlayerInfluence = player_influence_data.get(player_id)
	if player_data == null:
		return {
			"player_id": player_id,
			"total_incarnations": 0,
			"total_influence": 0.0,
			"reputation": 0.0
		}
	
	return {
		"player_id": player_id,
		"total_incarnations": player_data.total_incarnations,
		"total_influence": player_data.total_influence,
		"skills_taught": player_data.skills_taught,
		"civilizations_helped": player_data.civilizations_helped.size(),
		"legendary_actions": player_data.legendary_actions.size(),
		"reputation": player_data.reputation_score,
		"last_incarnation": player_data.last_incarnation_tick
	}

func get_world_impacts() -> Dictionary:
	return {
		"total_experiences": shared_experiences.size(),
		"world_impacts": world_impacts.size(),
		"cultural_contributions": cultural_contributions.size(),
		"recent_experiences": shared_experiences.slice(-10),
		"major_impacts": world_impacts.slice(-5)
	}

func can_incarnate(player_id: String) -> bool:
	return _can_incarnate(player_id)

func get_available_npcs() -> Array[int]:
	var available: Array[int] = []
	
	# Get all pawns and filter for availability
	var all_pawns: Array = ObservationAPI.observe_pawns_in_region(0)  # All regions
	for pawn_data in all_pawns:
		var pawn_id: int = pawn_data.get("pawn_id", -1)
		if pawn_id >= 0 and _is_npc_available(pawn_id):
			available.append(pawn_id)
	
	return available

func set_incarnation_mode(mode: IncarnationMode) -> void:
	incarnation_mode = mode

func update() -> void:
	# Update current incarnation
	if current_incarnation != null:
		current_duration += 1
		
		# Check if duration exceeded
		if current_duration >= max_incarnation_duration:
			end_incarnation()
		
		# Passive influence gain while incarnated
		if current_duration % 10 == 0:  # Every 10 ticks
			_gain_influence(base_influence_rate * 0.1)
