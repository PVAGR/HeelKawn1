## HeelKawnian Brain Integration Helper
## 
## Add this as a component to HeelKawnian pawn scenes or call from HeelKawnian._ready()
## to bind each character to their autonomous decision-making brain.

extends Node

@export var auto_enable_brain: bool = true  # Enable brain on spawn

var pawn_ref: Node
var _brain_data: Dictionary = {}  # Stub: stores brain state when CharacterBrainSystem unavailable

func _ready() -> void:
	pawn_ref = get_parent()
	if not pawn_ref:
		push_error("HeelKawnianBrainIntegration: parent is not a valid pawn")
		return
	
	if auto_enable_brain:
		enable_brain()

## Create and attach a brain to this pawn.
func enable_brain() -> void:
	if not pawn_ref or not is_instance_valid(pawn_ref):
		return
	
	var _pid = pawn_ref.get("id")
	var pawn_id = (_pid if _pid != null and _pid != "" else str(pawn_ref.get_instance_id()))
	
	# Stub: log brain creation when CharacterBrainSystem not available
	_brain_data = {"character_id": pawn_id, "current_goal": "IDLE", "goal_urgency": 0.0}
	print("[BrainIntegration] Created stub brain for pawn %s" % pawn_id)

## Disable this pawn's brain.
func disable_brain() -> void:
	_brain_data.clear()

## Get the current decision from the brain.
func get_brain_decision() -> String:
	return _brain_data.get("current_goal", "IDLE")

## Report an outcome to the brain (used after action completes).
func report_outcome(outcome_quality: float, world_context: String) -> void:
	# Stub: log adaptation when CharacterBrainSystem not available
	pass

## Get the brain's current goal.
func get_current_goal() -> String:
	return _brain_data.get("current_goal", "UNKNOWN")

## Get the brain's goal urgency (0.0 to 1.0).
func get_goal_urgency() -> float:
	return _brain_data.get("goal_urgency", 0.0)

## Serialize brain state for saving.
func serialize() -> Dictionary:
	return _brain_data.duplicate(true)

## Deserialize and restore brain state from save.
func deserialize(data: Dictionary) -> void:
	if data:
		_brain_data = data.duplicate(true)
