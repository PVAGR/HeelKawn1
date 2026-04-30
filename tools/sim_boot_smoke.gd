extends SceneTree

## Headless/boot check: instantiate Main and exit once GameManager reaches tick 10.
## Run: Godot --path . -s res://tools/sim_boot_smoke.gd --headless

var _smoke_done: bool = false


func _ready() -> void:
	var packed: PackedScene = load("res://scenes/main/Main.tscn") as PackedScene
	if packed == null:
		push_error("[SMOKE] Failed to load Main.tscn")
		quit(1)
		return
	var main: Node = packed.instantiate()
	root.add_child(main)
	if OS.is_debug_build():
		print("[SMOKE] Main instantiated; waiting for tick 10…")


func _process(_delta: float) -> bool:
	if _smoke_done:
		return false
	var gm: Node = root.get_node_or_null("/root/GameManager")
	if gm == null:
		return false
	var tick: int = int(gm.get("tick_count"))
	if tick >= 10:
		_smoke_done = true
		print("[SMOKE] OK reached tick_count=%d" % tick)
		quit(0)
		return true
	return false
