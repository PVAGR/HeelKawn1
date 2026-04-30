class_name RegionInspector
extends PanelContainer

const PANEL_BG: Color = Color(0.05, 0.06, 0.08, 0.85)
const PANEL_BORDER: Color = Color(0.60, 0.70, 0.85, 0.75)
const FONT_SIZE: int = 13

@onready var _title_label: Label = $VBoxContainer/TitleLabel
@onready var _region_info: RichTextLabel = $VBoxContainer/RegionInfo
@onready var _settlement_info: RichTextLabel = $VBoxContainer/SettlementInfo
@onready var _history_info: RichTextLabel = $VBoxContainer/HistoryInfo

var _current_region_key: int = -1
var _refresh_ticks: int = 0
const REFRESH_INTERVAL: int = 120


func _ready() -> void:
	_apply_panel_style()
	visible = false


func _process(_delta: float) -> void:
	if not visible:
		return
	if _refresh_ticks <= 0:
		_refresh_ticks = REFRESH_INTERVAL
		_update_display()
	else:
		_refresh_ticks -= 1


func set_region(region_key: int) -> void:
	_current_region_key = region_key
	visible = true
	_update_display()


func close() -> void:
	visible = false
	_current_region_key = -1


func _update_display() -> void:
	if _current_region_key < 0:
		_title_label.text = "No Region Selected"
		_region_info.text = ""
		_settlement_info.text = ""
		_history_info.text = ""
		return
	
	var region_data: Dictionary = _get_region_data(_current_region_key)
	_title_label.text = "Region: %s" % str(region_data.get("name", "Unknown"))
	_region_info.text = _format_region_info(region_data)
	_settlement_info.text = _format_settlement_info(region_data)
	_history_info.text = _format_history_info(region_data)


func _get_region_data(region_key: int) -> Dictionary:
	var data: Dictionary = {
		"region_key": region_key,
		"name": "Region %d" % region_key,
		"center": Vector2i.ZERO,
		"settlements": [],
		"deaths": 0,
		"births": 0,
		"events": []
	}
	
	# Get region center from SettlementMemory
	var center: Vector2i = SettlementMemory.get_center_region_for_region(region_key)
	if center != Vector2i(-1, -1):
		data.center = center
		data.name = "Region (%d, %d)" % [center.x, center.y]
	
	# Get settlement data
	var settlement: Variant = SettlementMemory.get_settlement_at_region(region_key)
	if settlement != null:
		data.settlements = [settlement]
	
	# Get death/birth counts from WorldMemory (approximate using recent events)
	var wm = preload("res://autoloads/WorldMemory.gd")
	var recent_events: Array = wm.get_recent_events_for_settlement(region_key, 10)
	var death_count: int = 0
	var birth_count: int = 0
	var event_list: Array = []
	
	for event in recent_events:
		var event_type: String = str(event.get("type", ""))
		if event_type == "death":
			death_count += 1
		elif event_type == "birth":
			birth_count += 1
		event_list.append(event)
	
	data.deaths = death_count
	data.births = birth_count
	data.events = event_list
	
	return data


func _format_region_info(data: Dictionary) -> String:
	return (
		"[b]Region Center:[/b] %s\n" % str(data.center)
		+ "[b]Settlements:[/b] %d\n" % data.settlements.size()
		+ "[b]Total Deaths:[/b] %d\n" % data.deaths
		+ "[b]Total Births:[/b] %d\n" % data.births
	)


func _format_settlement_info(data: Dictionary) -> String:
	if data.settlements.is_empty():
		return "[i]No settlements in this region.[/i]\n"
	
	var text: String = "[b]Settlements:[/b]\n"
	for settlement in data.settlements:
		var name: String = str(settlement.get("name", "Unknown"))
		var state: String = str(settlement.get("state", "Unknown"))
		var population: int = int(settlement.get("population", 0))
		text += "• %s [%s] - Pop: %d\n" % [name, state, population]
	
	return text


func _format_history_info(data: Dictionary) -> String:
	if data.events.is_empty():
		return "[i]No recent events recorded.[/i]\n"
	
	var text: String = "[b]Recent Events:[/b]\n"
	for event in data.events:
		var tick: int = int(event.get("tick", 0))
		var type: String = str(event.get("type", "Unknown"))
		var desc: String = str(event.get("description", ""))
		text += "Tick %d: %s - %s\n" % [tick, type, desc]
	
	return text


func _apply_panel_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_BG
	style.border_color = PANEL_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	add_theme_stylebox_override("panel", style)
	
	if _title_label != null:
		_title_label.add_theme_font_size_override("normal_font_size", FONT_SIZE + 2)
		_title_label.add_theme_color_override("font_color", Color(0.85, 0.90, 0.95))
	
	if _region_info != null:
		_region_info.add_theme_font_size_override("normal_font_size", FONT_SIZE)
	if _settlement_info != null:
		_settlement_info.add_theme_font_size_override("normal_font_size", FONT_SIZE)
	if _history_info != null:
		_history_info.add_theme_font_size_override("normal_font_size", FONT_SIZE)
