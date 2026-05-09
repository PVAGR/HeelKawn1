extends Node
class_name ErrorTracker
## Advanced Neural Network-Enhanced Error Tracking and Diagnostic System
## Helps identify, track, and predict errors using neural network matrix integration

signal error_detected(error_info: Dictionary)
signal error_resolved(error_id: String)
signal error_predicted(prediction: Dictionary)

@onready var WorldRNG = get_node_or_null("/root/WorldRNG")

var active_errors: Dictionary = {}
var error_history: Array[Dictionary] = []
var error_categories: Dictionary = {
	"compilation": "Compilation Errors",
	"runtime": "Runtime Errors", 
	"warning": "Warnings",
	"syntax": "Syntax Errors",
	"neural": "Neural Network Issues",
	"performance": "Performance Issues"
}

# Neural Network Error Prediction System
var error_prediction_network: Dictionary = {}
var error_patterns: Array[Dictionary] = []
var learning_rate: float = 0.01
var prediction_threshold: float = 0.7
var error_trends: Dictionary = {}

func _ready() -> void:
	_initialize_neural_error_prediction()
	print("[ErrorTracker] Advanced neural network-enhanced error tracking system initialized")

func _error_stream(label: String) -> StringName:
	return StringName("error_tracker:%s" % label)


# === Neural Network Error Prediction ===

func _initialize_neural_error_prediction() -> void:
	# Initialize neural network for error prediction
	error_prediction_network = {
		"input_layer": {"size": 16, "neurons": _create_error_input_neurons()},
		"hidden_layer": {"size": 8, "neurons": _create_error_hidden_neurons()},
		"output_layer": {"size": 6, "neurons": _create_error_output_neurons()},
		"weights": _initialize_error_weights(),
		"learning_rate": learning_rate,
		"accuracy": 0.0
	}
	
	print("[ErrorTracker] Neural error prediction network initialized")


func _create_error_input_neurons() -> Array[Dictionary]:
	var neurons: Array[Dictionary] = []
	var input_features = [
		"file_complexity", "recent_errors", "code_changes", "system_load",
		"memory_usage", "tick_frequency", "neural_activity", "error_frequency",
		"pattern_deviation", "performance_degradation", "resource_pressure",
		"neural_stress", "connection_health", "synaptic_efficiency", "learning_rate",
		"prediction_confidence"
	]
	
	for i in range(input_features.size()):
		neurons.append({
			"id": input_features[i],
			"value": 0.0,
			"activation": 0.0,
			"bias": WorldRNG.range_for(_error_stream("input_bias:%s" % input_features[i]), -0.1, 0.1)
		})
	
	return neurons


func _create_error_hidden_neurons() -> Array[Dictionary]:
	var neurons: Array[Dictionary] = []
	for i in range(8):
		neurons.append({
			"id": "hidden_%d" % i,
			"value": 0.0,
			"activation": 0.0,
			"bias": WorldRNG.range_for(_error_stream("hidden_bias:%d" % i), -0.1, 0.1)
		})
	return neurons


func _create_error_output_neurons() -> Array[Dictionary]:
	var neurons: Array[Dictionary] = []
	var error_types = ["compilation", "runtime", "syntax", "neural", "performance", "warning"]
	
	for i in range(error_types.size()):
		neurons.append({
			"id": error_types[i],
			"value": 0.0,
			"activation": 0.0,
			"bias": WorldRNG.range_for(_error_stream("output_bias:%s" % error_types[i]), -0.1, 0.1)
		})
	
	return neurons


func _initialize_error_weights() -> Dictionary:
	var weights: Dictionary = {}
	
	# Input to hidden weights
	weights["input_to_hidden"] = _create_error_weight_matrix(16, 8)
	
	# Hidden to output weights
	weights["hidden_to_output"] = _create_error_weight_matrix(8, 6)
	
	return weights


func _create_error_weight_matrix(rows: int, cols: int) -> Array:
	var matrix: Array = []
	for i in range(rows):
		var row: Array = []
		for j in range(cols):
			row.append(WorldRNG.range_for(_error_stream("weight:%d:%d:%d:%d" % [rows, cols, i, j]), -0.3, 0.3))
		matrix.append(row)
	return matrix


func predict_errors(system_state: Dictionary) -> Dictionary:
	# Use neural network to predict potential errors
	var input_features = _extract_error_features(system_state)
	var neural_output = _forward_propagate_error_prediction(input_features)
	var predictions = _interpret_error_predictions(neural_output)
	
	# Record prediction for learning
	_record_error_prediction(system_state, predictions)
	
	# Emit prediction signal
	error_predicted.emit(predictions)
	
	return predictions


func _extract_error_features(system_state: Dictionary) -> Array[float]:
	var features: Array[float] = []
	
	# Extract system state features
	features.append(system_state.get("file_complexity", 0.0))
	features.append(float(error_history.size()) / 100.0)
	features.append(system_state.get("code_changes", 0.0))
	features.append(system_state.get("system_load", 0.0))
	features.append(system_state.get("memory_usage", 0.0))
	features.append(system_state.get("tick_frequency", 0.0))
	features.append(system_state.get("neural_activity", 0.0))
	features.append(_calculate_error_frequency())
	features.append(_calculate_pattern_deviation())
	features.append(system_state.get("performance_degradation", 0.0))
	features.append(system_state.get("resource_pressure", 0.0))
	features.append(system_state.get("neural_stress", 0.0))
	features.append(system_state.get("connection_health", 0.0))
	features.append(system_state.get("synaptic_efficiency", 0.0))
	features.append(learning_rate)
	features.append(system_state.get("prediction_confidence", 0.0))
	
	return features


func _forward_propagate_error_prediction(input_features: Array[float]) -> Array[float]:
	# Forward propagation through error prediction network
	var network = error_prediction_network
	
	# Input layer
	var input_activations = input_features.duplicate()
	
	# Hidden layer
	var hidden_activations: Array[float] = []
	var input_hidden_weights = network.weights["input_to_hidden"]
	
	for i in range(network.hidden_layer.size):
		var neuron = network.hidden_layer.neurons[i]
		var activation = neuron.bias
		
		for j in range(input_activations.size()):
			activation += input_activations[j] * input_hidden_weights[j][i]
		
		neuron.activation = _apply_error_activation(activation)
		hidden_activations.append(neuron.activation)
	
	# Output layer
	var output_activations: Array[float] = []
	var hidden_output_weights = network.weights["hidden_to_output"]
	
	for i in range(network.output_layer.size):
		var neuron = network.output_layer.neurons[i]
		var activation = neuron.bias
		
		for j in range(hidden_activations.size()):
			activation += hidden_activations[j] * hidden_output_weights[j][i]
		
		neuron.activation = _apply_error_activation(activation)
		output_activations.append(neuron.activation)
	
	return output_activations


func _apply_error_activation(value: float) -> float:
	# Use sigmoid activation for error prediction
	return 1.0 / (1.0 + exp(-value))


func _interpret_error_predictions(neural_output: Array[float]) -> Dictionary:
	var predictions: Dictionary = {}
	var error_types = ["compilation", "runtime", "syntax", "neural", "performance", "warning"]
	
	for i in range(min(error_types.size(), neural_output.size())):
		var error_type = error_types[i]
		var confidence = neural_output[i]
		
		if confidence >= prediction_threshold:
			predictions[error_type] = {
				"predicted": true,
				"confidence": confidence,
				"urgency": "high" if confidence > 0.9 else "medium" if confidence > 0.8 else "low"
			}
		else:
			predictions[error_type] = {
				"predicted": false,
				"confidence": confidence,
				"urgency": "none"
			}
	
	return predictions


func _record_error_prediction(system_state: Dictionary, predictions: Dictionary) -> void:
	var prediction_record = {
		"timestamp": Time.get_unix_time_from_system(),
		"system_state": system_state,
		"predictions": predictions,
		"actual_outcome": "pending"
	}
	
	error_patterns.append(prediction_record)
	
	# Keep only recent patterns
	if error_patterns.size() > 1000:
		error_patterns = error_patterns.slice(-1000)


func _calculate_error_frequency() -> float:
	if error_history.size() == 0:
		return 0.0
	
	var recent_errors = 0
	var current_time = Time.get_unix_time_from_system()
	
	for error in error_history:
		if current_time - error.timestamp < 3600:  # Last hour
			recent_errors += 1
	
	return float(recent_errors) / 60.0  # Errors per minute


func _calculate_pattern_deviation() -> float:
	# Calculate deviation from normal error patterns
	if error_patterns.size() < 10:
		return 0.0
	
	var recent_patterns = error_patterns.slice(-10)
	var deviation_sum = 0.0
	
	for pattern in recent_patterns:
		if pattern.has("predictions"):
			var confidence_sum = 0.0
			for prediction in pattern.predictions:
				if prediction.predicted:
					confidence_sum += prediction.confidence
			deviation_sum += abs(confidence_sum - 0.5)
	
	return deviation_sum / float(recent_patterns.size())


func train_error_prediction_network(actual_outcomes: Dictionary) -> void:
	# Train the neural network with actual outcomes
	if error_patterns.size() == 0:
		return
	
	var latest_pattern = error_patterns[-1]
	if latest_pattern.actual_outcome != "pending":
		return
	
	# Update with actual outcome
	latest_pattern.actual_outcome = actual_outcomes
	
	# Backpropagation training
	_backpropagate_error_training(latest_pattern)
	
	# Update network accuracy
	_update_prediction_accuracy()


func _backpropagate_error_training(pattern: Dictionary) -> void:
	# Simplified backpropagation for error prediction
	var learning_rate = error_prediction_network.learning_rate
	
	# Calculate error gradients
	var target_outputs = _create_target_outputs(pattern.actual_outcome)
	var actual_outputs = _extract_network_outputs()
	var error_gradients = _calculate_error_gradients(target_outputs, actual_outputs)
	
	# Update weights
	_update_error_weights(error_gradients, learning_rate)


func _create_target_outputs(outcomes: Dictionary) -> Array[float]:
	var targets: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
	var error_types = ["compilation", "runtime", "syntax", "neural", "performance", "warning"]
	
	for i in range(error_types.size()):
		var error_type = error_types[i]
		if outcomes.has(error_type) and outcomes[error_type]:
			targets[i] = 1.0
	
	return targets


func _extract_network_outputs() -> Array[float]:
	var outputs: Array[float] = []
	for neuron in error_prediction_network.output_layer.neurons:
		outputs.append(neuron.activation)
	return outputs


func _calculate_error_gradients(targets: Array[float], actual: Array[float]) -> Array[float]:
	var gradients: Array[float] = []
	for i in range(min(targets.size(), actual.size())):
		gradients.append(targets[i] - actual[i])
	return gradients


func _update_error_weights(gradients: Array[float], learning_rate: float) -> float:
	var total_update = 0.0
	
	# Update hidden to output weights
	var hidden_output_weights = error_prediction_network.weights["hidden_to_output"]
	for i in range(gradients.size()):
		for j in range(hidden_output_weights.size()):
			var weight_change = learning_rate * gradients[i] * 0.1  # Simplified
			hidden_output_weights[j][i] += weight_change
			total_update += abs(weight_change)
	
	return total_update


func _update_prediction_accuracy() -> void:
	var correct_predictions = 0
	var total_predictions = 0
	
	for pattern in error_patterns:
		if pattern.actual_outcome == "pending":
			continue
		
		total_predictions += 1
		var predicted_correctly = _verify_prediction_accuracy(pattern)
		if predicted_correctly:
			correct_predictions += 1
	
	if total_predictions > 0:
		error_prediction_network.accuracy = float(correct_predictions) / float(total_predictions)

# === Error Registration ===

func register_error(error_type: String, file_path: String, line_number: int, error_message: String, severity: String = "error") -> String:
	var error_id: String = _generate_error_id(file_path, line_number, error_message)
	var error_info: Dictionary = {
		"id": error_id,
		"type": error_type,
		"file": file_path,
		"line": line_number,
		"message": error_message,
		"severity": severity,
		"timestamp": Time.get_unix_time_from_system(),
		"resolved": false
	}
	
	active_errors[error_id] = error_info
	error_history.append(error_info.duplicate(true))
	
	print("[ErrorTracker] %s registered: %s at %s:%d" % [error_type, error_message, file_path, line_number])
	error_detected.emit(error_info)
	
	return error_id

func resolve_error(error_id: String) -> void:
	if active_errors.has(error_id):
		active_errors[error_id].resolved = true
		active_errors[error_id].resolved_timestamp = Time.get_unix_time_from_system()
		
		print("[ErrorTracker] Error resolved: %s" % error_id)
		error_resolved.emit(error_id)

# === Error Analysis ===

func get_active_errors() -> Array[Dictionary]:
	var active: Array[Dictionary] = []
	for error_id in active_errors:
		if not active_errors[error_id].resolved:
			active.append(active_errors[error_id])
	return active

func get_errors_by_file(file_path: String) -> Array[Dictionary]:
	var file_errors: Array[Dictionary] = []
	for error_id in active_errors:
		if active_errors[error_id].file == file_path:
			file_errors.append(active_errors[error_id])
	return file_errors

func get_error_summary() -> Dictionary:
	var summary: Dictionary = {
		"total_active": 0,
		"by_category": {},
		"by_file": {},
		"by_severity": {}
	}
	
	for error_id in active_errors:
		var error: Dictionary = active_errors[error_id]
		if not error.resolved:
			summary.total_active += 1
			
			# Count by category
			var category: String = error_categories.get(error.type, error.type)
			summary.by_category[category] = summary.by_category.get(category, 0) + 1
			
			# Count by file
			var file_name: String = error.file.get_file()
			summary.by_file[file_name] = summary.by_file.get(file_name, 0) + 1
			
			# Count by severity
			summary.by_severity[error.severity] = summary.by_severity.get(error.severity, 0) + 1
	
	return summary

# === Error Detection ===

func check_compilation_errors() -> void:
	# Check for common compilation error patterns
	var files_to_check: Array[String] = [
		"res://scripts/ui/AIControlPanel.gd",
		"res://scripts/pawn/HeelKawnian.gd",
		"res://scenes/main/Main.gd"
	]
	
	for file_path in files_to_check:
		_check_file_syntax(file_path)

func _check_file_syntax(file_path: String) -> void:
	if not FileAccess.file_exists(file_path):
		register_error("file_missing", file_path, 0, "File not found", "error")
		return
	
	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		register_error("file_access", file_path, 0, "Cannot access file", "error")
		return
	
	var content: String = file.get_as_text()
	file.close()
	
	var lines: PackedStringArray = content.split("\n")
	for line_num in range(lines.size()):
		var line: String = lines[line_num]
		_check_line_syntax(file_path, line_num + 1, line)

func _check_line_syntax(file_path: String, line_num: int, line: String) -> void:
	# Check for common syntax issues
	var stripped_line: String = line.strip_edges()
	
	# Missing closing brackets
	if stripped_line.begins_with("func ") and not stripped_line.ends_with(":"):
		register_error("syntax", file_path, line_num, "Function declaration missing colon", "error")
	
	# Unclosed brackets (basic check)
	var open_brackets: int = 0
	var open_parentheses: int = 0
	var open_braces: int = 0
	
	for char in line:
		match char:
			"{": open_braces += 1
			"}": open_braces -= 1
			"(": open_parentheses += 1
			")": open_parentheses -= 1
			"[": open_brackets += 1
			"]": open_brackets -= 1
	
	if open_braces < 0 or open_parentheses < 0 or open_brackets < 0:
		register_error("syntax", file_path, line_num, "Unmatched closing bracket/parenthesis", "error")

# === Utility Functions ===

func _generate_error_id(file_path: String, line_number: int, message: String) -> String:
	var base: String = "%s_%d_%s" % [file_path.get_file(), line_number, message]
	return "ERR_%08X" % [base.hash()]

func generate_error_report() -> String:
	var report: PackedStringArray = []
	var summary: Dictionary = get_error_summary()
	
	report.append("=== HEELKAWN ERROR REPORT ===")
	report.append("Generated: %s" % Time.get_datetime_string_from_system())
	report.append("Active Errors: %d" % summary.total_active)
	report.append("")
	
	# Errors by category
	report.append("=== Errors by Category ===")
	for category in summary.by_category:
		report.append("%s: %d" % [category, summary.by_category[category]])
	report.append("")
	
	# Errors by file
	report.append("=== Errors by File ===")
	for file_name in summary.by_file:
		report.append("%s: %d" % [file_name, summary.by_file[file_name]])
	report.append("")
	
	# Active errors list
	var active_errors: Array[Dictionary] = get_active_errors()
	if active_errors.size() > 0:
		report.append("=== Active Error Details ===")
		for error in active_errors:
			report.append("[%s] %s:%d - %s" % [error.severity.to_upper(), error.file.get_file(), error.line, error.message])
	else:
		report.append("No active errors detected!")
	
	return "\n".join(report)

# === Debug Commands ===

func debug_check_current_files() -> void:
	print("[ErrorTracker] Running comprehensive error check...")
	check_compilation_errors()
	
	var active_errors: Array[Dictionary] = get_active_errors()
	if active_errors.size() > 0:
		print("[ErrorTracker] Found %d active errors:" % active_errors.size())
		for error in active_errors:
			print("  - %s:%d - %s" % [error.file.get_file(), error.line, error.message])
	else:
		print("[ErrorTracker] No errors detected!")

func debug_clear_all_errors() -> void:
	active_errors.clear()
	print("[ErrorTracker] All errors cleared")


func _verify_prediction_accuracy(pattern: Dictionary = {}) -> float:
	# Verify prediction accuracy
	# If specific pattern provided, check that one
	if not pattern.is_empty():
		return 1.0 if (pattern.has("correct") and pattern["correct"]) else 0.0
	
	# Otherwise check all patterns
	if error_patterns.size() == 0:
		return 0.0
	
	var correct = 0
	for p in error_patterns:
		if p.has("correct") and p["correct"]:
			correct += 1
	
	return float(correct) / float(error_patterns.size())
