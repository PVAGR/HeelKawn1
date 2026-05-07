extends RefCounted
class_name AIWorldEcosystem

## Layer 5: WorldBox Spirit - Ecosystem AI
## Manages world-scale ecosystems, wildlife populations, climate shifts, natural disasters
##
## Reads from: WildlifePopulation, DisasterSystem, WorldMemory
## Writes to: Wildlife spawns/migrations, disaster triggers, climate events

var _llm_client: LLMClient = null
var _wildlife_population: Node = null
var _disaster_system: Node = null
var _world_memory: Node = null
var _initialized: bool = false


func initialize(deps: Dictionary) -> void:
	_llm_client = deps.get("llm_client")
	_wildlife_population = deps.get("wildlife_population")
	_disaster_system = deps.get("disaster_system")
	_world_memory = deps.get("world_memory")
	_initialized = true


func evaluate(context: Dictionary) -> Dictionary:
	if not _initialized:
		return {"error": "not_initialized"}
	
	# Build world ecosystem state
	var world_state: Dictionary = _build_world_ecosystem_state(context)
	
	# Evaluate world events
	var events: Array = await _evaluate_world_events(world_state, context)
	
	# Execute world events
	for event in events:
		_execute_world_event(event)
	
	return {
		"world_events": events.size(),
		"events": events,
		"world_state": world_state,
		"action": "ecosystem_evaluation"
	}


func _build_world_ecosystem_state(context: Dictionary) -> Dictionary:
	var state: Dictionary = {
		"tick": context.get("tick", 0),
		"year": context.get("year", 0),
		"settlement_count": 0,
		"total_population": 0,
		"wildlife_populations": [],
		"climate_summary": "stable",
		"disaster_risk": "low",
		"resource_trends": {}
	}
	
	# Get settlement count
	var settlement_count: int = context.get("active_settlements", 0)
	state.settlement_count = settlement_count
	
	# Estimate total population (would query SettlementMemory)
	state.total_population = settlement_count * 15  # Rough estimate
	
	# Get wildlife populations
	if _wildlife_population != null and _wildlife_population.has_method("get_stats"):
		state.wildlife_populations = [_wildlife_population.get_stats()]
	
	# Get disaster risk
	if _disaster_system != null and _disaster_system.has_method("get_risk_assessment"):
		state.disaster_risk = _disaster_system.get_risk_assessment()
	
	# Resource trends (would analyze over time)
	state.resource_trends = {
		"food": "stable",
		"wood": "increasing",
		"stone": "stable",
		"wildlife": "stable"
	}
	
	return state


func _evaluate_world_events(world_state: Dictionary, context: Dictionary) -> Array:
	# Build prompt
	var prompt: String = """
You oversee the world ecosystem.

WORLD STATE:
- Settlements: {settlements} (total pop: {pop})
- Wildlife: {wildlife}
- Climate: {climate}
- Resource trends: {resources}
- Disaster risk: {disaster_risk}
- Year: {year}

As world simulator, what should happen next?
WorldBox style: "The world evolves whether humans are ready or not."

Options:
1. MIGRATION_WAVE (wildlife movement)
2. RESOURCE_DEPLETION (local scarcity)
3. CLIMATE_SHIFT (weather pattern change)
4. WILDLIFE_BOOM (population increase)
5. WILDLIFE_BUST (population decline)
6. PLAGUE_OUTBREAK (disease spread)
7. NATURAL_DISASTER (fire, flood, earthquake)
8. NOTHING (stable period)

Choose 1-2 events that make sense given the world state.
Consider: settlement pressure, resource balance, ecosystem health.

RESPOND JSON:
[
  {{
    "event": "migration_wave",
    "target_region": "north",
    "species": "deer",
    "reason": "overpopulation in south",
    "impact": "food source moves away from settlements"
  }}
]
""".format({
		"settlements": world_state.settlement_count,
		"pop": world_state.total_population,
		"wildlife": str(world_state.wildlife_populations),
		"climate": world_state.climate_summary,
		"resources": str(world_state.resource_trends),
		"disaster_risk": world_state.disaster_risk,
		"year": world_state.year
	})
	
	# Request from LLM
	var response: Dictionary = await _llm_client.request_json(
		prompt,
		world_state,
		{},
		"Respond with a JSON array of 1-2 world events. No markdown, no explanations."
	)

	# Parse events
	var events: Array = []
	if response is Array:
		events = response as Array
	elif response is Dictionary and response.has("events"):
		var events_var: Variant = response.get("events")
		if events_var is Array:
			events = events_var as Array

	return events


func _execute_world_event(event: Dictionary) -> void:
	var event_type: String = event.get("event", "unknown")
	
	match event_type:
		"migration_wave":
			_trigger_migration(event)
		
		"resource_depletion":
			_trigger_resource_depletion(event)
		
		"climate_shift":
			_trigger_climate_shift(event)
		
		"wildlife_boom":
			_trigger_wildlife_boom(event)
		
		"wildlife_bust":
			_trigger_wildlife_bust(event)
		
		"plague_outbreak":
			_trigger_plague_outbreak(event)
		
		"natural_disaster":
			_trigger_natural_disaster(event)
		
		_:
			pass  # NOTHING or unknown event


func _trigger_migration(event: Dictionary) -> void:
	var species: String = event.get("species", "deer")
	var target: String = event.get("target_region", "north")
	var reason: String = event.get("reason", "natural cycles")
	
	print("[AIWorldEcosystem] Migration: {species} moving to {target} ({reason})".format({
		"species": species,
		"target": target,
		"reason": reason
	}))
	
	# Would update WildlifePopulation
	if _wildlife_population != null:
		# Would call wildlife population update
		pass
	
	# Record event
	if _world_memory != null:
		_world_memory.record_event({
			"type": "ai_migration_wave",
			"species": species,
			"region": target,
			"reason": reason
		})


func _trigger_resource_depletion(event: Dictionary) -> void:
	var resource: String = event.get("resource", "wood")
	var region: String = event.get("region", "central")
	
	print("[AIWorldEcosystem] Resource depletion: {resource} in {region}".format({
		"resource": resource,
		"region": region
	}))


func _trigger_climate_shift(event: Dictionary) -> void:
	var shift_type: String = event.get("shift_type", "warming")
	var severity: String = event.get("severity", "mild")
	
	print("[AIWorldEcosystem] Climate shift: {type} ({severity})".format({
		"type": shift_type,
		"severity": severity
	}))


func _trigger_wildlife_boom(event: Dictionary) -> void:
	var species: String = event.get("species", "deer")
	var region: String = event.get("region", "north")
	var reason: String = event.get("reason", "favorable conditions")
	
	print("[AIWorldEcosystem] Wildlife boom: {species} in {region} ({reason})".format({
		"species": species,
		"region": region,
		"reason": reason
	}))
	
	# Would increase wildlife population
	if _wildlife_population != null:
		pass


func _trigger_wildlife_bust(event: Dictionary) -> void:
	var species: String = event.get("species", "deer")
	var region: String = event.get("region", "north")
	var reason: String = event.get("reason", "harsh winter")
	
	print("[AIWorldEcosystem] Wildlife bust: {species} in {region} ({reason})".format({
		"species": species,
		"region": region,
		"reason": reason
	}))


func _trigger_plague_outbreak(event: Dictionary) -> void:
	var plague_type: String = event.get("plague_type", "livestock")
	var region: String = event.get("region", "central")
	var severity: String = event.get("severity", "moderate")
	
	print("[AIWorldEcosystem] Plague outbreak: {type} in {region} ({severity})".format({
		"type": plague_type,
		"region": region,
		"severity": severity
	}))
	
	# Would trigger disease via DisasterSystem
	if _disaster_system != null:
		pass


func _trigger_natural_disaster(event: Dictionary) -> void:
	var disaster_type: String = event.get("disaster_type", "fire")
	var region: String = event.get("region", "forest")
	var severity: String = event.get("severity", "moderate")
	
	print("[AIWorldEcosystem] Natural disaster: {type} in {region} ({severity})".format({
		"type": disaster_type,
		"region": region,
		"severity": severity
	}))
	
	# Would trigger disaster via DisasterSystem
	if _disaster_system != null and _disaster_system.has_method("trigger_disaster"):
		_disaster_system.trigger_disaster({
			"type": disaster_type,
			"region": region,
			"severity": severity
		})


## Get ecosystem statistics
func get_stats() -> Dictionary:
	return {
		"initialized": _initialized,
		"events_triggered": 0,
		"last_update_tick": -1,
		"world_state": "stable"
	}
