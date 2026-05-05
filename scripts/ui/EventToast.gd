extends PanelContainer
class_name EventToast

@onready var label: Label = %MessageLabel

func setup(msg: String) -> void:
	label.text = msg
	var tw = create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 3.0).set_delay(2.0)
	tw.finished.connect(queue_free)
