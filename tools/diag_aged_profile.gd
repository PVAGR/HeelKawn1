extends SceneTree

## Headless aged-save profiler + starvation/settlement audit.
##
## Boots Main, loads the live aged autosave (user://heelkawn_colony_autosave.sav),
## runs it at 200x under PAWN_DISPATCH_PROFILE, then dumps:
##   - settlement gate status (formal/proto/reasons, not_evaluated check)
##   - per-starving-pawn reachability trace (component vs food zones)
##
## Requires --profile-pawn-dispatch (as user arg) to feed the profiler.
##
## NOTE: `--script` tools cannot reference autoload identifiers or class_name
## at parse time. Everything is resolved via /root lookups + .get()/.call().

const SAVE_PATH := "user://heelkawn_colony_autosave.sav"
const TARGET_DELTA := 6000
const FRAME_CAP := 240000
const WALL_BUDGET_US := 1500_000_000
const STATUS_INTERVAL := 2000

var _frame := 0
var _phase := "boot"
var _printed := false
var _wall0 := 0
var _saved_tick := 0
var _last_status_tick := -1

var _gm: Node = null
var _main: Node = null
var _world: Node = null

func _al(name: String) -> Node:
	return root.get_node_or_null("/root/" + name)

func _tick() -> int:
	if _gm != null:
		return int(_gm.get("tick_count"))
	return -1

func _jk(obj, key: String, default: Variant) -> Variant:
	if obj == null or not ("get" in obj):
		return default
	var v = obj.get(key)
	if v == null:
		return default
	return v

func _initialize() -> void:
	var gm_trace: Node = root.get_node_or_null("GameManager")
	if gm_trace != null:
		if gm_trace.has_method("set_game_tick_trace_enabled"):
			gm_trace.call("set_game_tick_trace_enabled", false)
		else:
			gm_trace.set("trace_game_tick_dispatch", false)
	call_deferred("_spawn_main")

func _spawn_main() -> void:
	## Permanent Tool Rule: this tool LOADS the production autosave and then
	## advances the sim past autosave boundaries — it MUST run with
	## --playtest-no-save or Main would overwrite the very save it is profiling.
	if not OS.get_cmdline_user_args().has("--playtest-no-save"):
		push_error("AGED_PROFILE: this tool loads and advances the production autosave and must run with --playtest-no-save; refusing to run")
		quit(1)
		return
	var packed: PackedScene = load("res://scenes/main/Main.tscn") as PackedScene
	if packed == null:
		push_error("AGED_PROFILE: cannot load Main.tscn")
		quit(1)
		return
	var main: Node = packed.instantiate()
	root.add_child(main)
	if not bool(main.get("_save_writes_disabled_for_playtest")):
		push_error("AGED_PROFILE: Main autosave fence not active (Main._save_writes_disabled_for_playtest=false); refusing to run")
		quit(1)

func _process(_delta: float) -> bool:
	if _printed:
		return false
	_frame += 1
	if _frame == 1:
		_wall0 = Time.get_ticks_usec()
	if _gm == null:
		_gm = _al("GameManager")
	if _gm == null:
		return false
	var used: int = Time.get_ticks_usec() - _wall0
	if _phase == "boot":
		_main = root.get_node_or_null("/root/Main")
		if _main == null:
			return false
		var spawner2 = _main.get("_pawn_spawner")
		if spawner2 == null:
			return false
		_phase = "load"
		print("AGED_PROFILE: Main ready, loading %s" % SAVE_PATH)
		return false
	if _phase == "load":
		var gs: GDScript = load("res://scripts/save/GameSave.gd") as GDScript
		var d: Dictionary = gs.call("read_file", SAVE_PATH)
		if d.is_empty():
			print("AGED_PROFILE: FATAL save empty/missing at %s" % SAVE_PATH)
			_printed = true
			quit(1)
			return false
		_saved_tick = int(_jk(d, "tick", -1))
		_main.call("_apply_save_dict", d)
		_phase = "run"
		if _gm.has_method("resume"):
			_gm.call("resume")
		_gm.call("set_speed", 200.0)
		print("AGED_PROFILE: loaded save tick=%d run 200x +%d ticks" % [_saved_tick, TARGET_DELTA])
		return false
	if _phase == "run":
		if _tick() >= _saved_tick + TARGET_DELTA:
			_phase = "dump"
			_pause()
			return false
		if used > WALL_BUDGET_US:
			_phase = "dump"
			print("AGED_PROFILE: wall budget expired @tick=%d (%ds)" % [_tick(), int(used / 1000000)])
			_pause()
			return false
		if _frame > FRAME_CAP:
			_phase = "dump"
			print("AGED_PROFILE: frame cap expired @tick=%d" % _tick())
			_pause()
			return false
		if _tick() - _last_status_tick >= STATUS_INTERVAL:
			_last_status_tick = _tick()
			_status_line()
		return false
	if _phase == "dump":
		_dump()
		_printed = true
		print("AGED_PROFILE: done @tick=%d elapsed=%ds" % [_tick(), int((Time.get_ticks_usec() - _wall0) / 1000000)])
		quit(0)
	return false

func _pause() -> void:
	_gm.call("pause")
	var tm2: Node = _al("TickManager")
	if tm2 != null and tm2.has_method("pause"):
		tm2.call("pause")

func _status_line() -> void:
	var sm = _al("SettlementMemory")
	if sm == null:
		return
	print("AGED_PROFILE: @%d formal=%d proto=%d starving=%d totalfood=%d" % [
		_tick(),
		sm.get_formal_settlements().size() if sm.has_method("get_formal_settlements") else -1,
		sm.get_proto_sites().size() if sm.has_method("get_proto_sites") else -1,
		_starving_count(),
		_total_food(),
	])

func _total_food() -> int:
	var sp = _al("StockpileManager")
	if sp == null or not sp.has_method("total_food"):
		return -1
	return int(sp.total_food())

func _starving_count() -> int:
	var n: int = 0
	for p in _pawns():
		if not is_instance_valid(p):
			continue
		var pd = p.get("data")
		if pd == null:
			continue
		if float(_jk(pd, "hunger", 999.0)) <= HUNGER_EMERGENCY:
			n += 1
	return n

const HUNGER_EMERGENCY := 20.0

func _pawns() -> Array:
	if _main == null:
		return []
	var spawner = _main.get("_pawn_spawner")
	if spawner == null:
		return []
	return spawner.get("pawns")

func _dump() -> void:
	_world = _main.get("_world")
	print("=== AGED_PROFILE dump @tick=%d ===" % _tick())
	_dump_settlements()
	_dump_starvation()
	_dump_tickprofiler()
	_dump_dispatch()
	print("=== AGED_PROFILE dump end ===")

func _dump_dispatch() -> void:
	var hg: GDScript = load("res://scripts/pawn/HeelKawnian.gd") as GDScript
	if hg == null:
		return
	if not hg.has_method("get_pd_snapshot_for_diagnostics"):
		return
	var snap: Dictionary = hg.call("get_pd_snapshot_for_diagnostics")
	var agg: Dictionary = snap.get("agg", {})
	var rows: Array = []
	for st in agg:
		var e: Array = agg[st]
		rows.append([int(e[0]), st, int(e[1])])
	rows.sort_custom(func(a, b): return int(a[0]) > int(b[0]))
	print("PAWN_DISPATCH_STAGES (total_us n avg_us)")
	for r in rows.slice(0, 30):
		var avg: int = (int(r[0]) / int(r[2])) if int(r[2]) > 0 else 0
		print("  %-26s n=%-6d total=%-10d avg=%d" % [r[1], int(r[2]), int(r[0]), avg])
	var wai: Node = _al("WorldAI")
	if wai != null:
		const SPLIT_KEYS: Array[String] = [
			"_nc_hits", "_nc_miss_ttl", "_nc_miss_sig", "_nc_compute_count", "_nc_compute_us",
			"_nc_input_vector_us", "_nc_forward_us", "_nc_rule_context_us", "_nc_rule_eval_us",
			"_nc_output_nudge_us", "_nc_result_cache_write_us",
		]
		var line: String = "NEURAL_CACHE_PROFILE"
		for k in SPLIT_KEYS:
			if wai.get(k) is int:
				line += " %s=%d" % [k, int(wai.get(k))]
		print(line)
		wai.set("_nc_hits", 0)
		wai.set("_nc_miss_ttl", 0)
		wai.set("_nc_miss_sig", 0)
		wai.set("_nc_compute_count", 0)
		wai.set("_nc_compute_us", 0)
		wai.set("_nc_input_vector_us", 0)
		wai.set("_nc_forward_us", 0)
		wai.set("_nc_rule_context_us", 0)
		wai.set("_nc_rule_eval_us", 0)
		wai.set("_nc_output_nudge_us", 0)
		wai.set("_nc_result_cache_write_us", 0)

func _dump_tickprofiler() -> void:
	var tp = _al("TickProfiler")
	if tp == null:
		return
	print("TP window_count=%d" % (tp.get("_window_count") if tp.get("_window_count") != null else -1))
	for cat in [
		"cat_bookkeeping", "cat_needs", "cat_survival_health", "cat_cognition",
		"cat_awareness", "cat_matrix_ai", "cat_social", "cat_household",
		"cat_settlement", "cat_state_dispatch", "cat_misc", "cat_total_heelkawnian",
		"cat_ai_world_ai", "cat_ai_settlement_ai", "cat_ai_agent_update", "cat_ai_maintenance", "cat_ai_total",
	]:
		print("TP %s=%d" % [cat, int(_jk(tp, cat, 0))])
	for cat in [
		"idle_social_us", "idle_job_search_us", "idle_job_scoring_us", "idle_job_claim_us",
		"idle_pathfinding_us", "idle_awareness_us", "idle_matrix_ai_us", "idle_cognition_us",
		"idle_emergency_us", "idle_food_us", "idle_rest_us", "idle_wander_us", "idle_misc_us",
	]:
		print("TP %s=%d" % [cat, int(_jk(tp, cat, 0))])
	for st in [
		"st_idle_calls", "st_idle_us", "st_working_calls", "st_working_us",
		"st_walking_calls", "st_walking_us", "st_eating_calls", "st_eating_us",
		"st_sleeping_calls", "st_sleeping_us",
	]:
		print("TP %s=%d" % [st, int(_jk(tp, st, 0))])
	var cb: Dictionary = tp.get_callback_profile() if tp.has_method("get_callback_profile") else {}
	if not cb.is_empty():
		var rows: Array = []
		for k in cb:
			rows.append([k, int(cb[k])])
		rows.sort_custom(func(a, b): return a[1] > b[1])
		for r in rows.slice(0, 25):
			print("TPCB %8dus  %s" % [r[1], r[0]])

func _dump_settlements() -> void:
	var sm = _al("SettlementMemory")
	if sm == null or not sm.has_method("get_formal_settlements"):
		return
	var formal: Array = sm.get_formal_settlements()
	var protos: Array = sm.get_proto_sites() if sm.has_method("get_proto_sites") else []
	var all_settlements: Array = sm.get_settlements() if sm.has_method("get_settlements") else []
	print("AGED_PROFILE: formal=%d proto=%d all=%d" % [formal.size(), protos.size(), all_settlements.size()])
	var reasons: Dictionary = {}
	var not_evaluated: int = 0
	for i in range(all_settlements.size()):
		if not (all_settlements[i] is Dictionary):
			continue
		var st: Dictionary = all_settlements[i]
		var reason: String = str(st.get("guild_candidate_reason", "UNSET"))
		reasons[reason] = int(reasons.get(reason, 0)) + 1
		if reason == "not_evaluated":
			not_evaluated += 1
		var ck: int = int(st.get("center_region", -1))
		var cx: int = ck & 0xFFFF
		var cy: int = (ck >> 16) & 0xFFFF
		print("AGED_PROFILE: st[%d] center=(%d,%d)rk=%d kind=%s formal=%s pop=%d reason=%s founding_tick=%d" % [
			i, cx, cy, ck, str(st.get("settlement_kind", "?")), str(st.get("is_formal_settlement", false)),
			int(st.get("population", 0)), reason, int(st.get("founding_tick", -1))])
	print("AGED_PROFILE: gate_reason_distribution=%s (not_evaluated=%d)" % [str(reasons), not_evaluated])

func _dump_starvation() -> void:
	var sm = _al("SettlementMemory")
	var spm = _al("StockpileManager")
	var pawns: Array = _pawns()
	print("AGED_PROFILE: starving trace pawn_count=%d total_food=%d zones=%d" % [
		pawns.size(), _total_food(), spm.zone_count() if spm != null and spm.has_method("zone_count") else -1])
	var zones: Array = spm.zones() if spm != null and spm.has_method("zones") else []
	var agg: Dictionary = {"starving": 0, "carrying": 0, "busy_work_state": 0, "component_mismatch": 0, "no_food_anywhere": 0, "other": 0}
	for p in pawns:
		if not is_instance_valid(p):
			continue
		var pd = p.get("data")
		if pd == null:
			continue
		var hunger: float = float(_jk(pd, "hunger", 999.0))
		if hunger > HUNGER_EMERGENCY:
			continue
		agg["starving"] += 1
		var tile: Vector2i = _jk(pd, "tile_pos", Vector2i(-1, -1))
		var sid: int = int(_jk(pd, "settlement_id", -1))
		var carrying: bool = pd.has_method("is_carrying") and bool(pd.call("is_carrying"))
		var state_int: int = int(_jk(p, "_state", 0))
		var job_type: int = -1
		var job = p.get("_current_job")
		if job != null and ("get" in job):
			job_type = int(_jk(job, "type", -1))
		var tile_comp: int = _component_of(tile)
		# Food zones relative to this pawn.
		var reachable_food: Array = []
		var own_food: Array = []
		for z in zones:
			if z == null or not is_instance_valid(z):
				continue
			if not (z.has_method("has_any_food") and bool(z.call("has_any_food"))):
				continue
			var z_near: Vector2i = z.call("nearest_reachable_tile_to", tile, _world.pathfinder) if "nearest_reachable_tile_to" in z else tile
			var z_comp: int = _component_of(z_near)
			var z_sid: int = int(_jk(z, "settlement_id", -1))
			if z_comp == tile_comp:
				reachable_food.append(z_sid)
			if z_sid == sid:
				own_food.append(z_comp)
		var cls: String = "other"
		if carrying:
			cls = "carrying"
		elif state_int != 0:  # State.IDLE == 0; eats only run on the idle lane
			cls = "busy_work_state"
		elif reachable_food.is_empty():
			if own_food.is_empty() and _total_food() <= 0:
				cls = "no_food_anywhere"
			else:
				cls = "component_mismatch"
		agg[cls] += 1
		print("AGED_PROFILE: pawn=%d hunger=%.0f state=%d carrying=%s job=%d tile=(%d,%d) comp=%d sid=%d reachable_food_zones=%s own_food_zone_comps=%s cls=%s" % [
			int(_jk(pd, "id", -1)), hunger, state_int, str(carrying), job_type, tile.x, tile.y, tile_comp, sid,
			str(reachable_food), str(own_food), cls])
	print("AGED_PROFILE: starving_agg=%s" % str(agg))

func _component_of(tile: Vector2i) -> int:
	if _world == null:
		return -2
	var pf = _world.get("pathfinder")
	if pf == null or not pf.has_method("component_of"):
		return -2
	return int(pf.call("component_of", tile))