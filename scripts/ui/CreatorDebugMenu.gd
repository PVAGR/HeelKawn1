extends Control
## Creator Debug Menu - F10 debug report buttons
## Consolidated from 40+ buttons into 6 comprehensive report buttons

@onready var _panel: Panel = $Panel
@onready var _vbox: VBoxContainer = $Panel/VBoxContainer

func _ready() -> void:
	_setup_buttons()

func _setup_buttons() -> void:
	# Clear existing buttons
	for child in _vbox.get_children():
		child.queue_free()
	
	var button_configs := [
		{
			"text": "📊 FULL SYSTEM REPORT",
			"tooltip": "Complete system status - all managers, memory, world state",
			"callback": Callable(self, "_print_full_system_report")
		},
		{
			"text": "⚡ PERFORMANCE PROFILE",
			"tooltip": "Tick profiler, pawn costs, hot paths, stride stats",
			"callback": Callable(self, "_print_performance_profile")
		},
		{
			"text": "🧠 AI & MEMORY STATE",
			"tooltip": "Neural networks, memory systems, world AI, settlement AI",
			"callback": Callable(self, "_print_ai_memory_state")
		},
		{
			"text": "🏘️ SETTLEMENTS & PAWNS",
			"tooltip": "All settlements, pawns, jobs, households, factions",
			"callback": Callable(self, "_print_settlements_pawns")
		},
		{
			"text": "🌍 WORLD & ECONOMY",
			"tooltip": "World state, economy, stockpiles, zones, pathfinding",
			"callback": Callable(self, "_print_world_economy")
		},
		{
			"text": "⚙️ CONFIG & SETTINGS",
			"tooltip": "Game config, speed settings, intervals, budgets",
			"callback": Callable(self, "_print_config_settings")
		}
	]
	
	for config in button_configs:
		var btn := Button.new()
		btn.text = config["text"]
		btn.tooltip_text = config["tooltip"]
		btn.custom_minimum_size = Vector2(400, 36)
		btn.connect("pressed", config["callback"])
		_vbox.add_child(btn)

# ============================================================================
# REPORT FUNCTIONS - Each prints comprehensive data to Godot game log
# ============================================================================

func _print_full_system_report() -> void:
	print("\n" + "=" .repeat(80))
	print("📊 FULL SYSTEM REPORT")
	print("=" .repeat(80))
	
	# GameManager
	if GameManager != null:
		print("[GameManager]")
		print("  Tick Count: %d" % GameManager.tick_count)
		print("  Game Speed: %dx" % GameManager.game_speed)
		print("  Is Paused: %s" % str(GameManager.is_paused))
	
	# World
	if get_node_or_null("/root/World") != null:
		var world = get_node("/root/World")
		print("\n[World]")
		print("  Size: %dx%d" % [world.data.width, world.data.height])
		print("  Settlements: %d" % world.settlement_count())
	
	# Memory Systems
	if WorldMemory != null:
		print("\n[WorldMemory]")
		print("  Regions: %d" % WorldMemory.region_count())
		print("  Tags: %d" % WorldMemory.tag_count())
	
	if SettlementMemory != null:
		print("\n[SettlementMemory]")
		print("  Settlements Tracked: %d" % SettlementMemory.settlement_count())
	
	if MemoryManager != null:
		print("\n[MemoryManager]")
		print("  Events: %d" % MemoryManager.event_count())
		print("  Histories: %d" % MemoryManager.history_count())
	
	# Managers
	print("\n[Managers Status]")
	print("  JobManager: open=%d, total=%d" % [JobManager.open_count(), JobManager.total_count()] if JobManager != null else "  JobManager: null")
	print("  StockpileManager: zones=%d" % StockpileManager.zone_count() if StockpileManager != null else "  StockpileManager: null")
	print("  ColonySimServices: active" if ColonySimServices != null else "  ColonySimServices: null")
	
	print("\n" + "=" .repeat(80))

func _print_performance_profile() -> void:
	print("\n" + "=" .repeat(80))
	print("⚡ PERFORMANCE PROFILE")
	print("=" .repeat(80))
	
	# TickProfiler
	if TickProfiler != null:
		print("[TickProfiler]")
		TickProfiler.print_summary()
	
	# HeelKawnian stride stats
	var sample_pawn := get_node_or_null("/root/World/pawns/HeelKawnian_0")
	if sample_pawn != null and sample_pawn.has_method("_speed_bucket"):
		print("\n[Stride Configuration]")
		print("  Speed Bucket: %d" % sample_pawn._speed_bucket())
		print("  Fast Forward Stride: %d" % sample_pawn._fast_forward_tick_stride())
		print("  Job Claim Interval: %d" % sample_pawn._job_claim_interval_for_speed())
		print("  Idle Action Refresh: %d" % sample_pawn._idle_action_refresh_interval_for_speed())
	
	# TickManager
	if TickManager != null:
		print("\n[TickManager]")
		print("  Speed Index: %d" % TickManager.get_speed_index())
		print("  Max Ticks/Frame: %d" % TickManager.max_ticks_per_frame())
	
	# AIAgentManager intervals
	if AIAgentManager != null:
		print("\n[AIAgentManager Intervals]")
		print("  World AI Interval: %d" % AIAgentManager._world_ai_interval_for_speed())
		print("  Settlement AI Interval: %d" % AIAgentManager._settlement_ai_interval_for_speed())
	
	print("\n" + "=" .repeat(80))

func _print_ai_memory_state() -> void:
	print("\n" + "=" .repeat(80))
	print("🧠 AI & MEMORY STATE")
	print("=" .repeat(80))
	
	# WorldAI
	if WorldAI != null:
		print("[WorldAI]")
		print("  Neural States: %d" % WorldAI.neural_state_count())
		print("  Patterns: %d" % WorldAI.pattern_count())
	
	# AIAgentManager
	if AIAgentManager != null:
		print("\n[AIAgentManager]")
		print("  Agents: %d" % AIAgentManager.agent_count() if AIAgentManager.has_method("agent_count") else "  Agents: N/A")
		print("  Training History Size: %d" % AIAgentManager.training_history.size() if AIAgentManager.has("training_history") else "  Training History: N/A")
	
	# HeelKawnianManager
	if HeelKawnianManager != null:
		print("\n[HeelKawnianManager]")
		print("  Pawns Managed: %d" % HeelKawnianManager.pawn_count() if HeelKawnianManager.has_method("pawn_count") else "  Pawns: N/A")
	
	# Memory Systems
	if WorldMemory != null:
		print("\n[WorldMemory]")
		var sample_region := WorldMemory._region_key(0, 0)
		print("  Sample Region Tags: %s" % str(WorldMemory.get_region_tags(sample_region)))
	
	if SettlementMemory != null:
		print("\n[SettlementMemory]")
		print("  Center Regions: %d" % SettlementMemory.center_region_count() if SettlementMemory.has_method("center_region_count") else "  Center Regions: N/A")
	
	print("\n" + "=" .repeat(80))

func _print_settlements_pawns() -> void:
	print("\n" + "=" .repeat(80))
	print("🏘️ SETTLEMENTS & PAWNS")
	print("=" .repeat(80))
	
	# Settlements
	if SettlementManager != null:
		print("[Settlements]")
		var settlements := SettlementManager.all_settlements() if SettlementManager.has_method("all_settlements") else []
		print("  Count: %d" % settlements.size())
		for s in settlements:
			if s != null and s.has("data"):
				print("    - %s: population=%d, tiles=%d" % [s.data.name, s.data.population, s.data.tiles.size()])
	
	# Pawns
	var pawns_node := get_node_or_null("/root/World/pawns")
	if pawns_node != null:
		print("\n[Pawns]")
		var pawn_count := 0
		var idle_count := 0
		var working_count := 0
		for child in pawns_node.get_children():
			if child.has("data") and child.data != null:
				pawn_count += 1
				if child.has("_state"):
					match child._state:
						0: idle_count += 1  # IDLE
						2: working_count += 1  # WORKING
		print("  Total: %d" % pawn_count)
		print("  Idle: %d" % idle_count)
		print("  Working: %d" % working_count)
	
	# Jobs
	if JobManager != null:
		print("\n[Jobs]")
		print("  Open: %d" % JobManager.open_count())
		print("  Total: %d" % JobManager.total_count())
	
	# Households
	if HouseholdManager != null:
		print("\n[Households]")
		print("  Count: %d" % HouseholdManager.household_count() if HouseholdManager.has_method("household_count") else "  Count: N/A")
	
	# Factions
	if FactionManager != null:
		print("\n[Factions]")
		print("  Count: %d" % FactionManager.faction_count() if FactionManager.has_method("faction_count") else "  Count: N/A")
	
	print("\n" + "=" .repeat(80))

func _print_world_economy() -> void:
	print("\n" + "=" .repeat(80))
	print("🌍 WORLD & ECONOMY")
	print("=" .repeat(80))
	
	# World State
	if get_node_or_null("/root/World") != null:
		var world = get_node("/root/World")
		print("[World]")
		print("  Dimensions: %dx%d" % [world.data.width, world.data.height])
		print("  Total Tiles: %d" % (world.data.width * world.data.height))
	
	# Stockpiles
	if StockpileManager != null:
		print("\n[StockpileManager]")
		print("  Zones: %d" % StockpileManager.zone_count())
		print("  Wood: %d" % StockpileManager.total_count_of(Item.Type.WOOD))
		print("  Stone: %d" % StockpileManager.total_count_of(Item.Type.STONE))
		print("  Food: %d" % StockpileManager.total_count_of(Item.Type.FOOD))
	
	# Economy
	if ColonySimServices != null:
		print("\n[ColonySimServices]")
		print("  Housing Pressure: %.2f" % ColonySimServices.get_housing_pressure())
		print("  Food Security: %.2f" % ColonySimServices.get_food_security())
	
	# Pathfinding
	if get_node_or_null("/root/World/pathfinder") != null:
		var pf = get_node("/root/World/pathfinder")
		print("\n[Pathfinder]")
		print("  Components Computed: %s" % str(pf.has_method("components_computed") and pf.components_computed))
	
	# Zones
	if ZoneRegistry != null:
		print("\n[ZoneRegistry]")
		print("  Zones: %d" % ZoneRegistry.zone_count() if ZoneRegistry.has_method("zone_count") else "  Zones: N/A")
	
	print("\n" + "=" .repeat(80))

func _print_config_settings() -> void:
	print("\n" + "=" .repeat(80))
	print("⚙️ CONFIG & SETTINGS")
	print("=" .repeat(80))
	
	# Game Settings
	if GameManager != null:
		print("[GameManager]")
		print("  Speed: %dx" % GameManager.game_speed)
		print("  Tick Count: %d" % GameManager.tick_count)
		print("  Days Elapsed: %.1f" % (GameManager.tick_count / 1000.0))
	
	# Tick Settings
	if TickManager != null:
		print("\n[TickManager]")
		print("  Speed Index: %d" % TickManager.get_speed_index())
		print("  Max Ticks/Frame: %d" % TickManager.max_ticks_per_frame())
	
	# Performance Settings
	print("\n[Performance Configuration]")
	print("  HeelKawnian Stride (200x): 100 ticks")
	print("  AIAgentManager World AI (200x): 100 ticks")
	print("  AIAgentManager Settlement AI (200x): 160 ticks")
	print("  TickRateDecoupler Multiplier (200x): 20x")
	
	# Budget Settings
	if TickBudgetManager != null:
		print("\n[TickBudgetManager]")
		print("  Enabled: %s" % str(TickBudgetManager.is_enabled()))
	
	print("\n" + "=" .repeat(80))
