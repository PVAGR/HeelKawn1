extends Node
## FintechBridge
##
## Deterministic external-finance bridge for HeelKawn.
## External systems (Meow, exchanges, payment rails) must never directly mutate
## world truth by wall-clock callbacks. They must be normalized into explicit
## manifests with stable ids + apply ticks, then consumed by the sim tick.

signal fintech_event_applied(event_id: String, kind: String, apply_tick: int)

const SOURCE_MEOW: String = "meow"
const SOURCE_MANUAL: String = "manual"

const KIND_TREASURY_CREDIT: String = "treasury_credit"
const KIND_TREASURY_DEBIT: String = "treasury_debit"
const KIND_PAYOUT_REQUESTED: String = "payout_requested"
const KIND_PAYOUT_SETTLED: String = "payout_settled"

var _pending_events: Array[Dictionary] = []
var _seen_event_ids: Dictionary = {}
var _seen_manifest_ids: Dictionary = {}
var _applied_events: Array[Dictionary] = []
var _treasury_by_currency: Dictionary = {} # currency -> int micro-units (cents for fiat)


func _ready() -> void:
	if GameManager != null and GameManager.has_signal("game_tick"):
		GameManager.game_tick.connect(_on_game_tick)


func queue_manifest(manifest: Dictionary) -> Dictionary:
	# Required manifest fields:
	# - manifest_id: String
	# - source: String
	# - events: Array[Dictionary] of normalized events
	var manifest_id: String = str(manifest.get("manifest_id", "")).strip_edges()
	if manifest_id == "":
		return {"ok": false, "error": "missing_manifest_id"}
	if _seen_manifest_ids.has(manifest_id):
		return {"ok": true, "accepted": 0, "duplicate_manifest": true}
	var source: String = str(manifest.get("source", SOURCE_MANUAL)).strip_edges()
	var events_v: Variant = manifest.get("events", [])
	if not (events_v is Array):
		return {"ok": false, "error": "events_must_be_array"}
	var events: Array = events_v as Array
	var accepted: int = 0
	for raw in events:
		if not (raw is Dictionary):
			continue
		var normalized: Dictionary = _normalize_event(raw as Dictionary, source)
		if normalized.is_empty():
			continue
		if _seen_event_ids.has(normalized.event_id):
			continue
		_seen_event_ids[normalized.event_id] = true
		_pending_events.append(normalized)
		accepted += 1
	_seen_manifest_ids[manifest_id] = true
	_pending_events.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var at: int = int(a.get("apply_tick", 0))
		var bt: int = int(b.get("apply_tick", 0))
		if at == bt:
			return str(a.get("event_id", "")) < str(b.get("event_id", ""))
		return at < bt
	)
	return {
		"ok": true,
		"accepted": accepted,
		"pending_total": _pending_events.size(),
	}


func queue_single_event(event_data: Dictionary, source: String = SOURCE_MANUAL) -> Dictionary:
	var manifest: Dictionary = {
		"manifest_id": "single:%s" % str(event_data.get("event_id", "")),
		"source": source,
		"events": [event_data],
	}
	return queue_manifest(manifest)


func _normalize_event(raw: Dictionary, source: String) -> Dictionary:
	var event_id: String = str(raw.get("event_id", "")).strip_edges()
	if event_id == "":
		return {}
	var apply_tick: int = int(raw.get("apply_tick", -1))
	if apply_tick < 0:
		return {}
	var kind: String = str(raw.get("kind", "")).strip_edges()
	if kind == "":
		return {}
	var currency: String = str(raw.get("currency", "USD")).to_upper().strip_edges()
	var amount_micro: int = int(raw.get("amount_micro", 0))
	var external_ref: String = str(raw.get("external_ref", "")).strip_edges()
	return {
		"event_id": event_id,
		"source": source,
		"kind": kind,
		"apply_tick": apply_tick,
		"currency": currency,
		"amount_micro": amount_micro,
		"external_ref": external_ref,
		"meta": raw.get("meta", {}),
	}


func _on_game_tick(tick: int) -> void:
	if _pending_events.is_empty():
		return
	while not _pending_events.is_empty():
		var next_ev: Dictionary = _pending_events[0]
		var apply_tick: int = int(next_ev.get("apply_tick", 0))
		if apply_tick > tick:
			break
		_pending_events.remove_at(0)
		_apply_event(next_ev)


func _apply_event(ev: Dictionary) -> void:
	var kind: String = str(ev.get("kind", ""))
	var currency: String = str(ev.get("currency", "USD"))
	var amount_micro: int = int(ev.get("amount_micro", 0))
	match kind:
		KIND_TREASURY_CREDIT:
			_treasury_add(currency, amount_micro)
		KIND_TREASURY_DEBIT:
			_treasury_add(currency, -abs(amount_micro))
		KIND_PAYOUT_REQUESTED:
			# Non-mutating in treasury by default; request entered for later settlement.
			pass
		KIND_PAYOUT_SETTLED:
			_treasury_add(currency, -abs(amount_micro))
		_:
			# Unknown kinds are recorded but do not mutate treasury.
			pass

	_applied_events.append(ev)
	if _applied_events.size() > 5000:
		_applied_events.pop_front()

	_record_to_world_memory(ev)
	fintech_event_applied.emit(
		str(ev.get("event_id", "")),
		kind,
		int(ev.get("apply_tick", -1)),
	)


func _treasury_add(currency: String, delta_micro: int) -> void:
	var cur: int = int(_treasury_by_currency.get(currency, 0))
	_treasury_by_currency[currency] = cur + delta_micro


func _record_to_world_memory(ev: Dictionary) -> void:
	if WorldMemory == null:
		return
	WorldMemory.record_event({
		"type": "fintech_event_applied",
		"kind": WorldMemory.Kind.LIFE_EVENT,
		"event_id": str(ev.get("event_id", "")),
		"event_kind": str(ev.get("kind", "")),
		"source": str(ev.get("source", "")),
		"currency": str(ev.get("currency", "USD")),
		"amount_micro": int(ev.get("amount_micro", 0)),
		"external_ref": str(ev.get("external_ref", "")),
		"apply_tick": int(ev.get("apply_tick", -1)),
		"tick": GameManager.tick_count if GameManager != null else 0,
	})


func get_treasury_snapshot() -> Dictionary:
	return _treasury_by_currency.duplicate(true)


func get_fintech_status() -> Dictionary:
	return {
		"pending": _pending_events.size(),
		"applied_recent": _applied_events.size(),
		"treasury": get_treasury_snapshot(),
		"manifests_seen": _seen_manifest_ids.size(),
		"events_seen": _seen_event_ids.size(),
	}


func debug_seed_meow_credit(apply_tick: int, amount_micro: int, external_ref: String = "") -> Dictionary:
	# Deterministic helper for testing pipeline from debug panels/scripts.
	return queue_single_event({
		"event_id": "meow:%d:%s" % [apply_tick, external_ref if external_ref != "" else str(amount_micro)],
		"kind": KIND_TREASURY_CREDIT,
		"apply_tick": apply_tick,
		"currency": "USD",
		"amount_micro": amount_micro,
		"external_ref": external_ref,
		"meta": {"provider": SOURCE_MEOW},
	}, SOURCE_MEOW)
