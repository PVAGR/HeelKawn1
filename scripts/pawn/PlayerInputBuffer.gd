extends Node
class_name PlayerInputBuffer

## Deterministic FIFO queue of player intents.
const MAX_QUEUE_SIZE: int = 10

var _intent_queue: Array[Dictionary] = []
var _last_action_state: String = "idle"

signal intent_ready(intent: Dictionary)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var action_key: String = ""
		if event.keycode == KEY_W or event.keycode == KEY_UP:
			action_key = "move_north"
		elif event.keycode == KEY_S or event.keycode == KEY_DOWN:
			action_key = "move_south"
		elif event.keycode == KEY_A or event.keycode == KEY_LEFT:
			action_key = "move_west"
		elif event.keycode == KEY_D or event.keycode == KEY_RIGHT:
			action_key = "move_east"
		elif event.keycode == KEY_SPACE:
			action_key = "interact"
		if action_key != "":
			push_intent(action_key)


func push_intent(action: String) -> void:
	if _intent_queue.size() >= MAX_QUEUE_SIZE:
		_intent_queue.pop_front()
	var intent: Dictionary = {"action": action, "queued_tick": GameManager.tick_count}
	_intent_queue.append(intent)
	intent_ready.emit(intent)


func process_next_tick(pawn: Node) -> bool:
	if _intent_queue.is_empty():
		_last_action_state = "idle"
		return false
	var intent: Dictionary = _intent_queue.pop_front()
	return execute_intent(pawn, intent)


func execute_intent(pawn: Node, intent: Dictionary) -> bool:
	var action_type: String = str(intent.get("action", ""))
	var executed: bool = false
	match action_type:
		"move_north":
			executed = bool(pawn.call("move", Vector2i(0, -1))) if pawn.has_method("move") else false
		"move_south":
			executed = bool(pawn.call("move", Vector2i(0, 1))) if pawn.has_method("move") else false
		"move_east":
			executed = bool(pawn.call("move", Vector2i(1, 0))) if pawn.has_method("move") else false
		"move_west":
			executed = bool(pawn.call("move", Vector2i(-1, 0))) if pawn.has_method("move") else false
		"interact":
			executed = bool(pawn.call("interact")) if pawn.has_method("interact") else false
		_:
			executed = false
	if executed and pawn.has_method("record_skill_gain"):
		match action_type:
			"move_north", "move_south", "move_east", "move_west":
				pawn.call("record_skill_gain", "movement", 1)
			"interact":
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
	var intent: Dictionary = _intent_queue[0]
	var delta: Vector2i = Vector2i.ZERO
	match str(intent.get("action", "")):
		"move_north":
			delta = Vector2i(0, -1)
		"move_south":
			delta = Vector2i(0, 1)
		"move_east":
			delta = Vector2i(1, 0)
		"move_west":
			delta = Vector2i(-1, 0)
		_:
			delta = Vector2i.ZERO
	if delta == Vector2i.ZERO:
		return null
	return pawn_pos + delta
