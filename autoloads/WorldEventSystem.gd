extends Node
## Macro-layer simulation: economy pressure, aggregate mood, weather-linked modifiers,
## and slow-paced social/event pressures. Heavy work runs every [macro MACRO_INTERVAL_TICKS]
## simulation ticks (not every frame). Hooks [TickManager.tick_processed] when available.

const MACRO_INTERVAL_TICKS: int = 1000
const MACRO_PHASE_OFFSET: int = 0

## Targets — tuning knobs for normalized supply (food vs mouths).
const FOOD_PER_PAWN_COMFORT: float = 12.0

var macro_supply_index: float = 1.0
## >1 means expensive / scarce.
var macro_price_pressure: float = 1.0
## 0..100 aggregate psychic tone for the colony/world slice we observe.
var world_mood: float = 50.0
## 0=drought-like … 3=storm-like bands (discrete season bucket).
var weather_band: int = 0
var weather_resource_mult: float = 1.0
var weather_mood_delta: float = 0.0

var crime_event_pressure: float = 0.0
var festival_trade_pressure: float = 0.0
## Feeds AI urgency — NPCs "work harder" when economy tightens.
var labor_urgency_bonus: float = 0.0
var theft_pressure: float = 0.0

var _last_food_units: int = -1
var _initialized: bool = false


func _ready() -> void:
	call_deferred("_hook_ticks")


func _hook_ticks() -> void:
	var tm: Node = get_node_or_null("/root/TickManager")
	if tm != null and tm.has_signal("tick_processed"):
		if not tm.tick_processed.is_connected(_on_tick_manager_tick):
			tm.tick_processed.connect(_on_tick_manager_tick)
		_initialized = true
		return
	if GameManager != null and not GameManager.game_tick.is_connected(_on_game_tick_fallback):
		GameManager.game_tick.connect(_on_game_tick_fallback)
	_initialized = true


func _exit_tree() -> void:
	var tm: Node = get_node_or_null("/root/TickManager")
	if tm != null and tm.tick_processed.is_connected(_on_tick_manager_tick):
		tm.tick_processed.disconnect(_on_tick_manager_tick)
	if GameManager != null and GameManager.game_tick.is_connected(_on_game_tick_fallback):
		GameManager.game_tick.disconnect(_on_game_tick_fallback)


func _on_tick_manager_tick(tick: int) -> void:
	_tick_macro_if_due(tick)


func _on_game_tick_fallback(tick: int) -> void:
	_tick_macro_if_due(tick)


func _tick_macro_if_due(tick: int) -> void:
	if GameManager == null:
		return
	if not GameManager.periodic_phase_due(tick, MACRO_INTERVAL_TICKS, MACRO_PHASE_OFFSET):
		return
	_run_macro_step(tick)


func _pawn_count() -> int:
	return maxi(1, PawnSpawner.find_pawns().size())


func _run_macro_step(tick: int) -> void:
	var food_now: int = 0
	if StockpileManager != null:
		food_now = StockpileManager.total_food()
	var mouths: float = float(_pawn_count())
	var comfortable_food: float = mouths * FOOD_PER_PAWN_COMFORT
	macro_supply_index = clampf(float(food_now) / maxf(1.0, comfortable_food), 0.0, 3.0)

	if _last_food_units >= 0:
		var delta_f: int = food_now - _last_food_units
		if delta_f < 0:
			macro_price_pressure = clampf(macro_price_pressure + 0.04 * absf(float(delta_f)) / maxf(1.0, mouths), 0.75, 2.5)
		elif delta_f > 0:
			macro_price_pressure = clampf(macro_price_pressure - 0.02 * float(delta_f) / maxf(1.0, mouths), 0.75, 2.5)
	else:
		macro_price_pressure = lerpf(macro_price_pressure, 1.0 / maxf(0.25, macro_supply_index), 0.25)

	if macro_supply_index < 0.65:
		labor_urgency_bonus = clampf(labor_urgency_bonus + 0.08, 0.0, 1.0)
		theft_pressure = clampf(theft_pressure + 0.06, 0.0, 1.0)
	else:
		labor_urgency_bonus = clampf(labor_urgency_bonus - 0.04, 0.0, 1.0)
		theft_pressure = clampf(theft_pressure - 0.03, 0.0, 1.0)

	_refresh_world_mood_from_pawns()
	_apply_weather_and_season(tick)
	world_mood = clampf(world_mood + weather_mood_delta, 0.0, 100.0)

	if world_mood < 32.0:
		crime_event_pressure = clampf(crime_event_pressure + 0.12, 0.0, 1.0)
		festival_trade_pressure = clampf(festival_trade_pressure - 0.05, 0.0, 1.0)
		var riot_roll: float = WorldRNG.range_for(StringName("macro_crime:%d" % tick), 0.0, 1.0, 91)
		if riot_roll < crime_event_pressure * 0.35:
			GameManager.add_global_stress(3)
			if WorldMemory != null:
				WorldMemory.record_event({"type": "macro_unrest", "tick": tick, "severity": crime_event_pressure})
	elif world_mood > 72.0:
		festival_trade_pressure = clampf(festival_trade_pressure + 0.1, 0.0, 1.0)
		crime_event_pressure = clampf(crime_event_pressure - 0.06, 0.0, 1.0)
		var fest_roll: float = WorldRNG.range_for(StringName("macro_festival:%d" % tick), 0.0, 1.0, 17)
		if fest_roll < festival_trade_pressure * 0.25:
			if WorldMemory != null:
				WorldMemory.record_event({"type": "macro_festival", "tick": tick, "boost": festival_trade_pressure})

	_last_food_units = food_now


func _refresh_world_mood_from_pawns() -> void:
	var nodes: Array[Pawn] = PawnSpawner.find_pawns()
	if nodes.is_empty():
		return
	var sum: float = 0.0
	var n: int = 0
	for node in nodes:
		if not is_instance_valid(node):
			continue
		var pd: Variant = node.get("data")
		if pd != null and ("mood" in pd):
			sum += float(pd.mood)
			n += 1
	if n <= 0:
		return
	world_mood = clampf(sum / float(n), 0.0, 100.0)


func _apply_weather_and_season(tick: int) -> void:
	var day_idx: int = SimTime.calendar_absolute_visual_day(tick)
	weather_band = posmod(day_idx + int(SimTime.tick_within_sim_year(tick) / 3000), 4)
	match weather_band:
		0:
			weather_resource_mult = 1.08
			weather_mood_delta = 2.0
		1:
			weather_resource_mult = 1.0
			weather_mood_delta = 0.0
		2:
			weather_resource_mult = 0.94
			weather_mood_delta = -3.0
		_:
			weather_resource_mult = 0.88
			weather_mood_delta = -5.0
	if WorldEvents != null:
		weather_resource_mult *= WorldEvents.gathering_efficiency_mult()


func get_price_pressure() -> float:
	return macro_price_pressure


func get_world_mood() -> float:
	return world_mood


func get_weather_resource_mult() -> float:
	return weather_resource_mult


func get_labor_urgency_bonus() -> float:
	return labor_urgency_bonus


func get_theft_pressure() -> float:
	return theft_pressure


func get_supply_index() -> float:
	return macro_supply_index
