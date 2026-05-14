extends Node
## Consolidated Player Manager
## Combines player systems into one autoload
## Reduces autoload count while preserving player functionality

# Child nodes for player subsystems (loaded on-demand)
var _player_intent_queue: Node
var _player_gathering: Node
var _player_building: Node
var _incarnation_manager: Node

var _player_intent_queue_loaded: bool = false
var _player_gathering_loaded: bool = false
var _player_building_loaded: bool = false
var _incarnation_manager_loaded: bool = false

func _ready() -> void:
	pass

func _load_sub(name: String, path: String) -> Node:
	var existing: Node = get_node_or_null("/root/" + name)
	if existing != null:
		return existing
	if FileAccess.file_exists(path):
		var loaded: Node = load(path).new()
		loaded.name = name
		add_child(loaded)
		return loaded
	return null

func _ensure_player_intent_queue() -> void:
	if not _player_intent_queue_loaded:
		_player_intent_queue = _load_sub("PlayerIntentQueue", "res://autoloads/PlayerIntentQueue.gd")
		_player_intent_queue_loaded = true

func _ensure_player_gathering() -> void:
	if not _player_gathering_loaded:
		_player_gathering = _load_sub("PlayerGathering", "res://autoloads/PlayerGathering.gd")
		_player_gathering_loaded = true

func _ensure_player_building() -> void:
	if not _player_building_loaded:
		_player_building = _load_sub("PlayerBuilding", "res://autoloads/PlayerBuilding.gd")
		_player_building_loaded = true

func _ensure_incarnation_manager() -> void:
	if not _incarnation_manager_loaded:
		_incarnation_manager = _load_sub("IncarnationManager", "res://autoloads/IncarnationManager.gd")
		_incarnation_manager_loaded = true

## Get a specific player subsystem (loads if not already loaded)
func get_subsystem(name: String) -> Node:
	match name:
		"player_intent_queue": _ensure_player_intent_queue(); return _player_intent_queue
		"player_gathering": _ensure_player_gathering(); return _player_gathering
		"player_building": _ensure_player_building(); return _player_building
		"incarnation_manager": _ensure_incarnation_manager(); return _incarnation_manager
		_: return null

## Queue player intent (delegates to PlayerIntentQueue if available)
func queue_intent(intent_type: String, target: Variant = null) -> void:
	_ensure_player_intent_queue()
	if _player_intent_queue != null and _player_intent_queue.has_method("queue"):
		_player_intent_queue.queue(intent_type, target)

## Process gathering (delegates to PlayerGathering if available)
func process_gathering(player_pawn: Node, world: World) -> void:
	_ensure_player_gathering()
	if _player_gathering != null and _player_gathering.has_method("process"):
		_player_gathering.process(player_pawn, world)

## Process building (delegates to PlayerBuilding if available)
func process_building(player_pawn: Node, world: World, tile: Vector2i) -> void:
	_ensure_player_building()
	if _player_building != null and _player_building.has_method("process"):
		_player_building.process(player_pawn, world, tile)

## Incarnate as pawn (delegates to IncarnationManager if available)
func incarnate(pawn_id: int) -> void:
	_ensure_incarnation_manager()
	if _incarnation_manager != null and _incarnation_manager.has_method("incarnate"):
		_incarnation_manager.incarnate(pawn_id)

## Forward getters for subsystems
func get_player_intent_queue() -> Node:
	return get_subsystem("player_intent_queue")

func get_player_gathering() -> Node:
	return get_subsystem("player_gathering")

func get_player_building() -> Node:
	return get_subsystem("player_building")

func get_incarnation_manager() -> Node:
	return get_subsystem("incarnation_manager")
