extends CanvasLayer
class_name ColonyHUD

@onready var day_label: Label = %DayLabel
@onready var bio_label: Label = %BioLabel
@onready var rock_label: Label = %RockLabel
@onready var alert_list: VBoxContainer = %AlertList

func _ready() -> void:
	_recenter()
	get_viewport().size_changed.connect(_recenter)

func _recenter() -> void:
	var vs = get_viewport().get_visible_rect().size
	# Adjust positioning logic here if needed for responsive UI
	pass

func update_stats(day: int, bio: int, rock: int) -> void:
	day_label.text = "Day: " + str(day)
	bio_label.text = "Bio: " + str(bio)
	rock_label.text = "Rock: " + str(rock)
