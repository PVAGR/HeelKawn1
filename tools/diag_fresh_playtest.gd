extends SceneTree
var _gm: Node = null
var _main: Node = null
var _phase := "boot"
var _printed := false
var _wall0 := 0
func _al(n: String) -> Node: return root.get_node_or_null("/root/" + n)
func _initialize() -> void: call_deferred("_spawn_main")
func _spawn_main() -> void:
	if not OS.get_cmdline_user_args().has("--playtest-no-save"): push_error("need fence"); quit(1); return
	var packed: PackedScene = load("res://scenes/main/Main.tscn") as PackedScene
	var m: Node = packed.instantiate()
	root.add_child(m)
	if not bool(m.get("_save_writes_disabled_for_playtest")): push_error("fence not active"); quit(1)
func _process(_d: float) -> bool:
	if _printed: return false
	if _gm == null: _gm = _al("GameManager"); return false
	if _phase == "boot":
		_main = root.get_node_or_null("/root/Main")
		if _main == null or _main.get("_pawn_spawner") == null: return false
		if _main.get("_pawn_spawner").get("pawns").is_empty(): return false
		_gm.call("set_speed", 26.0)
		_wall0 = Time.get_ticks_usec()
		_phase = "run"
		print("FRESH_PLAYTEST start 26x")
		return false
	if _phase == "run":
		var tick: int = int(_gm.get("tick_count"))
		if tick >= 8000 or Time.get_ticks_usec() - _wall0 > 60_000_000:
			_phase = "dump"
			_gm.call("pause")
			return false
		return false
	if _phase == "dump":
		var jm: Node = _al("JobManager")
		var stats: Dictionary = jm.call("stats") if jm != null and jm.has_method("stats") else {}
		var open: int = int(stats.get("open",0))
		var claimed: int = int(stats.get("claimed",0))
		var succ: int = int(stats.get("claim_successes",0))
		var att: int = int(stats.get("claim_attempts",0))
		var ab: Dictionary = stats.get("abandon_reasons",{})
		var nopath: int = int(ab.get("no_path_to_resource",0))
		var pa: Node = _al("PawnAccess")
		var alive: Array = pa.call("find_alive_pawns") if pa != null and pa.has_method("find_alive_pawns") else []
		var working: int = 0
		var idle: int = 0
		for p in alive:
			var s: String = str(p.call("get_state_name")) if p.has_method("get_state_name") else ""
			if s == "Working": working += 1
			elif s == "Idle": idle += 1
		var food: int = -1
		var spm: Node = _al("StockpileManager")
		if spm != null and spm.has_method("total_food"): food = int(spm.call("total_food"))
		var proto: int = 0
		var formal: int = 0
		var sm: Node = _al("SettlementMemory")
		if sm != null:
			if sm.has_method("get_proto_sites"): proto = int((sm.call("get_proto_sites") as Array).size())
			if sm.has_method("get_formal_settlements"): formal = int((sm.call("get_formal_settlements") as Array).size())
		# duplicate IDs
		var ids: Dictionary = {}
		var dups: int = 0
		for p in alive:
			var pid: int = int(p.get("data").get("id"))
			if ids.has(pid): dups += 1
			else: ids[pid] = true
		print("FRESH_PLAYTEST tick=%d alive=%d idle=%d working=%d open=%d claimed=%d succ=%d att=%d rate=%.2f nopath=%d food=%d proto=%d formal=%d dups=%d" % [int(_gm.get("tick_count")), alive.size(), idle, working, open, claimed, succ, att, float(succ)/max(1,att), nopath, food, proto, formal, dups])
		var pass_gate: bool = alive.size() >= 15 and succ > 0 and float(succ)/max(1,att) > 0.5 and nopath < 50 and dups == 0 and working >= 1
		print("GATE pass=%s" % str(pass_gate))
		_printed = true
		quit(0 if pass_gate else 1)
	return false
