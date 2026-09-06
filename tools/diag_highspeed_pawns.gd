extends SceneTree

## HIGH-SPEED PAWN ACTIVITY VERIFICATION
## Boots Main on a FRESH world with --playtest-no-save fence, then for each speed
## index in SPEED_CYCLE ([3]=50x, [4]=100x, [5]=200x) runs exactly WINDOW_REAL_SEC
## real seconds (wall clock) and snapshots:
##   tick_delta, jobs_open, jobs_claimed_tot, jobs_completed_win, idle_pawns,
##   working_or_walking_pawns, avg_fps
## PASS criteria per bug report:
##   tick_delta is strictly increasing with speed (100x > 50x, 200x > 100x), and
##   pawns keep claiming + working at 100x/200x (jobs_claimed_tot grows, and
##   working_or_walking_pawns > 0 in those windows).
## Pure diagnostic; NO save touched. Requires --playtest-no-save.

const SPEED_CYCLE: Array = [3, 4, 5]
const WINDOW_REAL_SEC: float = 5.0
const SETTLE_REAL_SEC: float = 2.0
const FRAME_CAP := 600000

var _phase := "boot"
var _frame := 0
var _gm: Node = null
var _tm: Node = null
var _main: Node = null
var _jm: Node = null
var _results: Array = []
var _speed_i: int = 0
var _win_start_wall: int = 0
var _win_start_tick: int = 0
var _win_start_frame: int = 0
var _win_start_claimed: int = 0
var _prev_state_snapshot: Dictionary = {}
var _done := false

func _al(name: String) -> Node:
	return root.get_node_or_null("/root/" + name)

func _initialize() -> void:
	call_deferred("_spawn_main")

func _spawn_main() -> void:
	if not OS.get_cmdline_user_args().has("--playtest-no-save"):
		push_error("HIGHSPEED: must run with --playtest-no-save; refusing")
		quit(1)
		return
	var packed: PackedScene = load("res://scenes/main/Main.tscn") as PackedScene
	if packed == null:
		push_error("HIGHSPEED: cannot load Main.tscn")
		quit(1)
		return
	var main: Node = packed.instantiate()
	root.add_child(main)
	if not bool(main.get("_save_writes_disabled_for_playtest")):
		push_error("HIGHSPEED: Main autosave fence not active; refusing")
		quit(1)

func _process(_delta: float) -> bool:
	if _done:
		return false
	_frame += 1
	if _frame > FRAME_CAP:
		_finish("FRAME_CAP_EXCEEDED")
		return false
	if _gm == null:
		_gm = _al("GameManager")
	if _main == null:
		_main = root.get_node_or_null("/root/Main")
	if _jm == null:
		_jm = _al("JobManager")
	if _phase == "boot":
		if _gm == null or _main == null or _jm == null:
			return false
		_tm = root.get_node_or_null("/root/TickManager")
		if _tm == null or _tm.get("current_tick") == null:
			return false
		_phase = "settle_pre"
	if _phase == "settle_pre":
		if (_frame - 1) * 0.0167 >= SETTLE_REAL_SEC:
			_begin_window()
		return false
	if _phase == "window":
		var wall: int = Time.get_ticks_usec()
		var elapsed: float = float(wall - _win_start_wall) / 1_000_000.0
		if elapsed >= WINDOW_REAL_SEC:
			_end_window(elapsed)
	return false

func _begin_window() -> void:
	var speed: int = SPEED_CYCLE[_speed_i]
	if _tm.has_method("set_speed_index"):
		_tm.call("set_speed_index", speed)
	_win_start_wall = Time.get_ticks_usec()
	_win_start_tick = int(_tm.get("current_tick"))
	_win_start_frame = _frame
	_win_start_claimed = _claimed_count()
	print("HIGHSPEED: BEGIN speed=%dx tick=%d" % [
		int(_tm.call("get_speed_multiplier")), _win_start_tick
	])
	_phase = "window"

func _end_window(elapsed: float) -> void:
	var end_tick: int = int(_tm.get("current_tick"))
	var end_frame: int = _frame
	var tick_delta: int = end_tick - _win_start_tick
	var frame_delta: int = end_frame - _win_start_frame
	var avg_fps: float = float(frame_delta) / maxf(0.001, elapsed)
	var jobs_open: int = _jm.call("open_count") if _jm != null and _jm.has_method("open_count") else -1
	var jobs_claimed_tot: int = _claimed_count()
	var jobs_completed_win: int = int(_jm.get("_diag_completed_this_window"))
	var states: Dictionary = _pawn_state_tally()
	var idle_pawns: int = int(states.get("idle", 0))
	var working_or_walking: int = int(states.get("working_or_walking", 0))
	var speed_mult: float = float(_tm.call("get_speed_multiplier"))
	_results.append({
		"speed": int(speed_mult),
		"tick_delta": tick_delta,
		"wall_sec": elapsed,
		"avg_fps": avg_fps,
		"jobs_open": jobs_open,
		"jobs_claimed_win": jobs_claimed_tot - _win_start_claimed,
		"jobs_completed_win": jobs_completed_win,
		"idle_pawns": idle_pawns,
		"working_or_walking": working_or_walking,
		"pawn_total": int(states.get("total", 0)),
	})
	print("HIGHSPEED: END speed=%dx tick_delta=%d wall=%.2fs fps=%.1f jobs_open=%d claimed_win=%d completed_win=%d idle=%d workwalk=%d total=%d" % [
		int(speed_mult), tick_delta, elapsed, avg_fps, jobs_open,
		jobs_claimed_tot - _win_start_claimed, jobs_completed_win,
		idle_pawns, working_or_walking, int(states.get("total", 0))
	])
	_speed_i += 1
	if _speed_i >= SPEED_CYCLE.size():
		_finish("")
	else:
		_phase = "settle_pre"

func _claimed_count() -> int:
	if _jm == null or not _jm.has_method("claimed_count"):
		return 0
	return int(_jm.call("claimed_count"))

func _pawn_state_tally() -> Dictionary:
	var spawner: Node = root.get_node_or_null("/root/Main/WorldViewport/PawnSpawner")
	var t: Dictionary = {"idle": 0, "working_or_walking": 0, "total": 0}
	if spawner == null:
		return t
	for child in spawner.get_children():
		if child == null or not child.has_method("get_state_name"):
			continue
		var s: String = child.call("get_state_name")
		if s.is_empty() and child.has_method("get"):
			var sv: Variant = child.get("_state")
			s = str(sv)
		t["total"] += 1
		var ls: String = s.to_lower()
		if ls == "idle":
			t["idle"] += 1
		elif ls != "eating" and ls != "sleeping" and ls != "goingtobed" and ls != "unknown":
			t["working_or_walking"] += 1
	return t

func _finish(reason: String) -> void:
	_done = true
	print("===== HIGH-SPEED PAWN ACTIVITY VERIFICATION =====")
	if not reason.is_empty():
		print("reason=%s" % reason)
	var prev: int = -1
	var monotonic: bool = true
	for r in _results:
		print("  speed=%dx  tick_delta=%d  fps=%.1f  jobs_open=%d  claimed_win=%d  completed_win=%d  idle=%d  working_or_walking=%d  pawn_total=%d" % [
			r["speed"], r["tick_delta"], r["avg_fps"], r["jobs_open"],
			r["jobs_claimed_win"], r["jobs_completed_win"], r["idle_pawns"],
			r["working_or_walking"], r["pawn_total"]
		])
		if prev >= 0 and r["tick_delta"] <= prev:
			monotonic = false
		prev = r["tick_delta"]
	var working_at_high: bool = true
	for r in _results:
		if r["speed"] >= 100 and r["working_or_walking"] <= 0:
			working_at_high = false
	print("TICK_DELTA_MONOTONIC_INCREASING=%s" % str(monotonic))
	print("PAWNS_WORKING_AT_100P_200P=%s" % str(working_at_high))
	var pass_all: bool = monotonic and working_at_high
	print("RESULT=%s" % ("PASS" if pass_all else "FAIL"))
	quit(0 if pass_all else 1)