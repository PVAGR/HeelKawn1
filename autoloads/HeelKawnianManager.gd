extends Node
class_name HeelKawnianManager

## Derived per-pawn development intelligence.
##
## This layer does not command pawns yet. It reads the pawn, memory, knowledge,
## progression, and civilization state, then returns a deterministic profile that
## future AI can use to decide how each HeelKawnian grows.

const MAX_MEMORY_EVENTS: int = 8

static var _identity_by_soul: Dictionary = {}


static func ensure_identity_for_pawn(pawn: Variant) -> String:
	var data: PawnData = _pawn_data(pawn)
	if data == null:
		return ""
	data.ensure_soul_identity()
	var soul_id: String = data.unique_id
	if soul_id.is_empty():
		soul_id = "soul_%d" % int(data.id)
	if not _identity_by_soul.has(soul_id):
		_identity_by_soul[soul_id] = HeelKawnianIdentity.new(soul_id, _world_seed())
	return soul_id


static func get_identity_for_pawn(pawn: Variant) -> HeelKawnianIdentity:
	var soul_id: String = ensure_identity_for_pawn(pawn)
	if soul_id.is_empty():
		return null
	return _identity_by_soul.get(soul_id, null) as HeelKawnianIdentity


static func get_development_profile_for_pawn(pawn: Variant) -> Dictionary:
	var data: PawnData = _pawn_data(pawn)
	if data == null:
		return {}
	var soul_id: String = ensure_identity_for_pawn(pawn)
	var known: Array[int] = _known_knowledge_for_pawn(int(data.id))
	var settlement_id: int = _settlement_key_for_pawn(data)
	var civ: Dictionary = _civilization_snapshot(settlement_id)
	var recent_events: Array[Dictionary] = _recent_events_for_pawn(int(data.id), MAX_MEMORY_EVENTS)
	var skill_summary: Dictionary = _skill_summary(data)
	var axes: Dictionary = _development_axes(data, known, civ, recent_events, skill_summary)
	var drive: String = _development_drive(data, axes, known, civ)
	var next_need: String = _next_need_for_drive(drive, data, axes, known, civ)
	var development_score: int = _development_score(axes, known, data)
	var profile: Dictionary = {
		"tick": _tick(),
		"pawn_id": int(data.id),
		"soul_id": soul_id,
		"name": data.display_name,
		"age": data.age,
		"profession": _profession_name(int(data.current_profession)),
		"life_path": _life_path_name(int(data.life_path)),
		"settlement_id": settlement_id,
		"era": str(civ.get("stage_name", "Primitive")),
		"era_score": int(civ.get("score", 0)),
		"development_score": development_score,
		"development_phase": _development_phase(development_score, civ),
		"development_drive": drive,
		"next_need": next_need,
		"known_knowledge_count": known.size(),
		"known_knowledge": _knowledge_names(known),
		"skills": skill_summary,
		"axes": axes,
		"recent_event_count": recent_events.size(),
		"identity_traits": _identity_traits(soul_id),
	}
	var identity: HeelKawnianIdentity = get_identity_for_pawn(pawn)
	if identity != null:
		identity.absorb_profile(profile)
	return profile


static func get_profiles_for_pawns(pawns: Array, max_items: int = 16) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for pawn in pawns:
		if out.size() >= max_items:
			break
		var profile: Dictionary = get_development_profile_for_pawn(pawn)
		if not profile.is_empty():
			out.append(profile)
	return out


static func log_heelkawn_event(
		soul_id: String,
		event_type: String,
		payload: Dictionary,
		rationale: String,
		inputs_snapshot: Dictionary,
		tick: int
) -> void:
	var event: Dictionary = {
		"event_id": "heelkawnian_%s_%d" % [soul_id, tick],
		"source_ai": "HeelKawnianManager",
		"event_type": event_type,
		"payload": payload,
		"rationale": rationale,
		"inputs_snapshot": inputs_snapshot,
		"tick": tick,
	}
	var identity: HeelKawnianIdentity = _identity_by_soul.get(soul_id, null) as HeelKawnianIdentity
	if identity != null:
		identity.evolve(event)
	var wm: Node = _root_node("WorldMemory")
	if wm != null and wm.has_method("record_event"):
		var wm_event: Dictionary = event.duplicate(true)
		wm_event["type"] = "heelkawnian_development"
		wm.call("record_event", wm_event)
	elif OS.is_debug_build():
		print("HeelKawnianEventLog", event)


static func _development_axes(
		data: PawnData,
		known: Array[int],
		civ: Dictionary,
		recent_events: Array[Dictionary],
		skills: Dictionary
) -> Dictionary:
	var avg_need: float = (
		clampf(data.hunger, 0.0, 100.0)
		+ clampf(data.thirst, 0.0, 100.0)
		+ clampf(data.rest, 0.0, 100.0)
		+ clampf(data.health, 0.0, 100.0)
	) / 4.0
	var survival: int = clampi(int(round(avg_need)), 0, 100)
	var highest_skill: int = int(skills.get("highest_level", 0))
	var practice: int = clampi(highest_skill * 5 + int(data.level * 3), 0, 100)
	var knowledge: int = clampi(known.size() * 8 + _knowledge_quality_bonus(known), 0, 100)
	var social: int = clampi(
		data.family_bonds.size() * 8
		+ data.trust.size() * 3
		+ data.children_ids.size() * 10
		+ int(data.reputation_score / 5.0),
		0,
		100
	)
	var preservation: int = clampi(
		data.biography.size() * 3
		+ data.known_historical_sites.size() * 8
		+ (20 if known.has(KnowledgeSystem.KnowledgeType.MEMORY_PRESERVATION) else 0)
		+ (30 if known.has(KnowledgeSystem.KnowledgeType.WRITING) else 0),
		0,
		100
	)
	var innovation: int = clampi(
		highest_skill * 3
		+ int(civ.get("score", 0)) / 2
		+ (20 if known.has(KnowledgeSystem.KnowledgeType.CRAFTING) else 0)
		+ (20 if known.has(KnowledgeSystem.KnowledgeType.ENGINEERING) else 0)
		+ (15 if known.has(KnowledgeSystem.KnowledgeType.PHILOSOPHY) else 0),
		0,
		100
	)
	var trauma_pressure: int = 0
	for ev in recent_events:
		var typ: String = str(ev.get("type", ""))
		if typ in ["pawn_death", "starvation_event", "fire_started", "disaster", "knowledge_lost"]:
			trauma_pressure += 10
	return {
		"survival": survival,
		"practice": practice,
		"knowledge": knowledge,
		"social": social,
		"preservation": preservation,
		"innovation": innovation,
		"trauma_pressure": clampi(trauma_pressure, 0, 100),
	}


static func _development_drive(data: PawnData, axes: Dictionary, known: Array[int], civ: Dictionary) -> String:
	if int(axes.get("survival", 0)) < 45:
		return "survive"
	if int(axes.get("trauma_pressure", 0)) >= 30:
		return "recover"
	if int(axes.get("preservation", 0)) < 25 and known.size() >= 2:
		return "preserve"
	if int(axes.get("knowledge", 0)) < 25:
		return "learn"
	if int(axes.get("practice", 0)) < 35:
		return "practice"
	if int(axes.get("social", 0)) < 30 and data.age >= 16:
		return "bond"
	if int(axes.get("innovation", 0)) >= 65 and int(civ.get("stage", 0)) >= 1:
		return "innovate"
	if int(axes.get("knowledge", 0)) >= 35 and int(axes.get("practice", 0)) >= 45:
		return "teach"
	return "serve_settlement"


static func _next_need_for_drive(
		drive: String,
		data: PawnData,
		axes: Dictionary,
		known: Array[int],
		civ: Dictionary
) -> String:
	match drive:
		"survive":
			if data.hunger < 50.0:
				return "secure food"
			if data.thirst < 50.0:
				return "secure water"
			if data.rest < 45.0:
				return "find rest"
			return "recover health"
		"recover":
			return "seek safety and lower trauma pressure"
		"preserve":
			if not known.has(KnowledgeSystem.KnowledgeType.MEMORY_PRESERVATION):
				return "learn memory preservation"
			if not known.has(KnowledgeSystem.KnowledgeType.WRITING):
				return "push toward writing and records"
			return "inscribe, teach, or copy knowledge"
		"learn":
			return "observe skilled pawns and practice unknown work"
		"practice":
			return "repeat useful labor until mastery branches unlock"
		"bond":
			return "build trust, family, and household stability"
		"innovate":
			return "combine mastered skill with knowledge to raise the era"
		"teach":
			return "teach apprentices before knowledge dies"
	return "serve local needs in %s era" % str(civ.get("stage_name", "Primitive"))


static func _development_score(axes: Dictionary, known: Array[int], data: PawnData) -> int:
	var score: int = 0
	score += int(axes.get("survival", 0)) / 5
	score += int(axes.get("practice", 0)) / 5
	score += int(axes.get("knowledge", 0)) / 5
	score += int(axes.get("social", 0)) / 10
	score += int(axes.get("preservation", 0)) / 10
	score += int(axes.get("innovation", 0)) / 10
	score += mini(10, known.size())
	score += mini(10, int(data.biography.size() / 2))
	return clampi(score, 0, 100)


static func _development_phase(score: int, civ: Dictionary) -> String:
	var stage: int = int(civ.get("stage", 0))
	if score < 20:
		return "survivor"
	if score < 40:
		return "worker"
	if score < 60:
		return "specialist"
	if score < 80:
		return "culture_carrier"
	if stage >= 2:
		return "civilization_builder"
	return "founder"


static func _skill_summary(data: PawnData) -> Dictionary:
	var levels: Dictionary = {}
	var highest_level: int = 0
	var highest_name: String = "none"
	for skill in PawnData.Skill.values():
		var level: int = data.get_skill_level(skill)
		var name: String = PawnData.skill_name(skill)
		levels[name] = level
		if level > highest_level:
			highest_level = level
			highest_name = name
	return {
		"levels": levels,
		"highest_level": highest_level,
		"highest_skill": highest_name,
		"skill_tree_count": data.skill_trees.size(),
		"mastery_perks": data.mastery_perks.size(),
	}


static func _known_knowledge_for_pawn(pawn_id: int) -> Array[int]:
	var ks: Node = _root_node("KnowledgeSystem")
	if ks == null:
		return []
	var carriers_v: Variant = ks.get("knowledge_carriers")
	if not (carriers_v is Dictionary):
		return []
	var arr_v: Variant = (carriers_v as Dictionary).get(pawn_id, [])
	var out: Array[int] = []
	if arr_v is Array:
		for kt in arr_v:
			out.append(int(kt))
	out.sort()
	return out


static func _knowledge_names(known: Array[int]) -> Array[String]:
	var out: Array[String] = []
	for kt in known:
		out.append(_knowledge_name(kt))
	return out


static func _knowledge_name(knowledge_type: int) -> String:
	var keys: Array = KnowledgeSystem.KnowledgeType.keys()
	if knowledge_type >= 0 and knowledge_type < keys.size():
		return str(keys[knowledge_type]).to_lower()
	return "knowledge_%d" % knowledge_type


static func _knowledge_quality_bonus(known: Array[int]) -> int:
	var bonus: int = 0
	for kt in known:
		match kt:
			KnowledgeSystem.KnowledgeType.TEACHING:
				bonus += 4
			KnowledgeSystem.KnowledgeType.MEMORY_PRESERVATION:
				bonus += 5
			KnowledgeSystem.KnowledgeType.WRITING:
				bonus += 8
			KnowledgeSystem.KnowledgeType.ENGINEERING, KnowledgeSystem.KnowledgeType.METALLURGY:
				bonus += 6
			KnowledgeSystem.KnowledgeType.PHILOSOPHY, KnowledgeSystem.KnowledgeType.MEDICINE:
				bonus += 5
	return bonus


static func _civilization_snapshot(settlement_id: int) -> Dictionary:
	var civ: Node = _root_node("CivilizationStage")
	if civ != null and civ.has_method("get_stage_snapshot"):
		return civ.call("get_stage_snapshot", settlement_id)
	return {"stage": 0, "stage_name": "Primitive", "score": 0}


static func _recent_events_for_pawn(pawn_id: int, max_items: int) -> Array[Dictionary]:
	var wm: Node = _root_node("WorldMemory")
	if wm != null and wm.has_method("get_recent_events_for_pawn"):
		return wm.call("get_recent_events_for_pawn", pawn_id, max_items)
	return []


static func _identity_traits(soul_id: String) -> Dictionary:
	var identity: HeelKawnianIdentity = _identity_by_soul.get(soul_id, null) as HeelKawnianIdentity
	if identity == null:
		return {}
	return identity.traits.duplicate(true)


static func _settlement_key_for_pawn(data: PawnData) -> int:
	if int(data.settlement_id) >= 0:
		return int(data.settlement_id)
	var wm: Node = _root_node("WorldMemory")
	if wm != null and wm.has_method("_region_key"):
		return int(wm.call("_region_key", data.tile_pos.x, data.tile_pos.y))
	return -1


static func _pawn_data(pawn: Variant) -> PawnData:
	if pawn == null or not is_instance_valid(pawn):
		return null
	var data_v: Variant = pawn.get("data")
	if data_v is PawnData:
		return data_v as PawnData
	return null


static func _profession_name(profession: int) -> String:
	var keys: Array = PawnData.Profession.keys()
	if profession >= 0 and profession < keys.size():
		return str(keys[profession]).to_lower()
	return "unknown"


static func _life_path_name(path: int) -> String:
	var keys: Array = PawnData.LifePath.keys()
	if path >= 0 and path < keys.size():
		return str(keys[path]).to_lower()
	return "unknown"


static func _root_node(name: String) -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null(name)


static func _world_seed() -> int:
	var wrng: Node = _root_node("WorldRNG")
	if wrng != null and wrng.has_method("current_seed"):
		return int(wrng.call("current_seed"))
	return 0


static func _tick() -> int:
	var gm: Node = _root_node("GameManager")
	if gm != null:
		return int(gm.get("tick_count"))
	return 0
