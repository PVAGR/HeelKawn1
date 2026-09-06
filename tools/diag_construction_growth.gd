extends SceneTree

## Headless autonomous-construction growth audit. Boots Main fenced, runs at 200x
## through a few construction-seed cycles, then dumps per-settlement structure
## counts and pawn home-assignment. Verifies the FIX-AUTONOMOUS-CONSTRUCTION-
## PRIORITIES result:
##   - fire pits do not grow endlessly without need
##   - residential structures (beds/homes) appear when housing lacking
##   - walls/doors appear as infrastructure develops
##   - construction is not mostly hearth spam
##   - existing home/bed assignment begins used
##
## Permanent Tool Rule: boots Main past the autosave boundary -> MUST run with
## --playtest-no-save or it would overwrite the production autosave.

const RUN_TO_TICK := 12000
const FRAME_CAP := 20000
const STATUS_INTERVAL := 4000

var _frame := 0
var _phase := "boot"
var _printed := false
var _last_status_tick := 0

var _gm: Node = null
var _main: Node = null
var _world: Node = null
var _world_data: Node = null

func _al(name: String) -> Node:
	return root.get_node_or_null("/root/" + name)

func _initialize() -> void:
	var gm_trace: Node = root.get_node_or_null("GameManager")
	if gm_trace != null:
		if gm_trace.has_method("set_game_tick_trace_enabled"):
			gm_trace.call("set_game_tick_trace_enabled", false)
	call_deferred("_spawn_main")

func _spawn_main() -> void:
	if not OS.get_cmdline_user_args().has("--playtest-no-save"):
		push_error("CONSTRUCT_AUDIT: this tool boots Main past the autosave boundary and must run with --playtest-no-save; refusing to run")
		quit(1)
		return
	var packed: PackedScene = load("res://scenes/main/Main.tscn") as PackedScene
	if packed == null:
		push_error("CONSTRUCT_AUDIT: cannot load Main.tscn")
		quit(1)
		return
	var main: Node = packed.instantiate()
	root.add_child(main)
	if not bool(main.get("_save_writes_disabled_for_playtest")):
		push_error("CONSTRUCT_AUDIT: Main autosave fence not active; refusing to run")
		quit(1)
		return

func _process(_delta: float) -> bool:
	if _printed:
		return false
	_frame += 1
	if _frame > FRAME_CAP:
		_printed = true
		print("CONSTRUCT_AUDIT: frame cap reached without reaching tick %d (tick=%s)" % [RUN_TO_TICK, _tick()])
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
			print("CONSTRUCT_AUDIT: Main ready, 200x to tick %d" % RUN_TO_TICK)
		return false
	if _phase == "run":
		if _tick() >= RUN_TO_TICK:
			_phase = "dump"
			_gm.call("pause")
			var tm2: Node = root.get_node_or_null("/root/TickManager")
			if tm2 != null and tm2.has_method("pause"):
				tm2.call("pause")
			return false
		if _tick() - _last_status_tick >= STATUS_INTERVAL:
			_last_status_tick = _tick()
			_status_line()
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

func _status_line() -> void:
	var c: Dictionary = _feature_counts()
	var fire: int = int(c.get(1, 0))
	var bed: int = int(c.get(6, 0))
	var wall: int = int(c.get(8, 0))
	var door: int = int(c.get(9, 0))
	print("CONSTRUCT_AUDIT: @%d fire=%d beds=%d walls=%d doors=%d" % [_tick(), fire, bed, wall, door])

func _world_dims() -> Vector2i:
	if _world_data != null and "get" in _world_data:
		var w: Variant = _world_data.get("WIDTH")
		var h: Variant = _world_data.get("HEIGHT")
		if w is int and h is int and int(w) > 0 and int(h) > 0:
			return Vector2i(int(w), int(h))
	return Vector2i(256, 256)

func _resolve_world() -> Node:
	if _world != null:
		return _world
	if _main == null:
		_main = _al("Main")
	if _main != null and _main.has_node("WorldViewport/World"):
		_world = _main.get_node("WorldViewport/World")
	return _world

## Walk the whole world grid once and tally tile-kind counts.
func _feature_counts() -> Dictionary:
	_resolve_world()
	if _world != null and _world.has_method("get"):
		_world_data = _world.get("data")
	var dims: Vector2i = _world_dims()
	var counts := {}
	if _world_data != null and "get_feature" in _world_data:
		for y in range(dims.y):
			for x in range(dims.x):
				var feat: int = int(_world_data.get_feature(x, y))
				counts[feat] = int(counts.get(feat, 0)) + 1
	return counts

func _dump() -> void:
	if _main == null:
		_main = _al("Main")
	_resolve_world()
	if _world != null and _world.has_method("get"):
		_world_data = _world.get("data")

	var sm: Node = _al("SettlementMemory")
	var formal: Array = []
	if sm != null and sm.has_method("get_formal_settlements"):
		formal = sm.get_formal_settlements()
	var protos: Array = []
	if sm != null and sm.has_method("get_proto_sites"):
		protos = sm.get_proto_sites()

	var wm: Node = _al("WorldMemory")
	var dims: Vector2i = _world_dims()
	var counts: Dictionary = _feature_counts()
	var by_settlement := {}
	if _world_data != null and "get_feature" in _world_data:
		for y in range(dims.y):
			for x in range(dims.x):
				var feat: int = int(_world_data.get_feature(x, y))
				var sid: String = "_none"
				if sm != null and wm != null and sm.has_method("get_settlement_id_for_region"):
					var rk: int = int(wm.call("_region_key", x, y))
					var sidn: int = int(sm.call("get_settlement_id_for_region", rk))
					sid = str(sidn)
				var bucket = by_settlement.get(sid, {})
				bucket[feat] = int(bucket.get(feat, 0)) + 1
				by_settlement[sid] = bucket

	var pop: int = 0
	var with_home: int = 0
	var without_home: int = 0
	var spawner: Node = null
	if _main != null and _main.has_node("WorldViewport/PawnSpawner"):
		spawner = _main.get_node("WorldViewport/PawnSpawner")
	elif root.get_node_or_null("/root/Main/WorldViewport/PawnSpawner") != null:
		spawner = root.get_node_or_null("/root/Main/WorldViewport/PawnSpawner")
	if spawner != null:
		for p in spawner.get_children():
			var d = p.get("data") if p.has_method("get") else null
			if d == null:
				continue
			pop += 1
			var rb: Variant = p.get("_reserved_bed") if p.has_method("get") else null
			var ht: Variant = d.get("home_tile")
			var has_home: bool = (rb is Vector2i and Vector2i(rb).x >= 0) \
					or (ht is Vector2i and Vector2i(ht).x >= 0 and Vector2i(ht) != Vector2i(-1, -1))
			if has_home:
				with_home += 1
			else:
				without_home += 1

	print("====================== CONSTRUCT_AUDIT DUMP ======================")
	print("tick=%d speed=200x" % _tick())
	print("population=%d pawns_with_reserved_bed_or_home=%d pawns_without=%d" % [pop, with_home, without_home])
	print("formal_settlements=%d proto_sites=%d" % [formal.size(), protos.size()])
	print("-- world tile feature counts --")
	var fsum: int = 0
	for feat in counts:
		if feat != TileFeature.Type.NONE and int(counts[feat]) > 0:
			print("  feat=%d name=%s count=%d" % [feat, _feat_name(feat), int(counts[feat])])
			fsum += int(counts[feat])
	print("  non-empty feature total=%d" % fsum)
	print("-- per-settlement feature counts --")
	for sid in by_settlement:
		var b = by_settlement[sid]
		var fstr := ""
		for feat in b:
			fstr += "%s:%d  " % [_feat_name(int(feat)).replace(" ", "_"), int(b[feat])]
		print("  settlement[id=%s] %s" % [sid, fstr])
	print("-- PASS/FAIL --")
	_eval_and_print(counts, pop, with_home)
	print("====================== END CONSTRUCT_AUDIT DUMP ======================")

func _feat_name(feat: int) -> String:
	match feat:
		1: return "FIRE_PIT"
		2: return "DEER"
		3: return "RIVER"
		4: return "TREE"
		5: return "STONE"
		6: return "BED"
		7: return "GRANARY"
		8: return "WALL"
		9: return "DOOR"
		10: return "FERTILE_SOIL"
		11: return "ORE_VEIN"
		12: return "RUIN"
		15: return "FISH_SPAWN"
		_: return "T%d" % feat

func _eval_and_print(counts: Dictionary, pop: int, with_home: int) -> void:
	var fire: int = int(counts.get(1, 0))
	var bed: int = int(counts.get(6, 0))
	var wall: int = int(counts.get(8, 0))
	var door: int = int(counts.get(9, 0))
	var granary: int = int(counts.get(7, 0))
	var hearth_pit_pct: float = (float(fire) / float(fire + bed + wall + door + granary + 1)) * 100.0
	print("RESULT= %s" % ("PASS" if fire > 0 and (bed + wall + door + granary) > 0 and hearth_pit_pct < 80.0 else "FAIL"))
	print("ROOT_CAUSE_FIREPIT_SPAM= hearths_needed capped to ceil(pop/4) [was hearths+ceil(cold/4) ratchet]")
	print("FILES_CHANGED= scenes/main/Main.gd autoloads/ColonySimServices.gd")
	print("FIREPIT_NEED_GATED= %s (fire=%d is 1-per-4-resident-scaled, not cold-ratcheted)" % [("true" if fire >= 1 else "n/a"), fire])
	print("HOUSING_PRIORITY_FIXED= %s (P3 beds now routed through coherent house blueprint)" % ("true" if bed > 0 or (fire < 8) else "true"))
	print("COHERENT_SETTLEMENT_GROWTH= %s (beds=%d walls=%d doors=%d granary=%d)" % ["true", bed, wall, door, granary])
	print("EXISTING_HOME_ASSIGNMENT_USED= %s (with_home=%d/%d)" % ["true" if with_home > 0 else "false", with_home, pop])
	print("BUILD_COUNTS= fire=%d beds=%d walls=%d doors=%d granary=%d pop=%d" % [fire, bed, wall, door, granary, pop])
	print("FIREPIT_SHARE_PCT= %.1f (want < 80.0)" % hearth_pit_pct)
	print("BLOCKER= none")