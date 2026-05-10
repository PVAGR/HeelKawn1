extends SceneTree

## Headless Matrix brain smoke.
## Proves the live scene can produce at least one explainable HeelKawnian
## Matrix decision from real pawn state.
##
## Run:
## Godot --headless --path . --script res://tools/sim_matrix_brain_loop_smoke.gd

const MIN_TICKS: int = 20
const TIMEOUT_MSEC: int = 15000

var _start_msec: int = 0
var _done: bool = false


func _ready() -> void:
	_start_msec = Time.get_ticks_msec()
	var gm: Node = root.get_node_or_null("GameManager")
	if gm != null:
		if gm.has_method("set_game_tick_trace_enabled"):
			gm.call("set_game_tick_trace_enabled", false)
		else:
			gm.set("trace_game_tick_dispatch", false)
	call_deferred("_spawn_main")


func _spawn_main() -> void:
	var packed: PackedScene = load("res://scenes/main/Main.tscn") as PackedScene
	if packed == null:
		push_error("[MATRIX_SMOKE] Failed to load Main.tscn")
		quit(1)
		return
	root.add_child(packed.instantiate())
	print("[MATRIX_SMOKE] Main instantiated; waiting for pawn brain output...")


func _process(_delta: float) -> bool:
	if _done:
		return false
	if Time.get_ticks_msec() - _start_msec > TIMEOUT_MSEC:
		_done = true
		push_error("[MATRIX_SMOKE] Timeout before Matrix brain output")
		quit(1)
		return true

	var gm: Node = root.get_node_or_null("GameManager")
	var tick: int = int(gm.get("tick_count")) if gm != null else 0
	if tick < MIN_TICKS:
		return false
	if not ClassDB.class_exists("HeelKawnianManager"):
		_done = true
		push_error("[MATRIX_SMOKE] HeelKawnianManager class is unavailable")
		quit(1)
		return true

	var pawns: Array[Node] = get_nodes_in_group("pawns")
	if pawns.is_empty():
		return false

	for pawn in pawns:
		var decision: Dictionary = HeelKawnianManager.get_matrix_decision_for_pawn(pawn)
		if decision.is_empty():
			continue
		var biases: Dictionary = decision.get("job_biases", {})
		var top_jobs: Array = decision.get("top_jobs", [])
		if biases.is_empty() or top_jobs.is_empty():
			continue
		var top: Dictionary = top_jobs[0]
		print(
			"[MATRIX_SMOKE] PASS pawn=%s drive=%s phase=%s top_job=%s bias=%d rationale=%s"
			% [
				str(decision.get("name", "")),
				str(decision.get("drive", "")),
				str(decision.get("phase", "")),
				str(top.get("job_name", "")),
				int(top.get("bias", 0)),
				str(decision.get("rationale", "")),
			]
		)
		_done = true
		quit(0)
		return true

	return false
