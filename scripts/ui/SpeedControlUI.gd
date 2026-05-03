extends Control
## Speed control UI for the TickManager.
## Provides buttons for Pause, 1x, 4x, 16x, 64x speed settings.
## Connects to TickManager singleton for speed control.

signal speed_changed(speed_multiplier: float)
signal pause_toggled(is_paused: bool)

@onready var TickMgr = get_node_or_null("/root/TickManager")

# UI Elements (to be set up in scene or _ready)
var pause_button: Button
var speed_buttons: Array[Button] = []
var current_speed_label: Label

# Speed options matching TickManager.SPEED_PRESETS
const SPEEDS: Array[float] = [1.0, 3.0, 6.0, 12.0, 26.0, 50.0, 100.0]
const SPEED_LABELS: Array[String] = ["1x", "3x", "6x", "12x", "26x", "50x", "100x"]

var selected_speed_index: int = 0  # Default to 1x (index 0)


func _ready() -> void:
	# Create UI if not already present
	_create_ui()
	# Connect to TickManager if available
	_connect_to_tick_manager()


func _create_ui() -> void:
	# Set up container
	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.name = "SpeedControlContainer"
	add_child(hbox)
	
	# Pause button
	pause_button = Button.new()
	pause_button.name = "PauseButton"
	pause_button.text = "Pause"
	pause_button.pressed.connect(_on_pause_pressed)
	hbox.add_child(pause_button)
	
	# Spacer
	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(10, 0)
	hbox.add_child(spacer)
	
	# Speed buttons
	for i in range(SPEEDS.size()):
		var btn: Button = Button.new()
		btn.name = "SpeedButton_%d" % i
		btn.text = SPEED_LABELS[i]
		btn.pressed.connect(_on_speed_pressed.bind(i))
		speed_buttons.append(btn)
		hbox.add_child(btn)
	
	# Current speed label
	var label_spacer: Control = Control.new()
	label_spacer.custom_minimum_size = Vector2(10, 0)
	hbox.add_child(label_spacer)
	
	current_speed_label = Label.new()
	current_speed_label.name = "SpeedLabel"
	current_speed_label.text = "Speed: 1x"
	hbox.add_child(current_speed_label)
	
	# Set initial selection
	_update_button_highlight()


func _connect_to_tick_manager() -> void:
	if TickMgr == null:
		TickMgr = get_node_or_null("/root/TickManager")
	if TickMgr != null:
		# Sync initial state
		selected_speed_index = TickMgr.get_speed_index()
		_update_button_highlight()
		_update_pause_button()


func _on_pause_pressed() -> void:
	if TickMgr == null:
		return
	TickMgr.toggle_pause()
	_update_pause_button()
	pause_toggled.emit(TickMgr.is_paused())


func _on_speed_pressed(speed_idx: int) -> void:
	if TickMgr == null:
		return
	TickMgr.set_speed_index(speed_idx)
	selected_speed_index = speed_idx
	_update_button_highlight()
	_update_speed_label()
	speed_changed.emit(TickMgr.get_speed_multiplier())


func _update_button_highlight() -> void:
	for i in range(speed_buttons.size()):
		if i == selected_speed_index:
			speed_buttons[i].modulate = Color.YELLOW
		else:
			speed_buttons[i].modulate = Color.WHITE


func _update_pause_button() -> void:
	if TickMgr == null:
		return
	if TickMgr.is_paused():
		pause_button.text = "Resume"
	else:
		pause_button.text = "Pause"


func _update_speed_label() -> void:
	if TickMgr == null or current_speed_label == null:
		return
	current_speed_label.text = "Speed: %s" % SPEED_LABELS[selected_speed_index]


## Public method to set speed (can be called by other scripts)
func set_speed(multiplier: float) -> void:
	if TickMgr == null:
		return
	TickMgr.set_speed(multiplier)
	selected_speed_index = TickMgr.get_speed_index()
	_update_button_highlight()
	_update_speed_label()


## Public method to pause/resume
func pause_game() -> void:
	if TickMgr == null:
		return
	TickMgr.pause()
	_update_pause_button()


func resume_game() -> void:
	if TickMgr == null:
		return
	TickMgr.resume()
	_update_pause_button()


func toggle_pause_game() -> void:
	if TickMgr == null:
		return
	TickMgr.toggle_pause()
	_update_pause_button()
