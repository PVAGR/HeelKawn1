extends Node
## OnboardingSystem - Tutorial and first-time player guidance
##
## Helps new players learn HeelKawn's complex systems through:
## - Contextual tooltips
## - Milestone celebrations
## - Progressive feature unlocks
## - Interactive tutorials

# Tutorial state (persisted across sessions)
var tutorial_state: Dictionary = {
	"first_launch": true,
	"completed_tutorials": [],
	"current_step": 0,
	"pawns_clicked": 0,
	"speed_changed": false,
	"f10_pressed": false,
	"incarnation_tried": false
}

# Tutorial definitions
var tutorials: Array[Dictionary] = [
	{
		"id": "welcome",
		"title": "Welcome to HeelKawn",
		"description": "A deterministic colony simulation where every pawn tells a story.",
		"steps": [
			{"text": "Click on any pawn to see their story.", "trigger": "pawn_click", "count": 1},
			{"text": "Press 1-7 to change simulation speed.", "trigger": "speed_change", "count": 1},
			{"text": "Press F10 to access debug features.", "trigger": "f10_press", "count": 1}
		],
		"reward": "First Steps complete! +50 Legacy Score"
	},
	{
		"id": "narrative",
		"title": "Pawn Narratives",
		"description": "Every pawn has a unique life story.",
		"steps": [
			{"text": "Click the 'Narrative' tab to see their story.", "trigger": "narrative_view", "count": 1}
		],
		"reward": "Storyteller achievement! +100 Legacy Score"
	},
	{
		"id": "incarnation",
		"title": "Incarnation Mode",
		"description": "Experience the world through a pawn's eyes.",
		"steps": [
			{"text": "Press P to incarnate into a pawn.", "trigger": "incarnation_enter", "count": 1},
			{"text": "Press P again to return to spectator mode.", "trigger": "incarnation_exit", "count": 1}
		],
		"reward": "Embodiment achievement! +200 Legacy Score"
	}
]

# Current active tutorial
var current_tutorial_index: int = 0
var current_step_index: int = 0

# UI references
var _tutorial_panel: PanelContainer = null
var _tooltip_label: RichTextLabel = null

# References
@onready var _main: Node = null
@onready var _legacy_system: Node = null


# Key state tracking for "just pressed" detection
var _p_key_was_pressed: bool = false
var _f10_key_was_pressed: bool = false

func _ready() -> void:
	GameManager.game_tick.connect(_on_game_tick)
	
	await get_tree().process_frame
	_main = get_node_or_null("/root/Main")
	_legacy_system = get_node_or_null("/root/LegacySystem")
	
	# Check if first launch
	if tutorial_state.first_launch:
		_show_welcome_message()


func _on_game_tick(tick: int) -> void:
	# Check tutorial triggers
	_check_tutorial_triggers(tick)
	
	# Track key state for "just pressed" detection
	var p_pressed: bool = Input.is_key_pressed(KEY_P)
	var f10_pressed: bool = Input.is_key_pressed(KEY_F10)
	
	if p_pressed and not _p_key_was_pressed:
		tutorial_state.incarnation_tried = true
		_trigger_tutorial_step("incarnation_enter")
	_p_key_was_pressed = p_pressed
	
	if f10_pressed and not _f10_key_was_pressed:
		tutorial_state.f10_pressed = true
		_trigger_tutorial_step("f10_press")
	_f10_key_was_pressed = f10_pressed


func _check_tutorial_triggers(tick: int) -> void:
	# Track pawn clicks
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		# Get mouse position in world coordinates
		var mouse_pos: Vector2
		if _main != null and _main._camera != null:
			var viewport_pos: Vector2 = _main.get_local_mouse_position()
			mouse_pos = _main._camera.get_global_transform().affine_inverse() * viewport_pos
		else:
			mouse_pos = Vector2.ZERO
		
		# Check if clicked on pawn
		if _main != null:
			var clicked_pawn: Pawn = _get_pawn_at_position(mouse_pos)
			if clicked_pawn != null:
				tutorial_state.pawns_clicked += 1
				_trigger_tutorial_step("pawn_click")
	
	# Track speed changes
	if Input.is_action_just_pressed("ui_speed_1") or \
	   Input.is_action_just_pressed("ui_speed_2") or \
	   Input.is_action_just_pressed("ui_speed_3"):
		tutorial_state.speed_changed = true
		_trigger_tutorial_step("speed_change")
	
	# Track incarnation (already tracked in _on_game_tick)
	
	# Close tutorial on ESC
	if Input.is_action_just_pressed("ui_cancel"):
		_on_ui_cancel()


func _get_pawn_at_position(pos: Vector2) -> Pawn:
	if _main == null or _main._pawn_spawner == null:
		return null
	
	for pawn in _main._pawn_spawner.pawns:
		if pawn != null and is_instance_valid(pawn):
			var pawn_rect: Rect2 = Rect2(pawn.position - Vector2(8, 8), Vector2(16, 16))
			if pawn_rect.has_point(pos):
				return pawn
	
	return null


func _trigger_tutorial_step(trigger: String) -> void:
	if current_tutorial_index >= tutorials.size():
		return
	
	var tutorial: Dictionary = tutorials[current_tutorial_index]
	if current_step_index >= tutorial.steps.size():
		return
	
	var step: Dictionary = tutorial.steps[current_step_index]
	if step.trigger == trigger:
		current_step_index += 1
		
		if current_step_index >= tutorial.steps.size():
			_complete_tutorial(tutorial)
		else:
			_show_tutorial_step(tutorial.steps[current_step_index])


func _complete_tutorial(tutorial: Dictionary) -> void:
	_show_tutorial_complete(tutorial)
	
	# Add to completed list
	if not tutorial_state.completed_tutorials.has(tutorial.id):
		tutorial_state.completed_tutorials.append(tutorial.id)
	
	# Grant reward
	_grant_tutorial_reward(tutorial.reward)
	
	# Move to next tutorial
	current_tutorial_index += 1
	current_step_index = 0
	
	if current_tutorial_index < tutorials.size():
		_show_tutorial_intro(tutorials[current_tutorial_index])


func _grant_tutorial_reward(reward_text: String) -> void:
	# Parse legacy score from reward
	var score: int = 0
	if "Legacy Score" in reward_text:
		var parts: PackedStringArray = reward_text.split(" ")
		for part in parts:
			if part.is_valid_int():
				score = int(part)
				break
	
	# Add to legacy system
	if _legacy_system != null and score > 0:
		_legacy_system._legacy_score += score


func _show_welcome_message() -> void:
	_create_tutorial_panel()
	
	var welcome_text: String = """[color=#FFD166][b]Welcome to HeelKawn![/b][/color]

A deterministic colony simulation where every pawn tells a story.

[color=#888888]This tutorial will teach you the basics.[/color]

Click [color=#57C5B6]Next[/color] to begin."""
	
	_set_tutorial_text(welcome_text)
	_add_next_button()


func _show_tutorial_intro(tutorial: Dictionary) -> void:
	var intro_text: String = """[color=#FFD166][b]%s[/b][/color]

%s

[color=#888888]Complete the steps to earn rewards.[/color]""" % [tutorial.title, tutorial.description]
	
	_set_tutorial_text(intro_text)
	_add_start_button(tutorial)


func _show_tutorial_step(step: Dictionary) -> void:
	var step_text: String = """[color=#57C5B6]%s[/color]

[color=#888888]Do this to continue...[/color]""" % step.text
	
	_set_tutorial_text(step_text)


func _show_tutorial_complete(tutorial: Dictionary) -> void:
	var complete_text: String = """[color=#FFD166][b]Tutorial Complete![/b][/color]

%s

[color=#FFD166]%s[/color]""" % [tutorial.title, tutorial.reward]
	
	_set_tutorial_text(complete_text)
	_add_continue_button()


func _create_tutorial_panel() -> void:
	if _tutorial_panel != null and is_instance_valid(_tutorial_panel):
		return
	
	_tutorial_panel = PanelContainer.new()
	_tutorial_panel.name = "TutorialPanel"
	_tutorial_panel.anchor_left = 0.5
	_tutorial_panel.anchor_right = 0.5
	_tutorial_panel.anchor_top = 0.5
	_tutorial_panel.anchor_bottom = 0.5
	_tutorial_panel.offset_left = -200
	_tutorial_panel.offset_right = 200
	_tutorial_panel.offset_top = -150
	_tutorial_panel.offset_bottom = 150
	
	# Style
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.06, 0.08, 0.95)
	style.border_color = Color(0.85, 0.78, 0.40, 0.65)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.set_corner_radius_all(8)
	_tutorial_panel.add_theme_stylebox_override("panel", style)
	
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	_tutorial_panel.add_child(vbox)
	
	# Text label (use RichTextLabel for BBCode support in Godot 4)
	_tooltip_label = RichTextLabel.new()
	_tooltip_label.bbcode_enabled = true
	_tooltip_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_tooltip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tooltip_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(_tooltip_label)
	
	# Button container
	var button_container: HBoxContainer = HBoxContainer.new()
	button_container.add_theme_constant_override("separation", 10)
	vbox.add_child(button_container)
	
	# Add to scene
	if _main != null:
		_main.add_child(_tutorial_panel)
		_tutorial_panel.set_as_toplevel(true)


func _set_tutorial_text(text: String) -> void:
	if _tooltip_label != null:
		_tooltip_label.text = text


func _add_next_button() -> void:
	var button: Button = Button.new()
	button.text = "Next"
	button.custom_minimum_size = Vector2(100, 30)
	button.pressed.connect(_on_next_clicked)
	
	var vbox: VBoxContainer = _tutorial_panel.get_child(0) as VBoxContainer
	var button_container: HBoxContainer = vbox.get_child(1) as HBoxContainer
	button_container.add_child(button)


func _add_start_button(tutorial: Dictionary) -> void:
	var button: Button = Button.new()
	button.text = "Start"
	button.custom_minimum_size = Vector2(100, 30)
	button.pressed.connect(_on_start_clicked.bind(tutorial))
	
	var vbox: VBoxContainer = _tutorial_panel.get_child(0) as VBoxContainer
	var button_container: HBoxContainer = vbox.get_child(1) as HBoxContainer
	button_container.add_child(button)


func _add_continue_button() -> void:
	var button: Button = Button.new()
	button.text = "Continue"
	button.custom_minimum_size = Vector2(100, 30)
	button.pressed.connect(_on_continue_clicked)
	
	var vbox: VBoxContainer = _tutorial_panel.get_child(0) as VBoxContainer
	var button_container: HBoxContainer = vbox.get_child(1) as HBoxContainer
	button_container.add_child(button)


func _on_next_clicked() -> void:
	if current_tutorial_index < tutorials.size():
		_show_tutorial_intro(tutorials[current_tutorial_index])
	
	# Remove next button
	var vbox: VBoxContainer = _tutorial_panel.get_child(0) as VBoxContainer
	var button_container: HBoxContainer = vbox.get_child(1) as HBoxContainer
	for child in button_container.get_children():
		child.queue_free()


func _on_start_clicked(tutorial: Dictionary) -> void:
	# Remove start button
	var vbox: VBoxContainer = _tutorial_panel.get_child(0) as VBoxContainer
	var button_container: HBoxContainer = vbox.get_child(1) as HBoxContainer
	for child in button_container.get_children():
		child.queue_free()
	
	# Show first step
	if tutorial.steps.size() > 0:
		_show_tutorial_step(tutorial.steps[0])


func _on_continue_clicked() -> void:
	# Close tutorial panel
	if _tutorial_panel != null and is_instance_valid(_tutorial_panel):
		_tutorial_panel.queue_free()
		_tutorial_panel = null


func _on_ui_cancel() -> void:
	# ESC key closes tutorial
	if _tutorial_panel != null and is_instance_valid(_tutorial_panel):
		_tutorial_panel.queue_free()
		_tutorial_panel = null


# ==================== Public API ====================

## Reset tutorial progress (for testing)
func reset_progress() -> void:
	tutorial_state = {
		"first_launch": true,
		"completed_tutorials": [],
		"current_step": 0,
		"pawns_clicked": 0,
		"speed_changed": false,
		"f10_pressed": false,
		"incarnation_tried": false
	}
	current_tutorial_index = 0
	current_step_index = 0
	
	if _tutorial_panel != null and is_instance_valid(_tutorial_panel):
		_tutorial_panel.queue_free()
		_tutorial_panel = null
	
	_show_welcome_message()


## Get tutorial progress for save/load
func get_save_data() -> Dictionary:
	return tutorial_state.duplicate()


## Load tutorial progress from save
func load_save_data(data: Dictionary) -> void:
	tutorial_state = data.duplicate()
	current_tutorial_index = tutorial_state.get("current_step", 0)
