extends Node
## VictorySystem - Endgame conditions and victory tracking
##
## Tracks progress toward victory conditions:
## - Legacy Victory: Reach 1000 legacy score
## - Dynasty Victory: Found 3 dynasties with 20+ members each
## - Knowledge Victory: Preserve all 26 knowledge types
## - Population Victory: Reach 100 pawns across settlements
## - Culture Victory: Establish 5 active settlements

# Victory condition definitions
const VICTORY_CONDITIONS: Dictionary = {
	"legacy": {"target": 1000, "current": 0, "description": "Accumulate 1000 Legacy Score"},
	"dynasty": {"target": 3, "current": 0, "description": "Found 3 dynasties with 20+ members"},
	"knowledge": {"target": 26, "current": 0, "description": "Preserve all 26 knowledge types"},
	"population": {"target": 100, "current": 0, "description": "Reach 100 pawns"},
	"culture": {"target": 5, "current": 0, "description": "Establish 5 active settlements"}
}

# Victory progress tracking
var victory_progress: Dictionary = {}
var game_won: bool = false
var victory_type: String = ""
var victory_tick: int = -1

# References
@onready var _legacy_system: Node = null
@onready var _settlement_memory: Node = null
@onready var _knowledge_system: Node = null
@onready var _pawn_spawner: Node = null
@onready var _world_memory: Node = null


func _ready() -> void:
	GameManager.game_tick.connect(_on_game_tick)
	_legacy_system = get_node_or_null("/root/LegacySystem")
	_settlement_memory = get_node_or_null("/root/SettlementMemory")
	_knowledge_system = get_node_or_null("/root/KnowledgeSystem")
	_pawn_spawner = get_node_or_null("/root/PawnSpawner")
	_world_memory = get_node_or_null("/root/WorldMemory")
	
	# Initialize victory progress
	for condition in VICTORY_CONDITIONS.keys():
		victory_progress[condition] = 0


func _on_game_tick(tick: int) -> void:
	# Check victory conditions every 100 ticks
	if tick % 100 == 0:
		_update_victory_progress(tick)
		_check_victory_conditions(tick)


func _update_victory_progress(tick: int) -> void:
	# Legacy Victory
	if _legacy_system != null:
		victory_progress["legacy"] = _legacy_system._legacy_score
	
	# Dynasty Victory
	var large_dynasties: int = 0
	if _legacy_system != null and _legacy_system.has("dynasties"):
		for dynasty in _legacy_system.dynasties.values():
			if int(dynasty.get("total_members", 0)) >= 20:
				large_dynasties += 1
	victory_progress["dynasty"] = large_dynasties
	
	# Knowledge Victory
	var preserved_knowledge: int = 0
	if _knowledge_system != null and _knowledge_system.has("record_carriers"):
		var knowledge_types: Dictionary = {}
		for carrier in _knowledge_system.record_carriers.values():
			for kt in carrier.get("knowledge_types", []):
				knowledge_types[kt] = true
		preserved_knowledge = knowledge_types.size()
	victory_progress["knowledge"] = preserved_knowledge
	
	# Population Victory
	if _pawn_spawner != null:
		victory_progress["population"] = _pawn_spawner.pawns.size()
	
	# Culture Victory
	var active_settlements: int = 0
	if _settlement_memory != null:
		for settlement in _settlement_memory.settlements:
			if settlement is Dictionary:
				var state: String = str(settlement.get("state", ""))
				if state == "active" or state == "revivable":
					active_settlements += 1
	victory_progress["culture"] = active_settlements


func _check_victory_conditions(tick: int) -> void:
	if game_won:
		return  # Already won
	
	for condition in VICTORY_CONDITIONS.keys():
		var target: int = VICTORY_CONDITIONS[condition].target
		var current: int = victory_progress[condition]
		
		if current >= target:
			_trigger_victory(condition, tick)
			return  # Only one victory at a time


func _trigger_victory(condition: String, tick: int) -> void:
	game_won = true
	victory_type = condition
	victory_tick = tick
	
	# Record victory event
	if _world_memory != null:
		_world_memory.record_event({
			"type": "victory_achieved",
			"victory_type": condition,
			"final_score": victory_progress[condition],
			"tick": tick
		})
	
	# Show victory notification
	_show_victory_message(condition)
	
	if OS.is_debug_build():
		print("[Victory] Game won via %s condition!" % condition)


func _show_victory_message(condition: String) -> void:
	var messages: Dictionary = {
		"legacy": "🏆 LEGACY VICTORY! Your legacy echoes through the ages!",
		"dynasty": "👑 DYNASTY VICTORY! Your bloodline dominates the land!",
		"knowledge": "📚 KNOWLEDGE VICTORY! Wisdom prevails over ignorance!",
		"population": "👥 POPULATION VICTORY! Your civilization flourishes!",
		"culture": "🏛️ CULTURE VICTORY! Your influence spans the land!"
	}
	
	var message: String = messages.get(condition, "🎉 VICTORY! You have triumphed!")
	print("\n" + message)
	print("Final Score: %d/%d" % [victory_progress[condition], VICTORY_CONDITIONS[condition].target])
	print("Completed in %d ticks (%.1f years)\n" % [victory_tick, float(victory_tick) / 360.0])


# ==================== Public API ====================

## Get current victory progress
func get_victory_progress() -> Dictionary:
	return victory_progress.duplicate()

## Get victory condition details
func get_victory_conditions() -> Dictionary:
	return VICTORY_CONDITIONS.duplicate()

## Check if game is won
func is_game_won() -> bool:
	return game_won

## Get victory type (if won)
func get_victory_type() -> String:
	return victory_type

## Get victory tick (if won)
func get_victory_tick() -> int:
	return victory_tick

## Get progress percentage for a condition
func get_progress_percent(condition: String) -> float:
	if not VICTORY_CONDITIONS.has(condition):
		return 0.0
	
	var target: int = VICTORY_CONDITIONS[condition].target
	var current: int = victory_progress.get(condition, 0)
	
	return minf(100.0, float(current) / float(target) * 100.0)

## Get overall completion (average of all conditions)
func get_overall_completion() -> float:
	var total: float = 0.0
	for condition in VICTORY_CONDITIONS.keys():
		total += get_progress_percent(condition)
	return total / float(VICTORY_CONDITIONS.size())

## Get the closest victory condition
func get_closest_victory() -> String:
	var closest: String = ""
	var highest_percent: float = 0.0
	
	for condition in VICTORY_CONDITIONS.keys():
		var percent: float = get_progress_percent(condition)
		if percent > highest_percent:
			highest_percent = percent
			closest = condition
	
	return closest

## Debug: Set victory progress (for testing)
func debug_set_progress(condition: String, value: int) -> void:
	if VICTORY_CONDITIONS.has(condition):
		victory_progress[condition] = value
		print("[Victory] Debug: Set %s to %d/%d" % [
			condition, value, VICTORY_CONDITIONS[condition].target
		])

## Debug: Trigger immediate victory (for testing)
func debug_trigger_victory(condition: String) -> void:
	if VICTORY_CONDITIONS.has(condition):
		victory_progress[condition] = VICTORY_CONDITIONS[condition].target
		_trigger_victory(condition, GameManager.tick_count)

## Get victory statistics for endgame screen
func get_victory_stats() -> Dictionary:
	var stats: Dictionary = {
		"game_won": game_won,
		"victory_type": victory_type,
		"victory_tick": victory_tick,
		"progress": victory_progress.duplicate(),
		"conditions": VICTORY_CONDITIONS.duplicate(),
		"overall_completion": get_overall_completion()
	}
	
	if game_won:
		stats["completion_time_years"] = float(victory_tick) / 360.0
	
	return stats
