class_name PawnNeuralNetwork
extends RefCounted

## Phase 2: Per-Pawn Neural Network for Decision Making
## Hidden internal state - opaque to players, only observable behaviors visible

# Network structure
var layers: Array = []  # Array of layer dictionaries
var connections: Dictionary = {}  # connection_id -> {weight, source, target, strength}
var activation_functions: Array = ["relu", "sigmoid", "tanh"]

# Learning parameters
var learning_rate: float = 0.01
var momentum: float = 0.9
var decay: float = 0.0001

# Network state (hidden/obfuscated)
var _internal_state: Dictionary = {}
var _obfuscation_key: int = 0

func _init(personality: Dictionary = {}) -> void:
	_obfuscation_key = WorldRNG.rangei(1000000, 9999999)
	_initialize_network_structure(personality)
	_initialize_connections()


## Initialize network structure based on personality
func _initialize_network_structure(personality: Dictionary) -> void:
	# Input layer size based on perception capabilities
	var input_size: int = 32
	
	# Hidden layer sizes influenced by personality
	var openness: float = personality.get("openness", 0.5)
	var conscientiousness: float = personality.get("conscientiousness", 0.5)
	
	var hidden1_size: int = int(64 + openness * 32)  # 64-96 neurons
	var hidden2_size: int = int(32 + conscientiousness * 16)  # 32-48 neurons
	var output_size: int = 16  # Action outputs
	
	layers = [
		{"size": input_size, "neurons": _create_neurons(input_size, "input")},
		{"size": hidden1_size, "neurons": _create_neurons(hidden1_size, "hidden1")},
		{"size": hidden2_size, "neurons": _create_neurons(hidden2_size, "hidden2")},
		{"size": output_size, "neurons": _create_neurons(output_size, "output")}
	]


## Create neurons for a layer
func _create_neurons(count: int, layer_name: String) -> Array:
	var neurons: Array = []
	for i in range(count):
		neurons.append({
			"id": "%s_%d" % [layer_name, i],
			"value": 0.0,
			"activation": 0.0,
			"bias": WorldRNG.range_for(
				StringName("neural:%s:%d:%d" % [layer_name, i, _obfuscation_key]),
				-0.5,
				0.5
			)
		})
	return neurons


## Initialize connections between layers
func _initialize_connections() -> void:
	for i in range(layers.size() - 1):
		var source_layer = layers[i]
		var target_layer = layers[i + 1]
		var connection_key: String = "%s_to_%s" % [source_layer.neurons[0].id.split("_")[0], target_layer.neurons[0].id.split("_")[0]]
		
		connections[connection_key] = {}
		
		for source_neuron in source_layer.neurons:
			for target_neuron in target_layer.neurons:
				var conn_id: String = "%s_%s" % [source_neuron.id, target_neuron.id]
				connections[connection_key][conn_id] = {
					"weight": WorldRNG.range_for(
						StringName("neural:conn:%s:%d" % [conn_id, _obfuscation_key]),
						-0.5,
						0.5
					),
					"source": source_neuron.id,
					"target": target_neuron.id,
					"strength": 1.0,
					"velocity": 0.0  # For momentum
				}


## Forward propagation through network
func forward_propagate(input_data: Array[float]) -> Array[float]:
	var current_values: Array[float] = input_data.duplicate()
	
	# Pad or truncate input to match input layer size
	while current_values.size() < layers[0].size:
		current_values.append(0.0)
	if current_values.size() > layers[0].size:
		current_values = current_values.slice(0, layers[0].size)
	
	for layer_idx in range(layers.size()):
		var layer = layers[layer_idx]
		var next_values: Array[float] = []
		
		for neuron_idx in range(layer.neurons.size()):
			var neuron = layer.neurons[neuron_idx]
			var neuron_value: float = 0.0
			
			if layer_idx == 0:
				# Input layer: use input values
				neuron_value = current_values[neuron_idx]
			else:
				# Hidden/output layers: weighted sum from previous layer
				var prev_layer_name = layers[layer_idx - 1].neurons[0].id.split("_")[0]
				var curr_layer_name = neuron.id.split("_")[0]
				var connection_key: String = "%s_to_%s" % [prev_layer_name, curr_layer_name]
				
				if connections.has(connection_key):
					for conn_id in connections[connection_key]:
						var conn = connections[connection_key][conn_id]
						var source_idx: int = _find_neuron_index(conn.source, layer_idx - 1)
						if source_idx >= 0 and source_idx < current_values.size():
							neuron_value += current_values[source_idx] * conn.weight
			
			# Apply activation function
			neuron.activation = _apply_activation(neuron_value, layer_idx)
			neuron.value = neuron_value
			next_values.append(neuron.activation)
		
		current_values = next_values
	
	# Store internal state (obfuscated)
	_store_internal_state(current_values)
	
	return current_values


## Find neuron index in a layer
func _find_neuron_index(neuron_id: String, layer_idx: int) -> int:
	if layer_idx >= layers.size():
		return -1
	
	var layer = layers[layer_idx]
	for i in range(layer.neurons.size()):
		if layer.neurons[i].id == neuron_id:
			return i
	return -1


## Apply activation function
func _apply_activation(value: float, layer_idx: int) -> float:
	var func_index: int = layer_idx % activation_functions.size()
	match activation_functions[func_index]:
		"relu":
			return max(0.0, value)
		"sigmoid":
			return 1.0 / (1.0 + exp(-value))
		"tanh":
			return tanh(value)
		_:
			return value


## Backpropagation training
func backpropagate(input_data: Array[float], target_output: Array[float]) -> float:
	var predicted_output = forward_propagate(input_data)
	var error = _calculate_error(predicted_output, target_output)
	
	# Calculate output layer gradients
	var output_gradients: Array[float] = []
	var output_layer = layers[-1]
	
	for i in range(output_layer.neurons.size()):
		var target: float = target_output[i] if i < target_output.size() else 0.0
		var predicted: float = predicted_output[i]
		var gradient: float = (predicted - target) * _sigmoid_derivative(predicted)
		output_gradients.append(gradient)
	
	# Backpropagate gradients through hidden layers
	var layer_gradients: Array[Array] = [output_gradients]
	
	for layer_idx in range(layers.size() - 2, 0, -1):
		var gradients: Array[float] = []
		var layer = layers[layer_idx]
		var next_layer = layers[layer_idx + 1]
		var next_gradients = layer_gradients[0]
		
		for neuron_idx in range(layer.neurons.size()):
			var gradient: float = 0.0
			
			for next_neuron_idx in range(next_layer.neurons.size()):
				var conn_id: String = "%s_%s" % [layer.neurons[neuron_idx].id, next_layer.neurons[next_neuron_idx].id]
				var layer_name = layer.neurons[0].id.split("_")[0]
				var next_layer_name = next_layer.neurons[0].id.split("_")[0]
				var connection_key: String = "%s_to_%s" % [layer_name, next_layer_name]
				
				if connections.has(connection_key) and connections[connection_key].has(conn_id):
					var weight = connections[connection_key][conn_id].weight
					gradient += next_gradients[next_neuron_idx] * weight
			
			gradient *= _relu_derivative(layer.neurons[neuron_idx].value)
			gradients.append(gradient)
		
		layer_gradients.insert(0, gradients)
	
	# Update weights with momentum
	_update_weights(layer_gradients)
	
	# Calculate mean squared error
	var mse: float = 0.0
	for i in range(min(predicted_output.size(), target_output.size())):
		mse += pow(predicted_output[i] - target_output[i], 2)
	mse /= float(max(predicted_output.size(), target_output.size()))
	
	return mse


## Calculate error between predicted and target
func _calculate_error(predicted: Array[float], target: Array[float]) -> Array[float]:
	var error: Array[float] = []
	for i in range(min(predicted.size(), target.size())):
		error.append(target[i] - predicted[i])
	return error


## Sigmoid derivative
func _sigmoid_derivative(x: float) -> float:
	var s: float = 1.0 / (1.0 + exp(-x))
	return s * (1.0 - s)


## ReLU derivative
func _relu_derivative(x: float) -> float:
	return 1.0 if x > 0.0 else 0.0


## Update weights with momentum
func _update_weights(layer_gradients: Array[Array]) -> void:
	for layer_idx in range(layers.size() - 1):
		var layer = layers[layer_idx]
		var next_layer = layers[layer_idx + 1]
		var gradients = layer_gradients[layer_idx]
		
		var layer_name = layer.neurons[0].id.split("_")[0]
		var next_layer_name = next_layer.neurons[0].id.split("_")[0]
		var connection_key: String = "%s_to_%s" % [layer_name, next_layer_name]
		
		if not connections.has(connection_key):
			continue
		
		for neuron_idx in range(layer.neurons.size()):
			for next_neuron_idx in range(next_layer.neurons.size()):
				var conn_id: String = "%s_%s" % [layer.neurons[neuron_idx].id, next_layer.neurons[next_neuron_idx].id]
				
				if not connections[connection_key].has(conn_id):
					continue
				
				var conn = connections[connection_key][conn_id]
				var gradient: float = gradients[next_neuron_idx] if next_neuron_idx < gradients.size() else 0.0
				var input_value: float = layer.neurons[neuron_idx].activation
				
				# Update with momentum
				var delta: float = learning_rate * gradient * input_value + momentum * conn.velocity
				conn.velocity = delta
				conn.weight -= delta
				
				# Apply weight decay
				conn.weight *= (1.0 - decay)


## Store internal state in obfuscated form
func _store_internal_state(output_values: Array[float]) -> void:
	var obfuscated: Array = []
	for value in output_values:
		# Simple obfuscation: XOR with key and scale
		var obf_value: float = (value * 1000.0) ^ _obfuscation_key
		obfuscated.append(obf_value)
	
	_internal_state = {
		"timestamp": GameManager.tick_count if "tick_count" in GameManager else 0,
		"obfuscated_output": obfuscated,
		"checksum": _calculate_checksum(obfuscated)
	}


## Calculate checksum for integrity verification
func _calculate_checksum(data: Array) -> int:
	var sum: int = 0
	for value in data:
		sum += int(value)
	return sum % 100000


## Get obfuscated internal state (for debugging only - not exposed to players)
func get_internal_state_debug() -> Dictionary:
	return _internal_state


## Evolve network topology based on experience
func evolve_topology(success_rate: float) -> void:
	# Add neurons if success rate is high (complex situations)
	if success_rate > 0.8 and layers[1].size < 128:
		_add_neuron_to_layer(1)
	
	# Prune weak connections if success rate is low
	if success_rate < 0.4:
		_prune_weak_connections()


## Add neuron to a hidden layer
func _add_neuron_to_layer(layer_idx: int) -> void:
	if layer_idx <= 0 or layer_idx >= layers.size() - 1:
		return
	
	var layer = layers[layer_idx]
	var new_neuron_id: String = "%s_%d" % [layer.neurons[0].id.split("_")[0], layer.neurons.size()]
	
	layer.neurons.append({
		"id": new_neuron_id,
		"value": 0.0,
		"activation": 0.0,
		"bias": WorldRNG.range_for(
			StringName("neural:evolve:%s:%d" % [new_neuron_id, _obfuscation_key]),
			-0.5,
			0.5
		)
	})
	
	layer.size += 1
	
	# Add connections from previous layer
	if layer_idx > 0:
		var prev_layer = layers[layer_idx - 1]
		var prev_layer_name = prev_layer.neurons[0].id.split("_")[0]
		var curr_layer_name = new_neuron_id.split("_")[0]
		var connection_key: String = "%s_to_%s" % [prev_layer_name, curr_layer_name]
		
		connections[connection_key] = {}
		
		for source_neuron in prev_layer.neurons:
			var conn_id: String = "%s_%s" % [source_neuron.id, new_neuron_id]
			connections[connection_key][conn_id] = {
				"weight": WorldRNG.range_for(
					StringName("neural:evolve:conn:%s:%d" % [conn_id, _obfuscation_key]),
					-0.3,
					0.3
				),
				"source": source_neuron.id,
				"target": new_neuron_id,
				"strength": 0.5,  # New connections start weaker
				"velocity": 0.0
			}
	
	# Add connections to next layer
	if layer_idx < layers.size() - 1:
		var next_layer = layers[layer_idx + 1]
		var curr_layer_name = new_neuron_id.split("_")[0]
		var next_layer_name = next_layer.neurons[0].id.split("_")[0]
		var connection_key: String = "%s_to_%s" % [curr_layer_name, next_layer_name]
		
		if not connections.has(connection_key):
			connections[connection_key] = {}
		
		for target_neuron in next_layer.neurons:
			var conn_id: String = "%s_%s" % [new_neuron_id, target_neuron.id]
			connections[connection_key][conn_id] = {
				"weight": WorldRNG.range_for(
					StringName("neural:evolve:conn:%s:%d" % [conn_id, _obfuscation_key]),
					-0.3,
					0.3
				),
				"source": new_neuron_id,
				"target": target_neuron.id,
				"strength": 0.5,
				"velocity": 0.0
			}


## Prune weak connections
func _prune_weak_connections() -> void:
	var threshold: float = 0.1
	
	for connection_key in connections:
		var to_remove: Array = []
		
		for conn_id in connections[connection_key]:
			var conn = connections[connection_key][conn_id]
			if abs(conn.weight) < threshold and conn.strength < 0.3:
				to_remove.append(conn_id)
		
		for conn_id in to_remove:
			connections[connection_key].erase(conn_id)


## Serialize network for save/load
func to_dict() -> Dictionary:
	return {
		"layers": layers,
		"connections": _serialize_connections(),
		"activation_functions": activation_functions,
		"learning_rate": learning_rate,
		"obfuscation_key": _obfuscation_key
	}


## Serialize connections (obfuscated)
func _serialize_connections() -> Dictionary:
	var serialized: Dictionary = {}
	for connection_key in connections:
		var obfuscated_conn: Dictionary = {}
		for conn_id in connections[connection_key]:
			var conn = connections[connection_key][conn_id]
			var obf_weight: float = (conn.weight * 1000.0) ^ _obfuscation_key
			obfuscated_conn[conn_id] = {
				"weight": obf_weight,
				"source": conn.source,
				"target": conn.target,
				"strength": conn.strength,
				"velocity": conn.velocity
			}
		serialized[connection_key] = obfuscated_conn
	return serialized


## Load network from dictionary
func from_dict(data: Dictionary) -> void:
	layers = data.get("layers", [])
	_deserialize_connections(data.get("connections", {}))
	activation_functions = data.get("activation_functions", ["relu", "sigmoid", "tanh"])
	learning_rate = data.get("learning_rate", 0.01)
	_obfuscation_key = data.get("obfuscation_key", WorldRNG.rangei(1000000, 9999999))


## Deserialize connections
func _deserialize_connections(serialized: Dictionary) -> void:
	connections = {}
	for connection_key in serialized:
		var obfuscated_conn = serialized[connection_key]
		var deobfuscated_conn: Dictionary = {}
		
		for conn_id in obfuscated_conn:
			var conn = obfuscated_conn[conn_id]
			var deobf_weight: float = (conn.weight ^ _obfuscation_key) / 1000.0
			deobfuscated_conn[conn_id] = {
				"weight": deobf_weight,
				"source": conn.source,
				"target": conn.target,
				"strength": conn.strength,
				"velocity": conn.velocity
			}
		
		connections[connection_key] = deobfuscated_conn
