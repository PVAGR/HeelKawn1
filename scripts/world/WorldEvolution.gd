extends Node
class_name WorldEvolution
## Dynamic World Evolution System with Neural Network Matrix Integration
## Manages world evolution, emergent behaviors, and adaptive systems

signal world_evolution_event(event_data: Dictionary)
signal emergent_behavior_detected(behavior: Dictionary)
var neural_evolution_engine: Dictionary = {}
var adaptive_systems: Dictionary = {}
var emergent_patterns: Array[Dictionary] = []
var evolution_history: Array[Dictionary] = []

# Evolution Parameters
var evolution_rate: float = 0.001
var adaptation_threshold: float = 0.8
var emergence_probability: float = 0.01
var neural_complexity_growth: float = 0.0001

func _ready() -> void:
	_initialize_neural_evolution_engine()
	_setup_adaptive_systems()
	print("[WorldEvolution] Dynamic world evolution system initialized")

# === Neural Evolution Engine ===

func _initialize_neural_evolution_engine() -> void:
	neural_evolution_engine = {
		"evolution_matrix": _create_evolution_matrix(),
		"adaptation_network": _create_adaptation_network(),
		"emergence_detector": _create_emergence_detector(),
		"complexity_analyzer": _create_complexity_analyzer(),
		"evolution_cycles": 0
	}
	
	print("[WorldEvolution] Neural evolution engine initialized")

func _create_evolution_matrix() -> Dictionary:
	return {
		"world_state_neurons": _create_world_state_neurons(),
		"evolution_drivers": _create_evolution_drivers(),
		"adaptation_neurons": _create_adaptation_neurons(),
		"complexity_neurons": _create_complexity_neurons(),
		"interconnections": _create_evolution_interconnections()
	}

func _create_world_state_neurons() -> Dictionary:
	return {
		"population_pressure": {"value": 0.0, "activation": 0.0, "evolution_rate": 0.0},
		"resource_depletion": {"value": 0.0, "activation": 0.0, "evolution_rate": 0.0},
		"environmental_stress": {"value": 0.0, "activation": 0.0, "evolution_rate": 0.0},
		"social_complexity": {"value": 0.0, "activation": 0.0, "evolution_rate": 0.0},
		"technological_advancement": {"value": 0.0, "activation": 0.0, "evolution_rate": 0.0},
		"cultural_diversity": {"value": 0.0, "activation": 0.0, "evolution_rate": 0.0}
	}

func _create_evolution_drivers() -> Dictionary:
	return {
		"survival_pressure": {"strength": 1.0, "direction": 1.0, "adaptation_rate": 0.01},
		"resource_competition": {"strength": 1.0, "direction": 1.0, "adaptation_rate": 0.01},
		"environmental_challenges": {"strength": 1.0, "direction": 1.0, "adaptation_rate": 0.01},
		"social_cooperation": {"strength": 1.0, "direction": 1.0, "adaptation_rate": 0.01},
		"innovation_drive": {"strength": 1.0, "direction": 1.0, "adaptation_rate": 0.01}
	}

func _create_adaptation_neurons() -> Dictionary:
	return {
		"behavioral_adaptation": {"plasticity": 0.1, "adaptation_threshold": 0.7},
		"physiological_adaptation": {"plasticity": 0.05, "adaptation_threshold": 0.8},
		"social_adaptation": {"plasticity": 0.15, "adaptation_threshold": 0.6},
		"technological_adaptation": {"plasticity": 0.2, "adaptation_threshold": 0.5},
		"cultural_adaptation": {"plasticity": 0.12, "adaptation_threshold": 0.65}
	}

func _create_complexity_neurons() -> Dictionary:
	return {
		"system_complexity": {"current_level": 1.0, "growth_rate": 0.001},
		"neural_complexity": {"current_level": 1.0, "growth_rate": 0.002},
		"behavioral_complexity": {"current_level": 1.0, "growth_rate": 0.0015},
		"environmental_complexity": {"current_level": 1.0, "growth_rate": 0.0008}
	}

func _create_evolution_interconnections() -> Dictionary:
	var connections: Dictionary = {}
	
	# Connect world state to evolution drivers
	var world_states = neural_evolution_engine.evolution_matrix.world_state_neurons.keys()
	var drivers = neural_evolution_engine.evolution_matrix.evolution_drivers.keys()
	
	for state in world_states:
		for driver in drivers:
			var connection_id = "%s_to_%s" % [state, driver]
			connections[connection_id] = {
				"weight": randf_range(-0.2, 0.2),
				"plasticity": 0.01,
				"strength": 1.0
			}
	
	return connections

func _create_adaptation_network() -> Dictionary:
	return {
		"input_layer": {"size": 12, "neurons": _create_adaptation_input_neurons()},
		"hidden_layer": {"size": 8, "neurons": _create_adaptation_hidden_neurons()},
		"output_layer": {"size": 6, "neurons": _create_adaptation_output_neurons()},
		"weights": _initialize_adaptation_weights(),
		"learning_rate": 0.01
	}

func _create_adaptation_input_neurons() -> Array[Dictionary]:
	var neurons: Array[Dictionary] = []
	var inputs = [
		"population_density", "resource_availability", "environmental_conditions",
		"social_pressure", "technological_level", "cultural_influence",
		"stress_factors", "opportunity_factors", "threat_level",
		"cooperation_level", "competition_level", "innovation_rate"
	]
	
	for i in range(inputs.size()):
		neurons.append({
			"id": inputs[i],
			"value": 0.0,
			"activation": 0.0,
			"bias": randf_range(-0.1, 0.1)
		})
	
	return neurons

func _create_adaptation_hidden_neurons() -> Array[Dictionary]:
	var neurons: Array[Dictionary] = []
	for i in range(8):
		neurons.append({
			"id": "hidden_%d" % i,
			"value": 0.0,
			"activation": 0.0,
			"bias": randf_range(-0.1, 0.1)
		})
	return neurons

func _create_adaptation_output_neurons() -> Array[Dictionary]:
	var neurons: Array[Dictionary] = []
	var outputs = ["behavioral", "physiological", "social", "technological", "cultural", "environmental"]
	
	for i in range(outputs.size()):
		neurons.append({
			"id": outputs[i],
			"value": 0.0,
			"activation": 0.0,
			"bias": randf_range(-0.1, 0.1)
		})
	
	return neurons

func _initialize_adaptation_weights() -> Dictionary:
	var weights: Dictionary = {}
	weights["input_to_hidden"] = _create_weight_matrix(12, 8)
	weights["hidden_to_output"] = _create_weight_matrix(8, 6)
	return weights

func _create_weight_matrix(rows: int, cols: int) -> Array[Array[float]]:
	var matrix: Array[Array[float]] = []
	for i in range(rows):
		var row: Array[float] = []
		for j in range(cols):
			row.append(randf_range(-0.3, 0.3))
		matrix.append(row)
	return matrix

func _create_emergence_detector() -> Dictionary:
	return {
		"pattern_threshold": emergence_probability,
		"complexity_threshold": 0.8,
		"novelty_threshold": 0.7,
		"detection_history": [],
		"emergent_patterns": []
	}

func _create_complexity_analyzer() -> Dictionary:
	return {
		"current_complexity": 1.0,
		"complexity_history": [],
		"growth_rate": neural_complexity_growth,
		"complexity_factors": {
			"neural_networks": 0.3,
			"adaptive_systems": 0.25,
			"emergent_behaviors": 0.2,
			"world_interactions": 0.15,
			"cultural_evolution": 0.1
		}
	}

# === Adaptive Systems Setup ===

func _setup_adaptive_systems() -> void:
	adaptive_systems = {
		"resource_adaptation": _create_resource_adaptation_system(),
		"environmental_adaptation": _create_environmental_adaptation_system(),
		"social_adaptation": _create_social_adaptation_system(),
		"technological_adaptation": _create_technological_adaptation_system(),
		"cultural_adaptation": _create_cultural_adaptation_system()
	}
	
	print("[WorldEvolution] Adaptive systems initialized")

func _create_resource_adaptation_system() -> Dictionary:
	return {
		"adaptation_rate": 0.02,
		"efficiency_threshold": 0.7,
		"scarcity_response": 0.8,
		"abundance_response": 0.3,
		"adaptation_history": []
	}

func _create_environmental_adaptation_system() -> Dictionary:
	return {
		"adaptation_rate": 0.015,
		"stress_tolerance": 0.6,
		"resilience_factor": 0.8,
		"adaptation_range": 0.5,
		"adaptation_history": []
	}

func _create_social_adaptation_system() -> Dictionary:
	return {
		"adaptation_rate": 0.025,
		"cooperation_threshold": 0.7,
		"conflict_resolution": 0.6,
		"social_learning": 0.8,
		"adaptation_history": []
	}

func _create_technological_adaptation_system() -> Dictionary:
	return {
		"adaptation_rate": 0.03,
		"innovation_threshold": 0.6,
		"diffusion_rate": 0.7,
		"obsolescence_factor": 0.1,
		"adaptation_history": []
	}

func _create_cultural_adaptation_system() -> Dictionary:
	return {
		"adaptation_rate": 0.02,
		"tradition_strength": 0.7,
		"innovation_acceptance": 0.5,
		"cultural_transmission": 0.8,
		"adaptation_history": []
	}

# === Main Evolution Loop ===

func evolve_world() -> Dictionary:
	var evolution_results: Dictionary = {
		"adaptations_applied": [],
		"emergent_behaviors": [],
		"complexity_growth": 0.0,
		"evolution_score": 0.0,
		"timestamp": Time.get_unix_time_from_system()
	}
	
	# Update world state neurons
	_update_world_state_neurons()
	
	# Process evolution drivers
	_process_evolution_drivers()
	
	# Apply adaptations
	var adaptations = _apply_adaptations()
	evolution_results.adaptations_applied = adaptations
	
	# Detect emergent behaviors
	var emergent_behaviors = _detect_emergent_behaviors()
	evolution_results.emergent_behaviors = emergent_behaviors
	
	# Update complexity
	var complexity_growth = _update_system_complexity()
	evolution_results.complexity_growth = complexity_growth
	
	# Calculate evolution score
	evolution_results.evolution_score = _calculate_evolution_score(evolution_results)
	
	# Record evolution cycle
	_record_evolution_cycle(evolution_results)
	
	# Emit evolution event
	world_evolution_event.emit(evolution_results)
	
	neural_evolution_engine.evolution_cycles += 1
	
	return evolution_results

func _update_world_state_neurons() -> void:
	var world_state = _get_current_world_state()
	var neurons = neural_evolution_engine.evolution_matrix.world_state_neurons
	
	# Update neuron values based on world state
	neurons.population_pressure.value = world_state.get("population_pressure", 0.0)
	neurons.resource_depletion.value = world_state.get("resource_depletion", 0.0)
	neurons.environmental_stress.value = world_state.get("environmental_stress", 0.0)
	neurons.social_complexity.value = world_state.get("social_complexity", 0.0)
	neurons.technological_advancement.value = world_state.get("technological_advancement", 0.0)
	neurons.cultural_diversity.value = world_state.get("cultural_diversity", 0.0)
	
	# Apply activation functions
	for neuron_name in neurons:
		var neuron = neurons[neuron_name]
		neuron.activation = _apply_evolution_activation(neuron.value)
		neuron.evolution_rate = _calculate_evolution_rate(neuron)

func _get_current_world_state() -> Dictionary:
	var state: Dictionary = {}
	
	# Get population pressure
	if SettlementMemory:
		state.population_pressure = float(SettlementMemory.settlements.size()) / 50.0
	
	# Get resource depletion
	if WorldMemory:
		var resources = WorldMemory.get_resource_summary()
		var total_depletion = 0.0
		for resource in resources:
			total_depletion += (1.0 - resources[resource])
		state.resource_depletion = total_depletion / float(resources.size())
	
	# Get environmental stress
	if WorldAI and WorldAI.neural_world_matrix:
		var env_neurons = WorldAI.neural_world_matrix.environmental_neurons
		var stress_sum = 0.0
		for neuron_name in env_neurons:
			stress_sum += 1.0 - env_neurons[neuron_name].activation
		state.environmental_stress = stress_sum / float(env_neurons.size())
	
	# Get social complexity
	if CulturalMemory:
		state.social_complexity = CulturalMemory.get_maturity_level()
	
	# Get technological advancement
	if WorldAI:
		state.technological_advancement = float(WorldAI.technological_tier) / 10.0
	
	# Get cultural diversity
	if CulturalMemory:
		state.cultural_diversity = CulturalMemory.get_diversity_index()
	
	return state

func _apply_evolution_activation(value: float) -> float:
	# Use tanh activation for evolution processing
	return tanh(value)

func _calculate_evolution_rate(neuron: Dictionary) -> float:
	var base_rate = evolution_rate
	var activation_factor = abs(neuron.activation)
	return base_rate * (1.0 + activation_factor)

func _process_evolution_drivers() -> void:
	var neurons = neural_evolution_engine.evolution_matrix.world_state_neurons
	var drivers = neural_evolution_engine.evolution_matrix.evolution_drivers
	var connections = neural_evolution_engine.evolution_matrix.interconnections
	
	# Update driver strengths based on neuron activations
	for state_name in neurons:
		var neuron = neurons[state_name]
		
		for driver_name in drivers:
			var driver = drivers[driver_name]
			var connection_id = "%s_to_%s" % [state_name, driver_name]
			
			if connections.has(connection_id):
				var connection = connections[connection_id]
				var influence = neuron.activation * connection.weight
				driver.strength += influence * driver.adaptation_rate
				driver.strength = clamp(driver.strength, 0.0, 2.0)

func _apply_adaptations() -> Array[Dictionary]:
	var adaptations_applied: Array[Dictionary] = []
	
	# Process each adaptive system
	for system_name in adaptive_systems:
		var system = adaptive_systems[system_name]
		var adaptation = _calculate_system_adaptation(system_name, system)
		
		if adaptation.adaptation_strength > adaptation_threshold:
			_apply_system_adaptation(system_name, adaptation)
			adaptations_applied.append(adaptation)
	
	return adaptations_applied

func _calculate_system_adaptation(system_name: String, system: Dictionary) -> Dictionary:
	var adaptation: Dictionary = {
		"system": system_name,
		"adaptation_strength": 0.0,
		"adaptation_type": "none",
		"adaptation_details": {}
	}
	
	# Get relevant world state factors
	var world_state = _get_current_world_state()
	
	match system_name:
		"resource_adaptation":
			adaptation = _calculate_resource_adaptation(world_state, system)
		"environmental_adaptation":
			adaptation = _calculate_environmental_adaptation(world_state, system)
		"social_adaptation":
			adaptation = _calculate_social_adaptation(world_state, system)
		"technological_adaptation":
			adaptation = _calculate_technological_adaptation(world_state, system)
		"cultural_adaptation":
			adaptation = _calculate_cultural_adaptation(world_state, system)
	
	return adaptation

func _calculate_resource_adaptation(world_state: Dictionary, system: Dictionary) -> Dictionary:
	var adaptation: Dictionary = {
		"system": "resource_adaptation",
		"adaptation_strength": 0.0,
		"adaptation_type": "none",
		"adaptation_details": {}
	}
	
	var resource_depletion = world_state.get("resource_depletion", 0.0)
	var population_pressure = world_state.get("population_pressure", 0.0)
	
	# Calculate adaptation strength
	adaptation.adaptation_strength = (resource_depletion * system.scarcity_response + 
									population_pressure * system.abundance_response) * system.adaptation_rate
	
	# Determine adaptation type
	if resource_depletion > 0.7:
		adaptation.adaptation_type = "efficiency_improvement"
		adaptation.adaptation_details = {
			"target_efficiency": 0.8,
			"resource_prioritization": true
		}
	elif population_pressure > 0.6:
		adaptation.adaptation_type = "resource_expansion"
		adaptation.adaptation_details = {
			"expansion_rate": 0.1,
			"exploration_incentive": true
		}
	
	return adaptation

func _calculate_environmental_adaptation(world_state: Dictionary, system: Dictionary) -> Dictionary:
	var adaptation: Dictionary = {
		"system": "environmental_adaptation",
		"adaptation_strength": 0.0,
		"adaptation_type": "none",
		"adaptation_details": {}
	}
	
	var environmental_stress = world_state.get("environmental_stress", 0.0)
	
	adaptation.adaptation_strength = environmental_stress * system.adaptation_rate
	
	if environmental_stress > system.stress_tolerance:
		adaptation.adaptation_type = "resilience_building"
		adaptation.adaptation_details = {
			"resilience_target": system.resilience_factor,
			"adaptation_range": system.adaptation_range
		}
	
	return adaptation

func _calculate_social_adaptation(world_state: Dictionary, system: Dictionary) -> Dictionary:
	var adaptation: Dictionary = {
		"system": "social_adaptation",
		"adaptation_strength": 0.0,
		"adaptation_type": "none",
		"adaptation_details": {}
	}
	
	var social_complexity = world_state.get("social_complexity", 0.0)
	var cultural_diversity = world_state.get("cultural_diversity", 0.0)
	
	adaptation.adaptation_strength = (social_complexity + cultural_diversity) * system.adaptation_rate
	
	if social_complexity > system.cooperation_threshold:
		adaptation.adaptation_type = "cooperation_enhancement"
		adaptation.adaptation_details = {
			"cooperation_level": system.cooperation_threshold,
			"conflict_resolution": system.conflict_resolution
		}
	
	return adaptation

func _calculate_technological_adaptation(world_state: Dictionary, system: Dictionary) -> Dictionary:
	var adaptation: Dictionary = {
		"system": "technological_adaptation",
		"adaptation_strength": 0.0,
		"adaptation_type": "none",
		"adaptation_details": {}
	}
	
	var technological_advancement = world_state.get("technological_advancement", 0.0)
	var population_pressure = world_state.get("population_pressure", 0.0)
	
	adaptation.adaptation_strength = (technological_advancement + population_pressure) * system.adaptation_rate
	
	if technological_advancement > system.innovation_threshold:
		adaptation.adaptation_type = "innovation_acceleration"
		adaptation.adaptation_details = {
			"innovation_rate": system.innovation_threshold,
			"diffusion_rate": system.diffusion_rate
		}
	
	return adaptation

func _calculate_cultural_adaptation(world_state: Dictionary, system: Dictionary) -> Dictionary:
	var adaptation: Dictionary = {
		"system": "cultural_adaptation",
		"adaptation_strength": 0.0,
		"adaptation_type": "none",
		"adaptation_details": {}
	}
	
	var cultural_diversity = world_state.get("cultural_diversity", 0.0)
	var social_complexity = world_state.get("social_complexity", 0.0)
	
	adaptation.adaptation_strength = (cultural_diversity + social_complexity) * system.adaptation_rate
	
	if cultural_diversity > system.tradition_strength:
		adaptation.adaptation_type = "cultural_synthesis"
		adaptation.adaptation_details = {
			"tradition_strength": system.tradition_strength,
			"innovation_acceptance": system.innovation_acceptance
		}
	
	return adaptation

func _apply_system_adaptation(system_name: String, adaptation: Dictionary) -> void:
	# Apply adaptation effects to the world
	match adaptation.adaptation_type:
		"efficiency_improvement":
			_apply_efficiency_improvement(adaptation.adaptation_details)
		"resource_expansion":
			_apply_resource_expansion(adaptation.adaptation_details)
		"resilience_building":
			_apply_resilience_building(adaptation.adaptation_details)
		"cooperation_enhancement":
			_apply_cooperation_enhancement(adaptation.adaptation_details)
		"innovation_acceleration":
			_apply_innovation_acceleration(adaptation.adaptation_details)
		"cultural_synthesis":
			_apply_cultural_synthesis(adaptation.adaptation_details)
	
	# Record adaptation in system history
	var system = adaptive_systems[system_name]
	if not system.has("adaptation_history"):
		system.adaptation_history = []
	
	system.adaptation_history.append({
		"timestamp": Time.get_unix_time_from_system(),
		"adaptation": adaptation
	})

func _apply_efficiency_improvement(details: Dictionary) -> void:
	# Improve resource efficiency
	if WorldAI:
		var resources = WorldAI.resource_distribution
		for resource in resources:
			resources[resource] *= 1.1  # 10% efficiency improvement

func _apply_resource_expansion(details: Dictionary) -> void:
	# Expand resource availability
	if WorldAI:
		var resources = WorldAI.resource_distribution
		for resource in resources:
			resources[resource] *= 1.05  # 5% expansion

func _apply_resilience_building(details: Dictionary) -> void:
	# Build environmental resilience
	if WorldAI:
		WorldAI.environmental_stability *= 1.02  # 2% resilience improvement

func _apply_cooperation_enhancement(details: Dictionary) -> void:
	# Enhance social cooperation
	if CulturalMemory:
		# This would update cultural cooperation metrics
		pass

func _apply_innovation_acceleration(details: Dictionary) -> void:
	# Accelerate technological innovation
	if WorldAI:
		WorldAI.tech_innovation_rate *= 1.05  # 5% innovation acceleration

func _apply_cultural_synthesis(details: Dictionary) -> void:
	# Promote cultural synthesis
	if CulturalMemory:
		# This would update cultural synthesis metrics
		pass

func _detect_emergent_behaviors() -> Array[Dictionary]:
	var emergent_behaviors: Array[Dictionary] = []
	
	# Analyze current system state for emergent patterns
	var current_state = _get_current_world_state()
	var complexity_score = _calculate_system_complexity()
	
	# Check for emergence conditions
	if complexity_score > neural_evolution_engine.evolution_matrix.complexity_neurons.system_complexity.current_level * 1.2:
		var emergent_behavior = _create_emergent_behavior(current_state, complexity_score)
		emergent_behaviors.append(emergent_behavior)
		emergent_patterns.append(emergent_behavior)
		
		# Emit emergent behavior signal
		emergent_behavior_detected.emit(emergent_behavior)
	
	return emergent_behaviors

func _create_emergent_behavior(world_state: Dictionary, complexity_score: float) -> Dictionary:
	var behavior: Dictionary = {
		"id": "EMERGENT_%08X" % [randi() % 100000000],
		"type": "adaptive_pattern",
		"complexity_score": complexity_score,
		"world_state": world_state,
		"behavior_pattern": _generate_behavior_pattern(world_state),
		"emergence_time": Time.get_unix_time_from_system(),
		"stability": 0.5,
		"influence_radius": 50.0
	}
	
	return behavior

func _generate_behavior_pattern(world_state: Dictionary) -> Dictionary:
	var pattern: Dictionary = {
		"primary_driver": "unknown",
		"secondary_driver": "unknown",
		"behavior_characteristics": []
	}
	
	# Determine primary driver based on world state
	var max_value = 0.0
	var primary_driver = ""
	
	for state_name in world_state:
		if world_state[state_name] > max_value:
			max_value = world_state[state_name]
			primary_driver = state_name
	
	pattern.primary_driver = primary_driver
	
	# Generate behavior characteristics
	match primary_driver:
		"population_pressure":
			pattern.behavior_characteristics = ["crowding_response", "resource_competition", "territorial_expansion"]
		"resource_depletion":
			pattern.behavior_characteristics = ["conservation_behavior", "alternative_resource_seeking", "efficiency_optimization"]
		"environmental_stress":
			pattern.behavior_characteristics = ["adaptation_response", "migration_tendency", "resilience_building"]
		"social_complexity":
			pattern.behavior_characteristics = ["cooperation_formation", "social_hierarchy", "cultural_development"]
		"technological_advancement":
			pattern.behavior_characteristics = ["innovation_adoption", "tool_development", "knowledge_sharing"]
		"cultural_diversity":
			pattern.behavior_characteristics = ["cultural_exchange", "tradition_preservation", "synthesis_creation"]
	
	return pattern

func _update_system_complexity() -> float:
	var analyzer = neural_evolution_engine.evolution_matrix.complexity_neurons
	var current_complexity = analyzer.system_complexity.current_level
	
	# Calculate new complexity based on various factors
	var complexity_growth = 0.0
	
	# Neural network complexity growth
	if AIAgentManager and AIAgentManager.neural_matrix:
		var neural_connections = 0
		for connection_key in AIAgentManager.neural_matrix.connections:
			neural_connections += AIAgentManager.neural_matrix.connections[connection_key].size()
		complexity_growth += float(neural_connections) / 10000.0 * analyzer.complexity_factors.neural_networks
	
	# Adaptive systems complexity
	var active_adaptations = 0
	for system_name in adaptive_systems:
		var system = adaptive_systems[system_name]
		if system.has("adaptation_history"):
			active_adaptations += system.adaptation_history.size()
	complexity_growth += float(active_adaptations) / 100.0 * analyzer.complexity_factors.adaptive_systems
	
	# Emergent behaviors complexity
	complexity_growth += float(emergent_patterns.size()) / 50.0 * analyzer.complexity_factors.emergent_behaviors
	
	# Apply growth rate
	var new_complexity = current_complexity + complexity_growth * analyzer.growth_rate
	
	# Update complexity values
	analyzer.system_complexity.current_level = new_complexity
	analyzer.neural_complexity.current_level = new_complexity * 1.1
	analyzer.behavioral_complexity.current_level = new_complexity * 1.05
	analyzer.environmental_complexity.current_level = new_complexity * 0.95
	
	# Record complexity history
	if not analyzer.has("complexity_history"):
		analyzer.complexity_history = []
	
	analyzer.complexity_history.append({
		"timestamp": Time.get_unix_time_from_system(),
		"system_complexity": new_complexity,
		"neural_complexity": analyzer.neural_complexity.current_level,
		"behavioral_complexity": analyzer.behavioral_complexity.current_level,
		"environmental_complexity": analyzer.environmental_complexity.current_level
	})
	
	# Keep only recent history
	if analyzer.complexity_history.size() > 1000:
		analyzer.complexity_history = analyzer.complexity_history.slice(-1000)
	
	return complexity_growth

func _calculate_system_complexity() -> float:
	var analyzer = neural_evolution_engine.evolution_matrix.complexity_neurons
	var total_complexity = 0.0
	var total_weight = 0.0
	
	for complexity_name in analyzer:
		if complexity_name.ends_with("_complexity"):
			var complexity_data = analyzer[complexity_name]
			var weight = analyzer.complexity_factors.get(complexity_name.replace("_complexity", ""), 0.2)
			total_complexity += complexity_data.current_level * weight
			total_weight += weight
	
	return total_complexity / total_weight if total_weight > 0 else 1.0

func _calculate_evolution_score(evolution_results: Dictionary) -> float:
	var score = 0.0
	
	# Score based on adaptations applied
	score += float(evolution_results.adaptations_applied.size()) * 0.2
	
	# Score based on emergent behaviors
	score += float(evolution_results.emergent_behaviors.size()) * 0.3
	
	# Score based on complexity growth
	score += evolution_results.complexity_growth * 0.5
	
	return clamp(score, 0.0, 1.0)

func _record_evolution_cycle(evolution_results: Dictionary) -> void:
	var cycle_record: Dictionary = {
		"cycle_number": neural_evolution_engine.evolution_cycles,
		"timestamp": evolution_results.timestamp,
		"results": evolution_results,
		"world_state": _get_current_world_state(),
		"complexity_metrics": {
			"system_complexity": neural_evolution_engine.evolution_matrix.complexity_neurons.system_complexity.current_level,
			"neural_complexity": neural_evolution_engine.evolution_matrix.complexity_neurons.neural_complexity.current_level,
			"behavioral_complexity": neural_evolution_engine.evolution_matrix.complexity_neurons.behavioral_complexity.current_level,
			"environmental_complexity": neural_evolution_engine.evolution_matrix.complexity_neurons.environmental_complexity.current_level
		}
	}
	
	evolution_history.append(cycle_record)
	
	# Keep only recent history
	if evolution_history.size() > 1000:
		evolution_history = evolution_history.slice(-1000)

# === Public Interface ===

func get_evolution_status() -> Dictionary:
	return {
		"evolution_cycles": neural_evolution_engine.evolution_cycles,
		"current_complexity": _calculate_system_complexity(),
		"emergent_patterns_count": emergent_patterns.size(),
		"active_adaptations": _get_active_adaptations(),
		"evolution_score": _calculate_overall_evolution_score()
	}

func _get_active_adaptations() -> Array[String]:
	var active: Array[String] = []
	for system_name in adaptive_systems:
		var system = adaptive_systems[system_name]
		if system.has("adaptation_history") and system.adaptation_history.size() > 0:
			var last_adaptation = system.adaptation_history[-1]
			var time_since = Time.get_unix_time_from_system() - last_adaptation.timestamp
			if time_since < 3600:  # Active within last hour
				active.append(system_name)
	return active

func _calculate_overall_evolution_score() -> float:
	if evolution_history.size() == 0:
		return 0.0
	
	var recent_scores: Array[float] = []
	for i in range(max(0, evolution_history.size() - 10), evolution_history.size()):
		recent_scores.append(evolution_history[i].results.evolution_score)
	
	if recent_scores.size() == 0:
		return 0.0
	
	var total_score = 0.0
	for score in recent_scores:
		total_score += score
	
	return total_score / float(recent_scores.size())
