extends Node

## Global priority-ordered job queue. Any system can post jobs; any idle pawn
## can claim the best-fitting one. Kept deliberately simple (O(N) scans) while
## the total job count is small (<= ~1000). Swap to a heap once we need to.

# Autoload references
@onready var WorldAI = get_node_or_null("/root/WorldAI")
@onready var TickManager = get_node_or_null("/root/TickManager")

signal job_posted(job: Job)
signal job_claimed(job: Job, pawn: HeelKawnian)
signal job_completed(job: Job)
signal job_cancelled(job: Job)


func _ready() -> void:
	add_to_group("tickable")
	if TickManager != null:
		TickManager.mark_tickable_cache_dirty()





var _next_id: int = 1

## All currently-known, non-retired jobs.
var _open: Array[Job] = []
var _claimed: Array[Job] = []

## tile(Vector2i) -> Job. Prevents posting two jobs on the same tile.
var _jobs_by_tile: Dictionary = {}

## SettlementMemory / planners scan open+claimed often in one tick; rebuild once per mutation.
var _jobs_data_generation: int = 0
var _active_jobs_union_gen_built: int = -1
var _active_jobs_union_cached: Array[Job] = []

## Lifetime counters (stats only).
var posted_count: int = 0
var completed_count: int = 0
var cancelled_count: int = 0

const MAX_OPEN_JOBS_DEFAULT: int = 256
const MAX_OPEN_JOBS_LIGHTWEIGHT: int = 96
## Last N slots reserved for construction/build/cook/plant jobs.
## Basic forage/mine/chop jobs cannot fill these slots, ensuring
## build jobs always have room in the queue.
const CONSTRUCTION_RESERVED_SLOTS: int = 40


func _bump_jobs_data_generation() -> void:
	_jobs_data_generation += 1


## Read-only union of open + claimed jobs, reused until the queue mutates.
func get_active_jobs_union() -> Array[Job]:
	if _active_jobs_union_gen_built != _jobs_data_generation:
		_active_jobs_union_gen_built = _jobs_data_generation
		_active_jobs_union_cached.clear()
		_active_jobs_union_cached.append_array(_open)
		_active_jobs_union_cached.append_array(_claimed)
	return _active_jobs_union_cached


## Create-and-post helper: returns the new Job (or null if the tile already has one).
## work_tile defaults to `tile`; callers that need a different standing tile
## (e.g. MINE on an impassable mountain) should set job.work_tile after posting.
func post(type: int, tile: Vector2i, priority: int = 0, work_ticks: int = 20) -> Job:
	if _jobs_by_tile.has(tile):
		return null
	var max_jobs: int = _max_open_jobs_allowed()
	var is_construction: bool = _is_construction_type(type)
	# Basic forage/mine/chop can't fill the reserved construction slots.
	if not is_construction and _open.size() >= max_jobs - CONSTRUCTION_RESERVED_SLOTS:
		return null
	if _open.size() >= max_jobs:
		return null
	var job := Job.new()
	job.id = _next_id
	_next_id += 1
	job.type = type
	job.tile = tile
	job.work_tile = tile
	job.priority = priority
	job.work_ticks_needed = work_ticks
	job.state = Job.State.OPEN
	_open.append(job)
	_jobs_by_tile[tile] = job
	posted_count += 1
	_bump_jobs_data_generation()
	job_posted.emit(job)
	return job


## Returns true if the job type is a construction/build/cook/plant type
## that is allowed to use the reserved construction slots.
static func _is_construction_type(type: int) -> bool:
	match type:
		Job.Type.BUILD_BED, Job.Type.BUILD_WALL, Job.Type.BUILD_DOOR, \
		Job.Type.BUILD_FIRE_PIT, Job.Type.BUILD_STORAGE_HUT, Job.Type.BUILD_MARKER_STONE, \
		Job.Type.BUILD_HEARTH, Job.Type.BUILD_SHRINE, \
		Job.Type.COOK_MEAT, Job.Type.COOK_BERRIES, \
		Job.Type.PLANT_SEEDS, Job.Type.HARVEST_CROPS, Job.Type.GROW_FOOD, \
		Job.Type.CARVE_GRAVE_MARKER, Job.Type.CARVE_KNOWLEDGE_STONE, Job.Type.CARVE_LEDGER_STONE, \
		Job.Type.PAPER_MAKING, Job.Type.INK_MAKING, Job.Type.BOOK_BINDING, \
		Job.Type.TOOL_MAKING, Job.Type.TEACH_SKILL, Job.Type.PROTECT, \
		Job.Type.BUILD_FARM_WHEAT, Job.Type.BUILD_FARM_CORN, Job.Type.BUILD_FARM_VEGETABLES, Job.Type.BUILD_HERB_GARDEN, \
		Job.Type.BUILD_WORKSHOP, Job.Type.BUILD_LOOM, Job.Type.BUILD_KILN, Job.Type.BUILD_SMELTER, \
		Job.Type.BUILD_BOATYARD, Job.Type.BUILD_DOCK, Job.Type.BUILD_FISHERMAN_HUT, \
		Job.Type.BUILD_APOTHECARY, \
		Job.Type.BUILD_LIBRARY, Job.Type.BUILD_SCHOOL, \
		Job.Type.BUILD_BARRACKS, Job.Type.BUILD_WATCHTOWER, \
		Job.Type.BUILD_MARKET, Job.Type.BUILD_TRADING_POST, \
		Job.Type.BUILD_ROAD, \
		Job.Type.BUILD_GRANARY, Job.Type.BUILD_CELLAR, \
		Job.Type.BUILD_SHELTER:
			return true
		_:
			return false
	return false


## Compatibility adapter for systems that post job dictionaries.
## Accepts either numeric `type` or string aliases (`"harvest_crops"`, `"build"`).
func post_from_dict(job_data: Dictionary) -> Job:
	if job_data.is_empty():
		return null
	var tile_v: Variant = job_data.get("work_tile", job_data.get("tile", null))
	if not (tile_v is Vector2i):
		return null
	var tile: Vector2i = tile_v as Vector2i
	var type_v: Variant = job_data.get("type", Job.Type.FORAGE)
	var resolved_type: int = _resolve_job_type(type_v, job_data)
	if resolved_type < 0:
		return null
	var priority: int = int(job_data.get("priority", 0))
	var work_ticks: int = int(job_data.get("work_ticks", 20))
	return post(resolved_type, tile, priority, work_ticks)


func _resolve_job_type(type_v: Variant, job_data: Dictionary) -> int:
	if type_v is int:
		return int(type_v)
	var type_s: String = str(type_v).strip_edges().to_lower()
	match type_s:
		"forage":
			return Job.Type.FORAGE
		"hunt":
			return Job.Type.HUNT
		"chop":
			return Job.Type.CHOP
		"mine":
			return Job.Type.MINE
		"build_bed", "bed":
			return Job.Type.BUILD_BED
		"build_wall", "wall":
			return Job.Type.BUILD_WALL
		"build_door", "door":
			return Job.Type.BUILD_DOOR
		"build_shelter", "shelter":
			return Job.Type.BUILD_SHELTER
		"build_hearth", "hearth":
			return Job.Type.BUILD_HEARTH
		"storage", "build_storage_hut":
			return Job.Type.BUILD_STORAGE_HUT
		"grow_food", "water_crops", "tend_crops":
			return Job.Type.GROW_FOOD
		"harvest_crops":
			return Job.Type.HARVEST_CROPS
		"defend":
			return Job.Type.DEFEND
		"protect":
			return Job.Type.PROTECT
		"teach_skill":
			return Job.Type.TEACH_SKILL
		"apprenticeship":
			return Job.Type.APPRENTICESHIP
		"trade_haul":
			return Job.Type.TRADE_HAUL
		"build":
			var build_type: String = str(job_data.get("build_type", "")).to_lower()
			return _resolve_build_type_alias(build_type)
	return -1


func _resolve_build_type_alias(build_type: String) -> int:
	match build_type:
		"shelter", "expand_shelter":
			return Job.Type.BUILD_SHELTER
		"storage":
			return Job.Type.BUILD_STORAGE_HUT
		"hearth":
			return Job.Type.BUILD_HEARTH
		"workshop":
			return Job.Type.TOOL_MAKING
		"wall":
			return Job.Type.BUILD_WALL
		"bed":
			return Job.Type.BUILD_BED
		"monument":
			return Job.Type.BUILD_MARKER_STONE
		"great_hall":
			return Job.Type.BUILD_WALL
	return -1


## [TRADE_HAUL]: stand at [work_tile] (in [trade_from] zone), load batch, deliver to [trade_to].
## [tile] and [work_tile] must be the same unique key (see [_jobs_by_tile]).
func post_trade_haul(
		work_tile: Vector2i,
		trade_from: Stockpile,
		trade_to: Stockpile,
		item: int,
		batch: int,
		priority: int = 0,
		work_ticks: int = 3
) -> Job:
	if _jobs_by_tile.has(work_tile):
		return null
	if trade_from == null or trade_to == null or batch <= 0 or item == 0:
		return null
	if _open.size() >= _max_open_jobs_allowed():
		return null
	var job: Job = Job.new()
	job.id = _next_id
	_next_id += 1
	job.type = Job.Type.TRADE_HAUL
	job.tile = work_tile
	job.work_tile = work_tile
	job.trade_from = trade_from
	job.trade_to = trade_to
	job.trade_item = item
	job.trade_batch = batch
	job.priority = priority
	job.work_ticks_needed = work_ticks
	job.state = Job.State.OPEN
	_open.append(job)
	_jobs_by_tile[work_tile] = job
	posted_count += 1
	_bump_jobs_data_generation()
	job_posted.emit(job)
	return job


## Return the best open job for this pawn, or null. "Best" = highest priority
## (plus optional `priority_bonus` offset), then Chebyshev distance. `filter`
## rejects ineligible jobs; `priority_bonus` can bias toward colony labor stance.
## Also applies WorldAI pawn obedience weight to influence job selection.
func claim_next_for(
		pawn: HeelKawnian, filter: Callable = Callable(), priority_bonus: Callable = Callable()
	) -> Job:
	var pd = pawn.call("get_pawn_data") if pawn != null and pawn.has_method("get_pawn_data") else null
	if _open.is_empty() or pawn == null or pd == null:
		return null
	var pawn_tile: Vector2i = pd.tile_pos
	
	# Get pawn obedience weight from WorldAI (affects job compliance)
	var obedience_weight: float = 1.0
	if WorldAI != null and WorldAI.has_method("get_pawn_obedience_weight"):
		obedience_weight = WorldAI.get_pawn_obedience_weight(int(pd.id))
	
	var best_idx: int = -1
	var best_eff: int = -0x7FFFFFFF
	var best_dist: int = 0x7FFFFFFF
	var use_filter: bool = filter.is_valid()
	var use_bonus: bool = priority_bonus.is_valid()
	for i in range(_open.size()):
		var j: Job = _open[i]
		if use_filter and not filter.call(j):
			continue
		var bonus: int = 0
		if use_bonus:
			bonus = int(priority_bonus.call(j))
		
		# Apply obedience weight to priority (lower obedience = higher priority needed to accept)
		var adjusted_priority: int = j.priority
		if obedience_weight < 0.5:
			adjusted_priority = int(j.priority / maxf(obedience_weight, 0.01))
		
		var eff: int = adjusted_priority + bonus
		var d: int = _chebyshev(pawn_tile, j.work_tile)
		if eff > best_eff or (eff == best_eff and d < best_dist):
			best_idx = i
			best_eff = eff
			best_dist = d
	if best_idx < 0:
		return null
	var job: Job = _open[best_idx]
	_open.remove_at(best_idx)
	_claimed.append(job)
	job.state = Job.State.CLAIMED
	job.assigned_pawn = pawn
	_bump_jobs_data_generation()
	job_claimed.emit(job, pawn)
	return job


func claim_by_id_for(pawn: HeelKawnian, job_id: int) -> Job:
	var pd = pawn.call("get_pawn_data") if pawn != null and pawn.has_method("get_pawn_data") else null
	if pawn == null or pd == null or job_id < 0:
		return null
	for i in range(_open.size()):
		var j: Job = _open[i]
		if int(j.id) != job_id:
			continue
		if pd.has_method("allows_job_type") and not pd.allows_job_type(j.type):
			return null
		# === CHECK TECH REQUIREMENT ===
		var settlement_id: int = -1
		if pd.has_method("get_tile_pos"):
			var tile_pos: Vector2i = pd.call("get_tile_pos")
			var rk: int = WorldMemory._region_key(int(tile_pos.x), int(tile_pos.y))
			settlement_id = SettlementMemory.get_center_region_for_region(rk)
		if settlement_id < 0 and j.has_method("get_work_tile"):
			var work_tile: Vector2i = j.call("get_work_tile")
			var rk: int = WorldMemory._region_key(int(work_tile.x), int(work_tile.y))
			settlement_id = SettlementMemory.get_center_region_for_region(rk)
		if settlement_id >= 0 and TechnologySystem != null:
			if not bool(TechnologySystem.call("can_settle_perform_job_type", settlement_id, int(j.type))):
				return null
		# === END TECH CHECK ===
		_open.remove_at(i)
		_claimed.append(j)
		j.state = Job.State.CLAIMED
		j.assigned_pawn = pawn
		_bump_jobs_data_generation()
		job_claimed.emit(j, pawn)
		return j
	return null


## HeelKawnian gave up on a job (couldn't reach it, or was freed). Puts it back in
## the open queue so another pawn can claim. Resets work progress.
func abandon(job: Job) -> void:
	if job == null:
		return
	if not _claimed.has(job):
		return
	_claimed.erase(job)
	job.state = Job.State.OPEN
	job.assigned_pawn = null
	job.work_ticks_done = 0
	_open.append(job)
	_bump_jobs_data_generation()


## Mark a job finished. Removes it from the claimed list and drops its tile lock.
func complete(job: Job) -> void:
	if job == null:
		return
	_claimed.erase(job)
	_jobs_by_tile.erase(job.tile)
	job.state = Job.State.COMPLETED
	completed_count += 1
	_bump_jobs_data_generation()

	# Notify WorldAI of job completion for economic neuron updates
	_notify_world_ai_job_completion(job)

	# Record progression impact
	var impact_amount: int = 0
	if job.type == Job.Type.BUILD_SHELTER or job.type == Job.Type.BUILD_HEARTH:
		impact_amount = 10
	elif job.type == Job.Type.TEACH_SKILL or job.type == Job.Type.APPRENTICESHIP:
		impact_amount = 10
	elif job.type == Job.Type.GROW_FOOD or job.type == Job.Type.HARVEST_CROPS:
		impact_amount = 5
	elif job.type == Job.Type.PROTECT or job.type == Job.Type.DEFEND:
		impact_amount = 15
	if impact_amount > 0 and get_tree() != null and get_tree().root.has_node("ProgressionSystem"):
		var pawn_id: int = 0
		if job.assigned_pawn != null and job.assigned_pawn.has_method("get_pawn_data"):
			var pd: HeelKawnianData = job.assigned_pawn.get_pawn_data()
			if pd != null:
				pawn_id = int(pd.id)
		var progression: Node = get_node("/root/ProgressionSystem")
		if progression.has_method("record_impact"):
			progression.call("record_impact", pawn_id, impact_amount, str(Job.Type.keys()[job.type]))

	job_completed.emit(job)
	# NOTE: `BUILD_WALL` path reservation is cleared in `World.build_wall` when
	# the feature is committed — not here (job may complete without build on edge cases).


## Abort a job. Useful if the target becomes invalid, the pawn dies, or the world
## is regenerated. Idempotent -- calling cancel() on an already-retired job is
## a no-op, so "two owners both call cancel" (clear_all + pawn.release) is safe.
func cancel(job: Job) -> void:
	if job == null or job.state == Job.State.CANCELLED or job.state == Job.State.COMPLETED:
		return
	_open.erase(job)
	_claimed.erase(job)
	_jobs_by_tile.erase(job.tile)
	_notify_path_reservation_released(job)
	job.state = Job.State.CANCELLED
	job.assigned_pawn = null
	cancelled_count += 1
	_bump_jobs_data_generation()
	job_cancelled.emit(job)


## Cancel every job. Called when the world is regenerated so we don't keep
## jobs pointing at tiles whose features no longer exist.
func clear_all() -> void:
	var all: Array[Job] = []
	all.append_array(_open)
	all.append_array(_claimed)
	_open.clear()
	_claimed.clear()
	_jobs_by_tile.clear()
	_bump_jobs_data_generation()
	for j in all:
		_notify_path_reservation_released(j)
		j.state = Job.State.CANCELLED
		j.assigned_pawn = null
		cancelled_count += 1
		job_cancelled.emit(j)


func open_count() -> int:
	return _open.size()


func claimed_count() -> int:
	return _claimed.size()


## Count open (unclaimed) jobs of a specific type. Used by planners to avoid
## over-posting when the queue is already full.
func count_open_by_type(job_type: int) -> int:
	var n: int = 0
	for j in _open:
		if j.type == job_type:
			n += 1
	return n


## Count both open and claimed jobs of a specific type. Gives a fuller picture
## of how much work is queued for a given build type.
func count_pending_by_type(job_type: int) -> int:
	var n: int = 0
	for j in _open:
		if j.type == job_type:
			n += 1
	for j in _claimed:
		if j.type == job_type:
			n += 1
	return n


## True if there is already a job (open or claimed) at this tile. Used by
## reactive job seeders to avoid duplicate posts.
func has_job_at(tile: Vector2i) -> bool:
	return _jobs_by_tile.has(tile)


## Count of currently-active (open + claimed) jobs of a given type.
func active_count_of_type(type: int) -> int:
	var n: int = 0
	for j in _open:
		if j.type == type:
			n += 1
	for j in _claimed:
		if j.type == type:
			n += 1
	return n


func stats() -> Dictionary:
	return {
		"open":	   _open.size(),
		"claimed":	_claimed.size(),
		"posted":	 posted_count,
		"completed":  completed_count,
		"cancelled":  cancelled_count,
	}


func _max_open_jobs_allowed() -> int:
	if GameManager != null and GameManager.has_method("is_lightweight_simulation_mode") and GameManager.is_lightweight_simulation_mode():
		return MAX_OPEN_JOBS_LIGHTWEIGHT
	return MAX_OPEN_JOBS_DEFAULT


## Dump the queue state + first N open jobs. Hotkeyed to J in Main.gd.
func print_debug(max_rows: int = 10) -> void:
	if not OS.is_debug_build():
		return
	var s := stats()
	print("[Jobs] open=%d claimed=%d  (posted=%d completed=%d cancelled=%d)" % [
		s.open, s.claimed, s.posted, s.completed, s.cancelled
	])
	var shown: int = 0
	for j in _open:
		if shown >= max_rows:
			break
		print("[Jobs]   %s" % j.describe())
		shown += 1
	for j in _claimed:
		if shown >= max_rows * 2:
			break
		var who: String = "?"
		if j.assigned_pawn != null and j.assigned_pawn.has_method("get_pawn_name_for_log"):
			who = str(j.assigned_pawn.call("get_pawn_name_for_log"))
		print("[Jobs]   %s  <- %s" % [j.describe(), who])
		shown += 1


static func _chebyshev(a: Vector2i, b: Vector2i) -> int:
	return max(abs(a.x - b.x), abs(a.y - b.y))


func _notify_world_ai_job_completion(job: Job) -> void:
	# Notify WorldAI of job completion for economic neuron updates
	if WorldAI != null and WorldAI.has_method("on_job_completed"):
		WorldAI.on_job_completed(job.type, job.priority)


## `abandon` keeps the open job: construction reservations on tiles stay. Only
## a full `cancel` (no longer any job) releases them.
func _on_world_tick(_tick_number: int) -> void:
	# JobManager is event-driven; no per-tick state changes required.
	pass

func _notify_path_reservation_released(j: Job) -> void:
	if j == null or j.type != Job.Type.BUILD_WALL:
		return
	var scene_tree: SceneTree = get_tree()
	if scene_tree == null:
		return
	for w in scene_tree.get_nodes_in_group("colony_world"):
		if w is World:
			(w as World).on_construction_path_job_ended(j)
			return
