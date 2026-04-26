extends Node
## Deterministic append-only world fact log (Phase 2.1). No RNG; no UI.
## Events are plain Dictionaries for trivial save/load via Main snapshot.

const SCHEMA: int = 1
const MAX_EVENTS: int = 5000

enum Kind { PAWN_DEATH = 0, ANIMAL_DEATH = 1, ENEMY_DEATH = 2 }

var _events: Array[Dictionary] = []
var _dirty: bool = false


func clear() -> void:
	_events.clear()
	_dirty = false


## Returns whether new historical facts were recorded since last consume; clears the flag.
func consume_dirty() -> bool:
	var was_dirty: bool = _dirty
	_dirty = false
	return was_dirty


static func _region_key(tx: int, ty: int) -> int:
	var rx: int = int(tx) >> 4
	var ry: int = int(ty) >> 4
	return (rx & 0xFFFF) | ((ry & 0xFFFF) << 16)


func _append(e: Dictionary) -> void:
	_dirty = true
	if _events.size() >= MAX_EVENTS:
		_events.remove_at(0)
	_events.append(e)


## Generic deterministic event appender for non-core typed events (e.g. player input).
func record_event(e: Dictionary) -> void:
	var payload: Dictionary = e.duplicate(true)
	payload["s"] = SCHEMA
	if not payload.has("t"):
		payload["t"] = GameManager.tick_count
	_append(payload)


## Record after `data` is still valid; use primitive fields only.
func record_pawn_death(
		tick: int,
		tile: Vector2i,
		pawn_id: int,
		pawn_name: String,
		cause: String
	) -> void:
	_append({
		"s": SCHEMA,
		"k": int(Kind.PAWN_DEATH),
		"t": tick,
		"x": tile.x,
		"y": tile.y,
		"r": _region_key(tile.x, tile.y),
		"pid": pawn_id,
		"n": pawn_name,
		"c": cause,
	})


func record_animal_death(
		tick: int,
		tile: Vector2i,
		species: int,
		species_name: String
	) -> void:
	_append({
		"s": SCHEMA,
		"k": int(Kind.ANIMAL_DEATH),
		"t": tick,
		"x": tile.x,
		"y": tile.y,
		"r": _region_key(tile.x, tile.y),
		"sp": species,
		"sn": species_name,
	})


func record_enemy_death(
		tick: int,
		tile: Vector2i,
		enemy_name: String,
		attacker_name: String,
		total_kills: int
	) -> void:
	_append({
		"s": SCHEMA,
		"k": int(Kind.ENEMY_DEATH),
		"type": "enemy_death",
		"t": tick,
		"x": tile.x,
		"y": tile.y,
		"r": _region_key(tile.x, tile.y),
		"enemy": enemy_name,
		"attacker": attacker_name,
		"kill_count": total_kills,
	})


func to_save_dict() -> Dictionary:
	return {
		"schema": SCHEMA,
		"events": _events.duplicate(true),
	}


func from_save_dict(d: Variant) -> void:
	clear()
	if d == null or not (d is Dictionary):
		return
	var ev: Variant = (d as Dictionary).get("events", [])
	if ev is Array:
		for e in ev:
			if e is Dictionary:
				_events.append((e as Dictionary).duplicate(true))


func event_count() -> int:
	return _events.size()


func get_recent_event_summaries(max_items: int = 3) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if max_items <= 0 or _events.is_empty():
		return out
	var start: int = maxi(0, _events.size() - max_items)
	for i in range(_events.size() - 1, start - 1, -1):
		var evt: Dictionary = _events[i]
		var kind: String = str(evt.get("type", ""))
		if kind == "":
			var k: int = int(evt.get("k", -1))
			if k == int(Kind.PAWN_DEATH):
				kind = "pawn_death"
			elif k == int(Kind.ANIMAL_DEATH):
				kind = "animal_death"
			elif k == int(Kind.ENEMY_DEATH):
				kind = "enemy_death"
			else:
				kind = "event"
		var line: String = "%d: %s" % [int(evt.get("t", 0)), kind.replace("_", " ")]
		if kind == "war_battle_spawned":
			line += " (battle spawned)"
		elif kind == "war_proposed":
			line += " (war proposed)"
		elif kind == "governance_change":
			line += " (ruler/governance changed)"
		out.append(line)
	return out


## Latest tick of an [enum Kind.ANIMAL_DEATH] in [param rk] for [param species] (Animal enum), or -1.
func get_last_animal_death_tick_in_region(rk: int, species: int) -> int:
	var best: int = -1
	for e in _events:
		if int(e.get("k", -1)) != int(Kind.ANIMAL_DEATH):
			continue
		if int(e.get("r", 0)) != rk:
			continue
		if int(e.get("sp", -1)) != species:
			continue
		best = maxi(best, int(e.get("t", 0)))
	return best


## Count of [enum Kind.ANIMAL_DEATH] in [param rk] for [param species] (read-only; for derived population v1).
func get_animal_death_count_in_region(rk: int, species: int) -> int:
	var n: int = 0
	for e in _events:
		if int(e.get("k", -1)) != int(Kind.ANIMAL_DEATH):
			continue
		if int(e.get("r", 0)) != rk:
			continue
		if int(e.get("sp", -1)) != species:
			continue
		n += 1
	return n


## Latest [enum Kind.PAWN_DEATH] tick in any of the given 16x16 [param regions], or -1.
func get_last_pawn_death_tick_in_regions(regions: PackedInt32Array) -> int:
	if regions.is_empty():
		return -1
	var want: Dictionary = {}
	for j in range(regions.size()):
		want[int(regions[j])] = true
	var best: int = -1
	for e in _events:
		if int(e.get("k", -1)) != int(Kind.PAWN_DEATH):
			continue
		var rk: int = int(e.get("r", 0))
		if not want.has(rk):
			continue
		best = maxi(best, int(e.get("t", 0)))
	return best


## Region keys (16x16) that have at least one animal death event, sorted ascending (deterministic).
func get_region_keys_with_animal_deaths() -> Array[int]:
	var seen: Dictionary = {}
	for e in _events:
		if int(e.get("k", -1)) != int(Kind.ANIMAL_DEATH):
			continue
		seen[int(e.get("r", 0))] = true
	var out: Array[int] = []
	for rr in seen:
		out.append(int(rr))
	out.sort()
	return out


func _provenance_hash_stub(evt: Dictionary) -> String:
	var payload: String = "%s|%s|%s|%s|%s|%s|%s" % [
		str(evt.get("t", 0)),
		str(evt.get("type", "unknown")),
		str(evt.get("pawn_id", evt.get("pid", "n/a"))),
		str(evt.get("action", evt.get("c", evt.get("reason", "")))),
		str(evt.get("amount", evt.get("total_xp", evt.get("sp", 0)))),
		str(evt.get("r", "n/a")),
		str(evt.get("s", SCHEMA)),
	]
	var h: int = abs(payload.hash())
	return "h%08x" % h


## Read-only deterministic export snapshot (no file IO).
func get_history_export_string() -> String:
	var out: PackedStringArray = []
	out.append("HEELKAWN HISTORY EXPORT - KERNEL v0.7.1")
	out.append("TICK_RANGE: 0 to %d" % GameManager.tick_count)
	out.append("EVENT_COUNT: %d" % _events.size())
	out.append("FORMAT: [tick] type | subject | cause | impact | provenance_hash")
	out.append("==============================================================")
	for evt in _events:
		var tick: int = int(evt.get("t", 0))
		var type_name: String = str(evt.get("type", "unknown"))
		if type_name == "unknown":
			var k: int = int(evt.get("k", -1))
			if k == int(Kind.PAWN_DEATH):
				type_name = "pawn_death"
			elif k == int(Kind.ANIMAL_DEATH):
				type_name = "animal_death"
		var subject: String = str(evt.get("pawn_id", evt.get("pid", evt.get("sp", "n/a"))))
		var cause: String = str(evt.get("cause", evt.get("action", evt.get("c", evt.get("reason", "n/a")))))
		var impact: String = str(evt.get("impact", evt.get("amount", evt.get("total_xp", evt.get("executed", "n/a")))))
		out.append("[T:%d] %s | SUB:%s | CAUSE:%s | IMP:%s | PROV:%s" % [
			tick, type_name, subject, cause, impact, _provenance_hash_stub(evt),
		])
	return "\n".join(out)


func get_events_for_tile(target_pos: Vector2i) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for evt in _events:
		var matched: bool = false
		# Compact typed events store x/y.
		if evt.has("x") and evt.has("y"):
			if int(evt.get("x", -999999)) == target_pos.x and int(evt.get("y", -999999)) == target_pos.y:
				matched = true
		# Generic events may store pos as Dictionary {x,y} or Vector2i.
		elif evt.has("pos"):
			var pv: Variant = evt.get("pos", null)
			if pv is Dictionary:
				var pd: Dictionary = pv as Dictionary
				if int(pd.get("x", -999999)) == target_pos.x and int(pd.get("y", -999999)) == target_pos.y:
					matched = true
			elif pv is Vector2i:
				if (pv as Vector2i) == target_pos:
					matched = true
		if matched:
			results.append(evt.duplicate(true))
	results.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("t", 0)) < int(b.get("t", 0))
	)
	return results
