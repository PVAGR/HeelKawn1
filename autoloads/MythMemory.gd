extends Node
## Myth & Fear v1: long-term emotional weight derived at recompute, not a kernel;
## [member _rebirth_count_by_center] is persisted so rebirth history survives load.

const KIND_PAWN_DEATH: int = 0
## Same order of magnitude as [constant WorldPersistence.RECOVERY_TICKS] (quiet gap between waves).
const WAVE_SEP_TICKS: int = 20000

## region_key (int) -> -1 / 0 / +1
var _region_myth: Dictionary = {}
## center_region_key string -> successful rebirth count (SettlementRebirth; save/load)
var _rebirth_count_by_center: Dictionary = {}


func clear() -> void:
	_region_myth.clear()
	_rebirth_count_by_center.clear()


func to_save_dict() -> Dictionary:
	return {"rebirth_count": _rebirth_count_by_center.duplicate(true)}


func from_save_dict(d: Variant) -> void:
	_rebirth_count_by_center.clear()
	if d is not Dictionary:
		return
	var raw: Variant = (d as Dictionary).get("rebirth_count", {})
	if not (raw is Dictionary):
		return
	for k0 in (raw as Dictionary).keys():
		_rebirth_count_by_center[str(k0)] = int((raw as Dictionary)[k0])


## Successful rebirth spawns (session; key may also load from save in [from_save_dict]).
func get_rebirth_success_count_for_center(center_rk: int) -> int:
	if center_rk < 0:
		return 0
	return int(_rebirth_count_by_center.get(str(center_rk), 0))


## Call when Settlement Rebirth spawns a pawn in a revivable cluster (session fact for -1 score).
func register_rebirth_success(center_rk: int) -> void:
	if center_rk < 0:
		return
	var ks: String = str(center_rk)
	_rebirth_count_by_center[ks] = int(_rebirth_count_by_center.get(ks, 0)) + 1


## -1 = revered, 0 = neutral, +1 = feared
func get_region_myth_state(region_key: int) -> int:
	if _region_myth.has(region_key):
		return int(_region_myth[region_key])
	return 0


## PERFORMANCE: Return only regions with non-zero myth state.
func get_regions_with_myth_state() -> Dictionary:
	var result: Dictionary = {}
	for rk in _region_myth:
		if int(_region_myth[rk]) != 0:
			result[int(rk)] = true
	return result


func recompute(_w: World) -> void:
	_region_myth.clear()
	for s in SettlementMemory.settlements:
		if s is not Dictionary:
			continue
		var d: Dictionary = s as Dictionary
		var reg0: Variant = d.get("regions", null)
		if not (reg0 is PackedInt32Array):
			continue
		var pack0: PackedInt32Array = reg0 as PackedInt32Array
		if pack0.is_empty():
			continue
		var ckr0: int = int(d.get("center_region", int(pack0[0])))
		var st0: String = str(d.get("state", ""))
		var sc0: int = 0
		sc0 += _repeated_collapse_bonus(pack0)
		if st0 == "abandoned":
			sc0 += 1
		elif st0 == "permanently_abandoned":
			sc0 += 2
		if st0 == "revivable" and int(_rebirth_count_by_center.get(str(ckr0), 0)) >= 1:
			sc0 -= 1
		sc0 = clampi(sc0, -2, 3)
		var m1: int = 0
		if sc0 >= 2:
			m1 = 1
		elif sc0 <= -1:
			m1 = -1
		for u in range(pack0.size()):
			_region_myth[int(pack0[u])] = m1


## +1 for each "repeat" after the first high-density collapse wave in this settlement.
func _repeated_collapse_bonus(regions: PackedInt32Array) -> int:
	var want0: Dictionary = {}
	for w in range(regions.size()):
		want0[int(regions[w])] = true
	var ev0: Array[Dictionary] = WorldMemory.get_events()
	if ev0.is_empty():
		return 0
	var seq: Array[Dictionary] = []
	for e in ev0:
		if e is not Dictionary:
			continue
		var ed: Dictionary = e
		if int(ed.get("k", -1)) != KIND_PAWN_DEATH:
			continue
		if not ed.has("r") or not ed.has("t"):
			continue
		var rrk: int = int(ed["r"])
		if not want0.has(rrk):
			continue
		seq.append({"t": int(ed.get("t", 0))})
	if seq.is_empty():
		return 0
	seq.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("t", 0)) < int(b.get("t", 0))
	)
	var waves: Array = []
	var cur: Array[Dictionary] = []
	var last_tt: int = -2_000_000_000
	for item in seq:
		var tcur: int = int(item.get("t", 0))
		if not cur.is_empty() and (tcur - last_tt) > WAVE_SEP_TICKS:
			waves.append(cur)
			cur = []
		cur.append(item)
		last_tt = tcur
	if not cur.is_empty():
		waves.append(cur)
	var high_w: int = 0
	for w2 in waves:
		var cws: int = (w2 as Array).size()
		if str(WorldMeaning.classify_death_density(cws)) == "high":
			high_w += 1
	return maxi(0, high_w - 1)
