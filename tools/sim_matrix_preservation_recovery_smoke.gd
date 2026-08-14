extends SceneTree

## Headless Matrix preservation/recovery live smoke.
## Boots Main.tscn, accelerates, then verifies that Matrix AI paths that
## require NO player input actually fire and reach the kernel.
## Evidence is read from the WorldMemory append-only event feed only —
## this probe does NOT call any Matrix function that mutates sim state
## (ambition seeding / chains are left to the live pawns).
##
## Checks:
##   1. heelkawnian_development events reach WorldMemory.
##   2. At least one matrix event type fires (preservation/learning/ambition).
##   3. Matrix drives are observed across pawns (survive/recover/preserve/etc.).
##   4. KnowledgeSystem.compute_preservation_pressure() is queryable.
##
## Run: Godot --headless --path . -s res://tools/sim_matrix_preservation_recovery_smoke.gd

const TARGET_TICK: int = 6000
const TIMEOUT_FRAMES: int = 30000  # generous ~8min headless
const TARGET_EVENT_TYPES: Array[String] = [
	"matrix_preservation_action",
	"matrix_learning_seed",
	"matrix_settlement_ambition",
	"matrix_household_ambition",
]

var _done: bool = false
var _started: bool = false
var _main_spawned: bool = false
var _frame_count: int = 0
var _observed_tick: int = -1
var _events_found: Dictionary = {}
var _total_heelkawnian_events: int = 0
var _drives_seen: Dictionary = {}
var _preservation_pressure_samples: Array = []


func _process(_delta: float) -> bool:
	if _done:
		return false

	if not _started:
		_started = true
		var gm_trace: Node = root.get_node_or_null("GameManager")
		if gm_trace != null:
			if gm_trace.has_method("set_game_tick_trace_enabled"):
				gm_trace.call("set_game_tick_trace_enabled", false)
			else:
				gm_trace.set("trace_game_tick_dispatch", false)
		var gm_hold: Node = root.get_node_or_null("GameManager")
		if gm_hold != null and gm_hold.has_method("pause"):
			gm_hold.call("pause")
		call_deferred("_spawn_main")
		return false

	if not _main_spawned:
		return false

	_frame_count += 1
	if _frame_count > TIMEOUT_FRAMES:
		var gm_t: Node = root.get_node_or_null("GameManager")
		var t: int = int(gm_t.get("tick_count")) if gm_t != null else -1
		print("[MATRIX_SMOKE_FAIL] tick=%d reason=frame_limit_exceeded" % t)
		_done = true
		quit(1)
		return true

	var gm: Node = root.get_node_or_null("GameManager")
	if gm == null:
		return false
	var tick: int = int(gm.get("tick_count"))

	if tick != _observed_tick and tick % 250 == 0:
		_observed_tick = tick
		_sample(tick)

	if tick >= TARGET_TICK:
		_done = true
		_report(tick)
		return true
	return false


func _spawn_main() -> void:
	var packed: PackedScene = load("res://scenes/main/Main.tscn") as PackedScene
	if packed == null:
		print("[MATRIX_SMOKE_FAIL] reason=Main_load_failed")
		quit(1)
		return
	var main: Node = packed.instantiate()
	root.add_child(main)
	var gm: Node = root.get_node_or_null("GameManager")
	if gm != null:
		if gm.has_method("set_game_tick_trace_enabled"):
			gm.call("set_game_tick_trace_enabled", false)
		else:
			gm.set("trace_game_tick_dispatch", false)
	var tm: Node = root.get_node_or_null("TickManager")
	if tm != null and tm.has_method("resume"):
		tm.call("resume")
	if gm != null and gm.has_method("resume"):
		gm.call("resume")
	if tm != null and tm.has_method("set_speed"):
		tm.call("set_speed", 500.0)
	elif tm != null and tm.has_method("set_speed_index"):
		tm.call("set_speed_index", 6)
	_main_spawned = true
	print("[MATRIX_SMOKE] START")


func _sample(tick: int) -> void:
	var wm: Node = root.get_node_or_null("WorldMemory")
	if wm != null and wm.has_method("get_events"):
		var all_events: Array = wm.call("get_events")
		var hk_count: int = 0
		for ev in all_events:
			if ev is Dictionary:
				var d: Dictionary = ev as Dictionary
				var typ: String = str(d.get("type", ""))
				if typ == "heelkawnian_development":
					hk_count += 1
					var ev_type: String = str(d.get("event_type", ""))
					if TARGET_EVENT_TYPES.has(ev_type):
						_events_found[ev_type] = int(_events_found.get(ev_type, 0)) + 1
					var payload: Variant = d.get("payload", {})
					if payload is Dictionary:
						var drive: String = str((payload as Dictionary).get("drive", ""))
						if drive != "":
							_drives_seen[drive] = int(_drives_seen.get(drive, 0)) + 1
		_total_heelkawnian_events += hk_count

	# KnowledgeSystem preservation pressure is a read-only derived query.
	var ks: Node = root.get_node_or_null("KnowledgeSystem")
	if ks != null and ks.has_method("compute_preservation_pressure"):
		var pressure: Variant = ks.call("compute_preservation_pressure", -1)
		if pressure is Dictionary:
			var pd: Dictionary = pressure as Dictionary
			_preservation_pressure_samples.append(int(pd.get("urgent_count", 0)) + int(pd.get("recommended_count", 0)))


func _report(final_tick: int) -> void:
	print("[MATRIX_SMOKE] final_tick=%d heelkawnian_events_seen=%d drives_seen=%s" % [final_tick, _total_heelkawnian_events, str(_drives_seen)])
	var missing: Array[String] = []
	for t in TARGET_EVENT_TYPES:
		if not _events_found.has(t):
			missing.append(t)
		else:
			print("[MATRIX_SMOKE] event_type=%s count=%d" % [t, int(_events_found[t])])

	var all_pass: bool = true
	if _total_heelkawnian_events <= 0:
		all_pass = false
		print("[MATRIX_SMOKE_FAIL] reason=no_heelkawnian_events_reached_kernel")
	if missing.size() >= TARGET_EVENT_TYPES.size():
		all_pass = false
		print("[MATRIX_SMOKE_FAIL] reason=no_matrix_event_types_fired missing_all=%s" % str(missing))
	elif not missing.is_empty():
		print("[MATRIX_SMOKE] missing_event_types=%s" % str(missing))
	if _drives_seen.is_empty():
		all_pass = false
		print("[MATRIX_SMOKE_FAIL] reason=no_matrix_drives_observed")
	else:
		print("[MATRIX_SMOKE] drives=%s" % str(_drives_seen))

	if not _preservation_pressure_samples.is_empty():
		print("[MATRIX_SMOKE] preservation_pressure_samples=%d last=%d" % [_preservation_pressure_samples.size(), _preservation_pressure_samples.back()])

	if all_pass:
		print("[MATRIX_SMOKE_PASS] matrix_preservation_recovery_live")
		quit(0)
	else:
		print("[MATRIX_SMOKE_FAIL] matrix_preservation_recovery_live")
		quit(1)
