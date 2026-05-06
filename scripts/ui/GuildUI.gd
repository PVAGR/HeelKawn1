extends PanelContainer
## GuildUI - Clean, professional guild management panel
##
## Features:
## - Simple, sleek design
## - Guild info at a glance
## - Easy join/leave
## - Clear progression display
## - Perk showcase

var _selected_guild_id: int = -1
var _guild_system: Node = null
var _modern_theme: Node = null

# UI references
var _guild_list: VBoxContainer = null
var _guild_info: VBoxContainer = null
var _guild_name_label: Label = null
var _guild_level_label: Label = null
var _guild_xp_bar: ProgressBar = null
var _guild_rank_label: Label = null
var _member_count_label: Label = null
var _perks_container: VBoxContainer = null
var _join_button: Button = null
var _leave_button: Button = null


func _ready() -> void:
	custom_minimum_size = Vector2(400, 600)
	_guild_system = get_node_or_null("/root/GuildSystem")
	_modern_theme = get_node_or_null("/root/ModernTheme")
	
	_build_ui()
	_refresh_guild_list()


func _build_ui() -> void:
	# Main horizontal layout
	var main_hbox: HBoxContainer = HBoxContainer.new()
	main_hbox.add_theme_constant_override("separation", 16)
	add_child(main_hbox)
	
	# Left panel: Guild list
	var list_panel: PanelContainer = _create_panel()
	list_panel.custom_minimum_size = Vector2(180, 0)
	main_hbox.add_child(list_panel)
	
	var list_vbox: VBoxContainer = VBoxContainer.new()
	list_vbox.add_theme_constant_override("separation", 8)
	list_panel.add_child(list_vbox)
	
	# Guild list title
	var list_title: Label = _modern_theme.create_styled_label("Guilds", "large")
	list_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	list_vbox.add_child(list_title)
	
	# Guild list
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_vbox.add_child(scroll)
	
	_guild_list = VBoxContainer.new()
	_guild_list.add_theme_constant_override("separation", 4)
	scroll.add_child(_guild_list)
	
	# Right panel: Guild info
	var info_panel: PanelContainer = _create_panel()
	info_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_hbox.add_child(info_panel)
	
	var info_vbox: VBoxContainer = VBoxContainer.new()
	info_vbox.add_theme_constant_override("separation", 12)
	info_panel.add_child(info_vbox)
	
	# Guild name
	_guild_name_label = _modern_theme.create_styled_label("Select a Guild", "title")
	_guild_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_vbox.add_child(_guild_name_label)
	
	# Guild icon + level
	var level_hbox: HBoxContainer = HBoxContainer.new()
	level_hbox.add_theme_constant_override("separation", 8)
	level_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	info_vbox.add_child(level_hbox)
	
	_guild_level_label = _modern_theme.create_styled_label("Level 1", "large")
	level_hbox.add_child(_guild_level_label)
	
	# XP bar
	_guild_xp_bar = ProgressBar.new()
	_guild_xp_bar.max_value = 100
	_guild_xp_bar.min_value = 0
	_guild_xp_bar.value = 0
	_guild_xp_bar.custom_minimum_size = Vector2(0, 24)
	_guild_xp_bar.show_percentage = true
	info_vbox.add_child(_guild_xp_bar)
	
	# Rank
	var rank_label: Label = _modern_theme.create_styled_label("Your Rank:", "small")
	info_vbox.add_child(rank_label)
	
	_guild_rank_label = _modern_theme.create_styled_label("Initiate", "normal")
	info_vbox.add_child(_guild_rank_label)
	
	# Member count
	_member_count_label = _modern_theme.create_styled_label("Members: 0", "small")
	info_vbox.add_child(_member_count_label)
	
	# Perks title
	var perks_title: Label = _modern_theme.create_styled_label("Guild Perks", "small")
	info_vbox.add_child(perks_title)
	
	# Perks container
	_perks_container = VBoxContainer.new()
	_perks_container.add_theme_constant_override("separation", 4)
	info_vbox.add_child(_perks_container)
	
	# Spacer
	info_vbox.add_child(Control.new())
	
	# Action buttons
	var button_hbox: HBoxContainer = HBoxContainer.new()
	button_hbox.add_theme_constant_override("separation", 8)
	info_vbox.add_child(button_hbox)
	
	_join_button = _modern_theme.create_styled_button("Join Guild")
	_join_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_join_button.pressed.connect(_on_join_pressed)
	button_hbox.add_child(_join_button)
	
	_leave_button = _modern_theme.create_styled_button("Leave Guild")
	_leave_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_leave_button.pressed.connect(_on_leave_pressed)
	button_hbox.add_child(_leave_button)


func _create_panel() -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	if _modern_theme != null:
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = _modern_theme.get_color("bg_medium")
		style.set_corner_radius_all(8)
		panel.add_theme_stylebox_override("panel", style)
	return panel


func _refresh_guild_list() -> void:
	# Clear guild list
	for child in _guild_list.get_children():
		child.queue_free()
	
	if _guild_system == null:
		return
	
	# Get all guilds
	var guilds: Array = _guild_system.get_all_guilds()
	
	for guild in guilds:
		var guild_btn: Button = _modern_theme.create_styled_button("")
		guild_btn.text = "%s %s" % [_guild_system.get_guild_type_icon(guild.guild_id), guild.name]
		guild_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		guild_btn.pressed.connect(_on_guild_selected.bind(guild.guild_id))
		_guild_list.add_child(guild_btn)


func _on_guild_selected(guild_id: int) -> void:
	_selected_guild_id = guild_id
	
	if _guild_system == null:
		return
	
	var guild: Dictionary = _guild_system.get_guild(guild_id)
	if guild.is_empty():
		return
	
	# Update UI
	_guild_name_label.text = "%s %s" % [_guild_system.get_guild_type_icon(guild_id), guild.name]
	_guild_level_label.text = "Level %d" % guild.guild_level
	_guild_xp_bar.value = guild.guild_xp % 100
	_member_count_label.text = "Members: %d" % guild.members.size()
	
	# Update perks
	for child in _perks_container.get_children():
		child.queue_free()
	
	for perk_level in guild.perks_unlocked:
		var perk_data: Dictionary = _guild_system.get_perk_data(perk_level)
		if not perk_data.is_empty():
			var perk_label: Label = _modern_theme.create_styled_label("✅ %s" % perk_data.name, "small")
			_perks_container.add_child(perk_label)
	
	# Update buttons
	var player_pawn_id: int = _get_player_pawn_id()
	var is_member: bool = _guild_system.is_pawn_in_guild(player_pawn_id)
	
	_join_button.visible = not is_member
	_leave_button.visible = is_member


func _on_join_pressed() -> void:
	if _selected_guild_id < 0 or _guild_system == null:
		return
	
	var player_pawn_id: int = _get_player_pawn_id()
	_guild_system.join_guild(_selected_guild_id, player_pawn_id)
	_refresh_guild_list()
	_on_guild_selected(_selected_guild_id)


func _on_leave_pressed() -> void:
	if _selected_guild_id < 0 or _guild_system == null:
		return
	
	var player_pawn_id: int = _get_player_pawn_id()
	_guild_system.leave_guild(_selected_guild_id, player_pawn_id)
	_refresh_guild_list()
	
	# Clear selection
	_selected_guild_id = -1
	_guild_name_label.text = "Select a Guild"
	_guild_level_label.text = ""
	_guild_xp_bar.value = 0
	_guild_rank_label.text = ""
	_member_count_label.text = "Members: 0"
	
	for child in _perks_container.get_children():
		child.queue_free()


func _get_player_pawn_id() -> int:
	# Get current player pawn ID
	# TODO: Implement proper player pawn tracking
	return 1


func update_display() -> void:
	if _selected_guild_id >= 0:
		_on_guild_selected(_selected_guild_id)
