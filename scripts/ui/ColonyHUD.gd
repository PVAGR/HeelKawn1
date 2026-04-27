class_name ColonyHUD
extends CanvasLayer

## Always-on heads-up display rendered in screen space (CanvasLayer = doesn't
## move with the camera). Refreshes every game tick so the numbers stay live
## without paying for a per-frame UI update at high speeds.
##
## Reads pawn list from PawnSpawner, stockpile from World, time + speed from
## GameManager, and job counts from JobManager (autoload).

const REFRESH_EVERY_N_TICKS: int = 1
const WILDLIFE_SAMPLE_EVERY_TICKS: int = 20
const WILDLIFE_HISTORY_SIZE: int = 8

const PANEL_BG: Color = Color(0.05, 0.06, 0.08, 0.78)
const PANEL_BORDER: Color = Color(0.85, 0.78, 0.40, 0.70)

const FONT_SIZE_BODY: int = 12
const FONT_SIZE_HOTKEYS: int = 9
const PANEL_PAD_X: int = 6
const PANEL_PAD_Y: int = 4

const HOTKEY_HINTS: String = "` map-only · G follow pawn · = full HUD · SPACE pause · 1-7 speed · F5/F8 · F9 observer · F10 debug · F6 focus · M labor · R reroll · B/W/O/Z · Esc"

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
var _wildlife_min_total: int = 0
var _wildlife_max_total: int = 0
var _momentum_spark: String = "........"
var _player_input_buffer: PlayerInputBuffer = null
var _player_pawn: Pawn = null
var _hud_dirty: bool = true
## False = compact HUD (default). True = full detail (`=` toggles).
var hud_verbose: bool = false


func toggle_hud_verbose() -> void:
	hud_verbose = not hud_verbose
	_apply_panel_style()
	_refresh()


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
	var refresh_stride: int = REFRESH_EVERY_N_TICKS
	if GameManager.game_speed >= 26.0:
		refresh_stride = 4
	elif GameManager.game_speed >= 12.0:
		refresh_stride = 2
	var coarse: int = 10
	if GameManager.game_speed >= 50.0:
		coarse = 35
	elif GameManager.game_speed >= 12.0:
		coarse = 20
	if tick % coarse != 0 and not _hud_dirty:
		return
	if tick % refresh_stride == 0:
		_refresh()
		_hud_dirty = false


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
	var bg: Color = PANEL_BG
	bg.a = 0.72 if hud_verbose else 0.36
	style.bg_color = bg
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
	lines.append(_time_line())
	lines.append(_colony_state_line())
	lines.append(_pawn_line())
	lines.append(_stockpile_line())
	lines.append(_jobs_line())
	lines.append(_wildlife_line())
	if hud_verbose:
		lines.append(_player_status_line())
		lines.append(_politics_line())
		lines.append(_war_status_line())
		lines.append(_skill_line())
		lines.append(_kill_line())
		lines.append(_export_status_line())
		lines.append(_settlement_revival_digest_line())
		lines.append(_session_diag_line())
		lines.append(_playtest_social_birth_hint_line())
	_label.text = "\n".join(lines)


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
	var day_len: int = DayNightCycle.TICKS_PER_DAY
	var phase: float = float(tick % day_len) / float(day_len)
	var phase_name: String = _phase_name(phase)
	var speed_str: String = "PAUSED" if GameManager.is_paused else "%dx" % int(GameManager.game_speed)
	# In-game hour estimate: 24 in-game hours per visual day cycle.
	var hour: int = int(phase * 24.0) % 24
	var year_n: int = SimTime.sim_year_index(tick)
	var y_tick: int = SimTime.tick_within_sim_year(tick)
	var day_in_year: int = SimTime.calendar_day_within_sim_year(tick)
	var days_per_y: int = SimTime.visual_days_per_sim_year()
	var abs_day: int = SimTime.calendar_absolute_visual_day(tick)
	return (
		"[b]Year %d[/b] · [b]Day %d/%d[/b]  %02d:00  %s   [color=#888888]absD%d[/color]   [color=#cccccc]Speed:[/color] [b]%s[/b]   [color=#888888]tick %d[/color]   [color=#666666](y.%d)[/color]"
		% [year_n, day_in_year, days_per_y, hour, phase_name, abs_day, speed_str, tick, y_tick]
	)


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
func _playtest_social_birth_hint_line() -> String:
	return (
		"[color=#a5d6a7][Playtest][/color] Social: co-presence +40t builds rapport; "
		+ "births need rapport 72+, relaxed hunger/rest, bed access. "
		+ "F10 → \"31 · Playtest bundle\" for one paste. Prefer 1x–12x while learning."
	)


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
	return (
		"[color=#9e9e9e][Session][/color] %.0fx pend~%.1f/%dt acc=%.3fs | tf=%d ac=%d | wm_ev=%d jobs %do/%dc st=%d"
		% [
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
	if not _wildlife_history.is_empty():
		_wildlife_min_total = int(_wildlife_history[0])
		_wildlife_max_total = int(_wildlife_history[0])
		for v in _wildlife_history:
			var vi: int = int(v)
			_wildlife_min_total = mini(_wildlife_min_total, vi)
			_wildlife_max_total = maxi(_wildlife_max_total, vi)


func _wildlife_line() -> String:
	if _wildlife_sample_tick == 0:
		return "🦌 Wildlife: Scanning ecosystem..."
	var r: int = int(_wildlife_snapshot.get("rabbit", 0))
	var d: int = int(_wildlife_snapshot.get("deer", 0))
	var t: int = int(_wildlife_snapshot.get("total", 0))
	var pr: int = int(_wildlife_prev_snapshot.get("rabbit", r))
	var pd: int = int(_wildlife_prev_snapshot.get("deer", d))
	var dr: int = 0
	var dd: int = 0
	var dts: int = 0
	if _wildlife_history.size() >= 2:
		dr = r - pr
		dd = d - pd
		dts = t - int(_wildlife_prev_snapshot.get("total", t))
	return "🦌 Wildlife: R:%d (%+d) D:%d (%+d) T:%d (%+d) [%s] Tmin:%d Tmax:%d" % [
		r, dr, d, dd, t, dts, _momentum_spark, _wildlife_min_total, _wildlife_max_total,
	]


func _settlement_revival_digest_line() -> String:
	var main_node: Main = get_tree().get_root().get_node_or_null("Main") as Main
	if main_node == null or not main_node.has_method("get_camera_revival_digest_bbcode"):
		return "[color=#9e9e9e]🏚 Cam settlement: (no Main)[/color]"
	return main_node.get_camera_revival_digest_bbcode()


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
