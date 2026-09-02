extends SceneTree

## SHORT fresh-world pawn-dispatch profile driver.
## Boots Main, forces 200x, runs a small number of ticks, then dumps the
## current gated --profile-pawn-dispatch aggregate directly from a live pawn
## (reads the shared static _pd_agg / _pd_stage_samples mirrors on a pawn
## node). Does NOT wait for the in-game tick-2000 summary.
##
## REQUIRED: --playtest-no-save (Permanent Tool Rule — boots Main past the
## tick-6000 autosave boundary; must never write the production autosave).
## REQUIRED for profiler data: --profile-pawn-dispatch.

const RUN_TO_TICK := 300
const FRAME_CAP := 4000
const WALL_SECONDS_MAX := 85.0

var _frame := 0
var _phase := "boot"
var _printed := false
var _start_sec := 0.0

var _gm: Node = null
var _main: Node = null

func _initialize() -> void:
	_start_sec = Time.get_ticks_msec() / 1000.0
	call_deferred("_spawn_main")

func _spawn_main() -> void:
	## Permanent Tool Rule: refuse to boot Main past the autosave boundary
	## unless save writes are fenced off.
	if not OS.get_cmdline_user_args().has("--playtest-no-save"):
		push_error("PAWN_PROFILE: must run with --playtest-no-save (boots Main past tick-6000 autosave); refusing to run")
		quit(1)
		return
	if not OS.get_cmdline_user_args().has("--profile-pawn-dispatch") and not OS.get_cmdline_args().has("--profile-pawn-dispatch"):
		push_error("PAWN_PROFILE: must run with --profile-pawn-dispatch; refusing to run")
		quit(1)
		return
	var packed: PackedScene = load("res://scenes/main/Main.tscn") as PackedScene
	if packed == null:
		push_error("PAWN_PROFILE: cannot load Main.tscn")
		quit(1)
		return
	var main: Node = packed.instantiate()
	root.add_child(main)
	if not bool(main.get("_save_writes_disabled_for_playtest")):
		push_error("PAWN_PROFILE: Main autosave fence not active (Main._save_writes_disabled_for_playtest=false); refusing to run")
		quit(1)

func _process(_delta: float) -> bool:
	if _printed:
		return false
	_frame += 1
	if _frame > FRAME_CAP:
		_printed = true
		_print_short()
		quit(1)
		return false
	var now: float = Time.get_ticks_msec() / 1000.0
	if now - _start_sec > WALL_SECONDS_MAX:
		_printed = true
		print("PAWN_PROFILE: wall-time limit reached (tick=%d)" % _tick())
		_print_short()
		quit(0)
		return false
	if _gm == null:
		_gm = root.get_node_or_null("/root/GameManager")
	if _gm == null:
		return false
	if _phase == "boot":
		_main = root.get_node_or_null("/root/Main")
		if _main != null:
			_phase = "run"
			_gm.call("set_speed", 200.0)
			print("PAWN_PROFILE: Main ready, running at 200x to tick %d" % RUN_TO_TICK)
		return false
	if _phase == "run":
		if _tick() >= RUN_TO_TICK:
			_phase = "done"
			_gm.call("pause")
			var tm: Node = root.get_node_or_null("/root/TickManager")
			if tm != null and tm.has_method("pause"):
				tm.call("pause")
		return false
	if _phase == "done":
		_print_short()
		_printed = true
		quit(0)
	return false

func _tick() -> int:
	if _gm != null:
		return int(_gm.get("tick_count"))
	return -1

## Read the shared profiler aggregate off a live pawn node mirror.
func _pawn_any() -> Node:
	var spawner: Node = null
	if _main != null:
		spawner = _main.get("_pawn_spawner")
	var pawns = spawner.get("pawns") if spawner != null else null
	if pawns is Array and pawns.size() > 0:
		for p in pawns:
			if p != null:
				return p
	return null

func _pctl(sorted_desc: Array, p: float) -> int:
	if sorted_desc.is_empty():
		return 0
	var idx: int = clampi(int(floor(float(sorted_desc.size()) * p)), 0, sorted_desc.size() - 1)
	return int(sorted_desc[idx])

func _print_short() -> void:
	var now: float = Time.get_ticks_msec() / 1000.0
	var tick: int = _tick()
	print("[PAWN_PROFILE_SHORT]")
	print("tick=%d" % tick)
	print("wall_seconds=%.1f" % (now - _start_sec))
	print("pawns=%d" % (_pawn_count()))
	print("speed=%s" % (str(_gm.get("game_speed")) if _gm != null else "?"))
	var snap: Dictionary = {}
	var pawn: Node = _pawn_any()
	if pawn != null and pawn.get_script() != null:
		var scr = pawn.get_script()
		if scr.has_method("get_pd_snapshot_for_diagnostics"):
			snap = scr.call("get_pd_snapshot_for_diagnostics")
	var agg: Dictionary = snap.get("agg", {})
	var stage_samples: Dictionary = snap.get("stage_samples", {})
	var stage_max_us: Dictionary = snap.get("stage_max_us", {})
	if agg.is_empty():
		print("TOP STAGES: <no dispatch data collected yet>")
		print("percentiles=unavailable_in_short_snapshot")
	else:
		var rows: Array = []
		for st in agg:
			var e: Array = agg[st]
			rows.append([int(e[0]), str(st), int(e[1])])
		rows.sort_custom(func(a, b): return int(a[0]) > int(b[0]))
		print("TOP STAGES BY TOTAL_US:")
		for item in rows:
			var total: int = int(item[0])
			var nm: int = int(item[2])
			var st: String = str(item[1])
			var avg: int = (total / nm) if nm > 0 else 0
			var samples: Array = ([] if not stage_samples.has(st) else stage_samples[st]).duplicate()
			var mx: int = int(stage_max_us.get(st, 0))
			var p50: int = 0
			var p95: int = 0
			var p99: int = 0
			if not samples.is_empty():
				samples.sort()
				samples.reverse()
				mx = int(samples[0])
				p50 = _pctl(samples, 0.50)
				p95 = _pctl(samples, 0.95)
				p99 = _pctl(samples, 0.99)
				print("  %-24s n=%-6d total_us=%-9d avg_us=%-6d max_us=%-6d p50=%-6d p95=%-6d p99=%-6d" % [
					st, nm, total, avg, mx, p50, p95, p99])
			else:
				print("  %-24s n=%-6d total_us=%-9d avg_us=%-6d max_us=%-6d percentiles=unavailable_in_short_snapshot" % [
					st, nm, total, avg, mx])
	var pc: Dictionary = _job_counters(snap.get("job_counters", {}))
	print("JOBS:")
	print("open=%d" % int(pc.get("open_jobs_last", -1)))
	print("claimed=%d" % int(pc.get("claimed_jobs_last", -1)))
	print("claim_successes=%d" % int(pc.get("claim_successes", 0)))
	print("failed_scans=%d" % int(pc.get("no_claim_success", 0)))
	print("jobs_eligible=%s" % str(pc.get("jobs_eligible", "unavailable")))
	print("END PAWN_PROFILE_SHORT")
	var wai: Node = root.get_node_or_null("/root/WorldAI")
	if wai != null and wai.has_method("_nc_print"):
		wai.call("_nc_print")
	return

func _pawn_count() -> int:
	var spawner: Node = null
	if _main != null:
		spawner = _main.get("_pawn_spawner")
	var pawns = spawner.get("pawns") if spawner != null else null
	return pawns.size() if pawns is Array else -1

func _job_counters(static_pc: Dictionary) -> Dictionary:
	## Live JobManager is the authoritative open/claimed count.
	var jm: Node = root.get_node_or_null("/root/JobManager")
	var open_c: int = jm.open_count() if (jm != null and jm.has_method("open_count")) else -1
	var claimed_c: int = jm.claimed_count() if (jm != null and jm.has_method("claimed_count")) else -1
	## Accumulated claim counters from the snapshot.
	var pc: Dictionary = static_pc
	return {
		"open_jobs_last": open_c,
		"claimed_jobs_last": claimed_c,
		"claim_successes": int(pc.get("claim_successes", 0)),
		"no_claim_success": int(pc.get("no_claim_success", 0)),
		"jobs_eligible": str(pc.get("jobs_eligible", "unavailable")),
	}
