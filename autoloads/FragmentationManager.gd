extends Node
## Deterministic out-migration when a large, low-pressure, GROW cluster can shed population.
## Settlements stay derived; this moves pawns and logs [WorldMemory] events.

const POP_THRESHOLD: int = 12
const PRESSURE_THRESHOLD: float = 0.35
const COOLDOWN_TICKS: int = 80000
## 10% of pawns, at least 1, at most half (deterministic)
const RELOC_FRACTION_NUM: int = 1
const RELOC_FRACTION_DEN: int = 10

## center_region_key (int) -> int last tick we fragmented
var _last_fragment_tick: Dictionary = {}


func clear() -> void:
	_last_fragment_tick.clear()


func check_and_fragment(world: World, main: Node2D) -> void:
	if world == null or not is_instance_valid(world) or world.data == null or main == null:
		return
	if not main.has_method("society_relocate_pawns_count"):
		return
	var now: int = GameManager.tick_count
	for s in SettlementMemory.settlements:
		if s is not Dictionary:
			continue
		var d: Dictionary = s as Dictionary
		var ckr: int = int(d.get("center_region", -1))
		if ckr < 0:
			continue
		if str(d.get("state", "")) != "dormant" and str(d.get("state", "")) != "revivable":
			continue
		var reg0: Variant = d.get("regions", null)
		if not (reg0 is PackedInt32Array):
			continue
		var pack0: PackedInt32Array = reg0 as PackedInt32Array
		if pack0.is_empty():
			continue
		if int(MemoryManager.get_settlement_intent().get(ckr, MemoryManager.INTENT_HOLD)) != MemoryManager.INTENT_GROW:
			continue
		var base_pressure: float = float(MemoryManager.get_settlement_pressure().get(ckr, 1.0))
		var eg_bias: Dictionary = _egregore_migration_bias(ckr)
		var pressure_gate: float = PRESSURE_THRESHOLD + float(eg_bias.get("pressure_gate_delta", 0.0))
		if base_pressure >= pressure_gate:
			continue
		var pop: int = int(main.settlement_planner_count_pawns_in_regions(pack0))
		var pop_threshold: int = POP_THRESHOLD + int(eg_bias.get("pop_threshold_delta", 0))
		if pop < pop_threshold:
			continue
		if _last_fragment_tick.has(ckr) and (now - int(_last_fragment_tick[ckr])) < COOLDOWN_TICKS:
			continue
		var target: Vector2i = find_outward_passable(world, ckr, pack0)
		if target.x < 0:
			continue
		var nmove: int = maxi(1, (pop * RELOC_FRACTION_NUM) / RELOC_FRACTION_DEN)
		nmove += int(eg_bias.get("move_delta", 0))
		nmove = mini(nmove, int(pop / 2))
		var na: int = int(main.society_relocate_pawns_count(pack0, target, nmove, ckr, "fragment"))
		if na < 1:
			continue
		_last_fragment_tick[ckr] = now
		WorldMemory.record_social(
				now, int(WorldMemory.Kind.SOCIAL_FRAGMENT), ckr, target, na, pack0
		)
		WorldMemory.record_event({
			"type": "egregore_fragmentation_applied",
			"tick": now,
			"settlement_id": ckr,
			"moved": na,
			"base_pressure": base_pressure,
			"pressure_gate": pressure_gate,
			"pop_threshold": pop_threshold,
			"eg_move_delta": int(eg_bias.get("move_delta", 0)),
		})
		if OS.is_debug_build():
			print(
					"[Fragment] moved=%d  from_ckr=%d  target=%s  tick=%d" % [na, ckr, target, now]
			)


func _egregore_migration_bias(settlement_id: int) -> Dictionary:
	if EgregoreMemory == null:
		return {"pressure_gate_delta": 0.0, "pop_threshold_delta": 0, "move_delta": 0}
	var fear: float = float(EgregoreMemory.get_settlement_pressure(settlement_id, "fear"))
	var vengeance: float = float(EgregoreMemory.get_settlement_pressure(settlement_id, "vengeance"))
	var cooperation: float = float(EgregoreMemory.get_settlement_pressure(settlement_id, "cooperation"))
	var care: float = float(EgregoreMemory.get_settlement_pressure(settlement_id, "care"))
	var discipline: float = float(EgregoreMemory.get_settlement_pressure(settlement_id, "discipline"))
	var norms: Array = EgregoreMemory.get_settlement_active_norms(settlement_id) if EgregoreMemory.has_method("get_settlement_active_norms") else []

	var threat: float = fear + vengeance
	var cohesion_guard: float = cooperation + care + discipline
	var pressure_delta: float = 0.0
	var pop_delta: int = 0
	var move_delta: int = 0

	if threat > 16.0:
		pressure_delta += 0.08
		move_delta += 1
	elif threat > 10.0:
		pressure_delta += 0.04
	if cohesion_guard > 18.0:
		pressure_delta -= 0.05
		pop_delta += 2
		move_delta -= 1
	elif cohesion_guard > 12.0:
		pressure_delta -= 0.02
		pop_delta += 1

	for n in norms:
		var ns: String = str(n)
		if ns == "mutual_aid" or ns == "scholar_path":
			pop_delta += 1
			move_delta -= 1
		elif ns == "martial_code" or ns == "austerity_rite":
			move_delta += 1
		elif ns == "market_charter":
			pressure_delta += 0.02

	return {
		"pressure_gate_delta": clampf(pressure_delta, -0.12, 0.12),
		"pop_threshold_delta": clampi(pop_delta, -3, 4),
		"move_delta": clampi(move_delta, -2, 3),
	}


func _center_tile(ck: int) -> Vector2i:
	var rx: int = int(ck) & 0xFFFF
	var ry: int = (int(ck) >> 16) & 0xFFFF
	return Vector2i(rx * 16 + 8, ry * 16 + 8)


func _region_pack_has_tile(world: World, pack0: PackedInt32Array, t: Vector2i) -> bool:
	if not world.data.in_bounds(t.x, t.y):
		return false
	var rkm: int = WorldMemory._region_key(t.x, t.y)
	for j in range(pack0.size()):
		if int(pack0[j]) == rkm:
			return true
	return false


## Passable, main component, not sacred, outside the settlement’s regions, spawnable biome.
func find_outward_passable(
		world: World, center_rk: int, pack0: PackedInt32Array
) -> Vector2i:
	var c: Vector2i = _center_tile(center_rk)
	var comp: int = world.pathfinder.largest_component_id()
	if comp < 0:
		return Vector2i(-1, -1)
	var cands: Array[Vector2i] = []
	for dy in range(-5, 6):
		for dx in range(-5, 6):
			var t: Vector2i = Vector2i(c.x + dx, c.y + dy)
			if not world.data.in_bounds(t.x, t.y):
				continue
			if not world.pathfinder.is_passable(t):
				continue
			if world.pathfinder.component_of(t) != comp:
				continue
			if MemoryManager.get_sacred_memory().is_tile_sacred(t):
				continue
			if _region_pack_has_tile(world, pack0, t):
				continue
			if not PawnSpawner.SPAWNABLE_BIOMES.has(world.data.get_biome(t.x, t.y)):
				continue
			cands.append(t)
	if cands.is_empty():
		return Vector2i(-1, -1)
	cands.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return (a.y * WorldData.WIDTH + a.x) < (b.y * WorldData.WIDTH + b.x)
	)
	return cands[0]
