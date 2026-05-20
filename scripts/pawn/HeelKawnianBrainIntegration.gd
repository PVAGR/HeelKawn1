## HeelKawnian Brain Integration Helper
## 
## Add this as a component to HeelKawnian pawn scenes or call from HeelKawnian._ready()
## to bind each character to their autonomous decision-making brain.

extends Node

@export var auto_enable_brain: bool = true  # Enable brain on spawn

var pawn_ref: Node
var brain: CharacterBrainSystem.CharacterBrain

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
	
	var pawn_id = pawn_ref.get("id", "") or str(pawn_ref.get_instance_id())
	brain = CharacterBrainSystem.create_brain(pawn_id, pawn_ref)

## Disable this pawn's brain.
func disable_brain() -> void:
	if brain:
		CharacterBrainSystem.remove_brain(brain.state.character_id)
		brain = null

## Get the current decision from the brain.
func get_brain_decision() -> String:
	if brain:
		return brain.decide_next_action()
	return "IDLE"

## Report an outcome to the brain (used after action completes).
func report_outcome(outcome_quality: float, world_context: String) -> void:
	if brain:
		brain.adapt_to_pressure(outcome_quality, world_context)

## Get the brain's current goal.
func get_current_goal() -> String:
	if brain:
		return brain.state.current_goal
	return "UNKNOWN"

## Get the brain's goal urgency (0.0 to 1.0).
func get_goal_urgency() -> float:
	if brain:
		return brain.state.goal_urgency
	return 0.0

## Serialize brain state for saving.
func serialize() -> Dictionary:
	if brain:
		return CharacterBrainSystem.serialize_brain(brain.state.character_id)
	return {}

## Deserialize and restore brain state from save.
func deserialize(data: Dictionary) -> void:
	if not pawn_ref:
		return
	
	brain = CharacterBrainSystem.deserialize_brain(data, pawn_ref)
	if brain:
		CharacterBrainSystem.brains[brain.state.character_id] = brain
