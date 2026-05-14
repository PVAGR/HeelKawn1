extends Node
## Central deterministic tick manager. Drives ALL simulation logic via fixed-step
## accumulation. Emits `tick_processed` and calls `_on_world_tick()` on all
## nodes in the "tickable" group.
##
## FRAME BUDGET POLICY:
## Caps the number of ticks processed per frame based on measured cost.
## At most 2 ticks per frame. If ticks become faster (e.g. < 1ms), cap
## allows more. Excess ticks carry over — keeps FPS smooth.

signal tick_processed(tick_number: int)

const TICK_STEP: float = 1.0  # Fixed simulation step (1 tick/sec base)

## Hard cap: at most 3 ticks per frame, regardless of speed.
## This prevents any single frame from freezing.
const MAX_TICKS_PER_FRAME: int = 3

## Hard safety cap: at most 5 seconds of ticks in the accumulator.
const MAX_ACCUMULATED_SECONDS: float = 5.0

## How often (in ticks) to force-rebuild the tickable cache.
const TICKABLE_CACHE_REBUILD_INTERVAL: int = 300

var current_tick: int = 0
var _accumulated_time: float = 0.0
var _is_paused: bool = false
var _speed_multiplier: float = 1.0

## RefCounted objects that register for tick notifications
var _refcounted_tickables: Array = []

## Cached sorted tickable nodes.
var _tickable_cache: Array = []
var _tickable_cache_dirty: bool = true
var _tickable_cache_last_rebuild_tick: int = -TICKABLE_CACHE_REBUILD_INTERVAL

## Speed presets: 1x, 3x, 6x, 12x, 26x, 50x, 100x
const SPEED_PRESETS: Array[float] = [1.0, 3.0, 6.0, 12.0, 26.0, 50.0, 100.0]
var _current_speed_index: int = 0

var _last_frame_ticks: int = 0
var debug_last_tick_batch_usec: int = 0

var ticks_processed_last_frame: int = 0
var tickables_called_last_frame: int = 0
var max_ticks_processed_seen: int = 0

var batch_stats: Dictionary = {
	"total_ticks": 0,
	"total_nodes_called": 0,
	"total_refcounted_called": 0,
	"avg_ticks_per_frame": 0.0,
	"last_frame_time_usec": 0,
}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func mark_tickable_cache_dirty() -> void:
	_tickable_cache_dirty = true


func _process(delta: float) -> void:
	if _is_paused:
		ticks_processed_last_frame = 0
		tickables_called_last_frame = 0
		return
	if delta <= 0.0 or _speed_multiplier <= 0.0:
		_last_frame_ticks = 0
		ticks_processed_last_frame = 0
		tickables_called_last_frame = 0
		return

	# Accumulate scaled time
	_accumulated_time += delta * _speed_multiplier
	# Cap accumulator to prevent death spiral
	_accumulated_time = min(_accumulated_time, MAX_ACCUMULATED_SECONDS)

	var start_time: int = Time.get_ticks_usec()
	var ticks_this_frame: int = 0
	var tickables_this_frame: int = 0

	# Process at most MAX_TICKS_PER_FRAME ticks. Extra ticks carry to next frame.
	while _accumulated_time >= TICK_STEP and ticks_this_frame < MAX_TICKS_PER_FRAME:
		_accumulated_time -= TICK_STEP
		current_tick += 1
		ticks_this_frame += 1
		tickables_this_frame += _dispatch_tick(current_tick)

	_last_frame_ticks = ticks_this_frame
	ticks_processed_last_frame = ticks_this_frame
	tickables_called_last_frame = tickables_this_frame
	max_ticks_processed_seen = maxi(max_ticks_processed_seen, ticks_this_frame)
	var batch_usec: int = Time.get_ticks_usec() - start_time
	debug_last_tick_batch_usec = batch_usec
	if _speed_multiplier >= 10.0 and batch_usec > 50000 and OS.is_debug_build():
		print("[TICK_BATCH] speed=%.0fx ticks=%d accum_before=%.2f elapsed_us=%d delta_ms=%.1f" % [_speed_multiplier, ticks_this_frame, _accumulated_time + TICK_STEP * ticks_this_frame, batch_usec, delta * 1000.0])


func _dispatch_tick(tick: int) -> int:
	var t0: int = Time.get_ticks_usec()
	var node_count: int = 0
	var refcounted_count: int = 0

	tick_processed.emit(tick)
	var t1: int = Time.get_ticks_usec()
	node_count = _call_tick_on_tickables(tick)
	var t2: int = Time.get_ticks_usec()
	refcounted_count = _call_tick_on_refcounted(tick)
	var t3: int = Time.get_ticks_usec()

	batch_stats["total_ticks"] = int(batch_stats.get("total_ticks", 0)) + 1
	batch_stats["total_nodes_called"] = int(batch_stats.get("total_nodes_called", 0)) + node_count
	batch_stats["total_refcounted_called"] = int(batch_stats.get("total_refcounted_called", 0)) + refcounted_count

	if GameManager != null:
		GameManager.tick_count = tick
	if t3 - t0 > 50000 and OS.is_debug_build() and _speed_multiplier >= 10.0:
		print("[TICK_COST] tick=%d total=%.1fms signal=%.1fms nodes(%d)=%.1fms refcounted(%d)=%.1fms" % [tick, (t3 - t0) / 1000.0, (t1 - t0) / 1000.0, node_count, (t2 - t1) / 1000.0, refcounted_count, (t3 - t2) / 1000.0])
	return node_count + refcounted_count


func _call_tick_on_tickables(tick: int) -> int:
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
		new_cache.sort_custom(func(a, b): return str(a.get_path()) < str(b.get_path()))
		_tickable_cache = new_cache
		_tickable_cache_dirty = false
		_tickable_cache_last_rebuild_tick = tick

	var valid_count: int = 0
	var i: int = _tickable_cache.size() - 1
	while i >= 0:
		var node: Node = _tickable_cache[i]
		if is_instance_valid(node):
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


func register_refcounted_tickable(obj: RefCounted) -> void:
	if not _refcounted_tickables.has(obj):
		_refcounted_tickables.append(obj)

func unregister_refcounted_tickable(obj: RefCounted) -> void:
	_refcounted_tickables.erase(obj)

func set_speed(multiplier: float) -> void:
	_speed_multiplier = max(multiplier, 0.0001)
	if GameManager != null:
		GameManager.game_speed = _speed_multiplier
		GameManager.speed_changed.emit(_speed_multiplier, _is_paused)

func set_speed_index(index: int) -> void:
	if index < 0 or index >= SPEED_PRESETS.size():
		return
	_current_speed_index = index
	set_speed(SPEED_PRESETS[index])

func next_speed() -> void:
	var next: int = (_current_speed_index + 1) % SPEED_PRESETS.size()
	set_speed_index(next)

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
	_last_frame_ticks = 0
	debug_last_tick_batch_usec = 0
	ticks_processed_last_frame = 0
	tickables_called_last_frame = 0
	max_ticks_processed_seen = 0
	_tickable_cache.clear()
	_tickable_cache_dirty = true
	_tickable_cache_last_rebuild_tick = -TICKABLE_CACHE_REBUILD_INTERVAL
