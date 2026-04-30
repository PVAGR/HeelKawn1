extends AIAgent
class_name CivilizationAgent
## Enhanced AI Agent for civilization building and long-term world creation
## Extends base AIAgent with learning, cultural development, and technological progression

enum CivilizationEra {
	PREHISTORIC = 0,    # Stone age, hunter-gatherer
	ANCIENT = 1,        # Agriculture, writing, early cities
	CLASSICAL = 2,      # Philosophy, engineering, empires
	MEDIEVAL = 3,       # Feudalism, guilds, universities
	RENAISSANCE = 4,    # Scientific method, exploration
	INDUSTRIAL = 5,     # Manufacturing, urbanization
	MODERN = 6          # Digital age, globalization
}

enum SkillCategory {
	SURVIVAL = 0,       # Hunting, gathering, basic needs
	CRAFTING = 1,       # Tool making, construction
	SOCIAL = 2,         # Communication, leadership
	KNOWLEDGE = 3,      # Learning, teaching, innovation
	TECHNOLOGY = 4,     # Advanced tools, engineering
	ARTISTIC = 5        # Culture, music, storytelling
}

class CivilizationGoal extends Goal:
	var era_requirement: CivilizationEra
	var skill_requirements: Dictionary = {}  # SkillCategory -> minimum level
	var cultural_prerequisites: Array[String] = []
	var impact_persistence: float = 0.0  # How long this goal affects world history

class Skill extends RefCounted:
	var category: SkillCategory
	var level: int = 0  # 0-100
	var experience: float = 0.0
	var teaching_ability: float = 0.0
	var last_practice_tick: int = 0
	
	func add_exp(amount: float) -> void:
		experience += amount
		var required_exp: float = _get_exp_for_next_level()
		if experience >= required_exp and level < 100:
			experience -= required_exp
			level += 1
			teaching_ability = level * 0.1

	func _get_exp_for_next_level() -> float:
		return pow(1.1, level) * 100.0

class AgentCulturalMemory extends Memory:
	var traditions: Array[String] = []
	var beliefs: Array[String] = []
	var language_elements: Dictionary = {}  # word -> meaning
	var art_styles: Array[String] = []
	var social_norms: Array[String] = []
	var historical_events: Array[String] = []
	
	func add_tradition(tradition: String) -> void:
		if not traditions.has(tradition):
			traditions.append(tradition)
	
	func add_historical_event(event: String) -> void:
		historical_events.append(event)
		# Keep only last 100 events
		if historical_events.size() > 100:
			historical_events.pop_front()

class PersonalityEvolution:
	var core_traits: Dictionary = {}  # trait_name -> value (0.0-1.0)
	var learned_behaviors: Array[String] = []
	var trauma_responses: Array[String] = []
	var aspiration_drives: Dictionary = {}  # goal_type -> drive_strength
	
	func evolve_from_experience(memory: AgentCulturalMemory, recent_events: Array) -> void:
		# Personality changes based on significant experiences
		for event in recent_events:
			_analyze_event_impact(event)
	
	func _analyze_event_impact(event: String) -> void:
		# Analyze how events shape personality
		if "disaster" in event or "death" in event:
			core_traits["caution"] = min(1.0, core_traits.get("caution", 0.5) + 0.1)
		if "discovery" in event or "innovation" in event:
			core_traits["curiosity"] = min(1.0, core_traits.get("curiosity", 0.5) + 0.1)
		if "war" in event or "conflict" in event:
			core_traits["aggressiveness"] = min(1.0, core_traits.get("aggressiveness", 0.5) + 0.05)

# Enhanced properties
var civilization_era: CivilizationEra = CivilizationEra.PREHISTORIC
var skills: Dictionary = {}  # SkillCategory -> Skill
var cultural_memory: AgentCulturalMemory
var personality_evolution: PersonalityEvolution
var teaching_cooldown: int = 0
var innovation_points: float = 0.0
var cultural_influence: float = 0.0

# Learning parameters
var learning_rate: float = 1.0
var teaching_effectiveness: float = 1.0
var innovation_tendency: float = 0.1

func _init(id: int, type: AgentType = AgentType.TACTICAL):
	super(id, type)
	cultural_memory = AgentCulturalMemory.new()
	personality_evolution = PersonalityEvolution.new()
	_initialize_skills()
	_initialize_personality_traits()

func _initialize_skills() -> void:
	for category in SkillCategory.values():
		var skill: Skill = Skill.new()
		skill.category = category
		skills[category] = skill

func _initialize_personality_traits() -> void:
	personality_evolution.core_traits = {
		"curiosity": exploration_drive,
		"caution": caution,
		"aggressiveness": aggressiveness,
		"social": social_tendency,
		"innovation": innovation_tendency,
		"leadership": 0.3,
		"tradition": 0.5
	}

# === Enhanced Goal Generation ===

func _add_goal(goal_type: String, priority: GoalPriority, target_data: Dictionary = {}) -> void:
	var goal: Goal = Goal.new(goal_type, priority, target_data)
	current_goals.append(goal)

func _generate_goals() -> void:
	# Generate era-appropriate goals
	match civilization_era:
		CivilizationEra.PREHISTORIC:
			_generate_prehistoric_goals()
		CivilizationEra.ANCIENT:
			_generate_ancient_goals()
		CivilizationEra.CLASSICAL:
			_generate_classical_goals()
		CivilizationEra.MEDIEVAL:
			_generate_medieval_goals()
		CivilizationEra.RENAISSANCE:
			_generate_renaissance_goals()
		CivilizationEra.INDUSTRIAL:
			_generate_industrial_goals()
		CivilizationEra.MODERN:
			_generate_modern_goals()

func _generate_prehistoric_goals() -> void:
	# Basic survival and discovery goals
	if skills[SkillCategory.SURVIVAL].level < 20:
		_add_goal("improve_survival_skills", GoalPriority.HIGH, {})
	
	if innovation_points > 5.0:
		_add_goal("discover_fire", GoalPriority.CRITICAL, {"innovation_cost": 10.0})
	
	if cultural_memory.traditions.size() < 3:
		_add_goal("establish_oral_traditions", GoalPriority.MEDIUM, {})

func _generate_ancient_goals() -> void:
	# Agriculture, writing, settlements
	if skills[SkillCategory.CRAFTING].level < 30:
		_add_goal("develop_agriculture", GoalPriority.HIGH, {})
	
	if not cultural_memory.language_elements.has("writing"):
		_add_goal("invent_writing", GoalPriority.CRITICAL, {"innovation_cost": 15.0})

func _generate_classical_goals() -> void:
	# Philosophy, engineering, governance
	if skills[SkillCategory.KNOWLEDGE].level < 50:
		_add_goal("develop_philosophy", GoalPriority.MEDIUM, {})
	
	if cultural_memory.social_norms.size() < 10:
		_add_goal("establish_governance", GoalPriority.HIGH, {})

func _generate_medieval_goals() -> void:
	# Guilds, universities, architecture
	if skills[SkillCategory.CRAFTING].level < 70:
		_add_goal("form_guilds", GoalPriority.MEDIUM, {})
	
	if skills[SkillCategory.KNOWLEDGE].level < 60:
		_add_goal("found_university", GoalPriority.HIGH, {})

func _generate_renaissance_goals() -> void:
	# Scientific method, exploration
	if innovation_points > 20.0:
		_add_goal("develop_scientific_method", GoalPriority.CRITICAL, {"innovation_cost": 25.0})

func _generate_industrial_goals() -> void:
	# Manufacturing, urbanization
	if skills[SkillCategory.TECHNOLOGY].level < 80:
		_add_goal("invent_mass_production", GoalPriority.HIGH, {})

func _generate_modern_goals() -> void:
	# Digital technology, globalization
	if innovation_points > 50.0:
		_add_goal("develop_digital_technology", GoalPriority.CRITICAL, {"innovation_cost": 40.0})

# === Learning and Skill Development ===

func practice_skill(category: SkillCategory, context: String = "") -> void:
	var skill: Skill = skills[category]
	var base_exp: float = 1.0 * learning_rate
	
	# Context-based bonuses
	if context == "teaching":
		base_exp *= 1.5
	elif context == "innovation":
		base_exp *= 2.0
	
	# Personality affects learning
	var curiosity: float = personality_evolution.core_traits.get("curiosity", 0.5)
	base_exp *= (1.0 + curiosity)
	
	skill.add_exp(base_exp)
	skill.last_practice_tick = GameManager.tick_count

func teach_skill(target_agent: CivilizationAgent, category: SkillCategory) -> bool:
	var my_skill: Skill = skills[category]
	var target_skill: Skill = target_agent.skills[category]
	
	if my_skill.level <= target_skill.level:
		return false  # Can't teach what you don't know better
	
	# Teaching effectiveness based on skill gap and personality
	var teaching_power: float = my_skill.teaching_ability * teaching_effectiveness
	var exp_transfer: float = teaching_power * 0.5
	
	target_skill.add_exp(exp_transfer)
	
	# Teacher also gains experience from teaching
	practice_skill(category, "teaching")
	
	# Record cultural transmission
	cultural_memory.add_historical_event("Taught %s to Agent %d" % [SkillCategory.keys()[category], target_agent.agent_id])
	
	return true

func innovate_discovery(category: SkillCategory) -> bool:
	if innovation_points < 10.0:
		return false
	
	var innovation: float = personality_evolution.core_traits.get("innovation", 0.1)
	var success_chance: float = innovation * skills[category].level * 0.01
	
	if _deterministic_chance("civilization:innovate:%d" % int(category), success_chance, _decision_salt(101)):
		innovation_points -= 10.0
		skills[category].level = min(100, skills[category].level + 5)
		
		# Record innovation in existing WorldMemory
		var discovery: String = "Innovation in %s: %s" % [SkillCategory.keys()[category], _generate_discovery_name()]
		cultural_memory.add_historical_event(discovery)
		cultural_influence += 5.0
		
		return true
	
	return false

func _generate_discovery_name() -> String:
	var prefixes = ["New", "Advanced", "Improved", "Revolutionary"]
	var suffixes = ["Method", "Technique", "Tool", "System", "Process"]
	
	var salt: int = _decision_salt(107)
	var prefix: String = prefixes[WorldRNG.index_for(_agent_stream("civilization:discovery_prefix"), prefixes.size(), salt)]
	var suffix: String = suffixes[WorldRNG.index_for(_agent_stream("civilization:discovery_suffix"), suffixes.size(), salt + 1)]
	return "%s %s" % [prefix, suffix]

# === Cultural Development ===

func develop_culture() -> void:
	# Cultural development based on experiences and personality
	var social_tendency: float = personality_evolution.core_traits.get("social", 0.5)
	var tradition_tendency: float = personality_evolution.core_traits.get("tradition", 0.5)
	
	if _deterministic_chance("civilization:create_social_norm", social_tendency * 0.1, _decision_salt(113)):
		_create_social_norm()
	
	if _deterministic_chance("civilization:create_tradition", tradition_tendency * 0.05, _decision_salt(127)):
		_create_tradition()

func _create_social_norm() -> void:
	var norms = [
		"Share food with elders",
		"Respect skilled craftsmen",
		"Honor agreements",
		"Protect the young",
		"Preserve knowledge"
	]
	
	var norm: String = norms[WorldRNG.index_for(_agent_stream("civilization:social_norm"), norms.size(), _decision_salt(131))]
	cultural_memory.social_norms.append(norm)
	cultural_influence += 1.0

func _create_tradition() -> void:
	var traditions = [
		"Seasonal harvest festivals",
		"Coming of age ceremonies",
		"Ancestor remembrance",
		"Storytelling gatherings",
		"Skill apprenticeship rituals"
	]
	
	var tradition: String = traditions[WorldRNG.index_for(_agent_stream("civilization:tradition"), traditions.size(), _decision_salt(137))]
	cultural_memory.add_tradition(tradition)
	cultural_influence += 2.0

# === Era Progression ===

func check_era_advancement() -> void:
	var current_era_requirements: Dictionary = _get_era_requirements()
	var meets_requirements: bool = true
	
	for category in current_era_requirements:
		var required_level: int = current_era_requirements[category]
		if skills[category].level < required_level:
			meets_requirements = false
			break
	
	if meets_requirements and civilization_era < CivilizationEra.MODERN:
		_advance_to_next_era()

func _get_era_requirements() -> Dictionary:
	match civilization_era:
		CivilizationEra.PREHISTORIC:
			return {SkillCategory.SURVIVAL: 20}
		CivilizationEra.ANCIENT:
			return {SkillCategory.CRAFTING: 30, SkillCategory.SOCIAL: 25}
		CivilizationEra.CLASSICAL:
			return {SkillCategory.KNOWLEDGE: 50, SkillCategory.CRAFTING: 40}
		CivilizationEra.MEDIEVAL:
			return {SkillCategory.CRAFTING: 70, SkillCategory.SOCIAL: 60}
		CivilizationEra.RENAISSANCE:
			return {SkillCategory.KNOWLEDGE: 70, SkillCategory.TECHNOLOGY: 50}
		CivilizationEra.INDUSTRIAL:
			return {SkillCategory.TECHNOLOGY: 80, SkillCategory.CRAFTING: 75}
		CivilizationEra.MODERN:
			return {SkillCategory.TECHNOLOGY: 90, SkillCategory.KNOWLEDGE: 85}
		_:
			return {}

func _advance_to_next_era() -> void:
	civilization_era = CivilizationEra.values()[civilization_era + 1]
	
	# Record era advancement in cultural memory
	var era_name: String = CivilizationEra.keys()[civilization_era]
	cultural_memory.add_historical_event("Entered %s Era" % era_name)
	cultural_influence += 20.0
	
	# Bonus innovation points for era advancement
	innovation_points += 25.0

# === Enhanced Decision Making ===

func _make_decisions() -> void:
	# Update personality based on recent experiences
	var recent_events: Array = cultural_memory.historical_events.slice(-10)
	personality_evolution.evolve_from_experience(cultural_memory, recent_events)
	
	# Practice relevant skills
	_practice_current_skills()
	
	# Attempt innovations
	if _deterministic_chance("civilization:attempt_innovation", innovation_tendency, _decision_salt(149)):
		var category: SkillCategory = SkillCategory.values()[WorldRNG.index_for(_agent_stream("civilization:innovation_category"), SkillCategory.size(), _decision_salt(151))]
		innovate_discovery(category)
	
	# Develop culture
	develop_culture()
	
	# Check for era advancement
	check_era_advancement()
	
	# Call parent decision making
	super._make_decisions()

func _practice_current_skills() -> void:
	# Practice skills based on current goals
	for goal in current_goals:
		match goal.type:
			"improve_survival_skills":
				practice_skill(SkillCategory.SURVIVAL)
			"develop_agriculture":
				practice_skill(SkillCategory.CRAFTING)
			"invent_writing":
				practice_skill(SkillCategory.KNOWLEDGE)
			"develop_philosophy":
				practice_skill(SkillCategory.KNOWLEDGE)
			"develop_scientific_method":
				practice_skill(SkillCategory.KNOWLEDGE)
			"invent_mass_production":
				practice_skill(SkillCategory.TECHNOLOGY)
			"develop_digital_technology":
				practice_skill(SkillCategory.TECHNOLOGY)

# === Public Interface ===

func get_civilization_status() -> Dictionary:
	return {
		"era": CivilizationEra.keys()[civilization_era],
		"skills": _get_skills_summary(),
		"cultural_influence": cultural_influence,
		"innovation_points": innovation_points,
		"traditions_count": cultural_memory.traditions.size(),
		"historical_events_count": cultural_memory.historical_events.size()
	}

func _get_skills_summary() -> Dictionary:
	var summary: Dictionary = {}
	for category in skills:
		var skill: Skill = skills[category]
		summary[SkillCategory.keys()[category]] = skill.level
	return summary

func can_teach(category: SkillCategory) -> bool:
	return skills[category].level >= 50 and skills[category].teaching_ability > 1.0

func get_cultural_memory() -> AgentCulturalMemory:
	return cultural_memory
