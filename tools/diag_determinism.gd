extends SceneTree

## 02A determinism proof harness. Boots Main fenced and runs the world at a
## FIXED 1x speed (speed-invariance across runs is the design baseline; a
## mid-run speed change corrupts the comparison because pawn/system stride is
## tick-anchored. Tick-per-frame in this heavy world is budget-coupled to ~1,
## so tick anchors land identically run to run). Periodically (every
## FINGERPRINT_INTERVAL ticks, aligned to the same anchors in every run) it
## prints a semantic world fingerprint, and on completion prints the final
## fingerprint. Run twice with identical args and diff the outputs: identical
## anchor fingerprints prove the optimization is deterministic (same tick +
## seed + inputs => same truth).
##
## Permanent Tool Rule: this tool boots Main past the autosave boundary at any
## speed and MUST run with --playtest-no-save; it hard-refuses otherwise.

const RUN_TO_TICK := 2000
const FINGERPRINT_INTERVAL := 500
const FRAME_CAP := 20000

var _frame := 0
var _phase := "boot"
var _done := false
var _last_fingerprint_tick := 0

var _gm: Node = null
var _tm: Node = null
var _main: Node = null

func _al(name: String) -> Node:
	return root.get_node_or_null("/root/" + name)

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
		push_error("DETMOD: this tool boots Main and must run with --playtest-no-save; refusing to run")
		quit(1)
		return
	var packed: PackedScene = load("res://scenes/main/Main.tscn") as PackedScene
	if packed == null:
		push_error("DETMOD: cannot load Main.tscn")
		quit(1)
		return
	var main: Node = packed.instantiate()
	root.add_child(main)
	if not bool(main.get("_save_writes_disabled_for_playtest")):
		push_error("DETMOD: Main autosave fence not active; refusing to run")
		quit(1)

func _fingerprint() -> void:
	var lines: Array[String] = []
	lines.append("DETMOD anchor tick=%d" % int(_gm.get("tick_count")) if _gm != null else 0)
	var sm: Node = _al("SettlementMemory")
	if sm != null:
		var formal: int = int(sm.call("get_formal_settlement_count")) if sm.has_method("get_formal_settlement_count") else 0
		var proto: int = int(sm.get("_proto_sites").size()) if sm.get("_proto_sites") is Array else 0
		lines.append("formal=%d proto=%d" % [formal, proto])
		var sett: Array = sm.call("get_formal_settlements") if sm.has_method("get_formal_settlements") else []
		for s in sett:
			if s is Dictionary:
				lines.append("formal rk=%d reason=%s founding=%s" % [
					int(s.get("center_region", s.get("center_rk", -1))),
					str(s.get("founding_reason", "?")),
					str(s.get("founding_tick", "?")),
				])
	var sp: Node = _al("StockpileManager")
	if sp != null:
		lines.append("stockpile_zones=%d" % int(sp.call("zone_count")) if sp.has_method("zone_count") else 0)
		for item_type in range(1, 9):
			lines.append("stockpile_t%d=%d" % [item_type, int(sp.call("total_count_of", item_type)) if sp.has_method("total_count_of") else 0])
	var jm: Node = _al("JobManager")
	if jm != null:
		lines.append("jobs_open=%d" % int(jm.call("open_count")) if jm.has_method("open_count") else 0)
	var cs: Node = _al("ColonySimServices")
	if cs != null:
		lines.append("pressures housing=%.3f food=%.3f storage=%.3f warmth=%.3f cooking=%.3f" % [
			float(cs.call("get_housing_pressure")) if cs.has_method("get_housing_pressure") else 0.0,
			float(cs.call("get_food_pressure")) if cs.has_method("get_food_pressure") else 0.0,
			float(cs.call("get_storage_pressure")) if cs.has_method("get_storage_pressure") else 0.0,
			float(cs.call("get_warmth_pressure", -1)) if cs.has_method("get_warmth_pressure") else 0.0,
			float(cs.call("get_cooking_pressure", -1)) if cs.has_method("get_cooking_pressure") else 0.0,
		])
	var pawns: Array = get_nodes_in_group("pawns")
	var rows: Array[String] = []
	for p in pawns:
		var pd: RefCounted = p.get("data")
		if pd == null:
			continue
		var tile = pd.get("tile_pos")
		rows.append("p=%d tile=%s age=%d life=%s sid=%d hunger=%d thirst=%d rest=%d mood=%d" % [
			int(pd.get("id")), str(tile if tile != null else "?"),
			int(pd.get("age")), str(pd.get("life_stage")),
			int(pd.get("settlement_id")), int(pd.get("hunger")),
			int(pd.get("thirst")), int(pd.get("rest")), int(pd.get("mood")),
		])
	rows.sort()
	for r in rows:
		lines.append(r)
	for l in lines:
		print(l)

func _process(_delta: float) -> bool:
	if _done:
		return false
	_frame += 1
	if _frame > FRAME_CAP:
		_done = true
		print("DETMOD: frame cap reached (phase=%s tick=%d)" % [_phase, int(_gm.get("tick_count")) if _gm != null else -1])
		quit(1)
		return false
	if _gm == null:
		_gm = _al("GameManager")
	if _tm == null:
		_tm = _al("TickManager")
	if _gm == null:
		return false
	if _phase == "boot":
		_main = root.get_node_or_null("/root/Main")
		if _main != null:
			_phase = "run"
			if _tm != null and _tm.has_method("set_speed"):
				_tm.call("set_speed", 1.0)
			print("DETMOD: Main ready, running at fixed 1x to tick %d" % RUN_TO_TICK)
		return false
	if _phase == "run":
		var t: int = int(_gm.get("tick_count"))
		if t - _last_fingerprint_tick >= FINGERPRINT_INTERVAL:
			_last_fingerprint_tick = t
			print("DETMOD =================  fingerprint anchor  =================")
			_fingerprint()
		if t >= RUN_TO_TICK:
			_phase = "done"
			_gm.call("pause")
			var tm2: Node = root.get_node_or_null("/root/TickManager")
			if tm2 != null and tm2.has_method("pause"):
				tm2.call("pause")
			print("DETMOD =================  FINAL fingerprint  =================")
			_fingerprint()
			_done = true
			quit(0)
		return false
	return false