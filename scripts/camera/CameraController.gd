extends Camera2D

@export var min_zoom: float = 0.25
@export var max_zoom: float = 4.0
@export var zoom_step: float = 1.1
@export var pan_sensitivity: float = 1.0
@export var touch_pan_sensitivity: float = 1.0

## Emitted when zoom level changes. Listeners use this for zoom-dependent
## visibility (territory borders, name labels, etc.).
signal zoom_changed(new_zoom: float)

var _is_panning: bool = false
var _touch_points: Dictionary = {}
var _touch_last_pinch_distance: float = -1.0

func _ready() -> void:
	make_current()

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
