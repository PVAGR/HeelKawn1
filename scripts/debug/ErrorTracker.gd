extends Node
class_name ErrorTracker
## Comprehensive Error Tracking and Diagnostic System
## Helps identify and track IDE errors, compilation issues, and runtime problems

signal error_detected(error_info: Dictionary)
signal error_resolved(error_id: String)

var active_errors: Dictionary = {}
var error_history: Array[Dictionary] = []
var error_categories: Dictionary = {
	"compilation": "Compilation Errors",
	"runtime": "Runtime Errors", 
	"warning": "Warnings",
	"syntax": "Syntax Errors"
}

func _ready() -> void:
	print("[ErrorTracker] Error tracking system initialized")

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
		"res://scripts/pawn/Pawn.gd",
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
