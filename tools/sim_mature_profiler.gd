extends SceneTree

## Headless MATURE-world per-listener game_tick profiler.
## Run: Godot --headless --path . -s res://tools/sim_mature_profiler.gd --profile-game-tick
##
## Boots Main.tscn, accelerates to 200x, and lets the world mature past the
## cheap early phase (where sim_tick_profiler.gd stops at tick 2000). The
## GameManager --profile-game-tick instrumentation prints a [GT_PROFILE] TOP10
## dump every 1000 ticks; this tool just bounds the run and quits cleanly.

const PROFILING_SPEED: float = 200.0
const MIN_TICK: int = 22000
const TIMEOUT_FRAMES: int = 60000

var _done: bool = false
var _started: bool = false
var _boot_wait: int = 30
var _frame_count: int = 0


func _process(_delta: float) -> bool:
	if _done:
		return false
	if _boot_wait > 0:
		_boot_wait -= 1
		if _boot_wait == 0:
			_begin_profiling()
		return false
	if not _started:
		return false

	_frame_count += 1
	if _frame_count > TIMEOUT_FRAMES:
		print("[MATURE] FAIL reason=frame_limit_exceeded")
		_done = true
		quit(1)
		return true

	var gm: Node = root.get_node_or_null("GameManager")
	if gm == null:
		return false
	var tick: int = gm.get("tick_count")

	if tick >= MIN_TICK:
		print("[MATURE] DONE tick=%d frames=%d" % [tick, _frame_count])
		_done = true
		quit(0)
		return true

	return false


func _enter_tree() -> void:
	var gm_hold: Node = root.get_node_or_null("GameManager")
	if gm_hold != null and gm_hold.has_method("pause"):
		gm_hold.call("pause")
	call_deferred("_spawn_main")


func _spawn_main() -> void:
	var packed: PackedScene = load("res://scenes/main/Main.tscn") as PackedScene
	if packed == null:
		print("[MATURE] FAIL reason=Main_load_failed")
		quit(1)
		return
	var main: Node = packed.instantiate()
	root.add_child(main)
	var tm: Node = root.get_node_or_null("TickManager")
	if tm != null and tm.has_method("resume"):
		tm.call("resume")
	var gm: Node = root.get_node_or_null("GameManager")
	if gm != null and gm.has_method("resume"):
		gm.call("resume")


func _begin_profiling() -> void:
	var tm: Node = root.get_node_or_null("TickManager")
	if tm != null and tm.has_method("set_speed"):
		tm.call("set_speed", PROFILING_SPEED)
	_started = true
	print("[MATURE] START speed=%.0fx" % PROFILING_SPEED)