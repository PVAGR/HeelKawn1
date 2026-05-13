extends Node
## Consolidated Player Manager
## Combines player systems into one autoload
## Reduces autoload count while preserving player functionality

# Child nodes for player subsystems (loaded on-demand)
var _player_intent_queue: Node
var _player_gathering: Node
var _player_building: Node
var _incarnation_manager: Node

var _subsystems_loaded: bool = false

func _ready() -> void:
	print("[PlayerManager] Initialized")

## Load player subsystems on-demand (not at startup)
func _load_subsystems() -> void:
	if _subsystems_loaded:
		return
	
	# Load player subsystems as children
	if FileAccess.file_exists("res://autoloads/PlayerIntentQueue.gd"):
		_player_intent_queue = load("res://autoloads/PlayerIntentQueue.gd").new()
		_player_intent_queue.name = "PlayerIntentQueue"
		add_child(_player_intent_queue)
	
	if FileAccess.file_exists("res://autoloads/PlayerGathering.gd"):
		_player_gathering = load("res://autoloads/PlayerGathering.gd").new()
		_player_gathering.name = "PlayerGathering"
		add_child(_player_gathering)
	
	if FileAccess.file_exists("res://autoloads/PlayerBuilding.gd"):
		_player_building = load("res://autoloads/PlayerBuilding.gd").new()
		_player_building.name = "PlayerBuilding"
		add_child(_player_building)
	
	if FileAccess.file_exists("res://autoloads/IncarnationManager.gd"):
		_incarnation_manager = load("res://autoloads/IncarnationManager.gd").new()
		_incarnation_manager.name = "IncarnationManager"
		add_child(_incarnation_manager)
	
	_subsystems_loaded = true
	print("[PlayerManager] Player subsystems loaded")

## Get a specific player subsystem (loads if not already loaded)
func get_subsystem(name: String) -> Node:
	_load_subsystems()
	match name:
		"player_intent_queue": return _player_intent_queue
		"player_gathering": return _player_gathering
		"player_building": return _player_building
		"incarnation_manager": return _incarnation_manager
		_: return null

## Queue player intent (delegates to PlayerIntentQueue if available)
func queue_intent(intent_type: String, target: Variant = null) -> void:
	if _player_intent_queue == null:
		_load_subsystems()
	if _player_intent_queue != null and _player_intent_queue.has_method("queue"):
		_player_intent_queue.queue(intent_type, target)

## Process gathering (delegates to PlayerGathering if available)
func process_gathering(player_pawn: Node, world: World) -> void:
	if _player_gathering == null:
		_load_subsystems()
	if _player_gathering != null and _player_gathering.has_method("process"):
		_player_gathering.process(player_pawn, world)

## Process building (delegates to PlayerBuilding if available)
func process_building(player_pawn: Node, world: World, tile: Vector2i) -> void:
	if _player_building == null:
		_load_subsystems()
	if _player_building != null and _player_building.has_method("process"):
		_player_building.process(player_pawn, world, tile)

## Incarnate as pawn (delegates to IncarnationManager if available)
func incarnate(pawn_id: int) -> void:
	if _incarnation_manager == null:
		_load_subsystems()
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
