extends Node
## Deterministic append-only world fact log (Phase 2.1). No RNG; no UI.
## Events are plain Dictionaries for trivial save/load via Main snapshot.

const SCHEMA: int = 1
const MAX_EVENTS: int = 5000

enum Kind { PAWN_DEATH = 0, ANIMAL_DEATH = 1 }

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


func _region_key(tx: int, ty: int) -> int:
	var rx: int = int(tx) >> 4
	var ry: int = int(ty) >> 4
	return (rx & 0xFFFF) | ((ry & 0xFFFF) << 16)


func _append(e: Dictionary) -> void:
	_dirty = true
	if _events.size() >= MAX_EVENTS:
		_events.remove_at(0)
	_events.append(e)


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
		"r": WorldMemory._region_key(tile.x, tile.y),
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
		"r": WorldMemory._region_key(tile.x, tile.y),
		"sp": species,
		"sn": species_name,
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
