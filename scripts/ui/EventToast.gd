extends PanelContainer
class_name EventToast

func setup(msg: String) -> void:
	var label: Label = get_node_or_null("%MessageLabel")
	if label == null:
		# Fallback: search children for a Label
		for child in get_children():
			if child is Label:
				label = child as Label
				break
	if label == null:
		return
	label.text = msg
	var tw = create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 3.0).set_delay(2.0)
	tw.finished.connect(queue_free)
