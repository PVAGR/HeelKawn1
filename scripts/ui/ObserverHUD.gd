extends CanvasLayer
class_name ObserverHUD

@onready var coord_label: Label = %CoordLabel
@onready var terrain_label: Label = %TerrainLabel

func _ready() -> void:
	_recenter()
	get_viewport().size_changed.connect(_recenter)

func _recenter() -> void:
	pass

func display_tile(pos: Vector2i, terrain: String) -> void:
	coord_label.text = "(%d, %d)" % [pos.x, pos.y]
	terrain_label.text = terrain
