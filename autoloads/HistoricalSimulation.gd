extends Node
## Phase 4: Deep Historical Simulation
## World contains ruins, relics, and artifacts from thousands of years of NPC history
## Time depth system, ruin generation, artifact system, myth generation

## Historical time tracking
var historical_ticks: int = 0
var years_elapsed: int = 0
var simulation_speed: int = 1000  # Ticks per historical year (fast-forward)

## Historical events
var historical_events: Array = []  # {tick, type, location, participants, impact, details}
var event_types: Array = ["settlement_founded", "settlement_abandoned", "war", "discovery", "catastrophe", "cultural_shift"]

## Ruins and artifacts
var ruins: Dictionary = {}  # ruin_id -> {location, age, original_settlement, decay_state, artifacts}
var artifacts: Dictionary = {}  # artifact_id -> {type, location, creator, history, power, description}

## Myths and legends
var myths: Dictionary = {}  # myth_id -> {name, origin_event, spread, belief_level, details}
var legends: Dictionary = {}  # legend_id -> {name, hero, deed, reputation, details}

## Civilization tracking
var civilizations: Dictionary = {}  # civ_id -> {name, lifespan, settlements, culture, technology}
var current_civilizations: Array = []

func _ready() -> void:
	GameManager.game_tick.connect(_on_game_tick)


## Run historical simulation for specified years
func simulate_history(years: int) -> void:
	var target_ticks: int = historical_ticks + (years * simulation_speed)
	
	while historical_ticks < target_ticks:
		_simulate_tick()
		historical_ticks += 1
	
	years_elapsed += years
	print("[HistoricalSimulation] Simulated %d years of history. Total: %d years" % [years, years_elapsed])


## Simulate a single historical tick
func _simulate_tick() -> void:
	# Random events based on probability
	if WorldRNG.range_for(StringName("hist:event:%d" % historical_ticks), 0.0, 1.0) < 0.01:
		_generate_historical_event()
	
	# Decay ruins
	_decay_ruins()
	
	# Spread myths
	_spread_myths()
	
	# Civilization evolution
	_evolve_civilizations()


## Generate a historical event
func _generate_historical_event() -> void:
	var event_type: String = event_types[WorldRNG.rangei(0, event_types.size() - 1)]
	var location: Vector2i = Vector2i(
		WorldRNG.rangei(0, 1000),
		WorldRNG.rangei(0, 1000)
	)
	
	var event_id: String = "%s_%d" % [event_type, historical_ticks]
	var impact: float = WorldRNG.range_for(StringName("hist:impact:%d" % historical_ticks), 0.0, 1.0)
	
	var event_data: Dictionary = {
		"tick": historical_ticks,
		"type": event_type,
		"location": location,
		"participants": [],
		"impact": impact,
		"details": {}
	}
	
	match event_type:
		"settlement_founded":
			_foundation_event(event_data)
		"settlement_abandoned":
			_abandonment_event(event_data)
		"war":
			_war_event(event_data)
		"discovery":
			_discovery_event(event_data)
		"catastrophe":
			_catastrophe_event(event_data)
		"cultural_shift":
			_cultural_shift_event(event_data)
	
	historical_events.append(event_data)
	
	# Generate myth from significant events
	if impact > 0.7:
		_generate_myth_from_event(event_data)


## Settlement foundation event
func _foundation_event(event: Dictionary) -> void:
	var settlement_name: String = _generate_settlement_name()
	var civ_id: String = _get_or_create_civilization()
	
	event.details = {
		"settlement_name": settlement_name,
		"civ_id": civ_id,
		"population": WorldRNG.rangei(10, 100),
		"prosperity": WorldRNG.range_for(StringName("hist:prosperity:%d" % historical_ticks), 0.0, 1.0)
	}
	
	# Track settlement in civilization
	if civilizations.has(civ_id):
		civilizations[civ_id].settlements.append(settlement_name)


## Settlement abandonment event
func _abandonment_event(event: Dictionary) -> void:
	var settlement_name: String = _get_random_settlement_name()
	
	if settlement_name.is_empty():
		return
	
	event.details = {
		"settlement_name": settlement_name,
		"reason": _get_abandonment_reason(),
		"remaining_artifacts": WorldRNG.rangei(1, 10)
	}
	
	# Create ruin
	_create_ruin(event.location, settlement_name, event.details.reason)


## War event
func _war_event(event: Dictionary) -> void:
	var civ1: String = _get_random_civilization()
	var civ2: String = _get_random_civilization()
	
	if civ1 == civ2 or civ1.is_empty() or civ2.is_empty():
		return
	
	event.details = {
		"attacker": civ1,
		"defender": civ2,
		"casualties": WorldRNG.rangei(10, 1000),
		"outcome": "victory" if WorldRNG.range_for(StringName("hist:war:%d" % historical_ticks), 0.0, 1.0) > 0.5 else "defeat"
	}
	
	# Generate artifacts from war
	if event.details.casualties > 100:
		_create_war_artifact(event.location, civ1, civ2)


## Discovery event
func _discovery_event(event: Dictionary) -> void:
	var discovery_types: Array = ["resource", "technology", "land", "ancient_relic"]
	var discovery_type: String = discovery_types[WorldRNG.rangei(0, discovery_types.size() - 1)]
	
	event.details = {
		"discovery_type": discovery_type,
		"value": WorldRNG.range_for(StringName("hist:discovery:%d" % historical_ticks), 0.0, 1.0),
		"discoverer": _generate_name()
	}
	
	if discovery_type == "ancient_relic":
		_create_relic_artifact(event.location, event.details.discoverer)


## Catastrophe event
func _catastrophe_event(event: Dictionary) -> void:
	var catastrophe_types: Array = ["plague", "flood", "earthquake", "volcanic_eruption", "drought"]
	var catastrophe_type: String = catastrophe_types[WorldRNG.rangei(0, catastrophe_types.size() - 1)]
	
	event.details = {
		"catastrophe_type": catastrophe_type,
		"severity": WorldRNG.range_for(StringName("hist:catastrophe:%d" % historical_ticks), 0.5, 1.0),
		"affected_settlements": WorldRNG.rangei(1, 5)
	}
	
	# Destroy settlements
	for i in range(event.details.affected_settlements):
		var settlement: String = _get_random_settlement_name()
		if not settlement.is_empty():
			_create_ruin(event.location + Vector2i(WorldRNG.rangei(-10, 10), WorldRNG.rangei(-10, 10)), settlement, catastrophe_type)


## Cultural shift event
func _cultural_shift_event(event: Dictionary) -> void:
	var shift_types: Array = ["religious", "technological", "artistic", "political"]
	var shift_type: String = shift_types[WorldRNG.rangei(0, shift_types.size() - 1)]
	
	event.details = {
		"shift_type": shift_type,
		"from": _generate_cultural_aspect(),
		"to": _generate_cultural_aspect(),
		"civ_id": _get_random_civilization()
	}


## Create a ruin at location
func _create_ruin(location: Vector2i, original_settlement: String, reason: String) -> void:
	var ruin_id: String = "ruin_%d_%d" % [location.x, location.y]
	
	ruins[ruin_id] = {
		"location": location,
		"age": 0,
		"original_settlement": original_settlement,
		"reason": reason,
		"decay_state": 0.0,  # 0-1, higher = more decayed
		"artifacts": [],
		"buildings_remaining": WorldRNG.rangei(1, 10)
	}
	
	# Generate artifacts for the ruin
	var artifact_count: int = WorldRNG.rangei(1, 5)
	for i in range(artifact_count):
		var artifact_id: String = _generate_artifact_id()
		var artifact: Dictionary = _generate_artifact(location, original_settlement)
		artifacts[artifact_id] = artifact
		ruins[ruin_id].artifacts.append(artifact_id)


## Decay ruins over time
func _decay_ruins() -> void:
	for ruin_id in ruins:
		var ruin = ruins[ruin_id]
		ruin.age += 1
		
		# Decay based on age
		var decay_rate: float = 0.0001  # Very slow decay
		ruin.decay_state = clamp(ruin.decay_state + decay_rate, 0.0, 1.0)
		
		# Buildings collapse over time
		if ruin.age > 1000 and WorldRNG.range_for(StringName("hist:ruin_decay:%s" % ruin_id), 0.0, 1.0) < 0.01:
			if ruin.buildings_remaining > 0:
				ruin.buildings_remaining -= 1


## Generate artifact
func _generate_artifact(location: Vector2i, creator: String) -> Dictionary:
	var artifact_types: Array = ["tool", "weapon", "jewelry", "writing", "relic", "pottery"]
	var artifact_type: String = artifact_types[WorldRNG.rangei(0, artifact_types.size() - 1)]
	
	return {
		"type": artifact_type,
		"location": location,
		"creator": creator,
		"created_tick": historical_ticks,
		"history": [],
		"power": WorldRNG.range_for(StringName("hist:artifact_power:%d" % historical_ticks), 0.0, 1.0),
		"description": _generate_artifact_description(artifact_type, creator),
		"condition": 1.0
	}


## Generate war artifact
func _create_war_artifact(location: Vector2i, attacker: String, defender: String) -> void:
	var artifact_id: String = _generate_artifact_id()
	var artifact: Dictionary = {
		"type": "weapon",
		"location": location,
		"creator": attacker,
		"created_tick": historical_ticks,
		"history": ["Used in war against %s" % defender],
		"power": WorldRNG.range_for(StringName("hist:war_art:%d" % historical_ticks), 0.5, 1.0),
		"description": "A weapon forged during the %s-%s conflict" % [attacker, defender],
		"condition": WorldRNG.range_for(StringName("hist:war_cond:%d" % historical_ticks), 0.3, 0.8)
	}
	artifacts[artifact_id] = artifact


## Generate relic artifact
func _create_relic_artifact(location: Vector2i, discoverer: String) -> void:
	var artifact_id: String = _generate_artifact_id()
	var artifact: Dictionary = {
		"type": "relic",
		"location": location,
		"creator": "unknown",
		"created_tick": historical_ticks - WorldRNG.rangei(100, 10000),
		"history": ["Ancient artifact of unknown origin"],
		"power": WorldRNG.range_for(StringName("hist:relic_power:%d" % historical_ticks), 0.7, 1.0),
		"description": "An ancient relic radiating mysterious power",
		"condition": WorldRNG.range_for(StringName("hist:relic_cond:%d" % historical_ticks), 0.2, 0.6)
	}
	artifacts[artifact_id] = artifact


## Generate myth from event
func _generate_myth_from_event(event: Dictionary) -> void:
	var myth_id: String = "myth_%d" % historical_ticks
	var myth_name: String = _generate_myth_name(event.type)
	
	myths[myth_id] = {
		"name": myth_name,
		"origin_event": event,
		"spread": 0.0,
		"belief_level": WorldRNG.range_for(StringName("hist:myth_belief:%d" % historical_ticks), 0.3, 0.8),
		"details": _generate_myth_details(event)
	}


## Spread myths over time
func _spread_myths() -> void:
	for myth_id in myths:
		var myth = myths[myth_id]
		if myth.spread < 1.0:
			myth.spread += 0.0001  # Slow spread
			myth.spread = clamp(myth.spread, 0.0, 1.0)


## Get or create civilization
func _get_or_create_civilization() -> String:
	if civilizations.is_empty() or WorldRNG.range_for(StringName("hist:new_civ:%d" % historical_ticks), 0.0, 1.0) < 0.1:
		var civ_id: String = "civ_%d" % civilizations.size()
		civilizations[civ_id] = {
			"name": _generate_civilization_name(),
			"lifespan": 0,
			"settlements": [],
			"culture": _generate_cultural_aspect(),
			"technology": WorldRNG.range_for(StringName("hist:civ_tech:%d" % historical_ticks), 0.0, 1.0)
		}
		current_civilizations.append(civ_id)
		return civ_id
	
	return current_civilizations[WorldRNG.rangei(0, current_civilizations.size() - 1)]


## Evolve civilizations
func _evolve_civilizations() -> void:
	for civ_id in civilizations:
		var civ = civilizations[civ_id]
		civ.lifespan += 1
		
		# Technology advances slowly
		if WorldRNG.range_for(StringName("hist:civ_adv:%s" % civ_id), 0.0, 1.0) < 0.001:
			civ.technology = clamp(civ.technology + 0.01, 0.0, 1.0)
		
		# Civilization collapse
		if civ.lifespan > 5000 and WorldRNG.range_for(StringName("hist:civ_collapse:%s" % civ_id), 0.0, 1.0) < 0.0001:
			_collapse_civilization(civ_id)


## Collapse civilization
func _collapse_civilization(civ_id: String) -> void:
	if not civilizations.has(civ_id):
		return
	
	var civ = civilizations[civ_id]
	
	# Abandon all settlements
	for settlement in civ.settlements:
		var location: Vector2i = Vector2i(WorldRNG.rangei(0, 1000), WorldRNG.rangei(0, 1000))
		_create_ruin(location, settlement, "civilization_collapse")
	
	# Remove from current civilizations
	current_civilizations.erase(civ_id)


## Helper: Generate random name
func _generate_name() -> String:
	var syllables: Array = ["ar", "ba", "ca", "da", "el", "fa", "ga", "ha", "il", "ja", "ka", "la", "ma", "na", "or", "pa", "ra", "sa", "ta", "ul", "va", "wa", "xa", "ya", "za"]
	var name: String = ""
	var num_syllables: int = WorldRNG.rangei(2, 4)
	
	for i in range(num_syllables):
		name += syllables[WorldRNG.rangei(0, syllables.size() - 1)]
	
	return name.capitalize()


## Helper: Generate settlement name
func _generate_settlement_name() -> String:
	var prefixes: Array = ["New", "Old", "Great", "Little", "High", "Low", "East", "West", "North", "South"]
	var suffixes: Array = ["ton", "burg", "ford", "ham", "ville", "port", "haven", "dale", "wood", "field"]
	
	return "%s%s%s" % [prefixes[WorldRNG.rangei(0, prefixes.size() - 1)], _generate_name(), suffixes[WorldRNG.rangei(0, suffixes.size() - 1)]]


## Helper: Generate civilization name
func _generate_civilization_name() -> String:
	var adjectives: Array = ["Ancient", "Golden", "Silver", "Mighty", "Wise", "Noble", "Proud", "Eternal"]
	var nouns: Array = ["Empire", "Kingdom", "Republic", "Federation", "Alliance", "Confederacy", "Dynasty"]
	
	return "%s %s of %s" % [adjectives[WorldRNG.rangei(0, adjectives.size() - 1)], nouns[WorldRNG.rangei(0, nouns.size() - 1)], _generate_name()]


## Helper: Generate myth name
func _generate_myth_name(event_type: String) -> String:
	match event_type:
		"settlement_founded":
			return "The Founding of %s" % _generate_name()
		"war":
			return "The Great %s War" % _generate_name()
		"discovery":
			return "The Discovery of %s" % _generate_name()
		"catastrophe":
			return "The %s Catastrophe" % _generate_name()
		_:
			return "The Legend of %s" % _generate_name()


## Helper: Generate myth details
func _generate_myth_details(event: Dictionary) -> String:
	return "A tale passed down through generations about %s" % event.type


## Helper: Generate cultural aspect
func _generate_cultural_aspect() -> String:
	var aspects: Array = ["honor", "wisdom", "courage", "piety", "craftsmanship", "trade", "warfare", "agriculture"]
	return aspects[WorldRNG.rangei(0, aspects.size() - 1)]


## Helper: Generate artifact description
func _generate_artifact_description(artifact_type: String, creator: String) -> String:
	match artifact_type:
		"tool":
			return "A well-crafted tool made by %s" % creator
		"weapon":
			return "A formidable weapon forged by %s" % creator
		"jewelry":
			return "Beautiful jewelry crafted by %s" % creator
		"writing":
			return "Ancient writings from the time of %s" % creator
		"relic":
			return "A mysterious relic with unknown powers"
		"pottery":
			return "Pottery made by %s" % creator
		_:
			return "An artifact from %s" % creator


## Helper: Generate artifact ID
func _generate_artifact_id() -> String:
	return "artifact_%d" % artifacts.size()


## Helper: Get random settlement name
func _get_random_settlement_name() -> String:
	if civilizations.is_empty():
		return ""
	
	var civ_id: String = current_civilizations[WorldRNG.rangei(0, current_civilizations.size() - 1)]
	if not civilizations.has(civ_id):
		return ""
	
	var civ = civilizations[civ_id]
	if civ.settlements.is_empty():
		return ""
	
	return civ.settlements[WorldRNG.rangei(0, civ.settlements.size() - 1)]


## Helper: Get random civilization
func _get_random_civilization() -> String:
	if current_civilizations.is_empty():
		return ""
	return current_civilizations[WorldRNG.rangei(0, current_civilizations.size() - 1)]


## Helper: Get abandonment reason
func _get_abandonment_reason() -> String:
	var reasons: Array = ["resource_depletion", "war", "disease", "natural_disaster", "migration", "political_collapse"]
	return reasons[WorldRNG.rangei(0, reasons.size() - 1)]


## Get ruins at or near location
func get_ruins_nearby(location: Vector2i, radius: int) -> Array:
	var nearby: Array = []
	
	for ruin_id in ruins:
		var ruin = ruins[ruin_id]
		var distance: int = ruin.location.distance_to(location)
		if distance <= radius:
			nearby.append({
				"ruin_id": ruin_id,
				"ruin": ruin
			})
	
	return nearby


## Get artifacts at or near location
func get_artifacts_nearby(location: Vector2i, radius: int) -> Array:
	var nearby: Array = []
	
	for artifact_id in artifacts:
		var artifact = artifacts[artifact_id]
		var distance: int = artifact.location.distance_to(location)
		if distance <= radius:
			nearby.append({
				"artifact_id": artifact_id,
				"artifact": artifact
			})
	
	return nearby


## Get myths with high belief level
func get_prominent_myths(min_belief: float = 0.5) -> Array:
	var prominent: Array = []
	
	for myth_id in myths:
		var myth = myths[myth_id]
		if myth.belief_level >= min_belief:
			prominent.append({
				"myth_id": myth_id,
				"myth": myth
			})
	
	return prominent


## Get historical events by type
func get_events_by_type(event_type: String, limit: int = 10) -> Array:
	var filtered: Array = []
	
	for event in historical_events:
		if event.type == event_type:
			filtered.append(event)
			if filtered.size() >= limit:
				break
	
	return filtered


## Game tick handler
func _on_game_tick(tick: int) -> void:
	# Historical simulation runs in fast-forward mode, not during normal gameplay
	pass


## Save historical state
func to_dict() -> Dictionary:
	return {
		"historical_ticks": historical_ticks,
		"years_elapsed": years_elapsed,
		"historical_events": historical_events,
		"ruins": ruins,
		"artifacts": artifacts,
		"myths": myths,
		"civilizations": civilizations,
		"current_civilizations": current_civilizations
	}


## Load historical state
func from_dict(data: Dictionary) -> void:
	historical_ticks = data.get("historical_ticks", 0)
	years_elapsed = data.get("years_elapsed", 0)
	historical_events = data.get("historical_events", [])
	ruins = data.get("ruins", {})
	artifacts = data.get("artifacts", {})
	myths = data.get("myths", {})
	civilizations = data.get("civilizations", {})
	current_civilizations = data.get("current_civilizations", [])
