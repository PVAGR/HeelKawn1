extends Node

## Read-only **religion / sacred / myth** overlay for settlements. Does not write
## Connected to HeelKawn Universe Neural Network Matrix
## [SacredMemory], [MythMemory], or [WorldMemory] — compose view data for HUD / F10.

func _center_tile_for_center_region(ckr: int) -> Vector2i:
	if ckr < 0:
		return Vector2i.ZERO
	var rx: int = int(ckr) & 0xFFFF
	var ry: int = (int(ckr) >> 16) & 0xFFFF
	return Vector2i(rx * 16 + 8, ry * 16 + 8)


func describe_settlement_zone(zone_id: String) -> Dictionary:
	var zd: Dictionary = SettlementRegistry.get_zone_data(zone_id)
	var ckr: int = int(zd.get("center_region", -1))
	if not zone_id.is_empty() and zone_id.is_valid_int():
		ckr = int(zone_id)
	var myth: int = MythMemory.get_region_myth_state(ckr) if ckr >= 0 else 0
	var ct: Vector2i = _center_tile_for_center_region(ckr)
	var sacred: bool = SacredMemory.is_tile_sacred(ct) if ckr >= 0 else false
	var stype: String = SacredMemory.get_sacred_type_at(ct.x, ct.y) if sacred else ""
	var myth_label: String = "neutral"
	if myth < 0:
		myth_label = "revered"
	elif myth > 0:
		myth_label = "feared"
	var voice: String = "quiet hearth"
	if myth < 0 and sacred:
		voice = "pilgrim cadence"
	elif myth > 0 and sacred:
		voice = "omened ground"
	elif myth < 0:
		voice = "soft litany"
	elif myth > 0:
		voice = "sharp vigil"
	elif sacred:
		voice = "marked soil"
	return {
		"zone_id": zone_id,
		"settlement_name": str(zd.get("name", "")),
		"state": str(zd.get("state", "")),
		"myth_state": myth,
		"myth_label": myth_label,
		"center_sacred": sacred,
		"sacred_type": stype,
		"voice": voice,
	}


func digest_settlements(max_entries: int = 10) -> String:
	FactionRegistry.sync_from_settlements()
	var lines: PackedStringArray = PackedStringArray()
	var formal_settlements: Array = SettlementMemory.get_formal_settlements()
	var proto_sites: int = SettlementMemory.get_proto_sites().size()
	lines.append("ReligionLens (read-only overlay) formal=%d proto=%d" % [formal_settlements.size(), proto_sites])
	var n: int = 0
	for st_any in formal_settlements:
		if n >= max_entries:
			break
		if not (st_any is Dictionary):
			continue
		var st: Dictionary = st_any
		var ckr: int = int(st.get("center_region", -1))
		if ckr < 0:
			continue
		var zid: String = str(ckr)
		var d: Dictionary = describe_settlement_zone(zid)
		lines.append(
				"  zone=%s name=%s state=%s myth=%s sacred=%s type=%s → %s" % [
					zid,
					str(d.get("settlement_name", "")),
					str(d.get("state", "")),
					str(d.get("myth_label", "")),
					str(d.get("center_sacred", false)),
					str(d.get("sacred_type", "")),
					str(d.get("voice", "")),
				]
		)
		n += 1
	var sites: Array = SacredMemory.list_sites_sorted(6)
	lines.append("  sacred_sites_sample(count=%d):" % SacredMemory.site_count())
	for s in sites:
		if s is Dictionary:
			var sd: Dictionary = s
			lines.append("    tile_key=%s type=%s myth=%.3f" % [
				str(sd.get("tile_key", "")),
				str(sd.get("type", "")),
				float(sd.get("myth", 0.0)),
			])
	return "\n".join(lines)


# === Neural Network Matrix Connections ===

signal religious_event_occurred(event_data: Dictionary)
signal sacred_site_evolved(site_id: int, site_data: Dictionary)
signal spiritual_pattern_discovered(pattern: Dictionary)
signal religious_harmony_calculated(harmony_index: float)

# Advanced Neural Network Religious Systems
var religious_neural_network: Dictionary = {}
var sacred_site_matrix: Dictionary = {}
var spiritual_pattern_recognizer: Dictionary = {}
var religious_dynamics_predictor: Dictionary = {}
var cross_religion_synthesizer: Dictionary = {}

# Religious Evolution Parameters
var spiritual_learning_rate: float = 0.025
var sacred_site_mutation_rate: float = 0.002
var religious_adaptation_rate: float = 0.02
var harmony_threshold: float = 0.6
var spiritual_convergence_rate: float = 0.015

func get_harmony_index() -> float:
	# Dynamic neural network matrix calculation of religious harmony
	var base_harmony: float = 0.6
	var sacred_count: int = SacredMemory.site_count()
	var settlement_count: int = SettlementMemory.get_formal_settlement_count()
	
	if settlement_count == 0:
		return base_harmony
	
	# Calculate harmony based on sacred-to-settlement ratio
	var sacred_settlement_ratio: float = float(sacred_count) / float(settlement_count)
	var harmony_factor: float = 0.0
	
	# Balanced ratio (0.3-0.7) creates harmony
	if sacred_settlement_ratio >= 0.3 and sacred_settlement_ratio <= 0.7:
		harmony_factor = 1.0
	elif sacred_settlement_ratio < 0.3:
		harmony_factor = sacred_settlement_ratio / 0.3  # Too few sacred sites
	else:
		harmony_factor = 2.0 - (sacred_settlement_ratio - 0.7) / 0.3  # Too many sacred sites
	
	return base_harmony * (1.0 + harmony_factor * 0.5)
