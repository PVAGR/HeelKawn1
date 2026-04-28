extends PanelContainer
class_name ObserverLensPanel

# Read-only HUD panel. Never mutates world state.
# Attach to a PanelContainer or MarginContainer in ColonyHUD.

@onready var narrative_label: Label = $VBoxContainer/NarrativeLabel
@onready var tags_label: Label = $VBoxContainer/TagsLabel
@onready var status_label: Label = $VBoxContainer/StatusLabel

var _target_zone: String = ""
var _refresh_ticks: int = 0
const REFRESH_INTERVAL: int = 400  # sparse UI updates only


func _process(_delta: float) -> void:
	if _refresh_ticks <= 0:
		_refresh_ticks = REFRESH_INTERVAL
		_update_display()
	else:
		_refresh_ticks -= 1


func set_target_zone(zone_id: String) -> void:
	_target_zone = zone_id
	_update_display()


func _update_display() -> void:
	if _target_zone.is_empty():
		narrative_label.text = "No zone selected"
		tags_label.text = ""
		status_label.text = ""
		return

	var snapshot: Dictionary = ObserverLens.get_zone_snapshot(_target_zone)
	var narrative: String = str(snapshot.get("narrative", "Unmarked"))
	var tags_v: Variant = snapshot.get("tags", PackedStringArray())
	var tags: PackedStringArray = tags_v as PackedStringArray if tags_v is PackedStringArray else PackedStringArray()
	var is_focus: bool = bool(snapshot.get("is_focus", false))

	var tags_text: String = "None"
	if tags.size() > 0:
		tags_text = str(tags[0])
		for i in range(1, tags.size()):
			tags_text += ", " + str(tags[i])

	narrative_label.text = narrative
	tags_label.text = "Tags: [%s]" % tags_text
	status_label.text = "Chronicler Focus: %s" % ("Yes" if is_focus else "No")
