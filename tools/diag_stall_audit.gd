extends SceneTree

## Headless stall audit. Boots Main, runs at 200x to tick ~3500, pauses, then
## dumps settlement/stockpile/job/pawn state and a per-job rejection matrix that
## mirrors HeelKawnian.base_passes() (hunt stabilization -> claim cooldown ->
## allows_job_type -> region scar >=3 -> component match -> materials -> tech)
## plus JobManager visibility. Pure diagnostic; does not modify world state.
##
## NOTE: `--script` tools cannot reference autoload identifiers at parse time,
## so every autoload is resolved via root node lookups here. Enum values are
## extracted at runtime from a pawn's script constant map (no preloads — pulling
## Item.gd/Job.gd into the parse graph breaks pawn spawn compilation).

const RUN_TO_TICK := 12000
const FRAME_CAP := 3000

var _frame := 0
var _phase := "boot"
var _printed := false

var _gm: Node = null
var _main: Node = null
var _world: Node = null

var _job_type_enum: Dictionary = {}
var _item_type_enum: Dictionary = {}
var _job_enum_noted: bool = false

func _job_type(t: int) -> String:
	if _job_type_enum.is_empty():
		return "TYPE_%d" % t
	var keys: Array = _job_type_enum.keys()
	if t >= 0 and t < keys.size():
		return str(keys[t])
	return "TYPE_%d" % t

func _item_type(t: int) -> String:
	if _item_type_enum.is_empty():
		return "ITEM_%d" % t
	var keys: Array = _item_type_enum.keys()
	if t >= 0 and t < keys.size():
		return str(keys[t])
	return "ITEM_%d" % t

func _load_enums_from_pawn(p) -> void:
	if p == null or not is_instance_valid(p):
		return
	var sc: Script = p.get_script()
	if sc == null:
		return
	var cc: Dictionary = sc.get_script_constant_map()
	var js = cc.get("_Job")
	var is_ = cc.get("_Item")
	if js != null:
		var e = js.get("Type")
		if e is Dictionary:
			_job_type_enum = e
	if is_ != null:
		var e = is_.get("Type")
		if e is Dictionary:
			_item_type_enum = e
	if not _job_type_enum.is_empty() and not _job_enum_noted:
		_job_enum_noted = true
		var jkeys: Array = _job_type_enum.keys()
		print("STALL_AUDIT: job enum loaded size=%d first6=%s" % [jkeys.size(), str(jkeys.slice(0, mini(6, jkeys.size())))])

func _al(name: String) -> Node:
	return root.get_node_or_null("/root/" + name)

func _job_val(n: String) -> int:
	return int(_job_type_enum.get(n, -1))

func _item_val(n: String) -> int:
	return int(_item_type_enum.get(n, -1))

func _initialize() -> void:
	var gm_trace: Node = root.get_node_or_null("GameManager")
	if gm_trace != null:
		if gm_trace.has_method("set_game_tick_trace_enabled"):
			gm_trace.call("set_game_tick_trace_enabled", false)
		else:
			gm_trace.set("trace_game_tick_dispatch", false)
	call_deferred("_spawn_main")

func _spawn_main() -> void:
	## Permanent Tool Rule: this tool boots Main past the autosave boundary
	## (tick % 6000) and MUST run with --playtest-no-save or it would overwrite
	## the production autosave. Refuse to run otherwise.
	if not OS.get_cmdline_user_args().has("--playtest-no-save"):
		push_error("STALL_AUDIT: this tool boots Main past the autosave boundary and must run with --playtest-no-save; refusing to run")
		quit(1)
		return
	var packed: PackedScene = load("res://scenes/main/Main.tscn") as PackedScene
	if packed == null:
		push_error("STALL_AUDIT: cannot load Main.tscn")
		quit(1)
		return
	var main: Node = packed.instantiate()
	root.add_child(main)
	if not bool(main.get("_save_writes_disabled_for_playtest")):
		push_error("STALL_AUDIT: Main autosave fence not active (Main._save_writes_disabled_for_playtest=false); refusing to run")
		quit(1)

func _process(_delta: float) -> bool:
	if _printed:
		return false
	_frame += 1
	if _frame > FRAME_CAP:
		_printed = true
		print("STALL_AUDIT: frame cap reached without reaching tick %d (tick=%s)" % [RUN_TO_TICK, _tick()])
		quit(1)
		return false
	if _gm == null:
		_gm = _al("GameManager")
	if _gm == null:
		return false
	if _phase == "boot":
		_main = root.get_node_or_null("/root/Main")
		if _main != null:
			_phase = "run"
			_gm.call("set_speed", 200.0)
			print("STALL_AUDIT: Main ready, running at 200x to tick %d" % RUN_TO_TICK)
		return false
	if _phase == "run":
		if _frame % 300 == 0:
			var tm: Node = root.get_node_or_null("/root/TickManager")
			print("STALL_AUDIT: frame=%d gm_tick=%d tm_tick=%d paused=%s speed=%s" % [
				_frame, _tick(), int(tm.get("current_tick")) if tm != null else -1,
				_gm.get("is_paused") if _gm != null else "?",
				_gm.get("game_speed") if _gm != null else "?"])
		if _tick() >= RUN_TO_TICK:
			_phase = "dump"
			_gm.call("pause")
			var tm2: Node = root.get_node_or_null("/root/TickManager")
			if tm2 != null and tm2.has_method("pause"):
				tm2.call("pause")
		return false
	if _phase == "dump":
		_dump()
		_printed = true
		quit(0)
	return false

func _tick() -> int:
	if _gm != null:
		return int(_gm.get("tick_count"))
	return -1

func _job_type_name(t: int) -> String:
	if t >= 0 and t < _job_type_enum.size():
		return _job_type(t)
	return "TYPE_%d" % t

func _jk(obj, key: String, default: Variant) -> Variant:
	var v = obj.get(key)
	if v == null:
		return default
	return v

func _dump() -> void:
	_world = _main.get("_world")
	var tick: int = _tick()
	var sm = _al("SettlementMemory")
	var jm = _al("JobManager")
	var stm = _al("StockpileManager")
	var wm = _al("WorldMemory")
	print("=== STALL_AUDIT dump @ tick=%d ===" % tick)

	# --- Settlements ---
	var formal: Array = []
	if sm != null and sm.has_method("get_formal_settlements"):
		formal = sm.get_formal_settlements()
	var protos: Array = []
	if sm != null and sm.has_method("get_proto_sites"):
		protos = sm.get_proto_sites()
	print("[AUDIT] formal_settlements=%d proto_sites=%d" % [formal.size(), protos.size()])
	for ps in protos:
		if not (ps is Dictionary):
			continue
		var ck: int = int(ps.get("center_region", -1))
		print("[AUDIT] proto center_rk=%d pop=%d beds=%d hearths=%d walls=%d gen=%s" % [
			ck,
			int(ps.get("population", 0)),
			int(ps.get("beds", 0)),
			int(ps.get("hearths", 0)),
			int(ps.get("walls", 0)),
			str(ps.get("gen", ps.get("created_tick", "?")))])

	# --- Stockpiles ---
	if stm != null:
		var wood: int = stm.total_count_of(_item_val("WOOD")) if stm.has_method("total_count_of") else -1
		var stone: int = stm.total_count_of(_item_val("STONE")) if stm.has_method("total_count_of") else -1
		print("[AUDIT] stockpiles zones=%d wood=%d stone=%d" % [
			stm.zone_count() if stm.has_method("zone_count") else -1, wood, stone])
	# --- Pressures ---
	var css = _al("ColonySimServices")
	if css != null:
		print("[AUDIT] pressures housing=%.2f food=%.2f storage=%.2f warmth=%.2f cooking=%.2f cold_uncovered=%d" % [
			float(css.get_housing_pressure()) if css.has_method("get_housing_pressure") else -1.0,
			float(css.get_food_pressure()) if css.has_method("get_food_pressure") else -1.0,
			float(css.get_storage_pressure()) if css.has_method("get_storage_pressure") else -1.0,
			float(css.get_warmth_pressure()) if css.has_method("get_warmth_pressure") else -1.0,
			float(css.get_cooking_pressure()) if css.has_method("get_cooking_pressure") else -1.0,
			int(css.count_cold_uncovered_pawns()) if css.has_method("count_cold_uncovered_pawns") else -1])

	# --- Jobs ---
	var open_jobs: Array = []
	if jm != null and jm.has_method("get_open_jobs_snapshot"):
		open_jobs = jm.get_open_jobs_snapshot()
	print("[AUDIT] job_count open=%d total=%d claimed=%d" % [
		open_jobs.size(),
		int(jm.get("_open").size()) if jm != null and jm.get("_open") != null else -1,
		jm.claimed_count() if jm != null and jm.has_method("claimed_count") else -1])
	for j in open_jobs:
		var t: int = int(j.get("type"))
		var sd: int = int(_jk(j, "settlement_id", -1))
		print("[AUDIT] job id=%d type=%s prio=%d tile=%s work=%s sid=%d region_key=%s vis_to=%s age=%d" % [
			int(_jk(j, "id", -1)), _job_type_name(t), int(_jk(j, "priority", 0)),
			str(_jk(j, "tile", Vector2i.ZERO)), str(_jk(j, "work_tile", Vector2i.ZERO)),
			sd, str(_jk(j, "region_key", -999)), str(_jk(j, "visible_to", "all")),
			tick - int(_jk(j, "posted_tick", tick))])

	# --- Pawns ---
	var pawns: Array = []
	if _main != null:
		var spawner = _main.get("_pawn_spawner")
		if spawner != null:
			pawns = spawner.get("pawns")
	print("[AUDIT] pawn_count=%d" % pawns.size())
	for p in pawns:
		if not is_instance_valid(p):
			continue
		var pd = p.get("data")
		if pd == null:
			continue
		var pid: int = int(_jk(pd, "id", -1))
		_load_enums_from_pawn(p)
		var sid: int = int(_jk(pd, "settlement_id", -1))
		var tile: Vector2i = _jk(pd, "tile_pos", Vector2i(-1, -1))
		var rk: int = wm.call("_region_key", tile.x, tile.y)
		var center_rk: int = -1
		if sm != null and sm.has_method("get_center_region_for_region"):
			center_rk = int(sm.get_center_region_for_region(rk))
		var comp: int = -1
		if _world != null and _world.get("pathfinder") != null:
			comp = int(_world.get("pathfinder").component_of(tile))
		var st: int = int(p.get("_state"))
		var stn: String = "?"
		if p.has_method("get_state_name"):
			stn = str(p.call("get_state_name"))
		var claim: String = "no-claim"
		var armed: bool = false
		if _gm != null and p.get("_pawn_sim_tick_armed") != null:
			armed = bool(p.get("_pawn_sim_tick_armed"))
			claim = "last_claim_tick=%d result=%s streak=%d" % [int(p.get("_last_claim_tick")), str(p.get("_last_claim_result")).left(14), int(p.get("_idle_claim_fail_streak"))]
		var age_y: float = 0.0
		if pd != null and pd.get("age_years") != null:
			age_y = float(pd.get("age_years"))
		var lstage: int = int(_jk(pd, "life_stage", -1))
		var lstage_name: String = "?"
		if pd != null and pd.has_method("get_life_stage_name"):
			lstage_name = str(pd.call("get_life_stage_name"))
		var hunger_v: float = float(_jk(pd, "hunger", -1.0))
		var age_i: int = int(_jk(pd, "age", -1))
		var pioneer: bool = bool(_jk(pd, "is_pioneer", false))
		var birth_set: int = int(_jk(pd, "birth_settlement", -1))
		var parent_a: int = int(_jk(pd, "parent_a_id", -1))
		var parent_b: int = int(_jk(pd, "parent_b_id", -1))
		var birth_kind: String = "?"
		if wm != null and wm.has_method("get_events"):
			for ev in wm.get_events():
				if ev is Dictionary and ev.get("type") == "pawn_birth" and int(ev.get("pawn_id", -1)) == pid:
					birth_kind = str(ev.get("birth_kind", "?")).left(16)
					break
		print("[AUDIT] pawn id=%d state=%d(%s) sid=%d tile=%s rk=%d center=%d comp=%d armed=%s age_y=%.3f age_i=%d life=%s hunger=%.1f pioneer=%s birth=%s parent_a=%d birth_kind=%s claim(%s)" % [
			pid, st, stn, sid, str(tile), rk, center_rk, comp, str(armed), age_y, age_i, lstage_name, hunger_v, str(pioneer), birth_set, parent_a, birth_kind, claim])

	# --- Rejection matrix (mirror base_passes + visibility) ---
	print("[AUDIT] === rejection matrix ===")
	for j in open_jobs:
		var t: int = int(j.get("type"))
		var job_name: String = _job_type_name(t)
		var wt: Vector2i = _jk(j, "work_tile", Vector2i.ZERO)
		var job_rk: int = wm.call("_region_key", wt.x, wt.y)
		var job_center_rk: int = -1
		if sm != null and sm.has_method("get_center_region_for_region"):
			job_center_rk = int(sm.get_center_region_for_region(job_rk))
		var job_sid: int = int(_jk(j, "settlement_id", -1))
		var job_comp: int = -1
		if _world != null and _world.get("pathfinder") != null:
			job_comp = int(_world.get("pathfinder").component_of(wt))
		var reasons: Dictionary = {}
		var eligible: int = 0
		var near24: int = 0
		var near40: int = 0
		var same_center: int = 0
		for p in pawns:
			if not is_instance_valid(p):
				continue
			var pd = p.get("data")
			if pd == null:
				continue
			var ptile: Vector2i = _jk(pd, "tile_pos", Vector2i(-999, -999))
			var d: int = absi(ptile.x - wt.x) + absi(ptile.y - wt.y)
			if d <= 24:
				near24 += 1
			if d <= 40:
				near40 += 1
			var prk: int = wm.call("_region_key", ptile.x, ptile.y)
			if prk == job_rk or (job_center_rk >= 0 and int(sm.get_center_region_for_region(prk)) == job_center_rk):
				same_center += 1
			var barrier: String = _pawn_job_barrier(p, pd, j, job_rk, job_center_rk, job_sid, job_comp)
			if barrier == "":
				eligible += 1
			else:
				reasons[barrier] = int(reasons.get(barrier, 0)) + 1
		var line: String = "[AUDIT] job %s sid=%d center=%d comp=%d eligible=%d near(24/40/same)=%d/%d/%d | reject:" % [
			job_name, job_sid, job_center_rk, job_comp, eligible, near24, near40, same_center]
		for k in reasons:
			line += " %s=%d" % [k, reasons[k]]
		print(line)
	print("[AUDIT] === matrix done ===")

func _pawn_job_barrier(p: Node, pd, j, job_rk: int, job_center_rk: int, job_sid: int, job_comp: int) -> String:
	var tick: int = _tick()
	var t: int = int(j.get("type"))
	var jid: int = int(j.get("id"))
	var wm = _al("WorldMemory")
	var stm = _al("StockpileManager")
	var jm = _al("JobManager")
	var wp = _al("WorldPersistence")

	# 1. hunt stabilization
	if p.has_method("_world_hunt_stabilization_blocks") and bool(p.call("_world_hunt_stabilization_blocks")) and t == _job_val("HUNT"):
		return "hunt_stabilization"

	# 2. claim cooldown
	var cd = p.get("_job_claim_cooldowns")
	if cd is Dictionary and cd.has(jid) and int(cd[jid]) > tick:
		return "claim_cooldown"

	# 3. job type allowance
	if not bool(pd.call("allows_job_type", t)):
		return "allows_job_type"

	# 4. region scar >= 3 (except critical job history)
	if p.has_method("is_job_history_critical") and not bool(p.call("is_job_history_critical", t)):
		var scar: int = 0
		if wp != null and wp.has_method("get_region_scar_level"):
			scar = int(wp.call("get_region_scar_level", job_rk))
		if scar >= 3:
			return "region_scar_w3"

	# 5. component mismatch
	var pawn_comp: int = -1
	if _world != null and _world.get("pathfinder") != null:
		pawn_comp = int(_world.get("pathfinder").component_of(_jk(pd, "tile_pos", Vector2i.ZERO)))
	if job_comp != pawn_comp:
		return "wrong_component(j=%d p=%d)" % [job_comp, pawn_comp]

	# 6. materials
	var mats: Dictionary = {}
	if p.has_method("_materials_for_active_build"):
		mats = p.call("_materials_for_active_build", j)
	if not mats.is_empty():
		var item: int = int(mats.get("item", -1))
		var qty: int = int(mats.get("qty", 0))
		var zones = stm.get("_zones") if stm != null else null
		var have_zones: bool = zones is Array and not (zones as Array).is_empty()
		if have_zones:
			var have: int = 0
			if stm.has_method("total_count_of"):
				have = stm.total_count_of(item)
			if have < qty:
				var item_name: String = _item_type(item)
				return "materials(%s need=%d have=%d)" % [item_name, qty, have]

	# 7. visibility (JobManager side)
	var vis_ok: bool = true
	if jm != null and jm.has_method("_job_visible_to_pawn_with_context") and jm.has_method("_build_pawn_visibility_context"):
		var pctx: Dictionary = jm.call("_build_pawn_visibility_context", p, pd)
		vis_ok = bool(jm.call("_job_visible_to_pawn_with_context", j, p, pd, pctx))
	if not vis_ok:
		return "job_visibility(%s sid=%d)" % [str(_jk(j, "visible_to", "all")), job_sid]

	return ""