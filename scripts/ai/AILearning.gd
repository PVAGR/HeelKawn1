extends Node
## AILearning - Deterministic AI adaptation from world events
##
## Reviews world events periodically and:
## - Identifies patterns (starvation, combat deaths, etc.)
## - Adjusts AI decision weights deterministically
## - Stores learnings in CulturalMemory
##
## All learning is:
## - Based on WorldMemory facts
## - Tick-stable inputs
## - Replayable cause/effect
## - No hidden non-auditable behavior

# Learning event data structure
## {
##   "event_type": String,
##   "count": int,
##   "last_tick": int,
##   "trend": String,  # "increasing", "decreasing", "stable"
##   "severity": int  # 1-10 scale
## }
var learned_patterns: Dictionary = {}

# Decision weight adjustments
## {
##   "decision_type": String,
##   "base_weight": float,
##   "adjusted_weight": float,
##   "reason": String,
##   "applied_tick": int
## }
var weight_adjustments: Dictionary = {}

# Configuration
const REVIEW_INTERVAL: int = 1000  # Review every 1000 ticks
const PATTERN_MEMORY_TICKS: int = 10000  # Remember patterns for 10k ticks
const MIN_SEVERITY_FOR_LEARNING: int = 3  # Only learn from severity 3+ events

# References
@onready var _world_memory: Node = null
@onready var _cultural_memory: Node = null
@onready var _settlement_memory: Node = null


func _ready() -> void:
	GameManager.game_tick.connect(_on_game_tick)
	_world_memory = get_node_or_null("/root/WorldMemory")
	_cultural_memory = get_node_or_null("/root/CulturalMemory")
	_settlement_memory = get_node_or_null("/root/SettlementMemory")


func _on_game_tick(tick: int) -> void:
	# Review world events periodically
	if tick % REVIEW_INTERVAL == 0:
		_review_world_events(tick)
	
	# Clean old patterns
	if tick % 5000 == 0:
		_clean_old_patterns(tick)


# ==================== EVENT REVIEW ====================

func _review_world_events(tick: int) -> void:
	if _world_memory == null:
		return
	
	# Get last REVIEW_INTERVAL of events
	var events: Array = _get_recent_events(REVIEW_INTERVAL)
	
	if events.is_empty():
		return
	
	# Identify patterns
	var patterns: Dictionary = _identify_patterns(events, tick)
	
	# Adjust decision weights based on patterns
	_adjust_weights_from_patterns(patterns, tick)
	
	# Store learnings in CulturalMemory
	_store_learnings(patterns, tick)


func _get_recent_events(ticks: int) -> Array:
	if not _world_memory.has_method("get_events"):
		return []
	
	# Get events from WorldMemory
	var all_events: Array = _world_memory.get_events()
	var recent: Array = []
	
	var start_tick: int = GameManager.tick_count - ticks
	for event in all_events:
		if event.get("tick", 0) >= start_tick:
			recent.append(event)
	
	return recent


func _identify_patterns(events: Array, tick: int) -> Dictionary:
	var patterns: Dictionary = {
		"starvation": {"count": 0, "severity": 0},
		"combat_deaths": {"count": 0, "severity": 0},
		"building_success": {"count": 0, "severity": 0},
		"resource_scarcity": {"count": 0, "severity": 0},
		"trade_success": {"count": 0, "severity": 0},
		"disaster_impact": {"count": 0, "severity": 0}
	}
	
	for event in events:
		var event_type: String = event.get("type", "")
		
		# Categorize events
		if event_type == "pawn_death":
			var cause: String = event.get("cause", "")
			if cause == "starvation" or cause == "hunger":
				patterns.starvation.count += 1
			elif cause == "combat" or cause == "wounds":
				patterns.combat_deaths.count += 1
		
		elif event_type == "building_completed":
			patterns.building_success.count += 1
		
		elif event_type == "resource_depleted":
			patterns.resource_scarcity.count += 1
		
		elif event_type == "trade_completed":
			patterns.trade_success.count += 1
		
		elif event_type.begins_with("disaster_"):
			patterns.disaster_impact.count += 1
	
	# Calculate severity (1-10 scale)
	for pattern_name in patterns:
		var pattern: Dictionary = patterns[pattern_name]
		pattern.severity = _calculate_severity(pattern.count, pattern_name)
		pattern.last_tick = tick
		pattern.trend = _calculate_trend(pattern_name, pattern.count)
	
	return patterns


func _calculate_severity(count: int, pattern_name: String) -> int:
	# Different patterns have different severity thresholds
	match pattern_name:
		"starvation":
			if count == 0: return 0
			elif count < 3: return 3
			elif count < 10: return 6
			else: return 10
		
		"combat_deaths":
			if count == 0: return 0
			elif count < 5: return 4
			elif count < 20: return 7
			else: return 10
		
		"resource_scarcity":
			if count == 0: return 0
			elif count < 5: return 3
			elif count < 15: return 6
			else: return 9
		
		_:
			if count == 0: return 0
			elif count < 10: return 2
			elif count < 50: return 5
			else: return 8


func _calculate_trend(pattern_name: String, current_count: int) -> String:
	# Compare to previous pattern
	if not learned_patterns.has(pattern_name):
		return "stable"
	
	var previous: Dictionary = learned_patterns[pattern_name]
	var previous_count: int = previous.get("count", 0)
	
	if current_count > previous_count * 1.5:
		return "increasing"
	elif current_count < previous_count * 0.5:
		return "decreasing"
	else:
		return "stable"


# ==================== WEIGHT ADJUSTMENT ====================

func _adjust_weights_from_patterns(patterns: Dictionary, tick: int) -> void:
	# Starvation → prioritize food production
	if patterns.starvation.severity >= MIN_SEVERITY_FOR_LEARNING:
		_adjust_weight("food_production", patterns.starvation.severity * 0.1, 
			"Starvation events detected (%d deaths)" % patterns.starvation.count, tick)
	
	# Combat deaths → prioritize defense/military
	if patterns.combat_deaths.severity >= MIN_SEVERITY_FOR_LEARNING:
		_adjust_weight("military_training", patterns.combat_deaths.severity * 0.1,
			"Combat deaths detected (%d deaths)" % patterns.combat_deaths.count, tick)
		_adjust_weight("defense_building", patterns.combat_deaths.severity * 0.08,
			"Combat deaths detected", tick)
	
	# Resource scarcity → prioritize gathering
	if patterns.resource_scarcity.severity >= MIN_SEVERITY_FOR_LEARNING:
		_adjust_weight("resource_gathering", patterns.resource_scarcity.severity * 0.1,
			"Resource scarcity detected (%d events)" % patterns.resource_scarcity.count, tick)
	
	# Building success → continue current approach
	if patterns.building_success.severity >= 5:
		_adjust_weight("construction", 0.05, "Building success rate high", tick)


func _adjust_weight(decision_type: String, adjustment: float, reason: String, tick: int) -> void:
	if not weight_adjustments.has(decision_type):
		weight_adjustments[decision_type] = {
			"base_weight": 1.0,
			"adjusted_weight": 1.0,
			"adjustments": [],
			"applied_tick": tick
		}
	
	var weight_data: Dictionary = weight_adjustments[decision_type]
	weight_data.adjusted_weight += adjustment
	weight_data.adjustments.append({
		"amount": adjustment,
		"reason": reason,
		"tick": tick
	})
	weight_data.applied_tick = tick
	
	# Clamp weight to reasonable range (0.1 to 10.0)
	weight_data.adjusted_weight = clampf(weight_data.adjusted_weight, 0.1, 10.0)
	
	# Record learning event
	if _world_memory != null:
		_world_memory.record_event({
			"type": "ai_weight_adjusted",
			"decision_type": decision_type,
			"adjustment": adjustment,
			"new_weight": weight_data.adjusted_weight,
			"reason": reason,
			"tick": tick
		})


# ==================== CULTURAL MEMORY STORAGE ====================

func _store_learnings(patterns: Dictionary, tick: int) -> void:
	if _cultural_memory == null:
		return
	
	# Store significant patterns
	for pattern_name in patterns:
		var pattern: Dictionary = patterns[pattern_name]
		if pattern.severity >= MIN_SEVERITY_FOR_LEARNING:
			_cultural_memory.store_learning({
				"pattern": pattern_name,
				"severity": pattern.severity,
				"trend": pattern.trend,
				"count": pattern.count,
				"learned_tick": tick,
				"lesson": _generate_lesson(pattern_name, pattern)
			})


func _generate_lesson(pattern_name: String, pattern: Dictionary) -> String:
	match pattern_name:
		"starvation":
			return "Food production must be prioritized. %d pawns died from hunger." % pattern.count
		"combat_deaths":
			return "Defense and military training are essential. %d pawns died in combat." % pattern.count
		"resource_scarcity":
			return "Resource gathering needs attention. %d scarcity events recorded." % pattern.count
		"building_success":
			return "Construction methods are effective. Continue current practices."
		_:
			return "Pattern observed: %s occurred %d times." % [pattern_name, pattern.count]


# ==================== PATTERN CLEANUP ====================

func _clean_old_patterns(tick: int) -> void:
	for pattern_name in learned_patterns:
		var pattern: Dictionary = learned_patterns[pattern_name]
		if tick - pattern.last_tick > PATTERN_MEMORY_TICKS:
			learned_patterns.erase(pattern_name)


# ==================== PUBLIC API ====================

## Get current weight for a decision type
func get_weight(decision_type: String) -> float:
	if weight_adjustments.has(decision_type):
		return weight_adjustments[decision_type].adjusted_weight
	return 1.0  # Default weight

## Get all learned patterns
func get_learned_patterns() -> Dictionary:
	return learned_patterns.duplicate()

## Get weight adjustments
func get_weight_adjustments() -> Dictionary:
	return weight_adjustments.duplicate()

## Clear all learnings (for world reroll)
func clear() -> void:
	learned_patterns.clear()
	weight_adjustments.clear()

## Get statistics
func get_stats() -> Dictionary:
	return {
		"patterns_learned": learned_patterns.size(),
		"weights_adjusted": weight_adjustments.size(),
		"review_interval": REVIEW_INTERVAL,
		"last_review_tick": GameManager.tick_count
	}

## Manual pattern review (for testing)
func force_review() -> void:
	_review_world_events(GameManager.tick_count)
