extends SceneTree
## Long-run headless simulation test — runs N ticks and reports health metrics.
## Run: godot --headless --path . -s res://tools/tests/long_run_test.gd
##
## Exit codes:
##   0 = simulation survived N ticks
##   1 = crashed or timed out

const TARGET_TICKS: int = 500
const TIMEOUT_FRAMES: int = 120000

var _frame_count: int = 0
var _main_spawned: bool = false
var _started: bool = false
var _last_reported_tick: int = -1
var _done: bool = false


func _spawn_main() -> void:
	var packed: PackedScene = load("res://scenes/main/Main.tscn") as PackedScene
	if packed == null:
		print("[LONG_RUN_FAIL] Main.tscn load failed")
		_done = true
		quit(1)
		return
	var main: Node = packed.instantiate()
	root.add_child(main)
	# Resume both TickManager and GameManager
	var tm: Node = root.get_node_or_null("TickManager")
	if tm != null and tm.has_method("resume"):
		tm.call("resume")
	var gm: Node = root.get_node_or_null("GameManager")
	if gm != null:
		if gm.has_method("resume"):
			gm.call("resume")
		elif "is_paused" in gm:
			gm.set("is_paused", false)
		if gm.has_method("set_speed_index"):
			gm.call("set_speed_index", 4)  # Max speed
	_main_spawned = true
	print("[LONG_RUN] Main scene spawned, simulation started")


func _process(_delta: float) -> bool:
	if _done:
		return true

	if not _started:
		_started = true
		call_deferred("_spawn_main")
		return false

	if not _main_spawned:
		return false

	_frame_count += 1

	# Hard timeout
	if _frame_count > TIMEOUT_FRAMES:
		var gm_t: Node = root.get_node_or_null("GameManager")
		var t: int = int(gm_t.get("tick_count")) if gm_t != null else -1
		print("[LONG_RUN_FAIL] tick=%d reason=frame_timeout frames=%d" % [t, _frame_count])
		_done = true
		quit(1)
		return true

	var gm: Node = root.get_node_or_null("GameManager")
	if gm == null:
		return false
	var tick: int = int(gm.get("tick_count"))

	# Report every 250 ticks
	if tick - _last_reported_tick >= 250:
		_snapshot_metrics(tick)
		_last_reported_tick = tick

	# Check target
	if tick >= TARGET_TICKS:
		print("\n=== RESULTS ===")
		print("Reached tick %d in %d frames" % [tick, _frame_count])
		print("\nSIMULATION SURVIVED %d TICKS" % TARGET_TICKS)
		_done = true
		quit(0)
		return true

	return false


func _snapshot_metrics(tick: int) -> void:
	var pawns: int = 0
	var ps: Node = root.get_node_or_null("PawnAccess")
	if ps != null and ps.has_method("find_pawns"):
		pawns = ps.call("find_pawns").size()

	var sm: Node = root.get_node_or_null("SettlementMemory")
	var wm: Node = root.get_node_or_null("WorldMemory")
	var jm: Node = root.get_node_or_null("JobManager")

	var settlements: int = 0
	if sm != null and "settlements" in sm:
		settlements = sm.settlements.size()

	var events: int = 0
	if wm != null and wm.has_method("event_count"):
		events = int(wm.event_count())

	var jobs: int = 0
	if jm != null and jm.has_method("open_count"):
		jobs = int(jm.open_count())

	print("[LONG_RUN] tick=%d pawns=%d settlements=%d events=%d jobs_open=%d" % [
		tick, pawns, settlements, events, jobs
	])
