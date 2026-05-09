extends Node
## SettlementAIBridge — connects settlement AI to the tick loop

const SYNC_INTERVAL_TICKS: int = 120

var _last_sync_tick: int = -1

var _WorldAI = null
var _SettlementMemory = null
var _GameManager = null

func _ready() -> void:
	_WorldAI = get_node_or_null("/root/WorldAI")
	_SettlementMemory = get_node_or_null("/root/SettlementMemory")
	_GameManager = get_node_or_null("/root/GameManager")
	if _GameManager != null:
		_GameManager.game_tick.connect(_on_game_tick)

func _on_game_tick(tick: int) -> void:
	if tick - _last_sync_tick < SYNC_INTERVAL_TICKS:
		return
	_last_sync_tick = tick
	_sync_settlements()

func _sync_settlements() -> void:
	if _SettlementMemory == null or _WorldAI == null:
		return

	var current_ids: Dictionary = {}
	for st in _SettlementMemory.settlements:
		if not (st is Dictionary):
			continue
		var center: int = int(st.get("center_region", -1))
		if center < 0:
			continue
		current_ids[center] = true
		if not _WorldAI.active_settlements.has(center):
			var name: String = str(st.get("name", "Unnamed"))
			var rx: int = center & 0xFFFF
			var ry: int = (center >> 16) & 0xFFFF
			var pos: Vector2i = Vector2i(rx * 16 + 8, ry * 16 + 8)
			var settlement_ai = SettlementAI.new(center, name, pos)
			_WorldAI.active_settlements[center] = settlement_ai

	var to_remove: Array = []
	for sid in _WorldAI.active_settlements:
		if not current_ids.has(sid):
			to_remove.append(sid)
	for sid in to_remove:
		_WorldAI.active_settlements.erase(sid)
