extends Node
## SocialDynamics — dyadic relationship tracking between pawns.
##
## Tracks friendship, rivalry, romance bonds. Integrates with EgregoreMemory
## for faction-level mood, GossipManager for social events, and GrudgeManager
## for lasting hostility. All updates use deterministic tick-based decay.
##
## Data model per relationship:
##   "low_id,high_id" -> {
##     pawn_a, pawn_b, friendship, rivalry, romance,
##     last_tick, interaction_count, last_bond, bond_tier,
##     history: [{tick, bond, delta, reason}],
##     total_positive, total_negative,
##     alliance_active, vendetta_active, children_ids
##   }

const DECAY_INTERVAL: int = 5000
const VENDETTA_DECAY_INTERVAL: int = 15000
const MAX_RELATIONSHIPS_PER_PAWN: int = 20
const HISTORY_MAX: int = 12
const GOSSIP_THRESHOLD: float = 0.15
const MARRIAGE_PREP_THRESHOLD: float = 0.7
const VENDETTA_THRESHOLD: float = 0.6
const ALLIANCE_THRESHOLD: float = 0.5
const CACHE_TTL_TICKS: int = 600

var _relationships: Dictionary = {}
var _last_decay_tick: int = -999999
var _last_vendetta_decay_tick: int = -999999
var _social_health_cache: Dictionary = {}
var _social_health_cache_tick: int = -999999

signal relationship_changed(pawn_a: int, pawn_b: int, bond: String, delta: float, new_value: float)
signal vendetta_started(pawn_a: int, pawn_b: int, reason: String)
signal alliance_formed(pawn_a: int, pawn_b: int, reason: String)
signal marriage_potential(pawn_a: int, pawn_b: int, match_quality: float)

func _ready() -> void:
	if GameManager != null:
		GameManager.game_tick.connect(_on_game_tick)
	if EventBus != null:
		EventBus.subscribe(EventBus.EVENT_PAWN_DEATH, self, "_on_pawn_death")
		EventBus.subscribe(EventBus.EVENT_PAWN_MOVE, self, "_on_pawn_move")
		EventBus.subscribe(EventBus.EVENT_CONFLICT, self, "_on_conflict_event")

func _exit_tree() -> void:
	if GameManager != null and GameManager.game_tick.is_connected(_on_game_tick):
		GameManager.game_tick.disconnect(_on_game_tick)
	if EventBus != null:
		EventBus.unsubscribe(EventBus.EVENT_PAWN_DEATH, self, "_on_pawn_death")
		EventBus.unsubscribe(EventBus.EVENT_PAWN_MOVE, self, "_on_pawn_move")
		EventBus.unsubscribe(EventBus.EVENT_CONFLICT, self, "_on_conflict_event")

func _on_game_tick(tick: int) -> void:
	if tick - _last_decay_tick >= DECAY_INTERVAL:
		_last_decay_tick = tick
		_decay_all_relationships(tick)
	if tick - _last_vendetta_decay_tick >= VENDETTA_DECAY_INTERVAL:
		_last_vendetta_decay_tick = tick
		_decay_vendettas(tick)
	if tick - _social_health_cache_tick > CACHE_TTL_TICKS:
		_social_health_cache.clear()
		_social_health_cache_tick = -999999

func _on_pawn_death(payload: Dictionary) -> void:
	var pid: int = int(payload.get("pawn_id", -1))
	if pid < 0:
		return
	var keys_to_remove: Array[String] = []
	for key in _relationships.keys():
		var rel: Dictionary = _relationships[key]
		if int(rel.get("pawn_a", -1)) == pid or int(rel.get("pawn_b", -1)) == pid:
			keys_to_remove.append(key)
	for k in keys_to_remove:
		_relationships.erase(k)
	if not keys_to_remove.is_empty():
		var gm := get_node_or_null("/root/GossipManager")
		if gm != null and gm.has_method("generate_gossip_event"):
			gm.generate_gossip_event(payload.get("tick", 0), pid,
					"pawn death cleared %d social bonds" % keys_to_remove.size())

func _on_pawn_move(payload: Dictionary) -> void:
	var pid: int = int(payload.get("pawn_id", -1))
	if pid < 0:
		return
	var old_settlement: int = int(payload.get("old_settlement_id", -1))
	var new_settlement: int = int(payload.get("new_settlement_id", -1))
	if old_settlement < 0 or new_settlement < 0 or old_settlement == new_settlement:
		return
	var tick: int = int(payload.get("tick", 0))
	for key in _relationships.keys():
		var rel: Dictionary = _relationships[key]
		var other: int = int(rel.get("pawn_a", -1))
		if other == pid:
			other = int(rel.get("pawn_b", -1))
		var other_data = _get_pawn_settlement(other)
		if other_data < 0 or other_data != new_settlement:
			_rel_decay_key(key, rel, 0.1, "distance_separation", tick)
		elif other_data == new_settlement:
			_rel_boost_key(key, rel, "friendship", 0.05, "reunited", tick)

func _on_conflict_event(payload: Dictionary) -> void:
	var a: int = int(payload.get("aggressor_id", -1))
	var b: int = int(payload.get("defender_id", -1))
	var tick: int = int(payload.get("tick", 0))
	if a < 0 or b < 0:
		return
	add_interaction(a, b, "rivalry", 0.3, tick, "conflict")
	add_interaction(b, a, "rivalry", 0.2, tick, "defended")
	var gm := get_node_or_null("/root/GossipManager")
	if gm != null and gm.has_method("generate_gossip_event"):
		gm.generate_gossip_event(tick, a, "conflict with pawn %d escalates rivalry" % b)

func get_or_create_key(a: int, b: int) -> String:
	var lo: int = mini(a, b)
	var hi: int = maxi(a, b)
	return "%d,%d" % [lo, hi]

func add_interaction(pawn_a: int, pawn_b: int, bond: String, delta: float, tick: int, reason: String = "") -> void:
	if pawn_a == pawn_b:
		return
	if delta == 0.0:
		return
	var key: String = get_or_create_key(pawn_a, pawn_b)
	if not _relationships.has(key):
		_relationships[key] = _new_relationship(pawn_a, pawn_b, tick)
	var rel: Dictionary = _relationships[key]
	var allowed: bool = true
	var new_val: float = rel.get(bond, 0.0)
	match bond:
		"friendship":
			new_val = clampf(new_val + delta, -1.0, 1.0)
			rel["friendship"] = new_val
			rel["total_positive"] = rel.get("total_positive", 0) + absf(delta)
		"rivalry":
			new_val = clampf(new_val + delta, -1.0, 1.0)
			rel["rivalry"] = new_val
			rel["total_negative"] = rel.get("total_negative", 0) + absf(delta)
		"romance":
			if delta > 0 and absf(rel.get("romance", 0.0)) < MARRIAGE_PREP_THRESHOLD:
				new_val = clampf(new_val + delta, -1.0, 1.0)
				rel["romance"] = new_val
			elif delta < 0:
				new_val = clampf(new_val + delta, -1.0, 1.0)
				rel["romance"] = new_val
			else:
				allowed = false
		_:
			allowed = false
	if not allowed:
		return
	rel["last_tick"] = tick
	rel["last_bond"] = bond
	rel["interaction_count"] = rel.get("interaction_count", 0) + 1
	rel["bond_tier"] = _compute_bond_tier(rel)
	_append_history(rel, tick, bond, delta, reason)
	if rel.get("rivalry", 0.0) > VENDETTA_THRESHOLD and not rel.get("vendetta_active", false):
		rel["vendetta_active"] = true
		vendetta_started.emit(pawn_a, pawn_b, reason)
		var gm := get_node_or_null("/root/GossipManager")
		if gm != null and gm.has_method("generate_gossip_event"):
			gm.generate_gossip_event(tick, pawn_a, "vendetta declared against pawn %d" % pawn_b)
		_record_world_event("vendetta_started", pawn_a, pawn_b, tick)
	if rel.get("friendship", 0.0) > ALLIANCE_THRESHOLD and not rel.get("alliance_active", false):
		rel["alliance_active"] = true
		alliance_formed.emit(pawn_a, pawn_b, reason)
		_record_world_event("alliance_formed", pawn_a, pawn_b, tick)
	if bond == "romance" and absf(new_val) >= MARRIAGE_PREP_THRESHOLD:
		marriage_potential.emit(pawn_a, pawn_b, new_val)
	_relationships[key] = rel
	relationship_changed.emit(pawn_a, pawn_b, bond, delta, new_val)
	if absf(delta) >= GOSSIP_THRESHOLD:
		_emit_gossip(tick, pawn_a, pawn_b, bond, delta)

func _new_relationship(a: int, b: int, tick: int) -> Dictionary:
	return {
		"pawn_a": a, "pawn_b": b,
		"friendship": 0.0, "rivalry": 0.0, "romance": 0.0,
		"last_tick": tick, "last_bond": "",
		"interaction_count": 0, "bond_tier": 0,
		"history": [], "total_positive": 0, "total_negative": 0,
		"alliance_active": false, "vendetta_active": false, "children_ids": [],
	}

func _compute_bond_tier(rel: Dictionary) -> int:
	var max_bond: float = maxf(
		maxf(absf(rel.get("friendship", 0.0)), absf(rel.get("rivalry", 0.0))),
		absf(rel.get("romance", 0.0))
	)
	if max_bond >= 0.8:
		return 5
	if max_bond >= 0.6:
		return 4
	if max_bond >= 0.4:
		return 3
	if max_bond >= 0.2:
		return 2
	if max_bond > 0.0:
		return 1
	return 0

func _append_history(rel: Dictionary, tick: int, bond: String, delta: float, reason: String) -> void:
	var hist: Array = rel.get("history", [])
	hist.append({"tick": tick, "bond": bond, "delta": delta, "reason": reason})
	if hist.size() > HISTORY_MAX:
		hist.pop_front()
	rel["history"] = hist

func _emit_gossip(tick: int, a: int, b: int, bond: String, delta: float) -> void:
	var gm := get_node_or_null("/root/GossipManager")
	if gm == null or not gm.has_method("generate_gossip_event"):
		return
	var adjective: String = "intense" if absf(delta) > 0.3 else "notable"
	var direction: String = "strengthened" if delta > 0 else "weakened"
	gm.generate_gossip_event(tick, a,
			"%s bond %s between pawn %d and %d" % [bond.capitalize(), direction, a, b])

func _record_world_event(event_type: String, a: int, b: int, tick: int) -> void:
	var wm := get_node_or_null("/root/WorldMemory")
	if wm == null or not wm.has_method("record_event"):
		return
	wm.record_event({
		"type": "social_" + event_type,
		"pawn_a": a, "pawn_b": b, "tick": tick,
	})

func get_relationship(a: int, b: int) -> Dictionary:
	if a == b:
		return {}
	return _relationships.get(get_or_create_key(a, b), {}).duplicate()

func get_friendship(a: int, b: int) -> float:
	if a == b:
		return 1.0
	return get_relationship(a, b).get("friendship", 0.0)

func get_rivalry(a: int, b: int) -> float:
	if a == b:
		return 0.0
	return get_relationship(a, b).get("rivalry", 0.0)

func get_romance(a: int, b: int) -> float:
	if a == b:
		return 0.0
	return get_relationship(a, b).get("romance", 0.0)

func get_dominant_bond(a: int, b: int) -> String:
	var rel: Dictionary = get_relationship(a, b)
	if rel.is_empty():
		return "neutral"
	var f: float = absf(rel.get("friendship", 0.0))
	var r: float = absf(rel.get("rivalry", 0.0))
	var ro: float = absf(rel.get("romance", 0.0))
	if f >= r and f >= ro and f > 0.1:
		return "friendship"
	if r >= f and r >= ro and r > 0.1:
		return "rivalry"
	if ro >= f and ro >= r and ro > 0.1:
		return "romance"
	return "neutral"

func get_bond_tier(a: int, b: int) -> int:
	return get_relationship(a, b).get("bond_tier", 0)

func get_all_relationships_for(pawn_id: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for key in _relationships.keys():
		var rel: Dictionary = _relationships[key]
		if int(rel.get("pawn_a", -1)) == pawn_id or int(rel.get("pawn_b", -1)) == pawn_id:
			out.append(rel.duplicate(true))
	return out

func get_relationships_of_bond(pawn_id: int, bond: String, min_val: float = 0.0) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for rel in get_all_relationships_for(pawn_id):
		if absf(rel.get(bond, 0.0)) >= min_val:
			out.append(rel)
	return out

func get_other_pawn_id(rel: Dictionary, pawn_id: int) -> int:
	if int(rel.get("pawn_a", -1)) == pawn_id:
		return int(rel.get("pawn_b", -1))
	return int(rel.get("pawn_a", -1))

func count_friends(pawn_id: int, min_friendship: float = 0.3) -> int:
	var count: int = 0
	for rel in get_all_relationships_for(pawn_id):
		if rel.get("friendship", 0.0) >= min_friendship:
			count += 1
	return count

func count_rivals(pawn_id: int, min_rivalry: float = 0.3) -> int:
	var count: int = 0
	for rel in get_all_relationships_for(pawn_id):
		if rel.get("rivalry", 0.0) >= min_rivalry:
			count += 1
	return count

func count_romances(pawn_id: int, min_romance: float = 0.3) -> int:
	var count: int = 0
	for rel in get_all_relationships_for(pawn_id):
		if rel.get("romance", 0.0) >= min_romance:
			count += 1
	return count

func is_allied(a: int, b: int) -> bool:
	return get_relationship(a, b).get("alliance_active", false)

func is_vendetta(a: int, b: int) -> bool:
	return get_relationship(a, b).get("vendetta_active", false)

func get_friend_ids(pawn_id: int, min_friendship: float = 0.3) -> Array[int]:
	var out: Array[int] = []
	for rel in get_all_relationships_for(pawn_id):
		if rel.get("friendship", 0.0) >= min_friendship:
			out.append(get_other_pawn_id(rel, pawn_id))
	return out

func get_rival_ids(pawn_id: int, min_rivalry: float = 0.3) -> Array[int]:
	var out: Array[int] = []
	for rel in get_all_relationships_for(pawn_id):
		if rel.get("rivalry", 0.0) >= min_rivalry:
			out.append(get_other_pawn_id(rel, pawn_id))
	return out

func get_friends_of_friends(pawn_id: int, depth: int = 1) -> Array[int]:
	var direct_friends: Array[int] = get_friend_ids(pawn_id)
	if depth <= 1:
		return direct_friends
	var out: Array[int] = []
	out.append_array(direct_friends)
	for fid in direct_friends:
		for rel in get_all_relationships_for(fid):
			var other: int = get_other_pawn_id(rel, fid)
			if other != pawn_id and not (other in out) and rel.get("friendship", 0.0) >= 0.3:
				out.append(other)
	return out

func get_social_isolation_score(pawn_id: int) -> float:
	var all: Array = get_all_relationships_for(pawn_id)
	if all.is_empty():
		return 1.0
	var strong_bonds: int = 0
	for rel in all:
		if rel.get("bond_tier", 0) >= 3:
			strong_bonds += 1
	if strong_bonds >= 2:
		return 0.0
	if strong_bonds == 1:
		return 0.5
	return 1.0

func get_settlement_social_health(settlement_id: int) -> float:
	var cache_key: int = settlement_id
	if _social_health_cache.has(cache_key) and _social_health_cache_tick > 0:
		return float(_social_health_cache[cache_key])
	var total_bonds: int = 0
	var positive_bonds: int = 0
	var total_pawns: int = _get_settlement_pawn_count(settlement_id)
	if total_pawns < 2:
		var result: float = 0.5
		_social_health_cache[cache_key] = result
		_social_health_cache_tick = 1
		return result
	for key in _relationships.keys():
		var rel: Dictionary = _relationships[key]
		var a_sett: int = _get_pawn_settlement(int(rel.get("pawn_a", -1)))
		var b_sett: int = _get_pawn_settlement(int(rel.get("pawn_b", -1)))
		if a_sett == settlement_id or b_sett == settlement_id:
			total_bonds += 1
			if rel.get("friendship", 0.0) > absf(rel.get("rivalry", 0.0)):
				positive_bonds += 1
	if total_bonds == 0:
		var result: float = 0.3
		_social_health_cache[cache_key] = result
		_social_health_cache_tick = settlement_id
		return result
	var health: float = float(positive_bonds) / float(total_bonds)
	_social_health_cache[cache_key] = health
	return health

func add_children_to_relationship(pawn_a: int, pawn_b: int, child_ids: Array[int]) -> void:
	var key: String = get_or_create_key(pawn_a, pawn_b)
	if not _relationships.has(key):
		_relationships[key] = _new_relationship(pawn_a, pawn_b, 0)
	var rel: Dictionary = _relationships[key]
	var existing: Array = rel.get("children_ids", [])
	for cid in child_ids:
		if not (cid in existing):
			existing.append(cid)
	rel["children_ids"] = existing
	_relationships[key] = rel

func get_children_ids(pawn_a: int, pawn_b: int) -> Array[int]:
	return get_relationship(pawn_a, pawn_b).get("children_ids", [])

func remove_pawn_relationships(pawn_id: int) -> int:
	var count: int = 0
	var keys_to_remove: Array[String] = []
	for key in _relationships.keys():
		var rel: Dictionary = _relationships[key]
		if int(rel.get("pawn_a", -1)) == pawn_id or int(rel.get("pawn_b", -1)) == pawn_id:
			keys_to_remove.append(key)
			count += 1
	for k in keys_to_remove:
		_relationships.erase(k)
	return count

func initialize_pawn_in_household(pawn_id: int, household_member_ids: Array[int], tick: int) -> int:
	var count: int = 0
	for other_id in household_member_ids:
		if other_id == pawn_id:
			continue
		add_interaction(pawn_id, other_id, "friendship", 0.15, tick, "household_initial")
		count += 1
	return count

func _decay_all_relationships(tick: int) -> void:
	var decay_rate: float = 0.02
	var keys_to_remove: Array[String] = []
	for key in _relationships.keys():
		var rel: Dictionary = _relationships[key]
		var dt: int = tick - int(rel.get("last_tick", tick))
		if dt > 30000:
			keys_to_remove.append(key)
			continue
		if dt > DECAY_INTERVAL:
			_rel_decay_key(key, rel, decay_rate, "time_decay", tick)
	_cleanup_keys(keys_to_remove)

func _decay_vendettas(tick: int) -> void:
	for key in _relationships.keys():
		var rel: Dictionary = _relationships[key]
		if not rel.get("vendetta_active", false):
			continue
		if rel.get("rivalry", 0.0) < VENDETTA_THRESHOLD * 0.7:
			rel["vendetta_active"] = false
			_relationships[key] = rel

func _rel_decay_key(key: String, rel: Dictionary, rate: float, reason: String, tick: int) -> void:
	var changed: bool = false
	if absf(rel["friendship"]) > 0.01:
		rel["friendship"] = clampf(rel["friendship"] - rate * signf(rel["friendship"]), -1.0, 1.0)
		changed = true
	if absf(rel["rivalry"]) > 0.01:
		rel["rivalry"] = clampf(rel["rivalry"] - rate * signf(rel["rivalry"]), -1.0, 1.0)
		changed = true
	if absf(rel["romance"]) > 0.01:
		rel["romance"] = clampf(rel["romance"] - rate * signf(rel["romance"]), -1.0, 1.0)
		changed = true
	if changed:
		_append_history(rel, tick, "decay", -rate, reason)
		rel["bond_tier"] = _compute_bond_tier(rel)
	_relationships[key] = rel

func _rel_boost_key(key: String, rel: Dictionary, bond: String, amount: float, reason: String, tick: int) -> void:
	var old: float = rel.get(bond, 0.0)
	rel[bond] = clampf(old + amount, -1.0, 1.0)
	_append_history(rel, tick, bond, amount, reason)
	rel["bond_tier"] = _compute_bond_tier(rel)
	_relationships[key] = rel

func _cleanup_keys(keys: Array[String]) -> void:
	for k in keys:
		_relationships.erase(k)

func _get_pawn_settlement(pawn_id: int) -> int:
	var ps := get_node_or_null("/root/Main/WorldViewport/PawnSpawner")
	if ps == null or not ps.has_method("_get_pawn_node"):
		return -1
	var pawn = ps.call("_get_pawn_node", pawn_id)
	if pawn == null or not is_instance_valid(pawn):
		return -1
	var data = pawn.get("data")
	if data == null:
		return -1
	return int(data.settlement_id)

func _get_settlement_pawn_count(settlement_id: int) -> int:
	var ps := get_node_or_null("/root/Main/WorldViewport/PawnSpawner")
	if ps == null:
		return 0
	var pawns_v = ps.get("pawns")
	if not (pawns_v is Array):
		return 0
	var pawns: Array = pawns_v as Array
	var count: int = 0
	for pawn in pawns:
		if pawn == null or not is_instance_valid(pawn):
			continue
		var data = pawn.get("data")
		if data != null and int(data.settlement_id) == settlement_id:
			count += 1
	return count

func clear() -> void:
	_relationships.clear()
	_last_decay_tick = -999999
	_last_vendetta_decay_tick = -999999
	_social_health_cache.clear()
	_social_health_cache_tick = -999999

func get_stats() -> Dictionary:
	var total: int = _relationships.size()
	var friends_total: int = 0
	var rivals_total: int = 0
	var romances_total: int = 0
	var vendettas: int = 0
	var alliances: int = 0
	for key in _relationships.keys():
		var rel: Dictionary = _relationships[key]
		if rel.get("friendship", 0.0) >= 0.3: friends_total += 1
		if rel.get("rivalry", 0.0) >= 0.3: rivals_total += 1
		if rel.get("romance", 0.0) >= 0.3: romances_total += 1
		if rel.get("vendetta_active", false): vendettas += 1
		if rel.get("alliance_active", false): alliances += 1
	return {
		"total_relationships": total,
		"total_friendships": friends_total,
		"total_rivalries": rivals_total,
		"total_romances": romances_total,
		"active_vendettas": vendettas,
		"active_alliances": alliances,
		"avg_friendship": roundf(_average_of("friendship") * 100.0) / 100.0,
		"avg_rivalry": roundf(_average_of("rivalry") * 100.0) / 100.0,
		"avg_romance": roundf(_average_of("romance") * 100.0) / 100.0,
	}

func get_detailed_stats() -> Dictionary:
	var stats: Dictionary = get_stats()
	stats["bond_tier_distribution"] = {0: 0, 1: 0, 2: 0, 3: 0, 4: 0, 5: 0}
	for key in _relationships.keys():
		var tier: int = int(_relationships[key].get("bond_tier", 0))
		tier = clampi(tier, 0, 5)
		stats["bond_tier_distribution"][tier] = stats["bond_tier_distribution"].get(tier, 0) + 1
	return stats

func get_save_state() -> Dictionary:
	return {
		"relationships": _relationships.duplicate(true),
		"last_decay_tick": _last_decay_tick,
		"last_vendetta_decay_tick": _last_vendetta_decay_tick,
	}

func load_state(state: Dictionary) -> void:
	clear()
	if state.has("relationships"):
		_relationships = state["relationships"].duplicate(true)
	if state.has("last_decay_tick"):
		_last_decay_tick = int(state["last_decay_tick"])
	if state.has("last_vendetta_decay_tick"):
		_last_vendetta_decay_tick = int(state["last_vendetta_decay_tick"])

func _average_of(field: String) -> float:
	if _relationships.is_empty():
		return 0.0
	var total: float = 0.0
	for key in _relationships.keys():
		total += _relationships[key].get(field, 0.0)
	return total / float(_relationships.size())
