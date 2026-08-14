extends SceneTree

## Headless F10 truth-pass sweep: boots Main, advances the sim a little, then
## invokes every CreatorDebugMenu report handler. Progress and per-panel
## results are written to a file so buffering cannot hide where it stops.
##
## Run: Godot --path . -s res://tools/f10_panels_sweep.gd --headless

const OUT_PATH: String = "res://logs/f10_sweep_results.txt"
const SWEEP_TARGET_TICK: int = 8
const MAX_WALL_MS: int = 60000

var _main: Node = null
var _menu: Node = null
var _done: bool = false
var _started_wall_ms: int = 0
var _invoked: Array[String] = []
var _errored: Array[String] = []


func _log(line: String) -> void:
	var f: FileAccess = FileAccess.open(OUT_PATH, FileAccess.READ_WRITE)
	if f == null:
		f = FileAccess.open(OUT_PATH, FileAccess.WRITE)
	if f != null:
		f.seek_end()
		f.store_string(line + "\n")
		f.flush()
		f.close()
	print(line)


func _ready() -> void:
	pass


func _initialize() -> void:
	var gm: Node = root.get_node_or_null("GameManager")
	if gm != null and gm.has_method("pause"):
		gm.call("pause")
	if gm != null and gm.has_method("set_game_tick_trace_enabled"):
		gm.call("set_game_tick_trace_enabled", false)
	_log("[F10_SWEEP] initialize")
	call_deferred("_spawn_main")


func _spawn_main() -> void:
	var packed: PackedScene = load("res://scenes/main/Main.tscn") as PackedScene
	if packed == null:
		_log("[F10_SWEEP] FAIL load Main.tscn")
		quit(1)
		return
	_main = packed.instantiate()
	root.add_child(_main)
	_menu = _main.get_node_or_null("CreatorDebugMenu")
	if _menu == null:
		_log("[F10_SWEEP] FAIL CreatorDebugMenu not found")
		quit(1)
		return
	_started_wall_ms = Time.get_ticks_msec()
	_log("[F10_SWEEP] Main instantiated; awaiting tick %d" % SWEEP_TARGET_TICK)


func _process(_delta: float) -> bool:
	if _done:
		return false
	if _main == null or _menu == null:
		return false
	if Time.get_ticks_msec() - _started_wall_ms > MAX_WALL_MS:
		_log("[F10_SWEEP] Wall cap reached; forcing sweep")
		_run_sweep()
		return true
	var gm: Node = root.get_node_or_null("GameManager")
	if gm == null:
		return false
	var tick: int = int(gm.get("tick_count"))
	if tick < SWEEP_TARGET_TICK:
		return false
	_log("[F10_SWEEP] tick=%d reached; starting sweep" % tick)
	_run_sweep()
	return true


func _run_sweep() -> void:
	var ids: Array[String] = _collect_report_ids()
	_log("[F10_SWEEP] PANEL_COUNT=%d" % ids.size())
	for rid in ids:
		_call_panel(rid)
	_log("[F10_SWEEP] DONE invoked=%d errored=%d" % [_invoked.size(), _errored.size()])
	_log("[F10_SWEEP] ERRED=%s" % str(_errored))
	_done = true
	if _errored.is_empty():
		quit(0)
	else:
		quit(2)


func _collect_report_ids() -> Array[String]:
	var out: Array[String] = []
	var sections: Array = _menu.get("DEBUG_SECTIONS")
	if sections is Array:
		for sec in sections:
			if sec is Dictionary and sec.get("rows") is Array:
				for row in sec.get("rows", []):
					if row is Dictionary:
						var rid: String = str(row.get("id", ""))
						if not rid.is_empty() and not out.has(rid):
							out.append(rid)
	return out


func _call_panel(rid: String) -> void:
	_menu.set("_last_report_wall_time", 0.0)
	_menu.set("_last_report_tick", -1)
	_menu.set("_last_report_key", "")
	var before: int = Time.get_ticks_msec()
	_menu.call("_emit_report", rid)
	var elapsed_ms: int = Time.get_ticks_msec() - before
	_invoked.append(rid)
	_log("[F10_SWEEP] PANEL=%-28s %6dms" % [rid, elapsed_ms])
