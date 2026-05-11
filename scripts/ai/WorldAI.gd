extends Node
## Advanced World AI with Neural Network Matrix Integration
## Manages civilizational planning, technological progression, and neural network-driven world evolution

const _PAWN_DECISION_RULES: Script = preload("res://scripts/ai/PawnDecisionRuleMatrix.gd")

## Lazily constructed — [method _pawn_decision_rule_matrix] returns this.
var _pawn_decision_rule_evaluator: RefCounted = null

# Event dispatch signals
signal collapse_warning_event(event: WorldEvent)
signal knowledge_crisis_event(event: WorldEvent)
signal authority_vacuum_event(event: WorldEvent)
signal historical_discovery_event(event: WorldEvent)
signal environmental_degradation_event(event: WorldEvent)
signal economic_boom_event(event: WorldEvent)
signal market_crash_event(event: WorldEvent)
signal religious_schism_event(event: WorldEvent)
signal religious_conversion_event(event: WorldEvent)
signal world_event_dispatched(event: WorldEvent)

# Autoload references
@onready var CollapseSystem = get_node_or_null("/root/CollapseSystem")
@onready var PersistenceSystem = get_node_or_null("/root/PersistenceSystem")
@onready var AuthoritySystem = get_node_or_null("/root/AuthoritySystem")
@onready var KnowledgeSystem = get_node_or_null("/root/KnowledgeSystem")
@onready var WorldMeaning = get_node_or_null("/root/WorldMeaning")
@onready var WorldMemory = get_node_or_null("/root/WorldMemory")
@onready var GameManager = get_node_or_null("/root/GameManager")

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
	var event_data: Dictionary = {}  # Additional event-specific data
	var tick_occurred: int
	var historical_significance: float = 0.0
	var aftermath_effects: Array[String] = []
	
	func _init(type: String, desc: String, impact: int = 1, data: Dictionary = {}):
		event_type = type
		description = desc
		impact_level = impact
		event_data = data
		tick_occurred = GameManager.tick_count if GameManager else 0

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
## Steady-state detectors (authority low, economy high, …) can stay true for thousands of ticks.
## Gate WorldMemory + settlement broadcasts so we do not append/spam every sim tick.
const EMERGENT_PATTERN_EMIT_COOLDOWN_TICKS: int = 600  # ~1 visual day (SimTime.TICKS_PER_VISUAL_DAY)
var _emergent_pattern_last_emit_tick: Dictionary = {}  # pattern_type -> tick

func _emergent_pattern_emit_gate(pattern_type: String) -> bool:
	if GameManager == null:
		return true
	var now: int = GameManager.tick_count
	var last: int = int(_emergent_pattern_last_emit_tick.get(pattern_type, -1000000000))
	if now - last < EMERGENT_PATTERN_EMIT_COOLDOWN_TICKS:
		return false
	_emergent_pattern_last_emit_tick[pattern_type] = now
	return true
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
const LEARN_EVENTS_PAGE_SIZE: int = 128
const LEARN_MAX_EVENTS_PER_UPDATE: int = 64
const LEARN_EVENT_TICK_WINDOW: int = 1000
var _last_learned_event_eid: int = 0
var _cached_pawn_spawner: WeakRef = null
## One full [method get_pawn_neural_state] resolve per pawn per sim tick (forward + matrix + nudge).
var _pawn_neural_cache_tick: int = -1
var _pawn_neural_cache: Dictionary = {}

func _ready():
	add_to_group("tickable")
	if TickManager != null:
		TickManager.mark_tickable_cache_dirty()
	_initialize_world_state()
	_setup_initial_discoveries()
	_initialize_neural_world_matrix()
	_initialize_neural_networks()


func _on_world_tick(tick_number: int) -> void:
	# Forward tick to all SettlementAI instances
	for settlement_id in active_settlements:
		var settlement_ai = active_settlements[settlement_id]
		if settlement_ai != null and settlement_ai.has_method("_on_world_tick"):
			settlement_ai._on_world_tick(tick_number)

func _world_stream(label: String) -> StringName:
	return StringName("world_ai:%s" % label)

func _world_salt(extra: int = 0) -> int:
	var tick: int = GameManager.tick_count if GameManager != null else 0
	var cycles: int = int(neural_world_matrix.get("evolution_cycles", 0)) if not neural_world_matrix.is_empty() else 0
	return tick + cycles * 1009 + extra

func _deterministic_range(label: String, min_value: float, max_value: float, salt: int = 0) -> float:
	return WorldRNG.range_for(_world_stream(label), min_value, max_value, salt)

func _deterministic_chance(label: String, probability: float, salt: int = 0) -> bool:
	return WorldRNG.chance_for(_world_stream(label), probability, salt)

func _deterministic_index(label: String, size: int, salt: int = 0) -> int:
	return WorldRNG.index_for(_world_stream(label), size, salt)

# === Neural Network Matrix Initialization ===

func _initialize_neural_world_matrix() -> void:
	# Create world-level neural network matrix
	neural_world_matrix = {
		"world_state_neurons": _create_world_state_neurons(),
		"environmental_neurons": _create_environmental_neurons(),
		"civilization_neurons": _create_civilization_neurons(),
		"cultural_neurons": _create_cultural_neurons(),
		"economic_neurons": _create_economic_neurons(),
		"religious_neurons": _create_religious_neurons(),
		# Phase 4 expansions — new neuron groups
		"military_neurons": _create_military_neurons(),
		"technology_neurons": _create_technology_neurons(),
		"migration_neurons": _create_migration_neurons(),
		"weather_neurons": _create_weather_neurons(),
		"trade_neurons": _create_trade_neurons(),
		"social_neurons": _create_social_neurons(),
		"political_neurons": _create_political_neurons(),
		"health_neurons": _create_health_neurons(),
		"infrastructure_neurons": _create_infrastructure_neurons(),
		"agriculture_neurons": _create_agriculture_neurons(),
		"interconnections": _create_neural_interconnections(),
		"learning_rate": neural_evolution_rate,
		"evolution_cycles": 0
	}
	
	if OS.is_debug_build():
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

func _create_religious_neurons() -> Dictionary:
	return {
		"religious_fervor": {"value": 0.0, "activation": 0.0, "connections": []},
		"ritual_complexity": {"value": 0.0, "activation": 0.0, "connections": []},
		"spiritual_authority": {"value": 0.0, "activation": 0.0, "connections": []},
		"belief_diversity": {"value": 0.0, "activation": 0.0, "connections": []},
		"sacred_sites": {"value": 0.0, "activation": 0.0, "connections": []},
		"religious_influence": {"value": 0.0, "activation": 0.0, "connections": []}
	}

# === Phase 4 Expansion: New Neuron Groups ===

func _create_military_neurons() -> Dictionary:
	return {
		"military_strength": {"value": 0.0, "activation": 0.0, "connections": []},
		"combat_experience": {"value": 0.0, "activation": 0.0, "connections": []},
		"tactical_awareness": {"value": 0.0, "activation": 0.0, "connections": []},
		"weapon_quality": {"value": 0.0, "activation": 0.0, "connections": []},
		"morale": {"value": 0.5, "activation": 0.0, "connections": []},
	}

func _create_technology_neurons() -> Dictionary:
	return {
		"innovation_rate": {"value": 0.0, "activation": 0.0, "connections": []},
		"tech_adoption": {"value": 0.0, "activation": 0.0, "connections": []},
		"research_efficiency": {"value": 0.0, "activation": 0.0, "connections": []},
		"tech_diversity": {"value": 0.0, "activation": 0.0, "connections": []},
		"innovation_stagnation": {"value": 0.0, "activation": 0.0, "connections": []},
	}

func _create_migration_neurons() -> Dictionary:
	return {
		"migration_pressure": {"value": 0.0, "activation": 0.0, "connections": []},
		"settlement_capacity": {"value": 0.5, "activation": 0.0, "connections": []},
		"population_growth": {"value": 0.0, "activation": 0.0, "connections": []},
		"migration_success": {"value": 0.5, "activation": 0.0, "connections": []},
		"overcrowding_risk": {"value": 0.0, "activation": 0.0, "connections": []},
	}

func _create_weather_neurons() -> Dictionary:
	return {
		"season_severity": {"value": 0.1, "activation": 0.0, "connections": []},
		"climate_stability": {"value": 0.8, "activation": 0.0, "connections": []},
		"disaster_risk": {"value": 0.05, "activation": 0.0, "connections": []},
		"drought_severity": {"value": 0.0, "activation": 0.0, "connections": []},
		"flood_risk": {"value": 0.0, "activation": 0.0, "connections": []},
	}

func _create_trade_neurons() -> Dictionary:
	return {
		"trade_volume": {"value": 0.0, "activation": 0.0, "connections": []},
		"resource_flow": {"value": 0.0, "activation": 0.0, "connections": []},
		"market_integration": {"value": 0.0, "activation": 0.0, "connections": []},
		"trade_risk": {"value": 0.1, "activation": 0.0, "connections": []},
		"economic_interdependence": {"value": 0.0, "activation": 0.0, "connections": []},
	}

func _create_social_neurons() -> Dictionary:
	return {
		"social_cohesion": {"value": 0.5, "activation": 0.0, "connections": []},
		"class_stratification": {"value": 0.0, "activation": 0.0, "connections": []},
		"cultural_diversity": {"value": 0.3, "activation": 0.0, "connections": []},
		"social_mobility": {"value": 0.5, "activation": 0.0, "connections": []},
		"social_tension": {"value": 0.0, "activation": 0.0, "connections": []},
	}

func _create_political_neurons() -> Dictionary:
	return {
		"political_stability": {"value": 0.7, "activation": 0.0, "connections": []},
		"faction_power": {"value": 0.0, "activation": 0.0, "connections": []},
		"diplomatic_reputation": {"value": 0.5, "activation": 0.0, "connections": []},
		"government_effectiveness": {"value": 0.5, "activation": 0.0, "connections": []},
		"political_polarization": {"value": 0.0, "activation": 0.0, "connections": []},
	}

func _create_health_neurons() -> Dictionary:
	return {
		"public_health": {"value": 0.8, "activation": 0.0, "connections": []},
		"disease_resistance": {"value": 0.7, "activation": 0.0, "connections": []},
		"life_expectancy": {"value": 0.5, "activation": 0.0, "connections": []},
		"sanitation_level": {"value": 0.3, "activation": 0.0, "connections": []},
		"healthcare_access": {"value": 0.0, "activation": 0.0, "connections": []},
	}

func _create_infrastructure_neurons() -> Dictionary:
	return {
		"road_network": {"value": 0.0, "activation": 0.0, "connections": []},
		"irrigation_systems": {"value": 0.0, "activation": 0.0, "connections": []},
		"fortification_level": {"value": 0.0, "activation": 0.0, "connections": []},
		"building_quality": {"value": 0.3, "activation": 0.0, "connections": []},
		"infrastructure_maintenance": {"value": 0.5, "activation": 0.0, "connections": []},
	}

func _create_agriculture_neurons() -> Dictionary:
	return {
		"crop_yield": {"value": 0.3, "activation": 0.0, "connections": []},
		"food_security": {"value": 0.5, "activation": 0.0, "connections": []},
		"agricultural_innovation": {"value": 0.0, "activation": 0.0, "connections": []},
		"soil_health": {"value": 0.7, "activation": 0.0, "connections": []},
		"famine_risk": {"value": 0.0, "activation": 0.0, "connections": []},
	}

func _create_neural_interconnections() -> Dictionary:
	var interconnections: Dictionary = {}
	
	# Create basic interconnections between neural domains
	var connection_types = [
		"civ_to_env", "civ_to_cult", "civ_to_econ", "civ_to_rel",
		"env_to_cult", "cult_to_econ", "env_to_econ", "cult_to_rel",
		"econ_to_rel", "rel_to_cult", "rel_to_civ"
	]
	
	for connection_type in connection_types:
		interconnections[connection_type] = {
			"weight": _deterministic_range("interconnection:%s" % connection_type, -0.3, 0.3),
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
	
	if OS.is_debug_build():
		print("[WorldAI] Specialized neural networks initialized")

func _create_specialized_network(network_type: String, input_size: int, hidden_size: int, output_size: int) -> Dictionary:
	return {
		"type": network_type,
		"layers": {
			"input": {"size": input_size, "neurons": _create_neuron_layer(input_size, "%s:input" % network_type)},
			"hidden": {"size": hidden_size, "neurons": _create_neuron_layer(hidden_size, "%s:hidden" % network_type)},
			"output": {"size": output_size, "neurons": _create_neuron_layer(output_size, "%s:output" % network_type)}
		},
		"weights": _initialize_weights(network_type, input_size, hidden_size, output_size),
		"learning_rate": 0.01,
		"training_history": []
	}

func _create_neuron_layer(size: int, layer_label: String = "layer") -> Array[Dictionary]:
	var layer: Array[Dictionary] = []
	for i in range(size):
		layer.append({
			"id": "neuron_%d" % i,
			"value": 0.0,
			"activation": 0.0,
			"bias": _deterministic_range("bias:%s:%d" % [layer_label, i], -0.1, 0.1)
		})
	return layer

func _initialize_weights(network_type: String, input_size: int, hidden_size: int, output_size: int) -> Dictionary:
	var weights: Dictionary = {}
	
	# Xavier/Glorot initialization for better convergence
	var input_scale = sqrt(2.0 / float(input_size))
	var hidden_scale = sqrt(2.0 / float(hidden_size))
	
	# Input to hidden weights
	weights["input_hidden"] = []
	for i in range(input_size):
		var neuron_weights: Array[float] = []
		for j in range(hidden_size):
			neuron_weights.append(_deterministic_range(
				"weights:%s:input_hidden:%d:%d" % [network_type, i, j],
				-input_scale,
				input_scale
			))
		weights["input_hidden"].append(neuron_weights)
	
	# Hidden to output weights
	weights["hidden_output"] = []
	for i in range(hidden_size):
		var neuron_weights: Array[float] = []
		for j in range(output_size):
			neuron_weights.append(_deterministic_range(
				"weights:%s:hidden_output:%d:%d" % [network_type, i, j],
				-hidden_scale,
				hidden_scale
			))
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
	_generate_neural_network_events()
	_update_technological_progress()
	_update_civilization_development()
	
	# Check collapse risk and trigger emergency behaviors
	_check_collapse_emergency()
	
	# Learn from recent game events
	_learn_from_game_events()
	
	# Process neural network evolution
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


func _learn_from_game_events() -> void:
	if WorldMemory == null or GameManager == null:
		return
	
	# Pull a bounded recent page and only process unseen events by eid.
	var page: Array[Dictionary] = WorldMemory.get_events_page_newest(LEARN_EVENTS_PAGE_SIZE, -1)
	if page.is_empty():
		return
	page.reverse()  # oldest -> newest
	var current_tick: int = int(GameManager.tick_count)
	var processed: int = 0
	var newest_eid_in_page: int = 0
	for event in page:
		var eid: int = int(event.get("eid", 0))
		if eid > newest_eid_in_page:
			newest_eid_in_page = eid
		if eid <= _last_learned_event_eid:
			continue
		var event_tick: int = int(event.get("tick", event.get("t", 0)))
		if event_tick <= current_tick - LEARN_EVENT_TICK_WINDOW:
			_last_learned_event_eid = maxi(_last_learned_event_eid, eid)
			continue
		var event_type: String = str(event.get("type", ""))
		_learn_from_event_type(event_type, event)
		_last_learned_event_eid = maxi(_last_learned_event_eid, eid)
		processed += 1
		if processed >= LEARN_MAX_EVENTS_PER_UPDATE:
			break
	if _last_learned_event_eid <= 0 and newest_eid_in_page > 0:
		_last_learned_event_eid = newest_eid_in_page


func _learn_from_event_type(event_type: String, event: Dictionary) -> void:
	var world_neurons = neural_world_matrix["world_state_neurons"]
	var civ_neurons = neural_world_matrix["civilization_neurons"]
	var cult_neurons = neural_world_matrix["cultural_neurons"]
	var env_neurons = neural_world_matrix["environmental_neurons"]
	
	match event_type:
		"teaching_success":
			# Teaching success strengthens knowledge retention neuron
			cult_neurons["knowledge_retention"].value = clamp(cult_neurons["knowledge_retention"].value + 0.01, 0.0, 1.0)
		"teaching_failure":
			# Teaching failure weakens knowledge retention neuron
			cult_neurons["knowledge_retention"].value = clamp(cult_neurons["knowledge_retention"].value - 0.005, 0.0, 1.0)
		"settlement_collapse":
			# Collapse increases collapse risk neuron
			world_neurons["collapse_risk"].value = clamp(world_neurons["collapse_risk"].value + 0.05, 0.0, 1.0)
		"collapse_stage_transition":
			# Stage transition adjusts collapse risk based on direction
			var to_stage = event.get("to_stage", 0)
			if to_stage > 0:
				world_neurons["collapse_risk"].value = clamp(world_neurons["collapse_risk"].value + 0.02, 0.0, 1.0)
		"knowledge_loss":
			# Knowledge loss increases knowledge scarcity
			cult_neurons["knowledge_scarcity"].value = clamp(cult_neurons["knowledge_scarcity"].value + 0.01, 0.0, 1.0)
		"authority_succession":
			# Succession affects authority stability
			civ_neurons["authority_stability"].value = clamp(civ_neurons["authority_stability"].value + 0.01, 0.0, 1.0)
		"organization_action":
			# Successful organization strengthens governance
			civ_neurons["governance_complexity"].value = clamp(civ_neurons["governance_complexity"].value + 0.005, 0.0, 1.0)
		"pawn_death":
			# Death affects trust and social complexity
			world_neurons["trust_level"].value = clamp(world_neurons["trust_level"].value - 0.005, 0.0, 1.0)
		"entity_visitation":
			# Visitation strengthens historical layering
			env_neurons["historical_layering"].value = clamp(env_neurons["historical_layering"].value + 0.002, 0.0, 1.0)


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
	var squad_boost: float = 0.0
	var sq = get_node_or_null("/root/SquadCoordinator")
	if sq != null:
		squad_boost = clampf(float(sq.active_squad_count) * 0.03, 0.0, 0.15)
	world_neurons["social_complexity"].value = float(active_settlements.size()) / 20.0 + squad_boost
	
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

# === Player Interaction Functions ===

func player_inspect_neuron(neuron_name: String, neuron_layer: String) -> Dictionary:
	if not neural_world_matrix.has(neuron_layer):
		return {"error": "Invalid layer"}
	
	var layer = neural_world_matrix[neuron_layer]
	if not layer.has(neuron_name):
		return {"error": "Invalid neuron"}
	
	var neuron = layer[neuron_name]
	return {
		"name": neuron_name,
		"layer": neuron_layer,
		"value": neuron.value,
		"activation": neuron.activation,
		"connections": neuron.connections.size()
	}


func player_influence_neuron(neuron_name: String, neuron_layer: String, new_value: float) -> bool:
	if not neural_world_matrix.has(neuron_layer):
		return false
	
	var layer = neural_world_matrix[neuron_layer]
	if not layer.has(neuron_name):
		return false
	
	layer[neuron_name].value = clamp(new_value, 0.0, 1.0)
	if GameManager.verbose_logs():
		print("[WorldAI] Player influenced neuron %s in layer %s to %.2f" % [neuron_name, neuron_layer, new_value])
	return true


func player_reset_neural_network() -> void:
	_initialize_neural_world_matrix()
	emergent_patterns.clear()
	if GameManager.verbose_logs():
		print("[WorldAI] Player reset neural network")


func player_trigger_manual_pattern_detection() -> Array[Dictionary]:
	_detect_emergent_patterns()
	var recent_patterns: Array[Dictionary] = []
	for i in range(emergent_patterns.size()):
		if i >= emergent_patterns.size() - 10:
			recent_patterns.append(emergent_patterns[i])
	return recent_patterns


func player_adjust_learning_rate(new_rate: float) -> void:
	neural_evolution_rate = clamp(new_rate, 0.001, 0.1)
	if GameManager.verbose_logs():
		print("[WorldAI] Player adjusted learning rate to %.4f" % neural_evolution_rate)


func player_adjust_pattern_threshold(new_threshold: float) -> void:
	pattern_emergence_threshold = clamp(new_threshold, 0.0, 1.0)
	if GameManager.verbose_logs():
		print("[WorldAI] Player adjusted pattern threshold to %.2f" % pattern_emergence_threshold)


func get_neural_network_summary_string() -> String:
	var summary = "[Neural Network State]\n"
	
	var world_neurons = neural_world_matrix["world_state_neurons"]
	var civ_neurons = neural_world_matrix["civilization_neurons"]
	var cult_neurons = neural_world_matrix["cultural_neurons"]
	var env_neurons = neural_world_matrix["environmental_neurons"]
	
	summary += "World State:\n"
	summary += "  Collapse Risk: %.2f\n" % world_neurons["collapse_risk"].value
	summary += "  Trust Level: %.2f\n" % world_neurons["trust_level"].value
	summary += "  Authority Stability: %.2f\n" % world_neurons["authority_stability"].value
	summary += "  Knowledge Retention: %.2f\n" % world_neurons["knowledge_retention"].value
	
	summary += "Civilization:\n"
	summary += "  Civil Authority: %.2f\n" % civ_neurons["civil_authority"].value
	summary += "  Military Authority: %.2f\n" % civ_neurons["military_authority"].value
	summary += "  Religious Authority: %.2f\n" % civ_neurons["religious_authority"].value
	summary += "  Knowledge Authority: %.2f\n" % civ_neurons["knowledge_authority"].value
	
	summary += "Culture:\n"
	summary += "  Knowledge Distribution: %.2f\n" % cult_neurons["knowledge_distribution"].value
	summary += "  Knowledge Scarcity: %.2f\n" % cult_neurons["knowledge_scarcity"].value
	summary += "  Teaching Activity: %.2f\n" % cult_neurons["teaching_activity"].value
	
	summary += "Environment:\n"
	summary += "  Ruin Density: %.2f\n" % env_neurons["ruin_density"].value
	summary += "  Grave Density: %.2f\n" % env_neurons["grave_density"].value
	summary += "  Historical Layering: %.2f\n" % env_neurons["historical_layering"].value
	
	summary += "Emergent Patterns: %d detected\n" % emergent_patterns.size()
	
	return summary


func get_expansion_priority_weight(expansion_type: String) -> float:
	var env_neurons = neural_world_matrix["environmental_neurons"]
	var ruin_density = env_neurons["ruin_density"].value
	var grave_density = env_neurons["grave_density"].value
	var historical_layering = env_neurons["historical_layering"].value
	
	# Expansion priority based on persistence (ruins, graves, history)
	match expansion_type:
		"ruin_exploration":
			# Prioritize exploring areas with high ruin density
			return ruin_density * 2.0 + historical_layering
		"grave_respect":
			# Prioritize respecting areas with high grave density
			return grave_density * 2.0
		"historical_preservation":
			# Prioritize preserving areas with high historical layering
			return historical_layering * 2.0
		"new_settlement":
			# Prioritize new settlements in areas with low historical layering (clean slate)
			return (1.0 - historical_layering) * 2.0
		"rebuilding":
			# Prioritize rebuilding near ruins
			return ruin_density * 2.5
		_:
			return 1.0


func get_settlement_goal_priority(goal_type: String) -> float:
	var world_neurons = neural_world_matrix["world_state_neurons"]
	var regional_density = world_neurons["regional_meaning_density"].value
	var settlement_depth = world_neurons["settlement_meaning_depth"].value
	
	# Goal priority based on world meaning
	match goal_type:
		"knowledge":
			# Knowledge goals prioritized in regions with deep meaning
			return settlement_depth * 2.0 + regional_density
		"exploration":
			# Exploration prioritized in regions with low meaning density
			return (1.0 - regional_density) * 2.0
		"building":
			# Building prioritized in areas with moderate meaning
			return settlement_depth * 1.5
		"defense":
			# Defense prioritized when meaning is threatened (low depth)
			return (1.0 - settlement_depth) * 1.5
		"trade":
			# Trade prioritized in regions with high meaning density
			return regional_density * 2.0
		_:
			return 1.0


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
	if not neural_world_matrix.has("civilization_neurons"):
		return 1.0
	var civ_neurons: Dictionary = neural_world_matrix["civilization_neurons"]
	if not civ_neurons.has("civil_authority") or not civ_neurons.has("military_authority"):
		return 1.0
	var civil_entry: Variant = civ_neurons["civil_authority"]
	var military_entry: Variant = civ_neurons["military_authority"]
	if not (civil_entry is Dictionary) or not (military_entry is Dictionary):
		return 1.0
	var civil_auth: float = float((civil_entry as Dictionary).get("value", 0.0))
	var military_auth: float = float((military_entry as Dictionary).get("value", 0.0))
	
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
	var pawns: Array[HeelKawnian] = PawnSpawner.find_pawns()
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
	var carrier_count: int = KnowledgeSystem.get_total_carrier_count()
	var total_knowledge: int = KnowledgeSystem.get_total_knowledge_count()
	var pawns: Array[HeelKawnian] = PawnSpawner.find_pawns()
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

func _detect_collapse_warning_patterns() -> void:
	var world_neurons = neural_world_matrix["world_state_neurons"]
	var collapse_risk = world_neurons["collapse_risk"].value
	var trust_level = world_neurons["trust_level"].value
	
	if collapse_risk > 0.6 and trust_level < 0.4:
		if not _emergent_pattern_emit_gate("collapse_warning"):
			return
		var pattern = {
			"type": "collapse_warning",
			"description": "High collapse risk with low trust",
			"severity": "high",
			"tick": GameManager.tick_count
		}
		emergent_patterns.append(pattern)
		WorldMemory.record_event({
			"type": "emergent_pattern_detected",
			"pattern_type": "collapse_warning",
			"description": pattern.description,
			"severity": pattern.severity,
			"tick": GameManager.tick_count
		})
		
		# Dispatch collapse warning event
		var event = WorldEvent.new(
			"collapse_warning",
			"Neural network detects imminent collapse risk: trust is low while collapse risk is high",
			8,
			{"collapse_risk": collapse_risk, "trust_level": trust_level}
		)
		world_events.append(event)
		collapse_warning_event.emit(event)
		world_event_dispatched.emit(event)
		_broadcast_event_to_settlements(event)
		
		if GameManager.verbose_logs():
			print("[WorldAI] Pattern detected: %s" % pattern.description)


func _detect_knowledge_crisis_patterns() -> void:
	var cult_neurons = neural_world_matrix["cultural_neurons"]
	var knowledge_scarcity = cult_neurons["knowledge_scarcity"].value
	var teaching_activity = cult_neurons["teaching_activity"].value
	
	if knowledge_scarcity > 0.7 and teaching_activity < 0.3:
		if not _emergent_pattern_emit_gate("knowledge_crisis"):
			return
		var pattern = {
			"type": "knowledge_crisis",
			"description": "High knowledge scarcity with low teaching activity",
			"severity": "medium",
			"tick": GameManager.tick_count
		}
		emergent_patterns.append(pattern)
		WorldMemory.record_event({
			"type": "emergent_pattern_detected",
			"pattern_type": "knowledge_crisis",
			"description": pattern.description,
			"severity": pattern.severity,
			"tick": GameManager.tick_count
		})
		
		# Dispatch knowledge crisis event
		var event = WorldEvent.new(
			"knowledge_crisis",
			"Neural network detects critical knowledge loss: knowledge is scarce and teaching activity is low",
			6,
			{"knowledge_scarcity": knowledge_scarcity, "teaching_activity": teaching_activity}
		)
		world_events.append(event)
		knowledge_crisis_event.emit(event)
		world_event_dispatched.emit(event)
		_broadcast_event_to_settlements(event)
		
		if GameManager.verbose_logs():
			print("[WorldAI] Pattern detected: %s" % pattern.description)


func _detect_authority_vacuum_patterns() -> void:
	var civ_neurons = neural_world_matrix["civilization_neurons"]
	var civil_auth = civ_neurons["civil_authority"].value
	var military_auth = civ_neurons["military_authority"].value
	
	if civil_auth < 0.3 and military_auth < 0.3:
		if not _emergent_pattern_emit_gate("authority_vacuum"):
			return
		var pattern = {
			"type": "authority_vacuum",
			"description": "Low authority across all contexts",
			"severity": "high",
			"tick": GameManager.tick_count
		}
		emergent_patterns.append(pattern)
		WorldMemory.record_event({
			"type": "emergent_pattern_detected",
			"pattern_type": "authority_vacuum",
			"description": pattern.description,
			"severity": pattern.severity,
			"tick": GameManager.tick_count
		})
		
		# Dispatch authority vacuum event
		var event = WorldEvent.new(
			"authority_vacuum",
			"Neural network detects authority breakdown: both civil and military authority are critically low",
			7,
			{"civil_authority": civil_auth, "military_authority": military_auth}
		)
		world_events.append(event)
		authority_vacuum_event.emit(event)
		world_event_dispatched.emit(event)
		_broadcast_event_to_settlements(event)
		
		if GameManager.verbose_logs():
			print("[WorldAI] Pattern detected: %s" % pattern.description)


func _detect_historical_saturation_patterns() -> void:
	var env_neurons = neural_world_matrix["environmental_neurons"]
	var historical_layering = env_neurons["historical_layering"].value
	var ruin_density = env_neurons["ruin_density"].value
	
	if historical_layering > 0.7 and ruin_density > 0.5:
		if not _emergent_pattern_emit_gate("historical_saturation"):
			return
		var pattern = {
			"type": "historical_saturation",
			"description": "High historical layering with dense ruins",
			"severity": "low",
			"tick": GameManager.tick_count
		}
		emergent_patterns.append(pattern)
		WorldMemory.record_event({
			"type": "emergent_pattern_detected",
			"pattern_type": "historical_saturation",
			"description": pattern.description,
			"severity": pattern.severity,
			"tick": GameManager.tick_count
		})
		
		# Dispatch historical discovery event
		var event = WorldEvent.new(
			"historical_discovery",
			"Neural network identifies significant historical pattern: dense ruins with deep historical layering",
			5,
			{"historical_layering": historical_layering, "ruin_density": ruin_density}
		)
		world_events.append(event)
		historical_discovery_event.emit(event)
		world_event_dispatched.emit(event)
		_broadcast_event_to_settlements(event)
		
		if GameManager.verbose_logs():
			print("[WorldAI] Pattern detected: %s" % pattern.description)


func _detect_environmental_degradation_patterns() -> void:
	var env_neurons = neural_world_matrix["environmental_neurons"]
	var resource_availability = env_neurons.get("resource_availability", {}).get("value", 0.5)
	var resource_depletion = 1.0 - resource_availability
	var ruin_density = env_neurons["ruin_density"].value
	
	if resource_depletion > 0.6 and ruin_density > 0.4:
		if not _emergent_pattern_emit_gate("environmental_degradation"):
			return
		var pattern = {
			"type": "environmental_degradation",
			"description": "High resource depletion with significant ruin density",
			"severity": "medium",
			"tick": GameManager.tick_count
		}
		emergent_patterns.append(pattern)
		WorldMemory.record_event({
			"type": "emergent_pattern_detected",
			"pattern_type": "environmental_degradation",
			"description": pattern.description,
			"severity": pattern.severity,
			"tick": GameManager.tick_count
		})
		
		# Dispatch environmental degradation event
		var event = WorldEvent.new(
			"environmental_degradation",
			"Neural network detects environmental stress: resources are depleted and ruins are spreading",
			6,
			{"resource_depletion": resource_depletion, "ruin_density": ruin_density}
		)
		world_events.append(event)
		environmental_degradation_event.emit(event)
		world_event_dispatched.emit(event)
		_broadcast_event_to_settlements(event)
		
		if GameManager.verbose_logs():
			print("[WorldAI] Pattern detected: %s" % pattern.description)


func _detect_economic_boom_patterns() -> void:
	var econ_neurons = neural_world_matrix["economic_neurons"]
	var production_eff = econ_neurons["production_efficiency"].value
	var econ_stability = econ_neurons["economic_stability"].value
	
	if production_eff > 0.7 and econ_stability > 0.6:
		if not _emergent_pattern_emit_gate("economic_boom"):
			return
		var pattern = {
			"type": "economic_boom",
			"description": "High production efficiency with strong economic stability",
			"severity": "positive",
			"tick": GameManager.tick_count
		}
		emergent_patterns.append(pattern)
		WorldMemory.record_event({
			"type": "emergent_pattern_detected",
			"pattern_type": "economic_boom",
			"description": pattern.description,
			"severity": pattern.severity,
			"tick": GameManager.tick_count
		})
		
		# Dispatch economic boom event
		var event = WorldEvent.new(
			"economic_boom",
			"Neural network detects economic prosperity: production is high and economy is stable",
			5,
			{"production_efficiency": production_eff, "economic_stability": econ_stability}
		)
		world_events.append(event)
		economic_boom_event.emit(event)
		world_event_dispatched.emit(event)
		_broadcast_event_to_settlements(event)
		
		if GameManager.verbose_logs():
			print("[WorldAI] Pattern detected: %s" % pattern.description)


func _detect_market_crash_patterns() -> void:
	var econ_neurons = neural_world_matrix["economic_neurons"]
	var econ_stability = econ_neurons["economic_stability"].value
	var wealth_accum = econ_neurons["wealth_accumulation"].value
	
	if econ_stability < 0.3 and wealth_accum > 0.5:
		if not _emergent_pattern_emit_gate("market_crash"):
			return
		var pattern = {
			"type": "market_crash",
			"description": "Low economic stability with high wealth accumulation indicates bubble burst",
			"severity": "high",
			"tick": GameManager.tick_count
		}
		emergent_patterns.append(pattern)
		WorldMemory.record_event({
			"type": "emergent_pattern_detected",
			"pattern_type": "market_crash",
			"description": pattern.description,
			"severity": pattern.severity,
			"tick": GameManager.tick_count
		})
		
		# Dispatch market crash event
		var event = WorldEvent.new(
			"market_crash",
			"Neural network detects market collapse: economic stability is critically low despite wealth accumulation",
			8,
			{"economic_stability": econ_stability, "wealth_accumulation": wealth_accum}
		)
		world_events.append(event)
		market_crash_event.emit(event)
		world_event_dispatched.emit(event)
		_broadcast_event_to_settlements(event)
		
		if GameManager.verbose_logs():
			print("[WorldAI] Pattern detected: %s" % pattern.description)


func _detect_religious_schism_patterns() -> void:
	var rel_neurons = neural_world_matrix["religious_neurons"]
	var belief_diversity = rel_neurons["belief_diversity"].value
	var religious_fervor = rel_neurons["religious_fervor"].value
	
	if belief_diversity > 0.7 and religious_fervor > 0.6:
		if not _emergent_pattern_emit_gate("religious_schism"):
			return
		var pattern = {
			"type": "religious_schism",
			"description": "High belief diversity with high religious fervor indicates schism risk",
			"severity": "medium",
			"tick": GameManager.tick_count
		}
		emergent_patterns.append(pattern)
		WorldMemory.record_event({
			"type": "emergent_pattern_detected",
			"pattern_type": "religious_schism",
			"description": pattern.description,
			"severity": pattern.severity,
			"tick": GameManager.tick_count
		})
		
		# Dispatch religious schism event
		var event = WorldEvent.new(
			"religious_schism",
			"Neural network detects religious schism: diverse beliefs with high fervor create division",
			6,
			{"belief_diversity": belief_diversity, "religious_fervor": religious_fervor}
		)
		world_events.append(event)
		religious_schism_event.emit(event)
		world_event_dispatched.emit(event)
		_broadcast_event_to_settlements(event)
		
		if GameManager.verbose_logs():
			print("[WorldAI] Pattern detected: %s" % pattern.description)


func _detect_religious_conversion_patterns() -> void:
	var rel_neurons = neural_world_matrix["religious_neurons"]
	var religious_influence = rel_neurons["religious_influence"].value
	var ritual_complexity = rel_neurons["ritual_complexity"].value
	
	if religious_influence > 0.6 and ritual_complexity > 0.5:
		if not _emergent_pattern_emit_gate("religious_conversion"):
			return
		var pattern = {
			"type": "religious_conversion",
			"description": "High religious influence with complex rituals attracts converts",
			"severity": "positive",
			"tick": GameManager.tick_count
		}
		emergent_patterns.append(pattern)
		WorldMemory.record_event({
			"type": "emergent_pattern_detected",
			"pattern_type": "religious_conversion",
			"description": pattern.description,
			"severity": pattern.severity,
			"tick": GameManager.tick_count
		})
		
		# Dispatch religious conversion event
		var event = WorldEvent.new(
			"religious_conversion",
			"Neural network detects religious conversion: strong influence and complex rituals attract new believers",
			5,
			{"religious_influence": religious_influence, "ritual_complexity": ritual_complexity}
		)
		world_events.append(event)
		religious_conversion_event.emit(event)
		world_event_dispatched.emit(event)
		_broadcast_event_to_settlements(event)
		
		if GameManager.verbose_logs():
			print("[WorldAI] Pattern detected: %s" % pattern.description)


func _broadcast_event_to_settlements(event: WorldEvent) -> void:
	# Broadcast event to all active settlements
	for settlement_id in active_settlements:
		var settlement = active_settlements[settlement_id]
		if settlement == null:
			continue
		
		# Call appropriate event handler based on event type
		match event.event_type:
			"collapse_warning":
				if settlement.has_method("handle_collapse_warning_event"):
					settlement.handle_collapse_warning_event(event.event_data)
			"knowledge_crisis":
				if settlement.has_method("handle_knowledge_crisis_event"):
					settlement.handle_knowledge_crisis_event(event.event_data)
			"authority_vacuum":
				if settlement.has_method("handle_authority_vacuum_event"):
					settlement.handle_authority_vacuum_event(event.event_data)
			"historical_discovery":
				if settlement.has_method("handle_historical_discovery_event"):
					settlement.handle_historical_discovery_event(event.event_data)
			"environmental_degradation":
				if settlement.has_method("handle_environmental_degradation_event"):
					settlement.handle_environmental_degradation_event(event.event_data)
			"economic_boom":
				if settlement.has_method("handle_economic_boom_event"):
					settlement.handle_economic_boom_event(event.event_data)
			"market_crash":
				if settlement.has_method("handle_market_crash_event"):
					settlement.handle_market_crash_event(event.event_data)
			"religious_schism":
				if settlement.has_method("handle_religious_schism_event"):
					settlement.handle_religious_schism_event(event.event_data)
			"religious_conversion":
				if settlement.has_method("handle_religious_conversion_event"):
					settlement.handle_religious_conversion_event(event.event_data)


# === Knowledge System Integration ===

func on_knowledge_lost(knowledge_type: int) -> void:
	# Called when a knowledge type is completely lost (no carriers remain)
	var cult_neurons = neural_world_matrix["cultural_neurons"]
	
	# Increase knowledge scarcity neuron
	cult_neurons["knowledge_scarcity"].value = min(cult_neurons["knowledge_scarcity"].value + 0.15, 1.0)
	
	# Decrease teaching activity neuron
	cult_neurons["teaching_activity"].value = max(cult_neurons["teaching_activity"].value - 0.1, 0.0)
	
	# Record event
	WorldMemory.record_event({
		"type": "knowledge_lost",
		"knowledge_type": knowledge_type,
		"tick": GameManager.tick_count
	})
	
	if GameManager.verbose_logs():
		print("[WorldAI] Knowledge type %d lost - updating neural network" % knowledge_type)


func on_knowledge_at_risk(knowledge_type: int, carrier_count: int) -> void:
	# Called when a knowledge type has few carriers (at risk of loss)
	var cult_neurons = neural_world_matrix["cultural_neurons"]
	
	# Slightly increase knowledge scarcity neuron
	cult_neurons["knowledge_scarcity"].value = min(cult_neurons["knowledge_scarcity"].value + 0.05, 1.0)
	
	# Record event
	WorldMemory.record_event({
		"type": "knowledge_at_risk",
		"knowledge_type": knowledge_type,
		"carrier_count": carrier_count,
		"tick": GameManager.tick_count
	})
	
	if GameManager.verbose_logs():
		print("[WorldAI] Knowledge type %d at risk (carriers: %d) - updating neural network" % [knowledge_type, carrier_count])


func on_entity_decay(entity_id: int, entity_type: int, condition: float) -> void:
	# Called when an entity's material condition decays significantly
	var env_neurons = neural_world_matrix["environmental_neurons"]
	
	# Increase ruin density if entity is a ruin or grave
	if entity_type in [0, 1]:  # RUIN or GRAVE_FIELD
		env_neurons["ruin_density"].value = min(env_neurons["ruin_density"].value + 0.02, 1.0)
	
	# Record event
	WorldMemory.record_event({
		"type": "entity_decay",
		"entity_id": entity_id,
		"entity_type": entity_type,
		"condition": condition,
		"tick": GameManager.tick_count
	})
	
	if GameManager.verbose_logs():
		print("[WorldAI] Entity %d decayed to condition %.2f - updating neural network" % [entity_id, condition])


func on_entity_loss(entity_id: int, entity_type: int) -> void:
	# Called when an entity is completely lost (removed from world)
	var env_neurons = neural_world_matrix["environmental_neurons"]
	
	# Decrease ruin density if entity was a ruin or grave
	if entity_type in [0, 1]:  # RUIN or GRAVE_FIELD
		env_neurons["ruin_density"].value = max(env_neurons["ruin_density"].value - 0.03, 0.0)
	
	# Record event
	WorldMemory.record_event({
		"type": "entity_loss",
		"entity_id": entity_id,
		"entity_type": entity_type,
		"tick": GameManager.tick_count
	})
	
	if GameManager.verbose_logs():
		print("[WorldAI] Entity %d lost - updating neural network" % entity_id)


func on_authority_change(pawn_id: int, context: int, new_level: float) -> void:
	# Called when authority level changes for a pawn
	var civ_neurons = neural_world_matrix["civilization_neurons"]
	
	# Update appropriate authority neuron based on context
	match context:
		0:  # MILITARY
			civ_neurons["military_authority"].value = _update_authority_average(civ_neurons["military_authority"].value, new_level)
		1:  # CIVIL
			civ_neurons["civil_authority"].value = _update_authority_average(civ_neurons["civil_authority"].value, new_level)
		2:  # RELIGIOUS
			civ_neurons["religious_authority"].value = _update_authority_average(civ_neurons["religious_authority"].value, new_level)
		3:  # KNOWLEDGE
			civ_neurons["knowledge_authority"].value = _update_authority_average(civ_neurons["knowledge_authority"].value, new_level)
	
	# Record event
	WorldMemory.record_event({
		"type": "authority_change",
		"pawn_id": pawn_id,
		"context": context,
		"new_level": new_level,
		"tick": GameManager.tick_count
	})
	
	if GameManager.verbose_logs():
		print("[WorldAI] Authority changed for pawn %d context %d to %.2f - updating neural network" % [pawn_id, context, new_level])


func _update_authority_average(current_avg: float, new_value: float) -> float:
	# Smoothly update authority average (exponential moving average)
	return current_avg * 0.95 + new_value * 0.05


func get_neural_network_summary() -> Dictionary:
	# Return a summary of neural network state for UI display
	var summary: Dictionary = {}

	# World state neurons
	var world_neurons = neural_world_matrix.get("world_state_neurons", {})
	summary["collapse_risk"] = world_neurons.get("collapse_risk", {}).get("value", 0.0)
	summary["trust_level"] = world_neurons.get("trust_level", {}).get("value", 0.0)
	summary["technological_progress"] = world_neurons.get("technological_progress", {}).get("value", 0.0)
	summary["social_complexity"] = world_neurons.get("social_complexity", {}).get("value", 0.0)

	# Civilization neurons
	var civ_neurons = neural_world_matrix.get("civilization_neurons", {})
	summary["civil_authority"] = civ_neurons.get("civil_authority", {}).get("value", 0.0)
	summary["military_authority"] = civ_neurons.get("military_authority", {}).get("value", 0.0)
	summary["religious_authority"] = civ_neurons.get("religious_authority", {}).get("value", 0.0)
	summary["knowledge_authority"] = civ_neurons.get("knowledge_authority", {}).get("value", 0.0)
	summary["governance_complexity"] = civ_neurons.get("governance_complexity", {}).get("value", 0.0)

	# Cultural neurons
	var cult_neurons = neural_world_matrix.get("cultural_neurons", {})
	summary["knowledge_scarcity"] = cult_neurons.get("knowledge_scarcity", {}).get("value", 0.0)
	summary["teaching_activity"] = cult_neurons.get("teaching_activity", {}).get("value", 0.0)
	summary["cultural_coherence"] = cult_neurons.get("cultural_coherence", {}).get("value", 0.0)

	# Environmental neurons
	var env_neurons = neural_world_matrix.get("environmental_neurons", {})
	summary["ruin_density"] = env_neurons.get("ruin_density", {}).get("value", 0.0)
	summary["resource_depletion"] = env_neurons.get("resource_depletion", {}).get("value", 0.0)
	summary["historical_layering"] = env_neurons.get("historical_layering", {}).get("value", 0.0)
	summary["environmental_health"] = env_neurons.get("environmental_health", {}).get("value", 0.0)

	# Economic neurons
	var econ_neurons = neural_world_matrix.get("economic_neurons", {})
	summary["production_efficiency"] = econ_neurons.get("production_efficiency", {}).get("value", 0.0)
	summary["economic_stability"] = econ_neurons.get("economic_stability", {}).get("value", 0.0)
	summary["labor_specialization"] = econ_neurons.get("labor_specialization", {}).get("value", 0.0)

	# Religious neurons
	var rel_neurons = neural_world_matrix.get("religious_neurons", {})
	summary["religious_fervor"] = rel_neurons.get("religious_fervor", {}).get("value", 0.0)
	summary["religious_influence"] = rel_neurons.get("religious_influence", {}).get("value", 0.0)
	summary["ritual_complexity"] = rel_neurons.get("ritual_complexity", {}).get("value", 0.0)

	# === Phase 4 Expansion: New Neuron Groups ===

	# Military neurons
	var mil_neurons = neural_world_matrix.get("military_neurons", {})
	summary["military_strength"] = mil_neurons.get("military_strength", {}).get("value", 0.0)
	summary["combat_experience"] = mil_neurons.get("combat_experience", {}).get("value", 0.0)
	summary["tactical_awareness"] = mil_neurons.get("tactical_awareness", {}).get("value", 0.0)
	summary["weapon_quality"] = mil_neurons.get("weapon_quality", {}).get("value", 0.0)
	summary["morale"] = mil_neurons.get("morale", {}).get("value", 0.5)

	# Technology neurons
	var tech_neurons = neural_world_matrix.get("technology_neurons", {})
	summary["innovation_rate"] = tech_neurons.get("innovation_rate", {}).get("value", 0.0)
	summary["tech_adoption"] = tech_neurons.get("tech_adoption", {}).get("value", 0.0)
	summary["research_efficiency"] = tech_neurons.get("research_efficiency", {}).get("value", 0.0)
	summary["tech_diversity"] = tech_neurons.get("tech_diversity", {}).get("value", 0.0)
	summary["innovation_stagnation"] = tech_neurons.get("innovation_stagnation", {}).get("value", 0.0)

	# Migration neurons
	var mig_neurons = neural_world_matrix.get("migration_neurons", {})
	summary["migration_pressure"] = mig_neurons.get("migration_pressure", {}).get("value", 0.0)
	summary["settlement_capacity"] = mig_neurons.get("settlement_capacity", {}).get("value", 0.5)
	summary["population_growth"] = mig_neurons.get("population_growth", {}).get("value", 0.0)
	summary["migration_success"] = mig_neurons.get("migration_success", {}).get("value", 0.5)
	summary["overcrowding_risk"] = mig_neurons.get("overcrowding_risk", {}).get("value", 0.0)

	# Weather/Environment neurons
	var weather_neurons = neural_world_matrix.get("weather_neurons", {})
	summary["season_severity"] = weather_neurons.get("season_severity", {}).get("value", 0.1)
	summary["climate_stability"] = weather_neurons.get("climate_stability", {}).get("value", 0.8)
	summary["disaster_risk"] = weather_neurons.get("disaster_risk", {}).get("value", 0.05)
	summary["drought_severity"] = weather_neurons.get("drought_severity", {}).get("value", 0.0)
	summary["flood_risk"] = weather_neurons.get("flood_risk", {}).get("value", 0.0)

	# Trade neurons
	var trade_neurons = neural_world_matrix.get("trade_neurons", {})
	summary["trade_volume"] = trade_neurons.get("trade_volume", {}).get("value", 0.0)
	summary["resource_flow"] = trade_neurons.get("resource_flow", {}).get("value", 0.0)
	summary["market_integration"] = trade_neurons.get("market_integration", {}).get("value", 0.0)
	summary["trade_risk"] = trade_neurons.get("trade_risk", {}).get("value", 0.1)
	summary["economic_interdependence"] = trade_neurons.get("economic_interdependence", {}).get("value", 0.0)

	# Social neurons
	var social_neurons = neural_world_matrix.get("social_neurons", {})
	summary["social_cohesion"] = social_neurons.get("social_cohesion", {}).get("value", 0.5)
	summary["class_stratification"] = social_neurons.get("class_stratification", {}).get("value", 0.0)
	summary["cultural_diversity"] = social_neurons.get("cultural_diversity", {}).get("value", 0.3)
	summary["social_mobility"] = social_neurons.get("social_mobility", {}).get("value", 0.5)
	summary["social_tension"] = social_neurons.get("social_tension", {}).get("value", 0.0)

	# Political neurons
	var pol_neurons = neural_world_matrix.get("political_neurons", {})
	summary["political_stability"] = pol_neurons.get("political_stability", {}).get("value", 0.7)
	summary["faction_power"] = pol_neurons.get("faction_power", {}).get("value", 0.0)
	summary["diplomatic_reputation"] = pol_neurons.get("diplomatic_reputation", {}).get("value", 0.5)
	summary["government_effectiveness"] = pol_neurons.get("government_effectiveness", {}).get("value", 0.5)
	summary["political_polarization"] = pol_neurons.get("political_polarization", {}).get("value", 0.0)

	# Health neurons
	var health_neurons = neural_world_matrix.get("health_neurons", {})
	summary["public_health"] = health_neurons.get("public_health", {}).get("value", 0.8)
	summary["disease_resistance"] = health_neurons.get("disease_resistance", {}).get("value", 0.7)
	# DORMANT WORLD: Disease resistance is 1.0 (immune) until era 1
	if DiscoveryGate != null and not DiscoveryGate.is_unlocked("era_1"):
		summary["disease_resistance"] = 1.0
	summary["life_expectancy"] = health_neurons.get("life_expectancy", {}).get("value", 0.5)
	summary["sanitation_level"] = health_neurons.get("sanitation_level", {}).get("value", 0.3)
	summary["healthcare_access"] = health_neurons.get("healthcare_access", {}).get("value", 0.0)

	# Infrastructure neurons
	var infra_neurons = neural_world_matrix.get("infrastructure_neurons", {})
	summary["road_network"] = infra_neurons.get("road_network", {}).get("value", 0.0)
	summary["irrigation_systems"] = infra_neurons.get("irrigation_systems", {}).get("value", 0.0)
	summary["fortification_level"] = infra_neurons.get("fortification_level", {}).get("value", 0.0)
	summary["building_quality"] = infra_neurons.get("building_quality", {}).get("value", 0.3)
	summary["infrastructure_maintenance"] = infra_neurons.get("infrastructure_maintenance", {}).get("value", 0.5)

	# Agriculture neurons
	var ag_neurons = neural_world_matrix.get("agriculture_neurons", {})
	summary["crop_yield"] = ag_neurons.get("crop_yield", {}).get("value", 0.3)
	summary["food_security"] = ag_neurons.get("food_security", {}).get("value", 0.5)
	summary["agricultural_innovation"] = ag_neurons.get("agricultural_innovation", {}).get("value", 0.0)
	summary["soil_health"] = ag_neurons.get("soil_health", {}).get("value", 0.7)
	summary["famine_risk"] = ag_neurons.get("famine_risk", {}).get("value", 0.0)
	# DORMANT WORLD: Famine risk is 0 (immune) until era 1
	if DiscoveryGate != null and not DiscoveryGate.is_unlocked("era_1"):
		summary["famine_risk"] = 0.0

	return summary


# === Neural Network Persistence ===

func save_neural_network_state() -> Dictionary:
	# Serialize neural network state for saving
	var save_data: Dictionary = {
		"world_state_neurons": _serialize_neuron_group(neural_world_matrix.get("world_state_neurons", {})),
		"civilization_neurons": _serialize_neuron_group(neural_world_matrix.get("civilization_neurons", {})),
		"cultural_neurons": _serialize_neuron_group(neural_world_matrix.get("cultural_neurons", {})),
		"environmental_neurons": _serialize_neuron_group(neural_world_matrix.get("environmental_neurons", {})),
		"economic_neurons": _serialize_neuron_group(neural_world_matrix.get("economic_neurons", {})),
		"religious_neurons": _serialize_neuron_group(neural_world_matrix.get("religious_neurons", {})),
		"evolution_cycles": neural_world_matrix.get("evolution_cycles", 0),
		"emergent_patterns": emergent_patterns.duplicate(true),
		"world_events": _serialize_world_events()
	}
	
	return save_data


func load_neural_network_state(save_data: Dictionary) -> void:
	# Deserialize neural network state from save data
	if save_data.has("world_state_neurons"):
		_deserialize_neuron_group(neural_world_matrix["world_state_neurons"], save_data["world_state_neurons"])
	
	if save_data.has("civilization_neurons"):
		_deserialize_neuron_group(neural_world_matrix["civilization_neurons"], save_data["civilization_neurons"])
	
	if save_data.has("cultural_neurons"):
		_deserialize_neuron_group(neural_world_matrix["cultural_neurons"], save_data["cultural_neurons"])
	
	if save_data.has("environmental_neurons"):
		_deserialize_neuron_group(neural_world_matrix["environmental_neurons"], save_data["environmental_neurons"])
	
	if save_data.has("economic_neurons"):
		_deserialize_neuron_group(neural_world_matrix["economic_neurons"], save_data["economic_neurons"])
	
	if save_data.has("religious_neurons"):
		_deserialize_neuron_group(neural_world_matrix["religious_neurons"], save_data["religious_neurons"])
	
	if save_data.has("evolution_cycles"):
		neural_world_matrix["evolution_cycles"] = save_data["evolution_cycles"]
	
	if save_data.has("emergent_patterns"):
		emergent_patterns = save_data["emergent_patterns"]
	
	if save_data.has("world_events"):
		_deserialize_world_events(save_data["world_events"])
	
	if GameManager.verbose_logs():
		print("[WorldAI] Neural network state loaded from save data")


func _serialize_neuron_group(neurons: Dictionary) -> Dictionary:
	var serialized: Dictionary = {}
	for neuron_name in neurons:
		var neuron = neurons[neuron_name]
		serialized[neuron_name] = {
			"value": neuron.get("value", 0.0),
			"activation": neuron.get("activation", 0.0),
			"decay_rate": neuron.get("decay_rate", 0.01)
		}
	return serialized


func _deserialize_neuron_group(neurons: Dictionary, serialized: Dictionary) -> void:
	for neuron_name in serialized:
		if neurons.has(neuron_name):
			var data = serialized[neuron_name]
			neurons[neuron_name]["value"] = data.get("value", 0.0)
			neurons[neuron_name]["activation"] = data.get("activation", 0.0)
			neurons[neuron_name]["decay_rate"] = data.get("decay_rate", 0.01)


func _serialize_world_events() -> Array:
	var serialized: Array = []
	for event in world_events:
		serialized.append({
			"event_type": event.event_type,
			"description": event.description,
			"impact_level": event.impact_level,
			"event_data": event.event_data,
			"tick_occurred": event.tick_occurred
		})
	return serialized


func _deserialize_world_events(serialized: Array) -> void:
	world_events.clear()
	for event_data in serialized:
		var event = WorldEvent.new(
			event_data.get("event_type", ""),
			event_data.get("description", ""),
			event_data.get("impact_level", 1),
			event_data.get("event_data", {})
		)
		event.tick_occurred = event_data.get("tick_occurred", 0)
		world_events.append(event)


func _detect_emergent_patterns() -> void:
	# Analyze neural network activity for emergent patterns
	var current_state = _get_current_neural_state()
	var pattern_score = _calculate_pattern_emergence()
	
	# Detect specific patterns based on neuron combinations
	_detect_collapse_warning_patterns()
	_detect_knowledge_crisis_patterns()
	_detect_authority_vacuum_patterns()
	_detect_historical_saturation_patterns()
	_detect_environmental_degradation_patterns()
	_detect_economic_boom_patterns()
	_detect_market_crash_patterns()
	_detect_religious_schism_patterns()
	_detect_religious_conversion_patterns()
	
	# Apply pattern persistence - detected patterns influence future neural weights
	_apply_pattern_persistence()
	
	if pattern_score >= pattern_emergence_threshold:
		var new_pattern = _create_emergent_pattern()
		emergent_patterns.append(new_pattern)
		_apply_emergent_pattern_effects(new_pattern)

func _apply_pattern_persistence() -> void:
	# Apply detected patterns to influence future neural weights
	# Patterns that occur frequently become "hardwired" into the neural network
	var pattern_weights: Dictionary = {
		"collapse_warning": {"collapse_risk": 0.02, "trust_level": -0.01},
		"knowledge_crisis": {"knowledge_scarcity": 0.02, "teaching_activity": -0.01},
		"authority_vacuum": {"civil_authority": -0.01, "military_authority": -0.01},
		"historical_discovery": {"historical_layering": 0.01, "ruin_density": 0.01},
		"environmental_degradation": {"resource_depletion": 0.02, "ruin_density": 0.01}
	}
	
	# Count pattern occurrences
	var pattern_counts: Dictionary = {}
	for pattern in emergent_patterns:
		var pattern_type = pattern.get("type", "")
		pattern_counts[pattern_type] = pattern_counts.get(pattern_type, 0) + 1
	
	# Apply weight adjustments based on pattern frequency
	for pattern_type in pattern_counts:
		var count = pattern_counts[pattern_type]
		if count >= 3:  # Only apply if pattern has occurred at least 3 times
			var weight_adjustments = pattern_weights.get(pattern_type, {})
			var influence_strength = min(count * 0.005, 0.05)  # Cap at 5% influence
			
			for neuron_name in weight_adjustments:
				var adjustment = weight_adjustments[neuron_name] * influence_strength
				_apply_neuron_weight_adjustment(neuron_name, adjustment)
	
	if GameManager.verbose_logs() and pattern_counts.size() > 0:
		print("[WorldAI] Applied pattern persistence for %d pattern types" % pattern_counts.size())


func _apply_neuron_weight_adjustment(neuron_name: String, adjustment: float) -> void:
	# Apply weight adjustment to specific neuron across all neuron groups
	var neuron_groups = ["world_state_neurons", "civilization_neurons", "cultural_neurons", "environmental_neurons", "economic_neurons", "religious_neurons"]
	
	for group_name in neuron_groups:
		var group = neural_world_matrix.get(group_name, {})
		if group.has(neuron_name):
			var neuron = group[neuron_name]
			neuron["value"] = clamp(neuron["value"] + adjustment, 0.0, 1.0)


func on_job_completed(job_type: int, job_priority: int) -> void:
	# Called when a job is completed - updates economic neurons
	var econ_neurons = neural_world_matrix.get("economic_neurons", {})
	
	# Increase production efficiency based on job completions
	econ_neurons["production_efficiency"].value = min(econ_neurons["production_efficiency"].value + 0.005, 1.0)
	
	# Increase economic stability based on high-priority job completions
	if job_priority >= 70:
		econ_neurons["economic_stability"].value = min(econ_neurons["economic_stability"].value + 0.01, 1.0)
	
	# Increase labor specialization based on job type diversity
	econ_neurons["labor_specialization"].value = min(econ_neurons["labor_specialization"].value + 0.003, 1.0)
	
	# Record event
	WorldMemory.record_event({
		"type": "job_completed",
		"job_type": job_type,
		"job_priority": job_priority,
		"tick": GameManager.tick_count
	})
	
	if GameManager.verbose_logs():
		print("[WorldAI] Job completed type %d priority %d - updating economic neurons" % [job_type, job_priority])


func on_sacred_site_established(settlement_id: int, location: Vector2i) -> void:
	# Called when a settlement establishes a sacred site
	var rel_neurons = neural_world_matrix.get("religious_neurons", {})
	
	# Increase sacred sites neuron
	rel_neurons["sacred_sites"].value = min(rel_neurons["sacred_sites"].value + 0.05, 1.0)
	
	# Increase religious influence
	rel_neurons["religious_influence"].value = min(rel_neurons["religious_influence"].value + 0.03, 1.0)
	
	# Record event
	WorldMemory.record_event({
		"type": "sacred_site_established",
		"settlement_id": settlement_id,
		"location": location,
		"tick": GameManager.tick_count
	})
	
	if GameManager.verbose_logs():
		print("[WorldAI] Sacred site established by settlement %d at %s - updating religious neurons" % [settlement_id, str(location)])


func on_ritual_performed(settlement_id: int, ritual_type: String, participants: int) -> void:
	# Called when a settlement performs a religious ritual
	var rel_neurons = neural_world_matrix.get("religious_neurons", {})
	
	# Increase religious fervor based on participant count
	var fervor_increase = min(participants * 0.01, 0.1)
	rel_neurons["religious_fervor"].value = min(rel_neurons["religious_fervor"].value + fervor_increase, 1.0)
	
	# Increase ritual complexity based on participant count
	if participants > 5:
		rel_neurons["ritual_complexity"].value = min(rel_neurons["ritual_complexity"].value + 0.02, 1.0)
	
	# Increase spiritual authority
	rel_neurons["spiritual_authority"].value = min(rel_neurons["spiritual_authority"].value + 0.01, 1.0)
	
	# Record event
	WorldMemory.record_event({
		"type": "ritual_performed",
		"settlement_id": settlement_id,
		"ritual_type": ritual_type,
		"participants": participants,
		"tick": GameManager.tick_count
	})
	
	if GameManager.verbose_logs():
		print("[WorldAI] Ritual %s performed by settlement %d with %d participants - updating religious neurons" % [ritual_type, settlement_id, participants])


func on_collapse_metric_change(settlement_id: int, metric_name: String, new_value: float) -> void:
	# Called when collapse metrics change - updates collapse risk neuron
	var world_neurons = neural_world_matrix.get("world_state_neurons", {})
	
	# Update appropriate neuron based on metric name
	match metric_name:
		"trust_level":
			world_neurons["trust_level"].value = new_value
		"authority_stability":
			world_neurons["authority_stability"].value = new_value
		"knowledge_retention":
			world_neurons["knowledge_retention"].value = new_value
		"environmental_health":
			world_neurons["environmental_health"].value = new_value
	
	# Update collapse risk based on average of all metrics
	var trust = world_neurons.get("trust_level", {}).get("value", 1.0)
	var authority = world_neurons.get("authority_stability", {}).get("value", 1.0)
	var knowledge = world_neurons.get("knowledge_retention", {}).get("value", 1.0)
	var environment = world_neurons.get("environmental_health", {}).get("value", 1.0)
	
	var avg_stability = (trust + authority + knowledge + environment) / 4.0
	world_neurons["collapse_risk"].value = 1.0 - avg_stability
	
	# Train neural network from this event
	_train_neural_network_from_event("collapse_metric_change", {"metric_name": metric_name, "new_value": new_value})
	
	# Record event
	WorldMemory.record_event({
		"type": "collapse_metric_change",
		"settlement_id": settlement_id,
		"metric_name": metric_name,
		"new_value": new_value,
		"collapse_risk": world_neurons["collapse_risk"].value,
		"tick": GameManager.tick_count
	})
	
	if GameManager.verbose_logs():
		print("[WorldAI] Collapse metric %s changed to %.2f for settlement %d - collapse risk now %.2f" % [metric_name, new_value, settlement_id, world_neurons["collapse_risk"].value])


func _train_neural_network_from_event(event_type: String, event_data: Dictionary) -> void:
	# Train neural network based on event outcomes
	# This implements reinforcement learning: adjust weights based on event success/failure
	
	var learning_rate = neural_world_matrix.get("learning_rate", 0.005)
	var world_neurons = neural_world_matrix.get("world_state_neurons", {})
	var civ_neurons = neural_world_matrix.get("civilization_neurons", {})
	var cult_neurons = neural_world_matrix.get("cultural_neurons", {})
	var env_neurons = neural_world_matrix.get("environmental_neurons", {})
	var econ_neurons = neural_world_matrix.get("economic_neurons", {})
	var rel_neurons = neural_world_matrix.get("religious_neurons", {})
	
	match event_type:
		"job_completed":
			# Job completion is positive - reinforce economic neurons
			econ_neurons["production_efficiency"].value = min(econ_neurons["production_efficiency"].value + learning_rate * 0.5, 1.0)
			econ_neurons["labor_specialization"].value = min(econ_neurons["labor_specialization"].value + learning_rate * 0.3, 1.0)
		
		"collapse_metric_change":
			# Collapse metric changes provide feedback on stability
			var metric_name = event_data.get("metric_name", "")
			var new_value = event_data.get("new_value", 0.5)
			
			# If metric improved (increased), reinforce stability
			if new_value > 0.5:
				world_neurons["trust_level"].value = min(world_neurons["trust_level"].value + learning_rate * 0.2, 1.0)
			# If metric declined, increase collapse risk awareness
			else:
				world_neurons["collapse_risk"].value = min(world_neurons["collapse_risk"].value + learning_rate * 0.3, 1.0)
		
		"sacred_site_established":
			# Sacred site establishment is positive - reinforce religious neurons
			rel_neurons["sacred_sites"].value = min(rel_neurons["sacred_sites"].value + learning_rate * 0.4, 1.0)
			rel_neurons["religious_influence"].value = min(rel_neurons["religious_influence"].value + learning_rate * 0.3, 1.0)
		
		"ritual_performed":
			# Ritual performance is positive - reinforce religious neurons
			rel_neurons["ritual_complexity"].value = min(rel_neurons["ritual_complexity"].value + learning_rate * 0.2, 1.0)
			rel_neurons["religious_fervor"].value = min(rel_neurons["religious_fervor"].value + learning_rate * 0.3, 1.0)
		
		"knowledge_lost":
			# Knowledge loss is negative - increase knowledge scarcity awareness
			cult_neurons["knowledge_scarcity"].value = min(cult_neurons["knowledge_scarcity"].value + learning_rate * 0.5, 1.0)
			cult_neurons["teaching_activity"].value = min(cult_neurons["teaching_activity"].value + learning_rate * 0.4, 1.0)
		
		"authority_change":
			# Authority changes provide feedback on governance
			var new_level = event_data.get("new_level", 0.5)
			if new_level > 0.5:
				civ_neurons["civil_authority"].value = min(civ_neurons["civil_authority"].value + learning_rate * 0.2, 1.0)
		
		"entity_decay":
			# Entity decay is negative - increase environmental awareness
			env_neurons["ruin_density"].value = min(env_neurons["ruin_density"].value + learning_rate * 0.3, 1.0)
		
		"entity_loss":
			# Entity loss is negative - increase historical awareness
			env_neurons["historical_layering"].value = min(env_neurons["historical_layering"].value + learning_rate * 0.2, 1.0)
	
	if GameManager.verbose_logs():
		print("[WorldAI] Neural network trained from event: %s" % event_type)


func predict_collapse_stage(settlement_id: int) -> int:
	# Predict collapse stage based on neural network state
	# Returns: 0=STABLE, 1=TRUST_DECAY, 2=AUTHORITY_DECAY, 3=KNOWLEDGE_DECAY, 4=ENVIRONMENTAL_DECAY, 5=COLLAPSED
	
	var summary = get_neural_network_summary()
	var collapse_risk = summary.get("collapse_risk", 0.0)
	var trust_level = summary.get("trust_level", 1.0)
	var civil_authority = summary.get("civil_authority", 1.0)
	var knowledge_scarcity = summary.get("knowledge_scarcity", 0.0)
	var resource_depletion = summary.get("resource_depletion", 0.0)
	
	# Calculate stage based on neural network state
	if collapse_risk < 0.2:
		return 0  # STABLE
	elif trust_level < 0.6:
		return 1  # TRUST_DECAY
	elif civil_authority < 0.5:
		return 2  # AUTHORITY_DECAY
	elif knowledge_scarcity > 0.6:
		return 3  # KNOWLEDGE_DECAY
	elif resource_depletion > 0.7:
		return 4  # ENVIRONMENTAL_DECAY
	else:
		return 5  # COLLAPSED


func get_collapse_stage_name(stage: int) -> String:
	match stage:
		0: return "STABLE"
		1: return "TRUST_DECAY"
		2: return "AUTHORITY_DECAY"
		3: return "KNOWLEDGE_DECAY"
		4: return "ENVIRONMENTAL_DECAY"
		5: return "COLLAPSED"
		_: return "UNKNOWN"


func _deterministic_succession_jitter(candidate_id: int, government_type: String) -> float:
	var seed_text: String = "%s:%d" % [government_type, candidate_id]
	var h: int = abs(seed_text.hash())
	return float(h % 1000) / 10000.0


func rank_succession_candidates(candidate_ids: Array[int], government_type: String) -> Array[int]:
	# Rank succession candidates based on neural network state and government type
	# Returns sorted array of candidate IDs from highest to lowest score
	
	var summary = get_neural_network_summary()
	var ranked_candidates: Array[Dictionary] = []
	
	for candidate_id in candidate_ids:
		var score: float = 0.0
		
		# Base score from neural network state
		match government_type:
			"MONARCHY":
				# Monarchies value civil authority and military authority
				score += summary.get("civil_authority", 0.0) * 0.4
				score += summary.get("military_authority", 0.0) * 0.3
				score += summary.get("trust_level", 0.0) * 0.3
			
			"THEOCRACY":
				# Theocracies value religious authority and spiritual authority
				score += summary.get("religious_authority", 0.0) * 0.5
				score += summary.get("religious_fervor", 0.0) * 0.3
				score += summary.get("trust_level", 0.0) * 0.2
			
			"TECHNOCRACY":
				# Technocracies value knowledge authority and teaching activity
				score += summary.get("knowledge_authority", 0.0) * 0.5
				score += summary.get("teaching_activity", 0.0) * 0.3
				score += summary.get("production_efficiency", 0.0) * 0.2
			
			"REPUBLIC":
				# Republics value civil authority and trust
				score += summary.get("civil_authority", 0.0) * 0.4
				score += summary.get("trust_level", 0.0) * 0.4
				score += summary.get("teaching_activity", 0.0) * 0.2
			
			"TRIBAL":
				# Tribes value military authority and trust
				score += summary.get("military_authority", 0.0) * 0.4
				score += summary.get("trust_level", 0.0) * 0.4
				score += summary.get("religious_fervor", 0.0) * 0.2
			
			_:
				# Default: balanced approach
				score += summary.get("civil_authority", 0.0) * 0.25
				score += summary.get("military_authority", 0.0) * 0.25
				score += summary.get("religious_authority", 0.0) * 0.25
				score += summary.get("knowledge_authority", 0.0) * 0.25
		
		# Stable tie-breaker: variety without non-replayable global RNG.
		score += _deterministic_succession_jitter(candidate_id, government_type)
		
		ranked_candidates.append({
			"candidate_id": candidate_id,
			"score": score
		})
	
	# Sort by score descending
	ranked_candidates.sort_custom(func(a, b): return a.score > b.score)
	
	# Return sorted candidate IDs
	var sorted_ids: Array[int] = []
	for candidate in ranked_candidates:
		sorted_ids.append(candidate.candidate_id)
	
	return sorted_ids


func calculate_diplomatic_modifier(settlement_a_id: int, settlement_b_id: int) -> float:
	# Calculate diplomatic relationship modifier based on neural network state
	# Returns: -1.0 (hostile) to 1.0 (friendly)
	
	var summary = get_neural_network_summary()
	var modifier: float = 0.0
	
	# Base modifier from trust level
	modifier += summary.get("trust_level", 0.5) * 0.3
	
	# Economic stability promotes trade and friendly relations
	modifier += summary.get("economic_stability", 0.5) * 0.2
	
	# Religious similarity (if both have high religious fervor, they may be allies or rivals)
	var religious_fervor = summary.get("religious_fervor", 0.0)
	if religious_fervor > 0.6:
		# High religious fervor can lead to both cooperation and conflict
		# Use belief diversity to determine direction
		var belief_diversity = summary.get("belief_diversity", 0.0)
		if belief_diversity < 0.3:
			modifier += 0.15  # Similar beliefs promote cooperation
		else:
			modifier -= 0.15  # Diverse beliefs may cause tension
	
	# Civil authority promotes diplomacy
	modifier += summary.get("civil_authority", 0.5) * 0.15
	
	# Knowledge sharing promotes cooperation
	modifier += summary.get("teaching_activity", 0.5) * 0.1
	
	# Collapse risk makes settlements more isolationist
	var collapse_risk = summary.get("collapse_risk", 0.0)
	if collapse_risk > 0.5:
		modifier -= 0.2  # High collapse risk reduces diplomatic openness
	
	# Military authority can indicate either defensive or aggressive posture
	var military_authority = summary.get("military_authority", 0.0)
	if military_authority > 0.7:
		modifier -= 0.1  # High military authority may be perceived as threatening
	
	return clamp(modifier, -1.0, 1.0)


func get_diplomatic_attitude(modifier: float) -> String:
	# Get diplomatic attitude string based on modifier
	if modifier >= 0.7:
		return "ALLIED"
	elif modifier >= 0.4:
		return "FRIENDLY"
	elif modifier >= 0.1:
		return "NEUTRAL"
	elif modifier >= -0.3:
		return "CAUTIOUS"
	elif modifier >= -0.6:
		return "HOSTILE"
	else:
		return "WAR"


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
		
		var adaptation = _calculate_weight_adaptation(str(connection_id))
		connection["weight"] += learning_rate * adaptation
		connection["weight"] = clamp(connection["weight"], -1.0, 1.0)

func _mutate_neural_structures() -> void:
	# Occasionally mutate neural structures for evolution
	if _deterministic_chance("mutate_neural_structures", neural_evolution_rate, _world_salt(17)):
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

func _generate_neural_network_events() -> void:
	var world_neurons = neural_world_matrix["world_state_neurons"]
	var civ_neurons = neural_world_matrix["civilization_neurons"]
	var cult_neurons = neural_world_matrix["cultural_neurons"]
	var env_neurons = neural_world_matrix["environmental_neurons"]
	
	# Generate events based on neural network state
	var collapse_risk = world_neurons["collapse_risk"].value
	var knowledge_scarcity = cult_neurons["knowledge_scarcity"].value
	var authority_stability = civ_neurons.get("authority_stability", {}).get("value", 1.0)
	var historical_layering = env_neurons.get("historical_layering", {}).get("value", 0.0)
	
	# Generate collapse warning event
	if collapse_risk > 0.8:
		var event = WorldEvent.new(
			"collapse_warning",
			"Neural network detects imminent collapse risk",
			8
		)
		world_events.append(event)
		if GameManager.verbose_logs():
			print("[WorldAI] Generated event: collapse_warning")
	
	# Generate knowledge crisis event
	if knowledge_scarcity > 0.8:
		var event = WorldEvent.new(
			"knowledge_crisis",
			"Neural network detects critical knowledge loss",
			6
		)
		world_events.append(event)
		if GameManager.verbose_logs():
			print("[WorldAI] Generated event: knowledge_crisis")
	
	# Generate authority crisis event
	if authority_stability < 0.3:
		var event = WorldEvent.new(
			"authority_crisis",
			"Neural network detects authority breakdown",
			7
		)
		world_events.append(event)
		if GameManager.verbose_logs():
			print("[WorldAI] Generated event: authority_crisis")
	
	# Generate historical discovery event
	if historical_layering > 0.8:
		var event = WorldEvent.new(
			"historical_discovery",
			"Neural network identifies significant historical pattern",
			5
		)
		world_events.append(event)
		if GameManager.verbose_logs():
			print("[WorldAI] Generated event: historical_discovery")


func _check_for_world_events() -> void:
	# Check for potential world events based on current conditions
	var event_probability = _calculate_event_probability()
	
	if _deterministic_chance("world_event_roll", event_probability, _world_salt(23)):
		_generate_world_event()

func _update_technological_progress() -> void:
	# Update technological progress based on neural network analysis
	var tech_input = _extract_technological_input()
	var tech_output = _forward_propagate_network(tech_input, technological_neural_network)
	
	# Check for new discoveries
	if _deterministic_chance("tech_discovery_roll", tech_output["discovery_probability"], _world_salt(29)):
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
	for s_any in settlements:
		if not s_any is Dictionary:
			continue
		var s: Dictionary = s_any as Dictionary
		if str(s.get("state", "")) == "active":
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
	organization += _soul_society_martial_settlement_pressure() * 0.25
	
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
	infrastructure += _soul_society_martial_settlement_pressure() * 0.12
	
	return clamp(infrastructure, 0.0, 1.0)


func _soul_society_martial_settlement_pressure() -> float:
	var sm = get_node_or_null("/root/SettlementMemory")
	if sm == null or not sm.has_method("get_settlements"):
		return 0.0
	var arr: Array = sm.get_settlements()
	if arr.is_empty():
		return 0.0
	var martial_n: int = 0
	for st_any in arr:
		if not (st_any is Dictionary):
			continue
		var st: Dictionary = st_any as Dictionary
		var tags_v: Variant = st.get("cultural_tags", [])
		if tags_v is Array:
			for t in tags_v:
				if str(t) == "Martial":
					martial_n += 1
					break
	return float(martial_n) / float(arr.size())

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
	var network_type: String = str(network.get("type", "generic"))
	
	# Simple forward propagation simulation
	var hidden_layer: Array[float] = []
	for i in range(32):  # Hidden layer size
		var sum = 0.0
		for j in range(min(input.size(), 64)):
			sum += input[j] * _deterministic_range(
				"forward:%s:%d:%d" % [network_type, i, j],
				-1.0,
				1.0
			)
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

func _calculate_weight_adaptation(connection_id: String = "") -> float:
	var adaptation = 0.0
	
	adaptation += _deterministic_range("weight_adaptation:%s" % connection_id, -0.1, 0.1, _world_salt(37))
	adaptation += (civilization_complexity - 0.5) * 0.05
	adaptation += (environmental_stability - 0.5) * 0.05
	
	return clamp(adaptation, -0.2, 0.2)

func _mutate_random_connection() -> void:
	var connections = []
	for connection_id in neural_world_matrix["interconnections"]:
		connections.append(connection_id)
	
	if connections.size() > 0:
		var random_connection = connections[_deterministic_index("mutate_connection_pick", connections.size(), _world_salt(41))]
		var connection = neural_world_matrix["interconnections"][random_connection]
		connection["weight"] += _deterministic_range(
			"mutate_connection_delta:%s" % str(random_connection),
			-0.1,
			0.1,
			_world_salt(43)
		)
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
	# DORMANT WORLD: Plague only after era 2, famine only after era 1
	if DiscoveryGate != null:
		if not DiscoveryGate.is_unlocked("era_2"):
			event_types.erase("plague")
		if not DiscoveryGate.is_unlocked("era_1"):
			event_types.erase("famine")
	if event_types.is_empty():
		return
	var event_type = event_types[_deterministic_index("world_event_type", event_types.size(), _world_salt(47))]
	var description = _generate_event_description(event_type)
	var impact = _deterministic_index("world_event_impact", 5, _world_salt(53)) + 1
	
	var event = WorldEvent.new(event_type, description, impact)
	world_events.append(event)

func _generate_technological_discovery() -> void:
	var discovery_names = [
		"Advanced Tools", "Agriculture", "Writing", "Metallurgy", 
		"Mathematics", "Astronomy", "Medicine", "Engineering"
	]
	var name = discovery_names[_deterministic_index("tech_discovery_name", discovery_names.size(), _world_salt(59))]
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
	return types[_deterministic_index("emergent_pattern_type", types.size(), _world_salt(61))]

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
		signature.append(_deterministic_range("neural_signature:%d" % i, -1.0, 1.0, _world_salt(67)))
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

func _pawn_decision_rule_matrix() -> RefCounted:
	if _pawn_decision_rule_evaluator == null:
		_pawn_decision_rule_evaluator = _PAWN_DECISION_RULES.new()
	return _pawn_decision_rule_evaluator


func get_pawn_neural_state(pawn_id: int) -> Dictionary:
	var sp: PawnSpawner = _resolve_pawn_spawner_for_world_ai()
	if sp == null:
		return {}
	var pd: HeelKawnianData = sp.pawn_data_for_id(pawn_id)
	if pd == null:
		return {}
	var tick_now: int = GameManager.tick_count if GameManager != null else 0
	if _pawn_neural_cache_tick != tick_now:
		_pawn_neural_cache.clear()
		_pawn_neural_cache_tick = tick_now
	if _pawn_neural_cache.has(pawn_id):
		return _pawn_neural_cache[pawn_id]
	pd.ensure_soul_identity()
	var inputs: Array[float] = _pawn_neural_input_vector(pd)
	var outputs_full: Array[float] = []
	if pd.neural_network != null and pd.neural_network.has_method("forward_propagate"):
		outputs_full = pd.neural_network.forward_propagate(inputs)
	if outputs_full.is_empty():
		return {"inputs": inputs, "outputs": [], "soul_id": pd.unique_id}
	var outs: Array = []
	var nslice: int = mini(8, outputs_full.size())
	for i in range(nslice):
		outs.append(outputs_full[i])
	var rule_ctx: Dictionary = _pawn_decision_rule_context(pd)
	var rule_pack: Variant = _pawn_decision_rule_matrix().evaluate(pd, rule_ctx, outs)
	var decision_rules: Array = []
	var human_channels: Array = []
	if rule_pack is Dictionary:
		decision_rules = rule_pack.get("fired", [])
		human_channels = rule_pack.get("human_channels", [])
	else:
		decision_rules = rule_pack as Array
	_apply_soul_society_output_nudge(pd, outs)
	var result: Dictionary = {
		"inputs": inputs,
		"outputs": outs,
		"soul_id": pd.unique_id,
		"scar_count": pd.physical_scars.size(),
		"self_preservation_bias": _estimate_self_preservation_bias(outs),
		"decision_rules": decision_rules,
		"decision_ctx": rule_ctx,
		"human_channels": human_channels,
		"human_channel_labels": _PAWN_DECISION_RULES.HUMAN_CHANNEL_LABELS,
	}
	_pawn_neural_cache[pawn_id] = result
	return result


func _estimate_self_preservation_bias(outs: Array) -> float:
	if outs.size() < 8:
		return 0.0
	return clampf(float(outs[1]) + float(outs[7]) * 0.5 - float(outs[5]) * 0.25, 0.0, 1.0)


func _apply_soul_society_output_nudge(pd: HeelKawnianData, outs: Array) -> void:
	if outs.size() < 8:
		return
	var scar_n: float = clampf(float(pd.physical_scars.size()) * 0.14, 0.0, 0.55)
	outs[1] = clampf(float(outs[1]) + scar_n * 0.35, 0.0, 2.0)
	outs[7] = clampf(float(outs[7]) + scar_n * 0.22, 0.0, 2.0)
	outs[5] = clampf(float(outs[5]) - scar_n * 0.28, 0.0, 2.0)
	outs[3] = clampf(float(outs[3]) - scar_n * 0.12, 0.0, 2.0)
	var martial: float = _pawn_martial_settlement_context(pd)
	if martial > 0.0:
		outs[4] = clampf(float(outs[4]) + martial * 0.18, 0.0, 2.0)
		outs[6] = clampf(float(outs[6]) + martial * 0.22, 0.0, 2.0)
		outs[5] = clampf(float(outs[5]) + martial * 0.08, 0.0, 2.0)


## Deterministic weather band for environment + matrix (not a full weather sim).
func get_weather_tag_for_sim() -> String:
	return _weather_tag_for_tick()


func _weather_tag_for_tick() -> String:
	var tick: int = GameManager.tick_count if GameManager != null else 0
	var seed: int = WorldRNG.current_seed()
	var phase: int = posmod(int(tick / 280) + seed % 97, 6)
	var gust: float = WorldRNG.range_for(StringName("weather_gust_band"), 0.0, 1.0, tick / 180)
	var night: bool = DayNightCycle.is_night_for_tick(tick)
	match phase:
		0, 1:
			return "storm" if night and gust > 0.62 else "clear"
		2:
			return "overcast"
		3, 4:
			return "rain" if gust > 0.35 else "overcast"
		_:
			return "gusty"


## Maps neural + human-intent channels to the same idle-action utilities NPCs and incarnated players use.
func build_idle_parity_context_for_pawn(pawn_id: int) -> Dictionary:
	var ns: Dictionary = get_pawn_neural_state(pawn_id)
	if ns.is_empty():
		return {}
	var outs: Array = ns.get("outputs", [])
	var hc: Array = ns.get("human_channels", [])
	var dc: Dictionary = ns.get("decision_ctx", {})
	var ub: Dictionary = {
		"work": 0.28,
		"wander": 0.22,
		"teach": 0.18,
		"challenge": 0.12,
		"forage": 0.14,
	}
	if outs.size() >= 8:
		ub["work"] += float(outs[4]) * 0.22 + float(outs[5]) * 0.22 + float(outs[3]) * 0.14
		ub["wander"] += float(outs[7]) * 0.26 + float(outs[3]) * 0.07
		ub["teach"] += float(outs[2]) * 0.34
		ub["challenge"] += float(outs[6]) * 0.24
		ub["forage"] += float(outs[0]) * 0.11 + float(outs[3]) * 0.28
	if hc.size() >= 12:
		ub["teach"] += float(hc[9]) * 0.28 + float(hc[8]) * 0.10
		ub["wander"] += float(hc[11]) * 0.22
		ub["challenge"] += float(hc[6]) * 0.12
		ub["work"] += float(hc[4]) * 0.09 + float(hc[5]) * 0.09
		ub["forage"] += float(hc[3]) * 0.10
	return {
		"utility_bias": ub,
		"weather": str(dc.get("weather_tag", "clear")),
	}


func _pawn_decision_rule_context(pd: HeelKawnianData) -> Dictionary:
	var tick: int = GameManager.tick_count if GameManager != null else 0
	var founding: float = clampf(
			1.0 - float(tick) / float(_pawn_decision_rule_matrix().FOUNDING_PERIOD_TICKS),
			0.0,
			1.0,
	)
	var food_u: int = 999
	if StockpileManager != null:
		food_u = StockpileManager.total_food()
	var food_p: float = 0.0
	if ColonySimServices != null:
		food_p = ColonySimServices.get_food_pressure()
	var tr: Dictionary = pd.top_social_rapport_peer()
	var top_r: int = int(tr.get("score", 0))
	var top_rapport_peer: int = int(tr.get("peer_id", -1))
	if top_rapport_peer < 0:
		top_r = 0
	var to_op: Dictionary = pd.top_character_opinion_peer()
	var top_o: int = int(to_op.get("opinion", 0))
	var top_op_peer: int = int(to_op.get("peer_id", -1))
	if top_op_peer < 0:
		top_o = 0
	var carrying_food: bool = false
	if pd.is_carrying():
		carrying_food = Item.is_food(pd.carrying)
	var rk_ctx: int = WorldMemory._region_key(pd.tile_pos.x, pd.tile_pos.y)
	var danger_hint: float = clampf(float(WorldPersistence.get_region_scar_level(rk_ctx)) / 3.0, 0.0, 1.0)
	return {
		"tick": tick,
		"founding_blend": founding,
		"hunger": pd.hunger,
		"rest": pd.rest,
		"mood": pd.mood,
		"health": pd.health,
		"max_health": pd.max_health,
		"pain": pd.pain,
		"food_stockpile_units": food_u,
		"food_pressure": food_p,
		"scar_count": pd.physical_scars.size(),
		"crisis_level": pd.get_crisis_level(),
		"children_count": pd.children_count,
		"settlement_id": pd.settlement_id,
		"martial_settlement": _pawn_martial_settlement_context(pd),
		"top_rapport_score": top_r,
		"top_opinion_score": top_o,
		"top_opinion_peer_id": top_op_peer,
		"extraversion": pd.extraversion,
		"openness": pd.openness,
		"agreeableness": pd.agreeableness,
		"neuroticism": pd.neuroticism,
		"conscientiousness": pd.conscientiousness,
		"weather_tag": _weather_tag_for_tick(),
		"danger_level_hint": danger_hint,
		"meaning_danger": _pawn_meaning_danger(rk_ctx),
		"meaning_safety": _pawn_meaning_safety(rk_ctx),
		"meaning_hunger": _pawn_meaning_hunger(rk_ctx),
		"meaning_knowledge": _pawn_meaning_knowledge(rk_ctx),
		"meaning_custom": _pawn_meaning_custom(rk_ctx),
		"meaning_craft": _pawn_meaning_craft(rk_ctx),
		"meaning_authority": _pawn_meaning_authority(rk_ctx),
		"meaning_trade": _pawn_meaning_trade(rk_ctx),
		"meaning_conflict": _pawn_meaning_conflict(rk_ctx),
		"meaning_legacy": _pawn_meaning_legacy(rk_ctx),
		"meaning_culture": _pawn_meaning_culture(rk_ctx),
		"knowledge_at_risk": _pawn_knowledge_at_risk(pd),
		"teaching_obligation": _pawn_teaching_obligation(pd),
		"diaspora_exile": 1.0 if pd._diaspora_origin >= 0 else 0.0,
		"affinity_combat": float(pd.affinities.get("combat", 0.5)),
		"affinity_farming": float(pd.affinities.get("farming", 0.5)),
		"affinity_building": float(pd.affinities.get("building", 0.5)),
		"affinity_crafting": float(pd.affinities.get("crafting", 0.5)),
		"affinity_diplomacy": float(pd.affinities.get("diplomacy", 0.5)),
		"is_carrying": pd.is_carrying(),
		"carrying_food": carrying_food,
		"work_forage": pd.work_forage,
		"work_mine": pd.work_mine,
		"work_build": pd.work_build,
		"work_hunt": pd.work_hunt,
		"profession_overrep": _pawn_profession_overrep(pd),
		# PawnConsciousness — trauma, awareness, dreams, beliefs
		"trauma_level": _pawn_consciousness_trauma(pd),
		"parental_trauma_level": _pawn_parental_trauma(pd),
		"self_awareness": _pawn_consciousness_awareness(pd),
		"recent_dream_theme": _pawn_consciousness_dream_theme(pd),
		"dream_nudge_action": _pawn_consciousness_dream_nudge_action(pd),
		"dream_nudge_target": _pawn_consciousness_dream_nudge_target(pd),
		"core_beliefs_count": _pawn_consciousness_beliefs_count(pd),
		# GrudgeManager — grudge intensity
		"grudge_intensity": _pawn_grudge_intensity(pd),
		# HeelKawnianMind — composed mind snapshot fields
		"mind_pursuit": _pawn_mind_pursuit(pd),
		"mind_emotional_pressure": _pawn_mind_emotional(pd),
		"mind_place_feeling": _pawn_mind_place_feeling(pd),
		"mind_culture_tradition": _pawn_mind_culture(pd),
		"mind_reputation": _pawn_mind_reputation(pd),
		# HeelKawnianMind — knowledge, war, settlement
		"mind_knowledge_count": _pawn_mind_knowledge_count(pd),
		"mind_knowledge_at_risk": _pawn_mind_knowledge_at_risk(pd),
		"mind_conflict_count": _pawn_mind_conflict_count(pd),
		# Combat rank from AICombatProgression
		"combat_rank": _pawn_combat_rank(pd),
		# Warrior threat level from AICombatProgression
		"warrior_threat": _pawn_warrior_threat(pd),
	}


func _pawn_martial_settlement_context(pd: HeelKawnianData) -> float:
	if pd.settlement_id < 0:
		return 0.0
	var sm: Node = get_node_or_null("/root/SettlementMemory")
	if sm == null or not sm.has_method("get_settlements"):
		return 0.0
	var arr: Array = sm.get_settlements()
	if pd.settlement_id >= arr.size():
		return 0.0
	var st_v: Variant = arr[pd.settlement_id]
	if not (st_v is Dictionary):
		return 0.0
	var tags: Variant = (st_v as Dictionary).get("cultural_tags", [])
	if tags is Array:
		for t in tags:
			if str(t) == "Martial":
				return 1.0
	return 0.0


## Returns true if the pawn's profession is overrepresented (>40% of same-settlement pawns share it).
func _pawn_profession_overrep(pd: HeelKawnianData) -> bool:
	if pd.current_profession == HeelKawnianData.Profession.NONE:
		return false
	var sp: PawnSpawner = _resolve_pawn_spawner_for_world_ai()
	if sp == null:
		return false
	var total: int = 0
	var same_prof: int = 0
	for p in sp.pawns:
		if p == null or not is_instance_valid(p):
			continue
		if p.data == null:
			continue
		if p.data.settlement_id != pd.settlement_id:
			continue
		total += 1
		if p.data.current_profession == pd.current_profession:
			same_prof += 1
	if total < 3:
		return false
	return float(same_prof) / float(total) >= 0.4


# ==================== PawnConsciousness context helpers ====================

func _pawn_consciousness_trauma(pd: HeelKawnianData) -> float:
	var pc: Node = get_node_or_null("/root/PawnConsciousness")
	if pc == null or not pc.has_method("get_trauma_level"):
		return 0.0
	return pc.get_trauma_level(int(pd.id))

func _pawn_parental_trauma(pd: HeelKawnianData) -> float:
	if pd == null:
		return 0.0
	var weights_v: Variant = pd.get("parental_trauma_weights") if pd.has_method("get") else null
	if weights_v is not Dictionary:
		return 0.0
	var weights: Dictionary = weights_v as Dictionary
	if weights.is_empty():
		return 0.0
	var total: float = 0.0
	var count: int = 0
	for k in weights.keys():
		total += float(weights.get(k, 0.0))
		count += 1
	if count <= 0:
		return 0.0
	return clampf(total / float(count), 0.0, 100.0)

func _pawn_consciousness_awareness(pd: HeelKawnianData) -> int:
	var pc: Node = get_node_or_null("/root/PawnConsciousness")
	if pc == null or not pc.has_method("get_awareness_level"):
		return 0
	return pc.get_awareness_level(int(pd.id))

func _pawn_consciousness_dream_theme(pd: HeelKawnianData) -> String:
	var pc: Node = get_node_or_null("/root/PawnConsciousness")
	if pc == null or not pc.has_method("get_dreams"):
		return ""
	var dreams: Array = pc.get_dreams(int(pd.id), 1)
	if dreams.is_empty():
		return ""
	return str(dreams[0].get("theme", ""))

func _pawn_consciousness_dream_nudge(pd: HeelKawnianData) -> Dictionary:
	var pc: Node = get_node_or_null("/root/PawnConsciousness")
	if pc == null or not pc.has_method("get_dream_nudge"):
		return {}
	var nudge_v: Variant = pc.get_dream_nudge(int(pd.id))
	return nudge_v if nudge_v is Dictionary else {}

func _pawn_consciousness_dream_nudge_action(pd: HeelKawnianData) -> String:
	var nudge: Dictionary = _pawn_consciousness_dream_nudge(pd)
	return str(nudge.get("action", ""))

func _pawn_consciousness_dream_nudge_target(pd: HeelKawnianData) -> String:
	var nudge: Dictionary = _pawn_consciousness_dream_nudge(pd)
	return str(nudge.get("target", ""))

func _pawn_consciousness_beliefs_count(pd: HeelKawnianData) -> int:
	var pc: Node = get_node_or_null("/root/PawnConsciousness")
	if pc == null or not pc.has_method("get_core_beliefs"):
		return 0
	return pc.get_core_beliefs(int(pd.id)).size()

func _pawn_grudge_intensity(pd: HeelKawnianData) -> float:
	var gm: Node = get_node_or_null("/root/GrudgeManager")
	if gm == null or not gm.has_method("get_grudges_held_by"):
		return 0.0
	var grudges: Array = gm.get_grudges_held_by(int(pd.id))
	var total: float = 0.0
	for g in grudges:
		total += float(g.get("intensity", 0.0))
	return minf(total, 2.0)  # Cap at 2.0 for rule matrix


# ==================== HeelKawnianMind context helpers ====================

func _pawn_mind_pursuit(pd: HeelKawnianData) -> String:
	var hm: Node = get_node_or_null("/root/HeelKawnianMind")
	if hm == null:
		return ""
	var pawn: Variant = _resolve_pawn_for_data(pd)
	if pawn == null:
		return ""
	var snapshot: Dictionary = hm.compute_mind_snapshot(pawn)
	return str(snapshot.get("pursuit", ""))


func _pawn_mind_emotional(pd: HeelKawnianData) -> String:
	var hm: Node = get_node_or_null("/root/HeelKawnianMind")
	if hm == null:
		return ""
	var pawn: Variant = _resolve_pawn_for_data(pd)
	if pawn == null:
		return ""
	var snapshot: Dictionary = hm.compute_mind_snapshot(pawn)
	return str(snapshot.get("emotional_pressure", ""))


func _pawn_mind_place_feeling(pd: HeelKawnianData) -> String:
	var hm: Node = get_node_or_null("/root/HeelKawnianMind")
	if hm == null:
		return ""
	var pawn: Variant = _resolve_pawn_for_data(pd)
	if pawn == null:
		return ""
	# Read meaning tags directly for efficiency
	var rk: int = WorldMemory._region_key(pd.tile_pos.x, pd.tile_pos.y)
	var tags: PackedStringArray = WorldMeaning.get_region_tags(rk)
	for tag in tags:
		match tag:
			"dangerous", "death", "blood":
				return "dangerous"
			"sacred":
				return "sacred"
			"home", "settlement", "hearth":
				return "home"
			"wild", "untamed":
				return "wild"
			"abandoned", "ruin":
				return "haunted"
	return ""


func _pawn_mind_culture(pd: HeelKawnianData) -> String:
	if pd.settlement_id < 0:
		return ""
	var cm: Node = get_node_or_null("/root/CulturalMemory")
	if cm == null or not cm.has_method("get_tradition"):
		return ""
	var tradition: Dictionary = cm.get_tradition(pd.settlement_id)
	if tradition.is_empty():
		return ""
	return str(tradition.get("type", ""))


func _pawn_mind_reputation(pd: HeelKawnianData) -> float:
	var gm: Node = get_node_or_null("/root/GossipManager")
	if gm == null or not gm.has_method("get_reputation_for"):
		return 0.0
	return gm.get_reputation_for(int(pd.id))


func _resolve_pawn_for_data(pd: HeelKawnianData) -> Variant:
	var sp: PawnSpawner = _resolve_pawn_spawner_for_world_ai()
	if sp == null or not sp.has_method("get_pawn_by_id"):
		return null
	return sp.get_pawn_by_id(int(pd.id))


func _pawn_mind_knowledge_count(pd: HeelKawnianData) -> int:
	var ks: Node = get_node_or_null("/root/KnowledgeSystem")
	if ks == null or not ks.has_method("get_pawn_knowledge"):
		return 0
	return ks.get_pawn_knowledge(int(pd.id)).size()


func _pawn_mind_knowledge_at_risk(pd: HeelKawnianData) -> bool:
	var ks: Node = get_node_or_null("/root/KnowledgeSystem")
	if ks == null or not ks.has_method("get_pawn_knowledge"):
		return false
	var known: Array = ks.get_pawn_knowledge(int(pd.id))
	for kt in known:
		if ks.has_method("get_carrier_count"):
			if ks.get_carrier_count(int(kt)) <= 1:
				return true
	return false


func _pawn_mind_conflict_count(pd: HeelKawnianData) -> int:
	var gm: Node = get_node_or_null("/root/GrudgeManager")
	if gm == null or not gm.has_method("get_grudges_held_by"):
		return 0
	return gm.get_grudges_held_by(int(pd.id)).size()


## Returns combat rank from AICombatProgression (0=NOBODY..5=GENERAL)
func _pawn_combat_rank(pd: HeelKawnianData) -> int:
	if AICombatProgression != null and AICombatProgression.has_method("get_rank_for_pawn"):
		return AICombatProgression.get_rank_for_pawn(int(pd.id))
	return pd.military_rank


## Returns warrior threat level from AICombatProgression
func _pawn_warrior_threat(pd: HeelKawnianData) -> String:
	if AICombatProgression != null and AICombatProgression.has_method("get_threat_level"):
		return AICombatProgression.get_threat_level(int(pd.id))
	return ""


## Returns 0.0-1.0 danger level from WorldMeaning tags (repeated_death, blood_soaked, graveyard, famine_stricken, fire_prone, ruined, ancient/old myth tags).
func _pawn_meaning_danger(region_key: int) -> float:
	var tags: PackedStringArray = WorldMeaning.get_region_tags(region_key)
	var danger: float = 0.0
	for tag in tags:
		match tag:
			"repeated_death":
				danger += 0.2
			"blood_soaked":
				danger += 0.3
			"graveyard":
				danger += 0.4
			"famine_stricken":
				danger += 0.25
			"fire_prone":
				danger += 0.15
			"ruined":
				danger += 0.1
			"cursed":
				danger += 0.35
			# Myth formation: ancient danger is feared more
			"old_death_place":
				danger += 0.35
			"ancient_death_place":
				danger += 0.5
			"old_famine":
				danger += 0.3
			"ancient_famine":
				danger += 0.45
			# Ritual Echo: burial groves carry residual danger memory
			"burial_grove":
				danger += 0.1
			# New conflict/injury tags amplify danger
			"war_torn":
				danger += 0.35
			"grudge_haunted":
				danger += 0.15
			"dangerous_ground":
				danger += 0.25
			"blood_stained":
				danger += 0.1
			"war_echo":
				danger += 0.2
			"old_battleground":
				danger += 0.25
			"ancient_battleground":
				danger += 0.4
	return clampf(danger, 0.0, 1.0)


## Returns 0.0-1.0 safety level from WorldMeaning tags (safe_hearth, fertile, learned, welcoming, ancient/old myth tags).
func _pawn_meaning_safety(region_key: int) -> float:
	var tags: PackedStringArray = WorldMeaning.get_region_tags(region_key)
	var safety: float = 0.0
	for tag in tags:
		match tag:
			"safe_hearth":
				safety += 0.4
			"fertile":
				safety += 0.2
			"learned":
				safety += 0.15
			"welcoming":
				safety += 0.1
			"educated":
				safety += 0.1
			"resilient":
				safety += 0.2
			# Myth formation: ancient safety is revered more
			"old_heart":
				safety += 0.3
			"ancient_heart":
				safety += 0.5
			# Ritual Echo: customs create safety (community bonds)
			"teaching_ground":
				safety += 0.15
			"feast_ground":
				safety += 0.1
			"gathering_place":
				safety += 0.15
			"builder_yard":
				safety += 0.05
			# New culture/trade/craft tags amplify safety
			"sacred":
				safety += 0.15
			"hallowed":
				safety += 0.25
			"trading_post":
				safety += 0.1
			"merchant_quarter":
				safety += 0.15
			"craftsman_quarter":
				safety += 0.1
			"industrial":
				safety += 0.05
			"sanctuary_echo":
				safety += 0.2
			"market_echo":
				safety += 0.1
			"forge_echo":
				safety += 0.05
			"old_sanctuary":
				safety += 0.15
			"ancient_sanctuary":
				safety += 0.3
	return clampf(safety, 0.0, 1.0)


## Returns 0.0-1.0 hunger memory from WorldMeaning tags (hunger_place, hungry, famine_stricken).
func _pawn_meaning_hunger(region_key: int) -> float:
	var tags: PackedStringArray = WorldMeaning.get_region_tags(region_key)
	var hunger: float = 0.0
	for tag in tags:
		match tag:
			"hunger_place":
				hunger += 0.3
			"hungry":
				hunger += 0.2
			"famine_stricken":
				hunger += 0.5
	return clampf(hunger, 0.0, 1.0)


## Returns 0.0-1.0 knowledge level from WorldMeaning tags (learned, educated, ancient/old wisdom).
func _pawn_meaning_knowledge(region_key: int) -> float:
	var tags: PackedStringArray = WorldMeaning.get_region_tags(region_key)
	var knowledge: float = 0.0
	for tag in tags:
		match tag:
			"learned":
				knowledge += 0.5
			"educated":
				knowledge += 0.3
			"old_wisdom":
				knowledge += 0.6
			"ancient_wisdom":
				knowledge += 0.8
	return clampf(knowledge, 0.0, 1.0)


## Returns 0.0-1.0 custom/ritual strength from WorldMeaning echo tags.
## Active customs are full weight, faded customs are half weight.
func _pawn_meaning_custom(region_key: int) -> float:
	var tags: PackedStringArray = WorldMeaning.get_region_tags(region_key)
	var custom: float = 0.0
	for tag in tags:
		match tag:
			"burial_grove":
				custom += 0.3
			"teaching_ground":
				custom += 0.25
			"feast_ground":
				custom += 0.2
			"builder_yard":
				custom += 0.2
			"gathering_place":
				custom += 0.25
			# Faded customs: half weight
			"faded_burial_grove":
				custom += 0.15
			"faded_teaching_ground":
				custom += 0.12
			"faded_feast_ground":
				custom += 0.1
			"faded_builder_yard":
				custom += 0.1
			"faded_gathering_place":
				custom += 0.12
	return clampf(custom, 0.0, 1.0)


## Returns 0.0-1.0 craft meaning from tags (industrial, craftsman_quarter, forge_echo, ancient_forge).
func _pawn_meaning_craft(region_key: int) -> float:
	var tags: PackedStringArray = WorldMeaning.get_region_tags(region_key)
	var craft: float = 0.0
	for tag in tags:
		match tag:
			"craftsman_quarter":
				craft += 0.4
			"industrial":
				craft += 0.2
			"forge_echo":
				craft += 0.25
			"old_forge":
				craft += 0.15
			"ancient_forge":
				craft += 0.3
			"faded_forge_echo":
				craft += 0.1
	return clampf(craft, 0.0, 1.0)


## Returns 0.0-1.0 authority meaning from tags (governed, seat_of_power, old_throne, ancient_throne).
func _pawn_meaning_authority(region_key: int) -> float:
	var tags: PackedStringArray = WorldMeaning.get_region_tags(region_key)
	var auth: float = 0.0
	for tag in tags:
		match tag:
			"seat_of_power":
				auth += 0.5
			"governed":
				auth += 0.2
			"old_throne":
				auth += 0.2
			"ancient_throne":
				auth += 0.35
	return clampf(auth, 0.0, 1.0)


## Returns 0.0-1.0 trade meaning from tags (trading_post, merchant_quarter, market_echo, old_market, ancient_market).
func _pawn_meaning_trade(region_key: int) -> float:
	var tags: PackedStringArray = WorldMeaning.get_region_tags(region_key)
	var trade: float = 0.0
	for tag in tags:
		match tag:
			"merchant_quarter":
				trade += 0.4
			"trading_post":
				trade += 0.2
			"market_echo":
				trade += 0.25
			"old_market":
				trade += 0.15
			"ancient_market":
				trade += 0.3
			"faded_market_echo":
				trade += 0.1
	return clampf(trade, 0.0, 1.0)


## Returns 0.0-1.0 conflict meaning from tags (war_torn, grudge_haunted, war_echo, old_battleground, ancient_battleground).
func _pawn_meaning_conflict(region_key: int) -> float:
	var tags: PackedStringArray = WorldMeaning.get_region_tags(region_key)
	var conflict: float = 0.0
	for tag in tags:
		match tag:
			"war_torn":
				conflict += 0.5
			"grudge_haunted":
				conflict += 0.2
			"war_echo":
				conflict += 0.3
			"old_battleground":
				conflict += 0.2
			"ancient_battleground":
				conflict += 0.35
			"faded_war_echo":
				conflict += 0.1
	return clampf(conflict, 0.0, 1.0)


## Returns 0.0-1.0 legacy meaning from tags (storied, ancient_lineage).
func _pawn_meaning_legacy(region_key: int) -> float:
	var tags: PackedStringArray = WorldMeaning.get_region_tags(region_key)
	var legacy: float = 0.0
	for tag in tags:
		match tag:
			"ancient_lineage":
				legacy += 0.5
			"storied":
				legacy += 0.25
	return clampf(legacy, 0.0, 1.0)


## Returns 0.0-1.0 culture meaning from tags (sacred, hallowed, sanctuary_echo, old_sanctuary, ancient_sanctuary).
func _pawn_meaning_culture(region_key: int) -> float:
	var tags: PackedStringArray = WorldMeaning.get_region_tags(region_key)
	var culture: float = 0.0
	for tag in tags:
		match tag:
			"hallowed":
				culture += 0.5
			"sacred":
				culture += 0.2
			"sanctuary_echo":
				culture += 0.3
			"old_sanctuary":
				culture += 0.2
			"ancient_sanctuary":
				culture += 0.35
			"faded_sanctuary_echo":
				culture += 0.1
	return clampf(culture, 0.0, 1.0)


## Returns 0.0-1.0 knowledge risk level for this pawn's settlement.
## High risk = few carriers for skills this pawn knows = urgency to teach.
func _pawn_knowledge_at_risk(pd: HeelKawnianData) -> float:
	if KnowledgeSystem == null:
		return 0.0
	var sid: int = pd.settlement_id
	if sid < 0:
		return 0.0
	var security: Dictionary = KnowledgeSystem.get_knowledge_security_for_settlement(sid)
	var at_risk_count: int = (security.get("at_risk", []) as Array).size()
	var lost_count: int = (security.get("lost", []) as Array).size()
	# Normalize: 0 at-risk + 0 lost = 0.0, 3+ at-risk or 1+ lost = 1.0
	var risk: float = clampf(float(at_risk_count) / 3.0 + float(lost_count) * 0.3, 0.0, 1.0)
	return risk


## Returns 0.0-1.0 teaching obligation weight for this pawn.
## High obligation = they carry knowledge but haven't taught recently.
func _pawn_teaching_obligation(pd: HeelKawnianData) -> float:
	if KnowledgeSystem == null:
		return 0.0
	var pid: int = int(pd.id)
	if KnowledgeSystem.has_method("get"):
		var teaching_debt: Variant = KnowledgeSystem.get("teaching_debt")
		if teaching_debt != null and teaching_debt is Dictionary and teaching_debt.has(pid):
			var debt: Dictionary = teaching_debt[pid]
			return clampf(float(debt.get("obligation_weight", 0.0)), 0.0, 1.0)
	return 0.0


func _pawn_neural_input_vector(pd: HeelKawnianData) -> Array[float]:
	var hunger_n: float = clampf(pd.hunger / 100.0, 0.0, 1.0)
	var rest_n: float = clampf(pd.rest / 100.0, 0.0, 1.0)
	var mood_n: float = clampf(pd.mood / 100.0, 0.0, 1.0)
	var health_n: float = clampf(pd.health / maxf(1.0, pd.max_health), 0.0, 1.0)
	var scar_n: float = clampf(float(pd.physical_scars.size()) / 5.0, 0.0, 1.0)
	var inputs: Array[float] = [
		hunger_n,
		rest_n,
		mood_n,
		health_n,
		float(pd.affinities.get("combat", 0.5)),
		float(pd.affinities.get("farming", 0.5)),
		float(pd.affinities.get("building", 0.5)),
		float(pd.affinities.get("crafting", 0.5)),
		float(pd.affinities.get("diplomacy", 0.5)),
		pd.neuroticism,
		scar_n,
		pd.openness,
		pd.conscientiousness,
	]
	while inputs.size() < 32:
		inputs.append(0.0)
	return inputs


func _resolve_pawn_spawner_for_world_ai() -> PawnSpawner:
	if _cached_pawn_spawner != null:
		var cached_v: Variant = _cached_pawn_spawner.get_ref()
		if cached_v is PawnSpawner and is_instance_valid(cached_v):
			return cached_v as PawnSpawner
	if get_tree() == null or get_tree().root == null:
		return null
	var n: Node = get_tree().root.find_child("PawnSpawner", true, false)
	if n is PawnSpawner and is_instance_valid(n):
		_cached_pawn_spawner = weakref(n)
		return n as PawnSpawner
	return null


func remove_settlement(settlement_id: int) -> void:
	if active_settlements.has(settlement_id):
		active_settlements.erase(settlement_id)

func get_technological_progress() -> float:
	var discovered_count: int = 0
	for discovery in technological_discoveries:
		if discovery.discovery_tick > 0:
			discovered_count += 1
	
	return float(discovered_count) / float(technological_discoveries.size())
