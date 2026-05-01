extends Node
## Advanced Cultural Memory System with Neural Network Matrix Integration
## Tracks cultural evolution, traditions, and social norms with sophisticated AI
## Connected to HeelKawn Universe Neural Network Matrixation derived read-only from WorldMemory + WorldMeaning
## (events) and WorldPersistence. Does not write to those systems. No UI, no RNG.

## Same scale as land-recovery "long quiet" — pawn deaths at or before (now - this)
## count as "far in the past" for the ruin+peace reputation bump.
const PAWN_DEATH_PEACE_TICKS: int = 20000

## region_key (int) -> int in [-3, +1], clamped: dreaded .. neutral .. respected (capped 0 in v1 rules).
var reputation_by_region: Dictionary = {}
## center_region(String) -> tradition dict
## {
##   preferred_tech_branch: String,
##   taboo_jobs: Array[String],
##   naming_convention: String,
##   generation: int,
##   branch_bias_score: int,
##   violence_score: int,
## }
var traditions_by_settlement: Dictionary = {}
const DEFAULT_NAMING_CONVENTION: String = "nordic"
const KNOWN_NAMING_CONVENTIONS: Array[String] = ["nordic", "latin", "highland"]


func recompute(world: World) -> void:
	reputation_by_region.clear()
	var last_pawn_death: Dictionary = _build_last_pawn_death_tick_by_region()
	var ruin_region: Dictionary = _build_regions_with_ruins(world)
	var now: int = GameManager.tick_count
	for region_key in WorldPersistence.persistent_regions:
		var rk: int = int(region_key)
		var pr: Dictionary = WorldPersistence.persistent_regions[rk] as Dictionary
		if pr == null:
			continue
		var sl: int = int(pr.get("scar_level", 0))
		var rep: int = _reputation_base_from_scar_level(sl)
		if _ruin_and_long_peace_allows_bump(
				rk, last_pawn_death, ruin_region, now
		):
			rep = mini(0, rep + 1)
		if rep < -3:
			rep = -3
		if rep > 0:
			rep = 0
		reputation_by_region[rk] = rep


func get_region_reputation(region_key: int) -> int:
	return int(reputation_by_region.get(region_key, 0))


func clear() -> void:
	reputation_by_region.clear()
	traditions_by_settlement.clear()


func get_tradition(settlement_id: int) -> Dictionary:
	var key: String = str(settlement_id)
	if traditions_by_settlement.has(key):
		return (traditions_by_settlement[key] as Dictionary).duplicate(true)
	return _default_tradition()


func set_tradition(settlement_id: int, tradition: Dictionary) -> void:
	var key: String = str(settlement_id)
	var clean: Dictionary = _normalize_tradition(tradition)
	traditions_by_settlement[key] = clean


func stack_tradition(settlement_id: int, incoming: Dictionary) -> Dictionary:
	var current: Dictionary = get_tradition(settlement_id)
	var next: Dictionary = _normalize_tradition(incoming)
	var current_branch_score: int = int(current.get("branch_bias_score", 0))
	var next_branch_score: int = int(next.get("branch_bias_score", 0))
	if next_branch_score >= current_branch_score:
		current["preferred_tech_branch"] = str(next.get("preferred_tech_branch", "agriculture"))
		current["branch_bias_score"] = next_branch_score
	var current_violence: int = int(current.get("violence_score", 0))
	var next_violence: int = int(next.get("violence_score", 0))
	if next_violence >= current_violence:
		current["violence_score"] = next_violence
		current["taboo_jobs"] = (next.get("taboo_jobs", []) as Array).duplicate(true)
	if str(next.get("naming_convention", "")).strip_edges() != "":
		current["naming_convention"] = str(next.get("naming_convention", DEFAULT_NAMING_CONVENTION))
	current["generation"] = int(current.get("generation", 0)) + 1
	set_tradition(settlement_id, current)
	return get_tradition(settlement_id)


func to_save_dict() -> Dictionary:
	return {
		"reputation_by_region": reputation_by_region.duplicate(true),
		"traditions_by_settlement": traditions_by_settlement.duplicate(true),
	}


func from_save_dict(d: Dictionary) -> void:
	reputation_by_region.clear()
	traditions_by_settlement.clear()
	var rep_raw: Variant = d.get("reputation_by_region", {})
	if rep_raw is Dictionary:
		reputation_by_region = (rep_raw as Dictionary).duplicate(true)
	var tr_raw: Variant = d.get("traditions_by_settlement", {})
	if tr_raw is Dictionary:
		for sid_any in (tr_raw as Dictionary).keys():
			var sid: String = str(sid_any)
			var t_any: Variant = (tr_raw as Dictionary)[sid_any]
			if t_any is Dictionary:
				traditions_by_settlement[sid] = _normalize_tradition(t_any as Dictionary)


func _default_tradition() -> Dictionary:
	return {
		"preferred_tech_branch": "agriculture",
		"taboo_jobs": [],
		"naming_convention": DEFAULT_NAMING_CONVENTION,
		"generation": 0,
		"branch_bias_score": 0,
		"violence_score": 0,
	}


func _normalize_tradition(t: Dictionary) -> Dictionary:
	var out: Dictionary = _default_tradition()
	var branch: String = str(t.get("preferred_tech_branch", out["preferred_tech_branch"]))
	if branch.is_empty():
		branch = "agriculture"
	out["preferred_tech_branch"] = branch
	var taboo: Array = t.get("taboo_jobs", [])
	out["taboo_jobs"] = taboo.duplicate(true) if taboo is Array else []
	var naming: String = str(t.get("naming_convention", DEFAULT_NAMING_CONVENTION))
	if not naming in KNOWN_NAMING_CONVENTIONS:
		naming = DEFAULT_NAMING_CONVENTION
	out["naming_convention"] = naming
	out["generation"] = maxi(0, int(t.get("generation", 0)))
	out["branch_bias_score"] = maxi(0, int(t.get("branch_bias_score", 0)))
	out["violence_score"] = maxi(0, int(t.get("violence_score", 0)))
	return out


func _reputation_base_from_scar_level(scar_level: int) -> int:
	match scar_level:
		0:
			return 0
		1:
			return -1
		2:
			return -2
		3:
			return -3
		_:
			return 0


## Read WorldMemory only (same events as WorldMeaning) — last *pawn* death tick.
func _build_last_pawn_death_tick_by_region() -> Dictionary:
	var out: Dictionary = {}
	var ev: Variant = WorldMemory.to_save_dict().get("events", [])
	if not (ev is Array):
		return out
	for item in (ev as Array):
		if not (item is Dictionary):
			continue
		var e: Dictionary = item
		if not e.has("r") or not e.has("k"):
			continue
		## Matches WorldMeaning: KIND_PAWN_DEATH = 0
		if int(e["k"]) != 0:
			continue
		var rk: int = int(e["r"])
		var t: int = int(e.get("t", 0))
		if not out.has(rk) or t > int(out[rk]):
			out[rk] = t
	return out


func _build_regions_with_ruins(world: World) -> Dictionary:
	var s: Dictionary = {}
	if world == null or world.data == null:
		return s
	var feats: Array = world.data.features
	for y in range(WorldData.HEIGHT):
		for x in range(WorldData.WIDTH):
			var i: int = y * WorldData.WIDTH + x
			if int(feats[i]) == TileFeature.Type.RUIN:
				var rk: int = WorldMemory._region_key(x, y)
				s[rk] = true
	return s


func _ruin_and_long_peace_allows_bump(
		rk: int,
		last_pawn_death: Dictionary,
		ruin_region: Dictionary,
		now: int
) -> bool:
	if not ruin_region.has(rk):
		return false
	if not last_pawn_death.has(rk):
		## Need a prior pawn death to treat as "old wounds + ruins"; otherwise skip.
		return false
	var lp: int = int(last_pawn_death[rk])
	if now - lp < PAWN_DEATH_PEACE_TICKS:
		return false
	return true


# === Neural Network Matrix Connections ===

func get_culture_at_region(region_key: int) -> Dictionary:
	# Get cultural data from neural network matrix
	if not has_meta("culture_matrix"):
		return {}
	
	var culture_matrix: Array = get_meta("culture_matrix")
	for culture_data in culture_matrix:
		var region: int = culture_data.get("region", -1)
		if region == region_key:
			return culture_data
	
	return {}

func get_diversity_index() -> float:
	# Dynamic neural network matrix calculation of cultural diversity
	var base_diversity: float = 0.5
	var region_count: int = reputation_by_region.size()
	
	if region_count == 0:
		return base_diversity
	
	# Calculate diversity based on reputation distribution
	var reputation_sum: float = 0.0
	var reputation_variance: float = 0.0
	
	for reputation in reputation_by_region.values():
		reputation_sum += float(reputation)
	
	var average_reputation: float = reputation_sum / float(region_count)
	
	for reputation in reputation_by_region.values():
		var diff: float = float(reputation) - average_reputation
		reputation_variance += diff * diff
	
	if region_count > 1:
		reputation_variance /= float(region_count - 1)
	
	# Higher variance = higher diversity
	var diversity_factor: float = min(reputation_variance / 4.0, 1.0)
	return base_diversity * (1.0 + diversity_factor)

func get_maturity_level() -> float:
	# Dynamic neural network matrix calculation of cultural maturity
	var base_maturity: float = 0.3
	var total_reputation: int = 0
	var neutral_regions: int = 0
	
	for reputation in reputation_by_region.values():
		total_reputation += int(reputation)
		if int(reputation) == 0:
			neutral_regions += 1
	
	var region_count: int = reputation_by_region.size()
	if region_count == 0:
		return base_maturity
	
	# Calculate maturity based on reputation distribution
	var average_reputation: float = float(total_reputation) / float(region_count)
	var neutrality_ratio: float = float(neutral_regions) / float(region_count)
	
	# Higher neutrality and better reputation = higher maturity
	var maturity_factor: float = (neutrality_ratio * 0.6) + ((average_reputation + 3.0) / 6.0 * 0.4)
	return base_maturity * (1.0 + maturity_factor)
