extends Node
## Consolidated Social Manager
## Lazy-loads subsystems on first access — no startup stutter.

var _kinship_system: Node
var _grudge_manager: Node
var _gossip_manager: Node
var _relational_graph: Node
var _bloodline_system: Node
var _legacy_system: Node

var _kinship_loaded: bool = false
var _grudge_loaded: bool = false
var _gossip_loaded: bool = false
var _relational_loaded: bool = false
var _bloodline_loaded: bool = false
var _legacy_loaded: bool = false

func _ready() -> void:
	pass

func _load_subsystem(sub: String, var_name: String, path: String) -> Node:
	var existing: Node = get_node_or_null("/root/" + sub)
	if existing != null:
		return existing
	if FileAccess.file_exists(path):
		var loaded: Node = load(path).new()
		loaded.name = sub
		add_child(loaded)
		return loaded
	return null

func _ensure_grudge() -> void:
	if not _grudge_loaded:
		_grudge_manager = _load_subsystem("GrudgeManager", "_grudge_manager", "res://autoloads/GrudgeManager.gd")
		_grudge_loaded = true

func _ensure_gossip() -> void:
	if not _gossip_loaded:
		_gossip_manager = _load_subsystem("GossipManager", "_gossip_manager", "res://autoloads/GossipManager.gd")
		_gossip_loaded = true

func _ensure_kinship() -> void:
	if not _kinship_loaded:
		_kinship_system = _load_subsystem("KinshipSystem", "_kinship_system", "res://autoloads/KinshipSystem.gd")
		_kinship_loaded = true

func _ensure_relational() -> void:
	if not _relational_loaded:
		_relational_graph = _load_subsystem("RelationalGraph", "_relational_graph", "res://autoloads/RelationalGraph.gd")
		_relational_loaded = true

func _ensure_bloodline() -> void:
	if not _bloodline_loaded:
		_bloodline_system = _load_subsystem("BloodlineSystem", "_bloodline_system", "res://autoloads/BloodlineSystem.gd")
		_bloodline_loaded = true

func _ensure_legacy() -> void:
	if not _legacy_loaded:
		_legacy_system = _load_subsystem("LegacySystem", "_legacy_system", "res://autoloads/LegacySystem.gd")
		_legacy_loaded = true

func get_subsystem(name: String) -> Node:
	match name:
		"kinship_system": _ensure_kinship(); return _kinship_system
		"grudge_manager": _ensure_grudge(); return _grudge_manager
		"gossip_manager": _ensure_gossip(); return _gossip_manager
		"relational_graph": _ensure_relational(); return _relational_graph
		"bloodline_system": _ensure_bloodline(); return _bloodline_system
		"legacy_system": _ensure_legacy(); return _legacy_system
		_: return null

## Record kinship relationship (delegates to KinshipSystem if available)
func record_kinship(pawn_id: int, relative_id: int, relationship_type: String) -> void:
	_ensure_kinship()
	if _kinship_system != null and _kinship_system.has_method("record_kinship"):
		_kinship_system.record_kinship(pawn_id, relative_id, relationship_type)

## Record grudge (delegates to GrudgeManager if available)
func record_grudge(pawn_id: int, target_id: int, grudge_type: String, intensity: float) -> void:
	_ensure_grudge()
	if _grudge_manager != null and _grudge_manager.has_method("record_grudge"):
		_grudge_manager.record_grudge(pawn_id, target_id, grudge_type, intensity)

## Spread gossip (delegates to GossipManager if available)
func spread_gossip(source_id: int, target_id: int, gossip_type: String, information: String) -> void:
	_ensure_gossip()
	if _gossip_manager != null and _gossip_manager.has_method("spread_gossip"):
		_gossip_manager.spread_gossip(source_id, target_id, gossip_type, information)

## Add relationship edge (delegates to RelationalGraph if available)
func add_relationship(pawn_id: int, target_id: int, relationship_type: String, strength: float) -> void:
	_ensure_relational()
	if _relational_graph != null and _relational_graph.has_method("add_relationship"):
		_relational_graph.add_relationship(pawn_id, target_id, relationship_type, strength)

## Record bloodline (delegates to BloodlineSystem if available)
func record_bloodline(pawn_id: int, parent_a_id: int, parent_b_id: int, generation: int) -> void:
	_ensure_bloodline()
	if _bloodline_system != null and _bloodline_system.has_method("record_bloodline"):
		_bloodline_system.record_bloodline(pawn_id, parent_a_id, parent_b_id, generation)

## Record legacy event (delegates to LegacySystem if available)
func record_legacy(pawn_id: int, legacy_type: String, impact_score: float) -> void:
	_ensure_legacy()
	if _legacy_system != null and _legacy_system.has_method("record_legacy"):
		_legacy_system.record_legacy(pawn_id, legacy_type, impact_score)

## Forward getters for subsystems
func get_kinship_system() -> Node:
	_ensure_kinship()
	return _kinship_system

func get_grudge_manager() -> Node:
	_ensure_grudge()
	return _grudge_manager

func get_gossip_manager() -> Node:
	_ensure_gossip()
	return _gossip_manager

func get_relational_graph() -> Node:
	_ensure_relational()
	return _relational_graph

func get_bloodline_system() -> Node:
	_ensure_bloodline()
	return _bloodline_system

func get_legacy_system() -> Node:
	_ensure_legacy()
	return _legacy_system

## Record pawn death in bloodline system (delegates to BloodlineSystem if available)
func record_pawn_death(pawn_id: int) -> void:
	_ensure_bloodline()
	if _bloodline_system != null and _bloodline_system.has_method("record_pawn_death"):
		_bloodline_system.record_pawn_death(pawn_id)

## Clear bloodline system (delegates to BloodlineSystem if available)
func clear_bloodline() -> void:
	_ensure_bloodline()
	if _bloodline_system != null and _bloodline_system.has_method("clear"):
		_bloodline_system.clear()

## Get all grudges held by a pawn (delegates to GrudgeManager)
func get_grudges_held_by(pawn_id: int) -> Array:
	_ensure_grudge()
	if _grudge_manager != null and _grudge_manager.has_method("get_grudges_held_by"):
		return _grudge_manager.get_grudges_held_by(pawn_id)
	return []

## Get all grudges against a pawn (delegates to GrudgeManager)
func get_grudges_against(pawn_id: int) -> Array:
	_ensure_grudge()
	if _grudge_manager != null and _grudge_manager.has_method("get_grudges_against"):
		return _grudge_manager.get_grudges_against(pawn_id)
	return []

## Get grudge target for a crime (delegates to GrudgeManager)
func get_grudge_target(pawn_id: int) -> int:
	_ensure_grudge()
	if _grudge_manager != null and _grudge_manager.has_method("get_grudge_target"):
		return _grudge_manager.get_grudge_target(pawn_id)
	return -1

## Get highest grudge level (delegates to GrudgeManager)
func get_highest_grudge_level(pawn_id: int) -> float:
	_ensure_grudge()
	if _grudge_manager != null and _grudge_manager.has_method("get_highest_grudge_level"):
		return _grudge_manager.get_highest_grudge_level(pawn_id)
	return 0.0

## Serialize grudges for save (delegates to GrudgeManager)
func grudges_to_save_dict() -> Dictionary:
	_ensure_grudge()
	if _grudge_manager != null and _grudge_manager.has_method("to_save_dict"):
		return _grudge_manager.to_save_dict()
	return {}

## Deserialize grudges from save (delegates to GrudgeManager)
func grudges_from_save_dict(data: Dictionary) -> void:
	_ensure_grudge()
	if _grudge_manager != null and _grudge_manager.has_method("from_save_dict"):
		_grudge_manager.from_save_dict(data)

## Get gossip about a pawn (delegates to GossipManager)
func get_gossip_about(pawn_id: int) -> Array:
	_ensure_gossip()
	if _gossip_manager != null and _gossip_manager.has_method("get_gossip_about"):
		return _gossip_manager.get_gossip_about(pawn_id)
	return []

## Get reputation for a pawn (delegates to GossipManager)
func get_reputation_for(pawn_id: int) -> float:
	_ensure_gossip()
	if _gossip_manager != null and _gossip_manager.has_method("get_reputation_for"):
		return _gossip_manager.get_reputation_for(pawn_id)
	return 0.0

## Get reputation label for a pawn (delegates to GossipManager)
func get_reputation_label(pawn_id: int) -> String:
	_ensure_gossip()
	if _gossip_manager != null and _gossip_manager.has_method("get_reputation_label"):
		return _gossip_manager.get_reputation_label(pawn_id)
	return "Unknown"

## Serialize gossip for save (delegates to GossipManager)
func gossip_to_save_dict() -> Dictionary:
	_ensure_gossip()
	if _gossip_manager != null and _gossip_manager.has_method("to_save_dict"):
		return _gossip_manager.to_save_dict()
	return {}

## Deserialize gossip from save (delegates to GossipManager)
func gossip_from_save_dict(data: Dictionary) -> void:
	_ensure_gossip()
	if _gossip_manager != null and _gossip_manager.has_method("from_save_dict"):
		_gossip_manager.from_save_dict(data)
