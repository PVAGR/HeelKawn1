extends Control
## UI for controlling simulation speed and pause state.
## Provides buttons for Pause, 1x, 4x, 16x, 64x speed multipliers.

signal speed_changed(multiplier: float)
signal pause_toggled(is_paused: bool)

var _buttons: Array[Button] = []
var _speed_labels: PackedStringArray = ["II", "1x", "4x", "16x", "64x"]
var _current_index: int = 1  # Start at 1x

func _ready() -> void:
	# Connect to TickManager if available
	if TickManager != null:
		TickManager.speed_changed.connect(_on_tick_manager_speed_changed)
		_current_index = TickManager.get_speed_index()
	
	# Create the UI
	_create_ui()

func _create_ui() -> void:
	# Main container
	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.name = "SpeedButtons"
	add_child(hbox)
	
	# Pause button
	var pause_btn: Button = Button.new()
	pause_btn.text = "II"
	pause_btn.pressed.connect(_on_pause_pressed)
	pause_btn.tooltip_text = "Pause/Resume (Space)"
	hbox.add_child(pause_btn)
	_buttons.append(pause_btn)
	
	# Speed buttons
	for i in range(1, _speed_labels.size()):
		var btn: Button = Button.new()
		btn.text = _speed_labels[i]
		btn.pressed.connect(_on_speed_pressed.bind(i))
		btn.tooltip_text = "Set speed to %s" % _speed_labels[i]
		hbox.add_child(btn)
		_buttons.append(btn)
	
	# Update button states
	_update_button_states()

func _on_pause_pressed() -> void:
	if TickManager != null:
		TickManager.toggle_pause()
	else:
		pause_toggled.emit(true)

func _on_speed_pressed(index: int) -> void:
	_current_index = index
	if TickManager != null:
		TickManager.set_speed_index(index)
	else:
		speed_changed.emit(TickManager.SPEED_PRESETS[index] if TickManager != null else 1.0)
	_update_button_states()

func _update_button_states() -> void:
	if TickManager == null:
		return
	var is_paused: bool = TickManager.is_paused()
	var speed_idx: int = TickManager.get_speed_index()
	
	for i in range(_buttons.size()):
		var btn: Button = _buttons[i]
		if i == 0:  # Pause button
			btn.button_pressed = is_paused
		else:
			btn.button_pressed = (i == speed_idx and not is_paused)

func _on_tick_manager_speed_changed(new_speed: float, is_paused: bool) -> void:
	_update_button_states()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_SPACE):
		if TickManager != null:
			TickManager.toggle_pause()
