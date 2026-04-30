extends Node

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
		print("TEST FAILED: SCAR threshold (expected SCAR, got %s)" % SettlementData.State.keys()[high_trauma.state])
	
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
			print("TEST FAILED: RUINS revival state (expected THRIVING with 10 pop, got %s with %d pop)" % [SettlementData.State.keys()[low_trauma.state], low_trauma.population])
	else:
		print("TEST FAILED: RUINS revival returned false")
	
	# Test revival failure on SCAR
	if not manager.attempt_revival(1):
		print("TEST PASSED: SCAR revival correctly blocked")
	else:
		print("TEST FAILED: SCAR revival should have failed")
	
	print("=== PHASE 4 KERNEL TEST END ===")
