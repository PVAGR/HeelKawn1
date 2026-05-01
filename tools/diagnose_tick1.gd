extends SceneTree

## Run: Godot --path . -s res://tools/diagnose_tick1.gd --headless
## For a full [code]Main.tscn[/code] boot, use [code]sim_boot_smoke.gd[/code] instead (SceneTree [code]_process[/code] drives the loop).
## [GameManager] starts paused when the command line references [code]diagnose_tick1[/code] (see [method GameManager._ready]).

var _diag_done: bool = false


func _init() -> void:
	print("=== TICK-1 DIAGNOSTIC (diagnose_tick1.gd) ===")


func _crash_trap() -> Node:
	return root.get_node_or_null("CrashTrap")


func _game_manager() -> Node:
	return root.get_node_or_null("GameManager")


func _process(_delta: float) -> bool:
	if _diag_done:
		return false
	_diag_done = true
	var ct: Node = _crash_trap()
	if ct == null:
		push_error("ERROR: CrashTrap node missing under root (check autoload order).")
		quit(1)
		return true
	ct.set("trace_enabled", true)
	ct.set("trace_first_sim_tick", true)
	var critical: PackedStringArray = PackedStringArray([
			"CrashTrap",
			"GameManager",
			"SettlementMemory",
			"WorldAI",
			"WorldMemory",
	])
	var all_valid: bool = true
	for nm in critical:
		if not bool(ct.call("validate_autoload", nm, "Node")):
			all_valid = false
	if not all_valid:
		ct.call("dump_crash_state")
		quit(2)
		return true
	print("Autoload checks passed. Emitting game_tick(1) (Main scene: use sim_boot_smoke.gd).")
	_emit_tick_only()
	print("TICK-1 diagnostic run finished.")
	quit(0)
	return true


func _emit_tick_only() -> void:
	var gm: Node = _game_manager()
	if gm == null:
		push_error("FAIL: GameManager missing")
		return
	var ct: Node = _crash_trap()
	if ct != null:
		ct.call("enter_system", "tick_1_simulation")
		ct.call("log_tick_event", "manual_dispatch", "GameManager.game_tick.emit(1)")
	var t0: int = Time.get_ticks_msec()
	gm.emit_signal("game_tick", 1)
	var elapsed: int = Time.get_ticks_msec() - t0
	if ct != null:
		ct.call("log_tick_event", "manual_dispatch", "completed in %dms" % elapsed)
		ct.call("exit_system", "tick_1_simulation")
	if elapsed > 1000:
		push_warning("Tick emit path took >1s (%dms)" % elapsed)
