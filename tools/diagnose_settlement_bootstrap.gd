extends SceneTree

## Temporary diagnostic: observe settlement bootstrap timing without mutation.
## Run: Godot --headless --path . -s res://tools/diagnose_settlement_bootstrap.gd
##
## Boots Main.tscn (same lifecycle as sim_boot_smoke.gd), then prints
## settlement count, stockpile zone count, and pawn group size at key ticks.
##
## This script does NOT call SettlementMemory.recompute() or any private
## SettlementMemory method. It only reads public state each frame.
##
## Exit 0 always — this is a probe, not a pass/fail gate.

var _done: bool = false
var _tick_logged: Dictionary = {}

# Ticks to sample (printed once each when first reached or passed)
var _sample_ticks: Array[int] = [1, 10, 30, 60]
var _max_tick: int = 60


func _ready() -> void:
	# Quiet CI
	var gm_trace: Node = root.get_node_or_null("GameManager")
	if gm_trace != null:
		if gm_trace.has_method("set_game_tick_trace_enabled"):
			gm_trace.call("set_game_tick_trace_enabled", false)
		else:
			gm_trace.set("trace_game_tick_dispatch", false)
	# Hold sim time until Main connects game_tick
	var gm_hold: Node = root.get_node_or_null("GameManager")
	if gm_hold != null and gm_hold.has_method("pause"):
		gm_hold.call("pause")
	call_deferred("_spawn_main")


func _spawn_main() -> void:
	print("[SETTLEMENT_BOOTSTRAP_DIAG] label=spawn_main_enter")
	var packed: PackedScene = load("res://scenes/main/Main.tscn") as PackedScene
	if packed == null:
		push_error("[SETTLEMENT_BOOTSTRAP_DIAG] Main.tscn load failed")
		quit(1)
		return
	var main: Node = packed.instantiate()
	root.add_child(main)
	print("[SETTLEMENT_BOOTSTRAP_DIAG] label=main_added")
	var gm: Node = root.get_node_or_null("GameManager")
	if gm != null:
		if gm.has_method("set_game_tick_trace_enabled"):
			gm.call("set_game_tick_trace_enabled", false)
		else:
			gm.set("trace_game_tick_dispatch", false)
	# Snapshot immediately after Main._ready() — bootstrap recompute has run
	var tick_now: int = 0
	if gm != null:
		tick_now = int(gm.get("tick_count"))
	_print_snapshot("after_main_ready", tick_now)


func _process(_delta: float) -> bool:
	if _done:
		return false
	var gm: Node = root.get_node_or_null("GameManager")
	if gm == null:
		return false
	var tick: int = int(gm.get("tick_count"))

	for sample_tick in _sample_ticks:
		if tick >= sample_tick and not _tick_logged.has(sample_tick):
			_tick_logged[sample_tick] = true
			_print_snapshot("tick_%d" % sample_tick, tick)

	if tick >= _max_tick:
		_done = true
		print("[SETTLEMENT_BOOTSTRAP_DIAG_DONE]")
		quit(0)
		return true
	return false


func _print_snapshot(label: String, actual_tick: int) -> void:
	var sm: Node = root.get_node_or_null("SettlementMemory")
	var settlements_n: int = -1
	var settlements: Array = []
	if sm != null and sm.has_method("get_settlements"):
		settlements = sm.call("get_settlements")
		settlements_n = settlements.size()

	var spm: Node = root.get_node_or_null("StockpileManager")
	var zones_n: int = -1
	if spm != null and spm.has_method("zones"):
		zones_n = spm.call("zones").size()

	var pawn_n: int = PawnAccess.find_pawns().size()

	print("[SETTLEMENT_BOOTSTRAP_DIAG] label=%s actual_tick=%d settlements=%d stockpile_zones=%d pawn_group=%d" % [label, actual_tick, settlements_n, zones_n, pawn_n])

	if settlements_n > 0:
		var si: int = 0
		for sv in settlements:
			if sv is Dictionary:
				var d: Dictionary = sv as Dictionary
				var state_v = d.get("state", "?")
				var center_v = d.get("center_region", "?")
				var intent_v = d.get("current_intent", "?")
				var reg_v = d.get("regions", null)
				var reg_count: int = 0
				if reg_v is PackedInt32Array:
					reg_count = (reg_v as PackedInt32Array).size()
				elif reg_v is Array:
					reg_count = (reg_v as Array).size()
				print("[SETTLEMENT_BOOTSTRAP_DIAG] settlement[%d] state=%s center=%s intent=%s regions=%d" % [si, str(state_v), str(center_v), str(intent_v), reg_count])
			si += 1
