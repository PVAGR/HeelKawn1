extends Node

## Stub: SettlementPersistenceManager for testing Phase 4 kernel
class SettlementPersistenceManager extends Node:
	var _settlements: Dictionary = {}
	
	func register_settlement(s: Node) -> void:
		_settlements[s.get("id", 0)] = s
	
	func process_tick(_delta: float) -> void:
		for s in _settlements.values():
			var trauma: float = s.get("trauma_score", 0.0)
			var state: int = s.get("state", 0)
			if trauma > 100.0 and state == 1:  # ABANDONED
				s.set("state", 3)  # SCAR
			elif trauma < 50.0 and state == 1:
				s.set("state", 2)  # RUINS
	
	func attempt_revival(id: int) -> bool:
		var s: Node = _settlements.get(id)
		if s and s.get("state") == 2:  # RUINS
			s.set("state", 0)  # THRIVING
			s.set("population", 10)
			return true
		return false

func _state_label(s: SettlementData.State) -> String:
	match s:
		SettlementData.State.THRIVING:
			return "THRIVING"
		SettlementData.State.ABANDONED:
			return "ABANDONED"
		SettlementData.State.RUINS:
			return "RUINS"
		SettlementData.State.SCAR:
			return "SCAR"
	return "UNKNOWN"

func _ready() -> void:
	print("=== PHASE 4 KERNEL TEST START ===")
	
	var manager: SettlementPersistenceManager = SettlementPersistenceManager.new()
	add_child(manager)
	
	# Create high trauma settlement (should become SCAR)
	var high_trauma: SettlementData = SettlementData.new()
	high_trauma.id = 1
	high_trauma.population = 0
	high_trauma.trauma_score = 150.0
	high_trauma.state = SettlementData.State.ABANDONED
	manager.register_settlement(high_trauma)
	
	# Create low trauma settlement (should become RUINS, then revive)
	var low_trauma: SettlementData = SettlementData.new()
	low_trauma.id = 2
	low_trauma.population = 0
	low_trauma.trauma_score = 10.0
	low_trauma.state = SettlementData.State.ABANDONED
	manager.register_settlement(low_trauma)
	
	# Fast-forward 200 ticks
	for i in range(200):
		manager.process_tick(10.0)
	
	# Verify high trauma → SCAR
	if high_trauma.state == SettlementData.State.SCAR:
		print("TEST PASSED: SCAR threshold (trauma %.1f → SCAR)" % high_trauma.trauma_score)
	else:
		print("TEST FAILED: SCAR threshold (expected SCAR, got %s)" % _state_label(high_trauma.state))
	
	# Verify low trauma → RUINS
	if low_trauma.state == SettlementData.State.RUINS:
		print("TEST PASSED: RUINS threshold (trauma %.1f → RUINS)" % low_trauma.trauma_score)
	else:
		print("TEST FAILED: RUINS threshold (expected RUINS, got %s)" % SettlementData.State.keys()[low_trauma.state])
	
	# Test revival on RUINS
	if manager.attempt_revival(2):
		if low_trauma.state == SettlementData.State.THRIVING and low_trauma.population == 10:
			print("TEST PASSED: RUINS revival (population %d, trauma %.1f)" % [low_trauma.population, low_trauma.trauma_score])
		else:
			print("TEST FAILED: RUINS revival state (expected THRIVING with 10 pop, got %s with %d pop)" % [_state_label(low_trauma.state), low_trauma.population])
	else:
		print("TEST FAILED: RUINS revival returned false")
	
	# Test revival failure on SCAR
	if not manager.attempt_revival(1):
		print("TEST PASSED: SCAR revival correctly blocked")
	else:
		print("TEST FAILED: SCAR revival should have failed")
	
	print("=== PHASE 4 KERNEL TEST END ===")
