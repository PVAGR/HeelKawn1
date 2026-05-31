extends Node
## LegendSystem — generation, spread, mutation, and decay of legends from exceptional events.
##
## Exceptional deeds (heroic deaths, cataclysms, discoveries, betrayals) seed legends.
## Legends spread between settlements via trade, migration, war, and cultural exchange,
## with each spread having a chance to mutate the legend's details. High-spread legends
## influence settlement culture and pawn beliefs. Low-spread legends fade over time.
##
## Integrates with WorldMemory (event scanning), EventBus (event response),
## NarrativeSystem (thread resolution), CulturalExchange (trait influence),
## and SettlementMemory (settlement lookup).

const LEGEND_CHECK_INTERVAL: int = 5000
const SPREAD_INTERVAL: int = 3000
const DECAY_INTERVAL: int = 10000
const MERGE_INTERVAL: int = 15000
const INFLUENCE_INTERVAL: int = 8000
const MAX_MUTATIONS_PER_LEGEND: int = 10
const FADE_THRESHOLD_SIGNIFICANCE: float = 20.0
const FADE_TICKS: int = 50000
const MUTATION_CHANCE: float = 0.2
const MAX_LEGENDS: int = 500
const NEARBY_RADIUS: int = 15

enum LegendCategory {
	HERO_DEED = 0,
	CATASTROPHE = 1,
	FOUNDING_MYTH = 2,
	ROMANCE_EPIC = 3,
	BETRAYAL = 4,
	DISCOVERY = 5,
	MIRACLE = 6,
	CURSE = 7,
}

enum LegendTier {
	LOCAL = 0,
	REGIONAL = 1,
	CONTINENTAL = 2,
	MYTHIC = 3,
}

class MutationRecord:
	var tick: int
	var field: String
	var old_value: String
	var new_value: String
	var spread_origin: int

	func _init(p_tick: int, p_field: String, p_old: String, p_new: String, p_origin: int) -> void:
		tick = p_tick
		field = p_field
		old_value = p_old
		new_value = p_new
		spread_origin = p_origin

	func to_dict() -> Dictionary:
		return {
			"tick": tick,
			"field": field,
			"old_value": old_value,
			"new_value": new_value,
			"spread_origin": spread_origin,
		}

class Legend:
	var name: String
	var description: String
	var origin_event_type: String
	var origin_tick: int
	var origin_location: int
	var involved_pawns: Array[int]
	var involved_settlements: Array[int]
	var significance: float
	var spread: float
	var mutations: Array
	var tick_created: int
	var tick_last_spread: int
	var category: int
	var tier: int
	var known_in_settlements: Array[int]
	var faded: bool

	func _init() -> void:
		mutations = []
		involved_pawns = []
		involved_settlements = []
		known_in_settlements = []
		significance = 30.0
		spread = 10.0
		tier = LegendTier.LOCAL
		faded = false
		tick_last_spread = -1

	func compute_tier() -> int:
		if spread >= 75.0:
			return LegendTier.MYTHIC
		if spread >= 50.0:
			return LegendTier.CONTINENTAL
		if spread >= 25.0:
			return LegendTier.REGIONAL
		return LegendTier.LOCAL

	func to_dict() -> Dictionary:
		var mut_list: Array = []
		for m in mutations:
			if m is MutationRecord:
				mut_list.append(m.to_dict())
		return {
			"name": name,
			"description": description,
			"origin_event_type": origin_event_type,
			"origin_tick": origin_tick,
			"origin_location": origin_location,
			"involved_pawns": involved_pawns.duplicate(),
			"involved_settlements": involved_settlements.duplicate(),
			"significance": significance,
			"spread": spread,
			"mutations": mut_list,
			"tick_created": tick_created,
			"tick_last_spread": tick_last_spread,
			"category": category,
			"tier": compute_tier(),
			"known_in_settlements": known_in_settlements.duplicate(),
			"faded": faded,
		}

var _legends: Array = []
var _last_legend_tick: int = -999999
var _last_spread_tick: int = -999999
var _last_decay_tick: int = -999999
var _last_merge_tick: int = -999999
var _last_influence_tick: int = -999999
var _EventBus: Variant = null

signal legend_created(name: String, origin_location: int, category: int, tick: int)
signal legend_spread(name: String, from_settlement: int, to_settlement: int, tick: int)
signal legend_mutated(name: String, field: String, old_value: String, new_value: String, tick: int)
signal legend_merged(name: String, survivor_name: String, merged_count: int, tick: int)
signal legend_faded(name: String, tick: int)
signal legend_tier_changed(name: String, old_tier: int, new_tier: int, tick: int)

func _ready() -> void:
	if GameManager != null:
		GameManager.game_tick.connect(_on_game_tick)
	_EventBus = get_node_or_null("/root/EventBus")
	if _EventBus != null and _EventBus.has_method("subscribe"):
		_EventBus.subscribe(EventBus.EVENT_SETTLEMENT_FOUNDED, self, "_on_settlement_founded")
		_EventBus.subscribe(EventBus.EVENT_COMBAT_ENDED, self, "_on_combat_ended")

func _exit_tree() -> void:
	if GameManager != null and GameManager.game_tick.is_connected(_on_game_tick):
		GameManager.game_tick.disconnect(_on_game_tick)
	if _EventBus != null and _EventBus.has_method("unsubscribe"):
		_EventBus.unsubscribe(EventBus.EVENT_SETTLEMENT_FOUNDED, self, "_on_settlement_founded")
		_EventBus.unsubscribe(EventBus.EVENT_COMBAT_ENDED, self, "_on_combat_ended")

func _on_settlement_founded(payload: Dictionary) -> void:
	var tick: int = int(payload.get("tick", GameManager.tick_count if GameManager != null else 0))
	var center: int = int(payload.get("center_region", -1))
	if center < 0:
		return
	var founder_id: int = int(payload.get("founder_id", -1))
	var name_str: String = str(payload.get("name", "Settlement"))
	var origin_event: Dictionary = {
		"type": "settlement_founded",
		"tick": tick,
		"center": center,
		"name": name_str,
		"founder_id": founder_id,
		"severity": 6,
		"pawn_count": 1,
	}
	_check_event_for_legend(origin_event, tick)

func _on_combat_ended(payload: Dictionary) -> void:
	var tick: int = int(payload.get("tick", GameManager.tick_count if GameManager != null else 0))
	if _has_recent_legend_of_type_at("hero_deed", int(payload.get("location", -1)), tick, 20000):
		return
	var casualties: int = int(payload.get("total_casualties", 0))
	var participants: Array = payload.get("participants", [])
	var center: int = int(payload.get("location", -1))
	if center < 0:
		return
	if casualties >= 5:
		var origin_event: Dictionary = {
			"type": "great_battle",
			"tick": tick,
			"center": center,
			"casualties": casualties,
			"participants": participants,
			"severity": clampi(casualties / 2, 5, 10),
			"pawn_count": participants.size(),
		}
		_check_event_for_legend(origin_event, tick)

func _on_game_tick(tick: int) -> void:
	if tick - _last_legend_tick < LEGEND_CHECK_INTERVAL:
		return
	_last_legend_tick = tick
	_check_for_new_legends(tick)
	if tick - _last_spread_tick >= SPREAD_INTERVAL:
		_last_spread_tick = tick
		_spread_legends(tick)
	if tick - _last_decay_tick >= DECAY_INTERVAL:
		_last_decay_tick = tick
		_process_decay(tick)
	if tick - _last_merge_tick >= MERGE_INTERVAL:
		_last_merge_tick = tick
		_process_merges(tick)
	if tick - _last_influence_tick >= INFLUENCE_INTERVAL:
		_last_influence_tick = tick
		_process_cultural_influence(tick)

func create_legend(
	p_name: String,
	p_description: String,
	p_origin_type: String,
	p_category: int,
	p_tick: int,
	p_location: int,
	p_pawns: Array[int],
	p_settlements: Array[int],
	p_significance: float,
) -> void:
	if _legends.size() >= MAX_LEGENDS:
		_fade_oldest_legend()
	var legend := Legend.new()
	legend.name = p_name
	legend.description = p_description
	legend.origin_event_type = p_origin_type
	legend.origin_tick = p_tick
	legend.origin_location = p_location
	legend.involved_pawns = p_pawns.duplicate()
	legend.involved_settlements = p_settlements.duplicate()
	legend.significance = clampf(p_significance, 0.0, 100.0)
	legend.spread = 10.0
	legend.tick_created = p_tick
	legend.tick_last_spread = p_tick
	legend.category = p_category
	legend.known_in_settlements = p_settlements.duplicate()
	legend.tier = LegendTier.LOCAL
	_legends.append(legend)
	legend_created.emit(legend.name, p_location, p_category, p_tick)
	_record_legend_event("legend_created", legend, p_tick)

func create_legend_from_event(event: Dictionary, tick: int, significance: float) -> void:
	var ev_type: String = str(event.get("type", ""))
	var category: int = _event_type_to_category(ev_type)
	var name_str: String = _generate_legend_name(event)
	var desc: String = _generate_legend_description(event, category)
	var center: int = int(event.get("center", int(event.get("location", int(event.get("settlement_id", -1))))))
	var pawns: Array[int] = []
	var settlements: Array[int] = []
	if event.has("pawn_id"):
		pawns.append(int(event["pawn_id"]))
	elif event.has("founder_id"):
		pawns.append(int(event["founder_id"]))
	elif event.has("participants"):
		var parts = event["participants"]
		if parts is Array:
			for p in parts:
				if p is int:
					pawns.append(p)
	if center >= 0:
		settlements.append(center)
	if event.has("settlement_id"):
		var sid: int = int(event["settlement_id"])
		if sid >= 0 and not settlements.has(sid):
			settlements.append(sid)
	create_legend(name_str, desc, ev_type, category, tick, center, pawns, settlements, significance)

## Core legend generation trigger — scan WorldMemory for exceptional events.
func _check_for_new_legends(tick: int) -> void:
	var wm := get_node_or_null("/root/WorldMemory")
	if wm == null:
		return
	if not wm.has_method("get_events"):
		return
	var all_events: Array = wm.get_events()
	if all_events.is_empty():
		return
	var event_pool: Array = _collect_legend_worthy_events(all_events, tick)
	for event in event_pool:
		if _legends.size() >= MAX_LEGENDS:
			return
		var ev: Dictionary = event as Dictionary
		var significance: float = _compute_significance(ev)
		if significance >= 25.0:
			create_legend_from_event(ev, tick, significance)

## Check a single event from EventBus callback — used for immediate generation.
func _check_event_for_legend(event: Dictionary, tick: int) -> void:
	if _legends.size() >= MAX_LEGENDS:
		return
	var significance: float = _compute_significance(event)
	if significance >= 25.0:
		create_legend_from_event(event, tick, significance)

## Collect events from WorldMemory that are worthy of becoming legends.
func _collect_legend_worthy_events(all_events: Array, tick: int) -> Array:
	var out: Array = []
	var seen_types: Dictionary = {}
	var window: int = LEGEND_CHECK_INTERVAL * 2
	for i in range(maxi(0, all_events.size() - 200), all_events.size()):
		var ev: Variant = all_events[i]
		if not (ev is Dictionary):
			continue
		var ev_dict: Dictionary = ev as Dictionary
		var ev_tick: int = int(ev_dict.get("t", int(ev_dict.get("tick", 0))))
		if tick - ev_tick > window:
			continue
		var ev_type: String = str(ev_dict.get("type", ""))
		if not _is_legend_worthy_type(ev_type):
			continue
		if not _check_event_uniqueness(ev_dict, tick):
			continue
		var type_key: String = ev_type + ":" + str(ev_dict.get("center", ev_dict.get("settlement_id", -1)))
		if seen_types.has(type_key):
			continue
		seen_types[type_key] = true
		ev_dict["t"] = ev_tick
		out.append(ev_dict)
	return out

func _is_legend_worthy_type(ev_type: String) -> bool:
	return ev_type in [
		"heroic_death", "pawn_death", "settlement_founded", "settlement_destroyed",
		"cataclysm_started", "cataclysm_ended", "great_battle", "war_proposed",
		"war_battle_spawned", "major_discovery", "first_of_type",
		"leadership_change", "settlement_revival", "ritual_performed",
		"sacred_site_established", "disaster_started", "ai_natural_disaster",
		"trade_route_opened", "polity_founded", "polity_merged",
		"bloodline_extinct", "knowledge_inscribed",
	]

## Check if event is unique enough to warrant a new legend (avoid duplicates).
func _check_event_uniqueness(event: Dictionary, tick: int) -> bool:
	var ev_type: String = str(event.get("type", ""))
	var ev_location: int = int(event.get("center", int(event.get("settlement_id", -1))))
	var ev_pawn: int = int(event.get("pawn_id", int(event.get("founder_id", -1))))
	var threshold: int = 30000
	for legend in _legends:
		if legend.origin_event_type == ev_type:
			var same_location: bool = legend.origin_location == ev_location
			var same_pawn: bool = ev_pawn >= 0 and legend.involved_pawns.has(ev_pawn)
			var recent: bool = tick - legend.tick_created < threshold
			if (same_location or same_pawn) and recent:
				return false
	return true

## Check if a legend of a given category exists recently at a location.
func _has_recent_legend_of_type_at(category_name: String, location: int, tick: int, window: int) -> bool:
	var cat: int = _category_name_to_enum(category_name)
	for legend in _legends:
		if legend.category == cat and legend.origin_location == location:
			if tick - legend.tick_created < window:
				return true
	return false

## Compute significance score for an event (0-100).
func _compute_significance(event: Dictionary) -> float:
	var base: float = 10.0
	var ev_type: String = str(event.get("type", ""))
	var severity: int = int(event.get("severity", 0))
	var pawn_count: int = int(event.get("pawn_count", int(event.get("total_casualties", 1))))
	pawn_count = maxi(1, pawn_count)
	match ev_type:
		"heroic_death":
			base = 40.0
			var legacy: int = int(event.get("legacy_score", 50))
			base += float(legacy) * 0.5
		"pawn_death":
			var legacy_score: int = int(event.get("legacy_score", 0))
			base = 15.0 + float(legacy_score) * 0.3
		"cataclysm_started", "disaster_started", "ai_natural_disaster":
			base = 50.0 + float(severity) * 3.0
		"settlement_founded":
			base = 35.0
		"settlement_destroyed":
			base = 45.0 + float(severity) * 2.0
		"great_battle":
			base = 30.0 + float(severity) * 2.0
		"war_proposed", "war_battle_spawned":
			base = 20.0 + float(severity) * 2.0
		"major_discovery", "first_of_type":
			base = 40.0
		"leadership_change":
			var leader_legacy: int = int(event.get("leader_legacy", 0))
			base = 20.0 + float(leader_legacy) * 0.3
		"settlement_revival":
			base = 50.0
		"ritual_performed", "sacred_site_established":
			base = 25.0
		"bloodline_extinct":
			base = 45.0
		"knowledge_inscribed":
			base = 30.0
		"polity_founded":
			base = 35.0
		"polity_merged":
			base = 25.0
		"trade_route_opened":
			base = 15.0
	base += float(pawn_count) * 2.0
	base += float(severity) * 1.5
	var rarities: int = _count_rarity_bonuses(event)
	base += float(rarities) * 10.0
	return clampf(base, 5.0, 100.0)

func _count_rarity_bonuses(event: Dictionary) -> int:
	var count: int = 0
	if event.get("first_of_type", false):
		count += 1
	if event.get("first_of_kind", false):
		count += 1
	if event.get("record_breaking", false):
		count += 1
	if int(event.get("total_kills", 0)) >= 10:
		count += 1
	var legacy: int = int(event.get("legacy_score", 0))
	if legacy >= 80:
		count += 1
	return count

## Spread legends to new settlements via proximity-based mechanics.
func _spread_legends(tick: int) -> void:
	var sm := get_node_or_null("/root/SettlementMemory")
	if sm == null or not sm.has_method("get_settlements"):
		return
	var all_settlements: Array = _get_all_settlement_centers(sm)
	if all_settlements.is_empty():
		return
	for legend in _legends:
		if legend.faded:
			continue
		if legend.spread >= 100.0:
			continue
		var spread_occurred: bool = false
		var known: Array[int] = legend.known_in_settlements.duplicate()
		for center in known:
			var neighbors: Array[int] = _find_nearby_settlements(center, all_settlements, NEARBY_RADIUS)
			for ncenter in neighbors:
				if legend.known_in_settlements.has(ncenter):
					continue
				var spread_chance: float = _compute_spread_chance(legend, center, ncenter, tick)
				if _rng_chance("legend_spread", legend.name + str(ncenter), tick, spread_chance):
					legend.known_in_settlements.append(ncenter)
					legend.tick_last_spread = tick
					legend.spread = clampf(legend.spread + _spread_increment(legend, ncenter), 0.0, 100.0)
					spread_occurred = true
					legend_spread.emit(legend.name, center, ncenter, tick)
					_record_spread_event(legend, center, ncenter, tick)
					if _rng_chance("legend_mutate", legend.name + str(ncenter) + str(legend.mutations.size()), tick, MUTATION_CHANCE):
						_mutate_legend(legend, ncenter, tick)
		if spread_occurred:
			var old_tier: int = legend.tier
			legend.tier = legend.compute_tier()
			if legend.tier != old_tier:
				legend_tier_changed.emit(legend.name, old_tier, legend.tier, tick)

func _compute_spread_chance(legend: Legend, from_center: int, to_center: int, tick: int) -> float:
	var base: float = legend.significance * 0.01
	base += legend.spread * 0.002
	var dist_factor: float = _settlement_distance_factor(from_center, to_center)
	base *= dist_factor
	var trade_bonus: float = _trade_route_bonus(from_center, to_center)
	base += trade_bonus
	var war_bonus: float = _war_connection_bonus(from_center, to_center)
	base += war_bonus
	return clampf(base, 0.01, 0.45)

func _settlement_distance_factor(from_center: int, to_center: int) -> float:
	var fx: int = from_center % 256
	var fy: int = from_center / 256
	var tx: int = to_center % 256
	var ty: int = to_center / 256
	var dist: float = Vector2(fx, fy).distance_to(Vector2(tx, ty))
	if dist <= 5.0:
		return 1.0
	if dist <= 10.0:
		return 0.8
	if dist <= 20.0:
		return 0.5
	if dist <= 30.0:
		return 0.25
	return 0.1

func _trade_route_bonus(from_center: int, to_center: int) -> float:
	var tm := get_node_or_null("/root/TradeMemory")
	if tm == null or not tm.has_method("has_trade_route"):
		return 0.0
	if tm.has_trade_route(from_center, to_center):
		return 0.15
	return 0.0

func _war_connection_bonus(from_center: int, to_center: int) -> float:
	var nbs := get_node_or_null("/root/NationBorderSystem")
	if nbs == null or not nbs.has_method("get_nation_at_region"):
		return 0.0
	var nation_a: int = nbs.get_nation_at_region(from_center)
	var nation_b: int = nbs.get_nation_at_region(to_center)
	if nation_a < 0 or nation_b < 0:
		return 0.0
	if nation_a == nation_b:
		return 0.05
	if nbs.has_method("are_nations_at_war") and nbs.are_nations_at_war(nation_a, nation_b):
		return 0.08
	return 0.02

func _spread_increment(legend: Legend, to_center: int) -> float:
	var base: float = legend.significance * 0.02
	var boost: float = 1.0
	var ce := get_node_or_null("/root/CulturalExchange")
	if ce != null and ce.has_method("get_cultural_distance"):
		var dist: float = ce.get_cultural_distance(legend.origin_location, to_center)
		if dist < 0.3:
			boost = 1.5
		elif dist > 0.7:
			boost = 0.7
	return base * boost

## Mutate a legend with 20% chance per spread event.
func _mutate_legend(legend: Legend, spread_origin: int, tick: int) -> void:
	if legend.mutations.size() >= MAX_MUTATIONS_PER_LEGEND:
		return
	var mut_field: String = ""
	var old_val: String = ""
	var new_val: String = ""
	var roll: float = _rng_unit("mutation_field", legend.name + str(tick), tick)
	if roll < 0.35:
		mut_field = "name"
		old_val = legend.name
		legend.name = _mutate_name(legend)
	elif roll < 0.65:
		mut_field = "description"
		old_val = legend.description
		legend.description = _mutate_description(legend)
	elif roll < 0.85:
		mut_field = "significance"
		old_val = str(legend.significance)
		legend.significance = clampf(legend.significance + _rng_range("mut_sig", legend.name, tick, -10.0, 15.0), 5.0, 100.0)
		new_val = str(legend.significance)
	else:
		mut_field = "category"
		old_val = str(legend.category)
		var new_cat: int = _rng_index("mut_cat", legend.name, tick, LegendCategory.size())
		if new_cat != legend.category:
			legend.category = new_cat
			new_val = str(legend.category)
	if mut_field == "name" or mut_field == "description":
		new_val = str(legend.name if mut_field == "name" else legend.description)
	if new_val != "" and new_val != old_val:
		var record := MutationRecord.new(tick, mut_field, old_val, new_val, spread_origin)
		legend.mutations.append(record)
		legend_mutated.emit(legend.name, mut_field, old_val, new_val, tick)
		_record_mutation_event(legend, record, tick)

func _mutate_name(legend: Legend) -> String:
	var prefixes: Array[String] = ["The Eternal", "The Whispered", "The Forgotten", "The Crimson",
		"The Ashen", "The Golden", "The Shadow", "The Iron", "The Silver", "The Broken"]
	var suffixes: Array[String] = ["of Old", "Reborn", "Unending", "of the Ancients",
		"Forevermore", "of Ruin", "of Glory", "of the Fallen", "Rekindled", "of the Deep"]
	var seed: StringName = StringName("mut_name:" + legend.name)
	var pidx: int = _rng_index("mut_prefix", legend.name + str(legend.tick_created), legend.tick_created, prefixes.size())
	var sidx: int = _rng_index("mut_suffix", legend.name, legend.tick_created, suffixes.size())
	var base: String = legend.name
	if _rng_chance("mut_name_prepend", legend.name, legend.tick_created, 0.5):
		base = prefixes[pidx] + " " + base
	if _rng_chance("mut_name_append", legend.name, legend.tick_created, 0.4):
		base = base + " " + suffixes[sidx]
	return base

func _mutate_description(legend: Legend) -> String:
	var embellishments: Array[String] = [
		"The gods themselves remember this day.",
		"It is said the earth trembled at this deed.",
		"Bards carry this tale across every border.",
		"The stones of the ancients bear witness.",
		"Even the sky remembers.",
		"Some say the spirit of this event lingers still.",
		"This deed reshaped the very land.",
		"Those who witnessed it were never the same.",
		"The stars align with this memory.",
		"Three generations have passed the tale.",
	]
	var idx: int = _rng_index("mut_desc", legend.name + str(legend.mutations.size()), legend.tick_created, embellishments.size())
	var emb: String = embellishments[idx]
	if legend.description.length() + emb.length() > 300:
		return emb
	return legend.description + " " + emb

## Process legend decay — legends fade if significance stays low too long.
func _process_decay(tick: int) -> void:
	var to_fade: Array = []
	for legend in _legends:
		if legend.faded:
			continue
		if legend.significance < FADE_THRESHOLD_SIGNIFICANCE:
			var age_since_spread: int = tick - maxi(legend.tick_last_spread, legend.tick_created)
			if age_since_spread >= FADE_TICKS:
				to_fade.append(legend)
	for legend in to_fade:
		legend.faded = true
		legend_faded.emit(legend.name, tick)
		_record_fade_event(legend, tick)

## Process legend merging — similar legends merge into composite.
func _process_merges(tick: int) -> void:
	var merged_names: Array = []
	for i in range(_legends.size()):
		var a: Legend = _legends[i]
		if a.faded or a.name in merged_names:
			continue
		for j in range(i + 1, _legends.size()):
			var b: Legend = _legends[j]
			if b.faded or b.name in merged_names:
				continue
			if not _can_merge_legends(a, b):
				continue
			var merged: Legend = _merge_two_legends(a, b, tick)
			if merged != null:
				merged_names.append(a.name)
				merged_names.append(b.name)
				_legends.append(merged)
				legend_merged.emit(merged.name, merged.name, 2, tick)
				_record_merge_event(a, b, merged, tick)
	if not merged_names.is_empty():
		var surviving: Array = []
		for legend in _legends:
			if not (legend.faded or legend.name in merged_names):
				surviving.append(legend)
		_legends = surviving

func _can_merge_legends(a: Legend, b: Legend) -> bool:
	if a.category != b.category:
		return false
	var shared_settlements: int = 0
	for s in a.involved_settlements:
		if b.involved_settlements.has(s):
			shared_settlements += 1
	if shared_settlements < 1 and a.origin_location != b.origin_location:
		var same_region: bool = abs(a.origin_location - b.origin_location) <= 5
		if not same_region:
			return false
	return abs(a.significance - b.significance) <= 30.0 and abs(a.spread - b.spread) <= 30.0

func _merge_two_legends(a: Legend, b: Legend, tick: int) -> Legend:
	var merged := Legend.new()
	var seed: StringName = StringName("merge_name:" + a.name + b.name)
	if _rng_chance("merge_name_pick", a.name + b.name, tick, 0.5):
		merged.name = "The Composite " + a.name
	else:
		merged.name = a.name + " & " + b.name
	merged.description = a.description + " " + b.description
	if merged.description.length() > 400:
		merged.description = merged.description.left(397) + "..."
	merged.origin_event_type = a.origin_event_type
	merged.origin_tick = mini(a.origin_tick, b.origin_tick)
	merged.origin_location = a.origin_location
	merged.involved_pawns = a.involved_pawns.duplicate()
	for p in b.involved_pawns:
		if not merged.involved_pawns.has(p):
			merged.involved_pawns.append(p)
	merged.involved_settlements = a.involved_settlements.duplicate()
	for s in b.involved_settlements:
		if not merged.involved_settlements.has(s):
			merged.involved_settlements.append(s)
	merged.significance = clampf((a.significance + b.significance) * 0.6, 5.0, 100.0)
	merged.spread = clampf((a.spread + b.spread) * 0.5, 5.0, 100.0)
	merged.tick_created = tick
	merged.tick_last_spread = tick
	merged.category = a.category
	merged.known_in_settlements = a.known_in_settlements.duplicate()
	for s in b.known_in_settlements:
		if not merged.known_in_settlements.has(s):
			merged.known_in_settlements.append(s)
	merged.mutations = a.mutations.duplicate()
	merged.mutations.append_array(b.mutations)
	merged.tier = merged.compute_tier()
	return merged

## Influence settlement culture based on dominant legends in the area.
func _process_cultural_influence(tick: int) -> void:
	var ce := get_node_or_null("/root/CulturalExchange")
	if ce == null or not ce.has_method("get_cultural_profile") or not ce.has_method("set_trait"):
		return
	var sm := get_node_or_null("/root/SettlementMemory")
	if sm == null:
		return
	var settlements: Array = _get_all_settlement_centers(sm)
	for center in settlements:
		var local_legends: Array = _get_legends_known_at(center)
		if local_legends.is_empty():
			continue
		var dominant: Legend = local_legends[0]
		for lg in local_legends:
			if lg.spread > dominant.spread:
				dominant = lg
		var influence_strength: float = dominant.spread * dominant.significance * 0.0001
		if influence_strength < 0.05:
			continue
		match dominant.category:
			LegendCategory.HERO_DEED, LegendCategory.FOUNDING_MYTH:
				if _rng_chance("legend_influence_gov", str(center) + str(tick), tick, influence_strength):
					ce.set_trait(center, "governance_attitude", "militaristic", tick)
			LegendCategory.CATASTROPHE, LegendCategory.CURSE:
				if _rng_chance("legend_influence_death", str(center) + str(tick), tick, influence_strength * 0.5):
					ce.set_trait(center, "death_rite", "crypt_storage", tick)
			LegendCategory.DISCOVERY:
				if _rng_chance("legend_influence_tech", str(center) + str(tick), tick, influence_strength * 0.5):
					var profile: Dictionary = ce.get_cultural_profile(center)
					if not profile.is_empty():
						pass
			LegendCategory.ROMANCE_EPIC:
				if _rng_chance("legend_influence_art", str(center) + str(tick), tick, influence_strength * 0.5):
					ce.set_trait(center, "art_style", "grandiose", tick)
			LegendCategory.MIRACLE:
				if _rng_chance("legend_influence_religion", str(center) + str(tick), tick, influence_strength * 0.5):
					ce.set_trait(center, "religion", "celestial", tick)

## Integration with NarrativeSystem — generate legends from resolved narrative threads.
func generate_legend_from_narrative(thread: Dictionary, tick: int) -> void:
	var title: String = str(thread.get("title", "Legend"))
	var category_str: String = str(thread.get("category", "tragedy"))
	var category: int = _narrative_category_to_legend_category(category_str)
	var characters: Array = thread.get("key_characters", [])
	var settlements: Array = thread.get("key_settlements", [])
	var character_ids: Array[int] = []
	for c in characters:
		if c is int:
			character_ids.append(c)
	var settlement_ids: Array[int] = []
	for s in settlements:
		if s is int:
			settlement_ids.append(s)
	var origin: int = settlement_ids[0] if not settlement_ids.is_empty() else -1
	var desc: String = "A " + category_str + " woven from the threads of fate."
	var events_data: Array = thread.get("events", [])
	if not events_data.is_empty():
		var last_ev: Dictionary = events_data[-1] if events_data[-1] is Dictionary else {}
		desc = str(last_ev.get("description", desc))
	var significance: float = 25.0 + float(thread.get("tension", 10.0)) * 0.5
	create_legend(title, desc, "narrative_resolution", category, tick, origin, character_ids, settlement_ids, significance)

func _narrative_category_to_legend_category(ncat: String) -> int:
	match ncat:
		"war": return LegendCategory.HERO_DEED
		"romance": return LegendCategory.ROMANCE_EPIC
		"tragedy": return LegendCategory.CATASTROPHE
		"triumph": return LegendCategory.FOUNDING_MYTH
		"mystery": return LegendCategory.DISCOVERY
	return LegendCategory.HERO_DEED

## Map event type strings to LegendCategory.
func _event_type_to_category(ev_type: String) -> int:
	if ev_type in ["heroic_death", "great_battle", "war_proposed", "war_battle_spawned"]:
		return LegendCategory.HERO_DEED
	if ev_type in ["cataclysm_started", "cataclysm_ended", "disaster_started", "ai_natural_disaster", "settlement_destroyed", "bloodline_extinct"]:
		return LegendCategory.CATASTROPHE
	if ev_type in ["settlement_founded", "settlement_revival", "polity_founded", "polity_merged"]:
		return LegendCategory.FOUNDING_MYTH
	if ev_type in ["major_discovery", "first_of_type", "knowledge_inscribed", "trade_route_opened"]:
		return LegendCategory.DISCOVERY
	if ev_type == "leadership_change":
		return LegendCategory.BETRAYAL
	if ev_type in ["ritual_performed", "sacred_site_established"]:
		return LegendCategory.MIRACLE
	return LegendCategory.HERO_DEED

## Generate legend name from event.
func _generate_legend_name(event: Dictionary) -> String:
	var ev_type: String = str(event.get("type", ""))
	match ev_type:
		"heroic_death":
			return "The Legend of " + str(event.get("pawn_name", "the Fallen Hero"))
		"pawn_death":
			var pname: String = str(event.get("pawn_name", str(event.get("n", "Unknown"))))
			return "The Passing of " + pname
		"settlement_founded":
			return "The Founding of " + str(event.get("name", "the Settlement"))
		"settlement_destroyed":
			return "The Fall of " + str(event.get("name", "the Settlement"))
		"cataclysm_started", "disaster_started", "ai_natural_disaster":
			return "The Great " + str(event.get("name", str(event.get("cause", "Cataclysm"))))
		"great_battle":
			return "The Battle of " + str(event.get("location_name", "Glory"))
		"war_proposed":
			return "The " + str(event.get("aggressor", "Unknown")) + " Conflict"
		"major_discovery", "first_of_type":
			return "The Discovery of " + str(event.get("name", "the Unknown"))
		"leadership_change":
			return "The Rise of " + str(event.get("new_leader_name", "the New Leader"))
		"settlement_revival":
			return "The Rebirth of " + str(event.get("name", "the Settlement"))
		"ritual_performed":
			return "The Great Ritual"
		"sacred_site_established":
			return "The Consecration of " + str(event.get("name", "the Sacred Site"))
		"bloodline_extinct":
			return "The Extinction of " + str(event.get("family_name", "the Ancient Line"))
		"knowledge_inscribed":
			return "The Inscription of " + str(event.get("knowledge_name", "Ancient Wisdom"))
		"polity_founded":
			return "The Founding of " + str(event.get("name", "the Polity"))
		"polity_merged":
			return "The Unification"
		"trade_route_opened":
			return "The Opening of the " + str(event.get("route_name", "Great Trade Way"))
	return "Legend of " + str(event.get("name", "a Distant Event"))

## Generate legend description from event.
func _generate_legend_description(event: Dictionary, category: int) -> String:
	var ev_type: String = str(event.get("type", ""))
	match ev_type:
		"heroic_death":
			return "A great hero fell in battle, their sacrifice echoing through the ages."
		"pawn_death":
			return "A notable figure passed from this world, leaving an indelible mark on memory."
		"settlement_founded":
			return "Brave pioneers established a new home against the wilderness."
		"settlement_destroyed":
			return "A once-great settlement fell to ruin, its memory preserved in song."
		"cataclysm_started":
			return "The world itself groaned as disaster of unimaginable scale unfolded."
		"great_battle":
			var cas: int = int(event.get("casualties", 0))
			return "A mighty clash that claimed " + str(_casi(maxi(1, cas), 0)) + " lives, forever changing the land."
		"major_discovery":
			return "Revealed knowledge that reshaped the understanding of the world."
		"leadership_change":
			return "Power changed hands in a pivotal moment that would define an era."
		"ritual_performed":
			return "A sacred rite of immense power was completed, binding fate itself."
		"bloodline_extinct":
			return "An ancient bloodline reached its end, a world sundered from its past."
		"knowledge_inscribed":
			return "Wisdom was carved into permanence, defying the erosion of time."
		_:
			return "An extraordinary event that the world will not soon forget."

## Fade the oldest (by last spread) legend to make room.
func _fade_oldest_legend() -> void:
	var oldest: Legend = null
	var oldest_spread: int = 0
	for legend in _legends:
		if legend.faded:
			continue
		var spread_tick: int = maxi(legend.tick_last_spread, legend.tick_created)
		if oldest == null or spread_tick < oldest_spread:
			oldest = legend
			oldest_spread = spread_tick
	if oldest != null:
		oldest.faded = true
		var tick: int = GameManager.tick_count if GameManager != null else 0
		legend_faded.emit(oldest.name, tick)

## --- Helper functions ---

func _rng_chance(stream: String, salt: String, tick: int, probability: float) -> bool:
	if WorldRNG == null:
		return randf() < probability
	var seed_name: StringName = StringName("legend:" + stream + ":" + salt)
	return WorldRNG.chance_for(seed_name, probability, tick)

func _rng_unit(stream: String, salt: String, tick: int) -> float:
	if WorldRNG == null:
		return randf()
	var seed_name: StringName = StringName("legend:" + stream + ":" + salt)
	return WorldRNG.unit(seed_name, tick)

func _rng_range(stream: String, salt: String, tick: int, min_val: float, max_val: float) -> float:
	if WorldRNG == null:
		return randf_range(min_val, max_val)
	var seed_name: StringName = StringName("legend:" + stream + ":" + salt)
	return WorldRNG.range_for(seed_name, min_val, max_val, tick)

func _rng_index(stream: String, salt: String, tick: int, size: int) -> int:
	if size <= 0:
		return -1
	if WorldRNG == null:
		return randi() % size
	var seed_name: StringName = StringName("legend:" + stream + ":" + salt)
	return WorldRNG.index_for(seed_name, size, tick)

func _get_all_settlement_centers(sm: Node) -> Array[int]:
	var out: Array[int] = []
	var settlements: Variant = null
	if sm.has_method("get_settlements"):
		settlements = sm.get_settlements()
	elif sm.has("settlements"):
		settlements = sm.settlements
	if settlements == null:
		return out
	if settlements is Array:
		for st in settlements:
			if st is Dictionary:
				var center: int = int((st as Dictionary).get("center_region", -1))
				if center >= 0 and not out.has(center):
					out.append(center)
	return out

func _find_nearby_settlements(center: int, all_centers: Array[int], radius: int) -> Array[int]:
	var out: Array[int] = []
	var cx: int = center % 256
	var cy: int = center / 256
	for sc in all_centers:
		if sc == center:
			continue
		var ox: int = sc % 256
		var oy: int = sc / 256
		var dist: float = Vector2(cx, cy).distance_to(Vector2(ox, oy))
		if dist <= float(radius):
			out.append(sc)
	return out

func _casi(val: int, digits: int) -> String:
	var s: String = str(val)
	if digits <= 0:
		return s
	var out: String = ""
	var count: int = 0
	for i in range(s.length() - 1, -1, -1):
		if count > 0 and count % digits == 0:
			out = "," + out
		out = s[i] + out
		count += 1
	return out

## --- Query functions ---

func get_all_legends() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for legend in _legends:
		if not legend.faded:
			out.append(legend.to_dict())
	return out

func get_all_legends_including_faded() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for legend in _legends:
		out.append(legend.to_dict())
	return out

func get_settlement_legends(center: int, min_spread: float = 0.0) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for legend in _legends:
		if legend.faded:
			continue
		if not legend.known_in_settlements.has(center):
			continue
		if legend.spread < min_spread:
			continue
		out.append(legend.to_dict())
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.get("spread", 0.0)) > float(b.get("spread", 0.0)))
	return out

func get_legends_for_origin(origin: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for legend in _legends:
		if legend.faded:
			continue
		if legend.origin_location == origin:
			out.append(legend.to_dict())
	return out

func get_legends_by_category(category: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for legend in _legends:
		if legend.faded:
			continue
		if legend.category == category:
			out.append(legend.to_dict())
	return out

func get_legends_by_tier(tier: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for legend in _legends:
		if legend.faded:
			continue
		if legend.compute_tier() == tier:
			out.append(legend.to_dict())
	return out

func get_legend_by_name(name: String) -> Dictionary:
	for legend in _legends:
		if legend.name == name and not legend.faded:
			return legend.to_dict()
	return {}

func get_legend_timeline(name: String) -> Array[Dictionary]:
	var timeline: Array[Dictionary] = []
	for legend in _legends:
		if legend.name != name:
			continue
		timeline.append({
			"tick": legend.tick_created,
			"event": "created",
			"description": "Legend '" + legend.name + "' was born from " + legend.origin_event_type,
		})
		for m in legend.mutations:
			if m is MutationRecord:
				timeline.append({
					"tick": m.tick,
					"event": "mutated",
					"field": m.field,
					"old_value": m.old_value,
					"new_value": m.new_value,
					"description": m.field + " changed from '" + m.old_value + "' to '" + m.new_value + "'",
				})
		if legend.tick_last_spread > legend.tick_created:
			timeline.append({
				"tick": legend.tick_last_spread,
				"event": "last_spread",
				"description": "Legend last spread to new settlements",
				"known_in": legend.known_in_settlements.size(),
			})
		if legend.faded:
			timeline.append({
				"tick": _find_fade_tick(legend),
				"event": "faded",
				"description": "Legend faded from collective memory",
			})
	timeline.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("tick", 0)) < int(b.get("tick", 0)))
	return timeline

func _find_fade_tick(legend: Legend) -> int:
	return maxi(legend.tick_last_spread, legend.tick_created) + FADE_TICKS

func _get_legends_known_at(center: int) -> Array:
	var out: Array = []
	for legend in _legends:
		if legend.faded:
			continue
		if legend.known_in_settlements.has(center):
			out.append(legend)
	return out

func _category_name_to_enum(name: String) -> int:
	match name:
		"hero_deed": return LegendCategory.HERO_DEED
		"catastrophe": return LegendCategory.CATASTROPHE
		"founding_myth": return LegendCategory.FOUNDING_MYTH
		"romance_epic": return LegendCategory.ROMANCE_EPIC
		"betrayal": return LegendCategory.BETRAYAL
		"discovery": return LegendCategory.DISCOVERY
		"miracle": return LegendCategory.MIRACLE
		"curse": return LegendCategory.CURSE
	return LegendCategory.HERO_DEED

## --- Stats ---

func get_stats() -> Dictionary:
	var by_category: Dictionary = {}
	var by_tier: Dictionary = {}
	var total_significance: float = 0.0
	var total_spread: float = 0.0
	var active_count: int = 0
	var faded_count: int = 0
	var total_mutations: int = 0
	for legend in _legends:
		if legend.faded:
			faded_count += 1
		else:
			active_count += 1
			total_significance += legend.significance
			total_spread += legend.spread
			total_mutations += legend.mutations.size()
			var cat_name: String = str(legend.category)
			by_category[cat_name] = int(by_category.get(cat_name, 0)) + 1
			var tier_name: String = str(legend.compute_tier())
			by_tier[tier_name] = int(by_tier.get(tier_name, 0)) + 1
	return {
		"total_legends": _legends.size(),
		"active_legends": active_count,
		"faded_legends": faded_count,
		"avg_significance": (total_significance / float(maxi(1, active_count))) if active_count > 0 else 0.0,
		"avg_spread": (total_spread / float(maxi(1, active_count))) if active_count > 0 else 0.0,
		"total_mutations": total_mutations,
		"by_category": by_category,
		"by_tier": by_tier,
		"legend_capacity": MAX_LEGENDS,
	}

func get_legend_count() -> int:
	var count: int = 0
	for legend in _legends:
		if not legend.faded:
			count += 1
	return count

func get_faded_count() -> int:
	var count: int = 0
	for legend in _legends:
		if legend.faded:
			count += 1
	return count

func get_tier_label(tier: int) -> String:
	match tier:
		LegendTier.LOCAL: return "Local"
		LegendTier.REGIONAL: return "Regional"
		LegendTier.CONTINENTAL: return "Continental"
		LegendTier.MYTHIC: return "Mythic"
	return "Unknown"

func get_category_label(category: int) -> String:
	match category:
		LegendCategory.HERO_DEED: return "Heroic Deed"
		LegendCategory.CATASTROPHE: return "Catastrophe"
		LegendCategory.FOUNDING_MYTH: return "Founding Myth"
		LegendCategory.ROMANCE_EPIC: return "Romance Epic"
		LegendCategory.BETRAYAL: return "Betrayal"
		LegendCategory.DISCOVERY: return "Discovery"
		LegendCategory.MIRACLE: return "Miracle"
		LegendCategory.CURSE: return "Curse"
	return "Unknown"

## --- Event recording to WorldMemory ---

func _record_legend_event(event_type: String, legend: Legend, tick: int) -> void:
	var wm := get_node_or_null("/root/WorldMemory")
	if wm == null or not wm.has_method("record_event"):
		return
	wm.record_event({
		"type": event_type,
		"legend_name": legend.name,
		"category": legend.category,
		"origin_location": legend.origin_location,
		"significance": legend.significance,
		"tick": tick,
	})

func _record_spread_event(legend: Legend, from_center: int, to_center: int, tick: int) -> void:
	var wm := get_node_or_null("/root/WorldMemory")
	if wm == null or not wm.has_method("record_event"):
		return
	wm.record_event({
		"type": "legend_spread",
		"legend_name": legend.name,
		"from_center": from_center,
		"to_center": to_center,
		"tick": tick,
	})

func _record_mutation_event(legend: Legend, mutation: MutationRecord, tick: int) -> void:
	var wm := get_node_or_null("/root/WorldMemory")
	if wm == null or not wm.has_method("record_event"):
		return
	wm.record_event({
		"type": "legend_mutated",
		"legend_name": legend.name,
		"field": mutation.field,
		"old_value": mutation.old_value,
		"new_value": mutation.new_value,
		"tick": tick,
	})

func _record_fade_event(legend: Legend, tick: int) -> void:
	var wm := get_node_or_null("/root/WorldMemory")
	if wm == null or not wm.has_method("record_event"):
		return
	wm.record_event({
		"type": "legend_faded",
		"legend_name": legend.name,
		"tick": tick,
	})

func _record_merge_event(a: Legend, b: Legend, merged: Legend, tick: int) -> void:
	var wm := get_node_or_null("/root/WorldMemory")
	if wm == null or not wm.has_method("record_event"):
		return
	wm.record_event({
		"type": "legend_merged",
		"merged_name": merged.name,
		"source_a": a.name,
		"source_b": b.name,
		"tick": tick,
	})

## --- Legend from NarrativeSystem (external call) ---

func on_narrative_resolved(thread_title: String, resolution: String, thread_data: Dictionary, tick: int) -> void:
	var ns := get_node_or_null("/root/NarrativeSystem")
	if ns == null:
		return
	if not ns.has_method("get_active_threads") and not ns.has_method("get_resolved_threads"):
		return
	var all_threads: Array = ns.get_resolved_threads() if ns.has_method("get_resolved_threads") else []
	all_threads += ns.get_active_threads() if ns.has_method("get_active_threads") else []
	for t in all_threads:
		if not (t is Dictionary):
			continue
		var td: Dictionary = t as Dictionary
		if str(td.get("title", "")) == thread_title:
			generate_legend_from_narrative(td, tick)
			return

## --- Save / Load ---

func to_save_dict() -> Dictionary:
	var legend_list: Array = []
	for legend in _legends:
		legend_list.append(legend.to_dict())
	return {
		"legends": legend_list,
		"last_legend_tick": _last_legend_tick,
		"last_spread_tick": _last_spread_tick,
		"last_decay_tick": _last_decay_tick,
		"last_merge_tick": _last_merge_tick,
		"last_influence_tick": _last_influence_tick,
	}

func from_save_dict(d: Variant) -> void:
	clear()
	if d == null or not (d is Dictionary):
		return
	var data: Dictionary = d as Dictionary
	var legend_list: Variant = data.get("legends", [])
	if legend_list is Array:
		for entry in legend_list:
			if not (entry is Dictionary):
				continue
			var ld: Dictionary = entry as Dictionary
			var legend := Legend.new()
			legend.name = str(ld.get("name", "Unknown"))
			legend.description = str(ld.get("description", ""))
			legend.origin_event_type = str(ld.get("origin_event_type", ""))
			legend.origin_tick = int(ld.get("origin_tick", 0))
			legend.origin_location = int(ld.get("origin_location", -1))
			var pawns: Variant = ld.get("involved_pawns", [])
			if pawns is Array:
				for p in pawns:
					if p is int:
						legend.involved_pawns.append(p)
			var settlements: Variant = ld.get("involved_settlements", [])
			if settlements is Array:
				for s in settlements:
					if s is int:
						legend.involved_settlements.append(s)
			var known: Variant = ld.get("known_in_settlements", [])
			if known is Array:
				for k in known:
					if k is int:
						legend.known_in_settlements.append(k)
			legend.significance = float(ld.get("significance", 30.0))
			legend.spread = float(ld.get("spread", 10.0))
			legend.tick_created = int(ld.get("tick_created", 0))
			legend.tick_last_spread = int(ld.get("tick_last_spread", -1))
			legend.category = int(ld.get("category", LegendCategory.HERO_DEED))
			legend.tier = int(ld.get("tier", LegendTier.LOCAL))
			legend.faded = bool(ld.get("faded", false))
			var muts: Variant = ld.get("mutations", [])
			if muts is Array:
				for m in muts:
					if m is Dictionary:
						var md: Dictionary = m as Dictionary
						var mr := MutationRecord.new(
							int(md.get("tick", 0)),
							str(md.get("field", "")),
							str(md.get("old_value", "")),
							str(md.get("new_value", "")),
							int(md.get("spread_origin", -1))
						)
						legend.mutations.append(mr)
			_legends.append(legend)
	if data.has("last_legend_tick"):
		_last_legend_tick = int(data["last_legend_tick"])
	if data.has("last_spread_tick"):
		_last_spread_tick = int(data["last_spread_tick"])
	if data.has("last_decay_tick"):
		_last_decay_tick = int(data["last_decay_tick"])
	if data.has("last_merge_tick"):
		_last_merge_tick = int(data["last_merge_tick"])
	if data.has("last_influence_tick"):
		_last_influence_tick = int(data["last_influence_tick"])

func clear() -> void:
	_legends.clear()
	_last_legend_tick = -999999
	_last_spread_tick = -999999
	_last_decay_tick = -999999
	_last_merge_tick = -999999
	_last_influence_tick = -999999
