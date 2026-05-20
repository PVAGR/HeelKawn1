extends Node
class_name TickManager
## Central deterministic tick manager. Drives ALL simulation logic via fixed-step
## accumulation. Emits `tick_processed` and calls `_on_world_tick()` on all
## nodes in the "tickable" group.
##
## PLAYABILITY POLICY:
## Keep simulation deterministic, but never allow catch-up storms to freeze
## rendering. Process ticks with adaptive frame caps + bounded backlog.

signal tick_processed(tick_number: int)

const TICK_STEP: float = 1.0  # Fixed simulation step (1 tick/sec base)

## Hard safety cap.
const MAX_TICKS_PER_FRAME: int = 48

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
var dropped_ticks_last_frame: int = 0


func _is_mobile_runtime() -> bool:
	return OS.has_feature("mobile") or DisplayServer.is_touchscreen_available()


func _is_frame_stressed() -> bool:
	var fps: float = float(Engine.get_frames_per_second())
	if fps <= 0.0:
		return false
	if _is_mobile_runtime():
		return fps < 42.0
	return fps < 32.0


func _frame_tick_cap_for_speed(speed: float) -> int:
	if _is_mobile_runtime():
		if speed <= 1.0: return 1
		if speed <= 3.0: return 2
		if speed <= 6.0: return 3
		if speed <= 12.0: return 4
		if speed <= 26.0: return 6
		if speed <= 50.0: return 8
		return 10
	if speed <= 1.0: return 1
	if speed <= 3.0: return 3
	if speed <= 6.0: return 5
	if speed <= 12.0: return 7
	if speed <= 26.0: return 10
	if speed <= 50.0: return 14
	return 18


func _accumulated_tick_cap_for_speed(speed: float) -> int:
	if _is_mobile_runtime():
		if speed <= 1.0: return 2
		if speed <= 3.0: return 6
		if speed <= 6.0: return 12
		if speed <= 12.0: return 20
		if speed <= 26.0: return 32
		if speed <= 50.0: return 48
		return 64
	if speed <= 1.0: return 2
	if speed <= 3.0: return 10
	if speed <= 6.0: return 20
	if speed <= 12.0: return 32
	if speed <= 26.0: return 48
	if speed <= 50.0: return 72
	return 96

## LOD tick counter for staggering pawn processing at high speeds
var _lod_tick_counter: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func mark_tickable_cache_dirty() -> void:
	_tickable_cache_dirty = true


func _process(delta: float) -> void:
	if _is_paused:
		ticks_processed_last_frame = 0
		tickables_called_last_frame = 0
		dropped_ticks_last_frame = 0
		return
	if delta <= 0.0 or _speed_multiplier <= 0.0:
		_last_frame_ticks = 0
		ticks_processed_last_frame = 0
		tickables_called_last_frame = 0
		dropped_ticks_last_frame = 0
		return

	# Accumulate scaled time; cap backlog to prevent catch-up storms.
	_accumulated_time += delta * _speed_multiplier
	dropped_ticks_last_frame = 0
	var accumulated_tick_cap: int = _accumulated_tick_cap_for_speed(_speed_multiplier)
	if _is_frame_stressed():
		accumulated_tick_cap = maxi(1, int(floor(float(accumulated_tick_cap) * 0.5)))
	var max_accumulated_time: float = float(accumulated_tick_cap) * TICK_STEP
	if _accumulated_time > max_accumulated_time:
		var dropped_ticks: int = int(floor((_accumulated_time - max_accumulated_time) / TICK_STEP))
		dropped_ticks_last_frame = maxi(0, dropped_ticks)
		_accumulated_time = max_accumulated_time

	var start_time: int = Time.get_ticks_usec()
	var ticks_this_frame: int = 0
	var tickables_this_frame: int = 0
	var frame_cap: int = mini(MAX_TICKS_PER_FRAME, _frame_tick_cap_for_speed(_speed_multiplier))
	if _is_frame_stressed():
		frame_cap = maxi(1, int(floor(float(frame_cap) * 0.5)))

	# Process with adaptive frame cap so render thread stays responsive.
	while _accumulated_time >= TICK_STEP and ticks_this_frame < frame_cap:
		_accumulated_time -= TICK_STEP
		current_tick += 1
		ticks_this_frame += 1
		tickables_this_frame += _dispatch_tick(current_tick)

	_last_frame_ticks = ticks_this_frame
	ticks_processed_last_frame = ticks_this_frame
	tickables_called_last_frame = tickables_this_frame
	max_ticks_processed_seen = maxi(max_ticks_processed_seen, ticks_this_frame)
	debug_last_tick_batch_usec = Time.get_ticks_usec() - start_time


func _dispatch_tick(tick: int) -> int:
	var node_count: int = 0
	var refcounted_count: int = 0

	tick_processed.emit(tick)
	node_count = _call_tick_on_tickables(tick)
	refcounted_count = _call_tick_on_refcounted(tick)

	batch_stats["total_ticks"] = int(batch_stats.get("total_ticks", 0)) + 1
	batch_stats["total_nodes_called"] = int(batch_stats.get("total_nodes_called", 0)) + node_count
	batch_stats["total_refcounted_called"] = int(batch_stats.get("total_refcounted_called", 0)) + refcounted_count

	if GameManager != null:
		GameManager.tick_count = tick
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

	var lod_rate: int = _lod_rate_for_speed()
	var valid_count: int = 0
	if lod_rate > 1:
		_lod_tick_counter = (_lod_tick_counter + 1) % lod_rate
	var i: int = _tickable_cache.size() - 1
	while i >= 0:
		var node: Node = _tickable_cache[i]
		if is_instance_valid(node):
			if not _should_skip_tick_for_lod(node, lod_rate):
				node._on_world_tick(tick)
				valid_count += 1
		else:
			_tickable_cache.remove_at(i)
			_tickable_cache_dirty = true
		i -= 1
	return valid_count


func _lod_rate_for_speed() -> int:
	# At high speeds, stagger pawn processing across ticks
	# to reduce per-frame simulation load
	if GameManager == null:
		return 1
	var gs: float = GameManager.game_speed
	if gs >= 100.0:
		return 4  # 1/4 of pawns per tick
	if gs >= 50.0:
		return 3  # 1/3 of pawns per tick
	if gs >= 26.0:
		return 2  # 1/2 of pawns per tick
	return 1  # All pawns every tick


func _should_skip_tick_for_lod(node: Node, lod_rate: int) -> bool:
	if lod_rate <= 1:
		return false
	# Only LOD pawns (nodes with 'data' property indicating a pawn)
	if not "data" in node:
		return false
	var bucket: int = node.get_instance_id() % lod_rate
	return bucket != _lod_tick_counter


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
	var next_speed: float = max(multiplier, 0.0001)
	# Mobile thermal/fps guardrail: avoid runaway 50x/100x simulation bursts on phones.
	if _is_mobile_runtime():
		next_speed = minf(next_speed, 26.0)
	_speed_multiplier = next_speed
	var nearest_idx: int = 0
	var nearest_dist: float = 1.0e20
	for i in range(SPEED_PRESETS.size()):
		var d: float = absf(float(SPEED_PRESETS[i]) - _speed_multiplier)
		if d < nearest_dist:
			nearest_dist = d
			nearest_idx = i
	_current_speed_index = nearest_idx
	if GameManager != null:
		GameManager.game_speed = _speed_multiplier
		GameManager.speed_changed.emit(_speed_multiplier, _is_paused)

func set_speed_index(index: int) -> void:
	if index < 0 or index >= SPEED_PRESETS.size():
		return
	var clamped_index: int = index
	if _is_mobile_runtime():
		clamped_index = mini(index, 4) # up to 26x on mobile
	_current_speed_index = clamped_index
	set_speed(SPEED_PRESETS[clamped_index])

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
