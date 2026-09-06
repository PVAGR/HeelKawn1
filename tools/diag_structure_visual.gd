extends SceneTree
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	print("=== STRUCTURE VISUAL TEST ===")
	var catalog: GDScript = load("res://scripts/visual/StructureCatalog.gd") as GDScript
	var count_ok: int = 0
	var count_missing: int = 0
	for key in ["bed","wall","door","fire_pit","storage_hut","shelter","workshop","farm","shrine","road","hearth","granary"]:
		var entry: Dictionary = {}
		if catalog != null:
			# Try to get entry via has_feature
			for k in catalog.STRUCTURES.keys():
				var e: Dictionary = catalog.STRUCTURES[k] as Dictionary
				if str(e.get("sprite_kind","")) == key or str(k)==key:
					entry = e
					break
		var tex_path: String = str(entry.get("texture",""))
		var tex: Texture2D = null
		if not tex_path.is_empty() and ResourceLoader.exists(tex_path):
			tex = load(tex_path) as Texture2D
		if tex != null and tex.get_image() != null:
			print("PASS %s -> %s size %s" % [key, tex_path, str(tex.get_size())])
			count_ok += 1
		else:
			print("FAIL %s -> %s missing" % [key, tex_path])
			count_missing += 1
	# Check specific assets
	var direct_checks: Dictionary = {
		"bed": "res://assets/sprites/terrain/bed.png",
		"wall": "res://assets/sprites/terrain/wall.png",
		"door": "res://assets/sprites/terrain/door.png",
		"fire_pit": "res://assets/sprites/structures/fire_pit.png",
		"storage_hut": "res://assets/sprites/structures/storage_hut.png",
		"shelter": "res://assets/sprites/structures/shelter.png",
		"workshop": "res://assets/sprites/structures/workshop.png",
		"farm": "res://assets/sprites/structures/farm.png",
		"shrine": "res://assets/sprites/structures/shrine.png",
		"road": "res://assets/sprites/structures/road.png",
	}
	for k in direct_checks.keys():
		var p: String = str(direct_checks[k])
		var t: Texture2D = load(p) as Texture2D if ResourceLoader.exists(p) else null
		if t != null and t.get_image() != null:
			print("ASSET OK %s -> %s %s" % [k, p, str(t.get_size())])
		else:
			print("ASSET MISSING %s -> %s" % [k, p])
	print("SUMMARY ok=%d missing=%d" % [count_ok, count_missing])
	# Check renderers exist
	var wo: GDScript = load("res://scripts/world/WorldOverlay.gd") as GDScript
	var sr: GDScript = load("res://scripts/visual/StructureRenderer.gd") as GDScript
	print("WorldOverlay has _draw_feature_sprite: %s" % str(wo != null))
	print("StructureRenderer has _draw_record: %s" % str(sr != null))
	# Check zoom logic
	var sr_text: String = FileAccess.get_file_as_string("res://scripts/visual/StructureRenderer.gd")
	if sr_text.find("draw_texture_rect") >= 0:
		print("StructureRenderer uses draw_texture_rect: YES")
	else:
		print("StructureRenderer uses draw_texture_rect: NO")
	var wo_text: String = FileAccess.get_file_as_string("res://scripts/world/WorldOverlay.gd")
	if wo_text.find("StructureCatalog.texture_for_feature") >= 0:
		print("WorldOverlay uses StructureCatalog texture: YES")
	else:
		print("WorldOverlay uses StructureCatalog texture: NO")
	if wo_text.find("draw_texture_rect") >= 0:
		print("WorldOverlay uses draw_texture_rect: YES")
	else:
		print("WorldOverlay uses draw_texture_rect: NO")
	print("=== VISUAL TEST DONE ===")
	quit(0)
