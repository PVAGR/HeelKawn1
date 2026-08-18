class_name CreatorDebugMenu
extends CanvasLayer
## F10 Diagnostics Panel — hidden by default, toggled via F10.
## All report output goes to Godot log (copy/paste for debugging).

var _panel: PanelContainer
var _vbox: VBoxContainer

func _ready() -> void:
	layer = 10
	visible = false

	_panel = PanelContainer.new()
	_panel.name = "Panel"
	_panel.custom_minimum_size = Vector2(420, 0)
	_panel.offset_left = 10
	_panel.offset_top = 10
	_panel.offset_right = 440
	_panel.offset_bottom = -10
	_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_panel)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.06, 0.1, 0.92)
	style.border_color = Color(0.3, 0.35, 0.45, 0.8)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	_panel.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.add_child(margin)

	var scroll := ScrollContainer.new()
	scroll.name = "ScrollContainer"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(scroll)

	_vbox = VBoxContainer.new()
	_vbox.name = "VBoxContainer"
	_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_vbox)

	_build_header()
	_build_buttons()

func toggle_menu() -> void:
	visible = not visible

func _build_header() -> void:
	var title := Label.new()
	title.text = "F10 DIAGNOSTICS"
	title.add_theme_font_size_override("font_size", 16)
	_vbox.add_child(title)

	var sep := HSeparator.new()
	_vbox.add_child(sep)

func _build_buttons() -> void:
	var configs: Array[Dictionary] = [
		{"text": "Full System Report",     "cb": "_print_full_system_report"},
		{"text": "Performance Profile",     "cb": "_print_performance_profile"},
		{"text": "AI & Memory State",       "cb": "_print_ai_memory_state"},
		{"text": "Settlements & Pawns",     "cb": "_print_settlements_pawns"},
		{"text": "World & Economy",         "cb": "_print_world_economy"},
		{"text": "Config & Settings",       "cb": "_print_config_settings"},
	]

	for c in configs:
		var btn := Button.new()
		btn.text = c["text"]
		btn.custom_minimum_size = Vector2(380, 32)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.pressed.connect(Callable(self, c["cb"]))
		_vbox.add_child(btn)

	var sep2 := HSeparator.new()
	_vbox.add_child(sep2)

	var hint := Label.new()
	hint.text = "Reports print to Godot Output log.\nPress F10 to close."
	hint.add_theme_font_size_override("font_size", 11)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_vbox.add_child(hint)

# ============================================================================
# REPORTS — all output goes to Godot log via print()
# ============================================================================

func _print_full_system_report() -> void:
	print("\n" + "=".repeat(80))
	print("  FULL SYSTEM REPORT")
	print("=".repeat(80))

	# --- GameManager ---
	print("\n--- GameManager ---")
	if GameManager != null:
		print("  tick_count    : %d" % GameManager.tick_count)
		print("  game_speed    : %dx" % GameManager.game_speed)
		print("  is_paused     : %s" % str(GameManager.is_paused))
		print("  days_elapsed  : %.1f" % (GameManager.tick_count / 1000.0))
	else:
		print("  NOT LOADED")

	# --- TickManager ---
	print("\n--- TickManager ---")
	if TickManager != null:
		print("  speed_index   : %d" % TickManager.get_speed_index())
		print("  current_tick  : %d" % TickManager.current_tick)
	else:
		print("  NOT LOADED")

	# --- World ---
	print("\n--- World ---")
	var wn := get_node_or_null("/root/World")
	if wn != null:
		if wn.get("data") != null:
			print("  dimensions    : %dx%d" % [wn.data.width, wn.data.height])
			print("  total_tiles   : %d" % (wn.data.width * wn.data.height))
		if wn.has_method("settlement_count"):
			print("  settlements   : %d" % wn.settlement_count())
	else:
		print("  World node not found")

	# --- WorldMemory ---
	print("\n--- WorldMemory ---")
	if WorldMemory != null:
		print("  loaded        : yes")
	else:
		print("  NOT LOADED")

	# --- WorldMeaning ---
	print("\n--- WorldMeaning ---")
	if WorldMeaning != null:
		print("  regions       : %d" % WorldMeaning.region_count())
	else:
		print("  NOT LOADED")

	# --- SettlementMemory ---
	print("\n--- SettlementMemory ---")
	if SettlementMemory != null:
		if SettlementMemory.has_method("get_formal_settlement_count"):
			print("  formal        : %d" % SettlementMemory.get_formal_settlement_count())
		if SettlementMemory.has_method("get_formal_settlements"):
			var sarr: Array = SettlementMemory.get_formal_settlements()
			for s in sarr:
				if s is Dictionary and s.has("name"):
					print("    - %s" % s["name"])
		if SettlementMemory.has_method("get_proto_sites"):
			print("  proto_sites   : %d" % SettlementMemory.get_proto_sites().size())
		if SettlementMemory.has_method("get_active_polity_count"):
			print("  polities      : %d" % SettlementMemory.get_active_polity_count())
	else:
		print("  NOT LOADED")

	# --- MemoryManager ---
	print("\n--- MemoryManager ---")
	if MemoryManager != null:
		if MemoryManager.has_method("site_count"):
			print("  sacred_sites  : %d" % MemoryManager.site_count())
	else:
		print("  NOT LOADED")

	# --- JobManager ---
	print("\n--- JobManager ---")
	if JobManager != null:
		print("  open_jobs     : %d" % JobManager.open_count())
	else:
		print("  NOT LOADED")

	# --- StockpileManager ---
	print("\n--- StockpileManager ---")
	if StockpileManager != null:
		print("  zones         : %d" % StockpileManager.zone_count())
		if StockpileManager.has_method("total_count_of"):
			print("  wood          : %d" % StockpileManager.total_count_of(Item.Type.WOOD))
			print("  stone         : %d" % StockpileManager.total_count_of(Item.Type.STONE))
			print("  food          : %d" % StockpileManager.total_count_of(Item.Type.FOOD))
	else:
		print("  NOT LOADED")

	# --- ColonySimServices ---
	print("\n--- ColonySimServices ---")
	if ColonySimServices != null:
		if ColonySimServices.has_method("get_housing_pressure"):
			print("  housing_press : %.3f" % ColonySimServices.get_housing_pressure())
		if ColonySimServices.has_method("get_food_pressure"):
			print("  food_pressure : %.3f" % ColonySimServices.get_food_pressure())
	else:
		print("  NOT LOADED")

	# --- KinshipSystem ---
	print("\n--- KinshipSystem ---")
	if KinshipSystem != null:
		print("  households    : %d" % KinshipSystem._households.size())
	else:
		print("  NOT LOADED")

	# --- FactionManager ---
	print("\n--- FactionManager ---")
	if FactionManager != null:
		if FactionManager.has_method("get_faction_ids"):
			print("  factions      : %d" % FactionManager.get_faction_ids().size())
	else:
		print("  NOT LOADED")

	# --- AIAgentManager ---
	print("\n--- AIAgentManager ---")
	if AIAgentManager != null:
		if AIAgentManager.has_method("get_agent_count"):
			print("  agents        : %d" % AIAgentManager.get_agent_count())
	else:
		print("  NOT LOADED")

	# --- WorldAI ---
	print("\n--- WorldAI ---")
	if WorldAI != null:
		print("  loaded        : yes")
		if WorldAI.get("neural_world_matrix") != null:
			print("  neural_states : %d" % WorldAI.neural_world_matrix.size())
		if WorldAI.get("emergent_patterns") != null:
			print("  patterns      : %d" % WorldAI.emergent_patterns.size())
	else:
		print("  NOT LOADED")

	# --- EcologySystem ---
	print("\n--- EcologySystem ---")
	if EcologySystem != null:
		print("  loaded        : yes")
	else:
		print("  NOT LOADED")

	# --- DiseaseSystem ---
	print("\n--- DiseaseSystem ---")
	if DiseaseSystem != null:
		print("  loaded        : yes")
	else:
		print("  NOT LOADED")

	# --- CrimeSystem ---
	print("\n--- CrimeSystem ---")
	if CrimeSystem != null:
		print("  loaded        : yes")
	else:
		print("  NOT LOADED")

	# --- DisasterSystem ---
	print("\n--- DisasterSystem ---")
	if DisasterSystem != null:
		print("  loaded        : yes")
	else:
		print("  NOT LOADED")

	# --- EconomyManager ---
	print("\n--- EconomyManager ---")
	if EconomyManager != null:
		print("  loaded        : yes")
	else:
		print("  NOT LOADED")

	# --- Weather ---
	print("\n--- WeatherSystem ---")
	if WorldEnvironmentManager != null:
		print("  loaded        : yes")
	else:
		print("  NOT LOADED")

	print("\n" + "=".repeat(80))
	print("  END FULL SYSTEM REPORT")
	print("=".repeat(80) + "\n")


func _print_performance_profile() -> void:
	print("\n" + "=".repeat(80))
	print("  PERFORMANCE PROFILE")
	print("=".repeat(80))

	# --- TickProfiler ---
	print("\n--- TickProfiler ---")
	if TickProfiler != null:
		print("  heelkawnian_total_us  : %d (%.2f ms)" % [TickProfiler.cat_total_heelkawnian, float(TickProfiler.cat_total_heelkawnian) / 1000.0])
		print("  bookkeeping_us        : %d (%.2f ms)" % [TickProfiler.cat_bookkeeping, float(TickProfiler.cat_bookkeeping) / 1000.0])
		print("  needs_us              : %d (%.2f ms)" % [TickProfiler.cat_needs, float(TickProfiler.cat_needs) / 1000.0])
		print("  survival_health_us    : %d (%.2f ms)" % [TickProfiler.cat_survival_health, float(TickProfiler.cat_survival_health) / 1000.0])
		print("  cognition_us          : %d (%.2f ms)" % [TickProfiler.cat_cognition, float(TickProfiler.cat_cognition) / 1000.0])
		print("  awareness_us          : %d (%.2f ms)" % [TickProfiler.cat_awareness, float(TickProfiler.cat_awareness) / 1000.0])
		print("  matrix_ai_us          : %d (%.2f ms)" % [TickProfiler.cat_matrix_ai, float(TickProfiler.cat_matrix_ai) / 1000.0])
		print("  social_us             : %d (%.2f ms)" % [TickProfiler.cat_social, float(TickProfiler.cat_social) / 1000.0])
		print("  household_us          : %d (%.2f ms)" % [TickProfiler.cat_household, float(TickProfiler.cat_household) / 1000.0])
		print("  settlement_us         : %d (%.2f ms)" % [TickProfiler.cat_settlement, float(TickProfiler.cat_settlement) / 1000.0])
		print("  state_dispatch_us     : %d (%.2f ms)" % [TickProfiler.cat_state_dispatch, float(TickProfiler.cat_state_dispatch) / 1000.0])
		print("  misc_us               : %d (%.2f ms)" % [TickProfiler.cat_misc, float(TickProfiler.cat_misc) / 1000.0])
		print("  ai_total_us           : %d (%.2f ms)" % [TickProfiler.cat_ai_total, float(TickProfiler.cat_ai_total) / 1000.0])
		print("  main_dispatch_us      : %d (%.2f ms)" % [TickProfiler.cat_main_dispatch, float(TickProfiler.cat_main_dispatch) / 1000.0])
	else:
		print("  NOT LOADED")

	# --- Pawn stride sample ---
	print("\n--- Pawn Stride (sample: HeelKawnian_0) ---")
	var sp := get_node_or_null("/root/World/pawns/HeelKawnian_0")
	if sp != null and sp.has_method("_speed_bucket"):
		print("  speed_bucket           : %d" % sp._speed_bucket())
		print("  fast_forward_stride    : %d" % sp._fast_forward_tick_stride())
		print("  job_claim_interval     : %d" % sp._job_claim_interval_for_speed())
		print("  idle_action_refresh    : %d" % sp._idle_action_refresh_interval_for_speed())
		print("  work_step_interval     : %d" % sp._work_step_interval_for_speed())
	else:
		print("  No sample pawn found")

	# --- TickManager ---
	print("\n--- TickManager ---")
	if TickManager != null:
		print("  speed_index   : %d" % TickManager.get_speed_index())
		print("  current_tick  : %d" % TickManager.current_tick)
		print("  last_tick_us  : %d" % TickManager._last_tick_usec)
	else:
		print("  NOT LOADED")

	# --- AIAgentManager intervals ---
	print("\n--- AIAgentManager ---")
	if AIAgentManager != null:
		if AIAgentManager.has_method("_world_ai_interval_for_speed"):
			print("  world_ai_interval    : %d" % AIAgentManager._world_ai_interval_for_speed())
		if AIAgentManager.has_method("_settlement_ai_interval_for_speed"):
			print("  settlement_ai_int    : %d" % AIAgentManager._settlement_ai_interval_for_speed())
	else:
		print("  NOT LOADED")

	# --- TickRateDecoupler ---
	print("\n--- TickRateDecoupler ---")
	if TickRateDecoupler != null:
		print("  systems_registered   : %d" % TickRateDecoupler.system_intervals.size())
		for sys_name in TickRateDecoupler.system_intervals:
			print("    %s : interval=%d" % [sys_name, TickRateDecoupler.system_intervals[sys_name]])
	else:
		print("  NOT LOADED")

	# --- Pawn counts ---
	print("\n--- Pawn Counts ---")
	var pn := get_node_or_null("/root/World/pawns")
	if pn != null:
		print("  total_in_scene : %d" % pn.get_child_count())
	else:
		print("  pawns node not found")

	print("\n" + "=".repeat(80))
	print("  END PERFORMANCE PROFILE")
	print("=".repeat(80) + "\n")


func _print_ai_memory_state() -> void:
	print("\n" + "=".repeat(80))
	print("  AI & MEMORY STATE")
	print("=".repeat(80))

	# --- WorldAI ---
	print("\n--- WorldAI ---")
	if WorldAI != null:
		if WorldAI.get("neural_world_matrix") != null:
			print("  neural_states     : %d" % WorldAI.neural_world_matrix.size())
			# Show first few keys as sample
			var keys: Array = WorldAI.neural_world_matrix.keys()
			var show: int = mini(keys.size(), 5)
			if show > 0:
				print("  sample_keys       : %s" % str(keys.slice(0, show)))
		if WorldAI.get("emergent_patterns") != null:
			print("  patterns          : %d" % WorldAI.emergent_patterns.size())
			for p in WorldAI.emergent_patterns:
				if p is Dictionary:
					print("    - %s (conf=%.2f)" % [p.get("type", "?"), p.get("confidence", 0.0)])
		if WorldAI.get("civilization_neural_network") != null:
			print("  civ_neural        : %d" % WorldAI.civilization_neural_network.size())
		if WorldAI.get("environmental_neural_network") != null:
			print("  env_neural        : %d" % WorldAI.environmental_neural_network.size())
		if WorldAI.get("cultural_neural_network") != null:
			print("  cultural_neural   : %d" % WorldAI.cultural_neural_network.size())
		if WorldAI.get("economic_neural_network") != null:
			print("  economic_neural   : %d" % WorldAI.economic_neural_network.size())
	else:
		print("  NOT LOADED")

	# --- AIAgentManager ---
	print("\n--- AIAgentManager ---")
	if AIAgentManager != null:
		if AIAgentManager.has_method("get_agent_count"):
			print("  agents            : %d" % AIAgentManager.get_agent_count())
		var ci = AIAgentManager.get("collective_intelligence")
		if ci is Dictionary:
			if ci.has("shared_memory") and ci["shared_memory"] is Dictionary:
				var sm: Dictionary = ci["shared_memory"]
				if sm.has("training_history") and sm["training_history"] is Array:
					print("  training_history  : %d records" % sm["training_history"].size())
	else:
		print("  NOT LOADED")

	# --- CharacterBrainSystem ---
	print("\n--- CharacterBrainSystem ---")
	if CharacterBrainSystem != null:
		print("  loaded            : yes")
	else:
		print("  NOT LOADED")

	# --- PawnAccess ---
	print("\n--- PawnAccess ---")
	if PawnAccess != null:
		print("  loaded            : yes")
		if PawnAccess.has_method("find_alive_pawns"):
			var alive: Array = PawnAccess.find_alive_pawns()
			print("  alive_pawns       : %d" % alive.size())
	else:
		print("  NOT LOADED")

	# --- WorldMemory ---
	print("\n--- WorldMemory ---")
	if WorldMemory != null:
		print("  loaded            : yes")
	else:
		print("  NOT LOADED")

	# --- WorldMeaning ---
	print("\n--- WorldMeaning ---")
	if WorldMeaning != null:
		print("  regions           : %d" % WorldMeaning.region_count())
	else:
		print("  NOT LOADED")

	# --- SettlementMemory ---
	print("\n--- SettlementMemory ---")
	if SettlementMemory != null:
		if SettlementMemory.has_method("get_formal_settlement_count"):
			print("  formal            : %d" % SettlementMemory.get_formal_settlement_count())
		if SettlementMemory.has_method("get_active_polity_count"):
			print("  polities          : %d" % SettlementMemory.get_active_polity_count())
	else:
		print("  NOT LOADED")

	# --- HeelKawnianManager ---
	print("\n--- HeelKawnianManager ---")
	if HeelKawnianManager != null:
		print("  loaded            : yes")
	else:
		print("  NOT LOADED")

	print("\n" + "=".repeat(80))
	print("  END AI & MEMORY STATE")
	print("=".repeat(80) + "\n")


func _print_settlements_pawns() -> void:
	print("\n" + "=".repeat(80))
	print("  SETTLEMENTS & PAWNS")
	print("=".repeat(80))

	# --- Settlements ---
	print("\n--- Settlements ---")
	if SettlementMemory != null:
		if SettlementMemory.has_method("get_formal_settlements"):
			var sarr: Array = SettlementMemory.get_formal_settlements()
			print("  formal_count : %d" % sarr.size())
			for s in sarr:
				if s is Dictionary:
					var sname: String = s.get("name", "?")
					var pop: int = s.get("population", 0)
					print("    - %s (pop=%d)" % [sname, pop])
		if SettlementMemory.has_method("get_proto_sites"):
			var proto: Array = SettlementMemory.get_proto_sites()
			print("  proto_count  : %d" % proto.size())
			for p in proto:
				if p is Dictionary:
					print("    - %s" % p.get("name", "?"))
	else:
		print("  SettlementMemory NOT LOADED")

	# --- Pawns ---
	print("\n--- Pawns ---")
	var pn := get_node_or_null("/root/World/pawns")
	if pn != null:
		var total := 0
		var idle := 0
		var walking := 0
		var working := 0
		var sleeping := 0
		var eating := 0
		for child in pn.get_children():
			if child.has("data") and child.data != null:
				total += 1
				if child.has("_state"):
					match child._state:
						0: idle += 1
						1: walking += 1
						2: working += 1
						3: sleeping += 1
						4: eating += 1
		print("  total        : %d" % total)
		print("  idle         : %d" % idle)
		print("  walking      : %d" % walking)
		print("  working      : %d" % working)
		print("  sleeping     : %d" % sleeping)
		print("  eating       : %d" % eating)
	else:
		print("  pawns node not found")

	# --- Jobs ---
	print("\n--- Jobs ---")
	if JobManager != null:
		print("  open          : %d" % JobManager.open_count())
	else:
		print("  NOT LOADED")

	# --- Households ---
	print("\n--- Households ---")
	if KinshipSystem != null:
		print("  count         : %d" % KinshipSystem._households.size())
	else:
		print("  NOT LOADED")

	# --- Factions ---
	print("\n--- Factions ---")
	if FactionManager != null:
		if FactionManager.has_method("get_faction_ids"):
			var fids: Array = FactionManager.get_faction_ids()
			print("  count         : %d" % fids.size())
			for fid in fids:
				if FactionManager.has_method("get_faction"):
					var fdata: Dictionary = FactionManager.get_faction(fid)
					print("    - id=%d name=%s" % [fid, fdata.get("name", "?")])
	else:
		print("  NOT LOADED")

	# --- MarriageSystem ---
	print("\n--- MarriageSystem ---")
	if MarriageSystem != null:
		print("  loaded        : yes")
	else:
		print("  NOT LOADED")

	# --- PrisonerManager ---
	print("\n--- PrisonerManager ---")
	if PrisonerManager != null:
		print("  loaded        : yes")
	else:
		print("  NOT LOADED")

	print("\n" + "=".repeat(80))
	print("  END SETTLEMENTS & PAWNS")
	print("=".repeat(80) + "\n")


func _print_world_economy() -> void:
	print("\n" + "=".repeat(80))
	print("  WORLD & ECONOMY")
	print("=".repeat(80))

	# --- World ---
	print("\n--- World ---")
	var wn := get_node_or_null("/root/World")
	if wn != null:
		if wn.get("data") != null:
			print("  dimensions    : %dx%d" % [wn.data.width, wn.data.height])
			print("  total_tiles   : %d" % (wn.data.width * wn.data.height))
	else:
		print("  NOT FOUND")

	# --- StockpileManager ---
	print("\n--- StockpileManager ---")
	if StockpileManager != null:
		print("  zones         : %d" % StockpileManager.zone_count())
		if StockpileManager.has_method("total_count_of"):
			print("  wood          : %d" % StockpileManager.total_count_of(Item.Type.WOOD))
			print("  stone         : %d" % StockpileManager.total_count_of(Item.Type.STONE))
			print("  food          : %d" % StockpileManager.total_count_of(Item.Type.FOOD))
			print("  berry         : %d" % StockpileManager.total_count_of(Item.Type.BERRY))
			print("  meat          : %d" % StockpileManager.total_count_of(Item.Type.MEAT))
			print("  flint         : %d" % StockpileManager.total_count_of(Item.Type.FLINT))
			print("  stick         : %d" % StockpileManager.total_count_of(Item.Type.STICK))
			print("  leather       : %d" % StockpileManager.total_count_of(Item.Type.LEATHER))
			print("  paper         : %d" % StockpileManager.total_count_of(Item.Type.PAPER))
			print("  book          : %d" % StockpileManager.total_count_of(Item.Type.BOOK))
	else:
		print("  NOT LOADED")

	# --- ColonySimServices ---
	print("\n--- ColonySimServices ---")
	if ColonySimServices != null:
		if ColonySimServices.has_method("get_housing_pressure"):
			print("  housing_pressure : %.3f" % ColonySimServices.get_housing_pressure())
		if ColonySimServices.has_method("get_food_pressure"):
			print("  food_pressure    : %.3f" % ColonySimServices.get_food_pressure())
	else:
		print("  NOT LOADED")

	# --- EconomyManager ---
	print("\n--- EconomyManager ---")
	if EconomyManager != null:
		print("  loaded        : yes")
	else:
		print("  NOT LOADED")

	# --- SupplyChainSystem ---
	print("\n--- SupplyChainSystem ---")
	if SupplyChainSystem != null:
		print("  loaded        : yes")
	else:
		print("  NOT LOADED")

	# --- TradeMemory ---
	print("\n--- TradeMemory ---")
	if TradeMemory != null:
		print("  loaded        : yes")
	else:
		print("  NOT LOADED")

	# --- FarmingSystem ---
	print("\n--- FarmingSystem ---")
	if FarmingSystem != null:
		print("  loaded        : yes")
	else:
		print("  NOT LOADED")

	# --- CraftingSystem ---
	print("\n--- CraftingSystem ---")
	if CraftingSystem != null:
		print("  loaded        : yes")
	else:
		print("  NOT LOADED")

	# --- EcologySystem ---
	print("\n--- EcologySystem ---")
	if EcologySystem != null:
		print("  loaded        : yes")
	else:
		print("  NOT LOADED")

	# --- BuildingRegistry ---
	print("\n--- BuildingRegistry ---")
	if BuildingRegistry != null:
		print("  loaded        : yes")
	else:
		print("  NOT LOADED")

	print("\n" + "=".repeat(80))
	print("  END WORLD & ECONOMY")
	print("=".repeat(80) + "\n")


func _print_config_settings() -> void:
	print("\n" + "=".repeat(80))
	print("  CONFIG & SETTINGS")
	print("=".repeat(80))

	# --- GameManager ---
	print("\n--- GameManager ---")
	if GameManager != null:
		print("  speed         : %dx" % GameManager.game_speed)
		print("  tick_count    : %d" % GameManager.tick_count)
		print("  days_elapsed  : %.1f" % (GameManager.tick_count / 1000.0))
		print("  is_paused     : %s" % str(GameManager.is_paused))
		print("  worker_mode   : %s" % str(GameManager.get("simulation_worker_mode")))
		print("  lightweight   : %s" % str(GameManager.get("lightweight_mode")))
	else:
		print("  NOT LOADED")

	# --- TickManager ---
	print("\n--- TickManager ---")
	if TickManager != null:
		print("  speed_index   : %d" % TickManager.get_speed_index())
		print("  speed_label   : %s" % TickManager.get_speed_label())
		print("  current_tick  : %d" % TickManager.current_tick)
	else:
		print("  NOT LOADED")

	# --- GameSettings ---
	print("\n--- GameSettings ---")
	if GameSettings != null:
		print("  loaded        : yes")
	else:
		print("  NOT LOADED")

	# --- TickBudgetManager ---
	print("\n--- TickBudgetManager ---")
	if TickBudgetManager != null:
		print("  loaded        : yes (disabled stub)")
	else:
		print("  NOT LOADED")

	# --- Platform ---
	print("\n--- Platform ---")
	print("  os            : %s" % OS.get_name())
	print("  debug_build   : %s" % str(OS.is_debug_build()))
	print("  fps           : %d" % Engine.get_frames_per_second())
	print("  physics_fps   : %d" % Engine.physics_ticks_per_second)

	# --- Autoload count ---
	print("\n--- Autoloads ---")
	var autoload_count := 0
	var root := get_node_or_null("/root")
	if root != null:
		for child in root.get_children():
			autoload_count += 1
	print("  total         : %d" % autoload_count)

	print("\n" + "=".repeat(80))
	print("  END CONFIG & SETTINGS")
	print("=".repeat(80) + "\n")
