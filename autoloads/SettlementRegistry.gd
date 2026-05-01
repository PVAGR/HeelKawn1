extends Node
## Phase 4.1 — facade over [SettlementMemory] for [SettlementPersistence]: stable zone ids,
## abandoned_at ticks, and merged persistence fields across recomputes.

## center_region (as string) -> int tick when this zone was first seen as [code]abandoned[/code]
var _abandoned_tick_by_zone: Dictionary = {}
## center_region (string) -> overlay keys merged onto settlement dicts (state, flags, etc.)
var _persistence_overlay: Dictionary = {}


func _zone_id_from_center(center_rk: int) -> String:
	if center_rk < 0:
		return ""
	return str(center_rk)


## Merge [member _persistence_overlay] and [member _abandoned_tick_by_zone] onto [param st] in place.
func upsert_overlay_field(zone_id: String, key: String, value: Variant) -> void:
	if zone_id.is_empty() or zone_id == "-1":
		return
	if not _persistence_overlay.has(zone_id):
		_persistence_overlay[zone_id] = {}
	var inner: Variant = _persistence_overlay[zone_id]
	if inner is Dictionary:
		(inner as Dictionary)[key] = value


func get_overlay_field(zone_id: String, key: String) -> Variant:
	if not _persistence_overlay.has(zone_id):
		return null
	var inner: Variant = _persistence_overlay[zone_id]
	if inner is Dictionary:
		return (inner as Dictionary).get(key)
	return null


func merge_persistence_into_settlement(st: Dictionary) -> void:
	var ckr: int = int(st.get("center_region", -1))
	var zid: String = _zone_id_from_center(ckr)
	if zid.is_empty():
		return
	if str(st.get("state", "")) == "abandoned" and not _abandoned_tick_by_zone.has(zid):
		_abandoned_tick_by_zone[zid] = GameManager.tick_count
	if _abandoned_tick_by_zone.has(zid):
		st["abandoned_at_tick"] = int(_abandoned_tick_by_zone[zid])
	if _persistence_overlay.has(zid):
		var o: Dictionary = _persistence_overlay[zid]
		for k in o.keys():
			st[k] = o[k]
	if not st.has("id") or str(st.get("id", "")).is_empty():
		st["id"] = zid
	if not st.has("name"):
		st["name"] = "Unnamed"
	if not st.has("traits"):
		st["traits"] = []
	if not st.has("lineage_parent"):
		st["lineage_parent"] = st.get("id", zid)
	if not st.has("reoccupied_tick"):
		st["reoccupied_tick"] = 0
	if not st.has("zone_id"):
		st["zone_id"] = zid


## After [SettlementPersistence] changes a settlement, snapshot overlay so the next
## [method SettlementMemory.recompute] can reapply.
func commit_zone_state(zone_id: String, st: Dictionary) -> void:
	var tr: Variant = st.get("traits", [])
	if tr is PackedStringArray:
		var ta: Array = []
		for t in tr as PackedStringArray:
			ta.append(str(t))
		tr = ta
	_persistence_overlay[zone_id] = {
		"state": str(st.get("state", "")),
		"persist_flags": (st.get("persist_flags", []) as Array).duplicate() if st.has("persist_flags") else [],
		"revival_window_open": st.get("revival_window_open", false),
		"id": str(st.get("id", zone_id)),
		"name": str(st.get("name", "Unnamed")),
		"traits": (tr as Array).duplicate() if tr is Array else [],
		"lineage_parent": str(st.get("lineage_parent", st.get("id", zone_id))),
		"reoccupied_tick": int(st.get("reoccupied_tick", 0)),
		"zone_id": str(st.get("zone_id", zone_id)),
	}


func get_abandoned_zone_ids() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for s in SettlementMemory.settlements:
		if s is not Dictionary:
			continue
		var d: Dictionary = s
		merge_persistence_into_settlement(d)
		if str(d.get("state", "")) == "abandoned":
			var zid: String = str(int(d.get("center_region", -1)))
			if not zid.is_empty() and zid != "-1":
				out.append(zid)
	return out


## Live dict from [member SettlementMemory.settlements] (same reference), with merges applied.
func get_zone_data(zone_id: String) -> Dictionary:
	if zone_id.is_empty():
		return {}
	for s in SettlementMemory.settlements:
		if s is not Dictionary:
			continue
		var d: Dictionary = s
		if str(int(d.get("center_region", -1))) == zone_id:
			merge_persistence_into_settlement(d)
			return d
	return {}


func _region_coords(rk: int) -> Vector2i:
	return Vector2i(int(rk) & 0xFFFF, (int(rk) >> 16) & 0xFFFF)


## Public: get the center tile coordinates of a zone from its zone_id (center_region as string)
func get_zone_center(zone_id: String) -> Vector2i:
	var zone_data: Dictionary = get_zone_data(zone_id)
	if zone_data.is_empty():
		return Vector2i(-1, -1)
	var center_rk: int = int(zone_data.get("center_region", -1))
	if center_rk < 0:
		return Vector2i(-1, -1)
	return _region_coords(center_rk)


## Count other settlements whose merged state is [i]active[/i] (dormant or revivable) within
## Chebyshev distance (in 16x16 [i]region[/i] cells) of [param zone_id].[br]
## [param radius] is in region cells (e.g. 2 = 5x5 block of region centers in Chebyshev norm).
func count_active_neighbors(zone_id: String, radius: int) -> int:
	var me: Dictionary = get_zone_data(zone_id)
	if me.is_empty():
		return 0
	var c0: int = int(me.get("center_region", -1))
	if c0 < 0:
		return 0
	var p0: Vector2i = _region_coords(c0)
	var n: int = 0
	for s in SettlementMemory.settlements:
		if s is not Dictionary:
			continue
		var d: Dictionary = s
		var z2: String = str(int(d.get("center_region", -1)))
		if z2 == zone_id or z2.is_empty() or z2 == "-1":
			continue
		merge_persistence_into_settlement(d)
		var st2: String = str(d.get("state", ""))
		if st2 != "dormant" and st2 != "revivable" and st2 != "active":
			continue
		var c1: int = int(d.get("center_region", -1))
		if c1 < 0:
			continue
		var p1: Vector2i = _region_coords(c1)
		var dx: int = abs(p0.x - p1.x)
		var dy: int = abs(p0.y - p1.y)
		if maxi(dx, dy) <= radius:
			n += 1
	return n


func clear() -> void:
	_abandoned_tick_by_zone.clear()
	_persistence_overlay.clear()


func to_save_dict() -> Dictionary:
	return {
		"abandoned_at": _abandoned_tick_by_zone.duplicate(true),
		"overlay": _persistence_overlay.duplicate(true),
	}


func from_save_dict(d: Variant) -> void:
	clear()
	if d == null or not (d is Dictionary):
		return
	var o: Dictionary = d
	var a: Variant = o.get("abandoned_at", {})
	if a is Dictionary:
		for k in (a as Dictionary).keys():
			_abandoned_tick_by_zone[str(k)] = int((a as Dictionary)[k])
	var ov: Variant = o.get("overlay", {})
	if ov is Dictionary:
		for k in (ov as Dictionary).keys():
			var inner: Variant = (ov as Dictionary)[k]
			if inner is Dictionary:
				_persistence_overlay[str(k)] = (inner as Dictionary).duplicate(true)
