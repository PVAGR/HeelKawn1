class_name SeedGallery
extends CanvasLayer

signal seed_selected(seed: int)
signal closed

const CARD_COUNT: int = 6

@onready var _panel: PanelContainer = $Panel
@onready var _close_button: Button = $Panel/Margin/VBox/Header/CloseButton
@onready var _subtitle: Label = $Panel/Margin/VBox/SubTitle
@onready var _grid: GridContainer = $Panel/Margin/VBox/Scroll/Grid

var _visible: bool = false
var _base_seed: int = 0


func _ready() -> void:
	layer = 80
	_panel.visible = false
	_close_button.pressed.connect(_on_close_pressed)
	if has_node("/root/GameManager"):
		GameManager.game_tick.connect(_on_tick)
	_apply_panel_style()


func show_gallery(base_seed: int = 0) -> void:
	_base_seed = base_seed
	_visible = true
	_panel.visible = true
	_subtitle.text = "Choose a deterministic world seed to begin a new colony."
	_populate_cards()
	queue_redraw()


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
	# Keep the panel responsive and deterministic while the title screen idles.
	if _subtitle != null:
		_subtitle.text = "Choose a deterministic world seed to begin a new colony."


func _apply_panel_style() -> void:
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
	var seeds: Array[int] = _generate_candidate_seeds(_base_seed)
	for seed in seeds:
		_grid.add_child(_build_seed_card(seed))


func _generate_candidate_seeds(base_seed: int) -> Array[int]:
	var seeds: Array[int] = []
	for i in range(CARD_COUNT):
		var candidate_seed: int = int(hash("%d::%d::heelkawn" % [base_seed, i])) & 0x7FFFFFFF
		if candidate_seed <= 0:
			candidate_seed = (base_seed + i + 1) & 0x7FFFFFFF
		seeds.append(candidate_seed)
	return seeds


func _build_seed_card(seed: int) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(220, 120)
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
	vbox.add_theme_constant_override("separation", 4)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "Seed %d" % seed
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(0.94, 0.85, 0.63, 1.0))
	vbox.add_child(title)

	var descriptor := Label.new()
	descriptor.text = _seed_descriptor(seed)
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


func _seed_descriptor(seed: int) -> String:
	var descriptors: Array[String] = [
		"Ashen valley with hard winters and quiet rivers.",
		"Mossy basin where the hills shelter the first fields.",
		"Wind-battered coastlands and bright dawns.",
		"A pale stone plain where roads matter more than walls.",
		"A dense woodland seed with rich game and soft ground.",
		"An old river-crossing favored by traders and pilgrims.",
	]
	var climate_tags: Array[String] = ["mild", "harsh", "wet", "dry", "windy", "frigid"]
	var tag_index: int = int(hash("%d::tag" % seed)) % climate_tags.size()
	var desc_index: int = int(hash("%d::desc" % seed)) % descriptors.size()
	return "%s\nClimate: %s" % [descriptors[desc_index], climate_tags[tag_index]]
