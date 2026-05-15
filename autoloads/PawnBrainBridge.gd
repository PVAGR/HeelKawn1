extends Node
## PawnBrainBridge — connects HeelKawnPawnBrain to the tick loop

const TICK_INTERVAL: int = 5
const BRAIN_PAWN_BATCH_COUNT: int = 4

var _brains: Dictionary = {}
var _last_tick: int = -1
var _GameManager = null

func _ready() -> void:
	_GameManager = get_node_or_null("/root/GameManager")
	if _GameManager != null:
		_GameManager.game_tick.connect(_on_game_tick)

func _on_game_tick(tick: int) -> void:
	if tick - _last_tick < TICK_INTERVAL:
		return
	_last_tick = tick
	_process_brains(tick)

func _process_brains(tick: int) -> void:
	if not is_instance_valid(get_tree()):
		return
	var pawns: Array[Node] = _get_pawns()
	var alive_ids: Dictionary = {}

	for pawn in pawns:
		if not is_instance_valid(pawn):
			continue
		if pawn.data == null or pawn.data.is_dead:
			continue

		var pid: int = pawn.data.id
		alive_ids[pid] = true
		if not _pawn_in_batch(pawn, tick, BRAIN_PAWN_BATCH_COUNT):
			continue

		if ClassDB.class_exists("HeelKawnianManager"):
			HeelKawnianManager.ensure_identity_for_pawn(pawn)

		if not _brains.has(pid):
			var world = pawn.get("_world")
			var brain = HeelKawnPawnBrain.new(pawn.data, world)
			_brains[pid] = brain
		if pawn.has_method("_set_brain_instance"):
			pawn.call("_set_brain_instance", _brains[pid])

		_brains[pid].brain_tick(tick, pawn)

	var to_remove: Array = []
	for pid in _brains:
		if not alive_ids.has(pid):
			var brain = _brains[pid] as HeelKawnPawnBrain
			if brain != null:
				brain.cleanup()
			to_remove.append(pid)
	for pid in to_remove:
		_brains.erase(pid)


func _get_pawns() -> Array[Node]:
	var out: Array[Node] = []
	var typed_pawns: Array[HeelKawnian] = PawnAccess.find_alive_pawns()
	if not typed_pawns.is_empty():
		for pawn in typed_pawns:
			if pawn != null:
				out.append(pawn)
		return out
	return get_tree().get_nodes_in_group("pawns")


func _pawn_stable_batch_id(pawn: Node) -> int:
	if pawn == null:
		return 0
	if pawn.has_method("get_stable_id"):
		return int(pawn.call("get_stable_id"))
	var data = pawn.get("data")
	if data != null and "id" in data:
		return int(data.id)
	var stable_id = pawn.get("stable_id")
	if stable_id != null:
		return int(stable_id)
	var pawn_id = pawn.get("pawn_id")
	if pawn_id != null:
		return int(pawn_id)
	return int(pawn.get_instance_id())


func _pawn_in_batch(pawn: Node, tick: int, batch_count: int) -> bool:
	var safe_batch_count: int = maxi(1, batch_count)
	return posmod(_pawn_stable_batch_id(pawn), safe_batch_count) == posmod(tick, safe_batch_count)


func has_brain_for_pawn_id(pawn_id: int) -> bool:
	return _brains.has(pawn_id)


func get_brain_for_pawn_id(pawn_id: int) -> HeelKawnPawnBrain:
	return _brains.get(pawn_id, null) as HeelKawnPawnBrain


func get_active_brain_count() -> int:
	return _brains.size()
