extends Control

## Speed control UI for the TickManager system.
## Provides buttons for Pause, 1x, 4x, 16x, 64x speed multipliers.

signal speed_changed(multiplier: float)

@onready var tick_manager = get_node_or_null("/root/TickManager")

func _ready() -> void:
	# Connect buttons if they exist as children
	_setup_buttons()


func _setup_buttons() -> void:
	if tick_manager == null:
		push_warning("SpeedControlUI: TickManager not found as autoload")
		return

	# Look for buttons by name
	var pause_btn = get_node_or_null("PauseButton")
	var speed_1x_btn = get_node_or_null("Speed1xButton")
	var speed_4x_btn = get_node_or_null("Speed4xButton")
	var speed_16x_btn = get_node_or_null("Speed16xButton")
	var speed_64x_btn = get_node_or_null("Speed64xButton")

	if pause_btn and pause_btn is Button:
		pause_btn.pressed.connect(_on_pause_pressed)

	if speed_1x_btn and speed_1x_btn is Button:
		speed_1x_btn.pressed.connect(_on_speed_1x_pressed)

	if speed_4x_btn and speed_4x_btn is Button:
		speed_4x_btn.pressed.connect(_on_speed_4x_pressed)

	if speed_16x_btn and speed_16x_btn is Button:
		speed_16x_btn.pressed.connect(_on_speed_16x_pressed)

	if speed_64x_btn and speed_64x_btn is Button:
		speed_64x_btn.pressed.connect(_on_speed_64x_pressed)


func _on_pause_pressed() -> void:
	if tick_manager == null:
		return
	if tick_manager.is_paused():
		tick_manager.resume()
	else:
		tick_manager.pause()


func _on_speed_1x_pressed() -> void:
	_set_speed(TickManager.SpeedPreset.SPEED_1X)


func _on_speed_4x_pressed() -> void:
	_set_speed(TickManager.SpeedPreset.SPEED_4X)


func _on_speed_16x_pressed() -> void:
	_set_speed(TickManager.SpeedPreset.SPEED_16X)


func _on_speed_64x_pressed() -> void:
	_set_speed(TickManager.SpeedPreset.SPEED_64X)


func _set_speed(preset: int) -> void:
	if tick_manager == null:
		return
	tick_manager.set_speed(preset)
	speed_changed.emit(_get_multiplier_for_preset(preset))


func _get_multiplier_for_preset(preset: int) -> float:
	match preset:
		TickManager.SpeedPreset.SPEED_0_5X:
			return 0.5
		TickManager.SpeedPreset.SPEED_1X:
			return 1.0
		TickManager.SpeedPreset.SPEED_4X:
			return 4.0
		TickManager.SpeedPreset.SPEED_16X:
			return 16.0
		TickManager.SpeedPreset.SPEED_64X:
			return 64.0
	return 1.0


## Public method to set speed from external UI
func set_speed_multiplier(multiplier: float) -> void:
	if tick_manager == null:
		return
	tick_manager.set_speed_multiplier(multiplier)
