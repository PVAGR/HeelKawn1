extends Node

## CrashTrap — Diagnostic wrapper for tick-1 failures.
## Logs which system is entered/exited during init and which [signal GameManager.game_tick] slot runs.
## GDScript cannot catch most runtime faults; the last [method enter_system] line before a hard stop is the hint.

var trace_enabled: bool = OS.has_feature("editor") or OS.is_debug_build()
var current_system: String = "startup"
var last_successful_step: String = ""
## When true, [method GameManager._dispatch_game_tick] logs each listener for [member GameManager.tick_count] == 1.
## Editor-only by default so headless [code]--headless[/code] CI is not flooded; set [code]true[/code] to trace tick 1 in exports.
var trace_first_sim_tick: bool = OS.has_feature("editor")


func _ready() -> void:
	_log(
			"CrashTrap initialized. trace_enabled=%s trace_first_sim_tick=%s (per-listener tick-1 trace when both true)"
			% [trace_enabled, trace_first_sim_tick]
	)
	if trace_enabled:
		_log("=== TICK-1 DIAGNOSTIC MODE (CrashTrap) ACTIVE ===")
		_log("If the process stops hard, the LAST [CrashTrap] ENTER line names the active slice.")
		_log("Search the console for 'CrashTrap FAIL'.")


func should_trace_game_tick_dispatch(tick: int) -> bool:
	return trace_enabled and trace_first_sim_tick and tick == 1


func enter_system(system_name: String) -> void:
	current_system = system_name
	if trace_enabled:
		_log("ENTER: %s" % system_name)


func exit_system(system_name: String) -> void:
	last_successful_step = system_name
	if trace_enabled:
		_log("EXIT: %s" % system_name)


func trap_step(step_name: String, callable_fn: Callable) -> Variant:
	enter_system(step_name)
	if trace_enabled:
		_log("STEP: %s" % step_name)
	var start_time: int = Time.get_ticks_msec()
	var result: Variant = callable_fn.call()
	var elapsed: int = Time.get_ticks_msec() - start_time
	if elapsed > 5000:
		_log("TIMEOUT: %s took %dms" % [step_name, elapsed])
	elif trace_enabled and elapsed > 100:
		_log("SLOW: %s took %dms" % [step_name, elapsed])
	exit_system(step_name)
	return result


func validate_autoload(name: String, expected_type: String = "") -> bool:
	var key: String = "validate_autoload:%s" % name
	enter_system(key)
	var node: Node = get_tree().root.get_node_or_null(name)
	if node == null:
		_log("FAIL: Autoload '%s' not found under scene tree root" % name)
		exit_system(key)
		return false
	if expected_type != "" and node.get_class() != expected_type:
		_log("FAIL: '%s' get_class()=%s (expected native class name '%s')" % [name, node.get_class(), expected_type])
		exit_system(key)
		return false
	_log("OK: Autoload '%s' (%s)" % [name, node.get_class()])
	exit_system(key)
	return true


func validate_signal(node: Object, signal_name: StringName) -> bool:
	if node == null or not is_instance_valid(node):
		_log("FAIL: null or invalid node for signal '%s'" % str(signal_name))
		return false
	var nm: String = str((node as Node).name) if node is Node else str(node)
	var key: String = "validate_signal:%s.%s" % [nm, str(signal_name)]
	enter_system(key)
	if not node.has_signal(signal_name):
		_log("FAIL: %s has no signal '%s'" % [nm, str(signal_name)])
		exit_system(key)
		return false
	exit_system(key)
	return true


func log_tick_event(phase: String, detail: String = "") -> void:
	if not trace_enabled:
		return
	if detail != "":
		_log("TICK[%s]: %s" % [phase, detail])
	else:
		_log("TICK[%s]" % phase)


func _log(msg: String) -> void:
	print("[CrashTrap] %s" % msg)


func dump_crash_state() -> void:
	_log("=== CRASH STATE DUMP ===")
	_log("Last successful system: %s" % last_successful_step)
	_log("Current system: %s" % current_system)
	_log("Time: %s" % Time.get_datetime_string_from_system())
	var tick_for_dump: int = 0
	var gm: Node = get_tree().root.get_node_or_null("GameManager")
	if gm != null:
		tick_for_dump = int(gm.get("tick_count"))
	_log("GameManager.tick_count: %d | Engine frames drawn: %d" % [tick_for_dump, Engine.get_frames_drawn()])
	var r: Window = get_tree().root
	for child in r.get_children():
		if child is Node:
			_log("Root child: %s (%s)" % [(child as Node).name, child.get_class()])
	_log("=== END CRASH DUMP ===")
