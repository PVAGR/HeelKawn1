extends Node
## Deterministic sub-group fission: HOLD + long duration + “conflict” myth proxy + high population.
## Same as [FragmentationManager]: pawns only; no forked [SettlementMemory] clusters.
const MIN_POP: int = 8
## 10 in-game days at [DayNightCycle.TICKS_PER_DAY] (600)
const MIN_HOLD_TICKS: int = 10 * 600
const CONFLICT_THRESHOLD: float = 0.6
const COOLDOWN_TICKS: int = 100_000
const SCHISM_MOVE_DIV: int = 3
const SCHISM_MOVE_MIN: int = 1

var _last_schism_tick: Dictionary = {}
## center_rk -> tick when this center was first seen in HOLD in this run
var _hold_since: Dictionary = {}
var _last_intent: Dictionary = {}


func clear() -> void:
	_last_schism_tick.clear()
	_hold_since.clear()
	_last_intent.clear()


func _sync_hold_timers() -> void:
	var now1: int = GameManager.tick_count
	for s in SettlementMemory.settlements:
		if s is not Dictionary:
			continue
		var d: Dictionary = s
		var ckr1: int = int(d.get("center_region", -1))
		if ckr1 < 0:
			continue
		var it: int = int(IntentMemory.get_settlement_intent().get(ckr1, IntentMemory.INTENT_HOLD))
		if not _last_intent.has(ckr1):
			_last_intent[ckr1] = it
			if it == IntentMemory.INTENT_HOLD:
				_hold_since[ckr1] = now1
			else:
				_hold_since[ckr1] = -1_000_000_000
			continue
		var prev: int = int(_last_intent[ckr1])
		if it != prev:
			_last_intent[ckr1] = it
			if it == IntentMemory.INTENT_HOLD:
				_hold_since[ckr1] = now1
			else:
				_hold_since[ckr1] = -1_000_000_000


func check_and_schism(world: World, main: Node2D) -> void:
	if world == null or not is_instance_valid(world) or world.data == null or main == null:
		return
	if not main.has_method("society_relocate_pawns_count"):
		return
	_sync_hold_timers()
	var now: int = GameManager.tick_count
	for s in SettlementMemory.settlements:
		if s is not Dictionary:
			continue
		var d: Dictionary = s as Dictionary
		var ckr: int = int(d.get("center_region", -1))
		if ckr < 0:
			continue
		var st: String = str(d.get("state", ""))
		if st != "dormant" and st != "revivable":
			continue
		var reg0: Variant = d.get("regions", null)
		if not (reg0 is PackedInt32Array):
			continue
		var pack0: PackedInt32Array = reg0 as PackedInt32Array
		if pack0.is_empty():
			continue
		if int(IntentMemory.get_settlement_intent().get(ckr, IntentMemory.INTENT_HOLD)) != IntentMemory.INTENT_HOLD:
			continue
		var h0: int = int(_hold_since.get(ckr, -1_000_000_000))
		if h0 < 0 or (now - h0) < MIN_HOLD_TICKS:
			continue
		if MythMemory.get_conflict_intensity(ckr) < CONFLICT_THRESHOLD:
			continue
		var pop: int = int(main.settlement_planner_count_pawns_in_regions(pack0))
		if pop < MIN_POP:
			continue
		if _last_schism_tick.has(ckr) and (now - int(_last_schism_tick[ckr])) < COOLDOWN_TICKS:
			continue
		var target: Vector2i = FragmentationManager.find_outward_passable(world, ckr, pack0)
		if target.x < 0:
			continue
		var to_move: int = maxi(SCHISM_MOVE_MIN, int(pop / SCHISM_MOVE_DIV))
		to_move = mini(to_move, int(pop / 2))
		var na: int = int(main.society_relocate_pawns_count(pack0, target, to_move, ckr, "schism"))
		if na < 1:
			continue
		_last_schism_tick[ckr] = now
		WorldMemory.record_social(
				now, int(WorldMemory.Kind.SOCIAL_SCHISM), ckr, target, na, pack0
		)
		if OS.is_debug_build():
			print(
					"[Schism] moved=%d  from_ckr=%d  target=%s  tick=%d" % [na, ckr, target, now]
			)
