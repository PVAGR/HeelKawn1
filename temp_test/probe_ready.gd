extends SceneTree

func _ready() -> void:
	var f: FileAccess = FileAccess.open("res://logs/probe_ready.txt", FileAccess.WRITE)
	if f != null:
		f.store_string("ready_called\n")
		f.close()
	print("[PROBE] _ready called")
	var gm: Node = root.get_node_or_null("GameManager")
	print("[PROBE] GameManager found: %s" % str(gm != null))
	quit(0)