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
	_record_world_event(
		"Diplomatic Envoy",
		"A noble envoy arrived to discuss an alliance. (logic stub)",
		{"stub": true}
	)


func _clear_temporary_event() -> void:
	_active_event_name = ""
	_active_event_until_tick = -1
	_gathering_efficiency_mult = 1.0


func gathering_efficiency_mult() -> float:
	return _gathering_efficiency_mult
