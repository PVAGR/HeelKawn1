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
var military_rank: String = "grunt"
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

## Deterministic co-presence bond: other pawn id (string key) -> rapport 0..3000.
## Grows when NPCs spend time near each other (same path component); feeds
## reproduction and future player social actions (gift, commend, etc.).
var social_rapport: Dictionary = {}


func _init() -> void:
	id = _next_id
	_next_id += 1
	birth_tick = int(GameManager.tick_count) if "tick_count" in GameManager else 0
	initialize_affinities(birth_tick, -1, -1)


func get_max_health() -> float:
	return max_health


func get_health_percentage() -> float:
	if max_health <= 0.0:
		return 0.0
	return clamp(health / max_health, 0.0, 1.0)


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
	skill_xp[skill] = get_skill_xp(skill) + amount * trait_mult
	
	# Stage 1: Track last used time for XP decay
	skill_last_used[skill] = GameManager.tick_count if "tick_count" in GameManager else 0
	
	# Stage 1: Check for overall level up
	_check_level_up()
	
	# Stage 1: Check for mastery perk unlocks
	_check_mastery_perks(skill)
	
	return get_skill_level(skill) != before


## Stage 1: Calculate overall level from total XP across all skills
func _check_level_up() -> void:
	var total_xp: float = 0.0
	for skill in skill_xp:
		total_xp += skill_xp[skill]
	var new_level: int = int(total_xp / XP_PER_LEVEL) + 1
	if new_level > level:
		level = new_level
		# Stage 1: Unlock skill branches at certain levels
		_unlock_skill_branches(level)


## Stage 1: Unlock skill branches at certain levels
func _unlock_skill_branches(new_level: int) -> void:
	# Level 5: Unlock basic specialization
	if new_level == 5:
		# TODO: Add basic skill branch unlocks
		pass
	# Level 10: Unlock intermediate specialization
	elif new_level == 10:
		# TODO: Add intermediate skill branch unlocks
		pass
	# Level 15: Unlock advanced specialization
	elif new_level == 15:
		# TODO: Add advanced skill branch unlocks
		pass
	# Level 20: Unlock mastery
	elif new_level == 20:
		# TODO: Add mastery skill branch unlocks
		pass


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
	var current_tick: int = GameManager.tick_count if "tick_count" in GameManager else 0
	var decay_threshold: int = GameManager.TICKS_PER_DAY * 7  # 7 days without use
	
	for skill in skill_xp:
		var last_used: int = skill_last_used.get(skill, 0)
		if current_tick - last_used > decay_threshold:
			# Decay XP slowly
			var decay_amount: float = 1.0
			skill_xp[skill] = max(0.0, skill_xp[skill] - decay_amount)
			# Update last used to prevent rapid decay
			skill_last_used[skill] = current_tick


## Speed multiplier to apply to per-tick work progress for `skill`. Linearly
## interpolates from 1.0 at level 0 to SKILL_BONUS_AT_MAX at SKILL_LEVEL_MAX,
## then plateaus.
func work_speed_for(skill: int) -> float:
	var lvl: int = mini(get_skill_level(skill), SKILL_LEVEL_MAX)
	if lvl <= 0:
		return 1.0
	var t: float = float(lvl) / float(SKILL_LEVEL_MAX)
	return 1.0 + t * (SKILL_BONUS_AT_MAX - 1.0)


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
	var seed: int = int(
		(birth_tick * 1103515245 + (parent_a_id + 31) * 12345 + (parent_b_id + 17) * 2654435761 + id * 97 + salt) & 0x7FFFFFFF
	)
	var modv: int = seed % 1000
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
	return base_mult * trait_mult


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
		"military_rank": military_rank,
		"influence": influence,
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
		"military_rank": military_rank,
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
	p.birth_tick = int(d.get("birth_tick", 0))
	p.parent_a_id = int(d.get("parent_a_id", -1))
	p.parent_b_id = int(d.get("parent_b_id", -1))
	p.children_count = int(d.get("children_count", 0))
	p.influence = float(d.get("influence", 0.0))
	p.military_rank = str(d.get("military_rank", "grunt"))
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
	# Load traits
	if d.has("trait_types") and d["trait_types"] is Array:
		for trait_type in d["trait_types"]:
			p.traits.append(Trait.new(int(trait_type)))
	_next_id = maxi(_next_id, p.id + 1)
	return p


func is_carrying() -> bool:
	return carrying != 0 and carrying_qty > 0


func clear_carry() -> void:
	carrying = 0
	carrying_qty = 0
