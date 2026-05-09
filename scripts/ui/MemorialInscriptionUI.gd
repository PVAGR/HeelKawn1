extends PanelContainer
## MemorialInscriptionUI — Clickable memorial inscription display
##
## Shows when player clicks on a memorial tile:
## - Memorial type and inscription
## - List of associated pawns (clickable to see their stories)
## - Event details (when, why, what happened)

var _memorial_system: Node = null
var _current_memorial: Dictionary = {}
var _pawn_spawner: Node = null

@onready var _inscription_text: RichTextLabel = $MarginContainer/VBoxContainer/InscriptionText
@onready var _pawns_list: VBoxContainer = $MarginContainer/VBoxContainer/PawnsList
@onready var _close_button: Button = $MarginContainer/VBoxContainer/CloseButton


func _ready() -> void:
	_memorial_system = get_node_or_null("/root/MemorialSystem")
	_pawn_spawner = get_node_or_null("/root/Main/WorldViewport/PawnSpawner")
	
	_close_button.pressed.connect(_on_close_pressed)
	
	# Hide by default
	visible = false


func show_memorial_inscription(memorial: Dictionary) -> void:
	_current_memorial = memorial
	visible = true
	
	# Clear previous content
	_inscription_text.text = ""
	for child in _pawns_list.get_children():
		child.queue_free()
	
	# Build inscription display
	_build_inscription_display()


func _build_inscription_display() -> void:
	var memorial_type: String = _current_memorial.get("memorial_type", "unknown")
	var inscription: String = _current_memorial.get("custom_inscription", "")
	var created_tick: int = _current_memorial.get("created_tick", 0)
	var associated_pawns: Array = _current_memorial.get("associated_pawns", [])
	
	# Header with memorial type
	var type_name: String = _get_memorial_type_name(memorial_type)
	var year: float = float(created_tick) / 3600.0
	
	_inscription_text.text += "[color=#FFD166][b]%s[/b][/color]\n" % type_name
	_inscription_text.text += "[color=#888888]Year %.1f[/color]\n\n" % year
	
	# Inscription text
	if inscription != "":
		_inscription_text.text += "[color=#CCCCCC]%s[/color]\n\n" % inscription
	else:
		_inscription_text.text += "[color=#888888][i]No inscription[/i][/color]\n\n"
	
	# Associated pawns (clickable)
	if associated_pawns.size() > 0:
		_inscription_text.text += "\n[color=#FFD166]Remembered:[/color]\n"
		
		for pawn_id in associated_pawns:
			var pawn_name: String = _get_pawn_name(pawn_id)
			var pawn_data = _get_pawn_data(pawn_id)

			if pawn_data != null:
				var profession: String = pawn_data.profession_name()
				var age: float = pawn_data.age / 360.0
				_inscription_text.text += "• [color=#AAAAAA]%s[/color] - %s (%.1f yrs)\n" % [pawn_name, profession, age]
			else:
				_inscription_text.text += "• [color=#888888]%s[/color] (departed)\n" % pawn_name
	
	# Create clickable pawn list
	for pawn_id in associated_pawns:
		var pawn_name: String = _get_pawn_name(pawn_id)
		var button: Button = Button.new()
		button.text = "📖 Read %s's Story" % pawn_name
		button.custom_minimum_size = Vector2(360, 0)
		button.pressed.connect(_on_pawn_story_pressed.bind(pawn_id))
		_pawns_list.add_child(button)


func _get_memorial_type_name(memorial_type: String) -> String:
	var names: Dictionary = {
		"grave_marker": "Grave Marker",
		"battle_monument": "Battle Monument",
		"founding_stone": "Founding Stone",
		"ruin_marker": "Ruin Marker",
		"memorial_plaque": "Memorial Plaque",
		"mass_grave": "Mass Memorial"
	}
	return names.get(memorial_type, memorial_type.capitalize())


func _get_pawn_name(pawn_id: int) -> String:
	if _pawn_spawner == null:
		return "Unknown"
	
	var pawn_data = _pawn_spawner.call("pawn_data_for_id", pawn_id)
	if pawn_data != null:
		return pawn_data.display_name
	
	# HeelKawnian may be dead, try WorldMemory
	var wm = get_node_or_null("/root/WorldMemory")
	if wm != null and wm.has_method("last_known_name_from_death_record"):
		return wm.call("last_known_name_from_death_record", pawn_id)
	
	return "Unknown"


func _get_pawn_data(pawn_id: int) -> Node:
	if _pawn_spawner == null:
		return null
	return _pawn_spawner.call("pawn_data_for_id", pawn_id)


func _on_close_pressed() -> void:
	visible = false
	_current_memorial = {}


func _on_pawn_story_pressed(pawn_id: int) -> void:
	# Open PawnInfoPanel for this pawn
	var main = get_node_or_null("/root/Main")
	if main != null and main.has_method("select_pawn_by_id"):
		main.call("select_pawn_by_id", pawn_id)
	
	visible = false


## Check if tile has memorial and show inscription
func check_tile_for_memorial(tile: Vector2i) -> bool:
	if _memorial_system == null:
		return false
	
	var memorial = _memorial_system.get_memorial_at_tile(tile)
	if memorial.is_empty():
		return false
	
	show_memorial_inscription(memorial)
	return true


## Get memorial info for tooltip
func get_memorial_tooltip(tile: Vector2i) -> String:
	if _memorial_system == null:
		return ""
	
	var memorial = _memorial_system.get_memorial_at_tile(tile)
	if memorial.is_empty():
		return ""
	
	var type_name: String = _get_memorial_type_name(memorial.get("memorial_type", "unknown"))
	return "🏛️ %s\nClick to read inscription" % type_name
