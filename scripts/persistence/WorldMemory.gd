extends Node
class_name WorldMemoryPersistence

## Persistence layer for world state including settlement status management.
## Handles marking settlements as 'Abandoned' or 'Scarred' based on game events.

## Settlement states
enum SettlementState {
	ACTIVE = 0,
	ABANDONED = 1,
	SCARRED = 2,
	DESTROYED = 3,
}

## Settlement configuration
const SETTLEMENT_STATE_TICKS: int = 5000
## Ticks of inactivity before settlement is abandoned
const ABANDONMENT_THRESHOLD: int = 3000
## Maximum damage 'scar' before settlement is considered scarred
const SCAR_THRESHOLD: int = 80

## Settlement state tracking
var _settlement_states: Dictionary = {}
var _events: Array[Dictionary] = [] # Historical log for Chronicles

## History of state transitions
var _state_transitions: Array[Dictionary] = []


func _ready() -> void:
	if TickManager != null:
		TickManager.mark_tickable_cache_dirty()


func _on_world_tick(tick_number: int) -> void:
	_process_settlement_states(tick_number)


## Update a settlement's state
func set_settlement_state(
	settlement_id: int,
	new_state: int,
	tick_number: int,
	details: Dictionary = {}
) -> void:
	var old_state: int = _settlement_states.get(settlement_id, {}).get("state", SettlementState.ACTIVE)
	
	if new_state == old_state:
		return
	
	# Record transition
	var transition: Dictionary = {
		"settlement_id": settlement_id,
		"old_state": old_state,
		"new_state": new_state,
		"tick": tick_number,
		"details": details,
	}
	_state_transitions.append(transition)
	
	# Update state
	if not _settlement_states.has(settlement_id):
		_settlement_states[settlement_id] = {}
	
	_settlement_states[settlement_id] = {
		"state": new_state,
		"last_update": tick_number,
		"scar": int(details.get("scar", 0)),
		"population": int(details.get("population", 0)),
	}


## Get settlement state
func get_settlement_state(settlement_id: int) -> int:
	if _settlement_states.has(settlement_id):
		return _settlement_states[settlement_id].get("state", SettlementState.ACTIVE)
	return SettlementState.ACTIVE


## Mark settlement as abandoned
func mark_abandoned(settlement_id: int, tick_number: int, reason: String = "") -> void:
	set_settlement_state(settlement_id, SettlementState.ABANDONED, tick_number, {
		"reason": reason,
	})


## Mark settlement as scarred
func mark_scarred(settlement_id: int, tick_number: int, scar_amount: int) -> void:
	set_settlement_state(settlement_id, SettlementState.SCARRED, tick_number, {
		"scar": scar_amount,
	})
	
	# If scar exceeds threshold, may escalate to destroyed
	if scar_amount >= SCAR_THRESHOLD:
		set_settlement_state(settlement_id, SettlementState.DESTROYED, tick_number, {
			"scar": scar_amount,
			"reason": "excessive_scar",
		})


## Process all settlement states each tick
func _process_settlement_states(tick_number: int) -> void:
	for settlement_id in _settlement_states.keys():
		var state_data: Dictionary = _settlement_states[settlement_id]
		var state: int = int(state_data.get("state", SettlementState.ACTIVE))
		var last_update: int = int(state_data.get("last_update", tick_number))
		
		# Skip non-active settlements for abandonment logic
		if state != SettlementState.ACTIVE:
			continue
		
		# Check for abandonment
		var time_since_update: int = tick_number - last_update
		if time_since_update > ABANDONMENT_THRESHOLD:
			mark_abandoned(settlement_id, tick_number, "inactivity")
		
		# Check for scarring from accumulated damage
		var scar: int = int(state_data.get("scar", 0))
		if scar >= SCAR_THRESHOLD:
			set_settlement_state(settlement_id, SettlementState.DESTROYED, tick_number, {
				"scar": scar,
				"reason": "excessive_damage",
			})


## Update settlement scar level
func add_scar(settlement_id: int, amount: int) -> void:
	if not _settlement_states.has(settlement_id):
		_settlement_states[settlement_id] = {"state": SettlementState.ACTIVE, "scar": 0}
	
	_settlement_states[settlement_id]["scar"] = int(_settlement_states[settlement_id].get("scar", 0)) + amount


## Get scar level for settlement
func get_settlement_scar(settlement_id: int) -> int:
	if _settlement_states.has(settlement_id):
		return _settlement_states[settlement_id].get("scar", 0)
	return 0


## Get all settlements in a specific state
func get_settlements_in_state(state: int) -> Array:
	var result: Array = []
	for settlement_id in _settlement_states.keys():
		if _settlement_states[settlement_id].get("state", SettlementState.ACTIVE) == state:
			result.append(settlement_id)
	return result


## Get active settlements count
func get_active_settlements_count() -> int:
	return get_settlements_in_state(SettlementState.ACTIVE).size()


## Get recent state transitions
func get_recent_transitions(max_count: int = 20) -> Array:
	if _state_transitions.size() > max_count:
		return _state_transitions.slice(_state_transitions.size() - max_count)
	return _state_transitions.duplicate(true)


## Get all settlement states (for save/load)
func get_all_states() -> Dictionary:
	return _settlement_states.duplicate(true)


## Restore settlement states (from save)
func restore_all_states(states: Dictionary) -> void:
	_settlement_states = states.duplicate(true)

func record_event(type: String, victim_id: int, actor_id: int, pos: Vector2i, extra: String = "") -> void:
	var e = {
		"t": GameManager.tick_count if GameManager else 0,
		"type": type,
		"vid": victim_id,
		"pid": actor_id,
		"r": _region_key(pos.x, pos.y),
		"n": extra
	}
	_events.append(e)
	if _events.size() > 1000: _events.remove_at(0)

func _region_key(x: int, y: int) -> int:
	return (int(y) / 16) * 16 + (int(x) / 16)
