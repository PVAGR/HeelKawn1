extends Node
## Phase 2.2: deterministic, derived metrics from WorldMemory only.
## No writes to WorldMemory, no world mutation, no UI. Interpretation only (RNG allowed only for labeled non-canonical presentation tiers — default paths stay deterministic-from-facts).

## Matches WorldMemory Kind enum (keep in sync; literal ints avoid autoload class timing).
const KIND_PAWN_DEATH: int = 0
const KIND_ANIMAL_DEATH: int = 1
const KIND_BUILDING_CONSTRUCTED: int = 5
const KIND_BUILDING_DESTROYED: int = 6
const KIND_FIRE_STARTED: int = 7
const KIND_FIRE_EXTINGUISHED: int = 8
const KIND_STARVATION_EVENT: int = 9
const KIND_MIGRATION_STARTED: int = 10
const KIND_MIGRATION_COMPLETED: int = 11
const KIND_TEACHING_EVENT: int = 12
const KIND_FOOD_EVENT: int = 13
const KIND_WORK_EVENT: int = 14
const KIND_SETTLEMENT_EVENT: int = 15
const KIND_CRAFT_EVENT: int = 16
const KIND_AUTHORITY_EVENT: int = 17
const KIND_TRADE_EVENT: int = 18
const KIND_CONFLICT_EVENT: int = 19
const KIND_LEGACY_EVENT: int = 20
const KIND_CULTURE_EVENT: int = 21
const KIND_INJURY_EVENT: int = 22
const KIND_WORLD_EVENT: int = 23

## region_key (int) -> aggregated entry Dictionary
var meaning_by_region: Dictionary = {}

## Settlement meanings: settlement_id -> derived meanings
var meaning_by_settlement: Dictionary = {}

## Bloodline meanings: bloodline_id -> derived meanings
var meaning_by_bloodline: Dictionary = {}

## Time period meanings: time period -> derived meanings
var meaning_by_period: Dictionary = {}

## Cursor for incremental recompute: index of last processed event.
var _last_recompute_event_index: int = 0


func recompute() -> void:
	# If events were evicted (swap-pop), counts are stale — full rebuild needed.
	if WorldMemory._eviction_occurred:
		meaning_by_region.clear()
		meaning_by_settlement.clear()
		meaning_by_bloodline.clear()
		meaning_by_period.clear()
		_last_recompute_event_index = 0
		WorldMemory._eviction_occurred = false

	# Incremental: only process new events since last recompute.
	var ev: Array[Dictionary] = WorldMemory.get_events()
	var ev_count: int = ev.size()

	if _last_recompute_event_index >= ev_count:
		# No new events — skip
		return

	# Process only new events
	var start_idx: int = _last_recompute_event_index
	for i in range(start_idx, ev_count):
		var item: Variant = ev[i]
		if not item is Dictionary:
			continue
		var e: Dictionary = item as Dictionary
		if not e.has("r") or not e.has("k"):
			continue
		var rk: int = int(e["r"])
		var k: int = int(e["k"])
		var t: int = int(e.get("t", 0))
		if not meaning_by_region.has(rk):
			meaning_by_region[rk] = _default_region_entry()
		var rec: Dictionary = meaning_by_region[rk]
		# Track first event tick for myth formation (age-based tag amplification)
		if int(rec.get("first_event_tick", -1)) < 0 or t < int(rec.get("first_event_tick", 999999999)):
			rec["first_event_tick"] = t

		match k:
			KIND_PAWN_DEATH:
				rec["pawn_deaths"] = int(rec["pawn_deaths"]) + 1
				rec["total_deaths"] = int(rec["total_deaths"]) + 1
				rec["last_death_tick"] = t
			KIND_ANIMAL_DEATH:
				rec["animal_deaths"] = int(rec["animal_deaths"]) + 1
				rec["total_deaths"] = int(rec["total_deaths"]) + 1
			KIND_BUILDING_CONSTRUCTED:
				rec["buildings_constructed"] = int(rec.get("buildings_constructed", 0)) + 1
				rec["last_build_tick"] = t
			KIND_BUILDING_DESTROYED:
				rec["buildings_destroyed"] = int(rec.get("buildings_destroyed", 0)) + 1
			KIND_FIRE_STARTED:
				rec["fires_started"] = int(rec.get("fires_started", 0)) + 1
				rec["last_fire_tick"] = t
			KIND_FIRE_EXTINGUISHED:
				rec["fires_extinguished"] = int(rec.get("fires_extinguished", 0)) + 1
			KIND_STARVATION_EVENT:
				rec["starvation_events"] = int(rec.get("starvation_events", 0)) + 1
			KIND_MIGRATION_STARTED:
				rec["migrations_started"] = int(rec.get("migrations_started", 0)) + 1
			KIND_MIGRATION_COMPLETED:
				rec["migrations_completed"] = int(rec.get("migrations_completed", 0)) + 1
			KIND_TEACHING_EVENT:
				rec["teaching_events"] = int(rec.get("teaching_events", 0)) + 1
				rec["last_teaching_tick"] = t
			KIND_FOOD_EVENT:
				rec["food_events"] = int(rec.get("food_events", 0)) + 1
				rec["last_food_tick"] = t
			KIND_WORK_EVENT:
				rec["work_events"] = int(rec.get("work_events", 0)) + 1
				rec["last_work_tick"] = t
			KIND_SETTLEMENT_EVENT:
				rec["settlement_events"] = int(rec.get("settlement_events", 0)) + 1
				rec["last_settlement_tick"] = t
			KIND_CRAFT_EVENT:
				rec["craft_events"] = int(rec.get("craft_events", 0)) + 1
				rec["last_craft_tick"] = t
			KIND_AUTHORITY_EVENT:
				rec["authority_events"] = int(rec.get("authority_events", 0)) + 1
				rec["last_authority_tick"] = t
			KIND_TRADE_EVENT:
				rec["trade_events"] = int(rec.get("trade_events", 0)) + 1
				rec["last_trade_tick"] = t
			KIND_CONFLICT_EVENT:
				rec["conflict_events"] = int(rec.get("conflict_events", 0)) + 1
				rec["last_conflict_tick"] = t
			KIND_LEGACY_EVENT:
				rec["legacy_events"] = int(rec.get("legacy_events", 0)) + 1
				rec["last_legacy_tick"] = t
			KIND_CULTURE_EVENT:
				rec["culture_events"] = int(rec.get("culture_events", 0)) + 1
				rec["last_culture_tick"] = t
			KIND_INJURY_EVENT:
				rec["injury_events"] = int(rec.get("injury_events", 0)) + 1
				rec["last_injury_tick"] = t
			KIND_WORLD_EVENT:
				rec["world_events"] = int(rec.get("world_events", 0)) + 1
				rec["last_world_tick"] = t

		# Read impact from ProgressionSystem
		if has_node("/root/ProgressionSystem"):
			var ps = get_node("/root/ProgressionSystem")
			var total_impact = 0
			if ps.has_method("get_all_impact_in_region"):
				total_impact = ps.call("get_all_impact_in_region", rk)
			elif ps.has_method("get_impact"):
				total_impact = ps.call("get_impact", rk)

			if total_impact > 1000:
				rec["influential_here"] = true
			if total_impact > 5000:
				rec["legendary_land"] = true

		var last: int = int(rec["last_death_tick"])
		if t > last:
			rec["last_death_tick"] = t

		# Also process string-typed WorldMemory events for lineage and stranger tracking
		var typ: String = str(e.get("type", "")).to_lower()
		match typ:
			"settlement_revival_with_lineage":
				rec["continuity_count"] = int(rec.get("continuity_count", 0)) + 1
			"settlement_new_foundation":
				rec["stranger_count"] = int(rec.get("stranger_count", 0)) + 1
			"pawn_death":
				rec["death_count"] = int(rec.get("death_count", 0)) + 1

	_last_recompute_event_index = ev_count

	# Derive total_deaths and death_density (only for regions that got new events)
	for rk in meaning_by_region.keys():
		var r2: Dictionary = meaning_by_region[rk]
		var pdc: int = int(r2.get("pawn_deaths", 0))
		var adc: int = int(r2.get("animal_deaths", 0))
		var tot: int = pdc + adc
		r2["total_deaths"] = tot
		r2["death_density"] = classify_death_density(tot)
		# Lineage-based meaning overrides
		var continuity_count: int = int(r2.get("continuity_count", 0))
		var stranger_count: int = int(r2.get("stranger_count", 0))
		var death_count: int = int(r2.get("death_count", 0))
		if continuity_count > 1:
			r2["meaning_label"] = "resilient"
		elif death_count > 5 and stranger_count > 0:
			r2["meaning_label"] = "cursed"
		else:
			r2["meaning_label"] = "scarred"
		r2["tags"] = _compute_region_tags(r2, GameManager.tick_count)

	# Derive enhanced meanings (these still iterate all events — acceptable for now)
	_derive_settlement_meanings(ev)
	_derive_bloodline_meanings(ev)
	_derive_period_meanings(ev)


func get_region_meaning(region_key: int) -> Dictionary:
	if meaning_by_region.has(region_key):
		return meaning_by_region[region_key] as Dictionary
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


## Public API: deterministic region tags derived from recorded world facts.
## Returns a PackedStringArray of tag strings for the given region_key.
## No mutation, no RNG, no UI. Tags are computed from WorldMemory event data.
func get_region_tags(region_key: int) -> PackedStringArray:
	var meaning: Dictionary = get_region_meaning(region_key)
	var tags_val: Variant = meaning.get("tags", PackedStringArray())
	if tags_val is PackedStringArray:
		return tags_val
	if tags_val is Array:
		var psa: PackedStringArray = PackedStringArray()
		for item in (tags_val as Array):
			if item is String:
				psa.append(item)
		return psa
	return PackedStringArray()


func get_cultural_style(region_key: int) -> String:
	var tags: PackedStringArray = get_zone_tags(str(region_key))
	if "myth_origin" in tags:
		return "mythic"
	if "ancient_ruin" in tags:
		return "ruin"
	if "echo_falls" in tags:
		return "echo"
	return get_region_meaning_label(region_key)


func get_wildlife_trend(region_key: int) -> String:
	var meaning: Dictionary = get_region_meaning(region_key)
	var density: String = str(meaning.get("death_density", "none"))
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


func _default_region_entry() -> Dictionary:
	return {
		"continuity_count": 0,
		"stranger_count": 0,
		"death_count": 0,
		"pawn_deaths": 0,
		"animal_deaths": 0,
		"total_deaths": 0,
		"death_density": "none",
		"last_death_tick": -1,
		"first_event_tick": -1,
		"buildings_constructed": 0,
		"buildings_destroyed": 0,
		"fires_started": 0,
		"fires_extinguished": 0,
		"starvation_events": 0,
		"migrations_started": 0,
		"migrations_completed": 0,
		"teaching_events": 0,
		"food_events": 0,
		"work_events": 0,
		# Echo tracking: last tick of each action type for custom tag formation
		"last_teaching_tick": -1,
		"last_food_tick": -1,
		"last_work_tick": -1,
		"last_build_tick": -1,
		"last_fire_tick": -1,
		# New meaning pipeline categories
		"settlement_events": 0,
		"craft_events": 0,
		"authority_events": 0,
		"trade_events": 0,
		"conflict_events": 0,
		"legacy_events": 0,
		"culture_events": 0,
		"injury_events": 0,
		"world_events": 0,
		"last_settlement_tick": -1,
		"last_craft_tick": -1,
		"last_authority_tick": -1,
		"last_trade_tick": -1,
		"last_conflict_tick": -1,
		"last_legacy_tick": -1,
		"last_culture_tick": -1,
		"last_injury_tick": -1,
		"last_world_tick": -1,
		"tags": PackedStringArray(),
	}


func _compute_region_tags(data: Dictionary, current_tick: int = 0) -> PackedStringArray:
	var tags: PackedStringArray = []

	var buildings_built: int = int(data.get("buildings_constructed", 0))
	var buildings_destroyed: int = int(data.get("buildings_destroyed", 0))
	var fires_started: int = int(data.get("fires_started", 0))
	var starvation_events: int = int(data.get("starvation_events", 0))
	var teaching_events: int = int(data.get("teaching_events", 0))
	var migrations_completed: int = int(data.get("migrations_completed", 0))
	var total_deaths: int = int(data.get("total_deaths", 0))

	# Myth formation: compute age of this region's memory
	var first_tick: int = int(data.get("first_event_tick", -1))
	var age_ticks: int = 0
	if first_tick >= 0 and current_tick > first_tick:
		age_ticks = current_tick - first_tick
	var is_ancient: bool = age_ticks >= 10000  # ~55 in-world years at 180 ticks/day
	var is_old: bool = age_ticks >= 5000      # ~28 in-world years
	
	# Construction tags
	if buildings_built >= 10:
		tags.append("built_up")
	if buildings_built >= 5:
		tags.append("developed")
	if buildings_destroyed > buildings_built:
		tags.append("ruined")
	
	# Fire tags
	if fires_started >= 3:
		tags.append("fire_prone")
	if fires_started >= 1:
		tags.append("burned")
	
	# Starvation tags
	if starvation_events >= 3:
		tags.append("famine_stricken")
	if starvation_events >= 1:
		tags.append("hungry")
	
	# Knowledge tags
	if teaching_events >= 5:
		tags.append("learned")
	if teaching_events >= 2:
		tags.append("educated")
	
	# Migration tags
	if migrations_completed >= 3:
		tags.append("cosmopolitan")
	if migrations_completed >= 1:
		tags.append("welcoming")
	
	# Death-based tags
	if total_deaths >= 10:
		tags.append("graveyard")
	if total_deaths >= 5:
		tags.append("blood_soaked")
	if total_deaths >= 2:
		tags.append("repeated_death")
	
	# Hunger-place: starvation in an inhabited region
	if starvation_events >= 1 and buildings_built >= 1:
		tags.append("hunger_place")
	
	# Safe-hearth: shelter + knowledge + no deaths
	if total_deaths == 0 and buildings_built >= 1 and teaching_events >= 1:
		tags.append("safe_hearth")

	# Food activity tags
	var food_events: int = int(data.get("food_events", 0))
	if food_events >= 10:
		tags.append("fertile")
	if food_events >= 5:
		tags.append("farmed")

	# Work activity tags
	var work_events: int = int(data.get("work_events", 0))
	if work_events >= 15:
		tags.append("busy")
	if work_events >= 5:
		tags.append("active")

	# Craft district tags
	var craft_events: int = int(data.get("craft_events", 0))
	if craft_events >= 10:
		tags.append("craftsman_quarter")
	if craft_events >= 5:
		tags.append("industrial")

	# Authority seat tags
	var authority_events: int = int(data.get("authority_events", 0))
	if authority_events >= 5:
		tags.append("governed")
	if authority_events >= 10:
		tags.append("seat_of_power")

	# Trade hub tags
	var trade_events: int = int(data.get("trade_events", 0))
	if trade_events >= 3:
		tags.append("trading_post")
	if trade_events >= 6:
		tags.append("merchant_quarter")

	# Conflict zone tags
	var conflict_events: int = int(data.get("conflict_events", 0))
	if conflict_events >= 5:
		tags.append("war_torn")
	if conflict_events >= 2:
		tags.append("grudge_haunted")

	# Legacy ground tags
	var legacy_events: int = int(data.get("legacy_events", 0))
	if legacy_events >= 5:
		tags.append("storied")
	if legacy_events >= 10:
		tags.append("ancient_lineage")

	# Culture site tags
	var culture_events: int = int(data.get("culture_events", 0))
	if culture_events >= 3:
		tags.append("sacred")
	if culture_events >= 6:
		tags.append("hallowed")

	# Injury tags
	var injury_events: int = int(data.get("injury_events", 0))
	if injury_events >= 5:
		tags.append("dangerous_ground")
	if injury_events >= 2:
		tags.append("blood_stained")

	# World event tags
	var world_events: int = int(data.get("world_events", 0))
	if world_events >= 2:
		tags.append("world_touched")

	# Myth formation: time amplifies meaning. Old events become legend.
	# Ancient death places are feared more. Ancient safe hearths are revered.
	if is_ancient:
		if total_deaths >= 2:
			tags.append("ancient_death_place")  # Stronger aversion than repeated_death
		if starvation_events >= 1:
			tags.append("ancient_famine")  # Deep cultural memory of hunger
		if total_deaths == 0 and buildings_built >= 1:
			tags.append("ancient_heart")  # Revered safe place — pilgrimage worthy
		if teaching_events >= 2:
			tags.append("ancient_wisdom")  # Knowledge shrine — seek teaching here
	elif is_old:
		if total_deaths >= 3:
			tags.append("old_death_place")  # Moderate aversion
		if starvation_events >= 2:
			tags.append("old_famine")  # Cultural memory forming
		if total_deaths == 0 and buildings_built >= 1:
			tags.append("old_heart")  # Respected safe place
		if teaching_events >= 3:
			tags.append("old_wisdom")  # Established learning place
		# Myth amplification for new categories
		if craft_events >= 5:
			tags.append("old_forge")  # Historic workshop district
		if authority_events >= 3:
			tags.append("old_throne")  # Former seat of power
		if conflict_events >= 3:
			tags.append("old_battleground")  # Remembered war
		if culture_events >= 2:
			tags.append("old_sanctuary")  # Former sacred site
		if trade_events >= 2:
			tags.append("old_market")  # Historic trade route
	elif is_ancient:
		# Ancient amplification for new categories
		if craft_events >= 5:
			tags.append("ancient_forge")  # Legendary workshop
		if authority_events >= 3:
			tags.append("ancient_throne")  # Mythic seat of power
		if conflict_events >= 3:
			tags.append("ancient_battleground")  # Legendary war site
		if culture_events >= 2:
			tags.append("ancient_sanctuary")  # Pilgrimage destination
		if trade_events >= 2:
			tags.append("ancient_market")  # Legendary trade crossroads

	# Ritual Echo System: repeated actions at same region form customs.
	# Custom tags emerge when an action type is repeated enough within a recency window.
	# If no reinforcing event for 5000+ ticks, the custom fades (faded_ prefix).
	var ECHO_RECENCY_TICKS: int = 500   # Action must be recent to count as echo
	var ECHO_FADE_TICKS: int = 5000     # Custom fades if no reinforcement for this long

	# Burial grove: 3+ pawn deaths with recent activity
	var last_death_t: int = int(data.get("last_death_tick", -1))
	if total_deaths >= 3 and last_death_t >= 0:
		if current_tick - last_death_t <= ECHO_FADE_TICKS:
			if current_tick - last_death_t <= ECHO_RECENCY_TICKS:
				tags.append("burial_grove")
			else:
				tags.append("faded_burial_grove")

	# Teaching ground: 5+ teaching events with recent activity
	var last_teach_t: int = int(data.get("last_teaching_tick", -1))
	if teaching_events >= 5 and last_teach_t >= 0:
		if current_tick - last_teach_t <= ECHO_FADE_TICKS:
			if current_tick - last_teach_t <= ECHO_RECENCY_TICKS:
				tags.append("teaching_ground")
			else:
				tags.append("faded_teaching_ground")

	# Feast ground: 8+ food events with recent activity
	var last_food_t: int = int(data.get("last_food_tick", -1))
	if food_events >= 8 and last_food_t >= 0:
		if current_tick - last_food_t <= ECHO_FADE_TICKS:
			if current_tick - last_food_t <= ECHO_RECENCY_TICKS:
				tags.append("feast_ground")
			else:
				tags.append("faded_feast_ground")

	# Builder yard: 5+ building events with recent activity
	var last_build_t: int = int(data.get("last_build_tick", -1))
	if buildings_built >= 5 and last_build_t >= 0:
		if current_tick - last_build_t <= ECHO_FADE_TICKS:
			if current_tick - last_build_t <= ECHO_RECENCY_TICKS:
				tags.append("builder_yard")
			else:
				tags.append("faded_builder_yard")

	# Gathering place: 10+ work events + 3+ migrations with recent activity
	var last_work_t: int = int(data.get("last_work_tick", -1))
	if work_events >= 10 and migrations_completed >= 3 and last_work_t >= 0:
		if current_tick - last_work_t <= ECHO_FADE_TICKS:
			if current_tick - last_work_t <= ECHO_RECENCY_TICKS:
				tags.append("gathering_place")
			else:
				tags.append("faded_gathering_place")

	# Forge echo: 5+ craft events with recent activity
	var last_craft_t: int = int(data.get("last_craft_tick", -1))
	if craft_events >= 5 and last_craft_t >= 0:
		if current_tick - last_craft_t <= ECHO_FADE_TICKS:
			if current_tick - last_craft_t <= ECHO_RECENCY_TICKS:
				tags.append("forge_echo")
			else:
				tags.append("faded_forge_echo")

	# War echo: 3+ conflict events with recent activity
	var last_conflict_t: int = int(data.get("last_conflict_tick", -1))
	if conflict_events >= 3 and last_conflict_t >= 0:
		if current_tick - last_conflict_t <= ECHO_FADE_TICKS:
			if current_tick - last_conflict_t <= ECHO_RECENCY_TICKS:
				tags.append("war_echo")
			else:
				tags.append("faded_war_echo")

	# Market echo: 3+ trade events with recent activity
	var last_trade_t: int = int(data.get("last_trade_tick", -1))
	if trade_events >= 3 and last_trade_t >= 0:
		if current_tick - last_trade_t <= ECHO_FADE_TICKS:
			if current_tick - last_trade_t <= ECHO_RECENCY_TICKS:
				tags.append("market_echo")
			else:
				tags.append("faded_market_echo")

	# Sanctuary echo: 3+ culture events with recent activity
	var last_culture_t: int = int(data.get("last_culture_tick", -1))
	if culture_events >= 3 and last_culture_t >= 0:
		if current_tick - last_culture_t <= ECHO_FADE_TICKS:
			if current_tick - last_culture_t <= ECHO_RECENCY_TICKS:
				tags.append("sanctuary_echo")
			else:
				tags.append("faded_sanctuary_echo")

	return tags


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

		var tick: int = int(event.get("t", event.get("tick", 0)))
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

func record_pawn_death(_pawn_id: int, bloodline_id: int) -> void:
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


func record_authority_grant(_pawn_id: int, bloodline_id: int) -> void:
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


func record_knowledge_carrier(_pawn_id: int, bloodline_id: int) -> void:
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


# === Phase 4: Settlement Cause Analysis ===

func analyze_cause(data: SettlementData) -> String:
	if data.trauma_score >= 100.0:
		return "War"
	elif data.population <= 0 and data.trauma_score < 20.0:
		return "Starvation"
	else:
		return "Abandonment"
