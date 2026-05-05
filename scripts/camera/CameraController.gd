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
	el
if event is InputEventMouseMotion and _is_panning:
		position -= event.relative * pan_sensitivity / zoom.x

func _handle_mouse_button(event: InputEventMouseButton) -> void:
	match event.button_index:
		MOUSE_BUTTON_MIDDLE:
			_is_panning = event.pressed
		MOUSE_BUTTON_WHEEL_UP:
			if event.pressed:
				_zoom_toward(zoom_step, event.position)