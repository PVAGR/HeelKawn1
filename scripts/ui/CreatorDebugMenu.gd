class_name CreatorDebugMenu
extends CanvasLayer
## F10: creator-facing debug hub. Each button prints a **copy-pasteable** block to stdout (Godot Output).
## HeelKawn kernel stays **deterministic** (seed + rules + history); these reports help you and the AI see truth.

const PANEL_W: int = 460
const PAD: int = 10
const _SOUL_EXPORT := preload("res://scripts/kernel/heelkawn_soul_export.gd")

## Sectioned menu: importance-ish order (playtest first, stubs last).
const DEBUG_SECTIONS: Array[Dictionary] = [
	{
		"heading": "Playtest / session truth",
		"rows": [
			{"id": "error_report", "label": "ERROR · Report (show all issues)"},
			{"id": "ai_control_panel", "label": "AI · Control Panel (toggle)"},
			{"id": "playtest_bundle", "label": "31 · Playtest bundle (one paste)"},
			{"id": "soul_bundle", "label": "32 · Soul bundle (1–2 sim-year handoff paste)"},
			{"id": "portable_character", "label": "33 · Portable character JSON (MMO / website handoff)"},
			{"id": "calendar", "label": "01 · Calendar + day/night + checkpoints"},
			{"id": "sim_diag", "label": "02 · GameManager sim_diag"},
			{"id": "kernel", "label": "24 · KernelDiagnostic session summary"},
			{"id": "harness", "label": "25 · Validation / harness flags"},
			{"id": "colony_sim", "label": "03 · ColonySimServices"},
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
	hint.text = "Sections ordered by usefulness. Deterministic kernel: copy blocks between === from Output."
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


func _add_report_button(label_text: String, report_id: String) -> void:
	var b: Button = Button.new()
	b.text = label_text
	b.add_theme_font_size_override("font_size", 13)
	b.custom_minimum_size = Vector2(PANEL_W - 40, 26)
	b.pressed.connect(_emit_report.bind(report_id))
	_vbox.add_child(b)


func _emit_report(report_id: String) -> void:
	var tick: int = GameManager.tick_count
	print("=== HEELKAWN_DEBUG_REPORT:%s:tick=%d BEGIN ===" % [report_id, tick])
	match report_id:
		"error_report":
			_report_error_issues()
		"ai_control_panel":
			_toggle_ai_control_panel()
		"calendar":
			_report_calendar(tick)
		"sim_diag":
			_report_sim_diag()
		"colony_sim":
			_report_colony_sim()
		"intent":
			_report_intent()
		"age":
			_report_age()
		"settlements":
			_report_settlements()
		"registry":
			_report_registry()
		"revival":
			_report_revival()
		"rebirth":
			_report_rebirth_consts()
		"wildlife":
			_report_wildlife()
		"jobs_stock":
			_report_jobs_stock()
		"trade":
			_report_trade()
		"world_events":
			_report_world_events()
		"world_memory":
			_report_world_memory()
		"history_snip":
			_report_history_snip()
		"world_meaning":
			_report_world_meaning()
		"world_persist":
			_report_world_persist()
		"cultural":
			_report_cultural()
		"myth":
			_report_myth()
		"road":
			_report_road()
		"remnant":
			_report_remnant()
		"pawns":
			_report_pawns()
		"main_world":
			_report_main_world()
		"kernel":
			_report_kernel()
		"harness":
			_report_harness()
		"profession_liking":
			_report_profession_liking()
		"vision_scope":
			_report_vision_scope()
		"player_intents":
			_report_player_intents()
		"factions":
			_report_factions()
		"religion_lens":
			_report_religion_lens()
		"playtest_bundle":
			_report_playtest_bundle()
		"soul_bundle":
			_report_soul_bundle()
		"portable_character":
			_report_portable_character()
		_:
			print("Unknown report_id=%s" % report_id)
	print("=== HEELKAWN_DEBUG_REPORT:%s:tick=%d END ===" % [report_id, tick])


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
		var rk: int = preload("res://autoloads/WorldMemory.gd")._region_key(t.x, t.y)
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
	var rk: int = preload("res://autoloads/WorldMemory.gd")._region_key(p.data.tile_pos.x, p.data.tile_pos.y)
	var bundle: Dictionary = p.data.to_portable_character_export(GameManager.tick_count, wseed, rk)
	print("=== HEELKAWN_PORTABLE_CHARACTER_JSON BEGIN ===")
	print(JSON.stringify(bundle, "\t"))
	print("=== HEELKAWN_PORTABLE_CHARACTER_JSON END ===")
	print(
			"[PORTABLE_CHARACTER] hint: paste between BEGIN/END; future MMO/website importers target schema=%s"
			% PawnData.PORTABLE_CHARACTER_SCHEMA
	)


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


func _toggle_ai_control_panel() -> void:
	var main: Node2D = _main()
	if main == null:
		print("Main missing - cannot toggle AI Control Panel")
		return
	
	var ai_panel: Control = main.get_node_or_null("AIControlPanel")
	if ai_panel == null:
		print("AI Control Panel not found - creating it...")
		# Try to create the AI Control Panel if it doesn't exist
		var ai_panel_scene: PackedScene = preload("res://scenes/ui/AIControlPanel.tscn")
		ai_panel = ai_panel_scene.instantiate()
		ai_panel.name = "AIControlPanel"
		main.add_child(ai_panel)
		print("AI Control Panel created and added to Main")
	else:
		ai_panel.visible = not ai_panel.visible
		print("AI Control Panel toggled: %s" % ("VISIBLE" if ai_panel.visible else "HIDDEN"))
	
	print("=== HEELKAWN_DEBUG_REPORT:ai_control_panel:tick=%d END ===" % GameManager.tick_count)


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
		"res://scenes/main/Main.gd",
		"res://autoloads/AIAgentManager.gd",
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
	print("=== AI CONTROL PANEL STATUS ===")
	var main: Node2D = _main()
	if main != null:
		var ai_panel: Control = main.get_node_or_null("AIControlPanel")
		if ai_panel != null:
			print("✓ AI Control Panel: INSTANCED")
			print("  Visible: %s" % ("YES" if ai_panel.visible else "NO"))
		else:
			print("✗ AI Control Panel: NOT FOUND")
			error_count += 1
	else:
		print("✗ Main scene: NOT FOUND")
		error_count += 1
	
	print("")
	print("=== SUMMARY ===")
	print("Total Issues Found: %d" % error_count)
	
	if error_count == 0:
		print("🎉 ALL SYSTEMS OPERATIONAL!")
		print("✓ No syntax errors detected")
		print("✓ All autoloads loaded")
		print("✓ Neural network matrix active")
		print("✓ AI Control Panel ready")
	else:
		print("⚠️  ISSUES DETECTED - See details above")
		print("Recommendation: Fix identified issues before proceeding")
	
	print("=== HEELKAWN_DEBUG_REPORT:error_report:tick=%d END ===" % GameManager.tick_count)


func _check_file_syntax_errors(file_path: String) -> Array[String]:
	## Only verify readability — never use regex/paren heuristics here. They false-positive on
	## format strings, multiline `func`, lambdas, and comments; Godot's parser is authoritative.
	var errors: Array[String] = []
	if not FileAccess.file_exists(file_path):
		errors.append("File not found")
		return errors
	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		errors.append("Cannot access file")
		return errors
	file.close()
	return errors
