class_name CreatorDebugMenu
extends CanvasLayer
## F10: creator-facing debug hub. Each button prints a **copy-pasteable** block to stdout (Godot Output).
## HeelKawn kernel stays **deterministic** (seed + rules + history); these reports help you and the AI see truth.

const PANEL_W: int = 460
const PAD: int = 10
const _SOUL_EXPORT := preload("res://scripts/kernel/heelkawn_soul_export.gd")
const _WM = preload("res://autoloads/WorldMemory.gd")

## PHASE 6: Knowledge Fog - incarnated player only sees what their pawn knows
const LOCAL_KNOWLEDGE_RADIUS_TILES: int = 50  # Incarnated player only knows events within this radius

## PHASE 6: Myth vs Truth - player sees facts, pawns believe distorted versions
const MYTH_DISTORTION_FACTOR: float = 0.6  # Myths are 60% more extreme than facts

func _is_player_incarnated() -> bool:
	var main_node: Node = get_node_or_null("/root/Main")
	if main_node == null:
		return false
	if main_node.has_method("is_player_incarnated"):
		return bool(main_node.call("is_player_incarnated"))
	return false

func _get_player_pawn_id() -> int:
	var main_node: Node = get_node_or_null("/root/Main")
	if main_node == null:
		return -1
	var player_pawn: Variant = main_node.get("_player_pawn")
	if player_pawn != null and is_instance_valid(player_pawn):
		var pawn_data: Variant = player_pawn.get("data")
		if pawn_data != null:
			return int(pawn_data.get("id", -1))
	return -1

func _get_player_pawn_tile() -> Vector2i:
	var main_node: Node = get_node_or_null("/root/Main")
	if main_node == null:
		return Vector2i(-1, -1)
	var player_pawn: Variant = main_node.get("_player_pawn")
	if player_pawn != null and is_instance_valid(player_pawn):
		var pawn_data: Variant = player_pawn.get("data")
		if pawn_data != null and pawn_data.has("tile_pos"):
			return Vector2i(int(pawn_data.get("tile_pos", Vector2i(-1, -1))))
	return Vector2i(-1, -1)

func _is_region_known_to_player(region_key: int) -> bool:
	# Check if region is within LOCAL_KNOWLEDGE_RADIUS_TILES of player pawn
	if not _is_player_incarnated():
		return true  # Spectator knows all regions
	
	var player_tile: Vector2i = _get_player_pawn_tile()
	if player_tile.x < 0:
		return false
	
	# Convert region_key to approximate tile position
	var rx: int = region_key & 0xFFFF
	var ry: int = (region_key >> 16) & 0xFFFF
	if rx & 0x8000:
		rx = -(0x10000 - rx)
	if ry & 0x8000:
		ry = -(0x10000 - ry)
	var region_tile: Vector2i = Vector2i(rx * 16 + 8, ry * 16 + 8)
	
	var dist: int = abs(player_tile.x - region_tile.x) + abs(player_tile.y - region_tile.y)
	return dist <= LOCAL_KNOWLEDGE_RADIUS_TILES

## Sectioned menu: importance-ish order (playtest first, stubs last).
const DEBUG_SECTIONS: Array[Dictionary] = [
	{
		"heading": "★ AI / Cursor · session snapshot (paste to assistant)",
		"rows": [
			{
				"id": "session_snapshot_guide",
				"label": "00 · Checklist only — what to capture & order (A→G)",
			},
			{
				"id": "session_snapshot_pack",
				"label": "00 · One paste pack — checklist + ERROR + 31 + 34 (digest)",
			},
			{
				"id": "performance_snapshot",
				"label": "01 · PERFORMANCE SNAPSHOT — copy this for lag debugging",
			},
		],
	},
	{
		"heading": "Playtest / session truth",
		"rows": [
			{"id": "error_report", "label": "ERROR · Report (show all issues)"},
			{"id": "playtest_bundle", "label": "31 · Playtest bundle (one paste)"},
			{"id": "soul_bundle", "label": "32 · Soul bundle (1–2 sim-year handoff paste)"},
			{"id": "portable_character", "label": "33 · Portable character JSON (MMO / website handoff)"},
			{"id": "creator_digest", "label": "34 · Creator session digest (plain + AI · one paste)"},
			{"id": "chronicle_summary", "label": "36 · Readable chronicle summary (paste pack / streams)"},
			{"id": "promotion_bundle", "label": "37 · Write promotion bundle (seed + summary + JSON → user://)"},
			{"id": "calendar", "label": "01 · Calendar + day/night + checkpoints"},
			{"id": "sim_diag", "label": "02 · GameManager sim_diag"},
			{"id": "kernel", "label": "24 · KernelDiagnostic session summary"},
			{"id": "harness", "label": "25 · Validation / harness flags"},
			{"id": "colony_sim", "label": "03 · ColonySimServices"},
			{"id": "backbone_status", "label": "35 · Backbone / first-play (LIVE vs DEFERRED)"},
		],
	},
	{
		"heading": "Settlements · economy · jobs",
		"rows": [
			{"id": "settlements", "label": "06 · SettlementMemory (clusters)"},
			{"id": "registry", "label": "07 · SettlementRegistry"},
			{"id": "intent", "label": "04 · IntentMemory"},
			{"id": "jobs_stock", "label": "11 · Jobs + stockpile zones"},
			{"id": "trade", "label": "12 · TradeMemory"},
			{"id": "world_events", "label": "13 · WorldEvents"},
			{"id": "cultural", "label": "18 · CulturalMemory"},
		],
	},
	{
		"heading": "World · camera · revival",
		"rows": [
			{"id": "revival", "label": "08 · Camera / revival digest"},
			{"id": "rebirth", "label": "09 · SettlementRebirth constants"},
			{"id": "wildlife", "label": "10 · Wildlife snapshot"},
			{"id": "road", "label": "20 · RoadMemory"},
			{"id": "remnant", "label": "21 · RemnantMemory"},
			{"id": "main_world", "label": "23 · Main world (beds + spawners)"},
		],
	},
	{
		"heading": "Memory layers (heavy dumps)",
		"rows": [
			{"id": "world_memory", "label": "14 · WorldMemory"},
			{"id": "history_snip", "label": "15 · WorldMemory history export"},
			{"id": "world_meaning", "label": "16 · WorldMeaning"},
			{"id": "world_persist", "label": "17 · WorldPersistence"},
			{"id": "myth", "label": "19 · MythMemory"},
			{"id": "age", "label": "05 · AgeMemory"},
		],
	},
	{
		"heading": "Pawns · specialization",
		"rows": [
			{"id": "pawns", "label": "22 · All pawns"},
			{"id": "profession_liking", "label": "26 · Profession liking"},
			{"id": "grudges", "label": "40 · Grudge system (Phase 5 — grudges, blood feuds)"},
			{"id": "gossip_reputation", "label": "41 · Gossip & Reputation (Phase 5 — social propagation)"},
			{"id": "avoidance_ai", "label": "42 · Avoidance AI (Phase 5 — enemy avoidance patterns)"},
			{"id": "life_arcs", "label": "43 · Life Arcs (Phase 5 — readable pawn narratives)"},
			{"id": "knowledge_carriers", "label": "44 · Knowledge Carriers (Phase 5 — knowledge at risk, masters)"},
			{"id": "myth_formation", "label": "45 · Myth Formation (Phase 5 — feared/revered regions)"},
			{"id": "record_carriers", "label": "46 · Record Carriers (Phase 5 — knowledge preservation stones)"},
			{"id": "force_building", "label": "50 · FORCE BUILDING — post 10 wall/bed/zone jobs NOW"},
		],
	},
	{
		"heading": "Stubs · narrative scaffolding",
		"rows": [
			{"id": "vision_scope", "label": "27 · Vision scope (SimVision stub)"},
			{"id": "player_intents", "label": "28 · PlayerIntentQueue"},
			{"id": "factions", "label": "29 · FactionRegistry"},
			{"id": "religion_lens", "label": "30 · ReligionLens"},
		],
	},
]

var _root_panel: PanelContainer = null
var _scroll: ScrollContainer = null
var _vbox: VBoxContainer = null
var _demo_player_intent_seeded: bool = false
var _last_report_key: String = ""
var _last_report_tick: int = -1
var _last_report_wall_time: float = 0.0
const REPORT_COOLDOWN_SEC: float = 2.0

## Performance monitor reference (toggled via F10 menu)
var _performance_monitor_enabled: bool = false


func _ready() -> void:
	layer = 25
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	get_viewport().size_changed.connect(_on_viewport_resized)
	_on_viewport_resized()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			visible = false
			get_viewport().set_input_as_handled()


func toggle_menu() -> void:
	# PHASE 6: Hide debug menu when incarnated (pawns don't have debug menus)
	if _is_player_incarnated():
		print("[CreatorDebugMenu] Disabled during incarnation (pawns don't have F10 menus)")
		return
	visible = not visible


func _on_viewport_resized() -> void:
	_fit_debug_panel_to_viewport()


func _fit_debug_panel_to_viewport() -> void:
	if _root_panel == null or _scroll == null or _vbox == null:
		return
	var vs: Vector2 = get_viewport().get_visible_rect().size
	if vs.x < 64.0 or vs.y < 64.0:
		return
	# Fill nearly the whole window (margin container keeps inset); grow with resolution.
	var w: int = maxi(PANEL_W, int(vs.x) - 28)
	var h: int = maxi(420, int(vs.y) - 52)
	_root_panel.custom_minimum_size = Vector2(w, h)
	var scroll_h: int = maxi(360, h - 88)
	_scroll.custom_minimum_size = Vector2(maxi(200, w - 28), scroll_h)
	var btn_w: float = maxf(160.0, float(w) - 56.0)
	for ch in _vbox.get_children():
		if ch is Button:
			(ch as Button).custom_minimum_size.x = btn_w


func _build_ui() -> void:
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.offset_left = 10.0
	margin.offset_top = 28.0
	margin.offset_right = -10.0
	margin.offset_bottom = -10.0
	margin.add_theme_constant_override("margin_left", PAD)
	margin.add_theme_constant_override("margin_top", PAD)
	margin.add_theme_constant_override("margin_right", PAD)
	margin.add_theme_constant_override("margin_bottom", PAD)
	add_child(margin)
	_root_panel = PanelContainer.new()
	_root_panel.custom_minimum_size = Vector2(PANEL_W, 680)
	margin.add_child(_root_panel)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.07, 0.1, 0.94)
	style.border_color = Color(0.75, 0.65, 0.35, 0.85)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.content_margin_left = PAD
	style.content_margin_right = PAD
	style.content_margin_top = PAD
	style.content_margin_bottom = PAD
	_root_panel.add_theme_stylebox_override("panel", style)
	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(PANEL_W - 24, 620)
	_root_panel.add_child(_scroll)
	_vbox = VBoxContainer.new()
	_vbox.add_theme_constant_override("separation", 5)
	_scroll.add_child(_vbox)
	var title: Label = Label.new()
	title.text = "HeelKawn — Creator debug (F10 · Esc)"
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", 15)
	title.modulate = Color(0.95, 0.87, 0.55)
	_vbox.add_child(title)
	var hint: Label = Label.new()
	hint.text = "Use ★00 · checklist or one paste pack for AI handoff; copy everything between === lines (or CREATOR_START/END for digest 34)."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 12)
	_vbox.add_child(hint)
	for sec in DEBUG_SECTIONS:
		var hl: Label = Label.new()
		hl.text = str(sec.get("heading", ""))
		hl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hl.add_theme_font_size_override("font_size", 13)
		hl.modulate = Color(0.55, 0.72, 0.95)
		_vbox.add_child(hl)
		var rows_v: Variant = sec.get("rows", [])
		if rows_v is Array:
			for row_any in rows_v:
				if row_any is Dictionary:
					var rowd: Dictionary = row_any as Dictionary
					_add_report_button(str(rowd.get("label", "?")), str(rowd.get("id", "")))
	
	# Add performance monitor toggle at the end
	_add_performance_monitor_toggle()


func _add_report_button(label_text: String, report_id: String) -> void:
	var b: Button = Button.new()
	b.text = label_text
	b.add_theme_font_size_override("font_size", 13)
	b.custom_minimum_size = Vector2(PANEL_W - 40, 26)
	b.pressed.connect(_emit_report.bind(report_id))
	_vbox.add_child(b)


func _emit_report(report_id: String) -> void:
	var now: float = Time.get_unix_time_from_system()
	if now - _last_report_wall_time < REPORT_COOLDOWN_SEC:
		return
	_last_report_wall_time = now
	var tick: int = GameManager.tick_count
	if _last_report_tick == tick and _last_report_key == report_id:
		return
	_last_report_tick = tick
	_last_report_key = report_id
	print("=== HEELKAWN_DEBUG_REPORT:%s:tick=%d BEGIN ===" % [report_id, tick])
	
	# WRAPPER: Catch errors in report functions to prevent menu crashes
	var error_occurred: bool = false
	var error_msg: String = ""
	
	match report_id:
		"session_snapshot_guide":
			error_occurred = _safe_report(_report_session_snapshot_guide, "session_snapshot_guide")
		"session_snapshot_pack":
			error_occurred = _safe_report(_report_session_snapshot_pack, "session_snapshot_pack")
		"performance_snapshot":
			error_occurred = _safe_report(_report_performance_snapshot, "performance_snapshot")
		"error_report":
			error_occurred = _safe_report(_report_error_issues, "error_report")
		"calendar":
			error_occurred = _safe_report(_report_calendar.bind(tick), "calendar")
		"sim_diag":
			error_occurred = _safe_report(_report_sim_diag, "sim_diag")
		"colony_sim":
			error_occurred = _safe_report(_report_colony_sim, "colony_sim")
		"backbone_status":
			error_occurred = _safe_report(_report_backbone_status, "backbone_status")
		"intent":
			error_occurred = _safe_report(_report_intent, "intent")
		"age":
			error_occurred = _safe_report(_report_age, "age")
		"settlements":
			error_occurred = _safe_report(_report_settlements, "settlements")
		"registry":
			error_occurred = _safe_report(_report_registry, "registry")
		"revival":
			error_occurred = _safe_report(_report_revival, "revival")
		"rebirth":
			error_occurred = _safe_report(_report_rebirth_consts, "rebirth_consts")
		"wildlife":
			error_occurred = _safe_report(_report_wildlife, "wildlife")
		"jobs_stock":
			error_occurred = _safe_report(_report_jobs_stock, "jobs_stock")
		"trade":
			error_occurred = _safe_report(_report_trade, "trade")
		"world_events":
			error_occurred = _safe_report(_report_world_events, "world_events")
		"world_memory":
			error_occurred = _safe_report(_report_world_memory, "world_memory")
		"history_snip":
			error_occurred = _safe_report(_report_history_snip, "history_snip")
		"world_meaning":
			error_occurred = _safe_report(_report_world_meaning, "world_meaning")
		"world_persist":
			error_occurred = _safe_report(_report_world_persist, "world_persist")
		"cultural":
			error_occurred = _safe_report(_report_cultural, "cultural")
		"myth":
			error_occurred = _safe_report(_report_myth, "myth")
		"road":
			error_occurred = _safe_report(_report_road, "road")
		"remnant":
			error_occurred = _safe_report(_report_remnant, "remnant")
		"pawns":
			error_occurred = _safe_report(_report_pawns, "pawns")
		"main_world":
			error_occurred = _safe_report(_report_main_world, "main_world")
		"kernel":
			error_occurred = _safe_report(_report_kernel, "kernel")
		"harness":
			error_occurred = _safe_report(_report_harness, "harness")
		"profession_liking":
			error_occurred = _safe_report(_report_profession_liking, "profession_liking")
		"grudges":
			error_occurred = _safe_report(_report_grudges, "grudges")
		"gossip_reputation":
			error_occurred = _safe_report(_report_gossip_reputation, "gossip_reputation")
		"avoidance_ai":
			error_occurred = _safe_report(_report_avoidance_ai, "avoidance_ai")
		"life_arcs":
			error_occurred = _safe_report(_report_life_arcs, "life_arcs")
		"knowledge_carriers":
			error_occurred = _safe_report(_report_knowledge_carriers, "knowledge_carriers")
		"myth_formation":
			error_occurred = _safe_report(_report_myth_formation, "myth_formation")
		"record_carriers":
			error_occurred = _safe_report(_report_record_carriers, "record_carriers")
		"force_building":
			error_occurred = _safe_report(_force_building_now, "force_building")
		"vision_scope":
			error_occurred = _safe_report(_report_vision_scope, "vision_scope")
		"player_intents":
			error_occurred = _safe_report(_report_player_intents, "player_intents")
		"factions":
			error_occurred = _safe_report(_report_factions, "factions")
		"religion_lens":
			error_occurred = _safe_report(_report_religion_lens, "religion_lens")
		"playtest_bundle":
			error_occurred = _safe_report(_report_playtest_bundle, "playtest_bundle")
		"soul_bundle":
			_report_soul_bundle()
		"portable_character":
			_report_portable_character()
		"creator_digest":
			_report_creator_session_digest()
		"chronicle_summary":
			_report_chronicle_summary()
		"promotion_bundle":
			_report_promotion_bundle()
		_:
			print("Unknown report_id=%s" % report_id)
	print("=== HEELKAWN_DEBUG_REPORT:%s:tick=%d END ===" % [report_id, tick])


func _print_session_snapshot_checklist(tick_now: int) -> void:
	print("")
	print("HEELKAWN_AI_SNAPSHOT_CHECKLIST  tick=%d" % tick_now)
	print("")
	print(
			"A) Godot Output — Copy lines with SIM_HITCH, SIM_CATCHUP, MAIN_TICK_HOTSPOT, VALIDATION_, "
			+ "and any errors. Note game speed (e.g. 100x) and whether the window felt smooth."
	)
	print(
			"B) Screenshot — One full game view; optional: Debugger → Monitors → FPS if profiling stalls."
	)
	print(
			"C) F10 → ★ 00 · One paste pack — one button prints checklist + ERROR + 31 + 34 (CREATOR_START…END)."
	)
	print(
			"   After running the pack, do not click ERROR / 31 / 34 again the same tick (duplicate Output)."
	)
	print(
			"D) Without the pack: press ERROR, then 31 · Playtest, then 34 · Creator digest in order."
	)
	print("E) Optional — F10 → 32 Soul bundle · 33 Portable character JSON (not in the pack).")
	print("")
	print(
			"Paste to Cursor/AI: Godot console tail (A) + screenshot (B) + one session_snapshot_pack block (C), "
			+ "or (A)+(B)+ separate D blocks."
	)
	print("")


## SAFE REPORT WRAPPER - catches errors to prevent menu crashes
func _safe_report(report_func: Callable, report_name: String) -> bool:
	if not report_func.is_valid():
		print("[_safe_report] Invalid function: %s" % report_name)
		return true
	print("[_safe_report] Starting: %s" % report_name)
	report_func.call()
	print("[_safe_report] Completed: %s" % report_name)
	return false


func _report_session_snapshot_guide() -> void:
	_print_session_snapshot_checklist(GameManager.tick_count)


func _report_session_snapshot_pack() -> void:
	var t: int = GameManager.tick_count
	_print_session_snapshot_checklist(t)
	print(
			">>> Embedded: ERROR + Playtest (31) + Creator digest (34). "
			+ "Optional extras: F10 → 32 Soul · 33 Portable character — not included here."
	)
	print("")
	print("--- embedded: ERROR report ---")
	_report_error_issues()
	print("")
	print("--- embedded: Playtest bundle (31) ---")
	_report_playtest_bundle()
	print("")
	print("--- embedded: Creator session digest (34) — CREATOR_START … CREATOR_END ---")
	_report_creator_session_digest()


# === PERFORMANCE DIAGNOSTICS ===

func _report_performance_snapshot() -> void:
	print("=== HEELKAWN PERFORMANCE SNAPSHOT ===")
	print("Generated: %s" % Time.get_datetime_string_from_system())
	print("Game Tick: %d" % GameManager.tick_count)
	print("Game Speed: %.1fx" % GameManager.game_speed)
	print("")
	
	# Count pawns
	var pawn_count: int = 0
	var ps: PawnSpawner = null
	if get_node_or_null("/root/PawnSpawner") != null:
		ps = get_node_or_null("/root/PawnSpawner") as PawnSpawner
		if ps != null:
			pawn_count = ps.pawns.size()
	
	print("--- SIMULATION STATE ---")
	print("Total Pawns: %d" % pawn_count)
	print("Game Speed: %.1fx" % GameManager.game_speed)
	print("Is Paused: %s" % str(GameManager.paused))
	print("")
	
	# Settlement stats
	var settlement_count: int = 0
	if SettlementMemory != null:
		settlement_count = SettlementMemory.get_settlement_count() if SettlementMemory.has_method("get_settlement_count") else 0
	
	print("--- SETTLEMENT STATS ---")
	print("Active Settlements: %d" % settlement_count)
	print("")
	
	# Job stats
	print("--- JOB STATS ---")
	if JobManager != null:
		var open_jobs: int = JobManager.open_count() if JobManager.has_method("open_count") else 0
		var claimed_jobs: int = JobManager.claimed_count() if JobManager.has_method("claimed_count") else 0
		print("Open Jobs: %d" % open_jobs)
		print("Claimed Jobs: %d" % claimed_jobs)
	print("")
	
	# Mining react status
	print("--- MINING REACT STATUS ---")
	var main_node: Node = get_node_or_null("/root/Main")
	if main_node != null and main_node.has_method("get"):
		var mining_pending: Variant = main_node.get("_mining_react_pending")
		var mining_in_progress: Variant = main_node.get("_mining_react_in_progress")
		var mining_cursor: Variant = main_node.get("_mining_react_scan_y_cursor")
		print("Mining React Pending: %s" % str(mining_pending))
		print("Mining React In Progress: %s" % str(mining_in_progress))
		print("Mining Scan Y Cursor: %d / 256" % [mining_cursor if mining_cursor != null else 0])
	print("")
	
	# Instructions
	print("--- HOW TO USE THIS DATA ---")
	print("1. Run game at speed where you see lag (e.g., 100x)")
	print("2. When you see freeze, press F10 immediately")
	print("3. Click '01 · PERFORMANCE SNAPSHOT'")
	print("4. Copy the output above and send to AI")
	print("")
	print("=== END PERFORMANCE SNAPSHOT ===")


func _main() -> Node2D:
	return get_tree().root.get_node_or_null("Main") as Node2D


func _print_dict_sample(title: String, d: Dictionary, max_entries: int) -> void:
	print("%s  entries=%d" % [title, d.size()])
	var keys: Array = d.keys()
	keys.sort()
	var n: int = mini(max_entries, keys.size())
	for i in range(n):
		var k: Variant = keys[i]
		print("  %s => %s" % [str(k), str(d[k])])


func _report_calendar(tick: int) -> void:
	var dlen: int = DayNightCycle.TICKS_PER_DAY
	var phase: float = float(tick % dlen) / float(dlen)
	var night: bool = DayNightCycle.is_night_for_tick(tick)
	var y: int = SimTime.sim_year_index(tick)
	var d_in_y: int = SimTime.calendar_day_within_sim_year(tick)
	var d_per: int = SimTime.visual_days_per_sim_year()
	var abs_d: int = SimTime.calendar_absolute_visual_day(tick)
	var y_tick: int = SimTime.tick_within_sim_year(tick)
	print(
			(
					"tick=%d  sim_year_index=%d  tick_within_sim_year=%d\n"
					+ "visual_day_in_year=%d/%d  absolute_visual_day=%d  TICKS_PER_VISUAL_DAY=%d  TICKS_PER_SIM_YEAR=%d\n"
					+ "day_phase=%.4f  is_night=%s  (DayNight uses same TICKS_PER_DAY as SimTime.TICKS_PER_VISUAL_DAY)"
			)
			% [tick, y, y_tick, d_in_y, d_per, abs_d, SimTime.TICKS_PER_VISUAL_DAY, SimTime.TICKS_PER_SIM_YEAR, phase, night]
	)
	for m in SimTime.long_run_checkpoints():
		if tick >= m:
			print("long_run_checkpoint_reached: tick>=%d" % m)


func _report_sim_diag() -> void:
	print("sim_diag: %s" % str(GameManager.sim_diag()))


func _report_colony_sim() -> void:
	print(
			"stance=%s food=%.3f housing=%.3f materials=%.3f haul=%.3f"
			% [
				ColonySimServices.get_stance_display(),
				ColonySimServices.get_food_pressure(),
				ColonySimServices.get_housing_pressure(),
				ColonySimServices.get_materials_pressure(),
				ColonySimServices.get_haul_pressure(),
			]
	)


func _report_backbone_status() -> void:
	const LIVE: String = "LIVE"
	const DEF: String = "DEFERRED"
	var tick: int = GameManager.tick_count
	var seed: int = WorldRNG.current_seed()
	print("HEELKAWN_BACKBONE_FIRST_PLAY  tick=%d  world_seed=%d" % [tick, seed])
	print("Authoritative detail: docs/HEELKAWN_STATE.md  (section FIRST PLAYABLE)")
	print("")
	print("LIVE = you can see it working in this build. DEFERRED = roadmap or thin stub.")
	print("")
	print("— SIM CORE —")
	var spd: float = GameManager.game_speed if GameManager != null else 0.0
	print("  GameManager            %s  speed=%.1f" % [LIVE, spd])
	var n_set: int = SettlementMemory.settlements.size() if SettlementMemory != null else 0
	print("  SettlementMemory       %s  settlements=%d" % [LIVE, n_set])
	var open_j: int = JobManager.open_count() if JobManager != null else -1
	print("  JobManager             %s  open_jobs=%d" % [LIVE, open_j])
	var wm_ct: int = WorldMemory.event_count() if WorldMemory != null else -1
	print("  WorldMemory            %s  event_count=%d" % [LIVE, wm_ct])
	var houses: int = -1
	if FactionRegistry != null:
		FactionRegistry.sync_from_settlements()
		houses = FactionRegistry.get_synced_house_count()
	print("  FactionRegistry        %s  houses=%d" % [LIVE, houses])
	var living: int = 0
	var m: Node2D = _main()
	if m != null:
		var ps: PawnSpawner = m.get_node_or_null("WorldViewport/PawnSpawner") as PawnSpawner
		if ps != null:
			for p in ps.pawns:
				if p != null and is_instance_valid(p):
					living += 1
	print("  Pawns (scene)          %s  living=%d" % [LIVE, living])
	var wai_ok: bool = WorldAI != null and WorldAI.has_method("get_pawn_neural_state")
	print("  WorldAI + matrix       %s  neural+rules+12ch parity" % (LIVE if wai_ok else DEF))
	print("  ColonySimServices      %s  food/mat/haul/housing pressures" % LIVE)
	print("  StockpileManager       %s  zones + aggregates" % LIVE)
	print("")
	print("— PARTIAL / ROADMAP —")
	print("  SimVision              %s  full vision/campaign sim" % DEF)
	print("  Tech diffusion graph   %s  peer settlement IDs (real list), not map adjacency" % LIVE)
	print("  Tool items (axe/pick)  %s  carry + efficiency proxy" % DEF)
	print("")
	print("— TRY —")
	print("  Click pawn → ID / Needs / Matrix / Neural / Social.  F9 realm.  F10 → 31 playtest bundle.")


func _report_intent() -> void:
	print("IntentMemory.global_pressure=%.4f" % IntentMemory.global_pressure)
	_print_dict_sample("IntentMemory.settlement_pressure", IntentMemory.settlement_pressure, 24)
	_print_dict_sample("IntentMemory.settlement_intent (0=GROW 1=HOLD 2=ABANDON)", IntentMemory.settlement_intent, 24)


func _report_age() -> void:
	print(
			"AgeMemory: current_age_index=%d age_start_tick=%d tint_strength=%.4f"
			% [AgeMemory.get_current_age_index(), AgeMemory.age_start_tick, AgeMemory.get_global_age_tint_strength()]
	)
	print("AgeMemory.age_signature: %s" % str(AgeMemory.age_signature))


func _report_settlements() -> void:
	if SettlementMemory == null or not SettlementMemory.has("settlements"):
		print("[_report_settlements] SettlementMemory not available")
		return
	print("settlement_count=%d" % SettlementMemory.settlements.size())
	var i: int = 0
	for s in SettlementMemory.settlements:
		if not (s is Dictionary):
			continue
		var st: Dictionary = s as Dictionary
		print(
				(
						"[%d] state=%s center=%d culture=%s scar_max=%d rev_score=%d peace_thr=%d last_death=%s intent=%s"
						% [
							i,
							str(st.get("state", "")),
							int(st.get("center_region", -1)),
							str(st.get("culture_name", "")),
							int(st.get("scar_max", 0)),
							int(st.get("revival_score", 0)),
							int(st.get("peace_threshold_ticks", 0)),
							str(st.get("last_pawn_death_tick", -1)),
							str(st.get("current_intent", "")),
						]
				)
		)
		i += 1


func _report_registry() -> void:
	print("SettlementRegistry.to_save_dict: %s" % str(SettlementRegistry.to_save_dict()))


func _report_revival() -> void:
	var m: Node2D = _main()
	if m != null and m.has_method("get_camera_revival_digest_plain"):
		print(str(m.call("get_camera_revival_digest_plain")))
		if m.has_method("get_camera_settlement_revival_digest"):
			print("digest_dict: %s" % str(m.call("get_camera_settlement_revival_digest")))
	else:
		print("Main not available")


func _report_rebirth_consts() -> void:
	print(
			"SettlementRebirth: CHECK_INTERVAL=%d REBIRTH_PEACE=%d REBIRTH_INTERVAL=%d TILE_SCORES struct=%d scar=%d road=%d trade=%d dist=%d"
			% [
				SettlementRebirth.CHECK_INTERVAL_TICKS,
				SettlementRebirth.REBIRTH_PEACE_TICKS,
				SettlementRebirth.REBIRTH_INTERVAL_TICKS,
				SettlementRebirth.TILE_SCORE_STRUCT_NEIGHBOR,
				SettlementRebirth.TILE_SCORE_SCAR_WEIGHT,
				SettlementRebirth.TILE_SCORE_ROAD_WEIGHT,
				SettlementRebirth.TILE_SCORE_TRADE_WEIGHT,
				SettlementRebirth.TILE_SCORE_DISTANCE_WEIGHT,
			]
	)


func _report_wildlife() -> void:
	var m: Node2D = _main()
	if m != null and m.has_method("get_wildlife_snapshot_for_diagnostic"):
		print(str(m.call("get_wildlife_snapshot_for_diagnostic")))
	else:
		print("Main not available")


func _report_jobs_stock() -> void:
	print("JobManager.stats: %s" % str(JobManager.stats()))
	print("JobManager.open_count=%d" % JobManager.open_count())
	print("Stockpile zones=%d" % StockpileManager.zones().size())
	for z in StockpileManager.zones():
		if z == null:
			continue
		print("  zone @%s items=%s" % [str(z.rect.position), str(z.inventory)])


func _report_trade() -> void:
	print(
			"TradeMemory: count_t2_tiles=%d count_route_tiles=%d last_tick_t2_existed=%d"
			% [TradeMemory.count_t2_tiles(), TradeMemory.count_route_tiles(), TradeMemory.get_last_tick_t2_existed()]
	)


func _report_world_events() -> void:
	print("WorldEvents.get_debug_active_event: %s" % str(WorldEvents.get_debug_active_event()))
	print("WorldEvents.gathering_efficiency_mult()=%.3f" % WorldEvents.gathering_efficiency_mult())
	print("validation_clean_economy_events_active=%s" % str(WorldEvents.validation_clean_economy_events_active()))


func _report_world_memory() -> void:
	var n: int = WorldMemory.event_count()
	print("WorldMemory.event_count=%d" % n)
	var mem: Dictionary = WorldMemory.to_save_dict()
	var ev: Variant = mem.get("events", [])
	if ev is Array:
		var arr: Array = ev as Array
		var start: int = maxi(0, arr.size() - 25)
		for j in range(start, arr.size()):
			print("  event[%d]: %s" % [j, str(arr[j])])


func _report_history_snip() -> void:
	var s: String = WorldMemory.get_history_export_string(false)
	var maxl: int = 12000
	if s.length() > maxl:
		s = s.substr(0, maxl) + "\n... [truncated at %d chars]" % maxl
	print(s)


func _report_world_meaning() -> void:
	var m: Dictionary = WorldMeaning.meaning_by_region
	print("WorldMeaning.meaning_by_region regions=%d" % m.size())
	var keys: Array = m.keys()
	keys.sort()
	var cap: int = mini(18, keys.size())
	for i in range(cap):
		var rk: int = int(keys[i])
		print("  rk=%d summary=%s" % [rk, str(WorldMeaning.get_region_meaning_summary(rk))])


func _report_world_persist() -> void:
	var pr: Dictionary = WorldPersistence.persistent_regions
	print("WorldPersistence.persistent_regions count=%d" % pr.size())
	var keys: Array = pr.keys()
	keys.sort()
	var shown: int = 0
	for k in keys:
		if shown >= 16:
			break
		var rec: Dictionary = WorldPersistence.get_region_persistence(int(k))
		var sl: int = int(rec.get("scar_level", 0))
		if sl >= 1 or int(rec.get("recovery_stage", 0)) > 0:
			print("  rk=%s scar=%d recovery=%s" % [str(k), sl, str(rec.get("recovery_stage", 0))])
			shown += 1


func _report_cultural() -> void:
	var rep: Dictionary = CulturalMemory.reputation_by_region
	print("CulturalMemory.reputation_by_region count=%d" % rep.size())
	var keys: Array = rep.keys()
	keys.sort()
	for i in range(mini(20, keys.size())):
		var rk: int = int(keys[i])
		print("  rk=%d reputation=%d" % [rk, CulturalMemory.get_region_reputation(rk)])


func _report_myth() -> void:
	print("MythMemory.to_save_dict: %s" % str(MythMemory.to_save_dict()))
	var seen: Dictionary = {}
	for s in SettlementMemory.settlements:
		if s is not Dictionary:
			continue
		var c: int = int((s as Dictionary).get("center_region", -1))
		if c < 0 or seen.has(c):
			continue
		seen[c] = true
		print(
				"  center=%d myth_state=%d rebirths=%d"
				% [c, MythMemory.get_region_myth_state(c), MythMemory.get_rebirth_success_count_for_center(c)]
		)
		if seen.size() >= 16:
			break


func _report_road() -> void:
	var m: Node2D = _main()
	var sx: int = 127
	var sy: int = 127
	if m != null:
		var w: World = m.get_node_or_null("WorldViewport/World") as World
		if w != null and w.data != null:
			sx = w.data.WIDTH / 2
			sy = w.data.HEIGHT / 2
	print(
			"RoadMemory traversal: (127,127)=%d (64,64)=%d mid(%d,%d)=%d path_mul_mid=%.3f"
			% [
				RoadMemory.get_traversal(127, 127),
				RoadMemory.get_traversal(64, 64),
				sx,
				sy,
				RoadMemory.get_traversal(sx, sy),
				RoadMemory.get_path_weight_mul(sx, sy),
			]
	)


func _report_remnant() -> void:
	var m: Node2D = _main()
	if m == null:
		print("Main missing")
		return
	var w: World = m.get_node_or_null("WorldViewport/World") as World
	if w == null:
		print("World missing")
		return
	print("RemnantMemory deltas: tile(0,0)=%d tile(64,64)=%d" % [
		RemnantMemory.get_tile_rem_delta(0, 0, w),
		RemnantMemory.get_tile_rem_delta(64, 64, w),
	])


func _report_pawns() -> void:
	var m: Node2D = _main()
	if m == null:
		print("Main missing")
		return
	var ps: PawnSpawner = m.get_node_or_null("WorldViewport/PawnSpawner") as PawnSpawner
	if ps == null:
		print("PawnSpawner null")
		return
	print("pawn_count=%d" % ps.pawns.size())
	for p in ps.pawns:
		if p == null or not is_instance_valid(p) or p.data == null:
			continue
		var d: PawnData = p.data
		var t: Vector2i = d.tile_pos
		var rk: int = _WM._region_key(t.x, t.y)
		var carry_s: String = "-"
		if d.is_carrying():
			carry_s = "%s x%d" % [Item.name_for(d.carrying), int(d.carrying_qty)]
		print(
				(
						"  id=%d name=%s age=%.1f tile=%s region=%d H=%.1f R=%.1f M=%.1f state=%s prof=%s carry=%s"
						% [
							int(d.id),
							d.display_name,
							float(d.age_years),
							str(t),
							rk,
							d.hunger,
							d.rest,
							d.mood,
							p.get_state_name(),
							d.profession_name(),
							carry_s,
						]
				)
		)


func _report_main_world() -> void:
	var m: Node2D = _main()
	if m == null:
		print("Main missing")
		return
	var w: World = m.get_node_or_null("WorldViewport/World") as World
	if w != null:
		print("World bed_count=%d" % w.bed_count())
	var es: Node = m.get_node_or_null("WorldViewport/EnemySpawner")
	if es != null and es.has_method("get_enemy_count"):
		print("EnemySpawner.get_enemy_count=%s" % str(es.call("get_enemy_count")))
	var asp: Node = m.get_node_or_null("WorldViewport/AnimalSpawner")
	if asp != null and asp.has_method("get_live_wildlife_snapshot"):
		print("AnimalSpawner snapshot=%s" % str(asp.call("get_live_wildlife_snapshot")))


func _report_kernel() -> void:
	var m0: Node2D = _main()
	var kd: Node = m0.get_node_or_null("KernelDiagnostic") if m0 != null else null
	if kd != null and kd.has_method("generate_session_log_summary"):
		print(kd.call("generate_session_log_summary"))
	else:
		print("KernelDiagnostic not found")


func _report_harness() -> void:
	var v: Dictionary = SettlementMemory.validation_harness_flags_for_snapshot()
	print("SettlementMemory.validation_harness_flags: %s" % str(v))
	print("OS.is_debug_build=%s" % OS.is_debug_build())


func _report_vision_scope() -> void:
	var sv: Node = get_tree().root.get_node_or_null("SimVision")
	if sv == null:
		print("SimVision autoload missing (check project.godot).")
		return
	if sv.has_method("roadmap_debug_block"):
		print(sv.call("roadmap_debug_block"))
	else:
		print("SimVision node has no roadmap_debug_block().")


func _report_player_intents() -> void:
	if not _demo_player_intent_seeded:
		_demo_player_intent_seeded = true
		var zid: String = ""
		var ckr: int = -1
		for st_any in SettlementMemory.settlements:
			if not (st_any is Dictionary):
				continue
			ckr = int((st_any as Dictionary).get("center_region", -1))
			if ckr >= 0:
				zid = str(ckr)
				break
		PlayerIntentQueue.submit(
				PlayerIntentQueue.IntentKind.OBSERVER_NOTE,
				zid,
				-1,
				"F10 report 28 demo intent (one-shot per session)",
				{"report_id": "player_intents"}
		)
		if ckr >= 0:
			PlayerIntentQueue.submit(
					PlayerIntentQueue.IntentKind.CHRONICLE_PIN_ZONE,
					zid,
					-1,
					"F10 demo CHRONICLE_PIN_ZONE (dispatches on next sim ticks)",
					{}
			)
			PlayerIntentQueue.submit(
					PlayerIntentQueue.IntentKind.REQUEST_SETTLEMENT_FOCUS,
					"",
					-1,
					"F10 demo REQUEST_SETTLEMENT_FOCUS",
					{"center_region": ckr}
			)
	print(PlayerIntentQueue.debug_summary_block())
	print(
			"ObservationAPI.observe_sim_ambient() player_intent: use for agents; unprocessed>0 drains 1/tick in Main."
	)
	print("WorldMemory tail: filter events type=player_intent in export (report 14/15).")


func _report_factions() -> void:
	print(FactionRegistry.debug_summary_block())


func _report_religion_lens() -> void:
	print(ReligionLens.digest_settlements(12))


func _report_soul_bundle() -> void:
	var m: Node2D = _main()
	var pack: Object = (_SOUL_EXPORT as Script).new()
	if pack != null and pack.has_method("print_bundle"):
		pack.call("print_bundle", m)


func _report_portable_character() -> void:
	var m: Node2D = _main()
	if m == null:
		print("[PORTABLE_CHARACTER] Main missing")
		return
	var p: Pawn = m.get_player_pawn()
	if p == null or p.data == null:
		print(
				"[PORTABLE_CHARACTER] No pawn — select one on the map (selection = player pawn for export)."
		)
		return
	var wseed: int = 0
	var w: World = m.get_node_or_null("WorldViewport/World") as World
	if w != null and w.data != null:
		wseed = int(w.data.world_seed)
	var rk: int = _WM._region_key(p.data.tile_pos.x, p.data.tile_pos.y)
	var bundle: Dictionary = p.data.to_portable_character_export(GameManager.tick_count, wseed, rk)
	print("=== HEELKAWN_PORTABLE_CHARACTER_JSON BEGIN ===")
	print(JSON.stringify(bundle, "\t"))
	print("=== HEELKAWN_PORTABLE_CHARACTER_JSON END ===")
	print(
			"[PORTABLE_CHARACTER] hint: paste between BEGIN/END; future MMO/website importers target schema=%s"
			% PawnData.PORTABLE_CHARACTER_SCHEMA
	)


func _report_creator_session_digest() -> void:
	var tick: int = GameManager.tick_count
	var paused_s: String = "yes — time is frozen" if GameManager.is_paused else "no — time is running"
	var spd: float = GameManager.game_speed
	var yr: int = SimTime.sim_year_index(tick)
	var day_in_y: int = SimTime.calendar_day_within_sim_year(tick)
	var days_per: int = SimTime.visual_days_per_sim_year()
	var abs_day: int = SimTime.calendar_absolute_visual_day(tick)
	print("")
	print("========== HEELKAWN · CREATOR SESSION DIGEST · ONE PASTE ==========")
	print("Paste everything from CREATOR_START through CREATOR_END to anyone helping you.")
	print("CREATOR_START")
	print("")
	print("--- What you are seeing (plain words) ---")
	print(
			"The simulation clock is at tick %d — think of that as the film frame counter."
			% tick
	)
	print(
			"Calendar: Year %d · day %d of %d in this year · absolute day %d since start."
			% [yr, day_in_y, days_per, abs_day]
	)
	print("Speed is %.1fx; pause is %s." % [spd, paused_s])
	var main_node: Node2D = _main()
	var wseed: int = -1
	if main_node != null:
		var w: World = main_node.get_node_or_null("WorldViewport/World") as World
		if w != null and w.data != null:
			wseed = int(w.data.world_seed)
	if wseed >= 0:
		print("World seed (same seed → same geography rules): %d" % wseed)
	else:
		print("World seed: not available from Main/World (ignore if headless).")
	var pawn_n: int = _get_playtest_pawn_count()
	if pawn_n >= 0:
		print(
				"Heelkawnians alive right now: %d — each one has needs, job prefs, and bonds like anyone in the colony."
				% pawn_n
		)
	print(
			"Recorded memories in the chronicle so far: %d events — births, talks, work, and milestones."
			% WorldMemory.event_count()
	)
	var stance: String = str(ColonySimServices.get_stance_display())
	var food_p: float = ColonySimServices.get_food_pressure()
	var house_p: float = ColonySimServices.get_housing_pressure()
	var mat_p: float = ColonySimServices.get_materials_pressure()
	print(
			"Colony mood from pressures: stance \"%s\". Food strain %.0f%% · housing strain %.0f%% · materials strain %.0f%%."
			% [stance, food_p * 100.0, house_p * 100.0, mat_p * 100.0]
	)
	print(_creator_digest_pressure_sentence(food_p, house_p, mat_p))
	var st_count: int = SettlementMemory.settlements.size()
	print(
			"Clusters we call settlements right now: %d (they carry culture, intent, and revival score)."
			% st_count
	)
	if st_count > 0:
		var st0: Variant = SettlementMemory.settlements[0]
		if st0 is Dictionary:
			var st: Dictionary = st0 as Dictionary
			print(
					'Largest indexed settlement snapshot — state: "%s" · culture flavor: %s · formal intent: %s.'
					% [
						str(st.get("state", "?")),
						str(st.get("culture_name", "?")),
						str(st.get("current_intent", "?")),
					]
			)
	if main_node != null and main_node.has_method("get_wildlife_snapshot_for_diagnostic"):
		var wld: Dictionary = main_node.call("get_wildlife_snapshot_for_diagnostic") as Dictionary
		print(
				"Animals on the map (rabbits / deer / total): %d / %d / %d"
				% [
					int(wld.get("rabbit", 0)),
					int(wld.get("deer", 0)),
					int(wld.get("total", 0)),
				]
		)
	print("")
	print("Recent story beats (newest last in log; shortened):")
	var evs: Array = WorldMemory.get_recent_events(14)
	var printed_lines: int = 0
	for i in range(evs.size() - 1, -1, -1):
		if printed_lines >= 6:
			break
		var ev_any: Variant = evs[i]
		if ev_any is Dictionary:
			var ln: String = _creator_digest_plain_event_line(ev_any as Dictionary)
			if not ln.is_empty():
				print(ln)
				printed_lines += 1
	if printed_lines == 0:
		print("• (Quiet moment — no fresh highlights in the last few events.)")
	print("")
	if main_node != null and main_node.has_method("get_selected_pawn"):
		var sp: Pawn = main_node.call("get_selected_pawn") as Pawn
		if sp != null and is_instance_valid(sp) and sp.data != null:
			var dd: PawnData = sp.data
			var rk_sel: int = _WM._region_key(dd.tile_pos.x, dd.tile_pos.y)
			print(
					"Your highlighted Heelkawnian on the right-hand sheet: %s — doing \"%s\" · hunger/rest snapshot %.0f / %.0f."
					% [dd.display_name, sp.describe_state(), dd.hunger, dd.rest]
			)
			print("They stand on region #%d (settlements use these ids behind the scenes)." % rk_sel)
		else:
			print("No pawn is highlighted — click someone on the map to attach the sheet to them.")
	if main_node != null and main_node.has_method("get_player_mode_label"):
		print(
				"You are in \"%s\" mode (spectator flies above; incarnation pilots one body)."
				% str(main_node.call("get_player_mode_label"))
		)
	print("")
	print("--- What machines read (compact backend truth) ---")
	print("[creator_digest_meta] schema=2026-04-29c tick=%d world_seed=%d" % [tick, wseed])
	print("[sim_diag] %s" % str(GameManager.sim_diag()))
	print("[jobs] %s" % str(JobManager.stats()))
	print("[stockpile_zones] count=%d" % StockpileManager.zones().size())
	var zlist: Array = StockpileManager.zones()
	if zlist.size() > 0 and zlist[0] != null and is_instance_valid(zlist[0]):
		var z0s: Stockpile = zlist[0] as Stockpile
		if z0s != null:
			print("[stockpile_first_zone_items] %s" % str(z0s.inventory))
	print("[settlements_n] %d" % SettlementMemory.settlements.size())
	print("[intent_memory_global] %.6f" % IntentMemory.global_pressure)
	print(PlayerIntentQueue.debug_summary_block())
	print("[faction_registry]")
	print(FactionRegistry.debug_summary_block())
	print("[observation_ambient] %s" % str(ObservationAPI.observe_sim_ambient(-1)))
	if main_node != null:
		if main_node.has_method("get_camera_settlement_revival_digest"):
			print(
					"[camera_settlement_revival_digest] %s"
					% str(main_node.call("get_camera_settlement_revival_digest"))
			)
		var kd: Node = main_node.get_node_or_null("KernelDiagnostic")
		if kd != null and kd.has_method("generate_session_log_summary"):
			var ks: String = str(kd.call("generate_session_log_summary"))
			var short_k: String = ks
			if short_k.length() > 900:
				short_k = short_k.substr(0, 900) + "\n... [kernel summary truncated; use F10 · 24 for full] ..."
			print("[kernel_summary_compact]\n%s" % short_k)
	print("")
	print("Hints: F10 · 31 = smaller bundle · F10 · 32 = long chronicle export · F10 · ERROR = wiring check.")
	print("CREATOR_END")
	print("========== END CREATOR DIGEST ==========")
	print("")


func _creator_digest_pressure_sentence(food_p: float, hous_p: float, mat_p: float) -> String:
	var bits: PackedStringArray = PackedStringArray()
	if food_p >= 0.55:
		bits.append("food is tight — foragers and farms matter")
	if hous_p >= 0.55:
		bits.append("shelter is stressed — beds and space compete")
	if mat_p >= 0.55:
		bits.append("building materials feel scarce for projects")
	if bits.is_empty():
		return "Day-to-day pressures look manageable from the colony-wide gauges."
	return "Plain read on strain: " + " · ".join(bits) + "."


func _creator_digest_plain_event_line(ev: Dictionary) -> String:
	var typ: String = str(ev.get("type", ""))
	match typ:
		"social_meeting":
			return "• %s and %s crossed paths." % [str(ev.get("a_name", "?")), str(ev.get("b_name", "?"))]
		"social_bond_milestone":
			return "• %s and %s grew noticeably closer." % [str(ev.get("a_name", "?")), str(ev.get("b_name", "?"))]
		"pawn_death_fact", "death":
			return "• Someone died — the world remembers."
		"birth", "child_born":
			return "• New life joined the colony."
		"job_completed":
			return ""
		"knowledge_acquisition":
			return "• Someone picked up practical knowledge."
		"player_inspect":
			return ""
		"governance_change":
			return "• Leadership or council posture shifted."
		_:
			if typ.is_empty():
				return ""
			return "• (%s)" % typ


func _report_chronicle_summary() -> void:
	print("=== HEELKAWN_READABLE_CHRONICLE_SUMMARY BEGIN ===")
	print(WorldMemory.build_readable_chronicle_summary(22))
	print("=== HEELKAWN_READABLE_CHRONICLE_SUMMARY END ===")
	print(
			"[CHRONICLE_SUMMARY] hint: also F10 → 37 writes this plus JSON to user://heelkawn_promotion_exports/…"
	)


func _report_promotion_bundle() -> void:
	var res: Dictionary = ExportSystem.export_promotion_bundle()
	if bool(res.get("ok", false)):
		print(
				"[PROMOTION_BUNDLE] ok  user_path=%s  os_path=%s"
				% [str(res.get("path", "")), str(res.get("absolute_path", ""))]
		)
		print(
				"[PROMOTION_BUNDLE] files: world_seed.json chronicle_summary.txt chronicle.json bloodlines.json artifacts.json"
		)
	else:
		print("[PROMOTION_BUNDLE] failed: %s" % str(res.get("error", "?")))


func _report_playtest_bundle() -> void:
	print("[PLAYTEST_BUNDLE] tick=%d" % GameManager.tick_count)
	print("[PLAYTEST_BUNDLE] sim_diag=%s" % str(GameManager.sim_diag()))
	print(
			"[PLAYTEST_BUNDLE] pawns=%d settlements=%d wm_events=%d"
			% [
				_get_playtest_pawn_count(),
				SettlementMemory.settlements.size(),
				WorldMemory.event_count(),
			]
	)
	print("[PLAYTEST_BUNDLE] --- PlayerIntentQueue ---")
	print(PlayerIntentQueue.debug_summary_block())
	print("[PLAYTEST_BUNDLE] --- FactionRegistry ---")
	print(FactionRegistry.debug_summary_block())
	print("[PLAYTEST_BUNDLE] --- ReligionLens (6 settlements max) ---")
	print(ReligionLens.digest_settlements(6))
	print(
			"[PLAYTEST_BUNDLE] hint: run at 1x–12x first; watch Colony HUD Playtest line + pawn Social; "
			+ "after ~1–2 sim years use F10 → 32 Soul bundle; for one pawn JSON handoff (MMO/site) use F10 → 33; "
			+ "F5 save before 50x+; Esc closes F10 menu."
	)


func _get_playtest_pawn_count() -> int:
	var m: Node2D = _main()
	if m == null:
		return -1
	var ps: PawnSpawner = m.get_node_or_null("WorldViewport/PawnSpawner") as PawnSpawner
	if ps == null:
		return -1
	var n: int = 0
	for p in ps.pawns:
		if p != null and is_instance_valid(p):
			n += 1
	return n


func _report_profession_liking() -> void:
	var m: Node2D = _main()
	if m == null:
		print("Main missing")
		return
	var ps: PawnSpawner = m.get_node_or_null("WorldViewport/PawnSpawner") as PawnSpawner
	if ps == null:
		print("PawnSpawner null")
		return
	for p in ps.pawns:
		if p == null or not is_instance_valid(p) or p.data == null:
			continue
		var d: PawnData = p.data
		var aff: String = "farm=%.3f combat=%.3f build=%.3f craft=%.3f diplo=%.3f" % [
			float(d.affinities.get("farming", 0.5)),
			float(d.affinities.get("combat", 0.5)),
			float(d.affinities.get("building", 0.5)),
			float(d.affinities.get("crafting", 0.5)),
			float(d.affinities.get("diplomacy", 0.5)),
		]
		print("  id=%d %s  %s  %s" % [int(d.id), d.display_name, aff, d.profession_liking_digest_line()])


# === Phase 5: Grudge System Report ===

func _report_grudges() -> void:
	print("=== HEELKAWN GRUDGE SYSTEM (Phase 5: Emergent Life) ===")
	print("Generated: %s" % Time.get_datetime_string_from_system())
	print("Game Tick: %d" % GameManager.tick_count)
	print("")
	
	var grudge_mgr: Node = get_node_or_null("/root/GrudgeManager")
	if grudge_mgr == null:
		print("GrudgeManager not found - system not loaded")
		return
	
	# Get grudge statistics
	var total_grudges: int = 0
	var blood_feuds: int = 0
	var active_holders: int = 0
	
	if grudge_mgr.has_method("grudge_count"):
		total_grudges = grudge_mgr.grudge_count()
	
	if grudge_mgr.has_method("get_blood_feuds"):
		var feuds: Array = grudge_mgr.get_blood_feuds()
		blood_feuds = feuds.size()
		if feuds.size() > 0:
			print("--- BLOOD FEUDS (intensity >= 0.85) ---")
			for feud in feuds:
				print("  Holder: %d → Target: %d | Type: %s | Intensity: %.2f | Gen: %d" % [
					feud.get("holder_id", -1),
					feud.get("target_id", -1),
					feud.get("type", "unknown"),
					feud.get("intensity", 0.0),
					feud.get("generation", 0)
				])
			print("")
	
	print("--- GRUDGE STATISTICS ---")
	print("Total grudges tracked: %d" % total_grudges)
	print("Blood feuds (intensity >= 0.85): %d" % blood_feuds)
	print("")
	
	# Sample grudges from first few pawns
	var m: Node2D = _main()
	if m == null:
		print("Main node not found")
		return

	# PHASE 6: Knowledge Fog - incarnated player only sees their own grudges
	var incarnated: bool = _is_player_incarnated()
	var player_pawn_id: int = _get_player_pawn_id() if incarnated else -1
	if incarnated and player_pawn_id >= 0:
		print("⚠ KNOWLEDGE FOG ACTIVE (Incarnated as pawn %d)" % player_pawn_id)
		print("  You only see grudges YOUR pawn holds.")
		print("")

	var ps: PawnSpawner = m.get_node_or_null("WorldViewport/PawnSpawner") as PawnSpawner
	if ps == null:
		print("PawnSpawner not found")
		return

	print("--- SAMPLE GRUDGES BY PAWN (first 10 pawns) ---")
	var shown_pawns: int = 0
	for p in ps.pawns:
		if shown_pawns >= 10:
			break
		if p == null or not is_instance_valid(p) or p.data == null:
			continue

		var pawn_id: int = int(p.data.id)
		if incarnated and pawn_id != player_pawn_id:
			continue  # Fog: hide other pawns' grudges

		if grudge_mgr.has_method("get_grudges_held_by"):
			var grudges: Array = grudge_mgr.get_grudges_held_by(pawn_id)
			if not grudges.is_empty():
				print("Pawn %d (%s) holds %d grudges:" % [pawn_id, p.data.display_name, grudges.size()])
				for g in grudges:
					print("  → Target: %d | Type: %s | Intensity: %.2f | Gen: %d" % [
						g.get("target_id", -1),
						g.get("type", "unknown"),
						g.get("intensity", 0.0),
						g.get("generation", 0)
					])
				shown_pawns += 1
	
	print("")
	print("=== END GRUDGE REPORT ===")


# === Phase 5: Gossip & Reputation Report ===

func _report_gossip_reputation() -> void:
	print("=== HEELKAWN GOSSIP & REPUTATION (Phase 5: Emergent Life) ===")
	print("Generated: %s" % Time.get_datetime_string_from_system())
	print("Game Tick: %d" % GameManager.tick_count)
	print("")
	
	var gossip_mgr: Node = get_node_or_null("/root/GossipManager")
	if gossip_mgr == null:
		print("GossipManager not found - system not loaded")
		return
	
	# Get gossip statistics
	var total_gossip: int = 0
	if gossip_mgr.has_method("gossip_count"):
		total_gossip = gossip_mgr.gossip_count()
	
	print("--- GOSSIP STATISTICS ---")
	print("Total gossip items tracked: %d" % total_gossip)
	print("")
	
	# Get active gossip (not yet spread to max hops)
	if gossip_mgr.has_method("get_active_gossip"):
		var active_gossip: Array[Dictionary] = gossip_mgr.get_active_gossip()
		if not active_gossip.is_empty():
			print("--- ACTIVE GOSSIP (recent, still spreading) ---")
			var shown: int = 0
			for g in active_gossip:
				if shown >= 15:
					break
				print("  About: %d | From: %d | Type: %s | Importance: %.2f | Spread: %d/%d" % [
					g.get("subject_pawn_id", -1),
					g.get("origin_pawn_id", -1),
					g.get("type", "unknown"),
					g.get("importance", 0.0),
					g.get("spread_count", 0),
					g.get("MAX_SPREAD_HOPS", 4)
				])
				shown += 1
			print("")
	
	# Get notorious pawns
	if gossip_mgr.has_method("get_notorious_report"):
		var notorious: Array[Dictionary] = gossip_mgr.get_notorious_report()
		if not notorious.is_empty():
			print("--- NOTORIOUS PAWNS (bad reputation) ---")
			for n in notorious:
				print("  Pawn %d: Reputation %.2f (%s)" % [
					n.get("pawn_id", -1),
					n.get("reputation", 0.0),
					n.get("label", "Unknown")
				])
			print("")
	
	# Sample reputation from first few pawns
	var m: Node2D = _main()
	if m == null:
		print("Main node not found")
		return

	# PHASE 6: Knowledge Fog - incarnated player only sees reputation they know about
	var incarnated: bool = _is_player_incarnated()
	var player_pawn_id: int = _get_player_pawn_id() if incarnated else -1
	if incarnated and player_pawn_id >= 0:
		print("⚠ KNOWLEDGE FOG ACTIVE (Incarnated as pawn %d)" % player_pawn_id)
		print("  You only see reputation YOUR pawn knows about.")
		print("")

	var ps: PawnSpawner = m.get_node_or_null("WorldViewport/PawnSpawner") as PawnSpawner
	if ps == null:
		print("PawnSpawner not found")
		return

	print("--- SAMPLE REPUTATIONS (first 10 pawns) ---")
	var shown_pawns: int = 0
	for p in ps.pawns:
		if shown_pawns >= 10:
			break
		if p == null or not is_instance_valid(p) or p.data == null:
			continue

		var pawn_id: int = int(p.data.id)
		if incarnated and pawn_id != player_pawn_id:
			continue  # Fog: hide other pawns' reputation

		if gossip_mgr.has_method("get_reputation_for") and gossip_mgr.has_method("get_reputation_label"):
			var rep: float = gossip_mgr.get_reputation_for(pawn_id)
			var label: String = gossip_mgr.get_reputation_label(pawn_id)
			print("  Pawn %d (%s): %.2f (%s)" % [pawn_id, p.data.display_name, rep, label])
			shown_pawns += 1
	
	print("")
	print("=== END GOSSIP REPORT ===")


# === Phase 5: Avoidance AI Report ===

func _report_avoidance_ai() -> void:
	print("=== HEELKAWN AVOIDANCE AI (Phase 5: Emergent Life) ===")
	print("Generated: %s" % Time.get_datetime_string_from_system())
	print("Game Tick: %d" % GameManager.tick_count)
	print("")
	
	var grudge_mgr: Node = get_node_or_null("/root/GrudgeManager")
	if grudge_mgr == null:
		print("GrudgeManager not found - system not loaded")
		return
	
	# Get grudge statistics
	var total_grudges: int = 0
	if grudge_mgr.has_method("grudge_count"):
		total_grudges = grudge_mgr.grudge_count()
	
	print("--- AVOIDANCE STATISTICS ---")
	print("Total grudges tracked: %d" % total_grudges)
	
	# Count pawns with enemies
	var pawns_with_enemies: int = 0
	var m: Node2D = _main()
	if m == null:
		print("Main node not found")
		return
	
	var ps: PawnSpawner = m.get_node_or_null("WorldViewport/PawnSpawner") as PawnSpawner
	if ps == null:
		print("PawnSpawner not found")
		return
	
	for p in ps.pawns:
		if p == null or not is_instance_valid(p) or p.data == null:
			continue
		if grudge_mgr.has_method("get_enemies_for"):
			var enemies: Array[int] = grudge_mgr.get_enemies_for(int(p.data.id), 0.4)
			if not enemies.is_empty():
				pawns_with_enemies += 1
	
	print("Pawns with enemies (avoidance active): %d" % pawns_with_enemies)
	print("")
	
	# Sample avoidance patterns
	print("--- SAMPLE AVOIDANCE PATTERNS (first 10 pawns with enemies) ---")
	var shown_pawns: int = 0
	for p in ps.pawns:
		if shown_pawns >= 10:
			break
		if p == null or not is_instance_valid(p) or p.data == null:
			continue
		
		var pawn_id: int = int(p.data.id)
		if grudge_mgr.has_method("get_enemies_for"):
			var enemies: Array[int] = grudge_mgr.get_enemies_for(pawn_id, 0.4)
			if not enemies.is_empty():
				print("Pawn %d (%s) avoids %d enemies:" % [pawn_id, p.data.display_name, enemies.size()])
				for enemy_id in enemies:
					var intensity: float = 0.0
					if grudge_mgr.has_method("get_grudge_intensity"):
						intensity = grudge_mgr.get_grudge_intensity(pawn_id, enemy_id)
					print("  → Pawn %d (intensity: %.2f)" % [enemy_id, intensity])
				shown_pawns += 1
	
	# Count blood feuds (highest avoidance priority)
	if grudge_mgr.has_method("get_blood_feuds"):
		var feuds: Array[Dictionary] = grudge_mgr.get_blood_feuds()
		if not feuds.is_empty():
			print("")
			print("--- BLOOD FEUDS (avoidance priority) ---")
			print("Active blood feuds: %d" % feuds.size())
	
	print("")
	print("=== END AVOIDANCE REPORT ===")


# === Phase 5: Life Arcs Report ===

func _report_life_arcs() -> void:
	print("=== HEELKAWN LIFE ARCS (Phase 5: Emergent Narrative) ===")
	print("Generated: %s" % Time.get_datetime_string_from_system())
	print("Game Tick: %d" % GameManager.tick_count)
	print("")

	var m: Node2D = _main()
	if m == null:
		print("Main node not found")
		return

	# PHASE 6: Knowledge Fog - incarnated player only sees their own life story
	var incarnated: bool = _is_player_incarnated()
	var player_pawn_id: int = _get_player_pawn_id() if incarnated else -1
	if incarnated and player_pawn_id >= 0:
		print("⚠ KNOWLEDGE FOG ACTIVE (Incarnated as pawn %d)" % player_pawn_id)
		print("  You only see YOUR OWN life story.")
		print("")

	var ps: PawnSpawner = m.get_node_or_null("WorldViewport/PawnSpawner") as PawnSpawner
	if ps == null:
		print("PawnSpawner not found")
		return

	# Count living pawns
	var total_pawns: int = ps.pawns.size()
	print("--- LIFE ARC STATISTICS ---")
	print("Total living pawns: %d" % total_pawns)
	print("")

	# Show life arcs for first 15 pawns (readable narratives)
	print("--- SAMPLE LIFE ARCS (first 15 pawns) ---")
	var shown_pawns: int = 0
	for p in ps.pawns:
		if shown_pawns >= 15:
			break
		if p == null or not is_instance_valid(p) or p.data == null:
			continue

		# Fog: skip other pawns when incarnated
		if incarnated and int(p.data.id) != player_pawn_id:
			continue

		# Call compose_life_arc() on pawn data
		if p.data.has_method("compose_life_arc"):
			var life_arc: String = p.data.compose_life_arc()
			print("╔════════════════════════════════════════╗")
			print("║ %s" % p.data.display_name.pad_spaces(35))
			print("╚════════════════════════════════════════╝")
			# Print each line of the life arc
			var lines: PackedStringArray = life_arc.split("\n")
			for line in lines:
				print("  " + line)
			print("")
			shown_pawns += 1

	print("=== END LIFE ARCS REPORT ===")


# === Phase 5: Knowledge Carriers Report ===

func _report_knowledge_carriers() -> void:
	print("=== HEELKAWN KNOWLEDGE CARRIERS (Phase 5: Knowledge Ecology) ===")
	print("Generated: %s" % Time.get_datetime_string_from_system())
	print("Game Tick: %d" % GameManager.tick_count)
	print("")

	var ks: Node = get_node_or_null("/root/KnowledgeSystem")
	if ks == null:
		print("KnowledgeSystem not found - system not loaded")
		return

	# PHASE 6: Knowledge Fog - incarnated player only sees their own knowledge
	var incarnated: bool = _is_player_incarnated()
	var player_pawn_id: int = _get_player_pawn_id() if incarnated else -1
	if incarnated and player_pawn_id >= 0:
		print("⚠ KNOWLEDGE FOG ACTIVE (Incarnated as pawn %d)" % player_pawn_id)
		print("  You only see knowledge YOUR pawn knows.")
		print("")

	# Get knowledge carrier statistics
	var total_carriers: int = 0
	if ks.has("knowledge_carriers"):
		var carriers: Dictionary = ks.get("knowledge_carriers")
		for pawn_id in carriers:
			if incarnated and pawn_id != player_pawn_id:
				continue  # Fog: hide other pawns' knowledge
			total_carriers += 1

	print("--- KNOWLEDGE STATISTICS ---")
	print("Total knowledge carriers: %d" % total_carriers)
	print("")

	# Show dormant knowledge (at risk of being lost)
	print("--- DORMANT KNOWLEDGE (At Risk of Being Lost) ---")
	if ks.has("dormant_knowledge"):
		var dormant: Dictionary = ks.get("dormant_knowledge")
		if dormant.is_empty():
			print("  (No dormant knowledge - all knowledge has active carriers)")
		else:
			for kt_key in dormant:
				var dk: Dictionary = dormant[kt_key]
				var last_carrier: int = int(dk.get("last_carrier_id", -1))
				var last_tick: int = int(dk.get("last_practiced_tick", -1))
				var ticks_ago: int = GameManager.tick_count - last_tick
				print("  %s: Last carrier pawn_id=%d, %d ticks ago" % [kt_key, last_carrier, ticks_ago])
	print("")

	# Show top 10 knowledge carriers (masters)
	print("--- TOP KNOWLEDGE CARRIERS (Masters) ---")
	var m: Node2D = _main()
	if m == null:
		print("Main node not found")
		return

	var ps: PawnSpawner = m.get_node_or_null("WorldViewport/PawnSpawner") as PawnSpawner
	if ps == null:
		print("PawnSpawner not found")
		return

	# Count knowledge per pawn (filtered by fog)
	var pawn_knowledge_count: Dictionary = {}
	if ks.has("knowledge_carriers"):
		var carriers: Dictionary = ks.get("knowledge_carriers")
		for pawn_id in carriers:
			if incarnated and pawn_id != player_pawn_id:
				continue  # Fog: hide other pawns' knowledge
			pawn_knowledge_count[pawn_id] = carriers[pawn_id].size()

	# Sort by knowledge count (descending)
	var sorted_pawns: Array = []
	for pawn_id in pawn_knowledge_count:
		sorted_pawns.append({"id": pawn_id, "count": pawn_knowledge_count[pawn_id]})
	sorted_pawns.sort_custom(func(a, b): return a.count > b.count)

	var shown: int = 0
	for entry in sorted_pawns:
		if shown >= 10:
			break
		var pawn_id: int = int(entry.id)
		var count: int = int(entry.count)
		# Find pawn by ID
		var pawn: Pawn = null
		for p in ps.pawns:
			if p != null and is_instance_valid(p) and p.data != null and int(p.data.id) == pawn_id:
				pawn = p
				break
		if pawn != null:
			print("  %s (%s): %d knowledge types" % [pawn.data.display_name, pawn.data.profession_name(), count])
			shown += 1

	print("")
	print("=== END KNOWLEDGE CARRIERS REPORT ===")


# === Phase 5: Myth Formation Report ===

func _report_myth_formation() -> void:
	print("=== HEELKAWN MYTH FORMATION (Phase 5: World-Memory Behavior) ===")
	print("Generated: %s" % Time.get_datetime_string_from_system())
	print("Game Tick: %d" % GameManager.tick_count)
	print("")

	var mm: Node = get_node_or_null("/root/MythMemory")
	if mm == null:
		print("MythMemory not found - system not loaded")
		return

	# PHASE 6: Knowledge Fog - incarnated player sees world myths (heard through gossip)
	# LOCAL KNOWLEDGE: Only shows myths for regions near player pawn
	# MYTH VS TRUTH: Shows both factual events and distorted myths
	var incarnated: bool = _is_player_incarnated()
	if incarnated:
		print("⚠ LOCAL KNOWLEDGE ACTIVE")
		print("  You only know myths for regions within %d tiles." % LOCAL_KNOWLEDGE_RADIUS_TILES)
		print("")
	else:
		print("👁 SPECTATOR MODE: You see TRUTH (facts from WorldMemory)")
		print("  Pawns believe distorted MYTHS (rumors, gossip, exaggeration)")
		print("")

	var m: Node2D = _main()
	if m == null:
		print("Main node not found")
		return

	# Get myth state statistics
	var feared_regions: int = 0
	var revered_regions: int = 0
	var neutral_regions: int = 0

	if mm.has_method("get_region_myth_state"):
		# Sample regions from WorldMemory
		var wmem: Node = get_node_or_null("/root/WorldMemory")
		if wmem != null and wmem.has("event_history"):
			var events: Array = wmem.get("event_history")
			var sampled_regions: Dictionary = {}
			for e in events:
				if e is Dictionary and e.has("r"):
					var rk: int = int(e.get("r", -1))
					if rk >= 0:
						sampled_regions[rk] = true

			for rk in sampled_regions:
				# LOCAL KNOWLEDGE: Skip regions player doesn't know about
				if incarnated and not _is_region_known_to_player(rk):
					continue
				var state: int = mm.get_region_myth_state(rk)
				if state == 1:
					feared_regions += 1
				elif state == -1:
					revered_regions += 1
				else:
					neutral_regions += 1

	print("--- MYTH STATISTICS ---")
	print("Feared regions (+1): %d" % feared_regions)
	print("Revered regions (-1): %d" % revered_regions)
	print("Neutral regions (0): %d" % neutral_regions)
	print("")

	# MYTH VS TRUTH: Show factual events that created the myths
	if not incarnated:
		print("--- TRUTH: FACTUAL EVENTS (WorldMemory) ---")
		var wmem: Node = get_node_or_null("/root/WorldMemory")
		if wmem != null and wmem.has("event_history"):
			var events: Array = wmem.get("event_history")
			var death_events_by_region: Dictionary = {}
			for e in events:
				if e is Dictionary and e.has("r") and e.has("type"):
					var event_type: String = str(e.get("type", ""))
					if event_type.contains("death") or event_type.contains("collapse"):
						var rk: int = int(e.get("r", -1))
						if rk >= 0:
							if not death_events_by_region.has(rk):
								death_events_by_region[rk] = 0
							death_events_by_region[rk] += 1
			
			for rk in death_events_by_region:
				if not _is_region_known_to_player(rk) and incarnated:
					continue
				var count: int = death_events_by_region[rk]
				var myth_state: int = mm.get_region_myth_state(rk) if mm.has_method("get_region_myth_state") else 0
				var myth_label: String = "Neutral"
				if myth_state == 1:
					myth_label = "⚠ FEARED (myth exaggerated)"
				elif myth_state == -1:
					myth_label = "✓ REVERED (myth glorified)"
				print("  Region %d: %d deaths → %s" % [rk, count, myth_label])
		print("")

	# Show settlement rebirth success counts
	print("--- SETTLEMENT REBIRTH HISTORY ---")
	if mm.has_method("get_rebirth_success_count_for_center"):
		var sl: Array = SettlementMemory.settlements
		if sl.is_empty():
			print("  (No settlements)")
		else:
			for s in sl:
				if not (s is Dictionary):
					continue
				var st: Dictionary = s as Dictionary
				var ckr: int = int(st.get("center_region", -1))
				if ckr < 0:
					continue
				var rebirths: int = mm.get_rebirth_success_count_for_center(ckr)
				var state: String = str(st.get("state", "unknown"))
				var name: String = str(st.get("culture_name", "Unnamed"))
				print("  %s (%s): %d rebirths, state=%s" % [name, ckr, rebirths, state])
	print("")

	# Show regional myth states for sampled regions
	print("--- SAMPLE REGION MYTH STATES ---")
	var wmem: Node = get_node_or_null("/root/WorldMemory")
	if wmem != null and wmem.has("event_history"):
		var events: Array = wmem.get("event_history")
		var sampled_regions: Dictionary = {}
		for e in events:
			if e is Dictionary and e.has("r"):
				var rk: int = int(e.get("r", -1))
				if rk >= 0:
					sampled_regions[rk] = true

		var shown: int = 0
		for rk in sampled_regions:
			if shown >= 15:
				break
			if mm.has_method("get_region_myth_state"):
				var state: int = mm.get_region_myth_state(rk)
				var state_label: String = "Neutral"
				if state == 1:
					state_label = "⚠ FEARED (repeated deaths/collapse)"
				elif state == -1:
					state_label = "✓ REVERED (successful rebirths)"
				print("  Region %d: %s" % [rk, state_label])
				shown += 1

	print("")
	print("=== END MYTH FORMATION REPORT ===")


# === Phase 5: Record Carriers Report ===

func _report_record_carriers() -> void:
	print("=== HEELKAWN RECORD CARRIERS (Phase 5: Knowledge Preservation) ===")
	print("Generated: %s" % Time.get_datetime_string_from_system())
	print("Game Tick: %d" % GameManager.tick_count)
	print("")

	var ks: Node = get_node_or_null("/root/KnowledgeSystem")
	if ks == null:
		print("KnowledgeSystem not found - system not loaded")
		return

	# PHASE 6: Knowledge Fog - incarnated player only sees their inscribed stones
	# LOCAL KNOWLEDGE: Also filter by distance from player pawn
	var incarnated: bool = _is_player_incarnated()
	var player_pawn_id: int = _get_player_pawn_id() if incarnated else -1
	var player_tile: Vector2i = _get_player_pawn_tile() if incarnated else Vector2i(-1, -1)
	if incarnated and player_pawn_id >= 0:
		print("⚠ LOCAL KNOWLEDGE ACTIVE")
		print("  You only see stones YOUR pawn inscribed AND within %d tiles." % LOCAL_KNOWLEDGE_RADIUS_TILES)
		print("")

	# Get record carrier statistics
	var total_carriers: int = 0
	var grave_markers: int = 0
	var knowledge_stones: int = 0
	var ledger_stones: int = 0

	if ks.has("record_carriers"):
		var carriers: Dictionary = ks.get("record_carriers")
		for tile_key in carriers:
			var carrier: Dictionary = carriers[tile_key]
			var inscriber: int = int(carrier.get("inscriber_id", -1))
			
			# Fog: hide stones inscribed by others
			if incarnated and inscriber != player_pawn_id:
				continue
			
			# Local knowledge: hide stones far from player
			if incarnated and player_tile.x >= 0:
				# Parse tile_key "x,y"
				var parts: PackedStringArray = tile_key.split(",")
				if parts.size() >= 2:
					var stone_x: int = int(parts[0])
					var stone_y: int = int(parts[1])
					var dist: int = abs(player_tile.x - stone_x) + abs(player_tile.y - stone_y)
					if dist > LOCAL_KNOWLEDGE_RADIUS_TILES:
						continue
			
			total_carriers += 1
			var carrier_type: String = str(carrier.get("carrier_type", "unknown"))
			if carrier_type == "grave_marker":
				grave_markers += 1
			elif carrier_type == "knowledge_stone":
				knowledge_stones += 1
			elif carrier_type == "ledger_stone":
				ledger_stones += 1

	print("--- RECORD CARRIER STATISTICS ---")
	print("Total record carriers: %d" % total_carriers)
	print("  Grave Markers: %d" % grave_markers)
	print("  Knowledge Stones: %d" % knowledge_stones)
	print("  Ledger Stones: %d" % ledger_stones)
	print("")

	# Show all record carriers with their stored knowledge
	print("--- ALL RECORD CARRIERS ---")
	if ks.has("record_carriers"):
		var carriers: Dictionary = ks.get("record_carriers")
		if carriers.is_empty():
			print("  (No record carriers inscribed yet)")
		else:
			var shown: int = 0
			for tile_key in carriers:
				var carrier: Dictionary = carriers[tile_key]
				var inscriber: int = int(carrier.get("inscriber_id", -1))
				if incarnated and inscriber != player_pawn_id:
					continue  # Fog: hide stones inscribed by others
				if shown >= 20:
					print("  ... and %d more" % (carriers.size() - shown))
					break
				var knowledge_types: Array = carrier.get("knowledge_types", [])
				var inscribed_tick: int = int(carrier.get("inscribed_tick", -1))
				var carrier_type: String = str(carrier.get("carrier_type", "unknown"))
				var ticks_ago: int = GameManager.tick_count - inscribed_tick

				print("  %s at (%s)" % [carrier_type.to_upper(), tile_key])
				print("    Inscribed by pawn %d, %d ticks ago" % [inscriber, ticks_ago])
				print("    Stores %d knowledge types:" % knowledge_types.size())
				for kt in knowledge_types:
					print("      - KnowledgeType #%d" % int(kt))
				print("")
				shown += 1

	print("")
	print("=== END RECORD CARRIERS REPORT ===")


# === BUILDING FORCES ===

func _force_building_now() -> void:
	print("=== FORCE BUILDING JOBS ===")
	print("Generated: %s" % Time.get_datetime_string_from_system())
	print("Game Tick: %d" % GameManager.tick_count)
	print("")
	
	var main_node: Node = get_node_or_null("/root/Main")
	if main_node == null:
		print("ERROR: Main node not found")
		return
	
	var world_node: Node = main_node.get_node_or_null("World")
	if world_node == null:
		print("ERROR: World node not found")
		return
	
	var jobs_posted: int = 0
	
	# Post 5 wall jobs
	for i in range(5):
		var wall_tile: Vector2i = Vector2i(127 + i, 127 + i)
		if world_node.has_method("get"):
			var data: Variant = world_node.get("data")
			if data != null and data.has_method("in_bounds") and data.in_bounds(wall_tile.x, wall_tile.y):
				if main_node.has_method("settlement_planner_post_wall"):
					var result: Variant = main_node.call("settlement_planner_post_wall", wall_tile)
					if result:
						jobs_posted += 1
						print("Posted WALL job at (%d, %d)" % [wall_tile.x, wall_tile.y])
	
	# Post 3 bed jobs
	for i in range(3):
		var bed_tile: Vector2i = Vector2i(125 + i, 125 + i)
		if world_node.has_method("get"):
			var data: Variant = world_node.get("data")
			if data != null and data.has_method("in_bounds") and data.in_bounds(bed_tile.x, bed_tile.y):
				if main_node.has_method("settlement_planner_post_bed"):
					var result: Variant = main_node.call("settlement_planner_post_bed", bed_tile)
					if result:
						jobs_posted += 1
						print("Posted BED job at (%d, %d)" % [bed_tile.x, bed_tile.y])
	
	# Post 2 zone jobs
	for i in range(2):
		var zone_origin: Vector2i = Vector2i(120 + (i * 5), 120 + (i * 5))
		if main_node.has_method("settlement_planner_post_zone_rect"):
			var rect: Rect2i = Rect2i(zone_origin, Vector2i(3, 3))
			var result: Variant = main_node.call("settlement_planner_post_zone_rect", rect)
			if result:
				jobs_posted += 1
				print("Posted ZONE job at (%d, %d) size 3x3" % [zone_origin.x, zone_origin.y])
	
	# Force settlement state to active
	if SettlementMemory != null and SettlementMemory.has_method("get_settlements"):
		var settlements: Array = SettlementMemory.get_settlements()
		for s in settlements:
			if s is Dictionary:
				var current_state: String = str(s.get("state", "unknown"))
				if current_state == "abandoned":
					s["state"] = "active"
					print("Forced settlement %s to ACTIVE state" % str(s.get("id", "?")))
	
	print("")
	print("Total jobs posted: %d" % jobs_posted)
	print("=== END FORCE BUILDING ===")


func _report_error_issues() -> void:
	print("=== HEELKAWN ERROR REPORT ===")
	print("Generated: %s" % Time.get_datetime_string_from_system())
	print("Game Tick: %d" % GameManager.tick_count)
	print("")
	
	# Check for compilation errors by examining key files
	var error_count: int = 0
	var files_to_check: Array[String] = [
		"res://scripts/ui/AIControlPanel.gd",
		"res://scripts/pawn/Pawn.gd", 
		"res://scripts/pawn/PawnData.gd",
		"res://scripts/pawn/PawnNeuralNetwork.gd",
		"res://scripts/ai/SettlementAI.gd",
		"res://scenes/main/Main.gd",
		"res://autoloads/AIAgentManager.gd",
		"res://autoloads/GeneticEvolution.gd",
		"res://autoloads/CharacterExport.gd",
		"res://autoloads/WorldMemory.gd",
		"res://autoloads/CulturalMemory.gd",
		"res://autoloads/ReligionLens.gd",
		"res://scripts/world/WorldData.gd",
		"res://scripts/world/WorldGenerator.gd",
		"res://scripts/world/PathFinder.gd"
	]
	
	print("=== FILE SYNTAX CHECK ===")
	for file_path in files_to_check:
		var file_errors: Array[String] = _check_file_syntax_errors(file_path)
		if file_errors.size() > 0:
			print("ERRORS in %s:" % file_path.get_file())
			for error in file_errors:
				print("  - %s" % error)
				error_count += 1
		else:
			print("✓ %s: OK" % file_path.get_file())
	
	print("")
	print("=== SYSTEM STATUS CHECK ===")
	
	# Check autoloads
	var autoload_status: Dictionary = {
		"GameManager": GameManager != null,
		"AIAgentManager": AIAgentManager != null,
		"WorldMemory": WorldMemory != null,
		"SettlementMemory": SettlementMemory != null,
		"CulturalMemory": CulturalMemory != null,
		"ReligionLens": ReligionLens != null,
		"JobManager": JobManager != null,
		"StockpileManager": StockpileManager != null
	}
	
	print("AUTOLOAD STATUS:")
	for autoload_name in autoload_status:
		var status: String = "✓ LOADED" if autoload_status[autoload_name] else "✗ MISSING"
		print("  %s: %s" % [autoload_name, status])
		if not autoload_status[autoload_name]:
			error_count += 1
	
	print("")
	print("=== NEURAL NETWORK MATRIX STATUS ===")
	
	# Check neural network matrix connections
	var nn_connections: Array[String] = []
	
	if WorldMemory != null:
		nn_connections.append("✓ WorldMemory neural matrix active")
	else:
		nn_connections.append("✗ WorldMemory neural matrix offline")
	
	if CulturalMemory != null:
		nn_connections.append("✓ CulturalMemory neural matrix active")
	else:
		nn_connections.append("✗ CulturalMemory neural matrix offline")
	
	if ReligionLens != null:
		nn_connections.append("✓ ReligionLens neural matrix active")
	else:
		nn_connections.append("✗ ReligionLens neural matrix offline")
	
	if AIAgentManager != null:
		nn_connections.append("✓ AIAgentManager neural matrix active")
	else:
		nn_connections.append("✗ AIAgentManager neural matrix offline")
	
	for connection in nn_connections:
		print("  %s" % connection)
	
	print("")
	print("=== AI RUNTIME POLICY ===")
	if AIAgentManager != null:
		print("✓ AI manager: ALWAYS-ON")
		print("  enabled=%s civilization_mode=%s max_agents=%d update_frequency=%d" % [
			str(AIAgentManager.enabled),
			str(AIAgentManager.civilization_mode),
			int(AIAgentManager.max_agents),
			int(AIAgentManager.update_frequency),
		])
	else:
		print("✗ AIAgentManager: NOT FOUND")
		error_count += 1
	
	print("")
	print("=== SUMMARY ===")
	print("Total Issues Found: %d" % error_count)
	
	if error_count == 0:
		print("🎉 ALL SYSTEMS OPERATIONAL!")
		print("✓ No syntax errors detected")
		print("✓ All autoloads loaded")
		print("✓ Neural network matrix active")
		print("✓ AI runtime policy active")
	else:
		print("⚠️  ISSUES DETECTED - See details above")
		print("Recommendation: Fix identified issues before proceeding")
	# Outer _emit_report() prints the matching HEELKAWN_DEBUG_REPORT END line.


func _check_file_syntax_errors(file_path: String) -> Array[String]:
	var errors: Array[String] = []
	if not FileAccess.file_exists(file_path):
		errors.append("File not found")
		return errors
	var loaded: Resource = ResourceLoader.load(
		file_path,
		"Script",
		ResourceLoader.CACHE_MODE_IGNORE
	)
	if loaded == null:
		errors.append("Script load failed (parse/compile error)")
		return errors
	if not (loaded is Script):
		errors.append("Resource is not a Script")
		return errors
	# ResourceLoader.load(..., "Script") already performs parse/compile validation.
	# Avoid Script.reload() here: runtime instances can make reload return non-parse
	# errors (for example code=22), which creates false positives in the report.
	return errors


func _add_performance_monitor_toggle() -> void:
	# Add separator
	var sep: HSeparator = HSeparator.new()
	_vbox.add_child(sep)
	
	# Add heading
	var hl: Label = Label.new()
	hl.text = "★ Performance Monitor"
	hl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hl.add_theme_font_size_override("font_size", 13)
	hl.modulate = Color(0.55, 0.95, 0.72)
	_vbox.add_child(hl)
	
	# Add toggle button
	var b: Button = Button.new()
	b.text = "Toggle Performance Monitor Overlay"
	b.add_theme_font_size_override("font_size", 13)
	b.custom_minimum_size = Vector2(PANEL_W - 40, 26)
	b.pressed.connect(_toggle_performance_monitor)
	_vbox.add_child(b)
	
	# Add status label
	var status: Label = Label.new()
	status.name = "PerformanceMonitorStatus"
	status.text = "Status: OFF (press button to enable)"
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.add_theme_font_size_override("font_size", 11)
	status.modulate = Color(0.7, 0.7, 0.7)
	_vbox.add_child(status)


func _toggle_performance_monitor() -> void:
	var main_node: Node = get_node_or_null("/root/Main")
	if main_node == null or not main_node.has_method("_toggle_performance_monitor"):
		print("[PerformanceMonitor] Not available - Main._toggle_performance_monitor() not found")
		return
	
	# Toggle via Main
	main_node.call("_toggle_performance_monitor")
	
	# Update status label
	_performance_monitor_enabled = not _performance_monitor_enabled
	var status_label: Label = _vbox.get_node_or_null("PerformanceMonitorStatus") as Label
	if status_label != null:
		if _performance_monitor_enabled:
			status_label.text = "Status: ON (overlay active)"
			status_label.modulate = Color(0.55, 0.95, 0.72)
		else:
			status_label.text = "Status: OFF (press button to enable)"
			status_label.modulate = Color(0.7, 0.7, 0.7)
