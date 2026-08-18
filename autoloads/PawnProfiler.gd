extends Node

# Profiling buckets for HeelKawnian internal operations
enum Bucket {
	DECISION,
	JOB_QUERY,
	JOB_SCORING,
	JOB_CLAIM,
	JOB_VALIDATION,
	MOVEMENT,
	PATH_REQUEST,
	TARGET_SEARCH,
	RESOURCE_SEARCH,
	BUILDING_SEARCH,
	STOCKPILE_SEARCH,
	CONSTRUCTION,
	GATHERING,
	HAULING,
	SOCIAL,
	RELATIONSHIPS,
	NEEDS,
	MEANING,
	PROFESSION,
	SKILL,
	SETTLEMENT_LOOKUP,
	WORLD_QUERY,
	OTHER,
	MAX_BUCKETS
}

# Per-bucket stats (aggregated across all pawns)
var _bucket_times: Array = []  # microseconds total per bucket
var _bucket_counts: Array = [] # call count per bucket
var _bucket_maxes: Array = []  # max single call per bucket

# Query counters
var _job_candidates_evaluated: int = 0
var _full_job_scans: int = 0
var _group_queries: int = 0
var _world_scans: int = 0
var _path_requests: int = 0
var _sort_operations: int = 0

# Profiling state
var _profiling_enabled: bool = true
var _profile_interval_ticks: int = 600
var _ticks_since_last_report: int = 0

# Tick tracking (connect to TickManager)
var _tick_manager: Node = null

func _ready():
	# Initialize buckets
	for i in range(Bucket.MAX_BUCKETS):
		_bucket_times.append(0.0)
		_bucket_counts.append(0)
		_bucket_maxes.append(0.0)
	
	# Connect to TickManager for tick counting
	_tick_manager = get_node_or_null("/root/TickManager")

func _process(_delta):
	if not _profiling_enabled:
		return
	
	_ticks_since_last_report += 1
	
	if _ticks_since_last_report >= _profile_interval_ticks:
		_report_and_reset()
		_ticks_since_last_report = 0

# Start timing a bucket (call at entry)
func start_bucket(bucket: int) -> float:
	if not _profiling_enabled:
		return 0.0
	return Time.get_ticks_usec()

# End timing a bucket (call at exit with elapsed time)
func end_bucket(bucket: int, start_time: float):
	if not _profiling_enabled:
		return
	
	var elapsed = float(Time.get_ticks_usec() - start_time)
	
	if bucket >= 0 and bucket < Bucket.MAX_BUCKETS:
		_bucket_times[bucket] += elapsed
		_bucket_counts[bucket] += 1
		if elapsed > _bucket_maxes[bucket]:
			_bucket_maxes[bucket] = elapsed

# Increment query counters
func count_job_candidate():
	_job_candidates_evaluated += 1

func count_full_job_scan():
	_full_job_scans += 1

func count_group_query():
	_group_queries += 1

func count_world_scan():
	_world_scans += 1

func count_path_request():
	_path_requests += 1

func count_sort_operation():
	_sort_operations += 1

# Get bucket name for reporting
func _get_bucket_name(bucket: int) -> String:
	var names = [
		"decision", "job_query", "job_scoring", "job_claim", "job_validation",
		"movement", "path_request", "target_search", "resource_search", "building_search",
		"stockpile_search", "construction", "gathering", "hauling", "social",
		"relationships", "needs", "meaning", "profession", "skill",
		"settlement_lookup", "world_query", "other"
	]
	if bucket >= 0 and bucket < names.size():
		return names[bucket]
	return "unknown"

# Report and reset stats
func _report_and_reset():
	var output = "[PAWN-PROFILE]\n"
	
	for i in range(Bucket.MAX_BUCKETS):
		var total = _bucket_times[i]
		var count = _bucket_counts[i]
		var avg = total / count if count > 0 else 0.0
		var max_val = _bucket_maxes[i]
		
		output += "%s total=%.1fus calls=%d avg=%.1fus max=%.1fus\n" % [
			_get_bucket_name(i), total, count, avg, max_val
		]
	
	output += "\n[QUERY-COUNTS]\n"
	output += "job_candidates_evaluated=%d\n" % _job_candidates_evaluated
	output += "full_job_scans=%d\n" % _full_job_scans
	output += "group_queries=%d\n" % _group_queries
	output += "world_scans=%d\n" % _world_scans
	output += "path_requests=%d\n" % _path_requests
	output += "sort_operations=%d\n" % _sort_operations
	
	print(output)
	
	# Reset for next interval
	for i in range(Bucket.MAX_BUCKETS):
		_bucket_times[i] = 0.0
		_bucket_counts[i] = 0
		_bucket_maxes[i] = 0.0
	
	_job_candidates_evaluated = 0
	_full_job_scans = 0
	_group_queries = 0
	_world_scans = 0
	_path_requests = 0
	_sort_operations = 0

# Enable/disable profiling
func set_profiling(enabled: bool):
	_profiling_enabled = enabled

# Get current stats without resetting (for debugging)
func get_bucket_stats(bucket: int) -> Dictionary:
	if bucket < 0 or bucket >= Bucket.MAX_BUCKETS:
		return {}
	return {
		"total": _bucket_times[bucket],
		"calls": _bucket_counts[bucket],
		"avg": _bucket_times[bucket] / _bucket_counts[bucket] if _bucket_counts[bucket] > 0 else 0.0,
		"max": _bucket_maxes[bucket]
	}
