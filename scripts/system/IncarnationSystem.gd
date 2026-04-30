class_name IncarnationSystem
extends Node

## Incarnation entry flow for new pawns
## Allows choosing region, era, and life context when joining the world

signal incarnation_chosen(pawn_data: Dictionary)

@onready var GameManager = get_node_or_null("/root/GameManager")
@onready var WorldRNG = get_node_or_null("/root/WorldRNG")

## Available regions for incarnation
var available_regions: Array = [
	{"id": 0, "name": "Northern Highlands", "climate": "cold", "danger": 0.3},
	{"id": 1, "name": "Central Plains", "climate": "temperate", "danger": 0.2},
	{"id": 2, "name": "Southern Desert", "climate": "hot", "danger": 0.4},
	{"id": 3, "name": "Eastern Coast", "climate": "mild", "danger": 0.15},
	{"id": 4, "name": "Western Mountains", "climate": "cold", "danger": 0.35},
]

## Available eras for incarnation
var available_eras: Array = [
	{"id": 0, "name": "Ancient Era", "technology": 0.2, "population": 0.3},
	{"id": 1, "name": "Medieval Era", "technology": 0.5, "population": 0.5},
	{"id": 2, "name": "Renaissance Era", "technology": 0.7, "population": 0.6},
	{"id": 3, "name": "Industrial Era", "technology": 0.85, "population": 0.8},
	{"id": 4, "name": "Modern Era", "technology": 1.0, "population": 1.0},
]

## Available life contexts
var available_contexts: Array = [
	{"id": 0, "name": "Peasant", "starting_level": 1, "starting_resources": 10},
	{"id": 1, "name": "Merchant", "starting_level": 2, "starting_resources": 50},
	{"id": 2, "name": "Scholar", "starting_level": 3, "starting_resources": 30},
	{"id": 3, "name": "Warrior", "starting_level": 2, "starting_resources": 40},
	{"id": 4, "name": "Noble", "starting_level": 4, "starting_resources": 100},
]

## Current incarnation choices
var chosen_region: Dictionary = {}
var chosen_era: Dictionary = {}
var chosen_context: Dictionary = {}


## Get available regions
func get_regions() -> Array:
	return available_regions


## Get available eras
func get_eras() -> Array:
	return available_eras


## Get available contexts
func get_contexts() -> Array:
	return available_contexts


## Choose a region
func choose_region(region_id: int) -> void:
	for region in available_regions:
		if region["id"] == region_id:
			chosen_region = region
			break


## Choose an era
func choose_era(era_id: int) -> void:
	for era in available_eras:
		if era["id"] == era_id:
			chosen_era = era
			break


## Choose a life context
func choose_context(context_id: int) -> void:
	for context in available_contexts:
		if context["id"] == context_id:
			chosen_context = context
			break


## Confirm incarnation and create pawn data
func confirm_incarnation() -> Dictionary:
	if chosen_region.is_empty() or chosen_era.is_empty() or chosen_context.is_empty():
		print("[IncarnationSystem] Cannot confirm: missing choices")
		return {}
	
	var pawn_data: Dictionary = {
		"region": chosen_region,
		"era": chosen_era,
		"context": chosen_context,
		"starting_level": chosen_context["starting_level"],
		"starting_resources": chosen_context["starting_resources"],
		"climate_adaptation": {chosen_region["climate"]: 50.0},
		"timestamp": Time.get_unix_time_from_system(),
	}
	
	incarnation_chosen.emit(pawn_data)
	
	print("[IncarnationSystem] Incarnation confirmed: %s from %s in %s" % [
		chosen_context["name"], chosen_region["name"], chosen_era["name"]
	])
	
	return pawn_data


## Reset choices
func reset_choices() -> void:
	chosen_region = {}
	chosen_era = {}
	chosen_context = {}


## Apply incarnation to an existing pawn
func apply_incarnation_to_pawn(pawn: Pawn, incarnation_data: Dictionary) -> bool:
	if pawn == null or not is_instance_valid(pawn):
		return false
	
	var pd: PawnData = pawn.data
	if pd == null:
		return false
	
	var region: Dictionary = incarnation_data.get("region", {})
	var era: Dictionary = incarnation_data.get("era", {})
	var context: Dictionary = incarnation_data.get("context", {})
	
	# Set starting level
	pd.level = incarnation_data.get("starting_level", 1)
	
	# Apply climate adaptation
	var climate_adaptation: Dictionary = incarnation_data.get("climate_adaptation", {})
	for climate in climate_adaptation:
		pd.climate_adaptation[climate] = climate_adaptation[climate]
	
	# Set region
	if not region.is_empty():
		pd.region_id = region["id"]
	
	# Apply era-based bonuses
	if not era.is_empty():
		var tech_level: float = era.get("technology", 0.5)
		# Higher tech era = starting with some skill XP
		for skill in pd.skill_xp:
			pd.skill_xp[skill] = pd.skill_xp.get(skill, 0.0) + tech_level * 10.0
	
	# Apply context-based bonuses
	if not context.is_empty():
		var context_id: int = context["id"]
		match context_id:
			0:  # Peasant
				pd.job_proficiency["forage"] = 20.0
				pd.job_proficiency["chop"] = 15.0
			1:  # Merchant
				pd.job_proficiency["trade"] = 30.0
				pd.trust = {}  # Start with neutral trust
			2:  # Scholar
				pd.job_proficiency["teach"] = 25.0
				pd.skill_trees["knowledge"] = ["basic"]
			3:  # Warrior
				pd.job_proficiency["hunt"] = 25.0
				pd.military_rank = 1  # Soldier
			4:  # Noble
				pd.job_proficiency["lead"] = 30.0
				pd.leadership_role = 1  # Elder
				pd.national_citizenship = 3  # Noble
	
	print("[IncarnationSystem] Applied incarnation to pawn %s" % pd.display_name)
	return true


## Generate random incarnation for AI pawns
func generate_random_incarnation() -> Dictionary:
	var salt: int = GameManager.tick_count if GameManager != null else 0
	var random_region: Dictionary = available_regions[WorldRNG.index_for(&"incarnation:region", available_regions.size(), salt)]
	var random_era: Dictionary = available_eras[WorldRNG.index_for(&"incarnation:era", available_eras.size(), salt + 1)]
	var random_context: Dictionary = available_contexts[WorldRNG.index_for(&"incarnation:context", available_contexts.size(), salt + 2)]
	
	return {
		"region": random_region,
		"era": random_era,
		"context": random_context,
		"starting_level": random_context["starting_level"],
		"starting_resources": random_context["starting_resources"],
		"climate_adaptation": {random_region["climate"]: 50.0},
		"timestamp": salt,
	}
