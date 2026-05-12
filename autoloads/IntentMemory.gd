extends Node
## v1: Derived, not saved — world-scale pressure and per-settlement intent (GROW / HOLD / ABANDON).
## Read-only: feeds future migration / conflict layers; no commands, no world writes.

## Intent / bias (stable ints for comparisons and debug).
const INTENT_GROW: int = 0
const INTENT_HOLD: int = 1
const INTENT_ABANDON: int = 2

## Session-only: last Age index we saw (for delta pressure).
var _age_index_last_seen: int = 0
var _ready_tick_guard: bool = false
## 0.0..1.0
var global_pressure: float = 0.0
## center_region (int) -> float 0..1
var settlement_pressure: Dictionary = {}
## center_region (int) -> INTENT_*
var settlement_intent: Dictionary = {}


func _ready() -> void:
	if not _ready_tick_guard:
		_ready_tick_guard = true
		GameManager.game_tick.connect(_on_game_tick)


func _on_game_tick(tick: int) -> void:
	if not OS.is_debug_build():
		return
	if (tick % 10_000) != 0 or tick <= 0:
		return
	_debug_intent_summary(tick)


func clear() -> void:
	_age_index_last_seen = 0
	global_pressure = 0.0
	settlement_pressure.clear()
	settlement_intent.clear()


func recompute(world: World) -> void:
	if world == null or not is_instance_valid(world) or world.data == null:
		return
	# Throttle to every 60 ticks to avoid lag
	if GameManager.tick_count % 60 != 0:
		return
	var now: int = GameManager.tick_count
	var pawns_alive: int = 0
	for n in PawnSpawner.find_pawns():
		if n.data != null:
			pawns_alive += 1
	var aidx: int = AgeMemory.get_current_age_index()
	var age_bump: float = 0.0
	if aidx > _age_index_last_seen:
		age_bump = mini(0.25, 0.08 * float(aidx - _age_index_last_seen))
		_age_index_last_seen = aidx
	var n_sett: int = 0
	var collapse_score: float = 0.0
	for s_any2 in SettlementMemory.get_formal_settlements():
		if not (s_any2 is Dictionary):
			continue
		var st: Dictionary = s_any2
		var st_name: String = str(st.get("state", ""))
		n_sett += 1
		if st_name == "dormant":
			collapse_score += 1.0
		elif st_name == "abandoned":
			collapse_score += 1.4
		elif st_name == "permanently_abandoned":
			collapse_score += 1.8
	var frac_da: float = 0.0
	if n_sett > 0:
		frac_da = collapse_score / (float(n_sett) * 1.8)
	var trade_collapse: float = 0.0
	if TradeMemory.count_t2_tiles() <= 0 and TradeMemory.get_last_tick_t2_existed() >= 0:
		var dt: int = now - int(TradeMemory.get_last_tick_t2_existed())
		if dt >= 1000:
			trade_collapse = mini(0.4, 0.00001 * float(dt))
	var food_total: int = 0
	food_total += StockpileManager.total_count_of(int(Item.Type.BERRY))
	food_total += StockpileManager.total_count_of(int(Item.Type.MEAT))
	food_total += StockpileManager.total_count_of(int(Item.Type.FISH))
	food_total += StockpileManager.total_count_of(int(Item.Type.COOKED_FISH))
	var need_food: float = float(1 + pawns_alive * 3)
	var food_p: float = 0.0
	if need_food > 0.0:
		food_p = mini(0.4, 1.0 - float(food_total) / need_food)
		if food_p < 0.0:
			food_p = 0.0
	global_pressure = age_bump + 0.5 * frac_da + 0.3 * trade_collapse + food_p
	global_pressure = clampf(global_pressure, 0.0, 1.0)
	# --- per settlement ---
	settlement_pressure.clear()
	settlement_intent.clear()
	var aspn: Node = null
	if world.has_meta("animal_spawner"):
		aspn = world.get_meta("animal_spawner", null) as Node
	for s_any in SettlementMemory.get_formal_settlements():
		if not (s_any is Dictionary):
			continue
		var sd: Dictionary = s_any
		var ck: int = int(sd.get("center_region", -1))
		if ck < 0:
			continue
		var pr: float = 0.0
		var st_now: String = str(sd.get("state", ""))
		if st_now == "dormant":
			pr += 0.04
		elif st_now == "abandoned":
			pr += 0.08
		elif st_now == "permanently_abandoned":
			pr += 0.16
		if TradeMemory.get_role(ck) == TradeMemory.ROLE_DEPENDENT:
			pr += 0.18
		var scmax: int = int(sd.get("scar_max", 0))
		if scmax >= 2:
			pr += 0.15
		if MythMemory.get_region_myth_state(ck) == 1:
			pr += 0.12
		var lat: int = int(sd.get("last_activity_tick", -1))
		if lat >= 0 and (now - lat) > 40000:
			pr += 0.1
		if st_now == "revivable" and MythMemory.get_rebirth_success_count_for_center(ck) < 1:
			pr += 0.05
		var p_sum: int = 0
		if aspn is AnimalSpawner:
			p_sum += AnimalSpawner._live_count_in_region(
					(aspn as AnimalSpawner).animals, world, ck, int(Animal.Type.RABBIT)
			)
			p_sum += AnimalSpawner._live_count_in_region(
					(aspn as AnimalSpawner).animals, world, ck, int(Animal.Type.DEER)
			)
		if p_sum < 2:
			pr += 0.12
		if pr > 0.0 and global_pressure > 0.0:
			pr = 0.7 * pr + 0.3 * global_pressure
		pr = clampf(pr, 0.0, 1.0)
		settlement_pressure[ck] = pr
		if pr < 0.33:
			settlement_intent[ck] = INTENT_GROW
		elif pr < 0.66:
			settlement_intent[ck] = INTENT_HOLD
		else:
			settlement_intent[ck] = INTENT_ABANDON


func _debug_intent_summary(now: int) -> void:
	if not OS.is_debug_build():
		return
	if (now % 10_000) != 0 or now <= 0:
		return
	var ng: int = 0
	var nh: int = 0
	var na: int = 0
	for _rk in settlement_intent.keys():
		var v2: int = int(settlement_intent[_rk])
		if v2 == INTENT_GROW:
			ng += 1
		elif v2 == INTENT_HOLD:
			nh += 1
		elif v2 == INTENT_ABANDON:
			na += 1
	if OS.is_debug_build():
		print(
				"[Intent] tick=%d global_pressure=%.3f  intent: GROW=%d HOLD=%d ABANDON=%d"
				% [now, global_pressure, ng, nh, na]
		)
