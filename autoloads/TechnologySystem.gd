extends Node
## Deterministic research tree system driven by KnowledgeSystem.
## Tech truth lives here; KnowledgeSystem provides per-settlement research points.

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


func _ready() -> void:
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
## - KnowledgeSystem point spend
## - effect application
## - persistence sync
func research_tech(tech_id: String, settlement_id: int) -> bool:
	if not TECH_TREE.has(tech_id):
		return false
	if has_tech(settlement_id, tech_id):
		return false
	if not _prereqs_met(settlement_id, tech_id):
		return false
	var node: Dictionary = TECH_TREE[tech_id] as Dictionary
	var cost: int = int(node.get("cost", 0))
	if cost <= 0:
		return false
	if KnowledgeSystem == null or not KnowledgeSystem.has_method("spend_research_points"):
		return false
	if not bool(KnowledgeSystem.call("spend_research_points", settlement_id, cost, tech_id)):
		return false
	var key: String = _sid(settlement_id)
	if not researched_by_settlement.has(key):
		researched_by_settlement[key] = []
	(researched_by_settlement[key] as Array).append(tech_id)
	active_research_by_settlement.erase(key)
	_apply_effect(settlement_id, str(node.get("effect", "")))
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
	_save_to_world_persistence()
	return true


func set_active_research(settlement_id: int, tech_id: String) -> bool:
	if not TECH_TREE.has(tech_id):
		return false
	if has_tech(settlement_id, tech_id):
		return false
	if not _prereqs_met(settlement_id, tech_id):
		return false
	active_research_by_settlement[_sid(settlement_id)] = tech_id
	_save_to_world_persistence()
	return true


func get_active_research(settlement_id: int) -> String:
	return str(active_research_by_settlement.get(_sid(settlement_id), ""))


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
