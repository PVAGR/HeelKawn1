extends Node

## Houses / proto-factions keyed by settlement **zone_id** (string of center_region int).
## v1: Deterministic names from (zone_id + settlement display name); no RNG.
## Sync is **lazy** — call [method sync_from_settlements] after settlement recompute,
## on load, and from debug reports.

var _house_by_zone: Dictionary = {}


func clear() -> void:
	_house_by_zone.clear()


func to_save_dict() -> Dictionary:
	return {"houses": _house_by_zone.duplicate(true)}


func from_save_dict(d: Variant) -> void:
	clear()
	if d is not Dictionary:
		return
	var h: Variant = (d as Dictionary).get("houses", {})
	if h is Dictionary:
		for k in (h as Dictionary).keys():
			var v: Variant = (h as Dictionary)[k]
			if v is Dictionary:
				_house_by_zone[str(k)] = (v as Dictionary).duplicate(true)


func sync_from_settlements() -> void:
	for st_any in SettlementMemory.settlements:
		if not (st_any is Dictionary):
			continue
		var st: Dictionary = st_any
		var ckr: int = int(st.get("center_region", -1))
		if ckr < 0:
			continue
		var zid: String = str(ckr)
		if _house_by_zone.has(zid):
			continue
		var nm: String = str(st.get("name", "Unnamed"))
		_house_by_zone[zid] = _derive_house_record(zid, nm)


func _derive_house_record(zone_id: String, settlement_name: String) -> Dictionary:
	var seed: int = int(String(zone_id + "|" + settlement_name).hash()) & 0x7FFFFFFF
	var house_roots: Array[String] = [
		"Ash", "Rill", "Gar", "Vel", "Tor", "Kai", "Sen", "Mor", "Bryn", "Lor",
	]
	var house_tags: Array[String] = [
		"kin", "thread", "mark", "well", "shard", "bloom", "hearth", "path",
	]
	var ri: int = seed % house_roots.size()
	var ti: int = (seed / 7) % house_tags.size()
	var hid: String = "%s_%s" % [house_roots[ri], house_tags[ti]]
	var r: float = float((seed >> 3) & 0xFF) / 255.0
	var g: float = float((seed >> 11) & 0xFF) / 255.0
	var b: float = float((seed >> 19) & 0xFF) / 255.0
	return {
		"house_id": hid,
		"house_display": "%s %s" % [house_roots[ri], house_tags[ti]],
		"seed_settlement_name": settlement_name,
		"banner_rgb": [r, g, b],
	}


func get_house_for_zone(zone_id: String) -> Dictionary:
	if _house_by_zone.has(zone_id):
		return (_house_by_zone[zone_id] as Dictionary).duplicate(true)
	return {}


func house_count() -> int:
	sync_from_settlements()
	return get_synced_house_count()


## Call after [method sync_from_settlements] to avoid duplicate full scans in one frame.
func get_synced_house_count() -> int:
	return _house_by_zone.size()


func debug_summary_block() -> String:
	sync_from_settlements()
	var lines: PackedStringArray = PackedStringArray()
	lines.append("FactionRegistry (house stub per settlement zone)")
	lines.append("  house_count=%d" % _house_by_zone.size())
	var keys: Array = _house_by_zone.keys()
	keys.sort()
	for k in keys:
		var h: Dictionary = _house_by_zone[k] as Dictionary
		lines.append(
				"  zone=%s  id=%s  display=%s  from_settlement=%s" % [
					str(k),
					str(h.get("house_id", "")),
					str(h.get("house_display", "")),
					str(h.get("seed_settlement_name", "")),
				]
		)
	return "\n".join(lines)
