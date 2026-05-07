extends Node
class_name HeelKawnianManager

## Derived per-pawn development intelligence.
##
## This layer reads the pawn, memory, knowledge, progression, and civilization
## state, then returns deterministic profile + Matrix AI job biases that pawns
## can use while choosing work. It nudges behavior; it does not override facts,
## player designations, job legality, or the simulation ledger.

const MAX_MEMORY_EVENTS: int = 8
const MATRIX_LOG_MIN_BIAS: int = 5
const MATRIX_LOG_COOLDOWN_TICKS: int = 240
const MATRIX_AMBITION_SETTLEMENT_COOLDOWN_TICKS: int = 180
const MATRIX_AMBITION_PAWN_COOLDOWN_TICKS: int = 90
const MATRIX_AFFILIATION_COOLDOWN_TICKS: int = 240

static var _identity_by_soul: Dictionary = {}
static var _last_matrix_log_tick_by_soul: Dictionary = {}
static var _last_ambition_tick_by_settlement: Dictionary = {}
static var _last_ambition_tick_by_pawn: Dictionary = {}
static var _last_affiliation_tick_by_pawn: Dictionary = {}


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
	var human_scale: Dictionary = _human_scale_levels(data)
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
		"human_scale": human_scale,
		"human_next_level": str(human_scale.get("next_level", "world")),
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


static func get_matrix_decision_for_pawn(pawn: Variant) -> Dictionary:
	var data: PawnData = _pawn_data(pawn)
	if data == null:
		return {}
	var profile: Dictionary = get_development_profile_for_pawn(pawn)
	if profile.is_empty():
		return {}
	var identity: HeelKawnianIdentity = get_identity_for_pawn(pawn)
	var biases: Dictionary = _matrix_job_biases(profile, data, identity)
	var top_jobs: Array[Dictionary] = _top_matrix_jobs(biases, 8)
	var rationale: String = _matrix_rationale(profile, top_jobs)
	return {
		"tick": _tick(),
		"pawn_id": int(data.id),
		"soul_id": str(profile.get("soul_id", "")),
		"name": str(profile.get("name", data.display_name)),
		"drive": str(profile.get("development_drive", "serve_settlement")),
		"phase": str(profile.get("development_phase", "")),
		"next_need": str(profile.get("next_need", "")),
		"era": str(profile.get("era", "")),
		"development_score": int(profile.get("development_score", 0)),
		"job_biases": biases,
		"top_jobs": top_jobs,
		"rationale": rationale,
		"inputs_snapshot": _matrix_inputs_snapshot(profile),
	}


static func get_job_priority_bias_for_pawn(pawn: Variant, job_type: int) -> int:
	var decision: Dictionary = get_matrix_decision_for_pawn(pawn)
	if decision.is_empty():
		return 0
	var biases: Dictionary = decision.get("job_biases", {})
	return clampi(int(biases.get(int(job_type), 0)), -8, 16)


static func note_matrix_job_choice(pawn: Variant, job: Job) -> void:
	if job == null:
		return
	var data: PawnData = _pawn_data(pawn)
	if data == null:
		return
	var decision: Dictionary = get_matrix_decision_for_pawn(pawn)
	if decision.is_empty():
		return
	var biases: Dictionary = decision.get("job_biases", {})
	var bias: int = int(biases.get(int(job.type), 0))
	if abs(bias) < MATRIX_LOG_MIN_BIAS:
		return
	var tick: int = _tick()
	var soul_id: String = str(decision.get("soul_id", ""))
	if soul_id.is_empty():
		return
	var last_tick: int = int(_last_matrix_log_tick_by_soul.get(soul_id, -1000000))
	if tick - last_tick < MATRIX_LOG_COOLDOWN_TICKS:
		return
	_last_matrix_log_tick_by_soul[soul_id] = tick
	var payload: Dictionary = {
		"pawn_id": int(data.id),
		"pawn_name": data.display_name,
		"job_type": int(job.type),
		"job_name": Job.describe_type(int(job.type)),
		"matrix_bias": bias,
		"drive": str(decision.get("drive", "")),
		"phase": str(decision.get("phase", "")),
		"next_need": str(decision.get("next_need", "")),
	}
	log_heelkawn_event(
		soul_id,
		"matrix_decision",
		payload,
		str(decision.get("rationale", "")),
		decision.get("inputs_snapshot", {}),
		tick
	)


static func get_social_action_for_pawn(pawn: Variant) -> Dictionary:
	var data: PawnData = _pawn_data(pawn)
	if data == null:
		return {}
	var profile: Dictionary = get_development_profile_for_pawn(pawn)
	if profile.is_empty():
		return {}
	var drive: String = str(profile.get("development_drive", "serve_settlement"))
	var candidates: Array = _nearby_pawn_candidates(pawn, 28, 26)
	var action: String = "none"
	var target_id: int = -1
	var target_tile: Vector2i = Vector2i(-1, -1)
	var best_score: float = -99999.0
	for c in candidates:
		var other_id: int = int(c.get("id", -1))
		if other_id < 0:
			continue
		var other_tile: Vector2i = c.get("tile", Vector2i(-1, -1))
		var d2: float = float(c.get("d2", 999999.0))
		var rapport: float = float(c.get("rapport", 0.0))
		var trust: float = float(c.get("trust", 50.0))
		var grudge: float = _grudge_intensity(int(data.id), other_id)
		var reputation: float = _reputation_for(other_id)
		var same_settlement: bool = int(c.get("settlement_id", -2)) == int(data.settlement_id)
		var ally_score: float = rapport / 900.0 + trust / 75.0 - grudge * 2.2 + reputation * 0.4 - d2 / 4500.0
		var rival_score: float = grudge * 2.6 + (1.0 - trust / 100.0) + (-reputation) * 0.25 - d2 / 6000.0
		var teach_score: float = ally_score + 0.65 + (0.2 if same_settlement else 0.0)
		match drive:
			"bond", "serve_settlement", "recover":
				if ally_score > best_score:
					best_score = ally_score
					action = "social_seek"
					target_id = other_id
					target_tile = other_tile
			"teach", "learn", "preserve":
				if teach_score > best_score:
					best_score = teach_score
					action = "teach_seek"
					target_id = other_id
					target_tile = other_tile
			_:
				if rival_score > 0.92 and rival_score > best_score:
					best_score = rival_score
					action = "grudge_confront"
					target_id = other_id
					target_tile = other_tile
				elif ally_score > best_score:
					best_score = ally_score
					action = "social_seek"
					target_id = other_id
					target_tile = other_tile
	if target_id < 0:
		return {
			"action": "none",
			"target_id": -1,
			"target_tile": Vector2i(-1, -1),
			"score": 0.0,
			"rationale": "no nearby social candidate",
			"drive": drive,
		}
	return {
		"action": action,
		"target_id": target_id,
		"target_tile": target_tile,
		"score": best_score,
		"rationale": "drive=%s target=%d score=%.2f action=%s" % [drive, target_id, best_score, action],
		"drive": drive,
	}


static func get_settlement_ambition_for_pawn(pawn: Variant) -> Dictionary:
	var data: PawnData = _pawn_data(pawn)
	if data == null:
		return {}
	var profile: Dictionary = get_development_profile_for_pawn(pawn)
	if profile.is_empty():
		return {}
	var tick: int = _tick()
	var pawn_id: int = int(data.id)
	var settlement_id: int = int(profile.get("settlement_id", -1))
	var last_pawn_tick: int = int(_last_ambition_tick_by_pawn.get(pawn_id, -1000000))
	if tick - last_pawn_tick < MATRIX_AMBITION_PAWN_COOLDOWN_TICKS:
		return {}
	var settlement_key: int = settlement_id if settlement_id >= 0 else _fallback_region_key(data.tile_pos)
	var last_settlement_tick: int = int(_last_ambition_tick_by_settlement.get(settlement_key, -1000000))
	if tick - last_settlement_tick < MATRIX_AMBITION_SETTLEMENT_COOLDOWN_TICKS:
		return {}
	var local_features: Dictionary = _scan_local_features(data.tile_pos, 12)
	var local_pop: int = _estimate_local_population(pawn)
	var beds: int = int(local_features.get("bed", 0))
	var hearths: int = int(local_features.get("hearth", 0))
	var storage_huts: int = int(local_features.get("storage_hut", 0))
	var walls: int = int(local_features.get("wall", 0))
	var doors: int = int(local_features.get("door", 0))
	var markers: int = int(local_features.get("marker", 0))
	var drive: String = str(profile.get("development_drive", "serve_settlement"))
	var next_need: String = str(profile.get("next_need", "serve local needs"))
	var loop_job: int = _worldbox_loop_job_for_pawn(data, local_pop, local_features, tick)

	var ambition: Dictionary = {}
	if loop_job >= 0:
		ambition = _ambition_result(loop_job, 6, "worldbox-loop: autonomous daily labor/defense cycle")
	elif hearths <= 0:
		ambition = _ambition_result(Job.Type.BUILD_FIRE_PIT, 9, "no hearth in local settlement core")
	elif storage_huts <= 0 and local_pop >= 3:
		ambition = _ambition_result(Job.Type.BUILD_STORAGE_HUT, 8, "storage is missing for current population")
	elif beds < maxi(2, int(round(local_pop / 2.2))):
		ambition = _ambition_result(Job.Type.BUILD_BED, 7, "household pressure requires more beds")
	elif (walls < 4 or doors <= 0) and local_pop >= 6:
		ambition = _ambition_result(Job.Type.BUILD_WALL if walls < 4 else Job.Type.BUILD_DOOR, 6, "settlement perimeter is underdeveloped")
	elif drive in ["preserve", "teach"] and markers <= 0:
		ambition = _ambition_result(Job.Type.BUILD_MARKER_STONE, 6, "memory anchor missing for preservation-focused population")
	elif drive == "survive":
		ambition = _ambition_result(Job.Type.GROW_FOOD, 7, "survival drive requests stronger food loop")
	elif drive == "innovate":
		ambition = _ambition_result(Job.Type.TOOL_MAKING, 6, "innovation drive requests production throughput")
	elif drive == "bond":
		ambition = _ambition_result(Job.Type.BUILD_HEARTH, 5, "bond drive requests social hearth space")
	elif next_need.find("teach") >= 0:
		ambition = _ambition_result(Job.Type.TEACH_SKILL, 5, "development need requests teaching continuity")

	if ambition.is_empty():
		return {}
	ambition["settlement_id"] = settlement_id
	ambition["settlement_key"] = settlement_key
	ambition["soul_id"] = str(profile.get("soul_id", ""))
	ambition["local_population"] = local_pop
	ambition["drive"] = drive
	ambition["next_need"] = next_need
	ambition["features"] = local_features

	_last_ambition_tick_by_pawn[pawn_id] = tick
	_last_ambition_tick_by_settlement[settlement_key] = tick
	return ambition


static func _worldbox_loop_job_for_pawn(
		data: PawnData,
		local_pop: int,
		local_features: Dictionary,
		tick: int
) -> int:
	var phase: int = posmod(tick / 90 + int(data.id) * 3, 8)
	var walls: int = int(local_features.get("wall", 0))
	var doors: int = int(local_features.get("door", 0))
	var hearths: int = int(local_features.get("hearth", 0))
	var storage_huts: int = int(local_features.get("storage_hut", 0))
	match phase:
		0:
			return Job.Type.FORAGE
		1:
			return Job.Type.PLANT_SEEDS
		2:
			return Job.Type.HARVEST_CROPS
		3:
			if hearths <= 0:
				return Job.Type.BUILD_FIRE_PIT
			return Job.Type.COOK_MEAT
		4:
			if storage_huts <= 0:
				return Job.Type.BUILD_STORAGE_HUT
			return Job.Type.CHOP
		5:
			if local_pop >= 6 and (walls < 4 or doors <= 0):
				return Job.Type.BUILD_WALL if walls < 4 else Job.Type.BUILD_DOOR
			return Job.Type.MINE
		6:
			if local_pop >= 7:
				return Job.Type.PROTECT
			return Job.Type.HUNT
		7:
			return Job.Type.TOOL_MAKING
	return -1


static func get_affiliation_action_for_pawn(pawn: Variant) -> Dictionary:
	var data: PawnData = _pawn_data(pawn)
	if data == null:
		return {}
	var tick: int = _tick()
	var pawn_id: int = int(data.id)
	var last_tick: int = int(_last_affiliation_tick_by_pawn.get(pawn_id, -1000000))
	if tick - last_tick < MATRIX_AFFILIATION_COOLDOWN_TICKS:
		return {}
	var profile: Dictionary = get_development_profile_for_pawn(pawn)
	if profile.is_empty():
		return {}
	var hs: Dictionary = profile.get("human_scale", {})
	var next_level: String = str(hs.get("next_level", "world"))
	var candidates: Array = _nearby_pawn_candidates(pawn, 40, 24)
	if candidates.is_empty():
		return {}

	if next_level == "family":
		for c in candidates:
			var pid: int = int(c.get("id", -1))
			if pid < 0:
				continue
			var trust: float = float(c.get("trust", 50.0))
			var rapport: float = float(c.get("rapport", 0.0))
			if trust < 60.0 and rapport < 450.0:
				continue
			var other_hid: int = int(c.get("household_id", -1))
			var chosen_hid: int = other_hid
			if chosen_hid < 0:
				chosen_hid = _deterministic_household_id(pawn_id, pid)
			_last_affiliation_tick_by_pawn[pawn_id] = tick
			return {
				"action": "join_household",
				"household_id": chosen_hid,
				"target_id": pid,
				"rationale": "family-level need; trust=%.1f rapport=%.1f" % [trust, rapport],
			}
	elif next_level == "clan":
		var clan_id: int = _deterministic_clan_id(data.settlement_id, data.household_id, pawn_id)
		_last_affiliation_tick_by_pawn[pawn_id] = tick
		return {
			"action": "join_clan",
			"clan_id": clan_id,
			"rationale": "clan-level need; household=%d settlement=%d" % [data.household_id, data.settlement_id],
		}
	elif next_level == "nation":
		var nation_id: int = _deterministic_nation_id(data.settlement_id, data.clan_id)
		_last_affiliation_tick_by_pawn[pawn_id] = tick
		return {
			"action": "join_nation",
			"nation_id": nation_id,
			"rationale": "nation-level need; clan=%d settlement=%d" % [data.clan_id, data.settlement_id],
		}
	return {}


static func _ambition_result(job_type: int, priority: int, reason: String) -> Dictionary:
	return {
		"job_type": int(job_type),
		"priority": priority,
		"reason": reason,
	}


static func _scan_local_features(center: Vector2i, radius: int) -> Dictionary:
	var out: Dictionary = {
		"bed": 0,
		"wall": 0,
		"door": 0,
		"hearth": 0,
		"storage_hut": 0,
		"marker": 0,
	}
	var main_node: Node = _root_node("Main")
	if main_node == null:
		return out
	var world_v: Variant = main_node.get("_world")
	if world_v == null:
		return out
	var world: World = world_v as World
	if world == null or world.data == null:
		return out
	var data: WorldData = world.data
	for y in range(center.y - radius, center.y + radius + 1):
		for x in range(center.x - radius, center.x + radius + 1):
			if not data.in_bounds(x, y):
				continue
			var feat: int = int(data.get_feature(x, y))
			match feat:
				TileFeature.Type.BED:
					out["bed"] = int(out["bed"]) + 1
				TileFeature.Type.WALL:
					out["wall"] = int(out["wall"]) + 1
				TileFeature.Type.DOOR:
					out["door"] = int(out["door"]) + 1
				TileFeature.Type.FIRE_PIT, TileFeature.Type.HEARTH:
					out["hearth"] = int(out["hearth"]) + 1
				TileFeature.Type.STORAGE_HUT:
					out["storage_hut"] = int(out["storage_hut"]) + 1
				TileFeature.Type.MARKER_STONE:
					out["marker"] = int(out["marker"]) + 1
	return out


static func _estimate_local_population(pawn: Variant) -> int:
	var cands: Array = _nearby_pawn_candidates(pawn, 96, 20)
	return maxi(1, cands.size() + 1)


static func _deterministic_household_id(a: int, b: int) -> int:
	var lo: int = mini(a, b)
	var hi: int = maxi(a, b)
	return int(abs(lo * 73856093 + hi * 19349663) % 100000)


static func _deterministic_clan_id(settlement_id: int, household_id: int, pawn_id: int) -> int:
	var s: int = settlement_id if settlement_id >= 0 else 0
	var h: int = household_id if household_id >= 0 else pawn_id
	return int(abs(s * 83492791 + h * 2654435761) % 100000)


static func _deterministic_nation_id(settlement_id: int, clan_id: int) -> int:
	var s: int = settlement_id if settlement_id >= 0 else 0
	var c: int = clan_id if clan_id >= 0 else 0
	return int(abs(s * 961748927 + c * 31) % 10000)


static func _fallback_region_key(tile: Vector2i) -> int:
	var wm: Node = _root_node("WorldMemory")
	if wm != null and wm.has_method("_region_key"):
		return int(wm.call("_region_key", tile.x, tile.y))
	return tile.x * 73856093 + tile.y * 19349663


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


static func _nearby_pawn_candidates(pawn: Variant, max_items: int, radius_tiles: int) -> Array:
	var out: Array = []
	var data: PawnData = _pawn_data(pawn)
	if data == null:
		return out
	var main_node: Node = _root_node("Main")
	if main_node == null:
		return out
	var spawner: Node = main_node.get_node_or_null("WorldViewport/PawnSpawner")
	if spawner == null:
		return out
	var pawns_v: Variant = spawner.get("pawns")
	if not (pawns_v is Array):
		return out
	var pawns: Array = pawns_v as Array
	var radius2: int = radius_tiles * radius_tiles
	for other in pawns:
		if other == null or not is_instance_valid(other) or other == pawn:
			continue
		var other_data: PawnData = _pawn_data(other)
		if other_data == null:
			continue
		var d2: int = data.tile_pos.distance_squared_to(other_data.tile_pos)
		if d2 > radius2:
			continue
		out.append({
			"id": int(other_data.id),
			"tile": other_data.tile_pos,
			"d2": d2,
			"rapport": float(data.get_social_rapport(int(other_data.id))),
			"trust": float(data.trust.get(int(other_data.id), 50.0)),
			"household_id": int(other_data.household_id),
			"settlement_id": int(other_data.settlement_id),
		})
		if out.size() >= max_items:
			break
	return out


static func _grudge_intensity(holder_id: int, target_id: int) -> float:
	var gm: Node = _root_node("GrudgeManager")
	if gm != null and gm.has_method("get_grudge_intensity"):
		return float(gm.call("get_grudge_intensity", holder_id, target_id))
	return 0.0


static func _reputation_for(pawn_id: int) -> float:
	var gossip: Node = _root_node("GossipManager")
	if gossip != null and gossip.has_method("get_reputation_for"):
		return float(gossip.call("get_reputation_for", pawn_id))
	return 0.0


static func _matrix_job_biases(profile: Dictionary, data: PawnData, identity: HeelKawnianIdentity) -> Dictionary:
	var biases: Dictionary = {}
	var drive: String = str(profile.get("development_drive", "serve_settlement"))
	match drive:
		"survive":
			_add_bias(biases, [Job.Type.FORAGE, Job.Type.HUNT, Job.Type.COOK_MEAT, Job.Type.COOK_BERRIES, Job.Type.DRY_MEAT, Job.Type.PLANT_SEEDS, Job.Type.HARVEST_CROPS, Job.Type.GROW_FOOD], 8)
			if data.hunger < 45.0:
				_add_bias(biases, [Job.Type.FORAGE, Job.Type.HUNT, Job.Type.HARVEST_CROPS, Job.Type.GROW_FOOD], 4)
			if data.rest < 45.0 or data.health < 55.0:
				_add_bias(biases, [Job.Type.BUILD_BED, Job.Type.BUILD_SHELTER, Job.Type.BUILD_HEARTH], 3)
		"recover":
			_add_bias(biases, [Job.Type.BUILD_BED, Job.Type.BUILD_SHELTER, Job.Type.BUILD_HEARTH, Job.Type.PROTECT, Job.Type.DEFEND, Job.Type.CARVE_GRAVE_MARKER], 7)
			_add_bias(biases, [Job.Type.HUNT, Job.Type.MINE, Job.Type.MINE_WALL], -2)
		"preserve":
			_add_bias(biases, [Job.Type.CARVE_KNOWLEDGE_STONE, Job.Type.CARVE_LEDGER_STONE, Job.Type.CARVE_GRAVE_MARKER, Job.Type.BUILD_MARKER_STONE, Job.Type.PAPER_MAKING, Job.Type.INK_MAKING, Job.Type.BOOK_BINDING, Job.Type.TEACH_SKILL], 8)
			_add_bias(biases, [Job.Type.BUILD_SHRINE, Job.Type.BUILD_HEARTH], 3)
		"learn":
			_add_bias(biases, [Job.Type.APPRENTICESHIP, Job.Type.TEACH_SKILL, Job.Type.GATHER_FLINT, Job.Type.GATHER_STICK, Job.Type.CRAFT_KNIFE, Job.Type.CRAFT_TORCH, Job.Type.CRAFT_PICK, Job.Type.CRAFT_SPEAR], 7)
			_add_skill_practice_bias(biases, profile, 2)
		"practice":
			_add_skill_practice_bias(biases, profile, 7)
			_add_profession_practice_bias(biases, int(data.current_profession), 3)
		"bond":
			_add_bias(biases, [Job.Type.TEACH_SKILL, Job.Type.APPRENTICESHIP, Job.Type.TRADE_HAUL, Job.Type.BUILD_HEARTH, Job.Type.COOK_MEAT, Job.Type.COOK_BERRIES], 6)
		"innovate":
			_add_bias(biases, [Job.Type.TOOL_MAKING, Job.Type.PAPER_MAKING, Job.Type.INK_MAKING, Job.Type.BOOK_BINDING, Job.Type.CRAFT_PICK, Job.Type.CRAFT_SPEAR, Job.Type.BUILD_STORAGE_HUT, Job.Type.BUILD_SHRINE], 8)
			_add_bias(biases, [Job.Type.CARVE_KNOWLEDGE_STONE, Job.Type.CARVE_LEDGER_STONE], 3)
		"teach":
			_add_bias(biases, [Job.Type.TEACH_SKILL, Job.Type.APPRENTICESHIP, Job.Type.CARVE_KNOWLEDGE_STONE, Job.Type.BUILD_HEARTH], 9)
		_:
			_add_bias(biases, [Job.Type.TRADE_HAUL, Job.Type.BUILD_STORAGE_HUT, Job.Type.BUILD_WALL, Job.Type.BUILD_DOOR], 3)
			_add_settlement_service_bias(biases, profile)
	_add_human_scale_biases(biases, profile, data)
	_add_identity_trait_biases(biases, identity)
	_clamp_biases(biases, -8, 16)
	return biases


static func _add_settlement_service_bias(biases: Dictionary, profile: Dictionary) -> void:
	var axes: Dictionary = profile.get("axes", {})
	if int(axes.get("survival", 100)) < 70:
		_add_bias(biases, [Job.Type.FORAGE, Job.Type.HUNT, Job.Type.GROW_FOOD, Job.Type.PLANT_SEEDS, Job.Type.HARVEST_CROPS], 4)
	if int(axes.get("innovation", 0)) >= 50:
		_add_bias(biases, [Job.Type.TOOL_MAKING, Job.Type.BUILD_STORAGE_HUT, Job.Type.BOOK_BINDING], 3)
	if int(axes.get("preservation", 0)) < 45:
		_add_bias(biases, [Job.Type.CARVE_LEDGER_STONE, Job.Type.CARVE_KNOWLEDGE_STONE], 3)


static func _add_human_scale_biases(biases: Dictionary, profile: Dictionary, data: PawnData) -> void:
	var hs: Dictionary = profile.get("human_scale", {})
	if hs.is_empty():
		return
	var next_level: String = str(hs.get("next_level", "world"))
	var family_score: int = int(hs.get("family", 0))
	var clan_score: int = int(hs.get("clan", 0))
	var nation_score: int = int(hs.get("nation", 0))
	var world_score: int = int(hs.get("world", 0))

	match next_level:
		"family":
			_add_bias(biases, [Job.Type.BUILD_BED, Job.Type.BUILD_HEARTH, Job.Type.COOK_MEAT, Job.Type.COOK_BERRIES, Job.Type.TEACH_SKILL], 6)
			if family_score < 25:
				_add_bias(biases, [Job.Type.BUILD_BED, Job.Type.BUILD_HEARTH], 3)
		"clan":
			_add_bias(biases, [Job.Type.BUILD_MARKER_STONE, Job.Type.BUILD_WALL, Job.Type.BUILD_DOOR, Job.Type.PROTECT, Job.Type.DEFEND], 6)
			if clan_score < 25:
				_add_bias(biases, [Job.Type.BUILD_MARKER_STONE, Job.Type.PROTECT], 3)
		"nation":
			_add_bias(biases, [Job.Type.PROTECT, Job.Type.DEFEND, Job.Type.TRADE_HAUL, Job.Type.BUILD_STORAGE_HUT, Job.Type.CARVE_LEDGER_STONE], 6)
			if nation_score < 25:
				_add_bias(biases, [Job.Type.PROTECT, Job.Type.DEFEND], 3)
		"world":
			_add_bias(biases, [Job.Type.TRADE_HAUL, Job.Type.TEACH_SKILL, Job.Type.APPRENTICESHIP, Job.Type.TOOL_MAKING, Job.Type.CARVE_KNOWLEDGE_STONE], 6)
			if world_score < 25:
				_add_bias(biases, [Job.Type.TRADE_HAUL, Job.Type.TEACH_SKILL], 3)
		_:
			pass

	# If belonging is under pressure, de-prioritize isolation-heavy jobs slightly.
	var belonging_pressure: int = int(round((100 - family_score + 100 - clan_score) / 2.0))
	if belonging_pressure >= 50 and data.current_profession != PawnData.Profession.WARRIOR:
		_add_bias(biases, [Job.Type.MINE, Job.Type.MINE_WALL], -1)


static func _add_skill_practice_bias(biases: Dictionary, profile: Dictionary, amount: int) -> void:
	var skills: Dictionary = profile.get("skills", {})
	var highest: String = str(skills.get("highest_skill", "")).to_lower()
	match highest:
		"foraging":
			_add_bias(biases, [Job.Type.FORAGE, Job.Type.GATHER_STICK, Job.Type.COOK_BERRIES, Job.Type.PLANT_SEEDS, Job.Type.HARVEST_CROPS, Job.Type.GROW_FOOD], amount)
		"mining":
			_add_bias(biases, [Job.Type.MINE, Job.Type.MINE_WALL, Job.Type.GATHER_FLINT, Job.Type.CRAFT_PICK], amount)
		"chopping":
			_add_bias(biases, [Job.Type.CHOP, Job.Type.CRAFT_TORCH, Job.Type.BUILD_FIRE_PIT], amount)
		"building":
			_add_bias(biases, [Job.Type.BUILD_BED, Job.Type.BUILD_WALL, Job.Type.BUILD_DOOR, Job.Type.BUILD_FIRE_PIT, Job.Type.BUILD_STORAGE_HUT, Job.Type.BUILD_SHELTER, Job.Type.BUILD_HEARTH, Job.Type.TOOL_MAKING], amount)
		"healing":
			_add_bias(biases, [Job.Type.COOK_BERRIES, Job.Type.BUILD_HEARTH, Job.Type.TEACH_SKILL], amount)
		"hunting":
			_add_bias(biases, [Job.Type.HUNT, Job.Type.CRAFT_SPEAR, Job.Type.PROTECT, Job.Type.DEFEND, Job.Type.DRY_MEAT, Job.Type.COOK_MEAT], amount)
		_:
			_add_bias(biases, [Job.Type.FORAGE, Job.Type.CHOP, Job.Type.BUILD_BED], maxi(1, amount / 2))


static func _add_profession_practice_bias(biases: Dictionary, profession: int, amount: int) -> void:
	match profession:
		PawnData.Profession.FARMER:
			_add_bias(biases, [Job.Type.FORAGE, Job.Type.PLANT_SEEDS, Job.Type.HARVEST_CROPS, Job.Type.GROW_FOOD, Job.Type.COOK_BERRIES], amount)
		PawnData.Profession.BUILDER:
			_add_bias(biases, [Job.Type.BUILD_BED, Job.Type.BUILD_WALL, Job.Type.BUILD_DOOR, Job.Type.BUILD_FIRE_PIT, Job.Type.BUILD_STORAGE_HUT, Job.Type.BUILD_SHELTER, Job.Type.BUILD_HEARTH], amount)
		PawnData.Profession.GATHERER:
			_add_bias(biases, [Job.Type.FORAGE, Job.Type.CHOP, Job.Type.GATHER_FLINT, Job.Type.GATHER_STICK], amount)
		PawnData.Profession.WARRIOR:
			_add_bias(biases, [Job.Type.HUNT, Job.Type.PROTECT, Job.Type.DEFEND, Job.Type.CRAFT_SPEAR], amount)
		PawnData.Profession.SCHOLAR:
			_add_bias(biases, [Job.Type.TEACH_SKILL, Job.Type.APPRENTICESHIP, Job.Type.CARVE_KNOWLEDGE_STONE, Job.Type.PAPER_MAKING, Job.Type.BOOK_BINDING], amount)
		PawnData.Profession.TRADER:
			_add_bias(biases, [Job.Type.TRADE_HAUL, Job.Type.CARVE_LEDGER_STONE], amount)
		PawnData.Profession.SMITH:
			_add_bias(biases, [Job.Type.TOOL_MAKING, Job.Type.CRAFT_KNIFE, Job.Type.CRAFT_PICK, Job.Type.CRAFT_SPEAR, Job.Type.MINE], amount)
		PawnData.Profession.HEALER:
			_add_bias(biases, [Job.Type.BUILD_HEARTH, Job.Type.COOK_BERRIES, Job.Type.TEACH_SKILL, Job.Type.APPRENTICESHIP], amount)


static func _add_identity_trait_biases(biases: Dictionary, identity: HeelKawnianIdentity) -> void:
	if identity == null:
		return
	var traits: Dictionary = identity.traits
	var curiosity: int = int(round(float(traits.get("curiosity", 0.0)) * 4.0))
	var knowledge_drive: int = int(round(float(traits.get("knowledge_drive", 0.0)) * 5.0))
	var preservation_drive: int = int(round(float(traits.get("preservation_drive", 0.0)) * 5.0))
	var labor_pride: int = int(round(float(traits.get("labor_pride", 0.0)) * 4.0))
	var caution: int = int(round(float(traits.get("caution", 0.0)) * 5.0))
	var mentor_drive: int = int(round(float(traits.get("mentor_drive", 0.0)) * 5.0))
	var social_memory: int = int(round(float(traits.get("social_memory", 0.0)) * 4.0))
	if curiosity > 0 or knowledge_drive > 0:
		_add_bias(biases, [Job.Type.APPRENTICESHIP, Job.Type.TEACH_SKILL, Job.Type.TOOL_MAKING, Job.Type.PAPER_MAKING, Job.Type.BOOK_BINDING], curiosity + knowledge_drive)
	if preservation_drive > 0:
		_add_bias(biases, [Job.Type.CARVE_KNOWLEDGE_STONE, Job.Type.CARVE_LEDGER_STONE, Job.Type.CARVE_GRAVE_MARKER], preservation_drive)
	if labor_pride > 0:
		_add_bias(biases, [Job.Type.BUILD_BED, Job.Type.BUILD_WALL, Job.Type.BUILD_DOOR, Job.Type.BUILD_STORAGE_HUT, Job.Type.CHOP, Job.Type.MINE], labor_pride)
	if caution > 0:
		_add_bias(biases, [Job.Type.BUILD_WALL, Job.Type.BUILD_DOOR, Job.Type.PROTECT, Job.Type.DEFEND, Job.Type.BUILD_SHELTER], caution)
		_add_bias(biases, [Job.Type.HUNT], -mini(3, caution))
	if mentor_drive > 0:
		_add_bias(biases, [Job.Type.TEACH_SKILL, Job.Type.APPRENTICESHIP], mentor_drive)
	if social_memory > 0:
		_add_bias(biases, [Job.Type.TRADE_HAUL, Job.Type.BUILD_HEARTH, Job.Type.COOK_MEAT, Job.Type.COOK_BERRIES], social_memory)


static func _add_bias(biases: Dictionary, job_types: Array, amount: int) -> void:
	for job_type in job_types:
		var key: int = int(job_type)
		biases[key] = int(biases.get(key, 0)) + amount


static func _clamp_biases(biases: Dictionary, low: int, high: int) -> void:
	for key in biases.keys():
		biases[key] = clampi(int(biases[key]), low, high)


static func _top_matrix_jobs(biases: Dictionary, max_items: int) -> Array[Dictionary]:
	var top: Array[Dictionary] = []
	for key in biases.keys():
		var bias: int = int(biases[key])
		if bias <= 0:
			continue
		top.append({
			"job_type": int(key),
			"job_name": Job.describe_type(int(key)),
			"bias": bias,
		})
	top.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ab: int = int(a.get("bias", 0))
		var bb: int = int(b.get("bias", 0))
		if ab == bb:
			return int(a.get("job_type", 0)) < int(b.get("job_type", 0))
		return ab > bb
	)
	if top.size() > max_items:
		top.resize(max_items)
	return top


static func _matrix_rationale(profile: Dictionary, top_jobs: Array[Dictionary]) -> String:
	var drive: String = str(profile.get("development_drive", "serve_settlement"))
	var need: String = str(profile.get("next_need", "serve local needs"))
	var phase: String = str(profile.get("development_phase", "unknown"))
	var jobs: Array[String] = []
	for item in top_jobs:
		if jobs.size() >= 3:
			break
		jobs.append("%s+%d" % [str(item.get("job_name", "Job")), int(item.get("bias", 0))])
	var job_line: String = ", ".join(jobs) if not jobs.is_empty() else "no strong job bias"
	return "%s phase is driven to %s; next need: %s; Matrix favors %s." % [phase, drive, need, job_line]


static func _matrix_inputs_snapshot(profile: Dictionary) -> Dictionary:
	return {
		"drive": str(profile.get("development_drive", "")),
		"phase": str(profile.get("development_phase", "")),
		"next_need": str(profile.get("next_need", "")),
		"era": str(profile.get("era", "")),
		"development_score": int(profile.get("development_score", 0)),
		"axes": profile.get("axes", {}).duplicate(true),
		"skills": profile.get("skills", {}).duplicate(true),
		"identity_traits": profile.get("identity_traits", {}).duplicate(true),
		"known_knowledge_count": int(profile.get("known_knowledge_count", 0)),
		"recent_event_count": int(profile.get("recent_event_count", 0)),
	}


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
	var human_scale: Dictionary = _human_scale_levels(data)
	var human_next: String = str(human_scale.get("next_level", "world"))
	if int(axes.get("survival", 0)) < 45:
		return "survive"
	if int(axes.get("trauma_pressure", 0)) >= 30:
		return "recover"
	if human_next == "family":
		return "bond"
	if human_next == "clan":
		return "teach"
	if human_next == "nation":
		return "serve_settlement"
	if human_next == "world":
		return "innovate"
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


static func _human_scale_levels(data: PawnData) -> Dictionary:
	# Human ladder: individual -> family -> clan -> nation -> world
	var family_score: int = 0
	family_score += mini(30, data.family_bonds.size() * 8)
	family_score += mini(20, data.children_ids.size() * 10)
	if int(data.spouse_id) >= 0:
		family_score += 18
	if int(data.household_id) >= 0:
		family_score += 22
	family_score = clampi(family_score, 0, 100)

	var clan_score: int = 0
	if int(data.clan_id) >= 0:
		clan_score += 30
	clan_score += mini(25, int(round(data.clan_influence / 4.0)))
	clan_score += mini(25, data.clan_reputation.size() * 5)
	clan_score += mini(20, int(data.reputation_score / 5.0))
	clan_score = clampi(clan_score, 0, 100)

	var nation_score: int = 0
	if int(data.nation_id) >= 0:
		nation_score += 35
	nation_score += mini(20, data.law_compliance.size() * 3)
	nation_score += mini(20, int(data.national_citizenship) * 8)
	nation_score += mini(25, int(round(data.military_service_years * 1.5)))
	nation_score = clampi(nation_score, 0, 100)

	var world_score: int = 0
	world_score += mini(30, data.cross_region_influence.size() * 5)
	world_score += mini(25, data.trade_relationships.size() * 5)
	world_score += mini(20, data.world_events_witnessed.size() * 3)
	world_score += mini(25, int(round(data.legacy_score / 4.0)))
	world_score = clampi(world_score, 0, 100)

	var next_level: String = "world"
	if family_score < 40:
		next_level = "family"
	elif clan_score < 40:
		next_level = "clan"
	elif nation_score < 40:
		next_level = "nation"
	elif world_score < 40:
		next_level = "world"
	else:
		next_level = "world_complete"

	return {
		"individual": 100,
		"family": family_score,
		"clan": clan_score,
		"nation": nation_score,
		"world": world_score,
		"next_level": next_level,
	}


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
