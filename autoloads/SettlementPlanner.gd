extends Node
## v1–v3 + culture v1: deterministic autonomous build intents for [SettlementMemory] clusters
## (read-only; posts via Main + JobManager). Not every tick: memory-dirty or interval.
## Culture: derived from settlement scar_max + reputation_min (read-only; not stored).

const PLANNING_INTERVAL_TICKS: int = 500  # OPTIMIZATION: Increased frequency from 2000 for faster building response
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
const PLANNING_REGION_RADIUS: int = 4
const PLANNING_REGION_HARD_CAP: int = 96
const PLANNER_MAX_SETTLEMENTS_PER_PASS: int = 5
const PLANNER_BED_SCAN_CAP: int = 24
const PLANNER_BED_PATH_PROBE_CAP: int = 4
const PLANNER_WALL_SCAN_CAP: int = 256

var _last_plan_tick: int = -1_000_000_000
@onready var SpatialManager = get_node_or_null("/root/SpatialManager") # ARCHITECT T006
var _plan_rr_cursor: int = 0
## Budget tracking: set at start of plan(), checked by tile-picking functions
static var _plan_budget_usec: int = 0
static var _plan_start_usec: int = 0


## Check if the planner's time budget has been exceeded. Tile-picking functions
## call this to bail out early instead of running expensive scans past budget.
static func _budget_exceeded() -> bool:
	if _plan_budget_usec <= 0:
		return false
	return Time.get_ticks_usec() - _plan_start_usec >= _plan_budget_usec


func plan(world: World, main: Node2D, from_memory_dirty: bool) -> void:
	if world == null or not is_instance_valid(world) or world.data == null or main == null:
		return
	if not from_memory_dirty:
		var t0: int = GameManager.tick_count
		if t0 - _last_plan_tick < PLANNING_INTERVAL_TICKS:
			return
		var open_backpressure_limit: int = _planner_open_job_backpressure_limit()
		if open_backpressure_limit > 0 and JobManager.open_count() >= open_backpressure_limit:
			return
	_last_plan_tick = GameManager.tick_count
	if not main.has_method("settlement_planner_count_pawns_in_regions"):
		return
	var settlements: Array = SettlementMemory.get_formal_settlements()
	var total: int = settlements.size()
	if total <= 0:
		return
	var start_idx: int = _plan_rr_cursor % total
	var max_settlements: int = _planner_pass_settlement_limit()
	var budget_usec: int = _planner_pass_budget_usec()
	var started_usec: int = Time.get_ticks_usec()
	_plan_budget_usec = budget_usec
	_plan_start_usec = started_usec
	var processed: int = 0
	var scanned: int = 0
	while scanned < total and processed < max_settlements:
		var idx: int = (start_idx + scanned) % total
		scanned += 1
		var s: Variant = settlements[idx]
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
		var center_rk: int = int(d.get("center_region", packed[0]))

		# ARCHITECT T006: Skip planning for settlements in inactive spatial chunks.
		if SpatialManager != null:
			var center_tile: Vector2i = _center_tile_of_region_key(center_rk)
			var chunk_coord: Vector2i = SpatialManager.tile_to_chunk(center_tile)
			if not SpatialManager.is_chunk_active(chunk_coord):
				# Debug for culling effectiveness.
				# print(
				# 	"[SettlementPlanner] Skipping planning for settlement %d "
				# 	+ "in inactive chunk (%d,%d) at tick %d" % [d.get("id", -1), chunk_coord.x, chunk_coord.y, GameManager.tick_count]
				# )
				continue # Skip this settlement if its chunk is inactive.

		var planning_regions: PackedInt32Array = _select_planning_regions(center_rk, packed)
		if planning_regions.is_empty():
			continue
		_plan_one_settlement(world, main, d, planning_regions)
		processed += 1
		if Time.get_ticks_usec() - started_usec >= budget_usec:
			break
	_plan_rr_cursor = (start_idx + scanned) % total


static func _planner_pass_settlement_limit() -> int:
	if GameManager == null:
		return PLANNER_MAX_SETTLEMENTS_PER_PASS
	var gs: float = GameManager.game_speed
	if gs >= 26.0:
		return 1
	if gs >= 12.0:
		return 2
	if gs >= 3.0:
		return 3
	return PLANNER_MAX_SETTLEMENTS_PER_PASS


static func _planner_pass_budget_usec() -> int:
	if GameManager == null:
		return 4_000
	var gs: float = GameManager.game_speed
	if gs >= 100.0:
		return 2_000
	if gs >= 50.0:
		return 2_000
	if gs >= 26.0:
		return 3_000
	if gs >= 12.0:
		return 4_000
	if gs >= 3.0:
		return 6_000
	return 8_000


static func _planner_open_job_backpressure_limit() -> int:
	if GameManager == null:
		return -1
	var gs: float = GameManager.game_speed
	if gs >= 100.0:
		return 80
	if gs >= 50.0:
		return 96
	if gs >= 26.0:
		return 112
	if gs >= 12.0:
		return 128
	if gs >= 3.0:
		return 160
	return -1


func _plan_one_settlement(
		world: World, main: Node2D, settlement: Dictionary, planning_regions: PackedInt32Array
) -> void:
	if _budget_exceeded():
		return
	var data: WorldData = world.data
	var center_rk: int = int(settlement.get("center_region", planning_regions[0]))
	var intent: int = SettlementPlanner._intent_for_settlement(center_rk)
	var center: Vector2i = SettlementPlanner._center_tile_of_region_key(center_rk)
	var pawns: int = int(main.call("settlement_planner_count_pawns_in_regions", planning_regions))
	var feature_summary: Dictionary = _scan_region_feature_summary(data, planning_regions)
	if _budget_exceeded():
		return
	var bed_n: int = int(feature_summary.get("bed_n", 0))
	var wall_n: int = int(feature_summary.get("wall_n", 0))
	var door_n: int = int(feature_summary.get("door_n", 0))
	var fire_pit_n: int = int(feature_summary.get("fire_pit_n", 0))
	var storage_hut_n: int = int(feature_summary.get("storage_hut_n", 0))
	var stage: int = _derive_settlement_stage(
			world, data, center, planning_regions, bed_n, wall_n, door_n, feature_summary
	)
	var scar_m: int = int(settlement.get("scar_max", 0))
	var repm: int = int(settlement.get("reputation_min", 0))
	var cult: int = SettlementPlanner._derive_culture_type_v1_for_age(
			scar_m, repm, AgeMemory.get_current_age_index()
	)
	_plan_one_settlement_culture(
			world, main, data, center, planning_regions, cult, intent, pawns, bed_n, wall_n, door_n, stage, feature_summary
	)


## Culture branches: rule order, gates, and tile sort only (one action per run).
func _plan_one_settlement_culture(
		world: World, main: Node2D, data: WorldData, center: Vector2i, regions: PackedInt32Array,
		cult: int, intent: int, pawns: int, bed_n: int, wall_n: int, door_n: int, stage: int,
		feature_summary: Dictionary
) -> void:
	var fire_pit_n: int = int(feature_summary.get("fire_pit_n", 0))
	var storage_hut_n: int = int(feature_summary.get("storage_hut_n", 0))
	var order: Array[int] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25]
	if cult == CULTURE_OPEN:
		# Beds + zone before fortifying; sprawl (tile picks below). Farms early.
		order = [1, 6, 4, 2, 3, 5, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 18, 17, 19, 20, 22, 21, 24, 23, 25]
	elif cult == CULTURE_DEFENSIVE:
		# Wall expansion before stockpile; compact defaults. Military early.
		order = [1, 2, 3, 5, 4, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 23, 18, 16, 17, 19, 20, 21, 22, 24, 25]
	if intent == IntentMemory.INTENT_GROW:
		if cult == CULTURE_OPEN:
			order = [1, 6, 4, 5, 2, 3, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 18, 22, 17, 19, 20, 21, 24, 23, 25]
		elif cult == CULTURE_DEFENSIVE:
			order = [1, 2, 3, 6, 5, 4, 7, 8, 9, 10, 11, 12, 13, 14, 15, 23, 18, 16, 17, 19, 20, 21, 22, 24, 25]
		else:
			order = [1, 6, 4, 2, 3, 5, 7, 8, 9, 10, 16, 18, 17, 19, 20, 21, 22, 23, 24, 25]
	elif intent == IntentMemory.INTENT_ABANDON:
		order = [1, 3, 7, 10, 2, 4, 5, 6, 8, 9, 11, 12, 13, 14, 15, 23, 24, 18, 16, 17, 19, 20, 21, 22, 25]
	for rid: int in order:
		if _budget_exceeded():
			return
		match rid:
			1:
				var open_beds: int = JobManager.count_pending_by_type(Job.Type.BUILD_BED)
				# Post beds whenever there's a deficit AND we don't already have
				# too many pending bed jobs (cap prevents spam).
				var need_bed: bool = pawns > bed_n + open_beds and open_beds < 3
				if intent == IntentMemory.INTENT_GROW:
					need_bed = pawns > bed_n + open_beds and open_beds < 4
				elif intent == IntentMemory.INTENT_ABANDON:
					need_bed = pawns > bed_n + open_beds and pawns <= bed_n + open_beds + 1
				if need_bed:
					var tbed: Vector2i = _pick_bed_tile_culture(
							world, main, center, regions, cult
					)
					if tbed.x >= 0 and bool(main.call("settlement_planner_post_bed", tbed)):
						continue
			2:
				var open_walls: int = JobManager.count_pending_by_type(Job.Type.BUILD_WALL)
				if bed_n > 0 and wall_n + open_walls == 0:
					if cult == CULTURE_OPEN and bed_n < 2:
						continue
					var tw: Vector2i = _pick_perimeter_wall_tile_culture(
							world, main, center, regions, cult
					)
					if tw.x >= 0 and bool(main.call("settlement_planner_post_wall", tw)):
						continue
			3:
				var open_doors: int = JobManager.count_pending_by_type(Job.Type.BUILD_DOOR)
				if wall_n > 0 and door_n + open_doors == 0:
					if cult == CULTURE_OPEN and pawns < 3:
						continue
					var td: Vector2i = _pick_door_tile_culture(
							world, main, data, center, regions, cult
					)
					if td.x >= 0 and bool(main.call("settlement_planner_post_door", td)):
						continue
			4:
				if intent == IntentMemory.INTENT_ABANDON:
					continue
				if not _settlement_touched_by_any_zone(center, regions, data):
					var r4: Rect2i = _zone_rect_3x3_anchored_at(center, data)
					if r4.size.x > 0 and bool(main.call("settlement_planner_post_zone_rect", r4)):
						continue
			5:
				if intent == IntentMemory.INTENT_ABANDON:
					continue
				if cult == CULTURE_OPEN and bed_n < OPEN_BED2_BEFORE_EXPAND:
					if intent != IntentMemory.INTENT_GROW:
						continue
				if intent == IntentMemory.INTENT_GROW and pawns < 2:
					continue
				if wall_n > 0 and _wall_bbox_too_small(data, regions, VILLAGE_SPAN, feature_summary):
					var texp: Vector2i = _pick_expansion_wall_tile_culture(
							world, main, data, center, regions, cult, feature_summary
					)
					if texp.x >= 0 and bool(main.call("settlement_planner_post_wall", texp)):
						continue
			6:
				if intent == IntentMemory.INTENT_ABANDON:
					continue
				var open_beds6: int = JobManager.count_pending_by_type(Job.Type.BUILD_BED)
				var can_bed2: bool = pawns > bed_n + open_beds6 and open_beds6 < 3
				if intent == IntentMemory.INTENT_GROW:
					can_bed2 = pawns > bed_n + open_beds6 and open_beds6 < 4
				if can_bed2:
					if cult == CULTURE_DEFENSIVE and door_n == 0 and wall_n > 0:
						continue
					var tbed2: Vector2i = _pick_bed_tile_culture(
							world, main, center, regions, cult
					)
					if tbed2.x >= 0 and bool(main.call("settlement_planner_post_bed", tbed2)):
						continue
			7:
				if wall_n > 0 and bed_n > 0 and not _path_bed_to_center_exists(
						world, data, center, regions
				):
					var tdoor2: Vector2i = _pick_door_tile_culture(
							world, main, data, center, regions, cult
					)
					if tdoor2.x >= 0 and bool(main.call("settlement_planner_post_door", tdoor2)):
						continue
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
							world, main, data, center, regions, cult, feature_summary
					)
					if t8.x >= 0 and bool(main.call("settlement_planner_post_wall", t8)):
						continue
			9:
				if intent == IntentMemory.INTENT_ABANDON:
					continue
				var d2sp: int = _door2_min_span_culture(cult)
				if _wall_bbox_too_small(data, regions, d2sp, feature_summary) or door_n >= 2:
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
							world, main, data, center, regions, cult, feature_summary
					)
					if t10.x >= 0 and bool(main.call("settlement_planner_post_door", t10)):
						continue
			11:
				if intent == IntentMemory.INTENT_ABANDON:
					continue
				var open_fire_pits: int = JobManager.count_pending_by_type(Job.Type.BUILD_FIRE_PIT)
				if bed_n >= 2 and fire_pit_n + open_fire_pits == 0:
					var t11: Vector2i = _pick_infrastructure_tile(world, main, data, center, regions)
					if t11.x >= 0 and bool(main.call("settlement_planner_post_fire_pit", t11)):
						continue
			12:
				if intent == IntentMemory.INTENT_ABANDON:
					continue
				var open_storage: int = JobManager.count_pending_by_type(Job.Type.BUILD_STORAGE_HUT)
				if bed_n >= 4 and storage_hut_n + open_storage == 0:
					var t12: Vector2i = _pick_infrastructure_tile(world, main, data, center, regions)
					if t12.x >= 0 and bool(main.call("settlement_planner_post_storage_hut", t12)):
						continue
			13:
				if intent == IntentMemory.INTENT_ABANDON:
					continue
				if wall_n >= 4 and pawns >= 3:
					var t13: Vector2i = _pick_defend_tile(world, main, data, center, regions)
					if t13.x >= 0 and bool(main.call("settlement_planner_post_protect", t13)):
						continue
			14:
				if intent == IntentMemory.INTENT_ABANDON:
					continue
				if stage >= 2 and pawns >= 4:
					var t14: Vector2i = _pick_defend_tile(world, main, data, center, regions)
					if t14.x >= 0 and bool(main.call("settlement_planner_post_defend", t14)):
						continue
			15:
				# Territory expansion: growing settlements claim adjacent regions
				# as TERRITORY zones so pawns prefer building/working there.
				if intent == IntentMemory.INTENT_ABANDON:
					continue
				if pawns >= 3 and intent == IntentMemory.INTENT_GROW:
					_expand_territory_zone(world, main, data, center, regions)
			# Phase 6: Agriculture — farms when settlement has enough pawns
			16:
				if intent == IntentMemory.INTENT_ABANDON:
					continue
				if pawns >= 4 and stage >= 1:
					var farm_type: int = _pick_farm_type_for_settlement(regions, data)
					if farm_type >= 0:
						var tfarm: Vector2i = _pick_farm_tile(world, main, data, center, regions)
						if tfarm.x >= 0 and bool(main.call("settlement_planner_post_job", tfarm, farm_type)):
							return
			# Phase 6: Production — workshop when settlement has enough pawns
			17:
				if intent == IntentMemory.INTENT_ABANDON:
					continue
				if pawns >= 5 and stage >= 1:
					var workshop_n: int = int(feature_summary.get("workshop_n", 0))
					if workshop_n < 1:
						var tws: Vector2i = _pick_infrastructure_tile(world, main, data, center, regions)
						if tws.x >= 0 and bool(main.call("settlement_planner_post_job", tws, Job.Type.BUILD_WORKSHOP)):
							return
			# Phase 6: Granary — food storage for growing settlements
			18:
				if intent == IntentMemory.INTENT_ABANDON:
					continue
				if pawns >= 4 and stage >= 1:
					var granary_n: int = int(feature_summary.get("granary_n", 0))
					if granary_n < 1:
						var tgr: Vector2i = _pick_infrastructure_tile(world, main, data, center, regions)
						if tgr.x >= 0 and bool(main.call("settlement_planner_post_job", tgr, Job.Type.BUILD_GRANARY)):
							return
			# Phase 6: Road — connect settlement to nearby settlements
			19:
				if intent == IntentMemory.INTENT_ABANDON:
					continue
				if pawns >= 5 and stage >= 2:
					var road_n: int = int(feature_summary.get("road_n", 0))
					if road_n < 3:
						var troad: Vector2i = _pick_road_tile(world, main, data, center, regions)
						if troad.x >= 0 and bool(main.call("settlement_planner_post_job", troad, Job.Type.BUILD_ROAD)):
							return
			# Phase 6: Maritime — boatyard/dock near water
			20:
				if intent == IntentMemory.INTENT_ABANDON:
					continue
				if pawns >= 6 and stage >= 2:
					var boatyard_n: int = int(feature_summary.get("boatyard_n", 0))
					if boatyard_n < 1 and _has_water_nearby(data, center, regions):
						var tby: Vector2i = _pick_waterside_tile(world, main, data, center, regions)
						if tby.x >= 0 and bool(main.call("settlement_planner_post_job", tby, Job.Type.BUILD_BOATYARD)):
							return
			# Phase 6: Knowledge — library/school for advanced settlements
			21:
				if intent == IntentMemory.INTENT_ABANDON:
					continue
				if pawns >= 8 and stage >= 2:
					var library_n: int = int(feature_summary.get("library_n", 0))
					if library_n < 1:
						var tlib: Vector2i = _pick_infrastructure_tile(world, main, data, center, regions)
						if tlib.x >= 0 and bool(main.call("settlement_planner_post_job", tlib, Job.Type.BUILD_LIBRARY)):
							return
			# Phase 6: Market — trade hub for settlements with trade routes
			22:
				if intent == IntentMemory.INTENT_ABANDON:
					continue
				if pawns >= 6 and stage >= 2:
					var market_n: int = int(feature_summary.get("market_n", 0))
					if market_n < 1:
						var tmkt: Vector2i = _pick_infrastructure_tile(world, main, data, center, regions)
						if tmkt.x >= 0 and bool(main.call("settlement_planner_post_job", tmkt, Job.Type.BUILD_MARKET)):
							return
			# Phase 6: Military — barracks for settlements under threat
			23:
				if intent == IntentMemory.INTENT_ABANDON:
					continue
				if pawns >= 6 and stage >= 2:
					var barracks_n: int = int(feature_summary.get("barracks_n", 0))
					if barracks_n < 1:
						var tbar: Vector2i = _pick_infrastructure_tile(world, main, data, center, regions)
						if tbar.x >= 0 and bool(main.call("settlement_planner_post_job", tbar, Job.Type.BUILD_BARRACKS)):
							return
			# Phase 6: Apothecary — medicine for settlements with injuries
			24:
				if intent == IntentMemory.INTENT_ABANDON:
					continue
				if pawns >= 5 and stage >= 1:
					var apothecary_n: int = int(feature_summary.get("apothecary_n", 0))
					if apothecary_n < 1:
						var tapo: Vector2i = _pick_infrastructure_tile(world, main, data, center, regions)
						if tapo.x >= 0 and bool(main.call("settlement_planner_post_job", tapo, Job.Type.BUILD_APOTHECARY)):
							return
			# Phase 6: Cellar — advanced storage for mature settlements
			25:
				if intent == IntentMemory.INTENT_ABANDON:
					continue
				if pawns >= 7 and stage >= 2:
					var cellar_n: int = int(feature_summary.get("cellar_n", 0))
					if cellar_n < 1:
						var tcel: Vector2i = _pick_infrastructure_tile(world, main, data, center, regions)
						if tcel.x >= 0 and bool(main.call("settlement_planner_post_job", tcel, Job.Type.BUILD_CELLAR)):
							return


## Claim adjacent regions as TERRITORY zones for a growing settlement.
## HeelKawnians actively expand their territory by building at the frontier.
## This registers 1-ring of adjacent regions around the settlement's existing
## regions as TERRITORY zones, giving pawns priority bias to build there.
func _expand_territory_zone(
		world: World, main: Node2D, data: WorldData,
		center: Vector2i, regions: PackedInt32Array
) -> void:
	if ZoneRegistry == null:
		return
	# Build set of existing region keys
	var existing: Dictionary = {}
	for rk in regions:
		existing[int(rk)] = true
	# Find adjacent regions not yet claimed
	var adjacent: Dictionary = {}
	for rk in regions:
		var rx: int = int(rk) & 0xFFFF
		var ry: int = (int(rk) >> 16) & 0xFFFF
		# 4-connected neighbors
		for off in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0)]:
			var nrx: int = rx + off.x
			var nry: int = ry + off.y
			var nkey: int = (nrx & 0xFFFF) | ((nry & 0xFFFF) << 16)
			if not existing.has(nkey) and not adjacent.has(nkey):
				# Check that the region is passable (has at least some passable tiles)
				var crx: int = nrx * 16 + 8
				var cry: int = nry * 16 + 8
				if data.in_bounds(crx, cry) and Biome.is_passable(data.get_biome(crx, cry)):
					adjacent[nkey] = true
	# Register adjacent regions as TERRITORY zones
	for nkey in adjacent:
		var nrx: int = int(nkey) & 0xFFFF
		var nry: int = (int(nkey) >> 16) & 0xFFFF
		var rect: Rect2i = Rect2i(nrx * 16, nry * 16, 16, 16)
		ZoneRegistry.register(ZoneRegistry.ZoneType.TERRITORY, rect)


## Pick a farm type based on settlement needs and terrain.
func _pick_farm_type_for_settlement(regions: PackedInt32Array, data: WorldData) -> int:
	# Default: wheat (most reliable food source)
	# TODO: check terrain moisture for corn, check for herb needs
	return Job.Type.BUILD_FARM_WHEAT


## Pick a tile for a farm — prefer fertile soil near settlement center.
func _pick_farm_tile(world: World, main: Node2D, data: WorldData, center: Vector2i, regions: PackedInt32Array) -> Vector2i:
	# Search for fertile soil tiles first, then any passable tile
	for radius in range(2, 10):
		for dx in range(-radius, radius + 1):
			for dy in range(-radius, radius + 1):
				if abs(dx) != radius and abs(dy) != radius:
					continue
				var t: Vector2i = center + Vector2i(dx, dy)
				if not data.in_bounds(t.x, t.y):
					continue
				var feat: int = data.get_feature(t.x, t.y)
				if feat == TileFeature.Type.FERTILE_SOIL:
					if Biome.is_passable(data.get_biome(t.x, t.y)):
						return t
	# Fallback: any passable tile near center
	return _pick_infrastructure_tile(world, main, data, center, regions)


## Pick a tile for a road — prefer tiles between settlements.
func _pick_road_tile(world: World, main: Node2D, data: WorldData, center: Vector2i, regions: PackedInt32Array) -> Vector2i:
	# Simple: pick a passable tile in a direction away from center
	var offsets: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for dist in range(2, 8):
		for off in offsets:
			var t: Vector2i = center + off * dist
			if data.in_bounds(t.x, t.y):
				var feat: int = data.get_feature(t.x, t.y)
				if feat == TileFeature.Type.NONE and Biome.is_passable(data.get_biome(t.x, t.y)):
					return t
	return Vector2i(-1, -1)


## Check if there's water adjacent to any of the settlement's regions.
func _has_water_nearby(data: WorldData, center: Vector2i, regions: PackedInt32Array) -> bool:
	# Check tiles near center for water biome
	for radius in range(1, 20):
		for dx in range(-radius, radius + 1):
			for dy in range(-radius, radius + 1):
				if abs(dx) != radius and abs(dy) != radius:
					continue
				var t: Vector2i = center + Vector2i(dx, dy)
				if data.in_bounds(t.x, t.y):
					var biome: int = data.get_biome(t.x, t.y)
					if biome == Biome.Type.WATER:
						return true
	return false


## Pick a tile adjacent to water for maritime buildings.
func _pick_waterside_tile(world: World, main: Node2D, data: WorldData, center: Vector2i, regions: PackedInt32Array) -> Vector2i:
	# Find water tiles, then pick a passable tile adjacent to them
	for radius in range(1, 20):
		for dx in range(-radius, radius + 1):
			for dy in range(-radius, radius + 1):
				if abs(dx) != radius and abs(dy) != radius:
					continue
				var t: Vector2i = center + Vector2i(dx, dy)
				if not data.in_bounds(t.x, t.y):
					continue
				var biome: int = data.get_biome(t.x, t.y)
				if biome == Biome.Type.WATER:
					# Check adjacent tiles for a buildable spot
					for adj in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
						var at: Vector2i = t + adj
						if data.in_bounds(at.x, at.y):
							var feat: int = data.get_feature(at.x, at.y)
							if feat == TileFeature.Type.NONE and Biome.is_passable(data.get_biome(at.x, at.y)):
								return at
	return Vector2i(-1, -1)


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
	var c: int = preload("res://autoloads/SettlementPlanner.gd").get_culture_type_for_settlement(settlement)
	if c == CULTURE_OPEN:
		return "open"
	if c == CULTURE_DEFENSIVE:
		return "defensive"
	return "cautious"


## Tiny audio intent nudge (no gameplay effect): open -> brighter, defensive -> heavier.
## This remains deterministic because it is derived from deterministic memory state.
static func get_culture_audio_bias_for_settlement(settlement: Dictionary) -> float:
	var c: int = preload("res://autoloads/SettlementPlanner.gd").get_culture_type_for_settlement(settlement)
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
	var region_lookup: Dictionary = _regions_lookup(regions)
	for dy in range(-12, 13):
		for dx in range(-12, 13):
			if _budget_exceeded():
				break
			var t := Vector2i(center.x + dx, center.y + dy)
			if not _tile_belongs_to_lookup(t, region_lookup):
				continue
			if not bool(main.call("settlement_planner_is_valid_bed_site", t)):
				continue
			cands.append(t)
		if _budget_exceeded():
			break
	if cands.is_empty():
		return Vector2i(-1, -1)
	_sort_tiles_farthest_first_remnant(cands, center, _world)
	return cands[0]


func _pick_expansion_wall_tile_culture(
		world: World, main: Node2D, data: WorldData, center: Vector2i, regions: PackedInt32Array,
		cult: int, feature_summary: Dictionary = {}
) -> Vector2i:
	# OPEN: sprawl; DEF/CAUTIOUS: compact (nearest) ring growth.
	if cult == CULTURE_OPEN:
		return _pick_expansion_wall_tile(world, main, data, center, regions, true, feature_summary)
	return _pick_expansion_wall_tile(world, main, data, center, regions, false, feature_summary)


## Pick a tile near center for infrastructure (fire pit, storage hut).
func _pick_infrastructure_tile(
		world: World, main: Node2D, data: WorldData, center: Vector2i, regions: PackedInt32Array
) -> Vector2i:
	var region_lookup: Dictionary = _regions_lookup(regions)
	var cands: Array[Vector2i] = []
	for dy in range(-4, 5):
		for dx in range(-4, 5):
			var t := Vector2i(center.x + dx, center.y + dy)
			if not _tile_belongs_to_lookup(t, region_lookup):
				continue
			if not data.in_bounds(t.x, t.y):
				continue
			if data.get_feature(t.x, t.y) != TileFeature.Type.NONE:
				continue
			if not Biome.is_passable(data.get_biome(t.x, t.y)):
				continue
			cands.append(t)
	if cands.is_empty():
		return Vector2i(-1, -1)
	# Prefer tiles inside DEFEND_ZONE
	var defended: Array[Vector2i] = []
	var rest: Array[Vector2i] = []
	for c in cands:
		if ZoneRegistry.tile_in_zone_type(c, ZoneRegistry.ZoneType.DEFEND):
			defended.append(c)
		else:
			rest.append(c)
	if not defended.is_empty():
		_sort_tiles_index_order_remnant(defended, center, world)
		return defended[0]
	_sort_tiles_index_order_remnant(cands, center, world)
	return cands[0]


## Pick a tile near a wall for defense (protect/defend jobs).
func _pick_defend_tile(
		world: World, main: Node2D, data: WorldData, center: Vector2i, regions: PackedInt32Array
) -> Vector2i:
	var walls: Array[Vector2i] = _collect_wall_tiles_in_regions(data, regions, center)
	if walls.is_empty():
		return Vector2i(-1, -1)
	# Find passable tiles adjacent to walls
	var region_lookup: Dictionary = _regions_lookup(regions)
	var cands: Array[Vector2i] = []
	for w in walls:
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				if dx == 0 and dy == 0:
					continue
				var t := Vector2i(w.x + dx, w.y + dy)
				if not data.in_bounds(t.x, t.y):
					continue
				if not Biome.is_passable(data.get_biome(t.x, t.y)):
					continue
				if not _tile_belongs_to_lookup(t, region_lookup):
					continue
				cands.append(t)
	if cands.is_empty():
		return Vector2i(-1, -1)
	_sort_tiles_index_order_remnant(cands, center, world)
	return cands[0]


static func _center_tile_of_region_key(rk: int) -> Vector2i:
	var rx: int = int(rk) & 0xFFFF
	var ry: int = (int(rk) >> 16) & 0xFFFF
	return Vector2i(rx * 16 + 8, ry * 16 + 8)


static func _region_chebyshev_distance(rk: int, cx: int, cy: int) -> int:
	var rx: int = rk & 0xFFFF
	var ry: int = (rk >> 16) & 0xFFFF
	return maxi(abs(rx - cx), abs(ry - cy))


static func _select_planning_regions(
		center_rk: int, regions: PackedInt32Array
) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	if regions.is_empty():
		return out
	var cx: int = center_rk & 0xFFFF
	var cy: int = (center_rk >> 16) & 0xFFFF
	var nearby: Array[int] = []
	var fallback: Array[int] = []
	for j in range(regions.size()):
		var rk: int = int(regions[j])
		fallback.append(rk)
		if _region_chebyshev_distance(rk, cx, cy) <= PLANNING_REGION_RADIUS:
			nearby.append(rk)
	var source: Array[int] = nearby if not nearby.is_empty() else fallback
	source.sort_custom(func(a: int, b: int) -> bool:
		var da: int = _region_chebyshev_distance(a, cx, cy)
		var db: int = _region_chebyshev_distance(b, cx, cy)
		if da != db:
			return da < db
		return a < b
	)
	var take_n: int = mini(_planning_region_cap_for_speed(), source.size())
	for i in range(take_n):
		out.append(int(source[i]))
	return out


static func _planning_region_cap_for_speed() -> int:
	if GameManager == null:
		return PLANNING_REGION_HARD_CAP
	var gs: float = GameManager.game_speed
	if gs >= 26.0:
		return mini(4, PLANNING_REGION_HARD_CAP)
	if gs >= 12.0:
		return mini(8, PLANNING_REGION_HARD_CAP)
	return PLANNING_REGION_HARD_CAP


static func _tile_belongs_to_regions(t: Vector2i, regions: PackedInt32Array) -> bool:
	var rk: int = WorldMemory._region_key(t.x, t.y)
	for j in range(regions.size()):
		if int(regions[j]) == rk:
			return true
	return false


static func _regions_lookup(regions: PackedInt32Array) -> Dictionary:
	var out: Dictionary = {}
	for j in range(regions.size()):
		out[int(regions[j])] = true
	return out


static func _tile_belongs_to_lookup(t: Vector2i, lookup: Dictionary) -> bool:
	return lookup.has(WorldMemory._region_key(t.x, t.y))


static func _count_feature_in_regions(
		data: WorldData, regions: PackedInt32Array, feature_id: int
) -> int:
	var n: int = 0
	var _count_abort: bool = false
	for j in range(regions.size()):
		if _budget_exceeded():
			break
		var rk2: int = int(regions[j])
		var rx: int = rk2 & 0xFFFF
		var ry: int = (rk2 >> 16) & 0xFFFF
		for dy in 16:
			if _count_abort:
				break
			for dx in 16:
				if dy == 8 and dx == 0 and _budget_exceeded():
					_count_abort = true
					break
				var x: int = rx * 16 + dx
				var y: int = ry * 16 + dy
				if not data.in_bounds(x, y):
					continue
				if int(data.get_feature(x, y)) == feature_id:
					n += 1
	return n


static func _scan_region_feature_summary(
		data: WorldData, regions: PackedInt32Array
) -> Dictionary:
	var bed_n: int = 0
	var wall_n: int = 0
	var door_n: int = 0
	var fire_pit_n: int = 0
	var storage_hut_n: int = 0
	# Phase 6: new building counts
	var farm_n: int = 0
	var workshop_n: int = 0
	var granary_n: int = 0
	var road_n: int = 0
	var boatyard_n: int = 0
	var library_n: int = 0
	var market_n: int = 0
	var barracks_n: int = 0
	var apothecary_n: int = 0
	var cellar_n: int = 0
	var wx0: int = 1_000_000
	var wx1: int = -1_000_000
	var wy0: int = 1_000_000
	var wy1: int = -1_000_000
	var wall_any: bool = false
	var _scan_abort: bool = false
	for j in range(regions.size()):
		if _budget_exceeded():
			break
		var rk2: int = int(regions[j])
		var rx: int = rk2 & 0xFFFF
		var ry: int = (rk2 >> 16) & 0xFFFF
		for dy in 16:
			if _scan_abort:
				break
			for dx in 16:
				# Budget check every 64 tiles to prevent frame spikes
				var x: int = rx * 16 + dx
				var y: int = ry * 16 + dy
				if ((dx == 8 and dy == 8) and _budget_exceeded()):
					_scan_abort = true
					break
				if not data.in_bounds(x, y):
					continue
				var f: int = int(data.get_feature(x, y))
				if f == TileFeature.Type.BED:
					bed_n += 1
				elif f == TileFeature.Type.WALL:
					wall_n += 1
					wall_any = true
					wx0 = mini(wx0, x)
					wx1 = maxi(wx1, x)
					wy0 = mini(wy0, y)
					wy1 = maxi(wy1, y)
				elif f == TileFeature.Type.DOOR:
					door_n += 1
				elif f == TileFeature.Type.FIRE_PIT:
					fire_pit_n += 1
				elif f == TileFeature.Type.STORAGE_HUT:
					storage_hut_n += 1
				# Phase 6: new building counts
				elif f == TileFeature.Type.FARM_WHEAT or f == TileFeature.Type.FARM_CORN or f == TileFeature.Type.FARM_VEGETABLES or f == TileFeature.Type.HERB_GARDEN:
					farm_n += 1
				elif f == TileFeature.Type.WORKSHOP:
					workshop_n += 1
				elif f == TileFeature.Type.GRANARY:
					granary_n += 1
				elif f == TileFeature.Type.ROAD:
					road_n += 1
				elif f == TileFeature.Type.BOATYARD:
					boatyard_n += 1
				elif f == TileFeature.Type.LIBRARY:
					library_n += 1
				elif f == TileFeature.Type.MARKET:
					market_n += 1
				elif f == TileFeature.Type.BARRACKS:
					barracks_n += 1
				elif f == TileFeature.Type.APOTHECARY:
					apothecary_n += 1
				elif f == TileFeature.Type.CELLAR:
					cellar_n += 1
	return {
		"bed_n": bed_n,
		"wall_n": wall_n,
		"door_n": door_n,
		"wall_any": wall_any,
		"wall_x0": wx0,
		"wall_x1": wx1,
		"wall_y0": wy0,
		"wall_y1": wy1,
		"fire_pit_n": fire_pit_n,
		"storage_hut_n": storage_hut_n,
		# Phase 6: new building counts
		"farm_n": farm_n,
		"workshop_n": workshop_n,
		"granary_n": granary_n,
		"road_n": road_n,
		"boatyard_n": boatyard_n,
		"library_n": library_n,
		"market_n": market_n,
		"barracks_n": barracks_n,
		"apothecary_n": apothecary_n,
		"cellar_n": cellar_n,
	}


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
		var zone_bonus_a: int = -3 if ZoneRegistry.tile_in_zone_type(a2, ZoneRegistry.ZoneType.BUILD) else 0
		var zone_bonus_b: int = -3 if ZoneRegistry.tile_in_zone_type(b2, ZoneRegistry.ZoneType.BUILD) else 0
		var am: int = (
				abs(a2.x - center.x)
				+ abs(a2.y - center.y)
				+ RemnantMemory.get_planner_penalty(a2, w)
				+ zone_bonus_a
		)
		var bm: int = (
				abs(b2.x - center.x)
				+ abs(b2.y - center.y)
				+ RemnantMemory.get_planner_penalty(b2, w)
				+ zone_bonus_b
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
	var region_lookup: Dictionary = _regions_lookup(regions)
	for dy in range(-12, 13):
		for dx in range(-12, 13):
			if _budget_exceeded():
				break
			var t := Vector2i(center.x + dx, center.y + dy)
			if not _tile_belongs_to_lookup(t, region_lookup):
				continue
			if not bool(main.call("settlement_planner_is_valid_bed_site", t)):
				continue
			cands.append(t)
		if _budget_exceeded():
			break
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
		data: WorldData, regions: PackedInt32Array, max_tiles: int = -1
) -> Array[Vector2i]:
	if _budget_exceeded():
		return []
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
					if max_tiles > 0 and out0.size() >= max_tiles:
						return out0
	return out0


## All valid door sites (on walls or passable) in the settlement, deduped; caller sorts by culture.
static func _collect_viable_door_tiles(
		world: World, main: Node2D, _data: WorldData, center: Vector2i, regions: PackedInt32Array
) -> Array[Vector2i]:
	if _budget_exceeded():
		return []
	var by_linear: Dictionary = {}
	var region_lookup: Dictionary = _regions_lookup(regions)
	for t in _collect_wall_tiles_in_regions_nosort(world.data, regions, PLANNER_WALL_SCAN_CAP):
		if not bool(main.call("settlement_planner_is_valid_door_site", t)):
			continue
		by_linear[t.y * WorldData.WIDTH + t.x] = t
	for dy in range(-6, 7):
		for dx in range(-6, 7):
			var t2: Vector2i = Vector2i(center.x + dx, center.y + dy)
			if not _tile_belongs_to_lookup(t2, region_lookup):
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
		data: WorldData, regions: PackedInt32Array, max_tiles: int = -1
) -> Array[Vector2i]:
	if _budget_exceeded():
		return []
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
					if max_tiles > 0 and outb.size() >= max_tiles:
						return outb
	return outb


static func _wall_bbox_too_small(
		data: WorldData, regions: PackedInt32Array, min_span: int, feature_summary: Dictionary = {}
) -> bool:
	if not feature_summary.is_empty():
		var any_w_cached: bool = bool(feature_summary.get("wall_any", false))
		if not any_w_cached:
			return false
		var wx0_cached: int = int(feature_summary.get("wall_x0", 1_000_000))
		var wx1_cached: int = int(feature_summary.get("wall_x1", -1_000_000))
		var wy0_cached: int = int(feature_summary.get("wall_y0", 1_000_000))
		var wy1_cached: int = int(feature_summary.get("wall_y1", -1_000_000))
		var w_cached: int = wx1_cached - wx0_cached + 1
		var h_cached: int = wy1_cached - wy0_cached + 1
		return w_cached < min_span or h_cached < min_span
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
		prefer_farthest: bool = false, feature_summary: Dictionary = {}
) -> Vector2i:
	if _budget_exceeded():
		return Vector2i(-1, -1)
	var wx0: int = 1_000_000
	var wx1: int = -1_000_000
	var wy0: int = 1_000_000
	var wy1: int = -1_000_000
	var any_w2: bool = false
	if not feature_summary.is_empty() and bool(feature_summary.get("wall_any", false)):
		any_w2 = true
		wx0 = int(feature_summary.get("wall_x0", wx0))
		wx1 = int(feature_summary.get("wall_x1", wx1))
		wy0 = int(feature_summary.get("wall_y0", wy0))
		wy1 = int(feature_summary.get("wall_y1", wy1))
	if not any_w2:
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
	var region_lookup: Dictionary = _regions_lookup(regions)
	var cands3: Array[Vector2i] = []
	for y3 in range(ey0, ey1 + 1):
		for x3 in range(ex0, ex1 + 1):
			if not (x3 == ex0 or x3 == ex1 or y3 == ey0 or y3 == ey1):
				continue
			if int(data.get_feature(x3, y3)) == TileFeature.Type.WALL:
				continue
			var ts: Vector2i = Vector2i(x3, y3)
			if not _tile_belongs_to_lookup(ts, region_lookup):
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
		bed_n: int, wall_n: int, door_n: int, feature_summary: Dictionary = {}
) -> int:
	if bed_n <= 0:
		return 0
	var span7: bool = not _wall_bbox_too_small(data, regions, VILLAGE_SPAN, feature_summary)
	var path_ok: bool = _path_bed_to_center_exists(world, data, center, regions)
	if bed_n > 0 and wall_n >= 6 and door_n >= 2 and span7 and path_ok:
		return 2
	if bed_n >= 2 and wall_n >= 4 and door_n >= 1:
		return 1
	return 0


static func _path_bed_to_center_exists(
		world: World, data: WorldData, center: Vector2i, regions: PackedInt32Array
) -> bool:
	if _budget_exceeded():
		return true  # Assume path exists if budget exceeded — skip expensive check
	var beds0: Array[Vector2i] = _collect_bed_tiles_in_regions(data, regions, PLANNER_BED_SCAN_CAP)
	if beds0.is_empty():
		return true
	_sort_tiles_index_order(beds0, center)
	var pf: PathFinder = world.pathfinder
	if pf == null:
		return true
	var center_comp: int = pf.component_of(center)
	var probes: int = mini(PLANNER_BED_PATH_PROBE_CAP, beds0.size())
	for i in range(probes):
		var b0: Vector2i = beds0[i]
		if b0 == center:
			return true
		if center_comp >= 0 and pf.component_of(b0) == center_comp:
			return true
		if center_comp < 0:
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
	var region_lookup: Dictionary = _regions_lookup(regions)
	for dy2 in range(-8, 9):
		for dx2 in range(-8, 9):
			if _budget_exceeded():
				break
			var t3 := Vector2i(center.x + dx2, center.y + dy2)
			if not _tile_belongs_to_lookup(t3, region_lookup):
				continue
			if int(data.get_feature(t3.x, t3.y)) == TileFeature.Type.DOOR:
				continue
			if not bool(main.call("settlement_planner_is_valid_door_site", t3)):
				continue
			by_idx[t3.y * WorldData.WIDTH + t3.x] = t3
		if _budget_exceeded():
			break
	if by_idx.is_empty():
		return Vector2i(-1, -1)
	var uniq: Array[Vector2i] = []
	for k in by_idx:
		uniq.append(by_idx[k] as Vector2i)
	_sort_tiles_farthest_first_remnant(uniq, center, _world)
	return uniq[0]


func _first_interior_bbox_wall_door(
		_world: World, main: Node2D, data: WorldData, center: Vector2i, regions: PackedInt32Array,
		cult: int, feature_summary: Dictionary = {}
) -> Vector2i:
	if _budget_exceeded():
		return Vector2i(-1, -1)
	var wx0: int = 1_000_000
	var wx1: int = -1_000_000
	var wy0: int = 1_000_000
	var wy1: int = -1_000_000
	var any_w3: bool = false
	if not feature_summary.is_empty() and bool(feature_summary.get("wall_any", false)):
		any_w3 = true
		wx0 = int(feature_summary.get("wall_x0", wx0))
		wx1 = int(feature_summary.get("wall_x1", wx1))
		wy0 = int(feature_summary.get("wall_y0", wy0))
		wy1 = int(feature_summary.get("wall_y1", wy1))
	if not any_w3:
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
	var region_lookup: Dictionary = _regions_lookup(regions)
	var cin: Array[Vector2i] = []
	for y5 in range(wy0 + 1, wy1):
		for x5 in range(wx0 + 1, wx1):
			if not data.in_bounds(x5, y5):
				continue
			var t5: Vector2i = Vector2i(x5, y5)
			if not _tile_belongs_to_lookup(t5, region_lookup):
				continue
			if int(data.get_feature(x5, y5)) != TileFeature.Type.WALL:
				continue
			if not bool(main.call("settlement_planner_is_valid_door_site", t5)):
				continue
			cin.append(t5)
	if cin.is_empty():
		return Vector2i(-1, -1)
	if cult == CULTURE_OPEN:
		_sort_tiles_farthest_first_remnant(cin, center, _world)
	else:
		_sort_tiles_index_order_remnant(cin, center, _world)
	return cin[0]
