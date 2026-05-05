class_name PawnInfoPanel
extends CanvasLayer

## Right-side **Heelkawnian** sheet (embodied citizen: NPC or player incarnation).
## Same `Pawn` / `PawnData` surface for parity. Chunky portrait reads
## from [PawnData] colors; coach lines are deterministic from likings + skills.
##
## Built programmatically (no .tscn) to mirror the BuildToolbar style and so
## tweaks live in one place. Polls on a lightweight wall-clock interval and
## repaints only when backend state signatures change.

const PANEL_BG:     Color = Color(0.05, 0.06, 0.08, 0.90)
const PANEL_BORDER: Color = Color(0.85, 0.78, 0.40, 0.65)
const TEXT_DIM:     Color = Color(0.70, 0.70, 0.75)
const TEXT_BRIGHT:  Color = Color(0.96, 0.96, 0.98)
const ACCENT:       Color = Color8(255, 209, 102)
const _WM = preload("res://autoloads/WorldMemory.gd")

const FONT_TITLE: int = 12
const FONT_BODY:  int = 10
const FONT_SMALL: int = 9
const FONT_MONO:  int = 9

const PANEL_WIDTH:    float = 268.0
const RIGHT_INSET:    float = 8.0
const TOP_INSET:      float = 8.0
## UI refresh is state-driven (signature diff), polled on wall-clock cadence.
## This keeps presentation dynamic without hard-binding repaint cadence to ticks.
const UI_POLL_INTERVAL_SEC: float = 0.35
## Settlement/governance identity is allowed to refresh on a coarse tick bucket
## instead of every UI poll. This keeps observer mode smooth while preserving
## living-world updates in the sheet.
const WORLD_CONTEXT_REFRESH_TICKS: int = 30
const PORTRAIT_COLS:  int = 6
const PORTRAIT_ROWS:  int = 8

const NEED_BARS: Array = [
	# (label, accessor name on PawnData, color)
	{"label": "Hunger", "field": "hunger", "color": Color8(230, 130, 100)},
	{"label": "Rest",   "field": "rest",   "color": Color8(140, 170, 235)},
	{"label": "Mood",   "field": "mood",   "color": Color8(180, 220, 130)},
	{"label": "Health", "field": "health", "color": Color8(220, 220, 220)},
]

const SKILLS_ORDER: Array = [
	# (label, PawnData.Skill enum value)
	{"label": "Foraging", "skill": 0},
	{"label": "Mining",   "skill": 1},
	{"label": "Chopping", "skill": 2},
	{"label": "Building", "skill": 3},
	{"label": "Hunting",  "skill": 4},
]

## (field on PawnData, checkbox label) — maps queue job categories to human text.
const WORK_CHECKS: Array = [
	{"field": "work_forage", "text": "Forage / gather"},
	{"field": "work_mine",   "text": "Mine / tunnel"},
	{"field": "work_chop",   "text": "Chop wood"},
	{"field": "work_hunt",   "text": "Hunt animals"},
	{"field": "work_build",  "text": "Build (bed/wall/door)"},
]


# ---- nodes built once in _ready, then rebound per pawn ----
var _panel: PanelContainer
var _root_vbox: VBoxContainer
var _header_row: HBoxContainer = null
var _title_label: Label
var _subtitle_label: Label = null
var _state_label: Label
var _need_bars: Dictionary = {}    # field name -> {bar: ProgressBar, label: Label}
var _skill_lines: Dictionary = {}  # skill enum -> Label
var _carry_label: Label
var _tile_label: Label
var _hint_label: Label
var _inspect_msg_label: Label = null
## field name (e.g. "work_mine") -> CheckBox, kept in sync from PawnData.
var _work_checkboxes: Dictionary = {}
## TabContainer for organized sections
var _tab_container: TabContainer = null
var _copy_dump_button: Button = null
## Tab content containers
var _tab_identity: VBoxContainer = null
var _tab_needs: VBoxContainer = null
var _tab_matrix: VBoxContainer = null
var _tab_neural: VBoxContainer = null
var _tab_social: VBoxContainer = null
var _tab_narrative: VBoxContainer = null  # Phase 5: Emergent Narrative
## Matrix/Neural display labels
var _matrix_inputs_label: RichTextLabel = null
var _neural_outputs_label: RichTextLabel = null
var _neural_bias_label: Label = null

var _pawn: Pawn = null
## When true (map-only mode), hide sheet even if a pawn is selected.
var _overlay_suppressed: bool = false
var _player_context_mode_label: String = "SPECTATOR"
var _player_context_pawn_id: int = -1
var _player_context_picker_visible: bool = false
var _traits_label: Label = null
var _lineage_label: Label = null
var _simple_lineage_label: Label = null
var _appearance_label: Label = null
var _mood_status_label: Label = null
var _crisis_level_label: Label = null
var _liking_label: Label = null
var _coach_label: Label = null
var _social_label: Label = null
var _identity_label: Label = null
var _settlement_label: Label = null
var _action_skills_label: Label = null
var _tier_label: Label = null
var _tier_bar: ProgressBar = null
var _portrait_cells: Array[ColorRect] = []
var _poll_accum_sec: float = 0.0
var _last_ui_signature: String = ""


func _ready() -> void:
	layer = 100
	_build_ui()
	set_process(true)
	get_viewport().size_changed.connect(_reposition)
	_set_visible(false)


# ==================== external API ====================

func set_overlay_suppressed(s: bool) -> void:
	if _overlay_suppressed == s:
		return
	_overlay_suppressed = s
	if _overlay_suppressed:
		_set_visible(false)
	elif _pawn != null and is_instance_valid(_pawn):
		_set_visible(true)


## Bind the panel to a specific pawn. Pass null to hide it.
func bind_pawn(p: Pawn) -> void:
	_pawn = p
	if _pawn == null:
		_set_visible(false)
		_last_ui_signature = ""
		return
	if _overlay_suppressed:
		_set_visible(false)
	else:
		_set_visible(true)
	_poll_accum_sec = UI_POLL_INTERVAL_SEC
	_last_ui_signature = ""
	_refresh()


func set_player_context(mode_label: String, player_pawn_id: int, picker_visible: bool) -> void:
	var next_mode: String = mode_label if not mode_label.is_empty() else "SPECTATOR"
	if _player_context_mode_label == next_mode and _player_context_pawn_id == player_pawn_id and _player_context_picker_visible == picker_visible:
		return
	_player_context_mode_label = next_mode
	_player_context_pawn_id = player_pawn_id
	_player_context_picker_visible = picker_visible
	if _pawn != null and is_instance_valid(_pawn):
		_refresh()


# ==================== layout ====================

func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.add_theme_stylebox_override("panel", _make_panel_style())
	_panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0.0)
	root.add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   8)
	margin.add_theme_constant_override("margin_right",  8)
	margin.add_theme_constant_override("margin_top",     6)
	margin.add_theme_constant_override("margin_bottom",  6)
	_panel.add_child(margin)

	_root_vbox = VBoxContainer.new()
	_root_vbox.add_theme_constant_override("separation", 3)
	margin.add_child(_root_vbox)

	# Header with portrait and name
	_header_row = HBoxContainer.new()
	_header_row.add_theme_constant_override("separation", 6)
	_root_vbox.add_child(_header_row)

	var portrait_frame := PanelContainer.new()
	var cell_px: int = 6
	portrait_frame.custom_minimum_size = Vector2(PORTRAIT_COLS * cell_px + 3, PORTRAIT_ROWS * cell_px + 3)
	var psty := StyleBoxFlat.new()
	psty.bg_color = Color(0.02, 0.03, 0.06, 1.0)
	psty.border_color = PANEL_BORDER
	psty.set_border_width_all(1)
	psty.set_corner_radius_all(2)
	portrait_frame.add_theme_stylebox_override("panel", psty)
	var pm := MarginContainer.new()
	pm.add_theme_constant_override("margin_left", 1)
	pm.add_theme_constant_override("margin_right", 1)
	pm.add_theme_constant_override("margin_top", 1)
	pm.add_theme_constant_override("margin_bottom", 1)
	portrait_frame.add_child(pm)
	var grid := GridContainer.new()
	grid.columns = PORTRAIT_COLS
	pm.add_child(grid)
	for _i in range(PORTRAIT_COLS * PORTRAIT_ROWS):
		var c := ColorRect.new()
		c.custom_minimum_size = Vector2(cell_px, cell_px)
		grid.add_child(c)
		_portrait_cells.append(c)
	_header_row.add_child(portrait_frame)

	var name_col := VBoxContainer.new()
	name_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_col.add_theme_constant_override("separation", 1)
	_title_label = _make_label("", FONT_TITLE, TEXT_BRIGHT)
	_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_col.add_child(_title_label)
	_subtitle_label = _make_label("", FONT_SMALL, TEXT_DIM)
	_subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_col.add_child(_subtitle_label)
	_header_row.add_child(name_col)

	# Tier indicator (small bar like need indicators)
	var tier_col := VBoxContainer.new()
	tier_col.name = "TierColumn"
	tier_col.size_flags_horizontal = Control.SIZE_SHRINK_END
	tier_col.add_theme_constant_override("separation", 2)
	_header_row.add_child(tier_col)

	var tier_header := _make_label("TIER", FONT_SMALL, ACCENT)
	tier_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tier_col.add_child(tier_header)

	_tier_bar = ProgressBar.new()
	_tier_bar.min_value = 0.0
	_tier_bar.max_value = 100.0
	_tier_bar.value = 0.0
	_tier_bar.show_percentage = false
	_tier_bar.custom_minimum_size = Vector2(40, 8)
	_tier_bar.size_flags_horizontal = Control.SIZE_SHRINK_END
	var tier_fill := StyleBoxFlat.new()
	tier_fill.bg_color = Color8(255, 209, 102)
	tier_fill.set_corner_radius_all(2)
	_tier_bar.add_theme_stylebox_override("fill", tier_fill)
	var tier_bg := StyleBoxFlat.new()
	tier_bg.bg_color = Color(0.12, 0.13, 0.16, 1.0)
	tier_bg.set_corner_radius_all(2)
	_tier_bar.add_theme_stylebox_override("background", tier_bg)
	tier_col.add_child(_tier_bar)

	_tier_label = _make_label("1", FONT_SMALL, TEXT_BRIGHT)
	_tier_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tier_col.add_child(_tier_label)

	# Current activity (compact)
	_state_label = _make_label("", FONT_BODY, ACCENT)
	_state_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_root_vbox.add_child(_state_label)

	# COPY DUMP button
	_copy_dump_button = Button.new()
	_copy_dump_button.text = "COPY DUMP"
	_copy_dump_button.custom_minimum_size = Vector2(0, 22)
	_copy_dump_button.pressed.connect(_on_copy_dump_pressed)
	_root_vbox.add_child(_copy_dump_button)

	# TabContainer for organized sections
	_tab_container = TabContainer.new()
	# _tab_container.tab_close_display_policy = TabContainer.CLOSE_BUTTON_NEVER  # Disabled for Godot 4.6 compatibility
	_tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_root_vbox.add_child(_tab_container)

	# Identity tab
	_tab_identity = VBoxContainer.new()
	_tab_identity.add_theme_constant_override("separation", 2)
	_tab_container.add_child(_tab_identity)
	_populate_identity_tab()

	# Needs tab
	_tab_needs = VBoxContainer.new()
	_tab_needs.add_theme_constant_override("separation", 2)
	_tab_container.add_child(_tab_needs)
	_populate_needs_tab()

	# Matrix Inputs tab (DEBUG ONLY - hidden in release builds)
	if OS.is_debug_build():
		_tab_matrix = VBoxContainer.new()
		_tab_matrix.add_theme_constant_override("separation", 2)
		_tab_container.add_child(_tab_matrix)
		_populate_matrix_tab()

		# Neural Outputs tab (DEBUG ONLY - hidden in release builds)
		_tab_neural = VBoxContainer.new()
		_tab_neural.add_theme_constant_override("separation", 2)
		_tab_container.add_child(_tab_neural)
		_populate_neural_tab()

	# Social tab
	_tab_social = VBoxContainer.new()
	_tab_social.add_theme_constant_override("separation", 2)
	_tab_container.add_child(_tab_social)
	_populate_social_tab()

	# Narrative tab (Phase 5: Emergent Narrative)
	_tab_narrative = VBoxContainer.new()
	_tab_narrative.add_theme_constant_override("separation", 2)
	_tab_container.add_child(_tab_narrative)
	_populate_narrative_tab()

	# Set tab titles
	_tab_container.set_tab_title(0, "ID")
	_tab_container.set_tab_title(1, "Needs")
	if OS.is_debug_build():
		_tab_container.set_tab_title(2, "Matrix")
		_tab_container.set_tab_title(3, "Neural")
		_tab_container.set_tab_title(4, "Social")
		_tab_container.set_tab_title(5, "Narrative")
	else:
		_tab_container.set_tab_title(2, "Social")
		_tab_container.set_tab_title(3, "Narrative")

	# Footer hint
	_hint_label = _make_label("[Esc] deselect", FONT_SMALL, Color(0.55, 0.55, 0.60))
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_root_vbox.add_child(_hint_label)

	call_deferred("_reposition")


func _populate_identity_tab() -> void:
	_traits_label = _make_label("", FONT_SMALL, TEXT_DIM)
	_traits_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tab_identity.add_child(_traits_label)

	_tab_identity.add_child(_make_section_header("Lineage"))
	_lineage_label = _make_label("", FONT_SMALL, TEXT_DIM)
	_lineage_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tab_identity.add_child(_lineage_label)

	# Simple lineage display (Born: Parent | Household)
	_simple_lineage_label = _make_label("", FONT_SMALL, TEXT_BRIGHT)
	_simple_lineage_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tab_identity.add_child(_simple_lineage_label)

	_appearance_label = _make_label("", FONT_SMALL, TEXT_DIM)
	_appearance_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tab_identity.add_child(_appearance_label)

	_tab_identity.add_child(_make_section_header("Work bias"))
	_liking_label = _make_label("", FONT_SMALL, TEXT_DIM)
	_liking_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tab_identity.add_child(_liking_label)

	_tab_identity.add_child(_make_section_header("Coach"))
	_coach_label = _make_label("", FONT_SMALL, TEXT_DIM)
	_coach_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tab_identity.add_child(_coach_label)

	_tab_identity.add_child(_make_section_header("Heelkawnian"))
	_identity_label = _make_label("", FONT_SMALL, TEXT_DIM)
	_identity_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tab_identity.add_child(_identity_label)

	_tab_identity.add_child(_make_section_header("Settlement"))
	_settlement_label = _make_label("", FONT_SMALL, TEXT_DIM)
	_settlement_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tab_identity.add_child(_settlement_label)


func _populate_needs_tab() -> void:
	for entry in NEED_BARS:
		_add_need_row_to_tab(entry.label, entry.field, entry.color, _tab_needs)


func _populate_matrix_tab() -> void:
	_matrix_inputs_label = RichTextLabel.new()
	_matrix_inputs_label.bbcode_enabled = true
	_matrix_inputs_label.fit_content = true
	_matrix_inputs_label.scroll_active = true
	_matrix_inputs_label.custom_minimum_size = Vector2(0, 220)
	_matrix_inputs_label.add_theme_font_size_override("normal_font_size", FONT_MONO)
	_tab_matrix.add_child(_matrix_inputs_label)


func _populate_neural_tab() -> void:
	_neural_bias_label = _make_label("", FONT_BODY, ACCENT)
	_neural_bias_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tab_neural.add_child(_neural_bias_label)

	_neural_outputs_label = RichTextLabel.new()
	_neural_outputs_label.bbcode_enabled = true
	_neural_outputs_label.fit_content = true
	_neural_outputs_label.scroll_active = true
	_neural_outputs_label.custom_minimum_size = Vector2(0, 100)
	_neural_outputs_label.add_theme_font_size_override("normal_font_size", FONT_MONO)
	_tab_neural.add_child(_neural_outputs_label)


func _populate_social_tab() -> void:
	_social_label = _make_label("", FONT_SMALL, TEXT_DIM)
	_social_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tab_social.add_child(_social_label)

	_mood_status_label = _make_label("", FONT_SMALL, TEXT_DIM)
	_mood_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tab_social.add_child(_mood_status_label)

	_crisis_level_label = _make_label("", FONT_SMALL, TEXT_DIM)
	_tab_social.add_child(_crisis_level_label)


func _populate_narrative_tab() -> void:
	# Narrative label - shows dynamic pawn story
	var narrative_label: RichTextLabel = RichTextLabel.new()
	narrative_label.name = "NarrativeLabel"
	narrative_label.bbcode_enabled = true
	narrative_label.fit_content = true
	narrative_label.scroll_active = true
	narrative_label.custom_minimum_size = Vector2(0, 280)
	narrative_label.add_theme_font_size_override("normal_font_size", FONT_BODY)
	_tab_narrative.add_child(narrative_label)


func _add_need_row_to_tab(label_text: String, field: String, color: Color, parent: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	parent.add_child(row)

	var name_lbl := _make_label(label_text, FONT_SMALL, TEXT_DIM)
	name_lbl.custom_minimum_size = Vector2(48, 0)
	row.add_child(name_lbl)

	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 100.0
	bar.value = 100.0
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 8)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(2)
	bar.add_theme_stylebox_override("fill", fill)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.12, 0.13, 0.16, 1.0)
	bg.set_corner_radius_all(2)
	bar.add_theme_stylebox_override("background", bg)
	row.add_child(bar)

	var num_lbl := _make_label("100", FONT_SMALL, TEXT_BRIGHT)
	num_lbl.custom_minimum_size = Vector2(24, 0)
	num_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(num_lbl)

	_need_bars[field] = {"bar": bar, "label": num_lbl}


func _on_copy_dump_pressed() -> void:
	if _pawn == null or not is_instance_valid(_pawn) or _pawn.data == null:
		return
	
	var d: PawnData = _pawn.data
	var tick: int = GameManager.tick_count
	
	var dump_lines: PackedStringArray = []
	dump_lines.append("Pawn: %s | Tick: %d" % [d.display_name, tick])
	dump_lines.append("ID: %d | Age: %d | Profession: %s" % [d.id, d.age, d.profession_label_from_enum(d.current_profession)])
	dump_lines.append("Needs: Hunger=%.1f Rest=%.1f Mood=%.1f Health=%.1f" % [d.hunger, d.rest, d.mood, d.health])
	dump_lines.append("Skills: Forage=%d Mine=%d Chop=%d Build=%d Hunt=%d" % [
		d.get_skill_level(0), d.get_skill_level(1), d.get_skill_level(2), d.get_skill_level(3), d.get_skill_level(4)
	])
	dump_lines.append("Affinities: combat=%.2f farming=%.2f building=%.2f crafting=%.2f diplomacy=%.2f" % [
		d.affinities.get("combat", 0.5), d.affinities.get("farming", 0.5), d.affinities.get("building", 0.5),
		d.affinities.get("crafting", 0.5), d.affinities.get("diplomacy", 0.5)
	])
	
	# Neural state if available
	if WorldAI != null and WorldAI.has_method("get_pawn_neural_state"):
		var neural_state: Dictionary = WorldAI.get_pawn_neural_state(int(d.id))
		if not neural_state.is_empty():
			var inputs: Array = neural_state.get("inputs", [])
			var outputs: Array = neural_state.get("outputs", [])
			dump_lines.append("Neural: Inputs=%s Outputs=%s" % [str(inputs), str(outputs)])
	
	var dump_text: String = "\n".join(dump_lines)
	DisplayServer.clipboard_set(dump_text)
	
	if _inspect_msg_label != null:
		_inspect_msg_label.text = "Copied to clipboard!"
		_inspect_msg_label.modulate = Color(0.6, 1.0, 0.6)
		await get_tree().create_timer(2.0).timeout
		if _inspect_msg_label != null:
			_inspect_msg_label.text = ""


func _add_need_row(label_text: String, field: String, color: Color) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	_root_vbox.add_child(row)

	var name_lbl := _make_label(label_text, FONT_SMALL, TEXT_DIM)
	name_lbl.custom_minimum_size = Vector2(54, 0)
	row.add_child(name_lbl)

	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 100.0
	bar.value = 100.0
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 10)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Tint via stylebox so each bar reads at a glance.
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(2)
	bar.add_theme_stylebox_override("fill", fill)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.12, 0.13, 0.16, 1.0)
	bg.set_corner_radius_all(2)
	bar.add_theme_stylebox_override("background", bg)
	row.add_child(bar)

	var num_lbl := _make_label("100", FONT_SMALL, TEXT_BRIGHT)
	num_lbl.custom_minimum_size = Vector2(28, 0)
	num_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(num_lbl)

	_need_bars[field] = {"bar": bar, "label": num_lbl}


func _make_work_hint() -> Label:
	var l := _make_label(
		"Uncheck to stop this pawn claiming that job type. Eating & hauling always allowed.",
		FONT_SMALL,
		Color(0.55, 0.56, 0.62)
	)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _add_work_checkbox(field: String, label_text: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	_root_vbox.add_child(row)
	var cb := CheckBox.new()
	cb.text = label_text
	cb.add_theme_font_size_override("font_size", FONT_SMALL)
	cb.add_theme_color_override("font_color", TEXT_BRIGHT)
	# Tighter hit target than default for this dense panel.
	cb.custom_minimum_size = Vector2(0, 18)
	var f := field
	cb.toggled.connect(func(pressed: bool): _on_work_toggled(f, pressed))
	row.add_child(cb)
	_work_checkboxes[field] = cb


func _on_work_toggled(field: String, pressed: bool) -> void:
	if _pawn == null or not is_instance_valid(_pawn) or _pawn.data == null:
		return
	var d: PawnData = _pawn.data
	match field:
		"work_forage":
			d.work_forage = pressed
		"work_mine":
			d.work_mine = pressed
		"work_chop":
			d.work_chop = pressed
		"work_hunt":
			d.work_hunt = pressed
		"work_build":
			d.work_build = pressed


static func _read_work_field(d: PawnData, field: String) -> bool:
	match field:
		"work_forage":
			return d.work_forage
		"work_mine":
			return d.work_mine
		"work_chop":
			return d.work_chop
		"work_hunt":
			return d.work_hunt
		"work_build":
			return d.work_build
	return true


func _add_skill_row(label_text: String, skill: int) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	_root_vbox.add_child(row)

	var name_lbl := _make_label(label_text, FONT_SMALL, TEXT_DIM)
	name_lbl.custom_minimum_size = Vector2(54, 0)
	row.add_child(name_lbl)

	var data_lbl := _make_label("0 (0/100)", FONT_SMALL, TEXT_BRIGHT)
	data_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(data_lbl)

	_skill_lines[skill] = data_lbl


func _make_section_header(text: String) -> Label:
	var l := _make_label(text.to_upper(), FONT_SMALL, ACCENT)
	# A little vertical breathing room above each section.
	l.add_theme_constant_override("line_spacing", 2)
	return l


func _make_label(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l


func _make_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_BG
	style.border_color = PANEL_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 4
	style.content_margin_right = 4
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	return style


func _portrait_cell_color(cell_idx: int, d: PawnData) -> Color:
	var n: int = PORTRAIT_COLS * PORTRAIT_ROWS
	if cell_idx < 0 or cell_idx >= n:
		return Color(0.08, 0.09, 0.11)
	var r: int = cell_idx / PORTRAIT_COLS
	var ccol: int = cell_idx % PORTRAIT_COLS
	var salt: float = float((d.id * 17 + r * 3 + ccol * 5) % 9) * 0.018
	if r < 2:
		return d.hair_color.lightened(salt)
	if r < 5:
		var sk: Color = d.color
		if ccol >= 2 and ccol <= 3 and r >= 3:
			return sk.darkened(0.1 + salt)
		return sk.lightened(salt * 0.45)
	return d.apparel_color.darkened(salt * 0.7)


func _refresh_portrait_strip(d: PawnData) -> void:
	var i: int = 0
	for c in _portrait_cells:
		if not (c is ColorRect):
			continue
		(c as ColorRect).color = _portrait_cell_color(i, d)
		i += 1


func _reposition() -> void:
	if _panel == null:
		return
	# Anchor top-right with a small inset, just inside the viewport edge.
	var view: Vector2 = get_viewport().get_visible_rect().size
	var size: Vector2 = _panel.get_combined_minimum_size()
	# Force the configured width regardless of label intrinsic widths.
	size.x = max(size.x, PANEL_WIDTH)
	_panel.position = Vector2(view.x - size.x - RIGHT_INSET, TOP_INSET)
	_panel.size = size


func _set_visible(v: bool) -> void:
	if _panel == null:
		return
	_panel.visible = v


# ==================== refresh ====================

func _process(delta: float) -> void:
	if _pawn == null:
		return
	# If the pawn was removed (e.g. world reroll wiped it), drop the binding
	# silently so we don't keep poking a freed object.
	if not is_instance_valid(_pawn):
		_pawn = null
		_set_visible(false)
		_last_ui_signature = ""
		return
	_poll_accum_sec += delta
	if _poll_accum_sec < UI_POLL_INTERVAL_SEC:
		return
	_poll_accum_sec = 0.0
	var sig: String = _build_ui_signature()
	if sig == _last_ui_signature:
		return
	_last_ui_signature = sig
	_refresh()


func _refresh() -> void:
	if _pawn == null or _pawn.data == null:
		return
	var d: PawnData = _pawn.data
	_title_label.text = "%s (age %.1f)" % [d.display_name, d.age]
	if _subtitle_label != null:
		var prof: String = d.profession_name()
		var hk: String = d.highest_affinity_skill()
		var arc_bits: String = "children %d" % int(d.children_count)
		if prof == "None":
			_subtitle_label.text = "%s · no prof · bias %s" % [arc_bits, hk]
		else:
			_subtitle_label.text = "%s · %s · bias %s" % [arc_bits, prof, hk]
		_refresh_portrait_strip(d)

	# Update tier indicator from ProgressionSystem
	if _tier_bar != null and _tier_label != null:
		if Engine.has_singleton("ProgressionSystem") or get_node_or_null("/root/ProgressionSystem") != null:
			var prog_sys = get_node_or_null("/root/ProgressionSystem")
			if prog_sys and prog_sys.has_method("get_tier_name"):
				var tier_name: String = prog_sys.get_tier_name(int(d.id))
				var tier: int = prog_sys.get_tier(int(d.id)) if prog_sys.has_method("get_tier") else 0
				var impact: int = prog_sys.get_impact(int(d.id)) if prog_sys.has_method("get_impact") else 0
				_tier_label.text = tier_name
				_tier_bar.value = float(impact)
				# Color based on tier
				var tier_color: Color = _tier_color(tier)
				var tier_fill := StyleBoxFlat.new()
				tier_fill.bg_color = tier_color
				tier_fill.set_corner_radius_all(2)
				_tier_bar.add_theme_stylebox_override("fill", tier_fill)
			else:
				_tier_label.text = "Unknown"
				_tier_bar.value = 0.0
		else:
			_tier_label.text = "Unknown"
			_tier_bar.value = 0.0
	
	_state_label.text = _pawn.describe_state()
	
	# Identity tab updates
	if _traits_label != null:
		_traits_label.text = "Traits: %s" % d.traits_display()
	if _lineage_label != null:
		_lineage_label.text = _lineage_block(d)
	if _simple_lineage_label != null:
		var parent_name: String = "Unknown"
		if d.parent_a_id >= 0:
			var parent_pd = d._get_parent_data(d.parent_a_id)
			if parent_pd != null:
				parent_name = parent_pd.display_name
		
		var household_info: String = "None"
		if d.household_id >= 0:
			household_info = "Household #" + str(d.household_id)
		
		_simple_lineage_label.text = "Born: " + parent_name + " | " + household_info
	if _appearance_label != null:
		_appearance_label.text = "Appearance: %s, %s" % [_body_type_label(d.body_type), _hair_style_label(d.hair_style)]
	if _liking_label != null:
		_liking_label.text = d.profession_liking_digest_line()
	if _coach_label != null:
		var hints: PackedStringArray = d.progression_coach_lines(3)
		_coach_label.text = "\n".join(hints)
	if _identity_label != null:
		_identity_label.text = _build_identity_strip(d)
	if _settlement_label != null:
		_settlement_label.text = _build_settlement_line(d)
	
	# Needs tab updates
	for field in _need_bars:
		var entry: Dictionary = _need_bars[field]
		var v: float = float(d.get(field))
		entry.bar.value = clampf(v, 0.0, 100.0)
		entry.label.text = "%d" % int(round(v))

	# Matrix tab updates — explicit if/then policy (see PawnDecisionRuleMatrix)
	# DEBUG ONLY: Hidden in release builds
	if OS.is_debug_build() and _matrix_inputs_label != null:
		var matrix_lines: PackedStringArray = []
		matrix_lines.append("[b]If / then matrix[/b] (colony + body + bonds + permissions)")
		if WorldAI != null and WorldAI.has_method("get_pawn_neural_state"):
			var ns: Dictionary = WorldAI.get_pawn_neural_state(int(d.id))
			var rules_v: Variant = ns.get("decision_rules", [])
			if rules_v is Array and (rules_v as Array).size() > 0:
				var ri: int = 0
				for r in (rules_v as Array):
					if ri >= 18:
						matrix_lines.append("…")
						break
					if r is Dictionary:
						matrix_lines.append("• %s" % str((r as Dictionary).get("line", "")))
					ri += 1
			else:
				matrix_lines.append("[i]No rules firing (neutral context or missing neural slice).[/i]")
			var dctx_v: Variant = ns.get("decision_ctx", {})
			if dctx_v is Dictionary and not (dctx_v as Dictionary).is_empty():
				var dc: Dictionary = dctx_v as Dictionary
				matrix_lines.append("")
				matrix_lines.append("[b]Context snapshot[/b]")
				matrix_lines.append(
						"food stock %d · pressure %.2f · founding %.2f · settlement %d" % [
							int(dc.get("food_stockpile_units", 0)),
							float(dc.get("food_pressure", 0.0)),
							float(dc.get("founding_blend", 0.0)),
							int(dc.get("settlement_id", -1)),
						]
				)
				matrix_lines.append(
						"rapport %d · opinion %+d · scars %d · crisis %.2f" % [
							int(dc.get("top_rapport_score", 0)),
							int(dc.get("top_opinion_score", 0)),
							int(dc.get("scar_count", 0)),
							float(dc.get("crisis_level", 0.0)),
						]
				)
				matrix_lines.append(
						"weather %s · danger hint %.2f" % [
							str(dc.get("weather_tag", "?")),
							float(dc.get("danger_level_hint", 0.0)),
						]
				)
			var hcv: Variant = ns.get("human_channels", [])
			var hcl_v: Variant = ns.get("human_channel_labels", [])
			if hcv is Array and (hcv as Array).size() > 0:
				matrix_lines.append("")
				matrix_lines.append("[b]12 intent channels[/b] (NPC / player parity stack)")
				var labels_arr: Array = hcl_v as Array if hcl_v is Array else []
				for hi in range(mini((hcv as Array).size(), 12)):
					var lab: String = "#%d" % hi
					if hi < labels_arr.size():
						lab = str(labels_arr[hi])
					matrix_lines.append("  %s: %.3f" % [lab, float((hcv as Array)[hi])])
		else:
			matrix_lines.append("[i]WorldAI not available[/i]")
		matrix_lines.append("")
		matrix_lines.append("[b]Neural input digest[/b]")
		matrix_lines.append(
				"H %.0f  R %.0f  M %.0f  health %.0f" % [d.hunger, d.rest, d.mood, d.health]
		)
		for ak in ["combat", "farming", "building", "crafting", "diplomacy"]:
			matrix_lines.append("  %s: %.2f" % [ak, d.affinities.get(ak, 0.5)])
		_matrix_inputs_label.text = "\n".join(matrix_lines)

	# Neural tab updates (DEBUG ONLY - hidden in release builds)
	if OS.is_debug_build():
		if _neural_bias_label != null:
			var bias: String = d.highest_affinity_skill()
			_neural_bias_label.text = "Current Bias: %s" % bias
		
		if _neural_outputs_label != null:
			var neural_lines: PackedStringArray = []
			neural_lines.append("[b]Neural Outputs:[/b]")
			neural_lines.append("[color=#8a8a95]forward → if/then matrix → scar & site nudge[/color]")
			if WorldAI != null and WorldAI.has_method("get_pawn_neural_state"):
				var neural_state: Dictionary = WorldAI.get_pawn_neural_state(int(d.id))
				if not neural_state.is_empty():
					var outputs: Array = neural_state.get("outputs", [])
					for i in range(outputs.size()):
						var out_val: float = float(outputs[i])
						var action_name: String = _neural_output_action_name(i)
						neural_lines.append("%s: %.3f" % [action_name, out_val])
				else:
					neural_lines.append("[i]No neural state available[/i]")
			else:
				neural_lines.append("[i]WorldAI not available[/i]")
			_neural_outputs_label.text = "\n".join(neural_lines)

	# Social tab updates
	if _social_label != null:
		var top_peer: Dictionary = d.top_social_rapport_peer()
		var pid: int = int(top_peer.get("peer_id", -1))
		var peer_disp: String = _peer_display_for_social(pid)
		var social_text: String = d.social_status_line(peer_disp)
		var top_op: Dictionary = d.top_character_opinion_peer()
		var opid: int = int(top_op.get("peer_id", -1))
		if opid >= 0:
			var opv: int = int(top_op.get("opinion", 0))
			social_text += "\nOpinion (CK-style): %s (%+d)" % [_peer_display_for_social(opid), opv]
		_social_label.text = social_text
	
	if _mood_status_label != null:
		var active_mood_event: MoodEvent = d.get_active_mood_event()
		if active_mood_event != null:
			_mood_status_label.text = "Mood: %s (%d event: %s)" % [
				d.mood_state_display(),
				int(d.mood),
				active_mood_event.description
			]
		else:
			_mood_status_label.text = "Mood: %s (%d)" % [d.mood_state_display(), int(d.mood)]
	
	if _crisis_level_label != null:
		var crisis: float = d.get_crisis_level()
		var crisis_text: String = "Crisis: "
		if crisis < 0.3:
			crisis_text += "Low"
		elif crisis < 0.6:
			crisis_text += "Moderate"
		elif crisis < 0.8:
			crisis_text += "HIGH"
		else:
			crisis_text += "CRITICAL"
		crisis_text += " (%.0f%%)" % (crisis * 100.0)
		_crisis_level_label.text = crisis_text

	if _hint_label != null:
		var esc: String = "[Esc] deselect"
		if _player_context_picker_visible:
			_hint_label.text = "Incarnation picker open · %s" % esc
		elif _player_context_mode_label == "INCARNATED" and _player_context_pawn_id >= 0:
			if int(d.id) == _player_context_pawn_id:
				_hint_label.text = "You are incarnated · %s · F9 realm · F10 → 35 · Backbone" % esc
			else:
				_hint_label.text = "Inspecting (your pawn #%d) · %s" % [_player_context_pawn_id, esc]
		else:
			_hint_label.text = "Observer/chronicler · %s · F9 · F10 → 35 · Backbone" % esc

	# Narrative tab updates (Phase 5: Emergent Narrative)
	var narrative_label: RichTextLabel = _tab_narrative.get_node_or_null("NarrativeLabel") as RichTextLabel
	if narrative_label != null:
		var narrative_text: String = _generate_pawn_narrative(_pawn)
		if narrative_text != "":
			# Convert emoji to bbcode colors for better readability
			var formatted: String = narrative_text.replace("📍", "[color=#FFD166]📍[/color]")
			formatted = formatted.replace("🎒", "[color=#57C5B6]🎒[/color]")
			formatted = formatted.replace("📜", "[color=#B084CC]📜[/color]")
			formatted = formatted.replace("🏠", "[color=#FF6B6B]🏠[/color]")
			narrative_label.text = formatted
		else:
			narrative_label.text = "[i]No narrative data available[/i]"

	# Reposition each tick because the panel can grow/shrink with carry text.
	_reposition()


func _pawn_spawner() -> PawnSpawner:
	var n: Node = Engine.get_main_loop().root.find_child("PawnSpawner", true, false)
	return n as PawnSpawner


func _neural_output_action_name(index: int) -> String:
	match index:
		0: return "Seek_Food"
		1: return "Seek_Rest"
		2: return "Seek_Social"
		3: return "Work_Forage"
		4: return "Work_Build"
		5: return "Work_Mine"
		6: return "Defend"
		7: return "Idle"
		_: return "Unknown"


## Live pawn name, else WorldMemory death / last-known (strongest bond can outlive the peer).
func _peer_display_for_social(pid: int) -> String:
	if pid < 0:
		return ""
	var spawner: PawnSpawner = _pawn_spawner()
	if spawner != null:
		var peer_data: PawnData = spawner.pawn_data_for_id(pid)
		if peer_data != null:
			var nm0: String = str(peer_data.display_name).strip_edges()
			if not nm0.is_empty():
				return nm0
	var fact: Dictionary = WorldMemory.pawn_death_fact(pid)
	if not fact.is_empty():
		var nm1: String = str(fact.get("n", "")).strip_edges()
		if not nm1.is_empty():
			return nm1
	var lk: String = WorldMemory.last_known_name_from_death_record(pid).strip_edges()
	if not lk.is_empty():
		return lk
	return ""


func _parent_line(pid: int) -> String:
	if pid < 0:
		return "—"
	var spawner: PawnSpawner = _pawn_spawner()
	if spawner != null:
		var pd: PawnData = spawner.pawn_data_for_id(pid)
		if pd != null:
			var nm: String = str(pd.display_name).strip_edges()
			if nm.is_empty():
				nm = "#%d" % pid
			var prof: String = pd.profession_name()
			if prof != "None":
				return "%s — %s" % [nm, prof]
			return nm
	var fact: Dictionary = WorldMemory.pawn_death_fact(pid)
	if not fact.is_empty():
		var nm2: String = str(fact.get("n", "")).strip_edges()
		if nm2.is_empty():
			nm2 = "#%d" % pid
		var line: String = "%s (#%d, departed)" % [nm2, pid]
		var prof_i: int = int(fact.get("prof", -1))
		var prof_l: String = PawnData.profession_label_from_enum(prof_i)
		if prof_i >= 0 and prof_l != "None":
			line += " — was %s" % prof_l
		return line
	var fallen: String = WorldMemory.last_known_name_from_death_record(pid)
	if not fallen.is_empty():
		return "%s (#%d, departed)" % [fallen, pid]
	return "#%d (record thin)" % pid


func _parent_profession_enum(pid: int) -> int:
	if pid < 0:
		return -1
	var spawner: PawnSpawner = _pawn_spawner()
	if spawner != null:
		var pd: PawnData = spawner.pawn_data_for_id(pid)
		if pd != null:
			return int(pd.current_profession)
	var fact: Dictionary = WorldMemory.pawn_death_fact(pid)
	if fact.is_empty():
		return -1
	return int(fact.get("prof", -1))


func _profession_inheritance_note(d: PawnData) -> String:
	if d.current_profession == PawnData.Profession.NONE:
		return ""
	var mine: int = int(d.current_profession)
	for lbl in ["A", "B"]:
		var pid: int = d.parent_a_id if lbl == "A" else d.parent_b_id
		if pid < 0:
			continue
		var pprof: int = _parent_profession_enum(pid)
		if pprof >= 0 and pprof == mine:
			return "Profession traces to parent %s (%s)." % [lbl, d.profession_name()]
	return ""


func _lineage_block(d: PawnData) -> String:
	var lines: PackedStringArray = PackedStringArray()
	if d.bloodline_id >= 0:
		var bloodline_line: String = "Bloodline: #%d" % d.bloodline_id
		if has_node("/root/BloodlineSystem"):
			var bloodline_sys: Node = get_node("/root/BloodlineSystem")
			if bloodline_sys != null and bloodline_sys.has_method("get_bloodline_info"):
				var info: Dictionary = bloodline_sys.call("get_bloodline_info", d.bloodline_id)
				if not info.is_empty():
					bloodline_line += " · founder %s · members %d · deaths %d" % [
						str(info.get("founder_name", "unknown")),
						int(info.get("living_members", 0)),
						int(info.get("historical_deaths", 0)),
					]
		lines.append(bloodline_line)
	if d.parent_a_id >= 0 or d.parent_b_id >= 0:
		lines.append("Parent A: %s" % _parent_line(d.parent_a_id))
		lines.append("Parent B: %s" % _parent_line(d.parent_b_id))
		if d.children_count > 0:
			lines.append("Children recorded: %d" % int(d.children_count))
	else:
		lines.append("Founding generation (no recorded parents).")
	var prof: String = d.profession_name()
	if prof != "None":
		lines.append("Profession: %s (progress %d)" % [prof, d.profession_progress_xp()])
	else:
		var prog: int = d.profession_progress_xp()
		if prog > 0:
			lines.append(
				"Profession: not locked — action skills toward first lock (%d/100 on leading track)" % prog
			)
	var inh: String = _profession_inheritance_note(d)
	if not inh.is_empty():
		lines.append(inh)
	return "\n".join(lines)


func _build_identity_strip(d: PawnData) -> String:
	var rk: int = _WM._region_key(d.tile_pos.x, d.tile_pos.y)
	var meaning_label: String = str(WorldMeaning.get_region_meaning_label(rk)).replace("_", " ")
	var rep: int = int(CulturalMemory.get_region_reputation(rk))
	var rep_word: String = "neutral"
	if rep <= -3:
		rep_word = "dreaded"
	elif rep <= -2:
		rep_word = "feared"
	elif rep == -1:
		rep_word = "scarred"
	elif rep >= 1:
		rep_word = "respected"
	var profile: Dictionary = SettlementMemory.get_settlement_profile(rk)
	var st_state: String = str(profile.get("state", "wild")).replace("_", " ")
	var culture_name: String = str(profile.get("culture_name", "cautious")).replace("_", " ")
	var rev_score: int = int(profile.get("revival_score", 0))
	var center: int = int(profile.get("center_region", -1))
	var st_any: Variant = SettlementMemory.get_settlement_at_region(rk)
	var intent: String = "none"
	if st_any is Dictionary:
		intent = str((st_any as Dictionary).get("current_intent", "none")).to_lower()
	var war: Dictionary = SettlementMemory.get_war_profile_for_region(rk)
	var war_state: String = str(war.get("state", "peace")).replace("_", " ")
	var gov: Dictionary = SettlementMemory.get_governance_profile_for_region(rk)
	var gov_type: String = str(gov.get("type", "anarchy")).replace("_", " ")
	return (
		"Region #%d · meaning: %s · reputation: %s (%d)\n"
		+ "Settlement: %s · culture: %s · intent: %s · revival %d\n"
		+ "Order: %s · governance: %s · center: %d"
	) % [rk, meaning_label, rep_word, rep, st_state, culture_name, intent, rev_score, war_state, gov_type, center]


func _build_settlement_line(d: PawnData) -> String:
	var sid: int = int(d.settlement_id)
	if sid < 0:
		return "Unaffiliated — no settlement bond recorded."
	var all_settlements: Array = SettlementMemory.get_settlements()
	if sid >= all_settlements.size():
		return "Affiliation stale — settlement #%d no longer exists." % sid
	var st: Dictionary = all_settlements[sid] as Dictionary
	var state: String = str(st.get("state", "unknown")).replace("_", " ")
	var culture: String = str(st.get("culture_name", "unknown")).replace("_", " ")
	var center_rk: int = int(st.get("center_region", -1))
	var region_count: int = 0
	var reg_v: Variant = st.get("regions", null)
	if reg_v is PackedInt32Array:
		region_count = (reg_v as PackedInt32Array).size()
	var revival: int = int(st.get("revival_score", 0))
	var members: int = _count_settlement_members(sid)
	var intent: String = "none"
	var war: Dictionary = SettlementMemory.get_war_profile_for_region(center_rk)
	if war != null and not war.is_empty():
		war = war
	else:
		war = {}
	var war_state: String = str(war.get("state", "peace")).replace("_", " ")
	var gov: Dictionary = SettlementMemory.get_governance_profile_for_region(center_rk)
	var gov_type: String = str(gov.get("type", "anarchy")).replace("_", " ")
	return (
		"Settlement #%d · %d regions · center #%d\n"
		+ "State: %s · culture: %s · revival: %d\n"
		+ "Members: %d · intent: %s · war: %s\n"
		+ "Governance: %s"
	) % [sid, region_count, center_rk, state, culture, revival, members, intent, war_state, gov_type]


func _count_settlement_members(settlement_idx: int) -> int:
	var count: int = 0
	var spawner: PawnSpawner = _pawn_spawner()
	if spawner == null:
		return count
	for pd in spawner.all_pawn_data():
		if pd is PawnData and int(pd.settlement_id) == settlement_idx:
			count += 1
	return count


func _build_ui_signature() -> String:
	if _pawn == null or not is_instance_valid(_pawn) or _pawn.data == null:
		return ""
	var d: PawnData = _pawn.data
	var rk: int = _WM._region_key(d.tile_pos.x, d.tile_pos.y)
	var top_peer: Dictionary = d.top_social_rapport_peer()
	var world_context_bucket: int = int(GameManager.tick_count / max(1, WORLD_CONTEXT_REFRESH_TICKS))
	var mood_sig: int = 0
	var me: MoodEvent = d.get_active_mood_event()
	if me != null:
		mood_sig = hash(str(me.description))
	# Must match argument count exactly — mismatch spams errors every UI poll.
	return (
		"%d|%d|%d|%d|%s|%s|%d|%d|%d|%d|%d|%d|%s|%s|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d"
	) % [
		d.id,
		d.age,
		d.tile_pos.x,
		d.tile_pos.y,
		d.display_name,
		_pawn.describe_state(),
		int(round(d.hunger)),
		int(round(d.rest)),
		int(round(d.mood)),
		int(round(d.health)),
		int(d.current_profession),
		int(d.profession_progress_xp()),
		str(d.carrying),
		str(d.carrying_qty),
		rk,
		world_context_bucket,
		int(top_peer.get("peer_id", -1)),
		int(top_peer.get("rapport", 0)),
		int(d.skills.get("combat", 0)),
		int(d.skills.get("gathering", 0)),
		int(d.skills.get("building", 0)),
		int(d.skills.get("farming", 0)),
		int(d.skills.get("movement", 0)),
		int(d.children_count),
		int(hash(str(d.traits_display()))),
		int(round(d.get_crisis_level() * 100.0)),
		mood_sig,
		int(d.settlement_id),
	]


static func _body_type_label(body_type: int) -> String:
	match body_type:
		PawnData.BodyType.SLIM:
			return "Slim"
		PawnData.BodyType.BROAD:
			return "Broad"
		_:
			return "Average"


static func _hair_style_label(hair_style: int) -> String:
	match hair_style:
		PawnData.HairStyle.NONE:
			return "No hair"
		PawnData.HairStyle.MOHAWK:
			return "Mohawk"
		PawnData.HairStyle.BUN:
			return "Bun"
		_:
			return "Short hair"

## Calculate tier (1-5) from pawn level. Each tier spans 5 levels.
static func _level_to_tier(level: int) -> int:
	return clampi((level - 1) / 5 + 1, 1, 5)

## Calculate progress (0-100) within current tier.
static func _tier_progress(level: int) -> float:
	var tier_start: int = (_level_to_tier(level) - 1) * 5 + 1
	return float(level - tier_start) / 4.0 * 100.0

## Get tier color (golden for higher tiers).
static func _tier_color(tier: int) -> Color:
	match tier:
		1: return Color8(180, 180, 180)  # Gray
		2: return Color8(76, 175, 80)    # Green
		3: return Color8(33, 150, 243)    # Blue
		4: return Color8(156, 39, 176)    # Purple
		5: return Color8(255, 193, 7)     # Gold
		_: return Color8(180, 180, 180)


# ==================== NARRATIVE SYSTEM (Phase 5: Emergent Narrative) ====================

## Generate Dwarf Fortress-style narrative text for a pawn based on their current state and history.
func _generate_pawn_narrative(pawn: Pawn) -> String:
	if pawn == null or not is_instance_valid(pawn) or pawn.data == null:
		return ""
	
	var d: PawnData = pawn.data
	var text: String = ""
	
	# Current activity with location
	text += "📍 Currently: " + _get_activity_description(pawn) + "\n"
	
	# Carrying status
	if d.carrying != Item.Type.NONE and d.carrying_qty > 0:
		var item_name: String = _get_item_name(d.carrying)
		text += "🎒 Carrying: %d %s" % [d.carrying_qty, item_name]
		if d.carrying_qty > 1:
			text += "s"
		# Check if hauling to stockpile
		if pawn._state == Pawn.State.HAULING or pawn._state == Pawn.State.FETCHING_MATERIAL:
			text += " → heading to stockpile"
		text += "\n"
	
	# Recent history (last 3-5 events)
	var events: Array[Dictionary] = _get_pawn_events(d.id, 5)
	if not events.is_empty():
		text += "📜 Recent History:\n"
		for ev in events:
			var event_text: String = _format_event(ev)
			if event_text != "":
				text += "   • " + event_text + "\n"
	
	# Settlement home
	if d.settlement_id >= 0:
		var settlement_name: String = _get_settlement_name(d.settlement_id)
		if settlement_name != "":
			text += "🏠 Home: %s\n" % settlement_name
	
	return text


## Get human-readable activity description from pawn state.
func _get_activity_description(pawn: Pawn) -> String:
	if pawn == null or not is_instance_valid(pawn) or pawn.data == null:
		return "Unknown"
	
	var d: PawnData = pawn.data
	var state: int = pawn._state
	var job: Job = pawn._current_job
	
	match state:
		Pawn.State.IDLE:
			return "Idle at %s" % _format_tile_pos(d.tile_pos)
		
		Pawn.State.WALKING_TO_JOB, Pawn.State.FETCHING_MATERIAL:
			if job != null:
				var job_type: String = Job.describe_type(job.type).to_lower()
				return "%sing at %s" % [job_type.capitalize().left(-1), _format_tile_pos(job.work_tile)]
			return "Walking to work"
		
		Pawn.State.WORKING:
			if job != null:
				var job_type: String = Job.describe_type(job.type)
				return "%s at %s" % [job_type, _format_tile_pos(job.work_tile)]
			return "Working"
		
		Pawn.State.HAULING:
			return "Hauling to stockpile"
		
		Pawn.State.GOING_TO_EAT:
			return "Going to eat at stockpile"
		
		Pawn.State.EATING:
			return "Eating at stockpile"
		
		Pawn.State.GOING_TO_BED:
			return "Going to bed"
		
		Pawn.State.SLEEPING:
			return "Sleeping"
		
		Pawn.State.DRAFT_WALK:
			if job != null:
				return "Moving to %s (drafted)" % _format_tile_pos(job.work_tile)
			return "Moving (drafted)"
		
		Pawn.State.TEACHING:
			return "Teaching nearby"
		
		Pawn.State.CHALLENGE:
			return "Challenging authority"
		
		Pawn.State.GATHERING:
			return "Gathering items at %s" % _format_tile_pos(d.tile_pos)
		
		Pawn.State.CRAFTING:
			return "Crafting at %s" % _format_tile_pos(d.tile_pos)
		
		Pawn.State.FLEEING:
			return "Fleeing from danger!"
		
		Pawn.State.HIDING:
			return "Hiding from threats"
		
		_:
			return "Unknown activity"


## Get item name from Item.Type enum.
func _get_item_name(item_type: int) -> String:
	match item_type:
		Item.Type.BERRY:
			return "berry"
		Item.Type.MEAT:
			return "meat"
		Item.Type.WOOD:
			return "wood"
		Item.Type.STONE:
			return "stone"
		Item.Type.FLINT:
			return "flint"
		Item.Type.STICK:
			return "stick"
		Item.Type.FLINT_KNIFE:
			return "flint knife"
		Item.Type.FLINT_PICK:
			return "flint pick"
		Item.Type.WOODEN_SPEAR:
			return "wooden spear"
		Item.Type.TORCH:
			return "torch"
		Item.Type.COOKED_MEAT:
			return "cooked meat"
		Item.Type.COOKED_BERRIES:
			return "cooked berries"
		Item.Type.DRIED_MEAT:
			return "dried meat"
		_:
			return "item"


## Get recent events for a specific pawn from WorldMemory.
func _get_pawn_events(pawn_id: int, count: int) -> Array[Dictionary]:
	if WorldMemory == null:
		return []
	
	var all_events: Array[Dictionary] = WorldMemory.get_events()
	var pawn_events: Array[Dictionary] = []
	
	# Search backwards from most recent events
	for i in range(all_events.size() - 1, -1, -1):
		if pawn_events.size() >= count:
			break
		
		var ev: Dictionary = all_events[i]
		var ev_pawn_id: int = int(ev.get("pawn_id", ev.get("pid", -1)))
		
		if ev_pawn_id == pawn_id:
			pawn_events.append(ev)
	
	return pawn_events


## Format a WorldMemory event into readable text.
func _format_event(ev: Dictionary) -> String:
	var event_type: String = str(ev.get("type", "unknown"))
	var tick: int = int(ev.get("t", 0))
	var ticks_ago: int = GameManager.tick_count - tick
	
	# Convert ticks to human-readable time
	var time_str: String = ""
	if ticks_ago < 60:
		time_str = "%d ticks ago" % ticks_ago
	elif ticks_ago < 3600:
		time_str = "%d min ago" % int(ticks_ago / 60)
	else:
		time_str = "%d hr ago" % int(ticks_ago / 3600)
	
	match event_type:
		"work_event":
			var job_type: String = str(ev.get("job_type", "work")).to_lower()
			var tile_data: Variant = ev.get("tile", {})
			var tile_str: String = ""
			if tile_data is Dictionary:
				tile_str = " at (%d,%d)" % [int(tile_data.get("x", 0)), int(tile_data.get("y", 0))]
			return "Completed %s%s (%s)" % [job_type, tile_str, time_str]
		
		"pawn_death":
			var cause: String = str(ev.get("cause", "unknown"))
			return "Died: %s (%s)" % [cause, time_str]
		
		"birth":
			return "Born (%s)" % time_str
		
		"teaching_event":
			var skill: String = str(ev.get("skill", "skill"))
			return "Taught %s (%s)" % [skill, time_str]
		
		"social_meeting":
			var other_name: String = str(ev.get("other_name", "someone"))
			return "Met %s (%s)" % [other_name, time_str]
		
		"social_bond_milestone":
			var milestone: int = int(ev.get("milestone", 0))
			return "Friendship milestone (%s)" % time_str
		
		"knowledge_acquisition":
			var knowledge: String = str(ev.get("knowledge_type", "knowledge"))
			return "Learned %s (%s)" % [knowledge, time_str]
		
		"knowledge_inscribed":
			var carrier_type: String = str(ev.get("carrier_type", "stone"))
			return "Inscribed %s (%s)" % [carrier_type, time_str]
		
		"knowledge_read":
			var gained_count: int = int(ev.get("gained_knowledge", []).size())
			return "Read stone, gained %d knowledge (%s)" % [gained_count, time_str]
		
		_:
			return "%s (%s)" % [event_type.capitalize(), time_str]


## Format tile position as readable string.
func _format_tile_pos(tile: Vector2i) -> String:
	return "(%d,%d)" % [tile.x, tile.y]


## Get settlement name from settlement_id.
func _get_settlement_name(settlement_id: int) -> String:
	if SettlementMemory == null or settlement_id < 0:
		return ""
	
	var settlements: Array = SettlementMemory.settlements
	if settlement_id >= settlements.size():
		return ""
	
	var st: Variant = settlements[settlement_id]
	if st is Dictionary:
		return str(st.get("culture_name", "Unnamed Settlement"))
	
	return "Settlement %d" % settlement_id


## Get pawn spawner reference.
func _pawn_spawner() -> PawnSpawner:
	var main_node: Node = get_node_or_null("/root/Main")
	if main_node == null:
		return null
	return main_node.get_node_or_null("WorldViewport/PawnSpawner") as PawnSpawner
