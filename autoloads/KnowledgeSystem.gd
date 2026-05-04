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
const RESEARCH_POINT_ACCUM_INTERVAL_TICKS: int = 300
const RESEARCH_POINT_ACCUM_PHASE_OFFSET_TICKS: int = 61

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

## Dormant knowledge: knowledge_type -> { last_known_location, last_practiced_tick, last_carrier_id, marker_placed }
## When the last carrier of a knowledge type dies, the knowledge enters dormant state.
## It can be rediscovered by curious/scholar pawns at the last known location.
var dormant_knowledge: Dictionary = {}

## Teaching debt: pawn_id -> { obligation_weight, last_taught_tick, knowledge_types_mastered }
## Masters who don't teach accumulate obligation weight, affecting mood and community support.
var teaching_debt: Dictionary = {}

## Knowledge genealogy: knowledge_type -> Array of { teacher_id, student_id, tick }
## Tracks the lineage of who learned from whom for each knowledge type.
var knowledge_genealogy: Dictionary = {}

## Knowledge security per settlement: settlement_id(str) -> { secure: [KnowledgeType], at_risk: [KnowledgeType], lost: [KnowledgeType] }
var knowledge_security: Dictionary = {}

const TEACHING_DEBT_INTERVAL_TICKS: int = 500
const TEACHING_DEBT_PHASE_OFFSET: int = 83
const KNOWLEDGE_SECURITY_INTERVAL_TICKS: int = 1000
const KNOWLEDGE_SECURITY_PHASE_OFFSET: int = 197
const MASTERY_XP_THRESHOLD: int = 100  # XP level at which a pawn is considered a "master"
const TEACHING_DEBT_MOOD_PENALTY: float = 0.5  # Mood reduction per 0.1 obligation weight
const REDISCOVERY_BASE_CHANCE: float = 0.05  # 5% per check at dormant location

func _ready() -> void:
	GameManager.game_tick.connect(_on_game_tick)
	_initialize_degradation()

func _initialize_degradation() -> void:
	for k in KnowledgeType.values():
		knowledge_degradation[k] = 0.0

func _on_game_tick(tick: int) -> void:
	if GameManager.periodic_phase_due(tick, KNOWLEDGE_DEGRADATION_INTERVAL_TICKS, KNOWLEDGE_DEGRADATION_PHASE_OFFSET_TICKS):
		_update_knowledge_degradation()
	if GameManager.periodic_phase_due(tick, RESEARCH_POINT_ACCUM_INTERVAL_TICKS, RESEARCH_POINT_ACCUM_PHASE_OFFSET_TICKS):
		_accrue_research_points_from_knowledge_carriers()
	if GameManager.periodic_phase_due(tick, TEACHING_DEBT_INTERVAL_TICKS, TEACHING_DEBT_PHASE_OFFSET):
		_update_teaching_debt()
	if GameManager.periodic_phase_due(tick, KNOWLEDGE_SECURITY_INTERVAL_TICKS, KNOWLEDGE_SECURITY_PHASE_OFFSET):
		_update_knowledge_security()

# === Knowledge Carrier Management ===

func add_knowledge_carrier(pawn_id: int, knowledge_type: KnowledgeType) -> void:
	if not knowledge_carriers.has(pawn_id):
		knowledge_carriers[pawn_id] = []
	
	var known: Array = knowledge_carriers[pawn_id]
	if not knowledge_type in known:
		known.append(knowledge_type)
		_record_knowledge_acquisition(pawn_id, knowledge_type)

func remove_knowledge_carrier(pawn_id: int, last_pos: Vector2i = Vector2i(-1, -1)) -> void:
	if knowledge_carriers.has(pawn_id):
		var known: Array = knowledge_carriers[pawn_id]
		for knowledge_type in known:
			# Record the dying carrier's location for dormant state
			_last_dying_carrier_pos = last_pos
			_last_dying_carrier_id = pawn_id
			_check_knowledge_loss(knowledge_type)
		knowledge_carriers.erase(pawn_id)
	# Remove teaching debt for dead pawn
	if teaching_debt.has(pawn_id):
		# If they died with unfulfilled obligation, record "knowledge sealed"
		var debt: Dictionary = teaching_debt[pawn_id]
		if float(debt.get("obligation_weight", 0.0)) > 0.3:
			WorldMemory.record_event({
				"type": "knowledge_sealed",
				"k": WorldMemory.Kind.TEACHING_EVENT,
				"r": WorldMemory._region_key(last_pos.x, last_pos.y) if last_pos.x >= 0 else 0,
				"t": GameManager.tick_count,
				"pawn_id": pawn_id,
				"obligation_weight": float(debt.get("obligation_weight", 0.0)),
			})
		teaching_debt.erase(pawn_id)

var _last_dying_carrier_pos: Vector2i = Vector2i(-1, -1)
var _last_dying_carrier_id: int = -1

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
		# Knowledge enters dormant state — no living carriers remain
		# Record last known location from the most recent carrier
		var last_location: Vector2i = Vector2i(-1, -1)
		var last_carrier_id: int = -1
		var last_tick: int = 0
		# Find the most recent carrier's info from lost_knowledge records
		for rec in lost_knowledge:
			if int(rec.get("knowledge_type", -1)) == int(knowledge_type):
				var rec_tick: int = int(rec.get("tick", 0))
				if rec_tick > last_tick:
					last_tick = rec_tick
					last_carrier_id = int(rec.get("last_carrier_id", -1))
					last_location = Vector2i(int(rec.get("last_x", -1)), int(rec.get("last_y", -1)))
		# Also check current dying carrier for location
		if last_carrier_id >= 0:
			# Try to get the dying pawn's last known position
			for n in PawnSpawner.find_pawns():
				if n == null or not is_instance_valid(n):
					continue
				if not n.has_method("get"):
					continue
				var data_v: Variant = n.get("data")
				if data_v == null:
					continue
				if int(data_v.id) == last_carrier_id:
					last_location = data_v.tile_pos
					break
		dormant_knowledge[int(knowledge_type)] = {
			"last_known_location": last_location,
			"last_practiced_tick": last_tick,
			"last_carrier_id": last_carrier_id,
			"marker_placed": false,
		}
		_record_knowledge_loss(knowledge_type, "no_carriers")
		_notify_world_ai_knowledge_loss(knowledge_type)
	elif carrier_count <= 2:
		# Knowledge is at risk — few carriers remain
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
	# Teaching debt: successful teaching reduces obligation
	on_teaching_success(teacher_id, int(knowledge_type))

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
		"tick": GameManager.tick_count,
		"last_carrier_id": _last_dying_carrier_id,
		"last_x": _last_dying_carrier_pos.x,
		"last_y": _last_dying_carrier_pos.y,
	}
	lost_knowledge.append(record)
	
	var rk: int = 0
	if _last_dying_carrier_pos.x >= 0:
		rk = WorldMemory._region_key(_last_dying_carrier_pos.x, _last_dying_carrier_pos.y)
	var event: Dictionary = {
		"type": "knowledge_loss",
		"k": WorldMemory.Kind.TEACHING_EVENT,
		"r": rk,
		"t": GameManager.tick_count,
		"knowledge_type": knowledge_type,
		"reason": reason,
		"last_carrier_id": _last_dying_carrier_id,
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
	dormant_knowledge.clear()
	teaching_debt.clear()
	knowledge_genealogy.clear()
	knowledge_security.clear()
	_initialize_degradation()


# === Teaching Debt System ===

## Update teaching debt for all masters. Masters who don't teach accumulate
## obligation weight, which reduces mood and community support.
func _update_teaching_debt() -> void:
	var tick: int = GameManager.tick_count
	# Scan all living pawns for mastery-level skills
	for n in PawnSpawner.find_pawns():
		if n == null or not is_instance_valid(n):
			continue
		if not n.has_method("get"):
			continue
		var data_v: Variant = n.get("data")
		if data_v == null:
			continue
		var pid: int = int(data_v.id)
		# Check if this pawn carries any knowledge (is a carrier = potential master)
		if not knowledge_carriers.has(pid):
			continue
		var known: Array = knowledge_carriers[pid]
		if known.is_empty():
			continue
		# Initialize debt tracking if new
		if not teaching_debt.has(pid):
			teaching_debt[pid] = {
				"obligation_weight": 0.0,
				"last_taught_tick": -1,
				"knowledge_types_mastered": known.size(),
			}
		var debt: Dictionary = teaching_debt[pid]
		# Update mastered count
		debt["knowledge_types_mastered"] = known.size()
		# Check if they've taught recently
		var last_taught: int = int(debt.get("last_taught_tick", -1))
		var ticks_since_teaching: int = tick - last_taught if last_taught >= 0 else 9999
		# Obligation increases if they haven't taught in 2000+ ticks
		if ticks_since_teaching > 2000 and known.size() >= 1:
			var increment: float = 0.02 * float(known.size())  # More knowledge = more obligation
			debt["obligation_weight"] = minf(float(debt.get("obligation_weight", 0.0)) + increment, 1.0)
		elif ticks_since_teaching <= 500:
			# Recent teaching reduces obligation
			debt["obligation_weight"] = maxf(float(debt.get("obligation_weight", 0.0)) - 0.05, 0.0)
		# Apply mood penalty from obligation weight
		var mood_penalty: float = float(debt.get("obligation_weight", 0.0)) * TEACHING_DEBT_MOOD_PENALTY
		if mood_penalty > 0.1:
			data_v.mood = maxf(data_v.mood - mood_penalty, 0.0)


## Record that a pawn taught successfully (reduces their debt)
func on_teaching_success(teacher_id: int, knowledge_type: int) -> void:
	if teaching_debt.has(teacher_id):
		teaching_debt[teacher_id]["last_taught_tick"] = GameManager.tick_count
		teaching_debt[teacher_id]["obligation_weight"] = maxf(
			float(teaching_debt[teacher_id].get("obligation_weight", 0.0)) - 0.15, 0.0)
	# Record genealogy
	if not knowledge_genealogy.has(knowledge_type):
		knowledge_genealogy[knowledge_type] = []
	# Find the student from the most recent teaching record
	for rec in teaching_records:
		if int(rec.get("teacher_id", -1)) == teacher_id and int(rec.get("knowledge_type", -1)) == knowledge_type:
			knowledge_genealogy[knowledge_type].append({
				"teacher_id": teacher_id,
				"student_id": int(rec.get("apprentice_id", -1)),
				"tick": int(rec.get("tick", 0)),
			})
			break


# === Knowledge Security ===

## Update knowledge security per settlement: which skills are secure, at-risk, or lost.
func _update_knowledge_security() -> void:
	knowledge_security.clear()
	# Count carriers per knowledge type per settlement
	var carriers_by_settlement: Dictionary = {}  # settlement_id(str) -> { knowledge_type -> count }
	for n in PawnSpawner.find_pawns():
		if n == null or not is_instance_valid(n):
			continue
		if not n.has_method("get"):
			continue
		var data_v: Variant = n.get("data")
		if data_v == null:
			continue
		var pid: int = int(data_v.id)
		if not knowledge_carriers.has(pid):
			continue
		var pos: Vector2i = data_v.tile_pos
		var rk: int = WorldMemory._region_key(pos.x, pos.y)
		var sid: int = SettlementMemory.get_center_region_for_region(rk)
		if sid < 0:
			continue
		var sid_key: String = str(sid)
		if not carriers_by_settlement.has(sid_key):
			carriers_by_settlement[sid_key] = {}
		for kt in knowledge_carriers[pid]:
			var kt_key: String = str(kt)
			carriers_by_settlement[sid_key][kt_key] = int(carriers_by_settlement[sid_key].get(kt_key, 0)) + 1
	# Classify each settlement's knowledge
	for sid_key in carriers_by_settlement.keys():
		var secure: Array = []
		var at_risk: Array = []
		var lost: Array = []
		var settlement_carriers: Dictionary = carriers_by_settlement[sid_key]
		for k in KnowledgeType.values():
			var count: int = int(settlement_carriers.get(str(k), 0))
			if count >= 3:
				secure.append(k)
			elif count >= 1:
				at_risk.append(k)
			# Lost = dormant knowledge that this settlement doesn't carry
			if count == 0 and dormant_knowledge.has(k):
				lost.append(k)
		knowledge_security[sid_key] = {
			"secure": secure,
			"at_risk": at_risk,
			"lost": lost,
		}


## Get knowledge security for a settlement. Returns { secure, at_risk, lost } arrays.
func get_knowledge_security_for_settlement(settlement_id: int) -> Dictionary:
	var key: String = str(settlement_id)
	if knowledge_security.has(key):
		return knowledge_security[key]
	return {"secure": [], "at_risk": [], "lost": []}


# === Dormant Knowledge & Rediscovery ===

## Check if a knowledge type is dormant (no living carriers).
func is_knowledge_dormant(knowledge_type: KnowledgeType) -> bool:
	return dormant_knowledge.has(int(knowledge_type)) and get_carrier_count(knowledge_type) == 0


## Attempt rediscovery: a pawn at a dormant knowledge's last known location
## may rediscover the knowledge. Deterministic chance based on pawn traits and location.
func attempt_rediscovery(pawn_id: int, pawn_pos: Vector2i, knowledge_type: KnowledgeType) -> bool:
	if not is_knowledge_dormant(knowledge_type):
		return false
	var dormant: Dictionary = dormant_knowledge.get(int(knowledge_type), {})
	var last_loc: Vector2i = Vector2i(int(dormant.get("last_known_location", Vector2i(-1, -1)).x), int(dormant.get("last_known_location", Vector2i(-1, -1)).y))
	# Must be within 5 tiles of the last known location
	if last_loc.x < 0:
		return false
	var dist: int = absi(pawn_pos.x - last_loc.x) + absi(pawn_pos.y - last_loc.y)
	if dist > 5:
		return false
	# Deterministic chance: scholars and curious pawns have higher chance
	var chance: float = REDISCOVERY_BASE_CHANCE
	# Check pawn profession
	for n in PawnSpawner.find_pawns():
		if n == null or not is_instance_valid(n):
			continue
		if not n.has_method("get"):
			continue
		var data_v: Variant = n.get("data")
		if data_v == null:
			continue
		if int(data_v.id) != pawn_id:
			continue
		if data_v.current_profession == PawnData.Profession.SCHOLAR:
			chance += 0.10  # Scholars are better at rediscovery
		if data_v.openness > 0.7:
			chance += 0.03  # Open-minded pawns notice more
		break
	# Seed-based deterministic check
	var salt: int = pawn_id * 1009 + int(knowledge_type) * 37 + GameManager.tick_count / 100
	if WorldRNG.chance_for(StringName("knowledge_rediscovery:%d" % int(knowledge_type)), chance, salt):
		rediscover_knowledge(pawn_id, knowledge_type, "site_rediscovery")
		# Remove from dormant
		dormant_knowledge.erase(int(knowledge_type))
		return true
	return false


## Get all dormant knowledge types.
func get_dormant_knowledge_types() -> Array:
	return dormant_knowledge.keys()


## Get dormant info for a knowledge type.
func get_dormant_info(knowledge_type: int) -> Dictionary:
	return dormant_knowledge.get(knowledge_type, {})


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
	return TechnologySystem.get_available_research(settlement_id)


func _add_research_points_for_pawn(pawn_id: int, amount: int, reason: String) -> void:
	if amount <= 0:
		return
	var settlement_id: int = _settlement_id_for_pawn(pawn_id)
	if settlement_id >= 0:
		add_research_points(settlement_id, amount, reason)


func _settlement_id_for_pawn(pawn_id: int) -> int:
	if SettlementMemory == null:
		return -1
	for n in PawnSpawner.find_pawns():
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


func _accrue_research_points_from_knowledge_carriers() -> void:
	var counts_by_settlement: Dictionary = _knowledge_carrier_counts_by_settlement()
	for sid_key in counts_by_settlement.keys():
		var carrier_count: int = int(counts_by_settlement.get(sid_key, 0))
		if carrier_count <= 0:
			continue
		# Deterministic baseline: every 2 carriers generate +1 point per accrual step, min 1.
		var gain: int = maxi(1, int(floor(float(carrier_count) / 2.0)))
		add_research_points(int(str(sid_key)), gain, "knowledge_carriers")


func _knowledge_carrier_counts_by_settlement() -> Dictionary:
	var out: Dictionary = {}
	if SettlementMemory == null:
		return out
	var carriers_present: Dictionary = {}
	for n in PawnSpawner.find_pawns():
		if n == null or not is_instance_valid(n):
			continue
		if not n.has_method("get"):
			continue
		var data_v: Variant = n.get("data")
		if data_v == null:
			continue
		var pid: int = int(data_v.id)
		if not knowledge_carriers.has(pid):
			continue
		var held: Array = knowledge_carriers[pid] as Array
		if held.is_empty():
			continue
		var pos: Vector2i = data_v.tile_pos
		var rk: int = WorldMemory._region_key(pos.x, pos.y)
		var settlement_id: int = SettlementMemory.get_center_region_for_region(rk)
		if settlement_id < 0:
			continue
		carriers_present[pid] = settlement_id
	for pid_any in carriers_present.keys():
		var sid: int = int(carriers_present[pid_any])
		var key: String = str(sid)
		out[key] = int(out.get(key, 0)) + 1
	return out
