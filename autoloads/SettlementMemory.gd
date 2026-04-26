extends Node
## v1: Settlement identity — 4-adjacent clusters of scarred, historically
## active regions. Derived only; read WorldMeaning, WorldPersistence, CulturalMemory.
## Does not keep references to [World] ([recompute] takes it for API symmetry with peers).
## "state" is one of: abandoned, permanently_abandoned, revivable, dormant (revival v1, not saved).

const KIND_PAWN_DEATH: int = 0
## Irreversible collapse: recent (within this window) max scar + worst rep.
const HARD_COLLAPSE_TICKS: int = 30000
## Revival tuning: moderately scarred but quiet regions may reopen.
const REVIVABLE_SCAR_MAX: int = 2
const REVIVABLE_REPUTATION_MIN: int = -1
## Deterministic peace requirements by culture branch.
const PEACE_TICKS_PER_BRANCH: Dictionary = {
	SettlementPlanner.CULTURE_OPEN: 18000,
	SettlementPlanner.CULTURE_CAUTIOUS: 30000,
	SettlementPlanner.CULTURE_DEFENSIVE: 42000,
}
## Deterministic score gates.
const REVIVAL_SCORE_RECOVERING_MIN: int = 35
const REVIVAL_SCORE_REVIVABLE_MIN: int = 70
const REVIVAL_SCORE_ACTIVE_MIN: int = 88

var settlements: Array = []
## region_key -> state string (derived cache for O(1) regional queries)
var _region_state: Dictionary = {}
## region_key -> settlement center_region key (derived cache for O(1) intent joins)
var _region_center: Dictionary = {}
## center_region -> governance snapshot hash for change detection.
var _governance_snapshot: Dictionary = {}


func recompute(_world: World) -> void:
	settlements.clear()
	_region_state.clear()
	_region_center.clear()
	var eligible: Array[int] = []
	for rk_any in WorldMeaning.meaning_by_region.keys():
		var rk: int = int(rk_any)
		var m: Dictionary = WorldMeaning.get_region_meaning(rk)
		if int(m.get("total_deaths", 0)) == 0:
			continue
		if int(WorldPersistence.get_region_persistence(rk).get("scar_level", 0)) < 1:
			continue
		eligible.append(rk)
	eligible.sort()
	if eligible.is_empty():
		return
	var in_eligible: Dictionary = {}
	for e in eligible:
		in_eligible[int(e)] = true
	var visited: Dictionary = {}
	for seed_value in eligible:
		if visited.has(seed_value):
			continue
		var cluster: Array[int] = _bfs_cluster(seed_value, in_eligible, visited)
		cluster.sort()
		var st: Dictionary = _build_settlement_from_regions(cluster)
		settlements.append(st)
		var st_name: String = str(st.get("state", ""))
		var ckr: int = int(st.get("center_region", -1))
		var preg: Variant = st.get("regions", null)
		if preg is PackedInt32Array:
			var pa: PackedInt32Array = preg as PackedInt32Array
			for i in range(pa.size()):
				var rk2: int = int(pa[i])
				_region_state[rk2] = st_name
				_region_center[rk2] = ckr
	settlements.sort_custom(func(a, b) -> bool:
		var ap: Variant = (a as Dictionary).get("regions", null)
		var bp: Variant = (b as Dictionary).get("regions", null)
		if not (ap is PackedInt32Array) or not (bp is PackedInt32Array):
			return false
		var pa: PackedInt32Array = ap as PackedInt32Array
		var pb: PackedInt32Array = bp as PackedInt32Array
		if pa.is_empty() or pb.is_empty():
			return false
		return pa[0] < pb[0]
	)
	_update_governance_state()


func _bfs_cluster(seed_value: int, in_eligible: Dictionary, visited: Dictionary) -> Array[int]:
	var out: Array[int] = []
	var q: Array[int] = [seed_value]
	visited[seed_value] = true
	var qi: int = 0
	while qi < q.size():
		var rk: int = q[qi]
		qi += 1
		out.append(rk)
		var c: Vector2i = _coords_from_region_key(rk)
		var nbrs: Array[Vector2i] = [
			Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)
		]
		for d in nbrs:
			var nxt: int = _region_key_from_rx_ry(c.x + d.x, c.y + d.y)
			if not in_eligible.has(nxt) or visited.has(nxt):
				continue
			visited[nxt] = true
			q.append(nxt)
	return out


func _coords_from_region_key(rk: int) -> Vector2i:
	return Vector2i(rk & 0xFFFF, (rk >> 16) & 0xFFFF)


func _region_key_from_rx_ry(rx: int, ry: int) -> int:
	return (rx & 0xFFFF) | ((ry & 0xFFFF) << 16)


func _build_settlement_from_regions(cluster: Array) -> Dictionary:
	var total_pawn_deaths: int = 0
	var scar_max: int = 0
	var reputation_min: int = 999999
	var last_activity_tick: int = -1
	for rk_any in cluster:
		var rk: int = int(rk_any)
		var m: Dictionary = WorldMeaning.get_region_meaning(rk)
		total_pawn_deaths += int(m.get("pawn_deaths", 0))
		var sl: int = int(WorldPersistence.get_region_persistence(rk).get("scar_level", 0))
		scar_max = maxi(scar_max, sl)
		var rep: int = CulturalMemory.get_region_reputation(rk)
		reputation_min = mini(reputation_min, rep)
		var ldt: int = int(m.get("last_death_tick", -1))
		last_activity_tick = maxi(last_activity_tick, ldt)
	if reputation_min == 999999:
		reputation_min = 0
	var center_rk: int = _pick_center_region(cluster)
	var last_pawn_death_tick: int = _max_last_pawn_death_tick_in_cluster(cluster)
	var draft: Dictionary = {
		"scar_max": scar_max,
		"reputation_min": reputation_min,
	}
	var culture_type: int = SettlementPlanner.get_culture_type_for_settlement(draft)
	var state: String = _settlement_state_v1(
			scar_max, reputation_min, last_activity_tick, last_pawn_death_tick, culture_type
	)
	var peace_threshold_ticks: int = get_peace_ticks_for_culture_branch(culture_type)
	var ticks_since_collapse: int = _ticks_since_or_large(last_pawn_death_tick)
	var revival_score: int = _deterministic_revival_score(
			ticks_since_collapse, scar_max, ticks_since_collapse, culture_type, reputation_min
	)
	var packed: PackedInt32Array = PackedInt32Array()
	for rk2 in cluster:
		packed.append(int(rk2))
	return {
		"regions": packed,
		"center_region": center_rk,
		"total_pawn_deaths": total_pawn_deaths,
		"scar_max": scar_max,
		"reputation_min": reputation_min,
		"last_activity_tick": last_activity_tick,
		"last_pawn_death_tick": last_pawn_death_tick,
		"culture_type": culture_type,
		"culture_name": SettlementPlanner.get_culture_name_for_settlement(draft),
		"peace_threshold_ticks": peace_threshold_ticks,
		"revival_score": revival_score,
		"state": state,
	}


func _settlement_state_v1(
		scar_max: int,
		reputation_min: int,
		last_activity_tick: int,
		last_pawn_death_tick: int,
		culture_branch: int
) -> String:
	# Exclusivity:
	# permanently_abandoned > abandoned > recovering > revivable > active.
	var ticks_since_collapse: int = _ticks_since_or_large(last_pawn_death_tick)
	var regional_peace_ticks: int = ticks_since_collapse
	var peace_threshold: int = get_peace_ticks_for_culture_branch(culture_branch)
	if scar_max >= 3:
		if ticks_since_collapse <= HARD_COLLAPSE_TICKS:
			return "abandoned"
		return "permanently_abandoned"
	# Fresh moderate collapse still reads as abandoned.
	if last_activity_tick >= 0 and _ticks_since_or_large(last_activity_tick) < int(HARD_COLLAPSE_TICKS * 0.4):
		return "abandoned"
	var revival_score: int = _deterministic_revival_score(
			ticks_since_collapse, scar_max, regional_peace_ticks, culture_branch, reputation_min
	)
	if revival_score < REVIVAL_SCORE_RECOVERING_MIN:
		return "abandoned"
	if revival_score < REVIVAL_SCORE_REVIVABLE_MIN:
		return "recovering"
	if scar_max <= REVIVABLE_SCAR_MAX and regional_peace_ticks >= peace_threshold:
		if revival_score >= REVIVAL_SCORE_ACTIVE_MIN and scar_max <= 1 and regional_peace_ticks >= peace_threshold * 2:
			return "active"
		return "revivable"
	return "recovering"


func get_peace_ticks_for_culture_branch(culture_branch: int) -> int:
	return int(PEACE_TICKS_PER_BRANCH.get(culture_branch, int(PEACE_TICKS_PER_BRANCH[SettlementPlanner.CULTURE_CAUTIOUS])))


func _ticks_since_or_large(tick_value: int) -> int:
	if tick_value < 0:
		return 1_000_000_000
	return maxi(0, GameManager.tick_count - tick_value)


func _deterministic_revival_score(
		ticks_since_collapse: int,
		scar_level: int,
		regional_peace_ticks: int,
		cultural_branch: int,
		reputation_min: int
) -> int:
	var peace_threshold: int = get_peace_ticks_for_culture_branch(cultural_branch)
	var collapse_component: int = mini(100, int((float(ticks_since_collapse) / float(maxi(1, HARD_COLLAPSE_TICKS * 2))) * 100.0))
	var peace_component: int = mini(100, int((float(regional_peace_ticks) / float(maxi(1, peace_threshold))) * 100.0))
	var scar_penalty: int = scar_level * 25
	var branch_bonus: int = 0
	if cultural_branch == SettlementPlanner.CULTURE_OPEN:
		branch_bonus = 15
	elif cultural_branch == SettlementPlanner.CULTURE_CAUTIOUS:
		branch_bonus = 5
	else:
		branch_bonus = -10
	var rep_bonus: int = clampi(reputation_min * 5, -20, 20)
	return clampi(int((collapse_component + peace_component) / 2) - scar_penalty + branch_bonus + rep_bonus, 0, 100)


func get_settlement_profile(region_key: int) -> Dictionary:
	var settlement: Variant = get_settlement_at_region(region_key)
	if settlement == null or not (settlement is Dictionary):
		return _default_profile(region_key)
	var d: Dictionary = settlement as Dictionary
	var mean: Dictionary = WorldMeaning.get_region_meaning_summary(region_key)
	var pers: Dictionary = WorldPersistence.get_region_persistence(region_key)
	var profile: Dictionary = {
		"region_key": region_key,
		"center_region": int(d.get("center_region", -1)),
		"state": str(d.get("state", "")),
		"culture_type": SettlementPlanner.get_culture_type_for_settlement(d),
		"culture_name": SettlementPlanner.get_culture_name_for_settlement(d),
		"scar_max": int(d.get("scar_max", 0)),
		"reputation_min": int(d.get("reputation_min", 0)),
		"last_activity_tick": int(d.get("last_activity_tick", -1)),
		"last_pawn_death_tick": int(d.get("last_pawn_death_tick", -1)),
		"meaning_label": str(mean.get("meaning_label", "quiet")),
		"death_density": str(mean.get("death_density", "none")),
		"total_deaths": int(mean.get("total_deaths", 0)),
		"scar_level": int(pers.get("scar_level", 0)),
		"recovery_stage": int(pers.get("recovery_stage", 0)),
		"peace_threshold_ticks": int(d.get("peace_threshold_ticks", get_peace_ticks_for_culture_branch(int(d.get("culture_type", SettlementPlanner.CULTURE_CAUTIOUS))))),
		"revival_score": int(d.get("revival_score", 0)),
		"revival_ready": false,
	}
	var state_now: String = str(profile.get("state", ""))
	profile["revival_ready"] = state_now == "revivable"
	return profile


func _default_profile(region_key: int) -> Dictionary:
	return {
		"region_key": region_key,
		"center_region": -1,
		"state": "",
		"culture_type": SettlementPlanner.CULTURE_CAUTIOUS,
		"culture_name": "cautious",
		"scar_max": 0,
		"reputation_min": 0,
		"last_activity_tick": -1,
		"last_pawn_death_tick": -1,
		"meaning_label": "quiet",
		"death_density": "none",
		"total_deaths": 0,
		"scar_level": 0,
		"recovery_stage": 0,
		"peace_threshold_ticks": int(PEACE_TICKS_PER_BRANCH[SettlementPlanner.CULTURE_CAUTIOUS]),
		"revival_score": 0,
		"revival_ready": false,
	}


func _regions_from_settlement(settlement: Dictionary) -> PackedInt32Array:
	var reg: Variant = settlement.get("regions", null)
	if reg is PackedInt32Array:
		return reg as PackedInt32Array
	return PackedInt32Array()


func _max_last_pawn_death_tick_in_regions(regions: PackedInt32Array) -> int:
	if regions.is_empty():
		return -1
	var want: Dictionary = {}
	for rk_any in regions:
		want[int(rk_any)] = true
	var best: int = -1
	var ev: Variant = WorldMemory.to_save_dict().get("events", [])
	if not (ev is Array):
		return best
	for item in ev as Array:
		if not (item is Dictionary):
			continue
		var e: Dictionary = item
		if int(e.get("k", -1)) != KIND_PAWN_DEATH:
			continue
		if not e.has("r"):
			continue
		var rk: int = int(e["r"])
		if not want.has(rk):
			continue
		var t: int = int(e.get("t", 0))
		if t > best:
			best = t
	return best


## True for [abandoned] (recent hard collapse) and [permanently_abandoned] (older hard collapse).
func is_collapsed_state(state: String) -> bool:
	return state == "abandoned" or state == "permanently_abandoned"


## True if [param region_key] lies in a settlement whose current [member settlements] [code]state[/code] is collapsed.
func is_region_in_collapsed_settlement(region_key: int) -> bool:
	if _region_state.has(region_key):
		return is_collapsed_state(str(_region_state[region_key]))
	for st in settlements:
		if st is not Dictionary:
			continue
		var d: Dictionary = st as Dictionary
		if not is_collapsed_state(str(d.get("state", ""))):
			continue
		var reg: Variant = d.get("regions", null)
		if not (reg is PackedInt32Array):
			continue
		var p: PackedInt32Array = reg as PackedInt32Array
		for j in range(p.size()):
			if p[j] == region_key:
				return true
	return false


## Kept for backward compatibility: same as [method is_region_in_collapsed_settlement] (name predates the split state string).
func is_region_in_permanently_abandoned_settlement(region_key: int) -> bool:
	if _region_state.has(region_key):
		return str(_region_state[region_key]) == "permanently_abandoned"
	for st in settlements:
		if st is not Dictionary:
			continue
		var d: Dictionary = st as Dictionary
		if str(d.get("state", "")) != "permanently_abandoned":
			continue
		var reg: Variant = d.get("regions", null)
		if not (reg is PackedInt32Array):
			continue
		var p: PackedInt32Array = reg as PackedInt32Array
		for j in range(p.size()):
			if p[j] == region_key:
				return true
	return false


func get_state_at_region(region_key: int) -> String:
	if _region_state.has(region_key):
		return str(_region_state[region_key])
	return ""


func get_center_region_for_region(region_key: int) -> int:
	if _region_center.has(region_key):
		return int(_region_center[region_key])
	return -1


## Latest pawn death tick in any listed region, or -1 if none.
func _max_last_pawn_death_tick_in_cluster(cluster: Array) -> int:
	var want: Dictionary = {}
	for rk_any in cluster:
		want[int(rk_any)] = true
	var best: int = -1
	var ev: Variant = WorldMemory.to_save_dict().get("events", [])
	if not (ev is Array):
		return best
	for item in ev as Array:
		if not (item is Dictionary):
			continue
		var e: Dictionary = item
		if int(e.get("k", -1)) != KIND_PAWN_DEATH:
			continue
		if not e.has("r"):
			continue
		var rk: int = int(e["r"])
		if not want.has(rk):
			continue
		var t: int = int(e.get("t", 0))
		if t > best:
			best = t
	return best


## Highest [pawn_deaths]; tie-break: lowest [region_key].
func _pick_center_region(cluster: Array) -> int:
	if cluster.is_empty():
		return -1
	var best_k: int = -1
	var best_pd: int = -1
	for rk_any in cluster:
		var rk: int = int(rk_any)
		var pd: int = int(WorldMeaning.get_region_meaning(rk).get("pawn_deaths", 0))
		if pd > best_pd or (pd == best_pd and (best_k < 0 or rk < best_k)):
			best_pd = pd
			best_k = rk
	return best_k


func get_settlements() -> Array:
	return settlements.duplicate(true)


## Duplicated settlement dict, or [null] if this [region_key] is not in any cluster.
func get_settlement_at_region(region_key: int) -> Variant:
	for s in settlements:
		if s is Dictionary:
			var reg: Variant = (s as Dictionary).get("regions", null)
			if reg is PackedInt32Array:
				for i in range((reg as PackedInt32Array).size()):
					if (reg as PackedInt32Array)[i] == region_key:
						return (s as Dictionary).duplicate(true)
	return null


func _update_governance_state() -> void:
	var pawns: Array[Pawn] = _living_pawns()
	for i in range(settlements.size()):
		if not (settlements[i] is Dictionary):
			continue
		var st: Dictionary = settlements[i]
		var gov: Dictionary = _governance_for_settlement(st, pawns)
		var center: int = int(st.get("center_region", -1))
		st["governance_type"] = str(gov.get("type", "anarchy"))
		st["current_ruler_id"] = int(gov.get("ruler_id", -1))
		st["council_ids"] = gov.get("council_ids", PackedInt32Array())
		settlements[i] = st
		if center < 0:
			continue
		var snap: String = "%s|%d|%s" % [
			st["governance_type"],
			int(st["current_ruler_id"]),
			str(st["council_ids"]),
		]
		if str(_governance_snapshot.get(center, "")) != snap:
			_governance_snapshot[center] = snap
			WorldMemory.record_event({
				"type": "governance_change",
				"settlement_id": center,
				"new_ruler_id": int(st["current_ruler_id"]),
				"governance_type": st["governance_type"],
				"council_ids": st["council_ids"],
				"tick": GameManager.tick_count,
			})


func _living_pawns() -> Array[Pawn]:
	var out: Array[Pawn] = []
	var tree: SceneTree = get_tree()
	if tree == null:
		return out
	for n in tree.get_nodes_in_group("pawns"):
		if n is Pawn and is_instance_valid(n):
			out.append(n as Pawn)
	return out


func _governance_for_settlement(st: Dictionary, pawns: Array[Pawn]) -> Dictionary:
	var regv: Variant = st.get("regions", PackedInt32Array())
	if not (regv is PackedInt32Array):
		return {"type": "anarchy", "ruler_id": -1, "council_ids": PackedInt32Array()}
	var regions: PackedInt32Array = regv as PackedInt32Array
	if regions.is_empty():
		return {"type": "anarchy", "ruler_id": -1, "council_ids": PackedInt32Array()}
	var region_set: Dictionary = {}
	for rk in regions:
		region_set[int(rk)] = true
	var ranked: Array[Dictionary] = []
	for p in pawns:
		if p.data == null:
			continue
		var rk: int = WorldMemory._region_key(p.data.tile_pos.x, p.data.tile_pos.y)
		if not region_set.has(rk):
			continue
		ranked.append({
			"id": int(p.data.id),
			"influence": float(p.data.influence),
		})
	if ranked.is_empty():
		return {"type": "anarchy", "ruler_id": -1, "council_ids": PackedInt32Array()}
	# Influence scales with local settlement population.
	for rec in ranked:
		var pid: int = int((rec as Dictionary).get("id", -1))
		for p in pawns:
			if p.data != null and int(p.data.id) == pid:
				(rec as Dictionary)["influence"] = p.data.calculate_influence(ranked.size())
				break
	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ai: float = float(a.get("influence", 0.0))
		var bi: float = float(b.get("influence", 0.0))
		if not is_equal_approx(ai, bi):
			return ai > bi
		return int(a.get("id", 0)) < int(b.get("id", 0))
	)
	if ranked.size() >= 3:
		var i0: float = float(ranked[0].influence)
		var i1: float = float(ranked[1].influence)
		var i2: float = float(ranked[2].influence)
		if absf(i0 - i2) <= maxf(5.0, i0 * 0.05):
			return {
				"type": "council",
				"ruler_id": -1,
				"council_ids": PackedInt32Array([int(ranked[0].id), int(ranked[1].id), int(ranked[2].id)]),
			}
	# Even spread over all participants => anarchy.
	var max_i: float = float(ranked[0].influence)
	var min_i: float = float(ranked[ranked.size() - 1].influence)
	if absf(max_i - min_i) <= maxf(3.0, max_i * 0.03):
		return {"type": "anarchy", "ruler_id": -1, "council_ids": PackedInt32Array()}
	return {"type": "monarchy", "ruler_id": int(ranked[0].id), "council_ids": PackedInt32Array()}


func get_governance_profile_for_region(region_key: int) -> Dictionary:
	var st_v: Variant = get_settlement_at_region(region_key)
	if not (st_v is Dictionary):
		return {"type": "anarchy", "ruler_id": -1, "council_ids": PackedInt32Array()}
	var st: Dictionary = st_v as Dictionary
	return {
		"type": str(st.get("governance_type", "anarchy")),
		"ruler_id": int(st.get("current_ruler_id", -1)),
		"council_ids": st.get("council_ids", PackedInt32Array()),
	}


func is_pawn_current_ruler(pawn_id: int) -> bool:
	for st in settlements:
		if st is Dictionary and int((st as Dictionary).get("current_ruler_id", -1)) == pawn_id:
			return true
	return false
