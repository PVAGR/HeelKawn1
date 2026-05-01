extends Node
## HEELKAWN Knowledge System - Knowledge only exists if carried by humans.
## Tracks discovery, apprenticeship, teaching, and forgetting of knowledge.

# Autoload references
@onready var WorldAI = get_node_or_null("/root/WorldAI")
@onready var WorldMemory = get_node_or_null("/root/WorldMemory")
@onready var GameManager = get_node_or_null("/root/GameManager")

enum KnowledgeType {
	FIRE_KEEPING = 0,
	FOOD_STORAGE = 1,
	TOOL_MAKING = 2,
	SEASON_READING = 3,
	SICKNESS_AVOIDANCE = 4,
	NAVIGATION = 5,
	SHELTER_BUILDING = 6,
	MEMORY_PRESERVATION = 7,
	RUIN_INTERPRETATION = 8,
	HOSPITALITY = 9,
	WINTER_SURVIVAL = 10,
	TEACHING = 11
}

const KNOWLEDGE_DEGRADATION_INTERVAL_TICKS: int = 1000
const KNOWLEDGE_DEGRADATION_PHASE_OFFSET_TICKS: int = 127
const BASE_DISCOVERY_RESEARCH_POINTS: int = 3
const BASE_TEACHING_RESEARCH_POINTS: int = 2

## Knowledge carriers: pawn_id -> Array[KnowledgeType]
var knowledge_carriers: Dictionary = {}

## Knowledge transmission records: who taught whom what when
var teaching_records: Array[Dictionary] = []

## Knowledge loss records: lost knowledge events
var lost_knowledge: Array[Dictionary] = []

## Rediscovery records: knowledge rediscovered after loss
var rediscovered_knowledge: Array[Dictionary] = []

## Knowledge degradation: knowledge_type -> degradation level (0.0-1.0)
var knowledge_degradation: Dictionary = {}
## settlement_id(String) -> research points (knowledge currency for TechnologySystem)
var research_points_by_settlement: Dictionary = {}

func _ready() -> void:
	GameManager.game_tick.connect(_on_game_tick)
	_initialize_degradation()

func _initialize_degradation() -> void:
	for k in KnowledgeType.values():
		knowledge_degradation[k] = 0.0

func _on_game_tick(tick: int) -> void:
	if GameManager.periodic_phase_due(tick, KNOWLEDGE_DEGRADATION_INTERVAL_TICKS, KNOWLEDGE_DEGRADATION_PHASE_OFFSET_TICKS):
		_update_knowledge_degradation()

# === Knowledge Carrier Management ===

func add_knowledge_carrier(pawn_id: int, knowledge_type: KnowledgeType) -> void:
	if not knowledge_carriers.has(pawn_id):
		knowledge_carriers[pawn_id] = []
	
	var known: Array = knowledge_carriers[pawn_id]
	if not knowledge_type in known:
		known.append(knowledge_type)
		_record_knowledge_acquisition(pawn_id, knowledge_type)

func remove_knowledge_carrier(pawn_id: int) -> void:
	if knowledge_carriers.has(pawn_id):
		var known: Array = knowledge_carriers[pawn_id]
		for knowledge_type in known:
			_check_knowledge_loss(knowledge_type)
		knowledge_carriers.erase(pawn_id)

func has_knowledge(pawn_id: int, knowledge_type: KnowledgeType) -> bool:
	if not knowledge_carriers.has(pawn_id):
		return false
	return knowledge_type in knowledge_carriers[pawn_id]

func get_carrier_count(knowledge_type: KnowledgeType) -> int:
	var count: int = 0
	for pawn_id in knowledge_carriers:
		if knowledge_type in knowledge_carriers[pawn_id]:
			count += 1
	return count

# === Discovery Mechanism ===

func discover_knowledge(pawn_id: int, knowledge_type: KnowledgeType, source_type: String = "observation") -> void:
	# Pawn discovers knowledge through observation or experience
	if not has_knowledge(pawn_id, knowledge_type):
		add_knowledge_carrier(pawn_id, knowledge_type)
		_record_discovery_event(pawn_id, knowledge_type, source_type)

func attempt_discovery_from_observation(pawn_id: int, observer_tile: Vector2i, knowledge_type: KnowledgeType) -> bool:
	# Check if pawn can discover knowledge by observing nearby activity
	var nearby_carriers: Array[int] = _get_nearby_knowledge_carriers(observer_tile, knowledge_type, 10)
	
	if nearby_carriers.size() > 0:
		# Discovery chance based on proximity and observation time
		var discovery_chance: float = 0.1 * nearby_carriers.size()
		var salt: int = (
				GameManager.tick_count
				+ pawn_id * 1009
				+ observer_tile.x * 9176
				+ observer_tile.y * 131
				+ int(knowledge_type) * 37
		)
		if WorldRNG.chance_for(StringName("knowledge_discovery:%d" % int(knowledge_type)), discovery_chance, salt):
			discover_knowledge(pawn_id, knowledge_type, "observation")
			return true
	
	return false

# === Apprenticeship System ===

func start_apprenticeship(teacher_id: int, apprentice_id: int, knowledge_type: KnowledgeType) -> bool:
	# Establish teaching relationship
	if not has_knowledge(teacher_id, knowledge_type):
		return false
	
	if not has_knowledge(apprentice_id, knowledge_type):
		_record_apprenticeship_start(teacher_id, apprentice_id, knowledge_type)
		return true
	
	return false

func complete_teaching(teacher_id: int, apprentice_id: int, knowledge_type: KnowledgeType, success: bool) -> void:
	if success:
		add_knowledge_carrier(apprentice_id, knowledge_type)
		_record_teaching_success(teacher_id, apprentice_id, knowledge_type)
	else:
		_record_teaching_failure(teacher_id, apprentice_id, knowledge_type)

# === Forgetting Mechanism ===

func _check_knowledge_loss(knowledge_type: KnowledgeType) -> void:
	var carrier_count: int = get_carrier_count(knowledge_type)
	
	if carrier_count == 0:
		# Knowledge is lost - no carriers remain
		_record_knowledge_loss(knowledge_type, "no_carriers")
		_notify_world_ai_knowledge_loss(knowledge_type)
	elif carrier_count <= 2:
		# Knowledge is at risk - few carriers remain
		_record_knowledge_risk(knowledge_type, carrier_count)
		_notify_world_ai_knowledge_risk(knowledge_type, carrier_count)

func _update_knowledge_degradation() -> void:
	# Knowledge degrades over time without practice/teaching
	for knowledge_type in knowledge_degradation:
		var carrier_count: int = get_carrier_count(knowledge_type)
		var teaching_count: int = _count_recent_teaching(knowledge_type, 5000)
		
		# Degradation increases when few carriers and little teaching
		if carrier_count <= 3 and teaching_count == 0:
			knowledge_degradation[knowledge_type] = min(knowledge_degradation[knowledge_type] + 0.05, 1.0)
		elif carrier_count > 5 or teaching_count > 0:
			knowledge_degradation[knowledge_type] = max(knowledge_degradation[knowledge_type] - 0.02, 0.0)

func rediscover_knowledge(pawn_id: int, knowledge_type: KnowledgeType, method: String = "rediscovery") -> void:
	# Knowledge rediscovered after being lost
	if not has_knowledge(pawn_id, knowledge_type):
		add_knowledge_carrier(pawn_id, knowledge_type)
		_record_rediscovery(pawn_id, knowledge_type, method)

# === Helper Functions ===

func _get_nearby_knowledge_carriers(_tile: Vector2i, knowledge_type: KnowledgeType, _radius: int) -> Array[int]:
	var nearby: Array[int] = []
	
	for pawn_id in knowledge_carriers:
		if knowledge_type in knowledge_carriers[pawn_id]:
			# Get pawn tile position from PawnData if available
			# This would need to be connected to the actual pawn system
			nearby.append(pawn_id)
	
	return nearby

func _count_recent_teaching(knowledge_type: KnowledgeType, within_ticks: int) -> int:
	var count: int = 0
	var current_tick: int = GameManager.tick_count
	
	for record in teaching_records:
		if record.get("knowledge_type") == knowledge_type:
			var record_tick: int = record.get("tick", 0)
			if current_tick - record_tick <= within_ticks:
				count += 1
	
	return count

func _notify_world_ai_knowledge_loss(knowledge_type: KnowledgeType) -> void:
	# Notify WorldAI of knowledge loss to update neural network
	if WorldAI != null and WorldAI.has_method("on_knowledge_lost"):
		WorldAI.on_knowledge_lost(knowledge_type)

func _notify_world_ai_knowledge_risk(knowledge_type: KnowledgeType, carrier_count: int) -> void:
	# Notify WorldAI of knowledge risk to update neural network
	if WorldAI != null and WorldAI.has_method("on_knowledge_at_risk"):
		WorldAI.on_knowledge_at_risk(knowledge_type, carrier_count)

# === Event Recording ===

func _record_knowledge_acquisition(pawn_id: int, knowledge_type: KnowledgeType) -> void:
	var event: Dictionary = {
		"type": "knowledge_acquisition",
		"pawn_id": pawn_id,
		"knowledge_type": knowledge_type,
		"tick": GameManager.tick_count
	}
	WorldMemory.record_event(event)

func _record_discovery_event(pawn_id: int, knowledge_type: KnowledgeType, source: String) -> void:
	var event: Dictionary = {
		"type": "knowledge_discovery",
		"pawn_id": pawn_id,
		"knowledge_type": knowledge_type,
		"source": source,
		"tick": GameManager.tick_count
	}
	WorldMemory.record_event(event)
	_add_research_points_for_pawn(pawn_id, BASE_DISCOVERY_RESEARCH_POINTS, "discovery")

func _record_apprenticeship_start(teacher_id: int, apprentice_id: int, knowledge_type: KnowledgeType) -> void:
	var event: Dictionary = {
		"type": "apprenticeship_start",
		"teacher_id": teacher_id,
		"apprentice_id": apprentice_id,
		"knowledge_type": knowledge_type,
		"tick": GameManager.tick_count
	}
	WorldMemory.record_event(event)

func _record_teaching_success(teacher_id: int, apprentice_id: int, knowledge_type: KnowledgeType) -> void:
	var record: Dictionary = {
		"teacher_id": teacher_id,
		"apprentice_id": apprentice_id,
		"knowledge_type": knowledge_type,
		"success": true,
		"tick": GameManager.tick_count
	}
	teaching_records.append(record)
	
	var event: Dictionary = {
		"type": "teaching_success",
		"teacher_id": teacher_id,
		"apprentice_id": apprentice_id,
		"knowledge_type": knowledge_type,
		"tick": GameManager.tick_count
	}
	WorldMemory.record_event(event)
	_add_research_points_for_pawn(teacher_id, BASE_TEACHING_RESEARCH_POINTS, "teaching_success")

func _record_teaching_failure(teacher_id: int, apprentice_id: int, knowledge_type: KnowledgeType) -> void:
	var record: Dictionary = {
		"teacher_id": teacher_id,
		"apprentice_id": apprentice_id,
		"knowledge_type": knowledge_type,
		"success": false,
		"tick": GameManager.tick_count
	}
	teaching_records.append(record)
	
	var event: Dictionary = {
		"type": "teaching_failure",
		"teacher_id": teacher_id,
		"apprentice_id": apprentice_id,
		"knowledge_type": knowledge_type,
		"tick": GameManager.tick_count
	}
	WorldMemory.record_event(event)

func _record_knowledge_loss(knowledge_type: KnowledgeType, reason: String) -> void:
	var record: Dictionary = {
		"knowledge_type": knowledge_type,
		"reason": reason,
		"tick": GameManager.tick_count
	}
	lost_knowledge.append(record)
	
	var event: Dictionary = {
		"type": "knowledge_loss",
		"knowledge_type": knowledge_type,
		"reason": reason,
		"tick": GameManager.tick_count
	}
	WorldMemory.record_event(event)


# === Public Query Functions ===

func get_total_carrier_count() -> int:
	return knowledge_carriers.size()

func get_total_knowledge_count() -> int:
	var total: int = 0
	for carrier_id in knowledge_carriers:
		var knowledge: Array = knowledge_carriers[carrier_id]
		total += knowledge.size()
	return total

func _record_knowledge_risk(knowledge_type: KnowledgeType, carrier_count: int) -> void:
	var event: Dictionary = {
		"type": "knowledge_risk",
		"knowledge_type": knowledge_type,
		"carrier_count": carrier_count,
		"tick": GameManager.tick_count
	}
	WorldMemory.record_event(event)

func _record_rediscovery(pawn_id: int, knowledge_type: KnowledgeType, method: String) -> void:
	var record: Dictionary = {
		"pawn_id": pawn_id,
		"knowledge_type": knowledge_type,
		"method": method,
		"tick": GameManager.tick_count
	}
	rediscovered_knowledge.append(record)
	
	var event: Dictionary = {
		"type": "knowledge_rediscovery",
		"pawn_id": pawn_id,
		"knowledge_type": knowledge_type,
		"method": method,
		"tick": GameManager.tick_count
	}
	WorldMemory.record_event(event)

# === Public Interface ===

func get_knowledge_status() -> Dictionary:
	var status: Dictionary = {}
	
	for k in KnowledgeType.values():
		status[KnowledgeType.keys()[k]] = {
			"carriers": get_carrier_count(k),
			"degradation": knowledge_degradation.get(k, 0.0),
			"lost": _is_knowledge_lost(k)
		}
	
	return status

func _is_knowledge_lost(knowledge_type: KnowledgeType) -> bool:
	return get_carrier_count(knowledge_type) == 0

func get_pawn_knowledge(pawn_id: int) -> Array:
	if knowledge_carriers.has(pawn_id):
		return knowledge_carriers[pawn_id]
	return []

func clear() -> void:
	knowledge_carriers.clear()
	teaching_records.clear()
	lost_knowledge.clear()
	rediscovered_knowledge.clear()
	research_points_by_settlement.clear()
	_initialize_degradation()


## === Research Pool Integration ===

func get_research_points(settlement_id: int) -> int:
	return int(research_points_by_settlement.get(str(settlement_id), 0))


func add_research_points(settlement_id: int, amount: int, reason: String = "knowledge_flow") -> void:
	if settlement_id < 0 or amount <= 0:
		return
	var key: String = str(settlement_id)
	var now_points: int = int(research_points_by_settlement.get(key, 0))
	research_points_by_settlement[key] = now_points + amount
	WorldMemory.record_event({
		"type": "research_points_gain",
		"settlement_id": settlement_id,
		"amount": amount,
		"reason": reason,
		"tick": GameManager.tick_count,
	})


func spend_research_points(settlement_id: int, amount: int, tech_id: String = "") -> bool:
	if settlement_id < 0 or amount <= 0:
		return false
	var key: String = str(settlement_id)
	var now_points: int = int(research_points_by_settlement.get(key, 0))
	if now_points < amount:
		return false
	research_points_by_settlement[key] = now_points - amount
	WorldMemory.record_event({
		"type": "research_points_spend",
		"settlement_id": settlement_id,
		"amount": amount,
		"tech_id": tech_id,
		"tick": GameManager.tick_count,
	})
	return true


## Filter tree by prerequisite state + already researched state + available points.
func get_researchable_techs(settlement_id: int) -> Array:
	if TechnologySystem == null or not TechnologySystem.has_method("get_available_research"):
		return []
	var available: Array = TechnologySystem.get_available_research(settlement_id)
	var points: int = get_research_points(settlement_id)
	var out: Array = []
	for tech_id_any in available:
		var tech_id: String = str(tech_id_any)
		if not TechnologySystem.TECH_TREE.has(tech_id):
			continue
		var node: Dictionary = TechnologySystem.TECH_TREE[tech_id] as Dictionary
		var cost: int = int(node.get("cost", 0))
		if points >= cost:
			out.append(tech_id)
	return out


func _add_research_points_for_pawn(pawn_id: int, amount: int, reason: String) -> void:
	if amount <= 0:
		return
	var settlement_id: int = _settlement_id_for_pawn(pawn_id)
	if settlement_id >= 0:
		add_research_points(settlement_id, amount, reason)


func _settlement_id_for_pawn(pawn_id: int) -> int:
	if SettlementMemory == null:
		return -1
	var main_loop: MainLoop = Engine.get_main_loop()
	if main_loop == null or not (main_loop is SceneTree):
		return -1
	var tree: SceneTree = main_loop as SceneTree
	for n in tree.get_nodes_in_group("pawns"):
		if n == null or not is_instance_valid(n):
			continue
		if not n.has_method("get"):
			continue
		var data_v: Variant = n.get("data")
		if data_v == null:
			continue
		if int(data_v.id) != pawn_id:
			continue
		var pos: Vector2i = data_v.tile_pos
		var rk: int = WorldMemory._region_key(pos.x, pos.y)
		return SettlementMemory.get_center_region_for_region(rk)
	return -1
