extends SceneTree

## MATURE-WORLD JOB-CLAIM STALL WINDOW CAPTURE
## Loads the production autosave (tick ~120k) with --playtest-no-save fence,
## accelerates at 200x, and captures bounded windows at regular cadence.
## Detects transition open>0 + claimed~0 + working~0 persisting.
## Pure diagnostic, never writes saves.

const SAVE_PATH := "user://heelkawn_colony_autosave.sav"
const CAPTURE_EVERY_TICKS := 500
const MAX_WINDOWS := 80
const STALL_PERSIST_REQUIRED := 3
const RUN_AT_SPEED := 26.0
const WALL_BUDGET_US := 1_200_000_000 # 20 min
const FRAME_CAP := 300000

var _frame := 0
var _phase := "boot"
var _wall0 := 0
var _gm: Node = null
var _main: Node = null
var _saved_tick := 0
var _next_capture_tick := 0
var _windows: Array[Dictionary] = []
var _prev_claim_attempts := -1
var _prev_claim_successes := -1
var _prev_completed := -1
var _prev_cancelled := -1
var _prev_abandoned := -1
var _stall_streak := 0
var _first_bad_idx := -1
var _printed := false

func _al(n: String) -> Node:
	return root.get_node_or_null("/root/" + n)

func _tick() -> int:
	if _gm != null:
		return int(_gm.get("tick_count"))
	return -1

func _jk(o, k: String, d: Variant) -> Variant:
	if o == null:
		return d
	var v = o.get(k)
	return v if v != null else d

func _initialize() -> void:
	var gm_trace: Node = root.get_node_or_null("GameManager")
	if gm_trace != null:
		if gm_trace.has_method("set_game_tick_trace_enabled"):
			gm_trace.call("set_game_tick_trace_enabled", false)
		else:
			gm_trace.set("trace_game_tick_dispatch", false)
	call_deferred("_spawn_main")

func _spawn_main() -> void:
	if not OS.get_cmdline_user_args().has("--playtest-no-save"):
		push_error("MATURE_WINDOWS: must run with --playtest-no-save; refusing")
		quit(1)
		return
	var packed: PackedScene = load("res://scenes/main/Main.tscn") as PackedScene
	if packed == null:
		push_error("MATURE_WINDOWS: cannot load Main.tscn")
		quit(1)
		return
	var main: Node = packed.instantiate()
	root.add_child(main)
	if not bool(main.get("_save_writes_disabled_for_playtest")):
		push_error("MATURE_WINDOWS: fence not active; refusing")
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
	if _phase == "boot":
		_main = root.get_node_or_null("/root/Main")
		if _main == null:
			return false
		var spawner2 = _main.get("_pawn_spawner")
		if spawner2 == null:
			return false
		_phase = "load"
		return false
	if _phase == "load":
		var gs: GDScript = load("res://scripts/save/GameSave.gd") as GDScript
		var d: Dictionary = gs.call("read_file", SAVE_PATH)
		if d.is_empty():
			print("MATURE_WINDOWS: FATAL save empty at %s" % SAVE_PATH)
			_printed = true
			quit(1)
			return false
		_saved_tick = int(_jk(d, "tick", -1))
		_main.call("_apply_save_dict", d)
		if _gm.has_method("resume"):
			_gm.call("resume")
		_gm.call("set_speed", RUN_AT_SPEED)
		_next_capture_tick = _tick() + CAPTURE_EVERY_TICKS
		_prev_claim_attempts = -1
		print("MATURE_WINDOWS: loaded tick=%d run %.0fx capture_every=%d" % [_saved_tick, RUN_AT_SPEED, CAPTURE_EVERY_TICKS])
		# Immediate capture at load
		_capture_window(true)
		_phase = "run"
		return false
	if _phase == "run":
		var cur := _tick()
		if cur >= _next_capture_tick:
			_capture_window(false)
			_next_capture_tick = cur + CAPTURE_EVERY_TICKS
		if _windows.size() >= MAX_WINDOWS:
			_phase = "dump"
			_pause()
			return false
		if Time.get_ticks_usec() - _wall0 > WALL_BUDGET_US:
			print("MATURE_WINDOWS: wall budget expired @%d" % cur)
			_phase = "dump"
			_pause()
			return false
		if _frame > FRAME_CAP:
			print("MATURE_WINDOWS: frame cap @%d" % cur)
			_phase = "dump"
			_pause()
			return false
		# Early stall detection: if we have persisting stall, stop accumulating and dump
		if _first_bad_idx >= 0 and _windows.size() >= _first_bad_idx + 3:
			# Got T+2 after first bad, stop
			print("MATURE_WINDOWS: stall persisting, captured T+2, stopping")
			_phase = "dump"
			_pause()
			return false
		return false
	if _phase == "dump":
		_dump()
		_printed = true
		quit(0)
	return false

func _pause() -> void:
	_gm.call("pause")
	var tm2: Node = _al("TickManager")
	if tm2 != null and tm2.has_method("pause"):
		tm2.call("pause")

func _capture_window(is_initial: bool) -> void:
	var tick := _tick()
	var gm = _al("GameManager")
	var tm = _al("TickManager")
	var sc = _al("SimulationClock")
	var jm = _al("JobManager")
	var sm = _al("SettlementMemory")
	var pa = _al("PawnAccess")
	var spawner = _main.get("_pawn_spawner") if _main != null else null

	var requested_speed: float = float(gm.get("game_speed")) if gm != null else -1.0
	var effective: float = 0.0
	if tm != null and tm.has_method("get_effective_world_speed"):
		effective = float(tm.call("get_effective_world_speed"))
	elif tm != null and tm.has_method("get_effective_world_speed"):
		effective = float(tm.call("get_effective_world_speed"))
	var target_ws: float = 0.0
	var committed_ws: float = 0.0
	var lag: float = 0.0
	if sc != null:
		if sc.has_method("get_target_world_time_seconds"):
			target_ws = float(sc.call("get_target_world_time_seconds"))
		if sc.has_method("get_committed_world_time_seconds"):
			committed_ws = float(sc.call("get_committed_world_time_seconds"))
		if sc.has_method("get_simulation_lag_seconds"):
			lag = float(sc.call("get_simulation_lag_seconds"))
	var pawn_discrete_min := 0.0
	var pawn_discrete_max := 0.0
	var pawn_discrete_count := 0
	# bounded aggregate
	var disc_agg := _discrete_bounded()
	pawn_discrete_min = float(disc_agg.get("min_applied", 0.0))
	pawn_discrete_max = float(disc_agg.get("max_applied", 0.0))
	pawn_discrete_count = int(disc_agg.get("count", 0))

	var pending: bool = false
	if tm != null:
		pending = bool(tm.get("_pending_tick_active"))

	# Pawns
	var alive: Array = []
	if pa != null and pa.has_method("find_alive_pawns"):
		alive = pa.call("find_alive_pawns")
	elif spawner != null and spawner.has_method("get_alive_pawns"):
		alive = spawner.call("get_alive_pawns")
	# Alternate via group
	if alive.is_empty():
		var grp: Array = get_nodes_in_group("pawns")
		for n in grp:
			if is_instance_valid(n) and n.get("data") != null and not bool(n.get("data").get("is_dead", true)):
				alive.append(n)

	var idle := 0
	var idle_can_work := 0
	var working := 0
	var alive_can_work := 0
	var idle_non_work_streak := 0
	for p in alive:
		if not is_instance_valid(p):
			continue
		var pd = p.get("data")
		if pd == null:
			continue
		var st: int = int(p.get("_state")) if p.get("_state") != null else -1
		var st_name: String = str(p.call("get_state_name")) if p.has_method("get_state_name") else str(st)
		if st == 0: # IDLE
			idle += 1
			var can_w: bool = false
			if pd.has_method("can_work"):
				can_w = bool(pd.call("can_work"))
			elif pd.get("life_stage") != null:
				can_w = int(pd.get("life_stage")) != 0
			if can_w:
				idle_can_work += 1
		if st == 7 or st_name == "Working":
			working += 1
		# alive_can_work overall
		var can_w2: bool = false
		if pd.has_method("can_work"):
			can_w2 = bool(pd.call("can_work"))
		if can_w2:
			alive_can_work += 1

	# Jobs GLOBAL via JobManager
	var open_cnt := 0
	var claimed_cnt := 0
	var posted_cnt := 0
	var completed_cnt := 0
	var cancelled_cnt := 0
	var abandoned_cnt := 0
	var claim_attempts := 0
	var claim_successes := 0
	var stats: Dictionary = {}
	if jm != null and jm.has_method("stats"):
		stats = jm.call("stats")
		open_cnt = int(stats.get("open", 0))
		claimed_cnt = int(stats.get("claimed", 0))
		posted_cnt = int(stats.get("posted", 0))
		completed_cnt = int(stats.get("completed", 0))
		cancelled_cnt = int(stats.get("cancelled", 0))
		abandoned_cnt = int(stats.get("abandoned", 0))
		claim_attempts = int(stats.get("claim_attempts", 0))
		claim_successes = int(stats.get("claim_successes", 0))
	else:
		if jm != null:
			if jm.get("_open") != null:
				open_cnt = int((jm.get("_open") as Array).size())
			if jm.has_method("claimed_count"):
				claimed_cnt = int(jm.call("claimed_count"))
			elif jm.get("_claimed") != null:
				claimed_cnt = int((jm.get("_claimed") as Array).size())

	var delta_attempts := 0
	var delta_successes := 0
	var delta_completed := 0
	var delta_cancelled := 0
	var delta_abandoned := 0
	if _prev_claim_attempts >= 0:
		delta_attempts = claim_attempts - _prev_claim_attempts
		delta_successes = claim_successes - _prev_claim_successes
		delta_completed = completed_cnt - _prev_completed
		delta_cancelled = cancelled_cnt - _prev_cancelled
		delta_abandoned = abandoned_cnt - _prev_abandoned
	_prev_claim_attempts = claim_attempts
	_prev_claim_successes = claim_successes
	_prev_completed = completed_cnt
	_prev_cancelled = cancelled_cnt
	_prev_abandoned = abandoned_cnt

	var rejection_reasons: Dictionary = stats.get("rejection_reasons", {}) if stats is Dictionary else {}
	var cancel_reasons: Dictionary = stats.get("cancel_reasons", {}) if stats is Dictionary else {}
	var abandon_reasons: Dictionary = stats.get("abandon_reasons", {}) if stats is Dictionary else {}

	# BY JOB TYPE
	var open_by_type: Dictionary = {}
	var oldest_by_type: Dictionary = {}
	if jm != null and jm.has_method("get_open_jobs_snapshot"):
		var snap: Array = jm.call("get_open_jobs_snapshot")
		for j in snap:
			var t: int = int(j.type)
			open_by_type[t] = int(open_by_type.get(t, 0)) + 1
			var age: int = tick - int(j.posted_tick)
			if not oldest_by_type.has(t) or age > int(oldest_by_type[t]):
				oldest_by_type[t] = age

	# SAMPLE AT LEAST 5 WORK-CAPABLE NON-WORKING PAWNS
	var samples: Array[Dictionary] = []
	var considered := 0
	for p in alive:
		if samples.size() >= 5:
			break
		if not is_instance_valid(p):
			continue
		var pd = p.get("data")
		if pd == null:
			continue
		var can_w: bool = false
		if pd.has_method("can_work"):
			can_w = bool(pd.call("can_work"))
		if not can_w:
			continue
		var st: int = int(p.get("_state")) if p.get("_state") != null else -1
		var st_name: String = str(p.call("get_state_name")) if p.has_method("get_state_name") else str(st)
		if st_name == "Working" or st == 7:
			continue
		# This is a work-capable non-working candidate
		var sid: int = int(pd.get("settlement_id")) if pd.get("settlement_id") != null else -1
		var tile: Vector2i = pd.get("tile_pos") if pd.get("tile_pos") != null else Vector2i(-1,-1)
		var hunger: float = float(pd.get("hunger")) if pd.get("hunger") != null else -1.0
		var health: float = float(pd.get("health")) if pd.get("health") != null else -1.0
		var cur_job = p.get("_current_job")
		var cur_job_type: int = -1
		if cur_job != null:
			cur_job_type = int(cur_job.type)
		var disc_snap: Dictionary = {}
		if p.has_method("get_pawn_discrete_snapshot_for_diagnostics"):
			disc_snap = p.call("get_pawn_discrete_snapshot_for_diagnostics")
		var pending_norm: int = int(disc_snap.get("pending_normal_count", -1))
		var applied: float = float(disc_snap.get("applied_through_world_time", -1.0))
		var queued: Array = disc_snap.get("queued_due_deadlines", [])
		var snap_info: Dictionary = {}
		var cand_count: int = -1
		var cand_types: Array = []
		var rej_reason: String = ""
		if jm != null and jm.has_method("get_indexed_candidate_snapshot"):
			snap_info = jm.call("get_indexed_candidate_snapshot", p, pd)
			var cands: Array = snap_info.get("candidates", [])
			cand_count = cands.size()
			for cj in cands:
				if cj != null:
					cand_types.append(int(cj.type))
			if cands.is_empty():
				var rr: Dictionary = snap_info.get("rejection_reasons", {})
				if not rr.is_empty():
					rej_reason = str(rr.keys()[0])
		# path/reachability: count reachable vs component mismatch
		var comp: int = -1
		if _main != null and _main.get("_world") != null:
			var w = _main.get("_world")
			if w != null and w.get("pathfinder") != null:
				var pf = w.get("pathfinder")
				if pf.has_method("component_of"):
					comp = int(pf.call("component_of", tile))
		var settlement_id_via_ctx: int = -1
		var region_key: int = -1
		var center_region: int = -1
		if _al("WorldMemory") != null:
			region_key = int(_al("WorldMemory").call("_region_key", tile.x, tile.y))
		if _al("SettlementMemory") != null and region_key >= 0:
			center_region = int(_al("SettlementMemory").call("get_center_region_for_region", region_key))
			settlement_id_via_ctx = int(_al("SettlementMemory").call("get_settlement_id_for_region", region_key))

		samples.append({
			"id": int(pd.get("id")),
			"name": str(pd.get("display_name")),
			"state": st_name,
			"state_int": st,
			"can_work": can_w,
			"hunger": hunger,
			"health": health,
			"life_stage": int(pd.get("life_stage")) if pd.get("life_stage") != null else -1,
			"cur_job_type": cur_job_type,
			"tile": tile,
			"component": comp,
			"settlement_id": sid,
			"settlement_via_ctx": settlement_id_via_ctx,
			"region_key": region_key,
			"pending_norm": pending_norm,
			"applied": applied,
			"queued": queued.size(),
			"next_decision": float(disc_snap.get("next_decision_world_time", -1.0)),
			"center_region": center_region,
			"cand_count": cand_count,
			"cand_types": cand_types,
			"rej_reason": rej_reason,
		})
		considered += 1

	# Settlement progression
	var formal_cnt := -1
	var proto_cnt := -1
	if sm != null:
		if sm.has_method("get_formal_settlements"):
			formal_cnt = int((sm.call("get_formal_settlements") as Array).size())
		if sm.has_method("get_proto_sites"):
			proto_cnt = int((sm.call("get_proto_sites") as Array).size())
	var zone_cnt := -1
	var total_food := -1
	var food_pressure := -1.0
	var housing_pressure := -1.0
	var spm = _al("StockpileManager")
	if spm != null:
		if spm.has_method("zone_count"):
			zone_cnt = int(spm.call("zone_count"))
		if spm.has_method("total_food"):
			total_food = int(spm.call("total_food"))
		elif spm.has_method("total_count_of"):
			# fallback
			var ItemScript: GDScript = load("res://scripts/items/Item.gd") as GDScript
			if ItemScript != null:
				var food_type: int = 7 # Item.Type.FOOD ?
				total_food = int(spm.call("total_count_of", food_type))
	var css = _al("ColonySimServices")
	if css != null:
		if css.has_method("get_food_pressure"):
			food_pressure = float(css.call("get_food_pressure"))
		if css.has_method("get_housing_pressure"):
			housing_pressure = float(css.call("get_housing_pressure"))

	var win: Dictionary = {
		"tick": tick,
		"requested_speed": requested_speed,
		"effective": effective,
		"target_ws": target_ws,
		"committed_ws": committed_ws,
		"lag": lag,
		"pawn_discrete_min": pawn_discrete_min,
		"pawn_discrete_max": pawn_discrete_max,
		"pawn_discrete_count": pawn_discrete_count,
		"pending": pending,
		"alive": alive.size(),
		"alive_can_work": alive_can_work,
		"idle": idle,
		"idle_can_work": idle_can_work,
		"working": working,
		"open": open_cnt,
		"claimed": claimed_cnt,
		"posted": posted_cnt,
		"completed": completed_cnt,
		"cancelled": cancelled_cnt,
		"abandoned": abandoned_cnt,
		"claim_attempts": claim_attempts,
		"claim_successes": claim_successes,
		"delta_attempts": delta_attempts,
		"delta_successes": delta_successes,
		"delta_completed": delta_completed,
		"delta_cancelled": delta_cancelled,
		"delta_abandoned": delta_abandoned,
		"success_rate_window": float(delta_successes) / float(max(1, delta_attempts)),
		"rejection_reasons": rejection_reasons,
		"cancel_reasons": cancel_reasons,
		"abandon_reasons": abandon_reasons,
		"open_by_type": open_by_type,
		"oldest_by_type": oldest_by_type,
		"formal": formal_cnt,
		"proto": proto_cnt,
		"zone_cnt": zone_cnt,
		"total_food": total_food,
		"food_pressure": food_pressure,
		"housing_pressure": housing_pressure,
		"samples": samples,
	}

	_windows.append(win)

	# Pretty print window
	var rate_str := "%.2f" % win["success_rate_window"]
	var by_type_str := ""
	for k in open_by_type.keys():
		by_type_str += " %d:%d" % [k, open_by_type[k]]
	if by_type_str.is_empty():
		by_type_str = " none"
	print("WIN tick=%d alive=%d idle=%d idle_can_work=%d working=%d open=%d claimed=%d dAttempts=%d dSucc=%d rate=%s dCompl=%d lag=%.1f eff=%.1f disc=[%.1f..%.1f] formal=%d proto=%d zones=%d food=%d foodPress=%.2f housePress=%.2f by_type:%s" % [
		tick, alive.size(), idle, idle_can_work, working, open_cnt, claimed_cnt, delta_attempts, delta_successes, rate_str, delta_completed, lag, effective, pawn_discrete_min, pawn_discrete_max, formal_cnt, proto_cnt, zone_cnt, total_food, food_pressure, housing_pressure, by_type_str
	])
	# Sample first pawn rej if any
	if not samples.is_empty():
		var s0: Dictionary = samples[0]
		print("  SAMPLE0 id=%d %s state=%s hunger=%.0f cand=%d rej=%s sid=%d->%d comp=%d" % [
			s0["id"], s0["name"], s0["state"], s0["hunger"], s0["cand_count"], s0["rej_reason"], s0["settlement_id"], s0["settlement_via_ctx"], s0["component"]
		])

	# Stall detection: open>0 + alive_can_work>0 + (claimed==0 or rate collapse) + working==0 persists
	var is_stall: bool = (open_cnt > 0 and alive_can_work > 0 and (claimed_cnt == 0 or (delta_attempts > 0 and float(delta_successes)/float(delta_attempts) < 0.02)) and working == 0)
	# Also near-zero: claimed==0 alone counts even if attempts low but persists
	if open_cnt > 0 and alive_can_work > 0 and claimed_cnt == 0 and working == 0:
		is_stall = true
	if is_stall:
		_stall_streak += 1
		print("  STALL_CANDIDATE streak=%d (open=%d claimed=%d working=%d alive_can_work=%d rate=%s)" % [_stall_streak, open_cnt, claimed_cnt, working, alive_can_work, rate_str])
		if _stall_streak >= STALL_PERSIST_REQUIRED and _first_bad_idx < 0:
			_first_bad_idx = _windows.size() - 1
			print("  >>> FIRST BAD WINDOW idx=%d tick=%d <<<" % [_first_bad_idx, tick])
	else:
		if _stall_streak > 0:
			print("  stall streak reset (was %d)" % _stall_streak)
		_stall_streak = 0

func _discrete_bounded() -> Dictionary:
	var agg := {"min_applied": 0.0, "max_applied": 0.0, "count": 0, "available": false}
	var pawns: Array = []
	if _main != null and _main.get("_pawn_spawner") != null:
		var sp = _main.get("_pawn_spawner")
		if sp != null and sp.get("pawns") != null:
			pawns = sp.get("pawns")
	if pawns.is_empty():
		var grp: Array = get_nodes_in_group("pawns")
		pawns = grp
	var found := 0
	var min_v := 1e9
	var max_v := -1e9
	for p in pawns:
		if p == null or not is_instance_valid(p):
			continue
		if not p.has_method("get_pawn_discrete_snapshot_for_diagnostics"):
			continue
		var s: Dictionary = p.call("get_pawn_discrete_snapshot_for_diagnostics")
		var ap: float = float(s.get("applied_through_world_time", -1.0))
		if ap < 0:
			continue
		found += 1
		if ap < min_v:
			min_v = ap
		if ap > max_v:
			max_v = ap
	if found > 0:
		agg["min_applied"] = min_v
		agg["max_applied"] = max_v
		agg["count"] = found
		agg["available"] = true
	return agg

func _dump() -> void:
	print("=== MATURE_WINDOWS DUMP %d windows first_bad=%d ===" % [_windows.size(), _first_bad_idx])
	if _first_bad_idx >= 0:
		var lo: int = max(0, _first_bad_idx - 3)
		var hi: int = min(_windows.size() - 1, _first_bad_idx + 2)
		print("--- T-3..T+2 around first bad idx %d ---" % _first_bad_idx)
		for i in range(lo, hi + 1):
			var w: Dictionary = _windows[i]
			var marker: String = ">>> BAD" if i == _first_bad_idx else "   "
			print("%s WIN[%d] tick=%d open=%d claimed=%d working=%d idle_can_work=%d dSucc=%d/%d rate=%.2f formal=%d proto=%d lag=%.2f" % [
				marker, i, w["tick"], w["open"], w["claimed"], w["working"], w["idle_can_work"], w["delta_successes"], w["delta_attempts"], w["success_rate_window"], w["formal"], w["proto"], w["lag"]
			])
			# Detail per sample
			for s in w["samples"]:
				print("  sample id=%d %s state=%s cand=%d rej=%s center=%d comp=%d" % [s["id"], s["name"], s["state"], s["cand_count"], s["rej_reason"], s["center_region"], s["component"]])
			# Open by type detail
			print("  open_by_type=%s oldest=%s rej=%s" % [str(w["open_by_type"]), str(w["oldest_by_type"]), str(w["rejection_reasons"])])
	else:
		print("No persisting stall detected in %d windows" % _windows.size())
		# Still dump last 5 windows for diagnosis
		for i in range(max(0, _windows.size() - 5), _windows.size()):
			var w: Dictionary = _windows[i]
			print("WIN[%d] tick=%d open=%d claimed=%d working=%d dSucc=%d/%d rate=%.2f" % [i, w["tick"], w["open"], w["claimed"], w["working"], w["delta_successes"], w["delta_attempts"], w["success_rate_window"]])
	# Global summary: tick progression
	if not _windows.is_empty():
		print("SUMMARY first_tick=%d last_tick=%d total_windows=%d" % [_windows[0]["tick"], _windows[_windows.size()-1]["tick"], _windows.size()])
	print("=== DUMP END ===")
