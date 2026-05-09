extends Node
## GeneticsSystem - CK3-style trait inheritance
##
## Features:
## - Genetic traits (fixed attributes)
## - Learned traits (skills, proficiencies)
## - Deterministic inheritance (no RNG)
## - Trait expression (dominant/recessive)
## - Individuality without superiority

# Trait types
enum TraitType {
	GENETIC,    # Fixed at birth, inherited
	LEARNED,    # Acquired through experience
	CULTURAL,   # From culture/upbringing
	SCAR,       # From wounds/events
}

# Trait data structure
## {
##   "trait_id": String,
##   "name": String,
##   "description": String,
##   "type": int,  # TraitType enum
##   "effects": Dictionary,
##   "inheritance": String,  # "dominant", "recessive", "complex"
##   "rarity": int  # 1-10 (1 = common, 10 = rare)
## }
var trait_definitions: Dictionary = {}

# HeelKawnian traits
## {
##   "pawn_id": int,
##   "genetic_traits": Array[String],  # Inherited traits
##   "learned_traits": Array[String],  # Acquired traits
##   "cultural_traits": Array[String],  # Cultural traits
##   "scars": Array[String]  # Event scars
## }
var pawn_traits: Dictionary = {}

# Trait database (pre-defined traits)
const TRAIT_DATABASE: Dictionary = {
	# Genetic traits
	"strong": {
		"name": "Strong",
		"description": "Above average physical strength",
		"type": TraitType.GENETIC,
		"effects": {"strength": 0.2},
		"inheritance": "dominant",
		"rarity": 3
	},
	"weak": {
		"name": "Weak",
		"description": "Below average physical strength",
		"type": TraitType.GENETIC,
		"effects": {"strength": -0.1},
		"inheritance": "recessive",
		"rarity": 2
	},
	"intelligent": {
		"name": "Intelligent",
		"description": "Quick learner, sharp mind",
		"type": TraitType.GENETIC,
		"effects": {"learning_speed": 0.3},
		"inheritance": "complex",
		"rarity": 4
	},
	"charismatic": {
		"name": "Charismatic",
		"description": "Natural leader, persuades easily",
		"type": TraitType.GENETIC,
		"effects": {"leadership": 0.25, "trade": 0.15},
		"inheritance": "dominant",
		"rarity": 3
	},
	"stoic": {
		"name": "Stoic",
		"description": "Endures hardship without complaint",
		"type": TraitType.GENETIC,
		"effects": {"pain_tolerance": 0.3, "mood_decay": -0.1},
		"inheritance": "recessive",
		"rarity": 2
	},
	"paranoid": {
		"name": "Paranoid",
		"description": "Always watching, never trusting",
		"type": TraitType.GENETIC,
		"effects": {"defense": 0.15, "trust": -0.2},
		"inheritance": "recessive",
		"rarity": 3
	},
	"ambitious": {
		"name": "Ambitious",
		"description": "Strives for greatness",
		"type": TraitType.GENETIC,
		"effects": {"skill_gain": 0.2, "contentment": -0.15},
		"inheritance": "dominant",
		"rarity": 3
	},
	"content": {
		"name": "Content",
		"description": "Satisfied with simple life",
		"type": TraitType.GENETIC,
		"effects": {"mood": 0.2, "ambition": -0.2},
		"inheritance": "recessive",
		"rarity": 2
	},
	
	# Learned traits
	"skilled_warrior": {
		"name": "Skilled Warrior",
		"description": "Veteran of many battles",
		"type": TraitType.LEARNED,
		"effects": {"combat": 0.3},
		"inheritance": "none",
		"rarity": 4
	},
	"master_crafter": {
		"name": "Master Crafter",
		"description": "Years of crafting experience",
		"type": TraitType.LEARNED,
		"effects": {"crafting": 0.4},
		"inheritance": "none",
		"rarity": 5
	},
	"scholar": {
		"name": "Scholar",
		"description": "Well-read and knowledgeable",
		"type": TraitType.LEARNED,
		"effects": {"research": 0.3, "teaching": 0.2},
		"inheritance": "none",
		"rarity": 4
	},
	
	# Cultural traits
	"northern": {
		"name": "Northern",
		"description": "From the cold north",
		"type": TraitType.CULTURAL,
		"effects": {"cold_resistance": 0.3},
		"inheritance": "none",
		"rarity": 2
	},
	"coastal": {
		"name": "Coastal",
		"description": "Grew up by the sea",
		"type": TraitType.CULTURAL,
		"effects": {"swimming": 0.2, "fishing": 0.2},
		"inheritance": "none",
		"rarity": 2
	},
	
	# Scar traits
	"battle_scarred": {
		"name": "Battle-Scarred",
		"description": "Survived many battles",
		"type": TraitType.SCAR,
		"effects": {"combat": 0.1, "appearance": -0.1},
		"inheritance": "none",
		"rarity": 4
	},
	"war_wound": {
		"name": "War Wound",
		"description": "Lost a limb in battle",
		"type": TraitType.SCAR,
		"effects": {"mobility": -0.2, "respect": 0.1},
		"inheritance": "none",
		"rarity": 5
	}
}


func _ready() -> void:
	# Load trait definitions
	_load_trait_definitions()


func _load_trait_definitions() -> void:
	for trait_id in TRAIT_DATABASE:
		trait_definitions[trait_id] = TRAIT_DATABASE[trait_id].duplicate()


# ==================== TRAIT INHERITANCE ====================

## Calculate inherited traits for a child (deterministic)
func calculate_inheritance(child_id: int, father_id: int, mother_id: int) -> Array[String]:
	var inherited: Array[String] = []
	
	# Get parent traits
	var father_genetic: Array[String] = _get_pawn_genetic_traits(father_id)
	var mother_genetic: Array[String] = _get_pawn_genetic_traits(mother_id)
	
	# Inherit from father (dominant traits first)
	for trait_id in father_genetic:
		if _should_inherit_trait(trait_id, "father"):
			inherited.append(trait_id)
	
	# Inherit from mother (dominant traits first)
	for trait_id in mother_genetic:
		if _should_inherit_trait(trait_id, "mother"):
			inherited.append(trait_id)
	
	# Store child's traits
	if not pawn_traits.has(child_id):
		pawn_traits[child_id] = {
			"genetic_traits": [],
			"learned_traits": [],
			"cultural_traits": [],
			"scars": []
		}
	
	pawn_traits[child_id].genetic_traits = inherited
	
	return inherited


func _should_inherit_trait(trait_id: String, parent: String) -> bool:
	if not trait_definitions.has(trait_id):
		return false

	var trait_def: Dictionary = trait_definitions[trait_id]
	var inheritance: String = trait_def.get("inheritance", "none")

	match inheritance:
		"dominant":
			return true
		"recessive":
			return true
		"complex":
			return true
		_:
			return false


# ==================== TRAIT MANAGEMENT ====================

## Add learned trait to pawn
func add_learned_trait(pawn_id: int, trait_id: String) -> bool:
	if not trait_definitions.has(trait_id):
		return false

	var tdef: Dictionary = trait_definitions[trait_id]
	if tdef.type != TraitType.LEARNED:
		return false

	if not pawn_traits.has(pawn_id):
		_initialize_pawn_traits(pawn_id)

	if not pawn_traits[pawn_id].learned_traits.has(trait_id):
		pawn_traits[pawn_id].learned_traits.append(trait_id)
		return true

	return false


## Add cultural trait to pawn
func add_cultural_trait(pawn_id: int, trait_id: String) -> bool:
	if not trait_definitions.has(trait_id):
		return false
	
	var trait_def: Dictionary = trait_definitions[trait_id]
	if trait_def.type != TraitType.CULTURAL:
		return false
	
	if not pawn_traits.has(pawn_id):
		_initialize_pawn_traits(pawn_id)
	
	if not pawn_traits[pawn_id].cultural_traits.has(trait_id):
		pawn_traits[pawn_id].cultural_traits.append(trait_id)
		return true
	
	return false


## Add scar to pawn
func add_scar(pawn_id: int, trait_id: String, reason: String = "") -> bool:
	if not trait_definitions.has(trait_id):
		return false
	
	var trait_def: Dictionary = trait_definitions[trait_id]
	if trait_def.type != TraitType.SCAR:
		return false
	
	if not pawn_traits.has(pawn_id):
		_initialize_pawn_traits(pawn_id)
	
	if not pawn_traits[pawn_id].scars.has(trait_id):
		pawn_traits[pawn_id].scars.append(trait_id)
		
		# Record scar acquisition
		var world_memory: Node = get_node_or_null("/root/WorldMemory")
		if world_memory != null:
			world_memory.record_event({
				"type": "scar_acquired",
				"pawn_id": pawn_id,
				"scar": trait_id,
				"reason": reason,
				"tick": GameManager.tick_count
			})
		
		return true
	
	return false


## Remove trait from pawn
func remove_trait(pawn_id: int, trait_id: String) -> bool:
	if not pawn_traits.has(pawn_id):
		return false
	
	var traits: Dictionary = pawn_traits[pawn_id]
	
	# Check all trait categories
	for category in ["genetic_traits", "learned_traits", "cultural_traits", "scars"]:
		if traits.has(category):
			var idx: int = traits[category].find(trait_id)
			if idx >= 0:
				traits[category].remove_at(idx)
				return true
	
	return false


# ==================== TRAIT QUERIES ====================

## Get all traits for a pawn
func get_all_traits(pawn_id: int) -> Dictionary:
	if not pawn_traits.has(pawn_id):
		_initialize_pawn_traits(pawn_id)
	
	return pawn_traits[pawn_id].duplicate()

## Get genetic traits for a pawn
func _get_pawn_genetic_traits(pawn_id: int) -> Array[String]:
	if not pawn_traits.has(pawn_id):
		return []
	return pawn_traits[pawn_id].get("genetic_traits", [])

## Get trait effects for a pawn
func get_trait_effects(pawn_id: int) -> Dictionary:
	var effects: Dictionary = {}
	
	if not pawn_traits.has(pawn_id):
		return effects
	
	var traits: Dictionary = pawn_traits[pawn_id]
	
	# Combine all trait effects
	for category in ["genetic_traits", "learned_traits", "cultural_traits", "scars"]:
		if traits.has(category):
			for trait_id in traits[category]:
				if trait_definitions.has(trait_id):
					var trait_effects: Dictionary = trait_definitions[trait_id].get("effects", {})
					for effect in trait_effects:
						effects[effect] = effects.get(effect, 0.0) + trait_effects[effect]
	
	return effects

## Get specific trait bonus
func get_trait_bonus(pawn_id: int, effect_type: String) -> float:
	var effects: Dictionary = get_trait_effects(pawn_id)
	return effects.get(effect_type, 0.0)

## Check if pawn has a trait
func has_trait(pawn_id: int, trait_id: String) -> bool:
	if not pawn_traits.has(pawn_id):
		return false
	
	var traits: Dictionary = pawn_traits[pawn_id]
	
	for category in ["genetic_traits", "learned_traits", "cultural_traits", "scars"]:
		if traits.has(category) and traits[category].has(trait_id):
			return true
	
	return false


# ==================== UTILITY ====================

func _initialize_pawn_traits(pawn_id: int) -> void:
	pawn_traits[pawn_id] = {
		"genetic_traits": [],
		"learned_traits": [],
		"cultural_traits": [],
		"scars": []
	}


func get_trait_definition(trait_id: String) -> Dictionary:
	if trait_definitions.has(trait_id):
		return trait_definitions[trait_id].duplicate()
	return {}


func get_all_trait_definitions() -> Dictionary:
	return trait_definitions.duplicate()


# ==================== PUBLIC API ====================

## Get pawn's trait summary
func get_trait_summary(pawn_id: int) -> String:
	if not pawn_traits.has(pawn_id):
		return "No traits"
	
	var traits: Dictionary = pawn_traits[pawn_id]
	var summary: PackedStringArray = []
	
	if traits.genetic_traits.size() > 0:
		summary.append("Genetic: " + ", ".join(traits.genetic_traits))
	if traits.learned_traits.size() > 0:
		summary.append("Learned: " + ", ".join(traits.learned_traits))
	if traits.cultural_traits.size() > 0:
		summary.append("Cultural: " + ", ".join(traits.cultural_traits))
	if traits.scars.size() > 0:
		summary.append("Scars: " + ", ".join(traits.scars))
	
	return "\n".join(summary) if summary.size() > 0 else "No traits"

## Clear all data (for world reroll)
func clear() -> void:
	pawn_traits.clear()

## Get statistics
func get_stats() -> Dictionary:
	var total_pawns: int = pawn_traits.size()
	var with_genetic: int = 0
	var with_learned: int = 0
	var with_scar: int = 0
	
	for pawn_id in pawn_traits:
		var traits: Dictionary = pawn_traits[pawn_id]
		if traits.genetic_traits.size() > 0:
			with_genetic += 1
		if traits.learned_traits.size() > 0:
			with_learned += 1
		if traits.scars.size() > 0:
			with_scar += 1
	
	return {
		"total_pawns": total_pawns,
		"with_genetic_traits": with_genetic,
		"with_learned_traits": with_learned,
		"with_scars": with_scar,
		"trait_definitions": trait_definitions.size()
	}
