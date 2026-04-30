extends Node
## v1: Deterministic inter-settlement trade as [Job.Type.TRADE_HAUL] (pickup + long haul). No RNG; not every tick.
## Reads: SettlementMemory, StockpileManager, World pathfinder, JobManager, RoadMemory (via same paths as pawns).

const TRADE_INTERVAL_TICKS: int = 5000
const SURPLUS_THRESHOLD: int = 30
const NEED_THRESHOLD: int = 10
const MAX_TRADE_DISTANCE: int = 6
const TRADE_BATCH: int = 5

const _ITEM_ORDER: Array[int] = [
	Item.Type.BERRY,
	Item.Type.STONE,
	Item.Type.WOOD,
	Item.Type.MEAT,
]

var _last_plan_tick: int = -1_000_000_000


func plan(world: World, _main: Node, from_memory_flush: bool) -> void:
	if world == null or not is_instance_valid(world) or world.data == null or world.pathfinder == null:
		return
	if not from_memory_flush:
		var t0: int = GameManager.tick_count
		if t0 - _last_plan_tick < TRADE_INTERVAL_TICKS:
			return
	_last_plan_tick = GameManager.tick_count
	if SettlementMemory.settlements.is_empty():
		return
	var settlements: Array = SettlementMemory.get_settlements()
	settlements.sort_custom(_sort_settlements_by_intent_then_center)
	var used: Dictionary = {}
	for a_any in settlements:
		if not (a_any is Dictionary):
			continue
		var a: Dictionary = a_any as Dictionary
		var a_center: int = int(a.get("center_region", -1))
		var a_intent: int = _intent_for_center(a_center)
		if a_center < 0 or used.has(a_center):
			continue
		if SettlementMemory.is_collapsed_state(str(a.get("state", ""))):
			continue
		if a_intent == IntentMemory.INTENT_ABANDON:
			continue
		if not (a.get("regions", null) is PackedInt32Array):
			continue
		var a_regions: PackedInt32Array = a["regions"] as PackedInt32Array
		if a_regions.is_empty():
			continue
		var a_region_want: Dictionary = _region_set(a_regions)
		for R in _ITEM_ORDER:
			if _settlement_item_total(a_region_want, R) <= SURPLUS_THRESHOLD:
				continue
			var from_sp: Stockpile = _first_source_zone(a_region_want, R, world)
			if from_sp == null:
				continue
			var b_pick: Dictionary = _find_best_receiver(
					world, settlements, a, a_center, a_region_want, R, from_sp, used
			)
			if b_pick.is_empty():
				continue
			var b_center: int = int(b_pick["center"])
			var to_sp: Stockpile = b_pick["to_sp"] as Stockpile
			if to_sp == null or not is_instance_valid(to_sp):
				continue
			var work_tile: Vector2i = _first_passable_free_job_tile(world, from_sp)
			if work_tile.x < 0:
				continue
				var j: Job = JobManager.post_trade_haul(
						work_tile, from_sp, to_sp, R, TRADE_BATCH, 0, 3
				)
				if j != null:
					used[a_center] = true
					used[b_center] = true
					# --- RelationalGraph integration: record trade relationship ---
					if Engine.has_singleton("RelationalGraph"):
						var rg = Engine.get_singleton("RelationalGraph")
						var edge_data = {
							"item": R,
							"batch": TRADE_BATCH,
							"from": a_center,
							"to": b_center,
							"tick": GameManager.tick_count
						}
						rg.add_edge(a_center, b_center, "trade", edge_data)
				break


static func _sort_settlements_by_intent_then_center(ka: Variant, kb: Variant) -> bool:
	if not (ka is Dictionary) or not (kb is Dictionary):
		return false
	var ca: int = int((ka as Dictionary).get("center_region", 0x7FFFFFFF))
	var cb: int = int((kb as Dictionary).get("center_region", 0x7FFFFFFF))
	var ia: int = _intent_sort_rank(_intent_for_center(ca))
	var ib: int = _intent_sort_rank(_intent_for_center(cb))
	if ia != ib:
		return ia < ib
	return ca < cb


static func _intent_sort_rank(intent: int) -> int:
	if intent == IntentMemory.INTENT_GROW:
		return 0
	if intent == IntentMemory.INTENT_ABANDON:
		return 2
	return 1


static func _intent_for_center(center_region: int) -> int:
	if center_region < 0:
		return IntentMemory.INTENT_HOLD
	return int(IntentMemory.settlement_intent.get(center_region, IntentMemory.INTENT_HOLD))


static func _region_set(regions: PackedInt32Array) -> Dictionary:
	var d: Dictionary = {}
	for i in range(regions.size()):
		d[int(regions[i])] = true
	return d


static func _settlement_item_total(region_want: Dictionary, item: int) -> int:
	var total: int = 0
	for z in StockpileManager.zones():
		if z == null or not is_instance_valid(z):
			continue
		if not _zone_overlaps_regions(z, region_want):
			continue
		total += z.count_of(item)
	return total


static func _settlement_item_total_by_dict(s: Dictionary, item: int) -> int:
	var reg: Variant = s.get("regions", null)
	if not (reg is PackedInt32Array):
		return 0
	return _settlement_item_total(_region_set(reg as PackedInt32Array), item)


static func _zone_overlaps_regions(z: Stockpile, region_want: Dictionary) -> bool:
	var r: Rect2i = z.rect
	var y1: int = r.position.y + r.size.y
	var x1: int = r.position.x + r.size.x
	for y in range(r.position.y, y1):
		for x in range(r.position.x, x1):
			var rk: int = WorldMemory._region_key(x, y)
			if region_want.has(rk):
				return true
	return false


## Pick a stockpile in this settlement to pull from: settlement already has
## aggregate surplus; zone must have enough for a batch and a free work tile.
static func _first_source_zone(
		region_want: Dictionary, item: int, world: World
) -> Stockpile:
	for z in StockpileManager.zones():
		if z == null or not is_instance_valid(z):
			continue
		if not _zone_overlaps_regions(z, region_want):
			continue
		if z.count_of(item) < TRADE_BATCH:
			continue
		if not z.accepts(item):
			continue
		if not _zone_has_passable_work_tile(world, z):
			continue
		return z
	return null


static func _first_dest_zone_for_item(region_want: Dictionary, item: int) -> Stockpile:
	for z in StockpileManager.zones():
		if z == null or not is_instance_valid(z):
			continue
		if not _zone_overlaps_regions(z, region_want):
			continue
		if not z.accepts(item):
			continue
		return z
	return null


static func _zone_has_passable_work_tile(world: World, z: Stockpile) -> bool:
	if world == null or world.pathfinder == null:
		return false
	var t: Vector2i = _first_passable_free_job_tile(world, z)
	return t.x >= 0


static func _first_passable_free_job_tile(world: World, z: Stockpile) -> Vector2i:
	var r: Rect2i = z.rect
	var y1: int = r.position.y + r.size.y
	var x1: int = r.position.x + r.size.x
	for y in range(r.position.y, y1):
		for x in range(r.position.x, x1):
			var t: Vector2i = Vector2i(x, y)
			if not world.pathfinder.is_passable(t):
				continue
			if JobManager.has_job_at(t):
				continue
			return t
	return Vector2i(-1, -1)


static func _region_grid_manhattan(ra: int, rb: int) -> int:
	var ax: int = int(ra) & 0xFFFF
	var ay: int = (int(ra) >> 16) & 0xFFFF
	var bx: int = int(rb) & 0xFFFF
	var by: int = (int(rb) >> 16) & 0xFFFF
	return absi(ax - bx) + absi(ay - by)


## Closest [B] that needs [R], tie-break lower [center_region]. Empty if none.
static func _find_best_receiver(
		world: World,
		settlements: Array,
		_st_a: Dictionary,
		a_center: int,
		_a_region_want: Dictionary,
		item: int,
		from_sp: Stockpile,
		used: Dictionary
) -> Dictionary:
	var ac: Vector2i = SettlementPlanner._center_tile_of_region_key(a_center)
	var cands: Array[Dictionary] = []
	for b_any in settlements:
		if not (b_any is Dictionary):
			continue
		var st_b: Dictionary = b_any as Dictionary
		var b_center: int = int(st_b.get("center_region", -1))
		var b_intent: int = _intent_for_center(b_center)
		if b_center < 0 or b_center == a_center or used.has(b_center):
			continue
		if SettlementMemory.is_collapsed_state(str(st_b.get("state", ""))):
			continue
		if b_intent == IntentMemory.INTENT_ABANDON:
			continue
		if SettlementMemory.is_region_in_permanently_abandoned_settlement(b_center):
			continue
		var d: int = _region_grid_manhattan(a_center, b_center)
		if d > MAX_TRADE_DISTANCE:
			continue
		if _settlement_item_total_by_dict(st_b, item) >= NEED_THRESHOLD:
			continue
		var reg: Variant = st_b.get("regions", null)
		if not (reg is PackedInt32Array) or (reg as PackedInt32Array).is_empty():
			continue
		var to_sp: Stockpile = _first_dest_zone_for_item(
				_region_set(reg as PackedInt32Array), item
		)
		if to_sp == null:
			continue
		if not _path_trading_pair(world, from_sp, st_b, to_sp, ac):
			continue
		cands.append({"d": d, "ir": _intent_sort_rank(b_intent), "c": b_center, "to_sp": to_sp})
	if cands.is_empty():
		return {}
	cands.sort_custom(func(x: Dictionary, y: Dictionary) -> bool:
		var dx: int = int(x.get("d", 0))
		var dy: int = int(y.get("d", 0))
		if dx != dy:
			return dx < dy
		var ix: int = int(x.get("ir", 1))
		var iy: int = int(y.get("ir", 1))
		if ix != iy:
			return ix < iy
		return int(x.get("c", 0)) < int(y.get("c", 0))
	)
	var first: Dictionary = cands[0]
	return {"center": int(first.get("c", 0)), "to_sp": first.get("to_sp", null)}


static func _path_trading_pair(
		world: World,
		from_sp: Stockpile,
		st_b: Dictionary,
		to_sp: Stockpile,
		ac: Vector2i
) -> bool:
	if world.pathfinder == null:
		return false
	var b_r: Variant = st_b.get("regions", null)
	if not (b_r is PackedInt32Array) or (b_r as PackedInt32Array).is_empty():
		return false
	var bc: int = int(st_b.get("center_region", 0))
	var bcen: Vector2i = SettlementPlanner._center_tile_of_region_key(bc)
	var t_from: Vector2i = from_sp.nearest_tile_to(ac)
	var t_to: Vector2i = to_sp.nearest_tile_to(bcen)
	if world.pathfinder.component_of(t_from) != world.pathfinder.component_of(t_to):
		return false
	var p: Array[Vector2i] = world.pathfinder.find_path_pawn_historic_aversion(
			t_from, t_to
	)
	return not p.is_empty()
