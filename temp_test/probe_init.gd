extends SceneTree

func _initialize() -> void:
	print("[PROBE] _initialize called")
	var f: FileAccess = FileAccess.open("res://logs/probe_init.txt", FileAccess.WRITE)
	if f != null:
		f.store_string("init_called\n")
		f.close()
	quit(0)