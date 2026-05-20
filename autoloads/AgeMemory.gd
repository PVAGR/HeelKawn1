extends Node
## v1: Derived, not saved — one slow epochal layer: Age advances on sustained pressure, not a reset.
## Read-only: [WorldMemory], [SettlementMemory], [TradeMemory], [MythMemory], [GameManager]. No RNG; no per-tick work outside [recompute] cadence.

const AGE_MIN_TICKS: int = 120_000
const RECOMPUTE_EVERY_TICKS: int = 10_000
## No T2 trade-route tiles for this long counts as "trade collapsed" (must have had T2 before; see [TradeMemory]).
const LONG_TRADE_NO_T2: int = 100_000

## Internal keys; read via getters only. For inspection/debug (no UI in v1).
const SIG_SA: StringName = &"s_alive"
const SIG_SD: StringName = &"s_dead"
const SIG_TD: StringName = &"t_dense"
const SIG_DC: StringName = &"d_cult"

## Trade route density label for [age_signature] (0=low, 1=med, 2=high)
const TDM_LOW: int = 0
const TDM_MED: int = 1
const TDM_HIGH: int = 2

## Dominant built culture in [age_signature] (matches [SettlementPlanner] order).
const DC_OPEN: int = 0
const DC_CAUTIOUS: int = 1
const DC_DEF: int = 2

var current_age_index: int = 0
var age_start_tick: int = 0
## Filled on each Age transition; not saved.
var age_signature: Dictionary = {}


func _ready() -> void:
	if age_start_tick == 0 and GameManager.tick_count >= 0:
		age_start_tick = GameManager.tick_count


func clear() -> void:
	current_age_index = 0
	age_start_tick = GameManager.tick_count
	age_signature = {}


static func get_current_age_index() -> int:
	var inst: AgeMemory = Engine.get_singleton("AgeMemory") as AgeMemory
	if inst == null:
		return 0
	return inst.current_age_index


## 0..~0.1 — multiply into a gray lerp at end of world tint stack (very subtle per Age).
func get_global_age_tint_strength() -> float:
	return minf(0.085, 0.007 * float(1 + current_age_index))


## Negative: lower ambient carrier slightly (heavier) as Ages stack.
func get_ambient_freq_shift() -> float:
	return -minf(3.2, 0.38 * float(1 + current_age_index))


## [recompute] may advance the Age, refresh terrain, and rebuild [age_signature].
func recompute() -> void:
	# TradeMemory.update_t2_collapse_cursor() - REMOVED: function doesn't exist
	var tick: int = GameManager.tick_count
	if age_start_tick == 0:
		age_start_tick = tick
	if tick - age_start_tick < AGE_MIN_TICKS:
		return
	if not _all_transition_conditions(tick):
		return
	_advance(tick)
	_request_world_tint_refresh()


func _all_transition_conditions(_tick: int) -> bool:
	if not _cond_pressure():
		return false
	if not _cond_myth_feared_dominant():
		return false
	return true


func _cond_settlement_stagnation() -> bool:
	var n: int = 0
	var da: int = 0
	for s_any in SettlementMemory.get_formal_settlements():
		if not (s_any is Dictionary):
			continue
		var s: Dictionary = s_any as Dictionary
		n += 1
		var st: String = str(s.get("state", ""))
		if st == "dormant" or SettlementMemory.is_collapsed_state(st):
			da += 1
	if n <= 0:
		return false
	# More than 50% dormant or abandoned: (d+a) * 2 > n
	return da * 2 > n


func _cond_trade_collapsed() -> bool:
	if TradeMemory.count_t2_tiles() > 0:
		return false
	var last_e: int = TradeMemory.get_last_tick_t2_existed()
	if last_e < 0:
		# No major route tier has ever been observed this session; not a "collapse".
		return false
	return GameManager.tick_count - last_e >= LONG_TRADE_NO_T2


func _cond_pressure() -> bool:
	return _cond_settlement_stagnation() or _cond_trade_collapsed()


func _cond_myth_feared_dominant() -> bool:
	var feared: int = 0
	var revered: int = 0
	for s_any2 in SettlementMemory.get_formal_settlements():
		if not (s_any2 is Dictionary):
			continue
		var s2: Dictionary = s_any2 as Dictionary
		var ckr: int = int(s2.get("center_region", -1))
		if ckr < 0:
			continue
		var m: int = MythMemory.get_region_myth_state(ckr)
		if m == 1:
			feared += 1
		elif m == -1:
			revered += 1
	return feared > revered


func _advance(tick: int) -> void:
	var ended_a: int = current_age_index
	var w0: World = _find_world_for_remnant()
	if w0 != null and is_instance_valid(w0):
		RemnantMemory.on_age_ended(ended_a, w0)
	current_age_index += 1
	age_start_tick = tick
	_build_signature()


static func _find_world_for_remnant() -> World:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	for n0 in tree.get_nodes_in_group("colony_world"):
		if n0 is World:
			return n0 as World
	return null


func _build_signature() -> void:
	var alive: int = 0
	var dead: int = 0
	var nopen: int = 0
	var ncau: int = 0
	var ndef: int = 0
	for s3_any in SettlementMemory.get_formal_settlements():
		if not (s3_any is Dictionary):
			continue
		var s3: Dictionary = s3_any as Dictionary
		var st3: String = str(s3.get("state", ""))
		if st3 == "abandoned" or st3 == "permanently_abandoned":
			dead += 1
		else:
			alive += 1
		var sc: int = int(s3.get("scar_max", 0))
		var rmin: int = int(s3.get("reputation_min", 0))
		var c: int = SettlementPlanner._derive_culture_type_v1_for_age(sc, rmin, 0)
		match c:
			SettlementPlanner.CULTURE_OPEN:
				nopen += 1
			SettlementPlanner.CULTURE_DEFENSIVE:
				ndef += 1
			_:
				ncau += 1
	var dom: int = DC_CAUTIOUS
	if nopen >= ncau and nopen >= ndef:
		dom = DC_OPEN
	if ndef >= nopen and ndef >= ncau:
		dom = DC_DEF
	var tdm: int = _classify_trade_density(TradeMemory.count_route_tiles())
	age_signature = {
		SIG_SA: alive,
		SIG_SD: dead,
		SIG_TD: tdm,
		SIG_DC: dom,
	}


static func _classify_trade_density(route_tiles: int) -> int:
	if route_tiles < 12:
		return TDM_LOW
	if route_tiles < 64:
		return TDM_MED
	return TDM_HIGH


func _request_world_tint_refresh() -> void:
	var tree1: SceneTree = Engine.get_main_loop() as SceneTree
	if tree1 == null:
		return
	for n in tree1.get_nodes_in_group("colony_world"):
		if n is World:
			(n as World).refresh_terrain_scar_tint()
			return
