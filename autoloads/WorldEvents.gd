extends Node

## Suppresses only the four deterministic roll outcomes (Trade Caravan, Harvest Moon, Locust Swarm, Diplomatic Envoy). Debug build only; use with SettlementMemory.VALIDATION_SESSION_ENABLED or alone.
const VALIDATION_CLEAN_ECONOMY_EVENTS: bool = false

const EVENT_ROLL_INTERVAL: int = 1000
const HARVEST_MOON_DURATION_TICKS: int = 200
const HARVEST_MOON_MULT: float = 1.25
const LOCUST_FOOD_DRAIN: int = 2

var _active_event_name: String = ""
var _active_event_until_tick: int = -1
var _gathering_efficiency_mult: float = 1.0
var _validation_first_event_roll_proof_logged: bool = false


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
	WorldMemory.record_event(rec)
	print("[WorldEvent] Day %d: %s - %s" % [_current_day(), event_name, description])


func _trigger_trade_caravan(_tick: int) -> void:
	var added_wood: int = 4
	var added_stone: int = 3
	var added_berry: int = 6
	var zones: Array[Stockpile] = StockpileManager.zones()
	if not zones.is_empty():
		var z: Stockpile = zones[0]
		z.add_item(Item.Type.WOOD, added_wood)
		z.add_item(Item.Type.STONE, added_stone)
		z.add_item(Item.Type.BERRY, added_berry)
	_record_world_event(
		"Trade Caravan",
		"A neutral caravan delivered supplies to the colony stockpiles.",
		{"wood": added_wood, "stone": added_stone, "berry": added_berry}
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
