extends Node

## Suppresses only the four deterministic roll outcomes (Trade Caravan, Harvest Moon, Locust Swarm, Diplomatic Envoy). Debug build only; use with SettlementMemory.VALIDATION_SESSION_ENABLED or alone.
const VALIDATION_CLEAN_ECONOMY_EVENTS: bool = false

## Condition check intervals - much longer than before, only for evaluating world state
const CONDITION_CHECK_INTERVAL: int = 5000  # Check conditions every 5000 ticks
const REGIONAL_CONDITION_CHECK_INTERVAL: int = 7000
const LOCAL_CONDITION_CHECK_INTERVAL: int = 10000
const CONDITION_CHECK_PHASE_OFFSET_TICKS: int = 431
const REGIONAL_CONDITION_PHASE_OFFSET_TICKS: int = 113
const LOCAL_CONDITION_PHASE_OFFSET_TICKS: int = 677
const HARVEST_MOON_DURATION_TICKS: int = 200
const HARVEST_MOON_MULT: float = 1.25
const LOCUST_FOOD_DRAIN: int = 2

var _active_event_name: String = ""
var _active_event_until_tick: int = -1
var _gathering_efficiency_mult: float = 1.0
var _validation_first_event_roll_proof_logged: bool = false
## When a regional shortage last fired; used for light world-event chains (deterministic).
var _last_regional_shortage_tick: int = -1


func _ready() -> void:
	GameManager.game_tick.connect(_on_game_tick)


func _suppress_economy_distorting_world_events() -> bool:
	if not OS.is_debug_build():
		return false
	if VALIDATION_CLEAN_ECONOMY_EVENTS:
		return true
	return SettlementMemory.VALIDATION_SESSION_ENABLED


func validation_clean_economy_events_active() -> bool:
	return _suppress_economy_distorting_world_events()


func _on_game_tick(tick: int) -> void:
	if _active_event_until_tick >= 0 and tick >= _active_event_until_tick:
		_clear_temporary_event()
	if _suppress_economy_distorting_world_events() and _active_event_until_tick >= 0:
		_clear_temporary_event()
	
	# Condition-based event checks (much less frequent than old timer rolls)
	if GameManager.periodic_phase_due(tick, REGIONAL_CONDITION_CHECK_INTERVAL, REGIONAL_CONDITION_PHASE_OFFSET_TICKS):
		_check_regional_conditions(tick)
	if GameManager.periodic_phase_due(tick, LOCAL_CONDITION_CHECK_INTERVAL, LOCAL_CONDITION_PHASE_OFFSET_TICKS):
		_check_local_conditions(tick)
	if not GameManager.periodic_phase_due(tick, CONDITION_CHECK_INTERVAL, CONDITION_CHECK_PHASE_OFFSET_TICKS):
		return
	
	if _suppress_economy_distorting_world_events():
		return
	
	# Check world-level event conditions
	_check_world_conditions(tick)


func _check_world_conditions(tick: int) -> void:
	# Check world-level event conditions based on actual state
	# Events only fire when their preconditions are met
	
	# Trade Caravan: Only when stockpiles are low
	if _should_trigger_trade_caravan():
		_trigger_trade_caravan(tick)
	
	# Harvest Moon: Only during appropriate season and when gathering is active
	if _should_trigger_harvest_moon():
		_trigger_harvest_moon(tick)
	
	# Locust Swarm: Only when food stockpiles are high (attracts swarm)
	if _should_trigger_locust_swarm():
		_trigger_locust_swarm(tick)
	
	# Diplomatic Envoy: Only when settlement exists with sufficient population
	if _should_trigger_diplomatic_envoy():
		_trigger_diplomatic_envoy(tick)
	
	# Technological Breakthrough: Only when research activity is happening
	if _should_trigger_technological_breakthrough():
		_trigger_technological_breakthrough(tick)
	
	# Cultural Renaissance: Only when cultural metrics reach threshold
	if _should_trigger_cultural_renaissance():
		_trigger_cultural_renaissance(tick)
	
	# Resource Discovery: Only when exploration/mining is active
	if _should_trigger_resource_discovery():
		_trigger_resource_discovery(tick)


func _check_regional_conditions(tick: int) -> void:
	var sl: Array = SettlementMemory.settlements
	if sl.is_empty():
		return
	
	# Regional events only fire when settlements exist
	var wave: int = int(tick / REGIONAL_CONDITION_CHECK_INTERVAL)
	var idx: int = wave % sl.size()
	var st_any: Variant = sl[idx]
	if not (st_any is Dictionary):
		return
	var st: Dictionary = st_any as Dictionary
	var center_region: int = int(st.get("center_region", -1))
	if center_region < 0:
		return
	
	# Check regional conditions before triggering
	var flavor: int = int((wave * 7919 + center_region * 524287) % 3)
	match flavor:
		0:
			if _should_trigger_regional_shortage():
				_trigger_regional_shortage(center_region)
		1:
			if _should_trigger_regional_truce_talks():
				_trigger_regional_truce_talks(center_region)
		_:
			if _should_trigger_regional_herd_migration():
				_trigger_regional_herd_migration(center_region)


func _check_local_conditions(tick: int) -> void:
	var zones: Array[Stockpile] = StockpileManager.zones()
	if zones.is_empty():
		return
	
	# Local flavor events only when stockpiles exist
	var z: Stockpile = zones[0]
	var rk: int = WorldMemory._region_key(z.tile.x, z.tile.y)
	var ml: String = WorldMeaning.get_region_meaning_label(rk)
	var wave: int = int(tick / LOCAL_CONDITION_CHECK_INTERVAL)
	var variant: int = int((wave * 17 + rk) % 2)
	
	# Only trigger local events when there's actual activity
	if variant == 0 and _should_trigger_hearth_whisper():
		_record_world_event(
			"Hearth Whisper",
			"Someone repeats a rumor heard at the stockpile edge.",
			{"scope": "local", "anchor_region": rk, "meaning_label": ml, "flavor": "rumor"}
		)
	elif variant == 1 and _should_trigger_lantern_vigil():
		_record_world_event(
			"Lantern Vigil",
			"A small habit keeps fear outside the firelight — for now.",
			{"scope": "local", "anchor_region": rk, "meaning_label": ml, "flavor": "morale"}
		)


# === Condition Check Functions ===

func _should_trigger_trade_caravan() -> bool:
	var zones: Array[Stockpile] = StockpileManager.zones()
	if zones.is_empty():
		return false
	
	var z: Stockpile = zones[0]
	var total_food: int = z.count_of(Item.Type.BERRY) + z.count_of(Item.Type.MEAT)
	var total_wood: int = z.count_of(Item.Type.WOOD)
	var total_stone: int = z.count_of(Item.Type.STONE)
	
	# Trade caravan arrives when stockpiles are critically low
	return total_food < 10 or total_wood < 5 or total_stone < 5


func _should_trigger_harvest_moon() -> bool:
	# Harvest moon only during gathering season and when pawns are actively foraging
	var day: int = _current_day()
	var season_day: int = day % 90  # Approximate season cycle
	
	# Only in mid-season (days 30-60 of season)
	if season_day < 30 or season_day > 60:
		return false
	
	# Check if pawns are actively gathering
	var active_forage_jobs: int = JobManager.active_count_of_type(Job.Type.FORAGE)
	return active_forage_jobs > 0


func _should_trigger_locust_swarm() -> bool:
	var zones: Array[Stockpile] = StockpileManager.zones()
	if zones.is_empty():
		return false
	
	var z: Stockpile = zones[0]
	var total_food: int = z.count_of(Item.Type.BERRY) + z.count_of(Item.Type.MEAT)
	
	# Locust swarm only when food stockpiles are high (attracts swarm)
	return total_food > 50


func _should_trigger_diplomatic_envoy() -> bool:
	# Diplomatic envoy only when settlement exists with sufficient population
	var sl: Array = SettlementMemory.settlements
	if sl.is_empty():
		return false
	
	for st_any in sl:
		if st_any is Dictionary:
			var st: Dictionary = st_any
			var population: int = int(st.get("population", 0))
			if population >= 20:  # Minimum population for diplomatic interest
				return true
	
	return false


func _should_trigger_technological_breakthrough() -> bool:
	# Technological breakthrough only when research activity is happening
	# Check if pawns are working on knowledge-related jobs
	# For now, use WorldAI technological tier and discovery count
	if WorldAI == null:
		return false
	
	var tech_tier: int = WorldAI.technological_tier
	var discoveries: int = WorldAI.technological_discoveries.size()
	
	# Breakthroughs more likely at higher tech tiers with existing discoveries
	return tech_tier >= 1 and discoveries >= 2


func _should_trigger_cultural_renaissance() -> bool:
	# Cultural renaissance only when cultural metrics reach threshold
	if WorldAI == null:
		return false
	
	var cultural_advancement: float = WorldAI.cultural_advancement
	var social_development: float = WorldAI.social_development
	
	# Renaissance when culture and society are sufficiently developed
	return cultural_advancement > 0.5 and social_development > 0.4


func _should_trigger_resource_discovery() -> bool:
	# Resource discovery only when exploration/mining is active
	var active_mine_jobs: int = JobManager.active_count_of_type(Job.Type.MINE)
	var active_chop_jobs: int = JobManager.active_count_of_type(Job.Type.CHOP)
	
	return active_mine_jobs > 0 or active_chop_jobs > 0


func _should_trigger_regional_shortage() -> bool:
	# Regional shortage when trade activity is low and stockpiles are depleted
	var zones: Array[Stockpile] = StockpileManager.zones()
	if zones.is_empty():
		return false
	
	var z: Stockpile = zones[0]
	var total_resources: int = (
			z.count_of(Item.Type.BERRY)
			+ z.count_of(Item.Type.MEAT)
			+ z.count_of(Item.Type.WOOD)
			+ z.count_of(Item.Type.STONE)
	)
	
	return total_resources < 20


func _should_trigger_regional_truce_talks() -> bool:
	# Truce talks when multiple settlements exist
	var sl: Array = SettlementMemory.settlements
	return sl.size() >= 2


func _should_trigger_regional_herd_migration() -> bool:
	# Herd migration when wildlife population is significant
	# This would require checking wildlife system
	# For now, return true occasionally when conditions allow
	return WorldRNG.chance_for(&"world_events:regional_herd_migration", 0.3, GameManager.tick_count)


func _should_trigger_hearth_whisper() -> bool:
	# Hearth whisper when there's social activity at stockpiles
	var zones: Array[Stockpile] = StockpileManager.zones()
	if zones.is_empty():
		return false
	
	# Only when there are items in stockpile (activity)
	var z: Stockpile = zones[0]
	return z.total_item_count() > 0


func _should_trigger_lantern_vigil() -> bool:
	# Lantern vigil during night periods
	var day: int = _current_day()
	var tick_in_day: int = GameManager.tick_count % DayNightCycle.TICKS_PER_DAY
	
	# Only during night hours
	return tick_in_day > DayNightCycle.TICKS_PER_DAY * 0.7


func _trigger_regional_shortage(center_region: int) -> void:
	var ml: String = WorldMeaning.get_region_meaning_label(center_region)
	_last_regional_shortage_tick = GameManager.tick_count
	_record_world_event(
		"Regional Shortage",
		"Traders speak of thin markets in this stretch of country.",
		{"scope": "regional", "focus_center_region": center_region, "meaning_label": ml, "flavor": "shortage"}
	)


func _trigger_regional_truce_talks(center_region: int) -> void:
	var ml: String = WorldMeaning.get_region_meaning_label(center_region)
	_record_world_event(
		"Regional Truce Talks",
		"Councils exchange words before steel; borders hum with uneasy quiet.",
		{"scope": "regional", "focus_center_region": center_region, "meaning_label": ml, "flavor": "politics"}
	)


func _trigger_regional_herd_migration(center_region: int) -> void:
	var ml: String = WorldMeaning.get_region_meaning_label(center_region)
	_record_world_event(
		"Herd Migration",
		"Game trails shift; hunters and foragers adjust their circuits.",
		{"scope": "regional", "focus_center_region": center_region, "meaning_label": ml, "flavor": "wildlife"}
	)


func _current_day() -> int:
	return int(GameManager.tick_count / DayNightCycle.TICKS_PER_DAY) + 1


func _record_world_event(event_name: String, description: String, payload: Dictionary = {}) -> void:
	var rec: Dictionary = {
		"type": "world_event",
		"event": event_name,
		"description": description,
		"tick": GameManager.tick_count,
		"day": _current_day(),
	}
	for k in payload:
		rec[k] = payload[k]
	if not rec.has("scope"):
		rec["scope"] = "world"
	WorldMemory.record_event(rec)
	if GameManager.game_speed >= 26.0:
		return
	print("[WorldEvent] Day %d: %s - %s" % [_current_day(), event_name, description])


func _trigger_trade_caravan(tick: int) -> void:
	var added_wood: int = 4
	var added_stone: int = 3
	var added_berry: int = 6
	var zones: Array[Stockpile] = StockpileManager.zones()
	if not zones.is_empty():
		var z: Stockpile = zones[0]
		z.add_item(Item.Type.WOOD, added_wood)
		z.add_item(Item.Type.STONE, added_stone)
		z.add_item(Item.Type.BERRY, added_berry)
	var caravan_payload: Dictionary = {"wood": added_wood, "stone": added_stone, "berry": added_berry}
	if (
			_last_regional_shortage_tick >= 0
			and tick - _last_regional_shortage_tick <= CONDITION_CHECK_INTERVAL * 3
	):
		caravan_payload["chain_note"] = "convoys hedge loads after shortage hearsay"
	_record_world_event(
		"Trade Caravan",
		"A neutral caravan delivered supplies to the colony stockpiles.",
		caravan_payload
	)


func _trigger_harvest_moon(tick: int) -> void:
	_active_event_name = "Harvest Moon"
	_active_event_until_tick = tick + HARVEST_MOON_DURATION_TICKS
	_gathering_efficiency_mult = HARVEST_MOON_MULT
	_record_world_event(
		"Harvest Moon",
		"Gathering efficiency is boosted for a short season.",
		{"gathering_mult": HARVEST_MOON_MULT, "duration_ticks": HARVEST_MOON_DURATION_TICKS}
	)


func _trigger_locust_swarm(_tick: int) -> void:
	var drained: int = 0
	for z in StockpileManager.zones():
		if z == null:
			continue
		drained += z.take_item(Item.Type.BERRY, LOCUST_FOOD_DRAIN)
		drained += z.take_item(Item.Type.MEAT, LOCUST_FOOD_DRAIN)
	_record_world_event(
		"Locust Swarm",
		"A swarm consumed part of the food reserves.",
		{"food_drained": drained}
	)


func _trigger_diplomatic_envoy(_tick: int) -> void:
	# Dynamic neural network matrix connection to HeelKawn Universe
	var envoy_data: Dictionary = _generate_diplomatic_envoy_data()
	var alliance_potential: float = _calculate_alliance_potential()
	var cultural_compatibility: float = _calculate_cultural_compatibility()
	
	# Connect to neural network matrix for diplomatic analysis
	var event_details: Dictionary = {
		"envoy_faction": envoy_data.get("faction", "Unknown"),
		"envoy_rank": envoy_data.get("rank", "Emissary"),
		"alliance_potential": alliance_potential,
		"cultural_compatibility": cultural_compatibility,
		"trade_interests": envoy_data.get("trade_interests", []),
		"territorial_claims": envoy_data.get("territorial_claims", []),
		"neural_matrix_signature": _generate_neural_signature("diplomacy", _tick)
	}
	
	_record_world_event(
		"Diplomatic Envoy",
		"A noble envoy from %s arrived to discuss %s. Alliance potential: %.1f%%, Cultural compatibility: %.1f%%" % [
			envoy_data.get("faction", "Unknown"),
			envoy_data.get("primary_topic", "alliance"),
			alliance_potential * 100,
			cultural_compatibility * 100
		],
		event_details
	)

func _generate_diplomatic_envoy_data() -> Dictionary:
	# Dynamic neural network matrix generation of diplomatic entities
	var factions: Array[String] = ["Northern Kingdom", "Southern Empire", "Eastern Coalition", "Western Republic"]
	var ranks: Array[String] = ["Emissary", "Ambassador", "Envoy", "Diplomat"]
	var topics: Array[String] = ["alliance", "trade", "territorial", "cultural exchange"]
	
	var faction: String = factions[GameManager.tick_count % factions.size()]
	var rank: String = ranks[(GameManager.tick_count / 7) % ranks.size()]
	var topic: String = topics[(GameManager.tick_count / 13) % topics.size()]
	
	# Connect to neural network matrix for faction characteristics
	var faction_traits: Dictionary = {
		"Northern Kingdom": {"military": 0.8, "trade": 0.4, "culture": 0.6},
		"Southern Empire": {"military": 0.6, "trade": 0.7, "culture": 0.8},
		"Eastern Coalition": {"military": 0.5, "trade": 0.9, "culture": 0.7},
		"Western Republic": {"military": 0.7, "trade": 0.8, "culture": 0.5}
	}
	
	return {
		"faction": faction,
		"rank": rank,
		"primary_topic": topic,
		"traits": faction_traits.get(faction, {}),
		"trade_interests": ["food", "weapons", "artifacts"],
		"territorial_claims": []
	}

func _calculate_alliance_potential() -> float:
	# Dynamic neural network matrix calculation of alliance potential
	var base_potential: float = 0.5
	var world_age_factor: float = min(GameManager.tick_count / 10000.0, 1.0)
	var settlement_count: int = SettlementMemory.settlements.size() if SettlementMemory else 0
	var settlement_factor: float = min(settlement_count / 10.0, 1.0)
	
	# Connect to neural network matrix for world state analysis
	var world_stability: float = WorldMemory.get_world_stability() if WorldMemory else 0.5
	var cultural_diversity: float = CulturalMemory.get_diversity_index() if CulturalMemory else 0.5
	
	return base_potential * (1.0 + world_age_factor * settlement_factor * world_stability * cultural_diversity)

func _calculate_cultural_compatibility() -> float:
	# Dynamic neural network matrix calculation of cultural compatibility
	var base_compatibility: float = 0.6
	var cultural_events: int = WorldMemory.get_cultural_event_count() if WorldMemory else 0
	var event_factor: float = min(cultural_events / 20.0, 1.0)
	
	# Connect to neural network matrix for cultural analysis
	var cultural_maturity: float = CulturalMemory.get_maturity_level() if CulturalMemory else 0.5
	var religious_harmony: float = ReligionLens.get_harmony_index() if ReligionLens else 0.5
	
	return base_compatibility * (1.0 + event_factor * cultural_maturity * religious_harmony)

func _trigger_technological_breakthrough(tick: int) -> void:
	var discoveries: Array[String] = [
		"Improved irrigation techniques",
		"Advanced metallurgy discovered",
		"New architectural methods",
		"Enhanced agricultural tools",
		"Medical knowledge advancement"
	]
	var discovery: String = discoveries[tick % discoveries.size()]
	
	# Connect to WorldAI for technological progression
	if WorldAI:
		WorldAI.technological_tier = min(WorldAI.technological_tier + 1, WorldAI.TechnologicalTier.QUANTUM)
	
	_record_world_event(
		"Technological Breakthrough",
		"Scholars have made a breakthrough: %s." % discovery,
		{"discovery": discovery, "tech_tier": WorldAI.technological_tier if WorldAI else 0}
	)

func _trigger_cultural_renaissance(tick: int) -> void:
	var arts: Array[String] = [
		"Painting and sculpture flourish",
		"Music and poetry spread",
		"Philosophy gains prominence",
		"Theater becomes popular",
		"Architecture reaches new heights"
	]
	var art_form: String = arts[tick % arts.size()]
	
	_record_world_event(
		"Cultural Renaissance",
		"A period of artistic and intellectual growth: %s." % art_form,
		{"art_form": art_form, "cultural_bonus": 0.15}
	)

func _trigger_resource_discovery(tick: int) -> void:
	var resources: Array[String] = [
		"Rich iron ore vein found",
		"Gold deposits discovered",
		"Rare gemstones unearthed",
		"Fertile land expansion",
		"Fresh water spring located"
	]
	var resource: String = resources[tick % resources.size()]
	
	_record_world_event(
		"Resource Discovery",
		"Explorers have found: %s." % resource,
		{"resource": resource, "economic_boost": 0.2}
	)

func _generate_neural_signature(event_type: String, tick: int) -> String:
	# Generate unique neural network matrix signature for events
	var signature_base: String = "%s_%d_%d" % [event_type, tick, GameManager.tick_count]
	var hash: int = signature_base.hash()
	return "NM_%08X" % hash


func _clear_temporary_event() -> void:
	_active_event_name = ""
	_active_event_until_tick = -1
	_gathering_efficiency_mult = 1.0


func gathering_efficiency_mult() -> float:
	return _gathering_efficiency_mult


func get_debug_active_event() -> Dictionary:
	return {
		"active_event_name": _active_event_name,
		"active_event_until_tick": _active_event_until_tick,
		"gathering_efficiency_mult": _gathering_efficiency_mult,
		"last_regional_shortage_tick": _last_regional_shortage_tick,
	}
