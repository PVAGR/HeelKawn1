extends Node
## Master controller for HeelKawn's 5-layer AI architecture
## Coordinates: Memory, HeelKawnian, Settlement, Diplomacy, Ecosystem AI
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
		"class": "AISettlementManager"
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
				"description": "HeelKawnian fear amplified by ecosystem wildlife boom"
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
	if pawns.is_empty():
		return states
	
	for i in range(min(count, pawns.size())):
		var pawn: Node = pawns[i]
		if pawn == null or not pawn.has_method("get_pawn_data"):
			continue
		var data: Node = pawn.get_pawn_data()
		if data == null:
			continue
		var state_name: String = "unknown"
		if pawn.has_method("get_state_name"):
			state_name = str(pawn.get_state_name())
		states.append({
			"id": data.id,
			"name": data.display_name,
			"hunger": data.hunger,
			"mood": data.mood,
			"rest": data.rest,
			"state": state_name,
			"settlement_id": data.settlement_id,
			"tile": data.tile_pos
		})

	return states


func _get_social_network_summary() -> Dictionary:
	var grudge_manager: Node = get_node_or_null("/root/GrudgeManager")
	var gossip_manager: Node = get_node_or_null("/root/GossipManager")

	var active_gossip: int = 0
	var active_grudges: int = 0

	if gossip_manager != null and gossip_manager.has_method("gossip_count"):
		active_gossip = int(gossip_manager.gossip_count())

	if grudge_manager != null and grudge_manager.has_method("grudge_count"):
		active_grudges = int(grudge_manager.grudge_count())

	return {
		"active_gossip": active_gossip,
		"active_grudges": active_grudges
	}


func _get_all_settlement_states() -> Array:
	var settlement_memory: Node = get_node_or_null("/root/SettlementMemory")
	if settlement_memory == null or not settlement_memory.has_method("get_formal_settlements"):
		return []
	
	var out: Array = []
	for st_any in settlement_memory.get_formal_settlements():
		if st_any is not Dictionary:
			continue
		var st: Dictionary = st_any as Dictionary
		var members: Array = st.get("pawn_refs", [])
		if members.is_empty():
			members = st.get("member_pawn_ids", [])
		out.append({
			"id": int(st.get("center_region", -1)),
			"name": str(st.get("name", st.get("polity_display_name", "Unknown"))),
			"member_count": members.size(),
			"pawn_refs": members,
			"founding_tick": int(st.get("founding_tick", -1)),
			"kind": str(st.get("kind", "formal_settlement")),
			"center_region": int(st.get("center_region", -1))
		})
	return out


func _get_resource_trends() -> Dictionary:
	var stockpile_manager: Node = get_node_or_null("/root/StockpileManager")
	if stockpile_manager == null:
		return {}
	
	# Would analyze stockpile trends over time
	return {"food": "stable", "wood": "increasing", "stone": "stable"}


func _get_settlement_relations() -> Array:
	var settlement_memory: Node = get_node_or_null("/root/SettlementMemory")
	if settlement_memory == null or not settlement_memory.has_method("get_formal_settlements"):
		return []
	
	var settlements: Array = settlement_memory.get_formal_settlements()
	var out: Array = []
	if settlements.size() < 2:
		return out
	
	for a in range(settlements.size()):
		for b in range(a + 1, settlements.size()):
			var sa: Dictionary = settlements[a] as Dictionary
			var sb: Dictionary = settlements[b] as Dictionary
			if not sa is Dictionary or not sb is Dictionary:
				continue
			var a_id: int = int(sa.get("center_region", -1))
			var b_id: int = int(sb.get("center_region", -1))
			if a_id < 0 or b_id < 0:
				continue
			# Count grudges held by members of A against members of B (and vice versa)
			var member_a: Array = sa.get("pawn_refs", [])
			if member_a.is_empty():
				member_a = sa.get("member_pawn_ids", [])
			var member_b: Array = sb.get("pawn_refs", [])
			if member_b.is_empty():
				member_b = sb.get("member_pawn_ids", [])
			var cross_grudges: int = _count_cross_grudges(member_a, member_b)
			var cross_grudges_reverse: int = _count_cross_grudges(member_b, member_a)
			out.append({
				"from_id": a_id,
				"to_id": b_id,
				"from_name": str(sa.get("name", sa.get("polity_display_name", "Unknown"))),
				"to_name": str(sb.get("name", sb.get("polity_display_name", "Unknown"))),
				"grudge_count": cross_grudges + cross_grudges_reverse,
				"power_ratio": _settlement_power_ratio(member_a.size(), member_b.size()),
				"war_history": "none",
				"trade_history": "none",
				"dynastic_ties": "none"
			})
	return out


func _count_cross_grudges(holder_ids: Array, target_ids: Array) -> int:
	if holder_ids.is_empty() or target_ids.is_empty():
		return 0
	var grudge_manager: Node = get_node_or_null("/root/GrudgeManager")
	if grudge_manager == null or not grudge_manager.has_method("get_grudges_held_by"):
		return 0
	var target_set: Dictionary = {}
	for tid in target_ids:
		target_set[int(tid)] = true
	var count: int = 0
	for hid in holder_ids:
		for grudge in grudge_manager.get_grudges_held_by(int(hid)):
			if grudge is Dictionary and target_set.has(int(grudge.get("target_id", -1))):
				count += 1
	return count


func _settlement_power_ratio(pop_a: int, pop_b: int) -> float:
	if pop_b <= 0:
		return 1.0
	return float(pop_a) / float(pop_b)


func _get_active_grudges() -> Array:
	var grudge_manager: Node = get_node_or_null("/root/GrudgeManager")
	if grudge_manager == null or not grudge_manager.has_method("grudge_count"):
		return []
	var pawn_spawner: Node = get_node_or_null("/root/Main/WorldViewport/PawnSpawner")
	if pawn_spawner == null:
		return []
	var out: Array = []
	for pid_any in _sample_living_pawn_ids(grudge_manager, pawn_spawner):
		for grudge in grudge_manager.get_grudges_held_by(int(pid_any)):
			if grudge is Dictionary:
				out.append({
					"holder_id": int(grudge.get("holder_id", -1)),
					"target_id": int(grudge.get("target_id", -1)),
					"type": str(grudge.get("type", "")),
					"intensity": float(grudge.get("intensity", 0.0))
				})
	return out


func _sample_living_pawn_ids(grudge_manager: Node, pawn_spawner: Node) -> Array:
	var out: Array = []
	if grudge_manager.has_method("grudge_count") and grudge_manager.grudge_count() <= 0:
		return out
	var pawns: Array = pawn_spawner.pawns if pawn_spawner.has_method("pawns") else []
	for i in range(min(12, pawns.size())):
		var pawn: Node = pawns[i]
		if pawn != null and pawn.has_method("get_pawn_data"):
			var data: Node = pawn.get_pawn_data()
			if data != null:
				out.append(data.id)
	return out


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
	var grudge_manager: Node = get_node_or_null("/root/SocialManager")
	var gossip_manager: Node = get_node_or_null("/root/SocialManager")
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


func _load_layer_script(layer_name: String) -> GDScript:
	var script_path: String = "res://scripts/ai/" + layer_name + ".gd"

	if not ResourceLoader.exists(script_path):
		push_warning("[AIOrchestrator] Layer script not found: " + script_path)
		return null

	var script: GDScript = load(script_path)
	return script

