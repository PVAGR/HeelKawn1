## HeelKawnianDecision — Extracted decision engine from HeelKawnian.gd
##
## Encapsulates all idle decision logic: utility scoring, goal caching,
## bias stacking, neural priority, matrix bias, resource pressure,
## settlement pressure, role affinity, danger level, memory confidence,
## short-horizon failure tracking, and awareness scanning.
##
## This is a RefCounted helper — it does NOT live on the scene tree.
## HeelKawnian.gd creates one and delegates decision computations to it.
##
## Architecture: HeelKawnian.gd owns the state machine and actions.
## HeelKawnianDecision.gd owns the reasoning. The pawn asks "what should
## I prioritize?" and the decision engine returns a bias/score.
class_name HeelKawnianDecision
extends RefCounted

## --- Constants (mirrored from HeelKawnian.gd for self-containment) ---
const UTILITY_SCORE_NORMALIZER: float = 100.0
const AWARENESS_SCAN_RADIUS: int = 6
const AWARENESS_REFRESH_INTERVAL: int = 40
const DREAM_NUDGE_CHECK_EVERY_TICKS: int = 600

## --- Internal caches ---
var _cached_utility_context: Dictionary = {}
var _cached_utility_context_tick: int = -1
var _cached_utility_food_emergency: bool = false

var _parity_context: Dictionary = {}
var _parity_context_tick: int = -1

var _cached_idle_action: String = "work"
var _cached_idle_action_food_emergency: bool = false

var _learning_weight_cache: Dictionary = {}
var _learning_weight_cache_tick: int = -1

var _next_goal_refresh_tick: int = -1
var _cached_active_goal: Dictionary = {}
var _cached_active_goal_priority: float = 0.0

var _awareness: Dictionary = {}
var _awareness_tick: int = -999999

var _neural_priority_fetch_tick: int = -1
var _neural_priority_outputs: Array = []
var _neural_priority_next_refresh_tick: int = -1

var _matrix_priority_fetch_tick: int = -1
var _matrix_priority_decision: Dictionary = {}
var _matrix_priority_next_refresh_tick: int = -1

var _last_neural_decision_log_tick: int = -1000000

var _last_dream_nudge_check_tick: int = -DREAM_NUDGE_CHECK_EVERY_TICKS

## --- Speed-scaled intervals ---
func _goal_refresh_interval_for_speed() -> int:
	return 60


func _neural_priority_refresh_interval_for_speed() -> int:
	return 15


func _matrix_priority_refresh_interval_for_speed() -> int:
	return 15


## --- Parity context (NPC/player parity) ---

func parity_idle_context(data: HeelKawnianData) -> Dictionary:
	var t: int = GameManager.tick_count if GameManager != null else 0
	if _parity_context_tick == t and not _parity_context.is_empty():
		return _parity_context
	_parity_context_tick = t
	_parity_context = {}
	if data != null and WorldAI != null and WorldAI.has_method("build_idle_parity_context_for_pawn"):
		_parity_context = WorldAI.build_idle_parity_context_for_pawn(int(data.id))
	return _parity_context


## --- Utility context builder ---
func build_idle_utility_context(data: HeelKawnianData, food_emergency: bool) -> Dictionary:
	var t: int = GameManager.tick_count if GameManager != null else 0
	if t == _cached_utility_context_tick and food_emergency == _cached_utility_food_emergency and not _cached_utility_context.is_empty():
		return _cached_utility_context
	var weather: String = "clear"
	if WorldAI != null and WorldAI.has_method("get_weather_tag_for_sim"):
		weather = WorldAI.get_weather_tag_for_sim()
	var pc: Dictionary = parity_idle_context(data)
	var parity_utility: Dictionary = {}
	if pc.has("utility_bias") and pc["utility_bias"] is Dictionary:
		parity_utility = pc["utility_bias"] as Dictionary
	if pc.has("weather"):
		weather = str(pc["weather"])
	_cached_utility_context = {
		"is_night": DayNightCycle.is_night_for_tick(t),
		"food_emergency": food_emergency,
		"weather": weather,
		"parity_utility": parity_utility,
		"tick": t,
	}
	_cached_utility_context_tick = t
	_cached_utility_food_emergency = food_emergency
	return _cached_utility_context


## --- Learning weight cache ---
func refresh_learning_weight_cache(data: HeelKawnianData) -> void:
	if data == null:
		return
	var t: int = GameManager.tick_count if GameManager != null else 0
	if t == _learning_weight_cache_tick and not _learning_weight_cache.is_empty():
		return
	_learning_weight_cache_tick = t
	_learning_weight_cache = {
		"food_production": data.calculate_action_utility("food_production", {}),
		"resource_gathering": data.calculate_action_utility("resource_gathering", {}),
		"defense_building": data.calculate_action_utility("defense_building", {}),
		"military_training": data.calculate_action_utility("military_training", {}),
		"construction": data.calculate_action_utility("construction", {}),
	}


## --- Goal cache ---
func refresh_active_goal_cache(data: HeelKawnianData) -> void:
	if data == null:
		return
	var t: int = GameManager.tick_count if GameManager != null else 0
	if _next_goal_refresh_tick >= 0 and t < _next_goal_refresh_tick:
		return
	data.cleanup_goals()
	data.generate_goals_from_needs()
	_cached_active_goal = data.get_highest_priority_goal()
	_cached_active_goal_priority = float(_cached_active_goal.get("priority", 0.0)) if not _cached_active_goal.is_empty() else 0.0
	_next_goal_refresh_tick = t + _goal_refresh_interval_for_speed()


func goal_priority_bias_for_job(job_type: int) -> int:
	if _cached_active_goal.is_empty():
		return 0
	var goal_type: String = str(_cached_active_goal.get("type", ""))
	if goal_type.is_empty():
		return 0
	var p: float = clampf(_cached_active_goal_priority, 0.0, 3.0)
	var p_bias: int = int(round(p * 2.0))
	var _Job = load("res://scripts/jobs/Job.gd")
	match goal_type:
		"find_food":
			if job_type in [
				_Job.Type.FORAGE, _Job.Type.HUNT, _Job.Type.FISH,
				_Job.Type.COOK_MEAT, _Job.Type.COOK_BERRIES, _Job.Type.COOK_FISH,
				_Job.Type.DRY_MEAT, _Job.Type.PLANT_SEEDS, _Job.Type.HARVEST_CROPS,
				_Job.Type.GROW_FOOD,
			]:
				return p_bias
		"find_shelter":
			if job_type in [
				_Job.Type.BUILD_BED, _Job.Type.BUILD_WALL, _Job.Type.BUILD_DOOR,
				_Job.Type.BUILD_SHELTER, _Job.Type.BUILD_HEARTH,
				_Job.Type.BUILD_FIRE_PIT, _Job.Type.BUILD_STORAGE_HUT,
			]:
				return p_bias
		"find_warmth":
			if job_type in [
				_Job.Type.BUILD_FIRE_PIT, _Job.Type.BUILD_HEARTH,
				_Job.Type.BUILD_SHELTER, _Job.Type.BUILD_BED,
			]:
				return p_bias
		"build":
			if job_type in [
				_Job.Type.BUILD_BED, _Job.Type.BUILD_WALL, _Job.Type.BUILD_DOOR,
				_Job.Type.BUILD_SHELTER, _Job.Type.BUILD_HEARTH,
				_Job.Type.BUILD_FIRE_PIT, _Job.Type.BUILD_STORAGE_HUT,
				_Job.Type.BUILD_MARKER_STONE, _Job.Type.BUILD_SHRINE,
			]:
				return p_bias
		"rest":
			if job_type == _Job.Type.FORAGE or job_type == _Job.Type.FISH:
				return -p_bias  # Rest goal penalizes food work slightly
		"improve_safety":
			if job_type in [_Job.Type.PROTECT, _Job.Type.DEFEND, _Job.Type.BUILD_WALL, _Job.Type.BUILD_DOOR, _Job.Type.HUNT]:
				return p_bias
		"build_reputation", "seek_leadership":
			if job_type in [_Job.Type.TEACH_SKILL, _Job.Type.APPRENTICESHIP, _Job.Type.CARVE_KNOWLEDGE_STONE, _Job.Type.BUILD_SHRINE]:
				return p_bias
		"master_skill":
			return p_bias
		"leave_legacy":
			if job_type in [_Job.Type.BUILD_SHRINE, _Job.Type.CARVE_KNOWLEDGE_STONE, _Job.Type.CARVE_LEDGER_STONE, _Job.Type.CARVE_GRAVE_MARKER]:
				return p_bias + 2
	return 0


func _is_profession_job(job_type: int, prof: int) -> bool:
	var _JD = HeelKawnianData
	var _Job = load("res://scripts/jobs/Job.gd")
	match prof:
		_JD.Profession.FARMER: return job_type in [_Job.Type.PLANT_SEEDS, _Job.Type.HARVEST_CROPS, _Job.Type.GROW_FOOD]
		_JD.Profession.BUILDER: return job_type in [_Job.Type.BUILD_BED, _Job.Type.BUILD_WALL, _Job.Type.BUILD_DOOR, _Job.Type.BUILD_SHELTER]
		_JD.Profession.GATHERER: return job_type in [_Job.Type.FORAGE, _Job.Type.CHOP, _Job.Type.GATHER_FLINT, _Job.Type.GATHER_STICK]
		_JD.Profession.WARRIOR: return job_type in [_Job.Type.HUNT, _Job.Type.PROTECT, _Job.Type.DEFEND]
		_JD.Profession.SCHOLAR: return job_type in [_Job.Type.TEACH_SKILL, _Job.Type.APPRENTICESHIP, _Job.Type.CARVE_KNOWLEDGE_STONE]
	return false


## --- Short-horizon bias (recent success/failure) ---
func short_horizon_bias_for_job(data: HeelKawnianData, job: Job) -> int:
	if data == null or job == null:
		return 0
	var recent: Dictionary = data.get_recent_job_outcomes(10)
	if recent.is_empty():
		return 0
	var success_count: int = 0
	var fail_count: int = 0
	for outcome in recent:
		var otype: int = int(outcome.get("job_type", -1))
		if otype == job.type:
			if outcome.get("success", false):
				success_count += 1
			else:
				fail_count += 1
	if fail_count > success_count + 2:
		return -3  # Avoid repeating failures
	if success_count > 2:
		return 2  # Lean into what works
	return 0


## --- Social influence bias ---
func apply_social_influence_bias(data: HeelKawnianData, job: Job, base_bias: int) -> int:
	if data == null or job == null:
		return base_bias
	# Squad/cohort members bias toward same job type
	if data.current_squad_id >= 0:
		var squad: Dictionary = SocialManager.get_squad_data(data.current_squad_id) if SocialManager != null else {}
		if not squad.is_empty():
			var squad_job_type: int = int(squad.get("active_job_type", -1))
			if squad_job_type == job.type:
				return base_bias + 3
	return base_bias


## --- Learning weight for job type ---
func learning_weight_for_job(job_type: int) -> float:
	var _Job = load("res://scripts/jobs/Job.gd")
	match job_type:
		_Job.Type.FORAGE, _Job.Type.HUNT, _Job.Type.FISH, \
		_Job.Type.COOK_MEAT, _Job.Type.COOK_BERRIES, _Job.Type.COOK_FISH, \
		_Job.Type.DRY_MEAT, _Job.Type.PLANT_SEEDS, _Job.Type.HARVEST_CROPS, \
		_Job.Type.GROW_FOOD:
			return float(_learning_weight_cache.get("food_production", 1.0))
		_Job.Type.CHOP, _Job.Type.MINE, _Job.Type.MINE_WALL, \
		_Job.Type.GATHER_FLINT, _Job.Type.GATHER_STICK:
			return float(_learning_weight_cache.get("resource_gathering", 1.0))
		_Job.Type.BUILD_WALL, _Job.Type.BUILD_DOOR, _Job.Type.BUILD_WATCHTOWER, \
		_Job.Type.BUILD_BARRACKS, _Job.Type.BUILD_FORD:
			return float(_learning_weight_cache.get("defense_building", 1.0))
		_Job.Type.DEFEND, _Job.Type.PROTECT, _Job.Type.GUARD:
			return float(_learning_weight_cache.get("military_training", 1.0))
		_:
			# Check if it's a structure build job via BuildingRegistry
			if BuildingRegistry != null and BuildingRegistry.has_method("get_building_for_job_type"):
				var entry = BuildingRegistry.get_building_for_job_type(job_type)
				if entry != null and not entry.is_empty():
					return float(_learning_weight_cache.get("construction", 1.0))
	return 1.0


## --- Settlement pressure ---
func idle_settlement_pressure(data: HeelKawnianData) -> float:
	if data == null:
		return 0.5
	var rk: int = _region_key(data.tile_pos.x, data.tile_pos.y)
	var center_region: int = SettlementMemory.get_center_region_for_region(rk)
	if center_region < 0:
		return 0.5
	var intent_mem: Node = MemoryManager.get_intent_memory()
	if intent_mem == null:
		return 0.5
	return clampf(float(intent_mem.settlement_pressure.get(center_region, 0.5)), 0.0, 1.0)


## --- Role affinity ---
func idle_role_affinity(data: HeelKawnianData) -> float:
	if data == null:
		return 0.5
	var affinity_key: String = data.highest_affinity_skill()
	return clampf(float(data.affinities.get(affinity_key, 0.5)), 0.0, 1.0)


## --- Memory confidence ---
func idle_memory_confidence(data: HeelKawnianData) -> float:
	if data == null:
		return 0.5
	var keys: Array[String] = [
		"action_success:work",
		"action_success:forage",
		"action_success:hunt",
		"action_success:build",
		"action_success:trade",
		"action_success:teach",
	]
	var total: float = 0.0
	var count: int = 0
	for key in keys:
		var fact: Dictionary = data.recall_semantic_fact(key)
		if fact.is_empty():
			continue
		total += clampf(float(fact.get("confidence", 0.5)), 0.0, 1.0)
		count += 1
	if count <= 0:
		return 0.5
	return total / float(count)


## --- Danger level ---
func idle_danger_level(data: HeelKawnianData, scar_level_at_tile: Callable) -> float:
	if data == null:
		return 0.0
	var scar_danger: float = clampf(float(scar_level_at_tile.call(data.tile_pos)) / 3.0, 0.0, 1.0)
	var tile_key: String = "%d,%d" % [data.tile_pos.x, data.tile_pos.y]
	var memory_danger: float = 0.0
	if data.location_memory.has(tile_key):
		var mem: Dictionary = data.location_memory[tile_key]
		memory_danger = clampf(float(mem.get("danger_level", 0.0)), 0.0, 1.0)
	return maxf(scar_danger, memory_danger)


## --- Awareness scan ---
func refresh_awareness(data: HeelKawnianData, world: Node) -> Dictionary:
	var tick: int = GameManager.tick_count if GameManager != null else 0
	if tick - _awareness_tick < AWARENESS_REFRESH_INTERVAL and not _awareness.is_empty():
		return _awareness
	_awareness_tick = tick
	var result: Dictionary = {
		"nearest_threat": Vector2i(-9999, -9999),
		"nearest_food_source": Vector2i(-9999, -9999),
		"nearest_shelter": Vector2i(-9999, -9999),
		"nearest_fire": Vector2i(-9999, -9999),
		"has_fire_nearby": false,
		"has_bed_nearby": false,
		"pawns_nearby_count": 0,
		"is_in_danger_zone": false,
	}
	if data == null or world == null or world.data == null:
		_awareness = result
		return result
	var px: int = data.tile_pos.x
	var py: int = data.tile_pos.y
	var r: int = AWARENESS_SCAN_RADIUS
	var best_threat_dist: int = 9999
	var best_food_dist: int = 9999
	var best_shelter_dist: int = 9999
	var best_fire_dist: int = 9999
	for dx in range(-r, r + 1):
		for dy in range(-r, r + 1):
			var tx: int = px + dx
			var ty: int = py + dy
			if tx < 0 or ty < 0 or tx >= WorldData.WIDTH or ty >= WorldData.HEIGHT:
				continue
			var dist: int = absi(dx) + absi(dy)
			if dist == 0:
				continue
			var tile: Vector2i = Vector2i(tx, ty)
			var feat: int = world.data.get_feature(tx, ty)
			if feat == TileFeature.Type.FIRE_PIT:
				if dist < best_fire_dist:
					best_fire_dist = dist
					result.nearest_fire = tile
				if dist <= 3:
					result.has_fire_nearby = true
			if feat == TileFeature.Type.BED:
				if dist < best_shelter_dist:
					best_shelter_dist = dist
					result.nearest_shelter = tile
				if dist <= 3:
					result.has_bed_nearby = true
			if feat == TileFeature.Type.FERTILE_SOIL:
				if dist < best_food_dist:
					best_food_dist = dist
					result.nearest_food_source = tile
			if feat == TileFeature.Type.WALL or feat == TileFeature.Type.DOOR:
				if dist < best_shelter_dist:
					best_shelter_dist = dist
					result.nearest_shelter = tile
			if TileFeature.is_wildlife(feat):
				if dist < best_threat_dist:
					best_threat_dist = dist
					result.nearest_threat = tile
	# Check scar level for danger zone
	if WorldPersistence != null and WorldPersistence.has_method("get_region_scar_level"):
		var rk: int = _region_key(px, py)
		var scar: int = WorldPersistence.get_region_scar_level(rk)
		if scar >= 2:
			result.is_in_danger_zone = true
	_awareness = result
	return result


## --- Utility action mapping ---
func utility_action_for_job(job_type: int) -> String:
	var _Job = load("res://scripts/jobs/Job.gd")
	match job_type:
		_Job.Type.FORAGE:
			return "forage"
		_Job.Type.HUNT:
			return "hunt"
		_Job.Type.FISH:
			return "forage"
		_Job.Type.CHOP:
			return "gather"
		_Job.Type.MINE, _Job.Type.MINE_WALL:
			return "mine"
		_Job.Type.BUILD_BED, _Job.Type.BUILD_WALL, _Job.Type.BUILD_DOOR, _Job.Type.BUILD_SHELTER, _Job.Type.BUILD_HEARTH, _Job.Type.BUILD_FIRE_PIT, _Job.Type.BUILD_STORAGE_HUT, _Job.Type.BUILD_MARKER_STONE, _Job.Type.BUILD_SHRINE:
			return "build"
		_Job.Type.TRADE_HAUL:
			return "trade"
		_:
			return "work"


## --- Utility score normalization ---
func utility_score_normalized(data: HeelKawnianData, action_type: String, context: Dictionary, cache: Dictionary = {}) -> float:
	if data == null:
		return 0.5
	if cache.has(action_type):
		return float(cache[action_type])
	var raw_score: float = data.calculate_action_utility(action_type, context)
	var normalized: float = clampf(raw_score / UTILITY_SCORE_NORMALIZER, 0.0, 1.0)
	cache[action_type] = normalized
	return normalized


## --- Job-affinity matching ---
func job_matches_affinity(job_type: int, affinity_key: String) -> bool:
	var _Job = load("res://scripts/jobs/Job.gd")
	match affinity_key:
		"building":
			return job_type == _Job.Type.BUILD_BED or job_type == _Job.Type.BUILD_WALL or job_type == _Job.Type.BUILD_DOOR
		"farming":
			return job_type == _Job.Type.FORAGE or job_type == _Job.Type.CHOP
		"combat":
			return job_type == _Job.Type.HUNT
		"crafting":
			return job_type == _Job.Type.CHOP or job_type == _Job.Type.MINE or job_type == _Job.Type.MINE_WALL
		"diplomacy":
			return job_type == _Job.Type.TRADE_HAUL
		"gathering":
			return job_type == _Job.Type.FORAGE or job_type == _Job.Type.CHOP or job_type == _Job.Type.MINE
		"construction":
			return job_type == _Job.Type.BUILD_BED or job_type == _Job.Type.BUILD_WALL or job_type == _Job.Type.BUILD_DOOR or job_type == _Job.Type.BUILD_FIRE_PIT or job_type == _Job.Type.BUILD_STORAGE_HUT or job_type == _Job.Type.BUILD_SHELTER or job_type == _Job.Type.BUILD_HEARTH or job_type == _Job.Type.MINE_WALL
		_:
			return false


## --- Settlement intent job multiplier ---
func get_settlement_intent_job_multiplier(data: HeelKawnianData, job: Job) -> float:
	if data == null or job == null:
		return 1.0
	var intent: String = SettlementMemory.get_settlement_intent_for_tile(data.tile_pos)
	var _Job = load("res://scripts/jobs/Job.gd")
	match intent:
		SettlementMemory.INTENT_HOARD:
			if job.type == _Job.Type.FORAGE or job.type == _Job.Type.HUNT or job.type == _Job.Type.FISH or job.type == _Job.Type.TRADE_HAUL:
				return 1.2
			if job.type == _Job.Type.CHOP or job.type == _Job.Type.MINE or job.type == _Job.Type.MINE_WALL:
				return 1.05
		SettlementMemory.INTENT_DEFEND:
			if job.type == _Job.Type.HUNT:
				return 1.2
			if job.type == _Job.Type.BUILD_WALL or job.type == _Job.Type.BUILD_DOOR:
				return 1.1
		SettlementMemory.INTENT_RECOVER:
			if job.type == _Job.Type.BUILD_BED or job.type == _Job.Type.BUILD_WALL or job.type == _Job.Type.BUILD_DOOR or job.type == _Job.Type.BUILD_FIRE_PIT or job.type == _Job.Type.BUILD_SHELTER or job.type == _Job.Type.BUILD_HEARTH:
				return 1.15
			if job.type == _Job.Type.TRADE_HAUL:
				return 1.1
		SettlementMemory.INTENT_GROW:
			if job.type == _Job.Type.FORAGE or job.type == _Job.Type.CHOP:
				return 1.05
	return 1.0


## --- Preferred front bias ---
func get_preferred_front_bias(data: HeelKawnianData, job: Job) -> float:
	if data == null or job == null:
		return 1.0
	return float(SettlementMemory.get_preferred_front_bias_for_job(data.tile_pos, job))


## --- Neural job priority bias ---
func get_neural_job_priority_bias(pawn: Node, data: HeelKawnianData, job_type: int) -> int:
	if data == null:
		return 0
	if GameManager != null:
		if GameManager.tick_count < 1200:
			return 0
		pass
	var tick: int = GameManager.tick_count if GameManager != null else -1
	var should_refresh: bool = (_neural_priority_next_refresh_tick < 0 or tick >= _neural_priority_next_refresh_tick)
	if should_refresh:
		_neural_priority_fetch_tick = tick
		var refreshed_outputs: Array = []
		var world_ai: Node = pawn.get_node_or_null("/root/WorldAI") if pawn != null else null
		if world_ai != null and world_ai.has_method("get_pawn_neural_state"):
			var neural_state: Dictionary = world_ai.get_pawn_neural_state(int(data.id))
			if not neural_state.is_empty():
				var outs: Variant = neural_state.get("outputs", [])
				if outs is Array and (outs as Array).size() >= 8:
					refreshed_outputs = outs as Array
		if refreshed_outputs.size() >= 8:
			_neural_priority_outputs = refreshed_outputs
			_neural_priority_next_refresh_tick = tick + _neural_priority_refresh_interval_for_speed()
		else:
			_neural_priority_next_refresh_tick = tick + 10

	if _neural_priority_outputs.size() < 8:
		return 0
	var outputs: Array = _neural_priority_outputs
	var _Job = load("res://scripts/jobs/Job.gd")
	var neural_bias: int = 0

	match job_type:
		_Job.Type.FORAGE:
			neural_bias = int((outputs[0] + outputs[3]) * 6.0)
		_Job.Type.HUNT:
			neural_bias = int((outputs[0] + outputs[3] + outputs[6]) * 5.0)
		_Job.Type.FISH:
			neural_bias = int((outputs[0] + outputs[3]) * 5.0)
		_Job.Type.CHOP:
			neural_bias = int(outputs[3] * 4.0)
		_Job.Type.MINE, _Job.Type.MINE_WALL:
			neural_bias = int(outputs[5] * 4.0)
		_Job.Type.BUILD_BED, _Job.Type.BUILD_WALL, _Job.Type.BUILD_DOOR, _Job.Type.BUILD_FIRE_PIT, _Job.Type.BUILD_STORAGE_HUT, _Job.Type.BUILD_SHELTER, _Job.Type.BUILD_HEARTH, _Job.Type.BUILD_MARKER_STONE, _Job.Type.BUILD_SHRINE:
			neural_bias = int(outputs[4] * 5.0)
		_Job.Type.TRADE_HAUL:
			neural_bias = int((outputs[2] + outputs[3]) * 3.0)
		_:
			neural_bias = 0

	if neural_bias >= 4 and _should_log_neural_decision_tick(tick):
		_log_neural_decision(data, job_type, neural_bias, outputs)

	return neural_bias


## --- Matrix job bias ---
func get_heelkawnian_matrix_job_bias(pawn: Node, data: HeelKawnianData, job_type: int) -> int:
	if data == null:
		return 0
	if GameManager != null:
		if GameManager.tick_count < 300:
			return 0
		pass
	var tick: int = GameManager.tick_count if GameManager != null else -1
	if _matrix_priority_next_refresh_tick < 0 or tick >= _matrix_priority_next_refresh_tick:
		_matrix_priority_fetch_tick = tick
		if HeelKawnianManager != null and HeelKawnianManager.has_method("get_matrix_decision_for_pawn"):
			_matrix_priority_decision = HeelKawnianManager.get_matrix_decision_for_pawn(pawn)
		else:
			_matrix_priority_decision = {}
		_matrix_priority_next_refresh_tick = tick + _matrix_priority_refresh_interval_for_speed()
	if _matrix_priority_decision.is_empty():
		return 0
	var biases: Dictionary = _matrix_priority_decision.get("job_biases", {})
	return clampi(int(biases.get(int(job_type), 0)), -8, 16)


## --- Resource pressure bias ---
func get_resource_pressure_bias(data: HeelKawnianData, job: Job) -> float:
	if data == null or job == null:
		return 1.0
	var rp: Dictionary = SettlementMemory.get_resource_pressure_for_tile(data.tile_pos)
	if rp.is_empty():
		return 1.0
	var wood_p: float = clampf(float(rp.get("wood", 0.0)), 0.0, 1.0)
	var stone_p: float = clampf(float(rp.get("stone", 0.0)), 0.0, 1.0)
	var ore_p: float = clampf(float(rp.get("ore_proxy", 0.0)), 0.0, 1.0)
	var food_p: float = clampf(float(rp.get("food", 0.0)), 0.0, 1.0)
	var trade_p: float = clampf(float(rp.get("trade", 0.0)), 0.0, 1.0)
	if wood_p > 0.9 or stone_p > 0.9 or ore_p > 0.9 or food_p > 0.9 or trade_p > 0.9:
		return 1.0
	var _Job = load("res://scripts/jobs/Job.gd")
	var intensity: float = 0.0
	match int(job.type):
		_Job.Type.CHOP, _Job.Type.BUILD_BED, _Job.Type.BUILD_WALL, _Job.Type.BUILD_DOOR, _Job.Type.BUILD_FIRE_PIT, _Job.Type.BUILD_STORAGE_HUT, _Job.Type.BUILD_SHELTER, _Job.Type.BUILD_HEARTH, _Job.Type.BUILD_SHRINE:
			intensity = wood_p
		_Job.Type.MINE_WALL:
			intensity = stone_p
		_Job.Type.MINE:
			intensity = ore_p
		_Job.Type.FORAGE, _Job.Type.HUNT, _Job.Type.FISH:
			intensity = food_p
		_Job.Type.TRADE_HAUL:
			intensity = trade_p
		_:
			intensity = 0.0
	if intensity <= 0.0:
		return 1.0
	# Amplify: high pressure = higher priority (1.0 → 1.5)
	return 1.0 + intensity * 0.5


## --- Neural decision logging ---
func _should_log_neural_decision_tick(tick: int) -> bool:
	if GameManager == null or not GameManager.verbose_logs():
		return false
	if tick - _last_neural_decision_log_tick < 120:
		return false
	_last_neural_decision_log_tick = tick
	return true


func _log_neural_decision(data: HeelKawnianData, job_type: int, bias: int, outputs: Array) -> void:
	if WorldMemory == null:
		return
	var _Job = load("res://scripts/jobs/Job.gd")
	var job_name: String = _Job.Type.keys()[job_type] if job_type >= 0 and job_type < _Job.Type.size() else "Unknown"
	WorldMemory.record_event({
		"type": "neural_decision",
		"pawn_id": int(data.id) if data != null else -1,
		"pawn_name": data.display_name if data != null else "Unknown",
		"job_type": job_type,
		"job_name": job_name,
		"neural_bias": bias,
		"neural_outputs": str(outputs),
		"tick": GameManager.tick_count
	})


## --- Region key helper (mirrors WorldPersistence._region_key) ---
static func _region_key(tx: int, ty: int) -> int:
	var rx: int = tx >> 4
	var ry: int = ty >> 4
	return (rx & 0xFFFF) | ((ry & 0xFFFF) << 16)


## --- Reset all caches (call on pawn death or major state change) ---
func reset_caches() -> void:
	_cached_utility_context.clear()
	_cached_utility_context_tick = -1
	_parity_context.clear()
	_parity_context_tick = -1
	_cached_idle_action = "work"
	_learning_weight_cache.clear()
	_learning_weight_cache_tick = -1
	_next_goal_refresh_tick = -1
	_cached_active_goal.clear()
	_cached_active_goal_priority = 0.0
	_awareness.clear()
	_awareness_tick = -999999
	_neural_priority_outputs.clear()
	_neural_priority_fetch_tick = -1
	_neural_priority_next_refresh_tick = -1
	_matrix_priority_decision.clear()
	_matrix_priority_fetch_tick = -1
	_matrix_priority_next_refresh_tick = -1


## --- Core decision engine: score and select best job from available pool ---
## Returns the best Job for this pawn based on utility, personality, needs,
## neural state, matrix bias, and settlement context. Replaces hardcoded
## priority waterfall with emergent need-driven scoring.
func decide_best_job(
	pawn: Node,
	data: HeelKawnianData,
	jobs: Array,
	base_passes: Callable,
	priority_cb: Callable,
	food_emergency: bool,
	utility_context: Dictionary,
	my_component: int,
	from_region_key: int
) -> Job:
	if jobs.is_empty() or data == null:
		return null

	var best_job: Job = null
	var best_score: float = -999999.0
	var _Job = load("res://scripts/jobs/Job.gd")

	# Cache personality traits once per decision pass
	var bp: Callable = func(i: int) -> float:
		if pawn != null and pawn.has_method("_bp"):
			return float(pawn.call("_bp", i))
		return 0.5

	for j in jobs:
		var job: Job = j as Job
		if job == null:
			continue

		# Hard filters first (component, materials, tech, etc.)
		if base_passes.is_valid() and not base_passes.call(job):
			continue

		# Start with base priority from callback
		var score: float = 0.0
		if priority_cb.is_valid():
			score = float(priority_cb.call(job))

		# If priority_cb already returned a hard reject, skip
		if score <= -900.0:
			continue

		# ── PERSONALITY INTEGRATION: Big Five traits shape job preference ──
		# Slot 0: Openness → prefer novel/exploratory jobs (forage, hunt, trade)
		var openness: float = bp.call(0)
		if job.type in [_Job.Type.FORAGE, _Job.Type.HUNT, _Job.Type.FISH, _Job.Type.TRADE_HAUL]:
			score += (openness - 0.5) * 8.0

		# Slot 1: Conscientiousness → prefer structured/building jobs
		var conscientiousness: float = bp.call(1)
		if _is_build_job(job.type):
			score += (conscientiousness - 0.5) * 10.0

		# Slot 2: Extraversion → prefer social/teaching jobs, avoid isolation
		var extraversion: float = bp.call(2)
		if job.type in [_Job.Type.TEACH_SKILL, _Job.Type.APPRENTICESHIP, _Job.Type.PROTECT, _Job.Type.DEFEND]:
			score += (extraversion - 0.5) * 6.0
		if job.type in [_Job.Type.FORAGE, _Job.Type.HUNT]:
			score += (extraversion - 0.5) * -4.0  # Introverts prefer solo work

		# Slot 3: Agreeableness → prefer helping/cooperative jobs
		var agreeableness: float = bp.call(3)
		if job.issuer_pawn_id >= 0:
			score += (agreeableness - 0.5) * 5.0  # Follow orders more
		if job.type in [_Job.Type.TEACH_SKILL, _Job.Type.BUILD_BED, _Job.Type.BUILD_SHELTER]:
			score += (agreeableness - 0.5) * 4.0

		# Slot 4: Neuroticism → avoid danger, prefer safety
		var neuroticism: float = bp.call(4)
		var job_rk: int = _region_key(job.work_tile.x, job.work_tile.y)
		var scar_level: int = 0
		if WorldPersistence != null and WorldPersistence.has_method("get_region_scar_level"):
			scar_level = int(WorldPersistence.get_region_scar_level(job_rk))
		if scar_level >= 2:
			score += (neuroticism - 0.5) * -12.0  # High neuroticism avoids danger
		if job.type in [_Job.Type.DEFEND, _Job.Type.PROTECT]:
			score += (neuroticism - 0.5) * -6.0

		# Slot 5: Wanderlust (existing) → already used in wander chance
		# Slot 6: Risk tolerance → prefer high-reward/high-risk jobs
		var risk_tolerance: float = bp.call(6)
		if job.type in [_Job.Type.HUNT, _Job.Type.MINE, _Job.Type.MINE_WALL]:
			score += (risk_tolerance - 0.5) * 8.0

		# Slot 7: Tradition → prefer established/customary jobs
		var tradition: float = bp.call(7)
		if job.social_weight > 0.01:
			score += (tradition - 0.5) * 4.0  # Follow social norms

		# ── DISTANCE PENALTY: closer jobs are easier to claim ──
		if pawn != null and data.tile_pos != job.work_tile:
			var dist: int = absi(data.tile_pos.x - job.work_tile.x) + absi(data.tile_pos.y - job.work_tile.y)
			score -= float(dist) * 0.15  # Small penalty per tile

		# ── URGENCY MULTIPLIER: critical needs amplify relevant jobs ──
		if food_emergency and job.type in [_Job.Type.FORAGE, _Job.Type.HUNT, _Job.Type.FISH]:
			score *= 1.5
		if data.hunger <= 30.0 and job.type in [_Job.Type.FORAGE, _Job.Type.HUNT, _Job.Type.FISH]:
			score *= 1.3
		if data.rest <= 20.0 and _is_rest_job(job.type):
			score *= 1.4

		if score > best_score:
			best_score = score
			best_job = job

	return best_job


static func _is_build_job(job_type: int) -> bool:
	var _Job = load("res://scripts/jobs/Job.gd")
	return job_type in [
		_Job.Type.BUILD_BED, _Job.Type.BUILD_WALL, _Job.Type.BUILD_DOOR,
		_Job.Type.BUILD_FIRE_PIT, _Job.Type.BUILD_STORAGE_HUT, _Job.Type.BUILD_STOCKPILE,
		_Job.Type.BUILD_SHELTER, _Job.Type.BUILD_HEARTH, _Job.Type.BUILD_MARKER_STONE,
		_Job.Type.BUILD_SHRINE, _Job.Type.BUILD_FARM_WHEAT, _Job.Type.BUILD_FARM_CORN,
		_Job.Type.BUILD_FARM_VEGETABLES, _Job.Type.BUILD_HERB_GARDEN,
		_Job.Type.BUILD_WORKSHOP, _Job.Type.BUILD_LOOM, _Job.Type.BUILD_KILN,
		_Job.Type.BUILD_SMELTER, _Job.Type.BUILD_BOATYARD, _Job.Type.BUILD_DOCK,
		_Job.Type.BUILD_FISHERMAN_HUT, _Job.Type.BUILD_APOTHECARY, _Job.Type.BUILD_LIBRARY,
		_Job.Type.BUILD_SCHOOL, _Job.Type.BUILD_BARRACKS, _Job.Type.BUILD_WATCHTOWER,
		_Job.Type.BUILD_MARKET, _Job.Type.BUILD_TRADING_POST, _Job.Type.BUILD_ROAD,
		_Job.Type.BUILD_GRANARY, _Job.Type.BUILD_CELLAR, _Job.Type.BUILD_BREWERY,
		_Job.Type.BUILD_TAVERN, _Job.Type.BUILD_FORD, _Job.Type.BUILD_WATER_MILL,
	]


static func _is_rest_job(job_type: int) -> bool:
	var _Job = load("res://scripts/jobs/Job.gd")
	return job_type in [_Job.Type.BUILD_BED, _Job.Type.BUILD_SHELTER, _Job.Type.BUILD_HEARTH, _Job.Type.BUILD_FIRE_PIT]
