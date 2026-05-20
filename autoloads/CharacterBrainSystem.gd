extends Node
## Lightweight autonomous character decision-making system.
## 
## Each HeelKawnian has a "Brain" — a minimal decision kernel that:
## - Maintains lightweight procedural memory (goals, state, recent events)
## - Generates next-action decisions using deterministic heuristics (not random)
## - Runs entirely in GDScript (no external LLM calls during gameplay)
## - Evolves behavior through world state pressure (not AI training)
##
## Acts as the "fusion core" / "battery" of character agency:
## All characters sim in parallel, evolving together.

## Brain state: persistent per-character, saved with character data.
class BrainState:
	var character_id: String = ""
	var current_goal: String = ""  # FORAGE, MINE, BUILD, SLEEP, SOCIAL, IDLE
	var goal_urgency: float = 0.5  # 0.0 (low) to 1.0 (critical)
	var memory_traits: Dictionary = {}  # learned behavior pattern weights
	var last_decision_tick: int = 0
	var decision_history: Array = []  # recent [decision, outcome] pairs (max 20)
	
	func _init(id: String) -> void:
		character_id = id
		_reset_memory_traits()
	
	func _reset_memory_traits() -> void:
		# Base decision weights (procedural, not learned).
		# During gameplay, world pressure (hunger, danger, resources) modulates these.
		memory_traits = {
			"hunger_threshold": 0.4,      # Forage if food < 40% of capacity
			"safety_threshold": 0.3,      # Hide/rest if danger > 30%
			"sociability": 0.5,           # Inclination to work near others
			"risk_tolerance": 0.4,        # Willingness to explore dangerous areas
			"build_ambition": 0.6,        # Prefer construction over pure harvest
		}
	
	func record_decision(action: String, outcome_value: float) -> void:
		decision_history.append({
			"action": action,
			"outcome": outcome_value,
			"tick": GameManager.tick if GameManager else 0
		})
		if decision_history.size() > 20:
			decision_history.pop_front()

## Per-character brain instance.
class CharacterBrain:
	var state: BrainState
	var character_ref: Node  # weak ref to HeelKawnian pawn
	
	func _init(char_id: String, char_ref: Node) -> void:
		state = BrainState.new(char_id)
		character_ref = char_ref
	
	## Decide next action based on world state + memory.
	## Called once per character per frame (or every N ticks).
	func decide_next_action() -> String:
		if not character_ref or not is_instance_valid(character_ref):
			return "IDLE"
		
		var hunger = character_ref.get("hunger", 50.0) / 100.0  # 0.0 to 1.0
		var danger = character_ref.get("danger_level", 0.0)  # 0.0 to 1.0
		var nearby_friends = character_ref.get("nearby_allies", 0)
		var local_resources = character_ref.get("resource_scarcity", 0.5)  # 0.0 = plenty, 1.0 = famine
		
		var traits = state.memory_traits
		
		# Decision tree: critical states first.
		if hunger > traits.hunger_threshold:
			state.current_goal = "FORAGE"
			state.goal_urgency = min(1.0, hunger)
			return "FORAGE"
		
		if danger > traits.safety_threshold:
			state.current_goal = "SEEK_SHELTER"
			state.goal_urgency = danger
			return "SEEK_SHELTER"
		
		# Sociability modulates solo vs. group work.
		if nearby_friends > 0 and randf() < traits.sociability:
			state.current_goal = "SOCIAL_WORK"
			state.goal_urgency = 0.3
			return "ASSIST_NEARBY"
		
		# Build ambition: when resources allow, prefer construction.
		if local_resources < 0.8 and randf() < traits.build_ambition:
			state.current_goal = "BUILD"
			state.goal_urgency = 0.5
			return "BUILD"
		
		# Default harvest (forage, mine, chop) based on urgency.
		if local_resources > 0.5:
			state.current_goal = "HARVEST"
			state.goal_urgency = 0.4
			return "HARVEST"
		
		state.current_goal = "IDLE"
		state.goal_urgency = 0.0
		return "IDLE"
	
	## Adapt memory traits based on world outcome (pressure).
	## Called after an action completes or on periodic evaluation.
	func adapt_to_pressure(outcome: float, world_condition: String) -> void:
		# outcome: -1.0 (bad), 0.0 (neutral), +1.0 (good)
		# world_condition: "famine", "plenty", "conflict", "peace", etc.
		
		var traits = state.memory_traits
		var learning_rate = 0.05  # small, deterministic updates
		
		match world_condition:
			"famine":
				# Increase hunger threshold to forage earlier.
				traits["hunger_threshold"] = min(0.8, traits["hunger_threshold"] + learning_rate * (1.0 - outcome))
				# Reduce build ambition during famine.
				traits["build_ambition"] = max(0.1, traits["build_ambition"] - learning_rate)
			"conflict":
				# Increase risk aversion.
				traits["risk_tolerance"] = max(0.0, traits["risk_tolerance"] - learning_rate * 2.0)
				traits["safety_threshold"] = min(1.0, traits["safety_threshold"] + learning_rate)
			"peace":
				# Increase build ambition and sociability.
				traits["build_ambition"] = min(1.0, traits["build_ambition"] + learning_rate * 0.5)
				traits["sociability"] = min(1.0, traits["sociability"] + learning_rate * 0.3)
		
		# Clamp all traits to [0.0, 1.0].
		for key in traits.keys():
			traits[key] = clamp(traits[key], 0.0, 1.0)
		
		# Record the decision and outcome for history.
		state.record_decision(state.current_goal, outcome)

## Global registry.
var brains: Dictionary = {}  # character_id -> CharacterBrain

func _ready() -> void:
	# Subscribe to character lifecycle events if available.
	pass

## Create a new brain for a character.
func create_brain(character_id: String, character_ref: Node) -> CharacterBrain:
	var brain = CharacterBrain.new(character_id, character_ref)
	brains[character_id] = brain
	return brain

## Get brain by character ID.
func get_brain(character_id: String) -> CharacterBrain:
	return brains.get(character_id)

## Tick all brains (called once per game tick or per-frame decision loop).
func tick_all_brains() -> void:
	for char_id in brains.keys():
		var brain = brains[char_id]
		if brain and is_instance_valid(brain.character_ref):
			brain.decide_next_action()

## Adapt all brains to current world state.
func adapt_all_brains(world_condition: String, average_outcome: float) -> void:
	for char_id in brains.keys():
		var brain = brains[char_id]
		if brain:
			brain.adapt_to_pressure(average_outcome, world_condition)

## Remove a brain when character dies/despawns.
func remove_brain(character_id: String) -> void:
	brains.erase(character_id)

## Serialize a brain's state for saving.
func serialize_brain(character_id: String) -> Dictionary:
	var brain = brains.get(character_id)
	if not brain:
		return {}
	
	return {
		"character_id": brain.state.character_id,
		"current_goal": brain.state.current_goal,
		"goal_urgency": brain.state.goal_urgency,
		"memory_traits": brain.state.memory_traits.duplicate(),
		"decision_history": brain.state.decision_history.duplicate(true),
	}

## Deserialize a brain's state from save.
func deserialize_brain(data: Dictionary, character_ref: Node) -> CharacterBrain:
	var brain = CharacterBrain.new(data.get("character_id", ""), character_ref)
	brain.state.current_goal = data.get("current_goal", "IDLE")
	brain.state.goal_urgency = data.get("goal_urgency", 0.0)
	brain.state.memory_traits = data.get("memory_traits", {}).duplicate()
	brain.state.decision_history = data.get("decision_history", []).duplicate(true)
	return brain
