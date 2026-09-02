extends SceneTree

## Headless soak + state dump: boots Main.tscn, accelerates to 200x, runs to a
## target tick, then dumps REAL world facts (pawns, settlements, jobs, veils)
## and quits cleanly. Crashes (SCRIPT ERROR) will surface in stderr.
## Run: Godot --headless --path . -s res://tools/soak_state_dump.gd
##
## NOTE: -s SceneTree scripts have NO _enter_tree virtual. Spawn from the first
## _process frame instead (sim_mature_profiler.gd had this latent bug).

const TARGET_TICK: int = 4000
const TIMEOUT_FRAMES: int = 120000
const PROFILE_SPEED: float = 200.0
const BOOT_WAIT_FRAMES: int = 30

var _done: bool = false
var _spawned: bool = false
var _boot_wait: int = -1
var _started: bool = false
var _frame_count: int = 0

func _process(_delta: float) -> bool:
	if _done:
		return false
	if not _spawned:
		_spawned = true
		_spawn_main()
		return false
	if _boot_wait > 0:
		_boot_wait -= 1
		if _boot_wait == 0:
			_begin()
		return false
	if not _started:
		return false
	_frame_count += 1
	if _frame_count > TIMEOUT_FRAMES:
		_dump_state("frame_limit")
		_done = true
		quit(1)
		return true
	var gm: Node = root.get_node_or_null("GameManager")
	if gm == null:
		return false
	var tick: int = int(gm.get("tick_count"))
	if tick >= TARGET_TICK:
		_dump_state("target_reached")
		_done = true
		quit(0)
		return true
	return false

func _spawn_main() -> void:
	var packed: PackedScene = load("res://scenes/main/Main.tscn") as PackedScene
	if packed == null:
		print("[SOAK] FAIL reason=Main_load_failed")
		quit(1)
		return
	var main: Node = packed.instantiate()
	root.add_child(main)
	print("[SOAK] main_added name=%s in_root=%s" % [main.name, root.get_node_or_null("Main") != null])
	var tm: Node = root.get_node_or_null("TickManager")
	if tm != null and tm.has_method("resume"):
		tm.call("resume")
	var gm: Node = root.get_node_or_null("GameManager")
	if gm != null and gm.has_method("resume"):
		gm.call("resume")
	_boot_wait = BOOT_WAIT_FRAMES

func _begin() -> void:
	var tm: Node = root.get_node_or_null("TickManager")
	if tm != null and tm.has_method("set_speed"):
		tm.call("set_speed", PROFILE_SPEED)
	_started = true
	print("[SOAK] START profile_speed=%.0fx target_tick=%d" % [PROFILE_SPEED, TARGET_TICK])

func _dump_state(reason: String) -> void:
	var gm: Node = root.get_node_or_null("GameManager")
	var tick: int = int(gm.get("tick_count")) if gm != null else -1
	var days: int = int(gm.get("days_elapsed")) if gm != null and gm.get("days_elapsed") != null else -1
	var main: Node = root.get_node_or_null("Main")
	if main != null:
		var names: Array = []
		for c in main.get_children():
			names.append(c.name)
		print("[SOAK] Main children=%s" % [names])
		var wv: Node = main.get_node_or_null("WorldViewport")
		if wv != null:
			var wv_names: Array = []
			for c in wv.get_children():
				wv_names.append(c.name)
			print("[SOAK] WorldViewport children=%s" % [wv_names])
	var sm: Node = root.get_node_or_null("SettlementMemory")
	var jm: Node = root.get_node_or_null("JobManager")
	var vs: Node = root.get_node_or_null("VeilSystem")
	var ps: Node = root.get_node_or_null("Main/WorldViewport/PawnSpawner")
	var pawn_count: int = ps.get_child_count() if ps != null else -1
	var formal: int = int(sm.call("get_formal_settlement_count")) if sm != null and sm.has_method("get_formal_settlement_count") else -1
	var proto: int = 0
	if sm != null and sm.has_method("get_proto_sites"):
		proto = (sm.call("get_proto_sites") as Array).size()
	var open_jobs: int = int(jm.call("open_count")) if jm != null and jm.has_method("open_count") else -1
	var claimed: int = -1
	if jm != null:
		var cl = jm.get("_claimed")
		if cl != null:
			claimed = (cl as Array).size()
	var thin: int = int(vs.get("_thin_spots").size()) if vs != null and vs.get("_thin_spots") != null else -1
	var rends: int = int(vs.get("_rends").size()) if vs != null and vs.get("_rends") != null else -1
	print("[SOAK] DUMP reason=%s tick=%d days=%d pawns=%d formal=%d proto=%d open_jobs=%d claimed_jobs=%d thin_spots=%d rends=%d" % [
		reason, tick, days, pawn_count, formal, proto, open_jobs, claimed, thin, rends,
	])
	if sm != null:
		var sites: Array = sm.call("get_proto_sites")
		for st in sites.slice(0, 12):
			var st_d: Dictionary = st
			print("[SOAK]   proto: name=%s region=%s members=%d stable_%d reason=%s" % [
				st_d.get("name", "?"),
				st_d.get("center_region", -1),
				int(st_d.get("guild_member_count", -1)),
				int(st_d.get("guild_candidate_stability_ticks", -1)),
				st_d.get("guild_candidate_reason", "?"),
			])
	if formal > 0 and sm != null:
		print("[SOAK]   formal_settlements=%s" % [sm.call("get_formal_settlements")])
	if ps != null and pawn_count > 0:
		var ids: Array = []
		for i in mini(pawn_count, 40):
			var p: Node = ps.get_child(i)
			var d: Variant = p.get("data")
			if d != null and d is Dictionary:
				ids.append("%s@%s" % [d.get("id", "?"), d.get("display_name", "?")])
		print("[SOAK]   pawns=%s" % [ids])