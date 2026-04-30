# --- Observation API extension: cultural style and wildlife trend ---
# Returns a derived or placeholder value for now; extend with real logic as needed.
func get_cultural_style(region_key: int) -> String:
       # Example: derive from tags or meaning label
       var tags: PackedStringArray = get_zone_tags(str(region_key))
       if "myth_origin" in tags:
	       return "mythic"
       if "ancient_ruin" in tags:
	       return "ruin"
       if "echo_falls" in tags:
	       return "echo"
       # Fallback to meaning label
       return get_region_meaning_label(region_key)

func get_wildlife_trend(region_key: int) -> String:
       # Placeholder: derive from death_density or meaning label
       var meaning: Dictionary = get_region_meaning(region_key)
       var density: String = meaning.get("death_density", "none")
       match density:
	       "none":
		       return "stable"
	       "low":
		       return "declining"
	       "medium":
		       return "scarce"
	       "high":
		       return "extinct"
       return "unknown"
extends Node
## Phase 2.2: deterministic, derived metrics from WorldMemory only.
## No writes to WorldMemory, no world mutation, no UI. Interpretation only (RNG allowed only for labeled non-canonical presentation tiers — default paths stay deterministic-from-facts).

## Matches WorldMemory Kind enum (keep in sync; literal ints avoid autoload class timing).
const KIND_PAWN_DEATH: int = 0
const KIND_ANIMAL_DEATH: int = 1

## region_key (int) -> aggregated entry Dictionary
var meaning_by_region: Dictionary = {}

## Settlement meanings: settlement_id -> derived meanings
var meaning_by_settlement: Dictionary = {}

## Bloodline meanings: bloodline_id -> derived meanings
var meaning_by_bloodline: Dictionary = {}

## Time period meanings: time period -> derived meanings
var meaning_by_period: Dictionary = {}


func recompute() -> void:
	meaning_by_region.clear()
	meaning_by_settlement.clear()
	meaning_by_bloodline.clear()
	meaning_by_period.clear()
	
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
	
	# Derive enhanced meanings
	_derive_settlement_meanings(ev)
	_derive_bloodline_meanings(ev)
	_derive_period_meanings(ev)


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

# === Enhanced Meaning Derivation ===

func _derive_settlement_meanings(events: Array) -> void:
	for event in events:
		if not event is Dictionary:
			continue

		var settlement_id: Variant = event.get("settlement_id")
		if settlement_id == null:
			continue

		var sid: int = int(settlement_id)
		if not meaning_by_settlement.has(sid):
			meaning_by_settlement[sid] = {
				"starvation_count": 0,
				"teaching_success_count": 0,
				"teaching_failure_count": 0,
				"conflict_count": 0,
				"stability_score": 1.0,
				"meaning_label": "founding"
			}

		var rec: Dictionary = meaning_by_settlement[sid]
		var event_type: String = event.get("type", "")

		match event_type:
			"starvation":
				rec["starvation_count"] += 1
			"teaching_success":
				rec["teaching_success_count"] += 1
			"teaching_failure":
				rec["teaching_failure_count"] += 1
			"conflict_start":
				rec["conflict_count"] += 1

	for sid in meaning_by_settlement:
		var rec: Dictionary = meaning_by_settlement[sid]
		var starvation: int = rec["starvation_count"]
		var teaching_success: int = rec["teaching_success_count"]
		var teaching_failure: int = rec["teaching_failure_count"]
		var conflicts: int = rec["conflict_count"]

		var teaching_ratio: float = 1.0
		if teaching_success + teaching_failure > 0:
			teaching_ratio = float(teaching_success) / float(teaching_success + teaching_failure)

		var stability: float = (
			teaching_ratio * 0.4 +
			(1.0 - min(conflicts / 10.0, 1.0)) * 0.3 +
			(1.0 - min(starvation / 5.0, 1.0)) * 0.3
		)
		rec["stability_score"] = stability

		if starvation >= 3:
			rec["meaning_label"] = "famine_stricken"
		elif conflicts >= 5:
			rec["meaning_label"] = "war_torn"
		elif teaching_success >= 5:
			rec["meaning_label"] = "learned"
		elif stability > 0.8:
			rec["meaning_label"] = "stable"
		elif stability > 0.5:
			rec["meaning_label"] = "struggling"
		else:
			rec["meaning_label"] = "collapsing"

func _derive_bloodline_meanings(events: Array) -> void:
	for event in events:
		if not event is Dictionary:
			continue

		var bloodline_id: Variant = event.get("bloodline_id")
		if bloodline_id == null:
			continue

		var bid: int = int(bloodline_id)
		if not meaning_by_bloodline.has(bid):
			meaning_by_bloodline[bid] = {
				"death_count": 0,
				"authority_grants": 0,
				"knowledge_carriers": 0,
				"meaning_label": "obscure"
			}

		var rec: Dictionary = meaning_by_bloodline[bid]
		var event_type: String = event.get("type", "")

		match event_type:
			"pawn_death":
				rec["death_count"] += 1
			"authority_grant":
				rec["authority_grants"] += 1
			"knowledge_acquisition":
				rec["knowledge_carriers"] += 1

	for bid in meaning_by_bloodline:
		var rec: Dictionary = meaning_by_bloodline[bid]
		var deaths: int = rec["death_count"]
		var authority: int = rec["authority_grants"]
		var knowledge: int = rec["knowledge_carriers"]

		if knowledge >= 3:
			rec["meaning_label"] = "keepers_of_fire"
		elif authority >= 3:
			rec["meaning_label"] = "protectors"
		elif deaths >= 5:
			rec["meaning_label"] = "fallen"
		elif deaths >= 2:
			rec["meaning_label"] = "scarred"
		elif authority >= 1:
			rec["meaning_label"] = "rising"
		else:
			rec["meaning_label"] = "obscure"

func _derive_period_meanings(events: Array) -> void:
	var current_tick: int = GameManager.tick_count if GameManager else 0

	for event in events:
		if not event is Dictionary:
			continue

		var tick: int = event.get("tick", 0)
		var period: int = int(tick / 10000)

		if not meaning_by_period.has(period):
			meaning_by_period[period] = {
				"death_count": 0,
				"conflict_count": 0,
				"discovery_count": 0,
				"collapse_count": 0,
				"meaning_label": "quiet"
			}

		var rec: Dictionary = meaning_by_period[period]
		var event_type: String = event.get("type", "")

		match event_type:
			"pawn_death", "animal_death":
				rec["death_count"] += 1
			"conflict_start":
				rec["conflict_count"] += 1
			"knowledge_discovery":
				rec["discovery_count"] += 1
			"settlement_collapse":
				rec["collapse_count"] += 1

	for period in meaning_by_period:
		var rec: Dictionary = meaning_by_period[period]
		var deaths: int = rec["death_count"]
		var conflicts: int = rec["conflict_count"]
		var discoveries: int = rec["discovery_count"]
		var collapses: int = rec["collapse_count"]

		if collapses >= 1:
			rec["meaning_label"] = "age_of_ruin"
		elif conflicts >= 5:
			rec["meaning_label"] = "age_of_war"
		elif discoveries >= 3:
			rec["meaning_label"] = "age_of_wonder"
		elif deaths >= 10:
			rec["meaning_label"] = "age_of_sorrow"
		elif conflicts >= 2:
			rec["meaning_label"] = "age_of_strife"
		elif discoveries >= 1:
			rec["meaning_label"] = "age_of_discovery"
		else:
			rec["meaning_label"] = "quiet_age"

func get_settlement_meaning(settlement_id: int) -> Dictionary:
	if meaning_by_settlement.has(settlement_id):
		return meaning_by_settlement[settlement_id].duplicate(true)
	return {
		"starvation_count": 0,
		"teaching_success_count": 0,
		"teaching_failure_count": 0,
		"conflict_count": 0,
		"stability_score": 1.0,
		"meaning_label": "founding"
	}

# === Bloodline Meaning Integration ===

func record_pawn_death(pawn_id: int, bloodline_id: int) -> void:
	# Record pawn death for bloodline meaning derivation
	if not meaning_by_bloodline.has(bloodline_id):
		meaning_by_bloodline[bloodline_id] = {
			"death_count": 0,
			"authority_grants": 0,
			"knowledge_carriers": 0,
			"meaning_label": "obscure"
		}
	
	meaning_by_bloodline[bloodline_id]["death_count"] += 1
	
	# Trigger meaning re-evaluation
	_update_bloodline_meaning(bloodline_id)


func record_authority_grant(pawn_id: int, bloodline_id: int) -> void:
	# Record authority grant for bloodline meaning derivation
	if not meaning_by_bloodline.has(bloodline_id):
		meaning_by_bloodline[bloodline_id] = {
			"death_count": 0,
			"authority_grants": 0,
			"knowledge_carriers": 0,
			"meaning_label": "obscure"
		}
	
	meaning_by_bloodline[bloodline_id]["authority_grants"] += 1
	
	# Trigger meaning re-evaluation
	_update_bloodline_meaning(bloodline_id)


func record_knowledge_carrier(pawn_id: int, bloodline_id: int) -> void:
	# Record knowledge carrier for bloodline meaning derivation
	if not meaning_by_bloodline.has(bloodline_id):
		meaning_by_bloodline[bloodline_id] = {
			"death_count": 0,
			"authority_grants": 0,
			"knowledge_carriers": 0,
			"meaning_label": "obscure"
		}
	
	meaning_by_bloodline[bloodline_id]["knowledge_carriers"] += 1
	
	# Trigger meaning re-evaluation
	_update_bloodline_meaning(bloodline_id)


func _update_bloodline_meaning(bloodline_id: int) -> void:
	if not meaning_by_bloodline.has(bloodline_id):
		return
	
	var rec: Dictionary = meaning_by_bloodline[bloodline_id]
	var deaths: int = rec["death_count"]
	var authority: int = rec["authority_grants"]
	var knowledge: int = rec["knowledge_carriers"]
	
	if knowledge >= 3:
		rec["meaning_label"] = "keepers_of_fire"
	elif authority >= 3:
		rec["meaning_label"] = "protectors"
	elif deaths >= 5:
		rec["meaning_label"] = "fallen"
	elif deaths >= 2:
		rec["meaning_label"] = "scarred"
	elif authority >= 1:
		rec["meaning_label"] = "rising"
	else:
		rec["meaning_label"] = "obscure"


func get_bloodline_meaning(bloodline_id: int) -> Dictionary:
	if meaning_by_bloodline.has(bloodline_id):
		return meaning_by_bloodline[bloodline_id].duplicate(true)
	return {
		"death_count": 0,
		"authority_grants": 0,
		"knowledge_carriers": 0,
		"meaning_label": "obscure"
	}

func get_period_meaning(period: int) -> Dictionary:
	if meaning_by_period.has(period):
		return meaning_by_period[period].duplicate(true)
	return {
		"death_count": 0,
		"conflict_count": 0,
		"discovery_count": 0,
		"collapse_count": 0,
		"meaning_label": "quiet_age"
	}

func get_current_period_meaning() -> Dictionary:
	var current_tick: int = GameManager.tick_count if GameManager else 0
	var period: int = int(current_tick / 10000)
	return get_period_meaning(period)
func describe_region_meaning(region_key: int) -> String:
	var meaning: Dictionary = get_region_meaning(region_key)
	var death_density: String = meaning.get("death_density", "none")

	match death_density:
		"none":
			return "This land has known peace."
		"low":
			return "This valley bears the scars of loss."
		"medium":
			return "This ground has drunk deep of blood."
		"high":
			return "This region is a grave of forgotten dead."
		_:
			return "This land is quiet."

func describe_settlement_meaning(settlement_id: int) -> String:
	var meaning: Dictionary = get_settlement_meaning(settlement_id)
	var label: String = meaning.get("meaning_label", "founding")

	match label:
		"stable":
			return "This settlement endures through the strength of its teachers."
		"learned":
			return "This settlement is remembered for preserving knowledge."
		"struggling":
			return "This settlement fights to hold against the encroaching dark."
		"collapsing":
			return "This settlement is failing, its foundations crumbling."
		"famine_stricken":
			return "This settlement has known the hollow ache of hunger."
		"war_torn":
			return "This settlement bears the wounds of endless conflict."
		_:
			return "This settlement is young, its story yet unwritten."

func describe_bloodline_meaning(bloodline_id: int) -> String:
	var meaning: Dictionary = get_bloodline_meaning(bloodline_id)
	var label: String = meaning.get("meaning_label", "obscure")

	match label:
		"keepers_of_fire":
			return "This bloodline is remembered for carrying the flame."
		"protectors":
			return "This bloodline is known for standing between the weak and the dark."
		"fallen":
			return "This bloodline has been broken by time and tragedy."
		"scarred":
			return "This bloodline bears the marks of old wounds."
		"rising":
			return "This bloodline is ascending through courage and service."
		_:
			return "This bloodline lives in quiet obscurity."


# === Public Query Functions ===

func get_tracked_region_count() -> int:
	return meaning_by_region.size()

func get_tracked_settlement_count() -> int:
	return meaning_by_settlement.size()
