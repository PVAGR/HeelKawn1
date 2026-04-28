extends RefCounted
class_name WorldAI
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
	var prerequisites: Array[String] = []
	var discovery_tick: int
	var discoverer_settlement: int
	var spread_rate: float = 0.1  # How fast it spreads to other settlements
	var world_impact: float = 0.0
	
	func _init(name: String, tier: TechnologicalTier, prereqs: Array[String] = []):
		discovery_name = name
		tier_required = tier
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
var neural_evolution_rate: float = 0.001  # Rate of neural network evolution
var pattern_emergence_threshold: float = 0.8  # Threshold for emergent patterns
var civilization_learning_rate: float = 0.01  # Learning rate for civilization AI
var environmental_adaptation_rate: float = 0.005  # Environmental adaptation rate

# Progression parameters
var age_progression_threshold: float = 0.0  # 0.0-1.0, when to advance to next age
var tech_innovation_rate: float = 0.01  # Base rate of technological discovery
var cultural_evolution_rate: float = 0.02  # Base rate of cultural change
var environmental_stability: float = 0.8  # How stable the environment is

func _init():
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
		"cultural_diversity": {"value": 0.0, "activation": 0.0, "connections": []}
	}


func _create_environmental_neurons() -> Dictionary:
	return {
		"temperature_stability": {"value": global_temperature, "activation": 0.0, "connections": []},
		"sea_level_stability": {"value": sea_level, "activation": 0.0, "connections": []},
		"biodiversity_health": {"value": biodiversity_index, "activation": 0.0, "connections": []},
		"resource_renewability": {"value": 0.8, "activation": 0.0, "connections": []},
		"climate_patterns": {"value": 0.5, "activation": 0.0, "connections": []},
		"ecosystem_resilience": {"value": 0.7, "activation": 0.0, "connections": []}
	}


func _create_civilization_neurons() -> Dictionary:
	return {
		"urbanization": {"value": 0.0, "activation": 0.0, "connections": []},
		"governance_complexity": {"value": 0.0, "activation": 0.0, "connections": []},
		"trade_networks": {"value": 0.0, "activation": 0.0, "connections": []},
		"military_organization": {"value": 0.0, "activation": 0.0, "connections": []},
		"educational_systems": {"value": 0.0, "activation": 0.0, "connections": []},
		"infrastructure_development": {"value": 0.0, "activation": 0.0, "connections": []}
	}


func _create_cultural_neurons() -> Dictionary:
	return {
		"artistic_expression": {"value": 0.0, "activation": 0.0, "connections": []},
		"religious_systems": {"value": 0.0, "activation": 0.0, "connections": []},
		"philosophical_thought": {"value": 0.0, "activation": 0.0, "connections": []},
		"social_norms": {"value": 0.0, "activation": 0.0, "connections": []},
		"language_complexity": {"value": 0.0, "activation": 0.0, "connections": []},
		"cultural_exchange": {"value": 0.0, "activation": 0.0, "connections": []}
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
	
	# Connect world state to all other networks
	var world_neurons = neural_world_matrix.world_state_neurons.keys()
	var all_networks = ["environmental_neurons", "civilization_neurons", "cultural_neurons", "economic_neurons"]
	
	for world_neuron in world_neurons:
		for network in all_networks:
			var network_neurons = neural_world_matrix[network].keys()
			for network_neuron in network_neurons:
				var connection_id = "%s_to_%s" % [world_neuron, network_neuron]
				interconnections[connection_id] = {
					"weight": randf_range(-0.3, 0.3),
					"strength": 1.0,
					"plasticity": 0.01
				}
	
	return interconnections


func _initialize_neural_networks() -> void:
	# Initialize specialized neural networks
	civilization_neural_network = _create_specialized_network("civilization", 32, 16, 8)
	environmental_neural_network = _create_specialized_network("environmental", 24, 12, 6)
	cultural_neural_network = _create_specialized_network("cultural", 28, 14, 7)
	economic_neural_network = _create_specialized_network("economic", 20, 10, 5)
	
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
		"learning_rate": civilization_learning_rate,
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
	
	# Input to hidden weights
	weights["input_to_hidden"] = _create_weight_matrix(input_size, hidden_size)
	
	# Hidden to output weights
	weights["hidden_to_output"] = _create_weight_matrix(hidden_size, output_size)
	
	return weights


func _create_weight_matrix(rows: int, cols: int) -> Array[Array[float]]:
	var matrix: Array[Array[float]] = []
	for i in range(rows):
		var row: Array[float] = []
		for j in range(cols):
			row.append(randf_range(-0.5, 0.5))
		matrix.append(row)
	return matrix

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
		TechnologicalDiscovery.new("Fire", TechnologicalTier.STONE),
		TechnologicalDiscovery.new("Stone Tools", TechnologicalTier.STONE),
		TechnologicalDiscovery.new("Simple Shelters", TechnologicalTier.STONE),
		TechnologicalDiscovery.new("Oral Language", TechnologicalTier.STONE),
		TechnologicalDiscovery.new("Basic Hunting", TechnologicalTier.STONE)
	]
	
	technological_discoveries.clear()
	for discovery in stone_age_discoveries:
		technological_discoveries.append(discovery)

# === Age Progression ===

func update_world_age() -> void:
	var progression_score: float = _calculate_age_progression()
	
	if progression_score >= age_progression_threshold and current_age < WorldAge.FUTURE:
		_advance_to_next_age()

func _calculate_age_progression() -> float:
	var score: float = 0.0
	
	# Population factor
	score += float(world_population) / 1000.0
	
	# Technology factor
	score += float(technological_tier) * 0.1
	
	# Settlement factor
	score += float(active_settlements.size()) * 0.05
	
	# Cultural factor
	score += total_cultural_influence * 0.01
	
	# Event factor (major events accelerate progression)
	var recent_major_events: int = 0
	for event in world_events:
		if event.impact_level >= 5 and GameManager.tick_count - event.tick_occurred < 1000:
			recent_major_events += 1
	score += float(recent_major_events) * 0.1
	
	return clamp(score, 0.0, 1.0)

func _advance_to_next_age() -> void:
	var next_age: WorldAge = WorldAge.values()[current_age + 1]
	current_age = next_age
	
	# Record age transition
	var age_name: String = WorldAge.keys()[current_age]
	major_turning_points.append("Beginning of %s Age" % age_name)
	
	# Record in existing WorldMemory
	var event: WorldEvent = WorldEvent.new("Age Transition", "World entered %s Age" % age_name, 8)
	world_events.append(event)
	
	# Update technological tier based on age
	_update_tech_tier_for_age()
	
	# Adjust resource availability
	_adjust_resources_for_age()

func _update_tech_tier_for_age() -> void:
	match current_age:
		WorldAge.PRIMAL:
			technological_tier = TechnologicalTier.STONE
		WorldAge.DAWN:
			technological_tier = TechnologicalTier.STONE
		WorldAge.TRIBAL:
			technological_tier = TechnologicalTier.COPPER
		WorldAge.CIVILIZED:
			technological_tier = TechnologicalTier.BRONZE
		WorldAge.CLASSICAL:
			technological_tier = TechnologicalTier.IRON
		WorldAge.MEDIEVAL:
			technological_tier = TechnologicalTier.STEEL
		WorldAge.RENAISSANCE:
			technological_tier = TechnologicalTier.GUNPOWDER
		WorldAge.INDUSTRIAL:
			technological_tier = TechnologicalTier.STEAM
		WorldAge.MODERN:
			technological_tier = TechnologicalTier.ELECTRICITY
		WorldAge.FUTURE:
			technological_tier = TechnologicalTier.DIGITAL

func _adjust_resources_for_age() -> void:
	match current_age:
		WorldAge.TRIBAL:
			resource_distribution["metal"] = 0.5
		WorldAge.CIVILIZED:
			resource_distribution["metal"] = 0.8
			resource_distribution["coal"] = 0.3
		WorldAge.CLASSICAL:
			resource_distribution["coal"] = 0.5
		WorldAge.MEDIEVAL:
			resource_distribution["coal"] = 0.7
		WorldAge.INDUSTRIAL:
			resource_distribution["coal"] = 1.0
			resource_distribution["oil"] = 0.3
		WorldAge.MODERN:
			resource_distribution["oil"] = 0.8
		WorldAge.FUTURE:
			resource_distribution["oil"] = 0.5
			resource_distribution["uranium"] = 0.3

# === Technological Progression ===

func process_technological_discovery() -> void:
	# Check if any settlement can make new discoveries
	for settlement_id in active_settlements:
		var settlement: SettlementAI = active_settlements[settlement_id]
		_attempt_discovery(settlement)
	
	# Spread existing discoveries
	_spread_technology()

func _attempt_discovery(settlement: SettlementAI) -> void:
	var available_discoveries: Array[TechnologicalDiscovery] = _get_available_discoveries(settlement)
	
	if available_discoveries.size() == 0:
		return
	
	# Discovery chance based on settlement's focus and population
	var discovery_chance: float = 0.0
	match settlement.development_focus:
		SettlementAI.DevelopmentFocus.KNOWLEDGE:
			discovery_chance = 0.05
		SettlementAI.DevelopmentFocus.BALANCED:
			discovery_chance = 0.02
		_:
			discovery_chance = 0.01
	
	discovery_chance *= float(settlement.population) / 100.0
	discovery_chance *= tech_innovation_rate
	
	if randf() < discovery_chance:
		var discovery: TechnologicalDiscovery = available_discoveries[randi() % available_discoveries.size()]
		_make_discovery(discovery, settlement.settlement_id)

func _get_available_discoveries(settlement: SettlementAI) -> Array[TechnologicalDiscovery]:
	var available: Array[TechnologicalDiscovery] = []
	
	for discovery in technological_discoveries:
		if _can_discover(settlement, discovery):
			available.append(discovery)
	
	return available

func _can_discover(settlement: SettlementAI, discovery: TechnologicalDiscovery) -> bool:
	# Check if already discovered
	if discovery.discovery_tick > 0:
		return false
	
	# Check tier requirement
	if discovery.tier_required > technological_tier:
		return false
	
	# Check prerequisites
	for prereq in discovery.prerequisites:
		var discovered: bool = false
		for existing in technological_discoveries:
			if existing.discovery_name == prereq and existing.discovery_tick > 0:
				discovered = true
				break
		if not discovered:
			return false
	
	return true

func _make_discovery(discovery: TechnologicalDiscovery, settlement_id: int) -> void:
	discovery.discovery_tick = GameManager.tick_count
	discovery.discoverer_settlement = settlement_id
	
	# Record discovery event
	var event: WorldEvent = WorldEvent.new("Technological Discovery", 
		"%s discovered in settlement %d" % [discovery.discovery_name, settlement_id], 6)
	world_events.append(event)
	civilization_achievements.append(discovery.discovery_name)
	
	# Calculate world impact
	discovery.world_impact = _calculate_discovery_impact(discovery)
	
	# Add new discoveries that become available
	_unlock_new_discoveries(discovery)

func _calculate_discovery_impact(discovery: TechnologicalDiscovery) -> float:
	var impact: float = 0.0
	
	# Base impact by tier
	impact += float(discovery.tier_required) * 0.1
	
	# Specific discoveries have higher impact
	match discovery.discovery_name:
		"Fire":
			impact = 0.8
		"Agriculture":
			impact = 0.9
		"Writing":
			impact = 0.7
		"Printing Press":
			impact = 0.6
		"Steam Engine":
			impact = 0.8
		"Electricity":
			impact = 0.9
		"Digital Computer":
			impact = 0.8
	
	return impact

func _unlock_new_discoveries(discovery: TechnologicalDiscovery) -> void:
	# New discoveries become available based on what was just discovered
	var new_discoveries: Array[TechnologicalDiscovery] = []
	
	match discovery.discovery_name:
		"Fire":
			new_discoveries.append(TechnologicalDiscovery.new("Cooking", TechnologicalTier.STONE))
			new_discoveries.append(TechnologicalDiscovery.new("Pottery", TechnologicalTier.COPPER))
		"Stone Tools":
			new_discoveries.append(TechnologicalDiscovery.new("Hunting Weapons", TechnologicalTier.STONE))
			new_discoveries.append(TechnologicalDiscovery.new("Woodworking", TechnologicalTier.COPPER))
		"Agriculture":
			new_discoveries.append(TechnologicalDiscovery.new("Irrigation", TechnologicalTier.BRONZE))
			new_discoveries.append(TechnologicalDiscovery.new("Food Storage", TechnologicalTier.BRONZE))
		"Writing":
			new_discoveries.append(TechnologicalDiscovery.new("Mathematics", TechnologicalTier.IRON))
			new_discoveries.append(TechnologicalDiscovery.new("Philosophy", TechnologicalTier.IRON))
		"Mathematics":
			new_discoveries.append(TechnologicalDiscovery.new("Engineering", TechnologicalTier.STEEL))
			new_discoveries.append(TechnologicalDiscovery.new("Astronomy", TechnologicalTier.STEEL))
		"Engineering":
			new_discoveries.append(TechnologicalDiscovery.new("Architecture", TechnologicalTier.STEEL))
			new_discoveries.append(TechnologicalDiscovery.new("Metallurgy", TechnologicalTier.STEEL))
		"Steam Engine":
			new_discoveries.append(TechnologicalDiscovery.new("Factories", TechnologicalTier.STEAM))
			new_discoveries.append(TechnologicalDiscovery.new("Railways", TechnologicalTier.STEAM))
		"Electricity":
			new_discoveries.append(TechnologicalDiscovery.new("Telegraph", TechnologicalTier.ELECTRICITY))
			new_discoveries.append(TechnologicalDiscovery.new("Lighting", TechnologicalTier.ELECTRICITY))
		"Digital Computer":
			new_discoveries.append(TechnologicalDiscovery.new("Internet", TechnologicalTier.DIGITAL))
			new_discoveries.append(TechnologicalDiscovery.new("Artificial Intelligence", TechnologicalTier.QUANTUM))
	
	technological_discoveries.append_array(new_discoveries)

func _spread_technology() -> void:
	for discovery in technological_discoveries:
		if discovery.discovery_tick > 0 and discovery.spread_rate > 0:
			_spread_discovery_to_settlements(discovery)

func _spread_discovery_to_settlements(discovery: TechnologicalDiscovery) -> void:
	var discoverer_settlement: SettlementAI = active_settlements.get(discovery.discoverer_settlement)
	if discoverer_settlement == null:
		return
	
	# Spread to trade partners and nearby settlements
	for settlement_id in active_settlements:
		if settlement_id == discovery.discoverer_settlement:
			continue
		
		var settlement: SettlementAI = active_settlements[settlement_id]
		var spread_chance: float = discovery.spread_rate
		
		# Higher spread chance for trade partners
		if settlement.resource_management.trade_partners.has(discovery.discoverer_settlement):
			spread_chance *= 2.0
		
		# Higher spread chance for nearby settlements
		var distance: float = settlement.location.distance_to(discoverer_settlement.location)
		if distance < 50:
			spread_chance *= 1.5
		
		if randf() < spread_chance:
			# Settlement adopts the technology
			var event: WorldEvent = WorldEvent.new("Technology Spread", 
				"%s spread to settlement %d" % [discovery.discovery_name, settlement_id], 3)
			world_events.append(event)

# === Environmental Systems ===

func update_environment() -> void:
	_update_climate_patterns()
	_process_environmental_events()
	_adjust_resource_availability()

func _update_climate_patterns() -> void:
	# Remove expired patterns
	var expired_patterns: Array[int] = []
	for i in range(climate_patterns.size()):
		var pattern: ClimatePattern = climate_patterns[i]
		if GameManager.tick_count > pattern.duration_ticks:
			expired_patterns.append(i)
	
	for i in range(expired_patterns.size() - 1, -1, -1):
		climate_patterns.remove_at(expired_patterns[i])
	
	# Chance to create new climate patterns
	if randf() < 0.01 and climate_patterns.size() < 3:
		_create_climate_pattern()

func _create_climate_pattern() -> void:
	var patterns = [
		ClimatePattern.new("Warm Period", 0.2, 0.1, 2000, 0.3),
		ClimatePattern.new("Cold Snap", -0.3, -0.2, 1000, 0.5),
		ClimatePattern.new("Drought", 0.1, -0.4, 1500, 0.6),
		ClimatePattern.new("Flood", -0.1, 0.6, 800, 0.7),
		ClimatePattern.new("Perfect Weather", 0.0, 0.2, 1200, 0.2)
	]
	
	var pattern: ClimatePattern = patterns[randi() % patterns.size()]
	pattern.duration_ticks = GameManager.tick_count + pattern.duration_ticks
	climate_patterns.append(pattern)
	
	var event: WorldEvent = WorldEvent.new("Climate Change", 
		"%s began affecting the world" % pattern.pattern_name, 4)
	world_events.append(event)

func _process_environmental_events() -> void:
	# Process active climate patterns
	for pattern in climate_patterns:
		_apply_climate_effects(pattern)
	
	# Random environmental events
	if randf() < 0.005:
		_create_environmental_event()

func _apply_climate_effects(pattern: ClimatePattern) -> void:
	# Adjust global temperature
	global_temperature = clamp(global_temperature + pattern.temperature_shift * 0.01, 0.5, 1.5)
	
	# Adjust resource availability
	if pattern.precipitation_change > 0:
		resource_distribution["food"] = clamp(resource_distribution.get("food", 0.0) + 0.01, 0.0, 2.0)
		resource_distribution["water"] = clamp(resource_distribution.get("water", 0.0) + 0.02, 0.0, 2.0)
	else:
		resource_distribution["food"] = clamp(resource_distribution.get("food", 0.0) - 0.01, 0.0, 2.0)
		resource_distribution["water"] = clamp(resource_distribution.get("water", 0.0) - 0.02, 0.0, 2.0)

func _create_environmental_event() -> void:
	var events = [
		"Earthquake",
		"Volcanic Eruption", 
		"Tornado",
		"Wildfire",
		"Disease Outbreak",
		"Plague",
		"Meteor Strike",
		"Solar Eclipse"
	]
	
	var event_name: String = events[randi() % events.size()]
	var impact: int = randi_range(3, 8)
	
	var event: WorldEvent = WorldEvent.new("Natural Disaster", 
		"%s struck the world" % event_name, impact)
	world_events.append(event)
	
	# Apply effects to settlements
	for settlement_id in active_settlements:
		var settlement: SettlementAI = active_settlements[settlement_id]
		if randf() < 0.3:  # 30% chance to affect each settlement
			_apply_disaster_to_settlement(settlement, event_name)

func _apply_disaster_to_settlement(settlement: SettlementAI, disaster_name: String) -> void:
	match disaster_name:
		"Earthquake":
			settlement.population = max(1, settlement.population - randi_range(1, 5))
		"Volcanic Eruption":
			settlement.population = max(1, settlement.population - randi_range(2, 8))
		"Disease Outbreak":
			settlement.population = max(1, settlement.population - randi_range(3, 10))
		"Plague":
			settlement.population = max(1, settlement.population - randi_range(5, 15))
	
	var event: WorldEvent = WorldEvent.new("Settlement Disaster", 
		"%s affected %s" % [disaster_name, settlement.settlement_name], 5)
	event.participant_settlements.append(settlement.settlement_id)
	world_events.append(event)

func _adjust_resource_availability() -> void:
	# Natural resource regeneration
	for resource in resource_distribution:
		var current: float = resource_distribution[resource]
		var max_amount: float = 2.0
		
		# Different resources regenerate at different rates
		var regeneration_rate: float = 0.001
		match resource:
			"wood", "food":
				regeneration_rate = 0.005
			"metal", "coal":
				regeneration_rate = 0.001
			"oil":
				regeneration_rate = 0.0005
		
		resource_distribution[resource] = min(current + regeneration_rate, max_amount)

# === Historical Recording ===

func record_world_event(event_type: String, description: String, impact: int = 1) -> void:
	var event: WorldEvent = WorldEvent.new(event_type, description, impact)
	world_events.append(event)
	
	# Check if this is a major turning point
	if impact >= 7:
		major_turning_points.append(description)

func update_world_statistics() -> void:
	# Update total population
	world_population = 0
	total_cultural_influence = 0.0
	
	for settlement_id in active_settlements:
		var settlement: SettlementAI = active_settlements[settlement_id]
		world_population += settlement.population
		total_cultural_influence += settlement.get_cultural_influence()
	
	# Check for golden ages
	_check_for_golden_age()

func _check_for_golden_age() -> void:
	# Golden age conditions: high population, high culture, peace
	var population_threshold: int = 100
	var culture_threshold: float = 50.0
	var recent_disasters: int = 0
	
	# Count recent disasters
	for event in world_events:
		if event.event_type == "Natural Disaster" and GameManager.tick_count - event.tick_occurred < 2000:
			recent_disasters += 1
	
	if world_population > population_threshold and total_cultural_influence > culture_threshold and recent_disasters < 2:
		# Check if we're not already in a golden age
		var in_golden_age: bool = false
		for golden_age in golden_ages:
			if GameManager.tick_count >= golden_age.start_tick and GameManager.tick_count <= golden_age.end_tick:
				in_golden_age = true
				break
		
		if not in_golden_age:
			_start_golden_age()

func _start_golden_age() -> void:
	var golden_age: Dictionary = {
		"start_tick": GameManager.tick_count,
		"end_tick": GameManager.tick_count + 3000,  # Golden age lasts 3000 ticks
		"description": "Age of prosperity and cultural achievement"
	}
	
	golden_ages.append(golden_age)
	
	var event: WorldEvent = WorldEvent.new("Golden Age", 
		"World entered a golden age of prosperity", 9)
	world_events.append(event)
	civilization_achievements.append("Golden Age Achievement")

# === Main Update Loop ===

func update() -> void:
	# Main update loop for world AI with neural network integration
	_update_neural_world_matrix()
	_process_neural_networks()
	_detect_emergent_patterns()
	_evolve_neural_networks()
	_update_environmental_conditions()
	_process_climate_patterns()
	_check_for_world_events()
	_update_technological_progress()
	_update_civilization_development()

# === Neural Network Processing ===

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

func _update_world_state_neurons() -> void:
	var world_neurons = neural_world_matrix.world_state_neurons
	
	# Update population density
	world_neurons.population_density.value = float(world_population) / 1000.0
	
	# Update technological progress
	world_neurons.technological_progress.value = float(technological_tier) / 10.0
	
	# Update environmental health
	world_neurons.environmental_health.value = biodiversity_index * environmental_stability
	
	# Update social complexity
	world_neurons.social_complexity.value = float(active_settlements.size()) / 20.0
	
	# Update resource abundance
	var total_resources = 0.0
	for resource in resource_distribution:
		total_resources += resource_distribution[resource]
	world_neurons.resource_abundance.value = total_resources / float(resource_distribution.size())
	
	# Update conflict level
	var conflict_score = 0.0
	for event in world_events:
		if event.event_type == "war" or event.event_type == "conflict":
			conflict_score += float(event.impact_level) / 10.0
	world_neurons.conflict_level.value = conflict_score / float(max(world_events.size(), 1))
	
	# Update innovation rate
	world_neurons.innovation_rate.value = tech_innovation_rate * float(technological_discoveries.size()) / 10.0
	
	# Update cultural diversity
	world_neurons.cultural_diversity.value = total_cultural_influence / 100.0

func _update_environmental_neurons() -> void:
	var env_neurons = neural_world_matrix.environmental_neurons
	
	# Update with current environmental data
	env_neurons.temperature_stability.value = global_temperature
	env_neurons.sea_level_stability.value = sea_level
	env_neurons.biodiversity_health.value = biodiversity_index
	
	# Calculate derived environmental metrics
	env_neurons.resource_renewability.value = _calculate_resource_renewability()
	env_neurons.climate_patterns.value = _calculate_climate_stability()
	env_neurons.ecosystem_resilience.value = _calculate_ecosystem_resilience()

func _update_civilization_neurons() -> void:
	var civ_neurons = neural_world_matrix.civilization_neurons
	
	# Update based on current civilization state
	civ_neurons.urbanization.value = float(active_settlements.size()) / 50.0
	civ_neurons.governance_complexity.value = float(technological_tier) / 10.0
	civ_neurons.trade_networks.value = _calculate_trade_network_complexity()
	civ_neurons.military_organization.value = _calculate_military_organization()
	civ_neurons.educational_systems.value = _calculate_educational_development()
	civ_neurons.infrastructure_development.value = _calculate_infrastructure_level()

func _update_cultural_neurons() -> void:
	var cult_neurons = neural_world_matrix.cultural_neurons
	
	# Update cultural metrics
	cult_neurons.artistic_expression.value = _calculate_artistic_expression()
	cult_neurons.religious_systems.value = _calculate_religious_complexity()
	cult_neurons.philosophical_thought.value = _calculate_philosophical_development()
	cult_neurons.social_norms.value = _calculate_social_norm_complexity()
	cult_neurons.language_complexity.value = _calculate_language_complexity()
	cult_neurons.cultural_exchange.value = _calculate_cultural_exchange_rate()

func _update_economic_neurons() -> void:
	var econ_neurons = neural_world_matrix.economic_neurons
	
	# Update economic metrics
	econ_neurons.production_efficiency.value = _calculate_production_efficiency()
	econ_neurons.resource_distribution.value = _calculate_resource_distribution_efficiency()
	econ_neurons.market_complexity.value = _calculate_market_complexity()
	econ_neurons.labor_specialization.value = _calculate_labor_specialization()
	econ_neurons.wealth_accumulation.value = _calculate_wealth_accumulation()
	econ_neurons.economic_stability.value = _calculate_economic_stability()

func _process_neural_activations() -> void:
	# Process all neural networks through activation functions
	var all_networks = [
		neural_world_matrix.world_state_neurons,
		neural_world_matrix.environmental_neurons,
		neural_world_matrix.civilization_neurons,
		neural_world_matrix.cultural_neurons,
		neural_world_matrix.economic_neurons
	]
	
	for network in all_networks:
		for neuron_name in network:
			var neuron = network[neuron_name]
			neuron.activation = _apply_neural_activation(neuron.value)

func _apply_neural_activation(value: float) -> float:
	# Use sigmoid activation function for neural processing
	return 1.0 / (1.0 + exp(-value))

func _process_neural_networks() -> void:
	# Process specialized neural networks
	_process_civilization_network()
	_process_environmental_network()
	_process_cultural_network()
	_process_economic_network()

func _process_civilization_network() -> void:
	var input_data = _extract_civilization_input()
	var output = _forward_propagate_network(civilization_neural_network, input_data)
	_interpret_civilization_output(output)

func _process_environmental_network() -> void:
	var input_data = _extract_environmental_input()
	var output = _forward_propagate_network(environmental_neural_network, input_data)
	_interpret_environmental_output(output)

func _process_cultural_network() -> void:
	var input_data = _extract_cultural_input()
	var output = _forward_propagate_network(cultural_neural_network, input_data)
	_interpret_cultural_output(output)

func _process_economic_network() -> void:
	var input_data = _extract_economic_input()
	var output = _forward_propagate_network(economic_neural_network, input_data)
	_interpret_economic_output(output)

func _detect_emergent_patterns() -> void:
	# Analyze neural network activity for emergent patterns
	var current_state = _get_current_neural_state()
	var pattern_score = _calculate_pattern_emergence(current_state)
	
	if pattern_score >= pattern_emergence_threshold:
		var new_pattern = _create_emergent_pattern(current_state, pattern_score)
		emergent_patterns.append(new_pattern)
		_apply_emergent_pattern_effects(new_pattern)

func _evolve_neural_networks() -> void:
	# Evolve neural networks based on experience
	neural_world_matrix.evolution_cycles += 1
	
	# Apply learning and adaptation
	_adapt_neural_weights()
	_mutate_neural_structures()
	_prune_weak_connections()

func _adapt_neural_weights() -> void:
	# Adapt weights based on performance feedback
	var learning_rate = neural_world_matrix.learning_rate
	
	for connection_id in neural_world_matrix.interconnections:
		var connection = neural_world_matrix.interconnections[connection_id]
		var adaptation = _calculate_weight_adaptation(connection)
		connection.weight += learning_rate * adaptation
		connection.weight = clamp(connection.weight, -1.0, 1.0)

func _mutate_neural_structures() -> void:
	# Occasionally mutate neural structures for evolution
	if randf() < neural_evolution_rate:
		_mutate_random_connection()

func _prune_weak_connections() -> void:
	# Remove very weak connections to improve efficiency
	var connections_to_remove = []
	
	for connection_id in neural_world_matrix.interconnections:
		var connection = neural_world_matrix.interconnections[connection_id]
		if abs(connection.weight) < 0.01:
			connections_to_remove.append(connection_id)
	
	for connection_id in connections_to_remove:
		neural_world_matrix.interconnections.erase(connection_id)

func _cleanup_old_events() -> void:
	# Keep only recent events (last 1000)
	if world_events.size() > 1000:
		world_events = world_events.slice(-1000)

# === Public Interface ===

func get_world_status() -> Dictionary:
	return {
		"current_age": WorldAge.keys()[current_age],
		"technological_tier": TechnologicalTier.keys()[technological_tier],
		"world_population": world_population,
		"active_settlements": active_settlements.size(),
		"total_discoveries": technological_discoveries.size(),
		"major_events": world_events.size(),
		"golden_ages_active": golden_ages.size(),
		"environmental_stability": environmental_stability
	}

func get_detailed_world_status() -> Dictionary:
	return {
		"current_age": current_age,
		"technological_tier": technological_tier,
		"world_events": _get_recent_events(),
		"discoveries": _get_discovery_summary(),
		"climate_patterns": _get_climate_summary(),
		"resource_distribution": resource_distribution,
		"golden_ages": golden_ages,
		"major_turning_points": major_turning_points,
		"civilization_achievements": civilization_achievements
	}

func _get_recent_events() -> Array:
	var recent: Array = []
	for event in world_events.slice(-20):  # Last 20 events
		recent.append({
			"type": event.event_type,
			"description": event.description,
			"impact": event.impact_level,
			"tick": event.tick_occurred
		})
	return recent

func _get_discovery_summary() -> Array:
	var summary: Array = []
	for discovery in technological_discoveries:
		if discovery.discovery_tick > 0:  # Only discovered technologies
			summary.append({
				"name": discovery.discovery_name,
				"tier": TechnologicalTier.keys()[discovery.tier_required],
				"discoverer": discovery.discoverer_settlement,
				"tick": discovery.discovery_tick,
				"impact": discovery.world_impact
			})
	return summary

func _get_climate_summary() -> Array:
	var summary: Array = []
	for pattern in climate_patterns:
		summary.append({
			"name": pattern.pattern_name,
			"temperature_shift": pattern.temperature_shift,
			"precipitation_change": pattern.precipitation_change,
			"severity": pattern.severity,
			"remaining_ticks": pattern.duration_ticks - GameManager.tick_count
		})
	return summary

func register_settlement(settlement: SettlementAI) -> void:
	active_settlements[settlement.settlement_id] = settlement
	
	var event: WorldEvent = WorldEvent.new("Settlement Founded", 
		"%s was established" % settlement.settlement_name, 3)
	world_events.append(event)

func unregister_settlement(settlement_id: int) -> void:
	if active_settlements.has(settlement_id):
		var settlement: SettlementAI = active_settlements[settlement_id]
		var event: WorldEvent = WorldEvent.new("Settlement Abandoned", 
			"%s was abandoned" % settlement.settlement_name, 4)
		world_events.append(event)
		
		active_settlements.erase(settlement_id)

func get_technological_progress() -> float:
	var discovered_count: int = 0
	for discovery in technological_discoveries:
		if discovery.discovery_tick > 0:
			discovered_count += 1
	
	return float(discovered_count) / float(technological_discoveries.size())
