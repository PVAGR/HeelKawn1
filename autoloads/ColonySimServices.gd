extends Node

## Single entry point for lightweight Phase-2b simulation hooks: settlement
## need pressure, labor stance, and (later) district tie-ins. Ticks with the sim.

## Broad macro labour bias — affects which job *types* get a few extra priority
## points when the queue is being searched (not work toggles: those are per-pawn).
enum LaborStance {
	BALANCED,
	FOOD_FIRST,
	BUILD_FIRST,
	HAUL_FIRST,
}

const DEMAND_REFRESH_INTERVAL_TICKS: int = 30
## All macro pressures below this for CONTENTMENT_STREAK_TICKS → colony_contentment_period().
const CONTENTMENT_MAX_PRESSURE: float = 0.15
const CONTENTMENT_STREAK_TICKS: int = 90

## Emitted so HUD and future UIs can reflect demand without polling every item.
signal demand_snapshot(
		food: float, housing: float, materials: float, hauling: float)

var current_labor_stance: int = LaborStance.BALANCED

var _food_press: float = 0.0
var _housing_press: float = 0.0
var _mat_press: float = 0.0
var _haul_press: float = 0.0
var _warmth_press: float = 0.0
var _cooking_press: float = 0.0
var _storage_press: float = 0.0
var _cached_colony_world: World = null
var _low_pressure_streak_ticks: int = 0
## Per formal settlement center_region — posts consumed during one construction seed pass (per tick).
var _settlement_posts_this_pass: Dictionary = {}
var _construction_pass_tick: int = -1

## Per stockpile zone tile and per STORAGE_HUT feature (matches BuildingRegistry buffs).
const STOCKPILE_TILE_CAPACITY: int = 8
const STORAGE_HUT_CAPACITY: int = 4
const GRANARY_FOOD_CAPACITY: int = 4
const CELLAR_STORAGE_CAPACITY: int = 6

## Body temp below this is "cold" (matches HeelKawnian warmth-seeking).
const COMFORT_BODY_TEMP_C: float = 36.5
## Chebyshev radius for fire-pit warmth coverage (matches _hearth_proxy_warmth_bonus).
const HEARTH_COVERAGE_RADIUS: int = 2


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameManager.game_tick.connect(_on_tick)
	# Autoloads run before Main exists; one frame later we can see World/pawns.
	call_deferred("_bootstrap_demands_after_scene")


func _bootstrap_demands_after_scene() -> void:
	_refresh_food_mat_haul_pressures()
	_refresh_housing_pressure()
	_refresh_warmth_cooking_pressures()
	_refresh_storage_pressure()
	demand_snapshot.emit(_food_press, _housing_press, _mat_press, _haul_press)


func _on_tick(tick: int) -> void:
	if tick % DEMAND_REFRESH_INTERVAL_TICKS == 0:
		_refresh_all_demands_immediate()
		_update_contentment_streak()
		demand_snapshot.emit(_food_press, _housing_press, _mat_press, _haul_press)


## Food pressure: 0 = plenty, 1 = acute shortage (simplified: inverse of food cap).
func _refresh_all_demands_immediate() -> void:
	_refresh_food_mat_haul_pressures()
	_refresh_housing_pressure()
	_refresh_warmth_cooking_pressures()
	_refresh_storage_pressure()


func _refresh_food_mat_haul_pressures() -> void:
	var snap: Dictionary = StockpileManager.labor_pressure_stock_snapshot()
	var food_total: int = int(snap.get("food", 0)) + _food_carried_by_pawns()
	var wood: int = int(snap.get("wood", 0))
	var stone: int = int(snap.get("stone", 0))
	_food_press = clamp(1.0 - float(food_total) / 30.0, 0.0, 1.0)
	_mat_press = clamp(1.0 - float(mini(wood, 24) + mini(stone, 12)) / 40.0, 0.0, 1.0)
	var open_harvest: int = JobManager.open_count()
	_haul_press = clamp(float(open_harvest) / 120.0, 0.0, 1.0)


func _food_carried_by_pawns() -> int:
	var total: int = 0
	for p in PawnAccess.find_alive_pawns():
		if p == null or not is_instance_valid(p) or p.data == null:
			continue
		if p.data.is_carrying() and Item.is_food(int(p.data.carrying)):
			total += int(p.data.carrying_qty)
	return total


## 0 = enough beds (or no pawns); 1 = many pawns share few beds. Uses `World` bed
## list vs pawns in group `pawns` (rough macro signal, not per-night scheduling).
## Call from [_on_tick] on DEMAND_REFRESH_INTERVAL_TICKS, or from immediate refresh paths.
func _refresh_housing_pressure() -> void:
	var scene_tree: SceneTree = get_tree()
	if scene_tree == null:
		_housing_press = 0.0
		return
	var pawns: int = PawnAccess.find_alive_pawns().size()
	if pawns <= 0:
		_housing_press = 0.0
		return
	var world: World = _get_colony_world()
	var beds: int = world.bed_count() if world != null else 0
	if beds >= pawns:
		_housing_press = 0.0
	else:
		_housing_press = clamp(float(pawns - beds) / float(pawns), 0.0, 1.0)


func _get_colony_world() -> World:
	if _cached_colony_world != null and is_instance_valid(_cached_colony_world):
		return _cached_colony_world
	var scene_tree: SceneTree = get_tree()
	if scene_tree == null:
		return null
	for n in scene_tree.get_nodes_in_group("colony_world"):
		if n is World:
			_cached_colony_world = n as World
			return _cached_colony_world
	return null


func get_stance_display() -> String:
	return _stance_name(current_labor_stance)


func get_food_pressure() -> float:
	return _food_press


func get_housing_pressure() -> float:
	return _housing_press


func get_materials_pressure() -> float:
	return _mat_press


func get_haul_pressure() -> float:
	return _haul_press


func colony_contentment_period() -> bool:
	return _low_pressure_streak_ticks >= CONTENTMENT_STREAK_TICKS


func get_contentment_streak_ticks() -> int:
	return _low_pressure_streak_ticks


func _update_contentment_streak() -> void:
	var peak: float = maxf(
			_food_press,
			maxf(_housing_press, maxf(_mat_press, maxf(_haul_press, maxf(_warmth_press, maxf(_cooking_press, _storage_press))))))
	if peak < CONTENTMENT_MAX_PRESSURE:
		_low_pressure_streak_ticks += DEMAND_REFRESH_INTERVAL_TICKS
	else:
		_low_pressure_streak_ticks = 0


## BUILD_HEARTH and BUILD_FIRE_PIT both complete as TileFeature.FIRE_PIT; regional cap uses fire-pit rules.
func is_hearth_build_job(job_type: int) -> bool:
	return job_type == Job.Type.BUILD_FIRE_PIT or job_type == Job.Type.BUILD_HEARTH


func resolve_hearth_post_job_type(job_type: int) -> int:
	if job_type == Job.Type.BUILD_HEARTH:
		return Job.Type.BUILD_FIRE_PIT
	return job_type


## Farm slots scale with food pressure and registry yield (not blind pop/5).
func estimate_farm_cap(local_pop: int, food_press: float, _farms_built: int = 0) -> int:
	if local_pop <= 0:
		return 0
	var baseline: int = maxi(1, int(ceil(float(local_pop) / 5.0)))
	if food_press <= 0.40:
		return baseline
	var yield_per_farm: int = 4
	if BuildingRegistry != null:
		var building: Dictionary = BuildingRegistry.get_building_by_job_type(Job.Type.BUILD_FARM_WHEAT)
		var buffs: Dictionary = building.get("buffs", {})
		yield_per_farm = maxi(1, int(buffs.get("yield", 4)))
	var meals_target: int = maxi(local_pop, int(ceil(float(local_pop) * food_press * 1.25)))
	var pressure_cap: int = int(ceil(float(meals_target) / float(yield_per_farm)))
	return maxi(baseline, mini(pressure_cap, maxi(baseline + 1, int(ceil(float(local_pop) / 3.0)))))


func begin_settlement_construction_pass() -> void:
	var tick: int = GameManager.tick_count if GameManager != null else 0
	if tick == _construction_pass_tick:
		return
	_construction_pass_tick = tick
	_settlement_posts_this_pass.clear()


func try_consume_settlement_build_slot(center_region: int, job_cap: int) -> bool:
	if job_cap <= 0:
		return false
	var key: int = center_region
	var used: int = int(_settlement_posts_this_pass.get(key, 0))
	if used >= job_cap:
		return false
	_settlement_posts_this_pass[key] = used + 1
	return true


func settlement_posts_used(center_region: int) -> int:
	return int(_settlement_posts_this_pass.get(center_region, 0))


## Ambition-tier optional buildings (workshop, library, …) wait out contentment streaks.
func should_block_ambition_tier_build() -> bool:
	return colony_contentment_period()


## Leaders with high drive may post ambition-tier builds before the contentment streak completes.
func leader_may_skip_contentment_gate(center_region: int) -> bool:
	if not colony_contentment_period():
		return false
	if SettlementMemory == null:
		return false
	var center_tile: Vector2i = _center_tile_for_region(center_region)
	var rk: int = WorldMemory._region_key(center_tile.x, center_tile.y)
	var sid: int = SettlementMemory.get_settlement_id_for_region(rk)
	if sid < 0:
		return false
	var ruler_id: int = SettlementMemory.get_ruler_pawn_id(sid)
	if ruler_id < 0:
		return false
	if HeelKawnianManager == null:
		return false
	var ruler_pawn: Node = null
	for p in PawnAccess.find_alive_pawns():
		if p != null and p.data != null and int(p.data.id) == ruler_id:
			ruler_pawn = p
			break
	if ruler_pawn == null:
		return false
	var profile: Dictionary = HeelKawnianManager.get_development_profile_for_pawn(ruler_pawn)
	var drive: String = str(profile.get("development_drive", "")).to_lower()
	return drive in ["innovate", "expand", "lead", "preserve", "bond"]


## 0 = pawns warm enough near hearths; 1 = many cold pawns lack fire coverage.
## Optional [param center_region]: settlement center region key; -1 = whole colony.
func get_warmth_pressure(center_region: int = -1) -> float:
	if center_region < 0:
		return _warmth_press
	return _warmth_pressure_for_scope(center_region)


## 0 = no raw backlog / no hearths; 1 = raw food waiting at hearths.
func get_cooking_pressure(center_region: int = -1) -> float:
	if center_region < 0:
		return _cooking_press
	return _cooking_pressure_for_scope(center_region)


## 0 = storage adequate; 1 = stockpiles full / goods rotting on the ground.
## Optional [param center_region]: settlement center region key; -1 = whole colony.
func get_storage_pressure(center_region: int = -1) -> float:
	if center_region < 0:
		return _storage_press
	return _storage_pressure_for_scope(center_region)


## Living pawns below comfort temp without a fire pit within HEARTH_COVERAGE_RADIUS.
func count_cold_uncovered_pawns(center_region: int = -1) -> int:
	var n: int = 0
	for p in PawnAccess.find_alive_pawns():
		if p == null or not is_instance_valid(p) or p.data == null:
			continue
		if not _pawn_in_scope(p, center_region):
			continue
		if _pawn_is_cold_without_hearth(p):
			n += 1
	return n


func _refresh_warmth_cooking_pressures() -> void:
	_warmth_press = _warmth_pressure_for_scope(-1)
	_cooking_press = _cooking_pressure_for_scope(-1)


func _refresh_storage_pressure() -> void:
	_storage_press = _storage_pressure_for_scope(-1)


func _storage_pressure_for_scope(center_region: int) -> float:
	var pop: int = _population_in_scope(center_region)
	var capacity: int = _storage_capacity_for_scope(center_region, pop)
	var stored: int = _stored_bulk_for_scope(center_region)
	var ground: Dictionary = _ground_bulk_for_scope(center_region)
	var ground_wood: int = int(ground.get("wood", 0))
	var ground_food: int = int(ground.get("food", 0))
	var ground_bulk: int = ground_wood + ground_food
	var usage: int = stored + ground_bulk
	if capacity <= 0:
		capacity = maxi(12, pop * 6)
	var fill_ratio: float = float(usage) / float(maxi(capacity, 1))
	var pressure: float = clampf((fill_ratio - 0.75) / 0.35, 0.0, 1.0)
	# Loose goods on the ground are a strong overflow signal.
	if ground_bulk > maxi(4, pop * 2):
		pressure = maxf(pressure, clampf(float(ground_bulk - pop * 2) / 16.0, 0.0, 1.0))
	if pop >= 3 and _storage_hut_count_for_scope(center_region) <= 0 and stored + ground_bulk >= pop * 4:
		pressure = maxf(pressure, 0.35)
	return clampf(pressure, 0.0, 1.0)


func _population_in_scope(center_region: int) -> int:
	var n: int = 0
	for p in PawnAccess.find_alive_pawns():
		if p == null or not is_instance_valid(p):
			continue
		if _pawn_in_scope(p, center_region):
			n += 1
	return n


func _storage_capacity_for_scope(center_region: int, pop: int) -> int:
	var cap: int = maxi(8, pop * 5)
	if StockpileManager != null:
		for z in StockpileManager.zones():
			if z == null or not is_instance_valid(z):
				continue
			if not _tile_in_scope(z.tile, center_region):
				continue
			cap += maxi(1, z.rect.size.x * z.rect.size.y) * STOCKPILE_TILE_CAPACITY
	var world: World = _get_colony_world()
	if world != null and world.data != null:
		cap += _storage_hut_count_for_scope(center_region) * STORAGE_HUT_CAPACITY
		cap += _feature_count_in_scope(TileFeature.Type.GRANARY, center_region) * GRANARY_FOOD_CAPACITY
		cap += _feature_count_in_scope(TileFeature.Type.CELLAR, center_region) * CELLAR_STORAGE_CAPACITY
	return cap


func _stored_bulk_for_scope(center_region: int) -> int:
	if StockpileManager == null:
		return 0
	if center_region < 0:
		var snap: Dictionary = StockpileManager.labor_pressure_stock_snapshot()
		return int(snap.get("food", 0)) + int(snap.get("wood", 0)) + int(snap.get("stone", 0))
	var total: int = 0
	for z in StockpileManager.zones():
		if z == null or not is_instance_valid(z):
			continue
		if not _tile_in_scope(z.tile, center_region):
			continue
		total += z.total_item_count()
	return total


func _ground_bulk_for_scope(center_region: int) -> Dictionary:
	var world: World = _get_colony_world()
	if world == null or not world.has_method("sum_ground_resources"):
		return {"wood": 0, "food": 0}
	if center_region < 0:
		return world.sum_ground_resources()
	return world.sum_ground_resources(center_region)


func _tile_in_scope(tile: Vector2i, center_region: int) -> bool:
	if center_region < 0:
		return true
	var rk: int = WorldMemory._region_key(tile.x, tile.y)
	return SettlementMemory.get_center_region_for_region(rk) == center_region


func _storage_hut_count_for_scope(center_region: int) -> int:
	return _feature_count_in_scope(TileFeature.Type.STORAGE_HUT, center_region)


func _feature_count_in_scope(feature_type: int, center_region: int) -> int:
	if center_region >= 0:
		var crx: int = center_region & 0xFFFF
		var cry: int = (center_region >> 16) & 0xFFFF
		var center_tile: Vector2i = Vector2i(crx * 16 + 8, cry * 16 + 8)
		var features: Dictionary = HeelKawnianManager._scan_local_features(center_tile, 12)
		match feature_type:
			TileFeature.Type.STORAGE_HUT:
				return int(features.get("storage_hut", 0))
			TileFeature.Type.GRANARY:
				return int(features.get("granary", 0))
			TileFeature.Type.CELLAR:
				return int(features.get("cellar", 0))
			_:
				return 0
	var world: World = _get_colony_world()
	if world == null:
		return 0
	var counts: Dictionary = world.get_feature_counts()
	return int(counts.get(feature_type, 0))


func _warmth_pressure_for_scope(center_region: int) -> float:
	var total: int = 0
	var cold_uncovered: int = 0
	for p in PawnAccess.find_alive_pawns():
		if p == null or not is_instance_valid(p) or p.data == null:
			continue
		if not _pawn_in_scope(p, center_region):
			continue
		total += 1
		if _pawn_is_cold_without_hearth(p):
			cold_uncovered += 1
	if total <= 0:
		return 0.0
	return clamp(float(cold_uncovered) / float(total), 0.0, 1.0)


func _cooking_pressure_for_scope(center_region: int) -> float:
	if StockpileManager == null:
		return 0.0
	var raw: int = StockpileManager.total_count_of(Item.Type.MEAT) \
			+ StockpileManager.total_count_of(Item.Type.FISH) \
			+ StockpileManager.total_count_of(Item.Type.BERRY)
	if raw <= 0:
		return 0.0
	var hearths: int = _hearth_count_for_scope(center_region)
	if hearths <= 0:
		return 0.0
	var pending_cooks: int = 0
	if JobManager != null:
		pending_cooks = JobManager.count_pending_by_type(Job.Type.COOK_MEAT) \
				+ JobManager.count_pending_by_type(Job.Type.COOK_FISH) \
				+ JobManager.count_pending_by_type(Job.Type.COOK_BERRIES)
	var backlog: int = maxi(0, raw - pending_cooks)
	return clamp(float(backlog) / 12.0, 0.0, 1.0)


func _pawn_in_scope(pawn: Node, center_region: int) -> bool:
	if center_region < 0:
		return true
	if pawn.data == null:
		return false
	var tile: Vector2i = pawn.data.tile_pos
	var rk: int = WorldMemory._region_key(tile.x, tile.y)
	return SettlementMemory.get_center_region_for_region(rk) == center_region


func _pawn_is_cold_without_hearth(pawn: Node) -> bool:
	var data = pawn.data
	if data == null:
		return false
	if float(data.body_temperature) >= COMFORT_BODY_TEMP_C:
		return false
	return not _tile_has_hearth_coverage(data.tile_pos)


func tile_has_hearth_coverage(tile: Vector2i) -> bool:
	return _tile_has_hearth_coverage(tile)


func _tile_has_hearth_coverage(tile: Vector2i) -> bool:
	var world: World = _get_colony_world()
	if world == null or world.data == null:
		return false
	for dx in range(-HEARTH_COVERAGE_RADIUS, HEARTH_COVERAGE_RADIUS + 1):
		for dy in range(-HEARTH_COVERAGE_RADIUS, HEARTH_COVERAGE_RADIUS + 1):
			var t: Vector2i = tile + Vector2i(dx, dy)
			if not world.data.in_bounds(t.x, t.y):
				continue
			if int(world.data.get_feature(t.x, t.y)) == TileFeature.Type.FIRE_PIT:
				return true
	return false


func _hearth_count_for_scope(center_region: int) -> int:
	if center_region >= 0:
		var crx: int = center_region & 0xFFFF
		var cry: int = (center_region >> 16) & 0xFFFF
		var center_tile: Vector2i = Vector2i(crx * 16 + 8, cry * 16 + 8)
		var features: Dictionary = HeelKawnianManager._scan_local_features(center_tile, 12)
		return int(features.get("hearth", 0))
	var centroid: Vector2i = _colony_centroid_tile()
	if centroid.x < 0:
		return 0
	var colony_features: Dictionary = HeelKawnianManager._scan_local_features(centroid, 14)
	return int(colony_features.get("hearth", 0))


func _colony_centroid_tile() -> Vector2i:
	var sx: int = 0
	var sy: int = 0
	var n: int = 0
	for p in PawnAccess.find_alive_pawns():
		if p == null or not is_instance_valid(p) or p.data == null:
			continue
		sx += int(p.data.tile_pos.x)
		sy += int(p.data.tile_pos.y)
		n += 1
	if n <= 0:
		return Vector2i(-1, -1)
	return Vector2i(int(sx / n), int(sy / n))


func cycle_labor_stance() -> void:
	current_labor_stance = (current_labor_stance + 1) % 4
	if OS.is_debug_build():
		print("[Colony] Labor stance: %s" % _stance_name(current_labor_stance))
	_refresh_all_demands_immediate()
	demand_snapshot.emit(_food_press, _housing_press, _mat_press, _haul_press)


func _stance_name(s: int) -> String:
	match s:
		LaborStance.BALANCED:   return "balanced"
		LaborStance.FOOD_FIRST:  return "food first"
		LaborStance.BUILD_FIRST: return "build first"
		LaborStance.HAUL_FIRST:  return "haul first"
	return "?"


## For `JobManager.claim_next_for` third argument. Small nudges only — the core
## queue priority still wins in large gaps.
func job_priority_stance_bias(job: Job) -> int:
	if job == null:
		return 0
	match current_labor_stance:
		LaborStance.BALANCED:
			return 0
		LaborStance.FOOD_FIRST:
			if job.type == Job.Type.FORAGE or job.type == Job.Type.HUNT or job.type == Job.Type.FISH:
				return 3
			return 0
		LaborStance.BUILD_FIRST:
			if job.type == Job.Type.BUILD_BED or job.type == Job.Type.BUILD_WALL \
					or job.type == Job.Type.BUILD_DOOR or job.type == Job.Type.MINE_WALL:
				return 3
			return 0
		LaborStance.HAUL_FIRST:
			# Pawns that already carry re-route in `_tick_idle`; this biases fetch jobs.
			match job.type:
				Job.Type.FORAGE, Job.Type.MINE, Job.Type.CHOP, Job.Type.MINE_WALL, \
				Job.Type.HUNT, Job.Type.FISH, Job.Type.TRADE_HAUL:
					return 2
			return 0
	return 0


## Need urgency (0..1) for scoring autonomous choices.
static func need_urgency_hunger(hunger: float) -> float:
	return clamp(1.0 - hunger / 100.0, 0.0, 1.0)


static func need_urgency_rest(rest: float) -> float:
	return clamp(1.0 - rest / 100.0, 0.0, 1.0)


func get_colony_truth() -> Dictionary:
	var stockpile_food: int = 0
	var carried_food: int = 0
	var food_in_pawn_hands: int = 0
	var total_immediately_available_food: int = 0
	var population: int = 0
	var food_pressure_state: String = "unknown"
	var contradiction_flags: Array[String] = []
	var warnings: Array[String] = []
	
	# Get stockpile food
	if StockpileManager != null:
		stockpile_food = StockpileManager.total_food()
	
	# Get carried food from living pawns
	if PawnSpawner != null:
		for pawn in PawnAccess.find_pawns():
			if pawn != null and is_instance_valid(pawn) and pawn.data != null and not bool(pawn.data.is_dead):
				population += 1
				if pawn.data != null and pawn.data.has("carrying"):
					var carrying = pawn.data.carrying
					if carrying != null and carrying.has("item_type") and carrying.item_type == "food":
						carried_food += int(carrying.get("quantity", 0))
						food_in_pawn_hands += int(carrying.get("quantity", 0))
	
	total_immediately_available_food = stockpile_food + carried_food
	
	# Determine food pressure state
	if total_immediately_available_food <= 0:
		food_pressure_state = "starvation"
	elif total_immediately_available_food < population * 2:
		food_pressure_state = "shortage"
	elif total_immediately_available_food < population * 10:
		food_pressure_state = "low"
	else:
		food_pressure_state = "adequate"
	
	# Check for contradictions
	if stockpile_food == 0 and carried_food > 0:
		contradiction_flags.append("stockpile_empty_but_carried_food_present")
	
	# Add warnings
	if total_immediately_available_food <= 0 and population > 0:
		warnings.append("no_food_available")
	elif stockpile_food == 0:
		warnings.append("stockpile_empty")
	
	return {
		"stockpile_food": stockpile_food,
		"carried_food": carried_food,
		"food_in_pawn_hands": food_in_pawn_hands,
		"total_immediately_available_food": total_immediately_available_food,
		"population": population,
		"food_pressure_state": food_pressure_state,
		"contradiction_flags": contradiction_flags,
		"warnings": warnings,
	}


## 0 = daylight; 1 = many pawns in scope lack hearth coverage at night (DayNightCycle).
func get_light_pressure(center_region: int = -1) -> float:
	if GameManager == null or not DayNightCycle.is_night_for_tick(GameManager.tick_count):
		return 0.0
	var total: int = 0
	var dark_uncovered: int = 0
	for p in PawnAccess.find_alive_pawns():
		if p == null or not is_instance_valid(p) or p.data == null:
			continue
		if not _pawn_in_scope(p, center_region):
			continue
		total += 1
		if not _tile_has_hearth_coverage(p.data.tile_pos):
			dark_uncovered += 1
	if total <= 0:
		return 0.0
	return clamp(float(dark_uncovered) / float(total), 0.0, 1.0)


## Ranked settlement build needs for seeders / leader posts. [param center_region] is
## settlement center region key; [param local_pop] and [param features] come from local scan.
func compute_settlement_build_priorities(
		center_region: int,
		local_pop: int,
		features: Dictionary,
		materials_crisis: bool = false,
) -> Dictionary:
	var hearths: int = int(features.get("hearth", 0))
	var beds: int = int(features.get("bed", 0))
	var storage_huts: int = int(features.get("storage_hut", 0))
	var farms: int = int(features.get("farm", 0))
	var cold_uncovered: int = count_cold_uncovered_pawns(center_region) if center_region >= 0 else count_cold_uncovered_pawns()
	var warmth_press: float = get_warmth_pressure(center_region)
	var food_press: float = get_food_pressure()
	var housing_press: float = get_housing_pressure()
	var storage_press: float = get_storage_pressure(center_region)
	var cooking_press: float = get_cooking_pressure(center_region)
	var hearths_needed: int = 0
	if hearths <= 0 and local_pop > 0:
		hearths_needed = 1
	elif cold_uncovered > 0:
		hearths_needed = hearths + int(ceil(float(cold_uncovered) / 4.0))
	var warmth_satisfied: bool = hearths > 0 and cold_uncovered <= 0 and warmth_press < 0.12
	var survival_met: bool = food_press <= 0.60 and housing_press <= 0.70 and warmth_press <= 0.40
	var need_beds: int = 0
	if housing_press > 0.35:
		need_beds = maxi(2, int(ceil(float(local_pop) * maxf(housing_press, 0.5))))
	var storage_needed: int = 0
	if storage_press > 0.25:
		storage_needed = maxi(1, int(ceil(float(local_pop) * storage_press * 0.4)))
	elif storage_huts <= 0 and local_pop >= 2:
		storage_needed = 1
	var farm_cap: int = estimate_farm_cap(local_pop, food_press, farms) if local_pop > 0 else 0
	var scored: Array = []
	_add_build_priority_score(scored, "warmth", 1.0 - (0.15 if warmth_satisfied else maxf(warmth_press, 0.35)))
	_add_build_priority_score(scored, "cook", cooking_press if hearths > 0 else cooking_press * 0.5)
	_add_build_priority_score(scored, "storage", storage_press)
	_add_build_priority_score(scored, "housing", housing_press)
	_add_build_priority_score(scored, "farm", food_press if farms < farm_cap else food_press * 0.35)
	var ambition_score: float = 0.0
	if survival_met and not materials_crisis:
		ambition_score = clampf(float(local_pop) / 12.0, 0.15, 1.0)
	_add_build_priority_score(scored, "ambition", ambition_score)
	scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("score", 0.0)) > float(b.get("score", 0.0))
	)
	var ranked: Array[String] = []
	for entry in scored:
		ranked.append(str(entry.get("need", "")))
	var job_cap: int = 4 if materials_crisis else 7
	if warmth_press > 0.5 or housing_press > 0.8:
		job_cap = mini(job_cap, 5)
	return {
		"ranked_needs": ranked,
		"warmth_satisfied": warmth_satisfied,
		"survival_met": survival_met,
		"hearths_needed": hearths_needed,
		"need_beds": need_beds,
		"storage_needed": storage_needed,
		"farm_cap": farm_cap,
		"job_cap": job_cap,
		"warmth_press": warmth_press,
		"food_press": food_press,
		"housing_press": housing_press,
		"storage_press": storage_press,
		"cooking_press": cooking_press,
		"light_press": get_light_pressure(center_region),
		"contentment": colony_contentment_period(),
	}


func _add_build_priority_score(bucket: Array, need: String, score: float) -> void:
	if score <= 0.01:
		return
	bucket.append({"need": need, "score": score})


func _center_tile_for_region(center_region: int) -> Vector2i:
	if center_region < 0:
		return _colony_centroid_tile()
	var crx: int = center_region & 0xFFFF
	var cry: int = (center_region >> 16) & 0xFFFF
	return Vector2i(crx * 16 + 8, cry * 16 + 8)


## Active jobs of [param job_type] within Chebyshev [param radius] of [param center_tile].
func count_pending_jobs_near(center_tile: Vector2i, job_type: int, radius: int) -> int:
	if JobManager == null or center_tile.x < 0:
		return 0
	if JobManager.has_method("count_pending_jobs_near"):
		return int(JobManager.call("count_pending_jobs_near", center_tile, job_type, radius))
	var n: int = 0
	for j in JobManager.get_active_jobs_union():
		if j == null:
			continue
		if job_type >= 0 and int(j.type) != job_type:
			continue
		if maxi(absi(j.tile.x - center_tile.x), absi(j.tile.y - center_tile.y)) <= radius:
			n += 1
	return n


## Total fire-pit jobs still queued in a formal settlement region (shared cap across clusters).
func count_pending_fire_pits_in_region(center_region: int, radius: int = 16) -> int:
	var center_tile: Vector2i = _center_tile_for_region(center_region)
	if center_tile.x < 0:
		return 0
	return count_pending_jobs_near(center_tile, Job.Type.BUILD_FIRE_PIT, radius)


## How many hearths the region still needs (cold coverage, not pop/4 per hamlet).
func regional_hearths_needed(center_region: int) -> int:
	var pop: int = _population_in_scope(center_region)
	if pop <= 0:
		return 0
	var built: int = _hearth_count_for_scope(center_region)
	var cold: int = count_cold_uncovered_pawns(center_region)
	if built <= 0:
		return 1
	if cold <= 0:
		return built
	return built + int(ceil(float(cold) / 4.0))


## Gate fire-pit posts so N settlements in one region do not each flood duplicate pits.
func can_seed_fire_pit(
		center_region: int,
		center_tile: Vector2i,
		local_hearths: int,
		local_hearths_needed: int,
) -> bool:
	if local_hearths_needed <= 0 or center_tile.x < 0:
		return false
	if local_hearths > 0 and BuildingUsageTracker != null \
			and BuildingUsageTracker.has_method("should_dampen_additional_hearth_post") \
			and bool(BuildingUsageTracker.call("should_dampen_additional_hearth_post", center_region)):
		return false
	var warmth_press: float = get_warmth_pressure(center_region)
	var cold: int = count_cold_uncovered_pawns(center_region)
	if local_hearths > 0 and cold <= 0 and warmth_press < 0.12:
		return false
	var regional_needed: int = regional_hearths_needed(center_region)
	var regional_built: int = _hearth_count_for_scope(center_region)
	var pending_regional: int = count_pending_fire_pits_in_region(center_region)
	if regional_built + pending_regional >= regional_needed:
		return false
	var pending_local: int = count_pending_jobs_near(center_tile, Job.Type.BUILD_FIRE_PIT, 10)
	if pending_local > 0:
		return false
	return local_hearths + pending_local < local_hearths_needed
