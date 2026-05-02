extends Node
## HEELKAWN Persistence Rules - Persistence must be earned by impact, repetition, witness, teaching, and material survival.
## Tracks what survives over time: ruins, graves, scars, roads, customs, names, bloodlines.

# Autoload references
@onready var WorldAI = get_node_or_null("/root/WorldAI")
@onready var WorldMemory = get_node_or_null("/root/WorldMemory")
@onready var GameManager = get_node_or_null("/root/GameManager")

enum EntityType {
	RUIN = 0,
	GRAVE_FIELD = 1,
	SETTLEMENT_SCAR = 2,
	ROAD = 3,
	DESIRE_PATH = 4,
	BOUNDARY_STONE = 5,
	SACRED_HEARTH = 6,
	DEPLETED_FOREST = 7,
	POLLUTED_LAND = 8,
	IRRIGATION_TRACE = 9,
	ABANDONED_STORAGE = 10,
	BATTLE_SITE = 11,
	CULTURAL_CUSTOM = 12,
	REMEMBERED_NAME = 13,
	PROTECTED_BLOODLINE = 14,
	SACRED_SITE = 15,
	PRACTICAL_SITE = 16
}

const PERSISTENCE_DECAY_INTERVAL_TICKS: int = 2000
const PERSISTENCE_DECAY_PHASE_OFFSET_TICKS: int = 311
const LOST_ENTITY_INTERVAL_TICKS: int = 5000
const LOST_ENTITY_PHASE_OFFSET_TICKS: int = 743

## Persistent entities: entity_id -> entity data
var persistent_entities: Dictionary = {}

## Persistence scores: entity_id -> persistence score (0.0-1.0)
var persistence_scores: Dictionary = {}

## Next entity ID
var _next_entity_id: int = 1

func _ready() -> void:
	GameManager.game_tick.connect(_on_game_tick)

func _on_game_tick(tick: int) -> void:
	if GameManager.periodic_phase_due(tick, PERSISTENCE_DECAY_INTERVAL_TICKS, PERSISTENCE_DECAY_PHASE_OFFSET_TICKS):
		_apply_persistence_decay()
	if GameManager.periodic_phase_due(tick, LOST_ENTITY_INTERVAL_TICKS, LOST_ENTITY_PHASE_OFFSET_TICKS):
		_remove_lost_entities()

# === Entity Creation ===

func create_persistent_entity(
	entity_type: EntityType,
	location: Vector2i,
	name: String = "",
	initial_impact: float = 0.5
) -> int:
	var entity_id: int = _next_entity_id
	_next_entity_id += 1
	
	var entity_data: Dictionary = {
		"id": entity_id,
		"type": entity_type,
		"location": location,
		"name": name,
		"created_tick": GameManager.tick_count,
		"last_visited_tick": GameManager.tick_count,
		"visit_count": 0,
		"use_count": 0,
		"witness_count": 0,
		"teaching_count": 0,
		"material_condition": 1.0
	}
	
	persistent_entities[entity_id] = entity_data
	persistence_scores[entity_id] = initial_impact
	
	_record_entity_creation(entity_id, entity_type, location, name)
	return entity_id

# === Persistence Scoring ===

func calculate_persistence_score(entity_id: int) -> float:
	if not persistent_entities.has(entity_id):
		return 0.0
	
	var entity: Dictionary = persistent_entities[entity_id]
	var material_condition: float = entity["material_condition"]
	
	# Impact: how significant the entity was
	var impact_score: float = persistence_scores.get(entity_id, 0.5)
	
	# Repetition: how often it was used/visited
	var visit_count: int = entity["visit_count"]
	var use_count: int = entity["use_count"]
	var repetition_score: float = min((visit_count + use_count * 2) / 100.0, 1.0)
	
	# Witness: how many people saw it
	var witness_count: int = entity["witness_count"]
	var witness_score: float = min(witness_count / 50.0, 1.0)
	
	# Teaching: how many were taught about it
	var teaching_count: int = entity["teaching_count"]
	var teaching_score: float = min(teaching_count / 20.0, 1.0)
	
	# Material survival: physical condition
	var material_score: float = material_condition
	
	# Weighted average
	var final_score: float = (
		impact_score * 0.3 +
		repetition_score * 0.25 +
		witness_score * 0.2 +
		teaching_score * 0.15 +
		material_score * 0.1
	)
	
	return clamp(final_score, 0.0, 1.0)

func update_persistence_score(entity_id: int) -> void:
	var new_score: float = calculate_persistence_score(entity_id)
	persistence_scores[entity_id] = new_score

# === Persistence Actions ===

func record_visitation(entity_id: int, visitor_id: int) -> void:
	if not persistent_entities.has(entity_id):
		return
	
	var entity: Dictionary = persistent_entities[entity_id]
	entity["visit_count"] += 1
	entity["last_visited_tick"] = GameManager.tick_count
	entity["witness_count"] += 1
	
	update_persistence_score(entity_id)
	_record_visitation(entity_id, visitor_id)

func record_use(entity_id: int, user_id: int) -> void:
	if not persistent_entities.has(entity_id):
		return
	
	var entity: Dictionary = persistent_entities[entity_id]
	entity["use_count"] += 1
	entity["last_visited_tick"] = GameManager.tick_count
	entity["witness_count"] += 1
	
	update_persistence_score(entity_id)
	_record_use(entity_id, user_id)

func record_teaching(entity_id: int, teacher_id: int, student_id: int) -> void:
	if not persistent_entities.has(entity_id):
		return
	
	var entity: Dictionary = persistent_entities[entity_id]
	entity["teaching_count"] += 1
	entity["witness_count"] += 2  # Teacher and student
	
	update_persistence_score(entity_id)
	_record_teaching(entity_id, teacher_id, student_id)

func record_material_damage(entity_id: int, damage: float) -> void:
	if not persistent_entities.has(entity_id):
		return
	
	var entity: Dictionary = persistent_entities[entity_id]
	entity["material_condition"] = max(entity["material_condition"] - damage, 0.0)
	
	update_persistence_score(entity_id)
	_record_material_damage(entity_id, damage)

func record_material_repair(entity_id: int, repair: float) -> void:
	if not persistent_entities.has(entity_id):
		return
	
	var entity: Dictionary = persistent_entities[entity_id]
	entity["material_condition"] = min(entity["material_condition"] + repair, 1.0)
	
	update_persistence_score(entity_id)
	_record_material_repair(entity_id, repair)

# === Persistence Decay ===

func _apply_persistence_decay() -> void:
	var current_tick: int = GameManager.tick_count
	
	for entity_id in persistent_entities:
		var entity: Dictionary = persistent_entities[entity_id]
		var last_visit: int = entity["last_visited_tick"]
		var time_since_visit: int = current_tick - last_visit
		
		# Decay based on time since last interaction
		var decay_rate: float = 0.0
		if time_since_visit > 50000:
			decay_rate = 0.05
		elif time_since_visit > 20000:
			decay_rate = 0.02
		elif time_since_visit > 10000:
			decay_rate = 0.01
		
		# Material condition decays faster
		var old_condition = entity["material_condition"]
		entity["material_condition"] = max(entity["material_condition"] - decay_rate * 0.5, 0.0)
		
		# Notify WorldAI of significant decay
		if old_condition > 0.5 and entity["material_condition"] <= 0.5:
			_notify_world_ai_entity_decay(entity_id, entity["type"], entity["material_condition"])
		
		# Witness count decays slowly (people forget)
		if time_since_visit > 30000:
			entity["witness_count"] = max(entity["witness_count"] - 1, 0)
		
		update_persistence_score(entity_id)

func _remove_lost_entities() -> void:
	var lost_entities: Array[int] = []
	
	for entity_id in persistence_scores:
		var score: float = persistence_scores[entity_id]
		var entity: Dictionary = persistent_entities[entity_id]
		
		# Remove if score is too low or material condition is zero
		if score < 0.1 or entity["material_condition"] <= 0.0:
			lost_entities.append(entity_id)
	
	for entity_id in lost_entities:
		var entity = persistent_entities.get(entity_id, {})
		_record_entity_loss(entity_id, persistence_scores[entity_id])
		_notify_world_ai_entity_loss(entity_id, entity.get("type", -1))
		persistent_entities.erase(entity_id)
		persistence_scores.erase(entity_id)

# === Helper Functions ===

func get_entity_at_location(location: Vector2i, entity_type: EntityType = -1) -> int:
	for entity_id in persistent_entities:
		var entity: Dictionary = persistent_entities[entity_id]
		if entity["location"] == location:
			if entity_type == -1 or entity["type"] == entity_type:
				return entity_id
	return -1

func get_entities_by_type(entity_type: EntityType) -> Array[int]:
	var found: Array[int] = []
	for entity_id in persistent_entities:
		if persistent_entities[entity_id]["type"] == entity_type:
			found.append(entity_id)
	return found

func get_entities_in_region(region_key: int) -> Array[int]:
	var found: Array[int] = []
	for entity_id in persistent_entities:
		var location: Vector2i = persistent_entities[entity_id]["location"]
		var entity_region: int = WorldMemory._region_key(location.x, location.y)
		if entity_region == region_key:
			found.append(entity_id)
	return found

# === Event Recording ===

func _record_entity_creation(entity_id: int, entity_type: EntityType, location: Vector2i, name: String) -> void:
	var event: Dictionary = {
		"type": "entity_creation",
		"entity_id": entity_id,
		"entity_type": entity_type,
		"location": location,
		"name": name,
		"tick": GameManager.tick_count
	}
	WorldMemory.record_event(event)

func _record_visitation(entity_id: int, visitor_id: int) -> void:
	var event: Dictionary = {
		"type": "entity_visitation",
		"entity_id": entity_id,
		"visitor_id": visitor_id,
		"tick": GameManager.tick_count
	}
	WorldMemory.record_event(event)

func _record_use(entity_id: int, user_id: int) -> void:
	var event: Dictionary = {
		"type": "entity_use",
		"entity_id": entity_id,
		"user_id": user_id,
		"tick": GameManager.tick_count
	}
	WorldMemory.record_event(event)

func _record_teaching(entity_id: int, teacher_id: int, student_id: int) -> void:
	var event: Dictionary = {
		"type": "entity_teaching",
		"entity_id": entity_id,
		"teacher_id": teacher_id,
		"student_id": student_id,
		"tick": GameManager.tick_count
	}
	WorldMemory.record_event(event)

func _record_material_damage(entity_id: int, damage: float) -> void:
	var event: Dictionary = {
		"type": "entity_damage",
		"entity_id": entity_id,
		"damage": damage,
		"tick": GameManager.tick_count
	}
	WorldMemory.record_event(event)

func _record_material_repair(entity_id: int, repair: float) -> void:
	var event: Dictionary = {
		"type": "entity_repair",
		"entity_id": entity_id,
		"repair": repair,
		"tick": GameManager.tick_count
	}
	WorldMemory.record_event(event)


# === Public Query Functions ===

func get_entity_count() -> int:
	return persistent_entities.size()

func get_entity_count_by_type(entity_type: EntityType) -> int:
	var count: int = 0
	for entity_id in persistent_entities:
		var entity: Dictionary = persistent_entities[entity_id]
		if entity.get("entity_type") == entity_type:
			count += 1
	return count

func _notify_world_ai_entity_decay(entity_id: int, entity_type: int, condition: float) -> void:
	# Notify WorldAI of entity decay to update neural network
	if WorldAI != null and WorldAI.has_method("on_entity_decay"):
		WorldAI.on_entity_decay(entity_id, entity_type, condition)

func _notify_world_ai_entity_loss(entity_id: int, entity_type: int) -> void:
	# Notify WorldAI of entity loss to update neural network
	if WorldAI != null and WorldAI.has_method("on_entity_loss"):
		WorldAI.on_entity_loss(entity_id, entity_type)

func _record_entity_loss(entity_id: int, final_score: float) -> void:
	var event: Dictionary = {
		"type": "entity_loss",
		"entity_id": entity_id,
		"final_score": final_score,
		"tick": GameManager.tick_count
	}
	WorldMemory.record_event(event)

# === Public Interface ===

func get_persistence_score(entity_id: int) -> float:
	return persistence_scores.get(entity_id, 0.0)

func get_entity_data(entity_id: int) -> Dictionary:
	if persistent_entities.has(entity_id):
		return persistent_entities[entity_id].duplicate(true)
	return {}

func get_persistence_status() -> Dictionary:
	var status: Dictionary = {}
	
	for entity_id in persistent_entities:
		status[entity_id] = {
			"data": persistent_entities[entity_id],
			"score": persistence_scores[entity_id]
		}
	
	return status

func clear() -> void:
	persistent_entities.clear()
	persistence_scores.clear()
	_next_entity_id = 1
