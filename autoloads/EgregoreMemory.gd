extends Node
## EgregoreMemory
##
## Deterministic collective-pressure layer derived from WorldMemory facts.
## Per-settlement signatures evolve from repeated behavior patterns.

const UPDATE_INTERVAL_TICKS: int = 600
const MAX_ABS_PRESSURE: float = 200.0
const NORM_COOLDOWN_TICKS: int = 7200

const AXES: PackedStringArray = [
	"cooperation",
	"discipline",
	"care",
	"fear",
	"vengeance",
	"curiosity",
	"asceticism",
	"opulence",
]

var _last_update_tick: int = -1
var _last_event_index: int = 0
## settlement_id(center_region) -> signature dictionary
var _signatures: Dictionary = {}
## settlement_id -> norm_name -> bool
var _active_norms: Dictionary = {}
## settlement_id|norm_name -> last change tick
var _norm_change_tick: Dictionary = {}
## settlement_id -> Array[float] divergence score history (recent)
var _divergence_history: Dictionary = {}
## settlement_id -> Array[float] migration tendency history (recent)
var _migration_history: Dictionary = {}


func _ready() -> void:
	if GameManager != null:
		GameManager.game_tick.connect(_on_game_tick)


func _on_game_tick(tick: int) -> void:
	if _last_update_tick >= 0 and tick - _last_update_tick < UPDATE_INTERVAL_TICKS:
		return
	_last_update_tick = tick
	_ingest_world_memory_events()
	_decay_signatures()
	_update_emergent_norms(tick)
	_sample_trends()


func _empty_signature(settlement_id: int) -> Dictionary:
	return {
		"id": settlement_id,
		"anchor_region": settlement_id,
		"cohesion": 0.5,
		"pressure_vector": {
			"cooperation": 0.0,
			"discipline": 0.0,
			"care": 0.0,
			"fear": 0.0,
			"vengeance": 0.0,
			"curiosity": 0.0,
			"asceticism": 0.0,
			"opulence": 0.0,
		},
		"ritual_density": 0.0,
		"taboo_density": 0.0,
		"law_density": 0.0,
		"memory_weight": 0.0,
		"last_update_tick": _last_update_tick,
	}


func _ensure_signature(settlement_id: int) -> Dictionary:
	if not _signatures.has(settlement_id):
		_signatures[settlement_id] = _empty_signature(settlement_id)
	return _signatures[settlement_id]


func _ingest_world_memory_events() -> void:
	if WorldMemory == null or not WorldMemory.has_method("get_events"):
		return
	var events: Array = WorldMemory.get_events()
	if events.is_empty():
		_last_event_index = 0
		return
	if _last_event_index < 0 or _last_event_index > events.size():
		_last_event_index = 0
	for i in range(_last_event_index, events.size()):
		var ev_v: Variant = events[i]
		if ev_v is Dictionary:
			_apply_event(ev_v as Dictionary)
	_last_event_index = events.size()


func _apply_event(ev: Dictionary) -> void:
	var settlement_id: int = _resolve_settlement_id(ev)
	if settlement_id < 0:
		return
	var typ: String = str(ev.get("type", ev.get("event_type", ""))).to_lower()
	if typ == "":
		return

	var sig: Dictionary = _ensure_signature(settlement_id)
	var pv: Dictionary = sig.get("pressure_vector", {})
	var delta: Dictionary = _pressure_delta_for_event(typ, ev)
	if delta.is_empty():
		return

	for k in delta.keys():
		if not pv.has(k):
			continue
		var v: float = float(pv.get(k, 0.0)) + float(delta.get(k, 0.0))
		pv[k] = clampf(v, -MAX_ABS_PRESSURE, MAX_ABS_PRESSURE)
	sig["pressure_vector"] = pv
	sig["memory_weight"] = float(sig.get("memory_weight", 0.0)) + 1.0
	sig["ritual_density"] = clampf(float(sig.get("ritual_density", 0.0)) + float(delta.get("_ritual", 0.0)), 0.0, 1.0)
	sig["taboo_density"] = clampf(float(sig.get("taboo_density", 0.0)) + float(delta.get("_taboo", 0.0)), 0.0, 1.0)
	sig["law_density"] = clampf(float(sig.get("law_density", 0.0)) + float(delta.get("_law", 0.0)), 0.0, 1.0)

	var positive: float = maxf(0.0, float(pv.get("cooperation", 0.0))) + maxf(0.0, float(pv.get("care", 0.0))) + maxf(0.0, float(pv.get("discipline", 0.0)))
	var negative: float = maxf(0.0, float(pv.get("fear", 0.0))) + maxf(0.0, float(pv.get("vengeance", 0.0)))
	var base: float = 0.5 + clampf((positive - negative) / 400.0, -0.35, 0.35)
	sig["cohesion"] = clampf(base, 0.0, 1.0)
	sig["last_update_tick"] = _last_update_tick
	_signatures[settlement_id] = sig


func _pressure_delta_for_event(typ: String, ev: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	match typ:
		"teach_skill", "apprenticeship":
			out["cooperation"] = 1.4
			out["discipline"] = 0.8
			out["care"] = 1.0
			out["curiosity"] = 1.6
		"shelter_built", "build_hearth", "build_bed", "settlement_founded":
			out["cooperation"] = 1.1
			out["discipline"] = 0.7
			out["care"] = 1.1
		"famine_warning", "starvation", "death_starvation":
			out["fear"] = 1.5
			out["asceticism"] = 0.8
			out["cooperation"] = -0.5
		"murder", "death_combat":
			out["fear"] = 1.3
			out["vengeance"] = 1.2
			out["cooperation"] = -0.7
		"law_enacted", "law_repealed", "governance_advanced", "governance_declared":
			out["discipline"] = 0.9
			out["_law"] = 0.02
		"ritual_performed", "prayer", "shrine_built":
			out["discipline"] = 0.4
			out["asceticism"] = 0.5
			out["_ritual"] = 0.03
		"trade_haul", "trade_route_established", "market_founded":
			out["cooperation"] = 0.5
			out["opulence"] = 0.9
		"fintech_event_applied":
			var ek: String = str(ev.get("event_kind", "")).to_lower()
			if ek == "payout_settled":
				out["care"] = 0.9
				out["cooperation"] = 0.6
				out["opulence"] = 0.5
			elif ek == "treasury_credit":
				out["opulence"] = 0.6
				out["discipline"] = 0.2
			elif ek == "treasury_debit":
				out["fear"] = 0.5
				out["asceticism"] = 0.3
		_:
			if typ.find("teach") >= 0:
				out["curiosity"] = 0.8
			elif typ.find("trade") >= 0:
				out["opulence"] = 0.5
			elif typ.find("law") >= 0:
				out["discipline"] = 0.5
				out["_law"] = 0.01
			elif typ.find("ritual") >= 0 or typ.find("prayer") >= 0 or typ.find("shrine") >= 0:
				out["asceticism"] = 0.3
				out["_ritual"] = 0.01
			elif typ.find("betray") >= 0:
				out["vengeance"] = 1.0
				out["cooperation"] = -0.5
				out["_taboo"] = 0.02
	return out


func _resolve_settlement_id(ev: Dictionary) -> int:
	if SettlementMemory == null:
		return -1
	var sid: int = int(ev.get("settlement_id", -1))
	if sid >= 0:
		return sid
	var pid: int = int(ev.get("pawn_id", -1))
	if pid >= 0 and SettlementMemory.has_method("get_settlement_id_for_pawn"):
		sid = int(SettlementMemory.get_settlement_id_for_pawn(pid))
		if sid >= 0:
			return sid
	var rk: int = int(ev.get("r", ev.get("region", -1)))
	if rk >= 0:
		sid = int(SettlementMemory.get_settlement_id_for_region(rk))
		if sid >= 0:
			return sid
		var ckr: int = int(SettlementMemory.get_center_region_for_region(rk))
		if ckr >= 0:
			return ckr
	return -1


func _decay_signatures() -> void:
	for sid_v in _signatures.keys():
		var sid: int = int(sid_v)
		var sig: Dictionary = _signatures[sid]
		var pv: Dictionary = sig.get("pressure_vector", {})
		for axis in AXES:
			var cur: float = float(pv.get(axis, 0.0))
			pv[axis] = cur * 0.995
		sig["pressure_vector"] = pv
		sig["memory_weight"] = maxf(0.0, float(sig.get("memory_weight", 0.0)) * 0.999)
		_signatures[sid] = sig


func _update_emergent_norms(tick: int) -> void:
	for sid_v in _signatures.keys():
		var sid: int = int(sid_v)
		var sig: Dictionary = _signatures[sid]
		var pv: Dictionary = sig.get("pressure_vector", {})
		var cooperation: float = float(pv.get("cooperation", 0.0))
		var discipline: float = float(pv.get("discipline", 0.0))
		var care: float = float(pv.get("care", 0.0))
		var fear: float = float(pv.get("fear", 0.0))
		var vengeance: float = float(pv.get("vengeance", 0.0))
		var curiosity: float = float(pv.get("curiosity", 0.0))
		var asceticism: float = float(pv.get("asceticism", 0.0))
		var opulence: float = float(pv.get("opulence", 0.0))
		var law_density: float = float(sig.get("law_density", 0.0))
		var taboo_density: float = float(sig.get("taboo_density", 0.0))

		# Norms are deterministic threshold rules over pressure state.
		_set_norm_state(sid, "mutual_aid", cooperation > 10.0 and care > 8.0 and fear < 8.0 and law_density > 0.10, tick)
		_set_norm_state(sid, "martial_code", fear > 10.0 and discipline > 8.0 and vengeance > 6.0, tick)
		_set_norm_state(sid, "scholar_path", curiosity > 10.0 and discipline > 6.0 and cooperation > 4.0, tick)
		_set_norm_state(sid, "austerity_rite", asceticism > 9.0 and fear > 6.0 and taboo_density > 0.08, tick)
		_set_norm_state(sid, "market_charter", opulence > 10.0 and cooperation > 6.0 and fear < 10.0, tick)


func _set_norm_state(settlement_id: int, norm_name: String, desired_active: bool, tick: int) -> void:
	if not _active_norms.has(settlement_id):
		_active_norms[settlement_id] = {}
	var m: Dictionary = _active_norms[settlement_id]
	var prev_active: bool = bool(m.get(norm_name, false))
	if prev_active == desired_active:
		return
	var key: String = "%d|%s" % [settlement_id, norm_name]
	var last_change: int = int(_norm_change_tick.get(key, -10_000_000))
	if tick - last_change < NORM_COOLDOWN_TICKS:
		return
	m[norm_name] = desired_active
	_active_norms[settlement_id] = m
	_norm_change_tick[key] = tick

	if desired_active:
		_add_emergent_law_if_missing(settlement_id, norm_name)
		if WorldMemory != null:
			WorldMemory.record_event({
				"type": "egregore_norm_emerged",
				"tick": tick,
				"settlement_id": settlement_id,
				"norm_type": norm_name,
			})
	else:
		if WorldMemory != null:
			WorldMemory.record_event({
				"type": "egregore_norm_faded",
				"tick": tick,
				"settlement_id": settlement_id,
				"norm_type": norm_name,
			})


func _add_emergent_law_if_missing(settlement_id: int, norm_name: String) -> void:
	if SettlementMemory == null or not SettlementMemory.has_method("add_law") or not SettlementMemory.has_method("get_laws"):
		return
	var law_type: String = "egregore_%s" % norm_name
	var laws: Array = SettlementMemory.get_laws(settlement_id)
	for lv in laws:
		if lv is Dictionary and str((lv as Dictionary).get("type", "")) == law_type:
			return
	var desc: String = ""
	match norm_name:
		"mutual_aid":
			desc = "Communal aid is expected during hunger, injury, and shelter work."
		"martial_code":
			desc = "Defense duty and response discipline are expected under threat."
		"scholar_path":
			desc = "Teaching and apprenticeship are recognized as civic obligations."
		"austerity_rite":
			desc = "Rationing and restrained consumption are expected in hardship."
		"market_charter":
			desc = "Trade fairness and contract trust are upheld by custom."
		_:
			desc = "Emergent social norm."
	SettlementMemory.add_law(settlement_id, {
		"type": law_type,
		"description": desc,
		"penalties": [],
		"rewards": [],
	})


func get_settlement_signature(settlement_id: int) -> Dictionary:
	if settlement_id < 0:
		return {}
	return (_signatures.get(settlement_id, {}) as Dictionary).duplicate(true)


func get_settlement_pressure(settlement_id: int, axis: String) -> float:
	if not _signatures.has(settlement_id):
		return 0.0
	var sig: Dictionary = _signatures[settlement_id]
	var pv: Dictionary = sig.get("pressure_vector", {})
	return float(pv.get(axis, 0.0))


func get_settlement_top_pressures(settlement_id: int, max_n: int = 3) -> Array:
	var out: Array = []
	if not _signatures.has(settlement_id):
		return out
	var sig: Dictionary = _signatures[settlement_id]
	var pv: Dictionary = sig.get("pressure_vector", {})
	var rows: Array = []
	for axis in AXES:
		rows.append({"axis": axis, "v": absf(float(pv.get(axis, 0.0))), "signed": float(pv.get(axis, 0.0))})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("v", 0.0)) > float(b.get("v", 0.0))
	)
	var lim: int = mini(max_n, rows.size())
	for i in range(lim):
		out.append(rows[i])
	return out


func get_world_snapshot() -> Dictionary:
	return {
		"tracked_settlements": _signatures.size(),
		"last_event_index": _last_event_index,
		"last_update_tick": _last_update_tick,
	}


func get_settlement_active_norms(settlement_id: int) -> Array:
	var out: Array = []
	if not _active_norms.has(settlement_id):
		return out
	var m: Dictionary = _active_norms[settlement_id]
	for k in m.keys():
		if bool(m[k]):
			out.append(str(k))
	out.sort()
	return out


func get_settlement_divergence_snapshot(settlement_id: int) -> Dictionary:
	if settlement_id < 0 or not _signatures.has(settlement_id):
		return {}
	var sig: Dictionary = _signatures[settlement_id]
	var pv: Dictionary = sig.get("pressure_vector", {})
	var cooperation: float = float(pv.get("cooperation", 0.0))
	var care: float = float(pv.get("care", 0.0))
	var discipline: float = float(pv.get("discipline", 0.0))
	var fear: float = float(pv.get("fear", 0.0))
	var vengeance: float = float(pv.get("vengeance", 0.0))
	var opulence: float = float(pv.get("opulence", 0.0))
	var curiosity: float = float(pv.get("curiosity", 0.0))
	var asceticism: float = float(pv.get("asceticism", 0.0))
	var norms: Array = get_settlement_active_norms(settlement_id)

	var stability: float = cooperation + care + discipline
	var threat: float = fear + vengeance
	var migration_tendency: float = clampf((threat - stability) * 0.08, -1.0, 1.0)
	if norms.has("mutual_aid"):
		migration_tendency -= 0.10
	if norms.has("scholar_path"):
		migration_tendency -= 0.06
	if norms.has("martial_code"):
		migration_tendency += 0.05
	if norms.has("austerity_rite"):
		migration_tendency += 0.05
	migration_tendency = clampf(migration_tendency, -1.0, 1.0)

	var divergence_score: float = clampf(
			(absf(cooperation) + absf(discipline) + absf(care) + absf(fear) + absf(vengeance) + absf(curiosity) + absf(asceticism) + absf(opulence))
			/ 120.0,
			0.0,
			1.0
	)
	var dtrend: String = _trend_label_from_series(_divergence_history.get(settlement_id, []) as Array, 0.01)
	var mtrend: String = _trend_label_from_series(_migration_history.get(settlement_id, []) as Array, 0.03)
	return {
		"cohesion": float(sig.get("cohesion", 0.5)),
		"divergence_score": divergence_score,
		"divergence_trend": dtrend,
		"migration_tendency": migration_tendency,
		"migration_trend": mtrend,
		"stability": stability,
		"threat": threat,
		"norms": norms,
	}


func _sample_trends() -> void:
	for sid_v in _signatures.keys():
		var sid: int = int(sid_v)
		var snap: Dictionary = get_settlement_divergence_snapshot_no_trend(sid)
		if snap.is_empty():
			continue
		_push_series(_divergence_history, sid, float(snap.get("divergence_score", 0.0)), 8)
		_push_series(_migration_history, sid, float(snap.get("migration_tendency", 0.0)), 8)


func get_settlement_divergence_snapshot_no_trend(settlement_id: int) -> Dictionary:
	if settlement_id < 0 or not _signatures.has(settlement_id):
		return {}
	var sig: Dictionary = _signatures[settlement_id]
	var pv: Dictionary = sig.get("pressure_vector", {})
	var cooperation: float = float(pv.get("cooperation", 0.0))
	var care: float = float(pv.get("care", 0.0))
	var discipline: float = float(pv.get("discipline", 0.0))
	var fear: float = float(pv.get("fear", 0.0))
	var vengeance: float = float(pv.get("vengeance", 0.0))
	var opulence: float = float(pv.get("opulence", 0.0))
	var curiosity: float = float(pv.get("curiosity", 0.0))
	var asceticism: float = float(pv.get("asceticism", 0.0))
	var norms: Array = get_settlement_active_norms(settlement_id)
	var stability: float = cooperation + care + discipline
	var threat: float = fear + vengeance
	var migration_tendency: float = clampf((threat - stability) * 0.08, -1.0, 1.0)
	if norms.has("mutual_aid"):
		migration_tendency -= 0.10
	if norms.has("scholar_path"):
		migration_tendency -= 0.06
	if norms.has("martial_code"):
		migration_tendency += 0.05
	if norms.has("austerity_rite"):
		migration_tendency += 0.05
	migration_tendency = clampf(migration_tendency, -1.0, 1.0)
	var divergence_score: float = clampf(
			(absf(cooperation) + absf(discipline) + absf(care) + absf(fear) + absf(vengeance) + absf(curiosity) + absf(asceticism) + absf(opulence))
			/ 120.0,
			0.0,
			1.0
	)
	return {
		"cohesion": float(sig.get("cohesion", 0.5)),
		"divergence_score": divergence_score,
		"migration_tendency": migration_tendency,
		"stability": stability,
		"threat": threat,
		"norms": norms,
	}


func _push_series(store: Dictionary, sid: int, value: float, max_n: int) -> void:
	var arr: Array = store.get(sid, []) as Array
	arr.append(value)
	while arr.size() > max_n:
		arr.pop_front()
	store[sid] = arr


func _trend_label_from_series(arr: Array, epsilon: float) -> String:
	if arr.size() < 2:
		return "steady"
	var older_n: int = maxi(1, arr.size() / 2)
	var recent_n: int = maxi(1, arr.size() - older_n)
	var older_sum: float = 0.0
	var recent_sum: float = 0.0
	for i in range(older_n):
		older_sum += float(arr[i])
	for i in range(older_n, arr.size()):
		recent_sum += float(arr[i])
	var older_avg: float = older_sum / float(older_n)
	var recent_avg: float = recent_sum / float(recent_n)
	if recent_avg > older_avg + epsilon:
		return "rising"
	if recent_avg < older_avg - epsilon:
		return "falling"
	return "steady"
