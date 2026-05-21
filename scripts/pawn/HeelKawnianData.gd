class_name HeelKawnianData
extends RefCounted

## Pure data for a single pawn. The HeelKawnian Node2D reads from this; all future
## systems (save/load, AI, macro view) will treat HeelKawnianData as the source of
## truth and HeelKawnian (the Node) as a visual representation.

enum Gender { MALE, FEMALE, OTHER }
enum BodyType { SLIM, AVERAGE, BROAD }
enum HairStyle { NONE, SHORT, MOHAWK, BUN }

## Trainable proficiencies. Higher level -> faster work + more XP per tick on
## that skill type. Pawns earn XP only while doing the matching job.
enum Skill { FORAGING, MINING, CHOPPING, BUILDING, HUNTING }
enum Profession { NONE, FARMER, BUILDER, GATHERER, WARRIOR, SCHOLAR, TRADER, SMITH, HEALER }

## Skill XP curve. Each skill tracked as raw XP; level = floor(xp / XP_PER_LEVEL).
const XP_PER_LEVEL: float = 500.0
## Soft cap. Skills can technically go higher but we display / multiply against
## this as the "mastery" mark.
const SKILL_LEVEL_MAX: int = 20
## Multiplier applied at level SKILL_LEVEL_MAX. Linear interpolation:
##   work_speed = 1.0 + (level / SKILL_LEVEL_MAX) * (SKILL_BONUS_AT_MAX - 1.0)
## At level 20 a skilled pawn works 2.0x as fast as a novice.
const SKILL_BONUS_AT_MAX: float = 2.0
const MISSING_REQUIRED_TOOL_WORK_SPEED_MULT: float = 0.5
## XP gained per tick of work on the matching skill. Tuned so a fresh pawn
## passes lvl 1 in ~one job cycle and reaches lvl 5 over a few in-game days.
const XP_PER_WORK_TICK: float = 2.0
const PROFESSION_ASSIGN_MIN_TICKS: int = 100  # Must do 100+ ticks in a category before earning profession

## Skill tree branch effects: passive bonuses from branch choices.
## Maps "skill_key:branch_name" -> {bonus_key: bonus_value}
const BRANCH_EFFECTS: Dictionary = {
	"foraging:abundant": {"yield_mult": 1.12, "crop_quality": 1.05},
	"foraging:sustainable": {"soil_decay_mult": 0.85, "water_efficiency": 1.10},
	"mining:deep_vein": {"ore_yield_mult": 1.10, "rare_ore_chance": 0.05},
	"mining:swift_strike": {"mine_speed_mult": 1.10, "stamina_cost_mult": 0.90},
	"chopping:heavy_swing": {"wood_yield_mult": 1.12, "tree_fall_speed": 1.08},
	"chopping:selective": {"sapling_preserve": 0.90, "quality_wood_mult": 1.05},
	"building:sturdy": {"structure_hp_mult": 1.15, "material_efficiency": 1.05},
	"building:elegant": {"quality_bonus": 1.10, "aesthetic_value": 1.20},
	"hunting:aggressive": {"damage_mult": 1.10, "stamina_cost_mult": 1.05},
	"hunting:patient": {"crit_chance": 0.08, "tracking_range": 1.15},
}

## Likes/dislikes categories. Each pawn gets 2-4 likes and 1-3 dislikes at birth.
const LIKE_CATEGORIES: PackedStringArray = [
	"farming", "building", "mining", "hunting", "crafting",
	"trading", "teaching", "exploring", "socializing", "resting",
]
const LIKE_THRESHOLD: float = 0.6   # >0.6 = liked
const DISLIKE_THRESHOLD: float = 0.4  # <0.4 = disliked
const LIKE_MUTATION_CHANCE: float = 0.2  # 20% chance per value to mutate on inheritance

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

## Life stages: Infant → Child → Youth → Adult → Elder → Ancient
## Each stage has different capabilities. Very Dwarf Fortress.
enum LifeStage {
	INFANT,   # 0-5 years: carried by parent, no work
	CHILD,    # 6-12 years: light tasks, learning
	YOUTH,    # 13-20 years: full work, fast learning
	ADULT,    # 21-50 years: full capability, stable
	ELDER,    # 51-70 years: slower, wisdom bonuses
	ANCIENT,  # 71+ years: very slow, revered
}

## Age thresholds for each life stage (in years)
const LIFE_STAGE_THRESHOLDS: Dictionary = {
	LifeStage.INFANT: 0,
	LifeStage.CHILD: 6,
	LifeStage.YOUTH: 13,
	LifeStage.ADULT: 21,
	LifeStage.ELDER: 51,
	LifeStage.ANCIENT: 71,
}

const LIFE_STAGE_NAMES: Dictionary = {
	LifeStage.INFANT: "Infant",
	LifeStage.CHILD: "Child",
	LifeStage.YOUTH: "Youth",
	LifeStage.ADULT: "Adult",
	LifeStage.ELDER: "Elder",
	LifeStage.ANCIENT: "Ancient",
}

## Current life stage (computed from age_years)
var life_stage: int = LifeStage.ADULT

## Ticks per in-game year. 5000 ticks = ~83 seconds at 1x, ~5 minutes at 100x.
const TICKS_PER_YEAR: int = 5000

var gender: int = Gender.OTHER
var tile_pos: Vector2i = Vector2i.ZERO

## Death flag - once true, pawn is dead and should not be processed further
## This prevents duplicate death events, biography spam, and legacy duplication
var is_dead: bool = false

## Display color used by the v1 circle renderer. Will be replaced by a sprite
## once we have pawn art. Kept on the data so it survives save/load.
var color: Color = Color.WHITE
var body_type: int = BodyType.AVERAGE
var hair_style: int = HairStyle.SHORT
var hair_color: Color = Color("#5f4630")
var apparel_color: Color = Color("#5d7ea8")

## Needs (0..100, higher is better). Will decay on tick in Phase 2b.
var hunger: float = 100.0
var thirst: float = 100.0  # NEW: Dehydrates faster than hunger
var rest: float = 100.0
var mood: float = 100.0
var health: float = 100.0
var max_health: float = 100.0
var agent_bayes_data: Dictionary = {}

## Stage 1 survival enhancements
var stamina: float = 100.0  # Depletes with work, recovers with rest
var body_temperature: float = 37.0  # Celsius, normal range 36-38
var pain: float = 0.0  # 0-100, affects work efficiency and mood
var intoxication: float = 0.0  # 0-100, from alcohol. Mood boost but reduced accuracy/speed
var exposure_sickness: float = 0.0  # 0-100, from prolonged cold/wet
var hypothermia_risk: float = 0.0  # 0-100, accumulates from cold exposure
var heat_exhaustion_risk: float = 0.0  # 0-100, accumulates from heat exposure
var wetness: float = 0.0  # 0-100, from precipitation; amplifies cold exposure

## DORMANT WORLD: Pioneer buff — first-generation pawns resist cold for 500 ticks
var is_pioneer: bool = false
var pioneer_ticks_remaining: int = 0

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

## Skill tree branch choices: skill_key -> branch_name (chosen at level 5+)
var skill_branches: Dictionary = {}

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
## Bloodline ID (-1 if not assigned)
var bloodline_id: int = -1

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
## Diaspora tracking: origin settlement for exiled pawns (-1 = native)
var _diaspora_origin: int = -1
## Diaspora tracking: tick when this pawn was exiled
var _diaspora_tick: int = -1
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
## Life-path tracks (v1): deterministic role emergence driven by settlement
## demand pressure + repeated job-type contributions. Each pawn gravitates
## toward the path whose jobs they perform most. Paths are advisory (not
## hard-gating) but emit distinct WorldMemory events and feed settlement
## role tallies used by governance / intent systems.
enum LifePath { NONE, FARMER, SOLDIER, RULER, WANDERER }
var life_path: int = LifePath.NONE
## Monotonic progress counter for current life path. Increases on
## path-aligned job completions; resets on path switch.
var life_path_progress: int = 0
## Lifetime total across ALL paths (used for milestone gating).
var life_path_total: int = 0
## Per-path contribution counts (farmer, soldier, ruler, wanderer).
var life_path_contributions: Dictionary = {"farmer": 0, "soldier": 0, "ruler": 0, "wanderer": 0}
## Regions this pawn has visited (region_key -> true). Feeds wanderer path.
var regions_visited: Dictionary = {}
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
## Final words or deathbed phrases that can be carried into memorials.
var last_words: String = ""
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
var carrying_capacity: int = 20  # OPTIMIZATION: Increased from default - pawns can carry more before returning to stockpile

## Personal inventory: multi-slot carry system.
## Each slot = {item_type: int, quantity: int}
## Max slots = 6 (hands + belt + pouch + backpack + side + back)
const INVENTORY_SLOTS: int = 6
var inventory: Array = []  # Array of {item_type: int, quantity: int}

## Equipped tool (Item.Type). None means bare-handed.
var equipped_tool: int = 0  # Item.Type.NONE
## Current durability of the equipped tool (0 = broken).
var equipped_tool_durability: int = 0

## Equipment system: 5 gear slots (Weapon, Armor, Tool, Accessory, Offhand)
## Each slot holds a GearItem or null. All gear is crafted by HeelKawnians.
## Using untyped Variant for GearItem due to class_name resolution order.
var equipped_gear: Dictionary = {
	0: null,  # GearItem.Slot.WEAPON
	1: null,  # GearItem.Slot.ARMOR
	2: null,  # GearItem.Slot.TOOL
	3: null,  # GearItem.Slot.ACCESSORY
	4: null,  # GearItem.Slot.OFFHAND
}

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
## Settlement center_region where this pawn was born (-1 if unknown or pre-system).
## Used for cultural memory and lineage-based settlement revival naming.
var birth_settlement: int = -1
var parent_a_id: int = -1
var parent_b_id: int = -1
## Inherited family trauma weights used by the decision rules.
var parental_trauma_weights: Dictionary = {}
# Generational trauma: inherited from parents, affects decision weights
var inherited_trauma: Dictionary = {
	"starvation_fear": 0.0,   # 0.0-1.0: hoard food more aggressively
	"violence_aversion": 0.0, # 0.0-1.0: avoid dangerous tiles
	"loss_grief": 0.0,        # 0.0-1.0: seek social bonds more
}
var parent_id: int = -1  # ID of the biological primary parent
var children_count: int = 0
## Likes/dislikes: randomly assigned at birth, inherited by children with mutation.
## Key = category string, value = float 0.0-1.0 (>0.6 = liked, <0.4 = disliked).
var likes: Dictionary = {}
var dislikes: Dictionary = {}
## Job tick tracking: how many ticks this pawn has spent on each job category.
## Key = category string, value = int tick count.
var job_ticks_by_category: Dictionary = {}
var influence: float = 0.0
var military_rank_legacy: String = "grunt"  # Legacy string rank, replaced by int military_rank in Stage 6
## Combat progression: XP earned through combat (synced from AICombatProgression)
var combat_xp: int = 0
## Combat progression: enemies killed (synced from AICombatProgression)
var enemies_killed: int = 0
var cohort_anchor_id: int = -1
var cohort_job_type: int = -1
var is_cohort_anchor: bool = false

## Work-type allow list (RimWorld-style). If false, this pawn will not *claim*
## that class of open job. Eating, sleeping, and hauling are not jobs; they
## are always available. Toggled from the PawnInfoPanel when a pawn is selected.
var work_forage: bool = true
var work_fish:   bool = true
var work_mine:   bool = true
var work_chop:   bool = true
var work_hunt:   bool = true
var work_build:  bool = true
var work_guard:  bool = true

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
## Personal outcomes: each HeelKawnian tracks their own success/failure rate
## action_type -> {successes: int, failures: int, last_tick: int}
var _personal_outcomes: Dictionary = {}
## Spatial memory: map of explored areas with resource locations
## tile_key -> {last_seen_tick, resource_type, danger_level, terrain_type}
var spatial_memory: Dictionary = {}
## Social memory: detailed relationships with other pawns
## other_pawn_id -> {trust, debt, grudge, friendship, last_interaction, interaction_history}
var social_memory: Dictionary = {}
## Memory decay tracking: memory_type -> last_accessed_tick
var memory_access: Dictionary = {}

## Phase 2: Per-HeelKawnian Neural Network (hidden internal state)
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

## Transient job-claim diagnostics (F10 idle audit / CreatorDebugMenu). Not saved.
var visible_orders_count: int = 0
var last_claim_failure_reason: String = ""
var last_law_breach_tick: int = -99999
var obey_score: float = 1.0


func _init() -> void:
	id = _next_id
	_next_id += 1
	# Explicit defaults (also on fields) so saves/tools never see unset sentinel bugs.
	settlement_id = -1
	current_profession = Profession.NONE
	birth_tick = int(GameManager.tick_count) if GameManager != null else 0
	initialize_affinities(birth_tick, -1, -1)
	_initialize_personality(birth_tick, parent_a_id, parent_b_id)
	_initialize_likes_dislikes(birth_tick, parent_a_id, parent_b_id)
	_initialize_neural_network()


func get_max_health() -> float:
	return max_health


## Phase 1.1: Initialize personality traits with inheritance and mutation
func _initialize_personality(init_tick: int, parent_a: int, parent_b: int) -> void:
	if parent_a >= 0 and parent_b >= 0:
		# Inherit from parents with mutation
		var parent_a_data: HeelKawnianData = _get_parent_data(parent_a)
		var parent_b_data: HeelKawnianData = _get_parent_data(parent_b)
		
		if parent_a_data != null and parent_b_data != null:
			# Blend parent personalities with mutation
			openness = _blend_with_mutation(parent_a_data.openness, parent_b_data.openness, init_tick, "openness")
			conscientiousness = _blend_with_mutation(parent_a_data.conscientiousness, parent_b_data.conscientiousness, init_tick, "conscientiousness")
			extraversion = _blend_with_mutation(parent_a_data.extraversion, parent_b_data.extraversion, init_tick, "extraversion")
			agreeableness = _blend_with_mutation(parent_a_data.agreeableness, parent_b_data.agreeableness, init_tick, "agreeableness")
			neuroticism = _blend_with_mutation(parent_a_data.neuroticism, parent_b_data.neuroticism, init_tick, "neuroticism")
		else:
			# Fallback to random if parent data unavailable
			_generate_random_personality(init_tick)
	else:
		# No parents: generate random personality
		_generate_random_personality(init_tick)


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


## Initialize likes/dislikes: randomly assigned at birth, inherited by children with mutation.
## Each pawn gets 2-4 likes and 1-3 dislikes. Children inherit from parents with 20% mutation.
func _initialize_likes_dislikes(init_tick: int, parent_a: int, parent_b: int) -> void:
	# Initialize job tick tracking
	job_ticks_by_category = {
		"farming": 0, "building": 0, "mining": 0, "hunting": 0,
		"crafting": 0, "trading": 0, "teaching": 0, "exploring": 0,
		"socializing": 0, "resting": 0,
	}
	# Generate raw values for each category
	var raw_values: Dictionary = {}
	if parent_a >= 0 and parent_b >= 0:
		var parent_a_data: HeelKawnianData = _get_parent_data(parent_a)
		var parent_b_data: HeelKawnianData = _get_parent_data(parent_b)
		if parent_a_data != null and parent_b_data != null:
			# Blend parent likes/dislikes with mutation
			for cat in LIKE_CATEGORIES:
				var val_a: float = _get_parent_like_value(parent_a_data, cat)
				var val_b: float = _get_parent_like_value(parent_b_data, cat)
				var base: float = (val_a + val_b) / 2.0
				# Mutation: 20% chance to shift significantly
				if WorldRNG.range_for(StringName("likes:mutate:%s:%d" % [cat, init_tick]), 0.0, 1.0) < LIKE_MUTATION_CHANCE:
					base = WorldRNG.range_for(StringName("likes:mutated:%s:%d" % [cat, init_tick]), 0.0, 1.0)
				raw_values[cat] = clampf(base, 0.0, 1.0)
		else:
			_generate_random_likes(init_tick, raw_values)
	else:
		_generate_random_likes(init_tick, raw_values)
	# Classify into likes and dislikes
	likes = {}
	dislikes = {}
	for cat in LIKE_CATEGORIES:
		var val: float = float(raw_values.get(cat, 0.5))
		if val >= LIKE_THRESHOLD:
			likes[cat] = val
		elif val <= DISLIKE_THRESHOLD:
			dislikes[cat] = val


func _generate_random_likes(salt: int, out: Dictionary) -> void:
	for cat in LIKE_CATEGORIES:
		out[cat] = WorldRNG.range_for(StringName("likes:%s:%d" % [cat, salt]), 0.0, 1.0)


func _get_parent_like_value(parent: HeelKawnianData, category: String) -> float:
	# If the parent explicitly likes/dislikes this category, use that value
	if parent.likes.has(category):
		return float(parent.likes[category])
	if parent.dislikes.has(category):
		return float(parent.dislikes[category])
	# Otherwise infer from affinities and job history
	var affinity_map: Dictionary = {
		"farming": "farming", "building": "building", "mining": "combat",
		"hunting": "combat", "crafting": "crafting", "trading": "diplomacy",
		"teaching": "diplomacy", "exploring": "combat", "socializing": "diplomacy",
		"resting": "farming",
	}
	var aff_key: String = str(affinity_map.get(category, ""))
	if aff_key != "" and parent.affinities.has(aff_key):
		return float(parent.affinities[aff_key])
	return 0.5


## Check if a pawn likes a job category (mood boost when doing it).
func likes_category(cat: String) -> bool:
	return likes.has(cat)


## Check if a pawn dislikes a job category (mood drain when doing it).
func dislikes_category(cat: String) -> bool:
	return dislikes.has(cat)


## Get mood modifier for a job category: +0.1 for likes, -0.1 for dislikes.
func mood_modifier_for_category(cat: String) -> float:
	if likes.has(cat):
		return 0.1
	if dislikes.has(cat):
		return -0.1
	return 0.0


## Record a tick of work in a job category. Used for profession assignment and likes evolution.
func record_job_tick(category: String) -> void:
	if not job_ticks_by_category.has(category):
		job_ticks_by_category[category] = 0
	job_ticks_by_category[category] = int(job_ticks_by_category[category]) + 1


## Get the job category for a Job.Type.
static func job_category_for_type(job_type: int) -> String:
	# Map Job.Type to like/dislike categories
	match job_type:
		0, 1:  return "farming"       # FORAGE, CHOP
		2, 3:  return "mining"        # MINE, MINE_WALL
		4:     return "building"      # BUILD_BED
		5:     return "building"      # BUILD_WALL
		6:     return "building"      # BUILD_DOOR
		7:     return "hunting"       # HUNT
		8:     return "building"      # BUILD_STORAGE
		9:     return "crafting"      # CRAFT_TOOL
		10:    return "building"      # BUILD_FIRE_PIT
		11:    return "building"      # BUILD_HEARTH
		12:    return "exploring"     # PROTECT
		13:    return "exploring"     # DEFEND
		14:    return "teaching"      # TEACH
		15:    return "crafting"      # CARVE_GRAVE_MARKER
		16:    return "crafting"      # CARVE_KNOWLEDGE_STONE
		17:    return "crafting"      # CARVE_LEDGER_STONE
		18:    return "building"      # BUILD_SHELTER
		19:    return "building"      # BUILD_MARKER_STONE
		20:    return "building"      # BUILD_SHRINE
		21:    return "socializing"   # HAUL_TO_STOCKPILE
		22:    return "farming"       # PLANT_CROP
		23:    return "farming"       # HARVEST_CROP
		24:    return "crafting"      # COOK_FOOD
		_:     return "exploring"     # default for new job types


## Static registry for pawn data lookup (set by PawnSpawner at spawn time)
static var _pawn_data_by_id: Dictionary = {}

## Register a pawn data instance for lineage lookup
static func register_pawn_data(data: HeelKawnianData) -> void:
	if data != null:
		_pawn_data_by_id[data.id] = data

## Unregister pawn data when pawn dies
static func unregister_pawn_data(pawn_id: int) -> void:
	_pawn_data_by_id.erase(pawn_id)

## Get parent data from static registry
func _get_parent_data(parent_id: int) -> HeelKawnianData:
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
	neural_network = HeelKawnianData.create_neural_network(personality_dict)


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


## Phase 1.1: Mood consistency enforcement
## Ensures mood doesn't swing too wildly between ticks based on personality
## Returns clamped mood value that respects personality-based consistency rules
func enforce_mood_consistency(new_mood: float, old_mood: float, ticks_delta: int) -> float:
	if ticks_delta <= 0:
		return new_mood
	
	var stability: float = get_mood_stability()
	var max_swing: float = 15.0 * (1.0 - stability) * float(ticks_delta)
	
	# High stability = smaller swings allowed
	if ticks_delta < 10:
		max_swing *= 0.5  # Dampen for frequent updates
	
	var swing: float = new_mood - old_mood
	if abs(swing) > max_swing:
		# Clamp the swing
		return old_mood + sign(swing) * max_swing
	
	return new_mood


## Get mood category for AI behavior (calm, neutral, agitated)
func get_mood_category() -> int:
	## 0 = agitated (<30), 1 = low (30-60), 2 = neutral (60-80), 3 = happy (>80)
	if mood < 30.0:
		return 0
	elif mood < 60.0:
		return 1
	elif mood < 80.0:
		return 2
	else:
		return 3


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
		var ticks_since_event: int = current_tick - memory.get("tick", 0) if current_tick > 0 else 0
		var decay_factor: float = exp(-ticks_since_event / 10000.0) if ticks_since_event >= 0 else 1.0  # Memories decay over ~10000 ticks
		
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
	var ticks_since_learned: int = current_tick - fact.get("learned_tick", 0) if current_tick > 0 else 0
	var decay_factor: float = exp(-ticks_since_learned / 20000.0) if ticks_since_learned >= 0 else 1.0  # Semantic memories last longer
	
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
				var ticks_since_seen: int = current_tick - memory.get("last_seen_tick", 0) if current_tick > 0 else 0
				
				# Spatial memories decay faster (geographic knowledge becomes outdated)
				var decay_factor: float = exp(-ticks_since_seen / 5000.0) if ticks_since_seen >= 0 else 1.0
				
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
	var ticks_since_interaction: int = current_tick - memory.get("last_interaction", 0)
	var decay_factor: float = exp(-ticks_since_interaction / 15000.0) if ticks_since_interaction >= 0 else 1.0  # Social memories last ~15000 ticks
	
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
		var ticks_old: int = current_tick - memory.get("tick", 0) if current_tick > 0 else 0
		if ticks_old > 20000:  # Remove very old episodic memories
			episodic_to_remove.append(event_id)
	
	for event_id in episodic_to_remove:
		episodic_memory.erase(event_id)
	
	# Decay semantic memories
	var semantic_to_remove: Array = []
	for fact_key in semantic_memory:
		var fact = semantic_memory[fact_key]
		var fact_ticks_old: int = current_tick - fact.get("learned_tick", 0) if current_tick > 0 else 0
		if fact_ticks_old > 50000:  # Remove very old semantic memories
			semantic_to_remove.append(fact_key)
	
	for fact_key in semantic_to_remove:
		semantic_memory.erase(fact_key)
	
	# Decay spatial memories
	var spatial_to_remove: Array = []
	for tile_key in spatial_memory:
		var memory = spatial_memory[tile_key]
		var spatial_ticks_old: int = current_tick - memory.get("last_seen_tick", 0) if current_tick > 0 else 0
		if spatial_ticks_old > 10000:  # Remove outdated spatial memories
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

	# Factor 10: World learning weights (colony adapts after crises)
	if context.has("learning_weights") and context["learning_weights"] is Dictionary:
		var lw: Dictionary = context["learning_weights"] as Dictionary
		var lane: String = ""
		match action_type:
			"eat", "forage", "hunt", "cook", "cook_meat", "cook_fish", "cook_berries", "dry_meat", "plant", "harvest", "grow_food":
				lane = "food_production"
			"gather", "mine", "chop", "gather_flint", "gather_stick":
				lane = "resource_gathering"
			"build", "build_shelter", "fortify", "construct", "repair":
				lane = "construction"
			"defend", "protect", "guard", "train", "fight":
				lane = "military_training"
		if lane != "":
			var w: float = float(lw.get(lane, 1.0))
			utility += (w - 1.0) * 0.8

	# Factor 11: Active goals (top goal gets a utility nudge)
	if context.has("active_goal"):
		var goal_type: String = str(context.get("active_goal", ""))
		var goal_priority: float = float(context.get("active_goal_priority", 0.0))
		var goal_bias: float = clampf(goal_priority, 0.0, 3.0) * 0.6
		if goal_bias > 0.0:
			match goal_type:
				"find_food":
					if action_type in ["eat", "forage", "hunt", "cook", "cook_meat", "cook_fish", "cook_berries", "dry_meat", "plant", "harvest", "grow_food"]:
						utility += goal_bias
				"find_rest":
					if action_type in ["rest", "sleep", "build_shelter", "build", "repair"]:
						utility += goal_bias * 0.6
				"improve_safety":
					if action_type in ["defend", "protect", "guard", "build", "fortify", "construct"]:
						utility += goal_bias * 0.6
				"improve_mood":
					if action_type in ["socialize", "talk", "rest", "wander"]:
						utility += goal_bias * 0.5
				"build_reputation", "seek_leadership":
					if action_type in ["teach", "help", "cooperate", "work", "build"]:
						utility += goal_bias * 0.4
				"master_skill":
					if action_type in ["work", "craft", "build", "gather", "mine", "chop"]:
						utility += goal_bias * 0.4
				"leave_legacy":
					if action_type in ["build", "work", "teach", "craft"]:
						utility += goal_bias * 0.3
	
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

	# Phase 5: Apply grudge-based trust penalty
	# Grudges reduce effective trust for social actions
	var grudge_penalty: float = 0.0
	if trust_n > 0:
		# Sample a few trusted pawns and check for grudges against them
		var sampled: int = 0
		for peer_id in trust:
			if sampled >= 5:  # Sample up to 5 for performance
				break
			var peer_trust: float = float(trust[peer_id])
			# If we have low trust in this pawn, check for grudges
			if peer_trust < 70.0:
				var grudge_intensity: float = _get_grudge_penalty_for_peer(peer_id)
				grudge_penalty = maxf(grudge_penalty, grudge_intensity)
			sampled += 1
	
	# Phase 5: Apply reputation-based trust modifier
	# Pawns with bad reputation are trusted less
	var reputation_modifier: float = _get_reputation_trust_modifier()

	if action_type in ["socialize", "talk", "help", "cooperate", "trade"]:
		factor += rapport_norm * 0.25
		factor += trust_norm * 0.2 * (1.0 - grudge_penalty) * (1.0 + reputation_modifier)  # Grudges reduce trust, reputation modifies
	if action_type in ["fight", "challenge"]:
		factor += (1.0 - trust_norm) * 0.2 * (1.0 + grudge_penalty) * (1.0 - reputation_modifier)  # Bad reputation = more aggression

	return clamp(factor, 0.0, 1.0)


## Get reputation-based trust modifier (-0.3 to 0.3)
## Positive for good reputation (more trust), negative for bad (less trust)
func _get_reputation_trust_modifier() -> float:
	# Get average reputation of pawns we trust
	if trust.is_empty():
		return 0.0
	
	var GossipMgr: Node = Engine.get_main_loop().get_root().get_node_or_null("SocialManager")
	if GossipMgr == null or not GossipMgr.has_method("get_reputation_for"):
		return 0.0
	
	var total_rep: float = 0.0
	var count: int = 0
	for peer_id in trust:
		if count >= 5:  # Sample up to 5 for performance
			break
		var rep: float = GossipMgr.get_reputation_for(int(peer_id))
		total_rep += rep
		count += 1
	
	if count <= 0:
		return 0.0
	
	var avg_rep: float = total_rep / float(count)
	# Scale to -0.3 to 0.3 range
	return clampf(avg_rep * 0.3, -0.3, 0.3)


## Get grudge penalty for a peer (helper for social calculations)
func _get_grudge_penalty_for_peer(peer_id: int) -> float:
	# Check if anyone holds a grudge against this peer
	var GrudgeMgr: Node = Engine.get_main_loop().get_root().get_node_or_null("SocialManager")
	if GrudgeMgr == null:
		return 0.0
	
	# Get grudges against this peer
	var grudges: Array = []
	if GrudgeMgr.has_method("get_grudges_against"):
		grudges = GrudgeMgr.get_grudges_against(int(peer_id))
	
	if grudges.is_empty():
		return 0.0
	
	# Find maximum grudge intensity
	var max_intensity: float = 0.0
	for grudge in grudges:
		if grudge is Dictionary:
			max_intensity = maxf(max_intensity, float(grudge.get("intensity", 0.0)))
	
	return max_intensity


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


## Record a personal outcome for this specific HeelKawnian.
## action_type: e.g. "forage", "mine", "build", "chop", "hunt", "fish"
## success: whether the action succeeded
func record_personal_outcome(action_type: String, success: bool) -> void:
	if not _personal_outcomes.has(action_type):
		_personal_outcomes[action_type] = {"successes": 0, "failures": 0, "last_tick": 0}
	var entry: Dictionary = _personal_outcomes[action_type]
	if success:
		entry.successes = min(entry.successes + 1, 50)  # Cap to prevent runaway
	else:
		entry.failures = min(entry.failures + 1, 50)
	entry.last_tick = GameManager.tick_count if GameManager != null else 0


## Get personal confidence (0.0-1.0) for an action type based on own experience.
## 0.5 = no experience (neutral). Higher = more success. Lower = more failure.
func personal_confidence_for(action_type: String) -> float:
	if not _personal_outcomes.has(action_type):
		return 0.5  # No experience = neutral
	var entry: Dictionary = _personal_outcomes[action_type]
	var total: int = entry.successes + entry.failures
	if total == 0:
		return 0.5
	# Weight recent outcomes more: if last_tick is recent, confidence matters more
	var tick: int = GameManager.tick_count if GameManager != null else 0
	var recency: float = 1.0
	if entry.last_tick > 0:
		var age: int = tick - int(entry.last_tick)
		if age > 5000:
			recency = 0.5  # Old outcomes matter less
		elif age > 2000:
			recency = 0.75
	# Calculate confidence with recency weighting
	var raw: float = float(entry.successes) / float(total)
	return lerpf(0.5, raw, recency)  # Blend toward 0.5 for old outcomes


## Get a job-type-mapped personal confidence.
## Maps Job.Type integers to action strings for personal learning.
func personal_confidence_for_job(job_type: int) -> float:
	var action: String = ""
	match job_type:
		0: action = "forage"       # FORAGE
		1: action = "chop"         # CHOP
		2: action = "mine"         # MINE
		3: action = "build"        # BUILD_BED
		4: action = "build"        # BUILD_WALL
		5: action = "build"        # BUILD_DOOR
		6: action = "gather"       # GATHER_FLINT
		7: action = "gather"       # GATHER_STICK
		8: action = "hunt"         # HUNT
		9: action = "fish"         # FISH
		10: action = "build"       # BUILD_FIRE_PIT
		11: action = "build"       # BUILD_STORAGE_HUT
		12: action = "cook"        # COOK_MEAT
		13: action = "cook"        # COOK_FISH
		14: action = "cook"        # COOK_BERRIES
		15: action = "carve"       # CARVE_GRAVE_MARKER
		16: action = "carve"       # CARVE_KNOWLEDGE_STONE
		17: action = "carve"       # CARVE_LEDGER_STONE
		18: action = "plant"       # PLANT_SEEDS
		19: action = "harvest"     # HARVEST_CROPS
		20: action = "build"       # BUILD_SHELTER
		21: action = "build"       # BUILD_HEARTH
		22: action = "build"       # BUILD_MARKER_STONE
		23: action = "build"       # BUILD_SHRINE
		24: action = "teach"       # TEACH_SKILL
		25: action = "teach"       # APPRENTICESHIP
		26: action = "protect"     # PROTECT
		27: action = "defend"      # DEFEND
		28: action = "mine"        # MINE_WALL
		29: action = "build"       # BUILD_STOCKPILE
		_: action = "work"        # Generic fallback
	if action == "":
		return 0.5
	return personal_confidence_for(action)


func get_health_percentage() -> float:
	if max_health <= 0.0:
		return 0.0
	return clamp(health / max_health, 0.0, 1.0)


## Compute life stage from current age_years.
func compute_life_stage() -> int:
	if age_years >= 71.0:
		return LifeStage.ANCIENT
	elif age_years >= 51.0:
		return LifeStage.ELDER
	elif age_years >= 21.0:
		return LifeStage.ADULT
	elif age_years >= 13.0:
		return LifeStage.YOUTH
	elif age_years >= 6.0:
		return LifeStage.CHILD
	else:
		return LifeStage.INFANT


## Get the name of the current life stage.
func get_life_stage_name() -> String:
	return LIFE_STAGE_NAMES.get(life_stage, "Unknown")


## Age the pawn by one tick. Call from the tick loop.
func age_one_tick() -> void:
	age_years += 1.0 / float(TICKS_PER_YEAR)
	var old_stage: int = life_stage
	life_stage = compute_life_stage()
	age = int(age_years)
	# Life stage transition events
	if life_stage != old_stage:
		var stage_name: String = get_life_stage_name()
		WorldMemory.record_event({
			"kind": WorldMemory.Kind.LIFE_EVENT,
			"tick": GameManager.tick_count if GameManager != null else 0,
			"pawn_id": int(id),
			"pawn_name": display_name,
			"life_stage": stage_name,
			"age": int(age_years),
		})
		add_mood_event(MoodEvent.Type.JOY, 30.0, 500)
		# Infants can't work. Children do light tasks. Elders slow down.
		if life_stage == LifeStage.INFANT:
			# Infants are carried — no work, no movement
			pass
		elif life_stage == LifeStage.ELDER:
			# Elders get wisdom bonuses but physical decline
			max_health = maxf(50.0, max_health - 10.0)
		elif life_stage == LifeStage.ANCIENT:
			# Ancients are revered but fragile
			max_health = maxf(30.0, max_health - 15.0)


## Work speed multiplier based on life stage.
func life_stage_work_mult() -> float:
	match life_stage:
		LifeStage.INFANT: return 0.0   # Can't work
		LifeStage.CHILD: return 0.4    # Light tasks only
		LifeStage.YOUTH: return 0.9    # Almost full, fast learner
		LifeStage.ADULT: return 1.0    # Full capability
		LifeStage.ELDER: return 0.7    # Slower, wiser
		LifeStage.ANCIENT: return 0.4  # Very slow
		_: return 1.0


## Movement speed multiplier based on life stage.
func life_stage_move_mult() -> float:
	match life_stage:
		LifeStage.INFANT: return 0.0   # Carried
		LifeStage.CHILD: return 0.7    # Shorter legs
		LifeStage.YOUTH: return 1.0    # Full speed
		LifeStage.ADULT: return 1.0    # Full speed
		LifeStage.ELDER: return 0.6    # Slower
		LifeStage.ANCIENT: return 0.3  # Very slow
		_: return 1.0


## Learning speed multiplier based on life stage.
func life_stage_learn_mult() -> float:
	match life_stage:
		LifeStage.INFANT: return 0.0   # Can't learn skills
		LifeStage.CHILD: return 1.5    # Fast learner
		LifeStage.YOUTH: return 1.3    # Still fast
		LifeStage.ADULT: return 1.0    # Normal
		LifeStage.ELDER: return 0.8    # Slower but wise
		LifeStage.ANCIENT: return 0.5  # Very slow
		_: return 1.0


## Can this pawn work at all?
func can_work() -> bool:
	return life_stage != LifeStage.INFANT


## Can this pawn claim jobs?
func can_claim_jobs() -> bool:
	return life_stage >= LifeStage.CHILD


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
func process_tick(_delta: float) -> void:
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


## PHASE 4: Get highest skill level across all skills (for event significance gating)
func get_highest_skill_level() -> int:
	var highest: int = 0
	for skill_idx in range(5):  # FORAGING, MINING, CHOPPING, BUILDING, HUNTING
		var level: int = get_skill_level(skill_idx)
		if level > highest:
			highest = level
	return highest


## Add XP to a skill. Returns true when the level changed (so callers can log
## a "Brenna's mining went up to 3!" message).
func add_skill_xp(skill: int, amount: float) -> bool:
	var before: int = get_skill_level(skill)
	var trait_mult: float = get_trait_mult("skill_xp_mult")
	var cat: String = tree_skill_category_for_job_skill(skill)
	var tree_xp: float = skill_tree_bonus_product_for_category(cat, "xp_mult")
	var branch_bonuses: Dictionary = get_branch_bonus(skill)
	var branch_xp: float = 1.0
	if branch_bonuses.has("xp_mult"):
		branch_xp = float(branch_bonuses["xp_mult"])
	skill_xp[skill] = get_skill_xp(skill) + amount * trait_mult * tree_xp * branch_xp

	# Stage 1: Track last used time for XP decay
	skill_last_used[skill] = GameManager.tick_count if GameManager != null else 0

	# Auto-assign profession when pawn has done enough work in a category
	# and doesn't dislike it. Requires PROFESSION_ASSIGN_MIN_TICKS in that category.
	if current_profession == Profession.NONE and cat != "" and get_skill_xp(skill) >= 30.0:
		var job_cat: String = _skill_to_like_category(cat)
		var ticks_in_cat: int = int(job_ticks_by_category.get(job_cat, 0))
		if ticks_in_cat >= PROFESSION_ASSIGN_MIN_TICKS and not dislikes.has(job_cat):
			current_profession = _skill_to_profession(cat)
			apparel_color = profession_apparel_color(current_profession)

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


func _record_profession_mastered_chronicle(tier: String, branch_skill: String, tier_level: int) -> void:
	if WorldMemory == null or branch_skill.is_empty():
		return
	var prof_name: String = profession_name() if current_profession != Profession.NONE else "laborer"
	WorldMemory.record_event({
		"type": "profession_mastered",
		"tick": GameManager.tick_count if GameManager != null else 0,
		"pawn_id": int(id),
		"pawn_name": display_name,
		"profession": prof_name,
		"branch_skill": branch_skill,
		"tier": tier,
		"tier_level": tier_level,
	})


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
	_record_profession_mastered_chronicle("basic", primary_skill, 5)
	print("[HeelKawnianData] %s unlocked basic %s branch" % [display_name, primary_skill])


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
	_record_profession_mastered_chronicle("intermediate", primary_skill, 10)
	print("[HeelKawnianData] %s unlocked intermediate %s branch" % [display_name, primary_skill])


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
	_record_profession_mastered_chronicle("advanced", primary_skill, 15)
	print("[HeelKawnianData] %s unlocked advanced %s branch" % [display_name, primary_skill])


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
	_record_profession_mastered_chronicle("mastery", primary_skill, 20)
	print("[HeelKawnianData] %s achieved MASTERY in %s" % [display_name, primary_skill])


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


## Teaching branch: multiplies XP granted to students in [method HeelKawnian.teach_skill].
func teach_efficiency_multiplier() -> float:
	var entry: Variant = skill_trees.get("teaching", null)
	if entry is Dictionary and bool((entry as Dictionary).get("unlocked", false)):
		var bonuses: Dictionary = (entry as Dictionary).get("bonuses", {}) as Dictionary
		if bonuses.has("teach_efficiency"):
			return maxf(0.25, float(bonuses["teach_efficiency"]))
	return 1.0


func _root_node_or_null(node_name: String) -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null(node_name)


func bloodline_pride_mood_bonus() -> float:
	if bloodline_id < 0:
		return 0.0
	var bloodline_sys: Node = _root_node_or_null("SocialManager")
	if bloodline_sys != null and bloodline_sys.has_method("get_bloodline_pride_mood_bonus"):
		return clampf(float(bloodline_sys.call("get_bloodline_pride_mood_bonus", bloodline_id)), 0.0, 0.08)
	return 0.0


func bloodline_specialization_multiplier(skill: int) -> float:
	if bloodline_id < 0:
		return 1.0
	var bloodline_sys: Node = _root_node_or_null("SocialManager")
	if bloodline_sys != null and bloodline_sys.has_method("get_bloodline_specialization_multiplier"):
		return maxf(0.85, float(bloodline_sys.call("get_bloodline_specialization_multiplier", bloodline_id, skill)))
	return 1.0


func _related_pawn_ids() -> PackedInt32Array:
	var out: PackedInt32Array = []
	var seen: Dictionary = {}
	for rid in [parent_a_id, parent_b_id, spouse_id]:
		if rid >= 0 and not seen.has(rid):
			seen[rid] = true
			out.append(rid)
	for cid in children_ids:
		if cid >= 0 and not seen.has(cid):
			seen[cid] = true
			out.append(cid)
	for fid_any in family_bonds.keys():
		var fid: int = int(fid_any)
		if fid >= 0 and not seen.has(fid):
			seen[fid] = true
			out.append(fid)
	return out


func kinship_mood_bonus() -> float:
	var delta: float = bloodline_pride_mood_bonus()
	for rid in _related_pawn_ids():
		var rel: HeelKawnianData = _pawn_data_by_id.get(rid, null)
		var bond: float = float(family_bonds.get(rid, 0.0))
		if rel != null:
			var health_ratio: float = clampf(rel.health / maxf(1.0, rel.max_health), 0.0, 1.0)
			if health_ratio >= 0.75:
				delta += 0.002 + bond / 50000.0
			elif health_ratio <= 0.25:
				delta -= 0.004
		else:
			delta -= 0.006
	return clampf(delta, -0.05, 0.05)


func kinship_work_speed_multiplier(work_tile: Vector2i, radius: int = 6) -> float:
	var mult: float = 1.0
	for rid in _related_pawn_ids():
		var rel: HeelKawnianData = _pawn_data_by_id.get(rid, null)
		if rel == null:
			continue
		if work_tile.distance_to(rel.tile_pos) > float(radius):
			continue
		var bond: float = float(family_bonds.get(rid, 0.0))
		mult += 0.015 + bond / 10000.0
	return clampf(mult, 1.0, 1.15)


func kinship_job_priority_bonus(work_tile: Vector2i, radius: int = 6) -> int:
	var bonus: int = 0
	for rid in _related_pawn_ids():
		var rel: HeelKawnianData = _pawn_data_by_id.get(rid, null)
		if rel == null:
			continue
		if work_tile.distance_to(rel.tile_pos) > float(radius):
			continue
		bonus += 1
	return mini(3, bonus)


func kinship_teach_efficiency_multiplier(target_pawn_id: int) -> float:
	if target_pawn_id < 0:
		return 1.0
	var mult: float = 1.0
	if target_pawn_id == spouse_id:
		mult *= 1.35
	if target_pawn_id == parent_a_id or target_pawn_id == parent_b_id or target_pawn_id in children_ids:
		mult *= 1.20
	if family_bonds.has(target_pawn_id):
		var bond: float = clampf(float(family_bonds[target_pawn_id]) / 100.0, 0.0, 1.0)
		mult *= lerpf(1.0, 1.12, bond)
	return mult


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


## Choose a skill tree branch for a given skill. Must be at least level 5
## and not already have a branch chosen for this skill.
## Returns true if successful, false if already chosen or level too low.
func choose_skill_branch(skill: int, branch_name: String) -> bool:
	var skill_key: String = _skill_enum_to_key(skill)
	if skill_key.is_empty():
		return false
	if skill_branches.has(skill_key):
		return false
	var skill_level: int = get_skill_level(skill)
	if skill_level < 5:
		return false
	var branch_key: String = "%s:%s" % [skill_key, branch_name]
	if not BRANCH_EFFECTS.has(branch_key):
		return false
	skill_branches[skill_key] = branch_name
	var bonuses: Dictionary = BRANCH_EFFECTS[branch_key] as Dictionary
	var bonus_desc: String = ""
	for bkey in bonuses:
		if not bonus_desc.is_empty():
			bonus_desc += ", "
		bonus_desc += "%s=%.2f" % [bkey, float(bonuses[bkey])]
	append_biography_line("Branch choice: %s -> %s (%s)" % [skill_key, branch_name, bonus_desc])
	return true


## Get the passive bonuses from a branch choice for a specific skill.
## Returns a Dictionary of bonus_key -> value, or empty if no branch chosen.
func get_branch_bonus(skill: int) -> Dictionary:
	var result: Dictionary = {}
	var skill_key: String = _skill_enum_to_key(skill)
	if skill_key.is_empty():
		return result
	if not skill_branches.has(skill_key):
		return result
	var branch_key: String = skill_branches[skill_key]
	if not BRANCH_EFFECTS.has(branch_key):
		return result
	var bonuses: Dictionary = BRANCH_EFFECTS[branch_key] as Dictionary
	for bkey in bonuses:
		result[bkey] = float(bonuses[bkey])
	return result


## Get all branch bonuses merged across all skills with branch choices.
func get_all_branch_bonuses() -> Dictionary:
	var result: Dictionary = {}
	for skill_key in skill_branches:
		var branch_key: String = skill_branches[skill_key]
		if not BRANCH_EFFECTS.has(branch_key):
			continue
		var bonuses: Dictionary = BRANCH_EFFECTS[branch_key] as Dictionary
		for bkey in bonuses:
			var val: float = float(bonuses[bkey])
			if result.has(bkey):
				result[bkey] = float(result[bkey]) * val
			else:
				result[bkey] = val
	return result


## Map a Skill enum int to the lowercase key used in BRANCH_EFFECTS.
static func _skill_enum_to_key(skill: int) -> String:
	match skill:
		Skill.FORAGING: return "foraging"
		Skill.MINING:   return "mining"
		Skill.CHOPPING: return "chopping"
		Skill.BUILDING: return "building"
		Skill.HUNTING:  return "hunting"
	return ""


## Inherit knowledge from both parents. Child has a 60% chance to inherit
## each knowledge type the parents know, 85% if both parents know it.
## Returns list of inherited knowledge type integers.
func inherit_knowledge_from_parents(parent_a_id: int, parent_b_id: int) -> Array[int]:
	var inherited: Array[int] = []
	var ks: Node = Engine.get_main_loop().get_root().get_node_or_null("KnowledgeSystem")
	if ks == null or not ks.has_method("get_pawn_knowledge"):
		return inherited
	var parent_a_known: Array = ks.call("get_pawn_knowledge", parent_a_id)
	var parent_b_known: Array = ks.call("get_pawn_knowledge", parent_b_id)
	var all_known: Dictionary = {}
	for kt in parent_a_known:
		all_known[int(kt)] = all_known.get(int(kt), 0) + 1
	for kt in parent_b_known:
		all_known[int(kt)] = all_known.get(int(kt), 0) + 1
	for kt in all_known:
		var count: int = int(all_known[kt])
		var chance: float = 0.60 if count == 1 else 0.85
		var salt: StringName = StringName("knowledge_inherit:%d:%d:%d" % [id, kt, birth_tick])
		if WorldRNG.range_for(salt, 0.0, 1.0) < chance:
			inherited.append(int(kt))
			if ks.has_method("add_knowledge_carrier"):
				ks.call("add_knowledge_carrier", id, kt)
	return inherited


## Inherit reputation from bloodline. Child starts with 25% of the family's
## average reputation. Returns {reputation_delta: float, source_bloodline: String}.
func inherit_reputation_from_bloodline(bloodline: String) -> Dictionary:
	var result: Dictionary = {"reputation_delta": 0.0, "source_bloodline": bloodline}
	var parent_a_data: HeelKawnianData = _pawn_data_by_id.get(parent_a_id, null)
	var parent_b_data: HeelKawnianData = _pawn_data_by_id.get(parent_b_id, null)
	if parent_a_data == null and parent_b_data == null:
		return result
	var avg_rep: float = 50.0
	var count: int = 0
	if parent_a_data != null:
		avg_rep += float(parent_a_data.reputation_score)
		count += 1
	if parent_b_data != null:
		avg_rep += float(parent_b_data.reputation_score)
		count += 1
	if count > 0:
		avg_rep /= float(count)
	var inherited_rep: float = (avg_rep - 50.0) * 0.25
	reputation_score = clampf(reputation_score + inherited_rep, 0.0, 100.0)
	result["reputation_delta"] = inherited_rep
	return result


## Inherit grudges from both parents. Child inherits grudges against the
## parents' enemies with 40% intensity. Returns count of inherited grudges.
static func inherit_grudges_from_parents(parent_a_id: int, parent_b_id: int, child_id: int) -> int:
	var gm: Node = Engine.get_main_loop().get_root().get_node_or_null("GrudgeManager")
	if gm == null or not gm.has_method("get_grudges_held_by"):
		return 0
	var inherited_count: int = 0
	var tick: int = GameManager.tick_count if GameManager != null else 0
	for parent_id in [parent_a_id, parent_b_id]:
		if parent_id < 0:
			continue
		var parent_grudges: Array = gm.call("get_grudges_held_by", parent_id)
		for grudge in parent_grudges:
			if not (grudge is Dictionary):
				continue
			var target_id: int = int(grudge.get("target_id", -1))
			if target_id < 0 or child_id == target_id:
				continue
			var grudge_type: String = str(grudge.get("type", ""))
			var parent_intensity: float = float(grudge.get("intensity", 0.0))
			var inherited_intensity: float = parent_intensity * 0.40
			if inherited_intensity < 0.1:
				continue
			if gm.has_method("has_grudge") and bool(gm.call("has_grudge", child_id, target_id, 0.1)):
				continue
			if gm.has_method("record_grudge"):
				gm.call("record_grudge", child_id, target_id, grudge_type, 0, "inherited", tick)
				inherited_count += 1
	return inherited_count


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
	var bloodline_mult: float = bloodline_specialization_multiplier(skill)
	var branch_bonuses: Dictionary = get_branch_bonus(skill)
	var branch_mult: float = 1.0
	if branch_bonuses.has("work_speed_mult"):
		branch_mult = float(branch_bonuses["work_speed_mult"])
	elif branch_bonuses.has("gather_speed_mult"):
		branch_mult = float(branch_bonuses["gather_speed_mult"])
	elif branch_bonuses.has("mine_speed_mult"):
		branch_mult = float(branch_bonuses["mine_speed_mult"])
	return base * tree_mult * bloodline_mult * branch_mult


func has_tool_required(job_type: int) -> bool:
	var required_tools: Array[int] = required_tools_for_job(job_type)
	if required_tools.is_empty():
		return true
	if not is_equipped_tool_valid():
		return false
	return required_tools.has(equipped_tool)


func get_work_speed_for_job(job_type: int) -> float:
	var skill: int = skill_for_job(job_type)
	var speed: float = 1.0
	if skill >= 0:
		speed = work_speed_for(skill)
	speed *= get_tool_efficacy(job_type)
	if not has_tool_required(job_type):
		speed *= MISSING_REQUIRED_TOOL_WORK_SPEED_MULT
	return speed


static func required_tools_for_job(job_type: int) -> Array[int]:
	match job_type:
		Job.Type.MINE, Job.Type.MINE_WALL:
			return [Item.Type.FLINT_PICK]
		Job.Type.CHOP:
			return [Item.Type.FLINT_KNIFE]
		Job.Type.HUNT, Job.Type.PROTECT, Job.Type.DEFEND:
			return [Item.Type.WOODEN_SPEAR, Item.Type.FLINT_KNIFE]
	return []


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
		"mining":
			return Profession.BUILDER
		"crafting":
			return Profession.BUILDER
		"foraging":
			return Profession.GATHERER
		"hunting":
			return Profession.WARRIOR
		"teaching":
			return Profession.SCHOLAR
		_:
			return Profession.NONE


func _skill_to_like_category(skill_key: String) -> String:
	# Map internal skill keys to like/dislike categories
	match skill_key:
		"farming", "foraging":
			return "farming"
		"building", "crafting":
			return "building"
		"mining":
			return "mining"
		"combat", "hunting":
			return "hunting"
		"movement":
			return "exploring"
		"teaching":
			return "teaching"
		"gathering":
			return "farming"
		_:
			return "exploring"


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


## Reassign profession if a non-primary skill has grown far beyond the
## current profession's primary skill. Threshold: the new skill must have
## ≥2x the XP of the current primary, and both must be ≥30 (the initial
## assign threshold). This prevents pawns from being locked into roles
## that no longer match what they actually do.
func _maybe_reassign_profession(_just_gained_key: String) -> void:
	if current_profession == Profession.NONE:
		return
	var primary: String = _profession_primary_skill(current_profession)
	if primary == "":
		return
	var primary_xp: int = tracked_skill_xp(primary)
	var best_key: String = ""
	var best_xp: int = primary_xp
	for k in skills:
		var xp: int = int(skills[k])
		if xp > best_xp:
			best_xp = xp
			best_key = k
	# Only reassign if the best skill is different and significantly stronger
	if best_key != "" and best_key != primary and best_xp >= 30 and best_xp >= primary_xp * 2:
		var new_prof: int = _skill_to_profession(best_key)
		if new_prof != Profession.NONE and new_prof != current_profession:
			current_profession = new_prof
			apparel_color = profession_apparel_color(current_profession)


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
		Profession.TRADER:
			return "Trader"
		Profession.SMITH:
			return "Smith"
		Profession.HEALER:
			return "Healer"
		_:
			return "None"


## Returns the apparel color for a given profession. Used to visually
## distinguish pawns by role — the pixel sprite torso uses apparel_color.
static func profession_apparel_color(prof: int) -> Color:
	match prof:
		Profession.FARMER:
			return Color("#7a9a4a")   # earthy green
		Profession.BUILDER:
			return Color("#8a7a6a")   # dusty brown
		Profession.GATHERER:
			return Color("#5a8a5a")   # forest green
		Profession.WARRIOR:
			return Color("#8a3a3a")   # dark red
		Profession.SCHOLAR:
			return Color("#4a5a8a")   # deep blue
		Profession.TRADER:
			return Color("#8a7a3a")   # gold/amber
		Profession.SMITH:
			return Color("#5a5a5a")   # dark gray (steel)
		Profession.HEALER:
			return Color("#5a8a7a")   # teal
		_:
			return Color("#5d7ea8")   # default (original random base)


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
	var before: int = tracked_skill_xp(skill_key)
	var after: int = before + amount
	var just_locked: bool = false
	if current_profession == Profession.NONE and after >= 30:
		current_profession = _skill_to_profession(skill_key)
		apparel_color = profession_apparel_color(current_profession)
		just_locked = true
	skills[skill_key] = after
	add_liking_from_action_skill(skill_key, amount)
	# Check for profession reassignment: if a non-primary skill has grown
	# significantly beyond the current profession's primary, switch roles.
	_maybe_reassign_profession(skill_key)
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
			_bump_lane("inquiry", maxi(1, int(float(w) * 0.25)))
		Job.Type.MINE_WALL:
			_bump_lane("industry", w)
			_bump_lane("inquiry", w)
			_bump_lane("structure", maxi(1, int(float(w) * 0.2)))
		Job.Type.CHOP:
			_bump_lane("industry", w)
			_bump_lane("outdoors", maxi(1, int(float(w) * 0.3333333333)))
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
			_bump_lane("circulation", maxi(1, int(float(a) * 0.5)))
		"farming":
			_bump_lane("tillage", a)
			_bump_lane("outdoors", maxi(1, int(float(a) * 0.3333333333)))
		"building":
			_bump_lane("structure", a)
			_bump_lane("industry", maxi(1, int(float(a) * 0.3333333333)))
		"gathering":
			_bump_lane("tillage", maxi(1, int(float(a) * 0.5)))
			_bump_lane("outdoors", a)
		"combat":
			_bump_lane("martial", a)
			_bump_lane("inquiry", maxi(1, int(float(a) * 0.25)))
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
	# Gear work speed bonus
	var gear_ws: float = 1.0
	var gs: Dictionary = get_gear_stats()
	if gs.has("work_speed"):
		gear_ws = 1.0 + float(gs["work_speed"])
	return base_mult * trait_mult * physical_scar_labor_mult() * gear_ws


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
		Job.Type.GATHER_FLINT: return Skill.MINING
		Job.Type.GATHER_STICK: return Skill.FORAGING
		Job.Type.CRAFT_KNIFE:  return Skill.BUILDING
		Job.Type.CRAFT_TORCH:  return Skill.BUILDING
		Job.Type.CRAFT_PICK:   return Skill.BUILDING
		Job.Type.CRAFT_SPEAR:  return Skill.HUNTING
		Job.Type.BUILD_FIRE_PIT:    return Skill.BUILDING
		Job.Type.BUILD_STORAGE_HUT: return Skill.BUILDING
		Job.Type.BUILD_STOCKPILE:   return Skill.BUILDING
		Job.Type.BUILD_MARKER_STONE:return Skill.BUILDING
		Job.Type.BUILD_SHRINE:      return Skill.BUILDING
		Job.Type.COOK_MEAT:         return Skill.BUILDING
		Job.Type.COOK_BERRIES:      return Skill.FORAGING
		Job.Type.COOK_FISH:         return Skill.FORAGING
		Job.Type.DRY_MEAT:          return Skill.BUILDING
		Job.Type.PLANT_SEEDS:       return Skill.FORAGING
		Job.Type.HARVEST_CROPS:     return Skill.FORAGING
		Job.Type.BUILD_SHELTER, Job.Type.BUILD_HEARTH:
			return Skill.BUILDING
		Job.Type.TEACH_SKILL, Job.Type.APPRENTICESHIP:
			return Skill.BUILDING
		Job.Type.GROW_FOOD:
			return Skill.FORAGING
		Job.Type.PROTECT, Job.Type.DEFEND:
			return Skill.HUNTING
		# Phase 6: new building skills
		Job.Type.BUILD_FARM_WHEAT, Job.Type.BUILD_FARM_CORN, Job.Type.BUILD_FARM_VEGETABLES, Job.Type.BUILD_HERB_GARDEN:
			return Skill.FORAGING  # Agriculture
		Job.Type.BUILD_WORKSHOP, Job.Type.BUILD_LOOM, Job.Type.BUILD_KILN, Job.Type.BUILD_SMELTER:
			return Skill.BUILDING  # Production
		Job.Type.BUILD_BOATYARD, Job.Type.BUILD_DOCK, Job.Type.BUILD_FISHERMAN_HUT:
			return Skill.BUILDING  # Maritime
		Job.Type.BUILD_APOTHECARY:
			return Skill.BUILDING  # Medicine
		Job.Type.BUILD_LIBRARY, Job.Type.BUILD_SCHOOL:
			return Skill.BUILDING  # Knowledge
		Job.Type.BUILD_BARRACKS, Job.Type.BUILD_WATCHTOWER:
			return Skill.BUILDING  # Military
		Job.Type.BUILD_MARKET, Job.Type.BUILD_TRADING_POST:
			return Skill.BUILDING  # Trade
		Job.Type.BUILD_ROAD:
			return Skill.BUILDING  # Infrastructure
		Job.Type.BUILD_GRANARY, Job.Type.BUILD_CELLAR, Job.Type.BUILD_FORD, Job.Type.BUILD_WATER_MILL:
			return Skill.BUILDING  # Storage / river / mill
		Job.Type.MAINTAIN_STRUCTURE:
			return Skill.BUILDING
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
		Job.Type.FISH:
			return work_fish
			return work_build
		Job.Type.TRADE_HAUL:
			return true
		Job.Type.GATHER_FLINT:
			return work_mine
		Job.Type.GATHER_STICK:
			return work_forage
		Job.Type.CRAFT_KNIFE, Job.Type.CRAFT_TORCH, Job.Type.CRAFT_PICK, Job.Type.CRAFT_SPEAR:
			return work_build
		Job.Type.BUILD_FIRE_PIT, Job.Type.BUILD_STORAGE_HUT, 		Job.Type.BUILD_MARKER_STONE, Job.Type.BUILD_SHRINE:
			return work_build
		Job.Type.COOK_MEAT, Job.Type.COOK_BERRIES, Job.Type.COOK_FISH, Job.Type.DRY_MEAT:
			return work_forage
		Job.Type.PLANT_SEEDS, Job.Type.HARVEST_CROPS:
			return work_forage
		Job.Type.BUILD_SHELTER, Job.Type.BUILD_HEARTH:
			return work_build
		Job.Type.TEACH_SKILL, Job.Type.APPRENTICESHIP:
			return work_build
		Job.Type.GROW_FOOD:
			return work_forage
		Job.Type.PROTECT, Job.Type.DEFEND:
			return work_hunt
		Job.Type.GUARD:
			return work_guard
		# Phase 6: new building job permissions
		Job.Type.BUILD_FARM_WHEAT, Job.Type.BUILD_FARM_CORN, Job.Type.BUILD_FARM_VEGETABLES, Job.Type.BUILD_HERB_GARDEN:
			return work_forage  # Agriculture = foraging skill
		Job.Type.BUILD_WORKSHOP, Job.Type.BUILD_LOOM, Job.Type.BUILD_KILN, Job.Type.BUILD_SMELTER, \
		Job.Type.BUILD_BOATYARD, Job.Type.BUILD_DOCK, Job.Type.BUILD_FISHERMAN_HUT, \
		Job.Type.BUILD_APOTHECARY, \
		Job.Type.BUILD_LIBRARY, Job.Type.BUILD_SCHOOL, \
		Job.Type.BUILD_BARRACKS, Job.Type.BUILD_WATCHTOWER, \
		Job.Type.BUILD_MARKET, Job.Type.BUILD_TRADING_POST, \
		Job.Type.BUILD_ROAD, \
		Job.Type.BUILD_GRANARY, Job.Type.BUILD_CELLAR, \
		Job.Type.BUILD_BREWERY, Job.Type.BUILD_TAVERN, \
		Job.Type.BUILD_FORD, Job.Type.BUILD_WATER_MILL:
			return work_build  # All construction = building skill
		Job.Type.BREW_MEAD, Job.Type.BREW_ALE:
			return work_build  # Brewing = building skill
		Job.Type.DRINK:
			return true  # Anyone can drink
		Job.Type.MAINTAIN_STRUCTURE:
			return work_build
	return true


func _allows_job_type_lightweight(job_type: int) -> bool:
	if job_type == Job.Type.FORAGE:
		return work_forage
	if job_type == Job.Type.CHOP:
		return work_chop
	if job_type == Job.Type.HUNT:
		return work_hunt
	if job_type == Job.Type.FISH:
		return work_fish
	if job_type == Job.Type.MINE:
		return work_mine and profession_progress_xp() >= 100
	if job_type == Job.Type.BUILD_BED or job_type == Job.Type.BUILD_DOOR:
		return work_build and profession_progress_xp() >= 300
	if job_type == Job.Type.BUILD_WALL or job_type == Job.Type.MINE_WALL:
		return work_build and work_mine and profession_progress_xp() >= 500
	if job_type == Job.Type.TRADE_HAUL:
		return profession_progress_xp() >= 800
	if job_type == Job.Type.GATHER_FLINT:
		return work_mine
	if job_type == Job.Type.GATHER_STICK:
		return work_forage
	if job_type == Job.Type.CRAFT_KNIFE or job_type == Job.Type.CRAFT_TORCH:
		return work_build and profession_progress_xp() >= 50
	if job_type == Job.Type.CRAFT_PICK or job_type == Job.Type.CRAFT_SPEAR:
		return work_build and profession_progress_xp() >= 150
	if job_type == Job.Type.BUILD_FIRE_PIT or job_type == Job.Type.BUILD_STORAGE_HUT:
		return work_build and profession_progress_xp() >= 200
	if job_type == Job.Type.BUILD_MARKER_STONE or job_type == Job.Type.BUILD_SHRINE:
		return work_build and profession_progress_xp() >= 400
	if job_type == Job.Type.COOK_MEAT or job_type == Job.Type.COOK_BERRIES or job_type == Job.Type.COOK_FISH:
		return work_forage and profession_progress_xp() >= 100
	if job_type == Job.Type.DRY_MEAT:
		return work_forage and profession_progress_xp() >= 200
	if job_type == Job.Type.PLANT_SEEDS or job_type == Job.Type.HARVEST_CROPS:
		return work_forage and profession_progress_xp() >= 50
	if job_type == Job.Type.BUILD_SHELTER or job_type == Job.Type.BUILD_HEARTH:
		return work_build and profession_progress_xp() >= 200
	if job_type == Job.Type.TEACH_SKILL or job_type == Job.Type.APPRENTICESHIP:
		return work_build and profession_progress_xp() >= 150
	if job_type == Job.Type.GROW_FOOD:
		return work_forage and profession_progress_xp() >= 50
	if job_type == Job.Type.PROTECT or job_type == Job.Type.DEFEND:
		return work_hunt and profession_progress_xp() >= 100
	if job_type == Job.Type.GUARD:
		return work_guard
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
		"parental_trauma_weights": parental_trauma_weights.duplicate(true),
		"children_count": children_count,
		"current_profession": current_profession,
		"skills": skills.duplicate(true),
		"skill_xp": sx,
		"affinities": affinities.duplicate(true),
		"affinity_birth_snapshot": affinity_birth_snapshot.duplicate(true),
		"profession_liking": profession_liking.duplicate(true),
		"likes": likes.duplicate(true),
		"dislikes": dislikes.duplicate(true),
		"job_ticks_by_category": job_ticks_by_category.duplicate(true),
		"social_rapport_top": _social_rapport_top_for_export(24),
		"trait_types": trait_types,
		"military_rank": military_rank_legacy,  # Use legacy string for export compatibility
		"influence": influence,
		"soul_id": unique_id,
		"lineage_id": lineage_id,
		"biography_lines": biography.size(),
		"last_words": last_words,
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
		"equipped_gear": _serialize_equipped_gear(),
		"skill_xp": sx,
		"level": level,
		"skill_trees": skill_trees.duplicate(true),
		"skill_branches": skill_branches.duplicate(true),
		"mastery_perks": mastery_perks.duplicate(),
		"skills": skills.duplicate(true),
		"affinities": affinities.duplicate(true),
		"affinity_birth_snapshot": affinity_birth_snapshot.duplicate(true),
		"profession_liking": profession_liking.duplicate(true),
		"likes": likes.duplicate(true),
		"dislikes": dislikes.duplicate(true),
		"job_ticks_by_category": job_ticks_by_category.duplicate(true),
		"current_profession": current_profession,
		"birth_tick": birth_tick,
		"parent_a_id": parent_a_id,
		"parent_b_id": parent_b_id,
		"parental_trauma_weights": parental_trauma_weights.duplicate(true),
		"children_count": children_count,
		"bloodline_id": bloodline_id,
		"influence": influence,
		"military_rank": military_rank_legacy,  # Use legacy string for save compatibility
		"military_rank_int": military_rank,  # Stage 6 int-based rank
		"combat_xp": combat_xp,
		"enemies_killed": enemies_killed,
		"cohort_anchor_id": cohort_anchor_id,
		"cohort_job_type": cohort_job_type,
		"is_cohort_anchor": is_cohort_anchor,
		"work_forage": work_forage,
		"work_fish":   work_fish,
		"work_mine":   work_mine,
		"work_chop": work_chop,
		"work_hunt": work_hunt,
		"work_build": work_build,
		"work_guard": work_guard,
		"trait_types": trait_types,
		"social_rapport": social_rapport.duplicate(true),
		"character_opinions": character_opinions.duplicate(true),
		"neural_network": neural_network.to_dict() if neural_network != null and neural_network.has_method("to_dict") else {},
		"agent_bayes": agent_bayes_data,
		"unique_id": unique_id,
		"lineage_id": lineage_id,
		"biography": biography.duplicate(),
		"physical_scars": physical_scars.duplicate(),
		"settlement_reputation": settlement_reputation.duplicate(true),
		"social_squad_anchor_id": social_squad_anchor_id,
		"available_krond": available_krond,
		"total_krond_earned": total_krond_earned,
		"active_traits": active_traits_ser,
		"life_path": life_path,
		"life_path_progress": life_path_progress,
		"life_path_total": life_path_total,
		"life_path_contributions": life_path_contributions.duplicate(true),
		"regions_visited": regions_visited.duplicate(true),
	}


## Rebuild from `to_save_dict`. Overrides the auto id from _init and bumps
## `_next_id` so future spawns don't collide.
static func from_save_dict(d: Dictionary) -> HeelKawnianData:
	var p := HeelKawnianData.new()
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
	p._deserialize_equipped_gear(d)
	p.skill_xp = {}
	if d.has("skill_xp") and d["skill_xp"] is Dictionary:
		for k in d["skill_xp"]:
			p.skill_xp[int(k)] = float(d["skill_xp"][k])
	p.sync_level_from_total_skill_xp()
	var saved_level: int = int(d.get("level", p.level))
	p.level = maxi(p.level, saved_level)
	if d.has("skill_trees") and d["skill_trees"] is Dictionary:
		p.skill_trees = (d["skill_trees"] as Dictionary).duplicate(true)
	if d.has("skill_branches") and d["skill_branches"] is Dictionary:
		p.skill_branches = (d["skill_branches"] as Dictionary).duplicate(true)
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
	# Load likes/dislikes
	p.likes = {}
	if d.has("likes") and d["likes"] is Dictionary:
		for lk in d["likes"]:
			p.likes[str(lk)] = float(d["likes"][lk])
	p.dislikes = {}
	if d.has("dislikes") and d["dislikes"] is Dictionary:
		for dlk in d["dislikes"]:
			p.dislikes[str(dlk)] = float(d["dislikes"][dlk])
	# Load job tick tracking
	p.job_ticks_by_category = {}
	if d.has("job_ticks_by_category") and d["job_ticks_by_category"] is Dictionary:
		for jk in d["job_ticks_by_category"]:
			p.job_ticks_by_category[str(jk)] = int(d["job_ticks_by_category"][jk])
	else:
		# Initialize for old saves
		for cat in LIKE_CATEGORIES:
			p.job_ticks_by_category[cat] = 0
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
	p.parental_trauma_weights = {}
	if d.has("parental_trauma_weights") and d["parental_trauma_weights"] is Dictionary:
		p.parental_trauma_weights = (d["parental_trauma_weights"] as Dictionary).duplicate(true)
	p.children_count = int(d.get("children_count", 0))
	p.bloodline_id = int(d.get("bloodline_id", -1))
	p.influence = float(d.get("influence", 0.0))
	p.military_rank_legacy = str(d.get("military_rank_legacy", "grunt"))
	p.military_rank = int(d.get("military_rank_int", 0))
	p.combat_xp = int(d.get("combat_xp", 0))
	p.enemies_killed = int(d.get("enemies_killed", 0))
	p.cohort_anchor_id = int(d.get("cohort_anchor_id", -1))
	p.cohort_job_type = int(d.get("cohort_job_type", -1))
	p.is_cohort_anchor = bool(d.get("is_cohort_anchor", false))
	p.work_forage = bool(d.get("work_forage", true))
	p.work_fish   = bool(d.get("work_fish", true))
	p.work_mine   = bool(d.get("work_mine", true))
	p.work_chop = bool(d.get("work_chop", true))
	p.work_hunt = bool(d.get("work_hunt", true))
	p.work_build = bool(d.get("work_build", true))
	p.work_guard = bool(d.get("work_guard", true))
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
	p.last_words = str(d.get("last_words", ""))
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
		var restored_network: Variant = HeelKawnianData.create_neural_network({
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
	# Restore life-path fields (v1)
	p.life_path = int(d.get("life_path", 0))
	p.life_path_progress = int(d.get("life_path_progress", 0))
	p.life_path_total = int(d.get("life_path_total", 0))
	if d.has("life_path_contributions") and d["life_path_contributions"] is Dictionary:
		p.life_path_contributions = (d["life_path_contributions"] as Dictionary).duplicate(true)
	if d.has("regions_visited") and d["regions_visited"] is Dictionary:
		p.regions_visited = (d["regions_visited"] as Dictionary).duplicate(true)
	# Restore agent bayes data if present
	p.agent_bayes_data = d.get("agent_bayes", {}) if d.has("agent_bayes") else {}
	# End neural network / trait restore block; always return constructed HeelKawnianData
	return p



func is_carrying() -> bool:
	return carrying != 0 and carrying_qty > 0


func clear_carry() -> void:
	carrying = 0
	carrying_qty = 0


## Add an item to personal inventory. Returns true if added.
func inventory_add(item_type: int, quantity: int = 1) -> bool:
	# Try to stack with existing slot
	for slot in inventory:
		if int(slot.get("item_type", -1)) == item_type:
			slot["quantity"] = int(slot.get("quantity", 0)) + quantity
			return true
	# New slot
	if inventory.size() >= INVENTORY_SLOTS:
		return false  # No room
	inventory.append({"item_type": item_type, "quantity": quantity})
	return true


## Remove items from personal inventory. Returns quantity actually removed.
func inventory_remove(item_type: int, quantity: int = 1) -> int:
	var removed: int = 0
	var to_erase: Array = []
	for i in range(inventory.size()):
		var slot: Dictionary = inventory[i]
		if int(slot.get("item_type", -1)) == item_type:
			var have: int = int(slot.get("quantity", 0))
			var take: int = mini(quantity - removed, have)
			slot["quantity"] = have - take
			removed += take
			if int(slot.get("quantity", 0)) <= 0:
				to_erase.append(i)
			if removed >= quantity:
				break
	# Remove empty slots (reverse order)
	for i in range(to_erase.size() - 1, -1, -1):
		inventory.remove_at(to_erase[i])
	return removed


## Check if inventory has at least `quantity` of item_type.
func inventory_has(item_type: int, quantity: int = 1) -> bool:
	var total: int = 0
	for slot in inventory:
		if int(slot.get("item_type", -1)) == item_type:
			total += int(slot.get("quantity", 0))
	return total >= quantity


## Count total items in inventory.
func inventory_count(item_type: int) -> int:
	var total: int = 0
	for slot in inventory:
		if int(slot.get("item_type", -1)) == item_type:
			total += int(slot.get("quantity", 0))
	return total


## Is inventory full?
func inventory_full() -> bool:
	return inventory.size() >= INVENTORY_SLOTS


# --- Tool system ---

func equip_tool(tool_type: int) -> void:
	equipped_tool = tool_type
	equipped_tool_durability = Item.tool_durability(tool_type)


func use_tool() -> void:
	if equipped_tool_durability > 0:
		equipped_tool_durability -= 1
		if equipped_tool_durability <= 0:
			# Tool breaks
			WorldMemory.record_event({
				"type": "tool_break",
				"pawn_id": int(id),
				"tool": equipped_tool,
				"tool_name": Item.name_for(equipped_tool),
				"tick": GameManager.tick_count,
			})
			equipped_tool = Item.Type.NONE
			equipped_tool_durability = 0


func has_tool(tool_type: int) -> bool:
	return equipped_tool == tool_type and equipped_tool_durability > 0


func is_equipped_tool_valid() -> bool:
	return equipped_tool != Item.Type.NONE and equipped_tool_durability > 0


## Equip a GearItem into the appropriate slot. Returns the previously equipped item (or null).
func equip_gear(gear: Variant) -> Variant:
	if gear == null:
		return null
	var slot_key: int = int(gear.slot)
	var old: Variant = equipped_gear.get(slot_key, null)
	equipped_gear[slot_key] = gear
	# Also update legacy equipped_tool for backward compatibility
	if slot_key == 0 or slot_key == 2:  # WEAPON or TOOL
		equipped_tool = int(gear.base_type)
		equipped_tool_durability = int(gear.durability)
	return old


## Unequip a gear slot. Returns the removed item (or null).
func unequip_gear(slot_key: int) -> Variant:
	var old: Variant = equipped_gear.get(slot_key, null)
	equipped_gear[slot_key] = null
	# Clear legacy tool if we removed the tool/weapon slot
	if slot_key == 0 or slot_key == 2:  # WEAPON or TOOL
		if old != null:
			equipped_tool = 0  # Item.Type.NONE
			equipped_tool_durability = 0
	return old


## Get aggregated gear stats
func get_gear_stats() -> Dictionary:
	var total_attack: float = 1.0  # Bare fists
	var total_defense: float = 0.0
	var total_work_speed: float = 0.0
	var total_warmth: float = 0.0
	for slot_key in equipped_gear:
		var gear: Variant = equipped_gear[slot_key]
		if gear == null or not gear.has_method("is_broken") or gear.is_broken():
			continue
		total_attack += float(gear.attack)
		total_defense += float(gear.defense)
		total_work_speed += float(gear.work_speed)
		total_warmth += float(gear.warmth)
	return {
		"attack": total_attack,
		"defense": total_defense,
		"work_speed": total_work_speed,
		"warmth": total_warmth,
	}


## Get the weapon GearItem (or null)
func get_weapon() -> Variant:
	return equipped_gear.get(0, null)  # Slot.WEAPON


## Get the armor GearItem (or null)
func get_armor() -> Variant:
	return equipped_gear.get(1, null)  # Slot.ARMOR


func _serialize_equipped_gear() -> Dictionary:
	var out: Dictionary = {}
	for slot_key in equipped_gear:
		var gear: Variant = equipped_gear[slot_key]
		if gear != null and gear.has_method("to_dict"):
			out[str(slot_key)] = gear.to_dict()
	return out


func _deserialize_equipped_gear(d: Dictionary) -> void:
	equipped_gear = {
		0: null,  # WEAPON
		1: null,  # ARMOR
		2: null,  # TOOL
		3: null,  # ACCESSORY
		4: null,  # OFFHAND
	}
	if not d.has("equipped_gear") or not (d["equipped_gear"] is Dictionary):
		return
	var eg: Dictionary = d["equipped_gear"] as Dictionary
	var _GearItem = load("res://scripts/items/GearItem.gd")
	for slot_key_str in eg:
		var slot_key: int = int(slot_key_str)
		var gear_dict: Variant = eg[slot_key_str]
		if gear_dict is Dictionary and _GearItem != null:
			equipped_gear[slot_key] = _GearItem.from_dict(gear_dict as Dictionary)


func get_tool_efficacy(job_type: int) -> float:
	if not is_equipped_tool_valid():
		return 1.0  # bare-handed baseline
	return Item.tool_efficacy(equipped_tool, job_type)


# === Life Arc Composer ===

## Compose a short life arc string for this pawn.
## Returns a human-readable narrative of major life events.
func compose_life_arc() -> String:
	var tick: int = GameManager.tick_count if GameManager != null else 0
	var age_ticks: int = maxi(tick - birth_tick, 0)
	var lines: Array = []

	# Opening: name, age, profession
	var prof_str: String = profession_name()
	lines.append("%s, %s" % [display_name, prof_str])
	lines.append("  Born tick %d, age %d ticks" % [birth_tick, age_ticks])

	# Diaspora origin
	if _diaspora_origin >= 0:
		lines.append("  Exiled from settlement %d at tick %d" % [_diaspora_origin, _diaspora_tick])

	# Profession history
	if current_profession != Profession.NONE:
		lines.append("  Profession: %s" % prof_str)

	# Key episodic memories (top 5 by emotional impact)
	var key_memories: Array = recall_episodic_memories("", 0.3, 5)
	if not key_memories.is_empty():
		lines.append("  Key memories:")
		for mem in key_memories:
			if not (mem is Dictionary):
				continue
			var mem_d: Dictionary = mem as Dictionary
			var mem_type: String = str(mem_d.get("type", "?")).replace("_", " ")
			var mem_tick: int = int(mem_d.get("tick", 0))
			var impact: float = float(mem_d.get("emotional_impact", 0.0))
			var impact_label: String = "strong" if impact > 0.7 else "notable" if impact > 0.4 else "mild"
			lines.append("    [t%d] %s (%s)" % [mem_tick, mem_type, impact_label])

	# Mood
	lines.append("  Mood: %.0f" % mood)

	return "\n".join(lines)


## Return visual indicators for rendering on the pawn sprite.
## Each indicator is a dict with: type ("dot"/"ring"/"line"), color, offset, size.
func get_visual_indicators() -> Array:
	var result: Array = []

	# --- Wound indicators (red dots) ---
	if BodyPartWounds != null and BodyPartWounds.has_method("get_wound_summary"):
		var wounds: Dictionary = BodyPartWounds.get_wound_summary(self)
		if not wounds.is_empty():
			var wound_count: int = 0
			for body_part in wounds:
				var severity: float = float(wounds[body_part])
				if severity > 0.0:
					# Red dot at different positions for different body parts
					var part_name: String = str(body_part).to_lower()
					var offset: Vector2 = Vector2(-3, -4)  # default: left shoulder
					if part_name.find("leg") >= 0:
						offset = Vector2(-3, 2)  # left leg
					elif part_name.find("arm") >= 0:
						offset = Vector2(3, -2)  # right arm
					elif part_name.find("head") >= 0:
						offset = Vector2(0, -6)  # head
					elif part_name.find("torso") >= 0:
						offset = Vector2(0, -1)  # torso
					var dot_size: float = clampf(severity * 1.5, 0.5, 2.0)
					result.append({"type": "dot", "color": Color8(220, 40, 30), "offset": offset, "size": dot_size})
					wound_count += 1
					if wound_count >= 4:
						break  # Max 4 wound indicators

	# --- Age indicators ---
	if life_stage == LifeStage.ELDER or life_stage == LifeStage.ANCIENT:
		# Gray hair: white ring above head
		result.append({"type": "ring", "color": Color8(200, 200, 210, 180), "offset": Vector2(0, -7), "size": 1.5})
	elif life_stage == LifeStage.CHILD or life_stage == LifeStage.INFANT:
		# Small size indicator: yellow ring above head
		result.append({"type": "ring", "color": Color8(255, 220, 100, 150), "offset": Vector2(0, -5), "size": 1.0})

	# --- Grief/trauma token (dark circle below) ---
	if PawnConsciousness != null and PawnConsciousness.has_method("get_trauma_level"):
		var trauma: float = PawnConsciousness.get_trauma_level(int(id))
		if trauma > 25.0:
			var alpha: float = clampf(trauma / 100.0, 0.3, 1.0)
			result.append({"type": "dot", "color": Color8(60, 40, 60, int(alpha * 200)), "offset": Vector2(2, 3), "size": 1.0})

	# --- Profession indicator (small colored dot) ---
	var prof: int = current_profession
	if prof == Profession.BUILDER:
		result.append({"type": "dot", "color": Color8(160, 120, 60), "offset": Vector2(3, -4), "size": 0.8})
	elif prof == Profession.WARRIOR:
		result.append({"type": "dot", "color": Color8(200, 80, 40), "offset": Vector2(3, -4), "size": 0.8})
	elif prof == Profession.GATHERER:
		result.append({"type": "dot", "color": Color8(140, 140, 150), "offset": Vector2(3, -4), "size": 0.8})
	elif prof == Profession.FARMER:
		result.append({"type": "dot", "color": Color8(80, 160, 60), "offset": Vector2(3, -4), "size": 0.8})
	elif prof == Profession.TRADER:
		result.append({"type": "dot", "color": Color8(60, 120, 180), "offset": Vector2(3, -4), "size": 0.8})
	elif prof == Profession.HEALER:
		result.append({"type": "dot", "color": Color8(60, 200, 80), "offset": Vector2(3, -4), "size": 0.8})
	elif prof == Profession.GATHERER:
		result.append({"type": "dot", "color": Color8(180, 160, 60), "offset": Vector2(3, -4), "size": 0.8})
	elif prof == Profession.WARRIOR:
		result.append({"type": "dot", "color": Color8(180, 40, 40), "offset": Vector2(3, -4), "size": 0.8})
	elif prof == Profession.SCHOLAR:
		result.append({"type": "dot", "color": Color8(100, 80, 180), "offset": Vector2(3, -4), "size": 0.8})
	elif prof == Profession.TRADER:
		result.append({"type": "dot", "color": Color8(200, 180, 60), "offset": Vector2(3, -4), "size": 0.8})
	elif prof == Profession.SMITH:
		result.append({"type": "dot", "color": Color8(160, 100, 50), "offset": Vector2(3, -4), "size": 0.8})

	return result

