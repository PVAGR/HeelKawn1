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
## Hard cap prevents infinite loops while allowing deterministic catch-up.
## At 100x speed: delta ≈ 16.7ms * 100 = 1667ms of sim → ~1667 ticks pending.
## With MAX=64, we process 64/frame; backlog drains over ~26 frames naturally.
const MAX_TICKS_PER_FRAME: int = 64

## Adaptive Throttle: Target frame time to leave CPU headroom (ms).
## At ~70 FPS target, each frame should take <14ms of tick processing to preserve 60 FPS UI rendering.
const TARGET_FRAME_TIME_MS: float = 14.0

var current_tick: int = 0
var _accumulated_time: float = 0.0
var _is_paused: bool = false
var _speed_multiplier: float = 1.0

## RefCounted objects that register for tick notifications (SettlementAI, etc.)
var _refcounted_tickables: Array = []

## Speed presets: 1x, 3x, 6x, 12x, 26x, 50x, 100x
const SPEED_PRESETS: Array[float] = [1.0, 3.0, 6.0, 12.0, 26.0, 50.0, 100.0]
var _current_speed_index: int = 0  # Start at 1x (index 0)

var _ticks_behind: int = 0
var _last_frame_ticks: int = 0
## Debug-only: microseconds spent in the tick batch last frame (0 when not a debug build).
var debug_last_tick_batch_usec: int = 0
## Once per backlog spike: warn when accumulated time exceeds 2× target interval until recovered.
var _backlog_degrade_warned: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	if _is_paused:
		return
	if delta <= 0.0 or _speed_multiplier <= 0.0:
		_last_frame_ticks = 0
		return

	# Accumulate scaled time
	_accumulated_time += delta * _speed_multiplier

	var start_time: int = Time.get_ticks_msec()
	var ticks_this_frame: int = 0

	# Process ticks up to safety cap
	while _accumulated_time >= TICK_STEP and ticks_this_frame < MAX_TICKS_PER_FRAME:
		_accumulated_time -= TICK_STEP
		current_tick += 1
		ticks_this_frame += 1
		_dispatch_tick(current_tick)

		# Adaptive Throttle: If processing this batch takes too long, break to let the frame render
		var elapsed: int = Time.get_ticks_msec() - start_time
		if elapsed > int(TARGET_FRAME_TIME_MS):
			if OS.is_debug_build():
				push_warning("[TickManager] Adaptive throttle active: Processed %d ticks in %dms, pausing to prevent freeze." % [ticks_this_frame, elapsed])
			break

	# SAFETY: If backlog grows dangerously large (>10x cap),
	# log a warning but DO NOT drop time. The sim will catch up over frames.
	if _accumulated_time > TICK_STEP * MAX_TICKS_PER_FRAME * 10:
		if OS.is_debug_build():
			push_warning("[TickManager] Massive backlog detected (%.1fs). System is catching up." % (_accumulated_time / TICK_STEP))

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
	
	tick_processed.emit(tick)
	_call_tick_on_tickables(tick)
	_call_tick_on_refcounted(tick)
	
	# Keep GameManager in sync for systems that still read tick_count
	if GameManager != null:
		GameManager.tick_count = tick


## LOD (Level of Detail) helper: should this pawn skip this tick?
func _should_skip_pawn_tick(pawn: Node, current_speed: float) -> bool:
	## At high speeds, distant pawns update less frequently
	## pawn must have a `position` and `tile_pos` property
	if current_speed < 16.0:
		return false  # No LOD at normal speeds
	
	if not is_instance_valid(pawn) or pawn.get("tile_pos") == null:
		return false
	
	## Get nearest settlement center (cached lookup)
	var tile_pos: Vector2i = pawn.get("tile_pos")
	var nearest_dist: float = 99999.0
	
	## Simple check: if pawn has a settlement_id, use that for distance
	if pawn.get("data") != null:
		var d = pawn.get("data")
		if d != null and d.has("settlement_id"):
			var sid: int = int(d.get("settlement_id"))
			if sid >= 0:
				## Pawn is in a settlement - always update
				return false
	
	## At 64x, only sample distant pawns without a settlement.
	if current_speed >= 64.0:
		if pawn.get("carrying") == null or pawn.get("carrying") == 0:
			## Sample distant non-settlement pawns instead of skipping all of them.
			return (GameManager.tick_count + int(pawn.get_instance_id())) % 8 != 0
	
	## At 16x-32x, use distance-based skip
	if current_speed >= 16.0:
		## Skip if pawn is far from any activity (no settlement, not carrying resources)
		if pawn.get("carrying") == null or pawn.get("carrying") == 0:
			## 50% chance to skip distant pawns (simplified update)
			return (GameManager.tick_count + int(pawn.get_instance_id())) % 2 == 0
	
	return false

func _call_tick_on_tickables(tick: int) -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	# Collect valid tickable nodes
	var tickable_nodes: Array = []
	for node in tree.get_nodes_in_group("tickable"):
		if node != null and is_instance_valid(node) and node.has_method("_on_world_tick"):
			tickable_nodes.append(node)
	# Sort by node path for deterministic order
	tickable_nodes.sort_custom(func(a, b): return str(a.get_path()) < str(b.get_path()))
	for node in tickable_nodes:
		node._on_world_tick(tick)

func _call_tick_on_refcounted(tick: int) -> void:
	for obj in _refcounted_tickables:
		if is_instance_valid(obj) and obj.has_method("_on_world_tick"):
			obj._on_world_tick(tick)

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
