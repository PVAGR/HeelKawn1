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
var MAI_AI_INTERVAL: int = 100

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
	"""Apply simulation speed multiplier — integrates with TickManager."""
	if GameManager == null:
		return
	var speed: float = GameManager.game_speed if GameManager.has_method("get_game_speed") else simulation_speed
	MAI_AI_INTERVAL = maxi(20, int(100.0 / maxf(speed, 0.5)))
	_entities_managed = _count_total_entities()
	if _entities_managed > PERFORMANCE_THRESHOLD_ENTITIES and speed > 1.0:
		MAI_AI_INTERVAL = maxi(MAI_AI_INTERVAL, 50)


func _check_performance_scaling(tick: int) -> void:
	"""Count entities for stats only — no throttling."""
	var total_entities: int = _count_total_entities()
	_entities_managed = total_entities
	_performance_throttled = false


func _count_total_entities() -> int:
	"""Count total entities being simulated."""
	var count: int = 0
	
	var pm := get_node_or_null("/root/PawnManager")
	if pm != null and pm.has_method("get_pawn_count"):
		count += pm.get_pawn_count()
	
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
	
	# Use NationBorderSystem's nation list instead of FactionManager
	var nations: Array[Dictionary] = NationBorderSystem.get_all_nations() if NationBorderSystem.has_method("get_all_nations") else []
	
	if nations.is_empty():
		return
	
	for nation_data in nations:
		if not (nation_data is Dictionary) or nation_data.is_empty():
			continue
		
		var faction_id: int = int(nation_data.get("id", -1))
		if faction_id < 0:
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
	"""Determine a faction's AI personality from Egregore signature + history."""
	if EgregoreMemory == null:
		return _derive_personality_from_history(faction_id)
	var sig: Dictionary = EgregoreMemory.get_settlement_signature(faction_id)
	if sig.is_empty():
		return _derive_personality_from_history(faction_id)
	var coop: float = sig.get("cooperation", 0.5)
	var fear: float = sig.get("fear", 0.2)
	var vengeance: float = sig.get("vengeance", 0.2)
	var curiosity: float = sig.get("curiosity", 0.4)
	var discipline: float = sig.get("discipline", 0.3)
	if fear > 0.7 and vengeance > 0.5:
		return "defensive"
	if vengeance > 0.6 and discipline > 0.6:
		return "expansionist"
	if curiosity > 0.7 and coop > 0.6:
		return "trader"
	if coop > 0.7 and fear < 0.3:
		return "peaceful"
	return _derive_personality_from_history(faction_id)


func _derive_personality_from_history(faction_id: int) -> String:
	"""Fallback: derive personality from WorldMemory faction event patterns."""
	if WorldMemory == null:
		return "balanced"
	var events: Array = WorldMemory.get_events()
	var war_count: int = 0
	var trade_count: int = 0
	var treaty_count: int = 0
	for ev in events:
		if not (ev is Dictionary):
			continue
		var e: Dictionary = ev as Dictionary
		var fid: int = int(e.get("faction_id", -1))
		if fid != faction_id and fid != -1:
			continue
		var etype: String = str(e.get("type", ""))
		if etype in ["war_declared", "battle"]:
			war_count += 1
		elif etype in ["trade_route_established", "trade_deal"]:
			trade_count += 1
		elif etype in ["treaty_signed", "alliance_formed"]:
			treaty_count += 1
	if war_count > trade_count * 2 and war_count > 3:
		return "expansionist"
	if trade_count > war_count * 2 and trade_count > 3:
		return "trader"
	if treaty_count > war_count and treaty_count > 2:
		return "peaceful"
	return "balanced"


func _find_expansion_targets(faction_id: int) -> Array:
	"""Find regions suitable for expansion — scans for unclaimed or weakly-held adjacent regions."""
	var targets: Array = []
	if NationBorderSystem == null:
		return targets
	var my_nation: Dictionary = {}
	var all_nations: Array[Dictionary] = NationBorderSystem.get_all_nations()
	for nd in all_nations:
		if nd is Dictionary and int(nd.get("id", -1)) == faction_id:
			my_nation = nd
			break
	if my_nation.is_empty():
		return targets
	var my_regions: Array = my_nation.get("regions", [])
	if my_regions.is_empty():
		return targets
	var my_strength: int = int(my_nation.get("strength", 0))
	var world := get_node_or_null("/root/Main/WorldViewport/World") as World
	if world == null:
		return targets
	var max_scan: int = 30
	var scanned: int = 0
	for rk in my_regions:
		if scanned >= max_scan:
			break
		if not (rk is int):
			continue
		var tile: Vector2i = _region_key_to_tile(int(rk))
		for dx in range(-3, 4):
			for dy in range(-3, 4):
				if scanned >= max_scan:
					break
				var nt: Vector2i = tile + Vector2i(dx, dy)
				if nt.x < 0 or nt.y < 0 or nt.x >= 256 or nt.y >= 256:
					continue
				var nrk: int = _tile_to_region_key(nt.x, nt.y)
				var owner: int = NationBorderSystem.get_nation_at_region(nrk)
				if owner < 0:
					var biome: int = world.get_cell_tile_data(0, nt).get("biome", 0) if world.has_method("get_cell_tile_data") else 0
					if biome in [0, 1, 2]:
						targets.append(Vector2(nt.x * 10 + 5, nt.y * 10 + 5))
						scanned += 1
				elif owner != faction_id:
					var other_nation: Dictionary = {}
					for nd2 in all_nations:
						if nd2 is Dictionary and int(nd2.get("id", -1)) == owner:
							other_nation = nd2
							break
					if not other_nation.is_empty():
						var other_strength: int = int(other_nation.get("strength", 0))
						if other_strength < my_strength * 0.5:
							targets.append(Vector2(nt.x * 10 + 5, nt.y * 10 + 5))
							scanned += 1
	targets.sort_custom(func(a: Vector2, b: Vector2) -> bool:
		var da: float = a.distance_squared_to(Vector2(127 * 10, 127 * 10))
		var db: float = b.distance_squared_to(Vector2(127 * 10, 127 * 10))
		return da < db
	)
	return targets


func _region_key_to_tile(region_key: int) -> Vector2i:
	return Vector2i(region_key % 256, region_key / 256)


func _tile_to_region_key(tx: int, ty: int) -> int:
	return ty * 256 + tx


func _find_trade_partners(faction_id: int) -> Array:
	"""Find potential trade partners — checks DiplomacySystem and economy complementarity."""
	var partners: Array = []
	var ds := get_node_or_null("/root/DiplomacySystem")
	if ds == null or NationBorderSystem == null:
		return partners
	var all_nations: Array[Dictionary] = NationBorderSystem.get_all_nations()
	var my_econ: String = _get_economy_type(faction_id)
	for nd in all_nations:
		if not (nd is Dictionary):
			continue
		var other_id: int = int(nd.get("id", -1))
		if other_id == faction_id or other_id < 0:
			continue
		if NationBorderSystem.are_nations_at_war(faction_id, other_id):
			continue
		var other_econ: String = _get_economy_type(other_id)
		if my_econ != other_econ:
			partners.append(other_id)
		elif partners.is_empty():
			partners.append(other_id)
	partners.sort()
	return partners


func _get_economy_type(faction_id: int) -> String:
	"""Determine a faction's dominant economy from specialization."""
	var spec: String = "mixed"
	if WarProductionSystem != null and WarProductionSystem.has_method("get_settlement_specialization"):
		spec = WarProductionSystem.get_settlement_specialization(faction_id)
	match spec:
		"weapons", "defense":
			return "military"
		"civilian":
			return "civilian"
		_:
			return "mixed"


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
	var ds := get_node_or_null("/root/DiplomacySystem")
	if ds == null or NationBorderSystem == null:
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
	
	var nation_dicts: Array = NationBorderSystem.get_all_nations()
	var nation_ids: Array[int] = []
	for nd in nation_dicts:
		if nd is Dictionary:
			var nid: int = int(nd.get("id", -1))
			if nid >= 0:
				nation_ids.append(nid)
	for i in range(nation_ids.size()):
		var nation_a: int = nation_ids[i]
		for j in range(i + 1, nation_ids.size()):
			var nation_b: int = nation_ids[j]
			
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
	var ds := get_node_or_null("/root/DiplomacySystem")
	if ds != null and ds.has_node(".") and ds.get("treaties") != null:
		var ds_treaties: Dictionary = ds.get("treaties")
		for tid in ds_treaties:
			var t: Dictionary = ds_treaties[tid]
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
		var ds := get_node_or_null("/root/DiplomacySystem")
		if ds != null and ds.has_method("propose_treaty"):
			# Propose non-aggression pact
			ds.propose_treaty(
				ds.TreatyType.NON_AGGRESSION if ds.has_constant("TreatyType") else 1,
				nation_a,
				nation_b,
				{}
			)


func _evaluate_treaty_violations(tick: int) -> void:
	"""Evaluate potential treaty violations — checks border crossings and attacks."""
	if NationBorderSystem == null or ArmyBattleSystem == null:
		return
	var ds := get_node_or_null("/root/DiplomacySystem")
	if ds == null:
		return
	var all_nations: Array[Dictionary] = NationBorderSystem.get_all_nations()
	for army in ArmyBattleSystem.get_active_armies():
		if not (army is Dictionary):
			continue
		var army_dict: Dictionary = army as Dictionary
		var army_nation: int = int(army_dict.get("nation_id", -1))
		var army_pos: Vector2 = army_dict.get("position", Vector2(-1, -1))
		if army_nation < 0 or army_pos.x < 0:
			continue
		var tile: Vector2i = Vector2i(int(army_pos.x) / 10, int(army_pos.y) / 10)
		var region_owner: int = NationBorderSystem.get_nation_at_region(_tile_to_region_key(tile.x, tile.y))
		if region_owner >= 0 and region_owner != army_nation:
			if not NationBorderSystem.are_nations_at_war(army_nation, region_owner):
				var personality: String = _determine_faction_personality(region_owner)
				var traits: Dictionary = _civilization_personalities.get(personality, {})
				if traits.get("caution", 0.5) > 0.3:
					if ds.has_method("add_treaty_violation"):
						ds.add_treaty_violation(army_nation, region_owner, tick, "border_crossing")
	if WorldMemory != null:
		WorldMemory.record_event({
			"type": "treaty_violation_check",
			"tick": tick,
			"nations_scanned": all_nations.size(),
		})


func _process_relationship_changes(tick: int) -> void:
	"""Process ongoing relationship changes — decay old grudges, strengthen alliances."""
	var ds := get_node_or_null("/root/DiplomacySystem")
	if ds == null:
		return
	if tick % 1000 != 0:
		return
	for nd in NationBorderSystem.get_all_nations():
		if not (nd is Dictionary):
			continue
		var nid: int = int(nd.get("id", -1))
		if nid < 0:
			continue
		var personality: String = _determine_faction_personality(nid)
		var traits: Dictionary = _civilization_personalities.get(personality, {})
		var diplo_bias: float = traits.get("diplomacy", 0.5)
		if EgregoreMemory != null:
			var sig: Dictionary = EgregoreMemory.get_settlement_signature(nid)
			if not sig.is_empty():
				var coop: float = sig.get("cooperation", 0.4)
				diplo_bias = (diplo_bias + coop) * 0.5
		if ds.has_method("adjust_nation_relationship"):
			ds.adjust_nation_relationship(nid, -1, -0.01 * (1.0 - diplo_bias))
		if ds.has_method("strengthen_alliances"):
			ds.strengthen_alliances(nid, 0.005 * diplo_bias)


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
	if SettlementMemory == null:
		return
	
	var pm := get_node_or_null("/root/PawnManager")
	if pm == null or not pm.has_method("get_pawn_count"):
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
	"""Create a new army for a settlement — integrates with ArmyBattleSystem."""
	if ArmyBattleSystem == null or not ArmyBattleSystem.has_method("create_army"):
		return
	var center: int = int(settlement.get("center_region", -1))
	var nation_id: int = NationBorderSystem.get_nation_at_region(center) if NationBorderSystem != null else -1
	if nation_id < 0:
		return
	var personality: String = _determine_faction_personality(nation_id)
	var pop: int = int(settlement.get("population", 0))
	var soldier_count: int = maxi(2, int(pop * 0.25))
	var pos: Vector2 = Vector2(
		(center % 256) * 10 + 5,
		(center / 256) * 10 + 5
	)
	var soldier_ids: Array[int] = []
	var pm := get_node_or_null("/root/PawnManager")
	if pm != null and pm.has_method("find_alive_pawns"):
		var all_pawns: Array = pm.find_alive_pawns()
		for p in all_pawns:
			if p != null and p.data != null and soldier_ids.size() < soldier_count:
				var s_id: int = int(p.data.id)
				if s_id > 0:
					soldier_ids.append(s_id)
	if soldier_ids.is_empty():
		return
	var army_id: int = ArmyBattleSystem.create_army(soldier_ids[0], nation_id, soldier_ids, pos, tick)
	if army_id >= 0:
		if WorldMemory != null:
			WorldMemory.record_event({
				"type": "army_formed",
				"army_id": army_id,
				"nation_id": nation_id,
				"settlement_center": center,
				"strength": strength,
				"personality": personality,
				"tick": tick,
			})


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
	"""Order army to defend the nearest threatened settlement."""
	if ArmyBattleSystem == null or SettlementMemory == null:
		return
	var army_pos: Vector2 = army.get("position", Vector2.ZERO)
	var nation_id: int = int(army.get("nation_id", -1))
	var best_target: Vector2 = army_pos
	var best_threat: float = 0.0
	for st_v in SettlementMemory.settlements:
		if not (st_v is Dictionary):
			continue
		var st: Dictionary = st_v as Dictionary
		var st_nation: int = NationBorderSystem.get_nation_at_region(int(st.get("center_region", -1))) if NationBorderSystem != null else -1
		if st_nation != nation_id:
			continue
		var threat: float = _calculate_settlement_threat(st, tick)
		if threat > best_threat:
			var st_center: int = int(st.get("center_region", -1))
			var st_pos: Vector2 = Vector2((st_center % 256) * 10 + 5, (st_center / 256) * 10 + 5)
			if army_pos.distance_squared_to(st_pos) < 250000.0:
				best_threat = threat
				best_target = st_pos
	if best_threat > 0.3:
		ArmyBattleSystem.set_army_target(int(army.get("id", -1)), best_target)


func _order_army_to_patrol(army: Dictionary, tick: int) -> void:
	"""Order army to patrol between key settlements or along border."""
	if ArmyBattleSystem == null or SettlementMemory == null:
		return
	var nation_id: int = int(army.get("nation_id", -1))
	var owned_settlements: Array[Vector2] = []
	for st_v in SettlementMemory.settlements:
		if not (st_v is Dictionary):
			continue
		var st: Dictionary = st_v as Dictionary
		var st_nation: int = NationBorderSystem.get_nation_at_region(int(st.get("center_region", -1))) if NationBorderSystem != null else -1
		if st_nation == nation_id:
			var sc: int = int(st.get("center_region", -1))
			owned_settlements.append(Vector2((sc % 256) * 10 + 5, (sc / 256) * 10 + 5))
	if owned_settlements.size() >= 2:
		var patrol_target: Vector2 = owned_settlements[tick % owned_settlements.size()]
		ArmyBattleSystem.set_army_target(int(army.get("id", -1)), patrol_target)
	elif owned_settlements.size() == 1:
		ArmyBattleSystem.set_army_target(int(army.get("id", -1)), owned_settlements[0])


func _reinforce_settlements(tick: int) -> void:
	"""Reinforce threatened settlements — moves nearby armies."""
	if ArmyBattleSystem == null or SettlementMemory == null:
		return
	if tick % 500 != 0:
		return
	for st_v in SettlementMemory.settlements:
		if not (st_v is Dictionary):
			continue
		var st: Dictionary = st_v as Dictionary
		var center: int = int(st.get("center_region", -1))
		var threat: float = _calculate_settlement_threat(st, tick)
		if threat < 0.6:
			continue
		var st_pos: Vector2 = Vector2((center % 256) * 10 + 5, (center / 256) * 10 + 5)
		var nation_id: int = NationBorderSystem.get_nation_at_region(center) if NationBorderSystem != null else -1
		if nation_id < 0:
			continue
		var closest_army_id: int = -1
		var closest_dist: float = 999999.0
		for army in ArmyBattleSystem.get_active_armies():
			if not (army is Dictionary):
				continue
			var a_dict: Dictionary = army as Dictionary
			if int(a_dict.get("nation_id", -1)) != nation_id:
				continue
			var a_pos: Vector2 = a_dict.get("position", Vector2.ZERO)
			var dist: float = a_pos.distance_squared_to(st_pos)
			if dist < closest_dist:
				closest_dist = dist
				closest_army_id = int(a_dict.get("id", -1))
		if closest_army_id >= 0:
			ArmyBattleSystem.set_army_target(closest_army_id, st_pos)
			if WorldMemory != null:
				WorldMemory.record_event({
					"type": "settlement_reinforced",
					"army_id": closest_army_id,
					"settlement_center": center,
					"threat_level": threat,
					"tick": tick,
				})


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
	"""Spawn migrant groups from overcrowded settlements — creates pawns that migrate out."""
	if SettlementMemory == null:
		return
	var pm := get_node_or_null("/root/PawnManager")
	var ps := get_node_or_null("/root/Main/WorldViewport/PawnSpawner")
	if pm == null or ps == null:
		return
	if tick % 2000 != 0:
		return
	var center: int = int(settlement.get("center_region", -1))
	var pop: int = int(settlement.get("population", 0))
	if pop < 8:
		return
	var overflow: int = pop - 12
	if overflow <= 0:
		return
	var migrant_count: int = mini(overflow, 3)
	var region_pos: Vector2 = Vector2((center % 256) * 10 + 5, (center / 256) * 10 + 5)
	var hex_seed: int = int(str(center).hash() ^ tick ^ 7919)
	for i in range(migrant_count):
		var migrant_name: String = "Migrant %d" % [tick + i]
		var offset: Vector2 = Vector2(
			((hex_seed + i * 101) % 40) - 20,
			((hex_seed + i * 103) % 40) - 20
		)
		if ps.has_method("spawn_migrant_pawn"):
			ps.spawn_migrant_pawn(region_pos + offset)
		elif ps.has_method("spawn_pawn"):
			ps.spawn_pawn(region_pos + offset)
	if WorldMemory != null and migrant_count > 0:
		WorldMemory.record_event({
			"type": "migration_out",
			"settlement_center": center,
			"migrant_count": migrant_count,
			"reason": "overcrowding",
			"population": pop,
			"tick": tick,
		})


func _should_found_new_settlement(settlement: Dictionary, tick: int) -> bool:
	"""Determine if a new settlement should be founded."""
	var pop: int = int(settlement.get("population", 0))
	var food: int = int(settlement.get("stock_food", 0))
	
	# Need sufficient population and food surplus
	return pop > 10 and food > 50


func _found_new_settlement(parent_settlement: Dictionary, tick: int) -> void:
	"""Found a new settlement — integrates with SettlementManager or FragmentationManager."""
	if SettlementMemory == null:
		return
	var center: int = int(parent_settlement.get("center_region", -1))
	var nation_id: int = NationBorderSystem.get_nation_at_region(center) if NationBorderSystem != null else -1
	if FragmentationManager != null and FragmentationManager.has_method("find_outward_passable"):
		var targets: Array[Vector2i] = []
		var ref_tile: Vector2i = Vector2i(center % 256, center / 256)
		for dx in range(-5, 6):
			for dy in range(-5, 6):
				var nt: Vector2i = ref_tile + Vector2i(dx, dy)
				if nt.x < 0 or nt.y < 0 or nt.x >= 256 or nt.y >= 256:
					continue
				targets.append(nt)
		for t in targets:
			var nrk: int = _tile_to_region_key(t.x, t.y)
			if NationBorderSystem != null:
				var owner: int = NationBorderSystem.get_nation_at_region(nrk)
				if owner >= 0:
					continue
			if FragmentationManager.find_outward_passable(t, 5).size() > 0:
				var sm := get_node_or_null("/root/SettlementManager")
				if sm != null and sm.has_method("create_settlement"):
					sm.create_settlement(nrk, "Outpost %d" % [tick])
					if WorldMemory != null:
						WorldMemory.record_event({
							"type": "new_settlement_founded",
							"parent_center": center,
							"new_center": nrk,
							"nation_id": nation_id,
							"tick": tick,
						})
				break


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
