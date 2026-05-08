extends Node
## Central deterministic tick manager. Drives ALL simulation logic via fixed-step
## accumulation. Emits `tick_processed` and calls `_on_world_tick()` on all
## nodes in the "tickable" group.
##
## BURST TICK PATTERN:
## At high speeds (100x, 1000x), multiple simulation ticks accumulate in one frame.
## The `while` loop processes all pending ticks, but is capped by MAX_TICKS_PER_FRAME
## to prevent hanging. If the cap is hit, we drop the remaining backlog so the
## sim can recover instead of spiraling forever.

signal tick_processed(tick_number: int)

const TICK_STEP: float = 1.0  # Fixed simulation step (1 tick/sec base; stable for HeelKawn)

## SAFETY: Maximum ticks processed in one render frame (bounded burst).
## High value (500) prioritizes simulation speed at high multipliers.
## At 100x speed: delta ≈ 16.7ms * 100 = 1667ms of sim → ~1667 ticks pending.
## With MAX=500, we can catch up faster and sustain smooth 100x simulation.
const MAX_TICKS_PER_FRAME: int = 500

## Adaptive Throttle: Target frame time budget (microseconds).
## 50ms = 50000 usec budget allows substantial CPU use for simulation.
## Prioritizes simulation speed over render framerate; game may drop to 20fps at 100x but simulation stays smooth.
const TARGET_FRAME_TIME_USEC: int = 50000  # 50ms budget


## Read max ticks/frame from GameSettings if available, else fall back to constant.
func _get_max_ticks_per_frame() -> int:
	if GameSettings != null:
		return int(GameSettings.get_value("max_ticks_per_frame"))
	return MAX_TICKS_PER_FRAME

## Read frame budget from GameSettings if available, else fall back to constant.
func _get_frame_budget_usec() -> int:
	if GameSettings != null:
		return int(GameSettings.get_value("frame_budget_ms")) * 1000
	return TARGET_FRAME_TIME_USEC

## How often (in ticks) to force-rebuild the tickable cache.
## A low value ensures dead nodes are pruned; a high value minimizes overhead.
const TICKABLE_CACHE_REBUILD_INTERVAL: int = 300

var current_tick: int = 0
var _accumulated_time: float = 0.0
var _is_paused: bool = false
var _speed_multiplier: float = 1.0

## RefCounted objects that register for tick notifications (SettlementAI, etc.)
var _refcounted_tickables: Array = []

## Cached sorted tickable nodes. Rebuilt when dirty or periodically.
var _tickable_cache: Array = []
var _tickable_cache_dirty: bool = true
var _tickable_cache_last_rebuild_tick: int = -TICKABLE_CACHE_REBUILD_INTERVAL

## Speed presets: 1x, 3x, 6x, 12x, 26x, 50x, 100x
const SPEED_PRESETS: Array[float] = [1.0, 3.0, 6.0, 12.0, 26.0, 50.0, 100.0]
var _current_speed_index: int = 0  # Start at 1x (index 0)

var _ticks_behind: int = 0
var _last_frame_ticks: int = 0
var _adaptive_max_ticks_per_frame: int = 500  # initialized from _get_max_ticks_per_frame() in _ready
var _low_fps_frame_streak: int = 0
## Debug-only: microseconds spent in the tick batch last frame (0 when not a debug build).
var debug_last_tick_batch_usec: int = 0
## Once per backlog spike: warn when accumulated time exceeds 2× target interval until recovered.
var _backlog_degrade_warned: bool = false

## Batch processing statistics (for performance monitoring)
var batch_stats: Dictionary = {
	"total_ticks": 0,
	"total_nodes_called": 0,
	"total_refcounted_called": 0,
	"avg_ticks_per_frame": 0.0,
	"last_frame_time_usec": 0,
}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_adaptive_max_ticks_per_frame = _get_max_ticks_per_frame()


## Mark the tickable cache as dirty. Call this when a node joins/leaves the "tickable" group.
func mark_tickable_cache_dirty() -> void:
	_tickable_cache_dirty = true


func _process(delta: float) -> void:
	if _is_paused:
		return
	if delta <= 0.0 or _speed_multiplier <= 0.0:
		_last_frame_ticks = 0
		return

	# Accumulate scaled time
	_accumulated_time += delta * _speed_multiplier
	var current_fps: int = Engine.get_frames_per_second()
	if current_fps < 55:
		_low_fps_frame_streak += 1
		if _low_fps_frame_streak >= 3:
			# Reduce ticks but never below floor — prevents death spiral where
			# adaptive throttle cuts to 1 tick/frame and pawns stop functioning.
			var floor_ticks: int = maxi(10, _get_max_ticks_per_frame() / 4)
			_adaptive_max_ticks_per_frame = maxi(floor_ticks, int(floor(float(_adaptive_max_ticks_per_frame) * 0.75)))
			_low_fps_frame_streak = 0
	else:
		_low_fps_frame_streak = 0
		_adaptive_max_ticks_per_frame = _get_max_ticks_per_frame()

	var start_time: int = Time.get_ticks_usec()
	var ticks_this_frame: int = 0

	# Frame budget: 50ms at normal speeds, 100ms at high speeds.
	# 100ms keeps the window responsive (well under Windows' 5s kill threshold)
	# while allowing ~10 ticks/frame for backlog catch-up at 10ms/tick.
	var frame_budget_usec: int = _get_frame_budget_usec()
	if _speed_multiplier > 20.0:
		frame_budget_usec = 100_000  # 100ms — responsive but allows burst catch-up

	while _accumulated_time >= TICK_STEP and ticks_this_frame < _adaptive_max_ticks_per_frame:
		_accumulated_time -= TICK_STEP
		current_tick += 1
		ticks_this_frame += 1
		_dispatch_tick(current_tick)

		# Check time every 4 ticks to balance overhead vs responsiveness
		if ticks_this_frame % 4 == 0:
			var elapsed: int = Time.get_ticks_usec() - start_time
			if elapsed > frame_budget_usec:
				break  # Yield to renderer — remaining ticks deferred to next frame

	# SAFETY: If backlog grows dangerously large (>10x cap),
	# drop the excess to prevent death spiral. The sim will lose
	# some ticks but recover instead of hanging forever.
	var max_backlog: float = TICK_STEP * float(_get_max_ticks_per_frame()) * 10.0
	if _accumulated_time > max_backlog:
		if OS.is_debug_build():
			push_warning("[TickManager] Backlog overflow (%.1f ticks). Dropping excess to prevent hang." % (_accumulated_time / TICK_STEP))
		_accumulated_time = max_backlog

	_last_frame_ticks = ticks_this_frame


func _dispatch_tick(tick: int) -> void:
	## PERFORMANCE NOTE: This is the CRITICAL tick loop.
	## Expensive operations that should be MOVED out:
	## 1. Complex pathfinding → use deferred worker or cache results
	## 2. Heavy math (per-pawn matrix calculations) → simplify at high speeds
	## 3. Distant pawn updates → use LOD (Level of Detail) system:
	##    - At 16x+: pawns >50 tiles from nearest settlement update at 1/4 rate
	##    - At 64x+: pawns >100 tiles update at 1/8 rate
	## 4. Settlement AI recalculations → run on 100-tick cadence, not every tick
	
	var node_count: int = 0
	var refcounted_count: int = 0
	
	tick_processed.emit(tick)
	node_count = _call_tick_on_tickables(tick)
	refcounted_count = _call_tick_on_refcounted(tick)
	
	# Update batch stats
	batch_stats["total_ticks"] = int(batch_stats.get("total_ticks", 0)) + 1
	batch_stats["total_nodes_called"] = int(batch_stats.get("total_nodes_called", 0)) + node_count
	batch_stats["total_refcounted_called"] = int(batch_stats.get("total_refcounted_called", 0)) + refcounted_count
	
	# Keep GameManager in sync for systems that still read tick_count
	if GameManager != null:
		GameManager.tick_count = tick


func _call_tick_on_tickables(tick: int) -> int:
	## PERFORMANCE OPTIMIZATION: Cached tickable nodes.
	## Instead of calling get_nodes_in_group() + sort every tick (O(n) traversal
	## + O(n log n) sort × 500 ticks/frame at 100x), we cache the sorted list and
	## only rebuild when dirty or every TICKABLE_CACHE_REBUILD_INTERVAL ticks.
	var needs_rebuild: bool = _tickable_cache_dirty
	if not needs_rebuild:
		var ticks_since_rebuild: int = tick - _tickable_cache_last_rebuild_tick
		if ticks_since_rebuild >= TICKABLE_CACHE_REBUILD_INTERVAL:
			needs_rebuild = true

	if needs_rebuild:
		var tree: SceneTree = get_tree()
		if tree == null:
			return 0
		var new_cache: Array = []
		for node in tree.get_nodes_in_group("tickable"):
			if node != null and is_instance_valid(node) and node.has_method("_on_world_tick"):
				new_cache.append(node)
		# Sort by node path for deterministic order
		new_cache.sort_custom(func(a, b): return str(a.get_path()) < str(b.get_path()))
		_tickable_cache = new_cache
		_tickable_cache_dirty = false
		_tickable_cache_last_rebuild_tick = tick

	# Call cached tickables, pruning any that became invalid since last rebuild
	var valid_count: int = 0
	var i: int = _tickable_cache.size() - 1
	while i >= 0:
		var node: Node = _tickable_cache[i]
		if is_instance_valid(node):
			# All tickables run every tick - no LOD skipping for pawns
			# HeelKawn principle: deterministic causality, no frame-dependent behavior
			node._on_world_tick(tick)
			valid_count += 1
		else:
			_tickable_cache.remove_at(i)
			_tickable_cache_dirty = true
		i -= 1
	return valid_count

func _call_tick_on_refcounted(tick: int) -> int:
	var count: int = 0
	for obj in _refcounted_tickables:
		if is_instance_valid(obj) and obj.has_method("_on_world_tick"):
			obj._on_world_tick(tick)
			count += 1
	return count

## Register a RefCounted object for tick notifications (e.g., SettlementAI).
func register_refcounted_tickable(obj: RefCounted) -> void:
	if not _refcounted_tickables.has(obj):
		_refcounted_tickables.append(obj)

func unregister_refcounted_tickable(obj: RefCounted) -> void:
	_refcounted_tickables.erase(obj)

## Set speed by multiplier (1.0, 3.0, 6.0, 12.0, 26.0, 50.0, 100.0).
func set_speed(multiplier: float) -> void:
	_speed_multiplier = max(multiplier, 0.0001)
	# Update GameManager speed for UI compatibility
	if GameManager != null:
		GameManager.game_speed = _speed_multiplier
		GameManager.speed_changed.emit(_speed_multiplier, _is_paused)

## Set speed by preset index: 0=0.5x, 1=1x, 2=4x, 3=16x, 4=64x.
func set_speed_index(index: int) -> void:
	if index < 0 or index >= SPEED_PRESETS.size():
		return
	_current_speed_index = index
	set_speed(SPEED_PRESETS[index])

## Cycle to next speed preset.
func next_speed() -> void:
	var next: int = (_current_speed_index + 1) % SPEED_PRESETS.size()
	set_speed_index(next)

## Cycle to previous speed preset.
func prev_speed() -> void:
	var prev: int = (_current_speed_index - 1 + SPEED_PRESETS.size()) % SPEED_PRESETS.size()
	set_speed_index(prev)

func pause() -> void:
	_is_paused = true
	if GameManager != null:
		GameManager.is_paused = true
		GameManager.speed_changed.emit(_speed_multiplier, true)

func resume() -> void:
	_is_paused = false
	if GameManager != null:
		GameManager.is_paused = false
		GameManager.speed_changed.emit(_speed_multiplier, false)

func toggle_pause() -> void:
	if _is_paused:
		resume()
	else:
		pause()

func is_paused() -> bool:
	return _is_paused

func get_speed_multiplier() -> float:
	return _speed_multiplier

func get_speed_index() -> int:
	return _current_speed_index

func reset() -> void:
	current_tick = 0
	_accumulated_time = 0.0
	_ticks_behind = 0
	_last_frame_ticks = 0
	_backlog_degrade_warned = false
	debug_last_tick_batch_usec = 0
	_tickable_cache.clear()
	_tickable_cache_dirty = true
	_tickable_cache_last_rebuild_tick = -TICKABLE_CACHE_REBUILD_INTERVAL
