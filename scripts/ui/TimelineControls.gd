class_name TimelineControls
extends HBoxContainer

const BTN_BG: Color = Color(0.1, 0.12, 0.15, 0.9)
const BTN_BORDER: Color = Color(0.50, 0.60, 0.70, 0.6)
const BTN_HOVER: Color = Color(0.15, 0.18, 0.22, 0.95)
const BTN_PRESSED: Color = Color(0.08, 0.10, 0.12, 0.95)

@onready var _pause_btn: Button = $PauseButton
@onready var _speed_label: Label = $SpeedLabel
@onready var _speed_down: Button = $SpeedDown
@onready var _speed_up: Button = $SpeedUp
@onready var _tick_label: Label = $TickLabel

var _speeds: Array[float] = [0.0, 0.5, 1.0, 2.0, 4.0, 8.0, 16.0, 32.0, 64.0, 128.0, 256.0, 512.0, 1024.0]
var _current_speed_index: int = 2  # Start at 1x


func _ready() -> void:
	_apply_button_style(_pause_btn)
	_apply_button_style(_speed_down)
	_apply_button_style(_speed_up)
	
	_pause_btn.pressed.connect(_on_pause_pressed)
	_speed_down.pressed.connect(_on_speed_down)
	_speed_up.pressed.connect(_on_speed_up)
	
	_update_display()


var _last_displayed_tick: int = -1


func _process(_delta: float) -> void:
	if _tick_label != null and GameManager != null:
		var cur_tick: int = GameManager.tick_count
		if cur_tick != _last_displayed_tick:
			_last_displayed_tick = cur_tick
			_tick_label.text = "Tick: %d" % cur_tick


func _on_pause_pressed() -> void:
	if GameManager != null:
		GameManager.toggle_pause()
	_update_display()


func _on_speed_down() -> void:
	if _current_speed_index > 0:
		_current_speed_index -= 1
		_apply_speed()


func _on_speed_up() -> void:
	if _current_speed_index < _speeds.size() - 1:
		_current_speed_index += 1
		_apply_speed()


func _apply_speed() -> void:
	var new_speed: float = _speeds[_current_speed_index]
	if GameManager != null:
		GameManager.set_game_speed(new_speed)
	_update_display()


func _update_display() -> void:
	if _pause_btn != null:
		_pause_btn.text = "▶" if GameManager.is_paused else "⏸"
	
	if _speed_label != null:
		var current_speed: float = GameManager.game_speed if GameManager != null else 1.0
		if current_speed == 0.0:
			_speed_label.text = "PAUSED"
		else:
			_speed_label.text = "%dx" % int(current_speed)


func _apply_button_style(btn: Button) -> void:
	if btn == null:
		return
	
	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = BTN_BG
	normal_style.border_color = BTN_BORDER
	normal_style.set_border_width_all(1)
	normal_style.set_corner_radius_all(3)
	
	var hover_style := StyleBoxFlat.new()
	hover_style.bg_color = BTN_HOVER
	hover_style.border_color = BTN_BORDER
	hover_style.set_border_width_all(1)
	hover_style.set_corner_radius_all(3)
	
	var pressed_style := StyleBoxFlat.new()
	pressed_style.bg_color = BTN_PRESSED
	pressed_style.border_color = BTN_BORDER
	pressed_style.set_border_width_all(1)
	pressed_style.set_corner_radius_all(3)
	
	btn.add_theme_stylebox_override("normal", normal_style)
	btn.add_theme_stylebox_override("hover", hover_style)
	btn.add_theme_stylebox_override("pressed", pressed_style)
	btn.add_theme_font_size_override("font_size", 16)
