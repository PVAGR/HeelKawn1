extends PanelContainer
## ChronicleReader - Read historical chronicles and action ledger
##
## Shows:
## - Auto-generated chronicles (Age of Survival, etc.)
## - Action ledger (who did what, when)
## - World scars (permanent marks)
## - Search/filter options

var _world_action_ledger: Node = null

@onready var chronicle_list: ItemList = $MarginContainer/HSplitContainer/VBoxContainer/ChronicleList
@onready var chronicle_content: TextEdit = $MarginContainer/HSplitContainer/VBoxContainer/ChronicleContent
@onready var filter_tabs: TabContainer = $MarginContainer/HSplitContainer/VBoxContainer/FilterTabs

var _chronicles: Array[Dictionary] = []
var _selected_chronicle: int = -1


func _ready() -> void:
	_world_action_ledger = get_node_or_null("/root/WorldActionLedger")
	
	# Hide by default
	visible = false
	
	# Setup filter tabs
	filter_tabs.set_tab_title(0, "Chronicles")
	filter_tabs.set_tab_title(1, "Actions")
	filter_tabs.set_tab_title(2, "Scars")


func _on_show_pressed() -> void:
	visible = true
	_load_chronicles()


func _load_chronicles() -> void:
	if _world_action_ledger == null:
		return
	
	# Clear existing
	chronicle_list.clear()
	chronicle_content.text = ""
	
	# Get chronicles
	_chronicles = _world_action_ledger.get_all_chronicles()
	
	# Add to list
	for i in range(_chronicles.size()):
		var chronicle: Dictionary = _chronicles[i]
		var title: String = chronicle.get("title", "Unknown Chronicle")
		var era: String = chronicle.get("era", "Unknown Era")
		chronicle_list.add_item("%s - %s" % [era, title])


func _on_chronicle_list_item_selected(index: int) -> void:
	if index < 0 or index >= _chronicles.size():
		return
	
	_selected_chronicle = index
	var chronicle: Dictionary = _chronicles[index]
	
	# Display content
	var content: String = chronicle.get("content", "")
	var title: String = chronicle.get("title", "")
	var era: String = chronicle.get("era", "")
	var year: int = chronicle.get("covers_period", {}).get("start", 0) / 360
	
	chronicle_content.text = """
[center][font_size=16]%s[/font_size][/center]

[center][font_size=12]%s[/font_size][/center]

[center][font_size=10]Year %d[/font_size][/center]

%s
""" % [title, era, year, content]


func _on_actions_tab_selected() -> void:
	if _world_action_ledger == null:
		return
	
	# Clear existing
	chronicle_list.clear()
	chronicle_content.text = ""
	
	# Get recent actions
	var actions: Array[Dictionary] = _world_action_ledger.get_full_ledger()
	
	# Show last 50 actions
	var start: int = max(0, actions.size() - 50)
	
	for i in range(start, actions.size()):
		var action: Dictionary = actions[i]
		var actor: String = action.get("actor_name", "Unknown")
		var action_type: String = action.get("action_type", "unknown")
		var desc: String = action.get("action_description", "")
		var year: int = action.get("year", 0)
		
		chronicle_list.add_item("[Year %d] %s: %s" % [year, actor, desc])


func _on_scars_tab_selected() -> void:
	if _world_action_ledger == null:
		return
	
	# Clear existing
	chronicle_list.clear()
	chronicle_content.text = ""
	
	# Get scars
	var scars: Array[Dictionary] = _world_action_ledger.world_scars
	
	for scar in scars:
		var scar_type: String = scar.get("type", "unknown")
		var desc: String = scar.get("description", "")
		var permanent: bool = scar.get("permanent", false)
		
		var icon: String = "⚔️" if scar_type == "battle" else "🌋" if scar_type == "disaster" else "🏗️"
		var perm_text: String = "∞" if permanent else "temp"
		
		chronicle_list.add_item("%s %s (%s)" % [icon, desc, perm_text])


func _on_hide_pressed() -> void:
	visible = false


## Show chronicle reader
func show_reader() -> void:
	visible = true
	_load_chronicles()


## Hide chronicle reader
func hide_reader() -> void:
	visible = false
