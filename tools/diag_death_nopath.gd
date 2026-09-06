extends SceneTree
const SAVE_PATH := "user://heelkawn_colony_autosave.sav"
var _gm: Node = null
var _main: Node = null
var _phase := "boot"
var _printed := false
var _wall0 := 0
var _tick_start := 0
var _last_alive: Dictionary = {} # id -> {name, hunger, health, tile, state, age}
var _death_log: Array[Dictionary] = []
var _abandon_log: Array[Dictionary] = []
var _abandon_count := 0

func _al(n: String) -> Node:
	return root.get_node_or_null("/root/" + n)

func _initialize() -> void:
	call_deferred("_spawn_main")

func _spawn_main() -> void:
	if not OS.get_cmdline_user_args().has("--playtest-no-save"):
		push_error("need fence")
		quit(1)
		return
	var packed: PackedScene = load("res://scenes/main/Main.tscn") as PackedScene
	var m: Node = packed.instantiate()
	root.add_child(m)
	if not bool(m.get("_save_writes_disabled_for_playtest")):
		push_error("fence not active")
		quit(1)

func _do_load() -> void:
	var gs: GDScript = load("res://scripts/save/GameSave.gd") as GDScript
	var d: Dictionary = gs.call("read_file", SAVE_PATH)
	if d.is_empty():
		print("save empty")
		return
	print("loading save tick=%d" % int(d.get("tick", -1)))
	_main.call("_apply_save_dict", d)
	var gm_tick: int = int(_gm.get("tick_count"))
	print("after load gm_tick=%d" % gm_tick)

func _process(_d: float) -> bool:
	if _printed:
		return false
	if _gm == null:
		_gm = _al("GameManager")
		return false
	if _phase == "boot":
		_main = root.get_node_or_null("/root/Main")
		if _main == null or _main.get("_pawn_spawner") == null:
			return false
		var spawner: Node = _main.get("_pawn_spawner")
		if spawner.get("pawns").is_empty():
			return false
		_phase = "load"
		_do_load()
		return false
	if _phase == "load":
		_phase = "run"
		_wall0 = Time.get_ticks_usec()
		_tick_start = int(_gm.get("tick_count"))
		_cache_alive()
		# Hook abandon: connect to JobManager abandon? Monitor via polling stats
		# Instead poll abandon count via JobManager stats
		_gm.call("set_speed", 26.0)
		if _gm.has_method("resume"):
			_gm.call("resume")
		print("DEATH_NOPATH: start tick=%d run 26x for 600 ticks" % _tick_start)
		return false
	if _phase == "run":
		var cur: int = int(_gm.get("tick_count"))
		# Poll abandons via stats
		var jm: Node = _al("JobManager")
		if jm != null:
			var stats: Dictionary = jm.call("stats") if jm.has_method("stats") else {}
			var ab_reasons: Dictionary = stats.get("abandon_reasons", {})
			var nopath: int = int(ab_reasons.get("no_path_to_resource", 0))
			if nopath > _abandon_count:
				# New abandons occurred, log details of recent jobs? Hard to get job details
				# We will instead hook via monitoring pawn abandon calls by checking pawn current job?
				_abandon_count = nopath
		# Check deaths
		_check_deaths()
		# Cache current alive for next tick
		_cache_alive()
		if cur >= _tick_start + 600:
			_phase = "dump"
			if _gm.has_method("pause"):
				_gm.call("pause")
			return false
		if Time.get_ticks_usec() - _wall0 > 120_000_000:
			print("wall budget")
			_phase = "dump"
			return false
		return false
	if _phase == "dump":
		_dump()
		_printed = true
		quit(0)
	return false

func _cache_alive() -> void:
	var pa: Node = _al("PawnAccess")
	var pawns: Array = pa.call("find_alive_pawns") if pa != null and pa.has_method("find_alive_pawns") else []
	_last_alive.clear()
	for p in pawns:
		if p == null or not is_instance_valid(p):
			continue
		var pd = p.get("data")
		if pd == null:
			continue
		var pid: int = int(pd.get("id"))
		_last_alive[pid] = {
			"name": str(pd.get("display_name")),
			"hunger": float(pd.get("hunger")),
			"health": float(pd.get("health")),
			"age": float(pd.get("age_years")),
			"tile": pd.get("tile_pos"),
			"state": str(p.call("get_state_name")) if p.has_method("get_state_name") else str(p.get("_state")),
			"job": str(p.get("_current_job").type) if p.get("_current_job") != null else "none",
			"sid": int(pd.get("settlement_id")),
		}

func _check_deaths() -> void:
	var pa: Node = _al("PawnAccess")
	var pawns: Array = pa.call("find_alive_pawns") if pa != null and pa.has_method("find_alive_pawns") else []
	var cur_ids: Dictionary = {}
	for p in pawns:
		if p == null or not is_instance_valid(p):
			continue
		var pd = p.get("data")
		if pd == null:
			continue
		cur_ids[int(pd.get("id"))] = true
	for pid in _last_alive.keys():
		if not cur_ids.has(pid):
			var last: Dictionary = _last_alive[pid]
			var tick: int = int(_gm.get("tick_count"))
			_death_log.append({
				"tick": tick,
				"pid": pid,
				"name": last["name"],
				"age": last["age"],
				"health": last["health"],
				"hunger": last["hunger"],
				"tile": last["tile"],
				"state": last["state"],
				"job": last["job"],
				"sid": last["sid"],
			})
			print("DEATH tick=%d id=%d %s age=%.1f health=%.1f hunger=%.1f tile=%s state=%s job=%s sid=%d" % [tick, pid, last["name"], last["age"], last["health"], last["hunger"], str(last["tile"]), last["state"], last["job"], last["sid"]])

func _dump() -> void:
	print("=== DEATH_NOPATH DUMP ===")
	print("deaths %d" % _death_log.size())
	var by_reason: Dictionary = {}
	for d in _death_log:
		# Try to get actual death cause from WorldMemory or pawn data? For now use health/hunger heuristic
		var cause: String = "unknown"
		if float(d["health"]) <= 0.0:
			cause = "health0"
		elif float(d["hunger"]) <= 0.0:
			cause = "starvation_hunger<=0"
		elif float(d["hunger"]) < 20.0:
			cause = "starvation_low_hunger"
		else:
			cause = "other_health%.0f_hunger%.0f" % [float(d["health"]), float(d["hunger"])]
		by_reason[cause] = int(by_reason.get(cause, 0)) + 1
		print("  death id=%d %s tick=%d age%.1f health%.1f hunger%.1f tile%s state%s" % [d["pid"], d["name"], d["tick"], float(d["age"]), float(d["health"]), float(d["hunger"]), str(d["tile"]), d["state"]])
	print("death_reason_counts=%s" % str(by_reason))
	# Abandon stats
	var jm: Node = _al("JobManager")
	if jm != null and jm.has_method("stats"):
		var stats: Dictionary = jm.call("stats")
		print("abandon_reasons=%s" % str(stats.get("abandon_reasons", {})))
		print("cancel_reasons=%s" % str(stats.get("cancel_reasons", {})))
		print("open=%d claimed=%d" % [int(stats.get("open",0)), int(stats.get("claimed",0))])
	# Check work_tile mutations
	print("=== WORK_TILE MUTATION AUDIT ===")
	var c: int = 0
	for p in _al("PawnAccess").call("find_alive_pawns"):
		if p == null:
			continue
		var pd = p.get("data")
		if pd == null:
			continue
		c += 1
		if c > 5:
			break
	print("alive sample %d pawns" % c)
	print("=== END ===")

func _audit_work_tile() -> void:
	# Search all Job work_tile assignments after posting
	pass
