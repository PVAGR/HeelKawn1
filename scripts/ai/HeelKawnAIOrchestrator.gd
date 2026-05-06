extends Node
class_name HeelKawnAIOrchestrator

## Master controller for HeelKawn's 5-layer AI architecture
## Coordinates: Memory, Pawn, Settlement, Diplomacy, Ecosystem AI
##
## Usage:
##   HeelKawnAIOrchestrator.initialize()
##   (Automatically manages layer updates on staggered intervals)

# AI Layer instances
var layers: Dictionary = {}

# Layer configuration
const LAYER_CONFIG: Dictionary = {
	"memory": {
		"interval": 500,  # ticks
		"priority": 3,
		"enabled": true,
		"class": "AIMemoryChronicler"
	},
	"pawn": {
		"interval": 60,
		"priority": 1,
		"enabled": true,
		"class": "AIPawnPsychologist"
	},
	"settlement": {
		"interval": 120,
		"priority": 2,
		"enabled": true,
		"class": "AISettlementPlanner"
	},
	"diplomacy": {
		"interval": 300,
		"priority": 2,
		"enabled": true,
		"class": "AIDiplomacyDirector"
	},
	"ecosystem": {
		"interval": 600,
		"priority": 3,
		"enabled": true,
		"class": "AIWorldEcosystem"
	}
}

# Performance configuration
var config: Dictionary = {
	"max_concurrent_requests": 2,  # Max LLM requests per frame
	"use_mock_llm": true,  # Use mock responses for testing
	"enable_cross_layer_narratives": true,  # Allow layers to influence each other
	"log_ai_decisions": true  # Log AI decisions to WorldMemory
}

# State tracking
var _tick_counters: Dictionary = {}
var _active_requests: int = 0
var _layer_narratives: Dictionary = {}  # Cross-layer narrative state

# References
var _llm_client: LLMClient = null
var _world_memory: Node = null

# Signals
signal layer_completed(layer_name: String, output: Dictionary)
signal layer_failed(layer_name: String, error: String)
signal cross_layer_narrative_created(narrative: Dictionary)


func _ready() -> void:
	# Get references
	_llm_client = get_node_or_null("/root/LLMClient")
	if _llm_client == null:
		_llm_client = LLMClient.new()
		add_child(_llm_client)
	
	_world_memory = get_node_or_null("/root/WorldMemory")
	
	# Initialize layers
	_initialize_layers()
	
	# Connect to game tick
	if GameManager != null:
		GameManager.game_tick.connect(_on_game_tick)


func _on_game_tick(tick: int) -> void:
	# Update each layer on its interval
	for layer_name in LAYER_CONFIG:
		if not LAYER_CONFIG[layer_name].enabled:
			continue
		
		# Initialize counter
		if not _tick_counters.has(layer_name):
			_tick_counters[layer_name] = 0
		
		_tick_counters[layer_name] += 1
		
		# Check if layer should update
		var interval: int = LAYER_CONFIG[layer_name].interval
		if _tick_counters[layer_name] >= interval:
			_tick_counters[layer_name] = 0
			_queue_layer_update(layer_name, tick)


func _queue_layer_update(layer_name: String, tick: int) -> void:
	if _active_requests >= config.max_concurrent_requests:
		return  # Rate limit
	
	var layer: Object = layers.get(layer_name)
	if layer == null or not layer.has_method("evaluate"):
		return
	
	_active_requests += 1
	
	# Call layer's evaluate method
	var context: Dictionary = _build_layer_context(layer_name, tick)
	var output: Dictionary = await layer.evaluate(context)
	
	_active_requests -= 1
	
	# Handle output
	if output.has("error"):
		layer_failed.emit(layer_name, output.error)
	else:
		_process_layer_output(layer_name, output, tick)
		layer_completed.emit(layer_name, output)


func _process_layer_output(layer_name: String, output: Dictionary, tick: int) -> void:
	# Store for cross-layer narratives
	_layer_narratives[layer_name] = {
		"tick": tick,
		"output": output
	}
	
	# Log to WorldMemory if enabled
	if config.log_ai_decisions and _world_memory != null:
		_world_memory.record_event({
			"type": "ai_layer_decision",
			"layer": layer_name,
			"tick": tick,
			"decision": output
		})
	
	# Check for cross-layer narrative opportunities
	if config.enable_cross_layer_narratives:
		_check_cross_layer_narratives(tick)


func _check_cross_layer_narratives(tick: int) -> void:
	# Look for interesting combinations across layers
	# Example: Settlement expansion + Diplomacy war = "War-driven expansion"
	
	var narratives: Array[Dictionary] = []
	
	# Check for settlement + diplomacy combinations
	if _layer_narratives.has("settlement") and _layer_narratives.has("diplomacy"):
		var settlement_output: Dictionary = _layer_narratives["settlement"].output
		var diplomacy_output: Dictionary = _layer_narratives["diplomacy"].output
		
		if settlement_output.get("action") == "expand_territory" and \
		   diplomacy_output.get("action") == "DECLARE_WAR":
			narratives.append({
				"type": "war_driven_expansion",
				"layers": ["settlement", "diplomacy"],
				"tick": tick,
				"description": "Settlement expansion fueled by diplomatic conflict"
			})
	
	# Check for pawn + ecosystem combinations
	if _layer_narratives.has("pawn") and _layer_narratives.has("ecosystem"):
		var pawn_output: Dictionary = _layer_narratives["pawn"].output
		var ecosystem_output: Dictionary = _layer_narratives["ecosystem"].output
		
		if pawn_output.get("fear") == "wildlife" and \
		   ecosystem_output.get("event") == "wildlife_boom":
			narratives.append({
				"type": "wildlife_threat",
				"layers": ["pawn", "ecosystem"],
				"tick": tick,
				"description": "Pawn fear amplified by ecosystem wildlife boom"
			})
	
	# Emit cross-layer narratives
	for narrative in narratives:
		cross_layer_narrative_created.emit(narrative)


func _build_layer_context(layer_name: String, tick: int) -> Dictionary:
	var context: Dictionary = {
		"tick": tick,
		"year": tick / 360,
		"layer": layer_name
	}
	
	# Add layer-specific context
	match layer_name:
		"memory":
			context.recent_events = _get_recent_events(10)
			context.active_settlements = _get_settlement_count()
		
		"pawn":
			context.sample_pawns = _get_sample_pawn_states(5)
			context.social_network = _get_social_network_summary()
		
		"settlement":
			context.settlements = _get_all_settlement_states()
			context.resource_trends = _get_resource_trends()
		
		"diplomacy":
			context.settlement_relations = _get_settlement_relations()
			context.active_grudges = _get_active_grudges()

		"ecosystem":
			context.wildlife_pops = _get_wildlife_populations()
			context.disaster_risks = _get_disaster_risk_assessment()
	
	# Add cross-layer context
	context.cross_layer_narratives = _layer_narratives.duplicate()
	
	return context


# ==================== CONTEXT BUILDING HELPERS ====================

func _get_recent_events(count: int) -> Array:
	if _world_memory == null or not _world_memory.has_method("get_recent_events"):
		return []
	return _world_memory.get_recent_events(count)


func _get_settlement_count() -> int:
	var settlement_memory: Node = get_node_or_null("/root/SettlementMemory")
	if settlement_memory == null or not settlement_memory.has_method("get_settlements"):
		return 0
	var settlements: Array = settlement_memory.get_settlements()
	return settlements.size()


func _get_sample_pawn_states(count: int) -> Array:
	var pawn_spawner: Node = get_node_or_null("/root/Main/WorldViewport/PawnSpawner")
	if pawn_spawner == null or not pawn_spawner.has_method("pawns"):
		return []
	
	var states: Array = []
	var pawns: Array = pawn_spawner.pawns
	
	for i in range(min(count, pawns.size())):
		var pawn: Node = pawns[i]
		if pawn != null and pawn.has_method("get_pawn_data"):
			var data: Node = pawn.get_pawn_data()
			if data != null:
				states.append({
					"id": data.id,
					"name": data.display_name,
					"hunger": data.hunger,
					"mood": data.mood,
					"state": pawn.get("state", "unknown") if pawn.has_method("get_state_name") else "unknown"
				})
	
	return states


func _get_social_network_summary() -> Dictionary:
	var gossip_manager: Node = get_node_or_null("/root/GossipManager")
	var grudge_manager: Node = get_node_or_null("/root/GrudgeManager")
	
	return {
		"active_gossip": gossip_manager.get_stats().get("total_gossip", 0) if gossip_manager != null else 0,
		"active_grudges": grudge_manager.get_stats().get("total_grudges", 0) if grudge_manager != null else 0
	}


func _get_all_settlement_states() -> Array:
	var settlement_memory: Node = get_node_or_null("/root/SettlementMemory")
	if settlement_memory == null:
		return []
	
	# This would call settlement_memory.get_all_settlement_states()
	# For now, return empty array
	return []


func _get_resource_trends() -> Dictionary:
	var stockpile_manager: Node = get_node_or_null("/root/StockpileManager")
	if stockpile_manager == null:
		return {}
	
	# Would analyze stockpile trends over time
	return {"food": "stable", "wood": "increasing", "stone": "stable"}


func _get_settlement_relations() -> Array:
	var grudge_manager: Node = get_node_or_null("/root/GrudgeManager")
	if grudge_manager == null:
		return []
	
	# Would return inter-settlement relation summary
	return []


func _get_active_grudges() -> Array:
	var grudge_manager: Node = get_node_or_null("/root/GrudgeManager")
	if grudge_manager == null:
		return []
	
	# Would return active grudges
	return []


func _get_wildlife_populations() -> Array:
	var wildlife: Node = get_node_or_null("/root/WildlifePopulation")
	if wildlife == null:
		return []
	
	if wildlife.has_method("get_stats"):
		return [wildlife.get_stats()]
	return []


func _get_disaster_risk_assessment() -> Dictionary:
	var disaster_system: Node = get_node_or_null("/root/DisasterSystem")
	if disaster_system == null:
		return {}
	
	# Would return disaster risk assessment
	return {"fire": "low", "plague": "low", "famine": "low"}


# ==================== PUBLIC API ====================

## Initialize all AI layers
func initialize_layers() -> void:
	_initialize_layers()


## Enable or disable a specific layer
func set_layer_enabled(layer_name: String, enabled: bool) -> void:
	if LAYER_CONFIG.has(layer_name):
		LAYER_CONFIG[layer_name].enabled = enabled


## Get layer status
func get_layer_status(layer_name: String) -> Dictionary:
	if not LAYER_CONFIG.has(layer_name):
		return {"error": "unknown_layer"}
	
	return {
		"enabled": LAYER_CONFIG[layer_name].enabled,
		"interval": LAYER_CONFIG[layer_name].interval,
		"last_update": _tick_counters.get(layer_name, 0),
		"active": layers.has(layer_name)
	}


## Get orchestrator statistics
func get_stats() -> Dictionary:
	return {
		"active_requests": _active_requests,
		"layers_enabled": LAYER_CONFIG.values().filter(func(v): return v.enabled).size(),
		"total_layers": LAYER_CONFIG.size(),
		"cross_layer_narratives": _layer_narratives.size()
	}


## Reset all layer counters
func reset_counters() -> void:
	_tick_counters.clear()
	_layer_narratives.clear()


# ==================== INTERNAL ====================

func _initialize_layers() -> void:
	# Get shared references
	var grudge_manager: Node = get_node_or_null("/root/GrudgeManager")
	var gossip_manager: Node = get_node_or_null("/root/GossipManager")
	var settlement_memory: Node = get_node_or_null("/root/SettlementMemory")
	var stockpile_manager: Node = get_node_or_null("/root/StockpileManager")
	var wildlife_population: Node = get_node_or_null("/root/WildlifePopulation")
	var disaster_system: Node = get_node_or_null("/root/DisasterSystem")
	
	# Create layer instances
	for layer_name in LAYER_CONFIG:
		var layer_class_name: String = LAYER_CONFIG[layer_name].class
		var layer_script: GDScript = _load_layer_script(layer_class_name)

		if layer_script != null:
			var layer_instance: Object = layer_script.new()
			layers[layer_name] = layer_instance

			# Initialize layer with references
			if layer_instance.has_method("initialize"):
				var deps: Dictionary = {
					"llm_client": _llm_client,
					"world_memory": _world_memory,
					"orchestrator": self,
					"grudge_manager": grudge_manager,
					"gossip_manager": gossip_manager,
					"settlement_memory": settlement_memory,
					"stockpile_manager": stockpile_manager,
					"wildlife_population": wildlife_population,
					"disaster_system": disaster_system
				}
				layer_instance.initialize(deps)


func _load_layer_script(class_name: String) -> GDScript:
	var script_path: String = "res://scripts/ai/" + class_name + ".gd"

	if not ResourceLoader.exists(script_path):
		push_warning("[AIOrchestrator] Layer script not found: " + script_path)
		return null

	var script: GDScript = load(script_path)
	return script
