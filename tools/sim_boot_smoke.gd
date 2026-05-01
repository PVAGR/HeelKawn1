extends SceneTree

## Headless/boot check: instantiate Main and exit once GameManager reaches tick 10.
## Run: Godot --path . -s res://tools/sim_boot_smoke.gd --headless
## Optional: --no-game-tick-trace (also toggled from script once [GameManager] is found).

var _smoke_done: bool = false


func _ready() -> void:
	## Quiet CI: debug builds default [member GameManager.trace_game_tick_dispatch] on — turn off before any ticks.
	# [member root] is the scene tree root; autoloads are direct children (path "GameManager", not "/root/GameManager").
	var gm_trace: Node = root.get_node_or_null("GameManager")
	if gm_trace != null:
		if gm_trace.has_method("set_game_tick_trace_enabled"):
			gm_trace.call("set_game_tick_trace_enabled", false)
		else:
			gm_trace.set("trace_game_tick_dispatch", false)
	## Hold sim time until [Main] connects [signal GameManager.game_tick] (otherwise tick 1 runs with autoloads only).
	var gm_hold: Node = root.get_node_or_null("GameManager")
	if gm_hold != null and gm_hold.has_method("pause"):
		gm_hold.call("pause")
	call_deferred("_spawn_main")


func _spawn_main() -> void:
	var packed: PackedScene = load("res://scenes/main/Main.tscn") as PackedScene
	if packed == null:
		push_error("[SMOKE] Failed to load Main.tscn")
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
	if OS.is_debug_build():
		var nconn: int = 0
		if gm != null:
			nconn = gm.get_signal_connection_list(&"game_tick").size()
		print("[SMOKE] Main instantiated; game_tick listeners=%d; waiting for tick 10…" % nconn)


func _process(_delta: float) -> bool:
	if _smoke_done:
		return false
	var gm: Node = root.get_node_or_null("GameManager")
	if gm == null:
		return false
	var tick: int = int(gm.get("tick_count"))
	if tick >= 10:
		_smoke_done = true
		print("[SMOKE] OK reached tick_count=%d" % tick)
		quit(0)
		return true
	return false
