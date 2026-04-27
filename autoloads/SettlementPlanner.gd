extends Node
## v1–v3 + culture v1: deterministic autonomous build intents for [SettlementMemory] clusters
## (read-only; posts via Main + JobManager). Not every tick: memory-dirty or interval.
## Culture: derived from settlement scar_max + reputation_min (read-only; not stored).

const PLANNING_INTERVAL_TICKS: int = 2000
const CORE_BOX_R: int = 2
const VILLAGE_SPAN: int = 7
## First perimeter: OPEN uses a larger initial ring (loose), DEF a tighter one (fortified).
## CAUTIOUS keeps [constant CORE_BOX_R] (5x5) — Architectural Style v1.
const PERIM_R_OPEN: int = 3
const PERIM_R_DEF: int = 1
## Second door: OPEN waits for larger growth; DEF allows at smaller enclosed span.
const DOOR2_MIN_SPAN_OPEN: int = 7
const DOOR2_MIN_SPAN_DEF: int = 4
## OPEN delays village-scale wall and second door.
const OPEN_VILLAGE_WALL_PAWNS: int = 10
const DEF_VILLAGE_WALL_PAWNS: int = 3
const OPEN_BED2_BEFORE_EXPAND: int = 3
## OPEN: delay second door until population or many beds.
const OPEN_DOOR2_PAWNS: int = 10
const OPEN_DOOR2_BEDS: int = 4
const ZONE_W: int = 3
const ZONE_H: int = 3
## 0=OPEN, 1=CAUTIOUS, 2=DEFENSIVE (derived only; not stored)
const CULTURE_OPEN: int = 0
const CULTURE_CAUTIOUS: int = 1
const CULTURE_DEFENSIVE: int = 2

var _last_plan_tick: int = -1_000_000_000


func plan(world: World, main: Node2D, from_memory_dirty: bool) -> void:
	if world == null or not is_instance_valid(world) or world.data == null or main == null:
		return
	if not from_memory_dirty:
		var t0: int = GameManager.tick_count
		if t0 - _last_plan_tick < PLANNING_INTERVAL_TICKS:
			return
	_last_plan_tick = GameManager.tick_count
	if not main.has_method("settlement_planner_count_pawns_in_regions"):
		return
	for s in SettlementMemory.settlements:
		if not (s is Dictionary):
			continue
		var d: Dictionary = s as Dictionary
		if SettlementMemory.is_collapsed_state(str(d.get("state", ""))):
			continue
		var reg: Variant = d.get("regions", null)
		if not (reg is PackedInt32Array):
			continue
		var packed: PackedInt32Array = reg as PackedInt32Array
		if packed.is_empty():
			continue
		_plan_one_settlement(world, main, d, packed)


func _plan_one_settlement(
		world: World, main: Node2D, settlement: Dictionary, regions: PackedInt32Array
) -> void:
	var data: WorldData = world.data
	var center_rk: int = int(settlement.get("center_region", regions[0]))
	var intent: int = SettlementPlanner._intent_for_settlement(center_rk)
	var center: Vector2i = SettlementPlanner._center_tile_of_region_key(center_rk)
	var pawns: int = int(main.call("settlement_planner_count_pawns_in_regions", regions))
	var bed_n: int = _count_feature_in_regions(data, regions, TileFeature.Type.BED)
	var wall_n: int = _count_feature_in_regions(data, regions, TileFeature.Type.WALL)
	var door_n: int = _count_feature_in_regions(data, regions, TileFeature.Type.DOOR)
	var stage: int = _derive_settlement_stage(
			world, data, center, regions, bed_n, wall_n, door_n
	)
	var scar_m: int = int(settlement.get("scar_max", 0))
	var repm: int = int(settlement.get("reputation_min", 0))
	var cult: int = SettlementPlanner._derive_culture_type_v1_for_age(
			scar_m, repm, AgeMemory.get_current_age_index()
	)
	_plan_one_settlement_culture(
			world, main, data, center, regions, cult, intent, pawns, bed_n, wall_n, door_n, stage
	)


## Culture branches: rule order, gates, and tile sort only (one action per run).
func _plan_one_settlement_culture(
		world: World, main: Node2D, data: WorldData, center: Vector2i, regions: PackedInt32Array,
		cult: int, intent: int, pawns: int, bed_n: int, wall_n: int, door_n: int, stage: int
) -> void:
	var order: Array[int] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
	if cult == CULTURE_OPEN:
		# Beds + zone before fortifying; sprawl (tile picks below).
		order = [1, 6, 4, 2, 3, 5, 7, 8, 9, 10]
	elif cult == CULTURE_DEFENSIVE:
		# Wall expansion before stockpile; compact defaults.
		order = [1, 2, 3, 5, 4, 6, 7, 8, 9, 10]
	if intent == IntentMemory.INTENT_GROW:
		if cult == CULTURE_OPEN:
			order = [1, 6, 4, 5, 2, 3, 7, 8, 9, 10]
		elif cult == CULTURE_DEFENSIVE:
			order = [1, 2, 3, 6, 5, 4, 7, 8, 9, 10]
		else:
			order = [1, 6, 4, 2, 3, 5, 7, 8, 9, 10]
	elif intent == IntentMemory.INTENT_ABANDON:
		order = [1, 3, 7, 10, 2, 4, 5, 6, 8, 9]
	for rid: int in order:
		match rid:
			1:
				var need_bed: bool = pawns > bed_n and pawns < bed_n + 2
				if intent == IntentMemory.INTENT_GROW:
					need_bed = pawns >= bed_n and pawns < bed_n + 3
				elif intent == IntentMemory.INTENT_ABANDON:
					need_bed = pawns > bed_n and pawns <= bed_n + 1
				if need_bed:
					var tbed: Vector2i = _pick_bed_tile_culture(
							world, main, center, regions, cult
					)
					if tbed.x >= 0 and bool(main.call("settlement_planner_post_bed", tbed)):
						return
			2:
				if bed_n > 0 and wall_n == 0:
					if cult == CULTURE_OPEN and bed_n < 2:
						continue
					var tw: Vector2i = _pick_perimeter_wall_tile_culture(
							world, main, center, regions, cult
					)
					if tw.x >= 0 and bool(main.call("settlement_planner_post_wall", tw)):
						return
			3:
				if wall_n > 0 and door_n == 0:
					if cult == CULTURE_OPEN and pawns < 3:
						continue
					var td: Vector2i = _pick_door_tile_culture(
							world, main, data, center, regions, cult
					)
					if td.x >= 0 and bool(main.call("settlement_planner_post_door", td)):
						return
			4:
				if intent == IntentMemory.INTENT_ABANDON:
					continue
				if not _settlement_touched_by_any_zone(center, regions, data):
					var r4: Rect2i = _zone_rect_3x3_anchored_at(center, data)
					if r4.size.x > 0 and bool(main.call("settlement_planner_post_zone_rect", r4)):
						return
			5:
				if intent == IntentMemory.INTENT_ABANDON:
					continue
				if cult == CULTURE_OPEN and bed_n < OPEN_BED2_BEFORE_EXPAND:
					if intent != IntentMemory.INTENT_GROW:
						continue
				if intent == IntentMemory.INTENT_GROW and pawns < 2:
					continue
				if wall_n > 0 and _wall_bbox_too_small(data, regions, VILLAGE_SPAN):
					var texp: Vector2i = _pick_expansion_wall_tile_culture(
							world, main, data, center, regions, cult
					)
					if texp.x >= 0 and bool(main.call("settlement_planner_post_wall", texp)):
						return
			6:
				if intent == IntentMemory.INTENT_ABANDON:
					continue
				var can_bed2: bool = pawns >= bed_n + 2
				if intent == IntentMemory.INTENT_GROW:
					can_bed2 = pawns >= bed_n + 1
				if can_bed2:
					if cult == CULTURE_DEFENSIVE and door_n == 0 and wall_n > 0:
						continue
					var tbed2: Vector2i = _pick_bed_tile_culture(
							world, main, center, regions, cult
					)
					if tbed2.x >= 0 and bool(main.call("settlement_planner_post_bed", tbed2)):
						return
			7:
				if wall_n > 0 and bed_n > 0 and not _path_bed_to_center_exists(
						world, data, center, regions
				):
					var tdoor2: Vector2i = _pick_door_tile_culture(
							world, main, data, center, regions, cult
					)
					if tdoor2.x >= 0 and bool(main.call("settlement_planner_post_door", tdoor2)):
						return
			8:
				if intent == IntentMemory.INTENT_ABANDON:
					continue
				var need_p: int = (
						OPEN_VILLAGE_WALL_PAWNS
						if cult == CULTURE_OPEN
						else (DEF_VILLAGE_WALL_PAWNS if cult == CULTURE_DEFENSIVE else 6)
				)
				if intent == IntentMemory.INTENT_GROW:
					need_p = maxi(2, need_p - 2)
				if stage == 1 and pawns >= need_p:
					var t8: Vector2i = _pick_expansion_wall_tile_culture(
							world, main, data, center, regions, cult
					)
					if t8.x >= 0 and bool(main.call("settlement_planner_post_wall", t8)):
						return
			9:
				if intent == IntentMemory.INTENT_ABANDON:
					continue
				var d2sp: int = _door2_min_span_culture(cult)
				if _wall_bbox_too_small(data, regions, d2sp) or door_n >= 2:
					continue
				if intent == IntentMemory.INTENT_GROW and pawns >= 6:
					d2sp = maxi(4, d2sp - 1)
				if cult == CULTURE_OPEN and not (
						pawns >= OPEN_DOOR2_PAWNS or bed_n >= OPEN_DOOR2_BEDS
				):
					continue
				var t9: Vector2i = _pick_second_door_tile_culture(
						world, main, data, center, regions, cult
				)
				if t9.x >= 0 and bool(main.call("settlement_planner_post_door", t9)):
					return
			10:
				if intent == IntentMemory.INTENT_ABANDON:
					continue
				if stage >= 1:
					var t10: Vector2i = _first_interior_bbox_wall_door(
							world, main, data, center, regions, cult
					)
					if t10.x >= 0 and bool(main.call("settlement_planner_post_door", t10)):
						return


static func _intent_for_settlement(center_region: int) -> int:
	if center_region < 0:
		return IntentMemory.INTENT_HOLD
	return int(IntentMemory.settlement_intent.get(center_region, IntentMemory.INTENT_HOLD))


## Deterministic, exclusive: worst survival context wins. Later Ages nudge away from [OPEN] without hard overrides.
static func _derive_culture_type_v1_for_age(
		scar_max: int, reputation_min: int, age_index: int
) -> int:
	var s_eff: int = mini(3, scar_max + int(age_index / 3))
	var r_eff: int = reputation_min - int(age_index / 2)
	if s_eff == 3 or r_eff <= -2:
		return CULTURE_DEFENSIVE
	if s_eff == 2 or r_eff == -1:
		return CULTURE_CAUTIOUS
	if s_eff <= 1 and r_eff >= 0:
		return CULTURE_OPEN
	return CULTURE_CAUTIOUS


## Back-compat: signature-only callers use age 0.
static func _derive_culture_type_v1(scar_max: int, reputation_min: int) -> int:
	return SettlementPlanner._derive_culture_type_v1_for_age(scar_max, reputation_min, 0)


## Public helper for other systems (ambient/camera/world expression):
## returns one of CULTURE_OPEN / CULTURE_CAUTIOUS / CULTURE_DEFENSIVE.
static func get_culture_type_for_settlement(settlement: Dictionary) -> int:
	var scar_m: int = int(settlement.get("scar_max", 0))
	var rep_m: int = int(settlement.get("reputation_min", 0))
	return SettlementPlanner._derive_culture_type_v1_for_age(scar_m, rep_m, AgeMemory.get_current_age_index())


## Stable string label for logs, save-compatible analytics, and non-UI world expression glue.
static func get_culture_name_for_settlement(settlement: Dictionary) -> String:
	var c: int = SettlementPlanner.get_culture_type_for_settlement(settlement)
	if c == CULTURE_OPEN:
		return "open"
	if c == CULTURE_DEFENSIVE:
		return "defensive"
	return "cautious"


## Tiny audio intent nudge (no gameplay effect): open -> brighter, defensive -> heavier.
## This remains deterministic because it is derived from deterministic memory state.
static func get_culture_audio_bias_for_settlement(settlement: Dictionary) -> float:
	var c: int = SettlementPlanner.get_culture_type_for_settlement(settlement)
	if c == CULTURE_OPEN:
		return 0.08
	if c == CULTURE_DEFENSIVE:
		return -0.1
	return -0.02


static func _door2_min_span_culture(cult: int) -> int:
	if cult == CULTURE_OPEN:
		return DOOR2_MIN_SPAN_OPEN
	if cult == CULTURE_DEFENSIVE:
		return DOOR2_MIN_SPAN_DEF
	return VILLAGE_SPAN


func _pick_bed_tile_culture(
		_world: World, main: Node2D, center: Vector2i, regions: PackedInt32Array, cult: int
) -> Vector2i:
	if cult == CULTURE_OPEN:
		return _pick_farthest_bed_tile(_world, main, center, regions)
	# CAUTIOUS + DEFENSIVE: compact near center (v1 def = tight build).
	return _pick_nearest_bed_tile(_world, main, center, regions)


func _pick_farthest_bed_tile(
		_world: World, main: Node2D, center: Vector2i, regions: PackedInt32Array
) -> Vector2i:
	var cands: Array[Vector2i] = []
	for dy in range(-12, 13):
		for dx in range(-12, 13):
			var t := Vector2i(center.x + dx, center.y + dy)
			if not _tile_belongs_to_regions(t, regions):
				continue
			if not bool(main.call("settlement_planner_is_valid_bed_site", t)):
				continue
			cands.append(t)
	if cands.is_empty():
		return Vector2i(-1, -1)
	_sort_tiles_farthest_first_remnant(cands, center, _world)
	return cands[0]


func _pick_expansion_wall_tile_culture(
		world: World, main: Node2D, data: WorldData, center: Vector2i, regions: PackedInt32Array,
		cult: int
) -> Vector2i:
	# OPEN: sprawl; DEF/CAUTIOUS: compact (nearest) ring growth.
	if cult == CULTURE_OPEN:
		return _pick_expansion_wall_tile(world, main, data, center, regions, true)
	return _pick_expansion_wall_tile(world, main, data, center, regions, false)


static func _center_tile_of_region_key(rk: int) -> Vector2i:
	var rx: int = int(rk) & 0xFFFF
	var ry: int = (int(rk) >> 16) & 0xFFFF
	return Vector2i(rx * 16 + 8, ry * 16 + 8)


static func _tile_belongs_to_regions(t: Vector2i, regions: PackedInt32Array) -> bool:
	var rk: int = WorldMemory._region_key(t.x, t.y)
	for j in range(regions.size()):
		if int(regions[j]) == rk:
			return true
	return false


static func _count_feature_in_regions(
		data: WorldData, regions: PackedInt32Array, feature_id: int
) -> int:
	var n: int = 0
	for j in range(regions.size()):
		var rk2: int = int(regions[j])
		var rx: int = rk2 & 0xFFFF
		var ry: int = (rk2 >> 16) & 0xFFFF
		for dy in 16:
			for dx in 16:
				var x: int = rx * 16 + dx
				var y: int = ry * 16 + dy
				if not data.in_bounds(x, y):
					continue
				if int(data.get_feature(x, y)) == feature_id:
					n += 1
	return n


static func _settlement_touched_by_any_zone(
		center: Vector2i, regions: PackedInt32Array, data: WorldData
) -> bool:
	if _tile_covered_by_any_zone(center, data):
		return true
	for j in range(regions.size()):
		var rk2: int = int(regions[j])
		var rx: int = rk2 & 0xFFFF
		var ry: int = (rk2 >> 16) & 0xFFFF
		for dy in 16:
			for dx in 16:
				var x: int = rx * 16 + dx
				var y: int = ry * 16 + dy
				if not data.in_bounds(x, y):
					continue
				if _tile_covered_by_any_zone(Vector2i(x, y), data):
					return true
	return false


static func _tile_covered_by_any_zone(t: Vector2i, _data: WorldData) -> bool:
	for z in StockpileManager.zones():
		if z != null and is_instance_valid(z) and z.contains_tile(t):
			return true
	return false


## Deterministic: Manhattan distance to center, then tile index (y * W + x).
static func _sort_tiles_index_order(cands: Array[Vector2i], center: Vector2i) -> void:
	cands.sort_custom(func(a, b) -> bool:
		var a2: Vector2i = a as Vector2i
		var b2: Vector2i = b as Vector2i
		var am: int = abs(a2.x - center.x) + abs(a2.y - center.y)
		var bm: int = abs(b2.x - center.x) + abs(b2.y - center.y)
		if am != bm:
			return am < bm
		var ia: int = a2.y * WorldData.WIDTH + a2.x
		var ib: int = b2.y * WorldData.WIDTH + b2.x
		return ia < ib
	)


## [RemnantMemory]: prefer sites with less prior-era "wear" (higher [tile_age_delta] = worse = sort later).
static func _sort_tiles_index_order_remnant(
		cands: Array[Vector2i], center: Vector2i, w: World
) -> void:
	if w == null or not is_instance_valid(w):
		_sort_tiles_index_order(cands, center)
		return
	cands.sort_custom(func(a, b) -> bool:
		var a2: Vector2i = a as Vector2i
		var b2: Vector2i = b as Vector2i
		var am: int = (
				abs(a2.x - center.x)
				+ abs(a2.y - center.y)
				+ RemnantMemory.get_planner_penalty(a2, w)
		)
		var bm: int = (
				abs(b2.x - center.x)
				+ abs(b2.y - center.y)
				+ RemnantMemory.get_planner_penalty(b2, w)
		)
		if am != bm:
			return am < bm
		var ia: int = a2.y * WorldData.WIDTH + a2.x
		var ib: int = b2.y * WorldData.WIDTH + b2.x
		return ia < ib
	)


func _pick_nearest_bed_tile(
		_world: World, main: Node2D, center: Vector2i, regions: PackedInt32Array
) -> Vector2i:
	var cands: Array[Vector2i] = []
	for dy in range(-12, 13):
		for dx in range(-12, 13):
			var t := Vector2i(center.x + dx, center.y + dy)
			if not _tile_belongs_to_regions(t, regions):
				continue
			if not bool(main.call("settlement_planner_is_valid_bed_site", t)):
				continue
			cands.append(t)
	if cands.is_empty():
		return Vector2i(-1, -1)
	_sort_tiles_index_order_remnant(cands, center, _world)
	return cands[0]


## Rectangular loop perimeter, inclusive, axis-aligned around [param center] with half-span [param box_r].
static func _perimeter_tiles_box(center: Vector2i, box_r: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var r0: int = max(0, center.x - box_r)
	var r1: int = min(WorldData.WIDTH - 1, center.x + box_r)
	var c0: int = max(0, center.y - box_r)
	var c1: int = min(WorldData.HEIGHT - 1, center.y + box_r)
	for y in range(c0, c1 + 1):
		for x in range(r0, r1 + 1):
			if x == r0 or x == r1 or y == c0 or y == c1:
				out.append(Vector2i(x, y))
	return out


static func _perim_r_for_culture(cult: int) -> int:
	if cult == CULTURE_OPEN:
		return PERIM_R_OPEN
	if cult == CULTURE_DEFENSIVE:
		return PERIM_R_DEF
	return int(CORE_BOX_R)


## First enclosure: OPEN = large initial ring, DEF = tight, CAUTIOUS = 5x5. Sort: OPEN farthest, else near.
func _pick_perimeter_wall_tile_culture(
		_world: World, main: Node2D, center: Vector2i, regions: PackedInt32Array, cult: int
) -> Vector2i:
	var cands: Array[Vector2i] = []
	for t in _perimeter_tiles_box(center, _perim_r_for_culture(cult)):
		if not _tile_belongs_to_regions(t, regions):
			continue
		if not bool(main.call("settlement_planner_is_valid_build_wall_site", t)):
			continue
		cands.append(t)
	if cands.is_empty():
		return Vector2i(-1, -1)
	if cult == CULTURE_OPEN:
		_sort_tiles_farthest_first_remnant(cands, center, _world)
	else:
		_sort_tiles_index_order_remnant(cands, center, _world)
	return cands[0]


func _collect_wall_tiles_in_regions(
		data: WorldData, regions: PackedInt32Array, sort_center: Vector2i
) -> Array[Vector2i]:
	var out2: Array[Vector2i] = []
	for j in range(regions.size()):
		var rk2: int = int(regions[j])
		var rx: int = rk2 & 0xFFFF
		var ry: int = (rk2 >> 16) & 0xFFFF
		for dy in 16:
			for dx in 16:
				var x: int = rx * 16 + dx
				var y: int = ry * 16 + dy
				if not data.in_bounds(x, y):
					continue
				if int(data.get_feature(x, y)) == TileFeature.Type.WALL:
					out2.append(Vector2i(x, y))
	_sort_tiles_index_order(out2, sort_center)
	return out2


## Deterministic map order, no culture sort; used to collect before OPEN/COMMON door ordering.
static func _collect_wall_tiles_in_regions_nosort(
		data: WorldData, regions: PackedInt32Array
) -> Array[Vector2i]:
	var out0: Array[Vector2i] = []
	for j in range(regions.size()):
		var rk2: int = int(regions[j])
		var rx: int = rk2 & 0xFFFF
		var ry: int = (rk2 >> 16) & 0xFFFF
		for dy in 16:
			for dx in 16:
				var x0: int = rx * 16 + dx
				var y0: int = ry * 16 + dy
				if not data.in_bounds(x0, y0):
					continue
				if int(data.get_feature(x0, y0)) == TileFeature.Type.WALL:
					out0.append(Vector2i(x0, y0))
	return out0


## All valid door sites (on walls or passable) in the settlement, deduped; caller sorts by culture.
static func _collect_viable_door_tiles(
		world: World, main: Node2D, _data: WorldData, center: Vector2i, regions: PackedInt32Array
) -> Array[Vector2i]:
	var by_linear: Dictionary = {}
	for t in _collect_wall_tiles_in_regions_nosort(world.data, regions):
		if not bool(main.call("settlement_planner_is_valid_door_site", t)):
			continue
		by_linear[t.y * WorldData.WIDTH + t.x] = t
	for dy in range(-6, 7):
		for dx in range(-6, 7):
			var t2: Vector2i = Vector2i(center.x + dx, center.y + dy)
			if not _tile_belongs_to_regions(t2, regions):
				continue
			if not bool(main.call("settlement_planner_is_valid_door_site", t2)):
				continue
			by_linear[t2.y * WorldData.WIDTH + t2.x] = t2
	var li: Array = by_linear.keys()
	li.sort()
	var out1: Array[Vector2i] = []
	for k in li:
		out1.append(by_linear[int(k)] as Vector2i)
	return out1


## OPEN: farthest viable wall/door site; CAUTIOUS + DEFENSIVE: nearest. Tie: [code]y * W + x[/code].
func _pick_door_tile_culture(
		world: World, main: Node2D, data: WorldData, center: Vector2i, regions: PackedInt32Array,
		cult: int
) -> Vector2i:
	var cands: Array[Vector2i] = _collect_viable_door_tiles(
			world, main, data, center, regions
	)
	if cands.is_empty():
		return Vector2i(-1, -1)
	if cult == CULTURE_OPEN:
		_sort_tiles_farthest_first_remnant(cands, center, world)
	else:
		_sort_tiles_index_order_remnant(cands, center, world)
	return cands[0]


## Second entry door: sprawl = far; def = try near then far fallback; balanced = far from center.
func _pick_second_door_tile_culture(
		world: World, main: Node2D, data: WorldData, center: Vector2i, regions: PackedInt32Array,
		cult: int
) -> Vector2i:
	if cult == CULTURE_OPEN:
		return _pick_door_tile_far_from_center(world, main, data, center, regions)
	if cult == CULTURE_DEFENSIVE:
		var tdef: Vector2i = _pick_door_tile_culture(
				world, main, data, center, regions, CULTURE_DEFENSIVE
		)
		if tdef.x >= 0:
			return tdef
		return _pick_door_tile_far_from_center(world, main, data, center, regions)
	return _pick_door_tile_far_from_center(world, main, data, center, regions)


static func _zone_rect_3x3_anchored_at(center: Vector2i, _data: WorldData) -> Rect2i:
	var ax: int = clampi(center.x - 1, 0, WorldData.WIDTH - ZONE_W)
	var ay: int = clampi(center.y - 1, 0, WorldData.HEIGHT - ZONE_H)
	return Rect2i(Vector2i(ax, ay), Vector2i(ZONE_W, ZONE_H))


static func _collect_bed_tiles_in_regions(
		data: WorldData, regions: PackedInt32Array
) -> Array[Vector2i]:
	var outb: Array[Vector2i] = []
	for j in range(regions.size()):
		var rk2: int = int(regions[j])
		var rx: int = rk2 & 0xFFFF
		var ry: int = (rk2 >> 16) & 0xFFFF
		for dy in 16:
			for dx in 16:
				var x: int = rx * 16 + dx
				var y: int = ry * 16 + dy
				if not data.in_bounds(x, y):
					continue
				if int(data.get_feature(x, y)) == TileFeature.Type.BED:
					outb.append(Vector2i(x, y))
	return outb


static func _wall_bbox_too_small(
		data: WorldData, regions: PackedInt32Array, min_span: int
) -> bool:
	var wx0: int = 1_000_000
	var wx1: int = -1_000_000
	var wy0: int = 1_000_000
	var wy1: int = -1_000_000
	var any_w: bool = false
	for j in range(regions.size()):
		var rk2: int = int(regions[j])
		var rx: int = rk2 & 0xFFFF
		var ry: int = (rk2 >> 16) & 0xFFFF
		for dy in 16:
			for dx in 16:
				var x: int = rx * 16 + dx
				var y: int = ry * 16 + dy
				if not data.in_bounds(x, y):
					continue
				if int(data.get_feature(x, y)) != TileFeature.Type.WALL:
					continue
				any_w = true
				wx0 = mini(wx0, x)
				wx1 = maxi(wx1, x)
				wy0 = mini(wy0, y)
				wy1 = maxi(wy1, y)
	if not any_w:
		return false
	var w: int = wx1 - wx0 + 1
	var h: int = wy1 - wy0 + 1
	return w < min_span or h < min_span


## If [param prefer_farthest], candidate order is far-from-center, then index (OPEN sprawl).
func _pick_expansion_wall_tile(
		_world: World, main: Node2D, data: WorldData, center: Vector2i, regions: PackedInt32Array,
		prefer_farthest: bool = false
) -> Vector2i:
	var wx0: int = 1_000_000
	var wx1: int = -1_000_000
	var wy0: int = 1_000_000
	var wy1: int = -1_000_000
	var any_w2: bool = false
	for j in range(regions.size()):
		var rk2: int = int(regions[j])
		var rx: int = rk2 & 0xFFFF
		var ry: int = (rk2 >> 16) & 0xFFFF
		for dy in 16:
			for dx in 16:
				var x2: int = rx * 16 + dx
				var y2: int = ry * 16 + dy
				if not data.in_bounds(x2, y2):
					continue
				if int(data.get_feature(x2, y2)) != TileFeature.Type.WALL:
					continue
				any_w2 = true
				wx0 = mini(wx0, x2)
				wx1 = maxi(wx1, x2)
				wy0 = mini(wy0, y2)
				wy1 = maxi(wy1, y2)
	if not any_w2:
		return Vector2i(-1, -1)
	var ex0: int = maxi(0, wx0 - 1)
	var ex1: int = mini(WorldData.WIDTH - 1, wx1 + 1)
	var ey0: int = maxi(0, wy0 - 1)
	var ey1: int = mini(WorldData.HEIGHT - 1, wy1 + 1)
	var cands3: Array[Vector2i] = []
	for y3 in range(ey0, ey1 + 1):
		for x3 in range(ex0, ex1 + 1):
			if not (x3 == ex0 or x3 == ex1 or y3 == ey0 or y3 == ey1):
				continue
			if int(data.get_feature(x3, y3)) == TileFeature.Type.WALL:
				continue
			var ts: Vector2i = Vector2i(x3, y3)
			if not _tile_belongs_to_regions(ts, regions):
				continue
			if not bool(main.call("settlement_planner_is_valid_build_wall_site", ts)):
				continue
			cands3.append(ts)
	if cands3.is_empty():
		return Vector2i(-1, -1)
	if prefer_farthest:
		_sort_tiles_farthest_first_remnant(cands3, center, _world)
	else:
		_sort_tiles_index_order_remnant(cands3, center, _world)
	return cands3[0]


## 0 = camp, 1 = village, 2 = fortified (derived only; not stored).
static func _derive_settlement_stage(
		world: World, data: WorldData, center: Vector2i, regions: PackedInt32Array,
		bed_n: int, wall_n: int, door_n: int
) -> int:
	if bed_n <= 0:
		return 0
	var span7: bool = not _wall_bbox_too_small(data, regions, VILLAGE_SPAN)
	var path_ok: bool = _path_bed_to_center_exists(world, data, center, regions)
	if bed_n > 0 and wall_n >= 6 and door_n >= 2 and span7 and path_ok:
		return 2
	if bed_n >= 2 and wall_n >= 4 and door_n >= 1:
		return 1
	return 0


static func _path_bed_to_center_exists(
		world: World, data: WorldData, center: Vector2i, regions: PackedInt32Array
) -> bool:
	var beds0: Array[Vector2i] = _collect_bed_tiles_in_regions(data, regions)
	if beds0.is_empty():
		return true
	_sort_tiles_index_order(beds0, center)
	var pf: PathFinder = world.pathfinder
	for b0 in beds0:
		if b0 == center:
			return true
		var pth: Array = pf.find_path(b0, center)
		if pth.size() > 0:
			return true
	return false


static func _sort_tiles_farthest_first(cands: Array[Vector2i], center: Vector2i) -> void:
	cands.sort_custom(func(a, b) -> bool:
		var a2: Vector2i = a as Vector2i
		var b2: Vector2i = b as Vector2i
		var am: int = abs(a2.x - center.x) + abs(a2.y - center.y)
		var bm: int = abs(b2.x - center.x) + abs(b2.y - center.y)
		if am != bm:
			return am > bm
		var ia: int = a2.y * WorldData.WIDTH + a2.x
		var ib: int = b2.y * WorldData.WIDTH + b2.x
		return ia < ib
	)


static func _sort_tiles_farthest_first_remnant(
		cands: Array[Vector2i], center: Vector2i, w: World
) -> void:
	if w == null or not is_instance_valid(w):
		_sort_tiles_farthest_first(cands, center)
		return
	cands.sort_custom(func(a, b) -> bool:
		var a2: Vector2i = a as Vector2i
		var b2: Vector2i = b as Vector2i
		var am: int = abs(a2.x - center.x) + abs(a2.y - center.y)
		var bm: int = abs(b2.x - center.x) + abs(b2.y - center.y)
		if am != bm:
			return am > bm
		var pa: int = RemnantMemory.get_planner_penalty(a2, w)
		var pb: int = RemnantMemory.get_planner_penalty(b2, w)
		if pa != pb:
			return pa < pb
		var ia: int = a2.y * WorldData.WIDTH + a2.x
		var ib: int = b2.y * WorldData.WIDTH + b2.x
		return ia < ib
	)


## Second door: valid sites farthest from center (opposite side first).
func _pick_door_tile_far_from_center(
		_world: World, main: Node2D, data: WorldData, center: Vector2i, regions: PackedInt32Array
) -> Vector2i:
	var by_idx: Dictionary = {}
	for dy2 in range(-8, 9):
		for dx2 in range(-8, 9):
			var t3 := Vector2i(center.x + dx2, center.y + dy2)
			if not _tile_belongs_to_regions(t3, regions):
				continue
			if int(data.get_feature(t3.x, t3.y)) == TileFeature.Type.DOOR:
				continue
			if not bool(main.call("settlement_planner_is_valid_door_site", t3)):
				continue
			by_idx[t3.y * WorldData.WIDTH + t3.x] = t3
	if by_idx.is_empty():
		return Vector2i(-1, -1)
	var uniq: Array[Vector2i] = []
	for k in by_idx:
		uniq.append(by_idx[k] as Vector2i)
	_sort_tiles_farthest_first_remnant(uniq, center, _world)
	return uniq[0]


func _first_interior_bbox_wall_door(
		_world: World, main: Node2D, data: WorldData, center: Vector2i, regions: PackedInt32Array,
		cult: int
) -> Vector2i:
	var wx0: int = 1_000_000
	var wx1: int = -1_000_000
	var wy0: int = 1_000_000
	var wy1: int = -1_000_000
	var any_w3: bool = false
	for j in range(regions.size()):
		var rk2: int = int(regions[j])
		var rx: int = rk2 & 0xFFFF
		var ry: int = (rk2 >> 16) & 0xFFFF
		for dy in 16:
			for dx in 16:
				var x4: int = rx * 16 + dx
				var y4: int = ry * 16 + dy
				if not data.in_bounds(x4, y4):
					continue
				if int(data.get_feature(x4, y4)) != TileFeature.Type.WALL:
					continue
				any_w3 = true
				wx0 = mini(wx0, x4)
				wx1 = maxi(wx1, x4)
				wy0 = mini(wy0, y4)
				wy1 = maxi(wy1, y4)
	if not any_w3 or wx1 - wx0 < 2 or wy1 - wy0 < 2:
		return Vector2i(-1, -1)
	var cin: Array[Vector2i] = []
	for y5 in range(wy0 + 1, wy1):
		for x5 in range(wx0 + 1, wx1):
			if not data.in_bounds(x5, y5):
				continue
			if not _tile_belongs_to_regions(Vector2i(x5, y5), regions):
				continue
			if int(data.get_feature(x5, y5)) != TileFeature.Type.WALL:
				continue
			if not bool(main.call("settlement_planner_is_valid_door_site", Vector2i(x5, y5))):
				continue
			cin.append(Vector2i(x5, y5))
	if cin.is_empty():
		return Vector2i(-1, -1)
	if cult == CULTURE_OPEN:
		_sort_tiles_farthest_first_remnant(cin, center, _world)
	else:
		_sort_tiles_index_order_remnant(cin, center, _world)
	return cin[0]
