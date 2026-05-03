extends Node
## Phase 4: Player-readable meaning refinement — audio/visual interpolation layer.
## Listens to WorldMeaning state changes and crossfades ambiance, color grade,
## and particle density. Deterministic; uses WorldRNG for labeled variation only.
##
## Wires to:
## - WorldMeaning.recompute() via signal or poll-on-meaning-change
## - Pawn behavior via global meaning_label accessor
## - SettlementPlanner via memorial spawn hooks

const MEANING_TRANSITION_TICKS_AUDIO: int = 30   # 3 seconds at 10 ticks/sec
const MEANING_TRANSITION_TICKS_VISUAL: int = 60  # 6 seconds

## Current meaning label per region (region_key -> "quiet"/"scarred"/"bloodied"/"grave")
var _meaning_by_region: Dictionary = {}

## Transition state: region_key -> {from_label, to_label, progress_audio, progress_visual}
var _transitions: Dictionary = {}

## Audio bus indices (cached)
var _bus_ambience: int = -1
var _bus_master: int = -1

## Cached WorldEnvironment reference
var _world_env: WorldEnvironment = null

## Particle system reference (if using GPUParticles2D/3D for ambient effects)
var _ambient_particles: Node = null


func _ready() -> void:
	_bus_ambience = AudioServer.get_bus_index("Ambience")
	if _bus_ambience == -1:
		_bus_ambience = AudioServer.get_bus_index("Master")  # fallback
	_bus_master = AudioServer.get_bus_index("Master")
	
	# Find WorldEnvironment in current scene
	if Engine.has_singleton("WorldEnvironment"):
		_world_env = Engine.get_singleton("WorldEnvironment")
	else:
		# Try to find in tree
		await get_tree().process_frame
		var candidates := get_tree().get_nodes_in_group("world_environment")
		if not candidates.is_empty():
			_world_env = candidates[0] as WorldEnvironment
	
	# Connect to WorldMeaning recompute (if signal exists)
	if WorldMeaning.has_signal("meaning_changed"):
		WorldMeaning.connect("meaning_changed", _on_world_meaning_changed)
	
	# Initialize meaning snapshot
	_update_meaning_snapshot()


func _process(_delta: float) -> void:
	# Process active transitions
	for rk in _transitions.keys():
		var ts: Dictionary = _transitions[rk]
		ts["progress_audio"] = min(1.0, ts["progress_audio"] + (1.0 / float(MEANING_TRANSITION_TICKS_AUDIO)))
		ts["progress_visual"] = min(1.0, ts["progress_visual"] + (1.0 / float(MEANING_TRANSITION_TICKS_VISUAL)))
		
		if ts["progress_audio"] >= 1.0 and ts["progress_visual"] >= 1.0:
			_transitions.erase(rk)
			_meaning_by_region[rk] = ts["to_label"]


var _last_tick: int = -1000

func _tick() -> void:
	# Called by GameManager or Main on tick; poll for meaning changes
	# Throttle: meaning labels change slowly, no need to check every tick
	if GameManager != null:
		var now: int = GameManager.tick_count
		if now - _last_tick < 20:
			return
		_last_tick = now
	_update_meaning_snapshot()


func _update_meaning_snapshot() -> void:
	# Iterate all known regions from WorldMemory
	if not WorldMemory or not WorldMemory.has_method("get_all_region_keys"):
		return
	
	var region_keys: PackedInt32Array = WorldMemory.get_all_region_keys()
	for rk in region_keys:
		var current_label: String = WorldMeaning.get_region_meaning_label(rk)
		var stored_label: String = str(_meaning_by_region.get(rk, ""))
		
		if current_label != stored_label and not stored_label.is_empty():
			# State changed; start transition
			_start_transition(rk, stored_label, current_label)
		elif stored_label.is_empty():
			# First initialization; no transition needed
			_meaning_by_region[rk] = current_label


func _start_transition(region_key: int, from_label: String, to_label: String) -> void:
	_transitions[region_key] = {
		"from_label": from_label,
		"to_label": to_label,
		"progress_audio": 0.0,
		"progress_visual": 0.0,
	}
	
	# Trigger immediate behavior update for pawns in this region
	_notify_pawns_of_meaning_change(region_key, to_label)
	
	# Trigger settlement restructuring hook
	_notify_settlement_planner_of_meaning_change(region_key, to_label)


func _notify_pawns_of_meaning_change(_region_key: int, _new_label: String) -> void:
	# Placeholder: broadcast to Pawn instances via signal or direct call
	# Implementation in Pawn.gd will poll MeaningAmbianceController.get_region_label()
	pass


func _notify_settlement_planner_of_meaning_change(region_key: int, new_label: String) -> void:
	# Hook for SettlementPlanner to spawn memorials or adjust posture
	if not has_node("/root/SettlementPlanner"):
		return
	var sp: Node = get_node("/root/SettlementPlanner")
	if sp.has_method("on_meaning_label_changed"):
		sp.call("on_meaning_label_changed", region_key, new_label)


## Get interpolated audio volume for a region (0.0-1.0 scale)
func get_ambient_volume_for_region(region_key: int) -> float:
	if not _transitions.has(region_key):
		return _get_base_volume_for_label(str(_meaning_by_region.get(region_key, "quiet")))
	
	var ts: Dictionary = _transitions[region_key]
	var from_vol: float = _get_base_volume_for_label(ts["from_label"])
	var to_vol: float = _get_base_volume_for_label(ts["to_label"])
	return lerp(from_vol, to_vol, ts["progress_audio"])


## Get base volume multiplier for a meaning label
func _get_base_volume_for_label(label: String) -> float:
	match label:
		"quiet": return 0.8
		"scarred": return 0.6
		"bloodied": return 0.4
		"grave": return 0.2
	return 0.8


## Get pitch scale range for pawn vocalizations in a region
func get_vocal_pitch_range_for_region(region_key: int) -> Array:
	var label: String = str(_meaning_by_region.get(region_key, "quiet"))
	match label:
		"quiet": return [0.95, 1.05]
		"scarred": return [0.88, 0.95]
		"bloodied": return [0.82, 0.90]
		"grave": return [0.75, 0.85]  # mostly silent anyway
	return [0.95, 1.05]


## Get movement speed multiplier for pawns in a region
func get_movement_speed_multiplier_for_region(region_key: int) -> float:
	var label: String = str(_meaning_by_region.get(region_key, "quiet"))
	match label:
		"quiet": return 1.0
		"scarred": return 0.9
		"bloodied": return 0.8
		"grave": return 0.7
	return 1.0


## Get clustering radius for pawns in a region (pixels)
func get_clustering_radius_for_region(region_key: int) -> float:
	var label: String = str(_meaning_by_region.get(region_key, "quiet"))
	match label:
		"quiet": return 128.0
		"scarred": return 96.0
		"bloodied": return 64.0
		"grave": return 48.0
	return 128.0


## Get wander bias for pawns in a region (0.0-1.0, higher = more wandering)
func get_wander_bias_for_region(region_key: int) -> float:
	var label: String = str(_meaning_by_region.get(region_key, "quiet"))
	match label:
		"quiet": return 0.5
		"scarred": return 0.3
		"bloodied": return 0.2
		"grave": return 0.1
	return 0.5


## Get max cluster size for job gathering in a region
func get_max_cluster_size_for_region(region_key: int) -> int:
	var label: String = str(_meaning_by_region.get(region_key, "quiet"))
	match label:
		"quiet": return 4
		"scarred": return 5
		"bloodied": return 6
		"grave": return 2
	return 4


## Get particle density multiplier (for WorldEnvironment or custom particles)
func get_particle_density_multiplier_for_region(region_key: int) -> float:
	var label: String = str(_meaning_by_region.get(region_key, "quiet"))
	match label:
		"quiet": return 0.3
		"scarred": return 0.6
		"bloodied": return 0.9
		"grave": return 1.2
	return 0.3


## Get saturation boost factor (1.0 = neutral, >1 = more saturated)
func get_saturation_boost_for_region(region_key: int) -> float:
	var label: String = str(_meaning_by_region.get(region_key, "quiet"))
	match label:
		"quiet": return 1.05
		"scarred": return 0.9
		"bloodied": return 0.85
		"grave": return 0.75
	return 1.0


## Get brightness boost factor (1.0 = neutral)
func get_brightness_boost_for_region(region_key: int) -> float:
	var label: String = str(_meaning_by_region.get(region_key, "quiet"))
	match label:
		"quiet": return 1.03
		"scarred": return 1.0
		"bloodied": return 0.95
		"grave": return 0.9
	return 1.0


## Get color temperature in Kelvin (5500K = warm daylight, 7000K = cool twilight)
func get_color_temperature_for_region(region_key: int) -> float:
	var label: String = str(_meaning_by_region.get(region_key, "quiet"))
	match label:
		"quiet": return 5500.0
		"scarred": return 6000.0
		"bloodied": return 6500.0
		"grave": return 7000.0
	return 5500.0


## Get vocalization skip chance (0.0 = always vocalize, 1.0 = never)
func get_vocal_skip_chance_for_region(region_key: int) -> float:
	var label: String = str(_meaning_by_region.get(region_key, "quiet"))
	match label:
		"quiet": return 0.0
		"scarred": return 0.2
		"bloodied": return 0.5
		"grave": return 1.0  # complete silence
	return 0.0


## Get idle animation modifier ("normal", "alert", "mournful")
func get_idle_animation_modifier_for_region(region_key: int) -> String:
	var label: String = str(_meaning_by_region.get(region_key, "quiet"))
	match label:
		"quiet": return "normal"
		"scarred": return "alert"
		"bloodied": return "alert"
		"grave": return "mournful"
	return "normal"


## Check if memorial spawning is appropriate for this meaning state
func should_spawn_memorial_for_label(label: String) -> bool:
	return label in ["scarred", "bloodied", "grave"]


## Get memorial type for meaning label ("marker", "cairn", "grave_field")
func get_memorial_type_for_label(label: String) -> String:
	match label:
		"scarred": return "marker"
		"bloodied": return "cairn"
		"grave": return "grave_field"
	return "marker"


func _on_world_meaning_changed() -> void:
	_update_meaning_snapshot()


## Debug: force a meaning label for testing
func debug_force_meaning_label(region_key: int, label: String) -> void:
	var old_label: String = str(_meaning_by_region.get(region_key, "quiet"))
	_start_transition(region_key, old_label, label)
