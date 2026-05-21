class_name WorldMemoryTypes
extends RefCounted


enum EventType {
	UNKNOWN = 0,
	PAWN_DIED = 1,
	SETTLEMENT_CREATED = 2,
	SETTLEMENT_FOUNDED = 3,
	RESOURCE_DEPLETED = 4,
	RESOURCE_EXHAUSTED = 5,
	TEACHING_EVENT = 6,
	WORK_EVENT = 7,
	CONFLICT_EVENT = 8,
}


class EventRecord:
	extends RefCounted

	var tick: int = 0
	var event_type: int = EventType.UNKNOWN
	var event_name: String = "unknown"
	var subject_id: String = ""
	var location: Vector2i = Vector2i.ZERO
	var cause: Dictionary = {}
	var impact_score: float = 0.0
	var hash: String = ""
	var eid: int = 0

	func to_dictionary(public_only: bool = false) -> Dictionary:
		var out: Dictionary = {
			"eid": eid,
			"tick": tick,
			"t": tick,
			"event_type": event_type,
			"event_type_name": event_name,
			"type": event_name,
			"location": location,
			"x": location.x,
			"y": location.y,
			"impact_score": impact_score,
			"impact": impact_score,
			"hash": hash,
		}
		if public_only:
			out["subject_id"] = WorldMemoryTypes.public_subject_id(subject_id)
			out["cause"] = WorldMemoryTypes.public_cause(cause)
		else:
			out["subject_id"] = subject_id
			out["cause"] = cause.duplicate(true)
		return out


static func event_type_name(event_type: int) -> String:
	match event_type:
		EventType.PAWN_DIED:
			return "pawn_died"
		EventType.SETTLEMENT_CREATED:
			return "settlement_created"
		EventType.SETTLEMENT_FOUNDED:
			return "settlement_founded"
		EventType.RESOURCE_DEPLETED:
			return "resource_depleted"
		EventType.RESOURCE_EXHAUSTED:
			return "resource_exhausted"
		EventType.TEACHING_EVENT:
			return "teaching_event"
		EventType.WORK_EVENT:
			return "work_event"
		EventType.CONFLICT_EVENT:
			return "conflict_event"
		_:
			return "unknown"


static func event_type_from_name(event_type_name: String) -> int:
	match event_type_name.strip_edges().to_lower():
		"pawn_died", "pawn_death", "death":
			return EventType.PAWN_DIED
		"settlement_created":
			return EventType.SETTLEMENT_CREATED
		"settlement_founded", "settlement_new_foundation":
			return EventType.SETTLEMENT_FOUNDED
		"resource_depleted":
			return EventType.RESOURCE_DEPLETED
		"resource_exhausted":
			return EventType.RESOURCE_EXHAUSTED
		"teaching_event", "teaching":
			return EventType.TEACHING_EVENT
		"work_event", "job_completed":
			return EventType.WORK_EVENT
		"conflict_event", "war_battle_spawned", "battle_resolved":
			return EventType.CONFLICT_EVENT
		_:
			return EventType.UNKNOWN


static func public_subject_id(subject_id: String) -> String:
	var s: String = subject_id.strip_edges()
	if s.is_empty():
		return s
	if s.is_valid_int():
		return "anon_%08x" % (abs(int(s) * 486187739) & 0xFFFFFFFF)
	return "anon_%s" % s.sha256_text().substr(0, 12)


static func public_cause(cause: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for key in cause.keys():
		var key_name: String = str(key)
		if key_name in ["killer_id", "killer_name", "subject_id", "actor_id", "target_id"]:
			continue
		out[key_name] = cause[key]
	return out


static func stable_value_string(value: Variant) -> String:
	if value == null:
		return "null"
	if value is Dictionary:
		var dict: Dictionary = value as Dictionary
		var keys: Array = dict.keys()
		keys.sort()
		var parts: PackedStringArray = []
		for key in keys:
			parts.append("%s=%s" % [str(key), stable_value_string(dict[key])])
		return "{" + ",".join(parts) + "}"
	if value is Array:
		var arr: Array = value as Array
		var items: PackedStringArray = []
		for item in arr:
			items.append(stable_value_string(item))
		return "[" + ",".join(items) + "]"
	if value is Vector2i:
		var tile: Vector2i = value as Vector2i
		return "%d,%d" % [tile.x, tile.y]
	if value is Vector3:
		var vec3: Vector3 = value as Vector3
		return "%d,%d,%d" % [int(vec3.x), int(vec3.y), int(vec3.z)]
	return str(value)


static func compute_record_hash(tick: int, event_type: int, subject_id: String, location: Vector2i, cause: Dictionary, impact_score: float) -> String:
	var payload: String = "tick=%d|type=%s|subject=%s|location=%d,%d|cause=%s|impact=%.4f" % [
		tick,
		event_type_name(event_type),
		subject_id,
		location.x,
		location.y,
		stable_value_string(cause),
		impact_score,
	]
	return payload.sha256_text()