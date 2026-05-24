extends Node
## AutonomousWorldAI — Combines WorldBox autonomy with DSS War Party production.
## Creates a self-running world where civilizations develop, wage war, and evolve
## without player intervention for 1000+ years of simulation.
##
## Key Features:
## - Set-and-watch autonomy (WorldBox-style)
## - Active production chains (DSS War Party)
## - Scalable to 1-10,000+ entities
## - Deterministic simulation
## - CPU-efficient tick decoupling
## - Living diplomacy and organic civilization evolution
##
## Integration Points:
## - CivilizationLoop: Settlement lifecycle and specialization
## - ArmyBattleSystem: Autonomous army formation and battles
## - DiplomacySystem: Organic treaty formation and breaking
## - WarProductionSystem: Continuous war material production
## - SupplyChainSystem: Resource flow and trade
## - JobManager: Priority-based worker assignment

# ============================================================
# CONFIGURATION
# ============================================================

## Simulation speed multiplier (1 = normal, 10 = fast forward)
var simulation_speed: float = 1.0

## Enable verbose logging for debugging
var debug_logging: bool = false

## Maximum entities before performance throttling kicks in
const PERFORMANCE_THRESHOLD_ENTITIES: int = 5000

## Tick budget per frame (milliseconds)
const TICK_BUDGET_MS: int = 16  # ~60 FPS target

## How often to run major AI decisions (ticks)
const MAI_AI_INTERVAL: int = 100

## How often to check entity scaling (ticks)
const SCALING_CHECK_INTERVAL: int = 300

# ============================================================
# STATE
# ============================================================

## civilization_id -> AI personality dict
var _civilization_personalities: Dictionary = {}

## settlement_id -> current strategic goal
var _settlement_goals: Dictionary = {}

## nation_id -> long-term strategy
var _nation_strategies: Dictionary = {}

## Stats tracking
var _total_ticks_processed: int = 0
var _ai_cycles_completed: int = 0
var _entities_managed: int = 0
var _performance_throttled: bool = false

## Last update ticks
var _last_major_ai_tick: int = -999999
var _last_scaling_check: int = -999999

# ============================================================
# INITIALIZATION
# ============================================================

func _ready() -> void:
	if GameManager != null:
		GameManager.game_tick.connect(_on_game_tick)
	
	_initialize_civilization_personalities()


func _initialize_civilization_personalities() -> void:
	"""Initialize AI personalities for emergent behavior."""
	_civilization_personalities = {
		"expansionist": {
			"aggression": 0.8,
			"curiosity": 0.6,
			"caution": 0.2,
			"diplomacy": 0.3,
			"production_focus": "military",
		},
		"peaceful": {
			"aggression": 0.1,
			"curiosity": 0.7,
			"caution": 0.8,
			"diplomacy": 0.9,
			"production_focus": "civilian",
		},
		"trader": {
			"aggression": 0.2,
			"curiosity": 0.9,
			"caution": 0.5,
			"diplomacy": 0.8,
			"production_focus": "economic",
		},
		"defensive": {
			"aggression": 0.3,
			"curiosity": 0.3,
			"caution": 0.9,
			"diplomacy": 0.5,
			"production_focus": "fortification",
		},
		"balanced": {
			"aggression": 0.5,
			"curiosity": 0.5,
			"caution": 0.5,
			"diplomacy": 0.5,
			"production_focus": "mixed",
		},
	}


func _on_game_tick(tick: int) -> void:
	"""Main AI tick handler."""
	_total_ticks_processed += 1
	
	# Apply simulation speed
	if simulation_speed != 1.0:
		_apply_simulation_speed(tick)
	
	# Check performance throttling
	if tick - _last_scaling_check >= SCALING_CHECK_INTERVAL:
		_last_scaling_check = tick
		_check_performance_scaling(tick)
	
	# Major AI decision cycle
	if tick - _last_major_ai_tick >= MAI_AI_INTERVAL:
		_last_major_ai_tick = tick
		_run_major_ai_cycle(tick)
		_ai_cycles_completed += 1
	
	# Continuous processes (every tick for responsiveness)
	_run_continuous_processes(tick)


func _apply_simulation_speed(tick: int) -> void:
	"""Apply simulation speed multiplier."""
	# This would integrate with TickManager to adjust tick rate
	# For now, placeholder
	pass


func _check_performance_scaling(tick: int) -> void:
	"""Check if we need to throttle for performance."""
	var total_entities: int = _count_total_entities()
	_entities_managed = total_entities
	
	if total_entities > PERFORMANCE_THRESHOLD_ENTITIES:
		_performance_throttled = true
		# Increase AI interval to reduce CPU load
		MAI_AI_INTERVAL = 200
		if debug_logging:
			print("AutonomousWorldAI: Performance throttling enabled (%d entities)" % total_entities)
	else:
		_performance_throttled = false
		MAI_AI_INTERVAL = 100


func _count_total_entities() -> int:
	"""Count total entities being simulated."""
	var count: int = 0
	
	if PawnManager != null:
		count += PawnManager.get_pawn_count() if PawnManager.has_method("get_pawn_count") else 0
	
	if SettlementMemory != null:
		count += SettlementMemory.settlements.size()
	
	if ArmyBattleSystem != null:
		count += ArmyBattleSystem.armies.size()
	
	# Add other entity counts as needed
	return count


# ============================================================
# MAJOR AI CYCLE
# ============================================================

func _run_major_ai_cycle(tick: int) -> void:
	"""Run major AI decision cycle."""
	if debug_logging:
		print("AutonomousWorldAI: Running major AI cycle at tick %d" % tick)
	
	# Phase 1: Update civilization strategies
	_update_civilization_strategies(tick)
	
	# Phase 2: Update settlement goals
	_update_settlement_goals(tick)
	
	# Phase 3: Process diplomacy
	_process_diplomacy(tick)
	
	# Phase 4: Manage military
	_manage_military_forces(tick)
	
	# Phase 5: Adjust production
	_adjust_production_priorities(tick)
	
	# Phase 6: Handle migration/expansion
	_handle_migration_and_expansion(tick)


func _update_civilization_strategies(tick: int) -> void:
	"""Update long-term strategies for each civilization."""
	if FactionManager == null or NationBorderSystem == null:
		return
	
	for faction_id in FactionManager.factions:
		if not (faction_id is int):
			continue
		
		var nation_data: Dictionary = NationBorderSystem.get_nation_by_id(faction_id)
		if nation_data.is_empty():
			continue
		
		# Determine personality based on faction traits
		var personality: String = _determine_faction_personality(faction_id)
		var personality_traits: Dictionary = _civilization_personalities.get(personality, _civilization_personalities["balanced"])
		
		# Update strategy based on current situation
		var strategy: Dictionary = _nation_strategies.get(faction_id, {})
		
		# Aggressive factions expand when strong
		if personality_traits["aggression"] > 0.7 and int(nation_data.get("strength", 0)) > 50:
			strategy["goal"] = "expand_territory"
			strategy["target_regions"] = _find_expansion_targets(faction_id)
		
		# Peaceful factions focus on development
		elif personality_traits["aggression"] < 0.3:
			strategy["goal"] = "internal_development"
			strategy["focus"] = "population_growth"
		
		# Trader factions seek trade partners
		if personality_traits["diplomacy"] > 0.7:
			strategy["goal"] = "trade_network"
			strategy["potential_partners"] = _find_trade_partners(faction_id)
		
		_nation_strategies[faction_id] = strategy


func _determine_faction_personality(faction_id: int) -> String:
	"""Determine a faction's AI personality."""
	# This would analyze faction history, traits, and behavior
	# For now, return balanced as default
	return "balanced"


func _find_expansion_targets(faction_id: int) -> Array:
	"""Find regions suitable for expansion."""
	var targets: Array = []
	# Would query NationBorderSystem for adjacent unclaimed or weakly-held regions
	return targets


func _find_trade_partners(faction_id: int) -> Array:
	"""Find potential trade partners."""
	var partners: Array = []
	# Would query SupplyChainSystem for complementary economies
	return partners


func _update_settlement_goals(tick: int) -> void:
	"""Update strategic goals for each settlement."""
	if SettlementMemory == null:
		return
	
	for st_v in SettlementMemory.settlements:
		if not (st_v is Dictionary):
			continue
		
		var st: Dictionary = st_v as Dictionary
		var center: int = int(st.get("center_region", -1))
		if center < 0:
			continue
		
		var pop: int = int(st.get("population", 0))
		var threat_level: float = _calculate_settlement_threat(st, tick)
		
		# Determine goal based on situation
		var goal: String = "maintain"
		
		if threat_level > 0.7:
			goal = "defend"
		elif pop < 3:
			goal = "grow_population"
		elif pop > 10 and threat_level < 0.3:
			goal = "expand_production"
		elif int(st.get("stock_food", 0)) < 20:
			goal = "food_security"
		
		_settlement_goals[center] = {
			"goal": goal,
			"threat_level": threat_level,
			"priority": _calculate_goal_priority(goal, threat_level),
			"tick_updated": tick,
		}


func _calculate_settlement_threat(settlement: Dictionary, tick: int) -> float:
	"""Calculate threat level for a settlement."""
	var scar_count: int = int(settlement.get("scar_max", 0))
	return clampf(float(scar_count) / 10.0, 0.0, 1.0)


func _calculate_goal_priority(goal: String, threat_level: float) -> int:
	"""Calculate priority for a goal (higher = more urgent)."""
	match goal:
		"defend":
			return 100
		"food_security":
			return 80
		"grow_population":
			return 60
		"expand_production":
			return 40
		_:
			return 20


# ============================================================
# DIPLOMACY MANAGEMENT
# ============================================================

func _process_diplomacy(tick: int) -> void:
	"""Process diplomatic interactions between nations."""
	if DiplomacySystem == null or NationBorderSystem == null:
		return
	
	# Check for treaty opportunities
	_evaluate_treaty_opportunities(tick)
	
	# Check for treaty violations
	_evaluate_treaty_violations(tick)
	
	# Process relationship changes
	_process_relationship_changes(tick)


func _evaluate_treaty_opportunities(tick: int) -> void:
	"""Evaluate potential treaty opportunities."""
	if NationBorderSystem == null:
		return
	
	var nations: Array = NationBorderSystem.get_all_nations()
	for i in range(nations.size()):
		var nation_a: int = int(nations[i])
		for j in range(i + 1, nations.size()):
			var nation_b: int = int(nations[j])
			
			# Skip if already at war
			if NationBorderSystem.are_nations_at_war(nation_a, nation_b):
				continue
			
			# Check if treaties exist
			var existing_treaties: Array = _get_treaties_between(nation_a, nation_b)
			
			if existing_treaties.size() == 0:
				# No treaties - consider proposing one
				_consider_treaty_proposal(nation_a, nation_b, tick)


func _get_treaties_between(nation_a: int, nation_b: int) -> Array:
	"""Get existing treaties between two nations."""
	var treaties: Array = []
	if DiplomacySystem != null:
		for tid in DiplomacySystem.treaties:
			var t: Dictionary = DiplomacySystem.treaties[tid]
			if (int(t.get("proposer", -1)) == nation_a and int(t.get("acceptor", -1)) == nation_b) or \
			   (int(t.get("proposer", -1)) == nation_b and int(t.get("acceptor", -1)) == nation_a):
				if bool(t.get("is_active", false)):
					treaties.append(t)
	return treaties


func _consider_treaty_proposal(nation_a: int, nation_b: int, tick: int) -> void:
	"""Consider proposing a treaty between two nations."""
	var strategy_a: Dictionary = _nation_strategies.get(nation_a, {})
	var strategy_b: Dictionary = _nation_strategies.get(nation_b, {})
	
	var personality_a: String = _determine_faction_personality(nation_a)
	var traits_a: Dictionary = _civilization_personalities.get(personality_a, {})
	
	# High diplomacy factions propose treaties more often
	if traits_a.get("diplomacy", 0.5) > 0.6:
		# Propose non-aggression pact
		DiplomacySystem.propose_treaty(
			DiplomacySystem.TreatyType.NON_AGGRESSION,
			nation_a,
			nation_b,
			{}
		)


func _evaluate_treaty_violations(tick: int) -> void:
	"""Evaluate potential treaty violations."""
	# Would check for armies crossing borders, attacks on allied settlements, etc.
	pass


func _process_relationship_changes(tick: int) -> void:
	"""Process ongoing relationship changes."""
	# Would decay old grudges, strengthen alliances over time, etc.
	pass


# ============================================================
# MILITARY MANAGEMENT
# ============================================================

func _manage_military_forces(tick: int) -> void:
	"""Manage military forces for all nations."""
	if ArmyBattleSystem == null:
		return
	
	# Form new armies where needed
	_form_new_armies(tick)
	
	# Issue movement orders
	_issue_army_orders(tick)
	
	# Reinforce threatened settlements
	_reinforce_settlements(tick)


func _form_new_armies(tick: int) -> void:
	"""Form new armies based on strategic needs."""
	if SettlementMemory == null or PawnManager == null:
		return
	
	for st_v in SettlementMemory.settlements:
		if not (st_v is Dictionary):
			continue
		
		var st: Dictionary = st_v as Dictionary
		var center: int = int(st.get("center_region", -1))
		if center < 0:
			continue
		
		var goal_data: Dictionary = _settlement_goals.get(center, {})
		var goal: String = str(goal_data.get("goal", "maintain"))
		
		# Form army if defending or expanding
		if goal in ["defend", "expand_production"]:
			var pop: int = int(st.get("population", 0))
			var existing_armies: int = _count_nearby_armies(center)
			
			if existing_armies == 0 and pop >= 5:
				_create_army_for_settlement(st, tick)


func _count_nearby_armies(center_region: int) -> int:
	"""Count armies near a settlement."""
	var count: int = 0
	if ArmyBattleSystem != null:
		for army_id in ArmyBattleSystem.armies:
			var army: Dictionary = ArmyBattleSystem.armies[army_id]
			var pos: Vector2 = army.get("position", Vector2.ZERO)
			# Check distance to settlement
			count += 1
	return count


func _create_army_for_settlement(settlement: Dictionary, tick: int) -> void:
	"""Create a new army for a settlement."""
	var center: int = int(settlement.get("center_region", -1))
	# Would integrate with ArmyBattleSystem to form army from available soldiers
	pass


func _issue_army_orders(tick: int) -> void:
	"""Issue movement and attack orders to armies."""
	if ArmyBattleSystem == null:
		return
	
	for army_id in ArmyBattleSystem.armies:
		var army: Dictionary = ArmyBattleSystem.armies[army_id]
		var nation_id: int = int(army.get("nation_id", -1))
		
		var strategy: Dictionary = _nation_strategies.get(nation_id, {})
		var goal: String = str(strategy.get("goal", "maintain"))
		
		match goal:
			"expand_territory":
				_order_army_to_expand(army, strategy, tick)
			"defend":
				_order_army_to_defend(army, tick)
			_:
				_order_army_to_patrol(army, tick)


func _order_army_to_expand(army: Dictionary, strategy: Dictionary, tick: int) -> void:
	"""Order army to expand territory."""
	var targets: Array = strategy.get("target_regions", [])
	if targets.size() > 0:
		var target: Vector2 = targets[0]
		ArmyBattleSystem.set_army_target(int(army.get("id", -1)), target)


func _order_army_to_defend(army: Dictionary, tick: int) -> void:
	"""Order army to defend position."""
	# Keep army at current position or move to threatened settlement
	pass


func _order_army_to_patrol(army: Dictionary, tick: int) -> void:
	"""Order army to patrol territory."""
	# Move army along border or between settlements
	pass


func _reinforce_settlements(tick: int) -> void:
	"""Reinforce threatened settlements with armies."""
	# Would move nearby armies to high-threat settlements
	pass


# ============================================================
# PRODUCTION MANAGEMENT
# ============================================================

func _adjust_production_priorities(tick: int) -> void:
	"""Adjust production priorities based on strategic goals."""
	if WarProductionSystem == null:
		return
	
	for center in _settlement_goals.keys():
		var goal_data: Dictionary = _settlement_goals[center]
		var goal: String = str(goal_data.get("goal", "maintain"))
		var threat_level: float = float(goal_data.get("threat_level", 0.0))
		
		# Set specialization based on goal
		var specialization: String = "mixed"
		
		match goal:
			"defend":
				specialization = "weapons"
				WarProductionSystem.set_settlement_specialization(center, specialization)
			"expand_production":
				specialization = "civilian"
				WarProductionSystem.set_settlement_specialization(center, specialization)
			"food_security":
				specialization = "supplies"
				WarProductionSystem.set_settlement_specialization(center, specialization)


# ============================================================
# MIGRATION AND EXPANSION
# ============================================================

func _handle_migration_and_expansion(tick: int) -> void:
	"""Handle population migration and settlement expansion."""
	if SettlementMemory == null:
		return
	
	# Check for overcrowded settlements
	for st_v in SettlementMemory.settlements:
		if not (st_v is Dictionary):
			continue
		
		var st: Dictionary = st_v as Dictionary
		var center: int = int(st.get("center_region", -1))
		var pop: int = int(st.get("population", 0))
		
		# Encourage migration if overcrowded
		if pop > 15:
			_spawn_migrants(st, tick)
		
		# Found new settlements if conditions are right
		if pop > 10 and _should_found_new_settlement(st, tick):
			_found_new_settlement(st, tick)


func _spawn_migrants(settlement: Dictionary, tick: int) -> void:
	"""Spawn migrant groups from overcrowded settlements."""
	# Would create migrant pawns that travel to found new settlements
	pass


func _should_found_new_settlement(settlement: Dictionary, tick: int) -> bool:
	"""Determine if a new settlement should be founded."""
	var pop: int = int(settlement.get("population", 0))
	var food: int = int(settlement.get("stock_food", 0))
	
	# Need sufficient population and food surplus
	return pop > 10 and food > 50


func _found_new_settlement(parent_settlement: Dictionary, tick: int) -> void:
	"""Found a new settlement."""
	# Would integrate with SettlementManager to create new settlement
	pass


# ============================================================
# CONTINUOUS PROCESSES
# ============================================================

func _run_continuous_processes(tick: int) -> void:
	"""Run continuous AI processes."""
	# Update production progress
	if WarProductionSystem != null:
		WarProductionSystem.process_production_progress(tick)
	
	# Update supply chains
	if SupplyChainSystem != null:
		# SupplyChainSystem updates itself via game_tick
		pass


# ============================================================
# DEBUG / STATS
# ============================================================

func get_ai_stats() -> Dictionary:
	"""Get AI statistics."""
	return {
		"total_ticks": _total_ticks_processed,
		"ai_cycles": _ai_cycles_completed,
		"entities_managed": _entities_managed,
		"performance_throttled": _performance_throttled,
		"active_settlements": _settlement_goals.size(),
		"active_nations": _nation_strategies.size(),
	}


func get_civilization_personality(faction_id: int) -> Dictionary:
	"""Get personality traits for a faction."""
	var personality: String = _determine_faction_personality(faction_id)
	return _civilization_personalities.get(personality, {})


func get_settlement_goal(center: int) -> Dictionary:
	"""Get current goal for a settlement."""
	return _settlement_goals.get(center, {})


func get_nation_strategy(nation_id: int) -> Dictionary:
	"""Get current strategy for a nation."""
	return _nation_strategies.get(nation_id, {})
