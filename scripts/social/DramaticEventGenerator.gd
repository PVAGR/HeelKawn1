class_name DramaticEventGenerator
extends RefCounted

## Phase 4: Dramatic Event Generator
## NPCs generate mini-narratives that shape their behavior and the world

enum DramaticEvent {
	DISCOVERY = 0,     # Found something important
	CONFLICT = 1,      # Argument/escalation
	ACCOMPLISHMENT = 2, # Achieved goal
	LOSS = 3,          # Death/relationship break
	REDEMPTION = 4,    # Made amends
	REUNION = 5,       # Found lost person
	BETRAYAL = 6,      # Trust broken
	SACRIFICE = 7,     # Helped at cost
}

enum StoryBeat {
	SETUP = 0,
	COMPLICATION = 1,
	RISING_ACTION = 2,
	CLIMAX = 3,
	RESOLUTION = 4,
	CODA = 5,
}

const MAX_ACTIVE_STORIES: int = 2
const STORY_CHANCE_PER_2000_TICKS: float = 0.35
const MEMORY_IMPORTANCE_BOOST: float = 0.15

var _pawn_id: int = -1
var _active_stories: Array[Dictionary] = []
var _completed_stories: Array[Dictionary] = []
var _story_cooldown_tick: int = 0
var _cooldown_ticks: int = 2000


func _init(pawn_id: int) -> void:
	_pawn_id = pawn_id


## Attempt to start or advance a story beat for this pawn.
## Returns a Dictionary with the event if one fires, or empty Dictionary.
func attempt_story_beat(pawn_data: PawnData, world_state: Dictionary) -> Dictionary:
	var tick: int = _current_tick()

	# Cooldown check
	if tick < _story_cooldown_tick:
		return {}

	# Try to advance existing stories first
	for story in _active_stories:
		if story.status == "active" and tick >= story.next_beat_tick:
			var result: Dictionary = _advance_story(story, pawn_data, world_state)
			if not result.is_empty():
				return result

	# Try to start a new story if under limit
	if _active_stories.size() < MAX_ACTIVE_STORIES:
		var new_story: Dictionary = _try_start_story(pawn_data, world_state)
		if not new_story.is_empty():
			_active_stories.append(new_story)
			_story_cooldown_tick = tick + _cooldown_ticks
			# Fire the setup beat immediately
			var setup_result: Dictionary = _fire_beat(new_story, StoryBeat.SETUP, pawn_data, world_state)
			if not setup_result.is_empty():
				return setup_result

	return {}


func _try_start_story(pawn_data: PawnData, world_state: Dictionary) -> Dictionary:
	var rng_label: StringName = StringName("dramatic:%d:start" % _pawn_id)
	var roll: float = WorldRNG.range_for(rng_label, 0.0, 1.0, tick)

	if roll > STORY_CHANCE_PER_2000_TICKS:
		return {}

	# Pick event type based on pawn state
	var event_type: int = _pick_event_type(pawn_data, world_state, rng_label)

	var story: Dictionary = {
		"id": _active_stories.size(),
		"event_type": event_type,
		"current_beat": StoryBeat.SETUP,
		"status": "active",
		"start_tick": _current_tick(),
		"next_beat_tick": _current_tick() + 500,  # First beat soon
		"participants": [_pawn_id],
		"memory_ids": [],
		"outcome": "",  # filled on resolution
	}

	return story


func _pick_event_type(pawn_data: PawnData, world_state: Dictionary, rng_label: StringName) -> int:
	# Weight event types by pawn state
	var hunger: float = pawn_data.hunger
	var mood: float = pawn_data.mood
	var health: float = pawn_data.health

	var weights: Array = [
		1.0,  # DISCOVERY — default
		1.0 if mood < 40.0 else 0.3,  # CONFLICT — more likely when unhappy
		1.0 if hunger > 70.0 else 0.5,  # ACCOMPLISHMENT — more likely when well-fed
		1.0 if health < 40.0 else 0.2,  # LOSS — more likely when hurt
		0.5,  # REDEMPTION
		0.5,  # REUNION
		0.3 if mood < 30.0 else 0.1,  # BETRAYAL — rare, needs low mood
		0.4,  # SACRIFICE
	]

	var total: float = 0.0
	for w in weights:
		total += float(w)

	var pick: float = WorldRNG.range_for(rng_label, 0.0, total, _current_tick())
	var cumulative: float = 0.0
	for i in range(weights.size()):
		cumulative += float(weights[i])
		if pick <= cumulative:
			return i

	return DramaticEvent.DISCOVERY


func _advance_story(story: Dictionary, pawn_data: PawnData, world_state: Dictionary) -> Dictionary:
	var next_beat: int = story.current_beat + 1
	if next_beat > StoryBeat.CODA:
		# Story complete
		story.status = "completed"
		_completed_stories.append(story)
		_active_stories.erase(story)
		return _fire_resolution(story, pawn_data, world_state)

	var result: Dictionary = _fire_beat(story, next_beat, pawn_data, world_state)
	if not result.is_empty():
		story.current_beat = next_beat
		story.next_beat_tick = _current_tick() + 800  # ~0.8 in-game hours
		return result

	return {}


func _fire_beat(story: Dictionary, beat: int, pawn_data: PawnData, world_state: Dictionary) -> Dictionary:
	var event_type: int = story.event_type
	var beat_name: String = _beat_to_string(beat)
	var event_name: String = _event_to_string(event_type)

	var summary: String = "%s_%s" % [event_name, beat_name.to_lower()]
	var description: String = _generate_beat_description(event_type, beat, pawn_data)

	# Record as memory
	var memory_id: int = -1
	if pawn_data and pawn_data.has_method("get") and false:  # Placeholder until wired
		pass  # Memory recorded via LongTermMemory after wiring

	# Record to WorldMemory
	var event_dict: Dictionary = {
		"type": "dramatic_event",
		"pawn_id": _pawn_id,
		"event_type": event_name,
		"beat": beat_name,
		"summary": summary,
		"description": description,
		"tick": _current_tick(),
	}

	_record_world_event(event_dict)

	return event_dict


func _fire_resolution(story: Dictionary, pawn_data: PawnData, world_state: Dictionary) -> Dictionary:
	var event_name: String = _event_to_string(story.event_type)

	# Determine outcome based on event type and pawn state
	var outcome: String = "neutral"
	match story.event_type:
		DramaticEvent.DISCOVERY:
			outcome = "success" if pawn_data.mood > 50.0 else "mixed"
		DramaticEvent.CONFLICT:
			outcome = "resolved" if pawn_data.mood > 40.0 else "bitter"
		DramaticEvent.ACCOMPLISHMENT:
			outcome = "triumph"
		DramaticEvent.LOSS:
			outcome = "grief"
		DramaticEvent.REDEMPTION:
			outcome = "healed"
		DramaticEvent.REUNION:
			outcome = "joyful"
		DramaticEvent.BETRAYAL:
			outcome = "shattered"
		DramaticEvent.SACRIFICE:
			outcome = "honored"

	story.outcome = outcome

	var resolution: Dictionary = {
		"type": "dramatic_event",
		"pawn_id": _pawn_id,
		"event_type": event_name,
		"beat": "RESOLUTION",
		"outcome": outcome,
		"summary": "%s_resolved_%s" % [event_name, outcome],
		"tick": _current_tick(),
	}

	_record_world_event(resolution)
	return resolution


func _generate_beat_description(event_type: int, beat: int, pawn_data: PawnData) -> String:
	var pawn_name: String = "Pawn%d" % _pawn_id
	var event_name: String = _event_to_string(event_type)
	var beat_name: String = _beat_to_string(beat)

	match beat:
		StoryBeat.SETUP:
			return "%s: A %s story begins to unfold." % [pawn_name, event_name.to_lower()]
		StoryBeat.COMPLICATION:
			return "Obstacles arise in %s's %s." % [pawn_name, event_name.to_lower()]
		StoryBeat.RISING_ACTION:
			return "%s struggles forward despite the challenges." % pawn_name
		StoryBeat.CLIMAX:
			return "The pivotal moment in %s's %s arrives." % [pawn_name, event_name.to_lower()]
		StoryBeat.RESOLUTION:
			return "%s's %s reaches its conclusion." % [pawn_name, event_name.to_lower()]
		StoryBeat.CODA:
			return "The echoes of %s's %s linger in memory." % [pawn_name, event_name.to_lower()]

	return "%s experiences a %s moment." % [pawn_name, beat_name.to_lower()]


func _event_to_string(event_type: int) -> String:
	match event_type:
		DramaticEvent.DISCOVERY: return "DISCOVERY"
		DramaticEvent.CONFLICT: return "CONFLICT"
		DramaticEvent.ACCOMPLISHMENT: return "ACCOMPLISHMENT"
		DramaticEvent.LOSS: return "LOSS"
		DramaticEvent.REDEMPTION: return "REDEMPTION"
		DramaticEvent.REUNION: return "REUNION"
		DramaticEvent.BETRAYAL: return "BETRAYAL"
		DramaticEvent.SACRIFICE: return "SACRIFICE"
	return "UNKNOWN"


func _beat_to_string(beat: int) -> String:
	match beat:
		StoryBeat.SETUP: return "SETUP"
		StoryBeat.COMPLICATION: return "COMPLICATION"
		StoryBeat.RISING_ACTION: return "RISING_ACTION"
		StoryBeat.CLIMAX: return "CLIMAX"
		StoryBeat.RESOLUTION: return "RESOLUTION"
		StoryBeat.CODA: return "CODA"
	return "UNKNOWN"


func _record_world_event(event_dict: Dictionary) -> void:
	var WorldMemory = _get_world_memory()
	if WorldMemory == null:
		return
	WorldMemory.record_event(event_dict)


func _get_world_memory() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("/root/WorldMemory")


func _current_tick() -> int:
	var GameManager = Engine.get_main_loop().root.get_node_or_null("/root/GameManager")
	if GameManager != null and GameManager.has_method("get_tick_count"):
		return GameManager.tick_count
	return 0


## Get story summary for UI/debug
func get_story_summary() -> Dictionary:
	return {
		"active_count": _active_stories.size(),
		"completed_count": _completed_stories.size(),
		"active_stories": _active_stories.duplicate(),
		"cooldown_remaining": max(0, _story_cooldown_tick - _current_tick()),
	}
