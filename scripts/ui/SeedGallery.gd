class_name SeedGallery
extends CanvasLayer

signal seed_selected(seed: int)
signal closed

const CARD_COUNT: int = 8

## Curated seeds: [seed, biome_name, description, climate_tag]
const CURATED_SEEDS: Array = [
	[42,        "Island Chain",      "Emerald isles ringed by shallow tides. Fish abound and invasion must come by sea.", "wet"],
	[1701,      "Mountain Valley",   "A sheltered valley between two granite spines. Rich stone, limited farmland.", "mild"],
	[3003,      "River Delta",       "Fertile floodplains where three rivers meet. Ideal for farming and trade.", "wet"],
	[7777,      "Archipelago",       "Countless tiny islands scattered across warm shallows. Boats are essential.", "mild"],
	[1313,      "Desert Oasis",      "A verdant spring hidden in endless dunes. Water is life; caravans are rare.", "dry"],
	[2202,      "Tundra Fjord",      "Deep icy inlets carved by ancient glaciers. Seals and hardy moss sustain life.", "frigid"],
	[5555,      "Volcanic Highlands","Black basalt ridges overlooking a restless caldera. Obsidian and hot springs.", "harsh"],
	[9001,      "Great Lake",        "A freshwater sea stretching to every horizon. Endless fish and timber.", "mild"],
]

@onready var _panel: PanelContainer = $Panel
@onready var _close_button: Button = $Panel/Margin/VBox/Header/CloseButton
@onready var _subtitle: Label = $Panel/Margin/VBox/SubTitle
@onready var _grid: GridContainer = $Panel/Margin/VBox/Scroll/Grid

var _visible: bool = false
var _base_seed: int = 0


func _ready() -> void:
	layer = 80
	if _panel != null:
		_panel.visible = false
	if _close_button != null:
		_close_button.pressed.connect(_on_close_pressed)
	if has_node("/root/GameManager"):
		GameManager.game_tick.connect(_on_tick)
	_apply_panel_style()


func show_gallery(base_seed: int = 0) -> void:
	_base_seed = base_seed
	_visible = true
	_panel.visible = true
	_subtitle.text = "Choose a curated world to begin a new colony."
	_populate_cards()
	_panel.queue_redraw()


func hide_gallery() -> void:
	_visible = false
	_panel.visible = false


func _on_close_pressed() -> void:
	hide_gallery()
	closed.emit()


func _unhandled_key_input(event: InputEvent) -> void:
	if not _visible:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		hide_gallery()
		closed.emit()
		get_viewport().set_input_as_handled()


func _on_tick(_tick: int) -> void:
	if not _visible:
		return
	if _subtitle != null:
		_subtitle.text = "Choose a curated world to begin a new colony."


func _apply_panel_style() -> void:
	if _panel == null:
		return
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.05, 0.07, 0.94)
	style.border_color = Color(0.85, 0.78, 0.40, 0.85)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	_panel.add_theme_stylebox_override("panel", style)


func _populate_cards() -> void:
	if _grid == null:
		return
	for child in _grid.get_children():
		child.queue_free()
	for entry in CURATED_SEEDS:
		_grid.add_child(_build_seed_card(entry[0], entry[1], entry[2], entry[3]))


func _build_seed_card(seed: int, biome_name: String, desc: String, climate: String) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(220, 140)
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.09, 0.10, 0.13, 0.96)
	card_style.border_color = Color(0.42, 0.36, 0.25, 0.85)
	card_style.set_border_width_all(1)
	card_style.set_corner_radius_all(6)
	card.add_theme_stylebox_override("panel", card_style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	card.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	margin.add_child(vbox)

	var biome_label := Label.new()
	biome_label.text = biome_name
	biome_label.add_theme_font_size_override("font_size", 13)
	biome_label.add_theme_color_override("font_color", Color(0.94, 0.85, 0.63, 1.0))
	vbox.add_child(biome_label)

	var seed_line := Label.new()
	seed_line.text = "Seed %d  ·  %s" % [seed, climate]
	seed_line.add_theme_font_size_override("font_size", 9)
	seed_line.add_theme_color_override("font_color", Color(0.65, 0.62, 0.58, 1.0))
	vbox.add_child(seed_line)

	var descriptor := Label.new()
	descriptor.text = desc
	descriptor.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	descriptor.add_theme_font_size_override("font_size", 10)
	descriptor.add_theme_color_override("font_color", Color(0.82, 0.80, 0.76, 1.0))
	vbox.add_child(descriptor)

	var button := Button.new()
	button.text = "Start with this seed"
	button.pressed.connect(_on_seed_button_pressed.bind(seed))
	vbox.add_child(button)

	return card


func _on_seed_button_pressed(seed: int) -> void:
	seed_selected.emit(seed)
	hide_gallery()
