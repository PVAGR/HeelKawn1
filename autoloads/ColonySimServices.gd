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

## Emitted so HUD and future UIs can reflect demand without polling every item.
signal demand_snapshot(
		food: float, housing: float, materials: float, hauling: float)

var current_labor_stance: int = LaborStance.BALANCED

var _food_press: float = 0.0
var _housing_press: float = 0.0
var _mat_press: float = 0.0
var _haul_press: float = 0.0
var _cached_colony_world: World = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameManager.game_tick.connect(_on_tick)
	# Autoloads run before Main exists; one frame later we can see World/pawns.
	call_deferred("_bootstrap_demands_after_scene")


func _bootstrap_demands_after_scene() -> void:
	_refresh_food_mat_haul_pressures()
	_refresh_housing_pressure()
	demand_snapshot.emit(_food_press, _housing_press, _mat_press, _haul_press)


func _on_tick(tick: int) -> void:
	if tick % DEMAND_REFRESH_INTERVAL_TICKS == 0:
		_refresh_all_demands_immediate()
		demand_snapshot.emit(_food_press, _housing_press, _mat_press, _haul_press)


## Food pressure: 0 = plenty, 1 = acute shortage (simplified: inverse of food cap).
func _refresh_all_demands_immediate() -> void:
	_refresh_food_mat_haul_pressures()
	_refresh_housing_pressure()


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
	for p in PawnSpawner.find_alive_pawns():
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
	var pawns: int = PawnSpawner.find_alive_pawns().size()
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
		for pawn in PawnSpawner.find_pawns():
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
