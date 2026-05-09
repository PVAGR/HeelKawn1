extends PanelContainer
## PawnMoodUI - Individual pawn mood panel (RimWorld-style)
##
## Features:
## - Mood display (0-100)
## - Need indicators (hunger, rest, social, etc.)
## - Thought bubbles (current thoughts)
## - Trait display
## - Health status

var _pawn_id: int = -1
var _pawn_data: Node = null

# UI references
var _mood_bar: ProgressBar = null
var _mood_label: Label = null
var _needs_container: VBoxContainer = null
var _thoughts_container: VBoxContainer = null
var _traits_container: FlowContainer = null
var _health_label: Label = null

# Need types
const NEED_TYPES: Array[String] = ["hunger", "rest", "social", "comfort", "safety"]

# References
@onready var _modern_theme: Node = get_node_or_null("/root/ModernTheme")


func _ready() -> void:
	_build_ui()
	_setup_theme()


func _build_ui() -> void:
	custom_minimum_size = Vector2(250, 300)
	
	# Main layout
	var main_vbox: VBoxContainer = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 10)
	add_child(main_vbox)
	
	# HeelKawnian name header
	var name_label: Label = _modern_theme.create_styled_label("HeelKawnian Name", "large")
	name_label.name = "NameLabel"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(name_label)
	
	# Mood section
	var mood_section: VBoxContainer = VBoxContainer.new()
	mood_section.add_theme_constant_override("separation", 4)
	main_vbox.add_child(mood_section)
	
	var mood_title: Label = _modern_theme.create_styled_label("Mood", "small")
	mood_section.add_child(mood_title)
	
	_mood_bar = ProgressBar.new()
	_mood_bar.name = "MoodBar"
	_mood_bar.max_value = 100
	_mood_bar.min_value = 0
	_mood_bar.value = 50
	_mood_bar.custom_minimum_size = Vector2(0, 20)
	mood_section.add_child(_mood_bar)
	
	_mood_label = _modern_theme.create_styled_label("50/100", "small")
	_mood_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mood_section.add_child(_mood_label)
	
	# Needs section
	var needs_title: Label = _modern_theme.create_styled_label("Needs", "small")
	main_vbox.add_child(needs_title)
	
	_needs_container = VBoxContainer.new()
	_needs_container.add_theme_constant_override("separation", 4)
	main_vbox.add_child(_needs_container)
	
	# Create need bars
	for need_type in NEED_TYPES:
		var need_row: HBoxContainer = HBoxContainer.new()
		
		var need_label: Label = _modern_theme.create_styled_label(need_type.capitalize(), "small")
		need_label.custom_minimum_size = Vector2(80, 0)
		need_row.add_child(need_label)
		
		var need_bar: ProgressBar = ProgressBar.new()
		need_bar.name = "Need_" + need_type
		need_bar.max_value = 100
		need_bar.min_value = 0
		need_bar.value = 50
		need_bar.custom_minimum_size = Vector2(0, 16)
		need_row.add_child(need_bar)
		
		_needs_container.add_child(need_row)
	
	# Thoughts section
	var thoughts_title: Label = _modern_theme.create_styled_label("Thoughts", "small")
	main_vbox.add_child(thoughts_title)
	
	_thoughts_container = VBoxContainer.new()
	_thoughts_container.add_theme_constant_override("separation", 4)
	main_vbox.add_child(_thoughts_container)
	
	# Traits section
	var traits_title: Label = _modern_theme.create_styled_label("Traits", "small")
	main_vbox.add_child(traits_title)
	
	_traits_container = FlowContainer.new()
	_traits_container.add_theme_constant_override("h_separation", 4)
	_traits_container.add_theme_constant_override("v_separation", 4)
	main_vbox.add_child(_traits_container)
	
	# Health section
	var health_title: Label = _modern_theme.create_styled_label("Health", "small")
	main_vbox.add_child(health_title)
	
	_health_label = _modern_theme.create_styled_label("Healthy", "small")
	main_vbox.add_child(_health_label)


func _setup_theme() -> void:
	if _modern_theme != null:
		# Apply background
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = _modern_theme.get_color("bg_medium")
		style.set_corner_radius_all(8)
		add_theme_stylebox_override("panel", style)


func set_pawn(pawn_id: int) -> void:
	_pawn_id = pawn_id
	_update_display()


func _update_display() -> void:
	if _pawn_id < 0:
		return
	
	# Get pawn data
	var main = get_node_or_null("/root/Main")
	var pawn_spawner: Node = null
	if main != null and main.has_method("get_pawn_spawner"):
		pawn_spawner = main.call("get_pawn_spawner")
	else:
		pawn_spawner = get_node_or_null("/root/Main/WorldViewport/PawnSpawner")
	
	if pawn_spawner == null or not pawn_spawner.has_method("pawn_data_for_id"):
		return
	
	_pawn_data = pawn_spawner.call("pawn_data_for_id", _pawn_id)
	if _pawn_data == null:
		return
	
	# Update name
	var name_label: Label = get_node_or_null("VBoxContainer/NameLabel")
	if name_label != null:
		var dn = _pawn_data.get("display_name")
		name_label.text = dn if dn != null else "Unknown"
	
	# Update mood
	_update_mood()
	
	# Update needs
	_update_needs()
	
	# Update thoughts
	_update_thoughts()
	
	# Update traits
	_update_traits()
	
	# Update health
	_update_health()


func _update_mood() -> void:
	if _mood_bar == null or _mood_label == null:
		return
	
	var mood_val = _pawn_data.get("mood")
	var mood: float = mood_val if mood_val != null else 50.0
	_mood_bar.value = mood
	_mood_label.text = "%d/100" % int(mood)
	
	# Color based on mood
	if _modern_theme != null:
		var color: Color = _modern_theme.get_mood_color(mood)
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = color
		_mood_bar.add_theme_stylebox_override("fill", style)


func _update_needs() -> void:
	if _needs_container == null:
		return
	
	# Update each need bar
	for need_type in NEED_TYPES:
		var need_bar: ProgressBar = _needs_container.get_node_or_null("Need_" + need_type)
		if need_bar != null:
			# Get need value from pawn data
			var nv = _pawn_data.get(need_type)
			var need_value: float = nv if nv != null else 50.0
			need_bar.value = need_value


func _update_thoughts() -> void:
	if _thoughts_container == null:
		return
	
	# Clear existing thoughts
	for child in _thoughts_container.get_children():
		child.queue_free()
	
	# Get thoughts from pawn data
	var thoughts_raw = _pawn_data.get("thoughts")
	var thoughts: Array = thoughts_raw if thoughts_raw != null else []
	
	for thought in thoughts:
		var thought_label: Label = _modern_theme.create_styled_label("• " + str(thought), "small")
		_thoughts_container.add_child(thought_label)


func _update_traits() -> void:
	if _traits_container == null:
		return
	
	# Clear existing traits
	var trait_children: Array = _traits_container.get_children()
	var i: int = 0
	while i < trait_children.size():
		var child: Node = trait_children[i]
		child.queue_free()
		i += 1

	# Get traits from pawn data
	var traits: Array = []
	if _pawn_data.has_meta("traits"):
		traits = _pawn_data.get_meta("traits")

	var j: int = 0
	while j < traits.size():
		var t: String = str(traits[j])
		var trait_chip: Label = Label.new()
		trait_chip.text = str(t)
		trait_chip.add_theme_color_override("font_color", _modern_theme.get_color("text_primary"))
		trait_chip.add_theme_font_size_override("font_size", _modern_theme.get_font_size("small"))

		# Style chip background
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = _modern_theme.get_color("bg_light")
		style.set_corner_radius_all(4)
		trait_chip.add_theme_stylebox_override("normal", style)

		_traits_container.add_child(trait_chip)
		j += 1


func _update_health() -> void:
	if _health_label == null:
		return
	
	var h = _pawn_data.get("health")
	var health: float = h if h != null else 100.0
	var w = _pawn_data.get("wounds")
	var wounds: Array = w if w != null else []
	
	if wounds.size() > 0:
		_health_label.text = "Wounded (%d wounds)" % wounds.size()
		_health_label.add_theme_color_override("font_color", _modern_theme.get_color("accent_danger"))
	elif health < 50:
		_health_label.text = "Injured"
		_health_label.add_theme_color_override("font_color", _modern_theme.get_color("accent_warning"))
	else:
		_health_label.text = "Healthy"
		_health_label.add_theme_color_override("font_color", _modern_theme.get_color("accent_success"))


var _last_mood_update_tick: int = -1

func _process(_delta: float) -> void:
	# Update display periodically (every 10 ticks, but only once per tick)
	if GameManager != null:
		var cur_tick: int = GameManager.tick_count
		if cur_tick % 10 == 0 and cur_tick != _last_mood_update_tick:
			_last_mood_update_tick = cur_tick
			_update_display()


# ==================== PUBLIC API ====================

## Get current pawn ID
func get_pawn_id() -> int:
	return _pawn_id

## Clear display
func clear() -> void:
	_pawn_id = -1
	_pawn_data = null
	
	var name_label: Label = get_node_or_null("VBoxContainer/NameLabel")
	if name_label != null:
		name_label.text = "No HeelKawnian Selected"
	
	if _mood_bar != null:
		_mood_bar.value = 0
	if _mood_label != null:
		_mood_label.text = "0/100"
