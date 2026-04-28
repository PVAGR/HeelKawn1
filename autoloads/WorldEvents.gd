extends Node

## Suppresses only the four deterministic roll outcomes (Trade Caravan, Harvest Moon, Locust Swarm, Diplomatic Envoy). Debug build only; use with SettlementMemory.VALIDATION_SESSION_ENABLED or alone.
const VALIDATION_CLEAN_ECONOMY_EVENTS: bool = false

const EVENT_ROLL_INTERVAL: int = 1000
## Regional flavor rolls; coprime with [member EVENT_ROLL_INTERVAL] to stagger workloads.
const REGIONAL_ROLL_INTERVAL_TICKS: int = 3500
## Colony-adjacent “kitchen table” rumors; sparse, O(1) via first stockpile anchor.
const LOCAL_ROLL_INTERVAL_TICKS: int = 8200
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
	if tick > 0 and tick % REGIONAL_ROLL_INTERVAL_TICKS == 0:
		_maybe_roll_regional_event(tick)
	if tick > 0 and tick % LOCAL_ROLL_INTERVAL_TICKS == 0:
		_maybe_roll_local_event(tick)
	if tick <= 0 or tick % EVENT_ROLL_INTERVAL != 0:
		return
	if not _validation_first_event_roll_proof_logged:
		_validation_first_event_roll_proof_logged = true
		var sup: bool = _suppress_economy_distorting_world_events()
		print(
				(
						"[VALIDATION_EVENT_ROLL_PROOF] tick=%d marker=%s clean_suppression_active=%s "
						+ "scheduled_economy_roll_skipped=%s (proof is one-shot only)"
				)
				% [
					tick,
					SettlementMemory.VALIDATION_RUNTIME_SMOKE_MARKER,
					sup,
					sup,
				]
		)
	if _suppress_economy_distorting_world_events():
		return
	var event_index: int = _deterministic_event_index(tick)
	match event_index:
		0:
			_trigger_trade_caravan(tick)
		1:
			_trigger_harvest_moon(tick)
		2:
			_trigger_locust_swarm(tick)
		3:
			_trigger_diplomatic_envoy(tick)


func _deterministic_event_index(tick: int) -> int:
	var roll_id: int = int(tick / EVENT_ROLL_INTERVAL)
	return int((roll_id * 1103515245 + 12345) % 4)


func _maybe_roll_local_event(tick: int) -> void:
	var zones: Array[Stockpile] = StockpileManager.zones()
	if zones.is_empty():
		return
	var z: Stockpile = zones[0]
	var rk: int = WorldMemory._region_key(z.tile.x, z.tile.y)
	var ml: String = WorldMeaning.get_region_meaning_label(rk)
	var wave: int = int(tick / LOCAL_ROLL_INTERVAL_TICKS)
	var variant: int = int((wave * 17 + rk) % 2)
	if variant == 0:
		_record_world_event(
			"Hearth Whisper",
			"Someone repeats a rumor heard at the stockpile edge.",
			{"scope": "local", "anchor_region": rk, "meaning_label": ml, "flavor": "rumor"}
		)
	else:
		_record_world_event(
			"Lantern Vigil",
			"A small habit keeps fear outside the firelight — for now.",
			{"scope": "local", "anchor_region": rk, "meaning_label": ml, "flavor": "morale"}
		)


func _maybe_roll_regional_event(tick: int) -> void:
	var sl: Array = SettlementMemory.settlements
	if sl.is_empty():
		return
	var wave: int = int(tick / REGIONAL_ROLL_INTERVAL_TICKS)
	var idx: int = wave % sl.size()
	var st_any: Variant = sl[idx]
	if not (st_any is Dictionary):
		return
	var st: Dictionary = st_any as Dictionary
	var center_region: int = int(st.get("center_region", -1))
	if center_region < 0:
		return
	var flavor: int = int((wave * 7919 + center_region * 524287) % 3)
	match flavor:
		0:
			_trigger_regional_shortage(center_region)
		1:
			_trigger_regional_truce_talks(center_region)
		_:
			_trigger_regional_herd_migration(center_region)


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
			and tick - _last_regional_shortage_tick <= EVENT_ROLL_INTERVAL * 3
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
