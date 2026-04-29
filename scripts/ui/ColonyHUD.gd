class_name ColonyHUD
extends CanvasLayer

## Always-on heads-up display rendered in screen space (CanvasLayer = doesn't
## move with the camera). Refreshes on deterministic tick cadence with
## high-speed throttling, so numbers stay live without per-frame UI churn.
##
## Reads pawn list from PawnSpawner, stockpile from World, time + speed from
## GameManager, and job counts from JobManager (autoload).

const REFRESH_EVERY_N_TICKS: int = 1
const REFRESH_EVERY_N_TICKS_FAST: int = 2
const REFRESH_EVERY_N_TICKS_ULTRA: int = 4
const REFRESH_EVERY_N_TICKS_EXTREME: int = 6
const REFRESH_EVERY_N_TICKS_MAX: int = 8
const WILDLIFE_SAMPLE_EVERY_TICKS: int = 20
const WILDLIFE_HISTORY_SIZE: int = 8
const SHOW_REFRESH_DIAG: bool = true

const PANEL_BG: Color = Color(0.05, 0.06, 0.08, 0.78)
const PANEL_BORDER: Color = Color(0.85, 0.78, 0.40, 0.70)

# Tuned to be unobtrusive: thin top-left strip, easy to read, doesn't
# eat the world.
const FONT_SIZE_BODY: int = 14
const FONT_SIZE_HOTKEYS: int = 12
const PANEL_PAD_X: int = 6
const PANEL_PAD_Y: int = 4
## Readability mode: bigger, simpler HUD for at-a-glance play.
const SIMPLE_READABLE_HUD: bool = true

const HOTKEY_HINTS: String = "SPACE pause · F5 save · F8 load · K sprite · F10 reports"

@onready var _panel: PanelContainer = $Panel
@onready var _label: RichTextLabel = $Panel/Margin/VBox/Body
@onready var _hotkeys: Label = $Panel/Margin/VBox/Hotkeys
var _history_panel: PopupPanel = null
var _history_text: RichTextLabel = null

var _world: World = null
var _spawner: PawnSpawner = null
var _animal_spawner: AnimalSpawner = null
## Empty string when no designation mode is active. Otherwise "Bed" / "Wall" / etc.
var _designation_label: String = ""
var _wildlife_snapshot: Dictionary = {"rabbit": 0, "deer": 0, "total": 0}
var _wildlife_prev_snapshot: Dictionary = {"rabbit": 0, "deer": 0, "total": 0}
var _wildlife_sample_tick: int = 0
var _wildlife_history: Array[int] = []
var _momentum_spark: String = "........"
var _player_input_buffer: PlayerInputBuffer = null
var _player_pawn: Pawn = null
var _hud_dirty: bool = true
var _last_refresh_stride: int = REFRESH_EVERY_N_TICKS
var _last_coarse_gate: int = 10
var _last_refresh_tick: int = 0
var _last_render_signature: String = ""


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
	_apply_panel_style()
	_ensure_history_panel()
	_hotkeys.text = HOTKEY_HINTS
	_refresh()


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
	_refresh()


func set_player_control_refs(input_buffer: PlayerInputBuffer, player_pawn: Pawn) -> void:
	if _player_input_buffer != null and _player_input_buffer.intent_ready.is_connected(_on_intent_ready):
		_player_input_buffer.intent_ready.disconnect(_on_intent_ready)
	_player_input_buffer = input_buffer
	_player_pawn = player_pawn
	if _player_input_buffer != null and not _player_input_buffer.intent_ready.is_connected(_on_intent_ready):
		_player_input_buffer.intent_ready.connect(_on_intent_ready)
	_hud_dirty = true


func _on_intent_ready(_action_id: int) -> void:
	_hud_dirty = true


## Called by Main whenever the player's build mode changes. Empty string =
## off. Anything else shows up as a colored banner above the stats lines.
func set_designation_mode(label: String) -> void:
	_designation_label = label
	_hud_dirty = true


# ==================== refresh hooks ====================

func _on_tick(tick: int) -> void:
	if tick % WILDLIFE_SAMPLE_EVERY_TICKS == 0:
		_sample_wildlife(tick)
		_hud_dirty = true
	var refresh_stride: int = _refresh_stride_for_speed(GameManager.game_speed)
	var coarse: int = _coarse_gate_for_speed(GameManager.game_speed)
	_last_refresh_stride = refresh_stride
	_last_coarse_gate = coarse
	if tick % coarse != 0 and not _hud_dirty:
		return
	if tick % refresh_stride == 0:
		_refresh()
		_hud_dirty = false
		_last_refresh_tick = tick


func _on_speed_changed(_s: float, _p: bool) -> void:
	_hud_dirty = true


func _on_jobs_changed(_job: Job) -> void:
	_hud_dirty = true


func _on_zones_changed(_zone: Stockpile) -> void:
	_hud_dirty = true


func _on_colony_demand(_f: float, _h: float, _m: float, _ha: float) -> void:
	_hud_dirty = true


# ==================== layout / style ====================

func _apply_panel_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_BG
	style.border_color = PANEL_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.content_margin_left = PANEL_PAD_X
	style.content_margin_right = PANEL_PAD_X
	style.content_margin_top = PANEL_PAD_Y
	style.content_margin_bottom = PANEL_PAD_Y
	_panel.add_theme_stylebox_override("panel", style)
	_label.add_theme_font_size_override("normal_font_size", FONT_SIZE_BODY)
	_label.add_theme_font_size_override("bold_font_size", FONT_SIZE_BODY)
	_hotkeys.add_theme_font_size_override("font_size", FONT_SIZE_HOTKEYS)


# ==================== text ====================

func _refresh() -> void:
	if _label == null:
		return
	_prune_freed_pawns_in_spawner()
	var lines: Array[String] = []
	if _designation_label != "":
		lines.append("[bgcolor=#583a14][color=#ffe082]  BUILD MODE: %s   (click or click-drag to place · right-click / Esc to cancel)  [/color][/bgcolor]" %
			_designation_label)
	if SIMPLE_READABLE_HUD:
		lines.append(_time_line())
		lines.append(_world_pulse_line())
		lines.append(_history_totals_line())
		lines.append(_colony_state_line())
		lines.append(_settlement_identity_line())
		lines.append(_stockpile_simple_line())
		lines.append(_pawn_line_simple())
		lines.append(_jobs_line_simple())
		lines.append(_wildlife_line())
		var intent_simple: String = _player_intent_hud_line()
		if intent_simple != "":
			lines.append(intent_simple)
		lines.append(_narrative_rail_line())
	else:
		lines.append(_time_line())
		lines.append(_colony_state_line())
		lines.append(_settlement_identity_line())
		lines.append(_pawn_line())
		lines.append(_player_status_line())
		lines.append(_politics_line())
		lines.append(_war_status_line())
		lines.append(_skill_line())
		lines.append(_kill_line())
		lines.append(_export_status_line())
		lines.append(_stockpile_line())
		lines.append(_jobs_line())
		lines.append(_wildlife_line())
		var intent_ln2: String = _player_intent_hud_line()
		if intent_ln2 != "":
			lines.append(intent_ln2)
		lines.append(_narrative_rail_line())
		lines.append(_session_diag_line())
	var next_text: String = "\n".join(lines)
	var sig: String = str(next_text.hash())
	if sig == _last_render_signature:
		return
	_last_render_signature = sig
	_label.text = next_text


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
	_history_text.bbcode_enabled = true
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


func _time_line() -> String:
	var tick: int = GameManager.tick_count
	var day_len: int = SimTime.TICKS_PER_VISUAL_DAY
	var phase: float = float(tick % day_len) / float(day_len)
	var phase_name: String = _phase_name(phase)
	var speed_str: String = "PAUSED" if GameManager.is_paused else "%dx" % int(GameManager.game_speed)
	# In-game hour estimate: 24 notional hours across one visual day cycle (see docs/TIME_SCALE.md).
	var hour: int = int(phase * 24.0) % 24
	var year_n: int = SimTime.sim_year_index(tick)
	var y_tick: int = SimTime.tick_within_sim_year(tick)
	var day_in_year: int = SimTime.visual_day_within_sim_year(tick)
	var days_per_y: int = SimTime.visual_days_per_sim_year()
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
	return "[color=#c9b37c]Colony:[/color]  stance [b]%s[/b]  ·  food [b]%d%%[/b] %s  ·  housing [b]%d%%[/b] %s" % [
		stance,
		int(round(fp * 100.0)), _demand_tier(fp),
		int(round(hp * 100.0)), _demand_tier(hp),
	]


## High-level world snapshot (places, memory log size, work queue).
func _world_pulse_line() -> String:
	var settlements_n: int = SettlementMemory.settlements.size()
	var facts: int = WorldMemory.event_count()
	var js: Dictionary = JobManager.stats()
	var open_j: int = int(js.get("open", 0))
	var claimed_j: int = int(js.get("claimed", 0))
	return "[color=#aed581]World:[/color] [b]%d[/b] settlements · chronicle [b]%d[/b] facts · work [b]%d[/b] open · [b]%d[/b] claimed" % [
		settlements_n,
		facts,
		open_j,
		claimed_j,
	]


## Lifetime totals from the append-only chronicle (what kind of story this world is building).
func _history_totals_line() -> String:
	var c: Dictionary = WorldMemory.get_event_type_counts()
	var births: int = int(c.get("birth", 0)) + int(c.get("pawn_birth", 0))
	var deaths: int = int(c.get("pawn_death", 0))
	var builds: int = int(c.get("structure_built", 0)) + int(c.get("cooperative_build", 0))
	var meet: int = int(c.get("social_meeting", 0))
	var know: int = int(c.get("knowledge_discovery", 0)) + int(c.get("knowledge_rediscovery", 0))
	return "[color=#9fa8da]Story:[/color] births [b]%d[/b] · deaths [b]%d[/b] · builds [b]%d[/b] · meets [b]%d[/b] · knowledge [b]%d[/b]" % [
		births,
		deaths,
		builds,
		meet,
		know,
	]


## Short stockpile strip so readable mode still shows material reality.
func _stockpile_simple_line() -> String:
	var zones: Array[Stockpile] = StockpileManager.zones()
	if zones.is_empty():
		return "[color=#ce93d8]Supplies:[/color] [i]no stockpiles[/i]"
	var totals: Dictionary = {}
	for z in zones:
		for t in z.inventory:
			totals[t] = totals.get(t, 0) + z.inventory[t]
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
	var main_node: Main = get_tree().get_root().get_node_or_null("Main") as Main
	if main_node == null:
		return "[color=#c9b37c]Identity:[/color] world link offline"
	var digest: Dictionary = main_node.get_camera_settlement_revival_digest()
	var cam_rk: int = int(digest.get("camera_region_key", -1))
	var profile_rk: int = int(digest.get("profile_region_key", cam_rk))
	var has_settlement: bool = bool(digest.get("has_settlement", false))
	if not has_settlement or profile_rk < 0:
		var cam_meaning: String = str(WorldMeaning.get_region_meaning_label(cam_rk)).replace("_", " ")
		return "[color=#c9b37c]Identity:[/color] Wilds @%d · meaning [b]%s[/b]" % [cam_rk, cam_meaning]
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
	var culture_txt: String = str(prof.get("culture_name", "cautious")).replace("_", " ")
	var revival_score: int = int(prof.get("revival_score", 0))
	var war: Dictionary = SettlementMemory.get_war_profile_for_region(profile_rk)
	var gov: Dictionary = SettlementMemory.get_governance_profile_for_region(profile_rk)
	var war_state: String = str(war.get("state", "peace")).replace("_", " ")
	var gov_txt: String = str(gov.get("type", "anarchy")).replace("_", " ")
	return (
		"[color=#c9b37c]Identity:[/color] #%d  [b]%s[/b] · %s · intent %s · rev %d  "
		+ "| meaning %s · rep %s(%d) · war %s · gov %s"
	) % [profile_rk, state_txt, culture_txt, intent, revival_score, meaning, rep_word, rep, war_state, gov_txt]


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
	var living: Array[Pawn] = []
	for p in _spawner.pawns:
		if is_instance_valid(p) and p is Pawn:
			living.append(p)
	_spawner.pawns = living


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
	var lead: Pawn = null
	for p in _spawner.pawns:
		if not is_instance_valid(p) or p.data == null:
			continue
		if lead == null:
			lead = p
		n += 1
		var d: PawnData = p.data
		sum_h += d.hunger
		sum_r += d.rest
		sum_m += d.mood
		children_total += int(d.children_count)
		if d.hunger <= Pawn.THRESHOLD_WARN: hungry += 1
		if d.rest   <= Pawn.THRESHOLD_WARN: tired  += 1
		if d.mood   <= Pawn.THRESHOLD_WARN: sad    += 1
		if p.get_state() == Pawn.State.SLEEPING: sleeping += 1
	if n <= 0:
		return "[color=#cccccc]Pawns:[/color] (none)"
	var avg_h: float = sum_h / float(n)
	var avg_r: float = sum_r / float(n)
	var avg_m: float = sum_m / float(n)
	var affinity_line: String = ""
	if lead != null and lead.data != null:
		var top_aff: String = lead.data.highest_affinity_skill()
		var top_xp: int = lead.data.affinity_xp_for(top_aff)
		affinity_line = "   Pawn: [b]%s[/b] | Aff: [b]%s[/b] | XP: [b]%d[/b]" % [
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
	for p in _spawner.pawns:
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


func _stockpile_line() -> String:
	var zones: Array[Stockpile] = StockpileManager.zones()
	if zones.is_empty():
		return "[color=#cccccc]Stockpiles:[/color] (none)"
	# Sum item counts across every registered zone. We build a small dict of
	# type -> qty and render a chip for each non-zero entry.
	var totals: Dictionary = {}
	for z in zones:
		for t in z.inventory:
			totals[t] = totals.get(t, 0) + z.inventory[t]
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
		zones.size(), "" if zones.size() == 1 else "s", inv_text
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
	return "[color=#cccccc]Work:[/color] open [b]%d[/b] · claimed [b]%d[/b] · done [b]%d[/b] · beds [b]%d[/b]" % [
		int(s.get("open", 0)),
		int(s.get("claimed", 0)),
		int(s.get("completed", 0)),
		beds_built,
	]


func _player_status_line() -> String:
	var main_node: Main = get_tree().get_root().get_node_or_null("Main") as Main
	if main_node == null:
		return "[color=#cccccc]PLAYER PAWN:[/color] --  |  QUEUE: [b]0[/b]  |  STATE: [b]offline[/b]"
	var pawn_id: int = main_node.get_player_pawn_id()
	var queue_count: int = main_node.get_player_queue_size()
	var state: String = main_node.get_player_action_state()
	var pawn_id_text: String = str(pawn_id) if pawn_id >= 0 else "--"
	return "[color=#cccccc]PLAYER PAWN:[/color] [b]%s[/b]  |  QUEUE: [b]%d[/b]  |  STATE: [b]%s[/b]" % [
		pawn_id_text, queue_count, state
	]


func _skill_line() -> String:
	if _player_pawn == null or not is_instance_valid(_player_pawn) or _player_pawn.data == null:
		return "👤 Pawn [--]: Profession [None] | XP: 0/100"
	var d: PawnData = _player_pawn.data
	var pawn_id: int = int(d.id)
	var prof_name: String = d.profession_name()
	var xp: int = d.profession_progress_xp()
	return "👤 Pawn [%d]: Profession [%s] | XP: %d/100" % [pawn_id, prof_name, xp]


func _export_status_line() -> String:
	var main_node: Main = get_tree().get_root().get_node_or_null("Main") as Main
	var milestone: int = SimTime.KERNEL_DIAGNOSTIC_TICK
	if main_node == null:
		return "📜 Export / kernel checkpoint: tick %d | Status: Waiting" % milestone
	var status: String = "Complete" if main_node.is_kernel_diagnostic_complete() else "Waiting"
	if GameManager.tick_count >= milestone:
		return "📜 Export / kernel checkpoint: tick %d | Status: %s" % [milestone, status]
	return "📜 Export / kernel checkpoint: tick %d | Status: Waiting" % milestone


## One-line snapshot for AI/debug sessions (HUD copy-paste; reduces need for console spam).
func _session_diag_line() -> String:
	var d: Dictionary = GameManager.sim_diag()
	var wc: int = WorldMemory.event_count()
	var js: Dictionary = JobManager.stats()
	var open_j: int = int(js.get("open", 0))
	var claimed_j: int = int(js.get("claimed", 0))
	var settlements_n: int = SettlementMemory.settlements.size()
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
	if not SHOW_REFRESH_DIAG:
		return base
	var lag: int = max(0, tick_n - _last_refresh_tick)
	return "%s | hud iv=%d coarse=%d lag=%dt" % [base, _last_refresh_stride, _last_coarse_gate, lag]


func _refresh_stride_for_speed(speed: float) -> int:
	if speed >= 100.0:
		return REFRESH_EVERY_N_TICKS_MAX
	if speed >= 50.0:
		return REFRESH_EVERY_N_TICKS_EXTREME
	if speed >= 26.0:
		return REFRESH_EVERY_N_TICKS_ULTRA
	if speed >= 12.0:
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
	var main_node: Main = get_tree().get_root().get_node_or_null("Main") as Main
	if main_node == null:
		return "💀 Kills: 0"
	return "💀 Kills: %d" % int(main_node.get_kill_count())


func _politics_line() -> String:
	var main_node: Main = get_tree().get_root().get_node_or_null("Main") as Main
	if main_node == null:
		return "🏛 Settlement State: Anarchy | Ruler: None | Player Status: None"
	var gp: Dictionary = main_node.get_player_governance_profile()
	var gtype_raw: String = str(gp.get("type", "anarchy"))
	var gtype: String = "Anarchy"
	if gtype_raw == "monarchy":
		gtype = "Monarchy"
	elif gtype_raw == "council":
		gtype = "Council"
	var base: String = "🏛 Settlement State: %s | Ruler: %s | Player Status: %s" % [
		gtype,
		str(gp.get("ruler_name", "None")),
		str(gp.get("player_status", "None")),
	]
	if bool(gp.get("edicts_unlocked", false)):
		base += " | EDICTS UNLOCKED"
	return base


func _war_status_line() -> String:
	var main_node: Main = get_tree().get_root().get_node_or_null("Main") as Main
	if main_node == null:
		return "⚔ WAR STATUS: Peace | RANK: Grunt"
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
	var out: String = "⚔ WAR STATUS: %s | RANK: %s" % [ws_label, rank_label]
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


func _wildlife_line() -> String:
	if _wildlife_sample_tick == 0:
		return "🦌 Wildlife: Scanning ecosystem..."
	var r: int = int(_wildlife_snapshot.get("rabbit", 0))
	var d: int = int(_wildlife_snapshot.get("deer", 0))
	var t: int = int(_wildlife_snapshot.get("total", 0))
	var span: String = _wildlife_total_span()
	var tail: String = "[%s]" % _momentum_spark
	if not span.is_empty():
		tail += "  %s" % span
	return "🦌 Wildlife: R:%d D:%d T:%d %s" % [r, d, t, tail]


## Shown when PlayerIntentQueue has backlog or Main holds a chronicler pin.
func _player_intent_hud_line() -> String:
	var u: int = PlayerIntentQueue.unprocessed_count()
	var pin: String = ""
	var main_node: Main = get_tree().get_root().get_node_or_null("Main") as Main
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
func _narrative_rail_line() -> String:
	var ev: Array = []
	var main_node: Main = get_tree().get_root().get_node_or_null("Main") as Main
	if main_node != null:
		var digest: Dictionary = main_node.get_camera_settlement_revival_digest()
		var profile_rk: int = int(digest.get("profile_region_key", -1))
		if bool(digest.get("has_settlement", false)) and profile_rk >= 0:
			ev = WorldMemory.get_recent_events_for_settlement(profile_rk, 96, true)
	if ev.is_empty():
		ev = WorldMemory.get_recent_events(64)
	if ev.is_empty():
		return "📜 Chronicle: world is quiet"
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
		return "📜 Chronicle: no major shifts"
	return "📜 Chronicle: %s" % "  •  ".join(entries)


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
			var nm: String = str(e.get("n", e.get("name", "someone"))).strip_edges()
			if nm.is_empty():
				nm = "someone"
			return "%s died" % nm
		"animal_death":
			return "wildlife was culled"
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
	if v <= Pawn.THRESHOLD_CRIT:
		return "[color=#e57373][b]%2.0f[/b][/color]" % v   # red
	if v <= Pawn.THRESHOLD_WARN:
		return "[color=#ffd54f][b]%2.0f[/b][/color]" % v   # amber
	return "[color=#a5d6a7]%2.0f[/color]" % v               # green


static func _alert_chip(label: String, count: int, color_hex: String) -> String:
	if count <= 0:
		return ""
	return "[color=%s]%dx %s[/color]  " % [color_hex, count, label]
