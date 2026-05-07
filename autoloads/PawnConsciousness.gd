extends Node
## PawnConsciousness - Makes HeelKawnians TRULY alive
##
## Westworld/Sunken Palace inspired:
## - Personal memories (pawn remembers EVERYTHING)
## - Dreams (unconscious desires surface during sleep)
## - Trauma (permanent scars from traumatic events)
## - Growth (pawn evolves from experiences)
## - Self-awareness levels (unconscious → aware → transcendent)
##
## This is what makes HeelKawnians DIFFERENT from normal NPCs.
## They REMEMBER. They DREAM. They GROW. They BECOME.

# Memory data structure
## {
##   "memory_id": int,
##   "pawn_id": int,
##   "tick": int,
##   "event_type": String,
##   "description": String,
##   "emotion": float,  # -100 (traumatic) to +100 (euphoric)
##   "importance": int,  # 1-10 (10 = life-changing)
##   "category": String,  # "survival", "social", "achievement", "trauma", "joy"
##   "associated_pawns": Array[int],  # Other pawns involved
##   "location": Vector2i,
##   "suppressed": bool  # Traumatic memories may be suppressed
## }

# Pawn consciousness data
## {
##   "pawn_id": int,
##   "memories": Array[Dictionary],
##   "dreams": Array[Dictionary],
##   "trauma_level": float,  # 0-100 (accumulated trauma)
##   "growth_points": int,  # Total personal growth
##   "self_awareness": int,  # 0-5 (unconscious to transcendent)
##   "personality_shifts": Dictionary,  # How personality changed
##   "core_beliefs": Array[String],  # Fundamental beliefs about world
##   "subconscious_desires": Array[String]  # What pawn truly wants
## }
var pawn_consciousness: Dictionary = {}
var _next_memory_id: int = 1

# Self-awareness levels
const AWARENESS_LEVELS: Array[String] = [
	"unconscious",    # 0: Pure instinct, no self-reflection
	"instinctive",    # 1: Basic drives, simple learning
	"aware",          # 2: Recognizes self, learns from mistakes
	"reflective",     # 3: Thinks about past, plans future
	"enlightened",    # 4: Deep understanding, teaches others
	"transcendent"    # 5: Legendary wisdom, becomes part of world lore
]

# Dream themes
const DREAM_THEMES: Dictionary = {
	"survival": ["being chased", "falling", "drowning", "starving", "freezing"],
	"social": ["being alone", "being celebrated", "rejection", "belonging"],
	"achievement": ["flying", "building", "creating", "mastering"],
	"trauma": ["reliving trauma", "being powerless", "losing loved ones"],
	"desire": ["finding treasure", "becoming master", "finding love"],
	"general": ["wandering", "floating", "watching", "remembering"]
}

# Trauma types
const TRAUMA_TYPES: Array[String] = [
	"near_death", "witnessed_death", "torture", "betrayal",
	"loss_of_loved_one", "humiliation", "powerlessness", "isolation"
]

# References
@onready var _world_memory: Node = null
@onready var _survival_system: Node = null


func _ready() -> void:
	GameManager.game_tick.connect(_on_game_tick)
	_world_memory = get_node_or_null("/root/WorldMemory")
	_survival_system = get_node_or_null("/root/SurvivalSystem")


func _get_pawn_spawner() -> Node:
	var _main: Node = get_tree().get_root().get_node_or_null("Main")
	if _main == null:
		return null
	return _main.get_node_or_null("WorldViewport/PawnSpawner")


func _on_game_tick(tick: int) -> void:
	# Process dreams for sleeping pawns
	if tick % 100 == 0:
		_process_dreams(tick)
	
	# Process trauma recovery
	if tick % 1000 == 0:
		_process_trauma_recovery(tick)


# ==================== MEMORY SYSTEM ====================

## Record a memory for a pawn
func record_memory(pawn_id: int, event_type: String, description: String, 
 emotion: float = 0.0, importance: int = 5, category: String = "general",
 associated_pawns: Array[int] = [], location: Vector2i = Vector2i.ZERO) -> int:
	
	# Initialize consciousness if needed
	_init_consciousness(pawn_id)
	
	# Create memory
	var memory: Dictionary = {
		"memory_id": _next_memory_id,
		"pawn_id": pawn_id,
		"tick": GameManager.tick_count,
		"event_type": event_type,
		"description": description,
		"emotion": clampf(emotion, -100.0, 100.0),
		"importance": clampi(importance, 1, 10),
		"category": category,
		"associated_pawns": associated_pawns.duplicate(),
		"location": location,
		"suppressed": false
	}
	
	# Check for trauma (emotion < -50)
	if emotion < -50:
		_apply_trauma(pawn_id, abs(emotion))
		memory.suppressed = emotion < -80  # Extremely traumatic memories suppressed
	
	# Check for growth opportunity (positive emotion + importance)
	if emotion > 30 and importance >= 7:
		_apply_growth(pawn_id, importance * int(emotion / 10))

	# Category-based belief formation
	var consciousness: Dictionary = pawn_consciousness[str(pawn_id)]
	if category == "achievement" and not consciousness.core_beliefs.has("skilled"):
		consciousness.core_beliefs.append("skilled")
	if category == "joy" and not consciousness.subconscious_desires.has("seek_joy"):
		consciousness.subconscious_desires.append("seek_joy")
	if category == "trauma" and not consciousness.subconscious_desires.has("seek_safety"):
		consciousness.subconscious_desires.append("seek_safety")
	
	# Add to memories
	pawn_consciousness[str(pawn_id)].memories.append(memory)
	
	# Record to WorldMemory (for persistence)
	_record_memory_to_world(pawn_id, memory)
	
	_next_memory_id += 1
	
	return memory.memory_id


## Get memories for a pawn
func get_memories(pawn_id: int, category: String = "", limit: int = -1) -> Array:
	_init_consciousness(pawn_id)

	var memories: Array = pawn_consciousness[str(pawn_id)].memories

	# Filter by category
	if category != "":
		memories = memories.filter(func(m): return m.category == category and not m.suppressed)
	else:
		memories = memories.filter(func(m): return not m.suppressed)

	# Sort by importance and emotion (most significant first)
	memories.sort_custom(func(a, b):
		return (a.importance * abs(a.emotion)) > (b.importance * abs(b.emotion))
	)

	# Limit results
	if limit > 0:
		return memories.slice(0, limit)

	return memories


## Get traumatic memories
func get_traumatic_memories(pawn_id: int) -> Array:
	return get_memories(pawn_id).filter(func(m): return m.emotion < -50)


## Get joyful memories
func get_joyful_memories(pawn_id: int) -> Array:
	return get_memories(pawn_id).filter(func(m): return m.emotion > 50)


# ==================== DREAM SYSTEM ====================

func _process_dreams(tick: int) -> void:
	var sp: Node = _get_pawn_spawner()
	if sp == null:
		return
	
	for pawn in sp.pawns:
		if pawn == null or not is_instance_valid(pawn) or pawn.data == null:
			continue

		# Check if pawn is sleeping
		var state: String = ""
		if pawn.has_method("get_state"):
			state = str(pawn.get_state())
		elif pawn.has_meta("state"):
			state = str(pawn.get_meta("state"))
		if state != "sleeping":
			continue

		# Generate dream
		_generate_dream(pawn)


func _generate_dream(pawn: Node) -> void:
	var pawn_id: int = int(pawn.data.id)
	_init_consciousness(pawn_id)
	
	var consciousness: Dictionary = pawn_consciousness[str(pawn_id)]
	
	# Dreams draw from recent memories and subconscious desires
	var recent_memories: Array[Dictionary] = get_memories(pawn_id, "", 10)
	
	if recent_memories.size() == 0:
		return
	
	# Dream theme based on dominant emotions and life state
	var theme: String = "general"
	if emotion_sum < -50:
		theme = "trauma"
	elif emotion_sum < -20:
		theme = "survival"
	elif emotion_sum > 50:
		theme = "desire"
	elif emotion_sum > 20:
		theme = "achievement"
	else:
		# Neutral emotions — check social context
		var has_social_memories: bool = false
		for memory in recent_memories:
			if memory.category == "social" or memory.category == "joy":
				has_social_memories = true
				break
		theme = "social" if has_social_memories else "general"

	# Get dream content
	var dream_themes: Array = DREAM_THEMES.get(theme, DREAM_THEMES.general)
	var dream_content: String = dream_themes[randi() % dream_themes.size()]
	
	# Create dream
	var dream: Dictionary = {
		"tick": GameManager.tick_count,
		"theme": theme,
		"content": dream_content,
		"emotion": emotion_sum / float(recent_memories.size()),
		"lucid": randf() < (float(consciousness.self_awareness) / 5.0)  # Higher awareness = more lucid dreams
	}
	
	consciousness.dreams.append(dream)
	
	# Record significant dreams
	if abs(dream.emotion) > 50 or dream.lucid:
		_record_dream_to_world(pawn_id, dream)


## Get recent dreams for a pawn
func get_dreams(pawn_id: int, limit: int = 5) -> Array:
	_init_consciousness(pawn_id)

	var dreams: Array = pawn_consciousness[str(pawn_id)].dreams
	dreams.sort_custom(func(a, b): return a.tick > b.tick)

	if limit > 0:
		return dreams.slice(0, limit)

	return dreams


# ==================== TRAUMA SYSTEM ====================

func _apply_trauma(pawn_id: int, severity: float) -> void:
	_init_consciousness(pawn_id)
	
	var consciousness: Dictionary = pawn_consciousness[str(pawn_id)]
	
	# Accumulate trauma
	consciousness.trauma_level = minf(100.0, consciousness.trauma_level + severity)
	
	# Trauma affects behavior
	if consciousness.trauma_level > 75:
		# Severe trauma: gain survivor belief, avoid danger
		if not consciousness.core_beliefs.has("survivor"):
			consciousness.core_beliefs.append("survivor")
		if not consciousness.subconscious_desires.has("avoid_danger"):
			consciousness.subconscious_desires.append("avoid_danger")
	elif consciousness.trauma_level > 50:
		# Moderate trauma: cautious worldview
		if not consciousness.core_beliefs.has("cautious"):
			consciousness.core_beliefs.append("cautious")
	elif consciousness.trauma_level > 25:
		# Mild trauma: slight mood effects
		if not consciousness.core_beliefs.has("resilient"):
			consciousness.core_beliefs.append("resilient")


func _process_trauma_recovery(tick: int) -> void:
	for pawn_id_str in pawn_consciousness:
		var consciousness: Dictionary = pawn_consciousness[pawn_id_str]
		
		# Natural trauma recovery (1 point per 1000 ticks)
		if consciousness.trauma_level > 0:
			consciousness.trauma_level = maxf(0.0, consciousness.trauma_level - 0.001)


## Get trauma level for a pawn
func get_trauma_level(pawn_id: int) -> float:
	_init_consciousness(pawn_id)
	return pawn_consciousness[str(pawn_id)].trauma_level


# ==================== GROWTH SYSTEM ====================

func _apply_growth(pawn_id: int, growth_points: int) -> void:
	_init_consciousness(pawn_id)
	
	var consciousness: Dictionary = pawn_consciousness[str(pawn_id)]
	
	# Accumulate growth points
	consciousness.growth_points += growth_points

	# Growth can form beliefs about purpose
	if consciousness.growth_points > 2000 and not consciousness.core_beliefs.has("purposeful"):
		consciousness.core_beliefs.append("purposeful")
	if consciousness.growth_points > 5000 and not consciousness.subconscious_desires.has("seek_wisdom"):
		consciousness.subconscious_desires.append("seek_wisdom")
	
	# Check for self-awareness increase
	var required_for_next_level: int = consciousness.self_awareness * consciousness.self_awareness * 1000
	if consciousness.growth_points >= required_for_next_level and consciousness.self_awareness < 5:
		consciousness.self_awareness += 1
		_on_awareness_increase(pawn_id, consciousness.self_awareness)


func _on_awareness_increase(pawn_id: int, new_level: int) -> void:
	# Record awareness increase
	if _world_memory != null:
		_world_memory.record_event({
			"type": "pawn_awareness_increased",
			"pawn_id": pawn_id,
			"new_level": new_level,
			"level_name": AWARENESS_LEVELS[new_level],
			"tick": GameManager.tick_count
		})


## Get self-awareness level for a pawn
func get_awareness_level(pawn_id: int) -> int:
	_init_consciousness(pawn_id)
	return pawn_consciousness[str(pawn_id)].self_awareness


## Get awareness level name
func get_awareness_name(level: int) -> String:
	if level >= 0 and level < AWARENESS_LEVELS.size():
		return AWARENESS_LEVELS[level]
	return "unknown"


# ==================== PERSONALITY & BELIEFS ====================

## Add core belief to pawn
func add_core_belief(pawn_id: int, belief: String) -> void:
	_init_consciousness(pawn_id)
	
	var consciousness: Dictionary = pawn_consciousness[str(pawn_id)]
	
	if not consciousness.core_beliefs.has(belief):
		consciousness.core_beliefs.append(belief)


## Remove core belief
func remove_core_belief(pawn_id: int, belief: String) -> void:
	_init_consciousness(pawn_id)
	
	var consciousness: Dictionary = pawn_consciousness[str(pawn_id)]
	
	var idx: int = consciousness.core_beliefs.find(belief)
	if idx >= 0:
		consciousness.core_beliefs.remove_at(idx)


## Get core beliefs
func get_core_beliefs(pawn_id: int) -> Array:
	_init_consciousness(pawn_id)
	return pawn_consciousness[str(pawn_id)].core_beliefs.duplicate()


## Add subconscious desire
func add_subconscious_desire(pawn_id: int, desire: String) -> void:
	_init_consciousness(pawn_id)

	var consciousness: Dictionary = pawn_consciousness[str(pawn_id)]

	if not consciousness.subconscious_desires.has(desire):
		consciousness.subconscious_desires.append(desire)


## Get subconscious desires
func get_subconscious_desires(pawn_id: int) -> Array:
	_init_consciousness(pawn_id)
	return pawn_consciousness[str(pawn_id)].subconscious_desires.duplicate()


# ==================== UTILITY ====================

func _init_consciousness(pawn_id: int) -> void:
	var pawn_id_str: String = str(pawn_id)
	
	if not pawn_consciousness.has(pawn_id_str):
		pawn_consciousness[pawn_id_str] = {
			"pawn_id": pawn_id,
			"memories": [],
			"dreams": [],
			"trauma_level": 0.0,
			"growth_points": 0,
			"self_awareness": 0,
			"personality_shifts": {},
			"core_beliefs": [],
			"subconscious_desires": []
		}


func _record_memory_to_world(pawn_id: int, memory: Dictionary) -> void:
	if _world_memory == null:
		return
	
	_world_memory.record_event({
		"type": "pawn_memory",
		"pawn_id": pawn_id,
		"memory_id": memory.memory_id,
		"event_type": memory.event_type,
		"emotion": memory.emotion,
		"importance": memory.importance,
		"category": memory.category,
		"tick": memory.tick
	})


func _record_dream_to_world(pawn_id: int, dream: Dictionary) -> void:
	if _world_memory == null:
		return
	
	_world_memory.record_event({
		"type": "pawn_dream",
		"pawn_id": pawn_id,
		"theme": dream.theme,
		"content": dream.content,
		"emotion": dream.emotion,
		"lucid": dream.lucid,
		"tick": dream.tick
	})


# ==================== PUBLIC API ====================

## Get full consciousness data for a pawn
func get_consciousness(pawn_id: int) -> Dictionary:
	_init_consciousness(pawn_id)
	return pawn_consciousness[str(pawn_id)].duplicate()


## Get consciousness summary (for UI display)
func get_consciousness_summary(pawn_id: int) -> Dictionary:
	_init_consciousness(pawn_id)
	
	var consciousness: Dictionary = pawn_consciousness[str(pawn_id)]
	
	return {
		"memory_count": consciousness.memories.size(),
		"trauma_level": consciousness.trauma_level,
		"growth_points": consciousness.growth_points,
		"self_awareness": consciousness.self_awareness,
		"awareness_name": get_awareness_name(consciousness.self_awareness),
		"core_beliefs": consciousness.core_beliefs.size(),
		"recent_dreams": consciousness.dreams.slice(-5)
	}


## Clear consciousness data (for pawn death)
func clear_pawn_consciousness(pawn_id: int) -> void:
	var pawn_id_str: String = str(pawn_id)
	
	if pawn_consciousness.has(pawn_id_str):
		# Record final consciousness state to world memory
		var consciousness: Dictionary = pawn_consciousness[pawn_id_str]
		
		if _world_memory != null:
			_world_memory.record_event({
				"type": "pawn_consciousness_archived",
				"pawn_id": pawn_id,
				"total_memories": consciousness.memories.size(),
				"final_awareness": consciousness.self_awareness,
				"final_trauma": consciousness.trauma_level,
				"tick": GameManager.tick_count
			})
		
		# Remove from active consciousness
		pawn_consciousness.erase(pawn_id_str)


## Clear all data (for world reroll)
func clear() -> void:
	pawn_consciousness.clear()
	_next_memory_id = 1
