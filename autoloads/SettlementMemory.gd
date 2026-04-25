extends Node
## v1: Settlement identity — 4-adjacent clusters of scarred, historically
## active regions. Derived only; read WorldMeaning, WorldPersistence, CulturalMemory.
## Does not keep references to [World] ([recompute] takes it for API symmetry with peers).
## "state" is one of: abandoned, permanently_abandoned, revivable, dormant (revival v1, not saved).

const KIND_PAWN_DEATH: int = 0
## Irreversible collapse: recent (within this window) max scar + worst rep.
const HARD_COLLAPSE_TICKS: int = 30000

var settlements: Array = []
## region_key -> state string (derived cache for O(1) regional queries)
var _region_state: Dictionary = {}
## region_key -> settlement center_region key (derived cache for O(1) intent joins)
var _region_center: Dictionary = {}


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
	var state: String = _settlement_state_v1(cluster, scar_max, reputation_min, last_activity_tick)
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
		"state": state,
	}


func _settlement_state_v1(
		cluster: Array, scar_max: int, reputation_min: int, last_activity_tick: int
) -> String:
	# Exclusivity: hard-collapse [abandoned] / [permanently_abandoned] first, then [revivable], else [dormant].
	var now: int = GameManager.tick_count
	if scar_max == 3 and reputation_min <= -2 and last_activity_tick >= 0:
		if now - last_activity_tick <= HARD_COLLAPSE_TICKS:
			return "abandoned"
		return "permanently_abandoned"
	var last_pawn: int = _max_last_pawn_death_tick_in_cluster(cluster)
	var recovery: int = WorldPersistence.RECOVERY_TICKS
	if scar_max <= 1 and reputation_min >= 0:
		if last_pawn < 0 or now - last_pawn >= recovery:
			return "revivable"
	return "dormant"


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
