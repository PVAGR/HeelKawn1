extends Node

## Global priority-ordered job queue. Any system can post jobs; any idle pawn
## can claim the best-fitting one. Kept deliberately simple (O(N) scans) while
## the total job count is small (<= ~1000). Swap to a heap once we need to.

# Autoload references
@onready var WorldAI = get_node_or_null("/root/WorldAI")
@onready var TickManager = get_node_or_null("/root/TickManager")
var _cached_colony_world: World = null

signal job_posted(job: Job)
signal job_claimed(job: Job, pawn: HeelKawnian)
signal job_completed(job: Job)
signal job_cancelled(job: Job)


func _ready() -> void:
	if TickManager != null:
		TickManager.mark_tickable_cache_dirty()
	if GameManager != null and not GameManager.game_tick.is_connected(_on_game_tick_prune):
		GameManager.game_tick.connect(_on_game_tick_prune)
	if GameManager != null:
		GameManager.game_tick.connect(_on_game_tick_diag)





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
var _open_counts_by_type_gen_built: int = -1
var _open_counts_by_type_cached: Dictionary = {}
var _pending_counts_by_type_gen_built: int = -1
var _pending_counts_by_type_cached: Dictionary = {}
var _pending_near_cache_gen_built: int = -1
var _pending_near_cache: Dictionary = {}
var _pending_settlement_cache_gen_built: int = -1
var _pending_settlement_cache: Dictionary = {}
var _job_context_by_id: Dictionary = {}

## PHASE A: Authoritative open-job index
## O(1) membership/removal keyed by stable job ID
var _open_index_by_id: Dictionary = {}  # job_id -> index in _open array
## Type buckets: job_type -> Array[job_id]
var _open_by_type: Dictionary = {}  # job_type -> Array[int] (job IDs)
## Settlement buckets: settlement_id -> Array[job_id]
var _open_by_settlement: Dictionary = {}  # settlement_id -> Array[int] (job IDs)
## Region buckets: region_key -> Array[job_id]
var _open_by_region: Dictionary = {}  # region_key -> Array[int] (job IDs)
## Center-region buckets: center_region -> Array[job_id]
var _open_by_center_region: Dictionary = {}  # center_region -> Array[int] (job IDs)
## PHASE B: Index generation for invariant checking
var _index_generation: int = 0
## Navigation generation for component cache invalidation
var _nav_generation: int = 0
## Component cache: component_id -> Array[job_id] (jobs in this path component)
var _open_by_component: Dictionary = {}  # component_id -> Array[int] (job IDs)

## PHASE B: Claim telemetry tracking
var _claim_attempts: int = 0
var _claim_successes: int = 0
var _claim_latency_total_us: int = 0
var _claim_latency_samples: int = 0
var _oldest_waiting_job_id: int = -1
var _oldest_waiting_job_tick: int = 0
var _consecutive_no_claim_streaks: Dictionary = {}  # pawn_id -> streak count
var _rejection_reasons: Dictionary = {}  # reason_string -> count

## Lifetime counters (stats only).
var posted_count: int = 0
var completed_count: int = 0
var cancelled_count: int = 0
var abandoned_count: int = 0

## Cancellation reason tracking (diagnostic). reason_string -> count.
var _cancel_reasons: Dictionary = {}
## Abandon reason tracking (diagnostic). reason_string -> count.
var _abandon_reasons: Dictionary = {}

## Window counters for periodic diagnostics.
var _diag_created_this_window: int = 0
var _diag_completed_this_window: int = 0
var _diag_cancelled_this_window: int = 0
var _diag_abandoned_this_window: int = 0

## Global tile failure cache: tile_key(int) -> {tick: int, reason: String}.
## Prevents re-posting jobs on tiles that have failed recently (resource depleted,
## path blocked). Cleared on world reset. Cooldown of FAIL_TILE_COOLDOWN_TICKS.
const FAIL_TILE_COOLDOWN_TICKS: int = 600
var _failed_tiles: Dictionary = {}

const MAX_OPEN_JOBS_DEFAULT: int = 256
const MAX_OPEN_JOBS_LIGHTWEIGHT: int = 96
## Global cap on open CHOP jobs (harvest spam control).
const MAX_OPEN_CHOP_JOBS: int = 50
const STALE_PRUNE_INTERVAL_TICKS: int = 200
const STALE_PRUNE_PHASE_OFFSET: int = 17
## Last N slots reserved for construction/build/cook/plant jobs.
## Basic forage/mine/chop jobs cannot fill these slots, ensuring
## build jobs always have room in the queue.
const CONSTRUCTION_RESERVED_SLOTS: int = 40


func _bump_jobs_data_generation() -> void:
	_jobs_data_generation += 1
	_active_jobs_union_gen_built = -1
	_open_counts_by_type_gen_built = -1
	_pending_counts_by_type_gen_built = -1
	_pending_near_cache_gen_built = -1
	_pending_settlement_cache_gen_built = -1
	_pending_near_cache.clear()
	_pending_settlement_cache.clear()


## PHASE A: Index mutation helpers

## Add job to all index buckets
func _index_add_job(job: Job, open_idx: int) -> void:
	if job == null or job.id <= 0:
		return
	_open_index_by_id[job.id] = open_idx
	
	# Type bucket
	if not _open_by_type.has(job.type):
		_open_by_type[job.type] = []
	_open_by_type[job.type].append(job.id)
	
	# Context buckets
	var ctx: Dictionary = _job_context_for(job)
	var region_key: int = int(ctx.get("region_key", -1))
	var center_region: int = int(ctx.get("center_region", -1))
	var settlement_id: int = int(ctx.get("settlement_id", -1))
	
	if region_key >= 0:
		if not _open_by_region.has(region_key):
			_open_by_region[region_key] = []
		_open_by_region[region_key].append(job.id)
	
	if center_region >= 0:
		if not _open_by_center_region.has(center_region):
			_open_by_center_region[center_region] = []
		_open_by_center_region[center_region].append(job.id)
	
	if settlement_id >= 0:
		if not _open_by_settlement.has(settlement_id):
			_open_by_settlement[settlement_id] = []
		_open_by_settlement[settlement_id].append(job.id)
	
	# Component bucket (lazy, requires world access)
	# Deferred to _index_add_to_component when needed
	
	_index_generation += 1


## Remove job from all index buckets
func _index_remove_job(job: Job) -> void:
	if job == null or job.id <= 0:
		return
	
	_open_index_by_id.erase(job.id)
	
	# Type bucket
	if _open_by_type.has(job.type):
		var type_arr: Array = _open_by_type[job.type]
		type_arr.erase(job.id)
		if type_arr.is_empty():
			_open_by_type.erase(job.type)
	
	# Context buckets
	var ctx: Dictionary = _job_context_for(job)
	var region_key: int = int(ctx.get("region_key", -1))
	var center_region: int = int(ctx.get("center_region", -1))
	var settlement_id: int = int(ctx.get("settlement_id", -1))
	
	if region_key >= 0 and _open_by_region.has(region_key):
		var region_arr: Array = _open_by_region[region_key]
		region_arr.erase(job.id)
		if region_arr.is_empty():
			_open_by_region.erase(region_key)
	
	if center_region >= 0 and _open_by_center_region.has(center_region):
		var center_arr: Array = _open_by_center_region[center_region]
		center_arr.erase(job.id)
		if center_arr.is_empty():
			_open_by_center_region.erase(center_region)
	
	if settlement_id >= 0 and _open_by_settlement.has(settlement_id):
		var settlement_arr: Array = _open_by_settlement[settlement_id]
		settlement_arr.erase(job.id)
		if settlement_arr.is_empty():
			_open_by_settlement.erase(settlement_id)
	
	# Component bucket
	for comp_id in _open_by_component.keys():
		var comp_arr: Array = _open_by_component[comp_id]
		comp_arr.erase(job.id)
		if comp_arr.is_empty():
			_open_by_component.erase(comp_id)
	
	_index_generation += 1


## Update index after swap-removal (repair moved item's index)
func _index_repair_after_swap(open_idx: int) -> void:
	if open_idx < 0 or open_idx >= _open.size():
		return
	var moved_job: Job = _open[open_idx]
	if moved_job != null and moved_job.id > 0:
		_open_index_by_id[moved_job.id] = open_idx


## Add job to component bucket (requires world access)
func _index_add_to_component(job: Job) -> void:
	if job == null or job.id <= 0:
		return
	var world: World = _get_colony_world()
	if world == null or world.pathfinder == null:
		return
	var component_id: int = world.pathfinder.get_component_id(job.work_tile)
	if component_id >= 0:
		if not _open_by_component.has(component_id):
			_open_by_component[component_id] = []
		_open_by_component[component_id].append(job.id)


## Invalidate component cache on navigation generation change
func _invalidate_component_cache() -> void:
	_nav_generation += 1
	_open_by_component.clear()


## Clear all index structures
func _index_clear() -> void:
	_open_index_by_id.clear()
	_open_by_type.clear()
	_open_by_settlement.clear()
	_open_by_region.clear()
	_open_by_center_region.clear()
	_open_by_component.clear()
	_index_generation += 1
	_invalidate_component_cache()


## PHASE A: Load-only static index checker
## Verifies index invariants without modifying simulation state
## Returns {valid: bool, errors: Array[String]}
func _verify_index_integrity() -> Dictionary:
	var errors: Array[String] = []
	var valid: bool = true
	
	# Check 1: Every open job has exactly one valid master index entry
	for i in range(_open.size()):
		var job: Job = _open[i]
		if job == null:
			errors.append("Open job at index %d is null" % i)
			valid = false
			continue
		if job.id <= 0:
			errors.append("Open job at index %d has invalid id %d" % [i, job.id])
			valid = false
			continue
		if not _open_index_by_id.has(job.id):
			errors.append("Open job id %d missing from _open_index_by_id" % job.id)
			valid = false
		else:
			var idx: int = int(_open_index_by_id[job.id])
			if idx != i:
				errors.append("Open job id %d index mismatch: expected %d, got %d" % [job.id, i, idx])
				valid = false
	
	# Check 2: No duplicate job IDs in open array
	var seen_ids: Dictionary = {}
	for job in _open:
		if job != null and job.id > 0:
			if seen_ids.has(job.id):
				errors.append("Duplicate job id %d in open array" % job.id)
				valid = false
			seen_ids[job.id] = true
	
	# Check 3: Bucket entries refer to open jobs
	for job_type in _open_by_type.keys():
		var job_ids: Array = _open_by_type[job_type]
		for job_id in job_ids:
			if not _open_index_by_id.has(job_id):
				errors.append("Type bucket contains non-open job id %d" % job_id)
				valid = false
	
	for settlement_id in _open_by_settlement.keys():
		var job_ids: Array = _open_by_settlement[settlement_id]
		for job_id in job_ids:
			if not _open_index_by_id.has(job_id):
				errors.append("Settlement bucket contains non-open job id %d" % job_id)
				valid = false
	
	for region_key in _open_by_region.keys():
		var job_ids: Array = _open_by_region[region_key]
		for job_id in job_ids:
			if not _open_index_by_id.has(job_id):
				errors.append("Region bucket contains non-open job id %d" % job_id)
				valid = false
	
	for center_region in _open_by_center_region.keys():
		var job_ids: Array = _open_by_center_region[center_region]
		for job_id in job_ids:
			if not _open_index_by_id.has(job_id):
				errors.append("Center-region bucket contains non-open job id %d" % job_id)
				valid = false
	
	# Check 4: Every open job appears in required applicable buckets
	for job in _open:
		if job == null:
			continue
		var ctx: Dictionary = _job_context_for(job)
		var region_key: int = int(ctx.get("region_key", -1))
		var center_region: int = int(ctx.get("center_region", -1))
		var settlement_id: int = int(ctx.get("settlement_id", -1))
		
		# Type bucket
		if not _open_by_type.has(job.type):
			errors.append("Job id %d missing from type bucket for type %d" % [job.id, job.type])
			valid = false
		elif not _open_by_type[job.type].has(job.id):
			errors.append("Job id %d not in type bucket array for type %d" % [job.id, job.type])
			valid = false
		
		# Region bucket (if applicable)
		if region_key >= 0:
			if not _open_by_region.has(region_key):
				errors.append("Job id %d missing from region bucket for region %d" % [job.id, region_key])
				valid = false
			elif not _open_by_region[region_key].has(job.id):
				errors.append("Job id %d not in region bucket array for region %d" % [job.id, region_key])
				valid = false
		
		# Center-region bucket (if applicable)
		if center_region >= 0:
			if not _open_by_center_region.has(center_region):
				errors.append("Job id %d missing from center-region bucket for center %d" % [job.id, center_region])
				valid = false
			elif not _open_by_center_region[center_region].has(job.id):
				errors.append("Job id %d not in center-region bucket array for center %d" % [job.id, center_region])
				valid = false
		
		# Settlement bucket (if applicable)
		if settlement_id >= 0:
			if not _open_by_settlement.has(settlement_id):
				errors.append("Job id %d missing from settlement bucket for settlement %d" % [job.id, settlement_id])
				valid = false
			elif not _open_by_settlement[settlement_id].has(job.id):
				errors.append("Job id %d not in settlement bucket array for settlement %d" % [job.id, settlement_id])
				valid = false
	
	# Check 5: No completed/cancelled/claimed job remains in open bucket
	for job in _claimed:
		if job != null and _open_index_by_id.has(job.id):
 # This is actually OK - claimed jobs can be in open index if they were just claimed
			# But they shouldn't be in _open array
			pass
	
	# Check 6: Stored positions match master open structure
	for job_id in _open_index_by_id.keys():
		var idx: int = int(_open_index_by_id[job_id])
		if idx < 0 or idx >= _open.size():
			errors.append("Index entry for job id %d has out-of-bounds position %d" % [job_id, idx])
			valid = false
		elif _open[idx] == null or _open[idx].id != job_id:
			errors.append("Index entry for job id %d points to wrong job at position %d" % [job_id, idx])
			valid = false
	
	# Check 7: Stable IDs are unique
	var all_ids: Array = []
	for job in _open:
		if job != null:
			all_ids.append(job.id)
	for job in _claimed:
		if job != null:
			all_ids.append(job.id)
	var unique_ids: Dictionary = {}
	for job_id in all_ids:
		if unique_ids.has(job_id):
			errors.append("Duplicate stable job id %d across open+claimed" % job_id)
			valid = false
		unique_ids[job_id] = true
	
	return {"valid": valid, "errors": errors}


## PHASE B: Indexed candidate snapshot for pawn decision
## Returns a deterministic narrowed candidate set intersected by type, authority,
## settlement/region, and path-component. Reused across all claim strategies.
## Returns {candidates: Array[Job], snapshot_id: int, rejection_reasons: Dictionary}
func get_indexed_candidate_snapshot(
	pawn: Node,
	pd: Variant,
	allowed_types: Array = [],
	allowed_categories: Array = [],
	require_same_settlement: bool = false,
	require_same_region: bool = false,
	require_same_center: bool = false,
	max_candidates: int = 1000
) -> Dictionary:
	if _open.is_empty() or pawn == null or pd == null:
		return {"candidates": [], "snapshot_id": -1, "rejection_reasons": {"no_candidates": true}}
	
	var pawn_ctx: Dictionary = _build_pawn_visibility_context(pawn, pd)
	var pawn_tile: Vector2i = pawn_ctx.get("tile", Vector2i(-1, -1))
	var pawn_region_key: int = int(pawn_ctx.get("region_key", -1))
	var pawn_center: int = int(pawn_ctx.get("center_region", -1))
	var pawn_settlement_id: int = int(pawn_ctx.get("settlement_id", -1))
	
	# Start with type bucket intersection
	var candidate_ids: Array[int] = []
	if not allowed_types.is_empty():
		for job_type in allowed_types:
			if _open_by_type.has(job_type):
				candidate_ids.append_array(_open_by_type[job_type])
	else:
		# No type filter, use all open jobs
		for job in _open:
			if job != null:
				candidate_ids.append(job.id)
	
	if candidate_ids.is_empty():
		return {"candidates": [], "snapshot_id": -1, "rejection_reasons": {"no_type_matches": true}}
	
	# Intersect with settlement/region/center filters
	var filtered_ids: Array[int] = []
	for job_id in candidate_ids:
		var idx: int = _open_index_by_id.get(job_id, -1)
		if idx < 0 or idx >= _open.size():
			continue
		var job: Job = _open[idx]
		if job == null:
			continue
		
		var ctx: Dictionary = _job_context_for(job)
		var job_region: int = int(ctx.get("region_key", -1))
		var job_center: int = int(ctx.get("center_region", -1))
		var job_settlement: int = int(ctx.get("settlement_id", -1))
		
		if require_same_settlement and pawn_settlement_id >= 0 and job_settlement != pawn_settlement_id:
			continue
		if require_same_region and pawn_region_key >= 0 and job_region != pawn_region_key:
			continue
		if require_same_center and pawn_center >= 0 and job_center != pawn_center:
			continue
		
		filtered_ids.append(job_id)
	
	if filtered_ids.is_empty():
		return {"candidates": [], "snapshot_id": -1, "rejection_reasons": {"no_spatial_matches": true}}
	
	# Convert IDs to Job objects, sorted by stable ID for deterministic ordering
	var candidates: Array[Job] = []
	var job_lookup: Dictionary = {}
	for job in _open:
		if job != null:
			job_lookup[job.id] = job
	
	filtered_ids.sort()  # Sort by job ID for deterministic order
	for job_id in filtered_ids:
		if job_lookup.has(job_id):
			candidates.append(job_lookup[job_id])
			if candidates.size() >= max_candidates:
				break
	
	# Apply visibility filter (authority rules)
	var visible_candidates: Array[Job] = []
	for job in candidates:
		if _job_visible_to_pawn_with_context(job, pawn, pd, pawn_ctx):
			visible_candidates.append(job)
	
	if visible_candidates.is_empty():
		return {"candidates": [], "snapshot_id": -1, "rejection_reasons": {"no_visible_candidates": true}}
	
	var snapshot_id: int = _index_generation
	return {"candidates": visible_candidates, "snapshot_id": snapshot_id, "rejection_reasons": {}}


## PHASE B: Claim from indexed candidate snapshot
## Selects best job from pre-filtered snapshot using filter and priority callbacks
## Returns {job: Job, rejection_reason: String}
func claim_from_snapshot(
	pawn: Node,
	pd: Variant,
	snapshot: Dictionary,
	filter: Callable = Callable(),
	priority_bonus: Callable = Callable()
) -> Dictionary:
	var candidates: Array = snapshot.get("candidates", [])
	if candidates.is_empty():
		return {"job": null, "rejection_reason": "empty_snapshot"}
	
	_claim_attempts += 1
	var t0: int = Time.get_ticks_usec()
	
	var pawn_ctx: Dictionary = _build_pawn_visibility_context(pawn, pd)
	var pawn_tile: Vector2i = pawn_ctx.get("tile", Vector2i(-1, -1))
	var obedience_weight: float = 1.0
	if WorldAI != null and WorldAI.has_method("get_pawn_obedience_weight"):
		obedience_weight = WorldAI.get_pawn_obedience_weight(int(pd.id))
	
	var best_idx: int = -1
	var best_eff: int = -0x7FFFFFFF
	var best_dist: int = 0x7FFFFFFF
	var use_filter: bool = filter.is_valid()
	var use_bonus: bool = priority_bonus.is_valid()
	var _type_bonus_cache: Dictionary = {}
	
	for i in range(candidates.size()):
		var j: Job = candidates[i]
		if j == null:
			continue
		
		# Check if job is still open (may have been claimed by another pawn)
		if not _open_index_by_id.has(j.id):
			continue
		
		# Enforce filter if provided
		if use_filter and not filter.call(j):
			continue
		
		# Re-check visibility (snapshot may have stale visibility)
		if not _job_visible_to_pawn_with_context(j, pawn, pd, pawn_ctx):
			continue
		
		var jt: int = j.type
		var bonus: int = 0
		if use_bonus:
			bonus = int(priority_bonus.call(j))
		if not _type_bonus_cache.has(jt):
			var _tb: int = 0
			var job_cat: String = pd.call("job_category_for_type", jt) if pd.has_method("job_category_for_type") else ""
			if not job_cat.is_empty():
				if pd.likes is Dictionary and pd.likes.has(job_cat):
					_tb += 5
				if pd.dislikes is Dictionary and pd.dislikes.has(job_cat):
					_tb -= 5
			if pd.has_method("has_required_tool_for_job") and not pd.has_required_tool_for_job(jt):
				_tb -= 10
			_type_bonus_cache[jt] = _tb
		bonus += int(_type_bonus_cache[jt])
		
		var adjusted_priority: int = j.priority
		if obedience_weight < 0.5:
			adjusted_priority = int(j.priority / maxf(obedience_weight, 0.01))
		
		var eff: int = adjusted_priority + bonus
		var d: int = _chebyshev(pawn_tile, j.work_tile)
		
		# Deterministic tie-breaking: use job ID when scores are equal
		if eff > best_eff or (eff == best_eff and (d < best_dist or (d == best_dist and j.id < candidates[best_idx].id if best_idx >= 0 else true))):
			best_idx = i
			best_eff = eff
			best_dist = d
	
	if best_idx < 0:
		# Track rejection
		var pawn_id: int = int(pd.id) if pd != null and pd.has_method("get") else -1
		if pawn_id >= 0:
			_consecutive_no_claim_streaks[pawn_id] = int(_consecutive_no_claim_streaks.get(pawn_id, 0)) + 1
		_rejection_reasons["no_eligible_candidates"] = int(_rejection_reasons.get("no_eligible_candidates", 0)) + 1
		return {"job": null, "rejection_reason": "no_eligible_candidates"}
	
	var job: Job = candidates[best_idx]
	
	# Claim the job using O(1) index lookup
	var open_idx: int = _open_index_by_id.get(job.id, -1)
	if open_idx >= 0 and open_idx < _open.size() and _open[open_idx] == job:
		_open.remove_at(open_idx)
		_index_repair_after_swap(open_idx)
		_index_remove_job(job)
		_claimed.append(job)
		job.state = Job.State.CLAIMED
		job.assigned_pawn = pawn
		_bump_jobs_data_generation()
		job_claimed.emit(job, pawn)
		
		_claim_successes += 1
		var elapsed_us: int = Time.get_ticks_usec() - t0
		_claim_latency_total_us += elapsed_us
		_claim_latency_samples += 1
		
		# Track oldest waiting job
		var job_tick: int = int(job.posted_tick)
		if job_tick > 0 and (job_tick < _oldest_waiting_job_tick or _oldest_waiting_job_tick == 0):
			_oldest_waiting_job_tick = job_tick
			_oldest_waiting_job_id = job.id
		
		# Reset streak for this pawn
		var pawn_id: int = int(pd.id) if pd != null and pd.has_method("get") else -1
		if pawn_id >= 0:
			_consecutive_no_claim_streaks[pawn_id] = 0
		
		return {"job": job, "rejection_reason": ""}
	else:
		# Job was claimed by another pawn
		_rejection_reasons["race_condition"] = int(_rejection_reasons.get("race_condition", 0)) + 1
		return {"job": null, "rejection_reason": "race_condition"}


func _cache_job_context(job: Job) -> void:
	if job == null or job.id <= 0:
		return
	var tile: Vector2i = job.work_tile if job.work_tile != Vector2i.ZERO else job.tile
	var region_key: int = WorldMemory._region_key(int(tile.x), int(tile.y)) if WorldMemory != null else -1
	var settlement_center: int = SettlementMemory.get_center_region_for_region(region_key) if SettlementMemory != null else -1
	var world_settlement_id: int = SettlementMemory.get_settlement_id_for_region(region_key) if SettlementMemory != null else -1
	_job_context_by_id[job.id] = {
		"region_key": region_key,
		"center_region": settlement_center,
		"settlement_id": world_settlement_id,
	}
	if job.region_key < 0:
		job.region_key = region_key


func _job_context_for(job: Job) -> Dictionary:
	if job == null or job.id <= 0:
		return {}
	if _job_context_by_id.has(job.id):
		var cached: Variant = _job_context_by_id[job.id]
		if cached is Dictionary:
			return cached as Dictionary
	_cache_job_context(job)
	var fresh: Variant = _job_context_by_id.get(job.id, {})
	return fresh if fresh is Dictionary else {}


func _build_pawn_visibility_context(pawn: Node, pd: Variant) -> Dictionary:
	var ctx: Dictionary = {
		"tile": Vector2i(-1, -1),
		"region_key": -1,
		"center_region": -1,
		"settlement_id": -1,
		"household_id": -1,
	}
	if pawn == null or pd == null:
		return ctx
	var pawn_tile: Vector2i = Vector2i(-1, -1)
	if typeof(pd) == TYPE_DICTIONARY:
		pawn_tile = (pd as Dictionary).get("tile_pos", Vector2i(-1, -1))
		ctx["household_id"] = int((pd as Dictionary).get("household_id", -1))
	else:
		pawn_tile = pd.tile_pos
		ctx["household_id"] = int(pd.household_id)
	ctx["tile"] = pawn_tile
	if pawn_tile.x < 0 or pawn_tile.y < 0:
		return ctx
	var pawn_rk: int = WorldMemory._region_key(int(pawn_tile.x), int(pawn_tile.y)) if WorldMemory != null else -1
	ctx["region_key"] = pawn_rk
	ctx["center_region"] = SettlementMemory.get_center_region_for_region(pawn_rk) if SettlementMemory != null else -1
	ctx["settlement_id"] = SettlementMemory.get_settlement_id_for_region(pawn_rk) if SettlementMemory != null else -1
	return ctx


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
	# Skip posting on tiles that have recently failed for resource jobs.
	if is_tile_on_fail_cooldown(tile):
		return null
	var chop_cap: int = MAX_OPEN_CHOP_JOBS
	if ColonySimServices != null:
		chop_cap = ColonySimServices.get_open_chop_job_cap()
		# During severe food crisis, prevent non-essential chop jobs from being posted.
		# Pawns should focus on foraging/hunting instead of wood gathering.
		if ColonySimServices.get_food_pressure() >= 0.85:
			chop_cap = mini(chop_cap, 3)
	if type == Job.Type.CHOP and count_open_by_type(Job.Type.CHOP) >= chop_cap:
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
	job.posted_tick = GameManager.tick_count if GameManager != null else 0
	var open_idx: int = _open.size()
	_open.append(job)
	_jobs_by_tile[tile] = job
	_cache_job_context(job)
	_index_add_job(job, open_idx)  # PHASE A: add to index
	posted_count += 1
	_diag_created_this_window += 1
	_bump_jobs_data_generation()
	job_posted.emit(job)
	return job


## Post + stamp reason/visibility in one call (settlement schedulers, player tools).
func post_stamped(
		type: int,
		tile: Vector2i,
		priority: int,
		work_ticks: int,
		reason: String,
		visible_to: String = "nearby",
		issuer_pawn_id: int = -1,
) -> Job:
	var job: Job = post(type, tile, priority, work_ticks)
	if job != null and not reason.is_empty():
		stamp_seeder_metadata(job, reason, visible_to, issuer_pawn_id)
	return job


## Optional metadata for settlement schedulers / seeders (AI_README issuer fields).
func stamp_seeder_metadata(
		job: Job,
		reason: String,
		visible_to: String = "settlement",
		issuer_pawn_id: int = -1,
) -> void:
	if job == null:
		return
	if not reason.is_empty():
		job.reason = reason
	job.visible_to = visible_to
	if issuer_pawn_id >= 0:
		job.issuer_pawn_id = issuer_pawn_id
		job.issuer_role = "leader"
	else:
		job.issuer_role = "settlement_scheduler"
	job.authority_scope = "formal_settlement"


## Returns true if the job type is a construction/build/cook/plant type
## that is allowed to use the reserved construction slots.
static func _is_construction_type(type: int) -> bool:
	match type:
		Job.Type.BUILD_BED, Job.Type.BUILD_WALL, Job.Type.BUILD_DOOR, \
		Job.Type.BUILD_FIRE_PIT, Job.Type.BUILD_STORAGE_HUT, Job.Type.BUILD_MARKER_STONE, \
		Job.Type.BUILD_HEARTH, Job.Type.BUILD_SHRINE, \
		Job.Type.COOK_MEAT, Job.Type.COOK_BERRIES, Job.Type.COOK_FISH, \
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
		Job.Type.BUILD_SHELTER, Job.Type.MAINTAIN_STRUCTURE:
			return true
		_:
			return false
	return false


## Returns true for primitive survival/build jobs that bypass tech requirements.
static func _is_primitive_job(type: int) -> bool:
	match type:
		Job.Type.FORAGE:
			return true
		Job.Type.CHOP:
			return true
		Job.Type.MINE:
			return true
		Job.Type.HUNT:
			return true
		Job.Type.FISH:
			return true
		Job.Type.BUILD_FIRE_PIT:
			return true
		Job.Type.BUILD_BED:
			return true
		Job.Type.GATHER_STICK:
			return true
		Job.Type.GATHER_FLINT:
			return true
		_:
			return false
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
	var job: Job = post(resolved_type, tile, priority, work_ticks)
	if job == null:
		return null
	# Carry authority/social metadata if present in the dict
	job.issuer_pawn_id = int(job_data.get("issuer_pawn_id", job.issuer_pawn_id))
	job.issuer_role = str(job_data.get("issuer_role", job.issuer_role))
	job.authority_scope = str(job_data.get("authority_scope", job.authority_scope))
	job.settlement_id = int(job_data.get("settlement_id", job.settlement_id))
	job.proto_camp_id = int(job_data.get("proto_camp_id", job.proto_camp_id))
	job.region_key = int(job_data.get("region_key", job.region_key))
	var eligible: Variant = job_data.get("eligible_member_ids", null)
	if eligible is Array:
		job.eligible_member_ids = eligible
	job.reason = str(job_data.get("reason", job.reason))
	job.plan_id = int(job_data.get("plan_id", job.plan_id))
	job.visible_to = str(job_data.get("visible_to", job.visible_to))
	job.social_weight = float(job_data.get("social_weight", job.social_weight))
	return job


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
		"maintain_structure", "maintain", "repair":
			return Job.Type.MAINTAIN_STRUCTURE
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
	_cache_job_context(job)
	posted_count += 1
	_diag_created_this_window += 1
	_bump_jobs_data_generation()
	job_posted.emit(job)
	# Carry optional authority metadata from trade args (compat)
	job.issuer_pawn_id = int(int(_get_with_default(job.trade_from, "issuer_pawn_id", job.issuer_pawn_id))) if job.trade_from != null else job.issuer_pawn_id
	return job
	return job


## Safe accessor that accepts either Dictionary or Object and returns a default
static func _get_with_default(obj: Variant, key: String, default: Variant) -> Variant:
	if obj == null:
		return default
	if typeof(obj) == TYPE_DICTIONARY:
		return obj.get(key, default)
	# If object supports metadata, prefer that
	if obj.has_method("get_meta") and obj.has_meta(key):
		return obj.get_meta(key)
	# Fallback to single-arg get() on Object (no default supported)
	var val = obj.get(key)
	return val if val != null else default


# PERF PASS 2: Within a single pawn decision (one game tick) the pawn state and
# WorldAI obedience weight are stable, yet a single idle decision calls
# claim_next_for several times (matrix + food + goal + unfiltered fallback).
# Rebuilding the visibility context (3 SettlementMemory lookups) and the
# obedience weight (2 FactionManager lookups) on every call is pure waste.
# Memoize per (pawn, tick) so the expensive context is computed once.
var _claim_ctx_pawn: Object = null
var _claim_ctx_tick: int = -1
var _claim_ctx_data: Dictionary = {}
var _claim_ctx_obedience: float = 1.0
# PERF PASS 3: per-job visibility under social rules depends only on (pawn, job,
# tick) — yet the claim loop recomputes `_job_visible_to_pawn_with_context` for
# every open job on every scan, and an idle decision scans ~4x. Memoize the
# result per (pawn, tick) and reuse it across the scans of one decision.
var _claim_vis_cache: Dictionary = {}
# PERF: memoized list of open jobs that pass the social/visibility guard for the
# current (pawn, tick) claim context. One idle decision calls `claim_next_for`
# ~4x (matrix / food / goal / fallback); visibility is pawn+job invariant within
# that decision, so we iterate only the (typically small) visible subset on each
# scan instead of re-walking all N open jobs. Per-scan `filter`/`priority_bonus`
# still gate each candidate inside the loop, so the winner is unchanged.
var _claim_visible_list: Array = []
var _claim_vis_list_ready: bool = false

## Return the best open job for this pawn, or null. "Best" = highest priority
## (plus optional `priority_bonus` offset), then Chebyshev distance. `filter`
## rejects ineligible jobs; `priority_bonus` can bias toward colony labor stance.
## Also applies WorldAI pawn obedience weight to influence job selection.
func claim_next_for(
	pawn: Node, filter: Callable = Callable(), priority_bonus: Callable = Callable()
) -> Job:
	var _claim_t0: int = Time.get_ticks_usec()
	var pd = pawn.call("get_pawn_data") if pawn != null and pawn.has_method("get_pawn_data") else null
	if _open.is_empty() or pawn == null or pd == null:
		return null
	var cur_tick: int = GameManager.tick_count if GameManager != null else -1
	var pawn_ctx: Dictionary
	var obedience_weight: float = 1.0
	if _claim_ctx_pawn == pawn and _claim_ctx_tick == cur_tick:
		pawn_ctx = _claim_ctx_data
		obedience_weight = _claim_ctx_obedience
	else:
		pawn_ctx = _build_pawn_visibility_context(pawn, pd)
		if WorldAI != null and WorldAI.has_method("get_pawn_obedience_weight"):
			obedience_weight = WorldAI.get_pawn_obedience_weight(int(pd.id))
		_claim_ctx_pawn = pawn
		_claim_ctx_tick = cur_tick
		_claim_ctx_data = pawn_ctx
		_claim_ctx_obedience = obedience_weight
		# Precompute visibility for all open jobs once (cheap dict fill); the scan
		# loop below reuses it via a lookup instead of recomputing per job.
		_claim_vis_cache = {}
		_claim_visible_list = []
		for _vj in _open:
			var _vj_vis: bool = _job_visible_to_pawn_with_context(_vj, pawn, pd, pawn_ctx)
			_claim_vis_cache[_vj] = _vj_vis
			if _vj_vis:
				_claim_visible_list.append(_vj)
		_claim_vis_list_ready = true
	var pawn_tile: Vector2i = pawn_ctx.get("tile", Vector2i(-1, -1))
	
	# PROMPT 3: Profession-based early-out — when there are many open jobs (>50)
	# and no explicit filter, first try a filtered scan for this pawn's profession.
	var scan_jobs: Array = _open
	if _open.size() > 50 and not filter.is_valid():
		var profession: int = 0
		if pd != null and pd.has_method("get"):
			profession = int(pd.get("current_profession", 0))
		if profession > 0:
			var filtered: Array[Job] = get_open_jobs_for_profession(profession)
			if not filtered.is_empty():
				scan_jobs = filtered
	
	var best_idx: int = -1
	var best_eff: int = -0x7FFFFFFF
	var best_dist: int = 0x7FFFFFFF
	var use_filter: bool = filter.is_valid()
	var use_bonus: bool = priority_bonus.is_valid()
	# Cache per-type interest/tool bonuses: they depend only on (pawn, job type),
	# not the job instance, so pay 2 method calls per type instead of per job.
	var _type_bonus_cache: Dictionary = {}
	# PERF: walk only the (small) visible-candidate subset computed once for this
	# (pawn, tick) context instead of re-walking all N open jobs per scan, when a
	# full vis list is available and we're not on a profession-narrowed pass where
	# the narrowed set is not a subset of the visible list.
	var walk_jobs: Array = scan_jobs
	if _claim_vis_list_ready and scan_jobs.size() == _open.size():
		walk_jobs = _claim_visible_list
	for i in range(walk_jobs.size()):
		var j: Job = walk_jobs[i]
		# Enforce filter if provided
		if use_filter and not filter.call(j):
			continue
		# Authority / visibility guard: skip jobs not visible to this pawn under social rules
		var _vis = _claim_vis_cache.get(j, null)
		if _vis == null:
			_vis = _job_visible_to_pawn_with_context(j, pawn, pd, pawn_ctx)
			_claim_vis_cache[j] = _vis
		if not _vis:
			continue
		var jt: int = j.type
		var bonus: int = 0
		if use_bonus:
			bonus = int(priority_bonus.call(j))
		if not _type_bonus_cache.has(jt):
			var _tb: int = 0
			var job_cat: String = pd.call("job_category_for_type", jt) if pd.has_method("job_category_for_type") else ""
			if not job_cat.is_empty():
				if pd.likes is Dictionary and pd.likes.has(job_cat):
					_tb += 5
				if pd.dislikes is Dictionary and pd.dislikes.has(job_cat):
					_tb -= 5
			if pd.has_method("has_required_tool_for_job") and not pd.has_required_tool_for_job(jt):
				_tb -= 10
			_type_bonus_cache[jt] = _tb
		bonus += int(_type_bonus_cache[jt])
		
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
		# DIAGNOSTICS: slow claim warning (even on null return — O(N) scan may be slow)
		var _claim_elapsed: int = Time.get_ticks_usec() - _claim_t0
		if _claim_elapsed > 2_000:
			var pawn_id: int = -1
			if pd != null and pd.has_method("get"):
				pawn_id = int(pd.get("id"))
			print("[JOB_DIAG] claim_next_for pawn=%d elapsed=%dus open_jobs=%d" % [
				pawn_id, _claim_elapsed, _open.size()
			])
		return null
	var job: Job = walk_jobs[best_idx]
	# Find and remove from _open (scan_jobs may be a filtered copy)
	# PHASE A: Use index for O(1) lookup instead of linear find
	var open_idx: int = _open_index_by_id.get(job.id, -1)
	if open_idx >= 0 and open_idx < _open.size() and _open[open_idx] == job:
		_open.remove_at(open_idx)
		_index_repair_after_swap(open_idx)  # PHASE A: repair index if swap occurred
	else:
		# Fallback to linear find if index is stale
		open_idx = _open.find(job)
		if open_idx >= 0:
			_open.remove_at(open_idx)
			_index_repair_after_swap(open_idx)
		else:
			return null  # job was consumed by another pawn between scan and claim
	_index_remove_job(job)  # PHASE A: remove from index after successful claim
	_claimed.append(job)
	job.state = Job.State.CLAIMED
	job.assigned_pawn = pawn
	_bump_jobs_data_generation()
	job_claimed.emit(job, pawn)
	# DIAGNOSTICS: slow claim warning
	var _claim_elapsed: int = Time.get_ticks_usec() - _claim_t0
	if _claim_elapsed > 2_000:
		var pawn_id: int = -1
		if pd != null:
			pawn_id = int(pd.get("id")) if pd.has_method("get") else -1
		print("[JOB_DIAG] claim_next_for pawn=%d elapsed=%dus open_jobs=%d" % [
			pawn_id, _claim_elapsed, _open.size()
		])
	return job


## HeelKawnian gave up on a job (couldn't reach it, or was freed). Puts it back in
## the open queue so another pawn can claim it. Resets work progress.
func abandon(job: Job, reason: String = "") -> void:
	if job == null:
		return
	if not _claimed.has(job):
		return
	_claimed.erase(job)
	job.state = Job.State.OPEN
	job.assigned_pawn = null
	job.work_ticks_done = 0
	var open_idx: int = _open.size()
	_open.append(job)
	_index_add_job(job, open_idx)  # PHASE A: re-add to index after abandon
	abandoned_count += 1  # PHASE A: track abandons separately
	_diag_abandoned_this_window += 1  # PHASE A: separate window counter
	_bump_jobs_data_generation()
	if not reason.is_empty():
		_abandon_reasons[reason] = int(_abandon_reasons.get(reason, 0)) + 1


## Mark a job as completed by a pawn. Removes it from the active queues and
## fires `job_completed` so downstream systems (WorldAI, settlement stats) can
## react. Idempotent: calling complete() on an already-retired job is a no-op.
func complete(job: Job) -> void:
	if job == null or job.state == Job.State.CANCELLED or job.state == Job.State.COMPLETED:
		return
	_index_remove_job(job)  # PHASE A: remove from index before array ops
	_open.erase(job)
	_claimed.erase(job)
	_jobs_by_tile.erase(job.tile)
	_job_context_by_id.erase(job.id)
	_notify_path_reservation_released(job)
	job.state = Job.State.COMPLETED
	job.assigned_pawn = null
	completed_count += 1  # PHASE A: increment completed_count
	_diag_completed_this_window += 1
	_bump_jobs_data_generation()
	_notify_world_ai_job_completion(job)
	job_completed.emit(job)


## Abort a job. Useful if the target becomes invalid, the pawn dies, or the world
## is regenerated. Idempotent: calling cancel() on an already-retired job is a no-op.
func cancel(job: Job, reason: String = "") -> void:
	if job == null or job.state == Job.State.CANCELLED or job.state == Job.State.COMPLETED:
		return
	_index_remove_job(job)  # PHASE A: remove from index before array ops
	_open.erase(job)
	_claimed.erase(job)
	_jobs_by_tile.erase(job.tile)
	_job_context_by_id.erase(job.id)
	_notify_path_reservation_released(job)
	job.state = Job.State.CANCELLED
	job.assigned_pawn = null
	cancelled_count += 1
	_diag_cancelled_this_window += 1
	if not reason.is_empty():
		_cancel_reasons[reason] = int(_cancel_reasons.get(reason, 0)) + 1
	_bump_jobs_data_generation()
	job_cancelled.emit(job)

## Determine if a job is visible/eligible to a pawn under authority rules.
func _job_visible_to_pawn(j: Job, pawn: Node, pd: Variant) -> bool:
	return _job_visible_to_pawn_with_context(j, pawn, pd, _build_pawn_visibility_context(pawn, pd))


func _job_visible_to_pawn_with_context(j: Job, pawn: Node, pd: Variant, pawn_ctx: Dictionary) -> bool:
	if j == null or pawn == null or pd == null:
		return false
	var pawn_tile: Vector2i = pawn_ctx.get("tile", Vector2i(-1, -1))
	var pawn_center: int = int(pawn_ctx.get("center_region", -1))
	var pawn_region_key: int = int(pawn_ctx.get("region_key", -1))
	var pawn_household_id: int = int(pawn_ctx.get("household_id", -1))
	var job_ctx: Dictionary = _job_context_for(j)
	var job_region_key: int = int(job_ctx.get("region_key", -1))
	var job_center: int = int(job_ctx.get("center_region", -1))
	var job_settlement_id: int = int(job_ctx.get("settlement_id", -1))
	if job_region_key < 0:
		job_region_key = WorldMemory._region_key(int(j.work_tile.x), int(j.work_tile.y)) if WorldMemory != null else -1
	if job_center < 0 and job_region_key >= 0 and SettlementMemory != null:
		job_center = SettlementMemory.get_center_region_for_region(job_region_key)
	if job_settlement_id < 0 and job_region_key >= 0 and SettlementMemory != null:
		job_settlement_id = SettlementMemory.get_settlement_id_for_region(job_region_key)
	var d: int = _chebyshev(pawn_tile, j.work_tile)
	if str(j.visible_to).to_lower() == "all":
		return true
	if str(j.visible_to).to_lower() == "self":
		return int(j.issuer_pawn_id) == int(pd.id)
	if str(j.issuer_role).to_lower() == "emergency" and d <= 48:
		return true
	if pawn_region_key >= 0 and pawn_center >= 0 and pawn_center == job_center:
		return true
	# pawn_settlement_id is already cached in pawn_ctx by _build_pawn_visibility_context
	var pawn_settlement_id: int = int(pawn_ctx.get("settlement_id", -1))
	if pawn_settlement_id >= 0 and pawn_settlement_id == job_settlement_id:
		return true
	var vis: String = str(j.visible_to).to_lower()
	if vis == "settlement" and d <= 48:
		return true
	var scope: String = str(j.authority_scope).to_lower()
	if scope == "formal_settlement" or scope == "settlement":
		if pawn_center >= 0 and pawn_center == job_center:
			return true
		if d <= 40:
			return true
		return false
	if scope == "proto_camp" or scope == "band":
		if pawn_center >= 0 and pawn_center == job_center:
			return true
		if d <= 24:
			return true
		return false
	if scope == "household":
		if pawn_household_id >= 0 and (int(j.settlement_id) == pawn_household_id or j.eligible_member_ids.has(pawn_household_id)):
			return true
		return false
	if str(j.visible_to).to_lower() == "nearby" or scope == "nearby":
		return d <= 32
	# PROMPT 4: Pawns with no settlement/region can still see nearby jobs within 24 tiles
	if pawn_center < 0 and pawn_region_key < 0:
		return d <= 24
	if pawn_region_key < 0 or pawn_center < 0:
		return d <= 40
	return false


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
		var settlement_id: int = -1
		if pd.has_method("get_tile_pos"):
			var tile_pos: Vector2i = pd.call("get_tile_pos")
			var rk: int = WorldMemory._region_key(int(tile_pos.x), int(tile_pos.y))
			settlement_id = SettlementMemory.get_center_region_for_region(rk)
		if settlement_id < 0:
			var work_tile: Vector2i = j.work_tile
			var rk2: int = WorldMemory._region_key(int(work_tile.x), int(work_tile.y))
			settlement_id = SettlementMemory.get_center_region_for_region(rk2)
		# PROMPT 4: Primitive jobs bypass tech gate
		if _is_primitive_job(j.type):
			pass
		elif settlement_id >= 0 and TechnologySystem != null:
			if not bool(TechnologySystem.call("can_settle_perform_job_type", settlement_id, int(j.type))):
				return null
		_index_remove_job(j)  # PHASE A: remove from index before claim
		_open.remove_at(i)
		_index_repair_after_swap(i)  # PHASE A: repair index if swap occurred
		_claimed.append(j)
		j.state = Job.State.CLAIMED
		j.assigned_pawn = pawn
		_bump_jobs_data_generation()
		job_claimed.emit(j, pawn)
		return j
	return null
## Cancel every job. Called when the world is regenerated so we don't keep
## jobs pointing at tiles whose features no longer exist.
func clear_all() -> void:
	var all: Array[Job] = []
	all.append_array(_open)
	all.append_array(_claimed)
	_open.clear()
	_claimed.clear()
	_jobs_by_tile.clear()
	_failed_tiles.clear()
	_job_context_by_id.clear()
	_index_clear()  # PHASE A: clear index structures
	_bump_jobs_data_generation()
	for j in all:
		_notify_path_reservation_released(j)
		j.state = Job.State.CANCELLED
		j.assigned_pawn = null
		cancelled_count += 1
		job_cancelled.emit(j)


const STALE_OPEN_JOB_TICKS: int = 200
## Hard timeout: cancel ANY open job older than this, even on valid tiles.
## Prevents unbounded queue growth when jobs are never claimed.
const HARD_STALE_OPEN_JOB_TICKS: int = 3000
const HARD_STALE_CONSTRUCTION_TICKS: int = 6000
## Soft timeout for still-valid jobs: an open job unclaimed this long is pruned
## even if its target tile is fine. Keeps the open board proportional to actual
## throughput (one-job-per-pawn model) instead of clogging with stale work.
const STALE_VALID_OPEN_JOB_TICKS: int = 1800


## Cancel open jobs that sat unclaimed for too long. Valid-tile jobs are pruned
## after STALE_VALID_OPEN_JOB_TICKS (longer for construction); any job that
## exceeds the hard timeout is always cancelled. This bounds queue growth so
## every pawn search stays cheap and no job lingers unclaimed forever.
func prune_stale_open_jobs(world: World, max_unclaimed_ticks: int = STALE_OPEN_JOB_TICKS) -> int:
	if world == null or world.data == null:
		return 0
	var tick: int = GameManager.tick_count if GameManager != null else 0
	var pruned: int = 0
	var doomed: Array[Job] = []
	for j in _open:
		if j == null or j.state != Job.State.OPEN:
			continue
		var posted: int = int(j.posted_tick)
		if posted <= 0:
			continue
		var age: int = tick - posted
		var is_construction: bool = _is_construction_type(j.type)
		# Hard timeout: cancel regardless of tile validity.
		var hard_max: int = HARD_STALE_CONSTRUCTION_TICKS if is_construction else HARD_STALE_OPEN_JOB_TICKS
		if age >= hard_max:
			doomed.append(j)
			continue
		# Soft timeout for still-valid jobs: prune unclaimed work that has sat
		# too long so it stops bloating every pawn's job search. Construction jobs
		# use the same window — the seeder re-posts them when still needed, so a
		# valid build job sitting unclaimed for this long is stale, not pending.
		var valid_max: int = STALE_VALID_OPEN_JOB_TICKS
		if age >= valid_max:
			doomed.append(j)
			continue
		# Brief grace for very young jobs.
		if age < max_unclaimed_ticks:
			continue
		# Between grace and valid_max: keep if the tile is still valid, else prune.
		if is_job_target_still_valid(world, j):
			continue
		doomed.append(j)
	for j in doomed:
		var reason: String = "stale_invalid_tile"
		if is_job_target_still_valid(world, j):
			reason = "stale_valid_timeout"
		elif age_for_job(j, tick) >= (HARD_STALE_CONSTRUCTION_TICKS if _is_construction_type(j.type) else HARD_STALE_OPEN_JOB_TICKS):
			reason = "stale_hard_timeout"
		cancel(j, reason)
		pruned += 1
	return pruned


func age_for_job(j: Job, tick: int) -> int:
	if j == null:
		return 0
	return tick - int(j.posted_tick)


## Shared validity check for open-job pruning (harvest + build targets).
func is_job_target_still_valid(world: World, job: Job) -> bool:
	if world == null or world.data == null or job == null:
		return false
	if not world.data.in_bounds(job.tile.x, job.tile.y):
		return false
	match job.type:
		Job.Type.FORAGE, Job.Type.PLANT_SEEDS:
			return int(world.data.get_feature(job.tile.x, job.tile.y)) == TileFeature.Type.FERTILE_SOIL
		Job.Type.MINE:
			return int(world.data.get_feature(job.tile.x, job.tile.y)) == TileFeature.Type.ORE_VEIN
		Job.Type.MINE_WALL:
			return int(world.data.get_biome(job.tile.x, job.tile.y)) == Biome.Type.MOUNTAIN
		Job.Type.CHOP:
			return int(world.data.get_feature(job.tile.x, job.tile.y)) == TileFeature.Type.TREE
		Job.Type.HUNT:
			return TileFeature.is_wildlife(int(world.data.get_feature(job.tile.x, job.tile.y)))
		Job.Type.FISH:
			var feat_f: int = int(world.data.get_feature(job.tile.x, job.tile.y))
			return feat_f == TileFeature.Type.RIVER \
					or int(world.data.get_biome(job.tile.x, job.tile.y)) == Biome.Type.WATER
		Job.Type.COOK_MEAT, Job.Type.COOK_BERRIES, Job.Type.COOK_FISH, Job.Type.DRY_MEAT:
			return int(world.data.get_feature(job.tile.x, job.tile.y)) == TileFeature.Type.FIRE_PIT
		Job.Type.TRADE_HAUL:
			var tf: Stockpile = job.trade_from
			var tt: Stockpile = job.trade_to
			if tf == null or not is_instance_valid(tf) or tt == null or not is_instance_valid(tt):
				return false
			if world.pathfinder != null and not world.pathfinder.is_passable(job.work_tile):
				return false
			if not tt.accepts(job.trade_item):
				return false
			return tf.count_of(job.trade_item) > 0
		Job.Type.BUILD_DOOR:
			var f_door: int = int(world.data.get_feature(job.tile.x, job.tile.y))
			if f_door == TileFeature.Type.WALL or f_door == TileFeature.Type.NONE:
				return Biome.is_passable(world.data.get_biome(job.tile.x, job.tile.y))
			return false
		_:
			if not Biome.is_passable(world.data.get_biome(job.tile.x, job.tile.y)):
				return false
			var f: int = int(world.data.get_feature(job.tile.x, job.tile.y))
			if f == TileFeature.Type.NONE:
				return true
			if f == TileFeature.Type.TREE or f == TileFeature.Type.FERTILE_SOIL \
					or f == TileFeature.Type.ORE_VEIN or f == TileFeature.Type.RUIN:
				return true
			if ColonySimServices != null and ColonySimServices.is_hearth_build_job(job.type):
				return f != TileFeature.Type.FIRE_PIT
			return false


func open_count() -> int:
	return _open.size()

## PERF PASS 3: global open-job count for a specific type. Used by the
## construction seeder to enforce a hard ceiling on build-job backlog so the
## open board cannot grow without bound (no infinite/duplicate-spam jobs).
func open_count_by_type(type: int) -> int:
	var n: int = 0
	for j in _open:
		if int(j.type) == type:
			n += 1
	return n

## PERF PASS 2: lightweight snapshot of open jobs so a caller can precompute
## per-job scoring once and reuse it across multiple claim_next_for calls
## (a single idle decision calls claim_next_for several times).
func get_open_jobs_snapshot() -> Array:
	return _open


func claimed_count() -> int:
	return _claimed.size()


func get_claimed_jobs() -> Array:
	return _claimed


## Return visible open jobs for a given pawn (applies same visibility rules
## used when claiming). Useful for diagnostics and Pawn-side failure reporting.
func visible_jobs_for_pawn(pawn: Node, pawn_data: Variant) -> Array:
	var res: Array = []
	var pawn_ctx: Dictionary = _build_pawn_visibility_context(pawn, pawn_data)
	for j in _open:
		if _job_visible_to_pawn_with_context(j, pawn, pawn_data, pawn_ctx):
			res.append(j)
	return res


## Diagnostic: cancellation reason counts for F10 debug report.
func get_cancel_stats() -> Dictionary:
	return _cancel_reasons.duplicate()

## Diagnostic: abandon reason counts for F10 debug report.
func get_abandon_stats() -> Dictionary:
	return _abandon_reasons.duplicate()


## Count open (unclaimed) jobs of a specific type. Used by planners to avoid
## over-posting when the queue is already full.
func count_open_by_type(job_type: int) -> int:
	return int(_get_open_counts_by_type().get(job_type, 0))


## Top N open job types by count (for HUD). Returns [{type, count, label}, ...].
func get_top_open_job_types(max_types: int = 3) -> Array[Dictionary]:
	if max_types <= 0:
		return []
	var counts: Dictionary = _get_open_counts_by_type()
	if counts.is_empty():
		return []
	var pairs: Array = []
	for t in counts.keys():
		pairs.append({"type": int(t), "count": int(counts[t])})
	pairs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("count", 0)) > int(b.get("count", 0))
	)
	var out: Array[Dictionary] = []
	for i in range(mini(max_types, pairs.size())):
		var p: Dictionary = pairs[i] as Dictionary
		var jt: int = int(p.get("type", 0))
		out.append({
			"type": jt,
			"count": int(p.get("count", 0)),
			"label": Job.describe_type(jt),
		})
	return out


## Count both open and claimed jobs of a specific type. Gives a fuller picture
## of how much work is queued for a given build type.
func count_pending_by_type(job_type: int) -> int:
	return int(_get_pending_counts_by_type().get(job_type, 0))


## Snapshot pending (open + claimed) counts by job type.
## Useful for planners that need many type lookups in one pass.
func get_pending_counts() -> Dictionary:
	return _get_pending_counts_by_type().duplicate()


## Get open jobs matching a pawn's profession.
## Returns array of jobs that match the profession's primary job types.
func get_open_jobs_for_profession(profession: int) -> Array[Job]:
	var matching_types: Array[int] = _profession_to_job_types(profession)
	if matching_types.is_empty():
		return []
	var out: Array[Job] = []
	for job in _open:
		if matching_types.has(job.type):
			out.append(job)
	return out


## Map profession enum to relevant job types.
func _profession_to_job_types(profession: int) -> Array[int]:
	match profession:
		HeelKawnianData.Profession.FARMER:
			return [Job.Type.FORAGE, Job.Type.PLANT_SEEDS, Job.Type.HARVEST_CROPS, Job.Type.GROW_FOOD, Job.Type.BUILD_FARM_FIELD, Job.Type.WORK_FARM_FIELD]
		HeelKawnianData.Profession.BUILDER:
			return [Job.Type.BUILD_BED, Job.Type.BUILD_WALL, Job.Type.BUILD_DOOR, Job.Type.BUILD_SHELTER, Job.Type.BUILD_HEARTH, Job.Type.BUILD_FIRE_PIT, Job.Type.BUILD_STORAGE_HUT, Job.Type.BUILD_STOCKPILE, Job.Type.BUILD_WORKSHOP, Job.Type.BUILD_LOOM, Job.Type.BUILD_KILN, Job.Type.BUILD_SMELTER]
		HeelKawnianData.Profession.GATHERER:
			return [Job.Type.FORAGE, Job.Type.GATHER_FLINT, Job.Type.GATHER_STICK, Job.Type.MINE]
		HeelKawnianData.Profession.WARRIOR:
			return [Job.Type.HUNT, Job.Type.PROTECT, Job.Type.DEFEND, Job.Type.GUARD]
		HeelKawnianData.Profession.SCHOLAR:
			return [Job.Type.TEACH_SKILL, Job.Type.APPRENTICESHIP, Job.Type.CARVE_KNOWLEDGE_STONE, Job.Type.CARVE_LEDGER_STONE, Job.Type.PAPER_MAKING, Job.Type.LEATHER_MAKING, Job.Type.INK_MAKING, Job.Type.BOOK_BINDING, Job.Type.BUILD_LIBRARY, Job.Type.BUILD_SCHOOL]
		HeelKawnianData.Profession.TRADER:
			return [Job.Type.TRADE_HAUL, Job.Type.HAUL_TO_MARKET, Job.Type.WORK_MARKET, Job.Type.BUILD_MARKET, Job.Type.BUILD_TRADING_POST, Job.Type.BUILD_MARKET_STALL]
		HeelKawnianData.Profession.SMITH:
			return [Job.Type.CRAFT_KNIFE, Job.Type.CRAFT_PICK, Job.Type.CRAFT_SPEAR, Job.Type.TOOL_MAKING, Job.Type.BUILD_WORKSHOP, Job.Type.WORK_WOODSHOP, Job.Type.BUILD_SMELTER]
		HeelKawnianData.Profession.HEALER:
			return [Job.Type.BUILD_APOTHECARY, Job.Type.DRY_MEAT]
		HeelKawnianData.Profession.CARPENTER:
			return [Job.Type.CHOP, Job.Type.BUILD_BED, Job.Type.BUILD_DOOR, Job.Type.BUILD_WOODSHOP, Job.Type.WORK_WOODSHOP, Job.Type.BUILD_COUNTER, Job.Type.BUILD_CHAIR, Job.Type.BUILD_BOAT_WORKSHOP]
		HeelKawnianData.Profession.COOK:
			return [Job.Type.COOK_MEAT, Job.Type.COOK_BERRIES, Job.Type.COOK_FISH, Job.Type.DRY_MEAT, Job.Type.BUILD_COOK_HUT, Job.Type.WORK_COOK_HUT, Job.Type.BUILD_BREWERY, Job.Type.BREW_MEAD, Job.Type.BREW_ALE]
		HeelKawnianData.Profession.MERCHANT:
			return [Job.Type.TRADE_HAUL, Job.Type.HAUL_TO_MARKET, Job.Type.WORK_MARKET, Job.Type.BUILD_MARKET, Job.Type.BUILD_TRADING_POST]
		HeelKawnianData.Profession.BOATWRIGHT:
			return [Job.Type.BUILD_BOATYARD, Job.Type.BUILD_DOCK, Job.Type.BUILD_FISHERMAN_HUT, Job.Type.BUILD_BOAT_WORKSHOP, Job.Type.FISH]
		_:
			return [Job.Type.FORAGE, Job.Type.CHOP, Job.Type.MINE, Job.Type.HUNT]


## Record a tile as failed for a job reason. Other systems (pawn abandons,
## resource depletion, path failures) call this so JobManager avoids
## re-posting on known-bad tiles for FAIL_TILE_COOLDOWN_TICKS.
func record_failed_tile(tile: Vector2i, reason: String) -> void:
	if tile.x < 0 or tile.y < 0:
		return
	var key: int = tile.y * 65536 + tile.x
	_failed_tiles[key] = {
		"tick": GameManager.tick_count if GameManager != null else 0,
		"reason": reason,
	}


## True if a tile was recently recorded as failed and is still on cooldown.
func is_tile_on_fail_cooldown(tile: Vector2i) -> bool:
	if tile.x < 0 or tile.y < 0:
		return false
	var key: int = tile.y * 65536 + tile.x
	if not _failed_tiles.has(key):
		return false
	var rec: Dictionary = _failed_tiles[key] as Dictionary
	var fail_tick: int = int(rec.get("tick", 0))
	var now: int = GameManager.tick_count if GameManager != null else 0
	if now - fail_tick >= FAIL_TILE_COOLDOWN_TICKS:
		_failed_tiles.erase(key)
		return false
	return true


## True if there is already a job (open or claimed) at this tile. Used by
## reactive job seeders to avoid duplicate posts.
func has_job_at(tile: Vector2i) -> bool:
	return _jobs_by_tile.has(tile)


## True when a build job of [param job_type] is already open or claimed near [param center_tile].
func has_pending_build_near(center_tile: Vector2i, job_type: int, radius: int = 14) -> bool:
	return count_pending_jobs_near(center_tile, job_type, radius) > 0


## Post helper: skips construction jobs when the same type is already queued near a settlement center.
func post_build_deduped(
		type: int,
		tile: Vector2i,
		priority: int = 0,
		work_ticks: int = 20,
		settlement_center: Vector2i = Vector2i(-99999, -99999),
) -> Job:
	if _is_construction_type(type) and settlement_center.x > -99990:
		if has_pending_build_near(settlement_center, type, 14):
			return null
	return post(type, tile, priority, work_ticks)


## Count open+claimed jobs near [param center_tile] (Chebyshev [param radius]).
func count_pending_jobs_near(center_tile: Vector2i, job_type: int, radius: int) -> int:
	if center_tile.x < 0:
		return 0
	if _pending_near_cache_gen_built != _jobs_data_generation:
		_pending_near_cache.clear()
		_pending_near_cache_gen_built = _jobs_data_generation
	var near_key: String = "%d:%d:%d:%d" % [center_tile.x, center_tile.y, job_type, radius]
	if _pending_near_cache.has(near_key):
		return int(_pending_near_cache[near_key])
	var n: int = 0
	for j in get_active_jobs_union():
		if j == null:
			continue
		if job_type >= 0 and int(j.type) != job_type:
			continue
		if maxi(absi(j.tile.x - center_tile.x), absi(j.tile.y - center_tile.y)) <= radius:
			n += 1
	_pending_near_cache[near_key] = n
	return n


## Single-pass variant: counts open+claimed jobs near [param center_tile] for every
## type in [param types] at once, returning a {type: count} dict. Replaces N separate
## [method count_pending_jobs_near] scans (one per type) with one union pass, which is
## the dominant cost in the construction seeder at high speed.
func count_pending_by_types_near(center_tile: Vector2i, types: Array, radius: int) -> Dictionary:
	var out: Dictionary = {}
	if center_tile.x < 0:
		return out
	for t in types:
		out[t] = 0
	for j in get_active_jobs_union():
		if j == null:
			continue
		var jt: int = int(j.type)
		if not out.has(jt):
			continue
		if maxi(absi(j.tile.x - center_tile.x), absi(j.tile.y - center_tile.y)) <= radius:
			out[jt] = int(out[jt]) + 1
	return out


## Count of currently-active (open + claimed) jobs of a given type.
func active_count_of_type(type: int) -> int:
	return int(_get_pending_counts_by_type().get(type, 0))


## Pending (open + claimed) jobs for one formal settlement and build type.
func count_pending_for_settlement(settlement_id: int, job_type: int) -> int:
	if settlement_id < 0:
		return 0
	if _pending_settlement_cache_gen_built != _jobs_data_generation:
		_pending_settlement_cache.clear()
		_pending_settlement_cache_gen_built = _jobs_data_generation
	var settlement_key: String = "%d:%d" % [settlement_id, job_type]
	if _pending_settlement_cache.has(settlement_key):
		return int(_pending_settlement_cache[settlement_key])
	var n: int = 0
	for j in get_active_jobs_union():
		if j == null:
			continue
		if job_type >= 0 and int(j.type) != job_type:
			continue
		if int(j.settlement_id) == settlement_id:
			n += 1
	_pending_settlement_cache[settlement_key] = n
	return n


func has_pending_for_settlement(settlement_id: int, job_type: int) -> bool:
	return count_pending_for_settlement(settlement_id, job_type) > 0


func _get_open_counts_by_type() -> Dictionary:
	if _open_counts_by_type_gen_built == _jobs_data_generation:
		return _open_counts_by_type_cached
	_open_counts_by_type_cached.clear()
	for j in _open:
		_open_counts_by_type_cached[j.type] = int(_open_counts_by_type_cached.get(j.type, 0)) + 1
	_open_counts_by_type_gen_built = _jobs_data_generation
	return _open_counts_by_type_cached


func _get_pending_counts_by_type() -> Dictionary:
	if _pending_counts_by_type_gen_built == _jobs_data_generation:
		return _pending_counts_by_type_cached
	_pending_counts_by_type_cached.clear()
	for j in _open:
		_pending_counts_by_type_cached[j.type] = int(_pending_counts_by_type_cached.get(j.type, 0)) + 1
	for j in _claimed:
		_pending_counts_by_type_cached[j.type] = int(_pending_counts_by_type_cached.get(j.type, 0)) + 1
	_pending_counts_by_type_gen_built = _jobs_data_generation
	return _pending_counts_by_type_cached


func stats() -> Dictionary:
	return {
		"open":	   _open.size(),
		"claimed":	_claimed.size(),
		"posted":	 posted_count,
		"completed":  completed_count,
		"cancelled":  cancelled_count,
		"abandoned":  abandoned_count,  # PHASE A: add abandoned count
		"cancel_reasons": _cancel_reasons.duplicate(),
		"abandon_reasons": _abandon_reasons.duplicate(),
		"index_generation": _index_generation,  # PHASE A: index diagnostic
		"nav_generation": _nav_generation,  # PHASE A: navigation generation
		# PHASE B: Claim telemetry
		"claim_attempts": _claim_attempts,
		"claim_successes": _claim_successes,
		"claim_latency_avg_us": (_claim_latency_total_us / _claim_latency_samples) if _claim_latency_samples > 0 else 0,
		"oldest_waiting_job_id": _oldest_waiting_job_id,
		"oldest_waiting_job_tick": _oldest_waiting_job_tick,
		"rejection_reasons": _rejection_reasons.duplicate(),
	}


## PHASE B: Get top N work-starved pawns (bounded read-only accessor)
## Returns Array of {pawn_id: int, streak: int}
func get_top_work_starved_pawns(max_pawns: int = 10) -> Array:
	if _consecutive_no_claim_streaks.is_empty():
		return []
	
	var pawn_streaks: Array = []
	for pawn_id in _consecutive_no_claim_streaks.keys():
		var streak: int = int(_consecutive_no_claim_streaks[pawn_id])
		if streak >= 5:  # Only count significant streaks
			pawn_streaks.append({"pawn_id": int(pawn_id), "streak": streak})
	
	# Sort by streak descending
	pawn_streaks.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("streak", 0)) > int(b.get("streak", 0))
	)
	
	# Return top N
	var result: Array = []
	for i in range(mini(max_pawns, pawn_streaks.size())):
		result.append(pawn_streaks[i])
	return result


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


func _on_game_tick_prune(tick: int) -> void:
	if GameManager == null or not GameManager.periodic_phase_due(
			tick, STALE_PRUNE_INTERVAL_TICKS, STALE_PRUNE_PHASE_OFFSET):
		return
	var world: World = _get_colony_world()
	if world != null:
		prune_stale_open_jobs(world, STALE_OPEN_JOB_TICKS)


## Periodic job diagnostics — prints every JOB_DIAG_INTERVAL_TICKS.
var _job_diag_last_tick: int = -1
const JOB_DIAG_INTERVAL_TICKS: int = 600  # every ~10s at 60fps

func _on_game_tick_diag(tick: int) -> void:
	if not OS.is_debug_build():
		return
	if tick - _job_diag_last_tick < JOB_DIAG_INTERVAL_TICKS:
		return
	_job_diag_last_tick = tick
	var open_count: int = _open.size()
	var claimed_count: int = _claimed.size()
	var total: int = open_count + claimed_count
	# Count by type
	var type_counts: Dictionary = {}
	for job in _open:
		var tn: String = Job.Type.keys()[job.type] if job.type >= 0 and job.type < Job.Type.size() else str(job.type)
		type_counts[tn] = int(type_counts.get(tn, 0)) + 1
	for job in _claimed:
		var tn: String = Job.Type.keys()[job.type] if job.type >= 0 and job.type < Job.Type.size() else str(job.type)
		type_counts[tn] = int(type_counts.get(tn, 0)) + 1
	# Stale detection
	var stale_count: int = 0
	var current_tick: int = GameManager.tick_count if GameManager != null else 0
	for job in _open:
		if current_tick - job.posted_tick > 2000:
			stale_count += 1
	print("[JOB_DIAG] total=%d open=%d claimed=%d stale(>2000t)=%d created=%d completed=%d cancelled=%d" % [
		total, open_count, claimed_count, stale_count,
		_diag_created_this_window, _diag_completed_this_window, _diag_cancelled_this_window
	])
	# Print top types
	var sorted_types: Array = type_counts.keys()
	sorted_types.sort()
	for tn in sorted_types:
		if int(type_counts[tn]) >= 3:
			print("[JOB_DIAG]   %s: %d" % [tn, int(type_counts[tn])])
	# Reset window counters
	_diag_created_this_window = 0
	_diag_completed_this_window = 0
	_diag_cancelled_this_window = 0
	_diag_abandoned_this_window = 0  # PHASE A: reset abandoned window counter

func _notify_path_reservation_released(j: Job) -> void:
	if j == null or j.type != Job.Type.BUILD_WALL:
		return
	var world: World = _get_colony_world()
	if world != null:
		world.on_construction_path_job_ended(j)


func _get_colony_world() -> World:
	if _cached_colony_world != null and is_instance_valid(_cached_colony_world):
		return _cached_colony_world
	var scene_tree: SceneTree = get_tree()
	if scene_tree == null:
		return null
	for w in scene_tree.get_nodes_in_group("colony_world"):
		if w is World:
			_cached_colony_world = w as World
			return _cached_colony_world
	return null
