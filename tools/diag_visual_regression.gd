extends SceneTree
var _gm: Node = null
var _main: Node = null
var _phase := "boot"
var _printed := false
var _wall_test_pass: bool = false
var _structure_test_pass: bool = false

func _al(n: String) -> Node: return root.get_node_or_null("/root/" + n)

func _initialize() -> void: call_deferred("_spawn_main")

func _spawn_main() -> void:
	if not OS.get_cmdline_user_args().has("--playtest-no-save"): push_error("need fence"); quit(1); return
	var packed: PackedScene = load("res://scenes/main/Main.tscn") as PackedScene
	var m: Node = packed.instantiate()
	root.add_child(m)
	if not bool(m.get("_save_writes_disabled_for_playtest")): push_error("fence not active"); quit(1)

func _process(_d: float) -> bool:
	if _printed: return false
	if _gm == null: _gm = _al("GameManager"); return false
	if _phase == "boot":
		_main = root.get_node_or_null("/root/Main")
		if _main == null or _main.get("_world") == null: return false
		if _main.get("_pawn_spawner") == null or _main.get("_pawn_spawner").get("pawns").is_empty(): return false
		_phase = "wall_test"
		print("VISUAL_REGRESSION wall test 1x")
		_gm.call("set_speed", 1.0)
		return false
	if _phase == "wall_test":
		var world: Node = _main.get("_world")
		var res: Variant = world.call("_wall_would_cause_entrapment", 10, 10)
		if res is bool:
			print("WALL entrapment check PASS")
			_wall_test_pass = true
		else:
			print("WALL entrapment check FAIL")
			_wall_test_pass = false
		# Try building walls
		var built: int = 0
		for pos in [Vector2i(20,20), Vector2i(21,20)]:
			var r: Variant = world.call("build_wall", pos.x, pos.y)
			if r is bool and bool(r):
				built += 1
		print("WALL build %d" % built)
		_phase = "structure_test"
		return false
	if _phase == "structure_test":
		# Check structure textures
		var ok: int = 0
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
		]
		for p in paths:
			if FileAccess.file_exists(p):
				var tex: Texture2D = null
				# Try ImageTexture for freshly generated PNGs (no .import yet)
				var img: Image = Image.load_from_file(ProjectSettings.globalize_path(p))
				if img != null:
					tex = ImageTexture.create_from_image(img)
				elif ResourceLoader.exists(p):
					tex = load(p) as Texture2D
				if tex != null and tex.get_image() != null:
					ok += 1
					print("TEXTURE OK %s size %s" % [p, str(tex.get_size())])
				else:
					print("TEXTURE FAIL %s" % p)
			else:
				print("MISSING %s" % p)
		_structure_test_pass = (ok >= 7)
		print("STRUCTURE textures %d/9" % ok)
		# Check renderers use textures
		var wo_text: String = FileAccess.get_file_as_string("res://scripts/world/WorldOverlay.gd")
		var sr_text: String = FileAccess.get_file_as_string("res://scripts/visual/StructureRenderer.gd")
		var wo_uses_tex: bool = wo_text.find("texture_for_feature") >= 0 and wo_text.find("draw_texture_rect") >= 0
		var sr_uses_tex: bool = sr_text.find("texture_for_feature") >= 0 and sr_text.find("draw_texture_rect") >= 0
		print("WorldOverlay uses texture: %s" % str(wo_uses_tex))
		print("StructureRenderer uses texture: %s" % str(sr_uses_tex))
		if not wo_uses_tex or not sr_uses_tex:
			_structure_test_pass = false
		# Check zoom logic
		if sr_text.find("cam_zoom < 0.35") >= 0:
			print("StructureRenderer generic only at far zoom: YES")
		else:
			print("StructureRenderer generic only at far zoom: NO")
			_structure_test_pass = false
		_phase = "done"
		return false
	if _phase == "done":
		print("VISUAL_REGRESSION wall=%s structure=%s" % [str(_wall_test_pass), str(_structure_test_pass)])
		if _wall_test_pass and _structure_test_pass:
			print("VISUAL_REGRESSION PASS")
		else:
			print("VISUAL_REGRESSION FAIL")
		_printed = true
		quit(0 if (_wall_test_pass and _structure_test_pass) else 1)
	return false
