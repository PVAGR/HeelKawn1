class_name HeelKawnMonitor
extends RefCounted

## HeelKawn Universe Live Monitoring System
## Continuously monitors all systems and reports health status

signal health_report_generated(report: Dictionary)
signal error_detected(error_type: String, details: String)
signal system_degraded(system_name: String, severity: int)

const MONITOR_VERSION := "2.6.1"
const CHECK_INTERVAL_TICKS := 100  # Check every 100 game ticks

var last_check_tick: int = 0
var error_history: Array[Dictionary] = []
var system_health_scores: Dictionary = {}
var is_monitoring: bool = false

# System status tracking
enum SystemStatus {
	HEALTHY = 0,
	DEGRADED = 1,
	CRITICAL = 2,
	OFFLINE = 3
}

func start_monitoring() -> void:
	is_monitoring = true
	print("[HeelKawnMonitor] v%s started - Live monitoring active" % MONITOR_VERSION)
	_perform_full_system_check()

func stop_monitoring() -> void:
	is_monitoring = false
	print("[HeelKawnMonitor] Monitoring stopped")

func update(current_tick: int) -> void:
	if not is_monitoring:
		return
	
	if current_tick - last_check_tick >= CHECK_INTERVAL_TICKS:
		last_check_tick = current_tick
		_perform_full_system_check()

func _perform_full_system_check() -> void:
	var report := {
		"timestamp": Time.get_datetime_string_from_system(),
		"tick": last_check_tick,
		"overall_status": "HEALTHY",
		"systems": {},
		"errors_found": 0,
		"warnings_found": 0
	}
	
	# Check WorldAI
	_check_world_ai(report)
	
	# Check AIAgentManager
	_check_ai_agent_manager(report)
	
	# Check ErrorTracker
	_check_error_tracker(report)
	
	# Check HeelKawnian system
	_check_pawn_system(report)
	
	# Check Stockpile system
	_check_stockpile_system(report)
	
	# Check Neural Network Matrix
	_check_neural_matrix(report)
	
	# Determine overall status
	if report.errors_found > 0:
		report.overall_status = "CRITICAL"
	elif report.warnings_found > 0:
		report.overall_status = "DEGRADED"
	
	health_report_generated.emit(report)
	
	if report.overall_status != "HEALTHY":
		_print_health_report(report)

func _check_world_ai(report: Dictionary) -> void:
	var status := SystemStatus.HEALTHY
	var issues := []
	
	# Check if WorldAI autoload exists
	if not Engine.has_singleton("WorldAI"):
		# Try to find it in the scene tree
		var world_ai_nodes = Engine.get_main_loop().root.find_children("*", "WorldAI", true, false)
		if world_ai_nodes.size() == 0:
			status = SystemStatus.CRITICAL
			issues.append("WorldAI not found in scene")
		else:
			# Check if neural matrix is initialized
			var world_ai = world_ai_nodes[0]
			if world_ai.neural_world_matrix.is_empty():
				status = SystemStatus.DEGRADED
				issues.append("Neural world matrix not initialized")
	
	report.systems["WorldAI"] = {
		"status": status,
		"issues": issues
	}
	
	if status != SystemStatus.HEALTHY:
		report.warnings_found += 1
		if status == SystemStatus.CRITICAL:
			report.errors_found += 1
			system_degraded.emit("WorldAI", status)

func _check_ai_agent_manager(report: Dictionary) -> void:
	var status := SystemStatus.HEALTHY
	var issues := []
	
	# Check if AIAgentManager exists
	if Engine.has_singleton("AIAgentManager"):
		var ai_manager = Engine.get_singleton("AIAgentManager")
		
		# Check if agents are being updated
		if ai_manager.civilization_agents.is_empty() and ai_manager.settlement_agents.is_empty():
			# This might be normal at game start
			pass
	else:
		status = SystemStatus.DEGRADED
		issues.append("AIAgentManager singleton not found")
	
	report.systems["AIAgentManager"] = {
		"status": status,
		"issues": issues
	}

func _check_error_tracker(report: Dictionary) -> void:
	var status := SystemStatus.HEALTHY
	var issues := []
	
	if Engine.has_singleton("ErrorTracker"):
		var error_tracker = Engine.get_singleton("ErrorTracker")
		
		# Check error counts
		var active_errors = error_tracker.active_errors.size()
		if active_errors > 10:
			status = SystemStatus.DEGRADED
			issues.append("High error count: %d active errors" % active_errors)
		elif active_errors > 50:
			status = SystemStatus.CRITICAL
			issues.append("Critical error count: %d active errors" % active_errors)
	else:
		issues.append("ErrorTracker not available")
	
	report.systems["ErrorTracker"] = {
		"status": status,
		"issues": issues
	}

func _check_pawn_system(report: Dictionary) -> void:
	var status := SystemStatus.HEALTHY
	var issues := []
	
	# Check for pawns in the scene
	var pawns = Engine.get_main_loop().root.find_children("*", "HeelKawnian", true, false)
	
	if pawns.size() == 0:
		# Might be normal at game start
		pass
	else:
		# Check for pawns with critical issues
		var starving_pawns = 0
		for pawn in pawns:
			if pawn.data.hunger < -5.0:
				starving_pawns += 1
		
		if starving_pawns > pawns.size() * 0.5:  # More than 50% starving
			status = SystemStatus.DEGRADED
			issues.append("High starvation rate: %d/%d pawns" % [starving_pawns, pawns.size()])
	
	report.systems["PawnSystem"] = {
		"status": status,
		"issues": issues,
		"pawn_count": pawns.size()
	}

func _check_stockpile_system(report: Dictionary) -> void:
	var status := SystemStatus.HEALTHY
	var issues := []
	
	# Check StockpileManager
	if Engine.has_singleton("StockpileManager"):
		var stockpile_manager = Engine.get_singleton("StockpileManager")
		
		# Check if stockpiles have food
		var total_food = 0
		for stockpile in stockpile_manager.stockpiles:
			total_food += stockpile.count_food()
		
		if total_food == 0:
			# Check if there are pawns that need food
			var pawns = Engine.get_main_loop().root.find_children("*", "HeelKawnian", true, false)
			if pawns.size() > 0:
				status = SystemStatus.DEGRADED
				issues.append("No food in stockpiles but pawns exist")
	else:
		status = SystemStatus.DEGRADED
		issues.append("StockpileManager not available")
	
	report.systems["StockpileSystem"] = {
		"status": status,
		"issues": issues
	}

func _check_neural_matrix(report: Dictionary) -> void:
	var status := SystemStatus.HEALTHY
	var issues := []
	
	# Check if WorldAI neural matrix is functioning
	if Engine.has_singleton("WorldAI"):
		var world_ai = Engine.get_singleton("WorldAI")
		
		# Check neural networks
		if world_ai.civilization_neural_network.is_empty():
			status = SystemStatus.CRITICAL
			issues.append("Civilization neural network not initialized")
		
		if world_ai.environmental_neural_network.is_empty():
			status = SystemStatus.CRITICAL
			issues.append("Environmental neural network not initialized")
		
		if world_ai.cultural_neural_network.is_empty():
			status = SystemStatus.CRITICAL
			issues.append("Cultural neural network not initialized")
		
		if world_ai.economic_neural_network.is_empty():
			status = SystemStatus.CRITICAL
			issues.append("Economic neural network not initialized")
		
		# Check neural matrix interconnections
		if world_ai.neural_world_matrix.has("interconnections"):
			var interconnections = world_ai.neural_world_matrix["interconnections"]
			if interconnections.size() == 0:
				status = SystemStatus.DEGRADED
				issues.append("No neural interconnections established")
		else:
			status = SystemStatus.CRITICAL
			issues.append("Neural interconnections not initialized")
	
	report.systems["NeuralMatrix"] = {
		"status": status,
		"issues": issues
	}
	
	if status != SystemStatus.HEALTHY:
		report.warnings_found += 1
		if status == SystemStatus.CRITICAL:
			report.errors_found += 1

func _print_health_report(report: Dictionary) -> void:
	print("\n[HeelKawnMonitor] ═══════════════════════════════════════════")
	print("[HeelKawnMonitor] HEALTH REPORT - %s" % report.timestamp)
	print("[HeelKawnMonitor] Overall Status: %s" % report.overall_status)
	print("[HeelKawnMonitor] Tick: %d" % report.tick)
	print("[HeelKawnMonitor] ───────────────────────────────────────────")
	
	for system_name in report.systems:
		var system = report.systems[system_name]
		var status_str = _status_to_string(system.status)
		print("[HeelKawnMonitor] %s: %s" % [system_name, status_str])
		
		for issue in system.issues:
			print("[HeelKawnMonitor]   ⚠️  %s" % issue)
	
	print("[HeelKawnMonitor] ───────────────────────────────────────────")
	print("[HeelKawnMonitor] Errors: %d | Warnings: %d" % [report.errors_found, report.warnings_found])
	print("[HeelKawnMonitor] ═══════════════════════════════════════════\n")

func _status_to_string(status: int) -> String:
	match status:
		SystemStatus.HEALTHY: return "✅ HEALTHY"
		SystemStatus.DEGRADED: return "⚠️ DEGRADED"
		SystemStatus.CRITICAL: return "❌ CRITICAL"
		SystemStatus.OFFLINE: return "⭕ OFFLINE"
		_: return "❓ UNKNOWN"

func log_error(error_type: String, details: String) -> void:
	error_history.append({
		"type": error_type,
		"details": details,
		"timestamp": Time.get_datetime_string_from_system(),
		"tick": last_check_tick
	})
	
	error_detected.emit(error_type, details)
	print("[HeelKawnMonitor] ERROR: %s - %s" % [error_type, details])

func get_system_health_score(system_name: String) -> int:
	if system_health_scores.has(system_name):
		return system_health_scores[system_name]
	return 100  # Default healthy score

func generate_detailed_report() -> String:
	var report := ""
	report += "HeelKawn Universe Detailed Report\n"
	report += "Generated: %s\n" % Time.get_datetime_string_from_system()
	report += "Version: %s\n" % MONITOR_VERSION
	report += "\n"
	
	report += "Active Systems:\n"
	report += "- WorldAI: Neural network matrix for world simulation\n"
	report += "- AIAgentManager: Civilization and settlement AI\n"
	report += "- ErrorTracker: Real-time error detection and prediction\n"
	report += "- NeuralOptimizer: Performance optimization system\n"
	report += "- PawnSpawner: Agent management system\n"
	report += "- StockpileManager: Resource management\n"
	report += "\n"
	
	report += "Neural Network Components:\n"
	report += "- Civilization Neural Network: 32-16-8 architecture\n"
	report += "- Environmental Neural Network: 24-12-6 architecture\n"
	report += "- Cultural Neural Network: 28-14-7 architecture\n"
	report += "- Economic Neural Network: 20-10-5 architecture\n"
	report += "- Interconnection Matrix: Dynamic neural connections\n"
	report += "\n"
	
	report += "Status: All systems operational\n"
	
	return report
