extends Node
## CombatNarrative - Kenshi-style dynamic text combat logs
##
## Generates gritty, text-based combat narratives:
## - Based on combatants, weapons, damage, outcome
## - LLM-powered or template-based generation
## - Saved to WorldMemory for history
##
## Kenshi style: "Gorne swings his rusted blade, connecting with 
## the wolf's flank. The beast yelps, but the farmer's strike 
## lacks conviction. This will be a long fight."

# Combat narrative cache
var _narrative_cache: Array[Dictionary] = []
const MAX_CACHE_SIZE: int = 100

# Templates for combat phrases
var _combat_templates: Dictionary = {
	"attack_hit": [
		"{attacker} swings {weapon}, connecting with {defender}'s {body_part}.",
		"{attacker} lands a solid blow on {defender} with {weapon}.",
		"{weapon} bites deep into {defender}'s {body_part}.",
		"{attacker}'s strike finds its mark on {defender}.",
	],
	"attack_miss": [
		"{attacker} swings {weapon} wildly, missing {defender}.",
		"{defender} dodges {attacker}'s clumsy attack.",
		"{weapon} whistles through the air as {attacker} overcommits.",
	],
	"critical_hit": [
		"{attacker} delivers a devastating blow to {defender}'s {body_part}!",
		"CRITICAL! {weapon} tears through {defender}'s defenses!",
		"{attacker}'s perfect strike cripples {defender}!",
	],
	"blocked": [
		"{defender} parries {attacker}'s attack with {shield}.",
		"{weapon} glances off {defender}'s armor.",
		"{defender} absorbs the blow with {shield}, barely flinching.",
	],
	"wounded": [
		"{defender} staggers, blood streaming from {body_part}.",
		"{defender} grits teeth against the pain in {body_part}.",
		"{defender}'s vision blurs as {body_part} throbs with agony.",
	],
	"victory": [
		"{victor} stands victorious over {defeated}.",
		"{defeated} collapses, defeated by {victor}.",
		"The battle ends. {victor} prevails.",
	],
	"fleeing": [
		"{fleeing} turns and runs, abandoning the fight.",
		"{fleeing} decides discretion is the better part of valor.",
		"{fleeing} retreats, living to fight another day.",
	]
}

# Body parts for flavor text
var _body_parts: Array[String] = [
	"head", "arm", "leg", "torso", "shoulder", 
	"side", "chest", "back", "thigh", "forearm"
]

# References
@onready var _world_memory: Node = null
@onready var _llm_client: Node = null


func _ready() -> void:
	_world_memory = get_node_or_null("/root/WorldMemory")
	_llm_client = get_node_or_null("/root/LLMClient")


# ==================== NARRATIVE GENERATION ====================

## Generate combat narrative for an attack
func generate_attack_narrative(attacker_name: String, defender_name: String, 
 weapon: String, damage: int, hit: bool, critical: bool = false) -> String:
	
	var template_type: String = "attack_miss"
	if hit:
		template_type = "critical_hit" if critical else "attack_hit"
	
	var template: String = _get_random_template(template_type)
	var body_part: String = _body_parts[randi() % _body_parts.size()]
	
	var narrative: String = template.format({
		"attacker": attacker_name,
		"defender": defender_name,
		"weapon": weapon,
		"body_part": body_part,
		"shield": "shield",
		"damage": damage
	})
	
	# Add wound description for hits
	if hit and damage > 0:
		narrative += " " + _generate_wound_text(defender_name, damage)
	
	_cache_narrative(narrative, "combat_attack")
	
	return narrative


## Generate combat narrative for battle outcome
func generate_battle_outcome(victor_name: String, defeated_name: String, 
 fled: bool = false) -> String:
	
	var template_type: String = "fleeing" if fled else "victory"
	var template: String = _get_random_template(template_type)
	
	var narrative: String = template.format({
		"victor": victor_name,
		"defeated": defeated_name,
		"fleeing": defeated_name
	})
	
	_cache_narrative(narrative, "combat_outcome")
	
	return narrative


## Generate full combat log for a battle
func generate_battle_log(attacker_id: int, defender_id: int, 
 rounds: Array[Dictionary]) -> String:
	
	var log: PackedStringArray = []
	
	# Get names
	var attacker_name: String = _get_name(attacker_id)
	var defender_name: String = _get_name(defender_id)
	
	# Opening
	log.append("=== COMBAT STARTED ===")
	log.append("%s vs %s" % [attacker_name, defender_name])
	log.append("")
	
	# Each round
	for i in range(rounds.size()):
		var round: Dictionary = rounds[i]
		var round_text: String = "Round %d: " % (i + 1)
		
		if round.has("attack_hit"):
			round_text += generate_attack_narrative(
				attacker_name if round.attacker == attacker_id else defender_name,
				defender_name if round.attacker == attacker_id else attacker_name,
				round.get("weapon", "fists"),
				round.get("damage", 0),
				true,
				round.get("critical", false)
			)
		elif round.has("attack_miss"):
			round_text += generate_attack_narrative(
				attacker_name if round.attacker == attacker_id else defender_name,
				defender_name if round.attacker == attacker_id else attacker_name,
				round.get("weapon", "fists"),
				0,
				false
			)
		
		log.append(round_text)
	
	# Outcome
	log.append("")
	var victor: String = attacker_name if rounds[-1].victor == attacker_id else defender_name
	var defeated: String = defender_name if rounds[-1].victor == attacker_id else attacker_name
	log.append(generate_battle_outcome(victor, defeated, rounds[-1].get("fled", false)))
	
	var full_log: String = "\n".join(log)
	
	# Record to WorldMemory
	if _world_memory != null:
		_world_memory.record_event({
			"type": "combat_log",
			"attacker_id": attacker_id,
			"defender_id": defender_id,
			"log": full_log,
			"rounds": rounds.size(),
			"tick": GameManager.tick_count
		})
	
	return full_log


# ==================== LLM-POWERED NARRATIVES ====================

## Generate narrative using LLM (if available)
func generate_llm_narrative(attacker_name: String, defender_name: String,
 attacker_rank: String, defender_rank: String,
 weapon: String, damage: int, outcome: String) -> String:
	
	if _llm_client == null:
		return generate_attack_narrative(attacker_name, defender_name, weapon, damage, true)
	
	var prompt: String = """
Generate a Kenshi-style combat narrative (2-3 sentences):

ATTACKER: {attacker} ({rank})
DEFENDER: {defender} ({rank})
WEAPON: {weapon}
DAMAGE: {damage}
OUTCOME: {outcome}

Style: Gritty, text-based, realistic. Not flowery or heroic.
Example: "Gorne swings his rusted blade, connecting with the wolf's flank. 
The beast yelps, but the farmer's strike lacks conviction."
""".format({
		"attacker": attacker_name,
		"defender": defender_name,
		"rank": attacker_rank,
		"weapon": weapon,
		"damage": damage,
		"outcome": outcome
	})
	
	# Request from LLM
	var response: Dictionary = await _llm_client.request(prompt, {}, "Generate gritty combat text.")
	
	if response.has("content"):
		var narrative: String = response.content
		_cache_narrative(narrative, "combat_llm")
		return narrative
	
	# Fallback to template
	return generate_attack_narrative(attacker_name, defender_name, weapon, damage, true)


# ==================== UTILITY ====================

func _get_random_template(template_type: String) -> String:
	if not _combat_templates.has(template_type):
		return "{attacker} attacks {defender}."
	
	var templates: Array = _combat_templates[template_type]
	return templates[randi() % templates.size()]


func _generate_wound_text(defender_name: String, damage: int) -> String:
	if damage < 10:
		return "{name} winces from the sting.".format({"name": defender_name})
	elif damage < 30:
		return "{name} grits teeth against the pain.".format({"name": defender_name})
	elif damage < 50:
		return "Blood flows from {name}'s wound.".format({"name": defender_name})
	else:
		return "{name} staggers, vision blurring from the brutal impact.".format({"name": defender_name})


func _cache_narrative(narrative: String, narrative_type: String) -> void:
	_narrative_cache.append({
		"narrative": narrative,
		"type": narrative_type,
		"tick": GameManager.tick_count
	})
	
	# Trim cache
	while _narrative_cache.size() > MAX_CACHE_SIZE:
		_narrative_cache.pop_front()


func _get_name(entity_id: int) -> String:
	# Try to get pawn name
	var pawn_spawner: Node = get_node_or_null("/root/Main/WorldViewport/PawnSpawner")
	if pawn_spawner != null and pawn_spawner.has_method("pawn_data_for_id"):
		var data: Node = pawn_spawner.call("pawn_data_for_id", entity_id)
		if data != null and data.has_method("get_display_name"):
			return data.get_display_name()
	
	return "Entity #%d" % entity_id


# ==================== PUBLIC API ====================

## Get cached narratives
func get_cached_narratives(limit: int = 10) -> Array[Dictionary]:
	var start: int = max(0, _narrative_cache.size() - limit)
	var result: Array[Dictionary] = []
	for i in range(start, _narrative_cache.size()):
		if _narrative_cache[i] is Dictionary:
			result.append(_narrative_cache[i])
	return result

## Clear cache (for memory management)
func clear_cache() -> void:
	_narrative_cache.clear()

## Clear all data (for world reroll)
func clear() -> void:
	clear_cache()

## Get statistics
func get_stats() -> Dictionary:
	var by_type: Dictionary = {}
	for entry in _narrative_cache:
		var t: String = entry.get("type", "unknown")
		by_type[t] = by_type.get(t, 0) + 1
	
	return {
		"cached_narratives": _narrative_cache.size(),
		"by_type": by_type
	}
