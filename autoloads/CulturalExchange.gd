extends Node
## CulturalExchange — spread of cultural traits between settlements.
##
## Cultural traits (art style, naming convention, preferred tech branch, religion,
## taboos, governance attitude) propagate through trade routes, migration, warfare,
## and personal relationships. Each settlement has a weighted trait profile that
## shifts toward neighbors over time.
##
## Traits also drift naturally over long periods. Major events (wars, cataclysms,
## founding) can trigger rapid cultural shifts.

const EXCHANGE_INTERVAL: int = 3000
const DRIFT_INTERVAL: int = 10000
const MIGRANT_INFLUENCE_INTERVAL: int = 2000
const CULTURAL_DISTANCE_CACHE_TTL: int = 600

const TRAIT_KEYS: Array[String] = [
	"art_style", "naming_convention", "preferred_tech_branch", "taboo_jobs",
	"religion", "governance_attitude", "festival_cycle", "death_rite"
]

const ART_STYLES: Array[String] = [
	"utilitarian", "ornamental", "abstract", "naturalist", "geometric",
	"symbolic", "minimalist", "grandiose", "folk", "ceremonial"
]

const NAMING_CONVENTIONS: Array[String] = [
	"ancestral", "patronymic", "matronymic", "totemic", "occupational",
	"geographic", "virtue", "honorific", "descriptive", "mythological"
]

const RELIGIONS: Array[String] = [
	"animist", "ancestor_worship", "pantheon", "monotheist", "dualist",
	"nature_spirit", "celestial", "henotheist", "totemist", "secular"
]

const GOVERNANCE_ATTITUDES: Array[String] = [
	"hierarchical", "egalitarian", "gerontocratic", "theocratic", "militaristic",
	"meritocratic", "oligarchic", "democratic", "autocratic", "council"
]

const DEATH_RITES: Array[String] = [
	"cremation", "burial", "sky_exposure", "water_rite", "crypt_storage",
	"tree_hanging", "mummification", "ossuary", "pyre", "sarcophagus"
]

const TABOO_CANDIDATES: Array[String] = [
	"cannibalism", "corpse_waste", "elder_abandonment", "infant_exposure",
	"kin_marriage", "slavery", "blood_sport", "idol_worship", "herbal_sacrifice"
]

signal culture_changed(center: int, trait_key: String, old_value: String, new_value: String)
signal culture_blended(center_a: int, center_b: int, new_trait: String, trait_key: String)
signal culture_conquered(loser_center: int, winner_center: int, trait_key: String, old_value: String, new_value: String)

var _last_exchange_tick: int = -999999
var _last_drift_tick: int = -999999
var _last_migrant_tick: int = -999999
var _cultural_distance_cache: Dictionary = {}
var _cultural_distance_cache_tick: int = -999999

var _settlement_cultures: Dictionary = {}  # center -> {trait_key: value}
var _cultural_influence: Dictionary = {}   # center -> {trait_key: {value: strength}}

func _ready() -> void:
	if GameManager != null:
		GameManager.game_tick.connect(_on_game_tick)
	if EventBus != null:
		EventBus.subscribe(EventBus.EVENT_SETTLEMENT_FOUNDED, self, "_on_settlement_founded")
		EventBus.subscribe("war_declared", self, "_on_war_declared")
		EventBus.subscribe("settlement_conquered", self, "_on_settlement_conquered")

func _exit_tree() -> void:
	if GameManager != null and GameManager.game_tick.is_connected(_on_game_tick):
		GameManager.game_tick.disconnect(_on_game_tick)
	if EventBus != null:
		EventBus.unsubscribe(EventBus.EVENT_SETTLEMENT_FOUNDED, self, "_on_settlement_founded")
		EventBus.unsubscribe("war_declared", self, "_on_war_declared")
		EventBus.unsubscribe("settlement_conquered", self, "_on_settlement_conquered")

func _on_game_tick(tick: int) -> void:
	var sm := get_node_or_null("/root/SettlementMemory")
	if sm == null:
		return
	if tick - _last_exchange_tick >= EXCHANGE_INTERVAL:
		_last_exchange_tick = tick
		_process_cultural_exchange(sm, tick)
	if tick - _last_drift_tick >= DRIFT_INTERVAL:
		_last_drift_tick = tick
		_process_cultural_drift(sm, tick)
	if tick - _last_migrant_tick >= MIGRANT_INFLUENCE_INTERVAL:
		_last_migrant_tick = tick
		_process_migrant_influence(sm, tick)
	if tick - _cultural_distance_cache_tick > CULTURAL_DISTANCE_CACHE_TTL:
		_cultural_distance_cache.clear()
		_cultural_distance_cache_tick = tick

func _on_settlement_founded(payload: Dictionary) -> void:
	var center: int = int(payload.get("center_region", -1))
	if center < 0:
		return
	var tick: int = int(payload.get("tick", 0))
	_initialize_culture(center, tick)

func _on_war_declared(payload: Dictionary) -> void:
	var a: int = int(payload.get("nation_a_id", -1))
	var b: int = int(payload.get("nation_b_id", -1))
	if a < 0 or b < 0:
		return
	_cultural_distance_cache.clear()
	_cultural_distance_cache_tick = -999999

func _on_settlement_conquered(payload: Dictionary) -> void:
	var loser: int = int(payload.get("loser_center", -1))
	var winner: int = int(payload.get("winner_center", -1))
	if loser < 0 or winner < 0:
		return
	var sm := get_node_or_null("/root/SettlementMemory")
	if sm == null:
		return
	var tik: int = int(payload.get("tick", 0))
	var loser_traits: Dictionary = _load_or_init_traits(loser, sm, tik)
	var winner_traits: Dictionary = _load_or_init_traits(winner, sm, tik)
	for key in TRAIT_KEYS:
		var wv: String = str(winner_traits.get(key, ""))
		var lv: String = str(loser_traits.get(key, ""))
		if wv != "" and lv != "" and wv != lv:
			var seed_key: StringName = StringName("conquest_culture:%d:%s" % [loser, key])
			var replace_chance: float = WorldRNG.unit(seed_key, tik)
			if replace_chance > 0.35:
				loser_traits[key] = wv
				culture_changed.emit(loser, key, lv, wv)
				culture_conquered.emit(loser, winner, key, lv, wv)
				_record_event("culture_conquered", loser, key, lv, wv, tik)
	_settlement_cultures[loser] = loser_traits
	_save_traits_to_settlement(sm, loser, loser_traits)

func _process_cultural_exchange(sm: Node, tick: int) -> void:
	var settlements: Array = _get_all_settlements(sm)
	if settlements.is_empty():
		return
	for st in settlements:
		var center: int = int(st.get("center_region", -1))
		if center < 0:
			continue
		var my_traits: Dictionary = _load_or_init_traits(center, sm, tick)
		var neighbors: Array[Dictionary] = _find_nearby_settlements(center, sm, 15)
		if neighbors.is_empty():
			continue
		for nst in neighbors:
			var ncenter: int = int(nst.get("center_region", -1))
			var their_traits: Dictionary = _load_or_init_traits(ncenter, sm, tick)
			var influence: float = _calculate_influence(st, nst, tick)
			if influence <= 0.0:
				continue
			for key in TRAIT_KEYS:
				var my_val: String = str(my_traits.get(key, ""))
				var their_val: String = str(their_traits.get(key, ""))
				if my_val == "" or their_val == "" or my_val == their_val:
					continue
				var seed_key: StringName = StringName("cultural_exchange:%d:%s" % [center, key])
				var swap_chance: float = influence * WorldRNG.unit(seed_key, tick + center)
				if swap_chance > 0.55:
					var old_val: String = my_val
					my_traits[key] = their_val
					culture_changed.emit(center, key, old_val, their_val)
					_record_event("cultural_exchange", center, key, old_val, their_val, tick)
		_settlement_cultures[center] = my_traits
		_save_traits_to_settlement(sm, center, my_traits)

func _process_cultural_drift(sm: Node, tick: int) -> void:
	var settlements: Array = _get_all_settlements(sm)
	if settlements.is_empty():
		return
	var global_era: int = _get_global_era()
	for st in settlements:
		var center: int = int(st.get("center_region", -1))
		if center < 0:
			continue
		var traits: Dictionary = _load_or_init_traits(center, sm, tick)
		var drifted: bool = false
		for key in TRAIT_KEYS:
			var pool: Array[String] = _trait_pool_for_key(key)
			if pool.is_empty():
				continue
			var seed_key: StringName = StringName("cultural_drift:%d:%d:%s" % [center, tick / DRIFT_INTERVAL, key])
			var drift_chance: float = WorldRNG.unit(seed_key, tick)
			var drift_rate: float = 0.08 + float(global_era) * 0.02
			if drift_chance < drift_rate:
				var old_val: String = str(traits.get(key, ""))
				var new_val: String = pool[WorldRNG.stream_seed(StringName("drift_pick:%d:%s" % [center, key]), tick) % pool.size()]
				if new_val != old_val:
					traits[key] = new_val
					drifted = true
					culture_changed.emit(center, key, old_val, new_val)
					_record_event("cultural_drift", center, key, old_val, new_val, tick)
		if drifted:
			_settlement_cultures[center] = traits
			_save_traits_to_settlement(sm, center, traits)

func _process_migrant_influence(sm: Node, tick: int) -> void:
	var settlements: Array = _get_all_settlements(sm)
	if settlements.size() < 2:
		return
	for st in settlements:
		var center: int = int(st.get("center_region", -1))
		if center < 0:
			continue
		var traits: Dictionary = _load_or_init_traits(center, sm, tick)
		var migrant_sources: Array[int] = _find_migrant_source_settlements(center, sm)
		if migrant_sources.is_empty():
			continue
		var changed: bool = false
		for src in migrant_sources:
			var src_traits: Dictionary = _load_or_init_traits(src, sm, tick)
			for key in TRAIT_KEYS:
				var my_val: String = str(traits.get(key, ""))
				var src_val: String = str(src_traits.get(key, ""))
				if my_val == "" or src_val == "" or my_val == src_val:
					continue
				var seed: StringName = StringName("migrant_influence:%d:%d:%s" % [center, src, key])
				if WorldRNG.unit(seed, tick) < 0.03:
					traits[key] = src_val
					changed = true
					_record_event("migrant_influence", center, key, my_val, src_val, tick)
		if changed:
			_settlement_cultures[center] = traits
			_save_traits_to_settlement(sm, center, traits)

func _initialize_culture(center: int, tick: int) -> void:
	if _settlement_cultures.has(center):
		return
	var sm := get_node_or_null("/root/SettlementMemory")
	var traits: Dictionary = {}
	for key in TRAIT_KEYS:
		var pool: Array[String] = _trait_pool_for_key(key)
		if pool.is_empty():
			continue
		var seed: StringName = StringName("init_culture:%d:%s" % [center, key])
		var idx: int = WorldRNG.stream_seed(seed, tick) % pool.size()
		traits[key] = pool[idx]
	_settlement_cultures[center] = traits
	if sm != null:
		_save_traits_to_settlement(sm, center, traits)
	_record_event("culture_established", center, "all", "", str(traits), tick)

func _load_or_init_traits(center: int, sm: Node, tick: int) -> Dictionary:
	if _settlement_cultures.has(center):
		return _settlement_cultures[center].duplicate()
	var st: Dictionary = _find_settlement_by_center(sm, center)
	if st.is_empty():
		return {}
	var trad: Variant = st.get("tradition", {})
	if trad is Dictionary and not (trad as Dictionary).is_empty():
		_settlement_cultures[center] = (trad as Dictionary).duplicate()
		return _settlement_cultures[center].duplicate()
	_initialize_culture(center, tick)
	return _settlement_cultures.get(center, {}).duplicate()

func _save_traits_to_settlement(sm: Node, center: int, traits: Dictionary) -> void:
	var st: Dictionary = _find_settlement_by_center(sm, center)
	if st.is_empty():
		return
	st["tradition"] = traits.duplicate()

func _find_settlement_by_center(sm: Node, center: int) -> Dictionary:
	for st_v in sm.settlements:
		if not (st_v is Dictionary):
			continue
		if int((st_v as Dictionary).get("center_region", -1)) == center:
			return st_v as Dictionary
	return {}

func _get_all_settlements(sm: Node) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for st_v in sm.settlements:
		if st_v is Dictionary:
			out.append(st_v as Dictionary)
	return out

func _find_nearby_settlements(center: int, sm: Node, radius: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var cx: int = center % 256
	var cy: int = center / 256
	for st_v in sm.settlements:
		if not (st_v is Dictionary):
			continue
		var sc: int = int((st_v as Dictionary).get("center_region", -1))
		if sc == center or sc < 0:
			continue
		var ox: int = sc % 256
		var oy: int = sc / 256
		var dist: float = Vector2(cx, cy).distance_to(Vector2(ox, oy))
		if dist <= float(radius):
			out.append(st_v as Dictionary)
	return out

func _find_migrant_source_settlements(center: int, sm: Node) -> Array[int]:
	var out: Array[int] = []
	var cx: int = center % 256
	var cy: int = center / 256
	for st_v in sm.settlements:
		if not (st_v is Dictionary):
			continue
		var sc: int = int((st_v as Dictionary).get("center_region", -1))
		if sc == center or sc < 0:
			continue
		var ox: int = sc % 256
		var oy: int = sc / 256
		var dist: float = Vector2(cx, cy).distance_to(Vector2(ox, oy))
		if dist <= 30.0:
			var pop: int = int((st_v as Dictionary).get("population", 0))
			if pop > 0:
				out.append(sc)
	return out

func _calculate_influence(st: Dictionary, nst: Dictionary, tick: int) -> float:
	var base: float = 0.02
	var ds := get_node_or_null("/root/DiplomacySystem")
	var nbs := get_node_or_null("/root/NationBorderSystem")
	var my_nation: int = _get_nation(st)
	var their_nation: int = _get_nation(nst)
	if ds != null and nbs != null:
		if my_nation >= 0 and their_nation >= 0:
			if nbs.has_method("are_nations_trading") and nbs.are_nations_trading(my_nation, their_nation):
				base += 0.04
			if nbs.has_method("are_nations_at_war") and nbs.are_nations_at_war(my_nation, their_nation):
				base += 0.03
	var cultural_distance: float = _compute_cultural_distance(st, nst)
	if cultural_distance < 0.3:
		base += 0.02
	elif cultural_distance > 0.7:
		base += 0.01
	return clampf(base, 0.0, 0.15)

func _compute_cultural_distance(st: Dictionary, nst: Dictionary) -> float:
	var cache_key: int = int(st.get("center_region", -1)) * 10000 + int(nst.get("center_region", -1))
	if _cultural_distance_cache.has(cache_key):
		return float(_cultural_distance_cache[cache_key])
	var a_traits: Dictionary = _get_traits(st)
	var b_traits: Dictionary = _get_traits(nst)
	var matches: int = 0
	var total: int = 0
	for key in TRAIT_KEYS:
		var av: String = str(a_traits.get(key, ""))
		var bv: String = str(b_traits.get(key, ""))
		if av != "" and bv != "":
			total += 1
			if av == bv:
				matches += 1
	if total == 0:
		return 0.5
	var dist: float = 1.0 - (float(matches) / float(total))
	_cultural_distance_cache[cache_key] = dist
	return dist

func _get_traits(st: Dictionary) -> Dictionary:
	var trad: Variant = st.get("tradition", {})
	if trad is Dictionary:
		return trad as Dictionary
	return {}

func _get_nation(st: Dictionary) -> int:
	var nbs := get_node_or_null("/root/NationBorderSystem")
	if nbs == null:
		return -1
	var center: int = int(st.get("center_region", -1))
	if nbs.has_method("get_nation_at_region"):
		return nbs.get_nation_at_region(center)
	return -1

func _get_global_era() -> int:
	var te := get_node_or_null("/root/TechnologyEras")
	if te != null and te.has_method("get_global_era"):
		return te.get_global_era()
	return 0

func _trait_pool_for_key(key: String) -> Array[String]:
	match key:
		"art_style": return ART_STYLES
		"naming_convention": return NAMING_CONVENTIONS
		"religion": return RELIGIONS
		"governance_attitude": return GOVERNANCE_ATTITUDES
		"death_rite": return DEATH_RITES
		"taboo_jobs": return TABOO_CANDIDATES
		_:
			return []

func _record_event(type: String, center: int, trait_key: String, old_val: String, new_val: String, tick: int) -> void:
	var wm := get_node_or_null("/root/WorldMemory")
	if wm == null or not wm.has_method("record_event"):
		return
	wm.record_event({
		"type": type,
		"center": center,
		"trait_key": trait_key,
		"old_value": old_val,
		"new_value": new_val,
		"tick": tick,
	})

func get_cultural_profile(center: int) -> Dictionary:
	var sm := get_node_or_null("/root/SettlementMemory")
	if sm == null:
		return _settlement_cultures.get(center, {})
	return _load_or_init_traits(center, sm, 0)

func get_cultural_distance(center_a: int, center_b: int) -> float:
	if center_a == center_b:
		return 0.0
	var sm := get_node_or_null("/root/SettlementMemory")
	if sm == null:
		return 0.5
	var st_a: Dictionary = _find_settlement_by_center(sm, center_a)
	var st_b: Dictionary = _find_settlement_by_center(sm, center_b)
	if st_a.is_empty() or st_b.is_empty():
		return 0.5
	return _compute_cultural_distance(st_a, st_b)

func get_cultural_diversity_score() -> float:
	var sm := get_node_or_null("/root/SettlementMemory")
	if sm == null:
		return 0.0
	var settlements: Array = _get_all_settlements(sm)
	if settlements.size() < 2:
		return 0.0
	var total_dist: float = 0.0
	var pairs: int = 0
	for i in range(settlements.size()):
		for j in range(i + 1, settlements.size()):
			var si: Dictionary = settlements[i] as Dictionary
			var sj: Dictionary = settlements[j] as Dictionary
			if si.is_empty() or sj.is_empty():
				continue
			total_dist += _compute_cultural_distance(si, sj)
			pairs += 1
	if pairs == 0:
		return 0.0
	return total_dist / float(pairs)

func get_trait_value(center: int, trait_key: String) -> String:
	var profile: Dictionary = get_cultural_profile(center)
	return str(profile.get(trait_key, ""))

func set_trait(center: int, trait_key: String, value: String, tick: int) -> void:
	if not (trait_key in TRAIT_KEYS):
		return
	var sm := get_node_or_null("/root/SettlementMemory")
	var traits: Dictionary = _load_or_init_traits(center, sm, tick)
	var old_val: String = str(traits.get(trait_key, ""))
	if old_val == value:
		return
	traits[trait_key] = value
	_settlement_cultures[center] = traits
	if sm != null:
		_save_traits_to_settlement(sm, center, traits)
	culture_changed.emit(center, trait_key, old_val, value)
	_record_event("trait_set", center, trait_key, old_val, value, tick)

func get_all_settlements_with_trait(trait_key: String, trait_value: String) -> Array[int]:
	var sm := get_node_or_null("/root/SettlementMemory")
	if sm == null:
		return []
	var out: Array[int] = []
	var settlements: Array = _get_all_settlements(sm)
	for st in settlements:
		var center: int = int(st.get("center_region", -1))
		if center < 0:
			continue
		var traits: Dictionary = _load_or_init_traits(center, sm, 0)
		if str(traits.get(trait_key, "")) == trait_value:
			out.append(center)
	return out

func export_cultural_map() -> Dictionary:
	var sm := get_node_or_null("/root/SettlementMemory")
	if sm == null:
		return {}
	var out: Dictionary = {}
	var settlements: Array = _get_all_settlements(sm)
	for st in settlements:
		var center: int = int(st.get("center_region", -1))
		if center < 0:
			continue
		out[center] = _load_or_init_traits(center, sm, 0).duplicate()
	return out

func get_stats() -> Dictionary:
	return {
		"tracked_settlements": _settlement_cultures.size(),
		"cultural_distance_avg": get_cultural_diversity_score(),
	}

func clear() -> void:
	_settlement_cultures.clear()
	_cultural_influence.clear()
	_cultural_distance_cache.clear()
	_last_exchange_tick = -999999
	_last_drift_tick = -999999
	_last_migrant_tick = -999999
	_cultural_distance_cache_tick = -999999

func get_save_state() -> Dictionary:
	return {
		"settlement_cultures": _settlement_cultures.duplicate(true),
		"last_exchange_tick": _last_exchange_tick,
		"last_drift_tick": _last_drift_tick,
		"last_migrant_tick": _last_migrant_tick,
	}

func load_state(state: Dictionary) -> void:
	clear()
	if state.has("settlement_cultures"):
		_settlement_cultures = state["settlement_cultures"].duplicate(true)
	if state.has("last_exchange_tick"):
		_last_exchange_tick = int(state["last_exchange_tick"])
	if state.has("last_drift_tick"):
		_last_drift_tick = int(state["last_drift_tick"])
	if state.has("last_migrant_tick"):
		_last_migrant_tick = int(state["last_migrant_tick"])
