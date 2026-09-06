extends SceneTree
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	print("=== SIMPLE STRUCTURE CHECK ===")
	var paths: Array[String] = [
		"res://assets/sprites/terrain/bed.png",
		"res://assets/sprites/terrain/wall.png",
		"res://assets/sprites/terrain/door.png",
		"res://assets/sprites/structures/fire_pit.png",
		"res://assets/sprites/structures/storage_hut.png",
		"res://assets/sprites/structures/shelter.png",
		"res://assets/sprites/structures/workshop.png",
		"res://assets/sprites/structures/farm.png",
		"res://assets/sprites/structures/shrine.png",
		"res://assets/sprites/structures/hearth.png",
		"res://assets/sprites/structures/road.png",
		"res://assets/sprites/structures/granary.png",
	]
	for p in paths:
		var exists: bool = FileAccess.file_exists(p)
		print("%s -> %s" % [p, "exists" if exists else "MISSING"])
		if exists:
			var img: Image = Image.load_from_file(ProjectSettings.globalize_path(p))
			if img != null:
				print("  size %dx%d" % [img.get_width(), img.get_height()])
	print("=== DONE ===")
	quit(0)
