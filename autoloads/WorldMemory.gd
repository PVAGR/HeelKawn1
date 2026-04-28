extends Node
## Deterministic append-only world fact log (Phase 2.1). No RNG; no UI.
## Events are plain Dictionaries for trivial save/load via Main snapshot.
## Connected to HeelKawn Universe Neural Network Matrix

const SCHEMA: int = 1
## Text/history export line format; bump when column order or provenance rules change.
const HISTORY_EXPORT_FORMAT: String = "1.0.0"
const MAX_EVENTS: int = 5000

enum Kind {
	PAWN_DEATH = 0,
	ANIMAL_DEATH = 1,
	ENEMY_DEATH = 2,
	SOCIAL_FRAGMENT = 3,
	SOCIAL_SCHISM = 4,
}

var _events: Array[Dictionary] = []
var _dirty: bool = false

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


## Last `count` events in append order (oldest first, newest last). Read-only; for soul-bundle / AI handoff.
func get_recent_events(count: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if count <= 0:
		return out
	var n: int = mini(count, _events.size())
	var start: int = _events.size() - n
	for i in range(start, _events.size()):
		out.append((_events[i] as Dictionary).duplicate(true))
	return out


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
