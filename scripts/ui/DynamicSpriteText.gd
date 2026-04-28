extends Node2D
class_name DynamicSpriteText
## Dynamic Sprite Text System - Similar to AI matrix for dynamic world information
## Provides real-time text overlays on sprites with customizable content

enum TextMode {
	PAWN_INFO = 0,      # Name, health, mood, job
	SETTLEMENT_INFO = 1, # Name, population, culture, state
	RESOURCE_INFO = 2,   # Type, amount, status
	AGENT_INFO = 3,      # Agent ID, type, goals
	CUSTOM = 4           # User-defined content
}

var target_sprite: Sprite2D = null
var text_mode: TextMode = TextMode.PAWN_INFO
var label: Label = null
var update_frequency: float = 1.0  # Update every second
var time_since_update: float = 0.0
var enabled: bool = true
var custom_content: String = ""

# Text formatting
var font_color: Color = Color.WHITE
var font_size: int = 12
var background_color: Color = Color(0, 0, 0, 0.7)
var offset: Vector2 = Vector2(0, -20)

func _ready() -> void:
	_create_label()

func _create_label() -> void:
	label = Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", font_color)
	label.z_index = 1000  # Render on top
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	# Add background panel
	var panel: Panel = Panel.new()
	panel.add_theme_stylebox_override("panel", create_background_style())
	
	# Create container
	var container: VBoxContainer = VBoxContainer.new()
	container.add_child(panel)
	panel.add_child(label)
	
	add_child(container)
	
	# Position container above target sprite
	if target_sprite:
		container.position = target_sprite.position + offset

func create_background_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = background_color
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.5, 0.5, 0.5, 0.8)
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	return style

func _process(delta: float) -> void:
	if not enabled or target_sprite == null:
		return
	
	time_since_update += delta
	if time_since_update >= update_frequency:
		_update_text()
		time_since_update = 0.0
	
	# Follow target sprite
	if target_sprite:
		position = target_sprite.global_position + offset

func _update_text() -> void:
	if label == null:
		return
	
	var text: String = ""
	
	match text_mode:
		TextMode.PAWN_INFO:
			text = _get_pawn_info_text()
		TextMode.SETTLEMENT_INFO:
			text = _get_settlement_info_text()
		TextMode.RESOURCE_INFO:
			text = _get_resource_info_text()
		TextMode.AGENT_INFO:
			text = _get_agent_info_text()
		TextMode.CUSTOM:
			text = custom_content
	
	label.text = text

func _get_pawn_info_text() -> String:
	if target_sprite == null:
		return ""
	
	# Try to get pawn from sprite
	var pawn: Pawn = null
	if target_sprite.get_parent() is Pawn:
		pawn = target_sprite.get_parent()
	elif target_sprite.has_method("get_pawn"):
		pawn = target_sprite.call("get_pawn")
	
	if pawn == null or pawn.data == null:
		return ""
	
	var name: String = pawn.data.display_name
	var health: int = pawn.data.health_percentage
	var mood: float = pawn.data.mood
	var job: String = pawn.data.current_job
	
	return "%s\nHP: %d%%\nMood: %.0f\nJob: %s" % [name, health, mood, job]

func _get_settlement_info_text() -> String:
	# Dynamic neural network matrix connection to HeelKawn Universe
	var settlement_id: int = -1
	var settlement_data: Dictionary = {}
	
	# Get settlement from neural network matrix
	if target_sprite.has_meta("settlement_id"):
		settlement_id = target_sprite.get_meta("settlement_id")
	
	if settlement_id >= 0 and SettlementMemory != null:
		settlement_data = SettlementMemory.get_settlement(settlement_id)
	
	if settlement_data.has("error") or settlement_data.is_empty():
		return "Settlement\nID: Unknown\nPop: ?\nCulture: ?\nState: Active"
	
	var population: int = settlement_data.get("population", 0)
	var culture_type: int = settlement_data.get("culture_type", 0)
	var state: String = settlement_data.get("state", "unknown")
	var center_region: int = settlement_data.get("center_region", -1)
	
	# Connect to neural network matrix for cultural data
	var culture_name: String = "Unknown"
	if CulturalMemory != null:
		var culture_data = CulturalMemory.get_culture_at_region(center_region)
		if not culture_data.is_empty():
			culture_name = culture_data.get("name", "Unknown")
	
	return "Settlement\nPop: %d\nCulture: %s\nState: %s" % [population, culture_name, state]

func _get_resource_info_text() -> String:
	# Dynamic neural network matrix connection to HeelKawn Universe
	var tile_pos: Vector2i = Vector2i(-1, -1)
	var resource_data: Dictionary = {}
	
	# Get tile position from sprite
	if target_sprite.has_meta("tile_pos"):
		tile_pos = target_sprite.get_meta("tile_pos")
	
	if tile_pos.x >= 0 and WorldMemory != null:
		resource_data = WorldMemory.get_resource_at_tile(tile_pos)
	
	if resource_data.is_empty():
		return "Resource\nType: None\nAmount: 0\nStatus: Empty"
	
	var resource_type: String = resource_data.get("type", "unknown")
	var amount: int = resource_data.get("amount", 0)
	var quality: float = resource_data.get("quality", 0.0)
	var extraction_rate: float = resource_data.get("extraction_rate", 0.0)
	
	# Connect to neural network matrix for resource analysis
	var status: String = "Available"
	if amount <= 0:
		status = "Depleted"
	elif extraction_rate <= 0.1:
		status = "Poor"
	elif extraction_rate >= 0.8:
		status = "Rich"
	
	return "Resource\nType: %s\nAmount: %d\nStatus: %s" % [resource_type, amount, status]

func _get_agent_info_text() -> String:
	# Try to get AI agent from sprite
	var agent_id: int = -1
	if target_sprite.has_meta("agent_id"):
		agent_id = target_sprite.get_meta("agent_id")
	
	if agent_id < 0:
		return "Agent\nID: Unknown\nType: ?\nGoals: ?"
	
	var agent_status: Dictionary = {}
	if AIAgentManager != null:
		agent_status = AIAgentManager.get_agent_status(agent_id)
	
	if agent_status.has("error"):
		return "Agent\nID: %d\nStatus: Error" % agent_id
	
	var agent_type: int = agent_status.get("agent_type", 0)
	var goal_count: int = agent_status.get("current_goals", 0)
	var controlled_pawn: int = agent_status.get("controlled_pawn_id", -1)
	
	var type_name: String = "Unknown"
	match agent_type:
		0: type_name = "Strategic"
		1: type_name = "Tactical"
		2: type_name = "Reactive"
	
	return "Agent %d\nType: %s\nGoals: %d\nPawn: %d" % [agent_id, type_name, goal_count, controlled_pawn]

# === Public Interface ===

func set_target_sprite(sprite: Sprite2D) -> void:
	target_sprite = sprite
	if label:
		position = sprite.global_position + offset

func set_text_mode(mode: TextMode) -> void:
	text_mode = mode
	_update_text()

func set_custom_content(content: String) -> void:
	custom_content = content
	if text_mode == TextMode.CUSTOM:
		_update_text()

func set_enabled(is_enabled: bool) -> void:
	enabled = is_enabled
	if label:
		label.visible = is_enabled

func set_update_frequency(frequency: float) -> void:
	update_frequency = frequency

func set_font_size(size: int) -> void:
	font_size = size
	if label:
		label.add_theme_font_size_override("font_size", font_size)

func set_font_color(color: Color) -> void:
	font_color = color
	if label:
		label.add_theme_color_override("font_color", font_color)

func set_background_color(color: Color) -> void:
	background_color = color
	if label:
		var panel: Panel = label.get_parent() as Panel
		if panel:
			panel.add_theme_stylebox_override("panel", create_background_style())

func set_offset(new_offset: Vector2) -> void:
	offset = new_offset

func get_current_text() -> String:
	if label:
		return label.text
	return ""

# === Static Helper Methods ===

static func create_for_pawn(pawn: Pawn, parent: Node = null) -> DynamicSpriteText:
	var text_node: DynamicSpriteText = DynamicSpriteText.new()
	text_node.text_mode = TextMode.PAWN_INFO
	
	# Find pawn sprite
	var sprite: Sprite2D = null
	if pawn.get_child_count() > 0:
		for child in pawn.get_children():
			if child is Sprite2D:
				sprite = child
				break
	
	if sprite:
		text_node.set_target_sprite(sprite)
		if parent:
			parent.add_child(text_node)
		else:
			pawn.add_child(text_node)
	
	return text_node

static func create_for_agent(agent_id: int, parent: Node = null) -> DynamicSpriteText:
	var text_node: DynamicSpriteText = DynamicSpriteText.new()
	text_node.text_mode = TextMode.AGENT_INFO
	
	# Find agent's controlled pawn sprite
	var pawn_id: int = -1
	if AIAgentManager != null:
		var agent_status: Dictionary = AIAgentManager.get_agent_status(agent_id)
		pawn_id = agent_status.get("controlled_pawn_id", -1)
	
	if pawn_id >= 0:
		# Find pawn in world
		var pawn_spawner: PawnSpawner = GameManager.get_node("/root/Main/PawnSpawner")
		if pawn_spawner:
			for pawn in pawn_spawner.pawns:
				if pawn != null and pawn.data != null and pawn.data.id == pawn_id:
					return create_for_pawn(pawn, parent)
	
	return text_node
