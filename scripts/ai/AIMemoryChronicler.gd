extends RefCounted
class_name AIMemoryChronicler

## Layer 1: Dwarf Fortress Spirit - Memory AI
## Chronicles events, writes history, preserves knowledge
##
## Reads from: WorldMemory, SettlementMemory
## Writes to: SettlementLegend, Chronicle logs

var _llm_client: LLMClient = null
var _world_memory: Node = null
var _initialized: bool = false


func initialize(deps: Dictionary) -> void:
	_llm_client = deps.get("llm_client")
	_world_memory = deps.get("world_memory")
	_initialized = true


func evaluate(context: Dictionary) -> Dictionary:
	if not _initialized:
		return {"error": "not_initialized"}
	
	var tick: int = context.get("tick", 0)
	var recent_events: Array = context.get("recent_events", [])
	
	if recent_events.is_empty():
		return {"chronicle_entries": 0, "reason": "no_recent_events"}
	
	# Generate chronicle entry
	var chronicle: String = await _generate_chronicle(recent_events, tick)
	
	# Generate settlement legends
	var legends: Dictionary = await _generate_settlement_legends(context)
	
	# Record to WorldMemory
	if _world_memory != null:
		_world_memory.record_event({
			"type": "ai_chronicle_written",
			"tick": tick,
			"chronicle": chronicle,
			"event_count": recent_events.size()
		})
	
	return {
		"chronicle_entries": 1,
		"legends_generated": legends.size(),
		"chronicle_text": chronicle,
		"legends": legends
	}


func _generate_chronicle(events: Array, tick: int) -> String:
	if events.is_empty():
		return ""
	
	# Build prompt
	var event_summaries: PackedStringArray = []
	for event in events:
		event_summaries.append(_format_event_for_chronicle(event))
	
	var prompt: String = """
Write a Dwarf Fortress-style historical chronicle entry for these events:

YEAR: {year}
EVENTS:
{events}

Style guidelines:
- Dry, factual, historical tone
- Include cause-and-effect relationships
- Mention key participants by name
- Note long-term implications
- Like: "In the Year {year}, a plague swept through Oakhaven, claiming 23 souls..."

Respond with 2-3 paragraphs of historical narrative.
""".format({
		"year": tick / 360,
		"events": "\n".join(event_summaries)
	})
	
	# Request from LLM
	var response: Dictionary = await _llm_client.request(prompt, {
		"tick": tick,
		"event_count": events.size()
	}, "You are a historical chronicler. Write factual, dry historical entries.")
	
	return response.get("content", "No chronicle generated.")


func _generate_settlement_legends(context: Dictionary) -> Dictionary:
	var legends: Dictionary = {}
	
	# Get settlement count
	var settlement_count: int = context.get("active_settlements", 0)
	
	if settlement_count == 0:
		return legends
	
	# For each settlement, generate/update legend
	# This would query SettlementMemory for each settlement's events
	# For now, return placeholder
	
	var prompt: String = """
Write a settlement legend in the style of ancient myths.

CONTEXT:
- Settlements: {settlements}
- Year: {year}

For each settlement, write a 3-4 sentence legend that:
- Explains its founding mythically
- Notes key historical events
- Mentions notable heroes or tragedies
- Ends with the settlement's current state

Style: Epic, mythic, like ancient legends.
""".format({
		"settlements": settlement_count,
		"year": context.get("year", 0)
	})
	
	var response: Dictionary = await _llm_client.request(prompt, context, "You are a mythmaker. Write epic legends.")
	
	legends["general_legend"] = response.get("content", "No legends generated.")
	
	return legends


func _format_event_for_chronicle(event: Dictionary) -> String:
	var event_type: String = event.get("type", "unknown")
	var tick: int = event.get("tick", 0)
	var year: int = tick / 360
	
	match event_type:
		"pawn_death":
			var name: String = event.get("pawn_name", "Unknown")
			var cause: String = event.get("cause", "unknown causes")
			return "Year {year}: {name} died ({cause})".format({"year": year, "name": name, "cause": cause})
		
		"pawn_birth":
			var name: String = event.get("pawn_name", "Unknown")
			return "Year {year}: {name} was born".format({"year": year, "name": name})
		
		"settlement_founded":
			var name: String = event.get("settlement_name", "Unknown")
			return "Year {year}: {name} was founded".format({"year": year, "name": name})
		
		"disaster_started":
			var disaster: String = event.get("disaster_type", "disaster")
			var location: String = event.get("location", "unknown")
			return "Year {year}: {disaster} struck {location}".format({"year": year, "disaster": disaster, "location": location})
		
		_:
			return "Year {year}: {event}".format({"year": year, "event": event_type})


## Get chronicle statistics
func get_stats() -> Dictionary:
	return {
		"initialized": _initialized,
		"last_chronicle_tick": -1,
		"total_chronicles": 0
	}
