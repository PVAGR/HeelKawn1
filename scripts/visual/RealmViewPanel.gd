extends PanelContainer
class_name RealmViewPanel

## Compact realm summary panel.
## It presents the read-only data prepared by TerritoryRenderer and keeps the
## UI free of settlement logic.

var _title_label: Label = null
var _summary_label: Label = null
var _body: RichTextLabel = null


func _ready() -> void:
	_build_ui()


func refresh_from_world(realm_summaries: Array) -> void:
	if _title_label == null or _summary_label == null or _body == null:
		_build_ui()
	_title_label.text = "Realm Ledger"
	_summary_label.text = "%d realm%s" % [realm_summaries.size(), "s" if realm_summaries.size() != 1 else ""]
	var lines: PackedStringArray = []
	if realm_summaries.is_empty():
		lines.append("No discovered realms yet.")
	else:
		var limit: int = mini(8, realm_summaries.size())
		for i in range(limit):
			var realm: Dictionary = realm_summaries[i] as Dictionary
			var name: String = str(realm.get("name", realm.get("house_name", "Realm")))
			var faction_name: String = str(realm.get("faction_name", "Independent"))
			var region_count: int = int(realm.get("region_count", 0))
			var population: int = int(realm.get("population", realm.get("pop", 0)))
			lines.append("[color=%s]■[/color] %s (%s, %d region%s, pop %d)" % [
				Color(0.92, 0.83, 0.55).to_html(false),
				name,
				faction_name,
				region_count,
				"s" if region_count != 1 else "",
				population,
			])
	_body.text = "\n".join(lines)


func _build_ui() -> void:
	for child in get_children():
		remove_child(child)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.07, 0.09, 0.95)
	style.border_color = Color(0.83, 0.72, 0.40, 0.75)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	add_theme_stylebox_override("panel", style)
	custom_minimum_size = Vector2(320, 220)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	add_child(margin)
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	margin.add_child(vbox)
	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", 14)
	_title_label.modulate = Color(1.0, 0.92, 0.65)
	vbox.add_child(_title_label)
	_summary_label = Label.new()
	_summary_label.modulate = Color(0.88, 0.90, 0.93)
	vbox.add_child(_summary_label)
	_body = RichTextLabel.new()
	_body.bbcode_enabled = true
	_body.fit_content = true
	_body.scroll_active = false
	_body.custom_minimum_size = Vector2(0, 140)
	vbox.add_child(_body)
