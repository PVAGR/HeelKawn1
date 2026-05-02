class_name LongTermMemory
extends RefCounted

## Phase 4: Long-Term Memory System
## Each NPC stores memories that define their personal history

enum MemoryType {
	PERSONAL = 0,
	SOCIAL = 1,
	EVENT = 2,
	GOAL = 3,
	REGRET = 4,
	ACCOMPLISHMENT = 5,
}

const MAX_MEMORIES: int = 64
const MEMORY_DECAY_BASE: float = 0.9995
const KEY_MEMORY_THRESHOLD: float = 0.85

var _pawn_id: int = -1
var _memories: Array[Dictionary] = []
var _memory_id_counter: int = 0


func _init(pawn_id: int) -> void:
	_pawn_id = pawn_id


func add_memory(
	mem_type: MemoryType,
	summary: String,
	emotional_sting: String = "neutral",
	importance: float = 0.5,
	location: Vector2i = Vector2i(-1, -1),
	people_involved: Array = []
) -> int:
	if _memories.size() >= MAX_MEMORIES:
		_prune_weakest_memory()
	
	var memory_id: int = _memory_id_counter
	_memory_id_counter += 1
	
	var memory: Dictionary = {
		"id": memory_id,
		"type": mem_type,
		"summary": summary,
		"emotional_sting": emotional_sting,
		"importance": importance,
		"tick_created": _current_tick(),
		"last_recalled": _current_tick(),
		"recall_count": 0,
		"location": location,
		"people_involved": people_involved.duplicate(),
		"key_memory": importance >= KEY_MEMORY_THRESHOLD,
	}
	
	_memories.append(memory)
	return memory_id


func recall_memory(memory_id: int) -> Dictionary:
	for mem in _memories:
		if mem.id == memory_id:
			mem.last_recalled = _current_tick()
			mem.recall_count += 1
			mem.importance = minf(1.0, mem.importance + 0.05)
			return mem
	return {}


func get_story_memory(min_importance: float = 0.3) -> Dictionary:
	var candidates: Array = []
	for mem in _memories:
		if mem.importance >= min_importance and mem.recall_count < 3:
			candidates.append(mem)
	
	if candidates.is_empty():
		return {}
	
	var total_weight: float = 0.0
	for mem in candidates:
		total_weight += mem.importance
	
	var roll: float = WorldRNG.rand_for(StringName("memory:%d:%d" % [_pawn_id, _current_tick()]), 0.0, total_weight)
	
	var cumulative: float = 0.0
	for mem in candidates:
		cumulative += mem.importance
		if cumulative >= roll:
			recall_memory(mem.id)
			return mem
	
	return candidates[0] if candidates else {}


func get_memories_with(pawn_id: int) -> Array[Dictionary]:
	var result: Array = []
	for mem in _memories:
		if pawn_id in mem.people_involved:
			result.append(mem)
	return result


func record_event(event_type: String, event_data: Dictionary) -> void:
	var emotional: String = "neutral"
	var importance: float = 0.5
	var location: Vector2i = Vector2i(-1, -1)
	var people: Array = []
	
	match event_type:
		"job_completed":
			emotional = "pride"
			importance = 0.6
		"social_bond":
			emotional = "joy"
			importance = 0.7
		"attack_survived":
			emotional = "fear"
			importance = 0.8
		"loss":
			emotional = "sorrow"
			importance = 0.9
		"discovery":
			emotional = "curiosity"
			importance = 0.65
	
	if event_data.has("location"):
		location = event_data.location
	if event_data.has("pawn_id"):
		people.append(event_data.pawn_id)
	
	add_memory(MemoryType.EVENT, event_type, emotional, importance, location, people)


func tick_decay() -> void:
	for mem in _memories:
		if mem.key_memory:
			continue
		var age: int = _current_tick() - mem.tick_created
		mem.importance = maxf(0.1, mem.importance * pow(MEMORY_DECAY_BASE, float(age)))
	
	_memories = _memories.filter(func(m): return m.importance > 0.15)


func _prune_weakest_memory() -> void:
	if _memories.is_empty():
		return
	
	var weakest_idx: int = -1
	var weakest_importance: float = 1.0
	
	for i in range(_memories.size()):
		var mem = _memories[i]
		if mem.key_memory:
			continue
		if mem.importance < weakest_importance:
			weakest_importance = mem.importance
			weakest_idx = i
	
	if weakest_idx >= 0:
		_memories.remove_at(weakest_idx)


func _current_tick() -> int:
	return GameManager.tick_count if GameManager != null else 0


func get_state() -> Dictionary:
	return {
		"pawn_id": _pawn_id,
		"memories": _memories,
		"memory_id_counter": _memory_id_counter,
	}


func load_state(state: Dictionary) -> void:
	_memories = state.get("memories", [])
	_memory_id_counter = state.get("memory_id_counter", 0)


func memory_count() -> int:
	return _memories.size()