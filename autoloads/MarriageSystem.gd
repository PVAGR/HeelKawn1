extends Node
## MarriageSystem — marriage contracts, family alliances, inheritance.
##
## Full marriage lifecycle: initiation, active maintenance, separation/
## divorce/widowhood, and remarriage. Creates deterministic alliances
## between households; handles inheritance transfer on pawn death.
## Integrates with SocialDynamics, EventBus, WorldMemory.
## All randomness uses only WorldRNG.stream_seed.

const MARRIAGE_CHECK_INTERVAL: int = 2000
const MIN_MARRIAGE_AGE: int = 16
const MIN_FRIENDSHIP_FOR_MARRIAGE: float = 0.5
const MIN_ROMANCE_FOR_MARRIAGE: float = 0.5
const ROMANCE_BIND_VALUE: float = 0.8
const FRIENDSHIP_BIND_VALUE: float = 0.5
const SEPARATION_THRESHOLD_TICKS: int = 30000
const DIVORCE_RIVALRY_THRESHOLD: float = 0.6
const WIDOW_REMARRIAGE_COOLDOWN_TICKS: int = 15000
const ALLIANCE_BREAK_ON_DIVORCE: bool = true
const INHERITANCE_SPOUSE_FRACTION: float = 0.5
const INHERITANCE_CHILD_FRACTION: float = 0.3
const INHERITANCE_SELF_FRACTION: float = 0.2
const MATCHMAKING_MAX_AGE: int = 80
const MATCHMAKING_AGE_GAP_MAX: int = 30
const MAX_MATCHMAKING_CANDIDATES: int = 6
const MAX_DOWRY_ITEMS: int = 8
const HISTORY_MAX_SIZE: int = 24

const S_ACTIVE: String = "active"
const S_SEPARATED: String = "separated"
const S_DIVORCED: String = "divorced"
const S_WIDOWED: String = "widowed"

signal marriage_contracted(
	pawn_a: int, pawn_b: int,
	settlement_a: int, settlement_b: int,
	tick: int, dowry_value: float
)
signal marriage_ended(pawn_a: int, pawn_b: int, reason: String, tick: int)
signal child_born(pawn_a: int, pawn_b: int, child_id: int, tick: int)
signal inheritance_transferred(
	deceased_id: int, spouse_id: int,
	child_ids: Array, tick: int
)
signal alliance_formed_between_houses(
	settlement_a: int, settlement_b: int,
	pawn_a: int, pawn_b: int, tick: int
)
signal alliance_broken_between_houses(
	settlement_a: int, settlement_b: int,
	reason: String, tick: int
)
signal matchmaking_attempted(
	pawn_id: int, candidate_id: int,
	match_score: float, tick: int
)

var _marriages: Array[Dictionary] = []
var _alliances: Dictionary = {}
var _widow_cooldowns: Dictionary = {}
var _last_check_tick: int = -999999
var _tick_cache: int = 0
var _history_log: Array[Dictionary] = []


func _ready() -> void:
	if GameManager != null:
		GameManager.game_tick.connect(_on_game_tick)
	if EventBus != null:
		EventBus.subscribe(EventBus.EVENT_PAWN_DIED, self, "_on_pawn_death_event")
		EventBus.subscribe(EventBus.EVENT_PAWN_BORN, self, "_on_pawn_born_event")
		EventBus.subscribe(EventBus.EVENT_RELATIONSHIP_CHANGED, self, "_on_relationship_changed")


func _exit_tree() -> void:
	if GameManager != null and GameManager.game_tick.is_connected(_on_game_tick):
		GameManager.game_tick.disconnect(_on_game_tick)
	if EventBus != null:
		EventBus.unsubscribe(EventBus.EVENT_PAWN_DIED, self, "_on_pawn_death_event")
		EventBus.unsubscribe(EventBus.EVENT_PAWN_BORN, self, "_on_pawn_born_event")
		EventBus.unsubscribe(EventBus.EVENT_RELATIONSHIP_CHANGED, self, "_on_relationship_changed")


func _on_game_tick(tick: int) -> void:
	if tick - _last_check_tick < MARRIAGE_CHECK_INTERVAL:
		return
	_last_check_tick = tick
	_tick_cache = tick
	_process_marriage_health(tick)
	_process_matchmaking(tick)
	_process_widow_remarriage(tick)
	_prune_stale_history(tick)


func arrange_marriage(
	pawn_a: int, pawn_b: int,
	settlement_a: int, settlement_b: int,
	tick: int,
	dowry: Dictionary = {}
) -> bool:
	if pawn_a < 0 or pawn_b < 0 or pawn_a == pawn_b:
		return false
	if not _can_pawns_marry(pawn_a, pawn_b, tick):
		return false
	if not _check_same_settlement(pawn_a, pawn_b) and settlement_a != settlement_b:
		var rng_key: StringName = StringName("marriage:cross_settlement:%d_%d" % [pawn_a, pawn_b])
		var cross_ok: bool = WorldRNG.chance_for(rng_key, 0.6, tick) if WorldRNG != null else true
		if not cross_ok:
			return false
	var existing: int = _get_marriage_index(pawn_a)
	if existing >= 0:
		return false
	existing = _get_marriage_index(pawn_b)
	if existing >= 0:
		return false
	var dowry_safe: Dictionary = _sanitize_dowry(dowry)
	var marriage: Dictionary = {
		"pawn_a": pawn_a,
		"pawn_b": pawn_b,
		"settlement_a": settlement_a,
		"settlement_b": settlement_b,
		"tick_married": tick,
		"dowry": dowry_safe,
		"status": S_ACTIVE,
		"children_ids": [],
		"alliance_key": "",
		"tick_ended": -1,
		"end_reason": "",
		"tick_separated": -1,
		"total_interactions": 0,
	}
	_marriages.append(marriage)
	var idx: int = _marriages.size() - 1
	var alliance_key: String = _create_alliance_key(settlement_a, settlement_b)
	_create_alliance(alliance_key, pawn_a, pawn_b, settlement_a, settlement_b, idx, tick)
	marriage["alliance_key"] = alliance_key
	_marriages[idx] = marriage
	_apply_marriage_social_bonds(pawn_a, pawn_b, tick)
	_append_history({
		"type": "marriage_contracted",
		"pawn_a": pawn_a, "pawn_b": pawn_b,
		"settlement_a": settlement_a, "settlement_b": settlement_b,
		"tick": tick, "dowry_value": _compute_dowry_value(dowry_safe),
	})
	_record_world_event("marriage", {
		"pawn_a": pawn_a, "pawn_b": pawn_b,
		"settlement_a": settlement_a, "settlement_b": settlement_b,
		"tick": tick,
	})
	marriage_contracted.emit(pawn_a, pawn_b, settlement_a, settlement_b, tick, _compute_dowry_value(dowry_safe))
	alliance_formed_between_houses.emit(settlement_a, settlement_b, pawn_a, pawn_b, tick)
	return true


func end_marriage_by_pawn(pawn_id: int, reason: String, tick: int) -> bool:
	var idx: int = _get_marriage_index(pawn_id)
	if idx < 0:
		return false
	return _end_marriage_at_index(idx, reason, tick)


func end_marriage(pawn_a: int, pawn_b: int, reason: String, tick: int) -> bool:
	for i in range(_marriages.size()):
		var m: Dictionary = _marriages[i]
		if m["status"] == S_ACTIVE or m["status"] == S_SEPARATED:
			var a: int = int(m["pawn_a"])
			var b: int = int(m["pawn_b"])
			if (a == pawn_a and b == pawn_b) or (a == pawn_b and b == pawn_a):
				return _end_marriage_at_index(i, reason, tick)
	return false


func register_child(child_id: int, parent_a: int, parent_b: int, tick: int) -> bool:
	if child_id < 0:
		return false
	var idx: int = _get_marriage_index(parent_a)
	if idx < 0:
		idx = _get_marriage_index(parent_b)
	if idx < 0:
		var alt: int = _find_marriage_by_parents(parent_a, parent_b)
		if alt >= 0:
			idx = alt
	if idx < 0:
		return false
	var m: Dictionary = _marriages[idx]
	var cids: Array = m.get("children_ids", [])
	if child_id in cids:
		return true
	cids.append(child_id)
	m["children_ids"] = cids
	_marriages[idx] = m
	var sd := get_node_or_null("/root/SocialDynamics")
	if sd != null and sd.has_method("add_children_to_relationship"):
		sd.call("add_children_to_relationship", parent_a, parent_b, [child_id])
	if sd != null and sd.has_method("add_interaction"):
		sd.add_interaction(parent_a, parent_b, "friendship", 0.15, tick, "child_birth")
	_append_history({
		"type": "child_born",
		"pawn_a": parent_a, "pawn_b": parent_b,
		"child_id": child_id, "tick": tick,
	})
	_record_world_event("birth", {
		"parent_a": parent_a, "parent_b": parent_b,
		"child_id": child_id, "tick": tick,
	})
	child_born.emit(parent_a, parent_b, child_id, tick)
	return true


func is_married(pawn_id: int) -> bool:
	for m in _marriages:
		if m["status"] == S_ACTIVE and (int(m["pawn_a"]) == pawn_id or int(m["pawn_b"]) == pawn_id):
			return true
	return false


func get_marriage(pawn_id: int) -> Dictionary:
	for m in _marriages:
		if (m["status"] == S_ACTIVE or m["status"] == S_SEPARATED) and (int(m["pawn_a"]) == pawn_id or int(m["pawn_b"]) == pawn_id):
			return m.duplicate(true)
	return {}


func get_spouse(pawn_id: int) -> int:
	for m in _marriages:
		var s: String = str(m["status"])
		if s != S_ACTIVE and s != S_SEPARATED:
			continue
		if int(m["pawn_a"]) == pawn_id:
			return int(m["pawn_b"])
		if int(m["pawn_b"]) == pawn_id:
			return int(m["pawn_a"])
	return -1


func get_children_for_pawn(pawn_id: int) -> Array[int]:
	var out: Array[int] = []
	for m in _marriages:
		if int(m["pawn_a"]) == pawn_id or int(m["pawn_b"]) == pawn_id:
			var cids: Array = m.get("children_ids", [])
			for c in cids:
				var ci: int = int(c)
				if not (ci in out):
					out.append(ci)
	return out


func get_all_marriages_for_pawn(pawn_id: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for m in _marriages:
		if int(m["pawn_a"]) == pawn_id or int(m["pawn_b"]) == pawn_id:
			out.append(m.duplicate(true))
	return out


func get_marriages_by_status(status: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for m in _marriages:
		if str(m["status"]) == status:
			out.append(m.duplicate(true))
	return out


func get_marriages_for_settlement(settlement_id: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for m in _marriages:
		if int(m["settlement_a"]) == settlement_id or int(m["settlement_b"]) == settlement_id:
			out.append(m.duplicate(true))
	return out


func is_allied(settlement_a: int, settlement_b: int) -> bool:
	if settlement_a == settlement_b:
		return true
	var key: String = _create_alliance_key(settlement_a, settlement_b)
	if not _alliances.has(key):
		return false
	var rec: Dictionary = _alliances[key]
	return bool(rec.get("active", false))


func get_alliance_settlements(settlement_id: int) -> Array[int]:
	var out: Array[int] = []
	for key in _alliances.keys():
		var rec: Dictionary = _alliances[key]
		if not bool(rec.get("active", false)):
			continue
		var sa: int = int(rec["settlement_a"])
		var sb: int = int(rec["settlement_b"])
		if sa == settlement_id and not (sb in out):
			out.append(sb)
		elif sb == settlement_id and not (sa in out):
			out.append(sa)
	out.sort()
	return out


func get_marriage_count() -> Dictionary:
	var counts: Dictionary = {S_ACTIVE: 0, S_SEPARATED: 0, S_DIVORCED: 0, S_WIDOWED: 0}
	for m in _marriages:
		var s: String = str(m.get("status", S_ACTIVE))
		counts[s] = int(counts.get(s, 0)) + 1
	return counts


func get_stats() -> Dictionary:
	var counts: Dictionary = get_marriage_count()
	var total: int = _marriages.size()
	var active: int = int(counts.get(S_ACTIVE, 0))
	var total_children: int = 0
	var total_dowry: float = 0.0
	var widows_eligible: int = 0
	var active_alliances: int = 0
	for m in _marriages:
		total_children += m.get("children_ids", []).size()
		var dv: float = _compute_dowry_value(m.get("dowry", {}))
		total_dowry += dv
	for key in _alliances.keys():
		if bool(_alliances[key].get("active", false)):
			active_alliances += 1
	var now: int = _tick_cache
	for pid in _widow_cooldowns.keys():
		var tw: int = int(_widow_cooldowns[pid])
		if now - tw >= WIDOW_REMARRIAGE_COOLDOWN_TICKS:
			widows_eligible += 1
	var avg_dur: float = _average_marriage_duration()
	var div_rate: float = _divorce_rate()
	return {
		"total_marriages": total,
		"active_marriages": active,
		"separated_marriages": int(counts.get(S_SEPARATED, 0)),
		"divorced_marriages": int(counts.get(S_DIVORCED, 0)),
		"widowed_marriages": int(counts.get(S_WIDOWED, 0)),
		"total_children": total_children,
		"total_dowry_value": roundf(total_dowry * 100.0) / 100.0,
		"active_alliances": active_alliances,
		"widows_eligible_for_remarriage": widows_eligible,
		"average_duration_ticks": roundf(avg_dur * 10.0) / 10.0,
		"divorce_rate": roundf(div_rate * 1000.0) / 1000.0,
		"history_log_size": _history_log.size(),
	}


func get_detailed_stats() -> Dictionary:
	var stats: Dictionary = get_stats()
	var duration_buckets: Dictionary = {5000: 0, 15000: 0, 30000: 0, 60000: 0, 100000: 0}
	var children_dist: Dictionary = {0: 0, 1: 0, 2: 0, 3: 0, 4: 0, 5: 0}
	var cross_settlement: int = 0
	for m in _marriages:
		var dur: int = _tick_cache - int(m["tick_married"])
		var found_bucket: bool = false
		for bkt in [100000, 60000, 30000, 15000, 5000]:
			if dur >= bkt:
				duration_buckets[bkt] = int(duration_buckets.get(bkt, 0)) + 1
				found_bucket = true
				break
		if not found_bucket:
			duration_buckets[5000] = int(duration_buckets.get(5000, 0)) + 1
		var nc: int = m.get("children_ids", []).size()
		if nc > 5:
			nc = 5
		children_dist[nc] = int(children_dist.get(nc, 0)) + 1
		if int(m["settlement_a"]) != int(m["settlement_b"]):
			cross_settlement += 1
	stats["duration_distribution"] = duration_buckets.duplicate()
	stats["children_distribution"] = children_dist.duplicate()
	stats["cross_settlement_marriages"] = cross_settlement
	return stats


func get_save_state() -> Dictionary:
	return {
		"marriages": _marriages.duplicate(true),
		"alliances": _alliances.duplicate(true),
		"widow_cooldowns": _widow_cooldowns.duplicate(true),
		"last_check_tick": _last_check_tick,
		"history_log": _history_log.duplicate(true),
	}


func load_state(state: Dictionary) -> void:
	clear()
	if state.has("marriages"):
		var raw: Array = state["marriages"]
		for entry in raw:
			if entry is Dictionary:
				_marriages.append((entry as Dictionary).duplicate(true))
	if state.has("alliances"):
		var raw_a: Dictionary = state["alliances"]
		for k in raw_a.keys():
			_alliances[str(k)] = (raw_a[k] as Dictionary).duplicate(true)
	if state.has("widow_cooldowns"):
		var raw_w: Dictionary = state["widow_cooldowns"]
		for k in raw_w.keys():
			_widow_cooldowns[int(k)] = int(raw_w[k])
	if state.has("last_check_tick"):
		_last_check_tick = int(state["last_check_tick"])
	if state.has("history_log"):
		var raw_h: Array = state["history_log"]
		for entry in raw_h:
			if entry is Dictionary:
				_history_log.append((entry as Dictionary).duplicate(true))


func clear() -> void:
	_marriages.clear()
	_alliances.clear()
	_widow_cooldowns.clear()
	_last_check_tick = -999999
	_history_log.clear()


# ---------------------------------------------------------------------------
# Private: marriage lifecycle
# ---------------------------------------------------------------------------

func _can_pawns_marry(pawn_a: int, pawn_b: int, tick: int) -> bool:
	if pawn_a == pawn_b:
		return false
	if not _check_minimum_age(pawn_a) or not _check_minimum_age(pawn_b):
		return false
	if not _check_relationship_threshold(pawn_a, pawn_b):
		return false
	return true


func _check_minimum_age(pawn_id: int) -> bool:
	var pd := _get_pawn_data(pawn_id)
	if pd == null:
		return false
	var age: int = int(pd.age) if "age" in pd else 0
	return age >= MIN_MARRIAGE_AGE


func _check_relationship_threshold(pawn_a: int, pawn_b: int) -> bool:
	var sd := get_node_or_null("/root/SocialDynamics")
	if sd == null:
		return true
	if not sd.has_method("get_friendship") or not sd.has_method("get_romance"):
		return true
	var friendship: float = sd.get_friendship(pawn_a, pawn_b)
	var romance: float = sd.get_romance(pawn_a, pawn_b)
	return friendship >= MIN_FRIENDSHIP_FOR_MARRIAGE or romance >= MIN_ROMANCE_FOR_MARRIAGE


func _check_same_settlement(pawn_a: int, pawn_b: int) -> bool:
	var sa: int = _get_pawn_settlement(pawn_a)
	var sb: int = _get_pawn_settlement(pawn_b)
	if sa < 0 or sb < 0:
		return false
	return sa == sb


func _end_marriage_at_index(idx: int, reason: String, tick: int) -> bool:
	if idx < 0 or idx >= _marriages.size():
		return false
	var m: Dictionary = _marriages[idx]
	if m["status"] != S_ACTIVE and m["status"] != S_SEPARATED:
		return false
	var pa: int = int(m["pawn_a"])
	var pb: int = int(m["pawn_b"])
	var sa: int = int(m["settlement_a"])
	var sb: int = int(m["settlement_b"])
	m["status"] = reason
	m["tick_ended"] = tick
	m["end_reason"] = reason
	_marriages[idx] = m
	if reason == S_DIVORCED:
		var akey: String = str(m.get("alliance_key", ""))
		if not akey.is_empty() and ALLIANCE_BREAK_ON_DIVORCE:
			_break_alliance(akey, "divorce", tick)
		_apply_divorce_social_penalty(pa, pb, tick)
	elif reason == S_WIDOWED:
		var survivor: int = pa
		var deceased: int = pb
		if _is_pawn_dead(pb):
			survivor = pa
			deceased = pb
		elif _is_pawn_dead(pa):
			survivor = pb
			deceased = pa
		_widow_cooldowns[survivor] = tick
		_process_inheritance(idx, deceased, tick)
		var akey2: String = str(m.get("alliance_key", ""))
		if not akey2.is_empty():
			_break_alliance(akey2, "widowed", tick)
	elif reason == S_SEPARATED:
		m["tick_separated"] = tick
		_marriages[idx] = m
	_append_history({
		"type": "marriage_ended",
		"pawn_a": pa, "pawn_b": pb,
		"settlement_a": sa, "settlement_b": sb,
		"reason": reason, "tick": tick,
	})
	_record_world_event("marriage_ended", {
		"pawn_a": pa, "pawn_b": pb,
		"reason": reason, "tick": tick,
	})
	marriage_ended.emit(pa, pb, reason, tick)
	return true


func _process_marriage_health(tick: int) -> void:
	for i in range(_marriages.size()):
		var m: Dictionary = _marriages[i]
		var status: String = str(m["status"])
		if status != S_ACTIVE and status != S_SEPARATED:
			continue
		var pa: int = int(m["pawn_a"])
		var pb: int = int(m["pawn_b"])
		if _is_pawn_dead(pa) or _is_pawn_dead(pb):
			var deceased: int = pa if _is_pawn_dead(pa) else pb
			_end_marriage_at_index(i, S_WIDOWED, tick)
			continue
		var sd := get_node_or_null("/root/SocialDynamics")
		var friendship: float = 0.0
		var rivalry: float = 0.0
		var romance: float = 0.0
		if sd != null and sd.has_method("get_friendship"):
			friendship = sd.get_friendship(pa, pb)
		if sd != null and sd.has_method("get_rivalry"):
			rivalry = sd.get_rivalry(pa, pb)
		if sd != null and sd.has_method("get_romance"):
			romance = sd.get_romance(pa, pb)
		if status == S_ACTIVE and rivalry > friendship + 0.2 and rivalry >= DIVORCE_RIVALRY_THRESHOLD:
			_end_marriage_at_index(i, S_SEPARATED, tick)
			continue
		var dt: int = tick - int(m["tick_married"])
		if status == S_SEPARATED:
			var sep_tick: int = int(m.get("tick_separated", m["tick_married"]))
			if tick - sep_tick > SEPARATION_THRESHOLD_TICKS:
				_end_marriage_at_index(i, S_DIVORCED, tick)
				continue
		else:
			if dt > SEPARATION_THRESHOLD_TICKS * 2:
				var rng_key: StringName = StringName("marriage:natural_separation:%d_%d" % [pa, pb])
				var roll: float = WorldRNG.unit_for(rng_key, tick) if WorldRNG != null else 0.5
				if roll < 0.02 and rivalry > friendship:
					_end_marriage_at_index(i, S_SEPARATED, tick)
					continue
		if dt % 5000 == 0 and dt > 0:
			m["total_interactions"] = int(m.get("total_interactions", 0)) + 1
			_marriages[i] = m


func _process_matchmaking(tick: int) -> void:
	var sm := get_node_or_null("/root/SettlementMemory")
	if sm == null or not sm.has_method("get_settlements"):
		return
	var settlements: Array = sm.get_settlements()
	for sv in settlements:
		if not (sv is Dictionary):
			continue
		var st: Dictionary = sv as Dictionary
		var pop: int = int(st.get("population", 0))
		if pop < 6:
			continue
		var center: int = int(st.get("center_region", -1))
		if center < 0:
			continue
		var all_unmarried: Array[int] = _find_unmarried_pawns(center)
		if all_unmarried.size() < 2:
			continue
		var processed: Dictionary = {}
		for pawn_id in all_unmarried:
			if processed.has(pawn_id):
				continue
			var candidates: Array[Dictionary] = _find_matchmaking_candidates(pawn_id, center, tick)
			if candidates.is_empty():
				continue
			candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				return float(a.get("score", 0.0)) > float(b.get("score", 0.0))
			)
			var best: Dictionary = candidates[0]
			var candidate_id: int = int(best.get("pawn_id", -1))
			if candidate_id < 0 or processed.has(candidate_id):
				if candidates.size() > 1:
					best = candidates[1]
					candidate_id = int(best.get("pawn_id", -1))
				else:
					continue
			var score: float = float(best.get("score", 0.0))
			if score < 0.3:
				continue
			matchmaking_attempted.emit(pawn_id, candidate_id, score, tick)
			var rng_key: StringName = StringName("marriage:matchmake:%d_%d" % [pawn_id, candidate_id])
			var success: bool = WorldRNG.chance_for(rng_key, score * 0.8, tick) if WorldRNG != null else score > 0.5
			if success:
				arrange_marriage(pawn_id, candidate_id, center, center, tick)
				processed[pawn_id] = true
				processed[candidate_id] = true


func _process_widow_remarriage(tick: int) -> void:
	var eligible_widows: Array[int] = []
	for pid in _widow_cooldowns.keys():
		var tw: int = int(_widow_cooldowns[pid])
		if tick - tw >= WIDOW_REMARRIAGE_COOLDOWN_TICKS:
			if not is_married(pid) and _check_minimum_age(pid):
				eligible_widows.append(pid)
	for wid in eligible_widows:
		var settlement: int = _get_pawn_settlement(wid)
		if settlement < 0:
			continue
		var candidates: Array[int] = _find_unmarried_pawns(settlement)
		var filtered: Array[int] = []
		for c in candidates:
			if c == wid or is_married(c):
				continue
			var rng_key2: StringName = StringName("marriage:widow_remarry:%d_%d" % [wid, c])
			var ok: bool = WorldRNG.chance_for(rng_key2, 0.4, tick) if WorldRNG != null else true
			if ok:
				filtered.append(c)
		if filtered.is_empty():
			continue
		filtered.sort_custom(func(a: int, b: int) -> bool:
			return _compute_match_score(wid, a, tick) > _compute_match_score(wid, b, tick)
		)
		var best_match: int = filtered[0]
		var score2: float = _compute_match_score(wid, best_match, tick)
		if score2 >= 0.25:
			arrange_marriage(wid, best_match, settlement, settlement, tick)
			_widow_cooldowns.erase(wid)


func _find_matchmaking_candidates(pawn_id: int, settlement_id: int, tick: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var all_unmarried: Array[int] = _find_unmarried_pawns(settlement_id)
	for other_id in all_unmarried:
		if other_id == pawn_id:
			continue
		var pd_other := _get_pawn_data(other_id)
		if pd_other == null:
			continue
		var pd_pawn := _get_pawn_data(pawn_id)
		if pd_pawn == null:
			continue
		var age_diff: int = absi(int(pd_pawn.age) - int(pd_other.age))
		if age_diff > MATCHMAKING_AGE_GAP_MAX * 360:
			continue
		if int(pd_pawn.age) > MATCHMAKING_MAX_AGE * 360 or int(pd_other.age) > MATCHMAKING_MAX_AGE * 360:
			continue
		var score: float = _compute_match_score(pawn_id, other_id, tick)
		if score <= 0.0:
			continue
		out.append({"pawn_id": other_id, "score": score, "tick": tick})
		if out.size() >= MAX_MATCHMAKING_CANDIDATES:
			break
	return out


func _compute_match_score(pawn_a: int, pawn_b: int, tick: int) -> float:
	var sd := get_node_or_null("/root/SocialDynamics")
	if sd == null:
		return 0.5
	var friendship: float = sd.get_friendship(pawn_a, pawn_b) if sd.has_method("get_friendship") else 0.0
	var romance: float = sd.get_romance(pawn_a, pawn_b) if sd.has_method("get_romance") else 0.0
	var rivalry: float = sd.get_rivalry(pawn_a, pawn_b) if sd.has_method("get_rivalry") else 0.0
	var pa: Array[int] = [pawn_a, pawn_b]
	var ages: Array[int] = [0, 0]
	for i in range(2):
		var pd := _get_pawn_data(pa[i])
		ages[i] = int(pd.age) if pd != null and "age" in pd else 0
	var age_gap: int = absi(ages[0] - ages[1])
	var age_penalty: float = clampf(float(age_gap) / 360.0 / float(MATCHMAKING_AGE_GAP_MAX), 0.0, 1.0)
	if ages[0] < MIN_MARRIAGE_AGE * 360 or ages[1] < MIN_MARRIAGE_AGE * 360:
		return 0.0
	var base: float = maxf(friendship, romance) * 0.7 + 0.3
	base = base - rivalry * 0.5
	base = base - age_penalty * 0.2
	var rng_key: StringName = StringName("marriage:match_score:%d_%d" % [pawn_a, pawn_b])
	var jitter: float = WorldRNG.unit_for(rng_key, tick) * 0.1 if WorldRNG != null else 0.05
	base = clampf(base + jitter, 0.0, 1.0)
	return base


func _find_unmarried_pawns(settlement_id: int) -> Array[int]:
	var out: Array[int] = []
	var ps: Node = _get_ps()
	if ps == null:
		return out
	var pawns_v = ps.get("pawns")
	if not (pawns_v is Array):
		return out
	var pawns: Array = pawns_v as Array
	for p in pawns:
		if p == null or not is_instance_valid(p):
			continue
		var data_v = p.get("data")
		if data_v == null:
			continue
		var pid: int = int(data_v.id) if "id" in data_v else -1
		if pid < 0:
			continue
		if is_married(pid):
			continue
		var p_sett: int = _get_pawn_settlement(pid)
		if p_sett != settlement_id:
			continue
		var age: int = int(data_v.age) if "age" in data_v else 0
		if age < MIN_MARRIAGE_AGE * 360:
			continue
		if age > MATCHMAKING_MAX_AGE * 360:
			continue
		out.append(pid)
	return out


func _sanitize_dowry(dowry: Dictionary) -> Dictionary:
	var safe: Dictionary = {"items": [], "total_value": 0.0}
	if dowry.is_empty():
		return safe
	var raw_items: Array = dowry.get("items", [])
	var count: int = 0
	for item in raw_items:
		if count >= MAX_DOWRY_ITEMS:
			break
		if item is Dictionary:
			var safe_item: Dictionary = {}
			for k in ["type", "value", "name", "quality"]:
				if item.has(k):
					safe_item[k] = item[k]
			if not safe_item.is_empty():
				safe["items"].append(safe_item)
				safe["total_value"] = float(safe["total_value"]) + float(safe_item.get("value", 0))
				count += 1
	if dowry.has("total_value"):
		safe["total_value"] = maxf(float(safe["total_value"]), float(dowry["total_value"]))
	return safe


func _compute_dowry_value(dowry: Dictionary) -> float:
	if dowry.is_empty():
		return 0.0
	var total: float = float(dowry.get("total_value", 0.0))
	if total > 0.0:
		return total
	var items: Array = dowry.get("items", [])
	for item in items:
		if item is Dictionary:
			total += float((item as Dictionary).get("value", 0))
	return total


# ---------------------------------------------------------------------------
# Private: inheritance
# ---------------------------------------------------------------------------

func _process_inheritance(marriage_idx: int, deceased_id: int, tick: int) -> void:
	if marriage_idx < 0 or marriage_idx >= _marriages.size():
		return
	var m: Dictionary = _marriages[marriage_idx]
	var spouse_id: int = int(m["pawn_a"]) if int(m["pawn_b"]) == deceased_id else int(m["pawn_b"])
	var child_ids: Array = m.get("children_ids", [])
	var pd := _get_pawn_data(deceased_id)
	if pd == null:
		_append_history({
			"type": "inheritance_no_data",
			"deceased_id": deceased_id, "spouse_id": spouse_id,
			"tick": tick,
		})
		return
	var skills: Dictionary = _extract_skills(pd)
	if skills.is_empty():
		_append_history({
			"type": "inheritance_no_skills",
			"deceased_id": deceased_id, "spouse_id": spouse_id,
			"tick": tick,
		})
		return
	_transfer_skills_to_pawn(skills, spouse_id, INHERITANCE_SPOUSE_FRACTION, tick)
	for child_id in child_ids:
		_transfer_skills_to_pawn(skills, int(child_id), INHERITANCE_CHILD_FRACTION, tick)
	_append_history({
		"type": "inheritance_transferred",
		"deceased_id": deceased_id,
		"spouse_id": spouse_id,
		"child_ids": child_ids.duplicate(),
		"skills_count": skills.size(),
		"tick": tick,
	})
	_record_world_event("inheritance", {
		"deceased_id": deceased_id,
		"spouse_id": spouse_id,
		"child_ids": child_ids,
		"tick": tick,
	})
	inheritance_transferred.emit(deceased_id, spouse_id, child_ids, tick)


func _extract_skills(pd) -> Dictionary:
	var skills: Dictionary = {}
	if "skill_levels" in pd:
		var sl: Dictionary = pd.skill_levels
		for k in sl.keys():
			var val: Variant = sl[k]
			if val is float or val is int:
				skills[k] = float(val)
	if "knowledge" in pd:
		var kn: Variant = pd.knowledge
		if kn is Array:
			for entry in kn:
				if entry is Dictionary:
					var ed: Dictionary = entry as Dictionary
					var kname: String = str(ed.get("name", ""))
					var klev: float = float(ed.get("level", 1.0))
					if not kname.is_empty():
						skills["knowledge_" + kname] = klev
	return skills


func _transfer_skills_to_pawn(skills: Dictionary, target_id: int, fraction: float, tick: int) -> void:
	if target_id < 0 or fraction <= 0.0 or skills.is_empty():
		return
	var pd := _get_pawn_data(target_id)
	if pd == null:
		return
	var knowledge_sys := get_node_or_null("/root/KnowledgeSystem")
	var skill_names: Dictionary = {
		0: "foraging", 1: "mining", 2: "chopping",
		3: "building", 4: "hunting", 5: "farming",
		6: "crafting", 7: "healing", 8: "scholarship",
	}
	for skill_key in skills.keys():
		var val: float = float(skills[skill_key]) * fraction
		if val <= 0.0:
			continue
		if skill_key is int and knowledge_sys != null and knowledge_sys.has_method("_get_pawn_data_by_id"):
			if pd.has_method("add_skill_xp"):
				pd.add_skill_xp(skill_key, val * 60.0)
		elif skill_key is String and skill_key.begins_with("knowledge_") and knowledge_sys != null:
			if knowledge_sys.has_method("get_knowledge_status"):
				var kn_name: String = skill_key.trim_prefix("knowledge_")
				if knowledge_sys.has_method("record_teaching_event"):
					knowledge_sys.call("record_teaching_event", tick, Vector2i(-1, -1),
						target_id, "", target_id, "", kn_name, -1)


func _extract_profession_data(pd) -> Dictionary:
	var prof_data: Dictionary = {}
	if "current_profession" in pd:
		prof_data["profession"] = int(pd.current_profession)
	var prof_names: Array = ["farmer", "builder", "gatherer", "warrior", "scholar", "trader", "smith", "healer"]
	if pd.has("profession") and int(pd.profession) >= 0 and int(pd.profession) < prof_names.size():
		prof_data["profession_name"] = prof_names[int(pd.profession)]
	elif prof_data.has("profession"):
		var pidx: int = int(prof_data["profession"])
		if pidx >= 0 and pidx < prof_names.size():
			prof_data["profession_name"] = prof_names[pidx]
	return prof_data


# ---------------------------------------------------------------------------
# Private: alliances
# ---------------------------------------------------------------------------

func _create_alliance_key(a: int, b: int) -> String:
	var lo: int = mini(a, b)
	var hi: int = maxi(a, b)
	return "%d,%d" % [lo, hi]


func _create_alliance(key: String, pawn_a: int, pawn_b: int, settlement_a: int, settlement_b: int, marriage_idx: int, tick: int) -> void:
	if _alliances.has(key):
		var existing: Dictionary = _alliances[key]
		if bool(existing.get("active", false)):
			return
		existing["active"] = true
		existing["tick_renewed"] = tick
		existing["marriage_indices"] = _ensure_array_append(existing.get("marriage_indices", []), marriage_idx)
		_alliances[key] = existing
		return
	_alliances[key] = {
		"settlement_a": settlement_a,
		"settlement_b": settlement_b,
		"pawn_a": pawn_a,
		"pawn_b": pawn_b,
		"tick_formed": tick,
		"tick_renewed": tick,
		"active": true,
		"marriage_indices": [marriage_idx],
	}


func _break_alliance(key: String, reason: String, tick: int) -> void:
	if not _alliances.has(key):
		return
	var rec: Dictionary = _alliances[key]
	if not bool(rec.get("active", false)):
		return
	rec["active"] = false
	rec["tick_broken"] = tick
	rec["break_reason"] = reason
	_alliances[key] = rec
	var sa: int = int(rec.get("settlement_a", -1))
	var sb: int = int(rec.get("settlement_b", -1))
	if sa >= 0 and sb >= 0:
		alliance_broken_between_houses.emit(sa, sb, reason, tick)
		_record_world_event("alliance_broken", {
			"settlement_a": sa, "settlement_b": sb,
			"reason": reason, "tick": tick,
		})


func _ensure_array_append(arr: Array, val: Variant) -> Array:
	var out: Array = arr.duplicate()
	if not (val in out):
		out.append(val)
	return out


# ---------------------------------------------------------------------------
# Private: social bonds
# ---------------------------------------------------------------------------

func _apply_marriage_social_bonds(pawn_a: int, pawn_b: int, tick: int) -> void:
	var sd := get_node_or_null("/root/SocialDynamics")
	if sd == null:
		return
	if sd.has_method("add_interaction"):
		sd.add_interaction(pawn_a, pawn_b, "romance", ROMANCE_BIND_VALUE, tick, "marriage_vows")
		sd.add_interaction(pawn_a, pawn_b, "friendship", FRIENDSHIP_BIND_VALUE, tick, "marriage_alliance")
	if sd.has_method("add_children_to_relationship"):
		sd.call("add_children_to_relationship", pawn_a, pawn_b, [])


func _apply_divorce_social_penalty(pawn_a: int, pawn_b: int, tick: int) -> void:
	var sd := get_node_or_null("/root/SocialDynamics")
	if sd == null:
		return
	if sd.has_method("add_interaction"):
		sd.add_interaction(pawn_a, pawn_b, "romance", -0.6, tick, "divorce")
		sd.add_interaction(pawn_a, pawn_b, "friendship", -0.4, tick, "divorce_cooling")
		sd.add_interaction(pawn_a, pawn_b, "rivalry", 0.3, tick, "divorce_resentment")


# ---------------------------------------------------------------------------
# Private: event bus handlers
# ---------------------------------------------------------------------------

func _on_pawn_death_event(payload: Dictionary) -> void:
	if payload == null or payload.is_empty():
		return
	var pawn_id: int = int(payload.get("pawn_id", -1))
	if pawn_id < 0:
		return
	var tick: int = int(payload.get("tick", _tick_cache))
	var idx: int = _get_marriage_index(pawn_id)
	if idx < 0:
		_widow_cooldowns.erase(pawn_id)
		return
	end_marriage_by_pawn(pawn_id, S_WIDOWED, tick)


func _on_pawn_born_event(payload: Dictionary) -> void:
	if payload == null or payload.is_empty():
		return
	var child_id: int = int(payload.get("pawn_id", payload.get("child_id", -1)))
	var mother_id: int = int(payload.get("mother_id", -1))
	var father_id: int = int(payload.get("father_id", -1))
	if child_id < 0:
		return
	var tick: int = int(payload.get("tick", _tick_cache))
	if mother_id >= 0 and father_id >= 0:
		register_child(child_id, mother_id, father_id, tick)
	elif mother_id >= 0:
		var spouse: int = get_spouse(mother_id)
		if spouse >= 0:
			register_child(child_id, mother_id, spouse, tick)


func _on_relationship_changed(payload: Dictionary) -> void:
	if payload == null or payload.is_empty():
		return
	var pawn_a: int = int(payload.get("pawn_a", -1))
	var pawn_b: int = int(payload.get("pawn_b", -1))
	var bond: String = str(payload.get("bond", ""))
	var delta: float = float(payload.get("delta", 0.0))
	var tick: int = int(payload.get("tick", _tick_cache))
	if pawn_a < 0 or pawn_b < 0:
		return
	var idx: int = _get_marriage_index(pawn_a)
	if idx < 0:
		idx = _get_marriage_index(pawn_b)
	if idx < 0:
		return
	var m: Dictionary = _marriages[idx]
	if str(m["status"]) != S_ACTIVE:
		return
	if bond == "rivalry" and delta > 0.1:
		var sd := get_node_or_null("/root/SocialDynamics")
		if sd != null and sd.has_method("get_friendship") and sd.has_method("get_rivalry"):
			var friendship: float = sd.get_friendship(pawn_a, pawn_b)
			var rivalry: float = sd.get_rivalry(pawn_a, pawn_b)
			if rivalry > friendship + 0.3 and rivalry >= DIVORCE_RIVALRY_THRESHOLD:
				end_marriage(pawn_a, pawn_b, S_SEPARATED, tick)
	elif bond == "romance" and delta < -0.3:
		var sd2 := get_node_or_null("/root/SocialDynamics")
		if sd2 != null and sd2.has_method("get_romance"):
			var romance: float = sd2.get_romance(pawn_a, pawn_b)
			if romance < 0.1:
				end_marriage(pawn_a, pawn_b, S_SEPARATED, tick)


# ---------------------------------------------------------------------------
# Private: world memory
# ---------------------------------------------------------------------------

func _record_world_event(event_type: String, data: Dictionary) -> void:
	var wm := get_node_or_null("/root/WorldMemory")
	if wm == null or not wm.has_method("record_event"):
		return
	var payload: Dictionary = data.duplicate()
	payload["type"] = "marriage_" + event_type
	wm.record_event(payload)


# ---------------------------------------------------------------------------
# Private: history log
# ---------------------------------------------------------------------------

func _append_history(entry: Dictionary) -> void:
	_history_log.append(entry.duplicate(true))
	if _history_log.size() > HISTORY_MAX_SIZE:
		_history_log.pop_front()


func _prune_stale_history(tick: int) -> void:
	var cutoff: int = tick - 50000
	var kept: Array[Dictionary] = []
	for entry in _history_log:
		var et: int = int(entry.get("tick", 0))
		if et >= cutoff:
			kept.append(entry)
	_history_log = kept


# ---------------------------------------------------------------------------
# Private: lookup helpers
# ---------------------------------------------------------------------------

func _get_marriage_index(pawn_id: int) -> int:
	for i in range(_marriages.size()):
		var m: Dictionary = _marriages[i]
		var s: String = str(m["status"])
		if s == S_ACTIVE or s == S_SEPARATED:
			if int(m["pawn_a"]) == pawn_id or int(m["pawn_b"]) == pawn_id:
				return i
	return -1


func _find_marriage_by_parents(parent_a: int, parent_b: int) -> int:
	for i in range(_marriages.size()):
		var m: Dictionary = _marriages[i]
		var pa: int = int(m["pawn_a"])
		var pb: int = int(m["pawn_b"])
		if (pa == parent_a and pb == parent_b) or (pa == parent_b and pb == parent_a):
			return i
	return -1


func _get_pawn_settlement(pawn_id: int) -> int:
	var ps: Node = _get_ps()
	if ps == null or not ps.has_method("_get_pawn_node"):
		return -1
	var pawn = ps.call("_get_pawn_node", pawn_id)
	if pawn == null or not is_instance_valid(pawn):
		return -1
	var data_v = pawn.get("data")
	if data_v == null:
		return -1
	return int(data_v.settlement_id) if "settlement_id" in data_v else -1


func _get_pawn_data(pawn_id: int) -> HeelKawnianData:
	var ps: Node = _get_ps()
	if ps == null or not ps.has_method("pawn_data_for_id"):
		return null
	return ps.call("pawn_data_for_id", pawn_id)


func _is_pawn_dead(pawn_id: int) -> bool:
	var ps: Node = _get_ps()
	if ps == null or not ps.has_method("_get_pawn_node"):
		return true
	var pawn = ps.call("_get_pawn_node", pawn_id)
	return pawn == null or not is_instance_valid(pawn)


func _get_ps() -> Node:
	return get_node_or_null("/root/Main/WorldViewport/PawnSpawner")


# ---------------------------------------------------------------------------
# Private: statistics helpers
# ---------------------------------------------------------------------------

func _average_marriage_duration() -> float:
	var ended: Array[Dictionary] = []
	for m in _marriages:
		if int(m.get("tick_ended", -1)) > 0:
			ended.append(m)
	if ended.is_empty():
		return 0.0
	var total_dur: int = 0
	for m in ended:
		total_dur += int(m["tick_ended"]) - int(m["tick_married"])
	return float(total_dur) / float(ended.size())


func _divorce_rate() -> float:
	if _marriages.is_empty():
		return 0.0
	var divorced: int = 0
	var ended: int = 0
	for m in _marriages:
		var s: String = str(m["status"])
		if s == S_DIVORCED:
			divorced += 1
			ended += 1
		elif s == S_WIDOWED or (int(m.get("tick_ended", -1)) > 0):
			ended += 1
	if ended == 0:
		return 0.0
	return float(divorced) / float(ended)
