extends SceneTree
func _initialize() -> void:
	var s: Script = load("res://autoloads/GameManager.gd")
	print("GM load %s" % ("OK" if s != null and s.can_instantiate() else "FAIL"))
	quit(0)
