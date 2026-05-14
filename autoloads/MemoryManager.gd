extends Node
## Consolidated Memory Manager
## Combines niche memory systems into one autoload
## Reduces autoload count while preserving memory functionality

# Core memory systems (kept separate as autoloads - essential)
@onready var WorldMemory = get_node_or_null("/root/WorldMemory")
@onready var CulturalMemory = get_node_or_null("/root/CulturalMemory")

# Child nodes for niche memory subsystems (loaded on-demand)
var _age_memory: Node
var _intent_memory: Node
var _remnant_memory: Node
var _myth_memory: Node
var _road_memory: Node
var _sacred_memory: Node
var _footpath_memory: Node
var _chronicle_log: Node

var _subsystems_loaded: bool = false

func _ready() -> void:
	print("[MemoryManager] Initialized")

## Load memory subsystems on-demand (not at startup)
func _load_subsystems() -> void:
	if _subsystems_loaded:
		return
	
	_age_memory = get_node_or_null("/root/AgeMemory")
	_intent_memory = get_node_or_null("/root/IntentMemory")
	_remnant_memory = get_node_or_null("/root/RemnantMemory")
	_myth_memory = get_node_or_null("/root/MythMemory")
	_road_memory = get_node_or_null("/root/RoadMemory")
	_sacred_memory = get_node_or_null("/root/SacredMemory")
	_footpath_memory = get_node_or_null("/root/FootpathMemory")
	_chronicle_log = get_node_or_null("/root/ChronicleLog")
	
	# Fallback: load from file if singleton not present
	if _age_memory == null and FileAccess.file_exists("res://autoloads/AgeMemory.gd"):
		_age_memory = load("res://autoloads/AgeMemory.gd").new()
		_age_memory.name = "AgeMemory"
		add_child(_age_memory)
	if _intent_memory == null and FileAccess.file_exists("res://autoloads/IntentMemory.gd"):
		_intent_memory = load("res://autoloads/IntentMemory.gd").new()
		_intent_memory.name = "IntentMemory"
		add_child(_intent_memory)
	if _remnant_memory == null and FileAccess.file_exists("res://autoloads/RemnantMemory.gd"):
		_remnant_memory = load("res://autoloads/RemnantMemory.gd").new()
		_remnant_memory.name = "RemnantMemory"
		add_child(_remnant_memory)
	if _myth_memory == null and FileAccess.file_exists("res://autoloads/MythMemory.gd"):
		_myth_memory = load("res://autoloads/MythMemory.gd").new()
		_myth_memory.name = "MythMemory"
		add_child(_myth_memory)
	if _road_memory == null and FileAccess.file_exists("res://autoloads/RoadMemory.gd"):
		_road_memory = load("res://autoloads/RoadMemory.gd").new()
		_road_memory.name = "RoadMemory"
		add_child(_road_memory)
	if _sacred_memory == null and FileAccess.file_exists("res://autoloads/SacredMemory.gd"):
		_sacred_memory = load("res://autoloads/SacredMemory.gd").new()
		_sacred_memory.name = "SacredMemory"
		add_child(_sacred_memory)
	if _footpath_memory == null and FileAccess.file_exists("res://autoloads/FootpathMemory.gd"):
		_footpath_memory = load("res://autoloads/FootpathMemory.gd").new()
		_footpath_memory.name = "FootpathMemory"
		add_child(_footpath_memory)
	if _chronicle_log == null and FileAccess.file_exists("res://autoloads/ChronicleLog.gd"):
		_chronicle_log = load("res://autoloads/ChronicleLog.gd").new()
		_chronicle_log.name = "ChronicleLog"
		add_child(_chronicle_log)
	
	_subsystems_loaded = true

## Get a specific memory subsystem (loads if not already loaded)
func get_subsystem(name: String) -> Node:
	_load_subsystems()
	match name:
		"age_memory": return _age_memory
		"intent_memory": return _intent_memory
		"remnant_memory": return _remnant_memory
		"myth_memory": return _myth_memory
		"road_memory": return _road_memory
		"sacred_memory": return _sacred_memory
		"footpath_memory": return _footpath_memory
		"chronicle_log": return _chronicle_log
		_: return null

## Record age-related event (delegates to AgeMemory if available)
func record_age_event(pawn_id: int, age: int, event_type: String) -> void:
	if _age_memory == null:
		_load_subsystems()
	if _age_memory != null and _age_memory.has_method("record_age_event"):
		_age_memory.record_age_event(pawn_id, age, event_type)

## Record intent (delegates to IntentMemory if available)
func record_intent(pawn_id: int, intent_type: String, target_id: int = -1) -> void:
	if _intent_memory == null:
		_load_subsystems()
	if _intent_memory != null and _intent_memory.has_method("record_intent"):
		_intent_memory.record_intent(pawn_id, intent_type, target_id)

## Record remnant (delegates to RemnantMemory if available)
func record_remnant(settlement_id: int, remnant_type: String) -> void:
	if _remnant_memory == null:
		_load_subsystems()
	if _remnant_memory != null and _remnant_memory.has_method("record_remnant"):
		_remnant_memory.record_remnant(settlement_id, remnant_type)

## Record myth (delegates to MythMemory if available)
func record_myth(settlement_id: int, myth_type: String, description: String) -> void:
	if _myth_memory == null:
		_load_subsystems()
	if _myth_memory != null and _myth_memory.has_method("record_myth"):
		_myth_memory.record_myth(settlement_id, myth_type, description)

## Record road (delegates to RoadMemory if available)
func record_road(from_tile: Vector2i, to_tile: Vector2i) -> void:
	if _road_memory == null:
		_load_subsystems()
	if _road_memory != null and _road_memory.has_method("record_road"):
		_road_memory.record_road(from_tile, to_tile)

## Record sacred site (delegates to SacredMemory if available)
func record_sacred_site(tile: Vector2i, sacred_type: String) -> void:
	if _sacred_memory == null:
		_load_subsystems()
	if _sacred_memory != null and _sacred_memory.has_method("record_sacred_site"):
		_sacred_memory.record_sacred_site(tile, sacred_type)

## Record footpath (delegates to FootpathMemory if available)
func record_footpath(tile: Vector2i, intensity: float) -> void:
	if _footpath_memory == null:
		_load_subsystems()
	if _footpath_memory != null and _footpath_memory.has_method("record_footpath"):
		_footpath_memory.record_footpath(tile, intensity)

## Record chronicle entry (delegates to ChronicleLog if available)
func record_chronicle(entry: Dictionary) -> void:
	if _chronicle_log == null:
		_load_subsystems()
	if _chronicle_log != null and _chronicle_log.has_method("record"):
		_chronicle_log.record(entry)

## Recompute (for memory systems that need recompute)
func recompute_age() -> void:
	if _age_memory == null:
		_load_subsystems()
	if _age_memory != null and _age_memory.has_method("recompute"):
		_age_memory.recompute()

## Get ambient freq shift (delegates to AgeMemory if available)
func get_ambient_freq_shift() -> float:
	if _age_memory == null:
		_load_subsystems()
	if _age_memory != null and _age_memory.has_method("get_ambient_freq_shift"):
		return _age_memory.get_ambient_freq_shift()
	return 0.0

## Get region myth state (delegates to MythMemory if available)
func get_region_myth_state(region_key: int) -> int:
	if _myth_memory == null:
		_load_subsystems()
	if _myth_memory != null and _myth_memory.has_method("get_region_myth_state"):
		return _myth_memory.get_region_myth_state(region_key)
	return 0

## Get site count (delegates to SacredMemory if available)
func site_count() -> int:
	if _sacred_memory == null:
		_load_subsystems()
	if _sacred_memory != null and _sacred_memory.has_method("site_count"):
		return _sacred_memory.site_count()
	return 0

## Get traversal (delegates to RoadMemory if available)
func get_traversal(rx: int, ry: int) -> int:
	if _road_memory == null:
		_load_subsystems()
	if _road_memory != null and _road_memory.has_method("get_traversal"):
		return _road_memory.get_traversal(rx, ry)
	return 0

## Get road T1 constant (delegates to RoadMemory if available)
func get_road_t1() -> int:
	if _road_memory == null:
		_load_subsystems()
	if _road_memory != null and _road_memory.has_method("get_road_t1"):
		return _road_memory.get_road_t1()
	return 0

## Flush dirty tiles (delegates to RoadMemory if available)
func flush_dirty_tiles(world: World) -> void:
	if _road_memory == null:
		_load_subsystems()
	if _road_memory != null and _road_memory.has_method("flush_dirty_tiles"):
		_road_memory.flush_dirty_tiles(world)

## Seed births from current world (delegates to RemnantMemory if available)
func seed_births_from_current_world(world: World) -> void:
	if _remnant_memory == null:
		_load_subsystems()
	if _remnant_memory != null and _remnant_memory.has_method("seed_births_from_current_world"):
		_remnant_memory.seed_births_from_current_world(world)

## Recompute intent (delegates to IntentMemory if available)
func recompute_intent(world: World) -> void:
	if _intent_memory == null:
		_load_subsystems()
	if _intent_memory != null and _intent_memory.has_method("recompute"):
		_intent_memory.recompute(world)

## Get INTENT_HOLD constant (delegates to IntentMemory if available)
func get_intent_hold() -> int:
	if _intent_memory == null:
		_load_subsystems()
	if _intent_memory != null and _intent_memory.has_method("INTENT_HOLD"):
		return _intent_memory.INTENT_HOLD
	return 0

## Get INTENT_GROW constant (delegates to IntentMemory if available)
func get_intent_grow() -> int:
	if _intent_memory == null:
		_load_subsystems()
	if _intent_memory != null and _intent_memory.has_method("INTENT_GROW"):
		return _intent_memory.INTENT_GROW
	return 0

## Get INTENT_ABANDON constant (delegates to IntentMemory if available)
func get_intent_abandon() -> int:
	if _intent_memory == null:
		_load_subsystems()
	if _intent_memory != null and _intent_memory.has_method("INTENT_ABANDON"):
		return _intent_memory.INTENT_ABANDON
	return 0

## Get settlement intent (delegates to IntentMemory if available)
func get_settlement_intent() -> Dictionary:
	if _intent_memory == null:
		_load_subsystems()
	if _intent_memory != null and _intent_memory.has_method("settlement_intent"):
		return _intent_memory.settlement_intent
	return {}

## Forward getters for subsystems
func get_age_memory() -> Node:
	return get_subsystem("age_memory")

func get_intent_memory() -> Node:
	return get_subsystem("intent_memory")

func get_remnant_memory() -> Node:
	return get_subsystem("remnant_memory")

func get_myth_memory() -> Node:
	return get_subsystem("myth_memory")

func get_road_memory() -> Node:
	return get_subsystem("road_memory")

func get_sacred_memory() -> Node:
	return get_subsystem("sacred_memory")

func get_footpath_memory() -> Node:
	return get_subsystem("footpath_memory")

func get_chronicle_log() -> Node:
	return get_subsystem("chronicle_log")

func footpath_get_wear_at(tile: Vector2i) -> float:
	if _footpath_memory == null:
		_load_subsystems()
	if _footpath_memory != null and _footpath_memory.has_method("get_wear_at"):
		return _footpath_memory.get_wear_at(tile)
	return 0.0

func footpath_bind_context(world: Node, pawn_spawner: Node) -> void:
	if _footpath_memory == null:
		_load_subsystems()
	if _footpath_memory != null and _footpath_memory.has_method("bind_context"):
		_footpath_memory.bind_context(world, pawn_spawner)

func footpath_clear() -> void:
	if _footpath_memory == null:
		_load_subsystems()
	if _footpath_memory != null and _footpath_memory.has_method("clear"):
		_footpath_memory.clear()
