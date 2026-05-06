extends Node
## ZoomSystem - EVE/Stronghold-style zoom (1:1 to 1:10000)
##
## Features:
## - Zoom levels: 1:1 to 1:10000
## - LOD (Level of Detail) system
## - Information density per zoom
## - Smooth transitions

# Zoom levels
enum ZoomLevel {
	ZOOM_1_1,      # 1:1 - Individual pawns
	ZOOM_1_100,    # 1:100 - Settlement
	ZOOM_1_1000,   # 1:1000 - Region
	ZOOM_1_10000   # 1:10000 - World
}

# Current zoom state
var current_zoom: ZoomLevel = ZoomLevel.ZOOM_1_1
var zoom_scale: float = 1.0
var target_zoom_scale: float = 1.0

# Zoom configuration
const ZOOM_CONFIG: Dictionary = {
	ZoomLevel.ZOOM_1_1: {
		"scale": 1.0,
		"name": "Pawn View",
		"lod_distance": 0,
		"info_density": "maximum"
	},
	ZoomLevel.ZOOM_1_100: {
		"scale": 0.5,
		"name": "Settlement View",
		"lod_distance": 50,
		"info_density": "high"
	},
	ZoomLevel.ZOOM_1_1000: {
		"scale": 0.2,
		"name": "Region View",
		"lod_distance": 200,
		"info_density": "medium"
	},
	ZoomLevel.ZOOM_1_10000: {
		"scale": 0.05,
		"name": "World View",
		"lod_distance": 1000,
		"info_density": "low"
	}
}

# LOD entity tracking
var lod_entities: Dictionary = {}  # {entity_id: {node: Node, distance: int, visible: bool}}

# Configuration
const ZOOM_TRANSITION_SPEED: float = 0.1
const MAX_ENTITIES_AT_ZOOM: Dictionary = {
	ZoomLevel.ZOOM_1_1: 100,
	ZoomLevel.ZOOM_1_100: 500,
	ZoomLevel.ZOOM_1_1000: 2000,
	ZoomLevel.ZOOM_1_10000: 10000
}

# References
@onready var _camera: Camera2D = null
@onready var _world: Node = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Get camera
	_camera = get_viewport().get_camera_2d()
	if _camera == null:
		_camera = Camera2D.new()
		get_tree().get_root().add_child.call_deferred(_camera)
	
	_world = get_node_or_null("/root/Main/World")


func _process(delta: float) -> void:
	# Smooth zoom transition
	if not is_equal_approx(zoom_scale, target_zoom_scale):
		zoom_scale = lerpf(zoom_scale, target_zoom_scale, ZOOM_TRANSITION_SPEED)
		
		if _camera != null:
			_camera.zoom = Vector2(zoom_scale, zoom_scale)
		
		# Update LOD
		_update_lod()


func _update_lod() -> void:
	# Determine current zoom level
	var new_zoom: ZoomLevel = _get_zoom_level_from_scale()
	
	if new_zoom != current_zoom:
		current_zoom = new_zoom
		_on_zoom_level_changed()
	
	# Update entity visibility based on LOD
	_update_entity_visibility()


func _get_zoom_level_from_scale() -> ZoomLevel:
	if zoom_scale >= 0.8:
		return ZoomLevel.ZOOM_1_1
	elif zoom_scale >= 0.4:
		return ZoomLevel.ZOOM_1_100
	elif zoom_scale >= 0.1:
		return ZoomLevel.ZOOM_1_1000
	else:
		return ZoomLevel.ZOOM_1_10000


func _on_zoom_level_changed() -> void:
	# Adjust rendering based on zoom level
	var config: Dictionary = ZOOM_CONFIG.get(current_zoom, {})
	
	# Update max entities
	var max_entities: int = MAX_ENTITIES_AT_ZOOM.get(current_zoom, 100)
	
	# Notify systems of zoom change
	_notify_zoom_change(current_zoom, config)


func _update_entity_visibility() -> void:
	var config: Dictionary = ZOOM_CONFIG.get(current_zoom, {})
	var lod_distance: int = config.get("lod_distance", 0)
	
	# Update visibility for tracked entities
	for entity_id in lod_entities:
		var entity_data: Dictionary = lod_entities[entity_id]
		var distance: int = entity_data.get("distance", 0)
		
		# Show/hide based on LOD distance
		var should_show: bool = distance <= lod_distance
		if entity_data.visible != should_show:
			entity_data.visible = should_show
			
			if entity_data.has("node") and is_instance_valid(entity_data.node):
				entity_data.node.visible = should_show


# ==================== ZOOM CONTROL ====================

## Set zoom level
func set_zoom_level(level: ZoomLevel) -> void:
	var config: Dictionary = ZOOM_CONFIG.get(level, {})
	target_zoom_scale = config.get("scale", 1.0)


## Zoom in
func zoom_in() -> void:
	var current_config: Dictionary = ZOOM_CONFIG.get(current_zoom, {})
	var current_scale: float = current_config.get("scale", 1.0)
	
	# Find next higher zoom level
	for level in ZOOM_CONFIG:
		var config: Dictionary = ZOOM_CONFIG[level]
		if config.scale > current_scale:
			target_zoom_scale = config.scale
			return


## Zoom out
func zoom_out() -> void:
	var current_config: Dictionary = ZOOM_CONFIG.get(current_zoom, {})
	var current_scale: float = current_config.get("scale", 1.0)
	
	# Find next lower zoom level
	for level in ZOOM_CONFIG:
		var config: Dictionary = ZOOM_CONFIG[level]
		if config.scale < current_scale:
			target_zoom_scale = config.scale
			return


## Set zoom scale directly
func set_zoom_scale(scale: float) -> void:
	target_zoom_scale = clampf(scale, 0.05, 1.0)


## Reset zoom to 1:1
func reset_zoom() -> void:
	set_zoom_level(ZoomLevel.ZOOM_1_1)


# ==================== LOD MANAGEMENT ====================

## Register entity for LOD tracking
func register_lod_entity(entity_id: int, node: Node, distance: int) -> void:
	lod_entities[entity_id] = {
		"node": node,
		"distance": distance,
		"visible": true
	}


## Unregister LOD entity
func unregister_lod_entity(entity_id: int) -> void:
	if lod_entities.has(entity_id):
		lod_entities.erase(entity_id)


## Update entity distance
func update_entity_distance(entity_id: int, distance: int) -> void:
	if lod_entities.has(entity_id):
		lod_entities[entity_id].distance = distance


## Get visible entities at current LOD
func get_visible_entities() -> Array[int]:
	var visible: Array[int] = []
	for entity_id in lod_entities:
		if lod_entities[entity_id].visible:
			visible.append(entity_id)
	return visible


# ==================== INFORMATION DENSITY ====================

## Get information density for current zoom
func get_info_density() -> String:
	var config: Dictionary = ZOOM_CONFIG.get(current_zoom, {})
	return config.get("info_density", "medium")


## Get visible information based on zoom
func get_visible_information(entity_data: Dictionary) -> Dictionary:
	var info: Dictionary = {}
	
	match current_zoom:
		ZoomLevel.ZOOM_1_1:
			# Maximum detail
			info = entity_data.duplicate()
		ZoomLevel.ZOOM_1_100:
			# High detail - basic stats
			info.name = entity_data.get("name", "")
			info.type = entity_data.get("type", "")
			info.status = entity_data.get("status", "")
		ZoomLevel.ZOOM_1_1000:
			# Medium detail - type only
			info.type = entity_data.get("type", "")
			info.count = entity_data.get("count", 1)
		ZoomLevel.ZOOM_1_10000:
			# Low detail - just presence
			info.present = true
	
	return info


# ==================== UTILITY ====================

func _notify_zoom_change(new_zoom: ZoomLevel, config: Dictionary) -> void:
	# Notify other systems of zoom change
	var world_memory: Node = get_node_or_null("/root/WorldMemory")
	if world_memory != null:
		world_memory.record_event({
			"type": "zoom_changed",
			"zoom_level": new_zoom,
			"zoom_name": config.get("name", ""),
			"scale": config.get("scale", 1.0),
			"tick": GameManager.tick_count
		})


## Get current zoom level name
func get_zoom_level_name() -> String:
	var config: Dictionary = ZOOM_CONFIG.get(current_zoom, {})
	return config.get("name", "Unknown")


## Get zoom scale for a level
func get_scale_for_level(level: ZoomLevel) -> float:
	var config: Dictionary = ZOOM_CONFIG.get(level, {})
	return config.get("scale", 1.0)


## Check if zoom transition is complete
func is_zoom_transition_complete() -> bool:
	return is_equal_approx(zoom_scale, target_zoom_scale)


# ==================== PUBLIC API ====================

## Get current zoom level
func get_current_zoom() -> ZoomLevel:
	return current_zoom

## Get current zoom scale
func get_current_scale() -> float:
	return zoom_scale

## Get all zoom levels
func get_all_zoom_levels() -> Array:
	return ZOOM_CONFIG.keys()

## Get zoom config for a level
func get_zoom_config(level: ZoomLevel) -> Dictionary:
	return ZOOM_CONFIG.get(level, {}).duplicate()

## Clear LOD tracking
func clear_lod() -> void:
	lod_entities.clear()

## Get statistics
func get_stats() -> Dictionary:
	var visible_count: int = 0
	var hidden_count: int = 0
	
	for entity_id in lod_entities:
		if lod_entities[entity_id].visible:
			visible_count += 1
		else:
			hidden_count += 1
	
	return {
		"current_zoom": current_zoom,
		"zoom_name": get_zoom_level_name(),
		"zoom_scale": zoom_scale,
		"target_scale": target_zoom_scale,
		"transition_complete": is_zoom_transition_complete(),
		"visible_entities": visible_count,
		"hidden_entities": hidden_count,
		"total_tracked": lod_entities.size()
	}
