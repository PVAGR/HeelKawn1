extends SceneTree

## Regression: Main/CreatorDebugMenu? no — Main._on_world_tick -> Main._on_game_tick
## must record ecology wildfires via the CANONICAL ChronicleLog API
## (append_entry), not the fictional `log_event`. Regression for the live tick-path
## error:
##     Invalid call. Nonexistent function 'log_event' in base 'Node (ChronicleLog.gd)'.
##
## Proves, against real autoloads and real Main:
##   1. the exact recording path runs without Invalid-call
##   2. the event is actually PERSISTED into ChronicleLog.entries (not swallowed)
##   3. the payload schema matches ChronicleLog's canonical entry contract
##      {tick: int, zone_id: String, message: String, tags: PackedStringArray}
##   4. repeated tick execution remains valid (two consecutive wildfire lanes)
##   5. the entry survives to_save_dict()/from_save_dict() round-trip
##
## IMPORTANT: like the F10 tool this must NOT statically reference the
## `HeelKawnian` class_name (compiles before autoloads register).
##
## Run: Godot --path . -s res://tools/chronicle_contract_regression.gd --headless

const BOOT_TICK_TARGET: int = 20
const WILDFIRE_LANE_INTERVAL: int = 500
const WILDFIRE_LANE_SALT: int = 41
const MAX_WALL_MS: int = 120000

var _main: Node = null
var _done: bool = false
var _started_wall_ms: int = 0
var _all_ok: bool = true


func _log(line: String) -> void:
	print("[CHRON_REGRESS] %s" % line)


func _fail(line: String) -> void:
	_all_ok = false
	print("[CHRON_REGRESS] FAIL %s" % line)


func _initialize() -> void:
	var gm: Node = root.get_node_or_null("GameManager")
	if gm != null:
		if gm.has_method("set_game_tick_trace_enabled"):
			gm.call("set_game_tick_trace_enabled", false)
		if gm.has_method("set_game_speed"):
			gm.call("set_game_speed", 1)
	_log("initialize; booting Main")
	call_deferred("_spawn_main")


func _spawn_main() -> void:
	var packed: PackedScene = load("res://scenes/main/Main.tscn") as PackedScene
	if packed == null:
		_fail("could not load Main.tscn")
		quit(1)
		return
	_main = packed.instantiate()
	root.add_child(_main)
	_started_wall_ms = Time.get_ticks_msec()
	_log("Main instantiated; awaiting percent real boot (tick %d)" % BOOT_TICK_TARGET)


func _collect_heels() -> Array:
	var pawns_node: Node = _main.get_node_or_null("WorldViewport/PawnSpawner")
	var out: Array = []
	if pawns_node == null:
		return out
	for child in pawns_node.get_children():
		if child != null and child.get("data") != null and child.has_method("get_pawn_data"):
			out.append(child)
	return out


func _process(_delta: float) -> bool:
	if _done:
		return false
	if _main == null:
		return false
	if Time.get_ticks_msec() - _started_wall_ms > MAX_WALL_MS:
		_fail("wall cap reached before boot")
		_finish()
		return true
	var gm: Node = root.get_node_or_null("GameManager")
	if gm == null:
		return false
	var tick: int = int(gm.get("tick_count"))
	if tick < BOOT_TICK_TARGET or _collect_heels().is_empty():
		return false
	_run_jam()
	return true


## Pause the sim, plant real pending wildfire events at two consecutive wildfire
## lane ticks (tick ≡ -41 mod 500, i.e. 459/959/...), then drive the EXACT
## Main path `_on_world_tick -> _on_game_tick -> ecology block -> ChronicleLog`.
func _run_jam() -> void:
	gm_pause()
	var lane: int = 459
	while lane <= int(root.get_node_or_null("GameManager").get("tick_count")):
		lane += WILDFIRE_LANE_INTERVAL

	_log("pause@tick=%d; planting wildfire event at lane %d" % [int(root.get_node_or_null("GameManager").get("tick_count")), lane])
	var eco: Node = root.get_node_or_null("EcologySystem")
	if eco == null:
		_fail("EcologySystem autoload missing")
		_finish()
		return

	var chronicle: Node = root.get_node_or_null("ChronicleLog")
	if chronicle == null:
		_fail("ChronicleLog autoload missing")
		_finish()
		return

	var events_before: int = chronicle.get("entries").size()

	## Frame 0 of the original crash. First wildfire lane.
	eco._pending_events.append({
		"type": "wildfire",
		"tick": lane,
		"new_fires": 1,
		"total_active": 3,
	})
	_log("pending_events after plant = %s" % str(eco.get("_pending_events")))
	_main.call("_on_world_tick", lane)
	_log("entries after lane %d = %d" % [lane, chronicle.get("entries").size()])
	_check_entry(chronicle, events_before, 1, lane, 3)

	## Frame 0 again. Second wildfire lane — repeated tick execution.
	eco._pending_events.append({
		"type": "wildfire",
		"tick": lane + WILDFIRE_LANE_INTERVAL,
		"new_fires": 2,
		"total_active": 5,
	})
	_main.call("_on_world_tick", lane + WILDFIRE_LANE_INTERVAL)
	_log("entries after lane %d = %d" % [lane + WILDFIRE_LANE_INTERVAL, chronicle.get("entries").size()])
	_check_entry(chronicle, events_before, 2, lane + WILDFIRE_LANE_INTERVAL, 5)

	## Persistence: round-trip through the save schema.
	var save_dict: Dictionary = chronicle.call("to_save_dict")
	chronicle.call("from_save_dict", save_dict)
	var reloaded: Array = chronicle.get("entries")
	if reloaded.size() < events_before + 2:
		_fail("save/load round-trip dropped entries: %d -> %d" % [events_before + 2, reloaded.size()])
	else:
		_log("round-trip preserved entries (total now %d)" % reloaded.size())
	_finish()


func _check_entry(chronicle: Node, events_before: int, expected_delta: int, expect_tick: int, expect_fires: int) -> void:
	var entries: Array = chronicle.get("entries")
	if entries.size() != events_before + expected_delta:
		_fail("entries delta mismatch: got +%d, expected +%d" % [entries.size() - events_before, expected_delta])
		return
	var e: Dictionary = entries.back() as Dictionary
	if int(e.get("tick", -1)) != expect_tick:
		_fail("entry.tick=%s expected %d" % [str(e.get("tick")), expect_tick])
	var zone: String = str(e.get("zone_id", ""))
	if zone != "world":
		_fail("entry.zone_id='%s' expected 'world'" % zone)
	var msg: String = str(e.get("message", ""))
	if not msg.contains("wildfire"):
		_fail("entry.message missing 'wildfire': '%s'" % msg)
	if not msg.contains(str(expect_fires)):
		_fail("entry.message missing fire count %d: '%s'" % [expect_fires, msg])
	var tags: Variant = e.get("tags", PackedStringArray())
	if not (tags is PackedStringArray) or not (tags as PackedStringArray).has("wildfire"):
		_fail("entry.tags missing 'wildfire': %s" % str(tags))
	_log("entry[%d] persisted tick=%d zone='%s' msg='%s' tags=%s" % [
		entries.size() - 1, expect_tick, zone, msg, str(tags)])


func gm_pause() -> void:
	var gm: Node = root.get_node_or_null("GameManager")
	if gm != null and gm.has_method("pause"):
		gm.call("pause")
	var tm: Node = root.get_node_or_null("TickManager")
	if tm != null and tm.has_method("pause"):
		tm.call("pause")


func _finish() -> void:
	_done = true
	if _all_ok:
		_log("OK chronicle contract verified against real runtime path")
		quit(0)
	else:
		_log("REGRESSION FAILED")
		quit(2)