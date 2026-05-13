extends Node
## Consolidated Social Manager
## Combines social systems (grudges, gossip, relationships, bloodlines, legacy) into one autoload
## Reduces autoload count while preserving social functionality

# Child nodes for social subsystems (loaded on-demand)
var _kinship_system: Node
var _grudge_manager: Node
var _gossip_manager: Node
var _relational_graph: Node
var _bloodline_system: Node
var _legacy_system: Node

var _subsystems_loaded: bool = false

func _ready() -> void:
	_kinship_system = get_node_or_null("/root/KinshipSystem")
	_grudge_manager = get_node_or_null("/root/GrudgeManager")
	_gossip_manager = get_node_or_null("/root/GossipManager")
	_relational_graph = get_node_or_null("/root/RelationalGraph")
	_bloodline_system = get_node_or_null("/root/BloodlineSystem")
	_legacy_system = get_node_or_null("/root/LegacySystem")
	
	if _kinship_system == null and FileAccess.file_exists("res://autoloads/KinshipSystem.gd"):
		_kinship_system = load("res://autoloads/KinshipSystem.gd").new()
		_kinship_system.name = "KinshipSystem"
		add_child(_kinship_system)
	if _grudge_manager == null and FileAccess.file_exists("res://autoloads/GrudgeManager.gd"):
		_grudge_manager = load("res://autoloads/GrudgeManager.gd").new()
		_grudge_manager.name = "GrudgeManager"
		add_child(_grudge_manager)
	if _gossip_manager == null and FileAccess.file_exists("res://autoloads/GossipManager.gd"):
		_gossip_manager = load("res://autoloads/GossipManager.gd").new()
		_gossip_manager.name = "GossipManager"
		add_child(_gossip_manager)
	if _relational_graph == null and FileAccess.file_exists("res://autoloads/RelationalGraph.gd"):
		_relational_graph = load("res://autoloads/RelationalGraph.gd").new()
		_relational_graph.name = "RelationalGraph"
		add_child(_relational_graph)
	if _bloodline_system == null and FileAccess.file_exists("res://autoloads/BloodlineSystem.gd"):
		_bloodline_system = load("res://autoloads/BloodlineSystem.gd").new()
		_bloodline_system.name = "BloodlineSystem"
		add_child(_bloodline_system)
	if _legacy_system == null and FileAccess.file_exists("res://autoloads/LegacySystem.gd"):
		_legacy_system = load("res://autoloads/LegacySystem.gd").new()
		_legacy_system.name = "LegacySystem"
		add_child(_legacy_system)
	
	_subsystems_loaded = true

## Get a specific social subsystem (loads if not already loaded)
func get_subsystem(name: String) -> Node:
	_load_subsystems()
	match name:
		"kinship_system": return _kinship_system
		"grudge_manager": return _grudge_manager
		"gossip_manager": return _gossip_manager
		"relational_graph": return _relational_graph
		"bloodline_system": return _bloodline_system
		"legacy_system": return _legacy_system
		_: return null

## Record kinship relationship (delegates to KinshipSystem if available)
func record_kinship(pawn_id: int, relative_id: int, relationship_type: String) -> void:
	if _kinship_system == null:
		_load_subsystems()
	if _kinship_system != null and _kinship_system.has_method("record_kinship"):
		_kinship_system.record_kinship(pawn_id, relative_id, relationship_type)

## Record grudge (delegates to GrudgeManager if available)
func record_grudge(pawn_id: int, target_id: int, grudge_type: String, intensity: float) -> void:
	if _grudge_manager == null:
		_load_subsystems()
	if _grudge_manager != null and _grudge_manager.has_method("record_grudge"):
		_grudge_manager.record_grudge(pawn_id, target_id, grudge_type, intensity)

## Spread gossip (delegates to GossipManager if available)
func spread_gossip(source_id: int, target_id: int, gossip_type: String, information: String) -> void:
	if _gossip_manager == null:
		_load_subsystems()
	if _gossip_manager != null and _gossip_manager.has_method("spread_gossip"):
		_gossip_manager.spread_gossip(source_id, target_id, gossip_type, information)

## Add relationship edge (delegates to RelationalGraph if available)
func add_relationship(pawn_id: int, target_id: int, relationship_type: String, strength: float) -> void:
	if _relational_graph == null:
		_load_subsystems()
	if _relational_graph != null and _relational_graph.has_method("add_relationship"):
		_relational_graph.add_relationship(pawn_id, target_id, relationship_type, strength)

## Record bloodline (delegates to BloodlineSystem if available)
func record_bloodline(pawn_id: int, parent_a_id: int, parent_b_id: int, generation: int) -> void:
	if _bloodline_system == null:
		_load_subsystems()
	if _bloodline_system != null and _bloodline_system.has_method("record_bloodline"):
		_bloodline_system.record_bloodline(pawn_id, parent_a_id, parent_b_id, generation)

## Record legacy event (delegates to LegacySystem if available)
func record_legacy(pawn_id: int, legacy_type: String, impact_score: float) -> void:
	if _legacy_system == null:
		_load_subsystems()
	if _legacy_system != null and _legacy_system.has_method("record_legacy"):
		_legacy_system.record_legacy(pawn_id, legacy_type, impact_score)

## Forward getters for subsystems
func get_kinship_system() -> Node:
	return get_subsystem("kinship_system")

func get_grudge_manager() -> Node:
	return get_subsystem("grudge_manager")

func get_gossip_manager() -> Node:
	return get_subsystem("gossip_manager")

func get_relational_graph() -> Node:
	return get_subsystem("relational_graph")

func get_bloodline_system() -> Node:
	return get_subsystem("bloodline_system")

func get_legacy_system() -> Node:
	return get_subsystem("legacy_system")
