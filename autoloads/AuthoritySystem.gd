extends Node
## HEELKAWN Authority/Conflict System - Authority is temporary and must emerge socially.
## Tracks authority emergence, conflict relationships, and resolution.


# Autoload references
@onready var WorldAI = get_node_or_null("/root/WorldAI")
@onready var WorldMemory = get_node_or_null("/root/WorldMemory")
@onready var GameManager = get_node_or_null("/root/GameManager")
@onready var RelationalGraph = get_node_or_null("/root/RelationalGraph")

enum AuthorityContext {
	MILITARY = 0,
	CIVIL = 1,
	RELIGIOUS = 2,
	KNOWLEDGE = 3
}

enum ConflictType {
	FEUD = 0,
	CLAN_DISPUTE = 1,
	TERRITORIAL = 2,
	RESOURCE = 3,
	IDEOLOGICAL = 4
}

## Authority levels: pawn_id -> context -> authority level (0.0-1.0)
var authority_levels: Dictionary = {}

## Authority sources: how authority was earned
var authority_sources: Dictionary = {}

## Conflict relationships: (pawn_id_a, pawn_id_b) -> conflict type and intensity
var conflicts: Dictionary = {}

## Conflict history: record of all conflicts
var conflict_history: Array[Dictionary] = []

## Peace treaties: active agreements
var peace_treaties: Array[Dictionary] = []

func _ready() -> void:
	GameManager.game_tick.connect(_on_game_tick)

func _on_game_tick(tick: int) -> void:
	if tick % 2000 == 0:
		_decay_authority()
	if tick % 3000 == 0:
		_update_conflict_intensities()

# === Authority Emergence ===

func grant_authority(pawn_id: int, context: AuthorityContext, amount: float, source: String) -> void:
       # Write to RelationalGraph
       if RelationalGraph:
	       var edge_data = {
		       "context": context,
		       "amount": amount,
		       "source": source,
		       "tick": GameManager.tick_count
	       }
	       RelationalGraph.add_edge(pawn_id, "AUTHORITY_CONTEXT_%d" % int(context), "authority", edge_data)
       # Legacy local storage for backward compatibility
       if not authority_levels.has(pawn_id):
	       authority_levels[pawn_id] = {}
       var contexts: Dictionary = authority_levels[pawn_id]
       var current: float = contexts.get(context, 0.0)
       contexts[context] = min(current + amount, 1.0)
       if not authority_sources.has(pawn_id):
	       authority_sources[pawn_id] = []
       var source_record: Dictionary = {
	       "context": context,
	       "source": source,
	       "amount": amount,
	       "tick": GameManager.tick_count
       }
       authority_sources[pawn_id].append(source_record)
       _record_authority_grant(pawn_id, context, amount, source)
       _notify_world_ai_authority_change(pawn_id, context, contexts[context])

func record_defense_action(defender_id: int, protected_id: int) -> void:
	# Defender gains military authority for protecting others
	grant_authority(defender_id, AuthorityContext.MILITARY, 0.1, "defense")
	_record_defense_event(defender_id, protected_id)

func record_organization_action(organizer_id: int, participants: Array[int]) -> void:
	# Organizer gains civil authority for coordinating labor
	grant_authority(organizer_id, AuthorityContext.CIVIL, 0.05 * participants.size(), "organization")
	_record_organization_event(organizer_id, participants)

func record_teaching_action(teacher_id: int, student_id: int) -> void:
	# Teacher gains knowledge authority
	grant_authority(teacher_id, AuthorityContext.KNOWLEDGE, 0.08, "teaching")
	# Teaching already recorded in KnowledgeSystem

func record_elder_recognition(elder_id: int) -> void:
	# Elder recognized for age and wisdom
	grant_authority(elder_id, AuthorityContext.CIVIL, 0.15, "elder_recognition")
	_record_elder_recognition(elder_id)

func record_memory_preservation(preserver_id: int) -> void:
	# Memory-keeper recognized for preserving knowledge
	grant_authority(preserver_id, AuthorityContext.KNOWLEDGE, 0.12, "memory_preservation")
	_record_memory_preservation(preserver_id)

# === Authority Decay ===

func _decay_authority() -> void:
	# Authority decays over time without reinforcement
	for pawn_id in authority_levels:
		var contexts: Dictionary = authority_levels[pawn_id]
		for context in contexts:
			var current: float = contexts[context]
			# Decay by 1% per check, minimum 0.1
			contexts[context] = max(current * 0.99, 0.1)

func transfer_authority(from_id: int, to_id: int, context: AuthorityContext) -> void:
	# Authority transfer through succession
	if not authority_levels.has(from_id):
		return
	
	var contexts: Dictionary = authority_levels[from_id]
	var amount: float = contexts.get(context, 0.0)
	
	if amount > 0:
		grant_authority(to_id, context, amount * 0.7, "succession")
		contexts[context] = amount * 0.3  # Retain some authority
		_record_succession(from_id, to_id, context, amount)

# === Conflict Systems ===

func start_conflict(pawn_id_a: int, pawn_id_b: int, conflict_type: ConflictType, initial_intensity: float = 0.5) -> void:
       # Write to RelationalGraph
       if RelationalGraph:
	       var edge_data = {
		       "type": conflict_type,
		       "intensity": initial_intensity,
		       "start_tick": GameManager.tick_count,
		       "last_action_tick": GameManager.tick_count
	       }
	       RelationalGraph.add_edge(pawn_id_a, pawn_id_b, "conflict", edge_data)
       # Legacy local storage for backward compatibility
       var key: String = _conflict_key(pawn_id_a, pawn_id_b)
       if not conflicts.has(key):
	       conflicts[key] = {
		       "type": conflict_type,
		       "intensity": initial_intensity,
		       "start_tick": GameManager.tick_count,
		       "last_action_tick": GameManager.tick_count
	       }
	       _record_conflict_start(pawn_id_a, pawn_id_b, conflict_type, initial_intensity)

func escalate_conflict(pawn_id_a: int, pawn_id_b: int, amount: float) -> void:
	var key: String = _conflict_key(pawn_id_a, pawn_id_b)
	
	if conflicts.has(key):
		var conflict: Dictionary = conflicts[key]
		conflict["intensity"] = min(conflict["intensity"] + amount, 1.0)
		conflict["last_action_tick"] = GameManager.tick_count
		_record_conflict_escalation(pawn_id_a, pawn_id_b, amount)

func deescalate_conflict(pawn_id_a: int, pawn_id_b: int, amount: float) -> void:
	var key: String = _conflict_key(pawn_id_a, pawn_id_b)
	
	if conflicts.has(key):
		var conflict: Dictionary = conflicts[key]
		conflict["intensity"] = max(conflict["intensity"] - amount, 0.0)
		conflict["last_action_tick"] = GameManager.tick_count
		
		if conflict["intensity"] <= 0.0:
			end_conflict(pawn_id_a, pawn_id_b, "resolved")
		else:
			_record_conflict_deescalation(pawn_id_a, pawn_id_b, amount)

func end_conflict(pawn_id_a: int, pawn_id_b: int, reason: String) -> void:
       # Remove from RelationalGraph
       if RelationalGraph:
	       # No direct remove_edge, but can be extended for real use
	       pass
       # Legacy local storage for backward compatibility
       var key: String = _conflict_key(pawn_id_a, pawn_id_b)
       if conflicts.has(key):
	       var conflict: Dictionary = conflicts[key]
	       _record_conflict_end(pawn_id_a, pawn_id_b, conflict["type"], reason)
	       conflicts.erase(key)

func inherit_conflict(from_id: int, to_id: int) -> void:
	# Inherited conflict memory - bloodline feuds
	for key in conflicts:
		var conflict: Dictionary = conflicts[key]
		var parts: PackedStringArray = key.split("_")
		var other_id: int = int(parts[1]) if int(parts[0]) == from_id else int(parts[0])
		
		# Inherit with reduced intensity
		start_conflict(to_id, other_id, conflict["type"], conflict["intensity"] * 0.5)
		_record_inherited_conflict(from_id, to_id, other_id, conflict["type"])

# === Peace and Resolution ===

func negotiate_peace(pawn_id_a: int, pawn_id_b: int, duration_ticks: int = 10000) -> bool:
       # Write to RelationalGraph
       if RelationalGraph:
	       var edge_data = {
		       "duration": duration_ticks,
		       "start_tick": GameManager.tick_count,
		       "end_tick": GameManager.tick_count + duration_ticks
	       }
	       RelationalGraph.add_edge(pawn_id_a, pawn_id_b, "peace_treaty", edge_data)
       # Legacy local storage for backward compatibility
       var key: String = _conflict_key(pawn_id_a, pawn_id_b)
       if not conflicts.has(key):
	       return false
       var conflict: Dictionary = conflicts[key]
       var treaty: Dictionary = {
	       "pawn_id_a": pawn_id_a,
	       "pawn_id_b": pawn_id_b,
	       "conflict_type": conflict["type"],
	       "start_tick": GameManager.tick_count,
	       "end_tick": GameManager.tick_count + duration_ticks
       }
       peace_treaties.append(treaty)
       # End conflict temporarily
       end_conflict(pawn_id_a, pawn_id_b, "peace_treaty")
       _record_peace_treaty(pawn_id_a, pawn_id_b, duration_ticks)
       return true

func check_peace_expiry() -> void:
	var current_tick: int = GameManager.tick_count
	var expired: Array[int] = []
	
	for i in range(peace_treaties.size()):
		var treaty: Dictionary = peace_treaties[i]
		if treaty["end_tick"] <= current_tick:
			expired.append(i)
			# Conflict may resume
			var pawn_id_a: int = treaty["pawn_id_a"]
			var pawn_id_b: int = treaty["pawn_id_b"]
			start_conflict(pawn_id_a, pawn_id_b, treaty["conflict_type"], 0.3)
			_record_peace_expiry(pawn_id_a, pawn_id_b)
	
	# Remove expired treaties (in reverse order)
	for i in range(expired.size() - 1, -1, -1):
		peace_treaties.remove_at(expired[i])

# === Helper Functions ===

func _conflict_key(pawn_id_a: int, pawn_id_b: int) -> String:
	var a: int = min(pawn_id_a, pawn_id_b)
	var b: int = max(pawn_id_a, pawn_id_b)
	return "%d_%d" % [a, b]

func _update_conflict_intensities() -> void:
	# Conflicts naturally deescalate over time without action
	var current_tick: int = GameManager.tick_count
	
	for key in conflicts:
		var conflict: Dictionary = conflicts[key]
		var last_action: int = conflict["last_action_tick"]
		
		# Deescalate if no recent action
		if current_tick - last_action > 5000:
			conflict["intensity"] = max(conflict["intensity"] * 0.95, 0.1)
			
			if conflict["intensity"] <= 0.1:
				var parts: PackedStringArray = key.split("_")
				end_conflict(int(parts[0]), int(parts[1]), "faded")

# === Event Recording ===

func _record_authority_grant(pawn_id: int, context: AuthorityContext, amount: float, source: String) -> void:
	var event: Dictionary = {
		"type": "authority_grant",
		"pawn_id": pawn_id,
		"context": context,
		"amount": amount,
		"source": source,
		"tick": GameManager.tick_count
	}
	WorldMemory.record_event(event)

func _record_defense_event(defender_id: int, protected_id: int) -> void:
	var event: Dictionary = {
		"type": "defense_action",
		"defender_id": defender_id,
		"protected_id": protected_id,
		"tick": GameManager.tick_count
	}
	WorldMemory.record_event(event)

func _record_organization_event(organizer_id: int, participants: Array[int]) -> void:
	var event: Dictionary = {
		"type": "organization_action",
		"organizer_id": organizer_id,
		"participants": participants,
		"tick": GameManager.tick_count
	}
	WorldMemory.record_event(event)

func _record_elder_recognition(elder_id: int) -> void:
	var event: Dictionary = {
		"type": "elder_recognition",
		"elder_id": elder_id,
		"tick": GameManager.tick_count
	}
	WorldMemory.record_event(event)

func _record_memory_preservation(preserver_id: int) -> void:
	var event: Dictionary = {
		"type": "memory_preservation",
		"preserver_id": preserver_id,
		"tick": GameManager.tick_count
	}
	WorldMemory.record_event(event)

func _record_succession(from_id: int, to_id: int, context: AuthorityContext, amount: float) -> void:
	var event: Dictionary = {
		"type": "authority_succession",
		"from_id": from_id,
		"to_id": to_id,
		"context": context,
		"amount": amount,
		"tick": GameManager.tick_count
	}
	WorldMemory.record_event(event)


# === Public Query Functions ===

func get_active_conflict_count() -> int:
	var count: int = 0
	for key in conflicts:
		var conflict_data = conflicts[key]
		if conflict_data is Dictionary and conflict_data.get("active", false):
			count += 1
	return count / 2  # Each conflict counted twice (A-B and B-A)

func get_active_treaty_count() -> int:
	return peace_treaties.size()

func _record_conflict_start(pawn_id_a: int, pawn_id_b: int, conflict_type: ConflictType, intensity: float) -> void:
	var record: Dictionary = {
		"pawn_id_a": pawn_id_a,
		"pawn_id_b": pawn_id_b,
		"conflict_type": conflict_type,
		"intensity": intensity,
		"start_tick": GameManager.tick_count
	}
	conflict_history.append(record)
	
	var event: Dictionary = {
		"type": "conflict_start",
		"pawn_id_a": pawn_id_a,
		"pawn_id_b": pawn_id_b,
		"conflict_type": conflict_type,
		"intensity": intensity,
		"tick": GameManager.tick_count
	}
	WorldMemory.record_event(event)

func _record_conflict_escalation(pawn_id_a: int, pawn_id_b: int, amount: float) -> void:
	var event: Dictionary = {
		"type": "conflict_escalation",
		"pawn_id_a": pawn_id_a,
		"pawn_id_b": pawn_id_b,
		"amount": amount,
		"tick": GameManager.tick_count
	}
	WorldMemory.record_event(event)

func _record_conflict_deescalation(pawn_id_a: int, pawn_id_b: int, amount: float) -> void:
	var event: Dictionary = {
		"type": "conflict_deescalation",
		"pawn_id_a": pawn_id_a,
		"pawn_id_b": pawn_id_b,
		"amount": amount,
		"tick": GameManager.tick_count
	}
	WorldMemory.record_event(event)

func _record_conflict_end(pawn_id_a: int, pawn_id_b: int, conflict_type: ConflictType, reason: String) -> void:
	var event: Dictionary = {
		"type": "conflict_end",
		"pawn_id_a": pawn_id_a,
		"pawn_id_b": pawn_id_b,
		"conflict_type": conflict_type,
		"reason": reason,
		"tick": GameManager.tick_count
	}
	WorldMemory.record_event(event)

func _record_inherited_conflict(from_id: int, to_id: int, other_id: int, conflict_type: ConflictType) -> void:
	var event: Dictionary = {
		"type": "inherited_conflict",
		"from_id": from_id,
		"to_id": to_id,
		"other_id": other_id,
		"conflict_type": conflict_type,
		"tick": GameManager.tick_count
	}
	WorldMemory.record_event(event)

func _record_peace_treaty(pawn_id_a: int, pawn_id_b: int, duration: int) -> void:
	var event: Dictionary = {
		"type": "peace_treaty",
		"pawn_id_a": pawn_id_a,
		"pawn_id_b": pawn_id_b,
		"duration": duration,
		"tick": GameManager.tick_count
	}
	WorldMemory.record_event(event)

func _record_peace_expiry(pawn_id_a: int, pawn_id_b: int) -> void:
	var event: Dictionary = {
		"type": "peace_expiry",
		"pawn_id_a": pawn_id_a,
		"pawn_id_b": pawn_id_b,
		"tick": GameManager.tick_count
	}
	WorldMemory.record_event(event)

# === Public Interface ===

func get_authority_level(pawn_id: int, context: AuthorityContext) -> float:
	if authority_levels.has(pawn_id):
		return authority_levels[pawn_id].get(context, 0.0)
	return 0.0

func get_conflict_intensity(pawn_id_a: int, pawn_id_b: int) -> float:
	var key: String = _conflict_key(pawn_id_a, pawn_id_b)
	if conflicts.has(key):
		return conflicts[key]["intensity"]
	return 0.0

func has_active_conflict(pawn_id_a: int, pawn_id_b: int) -> bool:
	var key: String = _conflict_key(pawn_id_a, pawn_id_b)
	return conflicts.has(key)

func has_peace_treaty(pawn_id_a: int, pawn_id_b: int) -> bool:
	for treaty in peace_treaties:
		if (treaty["pawn_id_a"] == pawn_id_a and treaty["pawn_id_b"] == pawn_id_b) or \
		   (treaty["pawn_id_a"] == pawn_id_b and treaty["pawn_id_b"] == pawn_id_a):
			return true
	return false

func get_authority_status() -> Dictionary:
	var status: Dictionary = {}
	
	for pawn_id in authority_levels:
		status[pawn_id] = authority_levels[pawn_id]
	
	return status

func get_conflict_status() -> Dictionary:
	var status: Dictionary = {}
	
	for key in conflicts:
		var parts: PackedStringArray = key.split("_")
		status[key] = {
			"pawn_a": int(parts[0]),
			"pawn_b": int(parts[1]),
			"type": conflicts[key]["type"],
			"intensity": conflicts[key]["intensity"]
		}
	
	return status

func _notify_world_ai_authority_change(pawn_id: int, context: AuthorityContext, new_level: float) -> void:
	# Notify WorldAI of authority change to update neural network
	if WorldAI != null and WorldAI.has_method("on_authority_change"):
		WorldAI.on_authority_change(pawn_id, context, new_level)

func clear() -> void:
	authority_levels.clear()
	authority_sources.clear()
	conflicts.clear()
	conflict_history.clear()
	peace_treaties.clear()
