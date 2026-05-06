extends RefCounted
class_name AIDiplomacyDirector

## Layer 4: Crusader Kings Spirit - Diplomacy AI
## Manages inter-settlement relations, dynasties, wars, alliances, trade agreements
##
## Reads from: GrudgeManager, GossipManager, SettlementMemory, TradeMemory
## Writes to: Diplomatic actions, war declarations, alliance proposals

var _llm_client: LLMClient = null
var _grudge_manager: Node = null
var _gossip_manager: Node = null
var _settlement_memory: Node = null
var _world_memory: Node = null
var _initialized: bool = false


func initialize(deps: Dictionary) -> void:
	_llm_client = deps.get("llm_client")
	_grudge_manager = deps.get("grudge_manager")
	_gossip_manager = deps.get("gossip_manager")
	_settlement_memory = deps.get("settlement_memory")
	_world_memory = deps.get("world_memory")
	_initialized = true


func evaluate(context: Dictionary) -> Dictionary:
	if not _initialized:
		return {"error": "not_initialized"}
	
	var settlement_relations: Array = context.get("settlement_relations", [])
	
	if settlement_relations.is_empty():
		return {"diplomatic_actions": 0, "reason": "no_settlement_relations"}
	
	# Evaluate diplomatic actions for each settlement pair
	var actions: Array[Dictionary] = []
	
	for relation in settlement_relations:
		var action: Dictionary = await _evaluate_diplomatic_action(relation, context)
		if not action.is_empty() and action.get("action") != "IGNORE":
			actions.append(action)
			# Execute diplomatic action
			_execute_diplomatic_action(relation, action)
	
	return {
		"diplomatic_actions": actions.size(),
		"actions": actions,
		"action": "diplomatic_evaluation"
	}


func _evaluate_diplomatic_action(relation: Dictionary, context: Dictionary) -> Dictionary:
	var from_id: int = relation.get("from_id", 0)
	var to_id: int = relation.get("to_id", 0)
	var from_name: String = relation.get("from_name", "Unknown")
	var to_name: String = relation.get("to_name", "Unknown")
	
	# Build diplomatic context
	var relationship: String = _build_relationship_summary(from_id, to_id)
	var power_balance: String = _calculate_power_balance(from_id, to_id)
	
	# Build prompt
	var prompt: String = """
Settlement {from_name} considers action toward {to_name}.

RELATIONSHIP:
{relationship}

POWER BALANCE:
{power}

HISTORICAL CONTEXT:
- Past wars: {wars}
- Trade history: {trade}
- Dynastic ties: {dynasty}

CRUSADER KINGS STYLE:
"The ruler weighs honor vs. pragmatism. What serves the settlement best?"

What should {from_name} do?
Options: DECLARE_WAR, PROPOSE_ALLIANCE, SEND_GIFT, DEMAND_TRIBUTE, 
         PROPOSE_TRADE, PROPOSE_PEACE, IGNORE

Consider: power balance, active grudges, strategic advantage, resources.

RESPOND JSON:
{{
  "action": "PROPOSE_ALLIANCE",
  "reason": "mutual threat from third settlement",
  "confidence": 0.8,
  "terms": {{
    "trade_bonus": 10,
    "military_support": true,
    "duration_ticks": 3600
  }}
}}
""".format({
		"from_name": from_name,
		"to_name": to_name,
		"relationship": relationship,
		"power": power_balance,
		"wars": relation.get("war_history", "none"),
		"trade": relation.get("trade_history", "none"),
		"dynasty": relation.get("dynastic_ties", "none")
	})
	
	# Request from LLM
	var response: Dictionary = await _llm_client.request_json(
		prompt,
		{"from_id": from_id, "to_id": to_id, "context": "diplomacy"},
		{},
		"Respond with valid JSON only. No markdown, no explanations."
	)
	
	return response


func _build_relationship_summary(from_id: int, to_id: int) -> String:
	var lines: PackedStringArray = []
	
	# Get active grudges
	var grudge_count: int = 0
	if _grudge_manager != null:
		# Would query grudges between settlements
		grudge_count = 0
	
	if grudge_count > 0:
		lines.append("- Active grudges: {count}".format({"count": grudge_count}))
	else:
		lines.append("- No active grudges")
	
	# Get gossip
	var gossip_count: int = 0
	if _gossip_manager != null:
		# Would query gossip between settlements
		gossip_count = 0
	
	lines.append("- Gossip items: {count}".format({"count": gossip_count}))
	
	# Trade relations
	lines.append("- Trade relations: stable")
	
	return "\n".join(lines)


func _calculate_power_balance(from_id: int, to_id: int) -> String:
	# Would calculate relative power (population, military, resources)
	# For now, return placeholder
	
	var scenarios: Array[String] = [
		"{from} is stronger militarily",
		"{to} has economic advantage",
		"Roughly equal power",
		"{from} has defensive advantage"
	]
	
	return scenarios[randi() % scenarios.size()]


func _execute_diplomatic_action(relation: Dictionary, action: Dictionary) -> void:
	var action_type: String = action.get("action", "IGNORE")
	var from_id: int = relation.get("from_id", 0)
	var to_id: int = relation.get("to_id", 0)
	
	match action_type:
		"DECLARE_WAR":
			_declare_war(from_id, to_id, action)
		
		"PROPOSE_ALLIANCE":
			_propose_alliance(from_id, to_id, action)
		
		"SEND_GIFT":
			_send_gift(from_id, to_id, action)
		
		"DEMAND_TRIBUTE":
			_demand_tribute(from_id, to_id, action)
		
		"PROPOSE_TRADE":
			_propose_trade(from_id, to_id, action)
		
		"PROPOSE_PEACE":
			_propose_peace(from_id, to_id, action)
		
		_:
			pass  # IGNORE or unknown action


func _declare_war(from_id: int, to_id: int, action: Dictionary) -> void:
	# Would trigger war declaration via WorldEvents
	print("[AIDiplomacy] {from} declared war on {to}".format({
		"from": from_id,
		"to": to_id
	}))

	# Record event
	if _world_memory != null:
		_world_memory.record_event({
			"type": "ai_war_declared",
			"from_settlement": from_id,
			"to_settlement": to_id,
			"reason": action.get("reason", "unknown")
		})


func _propose_alliance(from_id: int, to_id: int, action: Dictionary) -> void:
	# Would send alliance proposal
	print("[AIDiplomacy] {from} proposed alliance to {to}".format({
		"from": from_id,
		"to": to_id
	}))


func _send_gift(from_id: int, to_id: int, action: Dictionary) -> void:
	# Would transfer resources as gift
	var terms: Dictionary = action.get("terms", {})
	print("[AIDiplomacy] {from} sent gift to {to}: {terms}".format({
		"from": from_id,
		"to": to_id,
		"terms": terms
	}))


func _demand_tribute(from_id: int, to_id: int, action: Dictionary) -> void:
	# Would send tribute demand
	print("[AIDiplomacy] {from} demanded tribute from {to}".format({
		"from": from_id,
		"to": to_id
	}))


func _propose_trade(from_id: int, to_id: int, action: Dictionary) -> void:
	# Would create trade agreement via TradePlanner
	var terms: Dictionary = action.get("terms", {})
	print("[AIDiplomacy] {from} proposed trade to {to}: {terms}".format({
		"from": from_id,
		"to": to_id,
		"terms": terms
	}))


func _propose_peace(from_id: int, to_id: int, action: Dictionary) -> void:
	# Would propose peace treaty
	print("[AIDiplomacy] {from} proposed peace to {to}".format({
		"from": from_id,
		"to": to_id
	}))


## Get diplomacy statistics
func get_stats() -> Dictionary:
	return {
		"initialized": _initialized,
		"actions_taken": 0,
		"wars_declared": 0,
		"alliances_formed": 0,
		"last_update_tick": -1
	}
