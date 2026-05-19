extends Node

## Deterministic Bayesian-style decision tree for colony build choices.
## It learns from completed and cancelled jobs, then nudges future build
## priorities so the colony can adapt over long runs.

const SAVE_VERSION: int = 1
const PRIOR_WEIGHT: float = 3.0
const PRIORITY_MIN: int = -2
const PRIORITY_MAX: int = 3

var _root: Dictionary = _new_node()
var _events_seen: int = 0


func _ready() -> void:
	_bind_job_manager()


func _bind_job_manager() -> void:
	if JobManager == null:
		return
	var completed_cb: Callable = Callable(self, "_on_job_completed")
	if JobManager.has_signal("job_completed") and not JobManager.job_completed.is_connected(completed_cb):
		JobManager.job_completed.connect(completed_cb)
	var cancelled_cb: Callable = Callable(self, "_on_job_cancelled")
	if JobManager.has_signal("job_cancelled") and not JobManager.job_cancelled.is_connected(cancelled_cb):
		JobManager.job_cancelled.connect(cancelled_cb)


func to_save_dict() -> Dictionary:
	return {
		"v": SAVE_VERSION,
		"events_seen": _events_seen,
		"root": _root.duplicate(true),
	}


func from_save_dict(data: Dictionary) -> void:
	_events_seen = int(data.get("events_seen", 0))
	var raw_root: Variant = data.get("root", {})
	if raw_root is Dictionary:
		_root = (raw_root as Dictionary).duplicate(true)
	else:
		_root = _new_node()


func get_build_priority_bonus(
		job_type: int,
		center_region: int,
		features: Dictionary,
		local_pop: int,
		build_priorities: Dictionary = {}
) -> int:
	var family: String = _job_family_for_type(job_type)
	if family.is_empty():
		return 0
	var need_score: float = _need_score_for_job(job_type, center_region, features, local_pop, build_priorities)
	var tokens: Array[String] = _path_tokens(family, need_score, local_pop, build_priorities)
	var node: Dictionary = _ensure_path(tokens)
	var good: int = int(node.get("good", 0))
	var bad: int = int(node.get("bad", 0))
	var observed: float = float(good + 1) / float(good + bad + 2)
	var posterior: float = clampf((observed * 0.65) + (need_score * 0.35), 0.0, 1.0)
	var bonus: int = int(round((posterior - 0.50) * 8.0))
	if build_priorities.get("ranked_needs", []) is Array:
		bonus += _ranked_need_bonus(family, build_priorities.get("ranked_needs", []))
	return clampi(bonus, PRIORITY_MIN, PRIORITY_MAX)


func _on_job_completed(job: Job) -> void:
	_record_job_outcome(job, true)


func _on_job_cancelled(job: Job) -> void:
	_record_job_outcome(job, false)


func _record_job_outcome(job: Job, completed: bool) -> void:
	if job == null:
		return
	var family: String = _job_family_for_type(int(job.type))
	if family.is_empty():
		return
	var context: Dictionary = _job_context(job)
	var need_score: float = _need_score_for_job(
			int(job.type),
			int(context.get("center_region", -1)),
			context.get("features", {}),
			int(context.get("local_pop", 0)),
			context.get("build_priorities", {})
	)
	var path: Array[String] = _path_tokens(family, need_score, int(context.get("local_pop", 0)), context.get("build_priorities", {}))
	var node: Dictionary = _ensure_path(path)
	_events_seen += 1
	if completed and need_score >= 0.45:
		node["good"] = int(node.get("good", 0)) + 1
	else:
		node["bad"] = int(node.get("bad", 0)) + 1
	node["total"] = int(node.get("total", 0)) + 1
	node["last_tick"] = GameManager.tick_count if GameManager != null else int(node.get("last_tick", -1))


func _job_context(job: Job) -> Dictionary:
	var region_key: int = WorldMemory._region_key(job.tile.x, job.tile.y) if WorldMemory != null else -1
	var center_region: int = region_key
	if SettlementMemory != null and SettlementMemory.has_method("get_center_region_for_region") and region_key >= 0:
		var mapped_region: int = int(SettlementMemory.get_center_region_for_region(region_key))
		if mapped_region >= 0:
			center_region = mapped_region
	var features: Dictionary = {}
	if HeelKawnianManager != null and HeelKawnianManager.has_method("_scan_local_features"):
		features = HeelKawnianManager._scan_local_features(job.tile, 12)
	var local_pop: int = 0
	if SettlementMemory != null and SettlementMemory.has_method("get_settlement_at_region") and region_key >= 0:
		var settlement_v: Variant = SettlementMemory.get_settlement_at_region(region_key)
		if settlement_v is Dictionary:
			local_pop = int((settlement_v as Dictionary).get("population", 0))
	var build_priorities: Dictionary = {}
	if ColonySimServices != null and ColonySimServices.has_method("compute_settlement_build_priorities") and center_region >= 0:
		build_priorities = ColonySimServices.compute_settlement_build_priorities(center_region, local_pop, features, false)
	return {
		"region_key": region_key,
		"center_region": center_region,
		"features": features,
		"local_pop": local_pop,
		"build_priorities": build_priorities,
	}


func _job_family_for_type(job_type: int) -> String:
	match job_type:
		Job.Type.BUILD_BED, Job.Type.BUILD_SHELTER:
			return "housing"
		Job.Type.BUILD_FIRE_PIT, Job.Type.BUILD_HEARTH:
			return "warmth"
		Job.Type.BUILD_STORAGE_HUT, Job.Type.BUILD_STOCKPILE, Job.Type.BUILD_GRANARY, Job.Type.BUILD_CELLAR:
			return "storage"
		Job.Type.BUILD_WALL, Job.Type.BUILD_DOOR, Job.Type.BUILD_WATCHTOWER, Job.Type.BUILD_BARRACKS, Job.Type.BUILD_FORD:
			return "defense"
		Job.Type.BUILD_FARM_WHEAT, Job.Type.BUILD_FARM_CORN, Job.Type.BUILD_FARM_VEGETABLES, Job.Type.BUILD_HERB_GARDEN, Job.Type.PLANT_SEEDS, Job.Type.HARVEST_CROPS, Job.Type.COOK_MEAT, Job.Type.COOK_BERRIES, Job.Type.COOK_FISH:
			return "food"
		Job.Type.BUILD_WORKSHOP, Job.Type.BUILD_LIBRARY, Job.Type.BUILD_SCHOOL, Job.Type.BUILD_APOTHECARY, Job.Type.BUILD_MARKET, Job.Type.BUILD_TRADING_POST:
			return "civil"
		Job.Type.BUILD_ROAD, Job.Type.MAINTAIN_STRUCTURE:
			return "infrastructure"
		_:
			return ""
	return ""


func _need_score_for_job(job_type: int, center_region: int, features: Dictionary, local_pop: int, build_priorities: Dictionary) -> float:
	var family: String = _job_family_for_type(job_type)
	var need_score: float = 0.0
	match family:
		"housing":
			need_score = float(build_priorities.get("housing_press", 0.0))
		"warmth":
			need_score = float(build_priorities.get("warmth_press", 0.0))
		"storage":
			need_score = float(build_priorities.get("storage_press", 0.0))
			if int(features.get("storage_hut", 0)) <= 0 and local_pop >= 2:
				need_score = maxf(need_score, 0.55)
			var stockpile_count: int = StockpileManager.zone_count() if StockpileManager != null and StockpileManager.has_method("zone_count") else (StockpileManager.zones().size() if StockpileManager != null and StockpileManager.has_method("zones") else 0)
			if stockpile_count >= maxi(2, local_pop):
				need_score = maxf(need_score - 0.20, 0.0)
		"defense":
			var walls: int = int(features.get("wall", 0))
			var doors: int = int(features.get("door", 0))
			var barracks: int = int(features.get("barracks", 0))
			var watchtowers: int = int(features.get("watchtower", 0))
			var defense_gap: float = 0.0
			if walls < 2:
				defense_gap = 0.55
			if doors <= 0 and walls >= 2:
				defense_gap = maxf(defense_gap, 0.35)
			if barracks <= 0 and watchtowers <= 0 and local_pop >= 4:
				defense_gap = maxf(defense_gap, 0.25)
			need_score = defense_gap
		"food":
			need_score = float(build_priorities.get("food_press", 0.0))
			if int(features.get("farm", 0)) <= 0 and local_pop >= 2:
				need_score = maxf(need_score, 0.45)
		"civil":
			need_score = clampf(float(build_priorities.get("ambition_score", 0.0)) * 0.8, 0.0, 1.0)
			if bool(build_priorities.get("survival_met", false)):
				need_score = maxf(need_score, 0.35)
		"infrastructure":
			need_score = 0.25 if bool(build_priorities.get("survival_met", false)) else 0.10
		_:
			need_score = 0.0
	if build_priorities.get("ranked_needs", []) is Array:
		var ranked: Array = build_priorities.get("ranked_needs", [])
		if not ranked.is_empty():
			if String(ranked[0]) == family:
				need_score = maxf(need_score, 0.72)
			elif family in ranked:
				need_score = maxf(need_score, 0.48)
			else:
				need_score = minf(need_score, 0.30)
	return clampf(need_score, 0.0, 1.0)


func _ranked_need_bonus(family: String, ranked: Array) -> int:
	if ranked.is_empty():
		return 0
	if String(ranked[0]) == family:
		return 1
	if family in ranked:
		return 0
	return -1


func _path_tokens(family: String, need_score: float, local_pop: int, build_priorities: Dictionary) -> Array[String]:
	return [
		"family:%s" % family,
		"need:%s" % _bucket_need(need_score),
		"pop:%s" % _bucket_pop(local_pop),
		"pressure:%s" % _bucket_pressure(build_priorities, family),
	]


func _bucket_need(score: float) -> String:
	if score < 0.25:
		return "low"
	if score < 0.60:
		return "mid"
	return "high"


func _bucket_pop(local_pop: int) -> String:
	if local_pop <= 1:
		return "solo"
	if local_pop <= 3:
		return "small"
	if local_pop <= 6:
		return "medium"
	return "large"


func _bucket_pressure(build_priorities: Dictionary, family: String) -> String:
	var value: float = 0.0
	match family:
		"housing":
			value = float(build_priorities.get("housing_press", 0.0))
		"warmth":
			value = float(build_priorities.get("warmth_press", 0.0))
		"storage":
			value = float(build_priorities.get("storage_press", 0.0))
		"food":
			value = float(build_priorities.get("food_press", 0.0))
		"civil":
			value = float(build_priorities.get("ambition_score", 0.0))
		"defense":
			value = 0.35 if bool(build_priorities.get("survival_met", false)) else 0.65
		"infrastructure":
			value = 0.15
		_:
			value = 0.0
	if value < 0.25:
		return "low"
	if value < 0.60:
		return "mid"
	return "high"


func _ensure_path(tokens: Array[String]) -> Dictionary:
	var node: Dictionary = _root
	for token in tokens:
		var children: Dictionary = node.get("children", {})
		if not children.has(token):
			children[token] = _new_node()
		node["children"] = children
		node = children[token]
	return node


func _new_node() -> Dictionary:
	return {
		"good": 0,
		"bad": 0,
		"total": 0,
		"last_tick": -1,
		"children": {},
	}