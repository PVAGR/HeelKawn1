extends Node
## Derived civilization-era lens for HeelKawn.
##
## This does not advance civilization by itself. It reads live world state and
## answers: "what era does this settlement currently deserve?"

const STAGE_PRIMITIVE: int = 0
const STAGE_NEOLITHIC: int = 1
const STAGE_BRONZE_AGE: int = 2
const STAGE_IRON_AGE: int = 3
const STAGE_MEDIEVAL: int = 4
const STAGE_RENAISSANCE: int = 5
const STAGE_INDUSTRIAL: int = 6
const STAGE_MODERN: int = 7
const STAGE_INFORMATION: int = 8
const STAGE_SPACE_AGE: int = 9
const STAGE_POST_SCARCITY: int = 10

const STAGE_NAMES: Dictionary = {
	STAGE_PRIMITIVE: "Primitive",
	STAGE_NEOLITHIC: "Neolithic",
	STAGE_BRONZE_AGE: "Bronze Age",
	STAGE_IRON_AGE: "Iron Age",
	STAGE_MEDIEVAL: "Medieval",
	STAGE_RENAISSANCE: "Renaissance",
	STAGE_INDUSTRIAL: "Industrial",
	STAGE_MODERN: "Modern",
	STAGE_INFORMATION: "Information",
	STAGE_SPACE_AGE: "Space Age",
	STAGE_POST_SCARCITY: "Post-Scarcity",
}

## Display name: "—" until HeelKawnians have experienced enough to name their era.
## Once a settlement has any infrastructure or knowledge, the era becomes visible.
func get_stage_display_name(stage: int, score: int) -> String:
	if score <= 0:
		return "—"  # No experience yet — era is unknown
	return str(STAGE_NAMES.get(stage, "Unknown"))

const STAGE_DESCRIPTIONS: Dictionary = {
	STAGE_PRIMITIVE: "survival, fire, oral memory",
	STAGE_NEOLITHIC: "settlement, farming, stored food",
	STAGE_BRONZE_AGE: "craft specialization and durable records",
	STAGE_IRON_AGE: "metal, roads, trade, and stronger institutions",
	STAGE_MEDIEVAL: "guilds, law, libraries, and formal learning",
	STAGE_RENAISSANCE: "scientific method and cultural acceleration",
	STAGE_INDUSTRIAL: "machines, factories, mass production",
	STAGE_MODERN: "electricity, medicine, nation-scale systems",
	STAGE_INFORMATION: "digital memory and networked knowledge",
	STAGE_SPACE_AGE: "off-world expansion and planetary-scale engineering",
	STAGE_POST_SCARCITY: "abundance, deep archives, and god-tech",
}

const CACHE_TICKS: int = 120
const WRITING_KNOWLEDGE_ID: int = 24

## Era score penalty applied when knowledge is lost in a settlement.
## The penalty decays over time as the settlement adapts.
const KNOWLEDGE_LOSS_ERA_PENALTY: int = 3
const KNOWLEDGE_LOSS_PENALTY_DECAY_INTERVAL_TICKS: int = 360

var _snapshot_cache: Dictionary = {}
## Per-settlement era score penalties from knowledge loss (settlement_id(str) -> penalty amount)
var _knowledge_loss_penalties: Dictionary = {}


func get_civilization_stage(settlement_id: int = -1) -> int:
	return int(get_stage_snapshot(settlement_id).get("stage", STAGE_PRIMITIVE))


func get_stage_name(stage: int) -> String:
	return str(STAGE_NAMES.get(stage, "Unknown"))


func get_stage_description(stage: int) -> String:
	return str(STAGE_DESCRIPTIONS.get(stage, "unknown conditions"))


func calculate_civilization_score(settlement_id: int = -1) -> int:
	return int(get_stage_snapshot(settlement_id).get("score", 0))


## Get the world-level civilization score (highest settlement score).
## Used by MythAge to determine which myth age the world has entered.
func get_world_score() -> int:
	var world_snap: Dictionary = get_stage_snapshot(-1)
	return int(world_snap.get("score", 0))


func get_world_stage_snapshot() -> Dictionary:
	return get_stage_snapshot(-1)


func get_stage_snapshot(settlement_id: int = -1) -> Dictionary:
	var tick: int = _tick()
	var key: String = str(settlement_id)
	var cached: Variant = _snapshot_cache.get(key, null)
	if cached is Dictionary:
		var cached_dict: Dictionary = cached as Dictionary
		if tick - int(cached_dict.get("_cache_tick", -999999)) < CACHE_TICKS:
			return cached_dict.duplicate(true)
	var snap: Dictionary = _build_stage_snapshot(settlement_id)
	snap["_cache_tick"] = tick
	_snapshot_cache[key] = snap
	return snap.duplicate(true)


func get_all_stage_snapshots(max_items: int = 12) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if SettlementMemory == null or not SettlementMemory.has_method("get_settlements"):
		out.append(get_world_stage_snapshot())
		return out
	var settlements: Array = SettlementMemory.get_formal_settlements()
	for i in range(mini(max_items, settlements.size())):
		out.append(get_stage_snapshot(i))
	if settlements.is_empty():
		out.append(get_world_stage_snapshot())
	return out


func score_to_stage(score: int) -> int:
	if score < 10:
		return STAGE_PRIMITIVE
	if score < 20:
		return STAGE_NEOLITHIC
	if score < 30:
		return STAGE_BRONZE_AGE
	if score < 40:
		return STAGE_IRON_AGE
	if score < 50:
		return STAGE_MEDIEVAL
	if score < 60:
		return STAGE_RENAISSANCE
	if score < 70:
		return STAGE_INDUSTRIAL
	if score < 80:
		return STAGE_MODERN
	if score < 90:
		return STAGE_INFORMATION
	if score < 100:
		return STAGE_SPACE_AGE
	return STAGE_POST_SCARCITY


func _build_stage_snapshot(settlement_id: int) -> Dictionary:
	var st: Dictionary = _settlement_for_id(settlement_id)
	var center_region: int = int(st.get("center_region", settlement_id)) if not st.is_empty() else settlement_id
	var pawns: Array[HeelKawnian] = _pawns_for_settlement(st, settlement_id)
	var tech_score: int = _technology_score()
	var knowledge_score: int = _knowledge_score(pawns)
	var infrastructure_score: int = _infrastructure_score(st, center_region)
	var complexity_score: int = _complexity_score(pawns)
	var quality_score: int = _quality_of_life_score(pawns)
	var score: int = clampi(
		tech_score + knowledge_score + infrastructure_score + complexity_score + quality_score,
		0,
		100
	)
	var stage: int = score_to_stage(score)
	return {
		"settlement_id": settlement_id,
		"center_region": center_region,
		"name": _settlement_name(st, settlement_id),
		"score": score,
		"stage": stage,
		"stage_name": get_stage_name(stage),
		"description": get_stage_description(stage),
		"pawns": pawns.size(),
		"breakdown": {
			"technology": tech_score,
			"knowledge": knowledge_score,
			"infrastructure": infrastructure_score,
			"complexity": complexity_score,
			"quality_of_life": quality_score,
		},
		"next_stage_score": _next_stage_score(score),
	}


func _technology_score() -> int:
	if TechnologySystem == null or not TechnologySystem.has_method("get_stats"):
		return 0
	var stats: Dictionary = TechnologySystem.get_stats()
	var completed: int = int(stats.get("completed", 0))
	var research_points: int = int(stats.get("total_research_points", 0))
	return mini(30, completed * 3 + int(research_points / 250))


func _knowledge_score(pawns: Array[HeelKawnian]) -> int:
	if KnowledgeSystem == null:
		return 0
	var carriers_v: Variant = KnowledgeSystem.get("knowledge_carriers")
	if not (carriers_v is Dictionary):
		return 0
	var carriers: Dictionary = carriers_v as Dictionary
	var allowed_ids: Dictionary = {}
	if not pawns.is_empty():
		for p in pawns:
			if p != null and is_instance_valid(p) and p.data != null:
				allowed_ids[int(p.data.id)] = true
	var known_types: Dictionary = {}
	for pid in carriers:
		if not allowed_ids.is_empty() and not allowed_ids.has(int(pid)):
			continue
		var arr_v: Variant = carriers.get(pid, [])
		if arr_v is Array:
			for kt in arr_v:
				known_types[int(kt)] = true
	var record_bonus: int = 0
	var record_v: Variant = KnowledgeSystem.get("record_carriers")
	if record_v is Dictionary:
		record_bonus = mini(4, int((record_v as Dictionary).size()))
	return mini(20, known_types.size() + record_bonus)


func _infrastructure_score(st: Dictionary, center_region: int) -> int:
	var score: int = 0
	if not st.is_empty():
		var regs_v: Variant = st.get("regions", PackedInt32Array())
		if regs_v is PackedInt32Array:
			score += mini(8, maxi(1, int((regs_v as PackedInt32Array).size() / 2)))
		var state: String = str(st.get("state", ""))
		if state == "active":
			score += 3
		elif state == "reviving" or state == "recovering" or state == "revivable":
			score += 1
	if WorldMemory != null and WorldMemory.has_method("get_recent_events_for_settlement") and center_region >= 0:
		var events: Array[Dictionary] = WorldMemory.get_recent_events_for_settlement(center_region, 128, true)
		var built_count: int = 0
		for e in events:
			var typ: String = str(e.get("type", ""))
			if typ == "structure_built" or typ == "building_constructed" or typ == "cooperative_build":
				built_count += 1
		score += mini(7, built_count)
	elif WorldMemory != null and WorldMemory.has_method("get_event_type_counts"):
		var counts: Dictionary = WorldMemory.get_event_type_counts()
		score += mini(7, int(counts.get("structure_built", 0)) + int(counts.get("building_constructed", 0)))
	if StockpileManager != null and StockpileManager.has_method("zone_count"):
		score += mini(2, StockpileManager.zone_count())
	return mini(20, score)


func _complexity_score(pawns: Array[HeelKawnian]) -> int:
	var professions: Dictionary = {}
	var skill_branches: int = 0
	for p in pawns:
		if p == null or not is_instance_valid(p) or p.data == null:
			continue
		var prof: int = int(p.data.current_profession)
		if prof != HeelKawnianData.Profession.NONE:
			professions[prof] = true
		skill_branches += int(p.data.skill_trees.size())
	return mini(20, professions.size() * 3 + mini(5, skill_branches))


func _quality_of_life_score(pawns: Array[HeelKawnian]) -> int:
	if pawns.is_empty():
		return 0
	var total_health: float = 0.0
	var total_age: float = 0.0
	var literate: int = 0
	var count: int = 0
	for p in pawns:
		if p == null or not is_instance_valid(p) or p.data == null:
			continue
		count += 1
		total_health += float(p.data.health)
		total_age += float(p.data.age)
		if KnowledgeSystem != null and KnowledgeSystem.has_method("has_knowledge"):
			if bool(KnowledgeSystem.call("has_knowledge", int(p.data.id), WRITING_KNOWLEDGE_ID)):
				literate += 1
	if count <= 0:
		return 0
	var avg_health: float = total_health / float(count)
	var avg_age: float = total_age / float(count)
	var literacy: float = float(literate) / float(count)
	return mini(10, int(avg_health / 20.0) + int(avg_age / 20.0) + int(round(literacy * 3.0)))


func _pawns_for_settlement(st: Dictionary, settlement_id: int) -> Array[HeelKawnian]:
	var all_pawns: Array[HeelKawnian] = PawnSpawner.find_pawns()
	if st.is_empty() and settlement_id < 0:
		return all_pawns
	var out: Array[HeelKawnian] = []
	var center_region: int = int(st.get("center_region", settlement_id)) if not st.is_empty() else settlement_id
	var regions: Dictionary = {}
	var regs_v: Variant = st.get("regions", PackedInt32Array()) if not st.is_empty() else PackedInt32Array()
	if regs_v is PackedInt32Array:
		for rk in regs_v:
			regions[int(rk)] = true
	for p in all_pawns:
		if p == null or not is_instance_valid(p) or p.data == null:
			continue
		var pawn_sid: int = int(p.data.settlement_id)
		var pawn_rk: int = WorldMemory._region_key(p.data.tile_pos.x, p.data.tile_pos.y) if WorldMemory != null else -1
		if pawn_sid == settlement_id or pawn_sid == center_region or regions.has(pawn_rk):
			out.append(p)
	return out


func _settlement_for_id(settlement_id: int) -> Dictionary:
	if SettlementMemory == null or not SettlementMemory.has_method("get_settlements"):
		return {}
	var settlements: Array = SettlementMemory.get_formal_settlements()
	if settlement_id >= 0 and settlement_id < settlements.size() and settlements[settlement_id] is Dictionary:
		return (settlements[settlement_id] as Dictionary).duplicate(true)
	for st_v in settlements:
		if not (st_v is Dictionary):
			continue
		var st: Dictionary = st_v as Dictionary
		var center: int = int(st.get("center_region", -1))
		if center == settlement_id or int(st.get("settlement_id", -999999)) == settlement_id:
			return st.duplicate(true)
	return {}


func _settlement_name(st: Dictionary, settlement_id: int) -> String:
	if settlement_id < 0:
		return "World"
	if st.is_empty():
		return "Settlement #%d" % settlement_id
	var name: String = str(st.get("culture_name", ""))
	if name.is_empty():
		name = str(st.get("name", ""))
	if name.is_empty():
		name = "Settlement #%d" % settlement_id
	return name


func _next_stage_score(score: int) -> int:
	var next: int = int(ceil(float(score + 1) / 10.0) * 10.0)
	return mini(100, maxi(10, next))


func _tick() -> int:
	return GameManager.tick_count if GameManager != null else 0
