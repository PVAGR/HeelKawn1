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
const _OBF_SCALE: float = 1000.0

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
	var output_size: int = 8  # Direct action heads: food, rest, social, gather, build, mine, defend, idle
	
	layers = [
		{"size": input_size, "neurons": _create_neurons(input_size, "input")},
		{"size": hidden1_size, "neurons": _create_neurons(hidden1_size, "hidden1")},
		{"size": hidden2_size, "neurons": _create_neurons(hidden2_size, "hidden2")},
		{"size": output_size, "neurons": _create_neurons(output_size, "output")}
	]


## Clamp invalid float values to zero and keep the network stable.
func _sanitize_float(value: Variant, label: String = "") -> float:
	var result: float = float(value)
	if is_nan(result) or is_inf(result):
		if OS.is_debug_build():
			push_warning("[PawnNeuralNetwork] Invalid float%s sanitized to 0.0" % (" for %s" % label if label != "" else ""))
		return 0.0
	return result


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
	var input_size: int = layers[0].size
	var current_values: Array[float] = []
	current_values.resize(input_size)
	for i in range(input_size):
		current_values[i] = _sanitize_float(input_data[i] if i < input_data.size() else 0.0, "input[%d]" % i)
	
	# Input layer: copy values into neuron state and seed current_values.
	var input_layer: Dictionary = layers[0]
	var input_neurons: Array = input_layer.neurons
	var input_activations: Array[float] = []
	input_activations.resize(input_neurons.size())
	for i in range(input_neurons.size()):
		var in_neuron: Dictionary = input_neurons[i]
		var in_value: float = current_values[i]
		in_neuron.value = in_value
		in_neuron.activation = in_value
		input_activations[i] = in_value
	current_values = input_activations
	
	# Hidden + output layers: O(source*target), direct connection lookup.
	for layer_idx in range(1, layers.size()):
		var prev_layer: Dictionary = layers[layer_idx - 1]
		var layer: Dictionary = layers[layer_idx]
		var prev_neurons: Array = prev_layer.neurons
		var layer_neurons: Array = layer.neurons
		var next_values: Array[float] = []
		next_values.resize(layer_neurons.size())
		var prev_layer_name: String = str((prev_neurons[0] as Dictionary).get("id", "")).split("_")[0]
		var curr_layer_name: String = str((layer_neurons[0] as Dictionary).get("id", "")).split("_")[0]
		var connection_key: String = "%s_to_%s" % [prev_layer_name, curr_layer_name]
		var layer_connections: Dictionary = connections.get(connection_key, {})
		
		for neuron_idx in range(layer_neurons.size()):
			var neuron: Dictionary = layer_neurons[neuron_idx]
			var neuron_value: float = 0.0
			for source_idx in range(prev_neurons.size()):
				var source_neuron: Dictionary = prev_neurons[source_idx]
				var source_id: String = str(source_neuron.get("id", ""))
				var target_id: String = str(neuron.get("id", ""))
				var conn_id: String = "%s_%s" % [source_id, target_id]
				var conn_v: Variant = layer_connections.get(conn_id, null)
				if conn_v is Dictionary:
					var source_value: float = _sanitize_float(current_values[source_idx], "layer_%d_source_%d" % [layer_idx, source_idx])
					var weight: float = _sanitize_float((conn_v as Dictionary).get("weight", 0.0), "weight_%s" % conn_id)
					neuron_value += source_value * weight
			neuron.activation = _apply_activation(neuron_value, layer_idx)
			neuron.value = neuron_value
			next_values[neuron_idx] = _sanitize_float(neuron.activation, "activation_%s" % str(neuron.get("id", "")))
		
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
	if is_nan(value) or is_inf(value):
		if OS.is_debug_build():
			push_warning("[PawnNeuralNetwork] Activation received invalid input at layer %d" % layer_idx)
		return 0.0
	var func_index: int = layer_idx % activation_functions.size()
	match activation_functions[func_index]:
		"relu":
			return max(0.0, value)
		"sigmoid":
			return _sanitize_float(1.0 / (1.0 + exp(-value)), "sigmoid")
		"tanh":
			return _sanitize_float(tanh(value), "tanh")
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
		var obf_value: int = _encode_obfuscated_float(value)
		obfuscated.append(obf_value)
	
	_internal_state = {
		"timestamp": GameManager.tick_count if GameManager != null else 0,
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
	var d: Dictionary = {
		"layers": layers,
		"connections": _serialize_connections(),
		"activation_functions": activation_functions,
		"learning_rate": learning_rate,
		"obfuscation_key": _obfuscation_key,
		"goap_v1": _goap_to_dict(),
	}
	return d


## Serialize connections (obfuscated)
func _serialize_connections() -> Dictionary:
	var serialized: Dictionary = {}
	for connection_key in connections:
		var obfuscated_conn: Dictionary = {}
		for conn_id in connections[connection_key]:
			var conn = connections[connection_key][conn_id]
			var obf_weight: int = _encode_obfuscated_float(float(conn.weight))
			obfuscated_conn[conn_id] = {
				"weight": obf_weight,
				"weight_encoding": "xor_i32_milli_v1",
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
	_goap_from_dict(data.get("goap_v1", {}))


## Deserialize connections
func _deserialize_connections(serialized: Dictionary) -> void:
	connections = {}
	for connection_key in serialized:
		var obfuscated_conn = serialized[connection_key]
		var deobfuscated_conn: Dictionary = {}
		
		for conn_id in obfuscated_conn:
			var conn = obfuscated_conn[conn_id]
			var deobf_weight: float = _decode_obfuscated_float(conn.get("weight", 0.0), str(conn.get("weight_encoding", "")))
			deobfuscated_conn[conn_id] = {
				"weight": deobf_weight,
				"source": conn.source,
				"target": conn.target,
				"strength": conn.strength,
				"velocity": conn.velocity
			}
		
		connections[connection_key] = deobfuscated_conn


## --- GOAP-lite: Maslow needs + memory + autonomy hints (throttled from [Pawn]) ---
## GOAP-lite + Maslow: runs on a throttled tick from [Pawn]; does not replace weight-based forward pass.
const SHORT_MEM_CAP: int = 12
const LONG_MEM_CAP: int = 28
const MEMORY_DECAY: float = 0.9985

## 0 = biological … 3 = ego — aggregate urgency per layer.
var _maslow: Dictionary = {
	"bio": 0.0,
	"safety": 0.0,
	"social": 0.0,
	"ego": 0.0,
}
var _short_term_memory: Array[Dictionary] = []
var _long_term_memory: Array[Dictionary] = []
var last_autonomy_hint: String = "idle"
var last_autonomy_tick: int = -1


func _goap_to_dict() -> Dictionary:
	return {
		"maslow": _maslow.duplicate(true),
		"short": _short_term_memory.duplicate(true),
		"long": _long_term_memory.duplicate(true),
		"last_hint": last_autonomy_hint,
		"last_autonomy_tick": last_autonomy_tick,
	}


func _goap_from_dict(d: Dictionary) -> void:
	if d.is_empty():
		return
	_maslow = d.get("maslow", _maslow).duplicate(true)
	_short_term_memory.clear()
	_long_term_memory.clear()
	for e in d.get("short", []):
		if e is Dictionary:
			_short_term_memory.append((e as Dictionary).duplicate(true))
	for e2 in d.get("long", []):
		if e2 is Dictionary:
			_long_term_memory.append((e2 as Dictionary).duplicate(true))
	last_autonomy_hint = str(d.get("last_hint", "idle"))
	last_autonomy_tick = int(d.get("last_autonomy_tick", -1))


## Throttled entry from [Pawn] — one pass: sync needs, decay, plan hint.
func tick_autonomy(tick: int, pawn_id: int, ctx: Dictionary) -> void:
	sync_maslow_from_context(ctx)
	decay_memories(tick)
	last_autonomy_hint = choose_autonomy_action(tick, pawn_id, ctx)
	last_autonomy_tick = tick


func sync_maslow_from_context(ctx: Dictionary) -> void:
	var hunger: float = float(ctx.get("hunger", 100.0))
	var rest: float = float(ctx.get("rest", 100.0))
	var mood: float = float(ctx.get("mood", 50.0))
	var fear: float = float(ctx.get("fear", 0.0))
	var shelter: float = float(ctx.get("shelter", 0.5))
	var social: float = float(ctx.get("social_warmth", 0.5))
	var clan: float = float(ctx.get("clan_bond", 0.4))
	var nation: float = float(ctx.get("nation_pride", 0.3))
	var ambition: float = float(ctx.get("ambition", 0.5))
	var fame: float = float(ctx.get("fame", 0.2))
	# Urgency = deficit (0 = satisfied, 1 = critical)
	_maslow["bio"] = clampf((100.0 - hunger) / 100.0 * 0.6 + (100.0 - rest) / 100.0 * 0.4, 0.0, 1.0)
	_maslow["safety"] = clampf(fear / 100.0 + (1.0 - shelter) * 0.5, 0.0, 1.0)
	_maslow["social"] = clampf((1.0 - social) * 0.45 + (1.0 - clan) * 0.35 + (1.0 - nation) * 0.2, 0.0, 1.0)
	_maslow["ego"] = clampf(ambition * (1.0 - fame), 0.0, 1.0)
	if mood < 40.0:
		_maslow["social"] = clampf(_maslow["social"] + 0.08, 0.0, 1.0)


func record_memory_event(tick: int, kind: String, other_pawn_id: int, valence: float) -> void:
	var ev: Dictionary = {
		"t": tick,
		"k": kind,
		"o": other_pawn_id,
		"v": clampf(valence, -1.0, 1.0),
		"s": 1.0,
	}
	_short_term_memory.append(ev)
	while _short_term_memory.size() > SHORT_MEM_CAP:
		_promote_or_drop_oldest_short()


func _promote_or_drop_oldest_short() -> void:
	var old: Dictionary = _short_term_memory.pop_front()
	var sal: float = absf(float(old.get("v", 0.0)))
	if sal > 0.55:
		_long_term_memory.append(old)
		while _long_term_memory.size() > LONG_MEM_CAP:
			_long_term_memory.pop_front()


func decay_memories(tick: int) -> void:
	var kept_short: Array[Dictionary] = []
	for e in _short_term_memory:
		var ns: float = float(e.get("s", 1.0)) * MEMORY_DECAY
		if ns > 0.08:
			e["s"] = ns
			e["t"] = tick
			kept_short.append(e)
	_short_term_memory.clear()
	for x in kept_short:
		_short_term_memory.append(x)
	var kept_long: Array[Dictionary] = []
	for e2 in _long_term_memory:
		var ns2: float = float(e2.get("s", 1.0)) * pow(MEMORY_DECAY, 0.85)
		if ns2 > 0.05:
			e2["s"] = ns2
			kept_long.append(e2)
	_long_term_memory.clear()
	for y in kept_long:
		_long_term_memory.append(y)


func grudge_toward(other_pawn_id: int) -> float:
	var g: float = 0.0
	for e in _long_term_memory:
		if int(e.get("o", -1)) != other_pawn_id:
			continue
		if str(e.get("k", "")).find("attack") >= 0 or str(e.get("k", "")).find("hurt") >= 0:
			g += float(e.get("v", 0.0)) * float(e.get("s", 1.0))
	return clampf(g, -1.0, 1.0)


## Strongest negative attack/hurt memory toward another pawn (by weighted severity).
func get_strongest_grudge_target_id() -> int:
	var best_id: int = -1
	var best_w: float = 0.0
	for e in _long_term_memory:
		var k: String = str(e.get("k", ""))
		if k.find("attack") < 0 and k.find("hurt") < 0:
			continue
		if float(e.get("v", 0.0)) >= 0.0:
			continue
		var oid: int = int(e.get("o", -1))
		if oid < 0:
			continue
		var w: float = absf(float(e.get("v", 0.0))) * float(e.get("s", 1.0))
		if w > best_w:
			best_w = w
			best_id = oid
	return best_id


func choose_autonomy_action(tick: int, pawn_id: int, ctx: Dictionary) -> String:
	var wm: float = float(ctx.get("world_mood", 50.0))
	var theft_p: float = float(ctx.get("theft_pressure", 0.0))
	var labor_u: float = float(ctx.get("labor_urgency", 0.0))
	var bio: float = float(_maslow.get("bio", 0.0))
	var safety: float = float(_maslow.get("safety", 0.0))
	var soc: float = float(_maslow.get("social", 0.0))
	var ego: float = float(_maslow.get("ego", 0.0))
	var scores: Dictionary = {
		"eat": bio * 1.15 + (100.0 - float(ctx.get("hunger", 100.0))) / 200.0,
		"sleep": bio * 0.95 + (100.0 - float(ctx.get("rest", 100.0))) / 200.0,
		"shelter": safety * 1.05,
		"work": labor_u * 1.2 + ego * 0.35 + (1.0 - wm / 100.0) * 0.15,
		"social": soc * 1.1 + (wm / 100.0) * 0.2,
		"steal": theft_p * 1.25 + (1.0 - wm / 100.0) * 0.25,
	}
	var best_k: String = "idle"
	var best_v: float = -1.0
	for k in scores:
		var sc: float = float(scores[k])
		var jitter: float = WorldRNG.range_for(StringName("goap_pick:%d:%s:%d" % [pawn_id, k, tick]), -0.02, 0.02, 1)
		sc += jitter
		if sc > best_v:
			best_v = sc
			best_k = k
	return best_k


func get_autonomy_hint() -> String:
	return last_autonomy_hint

func _encode_obfuscated_float(value: float) -> int:
	var scaled: int = int(round(value * _OBF_SCALE))
	return scaled ^ _obfuscation_key


func _decode_obfuscated_float(weight_value: Variant, encoding: String = "") -> float:
	if encoding == "xor_i32_milli_v1":
		return float(int(weight_value) ^ _obfuscation_key) / _OBF_SCALE
	# Compatibility fallback: older saves may store plain float/int weights.
	if weight_value is int:
		return float(weight_value)
	if weight_value is float:
		return float(weight_value)
	if weight_value is String and String(weight_value).is_valid_float():
		return float(weight_value)
	return 0.0
