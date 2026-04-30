extends Node
## Deterministic append-only world fact log (Phase 2.1). No RNG; no UI.
## Events are plain Dictionaries for trivial save/load via Main snapshot.
## Connected to HeelKawn Universe Neural Network Matrix

const SCHEMA: int = 1
## Text/history export line format; bump when column order or provenance rules change.
const HISTORY_EXPORT_FORMAT: String = "1.0.0"
## Keep a long chronology by default; older entries rotate out only after this cap.
const MAX_EVENTS: int = 50000

enum Kind {
	PAWN_DEATH = 0,
	ANIMAL_DEATH = 1,
	ENEMY_DEATH = 2,
	SOCIAL_FRAGMENT = 3,
	SOCIAL_SCHISM = 4,
	BUILDING_CONSTRUCTED = 5,
	BUILDING_DESTROYED = 6,
	FIRE_STARTED = 7,
	FIRE_EXTINGUISHED = 8,
	STARVATION_EVENT = 9,
	MIGRATION_STARTED = 10,
	MIGRATION_COMPLETED = 11,
	TEACHING_EVENT = 12,
}

var _events: Array[Dictionary] = []
var _dirty: bool = false
## event_type -> first tick observed in this session/save timeline.
var _first_event_tick_by_type: Dictionary = {}
## event_type -> total retained events (O(1) counters for large timelines).
var _event_type_counts: Dictionary = {}
## Monotonic event id (stable cursor for paging/query surfaces).
var _next_event_id: int = 1

# === Neural Network Matrix Connections ===

func get_world_stability() -> float:
	# Dynamic neural network matrix calculation of world stability
	var base_stability: float = 0.7
	var death_count: int = 0
	var conflict_count: int = 0
	var disaster_count: int = 0
	
	# Analyze recent events for stability factors
	for i in range(max(0, _events.size() - 100), _events.size()):
		var event: Dictionary = _events[i]
		var event_type: String = event.get("type", "")
		
		match event_type:
			"death":
				death_count += 1
			"conflict":
				conflict_count += 1
			"disaster":
				disaster_count += 1
	
	# Calculate stability modifiers
	var death_penalty: float = min(death_count / 50.0, 0.3)
	var conflict_penalty: float = min(conflict_count / 20.0, 0.2)
	var disaster_penalty: float = min(disaster_count / 10.0, 0.2)
	
	var final_stability: float = base_stability - death_penalty - conflict_penalty - disaster_penalty
	return max(0.1, final_stability)

func get_cultural_event_count() -> int:
	# Count cultural events in neural network matrix
	var cultural_count: int = 0
	for event in _events:
		var event_type: String = event.get("type", "")
		if event_type in ["cultural", "religious", "artistic", "diplomatic"]:
			cultural_count += 1
	return cultural_count

func store_forage_data(x: int, y: int, amount: int, signature: String) -> void:
	# Store forage data in neural network matrix
	var forage_data: Dictionary = {
		"location": Vector2i(x, y),
		"amount": amount,
		"signature": signature,
		"tick": GameManager.tick_count
	}
	
	if not has_meta("forage_matrix"):
		set_meta("forage_matrix", [])
	
	var forage_matrix: Array = get_meta("forage_matrix")
	forage_matrix.append(forage_data)
	
	# Limit matrix size
	if forage_matrix.size() > 1000:
		forage_matrix.pop_front()

func consume_forage(x: int, y: int, amount: int, impact: float, delay: int) -> void:
	# Record forage consumption in neural network matrix
	var consumption_data: Dictionary = {
		"location": Vector2i(x, y),
		"amount": amount,
		"impact": impact,
		"regeneration_delay": delay,
		"tick": GameManager.tick_count,
		"neural_signature": "NM_CONSUME_%08X" % [x * 1000 + y + GameManager.tick_count]
	}
	
	if not has_meta("consumption_matrix"):
		set_meta("consumption_matrix", [])
	
	var consumption_matrix: Array = get_meta("consumption_matrix")
	consumption_matrix.append(consumption_data)
	
	# Limit matrix size
	if consumption_matrix.size() > 500:
		consumption_matrix.pop_front()

func record_ecosystem_event(data: Dictionary) -> void:
	# Record ecosystem events in neural network matrix
	if not has_meta("ecosystem_matrix"):
		set_meta("ecosystem_matrix", [])
	
	var ecosystem_matrix: Array = get_meta("ecosystem_matrix")
	ecosystem_matrix.append(data)
	
	# Limit matrix size
	if ecosystem_matrix.size() > 200:
		ecosystem_matrix.pop_front()

func get_resource_at_tile(tile_pos: Vector2i) -> Dictionary:
	# Get resource data from neural network matrix
	if not has_meta("resource_matrix"):
		return {}
	
	var resource_matrix: Array = get_meta("resource_matrix")
	for resource_data in resource_matrix:
		var location: Vector2i = resource_data.get("location", Vector2i(-1, -1))
		if location == tile_pos:
			return resource_data
	
	return {}


func clear() -> void:
	_events.clear()
	_first_event_tick_by_type.clear()
	_event_type_counts.clear()
	_next_event_id = 1
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
		var dropped: Dictionary = _events[0]
		_events.remove_at(0)
		_on_event_removed_from_indexes(dropped)
	_events.append(e)
	_on_event_added_to_indexes(e)


func _on_event_added_to_indexes(evt: Dictionary) -> void:
	var typ: String = _canonical_event_type(evt)
	_event_type_counts[typ] = int(_event_type_counts.get(typ, 0)) + 1
	var tick: int = int(evt.get("t", 0))
	if not _first_event_tick_by_type.has(typ):
		_first_event_tick_by_type[typ] = tick


func _on_event_removed_from_indexes(evt: Dictionary) -> void:
	var typ: String = _canonical_event_type(evt)
	var next_count: int = maxi(0, int(_event_type_counts.get(typ, 1)) - 1)
	if next_count <= 0:
		_event_type_counts.erase(typ)
		_first_event_tick_by_type.erase(typ)
		return
	_event_type_counts[typ] = next_count
	if not _first_event_tick_by_type.has(typ):
		return
	var dropped_tick: int = int(evt.get("t", 0))
	if int(_first_event_tick_by_type.get(typ, dropped_tick)) != dropped_tick:
		return
	_recompute_first_tick_for_type(typ)


func _recompute_first_tick_for_type(typ: String) -> void:
	var best: int = -1
	for evt in _events:
		if _canonical_event_type(evt) != typ:
			continue
		var tick: int = int(evt.get("t", 0))
		if best < 0 or tick < best:
			best = tick
	if best < 0:
		_first_event_tick_by_type.erase(typ)
	else:
		_first_event_tick_by_type[typ] = best


## Generic deterministic event appender for non-core typed events (e.g. player input).
func record_event(e: Dictionary) -> void:
	var payload: Dictionary = _normalize_event_payload(e)
	_append(payload)


func _normalize_event_payload(e: Dictionary) -> Dictionary:
	var payload: Dictionary = e.duplicate(true)
	payload["eid"] = _next_event_id
	_next_event_id += 1
	payload["s"] = SCHEMA
	if not payload.has("t"):
		payload["t"] = GameManager.tick_count
	var typ: String = _canonical_event_type(payload)
	payload["type"] = typ
	var sev: int = _severity_for_type(typ)
	payload["severity"] = sev
	var rr: int = _region_from_event_payload(payload)
	if rr >= 0:
		payload["r"] = rr
	var first_tick: int = int(payload.get("t", 0))
	if not _first_event_tick_by_type.has(typ):
		_first_event_tick_by_type[typ] = first_tick
		payload["first_of_type"] = true
	return payload


func _canonical_event_type(payload: Dictionary) -> String:
	var typ: String = str(payload.get("type", "")).strip_edges()
	if not typ.is_empty():
		return typ
	var k: int = int(payload.get("k", -1))
	match k:
		int(Kind.PAWN_DEATH):
			return "pawn_death"
		int(Kind.ANIMAL_DEATH):
			return "animal_death"
		int(Kind.ENEMY_DEATH):
			return "enemy_death"
		int(Kind.SOCIAL_FRAGMENT):
			return "social_fragment"
		int(Kind.SOCIAL_SCHISM):
			return "social_schism"
		int(Kind.BUILDING_CONSTRUCTED):
			return "building_constructed"
		int(Kind.BUILDING_DESTROYED):
			return "building_destroyed"
		int(Kind.FIRE_STARTED):
			return "fire_started"
		int(Kind.FIRE_EXTINGUISHED):
			return "fire_extinguished"
		int(Kind.STARVATION_EVENT):
			return "starvation_event"
		int(Kind.MIGRATION_STARTED):
			return "migration_started"
		int(Kind.MIGRATION_COMPLETED):
			return "migration_completed"
		int(Kind.TEACHING_EVENT):
			return "teaching_event"
	return "event"


func _severity_for_type(typ: String) -> int:
	match typ:
		"pawn_death", "knowledge_loss", "social_schism", "starvation_event", "fire_started":
			return 3
		"enemy_death", "war_proposed", "war_battle_spawned", "governance_change", "birth", "pawn_birth", "building_destroyed":
			return 2
		"social_bond_milestone", "social_meeting", "structure_built", "job_completed", "knowledge_discovery", "knowledge_rediscovery", "teaching_success", "settlement_intent_shift", "building_constructed", "fire_extinguished", "migration_started", "migration_completed", "teaching_event":
			return 1
		_:
			return 0


func _region_from_event_payload(payload: Dictionary) -> int:
	if payload.has("r"):
		return int(payload.get("r", -1))
	if payload.has("region"):
		return int(payload.get("region", -1))
	if payload.has("x") and payload.has("y"):
		return _region_key(int(payload.get("x", -1)), int(payload.get("y", -1)))
	var tile_v: Variant = payload.get("tile", null)
	if tile_v is Dictionary:
		var td: Dictionary = tile_v as Dictionary
		if td.has("x") and td.has("y"):
			return _region_key(int(td.get("x", -1)), int(td.get("y", -1)))
	var pos_v: Variant = payload.get("pos", null)
	if pos_v is Dictionary:
		var pd: Dictionary = pos_v as Dictionary
		if pd.has("x") and pd.has("y"):
			return _region_key(int(pd.get("x", -1)), int(pd.get("y", -1)))
	elif pos_v is Vector2i:
		var p: Vector2i = pos_v as Vector2i
		return _region_key(p.x, p.y)
	return -1


## Record after `data` is still valid; use primitive fields only.
func record_pawn_death(
		tick: int,
		tile: Vector2i,
		pawn_id: int,
		pawn_name: String,
		cause: String,
		prof_at_death: int = -1,
		parent_a_snapshot: int = -1,
		parent_b_snapshot: int = -1
	) -> void:
	var e: Dictionary = {
		"s": SCHEMA,
		"k": int(Kind.PAWN_DEATH),
		"t": tick,
		"x": tile.x,
		"y": tile.y,
		"r": WorldMemory._region_key(tile.x, tile.y),
		"pid": pawn_id,
		"n": pawn_name,
		"c": cause,
	}
	if prof_at_death >= 0:
		e["prof"] = prof_at_death
	if parent_a_snapshot >= 0:
		e["pa"] = parent_a_snapshot
	if parent_b_snapshot >= 0:
		e["pb"] = parent_b_snapshot
	_append(e)


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
		"r": WorldMemory._region_key(tile.x, tile.y),
		"enemy": enemy_name,
		"attacker": attacker_name,
		"kill_count": total_kills,
	})


## Deterministic social relocation (fragment / schism); [param regions] is the source cluster pack.
func record_social(
		tick: int,
		kind: int,
		center_rk: int,
		target_tile: Vector2i,
		moved_count: int,
		regions: PackedInt32Array
	) -> void:
	var reg_copy: PackedInt32Array = regions.duplicate()
	_append({
		"s": SCHEMA,
		"k": kind,
		"t": tick,
		"ckr": center_rk,
		"x": target_tile.x,
		"y": target_tile.y,
		"r": WorldMemory._region_key(target_tile.x, target_tile.y),
		"mv": moved_count,
		"rp": reg_copy,
	})


## Record building construction
func record_building_constructed(
		tick: int,
		tile: Vector2i,
		building_type: String,
		builder_id: int = -1,
		settlement_id: int = -1
	) -> void:
	var e: Dictionary = {
		"s": SCHEMA,
		"k": int(Kind.BUILDING_CONSTRUCTED),
		"t": tick,
		"x": tile.x,
		"y": tile.y,
		"r": WorldMemory._region_key(tile.x, tile.y),
		"building_type": building_type,
	}
	if builder_id >= 0:
		e["builder_id"] = builder_id
	if settlement_id >= 0:
		e["settlement_id"] = settlement_id
	_append(e)


## Record building destruction
func record_building_destroyed(
		tick: int,
		tile: Vector2i,
		building_type: String,
		cause: String = "unknown",
		settlement_id: int = -1
	) -> void:
	var e: Dictionary = {
		"s": SCHEMA,
		"k": int(Kind.BUILDING_DESTROYED),
		"t": tick,
		"x": tile.x,
		"y": tile.y,
		"r": WorldMemory._region_key(tile.x, tile.y),
		"building_type": building_type,
		"cause": cause,
	}
	if settlement_id >= 0:
		e["settlement_id"] = settlement_id
	_append(e)


## Record fire started
func record_fire_started(
		tick: int,
		tile: Vector2i,
		cause: String = "unknown",
		settlement_id: int = -1
	) -> void:
	var e: Dictionary = {
		"s": SCHEMA,
		"k": int(Kind.FIRE_STARTED),
		"t": tick,
		"x": tile.x,
		"y": tile.y,
		"r": WorldMemory._region_key(tile.x, tile.y),
		"cause": cause,
	}
	if settlement_id >= 0:
		e["settlement_id"] = settlement_id
	_append(e)


## Record fire extinguished
func record_fire_extinguished(
		tick: int,
		tile: Vector2i,
		duration_ticks: int = 0,
		settlement_id: int = -1
	) -> void:
	var e: Dictionary = {
		"s": SCHEMA,
		"k": int(Kind.FIRE_EXTINGUISHED),
		"t": tick,
		"x": tile.x,
		"y": tile.y,
		"r": WorldMemory._region_key(tile.x, tile.y),
		"duration": duration_ticks,
	}
	if settlement_id >= 0:
		e["settlement_id"] = settlement_id
	_append(e)


## Record starvation event
func record_starvation_event(
		tick: int,
		tile: Vector2i,
		pawn_id: int,
		pawn_name: String,
		severity: String = "moderate",
		settlement_id: int = -1
	) -> void:
	var e: Dictionary = {
		"s": SCHEMA,
		"k": int(Kind.STARVATION_EVENT),
		"t": tick,
		"x": tile.x,
		"y": tile.y,
		"r": WorldMemory._region_key(tile.x, tile.y),
		"pawn_id": pawn_id,
		"pawn_name": pawn_name,
		"severity": severity,
	}
	if settlement_id >= 0:
		e["settlement_id"] = settlement_id
	_append(e)


## Record migration started
func record_migration_started(
		tick: int,
		from_region: int,
		to_region: int,
		migrant_count: int,
		reason: String = "unknown"
	) -> void:
	_append({
		"s": SCHEMA,
		"k": int(Kind.MIGRATION_STARTED),
		"t": tick,
		"from_region": from_region,
		"to_region": to_region,
		"migrant_count": migrant_count,
		"reason": reason,
	})


## Record migration completed
func record_migration_completed(
		tick: int,
		from_region: int,
		to_region: int,
		migrant_count: int,
		successful: bool = true
	) -> void:
	_append({
		"s": SCHEMA,
		"k": int(Kind.MIGRATION_COMPLETED),
		"t": tick,
		"from_region": from_region,
		"to_region": to_region,
		"migrant_count": migrant_count,
		"successful": successful,
	})


## Record teaching event
func record_teaching_event(
		tick: int,
		tile: Vector2i,
		teacher_id: int,
		teacher_name: String,
		student_id: int,
		student_name: String,
		skill_taught: String,
		settlement_id: int = -1
	) -> void:
	var e: Dictionary = {
		"s": SCHEMA,
		"k": int(Kind.TEACHING_EVENT),
		"t": tick,
		"x": tile.x,
		"y": tile.y,
		"r": WorldMemory._region_key(tile.x, tile.y),
		"teacher_id": teacher_id,
		"teacher_name": teacher_name,
		"student_id": student_id,
		"student_name": student_name,
		"skill": skill_taught,
	}
	if settlement_id >= 0:
		e["settlement_id"] = settlement_id
	_append(e)


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
	var max_eid: int = 0
	if ev is Array:
		for e in ev:
			if e is Dictionary:
				var copy: Dictionary = (e as Dictionary).duplicate(true)
				if not copy.has("eid"):
					copy["eid"] = _next_event_id
					_next_event_id += 1
				max_eid = maxi(max_eid, int(copy.get("eid", 0)))
				_events.append(copy)
	if max_eid > 0:
		_next_event_id = max_eid + 1
	_rebuild_first_event_index()


func _rebuild_first_event_index() -> void:
	_first_event_tick_by_type.clear()
	_event_type_counts.clear()
	for evt in _events:
		var typ: String = _canonical_event_type(evt)
		var tick: int = int(evt.get("t", 0))
		_event_type_counts[typ] = int(_event_type_counts.get(typ, 0)) + 1
		if not _first_event_tick_by_type.has(typ):
			_first_event_tick_by_type[typ] = tick


func event_count() -> int:
	return _events.size()


## Last `count` events in append order (oldest first, newest last). Read-only; for soul-bundle / AI handoff.
func get_recent_events(count: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if count <= 0:
		return out
	var n: int = mini(count, _events.size())
	var start: int = _events.size() - n
	for i in range(start, _events.size()):
		var ev_any: Variant = _events[i]
		if not ev_any is Dictionary:
			continue
		out.append((ev_any as Dictionary).duplicate(true))
	return out


func get_recent_event_summaries(max_items: int = 3) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if max_items <= 0 or _events.is_empty():
		return out
	var start: int = maxi(0, _events.size() - max_items)
	for i in range(_events.size() - 1, start - 1, -1):
		var evt_any: Variant = _events[i]
		if not evt_any is Dictionary:
			continue
		var evt: Dictionary = evt_any as Dictionary
		var kind: String = str(evt.get("type", ""))
		if kind == "":
			var k: int = int(evt.get("k", -1))
			if k == int(Kind.PAWN_DEATH):
				kind = "pawn_death"
			elif k == int(Kind.ANIMAL_DEATH):
				kind = "animal_death"
			elif k == int(Kind.ENEMY_DEATH):
				kind = "enemy_death"
			elif k == int(Kind.SOCIAL_FRAGMENT):
				kind = "social_fragment"
			elif k == int(Kind.SOCIAL_SCHISM):
				kind = "social_schism"
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


## One pass over [member _events] for [enum Kind.ANIMAL_DEATH] only. Key format matches [code]AnimalSpawner._rsk[/code] ([code]"rk#species"[/code]).
## Use from hot paths (e.g. [method AnimalSpawner.update_population_dynamics]) instead of many calls to
## [method get_animal_death_count_in_region] / [method get_last_animal_death_tick_in_region] (each O(n) over all events).
func get_animal_death_ledger() -> Dictionary:
	var out: Dictionary = {}
	for e in _events:
		if int(e.get("k", -1)) != int(Kind.ANIMAL_DEATH):
			continue
		var rk: int = int(e.get("r", 0))
		var sp: int = int(e.get("sp", -1))
		var key: String = "%d#%d" % [rk, sp]
		var tt: int = int(e.get("t", 0))
		if not out.has(key):
			out[key] = {"count": 1, "last_t": tt}
		else:
			var rec: Dictionary = out[key]
			rec["count"] = int(rec["count"]) + 1
			rec["last_t"] = maxi(int(rec["last_t"]), tt)
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


func _export_subject_redacted(subject: Variant, anonymize: bool) -> String:
	var s: String = str(subject)
	if not anonymize:
		return s
	var st: String = s.strip_edges()
	if st.is_valid_int():
		var vi: int = int(st)
		return "anon_%08x" % (abs(vi * 486187739) & 0xFFFFFFFF)
	return s


## Read-only deterministic export snapshot (no file IO).
## Pass [code]anonymize_subjects[/code] for pvabazaar-style sharing (numeric ids hashed in SUB column).
func get_history_export_string(anonymize_subjects: bool = false) -> String:
	var out: PackedStringArray = []
	out.append("HEELKAWN_HISTORY_EXPORT v=%s schema=%d" % [HISTORY_EXPORT_FORMAT, SCHEMA])
	out.append(
		"EXPORT_MODE: %s" % ("public_redacted" if anonymize_subjects else "private_dev")
	)
	out.append("TICKS_PER_SIM_YEAR: %d" % SimTime.TICKS_PER_SIM_YEAR)
	out.append("TICK_RANGE: 0 to %d" % GameManager.tick_count)
	out.append("EVENT_COUNT: %d" % _events.size())
	out.append("COLUMNS: tick | type | subject | cause | impact | provenance_hash")
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
			elif k == int(Kind.SOCIAL_FRAGMENT):
				type_name = "social_fragment"
			elif k == int(Kind.SOCIAL_SCHISM):
				type_name = "social_schism"
		var subject: String = _export_subject_redacted(
			evt.get("pawn_id", evt.get("pid", evt.get("sp", "n/a"))),
			anonymize_subjects
		)
		var cause: String = str(evt.get("cause", evt.get("action", evt.get("c", evt.get("reason", "n/a")))))
		var impact: String = str(evt.get("impact", evt.get("amount", evt.get("total_xp", evt.get("executed", "n/a")))))
		out.append("[T:%d] %s | SUB:%s | CAUSE:%s | IMP:%s | PROV:%s" % [
			tick, type_name, subject, cause, impact, _provenance_hash_stub(evt),
		])
	return "\n".join(out)


## Impact buckets for [param zone_id] (center region id as decimal string). Uses [SettlementMemory] region packs when present.
## Latest pawn-death event for [param pawn_id], or empty dict (newest matching record).
func pawn_death_fact(pawn_id: int) -> Dictionary:
	if pawn_id < 0:
		return {}
	for i in range(_events.size() - 1, -1, -1):
		var e: Dictionary = _events[i]
		if int(e.get("k", -1)) != int(Kind.PAWN_DEATH):
			continue
		if int(e.get("pid", -1)) != pawn_id:
			continue
		return e.duplicate(true)
	return {}


## Last recorded name for a pawn id from a pawn death fact, or empty.
func last_known_name_from_death_record(pawn_id: int) -> String:
	return str(pawn_death_fact(pawn_id).get("n", ""))


func get_zone_aggregate(zone_id: String) -> Dictionary:
	var empty: Dictionary = {
		"builds": 0,
		"monuments": 0,
		"trade_routes": 0,
		"death_clusters": 0,
		"biome_exhaustion": 0,
	}
	if zone_id.is_empty() or not zone_id.is_valid_int():
		return empty
	var ckr: int = int(zone_id)
	var want: Dictionary = {}
	for s in SettlementMemory.settlements:
		if s is not Dictionary:
			continue
		var d: Dictionary = s
		if int(d.get("center_region", -2)) != ckr:
			continue
		var regv: Variant = d.get("regions", null)
		if regv is PackedInt32Array:
			var pack: PackedInt32Array = regv as PackedInt32Array
			for j in range(pack.size()):
				want[int(pack[j])] = true
		break
	if want.is_empty():
		want[ckr] = true
	var deaths: int = 0
	var governance_events: int = 0
	var intent_shifts: int = 0
	for e in _events:
		var k: int = int(e.get("k", -1))
		if k == int(Kind.PAWN_DEATH):
			var rr: int = int(e.get("r", -1))
			if want.has(rr):
				deaths += 1
			continue
		var typ: String = str(e.get("type", ""))
		if typ == "governance_change" and int(e.get("settlement_id", -2)) == ckr:
			governance_events += 1
		elif typ == "settlement_intent_shift" and int(e.get("settlement_id", -2)) == ckr:
			intent_shifts += 1
	# Lightweight proxies for revival scoring (deterministic, no RNG).
	return {
		"builds": mini(8, governance_events / 4),
		"monuments": mini(6, intent_shifts / 6),
		"trade_routes": 0,
		"death_clusters": deaths,
		"biome_exhaustion": 0,
	}


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


func get_first_event_tick(event_type: String) -> int:
	var key: String = event_type.strip_edges()
	if key.is_empty():
		return -1
	return int(_first_event_tick_by_type.get(key, -1))


func get_event_type_counts() -> Dictionary:
	return _event_type_counts.duplicate(true)


## Recent events scoped to a settlement center region (optionally includes all packed settlement regions).
func get_recent_events_for_settlement(center_region: int, max_items: int = 64, include_settlement_regions: bool = true) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if center_region < 0 or max_items <= 0:
		return out
	var wanted: Dictionary = {center_region: true}
	if include_settlement_regions:
		for s_any in SettlementMemory.settlements:
			if s_any is not Dictionary:
				continue
			var st: Dictionary = s_any as Dictionary
			if int(st.get("center_region", -1)) != center_region:
				continue
			var reg_v: Variant = st.get("regions", PackedInt32Array())
			if reg_v is PackedInt32Array:
				for rk in reg_v as PackedInt32Array:
					wanted[int(rk)] = true
			break
	for i in range(_events.size() - 1, -1, -1):
		if out.size() >= max_items:
			break
		var evt_any: Variant = _events[i]
		if not evt_any is Dictionary:
			continue
		var evt: Dictionary = evt_any as Dictionary
		var rk: int = _region_from_event_payload(evt)
		if rk < 0:
			continue
		if not wanted.has(rk):
			continue
		out.append(evt.duplicate(true))
	out.reverse()
	return out


## Cursor-like page from newest to oldest. Pass before_eid to continue pagination.
func get_events_page_newest(max_items: int = 100, before_eid: int = -1) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if max_items <= 0:
		return out
	for i in range(_events.size() - 1, -1, -1):
		if out.size() >= max_items:
			break
		var evt_any: Variant = _events[i]
		if not evt_any is Dictionary:
			continue
		var evt: Dictionary = evt_any as Dictionary
		var eid: int = int(evt.get("eid", 0))
		if before_eid > 0 and eid >= before_eid:
			continue
		out.append(evt.duplicate(true))
	return out


## Recent events involving a specific pawn id. Matches direct subject keys and
## pair/family fields where present.
func get_recent_events_for_pawn(pawn_id: int, max_items: int = 64) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if pawn_id < 0 or max_items <= 0:
		return out
	for i in range(_events.size() - 1, -1, -1):
		if out.size() >= max_items:
			break
		var evt_any: Variant = _events[i]
		if not evt_any is Dictionary:
			continue
		var evt: Dictionary = evt_any as Dictionary
		var hit: bool = false
		if int(evt.get("pawn_id", -1)) == pawn_id:
			hit = true
		elif int(evt.get("pid", -1)) == pawn_id:
			hit = true
		elif int(evt.get("a", -1)) == pawn_id or int(evt.get("b", -1)) == pawn_id:
			hit = true
		elif int(evt.get("parent_a_id", -1)) == pawn_id or int(evt.get("parent_b_id", -1)) == pawn_id:
			hit = true
		if not hit:
			continue
		out.append(evt.duplicate(true))
	out.reverse()
	return out


## Focused relationship timeline between two pawns (meetings, bond milestones,
## and shared family records) in append order.
func get_relationship_timeline(a_id: int, b_id: int, max_items: int = 64) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if a_id < 0 or b_id < 0 or max_items <= 0:
		return out
	var lo: int = mini(a_id, b_id)
	var hi: int = maxi(a_id, b_id)
	for i in range(_events.size() - 1, -1, -1):
		if out.size() >= max_items:
			break
		var evt_any: Variant = _events[i]
		if not evt_any is Dictionary:
			continue
		var evt: Dictionary = evt_any as Dictionary
		var typ: String = _canonical_event_type(evt)
		var include: bool = false
		if typ == "social_meeting" or typ == "social_bond_milestone":
			var ea: int = int(evt.get("a", -1))
			var eb: int = int(evt.get("b", -1))
			include = mini(ea, eb) == lo and maxi(ea, eb) == hi
		elif typ == "birth" or typ == "pawn_birth":
			var pa: int = int(evt.get("parent_a_id", -1))
			var pb: int = int(evt.get("parent_b_id", -1))
			include = mini(pa, pb) == lo and maxi(pa, pb) == hi
		if not include:
			continue
		out.append(evt.duplicate(true))
	out.reverse()
	return out
