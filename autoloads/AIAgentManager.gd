extends Node
## AI Agent Manager - Advanced Neural Network Matrix Integration
## Provides sophisticated AI decision-making with HeelKawn Universe neural network matrix


class SettlementAIShim:
	extends RefCounted

	var settlement_id: int = -1
	var settlement_name: String = ""
	var location: Vector2i = Vector2i.ZERO

	func _init(id: int, name: String, pos: Vector2i) -> void:
		settlement_id = id
		settlement_name = name
		location = pos

	func update() -> void:
		pass

	func add_resident(_agent_id: int) -> void:
		pass

signal agent_spawned(agent_id: int, agent_type: AIAgent.AgentType)
signal agent_goal_completed(agent_id: int, goal_type: String)
signal agent_action_executed(agent_id: int, action_type: String, success: bool)
signal neural_network_updated(network_state: Dictionary)

# Core AI Systems
var agents: Dictionary = {}  # agent_id -> AIAgent
var civilization_agents: Dictionary = {}  # agent_id -> CivilizationAgent
var agent_text_overlays: Dictionary = {}  # agent_id -> Node
var next_agent_id: int = 1000  # Start AI agent IDs at 1000 to avoid conflicts
var max_agents: int = 10
var update_frequency: int = 10  # Update agents every N ticks (balanced for performance)
var last_update_tick: int = 0
var enabled: bool = false
var show_agent_overlays: bool = true

# Advanced Neural Network Matrix Systems
var world_ai: Node
var settlement_ai_system: Dictionary = {}  # settlement_id -> settlement AI instances
var civilization_mode: bool = false  # Disabled by default for runtime stability

# Neural Network Matrix Components
var neural_matrix: Dictionary = {}  # Core neural network matrix data
var learning_algorithms: Dictionary = {}  # Learning algorithm implementations
var pattern_recognition: Dictionary = {}  # Pattern recognition systems
var predictive_models: Dictionary = {}  # Predictive modeling for world events
var collective_intelligence: Dictionary = {}  # Shared intelligence across agents

# Neural Network Parameters
var neural_complexity: float = 1.0  # Complexity multiplier for neural calculations
var learning_rate: float = 0.01  # Learning rate for neural network adaptation
var pattern_threshold: float = 0.7  # Threshold for pattern recognition
var prediction_accuracy: float = 0.85  # Target accuracy for predictions

# Agent spawning configuration
var strategic_agent_count: int = 2
var tactical_agent_count: int = 4
var reactive_agent_count: int = 2

func _ready() -> void:
	GameManager.game_tick.connect(_on_game_tick)
	if not enabled:
		if OS.is_debug_build():
			print("[AIAgentManager] Disabled (set enabled=true to opt in).")
		return
	
	# Initialize advanced neural network matrix systems
	_initialize_neural_network_matrix()
	_initialize_learning_algorithms()
	_initialize_pattern_recognition()
	_initialize_predictive_models()
	_initialize_collective_intelligence()
	
	# Initialize enhanced AI systems
	if civilization_mode:
		world_ai = WorldAI  # Reference to autoload singleton
		_initialize_settlement_system()
	
	_spawn_initial_agents()


# === Neural Network Matrix Initialization ===

func _initialize_neural_network_matrix() -> void:
	# Core neural network matrix structure
	neural_matrix = {
		"layers": {
			"input": {"size": 64, "neurons": []},
			"hidden1": {"size": 128, "neurons": []},
			"hidden2": {"size": 64, "neurons": []},
			"output": {"size": 32, "neurons": []}
		},
		"connections": {},
		"weights": {},
		"biases": {},
		"activation_functions": ["relu", "sigmoid", "tanh"],
		"learning_rate": learning_rate,
		"complexity": neural_complexity
	}
	
	# Initialize neurons for each layer
	for layer_name in neural_matrix.layers:
		var layer = neural_matrix.layers[layer_name]
		for i in range(layer.size):
			layer.neurons.append({
				"id": "%s_%d" % [layer_name, i],
				"value": 0.0,
				"activation": 0.0,
				"connections": []
			})
	
	# Initialize neural connections between layers
	_initialize_neural_connections()
	
	print("[AIAgentManager] Neural network matrix initialized with %d layers" % neural_matrix.layers.size())


func _initialize_neural_connections() -> void:
	var layer_names = neural_matrix.layers.keys()
	
	for i in range(layer_names.size() - 1):
		var source_layer = layer_names[i]
		var target_layer = layer_names[i + 1]
		
		neural_matrix.connections[source_layer + "_to_" + target_layer] = {}
		
		for source_neuron in neural_matrix.layers[source_layer].neurons:
			for target_neuron in neural_matrix.layers[target_layer].neurons:
				var connection_id = "%s_%s" % [source_neuron.id, target_neuron.id]
				neural_matrix.connections[source_layer + "_to_" + target_layer][connection_id] = {
					"weight": randf_range(-0.5, 0.5),
					"source": source_neuron.id,
					"target": target_neuron.id,
					"strength": 1.0
				}


func _initialize_learning_algorithms() -> void:
	learning_algorithms = {
		"backpropagation": {
			"enabled": true,
			"learning_rate": learning_rate,
			"momentum": 0.9,
			"decay": 0.0001
		},
		"reinforcement_learning": {
			"enabled": true,
			"exploration_rate": 0.1,
			"discount_factor": 0.95,
			"learning_rate": 0.001
		},
		"genetic_algorithm": {
			"enabled": true,
			"mutation_rate": 0.01,
			"crossover_rate": 0.7,
			"population_size": 50
		},
		"hebbian_learning": {
			"enabled": true,
			"learning_rate": 0.01,
			"decay_rate": 0.001
		}
	}
	
	print("[AIAgentManager] Learning algorithms initialized")


func _initialize_pattern_recognition() -> void:
	pattern_recognition = {
		"world_patterns": {
			"resource_cycles": [],
			"settlement_growth": [],
			"climate_changes": [],
			"cultural_shifts": []
		},
		"behavior_patterns": {
			"agent_decisions": [],
			"settlement_strategies": [],
			"trade_routes": [],
			"conflict_resolution": []
		},
		"threshold": pattern_threshold,
		"confidence_scores": {}
	}
	
	print("[AIAgentManager] Pattern recognition systems initialized")


func _initialize_predictive_models() -> void:
	predictive_models = {
		"resource_prediction": {
			"model_type": "neural_network",
			"accuracy": prediction_accuracy,
			"features": ["population", "technology", "environment"],
			"predictions": []
		},
		"settlement_growth": {
			"model_type": "time_series",
			"accuracy": prediction_accuracy,
			"features": ["resources", "culture", "economy"],
			"predictions": []
		},
		"world_events": {
			"model_type": "probabilistic",
			"accuracy": prediction_accuracy,
			"features": ["history", "current_state", "trends"],
			"predictions": []
		}
	}
	
	print("[AIAgentManager] Predictive models initialized")


func _initialize_collective_intelligence() -> void:
	collective_intelligence = {
		"shared_memory": {},
		"emergent_behaviors": [],
		"swarm_intelligence": {
			"consensus_threshold": 0.7,
			"communication_range": 100.0,
			"influence_radius": 50.0
		},
		"knowledge_graph": {
			"nodes": {},
			"edges": {},
			"weights": {}
		}
	}
	
	print("[AIAgentManager] Collective intelligence initialized")


# === Neural Network Processing ===

func process_neural_network(input_data: Array[float]) -> Array[float]:
	# Forward propagation through neural network
	var current_values = input_data.duplicate()
	
	var layer_names = neural_matrix.layers.keys()
	for i in range(layer_names.size()):
		var layer_name = layer_names[i]
		var layer = neural_matrix.layers[layer_name]
		var next_values: Array[float] = []
		
		for neuron in layer.neurons:
			var neuron_value = 0.0
			
			# Calculate weighted sum from previous layer
			if i == 0:  # Input layer
				var neuron_index = layer.neurons.find(neuron)
				if neuron_index < current_values.size():
					neuron_value = current_values[neuron_index]
			else:
				# Process connections from previous layer
				var prev_layer_name = layer_names[i - 1]
				var connection_key = prev_layer_name + "_to_" + layer_name
				
				if neural_matrix.connections.has(connection_key):
					for connection_id in neural_matrix.connections[connection_key]:
						var connection = neural_matrix.connections[connection_id]
						if connection.source in current_values:
							neuron_value += current_values[current_values.find(connection.source)] * connection.weight
			
			# Apply activation function
			neuron.activation = _apply_activation_function(neuron_value, i)
			next_values.append(neuron.activation)
		
		current_values = next_values
	
	return current_values


func _apply_activation_function(value: float, layer_index: int) -> float:
	var activation_functions = neural_matrix.activation_functions
	var func_index = layer_index % activation_functions.size()
	
	match activation_functions[func_index]:
		"relu":
			return max(0.0, value)
		"sigmoid":
			return 1.0 / (1.0 + exp(-value))
		"tanh":
			return tanh(value)
		_:
			return value


func train_neural_network(input_data: Array[float], target_output: Array[float]) -> void:
	# Backpropagation training
	var predicted_output = process_neural_network(input_data)
	var error = _calculate_error(predicted_output, target_output)
	
	# Update weights based on error
	if learning_algorithms.backpropagation.enabled:
		_backpropagate_error(error)
	
	# Record training data
	_record_training_session(input_data, target_output, predicted_output, error)


func _calculate_error(predicted: Array[float], target: Array[float]) -> Array[float]:
	var error: Array[float] = []
	for i in range(min(predicted.size(), target.size())):
		error.append(target[i] - predicted[i])
	return error


func _backpropagate_error(error: Array[float]) -> void:
	# Simplified backpropagation
	var learning_rate = learning_algorithms.backpropagation.learning_rate
	
	for connection_key in neural_matrix.connections:
		var connections = neural_matrix.connections[connection_key]
		for connection_id in connections:
			var connection = connections[connection_id]
			# Update weights based on error gradient
			connection.weight += learning_rate * error[0] * connection.strength
			# Apply weight decay
			connection.weight *= (1.0 - learning_algorithms.backpropagation.decay)


func _record_training_session(input_data: Array[float], target: Array[float], predicted: Array[float], error: Array[float]) -> void:
	var training_record = {
		"timestamp": GameManager.tick_count,
		"input": input_data,
		"target": target,
		"predicted": predicted,
		"error": error,
		"accuracy": _calculate_accuracy(predicted, target)
	}
	
	# Store in collective intelligence
	if not collective_intelligence.shared_memory.has("training_history"):
		collective_intelligence.shared_memory.training_history = []
	
	collective_intelligence.shared_memory.training_history.append(training_record)


func _calculate_accuracy(predicted: Array[float], target: Array[float]) -> float:
	if predicted.size() == 0 or target.size() == 0:
		return 0.0
	
	var total_error = 0.0
	for i in range(min(predicted.size(), target.size())):
		total_error += abs(predicted[i] - target[i])
	
	var mean_error = total_error / min(predicted.size(), target.size())
	return max(0.0, 1.0 - mean_error)


# === Pattern Recognition ===

func recognize_patterns(world_state: Dictionary) -> Dictionary:
	var recognized_patterns: Dictionary = {}
	
	# Analyze resource cycles
	var resource_pattern = _analyze_resource_pattern(world_state)
	if resource_pattern.confidence >= pattern_threshold:
		recognized_patterns.resource_cycle = resource_pattern
	
	# Analyze settlement growth
	var settlement_pattern = _analyze_settlement_pattern(world_state)
	if settlement_pattern.confidence >= pattern_threshold:
		recognized_patterns.settlement_growth = settlement_pattern
	
	# Analyze cultural shifts
	var cultural_pattern = _analyze_cultural_pattern(world_state)
	if cultural_pattern.confidence >= pattern_threshold:
		recognized_patterns.cultural_shift = cultural_pattern
	
	return recognized_patterns


func _analyze_resource_pattern(world_state: Dictionary) -> Dictionary:
	var pattern = {
		"type": "resource_cycle",
		"confidence": 0.0,
		"prediction": {},
		"features": {}
	}
	
	# Extract resource data from world state
	if world_state.has("resources"):
		var resources = world_state.resources
		pattern.features.current_levels = resources
		
		# Compare with historical data
		if pattern_recognition.world_patterns.resource_cycles.size() > 0:
			var historical_data = pattern_recognition.world_patterns.resource_cycles
			var trend = _calculate_resource_trend(historical_data, resources)
			pattern.prediction = trend
			pattern.confidence = _calculate_pattern_confidence(trend, resources)
	
	return pattern


func _calculate_resource_trend(historical: Array, current: Dictionary) -> Dictionary:
	var trend = {
		"direction": "stable",
		"magnitude": 0.0,
		"next_cycle": "unknown"
	}
	
	if historical.size() > 1:
		var recent = historical[-1]
		var older = historical[-2]
		
		# Simple trend calculation
		for resource in current:
			if recent.has(resource) and older.has(resource):
				var change = current[resource] - recent[resource]
				var historical_change = recent[resource] - older[resource]
				
				if abs(change) > abs(historical_change) * 1.5:
					trend.direction = "accelerating"
				elif abs(change) < abs(historical_change) * 0.5:
					trend.direction = "decelerating"
				else:
					trend.direction = "stable"
				
				trend.magnitude = abs(change)
	
	return trend


func _calculate_pattern_confidence(trend: Dictionary, current: Dictionary) -> float:
	var confidence = 0.5  # Base confidence
	
	# Increase confidence based on pattern consistency
	if trend.has("direction") and trend.direction != "unknown":
		confidence += 0.2
	
	# Increase confidence based on data completeness
	if current.size() >= 3:
		confidence += 0.2
	
	# Increase confidence based on historical data
	if pattern_recognition.world_patterns.resource_cycles.size() > 5:
		confidence += 0.1
	
	return min(confidence, 1.0)


func _analyze_settlement_pattern(world_state: Dictionary) -> Dictionary:
	var pattern = {
		"type": "settlement_growth",
		"confidence": 0.0,
		"prediction": {},
		"features": {}
	}
	
	# Extract settlement data from world state
	if world_state.has("settlements"):
		var settlements = world_state.settlements
		pattern.features.current_settlements = settlements
		
		# Compare with historical data
		if pattern_recognition.behavior_patterns.settlement_strategies.size() > 0:
			var historical_data = pattern_recognition.behavior_patterns.settlement_strategies
			var trend = _calculate_settlement_trend(historical_data, settlements)
			pattern.prediction = trend
			pattern.confidence = _calculate_pattern_confidence(trend, settlements)
	
	return pattern


func _analyze_cultural_pattern(world_state: Dictionary) -> Dictionary:
	var pattern = {
		"type": "cultural_shift",
		"confidence": 0.0,
		"prediction": {},
		"features": {}
	}
	
	# Extract cultural data from world state
	if world_state.has("culture"):
		var culture = world_state.culture
		pattern.features.current_culture = culture
		
		# Compare with historical data
		if pattern_recognition.world_patterns.cultural_shifts.size() > 0:
			var historical_data = pattern_recognition.world_patterns.cultural_shifts
			var trend = _calculate_cultural_trend(historical_data, culture)
			pattern.prediction = trend
			pattern.confidence = _calculate_pattern_confidence(trend, culture)
	
	return pattern


func _calculate_settlement_trend(historical: Array, current: Dictionary) -> Dictionary:
	var trend = {
		"direction": "stable",
		"growth_rate": 0.0,
		"next_phase": "unknown"
	}
	
	if historical.size() > 1:
		var recent = historical[-1]
		var older = historical[-2]
		
		# Simple settlement growth trend calculation
		var current_count = current.get("count", 0)
		var recent_count = recent.get("count", 0)
		var older_count = older.get("count", 0)
		
		var current_change = current_count - recent_count
		var historical_change = recent_count - older_count
		
		if current_change > historical_change * 1.5:
			trend.direction = "accelerating_growth"
		elif current_change < historical_change * 0.5:
			trend.direction = "decelerating_growth"
		else:
			trend.direction = "stable_growth"
		
		trend.growth_rate = current_change
	
	return trend


func _calculate_cultural_trend(historical: Array, current: Dictionary) -> Dictionary:
	var trend = {
		"direction": "stable",
		"diversity_change": 0.0,
		"next_shift": "unknown"
	}
	
	if historical.size() > 1:
		var recent = historical[-1]
		var older = historical[-2]
		
		# Simple cultural trend calculation
		var current_diversity = current.get("diversity", 0.0)
		var recent_diversity = recent.get("diversity", 0.0)
		var older_diversity = older.get("diversity", 0.0)
		
		var current_change = current_diversity - recent_diversity
		var historical_change = recent_diversity - older_diversity
		
		if abs(current_change) > abs(historical_change) * 1.5:
			trend.direction = "rapid_shift"
		elif abs(current_change) < abs(historical_change) * 0.5:
			trend.direction = "stabilizing"
		else:
			trend.direction = "gradual_shift"
		
		trend.diversity_change = current_change
	
	return trend


# === Predictive Modeling ===

func generate_predictions(world_state: Dictionary) -> Dictionary:
	var predictions: Dictionary = {}
	
	# Resource predictions
	if predictive_models.resource_prediction.enabled:
		predictions.resources = _predict_resources(world_state)
	
	# Settlement growth predictions
	if predictive_models.settlement_growth.enabled:
		predictions.settlements = _predict_settlement_growth(world_state)
	
	# World event predictions
	if predictive_models.world_events.enabled:
		predictions.events = _predict_world_events(world_state)
	
	return predictions


func _predict_resources(world_state: Dictionary) -> Dictionary:
	var prediction = {
		"type": "resource_prediction",
		"time_horizon": 100,  # ticks
		"accuracy": prediction_accuracy,
		"forecasts": {}
	}
	
	# Use neural network for prediction
	var input_features = _extract_resource_features(world_state)
	var neural_output = process_neural_network(input_features)
	
	# Convert neural output to resource forecasts
	var resource_types = ["food", "wood", "stone", "ore"]
	for i in range(min(resource_types.size(), neural_output.size())):
		var resource_type = resource_types[i]
		var predicted_value = neural_output[i] * 100.0  # Scale to appropriate range
		prediction.forecasts[resource_type] = {
			"current": world_state.get("resources", {}).get(resource_type, 0),
			"predicted": predicted_value,
			"trend": "increasing" if predicted_value > world_state.get("resources", {}).get(resource_type, 0) else "decreasing"
		}
	
	return prediction


func _extract_resource_features(world_state: Dictionary) -> Array[float]:
	var features: Array[float] = []
	
	# Population
	features.append(world_state.get("population", 0) / 100.0)
	
	# Technology level
	features.append(world_state.get("technology", 0) / 10.0)
	
	# Environmental factors
	features.append(world_state.get("environment", {}).get("fertility", 0.5))
	features.append(world_state.get("environment", {}).get("climate", 0.5))
	
	# Current resource levels
	var resources = world_state.get("resources", {})
	features.append(resources.get("food", 0) / 1000.0)
	features.append(resources.get("wood", 0) / 1000.0)
	features.append(resources.get("stone", 0) / 1000.0)
	features.append(resources.get("ore", 0) / 1000.0)
	
	# Pad to match input layer size
	while features.size() < 64:
		features.append(0.0)
	
	return features


func _predict_settlement_growth(world_state: Dictionary) -> Dictionary:
	var prediction = {
		"type": "settlement_growth",
		"time_horizon": 200,  # ticks
		"accuracy": prediction_accuracy,
		"forecasts": {}
	}
	
	# Use neural network for prediction
	var input_features = _extract_settlement_features(world_state)
	var neural_output = process_neural_network(input_features)
	
	# Convert neural output to settlement forecasts
	var settlement_metrics = ["new_settlements", "population_growth", "expansion_rate", "prosperity_index"]
	for i in range(min(settlement_metrics.size(), neural_output.size())):
		var metric = settlement_metrics[i]
		var predicted_value = neural_output[i] * 10.0  # Scale to appropriate range
		prediction.forecasts[metric] = {
			"current": world_state.get("settlements", {}).get(metric, 0),
			"predicted": predicted_value,
			"trend": "increasing" if predicted_value > world_state.get("settlements", {}).get(metric, 0) else "decreasing"
		}
	
	return prediction


func _predict_world_events(world_state: Dictionary) -> Dictionary:
	var prediction = {
		"type": "world_events",
		"time_horizon": 300,  # ticks
		"accuracy": prediction_accuracy,
		"forecasts": {}
	}
	
	# Use neural network for prediction
	var input_features = _extract_event_features(world_state)
	var neural_output = process_neural_network(input_features)
	
	# Convert neural output to event forecasts
	var event_types = ["natural_disaster", "technological_breakthrough", "cultural_shift", "resource_discovery", "conflict_escalation"]
	for i in range(min(event_types.size(), neural_output.size())):
		var event_type = event_types[i]
		var probability = neural_output[i]
		prediction.forecasts[event_type] = {
			"probability": probability,
			"urgency": "high" if probability > 0.8 else "medium" if probability > 0.5 else "low",
			"estimated_time": int(300 * (1.0 - probability))  # Sooner if more probable
		}
	
	return prediction


func _extract_settlement_features(world_state: Dictionary) -> Array[float]:
	var features: Array[float] = []
	
	# Population and settlement data
	features.append(world_state.get("population", 0) / 100.0)
	features.append(world_state.get("settlement_count", 0) / 20.0)
	
	# Economic factors
	features.append(world_state.get("prosperity", 0.0))
	features.append(world_state.get("trade_activity", 0.0))
	
	# Environmental factors
	features.append(world_state.get("environment", {}).get("fertility", 0.5))
	features.append(world_state.get("environment", {}).get("resources", 0.5))
	
	# Social factors
	features.append(world_state.get("social_stability", 0.5))
	features.append(world_state.get("cultural_development", 0.0))
	
	# Technology and infrastructure
	features.append(world_state.get("technology_level", 0) / 10.0)
	features.append(world_state.get("infrastructure", 0.0))
	
	# Pad to match input layer size
	while features.size() < 64:
		features.append(0.0)
	
	return features


func _extract_event_features(world_state: Dictionary) -> Array[float]:
	var features: Array[float] = []
	
	# World state factors
	features.append(world_state.get("population", 0) / 100.0)
	features.append(world_state.get("technology_level", 0) / 10.0)
	features.append(world_state.get("social_stability", 0.5))
	features.append(world_state.get("resource_pressure", 0.0))
	
	# Environmental factors
	features.append(world_state.get("environment", {}).get("stability", 0.5))
	features.append(world_state.get("climate_stress", 0.0))
	
	# Historical factors
	features.append(world_state.get("recent_events", 0) / 10.0)
	features.append(world_state.get("conflict_level", 0.0))
	
	# Cultural factors
	features.append(world_state.get("cultural_tension", 0.0))
	features.append(world_state.get("innovation_rate", 0.0))
	
	# Pad to match input layer size
	while features.size() < 64:
		features.append(0.0)
	
	return features


func _on_game_tick(tick: int) -> void:
	if not enabled:
		return
	
	var stride: int = 1
	if GameManager.game_speed >= 26.0:
		stride = 4
	elif GameManager.game_speed >= 12.0:
		stride = 2
	
	# Update enhanced AI systems
	if civilization_mode and tick % stride == 0:
		if world_ai:
			world_ai.update()
		
		for settlement_id in settlement_ai_system:
			var settlement = settlement_ai_system[settlement_id]
			settlement.update()
	
	# Update agents at specified frequency
	if tick - last_update_tick >= update_frequency * stride:
		_update_all_agents()
		last_update_tick = tick
	
	# Spawn new agents if under limit and conditions are met
	if tick % (600 * stride) == 0:  # Check every 600 ticks at base cadence
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
	var agent_id: int = next_agent_id
	next_agent_id += 1
	
	# Use base AIAgent class for now - enhanced agents will be added later
	var agent: AIAgent = AIAgent.new(agent_id, agent_type)
	
	agents[agent_id] = agent
	agent_spawned.emit(agent_id, agent_type)
	
	# Enhanced AI agent spawning
	if civilization_mode:
		var civ_agent: CivilizationAgent = CivilizationAgent.new(agent_id, agent_type)
		civilization_agents[agent_id] = civ_agent
	
	_try_incarnate_agent(agent)
	_create_agent_text_overlay(agent_id)
	
	return agent_id

func _remove_agent(agent_id: int) -> void:
	if agents.has(agent_id):
		agents.erase(agent_id)
		agent_text_overlays.erase(agent_id)
		
		# Remove enhanced AI agent if exists
		if civilization_agents.has(agent_id):
			civilization_agents.erase(agent_id)

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
			
			# Update enhanced AI agents if civilization mode is enabled
			if civilization_mode and civilization_agents.has(agent.agent_id):
				var civ_agent: CivilizationAgent = civilization_agents[agent.agent_id]
				civ_agent.update()

func _maintain_agent_population() -> void:
	# Remove dead agents
	var agents_to_remove: Array[int] = []
	
	for agent_id in agents:
		var agent: AIAgent = agents[agent_id]
		if agent.controlled_pawn_id >= 0:
			var pawn_obs: Dictionary = ObservationAPI.observe_pawn(agent.controlled_pawn_id)
			if not pawn_obs.has("error"):
				var pawn_health: float = pawn_obs.get("health", 0.0)
				if pawn_health <= 0.0:
					agents_to_remove.append(agent_id)
	
	# Remove agents
	for agent_id in agents_to_remove:
		_remove_agent(agent_id)
	
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

# === Enhanced AI System Methods ===

func _initialize_settlement_system() -> void:
	# Initialize settlement AI for existing settlements
	if SettlementMemory:
		for i in range(SettlementMemory.settlements.size()):
			var settlement_data: Dictionary = SettlementMemory.settlements[i]
			if settlement_data != null and settlement_data.has("center_region"):
				var settlement_id: int = settlement_data["center_region"]
				var settlement_ai = SettlementAIShim.new(settlement_id, "Settlement_%d" % settlement_id, Vector2i(0, 0))
				settlement_ai_system[settlement_id] = settlement_ai

# Enhanced AI update logic integrated into existing _update_all_agents function

func get_civilization_status() -> Dictionary:
	# Return status of civilization building progress
	var status: Dictionary = {
		"civilization_mode": civilization_mode,
		"total_agents": agents.size(),
		"civilization_agents": civilization_agents.size(),
		"settlement_ai_count": settlement_ai_system.size(),
		"world_age": world_ai.current_age if world_ai else -1,
		"technological_tier": world_ai.technological_tier if world_ai else -1
	}
	
	if world_ai:
		status["civilization_achievements"] = world_ai.civilization_achievements.size()
		status["active_settlements"] = world_ai.active_settlements.size()
	
	return status

func _add_agent_to_settlement(agent_id: int) -> void:
	# Find nearest settlement or add to existing
	var nearest_settlement_id: int = _find_nearest_settlement(agent_id)
	if nearest_settlement_id >= 0:
		var settlement = settlement_ai_system[nearest_settlement_id]
		settlement.add_resident(agent_id)

func _find_nearest_settlement(agent_id: int) -> int:
	# Simple implementation - return first settlement
	# In full implementation, would calculate distances
	for settlement_id in settlement_ai_system:
		return settlement_id
	return -1
#		return settlement_id
#	return -1
