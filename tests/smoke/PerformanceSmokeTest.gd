## Performance Smoke Test — Automated verification that lag and inactivity fixes are holding.
## Attach to a Node in the scene tree and call run_test() to begin.
## Outputs a pass/fail report to the Godot console.
##
## Usage: In the Godot editor, create a Node in the scene, attach this script,
## and run the scene. The test will automatically execute and print results.
##
## Pass Criteria:
## - 1x phase (0-30s): queued_ticks < 2.0 at all samples
## - 200x phase (30-90s): queued_ticks never > 100, drops below 20 in last 30s
## - Return 1x phase (90-120s): queued_ticks < 5.0 within 5s of switch
## - claimed_jobs >= 5 by 60s mark
## - open_jobs never > 200
## - >= 80% of alive pawns have jobs at 60s and 120s marks

class_name PerformanceSmokeTest
extends Node

const SAMPLE_INTERVAL_SEC: float = 1.0
const PHASE_1X_DURATION_SEC: float = 30.0
const PHASE_200X_DURATION_SEC: float = 60.0
const PHASE_RETURN_1X_DURATION_SEC: float = 30.0

enum Phase { IDLE, PHASE_1X, PHASE_200X, PHASE_RETURN_1X, DONE }

var _phase: int = Phase.IDLE
var _phase_start_time: float = 0.0
var _last_sample_time: float = 0.0
var _samples: Array[Dictionary] = []
var _report: Dictionary = {}
var _passed: bool = true
var _fail_reasons: Array[String] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("run_test")

func run_test() -> void:
	print("\n" + "=".repeat(80))
	print("  PERFORMANCE SMOKE TEST STARTING")
	print("=".repeat(80))
	if GameManager != null:
		GameManager.set_speed_index(0)
		if GameManager.is_paused:
			GameManager.resume()
	_phase = Phase.PHASE_1X
	_phase_start_time = Time.get_ticks_msec() / 1000.0
	_last_sample_time = _phase_start_time
	_samples.clear()
	_passed = true
	_fail_reasons.clear()

func _process(_delta: float) -> void:
	if _phase == Phase.IDLE or _phase == Phase.DONE:
		return
	var now: float = Time.get_ticks_msec() / 1000.0
	var elapsed: float = now - _phase_start_time
	
	# Phase transitions
	match _phase:
		Phase.PHASE_1X:
			if elapsed >= PHASE_1X_DURATION_SEC:
				print("[SMOKE] Switching to 200x...")
				if GameManager != null:
					GameManager.set_speed_index(5)
				_phase = Phase.PHASE_200X
				_phase_start_time = now
		Phase.PHASE_200X:
			if elapsed >= PHASE_200X_DURATION_SEC:
				print("[SMOKE] Switching back to 1x...")
				if GameManager != null:
					GameManager.set_speed_index(0)
				_phase = Phase.PHASE_RETURN_1X
				_phase_start_time = now
		Phase.PHASE_RETURN_1X:
			if elapsed >= PHASE_RETURN_1X_DURATION_SEC:
				_phase = Phase.DONE
				_generate_report()
				return
	
	# Sampling
	if now - _last_sample_time >= SAMPLE_INTERVAL_SEC:
		_last_sample_time = now
		_sample()

func _sample() -> void:
	var s: Dictionary = {
		"phase": _phase,
		"time": Time.get_ticks_msec() / 1000.0,
		"tick": GameManager.tick_count if GameManager != null else 0,
	}
	# TickManager backlog
	if TickManager != null:
		s["tm_queued"] = float(TickManager._accumulated_time) / float(TickManager.BASE_TICK_INTERVAL)
	else:
		s["tm_queued"] = 0.0
	# GameManager backlog
	if GameManager != null:
		s["gm_queued"] = float(GameManager._tick_accumulator) / float(GameManager.TICK_INTERVAL_SECONDS)
	else:
		s["gm_queued"] = 0.0
	# Job counts
	if JobManager != null:
		s["open_jobs"] = JobManager.open_count()
		s["claimed_jobs"] = JobManager.claimed_count()
	else:
		s["open_jobs"] = 0
		s["claimed_jobs"] = 0
	# Pawns with jobs
	var pawns_with_jobs: int = 0
	var alive_pawns: int = 0
	var all_pawns: Array = []
	var spawner = get_node_or_null("/root/Main/WorldViewport/PawnSpawner")
	if spawner != null and spawner.has_method("get_alive_pawns"):
		all_pawns = spawner.get_alive_pawns()
	for child in all_pawns:
		if child.has("data") and child.data != null and not child.data.is_dead:
			alive_pawns += 1
			if child.has("_current_job") and child._current_job != null:
				pawns_with_jobs += 1
	s["alive_pawns"] = alive_pawns
	s["pawns_with_jobs"] = pawns_with_jobs
	_samples.append(s)

func _generate_report() -> void:
	print("\n" + "=".repeat(80))
	print("  SMOKE TEST REPORT")
	print("=".repeat(80))
	
	var phase1_samples: Array = _samples.filter(func(x): return x.phase == Phase.PHASE_1X)
	var phase200_samples: Array = _samples.filter(func(x): return x.phase == Phase.PHASE_200X)
	var phase_return_samples: Array = _samples.filter(func(x): return x.phase == Phase.PHASE_RETURN_1X)
	
	# Criterion 1: 1x backlog < 2.0
	for s in phase1_samples:
		if s.tm_queued >= 2.0:
			_fail("[1x] queued_ticks %.2f >= 2.0 at t=%.1f" % [s.tm_queued, s.time])
	
	# Criterion 2: 200x backlog never exceeds 100, drops below 20 in last 30s
	var max_200_queued: float = 0.0
	for s in phase200_samples:
		max_200_queued = maxf(max_200_queued, s.tm_queued)
	if max_200_queued > 100.0:
		_fail("[200x] max queued_ticks %.2f > 100.0" % max_200_queued)
	var end_time_200: float = phase200_samples.back().time if not phase200_samples.is_empty() else 0.0
	var last_30s_200: Array = phase200_samples.filter(func(x): return x.time >= end_time_200 - 30.0)
	var dropped_below_20: bool = false
	for s in last_30s_200:
		if s.tm_queued < 20.0:
			dropped_below_20 = true
			break
	if not dropped_below_20 and not phase200_samples.is_empty():
		_fail("[200x] queued_ticks never dropped below 20 in last 30s")
	
	# Criterion 3: Return to 1x backlog < 5.0 within 5 seconds
	var return_start_time: float = phase_return_samples[0].time if not phase_return_samples.is_empty() else 0.0
	var stabilized: bool = false
	for s in phase_return_samples:
		if s.time - return_start_time <= 5.0 and s.tm_queued < 5.0:
			stabilized = true
			break
	if not stabilized and not phase_return_samples.is_empty():
		_fail("[return_1x] queued_ticks did not drop below 5.0 within 5s of deceleration")
	
	# Criterion 4: claimed_jobs >= 5 by 60s mark
	var s60: Dictionary = {}
	for s in _samples:
		if s.time >= 60.0:
			s60 = s
			break
	if s60.is_empty():
		_fail("[jobs] no sample at 60s mark")
	elif s60.claimed_jobs < 5:
		_fail("[jobs] claimed_jobs=%d < 5 at 60s" % s60.claimed_jobs)
	
	# Criterion 5: open_jobs never exceeds 200
	for s in _samples:
		if s.open_jobs > 200:
			_fail("[jobs] open_jobs=%d > 200 at t=%.1f" % [s.open_jobs, s.time])
	
	# Criterion 6: >= 80% of alive pawns have jobs at 60s and 120s
	for target_time in [60.0, 120.0]:
		var found: Dictionary = {}
		for s in _samples:
			if s.time >= target_time:
				found = s
				break
		if not found.is_empty():
			var pct: float = float(found.pawns_with_jobs) / float(max(found.alive_pawns, 1))
			if pct < 0.8:
				_fail("[activity] only %.0f%% pawns with jobs at %.0fs (need 80%%)" % [pct * 100.0, target_time])
	
	# Print results
	if _passed:
		print("\n  RESULT: ALL CHECKS PASSED")
	else:
		print("\n  RESULT: FAILED")
		for reason in _fail_reasons:
			print("    - %s" % reason)
	print("=".repeat(80) + "\n")

func _fail(reason: String) -> void:
	_passed = false
	_fail_reasons.append(reason)
	print("[SMOKE_FAIL] %s" % reason)