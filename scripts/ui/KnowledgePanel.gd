extends PanelContainer
## KnowledgePanel.gd — Knowledge carriers, teaching chains, and "last carrier" alerts
##
## Shows per settlement:
## - Knowledge carriers (who knows what)
## - At-risk knowledge (only 1 carrier left)
## - Lost/dormant knowledge (can be rediscovered)
## - Teaching chains (who taught whom)

const KNOWLEDGE_TYPE_NAMES: Dictionary = {
	0: "Fire Keeping",
	1: "Food Storage",
	2: "Tool Making",
	3: "Season Reading",
	4: "Sickness Avoidance",
	5: "Navigation",
	6: "Shelter Building",
	7: "Memory Preservation",
	8: "Ruin Interpretation",
	9: "Hospitality",
	10: "Winter Survival",
	11: "Teaching",
	12: "Hunting",
	13: "Farming",
	14: "Combat",
	15: "Diplomacy",
	16: "Crafting",
	17: "Leadership",
	18: "Metallurgy",
	19: "Animal Husbandry",
	20: "Architecture",
	21: "Medicine",
	22: "Astronomy",
	23: "Engineering",
	24: "Writing",
	25: "Philosophy",
}

var _knowledge_system: Node = null
var _pawn_spawner: Node = null
var _current_settlement_id: int = -1

@onready var _settlement_label: Label = $MarginContainer/VBoxContainer/SettlementLabel
@onready var _carriers_list: VBoxContainer = _get_node_safe("MarginContainer/VBoxContainer/ScrollContainer/Content/CarriersList")
@onready var _at_risk_list: VBoxContainer = _get_node_safe("MarginContainer/VBoxContainer/ScrollContainer/Content/AtRiskList")
@onready var _dormant_list: VBoxContainer = _get_node_safe("MarginContainer/VBoxContainer/ScrollContainer/Content/DormantList")
@onready var _close_button: Button = $MarginContainer/VBoxContainer/CloseButton


func _ready() -> void:
	_knowledge_system = get_node_or_null("/root/KnowledgeSystem")
	_pawn_spawner = get_node_or_null("/root/Main/WorldViewport/PawnSpawner")
	
	# Verify critical nodes exist
	if not _verify_nodes():
		push_error("[KnowledgePanel] Missing required nodes - panel will not display correctly")
		visible = false
		return
	
	_close_button.pressed.connect(_on_close_pressed)
	
	# Hide by default
	visible = false
	
	# Build initial (empty) lists
	_build_carrier_list()


func _verify_nodes() -> bool:
	return (
		_settlement_label != null and
		_carriers_list != null and
		_at_risk_list != null and
		_dormant_list != null and
		_close_button != null
	)


func _get_node_safe(path: String) -> VBoxContainer:
	var node = get_node_or_null(path)
	if node == null:
		# Create fallback node if path doesn't exist
		node = VBoxContainer.new()
		node.name = path.split("/")[-1]
		add_child(node)
	return node


func _input(event: InputEvent) -> void:
	if not visible:
		return
	
	# Toggle with K key
	if event is InputEventKey and event.pressed and event.keycode == KEY_K:
		visible = not visible
		if visible:
			_refresh_display()


## Set the settlement to display
func set_settlement(settlement_id: int) -> void:
	_current_settlement_id = settlement_id
	_settlement_label.text = "Settlement: #%d" % settlement_id
	_refresh_display()


## Refresh the display
func _refresh_display() -> void:
	if _knowledge_system == null:
		return
	
	# Clear lists
	_clear_list(_carriers_list)
	_clear_list(_at_risk_list)
	_clear_list(_dormant_list)
	
	# Get knowledge security for settlement
	var security: Dictionary = _knowledge_system.get_knowledge_security_for_settlement(_current_settlement_id)
	
	# Show carriers
	_show_carriers(security.get("secure", []))
	
	# Show at-risk knowledge
	_show_at_risk(security.get("at_risk", []))
	
	# Show dormant knowledge
	_show_dormant()


func _clear_list(list: VBoxContainer) -> void:
	for child in list.get_children():
		child.queue_free()


func _build_carrier_list() -> void:
	# Already built in scene
	pass


func _build_at_risk_list() -> void:
	# Already built in scene
	pass


func _build_dormant_list() -> void:
	# Already built in scene
	pass


func _show_carriers(secure_knowledge: Array) -> void:
	if secure_knowledge.is_empty():
		var label: Label = Label.new()
		label.text = "[color=#888888][i]No knowledge carriers in this settlement[/i][/color]"
		label.add_theme_font_size_override("font_size", 11)
		_carriers_list.add_child(label)
		return
	
	# Group by knowledge type
	for knowledge_type in secure_knowledge:
		var type_name: String = KNOWLEDGE_TYPE_NAMES.get(knowledge_type, "Unknown")
		
		# Get carriers for this knowledge type
		var carriers: Array = _get_carriers_for_knowledge(knowledge_type)
		
		var carrier_text: String = ""
		for i in range(min(3, carriers.size())):
			if i > 0:
				carrier_text += ", "
			carrier_text += carriers[i]
		
		if carriers.size() > 3:
			carrier_text += " (+%d more)" % (carriers.size() - 3)
		
		var label: Label = Label.new()
		label.text = "[b]%s[/b]\n  Carriers: %s" % [type_name, carrier_text]
		label.add_theme_font_size_override("font_size", 11)
		_carriers_list.add_child(label)


func _show_at_risk(at_risk_knowledge: Array) -> void:
	if at_risk_knowledge.is_empty():
		var label: Label = Label.new()
		label.text = "[color=#44FF44][i]All knowledge has multiple carriers[/i][/color]"
		label.add_theme_font_size_override("font_size", 11)
		_at_risk_list.add_child(label)
		return
	
	for knowledge_type in at_risk_knowledge:
		var type_name: String = KNOWLEDGE_TYPE_NAMES.get(knowledge_type, "Unknown")
		var carrier: String = _get_last_carrier_name(knowledge_type)
		
		var label: Label = Label.new()
		label.text = "[color=#FF4444][b]%s[/b][/color]\n  Last carrier: %s\n  [color=#FF8800]⚠️ If they die untaught, this knowledge is lost forever![/color]" % [
			type_name, carrier
		]
		label.add_theme_font_size_override("font_size", 11)
		_at_risk_list.add_child(label)


func _show_dormant() -> void:
	var dormant_types: Array = _knowledge_system.get_dormant_knowledge_types()
	
	if dormant_types.is_empty():
		var label: Label = Label.new()
		label.text = "[color=#888888][i]No lost knowledge[/i][/color]"
		label.add_theme_font_size_override("font_size", 11)
		_dormant_list.add_child(label)
		return
	
	for knowledge_type in dormant_types:
		var type_name: String = KNOWLEDGE_TYPE_NAMES.get(knowledge_type, "Unknown")
		var info: Dictionary = _knowledge_system.get_dormant_info(knowledge_type)
		
		var last_location: Vector2i = info.get("last_known_location", Vector2i.ZERO)
		var ticks_ago: int = GameManager.tick_count - info.get("last_practiced_tick", 0)
		
		var label: Label = Label.new()
		label.text = "[color=#AAAAAA]%s[/color]\n  Last practiced: %d ticks ago at (%d, %d)\n  [color=#44CCFF]Curious pawns may rediscover it[/color]" % [
			type_name, ticks_ago, last_location.x, last_location.y
		]
		label.add_theme_font_size_override("font_size", 11)
		_dormant_list.add_child(label)


func _get_carriers_for_knowledge(knowledge_type: int) -> Array[String]:
	var carriers: Array[String] = []
	
	if _pawn_spawner == null or _knowledge_system == null:
		return carriers
	
	# Get all pawns with this knowledge
	for pawn in _pawn_spawner.pawns:
		if pawn == null or not is_instance_valid(pawn) or pawn.data == null:
			continue
		
		var pawn_id: int = int(pawn.data.id)
		var pawn_knowledge: Array = _knowledge_system.get_pawn_knowledge(pawn_id)
		
		if knowledge_type in pawn_knowledge:
			carriers.append(pawn.data.display_name)
	
	return carriers


func _get_last_carrier_name(knowledge_type: int) -> String:
	var carriers: Array = _get_carriers_for_knowledge(knowledge_type)
	if carriers.is_empty():
		return "Unknown"
	return carriers[0]


func _on_close_pressed() -> void:
	visible = false


## Toggle menu visibility
func toggle_menu() -> void:
	visible = not visible
	if visible:
		_refresh_display()
