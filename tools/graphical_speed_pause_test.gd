extends SceneTree

## Graphical speed/pause test: 1x -> 200x -> 1x -> pause -> quit
## Measures FPS, node counts, transient counts at each phase.
## Requires --playtest-no-save.

const WARMUP_TICKS := 500
const MEASURE_TICKS := 200
const TOTAL_TICKS := WARMUP_TICKS + MEASURE_TICKS

var _phase := "boot"
var _frame := 0
var _printed := false
var _gm: Node = null
var _main: Node = null
var _hk: Node = null
var _tp: Node = null

# Per-window measurements
var _w1: Dictionary = {}  # 1x
var _w2: Dictionary = {}  # 200x
var _w3: Dictionary = {}  # 1x return
var _w4: Dictionary = {}  # pause
var _pause_start_tick: int = -1

func _init_window_data() -> Dictionary:
	return {
		"start_tick": -1,
		"end_tick": -1,
		"start_wall_usec": 0,
		"end_wall_usec": 0,
		"frame_count": 0,
		"engine_fps_samples": [],
		"node_count": 0,
		"transient_count": 0,
		"pawn_count": 0,
		"pawn_working": false,
		"pawn_eating": false,
		"pawn_sleeping": false,
	}

func _al(name: String) -> Node:
	return root.get_node_or_null("/root/" + name)

func _initialize() -> void:
	call_deferred("_spawn_main")

func _spawn_main() -> void:
	if not OS.get_cmdline_user_args().has("--playtest-no-save"):
		push_error("SPEED_PAUSE_TEST: must run with --playtest-no-save; refusing")
		quit(1)
		return
	var packed: PackedScene = load("res://scenes/main/Main.tscn") as PackedScene
	if packed == null:
		push_error("SPEED_PAUSE_TEST: cannot load Main.tscn")
		quit(1)
		return
	var main: Node = packed.instantiate()
	root.add_child(main)
	_hk = main.get_node_or_null("PawnSpawner")
	_main = main
	_tp = root.get_node_or_null("/root/TickManager")
	_gm = root.get_node_or_null("/root/GameManager")
	_phase = "boot"
	_frame = 0

func _process(_delta: float) -> bool:
	if _printed:
		return false
	_frame += 1
	if _frame > 3000:
		_printed = true
		_finish()
		return false

	if _phase == "boot":
		if _gm == null or _main == null or _hk == null or _tp == null:
			return false
		_phase = "1x_warmup"
		print("SPEED_PAUSE_TEST: boot complete, starting 1x warmup")

	elif _phase == "1x_warmup":
		var tick: int = int(_tp.get("current_tick"))
		if tick >= WARMUP_TICKS:
			_enter_1x_measure(tick)
		return false

	elif _phase == "1x_measure":
		_accumulate(_w1, int(_tp.get("current_tick")))
		if int(_tp.get("current_tick")) >= WARMUP_TICKS + MEASURE_TICKS:
			_exit_1x_measure(int(_tp.get("current_tick")))
			_phase = "200x_transition"
			print("SPEED_PAUSE_TEST: 1x measurement complete, transitioning to 200x")
		return false

	elif _phase == "200x_transition":
		# Switch to 200x
		if _tp.has_method("set_speed_index"):
			_tp.call("set_speed_index", 5)
		_phase = "200x_warmup"
		print("SPEED_PAUSE_TEST: starting 200x warmup")
		return false

	elif _phase == "200x_warmup":
		var tick: int = int(_tp.get("current_tick"))
		if tick >= WARMUP_TICKS + MEASURE_TICKS:
			_enter_200x_measure(tick)
		return false

	elif _phase == "200x_measure":
		_accumulate(_w2, int(_tp.get("current_tick")))
		if int(_tp.get("current_tick")) >= WARMUP_TICKS + MEASURE_TICKS * 2:
			_exit_200x_measure(int(_tp.get("current_tick")))
			_phase = "1x_return"
			print("SPEED_PAUSE_TEST: 200x measurement complete, returning to 1x")
		return false

	elif _phase == "1x_return":
		_enter_1x_return_measure(int(_tp.get("current_tick")))
		if int(_tp.get("current_tick")) >= WARMUP_TICKS + MEASURE_TICKS * 2 + MEASURE_TICKS:
			_exit_1x_return_measure(int(_tp.get("current_tick")))
			_phase = "pause_phase"
			print("SPEED_PAUSE_TEST: 1x return measurement complete, entering pause")
		return false

	elif _phase == "pause_phase":
		# Pause the game
		if _gm != null and _gm.has_method("pause"):
			_gm.call("pause")
		_pause_start_tick = int(_tp.get("current_tick"))
		_phase = "pause_measure"
		print("SPEED_PAUSE_TEST: pause phase started")
		return false

	elif _phase == "pause_measure":
		var tick: int = int(_tp.get("current_tick"))
		_accumulate_pause(_w4, tick)
		# Check if enough ticks have passed (pause should be sustained)
		if tick >= _pause_start_tick + 300:  # 300 ticks at whatever speed
			_exit_pause_measure(tick)
			_phase = "quit"
			print("SPEED_PAUSE_TEST: pause measurement complete, quitting")
		return false

	elif _phase == "quit":
		quit(0)
		return false

	return false

func _enter_1x_measure(tick: int) -> void:
	_w1 = _init_window_data()
	_w1["start_tick"] = tick
	_w1["start_wall_usec"] = Time.get_ticks_usec()
	print("SPEED_PAUSE_TEST: 1x MEASUREMENT WINDOW start")

func _enter_200x_measure(tick: int) -> void:
	_w2 = _init_window_data()
	_w2["start_tick"] = tick
	_w2["start_wall_usec"] = Time.get_ticks_usec()
	print("SPEED_PAUSE_TEST: 200x MEASUREMENT WINDOW start")

func _enter_1x_return_measure(tick: int) -> void:
	_w3 = _init_window_data()
	_w3["start_tick"] = tick
	_w3["start_wall_usec"] = Time.get_ticks_usec()
	print("SPEED_PAUSE_TEST: 1x RETURN MEASUREMENT WINDOW start")

func _accumulate(w: Dictionary, tick: int) -> void:
	w["frame_count"] += 1
	# Engine FPS
	var fps: float = Engine.get_frames_per_second()
	if fps > 0:
		w["engine_fps_samples"].append(fps)
		if w["engine_fps_samples"].size() > 60:
			w["engine_fps_samples"].remove_at(0)
	# Node counts
	var spawner: Node = root.get_node_or_null("WorldViewport/PawnSpawner")
	if spawner != null:
		w["pawn_count"] = spawner.get_child_count()
		# Count transient/particle nodes
		var transient_nodes: int = 0
		for child in spawner.get_children():
			if child != null:
				var name: String = child.name
				if name != null:
					if name.begins_with("EvtParticle") or name.begins_with("_footstep_particles") or name.begins_with("bubble") or name.begins_with("Notification"):
						transient_nodes += 1
		w["transient_count"] = transient_nodes
		# Count working pawns
		var working_count: int = 0
		for child in spawner.get_children():
			if child != null and child.has_method("get_state_name"):
				var state: String = child.call("get_state_name")
				if state == "Working":
					working_count += 1
		w["pawn_working"] = (working_count > 0)
	# Print summary every 50 ticks
	if tick % 50 == 0:
		var fps_samples: Array = w["engine_fps_samples"]
		var avg_fps: float = 0.0
		if fps_samples.size() > 0:
			avg_fps = _calc_avg_fps(fps_samples)
		print("SPEED_PAUSE_TEST: %s tick=%d frame_count=%d avg_fps=%.1f pawns=%d transients=%d working=%s" % [
			_phase, tick, w["frame_count"], avg_fps, w["pawn_count"], w["transient_count"], str(w["pawn_working"])
		])

func _exit_1x_measure(tick: int) -> void:
	_w1["end_tick"] = tick
	_w1["end_wall_usec"] = Time.get_ticks_usec()
	var wall_sec: float = float(_w1["end_wall_usec"] - _w1["start_wall_usec"]) / 1_000_000.0
	var avg_fps: float = 0.0
	var fps_samples: Array = _w1["engine_fps_samples"]
	if fps_samples.size() > 0:
		avg_fps = _calc_avg_fps(fps_samples)
	print("SPEED_PAUSE_TEST: 1x MEASUREMENT WINDOW end (elapsed_wall=%.2fs frames=%d avg_fps=%.1f)" % [wall_sec, _w1["frame_count"], avg_fps])

func _exit_200x_measure(tick: int) -> void:
	_w2["end_tick"] = tick
	_w2["end_wall_usec"] = Time.get_ticks_usec()
	var wall_sec: float = float(_w2["end_wall_usec"] - _w2["start_wall_usec"]) / 1_000_000.0
	var avg_fps: float = 0.0
	var fps_samples: Array = _w2["engine_fps_samples"]
	if fps_samples.size() > 0:
		avg_fps = _calc_avg_fps(fps_samples)
	print("SPEED_PAUSE_TEST: 200x MEASUREMENT WINDOW end (elapsed_wall=%.2fs frames=%d avg_fps=%.1f)" % [wall_sec, _w2["frame_count"], avg_fps])

func _accumulate_pause(w: Dictionary, tick: int) -> void:
	w["frame_count"] += 1
	var fps: float = Engine.get_frames_per_second()
	if fps > 0:
		w["engine_fps_samples"].append(fps)
		if w["engine_fps_samples"].size() > 60:
			w["engine_fps_samples"].remove_at(0)
	var spawner: Node = root.get_node_or_null("WorldViewport/PawnSpawner")
	if spawner != null:
		w["pawn_count"] = spawner.get_child_count()
		var transient_nodes: int = 0
		for child in spawner.get_children():
			if child != null:
				var name: String = child.name
				if name != null:
					if name.begins_with("EvtParticle") or name.begins_with("_footstep_particles") or name.begins_with("bubble") or name.begins_with("Notification"):
						transient_nodes += 1
		w["transient_count"] = transient_nodes
	if tick % 30 == 0:
		var fps_samples: Array = w["engine_fps_samples"]
		var avg_fps: float = 0.0
		if fps_samples.size() > 0:
			avg_fps = _calc_avg_fps(fps_samples)
		print("SPEED_PAUSE_TEST: pause tick=%d frame_count=%d avg_fps=%.1f transients=%d pawns=%d" % [
			tick, w["frame_count"], avg_fps, w["transient_count"], w["pawn_count"]
		])

func _exit_1x_return_measure(tick: int) -> void:
	_w3["end_tick"] = tick
	_w3["end_wall_usec"] = Time.get_ticks_usec()
	var wall_sec: float = float(_w3["end_wall_usec"] - _w3["start_wall_usec"]) / 1_000_000.0
	var avg_fps: float = 0.0
	var fps_samples: Array = _w3["engine_fps_samples"]
	if fps_samples.size() > 0:
		avg_fps = _calc_avg_fps(fps_samples)
	print("SPEED_PAUSE_TEST: 1x RETURN MEASUREMENT WINDOW end (elapsed_wall=%.2fs frames=%d avg_fps=%.1f)" % [wall_sec, _w3["frame_count"], avg_fps])

func _exit_pause_measure(tick: int) -> void:
	_w4["end_tick"] = tick
	_w4["end_wall_usec"] = Time.get_ticks_usec()
	var wall_sec: float = float(_w4["end_wall_usec"] - _w4["start_wall_usec"]) / 1_000_000.0
	var avg_fps: float = 0.0
	var fps_samples: Array = _w4["engine_fps_samples"]
	if fps_samples.size() > 0:
		avg_fps = _calc_avg_fps(fps_samples)
	print("SPEED_PAUSE_TEST: PAUSE MEASUREMENT WINDOW end (elapsed_wall=%.2fs frames=%d avg_fps=%.1f)" % [wall_sec, _w4["frame_count"], avg_fps])

func _finish() -> void:
	print("===== SPEED_PAUSE_TEST RESULT =====")
	print("1x: frames=%d avg_fps=%.1f transients=%d pawns=%d" % [
		_w1["frame_count"], _calc_avg_fps(_w1["engine_fps_samples"]), _w1["transient_count"], _w1["pawn_count"]
	])
	print("200x: frames=%d avg_fps=%.1f transients=%d pawns=%d" % [
		_w2["frame_count"], _calc_avg_fps(_w2["engine_fps_samples"]), _w2["transient_count"], _w2["pawn_count"]
	])
	print("1x return: frames=%d avg_fps=%.1f transients=%d pawns=%d" % [
		_w3["frame_count"], _calc_avg_fps(_w3["engine_fps_samples"]), _w3["transient_count"], _w3["pawn_count"]
	])
	print("pause: frames=%d avg_fps=%.1f transients=%d pawns=%d" % [
		_w4["frame_count"], _calc_avg_fps(_w4["engine_fps_samples"]), _w4["transient_count"], _w4["pawn_count"]
	])
	# Check key success criteria
	var ok: bool = true
	# 1x must have reasonable FPS
	var w1_avg: float = _calc_avg_fps(_w1["engine_fps_samples"])
	if w1_avg < 10.0: ok = false
	# 200x must have reasonable FPS (may be lower but not collapse)
	var w2_avg: float = _calc_avg_fps(_w2["engine_fps_samples"])
	if w2_avg < 5.0: ok = false
	# Pause must restore FPS (pause phase avg should be measured)
	print("RESULT: ok=%s" % str(ok))
	quit(0 if ok else 1)

func _calc_avg_fps(samples: Array) -> float:
	if samples.size() == 0: return 0.0
	var total: float = 0.0
	for s in samples:
		total += float(s)
	return total / float(samples.size())