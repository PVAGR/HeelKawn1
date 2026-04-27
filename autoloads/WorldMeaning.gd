extends Node
## Phase 2.2: deterministic, derived metrics from WorldMemory only.
## No writes to memory, no world mutation, no RNG, no UI.

## Matches WorldMemory Kind enum (keep in sync; literal ints avoid autoload class timing).
const KIND_PAWN_DEATH: int = 0
const KIND_ANIMAL_DEATH: int = 1

## region_key (int) -> aggregated entry Dictionary
var meaning_by_region: Dictionary = {}


func recompute() -> void:
	meaning_by_region.clear()
	# Public snapshot; WorldMemory is not modified by this.
	var ev: Variant = WorldMemory.to_save_dict().get("events", [])
	if not (ev is Array):
		return
	# Count pawn/animal deaths and max tick per region
	for item in ev:
		if not item is Dictionary:
			continue
		var e: Dictionary = item
		if not e.has("r") or not e.has("k"):
			continue
		var rk: int = int(e["r"])
		var k: int = int(e["k"])
		var t: int = int(e.get("t", 0))
		if not meaning_by_region.has(rk):
			meaning_by_region[rk] = {
				"pawn_deaths": 0,
				"animal_deaths": 0,
				"total_deaths": 0,
				"death_density": "none",
				"meaning_label": "quiet",
				"last_death_tick": -1,
			}
		var rec: Dictionary = meaning_by_region[rk]
		if k == KIND_PAWN_DEATH:
			rec["pawn_deaths"] = int(rec["pawn_deaths"]) + 1
		elif k == KIND_ANIMAL_DEATH:
			rec["animal_deaths"] = int(rec["animal_deaths"]) + 1
		var last: int = int(rec["last_death_tick"])
		if t > last:
			rec["last_death_tick"] = t
	# Derive total_deaths and death_density
	for rk in meaning_by_region.keys():
		var r2: Dictionary = meaning_by_region[rk]
		var pdc: int = int(r2.get("pawn_deaths", 0))
		var adc: int = int(r2.get("animal_deaths", 0))
		var tot: int = pdc + adc
		r2["total_deaths"] = tot
		r2["death_density"] = classify_death_density(tot)
		r2["meaning_label"] = describe_meaning_label(tot)


func get_region_meaning(region_key: int) -> Dictionary:
	if meaning_by_region.has(region_key):
		return (meaning_by_region[region_key] as Dictionary).duplicate(true)
	return _default_region_entry()


func classify_death_density(total_deaths: int) -> String:
	if total_deaths <= 0:
		return "none"
	if total_deaths <= 2:
		return "low"
	if total_deaths <= 5:
		return "medium"
	return "high"


func describe_meaning_label(total_deaths: int) -> String:
	match classify_death_density(total_deaths):
		"none":
			return "quiet"
		"low":
			return "scarred"
		"medium":
			return "bloodied"
		"high":
			return "grave"
	return "quiet"


func get_region_meaning_label(region_key: int) -> String:
	return str(get_region_meaning(region_key).get("meaning_label", "quiet"))


func get_region_meaning_summary(region_key: int) -> Dictionary:
	var out: Dictionary = get_region_meaning(region_key)
	out["meaning_label"] = str(out.get("meaning_label", describe_meaning_label(int(out.get("total_deaths", 0)))))
	return out


func _default_region_entry() -> Dictionary:
	return {
		"pawn_deaths": 0,
		"animal_deaths": 0,
		"total_deaths": 0,
		"death_density": "none",
		"last_death_tick": -1,
	}


func region_count() -> int:
	return meaning_by_region.size()


func total_regions_with_deaths() -> int:
	var n: int = 0
	for rk in meaning_by_region.keys():
		var rec: Dictionary = meaning_by_region[rk]
		if int(rec.get("total_deaths", 0)) > 0:
			n += 1
	return n


## Derived tags for a settlement zone (zone_id string is decimal center_region).
## Deterministic facts + regional meaning only (no RNG). Used by revival, identity, observer lens.
func get_zone_tags(zone_id: String) -> PackedStringArray:
	var tags: PackedStringArray = PackedStringArray()
	if zone_id.is_empty() or not zone_id.is_valid_int():
		return tags
	var ckr: int = int(zone_id)
	if ckr < 0:
		return tags

	var stats: Dictionary = WorldMemory.get_zone_aggregate(zone_id)
	var ml: String = get_region_meaning_label(ckr)
	var deaths_proxy: int = int(stats.get("death_clusters", 0))
	var builds_proxy: int = int(stats.get("builds", 0))
	var monuments_proxy: int = int(stats.get("monuments", 0))
	var bio_exh: int = int(stats.get("biome_exhaustion", 0))

	# Quiet land + no exhaustion proxy → eligible for stabilization / revival framing
	if ml == "quiet" and bio_exh == 0:
		tags.append("stabilizing_biome")

	match ml:
		"scarred", "bloodied", "grave":
			tags.append("echo_falls")

	if ml == "grave" or deaths_proxy >= 6:
		tags.append("ancient_ruin")

	# Repeated governance / intent signal → “myth-grade” footprint (deterministic thresholds)
	if builds_proxy >= 2 or monuments_proxy >= 2:
		tags.append("myth_origin")

	return tags
