extends Node
class_name FactionRegistry

## Houses / proto-factions keyed by settlement **zone_id** (string of center_region int).
## v1: Deterministic names from (zone_id + settlement display name); no RNG.
## Sync is **lazy** — call [method sync_from_settlements] after settlement recompute,
## on load, and from debug reports.
## v2: Adds inter-faction relations, diplomacy event recording, schism/fragmentation hooks,
## and faction influence scoring. All deterministic via WorldRNG.

const VALID_RELATIONS: Array[String] = ["neutral", "allied", "hostile", "trade_partner", "vassal"]
const RELATION_DEFAULT: String = "neutral"

## Schism/fragmentation thresholds (tunable).
const FRAGMENTATION_POPULATION_MIN: int = 15
const FRAGMENTATION_MAX_SCHISM_POP_RATIO: float = 0.45

var _house_by_zone: Dictionary = {}
var _relations: Dictionary = {}


func clear() -> void:
	_house_by_zone.clear()
	_relations.clear()


func to_save_dict() -> Dictionary:
	return {
		"houses": _house_by_zone.duplicate(true),
		"relations": _relations.duplicate(true),
	}


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
	var rel: Variant = (d as Dictionary).get("relations", {})
	if rel is Dictionary:
		for k in (rel as Dictionary).keys():
			var v: Variant = (rel as Dictionary)[k]
			if v is Dictionary:
				_relations[str(k)] = (v as Dictionary).duplicate(true)


static func sync_from_settlements() -> void:
	var inst: FactionRegistry = Engine.get_singleton("FactionRegistry") as FactionRegistry
	if inst == null:
		return
	for st_any in SettlementMemory.get_formal_settlements():
		if not (st_any is Dictionary):
			continue
		var st: Dictionary = st_any
		var ckr: int = int(st.get("center_region", -1))
		if ckr < 0:
			continue
		var zid: String = str(ckr)
		if inst._house_by_zone.has(zid):
			continue
		var nm: String = str(st.get("name", "Unnamed"))
		inst._house_by_zone[zid] = inst._derive_house_record(zid, nm)


func _derive_house_record(zone_id: String, settlement_name: String) -> Dictionary:
	var house_mix: int = int(String(zone_id + "|" + settlement_name).hash()) & 0x7FFFFFFF
	var house_roots: Array[String] = [
		"Ash", "Rill", "Gar", "Vel", "Tor", "Kai", "Sen", "Mor", "Bryn", "Lor",
	]
	var house_tags: Array[String] = [
		"kin", "thread", "mark", "well", "shard", "bloom", "hearth", "path",
	]
	var ri: int = house_mix % house_roots.size()
	var ti: int = (house_mix / 7) % house_tags.size()
	var hid: String = "%s_%s" % [house_roots[ri], house_tags[ti]]
	var r: float = float((house_mix >> 3) & 0xFF) / 255.0
	var g: float = float((house_mix >> 11) & 0xFF) / 255.0
	var b: float = float((house_mix >> 19) & 0xFF) / 255.0
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


## --- Inter-faction relations (symmetric) ---

static func _relation_pair_key(a: String, b: String) -> String:
	if a < b:
		return "%s|||%s" % [a, b]
	return "%s|||%s" % [b, a]


func set_relation(faction_a: String, faction_b: String, relation: String) -> void:
	if not VALID_RELATIONS.has(relation):
		push_warning("[FactionRegistry] Invalid relation '%s', defaulting to '%s'" % [relation, RELATION_DEFAULT])
		relation = RELATION_DEFAULT
	var key: String = _relation_pair_key(faction_a, faction_b)
	_relations[key] = {
		"faction_a": faction_a,
		"faction_b": faction_b,
		"relation": relation,
		"set_tick": GameManager.tick_count if GameManager != null else 0,
	}


func get_relation(faction_a: String, faction_b: String) -> String:
	if faction_a == faction_b:
		return "allied"
	var key: String = _relation_pair_key(faction_a, faction_b)
	if _relations.has(key):
		return str((_relations[key] as Dictionary).get("relation", RELATION_DEFAULT))
	return RELATION_DEFAULT


func get_all_relations() -> Dictionary:
	var out: Dictionary = {}
	for key in _relations:
		var entry: Dictionary = (_relations[key] as Dictionary).duplicate(true)
		out[key] = entry
	return out


## --- Diplomacy events ---

func record_diplomacy_event(faction_a: String, faction_b: String, event_type: String, details: String) -> void:
	if WorldMemory == null:
		return
	var tick_now: int = GameManager.tick_count if GameManager != null else 0
	var zone_a: int = _zone_for_faction(faction_a)
	var zone_b: int = _zone_for_faction(faction_b)
	WorldMemory.record_event({
		"type": "diplomacy_%s" % event_type,
		"k": WorldMemory.Kind.CONFLICT_EVENT if event_type == "war_declared" else WorldMemory.Kind.WORLD_EVENT,
		"t": tick_now,
		"faction_a": faction_a,
		"faction_b": faction_b,
		"event_type": event_type,
		"details": details,
		"zone_a": zone_a,
		"zone_b": zone_b,
		"narrative": _build_diplomacy_narrative(faction_a, faction_b, event_type, details),
	})


func _build_diplomacy_narrative(a: String, b: String, event_type: String, details: String) -> String:
	var disp_a: String = _faction_display_name(a)
	var disp_b: String = _faction_display_name(b)
	match event_type:
		"alliance_formed":
			return "%s and %s have forged an alliance.%s" % [disp_a, disp_b, _detail_suffix(details)]
		"war_declared":
			return "%s has declared war on %s.%s" % [disp_a, disp_b, _detail_suffix(details)]
		"trade_pact":
			return "%s and %s have established a trade pact.%s" % [disp_a, disp_b, _detail_suffix(details)]
		"vassalage":
			return "%s has submitted to %s as vassal.%s" % [disp_a, disp_b, _detail_suffix(details)]
		"peace_treaty":
			return "%s and %s have signed a peace treaty.%s" % [disp_a, disp_b, _detail_suffix(details)]
		_:
			return "%s and %s: %s.%s" % [disp_a, disp_b, event_type.replace("_", " "), _detail_suffix(details)]


func _detail_suffix(details: String) -> String:
	if details.is_empty():
		return ""
	return " (%s)" % details


func _faction_display_name(faction_id: String) -> String:
	for zone_id in _house_by_zone:
		var h: Dictionary = _house_by_zone[zone_id] as Dictionary
		if str(h.get("house_id", "")) == faction_id:
			return str(h.get("house_display", faction_id))
	return faction_id


func _zone_for_faction(faction_id: String) -> int:
	for zone_id in _house_by_zone:
		var h: Dictionary = _house_by_zone[zone_id] as Dictionary
		if str(h.get("house_id", "")) == faction_id:
			return int(zone_id)
	return -1


## --- Schism hook: split a house into two factions ---

func trigger_schism(zone_id: String) -> Dictionary:
	if not _house_by_zone.has(zone_id):
		return {}
	var original: Dictionary = (_house_by_zone[zone_id] as Dictionary).duplicate(true)
	var orig_id: String = str(original.get("house_id", ""))
	var orig_display: String = str(original.get("house_display", ""))

	## Deterministic schism name: derive from original + zone + tick
	var schism_seed: int = int(String("schism|%s|%d" % [zone_id, GameManager.tick_count if GameManager != null else 0]).hash()) & 0x7FFFFFFF
	var schism_roots: Array[String] = [
		"Dusk", "Thorn", "Iron", "Pale", "Red", "Black", "Fallen", "Broken", "Wilde", "Grim",
	]
	var schism_suffixes: Array[String] = [
		"branch", "splinter", "remnant", "exile", "castoff", "sever", "rift", "shade",
	]
	var ri: int = schism_seed % schism_roots.size()
	var si: int = (schism_seed / 11) % schism_suffixes.size()
	var new_id: String = "%s_%s" % [schism_roots[ri], schism_suffixes[si]]
	var new_display: String = "%s %s" % [schism_roots[ri], schism_suffixes[si]]

	var r: float = float((schism_seed >> 3) & 0xFF) / 255.0
	var g: float = float((schism_seed >> 11) & 0xFF) / 255.0
	var b: float = float((schism_seed >> 19) & 0xFF) / 255.0

	var schism_house: Dictionary = {
		"house_id": new_id,
		"house_display": new_display,
		"seed_settlement_name": str(original.get("seed_settlement_name", "")),
		"banner_rgb": [r, g, b],
		"schism_from": orig_id,
		"schism_tick": GameManager.tick_count if GameManager != null else 0,
	}
	_house_by_zone[zone_id] = schism_house

	## The new faction starts hostile to the parent
	set_relation(orig_id, new_id, "hostile")

	## Record the schism event
	if WorldMemory != null:
		var tick_now: int = GameManager.tick_count if GameManager != null else 0
		WorldMemory.record_event({
			"type": "faction_schism",
			"k": WorldMemory.Kind.SOCIAL_SCHISM,
			"t": tick_now,
			"zone_id": zone_id,
			"parent_faction": orig_id,
			"new_faction": new_id,
			"new_display": new_display,
			"narrative": "The house of %s has fractured — the %s break away." % [orig_display, new_display],
		})

	return {
		"parent": original,
		"schism": schism_house,
		"zone_id": zone_id,
	}


## --- Fragmentation check: suggest which factions should split ---

func check_fragmentation() -> Array[Dictionary]:
	sync_from_settlements()
	var suggestions: Array[Dictionary] = []

	for zone_id in _house_by_zone:
		var h: Dictionary = _house_by_zone[zone_id] as Dictionary
		var faction_id: String = str(h.get("house_id", ""))
		var influence: float = get_faction_influence(faction_id)

		## Check 1: population-based fragmentation
		var pop: int = _get_zone_population(zone_id)
		if pop >= FRAGMENTATION_POPULATION_MIN:
			var pop_ratio: float = float(pop) / float(maxi(pop, 1))
			if pop_ratio > FRAGMENTATION_MAX_SCHISM_POP_RATIO:
				suggestions.append({
					"zone_id": zone_id,
					"faction_id": faction_id,
					"reason": "population",
					"population": pop,
					"influence": influence,
				})
				continue

		## Check 2: internal relations — if this faction is hostile to many neighbors
		var hostile_count: int = _count_hostile_relations(faction_id)
		if hostile_count >= 2 and pop >= 5:
			suggestions.append({
				"zone_id": zone_id,
				"faction_id": faction_id,
				"reason": "hostile_pressure",
				"hostile_count": hostile_count,
				"population": pop,
				"influence": influence,
			})
			continue

		## Check 3: settlement distance — if the zone spans a large area
		var max_dist: float = _get_zone_spread(zone_id)
		if max_dist > 64.0 and pop >= 8:
			suggestions.append({
				"zone_id": zone_id,
				"faction_id": faction_id,
				"reason": "territorial_spread",
				"max_tile_distance": max_dist,
				"population": pop,
				"influence": influence,
			})

	return suggestions


func _count_hostile_relations(faction_id: String) -> int:
	var count: int = 0
	for key in _relations:
		var entry: Dictionary = _relations[key] as Dictionary
		if str(entry.get("relation", "")) == "hostile":
			if str(entry.get("faction_a", "")) == faction_id or str(entry.get("faction_b", "")) == faction_id:
				count += 1
	return count


func _get_zone_population(zone_id: String) -> int:
	if SettlementMemory == null:
		return 0
	var ckr: int = int(zone_id)
	for st_any in SettlementMemory.settlements:
		if not (st_any is Dictionary):
			continue
		var st: Dictionary = st_any as Dictionary
		if int(st.get("center_region", -1)) == ckr:
			return int(st.get("population", 0))
	return 0


func _get_zone_spread(zone_id: String) -> float:
	if SettlementMemory == null:
		return 0.0
	var ckr: int = int(zone_id)
	for st_any in SettlementMemory.settlements:
		if not (st_any is Dictionary):
			continue
		var st: Dictionary = st_any as Dictionary
		if int(st.get("center_region", -1)) == ckr:
			var regs: Variant = st.get("regions", null)
			if regs is PackedInt32Array:
				var pa: PackedInt32Array = regs as PackedInt32Array
				if pa.size() < 2:
					return 0.0
				var max_dist: float = 0.0
				var center_tile: Vector2i = SettlementPlanner._center_tile_of_region_key(ckr)
				for i in range(pa.size()):
					var rk: int = int(pa[i])
					var rx: int = rk & 0xFFFF
					var ry: int = (rk >> 16) & 0xFFFF
					var tile: Vector2i = Vector2i(rx << 4, ry << 4)
					var dx: float = float(tile.x - center_tile.x)
					var dy: float = float(tile.y - center_tile.y)
					var dist: float = sqrt(dx * dx + dy * dy)
					if dist > max_dist:
						max_dist = dist
				return max_dist
	return 0.0


## --- Faction influence scoring ---

func get_faction_influence(faction_id: String) -> float:
	var zone_id: String = _find_zone_for_faction(faction_id)
	if zone_id.is_empty():
		return 0.0

	var pop_score: float = 0.0
	var building_score: float = 0.0
	var knowledge_score: float = 0.0

	if SettlementMemory != null:
		var ckr: int = int(zone_id)
		for st_any in SettlementMemory.settlements:
			if not (st_any is Dictionary):
				continue
			var st: Dictionary = st_any as Dictionary
			if int(st.get("center_region", -1)) == ckr:
				pop_score = _score_population(int(st.get("population", 0)))
				building_score = _score_buildings(int(st.get("buildings_constructed", 0)))
				break

	knowledge_score = _score_knowledge_carriers(zone_id)

	var total: float = pop_score * 0.4 + building_score * 0.35 + knowledge_score * 0.25
	return clampf(total, 0.0, 1.0)


func _find_zone_for_faction(faction_id: String) -> String:
	for zid in _house_by_zone:
		var h: Dictionary = _house_by_zone[zid] as Dictionary
		if str(h.get("house_id", "")) == faction_id:
			return str(zid)
	return ""


func _score_population(pop: int) -> float:
	if pop <= 0:
		return 0.0
	return clampf(float(pop) / 50.0, 0.0, 1.0)


func _score_buildings(buildings: int) -> float:
	if buildings <= 0:
		return 0.0
	return clampf(float(buildings) / 30.0, 0.0, 1.0)


func _score_knowledge_carriers(zone_id: String) -> float:
	if KnowledgeSystem == null:
		return 0.0
	var ckr: int = int(zone_id)
	var carrier_count: int = 0
	if KnowledgeSystem.has_method("get_all_carriers"):
		var carriers: Array = KnowledgeSystem.get_all_carriers()
		for c_any in carriers:
			if not (c_any is Dictionary):
				continue
			var c: Dictionary = c_any as Dictionary
			var pawn_id: int = int(c.get("pawn_id", -1))
			if pawn_id < 0:
				continue
			var ps: Node = get_tree().get_root().get_node_or_null("Main/WorldViewport/PawnSpawner")
			if ps != null and ps.has_method("pawn_data_for_id"):
				var pd: Variant = ps.call("pawn_data_for_id", pawn_id)
				if pd is HeelKawnianData:
					var tile: Vector2i = (pd as HeelKawnianData).tile_pos
					var rk: int = WorldMemory._region_key(tile.x, tile.y)
					if rk == ckr:
						carrier_count += 1
	if carrier_count <= 0:
		return 0.0
	return clampf(float(carrier_count) / 5.0, 0.0, 1.0)


## Observer / focus readout: one line for the deterministic house of a settlement zone.
static func append_focus_house_lines(out: PackedStringArray, center_region: int) -> void:
	var inst: FactionRegistry = Engine.get_singleton("FactionRegistry") as FactionRegistry
	if inst == null:
		return
	if center_region < 0:
		return
	inst.sync_from_settlements()
	var house: Dictionary = inst.get_house_for_zone(str(center_region))
	if house.is_empty():
		out.append("House: (none — no settlement synced for this zone yet)")
		return
	var disp: String = str(house.get("house_display", house.get("house_id", "")))
	var hid: String = str(house.get("house_id", ""))
	var seed_nm: String = str(house.get("seed_settlement_name", "")).strip_edges()
	var rgb_v: Variant = house.get("banner_rgb", [])
	var rgb_s: String = "n/a"
	if rgb_v is Array:
		var rgb: Array = rgb_v as Array
		if rgb.size() >= 3:
			rgb_s = "%.2f,%.2f,%.2f" % [float(rgb[0]), float(rgb[1]), float(rgb[2])]
	var settlement_bit: String = (" · of %s" % seed_nm) if not seed_nm.is_empty() else ""
	out.append("House: %s [%s]%s | banner %s" % [disp, hid, settlement_bit, rgb_s])


func house_count() -> int:
	sync_from_settlements()
	return get_synced_house_count()


## Call after [method sync_from_settlements] to avoid duplicate full scans in one frame.
func get_synced_house_count() -> int:
	return _house_by_zone.size()


func debug_summary_block() -> String:
	sync_from_settlements()
	var lines: PackedStringArray = PackedStringArray()
	lines.append("FactionRegistry (houses keyed by settlement center_region)")
	lines.append("  house_count=%d" % _house_by_zone.size())
	lines.append("  relation_count=%d" % _relations.size())
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
	if not _relations.is_empty():
		lines.append("  --- relations ---")
		var rel_keys: Array = _relations.keys()
		rel_keys.sort()
		for rk in rel_keys:
			var entry: Dictionary = _relations[rk] as Dictionary
			lines.append(
					"  %s <-> %s : %s" % [
						str(entry.get("faction_a", "")),
						str(entry.get("faction_b", "")),
						str(entry.get("relation", "neutral")),
					]
			)
	return "\n".join(lines)
