class_name SettlementPersistenceManager
extends Node

signal settlement_state_changed(id: int, new_state: int)

var settlements: Dictionary[int, SettlementData] = {}

func register_settlement(data: SettlementData) -> void:
	settlements[data.id] = data

func process_tick(delta: float) -> void:
	for id: int in settlements:
		var data: SettlementData = settlements[id]
		var old_state: SettlementData.State = data.state
		
		data.process_tick(delta)
		
		if data.state != old_state:
			settlement_state_changed.emit(id, int(data.state))

func attempt_revival(target_id: int) -> bool:
	if not settlements.has(target_id):
		return false
	
	var data: SettlementData = settlements[target_id]
	
	if data.state == SettlementData.State.RUINS:
		data.state = SettlementData.State.THRIVING
		data.trauma_score = 50.0
		data.population = 10
		
		if WorldMemory != null:
			WorldMemory.record_event({
				"type": "settlement_revival",
				"id": target_id,
				"success": true,
				"day": WorldMemory.day if WorldMemory.has_method("day") else 0
			})
		
		return true
	elif data.state == SettlementData.State.SCAR:
		if WorldMemory != null:
			WorldMemory.record_event({
				"type": "settlement_revival",
				"id": target_id,
				"success": false,
				"reason": "permanent_scar",
				"day": WorldMemory.day if WorldMemory.has_method("day") else 0
			})
		
		return false
	
	return false
