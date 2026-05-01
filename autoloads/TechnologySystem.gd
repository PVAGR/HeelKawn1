extends Node
## Deterministic research tree system driven by KnowledgeSystem.
## Tech truth lives here; KnowledgeSystem provides per-settlement research points.
const RESEARCH_SPEND_INTERVAL_TICKS: int = 120

const EFFECT_STONE_KNAPPING: String = "unlock_stone_knapping"
const EFFECT_AGRICULTURE: String = "unlock_agriculture"
const EFFECT_MASONRY: String = "unlock_masonry"
const EFFECT_PRESERVATION: String = "unlock_food_preservation"
const EFFECT_METALLURGY: String = "unlock_metallurgy"

## Hard-coded early game tree.
const TECH_TREE: Dictionary = {
	"stone_knapping": {
		"name": "Stone Knapping",
		"cost": 25,
		"prereqs": [],
		"effect": EFFECT_STONE_KNAPPING,
	},
	"agriculture": {
		"name": "Agriculture",
		"cost": 40,
		"prereqs": ["stone_knapping"],
		"effect": EFFECT_AGRICULTURE,
	},
	"masonry": {
		"name": "Masonry",
		"cost": 45,
		"prereqs": ["stone_knapping"],
		"effect": EFFECT_MASONRY,
	},
	"food_preservation": {
		"name": "Food Preservation",
		"cost": 50,
		"prereqs": ["agriculture"],
		"effect": EFFECT_PRESERVATION,
	},
	"metallurgy": {
		"name": "Metallurgy",
		"cost": 70,
		"prereqs": ["masonry", "food_preservation"],
		"effect": EFFECT_METALLURGY,
	},
}

## settlement_id(String) -> discovered tech ids(Array[String])
var researched_by_settlement: Dictionary = {}
## settlement_id(String) -> active tech id(String)
var active_research_by_settlement: Dictionary = {}
## settlement_id(String) -> effect flags/multipliers
var tech_effects_by_settlement: Dictionary = {}
var research_history: Array = []

signal research_started(settlement_id: int, tech_id: String, started_tick: int)
signal research_progressed(settlement_id: int, tech_id: String, spent_points: int, cost: int, progress: float)
signal research_completed(settlement_id: int, tech_id: String, cost: int)


func _ready() -> void:
	if GameManager != null and GameManager.has_signal("game_tick"):
		GameManager.game_tick.connect(_on_game_tick)
	_load_from_world_persistence()


func _sid(settlement_id: int) -> String:
	return str(settlement_id)


func has_tech(settlement_id: int, tech_id: String) -> bool:
	var key: String = _sid(settlement_id)
	if not researched_by_settlement.has(key):
		return false
	return tech_id in (researched_by_settlement[key] as Array)


func get_researched_techs(settlement_id: int) -> Array:
	var key: String = _sid(settlement_id)
	if not researched_by_settlement.has(key):
		return []
	return (researched_by_settlement[key] as Array).duplicate()


func get_available_research(settlement_id: int) -> Array:
	var out: Array = []
	for tech_id in TECH_TREE.keys():
		if has_tech(settlement_id, str(tech_id)):
			continue
		if _prereqs_met(settlement_id, str(tech_id)):
			out.append(str(tech_id))
	out.sort_custom(func(a: String, b: String) -> bool:
		var ca: int = int((TECH_TREE.get(a, {}) as Dictionary).get("cost", 999999))
		var cb: int = int((TECH_TREE.get(b, {}) as Dictionary).get("cost", 999999))
		if ca != cb:
			return ca < cb
		return a < b
	)
	return out


## Primary deterministic research transaction:
## - prereq gate
## - starts active research if needed
## - spends available points from KnowledgeSystem pool
## - effect application
## - persistence sync
func research_tech(tech_id: String, settlement_id: int) -> bool:
	if not TECH_TREE.has(tech_id):
		return false
	if has_tech(settlement_id, tech_id):
		return false
	if not _prereqs_met(settlement_id, tech_id):
		return false
	if not set_active_research(settlement_id, tech_id):
		return false
	return _advance_active_research(settlement_id)


func _on_game_tick(tick: int) -> void:
	if tick % RESEARCH_SPEND_INTERVAL_TICKS != 0:
		return
	for key_any in active_research_by_settlement.keys():
		var sid: int = int(str(key_any))
		_advance_active_research(sid)


func _advance_active_research(settlement_id: int) -> bool:
	var key: String = _sid(settlement_id)
	if not active_research_by_settlement.has(key):
		return false
	var st: Dictionary = active_research_by_settlement[key] as Dictionary
	var tech_id: String = str(st.get("tech_id", ""))
	if tech_id.is_empty() or not TECH_TREE.has(tech_id):
		return false
	var node: Dictionary = TECH_TREE[tech_id] as Dictionary
	var cost: int = int(node.get("cost", 0))
	if cost <= 0:
		return false
	var spent: int = int(st.get("spent_points", 0))
	var remaining: int = maxi(0, cost - spent)
	if remaining <= 0:
		_complete_research(settlement_id, tech_id, cost)
		return true
	if KnowledgeSystem == null or not KnowledgeSystem.has_method("get_research_points") or not KnowledgeSystem.has_method("spend_research_points"):
		return false
	var pool_points: int = int(KnowledgeSystem.call("get_research_points", settlement_id))
	if pool_points <= 0:
		return false
	var spend_now: int = mini(pool_points, remaining)
	if spend_now <= 0:
		return false
	if not bool(KnowledgeSystem.call("spend_research_points", settlement_id, spend_now, tech_id)):
		return false
	spent += spend_now
	st["spent_points"] = spent
	active_research_by_settlement[key] = st
	var progress: float = clampf(float(spent) / float(maxi(1, cost)), 0.0, 1.0)
	research_progressed.emit(settlement_id, tech_id, spend_now, cost, progress)
	if spent >= cost:
		_complete_research(settlement_id, tech_id, cost)
		return true
	_save_to_world_persistence()
	return false


func _complete_research(settlement_id: int, tech_id: String, cost: int) -> void:
	var key: String = _sid(settlement_id)
	if not researched_by_settlement.has(key):
		researched_by_settlement[key] = []
	(researched_by_settlement[key] as Array).append(tech_id)
	active_research_by_settlement.erase(key)
	_apply_effect(settlement_id, str((TECH_TREE[tech_id] as Dictionary).get("effect", "")))
	research_history.append({
		"settlement_id": settlement_id,
		"tech_id": tech_id,
		"cost": cost,
		"tick": GameManager.tick_count if GameManager != null else 0,
	})
	WorldMemory.record_event({
		"type": "technology_researched",
		"settlement_id": settlement_id,
		"tech_id": tech_id,
		"cost": cost,
		"tick": GameManager.tick_count if GameManager != null else 0,
	})
	research_completed.emit(settlement_id, tech_id, cost)
	_save_to_world_persistence()


func set_active_research(settlement_id: int, tech_id: String) -> bool:
	if not TECH_TREE.has(tech_id):
		return false
	if has_tech(settlement_id, tech_id):
		return false
	if not _prereqs_met(settlement_id, tech_id):
		return false
	var key: String = _sid(settlement_id)
	if active_research_by_settlement.has(key):
		var current: Dictionary = active_research_by_settlement[key] as Dictionary
		if str(current.get("tech_id", "")) == tech_id:
			return true
	active_research_by_settlement[key] = {
		"tech_id": tech_id,
		"spent_points": 0,
		"started_tick": GameManager.tick_count if GameManager != null else 0,
	}
	research_started.emit(settlement_id, tech_id, int((active_research_by_settlement[key] as Dictionary).get("started_tick", 0)))
	_save_to_world_persistence()
	return true


func get_active_research(settlement_id: int) -> String:
	var key: String = _sid(settlement_id)
	if not active_research_by_settlement.has(key):
		return ""
	var st: Dictionary = active_research_by_settlement[key] as Dictionary
	return str(st.get("tech_id", ""))


func get_effects(settlement_id: int) -> Dictionary:
	var key: String = _sid(settlement_id)
	if not tech_effects_by_settlement.has(key):
		return {}
	return (tech_effects_by_settlement[key] as Dictionary).duplicate(true)


func _prereqs_met(settlement_id: int, tech_id: String) -> bool:
	var node: Dictionary = TECH_TREE[tech_id] as Dictionary
	var prereqs: Array = node.get("prereqs", [])
	for prereq in prereqs:
		if not has_tech(settlement_id, str(prereq)):
			return false
	return true


func _apply_effect(settlement_id: int, effect_id: String) -> void:
	var key: String = _sid(settlement_id)
	if not tech_effects_by_settlement.has(key):
		tech_effects_by_settlement[key] = {}
	var e: Dictionary = tech_effects_by_settlement[key] as Dictionary
	match effect_id:
		EFFECT_STONE_KNAPPING:
			e["job_unlock_mine_wall"] = true
			e["gather_speed_mult"] = maxf(float(e.get("gather_speed_mult", 1.0)), 1.05)
		EFFECT_AGRICULTURE:
			e["job_unlock_forage_advanced"] = true
			e["food_yield_mult"] = maxf(float(e.get("food_yield_mult", 1.0)), 1.15)
		EFFECT_MASONRY:
			e["job_unlock_build_wall"] = true
			e["build_speed_mult"] = maxf(float(e.get("build_speed_mult", 1.0)), 1.1)
		EFFECT_PRESERVATION:
			e["food_spoilage_mult"] = minf(float(e.get("food_spoilage_mult", 1.0)), 0.85)
			e["stockpile_efficiency_mult"] = maxf(float(e.get("stockpile_efficiency_mult", 1.0)), 1.1)
		EFFECT_METALLURGY:
			e["job_unlock_metal_work"] = true
			e["ore_yield_mult"] = maxf(float(e.get("ore_yield_mult", 1.0)), 1.2)
		_:
			return
	tech_effects_by_settlement[key] = e


func _save_to_world_persistence() -> void:
	if WorldPersistence == null:
		return
	WorldPersistence.named_landmarks["technology_state"] = {
		"researched_by_settlement": researched_by_settlement.duplicate(true),
		"active_research_by_settlement": active_research_by_settlement.duplicate(true),
		"tech_effects_by_settlement": tech_effects_by_settlement.duplicate(true),
		"research_history": research_history.duplicate(true),
	}


func _load_from_world_persistence() -> void:
	if WorldPersistence == null:
		return
	var raw: Variant = WorldPersistence.named_landmarks.get("technology_state", {})
	if not (raw is Dictionary):
		return
	var d: Dictionary = raw as Dictionary
	researched_by_settlement = (d.get("researched_by_settlement", {}) as Dictionary).duplicate(true)
	active_research_by_settlement = (d.get("active_research_by_settlement", {}) as Dictionary).duplicate(true)
	tech_effects_by_settlement = (d.get("tech_effects_by_settlement", {}) as Dictionary).duplicate(true)
	research_history = (d.get("research_history", []) as Array).duplicate(true)


func to_dict() -> Dictionary:
	return {
		"researched_by_settlement": researched_by_settlement.duplicate(true),
		"active_research_by_settlement": active_research_by_settlement.duplicate(true),
		"tech_effects_by_settlement": tech_effects_by_settlement.duplicate(true),
		"research_history": research_history.duplicate(true),
	}


func from_dict(data: Dictionary) -> void:
	researched_by_settlement = (data.get("researched_by_settlement", {}) as Dictionary).duplicate(true)
	active_research_by_settlement = (data.get("active_research_by_settlement", {}) as Dictionary).duplicate(true)
	tech_effects_by_settlement = (data.get("tech_effects_by_settlement", {}) as Dictionary).duplicate(true)
	research_history = (data.get("research_history", []) as Array).duplicate(true)
	_save_to_world_persistence()


## === Job Type Tech Requirements ===

## Maps Job.Type (int) to required tech_id (String).
## Jobs without an entry have no tech requirement (always available).
var job_type_tech_requirements: Dictionary = {
	# Mining requires stone knapping
	1: "stone_knapping",   # Job.Type.MINE
	2: "stone_knapping",   # Job.Type.MINE_WALL
	# Building stone walls requires masonry
	6: "masonry",          # Job.Type.BUILD_WALL
	# Crafting requires stone knapping
	11: "stone_knapping",  # Job.Type.CRAFT_KNIFE
	13: "stone_knapping",  # Job.Type.CRAFT_PICK
}


## Check if a settlement has the technology required for a job type.
## Returns true if the job has no tech requirement or if the settlement has researched it.
func can_settle_perform_job_type(settlement_id: int, job_type: int) -> bool:
	if not job_type_tech_requirements.has(job_type):
		# No tech requirement for this job type
		return true
	var required_tech: String = str(job_type_tech_requirements[job_type])
	return has_tech(settlement_id, required_tech)


## Get the tech required for a job type (returns empty string if none required).
func get_job_type_tech_requirement(job_type: int) -> String:
	if not job_type_tech_requirements.has(job_type):
		return ""
	return str(job_type_tech_requirements[job_type])
