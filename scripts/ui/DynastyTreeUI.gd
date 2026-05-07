extends CanvasLayer
class_name DynastyTreeUI

## Phase 7: Dynasty Tree Visualization
## Shows visual family tree with generations, connections, and legacy scores.

const MEMBER_WIDTH: int = 180
const MEMBER_HEIGHT: int = 60
const GENERATION_SPACING: int = 80
const MEMBER_SPACING: int = 20

var _scroll_container: ScrollContainer
var _tree_container: VBoxContainer
var _dynasty_id: int = -1
var _legacy_sys: Node


func _ready() -> void:
	layer = 95
	process_mode = Node.PROCESS_MODE_ALWAYS
	_legacy_sys = get_node_or_null("/root/LegacySystem")
	_build_ui()


func _build_ui() -> void:
	# Main window
	var window: Window = Window.new()
	window.title = "Dynasty Tree"
	window.size = Vector2(900, 600)
	window.position = Vector2(200, 100)
	window.close_requested.connect(window.queue_free)
	add_child(window)
	
	# Scroll container
	_scroll_container = ScrollContainer.new()
	_scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	window.add_child(_scroll_container)
	
	# Tree container (horizontal flow for generations)
	_tree_container = VBoxContainer.new()
	_tree_container.add_theme_constant_override("separation", GENERATION_SPACING)
	_scroll_container.add_child(_tree_container)
	
	# Instructions label
	var instructions: Label = Label.new()
	instructions.text = "Click member to see biography | Scroll to see all generations"
	instructions.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instructions.add_theme_color_override("font_color", Color8(180, 180, 190))
	_tree_container.add_child(instructions)


func show_dynasty(dynasty_id: int) -> void:
	_dynasty_id = dynasty_id
	_render_dynasty_tree()


func _render_dynasty_tree() -> void:
	if _legacy_sys == null or _dynasty_id < 0:
		return
	
	# Clear existing tree
	for child in _tree_container.get_children():
		if child.name != "Instructions":
			child.queue_free()
	
	# Get dynasty data
	var dynasty: Dictionary = _legacy_sys.call("get_dynasty_summary", _dynasty_id)
	if dynasty.is_empty():
		return
	
	# Add dynasty header
	var header: Label = Label.new()
	header.text = "━━━ %s ━━━" % dynasty.get("name", "Unknown Dynasty")
	header.add_theme_font_size_override("font_size", 16)
	header.add_theme_color_override("font_color", Color8(255, 209, 102))
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tree_container.add_child(header)
	
	# Add stats
	var stats: Label = Label.new()
	stats.text = "Generations: %d | Members: %d | Total Legacy: %d" % [
		dynasty.get("generations", 0),
		dynasty.get("members", 0),
		dynasty.get("legacy_score_total", 0)
	]
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tree_container.add_child(stats)
	
	# Get all members
	var member_ids: Array[int] = _legacy_sys.call("get_dynasty_members", _dynasty_id)
	if member_ids.is_empty():
		return
	
	# Group members by generation
	var members_by_gen: Dictionary = {}
	for pawn_id in member_ids:
		var generation: int = _get_pawn_generation(pawn_id)
		if not members_by_gen.has(generation):
			members_by_gen[generation] = []
		members_by_gen[generation].append(pawn_id)
	
	# Render each generation
	var generations: Array = members_by_gen.keys()
	generations.sort()
	
	for gen in generations:
		var gen_container: HBoxContainer = HBoxContainer.new()
		gen_container.add_theme_constant_override("separation", MEMBER_SPACING)
		
		var gen_label: Label = Label.new()
		gen_label.text = "Gen %d" % (gen + 1)
		gen_label.add_theme_font_size_override("font_size", 12)
		gen_label.add_theme_color_override("font_color", Color8(180, 180, 190))
		gen_label.custom_minimum_size = Vector2(60, 0)
		gen_container.add_child(gen_label)
		
		for pawn_id in members_by_gen[gen]:
			var member_card: Control = _create_member_card(pawn_id)
			if member_card != null:
				gen_container.add_child(member_card)
		
		_tree_container.add_child(gen_container)


func _get_pawn_spawner() -> Node:
	var _main: Node = get_tree().get_root().get_node_or_null("Main")
	if _main == null:
		return null
	return _main.get_node_or_null("WorldViewport/PawnSpawner")

func _create_member_card(pawn_id: int) -> Control:
	var ps: Node = _get_pawn_spawner()
	if ps == null or not ps.has_method("pawn_data_for_id"):
		return null
	
	var pawn_data: PawnData = ps.call("pawn_data_for_id", pawn_id)
	if pawn_data == null:
		return null
	
	# Create card container
	var card: PanelContainer = PanelContainer.new()
	card.custom_minimum_size = Vector2(MEMBER_WIDTH, MEMBER_HEIGHT)
	
	# Style
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.09, 0.11, 0.95)
	style.border_color = Color8(255, 209, 102)
	style.border_width_left = 2
	style.set_corner_radius_all(4)
	card.add_theme_stylebox_override("panel", style)
	
	# Content
	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation", 4)
	card.add_child(content)
	
	# Name
	var name_label: Label = Label.new()
	name_label.text = pawn_data.display_name
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	content.add_child(name_label)
	
	# Profession
	var prof_label: Label = Label.new()
	prof_label.text = pawn_data.profession_name()
	prof_label.add_theme_font_size_override("font_size", 10)
	prof_label.add_theme_color_override("font_color", Color8(180, 180, 190))
	content.add_child(prof_label)
	
	# Legacy score (if dead)
	var legacy_sys: Node = get_node_or_null("/root/LegacySystem")
	if legacy_sys != null and legacy_sys.has_method("get_legacy_entry"):
		var legacy: Dictionary = legacy_sys.call("get_legacy_entry", pawn_id)
		if not legacy.is_empty():
			var score: int = int(legacy.get("legacy_score", 0))
			var legacy_label: Label = Label.new()
			legacy_label.text = "⭐ Legacy: %d" % score
			legacy_label.add_theme_font_size_override("font_size", 10)
			legacy_label.add_theme_color_override("font_color", Color8(255, 209, 102))
			content.add_child(legacy_label)
	
	# Click handler
	card.gui_input.connect(_on_member_clicked.bind(pawn_id))
	
	return card


func _on_member_clicked(event: InputEvent, pawn_id: int) -> void:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			_show_member_biography(pawn_id)


func _show_member_biography(pawn_id: int) -> void:
	var ps: Node = _get_pawn_spawner()
	if ps == null:
		return
	
	var pawn_data: PawnData = ps.call("pawn_data_for_id", pawn_id)
	if pawn_data == null:
		return
	
	# Generate biography
	var wmem: Node = get_node_or_null("/root/WorldMemory")
	if wmem == null or not wmem.has_method("_generate_pawn_biography"):
		return
	
	var biography: String = wmem.call("_generate_pawn_biography", pawn_data, "viewed_from_tree")
	
	# Show dialog
	var dialog: AcceptDialog = AcceptDialog.new()
	dialog.title = "Biography: %s" % pawn_data.display_name
	dialog.dialog_text = biography
	dialog.exclusive = false
	dialog.resizable = true
	dialog.size = Vector2(600, 500)
	dialog.add_button("Close", true, "close")
	
	get_tree().root.add_child(dialog)
	dialog.popup_centered()


func _get_pawn_generation(pawn_id: int) -> int:
	# Simplified: would need kinship system integration
	# For now, estimate based on birth tick
	var ps: Node = _get_pawn_spawner()
	if ps == null or not ps.has_method("pawn_data_for_id"):
		return 0
	
	var pawn_data: PawnData = ps.call("pawn_data_for_id", pawn_id)
	if pawn_data == null:
		return 0
	
	# Each generation is ~3600 ticks (10 years)
	var current_tick: int = GameManager.tick_count if GameManager != null else 0
	var age_ticks: int = current_tick - pawn_data.birth_tick
	return age_ticks / 3600
