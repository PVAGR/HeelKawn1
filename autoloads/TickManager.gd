extends Node
signal tick_processed(tick_number: int)
signal speed_changed(speed_multiplier: float, is_paused: bool)

const SPEED_MULTIPLIERS: Array = [1.0, 6.0, 26.0, 50.0, 100.0, 200.0]
const SPEED_LABELS: Array      = ["1x", "6x", "26x", "50x", "100x", "200x"]
const BASE_TICK_INTERVAL: float = 0.05
const MAX_ACCUMULATOR_SEC: float = 5.0

var current_tick: int = 0
var _accumulated_time: float = 0.0
var _speed_index: int = 0
var _is_paused: bool = false
var _refcounted_tickables: Array = []
var _tickable_cache: Array = []
var _tickable_callables: Array = []
var _tickable_cache_dirty: bool = true
var debug_last_tick_batch_usec: int = 0
var _last_tick_usec: int = 0

var _profile_accum: Dictionary = {
	"neural": 0,
	"jobs": 0,
	"memory": 0,
	"meaning": 0,
	"pathfind": 0,
	"settlement": 0,
}
var _profile_total: int = 0
var _profile_tick_count: int = 0
var _profile_per_path: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(delta: float) -> void:
	if _is_paused:
		return
	_accumulated_time += delta * SPEED_MULTIPLIERS[_speed_index]
	# Cap accumulator to prevent death spiral if frame takes too long
	_accumulated_time = minf(_accumulated_time, MAX_ACCUMULATOR_SEC)
	var ticks_this_frame: int = 0
	while _accumulated_time >= BASE_TICK_INTERVAL:
		_accumulated_time -= BASE_TICK_INTERVAL
		current_tick += 1
		_fire_tick(current_tick)
		ticks_this_frame += 1

func _fire_tick(tick: int) -> void:
	var start: int = Time.get_ticks_usec()
	if _tickable_cache_dirty:
		_tickable_cache = get_tree().get_nodes_in_group("tickable")
		_tickable_cache.sort_custom(func(a, b): return str(a.get_path()) < str(b.get_path()))
		_tickable_callables.clear()
		for node in _tickable_cache:
			if is_instance_valid(node) and node.has_method("_on_world_tick"):
				_tickable_callables.append(Callable(node, "_on_world_tick"))
		_tickable_cache_dirty = false
	for cb in _tickable_callables:
		if cb.is_valid():
			var obj = cb.get_object()
			var sys_name: String = _get_system_name(obj)
			var t0: int = Time.get_ticks_usec()
			cb.call(tick)
			var dt: int = Time.get_ticks_usec() - t0
			if sys_name != "":
				_profile_accum[sys_name] += dt
			_profile_total += dt
			var path_str: String = str(obj.get_path())
			_profile_per_path[path_str] = int(_profile_per_path.get(path_str, 0)) + dt
	for ref in _refcounted_tickables:
		if ref != null and ref.has_method("_on_world_tick"):
			var t1: int = Time.get_ticks_usec()
			ref._on_world_tick(tick)
			_profile_total += Time.get_ticks_usec() - t1
	tick_processed.emit(tick)
	debug_last_tick_batch_usec = Time.get_ticks_usec() - start
	_last_tick_usec = debug_last_tick_batch_usec
	_profile_tick_count += 1
	if _profile_tick_count >= 60:
		_profile_tick_count = 0
		_emit_tick_profile()


func _get_system_name(node) -> String:
	if node == null:
		return ""
	var path = str(node.get_path())
	match path:
		"/root/WorldAI": return "neural"
		"/root/JobManager": return "jobs"
		"/root/WorldMemory": return "memory"
		"/root/WorldMeaning": return "meaning"
		"/root/SettlementMemory": return "settlement"
	if node is PathFinder:
		return "pathfind"
	return ""


func _emit_tick_profile() -> void:
	var known_total: int = 0
	for key in _profile_accum:
		known_total += int(_profile_accum[key])
	var other_usec: int = _profile_total - known_total
	# Sort paths by accumulated time descending
	var entries: Array = []
	for path_str in _profile_per_path:
		entries.append({"path": path_str, "usec": int(_profile_per_path[path_str])})
	entries.sort_custom(func(a, b): return int(a["usec"]) > int(b["usec"]))
	var top3_str: String = ""
	for i in range(mini(entries.size(), 3)):
		var e: Dictionary = entries[i]
		if i > 0:
			top3_str += " | "
		top3_str += "%s=%.2fms" % [e["path"], float(e["usec"]) / 1000.0]
	print("[TICK-PROFILE] neural=%.2fms | jobs=%.2fms | memory=%.2fms | meaning=%.2fms | pathfind=%.2fms | settlement=%.2fms | other=%.2fms | total=%.2fms" % [
		float(_profile_accum["neural"]) / 1000.0,
		float(_profile_accum["jobs"]) / 1000.0,
		float(_profile_accum["memory"]) / 1000.0,
		float(_profile_accum["meaning"]) / 1000.0,
		float(_profile_accum["pathfind"]) / 1000.0,
		float(_profile_accum["settlement"]) / 1000.0,
		float(other_usec) / 1000.0,
		float(_profile_total) / 1000.0
	])
	print("[TICK-PROFILE] TOP3: %s" % top3_str)
	# Reset accumulators
	for key in _profile_accum:
		_profile_accum[key] = 0
	_profile_total = 0
	_profile_per_path.clear()

func mark_tickable_cache_dirty() -> void:
	_tickable_cache_dirty = true

func register_refcounted_tickable(obj) -> void:
	if obj not in _refcounted_tickables:
		_refcounted_tickables.append(obj)
func unregister_refcounted_tickable(obj) -> void:
	_refcounted_tickables.erase(obj)
func set_speed(multiplier: float) -> void:
	var best: int = 0
	var best_diff: float = INF
	for i in range(SPEED_MULTIPLIERS.size()):
		var diff: float = absf(SPEED_MULTIPLIERS[i] - multiplier)
		if diff < best_diff:
			best_diff = diff
			best = i
	set_speed_index(best)
func set_speed_index(index: int) -> void:
	_speed_index = clampi(index, 0, SPEED_MULTIPLIERS.size() - 1)
	speed_changed.emit(SPEED_MULTIPLIERS[_speed_index], _is_paused)
func get_speed_multiplier() -> float: return SPEED_MULTIPLIERS[_speed_index]
func get_speed_label() -> String: return SPEED_LABELS[_speed_index]
func get_speed_index() -> int: return _speed_index
func pause() -> void:
	_is_paused = true
	speed_changed.emit(SPEED_MULTIPLIERS[_speed_index], _is_paused)
func resume() -> void:
	_is_paused = false
	speed_changed.emit(SPEED_MULTIPLIERS[_speed_index], _is_paused)
func toggle_pause() -> void:
	if _is_paused: resume()
	else: pause()
func is_paused() -> bool: return _is_paused
func is_high_speed() -> bool: return _speed_index >= 3
func verbose_logs() -> bool: return false
