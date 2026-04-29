extends Node

## SPEC (v1): Structured **observer / future-player** intents. Append-only session queue
## plus a slim [WorldMemory] echo per submit for copy-pasteable traces. This is
## not sim authority — gameplay still runs on kernel + existing queues.

enum IntentKind {
	NONE = 0,
	## Free-text chronicler mark (no world mutation).
	OBSERVER_NOTE = 1,
	## Pin attention on a settlement zone id (string center_region).
	CHRONICLE_PIN_ZONE = 2,
	## Request UI/debug focus (payload carries hint keys only).
	REQUEST_SETTLEMENT_FOCUS = 3,
	## Reserved for tooling (F10, tests); must stay deterministic.
	DEBUG_TOOL = 4,
	## Request to open the future incarnation entry flow.
	REQUEST_INCARNATION_ENTRY = 5,
	## Request to return from incarnation back to spectator state.
	REQUEST_SPECTATOR_RETURN = 6,
}

const MAX_QUEUE: int = 512

## Each entry: submit_tick, kind, zone_id, pawn_id, note, payload (Dictionary).
var _queue: Array[Dictionary] = []
var _submitted_total: int = 0
## Advances as [method take_next_unprocessed] runs; entries remain in [member _queue] for history/save.
var _dispatch_cursor: int = 0


func clear() -> void:
	_queue.clear()
	_submitted_total = 0
	_dispatch_cursor = 0


func to_save_dict() -> Dictionary:
	return {
		"queue": _queue.duplicate(true),
		"submitted_total": _submitted_total,
		"dispatch_cursor": _dispatch_cursor,
	}


func from_save_dict(d: Variant) -> void:
	clear()
	if d is not Dictionary:
		return
	var q: Variant = (d as Dictionary).get("queue", [])
	if q is Array:
		for item in q as Array:
			if item is Dictionary and _queue.size() < MAX_QUEUE:
				_queue.append((item as Dictionary).duplicate(true))
	_submitted_total = int((d as Dictionary).get("submitted_total", _queue.size()))
	_dispatch_cursor = clampi(int((d as Dictionary).get("dispatch_cursor", 0)), 0, _queue.size())


## Returns the next entry not yet passed to the sim-time dispatcher, then advances the cursor.
## Queue entries are retained for [method snapshot_queue] / save.
func take_next_unprocessed() -> Dictionary:
	if _dispatch_cursor >= _queue.size():
		return {}
	var e: Dictionary = _queue[_dispatch_cursor].duplicate(true)
	_dispatch_cursor += 1
	return e


func unprocessed_count() -> int:
	return maxi(0, _queue.size() - _dispatch_cursor)


## Returns false if queue is full. On success, records a [WorldMemory] event.
func submit(kind: int, zone_id: String, pawn_id: int, note: String, payload: Dictionary = {}) -> bool:
	if _queue.size() >= MAX_QUEUE:
		return false
	var tick: int = GameManager.tick_count
	var entry: Dictionary = {
		"submit_tick": tick,
		"kind": kind,
		"zone_id": zone_id,
		"pawn_id": pawn_id,
		"note": note,
		"payload": payload.duplicate(true),
	}
	_queue.append(entry)
	_submitted_total += 1
	WorldMemory.record_event({
		"type": "player_intent",
		"kind": kind,
		"kind_name": intent_kind_name(kind),
		"zone_id": zone_id,
		"pawn_id": pawn_id,
		"note": note,
		"tick": tick,
	})
	return true


static func intent_kind_name(kind: int) -> String:
	match kind:
		IntentKind.OBSERVER_NOTE:
			return "OBSERVER_NOTE"
		IntentKind.CHRONICLE_PIN_ZONE:
			return "CHRONICLE_PIN_ZONE"
		IntentKind.REQUEST_SETTLEMENT_FOCUS:
			return "REQUEST_SETTLEMENT_FOCUS"
		IntentKind.DEBUG_TOOL:
			return "DEBUG_TOOL"
		IntentKind.REQUEST_INCARNATION_ENTRY:
			return "REQUEST_INCARNATION_ENTRY"
		IntentKind.REQUEST_SPECTATOR_RETURN:
			return "REQUEST_SPECTATOR_RETURN"
		_:
			return "NONE"


func request_incarnation_entry(note: String = "", payload: Dictionary = {}) -> bool:
	return submit(IntentKind.REQUEST_INCARNATION_ENTRY, "", -1, note, payload)


func request_spectator_return(note: String = "", payload: Dictionary = {}) -> bool:
	return submit(IntentKind.REQUEST_SPECTATOR_RETURN, "", -1, note, payload)


func queue_size() -> int:
	return _queue.size()


func snapshot_queue() -> Array:
	return _queue.duplicate(true)


func debug_summary_block() -> String:
	var lines: PackedStringArray = PackedStringArray()
	lines.append("PlayerIntentQueue SPEC v1")
	lines.append(
			"  queue_size=%d unprocessed=%d submitted_total=%d max=%d"
			% [_queue.size(), unprocessed_count(), _submitted_total, MAX_QUEUE]
	)
	lines.append("  IntentKind: OBSERVER_NOTE=1 CHRONICLE_PIN_ZONE=2 REQUEST_SETTLEMENT_FOCUS=3 DEBUG_TOOL=4")
	var n: int = mini(12, _queue.size())
	for i in range(n):
		var e: Dictionary = _queue[_queue.size() - 1 - i]
		lines.append(
				"  [%d] tick=%d kind=%s zone=%s pawn=%d note=%s" % [
					i,
					int(e.get("submit_tick", -1)),
					intent_kind_name(int(e.get("kind", 0))),
					str(e.get("zone_id", "")),
					int(e.get("pawn_id", -1)),
					str(e.get("note", "")),
				]
		)
	if _queue.is_empty():
		lines.append("  (empty) Example: PlayerIntentQueue.submit(PlayerIntentQueue.IntentKind.OBSERVER_NOTE, \"\", -1, \"session note\", {})")
	lines.append("  Incarnation helpers: request_incarnation_entry() request_spectator_return()")
	return "\n".join(lines)
