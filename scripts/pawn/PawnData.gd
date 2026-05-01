class_name PawnData
extends RefCounted

## Pure data for a single pawn. The Pawn Node2D reads from this; all future
## systems (save/load, AI, macro view) will treat PawnData as the source of
## truth and Pawn (the Node) as a visual representation.

enum Gender { MALE, FEMALE, OTHER }
enum BodyType { SLIM, AVERAGE, BROAD }
enum HairStyle { NONE, SHORT, MOHAWK, BUN }

## Trainable proficiencies. Higher level -> faster work + more XP per tick on
## that skill type. Pawns earn XP only while doing the matching job.
enum Skill { FORAGING, MINING, CHOPPING, BUILDING, HUNTING }
enum Profession { NONE, FARMER, BUILDER, GATHERER, WARRIOR, SCHOLAR }

## Skill XP curve. Each skill tracked as raw XP; level = floor(xp / XP_PER_LEVEL).
const XP_PER_LEVEL: float = 100.0
## Soft cap. Skills can technically go higher but we display / multiply against
## this as the "mastery" mark.
const SKILL_LEVEL_MAX: int = 20
## Multiplier applied at level SKILL_LEVEL_MAX. Linear interpolation:
##   work_speed = 1.0 + (level / SKILL_LEVEL_MAX) * (SKILL_BONUS_AT_MAX - 1.0)
## At level 20 a skilled pawn works 2.0x as fast as a novice.
const SKILL_BONUS_AT_MAX: float = 2.0
## XP gained per tick of work on the matching skill. Tuned so a fresh pawn
## passes lvl 1 in ~one job cycle and reaches lvl 5 over a few in-game days.
const XP_PER_WORK_TICK: float = 1.5

## Cumulative "liking" (1..LIKING_MAX) per interest lane. Grows only from
## deterministic work and action-skill gains — no RNG in history. Lanes mix
## into the five job-affinity floats (birth baseline + earned blend).
const LIKING_MIN: int = 1
const LIKING_MAX: int = 10000
## Extra sum above all lanes at LIKING_MIN before affinities fully follow earned mix.
const LIKING_BLEND_DENOM: float = 20000.0
const PROFESSION_LIKING_KEYS: Array[String] = [
	"outdoors", "tillage", "industry", "structure", "martial", "circulation", "inquiry",
]
const PAWN_NEURAL_SCRIPT_PATH: String = "res://scripts/pawn/PawnNeuralNetwork.gd"

## Global monotonic id. Reset when the game starts, serialized per save.
static var _next_id: int = 1

var id: int
var display_name: String = ""
var age: int = 25
## Cumulative in-game years lived (float for fractional aging between ticks).
var age_years: float = 0.0
var gender: int = Gender.OTHER
var tile_pos: Vector2i = Vector2i.ZERO

## Display color used by the v1 circle renderer. Will be replaced by a sprite
## once we have pawn art. Kept on the data so it survives save/load.
var color: Color = Color.WHITE
var body_type: int = BodyType.AVERAGE
var hair_style: int = HairStyle.SHORT
var hair_color: Color = Color("#5f4630")
var apparel_color: Color = Color("#5d7ea8")

## Needs (0..100, higher is better). Will decay on tick in Phase 2b.
var hunger: float = 100.0
var rest: float = 100.0
var mood: float = 100.0
var health: float = 100.0
var max_health: float = 100.0

## Stage 1 survival enhancements
var stamina: float = 100.0  # Depletes with work, recovers with rest
var body_temperature: float = 37.0  # Celsius, normal range 36-38
var pain: float = 0.0  # 0-100, affects work efficiency and mood
var exposure_sickness: float = 0.0  # 0-100, from prolonged cold/wet
var hypothermia_risk: float = 0.0  # 0-100, accumulates from cold exposure
var heat_exhaustion_risk: float = 0.0  # 0-100, accumulates from heat exposure

## Injury tracking: injury_type -> severity (0-100)
## Injury types: cut, burn, blunt, broken_bone, frostbite, heat_burn
var injuries: Dictionary = {}

## Stage 1: Job proficiency per job type (0-100)
## Higher proficiency = faster work, better quality output
var job_proficiency: Dictionary = {}

## Stage 1: Overall level (total XP / 100)
## Level unlocks access to more complex jobs and features
var level: int = 1

## Stage 1: Skill trees - branching paths within a profession
## Each profession has skill branches that unlock at certain levels
var skill_trees: Dictionary = {}

## Stage 1: Mastery perks - special abilities at high levels
## Unlocked at level 10, 15, 20 in a skill
var mastery_perks: Array = []

## Stage 1: XP decay tracking - last time a skill was used
## Used to decay unused skills over time
var skill_last_used: Dictionary = {}

## Stage 1: Perception radius (based on level and awareness)
## Higher level = larger perception radius
var perception_radius: float = 50.0

## Stage 1: Location memory - remembers where resources and dangers are
## location_key -> last_seen_tick, resource_type, danger_level
var location_memory: Dictionary = {}

## Stage 2: Family & Trust system
## Family bonds: other_pawn_id -> bond_strength (0-100)
var family_bonds: Dictionary = {}
## Co-presence tracking: other_pawn_id -> ticks_spent_together
var co_presence: Dictionary = {}
## Household ID (-1 if not in a household)
var household_id: int = -1
## Trust with other pawns: other_pawn_id -> trust_level (0-100)
var trust: Dictionary = {}
## Spouse ID (-1 if unmarried)
var spouse_id: int = -1
## Children IDs
var children_ids: Array[int] = []

## Stage 3: Clan & Household Network
## Clan ID (-1 if not in a clan)
var clan_id: int = -1
## Reputation with other clans: clan_id -> reputation (0-100)
var clan_reputation: Dictionary = {}
## Personal reputation: reputation_score (0-100)
var reputation_score: float = 50.0
## Leadership role: NONE, ELDER, CHIEF, WARRIOR_LEADER
var leadership_role: int = 0
## Shared labor contributions: job_type -> contribution_count
var labor_contributions: Dictionary = {}
## Clan influence: influence_score (0-100)
var clan_influence: float = 0.0

## Stage 4: Settlement/Homestead
## Settlement ID (-1 if not in a settlement)
var settlement_id: int = -1
## Homestead tile location (-1 if no homestead)
var homestead_tile: Vector2i = Vector2i(-1, -1)
## Food production contribution: total_food_produced
var food_produced: int = 0
## Building contribution: total_buildings_constructed
var buildings_constructed: int = 0
## Trade relationships: settlement_id -> trade_volume
var trade_relationships: Dictionary = {}
## Settlement role: NONE, FARMER, BUILDER, MERCHANT, GUARD
var settlement_role: int = 0
## Property ownership: tile -> property_type
var owned_properties: Dictionary = {}

## Stage 5: Region/Local Polity
## Region ID (-1 if not in a region)
var region_id: int = -1
## Road construction contributions: tiles_paved
var roads_built: int = 0
## Regional safety rating (0-100)
var regional_safety: float = 50.0
## Customs/traditions known: custom_name -> familiarity (0-100)
var known_customs: Dictionary = {}
## Regional citizenship status: NONE, RESIDENT, CITIZEN, ELDER
var citizenship_status: int = 0
## Regional taxes paid
var taxes_paid: int = 0

## Stage 6: Nation/Country
## Nation ID (-1 if not in a nation)
var nation_id: int = -1
## Law compliance: law_id -> compliance_level (0-100)
var law_compliance: Dictionary = {}
## Cultural identity: culture_name -> affinity (0-100)
var cultural_affinity: Dictionary = {}
## Military service: served_years
var military_service_years: int = 0
## Military rank: NONE, SOLDIER, SERGEANT, OFFICER, GENERAL
var military_rank: int = 0
## Diplomatic standing with other nations: nation_id -> standing (0-100)
var diplomatic_standing: Dictionary = {}
## National citizenship: NONE, SUBJECT, CITIZEN, NOBLE
var national_citizenship: int = 0

## Stage 7: World systems
## Cross-region influence: region_id -> influence (0-100)
var cross_region_influence: Dictionary = {}
## Climate adaptation: climate_type -> adaptation (0-100)
var climate_adaptation: Dictionary = {}
## Mythological knowledge: myth_name -> belief (0-100)
var myth_knowledge: Dictionary = {}
## World events witnessed: event_id -> impact
var world_events_witnessed: Dictionary = {}
## Legacy score: how much the pawn has influenced the world
var legacy_score: float = 0.0

## Phase 4: Historical memory for settlements
## Maps site_id to "RUINS" or "SCAR"
var known_historical_sites: Dictionary[int, String] = {}
## Avoidance modifier for dangerous sites (0.0 to 1.0)
var avoidance_modifier: float = 0.0
## Tick timer for avoidance modifier decay
var avoidance_tick_timer: int = 0

## Phase 4 — Soul & Society: deterministic web identity, append-only legacy.
var unique_id: String = ""
var lineage_id: String = ""
var biography: Array[String] = []
var physical_scars: Array[String] = []
## Settlement key (string) -> standing score for trade / entry hooks.
var settlement_reputation: Dictionary = {}
## When set, wander bias pulls toward this anchor pawn (social squad leader id).
var social_squad_anchor_id: int = -1

## Single-item inventory. Type is Item.Type (NONE = empty hands).
## v1 pawns can only hold one kind of thing at a time; multi-slot / weight
## comes later with proper inventories.
var carrying: int = 0  # Item.Type.NONE
var carrying_qty: int = 0

## Skill XP per Skill enum value. Defaults to 0 for everything; pawns earn it
## by working. Stored as Dictionary so save/load is trivial and so we don't
## have to enumerate skills here.
var skill_xp: Dictionary = {}
## Deterministic Phase 6 action-skill XP (string key -> int).
var skills: Dictionary = {
	"movement": 0,
	"farming": 0,
	"building": 0,
	"gathering": 0,
	"combat": 0,
}
var affinities: Dictionary = {
	"combat": 0.5,
	"farming": 0.5,
	"building": 0.5,
	"crafting": 0.5,
	"diplomacy": 0.5,
}
## Snapshot of `affinities` right after deterministic birth init (or first load).
## Earned job bias lerps from this toward lane-derived weights as liking grows.
var affinity_birth_snapshot: Dictionary = {}
## Lane id (see PROFESSION_LIKING_KEYS) -> int in [LIKING_MIN, LIKING_MAX].
var profession_liking: Dictionary = {}
var current_profession: int = Profession.NONE
var birth_tick: int = 0
var parent_a_id: int = -1
var parent_b_id: int = -1
var children_count: int = 0
var influence: float = 0.0
var military_rank_legacy: String = "grunt"  # Legacy string rank, replaced by int military_rank in Stage 6
var cohort_anchor_id: int = -1
var cohort_job_type: int = -1
var is_cohort_anchor: bool = false

## Work-type allow list (RimWorld-style). If false, this pawn will not *claim*
## that class of open job. Eating, sleeping, and hauling are not jobs; they
## are always available. Toggled from the PawnInfoPanel when a pawn is selected.
var work_forage: bool = true
var work_mine:   bool = true
var work_chop:   bool = true
var work_hunt:   bool = true
var work_build:  bool = true

## Traits: modifiers that affect need decay, skill XP, work speed, etc.
## Each pawn starts with 0-2 traits at spawn.
var traits: Array[Trait] = []

## Mood events: temporary emotional states that affect mood decay and behavior.
## Each event has a type, intensity, and duration.
var mood_events: Array[MoodEvent] = []

# New Trait/Krond bookkeeping (per-request)
## Active traits (Resource-based; may include legacy Trait instances)
var active_traits: Array = []
## Krond currency available to this pawn for purchasing traits
var available_krond: float = 0.0
## Cumulative Krond ever earned by this pawn (for analytics)
var total_krond_earned: float = 0.0

## Deterministic co-presence bond: other pawn id (string key) -> rapport 0..3000.
## Grows when NPCs spend time near each other (same path component); feeds
## reproduction and future player social actions (gift, commend, etc.).
var social_rapport: Dictionary = {}

## Crusader-Kings-style directed opinion: other pawn id (string key) -> -100..100.
## Drifts from shared time near peers (see Main social pass); future: slights,
## favors, battles, succession.
var character_opinions: Dictionary = {}

## Phase 1.1: Big Five Personality Traits (0.0-1.0)
## Openness: creativity, curiosity, preference for variety
var openness: float = 0.5
## Conscientiousness: organization, diligence, self-discipline
var conscientiousness: float = 0.5
## Extraversion: sociability, assertiveness, positive emotions
var extraversion: float = 0.5
## Agreeableness: compassion, cooperativeness, trust
var agreeableness: float = 0.5
## Neuroticism: emotional instability, anxiety, moodiness
var neuroticism: float = 0.5

## Phase 1.2: Deep Memory System
## Episodic memory: significant events (death, birth, discovery, combat)
## event_id -> {type, tick, location, participants, emotional_impact, details}
var episodic_memory: Dictionary = {}
## Semantic memory: learned facts (locations, recipes, social relationships)
## fact_key -> {learned_tick, confidence, source, details}
var semantic_memory: Dictionary = {}
## Spatial memory: map of explored areas with resource locations
## tile_key -> {last_seen_tick, resource_type, danger_level, terrain_type}
var spatial_memory: Dictionary = {}
## Social memory: detailed relationships with other pawns
## other_pawn_id -> {trust, debt, grudge, friendship, last_interaction, interaction_history}
var social_memory: Dictionary = {}
## Memory decay tracking: memory_type -> last_accessed_tick
var memory_access: Dictionary = {}

## Phase 2: Per-Pawn Neural Network (hidden internal state)
var neural_network = null
static var _pawn_neural_script_cache: Script = null

## Phase 1.3: Goal Hierarchy System (Maslow-style needs)
## Active goals with priorities: goal_id -> {type, priority, progress, sub_goals, deadline}
var active_goals: Dictionary = {}
## Goal history: completed and abandoned goals
var goal_history: Array = []
## Current need satisfaction levels (0-100)
var need_satisfaction: Dictionary = {
	"survival": 50.0,  # Food, water, shelter, health
	"safety": 50.0,    # Security, stability, freedom from fear
	"belonging": 50.0, # Social connection, family, friendship
	"esteem": 50.0,    # Respect, status, recognition
	"self_actualization": 50.0  # Growth, creativity, purpose
}
## Need urgency weights (higher = more urgent)
var need_urgency: Dictionary = {
	"survival": 2.0,
	"safety": 1.5,
	"belonging": 1.0,
	"esteem": 0.8,
	"self_actualization": 0.5
}


func _init() -> void:
	id = _next_id
	_next_id += 1
	# Explicit defaults (also on fields) so saves/tools never see unset sentinel bugs.
	settlement_id = -1
	current_profession = Profession.NONE
	birth_tick = int(GameManager.tick_count) if GameManager != null else 0
	initialize_affinities(birth_tick, -1, -1)
	_initialize_personality(birth_tick, parent_a_id, parent_b_id)
	_initialize_neural_network()


func get_max_health() -> float:
	return max_health


## Phase 1.1: Initialize personality traits with inheritance and mutation
func _initialize_personality(birth_tick: int, parent_a: int, parent_b: int) -> void:
	if parent_a >= 0 and parent_b >= 0:
		# Inherit from parents with mutation
		var parent_a_data: PawnData = _get_parent_data(parent_a)
		var parent_b_data: PawnData = _get_parent_data(parent_b)
		
		if parent_a_data != null and parent_b_data != null:
			# Blend parent personalities with mutation
			openness = _blend_with_mutation(parent_a_data.openness, parent_b_data.openness, birth_tick, "openness")
			conscientiousness = _blend_with_mutation(parent_a_data.conscientiousness, parent_b_data.conscientiousness, birth_tick, "conscientiousness")
			extraversion = _blend_with_mutation(parent_a_data.extraversion, parent_b_data.extraversion, birth_tick, "extraversion")
			agreeableness = _blend_with_mutation(parent_a_data.agreeableness, parent_b_data.agreeableness, birth_tick, "agreeableness")
			neuroticism = _blend_with_mutation(parent_a_data.neuroticism, parent_b_data.neuroticism, birth_tick, "neuroticism")
		else:
			# Fallback to random if parent data unavailable
			_generate_random_personality(birth_tick)
	else:
		# No parents: generate random personality
		_generate_random_personality(birth_tick)


## Blend two parent values with small mutation
func _blend_with_mutation(val_a: float, val_b: float, trait_salt: int, trait_name: String) -> float:
	var base: float = (val_a + val_b) / 2.0
	var mutation_strength: float = 0.15  # 15% mutation variance
	var mutation: float = WorldRNG.range_for(
		StringName("personality:%s:%d" % [trait_name, trait_salt]),
		-mutation_strength,
		mutation_strength
	)
	return clamp(base + mutation, 0.0, 1.0)


## Generate random personality traits
func _generate_random_personality(personality_salt: int) -> void:
	openness = WorldRNG.range_for(StringName("personality:openness:%d" % personality_salt), 0.0, 1.0)
	conscientiousness = WorldRNG.range_for(StringName("personality:conscientiousness:%d" % personality_salt), 0.0, 1.0)
	extraversion = WorldRNG.range_for(StringName("personality:extraversion:%d" % personality_salt), 0.0, 1.0)
	agreeableness = WorldRNG.range_for(StringName("personality:agreeableness:%d" % personality_salt), 0.0, 1.0)
	neuroticism = WorldRNG.range_for(StringName("personality:neuroticism:%d" % personality_salt), 0.0, 1.0)


## Static registry for pawn data lookup (set by PawnSpawner at spawn time)
static var _pawn_data_by_id: Dictionary = {}

## Register a pawn data instance for lineage lookup
static func register_pawn_data(data: PawnData) -> void:
	if data != null:
		_pawn_data_by_id[data.id] = data

## Unregister pawn data when pawn dies
static func unregister_pawn_data(pawn_id: int) -> void:
	_pawn_data_by_id.erase(pawn_id)

## Get parent data from static registry
func _get_parent_data(parent_id: int) -> PawnData:
	if parent_id < 0:
		return null
	return _pawn_data_by_id.get(parent_id, null)


## Phase 2: Initialize neural network based on personality
func _initialize_neural_network() -> void:
	var personality_dict: Dictionary = {
		"openness": openness,
		"conscientiousness": conscientiousness,
		"extraversion": extraversion,
		"agreeableness": agreeableness,
		"neuroticism": neuroticism
	}
	neural_network = PawnData.create_neural_network(personality_dict)


## Krond / Trait helpers
func grant_krond(amount: float) -> void:
	# Deterministic currency grant. No RNG.
	available_krond += float(amount)
	total_krond_earned += float(amount)

func can_afford_trait(trait_cost: float) -> bool:
	return available_krond >= float(trait_cost)

func apply_trait(trait_res: Resource) -> bool:
	if trait_res == null:
		return false
	var cost: float = 0.0
	if trait_res.has_method("get") and trait_res.has("krond_cost"):
		cost = float(trait_res.get("krond_cost"))
	elif trait_res.has("krond_cost"):
		cost = float(trait_res.krond_cost)
	if cost > 0.0 and not can_afford_trait(cost):
		return false
	# Deduct and record
	available_krond = maxf(0.0, available_krond - cost)
	# Keep resource around for future effect queries
	active_traits.append(trait_res)
	# Backwards compatibility: if this is the legacy Trait resource, also
	# register it in the old `traits` array so existing modifiers apply.
	if trait_res is Trait:
		traits.append(trait_res)
	return true


static func _load_pawn_neural_script() -> Script:
	if _pawn_neural_script_cache != null:
		return _pawn_neural_script_cache
	var loaded: Resource = ResourceLoader.load(
		PAWN_NEURAL_SCRIPT_PATH,
		"Script",
		ResourceLoader.CACHE_MODE_IGNORE
	)
	if loaded is Script:
		_pawn_neural_script_cache = loaded as Script
	return _pawn_neural_script_cache


static func create_neural_network(personality_dict: Dictionary = {}) -> Variant:
	var neural_script: Script = _load_pawn_neural_script()
	if neural_script == null:
		return null
	return neural_script.new(personality_dict)


## Phase 1.1: Personality-based job preference modifier
## Returns multiplier (0.5-2.0) for job preference based on personality
func get_job_preference_modifier(job_type: String) -> float:
	var modifier: float = 1.0
	
	match job_type:
		"farming":
			# High conscientiousness, low openness prefer farming
			modifier *= 1.0 + (conscientiousness - 0.5) * 0.5
			modifier *= 1.0 - (openness - 0.5) * 0.3
		"building":
			# High conscientiousness prefer building
			modifier *= 1.0 + (conscientiousness - 0.5) * 0.6
		"mining":
			# Low neuroticism, high conscientiousness prefer mining
			modifier *= 1.0 - (neuroticism - 0.5) * 0.4
			modifier *= 1.0 + (conscientiousness - 0.5) * 0.4
		"hunting":
			# High openness, low agreeableness prefer hunting
			modifier *= 1.0 + (openness - 0.5) * 0.5
			modifier *= 1.0 - (agreeableness - 0.5) * 0.3
		"crafting":
			# High openness prefer crafting
			modifier *= 1.0 + (openness - 0.5) * 0.6
		"diplomacy":
			# High extraversion, high agreeableness prefer diplomacy
			modifier *= 1.0 + (extraversion - 0.5) * 0.5
			modifier *= 1.0 + (agreeableness - 0.5) * 0.5
		"combat":
			# Low neuroticism, low agreeableness prefer combat
			modifier *= 1.0 - (neuroticism - 0.5) * 0.4
			modifier *= 1.0 - (agreeableness - 0.5) * 0.3
	
	return clamp(modifier, 0.5, 2.0)


## Phase 1.1: Personality-based social behavior modifier
## Returns multiplier (0.5-2.0) for social interaction propensity
func get_social_propensity() -> float:
	var propensity: float = 1.0
	
	# Extraversion increases social desire
	propensity *= 1.0 + (extraversion - 0.5) * 0.8
	
	# Neuroticism decreases social desire (anxiety)
	propensity *= 1.0 - (neuroticism - 0.5) * 0.4
	
	# Agreeableness increases social desire
	propensity *= 1.0 + (agreeableness - 0.5) * 0.3
	
	return clamp(propensity, 0.5, 2.0)


## Phase 1.1: Personality-based risk tolerance
## Returns risk tolerance (0.0-1.0) based on personality
func get_risk_tolerance() -> float:
	var tolerance: float = 0.5
	
	# High openness increases risk tolerance
	tolerance += (openness - 0.5) * 0.3
	
	# High neuroticism decreases risk tolerance
	tolerance -= (neuroticism - 0.5) * 0.4
	
	# High conscientiousness decreases risk tolerance (cautious)
	tolerance -= (conscientiousness - 0.5) * 0.2
	
	return clamp(tolerance, 0.0, 1.0)


## Phase 1.1: Personality-based learning speed modifier
## Returns multiplier (0.7-1.5) for learning speed based on personality
func get_learning_speed_modifier() -> float:
	var modifier: float = 1.0
	
	# High openness increases learning speed
	modifier *= 1.0 + (openness - 0.5) * 0.4
	
	# High conscientiousness increases learning speed
	modifier *= 1.0 + (conscientiousness - 0.5) * 0.3
	
	# High neuroticism decreases learning speed (distraction)
	modifier *= 1.0 - (neuroticism - 0.5) * 0.2
	
	return clamp(modifier, 0.7, 1.5)


## Phase 1.1: Personality-based mood stability
## Returns mood stability (0.0-1.0) - higher = more stable
func get_mood_stability() -> float:
	var stability: float = 0.5
	
	# Low neuroticism increases stability
	stability -= (neuroticism - 0.5) * 0.6
	
	# High conscientiousness increases stability
	stability += (conscientiousness - 0.5) * 0.2
	
	# High agreeableness increases stability
	stability += (agreeableness - 0.5) * 0.2
	
	return clamp(stability, 0.0, 1.0)


## Phase 1.2: Record an episodic memory (significant event)
func record_episodic_memory(event_type: String, location: Vector2i, participants: Array, emotional_impact: float, details: Dictionary = {}) -> void:
	var event_id: String = "%s_%d_%d" % [event_type, GameManager.tick_count if GameManager != null else 0, id]
	episodic_memory[event_id] = {
		"type": event_type,
		"tick": GameManager.tick_count if GameManager != null else 0,
		"location": location,
		"participants": participants,
		"emotional_impact": emotional_impact,
		"details": details
	}
	memory_access["episodic"] = GameManager.tick_count if GameManager != null else 0


## Phase 1.2: Recall episodic memories by type or emotional impact
func recall_episodic_memories(event_type: String = "", min_impact: float = 0.0, limit: int = 10) -> Array:
	var recalled: Array = []
	var current_tick: int = GameManager.tick_count if GameManager != null else 0
	
	for event_id in episodic_memory:
		var memory = episodic_memory[event_id]
		
		# Filter by type if specified
		if not event_type.is_empty() and memory.get("type", "") != event_type:
			continue
		
		# Filter by emotional impact
		if memory.get("emotional_impact", 0.0) < min_impact:
			continue
		
		# Calculate memory decay (older memories fade)
		var age: int = current_tick - memory.get("tick", 0)
		var decay_factor: float = exp(-age / 10000.0)  # Memories decay over ~10000 ticks
		
		# Only recall if memory is still strong enough
		if decay_factor < 0.1:
			continue
		
		recalled.append({
			"event_id": event_id,
			"memory": memory,
			"decay_factor": decay_factor
		})
	
	# Sort by recency and emotional impact
	recalled.sort_custom(func(a, b): return a.memory.tick > b.memory.tick or (a.memory.tick == b.memory.tick and a.memory.emotional_impact > b.memory.emotional_impact))
	
	# Limit results
	if recalled.size() > limit:
		recalled = recalled.slice(0, limit)
	
	memory_access["episodic"] = current_tick
	return recalled


## Phase 1.2: Learn a semantic fact
func learn_semantic_fact(fact_key: String, details: Dictionary, confidence: float = 1.0, source: String = "observation") -> void:
	var current_tick: int = GameManager.tick_count if GameManager != null else 0
	
	# If fact already exists, update confidence (higher confidence wins)
	if semantic_memory.has(fact_key):
		var existing = semantic_memory[fact_key]
		if confidence > existing.get("confidence", 0.0):
			semantic_memory[fact_key] = {
				"learned_tick": current_tick,
				"confidence": confidence,
				"source": source,
				"details": details
			}
	else:
		semantic_memory[fact_key] = {
			"learned_tick": current_tick,
			"confidence": confidence,
			"source": source,
			"details": details
		}
	
	memory_access["semantic"] = current_tick


## Phase 1.2: Recall semantic fact
func recall_semantic_fact(fact_key: String) -> Dictionary:
	if not semantic_memory.has(fact_key):
		return {}
	
	var fact = semantic_memory[fact_key]
	var current_tick: int = GameManager.tick_count if GameManager != null else 0
	
	# Check if fact has decayed
	var age: int = current_tick - fact.get("learned_tick", 0)
	var decay_factor: float = exp(-age / 20000.0)  # Semantic memories last longer
	
	if decay_factor < 0.1:
		# Fact has been forgotten
		semantic_memory.erase(fact_key)
		return {}
	
	memory_access["semantic"] = current_tick
	return fact


## Phase 1.2: Update spatial memory for a tile
func update_spatial_memory(tile: Vector2i, resource_type: String = "", danger_level: float = 0.0, terrain_type: String = "") -> void:
	var tile_key: String = "%d,%d" % [tile.x, tile.y]
	var current_tick: int = GameManager.tick_count if GameManager != null else 0
	
	spatial_memory[tile_key] = {
		"last_seen_tick": current_tick,
		"resource_type": resource_type,
		"danger_level": danger_level,
		"terrain_type": terrain_type
	}
	
	memory_access["spatial"] = current_tick


## Phase 1.2: Recall spatial memory for nearby tiles
func recall_nearby_spatial_memory(center: Vector2i, radius: int) -> Dictionary:
	var nearby: Dictionary = {}
	var current_tick: int = GameManager.tick_count if GameManager != null else 0
	
	for dx in range(-radius, radius + 1):
		for dy in range(-radius, radius + 1):
			var tile: Vector2i = center + Vector2i(dx, dy)
			var tile_key: String = "%d,%d" % [tile.x, tile.y]
			
			if spatial_memory.has(tile_key):
				var memory = spatial_memory[tile_key]
				var age: int = current_tick - memory.get("last_seen_tick", 0)
				
				# Spatial memories decay faster (geographic knowledge becomes outdated)
				var decay_factor: float = exp(-age / 5000.0)
				
				if decay_factor >= 0.1:
					nearby[tile_key] = {
						"tile": tile,
						"memory": memory,
						"decay_factor": decay_factor
					}
	
	memory_access["spatial"] = current_tick
	return nearby


## Phase 1.2: Update social memory for another pawn
func update_social_memory(other_pawn_id: int, trust_change: float = 0.0, debt_change: float = 0.0, grudge_change: float = 0.0, friendship_change: float = 0.0, interaction_type: String = "") -> void:
	var current_tick: int = GameManager.tick_count if GameManager != null else 0
	
	if not social_memory.has(other_pawn_id):
		social_memory[other_pawn_id] = {
			"trust": 50.0,
			"debt": 0.0,
			"grudge": 0.0,
			"friendship": 0.0,
			"last_interaction": current_tick,
			"interaction_history": []
		}
	
	var memory = social_memory[other_pawn_id]
	
	# Update values with clamping
	memory.trust = clamp(memory.trust + trust_change, 0.0, 100.0)
	memory.debt = clamp(memory.debt + debt_change, -100.0, 100.0)
	memory.grudge = clamp(memory.grudge + grudge_change, 0.0, 100.0)
	memory.friendship = clamp(memory.friendship + friendship_change, 0.0, 100.0)
	memory.last_interaction = current_tick
	
	# Record interaction
	if not interaction_type.is_empty():
		memory.interaction_history.append({
			"type": interaction_type,
			"tick": current_tick
		})
		
		# Limit interaction history to last 50 interactions
		if memory.interaction_history.size() > 50:
			memory.interaction_history = memory.interaction_history.slice(-50)
	
	memory_access["social"] = current_tick


## Phase 1.2: Recall social memory for another pawn
func recall_social_memory(other_pawn_id: int) -> Dictionary:
	if not social_memory.has(other_pawn_id):
		return {
			"trust": 50.0,
			"debt": 0.0,
			"grudge": 0.0,
			"friendship": 0.0,
			"last_interaction": -1,
			"interaction_history": []
		}
	
	var memory = social_memory[other_pawn_id]
	var current_tick: int = GameManager.tick_count if GameManager != null else 0
	
	# Decay social memories over time
	var age: int = current_tick - memory.get("last_interaction", 0)
	var decay_factor: float = exp(-age / 15000.0)  # Social memories last ~15000 ticks
	
	# Apply decay to emotional values
	if decay_factor < 1.0:
		memory.trust = lerp(50.0, memory.trust, decay_factor)
		memory.grudge = lerp(0.0, memory.grudge, decay_factor)
		memory.friendship = lerp(0.0, memory.friendship, decay_factor)
	
	memory_access["social"] = current_tick
	return memory


## Phase 1.2: Decay all memories periodically
func decay_memories() -> void:
	var current_tick: int = GameManager.tick_count if GameManager != null else 0
	
	# Decay episodic memories
	var episodic_to_remove: Array = []
	for event_id in episodic_memory:
		var memory = episodic_memory[event_id]
		var age: int = current_tick - memory.get("tick", 0)
		if age > 20000:  # Remove very old episodic memories
			episodic_to_remove.append(event_id)
	
	for event_id in episodic_to_remove:
		episodic_memory.erase(event_id)
	
	# Decay semantic memories
	var semantic_to_remove: Array = []
	for fact_key in semantic_memory:
		var fact = semantic_memory[fact_key]
		var age: int = current_tick - fact.get("learned_tick", 0)
		if age > 50000:  # Remove very old semantic memories
			semantic_to_remove.append(fact_key)
	
	for fact_key in semantic_to_remove:
		semantic_memory.erase(fact_key)
	
	# Decay spatial memories
	var spatial_to_remove: Array = []
	for tile_key in spatial_memory:
		var memory = spatial_memory[tile_key]
		var age: int = current_tick - memory.get("last_seen_tick", 0)
		if age > 10000:  # Remove outdated spatial memories
			spatial_to_remove.append(tile_key)
	
	for tile_key in spatial_to_remove:
		spatial_memory.erase(tile_key)


## Phase 1.3: Update need satisfaction based on current state
func update_need_satisfaction() -> void:
	# Survival: based on hunger, rest, health
	var survival_score: float = (hunger + rest + health) / 3.0
	need_satisfaction["survival"] = survival_score
	
	# Safety: based on mood, regional safety, recent threats
	var safety_score: float = mood * 0.6 + regional_safety * 0.4
	need_satisfaction["safety"] = safety_score
	
	# Belonging: based on social rapport, household status, clan membership
	var belonging_score: float = 50.0
	if household_id >= 0:
		belonging_score += 20.0
	if clan_id >= 0:
		belonging_score += 15.0
	# Add social rapport average
	var total_rapport: float = 0.0
	var rapport_count: int = 0
	for other_id in social_rapport:
		total_rapport += social_rapport[other_id]
		rapport_count += 1
	if rapport_count > 0:
		belonging_score += (total_rapport / rapport_count / 3000.0) * 15.0
	need_satisfaction["belonging"] = clamp(belonging_score, 0.0, 100.0)
	
	# Esteem: based on reputation, leadership role, skill levels
	var esteem_score: float = reputation_score * 0.5
	if leadership_role > 0:
		esteem_score += 20.0 * leadership_presence_multiplier()
	# Add skill level contribution
	var total_skill_xp: float = 0.0
	for skill in skill_xp:
		total_skill_xp += skill_xp[skill]
	esteem_score += (total_skill_xp / 1000.0) * 10.0
	need_satisfaction["esteem"] = clamp(esteem_score, 0.0, 100.0)
	
	# Self-actualization: based on completed goals, mastery perks, legacy
	var self_actualization_score: float = legacy_score * 0.3
	self_actualization_score += mastery_perks.size() * 5.0
	self_actualization_score += goal_history.size() * 2.0
	need_satisfaction["self_actualization"] = clamp(self_actualization_score, 0.0, 100.0)


## Phase 1.3: Get most urgent unmet need
func get_most_urgent_need() -> String:
	var most_urgent: String = "survival"
	var highest_urgency: float = -1.0
	
	for need in need_satisfaction:
		var satisfaction: float = need_satisfaction[need]
		var urgency: float = need_urgency.get(need, 1.0)
		var urgency_score: float = (100.0 - satisfaction) * urgency
		
		if urgency_score > highest_urgency:
			highest_urgency = urgency_score
			most_urgent = need
	
	return most_urgent


## Phase 1.3: Add a new goal
func add_goal(goal_type: String, priority: float = 1.0, deadline: int = -1, details: Dictionary = {}) -> String:
	var goal_id: String = "%s_%d_%d" % [goal_type, GameManager.tick_count if GameManager != null else 0, id]
	active_goals[goal_id] = {
		"type": goal_type,
		"priority": priority,
		"progress": 0.0,
		"sub_goals": [],
		"deadline": deadline,
		"created_tick": GameManager.tick_count if GameManager != null else 0,
		"details": details
	}
	return goal_id


## Phase 1.3: Complete a goal
func complete_goal(goal_id: String, success: bool = true) -> void:
	if not active_goals.has(goal_id):
		return
	
	var goal = active_goals[goal_id]
	goal_history.append({
		"type": goal.type,
		"success": success,
		"completed_tick": GameManager.tick_count if GameManager != null else 0,
		"priority": goal.priority,
		"details": goal.details
	})
	
	active_goals.erase(goal_id)
	
	# Boost self-actualization on successful goal completion
	if success:
		need_satisfaction["self_actualization"] = clamp(need_satisfaction["self_actualization"] + 5.0, 0.0, 100.0)


## Phase 1.3: Abandon a goal
func abandon_goal(goal_id: String, reason: String = "") -> void:
	if not active_goals.has(goal_id):
		return
	
	var goal = active_goals[goal_id]
	goal_history.append({
		"type": goal.type,
		"success": false,
		"abandoned_tick": GameManager.tick_count if GameManager != null else 0,
		"priority": goal.priority,
		"reason": reason,
		"details": goal.details
	})
	
	active_goals.erase(goal_id)


## Phase 1.3: Update goal progress
func update_goal_progress(goal_id: String, progress_delta: float) -> void:
	if not active_goals.has(goal_id):
		return
	
	var goal = active_goals[goal_id]
	goal.progress = clamp(goal.progress + progress_delta, 0.0, 100.0)
	
	# Auto-complete if progress reaches 100%
	if goal.progress >= 100.0:
		complete_goal(goal_id, true)


## Phase 1.3: Get highest priority active goal
func get_highest_priority_goal() -> Dictionary:
	var highest_priority: float = -1.0
	var best_goal: Dictionary = {}
	
	for goal_id in active_goals:
		var goal = active_goals[goal_id]
		var adjusted_priority: float = goal.priority
		
		# Adjust priority based on deadline urgency
		if goal.deadline > 0:
			var current_tick: int = GameManager.tick_count if GameManager != null else 0
			var ticks_remaining: int = goal.deadline - current_tick
			if ticks_remaining < 100:
				adjusted_priority *= 2.0  # Urgent deadline
			elif ticks_remaining < 500:
				adjusted_priority *= 1.5
		
		if adjusted_priority > highest_priority:
			highest_priority = adjusted_priority
			best_goal = goal
			best_goal["goal_id"] = goal_id
	
	return best_goal


## Phase 1.3: Generate goals based on unmet needs
func generate_goals_from_needs() -> void:
	var urgent_need: String = get_most_urgent_need()
	var current_tick: int = GameManager.tick_count if GameManager != null else 0
	
	match urgent_need:
		"survival":
			# Generate survival goals based on lowest survival stat
			if hunger < 40.0:
				add_goal("find_food", 2.5, current_tick + 500, {"need": "hunger"})
			if rest < 40.0:
				add_goal("find_rest", 2.5, current_tick + 300, {"need": "rest"})
			if health < 40.0:
				add_goal("heal", 2.0, current_tick + 1000, {"need": "health"})
		"safety":
			# Generate safety goals
			if regional_safety < 30.0:
				add_goal("improve_safety", 1.5, current_tick + 2000, {"need": "safety"})
			if mood < 30.0:
				add_goal("improve_mood", 1.5, current_tick + 1000, {"need": "mood"})
		"belonging":
			# Generate belonging goals
			if household_id < 0:
				add_goal("join_household", 1.2, current_tick + 3000, {"need": "belonging"})
			if clan_id < 0:
				add_goal("join_clan", 1.0, current_tick + 5000, {"need": "belonging"})
		"esteem":
			# Generate esteem goals
			if reputation_score < 40.0:
				add_goal("build_reputation", 1.0, current_tick + 4000, {"need": "esteem"})
			if leadership_role == 0:
				add_goal("seek_leadership", 0.8, current_tick + 6000, {"need": "esteem"})
		"self_actualization":
			# Generate self-actualization goals
			if mastery_perks.size() < 3:
				add_goal("master_skill", 0.7, current_tick + 8000, {"need": "self_actualization"})
			if legacy_score < 20.0:
				add_goal("leave_legacy", 0.6, current_tick + 10000, {"need": "self_actualization"})


## Phase 1.3: Clean up expired or completed goals
func cleanup_goals() -> void:
	var current_tick: int = GameManager.tick_count if GameManager != null else 0
	var goals_to_remove: Array = []
	
	for goal_id in active_goals:
		var goal = active_goals[goal_id]
		
		# Remove if deadline passed
		if goal.deadline > 0 and current_tick > goal.deadline:
			abandon_goal(goal_id, "deadline_passed")
			goals_to_remove.append(goal_id)
	
	# Also remove goals that are no longer relevant
	for goal_id in active_goals:
		if goal_id in goals_to_remove:
			continue
		var goal = active_goals[goal_id]
		
		# If survival need is met, remove survival goals
		if goal.type == "find_food" and hunger > 70.0:
			complete_goal(goal_id, true)
		elif goal.type == "find_rest" and rest > 70.0:
			complete_goal(goal_id, true)


## Phase 1.4: Utility-based decision making
## Calculate utility value for a potential action
func calculate_action_utility(action_type: String, context: Dictionary = {}) -> float:
	var utility: float = 0.0
	
	# Factor 1: Need satisfaction (primary driver)
	var need_factor: float = _calculate_need_factor(action_type)
	utility += need_factor * 3.0
	
	# Factor 2: Personality alignment
	var personality_factor: float = _calculate_personality_factor(action_type)
	utility += personality_factor * 1.5
	
	# Factor 3: Social pressure
	var social_factor: float = _calculate_social_factor(action_type, context)
	utility += social_factor * 1.0
	
	# Factor 4: Environmental context
	var environment_factor: float = _calculate_environment_factor(action_type, context)
	utility += environment_factor * 0.8

	# Factor 5: Role affinity (stable, deterministic lane preference)
	var role_affinity_factor: float = _calculate_role_affinity_factor(action_type, context)
	utility += role_affinity_factor * 0.7
	
	# Factor 6: Past outcomes (learning)
	var learning_factor: float = _calculate_learning_factor(action_type)
	utility += learning_factor * 0.5

	# Factor 7: Memory confidence (semantic + short-horizon context signal)
	var memory_confidence_factor: float = _calculate_memory_confidence_factor(action_type, context)
	utility += memory_confidence_factor * 0.6
	
	# Factor 8: Risk assessment
	var risk_factor: float = _calculate_risk_factor(action_type, context)
	utility *= (1.0 - risk_factor * 0.3)  # Reduce utility for high-risk actions

	# Factor 9: Neural + human-intent parity (same stack for NPC and incarnated player)
	if context.has("parity_utility") and context["parity_utility"] is Dictionary:
		var pu: Dictionary = context["parity_utility"] as Dictionary
		utility += float(pu.get(action_type, 0.0)) * 1.15
	
	return utility


## Calculate need-based utility factor for an action
func _calculate_need_factor(action_type: String) -> float:
	var factor: float = 0.0
	var urgent_need: String = get_most_urgent_need()
	var need_satisfaction_level: float = need_satisfaction.get(urgent_need, 50.0)
	
	# Higher factor when need is less satisfied (more urgent)
	var urgency: float = (100.0 - need_satisfaction_level) / 100.0
	
	match action_type:
		"eat", "forage", "hunt":
			if urgent_need == "survival" and hunger < 50.0:
				factor = urgency * 2.0
		"sleep", "rest":
			if urgent_need == "survival" and rest < 50.0:
				factor = urgency * 2.0
		"build_shelter", "fortify":
			if urgent_need == "safety":
				factor = urgency * 1.5
		"socialize", "talk":
			if urgent_need == "belonging":
				factor = urgency * 1.5
		"work", "craft", "build":
			if urgent_need == "esteem":
				factor = urgency * 1.2
		"explore", "discover":
			if urgent_need == "self_actualization":
				factor = urgency * 1.0
	
	return clamp(factor, 0.0, 1.0)


## Calculate personality-based utility factor for an action
func _calculate_personality_factor(action_type: String) -> float:
	var factor: float = 0.5  # Base factor
	
	match action_type:
		"explore", "discover", "innovate":
			factor = openness
		"work", "craft", "build":
			factor = conscientiousness
		"socialize", "talk", "trade":
			factor = extraversion
		"help", "cooperate", "share":
			factor = agreeableness
		"fight", "defend", "hunt":
			factor = 1.0 - neuroticism  # Low neuroticism = higher utility
		"hide", "flee":
			factor = neuroticism  # High neuroticism = higher utility
	
	return factor


func _calculate_role_affinity_factor(action_type: String, context: Dictionary) -> float:
	var affinity_key: String = _resolve_affinity_key_for_action(action_type)
	var derived_affinity: float = 0.5
	if affinity_key != "":
		derived_affinity = clampf(float(affinities.get(affinity_key, 0.5)), 0.0, 1.0)
	var context_affinity: float = derived_affinity
	if context.has("role_affinity"):
		context_affinity = clampf(float(context.role_affinity), 0.0, 1.0)
	return clampf(lerpf(derived_affinity, context_affinity, 0.6), 0.0, 1.0)


func _resolve_affinity_key_for_action(action_type: String) -> String:
	match action_type:
		"forage", "gather", "harvest", "farm":
			return "farming"
		"hunt", "fight", "challenge", "defend":
			return "combat"
		"build", "build_shelter", "fortify", "construct":
			return "building"
		"mine", "mine_wall", "craft", "refine", "work":
			return "crafting"
		"trade", "socialize", "talk", "teach", "help", "cooperate":
			return "diplomacy"
		_:
			return ""


## Calculate social pressure factor for an action
func _calculate_social_factor(action_type: String, context: Dictionary) -> float:
	var factor: float = 0.0
	
	# Check if other pawns are nearby doing similar actions
	var nearby_pawns: Array = context.get("nearby_pawns", [])
	var similar_actions: int = 0
	
	for pawn_data in nearby_pawns:
		if pawn_data is Dictionary and pawn_data.has("current_action"):
			if pawn_data.current_action == action_type:
				similar_actions += 1
	
	# Social conformity: moderate utility boost for following crowd
	if similar_actions > 0:
		var conformity: float = agreeableness * 0.3
		factor += conformity * min(similar_actions / 3.0, 1.0)
	
	# Social pressure from authority
	if context.has("authority_present") and context.authority_present:
		if action_type in ["work", "build", "defend"]:
			factor += conscientiousness * 0.4
	
	# Social obligation (debts, favors)
	if context.has("social_obligation") and context.social_obligation:
		factor += 0.5

	# Internal rapport/trust memory: social actions become more attractive when
	# bonds are present, while combative choices are damped by trust.
	var rapport_total: float = 0.0
	var rapport_n: int = 0
	for peer_id in social_rapport:
		rapport_total += float(social_rapport[peer_id])
		rapport_n += 1
	var rapport_norm: float = 0.0
	if rapport_n > 0:
		rapport_norm = clampf((rapport_total / float(rapport_n)) / 3000.0, 0.0, 1.0)
	var trust_total: float = 0.0
	var trust_n: int = 0
	for peer_id in trust:
		trust_total += float(trust[peer_id])
		trust_n += 1
	var trust_norm: float = 0.5
	if trust_n > 0:
		trust_norm = clampf((trust_total / float(trust_n)) / 100.0, 0.0, 1.0)
	if action_type in ["socialize", "talk", "help", "cooperate", "trade"]:
		factor += rapport_norm * 0.25
		factor += trust_norm * 0.2
	if action_type in ["fight", "challenge"]:
		factor += (1.0 - trust_norm) * 0.2
	
	return clamp(factor, 0.0, 1.0)


## Calculate environmental context factor for an action
func _calculate_environment_factor(action_type: String, context: Dictionary) -> float:
	var factor: float = 0.5
	
	# Time of day
	var is_night: bool = context.get("is_night", false)
	match action_type:
		"sleep", "rest":
			factor = 1.0 if is_night else 0.3
		"work", "build", "explore":
			factor = 0.3 if is_night else 0.8
	
	# Weather conditions
	var weather: String = context.get("weather", "clear")
	match action_type:
		"forage", "hunt", "explore", "wander":
			if weather == "storm":
				factor = 0.2
			elif weather == "rain":
				factor = 0.5
			elif weather == "gusty":
				factor = 0.55
			elif weather == "overcast":
				factor = 0.72
		"work", "build":
			if weather == "storm":
				factor = 0.1
			elif weather == "rain":
				factor = 0.4
			elif weather == "gusty":
				factor = 0.45
			elif weather == "overcast":
				factor = 0.65
		"teach", "challenge", "socialize", "talk":
			if weather == "storm" or weather == "gusty":
				factor = 0.55
	
	# Resource availability
	var resources_available: bool = context.get("resources_available", true)
	if not resources_available and action_type in ["forage", "mine", "chop"]:
		factor = 0.1

	# Settlement pressure steers labor priorities deterministically.
	var settlement_pressure: float = clampf(float(context.get("settlement_pressure", 0.5)), 0.0, 1.0)
	if action_type in ["work", "build", "forage", "mine", "chop", "hunt", "trade"]:
		factor += settlement_pressure * 0.35
	elif action_type in ["sleep", "rest", "socialize", "talk"]:
		factor -= settlement_pressure * 0.2
	
	return clamp(factor, 0.0, 1.0)


## Calculate learning factor based on past outcomes
func _calculate_learning_factor(action_type: String) -> float:
	var factor: float = 0.5
	
	# Check episodic memory for similar past actions
	var past_actions: Array = recall_episodic_memories(action_type, 0.3, 20)
	
	if past_actions.is_empty():
		return factor  # No past experience, neutral
	
	var success_count: int = 0
	var failure_count: int = 0
	
	for memory_data in past_actions:
		var memory = memory_data.memory
		var success: bool = memory.details.get("success", true)
		if success:
			success_count += 1
		else:
			failure_count += 1
	
	var total_attempts: int = success_count + failure_count
	if total_attempts == 0:
		return factor
	
	var success_rate: float = float(success_count) / float(total_attempts)
	
	# High openness reduces learning from past failures (more willing to try again)
	var openness_modifier: float = 1.0 - (openness * 0.3)
	
	# High conscientiousness increases learning from past (more methodical)
	var conscientiousness_modifier: float = 1.0 + (conscientiousness * 0.2)
	
	factor = success_rate * conscientiousness_modifier * openness_modifier
	
	return clamp(factor, 0.0, 1.0)


func _calculate_memory_confidence_factor(action_type: String, context: Dictionary) -> float:
	var semantic_confidence: float = 0.5
	var fact_key: String = "action_success:" + action_type
	var semantic_fact: Dictionary = recall_semantic_fact(fact_key)
	if not semantic_fact.is_empty():
		semantic_confidence = clampf(float(semantic_fact.get("confidence", 0.5)), 0.0, 1.0)
	var context_confidence: float = semantic_confidence
	if context.has("memory_confidence"):
		context_confidence = clampf(float(context.memory_confidence), 0.0, 1.0)
	var danger_level: float = clampf(float(context.get("danger_level", 0.0)), 0.0, 1.0)
	var blended: float = lerpf(semantic_confidence, context_confidence, 0.5)
	return clampf(blended * (1.0 - danger_level * 0.35), 0.0, 1.0)


## Calculate risk factor for an action
func _calculate_risk_factor(action_type: String, context: Dictionary) -> float:
	var risk: float = 0.0
	
	# Base risk by action type
	match action_type:
		"fight", "hunt", "explore_unknown":
			risk = 0.7
		"forage", "mine", "chop":
			risk = 0.3
		"build", "craft", "socialize":
			risk = 0.1
		"sleep", "rest":
			risk = 0.2
	
	# Environmental danger
	var danger_level: float = context.get("danger_level", 0.0)
	risk += danger_level * 0.5
	
	# Health status
	var health_percentage: float = get_health_percentage()
	if health_percentage < 30.0:
		risk += 0.3  # Higher risk when injured
	
	# Personality risk tolerance
	var risk_tolerance: float = get_risk_tolerance()
	risk *= (1.0 - risk_tolerance * 0.5)  # High risk tolerance reduces perceived risk
	
	return clamp(risk, 0.0, 1.0)


## Phase 1.4: Choose best action from available options
func choose_best_action(available_actions: Array, context: Dictionary = {}) -> Dictionary:
	var best_action: Dictionary = {}
	var highest_utility: float = -1.0
	
	for action in available_actions:
		if action is Dictionary and action.has("type"):
			var action_type: String = action.type
			var utility: float = calculate_action_utility(action_type, context)
			
			if utility > highest_utility:
				highest_utility = utility
				best_action = action
				best_action["utility"] = utility
	
	return best_action


## Phase 1.4: Record action outcome for learning
func record_action_outcome(action_type: String, success: bool, context: Dictionary = {}) -> void:
	var emotional_impact: float = 10.0 if success else -5.0
	
	# Record as episodic memory
	record_episodic_memory(
		"action_" + action_type,
		context.get("location", tile_pos),
		context.get("participants", []),
		emotional_impact,
		{
			"action_type": action_type,
			"success": success,
			"context": context
		}
	)
	
	# Update learning based on outcome
	if success:
		# Reinforce successful action
		var fact_key: String = "action_success:" + action_type
		var current_confidence: float = recall_semantic_fact(fact_key).get("confidence", 0.5)
		learn_semantic_fact(fact_key, {"action_type": action_type}, clamp(current_confidence + 0.1, 0.0, 1.0), "experience")
	else:
		# Reduce confidence in failed action
		var fact_key: String = "action_success:" + action_type
		var current_confidence: float = recall_semantic_fact(fact_key).get("confidence", 0.5)
		learn_semantic_fact(fact_key, {"action_type": action_type}, clamp(current_confidence - 0.15, 0.0, 1.0), "experience")


func get_health_percentage() -> float:
	if max_health <= 0.0:
		return 0.0
	return clamp(health / max_health, 0.0, 1.0)


## Phase 4: Update historical memory for settlements
func update_historical_memory(site_id: int, state: String) -> void:
	known_historical_sites[site_id] = state
	
	if state == "SCAR":
		avoidance_modifier = 0.3
		avoidance_tick_timer = 30
	elif state == "RUINS":
		if current_profession == Profession.BUILDER:
			# Increase job priority for builders near ruins
			pass
	
	if WorldMemory != null:
		WorldMemory.record_event({
			"type": "pawn_historical_memory_update",
			"pawn_id": id,
			"site_id": site_id,
			"state": state,
			"avoidance_modifier": avoidance_modifier,
			"tick": GameManager.tick_count if GameManager != null else 0
		})


## Phase 4: Process tick for historical memory decay
func process_tick(delta: float) -> void:
	if avoidance_tick_timer > 0:
		avoidance_tick_timer -= 1
		if avoidance_tick_timer <= 0:
			avoidance_modifier = 0.0


# ==================== traits ====================

## Add a trait to this pawn. Traits modify various multipliers.
func add_trait(new_trait: Trait) -> void:
	if new_trait != null and not traits.has(new_trait):
		traits.append(new_trait)


## Get cumulative multiplier for a specific stat across all traits.
## Example: get_trait_mult("hunger_decay_mult") -> 1.2 if traits add 20%.
func get_trait_mult(stat_name: String) -> float:
	var mult: float = 1.0
	for trait_item in traits:
		if trait_item == null:
			continue
		match stat_name:
			"hunger_decay_mult":
				mult *= trait_item.hunger_decay_mult
			"rest_decay_mult":
				mult *= trait_item.rest_decay_mult
			"mood_decay_mult":
				mult *= trait_item.mood_decay_mult
			"health_max_mult":
				mult *= trait_item.health_max_mult
			"skill_xp_mult":
				mult *= trait_item.skill_xp_mult
			"work_speed_mult":
				mult *= trait_item.work_speed_mult
			"injury_chance_mult":
				mult *= trait_item.injury_chance_mult
			"damage_taken_mult":
				mult *= trait_item.damage_taken_mult
	return mult


## Check if this pawn has a trait of the given type.
func has_trait(trait_type: int) -> bool:
	for trait_item in traits:
		if trait_item == null:
			continue
		if trait_item.trait_type == trait_type:
			return true
	return false


## Get trait display string for UI.
func traits_display() -> String:
	if traits.is_empty():
		return "No traits"
	var names: PackedStringArray = []
	for trait_item in traits:
		if trait_item == null:
			continue
		names.append(trait_item.display_name)
	return ", ".join(names)


# ==================== mood events ====================

## Add a mood event (e.g., joy, sorrow, stress) that affects mood temporarily.
func add_mood_event(event_type: int, intensity: float = 50.0, duration_ticks: int = 300) -> void:
	var event := MoodEvent.new(event_type, intensity, duration_ticks)
	mood_events.append(event)


## Get the total mood impact (delta per tick) from all active mood events.
func get_mood_event_impact() -> float:
	var total_impact: float = 0.0
	for event in mood_events:
		total_impact += event.mood_impact()
	return total_impact


## Process mood event decay. Returns true if there are any events left.
func process_mood_events() -> bool:
	var expired: Array[int] = []
	for i in range(mood_events.size()):
		if mood_events[i].decay_tick():
			expired.append(i)
	# Remove expired events in reverse order to avoid index issues
	for i in range(expired.size() - 1, -1, -1):
		mood_events.remove_at(expired[i])
	return not mood_events.is_empty()


## Get current crisis level (0.0 = fine, 1.0 = collapse). Based on mood and recent events.
func get_crisis_level() -> float:
	var crisis: float = 0.0
	# Mood directly contributes: low mood = high crisis
	var mood_crisis: float = 1.0 - (clamp(mood, 0.0, 100.0) / 100.0)  # 0.0 at mood 100, 1.0 at mood 0
	crisis += mood_crisis * 0.5
	# Despair events spike crisis immediately
	for event in mood_events:
		if event.type == MoodEvent.Type.DESPAIR:
			crisis += event.intensity / 100.0 * 0.5
	return clamp(crisis, 0.0, 1.0)


## Get the most recent significant mood event for UI display.
func get_active_mood_event() -> MoodEvent:
	if mood_events.is_empty():
		return null
	# Return the event with highest intensity
	var best_event: MoodEvent = mood_events[0]
	for event in mood_events:
		if event.intensity > best_event.intensity:
			best_event = event
	return best_event


## Get description of current mood state for UI.
func mood_state_display() -> String:
	if mood < 25.0:
		return "CRITICAL DEPRESSION"
	elif mood < 45.0:
		return "Very unhappy"
	elif mood < 60.0:
		return "Unhappy"
	elif mood < 75.0:
		return "Content"
	elif mood < 90.0:
		return "Happy"
	else:
		return "ECSTATIC"


func ensure_soul_identity() -> void:
	if unique_id.is_empty():
		unique_id = _make_soul_uuid()
	if biography.is_empty():
		append_biography_line("Born")


func _make_soul_uuid() -> String:
	var a: int = int(WorldRNG.stream_seed(&"heelkawn:soul_uuid:a", id))
	var b: int = int(WorldRNG.stream_seed(&"heelkawn:soul_uuid:b", id ^ (birth_tick * 1315423911 + 1)))
	var c: int = int(WorldRNG.stream_seed(&"heelkawn:soul_uuid:c", display_name.hash() ^ id))
	var d: int = int(WorldRNG.stream_seed(&"heelkawn:soul_uuid:d", a ^ b ^ c))
	var lo48: int = ((d & 0xFFFFFF) << 20) ^ (c & 0xFFFFF) ^ (b & 0x3FFFF)
	lo48 = abs(lo48) % 281474976710656
	return "%08x-%04x-%04x-%04x-%012x" % [
		a & 0xFFFFFFFF,
		(b >> 16) & 0xFFFF,
		(0x4000 | (b & 0x0FFF)) & 0xFFFF,
		(0x8000 | ((c >> 12) & 0x3FFF)) & 0xFFFF,
		lo48,
	]


func append_biography_line(line: String) -> void:
	var t: String = str(line).strip_edges()
	if t.is_empty():
		return
	var tick: int = GameManager.tick_count if GameManager != null else 0
	biography.append("[%d] %s" % [tick, t])


func append_physical_scar(scar: String) -> void:
	var s: String = str(scar).strip_edges()
	if s.is_empty():
		return
	if s in physical_scars:
		return
	physical_scars.append(s)
	append_biography_line("Scarred: %s" % s)


func physical_scar_labor_mult() -> float:
	var m: float = 1.0
	for s in physical_scars:
		m *= _physical_scar_tag_labor_mult(str(s))
	return clampf(m, 0.35, 1.0)


func _physical_scar_tag_labor_mult(tag: String) -> float:
	match tag:
		"LameLeg":
			return 0.85
		"MissingArm":
			return 0.70
		"BlindedEye":
			return 0.95
		"DeepScar":
			return 0.90
		_:
			return 0.92


func physical_scar_damage_taken_mult() -> float:
	var m: float = 1.0
	for s in physical_scars:
		m *= _physical_scar_tag_damage_mult(str(s))
	return clampf(m, 1.0, 1.45)


func _physical_scar_tag_damage_mult(tag: String) -> float:
	match tag:
		"MissingArm":
			return 1.10
		"BlindedEye":
			return 1.05
		"DeepScar":
			return 1.08
		"LameLeg":
			return 1.0
		_:
			return 1.04


# ==================== skills ====================

func get_skill_xp(skill: int) -> float:
	return float(skill_xp.get(skill, 0.0))


func get_skill_level(skill: int) -> int:
	return int(get_skill_xp(skill) / XP_PER_LEVEL)


## Add XP to a skill. Returns true when the level changed (so callers can log
## a "Brenna's mining went up to 3!" message).
func add_skill_xp(skill: int, amount: float) -> bool:
	var before: int = get_skill_level(skill)
	var trait_mult: float = get_trait_mult("skill_xp_mult")
	var cat: String = tree_skill_category_for_job_skill(skill)
	var tree_xp: float = skill_tree_bonus_product_for_category(cat, "xp_mult")
	skill_xp[skill] = get_skill_xp(skill) + amount * trait_mult * tree_xp
	
	# Stage 1: Track last used time for XP decay
	skill_last_used[skill] = GameManager.tick_count if GameManager != null else 0
	
	# Stage 1: Check for overall level up
	_check_level_up()
	
	# Stage 1: Check for mastery perk unlocks
	_check_mastery_perks(skill)
	var after: int = get_skill_level(skill)
	if after != before:
		append_biography_line("Learned %s (level %d)" % [skill_name(skill), after])
	return after != before


## Stage 1: Calculate overall level from total XP across all skills
func _check_level_up() -> void:
	var total_xp: float = 0.0
	for skill in skill_xp:
		total_xp += skill_xp[skill]
	var new_level: int = int(total_xp / XP_PER_LEVEL) + 1
	if new_level > level:
		var old_level: int = level
		level = new_level
		# Fire every milestone crossed in one XP tick (avoids skipping branches).
		for m in [5, 10, 15, 20]:
			if m > old_level and m <= level:
				_unlock_skill_branches(m)


## Stage 1: Unlock skill branches at certain levels
func _unlock_skill_branches(new_level: int) -> void:
	# Level 5: Basic specialization unlocks
	if new_level == 5:
		_unlock_basic_skill_branch()
	# Level 10: Intermediate specialization unlocks
	elif new_level == 10:
		_unlock_intermediate_skill_branch()
	# Level 15: Advanced specialization unlocks
	elif new_level == 15:
		_unlock_advanced_skill_branch()
	# Level 20: Mastery unlocks
	elif new_level == 20:
		_unlock_mastery_skill_branch()


## Level 5: Basic skill branch unlocks
func _unlock_basic_skill_branch() -> void:
	var primary_skill: String = _profession_primary_skill(current_profession)
	if primary_skill.is_empty():
		return
	var key: String = primary_skill + "_basic"
	if skill_trees.has(key):
		return
	# Initialize basic skill tree for profession
	skill_trees[key] = {
		"unlocked": true,
		"level": 5,
		"bonuses": {"work_speed_mult": 1.1},  # +10% work speed
		"description": "Basic specialization in " + primary_skill,
	}
	append_biography_line("Skill branch: Basic " + primary_skill + " (level 5)")
	print("[PawnData] %s unlocked basic %s branch" % [display_name, primary_skill])


## Level 10: Intermediate skill branch unlocks
func _unlock_intermediate_skill_branch() -> void:
	var primary_skill: String = _profession_primary_skill(current_profession)
	if primary_skill.is_empty():
		return
	var pkey: String = primary_skill + "_intermediate"
	if skill_trees.has(pkey):
		return
	# Add intermediate branch
	skill_trees[pkey] = {
		"unlocked": true,
		"level": 10,
		"bonuses": {"work_speed_mult": 1.2, "xp_mult": 1.1},
		"description": "Intermediate specialization in " + primary_skill,
	}
	# Also unlock a secondary domain for cross-training
	var secondary: String = ""
	match primary_skill:
		"farming": secondary = "building"
		"building": secondary = "gathering"
		"gathering": secondary = "farming"
		"combat": secondary = "movement"
		"movement": secondary = "combat"
	if secondary != "":
		var skey: String = secondary + "_basics"
		if not skill_trees.has(skey):
			skill_trees[skey] = {
				"unlocked": true,
				"level": 10,
				"bonuses": {"work_speed_mult": 1.05},
				"description": "Foundation in " + secondary,
			}
	append_biography_line("Skill branch: Intermediate " + primary_skill + " (level 10)")
	print("[PawnData] %s unlocked intermediate %s branch" % [display_name, primary_skill])


## Level 15: Advanced skill branch unlocks
func _unlock_advanced_skill_branch() -> void:
	var primary_skill: String = _profession_primary_skill(current_profession)
	if primary_skill.is_empty():
		return
	var akey: String = primary_skill + "_advanced"
	if skill_trees.has(akey):
		return
	# Add advanced branch with significant bonuses
	skill_trees[akey] = {
		"unlocked": true,
		"level": 15,
		"bonuses": {"work_speed_mult": 1.3, "xp_mult": 1.15, "quality_bonus": 1.1},
		"description": "Advanced mastery in " + primary_skill,
	}
	# Unlock teaching ability at level 15
	if not skill_trees.has("teaching"):
		skill_trees["teaching"] = {
			"unlocked": true,
			"level": 15,
			"bonuses": {"teach_efficiency": 1.5},
			"description": "Can teach skills to others",
		}
	append_biography_line("Skill branch: Advanced " + primary_skill + " (level 15)")
	print("[PawnData] %s unlocked advanced %s branch" % [display_name, primary_skill])


## Level 20: Mastery skill branch unlocks
func _unlock_mastery_skill_branch() -> void:
	var primary_skill: String = _profession_primary_skill(current_profession)
	if primary_skill.is_empty():
		return
	var mkey: String = primary_skill + "_mastery"
	if skill_trees.has(mkey):
		return
	# Add mastery branch with full bonuses
	skill_trees[mkey] = {
		"unlocked": true,
		"level": 20,
		"bonuses": {"work_speed_mult": 1.5, "xp_mult": 1.2, "quality_bonus": 1.2, "leadership_mult": 1.3},
		"description": "Mastery of " + primary_skill,
	}
	# Unlock innovation ability at mastery
	if not skill_trees.has("innovation"):
		skill_trees["innovation"] = {
			"unlocked": true,
			"level": 20,
			"bonuses": {"innovation_chance": 0.15},
			"description": "Can discover new techniques",
		}
	append_biography_line("Skill branch: Mastery " + primary_skill + " (level 20)")
	print("[PawnData] %s achieved MASTERY in %s" % [display_name, primary_skill])


## Stage 1: Check for mastery perk unlocks at high skill levels
func _check_mastery_perks(skill: int) -> void:
	var skill_level: int = get_skill_level(skill)
	
	# Level 10: First mastery perk
	if skill_level == 10 and not _has_mastery_perk(skill, 10):
		_grant_mastery_perk(skill, 10)
	# Level 15: Second mastery perk
	elif skill_level == 15 and not _has_mastery_perk(skill, 15):
		_grant_mastery_perk(skill, 15)
	# Level 20: Third mastery perk
	elif skill_level == 20 and not _has_mastery_perk(skill, 20):
		_grant_mastery_perk(skill, 20)


## Stage 1: Check if pawn has a specific mastery perk
func _has_mastery_perk(skill: int, perk_level: int) -> bool:
	var perk_key: String = "%s_mastery_%d" % [skill_name(skill), perk_level]
	return perk_key in mastery_perks


## Stage 1: Grant a mastery perk
func _grant_mastery_perk(skill: int, perk_level: int) -> void:
	var perk_key: String = "%s_mastery_%d" % [skill_name(skill), perk_level]
	mastery_perks.append(perk_key)
	# TODO: Apply perk effects (work speed bonus, quality bonus, etc.)


## Stage 1: Decay unused skills over time
## Call this periodically (e.g., once per day)
func decay_unused_skills() -> void:
	var current_tick: int = GameManager.tick_count if GameManager != null else 0
	var decay_threshold: int = DayNightCycle.TICKS_PER_DAY * 7  # 7 days without use
	
	for skill in skill_xp:
		var last_used: int = skill_last_used.get(skill, 0)
		if current_tick - last_used > decay_threshold:
			# Decay XP slowly
			var decay_amount: float = 1.0
			skill_xp[skill] = max(0.0, skill_xp[skill] - decay_amount)
			# Update last used to prevent rapid decay
			skill_last_used[skill] = current_tick


## Maps job [enum Skill] to profession skill-tree category (keys in [member skill_trees]).
static func tree_skill_category_for_job_skill(skill: int) -> String:
	match skill:
		Skill.FORAGING:
			return "farming"
		Skill.MINING, Skill.CHOPPING:
			return "gathering"
		Skill.BUILDING:
			return "building"
		Skill.HUNTING:
			return "combat"
	return ""


func _skill_tree_branch_applies_to(branch_key: String, category: String) -> bool:
	if category.is_empty():
		return false
	for suffix in ["_basic", "_intermediate", "_advanced", "_mastery"]:
		if branch_key == category + suffix:
			return true
	# Cross-training unlock at level 10
	if branch_key == category + "_basics":
		return true
	return false


## Product of `bonus_key` from every unlocked branch that applies to `category`.
## Only entries that define the key participate (missing key = no change).
func skill_tree_bonus_product_for_category(category: String, bonus_key: String) -> float:
	var mult: float = 1.0
	for branch_key in skill_trees:
		var entry: Variant = skill_trees[branch_key]
		if entry is Dictionary and not bool((entry as Dictionary).get("unlocked", false)):
			continue
		if not (entry is Dictionary):
			continue
		if not _skill_tree_branch_applies_to(str(branch_key), category):
			continue
		var bonuses: Dictionary = (entry as Dictionary).get("bonuses", {}) as Dictionary
		if bonuses.has(bonus_key):
			mult *= float(bonuses[bonus_key])
	return mult


## Extra harvest quantity multiplier from advanced/mastery [code]quality_bonus[/code] nodes.
func harvest_quality_multiplier_for_job_skill(skill: int) -> float:
	var cat: String = tree_skill_category_for_job_skill(skill)
	if cat.is_empty():
		return 1.0
	return skill_tree_bonus_product_for_category(cat, "quality_bonus")


## Teaching branch: multiplies XP granted to students in [method Pawn.teach_skill].
func teach_efficiency_multiplier() -> float:
	var entry: Variant = skill_trees.get("teaching", null)
	if entry is Dictionary and bool((entry as Dictionary).get("unlocked", false)):
		var bonuses: Dictionary = (entry as Dictionary).get("bonuses", {}) as Dictionary
		if bonuses.has("teach_efficiency"):
			return maxf(0.25, float(bonuses["teach_efficiency"]))
	return 1.0


func leadership_presence_multiplier() -> float:
	var mult: float = 1.0
	for branch_key in skill_trees:
		var entry: Variant = skill_trees[branch_key]
		if entry is Dictionary and not bool((entry as Dictionary).get("unlocked", false)):
			continue
		var bonuses: Dictionary = (entry as Dictionary).get("bonuses", {}) as Dictionary
		if bonuses.has("leadership_mult"):
			mult *= float(bonuses["leadership_mult"])
	return mult


## After load: ensure milestone branches exist up to [member level] (idempotent).
func ensure_skill_trees_through_level(max_level: int) -> void:
	for m in [5, 10, 15, 20]:
		if max_level >= m:
			_unlock_skill_branches(m)


func sync_level_from_total_skill_xp() -> void:
	var total_xp: float = 0.0
	for sk in skill_xp:
		total_xp += float(skill_xp[sk])
	level = maxi(1, int(total_xp / XP_PER_LEVEL) + 1)


## Speed multiplier to apply to per-tick work progress for `skill`. Linearly
## interpolates from 1.0 at level 0 to SKILL_BONUS_AT_MAX at SKILL_LEVEL_MAX,
## then plateaus.
func work_speed_for(skill: int) -> float:
	var lvl: int = mini(get_skill_level(skill), SKILL_LEVEL_MAX)
	var base: float = 1.0
	if lvl > 0:
		var t: float = float(lvl) / float(SKILL_LEVEL_MAX)
		base = 1.0 + t * (SKILL_BONUS_AT_MAX - 1.0)
	var cat: String = tree_skill_category_for_job_skill(skill)
	var tree_mult: float = skill_tree_bonus_product_for_category(cat, "work_speed_mult")
	return base * tree_mult


func _skill_to_profession(skill_key: String) -> int:
	match skill_key:
		"farming":
			return Profession.FARMER
		"building":
			return Profession.BUILDER
		"gathering":
			return Profession.GATHERER
		"combat":
			return Profession.WARRIOR
		"movement":
			return Profession.SCHOLAR
		_:
			return Profession.NONE


func _profession_primary_skill(prof: int) -> String:
	match prof:
		Profession.FARMER:
			return "farming"
		Profession.BUILDER:
			return "building"
		Profession.GATHERER:
			return "gathering"
		Profession.WARRIOR:
			return "combat"
		Profession.SCHOLAR:
			return "movement"
		_:
			return ""


func profession_name() -> String:
	return profession_label_from_enum(int(current_profession))


static func profession_label_from_enum(prof: int) -> String:
	match prof:
		Profession.NONE:
			return "None"
		Profession.FARMER:
			return "Farmer"
		Profession.BUILDER:
			return "Builder"
		Profession.GATHERER:
			return "Gatherer"
		Profession.WARRIOR:
			return "Warrior"
		Profession.SCHOLAR:
			return "Scholar"
		_:
			return "None"


func tracked_skill_xp(skill_key: String) -> int:
	return int(skills.get(skill_key, 0))


func profession_progress_xp() -> int:
	var primary: String = _profession_primary_skill(current_profession)
	if primary != "":
		return tracked_skill_xp(primary)
	var best: int = 0
	for k in skills:
		best = maxi(best, int(skills[k]))
	return best


func gain_skill_xp(skill_key: String, amount: int) -> bool:
	if amount <= 0:
		return false
	if not skills.has(skill_key):
		return false
	# Once locked, only the profession's primary skill can gain XP.
	if current_profession != Profession.NONE:
		var primary_skill: String = _profession_primary_skill(current_profession)
		if skill_key != primary_skill:
			return false
	var before: int = tracked_skill_xp(skill_key)
	var after: int = before + amount
	var just_locked: bool = false
	if current_profession == Profession.NONE and after >= 100:
		current_profession = _skill_to_profession(skill_key)
		just_locked = true
	skills[skill_key] = after
	add_liking_from_action_skill(skill_key, amount)
	return (after != before) or just_locked


func _ensure_profession_liking_defaults() -> void:
	for k in PROFESSION_LIKING_KEYS:
		if not profession_liking.has(k):
			profession_liking[k] = LIKING_MIN
			continue
		var v: int = int(profession_liking[k])
		profession_liking[k] = clampi(v, LIKING_MIN, LIKING_MAX)


func profession_liking_total() -> int:
	_ensure_profession_liking_defaults()
	var s: int = 0
	for k in PROFESSION_LIKING_KEYS:
		s += int(profession_liking.get(k, LIKING_MIN))
	return s


func _bump_lane(lane_key: String, delta: int) -> void:
	if delta <= 0:
		return
	_ensure_profession_liking_defaults()
	var cur: int = int(profession_liking.get(lane_key, LIKING_MIN))
	profession_liking[lane_key] = clampi(cur + delta, LIKING_MIN, LIKING_MAX)


func _flush_liking_to_affinities() -> void:
	recompute_affinities_from_liking()


## Work ticks on the job queue (not trade haul — that uses completion hook).
func add_profession_liking_for_job(job_type: int, tick_weight: int) -> void:
	var w: int = maxi(1, tick_weight)
	_ensure_profession_liking_defaults()
	match job_type:
		Job.Type.FORAGE:
			_bump_lane("outdoors", w)
			_bump_lane("tillage", w)
		Job.Type.MINE:
			_bump_lane("industry", w)
			_bump_lane("inquiry", maxi(1, w / 4))
		Job.Type.MINE_WALL:
			_bump_lane("industry", w)
			_bump_lane("inquiry", w)
			_bump_lane("structure", maxi(1, w / 5))
		Job.Type.CHOP:
			_bump_lane("industry", w)
			_bump_lane("outdoors", maxi(1, w / 3))
		Job.Type.HUNT:
			_bump_lane("martial", w)
			_bump_lane("outdoors", w)
		Job.Type.BUILD_BED, Job.Type.BUILD_WALL, Job.Type.BUILD_DOOR:
			_bump_lane("structure", w)
		_:
			pass
	_flush_liking_to_affinities()


## One completed inter-zone haul (pickup + deposit succeeded).
func add_profession_liking_for_trade_completion() -> void:
	_bump_lane("circulation", 12)
	_bump_lane("inquiry", 6)
	_flush_liking_to_affinities()


func add_liking_from_action_skill(skill_key: String, amount: int) -> void:
	var a: int = maxi(1, amount)
	match skill_key:
		"movement":
			_bump_lane("inquiry", a)
			_bump_lane("circulation", maxi(1, a / 2))
		"farming":
			_bump_lane("tillage", a)
			_bump_lane("outdoors", maxi(1, a / 3))
		"building":
			_bump_lane("structure", a)
			_bump_lane("industry", maxi(1, a / 3))
		"gathering":
			_bump_lane("tillage", maxi(1, a / 2))
			_bump_lane("outdoors", a)
		"combat":
			_bump_lane("martial", a)
			_bump_lane("inquiry", maxi(1, a / 4))
		_:
			return
	_flush_liking_to_affinities()


func recompute_affinities_from_liking() -> void:
	_ensure_profession_liking_defaults()
	if affinity_birth_snapshot.is_empty():
		affinity_birth_snapshot = affinities.duplicate(true)
	var outdoors: int = int(profession_liking.get("outdoors", LIKING_MIN))
	var tillage: int = int(profession_liking.get("tillage", LIKING_MIN))
	var industry: int = int(profession_liking.get("industry", LIKING_MIN))
	var structure: int = int(profession_liking.get("structure", LIKING_MIN))
	var martial: int = int(profession_liking.get("martial", LIKING_MIN))
	var circulation: int = int(profession_liking.get("circulation", LIKING_MIN))
	var inquiry: int = int(profession_liking.get("inquiry", LIKING_MIN))
	# Integer scores → relative weights (cascade / web-tree style).
	var s_farm: int = tillage * 100 + outdoors * 35
	var s_combat: int = martial * 100 + outdoors * 12 + tillage * 2
	var s_build: int = structure * 100 + industry * 18
	var s_craft: int = industry * 100 + structure * 12 + inquiry * 8
	var s_diplo: int = circulation * 100 + inquiry * 35 + tillage * 4
	var tot: int = maxi(1, s_farm + s_combat + s_build + s_craft + s_diplo)
	var e_farm: float = float(s_farm) / float(tot)
	var e_combat: float = float(s_combat) / float(tot)
	var e_build: float = float(s_build) / float(tot)
	var e_craft: float = float(s_craft) / float(tot)
	var e_diplo: float = float(s_diplo) / float(tot)
	var blend_w: float = minf(0.95, float(profession_liking_total() - PROFESSION_LIKING_KEYS.size() * LIKING_MIN) / LIKING_BLEND_DENOM)
	var b_f: float = float(affinity_birth_snapshot.get("farming", 0.5))
	var b_c: float = float(affinity_birth_snapshot.get("combat", 0.5))
	var b_b: float = float(affinity_birth_snapshot.get("building", 0.5))
	var b_r: float = float(affinity_birth_snapshot.get("crafting", 0.5))
	var b_d: float = float(affinity_birth_snapshot.get("diplomacy", 0.5))
	affinities["farming"] = lerpf(b_f, 0.05 + 0.9 * clampf(e_farm, 0.0, 1.0), blend_w)
	affinities["combat"] = lerpf(b_c, 0.05 + 0.9 * clampf(e_combat, 0.0, 1.0), blend_w)
	affinities["building"] = lerpf(b_b, 0.05 + 0.9 * clampf(e_build, 0.0, 1.0), blend_w)
	affinities["crafting"] = lerpf(b_r, 0.05 + 0.9 * clampf(e_craft, 0.0, 1.0), blend_w)
	affinities["diplomacy"] = lerpf(b_d, 0.05 + 0.9 * clampf(e_diplo, 0.0, 1.0), blend_w)


func profession_liking_digest_line() -> String:
	_ensure_profession_liking_defaults()
	var parts: PackedStringArray = PackedStringArray()
	for k in PROFESSION_LIKING_KEYS:
		parts.append("%s=%d" % [k.substr(0, 3), int(profession_liking.get(k, LIKING_MIN))])
	return "Likings " + ", ".join(parts) + " → bias " + highest_affinity_skill()


func _profession_liking_ranked() -> Array:
	_ensure_profession_liking_defaults()
	var arr: Array = []
	for k in PROFESSION_LIKING_KEYS:
		arr.append({"k": k, "v": int(profession_liking.get(k, LIKING_MIN))})
	arr.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var va: int = int(a.get("v", 0))
		var vb: int = int(b.get("v", 0))
		if va != vb:
			return va > vb
		return String(a.get("k", "")) < String(b.get("k", ""))
	)
	return arr


static func _lane_plain_name(lane_key: String) -> String:
	match lane_key:
		"outdoors":
			return "open air and travel between sites"
		"tillage":
			return "fields, harvest, and food rhythm"
		"industry":
			return "stone, ore, and raw material"
		"structure":
			return "walls, beds, doors — shelter craft"
		"martial":
			return "danger, hunting, and confrontation"
		"circulation":
			return "convoys, stockpiles, and trade legs"
		"inquiry":
			return "study, routes, and reading the world"
		_:
			return lane_key


static func _affinity_jobs_plain(affinity_key: String) -> String:
	match affinity_key:
		"farming":
			return "forage / berry harvest"
		"combat":
			return "hunt / meat runs"
		"building":
			return "bed / wall / door builds"
		"crafting":
			return "mine / chop / tunnel stone"
		"diplomacy":
			return "trade haul between zones"
		_:
			return "mixed labour"


static func _nexus_coach_line(lane_a: String, lane_b: String) -> String:
	var x: String = lane_a if lane_a < lane_b else lane_b
	var y: String = lane_b if lane_a < lane_b else lane_a
	var pair: String = "%s|%s" % [x, y]
	match pair:
		"outdoors|tillage":
			return "Nexus: harvest cadence — you read weather and soil together (gatherer → farmer arc)."
		"martial|outdoors":
			return "Nexus: ranger beat — patrol and harvest both feel like home (hunter / warden cadence)."
		"inquiry|tillage":
			return "Nexus: agrarian scholar — ledgers, seed cycles, and ruins in farmland (teacher / planner tone)."
		"circulation|inquiry":
			return "Nexus: caravan mind — routes, prices, and rumor; merchant-scribe energy."
		"industry|structure":
			return "Nexus: mason-architect — raw mass becomes rooms; builder who owns the quarry."
		"martial|inquiry":
			return "Nexus: tactician — fights teach patterns you name; officer / ritualist undertone."
		"industry|inquiry":
			return "Nexus: delver — stone and story in the same breath (mine-wall → lore hooks)."
		"structure|circulation":
			return "Nexus: quartermaster — stockpiles meet blueprints; who builds also moves goods."
		"tillage|circulation":
			return "Nexus: granary web — food and freight entwine; colony lifeline roles."
		_:
			return "Nexus: %s + %s — generalist spine; odd jobs cluster on you first." % [
				_lane_plain_name(x), _lane_plain_name(y)]


## Observer-facing copy: no RNG, same inputs → same lines. For future per-player HUD.
func progression_coach_lines(max_lines: int = 5) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var cap: int = clampi(max_lines, 1, 8)
	_ensure_profession_liking_defaults()
	var hk: String = highest_affinity_skill()
	out.append(
			"Job queue bias: %s — %s (weight %.2f)." % [
				_affinity_jobs_plain(hk), hk, float(affinities.get(hk, 0.5)),
			]
	)
	var ranked: Array = _profession_liking_ranked()
	if ranked.is_empty():
		return out
	var top: Dictionary = ranked[0]
	out.append(
			"Inner pull: %s (score %d)." % [_lane_plain_name(str(top.get("k", ""))), int(top.get("v", 1))]
	)
	if ranked.size() >= 2 and out.size() < cap:
		var second: Dictionary = ranked[1]
		out.append(
				"Second thread: %s (%d)." % [_lane_plain_name(str(second.get("k", ""))), int(second.get("v", 1))]
		)
	if out.size() < cap:
		if current_profession == Profession.NONE:
			var lead: String = ""
			var lead_xp: int = -1
			for sk in ["farming", "building", "gathering", "combat", "movement"]:
				var xv: int = tracked_skill_xp(sk)
				if xv > lead_xp or (xv == lead_xp and (lead.is_empty() or sk < lead)):
					lead_xp = xv
					lead = sk
			out.append(
					"Profession: first action skill to 100 xp locks a role — closest track is `%s` (%d/100)." % [lead, lead_xp]
			)
		else:
			out.append(
					"Profession locked: %s — keep pushing `%s` for mastery perks." % [
						profession_name(), _profession_primary_skill(current_profession),
					]
			)
	if ranked.size() >= 2 and out.size() < cap:
		out.append(_nexus_coach_line(str(ranked[0].get("k", "")), str(ranked[1].get("k", ""))))
	while out.size() > cap:
		out.remove_at(out.size() - 1)
	return out


func initialize_affinities(new_birth_tick: int, parent_a: int, parent_b: int) -> void:
	birth_tick = new_birth_tick
	parent_a_id = parent_a
	parent_b_id = parent_b
	affinities["combat"] = _deterministic_affinity_value(11)
	affinities["farming"] = _deterministic_affinity_value(29)
	affinities["building"] = _deterministic_affinity_value(47)
	affinities["crafting"] = _deterministic_affinity_value(73)
	affinities["diplomacy"] = _deterministic_affinity_value(97)
	_ensure_profession_liking_defaults()
	affinity_birth_snapshot = affinities.duplicate(true)


func _deterministic_affinity_value(salt: int) -> float:
	var affinity_mix: int = int(
		(birth_tick * 1103515245 + (parent_a_id + 31) * 12345 + (parent_b_id + 17) * 2654435761 + id * 97 + salt) & 0x7FFFFFFF
	)
	var modv: int = affinity_mix % 1000
	return float(modv) / 999.0


func highest_affinity_skill() -> String:
	var best_key: String = "farming"
	var best_val: float = -1.0
	for k in affinities:
		var v: float = float(affinities[k])
		if v > best_val or (is_equal_approx(v, best_val) and str(k) < best_key):
			best_val = v
			best_key = str(k)
	return best_key


func affinity_xp_for(affinity_key: String) -> int:
	match affinity_key:
		"combat":
			return tracked_skill_xp("combat")
		"farming":
			return tracked_skill_xp("farming")
		"building":
			return tracked_skill_xp("building")
		"crafting":
			return tracked_skill_xp("gathering")
		"diplomacy":
			return tracked_skill_xp("movement")
		_:
			return 0


func get_mastery_perk(skill: String) -> String:
	var xp: int = tracked_skill_xp(skill)
	if xp > 500:
		return "Grandmaster"
	if xp > 200:
		return "Master"
	return ""


func total_tracked_xp() -> int:
	var total: int = 0
	for k in skills:
		total += int(skills[k])
	return total


func calculate_influence(population: int) -> float:
	var base_xp: float = float(total_tracked_xp())
	var dip_bonus: float = float(affinities.get("diplomacy", 0.5)) * 2.0
	var combat_bonus: float = float(affinities.get("combat", 0.5)) * 1.5
	var pop_mult: float = 1.0 + maxf(0.0, float(maxi(1, population) - 1) * 0.02)
	influence = (base_xp + dip_bonus + combat_bonus) * pop_mult
	return influence


## Multiplier applied to work ticks (low health and fatigue slow labour).
## Traits can also modify work speed.
func effective_labor_mult() -> float:
	var h: float = clamp(health * 0.01, 0.0, 1.0)
	var r: float = clamp(rest * 0.01, 0.0, 1.0)
	var base_mult: float = max(0.2, h * 0.55 + r * 0.45)
	var trait_mult: float = get_trait_mult("work_speed_mult")
	return base_mult * trait_mult * physical_scar_labor_mult()


static func skill_name(skill: int) -> String:
	match skill:
		Skill.FORAGING: return "Foraging"
		Skill.MINING:   return "Mining"
		Skill.CHOPPING: return "Chopping"
		Skill.BUILDING: return "Building"
		Skill.HUNTING:  return "Hunting"
	return "?"


## Map a job type to the skill that benefits from it. Returns -1 for jobs
## that don't grant XP (e.g. hauling).
static func skill_for_job(job_type: int) -> int:
	match job_type:
		Job.Type.FORAGE:     return Skill.FORAGING
		Job.Type.MINE:       return Skill.MINING
		Job.Type.MINE_WALL:  return Skill.MINING
		Job.Type.CHOP:       return Skill.CHOPPING
		Job.Type.HUNT:       return Skill.HUNTING
		Job.Type.BUILD_BED:  return Skill.BUILDING
		Job.Type.BUILD_WALL: return Skill.BUILDING
		Job.Type.BUILD_DOOR: return Skill.BUILDING
	return -1


## False if this pawn is not allowed to take `job_type` from the job queue.
func allows_job_type(job_type: int) -> bool:
	if GameManager != null and GameManager.has_method("is_lightweight_simulation_mode") and GameManager.is_lightweight_simulation_mode():
		return _allows_job_type_lightweight(job_type)
	match job_type:
		Job.Type.FORAGE:
			return work_forage
		Job.Type.MINE, Job.Type.MINE_WALL:
			return work_mine
		Job.Type.CHOP:
			return work_chop
		Job.Type.HUNT:
			return work_hunt
		Job.Type.BUILD_BED, Job.Type.BUILD_WALL, Job.Type.BUILD_DOOR:
			return work_build
		Job.Type.TRADE_HAUL:
			return true
	return true


func _allows_job_type_lightweight(job_type: int) -> bool:
	if job_type == Job.Type.FORAGE:
		return work_forage
	if job_type == Job.Type.CHOP:
		return work_chop
	if job_type == Job.Type.HUNT:
		return work_hunt
	if job_type == Job.Type.MINE:
		return work_mine and profession_progress_xp() >= 100
	if job_type == Job.Type.BUILD_BED or job_type == Job.Type.BUILD_DOOR:
		return work_build and profession_progress_xp() >= 300
	if job_type == Job.Type.BUILD_WALL or job_type == Job.Type.MINE_WALL:
		return work_build and work_mine and profession_progress_xp() >= 500
	if job_type == Job.Type.TRADE_HAUL:
		return profession_progress_xp() >= 800
	return false


func describe() -> String:
	return "#%d %s (age %d)" % [id, display_name, age]


func add_social_rapport(peer_id: int, delta: int) -> void:
	if peer_id < 0 or peer_id == id or delta <= 0:
		return
	var k: String = str(peer_id)
	social_rapport[k] = clampi(int(social_rapport.get(k, 0)) + delta, 0, 3000)


func get_social_rapport(peer_id: int) -> int:
	if peer_id < 0 or peer_id == id:
		return 0
	return int(social_rapport.get(str(peer_id), 0))


func top_social_rapport_peer() -> Dictionary:
	var best_id: int = -1
	var best_score: int = 0
	for k in social_rapport:
		var sc: int = int(social_rapport[k])
		var pid: int = int(k)
		if sc > best_score or (sc == best_score and (best_id < 0 or pid < best_id)):
			best_score = sc
			best_id = pid
	return {"peer_id": best_id, "score": best_score}


func modify_character_opinion(peer_id: int, delta: int) -> void:
	if peer_id < 0 or peer_id == id or delta == 0:
		return
	var k: String = str(peer_id)
	character_opinions[k] = clampi(int(character_opinions.get(k, 0)) + delta, -100, 100)


func get_character_opinion(peer_id: int) -> int:
	if peer_id < 0 or peer_id == id:
		return 0
	return clampi(int(character_opinions.get(str(peer_id), 0)), -100, 100)


func top_character_opinion_peer() -> Dictionary:
	var best_id: int = -1
	var best_op: int = -101
	for k in character_opinions:
		var op: int = int(character_opinions[k])
		var pid: int = int(k)
		if op > best_op or (op == best_op and (best_id < 0 or pid < best_id)):
			best_op = op
			best_id = pid
	return {"peer_id": best_id, "opinion": best_op}


func social_status_line(peer_display: String = "") -> String:
	var t: Dictionary = top_social_rapport_peer()
	var pid: int = int(t.get("peer_id", -1))
	var sc: int = int(t.get("score", 0))
	if pid < 0 or sc <= 0:
		return "Social: no steady bonds yet (stay near another pawn to build rapport)."
	var trimmed: String = peer_display.strip_edges()
	var whom: String = trimmed if not trimmed.is_empty() else "#%d" % pid
	return "Social: strongest bond toward %s (rapport %d) — pairing / births use this track." % [whom, sc]


## Versioned **portable character** payload for a future online game / PVA Bazaar tooling.
## Intentionally smaller than [method to_save_dict]: no tile bind, no job runtime; includes
## identity, look, earned bias, and top social edges. Bump [member PORTABLE_CHARACTER_SCHEMA] when fields change.
const PORTABLE_CHARACTER_SCHEMA: String = "heelkawn_character_portable/v1"


func _social_rapport_top_for_export(max_entries: int) -> Dictionary:
	var pairs: Array[Dictionary] = []
	for k in social_rapport:
		pairs.append({"id": int(k), "v": int(social_rapport[k])})
	pairs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["v"]) > int(b["v"]))
	var out: Dictionary = {}
	var n: int = mini(max_entries, pairs.size())
	for i in range(n):
		out[str(pairs[i]["id"])] = pairs[i]["v"]
	return out


func to_portable_character_export(export_tick: int, world_seed: int, origin_region_key: int) -> Dictionary:
	var sx: Dictionary = {}
	for k in skill_xp:
		sx[str(k)] = skill_xp[k]
	var trait_types: Array = []
	for trait_item in traits:
		if trait_item == null:
			continue
		trait_types.append(trait_item.trait_type)
	return {
		"schema": PORTABLE_CHARACTER_SCHEMA,
		"source_game": "HeelKawn1_standalone",
		"export_tick": export_tick,
		"world_seed": world_seed,
		"origin_region_key": origin_region_key,
		"legacy_standalone_pawn_id": id,
		"display_name": display_name,
		"gender": gender,
		"age_years": age_years,
		"color": [color.r, color.g, color.b, color.a],
		"body_type": body_type,
		"hair_style": hair_style,
		"hair_color": [hair_color.r, hair_color.g, hair_color.b, hair_color.a],
		"apparel_color": [apparel_color.r, apparel_color.g, apparel_color.b, apparel_color.a],
		"birth_tick": birth_tick,
		"parent_a_id": parent_a_id,
		"parent_b_id": parent_b_id,
		"children_count": children_count,
		"current_profession": current_profession,
		"skills": skills.duplicate(true),
		"skill_xp": sx,
		"affinities": affinities.duplicate(true),
		"affinity_birth_snapshot": affinity_birth_snapshot.duplicate(true),
		"profession_liking": profession_liking.duplicate(true),
		"social_rapport_top": _social_rapport_top_for_export(24),
		"trait_types": trait_types,
		"military_rank": military_rank_legacy,  # Use legacy string for export compatibility
		"influence": influence,
		"soul_id": unique_id,
		"lineage_id": lineage_id,
		"biography_lines": biography.size(),
		"physical_scars": physical_scars.duplicate(),
	}


## Serialize for `GameSave` (store_var). All numeric work flags included.
func to_save_dict() -> Dictionary:
	var sx: Dictionary = {}
	for k in skill_xp:
		sx[str(k)] = skill_xp[k]
	var trait_types: Array = []
	for trait_item in traits:
		if trait_item == null:
			continue
		trait_types.append(trait_item.trait_type)
	# Serialize active_traits (Resource-backed). Prefer a dict representation
	var active_traits_ser: Array = []
	for a in active_traits:
		if a == null:
			continue
		if a is Trait:
			active_traits_ser.append({"legacy_trait_type": int(a.trait_type)})
		elif a is Resource:
			# Prefer saving as a resource path when the trait is a saved resource.
			var rp: String = str(a.resource_path) if a.has_method("get_resource_path") or a.has("resource_path") else ""
			if rp != "":
				active_traits_ser.append({"resource_path": rp})
			elif a.has_method("to_dict"):
				active_traits_ser.append(a.to_dict())
			else:
				if a.has("id"):
					active_traits_ser.append({"id": str(a.get("id"))})
				else:
					active_traits_ser.append({})
		elif a.has_method("to_dict"):
			active_traits_ser.append(a.to_dict())
		else:
			# Fallback: store a lightweight id if present
			if a.has("id"):
				active_traits_ser.append({"id": str(a.get("id"))})
			else:
				active_traits_ser.append({})
	return {
		"id": id,
		"display_name": display_name,
		"age": age,
		"age_years": age_years,
		"gender": gender,
		"tile_x": tile_pos.x,
		"tile_y": tile_pos.y,
		"color": [color.r, color.g, color.b, color.a],
		"body_type": body_type,
		"hair_style": hair_style,
		"hair_color": [hair_color.r, hair_color.g, hair_color.b, hair_color.a],
		"apparel_color": [apparel_color.r, apparel_color.g, apparel_color.b, apparel_color.a],
		"hunger": hunger,
		"rest": rest,
		"mood": mood,
		"health": health,
		"max_health": max_health,
		"carrying": carrying,
		"carrying_qty": carrying_qty,
		"skill_xp": sx,
		"level": level,
		"skill_trees": skill_trees.duplicate(true),
		"mastery_perks": mastery_perks.duplicate(),
		"skills": skills.duplicate(true),
		"affinities": affinities.duplicate(true),
		"affinity_birth_snapshot": affinity_birth_snapshot.duplicate(true),
		"profession_liking": profession_liking.duplicate(true),
		"current_profession": current_profession,
		"birth_tick": birth_tick,
		"parent_a_id": parent_a_id,
		"parent_b_id": parent_b_id,
		"children_count": children_count,
		"influence": influence,
		"military_rank": military_rank_legacy,  # Use legacy string for save compatibility
		"military_rank_int": military_rank,  # Stage 6 int-based rank
		"cohort_anchor_id": cohort_anchor_id,
		"cohort_job_type": cohort_job_type,
		"is_cohort_anchor": is_cohort_anchor,
		"work_forage": work_forage,
		"work_mine": work_mine,
		"work_chop": work_chop,
		"work_hunt": work_hunt,
		"work_build": work_build,
		"trait_types": trait_types,
		"social_rapport": social_rapport.duplicate(true),
		"character_opinions": character_opinions.duplicate(true),
		"neural_network": neural_network.to_dict() if neural_network != null and neural_network.has_method("to_dict") else {},
		"unique_id": unique_id,
		"lineage_id": lineage_id,
		"biography": biography.duplicate(),
		"physical_scars": physical_scars.duplicate(),
		"settlement_reputation": settlement_reputation.duplicate(true),
		"social_squad_anchor_id": social_squad_anchor_id,
		"available_krond": available_krond,
		"total_krond_earned": total_krond_earned,
		"active_traits": active_traits_ser,
	}


## Rebuild from `to_save_dict`. Overrides the auto id from _init and bumps
## `_next_id` so future spawns don't collide.
static func from_save_dict(d: Dictionary) -> PawnData:
	var p := PawnData.new()
	p.id = int(d.get("id", p.id))
	p.display_name = str(d.get("display_name", p.display_name))
	p.age = int(d.get("age", p.age))
	p.age_years = float(d.get("age_years", float(p.age)))
	p.gender = int(d.get("gender", p.gender))
	p.tile_pos = Vector2i(int(d.get("tile_x", 0)), int(d.get("tile_y", 0)))
	var c: Array = d.get("color", [1, 1, 1, 1])
	if c.size() >= 3:
		p.color = Color(float(c[0]), float(c[1]), float(c[2]), float(c[3]) if c.size() > 3 else 1.0)
	p.body_type = int(d.get("body_type", BodyType.AVERAGE))
	p.hair_style = int(d.get("hair_style", HairStyle.SHORT))
	var hc: Array = d.get("hair_color", [0.37, 0.27, 0.18, 1.0])
	if hc.size() >= 3:
		p.hair_color = Color(float(hc[0]), float(hc[1]), float(hc[2]), float(hc[3]) if hc.size() > 3 else 1.0)
	var ac: Array = d.get("apparel_color", [0.36, 0.49, 0.66, 1.0])
	if ac.size() >= 3:
		p.apparel_color = Color(float(ac[0]), float(ac[1]), float(ac[2]), float(ac[3]) if ac.size() > 3 else 1.0)
	p.hunger = float(d.get("hunger", 100.0))
	p.rest = float(d.get("rest", 100.0))
	p.mood = float(d.get("mood", 100.0))
	p.health = float(d.get("health", 100.0))
	p.max_health = float(d.get("max_health", 100.0))
	p.carrying = int(d.get("carrying", 0))
	p.carrying_qty = int(d.get("carrying_qty", 0))
	p.skill_xp = {}
	if d.has("skill_xp") and d["skill_xp"] is Dictionary:
		for k in d["skill_xp"]:
			p.skill_xp[int(k)] = float(d["skill_xp"][k])
	p.sync_level_from_total_skill_xp()
	var saved_level: int = int(d.get("level", p.level))
	p.level = maxi(p.level, saved_level)
	if d.has("skill_trees") and d["skill_trees"] is Dictionary:
		p.skill_trees = (d["skill_trees"] as Dictionary).duplicate(true)
	if d.has("mastery_perks") and d["mastery_perks"] is Array:
		p.mastery_perks = (d["mastery_perks"] as Array).duplicate()
	p.skills = {
		"movement": 0,
		"farming": 0,
		"building": 0,
		"gathering": 0,
		"combat": 0,
	}
	if d.has("skills") and d["skills"] is Dictionary:
		for sk in p.skills.keys():
			p.skills[sk] = int(d["skills"].get(sk, 0))
	p.affinities = {
		"combat": 0.5,
		"farming": 0.5,
		"building": 0.5,
		"crafting": 0.5,
		"diplomacy": 0.5,
	}
	if d.has("affinities") and d["affinities"] is Dictionary:
		for ak in p.affinities.keys():
			p.affinities[ak] = float(d["affinities"].get(ak, p.affinities[ak]))
	p.profession_liking = {}
	if d.has("profession_liking") and d["profession_liking"] is Dictionary:
		for lk in PROFESSION_LIKING_KEYS:
			if d["profession_liking"].has(lk):
				p.profession_liking[lk] = clampi(int(d["profession_liking"][lk]), LIKING_MIN, LIKING_MAX)
	p._ensure_profession_liking_defaults()
	p.affinity_birth_snapshot = {}
	if d.has("affinity_birth_snapshot") and d["affinity_birth_snapshot"] is Dictionary:
		for ak in p.affinities.keys():
			if d["affinity_birth_snapshot"].has(ak):
				p.affinity_birth_snapshot[ak] = float(d["affinity_birth_snapshot"][ak])
	if p.affinity_birth_snapshot.is_empty():
		p.affinity_birth_snapshot = p.affinities.duplicate(true)
	p.recompute_affinities_from_liking()
	p.current_profession = int(d.get("current_profession", Profession.NONE))
	p.ensure_skill_trees_through_level(p.level)
	p.birth_tick = int(d.get("birth_tick", 0))
	p.parent_a_id = int(d.get("parent_a_id", -1))
	p.parent_b_id = int(d.get("parent_b_id", -1))
	p.children_count = int(d.get("children_count", 0))
	p.influence = float(d.get("influence", 0.0))
	p.military_rank_legacy = str(d.get("military_rank_legacy", "grunt"))
	p.military_rank = int(d.get("military_rank_int", 0))
	p.cohort_anchor_id = int(d.get("cohort_anchor_id", -1))
	p.cohort_job_type = int(d.get("cohort_job_type", -1))
	p.is_cohort_anchor = bool(d.get("is_cohort_anchor", false))
	p.work_forage = bool(d.get("work_forage", true))
	p.work_mine = bool(d.get("work_mine", true))
	p.work_chop = bool(d.get("work_chop", true))
	p.work_hunt = bool(d.get("work_hunt", true))
	p.work_build = bool(d.get("work_build", true))
	p.social_rapport = {}
	if d.has("social_rapport") and d["social_rapport"] is Dictionary:
		for sk in (d["social_rapport"] as Dictionary).keys():
			p.social_rapport[str(sk)] = clampi(int((d["social_rapport"] as Dictionary)[sk]), 0, 3000)
	p.character_opinions = {}
	if d.has("character_opinions") and d["character_opinions"] is Dictionary:
		for ok in (d["character_opinions"] as Dictionary).keys():
			p.character_opinions[str(ok)] = clampi(int((d["character_opinions"] as Dictionary)[ok]), -100, 100)
	p.unique_id = str(d.get("unique_id", p.unique_id))
	p.lineage_id = str(d.get("lineage_id", p.lineage_id))
	p.biography = []
	if d.has("biography") and d["biography"] is Array:
		for line in d["biography"]:
			p.biography.append(str(line))
	p.physical_scars = []
	if d.has("physical_scars") and d["physical_scars"] is Array:
		for sc in d["physical_scars"]:
			p.physical_scars.append(str(sc))
	p.settlement_reputation = {}
	if d.has("settlement_reputation") and d["settlement_reputation"] is Dictionary:
		for rk in d["settlement_reputation"]:
			p.settlement_reputation[str(rk)] = float(d["settlement_reputation"][rk])
	p.social_squad_anchor_id = int(d.get("social_squad_anchor_id", -1))
	# Load traits
	if d.has("trait_types") and d["trait_types"] is Array:
		for trait_type in d["trait_types"]:
			p.traits.append(Trait.new(int(trait_type)))
	var nn_data: Variant = d.get("neural_network", {})
	if nn_data is Dictionary and not (nn_data as Dictionary).is_empty():
		var restored_network: Variant = PawnData.create_neural_network({
			"openness": p.openness,
			"conscientiousness": p.conscientiousness,
			"extraversion": p.extraversion,
			"agreeableness": p.agreeableness,
			"neuroticism": p.neuroticism,
		})
		if restored_network != null and restored_network.has_method("from_dict"):
			restored_network.from_dict(nn_data)
			p.neural_network = restored_network
		_next_id = maxi(_next_id, p.id + 1)
		# Restore krond fields if present
		p.available_krond = float(d.get("available_krond", 0.0))
		p.total_krond_earned = float(d.get("total_krond_earned", 0.0))
		# Restore simple active traits list (legacy trait types supported)
		if d.has("active_traits") and d["active_traits"] is Array:
			for at in d["active_traits"]:
				# Legacy encoded trait types
				if at is Dictionary and at.has("legacy_trait_type"):
					var lt: int = int(at.get("legacy_trait_type", -1))
					if lt >= 0:
						var lt_obj: Trait = Trait.new(lt)
						p.traits.append(lt_obj)
						p.active_traits.append(lt_obj)
				# Resource-backed TraitData saved via to_dict()
				elif at is Dictionary and (at.has("id") or at.has("krond_cost") or at.has("effects")):
					# Create TraitData from dict when possible
					var td: TraitData = null
					# If we saved a resource path, try to load the resource to restore the exact object.
					if at.has("resource_path"):
						var rp := str(at.get("resource_path"))
						var loaded := ResourceLoader.load(rp)
						if loaded != null and loaded is TraitData:
							td = loaded
						else:
							# Fall back to dict-based construction via instance method if available
							if TraitData != null:
								var td_candidate := TraitData.new()
								if td_candidate.has_method("from_dict"):
									td_candidate.from_dict(at)
									td = td_candidate
								else:
									td = td_candidate
									td.id = str(at.get("id", "")) if at.has("id") else td.id
					else:
						# No resource path; try dict-based construction
						if TraitData != null:
							var td_candidate2 := TraitData.new()
							if td_candidate2.has_method("from_dict"):
								td_candidate2.from_dict(at)
								td = td_candidate2
							else:
								td = td_candidate2
								td.id = str(at.get("id", "")) if at.has("id") else td.id
					if td != null:
						p.active_traits.append(td)
				# Empty/fallback entries are ignored
		# Note: custom/resource-backed TraitData deserialization is not implemented here.
	# End neural network / trait restore block; always return constructed PawnData
	return p



func is_carrying() -> bool:
	return carrying != 0 and carrying_qty > 0


func clear_carry() -> void:
	carrying = 0
	carrying_qty = 0
