extends Camera2D

@export var min_zoom: float = 0.25
@export var max_zoom: float = 4.0
@export var zoom_step: float = 1.1
@export var pan_sensitivity: float = 1.0

var _is_panning: bool = false

func _ready() -> void:
	make_current()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_handle_mouse_button(event)
	elif event is InputEventMouseMotion and _is_panning:
		position -= event.relative * pan_sensitivity / zoom.x

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

func _zoom_toward(factor: float, screen_pos: Vector2) -> void:
	var new_zoom_value: float = clamp(zoom.x * factor, min_zoom, max_zoom)
	var actual_factor: float = new_zoom_value / zoom.x
	if is_equal_approx(actual_factor, 1.0):
		return
	var world_before: Vector2 = get_screen_center_to_world(screen_pos)
	zoom = Vector2(new_zoom_value, new_zoom_value)
	var world_after: Vector2 = get_screen_center_to_world(screen_pos)
	position += world_before - world_after

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
