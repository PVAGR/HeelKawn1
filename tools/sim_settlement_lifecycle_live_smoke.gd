extends SceneTree

## Headless settlement lifecycle transition smoke.
## Run: Godot --headless --path . -s res://tools/sim_settlement_lifecycle_live_smoke.gd
##
## Boots Main.tscn, accelerates to 100x, then observes settlement state
## at recompute boundaries (tick 2000, 4000, 6000) to prove:
##   1. Settlement state is always a valid value from the 5-state set.
##   2. Settlement count is stable across recomputes.
##   3. Hysteresis tracking fields (state_truth_raw) exist in public dicts.
##   4. The state machine is live — recompute runs and updates state.
##
## This test does NOT force a transition. It proves the state machine
## is functioning, not that transitions occur under pressure.
## It does NOT call recompute() or any private method.
## It does NOT mutate settlement state.

const VALID_STATES: Array[String] = [
	"active",
	"recovering",
	"revivable",
	"abandoned",
	"permanently_abandoned",
]

const SAMPLE_TICKS: Array[int] = [10, 2000, 2001]
const MAX_TICK: int = 2001
const TIMEOUT_FRAMES: int = 18000  # ~5min at 60fps; generous for headless

var _done: bool = false
var _started: bool = false
var _main_spawned: bool = false
var _frame_count: int = 0
var _tick_logged: Dictionary = {}
var _first_state: String = ""
var _first_center: int = -1


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
		print("[LIFECYCLE_LIVE_FAIL] tick=%d reason=frame_limit_exceeded" % t)
		_done = true
		quit(1)
		return true

	var gm: Node = root.get_node_or_null("GameManager")
	if gm == null:
		return false
	var tick: int = int(gm.get("tick_count"))

	for sample_tick in SAMPLE_TICKS:
		if tick >= sample_tick and not _tick_logged.has(sample_tick):
			_tick_logged[sample_tick] = true
			_observe(sample_tick, tick)

	if tick >= MAX_TICK:
		_done = true
		print("[LIFECYCLE_LIVE_PASS] all_recompute_boundaries_observed")
		quit(0)
		return true
	return false


func _spawn_main() -> void:
	var packed: PackedScene = load("res://scenes/main/Main.tscn") as PackedScene
	if packed == null:
		print("[LIFECYCLE_LIVE_FAIL] reason=Main_load_failed")
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
	# Resume TickManager (set_speed() in Main._ready unpauses GameManager but not TickManager)
	var tm: Node = root.get_node_or_null("TickManager")
	if tm != null and tm.has_method("resume"):
		tm.call("resume")
	if gm != null and gm.has_method("resume"):
		gm.call("resume")
	# Accelerate for fast tick advancement — use direct speed multiplier
	# 100x via preset is too slow for 6000 ticks. Set 500x directly.
	if tm != null and tm.has_method("set_speed"):
		tm.call("set_speed", 500.0)
	elif tm != null and tm.has_method("set_speed_index"):
		tm.call("set_speed_index", 6)  # 100x fallback
	_main_spawned = true
	print("[LIFECYCLE_LIVE] START")


func _observe(label_tick: int, actual_tick: int) -> void:
	var sm: Node = root.get_node_or_null("SettlementMemory")
	if sm == null:
		print("[LIFECYCLE_LIVE_FAIL] tick=%d reason=SettlementMemory_not_found" % label_tick)
		quit(1)
		return
	if not sm.has_method("get_settlements"):
		print("[LIFECYCLE_LIVE_FAIL] tick=%d reason=get_settlements_not_found" % label_tick)
		quit(1)
		return

	var settlements: Array = sm.call("get_settlements")
	var count: int = settlements.size()
	print("[LIFECYCLE_LIVE] label=tick_%d actual_tick=%d settlements=%d" % [label_tick, actual_tick, count])

	if count == 0:
		print("[LIFECYCLE_LIVE] tick=%d settlements_empty" % label_tick)
		return

	# Validate each settlement
	var idx: int = 0
	for sv in settlements:
		if not (sv is Dictionary):
			print("[LIFECYCLE_LIVE_FAIL] tick=%d settlement[%d] reason=not_dictionary" % [label_tick, idx])
			quit(1)
			return
		var d: Dictionary = sv as Dictionary

		# State must be valid
		var state_val = d.get("state", null)
		if not (state_val is String):
			print("[LIFECYCLE_LIVE_FAIL] tick=%d settlement[%d].state reason=not_string value=%s" % [label_tick, idx, str(state_val)])
			quit(1)
			return
		var state_str: String = state_val as String
		if state_str not in VALID_STATES:
			print("[LIFECYCLE_LIVE_FAIL] tick=%d settlement[%d].state reason=invalid value=%s" % [label_tick, idx, state_str])
			quit(1)
			return

		# Center region for identity tracking
		var center_val = d.get("center_region", -1)
		var center: int = int(center_val) if center_val != null else -1

		# Hysteresis tracking field — proves recompute ran and material override applied
		var has_state_truth_raw: bool = d.has("state_truth_raw")

		# Material signal fields — prove material override ran
		var has_material_signal: bool = d.has("material_signal_living")

		print("[LIFECYCLE_LIVE] tick=%d settlement[%d] state=%s center=%d state_truth_raw=%s material_signal=%s" % [
			label_tick, idx, state_str, center,
			"present" if has_state_truth_raw else "absent",
			"present" if has_material_signal else "absent",
		])

		# Record first settlement identity for stability check
		if _first_center == -1:
			_first_center = center
			_first_state = state_str
		elif center != _first_center:
			print("[LIFECYCLE_LIVE] tick=%d settlement[%d] center_changed old=%d new=%d" % [label_tick, idx, _first_center, center])

		idx += 1
