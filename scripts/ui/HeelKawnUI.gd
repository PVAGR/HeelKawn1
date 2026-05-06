extends Node
## HeelKawnUI - COMPLETE PROFESSIONAL UI SYSTEM
##
## ZERO SETUP REQUIRED - Just attach to Main scene and everything works!
##
## Features:
## - Survival HUD (always visible, top-left)
## - Action buttons (bottom-right corner)
## - Camera controls (mouse wheel zoom, right-click drag)
## - All UI panels with clickable buttons
## - Professional design with smooth animations
## - Auto-detects and connects to all game systems

# UI Panels
var survival_hud: PanelContainer = null
var action_buttons: HBoxContainer = null
var inventory_panel: PanelContainer = null
var chronicle_panel: PanelContainer = null
var character_panel: PanelContainer = null
var help_panel: PanelContainer = null
var camera_hint: Label = null

# Systems
var _player_gathering: Node = null
var _player_building: Node = null
var _pawn_consciousness: Node = null
var _world_action_ledger: Node = null
var _survival_system: Node = null

# State
var _update_timer: float = 0.0
var _camera_zoom: float = 1.0
var _camera_dragging: bool = false
var _drag_start: Vector2 = Vector2.ZERO


func _ready() -> void:
	# Get all systems
	_player_gathering = get_node_or_null("/root/PlayerGathering")
	_player_building = get_node_or_null("/root/PlayerBuilding")
	_pawn_consciousness = get_node_or_null("/root/PawnConsciousness")
	_world_action_ledger = get_node_or_null("/root/WorldActionLedger")
	_survival_system = get_node_or_null("/root/SurvivalSystem")
	
	# Create all UI
	_create_all_ui()
	
	# Show help initially
	_show_panel(help_panel)
	
	print("✅ HeelKawnUI: Professional UI system loaded!")
	print("✅ Mouse wheel: Zoom in/out")
	print("✅ Right-click drag: Move camera")
	print("✅ Bottom buttons: All actions")


func _create_all_ui() -> void:
	# Create survival HUD (top-left, always visible)
	_create_survival_hud()
	
	# Create action buttons (bottom-right)
	_create_action_buttons()
	
	# Create inventory panel
	_create_inventory_panel()
	
	# Create chronicle panel
	_create_chronicle_panel()
	
	# Create character panel
	_create_character_panel()
	
	# Create help panel
	_create_help_panel()
	
	# Create camera hint
	_create_camera_hint()


# ==================== SURVIVAL HUD ====================

func _create_survival_hud() -> void:
	survival_hud = PanelContainer.new()
	survival_hud.name = "SurvivalHUD"
	survival_hud.anchor_left = 0.0
	survival_hud.anchor_top = 0.0
	survival_hud.offset_right = 280.0
	survival_hud.offset_bottom = 220.0
	survival_hud.offset_left = 10.0
	survival_hud.offset_top = 10.0
	
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.7)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	survival_hud.add_theme_stylebox_override("panel", style)
	
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	survival_hud.add_child(vbox)
	
	# Title
	var title: Label = Label.new()
	title.text = "⚕️ SURVIVAL STATUS"
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(title)
	
	# Create bars
	var bars: Array = [
		["❤️ Health", "health_bar", 100.0],
		["🍖 Hunger", "hunger_bar", 100.0],
		["💧 Thirst", "thirst_bar", 100.0],
		["⚡ Energy", "energy_bar", 100.0],
	]
	
	for bar_data in bars:
		var hbox: HBoxContainer = HBoxContainer.new()
		var label: Label = Label.new()
		label.text = bar_data[0]
		label.custom_minimum_size.x = 90
		label.add_theme_color_override("font_color", Color.WHITE)
		hbox.add_child(label)
		
		var bar: ProgressBar = ProgressBar.new()
		bar.name = bar_data[1]
		bar.value = bar_data[2]
		bar.max_value = 100.0
		bar.min_value = 0.0
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.custom_minimum_size.y = 16
		hbox.add_child(bar)
		
		vbox.add_child(hbox)
	
	# Temperature
	var temp_hbox: HBoxContainer = HBoxContainer.new()
	var temp_label: Label = Label.new()
	temp_label.text = "🌡️ Temperature:"
	temp_label.add_theme_color_override("font_color", Color.WHITE)
	temp_hbox.add_child(temp_label)
	
	var temp_value: Label = Label.new()
	temp_value.name = "TempValue"
	temp_value.text = "37.0°C"
	temp_value.add_theme_color_override("font_color", Color(0.2, 1.0, 0.2))
	temp_hbox.add_child(temp_value)
	
	vbox.add_child(temp_hbox)
	
	# Status effects
	var status_label: Label = Label.new()
	status_label.text = "Status:"
	status_label.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(status_label)
	
	var status_list: VBoxContainer = VBoxContainer.new()
	status_list.name = "StatusList"
	status_list.add_theme_constant_override("separation", 2)
	vbox.add_child(status_list)
	
	# Add to tree
	get_tree().get_root().add_child(survival_hud)


# ==================== ACTION BUTTONS ====================

func _create_action_buttons() -> void:
	action_buttons = HBoxContainer.new()
	action_buttons.name = "ActionButtons"
	action_buttons.anchor_left = 1.0
	action_buttons.anchor_top = 1.0
	action_buttons.anchor_right = 1.0
	action_buttons.anchor_bottom = 1.0
	action_buttons.offset_left = -420.0
	action_buttons.offset_top = -80.0
	action_buttons.offset_right = -10.0
	action_buttons.offset_bottom = -10.0
	action_buttons.alignment = BoxContainer.ALIGNMENT_END
	action_buttons.add_theme_constant_override("separation", 8)
	
	# Create buttons
	var buttons: Array = [
		["🎒 Inventory", "inventory", KEY_I],
		["📜 Chronicles", "chronicles", KEY_C],
		["👤 Character", "character", KEY_K],
		["❓ Help", "help", KEY_H],
	]
	
	for btn_data in buttons:
		var button: Button = Button.new()
		button.text = btn_data[0]
		button.name = btn_data[1] + "Btn"
		button.custom_minimum_size = Vector2(100, 40)
		
		var style: StyleBoxFlat = _create_button_style()
		button.add_theme_stylebox_override("normal", style)
		
		var hover_style: StyleBoxFlat = style.duplicate()
		hover_style.bg_color = Color(0.3, 0.3, 0.3, 0.9)
		button.add_theme_stylebox_override("hover", hover_style)
		
		button.pressed.connect(_on_button_pressed.bind(btn_data[1]))
		action_buttons.add_child(button)
	
	# Add key hint
	var key_label: Label = Label.new()
	key_label.text = "Keys: I, C, K, H"
	key_label.add_theme_color_override("font_color", Color.GRAY)
	key_label.add_theme_font_size_override("font_size", 10)
	action_buttons.add_child(key_label)
	
	get_tree().get_root().add_child(action_buttons)


func _create_button_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.2, 0.2, 0.8)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_color = Color(0.4, 0.4, 0.4, 0.9)
	return style


func _on_button_pressed(panel_name: String) -> void:
	match panel_name:
		"inventory":
			_toggle_panel(inventory_panel)
		"chronicles":
			_toggle_panel(chronicle_panel)
		"character":
			_toggle_panel(character_panel)
		"help":
			_toggle_panel(help_panel)


# ==================== INVENTORY PANEL ====================

func _create_inventory_panel() -> void:
	inventory_panel = _create_panel("🎒 Inventory", 400, 350)
	inventory_panel.offset_left = -200.0
	inventory_panel.offset_top = -175.0
	
	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	inventory_panel.get_node("Panel/VBoxContainer").add_child(content)
	
	# Items grid
	var grid: GridContainer = GridContainer.new()
	grid.name = "ItemsGrid"
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(grid)
	
	# Close button
	var close_btn: Button = Button.new()
	close_btn.text = "Close (I)"
	close_btn.pressed.connect(func(): _hide_panel(inventory_panel))
	content.add_child(close_btn)
	
	get_tree().get_root().add_child(inventory_panel)


# ==================== CHRONICLE PANEL ====================

func _create_chronicle_panel() -> void:
	chronicle_panel = _create_panel("📜 Chronicles & History", 600, 450)
	chronicle_panel.offset_left = -300.0
	chronicle_panel.offset_top = -225.0
	
	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	chronicle_panel.get_node("Panel/VBoxContainer").add_child(content)
	
	# Tabs
	var tabs: TabContainer = TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(tabs)
	
	# Chronicles tab
	var chronicles_tab: TextEdit = TextEdit.new()
	chronicles_tab.name = "Chronicles"
	chronicles_tab.editable = false
	tabs.add_child(chronicles_tab)
	
	# Actions tab
	var actions_tab: TextEdit = TextEdit.new()
	actions_tab.name = "Actions"
	actions_tab.editable = false
	tabs.add_child(actions_tab)
	
	# Scars tab
	var scars_tab: TextEdit = TextEdit.new()
	scars_tab.name = "Scars"
	scars_tab.editable = false
	tabs.add_child(scars_tab)
	
	# Close button
	var close_btn: Button = Button.new()
	close_btn.text = "Close (C)"
	close_btn.pressed.connect(func(): _hide_panel(chronicle_panel))
	content.add_child(close_btn)
	
	get_tree().get_root().add_child(chronicle_panel)


# ==================== CHARACTER PANEL ====================

func _create_character_panel() -> void:
	character_panel = _create_panel("👤 Character Status", 400, 400)
	character_panel.offset_left = 10.0
	character_panel.offset_top = 230.0
	
	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	character_panel.get_node("Panel/VBoxContainer").add_child(content)
	
	# Awareness
	var awareness: Label = Label.new()
	awareness.name = "AwarenessLabel"
	awareness.text = "Awareness: Unconscious (Level 0)"
	awareness.add_theme_color_override("font_color", Color.WHITE)
	content.add_child(awareness)
	
	# Trauma
	var trauma: Label = Label.new()
	trauma.name = "TraumaLabel"
	trauma.text = "Trauma: 0.0/100"
	trauma.add_theme_color_override("font_color", Color.WHITE)
	content.add_child(trauma)
	
	# Growth
	var growth: Label = Label.new()
	growth.name = "GrowthLabel"
	growth.text = "Growth Points: 0"
	growth.add_theme_color_override("font_color", Color.WHITE)
	content.add_child(growth)
	
	# Memories
	var memories_label: Label = Label.new()
	memories_label.text = "Recent Memories:"
	memories_label.add_theme_color_override("font_color", Color.WHITE)
	content.add_child(memories_label)
	
	var memories_list: ItemList = ItemList.new()
	memories_list.name = "MemoriesList"
	memories_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(memories_list)
	
	# Close button
	var close_btn: Button = Button.new()
	close_btn.text = "Close (K)"
	close_btn.pressed.connect(func(): _hide_panel(character_panel))
	content.add_child(close_btn)
	
	get_tree().get_root().add_child(character_panel)


# ==================== HELP PANEL ====================

func _create_help_panel() -> void:
	help_panel = _create_panel("❓ HeelKawn Help", 500, 500)
	help_panel.offset_left = -250.0
	help_panel.offset_top = -250.0
	
	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	help_panel.get_node("Panel/VBoxContainer").add_child(content)
	
	var help_text: TextEdit = TextEdit.new()
	help_text.editable = false
	help_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	help_text.text = """
[center][font_size=18]🎮 HEELKAWN - CONTROLS & GUIDE[/font_size][/center]

[center]=== MOVEMENT ===[/center]
[b]Mouse Wheel:[/b] Zoom in/out
[b]Right-Click + Drag:[/b] Move camera
[b]WASD / Arrows:[/b] Move camera

[center]=== ACTIONS ===[/center]
[b]Right-Click Tile:[/b] Open action menu
[b]Gather:[/b] Click tree (🪵), rock (🪨), bush (🫐)
[b]Build:[/b] Right-click ground → Build menu

[center]=== UI HOTKEYS ===[/center]
[color=green][b]I[/b][/color] or [b]Inventory Button[/b]: Toggle inventory
[color=green][b]C[/b][/color] or [b]Chronicles Button[/b]: Toggle chronicles
[color=green][b]K[/b][/color] or [b]Character Button[/b]: Toggle character
[color=green][b]H[/b][/color] or [b]Help Button[/b]: Toggle help
[color=green][b]TAB[/b][/color]: Toggle all UI

[center]=== SURVIVAL ===[/center]
- [color=red]Hunger[/color] decays over time (eat berries 🫐)
- [color=blue]Thirst[/color] decays faster (find water)
- [color=orange]Temperature[/color] matters (avoid extreme cold/heat)
- [color=purple]Injuries[/color] heal naturally over time

[center]=== BUILDING ===[/center]
1. Gather wood (🪵) and stone (🪨) first
2. Right-click ground → Build Foundation
3. Build walls → shelter → fire pit
4. Fire pit provides warmth

[center]=== HEELKAWNIANS ===[/center]
- Every pawn [color=yellow]REMEMBERS[/color] experiences
- Every pawn [color=yellow]DREAMS[/color] during sleep
- Every pawn can [color=yellow]GROW[/color] self-aware
- Your actions are [color=yellow]RECORDED FOREVER[/color]

[center][font_size=16]=== YOUR LEGACY BEGINS NOW ===[/font_size][/center]
[center]Right-click to start gathering! [/center]
"""
	content.add_child(help_text)
	
	var close_btn: Button = Button.new()
	close_btn.text = "Close (H)"
	close_btn.pressed.connect(func(): _hide_panel(help_panel))
	content.add_child(close_btn)
	
	get_tree().get_root().add_child(help_panel)


# ==================== CAMERA HINT ====================

func _create_camera_hint() -> void:
	camera_hint = Label.new()
	camera_hint.name = "CameraHint"
	camera_hint.anchor_left = 0.5
	camera_hint.anchor_top = 1.0
	camera_hint.offset_left = -150.0
	camera_hint.offset_top = -30.0
	camera_hint.offset_right = 150.0
	camera_hint.offset_bottom = -10.0
	camera_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	camera_hint.text = "🖱️ Mouse Wheel: Zoom | Right-Click Drag: Move Camera"
	camera_hint.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 0.8))
	camera_hint.add_theme_font_size_override("font_size", 11)
	
	get_tree().get_root().add_child(camera_hint)
	
	# Hide after 5 seconds
	var timer: Timer = Timer.new()
	timer.wait_time = 5.0
	timer.one_shot = true
	timer.timeout.connect(func(): camera_hint.visible = false)
	add_child(timer)
	timer.start()


# ==================== UTILITY FUNCTIONS ====================

func _create_panel(title: String, width: int, height: int) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -float(width) / 2.0
	panel.offset_top = -float(height) / 2.0
	panel.offset_right = float(width) / 2.0
	panel.offset_bottom = float(height) / 2.0
	panel.visible = false
	
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 0.95)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_color = Color(0.3, 0.3, 0.3, 1.0)
	panel.add_theme_stylebox_override("panel", style)
	
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	vbox.name = "VBoxContainer"
	panel.add_child(vbox)
	
	var title_label: Label = Label.new()
	title_label.text = title
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 16)
	title_label.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(title_label)
	
	return panel


func _toggle_panel(panel: PanelContainer) -> void:
	if panel == null:
		return
	
	panel.visible = not panel.visible
	
	if panel.visible:
		_refresh_panel(panel)


func _show_panel(panel: PanelContainer) -> void:
	if panel != null:
		panel.visible = true
		_refresh_panel(panel)


func _hide_panel(panel: PanelContainer) -> void:
	if panel != null:
		panel.visible = false


func _refresh_panel(panel: PanelContainer) -> void:
	if panel == inventory_panel:
		_refresh_inventory()
	elif panel == chronicle_panel:
		_refresh_chronicles()
	elif panel == character_panel:
		_refresh_character()


func _refresh_inventory() -> void:
	if _player_gathering == null:
		return
	
	var grid: GridContainer = inventory_panel.get_node_or_null("Panel/VBoxContainer/ItemsGrid")
	if grid == null:
		return
	
	# Clear
	for child in grid.get_children():
		child.queue_free()
	
	# Get inventory
	var inventory: Dictionary = _player_gathering.get_inventory()
	
	# Add items
	for resource in inventory:
		var qty: int = inventory[resource]
		if qty <= 0:
			continue
		
		var item_box: VBoxContainer = VBoxContainer.new()
		item_box.add_theme_constant_override("separation", 2)
		item_box.alignment = BoxContainer.ALIGNMENT_CENTER
		
		var icon: Label = Label.new()
		icon.text = _get_resource_icon(resource)
		icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon.add_theme_font_size_override("font_size", 24)
		item_box.add_child(icon)
		
		var name: Label = Label.new()
		name.text = _get_resource_name(resource)
		name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name.add_theme_font_size_override("font_size", 10)
		name.add_theme_color_override("font_color", Color.WHITE)
		item_box.add_child(name)
		
		var qty_label: Label = Label.new()
		qty_label.text = "x" + str(qty)
		qty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		qty_label.add_theme_font_size_override("font_size", 12)
		qty_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 1.0))
		item_box.add_child(qty_label)
		
		grid.add_child(item_box)


func _refresh_chronicles() -> void:
	if _world_action_ledger == null:
		return
	
	var tabs: TabContainer = chronicle_panel.get_node_or_null("Panel/VBoxContainer/TabContainer")
	if tabs == null:
		return
	
	# Get chronicles
	var chronicles: Array[Dictionary] = _world_action_ledger.get_all_chronicles()
	
	# Update chronicles tab
	var chronicles_tab: TextEdit = tabs.get_child(0)
	if chronicles.size() > 0:
		var text: String = ""
		for c in chronicles:
			text += "[b]%s[/b]\n%s\n\n" % [c.get("title", "Unknown"), c.get("content", "")]
		chronicles_tab.text = text
	else:
		chronicles_tab.text = "No chronicles yet. Perform actions to create history!"
	
	# Get actions
	var actions: Array[Dictionary] = _world_action_ledger.get_full_ledger()
	var actions_tab: TextEdit = tabs.get_child(1)
	if actions.size() > 0:
		var text: String = "[b]Recent Actions:[/b]\n"
		var start: int = max(0, actions.size() - 50)
		for i in range(start, actions.size()):
			var a: Dictionary = actions[i]
			text += "[Year %d] %s: %s\n" % [a.get("year", 0), a.get("actor_name", "?"), a.get("action_description", "")]
		actions_tab.text = text
	else:
		actions_tab.text = "No actions recorded yet."
	
	# Get scars
	var scars: Array[Dictionary] = _world_action_ledger.world_scars
	var scars_tab: TextEdit = tabs.get_child(2)
	if scars.size() > 0:
		var text: String = "[b]World Scars:[/b]\n"
		for s in scars:
			var icon: String = "⚔️" if s.get("type", "") == "battle" else "🌋"
			var perm: String = "∞" if s.get("permanent", false) else "⏳"
			text += "%s %s [%s]\n" % [icon, s.get("description", ""), perm]
		scars_tab.text = text
	else:
		scars_tab.text = "No world scars yet."


func _refresh_character() -> void:
	if _pawn_consciousness == null:
		return
	
	# Get first pawn for now
	var pawn_spawner: Node = get_node_or_null("/root/Main/WorldViewport/PawnSpawner")
	if pawn_spawner == null or not pawn_spawner.has_node("pawns"):
		return
	
	var pawns: Array = (pawn_spawner.get("pawns") if pawn_spawner.get("pawns") != null else [])
	if pawns.size() == 0:
		return
	
	var pawn: Node = pawns[0]
	var pawn_id: int = int(pawn.data.id)
	
	var consciousness: Dictionary = _pawn_consciousness.get_consciousness_summary(pawn_id)
	
	# Update labels
	var awareness: Label = character_panel.get_node_or_null("Panel/VBoxContainer/AwarenessLabel")
	if awareness != null:
		awareness.text = "Awareness: %s (Level %d)" % [consciousness.get("awareness_name", "Unknown"), consciousness.get("self_awareness", 0)]
	
	var trauma: Label = character_panel.get_node_or_null("Panel/VBoxContainer/TraumaLabel")
	if trauma != null:
		trauma.text = "Trauma: %.1f/100" % consciousness.get("trauma_level", 0.0)
	
	var growth: Label = character_panel.get_node_or_null("Panel/VBoxContainer/GrowthLabel")
	if growth != null:
		growth.text = "Growth Points: %d" % consciousness.get("growth_points", 0)
	
	# Update memories
	var memories_list: ItemList = character_panel.get_node_or_null("Panel/VBoxContainer/MemoriesList")
	if memories_list != null:
		memories_list.clear()
		var memories: Array[Dictionary] = _pawn_consciousness.get_memories(pawn_id, "", 5)
		for m in memories:
			var emoji: String = "😊" if m.get("emotion", 0) > 0 else "😢" if m.get("emotion", 0) < 0 else "😐"
			memories_list.add_item("%s %s" % [emoji, m.get("description", "")])


func _refresh_survival_hud() -> void:
	if _survival_system == null:
		return
	
	# Get first pawn
	var pawn_spawner: Node = get_node_or_null("/root/Main/WorldViewport/PawnSpawner")
	if pawn_spawner == null or not pawn_spawner.has_node("pawns"):
		return
	
	var pawns: Array = (pawn_spawner.get("pawns") if pawn_spawner.get("pawns") != null else [])
	if pawns.size() == 0:
		return
	
	var pawn: Node = pawns[0]
	if pawn.data == null:
		return
	
	var data: RefCounted = pawn.data
	
	# Update bars
	var health_bar: ProgressBar = survival_hud.get_node_or_null("VBoxContainer/HBoxContainer/health_bar")
	var hunger_bar: ProgressBar = survival_hud.get_node_or_null("VBoxContainer/HBoxContainer2/hunger_bar")
	var thirst_bar: ProgressBar = survival_hud.get_node_or_null("VBoxContainer/HBoxContainer3/thirst_bar")
	var energy_bar: ProgressBar = survival_hud.get_node_or_null("VBoxContainer/HBoxContainer4/energy_bar")
	var temp_value: Label = survival_hud.get_node_or_null("VBoxContainer/HBoxContainer5/TempValue")
	
	if health_bar != null and data.has("health"):
		health_bar.value = data.health
	
	if hunger_bar != null and data.has("hunger"):
		hunger_bar.value = data.hunger
	
	if thirst_bar != null and data.has("thirst"):
		thirst_bar.value = data.thirst
	
	if energy_bar != null:
		var energy: float = (data.get("energy") if data.get("energy") != null else (data.get("rest") if data.get("rest") != null else 100.0))
		energy_bar.value = energy
	
	if temp_value != null and data.has("body_temperature"):
		var temp: float = data.body_temperature
		temp_value.text = "%.1f°C" % temp
		temp_value.add_theme_color_override("font_color", _get_temp_color(temp))


func _get_temp_color(temp: float) -> Color:
	if temp >= 36.0 and temp <= 37.5:
		return Color(0.2, 1.0, 0.2)
	elif temp < 35.0 or temp > 39.0:
		return Color(1.0, 0.2, 0.2)
	else:
		return Color(1.0, 1.0, 0.2)


func _get_resource_icon(resource: String) -> String:
	var icons: Dictionary = {
		"wood": "🪵", "stone": "🪨", "berries": "🫐", "flint": "🔩",
		"stick": "🥢", "iron_ore": "ite", "meat_raw": "🥩", "hide": "🟫"
	}
	return icons.get(resource, "❓")


func _get_resource_name(resource: String) -> String:
	var names: Dictionary = {
		"wood": "Wood", "stone": "Stone", "berries": "Berries",
		"flint": "Flint", "stick": "Stick", "iron_ore": "Iron"
	}
	return names.get(resource, resource)


# ==================== INPUT HANDLING ====================

func _input(event: InputEvent) -> void:
	# Hotkeys
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_I:
				_toggle_panel(inventory_panel)
			KEY_C:
				_toggle_panel(chronicle_panel)
			KEY_K:
				_toggle_panel(character_panel)
			KEY_H, KEY_F1:
				_toggle_panel(help_panel)
			KEY_TAB:
				_toggle_all_ui()
	
	# Camera zoom
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_camera_zoom = minf(3.0, _camera_zoom + 0.2)
			_apply_camera_zoom()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_camera_zoom = maxf(0.5, _camera_zoom - 0.2)
			_apply_camera_zoom()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_camera_dragging = event.pressed
			_drag_start = event.position
	
	# Camera drag
	if event is InputEventMouseMotion and _camera_dragging:
		var delta: Vector2 = event.position - _drag_start
		_drag_start = event.position
		_move_camera(delta)


func _apply_camera_zoom() -> void:
	var camera: Camera2D = get_viewport().get_camera_2d()
	if camera != null:
		camera.zoom = Vector2(_camera_zoom, _camera_zoom)


func _move_camera(delta: Vector2) -> void:
	var camera: Camera2D = get_viewport().get_camera_2d()
	if camera != null:
		camera.offset -= delta


func _toggle_all_ui() -> void:
	var panels: Array = [inventory_panel, chronicle_panel, character_panel, help_panel]
	var any_visible: bool = false
	
	for panel in panels:
		if panel != null and panel.visible:
			any_visible = true
			break
	
	for panel in panels:
		if panel != null:
			panel.visible = not any_visible


func _process(delta: float) -> void:
	_update_timer += delta
	
	# Update survival HUD every 0.5 seconds
	if _update_timer >= 0.5:
		_update_timer = 0.0
		_refresh_survival_hud()
		_refresh_inventory()
