class_name ColonyHUD
extends CanvasLayer

## Always-on heads-up display rendered in screen space (CanvasLayer = doesn't
## move with the camera). Refreshes on deterministic tick cadence with
## high-speed throttling, so numbers stay live without per-frame UI churn.
##
## Reads pawn list from PawnSpawner, stockpile from World, time + speed from
## GameManager, and job counts from JobManager (autoload).

const REFRESH_EVERY_N_TICKS: int = 15
const REFRESH_EVERY_N_TICKS_FAST: int = 2
const REFRESH_EVERY_N_TICKS_ULTRA: int = 4
const REFRESH_EVERY_N_TICKS_EXTREME: int = 6
const REFRESH_EVERY_N_TICKS_MAX: int = 8
const EXPENSIVE_HUD_REFRESH_INTERVAL_TICKS: int = 120
const WILDLIFE_SAMPLE_EVERY_TICKS: int = 120
const WILDLIFE_HISTORY_SIZE: int = 8
const WILDLIFE_NEARBY_RADIUS_TILES: int = 14
const SHOW_REFRESH_DIAG: bool = false

const PANEL_BG: Color = Color(0.05, 0.06, 0.08, 0.88)
const PANEL_BORDER: Color = Color(0.85, 0.78, 0.40, 0.75)

# SPECTATOR MODE: Compact, readable, unobtrusive
const FONT_SIZE_BODY: int = 11
const FONT_SIZE_HOTKEYS: int = 10
const FONT_SIZE_COMPACT: int = 9
const PANEL_PAD_X: int = 10
const PANEL_PAD_Y: int = 8
## Readability mode: bigger, simpler HUD for at-a-glance play.
const SIMPLE_READABLE_HUD: bool = true
## Max width for HUD panel (prevents it from taking over screen)
const PANEL_MAX_WIDTH: int = 420
## Max height (prevents vertical overflow)
const PANEL_MAX_HEIGHT: int = 600
## Show only essential info in spectator mode
const SPECTATOR_MODE: bool = true


## Helpers that read from GameSettings when available, falling back to constants.
func _is_simple_hud() -> bool:
	if GameSettings != null:
		return GameSettings.is_simple_hud()
	return SIMPLE_READABLE_HUD

func _get_font_size() -> int:
	if GameSettings != null:
		return int(GameSettings.get_value("hud_font_size"))
	return FONT_SIZE_BODY

func _is_show_refresh_diag() -> bool:
	if GameSettings != null:
		return bool(GameSettings.get_value("show_refresh_diag"))
	return SHOW_REFRESH_DIAG

func _is_show_hotkey_hints() -> bool:
	if GameSettings != null:
		return bool(GameSettings.get_value("show_hotkey_hints"))
	return true
## Show a one-line first-session orientation in simple HUD for this many in-game days, then hide (see docs/HEELKAWN_STATE.md).
const FIRST_PLAY_HINT_VISUAL_DAYS: int = 8

const HOTKEY_HINTS: String = "SPACE pause · F5 save · F8 load · F9 realm · Shift+F9 rows · K sprite · F10 reports"

@onready var _panel: PanelContainer = $Panel
@onready var _label: RichTextLabel = $Panel/Margin/VBox/Body
@onready var _hotkeys: Label = $Panel/Margin/VBox/Hotkeys
var _history_panel: PopupPanel = null
var _history_text: RichTextLabel = null
var _collapsed: bool = false  # Start expanded — all info visible

var _world = null
var _spawner = null
## Cached Main node reference — avoids repeated get_node_or_null tree traversals every HUD refresh.
var _main: Main = null
var _animal_spawner: AnimalSpawner = null
## Empty string when no designation mode is active. Otherwise "Bed" / "Wall" / etc.
var _designation_label: String = ""
## Current player mode label for badge display ("SPECTATOR", "INCARNATED", "OBSERVER")
var _player_mode_label: String = "SPECTATOR"
## Authority rank when incarnated ("HeelKawnian", "Captain", "Elder", "Ruler")
var _player_authority_rank: String = ""
var _wildlife_snapshot: Dictionary = {"rabbit": 0, "deer": 0, "total": 0}
var _wildlife_prev_snapshot: Dictionary = {"rabbit": 0, "deer": 0, "total": 0}
var _wildlife_sample_tick: int = 0
var _wildlife_history: Array[int] = []
var _momentum_spark: String = "........"
var _wildlife_nearby_snapshot: Dictionary = {"rabbit": 0, "deer": 0, "total": 0, "threat_level": "low"}
var _player_input_buffer: PlayerInputBuffer = null
var _player_pawn = null
var _has_player_needs: bool = false
var _player_hunger: float = 100.0
var _player_rest: float = 100.0
var _hud_dirty: bool = true
var _last_refresh_stride: int = REFRESH_EVERY_N_TICKS
var _last_coarse_gate: int = 10
var _last_refresh_tick: int = 0
var _last_render_signature: String = ""
var _cached_expensive_hud_lines: Array[String] = []
var _last_expensive_hud_refresh_tick: int = -1
var _expensive_hud_dirty: bool = true
var _cached_expensive_hud_simple: bool = true
## Narrative rail cache — recomputes only when WorldMemory event count changes.
var _narrative_cache: String = ""
var _narrative_cache_event_count: int = -1


func _ready() -> void:
	# Pin top-left, leave a small inset.
	layer = 10
	GameManager.game_tick.connect(_on_tick)
	GameManager.speed_changed.connect(_on_speed_changed)
	JobManager.job_posted.connect(_on_jobs_changed)
	JobManager.job_completed.connect(_on_jobs_changed)
	JobManager.job_cancelled.connect(_on_jobs_changed)
	# Phase 10: aggregated totals come from StockpileManager. Refresh on zone
	# add/remove so the HUD shows the truth instantly instead of waiting for
	# the next tick.
	StockpileManager.zone_registered.connect(_on_zones_changed)
	StockpileManager.zone_unregistered.connect(_on_zones_changed)
	ColonySimServices.demand_snapshot.connect(_on_colony_demand)
	if GameSettings != null:
		GameSettings.setting_changed.connect(_on_setting_changed)
	_apply_panel_style()
	_ensure_history_panel()
	_hotkeys.text = HOTKEY_HINTS
	# Add collapse toggle button
	var collapse_btn := Button.new()
	collapse_btn.name = "CollapseBtn"
	collapse_btn.text = "▼ Colony"
	collapse_btn.add_theme_font_size_override("font_size", 10)
	collapse_btn.add_theme_color_override("font_color", Color(0.85, 0.78, 0.40))
	collapse_btn.add_theme_color_override("font_hover_color", Color.WHITE)
	collapse_btn.focus_mode = Control.FOCUS_NONE
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = Color(0.05, 0.06, 0.08, 0.9)
	btn_style.set_border_width_all(1)
	btn_style.border_color = Color(0.85, 0.78, 0.40, 0.5)
	btn_style.set_corner_radius_all(3)
	collapse_btn.add_theme_stylebox_override("normal", btn_style)
	var hover_style := btn_style.duplicate()
	hover_style.bg_color = Color(0.08, 0.09, 0.12, 0.95)
	collapse_btn.add_theme_stylebox_override("hover", hover_style)
	collapse_btn.pressed.connect(_toggle_collapse)
	_panel.get_node("Margin/VBox").add_child(collapse_btn)
	_panel.get_node("Margin/VBox").move_child(collapse_btn, 0)
	_apply_collapse_state()
	_refresh()


## Toggle colony HUD between collapsed (header only) and expanded.
func _toggle_collapse() -> void:
	_collapsed = not _collapsed
	_apply_collapse_state()

func _apply_collapse_state() -> void:
	var collapse_btn: Button = _panel.get_node_or_null("Margin/VBox/CollapseBtn")
	if collapse_btn != null:
		collapse_btn.text = "▼ Colony" if _collapsed else "▲ Colony"
	_label.visible = not _collapsed
	_hotkeys.visible = not _collapsed

## Cached Main node lookup — avoids repeated get_node_or_null tree traversals.
## Re-fetches if the cached reference becomes invalid (e.g. scene reload).
func _get_main() -> Main:
	if _main != null and is_instance_valid(_main):
		return _main
	_main = get_tree().get_root().get_node_or_null("Main") as Main
	return _main


## Called by Main once it has spawned the world + spawner.
func bind(world: World, spawner: PawnSpawner) -> void:
	_world = world
	_spawner = spawner
	_animal_spawner = null
	if _world != null and _world.has_meta("animal_spawner"):
		var m: Variant = _world.get_meta("animal_spawner")
		if m is AnimalSpawner:
			_animal_spawner = m as AnimalSpawner
	_hud_dirty = true
	_expensive_hud_dirty = true
	_refresh(true)
	_hud_dirty = false


func set_player_control_refs(input_buffer: PlayerInputBuffer, player_pawn: HeelKawnian) -> void:
	if _player_input_buffer != null and _player_input_buffer.intent_ready.is_connected(_on_intent_ready):
		_player_input_buffer.intent_ready.disconnect(_on_intent_ready)
	_player_input_buffer = input_buffer
	_player_pawn = player_pawn
	if _player_input_buffer != null and not _player_input_buffer.intent_ready.is_connected(_on_intent_ready):
		_player_input_buffer.intent_ready.connect(_on_intent_ready)
	if _player_pawn != null and is_instance_valid(_player_pawn) and _player_pawn.data != null:
		update_player_needs(_player_pawn.data.hunger, _player_pawn.data.rest)
	else:
		_has_player_needs = false
	_hud_dirty = true


func update_player_needs(hunger: float, rest: float) -> void:
	_player_hunger = clampf(hunger, 0.0, 100.0)
	_player_rest = clampf(rest, 0.0, 100.0)
	_has_player_needs = true
	_hud_dirty = true

func toggle_hud_verbose() -> void:
	if GameSettings != null:
		var current: bool = GameSettings.is_simple_hud()
		GameSettings.set_value("hud_mode", 0 if current else 1)
	_hud_dirty = true
	_expensive_hud_dirty = true
	_refresh(true)
	_hud_dirty = false


func _on_intent_ready(_action_id: int) -> void:
	_hud_dirty = true


## Called by Main whenever the player's build mode changes. Empty string =
## off. Anything else shows up as a colored banner above the stats lines.
func set_designation_mode(label: String) -> void:
	_designation_label = label
	_hud_dirty = true
	_refresh()
	_hud_dirty = false


func set_player_mode_badge(mode_label: String, authority_rank: String = "") -> void:
	_player_mode_label = mode_label
	_player_authority_rank = authority_rank
	_hud_dirty = true
	_refresh()
	_hud_dirty = false


func _visible_pawns_for_hud() -> Array[HeelKawnian]:
	var out: Array[HeelKawnian] = []
	if _spawner == null:
		return out
	var main_node: Main = _get_main()
	if main_node != null:
		return main_node.get_visible_pawns()
	for p in _spawner.pawns:
		if p != null and is_instance_valid(p) and p.data != null:
			out.append(p)
	return out


# ==================== refresh hooks ====================

func _on_tick(tick: int) -> void:
	if tick % WILDLIFE_SAMPLE_EVERY_TICKS == 0:
		_sample_wildlife(tick)
		_expensive_hud_dirty = true
		_hud_dirty = true
	var refresh_stride: int = _refresh_stride_for_speed(GameManager.game_speed)
	var coarse: int = _coarse_gate_for_speed(GameManager.game_speed)
	_last_refresh_stride = refresh_stride
	_last_coarse_gate = coarse
	var expensive_due: bool = tick % EXPENSIVE_HUD_REFRESH_INTERVAL_TICKS == 0
	if _hud_dirty or expensive_due or tick % refresh_stride == 0:
		_refresh()
		_hud_dirty = false
		_last_refresh_tick = tick


func _on_speed_changed(_s: float, _p: bool) -> void:
	_hud_dirty = true
	_refresh()
	_hud_dirty = false


func _on_jobs_changed(_job: Job) -> void:
	_expensive_hud_dirty = true
	_hud_dirty = true


func _on_zones_changed(_zone: Stockpile) -> void:
	_expensive_hud_dirty = true
	_hud_dirty = true


func _on_colony_demand(_f: float, _h: float, _m: float, _ha: float) -> void:
	_expensive_hud_dirty = true
	_hud_dirty = true


# ==================== layout / style ====================

func _apply_panel_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_BG
	style.border_color = PANEL_BORDER
	style.set_border_width_all(2)  # Thicker border for clarity
	style.set_corner_radius_all(6)  # Rounder corners
	style.content_margin_left = PANEL_PAD_X
	style.content_margin_right = PANEL_PAD_X
	style.content_margin_top = PANEL_PAD_Y
	style.content_margin_bottom = PANEL_PAD_Y
	_panel.add_theme_stylebox_override("panel", style)

	# Set max size to prevent panel from taking over screen
	_panel.custom_minimum_size = Vector2(PANEL_MAX_WIDTH, 0)
	_panel.custom_minimum_size.y = PANEL_MAX_HEIGHT
	_panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN

	# Enable text wrapping to prevent overflow
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.size_flags_vertical = Control.SIZE_EXPAND_FILL

	_label.add_theme_font_size_override("normal_font_size", _get_font_size())
	_label.add_theme_font_size_override("bold_font_size", _get_font_size())
	_label.add_theme_constant_override("line_spacing", 4)  # Better line spacing
	_hotkeys.add_theme_font_size_override("font_size", max(8, _get_font_size() - 1))


## React to live settings changes — re-apply font size and mark HUD dirty.
func _on_setting_changed(key: String, _new_value: Variant) -> void:
	if key == "hud_font_size":
		_label.add_theme_font_size_override("normal_font_size", _get_font_size())
		_label.add_theme_font_size_override("bold_font_size", _get_font_size())
		_hotkeys.add_theme_font_size_override("font_size", max(8, _get_font_size() - 1))
	if key == "hud_mode":
		_expensive_hud_dirty = true
	_hud_dirty = true


# ==================== text ====================

func _refresh(force_expensive_hud: bool = false) -> void:
	if _label == null:
		return
	# Sync hotkey hints visibility from settings
	if _hotkeys != null:
		_hotkeys.visible = _is_show_hotkey_hints()
	# Sync font size from settings
	_label.add_theme_font_size_override("normal_font_size", _get_font_size())
	_label.add_theme_font_size_override("bold_font_size", _get_font_size())
	var simple_hud: bool = _is_simple_hud()
	var tick: int = GameManager.tick_count
	if _should_rebuild_expensive_hud(tick, simple_hud, force_expensive_hud):
		_cached_expensive_hud_lines = _build_expensive_hud_lines(simple_hud)
		_cached_expensive_hud_simple = simple_hud
		_last_expensive_hud_refresh_tick = tick
		_expensive_hud_dirty = false
	var lines: Array[String] = []
	# Mode badge
	var badge: String = _mode_badge_line()
	if badge != "":
		lines.append(badge)
	if _designation_label != "":
		lines.append("[bgcolor=#583a14][color=#ffe082]  BUILD MODE: %s   (click or click-drag to place · right-click / Esc to cancel)  [/color][/bgcolor]" %
			_designation_label)
	if simple_hud:
		var first_hint: String = _first_play_hint_line()
		if not first_hint.is_empty():
			lines.append(first_hint)
		lines.append(_time_line())
		lines.append(_colony_state_line())
		lines.append(_krond_line_simple())
		var body_simple: String = _player_body_needs_line_simple()
		if body_simple != "":
			lines.append(body_simple)
		var intent_simple: String = _player_intent_hud_line()
		if intent_simple != "":
			lines.append(intent_simple)
	else:
		lines.append(_time_line())
		lines.append(_colony_state_line())
		lines.append(_player_status_line())
		lines.append(_skill_line())
		var intent_ln2: String = _player_intent_hud_line()
		if intent_ln2 != "":
			lines.append(intent_ln2)
	for cached_line in _cached_expensive_hud_lines:
		if cached_line != "":
			lines.append(cached_line)
	var next_text: String = "\n".join(lines)
	var sig: String = str(next_text.hash())
	if sig == _last_render_signature:
		return
	_last_render_signature = sig
	_label.text = next_text


func _should_rebuild_expensive_hud(tick: int, simple_hud: bool, force_expensive_hud: bool) -> bool:
	if force_expensive_hud:
		return true
	if _cached_expensive_hud_lines.is_empty():
		return true
	if simple_hud != _cached_expensive_hud_simple:
		return true
	return tick % EXPENSIVE_HUD_REFRESH_INTERVAL_TICKS == 0


func _build_expensive_hud_lines(simple_hud: bool) -> Array[String]:
	_prune_freed_pawns_in_spawner()
	var lines: Array[String] = []
	if simple_hud:
		lines.append(_settlement_identity_line())
		lines.append(_polities_realm_line())
		lines.append(_stockpile_simple_line())
		lines.append(_pawn_line_simple())
		lines.append(_profession_breakdown_line())
		var beds_ln: String = _beds_line_simple()
		if beds_ln != "":
			lines.append(beds_ln)
		var wildlife_ln: String = _wildlife_line_simple()
		if wildlife_ln != "":
			lines.append(wildlife_ln)
		var meaning_ln: String = _region_meaning_line()
		if meaning_ln != "":
			lines.append(meaning_ln)
		lines.append(_narrative_rail_line())
	else:
		lines.append(_settlement_identity_line())
		lines.append(_polities_realm_line())
		lines.append(_pawn_line())
		lines.append(_politics_line())
		lines.append(_war_status_line())
		lines.append(_kill_line())
		lines.append(_export_status_line())
		lines.append(_stockpile_line())
		lines.append(_jobs_line())
		lines.append(_wildlife_line())
		lines.append(_narrative_rail_line())
	return lines


## CanvasLayer is not drawable; intent marker rendering is temporarily disabled.
## We keep the queue/state HUD text and can re-enable visual marker through a
## dedicated Node2D overlay child in a follow-up patch.


func _ensure_history_panel() -> void:
	if _history_panel != null and is_instance_valid(_history_panel):
		return
	_history_panel = PopupPanel.new()
	_history_panel.name = "TileHistoryPanel"
	_history_panel.size = Vector2i(520, 320)
	_history_panel.visible = false
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	_history_panel.add_child(margin)
	_history_text = RichTextLabel.new()
	_history_text.name = "HistoryText"
    # bbcode_enabled disabled for runtime stability
    # _history_text.bbcode_enabled = true
	_history_text.fit_content = false
	_history_text.scroll_active = true
	_history_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	margin.add_child(_history_text)
	add_child(_history_panel)


func show_tile_history(tile_pos: Vector2i, events: Array[Dictionary]) -> void:
	_ensure_history_panel()
	if _history_panel == null or _history_text == null:
		return
	var lines: PackedStringArray = []
	lines.append("[b]History for Tile %s[/b]" % str(tile_pos))
	if events.is_empty():
		lines.append("[color=#aaaaaa]No recorded events.[/color]")
	else:
		for evt in events:
			var tick: int = int(evt.get("t", 0))
			var etype: String = str(evt.get("type", "unknown"))
			if etype == "unknown":
				var k: int = int(evt.get("k", -1))
				if k == int(WorldMemory.Kind.PAWN_DEATH):
					etype = "pawn_death"
				elif k == int(WorldMemory.Kind.ANIMAL_DEATH):
					etype = "animal_death"
			var details: String = ""
			if evt.has("action"):
				details = "Action: %s" % str(evt.get("action", ""))
			elif evt.has("c"):
				details = "Cause: %s" % str(evt.get("c", ""))
			elif evt.has("cause"):
				details = "Cause: %s" % str(evt.get("cause", ""))
			elif evt.has("amount"):
				details = "Impact: %s" % str(evt.get("amount", ""))
			lines.append("[color=yellow][Tick %04d][/color] Event: %s  %s" % [tick, etype, details])
	_history_text.text = "\n".join(lines)
	_history_panel.popup_centered()


func hide_tile_history() -> void:
	if _history_panel != null and is_instance_valid(_history_panel):
		_history_panel.hide()


func _mode_badge_line() -> String:
	match _player_mode_label:
		"OBSERVER":
			return "[bgcolor=#3a2a08][color=#ffe082]  OBSERVER MODE  (Ctrl+G to exit · right-click pawns to command · Ctrl+Z zones)  [/color][/bgcolor]"
		"INCARNATED":
			var rank: String = _player_authority_rank if _player_authority_rank != "" else "HeelKawnian"
			var hint: String = "Ctrl+T to exit"
			if rank == "Captain":
				hint = "right-click warriors to command · Ctrl+T to exit"
			elif rank == "Elder":
				hint = "right-click builders/farmers to command · Ctrl+T to exit"
			elif rank == "Ruler":
				hint = "right-click any pawn to command · Ctrl+T to exit"
			return "[bgcolor=#082a3a][color=#82e0ff]  INCARNATED · %s  (%s)  [/color][/bgcolor]" % [rank, hint]
		"WATCH", "SPECTATOR":
			return "[bgcolor=#1a1a1a][color=#888888]  WATCH MODE  (Ctrl+T play as sprite · Ctrl+G observer)  [/color][/bgcolor]"
		_:
			return "[bgcolor=#1a1a1a][color=#888888]  WATCH MODE  (Ctrl+T play as sprite · Ctrl+G observer)  [/color][/bgcolor]"


func _time_line() -> String:
	var tick: int = GameManager.tick_count
	var day_len: int = SimTime.TICKS_PER_VISUAL_DAY
	var phase: float = float(tick % day_len) / float(day_len)
	if not is_finite(phase):
		phase = 0.0
	var phase_name: String = _phase_name(phase)
	var speed_str: String = "PAUSED" if GameManager.is_paused else "%dx" % int(GameManager.game_speed)
	# In-game hour estimate: 24 notional hours across one visual day cycle (see docs/TIME_SCALE.md).
	var hour: int = int(phase * 24.0) % 24
	var year_n: int = SimTime.sim_year_index(tick)
	var day_in_year: int = SimTime.visual_day_within_sim_year(tick)
	var days_per_y: int = SimTime.visual_days_per_sim_year()
	if _is_simple_hud():
		var base: String = "[b]Year %d[/b] · [b]Day %d/%d[/b]  %02d:00  %s   [color=#cccccc]Speed:[/color] [b]%s[/b]" % [
			year_n, day_in_year, days_per_y, hour, phase_name, speed_str,
		]
		if GameManager.game_speed >= 26.0 and not GameManager.is_paused:
			var d: Dictionary = GameManager.sim_diag()
			var q: float = float(d.get("queued_ticks_est", 0.0))
			var cap: int = int(d.get("max_ticks_per_frame", 6))
			if q >= 3.0:
				base += "   [color=#ffab91]Δ~%.0f tf%d[/color]" % [q, cap]
		return base
	var y_tick: int = SimTime.tick_within_sim_year(tick)
	var base: String = "[b]Year %d[/b] · [b]Day %d/%d[/b]  %02d:00  %s   [color=#cccccc]Speed:[/color] [b]%s[/b]   [color=#888888]tick %d[/color]   [color=#666666](σ+%d)[/color]" % [
		year_n, day_in_year, days_per_y, hour, phase_name, speed_str, tick, y_tick,
	]
	if GameManager.game_speed >= 26.0 and not GameManager.is_paused:
		var d: Dictionary = GameManager.sim_diag()
		var q: float = float(d.get("queued_ticks_est", 0.0))
		var cap: int = int(d.get("max_ticks_per_frame", 6))
		if q >= 3.0:
			base += "   [color=#ffab91]Δ~%.0f tf%d[/color]" % [q, cap]
	return base


## Labor stance (M) + key demand metrics from `ColonySimServices`.
func _colony_state_line() -> String:
	var stance: String = ColonySimServices.get_stance_display()
	var fp: float = ColonySimServices.get_food_pressure()
	var hp: float = ColonySimServices.get_housing_pressure()
	var wp: float = ColonySimServices.get_warmth_pressure()
	var sp: float = ColonySimServices.get_storage_pressure()
	var cp: float = ColonySimServices.get_cooking_pressure()
	var lp: float = ColonySimServices.get_light_pressure()
	if not is_finite(fp):
		fp = 0.0
	if not is_finite(hp):
		hp = 0.0
	if not is_finite(wp):
		wp = 0.0
	if not is_finite(sp):
		sp = 0.0
	if not is_finite(cp):
		cp = 0.0
	if not is_finite(lp):
		lp = 0.0
	var stance3: String = stance
	if stance3.length() > 3:
		stance3 = stance3.substr(0, 3)
	return "[color=#c9b37c]C:[/color]%s F%d H%d W%d S%d K%d L%d" % [
		stance3,
		int(round(fp * 100.0)),
		int(round(hp * 100.0)),
		int(round(wp * 100.0)),
		int(round(sp * 100.0)),
		int(round(cp * 100.0)),
		int(round(lp * 100.0)),
	]


## Short, truthful onboarding line; disappears after a few in-game days so veterans stay uncluttered.
func _first_play_hint_line() -> String:
	var cap: int = FIRST_PLAY_HINT_VISUAL_DAYS * SimTime.TICKS_PER_VISUAL_DAY
	if GameManager.tick_count >= cap:
		return ""
	return (
		"[color=#cfd8dc][i]HeelKawn backbone:[/i][/color] click people for the sheet · "
		+ "[b]F9[/b] realm readout · [b]F10[/b] creator hub → [b]35 · Backbone / first-play[/b] (LIVE vs DEFERRED) · "
		+ "default role is observer/chronicler (incarnation optional)"
	)


## High-level world snapshot (places, memory log size, work queue).
func _world_pulse_line() -> String:
	var settlements_n: int = _visible_settlement_count_for_hud()
	var facts: int = WorldMemory.event_count()
	var js: Dictionary = JobManager.stats()
	var open_j: int = int(js.get("open", 0))
	var claimed_j: int = int(js.get("claimed", 0))
	var done_j: int = int(js.get("completed", 0))
	var fire_pits: int = ColonySimServices.get_colony_fire_pit_count() \
			if ColonySimServices != null and ColonySimServices.has_method("get_colony_fire_pit_count") else 0
	return "[color=#aed581]W:[/color]%dst %dchrk · %dfire · Work: %d/%d/%d" % [
		settlements_n,
		facts,
		fire_pits,
		open_j,
		claimed_j,
		done_j,
	]


## Lifetime totals from the append-only chronicle (what kind of story this world is building).
func _history_totals_line() -> String:
	var c: Dictionary = WorldMemory.get_event_type_counts()
	var births: int = int(c.get("birth", 0)) + int(c.get("pawn_birth", 0))
	var deaths: int = int(c.get("pawn_death", 0))
	var builds: int = int(c.get("structure_built", 0)) + int(c.get("cooperative_build", 0))
	return "[color=#9fa8da]S:[/color]B%d D%d Bd%d" % [births, deaths, builds]


## Short stockpile strip so readable mode still shows material reality.
func _stockpile_simple_line() -> String:
	if StockpileManager.zone_count() <= 0:
		return "[color=#ce93d8]Supplies:[/color] [i]no stockpiles[/i]"
	var totals: Dictionary = StockpileManager.aggregate_inventory_totals()
	var rows: Array[Dictionary] = []
	for t in Item.Type.values():
		if t == Item.Type.NONE:
			continue
		var qty: int = int(totals.get(t, 0))
		if qty > 0:
			rows.append({"t": t, "q": qty})
	if rows.is_empty():
		return "[color=#ce93d8]Supplies:[/color] [i]empty[/i]"
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["q"]) > int(b["q"]))
	var parts: Array[String] = []
	for i in range(mini(5, rows.size())):
		var row: Dictionary = rows[i]
		parts.append("%s×%d" % [Item.name_for(row["t"]), int(row["q"])])
	return "[color=#ce93d8]Supplies:[/color] %s" % " · ".join(parts)


## In-universe identity strip driven by backend settlement/memory systems.
## Keeps labels short and scans quickly during play.
func _settlement_identity_line() -> String:
	var main_node: Main = _get_main()
	if main_node == null:
		return "[color=#c9b37c]Identity:[/color] world link offline"
	var digest: Dictionary = main_node.get_camera_settlement_revival_digest()
	var cam_rk: int = int(digest.get("camera_region_key", -1))
	var profile_rk: int = int(digest.get("profile_region_key", cam_rk))
	var has_settlement: bool = bool(digest.get("has_settlement", false))
	if not has_settlement or profile_rk < 0:
		var cam_meaning: String = str(WorldMeaning.get_region_meaning_label(cam_rk)).replace("_", " ")
		return "[color=#c9b37c]Identity:[/color] Wilds · [b]%s[/b]" % cam_meaning
	var prof: Dictionary = SettlementMemory.get_settlement_profile(profile_rk)
	var st_any: Variant = SettlementMemory.get_settlement_at_region(profile_rk)
	var intent: String = "none"
	if st_any is Dictionary:
		intent = str((st_any as Dictionary).get("current_intent", "none")).to_lower()
	var meaning: String = str(WorldMeaning.get_region_meaning_label(profile_rk)).replace("_", " ")
	var rep: int = int(CulturalMemory.get_region_reputation(profile_rk))
	var rep_word: String = "neutral"
	if rep <= -3:
		rep_word = "dreaded"
	elif rep <= -2:
		rep_word = "feared"
	elif rep == -1:
		rep_word = "scarred"
	elif rep >= 1:
		rep_word = "respected"
	var state_txt: String = str(prof.get("state", "unknown")).replace("_", " ")
	var kind_txt: String = "wilds"
	if st_any is Dictionary:
		var st_d: Dictionary = st_any as Dictionary
		if bool(st_d.get("is_formal_settlement", false)):
			kind_txt = "formal"
		else:
			kind_txt = str(st_d.get("settlement_kind", "proto_site")).replace("_", " ")
	var culture_txt: String = str(prof.get("culture_name", "cautious")).replace("_", " ")
	var revival_score: int = int(prof.get("revival_score", 0))
	var war: Dictionary = SettlementMemory.get_war_profile_for_region(profile_rk)
	var gov: Dictionary = SettlementMemory.get_governance_profile_for_region(profile_rk)
	var war_state: String = str(war.get("state", "peace")).replace("_", " ")
	var gov_txt: String = str(gov.get("type", "anarchy")).replace("_", " ")
	var era_txt: String = "—"
	if CivilizationStage != null:
		var civ_snap: Dictionary = CivilizationStage.get_stage_snapshot(profile_rk)
		var civ_score: int = int(civ_snap.get("score", 0))
		var civ_stage: int = int(civ_snap.get("stage", 0))
		era_txt = CivilizationStage.get_stage_display_name(civ_stage, civ_score)
	# Myth age overlay: show the myth age name if discovered
	var myth_age_txt: String = ""
	if MythAge != null:
		var myth_name: String = MythAge.get_current_age_name()
		if myth_name != "—":
			myth_age_txt = " · [color=#e8c170]%s[/color]" % myth_name
	var polity_line: String = _polity_focus_line(st_any if st_any is Dictionary else {})
	var laws_line: String = _laws_focus_line(profile_rk)
	if _is_simple_hud():
		var base_simple: String = "[color=#c9b37c]Identity:[/color] [b]%s[/b] · %s · %s · %s · era %s%s · war %s · gov %s" % [
			state_txt.capitalize(), kind_txt, culture_txt.capitalize(), meaning, era_txt, myth_age_txt, war_state, gov_txt,
		]
		if not polity_line.is_empty():
			base_simple += " · %s" % polity_line
		if not laws_line.is_empty():
			base_simple += " · %s" % laws_line
		return base_simple
	var base_full: String = (
		"[color=#c9b37c]Identity:[/color] #%d  [b]%s[/b] · %s · %s · era %s%s · intent %s · rev %d  "
		+ "| meaning %s · rep %s(%d) · war %s · gov %s"
	) % [profile_rk, state_txt, kind_txt, culture_txt, era_txt, myth_age_txt, intent, revival_score, meaning, rep_word, rep, war_state, gov_txt]
	if not polity_line.is_empty():
		base_full += " · %s" % polity_line
	if not laws_line.is_empty():
		base_full += " · %s" % laws_line
	return base_full


func _laws_focus_line(center_rk: int) -> String:
	if center_rk < 0 or SettlementMemory == null:
		return ""
	var laws: Array = SettlementMemory.get_laws(center_rk)
	if laws.is_empty():
		return ""
	var types: PackedStringArray = PackedStringArray()
	for law_v in laws:
		if law_v is Dictionary:
			var t: String = str((law_v as Dictionary).get("type", "")).replace("_", " ")
			if not t.is_empty():
				types.append(t)
	if types.is_empty():
		return "[color=#a8c8e8]Laws:[/color] %d" % laws.size()
	return "[color=#a8c8e8]Laws:[/color] %s" % ", ".join(types.slice(0, 3))


func _polity_swatch_bbcode(st: Dictionary) -> String:
	var bc_v: Variant = st.get("border_color", null)
	var r8: int = 200
	var g8: int = 160
	var b8: int = 90
	if bc_v is PackedFloat32Array:
		var bc: PackedFloat32Array = bc_v as PackedFloat32Array
		if bc.size() >= 3:
			r8 = int(clampf(bc[0], 0.0, 1.0) * 255.0)
			g8 = int(clampf(bc[1], 0.0, 1.0) * 255.0)
			b8 = int(clampf(bc[2], 0.0, 1.0) * 255.0)
	elif bc_v is Array and (bc_v as Array).size() >= 3:
		var ba: Array = bc_v as Array
		r8 = int(clampf(float(ba[0]), 0.0, 1.0) * 255.0)
		g8 = int(clampf(float(ba[1]), 0.0, 1.0) * 255.0)
		b8 = int(clampf(float(ba[2]), 0.0, 1.0) * 255.0)
	else:
		var pid: int = int(st.get("polity_id", -1))
		if pid >= 0 and SettlementMemory != null:
			var c: Color = SettlementMemory.color_for_polity_id(pid)
			r8 = int(c.r * 255.0)
			g8 = int(c.g * 255.0)
			b8 = int(c.b * 255.0)
	return "[color=#%02x%02x%02x]■[/color]" % [r8, g8, b8]


func _polity_focus_line(st: Dictionary) -> String:
	if st.is_empty() or SettlementMemory == null:
		return ""
	if not SettlementMemory.is_polity_visible(st):
		return ""
	var nm: String = str(st.get("polity_display_name", st.get("name", ""))).strip_edges()
	if nm.is_empty():
		return ""
	var formal_tag: String = "realm" if bool(st.get("is_formal_settlement", false)) else "proto"
	return "%s [b]%s[/b] (%s)" % [_polity_swatch_bbcode(st), nm, formal_tag]


func _polities_realm_line() -> String:
	if SettlementMemory == null:
		return ""
	var formal: int = SettlementMemory.get_formal_settlement_count()
	var proto: int = SettlementMemory.get_proto_sites().size()
	var polities: int = SettlementMemory.get_active_polity_count()
	var base: String = "[color=#c9b37c]Realms:[/color] [b]%d[/b] polities · %d formal · %d proto camps" % [polities, formal, proto]
	if formal < 2 or FactionManager == null:
		return base
	var focus_rk: int = _focus_center_region()
	if focus_rk < 0:
		return base
	var rel_lines: Array[String] = FactionManager.get_nearest_polity_relation_lines(focus_rk, 3)
	if rel_lines.is_empty():
		return base
	return base + "\n[color=#c9b37c]Diplomacy:[/color] " + " · ".join(rel_lines)


func _focus_center_region() -> int:
	if _spawner == null or _spawner.pawns.is_empty():
		return -1
	var p: HeelKawnian = _spawner.pawns[0]
	if p == null or not is_instance_valid(p) or p.data == null:
		return -1
	return SettlementMemory.get_center_region_for_region(
			WorldMemory._region_key(p.data.tile_pos.x, p.data.tile_pos.y)
	) if SettlementMemory != null and WorldMemory != null else -1


static func _demand_tier(p: float) -> String:
	# 0 = low pressure (good), 1 = high (bad) — show a one-word tag for scanability.
	if p < 0.25:
		return "[color=#8bc34a]ok[/color]"
	if p < 0.55:
		return "[color=#ffcc80]watch[/color]"
	return "[color=#e57373]high[/color]"


static func _phase_name(p: float) -> String:
	if p < 0.20:    return "Night"
	if p < 0.30:    return "Dawn"
	if p < 0.45:    return "Morning"
	if p < 0.55:    return "Noon"
	if p < 0.70:    return "Afternoon"
	if p < 0.80:    return "Dusk"
	return "Night"


## Drop references to pawns that have been queue_freed; spawner can lag behind
## actual scene lifetime. Safe to run every refresh (O(n) with small n).
func _prune_freed_pawns_in_spawner() -> void:
	if _spawner == null:
		return
	var list: Array[HeelKawnian] = _spawner.pawns
	var i: int = 0
	while i < list.size():
		var p: HeelKawnian = list[i]
		if p != null and is_instance_valid(p):
			i += 1
		else:
			list.remove_at(i)


func _visible_settlement_count_for_hud() -> int:
	var m: Main = _get_main()
	if m != null:
		return m.get_visible_settlement_count()
	return SettlementMemory.settlements.size()


func _pawn_line() -> String:
	if _spawner == null:
		return "[color=#cccccc]Pawns:[/color] (none)"
	var sum_h: float = 0.0
	var sum_r: float = 0.0
	var sum_m: float = 0.0
	var hungry: int = 0
	var tired: int = 0
	var sad: int = 0
	var sleeping: int = 0
	var children_total: int = 0
	var n: int = 0
	var lead: HeelKawnian = null
	for p in _visible_pawns_for_hud():
		if not is_instance_valid(p) or p.data == null:
			continue
		if lead == null:
			lead = p
		n += 1
		var d: HeelKawnianData = p.data
		sum_h += d.hunger
		sum_r += d.rest
		sum_m += d.mood
		children_total += int(d.children_count)
		if d.hunger <= HeelKawnian.THRESHOLD_WARN: hungry += 1
		if d.rest   <= HeelKawnian.THRESHOLD_WARN: tired  += 1
		if d.mood   <= HeelKawnian.THRESHOLD_WARN: sad    += 1
		if p.get_state() == HeelKawnian.State.SLEEPING: sleeping += 1
	if n <= 0:
		return "[color=#cccccc]Pawns:[/color] (none)"
	var avg_h: float = sum_h / float(n)
	var avg_r: float = sum_r / float(n)
	var avg_m: float = sum_m / float(n)
	var affinity_line: String = ""
	if lead != null and lead.data != null:
		var top_aff: String = lead.data.highest_affinity_skill()
		var top_xp: int = lead.data.affinity_xp_for(top_aff)
		affinity_line = "   HeelKawnian: [b]%s[/b] | Aff: [b]%s[/b] | XP: [b]%d[/b]" % [
			lead.data.display_name, top_aff.capitalize(), top_xp
		]
	return "[color=#cccccc]Pawns:[/color] [b]%d[/b] (children %d)   H %s  R %s  M %s   %s%s%s%s%s" % [
		n,
		children_total,
		_color_value(avg_h), _color_value(avg_r), _color_value(avg_m),
		_alert_chip("hungry",  hungry,   "#e57373"),
		_alert_chip("tired",   tired,    "#ffd54f"),
		_alert_chip("sad",     sad,      "#90caf9"),
		_alert_chip("asleep",  sleeping, "#b39ddb"),
		affinity_line,
	]


func _pawn_line_simple() -> String:
	if _spawner == null:
		return "[color=#cccccc]People:[/color] none"
	var n: int = 0
	var avg_h: float = 0.0
	var avg_r: float = 0.0
	var avg_m: float = 0.0
	for p in _visible_pawns_for_hud():
		if p == null or not is_instance_valid(p) or p.data == null:
			continue
		n += 1
		avg_h += p.data.hunger
		avg_r += p.data.rest
		avg_m += p.data.mood
	if n <= 0:
		return "[color=#cccccc]People:[/color] none"
	avg_h /= float(n)
	avg_r /= float(n)
	avg_m /= float(n)
	return "[color=#cccccc]People:[/color] [b]%d[/b] · hunger %s · rest %s · mood %s" % [
		n,
		_color_value(avg_h),
		_color_value(avg_r),
		_color_value(avg_m),
	]


func _profession_breakdown_line() -> String:
	if _spawner == null:
		return ""
	var counts: Dictionary = {
		HeelKawnianData.Profession.FARMER: 0,
		HeelKawnianData.Profession.BUILDER: 0,
		HeelKawnianData.Profession.GATHERER: 0,
		HeelKawnianData.Profession.WARRIOR: 0,
		HeelKawnianData.Profession.SCHOLAR: 0,
		HeelKawnianData.Profession.NONE: 0,
	}
	for p in _visible_pawns_for_hud():
		if p == null or not is_instance_valid(p) or p.data == null:
			continue
		var prof: int = int(p.data.current_profession)
		if counts.has(prof):
			counts[prof] = int(counts[prof]) + 1
		else:
			counts[HeelKawnianData.Profession.NONE] = int(counts[HeelKawnianData.Profession.NONE]) + 1
	var parts: Array[String] = []
	var farmer_n: int = int(counts[HeelKawnianData.Profession.FARMER])
	var builder_n: int = int(counts[HeelKawnianData.Profession.BUILDER])
	var gatherer_n: int = int(counts[HeelKawnianData.Profession.GATHERER])
	var warrior_n: int = int(counts[HeelKawnianData.Profession.WARRIOR])
	var scholar_n: int = int(counts[HeelKawnianData.Profession.SCHOLAR])
	var none_n: int = int(counts[HeelKawnianData.Profession.NONE])
	if farmer_n > 0:
		parts.append("[color=#d9a832]Farm:%d[/color]" % farmer_n)
	if builder_n > 0:
		parts.append("[color=#999999]Bld:%d[/color]" % builder_n)
	if gatherer_n > 0:
		parts.append("[color=#33cc44]Gth:%d[/color]" % gatherer_n)
	if warrior_n > 0:
		parts.append("[color=#e63333]War:%d[/color]" % warrior_n)
	if scholar_n > 0:
		parts.append("[color=#4d80e6]Sch:%d[/color]" % scholar_n)
	if none_n > 0:
		parts.append("[color=#888888]?:%d[/color]" % none_n)
	if parts.is_empty():
		return ""
	return "[color=#cccccc]Roles:[/color] " + " · ".join(parts)


func _krond_line_simple() -> String:
	if _player_pawn == null or _player_pawn.data == null:
		return "[color=#cccccc]Krond:[/color] -"
	var kr: float = float(_player_pawn.data.available_krond)
	var kint: int = int(round(kr))
	return "[color=#ffd54f]Krond:[/color] [b]%d[/b]" % [kint]


func _player_body_needs_text() -> String:
	if not _is_player_incarnated_for_hud():
		return ""
	if not _has_player_needs:
		if _player_pawn == null or not is_instance_valid(_player_pawn) or _player_pawn.data == null:
			return ""
		_player_hunger = clampf(float(_player_pawn.data.hunger), 0.0, 100.0)
		_player_rest = clampf(float(_player_pawn.data.rest), 0.0, 100.0)
		_has_player_needs = true
	return "hunger %s · rest %s" % [
		_color_value(_player_hunger),
		_color_value(_player_rest),
	]


func _player_body_needs_line_simple() -> String:
	var needs: String = _player_body_needs_text()
	if needs == "":
		return ""
	return "[color=#90caf9]Body:[/color] %s" % needs


func _is_player_incarnated_for_hud() -> bool:
	var main_node: Node = _get_main()
	if main_node == null or not main_node.has_method("is_player_incarnated"):
		return false
	return bool(main_node.call("is_player_incarnated"))


func _stockpile_line() -> String:
	var zc: int = StockpileManager.zone_count()
	if zc <= 0:
		return "[color=#cccccc]Stockpiles:[/color] (none)"
	var totals: Dictionary = StockpileManager.aggregate_inventory_totals()
	var parts: Array[String] = []
	# Keep the render order stable so the HUD doesn't flicker as the dict
	# hash ordering changes. Item.Type enum values are dense so iterating
	# over the enum keeps this cheap.
	for t in Item.Type.values():
		if t == Item.Type.NONE:
			continue
		var qty: int = totals.get(t, 0)
		if qty <= 0:
			continue
		parts.append("[color=%s]%s[/color] [b]%d[/b]" % [
			Item.color_for(t).to_html(false), Item.name_for(t), qty
		])
	var inv_text: String = " · ".join(parts) if not parts.is_empty() else "[color=#888888]empty[/color]"
	return "[color=#cccccc]Stockpiles (%d zone%s):[/color] %s" % [
		zc, "" if zc == 1 else "s", inv_text
	]


func _jobs_line() -> String:
	var s: Dictionary = JobManager.stats()
	var fw: int = JobManager.active_count_of_type(Job.Type.FORAGE)
	var mn: int = JobManager.active_count_of_type(Job.Type.MINE)
	var mw: int = JobManager.active_count_of_type(Job.Type.MINE_WALL)
	var ch: int = JobManager.active_count_of_type(Job.Type.CHOP)
	var hu: int = JobManager.active_count_of_type(Job.Type.HUNT)
	var bd: int = JobManager.active_count_of_type(Job.Type.BUILD_BED)
	var bw: int = JobManager.active_count_of_type(Job.Type.BUILD_WALL)
	var bo: int = JobManager.active_count_of_type(Job.Type.BUILD_DOOR)
	var beds_built: int = _world.bed_count() if _world != null else 0
	return "[color=#cccccc]Jobs:[/color] [b]%d[/b] open  [b]%d[/b] claimed   F %d · M %d · TM %d · C %d · H %d · B %d · W %d · D %d   [color=#dcb478]Beds[/color] [b]%d[/b]   [color=#888888](done %d)[/color]" % [
		s.open, s.claimed, fw, mn, mw, ch, hu, bd, bw, bo, beds_built, s.completed
	]


func _jobs_line_simple() -> String:
	var s: Dictionary = JobManager.stats()
	var beds_built: int = _world.bed_count() if _world != null else 0
	var top_jobs: String = _top_open_jobs_summary(3)
	var role_hint: String = _colony_role_hint_line()
	var extra: String = ""
	if not top_jobs.is_empty():
		extra += " · top %s" % top_jobs
	if not role_hint.is_empty():
		extra += " · %s" % role_hint
	return "[color=#cccccc]Work:[/color] open [b]%d[/b] · claimed [b]%d[/b] · done [b]%d[/b] · beds [b]%d[/b]%s" % [
		int(s.get("open", 0)),
		int(s.get("claimed", 0)),
		int(s.get("completed", 0)),
		beds_built,
		extra,
	]


func _top_open_jobs_summary(max_types: int) -> String:
	if JobManager == null:
		return ""
	var tops: Array[Dictionary] = JobManager.get_top_open_job_types(max_types)
	if tops.is_empty():
		return ""
	var parts: PackedStringArray = PackedStringArray()
	for entry in tops:
		var label: String = str(entry.get("label", "?"))
		var count: int = int(entry.get("count", 0))
		if count > 0:
			parts.append("%s×%d" % [label, count])
	return ", ".join(parts)


func _colony_role_hint_line() -> String:
	if _spawner == null:
		return ""
	var farmers: int = 0
	var builders: int = 0
	var gatherers: int = 0
	for p in _spawner.pawns:
		if p == null or not is_instance_valid(p) or p.data == null:
			continue
		match int(p.data.current_profession):
			HeelKawnianData.Profession.FARMER:
				farmers += 1
			HeelKawnianData.Profession.BUILDER:
				builders += 1
			HeelKawnianData.Profession.GATHERER:
				gatherers += 1
	var best: int = maxi(farmers, maxi(builders, gatherers))
	if best <= 0:
		return ""
	if farmers == best and farmers >= builders and farmers >= gatherers:
		return "[color=#a5d6a7]role: foragers/farmers[/color]"
	if builders == best and builders >= gatherers:
		return "[color=#dcb478]role: builders[/color]"
	if gatherers == best:
		return "[color=#90caf9]role: gatherers[/color]"
	return ""


## Simple beds-only line for readable HUD — players care about shelter, not job queue internals.
func _beds_line_simple() -> String:
	var beds_built: int = _world.bed_count() if _world != null else 0
	if beds_built <= 0:
		return ""
	return "[color=#dcb478]Beds:[/color] [b]%d[/b]" % beds_built


## Shorter wildlife line for readable HUD — just total count and trend, no nearby/threat details.
func _wildlife_line_simple() -> String:
	if _wildlife_sample_tick == 0:
		return ""
	var t: int = int(_wildlife_snapshot.get("total", 0))
	var tail: String = ""
	if _wildlife_history.size() >= 3:
		var recent_avg: float = 0.0
		var older_avg: float = 0.0
		var split: int = _wildlife_history.size() / 2
		for i in range(split):
			older_avg += float(_wildlife_history[i])
		for i in range(split, _wildlife_history.size()):
			recent_avg += float(_wildlife_history[i])
		older_avg /= float(split)
		recent_avg /= float(_wildlife_history.size() - split)
		var trend_ratio: float = recent_avg / maxf(1.0, older_avg)
		if trend_ratio > 1.1:
			tail = " ▲"
		elif trend_ratio < 0.9:
			tail = " ▼"
	return "[color=#a5d6a7]Wildlife:[/color] %d%s" % [t, tail]


func _player_status_line() -> String:
	var main_node: Main = _get_main()
	if main_node == null:
		return "[color=#cccccc]PLAYER PAWN:[/color] --  |  QUEUE: [b]0[/b]  |  STATE: [b]offline[/b]"
	var pawn_id: int = main_node.get_player_pawn_id()
	var queue_count: int = main_node.get_player_queue_size()
	var state: String = main_node.get_player_action_state()
	var pawn_id_text: String = str(pawn_id) if pawn_id >= 0 else "--"
	var body_text: String = _player_body_needs_text()
	var body_suffix: String = "" if body_text == "" else "  |  BODY: %s" % body_text
	return "[color=#cccccc]PLAYER PAWN:[/color] [b]%s[/b]  |  QUEUE: [b]%d[/b]  |  STATE: [b]%s[/b]%s" % [
		pawn_id_text, queue_count, state, body_suffix
	]


func _skill_line() -> String:
	if _player_pawn == null or not is_instance_valid(_player_pawn) or _player_pawn.data == null:
		return "👤 HeelKawnian [--]: Profession [None] | XP: 0/100"
	var d: HeelKawnianData = _player_pawn.data
	var pawn_id: int = int(d.id)
	var prof_name: String = d.profession_name()
	var xp: int = d.profession_progress_xp()
	return "👤 HeelKawnian [%d]: Profession [%s] | XP: %d/100" % [pawn_id, prof_name, xp]


func _export_status_line() -> String:
	var main_node: Main = _get_main()
	var milestone: int = SimTime.KERNEL_DIAGNOSTIC_TICK
	if main_node == null:
		return "EXPORT / kernel checkpoint: tick %d | Status: Waiting" % milestone
	var status: String = "Complete" if main_node.is_kernel_diagnostic_complete() else "Waiting"
	if GameManager.tick_count >= milestone:
		return "EXPORT / kernel checkpoint: tick %d | Status: %s" % [milestone, status]
	return "EXPORT / kernel checkpoint: tick %d | Status: Waiting" % milestone


## One-line snapshot for AI/debug sessions (HUD copy-paste; reduces need for console spam).
func _session_diag_line() -> String:
	var d: Dictionary = GameManager.sim_diag()
	var wc: int = WorldMemory.event_count()
	var js: Dictionary = JobManager.stats()
	var open_j: int = int(js.get("open", 0))
	var claimed_j: int = int(js.get("claimed", 0))
	var settlements_n: int = _visible_settlement_count_for_hud()
	var q: float = float(d.get("queued_ticks_est", 0.0))
	var acc_cap: int = int(d.get("max_accumulated_ticks", 16))
	var tpf: int = int(d.get("max_ticks_per_frame", 8))
	var tick_n: int = int(d.get("tick_count", 0))
	var cal: String = "Y%d D%d/%d" % [
		SimTime.sim_year_index(tick_n),
		SimTime.visual_day_within_sim_year(tick_n),
		SimTime.visual_days_per_sim_year(),
	]
	var base: String = (
		"[color=#9e9e9e][Session][/color] %s | %.0fx pend~%.1f/%dt acc=%.3fs | tf=%d ac=%d | wm_ev=%d jobs %do/%dc st=%d"
		% [
			cal,
			float(d.get("speed", 1.0)),
			q,
			acc_cap,
			float(d.get("accumulator_sec", 0.0)),
			tpf,
			acc_cap,
			wc,
			open_j,
			claimed_j,
			settlements_n,
		]
	)
	if not _is_show_refresh_diag():
		return base
	var lag: int = max(0, tick_n - _last_refresh_tick)
	return "%s | hud iv=%d coarse=%d lag=%dt" % [base, _last_refresh_stride, _last_coarse_gate, lag]


func _refresh_stride_for_speed(speed: float) -> int:
	if speed >= 100.0:
		if GameSettings != null:
			return int(GameSettings.get_value("hud_refresh_max"))
		return REFRESH_EVERY_N_TICKS_MAX
	if speed >= 50.0:
		if GameSettings != null:
			return int(GameSettings.get_value("hud_refresh_extreme"))
		return REFRESH_EVERY_N_TICKS_EXTREME
	if speed >= 26.0:
		if GameSettings != null:
			return int(GameSettings.get_value("hud_refresh_ultra"))
		return REFRESH_EVERY_N_TICKS_ULTRA
	if speed >= 12.0:
		if GameSettings != null:
			return int(GameSettings.get_value("hud_refresh_fast"))
		return REFRESH_EVERY_N_TICKS_FAST
	return REFRESH_EVERY_N_TICKS


func _coarse_gate_for_speed(speed: float) -> int:
	if speed >= 100.0:
		return 45
	if speed >= 50.0:
		return 30
	if speed >= 12.0:
		return 20
	return 10


func _kill_line() -> String:
	var main_node: Main = _get_main()
	if main_node == null:
		return "Kills: 0"
	return "Kills: %d" % int(main_node.get_kill_count())


func _politics_line() -> String:
	var main_node: Main = _get_main()
	if main_node == null:
		return "Settlement State: Anarchy | Ruler: None | Player Status: None"
	var gp: Dictionary = main_node.get_player_governance_profile()
	var gtype_raw: String = str(gp.get("type", "anarchy"))
	var gtype: String = "Anarchy"
	if gtype_raw == "monarchy":
		gtype = "Monarchy"
	elif gtype_raw == "council":
		gtype = "Council"
	var base: String = "Settlement State: %s | Ruler: %s | Player Status: %s" % [
		gtype,
		str(gp.get("ruler_name", "None")),
		str(gp.get("player_status", "None")),
	]
	if bool(gp.get("edicts_unlocked", false)):
		base += " | EDICTS UNLOCKED"
	return base


func _war_status_line() -> String:
	var main_node: Main = _get_main()
	if main_node == null:
		return "WAR STATUS: Peace | RANK: Grunt"
	var wp: Dictionary = main_node.get_player_war_profile()
	var ws: String = String(wp.get("state", "peace")).to_lower()
	var ws_label: String = "Peace"
	if ws == "proposed":
		ws_label = "Proposed (Vote Pending)"
	elif ws == "mobilizing":
		ws_label = "Proposed (Vote Pending)"
	elif ws == "at_war":
		ws_label = "Active"
	elif ws == "truce":
		ws_label = "Truce"
	var rank_raw: String = String(main_node.get_player_military_rank()).to_lower()
	var rank_label: String = rank_raw.capitalize()
	if rank_raw == "battlemaster":
		rank_label = "BattleMaster"
	var out: String = "WAR STATUS: %s | RANK: %s" % [ws_label, rank_label]
	if rank_raw == "battlemaster":
		out += " | TACTICAL MODE: Issue Orders"
	return out


func _sample_wildlife(current_tick: int) -> void:
	var spawner: AnimalSpawner = null
	if has_meta("animal_spawner"):
		var local_meta: Variant = get_meta("animal_spawner")
		if local_meta is AnimalSpawner:
			spawner = local_meta as AnimalSpawner
	if spawner == null and _animal_spawner != null and is_instance_valid(_animal_spawner):
		spawner = _animal_spawner
	if spawner == null and _world != null and _world.has_meta("animal_spawner"):
		var world_meta: Variant = _world.get_meta("animal_spawner")
		if world_meta is AnimalSpawner:
			spawner = world_meta as AnimalSpawner
			_animal_spawner = spawner
	if spawner == null:
		return
	_wildlife_prev_snapshot = _wildlife_snapshot.duplicate()
	_wildlife_snapshot = spawner.get_live_wildlife_snapshot()
	var probe_tile: Vector2i = _wildlife_probe_tile()
	_wildlife_nearby_snapshot = spawner.get_nearby_wildlife_snapshot(probe_tile, WILDLIFE_NEARBY_RADIUS_TILES)
	_wildlife_sample_tick = current_tick
	_wildlife_history.append(int(_wildlife_snapshot.get("total", 0)))
	if _wildlife_history.size() > WILDLIFE_HISTORY_SIZE:
		_wildlife_history.pop_front()
	_momentum_spark = ""
	for i in range(1, _wildlife_history.size()):
		var delta: int = _wildlife_history[i] - _wildlife_history[i - 1]
		if delta > 0:
			_momentum_spark += "↑"
		elif delta < 0:
			_momentum_spark += "↓"
		else:
			_momentum_spark += "→"
	while _momentum_spark.length() < WILDLIFE_HISTORY_SIZE - 1:
		_momentum_spark = "→" + _momentum_spark


func _wildlife_total_span() -> String:
	## Rolling min/max of total headcount over [member _wildlife_history] (validation / trend readout).
	if _wildlife_history.size() < 2:
		return ""
	var lo: int = 1_000_000_000
	var hi: int = 0
	for v in _wildlife_history:
		var n: int = int(v)
		lo = mini(lo, n)
		hi = maxi(hi, n)
	if lo > hi:
		return ""
	return "T %d…%d" % [lo, hi]


func _region_meaning_line() -> String:
	if WorldMeaning == null:
		return ""
	# Show meaning tags for the region the camera is centered on
	var cam: Camera2D = get_viewport().get_camera_2d() if get_viewport() != null else null
	if cam == null:
		return ""
	var cam_tile: Vector2i = Vector2i(int(cam.global_position.x / 16.0), int(cam.global_position.y / 16.0))
	if WorldMemory == null:
		return ""
	var rk: int = WorldMemory._region_key(cam_tile.x, cam_tile.y)
	var tags: PackedStringArray = WorldMeaning.get_region_tags(rk)
	if tags.is_empty():
		return ""
	var tag_str: String = " | ".join(tags.slice(0, 4))
	return "[color=#cccccc]Region:[/color] [color=#aaddaa]%s[/color]" % tag_str


func _wildlife_line() -> String:
	if _wildlife_sample_tick == 0:
		return "🦌 Wildlife: Scanning ecosystem..."
	var r: int = int(_wildlife_snapshot.get("rabbit", 0))
	var d: int = int(_wildlife_snapshot.get("deer", 0))
	var t: int = int(_wildlife_snapshot.get("total", 0))
	var span: String = _wildlife_total_span()
	var tail: String = ""
	
	# Trend validation: compute trend direction from history
	if _wildlife_history.size() >= 3:
		var recent_avg: float = 0.0
		var older_avg: float = 0.0
		var split: int = _wildlife_history.size() / 2
		for i in range(split):
			older_avg += float(_wildlife_history[i])
		for i in range(split, _wildlife_history.size()):
			recent_avg += float(_wildlife_history[i])
		older_avg /= float(split)
		recent_avg /= float(_wildlife_history.size() - split)
		
		var trend_ratio: float = recent_avg / maxf(1.0, older_avg)
		if trend_ratio > 1.1:
			tail = "▲"  # Growing
		elif trend_ratio < 0.9:
			tail = "▼"  # Declining
		else:
			tail = "▬"  # Stable
	else:
		tail = _momentum_spark
	
	var nr: int = int(_wildlife_nearby_snapshot.get("rabbit", 0))
	var nd: int = int(_wildlife_nearby_snapshot.get("deer", 0))
	var nt: int = int(_wildlife_nearby_snapshot.get("total", 0))
	var near_dist: int = int(_wildlife_nearby_snapshot.get("nearest_any_dist", -1))
	var near_str: String = "n/a" if near_dist < 0 else str(near_dist)
	var threat_level: String = str(_wildlife_nearby_snapshot.get("threat_level", "low"))
	var threat_icon: String = "!" if threat_level == "low" else "!!"
	if threat_level == "high":
		threat_icon = "!!!"
	return "🦌 Wildlife: R:%d D:%d T:%d %s %s | Nearby(%dt): R:%d D:%d T:%d nearest:%s threat:%s %s" % [
		r, d, t, span, tail,
		WILDLIFE_NEARBY_RADIUS_TILES, nr, nd, nt, near_str, threat_level.to_upper(), threat_icon
	]


func _wildlife_probe_tile() -> Vector2i:
	if _player_pawn != null and is_instance_valid(_player_pawn) and _player_pawn.data != null:
		return _player_pawn.data.tile_pos
	var main_node: Main = _get_main()
	if main_node != null:
		var camera: Camera2D = main_node.get_node_or_null("Camera2D") as Camera2D
		if camera != null and _world != null:
			return _world.world_to_tile(camera.global_position)
	return Vector2i(WorldData.WIDTH / 2, WorldData.HEIGHT / 2)


## Diagnostic: breakdown of wildlife trend calculation for validation
func get_wildlife_trend_diagnostic() -> Dictionary:
	if _wildlife_history.size() < 3:
		return {
			"status": "insufficient_data",
			"history_size": _wildlife_history.size(),
			"history": _wildlife_history.duplicate(),
		}
	
	var recent_avg: float = 0.0
	var older_avg: float = 0.0
	var split: int = _wildlife_history.size() / 2
	for i in range(split):
		older_avg += float(_wildlife_history[i])
	for i in range(split, _wildlife_history.size()):
		recent_avg += float(_wildlife_history[i])
	older_avg /= float(split)
	recent_avg /= float(_wildlife_history.size() - split)
	
	var trend_ratio: float = recent_avg / maxf(1.0, older_avg)
	var trend_label: String = "stable"
	if trend_ratio > 1.1:
		trend_label = "growing"
	elif trend_ratio < 0.9:
		trend_label = "declining"
	
	return {
		"status": "ok",
		"history_size": _wildlife_history.size(),
		"history": _wildlife_history.duplicate(),
		"split_index": split,
		"older_avg": older_avg,
		"recent_avg": recent_avg,
		"trend_ratio": trend_ratio,
		"trend_label": trend_label,
		"momentum_spark": _momentum_spark,
		"sample_tick": _wildlife_sample_tick,
	}


func _player_intent_hud_line() -> String:
	var u: int = PlayerIntentQueue.unprocessed_count()
	var pin: String = ""
	var main_node: Main = _get_main()
	if main_node != null and main_node.has_method("get_chronicler_pin_zone_id"):
		pin = str(main_node.call("get_chronicler_pin_zone_id"))
	if u <= 0 and pin.is_empty():
		return ""
	var parts: PackedStringArray = PackedStringArray()
	if u > 0:
		parts.append("queue %d" % u)
	if not pin.is_empty():
		parts.append("pin zone %s" % pin)
	return "📌 Chronicler: %s" % " · ".join(parts)


## Compact high-signal narrative rail (DF/CK/RimWorld-style summary strip).
## Purposefully filters out spammy low-signal events (e.g. job_completed) and
## reports only identity/meaning-relevant shifts for in-universe readability.
## Cached: only recomputes when the WorldMemory event count changes, avoiding
## expensive event log iteration every HUD refresh.
func _narrative_rail_line() -> String:
	var current_count: int = WorldMemory.event_count()
	if current_count == _narrative_cache_event_count and _narrative_cache != "":
		return _narrative_cache
	_narrative_cache_event_count = current_count
	var ev: Array = []
	var main_node: Main = _get_main()
	if main_node != null:
		var digest: Dictionary = main_node.get_camera_settlement_revival_digest()
		var profile_rk: int = int(digest.get("profile_region_key", -1))
		if bool(digest.get("has_settlement", false)) and profile_rk >= 0:
			ev = WorldMemory.get_recent_events_for_settlement(profile_rk, 96, true)
	if ev.is_empty():
		ev = WorldMemory.get_recent_events(64)
	if ev.is_empty():
		_narrative_cache = "Chronicle: world is quiet"
		return _narrative_cache
	var entries: PackedStringArray = PackedStringArray()
	for i in range(ev.size() - 1, -1, -1):
		if entries.size() >= 5:
			break
		var e_any: Variant = ev[i]
		if not (e_any is Dictionary):
			continue
		var e: Dictionary = e_any as Dictionary
		var typ: String = str(e.get("type", ""))
		var tick: int = int(e.get("tick", e.get("t", 0)))
		var line: String = _narrative_line_for_event(typ, e)
		if line.is_empty():
			continue
		entries.append("[t%d] %s" % [tick, line])
	if entries.is_empty():
		_narrative_cache = "Chronicle: no major shifts"
		return _narrative_cache
	_narrative_cache = "Chronicle: %s" % "  •  ".join(entries)
	return _narrative_cache


func _narrative_line_for_event(typ: String, e: Dictionary) -> String:
	if bool(e.get("first_of_type", false)):
		return "first: %s" % typ.replace("_", " ")
	match typ:
		"structure_built":
			return "new structures were completed"
		"birth", "pawn_birth":
			var child_name: String = str(e.get("pawn_name", "a child")).strip_edges()
			if child_name.is_empty():
				child_name = "a child"
			var pa: String = str(e.get("parent_a_name", "")).strip_edges()
			var pb: String = str(e.get("parent_b_name", "")).strip_edges()
			if not pa.is_empty() and not pb.is_empty():
				return "birth: %s to %s + %s" % [child_name, pa, pb]
			return "birth: %s" % child_name
		"cooperative_build":
			return "crews raised new structures together"
		"knowledge_discovery":
			var kt: String = str(e.get("knowledge_type", "?"))
			return "new knowledge discovered (k=%s)" % kt
		"knowledge_rediscovery":
			return "lost knowledge was rediscovered"
		"social_bond_milestone":
			var an: String = str(e.get("a_name", "A"))
			var bn: String = str(e.get("b_name", "B"))
			var m: int = int(e.get("milestone", 0))
			return "%s + %s bond deepened (%d)" % [an, bn, m]
		"social_meeting":
			var ma: String = str(e.get("a_name", "A"))
			var mb: String = str(e.get("b_name", "B"))
			return "%s met %s" % [ma, mb]
		"governance_change":
			var g: String = str(e.get("governance_type", "anarchy")).replace("_", " ")
			return "governance became %s" % g
		"settlement_intent_shift":
			var old_i: String = str(e.get("old_intent", "unknown")).to_lower()
			var new_i: String = str(e.get("new_intent", "unknown")).to_lower()
			return "intent shifted %s→%s" % [old_i, new_i]
		"player_intent":
			return "chronicler note recorded"
		"pawn_death":
			return ChronicleFeed._pawn_death_chronicle_line(e)
		"famine_warning":
			var fp: float = float(e.get("food_pressure", 0.0))
			if fp > 0.0:
				return "famine — food pressure %.0f%%" % [fp * 100.0]
			return "famine — reserves critical"
		"first_hearth_in_polity":
			var pol: String = str(e.get("polity_name", "the realm")).strip_edges()
			return "first hearth of %s" % pol
		"settlement_abandoned":
			var sn: String = str(e.get("settlement_name", "a settlement")).strip_edges()
			return "%s abandoned" % sn
		"profession_mastered":
			var who_m: String = str(e.get("pawn_name", "someone")).strip_edges()
			var branch_m: String = str(e.get("branch_skill", "")).strip_edges()
			return "%s mastered %s" % [who_m, branch_m if not branch_m.is_empty() else str(e.get("tier", "skill"))]
		"dynasty_line":
			var dyn: String = str(e.get("narrative", "")).strip_edges()
			if not dyn.is_empty():
				return dyn
			return "a dynasty line continued"
		"diplomatic_incident":
			var da: String = str(e.get("polity_a_name", "realm")).strip_edges()
			var db: String = str(e.get("polity_b_name", "realm")).strip_edges()
			return "diplomatic incident: %s vs %s" % [da, db]
		"skirmish_started":
			return "skirmish — hostile bands clash"
		"battle_resolved":
			return "skirmish ended — casualties counted"
		"trade_route_opened":
			return "formal trade route opened"
		"polity_founded", "settlement_formalized":
			var narr: String = str(e.get("narrative", "")).strip_edges()
			if not narr.is_empty():
				return narr.replace("[b]", "").replace("[/b]", "")
			var pn: String = str(e.get("polity_name", "")).strip_edges()
			if not pn.is_empty():
				return "realm: %s" % pn
			return "a realm was founded"
		"animal_death":
			return "wildlife was culled"
		"teaching_success":
			var teacher: String = str(e.get("teacher_name", "A")).strip_edges()
			var student: String = str(e.get("student_name", "B")).strip_edges()
			if not teacher.is_empty() and not student.is_empty():
				return "%s taught %s" % [teacher, student]
			return "teaching succeeded"
		"teaching_failure":
			return "a teaching attempt failed"
		"knowledge_sealed":
			var nm: String = str(e.get("carrier_name", "a scholar")).strip_edges()
			return "%s died with unfulfilled teaching obligations" % nm
		"knowledge_lost":
			return "knowledge was lost to the settlement"
		"knowledge_at_risk":
			return "knowledge at risk — only one carrier remains"
		"knowledge_crisis":
			return "knowledge crisis — multiple skills at risk"
		"authority_change":
			var nm: String = str(e.get("pawn_name", "someone")).strip_edges()
			var ctx: String = str(e.get("context", "")).replace("_", " ")
			return "%s gained %s authority" % [nm, ctx]
		"authority_points_added":
			return "authority recognized"
		"authority_vacuum":
			return "authority vacuum — no recognized leader"
		"diaspora_exile":
			var count: int = int(e.get("exile_count", 0))
			return "diaspora — %d pawns exiled" % maxi(count, 1)
		"diaspora_grief":
			var nm: String = str(e.get("pawn_name", "someone")).strip_edges()
			return "%s grieved for their lost home" % nm
		"cultural_exposure":
			var nm: String = str(e.get("pawn_name", "someone")).strip_edges()
			var custom: String = str(e.get("custom_tag", "a custom")).replace("_", " ")
			return "%s absorbed a new custom: %s" % [nm, custom]
		"collapse_warning":
			return "collapse warning — settlement under strain"
		"environmental_degradation":
			return "environmental degradation detected"
		"economic_boom":
			return "economic boom — surplus detected"
		"market_crash":
			return "market crash — resources scarce"
		"religious_schism":
			return "religious schism — beliefs diverged"
		"religious_conversion":
			var nm: String = str(e.get("pawn_name", "someone")).strip_edges()
			return "%s underwent a religious conversion" % nm
		"sacred_site_established":
			return "a sacred site was established"
		"ritual_performed":
			return "a ritual was performed"
		"bloodline_founded":
			var nm: String = str(e.get("founder_name", "a founder")).strip_edges()
			return "%s founded a bloodline" % nm
		"bloodline_member_added":
			return "a bloodline gained a new member"
		"bloodline_extinct":
			var nm: String = str(e.get("bloodline_name", "a bloodline")).strip_edges()
			return "the %s bloodline went extinct" % nm
		"food_spoiled":
			return "food spoiled in storage"
		"seeds_planted":
			return "seeds were planted"
		"crop_harvested":
			return "crops were harvested"
		"starvation_event":
			return "starvation — settlement is hungry"
		"injury":
			var nm: String = str(e.get("pawn_name", "someone")).strip_edges()
			return "%s was injured" % nm
		"war_battle_spawned":
			return "enemies appeared — battle imminent"
		"war_proposed":
			return "war was proposed"
		"entity_decay":
			return "an entity began to decay"
		"entity_loss":
			return "an entity was lost"
		"collapse_metric_change":
			return "collapse metrics shifted"
		"emergent_pattern_detected":
			var pattern: String = str(e.get("pattern", "")).replace("_", " ")
			if not pattern.is_empty():
				return "emergent pattern: %s" % pattern
			return "emergent pattern detected"
		"historical_saturation":
			return "historical saturation"
		"job_completed":
			# Too noisy for the rail; totals live in Story / Work lines.
			return ""
		_:
			# Surface rarer settlement / world events without spamming routine jobs.
			if typ.begins_with("settlement") or typ.contains("abandon") or typ.contains("revival") or typ.contains("rebirth"):
				return typ.replace("_", " ")
			return ""


# ==================== formatting helpers ====================

static func _color_value(v: float) -> String:
	# Same thresholds the pawn AI uses, so the HUD agrees with the warn / crit
	# print spam.
	if v <= HeelKawnian.THRESHOLD_CRIT:
		return "[color=#e57373][b]%2.0f[/b][/color]" % v   # red
	if v <= HeelKawnian.THRESHOLD_WARN:
		return "[color=#ffd54f][b]%2.0f[/b][/color]" % v   # amber
	return "[color=#a5d6a7]%2.0f[/color]" % v               # green


static func _alert_chip(label: String, count: int, color_hex: String) -> String:
	if count <= 0:
		return ""
	return "[color=%s]%dx %s[/color]  " % [color_hex, count, label]


func _recenter() -> void:
	# Anchor HUD elements to screen edges post-fullscreen resize
	var sw = get_viewport().get_visible_rect().size.x
	var sh = get_viewport().get_visible_rect().size.y
	# Example: Ensure bottom panel stays at bottom
	if has_node("BottomPanel"):
		get_node("BottomPanel").position.y = sh - get_node("BottomPanel").size.y
