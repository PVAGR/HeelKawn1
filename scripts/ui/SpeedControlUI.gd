extends HBoxContainer

@onready var tick_manager: Node = get_node_or_null("/root/TickManager")
var pause_btn: Button

func _ready() -> void:
	pause_btn = Button.new()
	pause_btn.name = "PauseButton"
	pause_btn.text = "Pause"
	pause_btn.pressed.connect(_on_pause_pressed)
	add_child(pause_btn)
	for speed in [1.0, 2.0, 4.0, 8.0]:
		var btn: Button = Button.new()
		btn.text = "%dx" % int(speed)
		btn.pressed.connect(_on_speed_pressed.bind(speed))
		add_child(btn)


func _on_pause_pressed() -> void:
	if tick_manager == null:
		return
	if bool(tick_manager.call("is_paused")):
		tick_manager.call("resume")
		pause_btn.text = "Pause"
	else:
		tick_manager.call("pause")
		pause_btn.text = "Resume"


func _on_speed_pressed(multiplier: float) -> void:
	if tick_manager == null:
		return
	tick_manager.call("set_speed", multiplier)
	tick_manager.call("resume")
	pause_btn.text = "Pause"
