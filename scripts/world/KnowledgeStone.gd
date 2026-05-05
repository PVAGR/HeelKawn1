extends Node2D
class_name KnowledgeStone

## Interactive Knowledge Stone - can be right-clicked to read inscribed knowledge
## Spawned when pawn completes CARVE_KNOWLEDGE_STONE job

@export var tile_pos: Vector2i = Vector2i.ZERO
@export var carrier_type: String = "knowledge_stone"
@export var inscriber_id: int = -1
@export var inscribed_tick: int = 0
@export var knowledge_types: Array = []

var _sprite: Node2D
var _tooltip: Control = null


func _ready() -> void:
	position = Vector2(tile_pos.x * 16 + 8, tile_pos.y * 16 + 8)
	_create_sprite()
	_setup_interaction()


func _create_sprite() -> void:
	# Try to load texture
	var texture_path: String = "res://sprites/stone_marker.png"
	var texture: Texture2D = load(texture_path) if ResourceLoader.exists(texture_path) else null
	
	if texture == null:
		# Fallback: create colored rectangle as child
		var rect: ColorRect = ColorRect.new()
		rect.custom_minimum_size = Vector2(12, 12)
		rect.position = Vector2(-6, -6)  # Center on pawn
		match carrier_type:
			"grave_marker":
				rect.color = Color8(120, 120, 130)  # Gray grave
			"knowledge_stone":
				rect.color = Color8(100, 140, 180)  # Blue knowledge
			"ledger_stone":
				rect.color = Color8(160, 140, 100)  # Tan ledger
			_:
				rect.color = Color8(140, 140, 140)  # Generic gray
		add_child(rect)
		_sprite = rect as Node2D
	else:
		# Use sprite with texture
		_sprite = Sprite2D.new()
		_sprite.texture = texture
		add_child(_sprite)
	
	# Add glow effect
	if _sprite != null:
		_sprite.modulate = Color(1.0, 1.0, 1.0, 0.8)


func _setup_interaction() -> void:
	# Enable mouse interaction on this Node2D
	z_index = 100


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_RIGHT and mouse_event.pressed:
			_show_reading_ui()
		elif mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			_show_preview_tooltip()


func _show_reading_ui() -> void:
	# Get full knowledge stone text from KnowledgeSystem
	var ks: Node = get_node_or_null("/root/KnowledgeSystem")
	if ks == null:
		return
	
	var stone_text: String = ""
	if ks.has_method("get_knowledge_stone_text"):
		stone_text = ks.call("get_knowledge_stone_text", tile_pos)
	
	# Create reading dialog
	var dialog: AcceptDialog = AcceptDialog.new()
	dialog.title = "Read Knowledge Stone"
	dialog.dialog_text = stone_text
	dialog.exclusive = false
	dialog.resizable = true
	dialog.size = Vector2(500, 400)
	
	# Add close button
	var close_btn: Button = Button.new()
	close_btn.text = "Close"
	close_btn.pressed.connect(dialog.queue_free)
	dialog.add_button("Close", true, "close")
	
	# Add to scene
	get_tree().root.add_child(dialog)
	dialog.popup_centered()
	
	# Record that pawn read this stone (if pawn is nearby)
	_try_record_reading()


func _show_preview_tooltip() -> void:
	# Show brief preview on left-click
	var preview: String = "📜 Inscribed Stone\n"
	
	# Get inscriber name
	var inscriber_name: String = "Unknown"
	var ps: Node = get_node_or_null("/root/PawnSpawner")
	if ps != null and ps.has_method("pawn_data_for_id"):
		var pawn_data = ps.call("pawn_data_for_id", inscriber_id)
		if pawn_data != null:
			inscriber_name = pawn_data.display_name
	
	preview += "By: %s\n" % inscriber_name
	preview += "Knowledge: %d types" % knowledge_types.size()
	
	# Show tooltip using existing UI system
	var main_node: Node = get_tree().root.get_node_or_null("Main")
	if main_node != null and main_node.has_method("show_tile_tooltip"):
		main_node.call("show_tile_tooltip", tile_pos, preview)


func _try_record_reading() -> void:
	# Find nearby pawn (the one who clicked)
	var ps: Node = get_node_or_null("/root/PawnSpawner")
	if ps == null:
		return
	
	for pawn in ps.pawns:
		if pawn == null or not is_instance_valid(pawn):
			continue
		
		var dist: int = abs(pawn.data.tile_pos.x - tile_pos.x) + abs(pawn.data.tile_pos.y - tile_pos.y)
		if dist <= 2:  # Must be adjacent to read
			# Record reading in KnowledgeSystem
			var ks: Node = get_node_or_null("/root/KnowledgeSystem")
			if ks != null and ks.has_method("read_knowledge_from_stone"):
				ks.call("read_knowledge_from_stone", int(pawn.data.id), tile_pos)
			break


func set_data(data: Dictionary) -> void:
	if data.has("tile_pos"):
		tile_pos = Vector2i(data.tile_pos)
	if data.has("carrier_type"):
		carrier_type = data.carrier_type
	if data.has("inscriber_id"):
		inscriber_id = data.inscriber_id
	if data.has("inscribed_tick"):
		inscribed_tick = data.inscribed_tick
	if data.has("knowledge_types"):
		knowledge_types = data.knowledge_types


func get_data() -> Dictionary:
	return {
		"tile_pos": tile_pos,
		"carrier_type": carrier_type,
		"inscriber_id": inscriber_id,
		"inscribed_tick": inscribed_tick,
		"knowledge_types": knowledge_types
	}
