class_name SettlementData
extends Resource

enum State {
	THRIVING,
	ABANDONED,
	RUINS,
	SCAR
}

@export var id: int = 0
@export var population: int = 0
@export var trauma_score: float = 0.0
@export var state: State = State.THRIVING

func process_tick(delta: float) -> void:
	var old_state: State = state
	
	if state == State.ABANDONED:
		trauma_score -= 0.05 * delta
	
	if trauma_score > 100.0:
		state = State.SCAR
	elif trauma_score < 20.0 and state == State.ABANDONED:
		state = State.RUINS
	
	if state != old_state and WorldMemory != null:
		WorldMemory.record_event({
			"type": "settlement_state_change",
			"id": id,
			"old_state": int(old_state),
			"new_state": int(state),
			"day": WorldMemory.day if WorldMemory.has_method("day") else 0,
			"cause": "derived_from_meaning",
			"trauma_score": trauma_score
		})
