extends Camera2D

@export var min_zoom: float = 0.15
@export var max_zoom: float = 4.0
@export var zoom_step: float = 1.1
@export var pan_sensitivity: float = 1.0
@export var touch_pan_sensitivity: float = 1.0
@export var songs_min_zoom: float = 0.08
@export var songs_max_zoom: float = 3.2
@export var songs_zoom_step: float = 1.14
@export var songs_pan_sensitivity: float = 1.1
@export var songs_touch_pan_sensitivity: float = 1.05
@export var songs_edge_pan_enabled: bool = true
@export var songs_edge_pan_margin_px: float = 28.0
@export var songs_edge_pan_speed_px_per_sec: float = 860.0
@export var dwarf_min_zoom: float = 0.35
@export var dwarf_max_zoom: float = 6.0
@export var dwarf_zoom_step: float = 1.08
@export var dwarf_pan_sensitivity: float = 0.78
@export var dwarf_touch_pan_sensitivity: float = 0.72
@export var default_profile: int = 0  # 0 Songs-of-Syx macro, 1 Dwarf-Fortress tactical

## Emitted when zoom level changes. Listeners use this for zoom-dependent
## visibility (territory borders, name labels, etc.).
signal zoom_changed(new_zoom: float)
signal camera_profile_changed(profile_name: String)

enum CameraProfile {
	SONGS_OF_SYX,
	DWARF_FORTRESS,
}

var _is_panning: bool = false
var _touch_points: Dictionary = {}
var _touch_last_pinch_distance: float = -1.0
var _camera_profile: int = CameraProfile.SONGS_OF_SYX

func _ready() -> void:
	make_current()
	_apply_profile(clampi(default_profile, 0, 1), true)
	set_process(true)


func _process(delta: float) -> void:
	if _camera_profile != CameraProfile.SONGS_OF_SYX:
		return
	if not songs_edge_pan_enabled:
		return
	if _is_panning:
		return
	var vp_rect: Rect2 = get_viewport_rect()
	if vp_rect.size.x <= 0.0 or vp_rect.size.y <= 0.0:
		return
	var m: Vector2 = get_viewport().get_mouse_position()
	var edge: Vector2 = _edge_pan_vector(vp_rect.size, m)
	if edge == Vector2.ZERO:
		return
	position += edge * songs_edge_pan_speed_px_per_sec * delta / maxf(zoom.x, 0.001)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_handle_mouse_button(event)
	elif event is InputEventMouseMotion and _is_panning:
		position -= event.relative * pan_sensitivity / zoom.x
	elif event is InputEventScreenTouch:
		_handle_touch(event)
	elif event is InputEventScreenDrag:
		_handle_touch_drag(event)

func _handle_mouse_button(event: InputEventMouseButton) -> void:
	match event.button_index:
		MOUSE_BUTTON_MIDDLE:
			_is_panning = event.pressed
		MOUSE_BUTTON_WHEEL_UP:
			if event.pressed:
				_zoom_toward(zoom_step, event.position)
		MOUSE_BUTTON_WHEEL_DOWN:
			if event.pressed:
				_zoom_toward(1.0 / zoom_step, event.position)

func _handle_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		_touch_points[event.index] = event.position
		if _touch_points.size() >= 2:
			var keys: Array = _touch_points.keys()
			var p1: Vector2 = _touch_points[keys[0]]
			var p2: Vector2 = _touch_points[keys[1]]
			_touch_last_pinch_distance = p1.distance_to(p2)
	else:
		_touch_points.erase(event.index)
		if _touch_points.size() < 2:
			_touch_last_pinch_distance = -1.0

func _handle_touch_drag(event: InputEventScreenDrag) -> void:
	_touch_points[event.index] = event.position
	if _touch_points.size() == 1:
		position -= event.relative * touch_pan_sensitivity / zoom.x
		return
	if _touch_points.size() < 2:
		return
	var keys: Array = _touch_points.keys()
	if keys.size() < 2:
		return
	var p1: Vector2 = _touch_points[keys[0]]
	var p2: Vector2 = _touch_points[keys[1]]
	var midpoint: Vector2 = (p1 + p2) * 0.5
	var distance: float = p1.distance_to(p2)
	if _touch_last_pinch_distance > 0.0 and distance > 0.0:
		_zoom_toward(clampf(distance / _touch_last_pinch_distance, 0.8, 1.25), midpoint)
	_touch_last_pinch_distance = distance

func _zoom_toward(factor: float, screen_pos: Vector2) -> void:
	var new_zoom_value: float = clamp(zoom.x * factor, min_zoom, max_zoom)
	var actual_factor: float = new_zoom_value / zoom.x
	if is_equal_approx(actual_factor, 1.0):
		return
	var world_before: Vector2 = get_screen_center_to_world(screen_pos)
	zoom = Vector2(new_zoom_value, new_zoom_value)
	var world_after: Vector2 = get_screen_center_to_world(screen_pos)
	position += world_before - world_after
	zoom_changed.emit(new_zoom_value)

func zoom_in(screen_pos: Vector2 = Vector2.INF) -> void:
	_zoom_toward(zoom_step, screen_pos if screen_pos != Vector2.INF else get_viewport_rect().size * 0.5)

func zoom_out(screen_pos: Vector2 = Vector2.INF) -> void:
	_zoom_toward(1.0 / zoom_step, screen_pos if screen_pos != Vector2.INF else get_viewport_rect().size * 0.5)

func get_screen_center_to_world(screen_pos: Vector2) -> Vector2:
	var viewport_size: Vector2 = get_viewport_rect().size
	var offset_from_center: Vector2 = screen_pos - viewport_size * 0.5
	return position + offset_from_center / zoom.x

## Keep panning from drifting far outside the map (used in player-pawn mode).
func clamp_position_to_world(world: Node2D, margin_px: float) -> void:
	if world == null:
		return
	var half_w: float = float(WorldData.WIDTH * 10) * 0.5
	var half_h: float = float(WorldData.HEIGHT * 10) * 0.5
	var o: Vector2 = world.global_position
	var gp: Vector2 = global_position
	gp.x = clampf(gp.x, o.x - half_w + margin_px, o.x + half_w - margin_px)
	gp.y = clampf(gp.y, o.y - half_h + margin_px, o.y + half_h - margin_px)
	global_position = gp

func reset_to_world_bounds(world: Node) -> void:
	if world == null:
		return
	var center_tile: Vector2i = Vector2i(WorldData.WIDTH >> 1, WorldData.HEIGHT >> 1)
	position = Vector2(center_tile.x * 10, center_tile.y * 10) 
	
	var viewport_size: Vector2 = get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		zoom = Vector2(1.0, 1.0)
		return
	
	var world_px_w: float = float(WorldData.WIDTH * 10)
	var world_px_h: float = float(WorldData.HEIGHT * 10)
	var scale_x: float = viewport_size.x / world_px_w
	var scale_y: float = viewport_size.y / world_px_h
	var fit_zoom: float = clamp(minf(scale_x, scale_y), min_zoom, max_zoom)
	zoom = Vector2(fit_zoom, fit_zoom)
	zoom_changed.emit(fit_zoom)


func set_camera_mode_songs_of_syx() -> void:
	_apply_profile(CameraProfile.SONGS_OF_SYX, false)


func set_camera_mode_dwarf_fortress() -> void:
	_apply_profile(CameraProfile.DWARF_FORTRESS, false)


func toggle_camera_profile() -> void:
	if _camera_profile == CameraProfile.SONGS_OF_SYX:
		_apply_profile(CameraProfile.DWARF_FORTRESS, false)
	else:
		_apply_profile(CameraProfile.SONGS_OF_SYX, false)


func set_camera_profile_by_name(profile_name: String) -> void:
	var key: String = profile_name.strip_edges().to_lower()
	match key:
		"songs", "songs_of_syx", "syx", "macro":
			set_camera_mode_songs_of_syx()
		"dwarf", "dwarf_fortress", "df", "tactical":
			set_camera_mode_dwarf_fortress()


func get_camera_profile_name() -> String:
	return "Songs of Syx Macro" if _camera_profile == CameraProfile.SONGS_OF_SYX else "Dwarf Fortress Tactical"


func get_camera_profile_id() -> int:
	return _camera_profile


func _apply_profile(profile: int, force: bool) -> void:
	var next_profile: int = clampi(profile, 0, 1)
	if not force and next_profile == _camera_profile:
		return
	_camera_profile = next_profile
	match _camera_profile:
		CameraProfile.SONGS_OF_SYX:
			min_zoom = songs_min_zoom
			max_zoom = songs_max_zoom
			zoom_step = songs_zoom_step
			pan_sensitivity = songs_pan_sensitivity
			touch_pan_sensitivity = songs_touch_pan_sensitivity
		CameraProfile.DWARF_FORTRESS:
			min_zoom = dwarf_min_zoom
			max_zoom = dwarf_max_zoom
			zoom_step = dwarf_zoom_step
			pan_sensitivity = dwarf_pan_sensitivity
			touch_pan_sensitivity = dwarf_touch_pan_sensitivity
	zoom = Vector2(clampf(zoom.x, min_zoom, max_zoom), clampf(zoom.y, min_zoom, max_zoom))
	zoom_changed.emit(zoom.x)
	camera_profile_changed.emit(get_camera_profile_name())


func _edge_pan_vector(view_size: Vector2, mouse_pos: Vector2) -> Vector2:
	var v: Vector2 = Vector2.ZERO
	var margin: float = maxf(2.0, songs_edge_pan_margin_px)
	if mouse_pos.x <= margin:
		v.x -= 1.0 - clampf(mouse_pos.x / margin, 0.0, 1.0)
	elif mouse_pos.x >= view_size.x - margin:
		v.x += clampf((mouse_pos.x - (view_size.x - margin)) / margin, 0.0, 1.0)
	if mouse_pos.y <= margin:
		v.y -= 1.0 - clampf(mouse_pos.y / margin, 0.0, 1.0)
	elif mouse_pos.y >= view_size.y - margin:
		v.y += clampf((mouse_pos.y - (view_size.y - margin)) / margin, 0.0, 1.0)
	if v == Vector2.ZERO:
		return v
	return v.normalized()
