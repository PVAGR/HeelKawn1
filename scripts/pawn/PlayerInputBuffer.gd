extends Node
class_name PlayerInputBuffer

## Deterministic FIFO queue of player intents.
const MAX_QUEUE_SIZE: int = 10
const ACTION_NONE: int = 0
const ACTION_MOVE_NORTH: int = 1
const ACTION_MOVE_SOUTH: int = 2
const ACTION_MOVE_WEST: int = 3
const ACTION_MOVE_EAST: int = 4
const ACTION_INTERACT: int = 5

var _intent_queue: Array[int] = []
var _last_action_state: String = "idle"

signal intent_ready(action_id: int)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var action_id: int = ACTION_NONE
		if event.keycode == KEY_W or event.keycode == KEY_UP:
			action_id = ACTION_MOVE_NORTH
		elif event.keycode == KEY_S or event.keycode == KEY_DOWN:
			action_id = ACTION_MOVE_SOUTH
		elif event.keycode == KEY_A or event.keycode == KEY_LEFT:
			action_id = ACTION_MOVE_WEST
		elif event.keycode == KEY_D or event.keycode == KEY_RIGHT:
			action_id = ACTION_MOVE_EAST
		elif event.keycode == KEY_SPACE:
			action_id = ACTION_INTERACT
		if action_id != ACTION_NONE:
			push_intent(action_id)


func push_intent(action_id: int) -> void:
	if _intent_queue.size() >= MAX_QUEUE_SIZE:
		_intent_queue.pop_front()
	_intent_queue.append(action_id)
	intent_ready.emit(action_id)


func process_next_tick(pawn: Node) -> bool:
	if _intent_queue.is_empty():
		_last_action_state = "idle"
		return false
	var action_id: int = int(_intent_queue.pop_front())
	return execute_intent(pawn, action_id)


func execute_intent(pawn: Node, action_id: int) -> bool:
	var action_type: String = _action_to_string(action_id)
	var executed: bool = false
	match action_id:
		ACTION_MOVE_NORTH:
			executed = bool(pawn.call("move", Vector2i(0, -1))) if pawn.has_method("move") else false
		ACTION_MOVE_SOUTH:
			executed = bool(pawn.call("move", Vector2i(0, 1))) if pawn.has_method("move") else false
		ACTION_MOVE_EAST:
			executed = bool(pawn.call("move", Vector2i(1, 0))) if pawn.has_method("move") else false
		ACTION_MOVE_WEST:
			executed = bool(pawn.call("move", Vector2i(-1, 0))) if pawn.has_method("move") else false
		ACTION_INTERACT:
			executed = bool(pawn.call("interact")) if pawn.has_method("interact") else false
		_:
			executed = false
	if executed and pawn.has_method("record_skill_gain"):
		match action_id:
			ACTION_MOVE_NORTH, ACTION_MOVE_SOUTH, ACTION_MOVE_EAST, ACTION_MOVE_WEST:
				pawn.call("record_skill_gain", "movement", 1)
			ACTION_INTERACT:
				pawn.call("record_skill_gain", "gathering", 2)
	_last_action_state = action_type if executed else "blocked_%s" % action_type
	_record_player_action(pawn, action_type, executed)
	return executed


func _record_player_action(pawn: Node, action_type: String, executed: bool) -> void:
	var pawn_id: int = -1
	var pos: Vector2 = Vector2.ZERO
	if pawn != null and is_instance_valid(pawn):
		var pawn_data: Variant = pawn.get("data")
		if pawn_data != null:
			pawn_id = int(pawn_data.id)
		pos = pawn.global_position
	WorldMemory.record_event({
		"type": "player_action",
		"action": action_type,
		"executed": executed,
		"pawn_id": pawn_id,
		"tick": GameManager.tick_count,
		"pos": {"x": pos.x, "y": pos.y},
	})


func get_queue_size() -> int:
	return _intent_queue.size()


func get_last_action_state() -> String:
	return _last_action_state


func get_queued_target(pawn_pos: Vector2i) -> Variant:
	if _intent_queue.is_empty():
		return null
	var action_id: int = int(_intent_queue[0])
	var delta: Vector2i = Vector2i.ZERO
	match action_id:
		ACTION_MOVE_NORTH:
			delta = Vector2i(0, -1)
		ACTION_MOVE_SOUTH:
			delta = Vector2i(0, 1)
		ACTION_MOVE_EAST:
			delta = Vector2i(1, 0)
		ACTION_MOVE_WEST:
			delta = Vector2i(-1, 0)
		_:
			delta = Vector2i.ZERO
	if delta == Vector2i.ZERO:
		return null
	return pawn_pos + delta


func _action_to_string(action_id: int) -> String:
	match action_id:
		ACTION_MOVE_NORTH:
			return "move_north"
		ACTION_MOVE_SOUTH:
			return "move_south"
		ACTION_MOVE_EAST:
			return "move_east"
		ACTION_MOVE_WEST:
			return "move_west"
		ACTION_INTERACT:
			return "interact"
		_:
			return "unknown"
