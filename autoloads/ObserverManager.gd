extends Node
## Consolidated Observer Manager
## Combines observer and vision systems into one autoload
## Reduces autoload count while preserving observer functionality

# Child nodes for observer subsystems (loaded on-demand)
var _observer_lens: Node
var _sim_vision: Node
var _observation_api: Node
var _discovery_gate: Node
var _fog_of_discovery: Node

var _observer_lens_loaded: bool = false
var _sim_vision_loaded: bool = false
var _observation_api_loaded: bool = false
var _discovery_gate_loaded: bool = false
var _fog_of_discovery_loaded: bool = false

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

func _ensure_observer_lens() -> void:
	if not _observer_lens_loaded:
		_observer_lens = _load_sub("ObserverLens", "res://scripts/kernel/observer_lens.gd")
		_observer_lens_loaded = true

func _ensure_sim_vision() -> void:
	if not _sim_vision_loaded:
		_sim_vision = _load_sub("SimVision", "res://autoloads/SimVision.gd")
		_sim_vision_loaded = true

func _ensure_observation_api() -> void:
	if not _observation_api_loaded:
		_observation_api = _load_sub("ObservationAPI", "res://autoloads/ObservationAPI.gd")
		_observation_api_loaded = true

func _ensure_discovery_gate() -> void:
	if not _discovery_gate_loaded:
		_discovery_gate = _load_sub("DiscoveryGate", "res://autoloads/DiscoveryGate.gd")
		_discovery_gate_loaded = true

func _ensure_fog_of_discovery() -> void:
	if not _fog_of_discovery_loaded:
		_fog_of_discovery = _load_sub("FogOfDiscovery", "res://autoloads/FogOfDiscovery.gd")
		_fog_of_discovery_loaded = true

## Get a specific observer subsystem (loads if not already loaded)
func get_subsystem(name: String) -> Node:
	match name:
		"observer_lens": _ensure_observer_lens(); return _observer_lens
		"sim_vision": _ensure_sim_vision(); return _sim_vision
		"observation_api": _ensure_observation_api(); return _observation_api
		"discovery_gate": _ensure_discovery_gate(); return _discovery_gate
		"fog_of_discovery": _ensure_fog_of_discovery(); return _fog_of_discovery
		_: return null

## Observe region (delegates to ObservationAPI if available)
func observe_region(region_id: int) -> Dictionary:
	_ensure_observation_api()
	if _observation_api != null and _observation_api.has_method("observe_region"):
		return _observation_api.observe_region(region_id)
	return {}

## Update fog of discovery (delegates to FogOfDiscovery if available)
func update_fog(world: World, player_position: Vector2i) -> void:
	_ensure_fog_of_discovery()
	if _fog_of_discovery != null and _fog_of_discovery.has_method("update"):
		_fog_of_discovery.update(world, player_position)

## Forward getters for subsystems
func get_observer_lens() -> Node:
	return get_subsystem("observer_lens")

func get_sim_vision() -> Node:
	return get_subsystem("sim_vision")

func get_observation_api() -> Node:
	return get_subsystem("observation_api")

func get_discovery_gate() -> Node:
	return get_subsystem("discovery_gate")

func get_fog_of_discovery() -> Node:
	return get_subsystem("fog_of_discovery")
