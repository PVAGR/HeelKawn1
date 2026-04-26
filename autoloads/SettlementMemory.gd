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
const INTENT_UPDATE_INTERVAL_TICKS: int = 100
const MIN_INTENT_DWELL_TICKS: int = 2000
const CRITICAL_LOCAL_FOOD_PRESSURE: float = 0.9
const LOCAL_HOUSING_PAWNS_PER_REGION: float = 2.0
const LOCAL_HOUSING_PRESSURE_THRESHOLD: float = 0.8
const INTENT_GROW: String = "GROW"
const INTENT_HOARD: String = "HOARD"
const INTENT_DEFEND: String = "DEFEND"
const INTENT_RECOVER: String = "RECOVER"

var settlements: Array = []
## region_key -> state string (derived cache for O(1) regional queries)
var _region_state: Dictionary = {}
## region_key -> settlement center_region key (derived cache for O(1) intent joins)
var _region_center: Dictionary = {}
## center_region -> governance snapshot hash for change detection.
var _governance_snapshot: Dictionary = {}
## center_region -> whether at-war command announcement already fired for this war state.
var _war_command_announced: Dictionary = {}
## center_region -> whether battle spawn bridge fired for current war state.
var _war_battle_spawned: Dictionary = {}


func recompute(_world: World) -> void:
	settlements.clear()
	_region_state.clear()
	_region_center.clear()
	_war_command_announced.clear()
	_war_battle_spawned.clear()
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
		"war_status": {
			"state": "peace",
			"target_settlement_id": -1,
			"votes": [],
		},
		"current_intent": INTENT_GROW,
		"last_intent_tick": -1,
		"intent_lock_ticks": 0,
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
		_process_war_state(i, pawns)


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


func propose_war_for_pawn(ruler_id: int, target_settlement_id: int) -> bool:
	var src_idx: int = -1
	for i in range(settlements.size()):
		if settlements[i] is Dictionary and int((settlements[i] as Dictionary).get("current_ruler_id", -1)) == ruler_id:
			src_idx = i
			break
	if src_idx < 0 or target_settlement_id < 0 or target_settlement_id >= settlements.size() or src_idx == target_settlement_id:
		return false
	var st: Dictionary = settlements[src_idx] as Dictionary
	var ws: Dictionary = st.get("war_status", {"state": "peace", "target_settlement_id": -1, "votes": []})
	ws["state"] = "proposed"
	ws["target_settlement_id"] = target_settlement_id
	ws["votes"] = []
	st["war_status"] = ws
	settlements[src_idx] = st
	_resolve_war_votes(src_idx)
	return true


func _process_war_state(settlement_idx: int, pawns: Array[Pawn]) -> void:
	if settlement_idx < 0 or settlement_idx >= settlements.size() or not (settlements[settlement_idx] is Dictionary):
		return
	var st: Dictionary = settlements[settlement_idx] as Dictionary
	var ws: Dictionary = st.get("war_status", {"state": "peace", "target_settlement_id": -1, "votes": []})
	var set_pawns: Array[Pawn] = _pawns_in_settlement(st, pawns)
	var center: int = int(st.get("center_region", -1))
	if str(ws.get("state", "peace")) == "at_war":
		_assign_military_hierarchy(set_pawns)
		if center >= 0 and not bool(_war_command_announced.get(center, false)):
			_war_command_announced[center] = true
			print("[War] BattleMaster takes command of forces.")
		if center >= 0 and not bool(_war_battle_spawned.get(center, false)):
			var strength: float = get_settlement_military_score(settlement_idx)
			if _trigger_war_battle_spawn(center, int(ws.get("target_settlement_id", -1)), strength):
				_war_battle_spawned[center] = true
	else:
		if center >= 0:
			_war_command_announced.erase(center)
			_war_battle_spawned.erase(center)
		for p in set_pawns:
			if p.data != null:
				p.data.military_rank = "grunt"


func _resolve_war_votes(settlement_idx: int) -> void:
	if settlement_idx < 0 or settlement_idx >= settlements.size() or not (settlements[settlement_idx] is Dictionary):
		return
	var st: Dictionary = settlements[settlement_idx] as Dictionary
	var ws: Dictionary = st.get("war_status", {"state": "peace", "target_settlement_id": -1, "votes": []})
	var pawns: Array[Pawn] = _pawns_in_settlement(st, _living_pawns())
	if pawns.is_empty():
		ws["state"] = "peace"
		st["war_status"] = ws
		settlements[settlement_idx] = st
		return
	var council: Array[Pawn] = _top_influence(pawns, 5)
	var favor: int = 0
	var against: int = 0
	var vote_records: Array = []
	for p in council:
		var yes_vote: bool = _council_vote_yes(p)
		vote_records.append({"pawn_id": int(p.data.id), "body": "council", "yes": yes_vote})
		if yes_vote:
			favor += 1
		else:
			against += 1
	print("[War] Council Vote: %d-%d in favor. Preparing Messengers..." % [favor, against])
	if favor < 3:
		ws["state"] = "truce"
		ws["votes"] = vote_records
		st["war_status"] = ws
		settlements[settlement_idx] = st
		return
	ws["state"] = "mobilizing"
	var lords: Array[Pawn] = _top_influence_excluding(pawns, 20, council)
	var total_weight: float = 0.0
	var favor_weight: float = 0.0
	for p in lords:
		var loyalty: float = float(p.data.affinities.get("diplomacy", 0.5))
		var kills_proxy: float = float(p.data.tracked_skill_xp("combat")) * 0.01
		var w: float = 1.0 + loyalty + kills_proxy
		var yes_lord: bool = _senate_vote_yes(p)
		total_weight += w
		if yes_lord:
			favor_weight += w
		vote_records.append({"pawn_id": int(p.data.id), "body": "senate", "yes": yes_lord, "weight": w})
	var senate_passed: bool = total_weight > 0.0 and (favor_weight / total_weight) > 0.5
	var target_idx: int = int(ws.get("target_settlement_id", -1))
	if senate_passed and settlement_should_declare_war(settlement_idx, target_idx):
		ws["state"] = "at_war"
	else:
		ws["state"] = "truce"
	ws["votes"] = vote_records
	st["war_status"] = ws
	settlements[settlement_idx] = st
	if ws["state"] == "at_war":
		var set_pawns: Array[Pawn] = _pawns_in_settlement(st, _living_pawns())
		_assign_military_hierarchy(set_pawns)
		var center: int = int(st.get("center_region", -1))
		if center >= 0 and not bool(_war_command_announced.get(center, false)):
			_war_command_announced[center] = true
			print("[War] BattleMaster takes command of forces.")
		if center >= 0 and not bool(_war_battle_spawned.get(center, false)):
			var strength: float = get_settlement_military_score(settlement_idx)
			if _trigger_war_battle_spawn(center, int(ws.get("target_settlement_id", -1)), strength):
				_war_battle_spawned[center] = true


func _pawns_in_settlement(st: Dictionary, pawns: Array[Pawn]) -> Array[Pawn]:
	var regv: Variant = st.get("regions", PackedInt32Array())
	if not (regv is PackedInt32Array):
		return []
	var regs: PackedInt32Array = regv as PackedInt32Array
	var region_set: Dictionary = {}
	for rk in regs:
		region_set[int(rk)] = true
	var out: Array[Pawn] = []
	for p in pawns:
		if p.data == null:
			continue
		var rk: int = WorldMemory._region_key(p.data.tile_pos.x, p.data.tile_pos.y)
		if region_set.has(rk):
			out.append(p)
	return out


func _top_influence(pawns: Array[Pawn], count: int) -> Array[Pawn]:
	var arr: Array[Pawn] = pawns.duplicate()
	arr.sort_custom(func(a: Pawn, b: Pawn) -> bool:
		if a.data == null or b.data == null:
			return false
		if not is_equal_approx(a.data.influence, b.data.influence):
			return a.data.influence > b.data.influence
		return int(a.data.id) < int(b.data.id)
	)
	if arr.size() > count:
		arr.resize(count)
	return arr


func _top_influence_excluding(pawns: Array[Pawn], count: int, excluded: Array[Pawn]) -> Array[Pawn]:
	var blocked: Dictionary = {}
	for p in excluded:
		if p != null and p.data != null:
			blocked[int(p.data.id)] = true
	var filtered: Array[Pawn] = []
	for p in pawns:
		if p.data != null and not blocked.has(int(p.data.id)):
			filtered.append(p)
	return _top_influence(filtered, count)


func _council_vote_yes(p: Pawn) -> bool:
	if p == null or p.data == null:
		return false
	var pressure: float = float(ColonySimServices.get_food_pressure()) + float(ColonySimServices.get_housing_pressure())
	var score: float = p.data.influence * 0.01 + float(p.data.affinities.get("combat", 0.5)) * 1.5 - pressure * 0.3
	return score >= 1.0


func _senate_vote_yes(p: Pawn) -> bool:
	if p == null or p.data == null:
		return false
	var loyalty: float = float(p.data.affinities.get("diplomacy", 0.5))
	var kills_proxy: float = float(p.data.tracked_skill_xp("combat")) * 0.01
	return (loyalty + kills_proxy) >= 0.75


func _assign_military_hierarchy(pawns: Array[Pawn]) -> void:
	if pawns.is_empty():
		return
	var ranked: Array[Dictionary] = []
	for p in pawns:
		if p.data == null:
			continue
		var score: float = float(p.data.influence) + float(p.data.affinities.get("combat", 0.5)) * 100.0
		ranked.append({"pawn": p, "score": score, "id": int(p.data.id)})
	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var sa: float = float(a.get("score", 0.0))
		var sb: float = float(b.get("score", 0.0))
		if not is_equal_approx(sa, sb):
			return sa > sb
		return int(a.get("id", 0)) < int(b.get("id", 0))
	)
	for i in range(ranked.size()):
		var p: Pawn = ranked[i].pawn as Pawn
		if p == null or p.data == null:
			continue
		if i == 0:
			p.data.military_rank = "battlemaster"
		elif i < 4:
			p.data.military_rank = "commander"
		elif i < 14:
			p.data.military_rank = "captain"
		elif i < 34:
			p.data.military_rank = "sarj"
		else:
			p.data.military_rank = "grunt"


func settlement_should_declare_war(src_idx: int, target_idx: int) -> bool:
	if src_idx < 0 or target_idx < 0 or src_idx >= settlements.size() or target_idx >= settlements.size() or src_idx == target_idx:
		return false
	if not (settlements[src_idx] is Dictionary) or not (settlements[target_idx] is Dictionary):
		return false
	var src_st: Dictionary = settlements[src_idx] as Dictionary
	var dst_st: Dictionary = settlements[target_idx] as Dictionary
	var pressure: float = (
		float(ColonySimServices.get_food_pressure())
		+ float(ColonySimServices.get_housing_pressure())
		+ float(ColonySimServices.get_materials_pressure())
		+ float(ColonySimServices.get_haul_pressure())
	) / 4.0
	var living: Array[Pawn] = _living_pawns()
	var src_score: float = _settlement_military_score(_pawns_in_settlement(src_st, living))
	var dst_score: float = _settlement_military_score(_pawns_in_settlement(dst_st, living))
	return pressure >= 0.55 and src_score > dst_score


func _settlement_military_score(pawns: Array[Pawn]) -> float:
	var total: float = 0.0
	for p in pawns:
		if p == null or p.data == null:
			continue
		var combat_aff: float = float(p.data.affinities.get("combat", 0.5))
		var combat_skill: float = float(p.data.tracked_skill_xp("combat"))
		total += float(p.data.influence) + combat_aff * 25.0 + combat_skill * 0.1
	return total


func get_settlement_military_score(settlement_idx: int) -> float:
	if settlement_idx < 0 or settlement_idx >= settlements.size() or not (settlements[settlement_idx] is Dictionary):
		return 0.0
	var st: Dictionary = settlements[settlement_idx] as Dictionary
	return _settlement_military_score(_pawns_in_settlement(st, _living_pawns()))


func _trigger_war_battle_spawn(src_settlement_id: int, target_settlement_id: int, strength: float) -> bool:
	var tree: SceneTree = get_tree()
	if tree == null:
		return false
	var main_node: Node = tree.get_root().get_node_or_null("Main")
	if main_node == null or not main_node.has_method("trigger_war_battle_spawn"):
		return false
	return bool(main_node.call("trigger_war_battle_spawn", src_settlement_id, target_settlement_id, strength))


func get_war_profile_for_region(region_key: int) -> Dictionary:
	var st_v: Variant = get_settlement_at_region(region_key)
	if not (st_v is Dictionary):
		return {"state": "peace", "target_settlement_id": -1, "votes": []}
	var st: Dictionary = st_v as Dictionary
	var ws: Dictionary = st.get("war_status", {"state": "peace", "target_settlement_id": -1, "votes": []})
	return ws.duplicate(true)


func update_settlement_intents(tick: int) -> void:
	if tick % INTENT_UPDATE_INTERVAL_TICKS != 0:
		return
	var living_pawns: Array[Pawn] = _living_pawns()
	for i in range(settlements.size()):
		if not (settlements[i] is Dictionary):
			continue
		var st: Dictionary = settlements[i] as Dictionary
		var settlement_pawns: Array[Pawn] = _pawns_in_settlement(st, living_pawns)
		var local_food_pressure: float = _calculate_local_food_pressure(settlement_pawns)
		var local_housing_pressure: float = _calculate_local_housing_pressure(st, settlement_pawns)
		var war_state: String = str((st.get("war_status", {"state": "peace"}) as Dictionary).get("state", "peace"))
		var is_emergency: bool = local_food_pressure >= CRITICAL_LOCAL_FOOD_PRESSURE or war_state == "mobilizing" or war_state == "at_war"
		var lock_ticks: int = int(st.get("intent_lock_ticks", 0))
		if is_emergency and lock_ticks > 0:
			lock_ticks = 0
			st["intent_lock_ticks"] = 0
		elif lock_ticks > 0:
			lock_ticks = maxi(0, lock_ticks - INTENT_UPDATE_INTERVAL_TICKS)
			st["intent_lock_ticks"] = lock_ticks
			st["last_intent_tick"] = tick
			settlements[i] = st
			continue
		var old_intent: String = str(st.get("current_intent", INTENT_GROW))
		var new_intent: String = _derive_settlement_intent(st, local_food_pressure, local_housing_pressure)
		st["last_intent_tick"] = tick
		if old_intent != new_intent:
			st["current_intent"] = new_intent
			st["intent_lock_ticks"] = MIN_INTENT_DWELL_TICKS
			WorldMemory.record_event({
				"type": "settlement_intent_shift",
				"settlement_id": int(st.get("center_region", -1)),
				"old_intent": old_intent,
				"new_intent": new_intent,
				"tick": tick,
				"settlement_state": str(st.get("state", "unknown")),
				"war_state": war_state,
				"local_food_pressure": local_food_pressure,
				"local_housing_pressure": local_housing_pressure,
				"intent_lock_ticks": int(st.get("intent_lock_ticks", 0)),
			})
		settlements[i] = st


func _derive_settlement_intent(st: Dictionary, local_food_pressure: float, local_housing_pressure: float) -> String:
	var settlement_state: String = str(st.get("state", ""))
	var war_state: String = str((st.get("war_status", {"state": "peace"}) as Dictionary).get("state", "peace"))
	if settlement_state == "recovering" or settlement_state == "revivable":
		return INTENT_RECOVER
	if war_state == "mobilizing" or war_state == "at_war":
		return INTENT_DEFEND
	if local_food_pressure >= 0.55:
		return INTENT_HOARD
	if local_housing_pressure >= LOCAL_HOUSING_PRESSURE_THRESHOLD:
		return INTENT_RECOVER
	return INTENT_GROW


func _calculate_local_food_pressure(pawns: Array[Pawn]) -> float:
	if pawns.is_empty():
		return 0.0
	var hunger_sum: float = 0.0
	var count: int = 0
	for p in pawns:
		if p == null or p.data == null:
			continue
		# PawnData.hunger is 0..100 with higher=better (less hungry),
		# so pressure is inverse normalized hunger.
		hunger_sum += clamp(p.data.hunger, 0.0, 100.0)
		count += 1
	if count <= 0:
		return 0.0
	var avg_hunger: float = hunger_sum / float(count)
	return clamp(1.0 - (avg_hunger / 100.0), 0.0, 1.0)


func _calculate_local_housing_pressure(st: Dictionary, pawns: Array[Pawn]) -> float:
	if pawns.size() < 2:
		return 0.0
	var regv: Variant = st.get("regions", PackedInt32Array())
	if not (regv is PackedInt32Array):
		return 0.0
	var regions: PackedInt32Array = regv as PackedInt32Array
	var region_count: int = regions.size()
	if region_count <= 0:
		return 0.0
	# Coarse local crowding proxy: local population versus settlement footprint.
	var comfort_capacity: float = float(region_count) * LOCAL_HOUSING_PAWNS_PER_REGION
	if comfort_capacity <= 0.0:
		return 0.0
	var crowding_ratio: float = float(pawns.size()) / comfort_capacity
	return clamp(crowding_ratio - 1.0, 0.0, 1.0)


func get_settlement_intent_for_tile(tile_pos: Vector2i) -> String:
	var rk: int = WorldMemory._region_key(tile_pos.x, tile_pos.y)
	var st_v: Variant = get_settlement_at_region(rk)
	if st_v is Dictionary:
		return str((st_v as Dictionary).get("current_intent", INTENT_GROW))
	return INTENT_GROW
