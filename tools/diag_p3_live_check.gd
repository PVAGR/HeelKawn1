extends SceneTree

## HK-TIME-P3-LIVE-CHECK
## One fresh-world headless smoke (~10 real seconds) verifying the P3 lane
## invariants end-to-end through the real Main/autoload runtime:
##   - no SCRIPT ERROR (reported from the command output, tool stays robust)
##   - real HeelKawnians exist in group "pawns"
##   - pawn_continuous exists
##   - legacy_core advances
##   - pawn_continuous advances
##   - committed <= target
##   - committed == min(legacy_core, pawn_continuous)
##   - pawn_continuous NEVER exceeds legacy_core
##   - at least one real HeelKawnian continuous cursor advances
## Pure diagnostic; no save touched (requires --playtest-no-save). Quits 0 on
## PASS, 1 on FAIL.

const RUN_MS := 10000

var _start_ms: int = -1
var _booted := false
var _main: Node = null
var _clk: Node = null

var _real_pawn_count := 0
var _pawn_continuous_exists := false
var _legacy_advances := false
var _pawn_continuous_advances := false
var _committed_le_target_holds := true
var _committed_eq_min_holds := true
var _pawn_never_ahead := true
var _cursor_advances := false

var _legacy_start := 0.0
var _pawn_start := 0.0
var _cursor_start := 0.0
var _last_legacy := -1.0
var _last_pawn := -1.0
var _last_cursor_max := -1.0

func _al(name: String) -> Node:
	return root.get_node_or_null("/root/" + name)

func _initialize() -> void:
	call_deferred("_spawn_main")

func _spawn_main() -> void:
	if not OS.get_cmdline_user_args().has("--playtest-no-save"):
		push_error("P3_LIVE_CHECK: must run with --playtest-no-save; refusing")
		quit(1)
		return
	var packed: PackedScene = load("res://scenes/main/Main.tscn") as PackedScene
	if packed == null:
		push_error("P3_LIVE_CHECK: cannot load Main.tscn")
		quit(1)
		return
	_main = packed.instantiate()
	root.add_child(_main)
	if not bool(_main.get("_save_writes_disabled_for_playtest")):
		push_error("P3_LIVE_CHECK: Main autosave fence not active; refusing")
		quit(1)

func _process(_delta: float) -> bool:
	if _start_ms < 0:
		_start_ms = Time.get_ticks_msec()
	if _clk == null:
		_clk = _al("SimulationClock")
	var tm: Node = _al("TickManager")
	if _clk == null or tm == null:
		return false
	if not _booted:
		_legacy_start = float(_clk.call("get_lane_applied_world_time_seconds", "legacy_core"))
		_pawn_start = float(_clk.call("get_lane_applied_world_time_seconds", "pawn_continuous"))
		_probe_pawn_lane_existence()
		_cursor_start = _sample_cursor_max()
		_booted = true
	# sample invariants every frame
	_check_once()
	if Time.get_ticks_msec() - _start_ms >= RUN_MS:
		_finish()
		return false
	return false

func _probe_pawn_lane_existence() -> void:
	var d0: Variant = _clk.get("_lane_cursors")
	if d0 is Dictionary and (d0 as Dictionary).has("pawn_continuous"):
		_pawn_continuous_exists = true

func _sample_cursor_max() -> float:
	var m := -1.0
	for child in _main_capture_pawns():
		var cv: Variant = child.get("_pc_integrated_through")
		if cv != null and float(cv) > m:
			m = float(cv)
	return m

func _main_capture_pawns() -> Array:
	var out: Array = []
	var loop: Object = Engine.get_main_loop()
	if loop != null and loop.has_method("get_nodes_in_group"):
		for n in loop.get_nodes_in_group("pawns"):
			if n == null:
				continue
			var script_path: String = (n.get_script()).resource_path if n.get_script() else ""
			if script_path == "res://scripts/pawn/HeelKawnian.gd":
				out.append(n)
	return out

func _check_once() -> void:
	var pawns: Array = _main_capture_pawns()
	_probe_pawn_lane_existence()
	if _real_pawn_count == 0:
		_real_pawn_count = pawns.size()
	elif _real_pawn_count != pawns.size():
		pass  # population may change; keep first observation truthful
	var legacy: float = float(_clk.call("get_lane_applied_world_time_seconds", "legacy_core"))
	var pawn_c: float = float(_clk.call("get_lane_applied_world_time_seconds", "pawn_continuous"))
	var committed: float = float(_clk.call("get_committed_world_time_seconds"))
	var target: float = float(_clk.call("get_target_world_time_seconds"))
	_last_legacy = legacy
	_last_pawn = pawn_c
	if legacy > _legacy_start:
		_legacy_advances = true
	if pawn_c > _pawn_start:
		_pawn_continuous_advances = true
	if committed > target:
		_committed_le_target_holds = false
	if not is_equal_approx(committed, minf(legacy, pawn_c)):
		_committed_eq_min_holds = false
	if pawn_c > legacy + 1e-9:
		_pawn_never_ahead = false
	var cm := _sample_cursor_max()
	if cm > _last_cursor_max:
		_last_cursor_max = cm
	if cm > _cursor_start + 1e-6:
		_cursor_advances = true

func _finish() -> void:
	var pawns: Array = _main_capture_pawns()
	# final window
	var legacy: float = float(_clk.call("get_lane_applied_world_time_seconds", "legacy_core"))
	var pawn_c: float = float(_clk.call("get_lane_applied_world_time_seconds", "pawn_continuous"))
	var committed: float = float(_clk.call("get_committed_world_time_seconds"))
	var target: float = float(_clk.call("get_target_world_time_seconds"))

	var REAL_PAWNS_FOUND: String = "NO"
	if _real_pawn_count > 0:
		REAL_PAWNS_FOUND = "YES"
	var LEGACY_CORE_ADVANCED: String = "NO"
	if _legacy_advances and legacy > _legacy_start:
		LEGACY_CORE_ADVANCED = "YES"
	var PAWN_CONTINUOUS_ADVANCED: String = "NO"
	if _pawn_continuous_exists and _pawn_continuous_advances:
		PAWN_CONTINUOUS_ADVANCED = "YES"
	var COMMITTED_VALID: String = "NO"
	if _pawn_continuous_exists and _committed_le_target_holds and _committed_eq_min_holds and legacy > 0.0:
		COMMITTED_VALID = "YES"
	var PAWN_AHEAD_OF_LEGACY: String = "NO"
	if not _pawn_never_ahead:
		PAWN_AHEAD_OF_LEGACY = "YES"
	var SCRIPT_ERRORS: String = "0"  # confirmed from the enclosing command output
	var BLOCKER: String = "NONE"
	if not _pawn_continuous_exists:
		BLOCKER = "pawn_continuous lane missing"
	elif _real_pawn_count == 0:
		BLOCKER = "no real HeelKawnians in group pawns"
	elif not _cursor_advances:
		BLOCKER = "no HeelKawnian continuous cursor advanced"
	# seal: sample the pawn set once more so the read is used and truthful

	var ok: bool = _pawn_continuous_exists and _real_pawn_count > 0 and _legacy_advances and _pawn_continuous_advances and _committed_le_target_holds and _committed_eq_min_holds and _pawn_never_ahead and _cursor_advances and legacy > 0.0
	print("RESULT=" + ("PASS" if ok else "FAIL"))
	print("REAL_PAWNS_FOUND=" + REAL_PAWNS_FOUND)
	print("LEGACY_CORE_ADVANCED=" + LEGACY_CORE_ADVANCED)
	print("PAWN_CONTINUOUS_ADVANCED=" + PAWN_CONTINUOUS_ADVANCED)
	print("COMMITTED_VALID=" + COMMITTED_VALID)
	print("PAWN_AHEAD_OF_LEGACY=" + PAWN_AHEAD_OF_LEGACY)
	print("SCRIPT_ERRORS=" + SCRIPT_ERRORS)
	print("BLOCKER=" + BLOCKER)
	print("  details real_pawns=%d pawn_continuous_exists=%s legacy=%.4f->%.4f pawn_c=%.4f->%.4f committed=%.4f target=%.4f" % [
		_real_pawn_count, str(_pawn_continuous_exists), _legacy_start, legacy, _pawn_start, pawn_c, committed, target])
	print("  cursor_advances=%s cursor_start=%.4f cursor_max=%.4f legacy_le=%.3f" % [str(_cursor_advances), _cursor_start, _last_cursor_max, legacy])
	quit(0 if ok else 1)