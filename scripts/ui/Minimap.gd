class_name Minimap
extends CanvasLayer

## Bottom-right corner minimap showing the full 256×256 world at a glance.
## Terrain from World._image, settlements as gold dots, enemies as red blips,
## pawn density as white glow, camera viewport as a white rectangle.
## Click to jump the camera.

const MAP_SIZE_PX: int = 180
const REFRESH_EVERY_N_TICKS: int = 30
const OVERLAY_REFRESH_TICKS: int = 5  # Pawn dots / camera rect update more often
const BORDER_COLOR: Color = Color(0.85, 0.78, 0.40, 0.50)
const SETTLEMENT_COLOR: Color = Color(1.0, 0.85, 0.3, 1.0)
const ENEMY_COLOR: Color = Color(1.0, 0.2, 0.15, 1.0)
const PAWN_COLOR: Color = Color(0.9, 0.9, 0.9, 0.7)
const CAMERA_RECT_COLOR: Color = Color(1.0, 1.0, 1.0, 0.8)
const MARGIN_RIGHT: float = 10.0
const MARGIN_BOTTOM: float = 10.0

var _texture_rect: TextureRect
var _minimap_image: Image
var _minimap_texture: ImageTexture
var _overlay: Control  # For drawing entities and camera rect on top
var _tick_counter: int = 0
var _world: World = null
var _camera: Camera2D = null
var _spawner: PawnSpawner = null


func _ready() -> void:
	layer = 10

	_minimap_image = Image.create(WorldData.WIDTH, WorldData.HEIGHT, false, Image.FORMAT_RGB8)
	_minimap_texture = ImageTexture.new()
	_minimap_texture.set_image(_minimap_image)

	# Background panel
	var panel: PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _make_panel_style())
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.custom_minimum_size = Vector2(MAP_SIZE_PX, MAP_SIZE_PX)

	# Terrain texture
	_texture_rect = TextureRect.new()
	_texture_rect.texture = _minimap_texture
	_texture_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_texture_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_texture_rect.mouse_filter = Control.MOUSE_FILTER_PASS

	# Overlay for entities and camera rect (drawn via _draw)
	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_PASS
	_overlay.draw.connect(_draw_overlay)

	panel.add_child(_texture_rect)
	panel.add_child(_overlay)

	# Anchor to bottom-right
	panel.anchor_left = 1.0
	panel.anchor_top = 1.0
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.offset_left = -MAP_SIZE_PX - MARGIN_RIGHT
	panel.offset_top = -MAP_SIZE_PX - MARGIN_BOTTOM
	panel.offset_right = -MARGIN_RIGHT
	panel.offset_bottom = -MARGIN_BOTTOM

	add_child(panel)

	# Click to jump camera
	_overlay.gui_input.connect(_on_overlay_input)


func initialize(world_ref: World, camera_ref: Camera2D, spawner_ref: PawnSpawner) -> void:
	_world = world_ref
	_camera = camera_ref
	_spawner = spawner_ref


func _process(_delta: float) -> void:
	_tick_counter += 1
	if _tick_counter % REFRESH_EVERY_N_TICKS == 0:
		_refresh_terrain()
	if _tick_counter % OVERLAY_REFRESH_TICKS == 0:
		_overlay.queue_redraw()


func _refresh_terrain() -> void:
	if _world == null or _world.data == null:
		return
	# Copy the world's terrain image directly
	var src: Image = _world._image
	if src != null:
		_minimap_image.blit_rect(src, Rect2i(Vector2i.ZERO, Vector2i(WorldData.WIDTH, WorldData.HEIGHT)), Vector2i.ZERO)
	_minimap_texture.update(_minimap_image)


func _draw_overlay() -> void:
	if _world == null:
		return

	var scale_x: float = MAP_SIZE_PX / float(WorldData.WIDTH)
	var scale_y: float = MAP_SIZE_PX / float(WorldData.HEIGHT)

	# Draw settlements
	if SettlementMemory != null:
		var settlements: Array = SettlementMemory.get_settlements()
		for s in settlements:
			if not s is Dictionary:
				continue
			var cr: int = int(s.get("center_region", -1))
			if cr < 0:
				continue
			# Convert region key to tile coords
			# Region key = (rx & 0xFFFF) | ((ry & 0xFFFF) << 16)
			var rx: int = (cr & 0xFFFF) * 16 + 8
			var ry: int = ((cr >> 16) & 0xFFFF) * 16 + 8
			var px: float = rx * scale_x
			var py: float = ry * scale_y
			_overlay.draw_circle(Vector2(px, py), 3.0, SETTLEMENT_COLOR)

	# Draw enemies
	var enemies: Array = []
	if _world != null:
		var tree: SceneTree = Engine.get_main_loop() as SceneTree
		if tree != null:
			enemies = tree.get_nodes_in_group("enemies")
	for e in enemies:
		if e == null or not is_instance_valid(e):
			continue
		if not e is Node2D:
			continue
		var e2: Node2D = e as Node2D
		var tile: Vector2i = _world.world_to_tile(e2.global_position)
		if tile.x < 0 or tile.y < 0:
			continue
		var px: float = tile.x * scale_x
		var py: float = tile.y * scale_y
		_overlay.draw_rect(Rect2(px - 1.0, py - 1.0, 2.0, 2.0), ENEMY_COLOR)

	# Draw pawn density (sparse — just dots for each pawn)
	if _spawner != null:
		for p in _spawner.get_all_pawns():
			if p == null or not is_instance_valid(p):
				continue
			var tile: Vector2i = _world.world_to_tile(p.global_position)
			if tile.x < 0 or tile.y < 0:
				continue
			var px: float = tile.x * scale_x
			var py: float = tile.y * scale_y
			_overlay.draw_rect(Rect2(px - 0.5, py - 0.5, 1.0, 1.0), PAWN_COLOR)

	# Draw camera viewport rectangle
	if _camera != null:
		var vp_size: Vector2 = _camera.get_viewport_rect().size
		var zoom_val: float = _camera.zoom.x
		var half_view_w: float = (vp_size.x / zoom_val) / (World.TILE_PIXELS * 2.0)
		var half_view_h: float = (vp_size.y / zoom_val) / (World.TILE_PIXELS * 2.0)
		var cam_tile: Vector2i = _world.world_to_tile(_camera.global_position)
		var left: float = (cam_tile.x - half_view_w) * scale_x
		var top: float = (cam_tile.y - half_view_h) * scale_y
		var w: float = half_view_w * 2.0 * scale_x
		var h: float = half_view_h * 2.0 * scale_y
		_overlay.draw_rect(Rect2(left, top, w, h), CAMERA_RECT_COLOR, false, 1.0)


func _on_overlay_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_jump_camera_to(event.position)
		get_viewport().set_input_as_handled()


func _jump_camera_to(click_pos: Vector2) -> void:
	if _camera == null or _world == null:
		return
	# Convert click position on minimap to tile coordinates
	var scale_x: float = MAP_SIZE_PX / float(WorldData.WIDTH)
	var scale_y: float = MAP_SIZE_PX / float(WorldData.HEIGHT)
	var tile_x: float = click_pos.x / scale_x
	var tile_y: float = click_pos.y / scale_y
	var tile: Vector2i = Vector2i(int(tile_x), int(tile_y))
	tile.x = clampi(tile.x, 0, WorldData.WIDTH - 1)
	tile.y = clampi(tile.y, 0, WorldData.HEIGHT - 1)
	var world_pos: Vector2 = _world.tile_to_world(tile)
	_camera.global_position = world_pos


func _make_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.06, 0.08, 0.70)
	style.border_color = BORDER_COLOR
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_width_left = 1
	style.border_width_right = 1
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	return style
