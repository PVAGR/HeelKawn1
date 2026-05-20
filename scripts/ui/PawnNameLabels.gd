class_name PawnNameLabels
extends Node2D

## Shows pawn names above their heads when hovered or selected.
## Also shows a brief status line (profession + current action).
## Lives in world space so labels track pawns naturally.

const LABEL_FONT_SIZE: int = 7
const STATUS_FONT_SIZE: int = 5
const NAME_COLOR: Color = Color(1.0, 0.95, 0.8, 0.9)
const STATUS_COLOR: Color = Color(0.7, 0.7, 0.65, 0.7)
const MOOD_GREAT: Color = Color(0.5, 1.0, 0.5, 0.9)
const MOOD_OK: Color = Color(1.0, 1.0, 0.5, 0.9)
const MOOD_BAD: Color = Color(1.0, 0.6, 0.4, 0.9)
const MOOD_CRITICAL: Color = Color(1.0, 0.2, 0.2, 0.9)
const SHADOW_COLOR: Color = Color(0.0, 0.0, 0.0, 0.5)
const Y_OFFSET: float = -16.0
const HOVER_RADIUS: float = 20.0  # pixels

## Cull pawn labels when pawn is more than this many screen-heights away from viewport.
const VIEWPORT_CULL_HEIGHT_MULT: float = 2.0
## Maximum UI update rate in Hz (4Hz = every 250ms).
const MAX_UPDATE_HZ: float = 4.0

var _world: World = null
var _camera: Camera2D = null
var _hovered_pawn = null
var _selected_pawn = null
var _cached_spawner: Node = null
var _last_mouse_world: Vector2 = Vector2.INF
var _is_mobile_runtime: bool = false
var _hover_check_every_frames: int = 5
var _camera_zoom: float = 1.0
var _viewport_cull_height_world: float = 100.0
var _update_timer: float = 0.0
var _last_throttle_check: float = 0.0


func initialize(world_ref: World, camera_ref: Camera2D) -> void:
	_world = world_ref
	_camera = camera_ref
	_is_mobile_runtime = OS.has_feature("mobile") or DisplayServer.is_touchscreen_available()
	# On touch devices hover is mostly irrelevant; reduce work aggressively.
	_hover_check_every_frames = 10 if _is_mobile_runtime else 5
	# Compute initial cull threshold from viewport size.
	_update_viewport_cull_height()


func set_selected_pawn(pawn) -> void:
	_selected_pawn = pawn


var _hover_throttle_frames: int = 0

func _update_viewport_cull_height() -> void:
	if _camera == null:
		return
	var viewport: Viewport = _camera.get_viewport()
	if viewport == null:
		return
	var viewport_size: Vector2 = viewport.get_visible_rect().size
	_camera_zoom = _camera.zoom.x if _camera.zoom.x > 0.0 else 1.0
	_viewport_cull_height_world = (viewport_size.y / _camera_zoom) * VIEWPORT_CULL_HEIGHT_MULT


func _process(delta: float) -> void:
	if _camera == null:
		return

	# Throttle: max 4Hz UI updates.
	_update_timer += delta
	if _update_timer < 1.0 / MAX_UPDATE_HZ:
		return
	_update_timer = 0.0

	# Recompute cull height periodically (zoom may change).
	_update_viewport_cull_height()

	# Mobile/touch: no hover cursor intent, so skip expensive nearest-pawn scans.
	if _is_mobile_runtime:
		if _hovered_pawn != null:
			_hovered_pawn = null
			queue_redraw()
		return

	_hover_throttle_frames += 1
	if _hover_throttle_frames >= _hover_check_every_frames:
		_hover_throttle_frames = 0
		var mouse_world: Vector2 = _camera.get_global_mouse_position()
		# Skip full pawn scan if the cursor barely moved.
		if _last_mouse_world != Vector2.INF and mouse_world.distance_squared_to(_last_mouse_world) < 2.0:
			return
		_last_mouse_world = mouse_world
		var next_hover = _find_pawn_under_cursor(mouse_world)
		if next_hover != _hovered_pawn:
			_hovered_pawn = next_hover
			queue_redraw()


func _resolve_spawner() -> Node:
	if _cached_spawner != null and is_instance_valid(_cached_spawner):
		return _cached_spawner
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	var spawners: Array = tree.get_nodes_in_group("pawn_spawner")
	if spawners.is_empty():
		return null
	_cached_spawner = spawners[0]
	return _cached_spawner


func _is_pawn_off_screen(pawn_pos: Vector2) -> bool:
	if _camera == null:
		return true
	# Compute cull threshold based on viewport height in world units.
	var camera_pos: Vector2 = _camera.global_position
	var dy: float = absf(pawn_pos.y - camera_pos.y)
	return dy > _viewport_cull_height_world


func _find_pawn_under_cursor(mouse_world: Vector2):
	if _camera == null:
		return null
	var best = null
	var best_dist: float = HOVER_RADIUS * HOVER_RADIUS
	var spawner = _resolve_spawner()
	if spawner == null or not spawner.has_method("get_all_pawns"):
		return null
	for p in spawner.get_all_pawns():
		if p == null or not is_instance_valid(p):
			continue
		# Cull pawns more than 2 screen-heights away.
		if _is_pawn_off_screen(p.global_position):
			continue
		var d_sq: float = p.global_position.distance_squared_to(mouse_world)
		if d_sq <= best_dist:
			best = p
			best_dist = d_sq
	return best


func _draw() -> void:
	var to_show: Array = []
	if _selected_pawn != null and is_instance_valid(_selected_pawn):
		if not _is_pawn_off_screen(_selected_pawn.global_position):
			to_show.append(_selected_pawn)
	if _hovered_pawn != null and is_instance_valid(_hovered_pawn) and _hovered_pawn != _selected_pawn:
		if not _is_pawn_off_screen(_hovered_pawn.global_position):
			to_show.append(_hovered_pawn)

	var font: Font = ThemeDB.fallback_font

	for pawn in to_show:
		if pawn.data == null:
			continue
		# World-space position: pawn position relative to this node
		var pos: Vector2 = pawn.global_position - global_position
		var name: String = pawn.data.display_name if pawn.data.display_name != "" else "HeelKawnian"
		var prof: String = ""
		if pawn.data.has_method("profession_label_from_enum"):
			prof = pawn.data.profession_label_from_enum(pawn.data.current_profession)

		# Mood-based color
		var mood: float = pawn.data.mood
		var name_color: Color = NAME_COLOR
		if mood >= 75:
			name_color = MOOD_GREAT
		elif mood >= 45:
			name_color = MOOD_OK
		elif mood >= 25:
			name_color = MOOD_BAD
		else:
			name_color = MOOD_CRITICAL

		# Name
		var name_pos: Vector2 = pos + Vector2(0.0, Y_OFFSET)
		var name_size: Vector2 = font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE)
		var name_centered: Vector2 = name_pos - Vector2(name_size.x * 0.5, 0.0)
		draw_string(font, name_centered + Vector2(0.5, 0.5), name, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE, SHADOW_COLOR)
		draw_string(font, name_centered, name, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE, name_color)

		# Status line (profession)
		if not prof.is_empty() and prof != "None":
			var status_text: String = prof
			var status_pos: Vector2 = name_pos + Vector2(0.0, 8.0)
			var status_size: Vector2 = font.get_string_size(status_text, HORIZONTAL_ALIGNMENT_LEFT, -1, STATUS_FONT_SIZE)
			var status_centered: Vector2 = status_pos - Vector2(status_size.x * 0.5, 0.0)
			draw_string(font, status_centered + Vector2(0.5, 0.5), status_text, HORIZONTAL_ALIGNMENT_LEFT, -1, STATUS_FONT_SIZE, SHADOW_COLOR)
			draw_string(font, status_centered, status_text, HORIZONTAL_ALIGNMENT_LEFT, -1, STATUS_FONT_SIZE, STATUS_COLOR)
		# Matrix drive line
		var drive_text: String = ""
		var profile: Dictionary = HeelKawnianManager.get_development_profile_for_pawn(pawn) if is_instance_valid(pawn) else {}
		if not profile.is_empty():
			var drive: String = str(profile.get("development_drive", ""))
			var next_need: String = str(profile.get("next_need", ""))
			if drive == "survive":
				drive_text = "Surviving"
			elif drive == "preserve":
				drive_text = "Preserving"
			elif drive == "innovate":
				drive_text = "Innovating"
			elif drive == "bond":
				drive_text = "Bonding"
			else:
				drive_text = "Serving"
			if not next_need.is_empty() and next_need != "serve local needs":
				var short_need: String = next_need
				if short_need.length() > 20:
					short_need = short_need.substr(0, 20)
				drive_text += " · " + short_need
		if not drive_text.is_empty():
			var drive_pos: Vector2 = name_pos + Vector2(0.0, 14.0)
			var drive_size: Vector2 = font.get_string_size(drive_text, HORIZONTAL_ALIGNMENT_LEFT, -1, STATUS_FONT_SIZE)
			var drive_centered: Vector2 = drive_pos - Vector2(drive_size.x * 0.5, 0.0)
			var drive_color: Color = Color(0.6, 0.8, 1.0, 0.7)
			draw_string(font, drive_centered + Vector2(0.5, 0.5), drive_text, HORIZONTAL_ALIGNMENT_LEFT, -1, STATUS_FONT_SIZE, SHADOW_COLOR)
			draw_string(font, drive_centered, drive_text, HORIZONTAL_ALIGNMENT_LEFT, -1, STATUS_FONT_SIZE, drive_color)
