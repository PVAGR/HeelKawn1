extends SceneTree

## Equivalence + determinism probe for PawnNeuralNetwork.forward_propagate.
## Proves the new precomputed-matrix forward path is bit-identical to the
## original per-pair Dictionary lookup algorithm on: fresh nets (all sizes),
## post-cache-reuse, after a missing connection (pruned), after weight mutation
## via backpropagate (cache invalidation), after to_dict/from_dict round-trip,
## and after evolve_topology add+prune. Also times both paths.
## Note: must load() the script inside _initialize (autoloads are registered by
## then); a compile-time class_name reference would compile its WorldRNG-using
## dependency before autoloads exist.

var _failures: int = 0
var _checks: int = 0
var _nn_script: Script
var _frames: int = 0

func _initialize() -> void:
	_nn_script = load("res://scripts/pawn/PawnNeuralNetwork.gd")
	if _nn_script == null:
		print("NN_EQUIV RESULT=FAIL reason=script_load_failed")
		quit(1)
		return
	call_deferred("_probe")

func _probe() -> void:
	var personalities: Array = [
		{"openness": 0.2, "conscientiousness": 0.2},
		{"openness": 0.5, "conscientiousness": 0.5},
		{"openness": 0.9, "conscientiousness": 0.9},
	]
	var inputs: Array[float] = _input_vector()
	for i in range(personalities.size()):
		var nn = _nn_script.new(personalities[i])
		_test_network(nn, inputs, "personality_%d" % i)
	var t0: int = Time.get_ticks_usec()
	var bench_net = _nn_script.new({"openness": 0.5, "conscientiousness": 0.5})
	var n_iters: int = 300
	for k in range(n_iters):
		bench_net.forward_propagate(inputs)
	var new_us: int = Time.get_ticks_usec() - t0
	t0 = Time.get_ticks_usec()
	for k in range(n_iters):
		_reference_forward(bench_net, inputs)
	var ref_us: int = Time.get_ticks_usec() - t0
	print("NN_EQUIV RESULT=%s checks=%d failures=%d new_300x_us=%d ref_300x_us=%d speedup=%.1fx" % [
		"PASS" if _failures == 0 else "FAIL",
		_checks,
		_failures,
		new_us,
		ref_us,
		float(ref_us) / float(max(new_us, 1)),
	])
	quit(1 if _failures else 0)

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames > 600:
		quit(1)
	return false


func _input_vector() -> Array[float]:
	var arr: Array[float] = []
	arr.resize(32)
	for i in range(32):
		arr[i] = float(i % 7) * 0.13 + 0.01
	return arr


func _check(label: String, a: Array, b: Array) -> void:
	_checks += 1
	if a.size() != b.size():
		_failures += 1
		print("MISMATCH %s: size a=%d b=%d" % [label, a.size(), b.size()])
		return
	for i in range(a.size()):
		if float(a[i]) != float(b[i]):
			_failures += 1
			print("MISMATCH %s: idx=%d a=%s b=%s" % [label, i, String.num(float(a[i])), String.num(float(b[i]))])
			return


func _test_network(nn, inputs: Array[float], label: String) -> void:
	var ref: Array = _reference_forward(nn, inputs)
	var out1: Array = nn.forward_propagate(inputs)
	_check("%s/fresh" % label, out1, ref)
	var out2: Array = nn.forward_propagate(inputs)
	_check("%s/cache_reuse" % label, out2, ref)
	var target: Array[float] = [0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5]
	nn.backpropagate(inputs, target)
	var out4: Array = nn.forward_propagate(inputs)
	_check("%s/after_backprop_invalidate" % label, out4, _reference_forward(nn, inputs))
	nn.evolve_topology(0.9)
	var out5: Array = nn.forward_propagate(inputs)
	_check("%s/after_evolve_add" % label, out5, _reference_forward(nn, inputs))
	nn.evolve_topology(0.2)
	var out6: Array = nn.forward_propagate(inputs)
	_check("%s/after_evolve_prune" % label, out6, _reference_forward(nn, inputs))
	var reloaded = _nn_script.new({"openness": 0.5, "conscientiousness": 0.5})
	reloaded.from_dict(nn.to_dict())
	var out7: Array = reloaded.forward_propagate(inputs)
	_check("%s/after_save_load" % label, out7, _reference_forward(reloaded, inputs))


## Faithful reproduction of the ORIGINAL forward_propagate algorithm
## (per-pair Dictionary.get by constructed conn_id, source 0..N-1 order).
func _reference_forward(nn, input_data: Array[float]) -> Array:
	var current: Array = []
	current.resize(nn.layers[0].size)
	for i in range(nn.layers[0].size):
		current[i] = float(input_data[i] if i < input_data.size() else 0.0)
	var input_activations: Array = []
	input_activations.resize(nn.layers[0].neurons.size())
	for i in range(nn.layers[0].neurons.size()):
		input_activations[i] = float(input_data[i] if i < input_data.size() else 0.0)
	current = input_activations
	for layer_idx in range(1, nn.layers.size()):
		var prev_layer: Dictionary = nn.layers[layer_idx - 1]
		var layer: Dictionary = nn.layers[layer_idx]
		var prev_layer_name: String = str((prev_layer.neurons[0] as Dictionary).get("id", "")).split("_")[0]
		var curr_layer_name: String = str((layer.neurons[0] as Dictionary).get("id", "")).split("_")[0]
		var layer_connections: Dictionary = nn.connections.get("%s_to_%s" % [prev_layer_name, curr_layer_name], {})
		var next_vals: Array = []
		next_vals.resize(layer.neurons.size())
		for neuron_idx in range(layer.neurons.size()):
			var neuron: Dictionary = layer.neurons[neuron_idx]
			var neuron_value: float = 0.0
			var target_id: String = str(neuron.get("id", ""))
			for source_idx in range(prev_layer.neurons.size()):
				var conn_id: String = str((prev_layer.neurons[source_idx] as Dictionary).get("id", "")) + "_" + target_id
				var conn_v: Variant = layer_connections.get(conn_id, null)
				if conn_v is Dictionary:
					neuron_value += float(current[source_idx]) * float((conn_v as Dictionary).get("weight", 0.0))
			next_vals[neuron_idx] = nn._apply_activation(neuron_value, layer_idx)
		current = next_vals
	return current