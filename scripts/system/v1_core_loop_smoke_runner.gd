extends SceneTree

const MAIN_SCENE_PATH: String = "res://scenes/main/Main.tscn"
const SAVE_SMOKE_PATH: String = "user://v1_core_loop_smoke.sav"
const BOOT_TIMEOUT_MS: int = 30000
const PROGRESS_TIMEOUT_MS: int = 45000
const SETTLE_TICKS: int = 12
const PROGRESS_TICKS: int = 260
const ITEM_WOOD: int = 3
const CONSTRUCTION_JOB_TYPES: Array[int] = [
	5, 6, 7, 15, 16, 17, 18, 22, 23, 24, 26, 27, 28, 29, 30, 33,
	35, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50,
	51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 62, 63, 66,
]

var _main: Node = null
var _gm: Node = null
var _tick_manager: Node = null
var _job_manager: Node = null
var _stockpile_manager: Node = null
var _phase: String = "boot"
var _phase_start_ms: int = 0
var _start_tick: int = 0
var _boot_checked: bool = false
var _job_claims: int = 0
var _job_completions: int = 0
var _max_job_progress_seen: int = 0
var _construction_seen: bool = false
var _construction_progressed: bool = false
var _construction_completed: bool = false
var _failures: PackedStringArray = PackedStringArray()
var _stockpile_added_wood: int = 0
var _stockpile_taken_wood: int = 0
var _save_load_result: Dictionary = {}


func _initialize() -> void:
	_phase_start_ms = Time.get_ticks_msec()
	_gm = root.get_node_or_null("GameManager")
	_tick_manager = root.get_node_or_null("TickManager")
	_job_manager = root.get_node_or_null("JobManager")
	_stockpile_manager = root.get_node_or_null("StockpileManager")
	if _gm != null and _gm.has_method("set_tick_benchmark_enabled"):
		_gm.call("set_tick_benchmark_enabled", true)
	var packed: PackedScene = load(MAIN_SCENE_PATH) as PackedScene
	if packed == null:
		_fail("boot", "Main.tscn failed to load")
		return
	_main = packed.instantiate()
	root.add_child(_main)
	if _job_manager != null:
		if _job_manager.has_signal("job_claimed"):
			_job_manager.connect("job_claimed", Callable(self, "_on_job_claimed"))
		if _job_manager.has_signal("job_completed"):
			_job_manager.connect("job_completed", Callable(self, "_on_job_completed"))
	print("[V1Smoke] start")


func _process(_delta: float) -> bool:
	if _phase == "done":
		return false
	if _phase == "failed":
		_finish()
		return true
	var now_ms: int = Time.get_ticks_msec()
	var timeout_ms: int = BOOT_TIMEOUT_MS if _phase == "boot" else PROGRESS_TIMEOUT_MS
	if now_ms - _phase_start_ms > timeout_ms:
		_fail(_phase, "timeout_ms=%d" % timeout_ms)
		return true
	var tick: int = _current_tick()
	match _phase:
		"boot":
			if tick >= SETTLE_TICKS:
				_run_boot_checks()
				_start_progress_phase(tick)
		"progress":
			_sample_job_progress()
			if tick >= _start_tick + PROGRESS_TICKS:
				_run_progress_checks()
				_run_stockpile_checks()
				_run_save_load_checks()
				_finish()
				return true
	return false


func _current_tick() -> int:
	return int(_gm.get("tick_count")) if _gm != null else 0


func _run_boot_checks() -> void:
	if _boot_checked:
		return
	_boot_checked = true
	var world: Node = _world()
	var pawn_spawner: Node = _pawn_spawner()
	var pawn_count: int = _pawn_count()
	var ok: bool = (
			_main != null
			and is_instance_valid(_main)
			and world != null
			and pawn_spawner != null
			and pawn_count > 0
			and _stockpile_manager != null
			and _job_manager != null
			and _tick_manager != null
	)
	if ok:
		print("[V1Smoke] boot PASS main=true world=true pawn_spawner=true stockpile_manager=true job_manager=true tick_manager=true")
		print("[V1Smoke] pawns PASS count=%d" % pawn_count)
	else:
		_fail("boot", "main/world/pawn_spawner/pawns/managers missing pawn_count=%d" % pawn_count)


func _start_progress_phase(tick: int) -> void:
	_set_sim_speed(100.0)
	_phase = "progress"
	_phase_start_ms = Time.get_ticks_msec()
	_start_tick = tick
	_sample_job_progress()


func _set_sim_speed(speed: float) -> void:
	if _gm != null and _gm.has_method("set_speed"):
		_gm.call("set_speed", speed)
	if _tick_manager != null and _tick_manager.has_method("set_speed"):
		_tick_manager.call("set_speed", speed)


func _run_progress_checks() -> void:
	_sample_job_progress()
	var open_count: int = int(_job_manager.call("open_count")) if _job_manager != null and _job_manager.has_method("open_count") else 0
	var claimed_count: int = int(_job_manager.call("claimed_count")) if _job_manager != null and _job_manager.has_method("claimed_count") else 0
	var posted_count: int = int(_job_manager.get("posted_count")) if _job_manager != null else 0
	var completed_count: int = int(_job_manager.get("completed_count")) if _job_manager != null else 0
	var job_ok: bool = posted_count > 0 and (_job_claims > 0 or claimed_count > 0) and (_max_job_progress_seen > 0 or _job_completions > 0 or completed_count > 0)
	if job_ok:
		print("[V1Smoke] jobs PASS posted=%d open=%d claimed=%d claim_events=%d completed_events=%d max_progress=%d" % [
			posted_count, open_count, claimed_count, _job_claims, _job_completions, _max_job_progress_seen,
		])
	else:
		_fail("jobs", "posted=%d open=%d claimed=%d claim_events=%d completed_events=%d max_progress=%d" % [
			posted_count, open_count, claimed_count, _job_claims, _job_completions, _max_job_progress_seen,
		])
	var construction_ok: bool = _construction_seen
	if construction_ok:
		print("[V1Smoke] construction PASS seen=true progressed=%s completed=%s" % [
			str(_construction_progressed), str(_construction_completed),
		])
	else:
		_fail("construction", "no construction job observed")


func _run_stockpile_checks() -> void:
	var zones: Array = _stockpile_zones()
	if zones.is_empty():
		_fail("stockpile", "no stockpile zones")
		return
	var sp: Node = zones[0] as Node
	var before_manual: int = _manual_stockpile_total(ITEM_WOOD)
	var before_cached: int = int(_stockpile_manager.call("total_count_of", ITEM_WOOD))
	if before_manual != before_cached:
		_fail("stockpile", "wood mismatch before manual=%d cached=%d" % [before_manual, before_cached])
		return
	sp.call("add_item", ITEM_WOOD, 7)
	_stockpile_added_wood = 7
	var after_add_manual: int = _manual_stockpile_total(ITEM_WOOD)
	var after_add_cached: int = int(_stockpile_manager.call("total_count_of", ITEM_WOOD))
	if after_add_manual != after_add_cached or after_add_manual != before_manual + 7:
		_fail("stockpile", "wood mismatch after_add manual=%d cached=%d expected=%d" % [after_add_manual, after_add_cached, before_manual + 7])
		return
	_stockpile_taken_wood = int(sp.call("take_item", ITEM_WOOD, 3))
	var after_take_manual: int = _manual_stockpile_total(ITEM_WOOD)
	var after_take_cached: int = int(_stockpile_manager.call("total_count_of", ITEM_WOOD))
	if _stockpile_taken_wood != 3 or after_take_manual != after_take_cached or after_take_manual != before_manual + 4:
		_fail("stockpile", "wood mismatch after_take taken=%d manual=%d cached=%d expected=%d" % [_stockpile_taken_wood, after_take_manual, after_take_cached, before_manual + 4])
		return
	var food_manual: int = _manual_stockpile_food()
	var food_cached: int = int(_stockpile_manager.call("total_food"))
	if food_manual != food_cached:
		_fail("stockpile", "food mismatch manual=%d cached=%d" % [food_manual, food_cached])
		return
	print("[V1Smoke] stockpile PASS manual_wood=%d cached_wood=%d manual_food=%d cached_food=%d added_wood=%d taken_wood=%d" % [
		after_take_manual, after_take_cached, food_manual, food_cached, _stockpile_added_wood, _stockpile_taken_wood,
	])


func _run_save_load_checks() -> void:
	if _main == null or not is_instance_valid(_main):
		_fail("save_load", "main invalid")
		return
	if not _main.has_method("_build_save_dict") or not _main.has_method("_apply_save_dict"):
		_fail("save_load", "main save/load methods missing")
		return
	var before_tick: int = _current_tick()
	var before_pawns: Array = _pawns()
	if before_pawns.is_empty():
		_fail("save_load", "no pawns before save")
		return
	var first_pawn: Node = before_pawns[0] as Node
	var first_data: Variant = first_pawn.get("data")
	var first_id: int = int(first_data.get("id")) if first_data != null else -1
	var first_name: String = str(first_data.get("display_name")) if first_data != null else ""
	if first_name.is_empty() and first_data != null and first_data.has_method("display_name"):
		first_name = str(first_data.call("display_name"))
	if first_name.is_empty() or first_name == "<null>":
		first_name = "pawn_%d" % first_id
	var first_tile: Vector2i = first_data.get("tile_pos") if first_data != null else Vector2i(-1, -1)
	var before_wood: int = int(_stockpile_manager.call("total_count_of", ITEM_WOOD))
	var snapshot: Dictionary = _main.call("_build_save_dict")
	if _main.has_method("verify_save_roundtrip") and not bool(_main.call("verify_save_roundtrip", snapshot)):
		_fail("save_load", "snapshot var roundtrip failed")
		return
	var err: int = int(GameSave.write_file(SAVE_SMOKE_PATH, snapshot))
	if err != OK:
		_fail("save_load", "write failed err=%d" % err)
		return
	var loaded: Dictionary = GameSave.read_file(SAVE_SMOKE_PATH)
	if loaded.is_empty():
		_fail("save_load", "read returned empty")
		return
	_main.call("_apply_save_dict", loaded)
	var after_pawns: Array = _pawns()
	var after_tick: int = _current_tick()
	var after_wood: int = int(_stockpile_manager.call("total_count_of", ITEM_WOOD))
	var found_identity: bool = false
	for p_any in after_pawns:
		var p: Node = p_any as Node
		if p == null or not is_instance_valid(p):
			continue
		var pd: Variant = p.get("data")
		if pd != null and int(pd.get("id")) == first_id:
			found_identity = true
			break
	var save_load_passed: bool = after_pawns.size() == before_pawns.size() and found_identity and after_tick == before_tick and after_wood == before_wood
	_save_load_result = {
		"before_tick": before_tick,
		"after_tick": after_tick,
		"before_pawns": before_pawns.size(),
		"after_pawns": after_pawns.size(),
		"first_id": first_id,
		"first_name": first_name,
		"first_tile": first_tile,
		"identity_found": found_identity,
		"before_wood": before_wood,
		"after_wood": after_wood,
	}
	if save_load_passed:
		print("[V1Smoke] save_load PASS tick_before=%d tick_after=%d pawn_count_before=%d pawn_count_after=%d pawn_id=%d pawn_name=\"%s\" wood_before=%d wood_after=%d" % [
			before_tick, after_tick, before_pawns.size(), after_pawns.size(), first_id, first_name, before_wood, after_wood,
		])
	else:
		_fail("save_load", JSON.stringify(_save_load_result))


func _finish() -> void:
	_phase = "done"
	if _gm != null and _gm.has_method("set_tick_benchmark_enabled"):
		_gm.call("set_tick_benchmark_enabled", false)
	var tm_summary: Dictionary = _tick_manager_summary()
	var pf_summary: Dictionary = _pathfinder_summary()
	print("[V1Smoke] counters tickables_last_frame=%d max_ticks_frame=%d backlog_hits=%d paths_max_tick=%d paths_total=%d paths_plain=%d paths_historic=%d" % [
		int(tm_summary.get("tickables_called_last_frame", 0)),
		int(tm_summary.get("max_ticks_processed_seen", 0)),
		int(tm_summary.get("backlog_protection_hits", 0)),
		int(pf_summary.get("max_paths_solved_in_tick", 0)),
		int(pf_summary.get("total_paths_solved", 0)),
		int(pf_summary.get("plain_paths_solved_total", 0)),
		int(pf_summary.get("historic_paths_solved_total", 0)),
	])
	if _failures.is_empty():
		print("[V1Smoke] overall PASS")
		quit(0)
	else:
		print("[V1Smoke] overall FAIL failures=%s" % ",".join(_failures))
		quit(1)


func _fail(check: String, reason: String) -> void:
	var msg: String = "%s:%s" % [check, reason]
	if not _failures.has(msg):
		_failures.append(msg)
	print("[V1Smoke] %s FAIL reason=\"%s\"" % [check, reason])
	_phase = "failed"


func _on_job_claimed(job: Variant, _pawn: Node) -> void:
	_job_claims += 1
	_track_construction_job(job)


func _on_job_completed(job: Variant) -> void:
	_job_completions += 1
	_track_construction_job(job)
	if _is_construction_job(job):
		_construction_completed = true


func _sample_job_progress() -> void:
	if _job_manager == null or not _job_manager.has_method("get_active_jobs_union"):
		return
	var jobs: Array = _job_manager.call("get_active_jobs_union")
	for job_any in jobs:
		if job_any == null:
			continue
		_track_construction_job(job_any)
		var progress: int = int(job_any.get("work_ticks_done"))
		if progress > _max_job_progress_seen:
			_max_job_progress_seen = progress
		if _is_construction_job(job_any) and progress > 0:
			_construction_progressed = true


func _track_construction_job(job: Variant) -> void:
	if _is_construction_job(job):
		_construction_seen = true


func _is_construction_job(job: Variant) -> bool:
	if job == null:
		return false
	return CONSTRUCTION_JOB_TYPES.has(int(job.get("type")))


func _world() -> Node:
	if _main == null or not is_instance_valid(_main):
		return null
	return _main.get_node_or_null("WorldViewport/World")


func _pawn_spawner() -> Node:
	if _main == null or not is_instance_valid(_main):
		return null
	return _main.get_node_or_null("WorldViewport/PawnSpawner")


func _pawns() -> Array:
	var spawner: Node = _pawn_spawner()
	if spawner == null:
		return []
	if spawner.has_method("get_alive_pawns"):
		return spawner.call("get_alive_pawns")
	var raw: Variant = spawner.get("pawns")
	if raw is Array:
		return raw as Array
	return []


func _pawn_count() -> int:
	return _pawns().size()


func _stockpile_zones() -> Array:
	if _stockpile_manager == null or not _stockpile_manager.has_method("zones"):
		return []
	return _stockpile_manager.call("zones")


func _manual_stockpile_total(item_type: int) -> int:
	var total: int = 0
	for z_any in _stockpile_zones():
		var z: Node = z_any as Node
		if z == null or not is_instance_valid(z):
			continue
		total += int(z.call("count_of", item_type))
	return total


func _manual_stockpile_food() -> int:
	var total: int = 0
	for z_any in _stockpile_zones():
		var z: Node = z_any as Node
		if z == null or not is_instance_valid(z):
			continue
		total += int(z.call("count_food"))
	return total


func _tick_manager_summary() -> Dictionary:
	return {
		"ticks_processed_last_frame": int(_tick_manager.get("ticks_processed_last_frame")) if _tick_manager != null else 0,
		"tickables_called_last_frame": int(_tick_manager.get("tickables_called_last_frame")) if _tick_manager != null else 0,
		"max_ticks_processed_seen": int(_tick_manager.get("max_ticks_processed_seen")) if _tick_manager != null else 0,
		"backlog_protection_hits": int(_tick_manager.get("backlog_protection_hits")) if _tick_manager != null else 0,
	}


func _pathfinder_summary() -> Dictionary:
	var world: Node = _world()
	var pf: Object = null
	if world != null:
		var pf_v: Variant = world.get("pathfinder")
		if pf_v is Object:
			pf = pf_v as Object
	return {
		"max_paths_solved_in_tick": int(pf.get("max_paths_solved_in_tick")) if pf != null else 0,
		"total_paths_solved": int(pf.get("total_paths_solved")) if pf != null else 0,
		"plain_paths_solved_total": int(pf.get("plain_paths_solved_total")) if pf != null else 0,
		"historic_paths_solved_total": int(pf.get("historic_paths_solved_total")) if pf != null else 0,
	}
