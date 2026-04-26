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
var _command_queue: Array[String] = []
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
	if not _command_queue.is_empty():
		var cmd: String = _command_queue.pop_front()
		var did_cmd: bool = _execute_command(pawn, cmd)
		_last_action_state = "cmd_%s" % cmd if did_cmd else "cmd_blocked"
		return did_cmd
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
	return _intent_queue.size() + _command_queue.size()


func enqueue_chat_command(command: String) -> void:
	var c: String = command.strip_edges().to_lower()
	if c == "":
		return
	if _command_queue.size() >= MAX_QUEUE_SIZE:
		_command_queue.pop_front()
	_command_queue.append(c)


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


func _execute_command(pawn: Node, command: String) -> bool:
	if pawn == null or not is_instance_valid(pawn):
		return false
	if command == "!abdicate":
		return bool(pawn.call("abdicate")) if pawn.has_method("abdicate") else false
	if command.begins_with("!edict "):
		if not pawn.has_method("issue_edict"):
			return false
		var parts: PackedStringArray = command.split(" ")
		if parts.size() < 2:
			return false
		return bool(pawn.call("issue_edict", parts[1]))
	if command == "!pledge_loyalty":
		if not pawn.has_method("pledge_loyalty"):
			return false
		var target: Pawn = _nearest_ruler(pawn as Pawn)
		if target == null:
			return false
		return bool(pawn.call("pledge_loyalty", target))
	if command.begins_with("!propose_war "):
		if not pawn.has_method("propose_war"):
			return false
		var parts_war: PackedStringArray = command.split(" ")
		if parts_war.size() < 2:
			return false
		var target_settlement_id: int = int(parts_war[1])
		return bool(pawn.call("propose_war", target_settlement_id))
	return false


func _nearest_ruler(pawn: Pawn) -> Pawn:
	if pawn == null:
		return null
	var best: Pawn = null
	var best_d2: float = INF
	for n in pawn.get_tree().get_nodes_in_group("pawns"):
		if not (n is Pawn):
			continue
		var p: Pawn = n as Pawn
		if p.data == null:
			continue
		if not SettlementMemory.is_pawn_current_ruler(int(p.data.id)):
			continue
		var d2: float = p.position.distance_squared_to(pawn.position)
		if d2 < best_d2:
			best = p
			best_d2 = d2
	return best
