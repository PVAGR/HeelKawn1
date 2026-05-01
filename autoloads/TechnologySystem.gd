extends Node
## Phase 5: Infinite Technology Tree and Knowledge Discovery
## REFACTORED: Closed-loop research system driven by KnowledgeSystem carriers

# Autoload references
@onready var WorldAI = get_node_or_null("/root/WorldAI")
@onready var KnowledgeSystem = get_node_or_null("/root/KnowledgeSystem")
@onready var GameManager = get_node_or_null("/root/GameManager")
@onready var WorldMemory = get_node_or_null("/root/WorldMemory")

## === CORE DATA STRUCTURES ===

## Hard-coded technology tree - each tech has meaning and purpose
var TECH_TREE: Dictionary = {
# Tier 0: Base (always known)
"fire": {
"name": "Fire Keeping",
"description": "The ability to create and maintain fire for warmth and cooking",
"cost": 0,
"prerequisites": [],
"effect": "unlocks_job:COOK_MEAT,unlocks_job:COOK_BERRIES,unlocks_job:BUILD_FIRE_PIT",
"knowledge_required": KnowledgeSystem.KnowledgeType.FIRE_KEEPING,
"tier": 0
},
"shelter": {
"name": "Basic Shelter",
"description": "Understanding of how to build protective structures",
"cost": 0,
"prerequisites": [],
"effect": "unlocks_job:BUILD_WALL,unlocks_job:BUILD_DOOR",
"knowledge_required": KnowledgeSystem.KnowledgeType.SHELTER_BUILDING,
"tier": 0
},
"foraging": {
"name": "Foraging",
"description": "Knowledge of edible plants and safe gathering practices",
"cost": 0,
"prerequisites": [],
"effect": "unlocks_job:FORAGE,unlocks_job:GATHER_STICK",
"knowledge_required": null,
"tier": 0
},
"stone_tools": {
"name": "Stone Knapping",
"description": "The ancient art of shaping stone into tools",
"cost": 0,
"prerequisites": [],
"effect": "unlocks_job:MINE,unlocks_job:GATHER_FLINT,unlocks_job:CRAFT_KNIFE",
"knowledge_required": KnowledgeSystem.KnowledgeType.TOOL_MAKING,
"tier": 0
},

# Tier 1: Early Survival
"food_preservation": {
"name": "Food Preservation",
"description": "Techniques for storing and preserving food through lean times",
"cost": 50,
"prerequisites": ["fire", "foraging"],
"effect": "unlocks_job:DRY_MEAT,unlocks_job:BUILD_STORAGE_HUT",
"knowledge_required": KnowledgeSystem.KnowledgeType.FOOD_STORAGE,
"tier": 1
},
"basic_agriculture": {
"name": "Basic Agriculture",
"description": "Planting and harvesting crops for reliable food",
"cost": 100,
"prerequisites": ["foraging", "stone_tools"],
"effect": "unlocks_job:PLANT_SEEDS,unlocks_job:HARVEST_CROPS",
"knowledge_required": KnowledgeSystem.KnowledgeType.SEASON_READING,
"tier": 1
},
"tool_crafting": {
"name": "Tool Crafting",
"description": "Advanced techniques for creating specialized tools",
"cost": 75,
"prerequisites": ["stone_tools"],
"effect": "unlocks_job:CRAFT_TORCH,unlocks_job:CRAFT_PICK,unlocks_job:CRAFT_SPEAR",
"knowledge_required": KnowledgeSystem.KnowledgeType.TOOL_MAKING,
"tier": 1
},

# Tier 2: Settlement & Culture
"territorial_marking": {
"name": "Territorial Marking",
"description": "Marking land claims and creating cultural monuments",
"cost": 150,
"prerequisites": ["stone_tools", "shelter"],
"effect": "unlocks_job:BUILD_MARKER_STONE",
"knowledge_required": KnowledgeSystem.KnowledgeType.NAVIGATION,
"tier": 2
},
"ritual_practices": {
"name": "Ritual Practices",
"description": "Building shrines and honoring ancestors",
"cost": 200,
"prerequisites": ["fire", "shelter"],
"effect": "unlocks_job:BUILD_SHRINE",
"knowledge_required": KnowledgeSystem.KnowledgeType.MEMORY_PRESERVATION,
"tier": 2
},
"medicine_basics": {
"name": "Basic Medicine",
"description": "Understanding sickness avoidance and basic healing",
"cost": 120,
"prerequisites": ["foraging"],
"effect": "passive:mood_bonus_5",
"knowledge_required": KnowledgeSystem.KnowledgeType.SICKNESS_AVOIDANCE,
"tier": 2
},

# Tier 3: Advanced
"hunting_mastery": {
"name": "Hunting Mastery",
"description": "Advanced hunting techniques and tracking",
"cost": 180,
"prerequisites": ["tool_crafting", "foraging"],
"effect": "unlocks_job:HUNT,efficiency_bonus:hunt_2x",
"knowledge_required": KnowledgeSystem.KnowledgeType.WINTER_SURVIVAL,
"tier": 3
}
}

## Research progress: settlement_id -> {tech_id: {progress: float, started_tick: int}}
var active_research: Dictionary = {}

## Researched technologies: settlement_id -> [tech_ids]
var researched_technologies: Dictionary = {}

## Auto-research toggle
var auto_research_enabled: bool = true
const BASE_RESEARCH_PROGRESS_PER_TICK: float = 0.5

func _ready() -> void:
if GameManager:
GameManager.game_tick.connect(_on_game_tick)

func _on_game_tick(tick: int) -> void:
_update_all_research()
if auto_research_enabled:
_auto_assign_research()

## === CORE RESEARCH FUNCTIONS ===

func can_research(settlement_id: int, tech_id: String) -> bool:
if not TECH_TREE.has(tech_id):
return false

var tech_data = TECH_TREE[tech_id]

if is_tech_researched(settlement_id, tech_id):
return false

if active_research.has(settlement_id) and active_research[settlement_id].has(tech_id):
return false

for prereq in tech_data.prerequisites:
if not is_tech_researched(settlement_id, prereq):
return false

if tech_data.knowledge_required != null:
if not KnowledgeSystem.has_carrier_with_knowledge_in_settlement(settlement_id, tech_data.knowledge_required):
return false

return true

func get_available_research(settlement_id: int) -> Array:
var available: Array = []
for tech_id in TECH_TREE.keys():
if can_research(settlement_id, tech_id):
available.append(tech_id)
return available

func research_tech(settlement_id: int, tech_id: String) -> Dictionary:
var result = {"success": false, "error": "", "tech_id": tech_id}

if not can_research(settlement_id, tech_id):
result.error = "Cannot research this technology (prerequisites or knowledge missing)"
return result

var tech_data = TECH_TREE[tech_id]

if tech_data.cost > 0:
if not KnowledgeSystem.deduct_colony_knowledge(settlement_id, tech_data.cost):
result.error = "Insufficient knowledge points"
return result

if not active_research.has(settlement_id):
active_research[settlement_id] = {}

active_research[settlement_id][tech_id] = {
"progress": 0.0,
"started_tick": GameManager.current_tick if GameManager else 0
}

if WorldMemory:
WorldMemory.record_event({
"type": "research_started",
"settlement_id": settlement_id,
"tech_id": tech_id,
"tick": GameManager.current_tick if GameManager else 0
})

result.success = true
return result

func complete_research(settlement_id: int, tech_id: String) -> void:
if not active_research.has(settlement_id):
return
if not active_research[settlement_id].has(tech_id):
return

active_research[settlement_id].erase(tech_id)
if active_research[settlement_id].is_empty():
active_research.erase(settlement_id)

if not researched_technologies.has(settlement_id):
researched_technologies[settlement_id] = []
researched_technologies[settlement_id].append(tech_id)

_apply_tech_effects(settlement_id, tech_id)

if WorldMemory:
WorldMemory.record_event({
"type": "technology_researched",
"settlement_id": settlement_id,
"tech_id": tech_id,
"tick": GameManager.current_tick if GameManager else 0
})

func is_tech_researched(settlement_id: int, tech_id: String) -> bool:
if not researched_technologies.has(settlement_id):
return false
return tech_id in researched_technologies[settlement_id]

func _apply_tech_effects(settlement_id: int, tech_id: String) -> void:
var tech_data = TECH_TREE[tech_id]
var effects = tech_data.effect.split(",")
for effect in effects:
var parts = effect.split(":")
if parts.size() < 2:
continue
var effect_type = parts[0]
var effect_value = parts[1]
if effect_type == "unlocks_job":
pass  # Job availability checked dynamically
elif effect_type == "passive":
pass  # To be integrated with Pawn mood system
elif effect_type == "efficiency_bonus":
pass  # To be integrated with work_speed calculations

## === RESEARCH PROGRESSION SYSTEM ===

func _update_all_research() -> void:
for settlement_id in active_research.keys():
var researching = active_research[settlement_id]
for tech_id in researching.keys():
var knowledge_bonus = _calculate_knowledge_bonus(settlement_id, tech_id)
var progress_gain = BASE_RESEARCH_PROGRESS_PER_TICK * (1.0 + knowledge_bonus)
researching[tech_id].progress += progress_gain
if researching[tech_id].progress >= 100.0:
complete_research(settlement_id, tech_id)

func _calculate_knowledge_bonus(settlement_id: int, tech_id: String) -> float:
var bonus: float = 0.0
if TECH_TREE.has(tech_id):
var tech_data = TECH_TREE[tech_id]
if tech_data.knowledge_required != null:
var carrier_count = KnowledgeSystem.get_carrier_count(tech_data.knowledge_required)
bonus = float(carrier_count) * 0.1
return bonus

func _auto_assign_research() -> void:
var settlements: Array = []
if WorldAI and WorldAI.settlements:
settlements = WorldAI.settlements.keys()

for settlement_id in settlements:
if active_research.has(settlement_id) and not active_research[settlement_id].is_empty():
continue

var available = get_available_research(settlement_id)
if available.is_empty():
continue

var cheapest_tech: String = ""
var cheapest_cost: int = 999999

for tech_id in available:
var cost = TECH_TREE[tech_id].cost
if cost < cheapest_cost:
cheapest_cost = cost
cheapest_tech = tech_id

if cheapest_tech != "":
research_tech(settlement_id, cheapest_tech)

## === DEBUG & SAVE/LOAD ===

func debug_print_tree() -> void:
print("\n=== TECHNOLOGY TREE DEBUG ===")
for tech_id in TECH_TREE.keys():
var tech_data = TECH_TREE[tech_id]
var status = "LOCKED"
for sid in researched_technologies.keys():
if tech_id in researched_technologies[sid]:
status = "RESEARCHED (Settlement %d)" % sid
break
for sid in active_research.keys():
if tech_id in active_research[sid]:
var progress = active_research[sid][tech_id].progress
status = "RESEARCHING (%.1f%%)" % progress
break
print(" [%s] %s - Tier %d - Cost: %d" % [status, tech_data.name, tech_data.tier, tech_data.cost])
print("=============================\n")

func to_dict() -> Dictionary:
return {
"researched_technologies": researched_technologies,
"active_research": active_research
}

func from_dict(data: Dictionary) -> void:
researched_technologies = data.get("researched_technologies", {})
active_research = data.get("active_research", {})
