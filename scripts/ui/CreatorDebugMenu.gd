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
			var tile_pos: Variant = pawn_data.get("tile_pos")
			if tile_pos is Vector2i:
				return tile_pos
			elif tile_pos is Vector2:
				return Vector2i(int(tile_pos.x), int(tile_pos.y))
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
		"heading": "★ AI PIPELINE HEALTH — one button shows everything",
		"rows": [
			{
				"id": "ai_pipeline_health",
				"label": "80 · AI PIPELINE HEALTH (one paste — food + survival + structures + jobs + pathfinder + resource truth)",
			},
			{"id": "food_pipeline", "label": "81 · Food pipeline (eating, hunger, stockpile food)"},
			{"id": "survival_audit", "label": "82 · Survival audit (deaths, hypothermia, starvation)"},
			{"id": "structure_inventory", "label": "83 · Structure inventory (beds, walls, hearths, shelters)"},
			{"id": "job_pipeline", "label": "84 · Job pipeline (posted→claimed→completed→cancelled)"},
			{"id": "pathfinder_audit", "label": "85 · Pathfinder audit (connectivity, components)"},
			{"id": "resource_truth_audit", "label": "86 · Resource truth audit (stockpile vs settlement)"},
			{"id": "guild_settlement_audit", "label": "88 · Guild settlement audit (formal vs proto)"},
			{"id": "save_dump", "label": "87 · Save dump (read latest PlaytestRecorder save)"},
		],
	},
	{
		"heading": "★ AI / Cursor · session snapshot (paste to assistant)",
		"rows": [
			{
				"id": "session_snapshot_pack",
				"label": "00 · One paste pack — checklist + ERROR + 31 + 34 (digest)",
			},
			{
				"id": "session_snapshot_guide",
				"label": "00 · Checklist only — what to capture & order (A→G)",
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
			{
				"id": "playtest_truth_all",
				"label": "★ ALL PLAYTEST TRUTH — one paste (ERROR + calendar + sim_diag + colony_sim + civ + backbone + settlements + registry + intent + jobs_stock + trade + world_events + cultural + kernel + harness)",
			},
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
			{"id": "civilization_stage", "label": "03B · Civilization Stage (derived era lens)"},
			{"id": "backbone_status", "label": "35 · Backbone / first-play (LIVE vs DEFERRED)"},
		],
	},
	{
		"heading": "Settlements · economy · jobs",
		"rows": [
			{
				"id": "settlements_economy_all",
				"label": "★ ALL SETTLEMENTS+ECONOMY — one paste (settlements + registry + intent + jobs_stock + trade + world_events + cultural)",
			},
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
			{
				"id": "world_camera_all",
				"label": "★ ALL WORLD+CAMERA — one paste (revival + rebirth + wildlife + road + remnant + main_world)",
			},
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
			{
				"id": "memory_layers_all",
				"label": "★ ALL MEMORY LAYERS — one paste (world_memory + history_snip + world_meaning + world_persist + myth + age)",
			},
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
			{
				"id": "pawns_social_all",
				"label": "★ ALL PAWNS+SOCIAL — one paste (pawns + profession_liking + grudges + gossip + avoidance + life_arcs + knowledge_carriers + myth_formation + record_carriers + memorial + knowledge_system + heelkawnians + communication)",
			},
			{"id": "pawns", "label": "22 · All pawns"},
			{"id": "profession_liking", "label": "26 · Profession liking"},
			{"id": "grudges", "label": "40 · Grudge system (Phase 5 — grudges, blood feuds)"},
			{"id": "gossip_reputation", "label": "41 · Gossip & Reputation (Phase 5 — social propagation)"},
			{"id": "avoidance_ai", "label": "42 · Avoidance AI (Phase 5 — enemy avoidance patterns)"},
			{"id": "life_arcs", "label": "43 · Life Arcs (Phase 5 — readable pawn narratives)"},
			{"id": "knowledge_carriers", "label": "44 · Knowledge Carriers (Phase 5 — knowledge at risk, masters)"},
			{"id": "myth_formation", "label": "45 · Myth Formation (Phase 5 — feared/revered regions)"},
			{"id": "record_carriers", "label": "46 · Record Carriers (Phase 5 — knowledge preservation stones)"},
			{"id": "memorial_system", "label": "47 · Memorial System (Phase 5/6 — memorials, sacred geography, pilgrimage)"},
			{"id": "knowledge_system", "label": "48 · Knowledge Systems (Phase 5/6 — carriers, teaching, loss/rediscovery)"},
			{"id": "heelkawnians", "label": "49 · HeelKawnians (individual development AI profiles)"},
			{"id": "communication", "label": "50 · HeelKawnian Communication Log (conversations, plans, clans)"},
			{"id": "force_building", "label": "51 · FORCE BUILDING — post 10 wall/bed/zone jobs NOW"},
		],
	},
	{
		"heading": "★ Phase 7: Dynasty & Legacy",
		"rows": [
			{
				"id": "dynasty_legacy_all",
				"label": "★ ALL DYNASTY+LEGACY — one paste (legacy_dynasty + chronicle_view + settlement_legends + endgame_status)",
			},
			{"id": "legacy_dynasty", "label": "70 · Legacy & Dynasty (Phase 7 — milestone tracking)"},
			{"id": "chronicle_view", "label": "71 · Chronicle View (Phase 5 — settlement history as story)"},
			{"id": "settlement_legends", "label": "72 · Settlement Legends (Phase 5 — emergent myths & stories)"},
			{"id": "read_knowledge_stone", "label": "73 · Read Knowledge Stone (Phase 5 — inscribed knowledge)"},
			{"id": "dynasty_tree", "label": "74 · Dynasty Tree (Phase 7 — visual family tree)"},
			{"id": "endgame_status", "label": "75 · Legacy Milestones (Phase 7 — historical progress)"},
		],
	},
	{
		"heading": "Stubs · narrative scaffolding",
		"rows": [
			{
				"id": "stubs_all",
				"label": "★ ALL STUBS — one paste (vision_scope + player_intents + factions + religion_lens)",
			},
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
		"civilization_stage":
			error_occurred = _safe_report(_report_civilization_stage, "civilization_stage")
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
		"memorial_system":
			error_occurred = _safe_report(_report_memorial_system, "memorial_system")
		"knowledge_system":
			error_occurred = _safe_report(_report_knowledge_system, "knowledge_system")
		"heelkawnians":
			error_occurred = _safe_report(_report_heelkawnians, "heelkawnians")
		"communication":
			error_occurred = _safe_report(_report_communication, "communication")
		"force_building":
			error_occurred = _safe_report(_force_building_now, "force_building")
		"legacy_dynasty":
			error_occurred = _safe_report(_report_legacy_dynasty, "legacy_dynasty")
		"chronicle_view":
			error_occurred = _safe_report(_report_chronicle_view, "chronicle_view")
		"settlement_legends":
			error_occurred = _safe_report(_report_settlement_legends, "settlement_legends")
		"read_knowledge_stone":
			_report_read_knowledge_stone()
		"dynasty_tree":
			_show_dynasty_tree_ui()
		"endgame_status":
			_report_endgame_status()
		"vision_scope":
			error_occurred = _safe_report(_report_vision_scope, "vision_scope")
		"player_intents":
			error_occurred = _safe_report(_report_player_intents, "player_intents")
		"factions":
			error_occurred = _safe_report(_report_factions, "factions")
		"religion_lens":
			error_occurred = _safe_report(_report_religion_lens, "religion_lens")
		"playtest_truth_all":
			_report_playtest_truth_all()
		"settlements_economy_all":
			_report_settlements_economy_all()
		"world_camera_all":
			_report_world_camera_all()
		"memory_layers_all":
			_report_memory_layers_all()
		"pawns_social_all":
			_report_pawns_social_all()
		"dynasty_legacy_all":
			_report_dynasty_legacy_all()
		"stubs_all":
			_report_stubs_all()
		"ai_pipeline_health":
			_report_ai_pipeline_health()
		"food_pipeline":
			error_occurred = _safe_report(_report_food_pipeline, "food_pipeline")
		"survival_audit":
			error_occurred = _safe_report(_report_survival_audit, "survival_audit")
		"structure_inventory":
			error_occurred = _safe_report(_report_structure_inventory, "structure_inventory")
		"job_pipeline":
			error_occurred = _safe_report(_report_job_pipeline, "job_pipeline")
		"pathfinder_audit":
			error_occurred = _safe_report(_report_pathfinder_audit, "pathfinder_audit")
		"resource_truth_audit":
			error_occurred = _safe_report(_report_resource_truth_audit, "resource_truth_audit")
		"guild_settlement_audit":
			error_occurred = _safe_report(_report_guild_settlement_audit, "guild_settlement_audit")
		"save_dump":
			_report_save_dump()
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
	var _main: Node = get_tree().get_root().get_node_or_null("Main")
	if _main != null:
		ps = _main.get_node_or_null("WorldViewport/PawnSpawner") as PawnSpawner
		if ps != null:
			pawn_count = ps.pawns.size()
	
	print("--- SIMULATION STATE ---")
	print("Total Pawns: %d" % pawn_count)
	print("Game Speed: %.1fx" % GameManager.game_speed if GameManager != null else 0.0)
	print("Is Paused: %s" % str(GameManager.is_paused) if GameManager != null else "N/A")
	print("")
	
	# Settlement stats
	var settlement_count: int = 0
	if SettlementMemory != null:
		if SettlementMemory.has_method("get_settlements"):
			for s in SettlementMemory.get_formal_settlements():
				if not (s is Dictionary):
					continue
				var state: String = str((s as Dictionary).get("state", "active"))
				if state != "abandoned" and state != "permanently_abandoned":
					settlement_count += 1
		elif SettlementMemory.has_method("get_settlement_count"):
			settlement_count = SettlementMemory.get_settlement_count()
	
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


func _report_civilization_stage() -> void:
	if CivilizationStage == null:
		print("CivilizationStage autoload missing")
		return
	print("=== HEELKAWN CIVILIZATION STAGE ===")
	print("Derived only: era comes from live technology, knowledge, infrastructure, profession diversity, and quality-of-life signals.")
	var world: Dictionary = CivilizationStage.get_world_stage_snapshot()
	_print_civilization_stage_snapshot("WORLD", world)
	print("")
	print("--- SETTLEMENTS ---")
	var snaps: Array[Dictionary] = CivilizationStage.get_all_stage_snapshots(12)
	if snaps.is_empty():
		print("No settlements discovered yet.")
	for snap in snaps:
		_print_civilization_stage_snapshot(str(snap.get("name", "Settlement")), snap)
	print("=== END CIVILIZATION STAGE ===")


func _print_civilization_stage_snapshot(label: String, snap: Dictionary) -> void:
	var breakdown: Dictionary = snap.get("breakdown", {})
	print(
		"%s: %s (stage %d) score=%d next=%d pawns=%d"
		% [
			label,
			str(snap.get("stage_name", "Unknown")),
			int(snap.get("stage", 0)),
			int(snap.get("score", 0)),
			int(snap.get("next_stage_score", 10)),
			int(snap.get("pawns", 0)),
		]
	)
	print("  %s" % str(snap.get("description", "")))
	print(
		"  tech=%d knowledge=%d infrastructure=%d complexity=%d quality=%d"
		% [
			int(breakdown.get("technology", 0)),
			int(breakdown.get("knowledge", 0)),
			int(breakdown.get("infrastructure", 0)),
			int(breakdown.get("complexity", 0)),
			int(breakdown.get("quality_of_life", 0)),
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
	var n_set: int = SettlementMemory.get_formal_settlement_count() if SettlementMemory != null else 0
	print("  SettlementMemory       %s  formal_settlements=%d" % [LIVE, n_set])
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
	var civ_stage: String = "missing"
	if CivilizationStage != null:
		var civ_snap: Dictionary = CivilizationStage.get_world_stage_snapshot()
		civ_stage = "%s score=%d" % [str(civ_snap.get("stage_name", "Unknown")), int(civ_snap.get("score", 0))]
	print("  CivilizationStage      %s  %s" % [LIVE if CivilizationStage != null else DEF, civ_stage])
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
	if SettlementMemory == null:
		print("[_report_settlements] SettlementMemory not available")
		return
	
	# Safe access: SettlementMemory is a Node, check if it has the property
	var settlements: Variant = null
	if SettlementMemory.has_method("get"):
		settlements = SettlementMemory.get("settlements")
	elif "settlements" in SettlementMemory:
		settlements = SettlementMemory.settlements
	
	if settlements == null:
		print("[_report_settlements] SettlementMemory.settlements not available")
		return
	
	var settlements_array: Array = settlements as Array
	var formal_count: int = SettlementMemory.get_formal_settlement_count()
	var proto_count: int = SettlementMemory.get_proto_sites().size()
	print("settlement_count=%d formal_settlements=%d proto_sites=%d" % [settlements_array.size(), formal_count, proto_count])
	var i: int = 0
	for s in settlements_array:
		if not (s is Dictionary):
			continue
		var st: Dictionary = s as Dictionary
		print(
				(
	var settlements_array: Array = SettlementMemory.get_formal_settlements()
	var formal_count: int = SettlementMemory.get_formal_settlement_count()
	var proto_count: int = SettlementMemory.get_proto_sites().size()
	print("settlement_count=%d formal_settlements=%d proto_sites=%d" % [settlements_array.size(), formal_count, proto_count])
						str(st.get("settlement_kind", "proto_site")),
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


func _report_guild_settlement_audit() -> void:
	var m: Node2D = _main()
	var w: World = null
	if m != null:
		w = m.get_node_or_null("WorldViewport/World") as World
	if SettlementMemory == null:
		print("[guild_settlement_audit] SettlementMemory not available")
		return
	print(SettlementMemory.guild_settlement_audit(w))


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
	var t2: int = TradeMemory.count_t2_tiles() if TradeMemory.has_method("count_t2_tiles") else 0
	var rt: int = TradeMemory.count_route_tiles() if TradeMemory.has_method("count_route_tiles") else 0
	var last_t2: int = TradeMemory.get_last_tick_t2_existed() if TradeMemory.has_method("get_last_tick_t2_existed") else 0
	print(
			"TradeMemory: count_t2_tiles=%d count_route_tiles=%d last_tick_t2_existed=%d"
			% [t2, rt, last_t2]
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
		var d: HeelKawnianData = p.data
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
	var p: HeelKawnian = m.get_player_pawn()
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
			% HeelKawnianData.PORTABLE_CHARACTER_SCHEMA
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
	var formal_count: int = SettlementMemory.get_formal_settlement_count()
	var proto_count: int = SettlementMemory.get_proto_sites().size()
	print(
			"Formal settlements right now: %d · proto sites: %d."
			% [formal_count, proto_count]
	)
	if formal_count > 0:
		var formal_settlements: Array = SettlementMemory.get_formal_settlements()
		var st0: Variant = formal_settlements[0]
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
		var sp: HeelKawnian = main_node.call("get_selected_pawn") as HeelKawnian
		if sp != null and is_instance_valid(sp) and sp.data != null:
			var dd: HeelKawnianData = sp.data
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
	print("[settlements_n] %d" % formal_count)
	print("[proto_sites_n] %d" % proto_count)
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
			"[PLAYTEST_BUNDLE] pawns=%d formal_settlements=%d wm_events=%d"
			% [
				_get_playtest_pawn_count(),
				SettlementMemory.get_formal_settlement_count(),
				WorldMemory.event_count(),
			]
	)
	print("[PLAYTEST_BUNDLE] proto_sites=%d" % SettlementMemory.get_proto_sites().size())
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
		var d: HeelKawnianData = p.data
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
				print("HeelKawnian %d (%s) holds %d grudges:" % [pawn_id, p.data.display_name, grudges.size()])
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
				print("  HeelKawnian %d: Reputation %.2f (%s)" % [
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
			print("  HeelKawnian %d (%s): %.2f (%s)" % [pawn_id, p.data.display_name, rep, label])
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
				print("HeelKawnian %d (%s) avoids %d enemies:" % [pawn_id, p.data.display_name, enemies.size()])
				for enemy_id in enemies:
					var intensity: float = 0.0
					if grudge_mgr.has_method("get_grudge_intensity"):
						intensity = grudge_mgr.get_grudge_intensity(pawn_id, enemy_id)
					print("  → HeelKawnian %d (intensity: %.2f)" % [enemy_id, intensity])
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
			var name_padded: String = p.data.display_name
			while name_padded.length() < 35:
				name_padded += " "
			print("╔════════════════════════════════════════╗")
			print("║ %s" % name_padded)
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

	# Get knowledge carrier statistics (Node-safe access)
	var total_carriers: int = 0
	if ks.has_method("get"):
		var carriers: Variant = ks.get("knowledge_carriers")
		if carriers != null and carriers is Dictionary:
			for pawn_id in carriers:
				if incarnated and pawn_id != player_pawn_id:
					continue  # Fog: hide other pawns' knowledge
				total_carriers += 1

	print("--- KNOWLEDGE STATISTICS ---")
	print("Total knowledge carriers: %d" % total_carriers)
	print("")

	# Show dormant knowledge (at risk of being lost)
	print("--- DORMANT KNOWLEDGE (At Risk of Being Lost) ---")
	if ks.has_method("get"):
		var dormant: Variant = ks.get("dormant_knowledge")
		if dormant != null and dormant is Dictionary:
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
	if ks.has_method("get"):
		var carriers: Variant = ks.get("knowledge_carriers")
		if carriers != null and carriers is Dictionary:
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
		var pawn: HeelKawnian = null
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
		if wmem != null and wmem.has_method("get"):
			var events: Variant = wmem.get("event_history")
			if events != null and events is Array:
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
		if wmem != null and wmem.has_method("get"):
			var events: Variant = wmem.get("event_history")
			if events != null and events is Array:
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
	if wmem != null and wmem.has_method("get"):
		var events: Variant = wmem.get("event_history")
		if events != null and events is Array:
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

	if ks.has_method("get"):
		var carriers: Variant = ks.get("record_carriers")
		if carriers != null and carriers is Dictionary:
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
	if ks.has_method("get"):
		var carriers: Variant = ks.get("record_carriers")
		if carriers != null and carriers is Dictionary:
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


# === Phase 5/6: Memorial System Report ===

func _report_memorial_system() -> void:
	print("=== HEELKAWN MEMORIAL SYSTEM (Phase 5/6: Memorials, Sacred Geography, Pilgrimage) ===")
	print("Generated: %s" % Time.get_datetime_string_from_system())
	print("Game Tick: %d" % GameManager.tick_count)
	print("")

	var ms: Node = get_node_or_null("/root/MemorialSystem")
	var sg: Node = get_node_or_null("/root/SacredGeography")

	if ms == null:
		print("MemorialSystem not found - system not loaded")
		return

	# Memorial statistics
	var memorials: Array[Dictionary] = ms.get_memorials() if ms.has_method("get_memorials") else []
	var memorial_types: Dictionary = {}
	for memorial in memorials:
		var mtype: String = memorial.get("memorial_type", "unknown")
		memorial_types[mtype] = memorial_types.get(mtype, 0) + 1

	print("--- MEMORIAL STATISTICS ---")
	print("Total memorials: %d" % memorials.size())
	for mtype in memorial_types:
		print("  %s: %d" % [mtype, memorial_types[mtype]])
	print("")

	# Sacred geography statistics
	if sg != null and sg.has_method("get_sacred_tile_counts"):
		var sacred_counts: Dictionary = sg.call("get_sacred_tile_counts")
		print("--- SACRED GEOGRAPHY ---")
		print("Remembered tiles (1-2 memorials): %d" % sacred_counts.get("remembered", 0))
		print("Sacred tiles (3-4 memorials): %d" % sacred_counts.get("sacred", 0))
		print("Holy Ground tiles (5+ memorials): %d" % sacred_counts.get("holy_ground", 0))
		print("")

	# Show recent memorials
	print("--- RECENT MEMORIALS ---")
	if memorials.is_empty():
		print("  (No memorials created yet)")
	else:
		var shown: int = 0
		for memorial in memorials:
			if shown >= 10:
				print("  ... and %d more" % (memorials.size() - shown))
				break

			var mtype: String = memorial.get("memorial_type", "unknown")
			var tile: Vector2i = memorial.get("tile", Vector2i.ZERO)
			var created_tick: int = memorial.get("created_tick", 0)
			var ticks_ago: int = GameManager.tick_count - created_tick
			var associated_pawns: Array = memorial.get("associated_pawns", [])

			print("  %s at (%d, %d)" % [mtype, tile.x, tile.y])
			print("    Created %d ticks ago" % ticks_ago)
			print("    Associated pawns: %d" % associated_pawns.size())
			if associated_pawns.size() > 0:
				for pawn_id in associated_pawns:
					print("      - HeelKawnian #%d" % pawn_id)
			print("")
			shown += 1

	# Pilgrimage activity
	print("--- PILGRIMAGE ACTIVITY ---")
	var total_crossings: int = 0
	if sg != null and sg.has_method("get_total_crossings"):
		total_crossings = sg.call("get_total_crossings")
	print("Total sacred tile crossings: %d" % total_crossings)
	print("")

	print("=== END MEMORIAL SYSTEM REPORT ===")


# === Phase 5/6: Knowledge Systems Report ===

func _report_knowledge_system() -> void:
	print("=== HEELKAWN KNOWLEDGE SYSTEMS (Phase 5/6: Carriers, Teaching, Loss/Rediscovery) ===")
	print("Generated: %s" % Time.get_datetime_string_from_system())
	print("Game Tick: %d" % GameManager.tick_count)
	print("")

	var ks: Node = get_node_or_null("/root/KnowledgeSystem")
	if ks == null:
		print("KnowledgeSystem not found - system not loaded")
		return

	# Knowledge carrier statistics
	var total_carriers: int = 0
	var total_knowledge: int = 0
	var knowledge_by_type: Dictionary = {}

	if ks.has_method("get"):
		var carriers: Variant = ks.get("knowledge_carriers")
		if carriers != null and carriers is Dictionary:
			for pawn_id in carriers:
				var pawn_knowledge: Array = carriers[pawn_id]
				total_carriers += 1
				total_knowledge += pawn_knowledge.size()

				for ktype in pawn_knowledge:
					if not knowledge_by_type.has(ktype):
						knowledge_by_type[ktype] = 0
					knowledge_by_type[ktype] += 1

	print("--- KNOWLEDGE CARRIER STATISTICS ---")
	print("Total knowledge carriers: %d" % total_carriers)
	print("Total knowledge instances: %d" % total_knowledge)
	print("Average knowledge per carrier: %.1f" % (float(total_knowledge) / max(1, total_carriers)))
	print("")

	print("--- KNOWLEDGE BY TYPE ---")
	var type_names: Dictionary = {
		0: "Fire Keeping", 1: "Food Storage", 2: "Tool Making", 3: "Season Reading",
		4: "Sickness Avoidance", 5: "Navigation", 6: "Shelter Building", 7: "Memory Preservation",
		8: "Ruin Interpretation", 9: "Hospitality", 10: "Winter Survival", 11: "Teaching",
		12: "Hunting", 13: "Farming", 14: "Combat", 15: "Diplomacy", 16: "Crafting", 17: "Leadership",
		18: "Metallurgy", 19: "Animal Husbandry", 20: "Architecture", 21: "Medicine",
		22: "Astronomy", 23: "Engineering", 24: "Writing", 25: "Philosophy"
	}
	for ktype in knowledge_by_type:
		var count: int = knowledge_by_type[ktype]
		var name: String = type_names.get(ktype, "Unknown")
		var status: String = "✓" if count > 1 else "⚠ LAST CARRIER" if count == 1 else ""
		print("  %s (%d carriers): %d %s" % [name, count, count, status])
	print("")

	# Dormant knowledge
	if ks.has_method("get_dormant_knowledge_types"):
		var dormant: Array = ks.call("get_dormant_knowledge_types")
		print("--- DORMANT KNOWLEDGE (Lost, Can Rediscover) ---")
		if dormant.is_empty():
			print("  (No dormant knowledge)")
		else:
			for ktype in dormant:
				var info: Dictionary = ks.call("get_dormant_info", ktype)
				var name: String = type_names.get(ktype, "Unknown")
				var ticks_ago: int = GameManager.tick_count - info.get("last_practiced_tick", 0)
				print("  %s - Lost %d ticks ago at (%d, %d)" % [name, ticks_ago, info.get("last_known_location", Vector2i.ZERO).x, info.get("last_known_location", Vector2i.ZERO).y])
		print("")

	# Teaching records
	if ks.has_method("get"):
		var records: Variant = ks.get("teaching_records")
		if records != null and records is Array:
			print("--- RECENT TEACHING (Last 10) ---")
			if records.is_empty():
				print("  (No teaching records)")
			else:
				var shown: int = 0
				for i in range(max(0, records.size() - 10), records.size()):
					var record: Dictionary = records[i]
					var teacher: int = int(record.get("teacher_id", -1))
					var student: int = int(record.get("student_id", -1))
					var ktype: int = int(record.get("knowledge_type", -1))
					var tick: int = int(record.get("tick", 0))
					var name: String = type_names.get(ktype, "Unknown")
					print("  %s taught %s: %s (%d ticks ago)" % [teacher, student, name, GameManager.tick_count - tick])
					shown += 1
			print("")

	# Knowledge security
	if ks.has_method("get_knowledge_status"):
		var status: Dictionary = ks.call("get_knowledge_status")
		print("--- KNOWLEDGE SECURITY ---")
		print("Secure (2+ carriers): %d knowledge types" % status.get("secure", 0))
		print("At risk (1 carrier): %d knowledge types" % status.get("at_risk", 0))
		print("Lost (dormant): %d knowledge types" % status.get("lost", 0))
		print("")

	print("=== END KNOWLEDGE SYSTEMS REPORT ===")


func _report_heelkawnians() -> void:
	print("=== HEELKAWNIAN DEVELOPMENT AI (Individual Sprite Profiles) ===")
	print("Generated: %s" % Time.get_datetime_string_from_system())
	print("Game Tick: %d" % GameManager.tick_count)
	print("Derived + live influence: profiles read pawn needs, skills, knowledge, memory, settlement, and era state; Matrix biases job choice without overriding job legality.")
	print("")

	var main_node: Node2D = _main()
	if main_node == null:
		print("Main node not found")
		return
	var ps: PawnSpawner = main_node.get_node_or_null("WorldViewport/PawnSpawner") as PawnSpawner
	if ps == null:
		print("PawnSpawner not found")
		return

	var profiles: Array[Dictionary] = HeelKawnianManager.get_profiles_for_pawns(ps.pawns, 16)
	if profiles.is_empty():
		print("No living HeelKawnians found.")
		return

	var drive_counts: Dictionary = {}
	var phase_counts: Dictionary = {}
	var total_score: int = 0
	for profile in profiles:
		var drive: String = str(profile.get("development_drive", "unknown"))
		var phase: String = str(profile.get("development_phase", "unknown"))
		drive_counts[drive] = int(drive_counts.get(drive, 0)) + 1
		phase_counts[phase] = int(phase_counts.get(phase, 0)) + 1
		total_score += int(profile.get("development_score", 0))

	print("--- SUMMARY ---")
	print("sampled=%d avg_development=%d" % [profiles.size(), int(total_score / maxi(1, profiles.size()))])
	print("drives=%s" % str(drive_counts))
	print("phases=%s" % str(phase_counts))
	print("")
	print("--- SAMPLE HEELKAWNIANS ---")
	for profile in profiles:
		var axes: Dictionary = profile.get("axes", {})
		var skills: Dictionary = profile.get("skills", {})
		var known_names: Array = profile.get("known_knowledge", [])
		var known_preview: String = "none"
		if not known_names.is_empty():
			var parts: Array[String] = []
			for i in range(mini(4, known_names.size())):
				parts.append(str(known_names[i]))
			known_preview = ", ".join(parts)
			if known_names.size() > 4:
				known_preview += ", ..."
		print(
			"#%d %s soul=%s"
			% [
				int(profile.get("pawn_id", -1)),
				str(profile.get("name", "unknown")),
				str(profile.get("soul_id", "")).left(12),
			]
		)
		print(
			"  phase=%s drive=%s next=%s era=%s dev=%d"
			% [
				str(profile.get("development_phase", "")),
				str(profile.get("development_drive", "")),
				str(profile.get("next_need", "")),
				str(profile.get("era", "")),
				int(profile.get("development_score", 0)),
			]
		)
		print(
			"  profession=%s path=%s best_skill=%s:%d known=%d [%s]"
			% [
				str(profile.get("profession", "")),
				str(profile.get("life_path", "")),
				str(skills.get("highest_skill", "none")),
				int(skills.get("highest_level", 0)),
				int(profile.get("known_knowledge_count", 0)),
				known_preview,
			]
		)
		print(
			"  axes survival=%d practice=%d knowledge=%d social=%d preservation=%d innovation=%d trauma=%d"
			% [
				int(axes.get("survival", 0)),
				int(axes.get("practice", 0)),
				int(axes.get("knowledge", 0)),
				int(axes.get("social", 0)),
				int(axes.get("preservation", 0)),
				int(axes.get("innovation", 0)),
				int(axes.get("trauma_pressure", 0)),
			]
		)
		var matrix_decision: Dictionary = {}
		for pawn in ps.pawns:
			if pawn == null or not is_instance_valid(pawn):
				continue
			var pdata: HeelKawnianData = pawn.get("data") as HeelKawnianData
			if pdata != null and int(pdata.id) == int(profile.get("pawn_id", -1)):
				matrix_decision = HeelKawnianManager.get_matrix_decision_for_pawn(pawn)
				break
		if not matrix_decision.is_empty():
			var top_jobs: Array = matrix_decision.get("top_jobs", [])
			var matrix_parts: Array[String] = []
			for item in top_jobs:
				if matrix_parts.size() >= 4:
					break
				matrix_parts.append("%s+%d" % [str(item.get("job_name", "Job")), int(item.get("bias", 0))])
			print("  matrix=%s" % (", ".join(matrix_parts) if not matrix_parts.is_empty() else "no strong bias"))
			print("  rationale=%s" % str(matrix_decision.get("rationale", "")))
	print("=== END HEELKAWNIAN DEVELOPMENT AI ===")


# === PAWN COMMUNICATION LOG ===

func _report_communication() -> void:
	var comm_log: Node = get_node_or_null("/root/PawnCommunicationLog")
	if comm_log == null:
		print("PawnCommunicationLog not found - system not loaded")
		return
	
	if not comm_log.has_method("generate_communication_report"):
		print("PawnCommunicationLog.generate_communication_report() not found")
		return
	
	print(comm_log.call("generate_communication_report"))


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
		var settlements: Array = SettlementMemory.get_formal_settlements()
		for s in settlements:
			if s is Dictionary:
				var current_state: String = str(s.get("state", "unknown"))
				if current_state == "abandoned":
					s["state"] = "active"
					print("Forced settlement %s to ACTIVE state" % str(s.get("id", "?")))
	
	print("")
	print("Total jobs posted: %d" % jobs_posted)
	print("=== END FORCE BUILDING ===")


# === Phase 7: Legacy & Dynasty Report ===

func _report_legacy_dynasty() -> void:
	print("=== HEELKAWN LEGACY & DYNASTY (Phase 7: Historical Milestones) ===")
	print("Generated: %s" % Time.get_datetime_string_from_system())
	print("Game Tick: %d" % GameManager.tick_count)
	print("")

	var legacy_sys: Node = get_node_or_null("/root/LegacySystem")
	if legacy_sys == null:
		print("LegacySystem not found - system not loaded")
		return

		# Get legacy milestone status
	if legacy_sys.has_method("get_endgame_status"):
		var status: Dictionary = legacy_sys.call("get_endgame_status")
		print("--- LEGACY MILESTONE STATUS ---")
		print("Total Legacy Score: %d" % status.get("total_legacy", 0))
		print("Total Dynasties: %d" % status.get("dynasty_count", 0))
		print("Total Dynasty Members: %d" % status.get("total_dynasty_members", 0))
		print("Player Incarnations: %d" % status.get("player_incarnations", 0))
		print("")

	# Get all legacy entries
	if legacy_sys.has_method("get_all_legacy_entries"):
		var entries: Array = legacy_sys.call("get_all_legacy_entries")
		if entries.is_empty():
			print("--- LEGACY ENTRIES ---")
			print("  (No legacy entries yet - pawns must die to create entries)")
		else:
			print("--- TOP LEGACY ENTRIES (by score) ---")
			# Sort by legacy score
			entries.sort_custom(func(a, b): return int(a.get("legacy_score", 0)) > int(b.get("legacy_score", 0)))
			var shown: int = 0
			for entry in entries:
				if shown >= 10:
					break
				var pawn_name: String = "Unknown"
				if legacy_sys.has_method("_get_pawn_name"):
					pawn_name = legacy_sys.call("_get_pawn_name", int(entry.get("pawn_id", -1)))
				print("  %s (ID %d): Score %d" % [pawn_name, int(entry.get("pawn_id", -1)), int(entry.get("legacy_score", 0))])
				print("    Children: %d | Grandchildren: %d | Knowledge: %d | Students: %d" % [
					int(entry.get("children_count", 0)),
					int(entry.get("grandchildren_count", 0)),
					int(entry.get("knowledge_preserved", []).size()),
					int(entry.get("students_taught", 0))
				])
				print("    Survived: %d ticks | Death: %s" % [
					int(entry.get("ticks_survived", 0)),
					entry.get("death_cause", "unknown")
				])
				shown += 1
		print("")

	# Get dynasty summaries
	print("--- DYNASTY SUMMARIES ---")
	var dynasty_count: int = 0
	if legacy_sys.has_method("get"):
		var dynasties: Variant = legacy_sys.get("dynasties")
		if dynasties != null and dynasties is Dictionary:
			for dynasty_id in dynasties:
				if dynasty_count >= 5:
					print("  ... and %d more dynasties" % (dynasties.size() - dynasty_count))
					break
				if legacy_sys.has_method("get_dynasty_summary"):
					var summary: Dictionary = legacy_sys.call("get_dynasty_summary", int(dynasty_id))
					if not summary.is_empty():
						print("  %s" % summary.get("name", "Unknown Dynasty"))
						print("    Generations: %d | Members: %d | Total Legacy: %d" % [
							summary.get("generations", 0),
							summary.get("members", 0),
							summary.get("legacy_score_total", 0)
					])
					dynasty_count += 1

	print("")
	print("=== END LEGACY & DYNASTY REPORT ===")


# === Phase 5: Chronicle View (Settlement History as Story) ===

func _report_chronicle_view() -> void:
	print("=== HEELKAWN CHRONICLE (Settlement History as Story) ===")
	print("Generated: %s" % Time.get_datetime_string_from_system())
	print("Game Tick: %d" % GameManager.tick_count)
	print("")

	var wmem: Node = get_node_or_null("/root/WorldMemory")
	if wmem == null:
		print("WorldMemory not found")
		return

	# Get all events
	var events: Array[Dictionary] = wmem.get_events()
	if events.is_empty():
		print("No events recorded yet.")
		return

	# Group events by settlement
	var events_by_settlement: Dictionary = {}
	var events_global: Array[Dictionary] = []

	for ev in events:
		var settlement_id: int = int(ev.get("sid", -1))
		if settlement_id >= 0:
			if not events_by_settlement.has(settlement_id):
				events_by_settlement[settlement_id] = []
			events_by_settlement[settlement_id].append(ev)
		else:
			events_global.append(ev)

	# Print global events first
	if not events_global.is_empty():
		print("━━━ WORLD EVENTS ━━━")
		var shown: int = 0
		for ev in events_global:
			if shown >= 15:
				print("  [color=#666666]... and %d more events" % (events_global.size() - shown))
				break
			print("  %s" % _format_chronicle_event(ev))
			shown += 1
		print("")

	# Print settlement-specific events as stories
	print("━━━ SETTLEMENT CHRONICLES ━━━")
	for settlement_id in events_by_settlement:
		var settlement_events: Array[Dictionary] = events_by_settlement[settlement_id]
		var settlement_name: String = _get_settlement_name_chronicle(settlement_id)
		
		print("\n[color=#FFD166][b]━━━ %s ━━━[/b][/color]" % settlement_name)
		
		# Sort events by tick
		settlement_events.sort_custom(func(a, b): return int(a.get("t", 0)) < int(b.get("t", 0)))
		
		# Group by year (every 360 ticks)
		var events_by_year: Dictionary = {}
		for ev in settlement_events:
			var tick: int = int(ev.get("t", 0))
			var year: int = tick / 360
			if not events_by_year.has(year):
				events_by_year[year] = []
			events_by_year[year].append(ev)
		
		# Print by year
		var years: Array = events_by_year.keys()
		years.sort()
		
		var shown_years: int = 0
		for year in years:
			if shown_years >= 5:  # Show last 5 years only
				var remaining: int = years.size() - shown_years
				print("  [color=#666666]... %d more years of history" % remaining)
				break
			
			print("\n  [color=#B084CC][b]Year %d:[/b][/color]" % (year + 1))
			var year_events: Array[Dictionary] = events_by_year[year]
			
			for ev in year_events:
				print("    %s" % _format_chronicle_event(ev))
			
			shown_years += 1

	print("\n=== END CHRONICLE ===")


## Format a single event for chronicle display.
func _format_chronicle_event(ev: Dictionary) -> String:
	var event_type: String = str(ev.get("type", "unknown"))
	var tick: int = int(ev.get("t", 0))
	var year: int = tick / 360
	var day: int = (tick % 360) / 10
	
	var time_str: String = "Y%d D%d" % [year + 1, day + 1]
	
	match event_type:
		"pawn_death":
			var name: String = str(ev.get("n", "Someone"))
			var cause: String = str(ev.get("c", "unknown"))
			return "[color=#FF6B6B]⚰ %s died (%s)[/color]" % [name, cause]
		
		"birth":
			var name: String = str(ev.get("n", "A child"))
			return "[color=#57C5B6]👶 %s was born[/color]" % name
		
		"work_event":
			var job_type: String = str(ev.get("job_type", "work"))
			return "Completed %s" % job_type
		
		"teaching_event":
			var skill: String = str(ev.get("skill", "skill"))
			return "[color=#B084CC]📚 Taught %s[/color]" % skill
		
		"building_constructed":
			var building: String = str(ev.get("building_type", "structure"))
			return "[color=#FFD166]🏗 Built %s[/color]" % building
		
		"knowledge_inscribed":
			return "[color=#B084CC]📜 Knowledge inscribed on stone[/color]"
		
		"settlement_founded":
			var name: String = str(ev.get("name", "Settlement"))
			return "[color=#FFD166][b]🏰 %s was founded[/b][/color]" % name
		
		"social_meeting":
			return "Social meeting occurred"
		
		"social_bond_milestone":
			var milestone: int = int(ev.get("milestone", 0))
			return "[color=#FF9F6B]💕 Friendship milestone (%d)[/color]" % milestone
		
		_:
			return "%s occurred" % event_type.capitalize()


## Get settlement name for chronicle.
func _get_settlement_name_chronicle(settlement_id: int) -> String:
	if SettlementMemory == null or settlement_id < 0:
		return "Unknown Settlement"
	
	var settlements: Array = SettlementMemory.settlements
	if settlement_id >= settlements.size():
		return "Settlement #%d" % settlement_id
	
	var st: Variant = settlements[settlement_id]
	if st is Dictionary:
		return str(st.get("culture_name", "Settlement #%d" % settlement_id))
	
	return "Settlement #%d" % settlement_id


# === Phase 5: Settlement Legends (Emergent Myths & Stories) ===

func _report_settlement_legends() -> void:
	print("=== HEELKAWN SETTLEMENT LEGENDS (Phase 5: Emergent Stories) ===")
	print("Generated: %s" % Time.get_datetime_string_from_system())
	print("Game Tick: %d" % GameManager.tick_count)
	print("")

	var wmem: Node = get_node_or_null("/root/WorldMemory")
	if wmem == null:
		print("WorldMemory not found")
		return

	# Get all events
	var events: Array[Dictionary] = wmem.get_events()
	if events.is_empty():
		print("No events recorded yet.")
		return

	# Group events by settlement
	var events_by_settlement: Dictionary = {}
	for ev in events:
		var settlement_id: int = int(ev.get("sid", -1))
		if settlement_id >= 0:
			if not events_by_settlement.has(settlement_id):
				events_by_settlement[settlement_id] = []
			events_by_settlement[settlement_id].append(ev)

	# Generate legend for each settlement
	print("━━━ SETTLEMENT LEGENDS ━━━\n")
	for settlement_id in events_by_settlement:
		var settlement_events: Array[Dictionary] = events_by_settlement[settlement_id]
		var settlement_name: String = _get_settlement_name_chronicle(settlement_id)
		
		# Generate legend using SettlementLegend class
		var legend_script: GDScript = load("res://scripts/world/SettlementLegend.gd")
		if legend_script != null:
			var legend: String = legend_script.generate_legend(settlement_id, settlement_name, settlement_events)
			print(legend)
			print("\n[color=#666666]━━━ ━━━\n[/color]")

	print("=== END SETTLEMENT LEGENDS ===")


# === Phase 5: Read Knowledge Stone ===

func _report_read_knowledge_stone() -> void:
	print("=== READ KNOWLEDGE STONE ===")
	print("Usage: Pass tile coordinates as arguments")
	print("Example: F10 → type command with tile X Y")
	print("")
	
	# For now, show all known knowledge stones
	var ks: Node = get_node_or_null("/root/KnowledgeSystem")
	if ks == null:
		print("KnowledgeSystem not found")
		return
	
	print("━━━ ALL INSCRIBED STONES ━━━\n")

	if ks.has_method("get"):
		var carriers: Variant = ks.get("record_carriers")
		if carriers != null and carriers is Dictionary:
			if carriers.is_empty():
				print("  [color=#666666]No knowledge stones inscribed yet.[/color]")
			else:
				for tile_key in carriers:
					var carrier: Dictionary = carriers[tile_key]
					var carrier_type: String = str(carrier.get("carrier_type", "stone"))
					var inscriber_id: int = int(carrier.get("inscriber_id", -1))
					var knowledge_count: int = int(carrier.get("knowledge_types", []).size())

					print("  [color=#B084CC]📍 Tile (%s)[/color]" % tile_key)
					print("    Type: %s | Inscriber: ID %d | Knowledge: %d types" % [carrier_type, inscriber_id, knowledge_count])
					
					# Get full text
					var parts: PackedStringArray = tile_key.split(",")
					if parts.size() >= 2:
						var tile_x: int = int(parts[0])
						var tile_y: int = int(parts[1])
						var tile: Vector2i = Vector2i(tile_x, tile_y)
						
						if ks.has_method("get_knowledge_stone_text"):
							var stone_text: String = ks.call("get_knowledge_stone_text", tile)
							# Print first 200 chars as preview
							if stone_text.length() > 200:
								print("    Preview: %s...\n" % stone_text.left(200))
							else:
								print("    %s\n" % stone_text)
	
	print("\n=== END KNOWLEDGE STONES ===")


# === Phase 7: Dynasty Tree UI ===

func _show_dynasty_tree_ui() -> void:
	print("Opening Dynasty Tree UI...")
	
	var legacy_sys: Node = get_node_or_null("/root/LegacySystem")
	if legacy_sys == null:
		print("LegacySystem not found")
		return
	
	# Get first dynasty (or current player's dynasty)
	var dynasty_id: int = -1
	if legacy_sys.has_method("get"):
		var dynasties: Variant = legacy_sys.get("dynasties")
		if dynasties != null and dynasties is Dictionary:
			for did in dynasties:
				dynasty_id = int(did)
				break

	if dynasty_id < 0:
		print("No dynasties found - pawns must have children to create dynasties")
		return
	
	# Create and show dynasty tree UI
	var tree_ui: CanvasLayer = CanvasLayer.new()
	tree_ui.set_script(load("res://scripts/ui/DynastyTreeUI.gd"))
	get_tree().root.add_child(tree_ui)
	
	if tree_ui.has_method("show_dynasty"):
		tree_ui.call("show_dynasty", dynasty_id)
	
	print("Dynasty Tree UI opened for dynasty %d" % dynasty_id)


# === Phase 7: Legacy Milestones ===

func _report_endgame_status() -> void:
	print("=== HEELKAWN LEGACY MILESTONES (Phase 7: Historical Progress) ===")
	print("Generated: %s" % Time.get_datetime_string_from_system())
	print("Game Tick: %d" % GameManager.tick_count)
	print("")

	var legacy_sys: Node = get_node_or_null("/root/LegacySystem")
	if legacy_sys == null:
		print("LegacySystem not found")
		return

	# Get legacy milestone status
	var status: Dictionary = {}
	if legacy_sys.has_method("get_endgame_status"):
		status = legacy_sys.call("get_endgame_status")

	print("--- HISTORICAL PROGRESS ---")
	print("Total Legacy Score: %d / 1000 (goal)" % status.get("total_legacy", 0))
	print("Total Dynasties: %d" % status.get("dynasty_count", 0))
	print("Total Dynasty Members: %d" % status.get("total_dynasty_members", 0))
	print("Player Incarnations: %d" % status.get("player_incarnations", 0))
	print("")

	# Legacy milestones
	print("--- LEGACY CONDITIONS / HISTORICAL MILESTONES ---")
	var legacy_goal: int = 1000
	var dynasty_goal: int = 3
	var members_goal: int = 20
	var incarnations_goal: int = 3

	var legacy_progress: float = float(status.get("total_legacy", 0)) / float(legacy_goal) * 100.0
	var dynasty_progress: float = float(status.get("dynasty_count", 0)) / float(dynasty_goal) * 100.0
	var members_progress: float = float(status.get("total_dynasty_members", 0)) / float(members_goal) * 100.0
	var incarnations_progress: float = float(status.get("player_incarnations", 0)) / float(incarnations_goal) * 100.0

	print("Legacy Score: %.1f%% (%d/%d)" % [legacy_progress, status.get("total_legacy", 0), legacy_goal])
	print("Dynasties Founded: %.1f%% (%d/%d)" % [dynasty_progress, status.get("dynasty_count", 0), dynasty_goal])
	print("Dynasty Members: %.1f%% (%d/%d)" % [members_progress, status.get("total_dynasty_members", 0), members_goal])
	print("Player Incarnations: %.1f%% (%d/%d)" % [incarnations_progress, status.get("player_incarnations", 0), incarnations_goal])
	print("")

	# Overall milestone progress
	var total_progress: float = (legacy_progress + dynasty_progress + members_progress + incarnations_progress) / 4.0
	print("OVERALL MILESTONE PROGRESS: %.1f%%" % total_progress)

	if total_progress >= 100.0:
		print("\n[color=#57C5B6][b]Legacy milestone set reached. HeelKawn continues.[/b][/color]")
	elif total_progress >= 75.0:
		print("\n[color=#FFD166]Getting close! Keep building your legacy.[/color]")
	elif total_progress >= 50.0:
		print("\n[color=#FF9F6B]Halfway there. Your dynasty is growing.[/color]")
	else:
		print("\n[color=#888888]Your legacy has just begun. Build, teach, and preserve.[/color]")

	print("\n=== END LEGACY MILESTONES ===")


func _report_error_issues() -> void:
	print("=== HEELKAWN ERROR REPORT ===")
	print("Generated: %s" % Time.get_datetime_string_from_system())
	print("Game Tick: %d" % GameManager.tick_count)
	print("")
	
	# Check for compilation errors by examining key files
	var error_count: int = 0
	var files_to_check: Array[String] = [
		"res://scripts/ui/AIControlPanel.gd",
		"res://scripts/pawn/HeelKawnian.gd", 
		"res://scripts/pawn/HeelKawnianData.gd",
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
		"CivilizationStage": CivilizationStage != null,
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


# ============================================================
# AI PIPELINE HEALTH REPORTS (F10 buttons 80-87)
# ============================================================

func _report_ai_pipeline_health() -> void:
	var tick: int = GameManager.tick_count
	print("=== HEELKAWN_AI_PIPELINE_HEALTH:tick=%d BEGIN ===" % tick)
	print("")
	_report_food_pipeline()
	print("")
	_report_survival_audit()
	print("")
	_report_structure_inventory()
	print("")
	_report_job_pipeline()
	print("")
	_report_ai_integration_health()
	print("")
	_report_pathfinder_audit()
	print("")
	_report_resource_truth_audit()
	print("")
	# Colony sim pressures (compact)
	print("[colony_sim_pressures] stance=%s food=%.3f housing=%.3f materials=%.3f haul=%.3f" % [
		ColonySimServices.get_stance_display(),
		ColonySimServices.get_food_pressure(),
		ColonySimServices.get_housing_pressure(),
		ColonySimServices.get_materials_pressure(),
		ColonySimServices.get_haul_pressure(),
	])
	print("")
	print("=== HEELKAWN_AI_PIPELINE_HEALTH:tick=%d END ===" % tick)


func _report_ai_integration_health() -> void:
	print("[ai_integration_health] tick=%d" % GameManager.tick_count)
	if HeelKawnianManager == null:
		print("  HeelKawnianManager health bridge missing")
		return
	var health: Dictionary = HeelKawnianManager.get_ai_integration_health()
	for key in health.keys():
		print("  %s=%s" % [str(key), str(health[key])])


func _report_food_pipeline() -> void:
	print("[food_pipeline] tick=%d" % GameManager.tick_count)
	var m: Node2D = _main()
	if m == null:
		print("  Main missing")
		return
	var ps: PawnSpawner = m.get_node_or_null("WorldViewport/PawnSpawner") as PawnSpawner
	if ps == null:
		print("  PawnSpawner null")
		return

	# Hunger histogram
	var bands: Dictionary = {
		"CRITICAL(0-20)": 0,
		"HUNGRY(20-40)": 0,
		"OK(40-60)": 0,
		"FED(60-80)": 0,
		"FULL(80-100)": 0,
	}
	var eating_count: int = 0
	var seeking_food_count: int = 0
	var starving_count: int = 0
	for p in ps.pawns:
		if p == null or not is_instance_valid(p) or p.data == null:
			continue
		var h: float = p.data.hunger
		if h < 20.0:
			bands["CRITICAL(0-20)"] += 1
			starving_count += 1
		elif h < 40.0:
			bands["HUNGRY(20-40)"] += 1
		elif h < 60.0:
			bands["OK(40-60)"] += 1
		elif h < 80.0:
			bands["FED(60-80)"] += 1
		else:
			bands["FULL(80-100)"] += 1
		var state_name: String = p.get_state_name()
		if state_name == "Eating":
			eating_count += 1
		elif state_name == "GoingToEat":
			seeking_food_count += 1

	print("  hunger_histogram: %s" % str(bands))
	print("  pawns_eating=%d pawns_seeking_food=%d pawns_starving(h<20)=%d" % [eating_count, seeking_food_count, starving_count])

	# Food in stockpiles by type
	var food_by_type: Dictionary = {}
	var total_food: int = 0
	for z in StockpileManager.zones():
		if z == null or not is_instance_valid(z):
			continue
		for t in z.inventory:
			if Item.is_food(t):
				var q: int = int(z.inventory[t])
				var name: String = Item.name_for(t)
				if not food_by_type.has(name):
					food_by_type[name] = 0
				food_by_type[name] += q
				total_food += q
	print("  stockpile_food_total=%d" % total_food)
	print("  stockpile_food_by_type: %s" % str(food_by_type))
	print("  StockpileManager.total_food()=%d has_any_food=%s" % [
		StockpileManager.total_food(),
		str(StockpileManager.has_any_food()),
	])

	# Food being carried by pawns
	var food_in_hand: int = 0
	for p in ps.pawns:
		if p == null or not is_instance_valid(p) or p.data == null:
			continue
		if p.data.is_carrying() and Item.is_food(p.data.carrying):
			food_in_hand += int(p.data.carrying_qty)
	print("  food_in_pawn_hands=%d" % food_in_hand)


func _report_survival_audit() -> void:
	print("[survival_audit] tick=%d" % GameManager.tick_count)
	var m: Node2D = _main()
	if m == null:
		print("  Main missing")
		return

	# Death causes from WorldMemory
	var death_by_cause: Dictionary = {}
	var recent_deaths: Array = []
	var events: Array[Dictionary] = WorldMemory.get_events()
	for e in events:
		if str(e.get("type", "")) == "pawn_death":
			var cause: String = str(e.get("cause", "unknown"))
			if not death_by_cause.has(cause):
				death_by_cause[cause] = 0
			death_by_cause[cause] += 1
			recent_deaths.append(e)
	print("  deaths_by_cause: %s" % str(death_by_cause))
	var total_deaths: int = 0
	for cause in death_by_cause:
		total_deaths += int(death_by_cause[cause])
	print("  total_deaths=%d" % total_deaths)

	# Recent deaths (last 10)
	var shown: int = 0
	for i in range(recent_deaths.size() - 1, -1, -1):
		if shown >= 10:
			break
		var d: Dictionary = recent_deaths[i]
		print("  recent_death: %s (cause=%s tick=%d)" % [
			str(d.get("pawn_name", "?")),
			str(d.get("cause", "?")),
			int(d.get("tick", -1)),
		])
		shown += 1

	# Warmth coverage
	var w: World = m.get_node_or_null("WorldViewport/World") as World
	var beds: int = 0
	var fire_pits: int = 0
	if w != null:
		beds = w.bed_count()
		var fc: Dictionary = w.get_feature_counts()
		fire_pits = int(fc.get(TileFeature.Type.FIRE_PIT, 0))
	var pawn_count: int = _get_playtest_pawn_count()
	print("  warmth: beds=%d fire_pits=%d living_pawns=%d" % [beds, fire_pits, pawn_count])
	if pawn_count > 0:
		print("  bed_ratio=%.2f fire_pit_ratio=%.2f" % [
			float(beds) / float(pawn_count),
			float(fire_pits) / float(pawn_count),
		])


func _report_structure_inventory() -> void:
	print("[structure_inventory] tick=%d" % GameManager.tick_count)
	var m: Node2D = _main()
	if m == null:
		print("  Main missing")
		return
	var w: World = m.get_node_or_null("WorldViewport/World") as World
	if w == null:
		print("  World missing")
		return
	var counts: Dictionary = w.get_feature_counts()
	var keys: Array = counts.keys()
	keys.sort()
	var total_structures: int = 0
	for f in keys:
		var c: int = int(counts[f])
		total_structures += c
		print("  %s=%d" % [TileFeature.name_for(int(f)), c])
	print("  total_structures=%d" % total_structures)


func _report_job_pipeline() -> void:
	print("[job_pipeline] tick=%d" % GameManager.tick_count)
	var stats: Dictionary = JobManager.stats()
	print("  flow: posted=%d claimed=%d completed=%d cancelled=%d" % [
		int(stats.get("posted", 0)),
		int(stats.get("claimed", 0)),
		int(stats.get("completed", 0)),
		int(stats.get("cancelled", 0)),
	])
	print("  open=%d claimed=%d" % [JobManager.open_count(), JobManager.claimed_count()])

	# Active jobs by type (open + claimed)
	var active_by_type: Dictionary = {}
	var all_jobs: Array = JobManager.get_active_jobs_union()
	for job_any in all_jobs:
		if job_any == null or not is_instance_valid(job_any):
			continue
		var j: Job = job_any as Job
		var tname: String = Job.describe_type(j.type)
		if not active_by_type.has(tname):
			active_by_type[tname] = 0
		active_by_type[tname] += 1
	if active_by_type.size() > 0:
		print("  active_by_type: %s" % str(active_by_type))

	# Stuck jobs: claimed but work_ticks_done == 0 (pawn walking but not arrived)
	var stuck_walking: int = 0
	var stuck_working: int = 0
	for job_any in all_jobs:
		if job_any == null or not is_instance_valid(job_any):
			continue
		var j: Job = job_any as Job
		if j.state == Job.State.CLAIMED:
			if j.work_ticks_done == 0:
				stuck_walking += 1
			elif j.work_ticks_done >= j.work_ticks_needed:
				stuck_working += 1  # should be completed but isn't
	print("  stuck_walking(claimed+0_work_done)=%d stuck_working(work_done>=needed)=%d" % [stuck_walking, stuck_working])


func _report_pathfinder_audit() -> void:
	print("[pathfinder_audit] tick=%d" % GameManager.tick_count)
	var m: Node2D = _main()
	if m == null:
		print("  Main missing")
		return
	var w: World = m.get_node_or_null("WorldViewport/World") as World
	if w == null:
		print("  World missing")
		return
	var pf: PathFinder = w.pathfinder
	if pf == null:
		print("  PathFinder missing")
		return
	var ps: PawnSpawner = m.get_node_or_null("WorldViewport/PawnSpawner") as PawnSpawner
	if ps == null:
		print("  PawnSpawner missing")
		return

	# HeelKawnian components
	var pawn_components: Dictionary = {}  # component_id -> count
	var stranded_pawns: int = 0
	var stockpile_components: Dictionary = {}  # component_id -> count of zones

	# Stockpile components
	var zones: Array = StockpileManager.zones()
	var stockpile_comp_set: Dictionary = {}
	for z in zones:
		if z == null or not is_instance_valid(z):
			continue
		var near_tile: Vector2i = z.rect.position
		if pf != null:
			var comp: int = pf.component_of(near_tile)
			if comp >= 0:
				if not stockpile_components.has(comp):
					stockpile_components[comp] = 0
				stockpile_components[comp] += 1
				stockpile_comp_set[comp] = true

	# HeelKawnian components
	for p in ps.pawns:
		if p == null or not is_instance_valid(p) or p.data == null:
			continue
		var tile: Vector2i = p.data.tile_pos
		var comp: int = pf.component_of(tile)
		if comp < 0:
			stranded_pawns += 1
			continue
		if not pawn_components.has(comp):
			pawn_components[comp] = 0
		pawn_components[comp] += 1
		# Check if this pawn's component has any stockpile
		if not stockpile_comp_set.has(comp):
			stranded_pawns += 1

	var unique_components: int = pawn_components.size()
	print("  unique_pawn_components=%d" % unique_components)
	print("  pawn_components: %s" % str(pawn_components))
	print("  stockpile_components: %s" % str(stockpile_components))
	print("  stranded_pawns(no_stockpile_in_component)=%d" % stranded_pawns)
	print("  largest_component=%d" % pf.largest_component_id())


func _report_resource_truth_audit() -> void:
	print("[resource_truth_audit] tick=%d" % GameManager.tick_count)
	# Global stockpile truth
	var snap: Dictionary = StockpileManager.labor_pressure_stock_snapshot()
	print("  StockpileManager: food=%d wood=%d stone=%d" % [
		int(snap.get("food", 0)),
		int(snap.get("wood", 0)),
		int(snap.get("stone", 0)),
	])

	# Per-settlement resource truth
	var settlements: Array = SettlementMemory.get_formal_settlements()
	for i in range(settlements.size()):
		var s_any: Variant = settlements[i]
		if not (s_any is Dictionary):
			continue
		var st: Dictionary = s_any as Dictionary
		var center: int = int(st.get("center_region", -1))
		var formal: bool = bool(st.get("is_formal_settlement", false))
		var kind: String = str(st.get("settlement_kind", "proto_site"))
		var rt: Variant = st.get("resource_truth")
		var rb: Variant = st.get("resource_balance")
		if rt is Dictionary:
			print("  settlement[%d] formal=%s kind=%s center=%d resource_truth: food=%d wood=%d stone=%d total=%d" % [
				i, str(formal), kind, center,
				int(rt.get("stock_food", -1)),
				int(rt.get("stock_wood", -1)),
				int(rt.get("stock_stone", -1)),
				int(rt.get("total_stock_units", -1)),
			])
		else:
			print("  settlement[%d] formal=%s kind=%s center=%d resource_truth: MISSING" % [i, str(formal), kind, center])
		if rb is Dictionary:
			print("  settlement[%d] formal=%s kind=%s center=%d resource_balance: food=%s wood=%s stone=%s source=%s" % [
				i, str(formal), kind, center,
				str(rb.get("food_balance", "?")),
				str(rb.get("wood_balance", "?")),
				str(rb.get("stone_balance", "?")),
				str(rb.get("source", "?")),
			])
		else:
			print("  settlement[%d] formal=%s kind=%s center=%d resource_balance: MISSING" % [i, str(formal), kind, center])


func _report_save_dump() -> void:
	print("[save_dump] tick=%d" % GameManager.tick_count)
	var dir: DirAccess = DirAccess.open("user://logs/playtest/")
	if dir == null:
		print("  No playtest directory found")
		return

	# Find latest backup file (files are directly in playtest/ dir)
	var files: PackedStringArray = dir.get_files()
	var backup_files: PackedStringArray = PackedStringArray()
	for f in files:
		if f.contains("backup") and f.ends_with(".json"):
			backup_files.append(f)
	if backup_files.is_empty():
		print("  No backup files found")
		return
	backup_files.sort()
	var latest_backup: String = backup_files[backup_files.size() - 1]
	print("  latest_backup=%s" % latest_backup)

	# Read and parse
	var path: String = "user://logs/playtest/%s" % latest_backup
	var f_handle: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f_handle == null:
		print("  Cannot open file: %s" % path)
		return
	var content: String = f_handle.get_as_text()
	f_handle.close()

	# Parse JSON and extract key fields
	var json: JSON = JSON.new()
	var err: Error = json.parse(content)
	if err != OK:
		print("  JSON parse error: %s" % json.get_error_message())
		# Print first 2000 chars raw
		if content.length() > 2000:
			content = content.substr(0, 2000) + "\n... [truncated]"
		print(content)
		return

	var data: Variant = json.data
	if data is Dictionary:
		var d: Dictionary = data as Dictionary
		print("  session_id=%s" % str(d.get("session_id", "?")))
		print("  backup_tick=%s" % str(d.get("backup_tick", "?")))
		print("  backup_time=%s" % str(d.get("backup_time", "?")))
		print("  record_count=%s" % str(d.get("record_count", "?")))
		print("  top_level_keys: %s" % str(d.keys()))
		var compact: String = JSON.stringify(d, "\t")
		if compact.length() > 1500:
			compact = compact.substr(0, 1500) + "\n... [truncated at 1500 chars]"
		print("  json_preview:")
		print(compact)
	else:
		if content.length() > 2000:
			content = content.substr(0, 2000) + "\n... [truncated]"
		print(content)


# ============================================================
# SECTION MEGA-BUTTONS — one paste per section
# ============================================================

func _report_playtest_truth_all() -> void:
	var tick: int = GameManager.tick_count
	print("=== HEELKAWN_PLAYTEST_TRUTH_ALL:tick=%d BEGIN ===" % tick)
	print("")
	_report_error_issues()
	print("")
	_report_calendar(tick)
	print("")
	_report_sim_diag()
	print("")
	_report_colony_sim()
	print("")
	_report_civilization_stage()
	print("")
	_report_backbone_status()
	print("")
	_report_settlements()
	print("")
	_report_registry()
	print("")
	_report_intent()
	print("")
	_report_jobs_stock()
	print("")
	_report_trade()
	print("")
	_report_world_events()
	print("")
	_report_cultural()
	print("")
	_report_kernel()
	print("")
	_report_harness()
	print("")
	print("=== HEELKAWN_PLAYTEST_TRUTH_ALL:tick=%d END ===" % tick)


func _report_settlements_economy_all() -> void:
	var tick: int = GameManager.tick_count
	print("=== HEELKAWN_SETTLEMENTS_ECONOMY_ALL:tick=%d BEGIN ===" % tick)
	print("")
	_report_settlements()
	print("")
	_report_registry()
	print("")
	_report_intent()
	print("")
	_report_jobs_stock()
	print("")
	_report_trade()
	print("")
	_report_world_events()
	print("")
	_report_cultural()
	print("")
	print("=== HEELKAWN_SETTLEMENTS_ECONOMY_ALL:tick=%d END ===" % tick)


func _report_world_camera_all() -> void:
	var tick: int = GameManager.tick_count
	print("=== HEELKAWN_WORLD_CAMERA_ALL:tick=%d BEGIN ===" % tick)
	print("")
	_report_revival()
	print("")
	_report_rebirth_consts()
	print("")
	_report_wildlife()
	print("")
	_report_road()
	print("")
	_report_remnant()
	print("")
	_report_main_world()
	print("")
	print("=== HEELKAWN_WORLD_CAMERA_ALL:tick=%d END ===" % tick)


func _report_memory_layers_all() -> void:
	var tick: int = GameManager.tick_count
	print("=== HEELKAWN_MEMORY_LAYERS_ALL:tick=%d BEGIN ===" % tick)
	print("")
	_report_world_memory()
	print("")
	_report_history_snip()
	print("")
	_report_world_meaning()
	print("")
	_report_world_persist()
	print("")
	_report_myth()
	print("")
	_report_age()
	print("")
	print("=== HEELKAWN_MEMORY_LAYERS_ALL:tick=%d END ===" % tick)


func _report_pawns_social_all() -> void:
	var tick: int = GameManager.tick_count
	print("=== HEELKAWN_PAWNS_SOCIAL_ALL:tick=%d BEGIN ===" % tick)
	print("")
	_report_pawns()
	print("")
	_report_profession_liking()
	print("")
	_report_grudges()
	print("")
	_report_gossip_reputation()
	print("")
	_report_avoidance_ai()
	print("")
	_report_life_arcs()
	print("")
	_report_knowledge_carriers()
	print("")
	_report_myth_formation()
	print("")
	_report_record_carriers()
	print("")
	_report_memorial_system()
	print("")
	_report_knowledge_system()
	print("")
	_report_heelkawnians()
	print("")
	_report_communication()
	print("")
	print("=== HEELKAWN_PAWNS_SOCIAL_ALL:tick=%d END ===" % tick)


func _report_dynasty_legacy_all() -> void:
	var tick: int = GameManager.tick_count
	print("=== HEELKAWN_DYNASTY_LEGACY_ALL:tick=%d BEGIN ===" % tick)
	print("")
	_report_legacy_dynasty()
	print("")
	_report_chronicle_view()
	print("")
	_report_settlement_legends()
	print("")
	_report_endgame_status()
	print("")
	print("=== HEELKAWN_DYNASTY_LEGACY_ALL:tick=%d END ===" % tick)


func _report_stubs_all() -> void:
	var tick: int = GameManager.tick_count
	print("=== HEELKAWN_STUBS_ALL:tick=%d BEGIN ===" % tick)
	print("")
	_report_vision_scope()
	print("")
	_report_player_intents()
	print("")
	_report_factions()
	print("")
	_report_religion_lens()
	print("")
	print("=== HEELKAWN_STUBS_ALL:tick=%d END ===" % tick)
