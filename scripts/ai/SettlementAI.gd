extends RefCounted
class_name SettlementAI
## Community-level AI for managing collective decision-making, cultural evolution, and settlement development

const _WM = preload("res://autoloads/WorldMemory.gd")

## Safe leader or first resident, or -1 if no residents
func _leader_or_first_resident() -> int:
	if leader_id >= 0:
		return leader_id
	if not resident_agents.is_empty():
		return resident_agents[0]
	return -1

## Safe enum key name lookup — returns "UNKNOWN" if out of range
static func _safe_enum_name(keys: Array, value: int) -> String:
	if value >= 0 and value < keys.size():
		return keys[value]
	return "UNKNOWN"

# Autoload references (accessed via Engine.get_singleton or get_node)
var CollapseSystem = null
var AuthoritySystem = null
var WorldAI = null
var GameManager = null
var TechnologySystem = null
var KnowledgeSystem = null

func _autoload_or_null(path: String) -> Node:
	var main_loop: MainLoop = Engine.get_main_loop()
	if main_loop == null or not (main_loop is SceneTree):
		return null
	var tree: SceneTree = main_loop as SceneTree
	var root: Node = tree.get_root()
	if root == null:
		return null
	return root.get_node_or_null(path)


func _resolve_autoload_refs() -> void:
	CollapseSystem = _autoload_or_null("/root/CollapseSystem")
	AuthoritySystem = _autoload_or_null("/root/AuthoritySystem")
	WorldAI = _autoload_or_null("/root/WorldAI")
	GameManager = _autoload_or_null("/root/GameManager")
	TechnologySystem = _autoload_or_null("/root/TechnologySystem")
	KnowledgeSystem = _autoload_or_null("/root/KnowledgeSystem")

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
var previous_development_focus: DevelopmentFocus = DevelopmentFocus.SURVIVAL
var collective_goals: Array[CollectiveGoal] = []
var cultural_norms: Array[CulturalNorm] = []
var resource_management: ResourceManagement
var diplomatic_relations: Dictionary = {}  # settlement_id -> relationship_score
var historical_events: Array[String] = []

# Emergency state
var emergency_mode: bool = false
var emergency_reason: String = ""

# Diplomatic state
var active_treaties: Array[Dictionary] = []  # treaty_id -> treaty data
var treaty_proposals: Array[Dictionary] = []

# Religious state
var sacred_sites: Array[Vector2i] = []  # Locations of sacred sites
var ritual_complexity: float = 0.0  # Complexity of religious rituals
var religious_fervor: float = 0.0  # Overall religious fervor

# Cultural properties
var dominant_culture: String = ""
var language_family: String = ""
var religious_beliefs: Array[String] = []
var artistic_traditions: Array[String] = []

func _settlement_stream(label: String) -> StringName:
	return StringName("settlement_ai:%d:%s" % [settlement_id, label])

func _settlement_salt(extra: int = 0) -> int:
	var tick: int = GameManager.tick_count if GameManager != null else 0
	return tick + settlement_id * 1009 + extra

func _pick_resident(label: String, extra: int = 0) -> int:
	if resident_agents.is_empty():
		return -1
	var ordered = resident_agents.duplicate()
	ordered.sort()
	var idx := WorldRNG.index_for(_settlement_stream(label), ordered.size(), _settlement_salt(extra))
	if idx < 0 or idx >= ordered.size():
		return -1
	return ordered[idx]
var technological_level: int = 0  # 0-100

# Leadership properties
var leader_id: int = -1
var council_members: Array[int] = []
var decision_making_process: String = "consensus"
var leadership_approval: float = 0.5  # 0.0-1.0

func _init(id: int, name: String, pos: Vector2i):
	_resolve_autoload_refs()
	settlement_id = id
	settlement_name = name
	location = pos
	resource_management = ResourceManagement.new()
	_initialize_cultural_norms()
	
	# CollapseSystem: initialize collapse metrics for this settlement
	if CollapseSystem != null:
		CollapseSystem.initialize_settlement_metrics(settlement_id)

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
		
		# CollapseSystem: population growth improves stability
		if CollapseSystem != null:
			CollapseSystem.update_trust_level(settlement_id, 0.02)

func remove_resident(agent_id: int) -> void:
	if resident_agents.has(agent_id):
		resident_agents.erase(agent_id)
		population -= 1
		_update_leadership()
		
		# CollapseSystem: population loss hurts stability
		if CollapseSystem != null:
			CollapseSystem.update_trust_level(settlement_id, -0.05)
			CollapseSystem.update_authority_stability(settlement_id, -0.03)

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
	if resident_agents.size() == 0:
		leader_id = -1
		return
	leader_id = resident_agents[0]  # First agent as elder
	decision_making_process = "consensus"
	
	# AuthoritySystem: grant civil authority to elder
	if AuthoritySystem != null and leader_id >= 0:
		AuthoritySystem.record_elder_recognition(leader_id)

func _chieftain_selection() -> void:
	# Hereditary or strongest warrior
	leader_id = _pick_resident("chieftain_selection", 1)
	decision_making_process = "authoritarian"
	
	# AuthoritySystem: grant military authority to chief
	if AuthoritySystem != null and leader_id >= 0:
		AuthoritySystem.grant_authority(leader_id, AuthoritySystem.AuthorityContext.MILITARY, 0.3, "chieftain_selection")

func _monarch_selection() -> void:
	# Similar to chief but with more formal structure
	leader_id = _pick_resident("monarch_selection", 2)
	decision_making_process = "decrees"
	
	# AuthoritySystem: grant civil authority to monarch
	if AuthoritySystem != null and leader_id >= 0:
		AuthoritySystem.grant_authority(leader_id, AuthoritySystem.AuthorityContext.CIVIL, 0.4, "monarch_selection")

func _republic_election() -> void:
	# Most respected agent
	leader_id = _pick_resident("republic_election", 3)
	decision_making_process = "voting"
	
	# AuthoritySystem: grant civil authority through election
	if AuthoritySystem != null and leader_id >= 0:
		AuthoritySystem.grant_authority(leader_id, AuthoritySystem.AuthorityContext.CIVIL, 0.35, "republic_election")

func _theocratic_selection() -> void:
	# Most spiritually-influential agent
	leader_id = _pick_resident("theocratic_selection", 4)
	decision_making_process = "divine_guidance"
	
	# AuthoritySystem: grant religious authority
	if AuthoritySystem != null and leader_id >= 0:
		AuthoritySystem.grant_authority(leader_id, AuthoritySystem.AuthorityContext.RELIGIOUS, 0.4, "theocratic_selection")

func _technocratic_selection() -> void:
	# Most skilled/knowledgeable agent
	leader_id = _pick_resident("technocratic_selection", 5)
	decision_making_process = "expert_consensus"
	
	# AuthoritySystem: grant knowledge authority
	if AuthoritySystem != null and leader_id >= 0:
		AuthoritySystem.grant_authority(leader_id, AuthoritySystem.AuthorityContext.KNOWLEDGE, 0.35, "technocratic_selection")

# === Collective Decision Making ===

func propose_collective_goal(goal_type: String, proposer_id: int, base_priority: int) -> bool:
	# Propose a collective goal with neural network-influenced priority
	var neural_priority_modifier = _get_neural_priority_modifier(goal_type)
	var adjusted_priority = base_priority + neural_priority_modifier
	
	var goal = CollectiveGoal.new(goal_type, adjusted_priority)
	goal.supporters.append(proposer_id)
	
	# Check if goal aligns with development focus
	if not _goal_aligns_with_focus(goal_type):
		return false
	
	# Apply WorldAI settlement goal priority weight
	if WorldAI != null and WorldAI.has_method("get_settlement_goal_priority"):
		var goal_weight: float = WorldAI.get_settlement_goal_priority(goal_type)
		adjusted_priority = int(adjusted_priority * (1.0 + goal_weight))
		goal.priority = adjusted_priority
	
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
	if resident_agents.is_empty():
		return false
	if float(current_support) / float(resident_agents.size()) >= support_threshold:
		collective_goals.append(goal)
		historical_events.append("Collective goal approved: %s (priority: %d, neural modifier: %d)" % [goal_type, adjusted_priority, neural_priority_modifier])
		return true
	
	return false


func _get_neural_priority_modifier(goal_type: String) -> int:
	# Get priority modifier based on neural network state
	if WorldAI == null or not WorldAI.has_method("get_neural_network_summary"):
		return 0
	
	var summary = WorldAI.get_neural_network_summary()
	var modifier: int = 0
	
	match goal_type:
		"resource_conservation":
			# Higher priority when resource depletion is high
			var resource_depletion = summary.get("resource_depletion", 0.0)
			modifier = int(resource_depletion * 20)
		"infrastructure_investment":
			# Higher priority when economic stability is high
			var econ_stability = summary.get("economic_stability", 0.0)
			modifier = int(econ_stability * 15)
		"economic_recovery":
			# Higher priority when economic stability is low
			var econ_stability = summary.get("economic_stability", 0.0)
			modifier = int((1.0 - econ_stability) * 25)
		"religious_unity":
			# Higher priority when religious fervor is high
			var religious_fervor = summary.get("religious_fervor", 0.0)
			modifier = int(religious_fervor * 15)
		"religious_integration":
			# Higher priority when religious influence is high
			var religious_influence = summary.get("religious_influence", 0.0)
			modifier = int(religious_influence * 12)
		"preserve_knowledge":
			# Higher priority when knowledge scarcity is high
			var knowledge_scarcity = summary.get("knowledge_scarcity", 0.0)
			modifier = int(knowledge_scarcity * 20)
		"build_monument":
			# Higher priority when cultural advancement is high
			var teaching_activity = summary.get("teaching_activity", 0.0)
			modifier = int(teaching_activity * 10)
		_:
			modifier = 0
	
	return clamp(modifier, -10, 30)

func _goal_aligns_with_focus(goal_type: String) -> bool:
	var base_alignment: bool = false
	
	match development_focus:
		DevelopmentFocus.SURVIVAL:
			base_alignment = goal_type in ["gather_food", "build_shelter", "defend_settlement"]
		DevelopmentFocus.EXPANSION:
			base_alignment = goal_type in ["explore_territory", "found_colony", "build_road"]
		DevelopmentFocus.TRADE:
			base_alignment = goal_type in ["establish_trade_route", "build_market", "produce_goods"]
		DevelopmentFocus.KNOWLEDGE:
			base_alignment = goal_type in ["build_library", "research_technology", "preserve_knowledge"]
		DevelopmentFocus.MILITARY:
			base_alignment = goal_type in ["train_warriors", "build_fortifications", "conquer_territory"]
		DevelopmentFocus.ARTISTIC:
			base_alignment = goal_type in ["create_art", "hold_festival", "build_monument"]
		DevelopmentFocus.BALANCED:
			base_alignment = true  # Accept all goals
		_:
			base_alignment = false
	
	# Apply WorldAI expansion priority for expansion-related goals
	if base_alignment and goal_type in ["explore_territory", "found_colony", "build_road"]:
		if WorldAI != null and WorldAI.has_method("get_expansion_priority_weight"):
			var expansion_weight: float = WorldAI.get_expansion_priority_weight(goal_type)
			# If expansion priority is low, require higher base alignment
			if expansion_weight < 0.3:
				return development_focus == DevelopmentFocus.EXPANSION
	
	return base_alignment

# === Emergency Response ===

func check_emergency_status() -> void:
	if WorldAI == null or not WorldAI.has_method("get_neural_network_summary"):
		return
	
	# Check collapse risk from WorldAI
	var world_neurons = WorldAI.neural_world_matrix.get("world_state_neurons", {})
	var collapse_risk = world_neurons.get("collapse_risk", {}).get("value", 0.0)
	
	# Trigger emergency mode if collapse risk is high
	if collapse_risk > 0.7 and not emergency_mode:
		enter_emergency_mode("high_collapse_risk")
	elif collapse_risk < 0.4 and emergency_mode:
		exit_emergency_mode("collapse_risk_lowered")


func enter_emergency_mode(reason: String) -> void:
	emergency_mode = true
	emergency_reason = reason
	
	# Save previous development focus
	previous_development_focus = development_focus
	
	# Prioritize survival goals
	development_focus = DevelopmentFocus.SURVIVAL
	
	# Cancel non-essential goals
	var essential_goals = ["gather_food", "build_shelter", "defend_settlement"]
	var i = collective_goals.size() - 1
	while i >= 0:
		if collective_goals[i].goal_type not in essential_goals:
			collective_goals.remove_at(i)
		i -= 1
	
	# Propose emergency goals
	propose_collective_goal("gather_food", _leader_or_first_resident(), 95)
	propose_collective_goal("defend_settlement", _leader_or_first_resident(), 90)
	
	historical_events.append("Emergency mode activated: %s" % reason)


func exit_emergency_mode(reason: String) -> void:
	emergency_mode = false
	emergency_reason = ""
	
	# Restore previous development focus
	development_focus = previous_development_focus
	
	historical_events.append("Emergency mode deactivated: %s" % reason)


# === WorldAI Event Handlers ===

func handle_collapse_warning_event(event_data: Dictionary) -> void:
	# Respond to collapse warning from WorldAI
	var collapse_risk = event_data.get("collapse_risk", 0.0)
	var trust_level = event_data.get("trust_level", 0.0)
	
	# Enter emergency mode if not already
	if not emergency_mode:
		enter_emergency_mode("world_collapse_warning")
	
	# Propose defensive goals
	propose_collective_goal("defend_settlement", _leader_or_first_resident(), 90)
	propose_collective_goal("gather_food", _leader_or_first_resident(), 85)
	
	historical_events.append("Responded to collapse warning: risk=%.2f, trust=%.2f" % [collapse_risk, trust_level])


func handle_knowledge_crisis_event(event_data: Dictionary) -> void:
	# Respond to knowledge crisis from WorldAI
	var knowledge_scarcity = event_data.get("knowledge_scarcity", 0.0)
	var teaching_activity = event_data.get("teaching_activity", 0.0)
	
	# Prioritize knowledge preservation
	if development_focus != DevelopmentFocus.KNOWLEDGE:
		previous_development_focus = development_focus
		development_focus = DevelopmentFocus.KNOWLEDGE
	
	# Propose knowledge goals
	propose_collective_goal("preserve_knowledge", _leader_or_first_resident(), 80)
	propose_collective_goal("build_library", _leader_or_first_resident(), 75)
	
	historical_events.append("Responded to knowledge crisis: scarcity=%.2f, teaching=%.2f" % [knowledge_scarcity, teaching_activity])


func handle_authority_vacuum_event(event_data: Dictionary) -> void:
	# Respond to authority vacuum from WorldAI
	var civil_auth = event_data.get("civil_authority", 0.0)
	var military_auth = event_data.get("military_authority", 0.0)
	
	# Trigger leadership selection to fill vacuum
	if AuthoritySystem != null:
		_trigger_emergency_leadership_selection()
	
	# Propose stability goals
	propose_collective_goal("defend_settlement", _leader_or_first_resident(), 85)
	
	historical_events.append("Responded to authority vacuum: civil=%.2f, military=%.2f" % [civil_auth, military_auth])


func handle_historical_discovery_event(event_data: Dictionary) -> void:
	# Respond to historical discovery from WorldAI
	var historical_layering = event_data.get("historical_layering", 0.0)
	var ruin_density = event_data.get("ruin_density", 0.0)
	
	# Propose memorial or exploration goals
	if development_focus == DevelopmentFocus.ARTISTIC:
		propose_collective_goal("build_monument", _leader_or_first_resident(), 70)
	elif development_focus == DevelopmentFocus.KNOWLEDGE:
		propose_collective_goal("preserve_knowledge", _leader_or_first_resident(), 70)
	else:
		propose_collective_goal("explore_territory", _leader_or_first_resident(), 65)
	
	historical_events.append("Responded to historical discovery: layering=%.2f, ruins=%.2f" % [historical_layering, ruin_density])


func handle_environmental_degradation_event(event_data: Dictionary) -> void:
	# Respond to environmental degradation by prioritizing survival
	emergency_mode = true
	emergency_reason = "environmental_degradation"
	
	# Shift development focus to survival
	previous_development_focus = development_focus
	development_focus = DevelopmentFocus.SURVIVAL
	
	# Propose resource conservation goals
	var proposer_env: int = _leader_or_first_resident()
	if proposer_env >= 0:
		propose_collective_goal("resource_conservation", proposer_env, 90)
	
	historical_events.append("Environmental degradation detected - shifted to survival focus")


func handle_economic_boom_event(event_data: Dictionary) -> void:
	# Respond to economic boom by expanding and investing
	var production_eff = event_data.get("production_efficiency", 0.0)
	var econ_stability = event_data.get("economic_stability", 0.0)
	
	# Shift development focus to expansion if not in emergency
	if not emergency_mode:
		development_focus = DevelopmentFocus.EXPANSION
	
	# Propose investment goals
	var proposer_boom: int = _leader_or_first_resident()
	if proposer_boom >= 0:
		propose_collective_goal("infrastructure_investment", proposer_boom, 80)
	
	historical_events.append("Economic boom detected - expanding and investing")


func handle_market_crash_event(event_data: Dictionary) -> void:
	# Respond to market crash by entering emergency mode
	emergency_mode = true
	emergency_reason = "market_crash"
	
	# Shift development focus to survival
	previous_development_focus = development_focus
	development_focus = DevelopmentFocus.SURVIVAL
	
	# Propose economic recovery goals
	var proposer_crash: int = _leader_or_first_resident()
	if proposer_crash >= 0:
		propose_collective_goal("economic_recovery", proposer_crash, 90)
	
	historical_events.append("Market crash detected - entered emergency mode")


func handle_religious_schism_event(event_data: Dictionary) -> void:
	# Respond to religious schism by addressing division
	var belief_diversity = event_data.get("belief_diversity", 0.0)
	var religious_fervor = event_data.get("religious_fervor", 0.0)
	
	# Propose unity goals
	var proposer_schism: int = _leader_or_first_resident()
	if proposer_schism >= 0:
		propose_collective_goal("religious_unity", proposer_schism, 80)
	
	# Reduce religious fervor to lower tension
	religious_fervor = max(religious_fervor - 0.1, 0.0)
	
	historical_events.append("Religious schism detected - promoting unity")


func handle_religious_conversion_event(event_data: Dictionary) -> void:
	# Respond to religious conversion by welcoming new believers
	var religious_influence = event_data.get("religious_influence", 0.0)
	var ritual_complexity = event_data.get("ritual_complexity", 0.0)
	
	# Increase religious fervor
	religious_fervor = min(religious_fervor + 0.05, 1.0)
	
	# Propose integration goals
	var proposer_convert: int = _leader_or_first_resident()
	if proposer_convert >= 0:
		propose_collective_goal("religious_integration", proposer_convert, 70)
	
	historical_events.append("Religious conversion detected - welcoming new believers")


func _trigger_emergency_leadership_selection() -> void:
	# Select new leader based on government type
	match government_type:
		GovernmentType.MONARCHY:
			_monarch_selection()
		GovernmentType.THEOCRACY:
			_theocratic_selection()
		GovernmentType.TECHNOCRACY:
			_technocratic_selection()
		_:
			_tribal_leadership_selection()


# === Peace Treaty Negotiation ===

func propose_peace_treaty(target_settlement_id: int, terms: Dictionary) -> bool:
	# Propose peace treaty to another settlement
	if target_settlement_id == settlement_id:
		return false
	
	var proposal = {
		"proposer_id": settlement_id,
		"target_id": target_settlement_id,
		"terms": terms,
		"tick": GameManager.tick_count if GameManager else 0,
		"status": "pending"
	}
	
	treaty_proposals.append(proposal)
	historical_events.append("Peace treaty proposed to settlement %d" % target_settlement_id)
	
	return true


func accept_peace_treaty(proposal_index: int) -> bool:
	if proposal_index < 0 or proposal_index >= treaty_proposals.size():
		return false
	
	var proposal = treaty_proposals[proposal_index]
	if proposal.get("target_id") != settlement_id:
		return false
	
	# Create active treaty
	var treaty = {
		"treaty_id": GameManager.tick_count if GameManager else 0,
		"parties": [proposal["proposer_id"], proposal["target_id"]],
		"terms": proposal["terms"],
		"start_tick": GameManager.tick_count if GameManager else 0,
		"duration": proposal["terms"].get("duration", 5000),
		"status": "active"
	}
	
	active_treaties.append(treaty)
	treaty_proposals.remove_at(proposal_index)
	
	# Improve diplomatic relations
	var other_settlement = proposal["proposer_id"]
	diplomatic_relations[other_settlement] = diplomatic_relations.get(other_settlement, 0.0) + 0.3
	
	historical_events.append("Peace treaty accepted with settlement %d" % other_settlement)
	return true


func reject_peace_treaty(proposal_index: int) -> bool:
	if proposal_index < 0 or proposal_index >= treaty_proposals.size():
		return false
	
	var proposal = treaty_proposals[proposal_index]
	if proposal.get("target_id") != settlement_id:
		return false
	
	treaty_proposals.remove_at(proposal_index)
	
	# Worsen diplomatic relations
	var other_settlement = proposal["proposer_id"]
	diplomatic_relations[other_settlement] = diplomatic_relations.get(other_settlement, 0.0) - 0.1
	
	historical_events.append("Peace treaty rejected from settlement %d" % other_settlement)
	return true


func check_treaty_expiry() -> void:
	var current_tick = GameManager.tick_count if GameManager else 0
	var i = active_treaties.size() - 1
	
	while i >= 0:
		var treaty = active_treaties[i]
		var age = current_tick - treaty.get("start_tick", 0)
		
		if age >= treaty.get("duration", 5000):
			# Treaty expired
			active_treaties.remove_at(i)
			var parties = treaty.get("parties", [])
			if parties.size() >= 2:
				var other_id = parties[0] if parties[0] != settlement_id else parties[1]
				historical_events.append("Peace treaty with settlement %d expired" % other_id)
		
		i -= 1


func evaluate_peace_proposal(target_settlement_id: int) -> float:
	# Evaluate whether to accept a peace proposal (0.0-1.0)
	var relationship = diplomatic_relations.get(target_settlement_id, 0.0)
	var military_strength = population * 0.1  # Simple proxy
	
	# Higher relationship = more likely to accept
	var acceptance_chance = relationship * 0.5 + 0.3
	
	# If in emergency mode, more likely to accept peace
	if emergency_mode:
		acceptance_chance += 0.2
	
	return clamp(acceptance_chance, 0.0, 1.0)


# === Religious Management ===

func establish_sacred_site(location: Vector2i) -> bool:
	# Establish a sacred site at the given location
	if location in sacred_sites:
		return false
	
	sacred_sites.append(location)
	ritual_complexity = min(ritual_complexity + 0.1, 1.0)
	religious_fervor = min(religious_fervor + 0.05, 1.0)
	
	# Notify WorldAI
	if WorldAI != null and WorldAI.has_method("on_sacred_site_established"):
		WorldAI.on_sacred_site_established(settlement_id, location)
	
	historical_events.append("Sacred site established at %s" % str(location))
	return true


func perform_ritual(ritual_type: String, participants: int) -> void:
	# Perform a religious ritual
	var fervor_increase = min(participants * 0.01, 0.1)
	religious_fervor = min(religious_fervor + fervor_increase, 1.0)
	
	# Increase ritual complexity based on participant count
	if participants > 5:
		ritual_complexity = min(ritual_complexity + 0.02, 1.0)
	
	# Notify WorldAI
	if WorldAI != null and WorldAI.has_method("on_ritual_performed"):
		WorldAI.on_ritual_performed(settlement_id, ritual_type, participants)
	
	historical_events.append("Ritual %s performed with %d participants" % [ritual_type, participants])


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
	return WorldRNG.chance_for(
		_settlement_stream("goal_support:%s" % goal.goal_type),
		0.6,
		_settlement_salt(agent_id * 17 + goal.priority * 31)
	)

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
		
		var available_norms: Array[String] = []
		for candidate_norm in new_norms:
			if not _has_cultural_norm(candidate_norm):
				available_norms.append(candidate_norm)
		if available_norms.is_empty():
			return
		var norm_idx := WorldRNG.index_for(
			_settlement_stream("new_norm"),
			available_norms.size(),
			_settlement_salt(cultural_norms.size() * 43)
		)
		if norm_idx < 0 or norm_idx >= available_norms.size():
			return
		var norm_name: String = available_norms[norm_idx]
		var norm: CulturalNorm = CulturalNorm.new(norm_name, "Emergent cultural practice")
		cultural_norms.append(norm)

func _has_cultural_norm(norm_name: String) -> bool:
	for norm in cultural_norms:
		if norm != null and norm.norm_name == norm_name:
			return true
	return false

func _advance_technology() -> void:
	# Keep legacy tech-level drift so older systems remain stable.
	var tech_progress: float = 0.05
	match development_focus:
		DevelopmentFocus.KNOWLEDGE:
			tech_progress = 0.2
		DevelopmentFocus.TRADE:
			tech_progress = 0.15
		DevelopmentFocus.BALANCED:
			tech_progress = 0.1
	technological_level = min(100, technological_level + tech_progress)
	# Deterministic backend research hook: choose cheapest available tech when points allow.
	if TechnologySystem == null or KnowledgeSystem == null:
		return
	if not TechnologySystem.has_method("get_active_research"):
		return
	var active_id: String = str(TechnologySystem.call("get_active_research", settlement_id))
	if not active_id.is_empty():
		return
	var researchable: Array = []
	if KnowledgeSystem.has_method("get_researchable_techs"):
		researchable = KnowledgeSystem.call("get_researchable_techs", settlement_id)
	if researchable.is_empty():
		return
	var preferred_branch: String = ""
	if CulturalMemory != null and CulturalMemory.has_method("get_tradition"):
		var trad_v: Variant = CulturalMemory.call("get_tradition", settlement_id)
		if trad_v is Dictionary:
			preferred_branch = str((trad_v as Dictionary).get("preferred_tech_branch", "")).to_lower()
	var best: String = ""
	var best_score: int = -1_000_000
	for tech_any in researchable:
		var tech_id: String = str(tech_any)
		if not TechnologySystem.TECH_TREE.has(tech_id):
			continue
		var node: Dictionary = TechnologySystem.TECH_TREE[tech_id] as Dictionary
		var cost: int = int(node.get("cost", 0))
		var score: int = -cost
		if not preferred_branch.is_empty():
			var tech_lc: String = tech_id.to_lower()
			var effect_lc: String = str(node.get("effect", "")).to_lower()
			if tech_lc.find(preferred_branch) >= 0 or effect_lc.find(preferred_branch) >= 0:
				score += 1000
		if score > best_score or (score == best_score and tech_id < best):
			best_score = score
			best = tech_id
	if best.is_empty():
		return
	TechnologySystem.call("set_active_research", settlement_id, best)
	var researched: bool = bool(TechnologySystem.call("research_tech", best, settlement_id))
	if researched:
		historical_events.append("Researched technology: %s" % best)

func _update_government_type() -> void:
	# Government evolves with population and complexity
	var previous_government: int = government_type
	
	if population > 30 and government_type == GovernmentType.TRIBAL:
		government_type = GovernmentType.CHIEFDOM
		historical_events.append("Government evolved from %s to %s" % [_safe_enum_name(GovernmentType.keys(), previous_government), _safe_enum_name(GovernmentType.keys(), government_type)])
	elif population > 60 and government_type == GovernmentType.CHIEFDOM:
		previous_government = government_type
		government_type = GovernmentType.MONARCHY
		historical_events.append("Government evolved from %s to %s" % [_safe_enum_name(GovernmentType.keys(), previous_government), _safe_enum_name(GovernmentType.keys(), government_type)])
	elif population > 120 and government_type == GovernmentType.MONARCHY:
		previous_government = government_type
		government_type = GovernmentType.REPUBLIC
		historical_events.append("Government evolved from %s to %s" % [_safe_enum_name(GovernmentType.keys(), previous_government), _safe_enum_name(GovernmentType.keys(), government_type)])

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

## Called by TickManager via AIAgentManager forwarding
func _on_world_tick(tick_number: int) -> void:
	# Throttle: settlement AI doesn't need to run every tick.
	# Culture/economy/goals evolve on longer timescales.
	if tick_number % 10 != 0:
		return
	update()

func _process_collective_goals() -> void:
	var completed_goals: Array[int] = []
	
	for i in range(collective_goals.size()):
		var goal: CollectiveGoal = collective_goals[i]
		if goal.expected_duration <= 0:
			continue
		goal.progress += 1.0 / float(goal.expected_duration)
		
		if goal.progress >= 1.0:
			completed_goals.append(i)
			historical_events.append("Completed collective goal: %s" % goal.goal_type)
			
			# AuthoritySystem: grant authority to leader for organizing collective effort
			if AuthoritySystem != null and leader_id >= 0:
				AuthoritySystem.record_organization_action(leader_id, goal.supporters)
			
			# CollapseSystem: successful collective goal improves stability
			if CollapseSystem != null:
				CollapseSystem.update_trust_level(settlement_id, 0.05)
				CollapseSystem.update_authority_stability(settlement_id, 0.03)
	
	# Remove completed goals (in reverse order)
	for i in range(completed_goals.size() - 1, -1, -1):
		collective_goals.remove_at(completed_goals[i])

func _propose_automatic_goals() -> void:
	# Automatically propose goals based on settlement needs
	if collective_goals.size() >= 5:
		return  # Limit active goals
	
	var food_stock = resource_management.stockpiles.get("food", 0.0)
	var wood_stock = resource_management.stockpiles.get("wood", 0.0)
	
	# WorldMeaning: get region meaning to influence goal priorities
	var region_meaning: Dictionary = {}
	if WorldMeaning != null:
		var rk: int = _WM._region_key(location.x, location.y)
		region_meaning = WorldMeaning.get_region_meaning(rk)
	
	var death_density: String = region_meaning.get("death_density", "none")
	var meaning_label: String = region_meaning.get("meaning_label", "quiet")
	
	# Propose food gathering if low
	if food_stock < 10.0 and population > 5:
		var priority: int = 80
		# Higher priority in scarred regions (survival focus)
		if death_density in ["medium", "high"]:
			priority = 90
		propose_collective_goal("gather_food", _leader_or_first_resident(), priority)
	
	# Propose shelter building if population growing
	if population > 10 and wood_stock > 5.0:
		var priority: int = 70
		# Higher priority in grave regions (need protection)
		if meaning_label == "grave":
			priority = 85
		propose_collective_goal("build_shelter", _leader_or_first_resident(), priority)
	
	# Propose research if knowledge-focused
	if development_focus == DevelopmentFocus.KNOWLEDGE and population > 15:
		var priority: int = 60
		# Higher priority in quiet regions (stable for learning)
		if meaning_label == "quiet":
			priority = 75
		
		# Apply WorldAI teaching priority weight
		if WorldAI != null and WorldAI.has_method("get_teaching_priority_weight"):
			var teaching_weight: float = WorldAI.get_teaching_priority_weight()
			priority = int(priority * (1.0 + teaching_weight))
		
		propose_collective_goal("research_technology", _leader_or_first_resident(), priority)
	
	# Propose memorial/remembering in scarred regions
	if death_density in ["medium", "high"] and population > 5:
		propose_collective_goal("honor_dead", _leader_or_first_resident(), 65)

# === Public Interface ===

func get_settlement_status() -> Dictionary:
	return {
		"name": settlement_name,
		"population": population,
		"government": _safe_enum_name(GovernmentType.keys(), government_type),
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
