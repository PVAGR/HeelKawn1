extends SceneTree

const RUN_TICKS: int = 300
const SPEED: float = 100.0
const TIMEOUT_FRAMES: int = 12000

var _done: bool = false
var _main: Node = null

func _ready() -> void:
	var gm_hold: Node = root.get_node_or_null("GameManager")
	if gm_hold != null and gm_hold.has_method("pause"):
		gm_hold.call("pause")
	call_deferred("_spawn_main")

func _spawn_main() -> void:
	var packed: PackedScene = load("res://scenes/main/Main.tscn") as PackedScene
	if packed == null:
		push_error("[DIAG] Failed to load Main.tscn")
		quit(1)
		return
	_main = packed.instantiate()
	root.add_child(_main)
	var gm: Node = root.get_node_or_null("GameManager")
	if gm != null:
		if gm.has_method("set_game_tick_trace_enabled"):
			gm.call("set_game_tick_trace_enabled", false)
		else:
			gm.set("trace_game_tick_dispatch", false)
		gm.set_game_speed(SPEED)
		if gm.has_method("resume"):
			gm.call("resume")
		print("[DIAG] Speed=%0.0fx  waiting for tick %d..." % [SPEED, RUN_TICKS])

func _process(_delta: float) -> bool:
	if _done:
		return false
	if _main == null:
		return false
	var gm: Node = root.get_node_or_null("GameManager")
	if gm == null:
		return false
	var tick: int = int(gm.get("tick_count"))
	if tick >= RUN_TICKS:
		_done = true
		_dump_report(tick)
		quit(0)
		return true
	return false

func _dump_report(tick: int) -> void:
	print("\n========== PAWN DIAGNOSTIC ==========")
	print("Tick: %d  Speed: %0.0fx" % [tick, SPEED])

	var jm: Node = root.get_node_or_null("JobManager")
	if jm != null and jm.has_method("stats"):
		var s: Dictionary = jm.stats()
		print("\n-- Jobs --")
		print("  Open=%d Claimed=%d Completed=%d Cancelled=%d" % [
			int(s.get("open",0)), int(s.get("claimed",0)),
			int(s.get("completed",0)), int(s.get("cancelled",0))])
		var bt: Dictionary = s.get("by_type", {})
		if not bt.is_empty():
			for k in bt:
				print("  %s: %d" % [k, int(bt[k])])

	var ps: Node = _main.get_node_or_null("WorldViewport/PawnSpawner")
	if ps == null:
		print("[DIAG] No PawnSpawner")
		return
	var pawns: Array = ps.get("pawns") if "pawns" in ps else []
	print("\n-- Pawns (%d) --" % pawns.size())

	var idle_n: int = 0
	var work_n: int = 0
	var walk_n: int = 0
	var sleep_n: int = 0
	var eat_n: int = 0
	var other_n: int = 0

	for p in pawns:
		if p == null or not is_instance_valid(p):
			continue
		var d = p.data
		if d == null:
			continue
		var sv: int = p.get_state() if p.has_method("get_state") else 0
		var sn: String = _sn(sv)
		var hu: float = float(d.hunger)
		var re: float = float(d.rest)
		var jn: String = "none"
		if "_current_job" in p and p._current_job != null:
			jn = str(p._current_job.type)
		var tp: Vector2i = d.tile_pos
		var cr: String = " CARRY" if d.is_carrying() else ""

		if sv == 0: idle_n += 1
		elif sv == 1: work_n += 1
		elif sv == 2: walk_n += 1
		elif sv == 6: sleep_n += 1
		elif sv == 5: eat_n += 1
		else: other_n += 1

		print("  %s %s h=%.0f r=%.0f job=%s %s%s" % [d.display_name, sn, hu, re, jn, tp, cr])

	print("\n-- Summary --")
	print("  IDLE=%d WORK=%d WALK=%d SLEEP=%d EAT=%d OTHER=%d" % [idle_n, work_n, walk_n, sleep_n, eat_n, other_n])

	var sm: Node = root.get_node_or_null("StockpileManager")
	if sm != null and sm.has_method("total_food"):
		print("\n-- Stockpile --")
		print("  Food=%d" % sm.total_food())

	print("\n========== END ==========")

func _sn(s: int) -> String:
	if s == 0: return "IDLE"
	if s == 1: return "WORK"
	if s == 2: return "WALK"
	if s == 3: return "WALK_EAT"
	if s == 4: return "HAUL"
	if s == 5: return "EAT"
	if s == 6: return "SLEEP"
	if s == 7: return "GO_EAT"
	if s == 8: return "FETCH"
	if s == 9: return "DFORGE"
	if s == 10: return "FLEE"
	return "UNK"
