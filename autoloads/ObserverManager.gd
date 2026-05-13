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

var _subsystems_loaded: bool = false

func _ready() -> void:
	print("[ObserverManager] Initialized")

## Load observer subsystems on-demand (not at startup)
func _load_subsystems() -> void:
	if _subsystems_loaded:
		return
	
	# Load observer subsystems as children
	if FileAccess.file_exists("res://scripts/kernel/observer_lens.gd"):
		_observer_lens = load("res://scripts/kernel/observer_lens.gd").new()
		_observer_lens.name = "ObserverLens"
		add_child(_observer_lens)
	
	if FileAccess.file_exists("res://autoloads/SimVision.gd"):
		_sim_vision = load("res://autoloads/SimVision.gd").new()
		_sim_vision.name = "SimVision"
		add_child(_sim_vision)
	
	if FileAccess.file_exists("res://autoloads/ObservationAPI.gd"):
		_observation_api = load("res://autoloads/ObservationAPI.gd").new()
		_observation_api.name = "ObservationAPI"
		add_child(_observation_api)
	
	if FileAccess.file_exists("res://autoloads/DiscoveryGate.gd"):
		_discovery_gate = load("res://autoloads/DiscoveryGate.gd").new()
		_discovery_gate.name = "DiscoveryGate"
		add_child(_discovery_gate)
	
	if FileAccess.file_exists("res://autoloads/FogOfDiscovery.gd"):
		_fog_of_discovery = load("res://autoloads/FogOfDiscovery.gd").new()
		_fog_of_discovery.name = "FogOfDiscovery"
		add_child(_fog_of_discovery)
	
	_subsystems_loaded = true
	print("[ObserverManager] Observer subsystems loaded")

## Get a specific observer subsystem (loads if not already loaded)
func get_subsystem(name: String) -> Node:
	_load_subsystems()
	match name:
		"observer_lens": return _observer_lens
		"sim_vision": return _sim_vision
		"observation_api": return _observation_api
		"discovery_gate": return _discovery_gate
		"fog_of_discovery": return _fog_of_discovery
		_: return null

## Observe region (delegates to ObservationAPI if available)
func observe_region(region_id: int) -> Dictionary:
	if _observation_api == null:
		_load_subsystems()
	if _observation_api != null and _observation_api.has_method("observe_region"):
		return _observation_api.observe_region(region_id)
	return {}

## Update fog of discovery (delegates to FogOfDiscovery if available)
func update_fog(world: World, player_position: Vector2i) -> void:
	if _fog_of_discovery == null:
		_load_subsystems()
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
