extends SceneTree

const MAIN_SCENE_PATH: String = "res://scenes/main/Main.tscn"
const YEAR_TICKS: int = SimTime.TICKS_PER_SIM_YEAR
const MID_YEAR_TICK: int = YEAR_TICKS / 2
const TARGET_SPEED: float = 500.0
const TIMEOUT_FRAMES: int = 240000
const REPORT_PATH: String = "res://logs/year1_visible_growth_smoke_report.json"

const BUILD_JOB_TYPES: Array[int] = [
	Job.Type.BUILD_BED,
	Job.Type.BUILD_WALL,
	Job.Type.BUILD_DOOR,
	Job.Type.BUILD_FIRE_PIT,
	Job.Type.BUILD_STORAGE_HUT,
	Job.Type.BUILD_STOCKPILE,
	Job.Type.BUILD_MARKER_STONE,
	Job.Type.BUILD_SHRINE,
	Job.Type.BUILD_SHELTER,
	Job.Type.BUILD_HEARTH,
	Job.Type.BUILD_FARM_WHEAT,
	Job.Type.BUILD_FARM_CORN,
	Job.Type.BUILD_FARM_VEGETABLES,
	Job.Type.BUILD_HERB_GARDEN,
	Job.Type.BUILD_WORKSHOP,
	Job.Type.BUILD_LOOM,
	Job.Type.BUILD_KILN,
	Job.Type.BUILD_SMELTER,
	Job.Type.BUILD_BOATYARD,
	Job.Type.BUILD_DOCK,
	Job.Type.BUILD_FISHERMAN_HUT,
	Job.Type.BUILD_APOTHECARY,
	Job.Type.BUILD_LIBRARY,
	Job.Type.BUILD_SCHOOL,
	Job.Type.BUILD_BARRACKS,
	Job.Type.BUILD_WATCHTOWER,
	Job.Type.BUILD_MARKET,
	Job.Type.BUILD_TRADING_POST,
	Job.Type.BUILD_ROAD,
	Job.Type.BUILD_GRANARY,
	Job.Type.BUILD_CELLAR,
	Job.Type.BUILD_BREWERY,
	Job.Type.BUILD_TAVERN,
	Job.Type.BUILD_FORD,
	Job.Type.BUILD_WATER_MILL,
]

const TRACE_CATEGORIES: Dictionary = {
	"farm": [Job.Type.BUILD_FARM_WHEAT, Job.Type.BUILD_FARM_CORN, Job.Type.BUILD_FARM_VEGETABLES, Job.Type.BUILD_HERB_GARDEN],
	"road": [Job.Type.BUILD_ROAD],
	"mine": [Job.Type.MINE, Job.Type.MINE_WALL],
	"shelter": [Job.Type.BUILD_SHELTER],
	"hearth": [Job.Type.BUILD_FIRE_PIT, Job.Type.BUILD_HEARTH],
	"storage": [Job.Type.BUILD_STORAGE_HUT, Job.Type.BUILD_STOCKPILE],
}

var _main: Node = null
var _gm: Node = null
var _tm: Node = null
var _jm: Node = null
var _sm: Node = null
var _world: Node = null
var _started: bool = false
var _main_spawned: bool = false
var _simulation_started: bool = false
var _done: bool = false
var _frame_count: int = 0
var _sampled: Dictionary = {}
var _samples: Array[Dictionary] = []
var _job_trace: Dictionary = {}
var _job_posted_counts: Dictionary = {}
var _job_claimed_counts: Dictionary = {}
var _job_completed_counts: Dictionary = {}
var _first_job_posted: Dictionary = {}
var _first_job_claimed: Dictionary = {}
var _first_job_completed: Dictionary = {}
var _failure_reason_counts: Dictionary = {}
var _start_tick: int = -1


func _initialize() -> void:
	_gm = root.get_node_or_null("GameManager")
	_tm = root.get_node_or_null("TickManager")
	_jm = root.get_node_or_null("JobManager")
	_sm = root.get_node_or_null("StockpileManager")
	if _gm != null and _gm.has_method("pause"):
		_gm.call("pause")
	if _tm != null and _tm.has_method("pause"):
		_tm.call("pause")
	_clear_fresh_save_files()
	call_deferred("_spawn_main")


func _process(_delta: float) -> bool:
	if _done:
		return false
	if not _started:
		_started = true
		return false
	if not _main_spawned:
		return false
	_frame_count += 1
	if _frame_count > TIMEOUT_FRAMES:
		_print_fail("timeout", "frame_limit_exceeded")
		_done = true
		quit(1)
		return true
	var tick: int = _current_tick()
	if not _simulation_started:
		_sample_and_print("start", tick)
		_start_simulation()
		_simulation_started = true
		_start_tick = tick
		return false
	if tick >= MID_YEAR_TICK and not _sampled.has("mid_year"):
		_sample_and_print("mid_year", tick)
	if tick >= YEAR_TICKS and not _sampled.has("year_1"):
		_sample_and_print("year_1", tick)
		_print_trace_if_needed()
		_print_failure_reason_summary()
		_done = true
		quit(0)
		return true
	return false


func _spawn_main() -> void:
	var packed: PackedScene = load(MAIN_SCENE_PATH) as PackedScene
	if packed == null:
		_print_fail("boot", "Main.tscn load failed")
		_done = true
		quit(1)
		return
	_main = packed.instantiate()
	root.add_child(_main)
	connect_job_signals()
	if _main != null and _main.has_method("_reroll_world"):
		_main.call("_reroll_world")
	_main_spawned = true
	print("[YEAR1_VIS] booted Main.tscn")


func _start_simulation() -> void:
	if _gm != null and _gm.has_method("set_state_from_load"):
		_gm.call("set_state_from_load", _current_tick(), TARGET_SPEED, false)
	else:
		if _gm != null and _gm.has_method("resume"):
			_gm.call("resume")
		if _tm != null and _tm.has_method("resume"):
			_tm.call("resume")
		if _gm != null and _gm.has_method("set_speed"):
			_gm.call("set_speed", TARGET_SPEED)
		if _tm != null and _tm.has_method("set_speed"):
			_tm.call("set_speed", TARGET_SPEED)
	print("[YEAR1_VIS] sim_start speed=%.1f" % TARGET_SPEED)


func connect_job_signals() -> void:
	if _jm == null:
		return
	if _jm.has_signal("job_posted") and not _jm.is_connected("job_posted", Callable(self, "_on_job_posted")):
		_jm.connect("job_posted", Callable(self, "_on_job_posted"))
	if _jm.has_signal("job_claimed") and not _jm.is_connected("job_claimed", Callable(self, "_on_job_claimed")):
		_jm.connect("job_claimed", Callable(self, "_on_job_claimed"))
	if _jm.has_signal("job_completed") and not _jm.is_connected("job_completed", Callable(self, "_on_job_completed")):
		_jm.connect("job_completed", Callable(self, "_on_job_completed"))
	if _jm.has_signal("job_cancelled") and not _jm.is_connected("job_cancelled", Callable(self, "_on_job_cancelled")):
		_jm.connect("job_cancelled", Callable(self, "_on_job_cancelled"))


func _on_job_posted(job: Variant) -> void:
	_track_job_event(job, _job_posted_counts, _first_job_posted)


func _on_job_claimed(job: Variant, pawn: Variant) -> void:
	_track_job_event(job, _job_claimed_counts, _first_job_claimed)
	_capture_job_actor(job, pawn, "claimed")


func _on_job_completed(job: Variant) -> void:
	_track_job_event(job, _job_completed_counts, _first_job_completed)
	_capture_job_actor(job, job.get("assigned_pawn") if job != null and job.has_method("get") else null, "completed")


func _on_job_cancelled(job: Variant) -> void:
	_capture_job_actor(job, job.get("assigned_pawn") if job != null and job.has_method("get") else null, "cancelled")


func _track_job_event(job: Variant, counter: Dictionary, first_store: Dictionary) -> void:
	if job == null:
		return
	var jt: int = int(job.get("type")) if job.has_method("get") else -1
	counter[jt] = int(counter.get(jt, 0)) + 1
	if not first_store.has(jt):
		first_store[jt] = _snapshot_job(job)


func _snapshot_job(job: Variant) -> Dictionary:
	if job == null:
		return {}
	var tile: Vector2i = job.get("tile") if job.has_method("get") else Vector2i(-1, -1)
	var work_tile: Vector2i = job.get("work_tile") if job.has_method("get") else tile
	var issuer_id: int = int(job.get("issuer_pawn_id")) if job.has_method("get") else -1
	var issuer_role: String = str(job.get("issuer_role")) if job.has_method("get") else ""
	var reason: String = str(job.get("reason")) if job.has_method("get") else ""
	return {
		"id": int(job.get("id")) if job.has_method("get") else -1,
		"type": jt_name(int(job.get("type")) if job.has_method("get") else -1),
		"type_id": int(job.get("type")) if job.has_method("get") else -1,
		"tile": tile,
		"work_tile": work_tile,
		"issuer_pawn_id": issuer_id,
		"issuer_role": issuer_role,
		"reason": reason,
		"material_req": _material_requirement_for_job(int(job.get("type")) if job.has_method("get") else -1),
	}


func _capture_job_actor(job: Variant, pawn: Variant, phase: String) -> void:
	if job == null:
		return
	var jt: int = int(job.get("type")) if job.has_method("get") else -1
	var rec: Dictionary = _job_trace.get(jt, {}) as Dictionary
	if rec.is_empty():
		rec = _snapshot_job(job)
	if pawn != null:
		var pd: Variant = pawn.get("data") if pawn.has_method("get") else null
		if pd != null:
			rec["pawn_id"] = int(pd.get("id"))
			rec["pawn_name"] = str(pd.get("display_name"))
		var tz: Variant = pawn.get("_target_zone") if pawn.has_method("get") else null
		if tz != null and tz is Node and is_instance_valid(tz):
			if tz.has_method("get"):
				rec["material_source_tile"] = tz.get("tile") if tz.get("tile") != null else Vector2i(-1, -1)
				rec["material_source_filter"] = str(tz.get("filter"))
			rec["material_source_settlement_id"] = int(tz.get("settlement_id")) if tz.has_method("get") else -1
	if phase == "completed":
		rec["completion_feature"] = _feature_name_at_tile(rec)
	_job_trace[jt] = rec


func _feature_name_at_tile(rec: Dictionary) -> String:
	if _world == null or _world.get("data") == null:
		return "unknown"
	var tile_v: Variant = rec.get("tile", Vector2i(-1, -1))
	if not (tile_v is Vector2i):
		return "unknown"
	var t: Vector2i = tile_v as Vector2i
	var feat: int = int(_world.get("data").get_feature(t.x, t.y))
	return TileFeature.name_for(feat)


func _material_requirement_for_job(job_type: int) -> String:
	var br: Node = root.get_node_or_null("BuildingRegistry")
	if br != null and br.has_method("get_building_by_job_type"):
		var b: Dictionary = br.call("get_building_by_job_type", job_type)
		if not b.is_empty():
			var cost: Dictionary = b.get("cost", {})
			if not cost.is_empty():
				return JSON.stringify(cost)
	match job_type:
		Job.Type.BUILD_FIRE_PIT, Job.Type.BUILD_HEARTH:
			return JSON.stringify({"wood": 1, "stone": 1})
		Job.Type.BUILD_SHELTER:
			return JSON.stringify({"wood": 3})
		Job.Type.BUILD_STORAGE_HUT:
			return JSON.stringify({"wood": 2})
		Job.Type.BUILD_ROAD:
			return JSON.stringify({"stone": 1})
		Job.Type.MINE, Job.Type.MINE_WALL:
			return "none"
		_:
			return "unknown"


func _sample_and_print(label: String, tick: int) -> void:
	_sampled[label] = true
	var snapshot: Dictionary = _collect_snapshot(tick)
	snapshot["label"] = label
	_samples.append(snapshot)
	_write_report()
	print("[YEAR1_VIS] SAMPLE label=%s %s" % [label, _format_snapshot(snapshot)])


func _collect_snapshot(tick: int) -> Dictionary:
	var world: Node = _world_node()
	var job_stats: Dictionary = _jm.stats() if _jm != null and _jm.has_method("stats") else {}
	var feature_counts: Dictionary = world.get_feature_counts() if world != null and world.has_method("get_feature_counts") else {}
	var stockpile_totals: Dictionary = _stockpile_snapshot()
	var fail_counts: Dictionary = _collect_failure_reasons()
	var year_idx: int = SimTime.sim_year_index(tick)
	var day_idx: int = SimTime.calendar_day_within_sim_year(tick)
	return {
		"label": "",
		"tick": tick,
		"year": year_idx,
		"day": day_idx,
		"total_jobs_posted": int(job_stats.get("posted", 0)),
		"build_jobs_posted": _sum_by_type(_job_posted_counts, BUILD_JOB_TYPES),
		"build_jobs_claimed": _sum_by_type(_job_claimed_counts, BUILD_JOB_TYPES),
		"build_jobs_completed": _sum_by_type(_job_completed_counts, BUILD_JOB_TYPES),
		"stockpiles_created": _stockpile_zone_count(),
		"farms_created": _feature_sum(feature_counts, [TileFeature.Type.FARM_WHEAT, TileFeature.Type.FARM_CORN, TileFeature.Type.FARM_VEGETABLES, TileFeature.Type.HERB_GARDEN]),
		"roads_created": _feature_sum(feature_counts, [TileFeature.Type.ROAD]),
		"mines_created": _sum_by_type(_job_completed_counts, [Job.Type.MINE, Job.Type.MINE_WALL]),
		"shelters_created": _sum_by_type(_job_completed_counts, [Job.Type.BUILD_SHELTER]),
		"hearths_created": _feature_sum(feature_counts, [TileFeature.Type.FIRE_PIT]),
		"storage_created": _feature_sum(feature_counts, [TileFeature.Type.STORAGE_HUT, TileFeature.Type.GRANARY, TileFeature.Type.CELLAR]),
		"stockpile_food": int(stockpile_totals.get("food", 0)),
		"stockpile_wood": int(stockpile_totals.get("wood", 0)),
		"stockpile_stone": int(stockpile_totals.get("stone", 0)),
		"failure_reasons": fail_counts,
	}


func _format_snapshot(s: Dictionary) -> String:
	var failure_summary: String = _format_top_reasons(Dictionary(s.get("failure_reasons", {})))
	return "tick=%d year=%d day=%d total_jobs_posted=%d build_jobs_posted=%d build_jobs_claimed=%d build_jobs_completed=%d stockpiles_created=%d farms_created=%d roads_created=%d mines_created=%d shelters_created=%d hearths_created=%d storage_created=%d stockpile_food=%d stockpile_wood=%d stockpile_stone=%d top_failure_reasons=%s" % [
		int(s.get("tick", 0)),
		int(s.get("year", 0)),
		int(s.get("day", 0)),
		int(s.get("total_jobs_posted", 0)),
		int(s.get("build_jobs_posted", 0)),
		int(s.get("build_jobs_claimed", 0)),
		int(s.get("build_jobs_completed", 0)),
		int(s.get("stockpiles_created", 0)),
		int(s.get("farms_created", 0)),
		int(s.get("roads_created", 0)),
		int(s.get("mines_created", 0)),
		int(s.get("shelters_created", 0)),
		int(s.get("hearths_created", 0)),
		int(s.get("storage_created", 0)),
		int(s.get("stockpile_food", 0)),
		int(s.get("stockpile_wood", 0)),
		int(s.get("stockpile_stone", 0)),
		failure_summary,
	]


func _feature_sum(feature_counts: Dictionary, features: Array[int]) -> int:
	var total: int = 0
	for ft in features:
		total += int(feature_counts.get(ft, 0))
	return total


func _stockpile_zone_count() -> int:
	if _sm == null:
		return 0
	if _sm.has_method("zone_count"):
		return int(_sm.call("zone_count"))
	if _sm.has_method("zones"):
		return int((_sm.call("zones") as Array).size())
	return 0


func _stockpile_snapshot() -> Dictionary:
	if _sm == null or not _sm.has_method("labor_pressure_stock_snapshot"):
		return {"food": 0, "wood": 0, "stone": 0}
	return _sm.call("labor_pressure_stock_snapshot")


func _sum_by_type(counter: Dictionary, types: Array[int]) -> int:
	var total: int = 0
	for t in types:
		total += int(counter.get(t, 0))
	return total


func _collect_failure_reasons() -> Dictionary:
	var out: Dictionary = {}
	if _jm != null:
		if _jm.has_method("get_cancel_stats"):
			_merge_reason_counts(out, _jm.call("get_cancel_stats"), "cancel")
		if _jm.has_method("get_abandon_stats"):
			_merge_reason_counts(out, _jm.call("get_abandon_stats"), "abandon")
	for p in _alive_pawns():
		var pd: Variant = p.get("data") if p.has_method("get") else null
		if pd == null:
			continue
		var idle_reason: String = str(pd.last_claim_failure_reason).strip_edges()
		if not idle_reason.is_empty():
			out[idle_reason] = int(out.get(idle_reason, 0)) + 1
	return out


func _merge_reason_counts(dest: Dictionary, src: Variant, prefix: String) -> void:
	if not (src is Dictionary):
		return
	for k in (src as Dictionary).keys():
		var reason: String = str(k)
		var count: int = int((src as Dictionary)[k])
		if reason.is_empty() or count <= 0:
			continue
		dest[reason] = int(dest.get(reason, 0)) + count


func _format_top_reasons(reason_counts: Dictionary) -> String:
	if reason_counts.is_empty():
		return "[]"
	var pairs: Array[Dictionary] = []
	for k in reason_counts.keys():
		pairs.append({"reason": str(k), "count": int(reason_counts[k])})
	pairs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("count", 0)) > int(b.get("count", 0))
	)
	var out: Array[String] = []
	for i in range(mini(5, pairs.size())):
		var p: Dictionary = pairs[i]
		out.append("%s=%d" % [str(p.get("reason", "")), int(p.get("count", 0))])
	return "[%s]" % ", ".join(out)


func _print_failure_reason_summary() -> void:
	var reasons: String = _format_top_reasons(_collect_failure_reasons())
	print("[YEAR1_VIS] FAILURE_TOP5 %s" % reasons)
	_write_report()


func _print_trace_if_needed() -> void:
	for label in TRACE_CATEGORIES.keys():
		var visible_count: int = _visible_count_for_label(str(label))
		if visible_count > 0:
			continue
		var trace: Dictionary = _first_trace_for_label(str(label))
		print("[YEAR1_VIS] TRACE label=%s visible_count=%d trace=%s" % [label, visible_count, JSON.stringify(trace)])


func _visible_count_for_label(label: String) -> int:
	var world: Node = _world_node()
	if world == null or not world.has_method("get_feature_counts"):
		return 0
	var fc: Dictionary = world.get_feature_counts()
	match label:
		"farm":
			return _feature_sum(fc, [TileFeature.Type.FARM_WHEAT, TileFeature.Type.FARM_CORN, TileFeature.Type.FARM_VEGETABLES, TileFeature.Type.HERB_GARDEN])
		"road":
			return int(fc.get(TileFeature.Type.ROAD, 0))
		"mine":
			return _sum_by_type(_job_completed_counts, [Job.Type.MINE, Job.Type.MINE_WALL])
		"shelter":
			return int(fc.get(TileFeature.Type.BED, 0))
		"hearth":
			return int(fc.get(TileFeature.Type.FIRE_PIT, 0))
		"storage":
			return _feature_sum(fc, [TileFeature.Type.STORAGE_HUT, TileFeature.Type.GRANARY, TileFeature.Type.CELLAR])
		_:
			return 0


func _first_trace_for_label(label: String) -> Dictionary:
	var types: Array = TRACE_CATEGORIES.get(label, []) as Array
	for jt_any in types:
		var jt: int = int(jt_any)
		if _job_trace.has(jt):
			return _job_trace[jt]
		if _first_job_completed.has(jt):
			return _first_job_completed[jt]
		if _first_job_claimed.has(jt):
			return _first_job_claimed[jt]
		if _first_job_posted.has(jt):
			return _first_job_posted[jt]
	return {}


func _clear_fresh_save_files() -> void:
	var paths: Array[String] = [
		GameSave.get_save_path(),
		GameSave.get_save_path(1),
		GameSave.get_save_path(2),
		GameSave.get_save_path(3),
		GameSave.DEFAULT_PATH.trim_suffix(".sav") + "_autosave.sav",
		"user://v1_core_loop_smoke.sav",
	]
	for path in paths:
		var abs: String = ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(abs)
		elif FileAccess.file_exists(abs):
			DirAccess.remove_absolute(abs)


func _write_report() -> void:
	var report: Dictionary = {
		"samples": _samples,
		"job_trace": _job_trace,
		"failure_reasons": _collect_failure_reasons(),
		"tick": _current_tick(),
		"simulation_started": _simulation_started,
	}
	var abs_path: String = ProjectSettings.globalize_path(REPORT_PATH)
	var f: FileAccess = FileAccess.open(abs_path, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(report, "\t"))
	f.close()


func _world_node() -> Node:
	if _main == null or not is_instance_valid(_main):
		return null
	return _main.get_node_or_null("WorldViewport/World")


func _alive_pawns() -> Array:
	var pa: Node = root.get_node_or_null("PawnAccess")
	if pa == null or not pa.has_method("find_alive_pawns"):
		return []
	return pa.call("find_alive_pawns")


func _current_tick() -> int:
	if _gm == null:
		return 0
	return int(_gm.get("tick_count"))


func jt_name(job_type: int) -> String:
	return str(Job.describe_type(job_type))


func _print_fail(check: String, reason: String) -> void:
	print("[YEAR1_VIS_FAIL] %s reason=%s" % [check, reason])
