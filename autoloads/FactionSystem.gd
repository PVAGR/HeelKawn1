extends Node
## FactionSystem - Inter-settlement diplomacy and alliances
##
## Factions form between settlements based on:
## - Trade relationships
## - Shared knowledge
## - Mutual defense
## - Cultural similarity
##
## Relations can be:
## - Allied (trade bonuses, defense pacts)
## - Friendly (open borders, trade)
## - Neutral (no interaction)
## - Hostile (trade embargoes)
## - At War (raids, battles)

# Faction relationship data
## {
##   "faction_id": int,
##   "settlement_a": int,  # center_region
##   "settlement_b": int,
##   "relation": String,  # "allied", "friendly", "neutral", "hostile", "war"
##   "trade_value": int,  # Total trade value (increases relation)
##   "knowledge_shared": int,  # Knowledge types shared
##   "defense_pacts": int,  # Number of defense agreements
##   "conflicts": int,  # Number of conflicts
##   "formed_tick": int,
##   "last_update_tick": int
## }
var factions: Array[Dictionary] = []
var _next_faction_id: int = 1

# Relation thresholds - BALANCED FOR MEANINGFUL DIPLOMACY (Option C)
const RELATION_ALLIED: int = 75  # (REDUCED from 80 - easier to achieve alliance)
const RELATION_FRIENDLY: int = 40  # (REDUCED from 50 - more friendly settlements)
const RELATION_NEUTRAL: int = 15  # (REDUCED from 20 - easier to make friends)
const RELATION_HOSTILE: int = -15  # (REDUCED magnitude - harder to become hostile)
# Below -15 = war

# Configuration - BALANCED FOR ENGAGEMENT (Option C)
const FACTION_CHECK_INTERVAL: int = 1500  # Check every 1500 ticks (REDUCED from 2000 - faster diplomacy)
const TRADE_RELATION_BONUS: int = 2  # +2 relation per 10 trade value (DOUBLED from 1 - trade matters more)
const KNOWLEDGE_RELATION_BONUS: int = 8  # +8 per knowledge type shared (INCREASED from 5 - knowledge is valuable)
const CONFLICT_RELATION_PENALTY: int = -12  # -12 per conflict (REDUCED magnitude from -15 - wars less common)
const NATURAL_RELATION_DECAY: int = 0  # NO decay (CHANGED from -1 - relations persist, less micromanagement)
const MAX_RELATION: int = 100
const MIN_RELATION: int = -100

# References
@onready var _settlement_memory: Node = null
@onready var _trade_memory: Node = null
@onready var _knowledge_system: Node = null
@onready var _world_memory: Node = null


func _ready() -> void:
	GameManager.game_tick.connect(_on_game_tick)
	_settlement_memory = get_node_or_null("/root/SettlementMemory")
	_trade_memory = EconomyManager.get_trade_memory()
	_knowledge_system = get_node_or_null("/root/KnowledgeSystem")
	_world_memory = get_node_or_null("/root/WorldMemory")


func _on_game_tick(tick: int) -> void:
	_prune_stale_factions()
	# Update faction relations periodically
	if tick % FACTION_CHECK_INTERVAL == 0:
		_update_faction_relations(tick)
	
	# Check for new faction opportunities
	if tick % (FACTION_CHECK_INTERVAL * 2) == 0:
		_try_form_new_factions(tick)


func sync_from_settlements() -> void:
	_prune_stale_factions()


func _current_formal_settlement_centers() -> Dictionary:
	var centers: Dictionary = {}
	if _settlement_memory == null or not _settlement_memory.has_method("get_formal_settlements"):
		return centers
	for st_any in _settlement_memory.get_formal_settlements():
		if not (st_any is Dictionary):
			continue
		var st: Dictionary = st_any as Dictionary
		var center: int = int(st.get("center_region", -1))
		if center >= 0:
			centers[center] = true
	return centers


func _prune_stale_factions() -> void:
	if _settlement_memory == null or not _settlement_memory.has_method("get_formal_settlements"):
		return
	var formal_centers: Dictionary = _current_formal_settlement_centers()
	if formal_centers.is_empty():
		if not factions.is_empty():
			factions.clear()
		return
	var kept: Array[Dictionary] = []
	var changed: bool = false
	for faction_any in factions:
		if not (faction_any is Dictionary):
			changed = true
			continue
		var faction: Dictionary = faction_any as Dictionary
		var settlement_a: int = int(faction.get("settlement_a", -1))
		var settlement_b: int = int(faction.get("settlement_b", -1))
		if settlement_a < 0 or settlement_b < 0:
			changed = true
			continue
		if not formal_centers.has(settlement_a) or not formal_centers.has(settlement_b):
			changed = true
			continue
		kept.append(faction)
	if changed:
		factions = kept


func _update_faction_relations(tick: int) -> void:
	for faction in factions:
		# Calculate relation changes
		var relation_change: int = 0
		
		# Trade bonus
		var trade_value: int = faction.trade_value
		relation_change += trade_value / 10 * TRADE_RELATION_BONUS
		
		# Knowledge sharing bonus
		var knowledge_shared: int = faction.knowledge_shared
		relation_change += knowledge_shared * KNOWLEDGE_RELATION_BONUS
		
		# Conflict penalty
		var conflicts: int = faction.conflicts
		relation_change += conflicts * CONFLICT_RELATION_PENALTY
		
		# Natural decay toward neutral
		if faction.relation != "neutral":
			relation_change += NATURAL_RELATION_DECAY
		
		# Apply relation change
		var current_relation: int = _relation_to_number(faction.relation)
		var new_relation: int = clampi(current_relation + relation_change, MIN_RELATION, MAX_RELATION)
		
		# Update relation string
		faction.relation = _number_to_relation(new_relation)
		faction.last_update_tick = tick
		
		# Record relation change event
		if _world_memory != null:
			_world_memory.record_event({
				"type": "faction_relation_changed",
				"settlement_a": faction.settlement_a,
				"settlement_b": faction.settlement_b,
				"new_relation": faction.relation,
				"trade_value": trade_value,
				"knowledge_shared": knowledge_shared,
				"conflicts": conflicts,
				"tick": tick
			})


func _try_form_new_factions(tick: int) -> void:
	if _settlement_memory == null or _settlement_memory.settlements.is_empty():
		return
	
	# Get all active settlements (formal only, no proto-sites)
	var active_settlements: Array = []
	var formal_settlements: Array = _settlement_memory.get_formal_settlements() if _settlement_memory.has_method("get_formal_settlements") else []
	for st in formal_settlements:
		if st is Dictionary:
			var state: String = str(st.get("state", ""))
			if state == "active" or state == "revivable":
				var center: int = int(st.get("center_region", -1))
				if center >= 0:
					active_settlements.append(center)
	
	# Need at least 2 settlements
	if active_settlements.size() < 2:
		return
	
	# Try to form factions between settlements
	for i in range(active_settlements.size()):
		for j in range(i + 1, active_settlements.size()):
			var settlement_a: int = active_settlements[i]
			var settlement_b: int = active_settlements[j]
			
			# Check if faction already exists
			if _faction_exists(settlement_a, settlement_b):
				continue
			
			# Check if settlements are close enough (trade range)
			if _settlements_are_close(settlement_a, settlement_b):
				_form_faction(settlement_a, settlement_b, tick)


func _faction_exists(settlement_a: int, settlement_b: int) -> bool:
	for faction in factions:
		if (faction.settlement_a == settlement_a and faction.settlement_b == settlement_b) or \
		   (faction.settlement_a == settlement_b and faction.settlement_b == settlement_a):
			return true
	return false


func _settlements_are_close(region_a: int, region_b: int) -> bool:
	# Simplified: check if regions are within 5 tiles of each other
	# In full implementation, would calculate actual distance
	var distance: int = abs(region_a - region_b)
	return distance < 50  # Arbitrary threshold for demo


func _form_faction(settlement_a: int, settlement_b: int, tick: int) -> void:
	# Start with neutral relation
	var faction: Dictionary = {
		"faction_id": _next_faction_id,
		"settlement_a": settlement_a,
		"settlement_b": settlement_b,
		"relation": "neutral",
		"trade_value": 0,
		"knowledge_shared": 0,
		"defense_pacts": 0,
		"conflicts": 0,
		"formed_tick": tick,
		"last_update_tick": tick
	}
	
	factions.append(faction)
	_next_faction_id += 1
	
	# Record faction formation event
	if _world_memory != null:
		_world_memory.record_event({
			"type": "faction_formed",
			"settlement_a": settlement_a,
			"settlement_b": settlement_b,
			"initial_relation": "neutral",
			"tick": tick
		})
	
	if OS.is_debug_build():
		print("[Faction] Formed between settlements %d and %d" % [settlement_a, settlement_b])


func _relation_to_number(relation: String) -> int:
	match relation:
		"allied":
			return RELATION_ALLIED + 10
		"friendly":
			return RELATION_FRIENDLY + 15
		"neutral":
			return RELATION_NEUTRAL + 10
		"hostile":
			return RELATION_HOSTILE - 10
		"war":
			return MIN_RELATION + 10
		_:
			return 0


func _number_to_relation(value: int) -> String:
	if value >= RELATION_ALLIED:
		return "allied"
	elif value >= RELATION_FRIENDLY:
		return "friendly"
	elif value >= RELATION_NEUTRAL:
		return "neutral"
	elif value >= RELATION_HOSTILE:
		return "hostile"
	else:
		return "war"


# ==================== Public API ====================

## Get relation between two settlements
func get_relation(settlement_a: int, settlement_b: int) -> String:
	_prune_stale_factions()
	for faction in factions:
		if (faction.settlement_a == settlement_a and faction.settlement_b == settlement_b) or \
		   (faction.settlement_a == settlement_b and faction.settlement_b == settlement_a):
			return faction.relation
	return "neutral"  # Default if no faction exists

## Get all factions for a settlement
func get_settlement_factions(settlement: int) -> Array[Dictionary]:
	_prune_stale_factions()
	var result: Array[Dictionary] = []
	for faction in factions:
		if faction.settlement_a == settlement or faction.settlement_b == settlement:
			result.append(faction.duplicate())
	return result

## Add trade value to faction (increases relation)
func add_trade_value(settlement_a: int, settlement_b: int, value: int) -> void:
	_prune_stale_factions()
	for faction in factions:
		if (faction.settlement_a == settlement_a and faction.settlement_b == settlement_b) or \
		   (faction.settlement_a == settlement_b and faction.settlement_b == settlement_a):
			faction.trade_value += value
			return

## Add knowledge sharing to faction (increases relation)
func add_knowledge_sharing(settlement_a: int, settlement_b: int, knowledge_types: int) -> void:
	_prune_stale_factions()
	for faction in factions:
		if (faction.settlement_a == settlement_a and faction.settlement_b == settlement_b) or \
		   (faction.settlement_a == settlement_b and faction.settlement_b == settlement_a):
			faction.knowledge_shared += knowledge_types
			return

## Add conflict to faction (decreases relation)
func add_conflict(settlement_a: int, settlement_b: int) -> void:
	_prune_stale_factions()
	for faction in factions:
		if (faction.settlement_a == settlement_a and faction.settlement_b == settlement_b) or \
		   (faction.settlement_a == settlement_b and faction.settlement_b == settlement_a):
			faction.conflicts += 1
			return

## Check if two settlements are allied
func are_allied(settlement_a: int, settlement_b: int) -> bool:
	return get_relation(settlement_a, settlement_b) == "allied"

## Check if two settlements are at war
func are_at_war(settlement_a: int, settlement_b: int) -> bool:
	return get_relation(settlement_a, settlement_b) == "war"

## Get faction statistics
func get_stats() -> Dictionary:
	_prune_stale_factions()
	var stats: Dictionary = {
		"total_factions": factions.size(),
		"allied": 0,
		"friendly": 0,
		"neutral": 0,
		"hostile": 0,
		"war": 0
	}
	
	for faction in factions:
		var relation: String = faction.relation
		if relation in stats:
			stats[relation] += 1
	
	return stats

## Get all factions (for debugging)
func get_all_factions() -> Array[Dictionary]:
	_prune_stale_factions()
	return factions.duplicate()

## Debug: Force relation between settlements
func debug_set_relation(settlement_a: int, settlement_b: int, relation: String) -> void:
	for faction in factions:
		if (faction.settlement_a == settlement_a and faction.settlement_b == settlement_b) or \
		   (faction.settlement_a == settlement_b and faction.settlement_b == settlement_a):
			faction.relation = relation
			return
	
	# Create new faction if doesn't exist
	var faction: Dictionary = {
		"faction_id": _next_faction_id,
		"settlement_a": settlement_a,
		"settlement_b": settlement_b,
		"relation": relation,
		"trade_value": 0,
		"knowledge_shared": 0,
		"defense_pacts": 0,
		"conflicts": 0,
		"formed_tick": GameManager.tick_count,
		"last_update_tick": GameManager.tick_count
	}
	factions.append(faction)
	_next_faction_id += 1
