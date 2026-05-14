extends Node
## Consolidated Faction Manager
## Combines faction and authority systems into one autoload
## Reduces autoload count while preserving faction functionality

# Child nodes for faction subsystems (loaded on-demand)
var _faction_registry: Node
var _faction_system: Node
var _authority_system: Node

var _faction_registry_loaded: bool = false
var _faction_system_loaded: bool = false
var _authority_system_loaded: bool = false

enum AuthorityContext {
	MILITARY = 0,
	CIVIL = 1,
	RELIGIOUS = 2,
	KNOWLEDGE = 3,
}

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

func _ensure_faction_registry() -> void:
	if not _faction_registry_loaded:
		_faction_registry = _load_sub("FactionRegistry", "res://autoloads/FactionRegistry.gd")
		_faction_registry_loaded = true

func _ensure_faction_system() -> void:
	if not _faction_system_loaded:
		_faction_system = _load_sub("FactionSystem", "res://autoloads/FactionSystem.gd")
		_faction_system_loaded = true

func _ensure_authority() -> void:
	if not _authority_system_loaded:
		_authority_system = _load_sub("AuthoritySystem", "res://autoloads/AuthoritySystem.gd")
		_authority_system_loaded = true

## Get a specific faction subsystem (loads if not already loaded)
func get_subsystem(name: String) -> Node:
	match name:
		"faction_registry": _ensure_faction_registry(); return _faction_registry
		"faction_system": _ensure_faction_system(); return _faction_system
		"authority_system": _ensure_authority(); return _authority_system
		_: return null

## Register faction (delegates to FactionRegistry if available)
func register_faction(faction_id: int, name: String, settlement_id: int) -> void:
	_ensure_faction_registry()
	if _faction_registry != null and _faction_registry.has_method("register_faction"):
		_faction_registry.register_faction(faction_id, name, settlement_id)

## Get faction (delegates to FactionRegistry if available)
func get_faction(faction_id: int) -> Dictionary:
	_ensure_faction_registry()
	if _faction_registry != null and _faction_registry.has_method("get_faction"):
		return _faction_registry.get_faction(faction_id)
	return {}

## Set authority (delegates to AuthoritySystem if available)
func set_authority(settlement_id: int, authority_type: String, authority_id: int) -> void:
	_ensure_authority()
	if _authority_system != null and _authority_system.has_method("set_authority"):
		_authority_system.set_authority(settlement_id, authority_type, authority_id)

## Forward getters for subsystems
func get_faction_registry() -> Node:
	return get_subsystem("faction_registry")

func get_faction_system() -> Node:
	return get_subsystem("faction_system")

func get_authority_system() -> Node:
	return get_subsystem("authority_system")

## Forward AuthoritySystem API for authority-related calls
func apply_authority_bonus(base_priority: int, pawn_id: int) -> int:
	_ensure_authority()
	if _authority_system != null and _authority_system.has_method("apply_authority_bonus"):
		return _authority_system.apply_authority_bonus(base_priority, pawn_id)
	return base_priority

func get_authority_level(pawn_id: int, context: int) -> float:
	_ensure_authority()
	if _authority_system != null and _authority_system.has_method("get_authority_level"):
		return _authority_system.get_authority_level(pawn_id, context)
	return 0.0

func grant_authority(pawn_id: int, context: int, amount: float, source: String) -> void:
	_ensure_authority()
	if _authority_system != null and _authority_system.has_method("grant_authority"):
		_authority_system.grant_authority(pawn_id, context, amount, source)

func get_authority_context(pawn_id: int) -> Dictionary:
	_ensure_authority()
	if _authority_system != null and _authority_system.has_method("get_authority_context"):
		return _authority_system.get_authority_context(pawn_id)
	return {}


## Compatibility / debug shims used by CreatorDebugMenu and other reporters
func debug_summary_block() -> String:
	_ensure_faction_system()
	_ensure_faction_registry()
	if _faction_system != null and _faction_system.has_method("debug_summary_block"):
		return str(_faction_system.call("debug_summary_block"))
	if _faction_registry != null and _faction_registry.has_method("debug_summary_block"):
		return str(_faction_registry.call("debug_summary_block"))
	return "FactionManager: subsystems not loaded or no debug summary available"


func sync_from_settlements() -> void:
	_ensure_faction_system()
	if _faction_system != null and _faction_system.has_method("sync_from_settlements"):
		_faction_system.call("sync_from_settlements")


func get_synced_house_count() -> int:
	_ensure_faction_system()
	_ensure_faction_registry()
	if _faction_system != null and _faction_system.has_method("get_synced_house_count"):
		return int(_faction_system.call("get_synced_house_count"))
	if _faction_registry != null and _faction_registry.has_method("get_house_count"):
		return int(_faction_registry.call("get_house_count"))
	return 0

