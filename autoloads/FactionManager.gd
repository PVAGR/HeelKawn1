extends Node
## Consolidated Faction Manager
## Combines faction and authority systems into one autoload
## Reduces autoload count while preserving faction functionality

# Child nodes for faction subsystems (loaded on-demand)
var _faction_registry: Node
var _faction_system: Node
var _authority_system: Node

var _faction_registry_loaded: bool = false
var _faction_system_loaded: bool = false
var _authority_system_loaded: bool = false

## CK-lite polity relations: pair_key -> score (-100 hostile .. 100 allied).
var _polity_relation_scores: Dictionary = {}
var _polity_relation_last_tick: Dictionary = {}
var _diplomatic_incident_recorded: Dictionary = {}
var _formal_trade_pairs: Dictionary = {}
const POLITY_RELATION_WAR_THRESHOLD: int = -80
const POLITY_TRADE_RELATION_BONUS: int = 5
const POLITY_RELATION_REFRESH_TICKS: int = 400
const DIPLOMATIC_INCIDENT_COOLDOWN_TICKS: int = 6000

enum AuthorityContext {
	MILITARY = 0,
	CIVIL = 1,
	RELIGIOUS = 2,
	KNOWLEDGE = 3,
}

func _ready() -> void:
	if GameManager != null and not GameManager.game_tick.is_connected(_on_game_tick_diplomacy):
		GameManager.game_tick.connect(_on_game_tick_diplomacy)


func _load_sub(name: String, path: String) -> Node:
	var existing: Node = get_node_or_null("/root/" + name)
	if existing != null:
		return existing
	if FileAccess.file_exists(path):
		var loaded: Node = load(path).new()
		loaded.name = name
		add_child(loaded)
		return loaded
	return null


func _ensure_faction_registry() -> void:
	if not _faction_registry_loaded:
		_faction_registry = _load_sub("FactionRegistry", "res://autoloads/FactionRegistry.gd")
		_faction_registry_loaded = true


func _ensure_faction_system() -> void:
	if not _faction_system_loaded:
		_faction_system = _load_sub("FactionSystem", "res://autoloads/FactionSystem.gd")
		_faction_system_loaded = true


func _ensure_authority() -> void:
	if not _authority_system_loaded:
		_authority_system = _load_sub("AuthoritySystem", "res://autoloads/AuthoritySystem.gd")
		_authority_system_loaded = true


## Get a specific faction subsystem (loads if not already loaded)
func get_subsystem(name: String) -> Node:
	match name:
		"faction_registry": _ensure_faction_registry(); return _faction_registry
		"faction_system": _ensure_faction_system(); return _faction_system
		"authority_system": _ensure_authority(); return _authority_system
		_: return null


## Register faction (delegates to FactionRegistry if available)
func register_faction(faction_id: int, name: String, settlement_id: int) -> void:
	_ensure_faction_registry()
	if _faction_registry != null and _faction_registry.has_method("register_faction"):
		_faction_registry.register_faction(faction_id, name, settlement_id)


## Get faction (delegates to FactionRegistry if available)
func get_faction(faction_id: int) -> Dictionary:
	_ensure_faction_registry()
	if _faction_registry != null and _faction_registry.has_method("get_faction"):
		return _faction_registry.get_faction(faction_id)
	return {}


## Set authority (delegates to AuthoritySystem if available)
func set_authority(settlement_id: int, authority_type: String, authority_id: int) -> void:
	_ensure_authority()
	if _authority_system != null and _authority_system.has_method("set_authority"):
		_authority_system.set_authority(settlement_id, authority_type, authority_id)


## Forward getters for subsystems
func get_faction_registry() -> Node:
	return get_subsystem("faction_registry")


func get_faction_system() -> Node:
	return get_subsystem("faction_system")


func get_authority_system() -> Node:
	return get_subsystem("authority_system")


## Forward AuthoritySystem API for authority-related calls
func apply_authority_bonus(base_priority: int, pawn_id: int) -> int:
	_ensure_authority()
	if _authority_system != null and _authority_system.has_method("apply_authority_bonus"):
		return _authority_system.apply_authority_bonus(base_priority, pawn_id)
	return base_priority


func get_authority_level(pawn_id: int, context: int) -> float:
	_ensure_authority()
	if _authority_system != null and _authority_system.has_method("get_authority_level"):
		return _authority_system.get_authority_level(pawn_id, context)
	return 0.0


func grant_authority(pawn_id: int, context: int, amount: float, source: String) -> void:
	_ensure_authority()
	if _authority_system != null and _authority_system.has_method("grant_authority"):
		_authority_system.grant_authority(pawn_id, context, amount, source)


func get_authority_context(pawn_id: int) -> Dictionary:
	_ensure_authority()
	if _authority_system != null and _authority_system.has_method("get_authority_context"):
		return _authority_system.get_authority_context(pawn_id)
	return {}


## Compatibility / debug shims used by CreatorDebugMenu and other reporters
func debug_summary_block() -> String:
	_ensure_faction_system()
	_ensure_faction_registry()
	if _faction_system != null and _faction_system.has_method("debug_summary_block"):
		return str(_faction_system.call("debug_summary_block"))
	if _faction_registry != null and _faction_registry.has_method("debug_summary_block"):
		return str(_faction_registry.call("debug_summary_block"))
	return "FactionManager: subsystems not loaded or no debug summary available"


func sync_from_settlements() -> void:
	_ensure_faction_system()
	if _faction_system != null and _faction_system.has_method("sync_from_settlements"):
		_faction_system.call("sync_from_settlements")
	_ensure_faction_registry()
	if _faction_registry != null and _faction_registry.has_method("sync_from_settlements"):
		_faction_registry.sync_from_settlements()


func get_synced_house_count() -> int:
	_ensure_faction_system()
	_ensure_faction_registry()
	if _faction_system != null and _faction_system.has_method("get_synced_house_count"):
		return int(_faction_system.call("get_synced_house_count"))
	if _faction_registry != null and _faction_registry.has_method("get_house_count"):
		return int(_faction_registry.call("get_house_count"))
	return 0


# === CK-lite diplomacy (formal polities) ===

static func _polity_pair_key(polity_a: int, polity_b: int) -> String:
	if polity_a > polity_b:
		var tmp: int = polity_a
		polity_a = polity_b
		polity_b = tmp
	return "%d|%d" % [polity_a, polity_b]


func _on_game_tick_diplomacy(tick: int) -> void:
	if SettlementMemory == null:
		return
	if SettlementMemory.get_formal_settlement_count() < 2:
		return
	if GameManager == null or not GameManager.periodic_phase_due(tick, POLITY_RELATION_REFRESH_TICKS, 53):
		return
	refresh_polity_relations(tick)


func refresh_polity_relations(tick: int = -1) -> void:
	if SettlementMemory == null:
		return
	if tick < 0:
		tick = GameManager.tick_count if GameManager != null else 0
	var formal: Array = []
	for st_any in SettlementMemory.get_formal_settlements():
		if st_any is Dictionary:
			formal.append(st_any)
	if formal.size() < 2:
		return
	_ensure_faction_registry()
	if _faction_registry != null and _faction_registry.has_method("sync_from_settlements"):
		_faction_registry.sync_from_settlements()
	for i in range(formal.size()):
		var a: Dictionary = formal[i] as Dictionary
		var pid_a: int = int(a.get("polity_id", a.get("center_region", -1)))
		if pid_a < 0:
			continue
		for j in range(i + 1, formal.size()):
			var b: Dictionary = formal[j] as Dictionary
			var pid_b: int = int(b.get("polity_id", b.get("center_region", -1)))
			if pid_b < 0 or pid_a == pid_b:
				continue
			var score: int = _compute_polity_relation_score(a, b, tick)
			var pair_key: String = _polity_pair_key(pid_a, pid_b)
			var prev: int = int(_polity_relation_scores.get(pair_key, 0))
			_polity_relation_scores[pair_key] = score
			_polity_relation_last_tick[pair_key] = tick
			_maybe_open_formal_trade_route(pair_key, pid_a, pid_b, a, b, tick)
			_maybe_record_diplomatic_incident(pair_key, pid_a, pid_b, prev, score, a, b, tick)


func _compute_polity_relation_score(a: Dictionary, b: Dictionary, tick: int) -> int:
	var score: int = 0
	var ckr_a: int = int(a.get("center_region", -1))
	var ckr_b: int = int(b.get("center_region", -1))
	if _polities_share_border(ckr_a, ckr_b):
		score -= 12
	else:
		score += 8
	if _recent_skirmish_between(ckr_a, ckr_b, tick):
		score -= 35
	if _trade_route_stub_between(a, b):
		score += 18
	if _formal_trade_pairs.has(_polity_pair_key(int(a.get("polity_id", -1)), int(b.get("polity_id", -1)))):
		score += POLITY_TRADE_RELATION_BONUS
	if _same_ruler_house(a, b):
		score += 22
	return clampi(score, -100, 100)


func _regions_for_center(center_rk: int) -> PackedInt32Array:
	if SettlementMemory == null or center_rk < 0:
		return PackedInt32Array()
	for st_any in SettlementMemory.settlements:
		if st_any is not Dictionary:
			continue
		var st: Dictionary = st_any as Dictionary
		if int(st.get("center_region", -1)) != center_rk:
			continue
		var regs_v: Variant = st.get("regions", null)
		if regs_v is PackedInt32Array:
			return regs_v as PackedInt32Array
		break
	return PackedInt32Array([center_rk])


static func _region_keys_touch(ra: int, rb: int) -> bool:
	var ax: int = ra & 0xFFFF
	var ay: int = (ra >> 16) & 0xFFFF
	var bx: int = rb & 0xFFFF
	var by: int = (rb >> 16) & 0xFFFF
	return (absi(ax - bx) == 1 and ay == by) or (absi(ay - by) == 1 and ax == bx)


func _polities_share_border(ckr_a: int, ckr_b: int) -> bool:
	if ckr_a < 0 or ckr_b < 0:
		return false
	var regions_a: PackedInt32Array = _regions_for_center(ckr_a)
	var regions_b: PackedInt32Array = _regions_for_center(ckr_b)
	if regions_a.is_empty() or regions_b.is_empty():
		return false
	for ra in regions_a:
		for rb in regions_b:
			if _region_keys_touch(int(ra), int(rb)):
				return true
	return false


func _recent_skirmish_between(ckr_a: int, ckr_b: int, tick: int) -> bool:
	if WorldMemory == null or ckr_a < 0 or ckr_b < 0:
		return false
	var window: int = 4000
	for evt_any in WorldMemory.get_recent_events(48):
		if evt_any is not Dictionary:
			continue
		var evt: Dictionary = evt_any as Dictionary
		if str(evt.get("type", "")) != "skirmish_started":
			continue
		var et: int = int(evt.get("tick", evt.get("t", -1)))
		if et >= 0 and tick - et > window:
			continue
		var fa: int = int(evt.get("faction_a_id", -1))
		var fb: int = int(evt.get("faction_b_id", -1))
		if (fa == ckr_a and fb == ckr_b) or (fa == ckr_b and fb == ckr_a):
			return true
		var er: int = int(evt.get("r", -1))
		if er == ckr_a or er == ckr_b:
			return true
	return false


func _trade_route_stub_between(a: Dictionary, b: Dictionary) -> bool:
	var ckr_a: int = int(a.get("center_region", -1))
	var ckr_b: int = int(b.get("center_region", -1))
	var trade_mem: Node = EconomyManager.get_trade_memory()
	if trade_mem != null and trade_mem.has_method("has_active_route_between"):
		if bool(trade_mem.has_active_route_between(ckr_a, ckr_b)):
			return true
	if _polity_pair_has_trade_supplies(a, b):
		return true
	var pop_a: int = int(a.get("population", 0))
	var pop_b: int = int(b.get("population", 0))
	if pop_a < 6 or pop_b < 6:
		return false
	var markets_a: int = int(a.get("markets", 0))
	var markets_b: int = int(b.get("markets", 0))
	if markets_a > 0 or markets_b > 0:
		return true
	return pop_a + pop_b >= 24


func _settlement_stock_food_wood(st: Dictionary) -> Dictionary:
	var rt_v: Variant = st.get("resource_truth", {})
	if rt_v is Dictionary:
		var rt: Dictionary = rt_v as Dictionary
		return {
			"food": int(rt.get("stock_food", 0)),
			"wood": int(rt.get("stock_wood", 0)),
		}
	return {"food": 0, "wood": 0}


func _polity_pair_has_trade_supplies(a: Dictionary, b: Dictionary) -> bool:
	var sa: Dictionary = _settlement_stock_food_wood(a)
	var sb: Dictionary = _settlement_stock_food_wood(b)
	return int(sa.get("food", 0)) > 0 and int(sa.get("wood", 0)) > 0 \
			and int(sb.get("food", 0)) > 0 and int(sb.get("wood", 0)) > 0


func _maybe_open_formal_trade_route(
		pair_key: String,
		pid_a: int,
		pid_b: int,
		st_a: Dictionary,
		st_b: Dictionary,
		tick: int,
) -> void:
	if _formal_trade_pairs.has(pair_key):
		return
	if str(st_a.get("state", "")) != "active" and str(st_a.get("state", "")) != "revivable":
		return
	if str(st_b.get("state", "")) != "active" and str(st_b.get("state", "")) != "revivable":
		return
	if not _polity_pair_has_trade_supplies(st_a, st_b):
		return
	_formal_trade_pairs[pair_key] = true
	st_a["trade_active"] = true
	st_b["trade_active"] = true
	var ckr_a: int = int(st_a.get("center_region", -1))
	var ckr_b: int = int(st_b.get("center_region", -1))
	if SettlementMemory != null:
		for i in range(SettlementMemory.settlements.size()):
			var st_v: Variant = SettlementMemory.settlements[i]
			if st_v is not Dictionary:
				continue
			var st: Dictionary = st_v as Dictionary
			var cr: int = int(st.get("center_region", -1))
			if cr == ckr_a or cr == ckr_b:
				st["trade_active"] = true
				SettlementMemory.settlements[i] = st
	var nm_a: String = str(st_a.get("polity_display_name", st_a.get("name", "realm")))
	var nm_b: String = str(st_b.get("polity_display_name", st_b.get("name", "realm")))
	var bonus_key: String = _polity_pair_key(pid_a, pid_b)
	_polity_relation_scores[bonus_key] = int(_polity_relation_scores.get(bonus_key, 0)) + POLITY_TRADE_RELATION_BONUS
	var trade_mem: Node = EconomyManager.get_trade_memory()
	if trade_mem != null and trade_mem.has_method("ensure_route_between"):
		trade_mem.ensure_route_between(ckr_a, ckr_b, tick)
	if WorldMemory != null:
		WorldMemory.record_event({
			"type": "trade_route_opened",
			"k": WorldMemory.Kind.TRADE_EVENT,
			"tick": tick,
			"polity_a_id": pid_a,
			"polity_b_id": pid_b,
			"polity_a_name": nm_a,
			"polity_b_name": nm_b,
			"center_region_a": ckr_a,
			"center_region_b": ckr_b,
			"relation_bonus": POLITY_TRADE_RELATION_BONUS,
		})


func _same_ruler_house(a: Dictionary, b: Dictionary) -> bool:
	if SettlementMemory == null:
		return false
	if not SettlementMemory.has_method("_ruler_house_key_for_settlement"):
		return false
	var house_a: String = str(SettlementMemory.call("_ruler_house_key_for_settlement", a))
	var house_b: String = str(SettlementMemory.call("_ruler_house_key_for_settlement", b))
	return not house_a.is_empty() and house_a == house_b


func get_polity_relation_score(polity_a: int, polity_b: int) -> int:
	return int(_polity_relation_scores.get(_polity_pair_key(polity_a, polity_b), 0))


func relation_attitude_label(score: int) -> String:
	if score <= POLITY_RELATION_WAR_THRESHOLD:
		return "war"
	if score <= -40:
		return "hostile"
	if score < 20:
		return "neutral"
	if score < 60:
		return "cordial"
	return "allied"


## Nearest formal polities to [param focus_center_region] with relation lines for HUD.
func get_nearest_polity_relation_lines(focus_center_region: int, max_lines: int = 3) -> Array[String]:
	var out: Array[String] = []
	if focus_center_region < 0 or SettlementMemory == null or max_lines <= 0:
		return out
	refresh_polity_relations()
	var focus_tile: Vector2i = SettlementPlanner._center_tile_of_region_key(focus_center_region)
	var focus_pid: int = -1
	for st_any in SettlementMemory.get_formal_settlements():
		if st_any is not Dictionary:
			continue
		var st: Dictionary = st_any as Dictionary
		if int(st.get("center_region", -1)) == focus_center_region:
			focus_pid = int(st.get("polity_id", focus_center_region))
			break
	if focus_pid < 0:
		return out
	var ranked: Array = []
	for st_any in SettlementMemory.get_formal_settlements():
		if st_any is not Dictionary:
			continue
		var st: Dictionary = st_any as Dictionary
		var ckr: int = int(st.get("center_region", -1))
		var pid: int = int(st.get("polity_id", ckr))
		if pid < 0 or pid == focus_pid:
			continue
		var other_tile: Vector2i = SettlementPlanner._center_tile_of_region_key(ckr)
		var dist: int = maxi(absi(other_tile.x - focus_tile.x), absi(other_tile.y - focus_tile.y))
		var nm: String = str(st.get("polity_display_name", st.get("name", "realm"))).strip_edges()
		var score: int = get_polity_relation_score(focus_pid, pid)
		ranked.append({"dist": dist, "name": nm, "score": score, "pid": pid})
	ranked.sort_custom(func(x: Dictionary, y: Dictionary) -> bool:
		return int(x.get("dist", 99999)) < int(y.get("dist", 99999))
	)
	for i in range(mini(max_lines, ranked.size())):
		var row: Dictionary = ranked[i] as Dictionary
		var nm2: String = str(row.get("name", "realm"))
		var sc: int = int(row.get("score", 0))
		out.append("%s %s (%+d)" % [nm2, relation_attitude_label(sc), sc])
	return out


func _maybe_record_diplomatic_incident(
		pair_key: String,
		pid_a: int,
		pid_b: int,
		prev_score: int,
		score: int,
		st_a: Dictionary,
		st_b: Dictionary,
		tick: int,
) -> void:
	if WorldMemory == null:
		return
	if prev_score > POLITY_RELATION_WAR_THRESHOLD and score <= POLITY_RELATION_WAR_THRESHOLD:
		var last: int = int(_diplomatic_incident_recorded.get(pair_key, -1))
		if last >= 0 and tick - last < DIPLOMATIC_INCIDENT_COOLDOWN_TICKS:
			return
		_diplomatic_incident_recorded[pair_key] = tick
		var nm_a: String = str(st_a.get("polity_display_name", st_a.get("name", "realm")))
		var nm_b: String = str(st_b.get("polity_display_name", st_b.get("name", "realm")))
		WorldMemory.record_event({
			"type": "diplomatic_incident",
			"k": WorldMemory.Kind.CONFLICT_EVENT,
			"tick": tick,
			"polity_a_id": pid_a,
			"polity_b_id": pid_b,
			"polity_a_name": nm_a,
			"polity_b_name": nm_b,
			"relation_score": score,
			"reason": "war_threshold",
		})
