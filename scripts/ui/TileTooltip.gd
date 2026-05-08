class_name TileTooltip
extends CanvasLayer

## Hover tooltip showing tile info: biome, feature, elevation, moisture,
## meaning tags, settlement ownership, and any pawn at that tile.
## Follows the mouse cursor with a small offset.

const OFFSET: Vector2 = Vector2(14.0, 14.0)
const BG_COLOR: Color = Color(0.06, 0.07, 0.10, 0.88)
const BORDER_COLOR: Color = Color(0.5, 0.48, 0.35, 0.40)
const TEXT_COLOR: Color = Color(0.88, 0.84, 0.72, 1.0)
const MUTED_COLOR: Color = Color(0.55, 0.55, 0.50, 0.7)
const TAG_COLOR: Color = Color(0.6, 0.75, 0.55, 0.9)
const SETTLEMENT_COLOR: Color = Color(1.0, 0.85, 0.3, 0.9)
const STRUCTURE_COLOR: Color = Color(0.76, 0.69, 0.57, 0.85)
const PROFESSION_COLOR: Color = Color(0.65, 0.80, 0.95, 0.9)
const MOOD_COLOR: Color = Color(0.90, 0.85, 0.70, 0.9)
const MAX_WIDTH: float = 260.0
const REFRESH_EVERY_N_FRAMES: int = 3

var _panel: PanelContainer
var _label: RichTextLabel
var _world: World = null
var _camera: Camera2D = null
var _frame_counter: int = 0
var _last_tile: Vector2i = Vector2i(-1, -1)


func _ready() -> void:
	layer = 12

	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", _make_style())
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.visible = false

	_label = RichTextLabel.new()
	_label.bbcode_enabled = true
	_label.fit_content = true
	_label.scroll_active = false
	_label.add_theme_font_size_override("normal_font_size", 11)
	_label.custom_minimum_size = Vector2(MAX_WIDTH, 0)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_panel.add_child(_label)
	add_child(_panel)


func initialize(world_ref: World, camera_ref: Camera2D) -> void:
	_world = world_ref
	_camera = camera_ref


func _process(_delta: float) -> void:
	_frame_counter += 1
	if _frame_counter % REFRESH_EVERY_N_FRAMES != 0:
		return
	if _world == null or _camera == null:
		return

	var mouse_pos: Vector2 = _camera.get_global_mouse_position()
	var tile: Vector2i = _world.world_to_tile(mouse_pos)

	if not _world.data.in_bounds(tile.x, tile.y):
		_panel.visible = false
		_last_tile = Vector2i(-1, -1)
		return

	if tile == _last_tile:
		# Still update position even if tile unchanged
		_update_position()
		return

	_last_tile = tile
	_refresh(tile)
	_update_position()


func _refresh(tile: Vector2i) -> void:
	var lines: PackedStringArray = []

	# Biome
	var biome: int = _world.data.get_biome(tile.x, tile.y)
	var biome_name: String = Biome.NAMES.get(biome, "Unknown")
	lines.append("[b]%s[/b]" % biome_name)

	# Feature
	var feature: int = _world.data.get_feature(tile.x, tile.y)
	if feature != TileFeature.Type.NONE:
		var feat_name: String = TileFeature.NAMES.get(feature, "?")
		lines.append("[color=#bcaaa4]%s[/color]" % feat_name)

	# Elevation + Moisture (compact)
	var elev: float = _world.data.get_elevation(tile.x, tile.y)
	var moist: float = _world.data.get_moisture(tile.x, tile.y)
	lines.append("[color=%s]Elev %.0f%% · Moist %.0f%%[/color]" % [MUTED_COLOR.to_html(false), elev * 100.0, moist * 100.0])

	# Meaning tags
	var region_key: int = WorldMemory._region_key(tile.x, tile.y)
	if WorldMeaning != null:
		var tags: PackedStringArray = WorldMeaning.get_region_tags(region_key)
		if not tags.is_empty():
			var tag_str: String = " ".join(tags)
			lines.append("[color=%s]%s[/color]" % [TAG_COLOR.to_html(false), tag_str])

	# Settlement ownership + building counts
	if SettlementMemory != null:
		var settlement: Variant = SettlementMemory.get_settlement_at_region(region_key)
		if settlement != null and settlement is Dictionary:
			var s: Dictionary = settlement as Dictionary
			var s_name: String = str(s.get("name", s.get("intent", "Settlement")))
			var gov: String = str(s.get("governance_type", "anarchy"))
			var pop: int = int(s.get("population", 0))
			var state: String = str(s.get("state", ""))
			var state_tag: String = ""
			if state != "" and state != "active":
				state_tag = " [%s]" % state
			lines.append("[color=%s]%s%s (%s, pop %d)[/color]" % [SETTLEMENT_COLOR.to_html(false), s_name, state_tag, gov, pop])
			# Building counts from local feature scan
			var center_rk: int = int(s.get("center_region", -1))
			if center_rk >= 0:
				var crx: int = center_rk & 0xFFFF
				var cry: int = (center_rk >> 16) & 0xFFFF
				var center_tile: Vector2i = Vector2i(crx * 16 + 8, cry * 16 + 8)
				var feats: Dictionary = HeelKawnianManager._scan_local_features(center_tile, 12)
				var struct_parts: PackedStringArray = []
				if int(feats.get("hearth", 0)) > 0:
					struct_parts.append("hearth×%d" % int(feats.get("hearth", 0)))
				if int(feats.get("bed", 0)) > 0:
					struct_parts.append("bed×%d" % int(feats.get("bed", 0)))
				if int(feats.get("wall", 0)) > 0:
					struct_parts.append("wall×%d" % int(feats.get("wall", 0)))
				if int(feats.get("door", 0)) > 0:
					struct_parts.append("door×%d" % int(feats.get("door", 0)))
				if int(feats.get("storage_hut", 0)) > 0:
					struct_parts.append("store×%d" % int(feats.get("storage_hut", 0)))
				if int(feats.get("marker", 0)) > 0:
					struct_parts.append("marker×%d" % int(feats.get("marker", 0)))
				if not struct_parts.is_empty():
					lines.append("[color=%s]%s[/color]" % [STRUCTURE_COLOR.to_html(false), " · ".join(struct_parts)])

	# Pawn at tile — with profession, job, mood, carrying
	var pawns_here: Array = []
	if _world != null:
		var tree: SceneTree = Engine.get_main_loop() as SceneTree
		if tree != null:
			var spawners: Array = tree.get_nodes_in_group("pawn_spawner")
			if not spawners.is_empty():
				var spawner: PawnSpawner = spawners[0] as PawnSpawner
				if spawner != null:
					for p in spawner.get_all_pawns():
						if p == null or not is_instance_valid(p):
							continue
						var pt: Vector2i = _world.world_to_tile(p.global_position)
						if pt == tile:
							pawns_here.append(p)

	if not pawns_here.is_empty():
		for p in pawns_here:
			if p.data != null:
				var nm: String = p.data.display_name if p.data.display_name != "" else "Pawn"
				var prof: String = p.data.profession_name() if p.data.has_method("profession_name") else ""
				var mood: float = p.data.mood
				var mood_tag: String = "calm"
				if mood >= 80.0:
					mood_tag = "joyful"
				elif mood >= 60.0:
					mood_tag = "content"
				elif mood >= 40.0:
					mood_tag = "calm"
				elif mood >= 20.0:
					mood_tag = "uneasy"
				else:
					mood_tag = "distressed"
				var carry: String = ""
				if p.data.carrying_qty > 0:
					var carry_name: String = str(Item.NAMES.get(int(p.data.carrying), "?"))
					carry = " carrying %d %s" % [int(p.data.carrying_qty), carry_name]
				var job_str: String = ""
				if p._current_job != null and is_instance_valid(p._current_job):
					job_str = " [%s]" % Job.describe_type(int(p._current_job.type))
				var line: String = "[color=#e0e0e0]%s[/color]" % nm
				if prof != "" and prof != "None":
					line += " [color=%s]%s[/color]" % [PROFESSION_COLOR.to_html(false), prof]
				line += " [color=%s]%s[/color]" % [MOOD_COLOR.to_html(false), mood_tag]
				if job_str != "":
					line += "[color=%s]%s[/color]" % [MUTED_COLOR.to_html(false), job_str]
				if carry != "":
					line += "[color=%s]%s[/color]" % [MUTED_COLOR.to_html(false), carry]
				lines.append(line)

	_label.text = "\n".join(lines)
	_panel.visible = not lines.is_empty()


func _update_position() -> void:
	var screen_pos: Vector2 = get_viewport().get_mouse_position()
	_panel.position = screen_pos + OFFSET

	# Keep on screen
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	var panel_size: Vector2 = _panel.size
	if _panel.position.x + panel_size.x > vp_size.x:
		_panel.position.x = screen_pos.x - panel_size.x - OFFSET.x
	if _panel.position.y + panel_size.y > vp_size.y:
		_panel.position.y = screen_pos.y - panel_size.y - OFFSET.y


func _make_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = BG_COLOR
	style.border_color = BORDER_COLOR
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_width_left = 1
	style.border_width_right = 1
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	return style
