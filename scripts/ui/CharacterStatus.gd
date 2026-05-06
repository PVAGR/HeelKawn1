extends PanelContainer
## CharacterStatus - Show pawn consciousness status
##
## Shows:
## - Self-awareness level (0-5)
## - Trauma level (0-100)
## - Growth points
## - Recent memories
## - Recent dreams
## - Core beliefs

var _pawn_consciousness: Node = null
var _selected_pawn_id: int = -1

@onready var awareness_label: Label = $MarginContainer/VBoxContainer/AwarenessBox/AwarenessLabel
@onready var trauma_label: Label = $MarginContainer/VBoxContainer/TraumaBox/TraumaLabel
@onready var growth_label: Label = $MarginContainer/VBoxContainer/GrowthBox/GrowthLabel
@onready var memories_list: ItemList = $MarginContainer/VBoxContainer/MemoriesBox/MemoriesList
@onready var dreams_list: ItemList = $MarginContainer/VBoxContainer/DreamsBox/DreamsList
@onready var beliefs_list: ItemList = $MarginContainer/VBoxContainer/BeliefsBox/BeliefsList


func _ready() -> void:
	_pawn_consciousness = get_node_or_null("/root/PawnConsciousness")
	
	# Hide by default
	visible = false


func set_selected_pawn(pawn_id: int) -> void:
	_selected_pawn_id = pawn_id
	_refresh_display()


func _refresh_display() -> void:
	if _pawn_consciousness == null or _selected_pawn_id < 0:
		return
	
	# Get consciousness data
	var consciousness: Dictionary = _pawn_consciousness.get_consciousness_summary(_selected_pawn_id)
	
	# Update awareness
	var awareness: int = consciousness.get("self_awareness", 0)
	var awareness_name: String = consciousness.get("awareness_name", "Unknown")
	awareness_label.text = "Awareness: %s (Level %d)" % [awareness_name, awareness]
	
	# Update trauma
	var trauma: float = consciousness.get("trauma_level", 0.0)
	trauma_label.text = "Trauma: %.1f/100" % trauma
	trauma_label.modulate = _get_trauma_color(trauma)
	
	# Update growth
	var growth: int = consciousness.get("growth_points", 0)
	growth_label.text = "Growth Points: %d" % growth
	
	# Update memories
	memories_list.clear()
	var memories: Array[Dictionary] = _pawn_consciousness.get_memories(_selected_pawn_id, "", 5)
	for memory in memories:
		var emotion: float = memory.get("emotion", 0.0)
		var emoji: String = "😊" if emotion > 0 else "😢" if emotion < 0 else "😐"
		var desc: String = memory.get("description", "")
		memories_list.add_item("%s %s" % [emoji, desc])
	
	# Update dreams
	dreams_list.clear()
	var dreams: Array[Dictionary] = consciousness.get("recent_dreams", [])
	for dream in dreams:
		var theme: String = dream.get("theme", "unknown")
		var content: String = dream.get("content", "")
		var lucid: bool = dream.get("lucid", false)
		var lucid_text: String = "✨ " if lucid else ""
		dreams_list.add_item("%s%s: %s" % [lucid_text, theme, content])
	
	# Update beliefs
	beliefs_list.clear()
	var beliefs: Array[String] = consciousness.get("core_beliefs", [])
	for belief in beliefs:
		beliefs_list.add_item("💭 " + belief)


func _get_trauma_color(trauma: float) -> Color:
	if trauma < 25:
		return Color(0.2, 0.8, 0.2)  # Green (low)
	elif trauma < 50:
		return Color(0.8, 0.8, 0.2)  # Yellow (moderate)
	elif trauma < 75:
		return Color(0.8, 0.5, 0.2)  # Orange (high)
	else:
		return Color(0.8, 0.2, 0.2)  # Red (severe)


## Show character status
func show_status() -> void:
	visible = true
	_refresh_display()


## Hide character status
func hide_status() -> void:
	visible = false


## Toggle character status
func toggle_status() -> void:
	visible = not visible
	if visible:
		_refresh_display()
