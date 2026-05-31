extends Node
## FactionPolitics — internal political factions within settlements.
##
## Tracks competing power blocs: royalists, merchants, military, clergy, commoners.
## Factions gain/lose influence (0–100) based on events, governance type, and
## settlement conditions. Can trigger coups, coalitions, and policy shifts.
## All randomness flows through WorldRNG.stream_seed for determinism.

# ── Interval ──────────────────────────────────────────────────────────
const POLITICS_INTERVAL: int = 3000

# ── Influence bounds & tuning ─────────────────────────────────────────
const MIN_INFLUENCE: float = 0.0
const MAX_INFLUENCE: float = 100.0
const INFLUENCE_DECAY_TOWARD: float = 10.0
const INFLUENCE_DECAY_RATE: float = 0.8
const COUP_TRIGGER_THRESHOLD: float = 90.0
const COUP_DOMINANT_FLOOR: float = 20.0
const COUP_COOLDOWN_TICKS: int = 15000
const COALITION_FORM_THRESHOLD: float = 50.0
const COALITION_MIN_MEMBER_INF: float = 15.0
const COALITION_MAX_MEMBERS: int = 3
const COLLAPSE_INFLUENCE_FLOOR: float = 0.5
const MAX_HISTORICAL_SNAPSHOTS: int = 200
const FOREIGN_INFLUENCE_RADIUS: float = 0.15

# ── Faction types ─────────────────────────────────────────────────────
enum FactionType {
	ROYALISTS,    # Pro-monarchy, traditional authority
	MERCHANTS,    # Trade and wealth-based power
	MILITARY,     # Martial law and defense focus
	CLERGY,       # Religious authority
	COMMONERS,    # Popular/democratic movement
}

const FACTION_NAMES: Dictionary = {
	FactionType.ROYALISTS: "Royalists",
	FactionType.MERCHANTS: "Merchants",
	FactionType.MILITARY: "Military",
	FactionType.CLERGY: "Clergy",
	FactionType.COMMONERS: "Commoners",
}

# ── Agenda templates per faction ──────────────────────────────────────
const AGENDA_TEMPLATES: Dictionary = {
	FactionType.ROYALISTS: [
		{"name": "Strengthen monarchy", "building_prefs": ["keep", "palace", "throne_room"], "diplomatic_stance": "aggressive", "tax_policy": "high"},
		{"name": "Suppress rebellion", "building_prefs": ["barracks", "wall", "garrison"], "diplomatic_stance": "repressive", "tax_policy": "moderate"},
		{"name": "Expand territory", "building_prefs": ["fort", "outpost", "road"], "diplomatic_stance": "expansionist", "tax_policy": "moderate"},
		{"name": "Raise taxes", "building_prefs": ["treasury", "courthouse"], "diplomatic_stance": "neutral", "tax_policy": "high"},
		{"name": "Royal decree", "building_prefs": ["monument", "statue"], "diplomatic_stance": "neutral", "tax_policy": "moderate"},
	],
	FactionType.MERCHANTS: [
		{"name": "Open trade routes", "building_prefs": ["market", "warehouse", "dock"], "diplomatic_stance": "open", "tax_policy": "low"},
		{"name": "Reduce tariffs", "building_prefs": ["exchange", "bank"], "diplomatic_stance": "open", "tax_policy": "low"},
		{"name": "Build market", "building_prefs": ["market", "inn", "shop"], "diplomatic_stance": "neutral", "tax_policy": "low"},
		{"name": "Standardize currency", "building_prefs": ["mint", "exchange"], "diplomatic_stance": "neutral", "tax_policy": "moderate"},
		{"name": "Expand guild", "building_prefs": ["guild_hall", "workshop"], "diplomatic_stance": "protectionist", "tax_policy": "moderate"},
	],
	FactionType.MILITARY: [
		{"name": "Fortify borders", "building_prefs": ["wall", "gate", "watchtower"], "diplomatic_stance": "defensive", "tax_policy": "high"},
		{"name": "Increase army", "building_prefs": ["barracks", "training_yard", "armory"], "diplomatic_stance": "aggressive", "tax_policy": "high"},
		{"name": "Declare war", "building_prefs": ["war_room", "supply_depot"], "diplomatic_stance": "aggressive", "tax_policy": "high"},
		{"name": "Build barracks", "building_prefs": ["barracks", "mess_hall", "drill_field"], "diplomatic_stance": "defensive", "tax_policy": "moderate"},
		{"name": "Martial law", "building_prefs": ["garrison", "checkpoint"], "diplomatic_stance": "repressive", "tax_policy": "moderate"},
	],
	FactionType.CLERGY: [
		{"name": "Build shrine", "building_prefs": ["shrine", "altar", "temple"], "diplomatic_stance": "neutral", "tax_policy": "moderate"},
		{"name": "Convert heretics", "building_prefs": ["temple", "pulpit", "scriptorium"], "diplomatic_stance": "zealous", "tax_policy": "moderate"},
		{"name": "Holy festival", "building_prefs": ["square", "shrine"], "diplomatic_stance": "open", "tax_policy": "low"},
		{"name": "Religious law", "building_prefs": ["temple", "courthouse"], "diplomatic_stance": "zealous", "tax_policy": "moderate"},
		{"name": "Pilgrimage route", "building_prefs": ["road", "inn", "shrine"], "diplomatic_stance": "open", "tax_policy": "low"},
	],
	FactionType.COMMONERS: [
		{"name": "Reduce taxes", "building_prefs": ["town_hall", "granary"], "diplomatic_stance": "neutral", "tax_policy": "low"},
		{"name": "Land reform", "building_prefs": ["farm", "pasture"], "diplomatic_stance": "neutral", "tax_policy": "moderate"},
		{"name": "Free speech", "building_prefs": ["square", "tavern"], "diplomatic_stance": "open", "tax_policy": "low"},
		{"name": "Elect council", "building_prefs": ["town_hall", "assembly"], "diplomatic_stance": "open", "tax_policy": "moderate"},
		{"name": "Public works", "building_prefs": ["well", "road", "bath"], "diplomatic_stance": "neutral", "tax_policy": "moderate"},
	],
}

# ── Job-type preferences per faction ──────────────────────────────────
const FACTION_JOB_PREFERENCES: Dictionary = {
	FactionType.ROYALISTS: ["administrator", "noble", "judge", "steward", "herald"],
	FactionType.MERCHANTS: ["trader", "merchant", "shopkeeper", "banker", "innkeeper"],
	FactionType.MILITARY: ["warrior", "soldier", "guard", "captain", "scout"],
	FactionType.CLERGY: ["priest", "monk", "healer", "scribe", "acolyte"],
	FactionType.COMMONERS: ["farmer", "builder", "gatherer", "crafter", "labourer"],
}

# ── Governance-to-faction drift table ─────────────────────────────────
const GOVERNANCE_DRIFT: Dictionary = {
	"monarchy": {FactionType.ROYALISTS: 3.0, FactionType.MILITARY: 1.5, FactionType.COMMONERS: -1.5, FactionType.CLERGY: 1.0},
	"council": {FactionType.MERCHANTS: 2.5, FactionType.COMMONERS: 2.0, FactionType.ROYALISTS: -1.5, FactionType.CLERGY: 0.5},
	"anarchy": {FactionType.MILITARY: 3.5, FactionType.CLERGY: 1.5, FactionType.MERCHANTS: -1.5, FactionType.ROYALISTS: -2.0},
	"theocracy": {FactionType.CLERGY: 4.0, FactionType.ROYALISTS: 1.0, FactionType.COMMONERS: -1.0, FactionType.MERCHANTS: -1.0},
}

# ── Signals ───────────────────────────────────────────────────────────
signal faction_influence_changed(center: int, faction: int, old_value: float, new_value: float, tick: int)
signal dominant_faction_changed(center: int, old_faction: int, new_faction: int, tick: int)
signal coup_attempted(center: int, faction: int, success: bool, tick: int)
signal coup_completed(center: int, new_dominant_faction: int, old_dominant_faction: int, tick: int)
signal coalition_formed(center: int, factions: Array, shared_agenda: String, tick: int)
signal coalition_broken(center: int, tick: int)
signal faction_collapsed(center: int, faction: int, tick: int)

# ── State ─────────────────────────────────────────────────────────────
var _settlement_factions: Dictionary = {}  # center -> {faction_id -> {influence, members, agenda, ...}}
var _settlement_meta: Dictionary = {}       # center -> {dominant, last_coup_tick, ...}
var _pawn_loyalties: Dictionary = {}        # pawn_id -> {faction -> affinity 0..100}
var _historical_power: Dictionary = {}      # center -> [{tick, faction_id, influence}]
var _coalitions: Dictionary = {}            # center -> [{member_factions:[], formed_tick, shared_agenda:{}, member_ids:[]}]
var _event_driven_boosts: Dictionary = {}   # center -> {faction_id -> pending_boost}
var _coup_cooldowns: Dictionary = {}        # center -> tick of last coup attempt
var _last_politics_tick: int = -999999
var _foreign_influence_pending: Dictionary = {}  # target_center -> {faction_id -> pending_amount}

# ── Lifecycle ─────────────────────────────────────────────────────────
func _ready() -> void:
	var gm := get_node_or_null("/root/GameManager")
	if gm != null and gm.has_signal("game_tick"):
		gm.game_tick.connect(_on_game_tick)

	var eb := get_node_or_null("/root/EventBus")
	if eb != null and eb.has_method("subscribe"):
		eb.subscribe(EventBus.EVENT_SETTLEMENT_FOUNDED, self, "_on_settlement_founded")
		eb.subscribe(EventBus.EVENT_PAWN_DIED, self, "_on_pawn_died")
		eb.subscribe(EventBus.EVENT_SETTLEMENT_ATTACKED, self, "_on_settlement_attacked")
		eb.subscribe(EventBus.EVENT_COMBAT_STARTED, self, "_on_combat_started")
		eb.subscribe(EventBus.EVENT_COMBAT_ENDED, self, "_on_combat_ended")
		eb.subscribe(EventBus.EVENT_TRADE_ROUTE_ESTABLISHED, self, "_on_trade_route_established")
		eb.subscribe(EventBus.EVENT_PRESSURE_EVENT, self, "_on_pressure_event")
		eb.subscribe("building_constructed", self, "_on_building_constructed")
		eb.subscribe("war_declared", self, "_on_war_declared")

# ── Tick processing ───────────────────────────────────────────────────
func _on_game_tick(tick: int) -> void:
	if tick - _last_politics_tick < POLITICS_INTERVAL:
		return
	_last_politics_tick = tick

	var sm := get_node_or_null("/root/SettlementMemory")
	if sm == null or not sm.has_method("get") and not ("settlements" in sm):
		return

	var settlements: Array = sm.settlements if "settlements" in sm else []
	for st_v in settlements:
		if not (st_v is Dictionary):
			continue
		var st: Dictionary = st_v as Dictionary
		var center: int = int(st.get("center_region", -1))
		if center < 0:
			continue
		_process_settlement(st, center, tick)

func _process_settlement(st: Dictionary, center: int, tick: int) -> void:
	_ensure_factions(center, st)

	_apply_influence_decay(center, tick)
	_apply_event_boosts(center, tick)
	_apply_foreign_influence(center, tick)
	_apply_governance_drift(center, st, tick)

	var factions: Dictionary = _settlement_factions[center]
	var pop: int = maxi(1, int(st.get("population", 1)))
	var any_collapsed: bool = false

	for fid in FactionType.values():
		if not factions.has(fid):
			continue
		var f: Dictionary = factions[fid]
		f["influence"] = clampf(f["influence"], MIN_INFLUENCE, MAX_INFLUENCE)
		if fid == _get_dominant_faction(center):
			f["members"] = maxi(1, int(pop * (f["influence"] / 100.0) * 0.35))
		else:
			f["members"] = maxi(1, int(pop * (f["influence"] / 100.0) * 0.25))
		if f["influence"] < COLLAPSE_INFLUENCE_FLOOR:
			_collapse_faction(center, fid, tick)
			any_collapsed = true

	if any_collapsed:
		_redistribute_collapsed_influence(center, tick)

	var old_dominant: int = _get_meta(center, "dominant_faction", -1)
	var new_dominant: int = _get_dominant_faction(center)
	if new_dominant != old_dominant:
		_dominant_faction_changed(center, old_dominant, new_dominant, tick)

	if new_dominant >= 0:
		_update_agenda(center, new_dominant, tick)

	_check_coalitions(center, tick)
	_check_coup(center, tick)

	if tick % (POLITICS_INTERVAL * 10) == 0:
		_record_historical_snapshot(center, tick)

# ── Faction initialization ────────────────────────────────────────────
func _ensure_factions(center: int, st: Dictionary) -> void:
	if _settlement_factions.has(center):
		return
	var raw_inits: Array = FactionType.values()
	var rng_base: int = center * 7919
	var factions: Dictionary = {}
	var total_inf: float = 0.0

	for ft in raw_inits:
		var offset: float = float(absi(rng_base * (int(ft) + 1)) % 35)
		var inf: float = 10.0 + offset
		factions[ft] = {
			"influence": inf,
			"members": 0,
			"agenda": _pick_agenda(ft, center),
			"coup_attempts": 0,
			"total_boosts": 0.0,
			"total_penalties": 0.0,
			"peak_influence": inf,
			"ticks_dominant": 0,
		}
		total_inf += inf

	if total_inf > MAX_INFLUENCE:
		var scale: float = MAX_INFLUENCE / total_inf
		for ft in factions:
			factions[ft]["influence"] *= scale

	_settlement_factions[center] = factions
	_settlement_meta[center] = {
		"dominant_faction": _get_dominant_faction_from(factions),
		"last_coup_tick": -1,
		"last_coalition_tick": -1,
		"coalition_active": false,
		"coalition_members": [],
	}

func _pick_agenda(faction: int, center: int) -> Dictionary:
	var templates: Array = AGENDA_TEMPLATES.get(faction, [])
	if templates.is_empty():
		return {"name": "Status quo", "building_prefs": [], "diplomatic_stance": "neutral", "tax_policy": "moderate"}
	var idx: int = absi(center * 31337 + faction * 7919) % templates.size()
	return (templates[idx] as Dictionary).duplicate()

# ── Core influence operations ─────────────────────────────────────────
func _adjust_influence(center: int, faction: int, delta: float, tick: int = -1) -> void:
	var factions: Dictionary = _settlement_factions.get(center, {})
	if not factions.has(faction):
		return
	var f: Dictionary = factions[faction]
	var old: float = f["influence"]
	f["influence"] = clampf(f["influence"] + delta, MIN_INFLUENCE, MAX_INFLUENCE)
	if f["influence"] > f["peak_influence"]:
		f["peak_influence"] = f["influence"]
	if delta < 0.0:
		f["total_penalties"] += absf(delta)
	else:
		f["total_boosts"] += delta
	var current_tick: int = tick if tick >= 0 else Engine.get_meta("current_tick", 0)
	if absf(f["influence"] - old) > 0.5:
		faction_influence_changed.emit(center, faction, old, f["influence"], current_tick)

func _apply_influence_decay(center: int, tick: int) -> void:
	var factions: Dictionary = _settlement_factions.get(center, {})
	if factions.is_empty():
		return
	for fid in factions.keys():
		var f: Dictionary = factions[fid]
		if f["influence"] <= INFLUENCE_DECAY_TOWARD:
			continue
		var excess: float = f["influence"] - INFLUENCE_DECAY_TOWARD
		var decay: float = excess * (INFLUENCE_DECAY_RATE / 100.0)
		if decay > 0.01:
			_adjust_influence(center, fid, -decay, tick)

func _apply_event_boosts(center: int, tick: int) -> void:
	var boosts: Dictionary = _event_driven_boosts.get(center, {})
	if boosts.is_empty():
		return
	var factions: Dictionary = _settlement_factions.get(center, {})
	for fid in boosts.keys():
		if not factions.has(fid):
			continue
		var boost: float = boosts[fid]
		_adjust_influence(center, fid, boost, tick)
	_event_driven_boosts[center] = {}

func _apply_foreign_influence(center: int, tick: int) -> void:
	var pending: Dictionary = _foreign_influence_pending.get(center, {})
	if pending.is_empty():
		return
	for fid in pending.keys():
		var amt: float = pending[fid]
		_adjust_influence(center, fid, amt, tick)
	_foreign_influence_pending[center] = {}

func _apply_governance_drift(center: int, st: Dictionary, tick: int) -> void:
	var gov: String = str(st.get("governance_type", "anarchy"))
	var drift: Dictionary = GOVERNANCE_DRIFT.get(gov, {})
	for fid in drift.keys():
		var amount: float = drift[fid]
		_adjust_influence(center, fid, amount, tick)

# ── Dominant faction ──────────────────────────────────────────────────
func _get_dominant_faction(center: int) -> int:
	return _get_dominant_faction_from(_settlement_factions.get(center, {}))

static func _get_dominant_faction_from(factions: Dictionary) -> int:
	var best_fid: int = -1
	var best_inf: float = -1.0
	for fid in factions.keys():
		if not (fid is int):
			continue
		var inf: float = factions[fid].get("influence", 0.0)
		if inf > best_inf:
			best_inf = inf
			best_fid = fid
	return best_fid

func _get_meta(center: int, key: String, default = null):
	var m: Dictionary = _settlement_meta.get(center, {})
	return m.get(key, default)

func _set_meta(center: int, key: String, value) -> void:
	if not _settlement_meta.has(center):
		_settlement_meta[center] = {}
	_settlement_meta[center][key] = value

func _dominant_faction_changed(center: int, old_fid: int, new_fid: int, tick: int) -> void:
	_set_meta(center, "dominant_faction", new_fid)
	dominant_faction_changed.emit(center, old_fid, new_fid, tick)

	var wm := get_node_or_null("/root/WorldMemory")
	if wm == null or not wm.has_method("record_event"):
		return
	if new_fid >= 0:
		wm.record_event({
			"type": "faction_rise",
			"settlement_center": center,
			"faction": FACTION_NAMES.get(new_fid, "Unknown"),
			"faction_id": new_fid,
			"tick": tick,
		})
	if old_fid >= 0:
		wm.record_event({
			"type": "faction_fall",
			"settlement_center": center,
			"faction": FACTION_NAMES.get(old_fid, "Unknown"),
			"faction_id": old_fid,
			"tick": tick,
		})

func _update_agenda(center: int, dominant_fid: int, tick: int) -> void:
	var factions: Dictionary = _settlement_factions.get(center, {})
	var dom: Dictionary = factions.get(dominant_fid, {})
	var old_agenda: String = str(dom.get("agenda", {}).get("name", ""))
	var new_agenda: Dictionary = _pick_agenda(dominant_fid, center + tick)
	var rng_salt: int = center * 31337 + tick
	var wm := get_node_or_null("/root/WorldMemory")
	if rng_salt % 7 == 0:
		new_agenda = AGENDA_TEMPLATES[dominant_fid][(int(rng_salt / 7)) % AGENDA_TEMPLATES[dominant_fid].size()].duplicate()
	dom["agenda"] = new_agenda
	if str(new_agenda.get("name", "")) != old_agenda and not old_agenda.is_empty():
		if wm != null and wm.has_method("record_event"):
			wm.record_event({
				"type": "agenda_changed",
				"settlement_center": center,
				"faction": FACTION_NAMES.get(dominant_fid, "Unknown"),
				"old_agenda": old_agenda,
				"new_agenda": new_agenda.get("name", ""),
				"tick": tick,
			})

# ── Coalition system ──────────────────────────────────────────────────
func _check_coalitions(center: int, tick: int) -> void:
	var factions: Dictionary = _settlement_factions.get(center, {})
	var dominant: int = _get_dominant_faction(center)
	if dominant < 0:
		return
	var dom_inf: float = factions.get(dominant, {}).get("influence", 0.0)
	var currently_in_coalition: bool = _get_meta(center, "coalition_active", false)

	if dom_inf >= COALITION_FORM_THRESHOLD:
		if currently_in_coalition:
			_break_coalition(center, tick)
		return

	if currently_in_coalition:
		var members: Array = _get_meta(center, "coalition_members", [])
		var should_break: bool = false
		for mf in members:
			if not factions.has(mf) or factions[mf].get("influence", 0.0) < COALITION_MIN_MEMBER_INF:
				should_break = true
				break
		if not should_break:
			return
		_break_coalition(center, tick)

	var candidates: Array = []
	for fid in factions.keys():
		if not (fid is int):
			continue
		var inf: float = factions[fid].get("influence", 0.0)
		if fid == dominant:
			continue
		if inf >= COALITION_MIN_MEMBER_INF:
			candidates.append({"fid": fid, "inf": inf})
	candidates.sort_custom(func(a, b): return a["inf"] > b["inf"])
	if candidates.size() < 1:
		return
	var max_members: int = mini(COALITION_MAX_MEMBERS, candidates.size())
	var coalition_ids: Array = []
	for i in range(max_members):
		coalition_ids.append(candidates[i]["fid"])
	if coalition_ids.is_empty():
		return
	_form_coalition(center, coalition_ids, dominant, tick)

func _form_coalition(center: int, member_ids: Array, against_fid: int, tick: int) -> void:
	_set_meta(center, "coalition_active", true)
	_set_meta(center, "coalition_members", member_ids.duplicate())
	_set_meta(center, "last_coalition_tick", tick)

	var shared_agenda_name: String = "Oppose " + FACTION_NAMES.get(against_fid, "the ruling faction")
	var wm := get_node_or_null("/root/WorldMemory")
	if wm != null and wm.has_method("record_event"):
		wm.record_event({
			"type": "coalition_formed",
			"settlement_center": center,
			"members": member_ids.duplicate(),
			"member_names": member_ids.map(func(f): return FACTION_NAMES.get(f, "?")),
			"against_faction": FACTION_NAMES.get(against_fid, "?"),
			"tick": tick,
		})
	coalition_formed.emit(center, member_ids.duplicate(), shared_agenda_name, tick)

func _break_coalition(center: int, tick: int) -> void:
	_set_meta(center, "coalition_active", false)
	_set_meta(center, "coalition_members", [])

	var wm := get_node_or_null("/root/WorldMemory")
	if wm != null and wm.has_method("record_event"):
		wm.record_event({
			"type": "coalition_broken",
			"settlement_center": center,
			"tick": tick,
		})
	coalition_broken.emit(center, tick)

# ── Coup mechanics ────────────────────────────────────────────────────
func _check_coup(center: int, tick: int) -> void:
	if _coup_cooldowns.get(center, -1) > 0 and tick - _coup_cooldowns.get(center, -1) < COUP_COOLDOWN_TICKS:
		return

	var factions: Dictionary = _settlement_factions.get(center, {})
	var dominant_fid: int = _get_dominant_faction(center)
	if dominant_fid < 0:
		return
	var dom_inf: float = factions.get(dominant_fid, {}).get("influence", 0.0)
	if dom_inf > COUP_DOMINANT_FLOOR:
		return

	for fid in factions.keys():
		if not (fid is int) or fid == dominant_fid:
			continue
		var inf: float = factions[fid].get("influence", 0.0)
		if inf < COUP_TRIGGER_THRESHOLD:
			continue
		_execute_coup(center, fid, dominant_fid, tick)
		return

func _execute_coup(center: int, challenger_fid: int, target_fid: int, tick: int) -> void:
	_coup_cooldowns[center] = tick
	var factions: Dictionary = _settlement_factions[center]
	var f_challenger: Dictionary = factions[challenger_fid]
	f_challenger["coup_attempts"] = int(f_challenger.get("coup_attempts", 0)) + 1

	var military_inf: float = factions.get(FactionType.MILITARY, {}).get("influence", 0.0)
	var challenger_inf: float = f_challenger["influence"]
	var target_inf: float = factions.get(target_fid, {}).get("influence", 0.0)

	var success_chance: float = 0.3
	success_chance += challenger_inf / MAX_INFLUENCE * 0.3
	success_chance += military_inf / MAX_INFLUENCE * 0.2
	if challenger_fid == FactionType.MILITARY:
		success_chance += 0.15
	success_chance -= target_inf / MAX_INFLUENCE * 0.15
	success_chance -= (military_inf / MAX_INFLUENCE) * 0.1
	success_chance = clampf(success_chance, 0.05, 0.95)

	var rng_stream: StringName = StringName("coup:%d:%d" % [center, challenger_fid])
	var roll: float = WorldRNG.unit_for(rng_stream, tick) if WorldRNG != null else 0.5
	var success: bool = roll < success_chance

	coup_attempted.emit(center, challenger_fid, success, tick)
	if success:
		_resolve_coup(center, challenger_fid, target_fid, tick)
	else:
		_failed_coup(center, challenger_fid, target_fid, tick)

func _resolve_coup(center: int, challenger_fid: int, target_fid: int, tick: int) -> void:
	var factions: Dictionary = _settlement_factions[center]

	var old_inf: float = factions[target_fid]["influence"]
	factions[target_fid]["influence"] = maxf(MIN_INFLUENCE, old_inf * 0.15)
	factions[target_fid]["total_penalties"] += old_inf * 0.85

	var challenger_bonus: float = 15.0 + (old_inf * 0.1)
	factions[challenger_fid]["influence"] = clampf(factions[challenger_fid]["influence"] + challenger_bonus, MIN_INFLUENCE, MAX_INFLUENCE)

	for fid in FactionType.values():
		if not factions.has(fid) or fid == challenger_fid or fid == target_fid:
			continue
		var f: Dictionary = factions[fid]
		var collateral: float = f["influence"] * 0.05
		f["influence"] = clampf(f["influence"] - collateral, MIN_INFLUENCE, MAX_INFLUENCE)
		f["total_penalties"] += collateral

	var new_dominant: int = _get_dominant_faction(center)
	_set_meta(center, "dominant_faction", new_dominant)
	_set_meta(center, "last_coup_tick", tick)
	coup_completed.emit(center, new_dominant, target_fid, tick)

	var wm := get_node_or_null("/root/WorldMemory")
	if wm != null and wm.has_method("record_event"):
		wm.record_event({
			"type": "coup",
			"settlement_center": center,
			"challenger": FACTION_NAMES.get(challenger_fid, "Unknown"),
			"challenger_id": challenger_fid,
			"target": FACTION_NAMES.get(target_fid, "Unknown"),
			"target_id": target_fid,
			"success": true,
			"roll": 0.0,
			"chance": 0.0,
			"tick": tick,
		})

func _failed_coup(center: int, challenger_fid: int, target_fid: int, tick: int) -> void:
	var factions: Dictionary = _settlement_factions[center]

	var penalty: float = factions[challenger_fid]["influence"] * 0.25
	factions[challenger_fid]["influence"] = clampf(factions[challenger_fid]["influence"] - penalty, MIN_INFLUENCE, MAX_INFLUENCE)
	factions[challenger_fid]["total_penalties"] += penalty

	var backlash: float = 5.0 * (1.0 + (factions[target_fid]["influence"] / MAX_INFLUENCE))
	factions[target_fid]["influence"] = clampf(factions[target_fid]["influence"] + backlash, MIN_INFLUENCE, MAX_INFLUENCE)
	factions[target_fid]["total_boosts"] += backlash

	var wm := get_node_or_null("/root/WorldMemory")
	if wm != null and wm.has_method("record_event"):
		wm.record_event({
			"type": "coup",
			"settlement_center": center,
			"challenger": FACTION_NAMES.get(challenger_fid, "Unknown"),
			"challenger_id": challenger_fid,
			"target": FACTION_NAMES.get(target_fid, "Unknown"),
			"target_id": target_fid,
			"success": false,
			"roll": 0.0,
			"chance": 0.0,
			"tick": tick,
		})

# ── Faction collapse & redistribution ────────────────────────────────
func _check_collapse(center: int, tick: int) -> void:
	var factions: Dictionary = _settlement_factions.get(center, {})
	for fid in FactionType.values():
		if not factions.has(fid):
			continue
		if factions[fid]["influence"] >= COLLAPSE_INFLUENCE_FLOOR:
			continue
		_collapse_faction(center, fid, tick)
	_redistribute_collapsed_influence(center, tick)

func _collapse_faction(center: int, faction: int, tick: int) -> void:
	var factions: Dictionary = _settlement_factions.get(center, {})
	if not factions.has(faction):
		return
	var wm := get_node_or_null("/root/WorldMemory")
	if wm != null and wm.has_method("record_event"):
		wm.record_event({
			"type": "faction_collapse",
			"settlement_center": center,
			"faction": FACTION_NAMES.get(faction, "Unknown"),
			"faction_id": faction,
			"tick": tick,
		})
	faction_collapsed.emit(center, faction, tick)
	factions[faction]["influence"] = MIN_INFLUENCE

func _redistribute_collapsed_influence(center: int, tick: int) -> void:
	var factions: Dictionary = _settlement_factions.get(center, {})
	var collapsed_inf: float = 0.0
	var active_factions: Array = []
	for fid in FactionType.values():
		if not factions.has(fid):
			continue
		var inf: float = factions[fid]["influence"]
		if inf < COLLAPSE_INFLUENCE_FLOOR:
			collapsed_inf += inf
		else:
			active_factions.append(fid)
	if collapsed_inf <= 0.0 or active_factions.is_empty():
		return
	var share: float = collapsed_inf / float(active_factions.size())
	for fid in active_factions:
		_adjust_influence(center, fid, share, tick)

# ── Pawn loyalty system ──────────────────────────────────────────────
func assign_pawn_loyalty(pawn_id: int, profession: String, caste: String = "", household: String = "") -> void:
	if _pawn_loyalties.has(pawn_id):
		return
	var affinities: Dictionary = {}
	for ft in FactionType.values():
		var base: float = 10.0
		var prefs: Array = FACTION_JOB_PREFERENCES.get(ft, [])
		for pref in prefs:
			if profession.to_lower() == pref.to_lower():
				base += 25.0
				break
		if not caste.is_empty() and _caste_faction_bias(caste) == ft:
			base += 15.0
		if not household.is_empty():
			var h_hash: int = abs(household.hash())
			var h_bias: int = h_hash % int(FactionType.size())
			if h_bias == ft:
				base += 10.0
		affinities[ft] = clampf(base, 0.0, MAX_INFLUENCE)
	_pawn_loyalties[pawn_id] = affinities

static func _caste_faction_bias(caste: String) -> int:
	var c: String = caste.to_lower().strip_edges()
	var biases: Dictionary = {
		"noble": FactionType.ROYALISTS,
		"merchant": FactionType.MERCHANTS,
		"warrior": FactionType.MILITARY,
		"priest": FactionType.CLERGY,
		"common": FactionType.COMMONERS,
		"artisan": FactionType.COMMONERS,
		"scholar": FactionType.CLERGY,
		"trader": FactionType.MERCHANTS,
	}
	return biases.get(c, -1)

func get_pawn_primary_loyalty(pawn_id: int) -> int:
	var affinities: Dictionary = _pawn_loyalties.get(pawn_id, {})
	if affinities.is_empty():
		return -1
	var best_fid: int = -1
	var best_val: float = -1.0
	for fid in affinities.keys():
		if affinities[fid] > best_val:
			best_val = affinities[fid]
			best_fid = fid
	return best_fid

func get_pawn_faction_affinity(pawn_id: int, faction: int) -> float:
	return _pawn_loyalties.get(pawn_id, {}).get(faction, 0.0)

func modify_pawn_affinity(pawn_id: int, faction: int, delta: float) -> void:
	if not _pawn_loyalties.has(pawn_id):
		return
	var affinities: Dictionary = _pawn_loyalties[pawn_id]
	if not affinities.has(faction):
		return
	affinities[faction] = clampf(affinities[faction] + delta, 0.0, MAX_INFLUENCE)

# ── EventBus callbacks ───────────────────────────────────────────────
func _on_settlement_founded(payload: Dictionary) -> void:
	var center: int = int(payload.get("settlement_id", payload.get("center_region", -1)))
	if center < 0:
		var tile: Variant = payload.get("tile", null)
		if tile is Vector2i:
			center = int(WorldMemory._region_key((tile as Vector2i).x, (tile as Vector2i).y))
	if center < 0 or _settlement_factions.has(center):
		return
	var st: Dictionary = {"center_region": center, "governance_type": "council", "population": 5}
	_ensure_factions(center, st)

func _on_pawn_died(payload: Dictionary) -> void:
	var pawn_id: int = int(payload.get("pawn_id", -1))
	if pawn_id < 0 or not _pawn_loyalties.has(pawn_id):
		return
	var affinities: Dictionary = _pawn_loyalties[pawn_id]
	var top_fid: int = -1
	var top_val: float = -1.0
	for fid in affinities.keys():
		if affinities[fid] > top_val:
			top_val = affinities[fid]
			top_fid = fid
	if top_fid < 0:
		return
	_pawn_loyalties.erase(pawn_id)

func _on_settlement_attacked(payload: Dictionary) -> void:
	var center: int = int(payload.get("settlement_id", -1))
	if center < 0:
		return
	var boost_amount: float = 8.0
	_queue_event_boost(center, FactionType.MILITARY, boost_amount)

func _on_combat_started(payload: Dictionary) -> void:
	var center: int = int(payload.get("settlement_id", payload.get("center", -1)))
	if center < 0:
		return
	_queue_event_boost(center, FactionType.MILITARY, 5.0)

func _on_combat_ended(payload: Dictionary) -> void:
	var center: int = int(payload.get("settlement_id", payload.get("center", -1)))
	if center < 0:
		return
	var won: bool = bool(payload.get("victory", payload.get("won", true)))
	if won:
		_queue_event_boost(center, FactionType.MILITARY, 6.0)
		_queue_event_boost(center, FactionType.ROYALISTS, 2.0)
	else:
		_queue_event_boost(center, FactionType.COMMONERS, 3.0)
		_queue_event_boost(center, FactionType.MILITARY, -4.0)

func _on_trade_route_established(payload: Dictionary) -> void:
	var center: int = int(payload.get("settlement_id", -1))
	if center < 0:
		return
	_queue_event_boost(center, FactionType.MERCHANTS, 10.0)

func _on_pressure_event(payload: Dictionary) -> void:
	var center: int = int(payload.get("settlement_id", -1))
	var event_type: String = str(payload.get("event_type", ""))
	if center < 0:
		return
	match event_type:
		"famine", "starvation":
			_queue_event_boost(center, FactionType.COMMONERS, 4.0)
			_queue_event_boost(center, FactionType.ROYALISTS, -6.0)
		"religious_awakening":
			_queue_event_boost(center, FactionType.CLERGY, 10.0)
		"economic_boom":
			_queue_event_boost(center, FactionType.MERCHANTS, 8.0)
		"foreign_threat":
			_queue_event_boost(center, FactionType.MILITARY, 10.0)
			_queue_event_boost(center, FactionType.COMMONERS, 3.0)
		"plague":
			_queue_event_boost(center, FactionType.CLERGY, 6.0)
			_queue_event_boost(center, FactionType.COMMONERS, -4.0)
		"rebellion":
			_queue_event_boost(center, FactionType.COMMONERS, 8.0)
			_queue_event_boost(center, FactionType.ROYALISTS, -5.0)
			_queue_event_boost(center, FactionType.MILITARY, 3.0)

func _on_building_constructed(payload: Dictionary) -> void:
	var center: int = int(payload.get("settlement_id", -1))
	var building_type: String = str(payload.get("building_type", ""))
	if center < 0 or building_type.is_empty():
		return
	var btype: String = building_type.to_lower()
	if btype in ["barracks", "fort", "wall", "watchtower", "garrison", "armory", "training_yard"]:
		_queue_event_boost(center, FactionType.MILITARY, 5.0)
	elif btype in ["market", "shop", "bank", "exchange", "warehouse", "dock", "guild_hall"]:
		_queue_event_boost(center, FactionType.MERCHANTS, 5.0)
	elif btype in ["shrine", "temple", "altar", "pulpit", "scriptorium"]:
		_queue_event_boost(center, FactionType.CLERGY, 5.0)
	elif btype in ["town_hall", "assembly", "well", "square"]:
		_queue_event_boost(center, FactionType.COMMONERS, 4.0)
	elif btype in ["keep", "palace", "throne_room", "monument"]:
		_queue_event_boost(center, FactionType.ROYALISTS, 5.0)

func _on_war_declared(payload: Dictionary) -> void:
	var center: int = int(payload.get("settlement_id", payload.get("aggressor", -1)))
	if center < 0:
		center = int(payload.get("defender", -1))
	if center < 0:
		return
	_queue_event_boost(center, FactionType.MILITARY, 12.0)
	_queue_event_boost(center, FactionType.MERCHANTS, -3.0)
	_queue_event_boost(center, FactionType.COMMONERS, -5.0)
	var wm := get_node_or_null("/root/WorldMemory")
	if wm != null and wm.has_method("record_event"):
		wm.record_event({
			"type": "war_faction_response",
			"settlement_center": center,
			"military_boost": 12.0,
			"tick": GameManager.tick_count if GameManager != null else 0,
		})

func _queue_event_boost(center: int, faction: int, amount: float) -> void:
	if not _event_driven_boosts.has(center):
		_event_driven_boosts[center] = {}
	var boosts: Dictionary = _event_driven_boosts[center]
	boosts[faction] = boosts.get(faction, 0.0) + amount

# ── Foreign faction influence ─────────────────────────────────────────
func apply_foreign_influence(target_center: int, from_center: int, faction: int, amount: float) -> void:
	if amount <= 0.0:
		return
	var dist_factor: float = FOREIGN_INFLUENCE_RADIUS
	if from_center == target_center:
		dist_factor = 1.0
	else:
		var diff: int = absi(from_center - target_center)
		dist_factor = clampf(FOREIGN_INFLUENCE_RADIUS / (1.0 + float(diff) * 0.001), 0.01, 0.5)
	var effective: float = amount * dist_factor
	if not _foreign_influence_pending.has(target_center):
		_foreign_influence_pending[target_center] = {}
	var pending: Dictionary = _foreign_influence_pending[target_center]
	var factions: Dictionary = _settlement_factions.get(target_center, {})
	if factions.has(faction):
		pending[faction] = pending.get(faction, 0.0) + effective

# ── Historical tracking ──────────────────────────────────────────────
func _record_historical_snapshot(center: int, tick: int) -> void:
	if not _historical_power.has(center):
		_historical_power[center] = []
	var snapshots: Array = _historical_power[center]
	var snapshot: Dictionary = {"tick": tick}
	var factions: Dictionary = _settlement_factions.get(center, {})
	for fid in FactionType.values():
		if factions.has(fid):
			snapshot[FACTION_NAMES.get(fid, str(fid))] = factions[fid]["influence"]
	snapshot["dominant"] = FACTION_NAMES.get(_get_dominant_faction(center), "None")
	snapshots.append(snapshot)
	while snapshots.size() > MAX_HISTORICAL_SNAPSHOTS:
		snapshots.pop_front()

func get_historical_power(center: int) -> Array:
	return _historical_power.get(center, []).duplicate()

# ── Public API / Debug ───────────────────────────────────────────────
func get_dominant_faction(center: int) -> int:
	return _get_dominant_faction(center)

func get_faction_influence(center: int, faction: int) -> float:
	return _settlement_factions.get(center, {}).get(faction, {}).get("influence", 0.0)

func get_factions(center: int) -> Dictionary:
	var factions: Dictionary = _settlement_factions.get(center, {})
	var out: Dictionary = {}
	for fid in factions.keys():
		if not (fid is int):
			continue
		out[FACTION_NAMES.get(fid, str(fid))] = factions[fid].duplicate()
	return out

func get_faction_agenda(center: int, faction: int) -> Dictionary:
	return _settlement_factions.get(center, {}).get(faction, {}).get("agenda", {}).duplicate()

func get_settlement_agenda(center: int) -> Dictionary:
	var dom: int = _get_dominant_faction(center)
	if dom < 0:
		return {"name": "None", "building_prefs": [], "diplomatic_stance": "neutral", "tax_policy": "moderate"}
	return get_faction_agenda(center, dom)

func get_coalition_info(center: int) -> Dictionary:
	return {
		"active": _get_meta(center, "coalition_active", false),
		"members": _get_meta(center, "coalition_members", []).duplicate(),
		"formed_tick": _get_meta(center, "last_coalition_tick", -1),
	}

func get_faction_report(center: int) -> Dictionary:
	var factions: Dictionary = _settlement_factions.get(center, {})
	var dom: int = _get_dominant_faction(center)
	var report: Dictionary = {
		"center": center,
		"dominant_faction": FACTION_NAMES.get(dom, "None"),
		"dominant_faction_id": dom,
		"factions": {},
		"coalition": get_coalition_info(center),
		"total_factions": 0,
		"avg_influence": 0.0,
		"power_delta": 0.0,
	}
	var total_inf: float = 0.0
	var count: int = 0
	for fid in FactionType.values():
		if not factions.has(fid):
			continue
		var f: Dictionary = factions[fid]
		report["factions"][FACTION_NAMES.get(fid, str(fid))] = {
			"influence": f["influence"],
			"members": f["members"],
			"agenda": f.get("agenda", {}).get("name", "None"),
			"coup_attempts": f.get("coup_attempts", 0),
			"peak": f.get("peak_influence", 0.0),
			"total_boosts": f.get("total_boosts", 0.0),
			"total_penalties": f.get("total_penalties", 0.0),
		}
		total_inf += f["influence"]
		count += 1
	report["total_factions"] = count
	if count > 0:
		report["avg_influence"] = total_inf / float(count)
	return report

func is_single_faction_settlement(center: int) -> bool:
	var factions: Dictionary = _settlement_factions.get(center, {})
	var active: int = 0
	for fid in FactionType.values():
		if factions.has(fid) and factions[fid]["influence"] > COLLAPSE_INFLUENCE_FLOOR:
			active += 1
	return active <= 1

# ── Save / Load / Clear ──────────────────────────────────────────────
func to_save_dict() -> Dictionary:
	return {
		"settlement_factions": _duplicate_dict(_settlement_factions),
		"settlement_meta": _settlement_meta.duplicate(true),
		"pawn_loyalties": _duplicate_dict(_pawn_loyalties),
		"historical_power": _duplicate_historical(),
		"coalitions": _coalitions.duplicate(true),
		"coup_cooldowns": _coup_cooldowns.duplicate(true),
		"event_driven_boosts": _duplicate_dict(_event_driven_boosts),
		"last_politics_tick": _last_politics_tick,
	}

func from_save_dict(d: Variant) -> void:
	clear()
	if d == null or not (d is Dictionary):
		return
	var sd: Dictionary = d as Dictionary
	_settlement_factions = _restore_nested(sd.get("settlement_factions", {}))
	_settlement_meta = sd.get("settlement_meta", {}).duplicate(true)
	_pawn_loyalties = _restore_nested(sd.get("pawn_loyalties", {}))
	_historical_power = _restore_historical(sd.get("historical_power", {}))
	_coalitions = sd.get("coalitions", {}).duplicate(true)
	_coup_cooldowns = sd.get("coup_cooldowns", {}).duplicate(true)
	_event_driven_boosts = _restore_nested(sd.get("event_driven_boosts", {}))
	_last_politics_tick = int(sd.get("last_politics_tick", -999999))
	_rebuild_meta()

func clear() -> void:
	_settlement_factions.clear()
	_settlement_meta.clear()
	_pawn_loyalties.clear()
	_historical_power.clear()
	_coalitions.clear()
	_coup_cooldowns.clear()
	_event_driven_boosts.clear()
	_foreign_influence_pending.clear()
	_last_politics_tick = -999999

func _rebuild_meta() -> void:
	for center in _settlement_factions.keys():
		if not _settlement_meta.has(center):
			_settlement_meta[center] = {
				"dominant_faction": _get_dominant_faction(center),
				"last_coup_tick": -1,
				"last_coalition_tick": -1,
				"coalition_active": false,
				"coalition_members": [],
			}
		else:
			_settlement_meta[center]["dominant_faction"] = _get_dominant_faction(center)

# ── Deep-copy helpers (preserves nested Dict → Dict → primitive) ─────
static func _duplicate_dict(d: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for k in d.keys():
		var v = d[k]
		if v is Dictionary:
			out[k] = _duplicate_dict(v as Dictionary)
		elif v is Array:
			out[k] = v.duplicate(true)
		else:
			out[k] = v
	return out

static func _restore_nested(d: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for k in d.keys():
		var v = d[k]
		if v is Dictionary:
			out[k] = _restore_nested(v as Dictionary)
		else:
			out[k] = v
	return out

func _duplicate_historical() -> Dictionary:
	var out: Dictionary = {}
	for center in _historical_power.keys():
		var snaps: Array = _historical_power[center]
		var copy: Array = []
		for s in snaps:
			if s is Dictionary:
				copy.append((s as Dictionary).duplicate(true))
		out[center] = copy
	return out

func _restore_historical(d: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for k in d.keys():
		var v = d[k]
		if v is Array:
			var restored: Array = []
			for item in v:
				if item is Dictionary:
					restored.append((item as Dictionary).duplicate(true))
			out[int(k)] = restored
	return out
