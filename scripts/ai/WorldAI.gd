extends Node
## Advanced World AI with Neural Network Matrix Integration
## Manages civilizational planning, technological progression, and neural network-driven world evolution

enum WorldAge {
	PRIMAL = 0,        # Pre-human, natural world
	DAWN = 1,          # First humans, basic survival
	TRIBAL = 2,        # Early settlements, oral traditions
	CIVILIZED = 3,     # Cities, writing, agriculture
	CLASSICAL = 4,     # Philosophy, empires, technology
	MEDIEVAL = 5,      # Feudalism, religion, guilds
	RENAISSANCE = 6,    # Science, exploration, reformation
	INDUSTRIAL = 7,    # Manufacturing, urbanization
	MODERN = 8,        # Digital age, globalization
	FUTURE = 9         # Speculative evolution
}

enum TechnologicalTier {
	STONE = 0,         # Basic tools, fire, simple shelters
	COPPER = 1,        # Metalworking, early agriculture
	BRONZE = 2,          # Advanced tools, early writing
	IRON = 3,            # Large-scale construction, organized warfare
	STEEL = 4,           # Medieval technology, universities
	GUNPOWDER = 5,       # Early modern, exploration
	STEAM = 6,           # Industrial revolution
	ELECTRICITY = 7,     # Modern era, mass production
	DIGITAL = 8,         # Information age
	QUANTUM = 9          # Future technology
}

class WorldEvent extends RefCounted:
	var event_type: String
	var description: String
	var impact_level: int  # 1-10, how world-changing
	var affected_regions: Array[Vector2i] = []
	var participant_settlements: Array[int] = []
	var tick_occurred: int
	var historical_significance: float = 0.0
	var aftermath_effects: Array[String] = []
	
	func _init(type: String, desc: String, impact: int = 1):
		event_type = type
		description = desc
		impact_level = impact
		tick_occurred = GameManager.tick_count

class TechnologicalDiscovery extends RefCounted:
	var discovery_name: String
	var tier_required: TechnologicalTier
	var description: String
	var prerequisites: Array[String] = []
	var discovery_tick: int = 0
	
	func _init(name: String, tier: TechnologicalTier, desc: String, prerequisites: Array[String] = []):
		discovery_name = name
		tier_required = tier
		description = desc
		prerequisites = prerequisites

class ClimatePattern extends RefCounted:
	var pattern_name: String
	var temperature_shift: float = 0.0
	var precipitation_change: float = 0.0
	var duration_ticks: int = 0
	var affected_regions: Array[Vector2i] = []
	var severity: float = 0.0  # 0.0-1.0
	
	func _init(name: String, temp_shift: float, precip_change: float, duration: int, severity: float = 0.5):
		pattern_name = name
		temperature_shift = temp_shift
		precipitation_change = precip_change
		duration_ticks = duration
		severity = severity

# World properties
var current_age: WorldAge = WorldAge.PRIMAL
var technological_tier: TechnologicalTier = TechnologicalTier.STONE
var world_events: Array[WorldEvent] = []
var technological_discoveries: Array[TechnologicalDiscovery] = []
var climate_patterns: Array[ClimatePattern] = []
var active_settlements: Dictionary = {}  # settlement_id -> SettlementAI
var world_population: int = 0
var total_cultural_influence: float = 0.0

# Historical tracking
var major_turning_points: Array[String] = []
var civilization_achievements: Array[String] = []
var world_ending_events: Array[String] = []
var golden_ages: Array[Dictionary] = []

# Environmental properties
var global_temperature: float = 1.0  # Baseline temperature multiplier
var sea_level: float = 1.0  # Baseline sea level
var resource_distribution: Dictionary = {}  # resource_type -> global_availability
var biodiversity_index: float = 1.0  # Global biodiversity health

# Neural Network Matrix Integration
var neural_world_matrix: Dictionary = {}  # World-level neural network
var emergent_patterns: Array[Dictionary] = []  # Emergent world patterns
var civilization_neural_network: Dictionary = {}  # Civilization-level AI
var environmental_neural_network: Dictionary = {}  # Environmental AI
var cultural_neural_network: Dictionary = {}  # Cultural AI
var economic_neural_network: Dictionary = {}  # Economic AI

# Neural Network Evolution Parameters
var neural_evolution_rate: float = 0.005  # Rate of neural network evolution (increased for faster learning)
var pattern_emergence_threshold: float = 0.7  # Threshold for emergent patterns (lowered for more frequent patterns)
var civilization_learning_rate: float = 0.02  # Learning rate for civilization AI (increased)
var environmental_adaptation_rate: float = 0.01  # Environmental adaptation rate (increased)

# Progression parameters
var age_progression_threshold: float = 0.0  # 0.0-1.0, when to advance to next age
var tech_innovation_rate: float = 0.03  # Base rate of technological discovery (increased)
var cultural_evolution_rate: float = 0.04  # Base rate of cultural change (increased)
var environmental_stability: float = 0.8  # How stable the environment is

# Civilization development metrics
var civilization_complexity: float = 0.1  # Complexity of civilization (0.0-1.0)
var social_development: float = 0.1  # Social development level (0.0-1.0)
var cultural_advancement: float = 0.1  # Cultural advancement level (0.0-1.0)

# Additional neural networks
var technological_neural_network: Dictionary = {}  # Technological AI

func _ready():
	_initialize_world_state()
	_setup_initial_discoveries()
	_initialize_neural_world_matrix()
	_initialize_neural_networks()

# === Neural Network Matrix Initialization ===

func _initialize_neural_world_matrix() -> void:
	# Create world-level neural network matrix
	neural_world_matrix = {
		"world_state_neurons": _create_world_state_neurons(),
		"environmental_neurons": _create_environmental_neurons(),
		"civilization_neurons": _create_civilization_neurons(),
		"cultural_neurons": _create_cultural_neurons(),
		"economic_neurons": _create_economic_neurons(),
		"interconnections": _create_neural_interconnections(),
		"learning_rate": neural_evolution_rate,
		"evolution_cycles": 0
	}
	
	print("[WorldAI] Neural world matrix initialized with %d neural networks" % neural_world_matrix.size())

func _create_world_state_neurons() -> Dictionary:
	return {
		"population_density": {"value": 0.0, "activation": 0.0, "connections": []},
		"technological_progress": {"value": 0.0, "activation": 0.0, "connections": []},
		"environmental_health": {"value": 0.0, "activation": 0.0, "connections": []},
		"social_complexity": {"value": 0.0, "activation": 0.0, "connections": []},
		"resource_abundance": {"value": 0.0, "activation": 0.0, "connections": []},
		"conflict_level": {"value": 0.0, "activation": 0.0, "connections": []},
		"innovation_rate": {"value": 0.0, "activation": 0.0, "connections": []},
		"cultural_diversity": {"value": 0.0, "activation": 0.0, "connections": []},
		"trust_level": {"value": 1.0, "activation": 0.0, "connections": []},
		"authority_stability": {"value": 1.0, "activation": 0.0, "connections": []},
		"knowledge_retention": {"value": 1.0, "activation": 0.0, "connections": []},
		"collapse_risk": {"value": 0.0, "activation": 0.0, "connections": []},
		"regional_meaning_density": {"value": 0.0, "activation": 0.0, "connections": []},
		"settlement_meaning_depth": {"value": 0.0, "activation": 0.0, "connections": []}
	}

func _create_environmental_neurons() -> Dictionary:
	return {
		"temperature_stability": {"value": 1.0, "activation": 0.0, "connections": []},
		"sea_level_stability": {"value": 1.0, "activation": 0.0, "connections": []},
		"biodiversity_health": {"value": 1.0, "activation": 0.0, "connections": []},
		"resource_availability": {"value": 0.5, "activation": 0.0, "connections": []},
		"climate_stability": {"value": 0.8, "activation": 0.0, "connections": []},
		"ecosystem_resilience": {"value": 0.7, "activation": 0.0, "connections": []},
		"ruin_density": {"value": 0.0, "activation": 0.0, "connections": []},
		"grave_density": {"value": 0.0, "activation": 0.0, "connections": []},
		"historical_layering": {"value": 0.0, "activation": 0.0, "connections": []}
	}

func _create_civilization_neurons() -> Dictionary:
	return {
		"urbanization": {"value": 0.0, "activation": 0.0, "connections": []},
		"governance_complexity": {"value": 0.0, "activation": 0.0, "connections": []},
		"trade_networks": {"value": 0.0, "activation": 0.0, "connections": []},
		"military_organization": {"value": 0.0, "activation": 0.0, "connections": []},
		"educational_systems": {"value": 0.0, "activation": 0.0, "connections": []},
		"infrastructure_development": {"value": 0.0, "activation": 0.0, "connections": []},
		"civil_authority": {"value": 0.0, "activation": 0.0, "connections": []},
		"military_authority": {"value": 0.0, "activation": 0.0, "connections": []},
		"religious_authority": {"value": 0.0, "activation": 0.0, "connections": []},
		"knowledge_authority": {"value": 0.0, "activation": 0.0, "connections": []}
	}

func _create_cultural_neurons() -> Dictionary:
	return {
		"artistic_expression": {"value": 0.0, "activation": 0.0, "connections": []},
		"religious_systems": {"value": 0.0, "activation": 0.0, "connections": []},
		"philosophical_thought": {"value": 0.0, "activation": 0.0, "connections": []},
		"social_norms": {"value": 0.0, "activation": 0.0, "connections": []},
		"language_complexity": {"value": 0.0, "activation": 0.0, "connections": []},
		"cultural_exchange": {"value": 0.0, "activation": 0.0, "connections": []},
		"knowledge_distribution": {"value": 0.0, "activation": 0.0, "connections": []},
		"knowledge_scarcity": {"value": 0.0, "activation": 0.0, "connections": []},
		"teaching_activity": {"value": 0.0, "activation": 0.0, "connections": []}
	}

func _create_economic_neurons() -> Dictionary:
	return {
		"production_efficiency": {"value": 0.0, "activation": 0.0, "connections": []},
		"resource_distribution": {"value": 0.0, "activation": 0.0, "connections": []},
		"market_complexity": {"value": 0.0, "activation": 0.0, "connections": []},
		"labor_specialization": {"value": 0.0, "activation": 0.0, "connections": []},
		"wealth_accumulation": {"value": 0.0, "activation": 0.0, "connections": []},
		"economic_stability": {"value": 0.0, "activation": 0.0, "connections": []}
	}

func _create_neural_interconnections() -> Dictionary:
	var interconnections: Dictionary = {}
	
	# Create basic interconnections between neural domains
	var connection_types = [
		"civ_to_env", "civ_to_cult", "civ_to_econ",
		"env_to_cult", "cult_to_econ", "env_to_econ"
	]
	
	for connection_type in connection_types:
		interconnections[connection_type] = {
			"weight": randf_range(-0.3, 0.3),
			"strength": 1.0,
			"plasticity": 0.01,
			"type": "basic"
		}
	
	return interconnections

func _initialize_neural_networks() -> void:
	# Initialize specialized neural networks
	civilization_neural_network = _create_specialized_network("civilization", 32, 16, 8)
	environmental_neural_network = _create_specialized_network("environmental", 24, 12, 6)
	cultural_neural_network = _create_specialized_network("cultural", 28, 14, 7)
	economic_neural_network = _create_specialized_network("economic", 20, 10, 5)
	technological_neural_network = _create_specialized_network("technological", 16, 8, 4)
	
	print("[WorldAI] Specialized neural networks initialized")

func _create_specialized_network(network_type: String, input_size: int, hidden_size: int, output_size: int) -> Dictionary:
	return {
		"type": network_type,
		"layers": {
			"input": {"size": input_size, "neurons": _create_neuron_layer(input_size)},
			"hidden": {"size": hidden_size, "neurons": _create_neuron_layer(hidden_size)},
			"output": {"size": output_size, "neurons": _create_neuron_layer(output_size)}
		},
		"weights": _initialize_weights(input_size, hidden_size, output_size),
		"learning_rate": 0.01,
		"training_history": []
	}

func _create_neuron_layer(size: int) -> Array[Dictionary]:
	var layer: Array[Dictionary] = []
	for i in range(size):
		layer.append({
			"id": "neuron_%d" % i,
			"value": 0.0,
			"activation": 0.0,
			"bias": randf_range(-0.1, 0.1)
		})
	return layer

func _initialize_weights(input_size: int, hidden_size: int, output_size: int) -> Dictionary:
	var weights: Dictionary = {}
	
	# Xavier/Glorot initialization for better convergence
	var input_scale = sqrt(2.0 / float(input_size))
	var hidden_scale = sqrt(2.0 / float(hidden_size))
	
	# Input to hidden weights
	weights["input_hidden"] = []
	for i in range(input_size):
		var neuron_weights: Array[float] = []
		for j in range(hidden_size):
			neuron_weights.append(randf_range(-input_scale, input_scale))
		weights["input_hidden"].append(neuron_weights)
	
	# Hidden to output weights
	weights["hidden_output"] = []
	for i in range(hidden_size):
		var neuron_weights: Array[float] = []
		for j in range(output_size):
			neuron_weights.append(randf_range(-hidden_scale, hidden_scale))
		weights["hidden_output"].append(neuron_weights)
	
	return weights

func _initialize_world_state() -> void:
	# Start with primal world state
	current_age = WorldAge.PRIMAL
	technological_tier = TechnologicalTier.STONE
	global_temperature = 1.0
	sea_level = 1.0
	biodiversity_index = 1.0
	
	# Initialize resource distribution
	resource_distribution = {
		"stone": 1.0,
		"wood": 1.0,
		"water": 1.0,
		"food": 0.8,
		"metal": 0.3,
		"coal": 0.1,
		"oil": 0.0
	}

func _setup_initial_discoveries() -> void:
	# Set up discoveries that can be made in the Stone Age
	var stone_age_discoveries = [
		TechnologicalDiscovery.new("Fire", TechnologicalTier.STONE, "The ability to create and control fire"),
		TechnologicalDiscovery.new("Stone Tools", TechnologicalTier.STONE, "Basic tools made from stone"),
		TechnologicalDiscovery.new("Simple Shelters", TechnologicalTier.STONE, "Basic construction techniques for shelter"),
		TechnologicalDiscovery.new("Oral Language", TechnologicalTier.STONE, "Development of spoken communication"),
		TechnologicalDiscovery.new("Basic Hunting", TechnologicalTier.STONE, "Fundamental hunting and gathering techniques")
	]
	
	technological_discoveries.clear()
	for discovery in stone_age_discoveries:
		technological_discoveries.append(discovery)

# === Main Update Functions ===

func update() -> void:
	# Update world state based on neural network processing
	_update_neural_world_matrix()
	_process_climate_patterns()
	_check_for_world_events()
	_update_technological_progress()
	_update_civilization_development()
	
	# Check collapse risk and trigger emergency behaviors
	_check_collapse_emergency()
	
	# Process neural network evolution
	_update_neural_interconnections()
	_process_neural_activations()
	_detect_emergent_patterns()
	_evolve_neural_networks()

func _update_neural_world_matrix() -> void:
	# Update world state neurons with current data
	_update_world_state_neurons()
	_update_environmental_neurons()
	_update_civilization_neurons()
	_update_cultural_neurons()
	_update_economic_neurons()
	
	# Process neural activations
	_process_neural_activations()
	
	# Update interconnections
	_update_neural_interconnections()

func _trigger_settlement_emergency_responses(collapse_risk: float) -> void:
	# Trigger emergency responses in settlements based on collapse risk
	for settlement_id in active_settlements:
		var settlement_ai = active_settlements[settlement_id]
		if settlement_ai == null or not is_instance_valid(settlement_ai):
			continue
		
		if collapse_risk > 0.7:
			# High collapse risk - emergency mode
			if settlement_ai.has_method("trigger_emergency_mode"):
				settlement_ai.trigger_emergency_mode("high_collapse_risk")
		elif collapse_risk > 0.5:
			# Moderate collapse risk - warning mode
			if settlement_ai.has_method("trigger_emergency_mode"):
				settlement_ai.trigger_emergency_mode("moderate_collapse_risk")


func _check_collapse_emergency() -> void:
	if CollapseSystem == null:
		return
	
	var world_neurons = neural_world_matrix["world_state_neurons"]
	var collapse_risk = world_neurons["collapse_risk"].value
	
	# Trigger emergency behaviors based on collapse risk thresholds
	if collapse_risk > 0.7:
		# High collapse risk - emergency mode
		_trigger_emergency_mode("high_collapse_risk")
	elif collapse_risk > 0.5:
		# Moderate collapse risk - warning mode
		_trigger_emergency_mode("moderate_collapse_risk")
	elif collapse_risk > 0.3:
		# Low collapse risk - alert mode
		_trigger_emergency_mode("low_collapse_risk")
	
	# Trigger settlement-level emergency responses
	_trigger_settlement_emergency_responses(collapse_risk)


func _trigger_emergency_mode(emergency_type: String) -> void:
	match emergency_type:
		"high_collapse_risk":
			# Prioritize survival over development
			neural_evolution_rate *= 0.5  # Slow down evolution to focus on stability
			environmental_stability *= 0.9  # Environmental degradation accelerates
			if GameManager.verbose_logs():
				print("[WorldAI] HIGH COLLAPSE RISK - Emergency mode activated")
		"moderate_collapse_risk":
			# Balance survival and development
			neural_evolution_rate *= 0.8
			if GameManager.verbose_logs():
				print("[WorldAI] MODERATE COLLAPSE RISK - Warning mode activated")
		"low_collapse_risk":
			# Monitor and prepare
			if GameManager.verbose_logs():
				print("[WorldAI] LOW COLLAPSE RISK - Alert mode activated")


func _update_world_meaning_neurons(world_neurons: Dictionary) -> void:
	if WorldMeaning == null:
		return
	
	# Get world meaning metrics
	var region_count: int = WorldMeaning.get_tracked_region_count()
	var settlement_count: int = WorldMeaning.get_tracked_settlement_count()
	
	# Regional meaning density: regions with meaning / total possible regions
	world_neurons["regional_meaning_density"].value = float(region_count) / 100.0
	
	# Settlement meaning depth: settlements with meaning / active settlements
	var active_settlement_count: int = active_settlements.size()
	if active_settlement_count > 0:
		world_neurons["settlement_meaning_depth"].value = float(settlement_count) / float(active_settlement_count)
	else:
		world_neurons["settlement_meaning_depth"].value = 0.0


func _update_collapse_neurons(world_neurons: Dictionary) -> void:
	if CollapseSystem == null:
		return
	
	# Get average collapse metrics across all settlements
	var total_trust: float = 0.0
	var total_authority: float = 0.0
	var total_knowledge: float = 0.0
	var total_environmental: float = 0.0
	var settlement_count: int = 0
	
	for settlement_id in CollapseSystem.collapse_metrics:
		var metrics: Dictionary = CollapseSystem.collapse_metrics[settlement_id]
		total_trust += metrics.get("trust_level", 1.0)
		total_authority += metrics.get("authority_stability", 1.0)
		total_knowledge += metrics.get("knowledge_retention", 1.0)
		total_environmental += metrics.get("environmental_health", 1.0)
		settlement_count += 1
	
	if settlement_count > 0:
		world_neurons["trust_level"].value = total_trust / float(settlement_count)
		world_neurons["authority_stability"].value = total_authority / float(settlement_count)
		world_neurons["knowledge_retention"].value = total_knowledge / float(settlement_count)
		
		# Calculate overall collapse risk (inverse of average health)
		var avg_health: float = (total_trust + total_authority + total_knowledge + total_environmental) / (4.0 * float(settlement_count))
		world_neurons["collapse_risk"].value = 1.0 - avg_health


func _update_world_state_neurons() -> void:
	var world_neurons = neural_world_matrix["world_state_neurons"]
	
	# Update population density
	world_neurons["population_density"].value = float(world_population) / 1000.0
	
	# Update technological progress
	world_neurons["technological_progress"].value = float(technological_tier) / 10.0
	
	# Update collapse metrics from CollapseSystem
	_update_collapse_neurons(world_neurons)
	
	# Update world meaning metrics from WorldMeaning
	_update_world_meaning_neurons(world_neurons)
	
	# Update environmental health
	world_neurons["environmental_health"].value = biodiversity_index * environmental_stability
	
	# Update social complexity
	world_neurons["social_complexity"].value = float(active_settlements.size()) / 20.0
	
	# Update resource abundance
	var total_resources = 0.0
	for resource in resource_distribution:
		total_resources += resource_distribution[resource]
	world_neurons["resource_abundance"].value = total_resources / float(resource_distribution.size())
	
	# Update conflict level
	var conflict_score = 0.0
	for event in world_events:
		if event.event_type == "war" or event.event_type == "conflict":
			conflict_score += float(event.impact_level) / 10.0
	world_neurons["conflict_level"].value = conflict_score / float(max(world_events.size(), 1))
	
	# Update innovation rate
	world_neurons["innovation_rate"].value = tech_innovation_rate * float(technological_discoveries.size()) / 10.0
	
	# Update cultural diversity
	world_neurons["cultural_diversity"].value = total_cultural_influence / 100.0

func _update_persistence_neurons(env_neurons: Dictionary) -> void:
	if PersistenceSystem == null:
		return
	
	# Get persistence metrics
	var total_entities: int = PersistenceSystem.get_entity_count()
	var ruin_count: int = PersistenceSystem.get_entity_count_by_type(PersistenceSystem.EntityType.RUIN)
	var grave_count: int = PersistenceSystem.get_entity_count_by_type(PersistenceSystem.EntityType.GRAVE_FIELD)
	
	# Ruin density: ruins per settlement
	var settlement_count: int = active_settlements.size()
	if settlement_count > 0:
		env_neurons["ruin_density"].value = float(ruin_count) / float(settlement_count)
		env_neurons["grave_density"].value = float(grave_count) / float(settlement_count)
	else:
		env_neurons["ruin_density"].value = 0.0
		env_neurons["grave_density"].value = 0.0
	
	# Historical layering: total entities per 1000 population
	if world_population > 0:
		env_neurons["historical_layering"].value = float(total_entities) / (float(world_population) / 1000.0)
	else:
		env_neurons["historical_layering"].value = 0.0


func _update_environmental_neurons() -> void:
	var env_neurons = neural_world_matrix["environmental_neurons"]
	
	# Update environmental metrics
	env_neurons["temperature_stability"].value = _calculate_climate_stability()
	env_neurons["sea_level_stability"].value = _calculate_ecosystem_resilience()
	env_neurons["biodiversity_health"].value = biodiversity_index
	env_neurons["resource_availability"].value = _calculate_resource_renewability()
	env_neurons["climate_stability"].value = environmental_stability
	env_neurons["ecosystem_resilience"].value = _calculate_ecosystem_resilience()
	
	# Update persistence metrics from PersistenceSystem
	_update_persistence_neurons(env_neurons)

func get_teaching_priority_weight() -> float:
	var cult_neurons = neural_world_matrix["cultural_neurons"]
	var knowledge_scarcity = cult_neurons["knowledge_scarcity"].value
	var teaching_activity = cult_neurons["teaching_activity"].value
	
	# Teaching priority: higher when knowledge is scarce
	# Returns a weight that can be used to prioritize teaching jobs
	var priority = knowledge_scarcity * 2.0 + teaching_activity
	
	return clamp(priority, 0.0, 2.0)


func get_pawn_obedience_weight(pawn_id: int) -> float:
	if AuthoritySystem == null:
		return 1.0
	
	var civ_neurons = neural_world_matrix["civilization_neurons"]
	var civil_auth = civ_neurons["civil_authority"].value
	var military_auth = civ_neurons["military_authority"].value
	
	# Get pawn's authority level
	var pawn_civil = AuthoritySystem.get_authority_level(pawn_id, AuthoritySystem.AuthorityContext.CIVIL)
	var pawn_military = AuthoritySystem.get_authority_level(pawn_id, AuthoritySystem.AuthorityContext.MILITARY)
	
	# Obedience weight: how much authority this pawn has relative to average
	# Higher authority = higher obedience from others
	var obedience_weight = (pawn_civil / (civil_auth + 0.01) + pawn_military / (military_auth + 0.01)) / 2.0
	
	return clamp(obedience_weight, 0.1, 2.0)


func _update_authority_neurons(civ_neurons: Dictionary) -> void:
	if AuthoritySystem == null:
		return
	
	# Get average authority levels across all pawns
	var total_civil: float = 0.0
	var total_military: float = 0.0
	var total_religious: float = 0.0
	var total_knowledge: float = 0.0
	var pawn_count: int = 0
	
	# Get all pawns in the world
	var pawns = get_tree().get_nodes_in_group("pawns")
	for pawn in pawns:
		if not is_instance_valid(pawn) or pawn.data == null:
			continue
		var pawn_id: int = int(pawn.data.id)
		
		total_civil += AuthoritySystem.get_authority_level(pawn_id, AuthoritySystem.AuthorityContext.CIVIL)
		total_military += AuthoritySystem.get_authority_level(pawn_id, AuthoritySystem.AuthorityContext.MILITARY)
		total_religious += AuthoritySystem.get_authority_level(pawn_id, AuthoritySystem.AuthorityContext.RELIGIOUS)
		total_knowledge += AuthoritySystem.get_authority_level(pawn_id, AuthoritySystem.AuthorityContext.KNOWLEDGE)
		pawn_count += 1
	
	if pawn_count > 0:
		civ_neurons["civil_authority"].value = total_civil / float(pawn_count)
		civ_neurons["military_authority"].value = total_military / float(pawn_count)
		civ_neurons["religious_authority"].value = total_religious / float(pawn_count)
		civ_neurons["knowledge_authority"].value = total_knowledge / float(pawn_count)


func _update_civilization_neurons() -> void:
	var civ_neurons = neural_world_matrix["civilization_neurons"]
	
	# Update civilization metrics
	civ_neurons["urbanization"].value = float(active_settlements.size()) / 50.0
	civ_neurons["governance_complexity"].value = civilization_complexity
	civ_neurons["trade_networks"].value = _calculate_trade_network_complexity()
	civ_neurons["military_organization"].value = _calculate_military_organization()
	civ_neurons["educational_systems"].value = _calculate_educational_development()
	civ_neurons["infrastructure_development"].value = _calculate_infrastructure_level()
	
	# Update authority metrics from AuthoritySystem
	_update_authority_neurons(civ_neurons)

func _update_knowledge_neurons(cult_neurons: Dictionary) -> void:
	if KnowledgeSystem == null:
		return
	
	# Get knowledge distribution metrics
	var carrier_count: int = KnowledgeSystem.get_carrier_count()
	var total_knowledge: int = KnowledgeSystem.get_total_knowledge_count()
	var pawns = get_tree().get_nodes_in_group("pawns")
	var pawn_count: int = pawns.size()
	
	if pawn_count > 0:
		# Knowledge distribution: ratio of carriers to total pawns
		cult_neurons["knowledge_distribution"].value = float(carrier_count) / float(pawn_count)
		
		# Knowledge scarcity: inverse of distribution (higher = more scarce)
		cult_neurons["knowledge_scarcity"].value = 1.0 - cult_neurons["knowledge_distribution"].value
		
		# Teaching activity: based on knowledge scarcity (higher scarcity = more teaching needed)
		cult_neurons["teaching_activity"].value = cult_neurons["knowledge_scarcity"].value


func _update_cultural_neurons() -> void:
	var cult_neurons = neural_world_matrix["cultural_neurons"]
	
	# Update cultural metrics
	cult_neurons["artistic_expression"].value = _calculate_artistic_expression()
	cult_neurons["religious_systems"].value = _calculate_religious_complexity()
	cult_neurons["philosophical_thought"].value = _calculate_philosophical_development()
	cult_neurons["social_norms"].value = _calculate_social_norm_complexity()
	cult_neurons["language_complexity"].value = _calculate_language_complexity()
	cult_neurons["cultural_exchange"].value = _calculate_cultural_exchange_rate()
	
	# Update knowledge metrics from KnowledgeSystem
	_update_knowledge_neurons(cult_neurons)

func _update_economic_neurons() -> void:
	var econ_neurons = neural_world_matrix["economic_neurons"]
	
	# Update economic metrics
	econ_neurons["production_efficiency"].value = _calculate_production_efficiency()
	econ_neurons["resource_distribution"].value = _calculate_resource_distribution_efficiency()
	econ_neurons["market_complexity"].value = _calculate_market_complexity()
	econ_neurons["labor_specialization"].value = _calculate_labor_specialization()
	econ_neurons["wealth_accumulation"].value = _calculate_wealth_accumulation()
	econ_neurons["economic_stability"].value = _calculate_economic_stability()

func _update_neural_interconnections() -> void:
	# Update interconnections between neural networks based on current state
	if not neural_world_matrix.has("interconnections"):
		neural_world_matrix["interconnections"] = {}
	
	var interconnections = neural_world_matrix["interconnections"]
	
	# Calculate connection strengths based on system correlations
	var civ_env_strength = civilization_complexity * environmental_stability
	var civ_cult_strength = civilization_complexity * cultural_advancement
	var civ_econ_strength = civilization_complexity * _calculate_economic_stability()
	var env_cult_strength = environmental_stability * cultural_advancement
	var cult_econ_strength = cultural_advancement * _calculate_economic_stability()
	
	# Update or create interconnections with proper structure
	if interconnections.has("civ_to_env"):
		interconnections["civ_to_env"]["strength"] = civ_env_strength
	else:
		interconnections["civ_to_env"] = {"strength": civ_env_strength, "weight": 0.5, "type": "influence"}
	
	if interconnections.has("civ_to_cult"):
		interconnections["civ_to_cult"]["strength"] = civ_cult_strength
	else:
		interconnections["civ_to_cult"] = {"strength": civ_cult_strength, "weight": 0.5, "type": "development"}
	
	if interconnections.has("civ_to_econ"):
		interconnections["civ_to_econ"]["strength"] = civ_econ_strength
	else:
		interconnections["civ_to_econ"] = {"strength": civ_econ_strength, "weight": 0.5, "type": "resource"}
	
	if interconnections.has("env_to_cult"):
		interconnections["env_to_cult"]["strength"] = env_cult_strength
	else:
		interconnections["env_to_cult"] = {"strength": env_cult_strength, "weight": 0.5, "type": "adaptation"}
	
	if interconnections.has("cult_to_econ"):
		interconnections["cult_to_econ"]["strength"] = cult_econ_strength
	else:
		interconnections["cult_to_econ"] = {"strength": cult_econ_strength, "weight": 0.5, "type": "trade"}
	
	# Remove weak connections
	var connections_to_remove = []
	for connection_id in interconnections:
		var connection = interconnections[connection_id]
		if connection.has("strength") and connection["strength"] < 0.01:
			connections_to_remove.append(connection_id)
	
	for connection_id in connections_to_remove:
		interconnections.erase(connection_id)

func _process_neural_activations() -> void:
	# Process all neural networks through activation functions
	var all_networks = [
		neural_world_matrix["world_state_neurons"],
		neural_world_matrix["environmental_neurons"],
		neural_world_matrix["civilization_neurons"],
		neural_world_matrix["cultural_neurons"],
		neural_world_matrix["economic_neurons"]
	]
	
	for network in all_networks:
		for neuron_name in network:
			var neuron = network[neuron_name]
			neuron["activation"] = _apply_neural_activation(neuron["value"])

func _apply_neural_activation(value: float) -> float:
	# Use sigmoid activation function for neural processing
	return 1.0 / (1.0 + exp(-value))

func _process_neural_networks() -> void:
	# Process specialized neural networks
	_process_civilization_network()
	_process_environmental_network()
	_process_cultural_network()
	_process_economic_network()
	_process_technological_network()

func _process_civilization_network() -> void:
	var input_data = _extract_civilization_input()
	var output = _forward_propagate_network(input_data, civilization_neural_network)
	_interpret_civilization_output(output)

func _process_environmental_network() -> void:
	var input_data = _extract_environmental_input()
	var output = _forward_propagate_network(input_data, environmental_neural_network)
	_interpret_environmental_output(output)

func _process_cultural_network() -> void:
	var input_data = _extract_cultural_input()
	var output = _forward_propagate_network(input_data, cultural_neural_network)
	_interpret_cultural_output(output)

func _process_economic_network() -> void:
	var input_data = _extract_economic_input()
	var output = _forward_propagate_network(input_data, economic_neural_network)
	_interpret_economic_output(output)

func _process_technological_network() -> void:
	var input_data = _extract_technological_input()
	var output = _forward_propagate_network(input_data, technological_neural_network)
	_interpret_technological_output(output)

func _detect_emergent_patterns() -> void:
	# Analyze neural network activity for emergent patterns
	var current_state = _get_current_neural_state()
	var pattern_score = _calculate_pattern_emergence()
	
	if pattern_score >= pattern_emergence_threshold:
		var new_pattern = _create_emergent_pattern()
		emergent_patterns.append(new_pattern)
		_apply_emergent_pattern_effects(new_pattern)

func _evolve_neural_networks() -> void:
	# Evolve neural networks based on experience
	neural_world_matrix["evolution_cycles"] += 1
	
	# Apply learning and adaptation
	_adapt_neural_weights()
	_mutate_neural_structures()
	_prune_weak_connections()

func _adapt_neural_weights() -> void:
	# Adapt weights based on performance feedback
	if not neural_world_matrix.has("learning_rate"):
		neural_world_matrix["learning_rate"] = neural_evolution_rate
	
	var learning_rate = neural_world_matrix["learning_rate"]
	
	if not neural_world_matrix.has("interconnections"):
		return
	
	for connection_id in neural_world_matrix["interconnections"]:
		var connection = neural_world_matrix["interconnections"][connection_id]
		if not connection.has("weight"):
			connection["weight"] = 0.5
		
		var adaptation = _calculate_weight_adaptation()
		connection["weight"] += learning_rate * adaptation
		connection["weight"] = clamp(connection["weight"], -1.0, 1.0)

func _mutate_neural_structures() -> void:
	# Occasionally mutate neural structures for evolution
	if randf() < neural_evolution_rate:
		_mutate_random_connection()

func _prune_weak_connections() -> void:
	# Remove very weak connections to improve efficiency
	var connections_to_remove = []
	
	for connection_id in neural_world_matrix["interconnections"]:
		var connection = neural_world_matrix["interconnections"][connection_id]
		if abs(connection["weight"]) < 0.01:
			connections_to_remove.append(connection_id)
	
	for connection_id in connections_to_remove:
		neural_world_matrix["interconnections"].erase(connection_id)

# === Missing Update Functions ===

func _update_environmental_conditions() -> void:
	# Update environmental conditions based on neural network processing
	var environmental_input = _extract_environmental_input()
	var neural_output = _forward_propagate_network(environmental_input, environmental_neural_network)
	var interpreted_output = _interpret_environmental_output(neural_output)
	
	# Apply environmental changes
	environmental_stability = interpreted_output["stability"]
	biodiversity_index = interpreted_output["biodiversity"]
	global_temperature = interpreted_output["temperature"]
	sea_level = interpreted_output["sea_level"]

func _process_climate_patterns() -> void:
	# Process climate patterns using neural networks
	var climate_data = {
		"temperature": global_temperature,
		"sea_level": sea_level,
		"biodiversity": biodiversity_index,
		"stability": environmental_stability
	}
	
	# Detect climate patterns
	if climate_data.temperature > 1.2:
		_trigger_climate_event("warming_period", "Global warming period detected")
	elif climate_data.temperature < 0.8:
		_trigger_climate_event("cooling_period", "Global cooling period detected")
	
	if climate_data.sea_level > 1.1:
		_trigger_climate_event("sea_level_rise", "Sea level rising")
	elif climate_data.sea_level < 0.9:
		_trigger_climate_event("sea_level_fall", "Sea level falling")

func _check_for_world_events() -> void:
	# Check for potential world events based on current conditions
	var event_probability = _calculate_event_probability()
	
	if randf() < event_probability:
		_generate_world_event()

func _update_technological_progress() -> void:
	# Update technological progress based on neural network analysis
	var tech_input = _extract_technological_input()
	var tech_output = _forward_propagate_network(tech_input, technological_neural_network)
	
	# Check for new discoveries
	if randf() < tech_output["discovery_probability"]:
		_generate_technological_discovery()
	
	# Update technological tier
	if technological_discoveries.size() > get_tier_discoveries_required(technological_tier + 1):
		technological_tier = min(technological_tier + 1, TechnologicalTier.QUANTUM)

func _update_civilization_development() -> void:
	# Update civilization development metrics
	var civ_input = _extract_civilization_input()
	var civ_raw_output = _forward_propagate_network(civ_input, civilization_neural_network)
	var civ_output = _interpret_civilization_output(civ_raw_output)
	
	# Update civilization metrics
	civilization_complexity = civ_output["complexity"]
	social_development = civ_output["social_development"]
	cultural_advancement = civ_output["cultural_advancement"]
	
	# Advance WorldAge based on actual game progress
	_advance_world_age()

func _advance_world_age() -> void:
	# Get actual game metrics from SettlementMemory
	var settlements = SettlementMemory.get_settlements()
	var active_settlement_count = 0
	for s in settlements:
		if s.get("state", "") == "active":
			active_settlement_count += 1
	
	var living_pawns = SettlementMemory._living_pawns()
	var total_pawns = living_pawns.size()
	
	# Progression thresholds for each age
	var age_thresholds = {
		WorldAge.PRIMAL: {"pawns": 0, "settlements": 0, "tech": TechnologicalTier.STONE},
		WorldAge.DAWN: {"pawns": 5, "settlements": 1, "tech": TechnologicalTier.STONE},
		WorldAge.TRIBAL: {"pawns": 15, "settlements": 2, "tech": TechnologicalTier.COPPER},
		WorldAge.CIVILIZED: {"pawns": 30, "settlements": 3, "tech": TechnologicalTier.BRONZE},
		WorldAge.CLASSICAL: {"pawns": 50, "settlements": 5, "tech": TechnologicalTier.IRON},
		WorldAge.MEDIEVAL: {"pawns": 80, "settlements": 7, "tech": TechnologicalTier.STEEL},
		WorldAge.RENAISSANCE: {"pawns": 120, "settlements": 10, "tech": TechnologicalTier.GUNPOWDER},
		WorldAge.INDUSTRIAL: {"pawns": 200, "settlements": 15, "tech": TechnologicalTier.STEAM},
		WorldAge.MODERN: {"pawns": 300, "settlements": 20, "tech": TechnologicalTier.ELECTRICITY},
		WorldAge.FUTURE: {"pawns": 500, "settlements": 30, "tech": TechnologicalTier.QUANTUM}
	}
	
	# Check if we can advance to next age
	var next_age = min(current_age + 1, WorldAge.FUTURE)
	var threshold = age_thresholds[next_age]
	
	if total_pawns >= threshold["pawns"] and active_settlement_count >= threshold["settlements"] and technological_tier >= threshold["tech"]:
		current_age = next_age
		print("[WorldAI] Civilization advanced to age: %s" % WorldAge.keys()[current_age])
		major_turning_points.append("Advanced to %s age" % WorldAge.keys()[current_age])

# === Missing Calculation Functions ===

func _calculate_resource_renewability() -> float:
	var renewability = 0.0
	
	# Calculate based on environmental factors
	renewability += biodiversity_index * 0.3
	renewability += environmental_stability * 0.4
	renewability += (1.0 - abs(global_temperature - 1.0)) * 0.3
	
	return clamp(renewability, 0.0, 1.0)

func _calculate_climate_stability() -> float:
	var stability = 0.0
	
	# Calculate based on temperature and sea level variance
	stability += (1.0 - abs(global_temperature - 1.0)) * 0.5
	stability += (1.0 - abs(sea_level - 1.0)) * 0.3
	stability += biodiversity_index * 0.2
	
	return clamp(stability, 0.0, 1.0)

func _calculate_ecosystem_resilience() -> float:
	var resilience = 0.0
	
	# Calculate based on biodiversity and environmental health
	resilience += biodiversity_index * 0.4
	resilience += environmental_stability * 0.3
	resilience += _calculate_resource_renewability() * 0.3
	
	return clamp(resilience, 0.0, 1.0)

func _calculate_trade_network_complexity() -> float:
	var complexity = 0.0
	
	# Calculate based on settlements and technological level
	complexity += float(active_settlements.size()) / 20.0 * 0.4
	complexity += float(technological_tier) / 10.0 * 0.3
	complexity += civilization_complexity * 0.3
	
	return clamp(complexity, 0.0, 1.0)

func _calculate_military_organization() -> float:
	var organization = 0.0
	
	# Calculate based on civilization development
	organization += civilization_complexity * 0.4
	organization += float(technological_tier) / 10.0 * 0.3
	organization += social_development * 0.3
	
	return clamp(organization, 0.0, 1.0)

func _calculate_educational_development() -> float:
	var education = 0.0
	
	# Calculate based on technological and cultural advancement
	education += float(technological_tier) / 10.0 * 0.4
	education += cultural_advancement * 0.3
	education += civilization_complexity * 0.3
	
	return clamp(education, 0.0, 1.0)

func _calculate_infrastructure_level() -> float:
	var infrastructure = 0.0
	
	# Calculate based on population and technology
	infrastructure += float(world_population) / 1000.0 * 0.3
	infrastructure += float(technological_tier) / 10.0 * 0.4
	infrastructure += civilization_complexity * 0.3
	
	return clamp(infrastructure, 0.0, 1.0)

func _calculate_artistic_expression() -> float:
	var art = 0.0
	
	# Calculate based on cultural development
	art += cultural_advancement * 0.5
	art += social_development * 0.3
	art += civilization_complexity * 0.2
	
	return clamp(art, 0.0, 1.0)

func _calculate_religious_complexity() -> float:
	var religion = 0.0
	
	# Calculate based on cultural and social development
	religion += cultural_advancement * 0.4
	religion += social_development * 0.3
	religion += civilization_complexity * 0.3
	
	return clamp(religion, 0.0, 1.0)

func _calculate_philosophical_development() -> float:
	var philosophy = 0.0
	
	# Calculate based on educational and cultural development
	philosophy += _calculate_educational_development() * 0.4
	philosophy += cultural_advancement * 0.3
	philosophy += social_development * 0.3
	
	return clamp(philosophy, 0.0, 1.0)

func _calculate_social_norm_complexity() -> float:
	var norms = 0.0
	
	# Calculate based on social and cultural development
	norms += social_development * 0.4
	norms += cultural_advancement * 0.3
	norms += civilization_complexity * 0.3
	
	return clamp(norms, 0.0, 1.0)

func _calculate_language_complexity() -> float:
	var language = 0.0
	
	# Calculate based on cultural and social development
	language += cultural_advancement * 0.4
	language += social_development * 0.3
	language += civilization_complexity * 0.3
	
	return clamp(language, 0.0, 1.0)

func _calculate_cultural_exchange_rate() -> float:
	var exchange = 0.0
	
	# Calculate based on trade network and cultural development
	exchange += _calculate_trade_network_complexity() * 0.4
	exchange += cultural_advancement * 0.3
	exchange += float(active_settlements.size()) / 20.0 * 0.3
	
	return clamp(exchange, 0.0, 1.0)

func _calculate_production_efficiency() -> float:
	var efficiency = 0.0
	
	# Calculate based on technology and infrastructure
	efficiency += float(technological_tier) / 10.0 * 0.4
	efficiency += _calculate_infrastructure_level() * 0.3
	efficiency += civilization_complexity * 0.3
	
	return clamp(efficiency, 0.0, 1.0)

func _calculate_resource_distribution_efficiency() -> float:
	var efficiency = 0.0
	
	# Calculate based on infrastructure and trade networks
	efficiency += _calculate_infrastructure_level() * 0.4
	efficiency += _calculate_trade_network_complexity() * 0.3
	efficiency += social_development * 0.3
	
	return clamp(efficiency, 0.0, 1.0)

func _calculate_market_complexity() -> float:
	var complexity = 0.0
	
	# Calculate based on trade networks and settlements
	complexity += _calculate_trade_network_complexity() * 0.4
	complexity += float(active_settlements.size()) / 20.0 * 0.3
	complexity += civilization_complexity * 0.3
	
	return clamp(complexity, 0.0, 1.0)

func _calculate_labor_specialization() -> float:
	var specialization = 0.0
	
	# Calculate based on education and civilization development
	specialization += _calculate_educational_development() * 0.4
	specialization += civilization_complexity * 0.3
	specialization += social_development * 0.3
	
	return clamp(specialization, 0.0, 1.0)

func _calculate_wealth_accumulation() -> float:
	var wealth = 0.0
	
	# Calculate based on production efficiency and market complexity
	wealth += _calculate_production_efficiency() * 0.4
	wealth += _calculate_market_complexity() * 0.3
	wealth += civilization_complexity * 0.3
	
	return clamp(wealth, 0.0, 1.0)

func _calculate_economic_stability() -> float:
	var stability = 0.0
	
	# Calculate based on multiple economic factors
	stability += _calculate_production_efficiency() * 0.2
	stability += _calculate_market_complexity() * 0.2
	stability += _calculate_wealth_accumulation() * 0.2
	stability += _calculate_labor_specialization() * 0.2
	stability += _calculate_resource_distribution_efficiency() * 0.2
	
	return clamp(stability, 0.0, 1.0)

# === Missing Neural Network Functions ===

func _extract_civilization_input() -> Array[float]:
	var input: Array[float] = []
	input.append(float(world_population) / 1000.0)
	input.append(float(technological_tier) / 10.0)
	input.append(civilization_complexity)
	input.append(social_development)
	input.append(cultural_advancement)
	input.append(float(active_settlements.size()) / 50.0)
	input.append(_calculate_trade_network_complexity())
	input.append(_calculate_military_organization())
	
	# Pad to required size
	while input.size() < 64:
		input.append(0.0)
	
	return input

func _extract_environmental_input() -> Array[float]:
	var input: Array[float] = []
	input.append(global_temperature)
	input.append(sea_level)
	input.append(biodiversity_index)
	input.append(environmental_stability)
	input.append(_calculate_resource_renewability())
	input.append(_calculate_climate_stability())
	input.append(_calculate_ecosystem_resilience())
	
	# Add resource distribution data
	for resource in resource_distribution:
		input.append(resource_distribution[resource])
	
	# Pad to required size
	while input.size() < 64:
		input.append(0.0)
	
	return input

func _extract_cultural_input() -> Array[float]:
	var input: Array[float] = []
	input.append(cultural_advancement)
	input.append(_calculate_artistic_expression())
	input.append(_calculate_religious_complexity())
	input.append(_calculate_philosophical_development())
	input.append(_calculate_social_norm_complexity())
	input.append(_calculate_language_complexity())
	input.append(_calculate_cultural_exchange_rate())
	input.append(total_cultural_influence / 100.0)
	
	# Pad to required size
	while input.size() < 64:
		input.append(0.0)
	
	return input

func _extract_economic_input() -> Array[float]:
	var input: Array[float] = []
	input.append(_calculate_production_efficiency())
	input.append(_calculate_resource_distribution_efficiency())
	input.append(_calculate_market_complexity())
	input.append(_calculate_labor_specialization())
	input.append(_calculate_wealth_accumulation())
	input.append(_calculate_economic_stability())
	input.append(float(world_population) / 1000.0)
	input.append(float(technological_tier) / 10.0)
	
	# Pad to required size
	while input.size() < 64:
		input.append(0.0)
	
	return input

func _extract_technological_input() -> Array[float]:
	var input: Array[float] = []
	input.append(float(technological_tier) / 10.0)
	input.append(float(technological_discoveries.size()) / 20.0)
	input.append(tech_innovation_rate)
	input.append(civilization_complexity)
	input.append(social_development)
	input.append(_calculate_infrastructure_level())
	input.append(_calculate_educational_development())
	input.append(_calculate_production_efficiency())
	
	# Pad to required size
	while input.size() < 64:
		input.append(0.0)
	
	return input

func _forward_propagate_network(input: Array[float], network: Dictionary) -> Dictionary:
	var output: Dictionary = {}
	
	# Simple forward propagation simulation
	var hidden_layer: Array[float] = []
	for i in range(32):  # Hidden layer size
		var sum = 0.0
		for j in range(min(input.size(), 64)):
			sum += input[j] * randf_range(-1.0, 1.0)
		hidden_layer.append(_sigmoid(sum))
	
	# Output layer
	output["stability"] = hidden_layer[0]
	output["complexity"] = hidden_layer[1]
	output["efficiency"] = hidden_layer[2]
	output["growth_rate"] = hidden_layer[3]
	output["discovery_probability"] = hidden_layer[4]
	output["adaptation_rate"] = hidden_layer[5]
	
	return output

func _interpret_civilization_output(output: Dictionary) -> Dictionary:
	var interpreted: Dictionary = {}
	
	interpreted["complexity"] = clamp(output["complexity"], 0.0, 1.0)
	interpreted["social_development"] = clamp(output["stability"], 0.0, 1.0)
	interpreted["cultural_advancement"] = clamp(output["efficiency"], 0.0, 1.0)
	
	return interpreted

func _interpret_environmental_output(output: Dictionary) -> Dictionary:
	var interpreted: Dictionary = {}
	
	interpreted["stability"] = clamp(output["stability"], 0.0, 1.0)
	interpreted["biodiversity"] = clamp(output["complexity"], 0.0, 1.0)
	interpreted["temperature"] = clamp(output["efficiency"], 0.5, 1.5)
	interpreted["sea_level"] = clamp(output["growth_rate"], 0.5, 1.5)
	
	return interpreted

func _interpret_cultural_output(output: Dictionary) -> Dictionary:
	var interpreted: Dictionary = {}
	
	interpreted["artistic_level"] = clamp(output["complexity"], 0.0, 1.0)
	interpreted["religious_influence"] = clamp(output["stability"], 0.0, 1.0)
	interpreted["philosophical_depth"] = clamp(output["efficiency"], 0.0, 1.0)
	
	return interpreted

func _interpret_economic_output(output: Dictionary) -> Dictionary:
	var interpreted: Dictionary = {}
	
	interpreted["production_rate"] = clamp(output["complexity"], 0.0, 1.0)
	interpreted["market_activity"] = clamp(output["stability"], 0.0, 1.0)
	interpreted["trade_volume"] = clamp(output["efficiency"], 0.0, 1.0)
	
	return interpreted

func _interpret_technological_output(output: Dictionary) -> Dictionary:
	var interpreted: Dictionary = {}
	
	interpreted["innovation_rate"] = clamp(output["discovery_probability"], 0.0, 1.0)
	interpreted["research_efficiency"] = clamp(output["efficiency"], 0.0, 1.0)
	interpreted["tech_adoption"] = clamp(output["growth_rate"], 0.0, 1.0)
	
	return interpreted

func _sigmoid(x: float) -> float:
	return 1.0 / (1.0 + exp(-x))

# === Missing Evolution Functions ===

func _get_current_neural_state() -> Dictionary:
	var state: Dictionary = {}
	
	state["civilization_complexity"] = civilization_complexity
	state["social_development"] = social_development
	state["cultural_advancement"] = cultural_advancement
	state["environmental_stability"] = environmental_stability
	state["technological_tier"] = technological_tier
	state["world_population"] = world_population
	
	return state

func _calculate_pattern_emergence() -> float:
	var emergence = 0.0
	
	emergence += abs(civilization_complexity - 0.5) * 0.2
	emergence += abs(cultural_advancement - 0.5) * 0.2
	emergence += abs(environmental_stability - 0.5) * 0.2
	emergence += float(active_settlements.size()) / 100.0 * 0.2
	emergence += float(technological_discoveries.size()) / 50.0 * 0.2
	
	return clamp(emergence, 0.0, 1.0)

func _create_emergent_pattern() -> Dictionary:
	var pattern: Dictionary = {}
	var pattern_type = _generate_pattern_type()
	
	pattern["type"] = pattern_type
	pattern["description"] = _generate_pattern_description(pattern_type)
	pattern["effects"] = _generate_pattern_effects(pattern_type)
	pattern["neural_signature"] = _generate_neural_signature()
	pattern["strength"] = _calculate_pattern_emergence()
	pattern["timestamp"] = GameManager.tick_count
	
	return pattern

func _apply_emergent_pattern_effects(pattern: Dictionary) -> void:
	# Apply pattern effects to world state
	for effect in pattern["effects"]:
		_apply_pattern_effect(effect)

func _calculate_weight_adaptation() -> float:
	var adaptation = 0.0
	
	adaptation += randf_range(-0.1, 0.1)
	adaptation += (civilization_complexity - 0.5) * 0.05
	adaptation += (environmental_stability - 0.5) * 0.05
	
	return clamp(adaptation, -0.2, 0.2)

func _mutate_random_connection() -> void:
	var connections = []
	for connection_id in neural_world_matrix["interconnections"]:
		connections.append(connection_id)
	
	if connections.size() > 0:
		var random_connection = connections[randi() % connections.size()]
		var connection = neural_world_matrix["interconnections"][random_connection]
		connection["weight"] += randf_range(-0.1, 0.1)
		connection["weight"] = clamp(connection["weight"], -1.0, 1.0)

# === Helper Functions ===

func _trigger_climate_event(event_type: String, description: String) -> void:
	var event = WorldEvent.new(event_type, description, 3)
	world_events.append(event)
	
	# Apply immediate effects
	match event_type:
		"warming_period":
			global_temperature += 0.1
		"cooling_period":
			global_temperature -= 0.1
		"sea_level_rise":
			sea_level += 0.05
		"sea_level_fall":
			sea_level -= 0.05

func _calculate_event_probability() -> float:
	var probability = 0.01  # Base probability
	
	# Increase probability based on world complexity
	probability += civilization_complexity * 0.02
	probability += float(active_settlements.size()) / 100.0 * 0.01
	probability += float(technological_discoveries.size()) / 50.0 * 0.01
	
	return clamp(probability, 0.0, 0.1)

func _generate_world_event() -> void:
	var event_types = ["war", "peace", "discovery", "plague", "famine", "prosperity"]
	var event_type = event_types[randi() % event_types.size()]
	var description = _generate_event_description(event_type)
	var impact = randi_range(1, 5)
	
	var event = WorldEvent.new(event_type, description, impact)
	world_events.append(event)

func _generate_technological_discovery() -> void:
	var discovery_names = [
		"Advanced Tools", "Agriculture", "Writing", "Metallurgy", 
		"Mathematics", "Astronomy", "Medicine", "Engineering"
	]
	var name = discovery_names[randi() % discovery_names.size()]
	var description = "Breakthrough in " + name
	
	var discovery = TechnologicalDiscovery.new(name, technological_tier, description)
	technological_discoveries.append(discovery)

func _generate_event_description(event_type: String) -> String:
	match event_type:
		"war":
			return "Conflict breaks out between settlements"
		"peace":
			return "Treaty established bringing peace"
		"discovery":
			return "New discovery changes the world"
		"plague":
			return "Disease spreads through the population"
		"famine":
			return "Food shortage affects the region"
		"prosperity":
			return "Period of growth and abundance"
		_:
			return "Significant world event occurs"

func _generate_pattern_type() -> String:
	var types = ["cultural_shift", "technological_breakthrough", "environmental_change", "social_evolution"]
	return types[randi() % types.size()]

func _generate_pattern_description(pattern_type: String) -> String:
	match pattern_type:
		"cultural_shift":
			return "Significant change in cultural values and practices"
		"technological_breakthrough":
			return "Revolutionary technological advancement"
		"environmental_change":
			return "Major environmental transformation"
		"social_evolution":
			return "Evolution of social structures and relationships"
		_:
			return "Emergent pattern detected in world system"

func _generate_pattern_effects(pattern_type: String) -> Array[String]:
	var effects: Array[String] = []
	
	match pattern_type:
		"cultural_shift":
			effects.append("cultural_advancement += 0.1")
			effects.append("social_development += 0.05")
		"technological_breakthrough":
			effects.append("technological_tier += 1")
			effects.append("tech_innovation_rate += 0.02")
		"environmental_change":
			effects.append("environmental_stability += 0.1")
			effects.append("biodiversity_index += 0.05")
		"social_evolution":
			effects.append("civilization_complexity += 0.1")
			effects.append("social_development += 0.05")
	
	return effects

func _generate_neural_signature() -> Array[float]:
	var signature: Array[float] = []
	for i in range(16):
		signature.append(randf_range(-1.0, 1.0))
	return signature

func _apply_pattern_effect(effect: String) -> void:
	# Parse and apply effect string
	var parts = effect.split(" ")
	if parts.size() == 3:
		var variable = parts[0]
		var operator = parts[1]
		var value = float(parts[2])
		
		match variable:
			"cultural_advancement":
				if operator == "+=":
					cultural_advancement += value
			"social_development":
				if operator == "+=":
					social_development += value
			"technological_tier":
				if operator == "+=":
					technological_tier = min(technological_tier + int(value), TechnologicalTier.QUANTUM)
			"tech_innovation_rate":
				if operator == "+=":
					tech_innovation_rate += value
			"environmental_stability":
				if operator == "+=":
					environmental_stability += value
			"biodiversity_index":
				if operator == "+=":
					biodiversity_index += value
			"civilization_complexity":
				if operator == "+=":
					civilization_complexity += value

func get_tier_discoveries_required(tier: TechnologicalTier) -> int:
	match tier:
		TechnologicalTier.STONE:
			return 0
		TechnologicalTier.COPPER:
			return 3
		TechnologicalTier.BRONZE:
			return 6
		TechnologicalTier.IRON:
			return 10
		TechnologicalTier.STEEL:
			return 15
		TechnologicalTier.GUNPOWDER:
			return 20
		TechnologicalTier.STEAM:
			return 25
		TechnologicalTier.ELECTRICITY:
			return 30
		TechnologicalTier.DIGITAL:
			return 35
		TechnologicalTier.QUANTUM:
			return 40
		_:
			return 0

# === Public Interface ===

func get_world_status() -> Dictionary:
	var status: Dictionary = {}
	
	status.current_age = current_age
	status.technological_tier = technological_tier
	status.world_population = world_population
	status.civilization_complexity = civilization_complexity
	status.environmental_stability = environmental_stability
	status.active_settlements = active_settlements.size()
	status.technological_discoveries = technological_discoveries.size()
	status.world_events = world_events.size()
	
	return status

func get_neural_network_status() -> Dictionary:
	var status: Dictionary = {}
	
	status["neural_world_matrix_size"] = neural_world_matrix.size()
	status["emergent_patterns_count"] = emergent_patterns.size()
	status["evolution_cycles"] = neural_world_matrix["evolution_cycles"]
	status["interconnections_count"] = neural_world_matrix["interconnections"].size()
	
	return status

func _cleanup_old_events() -> void:
	# Keep only recent events (last 1000 ticks)
	var current_tick = GameManager.tick_count
	var events_to_remove = []
	
	for i in range(world_events.size()):
		var event = world_events[i]
		if current_tick - event.tick_occurred > 1000:
			events_to_remove.append(i)
	
	# Remove old events (in reverse order to maintain indices)
	for i in range(events_to_remove.size() - 1, -1, -1):
		world_events.remove_at(events_to_remove[i])

func remove_settlement(settlement_id: int) -> void:
	if active_settlements.has(settlement_id):
		active_settlements.erase(settlement_id)

func get_technological_progress() -> float:
	var discovered_count: int = 0
	for discovery in technological_discoveries:
		if discovery.discovery_tick > 0:
			discovered_count += 1
	
	return float(discovered_count) / float(technological_discoveries.size())
