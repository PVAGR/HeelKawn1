extends RefCounted
class_name AISettlementPlanner

## Layer 3: Songs of Syx Spirit - Settlement AI
## Manages settlement development, resource logistics, expansion
##
## Reads from: SettlementMemory, StockpileManager, TradePlanner
## Writes to: SettlementPlanner, JobManager (via strategic decisions)

var _llm_client: LLMClient = null
var _settlement_memory: Node = null
var _stockpile_manager: Node = null
var _initialized: bool = false


func initialize(deps: Dictionary) -> void:
	_llm_client = deps.get("llm_client")
	_settlement_memory = deps.get("settlement_memory")
	_stockpile_manager = deps.get("stockpile_manager")
	_initialized = true


func evaluate(context: Dictionary) -> Dictionary:
	if not _initialized:
		return {"error": "not_initialized"}
	
	var settlements: Array = context.get("settlements", [])
	
	if settlements.is_empty():
		return {"strategies": 0, "reason": "no_settlements"}
	
	# Generate strategies for each settlement
	var strategies: Array[Dictionary] = []
	
	for settlement in settlements:
		var strategy: Dictionary = await _generate_settlement_strategy(settlement, context)
		if not strategy.is_empty():
			strategies.append(strategy)
	
	return {
		"strategies": strategies,
		"settlement_count": settlements.size(),
		"action": "strategic_planning"
	}


func _generate_settlement_strategy(settlement: Dictionary, context: Dictionary) -> Dictionary:
	var settlement_name: String = settlement.get("name", "Unknown")
	var population: int = settlement.get("population", 0)
	
	# Build state summary
	var state_summary: String = _build_settlement_state_summary(settlement)
	
	# Build prompt
	var prompt: String = """
You are managing the settlement {name} (population: {pop}).

MACRO STATE:
{state}

CRUSADER KINGS LAYER:
- Governance: {governance}
- Diplomatic status: {diplomacy}

Choose 2-3 STRATEGIC actions (not individual jobs):
1. Expand housing (which zone?)
2. Specialize economy (what resource?)
3. Diplomatic move (with whom?)
4. Military preparation (against whom?)
5. Knowledge focus (what to research?)

RESPOND JSON:
[
  {"strategy": "expand_housing", "zone": 3, "priority": "high", "reason": "..."},
  {"strategy": "specialize_economy", "resource": "wood", "priority": "medium", "reason": "..."}
]
""".format({
		"name": settlement_name,
		"pop": population,
		"state": state_summary,
		"governance": settlement.get("governance", "unknown"),
		"diplomacy": settlement.get("diplomacy", "neutral")
	})
	
	# Request from LLM
	var response: Dictionary = await _llm_client.request_json(
		prompt,
		{"settlement": settlement_name, "population": population},
		{},
		"Respond with a JSON array of 2-3 strategic actions. No markdown, no explanations."
	)
	
	# Parse strategies
	var strategies: Array = []
	if response is Array:
		strategies = response
	elif response.has("strategies"):
		strategies = response.get("strategies", [])
	
	# Execute strategies (would integrate with SettlementPlanner.plan())
	for strategy in strategies:
		_execute_strategy(settlement, strategy)
	
	return {
		"settlement": settlement_name,
		"strategies": strategies,
		"action": "strategic_planning"
	}


func _build_settlement_state_summary(settlement: Dictionary) -> String:
	var lines: PackedStringArray = []
	
	# Housing
	var houses: int = settlement.get("houses", 0)
	var homeless: int = settlement.get("homeless", 0)
	lines.append("- Housing: {houses} houses, {homeless} homeless".format({
		"houses": houses,
		"homeless": homeless
	}))
	
	# Food
	var food_production: float = settlement.get("food_production", 0.0)
	var food_consumption: float = settlement.get("food_consumption", 0.0)
	lines.append("- Food: {prod:.1f}/day production, {cons:.1f}/day consumption".format({
		"prod": food_production,
		"cons": food_consumption
	}))
	
	# Resources
	var resources: Dictionary = settlement.get("resources", {})
	for resource in resources:
		lines.append("- {res}: {amt}".format({"res": resource, "amt": resources[resource]}))
	
	# Population breakdown
	var pop_by_profession: Dictionary = settlement.get("population_by_profession", {})
	for profession in pop_by_profession:
		lines.append("- {prof}: {count}".format({"prof": profession, "count": pop_by_profession[profession]}))
	
	return "\n".join(lines)


func _execute_strategy(settlement: Dictionary, strategy: Dictionary) -> void:
	var strategy_type: String = strategy.get("strategy", "")
	
	match strategy_type:
		"expand_housing":
			# Would call SettlementPlanner.plan() to zone new housing
			pass
		
		"specialize_economy":
			# Would adjust job priorities for resource specialization
			pass
		
		"diplomatic_move":
			# Would trigger AIDiplomacyDirector
			pass
		
		"military_preparation":
			# Would queue military jobs
			pass
		
		"knowledge_focus":
			# Would prioritize research jobs
			pass


## Get planner statistics
func get_stats() -> Dictionary:
	return {
		"initialized": _initialized,
		"strategies_generated": 0,
		"last_update_tick": -1
	}
