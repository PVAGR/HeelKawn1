extends Node
class_name NPCManager

## Manages NPCs with mood consistency based on recent memory events.
## Tracks mood history and enforces gradual mood transitions.

signal npc_mood_updated(npc_id: int, new_mood: float, old_mood: float)

## Maximum mood history entries per NPC
const MAX_MOOD_HISTORY: int = 50

## Maximum mood change per tick (personality affects this)
const BASE_MAX_MOOD_CHANGE: float = 5.0

## Mood decay over time (per tick)
const MOOD_DECAY_RATE: float = 0.02

## NPC data storage
var _npcs: Dictionary = {}


func _ready() -> void:
	add_to_group("tickable")


func _on_world_tick(tick_number: int) -> void:
	# Process mood consistency for all NPCs
	for npc_id in _npcs.keys():
		var npc_data: Dictionary = _npcs.get(npc_id, {})
		if npc_data.is_empty():
			continue
		_apply_mood_consistency(npc_id, npc_data, tick_number)


## Register a new NPC
func register_npc(npc_id: int, npc_data: Dictionary) -> void:
	if not _npcs.has(npc_id):
		_npcs[npc_id] = {
			"current_mood": 50.0,
			"mood_history": [],
			"last_tick": 0,
		}
	
	# Initialize with provided data
	if npc_data.has("initial_mood"):
		_npcs[npc_id]["current_mood"] = npc_data["initial_mood"]


## Get NPC mood
func get_npc_mood(npc_id: int) -> float:
	if _npcs.has(npc_id):
		return _npcs[npc_id].get("current_mood", 50.0)
	return 50.0


## Set NPC mood with memory-based consistency
func set_npc_mood(npc_id: int, target_mood: float, current_tick: int) -> void:
	if not _npcs.has(npc_id):
		register_npc(npc_id, {})
	
	var npc_data: Dictionary = _npcs[npc_id]
	var old_mood: float = npc_data.get("current_mood", 50.0)
	
	# Apply mood consistency rules
	var new_mood: float = _calculate_consistent_mood(
		npc_id, 
		target_mood, 
		old_mood, 
		current_tick - int(npc_data.get("last_tick", 0))
	)
	
	npc_data["current_mood"] = new_mood
	npc_data["last_tick"] = current_tick
	
	# Update mood history
	var history: Array = npc_data.get("mood_history", [])
	history.append({
		"tick": current_tick,
		"mood": new_mood,
	})
	
	# Trim history to max size
	if history.size() > MAX_MOOD_HISTORY:
		history = history.slice(history.size() - MAX_MOOD_HISTORY)
	
	npc_data["mood_history"] = history
	
	npc_mood_updated.emit(npc_id, new_mood, old_mood)


## Calculate mood with personality-based consistency
func _calculate_consistent_mood(npc_id: int, target_mood: float, old_mood: float, ticks_delta: int) -> float:
	if ticks_delta <= 0:
		return target_mood
	
	# Get personality-based stability (0.0-1.0)
	var stability: float = _get_personality_stability(npc_id)
	
	# Calculate maximumallowed swing based on stability
	var max_change: float = BASE_MAX_MOOD_CHANGE * (1.0 - stability) * float(ticks_delta)
	
	# Dampen for very frequent updates
	if ticks_delta < 5:
		max_change *= 0.3
	elif ticks_delta < 15:
		max_change *= 0.7
	
	var mood_swing: float = target_mood - old_mood
	if abs(mood_swing) > max_change:
		return old_mood + sign(mood_swing) * max_change
	
	return target_mood


## Get NPC personality stability (0.0 = volatile, 1.0 = stable)
func _get_personality_stability(npc_id: int) -> float:
	# Default stability - override to load from NPC data
	return 0.5


## Apply mood decay and consistency
func _apply_mood_consistency(npc_id: int, npc_data: Dictionary, tick_number: int) -> void:
	var current_mood: float = npc_data.get("current_mood", 50.0)
	var last_tick: int = int(npc_data.get("last_tick", 0))
	var ticks_delta: int = tick_number - last_tick
	
	if ticks_delta <= 0:
		return
	
	# Apply natural mood decay (toward 50.0 baseline)
	var decay: float = MOOD_DECAY_RATE * float(ticks_delta)
	var new_mood: float = current_mood
	
	if current_mood > 50.0:
		new_mood = maxf(50.0, current_mood - decay)
	elif current_mood < 50.0:
		new_mood = minf(50.0, current_mood + decay)
	
	# Update if changed
	if abs(new_mood - current_mood) > 0.01:
		npc_data["current_mood"] = new_mood
		npc_data["last_tick"] = tick_number


## Get mood history for NPC
func get_mood_history(npc_id: int, max_entries: int = 10) -> Array:
	if _npcs.has(npc_id):
		var history: Array = _npcs[npc_id].get("mood_history", [])
		if history.size() > max_entries:
			return history.slice(history.size() - max_entries)
		return history.duplicate(true)
	return []


## Remove NPC (e.g., on death)
func remove_npc(npc_id: int) -> void:
	_npcs.erase(npc_id)


## Get total NPC count
func get_npc_count() -> int:
	return _npcs.size()