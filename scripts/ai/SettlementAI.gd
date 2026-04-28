extends RefCounted
class_name SettlementAI
## Community-level AI for managing collective decision-making, cultural evolution, and settlement development

enum GovernmentType {
	TRIBAL = 0,        # Hunter-gatherer bands, consensus decisions
	CHIEFDOM = 1,      # Hereditary leadership, early hierarchy
	MONARCHY = 2,      # King/queen rule, feudal structure
	REPUBLIC = 3,      # Elected representatives, democratic
	THEOCRACY = 4,      # Religious leadership
	TECHNOCRACY = 5,    # Expert rule, merit-based
	ANARCHY = 6        # No formal government
}

enum DevelopmentFocus {
	SURVIVAL = 0,      # Food, shelter, basic needs
	EXPANSION = 1,     # Territory growth, colonization
	TRADE = 2,         # Economic development, commerce
	KNOWLEDGE = 3,     # Learning, research, innovation
	MILITARY = 4,      # Defense, conquest, security
	ARTISTIC = 5,      # Culture, religion, entertainment
	BALANCED = 6       # Mixed approach
}

class CollectiveGoal extends RefCounted:
	var goal_type: String
	var priority: int  # 0-100
	var resource_requirements: Dictionary = {}
	var labor_requirements: int = 0
	var expected_duration: int = 0  # in ticks
	var progress: float = 0.0
	var supporters: Array[int] = []  # Agent IDs
	var opponents: Array[int] = []   # Agent IDs
	
	func _init(type: String, prio: int, resources: Dictionary = {}, labor: int = 0, duration: int = 100):
		goal_type = type
		priority = prio
		resource_requirements = resources
		labor_requirements = labor
		expected_duration = duration

class CulturalNorm extends RefCounted:
	var norm_name: String
	var description: String
	var adherence_level: float = 0.0  # 0.0-1.0
	var origin_story: String = ""
	var enforcement_mechanism: String = "social"
	
	func _init(name: String, desc: String, story: String = ""):
		norm_name = name
		description = desc
		origin_story = story

class ResourceManagement extends RefCounted:
	var stockpiles: Dictionary = {}  # resource_type -> amount
	var production_rates: Dictionary = {}  # resource_type -> per_tick
	var consumption_rates: Dictionary = {}  # resource_type -> per_tick
	var trade_partners: Array[int] = []  # Settlement IDs
	var resource_priorities: Dictionary = {}  # resource_type -> priority
	
	func update_production() -> void:
		for resource in production_rates:
			var amount: float = production_rates[resource]
			stockpiles[resource] = stockpiles.get(resource, 0.0) + amount
	
	func update_consumption() -> void:
		for resource in consumption_rates:
			var amount: float = consumption_rates[resource]
			stockpiles[resource] = stockpiles.get(resource, 0.0) - amount
			# Prevent negative stockpiles
			if stockpiles[resource] < 0:
				stockpiles[resource] = 0

# Settlement properties
var settlement_id: int
var settlement_name: String
var location: Vector2i
var population: int = 0
var resident_agents: Array[int] = []  # Agent IDs
var government_type: GovernmentType = GovernmentType.TRIBAL
var development_focus: DevelopmentFocus = DevelopmentFocus.SURVIVAL
var collective_goals: Array[CollectiveGoal] = []
var cultural_norms: Array[CulturalNorm] = []
var resource_management: ResourceManagement
var diplomatic_relations: Dictionary = {}  # settlement_id -> relationship_score
var historical_events: Array[String] = []

# Cultural properties
var dominant_culture: String = ""
var language_family: String = ""
var religious_beliefs: Array[String] = []
var artistic_traditions: Array[String] = []
var technological_level: int = 0  # 0-100

# Leadership properties
var leader_id: int = -1
var council_members: Array[int] = []
var decision_making_process: String = "consensus"
var leadership_approval: float = 0.5  # 0.0-1.0

func _init(id: int, name: String, pos: Vector2i):
	settlement_id = id
	settlement_name = name
	location = pos
	resource_management = ResourceManagement.new()
	_initialize_cultural_norms()

func _initialize_cultural_norms() -> void:
	# Start with basic tribal norms
	cultural_norms.append(CulturalNorm.new("Share resources", "Community members share food and tools", "Survival necessity"))
	cultural_norms.append(CulturalNorm.new("Respect elders", "Older members receive deference", "Experience valued"))
	cultural_norms.append(CulturalNorm.new("Protect children", "Young members are community priority", "Future of the tribe"))

# === Population Management ===

func add_resident(agent_id: int) -> void:
	if not resident_agents.has(agent_id):
		resident_agents.append(agent_id)
		population += 1
		_update_collective_goals()

func remove_resident(agent_id: int) -> void:
	if resident_agents.has(agent_id):
		resident_agents.erase(agent_id)
		population -= 1
		_update_leadership()

func _update_leadership() -> void:
	# Remove leader if they're no longer resident
	if leader_id >= 0 and not resident_agents.has(leader_id):
		leader_id = -1
		_select_new_leader()

func _select_new_leader() -> void:
	if resident_agents.size() == 0:
		return
	
	match government_type:
		GovernmentType.TRIBAL:
			_tribal_leadership_selection()
		GovernmentType.CHIEFDOM:
			_chieftain_selection()
		GovernmentType.MONARCHY:
			_monarch_selection()
		GovernmentType.REPUBLIC:
			_republic_election()
		GovernmentType.THEOCRACY:
			_theocratic_selection()
		GovernmentType.TECHNOCRACY:
			_technocratic_selection()
		GovernmentType.ANARCHY:
			leader_id = -1  # No formal leader

func _tribal_leadership_selection() -> void:
	# Select based on age and wisdom (simplified)
	leader_id = resident_agents[0]  # First agent as elder
	decision_making_process = "consensus"
	
	# AuthoritySystem: grant civil authority to elder
	if AuthoritySystem != null and leader_id >= 0:
		AuthoritySystem.record_elder_recognition(leader_id)

func _chieftain_selection() -> void:
	# Hereditary or strongest warrior
	leader_id = resident_agents[randi() % resident_agents.size()]
	decision_making_process = "authoritarian"
	
	# AuthoritySystem: grant military authority to chief
	if AuthoritySystem != null and leader_id >= 0:
		AuthoritySystem.grant_authority(leader_id, AuthoritySystem.AuthorityContext.MILITARY, 0.3, "chieftain_selection")

func _monarch_selection() -> void:
	# Similar to chief but with more formal structure
	leader_id = resident_agents[randi() % resident_agents.size()]
	decision_making_process = "decrees"
	
	# AuthoritySystem: grant civil authority to monarch
	if AuthoritySystem != null and leader_id >= 0:
		AuthoritySystem.grant_authority(leader_id, AuthoritySystem.AuthorityContext.CIVIL, 0.4, "monarch_selection")

func _republic_election() -> void:
	# Most respected agent
	leader_id = resident_agents[randi() % resident_agents.size()]
	decision_making_process = "voting"
	
	# AuthoritySystem: grant civil authority through election
	if AuthoritySystem != null and leader_id >= 0:
		AuthoritySystem.grant_authority(leader_id, AuthoritySystem.AuthorityContext.CIVIL, 0.35, "republic_election")

func _theocratic_selection() -> void:
	# Most spiritually-influential agent
	leader_id = resident_agents[randi() % resident_agents.size()]
	decision_making_process = "divine_guidance"
	
	# AuthoritySystem: grant religious authority
	if AuthoritySystem != null and leader_id >= 0:
		AuthoritySystem.grant_authority(leader_id, AuthoritySystem.AuthorityContext.RELIGIOUS, 0.4, "theocratic_selection")

func _technocratic_selection() -> void:
	# Most skilled/knowledgeable agent
	leader_id = resident_agents[randi() % resident_agents.size()]
	decision_making_process = "expert_consensus"
	
	# AuthoritySystem: grant knowledge authority
	if AuthoritySystem != null and leader_id >= 0:
		AuthoritySystem.grant_authority(leader_id, AuthoritySystem.AuthorityContext.KNOWLEDGE, 0.35, "technocratic_selection")

# === Collective Decision Making ===

func propose_collective_goal(goal_type: String, proposer_id: int, priority: int = 50) -> bool:
	var goal: CollectiveGoal = CollectiveGoal.new(goal_type, priority)
	goal.supporters.append(proposer_id)
	
	# Check if goal aligns with development focus
	if not _goal_aligns_with_focus(goal_type):
		return false
	
	# Get community support
	var support_threshold: float = _get_support_threshold()
	var current_support: int = 1  # Proponent
	
	# Poll other residents
	for agent_id in resident_agents:
		if agent_id != proposer_id:
			if _agent_supports_goal(agent_id, goal):
				goal.supporters.append(agent_id)
				current_support += 1
	
	# Check if goal has enough support
	if float(current_support) / float(resident_agents.size()) >= support_threshold:
		collective_goals.append(goal)
		historical_events.append("Collective goal approved: %s" % goal_type)
		return true
	
	return false

func _goal_aligns_with_focus(goal_type: String) -> bool:
	match development_focus:
		DevelopmentFocus.SURVIVAL:
			return goal_type in ["gather_food", "build_shelter", "defend_settlement"]
		DevelopmentFocus.EXPANSION:
			return goal_type in ["explore_territory", "found_colony", "build_road"]
		DevelopmentFocus.TRADE:
			return goal_type in ["establish_trade_route", "build_market", "produce_goods"]
		DevelopmentFocus.KNOWLEDGE:
			return goal_type in ["build_library", "research_technology", "preserve_knowledge"]
		DevelopmentFocus.MILITARY:
			return goal_type in ["train_warriors", "build_fortifications", "conquer_territory"]
		DevelopmentFocus.ARTISTIC:
			return goal_type in ["create_art", "hold_festival", "build_monument"]
		DevelopmentFocus.BALANCED:
			return true  # Accept all goals
		_:
			return false

func _get_support_threshold() -> float:
	match government_type:
		GovernmentType.TRIBAL:
			return 0.7  # High consensus needed
		GovernmentType.CHIEFDOM:
			return 0.3  # Chief decides
		GovernmentType.MONARCHY:
			return 0.2  # Monarch decides
		GovernmentType.REPUBLIC:
			return 0.5  # Majority vote
		GovernmentType.THEOCRACY:
			return 0.4  # Religious approval
		GovernmentType.TECHNOCRACY:
			return 0.6  # Expert consensus
		GovernmentType.ANARCHY:
			return 0.8  # Individual consent
		_:
			return 0.5

func _agent_supports_goal(agent_id: int, goal: CollectiveGoal) -> bool:
	# Simplified support calculation
	# In full implementation, would check agent's personality, current needs, etc.
	return randf() < 0.6

# === Cultural Evolution ===

func evolve_culture() -> void:
	# Cultural norms evolve based on experiences and population
	_update_norm_adherence()
	_develop_new_norms()
	_advance_technology()
	_update_government_type()

func _update_norm_adherence() -> void:
	for norm in cultural_norms:
		# Adherence changes based on population size and recent events
		var base_adherence: float = 0.5
		var population_factor: float = float(population) / 100.0
		norm.adherence_level = clamp(base_adherence + population_factor * 0.1, 0.0, 1.0)

func _develop_new_norms() -> void:
	# New norms emerge as settlement grows
	if population > 20 and cultural_norms.size() < 5:
		var new_norms = [
			"Trade fairly with outsiders",
			"Honor agreements with other settlements",
			"Preserve knowledge through teaching",
			"Respect property rights"
		]
		
		var norm_name: String = new_norms[randi() % new_norms.size()]
		var norm: CulturalNorm = CulturalNorm.new(norm_name, "Emergent cultural practice")
		cultural_norms.append(norm)

func _advance_technology() -> void:
	# Technology advances based on population and focus
	var tech_progress: float = 0.0
	
	match development_focus:
		DevelopmentFocus.KNOWLEDGE:
			tech_progress = 0.2
		DevelopmentFocus.TRADE:
			tech_progress = 0.15
		DevelopmentFocus.BALANCED:
			tech_progress = 0.1
		_:
			tech_progress = 0.05
	
	technological_level = min(100, technological_level + tech_progress)

func _update_government_type() -> void:
	# Government evolves with population and complexity
	var previous_government: int = government_type
	
	if population > 30 and government_type == GovernmentType.TRIBAL:
		government_type = GovernmentType.CHIEFDOM
		historical_events.append("Government evolved from %s to %s" % [GovernmentType.keys()[previous_government], GovernmentType.keys()[government_type]])
	elif population > 60 and government_type == GovernmentType.CHIEFDOM:
		previous_government = government_type
		government_type = GovernmentType.MONARCHY
		historical_events.append("Government evolved from %s to %s" % [GovernmentType.keys()[previous_government], GovernmentType.keys()[government_type]])
	elif population > 120 and government_type == GovernmentType.MONARCHY:
		previous_government = government_type
		government_type = GovernmentType.REPUBLIC
		historical_events.append("Government evolved from %s to %s" % [GovernmentType.keys()[previous_government], GovernmentType.keys()[government_type]])

# === Economic Management ===

func manage_economy() -> void:
	# Update production and consumption
	resource_management.update_production()
	resource_management.update_consumption()
	
	# Adjust production based on goals
	for goal in collective_goals:
		_adjust_production_for_goal(goal)
	
	# Consider trade opportunities
	_explore_trade_opportunities()

func _adjust_production_for_goal(goal: CollectiveGoal) -> void:
	match goal.goal_type:
		"gather_food":
			resource_management.production_rates["food"] = resource_management.production_rates.get("food", 0.0) + 1.0
		"build_shelter":
			resource_management.production_rates["wood"] = resource_management.production_rates.get("wood", 0.0) + 0.5
		"research_technology":
			resource_management.production_rates["knowledge"] = resource_management.production_rates.get("knowledge", 0.0) + 0.3

func _explore_trade_opportunities() -> void:
	# Look for trade partners based on resource needs and surpluses
	for partner_id in resource_management.trade_partners:
		_negotiate_trade(partner_id)

func _negotiate_trade(partner_id: int) -> void:
	# Simplified trade negotiation
	# In full implementation, would exchange actual resources
	var relationship: float = diplomatic_relations.get(partner_id, 0.0)
	if relationship > 0.3:
		historical_events.append("Trade agreement with settlement %d" % partner_id)

# === Diplomatic Relations ===

func establish_diplomatic_relation(other_settlement_id: int, initial_relationship: float = 0.0) -> void:
	diplomatic_relations[other_settlement_id] = initial_relationship
	
	if initial_relationship > 0.5:
		resource_management.trade_partners.append(other_settlement_id)
		historical_events.append("Established friendly relations with settlement %d" % other_settlement_id)
	elif initial_relationship < -0.5:
		historical_events.append("Hostile relations with settlement %d" % other_settlement_id)

func update_diplomatic_relations(event: String, other_settlement_id: int, impact: float) -> void:
	var current_relation: float = diplomatic_relations.get(other_settlement_id, 0.0)
	var new_relation: float = clamp(current_relation + impact, -1.0, 1.0)
	diplomatic_relations[other_settlement_id] = new_relation
	
	# Update trade relationship
	if new_relation > 0.3 and not resource_management.trade_partners.has(other_settlement_id):
		resource_management.trade_partners.append(other_settlement_id)
	elif new_relation < -0.3 and resource_management.trade_partners.has(other_settlement_id):
		resource_management.trade_partners.erase(other_settlement_id)

# === Main Update Loop ===

func _update_collective_goals() -> void:
	# Process collective goals and remove completed ones
	var completed_goals: Array[int] = []
	
	for i in range(collective_goals.size()):
		var goal: CollectiveGoal = collective_goals[i]
		goal.progress += 0.01  # Simple progress simulation
		
		if goal.progress >= 1.0:
			completed_goals.append(i)
			historical_events.append("Completed collective goal: %s" % goal.goal_type)
	
	# Remove completed goals (in reverse order)
	for i in range(completed_goals.size() - 1, -1, -1):
		collective_goals.remove_at(completed_goals[i])

func update() -> void:
	evolve_culture()
	manage_economy()
	_process_collective_goals()
	_update_leadership()
	_propose_automatic_goals()

func _process_collective_goals() -> void:
	var completed_goals: Array[int] = []
	
	for i in range(collective_goals.size()):
		var goal: CollectiveGoal = collective_goals[i]
		goal.progress += 1.0 / float(goal.expected_duration)
		
		if goal.progress >= 1.0:
			completed_goals.append(i)
			historical_events.append("Completed collective goal: %s" % goal.goal_type)
			
			# AuthoritySystem: grant authority to leader for organizing collective effort
			if AuthoritySystem != null and leader_id >= 0:
				AuthoritySystem.record_organization_action(leader_id, goal.supporters)
	
	# Remove completed goals (in reverse order)
	for i in range(completed_goals.size() - 1, -1, -1):
		collective_goals.remove_at(completed_goals[i])

func _propose_automatic_goals() -> void:
	# Automatically propose goals based on settlement needs
	if collective_goals.size() >= 5:
		return  # Limit active goals
	
	var food_stock = resource_management.stockpiles.get("food", 0.0)
	var wood_stock = resource_management.stockpiles.get("wood", 0.0)
	
	# Propose food gathering if low
	if food_stock < 10.0 and population > 5:
		propose_collective_goal("gather_food", leader_id if leader_id >= 0 else resident_agents[0], 80)
	
	# Propose shelter building if population growing
	if population > 10 and wood_stock > 5.0:
		propose_collective_goal("build_shelter", leader_id if leader_id >= 0 else resident_agents[0], 70)
	
	# Propose research if knowledge-focused
	if development_focus == DevelopmentFocus.KNOWLEDGE and population > 15:
		propose_collective_goal("research_technology", leader_id if leader_id >= 0 else resident_agents[0], 60)

# === Public Interface ===

func get_settlement_status() -> Dictionary:
	return {
		"name": settlement_name,
		"population": population,
		"government": GovernmentType.keys()[government_type],
		"focus": DevelopmentFocus.keys()[development_focus],
		"technological_level": technological_level,
		"active_goals": collective_goals.size(),
		"cultural_norms": cultural_norms.size(),
		"trade_partners": resource_management.trade_partners.size()
	}

func get_detailed_status() -> Dictionary:
	return {
		"settlement_id": settlement_id,
		"location": location,
		"population": population,
		"residents": resident_agents,
		"government_type": government_type,
		"leader_id": leader_id,
		"development_focus": development_focus,
		"collective_goals": _get_goals_summary(),
		"cultural_norms": _get_norms_summary(),
		"resources": resource_management.stockpiles,
		"diplomatic_relations": diplomatic_relations,
		"historical_events": historical_events,
		"technological_level": technological_level
	}

func _get_goals_summary() -> Array:
	var summary: Array = []
	for goal in collective_goals:
		summary.append({
			"type": goal.goal_type,
			"priority": goal.priority,
			"progress": goal.progress,
			"supporters": goal.supporters.size()
		})
	return summary

func _get_norms_summary() -> Array:
	var summary: Array = []
	for norm in cultural_norms:
		summary.append({
			"name": norm.norm_name,
			"adherence": norm.adherence_level,
			"description": norm.description
		})
	return summary

func can_accept_new_residents() -> bool:
	return population < 200  # Increased population limit

func get_cultural_influence() -> float:
	var influence: float = 0.0
	influence += float(population) * 0.1
	influence += float(technological_level) * 0.2
	influence += float(cultural_norms.size()) * 0.5
	influence += float(diplomatic_relations.size()) * 0.3
	return influence
