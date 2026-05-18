class_name PawnInfoPanel
extends CanvasLayer

## Right-side **Heelkawnian** sheet (embodied citizen: NPC or player incarnation).
## Same `HeelKawnian` / `HeelKawnianData` surface for parity. Chunky portrait reads
## from [HeelKawnianData] colors; coach lines are deterministic from likings + skills.
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
const EXPENSIVE_DETAILS_REFRESH_SEC: float = 0.75
const HIGH_SPEED_EXPENSIVE_DETAILS_REFRESH_SEC: float = 1.5
## Settlement/governance identity is allowed to refresh on a coarse tick bucket
## instead of every UI poll. This keeps observer mode smooth while preserving
## living-world updates in the sheet.
const WORLD_CONTEXT_REFRESH_TICKS: int = 30
const PORTRAIT_COLS:  int = 6
const PORTRAIT_ROWS:  int = 8

const NEED_BARS: Array = [
	# (label, accessor name on HeelKawnianData, color)
	{"label": "Hunger", "field": "hunger", "color": Color8(230, 130, 100)},
	{"label": "Rest",   "field": "rest",   "color": Color8(140, 170, 235)},
	{"label": "Mood",   "field": "mood",   "color": Color8(180, 220, 130)},
	{"label": "Health", "field": "health", "color": Color8(220, 220, 220)},
]

const SKILLS_ORDER: Array = [
	# (label, HeelKawnianData.Skill enum value)
	{"label": "Foraging", "skill": 0},
	{"label": "Mining",   "skill": 1},
	{"label": "Chopping", "skill": 2},
	{"label": "Building", "skill": 3},
	{"label": "Hunting",  "skill": 4},
]

## (field on HeelKawnianData, checkbox label) — maps queue job categories to human text.
const WORK_CHECKS: Array = [
	{"field": "work_forage", "text": "Forage / gather"},
	{"field": "work_fish",   "text": "Fish"},
	{"field": "work_mine",   "text": "Mine / tunnel"},
	{"field": "work_chop",   "text": "Chop wood"},
	{"field": "work_hunt",   "text": "Hunt animals"},
	{"field": "work_build",  "text": "Build (bed/wall/door)"},
	{"field": "work_guard",  "text": "Guard prisoners"},
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
## field name (e.g. "work_mine") -> CheckBox, kept in sync from HeelKawnianData.
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
var _tab_consciousness: VBoxContainer = null  # Phase 5: HeelKawnian Consciousness
var _tab_gear: VBoxContainer = null  # Equipment System
var _tab_talk: VBoxContainer = null  # Conversational AI
## Talk tab UI elements
var _talk_greeting: RichTextLabel = null
var _talk_output: RichTextLabel = null
var _talk_input: LineEdit = null
## Matrix/Neural display labels
var _matrix_inputs_label: RichTextLabel = null
var _neural_outputs_label: RichTextLabel = null
var _neural_bias_label: Label = null

var _pawn: HeelKawnian = null
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
var _likes_dislikes_label: Label = null
var _gear_labels: Dictionary = {}  # slot index -> Label
var _gear_stats_label: Label = null
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
var _expensive_poll_accum_sec: float = HIGH_SPEED_EXPENSIVE_DETAILS_REFRESH_SEC
var _last_expensive_signature: String = ""
var _expensive_dirty: bool = true
var _last_gear_signature: String = ""


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
func bind_pawn(p: HeelKawnian) -> void:
	_pawn = p
	if _pawn == null:
		_set_visible(false)
		_last_ui_signature = ""
		_reset_expensive_detail_cache()
		return
	if _overlay_suppressed:
		_set_visible(false)
	else:
		_set_visible(true)
	_poll_accum_sec = UI_POLL_INTERVAL_SEC
	_last_ui_signature = ""
	_expensive_poll_accum_sec = _expensive_refresh_interval()
	_expensive_dirty = true
	_refresh(true)


func set_player_context(mode_label: String, player_pawn_id: int, picker_visible: bool) -> void:
	var next_mode: String = mode_label if not mode_label.is_empty() else "SPECTATOR"
	if _player_context_mode_label == next_mode and _player_context_pawn_id == player_pawn_id and _player_context_picker_visible == picker_visible:
		return
	_player_context_mode_label = next_mode
	_player_context_pawn_id = player_pawn_id
	_player_context_picker_visible = picker_visible
	if _pawn != null and is_instance_valid(_pawn):
		_expensive_dirty = true
		_refresh(true)


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

	# Consciousness tab (Phase 5: HeelKawnian Consciousness)
	_tab_consciousness = VBoxContainer.new()
	_tab_consciousness.add_theme_constant_override("separation", 2)
	_tab_container.add_child(_tab_consciousness)
	_populate_consciousness_tab()

	# Gear tab (Equipment System)
	_tab_gear = VBoxContainer.new()
	_tab_gear.add_theme_constant_override("separation", 2)
	_tab_container.add_child(_tab_gear)
	_populate_gear_tab()

	# Talk tab (Conversational AI — talk to HeelKawnians)
	_tab_talk = VBoxContainer.new()
	_tab_talk.add_theme_constant_override("separation", 2)
	_tab_container.add_child(_tab_talk)
	_populate_talk_tab()

	# Set tab titles
	_tab_container.set_tab_title(0, "ID")
	_tab_container.set_tab_title(1, "Needs")
	if OS.is_debug_build():
		_tab_container.set_tab_title(2, "Matrix")
		_tab_container.set_tab_title(3, "Neural")
		_tab_container.set_tab_title(4, "Social")
		_tab_container.set_tab_title(5, "Narrative")
		_tab_container.set_tab_title(6, "Mind")
		_tab_container.set_tab_title(7, "Gear")
		_tab_container.set_tab_title(8, "Talk")
	else:
		_tab_container.set_tab_title(2, "Social")
		_tab_container.set_tab_title(3, "Narrative")
		_tab_container.set_tab_title(4, "Mind")
		_tab_container.set_tab_title(5, "Gear")
		_tab_container.set_tab_title(6, "Talk")

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

	_tab_identity.add_child(_make_section_header("Likes / Dislikes"))
	_likes_dislikes_label = _make_label("", FONT_SMALL, TEXT_DIM)
	_likes_dislikes_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tab_identity.add_child(_likes_dislikes_label)

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
	# bbcode_enabled disabled for runtime stability
	# _matrix_inputs_label.bbcode_enabled = true
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
	# bbcode_enabled disabled for runtime stability
	# _neural_outputs_label.bbcode_enabled = true
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
	# bbcode_enabled disabled for runtime stability
	# narrative_label.bbcode_enabled = true
	narrative_label.fit_content = true
	narrative_label.scroll_active = true
	narrative_label.custom_minimum_size = Vector2(0, 280)
	narrative_label.add_theme_font_size_override("normal_font_size", FONT_BODY)
	_tab_narrative.add_child(narrative_label)


func _populate_consciousness_tab() -> void:
	# === MIND SNAPSHOT (HeelKawnianMind) — composed readable state ===
	_tab_consciousness.add_child(_make_section_header("Mind"))

	var thought_label: Label = _make_label("", FONT_BODY, ACCENT)
	thought_label.name = "MindThought"
	thought_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tab_consciousness.add_child(thought_label)

	var pursuit_row: HBoxContainer = HBoxContainer.new()
	_tab_consciousness.add_child(pursuit_row)
	pursuit_row.add_child(_make_label("Pursuit: ", FONT_SMALL, TEXT_DIM))
	var pursuit_val: Label = _make_label("", FONT_SMALL, TEXT_BRIGHT)
	pursuit_val.name = "MindPursuit"
	pursuit_row.add_child(pursuit_val)

	var body_row: HBoxContainer = HBoxContainer.new()
	_tab_consciousness.add_child(body_row)
	body_row.add_child(_make_label("Body: ", FONT_SMALL, TEXT_DIM))
	var body_val: Label = _make_label("", FONT_SMALL, Color8(230, 180, 140))
	body_val.name = "MindBody"
	body_row.add_child(body_val)

	var emotion_row: HBoxContainer = HBoxContainer.new()
	_tab_consciousness.add_child(emotion_row)
	emotion_row.add_child(_make_label("Emotion: ", FONT_SMALL, TEXT_DIM))
	var emotion_val: Label = _make_label("", FONT_SMALL, Color8(180, 200, 230))
	emotion_val.name = "MindEmotion"
	emotion_row.add_child(emotion_val)

	var likes_row: HBoxContainer = HBoxContainer.new()
	_tab_consciousness.add_child(likes_row)
	likes_row.add_child(_make_label("Likes: ", FONT_SMALL, TEXT_DIM))
	var likes_val: Label = _make_label("", FONT_SMALL, Color8(140, 220, 140))
	likes_val.name = "MindLikes"
	likes_val.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	likes_row.add_child(likes_val)

	var dislikes_row: HBoxContainer = HBoxContainer.new()
	_tab_consciousness.add_child(dislikes_row)
	dislikes_row.add_child(_make_label("Dislikes: ", FONT_SMALL, TEXT_DIM))
	var dislikes_val: Label = _make_label("", FONT_SMALL, Color8(220, 140, 140))
	dislikes_val.name = "MindDislikes"
	dislikes_val.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dislikes_row.add_child(dislikes_val)

	var family_row: HBoxContainer = HBoxContainer.new()
	_tab_consciousness.add_child(family_row)
	family_row.add_child(_make_label("Family: ", FONT_SMALL, TEXT_DIM))
	var family_val: Label = _make_label("", FONT_SMALL, TEXT_BRIGHT)
	family_val.name = "MindFamily"
	family_val.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	family_row.add_child(family_val)

	var rel_row: HBoxContainer = HBoxContainer.new()
	_tab_consciousness.add_child(rel_row)
	rel_row.add_child(_make_label("Bonds: ", FONT_SMALL, TEXT_DIM))
	var rel_val: Label = _make_label("", FONT_SMALL, TEXT_BRIGHT)
	rel_val.name = "MindRelationships"
	rel_val.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rel_row.add_child(rel_val)

	var memory_row: HBoxContainer = HBoxContainer.new()
	_tab_consciousness.add_child(memory_row)
	memory_row.add_child(_make_label("Memory: ", FONT_SMALL, TEXT_DIM))
	var memory_val: Label = _make_label("", FONT_SMALL, Color8(200, 180, 220))
	memory_val.name = "MindMemory"
	memory_val.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	memory_row.add_child(memory_val)

	var culture_row: HBoxContainer = HBoxContainer.new()
	_tab_consciousness.add_child(culture_row)
	culture_row.add_child(_make_label("Culture: ", FONT_SMALL, TEXT_DIM))
	var culture_val: Label = _make_label("", FONT_SMALL, Color8(200, 200, 160))
	culture_val.name = "MindCulture"
	culture_val.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	culture_row.add_child(culture_val)

	var work_row: HBoxContainer = HBoxContainer.new()
	_tab_consciousness.add_child(work_row)
	work_row.add_child(_make_label("Work: ", FONT_SMALL, TEXT_DIM))
	var work_val: Label = _make_label("", FONT_SMALL, TEXT_BRIGHT)
	work_val.name = "MindWork"
	work_row.add_child(work_val)

	var reason_row: HBoxContainer = HBoxContainer.new()
	_tab_consciousness.add_child(reason_row)
	reason_row.add_child(_make_label("Reason: ", FONT_SMALL, TEXT_DIM))
	var reason_val: Label = _make_label("", FONT_SMALL, Color8(160, 160, 170))
	reason_val.name = "MindReason"
	reason_val.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reason_row.add_child(reason_val)

	var knowledge_row: HBoxContainer = HBoxContainer.new()
	_tab_consciousness.add_child(knowledge_row)
	knowledge_row.add_child(_make_label("Knowledge: ", FONT_SMALL, TEXT_DIM))
	var knowledge_val: Label = _make_label("", FONT_SMALL, Color8(180, 220, 255))
	knowledge_val.name = "MindKnowledge"
	knowledge_val.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	knowledge_row.add_child(knowledge_val)

	var war_row: HBoxContainer = HBoxContainer.new()
	_tab_consciousness.add_child(war_row)
	war_row.add_child(_make_label("Conflict: ", FONT_SMALL, TEXT_DIM))
	var war_val: Label = _make_label("", FONT_SMALL, Color8(255, 180, 160))
	war_val.name = "MindWar"
	war_val.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	war_row.add_child(war_val)

	var settlement_row: HBoxContainer = HBoxContainer.new()
	_tab_consciousness.add_child(settlement_row)
	settlement_row.add_child(_make_label("Settlement: ", FONT_SMALL, TEXT_DIM))
	var settlement_val: Label = _make_label("", FONT_SMALL, Color8(200, 200, 180))
	settlement_val.name = "MindSettlement"
	settlement_val.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	settlement_row.add_child(settlement_val)

	# === DEEP MIND (existing consciousness data) ===
	_tab_consciousness.add_child(_make_section_header("Deep Mind"))
	
	var awareness_row: HBoxContainer = HBoxContainer.new()
	_tab_consciousness.add_child(awareness_row)
	
	var awareness_label: Label = _make_label("Self-Awareness:", FONT_SMALL, TEXT_DIM)
	awareness_row.add_child(awareness_label)
	
	var awareness_value: Label = _make_label("", FONT_SMALL, ACCENT)
	awareness_value.name = "AwarenessValue"
	awareness_row.add_child(awareness_value)
	
	# Trauma section
	_tab_consciousness.add_child(_make_section_header("Trauma"))
	
	var trauma_bar: ProgressBar = ProgressBar.new()
	trauma_bar.name = "TraumaBar"
	trauma_bar.min_value = 0.0
	trauma_bar.max_value = 100.0
	trauma_bar.value = 0.0
	trauma_bar.show_percentage = true
	trauma_bar.custom_minimum_size = Vector2(0, 20)
	_tab_consciousness.add_child(trauma_bar)
	
	var trauma_status: Label = _make_label("", FONT_SMALL, TEXT_DIM)
	trauma_status.name = "TraumaStatus"
	_tab_consciousness.add_child(trauma_status)
	
	# Growth section
	_tab_consciousness.add_child(_make_section_header("Growth"))
	
	var growth_label: Label = _make_label("", FONT_SMALL, TEXT_BRIGHT)
	growth_label.name = "GrowthLabel"
	_tab_consciousness.add_child(growth_label)
	
	# Dreams section
	_tab_consciousness.add_child(_make_section_header("Recent Dreams"))
	
	var dreams_container: VBoxContainer = VBoxContainer.new()
	dreams_container.name = "DreamsContainer"
	dreams_container.add_theme_constant_override("separation", 4)
	_tab_consciousness.add_child(dreams_container)
	
	# Memories section
	_tab_consciousness.add_child(_make_section_header("Significant Memories"))
	
	var memories_container: VBoxContainer = VBoxContainer.new()
	memories_container.name = "MemoriesContainer"
	memories_container.add_theme_constant_override("separation", 4)
	_tab_consciousness.add_child(memories_container)
	
	# Beliefs section
	_tab_consciousness.add_child(_make_section_header("Core Beliefs"))
	
	var beliefs_label: Label = _make_label("", FONT_SMALL, TEXT_DIM)
	beliefs_label.name = "BeliefsLabel"
	beliefs_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tab_consciousness.add_child(beliefs_label)


func _populate_gear_tab() -> void:
	_tab_gear.add_child(_make_section_header("Equipment"))
	# 5 gear slots: Weapon, Armor, Tool, Accessory, Offhand
	var slot_names: PackedStringArray = ["Weapon", "Armor", "Tool", "Accessory", "Offhand"]
	var slot_colors: Array = [
		Color8(220, 80, 80),   # Weapon: red
		Color8(80, 140, 220),  # Armor: blue
		Color8(180, 160, 60),  # Tool: gold
		Color8(160, 80, 220),  # Accessory: purple
		Color8(80, 180, 140),  # Offhand: green
	]
	for i in range(5):
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		_tab_gear.add_child(row)
		# Slot name label
		var slot_label: Label = _make_label(slot_names[i] + ":", FONT_SMALL, slot_colors[i])
		slot_label.custom_minimum_size = Vector2(64, 0)
		row.add_child(slot_label)
		# Item name label
		var item_label: Label = _make_label("Empty", FONT_SMALL, TEXT_DIM)
		item_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(item_label)
		_gear_labels[i] = item_label
	_tab_gear.add_child(_make_section_header("Stats"))
	_gear_stats_label = _make_label("", FONT_SMALL, TEXT_BRIGHT)
	_gear_stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tab_gear.add_child(_gear_stats_label)


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
	
	var d: HeelKawnianData = _pawn.data
	var tick: int = GameManager.tick_count
	
	var dump_lines: PackedStringArray = []
	dump_lines.append("HeelKawnian: %s | Tick: %d" % [d.display_name, tick])
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
	var d: HeelKawnianData = _pawn.data
	match field:
		"work_forage":
			d.work_forage = pressed
		"work_fish":
			d.work_fish = pressed
		"work_mine":
			d.work_mine = pressed
		"work_chop":
			d.work_chop = pressed
		"work_hunt":
			d.work_hunt = pressed
		"work_build":
			d.work_build = pressed
		"work_guard":
			d.work_guard = pressed


static func _read_work_field(d: HeelKawnianData, field: String) -> bool:
	match field:
		"work_forage":
			return d.work_forage
		"work_fish":
			return d.work_fish
		"work_mine":
			return d.work_mine
		"work_chop":
			return d.work_chop
		"work_hunt":
			return d.work_hunt
		"work_build":
			return d.work_build
		"work_guard":
			return d.work_guard
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


func _portrait_cell_color(cell_idx: int, d: HeelKawnianData) -> Color:
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


func _refresh_portrait_strip(d: HeelKawnianData) -> void:
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
		_reset_expensive_detail_cache()
		return
	_poll_accum_sec += delta
	_expensive_poll_accum_sec += delta
	if _poll_accum_sec < UI_POLL_INTERVAL_SEC and not _expensive_dirty:
		return
	if _poll_accum_sec >= UI_POLL_INTERVAL_SEC:
		_poll_accum_sec = 0.0
	var refresh_expensive: bool = _should_refresh_expensive_details()
	var sig: String = _build_cheap_ui_signature()
	if sig == _last_ui_signature and not refresh_expensive:
		return
	_last_ui_signature = sig
	_refresh(refresh_expensive)


func _refresh(refresh_expensive_details: bool = false) -> void:
	if _pawn == null or _pawn.data == null:
		return
	var d: HeelKawnianData = _pawn.data
	_title_label.text = "%s (age %.1f)" % [d.display_name, d.age]
	if _subtitle_label != null:
		var prof: String = d.profession_name()
		var hk: String = d.highest_affinity_skill()
		var arc_bits: String = "children %d" % int(d.children_count)
		var clan_bit: String = ""
		if d.clan_id >= 0:
			clan_bit = " · clan %d" % d.clan_id
		var rank_bit: String = ""
		var rank_legacy: String = str(d.military_rank_legacy).strip_edges()
		if not rank_legacy.is_empty() and rank_legacy.to_lower() != "none":
			rank_bit = " · %s" % rank_legacy.capitalize()
		var job_diag: String = ""
		if d.visible_orders_count > 0 or not str(d.last_claim_failure_reason).is_empty():
			var fail: String = str(d.last_claim_failure_reason).strip_edges()
			if fail.is_empty():
				job_diag = " · jobs vis %d" % int(d.visible_orders_count)
			else:
				job_diag = " · jobs %d · %s" % [int(d.visible_orders_count), fail]
		if prof == "None":
			_subtitle_label.text = "%s · no prof · bias %s%s%s%s" % [arc_bits, hk, clan_bit, rank_bit, job_diag]
		else:
			_subtitle_label.text = "%s · %s · bias %s%s%s%s" % [arc_bits, prof, hk, clan_bit, rank_bit, job_diag]
		if refresh_expensive_details:
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
	
	if refresh_expensive_details:
		_refresh_expensive_details(d)

	# Needs tab updates
	for field in _need_bars:
		var entry: Dictionary = _need_bars[field]
		var v: float = float(d.get(field))
		entry.bar.value = clampf(v, 0.0, 100.0)
		entry.label.text = "%d" % int(round(v))

	if refresh_expensive_details and OS.is_debug_build() and _matrix_inputs_label != null:
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

	if refresh_expensive_details and OS.is_debug_build():
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

	if refresh_expensive_details and _social_label != null:
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

	if refresh_expensive_details:
		_refresh_narrative_tab()
		_update_consciousness_tab()
		_last_expensive_signature = _build_ui_signature()
		_expensive_dirty = false
		_expensive_poll_accum_sec = 0.0

	# Reposition each tick because the panel can grow/shrink with carry text.
	_reposition()


func _reset_expensive_detail_cache() -> void:
	_expensive_poll_accum_sec = HIGH_SPEED_EXPENSIVE_DETAILS_REFRESH_SEC
	_last_expensive_signature = ""
	_expensive_dirty = true
	_last_gear_signature = ""


func _expensive_refresh_interval() -> float:
	if GameManager != null and GameManager.game_speed >= 10.0:
		return HIGH_SPEED_EXPENSIVE_DETAILS_REFRESH_SEC
	return EXPENSIVE_DETAILS_REFRESH_SEC


func _should_refresh_expensive_details() -> bool:
	if _expensive_dirty:
		return true
	if _expensive_poll_accum_sec < _expensive_refresh_interval():
		return false
	var sig: String = _build_ui_signature()
	if sig == _last_expensive_signature:
		_expensive_poll_accum_sec = 0.0
		return false
	return true


func _build_cheap_ui_signature() -> String:
	if _pawn == null or not is_instance_valid(_pawn) or _pawn.data == null:
		return ""
	var d: HeelKawnianData = _pawn.data
	return "%d|%d|%d|%d|%s|%d|%d|%d|%d|%s|%s|%s|%d|%s|%d|%s" % [
		int(d.id),
		int(d.age),
		d.tile_pos.x,
		d.tile_pos.y,
		_pawn.describe_state(),
		int(round(d.hunger)),
		int(round(d.rest)),
		int(round(d.mood)),
		int(round(d.health)),
		str(d.carrying),
		str(d.carrying_qty),
		_player_context_mode_label,
		_player_context_pawn_id,
		str(_player_context_picker_visible),
		int(d.current_profession),
		str(d.display_name),
	]


func _refresh_expensive_details(d: HeelKawnianData) -> void:
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
	if _likes_dislikes_label != null:
		_likes_dislikes_label.text = _build_likes_dislikes_text(d)
	if _coach_label != null:
		var hints: PackedStringArray = d.progression_coach_lines(3)
		_coach_label.text = "\n".join(hints)
	if _identity_label != null:
		_identity_label.text = _build_identity_strip(d)
	if _settlement_label != null:
		_settlement_label.text = _build_settlement_line(d)
	_refresh_gear_tab_if_changed(d)


func _refresh_gear_tab_if_changed(d: HeelKawnianData) -> void:
	var sig: String = _gear_signature(d)
	if sig == _last_gear_signature:
		return
	_last_gear_signature = sig
	_refresh_gear_tab(d)


func _gear_signature(d: HeelKawnianData) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for slot_idx in range(5):
		var gear: Variant = d.equipped_gear.get(slot_idx, null)
		if gear == null:
			parts.append("%d:empty" % slot_idx)
		else:
			parts.append("%d:%s:%d:%d:%d" % [
				slot_idx,
				str(gear.name),
				int(gear.durability),
				int(gear.max_durability),
				int(gear.quality),
			])
	return "|".join(parts)


func _refresh_narrative_tab() -> void:
	var narrative_label: RichTextLabel = _tab_narrative.get_node_or_null("NarrativeLabel") as RichTextLabel
	if narrative_label == null:
		return
	var narrative_text: String = _generate_pawn_narrative(_pawn)
	if narrative_text != "":
		narrative_label.text = narrative_text
	else:
		narrative_label.text = "[i][color=#666666]No narrative data available[/color][/i]"


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
		var peer_data: HeelKawnianData = spawner.pawn_data_for_id(pid)
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
		var pd: HeelKawnianData = spawner.pawn_data_for_id(pid)
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
		var prof_l: String = HeelKawnianData.profession_label_from_enum(prof_i)
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
		var pd: HeelKawnianData = spawner.pawn_data_for_id(pid)
		if pd != null:
			return int(pd.current_profession)
	var fact: Dictionary = WorldMemory.pawn_death_fact(pid)
	if fact.is_empty():
		return -1
	return int(fact.get("prof", -1))


func _profession_inheritance_note(d: HeelKawnianData) -> String:
	if d.current_profession == HeelKawnianData.Profession.NONE:
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


func _lineage_block(d: HeelKawnianData) -> String:
	var lines: PackedStringArray = PackedStringArray()
	if d.bloodline_id >= 0:
		var bloodline_line: String = "Bloodline: #%d" % d.bloodline_id
		var bloodline_sys: Node = SocialManager.get_bloodline_system()
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
	# Matrix drive from HeelKawnianManager development profile
	var _hk_profile: Dictionary = HeelKawnianManager.get_development_profile_for_pawn(_pawn) if is_instance_valid(_pawn) else {}
	if not _hk_profile.is_empty():
		var drive: String = str(_hk_profile.get("development_drive", ""))
		var next_need: String = str(_hk_profile.get("next_need", ""))
		if not drive.is_empty():
			lines.append("Matrix drive: %s · next: %s" % [drive.capitalize(), next_need.capitalize()])
	var inh: String = _profession_inheritance_note(d)
	if not inh.is_empty():
		lines.append(inh)
	return "\n".join(lines)


func _build_identity_strip(d: HeelKawnianData) -> String:
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


func _build_likes_dislikes_text(d: HeelKawnianData) -> String:
	var like_parts: PackedStringArray = []
	for cat in d.likes:
		like_parts.append("%s (%d%%)" % [str(cat).capitalize(), int(float(d.likes[cat]) * 100)])
	var dislike_parts: PackedStringArray = []
	for cat in d.dislikes:
		dislike_parts.append("%s (%d%%)" % [str(cat).capitalize(), int(float(d.dislikes[cat]) * 100)])
	var text: String = ""
	if not like_parts.is_empty():
		text += "Likes: " + ", ".join(like_parts)
	if not dislike_parts.is_empty():
		if text != "":
			text += "\n"
		text += "Dislikes: " + ", ".join(dislike_parts)
	if text.is_empty():
		text = "No strong preferences yet"
	return text


func _refresh_gear_tab(d: HeelKawnianData) -> void:
	# Update each gear slot label
	for slot_idx in range(5):
		var label: Label = _gear_labels.get(slot_idx, null) as Label
		if label == null:
			continue
		var gear: Variant = d.equipped_gear.get(slot_idx, null)
		if gear == null or not gear.has_method("short_desc"):
			label.text = "Empty"
			label.add_theme_color_override("font_color", TEXT_DIM)
		else:
			var gear_name: String = str(gear.name)
			var gear_desc: String = str(gear.short_desc())
			var dur: int = int(gear.durability)
			var max_dur: int = int(gear.max_durability)
			var quality: int = int(gear.quality)
			var quality_color: Color = TEXT_DIM
			if quality == 3:  # MASTERWORK
				quality_color = Color8(255, 180, 50)  # gold
			elif quality == 2:  # FINE
				quality_color = Color8(100, 200, 255)  # blue
			elif quality == 0:  # POOR
				quality_color = Color8(180, 100, 100)  # red
			else:
				quality_color = TEXT_BRIGHT
			label.text = "%s [%d/%d] %s" % [gear_name, dur, max_dur, gear_desc]
			label.add_theme_color_override("font_color", quality_color)
	# Update stats summary
	if _gear_stats_label != null:
		var stats: Dictionary = d.get_gear_stats()
		var parts: PackedStringArray = []
		parts.append("ATK %.0f" % float(stats.get("attack", 1.0)))
		parts.append("DEF %.0f" % float(stats.get("defense", 0.0)))
		parts.append("SPD +%.0f%%" % (float(stats.get("work_speed", 0.0)) * 100.0))
		parts.append("WRM +%.0f" % float(stats.get("warmth", 0.0)))
		_gear_stats_label.text = " | ".join(parts)


func _build_settlement_line(d: HeelKawnianData) -> String:
	var sid: int = int(d.settlement_id)
	if sid < 0:
		return "Unaffiliated — no settlement bond recorded."
	var all_settlements: Array = SettlementMemory.get_formal_settlements()
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
	var st_name: String = str(st.get("name", ""))
	if st_name.is_empty():
		st_name = "Settlement #%d" % sid
	return (
		"%s · %d regions · center #%d\n"
		+ "State: %s · culture: %s · revival: %d\n"
		+ "Members: %d · intent: %s · war: %s\n"
		+ "Governance: %s"
	) % [st_name, region_count, center_rk, state, culture, revival, members, intent, war_state, gov_type]


func _count_settlement_members(settlement_idx: int) -> int:
	var count: int = 0
	var spawner: PawnSpawner = _pawn_spawner()
	if spawner == null:
		return count
	for pd in spawner.all_pawn_data():
		if pd is HeelKawnianData and int(pd.settlement_id) == settlement_idx:
			count += 1
	return count


func _build_ui_signature() -> String:
	if _pawn == null or not is_instance_valid(_pawn) or _pawn.data == null:
		return ""
	var d: HeelKawnianData = _pawn.data
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
		HeelKawnianData.BodyType.SLIM:
			return "Slim"
		HeelKawnianData.BodyType.BROAD:
			return "Broad"
		_:
			return "Average"


static func _hair_style_label(hair_style: int) -> String:
	match hair_style:
		HeelKawnianData.HairStyle.NONE:
			return "No hair"
		HeelKawnianData.HairStyle.MOHAWK:
			return "Mohawk"
		HeelKawnianData.HairStyle.BUN:
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
func _generate_pawn_narrative(pawn: HeelKawnian) -> String:
	if pawn == null or not is_instance_valid(pawn) or pawn.data == null:
		return ""
	
	var d: HeelKawnianData = pawn.data
	var text: String = ""
	
	# Header with pawn identity
	text += "[color=#FFD166][b]━━━ %s the %s ━━━[/b][/color]\n" % [d.display_name.to_upper(), d.profession_name().to_upper()]
	text += "[color=#888888]Age: %.1f years | Level: %d | Mood: %s[/color]\n" % [d.age / 360.0, d.level, d.mood_state_display()]
	# Combat rank display
	if AICombatProgression != null and d.military_rank > 0:
		var rank_name: String = AICombatProgression.get_rank_name(int(d.id))
		var rank_color: String = "#CC4444" if d.military_rank >= 5 else "#DD8844" if d.military_rank >= 3 else "#AAAAAA"
		text += "[color=%s][b]%s[/b][/color]  " % [rank_color, rank_name.to_upper()]
		if d.enemies_killed > 0:
			text += "[color=#666666]%d kills | %d XP[/color]" % [d.enemies_killed, d.combat_xp]
		text += "\n"
	text += "\n"
	
	# Current activity with location
	text += "[color=#FFD166][b]📍 CURRENTLY:[/b][/color]\n"
	text += "  %s\n" % _get_activity_description(pawn)
	if pawn._current_job != null:
		var job_name: String = Job.describe_type(pawn._current_job.type)
		text += "  [color=#666666](%s job at tile %d,%d)[/color]\n\n" % [job_name, pawn._current_job.work_tile.x, pawn._current_job.work_tile.y]
	else:
		text += "\n"
	
	# Carrying status
	if d.carrying != Item.Type.NONE and d.carrying_qty > 0:
		var item_name: String = _get_item_name(d.carrying)
		text += "[color=#57C5B6][b]🎒 CARRYING:[/b][/color]\n"
		text += "  %d %s" % [d.carrying_qty, item_name]
		if d.carrying_qty > 1:
			text += "s"
		# Check if hauling to stockpile
		if pawn._state == HeelKawnian.State.HAULING or pawn._state == HeelKawnian.State.FETCHING_MATERIAL:
			text += " [color=#666666]→ heading to stockpile[/color]"
		text += "\n\n"
	
	# Skills summary
	text += "[color=#B084CC][b]📊 SKILLS:[/b][/color]\n"
	var skill_text: String = _get_skills_summary(d)
	text += "  %s\n\n" % skill_text
	
	# Recent history (last 5 events)
	var events: Array = _get_pawn_events(d.id, 5)
	if not events.is_empty():
		text += "[color=#B084CC][b]📜 RECENT HISTORY:[/b][/color]\n"
		for ev in events:
			var event_text: String = _format_event(ev)
			if event_text != "":
				text += "  [color=#888888]•[/color] %s\n" % event_text
		text += "\n"
	
	# Settlement home
	if d.settlement_id >= 0:
		var settlement_name: String = _get_settlement_name(d.settlement_id)
		if settlement_name != "":
			var settlement_state: String = _get_settlement_state(d.settlement_id)
			text += "[color=#FF6B6B][b]🏠 HOME:[/b][/color]\n"
			text += "  %s [color=#666666](%s)[/color]\n\n" % [settlement_name, settlement_state]
	
	# Family ties
	var family_text: String = _get_family_summary(d)
	if family_text != "":
		text += "[color=#FF9F6B][b]👨‍👩‍👧‍👦 FAMILY:[/b][/color]\n"
		text += "  %s\n\n" % family_text
	
	# Memoir / pilgrim memory
	var memoir_text: String = _get_pawn_memoir_summary(int(d.id))
	if memoir_text != "":
		text += "[color=#9AD0FF][b]📖 MEMOIR:[/b][/color]\n"
		for line in memoir_text.split("\n"):
			text += "  [color=#888888]•[/color] %s\n" % line
		text += "\n"
	
	# Legacy preview (Phase 7)
	var legacy_sys: Node = get_node_or_null("/root/LegacySystem")
	if legacy_sys != null and legacy_sys.has_method("get_legacy_entry"):
		var legacy: Dictionary = legacy_sys.call("get_legacy_entry", int(d.id))
		if not legacy.is_empty():
			var score: int = int(legacy.get("legacy_score", 0))
			text += "[color=#FFD166][b]⭐ LEGACY SCORE:[/b][/color] [color=#FFD166]%d[/color]\n" % score
	
	return text


func _get_pawn_memoir_summary(pawn_id: int) -> String:
	var lines: Array[String] = []
	var events: Array = _get_pawn_events(pawn_id, 3)
	for ev in events:
		var event_text: String = _format_event(ev)
		if event_text != "":
			lines.append(event_text)
	if MemorialSystem != null and MemorialSystem.has_method("get_memorial_for_pilgrimage"):
		var memorial: Dictionary = MemorialSystem.get_memorial_for_pilgrimage(pawn_id)
		if not memorial.is_empty():
			var tile: Vector2i = memorial.get("tile", Vector2i.ZERO)
			lines.append("Memorial pilgrimage: %s at %s" % [str(memorial.get("memorial_type", "memorial")), _format_tile_pos(tile)])
	if lines.is_empty():
		return ""
	return "\n".join(lines)


## Get human-readable activity description from pawn state.
func _get_activity_description(pawn: HeelKawnian) -> String:
	if pawn == null or not is_instance_valid(pawn) or pawn.data == null:
		return "Unknown"
	var d: HeelKawnianData = pawn.data
	var state: int = pawn._state
	var job: Job = pawn._current_job
	match state:
		HeelKawnian.State.IDLE:
			return "Idle at %s" % _format_tile_pos(d.tile_pos)
		HeelKawnian.State.WALKING_TO_JOB, HeelKawnian.State.FETCHING_MATERIAL:
			if job != null:
				var job_type: String = Job.describe_type(job.type).to_lower()
				return "%sing at %s" % [job_type.capitalize().left(-1), _format_tile_pos(job.work_tile)]
			return "Walking to work"
		HeelKawnian.State.WORKING:
			if job != null:
				var job_type: String = Job.describe_type(job.type)
				return "%s at %s" % [job_type, _format_tile_pos(job.work_tile)]
			return "Working"
		HeelKawnian.State.HAULING:
			return "Hauling to stockpile"
		HeelKawnian.State.GOING_TO_EAT:
			return "Going to eat at stockpile"
		HeelKawnian.State.EATING:
			return "Eating at stockpile"
		HeelKawnian.State.GOING_TO_BED:
			return "Going to bed"
		HeelKawnian.State.SLEEPING:
			return "Sleeping"
		HeelKawnian.State.DRAFT_WALK:
			if job != null:
				return "Moving to %s (drafted)" % _format_tile_pos(job.work_tile)
			return "Moving (drafted)"
		HeelKawnian.State.TEACHING:
			return "Teaching nearby"
		HeelKawnian.State.CHALLENGE:
			return "Challenging authority"
		HeelKawnian.State.GATHERING:
			return "Gathering items at %s" % _format_tile_pos(d.tile_pos)
		HeelKawnian.State.CRAFTING:
			return "Crafting at %s" % _format_tile_pos(d.tile_pos)
		HeelKawnian.State.FLEEING:
			return "Fleeing from danger!"
		HeelKawnian.State.HIDING:
			return "Hiding from threats"
		_:
			return "Unknown activity"


func _populate_talk_tab() -> void:
	_tab_talk.add_child(_make_section_header("Talk"))
	# Greeting from HeelKawnianVoice
	_talk_greeting = RichTextLabel.new()
	_talk_greeting.bbcode_enabled = true
	_talk_greeting.fit_content = true
	_talk_greeting.custom_minimum_size = Vector2(0, 60)
	_tab_talk.add_child(_talk_greeting)
	# Conversation output
	_talk_output = RichTextLabel.new()
	_talk_output.bbcode_enabled = true
	_talk_output.fit_content = true
	_talk_output.custom_minimum_size = Vector2(0, 120)
	_tab_talk.add_child(_talk_output)
	# Input field
	_talk_input = LineEdit.new()
	_talk_input.placeholder_text = "Say something..."
	_talk_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tab_talk.add_child(_talk_input)
	# Quick topic buttons
	var topics: HBoxContainer = HBoxContainer.new()
	topics.add_theme_constant_override("separation", 4)
	_tab_talk.add_child(topics)
	for topic in ["Day", "Work", "Feelings", "Family", "Dreams", "Knowledge"]:
		var btn: Button = Button.new()
		btn.text = topic
		btn.custom_minimum_size = Vector2(60, 24)
		btn.pressed.connect(_on_talk_topic_button.bind(topic.to_lower()))
		topics.add_child(btn)
	_talk_input.text_submitted.connect(_on_talk_input_submitted)


func _on_talk_topic_button(topic: String) -> void:
	if _pawn == null or not is_instance_valid(_pawn):
		return
	var response: String = ""
	if HeelKawnianVoice != null:
		response = HeelKawnianVoice.compose_dialogue(_pawn, topic)
	if _talk_output != null:
		var name: String = _pawn.data.display_name if _pawn.data != null else "???"
		_talk_output.append_text("[color=#c9a84c]%s:[/color] %s\n" % [name, response])


func _on_talk_input_submitted(text: String) -> void:
	if _talk_input != null:
		_talk_input.clear()
	if _pawn == null or not is_instance_valid(_pawn):
		return
	# Show player message
	if _talk_output != null:
		_talk_output.append_text("[color=#88aacc]You:[/color] %s\n" % text)
	# Try PawnDialogue (LLM-powered) first, fall back to HeelKawnianVoice
	if PawnDialogue != null:
		var pawn_id: int = int(_pawn.data.id) if _pawn.data != null else -1
		var pawn_name: String = _pawn.data.display_name if _pawn.data != null else "???"
		PawnDialogue.start_conversation(pawn_id, pawn_name)
		PawnDialogue.send_message(pawn_id, text)
		# Connect to response signal (one-shot)
		if not PawnDialogue.message_received.is_connected(_on_pawn_dialogue_response):
			PawnDialogue.message_received.connect(_on_pawn_dialogue_response)
	else:
		# Deterministic fallback
		var response: String = ""
		if HeelKawnianVoice != null:
			response = HeelKawnianVoice.compose_dialogue(_pawn, "")
		if _talk_output != null:
			var name: String = _pawn.data.display_name if _pawn.data != null else "???"
			_talk_output.append_text("[color=#c9a84c]%s:[/color] %s\n" % [name, response])


func _on_pawn_dialogue_response(pawn_id: int, speaker: String, text: String) -> void:
	if _talk_output != null:
		_talk_output.append_text("[color=#c9a84c]%s:[/color] %s\n" % [speaker, text])


func _refresh_talk_tab() -> void:
	if _pawn == null or not is_instance_valid(_pawn) or _pawn.data == null:
		return
	if _talk_greeting != null:
		var greeting: String = ""
		if HeelKawnianVoice != null:
			greeting = HeelKawnianVoice.compose_greeting(_pawn)
		_talk_greeting.clear()
		_talk_greeting.append_text(greeting)


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
		Item.Type.FISH:
			return "fish"
		Item.Type.COOKED_FISH:
			return "cooked fish"
		Item.Type.BONE:
			return "bone"
		Item.Type.STONE_ARROW:
			return "stone arrow"
		Item.Type.BONE_ARROW:
			return "bone arrow"
		_:
			return "item"


## Get recent events for a specific pawn from WorldMemory.
func _get_pawn_events(pawn_id: int, count: int) -> Array:
	if WorldMemory == null:
		return []

	var all_events: Array = WorldMemory.get_events()
	var pawn_events: Array = []
	
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


# ==================== CONSCIOUSNESS SYSTEM (Phase 5: HeelKawnian Consciousness) ====================

## Update the Consciousness tab with pawn's mental state data.
func _update_consciousness_tab() -> void:
	if _pawn == null or _pawn.data == null or PawnConsciousness == null:
		return

	var pawn_id: int = int(_pawn.data.id)

	# === MIND SNAPSHOT (HeelKawnianMind) ===
	if HeelKawnianMind != null:
		var snapshot: Dictionary = HeelKawnianMind.compute_mind_snapshot(_pawn)
		if not snapshot.is_empty():
			var thought_label: Label = _tab_consciousness.get_node_or_null("MindThought") as Label
			if thought_label != null:
				thought_label.text = "\"%s\"" % str(snapshot.get("current_thought", ""))

			var pursuit_val: Label = _tab_consciousness.get_node_or_null("MindPursuit") as Label
			if pursuit_val != null:
				pursuit_val.text = str(snapshot.get("pursuit", ""))

			var body_val: Label = _tab_consciousness.get_node_or_null("MindBody") as Label
			if body_val != null:
				body_val.text = str(snapshot.get("body_pressure", ""))

			var emotion_val: Label = _tab_consciousness.get_node_or_null("MindEmotion") as Label
			if emotion_val != null:
				emotion_val.text = str(snapshot.get("emotional_pressure", ""))

			var likes_val: Label = _tab_consciousness.get_node_or_null("MindLikes") as Label
			if likes_val != null:
				likes_val.text = str(snapshot.get("likes", ""))

			var dislikes_val: Label = _tab_consciousness.get_node_or_null("MindDislikes") as Label
			if dislikes_val != null:
				dislikes_val.text = str(snapshot.get("dislikes", ""))

			var family_val: Label = _tab_consciousness.get_node_or_null("MindFamily") as Label
			if family_val != null:
				family_val.text = str(snapshot.get("family", ""))

			var rel_val: Label = _tab_consciousness.get_node_or_null("MindRelationships") as Label
			if rel_val != null:
				rel_val.text = str(snapshot.get("relationships", ""))

			var memory_val: Label = _tab_consciousness.get_node_or_null("MindMemory") as Label
			if memory_val != null:
				memory_val.text = str(snapshot.get("memory_summary", ""))

			var culture_val: Label = _tab_consciousness.get_node_or_null("MindCulture") as Label
			if culture_val != null:
				culture_val.text = str(snapshot.get("culture_summary", ""))

			var work_val: Label = _tab_consciousness.get_node_or_null("MindWork") as Label
			if work_val != null:
				work_val.text = str(snapshot.get("work_intent", ""))

			var reason_val: Label = _tab_consciousness.get_node_or_null("MindReason") as Label
			if reason_val != null:
				reason_val.text = str(snapshot.get("reason", ""))

			var knowledge_val: Label = _tab_consciousness.get_node_or_null("MindKnowledge") as Label
			if knowledge_val != null:
				var ktext: String = str(snapshot.get("knowledge_summary", ""))
				if bool(snapshot.get("knowledge_at_risk", false)):
					ktext += " [color=#FF6644][AT RISK][/color]"
				knowledge_val.text = ktext

			var war_val: Label = _tab_consciousness.get_node_or_null("MindWar") as Label
			if war_val != null:
				war_val.text = str(snapshot.get("war_memory", ""))

			var settlement_val: Label = _tab_consciousness.get_node_or_null("MindSettlement") as Label
			if settlement_val != null:
				settlement_val.text = str(snapshot.get("settlement_history", ""))

	# === DEEP MIND (existing consciousness data) ===

	# Self-Awareness
	var awareness_value: Label = _tab_consciousness.get_node_or_null("AwarenessValue") as Label
	if awareness_value != null:
		var awareness_level: int = PawnConsciousness.get_awareness_level(pawn_id)
		var awareness_name: String = PawnConsciousness.get_awareness_name(awareness_level)
		awareness_value.text = " %s (Level %d)" % [awareness_name, awareness_level]

	# Trauma
	var trauma_bar: ProgressBar = _tab_consciousness.get_node_or_null("TraumaBar") as ProgressBar
	var trauma_status: Label = _tab_consciousness.get_node_or_null("TraumaStatus") as Label
	if trauma_bar != null and trauma_status != null:
		var trauma_level: float = PawnConsciousness.get_trauma_level(pawn_id)
		trauma_bar.value = clampf(trauma_level, 0.0, 100.0)
		if trauma_level >= 80:
			trauma_status.text = "[color=#FF4444]Severely Traumatized[/color] - permanent scars likely"
			trauma_bar.modulate = Color(0.8, 0.2, 0.2)
		elif trauma_level >= 50:
			trauma_status.text = "[color=#FF8800]Moderately Traumatized[/color] - behavioral effects active"
			trauma_bar.modulate = Color(0.8, 0.5, 0.2)
		elif trauma_level >= 25:
			trauma_status.text = "[color=#FFCC00]Mildly Traumatized[/color] - recovering naturally"
			trauma_bar.modulate = Color(0.8, 0.8, 0.2)
		else:
			trauma_status.text = "[color=#44FF44]Psychologically Stable[/color]"
			trauma_bar.modulate = Color(0.2, 0.8, 0.2)

	# Growth
	var growth_label: Label = _tab_consciousness.get_node_or_null("GrowthLabel") as Label
	if growth_label != null:
		var consciousness: Dictionary = PawnConsciousness.get_consciousness(pawn_id)
		var growth_points: int = consciousness.get("growth_points", 0)
		var growth_text: String = "Growth Points: %d" % growth_points
		if growth_points >= 100:
			growth_text += " [color=#44FF44](Ready for growth milestone)[/color]"
		growth_label.text = growth_text

	# Dreams
	var dreams_container: VBoxContainer = _tab_consciousness.get_node_or_null("DreamsContainer") as VBoxContainer
	if dreams_container != null:
		# Clear existing dream labels
		for child in dreams_container.get_children():
			child.queue_free()

		var dreams: Array = PawnConsciousness.get_dreams(pawn_id, 3)
		if dreams.is_empty():
			var no_dreams: Label = _make_label("[i][color=#666666]No recent dreams[/color][/i]", FONT_SMALL, TEXT_DIM)
			dreams_container.add_child(no_dreams)
		else:
			for dream in dreams:
				var dream_text: String = _format_dream(dream)
				var dream_label: Label = _make_label(dream_text, FONT_SMALL, TEXT_BRIGHT)
				dream_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				dreams_container.add_child(dream_label)

	# Memories
	var memories_container: VBoxContainer = _tab_consciousness.get_node_or_null("MemoriesContainer") as VBoxContainer
	if memories_container != null:
		# Clear existing memory labels
		for child in memories_container.get_children():
			child.queue_free()

		var memories: Array = PawnConsciousness.get_memories(pawn_id, "", 5)
		if memories.is_empty():
			var no_memories: Label = _make_label("[i][color=#666666]No significant memories[/color][/i]", FONT_SMALL, TEXT_DIM)
			memories_container.add_child(no_memories)
		else:
			for memory in memories:
				var memory_text: String = _format_memory(memory)
				var memory_label: Label = _make_label(memory_text, FONT_SMALL, TEXT_BRIGHT)
				memory_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				memories_container.add_child(memory_label)

	# Beliefs
	var beliefs_label: Label = _tab_consciousness.get_node_or_null("BeliefsLabel") as Label
	if beliefs_label != null:
		var beliefs: Array = PawnConsciousness.get_core_beliefs(pawn_id)
		if beliefs.is_empty():
			beliefs_label.text = "[i][color=#666666]No core beliefs formed yet[/color][/i]"
		else:
			beliefs_label.text = "• " + "\n• ".join(beliefs)


## Format a dream into readable text.
func _format_dream(dream: Dictionary) -> String:
	var theme: String = str(dream.get("theme", "general"))
	var content: String = str(dream.get("content", "unknown"))
	var emotion: float = float(dream.get("emotion", 0.0))
	var lucid: bool = bool(dream.get("lucid", false))
	var tick: int = int(dream.get("tick", 0))
	var ticks_ago: int = GameManager.tick_count - tick
	var minutes_ago: float = float(ticks_ago) / 60.0

	var emotion_color: String = "#888888"
	if emotion > 30:
		emotion_color = "#44FF44"
	elif emotion < -30:
		emotion_color = "#FF4444"
	elif emotion > 0:
		emotion_color = "#44CCFF"

	var lucid_tag: String = " [color=#FFD166][Lucid Dream][/color]" if lucid else ""
	var theme_emoji: String = _get_dream_theme_emoji(theme)

	return "%s %s%s [color=%s](%s)[/color] [color=#666666](%.0f min ago)[/color]" % [
		theme_emoji, content, lucid_tag, emotion_color, theme, minutes_ago
	]


## Get emoji for dream theme.
func _get_dream_theme_emoji(theme: String) -> String:
	match theme:
		"trauma":
			return "💀"
		"desire":
			return "✨"
		"survival":
			return "🏃"
		"social":
			return "💬"
		"achievement":
			return "🏆"
		_:
			return "💭"


## Format a memory into readable text.
func _format_memory(memory: Dictionary) -> String:
	var event_type: String = str(memory.get("event_type", "unknown"))
	var description: String = str(memory.get("description", ""))
	var emotion: float = float(memory.get("emotion", 0.0))
	var importance: int = int(memory.get("importance", 5))
	var tick: int = int(memory.get("tick", 0))
	var ticks_ago: int = GameManager.tick_count - tick
	var minutes_ago: float = float(ticks_ago) / 60.0
	var hours_ago: float = minutes_ago / 60.0

	var emotion_color: String = "#888888"
	var emotion_label: String = "Neutral"
	if emotion > 50:
		emotion_color = "#44FF44"
		emotion_label = "Joyful"
	elif emotion > 20:
		emotion_color = "#44CCFF"
		emotion_label = "Positive"
	elif emotion < -50:
		emotion_color = "#FF4444"
		emotion_label = "Traumatic"
	elif emotion < -20:
		emotion_color = "#FF8800"
		emotion_label = "Negative"

	var time_text: String = ""
	if minutes_ago < 60:
		time_text = "%.0f min ago" % minutes_ago
	else:
		time_text = "%.1f hr ago" % hours_ago

	var importance_stars: String = ""
	for i in range(importance):
		importance_stars += "★" if i < importance else "☆"

	return "[color=%s]%s[/color] • %s [color=#666666](%s)[/color]" % [
		emotion_color, emotion_label, description, time_text
	]


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


## Get skills summary as formatted string.
func _get_skills_summary(d: HeelKawnianData) -> String:
	var skills: Array[String] = []
	
	# Get skill levels
	var foraging: int = d.get_skill_level(HeelKawnianData.Skill.FORAGING)
	var mining: int = d.get_skill_level(HeelKawnianData.Skill.MINING)
	var chopping: int = d.get_skill_level(HeelKawnianData.Skill.CHOPPING)
	var building: int = d.get_skill_level(HeelKawnianData.Skill.BUILDING)
	var hunting: int = d.get_skill_level(HeelKawnianData.Skill.HUNTING)
	
	if foraging > 0:
		skills.append("Foraging %d" % foraging)
	if mining > 0:
		skills.append("Mining %d" % mining)
	if chopping > 0:
		skills.append("Chopping %d" % chopping)
	if building > 0:
		skills.append("Building %d" % building)
	if hunting > 0:
		skills.append("Hunting %d" % hunting)
	
	if skills.is_empty():
		return "[color=#666666]No skills yet[/color]"
	
	return ", ".join(skills)


## Get family summary as formatted string.
func _get_family_summary(d: HeelKawnianData) -> String:
	var parts: Array[String] = []
	
	if d.children_count > 0:
		parts.append("%d childr%s" % [d.children_count, "en" if d.children_count > 1 else ""])
	
	if d.parent_a_id >= 0 or d.parent_b_id >= 0:
		var parents: Array[String] = []
		if d.parent_a_id >= 0:
			var parent_a = d._get_parent_data(d.parent_a_id)
			if parent_a != null:
				parents.append(parent_a.display_name)
		if d.parent_b_id >= 0:
			var parent_b = d._get_parent_data(d.parent_b_id)
			if parent_b != null:
				parents.append(parent_b.display_name)
		if not parents.is_empty():
			parts.append("Child of %s" % " & ".join(parents))
	
	if d.spouse_id >= 0:
		parts.append("Married")
	
	if parts.is_empty():
		return ""
	
	return " | ".join(parts)


## Get settlement state as string.
func _get_settlement_state(settlement_id: int) -> String:
	if SettlementMemory == null or settlement_id < 0:
		return "Unknown"
	
	var settlements: Array = SettlementMemory.settlements
	if settlement_id >= settlements.size():
		return "Unknown"
	
	var st: Variant = settlements[settlement_id]
	if st is Dictionary:
		var state: String = str(st.get("state", "unknown"))
		return state.capitalize()
	
	return "Unknown"
