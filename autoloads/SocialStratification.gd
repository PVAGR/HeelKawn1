extends Node
## SocialStratification — per-settlement class hierarchy tracking with mobility.
##
## Tracks six class tiers per settlement (OUTCAST through RULER). Processes
## class distribution every STRATIFICATION_INTERVAL ticks. Pawns move between
## tiers based on wealth, skill accumulation, profession, and marriage.
## Provides inequality scores, class tension metrics, and happiness modifiers.
## Integrates with WorldMemory for event recording, EventBus for cross-system
## signals, and WorldRNG for all deterministic randomness.

const STRATIFICATION_INTERVAL: int = 3000
const CACHE_TTL_TICKS: int = 600
const MOBILITY_HISTORY_MAX: int = 50
const MIN_POPULATION_FOR_CLASSES: int = 1
const COLLAPSE_TENSION_THRESHOLD: float = 0.85
const COLLAPSE_RECOVERY_TICKS: int = 15000
const TENSION_DECAY_PER_TICK: float = 0.00005
const DEFAULT_INEQUALITY_WEIGHT: float = 0.4
const DEFAULT_TENSION_WEIGHT: float = 0.3

enum ClassTier {
	OUTCAST = 0,
	LABORER = 1,
	ARTISAN = 2,
	MERCHANT = 3,
	NOBLE = 4,
	RULER = 5,
}

const TIER_NAMES: Dictionary = {
	ClassTier.OUTCAST: "Outcast",
	ClassTier.LABORER: "Laborer",
	ClassTier.ARTISAN: "Artisan",
	ClassTier.MERCHANT: "Merchant",
	ClassTier.NOBLE: "Noble",
	ClassTier.RULER: "Ruler",
}

const TIER_COUNT: int = 6

## Wealth thresholds per tier index. Pawn must meet or exceed to qualify.
const DEFAULT_WEALTH_THRESHOLDS: Array[float] = [
	-100.0,   # OUTCAST: any
	0.0,      # LABORER: baseline
	30.0,     # ARTISAN
	80.0,     # MERCHANT
	200.0,    # NOBLE
	500.0,    # RULER
]

## Skill-score thresholds per tier.
const DEFAULT_SKILL_THRESHOLDS: Array[float] = [
	0.0,   # OUTCAST
	5.0,   # LABORER
	20.0,  # ARTISAN
	40.0,  # MERCHANT
	70.0,  # NOBLE
	100.0, # RULER
]

## Signals emitted when a pawn moves up a tier.
signal mobility_upgraded(pawn_id: int, settlement_center: int, from_tier: int, to_tier: int, reason: String)
## Signals emitted when a pawn moves down a tier.
signal mobility_downgraded(pawn_id: int, settlement_center: int, from_tier: int, to_tier: int, reason: String)
## Signals when class tension meaningfully changes for a settlement.
signal class_tension_changed(settlement_center: int, old_tension: float, new_tension: float, inequality: float)

@onready var _WorldRNG := get_node_or_null("/root/WorldRNG")
@onready var _WorldMemory := get_node_or_null("/root/WorldMemory")
@onready var _EventBus := get_node_or_null("/root/EventBus")
@onready var _SettlementMemory := get_node_or_null("/root/SettlementMemory")
@onready var _PawnManager := get_node_or_null("/root/PawnManager")

## Per-settlement class data: center_region -> Dictionary
var _settlement_classes: Dictionary = {}
var _last_update_tick: int = -999999

## Cache for social profiles: center_region -> { data, cached_at_tick }
var _profile_cache: Dictionary = {}
var _last_cache_invalidation_tick: int = -999999

## Mobility history archive: center_region -> Array of mobility events
var _mobility_history: Dictionary = {}

## Map of pawn_id -> last_assigned_tier { tier, tick } to detect changes
var _pawn_tier_snapshot: Dictionary = {}

func _ready() -> void:
	if GameManager != null:
		GameManager.game_tick.connect(_on_game_tick)
		var gm := GameManager as Node
		if gm.has_signal("game_tick"):
			pass
	if _EventBus != null:
		if _EventBus.has_method("subscribe"):
			_EventBus.subscribe(EventBus.EVENT_PAWN_DIED, self, "_on_pawn_died")
			_EventBus.subscribe(EventBus.EVENT_SETTLEMENT_FOUNDED, self, "_on_settlement_founded")
		var erp := EventBus as Node
		if erp.has_signal("war_declared"):
			if not erp.event_emitted.is_connected(_on_eventbus_war):
				erp.event_emitted.connect(_on_eventbus_war)

func _exit_tree() -> void:
	if GameManager != null and GameManager.game_tick.is_connected(_on_game_tick):
		GameManager.game_tick.disconnect(_on_game_tick)
	if _EventBus != null:
		if _EventBus.has_method("unsubscribe"):
			_EventBus.unsubscribe(EventBus.EVENT_PAWN_DIED, self, "_on_pawn_died")
			_EventBus.unsubscribe(EventBus.EVENT_SETTLEMENT_FOUNDED, self, "_on_settlement_founded")
		var erp := _EventBus as Node
		if erp != null and erp.event_emitted.is_connected(_on_eventbus_war):
			erp.event_emitted.disconnect(_on_eventbus_war)

func _on_eventbus_war(event_name: String, _payload: Dictionary) -> void:
	if event_name != "war_declared":
		return
	## War disrupts class structure: increase tension across affected settlements
	if _SettlementMemory == null or not _SettlementMemory.has_method("get_settlements"):
		return
	if GameManager == null:
		return
	var tick: int = GameManager.tick_count
	var settlements_updated: int = 0
	for center in _settlement_classes.keys():
		var sc: Dictionary = _settlement_classes.get(center, {})
		if sc.is_empty():
			continue
		var old_tension: float = sc.get("tension", 0.0)
		var new_tension: float = clampf(old_tension + 0.15, 0.0, 1.0)
		sc["tension"] = new_tension
		sc["last_tension_update"] = tick
		_settlement_classes[center] = sc
		_settlement_classes[center]["tension_war_spike_tick"] = tick
		class_tension_changed.emit(center, old_tension, new_tension, sc.get("inequality", 0.0))
		settlements_updated += 1
	_invalidate_cache_for_center(-1)
	if OS.is_debug_build() and settlements_updated > 0:
		print("[SocialStratification] War tension spike applied to %d settlements" % settlements_updated)

func _on_pawn_died(payload: Dictionary) -> void:
	var pawn_id: int = int(payload.get("pawn_id", -1))
	var settlement_id: int = int(payload.get("settlement_id", -1))
	if pawn_id < 0:
		return
	if settlement_id >= 0 and _settlement_classes.has(settlement_id):
		var sc: Dictionary = _settlement_classes[settlement_id]
		var tier_snapshot: Dictionary = _pawn_tier_snapshot.get(pawn_id, {})
		var tier: int = int(tier_snapshot.get("tier", -1))
		if tier >= 0 and tier < TIER_COUNT:
			var counts: Dictionary = sc.get("tier_counts", {})
			counts[tier] = maxi(0, counts.get(tier, 0) - 1)
			sc["tier_counts"] = counts
			_settlement_classes[settlement_id] = sc
		var tick: int = GameManager.tick_count if GameManager != null else 0
		_recalculate_inequality_and_tension(settlement_id, sc, tick)
		_invalidate_cache_for_center(settlement_id)
	_pawn_tier_snapshot.erase(pawn_id)

func _on_settlement_founded(payload: Dictionary) -> void:
	var center: int = int(payload.get("center_region", -1))
	if center < 0:
		center = int(payload.get("settlement_id", -1))
	if center < 0:
		return
	if _settlement_classes.has(center):
		return
	var pop: int = int(payload.get("population", 0))
	if pop <= 0:
		pop = 1
	var sc: Dictionary = _initialize_settlement_data(center, pop)
	_settlement_classes[center] = sc
	if _WorldMemory != null and _WorldMemory.has_method("record_event"):
		var tick: int = GameManager.tick_count if GameManager != null else 0
		_WorldMemory.record_event({
			"type": "social_stratification_initialized",
			"settlement_center": center,
			"population": pop,
			"tick": tick,
		})

func _on_game_tick(tick: int) -> void:
	if tick - _last_update_tick < STRATIFICATION_INTERVAL:
		return
	_last_update_tick = tick
	if _SettlementMemory == null or not _SettlementMemory.has_method("get_settlements"):
		_settlement_memory_fallback(tick)
		return
	var sm_settlements: Array = _SettlementMemory.settlements
	if sm_settlements.is_empty():
		_settlement_memory_fallback(tick)
		return
	for st_v in sm_settlements:
		if not (st_v is Dictionary):
			continue
		var st: Dictionary = st_v as Dictionary
		var center: int = int(st.get("center_region", -1))
		if center < 0:
			continue
		_update_settlement_classes(st, center, tick)
	if tick - _last_cache_invalidation_tick >= CACHE_TTL_TICKS:
		_flush_expired_cache(tick)

func _settlement_memory_fallback(tick: int) -> void:
	## Process already-known settlements if SettlementMemory is unavailable
	if _settlement_classes.is_empty():
		return
	for center in _settlement_classes.keys():
		var sc: Dictionary = _settlement_classes.get(center, {})
		if sc.is_empty():
			continue
		var pop: int = sc.get("population", 0)
		if pop <= 0:
			continue
		_update_settlement_classes_internal(center, sc, tick)

func _initialize_settlement_data(center: int, pop: int) -> Dictionary:
	var tick: int = GameManager.tick_count if GameManager != null else 0
	return {
		"tier_counts": {
			ClassTier.OUTCAST: maxi(0, pop / 10),
			ClassTier.LABORER: maxi(1, pop * 2 / 5),
			ClassTier.ARTISAN: maxi(0, pop / 5),
			ClassTier.MERCHANT: maxi(0, pop / 8),
			ClassTier.NOBLE: maxi(0, pop / 20),
			ClassTier.RULER: 1 if pop >= 10 else 0,
		},
		"population": pop,
		"wealth_thresholds": DEFAULT_WEALTH_THRESHOLDS.duplicate(),
		"skill_thresholds": DEFAULT_SKILL_THRESHOLDS.duplicate(),
		"mobility_thresholds": {
			"wealth_factor": 1.0,
			"skill_factor": 1.0,
			"crime_factor": 1.0,
		},
		"tension": 0.15,
		"inequality": 0.3,
		"happiness_modifier": 0.0,
		"last_update_tick": tick,
		"last_tension_update": tick,
		"total_mobility_up": 0,
		"total_mobility_down": 0,
		"last_collapse_tick": -1,
		"tension_war_spike_tick": -1,
		"economy_type": "agrarian",
		"governance_type": "anarchy",
	}

func _reconcile_tier_counts(sc: Dictionary, pop: int) -> void:
	var counts: Dictionary = sc.get("tier_counts", {})
	var total: int = 0
	for t in TIER_COUNT:
		total += counts.get(t, 0)
	if total == pop:
		return
	if total <= 0 and pop > 0:
		counts[ClassTier.LABORER] = pop
		sc["tier_counts"] = counts
		return
	var diff: int = pop - total
	if diff > 0:
		counts[ClassTier.LABORER] = counts.get(ClassTier.LABORER, 0) + diff
	elif diff < 0:
		var to_remove: int = -diff
		for t in [ClassTier.RULER, ClassTier.NOBLE, ClassTier.MERCHANT, ClassTier.ARTISAN, ClassTier.LABORER, ClassTier.OUTCAST]:
			if to_remove <= 0:
				break
			var available: int = counts.get(t, 0) - (1 if t == ClassTier.RULER else 0)
			if available <= 0:
				continue
			var remove_now: int = mini(to_remove, available)
			counts[t] = maxi(0, counts.get(t, 0) - remove_now)
			to_remove -= remove_now
	sc["tier_counts"] = counts

func _update_settlement_classes(st: Dictionary, center: int, tick: int) -> void:
	var pop: int = int(st.get("population", 0))
	if pop <= 0:
		return
	var econ: String = _settlement_economy(st)
	var gov: String = str(st.get("governance_type", "anarchy"))
	if not _settlement_classes.has(center):
		_settlement_classes[center] = _initialize_settlement_data(center, pop)
	var sc: Dictionary = _settlement_classes[center]
	sc["economy_type"] = econ
	sc["governance_type"] = gov
	sc["population"] = pop
	sc["last_update_tick"] = tick
	_settlement_classes[center] = sc
	_update_settlement_classes_internal(center, sc, tick)

func _update_settlement_classes_internal(center: int, sc: Dictionary, tick: int) -> void:
	var pop: int = sc.get("population", 0)
	if pop <= 0:
		return
	_adjust_thresholds_by_economy(sc)
	_adjust_thresholds_by_governance(sc, pop)
	var pawn_tiers: Dictionary = _assign_pawns_to_tiers(center, sc, pop, tick)
	var counts: Dictionary = sc.get("tier_counts", {})
	var old_counts: Dictionary = counts.duplicate()
	counts = pawn_tiers.get("tier_counts", counts)
	sc["tier_counts"] = counts
	_reconcile_tier_counts(sc, pop)
	var mobility_events: Array = pawn_tiers.get("mobility_events", [])
	_process_mobility_events(center, sc, mobility_events, tick)
	var old_tension: float = sc.get("tension", 0.0)
	_recalculate_inequality_and_tension(center, sc, tick)
	var new_tension: float = sc.get("tension", 0.0)
	if absf(new_tension - old_tension) > 0.02:
		class_tension_changed.emit(center, old_tension, new_tension, sc.get("inequality", 0.0))
	sc["happiness_modifier"] = _compute_happiness_modifier(sc)
	_settlement_classes[center] = sc
	_invalidate_cache_for_center(center)

func _adjust_thresholds_by_economy(sc: Dictionary) -> void:
	var econ: String = sc.get("economy_type", "agrarian")
	var wealth_thresh: Array = sc.get("wealth_thresholds", DEFAULT_WEALTH_THRESHOLDS.duplicate())
	var skill_thresh: Array = sc.get("skill_thresholds", DEFAULT_SKILL_THRESHOLDS.duplicate())
	match econ:
		"agrarian":
			wealth_thresh[ClassTier.MERCHANT] = 60.0
			wealth_thresh[ClassTier.NOBLE] = 150.0
			skill_thresh[ClassTier.ARTISAN] = 15.0
		"industrial":
			wealth_thresh[ClassTier.MERCHANT] = 100.0
			wealth_thresh[ClassTier.NOBLE] = 300.0
			wealth_thresh[ClassTier.RULER] = 600.0
			skill_thresh[ClassTier.ARTISAN] = 30.0
			skill_thresh[ClassTier.MERCHANT] = 50.0
		"martial":
			wealth_thresh[ClassTier.NOBLE] = 120.0
			skill_thresh[ClassTier.NOBLE] = 80.0
			skill_thresh[ClassTier.RULER] = 120.0
		"trade":
			wealth_thresh[ClassTier.MERCHANT] = 50.0
			wealth_thresh[ClassTier.NOBLE] = 180.0
			skill_thresh[ClassTier.MERCHANT] = 30.0
		"theocratic":
			skill_thresh[ClassTier.ARTISAN] = 25.0
			skill_thresh[ClassTier.NOBLE] = 60.0
			wealth_thresh[ClassTier.NOBLE] = 100.0
	sc["wealth_thresholds"] = wealth_thresh
	sc["skill_thresholds"] = skill_thresh

func _adjust_thresholds_by_governance(sc: Dictionary, pop: int) -> void:
	var gov: String = sc.get("governance_type", "anarchy")
	var counts: Dictionary = sc.get("tier_counts", {})
	match gov:
		"monarchy":
			counts[ClassTier.RULER] = clampi(counts.get(ClassTier.RULER, 0) + 0, 1, maxi(1, pop / 15))
			counts[ClassTier.NOBLE] = maxi(1, pop / 12)
		"council":
			counts[ClassTier.RULER] = 0
			counts[ClassTier.NOBLE] = maxi(2, pop / 8)
		"anarchy":
			counts[ClassTier.RULER] = 0
			counts[ClassTier.NOBLE] = 0
			counts[ClassTier.OUTCAST] = maxi(1, pop / 15)
		"republic":
			counts[ClassTier.RULER] = clampi(counts.get(ClassTier.RULER, 0), 1, maxi(1, pop / 25))
			counts[ClassTier.NOBLE] = maxi(1, pop / 15)
		"tribal":
			counts[ClassTier.RULER] = clampi(counts.get(ClassTier.RULER, 0), 1, maxi(1, pop / 10))
			counts[ClassTier.NOBLE] = 0
			counts[ClassTier.MERCHANT] = 0
	sc["tier_counts"] = counts

func _assign_pawns_to_tiers(center: int, sc: Dictionary, pop: int, tick: int) -> Dictionary:
	var counts: Dictionary = sc.get("tier_counts", {})
	var wealth_thresh: Array = sc.get("wealth_thresholds", DEFAULT_WEALTH_THRESHOLDS.duplicate())
	var skill_thresh: Array = sc.get("skill_thresholds", DEFAULT_SKILL_THRESHOLDS.duplicate())
	var mobility_events: Array = []
	if pop <= MIN_POPULATION_FOR_CLASSES:
		var single_counts: Dictionary = {}
		for t in TIER_COUNT:
			single_counts[t] = 0
		single_counts[ClassTier.LABORER] = pop
		return { "tier_counts": single_counts, "mobility_events": mobility_events }
	if _PawnManager == null or not _PawnManager.has_method("get_all_pawns"):
		return { "tier_counts": _default_distribution(pop), "mobility_events": mobility_events }
	var pawns: Array = _PawnManager.get_all_pawns()
	if pawns.is_empty():
		return { "tier_counts": _default_distribution(pop), "mobility_events": mobility_events }
	var pawn_data_list: Array = []
	for pv in pawns:
		var pdata: Dictionary = _extract_pawn_data(pv, center)
		if pdata.is_empty():
			continue
		pawn_data_list.append(pdata)
	if pawn_data_list.is_empty():
		return { "tier_counts": _default_distribution(pop), "mobility_events": mobility_events }
	var new_counts: Dictionary = {}
	var new_tier_of_pawn: Dictionary = {}
	for t in TIER_COUNT:
		new_counts[t] = 0
	for pd in pawn_data_list:
		var pid: int = int(pd.get("id", -1))
		var wealth: float = pd.get("wealth", 0.0)
		var skill: float = pd.get("skill_level", 0.0)
		var crime: float = pd.get("crime_severity", 0.0)
		var profession: String = pd.get("profession", "laborer")
		var married: bool = pd.get("is_married", false)
		var assigned_tier: int = _compute_pawn_tier(wealth, skill, crime, profession, married, wealth_thresh, skill_thresh)
		new_counts[assigned_tier] = new_counts.get(assigned_tier, 0) + 1
		new_tier_of_pawn[pid] = assigned_tier
		var old_snap: Dictionary = _pawn_tier_snapshot.get(pid, {})
		var old_tier: int = int(old_snap.get("tier", -1))
		if old_tier >= 0 and old_tier != assigned_tier:
			mobility_events.append({
				"pawn_id": pid,
				"from_tier": old_tier,
				"to_tier": assigned_tier,
				"wealth": wealth,
				"skill": skill,
				"reason": _determine_mobility_reason(old_tier, assigned_tier, wealth, skill, crime, married),
			})
		_pawn_tier_snapshot[pid] = { "tier": assigned_tier, "tick": tick, "center": center }
	return { "tier_counts": new_counts, "mobility_events": mobility_events }

func _default_distribution(pop: int) -> Dictionary:
	var out: Dictionary = {}
	for t in TIER_COUNT:
		out[t] = 0
	if pop <= 0:
		return out
	out[ClassTier.OUTCAST] = maxi(0, pop / 12)
	out[ClassTier.LABORER] = maxi(1, pop * 2 / 5)
	out[ClassTier.ARTISAN] = maxi(0, pop / 5)
	out[ClassTier.MERCHANT] = maxi(0, pop / 8)
	out[ClassTier.NOBLE] = maxi(0, pop / 20)
	out[ClassTier.RULER] = 1 if pop >= 8 else 0
	var total: int = 0
	for v in out.values():
		total += v
	if total < pop:
		out[ClassTier.LABORER] = out.get(ClassTier.LABORER, 0) + (pop - total)
	elif total > pop:
		out[ClassTier.OUTCAST] = maxi(0, out.get(ClassTier.OUTCAST, 0) - (total - pop))
	return out

func _extract_pawn_data(pawn_variant: Variant, center: int) -> Dictionary:
	if pawn_variant == null:
		return {}
	if pawn_variant is Dictionary:
		var pd: Dictionary = pawn_variant as Dictionary
		var pawn_center: int = int(pd.get("settlement_id", -1))
		if pawn_center >= 0 and pawn_center != center:
			return {}
		return {
			"id": int(pd.get("id", -1)),
			"wealth": float(pd.get("wealth", 0.0)),
			"skill_level": float(pd.get("skill_level", pd.get("skills", 0.0))),
			"crime_severity": float(pd.get("crime_severity", 0.0)),
			"profession": str(pd.get("profession", "laborer")),
			"is_married": bool(pd.get("is_married", false)),
		}
	if pawn_variant is Object:
		var po: Object = pawn_variant as Object
		if not po.has_method("get_data") and not po.has_method("get"):
			return {}
		var pd2: Dictionary = {}
		if po.has_method("get_data"):
			pd2 = po.get_data()
		elif po.has_method("get"):
			var keys: Array = ["id", "wealth", "skill_level", "skills", "crime_severity", "profession", "is_married"]
			for k in keys:
				pd2[k] = po.get(k, null)
		var pawn_center2: int = int(pd2.get("settlement_id", -1))
		if pawn_center2 >= 0 and pawn_center2 != center:
			return {}
		return {
			"id": int(pd2.get("id", -1)),
			"wealth": float(pd2.get("wealth", 0.0)),
			"skill_level": float(maxf(pd2.get("skill_level", 0.0), pd2.get("skills", 0.0))),
			"crime_severity": float(pd2.get("crime_severity", 0.0)),
			"profession": str(pd2.get("profession", "laborer")),
			"is_married": bool(pd2.get("is_married", false)),
		}
	return {}

func _compute_pawn_tier(wealth: float, skill: float, crime: float, profession: String, married: bool, wealth_thresh: Array, skill_thresh: Array) -> int:
	var base_tier: int = ClassTier.LABORER
	for tier in range(TIER_COUNT - 1, -1, -1):
		var w_th: float = wealth_thresh[tier] if tier < wealth_thresh.size() else DEFAULT_WEALTH_THRESHOLDS[tier]
		var s_th: float = skill_thresh[tier] if tier < skill_thresh.size() else DEFAULT_SKILL_THRESHOLDS[tier]
		if wealth >= w_th and skill >= s_th:
			base_tier = tier
			break
	if crime > 8.0:
		base_tier = maxi(ClassTier.OUTCAST, base_tier - 2)
	elif crime > 4.0:
		base_tier = maxi(ClassTier.OUTCAST, base_tier - 1)
	match profession:
		"ruler", "monarch":
			base_tier = maxi(base_tier, ClassTier.RULER)
		"noble", "lord", "knight":
			base_tier = maxi(base_tier, ClassTier.NOBLE)
		"merchant", "trader":
			base_tier = maxi(base_tier, ClassTier.MERCHANT)
		"artisan", "crafter", "blacksmith":
			base_tier = maxi(base_tier, ClassTier.ARTISAN)
		"outcast", "criminal", "bandit":
			base_tier = mini(base_tier, ClassTier.OUTCAST)
		"laborer", "farmer", "miner":
			base_tier = maxi(base_tier, ClassTier.LABORER)
	if married and base_tier < ClassTier.ARTISAN:
		var sp_bonus: int = 1
		if crime <= 2.0:
			sp_bonus = 2
		base_tier = mini(ClassTier.MERCHANT, base_tier + sp_bonus)
	return clampi(base_tier, ClassTier.OUTCAST, ClassTier.RULER)

func _determine_mobility_reason(old_tier: int, new_tier: int, wealth: float, skill: float, crime: float, married: bool) -> String:
	if new_tier > old_tier:
		if wealth > DEFAULT_WEALTH_THRESHOLDS[new_tier] * 1.5:
			return "wealth_accumulation"
		if skill > DEFAULT_SKILL_THRESHOLDS[new_tier] * 1.5:
			return "skill_mastery"
		if married:
			return "marriage_alliance"
		return "general_advancement"
	if new_tier < old_tier:
		if crime > 5.0:
			return "criminal_activity"
		if wealth < DEFAULT_WEALTH_THRESHOLDS[old_tier] * 0.3:
			return "poverty_decline"
		return "general_decline"
	return "stable"

func _process_mobility_events(center: int, sc: Dictionary, events: Array, tick: int) -> void:
	if events.is_empty():
		return
	if not _mobility_history.has(center):
		_mobility_history[center] = []
	var up_count: int = 0
	var down_count: int = 0
	for evt in events:
		var pawn_id: int = int(evt.get("pawn_id", -1))
		var from_tier: int = int(evt.get("from_tier", -1))
		var to_tier: int = int(evt.get("to_tier", -1))
		var reason: String = str(evt.get("reason", "unknown"))
		if from_tier < 0 or to_tier < 0:
			continue
		var record: Dictionary = {
			"pawn_id": pawn_id,
			"from_tier": from_tier,
			"to_tier": to_tier,
			"tick": tick,
			"reason": reason,
		}
		_mobility_history[center].append(record)
		if _mobility_history[center].size() > MOBILITY_HISTORY_MAX:
			_mobility_history[center].pop_front()
		if to_tier > from_tier:
			up_count += 1
			sc["total_mobility_up"] = sc.get("total_mobility_up", 0) + 1
			mobility_upgraded.emit(pawn_id, center, from_tier, to_tier, reason)
			_record_world_event("class_ascension", pawn_id, center, from_tier, to_tier, tick, reason)
		elif to_tier < from_tier:
			down_count += 1
			sc["total_mobility_down"] = sc.get("total_mobility_down", 0) + 1
			mobility_downgraded.emit(pawn_id, center, from_tier, to_tier, reason)
			_record_world_event("class_decline", pawn_id, center, from_tier, to_tier, tick, reason)
	if events.size() > maxi(1, sc.get("population", 1)) / 3:
		_record_world_event("social_restructuring", -1, center, -1, -1, tick,
				"mass mobility: %d up, %d down" % [up_count, down_count])

func _recalculate_inequality_and_tension(center: int, sc: Dictionary, tick: int) -> void:
	var counts: Dictionary = sc.get("tier_counts", {})
	var pop: int = sc.get("population", 0)
	if pop <= 0:
		sc["inequality"] = 0.0
		sc["tension"] = 0.0
		sc["last_tension_update"] = tick
		return
	var total_weighted: float = 0.0
	var max_weighted: float = 0.0
	for tier in range(TIER_COUNT):
		var count: int = counts.get(tier, 0)
		if count <= 0:
			continue
		var tier_weight: float = float(tier) / float(TIER_COUNT - 1)
		total_weighted += tier_weight * count
		max_weighted += 1.0 * count
	var mean_weight: float = total_weighted / float(pop) if pop > 0 else 0.0
	var gini_numerator: float = 0.0
	var gini_denominator: float = 0.0
	for tier_a in range(TIER_COUNT):
		var count_a: int = counts.get(tier_a, 0)
		if count_a <= 0:
			continue
		var wa: float = float(tier_a) / float(TIER_COUNT - 1)
		for tier_b in range(TIER_COUNT):
			var count_b: int = counts.get(tier_b, 0)
			if count_b <= 0:
				continue
			var wb: float = float(tier_b) / float(TIER_COUNT - 1)
			gini_numerator += float(count_a) * float(count_b) * absf(wa - wb)
			gini_denominator += float(count_a) * float(count_b)
	var gini: float = gini_numerator / gini_denominator if gini_denominator > 0.0 else 0.0
	var upper_concentration: float = 0.0
	var upper_total: int = counts.get(ClassTier.NOBLE, 0) + counts.get(ClassTier.RULER, 0)
	if pop > 0:
		upper_concentration = float(upper_total) / float(pop)
	sc["inequality"] = clampf(gini * 0.6 + upper_concentration * 0.4, 0.0, 1.0)
	var old_tension: float = sc.get("tension", 0.0)
	var inequality: float = sc.get("inequality", 0.0)
	var base_tension: float = inequality * DEFAULT_TENSION_WEIGHT + (1.0 - mean_weight) * DEFAULT_INEQUALITY_WEIGHT
	var war_spike_tick: int = sc.get("tension_war_spike_tick", -1)
	var war_decay: float = 0.0
	if war_spike_tick > 0:
		var ticks_since_war: int = tick - war_spike_tick
		war_decay = clampf(float(ticks_since_war) / 5000.0, 0.0, 1.0)
	var war_remaining: float = 0.15 * (1.0 - war_decay)
	base_tension += war_remaining
	var last_collapse: int = sc.get("last_collapse_tick", -1)
	if last_collapse > 0:
		var recovery_progress: float = clampf(float(tick - last_collapse) / float(COLLAPSE_RECOVERY_TICKS), 0.0, 1.0)
		base_tension *= 1.0 + (0.4 * (1.0 - recovery_progress))
	sc["tension"] = clampf(base_tension, 0.0, 1.0)
	sc["last_tension_update"] = tick
	if sc["tension"] >= COLLAPSE_TENSION_THRESHOLD:
		_handle_class_structure_collapse(center, sc, tick)

func _handle_class_structure_collapse(center: int, sc: Dictionary, tick: int) -> void:
	sc["last_collapse_tick"] = tick
	var pop: int = sc.get("population", 0)
	if pop <= 0:
		return
	var flattened_dist: Dictionary = _default_distribution(pop)
	flattened_dist[ClassTier.OUTCAST] = maxi(1, pop / 4)
	flattened_dist[ClassTier.RULER] = 0
	var total_f: int = 0
	for v in flattened_dist.values():
		total_f += v
	if total_f < pop:
		flattened_dist[ClassTier.OUTCAST] = flattened_dist.get(ClassTier.OUTCAST, 0) + (pop - total_f)
	elif total_f > pop:
		flattened_dist[ClassTier.LABORER] = maxi(1, flattened_dist.get(ClassTier.LABORER, 0) - (total_f - pop))
	sc["tier_counts"] = flattened_dist
	sc["tension"] = 0.5
	sc["last_tension_update"] = tick
	_settlement_classes[center] = sc
	_record_world_event("social_restructuring", -1, center, -1, -1, tick, "class structure collapse after crisis")
	if OS.is_debug_build():
		print("[SocialStratification] Class collapse at settlement %d, pop %d" % [center, pop])

func _compute_happiness_modifier(sc: Dictionary) -> float:
	var inequality: float = sc.get("inequality", 0.0)
	var tension: float = sc.get("tension", 0.0)
	var pop: int = sc.get("population", 0)
	if pop <= 0:
		return 0.0
	var ineq_penalty: float = -inequality * 0.4
	var tension_penalty: float = -tension * 0.3
	var mobility_up: int = sc.get("total_mobility_up", 0)
	var mobility_down: int = sc.get("total_mobility_down", 0)
	var mobility_net: int = mobility_up - mobility_down
	var total_mobility: int = mobility_up + mobility_down
	var mobility_bonus: float = 0.0
	if total_mobility > 0:
		mobility_bonus = clampf(float(mobility_net) / float(total_mobility) * 0.1, -0.1, 0.1)
	return clampf(ineq_penalty + tension_penalty + mobility_bonus, -1.0, 1.0)

func _record_world_event(event_type: String, pawn_id: int, center: int, from_tier: int, to_tier: int, tick: int, detail: String) -> void:
	if _WorldMemory == null or not _WorldMemory.has_method("record_event"):
		return
	var event: Dictionary = {
		"type": "social_" + event_type,
		"pawn_id": pawn_id,
		"settlement_center": center,
		"from_tier": TIER_NAMES.get(from_tier, "Unknown"),
		"to_tier": TIER_NAMES.get(to_tier, "Unknown"),
		"tick": tick,
		"detail": detail,
	}
	_WorldMemory.record_event(event)

func _settlement_economy(st: Dictionary) -> String:
	var trad: Variant = st.get("tradition", {})
	if trad is Dictionary:
		var td: Dictionary = trad as Dictionary
		var pref: Variant = td.get("preferred_tech_branch", "agrarian")
		if pref is String:
			return pref as String
		if pref is int:
			match int(pref):
				0: return "agrarian"
				1: return "industrial"
				2: return "martial"
				3: return "trade"
				4: return "theocratic"
		return "agrarian"
	if trad is String:
		return trad as String
	return "agrarian"

## Cache management

func _invalidate_cache_for_center(center: int) -> void:
	if center < 0:
		_profile_cache.clear()
		_last_cache_invalidation_tick = GameManager.tick_count if GameManager != null else 0
		return
	_profile_cache.erase(center)

func _flush_expired_cache(tick: int) -> void:
	var expired_centers: Array = []
	for center in _profile_cache.keys():
		var cached: Dictionary = _profile_cache.get(center, {})
		var cached_tick: int = cached.get("cached_at_tick", -999999)
		if tick - cached_tick >= CACHE_TTL_TICKS * 2:
			expired_centers.append(center)
	for c in expired_centers:
		_profile_cache.erase(c)
	_last_cache_invalidation_tick = tick

func _get_or_build_profile(center: int) -> Dictionary:
	var cached: Dictionary = _profile_cache.get(center, {})
	if not cached.is_empty():
		var cache_tick: int = cached.get("cached_at_tick", -999999)
		var game_tick: int = GameManager.tick_count if GameManager != null else 0
		if game_tick - cache_tick < CACHE_TTL_TICKS:
			return cached.get("data", {}).duplicate(true)
	var sc: Dictionary = _settlement_classes.get(center, {})
	if sc.is_empty():
		return {}
	if _WorldRNG != null:
		var cheat: bool = _WorldRNG.chance_for(StringName("social_profile_cache_miss_%d" % center), 0.01, center)
		if cheat:
			pass
	var profile: Dictionary = _build_social_profile(center, sc)
	var game_tick2: int = GameManager.tick_count if GameManager != null else 0
	_profile_cache[center] = {
		"data": profile.duplicate(true),
		"cached_at_tick": game_tick2,
	}
	return profile

func _build_social_profile(center: int, sc: Dictionary) -> Dictionary:
	var counts: Dictionary = sc.get("tier_counts", {})
	var tier_pcts: Dictionary = {}
	var pop: int = sc.get("population", 0)
	for tier in range(TIER_COUNT):
		var cnt: int = counts.get(tier, 0)
		if pop > 0:
			tier_pcts[TIER_NAMES.get(tier, "Unknown")] = float(cnt) / float(pop)
		else:
			tier_pcts[TIER_NAMES.get(tier, "Unknown")] = 0.0
	return {
		"center": center,
		"population": pop,
		"tier_counts": counts.duplicate(),
		"tier_percentages": tier_pcts,
		"inequality": sc.get("inequality", 0.0),
		"tension": sc.get("tension", 0.0),
		"happiness_modifier": sc.get("happiness_modifier", 0.0),
		"governance_type": sc.get("governance_type", "anarchy"),
		"economy_type": sc.get("economy_type", "agrarian"),
		"total_mobility_up": sc.get("total_mobility_up", 0),
		"total_mobility_down": sc.get("total_mobility_down", 0),
		"last_collapse_tick": sc.get("last_collapse_tick", -1),
	}

## Public API

func get_tier(pawn_id: int, settlement_center: int) -> int:
	var sc: Dictionary = _settlement_classes.get(settlement_center, {})
	if sc.is_empty():
		return ClassTier.LABORER
	var snap: Dictionary = _pawn_tier_snapshot.get(pawn_id, {})
	var tier: int = int(snap.get("tier", -1))
	var snap_center: int = int(snap.get("center", -1))
	if tier >= 0 and snap_center == settlement_center:
		return tier
	var counts: Dictionary = sc.get("tier_counts", {})
	var total: int = 0
	for v in counts.values():
		total += v
	if total <= 0:
		return ClassTier.LABORER
	var hash_pos: int = absi(pawn_id * 7919 + settlement_center * 104729) % total
	var cumulative: int = 0
	for tier_i in [ClassTier.RULER, ClassTier.NOBLE, ClassTier.MERCHANT, ClassTier.ARTISAN, ClassTier.LABORER, ClassTier.OUTCAST]:
		cumulative += counts.get(tier_i, 0)
		if hash_pos < cumulative:
			return tier_i
	return ClassTier.LABORER

func attempt_mobility(pawn_id: int, center: int, wealth: float, fame: float, crime: float) -> int:
	var sc: Dictionary = _settlement_classes.get(center, {})
	if sc.is_empty():
		return ClassTier.LABORER
	var thresh: Dictionary = sc.get("mobility_thresholds", {
		"wealth_factor": 1.0, "skill_factor": 1.0, "crime_factor": 1.0,
	})
	var wf: float = float(thresh.get("wealth_factor", 1.0))
	var sf: float = float(thresh.get("skill_factor", 1.0))
	var cf: float = float(thresh.get("crime_factor", 1.0))
	var current_tier: int = get_tier(pawn_id, center)
	var tick: int = GameManager.tick_count if GameManager != null else 0
	if wealth * wf >= 120.0 and current_tier < ClassTier.MERCHANT:
		var new_tier: int = current_tier + 1
		_apply_mobility(pawn_id, center, current_tier, new_tier, "wealth_promotion", tick)
		return new_tier
	if wealth * wf >= 300.0 and current_tier < ClassTier.NOBLE:
		var new_tier: int = current_tier + 1
		_apply_mobility(pawn_id, center, current_tier, new_tier, "wealth_peerage", tick)
		return new_tier
	if fame * sf >= 80.0 and current_tier < ClassTier.NOBLE:
		var new_tier: int = current_tier + 2
		_apply_mobility(pawn_id, center, current_tier, mini(ClassTier.RULER, new_tier), "fame_ascension", tick)
		return new_tier
	if crime * cf >= 10.0 and current_tier > ClassTier.OUTCAST:
		var new_tier: int = current_tier - 1
		_apply_mobility(pawn_id, center, current_tier, maxi(ClassTier.OUTCAST, new_tier), "crime_disgrace", tick)
		return new_tier
	if wealth * wf < 5.0 and current_tier > ClassTier.LABORER:
		var new_tier: int = current_tier - 1
		_apply_mobility(pawn_id, center, current_tier, maxi(ClassTier.OUTCAST, new_tier), "impoverishment", tick)
		return new_tier
	return current_tier

func _apply_mobility(pawn_id: int, center: int, from: int, to: int, reason: String, tick: int) -> void:
	if from == to:
		return
	var sc: Dictionary = _settlement_classes.get(center, {})
	if sc.is_empty():
		return
	var counts: Dictionary = sc.get("tier_counts", {})
	counts[from] = maxi(0, counts.get(from, 0) - 1)
	counts[to] = counts.get(to, 0) + 1
	sc["tier_counts"] = counts
	var old_tension: float = sc.get("tension", 0.0)
	_recalculate_inequality_and_tension(center, sc, tick)
	sc["happiness_modifier"] = _compute_happiness_modifier(sc)
	if to > from:
		sc["total_mobility_up"] = sc.get("total_mobility_up", 0) + 1
	elif to < from:
		sc["total_mobility_down"] = sc.get("total_mobility_down", 0) + 1
	_settlement_classes[center] = sc
	_pawn_tier_snapshot[pawn_id] = { "tier": to, "tick": tick, "center": center }
	if not _mobility_history.has(center):
		_mobility_history[center] = []
	_mobility_history[center].append({
		"pawn_id": pawn_id, "from_tier": from, "to_tier": to, "tick": tick, "reason": reason,
	})
	if _mobility_history[center].size() > MOBILITY_HISTORY_MAX:
		_mobility_history[center].pop_front()
	if to > from:
		mobility_upgraded.emit(pawn_id, center, from, to, reason)
		_record_world_event("class_ascension", pawn_id, center, from, to, tick, reason)
	else:
		mobility_downgraded.emit(pawn_id, center, from, to, reason)
		_record_world_event("class_decline", pawn_id, center, from, to, tick, reason)
	if absf(sc.get("tension", 0.0) - old_tension) > 0.02:
		class_tension_changed.emit(center, old_tension, sc.get("tension", 0.0), sc.get("inequality", 0.0))
	_invalidate_cache_for_center(center)

func get_class_stats(center: int) -> Dictionary:
	var sc: Dictionary = _settlement_classes.get(center, {})
	if sc.is_empty():
		return {
			"tier_counts": {},
			"mobility_thresholds": {},
			"inequality": 0.0,
			"tension": 0.0,
			"happiness_modifier": 0.0,
		}
	return {
		"tier_counts": sc.get("tier_counts", {}).duplicate(),
		"mobility_thresholds": sc.get("mobility_thresholds", {}).duplicate(),
		"inequality": sc.get("inequality", 0.0),
		"tension": sc.get("tension", 0.0),
		"happiness_modifier": sc.get("happiness_modifier", 0.0),
		"population": sc.get("population", 0),
		"total_mobility_up": sc.get("total_mobility_up", 0),
		"total_mobility_down": sc.get("total_mobility_down", 0),
		"last_update_tick": sc.get("last_update_tick", -1),
	}

## Debug methods

func get_settlement_social_profile(center: int) -> Dictionary:
	return _get_or_build_profile(center)

func get_class_tension(center: int) -> float:
	var sc: Dictionary = _settlement_classes.get(center, {})
	return sc.get("tension", 0.0)

func get_inequality_score(center: int) -> float:
	var sc: Dictionary = _settlement_classes.get(center, {})
	return sc.get("inequality", 0.0)

func get_mobility_history(center: int, max_records: int = 20) -> Array:
	var hist: Array = _mobility_history.get(center, [])
	if hist.is_empty():
		return []
	var result: Array = []
	var start: int = maxi(0, hist.size() - max_records)
	for i in range(start, hist.size()):
		result.append(hist[i].duplicate())
	return result

func get_settlement_happiness_modifier(center: int) -> float:
	var sc: Dictionary = _settlement_classes.get(center, {})
	if sc.is_empty():
		return 0.0
	return sc.get("happiness_modifier", 0.0)

func get_pawn_tier_snapshot(pawn_id: int) -> Dictionary:
	return _pawn_tier_snapshot.get(pawn_id, {}).duplicate()

func get_all_settlements_with_class_data() -> Array:
	var result: Array = []
	for center in _settlement_classes.keys():
		result.append({
			"center": center,
			"population": _settlement_classes[center].get("population", 0),
			"tension": _settlement_classes[center].get("tension", 0.0),
			"inequality": _settlement_classes[center].get("inequality", 0.0),
		})
	return result

func debug_print_class_summary() -> void:
	if not OS.is_debug_build():
		return
	print("\n=== SOCIAL STRATIFICATION SUMMARY ===")
	print("Settlements tracked: %d" % _settlement_classes.size())
	for center in _settlement_classes:
		var sc: Dictionary = _settlement_classes[center]
		var counts: Dictionary = sc.get("tier_counts", {})
		var line: String = "  Center %d (pop %d): " % [center, sc.get("population", 0)]
		for tier in range(TIER_COUNT):
			line += "%s=%d " % [TIER_NAMES.get(tier, "?")[0], counts.get(tier, 0)]
		line += "| T=%.2f I=%.2f H=%.2f" % [sc.get("tension", 0.0), sc.get("inequality", 0.0), sc.get("happiness_modifier", 0.0)]
		print(line)
	var total_pop: int = 0
	for sc2 in _settlement_classes.values():
		total_pop += sc2.get("population", 0)
	print("Total stratified population: %d" % total_pop)
	print("Cache entries: %d (TTL=%d)" % [_profile_cache.size(), CACHE_TTL_TICKS])
	print("=== END SUMMARY ===\n")

## Save / Load / Clear

func get_save_state() -> Dictionary:
	var save_data: Dictionary = {
		"settlement_classes": {},
		"last_update_tick": _last_update_tick,
		"mobility_history": {},
		"pawn_tier_snapshot": _pawn_tier_snapshot.duplicate(true),
	}
	for center in _settlement_classes:
		var sc: Dictionary = _settlement_classes[center]
		var save_sc: Dictionary = sc.duplicate(true)
		save_data["settlement_classes"][center] = save_sc
	for center in _mobility_history:
		var hist_copy: Array = []
		for evt in _mobility_history[center]:
			hist_copy.append(evt.duplicate(true))
		save_data["mobility_history"][center] = hist_copy
	return save_data

func load_state(state: Dictionary) -> void:
	clear()
	if state.is_empty():
		return
	if state.has("settlement_classes"):
		var raw_sc: Dictionary = state["settlement_classes"]
		for center_v in raw_sc.keys():
			var center: int = int(center_v)
			var sc_data: Variant = raw_sc[center_v]
			if sc_data is Dictionary:
				var sc: Dictionary = sc_data as Dictionary
				sc["tier_counts"] = _ensure_tier_counts(sc.get("tier_counts", {}))
				sc["wealth_thresholds"] = sc.get("wealth_thresholds", DEFAULT_WEALTH_THRESHOLDS.duplicate())
				sc["skill_thresholds"] = sc.get("skill_thresholds", DEFAULT_SKILL_THRESHOLDS.duplicate())
				sc["mobility_thresholds"] = sc.get("mobility_thresholds", {"wealth_factor": 1.0, "skill_factor": 1.0, "crime_factor": 1.0})
				sc["happiness_modifier"] = sc.get("happiness_modifier", 0.0)
				sc["last_collapse_tick"] = int(sc.get("last_collapse_tick", -1))
				_settlement_classes[center] = sc
		if state.has("last_update_tick"):
			_last_update_tick = int(state["last_update_tick"])
	if state.has("mobility_history"):
		var raw_mh: Dictionary = state["mobility_history"]
		for center_v2 in raw_mh.keys():
			var center2: int = int(center_v2)
			var hist_data: Variant = raw_mh[center_v2]
			if hist_data is Array:
				var hist_arr: Array = hist_data as Array
				var cleaned: Array = []
				for evt_v in hist_arr:
					if evt_v is Dictionary:
						cleaned.append((evt_v as Dictionary).duplicate(true))
				_mobility_history[center2] = cleaned
	if state.has("pawn_tier_snapshot"):
		var raw_pts: Dictionary = state["pawn_tier_snapshot"]
		for pid_v in raw_pts.keys():
			var pid: int = int(pid_v)
			var snap_data: Variant = raw_pts[pid_v]
			if snap_data is Dictionary:
				_pawn_tier_snapshot[pid] = (snap_data as Dictionary).duplicate(true)

func _ensure_tier_counts(counts: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for t in TIER_COUNT:
		out[t] = maxi(0, int(counts.get(t, 0)))
	return out

func clear() -> void:
	_settlement_classes.clear()
	_last_update_tick = -999999
	_profile_cache.clear()
	_last_cache_invalidation_tick = -999999
	_mobility_history.clear()
	_pawn_tier_snapshot.clear()
