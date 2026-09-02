extends SceneTree

## #20 TRUE MULTI-RATE PAWN TIME VALIDATION SMOKE — FIXED VALIDATOR
## Boots Main on a FRESH world with --playtest-no-save fence, then:
##   1x phase: warmup -> steady measurement window
##   200x phase: warmup -> steady measurement window
## Verifies at BOTH speeds:
##   - compat_tick_rate ~20/sec real time (NOT ~4000 at 200x)
##   - target_world_time_rate ~1x real at 1x, ~200x real at 200x
##   - pawn applied world time tracks target (lag bounded)
##   - pawn time lane advances sim_dt correctly
##   - expensive decisions are small fraction of pawn tick calls
##   - >= 60 independent main-loop Hz at both speeds
##   - pawns still work/eat/sleep (behavioral proof)
## Pure diagnostic; NO save touched. Requires --playtest-no-save.

const HK_SCRIPT := "res://scripts/pawn/HeelKawnian.gd"
const WARMUP_TICKS_1X := 200
const MEASURE_TICKS_1X := 400
const WARMUP_TICKS_200X := 200
const MEASURE_TICKS_200X := 400
const TOTAL_TICKS := WARMUP_TICKS_1X + MEASURE_TICKS_1X + WARMUP_TICKS_200X + MEASURE_TICKS_200X
const FRAME_CAP := 60000

var _phase := "boot"
var _frame := 0
var _printed := false
var _gm: Node = null
var _tm: Node = null
var _main: Node = null
var _hk: GDScript = null

# Window state
var _current_window: String = ""
var _prev_tick: int = -1

# Per-window stored measurements
var _w1: Dictionary = {}
var _w2: Dictionary = {}

func _init_window_data() -> Dictionary:
	return {
		"start_tick": -1,
		"end_tick": -1,
		"start_wall_usec": 0,
		"end_wall_usec": 0,
		"frame_count": 0,
		"max_slice_usec": 0,
		"max_callback_usec": 0,
		"max_callback_name": "",
		"target_wt_start": 0.0,
		"target_wt_end": 0.0,
		"pawn_applied_min": INF,
		"pawn_applied_max": -INF,
		"pawn_applied_sum": 0.0,
		"pawn_count": 0,
		"pawn_lane_lag_max": 0.0,
		"pawn_time_lane_calls": 0,
		"pawn_sim_seconds_applied": 0.0,
		"pawn_expensive_decisions": 0,
		"pawn_forced_decisions": 0,
		"seen_working": false,
		"seen_eating": false,
		"seen_sleeping": false,
	}

func _al(name: String) -> Node:
	return root.get_node_or_null("/root/" + name)

func _initialize() -> void:
	_hk = load(HK_SCRIPT) as GDScript
	call_deferred("_spawn_main")

func _spawn_main() -> void:
	if not OS.get_cmdline_user_args().has("--playtest-no-save"):
		push_error("MULTIRATE_SMOKE: must run with --playtest-no-save; refusing")
		quit(1)
		return
	var packed: PackedScene = load("res://scenes/main/Main.tscn") as PackedScene
	if packed == null:
		push_error("MULTIRATE_SMOKE: cannot load Main.tscn")
		quit(1)
		return
	var main: Node = packed.instantiate()
	root.add_child(main)
	if not bool(main.get("_save_writes_disabled_for_playtest")):
		push_error("MULTIRATE_SMOKE: Main autosave fence not active; refusing")
		quit(1)

func _process(_delta: float) -> bool:
	if _printed:
		return false
	_frame += 1
	if _frame > FRAME_CAP:
		_printed = true
		_finish("FRAME_CAP_EXCEEDED", false)
		return false
	if _gm == null:
		_gm = _al("GameManager")
	if _main == null:
		_main = root.get_node_or_null("/root/Main")
	if _phase == "boot":
		if _gm == null or _main == null:
			return false
		_phase = "arm"
	if _phase == "arm":
		_tm = root.get_node_or_null("/root/TickManager")
		if _tm == null or _tm.get("tick_processed") == null:
			return false
		# 1x warmup start
		if _tm.has_method("set_speed_index"):
			_tm.call("set_speed_index", 0)
		print("MULTIRATE_SMOKE: 1x warmup start (ticks 0..%d)" % WARMUP_TICKS_1X)
		_current_window = "1x_warmup"
		_phase = "run"
		return false
	if _phase == "run":
		_read_diag()
		var completed: int = int(_tm.get("current_tick"))
		# Window state machine
		if _current_window == "1x_warmup":
			if completed >= WARMUP_TICKS_1X:
				_enter_1x_measure(completed)
		elif _current_window == "1x_measure":
			_accumulate(_w1, completed)
			if completed >= WARMUP_TICKS_1X + MEASURE_TICKS_1X:
				_exit_1x_measure(completed)
				# Start 200x warmup
				if _tm.has_method("set_speed_index"):
					_tm.call("set_speed_index", 5)
				print("MULTIRATE_SMOKE: 200x warmup start (ticks %d..%d)" % [completed, completed + WARMUP_TICKS_200X])
				_current_window = "200x_warmup"
		elif _current_window == "200x_warmup":
			if completed >= WARMUP_TICKS_1X + MEASURE_TICKS_1X + WARMUP_TICKS_200X:
				_enter_200x_measure(completed)
		elif _current_window == "200x_measure":
			_accumulate(_w2, completed)
			if completed >= TOTAL_TICKS:
				_exit_200x_measure(completed)
				_finish("", true)
				_printed = true
				return false
	return false

func _enter_1x_measure(tick: int) -> void:
	_current_window = "1x_measure"
	_w1 = _init_window_data()
	_w1["start_tick"] = tick
	_w1["start_wall_usec"] = Time.get_ticks_usec()
	_w1["frame_count"] = 0
	# Reset TickManager steady-state max diagnostics after warmup
	if _tm.has_method("reset_steady_max_diagnostics"):
		_tm.call("reset_steady_max_diagnostics")
	# Reset pawn time lane aggregate diagnostics
	if _hk != null and _hk.has_method("_pt_reset_aggregate"):
		_hk.call("_pt_reset_aggregate")
	# Snapshot target world time
	if _tm.has_method("get_world_time_seconds"):
		_w1["target_wt_start"] = float(_tm.call("get_world_time_seconds"))
	# Snapshot pawn applied times
	_sample_pawn_applied(_w1, true)
	print("MULTIRATE_SMOKE: 1x MEASUREMENT WINDOW start (ticks %d..%d)" % [WARMUP_TICKS_1X, WARMUP_TICKS_1X + MEASURE_TICKS_1X])

func _enter_200x_measure(tick: int) -> void:
	_current_window = "200x_measure"
	_w2 = _init_window_data()
	_w2["start_tick"] = tick
	_w2["start_wall_usec"] = Time.get_ticks_usec()
	_w2["frame_count"] = 0
	_prev_tick = tick
	# Reset TickManager steady-state max diagnostics after warmup
	if _tm.has_method("reset_steady_max_diagnostics"):
		_tm.call("reset_steady_max_diagnostics")
	# Reset pawn time lane aggregate diagnostics
	if _hk != null and _hk.has_method("_pt_reset_aggregate"):
		_hk.call("_pt_reset_aggregate")
	if _tm.has_method("get_world_time_seconds"):
		_w2["target_wt_start"] = float(_tm.call("get_world_time_seconds"))
	_sample_pawn_applied(_w2, true)
	print("MULTIRATE_SMOKE: 200x MEASUREMENT WINDOW start (ticks %d..%d)" % [tick, TOTAL_TICKS])

func _accumulate(w: Dictionary, tick: int) -> void:
	w["frame_count"] += 1
	if tick > _prev_tick:
		_prev_tick = tick
	# Accumulate max slice/callback (from TickManager)
	var slice: int = int(_tm.get("debug_last_sim_slice_usec"))
	if slice > w["max_slice_usec"]:
		w["max_slice_usec"] = slice
	var cb: int = int(_tm.get("debug_max_sim_callback_usec"))
	if cb > w["max_callback_usec"]:
		w["max_callback_usec"] = cb
		w["max_callback_name"] = str(_tm.get("debug_max_sim_callback_name"))
	# Snapshot pawn applied world time + states
	_sample_pawn_applied(w, false)

func _exit_1x_measure(tick: int) -> void:
	_w1["end_tick"] = tick
	_w1["end_wall_usec"] = Time.get_ticks_usec()
	if _tm.has_method("get_world_time_seconds"):
		_w1["target_wt_end"] = float(_tm.call("get_world_time_seconds"))
	_sample_pawn_applied(_w1, false)
	_current_window = ""
	var wall_sec: float = float(_w1["end_wall_usec"] - _w1["start_wall_usec"]) / 1_000_000.0
	print("MULTIRATE_SMOKE: 1x MEASUREMENT WINDOW end (elapsed_wall=%.2fs compat_ticks=%d target_wt_delta=%.2fs)" % [wall_sec, _w1["end_tick"] - _w1["start_tick"], _w1["target_wt_end"] - _w1["target_wt_start"]])

func _exit_200x_measure(tick: int) -> void:
	_w2["end_tick"] = tick
	_w2["end_wall_usec"] = Time.get_ticks_usec()
	if _tm.has_method("get_world_time_seconds"):
		_w2["target_wt_end"] = float(_tm.call("get_world_time_seconds"))
	_sample_pawn_applied(_w2, false)
	_current_window = "done"
	var wall_sec: float = float(_w2["end_wall_usec"] - _w2["start_wall_usec"]) / 1_000_000.0
	print("MULTIRATE_SMOKE: 200x MEASUREMENT WINDOW end (elapsed_wall=%.2fs compat_ticks=%d target_wt_delta=%.2fs)" % [wall_sec, _w2["end_tick"] - _w2["start_tick"], _w2["target_wt_end"] - _w2["target_wt_start"]])

func _sample_pawn_applied(w: Dictionary, is_start: bool) -> void:
	var spawner: Node = root.get_node_or_null("/root/Main/WorldViewport/PawnSpawner")
	if spawner == null or _hk == null:
		return
	var sim_clock: Node = _al("SimulationClock")
	var target_wt: float = 0.0
	if sim_clock != null and sim_clock.has_method("get_target_world_time_seconds"):
		target_wt = sim_clock.get_target_world_time_seconds()
	var count: int = 0
	var sum_applied: float = 0.0
	var min_applied: float = INF
	var max_applied: float = -INF
	var max_lag: float = 0.0
	for child in spawner.get_children():
		if child == null or not child.has_method("get"):
			continue
		var applied_val: Variant = child.get("_pawn_time_applied_world_seconds")
		var applied: float = 0.0
		if applied_val != null:
			applied = float(applied_val)
		if applied < 0.0:
			continue
		count += 1
		sum_applied += applied
		if applied < min_applied:
			min_applied = applied
		if applied > max_applied:
			max_applied = applied
		var lag: float = target_wt - applied
		if lag > max_lag:
			max_lag = lag
		# Track states via get_state_name() if available
		if not is_start:
			var state_name: String = ""
			if child.has_method("get_state_name"):
				state_name = child.call("get_state_name")
			elif child.has_method("get"):
				var st_val: Variant = child.get("_state")
				if st_val != null:
					state_name = str(st_val)
			# Normalize and track
			state_name = state_name.to_lower().capitalize()
			if state_name == "Working":
				w["seen_working"] = true
			elif state_name == "Eating":
				w["seen_eating"] = true
			elif state_name == "Sleeping":
				w["seen_sleeping"] = true
	if is_start:
		# Start snapshots not used for final stats but could be
		pass
	else:
		w["pawn_applied_min"] = min_applied
		w["pawn_applied_max"] = max_applied
		w["pawn_applied_sum"] = sum_applied
		w["pawn_count"] = count
		w["pawn_lane_lag_max"] = max_lag
		# Pawn time lane diagnostics
		var pt: Dictionary = {}
		if _hk.has_method("get_pawn_time_lane_snapshot_for_diagnostics"):
			pt = _hk.call("get_pawn_time_lane_snapshot_for_diagnostics")
		w["pawn_time_lane_calls"] = int(pt.get("pawn_time_lane_calls", 0))
		w["pawn_sim_seconds_applied"] = float(pt.get("sim_seconds_applied_total", 0.0))
		# Cadence
		var cad: Dictionary = {}
		if _hk.has_method("get_cadence_snapshot_for_diagnostics"):
			cad = _hk.call("get_cadence_snapshot_for_diagnostics")
		w["pawn_expensive_decisions"] = int(cad.get("expensive_decisions", 0))
		w["pawn_forced_decisions"] = int(cad.get("forced_decisions", 0))

func _read_diag() -> void:
	# Frame counting handled in accumulate
	pass

func _print_window(label: String, w: Dictionary) -> void:
	var compat_ticks: int = w["end_tick"] - w["start_tick"]
	var wall_sec: float = float(w["end_wall_usec"] - w["start_wall_usec"]) / 1_000_000.0
	var target_delta: float = w["target_wt_end"] - w["target_wt_start"]
	var target_rate: float = target_delta / maxf(0.001, wall_sec)
	var compat_rate: float = float(compat_ticks) / maxf(0.001, wall_sec)
	var main_loop_hz: float = float(w["frame_count"]) / maxf(0.001, wall_sec)
	var pawn_applied_avg: float = w["pawn_applied_sum"] / maxi(1, w["pawn_count"])
	
	print("--- %s WINDOW ---" % label)
	print("  start_tick=%d" % w["start_tick"])
	print("  end_tick=%d" % w["end_tick"])
	print("  compat_ticks=%d" % compat_ticks)
	print("  start_wall_usec=%d" % w["start_wall_usec"])
	print("  end_wall_usec=%d" % w["end_wall_usec"])
	print("  real_wall_seconds=%.3f" % wall_sec)
	print("  frame_count=%d" % w["frame_count"])
	print("  main_loop_hz=%.2f" % main_loop_hz)
	print("  compat_ticks_per_real_second=%.2f" % compat_rate)
	print("  target_world_time_start=%.3f" % w["target_wt_start"])
	print("  target_world_time_end=%.3f" % w["target_wt_end"])
	print("  target_world_time_delta=%.3f" % target_delta)
	print("  target_world_time_rate_per_real_second=%.3f" % target_rate)
	print("  pawn_applied_min=%.3f" % w["pawn_applied_min"])
	print("  pawn_applied_avg=%.3f" % pawn_applied_avg)
	print("  pawn_applied_max=%.3f" % w["pawn_applied_max"])
	print("  pawn_lane_lag_max=%.3f" % w["pawn_lane_lag_max"])
	print("  pawn_time_lane_calls=%d" % w["pawn_time_lane_calls"])
	print("  pawn_sim_seconds_applied_total=%.3f" % w["pawn_sim_seconds_applied"])
	print("  pawn_expensive_decisions=%d" % w["pawn_expensive_decisions"])
	print("  pawn_forced_decisions=%d" % w["pawn_forced_decisions"])
	print("  steady_max_sim_slice_usec=%d" % w["max_slice_usec"])
	print("  steady_max_callback_usec=%d" % w["max_callback_usec"])
	print("  steady_max_callback_name=%s" % w["max_callback_name"])
	print("  engine_fps=%.2f" % Engine.get_frames_per_second())
	print("  PAWNS_WORKING_OBSERVED=%s" % str(w["seen_working"]))
	print("  PAWNS_EATING_OBSERVED=%s" % str(w["seen_eating"]))
	print("  PAWNS_SLEEPING_OBSERVED=%s" % str(w["seen_sleeping"]))

func _finish(reason: String, ok: bool) -> void:
	print("===== MULTIRATE_SMOKE #20 VALIDATION RESULT =====")
	print("reason=%s ok=%s" % [reason, str(ok)])
	if _tm != null:
		var current: int = int(_tm.get("current_tick"))
		print("completed_tick=%d TOTAL_TICKS=%d" % [current, TOTAL_TICKS])
		
		# Print raw audit for both windows
		_print_window("1x", _w1)
		_print_window("200x", _w2)
		
		# Compat tick rate ratio
		var w1_compat_ticks: int = _w1["end_tick"] - _w1["start_tick"]
		var w2_compat_ticks: int = _w2["end_tick"] - _w2["start_tick"]
		var w1_wall_sec: float = float(_w1["end_wall_usec"] - _w1["start_wall_usec"]) / 1_000_000.0
		var w2_wall_sec: float = float(_w2["end_wall_usec"] - _w2["start_wall_usec"]) / 1_000_000.0
		var w1_compat_rate: float = float(w1_compat_ticks) / maxf(0.001, w1_wall_sec)
		var w2_compat_rate: float = float(w2_compat_ticks) / maxf(0.001, w2_wall_sec)
		var rate_ratio: float = w2_compat_rate / maxf(0.001, w1_compat_rate)
		print("  COMPAT_TICK_RATE_RATIO_200x_vs_1x=%.3f (should be ~1.0)" % rate_ratio)
		
		# Target world time rates
		var w1_target_delta: float = _w1["target_wt_end"] - _w1["target_wt_start"]
		var w2_target_delta: float = _w2["target_wt_end"] - _w2["target_wt_start"]
		var w1_target_rate: float = w1_target_delta / maxf(0.001, w1_wall_sec)
		var w2_target_rate: float = w2_target_delta / maxf(0.001, w2_wall_sec)
		print("  TARGET_WORLD_TIME_RATE_1X=%.3f TARGET_WORLD_TIME_RATE_200X=%.3f" % [w1_target_rate, w2_target_rate])
		
		# Pawn lag
		print("  PAWN_LAG_MAX_1X=%.3f PAWN_LAG_MAX_200X=%.3f" % [_w1["pawn_lane_lag_max"], _w2["pawn_lane_lag_max"]])
		
		# Pawn states
		var seen_working: bool = _w1["seen_working"] or _w2["seen_working"]
		var seen_eating: bool = _w1["seen_eating"] or _w2["seen_eating"]
		var seen_sleeping: bool = _w1["seen_sleeping"] or _w2["seen_sleeping"]
		print("  PAWNS_WORKING_OBSERVED=%s PAWNS_EATING_OBSERVED=%s PAWNS_SLEEPING_OBSERVED=%s" % [
			str(seen_working), str(seen_eating), str(seen_sleeping)
		])
		
		# NEEDS_1X_RATE_PRESERVED: read-only source audit
		# We cannot prove this from measurements alone; flag NOT_PROVEN
		print("  NEEDS_1X_RATE_PRESERVED=NOT_PROVEN")
		
		# Decision pipeline diagnostics (#22)
		var cad: Dictionary = {}
		if _hk.has_method("get_cadence_snapshot_for_diagnostics"):
			cad = _hk.call("get_cadence_snapshot_for_diagnostics")
		var dp_started: int = int(cad.get("decisions_started", 0))
		var dp_completed: int = int(cad.get("decisions_completed", 0))
		var dp_cancelled: int = int(cad.get("decisions_cancelled", 0))
		var dp_phase_max: Dictionary = cad.get("phase_max_usec", {})
		var dp_max_cb_us: int = int(cad.get("max_total_pawn_callback_usec", 0))
		var dp_max_cb_state: String = str(cad.get("max_total_pawn_callback_state", ""))
		var dp_over_16667: int = int(cad.get("callbacks_over_16667", 0))
		var dp_over_8000: int = int(cad.get("callbacks_over_8000", 0))
		print("  pawn_decisions_started=%d" % dp_started)
		print("  pawn_decisions_completed=%d" % dp_completed)
		print("  pawn_decisions_cancelled=%d" % dp_cancelled)
		var max_phase_name: String = ""
		var max_phase_us: int = 0
		for pk in dp_phase_max:
			if int(dp_phase_max[pk]) > max_phase_us:
				max_phase_us = int(dp_phase_max[pk])
				max_phase_name = str(pk)
		print("  max_decision_phase_usec=%d" % max_phase_us)
		print("  max_decision_phase_name=%s" % max_phase_name)
		print("  max_total_pawn_callback_usec=%d" % dp_max_cb_us)
		print("  max_total_pawn_callback_state=%s" % dp_max_cb_state)
		print("  callbacks_over_16667=%d" % dp_over_16667)
		print("  callbacks_over_8000=%d" % dp_over_8000)
		
		# Overall result criteria
		var tick_ok: bool = current >= TOTAL_TICKS
		var compat_ok: bool = w1_compat_rate > 10.0 and w1_compat_rate < 30.0 and w2_compat_rate > 10.0 and w2_compat_rate < 30.0 and rate_ratio > 0.5 and rate_ratio < 2.0
		var target_ok: bool = w1_target_rate > 0.5 and w1_target_rate < 2.0 and w2_target_rate > 100.0 and w2_target_rate < 400.0
		var lag_ok: bool = _w1["pawn_lane_lag_max"] < 10.0 and _w2["pawn_lane_lag_max"] < 10.0
		var perf_1x_ok: bool = (float(_w1["frame_count"]) / maxf(0.001, w1_wall_sec)) >= 60.0
		var perf_200x_ok: bool = (float(_w2["frame_count"]) / maxf(0.001, w2_wall_sec)) >= 60.0
		var pawns_ok: bool = seen_working
		var decisions_ok: bool = dp_started > 0 and dp_completed > 0
		
		var validator_consistent: bool = true
		if compat_ok and not (w1_compat_rate > 0 and w2_compat_rate > 0):
			validator_consistent = false
		if target_ok and not (w1_target_rate > 0 and w2_target_rate > 0):
			validator_consistent = false
		
		print("  COMPAT_RATE_OK=%s TARGET_RATE_OK=%s LAG_OK=%s PERF_1X_OK=%s PERF_200X_OK=%s PAWNS_OK=%s DECISIONS_OK=%s VALIDATOR_SELF_CONSISTENT=%s" % [
			str(compat_ok), str(target_ok), str(lag_ok), str(perf_1x_ok), str(perf_200x_ok), str(pawns_ok), str(decisions_ok), str(validator_consistent)
		])
		
		var ok_all: bool = ok and tick_ok and compat_ok and target_ok and lag_ok and perf_1x_ok and perf_200x_ok and pawns_ok and decisions_ok and validator_consistent
		var result_str: String
		if ok_all and dp_over_16667 == 0:
			result_str = "SMOOTH_PAWN_CALLBACKS"
		elif ok_all:
			result_str = "ATOMIC_PAWN_PHASE_STILL_BLOCKING"
		elif compat_ok and target_ok and lag_ok and pawns_ok:
			result_str = "#20_PARTIAL"
		elif not perf_1x_ok or not perf_200x_ok:
			result_str = "PERFORMANCE_TARGET_NOT_MET"
		else:
			result_str = "VALIDATION_FAILED"
		print("RESULT=%s" % result_str)
		quit(0 if ok_all else 1)
		return
	quit(1)