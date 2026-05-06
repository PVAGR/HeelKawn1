extends Control
## UIManager - Central UI controller for HeelKawn
##
## Manages all UI panels:
## - Survival HUD (always visible)
## - Inventory (I key)
## - Action Menu (right-click)
## - Chronicles (C key)
## - Character Status (K key)
## - Help Menu (H key / F1)

@export var survival_hud_scene: PackedScene
@export var inventory_scene: PackedScene
@export var action_menu_scene: PackedScene
@export var chronicle_scene: PackedScene
@export var character_scene: PackedScene
@export var help_scene: PackedScene

var survival_hud: Node = null
var inventory_ui: Node = null
var action_menu: Node = null
var chronicle_reader: Node = null
var character_status: Node = null
var help_menu: Node = null

var _player_gathering: Node = null
var _player_building: Node = null
var _pawn_consciousness: Node = null
var _world_action_ledger: Node = null


func _ready() -> void:
	# Get systems
	_player_gathering = get_node_or_null("/root/PlayerGathering")
	_player_building = get_node_or_null("/root/PlayerBuilding")
	_pawn_consciousness = get_node_or_null("/root/PawnConsciousness")
	_world_action_ledger = get_node_or_null("/root/WorldActionLedger")
	
	# Create UI panels
	_create_ui_panels()
	
	# Show help on first run
	_show_help()


func _create_ui_panels() -> void:
	# Survival HUD (always visible)
	if survival_hud_scene != null:
		survival_hud = survival_hud_scene.instantiate()
		add_child(survival_hud)
	else:
		# Create from script if no scene
		survival_hud = _create_survival_hud()
		add_child(survival_hud)
	
	# Inventory UI
	if inventory_scene != null:
		inventory_ui = inventory_scene.instantiate()
		add_child(inventory_ui)
	else:
		inventory_ui = _create_inventory_ui()
		add_child(inventory_ui)
	
	# Action Menu
	if action_menu_scene != null:
		action_menu = action_menu_scene.instantiate()
		add_child(action_menu)
	else:
		action_menu = _create_action_menu()
		add_child(action_menu)
	
	# Chronicle Reader
	if chronicle_scene != null:
		chronicle_reader = chronicle_scene.instantiate()
		add_child(chronicle_reader)
	else:
		chronicle_reader = _create_chronicle_reader()
		add_child(chronicle_reader)
	
	# Character Status
	if character_scene != null:
		character_status = character_scene.instantiate()
		add_child(character_status)
	else:
		character_status = _create_character_status()
		add_child(character_status)
	
	# Help Menu
	if help_scene != null:
		help_menu = help_scene.instantiate()
		add_child(help_menu)
	else:
		help_menu = _create_help_menu()
		add_child(help_menu)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_I:
				_toggle_inventory()
			KEY_C:
				_toggle_chronicles()
			KEY_K:
				_toggle_character()
			KEY_H, KEY_F1:
				_toggle_help()
			KEY_TAB:
				_toggle_all_ui()


func _toggle_inventory() -> void:
	if inventory_ui != null:
		inventory_ui.visible = not inventory_ui.visible


func _toggle_chronicles() -> void:
	if chronicle_reader != null:
		chronicle_reader.visible = not chronicle_reader.visible
		if chronicle_reader.visible and chronicle_reader.has_method("_load_chronicles"):
			chronicle_reader._load_chronicles()


func _toggle_character() -> void:
	if character_status != null:
		character_status.visible = not character_status.visible
		if character_status.visible and character_status.has_method("_refresh_display"):
			character_status._refresh_display()


func _toggle_help() -> void:
	if help_menu != null:
		help_menu.visible = not help_menu.visible


func _toggle_all_ui() -> void:
	var any_visible: bool = false
	if inventory_ui != null and inventory_ui.visible:
		any_visible = true
	if chronicle_reader != null and chronicle_reader.visible:
		any_visible = true
	if character_status != null and character_status.visible:
		any_visible = true
	
	if any_visible:
		if inventory_ui != null: inventory_ui.visible = false
		if chronicle_reader != null: chronicle_reader.visible = false
		if character_status != null: character_status.visible = false
	else:
		if inventory_ui != null: inventory_ui.visible = true
		if chronicle_reader != null: chronicle_reader.visible = true
		if character_status != null: character_status.visible = true


func _show_help() -> void:
	if help_menu != null:
		help_menu.visible = true


# ==================== CREATE UI FROM SCRIPT (Fallback) ====================

func _create_survival_hud() -> Node:
	# Create survival HUD panel
	var panel: PanelContainer = PanelContainer.new()
	panel.name = "SurvivalHUD"
	panel.anchor_left = 0.0
	panel.anchor_top = 0.0
	panel.offset_right = 250.0
	panel.offset_bottom = 200.0
	
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	panel.add_child(vbox)
	
	# Create bars
	var bars: Dictionary = {
		"❤️ Health": "health_bar",
		"🍖 Hunger": "hunger_bar",
		"💧 Thirst": "thirst_bar",
		"⚡ Energy": "energy_bar"
	}
	
	for label_text in bars:
		var hbox: HBoxContainer = HBoxContainer.new()
		var label: Label = Label.new()
		label.text = label_text
		label.custom_minimum_size.x = 80
		hbox.add_child(label)
		
		var bar: ProgressBar = ProgressBar.new()
		bar.name = bars[label_text]
		bar.value = 100
		bar.max_value = 100
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(bar)
		
		vbox.add_child(hbox)
	
	# Temperature
	var temp_hbox: HBoxContainer = HBoxContainer.new()
	var temp_label: Label = Label.new()
	temp_label.text = "🌡️ Temp: 37.0°C"
	temp_label.name = "TempLabel"
	temp_hbox.add_child(temp_label)
	vbox.add_child(temp_hbox)
	
	return panel


func _create_inventory_ui() -> Node:
	var panel: PanelContainer = PanelContainer.new()
	panel.name = "PlayerInventoryUI"
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.offset_left = -200.0
	panel.offset_top = -150.0
	panel.offset_right = 200.0
	panel.offset_bottom = 150.0
	panel.visible = false
	
	var vbox: VBoxContainer = VBoxContainer.new()
	panel.add_child(vbox)
	
	var title: Label = Label.new()
	title.text = "🎒 Inventory (Press I to close)"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 14)
	vbox.add_child(title)
	
	var grid: GridContainer = GridContainer.new()
	grid.name = "ItemsGrid"
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	vbox.add_child(grid)
	
	return panel


func _create_action_menu() -> Node:
	var panel: PanelContainer = PanelContainer.new()
	panel.name = "ActionMenu"
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.offset_left = -100.0
	panel.offset_top = -75.0
	panel.offset_right = 100.0
	panel.offset_bottom = 75.0
	panel.visible = false
	
	var vbox: VBoxContainer = VBoxContainer.new()
	panel.add_child(vbox)
	
	var title: Label = Label.new()
	title.text = "Actions (Right-click to close)"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	
	var action_list: VBoxContainer = VBoxContainer.new()
	action_list.name = "ActionList"
	vbox.add_child(action_list)
	
	return panel


func _create_chronicle_reader() -> Node:
	var panel: PanelContainer = PanelContainer.new()
	panel.name = "ChronicleReader"
	panel.anchor_left = 0.1
	panel.anchor_top = 0.1
	panel.anchor_right = 0.9
	panel.anchor_bottom = 0.9
	panel.offset_left = 50.0
	panel.offset_top = 50.0
	panel.offset_right = -50.0
	panel.offset_bottom = -50.0
	panel.visible = false
	
	var vbox: VBoxContainer = VBoxContainer.new()
	panel.add_child(vbox)
	
	var title: Label = Label.new()
	title.text = "📜 Chronicles & History (Press C to close)"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 16)
	vbox.add_child(title)
	
	var content: TextEdit = TextEdit.new()
	content.name = "ChronicleContent"
	content.editable = false
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.text = """
[center][font_size=18]Welcome to HeelKawn[/font_size][/center]

[center]Your actions matter. Your legacy persists.[/center]

[center]=== CONTROLS ===[/center]

[b]Movement:[/b]
- WASD / Arrow Keys: Move camera
- Mouse wheel: Zoom

[b]Actions:[/b]
- Right-click on tile: Open action menu
- Gather: Click tree (wood), rock (stone), bush (berries)
- Build: Right-click empty ground → Build menu

[b]UI Hotkeys:[/b]
- [color=green]I[/color]: Toggle Inventory
- [color=green]C[/color]: Toggle Chronicles
- [color=green]K[/color]: Toggle Character Status
- [color=green]H[/color] or [color=green]F1[/color]: Toggle Help
- [color=green]TAB[/color]: Toggle all UI

[b]Survival:[/b]
- Hunger decays over time (eat berries)
- Thirst decays faster than hunger
- Temperature matters (avoid extreme cold/heat)
- Injuries heal naturally

[b]Building:[/b]
- Gather wood and stone first
- Build foundation → walls → shelter
- Fire pit provides warmth

[b]HeelKawnians:[/b]
- Every pawn remembers experiences
- Every pawn dreams during sleep
- Every pawn can grow self-aware
- Your actions are recorded forever

[center]=== YOUR LEGACY BEGINS NOW ===[/center]
"""
	vbox.add_child(content)
	
	var close_btn: Button = Button.new()
	close_btn.text = "Close (Press C)"
	close_btn.pressed.connect(func(): panel.visible = false)
	vbox.add_child(close_btn)
	
	return panel


func _create_character_status() -> Node:
	var panel: PanelContainer = PanelContainer.new()
	panel.name = "CharacterStatus"
	panel.anchor_left = 0.7
	panel.anchor_top = 0.1
	panel.offset_left = 50.0
	panel.offset_top = 50.0
	panel.offset_right = 350.0
	panel.offset_bottom = 300.0
	panel.visible = false
	
	var vbox: VBoxContainer = VBoxContainer.new()
	panel.add_child(vbox)
	
	var title: Label = Label.new()
	title.text = "👤 Character (Press K to close)"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 14)
	vbox.add_child(title)
	
	var awareness: Label = Label.new()
	awareness.text = "Awareness: Unconscious (Level 0)"
	awareness.name = "AwarenessLabel"
	vbox.add_child(awareness)
	
	var trauma: Label = Label.new()
	trauma.text = "Trauma: 0.0/100"
	trauma.name = "TraumaLabel"
	vbox.add_child(trauma)
	
	var growth: Label = Label.new()
	growth.text = "Growth Points: 0"
	growth.name = "GrowthLabel"
	vbox.add_child(growth)
	
	return panel


func _create_help_menu() -> Node:
	# Help is shown via ChronicleReader on first run
	var panel: PanelContainer = PanelContainer.new()
	panel.name = "HelpMenu"
	panel.visible = false
	return panel
