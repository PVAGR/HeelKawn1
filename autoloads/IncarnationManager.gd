extends Node
## IncarnationManager — Bridges player incarnation with PawnConsciousness.
##
## Tracks the incarnation lifecycle and ensures player pawns get the same
## consciousness treatment (memories, dreams, trauma, growth) as AI pawns.
##
## Purely additive — hooks into existing flows without changing them.
## Designed for future multiplayer: player_id String supports multiple players.

signal player_incarnated(player_id: String, pawn_id: int)
signal player_ended_incarnation(player_id: String, pawn_id: int, duration_ticks: int)

const DEFAULT_PLAYER_ID: String = "player"

var _incarnations: Dictionary = {}
var _pawn_to_player: Dictionary = {}


func _ready() -> void:
	if GameManager != null and GameManager.has_signal("game_tick"):
		GameManager.game_tick.connect(_on_game_tick)


func _on_game_tick(_tick: int) -> void:
	_passive_consciousness_processing()


func _passive_consciousness_processing() -> void:
	for pawn_id_str in _pawn_to_player.keys():
		var pawn_id: int = int(pawn_id_str)
		_check_awareness_milestones(pawn_id)


func _check_awareness_milestones(pawn_id: int) -> void:
	var level: int = PawnConsciousness.get_awareness_level(pawn_id)
	if level >= 2 and not _has_milestone(pawn_id, "became_aware"):
		_record_milestone(pawn_id, "became_aware")
		PawnConsciousness.record_memory(
			pawn_id, "awareness", "I am real. I think. I remember. I am.",
			50.0, 9, "achievement", [], Vector2i.ZERO
		)
	if level >= 4 and not _has_milestone(pawn_id, "became_enlightened"):
		_record_milestone(pawn_id, "became_enlightened")
		PawnConsciousness.record_memory(
			pawn_id, "enlightenment", "I see the shape of things. The world has patterns.",
			80.0, 10, "achievement", [], Vector2i.ZERO
		)


var _milestones: Dictionary = {}

func _has_milestone(pawn_id: int, milestone: String) -> bool:
	var list: Array = _milestones.get(pawn_id, [])
	return milestone in list

func _record_milestone(pawn_id: int, milestone: String) -> void:
	if not _milestones.has(pawn_id):
		_milestones[pawn_id] = []
	_milestones[pawn_id].append(milestone)


## Called when a player incarnates into a pawn.
## player_id identifies the human; pawn_id is the pawn they now control.
func on_player_incarnated(player_id: String, pawn_id: int) -> void:
	if pawn_id < 0:
		return
	
	_incarnations[player_id] = pawn_id
	_pawn_to_player[pawn_id] = player_id
	
	PawnConsciousness.record_memory(
		pawn_id,
		"incarnation",
		"A presence fills my mind. I am seen. I am chosen. A chronicler walks in my skin.",
		80.0, 10, "achievement", [], Vector2i.ZERO
	)
	
	WorldMemory.record_event({
		"type": "player_incarnation",
		"player_id": player_id,
		"pawn_id": pawn_id,
		"tick": GameManager.tick_count
	})
	
	player_incarnated.emit(player_id, pawn_id)


## Called each time the player-controlled pawn performs an action.
## Records the action as a consciousness memory so the pawn remembers.
func on_player_action(pawn_id: int, action_type: String, action_desc: String, importance: int = 3) -> void:
	if not _pawn_to_player.has(pawn_id):
		return
	
	var category: String = _action_to_category(action_type)
	var emotion: float = _action_emotion(action_type, action_desc)
	
	PawnConsciousness.record_memory(
		pawn_id, action_type, action_desc,
		emotion, importance, category, [], Vector2i.ZERO
	)


## Called when the player-controlled pawn dies.
func on_player_pawn_died(pawn_id: int, cause: String = "unknown") -> void:
	var player_id: String = _pawn_to_player.get(pawn_id, "")
	if player_id.is_empty():
		return
	
	PawnConsciousness.record_memory(
		pawn_id, "death",
		"My journey as an incarnated ends here. I fall: %s." % cause,
		-85.0, 10, "trauma", [], Vector2i.ZERO
	)
	
	var summary: Dictionary = PawnConsciousness.get_consciousness_summary(pawn_id)
	
	WorldMemory.record_event({
		"type": "player_pawn_death",
		"player_id": player_id,
		"pawn_id": pawn_id,
		"cause": cause,
		"final_awareness": summary.get("self_awareness", 0),
		"total_memories": summary.get("memory_count", 0),
		"tick": GameManager.tick_count
	})
	
	_incarnations.erase(player_id)
	_pawn_to_player.erase(pawn_id)


## Called when the player returns to spectator mode (voluntary exit).
func on_player_returned(player_id: String) -> void:
	var pawn_id: int = _incarnations.get(player_id, -1)
	if pawn_id < 0:
		return
	
	PawnConsciousness.record_memory(
		pawn_id, "incarnation_end",
		"The presence withdraws. I am alone in my own mind again, but I remember being more.",
		-30.0, 9, "social", [], Vector2i.ZERO
	)
	
	WorldMemory.record_event({
		"type": "player_incarnation_end",
		"player_id": player_id,
		"pawn_id": pawn_id,
		"tick": GameManager.tick_count
	})
	
	var duration: int = GameManager.tick_count
	player_ended_incarnation.emit(player_id, pawn_id, duration)
	
	_incarnations.erase(player_id)
	_pawn_to_player.erase(pawn_id)


## Check if any player is controlling a given pawn.
func is_pawn_controlled(pawn_id: int) -> bool:
	return _pawn_to_player.has(pawn_id)


## Get the pawn ID a player currently controls, or -1.
func get_player_pawn_id(player_id: String = DEFAULT_PLAYER_ID) -> int:
	return _incarnations.get(player_id, -1)


## Get all active incarnations (player_id -> pawn_id).
func get_active_incarnations() -> Dictionary:
	return _incarnations.duplicate()


## Get the player's current consciousness summary for UI display.
## Returns empty dict if player isn't incarnated.
func get_player_consciousness_summary(player_id: String = DEFAULT_PLAYER_ID) -> Dictionary:
	var pawn_id: int = _incarnations.get(player_id, -1)
	if pawn_id < 0:
		return {"incarnated": false}
	
	var result: Dictionary = PawnConsciousness.get_consciousness_summary(pawn_id)
	result["incarnated"] = true
	result["pawn_id"] = pawn_id
	return result


## Get last N dreams for player's pawn.
func get_player_dreams(limit: int = 5, player_id: String = DEFAULT_PLAYER_ID) -> Array:
	var pawn_id: int = _incarnations.get(player_id, -1)
	if pawn_id < 0:
		return []
	return PawnConsciousness.get_dreams(pawn_id, limit)


## Get full consciousness snapshot for player's pawn (UI deep view).
func get_player_full_consciousness(player_id: String = DEFAULT_PLAYER_ID) -> Dictionary:
	var pawn_id: int = _incarnations.get(player_id, -1)
	if pawn_id < 0:
		return {"incarnated": false}
	return PawnConsciousness.get_consciousness(pawn_id)


func _action_to_category(action_type: String) -> String:
	match action_type:
		"move_north", "move_south", "move_east", "move_west":
			return "survival"
		"interact":
			return "social"
		"inspect":
			return "achievement"
		"drop_item":
			return "survival"
		_:
			return "general"


func _action_emotion(action_type: String, _action_desc: String) -> float:
	match action_type:
		"interact":
			return 15.0
		"inspect":
			return 10.0
		"move_north", "move_south", "move_east", "move_west":
			return 3.0
		"drop_item":
			return -2.0
		_:
			return 5.0
