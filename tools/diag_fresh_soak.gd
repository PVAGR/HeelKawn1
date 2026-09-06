extends SceneTree
const CAPTURE_EVERY := 2000
const MAX_WINDOWS := 60
const RUN_SPEED := 26.0
const WALL_BUDGET_US := 1_200_000_000
var _gm: Node = null
var _main: Node = null
var _phase := "boot"
var _wall0 := 0
var _next_cap := 0
var _windows: Array[Dictionary] = []
var _prev_attempts := -1
var _prev_success := -1
var _stall_streak := 0
var _first_bad := -1
var _printed := false
func _al(n: String) -> Node:
	return root.get_node_or_null("/root/" + n)
func _initialize() -> void:
	call_deferred("_spawn_main")
func _spawn_main() -> void:
	if not OS.get_cmdline_user_args().has("--playtest-no-save"):
		push_error("FRESH_SOAK must run with --playtest-no-save")
		quit(1)
		return
	var packed: PackedScene = load("res://scenes/main/Main.tscn") as PackedScene
	var main: Node = packed.instantiate()
	root.add_child(main)
	if not bool(main.get("_save_writes_disabled_for_playtest")):
		push_error("fence not active")
		quit(1)
func _process(_delta: float) -> bool:
	if _printed:
		return false
	if _gm == null:
		_gm = _al("GameManager")
		return false
	if _phase == "boot":
		_main = root.get_node_or_null("/root/Main")
		if _main == null or _main.get("_pawn_spawner") == null:
			return false
		_wall0 = Time.get_ticks_usec()
		_gm.call("set_speed", RUN_SPEED)
		_next_cap = int(_gm.get("tick_count")) + CAPTURE_EVERY
		_phase = "run"
		print("FRESH_SOAK start speed %.0f capture every %d" % [RUN_SPEED, CAPTURE_EVERY])
		return false
	if _phase == "run":
		var cur: int = int(_gm.get("tick_count"))
		if cur >= _next_cap:
			_capture()
			_next_cap = cur + CAPTURE_EVERY
		if _windows.size() >= MAX_WINDOWS:
			_phase = "dump"
		elif Time.get_ticks_usec() - _wall0 > WALL_BUDGET_US:
			print("FRESH_SOAK wall budget")
			_phase = "dump"
		elif cur > 40000:
			_phase = "dump"
		return false
	if _phase == "dump":
		_dump()
		_printed = true
		quit(0)
	return false
func _capture() -> void:
	var gm = _al("GameManager")
	var tm = _al("TickManager")
	var sc = _al("SimulationClock")
	var jm = _al("JobManager")
	var sm = _al("SettlementMemory")
	var tick: int = int(gm.get("tick_count"))
	var target: float = float(sc.call("get_target_world_time_seconds")) if sc != null and sc.has_method("get_target_world_time_seconds") else 0.0
	var committed: float = float(sc.call("get_committed_world_time_seconds")) if sc != null and sc.has_method("get_committed_world_time_seconds") else 0.0
	var lag: float = target - committed
	var pa = _al("PawnAccess")
	var sp = _main.get("_pawn_spawner") if _main != null else null
	var alive: Array = []
	if pa != null and pa.has_method("find_alive_pawns"):
		alive = pa.call("find_alive_pawns")
	elif sp != null:
		alive = sp.get("pawns")
	var idle := 0
	var working := 0
	var can_work := 0
	for p in alive:
		if not is_instance_valid(p): continue
		var pd = p.get("data")
		if pd == null: continue
		var st: String = str(p.call("get_state_name")) if p.has_method("get_state_name") else ""
		if st == "Idle":
			idle += 1
			if pd.has_method("can_work") and bool(pd.call("can_work")):
				can_work += 1
		if st == "Working":
			working += 1
	var stats: Dictionary = jm.call("stats") if jm != null and jm.has_method("stats") else {}
	var open: int = int(stats.get("open",0))
	var claimed: int = int(stats.get("claimed",0))
	var attempts: int = int(stats.get("claim_attempts",0))
	var succ: int = int(stats.get("claim_successes",0))
	var dAtt := 0
	var dSucc := 0
	if _prev_attempts >= 0:
		dAtt = attempts - _prev_attempts
		dSucc = succ - _prev_success
	_prev_attempts = attempts
	_prev_success = succ
	var rate: float = float(dSucc)/float(max(1,dAtt))
	var open_by: Dictionary = {}
	if jm != null and jm.has_method("get_open_jobs_snapshot"):
		for j in jm.call("get_open_jobs_snapshot"):
			var t: int = int(j.type)
			open_by[t] = int(open_by.get(t,0))+1
	var formal: int = 0
	var proto: int = 0
	if sm != null:
		if sm.has_method("get_formal_settlements"):
			formal = int((sm.call("get_formal_settlements") as Array).size())
		if sm.has_method("get_proto_sites"):
			proto = int((sm.call("get_proto_sites") as Array).size())
	var zone: int = -1
	var food: int = -1
	var spm = _al("StockpileManager")
	if spm != null and spm.has_method("zone_count"):
		zone = int(spm.call("zone_count"))
		if spm.has_method("total_food"):
			food = int(spm.call("total_food"))
	var win: Dictionary = {"tick":tick, "alive":alive.size(), "idle":idle, "can_work":can_work, "working":working, "open":open, "claimed":claimed, "dAtt":dAtt, "dSucc":dSucc, "rate":rate, "formal":formal, "proto":proto, "zone":zone, "food":food, "lag":lag, "open_by":open_by}
	_windows.append(win)
	print("WIN tick=%d alive=%d idle=%d can_work=%d working=%d open=%d claimed=%d dAtt=%d dSucc=%d rate=%.2f formal=%d proto=%d zone=%d food=%d lag=%.1f by=%s" % [tick, alive.size(), idle, can_work, working, open, claimed, dAtt, dSucc, rate, formal, proto, zone, food, lag, str(open_by)])
	var is_stall := open>0 and can_work>0 and (claimed==0 or rate<0.02) and working==0
	if is_stall:
		_stall_streak += 1
		print("  STALL streak %d" % _stall_streak)
		if _stall_streak >= 3 and _first_bad<0:
			_first_bad = _windows.size()-1
			print(">>> FIRST BAD %d tick %d" % [_first_bad, tick])
	else:
		_stall_streak = 0
func _dump() -> void:
	print("=== FRESH_SOAK DUMP windows=%d first_bad=%d ===" % [_windows.size(), _first_bad])
	if _first_bad>=0:
		var lo: int = max(0, _first_bad-3)
		var hi: int = min(_windows.size()-1, _first_bad+2)
		for i in range(lo, hi+1):
			var w: Dictionary = _windows[i]
			var mark: String = ">>> BAD" if i==_first_bad else "   "
			print("%s WIN[%d] tick=%d alive=%d working=%d open=%d claimed=%d rate=%.2f formal=%d proto=%d food=%d lag=%.1f" % [mark, i, w["tick"], w["alive"], w["working"], w["open"], w["claimed"], w["rate"], w["formal"], w["proto"], w["food"], w["lag"]])
	else:
		print("No persisting stall in %d windows" % _windows.size())
		for i in range(max(0,_windows.size()-5), _windows.size()):
			var w: Dictionary = _windows[i]
			print("WIN[%d] tick=%d alive=%d working=%d open=%d claimed=%d rate=%.2f" % [i, w["tick"], w["alive"], w["working"], w["open"], w["claimed"], w["rate"]])
	print("=== END ===")
