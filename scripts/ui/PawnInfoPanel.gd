class_name PawnInfoPanel
extends CanvasLayer

## Right-side **character sheet** for the selected pawn (NPC today; same
## surface can bind to a human-controlled pawn later). Chunky portrait reads
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

const FONT_TITLE: int = 13
const FONT_BODY:  int = 11
const FONT_SMALL: int = 10

const PANEL_WIDTH:    float = 268.0
const RIGHT_INSET:    float = 8.0
const TOP_INSET:      float = 8.0
## UI refresh is state-driven (signature diff), polled on wall-clock cadence.
## This keeps presentation dynamic without hard-binding repaint cadence to ticks.
const UI_POLL_INTERVAL_SEC: float = 0.20
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

var _pawn: Pawn = null
## When true (map-only mode), hide sheet even if a pawn is selected.
var _overlay_suppressed: bool = false
var _player_context_mode_label: String = "SPECTATOR"
var _player_context_pawn_id: int = -1
var _player_context_picker_visible: bool = false
var _traits_label: Label = null
var _lineage_label: Label = null
var _appearance_label: Label = null
var _mood_status_label: Label = null
var _crisis_level_label: Label = null
var _liking_label: Label = null
var _coach_label: Label = null
var _social_label: Label = null
var _identity_label: Label = null
var _action_skills_label: Label = null
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
	margin.add_theme_constant_override("margin_left",   10)
	margin.add_theme_constant_override("margin_right",  10)
	margin.add_theme_constant_override("margin_top",     8)
	margin.add_theme_constant_override("margin_bottom",  8)
	_panel.add_child(margin)

	_root_vbox = VBoxContainer.new()
	_root_vbox.add_theme_constant_override("separation", 4)
	margin.add_child(_root_vbox)

	_header_row = HBoxContainer.new()
	_header_row.add_theme_constant_override("separation", 8)
	_root_vbox.add_child(_header_row)

	var portrait_frame := PanelContainer.new()
	var cell_px: int = 8
	portrait_frame.custom_minimum_size = Vector2(PORTRAIT_COLS * cell_px + 4, PORTRAIT_ROWS * cell_px + 4)
	var psty := StyleBoxFlat.new()
	psty.bg_color = Color(0.02, 0.03, 0.06, 1.0)
	psty.border_color = PANEL_BORDER
	psty.set_border_width_all(1)
	psty.set_corner_radius_all(2)
	portrait_frame.add_theme_stylebox_override("panel", psty)
	var pm := MarginContainer.new()
	pm.add_theme_constant_override("margin_left", 2)
	pm.add_theme_constant_override("margin_right", 2)
	pm.add_theme_constant_override("margin_top", 2)
	pm.add_theme_constant_override("margin_bottom", 2)
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
	name_col.add_theme_constant_override("separation", 2)
	_title_label = _make_label("", FONT_TITLE, TEXT_BRIGHT)
	_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_col.add_child(_title_label)
	_subtitle_label = _make_label("", FONT_SMALL, TEXT_DIM)
	_subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_col.add_child(_subtitle_label)
	_header_row.add_child(name_col)

	# current activity
	_state_label = _make_label("", FONT_BODY, ACCENT)
	_state_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_root_vbox.add_child(_state_label)

	# traits
	_traits_label = _make_label("", FONT_SMALL, TEXT_DIM)
	_traits_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_root_vbox.add_child(_traits_label)

	_root_vbox.add_child(_make_section_header("Lineage"))
	_lineage_label = _make_label("", FONT_SMALL, TEXT_DIM)
	_lineage_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_root_vbox.add_child(_lineage_label)

	_appearance_label = _make_label("", FONT_SMALL, TEXT_DIM)
	_appearance_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_root_vbox.add_child(_appearance_label)

	# mood status and crisis
	_mood_status_label = _make_label("", FONT_SMALL, TEXT_DIM)
	_mood_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_root_vbox.add_child(_mood_status_label)
	
	_crisis_level_label = _make_label("", FONT_SMALL, TEXT_DIM)
	_root_vbox.add_child(_crisis_level_label)

	_root_vbox.add_child(_make_section_header("Work bias (liking)"))
	_liking_label = _make_label("", FONT_SMALL, TEXT_DIM)
	_liking_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_root_vbox.add_child(_liking_label)

	_root_vbox.add_child(_make_section_header("Coach (deterministic)"))
	_coach_label = _make_label("", FONT_SMALL, TEXT_DIM)
	_coach_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_root_vbox.add_child(_coach_label)

	_root_vbox.add_child(_make_section_header("Social (NPC v1)"))
	_social_label = _make_label("", FONT_SMALL, TEXT_DIM)
	_social_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_root_vbox.add_child(_social_label)

	_root_vbox.add_child(_make_section_header("HeelKawn identity"))
	_identity_label = _make_label("", FONT_SMALL, TEXT_DIM)
	_identity_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_root_vbox.add_child(_identity_label)

	_root_vbox.add_child(_make_section_header("Needs"))
	for entry in NEED_BARS:
		_add_need_row(entry.label, entry.field, entry.color)

	_root_vbox.add_child(_make_section_header("Skills"))
	for entry in SKILLS_ORDER:
		_add_skill_row(entry.label, entry.skill)

	_root_vbox.add_child(_make_section_header("Work"))
	_root_vbox.add_child(_make_work_hint())
	for w in WORK_CHECKS:
		_add_work_checkbox(String(w.field), String(w.text))

	_root_vbox.add_child(_make_section_header("Misc"))
	_action_skills_label = _make_label("", FONT_SMALL, TEXT_DIM)
	_action_skills_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_root_vbox.add_child(_action_skills_label)
	_carry_label = _make_label("", FONT_SMALL, TEXT_DIM)
	_root_vbox.add_child(_carry_label)
	_tile_label = _make_label("", FONT_SMALL, TEXT_DIM)
	_root_vbox.add_child(_tile_label)

	_hint_label = _make_label("[Esc] deselect", FONT_SMALL, Color(0.55, 0.55, 0.60))
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_root_vbox.add_child(_hint_label)

	# ephemeral inspect message
	_inspect_msg_label = _make_label("", FONT_SMALL, Color(0.82, 0.82, 0.6))
	_inspect_msg_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_root_vbox.add_child(_inspect_msg_label)

	call_deferred("_reposition")


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
	_title_label.text = "%s  (age %d)" % [d.display_name, d.age]
	if _subtitle_label != null:
		var prof: String = d.profession_name()
		var hk: String = d.highest_affinity_skill()
		var control_line: String = "Control: %s" % _player_context_mode_label
		if _player_context_mode_label == "INCARNATED" and _player_context_pawn_id >= 0:
			control_line += " (#%d)" % _player_context_pawn_id
		if _player_context_picker_visible:
			control_line += " | picker open"
		if prof == "None":
			_subtitle_label.text = "%s · No locked profession · job bias: %s" % [control_line, hk]
		else:
			_subtitle_label.text = "%s · %s · job bias: %s" % [control_line, prof, hk]
	_refresh_portrait_strip(d)
	if _coach_label != null:
		var hints: PackedStringArray = d.progression_coach_lines(5)
		var coach_sb: String = ""
		for hi in range(hints.size()):
			if hi > 0:
				coach_sb += "\n"
			coach_sb += hints[hi]
		_coach_label.text = coach_sb
	if _social_label != null:
		var top_peer: Dictionary = d.top_social_rapport_peer()
		var pid: int = int(top_peer.get("peer_id", -1))
		var peer_disp: String = _peer_display_for_social(pid)
		_social_label.text = d.social_status_line(peer_disp)
	if _identity_label != null:
		_identity_label.text = _build_identity_strip(d)
	if _action_skills_label != null:
		_action_skills_label.text = (
				"Action xp  move %d  farm %d  build %d  gather %d  combat %d"
				% [
					int(d.skills.get("movement", 0)),
					int(d.skills.get("farming", 0)),
					int(d.skills.get("building", 0)),
					int(d.skills.get("gathering", 0)),
					int(d.skills.get("combat", 0)),
				]
		)
	_state_label.text = _pawn.describe_state()
	_traits_label.text = "Traits: %s" % d.traits_display()
	_lineage_label.text = _lineage_block(d)
	_appearance_label.text = "Appearance: %s, %s" % [_body_type_label(d.body_type), _hair_style_label(d.hair_style)]
	
	# Mood status with active mood event
	var active_mood_event: MoodEvent = d.get_active_mood_event()

	# Show ephemeral inspect message if recent, with fade-out
	if _inspect_msg_label != null:
		var msg: String = ""
		var alpha: float = 0.0
		if _pawn != null and is_instance_valid(_pawn):
			var last_tick: int = int(_pawn._last_inspect_tick)
			var age: int = GameManager.tick_count - last_tick
			var max_age: int = 200
			if age >= 0 and age < max_age and str(_pawn._last_inspect_msg) != "":
				msg = str(_pawn._last_inspect_msg)
				alpha = clamp(1.0 - float(age) / float(max_age), 0.0, 1.0)
			else:
				msg = ""
		_inspect_msg_label.text = msg
		# apply fade via modulate alpha so text color remains themed
		_inspect_msg_label.modulate = Color(1, 1, 1, alpha)
	if active_mood_event != null:
		_mood_status_label.text = "Mood: %s (%d event: %s)" % [
			d.mood_state_display(),
			int(d.mood),
			active_mood_event.description
		]
	else:
		_mood_status_label.text = "Mood: %s (%d)" % [d.mood_state_display(), int(d.mood)]
	
	# Crisis level
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

	if _liking_label != null:
		_liking_label.text = d.profession_liking_digest_line()

	for field in _need_bars:
		var entry: Dictionary = _need_bars[field]
		var v: float = float(d.get(field))
		entry.bar.value = clampf(v, 0.0, 100.0)
		entry.label.text = "%d" % int(round(v))

	for skill in _skill_lines:
		var lbl: Label = _skill_lines[skill]
		var lvl: int = d.get_skill_level(skill)
		var xp: float = d.get_skill_xp(skill)
		var into_level: float = xp - float(lvl) * PawnData.XP_PER_LEVEL
		lbl.text = "Lv %d  (%d/%d)" % [
			lvl,
			int(into_level),
			int(PawnData.XP_PER_LEVEL),
		]

	if d.is_carrying():
		_carry_label.text = "Carrying: %s x%d" % [
			Item.name_for(d.carrying),
			d.carrying_qty,
		]
	else:
		_carry_label.text = "Carrying: nothing"

	_tile_label.text = "Tile: (%d, %d)" % [d.tile_pos.x, d.tile_pos.y]

	# Work toggles: reflect PawnData without re-emitting toggled (avoid feedback).
	for w in WORK_CHECKS:
		var f: String = String(w.field)
		if not _work_checkboxes.has(f):
			continue
		var cb: CheckBox = _work_checkboxes[f]
		cb.set_pressed_no_signal(_read_work_field(d, f))

	# Reposition each tick because the panel can grow/shrink with carry text.
	_reposition()


func _pawn_spawner() -> PawnSpawner:
	var n: Node = Engine.get_main_loop().root.find_child("PawnSpawner", true, false)
	return n as PawnSpawner


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
	var rk: int = preload("res://autoloads/WorldMemory.gd")._region_key(d.tile_pos.x, d.tile_pos.y)
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


func _build_ui_signature() -> String:
	if _pawn == null or not is_instance_valid(_pawn) or _pawn.data == null:
		return ""
	var d: PawnData = _pawn.data
	var rk: int = preload("res://autoloads/WorldMemory.gd")._region_key(d.tile_pos.x, d.tile_pos.y)
	var profile: Dictionary = SettlementMemory.get_settlement_profile(rk)
	var st_any: Variant = SettlementMemory.get_settlement_at_region(rk)
	var intent: String = "none"
	if st_any is Dictionary:
		intent = str((st_any as Dictionary).get("current_intent", "none"))
	var war: Dictionary = SettlementMemory.get_war_profile_for_region(rk)
	var gov: Dictionary = SettlementMemory.get_governance_profile_for_region(rk)
	var top_peer: Dictionary = d.top_social_rapport_peer()
	return (
		"%d|%d|%d|%d|%s|%s|%d|%d|%d|%d|%d|%d|%s|%s|%s|%s|%s|%d|%d|%d|%d|%d|%d|%s|%s|%s"
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
		WorldMeaning.get_region_meaning_label(rk),
		str(CulturalMemory.get_region_reputation(rk)),
		str(profile.get("state", "")),
		int(profile.get("revival_score", 0)),
		int(profile.get("center_region", -1)),
		int(profile.get("scar_max", 0)),
		int(profile.get("peace_since_conflict_ticks", 0)),
		int(top_peer.get("peer_id", -1)),
		int(top_peer.get("rapport", 0)),
		intent,
		str(war.get("state", "peace")),
		str(gov.get("type", "anarchy")),
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
