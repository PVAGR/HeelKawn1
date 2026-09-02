extends SceneTree

func _initialize() -> void:
	print("HASHPROBE hash=%d" % hash("20260429::pawn_spawn_candidates::0"))
	print("HASHPROBE hash2=%d" % hash("20260429::compat:rangei::1"))
	print("HASHPROBE strname=%d" % int("pawn_spawn_candidates".hash()))
	quit(0)