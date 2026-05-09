extends Node
## PawnBrainBridge — connects HeelKawnPawnBrain to the tick loop

const TICK_INTERVAL: int = 5

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
	var pawns: Array[Node] = get_tree().get_nodes_in_group("pawns")
	var alive_ids: Dictionary = {}

	for pawn in pawns:
		if not is_instance_valid(pawn):
			continue
		if pawn.data == null or pawn.data.is_dead:
			continue

		var pid: int = pawn.data.id
		alive_ids[pid] = true

		if not _brains.has(pid):
			var world = pawn.get("_world")
			var brain = HeelKawnPawnBrain.new(pawn.data, world)
			_brains[pid] = brain

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
