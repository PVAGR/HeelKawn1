extends Node
## Consolidated Memory Manager
## Lazy-loads subsystems on first access only.

# Intent constants (re-exported from IntentMemory)
const INTENT_GROW: int = 0
const INTENT_HOLD: int = 1
const INTENT_ABANDON: int = 2
const INTENT_RECOVER: int = 3

func get_intent_hold() -> int:
	return INTENT_HOLD

func get_intent_grow() -> int:
	return INTENT_GROW

func get_intent_abandon() -> int:
	return INTENT_ABANDON

func get_intent_recover() -> int:
	return INTENT_RECOVER

# Core memory systems (kept separate as autoloads - essential)
@onready var WorldMemory = get_node_or_null("/root/WorldMemory")
@onready var CulturalMemory = get_node_or_null("/root/CulturalMemory")

var _age_memory: Node
var _intent_memory: Node
var _remnant_memory: Node
var _myth_memory: Node
var _road_memory: Node
var _sacred_memory: Node
var _footpath_memory: Node
var _chronicle_log: Node

var _age_loaded: bool = false
var _intent_loaded: bool = false
var _remnant_loaded: bool = false
var _myth_loaded: bool = false
var _road_loaded: bool = false
var _sacred_loaded: bool = false
var _footpath_loaded: bool = false
var _chronicle_loaded: bool = false

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

func _ensure_age() -> void:
	if not _age_loaded:
		_age_memory = _load_sub("AgeMemory", "res://autoloads/AgeMemory.gd")
		_age_loaded = true

func _ensure_intent() -> void:
	if not _intent_loaded:
		_intent_memory = _load_sub("IntentMemory", "res://autoloads/IntentMemory.gd")
		_intent_loaded = true

func _ensure_remnant() -> void:
	if not _remnant_loaded:
		_remnant_memory = _load_sub("RemnantMemory", "res://autoloads/RemnantMemory.gd")
		_remnant_loaded = true

func _ensure_myth() -> void:
	if not _myth_loaded:
		_myth_memory = _load_sub("MythMemory", "res://autoloads/MythMemory.gd")
		_myth_loaded = true

func _ensure_road() -> void:
	if not _road_loaded:
		_road_memory = _load_sub("RoadMemory", "res://autoloads/RoadMemory.gd")
		_road_loaded = true

func _ensure_sacred() -> void:
	if not _sacred_loaded:
		_sacred_memory = _load_sub("SacredMemory", "res://autoloads/SacredMemory.gd")
		_sacred_loaded = true

func _ensure_footpath() -> void:
	if not _footpath_loaded:
		_footpath_memory = _load_sub("FootpathMemory", "res://autoloads/FootpathMemory.gd")
		_footpath_loaded = true

func _ensure_chronicle() -> void:
	if not _chronicle_loaded:
		_chronicle_log = _load_sub("ChronicleLog", "res://autoloads/ChronicleLog.gd")
		_chronicle_loaded = true

func get_subsystem(name: String) -> Node:
	match name:
		"age_memory": _ensure_age(); return _age_memory
		"intent_memory": _ensure_intent(); return _intent_memory
		"remnant_memory": _ensure_remnant(); return _remnant_memory
		"myth_memory": _ensure_myth(); return _myth_memory
		"road_memory": _ensure_road(); return _road_memory
		"sacred_memory": _ensure_sacred(); return _sacred_memory
		"footpath_memory": _ensure_footpath(); return _footpath_memory
		"chronicle_log": _ensure_chronicle(); return _chronicle_log
		_: return null

## Record age-related event (delegates to AgeMemory if available)
func record_age_event(pawn_id: int, age: int, event_type: String) -> void:
	_ensure_age()
	if _age_memory != null and _age_memory.has_method("record_age_event"):
		_age_memory.record_age_event(pawn_id, age, event_type)

## Record intent (delegates to IntentMemory if available)
func record_intent(pawn_id: int, intent_type: String, target_id: int = -1) -> void:
	_ensure_intent()
	if _intent_memory != null and _intent_memory.has_method("record_intent"):
		_intent_memory.record_intent(pawn_id, intent_type, target_id)

## Record remnant (delegates to RemnantMemory if available)
func record_remnant(settlement_id: int, remnant_type: String) -> void:
	_ensure_remnant()
	if _remnant_memory != null and _remnant_memory.has_method("record_remnant"):
		_remnant_memory.record_remnant(settlement_id, remnant_type)

## Register rebirth success (delegates to MythMemory if available)
func register_myth_rebirth_success(center_rk: int) -> void:
	_ensure_myth()
	if _myth_memory != null and _myth_memory.has_method("register_rebirth_success"):
		_myth_memory.register_rebirth_success(center_rk)

## Get conflict intensity (delegates to MythMemory if available)
func get_myth_conflict_intensity(region_key: int) -> float:
	_ensure_myth()
	if _myth_memory != null and _myth_memory.has_method("get_conflict_intensity"):
		return _myth_memory.get_conflict_intensity(region_key)
	return 0.0

## Record road (delegates to RoadMemory if available)
func record_road(from_tile: Vector2i, to_tile: Vector2i) -> void:
	_ensure_road()
	if _road_memory != null and _road_memory.has_method("record_road"):
		_road_memory.record_road(from_tile, to_tile)

## Record sacred site (delegates to SacredMemory if available)
func record_sacred_site(tile: Vector2i, sacred_type: String) -> void:
	_ensure_sacred()
	if _sacred_memory != null and _sacred_memory.has_method("record_sacred_site"):
		_sacred_memory.record_sacred_site(tile, sacred_type)

## Record footpath (delegates to FootpathMemory if available)
func record_footpath(tile: Vector2i, intensity: float) -> void:
	_ensure_footpath()
	if _footpath_memory != null and _footpath_memory.has_method("record_footpath"):
		_footpath_memory.record_footpath(tile, intensity)

## Record chronicle entry (delegates to ChronicleLog if available)
func record_chronicle(entry: Dictionary) -> void:
	_ensure_chronicle()
	if _chronicle_log != null and _chronicle_log.has_method("record"):
		_chronicle_log.record(entry)

## Recompute (for memory systems that need recompute)
func recompute_age() -> void:
	_ensure_age()
	if _age_memory != null and _age_memory.has_method("recompute"):
		_age_memory.recompute()

## Get ambient freq shift (delegates to AgeMemory if available)
func get_ambient_freq_shift() -> float:
	_ensure_age()
	if _age_memory != null and _age_memory.has_method("get_ambient_freq_shift"):
		return _age_memory.get_ambient_freq_shift()
	return 0.0

## Get region myth state (delegates to MythMemory if available)
func get_region_myth_state(region_key: int) -> int:
	_ensure_myth()
	if _myth_memory != null and _myth_memory.has_method("get_region_myth_state"):
		return _myth_memory.get_region_myth_state(region_key)
	return 0

## Get site count (delegates to SacredMemory if available)
func site_count() -> int:
	_ensure_sacred()
	if _sacred_memory != null and _sacred_memory.has_method("site_count"):
		return _sacred_memory.site_count()
	return 0

## Get traversal (delegates to RoadMemory if available)
func get_traversal(rx: int, ry: int) -> int:
	_ensure_road()
	if _road_memory != null and _road_memory.has_method("get_traversal"):
		return _road_memory.get_traversal(rx, ry)
	return 0

## Get road T1 constant (delegates to RoadMemory if available)
func get_road_t1() -> int:
	_ensure_road()
	if _road_memory != null and _road_memory.has_method("get_road_t1"):
		return _road_memory.get_road_t1()
	return 0

## Flush dirty tiles (delegates to RoadMemory if available)
func flush_dirty_tiles(world: World) -> void:
	_ensure_road()
	if _road_memory != null and _road_memory.has_method("flush_dirty_tiles"):
		_road_memory.flush_dirty_tiles(world)

## Seed births from current world (delegates to RemnantMemory if available)
func seed_births_from_current_world(world: World) -> void:
	_ensure_remnant()
	if _remnant_memory != null and _remnant_memory.has_method("seed_births_from_current_world"):
		_remnant_memory.seed_births_from_current_world(world)

## Recompute intent (delegates to IntentMemory if available)
func recompute_intent(world: World) -> void:
	_ensure_intent()
	if _intent_memory != null and _intent_memory.has_method("recompute"):
		_intent_memory.recompute(world)

## Get settlement intent (delegates to IntentMemory if available)
func get_settlement_intent() -> Dictionary:
	_ensure_intent()
	if _intent_memory != null and _intent_memory.has_method("get_settlement_intent"):
		return _intent_memory.get_settlement_intent()
	return {}

## Get settlement pressure (delegates to IntentMemory if available)
func get_settlement_pressure() -> Dictionary:
	_ensure_intent()
	if _intent_memory != null and _intent_memory.has_method("get_settlement_pressure"):
		return _intent_memory.get_settlement_pressure()
	return {}

## Clear intent memory (delegates to IntentMemory if available)
func clear_intent_memory() -> void:
	_ensure_intent()
	if _intent_memory != null and _intent_memory.has_method("clear"):
		_intent_memory.clear()

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
	_ensure_footpath()
	if _footpath_memory != null and _footpath_memory.has_method("get_wear_at"):
		return _footpath_memory.get_wear_at(tile)
	return 0.0

func footpath_bind_context(world: Node, pawn_spawner: Node) -> void:
	_ensure_footpath()
	if _footpath_memory != null and _footpath_memory.has_method("bind_context"):
		_footpath_memory.bind_context(world, pawn_spawner)

func footpath_clear() -> void:
	_ensure_footpath()
	if _footpath_memory != null and _footpath_memory.has_method("clear"):
		_footpath_memory.clear()


## Cached world-history export string passthrough.
func get_history_export_string(anonymize_subjects: bool = false) -> String:
	if WorldMemory != null and WorldMemory.has_method("get_history_export_string"):
		return WorldMemory.get_history_export_string(anonymize_subjects)
	return ""


## Chronicle export passthrough for callers that route through MemoryManager.
func export_chronicle(file_path: String) -> bool:
	if WorldMemory != null and WorldMemory.has_method("export_chronicle"):
		return bool(WorldMemory.export_chronicle(file_path))
	return false
