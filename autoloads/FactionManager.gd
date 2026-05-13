extends Node
## Consolidated Faction Manager
## Combines faction and authority systems into one autoload
## Reduces autoload count while preserving faction functionality

# Child nodes for faction subsystems (loaded on-demand)
var _faction_registry: Node
var _faction_system: Node
var _authority_system: Node

var _subsystems_loaded: bool = false

func _load_subsystems() -> void:
	if _subsystems_loaded:
		return
	_ready()

func _ready() -> void:
	_faction_registry = get_node_or_null("/root/FactionRegistry")
	_faction_system = get_node_or_null("/root/FactionSystem")
	_authority_system = get_node_or_null("/root/AuthoritySystem")
	
	if _faction_registry == null and FileAccess.file_exists("res://autoloads/FactionRegistry.gd"):
		_faction_registry = load("res://autoloads/FactionRegistry.gd").new()
		_faction_registry.name = "FactionRegistry"
		add_child(_faction_registry)
	if _faction_system == null and FileAccess.file_exists("res://autoloads/FactionSystem.gd"):
		_faction_system = load("res://autoloads/FactionSystem.gd").new()
		_faction_system.name = "FactionSystem"
		add_child(_faction_system)
	if _authority_system == null and FileAccess.file_exists("res://autoloads/AuthoritySystem.gd"):
		_authority_system = load("res://autoloads/AuthoritySystem.gd").new()
		_authority_system.name = "AuthoritySystem"
		add_child(_authority_system)
	
	_subsystems_loaded = true

## Get a specific faction subsystem (loads if not already loaded)
func get_subsystem(name: String) -> Node:
	_load_subsystems()
	match name:
		"faction_registry": return _faction_registry
		"faction_system": return _faction_system
		"authority_system": return _authority_system
		_: return null

## Register faction (delegates to FactionRegistry if available)
func register_faction(faction_id: int, name: String, settlement_id: int) -> void:
	if _faction_registry == null:
		_load_subsystems()
	if _faction_registry != null and _faction_registry.has_method("register_faction"):
		_faction_registry.register_faction(faction_id, name, settlement_id)

## Get faction (delegates to FactionRegistry if available)
func get_faction(faction_id: int) -> Dictionary:
	if _faction_registry == null:
		_load_subsystems()
	if _faction_registry != null and _faction_registry.has_method("get_faction"):
		return _faction_registry.get_faction(faction_id)
	return {}

## Set authority (delegates to AuthoritySystem if available)
func set_authority(settlement_id: int, authority_type: String, authority_id: int) -> void:
	if _authority_system == null:
		_load_subsystems()
	if _authority_system != null and _authority_system.has_method("set_authority"):
		_authority_system.set_authority(settlement_id, authority_type, authority_id)

## Forward getters for subsystems
func get_faction_registry() -> Node:
	return get_subsystem("faction_registry")

func get_faction_system() -> Node:
	return get_subsystem("faction_system")

func get_authority_system() -> Node:
	return get_subsystem("authority_system")
