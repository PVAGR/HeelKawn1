extends Node
## Consolidated Event Manager
## Combines world event systems into one autoload
## Reduces autoload count while preserving event functionality

# Child nodes for event subsystems (loaded on-demand)
var _world_events: Node
var _world_event_system: Node
var _world_event_seed_manager: Node

var _world_events_loaded: bool = false
var _world_event_system_loaded: bool = false
var _world_event_seed_manager_loaded: bool = false

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

func _ensure_world_events() -> void:
	if not _world_events_loaded:
		_world_events = _load_sub("WorldEvents", "res://autoloads/WorldEvents.gd")
		_world_events_loaded = true

func _ensure_world_event_system() -> void:
	if not _world_event_system_loaded:
		_world_event_system = _load_sub("WorldEventSystem", "res://autoloads/WorldEventSystem.gd")
		_world_event_system_loaded = true

func _ensure_world_event_seed_manager() -> void:
	if not _world_event_seed_manager_loaded:
		_world_event_seed_manager = _load_sub("WorldEventSeedManager", "res://autoloads/WorldEventSeedManager.gd")
		_world_event_seed_manager_loaded = true

## Get a specific event subsystem (loads if not already loaded)
func get_subsystem(name: String) -> Node:
	match name:
		"world_events": _ensure_world_events(); return _world_events
		"world_event_system": _ensure_world_event_system(); return _world_event_system
		"world_event_seed_manager": _ensure_world_event_seed_manager(); return _world_event_seed_manager
		_: return null

## Trigger world event (delegates to WorldEvents if available)
func trigger_event(event_type: String, location: Vector2i, data: Dictionary = {}) -> void:
	_ensure_world_events()
	if _world_events != null and _world_events.has_method("trigger_event"):
		_world_events.trigger_event(event_type, location, data)

## Process events (delegates to WorldEventSystem if available)
func process_events(world: World, tick: int) -> void:
	_ensure_world_event_system()
	if _world_event_system != null and _world_event_system.has_method("process"):
		_world_event_system.process(world, tick)

## Forward getters for subsystems
func get_world_events() -> Node:
	return get_subsystem("world_events")

func get_world_event_system() -> Node:
	return get_subsystem("world_event_system")

func get_world_event_seed_manager() -> Node:
	return get_subsystem("world_event_seed_manager")
