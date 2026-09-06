extends SceneTree

## Loads mature save, pauses, and dumps job pipeline with per-pawn indexed snapshot.
const SAVE_PATH := "user://heelkawn_colony_autosave.sav"

var _phase := "boot"
var _gm: Node = null
var _main: Node = null
var _printed := false
var _run_target := 0
var _run_start_wall := 0

func _al(n: String) -> Node:
	return root.get_node_or_null("/root/" + n)

func _initialize() -> void:
	call_deferred("_spawn_main")

func _spawn_main() -> void:
	if not OS.get_cmdline_user_args().has("--playtest-no-save"):
		push_error("SNAPSHOT: must run with --playtest-no-save")
		quit(1)
		return
	var packed: PackedScene = load("res://scenes/main/Main.tscn") as PackedScene
	var main: Node = packed.instantiate()
	root.add_child(main)
	if not bool(main.get("_save_writes_disabled_for_playtest")):
		push_error("SNAPSHOT: fence not active")
		quit(1)

func _process(_delta: float) -> bool:
	if _printed:
		return false
	if _gm == null:
		_gm = _al("GameManager")
		return false
	if _phase == "boot":
		_main = root.get_node_or_null("/root/Main")
		if _main == null:
			return false
		if _main.get("_pawn_spawner") == null:
			return false
		_phase = "load"
		return false
	if _phase == "load":
		var gs: GDScript = load("res://scripts/save/GameSave.gd") as GDScript
		var d: Dictionary = gs.call("read_file", SAVE_PATH)
		if d.is_empty():
			print("SNAPSHOT: save empty")
			quit(1)
			return false
		var saved_tick: int = int(d.get("tick", -1))
		print("SNAPSHOT: loading saved tick=%d" % saved_tick)
		_main.call("_apply_save_dict", d)
		var gm_tick: int = int(_gm.get("tick_count"))
		var tm: Node = _al("TickManager")
		var tm_tick: int = int(tm.get("current_tick")) if tm != null else -1
		print("SNAPSHOT: after load gm_tick=%d tm_tick=%d (expected %d)" % [gm_tick, tm_tick, saved_tick])
		# Run a short soak at 26x to observe claim activity post-load
		_gm.call("set_speed", 26.0)
		if _gm.has_method("resume"):
			_gm.call("resume")
		_phase = "run"
		_run_target = gm_tick + 3000
		_run_start_wall = Time.get_ticks_usec()
		print("SNAPSHOT: resuming at 26x to %d (wall budget 90s)" % _run_target)
		return false
	if _phase == "run":
		var cur: int = int(_gm.get("tick_count"))
		if cur >= _run_target or Time.get_ticks_usec() - _run_start_wall > 90_000_000:
			print("SNAPSHOT: run done cur=%d target=%d" % [cur, _run_target])
			var tm2: Node = _al("TickManager")
			if _gm.has_method("pause"):
				_gm.call("pause")
			if tm2 != null and tm2.has_method("pause"):
				tm2.call("pause")
			_phase = "dump"
		return false
	if _phase == "dump":
		_dump()
		_printed = true
		quit(0)
	return false

func _dump() -> void:
	var gm = _al("GameManager")
	var jm = _al("JobManager")
	var sm = _al("SettlementMemory")
	var pa = _al("PawnAccess")
	var wm = _al("WorldMemory")
	var tick: int = int(gm.get("tick_count")) if gm != null else -1
	print("=== SNAPSHOT dump @ tick=%d ===" % tick)
	# settlements
	if sm != null:
		var formal: Array = sm.call("get_formal_settlements") if sm.has_method("get_formal_settlements") else []
		var proto: Array = sm.call("get_proto_sites") if sm.has_method("get_proto_sites") else []
		print("SNAP settlements formal=%d proto=%d" % [formal.size(), proto.size()])
		for s in proto:
			if s is Dictionary:
				print("  proto center=%d pop=%d" % [int(s.get("center_region",-1)), int(s.get("population",0))])
		for s in formal:
			if s is Dictionary:
				print("  formal center=%d pop=%d kind=%s" % [int(s.get("center_region",-1)), int(s.get("population",0)), str(s.get("settlement_kind","?"))])
	# job global
	var stats: Dictionary = {}
	if jm != null and jm.has_method("stats"):
		stats = jm.call("stats")
	print("SNAP jobs stats=%s" % str(stats))
	var open_jobs: Array = []
	if jm != null and jm.has_method("get_open_jobs_snapshot"):
		open_jobs = jm.call("get_open_jobs_snapshot")
	print("SNAP open_jobs=%d" % open_jobs.size())
	var by_type: Dictionary = {}
	for j in open_jobs:
		var t: int = int(j.type)
		by_type[t] = int(by_type.get(t,0))+1
	print("SNAP open_by_type=%s" % str(by_type))
	# list first 10 jobs detail
	for i in range(mini(10, open_jobs.size())):
		var j = open_jobs[i]
		print("  job[%d] id=%d type=%d prio=%d tile=%s work=%s sid=%d region=%s visible_to=%s" % [i, int(j.id), int(j.type), int(j.priority), str(j.tile), str(j.work_tile), int(j.settlement_id), str(j.region_key), str(j.visible_to)])
	# pawns
	var pawns: Array = []
	if pa != null and pa.has_method("find_alive_pawns"):
		pawns = pa.call("find_alive_pawns")
	elif _main != null and _main.get("_pawn_spawner") != null:
		var sp = _main.get("_pawn_spawner")
		pawns = sp.get("pawns")
	print("SNAP pawns alive=%d" % pawns.size())
	var work_capable_non_working: Array = []
	for p in pawns:
		if not is_instance_valid(p):
			continue
		var pd = p.get("data")
		if pd == null:
			continue
		var can_w: bool = false
		if pd.has_method("can_work"):
			can_w = bool(pd.call("can_work"))
		var st_name: String = str(p.call("get_state_name")) if p.has_method("get_state_name") else str(p.get("_state"))
		if can_w and st_name != "Working":
			work_capable_non_working.append(p)
		var idle_can := false
		if st_name == "Idle" and can_w:
			idle_can = true
		print("  pawn id=%d %s state=%s can_work=%s hunger=%.1f tile=%s sid=%d" % [int(pd.get("id")), str(pd.get("display_name")), st_name, str(can_w), float(pd.get("hunger")), str(pd.get("tile_pos")), int(pd.get("settlement_id"))])
	print("SNAP work_capable_non_working=%d" % work_capable_non_working.size())
	# per-pawn indexed snapshot
	var max_samples := 5
	for idx in range(mini(max_samples, work_capable_non_working.size())):
		var p = work_capable_non_working[idx]
		var pd = p.get("data")
		print("--- SAMPLE pawn id=%d %s ---" % [int(pd.get("id")), str(pd.get("display_name"))])
		var snap: Dictionary = jm.call("get_indexed_candidate_snapshot", p, pd) if jm != null and jm.has_method("get_indexed_candidate_snapshot") else {}
		var cands: Array = snap.get("candidates", [])
		var rej: Dictionary = snap.get("rejection_reasons", {})
		print("  indexed_snapshot candidates=%d rej=%s snapshot_id=%s" % [cands.size(), str(rej), str(snap.get("snapshot_id",-1))])
		for cj in cands.slice(0,5):
			print("    cand id=%d type=%d prio=%d work=%s" % [int(cj.id), int(cj.type), int(cj.priority), str(cj.work_tile)])
		# Also try base_passes barrier for first few jobs
		if cands.is_empty() and not open_jobs.is_empty():
			# Check visibility per job for this pawn
			var vis_count := 0
			var non_vis_examples: Array = []
			for j in open_jobs.slice(0,10):
				var vis: bool = false
				if jm != null and jm.has_method("_job_visible_to_pawn_with_context"):
					var ctx: Dictionary = jm.call("_build_pawn_visibility_context", p, pd)
					vis = bool(jm.call("_job_visible_to_pawn_with_context", j, p, pd, ctx))
				if vis:
					vis_count += 1
				elif non_vis_examples.size() < 3:
					non_vis_examples.append(int(j.type))
			print("  visibility check first10: vis=%d non_vis_types=%s" % [vis_count, str(non_vis_examples)])
		# Also try legacy barrier via diag logic
		var barrier_counts: Dictionary = {}
		for j in open_jobs.slice(0,20):
			var barrier: String = _barrier(p, pd, j)
			if barrier.is_empty():
				barrier = "eligible"
			barrier_counts[barrier] = int(barrier_counts.get(barrier,0))+1
		print("  barrier sample first20: %s" % str(barrier_counts))

func _barrier(p: Node, pd, j) -> String:
	var jm = _al("JobManager")
	var tick: int = int(_al("GameManager").get("tick_count"))
	var wm = _al("WorldMemory")
	var stm = _al("StockpileManager")
	var wp = _al("WorldPersistence")
	var t: int = int(j.type)
	var jid: int = int(j.id)
	if p.has_method("_world_hunt_stabilization_blocks") and bool(p.call("_world_hunt_stabilization_blocks")) and t == 5: # HUNT
		return "hunt_stabilization"
	var cd = p.get("_job_claim_cooldowns")
	if cd is Dictionary and cd.has(jid) and int(cd[jid]) > tick:
		return "claim_cooldown"
	if not bool(pd.call("allows_job_type", t)):
		return "allows_job_type"
	if p.has_method("is_job_history_critical") and not bool(p.call("is_job_history_critical", t)):
		var scar: int = 0
		if wp != null and wp.has_method("get_region_scar_level"):
			var wt: Vector2i = j.work_tile
			var rk: int = int(wm.call("_region_key", wt.x, wt.y))
			scar = int(wp.call("get_region_scar_level", rk))
		if scar >= 3:
			return "region_scar_w3"
	var pawn_comp: int = -1
	var job_comp: int = -1
	if _main != null and _main.get("_world") != null:
		var w = _main.get("_world")
		if w != null and w.get("pathfinder") != null:
			var pf = w.get("pathfinder")
			pawn_comp = int(pf.call("component_of", pd.get("tile_pos")))
			job_comp = int(pf.call("component_of", j.work_tile))
	if job_comp != pawn_comp:
		return "wrong_component"
	var mats: Dictionary = {}
	if p.has_method("_materials_for_active_build"):
		mats = p.call("_materials_for_active_build", j)
	if not mats.is_empty():
		var item: int = int(mats.get("item",-1))
		var qty: int = int(mats.get("qty",0))
		var have: int = 0
		if stm != null and stm.has_method("total_count_of"):
			have = int(stm.call("total_count_of", item))
		if have < qty:
			return "materials"
	var vis_ok: bool = true
	if jm != null and jm.has_method("_job_visible_to_pawn_with_context") and jm.has_method("_build_pawn_visibility_context"):
		var pctx: Dictionary = jm.call("_build_pawn_visibility_context", p, pd)
		vis_ok = bool(jm.call("_job_visible_to_pawn_with_context", j, p, pd, pctx))
	if not vis_ok:
		return "job_visibility"
	return ""
