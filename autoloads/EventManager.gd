extends Node
## Consolidated Event Manager
## Combines world event systems into one autoload
## Reduces autoload count while preserving event functionality

# Child nodes for event subsystems (loaded on-demand)
var _world_events: Node
var _world_event_system: Node
var _world_event_seed_manager: Node

var _subsystems_loaded: bool = false

func _ready() -> void:
	print("[EventManager] Initialized")

## Load event subsystems on-demand (not at startup)
func _load_subsystems() -> void:
	if _subsystems_loaded:
		return
	
	# Load event subsystems as children
	if FileAccess.file_exists("res://autoloads/WorldEvents.gd"):
		_world_events = load("res://autoloads/WorldEvents.gd").new()
		_world_events.name = "WorldEvents"
		add_child(_world_events)
	
	if FileAccess.file_exists("res://autoloads/WorldEventSystem.gd"):
		_world_event_system = load("res://autoloads/WorldEventSystem.gd").new()
		_world_event_system.name = "WorldEventSystem"
		add_child(_world_event_system)
	
	if FileAccess.file_exists("res://autoloads/WorldEventSeedManager.gd"):
		_world_event_seed_manager = load("res://autoloads/WorldEventSeedManager.gd").new()
		_world_event_seed_manager.name = "WorldEventSeedManager"
		add_child(_world_event_seed_manager)
	
	_subsystems_loaded = true
	print("[EventManager] Event subsystems loaded")

## Get a specific event subsystem (loads if not already loaded)
func get_subsystem(name: String) -> Node:
	_load_subsystems()
	match name:
		"world_events": return _world_events
		"world_event_system": return _world_event_system
		"world_event_seed_manager": return _world_event_seed_manager
		_: return null

## Trigger world event (delegates to WorldEvents if available)
func trigger_event(event_type: String, location: Vector2i, data: Dictionary = {}) -> void:
	if _world_events == null:
		_load_subsystems()
	if _world_events != null and _world_events.has_method("trigger_event"):
		_world_events.trigger_event(event_type, location, data)

## Process events (delegates to WorldEventSystem if available)
func process_events(world: World, tick: int) -> void:
	if _world_event_system == null:
		_load_subsystems()
	if _world_event_system != null and _world_event_system.has_method("process"):
		_world_event_system.process(world, tick)

## Forward getters for subsystems
func get_world_events() -> Node:
	return get_subsystem("world_events")

func get_world_event_system() -> Node:
	return get_subsystem("world_event_system")

func get_world_event_seed_manager() -> Node:
	return get_subsystem("world_event_seed_manager")
