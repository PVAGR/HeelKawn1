
class_name HeelKawnian
extends Node2D

## A pawn: data container, tick-driven needs, AI state machine, and
## waypoint-following movement. Ticks happen on GameManager.game_tick;
## movement interpolates in _process for smoothness.
##
## State machine (v1):
##
##   IDLE --(hungry + food available)--> GOING_TO_EAT --arrive--> EATING --done--> IDLE
##   IDLE --(job claimed)--> WALKING_TO_JOB --arrive--> WORKING --done--> HAULING
##        --arrive stockpile--> IDLE  (item deposited)
##   IDLE --(nothing else)--> (wander step) --> IDLE

# -------------------- visual tuning --------------------

## Radius of the pawn circle in world units. Kept <= TILE_PIXELS (8) so a
## pawn doesn't visually spill into neighboring tiles as it walks.
const DRAW_RADIUS: float = 3.5
## Tiny deterministic pixel figure (skin / hair / apparel from `HeelKawnianData`) â€” reads as a "sprite"
## before bespoke art ships; NPCs and player use the same path.
const PROCEDURAL_PIXEL_PAWN: bool = true
const OUTLINE_WIDTH: float = 1.0
const OUTLINE_WIDTH_BUSY: float = 1.75
const HEALTH_BAR_W: float = 8.0
const HEALTH_BAR_H: float = 1.2
const HEALTH_BAR_Y: float = 7.0
const MOOD_DOT_Y: float = -9.5
const DRAFT_CHEVRON_Y: float = -12.0

## Offset and size of the "carrying" swatch drawn above the pawn's head.
const CARRY_OFFSET: Vector2 = Vector2(0.0, -6.0)
const CARRY_SIZE: Vector2 = Vector2(3.5, 3.5)
const _WM = preload("res://autoloads/WorldMemory.gd")
const _Job = preload("res://scripts/jobs/Job.gd")
const _Item = preload("res://scripts/items/Item.gd")
@onready var SpatialManager = get_node_or_null("/root/SpatialManager") # ARCHITECT T006

# PERFORMANCE: Tick rate decoupling for AI systems
@onready var _tick_rate_decoupler: Node = get_node_or_null("/root/TickRateDecoupler")
@onready var _spatial_grid: Node = get_node_or_null("/root/SpatialGrid")

# -------------------- PERFORMANCE OPTIMIZATION: Frame skipping --------------------
## Only update visuals every N frames based on game speed.
## At 1x: update every 3rd frame. At 26x: every 8th frame. At 100x: every 15th frame.
## This dramatically reduces draw calls while maintaining visual smoothness.
const MIN_VISUAL_UPDATE_INTERVAL: int = 3

# -------------------- need decay tuning --------------------

# Survival drain rates. Tuned so a 5-pawn colony with realistic forage travel
# distances (often ~30-70 tiles to a fertile soil patch) can run a sustained
# food/rest surplus instead of slowly starving. If the colony grows or food
# moves further away these will need re-tuning.
const HUNGER_DECAY_PER_TICK: float = 0.03  # Reduced from 0.06 to prevent rapid starvation
const REST_DECAY_PER_TICK:   float = 0.04  # Reduced from 0.05
const MOOD_DECAY_PER_TICK:   float = 0.02  # Reduced from 0.03
const THRESHOLD_WARN: float = 50.0
const THRESHOLD_CRIT: float = 25.0

# -------------------- mood recovery --------------------

## Mood gained per tick when both hunger and rest are above MOOD_CONTENT_FLOOR
## ("nothing's wrong, life is fine"). Tuned to outpace the 0.03 decay so a
## pawn whose needs are met slowly trends back toward 100.
const MOOD_GAIN_PER_TICK_CONTENT: float = 0.08
const MOOD_CONTENT_FLOOR: float = 60.0
## One-shot mood gain when finishing a meal (eating from stockpile or hand).
const MOOD_BONUS_ATE: float = 4.0
## One-shot mood gain when waking up fully rested.
const MOOD_BONUS_WOKE_REFRESHED: float = 8.0

## Pawns go eat when hunger drops below this (and a stockpile has food).
## Tuned so HeelKawnians work through most of their hunger bar before eating,
## preventing the entire colony from abandoning work simultaneously.
const HUNGER_EAT_THRESHOLD: float = 30.0
## Below this, a pawn will eat food directly from its own hands rather than
## insist on hauling it to the stockpile first. Saves starving pawns who got
## stranded mid-haul (unreachable stockpile, no path, etc).
const HUNGER_EMERGENCY: float = 20.0
## Ticks spent "eating" once at the stockpile. 5 ticks = ~0.5s at 1x speed.
const EAT_TICKS: int = 5

# -------------------- sleep tuning --------------------

## Below this, an idle pawn will lie down to sleep wherever they stand
## (preferring a bed if one is reachable). At night the threshold is much
## higher so pawns settle into a natural diurnal schedule instead of working
## around the clock until exhausted.
const REST_SLEEP_THRESHOLD: float = 25.0
const REST_SLEEP_THRESHOLD_NIGHT: float = 55.0
## Below this, the pawn is so exhausted they abandon whatever they were doing
## (job, eating, hauling) and collapse. Without this, busy pawns happily ride
## rest down to 0 because they never reach the IDLE priority chain.
const REST_PANIC_THRESHOLD: float = 12.0

# -------------------- food-supply tuning --------------------

## Hard floor: at or below this, forage/hunt-only pass always runs (true starvation guard).
const STOCKPILE_FOOD_CRITICAL_UNITS: int = 3
## Colony food pressure at/above this triggers the forage-only pass together with critical units.
const COLONY_FOOD_PRESSURE_FOR_EMERGENCY: float = 0.56
## Added inside JobManager priority_cb only â€” not an exclusive job filter (see _tick_idle).
const AFFINITY_JOB_PRIORITY_BONUS: int = 2
const UTILITY_JOB_PRIORITY_BIAS_RANGE: int = 6
const UTILITY_SCORE_NORMALIZER: float = 6.0
const UTILITY_WANDER_THRESHOLD: float = 0.42
## Sleep ends and the pawn wakes once rest climbs above this.
const REST_WAKE_THRESHOLD: float = 70.0
## Rest restored per tick while in SLEEPING state. ~7x the normal decay rate
## so a full sleep takes ~120 ticks (12 in-game hours) to go from crit to wake.
const REST_RECOVER_PER_TICK_SLEEP: float = 0.6
## Multiplier applied to REST_RECOVER_PER_TICK_SLEEP when the sleeping pawn is
## standing on a bed they own. Beds make sleep ~67% faster.
const REST_RECOVER_BED_MULTIPLIER: float = 1.67
## Health recovered per tick while sleeping. Slow but steady â€” a pawn with 50
## health recovers in ~100 ticks of sleep (~1 sleep cycle). In a bed the rate
## is doubled, so the same pawn heals in ~50 ticks.
const HEALTH_RECOVER_PER_TICK_SLEEP: float = 0.5
const HEALTH_RECOVER_BED_MULTIPLIER: float = 2.0
## Hunger keeps decaying while asleep, but at half rate (rest body burns less).
const HUNGER_DECAY_PER_TICK_SLEEPING: float = 0.025  # Reduced from 0.05

# -------------------- build tuning --------------------

## How much wood each buildable consumes. Carried in the pawn's hands during
## the walk from stockpile to build site.
const BED_WOOD_COST: int = 1
const WALL_WOOD_COST: int = 2
const DOOR_WOOD_COST: int = 1


## Map of build-job type -> (item_type, qty) needed at the build site. Anything
## listed here triggers the FETCHING_MATERIAL bounce in _begin_job.
static func _materials_for_build(job_type: int) -> Dictionary:
	match job_type:
		_Job.Type.BUILD_BED:  return {"item": _Item.Type.WOOD, "qty": BED_WOOD_COST}
		_Job.Type.BUILD_WALL: return {"item": _Item.Type.WOOD, "qty": WALL_WOOD_COST}
		_Job.Type.BUILD_DOOR: return {"item": _Item.Type.WOOD, "qty": DOOR_WOOD_COST}
		_Job.Type.BUILD_FIRE_PIT:     return {"item": _Item.Type.WOOD, "qty": 2}  # wood + stone (stone tracked separately)
		_Job.Type.BUILD_STORAGE_HUT:  return {"item": _Item.Type.WOOD, "qty": 3}
		_Job.Type.BUILD_MARKER_STONE: return {"item": _Item.Type.STONE, "qty": 2}
		_Job.Type.BUILD_SHRINE:       return {"item": _Item.Type.WOOD, "qty": 2}  # + stone tracked separately
		_Job.Type.BUILD_SHELTER:      return {"item": _Item.Type.WOOD, "qty": BED_WOOD_COST}
		_Job.Type.BUILD_HEARTH:       return {"item": _Item.Type.WOOD, "qty": 2}
		_Job.Type.COOK_MEAT:          return {"item": _Item.Type.MEAT, "qty": 1}
		_Job.Type.COOK_BERRIES:       return {"item": _Item.Type.BERRY, "qty": 2}
		_Job.Type.DRY_MEAT:           return {"item": _Item.Type.MEAT, "qty": 2}
	# Phase 6: new buildings use BuildingRegistry for cost lookup.
	# Return the first (primary) material from the cost dict.
	if BuildingRegistry != null:
		var building: Dictionary = BuildingRegistry.get_building_by_job_type(job_type)
		if not building.is_empty():
			var cost: Dictionary = building.get("cost", {})
			if not cost.is_empty():
				# Map string cost keys to Item.Type
				var item_map: Dictionary = {
					"wood": _Item.Type.WOOD, "stone": _Item.Type.STONE,
					"seeds": _Item.Type.SEEDS, "stick": _Item.Type.STICK,
					"flint": _Item.Type.FLINT, "herbs": _Item.Type.BERRY,
					"paper": _Item.Type.PAPER, "leather": _Item.Type.LEATHER,
					"ink": _Item.Type.INK, "meat": _Item.Type.MEAT,
				}
				for cost_key in cost:
					if item_map.has(cost_key):
						return {"item": int(item_map[cost_key]), "qty": int(cost[cost_key])}
	return {}


func _pawn_stream(label: String) -> StringName:
	var pawn_id: int = int(data.id) if data != null else 0
	return StringName("pawn:%d:%s" % [pawn_id, label])


func _pawn_salt(extra: int = 0) -> int:
	var pawn_id: int = int(data.id) if data != null else 0
	var tile: Vector2i = data.tile_pos if data != null else Vector2i.ZERO
	return GameManager.tick_count + pawn_id * 1009 + tile.x * 131 + tile.y * 17 + extra


## Stable 0..1 facets per pawn (world_seed + id). Makes metabolism, rest habits,
## wanderlust, and job tastes diverge so the colony does not move as one machine.
var _behavior_profile: PackedFloat32Array = PackedFloat32Array()
var _behavior_profile_ready: bool = false

## 1.0 at world start, 0.0 after this many ticks: looser idle, more wander, slower job claims.
const FOUNDING_PERIOD_TICKS: int = 4500


func _founding_blend() -> float:
	if GameManager == null:
		return 0.0
	return clampf(1.0 - float(GameManager.tick_count) / float(FOUNDING_PERIOD_TICKS), 0.0, 1.0)


func _reset_behavior_profile() -> void:
	_behavior_profile.clear()
	_behavior_profile_ready = false


func _bp(i: int) -> float:
	if data == null:
		return 0.5
	if not _behavior_profile_ready:
		_behavior_profile.resize(8)
		var pid: int = int(data.id)
		for k in range(8):
			_behavior_profile[k] = WorldRNG.range_for(StringName("pawn_behavior_v1:%d" % pid), 0.0, 1.0, k)
		_behavior_profile_ready = true
	return float(_behavior_profile[clampi(i, 0, 7)])


# -------------------- movement tuning --------------------

# 1 tile = 8 world units, so 24 = 3 tiles/sec at 1x = 18 tiles/sec at 6x.
# Snappier movement makes long forage runs viable without sucking the
# colony's whole tick budget into walk-time.
const WALK_SPEED_WORLD_UNITS_PER_SEC: float = 24.0
## Chance per tick to start a random wander when idle and nothing to do.
const WANDER_CHANCE_PER_TICK: float = 0.08

## Print "retrying haul (no path)" at most once every N ticks per pawn. Keeps
## the log readable while still making stuck hauls obvious.
const HAUL_FAIL_LOG_EVERY_N_TICKS: int = 300
## If a haul target is unreachable/missing, wait a few ticks before trying again.
const HAUL_RETRY_COOLDOWN_TICKS: int = 10
## At high sim speeds, skip historical aversion weighting path pass to avoid
## expensive weight toggles on every pawn path request.
const FAST_PATHFIND_SPEED_THRESHOLD: float = 6.0
const REPRODUCTION_COOLDOWN_TICKS: int = 5000
## ~11.5 tiles at 10px/tile â€” cohabiting workers can still pair without pixel-perfect overlap.
const REPRODUCTION_MATE_RANGE_PX: float = 115.0
## When there are no bed tiles on the map, widen pairing distance so abandoned/collapse
## play can still repopulate (same path component + rapport gates still apply).
const REPRODUCTION_MATE_RANGE_NO_BEDS_MIN_TILES: float = 22.0
## Softer than general job hunger gates so pairs can raise children under colony stress.
const REPRODUCTION_MIN_HUNGER: float = 48.0
const REPRODUCTION_MIN_REST: float = 42.0
## Requires [member HeelKawnianData.social_rapport] built from co-presence (Main._accumulate_social_rapport).
const REPRODUCTION_MIN_RAPPORT: int = 72
const COHORT_UPDATE_TICKS: int = 200
const COHORT_MATCH_RADIUS_TILES: int = 8
const COHORT_BREAK_DISTANCE_TILES: int = 16
const COHORT_MIN_SIZE: int = 2
const COHORT_COHESION_BIAS_WEIGHT: float = 0.12

## Meaning-based behavior modifiers (Phase 4: Player-readable meaning refinement)
## These are base values; actual multipliers come from MeaningAmbianceController
const MEANING_SPEED_QUIET: float = 1.0
const MEANING_SPEED_SCARRED: float = 0.9
const MEANING_SPEED_BLOODIED: float = 0.75
const MEANING_SPEED_GRAVE: float = 0.6
const COHORT_COHESION_MAX_STEP: float = 0.35
const COHORT_RECRUITMENT_SCAN_RADIUS_TILES: int = 10
const COHORT_RECRUITMENT_MAX_PAWNS: int = 24
const COHORT_RECRUITMENT_MAX_SIGNALS: int = 8
const COHORT_RECRUITMENT_CACHE_UPDATE_TICKS: int = 60
const COHORT_RECRUITMENT_BIAS_MAX: float = 1.12
const COHORT_STABILITY_WINDOW_TICKS: int = 400
const COHORT_LOCUS_PERSIST_RADIUS_TILES: int = 12
const COHORT_LOCUS_PERSIST_BIAS_WEIGHT: float = 0.08
const COHORT_LOCUS_PERSIST_MAX_STEP: float = 0.22
const RESOURCE_PRESSURE_BIAS_MAX: float = 1.12
## Social mentoring can happen often; WorldMemory facts stay sparse and auditable.
const TEACHING_MEMORY_EVENT_MIN_INTERVAL_TICKS: int = 300

# -------------------- AI state --------------------

enum State {
	IDLE,
	WALKING_TO_JOB,
	WORKING,
	HAULING,            # carrying a produced item toward the stockpile
	GOING_TO_EAT,       # hungry, walking toward stockpile
	EATING,             # at stockpile, consuming a food item
	SLEEPING,           # restoring rest in place; wakes on full rest or starvation
	FETCHING_MATERIAL,  # build job claimed; walking to stockpile to grab inputs
	GOING_TO_BED,       # tired, walking toward a reserved bed
	TEACHING,           # teaching knowledge to nearby pawn
	CHALLENGE,          # challenging another pawn's authority
	## Player-ordered move (Kenshi / RimWorld "draft" step); not a work job.
	DRAFT_WALK,
	## Stage 1: Small direct actions
	GATHERING,          # picking up items from ground
	CRAFTING,           # creating simple tools from materials
	FLEEING,            # running from danger
	HIDING,             # taking cover from threats
	PILGRIMAGE,         # visiting memorial site (reverence, closure)
}

# -------------------- runtime --------------------

var data: HeelKawnianData
@onready var _sprite: Sprite2D = Sprite2D.new() # SPRITE_ART

var _world: World
var _brain_instance: HeelKawnPawnBrain = null
var _state: int = State.IDLE
var _current_job: Job = null
var _cohort_id: int = -1
var _sacred_geography_cache: Node = null
var _cohort_role: int = -1
var _carrying_spawn_item: bool = false
var draft_mode: bool = false
var is_selected: bool = false
## Active path: list of tiles AFTER the current tile that must be visited in
## order. Empty means stationary.
var _path: Array[Vector2i] = []
var _path_index: int = 0
var _facing_dir: Vector2 = Vector2(0.0, 1.0)  # Last movement direction for sprite rendering
var _target_tile: Vector2i = Vector2i.ZERO
var _target_world_pos: Vector2 = Vector2.ZERO

## Ticks remaining in the EATING state.
var _eat_ticks_left: int = 0

## Teaching state variables
var _teaching_target: HeelKawnian = null
var _teaching_ticks_left: int = 0
var _teaching_knowledge_type: int = -1
var _last_teach_tick: int = 0
var _teach_cooldown_ticks: int = 0  # Will be set in _ready()
## Student progress tracking: pawn_id -> {skill: level, ticks_taught: int}
var _students_taught: Dictionary = {}

## Challenge state variables
var _challenge_target: HeelKawnian = null
var _challenge_ticks_left: int = 0
var _challenge_context: int = -1

## Bed currently reserved by this pawn (Vector2i(-1,-1) = none). Set when we
## start walking to a bed, cleared on wake or panic-abort. World holds the
## authoritative occupancy map; this is just a back-pointer so we know which
## bed to release.
var _reserved_bed: Vector2i = Vector2i(-1, -1)

## The specific zone we're pathing to for the current eat/haul/fetch. Phase
## 10 made stockpiles multi-zone, so "walk to the stockpile" is no longer a
## constant -- we pick a target when we start walking and remember it so the
## arrival handler deposits into / takes from the *same* zone we planned for,
## even if a closer zone got designated mid-walk.
var _target_zone: Stockpile = null

## Last severity level reported per need, to avoid log spam.
var _hunger_level: int = 0
## Snapshot of [CulturalMemory] at bind / resync: inherited place reputation; not updated on tick.
var initial_region_reputation: int = 0
## Failsafe log once: pawn standing on a tile A* now marks as solid.
var _reported_stuck: bool = false
var _woke_tick: int = -9999  # tick when pawn last woke; prevents sleep oscillation
var _next_reproduction_tick: int = 0
var _active_edict: String = ""
var _rest_level: int = 0
var _mood_level: int = 0

## Game tick at which we last logged a haul failure for this pawn, so the
## retry loop doesn't flood the console.
var _last_haul_fail_log_tick: int = -HAUL_FAIL_LOG_EVERY_N_TICKS
var _next_haul_retry_tick: int = 0
var _next_cohort_update_tick: int = 0
var _cohort_anchor_ref: WeakRef = null
var _next_recruitment_cache_tick: int = 0
var _next_matrix_ambition_tick: int = 0
var _last_recruitment_job_type: int = -2
var _recruitment_signal_cache: Array[Dictionary] = []
var _cohort_stability_ticks: int = 0
var _cohort_locus_tile: Vector2i = Vector2i(-1, -1)
var _cohort_stability_job_type: int = -1
## Per-tick cache for global food queries â€” avoids every pawn calling StockpileManager.total_food()
static var _s_food_units: int = 0
static var _s_food_pressure: float = 0.0
static var _s_food_emergency: bool = false
static var _s_food_cache_tick: int = -1
static var _s_discovered_regions: Dictionary = {}  # region_key -> true (rate-limit discovery events)
## Per-tick cache for idle utility context â€” avoids rebuilding dict every idle tick
var _cached_utility_context: Dictionary = {}
var _cached_utility_context_tick: int = -1
var _cached_utility_food_emergency: bool = false
var _anim_t: float = 0.0
var _draw_frame_counter: int = 0
var _visual_frame_counter: int = 0  # PERFORMANCE: Adaptive visual update throttling
var _last_sacred_check_tile: Vector2i = Vector2i(-9999, -9999)  # PERFORMANCE: SacredGeography tile cache
var _cached_path: Array[Vector2i] = []  # PERFORMANCE: Pathfinding cache
var _cached_path_target: Vector2i = Vector2i(-9999, -9999)  # PERFORMANCE: Path target cache
var _cached_path_tick: int = -1  # PERFORMANCE: Path cache timestamp
const PATH_CACHE_DURATION: int = 20  # PERFORMANCE: Ticks to cache path
## Cached enemy list â€” refreshed every 30 ticks to avoid per-pawn scene tree scans.
static var _cached_enemies: Array = []
static var _cached_enemies_tick: int = -100
## Cached job-type â†’ upper-name lookup. Built once, avoids str()+to_upper()
## per pawn per job tick.
static var _job_type_name_cache: Dictionary = {}
static var _job_type_name_cache_built: bool = false
var _sfx: AudioStreamPlayer2D = null
var _action_popup: ActionPopupLabel = null
var _footstep_particles: GPUParticles2D = null
var _hit_flash_ticks: int = 0
## `JobManager.claim_next_for` invokes priority_cb once per open job; neural forward
## propagation must not run hundreds of times in one claim scan (was freezing / hard-stopping).
var _neural_priority_fetch_tick: int = -1
var _neural_priority_outputs: Array = []
var _neural_priority_next_refresh_tick: int = -1
## HeelKawnian Matrix AI profile cache: identity/memory/development job bias.
## Kept per tick so a job scan can read "soul intent" without recomputing it
## for every open job.
var _matrix_priority_fetch_tick: int = -1
var _matrix_priority_decision: Dictionary = {}
## Prevent per-job scan event spam from turning priority evaluation into a hitch source.
var _last_neural_decision_log_tick: int = -1000000
var _last_inspect_msg: String = ""
var _last_inspect_tick: int = -999999
var _last_teaching_memory_event_tick: int = -TEACHING_MEMORY_EVENT_MIN_INTERVAL_TICKS
var _last_body_needs_tick_applied: int = -1
## Autonomy-driven draft walks (social / grudge); not player draft.
var _autonomy_draft_purpose: String = ""
var _autonomy_draft_peer_id: int = -1
var _last_autonomy_feedback: String = ""
var _next_autonomy_grudge_tick: int = 0
var _next_autonomy_social_seek_tick: int = 0
## One [WorldAI.build_idle_parity_context_for_pawn] snapshot per pawn per tick (NPC / player parity).
var _parity_context_tick: int = -1
var _parity_context: Dictionary = {}
var _initial_knowledge_granted: bool = false
var _perception_scan_cursor: int = 0
var _cached_idle_action: String = "work"
var _cached_idle_action_food_emergency: bool = false
var _next_idle_action_refresh_tick: int = -1
## Set true only after [method _pawn_connect_sim_tick_deferred] connects [signal GameManager.game_tick].
## Prevents sim ticks from running before [method bind] + [method _ready] have finished.
var _pawn_sim_tick_armed: bool = false

## Autoloads (e.g. JobManager) should call these instead of `pawn.data` â€” the
## parser can fail to resolve the `data` member on class_name HeelKawnian in autoload scripts.
func get_pawn_data() -> HeelKawnianData:
	return data


func apply_body_needs() -> void:
	if data == null:
		return
	var tick_now: int = GameManager.tick_count if GameManager != null else -1
	if tick_now >= 0 and _last_body_needs_tick_applied == tick_now:
		_publish_player_body_needs_to_hud_if_incarnated()
		return
	_last_body_needs_tick_applied = tick_now
	_decay_needs()
	_publish_player_body_needs_to_hud_if_incarnated()


func get_state_name() -> String:
	match _state:
		State.IDLE:
			return "Idle"
		State.WALKING_TO_JOB:
			return "WalkingToJob"
		State.WORKING:
			return "Working"
		State.HAULING:
			return "Hauling"
		State.GOING_TO_EAT:
			return "GoingToEat"
		State.EATING:
			return "Eating"
		State.GOING_TO_BED:
			return "GoingToBed"
		State.SLEEPING:
			return "Sleeping"
		State.FETCHING_MATERIAL:
			return "FetchingMaterial"
		State.DRAFT_WALK:
			return "DraftWalk"
		_:
			return "Unknown"


func get_current_job_label() -> String:
	if _current_job == null:
		return "None"
	return Job.describe_type(_current_job.type)


## Soul & Society: eligible to join/form an idle social squad (no work job, not drafted).
func is_eligible_for_social_squad() -> bool:
	if data == null or draft_mode:
		return false
	if _current_job != null:
		return false
	if _state == State.SLEEPING:
		return false
	return _state == State.IDLE


func _clear_cohort_state() -> void:
	if data == null:
		return
	data.cohort_anchor_id = -1
	data.cohort_job_type = -1
	data.is_cohort_anchor = false
	_cohort_anchor_ref = null
	_clear_cohort_stability_state()
	_invalidate_recruitment_signal_cache()


func _active_cohort_job_type() -> int:
	if _current_job == null:
		return -1
	if _state == State.WALKING_TO_JOB or _state == State.WORKING or _state == State.FETCHING_MATERIAL:
		return int(_current_job.type)
	return -1


func _cohort_settlement_center_for_tile(tile: Vector2i) -> int:
	var rk: int = _WM._region_key(tile.x, tile.y)
	return SettlementMemory.get_center_region_for_region(rk)


func _cohort_anchor_node() -> HeelKawnian:
	if _cohort_anchor_ref == null:
		return null
	var n: Object = _cohort_anchor_ref.get_ref()
	if n == null or not (n is HeelKawnian):
		return null
	return n as HeelKawnian


func _job_locus_world_pos(p: HeelKawnian) -> Variant:
	if p == null or p.data == null or p._current_job == null or p._world == null:
		return null
	if p._active_cohort_job_type() < 0:
		return null
	return p._world.tile_to_world(p._current_job.work_tile)


func _cohort_locus_world_pos() -> Variant:
	var anchor: HeelKawnian = _cohort_anchor_node()
	# 1) Anchor's live job destination tile.
	var anchor_locus: Variant = _job_locus_world_pos(anchor)
	if anchor_locus is Vector2:
		return anchor_locus
	# 2) Own live job destination tile.
	var own_locus: Variant = _job_locus_world_pos(self)
	if own_locus is Vector2:
		return own_locus
	# 3) Anchor pawn position as last resort.
	if anchor != null:
		return anchor.position
	return null


func update_cohort_membership(force: bool = false) -> void:
	# Throttled to every 200 ticks to reduce lag (COHORT_UPDATE_TICKS)
	if not force and GameManager.tick_count % COHORT_UPDATE_TICKS != 0:
		return


func _validate_or_dissolve_cohort() -> void:
	if data == null:
		return
	if data.cohort_anchor_id < 0:
		return
	var job_type: int = _active_cohort_job_type()
	if job_type < 0 or data.cohort_job_type != job_type:
		_clear_cohort_state()
		return
	var anchor: HeelKawnian = _cohort_anchor_node()
	if anchor == null or anchor.data == null:
		_clear_cohort_state()
		return
	if int(anchor.data.id) != int(data.cohort_anchor_id):
		_clear_cohort_state()
		return
	if anchor == self:
		data.is_cohort_anchor = true
		return
	if anchor._active_cohort_job_type() != job_type:
		_clear_cohort_state()
		return
	var my_center: int = _cohort_settlement_center_for_tile(data.tile_pos)
	var anchor_center: int = _cohort_settlement_center_for_tile(anchor.data.tile_pos)
	if my_center >= 0 and anchor_center >= 0 and my_center != anchor_center:
		_clear_cohort_state()
		return
	var break_sq: int = COHORT_BREAK_DISTANCE_TILES * COHORT_BREAK_DISTANCE_TILES
	if data.tile_pos.distance_squared_to(anchor.data.tile_pos) > break_sq:
		_clear_cohort_state()


func _cohort_cohesion_bias(step: float) -> Vector2:
	if data == null or data.is_cohort_anchor or _path.is_empty():
		return Vector2.ZERO
	if _active_cohort_job_type() < 0:
		return Vector2.ZERO
	var anchor: HeelKawnian = _cohort_anchor_node()
	if anchor == null or anchor.data == null or anchor == self:
		return Vector2.ZERO
	if anchor._active_cohort_job_type() != _active_cohort_job_type():
		return Vector2.ZERO
	var locus_v: Variant = _cohort_locus_world_pos()
	if not (locus_v is Vector2):
		return Vector2.ZERO
	var locus: Vector2 = locus_v as Vector2
	var offset: Vector2 = locus - position
	var dist_sq: float = offset.length_squared()
	var max_dist_world: float = float(COHORT_BREAK_DISTANCE_TILES * World.TILE_PIXELS)
	if dist_sq <= 1.0 or dist_sq > max_dist_world * max_dist_world:
		return Vector2.ZERO
	var bias_mag: float = minf(COHORT_COHESION_MAX_STEP, step * COHORT_COHESION_BIAS_WEIGHT)
	return offset.normalized() * bias_mag


func _clear_cohort_stability_state() -> void:
	_cohort_stability_ticks = 0
	_cohort_locus_tile = Vector2i(-1, -1)
	_cohort_stability_job_type = -1


func _decay_cohort_stability_window() -> void:
	if _cohort_stability_ticks <= 0:
		_clear_cohort_stability_state()
		return
	_cohort_stability_ticks = maxi(0, _cohort_stability_ticks - COHORT_UPDATE_TICKS)
	if _cohort_stability_ticks <= 0:
		_clear_cohort_stability_state()


func _refresh_or_decay_cohort_stability(force: bool = false) -> void:
	if not force and GameManager.tick_count % COHORT_UPDATE_TICKS != 0:
		return
	if data == null:
		_clear_cohort_stability_state()
		return
	var active_job_type: int = _active_cohort_job_type()
	if active_job_type < 0 or _current_job == null:
		_decay_cohort_stability_window()
		return
	if int(data.cohort_anchor_id) < 0 or int(data.cohort_job_type) != active_job_type:
		_decay_cohort_stability_window()
		return
	if not data.is_cohort_anchor:
		var anchor: HeelKawnian = _cohort_anchor_node()
		if anchor == null or anchor.data == null:
			_decay_cohort_stability_window()
			return
		if anchor._active_cohort_job_type() != active_job_type:
			_decay_cohort_stability_window()
			return
	_cohort_locus_tile = _current_job.work_tile
	_cohort_stability_job_type = active_job_type
	_cohort_stability_ticks = COHORT_STABILITY_WINDOW_TICKS


func _cohort_locus_persistence_bias(step: float) -> Vector2:
	if data == null or data.is_cohort_anchor or _path.is_empty():
		return Vector2.ZERO
	if _cohort_stability_ticks <= 0 or _cohort_stability_job_type < 0:
		return Vector2.ZERO
	if _active_cohort_job_type() != _cohort_stability_job_type:
		return Vector2.ZERO
	if _cohort_locus_tile.x < 0 or _cohort_locus_tile.y < 0 or _world == null:
		return Vector2.ZERO
	var locus_world: Vector2 = _world.tile_to_world(_cohort_locus_tile)
	var offset: Vector2 = locus_world - position
	var dist_sq: float = offset.length_squared()
	var max_dist_world: float = float(COHORT_LOCUS_PERSIST_RADIUS_TILES * World.TILE_PIXELS)
	if dist_sq <= 1.0 or dist_sq > max_dist_world * max_dist_world:
		return Vector2.ZERO
	var bias_mag: float = minf(COHORT_LOCUS_PERSIST_MAX_STEP, step * COHORT_LOCUS_PERSIST_BIAS_WEIGHT)
	return offset.normalized() * bias_mag


func _invalidate_recruitment_signal_cache() -> void:
	_next_recruitment_cache_tick = 0
	_recruitment_signal_cache.clear()


func _update_recruitment_cache(force: bool = false) -> void:
	# DISABLED for performance - iterates through all pawns
	return


func get_cohort_recruitment_bias(job: Job) -> float:
	if data == null or job == null:
		return 1.0
	var job_type: int = int(job.type)
	var my_center: int = _cohort_settlement_center_for_tile(data.tile_pos)
	var job_center: int = _cohort_settlement_center_for_tile(job.work_tile)
	if my_center >= 0 and job_center >= 0 and my_center != job_center:
		return 1.0
	var radius_sq: int = COHORT_RECRUITMENT_SCAN_RADIUS_TILES * COHORT_RECRUITMENT_SCAN_RADIUS_TILES
	for sig in _recruitment_signal_cache:
		var sig_job: int = int(sig.get("job_type", -1))
		if sig_job != job_type:
			continue
		var sig_center: int = int(sig.get("center", -1))
		if my_center >= 0 and sig_center >= 0 and my_center != sig_center:
			continue
		var locus_tile: Vector2i = sig.get("locus_tile", Vector2i(-100000, -100000))
		if locus_tile.x <= -99999:
			continue
		if locus_tile.distance_squared_to(job.work_tile) > radius_sq:
			continue
		return COHORT_RECRUITMENT_BIAS_MAX
	return 1.0


func get_pawn_name_for_log() -> String:
	if data == null:
		return "?"
	return data.display_name


# === History response v1 (read-only: WorldPersistence + path weights) ===
# WorldMemory: tile-based HUNT completion records ANIMAL_DEATH when no Animal node
# occupies the tile. Food jobs (FORAGE/HUNT) are "critical" and skip scar penalties.
# See [PathFinder.find_path_pawn_historic_aversion] and [method _complete_current_job] HUNT.

func get_region_discomfort() -> int:
	## 0 = none, 1..3 = WorldPersistence.scar_level for this 16x16 map region.
	if data == null:
		return 0
	return _scar_level_at_tile(data.tile_pos)


static func _world_hunt_stabilization_blocks() -> bool:
	return (
			Main._world_stabilization_until_tick >= 0
			and GameManager.tick_count < Main._world_stabilization_until_tick
	)


## HUNT: same species int as [method Animal._apply_death] (Animal enum) for [WorldMemory].
static func _hunt_species_int_from_wildlife_feature(feat: int) -> int:
	if feat == TileFeature.Type.DEER:
		return int(Animal.Type.DEER)
	if feat == TileFeature.Type.RABBIT:
		return int(Animal.Type.RABBIT)
	return int(Animal.Type.RABBIT)


## True if a live [Animal] occupies [param t] (tile feature hunt must not double-record with node death).
func _hunt_has_live_animal_node_at(t: Vector2i) -> bool:
	var st: SceneTree = get_tree()
	if st == null:
		return false
	for n in st.get_nodes_in_group("animals"):
		if n is Animal and is_instance_valid(n) and (n as Animal).tile_pos == t:
			return true
	return false


## Check if a fisherman hut is within 4 tiles of the given position.
## Used to boost fishing yield when operating near a hut.
func _has_fisherman_hut_nearby(tile: Vector2i) -> bool:
	var w: Node = _world
	if w == null or w.data == null:
		return false
	var wd = w.data
	var search_radius: int = 4
	for dx in range(-search_radius, search_radius + 1):
		for dy in range(-search_radius, search_radius + 1):
			var nx: int = tile.x + dx
			var ny: int = tile.y + dy
			if not wd.in_bounds(nx, ny):
				continue
			if wd.get_feature(nx, ny) == TileFeature.Type.FISHERMAN_HUT:
				return true
	return false


static func is_job_history_critical(job_type: int) -> bool:
	return job_type == _Job.Type.FORAGE or job_type == _Job.Type.HUNT or job_type == _Job.Type.FISH


func _scar_level_at_tile(t: Vector2i) -> int:
	var rk: int = _WM._region_key(t.x, t.y)
	return int(WorldPersistence.get_region_scar_level(rk))


func _job_region_scar_blocks_noncritical(j: Job) -> bool:
	if is_job_history_critical(j.type):
		return false
	return _scar_level_at_tile(j.work_tile) >= 3


func _job_history_scar_priority_offset(j: Job) -> int:
	## Subtracted from effective job priority; critical jobs return 0.
	## Lived [WorldPersistence] bias is much stronger than cached cultural offset.
	if is_job_history_critical(j.type):
		return 0
	var o: int = 0
	match _scar_level_at_tile(j.work_tile):
		0:
			o = 0
		1:
			o = -5
		2:
			o = -24
		3:
			o = 0
		_:
			o = 0
	o += _culture_inherited_job_offset()
	o += _job_intent_priority_offset(j)
	return o


func _job_intent_priority_offset(j: Job) -> int:
	if j == null:
		return 0
	var from_rk: int = _WM._region_key(data.tile_pos.x, data.tile_pos.y)
	var to_rk: int = _WM._region_key(j.work_tile.x, j.work_tile.y)
	var from_center: int = SettlementMemory.get_center_region_for_region(from_rk)
	var to_center: int = SettlementMemory.get_center_region_for_region(to_rk)
	if from_center < 0 and to_center < 0:
		return 0
	var from_intent: int = int(IntentMemory.settlement_intent.get(from_center, IntentMemory.INTENT_HOLD))
	var to_intent: int = int(IntentMemory.settlement_intent.get(to_center, IntentMemory.INTENT_HOLD))
	var from_pressure: float = float(IntentMemory.settlement_pressure.get(from_center, 0.5))
	var to_pressure: float = float(IntentMemory.settlement_pressure.get(to_center, 0.5))
	var delta: int = 0
	if to_intent == IntentMemory.INTENT_GROW:
		delta += 3
	elif to_intent == IntentMemory.INTENT_ABANDON:
		delta -= 4
	if to_pressure < from_pressure:
		delta += 1
	elif to_pressure > from_pressure + 0.12:
		delta -= 1
	if from_intent == IntentMemory.INTENT_ABANDON and to_intent != IntentMemory.INTENT_ABANDON:
		delta += 2
	elif from_intent != IntentMemory.INTENT_ABANDON and to_intent == IntentMemory.INTENT_ABANDON:
		delta -= 2
	return delta


func _culture_inherited_job_offset() -> int:
	if initial_region_reputation >= 0:
		return 0
	## At most an extra -1 (when birth region was -3 or -2).
	if initial_region_reputation <= -2:
		return -1
	return 0


func _path_for_pawn(to: Vector2i) -> Array[Vector2i]:
	if _world == null or _world.pathfinder == null or data == null:
		return [] as Array[Vector2i]
	
	# Phase 5: Check if destination is near an enemy
	var destination_near_enemy: bool = is_tile_near_enemy(to)
	
	# If destination is near enemy, find alternative nearby tile
	var actual_dest: Vector2i = to
	if destination_near_enemy:
		actual_dest = _find_safe_tile_near(to)
		if actual_dest == to:
			# No safe alternative found, proceed anyway
			pass

	# PERFORMANCE: Use cached pathfinding
	return _get_cached_path(data.tile_pos, actual_dest, not GameManager.game_speed >= FAST_PATHFIND_SPEED_THRESHOLD)


## Find a safe tile near the goal (avoiding enemies)
## OPTIMIZATION: Limit search radius and iterations
func _find_safe_tile_near(goal: Vector2i) -> Vector2i:
	if _world == null or _world.data == null:
		return goal
	
	# OPTIMIZATION: Search only up to radius 4 (was 6), limit iterations
	for radius in range(1, 5):
		var found: bool = false
		for dx in range(-radius, radius + 1):
			for dy in range(-radius, radius + 1):
				if abs(dx) != radius and abs(dy) != radius:
					continue  # Only check perimeter
				var candidate: Vector2i = goal + Vector2i(dx, dy)
				if _world.data.in_bounds(candidate.x, candidate.y):
					if _world.pathfinder.is_passable(candidate):
						if not is_tile_near_enemy(candidate):
							return candidate
				found = true
			if found:
				break
		if found:
			break
	
	return goal  # No safe tile found, return original


func _request_redraw() -> void:
	queue_redraw()


## Throttled variant: only redraws every 3 ticks. Use for periodic/position
## updates where a 2-tick visual delay is acceptable.
func _request_redraw_throttled() -> void:
	if GameManager.tick_count % 3 == 0:
		queue_redraw()


func _ready() -> void:
	## Spawner calls [method bind] before [code]add_child[/code] so [member data] / [member _world] exist here.
	## [signal GameManager.game_tick] is deferred until after this node finishes [method _ready] (init order).
	_init_footstep_particles()
	_sfx = AudioStreamPlayer2D.new()
	_sfx.max_distance = 320.0
	_sfx.volume_db = -5.0
	add_child(_sfx)
	_action_popup = $ActionPopup
	add_to_group("tickable")
	set_process(false)
	if TickManager != null:
		TickManager.mark_tickable_cache_dirty()
	call_deferred("_pawn_connect_sim_tick_deferred")

	# HeelKawnian identity hook (deterministic per-soul profile bootstrap).
	if ClassDB.class_exists("HeelKawnianManager"):
		HeelKawnianManager.ensure_identity_for_pawn(self)


func _set_brain_instance(brain: HeelKawnPawnBrain) -> void:
	_brain_instance = brain


func _init_footstep_particles() -> void:
	_footstep_particles = GPUParticles2D.new()
	_footstep_particles.one_shot = true
	_footstep_particles.emitting = false
	_footstep_particles.amount = 2
	_footstep_particles.lifetime = 0.5
	_footstep_particles.explosiveness = 0.0
	_footstep_particles.randomness = 0.0
	var biome_color: Color = Color8(180, 160, 130)
	var _biome: int = _world.data.get_biome(data.tile_pos.x, data.tile_pos.y) if _world != null and data != null else -1
	match _biome:
		Biome.Type.DESERT:
			biome_color = Color8(210, 180, 140)
		Biome.Type.TUNDRA:
			biome_color = Color8(200, 200, 210)
		Biome.Type.PLAINS, Biome.Type.FOREST:
			biome_color = Color8(160, 140, 100)
	var mat: ParticleProcessMaterial = ParticleProcessMaterial.new()
	mat.gravity = Vector3.ZERO
	mat.initial_velocity_min = 5.0
	mat.initial_velocity_max = 15.0
	mat.angle_min = 0.0
	mat.angle_max = 360.0
	mat.scale_min = 0.3
	mat.scale_max = 0.8
	mat.color = biome_color
	_footstep_particles.process_material = mat
	add_child(_footstep_particles)


func _emit_footstep_dust() -> void:
	if _footstep_particles == null:
		return
	var _ws: Node = get_node_or_null("/root/WindSystem")
	if _ws != null and _ws.has_method("get_wind_direction") and _footstep_particles.process_material != null:
		var wind_dir: Vector2 = Vector2(_ws.get("_current_direction", Vector2.RIGHT))
		var wind_str: float = float(_ws.get("_current_strength", 0.5))
		_footstep_particles.process_material.initial_velocity_min = 5.0 + wind_str * 10.0
		_footstep_particles.process_material.direction = Vector3(wind_dir.x, 0, wind_dir.y)
	_footstep_particles.restart()
	_footstep_particles.emitting = true


func _get_brain() -> HeelKawnPawnBrain:
	return _brain_instance


func _pawn_connect_sim_tick_deferred() -> void:
	if not is_instance_valid(self):
		return
	if data == null or _world == null:
		push_warning("HeelKawnian: deferred tick connect skipped â€” not bound")
		return
	
	# CRITICAL: Arm pawn simulation ticks FIRST
	# This flag gates ALL pawn behavior in _on_world_tick
	_pawn_sim_tick_armed = true

	# Try to equip starting gear from stockpile (if available)
	if CraftingSystem != null and CraftingSystem.has_method("try_equip_from_stockpile"):
		CraftingSystem.try_equip_from_stockpile(data)

	# TickManager automatically calls _on_world_tick on all "tickable" group members
	# We were added to "tickable" in _ready(), so just ensure cache is dirty
	if TickManager != null:
		TickManager.mark_tickable_cache_dirty()
		# Force immediate cache rebuild so we're included in next tick
		TickManager._tickable_cache_dirty = true
	
	# DEBUG: Verify connection worked
	if OS.is_debug_build():
		print("[HeelKawnian] #%s %s: tick armed=%s, tickable=%s" % [data.id, data.display_name, _pawn_sim_tick_armed, is_in_group("tickable")])
	
	# Continue with pawn initialization
	_reserved_bed = Vector2i(-1, -1)
	_target_zone = null
	_cohort_id = -1
	_cohort_role = -1
	_last_recruitment_job_type = -1
	_next_reproduction_tick = GameManager.tick_count + 1000 + WorldRNG.index_for(_pawn_stream("reproduction_delay"), 4001, _pawn_salt(3))
	_carrying_spawn_item = false
	_perception_scan_cursor = 0
	# Load saved age as years for display
	data.age_years = float(data.age)
	
	# Teaching cooldown (3 days). bind() runs before add_child; resolve WorldClock from scene root.
	var tree_bt: SceneTree = Engine.get_main_loop() as SceneTree
	if tree_bt != null and tree_bt.root != null:
		var wc_bt: Node = tree_bt.root.get_node_or_null("WorldClock")
		if wc_bt != null and "ticks_per_day" in wc_bt:
			_teach_cooldown_ticks = int(wc_bt.ticks_per_day) * 3
	_clear_cohort_state()
	add_to_group("pawns")
	# Already added to "tickable" in _ready(); just mark cache dirty
	if TickManager != null:
		TickManager.mark_tickable_cache_dirty()
	if not _initial_knowledge_granted:
		_grant_initial_knowledge()
		_initial_knowledge_granted = true
	refresh_inherited_cultural_reputation()
	data.ensure_soul_identity()
	_reset_neural_priority_cache()
	_parity_context_tick = -1
	_parity_context.clear()
	_request_redraw()


func _reset_neural_priority_cache() -> void:
	_neural_priority_fetch_tick = -1
	_neural_priority_outputs.clear()


func _exit_tree() -> void:
	_pawn_sim_tick_armed = false
	_brain_instance = null
	# Disconnect from TickManager if connected
	var tick_manager = get_node_or_null("/root/TickManager")
	if tick_manager != null and tick_manager.tick_processed.is_connected(_on_world_tick):
		tick_manager.tick_processed.disconnect(_on_world_tick)
	# Disconnect from GameManager if connected (backward compatibility)
	if GameManager != null and GameManager.game_tick.is_connected(_on_world_tick):
		GameManager.game_tick.disconnect(_on_world_tick)
	# Unregister pawn data so static registry stays accurate
	if data != null:
		HeelKawnianData.unregister_pawn_data(int(data.id))
		if SpatialManager != null: # ARCHITECT T006
			SpatialManager.unregister_entity(int(data.id))
	# OPTIMIZATION: Invalidate avoidance caches for all pawns when this pawn dies
	_invalidate_avoidance_cache_for_pawn(int(data.id))


## Re-read the spawn tileâ€™s [CulturalMemory] entry (e.g. after load once ruins are applied). Does not run every tick.
func refresh_inherited_cultural_reputation() -> void:
	if data == null:
		initial_region_reputation = 0
		return
	var rk: int = _WM._region_key(data.tile_pos.x, data.tile_pos.y)
	initial_region_reputation = CulturalMemory.get_region_reputation(rk)


## KnowledgeSystem: grant initial knowledge based on profession
func _grant_initial_knowledge() -> void:
	if data == null:
		return
	var pawn_id: int = int(data.id)
	
	# Basic knowledge all pawns start with
	KnowledgeSystem.add_knowledge_carrier(pawn_id, KnowledgeSystem.KnowledgeType.FOOD_STORAGE)
	KnowledgeSystem.add_knowledge_carrier(pawn_id, KnowledgeSystem.KnowledgeType.NAVIGATION)
	
	# Profession-specific knowledge
	match int(data.current_profession):
		HeelKawnianData.Profession.FARMER:
			KnowledgeSystem.add_knowledge_carrier(pawn_id, KnowledgeSystem.KnowledgeType.SEASON_READING)
			KnowledgeSystem.add_knowledge_carrier(pawn_id, KnowledgeSystem.KnowledgeType.FIRE_KEEPING)
		HeelKawnianData.Profession.BUILDER:
			KnowledgeSystem.add_knowledge_carrier(pawn_id, KnowledgeSystem.KnowledgeType.SHELTER_BUILDING)
			KnowledgeSystem.add_knowledge_carrier(pawn_id, KnowledgeSystem.KnowledgeType.TOOL_MAKING)
		HeelKawnianData.Profession.GATHERER:
			KnowledgeSystem.add_knowledge_carrier(pawn_id, KnowledgeSystem.KnowledgeType.TOOL_MAKING)
		HeelKawnianData.Profession.WARRIOR:
			KnowledgeSystem.add_knowledge_carrier(pawn_id, KnowledgeSystem.KnowledgeType.NAVIGATION)
			KnowledgeSystem.add_knowledge_carrier(pawn_id, KnowledgeSystem.KnowledgeType.SICKNESS_AVOIDANCE)


## Player-ordered direct move. Cancels a claimed work job, drops bed/zone
## holds, and paths to a passable tile (Kenshi / RimWorld "draft" feel).
func draft_goto(world_tile: Vector2i) -> void:
	_autonomy_draft_purpose = ""
	_autonomy_draft_peer_id = -1
	if _world == null or _world.data == null:
		return
	if not _world.data.in_bounds(world_tile.x, world_tile.y):
		return
	if not _world.pathfinder.is_passable(world_tile):
		return
	release_job_if_any()
	_release_bed_if_reserved()
	_target_zone = null
	_clear_path()
	_state = State.DRAFT_WALK
	if data.tile_pos == world_tile:
		_state = State.IDLE
		_request_redraw()
		return
	var path: Array[Vector2i] = _path_for_pawn(world_tile)
	if path.is_empty():
		_state = State.IDLE
		_request_redraw()
		return
	_start_path(path)
	_request_redraw()


## NPC autonomy: same pathing as [draft_goto] but tags arrival for social / grudge resolution.
func autonomy_draft_goto(world_tile: Vector2i, purpose: String, peer_id: int = -1) -> void:
	if _world == null or _world.data == null:
		return
	if not _world.data.in_bounds(world_tile.x, world_tile.y):
		return
	if not _world.pathfinder.is_passable(world_tile):
		return
	_autonomy_draft_purpose = purpose
	_autonomy_draft_peer_id = peer_id
	release_job_if_any()
	_release_bed_if_reserved()
	_target_zone = null
	_clear_path()
	_state = State.DRAFT_WALK
	if data.tile_pos == world_tile:
		_autonomy_draft_purpose = ""
		_autonomy_draft_peer_id = -1
		_state = State.IDLE
		_request_redraw()
		return
	var path: Array[Vector2i] = _path_for_pawn(world_tile)
	if path.is_empty():
		_autonomy_draft_purpose = ""
		_autonomy_draft_peer_id = -1
		_state = State.IDLE
		_request_redraw()
		return
	_notify_autonomy_feedback(purpose)
	_start_path(path)
	_request_redraw()


## Tick-safe one-tile move used by deterministic player input queue.
func move(tile_delta: Vector2i) -> bool:
	if _world == null or data == null:
		return false
	var dest: Vector2i = data.tile_pos + tile_delta
	if not _world.data.in_bounds(dest.x, dest.y):
		return false
	if not _world.pathfinder.is_passable(dest):
		return false
	draft_goto(dest)
	return true


func _notify_autonomy_feedback(action_key: String) -> void:
	if action_key.is_empty() or action_key == _last_autonomy_feedback:
		return
	_last_autonomy_feedback = action_key
	# Debug print disabled for performance
	if _action_popup != null and data != null and GameManager != null and GameManager.game_speed < 60.0:
		_action_popup.show_action_context(data.display_name, "Autonomy: %s" % action_key, "", "", "")


func _finish_autonomy_draft_walk(purpose: String, peer_id: int) -> void:
	if data == null or GameManager == null:
		return
	var tick: int = GameManager.tick_count
	var peer: HeelKawnian = _find_pawn_by_id(peer_id)
	match purpose:
		"social_seek":
			if peer != null and is_instance_valid(peer) and peer.data != null:
				data.add_social_rapport(peer_id, 3)
				peer.data.add_social_rapport(int(data.id), 2)
				data.mood = min(100.0, data.mood + 0.35)
				peer.data.mood = min(100.0, peer.data.mood + 0.25)
				if data.neural_network != null and data.neural_network.has_method("record_memory_event"):
					data.neural_network.record_memory_event(tick, "social_visit", peer_id, 0.35)
		"teach_seek":
			if peer != null and is_instance_valid(peer) and peer.data != null:
				data.add_social_rapport(peer_id, 4)
				peer.data.add_social_rapport(int(data.id), 3)
				data.update_social_memory(peer_id, 0.08, 0.0, -0.02, 0.07, "autonomy_teach_seek")
				data.mood = min(100.0, data.mood + 0.25)
				if data.neural_network != null and data.neural_network.has_method("record_memory_event"):
					data.neural_network.record_memory_event(tick, "teach_seek", peer_id, 0.25)
		"grudge_confront":
			if peer != null and is_instance_valid(peer) and peer.data != null:
				data.update_social_memory(peer_id, 0.0, 0.0, -0.15, -0.05, "autonomy_confront")
				data.mood = clampf(data.mood - 0.4, 0.0, 100.0)
				if data.neural_network != null and data.neural_network.has_method("record_memory_event"):
					data.neural_network.record_memory_event(tick, "confront_attempt", peer_id, -0.08)
		_:
			pass
	_next_autonomy_grudge_tick = tick + 80
	_next_autonomy_social_seek_tick = tick + 50


func _find_pawn_by_id(pid: int) -> HeelKawnian:
	if pid < 0:
		return null
	# OPTIMIZATION: Use O(1) lookup instead of O(n) scan
	var _ps: PawnSpawner = _resolve_pawn_spawner()
	if _ps != null:
		return _ps.get_pawn_by_id(pid)
	return null


## True if the job type places a structure (building, not cooking/teaching/etc.)
func _is_structure_build_job(jtype: int) -> bool:
	match jtype:
		_Job.Type.BUILD_BED, _Job.Type.BUILD_WALL, _Job.Type.BUILD_DOOR, \
		_Job.Type.BUILD_FIRE_PIT, _Job.Type.BUILD_STORAGE_HUT, _Job.Type.BUILD_MARKER_STONE, \
		_Job.Type.BUILD_SHRINE, _Job.Type.BUILD_SHELTER, _Job.Type.BUILD_HEARTH, \
		_Job.Type.BUILD_FARM_WHEAT, _Job.Type.BUILD_FARM_CORN, _Job.Type.BUILD_FARM_VEGETABLES, _Job.Type.BUILD_HERB_GARDEN, \
		_Job.Type.BUILD_WORKSHOP, _Job.Type.BUILD_LOOM, _Job.Type.BUILD_KILN, _Job.Type.BUILD_SMELTER, \
		_Job.Type.BUILD_BOATYARD, _Job.Type.BUILD_DOCK, _Job.Type.BUILD_FISHERMAN_HUT, \
		_Job.Type.BUILD_APOTHECARY, \
		_Job.Type.BUILD_LIBRARY, _Job.Type.BUILD_SCHOOL, \
		_Job.Type.BUILD_BARRACKS, _Job.Type.BUILD_WATCHTOWER, \
		_Job.Type.BUILD_MARKET, _Job.Type.BUILD_TRADING_POST, \
		_Job.Type.BUILD_ROAD, \
		_Job.Type.BUILD_GRANARY, _Job.Type.BUILD_CELLAR, \
		_Job.Type.BUILD_FORD, _Job.Type.BUILD_WATER_MILL:
			return true
		_:
			return false
	return false


func _pick_passable_near_tile(origin: Vector2i, goal: Vector2i) -> Vector2i:
	if _world == null:
		return Vector2i(-1, -1)
	var best: Vector2i = Vector2i(-1, -1)
	var best_d: int = 1_000_000
	var dirs: Array[Vector2i] = [
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
		Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1),
	]
	for d in dirs:
		var t: Vector2i = goal + d
		if not _world.data.in_bounds(t.x, t.y):
			continue
		if not _world.pathfinder.is_passable(t):
			continue
		var dd: int = origin.distance_squared_to(t)
		if dd < best_d:
			best_d = dd
			best = t
	return best


func _try_autonomy_grudge_confront() -> bool:
	if data == null or _world == null or GameManager == null:
		return false
	if data.neural_network == null:
		return false
	var nn: Variant = data.neural_network
	if not nn.has_method("get_strongest_grudge_target_id"):
		return false
	var tick: int = GameManager.tick_count
	if tick < _next_autonomy_grudge_tick:
		return false
	if posmod(tick + int(data.id) * 11, 41) != 0:
		return false
	var gid: int = int(nn.get_strongest_grudge_target_id())
	if gid < 0:
		return false
	var gmag: float = absf(float(nn.grudge_toward(gid)))
	if gmag < 0.08:
		return false
	var p_roll: float = clampf(0.06 + gmag * 0.22, 0.05, 0.38)
	if not WorldRNG.chance_for(_pawn_stream("grudge_seek"), p_roll, _pawn_salt(71)):
		return false
	var target: HeelKawnian = _find_pawn_by_id(gid)
	if target == null or not is_instance_valid(target) or target.data == null:
		return false
	var near_tile: Vector2i = _pick_passable_near_tile(data.tile_pos, target.data.tile_pos)
	if near_tile.x < 0:
		return false
	autonomy_draft_goto(near_tile, "grudge_confront", gid)
	return _state == State.DRAFT_WALK


func _try_heelkawnian_matrix_social_action() -> bool:
	if data == null or _world == null or GameManager == null:
		return false
	var tick: int = GameManager.tick_count
	if posmod(tick + int(data.id) * 9, 29) != 0:
		return false
	var decision: Dictionary = HeelKawnianManager.get_social_action_for_pawn(self)
	if decision.is_empty():
		return false
	var action: String = str(decision.get("action", "none"))
	var target_id: int = int(decision.get("target_id", -1))
	if action == "none" or target_id < 0:
		return false
	if action == "grudge_confront" and tick < _next_autonomy_grudge_tick:
		return false
	if (action == "social_seek" or action == "teach_seek") and tick < _next_autonomy_social_seek_tick:
		return false
	var target: HeelKawnian = _find_pawn_by_id(target_id)
	if target == null or not is_instance_valid(target) or target.data == null:
		return false
	var near_tile: Vector2i = _pick_passable_near_tile(data.tile_pos, target.data.tile_pos)
	if near_tile.x < 0:
		return false
	autonomy_draft_goto(near_tile, action, target_id)
	return _state == State.DRAFT_WALK


func _try_heelkawnian_matrix_ambition_seed() -> bool:
	if data == null or _world == null or GameManager == null:
		return false
	var tick: int = GameManager.tick_count
	if tick < _next_matrix_ambition_tick:
		return false
	if posmod(tick + int(data.id) * 7, 23) != 0:
		return false
	var ambition: Dictionary = HeelKawnianManager.get_settlement_ambition_for_pawn(self)
	if ambition.is_empty():
		_next_matrix_ambition_tick = tick + 40
		return false
	var job_type: int = int(ambition.get("job_type", -1))
	if job_type < 0:
		_next_matrix_ambition_tick = tick + 55
		return false
	var target_tile: Vector2i = _matrix_ambition_target_tile(job_type)
	if target_tile.x < 0:
		_next_matrix_ambition_tick = tick + 65
		return false
	var priority: int = clampi(int(ambition.get("priority", 5)), 1, 10)
	var work_ticks: int = Job.tool_job_work_ticks(job_type)
	if work_ticks <= 0:
		work_ticks = 20
	var posted: Job = JobManager.post(job_type, target_tile, priority, work_ticks)
	if posted == null:
		_next_matrix_ambition_tick = tick + 70
		return false
	var payload: Dictionary = {
		"pawn_id": int(data.id),
		"pawn_name": data.display_name,
		"job_type": job_type,
		"job_name": Job.describe_type(job_type),
		"tile": target_tile,
		"priority": priority,
		"reason": str(ambition.get("reason", "")),
		"settlement_id": int(ambition.get("settlement_id", -1)),
	}
	HeelKawnianManager.log_heelkawn_event(
		str(ambition.get("soul_id", data.unique_id)),
		"matrix_settlement_ambition",
		payload,
		str(ambition.get("reason", "")),
		ambition,
		tick
	)
	_next_matrix_ambition_tick = tick + 110
	return true


func _try_heelkawnian_affiliation_action() -> bool:
	if data == null or _world == null or GameManager == null:
		return false
	# Belonging actions should not override survival.
	if data.hunger < HUNGER_EAT_THRESHOLD + 10.0:
		return false
	if data.rest < REST_SLEEP_THRESHOLD + 8.0:
		return false
	var tick: int = GameManager.tick_count
	if posmod(tick + int(data.id) * 7, 61) != 0:
		return false
	var act: Dictionary = HeelKawnianManager.get_affiliation_action_for_pawn(self)
	if act.is_empty():
		return false
	var kind: String = str(act.get("action", ""))
	match kind:
		"join_household":
			if int(data.household_id) >= 0:
				return false
			var hid: int = int(act.get("household_id", -1))
			if hid < 0:
				return false
			join_household(hid)
		"join_clan":
			if int(data.clan_id) >= 0:
				return false
			var cid: int = int(act.get("clan_id", -1))
			if cid < 0:
				return false
			join_clan(cid)
		"join_nation":
			if int(data.nation_id) >= 0:
				return false
			var nid: int = int(act.get("nation_id", -1))
			if nid < 0:
				return false
			join_nation(nid)
			if data.national_citizenship <= 0:
				set_national_citizenship(1)
		_:
			return false
	HeelKawnianManager.log_heelkawn_event(
		data.unique_id,
		"matrix_affiliation",
		{
			"pawn_id": int(data.id),
			"pawn_name": data.display_name,
			"action": kind,
			"household_id": int(data.household_id),
			"clan_id": int(data.clan_id),
			"nation_id": int(data.nation_id),
		},
		str(act.get("rationale", "")),
		act,
		tick
	)
	return true


func _matrix_ambition_target_tile(job_type: int) -> Vector2i:
	if _world == null or _world.data == null or _world.pathfinder == null or data == null:
		return Vector2i(-1, -1)
	var origin: Vector2i = data.tile_pos
	var prefer_ring: int = 4
	var allow_fertile: bool = false  # Farms can go on fertile soil
	if job_type == _Job.Type.BUILD_WALL or job_type == _Job.Type.BUILD_DOOR:
		prefer_ring = 8
	elif job_type == _Job.Type.BUILD_BED or job_type == _Job.Type.BUILD_FIRE_PIT or job_type == _Job.Type.BUILD_STORAGE_HUT or job_type == _Job.Type.BUILD_SHELTER or job_type == _Job.Type.BUILD_HEARTH:
		prefer_ring = 6  # Increased from 3 â€” critical infrastructure needs more space
	elif job_type == _Job.Type.GROW_FOOD or job_type == _Job.Type.PLANT_SEEDS:
		prefer_ring = 6
	# Phase 6: farms prefer fertile soil, larger search radius
	elif job_type == _Job.Type.BUILD_FARM_WHEAT or job_type == _Job.Type.BUILD_FARM_CORN or job_type == _Job.Type.BUILD_FARM_VEGETABLES or job_type == _Job.Type.BUILD_HERB_GARDEN:
		prefer_ring = 8
		allow_fertile = true
	# Phase 6: maritime buildings need water adjacency
	elif job_type == _Job.Type.BUILD_BOATYARD or job_type == _Job.Type.BUILD_DOCK or job_type == _Job.Type.BUILD_FISHERMAN_HUT:
		prefer_ring = 10
	# Phase 6: roads go further out
	elif job_type == _Job.Type.BUILD_ROAD:
		prefer_ring = 7
	# Two-pass search: first pass prefers empty tiles, second pass allows clearable features
	# (TREE, FERTILE_SOIL, STICK, FLINT, RUIN) â€” set_feature overwrites them on completion.
	for pass_n in range(2):
		for r in range(1, prefer_ring + 1):
			for y in range(-r, r + 1):
				for x in range(-r, r + 1):
					if abs(x) != r and abs(y) != r:
						continue
					var t: Vector2i = origin + Vector2i(x, y)
					if not _world.data.in_bounds(t.x, t.y):
						continue
					if not _world.pathfinder.is_passable(t):
						continue
					var feat: int = int(_world.data.get_feature(t.x, t.y))
					if job_type == _Job.Type.BUILD_WALL or job_type == _Job.Type.BUILD_DOOR:
						if pass_n == 0:
							if feat != TileFeature.Type.NONE and feat != TileFeature.Type.WALL:
								continue
						else:
							# Second pass: allow clearable features for walls
							if TileFeature.name_for(feat) != "None" and feat != TileFeature.Type.WALL and feat != TileFeature.Type.TREE and feat != TileFeature.Type.FERTILE_SOIL and feat != TileFeature.Type.ORE_VEIN and feat != TileFeature.Type.RUIN:
								continue
					elif allow_fertile:
						if feat != TileFeature.Type.NONE and feat != TileFeature.Type.FERTILE_SOIL:
							continue
					else:
						if pass_n == 0:
							if feat != TileFeature.Type.NONE:
								continue
						else:
							# Second pass: allow clearable features (tree, fertile soil, ore vein, ruin)
							if TileFeature.name_for(feat) != "None" and feat != TileFeature.Type.TREE and feat != TileFeature.Type.FERTILE_SOIL and feat != TileFeature.Type.ORE_VEIN and feat != TileFeature.Type.RUIN:
								continue
					return t
	return _pick_passable_near_tile(origin, origin + Vector2i(2, 0))


func _try_autonomy_social_seek() -> bool:
	if data == null or _world == null or GameManager == null:
		return false
	if data.neural_network == null:
		return false
	if str(data.neural_network.get_autonomy_hint()) != "social":
		return false
	var tick: int = GameManager.tick_count
	if tick < _next_autonomy_social_seek_tick:
		return false
	if posmod(tick + int(data.id) * 5, 37) != 0:
		return false
	var spawner: PawnSpawner = _resolve_pawn_spawner()
	if spawner == null:
		return false
	var best_peer: HeelKawnian = null
	var best_score: float = -1.0
	var seen: int = 0
	for p in spawner.pawns:
		seen += 1
		if seen > 28:
			break
		if p == null or not is_instance_valid(p) or p == self or p.data == null:
			continue
		var d2: int = data.tile_pos.distance_squared_to(p.data.tile_pos)
		if d2 > 400:
			continue
		var pid_i: int = int(p.data.id)
		var rap: float = float(data.get_social_rapport(pid_i))
		var score: float = rap / 3000.0 - float(d2) / 20000.0
		# Profession clustering: same-profession pawns are slightly more attractive
		if data.current_profession != HeelKawnianData.Profession.NONE and p.data.current_profession == data.current_profession:
			score += 0.15
		if score > best_score:
			best_score = score
			best_peer = p
	if best_peer == null:
		return false
	var near_tile: Vector2i = _pick_passable_near_tile(data.tile_pos, best_peer.data.tile_pos)
	if near_tile.x < 0:
		return false
	autonomy_draft_goto(near_tile, "social_seek", int(best_peer.data.id))
	return _state == State.DRAFT_WALK


## Memorial pilgrimage: pawn feels desire to visit memorial (closure, remembrance, family)
func _try_start_pilgrimage() -> bool:
	if data == null or _world == null or GameManager == null:
		return false
	var ms: Node = get_node_or_null("/root/MemorialSystem")
	if ms == null:
		return false
	
	var tick: int = GameManager.tick_count
	
	# Check pilgrimage desire occasionally (every 200 ticks, staggered by pawn ID)
	if tick % 200 != int(data.id) % 200:
		return false
	
	# Only pilgrimage when idle
	if _state != State.IDLE:
		return false
	
	# Check if any memorials call to this pawn
	var memorial: Dictionary = ms.call("get_memorial_for_pilgrimage", int(data.id)) if ms.has_method("get_memorial_for_pilgrimage") else {}
	if memorial.is_empty():
		return false
	
	# Start pilgrimage
	_start_pilgrimage_to_memorial(memorial)
	return true


func _start_pilgrimage_to_memorial(memorial: Dictionary) -> void:
	var target_tile: Vector2i = memorial.tile
	
	# Pathfind to memorial tile (use cached pathfinding, no historic aversion for pilgrimage)
	var path = _get_cached_path(data.tile_pos, target_tile, false)
	if path.is_empty():
		return  # No valid path
	
	# Set state to PILGRIMAGE
	_state = State.PILGRIMAGE
	_current_job = null  # Clear any job
	_path = path
	_target_tile = target_tile
	_target_world_pos = _world.tile_to_world(target_tile)
	
	if GameManager.verbose_logs():
		print("[HeelKawnian] %s starting pilgrimage to memorial at (%d,%d)" % [
			data.display_name, target_tile.x, target_tile.y
		])


func _try_grave_pilgrimage() -> bool:
	if data == null or _world == null:
		return false
	if data.mood > 50.0:
		return false
	var grave_tile: Vector2i = _find_family_grave()
	if grave_tile.x < 0:
		return false
	var path: Array[Vector2i] = _world.pathfinder.find_path(data.tile_pos, grave_tile)
	if path.is_empty():
		return false
	_current_job = Job.new()
	_current_job.type = _Job.Type.VISIT_GRAVE
	_current_job.tile = grave_tile
	_current_job.work_tile = grave_tile
	_current_job.work_ticks_needed = 30
	_current_job.work_ticks_done = 0
	_state = State.WALKING_TO_JOB
	_start_path(path)
	return true


func _find_family_grave() -> Vector2i:
	if WorldMemory == null:
		return Vector2i(-1, -1)
	for y in range(maxi(0, data.tile_pos.y - 20), mini(WorldData.HEIGHT, data.tile_pos.y + 20)):
		for x in range(maxi(0, data.tile_pos.x - 20), mini(WorldData.WIDTH, data.tile_pos.x + 20)):
			var feat: int = _world.data.get_feature(x, y)
			if feat == TileFeature.Type.GRAVE_MARKER:
				return Vector2i(x, y)
	return Vector2i(-1, -1)


## Dream nudge: follow a recent dream impulse if it suggests wandering/socializing/resting.
func _maybe_follow_dream_nudge() -> bool:
	if data == null or _world == null:
		return false
	var pc: Node = get_node_or_null("/root/PawnConsciousness")
	if pc == null or not pc.has_method("get_dream_nudge"):
		return false
	var nudge_v: Variant = pc.get_dream_nudge(int(data.id))
	if nudge_v is not Dictionary:
		return false
	var nudge: Dictionary = nudge_v as Dictionary
	var action: String = str(nudge.get("action", ""))
	if action.is_empty():
		return false
	var intensity: float = float(nudge.get("intensity", 0.0))
	if intensity <= 0.0:
		return false
	# Check for prophetic dreams first
	if pc.has_method("get_dreams"):
		var recent_dreams: Array = pc.get_dreams(int(data.id), 3)
		for dream in recent_dreams:
			if dream is Dictionary and dream.has("prophetic"):
				var prop: Dictionary = dream["prophetic"] as Dictionary
				if not prop.is_empty() and int(prop.get("distance", 0)) > 0:
					var dir_v: Variant = prop.get("direction", {})
					if dir_v is Dictionary:
						var dir_vec: Vector2i = Vector2i(int(dir_v.get("x", 0)), int(dir_v.get("y", 0)))
						var dist: int = int(prop.get("distance", 10))
						if dir_vec != Vector2i.ZERO:
							var target: Vector2i = data.tile_pos + dir_vec * dist
							target.x = clampi(target.x, 1, _world.data.get_size().x - 2)
							target.y = clampi(target.y, 1, _world.data.get_size().y - 2)
							autonomy_draft_goto(target, "prophetic_dream", 2)
							return true

	if action == "wander":
		if WorldRNG.chance_for(_pawn_stream("dream_nudge_wander"), clampf(intensity, 0.0, 1.0), _pawn_salt(29)):
			_start_wander()
			return true
	elif action == "socialize":
		if WorldRNG.chance_for(_pawn_stream("dream_nudge_socialize"), clampf(intensity * 0.8, 0.0, 1.0), _pawn_salt(31)):
			if _try_autonomy_social_seek():
				return true
			_start_wander()
			return true
	elif action == "rest":
		if _maybe_start_sleeping():
			return true
	elif action == "forage":
		if _maybe_start_eating():
			return true
	return false


## Warrior peacetime patrol: path toward a settlement wall tile and idle there.
## Gives warriors visible presence around the perimeter instead of clustering at stockpile.
func _maybe_warrior_patrol() -> bool:
	if data == null or _world == null or GameManager == null:
		return false
	var tick: int = GameManager.tick_count
	# Don't patrol every tick â€” check every ~60 ticks
	if posmod(tick + int(data.id) * 7, 60) != 0:
		return false
	# Only patrol if no HUNT/DEFEND/PROTECT jobs are available
	if JobManager.active_count_of_type(_Job.Type.HUNT) > 0:
		return false
	if JobManager.active_count_of_type(_Job.Type.DEFEND) > 0:
		return false
	if JobManager.active_count_of_type(_Job.Type.PROTECT) > 0:
		return false
	# Find a wall tile near the settlement to patrol toward
	if data.settlement_id < 0:
		return false
	var sm: Node = get_node_or_null("/root/SettlementMemory")
	if sm == null or not sm.has_method("get_settlements"):
		return false
	var arr: Array = sm.get_settlements()
	if data.settlement_id >= arr.size():
		return false
	var st: Dictionary = arr[data.settlement_id] as Dictionary
	var regions: Variant = st.get("regions", PackedInt32Array())
	if not (regions is PackedInt32Array):
		return false
	var packed: PackedInt32Array = regions as PackedInt32Array
	if packed.is_empty():
		return false
	# Pick a random wall tile from the settlement
	var center_rk: int = int(st.get("center_region", packed[0]))
	var center: Vector2i = SettlementManager._center_tile_of_region_key(center_rk)
	# Search for walls in a small radius
	var wall_cands: Array[Vector2i] = []
	for dy in range(-6, 7):
		for dx in range(-6, 7):
			var t: Vector2i = Vector2i(center.x + dx, center.y + dy)
			if not _world.data.in_bounds(t.x, t.y):
				continue
			if int(_world.data.get_feature(t.x, t.y)) == TileFeature.Type.WALL:
				# Find passable tile adjacent to this wall
				for ady in range(-1, 2):
					for adx in range(-1, 2):
						var at: Vector2i = Vector2i(t.x + adx, t.y + ady)
						if _world.data.in_bounds(at.x, at.y) and _world.data.is_passable(at.x, at.y):
							wall_cands.append(at)
	if wall_cands.is_empty():
		return false
	# Deterministic pick based on pawn id + tick
	var idx: int = posmod(int(data.id) * 31 + tick / 60, wall_cands.size())
	var target: Vector2i = wall_cands[idx]
	autonomy_draft_goto(target, "warrior_patrol", 0)
	return _state == State.DRAFT_WALK


## Cultural exposure: if this pawn is from a different settlement than the
## region they're standing in, and the region has active custom tags, they
## may absorb the custom. Absorbed customs nudge the pawn's home settlement
## toward adopting the same custom over time (via SettlementMemory drift).
func _maybe_absorb_custom() -> void:
	if data == null or _WM == null or GameManager == null:
		return
	var rk: int = _WM._region_key(data.tile_pos.x, data.tile_pos.y)
	var tags: PackedStringArray = WorldMeaning.get_region_tags(rk)
	# Only active customs (not faded) can be absorbed
	var active_customs: PackedStringArray = []
	for tag in tags:
		if tag == "burial_grove" or tag == "teaching_ground" or tag == "feast_ground" or tag == "builder_yard" or tag == "gathering_place":
			active_customs.append(tag)
	if active_customs.is_empty():
		return
	# Check if this pawn is an outsider (different settlement than the region)
	var pawn_settlement: int = data.settlement_id
	var region_settlement: Variant = SettlementMemory.get_settlement_at_region(rk)
	var region_settlement_id: int = -1
	if region_settlement != null and region_settlement is Dictionary:
		region_settlement_id = int((region_settlement as Dictionary).get("center_region", -1))
	if pawn_settlement < 0 or region_settlement_id < 0 or pawn_settlement == region_settlement_id:
		return  # Same settlement â€” no exposure effect
	# Deterministic chance: 10% per check (every 100 ticks = ~1.8% per in-world day)
	if not WorldRNG.chance_for(_pawn_stream("custom_absorb"), 0.10, _pawn_salt(17)):
		return
	# Record cultural exposure event
	WorldMemory.record_event({
		"type": "cultural_exposure",
		"k": WorldMemory.Kind.TEACHING_EVENT,  # Reuse teaching kind for knowledge transmission
		"r": rk,
		"t": GameManager.tick_count,
		"pawn_id": int(data.id),
		"custom_tag": active_customs[0],  # Absorb one custom at a time
		"from_settlement": region_settlement,
		"to_settlement": pawn_settlement,
	})


## Knowledge rediscovery: if this pawn is a scholar or has high openness,
## and they're near a dormant knowledge site, they may rediscover lost knowledge.
func _maybe_attempt_rediscovery() -> void:
	if data == null or KnowledgeSystem == null or GameManager == null:
		return
	# Only scholars and high-openness pawns attempt rediscovery
	if data.current_profession != HeelKawnianData.Profession.SCHOLAR and data.openness < 0.6:
		return
	var dormant_types: Array = KnowledgeSystem.get_dormant_knowledge_types()
	if dormant_types.is_empty():
		return
	# Check each dormant knowledge type
	for kt in dormant_types:
		if KnowledgeSystem.attempt_rediscovery(int(data.id), data.tile_pos, int(kt)):
			break  # One rediscovery per check is enough


## Diaspora homesickness: exiled pawns check their origin settlement.
## If the origin has collapsed, they experience a grief event derived from facts.
func _maybe_diaspora_homesickness(tick: int) -> void:
	if data == null or SettlementMemory == null or GameManager == null:
		return
	var origin_id: int = int(data._diaspora_origin)
	if origin_id < 0:
		return
	# Check if origin settlement still exists
	var origin_exists: bool = false
	var origin_collapsed: bool = false
	if SettlementMemory.has_method("get_settlements"):
		for s in SettlementMemory.get_settlements():
			if s is Dictionary:
				if int(s.get("center_region", -1)) == origin_id:
					origin_exists = true
					var state: String = str(s.get("state", ""))
					if state == "collapsed" or state == "abandoned":
						origin_collapsed = true
					break
	if origin_collapsed:
		# Origin settlement has collapsed â€” grief event
		data.mood = maxf(data.mood - 15.0, 0.0)
		WorldMemory.record_event({
			"type": "diaspora_grief",
			"k": WorldMemory.Kind.PAWN_DEATH,
			"r": WorldMemory._region_key(data.tile_pos.x, data.tile_pos.y),
			"t": tick,
			"pawn_id": int(data.id),
			"origin_settlement": origin_id,
			"origin_state": "collapsed",
		})
		# Clear diaspora origin â€” grief is processed once
		data._diaspora_origin = -1
	elif not origin_exists:
		# Origin settlement no longer exists at all â€” deeper grief
		data.mood = maxf(data.mood - 25.0, 0.0)
		WorldMemory.record_event({
			"type": "diaspora_grief",
			"k": WorldMemory.Kind.PAWN_DEATH,
			"r": WorldMemory._region_key(data.tile_pos.x, data.tile_pos.y),
			"t": tick,
			"pawn_id": int(data.id),
			"origin_settlement": origin_id,
			"origin_state": "destroyed",
		})
		data._diaspora_origin = -1


func _can_use_manual_ground_item_actions() -> bool:
	match _state:
		State.WORKING, State.WALKING_TO_JOB, State.HAULING, State.GOING_TO_EAT, State.EATING, State.SLEEPING, State.FETCHING_MATERIAL, State.GOING_TO_BED, State.TEACHING, State.CHALLENGE, State.CRAFTING:
			return false
		_:
			return true


## Pick up one logical stack from the ground at the current tile (deterministic type order).
## Returns false if busy, hands full of a different item, or nothing on the tile.
func try_pickup_item() -> bool:
	if data == null or _world == null:
		return false
	if not _can_use_manual_ground_item_actions():
		return false
	var tile: Vector2i = data.tile_pos
	var stacks: Dictionary = _world.get_ground_stacks_at(tile)
	if stacks.is_empty():
		return false
	var type_keys: Array = stacks.keys()
	type_keys.sort()
	var chosen_type: int = _Item.Type.NONE
	var on_ground: int = 0
	for tk in type_keys:
		var q: int = int(stacks[tk])
		if q > 0:
			chosen_type = int(tk)
			on_ground = q
			break
	if chosen_type == _Item.Type.NONE or on_ground <= 0:
		return false
	if data.is_carrying() and data.carrying != chosen_type:
		return false
	var taken: int = _world.take_ground_items(tile, chosen_type, on_ground)
	if taken <= 0:
		return false
	if data.carrying == chosen_type:
		data.carrying_qty += taken
	else:
		data.carrying = chosen_type
		data.carrying_qty = taken
	_request_redraw()
	return true


## Place the carried stack on the ground at the current tile.
func drop_item() -> bool:
	if data == null or _world == null:
		return false
	if not _can_use_manual_ground_item_actions():
		return false
	if not data.is_carrying():
		return false
	var tile: Vector2i = data.tile_pos
	var it: int = data.carrying
	var q: int = data.carrying_qty
	_world.add_ground_item(tile, it, q)
	data.clear_carry()
	_request_redraw()
	return true


## Contextual player action hook used by deterministic player input queue.
func interact() -> bool:
	if data == null:
		return false
	if try_pickup_item():
		return true
	if data.is_carrying():
		_begin_haul_to_stockpile()
		return true
	if _maybe_start_eating():
		return true
	if _maybe_start_sleeping():
		return true
	_perform_presence_action()
	return true


func _perform_presence_action() -> void:
	if data == null:
		return
	var rk: int = _WM._region_key(data.tile_pos.x, data.tile_pos.y)
	var settlement_state: String = SettlementMemory.get_state_at_region(rk)
	data.mood = min(100.0, data.mood + 0.75)
	WorldMemory.record_event({
		"type": "player_presence",
		"pawn_id": int(data.id),
		"tick": GameManager.tick_count,
		"region": rk,
		"settlement_state": settlement_state,
		"tile": {"x": data.tile_pos.x, "y": data.tile_pos.y},
		"mood": int(round(data.mood)),
	})
	_request_redraw()


## Player-local inspect action: records a local inspection event and returns true if performed.
func inspect() -> bool:
	if data == null:
		return false
	# Do not inspect while busy hauling/eating/sleeping
	if _state == State.HAULING or _state == State.EATING or _state == State.SLEEPING:
		return false
	_perform_inspect_action()
	return true


func _perform_inspect_action() -> void:
	if data == null:
		return
	var rk: int = _WM._region_key(data.tile_pos.x, data.tile_pos.y)
	var center_region: int = SettlementMemory.get_center_region_for_region(rk)
	var region_key_for_meaning: int = center_region if center_region >= 0 else rk
	var meaning_label: String = WorldMeaning.get_region_meaning_label(region_key_for_meaning)
	var zone_id: String = str(region_key_for_meaning)
	var tags: PackedStringArray = WorldMeaning.get_zone_tags(zone_id)
	WorldMemory.record_event({
		"type": "player_inspect",
		"pawn_id": int(data.id),
		"tick": GameManager.tick_count,
		"region": rk,
		"center_region": region_key_for_meaning,
		"meaning_label": meaning_label,
		"tags": tags,
		"tile": {"x": data.tile_pos.x, "y": data.tile_pos.y},
	})
	# Record ephemeral inspect message for immediate HUD feedback
	_last_inspect_msg = "%s â€” %s" % [meaning_label, (", ".join(tags) if tags.size() > 0 else "no notable tags")]
	_last_inspect_tick = GameManager.tick_count
	_request_redraw()


## Player interaction: teach knowledge to nearby pawn
func teach_knowledge(knowledge_type: int) -> bool:
	# DISABLED for performance - iterates through all pawns
	return false


## Player interaction: challenge nearby pawn's authority
func challenge_authority_nearby(context: int) -> bool:
	# DISABLED for performance - iterates through all pawns
	return false


## Player interaction: visit persistent entity at current location
func visit_persistent_entity() -> bool:
	if PersistenceSystem == null:
		return false
	
	# Find persistent entity at current tile
	var entities: Array = PersistenceSystem.get_entities_at_tile(data.tile_pos)
	
	if entities.is_empty():
		return false
	
	for entity_id in entities:
		PersistenceSystem.record_visitation(entity_id, int(data.id))
		
		if GameManager.verbose_logs():
			print("[HeelKawnian] Player visiting persistent entity %d at %s" % [entity_id, str(data.tile_pos)])
	
	return true


func record_skill_gain(skill: String, amount: int) -> void:
	if data == null:
		return
	if data.gain_skill_xp(skill, amount):
		WorldMemory.record_event({
			"type": "skill_gain",
			"pawn_id": int(data.id),
			"skill": skill,
			"amount": amount,
			"tick": GameManager.tick_count,
			"total_xp": int(data.tracked_skill_xp(skill)),
			"profession": data.profession_name(),
		})


func _show_action_popup_for_job(job: Job) -> void:
	if data == null or _action_popup == null:
		return
	
	var action_name: String = Job.describe_type(job.type)
	var personality_context: String = _get_personality_context_for_job(job)
	var goal_context: String = _get_goal_context_for_job(job)
	var memory_context: String = _get_memory_context_for_job(job)
	
	_action_popup.show_action_context(data.display_name, action_name, personality_context, goal_context, memory_context)


func _get_personality_context_for_job(job: Job) -> String:
	if data == null:
		return ""
	
	var context: String = ""
	
	# Openness influences exploration
	if data.openness > 0.7 and job.type == _Job.Type.FORAGE:
		context = "High openness drives exploration"
	elif data.openness < 0.3 and job.type == _Job.Type.FORAGE:
		context = "Low openness prefers familiar areas"
	
	# Conscientiousness influences work quality
	if data.conscientiousness > 0.7:
		if context.is_empty():
			context = "High conscientiousness ensures thorough work"
		else:
			context += ", thorough work"
	
	# Extraversion influences social jobs
	if data.extraversion > 0.7 and job.type == _Job.Type.BUILD_BED:
		if context.is_empty():
			context = "High extraversion enjoys community building"
		else:
			context += ", enjoys community building"
	
	return context


func _get_goal_context_for_job(job: Job) -> String:
	if data == null:
		return ""
	
	var context: String = ""
	
	# Check which needs are driving this action
	if data.hunger < 50.0 and job.type == _Job.Type.FORAGE:
		context = "Driven by survival need: hunger at %.0f%%" % data.hunger
	elif data.rest < 50.0 and job.type == _Job.Type.BUILD_BED:
		context = "Driven by rest need: seeking shelter"
	
	# Check active goals
	if not data.active_goals.is_empty():
		for goal_id in data.active_goals:
			var goal = data.active_goals[goal_id]
			if goal.type == "survival" and job.type == _Job.Type.FORAGE:
				if context.is_empty():
					context = "Goal: secure food supply"
				else:
					context += ", goal: secure food"
			elif goal.type == "shelter" and job.type == _Job.Type.BUILD_BED:
				if context.is_empty():
					context = "Goal: improve shelter"
				else:
					context += ", goal: improve shelter"
	
	return context


func _get_memory_context_for_job(job: Job) -> String:
	if data == null:
		return ""
	
	var context: String = ""
	
	# Check spatial memory for past success at this location
	var location_key: String = "%d,%d" % [job.work_tile.x, job.work_tile.y]
	if data.spatial_memory.has(location_key):
		var memory = data.spatial_memory[location_key]
		var success_count: int = memory.get("success_count", 0)
		if success_count > 3:
			context = "Recalls %d past successes here" % success_count
	
	# Check episodic memory for similar jobs
	if not data.episodic_memory.is_empty():
		var memory_keys: Array = data.episodic_memory.keys()
		var count: int = 0
		for key in memory_keys:
			if count >= 10:
				break
			var mem = data.episodic_memory[key]
			var mem_type: String = mem.get("type", "")
			if mem_type == "job_completed" and mem.get("job_type", -1) == job.type:
				if context.is_empty():
					context = "Recalls recent similar work"
				else:
					context += ", recalls similar work"
				break
			count += 1
	
	return context


## Called from World when a wall appears under this pawn â€” step off solid tiles.
func nudge_if_standing_on_solid() -> void:
	if _world == null or _world.pathfinder == null or data == null:
		return
	if _world.pathfinder.is_passable(data.tile_pos):
		return
	var dest: Vector2i = _world.pathfinder.find_adjacent_passable(data.tile_pos)
	if dest.x < 0:
		return
	_clear_path()
	# Stuck pawns are never supposed to be mid-job on the tile that became
	# a wall, but if pathing desyncs, free the job so the AI can recover.
	if _current_job != null:
		var jn: Job = _current_job
		_return_trade_cargo_to_source_if_any(jn)
		JobManager.abandon(jn)
		_current_job = null
	_state = State.IDLE
	var from_n: Vector2i = data.tile_pos
	data.tile_pos = dest
	if from_n != dest:
		RoadMemory.record_step(from_n, dest, _world)
	position = _world.tile_to_world(dest)
	_target_tile = dest
	_target_world_pos = position
	_request_redraw()


## Evict a pawn standing *on* `stand_tile` to any adjacent walkable cell (used
## before a wall build finalizes, while the cell may still be passable in data).
func evict_to_neighbor_of_tile(stand_tile: Vector2i) -> void:
	if _world == null or _world.pathfinder == null or data == null:
		return
	if _state == State.SLEEPING or _state == State.EATING:
		return
	if data.tile_pos != stand_tile:
		return
	var dest: Vector2i = _world.pathfinder.find_adjacent_passable(stand_tile)
	if dest.x < 0:
		return
	_clear_path()
	# If we're standing on a build site, drop work so the site can be committed.
	if _current_job != null:
		var je: Job = _current_job
		_return_trade_cargo_to_source_if_any(je)
		JobManager.abandon(je)
		_current_job = null
	_state = State.IDLE
	_target_zone = null
	var from_e: Vector2i = stand_tile
	data.tile_pos = dest
	if from_e != dest:
		RoadMemory.record_step(from_e, dest, _world)
	position = _world.tile_to_world(dest)
	_target_tile = dest
	_target_world_pos = position
	_request_redraw()


## World/navigation: tiles changed (walls, doors, mining). Re-nudge, then
## re-seek paths for movement states.
func on_world_nav_changed() -> void:
	if _world == null or _world.pathfinder == null or data == null:
		return
	if not _world.pathfinder.is_passable(data.tile_pos):
		nudge_if_standing_on_solid()
		return
	match _state:
		State.WALKING_TO_JOB:
			if _current_job != null:
				_walk_to_work_tile(_current_job)
		State.FETCHING_MATERIAL:
			if _current_job != null:
				var mm: Dictionary = _materials_for_build(_current_job.type)
				if not mm.is_empty():
					_begin_fetching_material(mm.item, mm.qty)
		State.HAULING:
			if data.is_carrying():
				if _current_job != null and _current_job.type == _Job.Type.TRADE_HAUL and _current_job.trade_to != null:
					_begin_haul_to_forced_zone(_current_job.trade_to)
				else:
					_begin_haul_to_stockpile()
		State.GOING_TO_EAT:
			if _target_zone != null and is_instance_valid(_target_zone):
				_begin_going_to_eat(_target_zone)
		State.GOING_TO_BED:
			if _reserved_bed.x < 0:
				pass
			elif data.tile_pos == _reserved_bed:
				pass
			else:
				var pbed: Array[Vector2i] = _path_for_pawn(_reserved_bed)
				if pbed.is_empty():
					_world.release_bed(_reserved_bed, self)
					_reserved_bed = Vector2i(-1, -1)
					_state = State.IDLE
					_clear_path()
				else:
					_state = State.GOING_TO_BED
					_start_path(pbed)
		State.DRAFT_WALK:
			_autonomy_draft_purpose = ""
			_autonomy_draft_peer_id = -1
			_state = State.IDLE
			_clear_path()
		_:
			pass


## Failsafe: if the sim tile is not passable, nudge. Logs once with context.
func sanity_check_impassable_tile() -> void:
	if _world == null or _world.pathfinder == null or data == null:
		return
	if _world.pathfinder.is_passable(data.tile_pos):
		return
	# Nudge will handle logging if needed for debug builds.
	nudge_if_standing_on_solid()


# ==================== per-frame movement ====================

func _process(delta: float) -> void:
	if data == null or GameManager.is_paused:
		return
	
	# PERFORMANCE: Skip movement interpolation if no path
	if _path.is_empty():
		return
	
	# PERFORMANCE: Adaptive visual update rate based on game speed
	# At high speeds, players can't perceive smooth movement anyway
	# But we need to show SOME movement so pawns don't appear frozen
	_visual_frame_counter += 1
	var visual_interval: int = MIN_VISUAL_UPDATE_INTERVAL + int(GameManager.game_speed * 0.15)  # Reduced from 0.4 for better visibility
	var should_update_visuals: bool = (_visual_frame_counter >= visual_interval)
	
	if should_update_visuals:
		_visual_frame_counter = 0
	
	_anim_t += delta * (0.5 + GameManager.game_speed * 0.25)
	
	var step: float = WALK_SPEED_WORLD_UNITS_PER_SEC * delta * GameManager.game_speed * _meaning_speed_multiplier
	# Apply injury mobility penalty
	if not data.injuries.is_empty():
		step *= (1.0 - BodyRiskManager.get_mobility_penalty(data))
	var to_target: Vector2 = _target_world_pos - position

	var old_tile_pos = data.tile_pos # ARCHITECT T006 - Store old position for chunk check
	if to_target.length() <= step:
		position = _target_world_pos
		var from_step: Vector2i = data.tile_pos
		data.tile_pos = _target_tile
		if from_step != _target_tile:
			RoadMemory.record_step(from_step, _target_tile, _world)
		# Record footstep for path wearing and emit dust
		if _world != null and _world.has_method("record_footstep"):
			_world.record_footstep(data.tile_pos)
		_emit_footstep_dust()
		# Wanderer path: track region exploration.
		_track_region_visit(_target_tile)
		_advance_path()
	else:
		position += to_target.normalized() * step

	# ARCHITECT T006: Update SpatialManager if pawn moved to a new chunk
	if SpatialManager != null and data != null and old_tile_pos != data.tile_pos:
		SpatialManager.update_pawn_position(int(data.id), data.tile_pos)

	# PERFORMANCE: Only check knowledge stones when visuals update
	# Knowledge doesn't need to be checked every single frame
	if should_update_visuals and KnowledgeSystem != null and KnowledgeSystem.has_method("read_knowledge_from_stone"):
		var gained: Array = KnowledgeSystem.read_knowledge_from_stone(int(data.id), data.tile_pos)
		if not gained.is_empty():
			# HeelKawnian gained knowledge from reading stone
			pass
	
	# SACRED GEOGRAPHY: Apply reverence slowdown on sacred tiles
	# OPTIMIZATION: Cache SacredGeography reference, only check on tile change
	if data.tile_pos != _last_sacred_check_tile:
		_last_sacred_check_tile = data.tile_pos
		if _sacred_geography_cache == null:
			_sacred_geography_cache = get_node_or_null("/root/SacredGeography")
		if _sacred_geography_cache != null and _sacred_geography_cache.has_method("check_sacred_tile_effect"):
			_sacred_geography_cache.call("check_sacred_tile_effect", self)
	
	# PERFORMANCE: Adaptive redraw throttling
	# At 1x: redraw every 5th frame
	# At 26x: redraw every 12th frame  
	# At 100x: redraw every 25th frame
	# This is the BIGGEST performance win - reduces draw calls by 80-95%
	var redraw_threshold: int = 5 + int(GameManager.game_speed * 0.2)
	_draw_frame_counter += 1
	if _draw_frame_counter >= redraw_threshold:
		_draw_frame_counter = 0
		queue_redraw()


func _start_path(path: Array[Vector2i]) -> void:
	_path = path
	_path_index = 0
	if _path.is_empty():
		_clear_path()
		_on_path_complete()
		return
	_target_tile = _path[0]
	_target_world_pos = _world.tile_to_world(_target_tile)
	set_process(true)  # Enable per-frame movement while pathing


## PERFORMANCE: Get cached path or compute new one
func _get_cached_path(from: Vector2i, to: Vector2i, use_historic: bool = true) -> Array[Vector2i]:
	# Check if we can reuse cached path
	if to == _cached_path_target and GameManager.tick_count - _cached_path_tick < PATH_CACHE_DURATION:
		if not _cached_path.is_empty():
			return _cached_path

	# Need new path
	if use_historic:
		_cached_path = _world.pathfinder.find_path_pawn_historic_aversion(from, to)
	else:
		_cached_path = _world.pathfinder.find_path(from, to)

	_cached_path_target = to
	_cached_path_tick = GameManager.tick_count
	return _cached_path


func _advance_path() -> void:
	_path_index += 1
	if _path_index < _path.size():
		_target_tile = _path[_path_index]
		_target_world_pos = _world.tile_to_world(_target_tile)
		# Update facing direction for sprite rendering
		var next_pos: Vector2 = Vector2(_target_tile.x, _target_tile.y)
		var cur_pos: Vector2 = Vector2(data.tile_pos.x, data.tile_pos.y)
		var diff: Vector2 = (next_pos - cur_pos).normalized()
		if diff.length_squared() > 0.01:
			_facing_dir = diff
	else:
		_clear_path()
		_on_path_complete()


func _clear_path() -> void:
	_path = []
	_path_index = 0
	_target_tile = data.tile_pos if data != null else Vector2i.ZERO
	_target_world_pos = position
	set_process(false)  # No movement needed â€” stop per-frame updates


func _on_path_complete() -> void:
	match _state:
		State.DRAFT_WALK:
			var ap: String = _autonomy_draft_purpose
			var apid: int = _autonomy_draft_peer_id
			_autonomy_draft_purpose = ""
			_autonomy_draft_peer_id = -1
			_state = State.IDLE
			if ap != "":
				_finish_autonomy_draft_walk(ap, apid)
			_request_redraw()
		State.WALKING_TO_JOB:
			if _current_job != null and data.tile_pos == _current_job.work_tile:
				_state = State.WORKING
				_request_redraw()
			else:
				_unclaim_current_job()
		State.HAULING:
			_deposit_at_stockpile()
		State.GOING_TO_EAT:
			_begin_eating()
		State.FETCHING_MATERIAL:
			_arrive_at_stockpile_for_material()
		State.GOING_TO_BED:
			_arrive_at_bed()
		State.IDLE:
			pass


# ==================== per-tick simulation ====================

func _on_world_tick(_tick: int) -> void:
	# CRITICAL: Hard guard: no sim until bind + _ready + deferred connect completed.
	if not is_instance_valid(self):
		return
	if not _pawn_sim_tick_armed:
		# DEBUG: This should not happen after deferred connect runs
		# If it does, the pawn wasn't properly initialized
		return
	if data == null:
		push_warning("HeelKawnian: game_tick skipped - data not ready (path=%s)" % str(get_path()))
		return
	
	# CRITICAL: Dead pawns do NOT process ticks - prevents duplicate deaths, biography spam, legacy duplication
	if data.is_dead:
		return  # HeelKawnian is already dead - skip all processing
	
	## Sync GameManager.tick_count for backward compatibility
	if GameManager != null:
		GameManager.tick_count = _tick
	var pid: int = int(data.id)
	var _trace_ai_slice: bool = CrashTrap.should_trace_game_tick_dispatch(_tick)
	if _hit_flash_ticks > 0:
		_hit_flash_ticks -= 1

	# Stagger needs/threshold upkeep by pawn id so not every pawn runs this
	# bookkeeping on the same sim tick.
	if posmod(GameManager.tick_count + pid, 5) == 0:
		if _trace_ai_slice:
			CrashTrap.enter_system("pawn_tick:%d:needs" % pid)
		apply_body_needs()
		_check_thresholds()
		if _trace_ai_slice:
			CrashTrap.exit_system("pawn_tick:%d:needs" % pid)
	if _state != State.SLEEPING and posmod(GameManager.tick_count + pid * 3, 23) == 0:
		_pawn_neural_autonomy_pulse()
	# Sleepers only need wake checks; skip full AI branch logic to reduce
	# per-tick overhead during overnight "everyone in bed" windows.
	if _state == State.SLEEPING:
		if _trace_ai_slice:
			CrashTrap.enter_system("pawn_tick:%d:sleep" % pid)
		_tick_sleeping()
		if _trace_ai_slice:
			CrashTrap.exit_system("pawn_tick:%d:sleep" % pid)
		return

	if _trace_ai_slice:
		CrashTrap.enter_system("pawn_tick:%d:ai" % pid)
	if _trace_ai_slice:
		CrashTrap.enter_system("pawn_tick:%d:ai:stride" % pid)
	var stride: int = maxi(1, _fast_forward_tick_stride())
	var ai_phase: int = pid
	var run_full_ai: bool = stride <= 1 or (posmod(_tick + ai_phase, stride) == 0)
	if _trace_ai_slice:
		CrashTrap.exit_system("pawn_tick:%d:ai:stride" % pid)
	if run_full_ai:
		if _trace_ai_slice:
			CrashTrap.enter_system("pawn_tick:%d:ai:cohort_draft" % pid)
		# Throttled cohort system calls for performance
		if GameManager.tick_count % COHORT_UPDATE_TICKS == 0:
			update_cohort_membership()
			_validate_or_dissolve_cohort()
			_refresh_or_decay_cohort_stability()
		# Apply meaning-based behavior density modifiers (Phase 4)
		_apply_meaning_behavior_modifiers()
		if draft_mode:
			_engage_enemies()
		if _trace_ai_slice:
			CrashTrap.exit_system("pawn_tick:%d:ai:cohort_draft" % pid)
	# Panic-sleep interrupt: if rest is critically low and we're not already
	# resolving a true emergency (asleep, eating, or fed/in-hand), abandon
	# what we're doing and collapse. Beats the eat/haul cycle that otherwise
	# keeps a pawn busy until rest hits 0.
	if _trace_ai_slice:
		CrashTrap.enter_system("pawn_tick:%d:ai:panic" % pid)
	if _should_panic_sleep():
		_force_panic_sleep()
		if _trace_ai_slice:
			CrashTrap.exit_system("pawn_tick:%d:ai:panic" % pid)
			CrashTrap.exit_system("pawn_tick:%d:ai" % pid)
		return
	if _trace_ai_slice:
		CrashTrap.exit_system("pawn_tick:%d:ai:panic" % pid)
	if not run_full_ai:
		if _trace_ai_slice:
			CrashTrap.enter_system("pawn_tick:%d:ai:throttled_state" % pid)
		match _state:
			State.WORKING:
				_tick_working()
			State.EATING:
				_tick_eating()
			State.SLEEPING:
				_tick_sleeping()
			State.TEACHING:
				_tick_teaching()
			State.CHALLENGE:
				_tick_challenge()
			_:
				pass
		if _trace_ai_slice:
			CrashTrap.exit_system("pawn_tick:%d:ai:throttled_state" % pid)
		if _trace_ai_slice:
			CrashTrap.exit_system("pawn_tick:%d:ai" % pid)
		return
	if _trace_ai_slice:
		CrashTrap.enter_system("pawn_tick:%d:ai:full_state" % pid)
	match _state:
		State.IDLE:
			_tick_idle()
		State.WALKING_TO_JOB:
			if _trace_ai_slice:
				CrashTrap.enter_system("pawn_tick:%d:movement" % pid)
			_tick_walking()
			if _trace_ai_slice:
				CrashTrap.exit_system("pawn_tick:%d:movement" % pid)
		State.WORKING:
			_tick_working()
		State.HAULING, State.GOING_TO_EAT, State.FETCHING_MATERIAL, State.GOING_TO_BED, State.DRAFT_WALK:
			# movement handled in _process; state exits on arrival
			pass
		State.EATING:
			_tick_eating()
		State.SLEEPING:
			_tick_sleeping()
		State.TEACHING:
			_tick_teaching()
		State.CHALLENGE:
			_tick_challenge()
	if _trace_ai_slice:
		CrashTrap.exit_system("pawn_tick:%d:ai:full_state" % pid)
		CrashTrap.exit_system("pawn_tick:%d:ai" % pid)


func _fast_forward_tick_stride() -> int:
	if GameManager == null:
		return 1
	var gs: float = GameManager.game_speed
	## Match toolbar tiers (12 / 26 / 50 / 100): fewer expensive idle/job scans per sim tick.
	if gs >= 100.0:
		return 14
	if gs >= 50.0:
		return 10
	if gs >= 26.0:
		return 8
	if gs >= 12.0:
		return 4
	if gs >= 4.0:
		return 2
	# At baseline play speed, run full AI every tick for responsive behavior.
	return 1


func _job_claim_interval_for_speed() -> int:
	if GameManager == null:
		return 3
	var gs: float = GameManager.game_speed
	if gs >= 100.0:
		return 1  # Claim every tick at 100x - MAXIMUM BUILDING ACTIVITY
	if gs >= 50.0:
		return 1  # Claim every tick at 50x
	if gs >= 26.0:
		return 1  # Claim every tick at 26x
	if gs >= 12.0:
		return 2  # Every 2 ticks at 12x
	if gs >= 3.0:
		return 3  # Every 3 ticks at 3x
	# 1x: claim often enough that pawns feel "busy" without scanning every tick.
	return 3  # Reduced from 4


func _neural_priority_refresh_interval_for_speed() -> int:
	if GameManager == null:
		return 45
	var gs: float = GameManager.game_speed
	if gs >= 100.0:
		return 420
	if gs >= 50.0:
		return 260
	if gs >= 26.0:
		return 180
	if gs >= 12.0:
		return 130
	if gs >= 6.0:
		return 90
	if gs >= 3.0:
		return 60
	return 45


func _idle_action_refresh_interval_for_speed() -> int:
	if GameManager == null:
		return 12
	var gs: float = GameManager.game_speed
	if gs >= 100.0:
		return 180
	if gs >= 50.0:
		return 120
	if gs >= 26.0:
		return 90
	if gs >= 12.0:
		return 60
	if gs >= 6.0:
		return 36
	if gs >= 3.0:
		return 24
	return 12


func _work_step_interval_for_speed() -> int:
	if GameManager == null:
		return 1
	var gs: float = GameManager.game_speed
	# REDUCED intervals - pawns were working too infrequently (1 out of N ticks)
	# At 100x: was 6 (16.7% work rate), now 2 (50% work rate)
	if gs >= 100.0:
		return 2  # Was 6 - pawns work 50% of ticks instead of 16.7%
	if gs >= 50.0:
		return 2  # Was 4
	if gs >= 26.0:
		return 2
	if gs >= 12.0:
		return 2
	if gs >= 3.0:
		return 2
	return 1  # At 1x, every pawn works every tick


func _should_panic_sleep() -> bool:
	if _state == State.SLEEPING:
		return false
	if data.rest > REST_PANIC_THRESHOLD:
		return false
	# Hunger emergency outranks sleep. Better to stagger toward food than nap
	# and wake up dead.
	if data.hunger <= HUNGER_EMERGENCY:
		return false
	# Don't yank a pawn out of an active eating action -- it's only a few ticks
	# and ends naturally; rest can wait that long.
	if _state == State.EATING:
		return false
	return true


## Force the current activity to abort, drop any claimed job back into the
## queue, and lie down. Anything the pawn was carrying stays in their hands;
## they'll deliver it when they wake up.
func _force_panic_sleep() -> void:
	if _state == State.DRAFT_WALK:
		_state = State.IDLE
	if _current_job != null:
		var jp: Job = _current_job
		_return_trade_cargo_to_source_if_any(jp)
		JobManager.abandon(jp)
		_current_job = null
		_clear_cohort_state()
	_clear_path()
	# If we were already walking to a bed when panic hit, give up the
	# reservation so other pawns can use it; we're sleeping where we stand.
	_release_bed_if_reserved()
	# `where` string for logs could be re-added if verbose_logs are re-enabled.
	# var on_bed: bool = _reserved_bed.x >= 0 and data.tile_pos == _reserved_bed
	# var where: String = " in a bed" if on_bed else ""
	# if GameManager.verbose_logs():
	# 	print("[HeelKawnian] %s lies down to sleep%s  (rest=%.1f)" % [data.display_name, where, data.rest])
	_begin_sleeping()


func _tick_idle() -> void:
	if _world == null or _world.pathfinder == null:
		return
	if draft_mode:
		if data.is_carrying():
			if _current_job != null and _current_job.type == _Job.Type.TRADE_HAUL and _current_job.trade_to != null:
				_begin_haul_to_forced_zone(_current_job.trade_to)
			else:
				_begin_haul_to_stockpile()
			return
		if _maybe_start_eating():
			return
		return
	# Priority chain (most urgent first):
	#   1. Starving + holding food          -> eat from hand
	#   2. Holding a non-food item          -> haul to stockpile
	#   3. Hungry + food in stockpile       -> go eat
	#   4. Tired (no food emergency)        -> sleep on the spot
	#   5. Can teach nearby pawn           -> teach knowledge
	#   6. Can challenge authority          -> challenge nearby pawn
	#   7. Open job available               -> claim and walk to it
	#   8. Nothing                          -> small chance to wander

	# 1. Emergency: starving + holding food = eat it right now, no stockpile.
	if data.hunger <= HUNGER_EMERGENCY and data.is_carrying() and Item.is_food(data.carrying):
		_eat_from_hand()
		return
	# 1b. Starving + carrying non-food: drop it and seek food. Hauling can
	# wait â€” survival comes first.
	if data.hunger <= HUNGER_EMERGENCY and data.is_carrying():
		data.clear_carry()
		if _maybe_start_eating():
			return
	# 2. If we're still holding something from a prior task, deliver it first.
	if data.is_carrying():
		if _current_job != null and _current_job.type == _Job.Type.TRADE_HAUL and _current_job.trade_to != null:
			_begin_haul_to_forced_zone(_current_job.trade_to)
		else:
			_begin_haul_to_stockpile()
		return
	# 2a. Periodic gear check: try equipping better gear from stockpile (every 200 ticks)
	if GameManager.tick_count % 200 == int(data.id) % 200:
		if CraftingSystem != null and CraftingSystem.has_method("try_equip_from_stockpile"):
			CraftingSystem.try_equip_from_stockpile(data)
	# 2b. HeelKawnian Matrix social intent: ally-seek, mentor-seek, or confrontation.
	if _try_heelkawnian_matrix_social_action():
		return
	# 2c. Human ladder affiliation: household -> clan -> nation.
	if _try_heelkawnian_affiliation_action():
		return
	# Fallback autonomy paths.
	if _try_autonomy_grudge_confront():
		return
	# 3. Need-driven: hungry + food nearby -> go eat
	if _maybe_start_eating():
		return
	# 4. Tired -> sleep. Skipped if we're starving (food first, sleep when full).
	if _maybe_start_sleeping():
		return
	# 4a. Matrix ambition seed: post one strategic household/settlement job.
	# This does not force movement; it injects world-building work into the queue.
	_try_heelkawnian_matrix_ambition_seed()
	# 4b. Neural "social" hint: path toward a high-rapport nearby pawn if not already eating/sleeping.
	if _try_autonomy_social_seek():
		return
	# 4c. Memorial pilgrimage: occasional desire to visit memorials (closure, remembrance)
	if _try_start_pilgrimage():
		return
	# 4c1. Grave pilgrimage: visit family graves when mood is low
	if _try_grave_pilgrimage():
		return
	# 4d. Dream nudge: dreams can push a pawn to wander, rest, or socialize.
	if _maybe_follow_dream_nudge():
		return
	# Cache global food queries once per tick across all pawns
	var now_tick: int = GameManager.tick_count if GameManager != null else 0
	if now_tick != HeelKawnian._s_food_cache_tick:
		HeelKawnian._s_food_units = StockpileManager.total_food()
		HeelKawnian._s_food_pressure = 0.0
		if ColonySimServices != null:
			HeelKawnian._s_food_pressure = ColonySimServices.get_food_pressure()
		HeelKawnian._s_food_emergency = (
			HeelKawnian._s_food_units <= STOCKPILE_FOOD_CRITICAL_UNITS
			or HeelKawnian._s_food_pressure >= COLONY_FOOD_PRESSURE_FOR_EMERGENCY
		)
		HeelKawnian._s_food_cache_tick = now_tick
	var food_emergency: bool = HeelKawnian._s_food_emergency
	var utility_context: Dictionary = _build_idle_utility_context(food_emergency)
	var available_idle_actions: Array = [
		{"type": "work"},
		{"type": "wander"},
	]
	if data != null:
		available_idle_actions.append({"type": "teach"})
	if data != null:
		available_idle_actions.append({"type": "challenge"})
	if food_emergency:
		available_idle_actions.append({"type": "forage"})
	var preferred_idle_action: String = "work"
	if data != null:
		var should_refresh_idle_action: bool = (
			_next_idle_action_refresh_tick < 0
			or now_tick >= _next_idle_action_refresh_tick
			or _cached_idle_action_food_emergency != food_emergency
		)
		if should_refresh_idle_action:
			var best_idle_action: Dictionary = data.choose_best_action(available_idle_actions, utility_context)
			_cached_idle_action = "work"
			if not best_idle_action.is_empty() and best_idle_action.has("type"):
				_cached_idle_action = str(best_idle_action.get("type", "work"))
			_cached_idle_action_food_emergency = food_emergency
			_next_idle_action_refresh_tick = now_tick + _idle_action_refresh_interval_for_speed()
		preferred_idle_action = _cached_idle_action
	# 5. Social cognition: choose one social action first, then fall back.
	if preferred_idle_action == "teach":
		if _maybe_start_teaching():
			return
	elif preferred_idle_action == "challenge":
		if _maybe_start_challenge():
			return
	else:
		# Keep prior behavior continuity if utility favored non-social actions.
		if _maybe_start_teaching():
			return
		if _maybe_start_challenge():
			return
	# 5b. Warrior peacetime patrol: if this pawn is a WARRIOR and no
	# combat/security jobs are available, path toward a settlement wall
	# and idle there (visible presence, not stuck at stockpile).
	if data != null and data.current_profession == HeelKawnianData.Profession.WARRIOR:
		if _maybe_warrior_patrol():
			return
	# 5c. Cultural exposure: outsiders near custom-tagged regions may adopt customs.
	# Runs every ~100 ticks to stay cheap.
	if data != null and posmod(now_tick + int(data.id), 100) == 0:
		_maybe_absorb_custom()
	# 5d. Knowledge rediscovery: scholars and curious pawns near dormant
	# knowledge sites may rediscover lost knowledge.
	if data != null and posmod(now_tick + int(data.id) * 3, 200) == 0:
		_maybe_attempt_rediscovery()
	# 5e. Diaspora homesickness: exiled pawns periodically check their
	# origin settlement's status. If origin collapsed, grief event.
	if data != null and data._diaspora_origin >= 0 and posmod(now_tick + int(data.id) * 7, 500) == 0:
		_maybe_diaspora_homesickness(now_tick)
	# 6. Job queue: take the best reachable job. We additionally skip build
	# jobs whose required materials aren't on hand at the stockpile -- this
	# prevents pawns from claim/abort looping when wood is empty.
	#
	# Food-emergency override: if the stockpile is almost out of food, do
	# *one* preferential pass restricted to FORAGE jobs, then fall back to the
	# normal filter if no forage is available. Stops the colony from happily
	# mining stone while everyone starves.
	
	# Job claiming is one of the hottest paths at ultra speed; spread claims so
	# not every pawn rescans the full queue on the same tick burst.
	var claim_iv: int = maxi(1, _job_claim_interval_for_speed())
	claim_iv += int(round(_founding_blend() * 2.0))
	var claim_phase: int = 0
	if data != null:
		claim_phase = posmod(int(data.id), claim_iv)
	if posmod(GameManager.tick_count + claim_phase, claim_iv) != 0:
		var wanderlust: float = lerpf(0.52, 1.68, _bp(3))
		var early_wander_chance: float = WANDER_CHANCE_PER_TICK * wanderlust * (1.0 + 0.55 * _founding_blend())
		if preferred_idle_action == "wander":
			early_wander_chance *= 1.7
		if WorldRNG.chance_for(_pawn_stream("idle_wander"), clampf(early_wander_chance, 0.0, 0.35), _pawn_salt(11)):
			_start_wander()
		return
	
	var my_component: int = _world.pathfinder.component_of(data.tile_pos)
	# Treat the whole pantry (berries + meat + any future food) as one number
	# summed across every registered zone. Counting only berries was fine
	# before HUNT existed; now a colony living on hunted meat would have
	# looked like it was starving. And with Phase-10 multi-zone stockpiles
	# we have to sum across zones, not peek at one hardcoded pile.
	var affinity_key: String = data.highest_affinity_skill() if data != null else ""
	var utility_cache: Dictionary = {}
	var utility_bias_cache: Dictionary = {}
	var neural_bias_cache: Dictionary = {}
	var work_tile_component_cache: Dictionary = {}
	var work_tile_region_cache: Dictionary = {}
	var region_scar_cache: Dictionary = {}
	var region_history_offset_cache: Dictionary = {}
	var inherited_history_offset: int = _culture_inherited_job_offset()
	var crisis_housing_pressure: float = 0.0
	var crisis_food_pressure: float = 0.0
	if ColonySimServices != null:
		crisis_housing_pressure = ColonySimServices.get_housing_pressure()
		crisis_food_pressure = ColonySimServices.get_food_pressure()
	var from_region_key: int = _WM._region_key(data.tile_pos.x, data.tile_pos.y)
	var from_center_region: int = SettlementMemory.get_center_region_for_region(from_region_key)
	var from_intent: int = int(IntentMemory.settlement_intent.get(from_center_region, IntentMemory.INTENT_HOLD))
	var from_pressure: float = float(IntentMemory.settlement_pressure.get(from_center_region, 0.5))
	var scar_priority_for_level: Dictionary = {0: 0, 1: -5, 2: -24}
	
	var resolve_region_key_for_work_tile: Callable = func(work_tile: Vector2i) -> int:
		if work_tile_region_cache.has(work_tile):
			return int(work_tile_region_cache[work_tile])
		var rk: int = _WM._region_key(work_tile.x, work_tile.y)
		work_tile_region_cache[work_tile] = rk
		return rk
	
	var resolve_component_for_work_tile: Callable = func(work_tile: Vector2i) -> int:
		if work_tile_component_cache.has(work_tile):
			return int(work_tile_component_cache[work_tile])
		var comp: int = _world.pathfinder.component_of(work_tile)
		work_tile_component_cache[work_tile] = comp
		return comp
	
	var resolve_region_scar_level: Callable = func(region_key: int) -> int:
		if region_scar_cache.has(region_key):
			return int(region_scar_cache[region_key])
		var sl: int = int(WorldPersistence.get_region_scar_level(region_key))
		region_scar_cache[region_key] = sl
		return sl
	
	var resolve_history_offset_for_region: Callable = func(region_key: int) -> int:
		if region_history_offset_cache.has(region_key):
			return int(region_history_offset_cache[region_key])
		var scar_level: int = int(resolve_region_scar_level.call(region_key))
		var scar_offset: int = int(scar_priority_for_level.get(scar_level, 0))
		var to_center: int = SettlementMemory.get_center_region_for_region(region_key)
		var intent_delta: int = 0
		if not (from_center_region < 0 and to_center < 0):
			var to_intent: int = int(IntentMemory.settlement_intent.get(to_center, IntentMemory.INTENT_HOLD))
			var to_pressure: float = float(IntentMemory.settlement_pressure.get(to_center, 0.5))
			if to_intent == IntentMemory.INTENT_GROW:
				intent_delta += 3
			elif to_intent == IntentMemory.INTENT_ABANDON:
				intent_delta -= 4
			if to_pressure < from_pressure:
				intent_delta += 1
			elif to_pressure > from_pressure + 0.12:
				intent_delta -= 1
			if from_intent == IntentMemory.INTENT_ABANDON and to_intent != IntentMemory.INTENT_ABANDON:
				intent_delta += 2
			elif from_intent != IntentMemory.INTENT_ABANDON and to_intent == IntentMemory.INTENT_ABANDON:
				intent_delta -= 2
		var history_offset: int = scar_offset + inherited_history_offset + intent_delta
		region_history_offset_cache[region_key] = history_offset
		return history_offset

	# Simplified priority calculation for performance; affinity is a small nudge â€” not a separate queue pass â€” so build/mining jobs can compete with forage.
	var priority_cb: Callable = func(j: Job) -> int:
		var base_bias: int = int(ColonySimServices.job_priority_stance_bias(j))
		if not is_job_history_critical(j.type):
			var rk_hist: int = int(resolve_region_key_for_work_tile.call(j.work_tile))
			base_bias += int(resolve_history_offset_for_region.call(rk_hist))
		if affinity_key != "" and _job_matches_affinity(j.type, affinity_key):
			base_bias += AFFINITY_JOB_PRIORITY_BONUS
		# Profession-specific job priority: pawns strongly prefer jobs matching their role
		if data.current_profession != HeelKawnianData.Profession.NONE:
			var prof: int = data.current_profession
			match prof:
				HeelKawnianData.Profession.FARMER:
					if j.type == _Job.Type.FORAGE or j.type == _Job.Type.PLANT_SEEDS or j.type == _Job.Type.HARVEST_CROPS:
						base_bias += 5
				HeelKawnianData.Profession.BUILDER:
					if _is_structure_build_job(j.type):
						base_bias += 5
				HeelKawnianData.Profession.GATHERER:
					if j.type == _Job.Type.FORAGE or j.type == _Job.Type.CHOP or j.type == _Job.Type.GATHER_FLINT or j.type == _Job.Type.GATHER_STICK:
						base_bias += 5
				HeelKawnianData.Profession.WARRIOR:
					if j.type == _Job.Type.HUNT or j.type == _Job.Type.PROTECT or j.type == _Job.Type.DEFEND:
						base_bias += 5
				HeelKawnianData.Profession.SCHOLAR:
					if j.type == _Job.Type.TEACH_SKILL or j.type == _Job.Type.APPRENTICESHIP:
						base_bias += 5
		var action_key: String = _utility_action_for_job(int(j.type))
		var utility_bias: int = 0
		if utility_bias_cache.has(action_key):
			utility_bias = int(utility_bias_cache[action_key])
		else:
			utility_bias = int(round((_utility_score_normalized(action_key, utility_context, utility_cache) - 0.5) * float(UTILITY_JOB_PRIORITY_BIAS_RANGE)))
			utility_bias_cache[action_key] = utility_bias
		base_bias += utility_bias
		base_bias += data.kinship_job_priority_bonus(j.work_tile)
		if preferred_idle_action == "forage" and (j.type == _Job.Type.FORAGE or j.type == _Job.Type.HUNT or j.type == _Job.Type.FISH):
			base_bias += 2
		# When the pantry is not in emergency, nudge non-food labor so the colony
		# visibly diversifies (stone, wood, planned builds) instead of idle wandering.
		# OPTIMIZATION: Strong bias toward BUILD jobs to get settlement started
		if not food_emergency:
			match int(j.type):
				_Job.Type.MINE, _Job.Type.MINE_WALL, _Job.Type.CHOP:
					base_bias += 3  # Increased from 2
				_Job.Type.BUILD_BED, _Job.Type.BUILD_WALL, _Job.Type.BUILD_DOOR, _Job.Type.BUILD_FIRE_PIT, _Job.Type.BUILD_STORAGE_HUT, _Job.Type.BUILD_SHELTER, _Job.Type.BUILD_HEARTH, _Job.Type.BUILD_MARKER_STONE, _Job.Type.BUILD_SHRINE, \
				_Job.Type.BUILD_FARM_WHEAT, _Job.Type.BUILD_FARM_CORN, _Job.Type.BUILD_FARM_VEGETABLES, _Job.Type.BUILD_HERB_GARDEN, \
				_Job.Type.BUILD_WORKSHOP, _Job.Type.BUILD_LOOM, _Job.Type.BUILD_KILN, _Job.Type.BUILD_SMELTER, \
				_Job.Type.BUILD_BOATYARD, _Job.Type.BUILD_DOCK, _Job.Type.BUILD_FISHERMAN_HUT, \
				_Job.Type.BUILD_APOTHECARY, _Job.Type.BUILD_LIBRARY, _Job.Type.BUILD_SCHOOL, \
				_Job.Type.BUILD_BARRACKS, _Job.Type.BUILD_WATCHTOWER, \
				_Job.Type.BUILD_MARKET, _Job.Type.BUILD_TRADING_POST, _Job.Type.BUILD_ROAD, \
				_Job.Type.BUILD_GRANARY, _Job.Type.BUILD_CELLAR, \
				_Job.Type.BUILD_FORD, _Job.Type.BUILD_WATER_MILL:
					base_bias += 6  # Strong priority for all building jobs
				_Job.Type.FORAGE, _Job.Type.HUNT, _Job.Type.FISH:
					base_bias -= 1  # Slightly deprioritize foraging when not starving

		# Crisis priority bonus (snapshot pressures once per claim pass).
		# Boost BUILD_BED jobs during housing crisis
		if crisis_housing_pressure > 0.8 and j.type == _Job.Type.BUILD_BED:
			base_bias += 8
		# Boost FIRE_PIT when warmth is scarce
		if j.type == _Job.Type.BUILD_FIRE_PIT and crisis_housing_pressure > 0.5:
			base_bias += 3
		# Boost FORAGE/HUNT jobs during food crisis
		if crisis_food_pressure > 0.7 and (j.type == _Job.Type.FORAGE or j.type == _Job.Type.HUNT or j.type == _Job.Type.FISH):
			base_bias += 4
		# Leader proximity bonus: if the settlement ruler is nearby and this
		# is a build job, the pawn gets +3 priority (leader directs construction)
		if _is_structure_build_job(j.type):
			var my_sid: int = SettlementMemory.get_settlement_id_for_pawn(int(data.id))
			if my_sid >= 0:
				var ruler_id: int = SettlementMemory.get_ruler_pawn_id(my_sid)
				if ruler_id >= 0 and ruler_id != int(data.id):
					var ruler_data: HeelKawnianData = HeelKawnianManager._pawn_data_for_id(ruler_id)
					if ruler_data != null:
						var dist_to_ruler: int = absi(data.tile_pos.x - ruler_data.tile_pos.x) + absi(data.tile_pos.y - ruler_data.tile_pos.y)
						if dist_to_ruler <= 12:
							base_bias += 3

		# Neural AI priority bonus from WorldAI matrix (once per job type/tick).
		var neural_bias: int = 0
		if neural_bias_cache.has(j.type):
			neural_bias = int(neural_bias_cache[j.type])
		else:
			neural_bias = _get_neural_job_priority_bias(j.type)
			neural_bias_cache[j.type] = neural_bias
		base_bias += neural_bias
		base_bias += _get_heelkawnian_matrix_job_bias(j.type)
		# World-memory-driven job bias: meaning tags at the job's work tile
		# shape whether pawns want to work there.
		var meaning_bias: int = 0
		var job_rk: int = int(resolve_region_key_for_work_tile.call(j.work_tile))
		var job_tags: PackedStringArray = WorldMeaning.get_region_tags(job_rk)
		for _mt in job_tags:
			match _mt:
				"repeated_death", "blood_soaked", "graveyard":
					meaning_bias -= 2  # avoid death places
				"cursed":
					meaning_bias -= 3  # strongly avoid cursed places
				# Myth formation: ancient danger is feared more
				"old_death_place":
					meaning_bias -= 3
				"ancient_death_place":
					meaning_bias -= 4
				"old_famine":
					meaning_bias -= 2
				"ancient_famine":
					meaning_bias -= 3
				"famine_stricken", "hunger_place":
					# Hunger memory: food jobs are urgent here, others avoid
					if j.type == _Job.Type.FORAGE or j.type == _Job.Type.HUNT or j.type == _Job.Type.FISH:
						meaning_bias += 2
					else:
						meaning_bias -= 1
				"fire_prone":
					if j.type == _Job.Type.BUILD_BED or j.type == _Job.Type.BUILD_WALL:
						meaning_bias -= 1  # don't build where fire keeps happening
				"safe_hearth", "fertile":
					meaning_bias += 1  # prefer working in safe/fertile regions
				# Myth formation: ancient safety is revered
				"old_heart":
					meaning_bias += 2
				"ancient_heart":
					meaning_bias += 3
				"learned", "educated":
					if j.type == _Job.Type.TEACH_SKILL or j.type == _Job.Type.APPRENTICESHIP:
						meaning_bias += 2  # teach where knowledge already lives
				# Myth formation: ancient wisdom draws scholars
				"old_wisdom":
					if j.type == _Job.Type.TEACH_SKILL or j.type == _Job.Type.APPRENTICESHIP:
						meaning_bias += 3
				"ancient_wisdom":
					if j.type == _Job.Type.TEACH_SKILL or j.type == _Job.Type.APPRENTICESHIP:
						meaning_bias += 4
				"ruined":
					if j.type == _Job.Type.BUILD_BED or j.type == _Job.Type.BUILD_WALL:
						meaning_bias += 1  # rebuild ruined places
				# Ritual Echo System: custom tags from repeated actions
				"burial_grove":
					# Respect burial sites â€” don't build here, but defend them
					if j.type == _Job.Type.BUILD_BED or j.type == _Job.Type.BUILD_WALL:
						meaning_bias -= 2  # violation tension
					if j.type == _Job.Type.DEFEND or j.type == _Job.Type.PROTECT:
						meaning_bias += 2  # guard the sacred dead
				"faded_burial_grove":
					if j.type == _Job.Type.BUILD_BED or j.type == _Job.Type.BUILD_WALL:
						meaning_bias -= 1  # mild violation tension
				"teaching_ground":
					if j.type == _Job.Type.TEACH_SKILL or j.type == _Job.Type.APPRENTICESHIP:
						meaning_bias += 3  # teach where teaching is customary
				"faded_teaching_ground":
					if j.type == _Job.Type.TEACH_SKILL or j.type == _Job.Type.APPRENTICESHIP:
						meaning_bias += 1  # faint echo of teaching custom
				"feast_ground":
					if j.type == _Job.Type.FORAGE or j.type == _Job.Type.HUNT or j.type == _Job.Type.FISH:
						meaning_bias += 2  # food gathering where feasts happen
				"faded_feast_ground":
					if j.type == _Job.Type.FORAGE or j.type == _Job.Type.HUNT or j.type == _Job.Type.FISH:
						meaning_bias += 1
				"builder_yard":
					if j.type == _Job.Type.BUILD_BED or j.type == _Job.Type.BUILD_WALL or j.type == _Job.Type.BUILD_DOOR:
						meaning_bias += 2  # build where building is customary
				"faded_builder_yard":
					if j.type == _Job.Type.BUILD_BED or j.type == _Job.Type.BUILD_WALL:
						meaning_bias += 1
				"gathering_place":
					meaning_bias += 1  # generally prefer working where people gather
					if j.type == _Job.Type.TEACH_SKILL or j.type == _Job.Type.APPRENTICESHIP:
						meaning_bias += 1  # knowledge exchange at crossroads
				"faded_gathering_place":
					meaning_bias += 1  # faint echo of community
				# New meaning pipeline tags: craft, authority, trade, conflict, legacy, culture
				"craftsman_quarter":
					meaning_bias += 2  # work where craft lives
					if j.type == _Job.Type.BUILD_BED or j.type == _Job.Type.BUILD_WALL or j.type == _Job.Type.BUILD_DOOR:
						meaning_bias += 2  # build in craft district
				"industrial":
					meaning_bias += 1  # mild work preference
				"forge_echo":
					meaning_bias += 2  # work where forging is customary
				"faded_forge_echo":
					meaning_bias += 1
				"governed":
					meaning_bias += 1  # stability attracts work
				"seat_of_power":
					meaning_bias += 2  # authority center
					if j.type == _Job.Type.DEFEND or j.type == _Job.Type.PROTECT:
						meaning_bias += 2  # defend the seat of power
				"trading_post":
					meaning_bias += 1  # trade attracts foragers
					if j.type == _Job.Type.FORAGE:
						meaning_bias += 2
				"merchant_quarter":
					meaning_bias += 2  # strong trade center
				"market_echo":
					meaning_bias += 1  # faint market memory
				"faded_market_echo":
					meaning_bias += 1
				"war_torn":
					meaning_bias -= 3  # avoid war zones
					if j.type == _Job.Type.DEFEND or j.type == _Job.Type.PROTECT:
						meaning_bias += 3  # but warriors go where war is
				"grudge_haunted":
					meaning_bias -= 1  # mild unease
				"war_echo":
					meaning_bias -= 2  # residual danger
					if j.type == _Job.Type.DEFEND:
						meaning_bias += 2
				"faded_war_echo":
					meaning_bias -= 1
				"dangerous_ground":
					meaning_bias -= 2  # avoid injury places
				"blood_stained":
					meaning_bias -= 1
				"storied":
					meaning_bias += 1  # history attracts
				"ancient_lineage":
					meaning_bias += 2  # deep history
				"sacred":
					meaning_bias += 1  # sacred places attract
					if j.type == _Job.Type.TEACH_SKILL:
						meaning_bias += 2  # teach at sacred sites
				"hallowed":
					meaning_bias += 2  # deeply sacred
				"sanctuary_echo":
					meaning_bias += 2  # active sanctuary
				"faded_sanctuary_echo":
					meaning_bias += 1
				# Myth-amplified tags
				"old_forge":
					meaning_bias += 1  # historic workshop
				"ancient_forge":
					meaning_bias += 2  # legendary workshop
				"old_throne":
					meaning_bias += 1  # former power
				"ancient_throne":
					meaning_bias += 2  # mythic power
				"old_battleground":
					meaning_bias -= 2
					if j.type == _Job.Type.DEFEND:
						meaning_bias += 2
				"ancient_battleground":
					meaning_bias -= 3
					if j.type == _Job.Type.DEFEND:
						meaning_bias += 3
				"old_sanctuary":
					meaning_bias += 1
				"ancient_sanctuary":
					meaning_bias += 2
				"old_market":
					meaning_bias += 1
				"ancient_market":
					meaning_bias += 2
				"world_touched":
					meaning_bias += 1  # world events leave marks
		base_bias += meaning_bias
		# Player zone designation bias: jobs in designated zones get priority
		var zone_bias: int = 0
		var job_tile: Vector2i = j.work_tile
		if ZoneRegistry.tile_in_zone_type(job_tile, ZoneRegistry.ZoneType.FORAGE):
			if j.type == _Job.Type.FORAGE or j.type == _Job.Type.HUNT or j.type == _Job.Type.PLANT_SEEDS or j.type == _Job.Type.HARVEST_CROPS or j.type == _Job.Type.FISH:
				zone_bias += 6
		if ZoneRegistry.tile_in_zone_type(job_tile, ZoneRegistry.ZoneType.BUILD):
			if j.type == _Job.Type.BUILD_BED or j.type == _Job.Type.BUILD_WALL or j.type == _Job.Type.BUILD_DOOR or j.type == _Job.Type.BUILD_FIRE_PIT or j.type == _Job.Type.BUILD_STORAGE_HUT or j.type == _Job.Type.BUILD_SHELTER or j.type == _Job.Type.BUILD_HEARTH:
				zone_bias += 6
		if ZoneRegistry.tile_in_zone_type(job_tile, ZoneRegistry.ZoneType.DEFEND):
			if j.type == _Job.Type.DEFEND or j.type == _Job.Type.PROTECT:
				zone_bias += 6
		if ZoneRegistry.tile_in_zone_type(job_tile, ZoneRegistry.ZoneType.TERRITORY):
			# Territory zones: pawns prefer building and working inside their own territory
			if j.type == _Job.Type.BUILD_BED or j.type == _Job.Type.BUILD_WALL or j.type == _Job.Type.BUILD_DOOR or j.type == _Job.Type.BUILD_FIRE_PIT or j.type == _Job.Type.BUILD_STORAGE_HUT or j.type == _Job.Type.BUILD_SHELTER or j.type == _Job.Type.BUILD_HEARTH or j.type == _Job.Type.FORAGE or j.type == _Job.Type.CHOP or j.type == _Job.Type.MINE or j.type == _Job.Type.MINE_WALL:
				zone_bias += 4
		base_bias += zone_bias
		# Personal whim: same queue, slightly different ordering per pawn (still deterministic).
		base_bias += clampi(int(floor((_bp(5) - 0.5) * 6.0)), -2, 2)

		# Keep bias math cheap and deterministic on hot claim path.
		return AuthoritySystem.apply_authority_bonus(base_bias, int(data.id))
	var base_passes: Callable = func(j: Job) -> bool:
		if HeelKawnian._world_hunt_stabilization_blocks() and j.type == _Job.Type.HUNT:
			return false
		if not data.allows_job_type(j.type):
			return false

		# TOOL REQUIREMENT CHECK - lenient: pawns can work without tools, just slower
		# Only block if pawn TRULY can't do the job (e.g., no hands, incapacitated)
		# Removed hard block - pawns will work with bare hands if needed

		var rk_filter: int = int(resolve_region_key_for_work_tile.call(j.work_tile))
		if not is_job_history_critical(j.type):
			if int(resolve_region_scar_level.call(rk_filter)) >= 3:
				return false
		if int(resolve_component_for_work_tile.call(j.work_tile)) != my_component:
			return false
		var mats: Dictionary = _materials_for_build(j.type)
		if not mats.is_empty():
			# Any zone with the material is fine -- the pawn will walk to
			# the closest one in _begin_fetching_material.
			if StockpileManager.total_count_of(mats.item) < mats.qty:
				return false
		# === Check cultural style material availability ===
		if not mats.is_empty():
			var settlement_id: int = int(from_center_region) if from_center_region >= 0 else -1
			if settlement_id >= 0 and CulturalStyleManager != null:
				var style_material: int = int(CulturalStyleManager.call("get_build_material_for_settlement", settlement_id, j.type))
				if style_material != mats.item:
					# Check if we have the style-specific material instead
					if StockpileManager.total_count_of(style_material) < mats.qty:
						return false
		# === End style material check ===
		# === CHECK TECH REQUIREMENT ===
		# Only allow job claiming if the settlement has researched required technology
		if TechnologySystem != null:
			var settle_center: int = int(from_center_region)
			if settle_center >= 0:
				if not bool(TechnologySystem.call("can_settle_perform_job_type", settle_center, int(j.type))):
					return false
		# === END TECH CHECK ===
		return true
	if food_emergency:
		# Either harvest type fills the pantry; let pawns pick whichever is
		# nearest by deferring to JobManager's distance tiebreak. `base_passes`
		# already enforces per-pawn work toggles (work_forage / work_hunt).
		var food_only: Callable = func(j: Job) -> bool:
			if HeelKawnian._world_hunt_stabilization_blocks() and j.type == _Job.Type.HUNT:
				return false
			if j.type != _Job.Type.FORAGE and j.type != _Job.Type.HUNT and j.type != _Job.Type.FISH:
				return false
			return base_passes.call(j)
		var food_job: Job = JobManager.claim_next_for(self, food_only, priority_cb)
		if food_job != null:
			_begin_job(food_job)
			return
	# PROFESSION PRIORITY: Builders prioritize build jobs, Warriors prioritize hunt/combat
	var profession_bonus: Callable = _get_profession_priority_bonus
	var job: Job = JobManager.claim_next_for(self, base_passes, _merge_priority_callbacks(priority_cb, profession_bonus))
	if job != null:
		_begin_job(job)

		# LOG COMMUNICATION: Announce work to nearby pawns
		if data != null and PawnCommunicationLog != null:
			PawnCommunicationLog.log_work_announcement(
				int(data.id),
				data.display_name,
				job.type,
				job.work_tile,
				"Priority: %d" % job.priority
			)

		# SHOW CHATTER BUBBLE: Visible speech bubble above pawn
		if data != null and PawnChatterBubbles != null:
			PawnChatterBubbles.show_work_bubble(int(data.id), self, job.type)

		return
	# 7. Nothing to do: idle wander
	var wanderlust2: float = lerpf(0.52, 1.68, _bp(3))
	var wander_score: float = _utility_score_normalized("wander", utility_context)
	var wander_chance: float = WANDER_CHANCE_PER_TICK * wanderlust2 * (1.0 + maxf(0.0, wander_score - UTILITY_WANDER_THRESHOLD))
	if preferred_idle_action == "wander":
		wander_chance *= 1.6
	if WorldRNG.chance_for(_pawn_stream("idle_wander"), clampf(wander_chance, 0.0, 0.35), _pawn_salt(11)):
		_start_wander()


func _parity_idle_context() -> Dictionary:
	var t: int = GameManager.tick_count if GameManager != null else 0
	if _parity_context_tick == t and not _parity_context.is_empty():
		return _parity_context
	_parity_context_tick = t
	_parity_context = {}
	if data != null and WorldAI != null and WorldAI.has_method("build_idle_parity_context_for_pawn"):
		_parity_context = WorldAI.build_idle_parity_context_for_pawn(int(data.id))
	return _parity_context


func _build_idle_utility_context(food_emergency: bool) -> Dictionary:
	var t: int = GameManager.tick_count if GameManager != null else 0
	if t == _cached_utility_context_tick and food_emergency == _cached_utility_food_emergency and not _cached_utility_context.is_empty():
		return _cached_utility_context
	var weather: String = "clear"
	if WorldAI != null and WorldAI.has_method("get_weather_tag_for_sim"):
		weather = WorldAI.get_weather_tag_for_sim()
	var pc: Dictionary = _parity_idle_context()
	var parity_utility: Dictionary = {}
	if pc.has("utility_bias") and pc["utility_bias"] is Dictionary:
		parity_utility = pc["utility_bias"] as Dictionary
	if pc.has("weather"):
		weather = str(pc["weather"])
	_cached_utility_context = {
		"is_night": DayNightCycle.is_night_for_tick(t),
		"weather": weather,
		"resources_available": JobManager.open_count() > 0,
		"danger_level": _idle_danger_level(),
		"settlement_pressure": _idle_settlement_pressure(),
		"role_affinity": _idle_role_affinity(),
		"memory_confidence": _idle_memory_confidence(),
		"food_emergency": food_emergency,
		"parity_utility": parity_utility,
	}
	_cached_utility_context_tick = t
	_cached_utility_food_emergency = food_emergency
	return _cached_utility_context


func _idle_settlement_pressure() -> float:
	if data == null:
		return 0.5
	var rk: int = _WM._region_key(data.tile_pos.x, data.tile_pos.y)
	var center_region: int = SettlementMemory.get_center_region_for_region(rk)
	if center_region < 0:
		return 0.5
	return clampf(float(IntentMemory.settlement_pressure.get(center_region, 0.5)), 0.0, 1.0)


func _idle_role_affinity() -> float:
	if data == null:
		return 0.5
	var affinity_key: String = data.highest_affinity_skill()
	return clampf(float(data.affinities.get(affinity_key, 0.5)), 0.0, 1.0)


func _idle_memory_confidence() -> float:
	if data == null:
		return 0.5
	var keys: Array[String] = [
		"action_success:work",
		"action_success:forage",
		"action_success:hunt",
		"action_success:build",
		"action_success:trade",
		"action_success:teach",
	]
	var total: float = 0.0
	var count: int = 0
	for key in keys:
		var fact: Dictionary = data.recall_semantic_fact(key)
		if fact.is_empty():
			continue
		total += clampf(float(fact.get("confidence", 0.5)), 0.0, 1.0)
		count += 1
	if count <= 0:
		return 0.5
	return total / float(count)


func _idle_danger_level() -> float:
	if data == null:
		return 0.0
	var scar_danger: float = clampf(float(_scar_level_at_tile(data.tile_pos)) / 3.0, 0.0, 1.0)
	var tile_key: String = "%d,%d" % [data.tile_pos.x, data.tile_pos.y]
	var memory_danger: float = 0.0
	if data.location_memory.has(tile_key):
		var mem: Dictionary = data.location_memory[tile_key]
		memory_danger = clampf(float(mem.get("danger_level", 0.0)), 0.0, 1.0)
	return maxf(scar_danger, memory_danger)


func _utility_action_for_job(job_type: int) -> String:
	match job_type:
		_Job.Type.FORAGE:
			return "forage"
		_Job.Type.HUNT:
			return "hunt"
		_Job.Type.FISH:
			return "forage"
		_Job.Type.CHOP:
			return "gather"
		_Job.Type.MINE, _Job.Type.MINE_WALL:
			return "mine"
		_Job.Type.BUILD_BED, _Job.Type.BUILD_WALL, _Job.Type.BUILD_DOOR, _Job.Type.BUILD_SHELTER, _Job.Type.BUILD_HEARTH, _Job.Type.BUILD_FIRE_PIT, _Job.Type.BUILD_STORAGE_HUT, _Job.Type.BUILD_MARKER_STONE, _Job.Type.BUILD_SHRINE:
			return "build"
		_Job.Type.TRADE_HAUL:
			return "trade"
		_:
			return "work"


func _utility_score_normalized(action_type: String, context: Dictionary, cache: Dictionary = {}) -> float:
	if data == null:
		return 0.5
	if cache.has(action_type):
		return float(cache[action_type])
	var raw_score: float = data.calculate_action_utility(action_type, context)
	var normalized: float = clampf(raw_score / UTILITY_SCORE_NORMALIZER, 0.0, 1.0)
	cache[action_type] = normalized
	return normalized


func _job_matches_affinity(job_type: int, affinity_key: String) -> bool:
	match affinity_key:
		"building":
			return job_type == _Job.Type.BUILD_BED or job_type == _Job.Type.BUILD_WALL or job_type == _Job.Type.BUILD_DOOR
		"farming":
			return job_type == _Job.Type.FORAGE or job_type == _Job.Type.CHOP  # Chop supports farming
		"combat":
			return job_type == _Job.Type.HUNT
		"crafting":
			return job_type == _Job.Type.CHOP or job_type == _Job.Type.MINE or job_type == _Job.Type.MINE_WALL
		"diplomacy":
			return job_type == _Job.Type.TRADE_HAUL
		"gathering":
			return job_type == _Job.Type.FORAGE or job_type == _Job.Type.CHOP or job_type == _Job.Type.MINE
		"construction":
			return job_type == _Job.Type.BUILD_BED or job_type == _Job.Type.BUILD_WALL or job_type == _Job.Type.BUILD_DOOR or job_type == _Job.Type.BUILD_FIRE_PIT or job_type == _Job.Type.BUILD_STORAGE_HUT or job_type == _Job.Type.BUILD_SHELTER or job_type == _Job.Type.BUILD_HEARTH or job_type == _Job.Type.MINE_WALL
		_:
			return false


func get_settlement_intent_job_multiplier(job: Job) -> float:
	if data == null or job == null:
		return 1.0
	var intent: String = SettlementMemory.get_settlement_intent_for_tile(data.tile_pos)
	match intent:
		SettlementMemory.INTENT_HOARD:
			if job.type == _Job.Type.FORAGE or job.type == _Job.Type.HUNT or job.type == _Job.Type.FISH or job.type == _Job.Type.TRADE_HAUL:
				return 1.2
			if job.type == _Job.Type.CHOP or job.type == _Job.Type.MINE or job.type == _Job.Type.MINE_WALL:
				return 1.05
		SettlementMemory.INTENT_DEFEND:
			if job.type == _Job.Type.HUNT:
				return 1.2
			if job.type == _Job.Type.BUILD_WALL or job.type == _Job.Type.BUILD_DOOR:
				return 1.1
		SettlementMemory.INTENT_RECOVER:
			if job.type == _Job.Type.BUILD_BED or job.type == _Job.Type.BUILD_WALL or job.type == _Job.Type.BUILD_DOOR or job.type == _Job.Type.BUILD_FIRE_PIT or job.type == _Job.Type.BUILD_SHELTER or job.type == _Job.Type.BUILD_HEARTH:
				return 1.15
			if job.type == _Job.Type.TRADE_HAUL:
				return 1.1
		SettlementMemory.INTENT_GROW:
			if job.type == _Job.Type.FORAGE or job.type == _Job.Type.CHOP:
				return 1.05
	return 1.0


func get_preferred_front_bias(job: Job) -> float:
	if data == null or job == null:
		return 1.0
	return float(SettlementMemory.get_preferred_front_bias_for_job(data.tile_pos, job))


## Get neural AI priority bias from WorldAI matrix for job selection
## Returns an integer bias bonus based on the pawn's neural state
func _get_neural_job_priority_bias(job_type: int) -> int:
	if data == null:
		return 0
	if GameManager != null:
		# Startup and extreme fast-forward prioritize frame pacing over
		# per-claim neural nuance. Neural bias returns automatically later.
		if GameManager.tick_count < 1200:
			return 0
		if GameManager.game_speed >= 200.0:
			return 0
	var tick: int = GameManager.tick_count if GameManager != null else -1
	var should_refresh: bool = (_neural_priority_next_refresh_tick < 0 or tick >= _neural_priority_next_refresh_tick)
	if should_refresh:
		_neural_priority_fetch_tick = tick
		var refreshed_outputs: Array = []
		var world_ai: Node = get_node_or_null("/root/WorldAI")
		if world_ai != null and world_ai.has_method("get_pawn_neural_state"):
			var neural_state: Dictionary = world_ai.get_pawn_neural_state(int(data.id))
			if not neural_state.is_empty():
				var outs: Variant = neural_state.get("outputs", [])
				if outs is Array and (outs as Array).size() >= 8:
					refreshed_outputs = outs as Array
		if refreshed_outputs.size() >= 8:
			_neural_priority_outputs = refreshed_outputs
			_neural_priority_next_refresh_tick = tick + _neural_priority_refresh_interval_for_speed()
		else:
			# Failed fetch: retry soon, but do not thrash every tick.
			_neural_priority_next_refresh_tick = tick + 10
	
	if _neural_priority_outputs.size() < 8:
		return 0
	var outputs: Array = _neural_priority_outputs
	
	# Map job types to neural output indices
	# Outputs: [Seek_Food, Seek_Rest, Seek_Social, Work_Forage, Work_Build, Work_Mine, Defend, Idle]
	var neural_bias: int = 0
	
	match job_type:
		_Job.Type.FORAGE:
			# Combine Seek_Food (0) and Work_Forage (3)
			neural_bias = int((outputs[0] + outputs[3]) * 6.0)
		_Job.Type.HUNT:
			# Similar to forage but more combat-oriented
			neural_bias = int((outputs[0] + outputs[3] + outputs[6]) * 5.0)
		_Job.Type.FISH:
			# Food gathering from rivers
			neural_bias = int((outputs[0] + outputs[3]) * 5.0)
		_Job.Type.CHOP:
			# Work-related
			neural_bias = int(outputs[3] * 4.0)
		_Job.Type.MINE, _Job.Type.MINE_WALL:
			# Work_Mine (5)
			neural_bias = int(outputs[5] * 4.0)
		_Job.Type.BUILD_BED, _Job.Type.BUILD_WALL, _Job.Type.BUILD_DOOR, _Job.Type.BUILD_FIRE_PIT, _Job.Type.BUILD_STORAGE_HUT, _Job.Type.BUILD_SHELTER, _Job.Type.BUILD_HEARTH, _Job.Type.BUILD_MARKER_STONE, _Job.Type.BUILD_SHRINE:
			# Work_Build (4)
			neural_bias = int(outputs[4] * 5.0)
		_Job.Type.TRADE_HAUL:
			# Social/economic
			neural_bias = int((outputs[2] + outputs[3]) * 3.0)
		_:
			neural_bias = 0
	
	# Log unusual neural-driven decisions to WorldMemory
	if neural_bias >= 4 and _should_log_neural_decision_tick(tick):
		_log_neural_decision(job_type, neural_bias, outputs)
	
	return neural_bias


## HeelKawnian Matrix AI priority bias. This is the "sprite soul" layer:
## survival, memory, learned traits, phase, and era nudge the pawn toward
## work that fits its current development drive.
func _get_heelkawnian_matrix_job_bias(job_type: int) -> int:
	if data == null:
		return 0
	if GameManager != null:
		if GameManager.tick_count < 300:
			return 0
		if GameManager.game_speed >= 200.0:
			return 0
	var tick: int = GameManager.tick_count if GameManager != null else -1
	if _matrix_priority_fetch_tick != tick:
		_matrix_priority_fetch_tick = tick
		_matrix_priority_decision = HeelKawnianManager.get_matrix_decision_for_pawn(self)
	if _matrix_priority_decision.is_empty():
		return 0
	var biases: Dictionary = _matrix_priority_decision.get("job_biases", {})
	return clampi(int(biases.get(int(job_type), 0)), -8, 16)


func _should_log_neural_decision_tick(tick: int) -> bool:
	if GameManager == null or not GameManager.verbose_logs():
		return false
	if tick - _last_neural_decision_log_tick < 120:
		return false
	_last_neural_decision_log_tick = tick
	return true


## Log neural-driven decisions to WorldMemory for analysis
func _log_neural_decision(job_type: int, bias: int, outputs: Array) -> void:
	if WorldMemory == null:
		return
	
	var job_name: String = _Job.Type.keys()[job_type] if job_type >= 0 and job_type < _Job.Type.size() else "Unknown"
	
	WorldMemory.record_event({
		"type": "neural_decision",
		"pawn_id": int(data.id) if data != null else -1,
		"pawn_name": data.display_name if data != null else "Unknown",
		"job_type": job_type,
		"job_name": job_name,
		"neural_bias": bias,
		"neural_outputs": str(outputs),
		"tick": GameManager.tick_count
	})


func get_resource_pressure_bias(job: Job) -> float:
	if data == null or job == null:
		return 1.0
	var rp: Dictionary = SettlementMemory.get_resource_pressure_for_tile(data.tile_pos)
	if rp.is_empty():
		return 1.0
	var wood_p: float = clamp(float(rp.get("wood", 0.0)), 0.0, 1.0)
	var stone_p: float = clamp(float(rp.get("stone", 0.0)), 0.0, 1.0)
	var ore_p: float = clamp(float(rp.get("ore_proxy", 0.0)), 0.0, 1.0)
	var food_p: float = clamp(float(rp.get("food", 0.0)), 0.0, 1.0)
	var trade_p: float = clamp(float(rp.get("trade", 0.0)), 0.0, 1.0)
	# Safety guard: if upstream pressure is unexpectedly out of bounds, neutralize.
	if wood_p > 0.9 or stone_p > 0.9 or ore_p > 0.9 or food_p > 0.9 or trade_p > 0.9:
		return 1.0
	var intensity: float = 0.0
	match int(job.type):
		_Job.Type.CHOP, _Job.Type.BUILD_BED, _Job.Type.BUILD_WALL, _Job.Type.BUILD_DOOR, _Job.Type.BUILD_FIRE_PIT, _Job.Type.BUILD_STORAGE_HUT, _Job.Type.BUILD_SHELTER, _Job.Type.BUILD_HEARTH, _Job.Type.BUILD_SHRINE:
			intensity = wood_p
		_Job.Type.MINE_WALL:
			intensity = stone_p
		_Job.Type.MINE:
			intensity = ore_p
		_Job.Type.FORAGE, _Job.Type.HUNT, _Job.Type.FISH:
			intensity = food_p
		_Job.Type.TRADE_HAUL:
			intensity = trade_p
		_:
			return 1.0
	var scaled: float = 1.0 + (RESOURCE_PRESSURE_BIAS_MAX - 1.0) * intensity
	return clamp(scaled, 1.0, RESOURCE_PRESSURE_BIAS_MAX)


func attempt_reproduction() -> bool:
	if data == null or _world == null:
		return false
	var now: int = GameManager.tick_count
	if now < _next_reproduction_tick:
		return false
	if data.hunger <= REPRODUCTION_MIN_HUNGER or data.rest <= REPRODUCTION_MIN_REST:
		return false
	var has_shelter: bool = is_in_bed()
	if not has_shelter:
		var bed: Vector2i = _world.find_free_bed_for(self, data.tile_pos)
		has_shelter = bed.x >= 0
	if not has_shelter and _world.bed_count() <= 0:
		# No furniture anywhere â€” allow "ground" pairing instead of hard-blocking births.
		has_shelter = true
	if not has_shelter:
		return false
	var mate: HeelKawnian = _find_compatible_mate()
	if mate == null or mate.data == null:
		return false
	if data.get_social_rapport(int(mate.data.id)) < REPRODUCTION_MIN_RAPPORT:
		return false
	if int(data.id) > int(mate.data.id):
		return false
	var child: HeelKawnian = _spawn_child_pawn(int(data.id), int(mate.data.id))
	if child != null:
		_next_reproduction_tick = now + REPRODUCTION_COOLDOWN_TICKS
		mate._next_reproduction_tick = now + REPRODUCTION_COOLDOWN_TICKS

		# Record joyful birth memory to consciousness
		_record_consciousness_event("birth", "Child born with %s" % str(mate.data.display_name), 70.0, 8, "joy")
		mate._record_consciousness_event("birth", "Child born with %s" % str(data.display_name), 70.0, 8, "joy")

		# Record birth gossip
		var gossip: Node = get_node_or_null("/root/GossipManager")
		if gossip != null and gossip.has_method("record_gossip"):
			gossip.record_gossip(int(data.id), "Child born with %s" % str(mate.data.display_name), int(data.id), "birth", 0.5, 0.7, now)

		# PAWN-ACTIVATED EVENT: Record birth for event system
		if WorldEvents != null and WorldEvents.has_method("record_pawn_action"):
			WorldEvents.record_pawn_action("birth", int(data.id))
		
		WorldMemory.record_event({
			"type": "birth",
			"tick": now,
			"region": _WM._region_key(data.tile_pos.x, data.tile_pos.y),
			"category": "family",
			"severity": 3,
			"parent_a_name": str(data.display_name),
			"parent_b_name": str(mate.data.display_name),
			"parent_a_id": int(data.id),
			"parent_b_id": int(mate.data.id),
		})
		var pc: Node = get_node_or_null("/root/PawnConsciousness")
		if child.data != null and pc != null and pc.has_method("get_trauma_level"):
			var trauma_a: float = float(pc.get_trauma_level(int(data.id)))
			var trauma_b: float = float(pc.get_trauma_level(int(mate.data.id)))
			child.data.parental_trauma_weights = {
				"parent_a": trauma_a,
				"parent_b": trauma_b,
				"inherited": clampf((trauma_a + trauma_b) * 0.5, 0.0, 100.0),
			}
	return child != null

func _reproduction_mate_range_px() -> float:
	if _world == null:
		return REPRODUCTION_MATE_RANGE_PX
	var r: float = REPRODUCTION_MATE_RANGE_PX
	if _world.bed_count() <= 0:
		r = maxf(r, float(World.TILE_PIXELS) * REPRODUCTION_MATE_RANGE_NO_BEDS_MIN_TILES)
	return r


func _find_compatible_mate() -> HeelKawnian:
	# DISABLED for performance - iterates through all pawns
	return null


func is_current_ruler() -> bool:
	if data == null:
		return false
	return SettlementMemory.is_pawn_current_ruler(int(data.id))


func issue_edict(edict_key: String) -> bool:
	if data == null or not is_current_ruler():
		return false
	_active_edict = edict_key
	WorldMemory.record_event({
		"type": "edict_issued",
		"pawn_id": int(data.id),
		"edict": edict_key,
		"tick": GameManager.tick_count,
	})
	# Dynamic neural network matrix connection for settlement effects - DISABLED for performance
	# _nearby_pawn_edict_influence(edict_key)
	return true


func _nearby_pawn_edict_influence(edict_key: String) -> void:
	# DISABLED for performance - iterates through all pawns
	return


func abdicate() -> bool:
	if data == null or not is_current_ruler():
		return false
	data.influence = 0.0
	WorldMemory.record_event({
		"type": "abdicate",
		"pawn_id": int(data.id),
		"tick": GameManager.tick_count,
	})
	return true


func propose_war(target_settlement_id: int) -> bool:
	if data == null or not is_current_ruler():
		return false
	var ok: bool = SettlementMemory.propose_war_for_pawn(int(data.id), target_settlement_id)
	if ok:
		WorldMemory.record_event({
			"type": "war_proposed",
			"pawn_id": int(data.id),
			"target_settlement_id": int(target_settlement_id),
			"tick": GameManager.tick_count,
		})
	return ok


func pledge_loyalty(target_ruler: HeelKawnian) -> bool:
	if data == null or target_ruler == null or target_ruler.data == null:
		return false
	if not target_ruler.is_current_ruler():
		return false
	target_ruler.data.influence += 5.0
	WorldMemory.record_event({
		"type": "pledge_loyalty",
		"pawn_id": int(data.id),
		"target_ruler_id": int(target_ruler.data.id),
		"tick": GameManager.tick_count,
	})
	return true


func _tick_walking() -> void:
	if _state == State.DRAFT_WALK:
		return
	if _current_job == null:
		_state = State.IDLE
		_clear_path()
		return
	if not _is_job_tile_still_valid(_current_job):
		_cancel_current_job()


func _tick_working() -> void:
	var work_step_interval: int = _work_step_interval_for_speed()
	var tick_now: int = GameManager.tick_count if GameManager != null else 0
	if work_step_interval > 1 and posmod(tick_now + int(data.id), work_step_interval) != 0:
		return
	var work_step_multiplier: int = maxi(1, work_step_interval)
	if _current_job == null:
		_state = State.IDLE
		return
	if _current_job.type == _Job.Type.HUNT and HeelKawnian._world_hunt_stabilization_blocks():
		_unclaim_current_job("hunt_blocked")
		return
	# Starving: let go of non-harvest work so the next tick can path to food.
	if data.hunger <= HUNGER_EMERGENCY and _current_job != null:
		if _current_job.type != _Job.Type.FORAGE and _current_job.type != _Job.Type.HUNT and _current_job.type != _Job.Type.FISH:
			_unclaim_current_job("hunger_emergency")
			return
	# Hungry + autonomy wants food: release non-forage work so the pawn can eat sooner than emergency.
	if (
			data.hunger <= HUNGER_EAT_THRESHOLD
			and _current_job != null
			and data.neural_network != null
			and str(data.neural_network.get_autonomy_hint()) == "eat"
	):
		if _current_job.type != _Job.Type.FORAGE and _current_job.type != _Job.Type.HUNT and _current_job.type != _Job.Type.FISH:
			_notify_autonomy_feedback("need_eat (drop job)")
			_unclaim_current_job("neural_eat")
			return
	if not _is_job_tile_still_valid(_current_job):
		JobManager.cancel(_current_job, "tile_invalid")
		_reset_to_idle()
		return
	
	# Stage 1: Calculate work efficiency based on proficiency, stamina, pain, injuries
	var efficiency: float = _calculate_work_efficiency()
	
	# Skill-modulated work rate: progress per tick = work_speed_for(skill).
	# Always at least 1 progress per tick (a fresh pawn isn't slower than the
	# old constant-rate baseline). XP accrues only while actually working.
	var skill: int = HeelKawnianData.skill_for_job(_current_job.type)
	var speed: float = data.effective_labor_mult() * float(work_step_multiplier)
	# Tool efficacy is applied inside _calculate_work_efficiency() â€” don't double-count.
	speed *= data.kinship_work_speed_multiplier(_current_job.work_tile)
	if skill >= 0:
		speed *= data.work_speed_for(skill)
		# Apply efficiency modifier
		speed *= efficiency
		var leveled_up: bool = data.add_skill_xp(
				skill, HeelKawnianData.XP_PER_WORK_TICK * float(work_step_multiplier)
		)
		var w: int = maxi(1, int(ceil(speed)))
		data.add_profession_liking_for_job(_current_job.type, w)
		# Record job tick for likes/dislikes and profession assignment
		var job_cat: String = HeelKawnianData.job_category_for_type(_current_job.type)
		data.record_job_tick(job_cat)
		# Apply mood modifier from likes/dislikes
		var mood_mod: float = data.mood_modifier_for_category(job_cat)
		if mood_mod != 0.0:
			data.mood = clampf(data.mood + mood_mod, 0.0, 100.0)
		# Decay gear durability for tool/weapon slots
		var tool_gear: Variant = data.equipped_gear.get(2, null)  # Slot.TOOL
		if tool_gear != null and tool_gear.has_method("use"):
			if not tool_gear.use():
				# Tool broke â€” unequip and record event
				data.unequip_gear(2)
				WorldMemory.record_event({
					"type": "gear_break",
					"pawn_id": int(data.id),
					"gear_name": str(tool_gear.name),
					"tick": GameManager.tick_count,
				})
		var weapon_gear: Variant = data.equipped_gear.get(0, null)  # Slot.WEAPON
		if weapon_gear != null and weapon_gear.has_method("use"):
			if not weapon_gear.use():
				data.unequip_gear(0)
				WorldMemory.record_event({
					"type": "gear_break",
					"pawn_id": int(data.id),
					"gear_name": str(weapon_gear.name),
					"tick": GameManager.tick_count,
				})
		_current_job.work_ticks_done += w
	if _current_job.work_ticks_done >= _current_job.work_ticks_needed:
		if _current_job.type == _Job.Type.TRADE_HAUL:
			_complete_trade_pickup()
		else:
			_complete_current_job()
	# Mining and wall-mining are hazardous. Small chance of injury each tick.
	_apply_work_hazards(work_step_multiplier)


func _calculate_work_efficiency() -> float:
	var efficiency: float = 1.0
	
	# Tool efficacy: equipped tools boost specific job types
	if data.is_equipped_tool_valid():
		efficiency *= data.get_tool_efficacy(_current_job.type)
	
	# Job proficiency bonus (0-100 proficiency -> 0.5-2.0 multiplier)
	var job_type_str: String = Job.describe_type(_current_job.type).to_lower()
	var proficiency: float = data.job_proficiency.get(job_type_str, 0.0)
	var proficiency_bonus: float = 0.5 + (proficiency / 100.0) * 1.5
	efficiency *= proficiency_bonus
	
	# Stamina penalty (low stamina reduces efficiency)
	if data.stamina < 30.0:
		efficiency *= 0.5
	elif data.stamina < 50.0:
		efficiency *= 0.75
	
	# Pain penalty (pain reduces efficiency)
	if data.pain > 50.0:
		efficiency *= 0.5
	elif data.pain > 30.0:
		efficiency *= 0.75
	
	# Injury penalty from BodyRiskManager (severity-weighted per injury type)
	if not data.injuries.is_empty():
		var injury_penalty: float = BodyRiskManager.get_work_efficiency_penalty(data)
		efficiency *= (1.0 - injury_penalty)
	
	# Improvised tool proxy from carried material (no separate pickaxe/axe items in v1).
	if _current_job != null and data != null:
		var jt: int = _current_job.type
		_apply_tradition_mood_for_job(jt)
		if jt == _Job.Type.MINE or jt == _Job.Type.MINE_WALL:
			if data.is_carrying() and (data.carrying == _Item.Type.STONE or data.carrying == _Item.Type.WOOD):
				efficiency *= 1.04
			else:
				efficiency *= 0.88
		elif jt == _Job.Type.CHOP:
			if data.is_carrying() and not Item.is_food(data.carrying):
				if data.carrying == _Item.Type.WOOD or data.carrying == _Item.Type.STONE:
					efficiency *= 1.03
				else:
					efficiency *= 0.90
			else:
				efficiency *= 0.93
	
	return clamp(efficiency, 0.1, 2.0)


func _apply_tradition_mood_for_job(job_type: int) -> void:
	if data == null:
		return
	if not data.has_meta("tradition_taboo_jobs"):
		return
	var taboo_v: Variant = data.get_meta("tradition_taboo_jobs", [])
	if not (taboo_v is Array):
		return
	var taboo: Array = taboo_v as Array
	var bonus: float = float(data.get_meta("tradition_mood_bonus", 4.0))
	var penalty: float = float(data.get_meta("tradition_mood_penalty", -6.0))
	var job_name: String = _cached_job_type_name(job_type)
	var mood_delta: float = bonus
	for taboo_any in taboo:
		if str(taboo_any).to_upper() == job_name:
			mood_delta = penalty
			break
	data.mood = clampf(data.mood + mood_delta * 0.01, 0.0, 100.0)


func _tick_eating() -> void:
	_eat_ticks_left -= 1
	if _eat_ticks_left <= 0:
		_finish_eating()


func _tick_teaching() -> void:
	_teaching_ticks_left -= 1
	
	# Check if target is still valid and nearby
	if _teaching_target == null or not is_instance_valid(_teaching_target):
		_finish_teaching()
		return
	
	var dist: float = position.distance_to(_teaching_target.position)
	if dist > 50.0:  # Teaching range
		_finish_teaching()
		return
	
	if _teaching_ticks_left <= 0:
		# Teaching complete - transfer knowledge
		if KnowledgeSystem != null and _teaching_knowledge_type >= 0:
			var teacher_id: int = int(data.id)
			var student_id: int = int(_teaching_target.data.id)
			KnowledgeSystem.teach_knowledge(teacher_id, student_id, _teaching_knowledge_type)
			# Record teaching achievement to consciousness
			_record_consciousness_event("teaching", "Taught knowledge type %d to %s" % [_teaching_knowledge_type, str(_teaching_target.data.display_name)], 40.0, 6, "achievement")
		_finish_teaching()


func _finish_teaching() -> void:
	_teaching_target = null
	_teaching_ticks_left = 0
	_teaching_knowledge_type = -1
	_reset_to_idle()


func _tick_challenge() -> void:
	_challenge_ticks_left -= 1
	
	# Check if target is still valid and nearby
	if _challenge_target == null or not is_instance_valid(_challenge_target):
		_finish_challenge()
		return
	
	var dist: float = position.distance_to(_challenge_target.position)
	if dist > 50.0:  # Challenge range
		_finish_challenge()
		return
	
	if _challenge_ticks_left <= 0:
		# Challenge complete - resolve through AuthoritySystem
		if AuthoritySystem != null and _challenge_context >= 0:
			var challenger_id: int = int(data.id)
			var defender_id: int = int(_challenge_target.data.id)
			AuthoritySystem.resolve_conflict(challenger_id, defender_id, _challenge_context)
		_finish_challenge()


func _finish_challenge() -> void:
	_challenge_target = null
	_challenge_ticks_left = 0
	_challenge_context = -1
	_reset_to_idle()


func _apply_work_hazards(work_ticks_simulated: int = 1) -> void:
	if _current_job == null:
		return
	if _current_job.type == _Job.Type.TRADE_HAUL:
		return
	# Mining and wall-mining expose pawns to injury risk.
	# Chance = 2% base, reduced by skill level (miners get safer as they level).
	# Unskilled pawn (lvl 0): 2% per tick. Skilled (lvl 20): 0.2% per tick.
	var hazard_chance: float = 0.0
	if _current_job.type == _Job.Type.MINE or _current_job.type == _Job.Type.MINE_WALL:
		var mining_level: int = data.get_skill_level(HeelKawnianData.Skill.MINING)
		hazard_chance = 0.02 * max(0.1, 1.0 - (mining_level / 20.0))
		# Traits can modify injury chance
		hazard_chance *= data.get_trait_mult("injury_chance_mult")
	var step_ticks: int = maxi(1, work_ticks_simulated)
	var per_step_chance: float = hazard_chance
	if step_ticks > 1 and hazard_chance > 0.0 and hazard_chance < 1.0:
		# Fold N Bernoulli trials into one check so expected hazard frequency is
		# stable when work updates are batched for performance.
		per_step_chance = 1.0 - pow(maxf(0.0, 1.0 - hazard_chance), float(step_ticks))
	if per_step_chance > 0.0 and WorldRNG.chance_for(_pawn_stream("work_hazard"), per_step_chance, _pawn_salt(23)):
		var damage: float = WorldRNG.range_for(_pawn_stream("work_hazard_damage"), 3.0, 8.0, _pawn_salt(29))
		# Traits can reduce damage taken
		damage *= data.get_trait_mult("damage_taken_mult")
		damage *= data.physical_scar_damage_taken_mult()
		data.health = max(0.0, data.health - damage)
		_play_sfx("res://assets/audio/pawn_hurt.ogg", 0.9)
		# Trigger stress mood event from injury
		data.add_mood_event(MoodEvent.Type.STRESS, 60.0, 300)
		# Record injury trauma to PawnConsciousness
		_record_consciousness_event("injury", "Hurt while working (%s)" % Job.describe_type(_current_job.type), -60.0, 7, "survival")
		# Record grudge against the job type (workplace hazard) â€” no specific target
		# This creates a mild "workplace resentment" that affects job preference
		
		# Apply specific injury via BodyRiskManager
		var injury_type: int = BodyRiskManager.InjuryType.BLUNT
		if _current_job.type == _Job.Type.MINE or _current_job.type == _Job.Type.MINE_WALL:
			injury_type = BodyRiskManager.InjuryType.CUT  # Rock cuts
		elif _current_job.type == _Job.Type.CHOP:
			injury_type = BodyRiskManager.InjuryType.CUT  # Axe cuts
		BodyRiskManager.apply_injury(self, injury_type, damage * 2.0, Job.describe_type(_current_job.type))
		
		if damage >= 5.0:
			var scar_pool: Array[String] = ["LameLeg", "MissingArm", "BlindedEye", "DeepScar"]
			var pick: int = WorldRNG.index_for(_pawn_stream("work_hazard_scar"), scar_pool.size(), _pawn_salt(31))
			data.append_physical_scar(scar_pool[pick])


# ==================== jobs (FORAGE / MINE) ====================

func _begin_job(job: Job) -> void:
	_current_job = job
	HeelKawnianManager.note_matrix_job_choice(self, job)
	# Throttled cohort system calls for performance
	_invalidate_recruitment_signal_cache()
	update_cohort_membership(true)
	_refresh_or_decay_cohort_stability(true)
	# Build jobs need raw materials in hand before we walk to the build site.
	# If we don't already have the right item in sufficient quantity, bounce
	# to the stockpile first.
	var mats: Dictionary = _materials_for_build(job.type)
	if not mats.is_empty():
		var item_type: int = mats.item
		var need_qty: int = mats.qty
		# === Check for cultural style material override ===
		var settlement_id: int = _current_settlement_center_region()
		# material_family is not directly used by this pawn for logic, so no verbose logging here.
		if settlement_id >= 0 and CulturalStyleManager != null:
			item_type = int(CulturalStyleManager.call("get_build_material_for_settlement", settlement_id, job.type))
		# === End style check ===
		var have: int = data.carrying_qty if data.carrying == item_type else 0
		if have < need_qty:
			_begin_fetching_material(item_type, need_qty)
			return
	_walk_to_work_tile(job)


## Path the pawn to its current job's work_tile, transitioning to WORKING on
## arrival. Used by both the initial _begin_job and the post-fetch handoff.
func _walk_to_work_tile(job: Job) -> void:
	if data.tile_pos == job.work_tile:
		_clear_path()
		_state = State.WORKING
		_request_redraw()
		return
	var path: Array[Vector2i] = _path_for_pawn(job.work_tile)
	if path.is_empty():
		_unclaim_current_job("no_path_to_job")
		return
	_state = State.WALKING_TO_JOB
	_start_path(path)
	_request_redraw()


func _return_trade_cargo_to_source_if_any(j: Job) -> void:
	if j == null or j.type != _Job.Type.TRADE_HAUL:
		return
	if not data.is_carrying() or j.trade_from == null or not is_instance_valid(j.trade_from):
		return
	if j.trade_item == data.carrying:
		j.trade_from.add_item(data.carrying, data.carrying_qty)
		data.clear_carry()


func _complete_trade_pickup() -> void:
	var job: Job = _current_job
	if job == null or job.type != _Job.Type.TRADE_HAUL:
		_unclaim_current_job("trade_not_haul")
		return
	var from_sp: Stockpile = job.trade_from
	var to_sp: Stockpile = job.trade_to
	if from_sp == null or not is_instance_valid(from_sp) or to_sp == null or not is_instance_valid(to_sp):
		_unclaim_current_job("trade_sp_invalid")
		return
	var want: int = mini(job.trade_batch, from_sp.count_of(job.trade_item))
	if want <= 0:
		_unclaim_current_job("trade_no_stock")
		return
	var taken: int = from_sp.take_item(job.trade_item, want)
	if taken <= 0:
		_unclaim_current_job("trade_take_failed")
		return
	if not to_sp.accepts(job.trade_item):
		from_sp.add_item(job.trade_item, taken)
		_unclaim_current_job("trade_rejected")
		return
	data.carrying = job.trade_item
	data.carrying_qty = taken
	_begin_haul_to_forced_zone(to_sp)
	_request_redraw()


func _begin_haul_to_forced_zone(sp: Stockpile) -> void:
	if not data.is_carrying() or sp == null or not is_instance_valid(sp) or not sp.accepts(data.carrying):
		_unclaim_current_job("haul_rejected")
		return
	_target_zone = sp
	var target_tile: Vector2i = sp.nearest_reachable_tile_to(data.tile_pos, _world.pathfinder)
	# Verify the target tile is actually reachable (same pathfinder component)
	if _world.pathfinder != null and _world.pathfinder.component_of(target_tile) != _world.pathfinder.component_of(data.tile_pos):
		_unclaim_current_job("stockpile_unreachable")
		return
	if data.tile_pos == target_tile:
		_deposit_at_stockpile()
		return
	var path2: Array[Vector2i] = _path_for_pawn(target_tile)
	if path2.is_empty():
		_log_haul_fail("no path")
		_return_trade_cargo_to_source_if_any(_current_job)
		_unclaim_current_job("haul_no_path")
		return
	_state = State.HAULING
	_start_path(path2)
	_request_redraw()


# ==================== material fetch (build jobs) ====================

## Walk to the nearest stockpile zone that has the requested materials and
## pick up `qty` of `item_type` for the active job. Aborts the job (with a
## one-line log) if no reachable zone has enough.
func _begin_fetching_material(item_type: int, qty: int) -> void:
	var sp: Stockpile = StockpileManager.find_source_for(
		item_type, qty, data.tile_pos, _world.pathfinder
	)
	if sp == null:
		_unclaim_current_job("no_stockpile_source")
		return
	_target_zone = sp
	var target_tile: Vector2i = sp.nearest_reachable_tile_to(data.tile_pos, _world.pathfinder)
	if data.tile_pos == target_tile:
		_pickup_material(item_type, qty)
		return
	var path: Array[Vector2i] = _path_for_pawn(target_tile)
	if path.is_empty():
		_unclaim_current_job("no_path_to_stockpile")
		return
	_state = State.FETCHING_MATERIAL
	_start_path(path)
	_request_redraw()


## Called when the FETCHING_MATERIAL walk completes. Take the materials out
## of the stockpile (per the build job's recipe), then walk back to the
## build site. If someone else cleared the stockpile out from under us,
## abort the job.
func _arrive_at_stockpile_for_material() -> void:
	if _current_job == null:
		_reset_to_idle()
		return
	var mats: Dictionary = _materials_for_build(_current_job.type)
	if mats.is_empty():
		_reset_to_idle()
		return
	var item_type: int = mats.item
	var need_qty: int = mats.qty
	var have: int = data.carrying_qty if data.carrying == item_type else 0
	var to_take: int = max(0, need_qty - have)
	_pickup_material(item_type, to_take)


func _pickup_material(item_type: int, qty: int) -> void:
	# qty <= 0 means we already have enough on hand; just walk to the build
	# site without bothering the stockpile.
	if qty <= 0:
		if _current_job != null:
			_walk_to_work_tile(_current_job)
		else:
			_reset_to_idle()
		return
	# Prefer the zone we planned for when we started walking. If it's gone
	# (wiped by reroll, e.g.) or ran dry, fall back to nearest zone with the
	# material -- saves the trip if there's still wood elsewhere.
	var sp: Stockpile = _target_zone
	if sp == null or not is_instance_valid(sp) or sp.count_of(item_type) < qty:
		sp = StockpileManager.find_source_for(item_type, qty, data.tile_pos, _world.pathfinder)
	if sp == null:
		_target_zone = null
		_unclaim_current_job("stockpile_gone")
		return
	var taken: int = sp.take_item(item_type, qty)
	if taken < qty:
		# Partial take: put it back so we don't strand items in our hand.
		if taken > 0:
			sp.add_item(item_type, taken)
		_target_zone = null
		_unclaim_current_job("stockpile_partial")
		return
	# Stack onto existing carry of the same type, otherwise replace.
	if data.carrying == item_type:
		data.carrying_qty += taken
	else:
		data.carrying = item_type
		data.carrying_qty = taken
	_target_zone = null
	_request_redraw()
	if _current_job != null:
		_walk_to_work_tile(_current_job)
	else:
		_reset_to_idle()


func _is_job_tile_still_valid(job: Job) -> bool:
	if _world == null or _world.data == null:
		return false
	if not _world.data.in_bounds(job.tile.x, job.tile.y):
		return false
	match job.type:
		_Job.Type.FORAGE, _Job.Type.PLANT_SEEDS:
			return _world.data.get_feature(job.tile.x, job.tile.y) == TileFeature.Type.FERTILE_SOIL
		_Job.Type.MINE:
			return _world.data.get_feature(job.tile.x, job.tile.y) == TileFeature.Type.ORE_VEIN
		_Job.Type.MINE_WALL:
			return _world.data.get_biome(job.tile.x, job.tile.y) == Biome.Type.MOUNTAIN
		_Job.Type.CHOP:
			return _world.data.get_feature(job.tile.x, job.tile.y) == TileFeature.Type.TREE
		_Job.Type.HUNT:
			# Animals are tile features; the hunt's still valid as long as the
			# critter hasn't already been killed (cleared) by someone else.
			return TileFeature.is_wildlife(_world.data.get_feature(job.tile.x, job.tile.y))
		_Job.Type.COOK_MEAT, _Job.Type.COOK_BERRIES, _Job.Type.COOK_FISH, _Job.Type.DRY_MEAT:
			# Cooking requires a fire pit on the job tile (the hearth).
			return _world.data.get_feature(job.tile.x, job.tile.y) == TileFeature.Type.FIRE_PIT
		_Job.Type.TRADE_HAUL:
			var tf: Stockpile = job.trade_from
			var tt: Stockpile = job.trade_to
			if tf == null or not is_instance_valid(tf) or tt == null or not is_instance_valid(tt):
				return false
			if not _world.pathfinder.is_passable(job.work_tile):
				return false
			if not tt.accepts(job.trade_item):
				return false
			return tf.count_of(job.trade_item) > 0
		_Job.Type.BUILD_BED, _Job.Type.BUILD_WALL, \
		_Job.Type.BUILD_FIRE_PIT, _Job.Type.BUILD_STORAGE_HUT, \
		_Job.Type.BUILD_MARKER_STONE, _Job.Type.BUILD_SHRINE, \
		_Job.Type.BUILD_SHELTER, _Job.Type.BUILD_HEARTH, \
		# Phase 6: new buildings via BuildingRegistry
		_Job.Type.BUILD_FARM_WHEAT, _Job.Type.BUILD_FARM_CORN, _Job.Type.BUILD_FARM_VEGETABLES, _Job.Type.BUILD_HERB_GARDEN, \
		_Job.Type.BUILD_WORKSHOP, _Job.Type.BUILD_LOOM, _Job.Type.BUILD_KILN, _Job.Type.BUILD_SMELTER, \
		_Job.Type.BUILD_BOATYARD, _Job.Type.BUILD_DOCK, _Job.Type.BUILD_FISHERMAN_HUT, \
		_Job.Type.BUILD_APOTHECARY, \
		_Job.Type.BUILD_LIBRARY, _Job.Type.BUILD_SCHOOL, \
		_Job.Type.BUILD_BARRACKS, _Job.Type.BUILD_WATCHTOWER, \
		_Job.Type.BUILD_MARKET, _Job.Type.BUILD_TRADING_POST, \
		_Job.Type.BUILD_ROAD, \
		_Job.Type.BUILD_GRANARY, _Job.Type.BUILD_CELLAR, \
		_Job.Type.BUILD_FORD, _Job.Type.BUILD_WATER_MILL:
			# Build sites are valid if the tile doesn't already have a
			# structure on it (TREE/FERTILE_SOIL are OK â€” set_feature overwrites
			# them on completion) and the underlying biome is passable.
			var f1: int = _world.data.get_feature(job.tile.x, job.tile.y)
			# Skip tiles with existing structures (any built feature)
			if TileFeature.name_for(f1) != "None" and f1 != TileFeature.Type.TREE and f1 != TileFeature.Type.FERTILE_SOIL and f1 != TileFeature.Type.ORE_VEIN and f1 != TileFeature.Type.RUIN:
				return false
			return Biome.is_passable(_world.data.get_biome(job.tile.x, job.tile.y))
		_Job.Type.BUILD_DOOR:
			# Fresh door: empty tile. Replace-door: still a WALL (worker stands
			# on a neighbor; job completes into build_door swap).
			var f2: int = _world.data.get_feature(job.tile.x, job.tile.y)
			if f2 == TileFeature.Type.WALL or f2 == TileFeature.Type.NONE:
				return Biome.is_passable(_world.data.get_biome(job.tile.x, job.tile.y))
			return false
		_Job.Type.CARVE_GRAVE_MARKER, _Job.Type.CARVE_KNOWLEDGE_STONE, _Job.Type.CARVE_LEDGER_STONE:
			# Carve jobs: tile must be passable and not already have a structure.
			var f3: int = _world.data.get_feature(job.tile.x, job.tile.y)
			if f3 == TileFeature.Type.GRAVE_MARKER or f3 == TileFeature.Type.KNOWLEDGE_STONE or f3 == TileFeature.Type.LEDGER_STONE:
				return false
			return Biome.is_passable(_world.data.get_biome(job.tile.x, job.tile.y))
	# Jobs without specific tile requirements (PROTECT, DEFEND, TEACH, etc.)
	# are valid as long as the tile is in bounds and passable.
	if _world.data.in_bounds(job.tile.x, job.tile.y):
		return Biome.is_passable(_world.data.get_biome(job.tile.x, job.tile.y))
	return false


## Work finished successfully. Produce the item into the pawn's hands and
## transition to HAULING (walk it to the stockpile).
func _complete_current_job() -> void:
	var job: Job = _current_job
	if job != null and job.type == _Job.Type.TRADE_HAUL:
		return
	if job != null and job.type == _Job.Type.HUNT and HeelKawnian._world_hunt_stabilization_blocks():
		_unclaim_current_job("hunt_stabilization")
		return

	# PAWN-ACTIVATED EVENT: Record job completion for event system
	if WorldEvents != null and WorldEvents.has_method("record_pawn_action"):
		WorldEvents.record_pawn_action("job_complete", int(data.id))

	# Show action popup for significant job completions
	if _action_popup != null and job != null and GameManager.game_speed < 50.0:
		_show_action_popup_for_job(job)
	
	# Stage 1: Increase job proficiency for completed job
	var job_type_str: String = Job.describe_type(job.type).to_lower()
	var current_proficiency: float = data.job_proficiency.get(job_type_str, 0.0)
	data.job_proficiency[job_type_str] = min(100.0, current_proficiency + 2.0)  # +2 proficiency per job
	
	var produced_type: int = _Item.Type.NONE
	# Most harvests yield 1; only HUNT (deer) yields more, but plumbing it as a
	# variable keeps room for future high-yield jobs without re-plumbing again.
	var produced_qty: int = 1
	match job.type:
		_Job.Type.FORAGE:
			produced_type = _Item.Type.BERRY
			_world.clear_feature(job.tile.x, job.tile.y)
		_Job.Type.MINE:
			produced_type = _Item.Type.STONE
			_world.clear_feature(job.tile.x, job.tile.y)
		_Job.Type.MINE_WALL:
			produced_type = _Item.Type.STONE
			# This converts MOUNTAIN -> STONE_FLOOR and rebuilds the components
			# map, which can cascade-unlock sealed ore veins.
			_world.mine_out_wall(job.tile.x, job.tile.y)
		_Job.Type.CHOP:
			produced_type = _Item.Type.WOOD
			_world.clear_feature(job.tile.x, job.tile.y)
		_Job.Type.HUNT:
			produced_type = _Item.Type.MEAT
			# Read the species off the tile BEFORE we clear it, so we know
			# whether to grant 1 (rabbit) or 2 (deer) meat.
			var animal_feat: int = _world.data.get_feature(job.tile.x, job.tile.y)
			produced_qty = 2 if animal_feat == TileFeature.Type.DEER else 1
			var htile: Vector2i = Vector2i(job.tile.x, job.tile.y)
			if TileFeature.is_wildlife(animal_feat) and not _hunt_has_live_animal_node_at(htile):
				WorldMemory.record_animal_death(
						GameManager.tick_count,
						htile,
						_hunt_species_int_from_wildlife_feature(animal_feat),
						TileFeature.name_for(animal_feat),
				)
			# Also produce a bone as a hunting byproduct
			var bone_sp: Stockpile = StockpileManager.find_drop_zone(_Item.Type.BONE, job.tile, _world.pathfinder)
			if bone_sp != null:
				bone_sp.add_item(_Item.Type.BONE, 1)
			_world.clear_feature(job.tile.x, job.tile.y)
		_Job.Type.FISH:
			produced_type = _Item.Type.FISH
			# RIVER features persist (don't clear) - fish regenerate naturally
			# Base yield 1; fisherman hut adds 1; deep pools (high quality) add 1
			produced_qty = 1
			if _has_fisherman_hut_nearby(job.tile):
				produced_qty += 1
			if WorldGenerator.river_quality(job.tile) > 0.7:
				produced_qty += 1  # Deep pool bonus
			# Seasonal fish migration: spring = spawning, best yield; winter = lowest
			var season: int = Biome.season_for_tick(GameManager.tick_count)
			match season:
				Biome.Season.SPRING:
					produced_qty += 1  # Spring spawning run
				Biome.Season.WINTER:
					produced_qty = maxi(1, produced_qty - 1)  # Winter scarcity
		_Job.Type.BUILD_BED, _Job.Type.BUILD_WALL, _Job.Type.BUILD_DOOR:
			_finish_build(job)
		_Job.Type.GATHER_FLINT:
			produced_type = _Item.Type.FLINT
		_Job.Type.GATHER_STICK:
			produced_type = _Item.Type.STICK
		_Job.Type.CRAFT_KNIFE, _Job.Type.CRAFT_TORCH, _Job.Type.CRAFT_PICK, _Job.Type.CRAFT_SPEAR:
			_finish_craft(job)
			produced_type = _Item.Type.NONE  # tool is equipped, not carried
		_Job.Type.BUILD_FIRE_PIT, _Job.Type.BUILD_STORAGE_HUT, _Job.Type.BUILD_MARKER_STONE, _Job.Type.BUILD_SHRINE, _Job.Type.BUILD_SHELTER, _Job.Type.BUILD_HEARTH:
			_finish_shelter_build(job)
			produced_type = _Item.Type.NONE
		# Phase 6: Data-driven building placement via BuildingRegistry
		_Job.Type.BUILD_FARM_WHEAT, _Job.Type.BUILD_FARM_CORN, _Job.Type.BUILD_FARM_VEGETABLES, _Job.Type.BUILD_HERB_GARDEN, \
		_Job.Type.BUILD_WORKSHOP, _Job.Type.BUILD_LOOM, _Job.Type.BUILD_KILN, _Job.Type.BUILD_SMELTER, \
		_Job.Type.BUILD_BOATYARD, _Job.Type.BUILD_DOCK, _Job.Type.BUILD_FISHERMAN_HUT, \
		_Job.Type.BUILD_APOTHECARY, \
		_Job.Type.BUILD_LIBRARY, _Job.Type.BUILD_SCHOOL, \
		_Job.Type.BUILD_BARRACKS, _Job.Type.BUILD_WATCHTOWER, \
		_Job.Type.BUILD_MARKET, _Job.Type.BUILD_TRADING_POST, \
		_Job.Type.BUILD_ROAD, \
		_Job.Type.BUILD_GRANARY, _Job.Type.BUILD_CELLAR, \
		_Job.Type.BUILD_FORD, _Job.Type.BUILD_WATER_MILL:
			_finish_registry_build(job)
			produced_type = _Item.Type.NONE
		_Job.Type.COOK_MEAT, _Job.Type.COOK_BERRIES, _Job.Type.COOK_FISH, _Job.Type.DRY_MEAT:
			produced_type = Job.tool_job_output(job.type)
		_Job.Type.PLANT_SEEDS:
			FoodChainManager.plant_seeds(job.tile)
			produced_type = _Item.Type.NONE
		_Job.Type.HARVEST_CROPS:
			produced_type = FoodChainManager.harvest_crop(job.tile)
			produced_qty = 2 if produced_type != _Item.Type.NONE else 0  # Crops yield more
		_Job.Type.CARVE_GRAVE_MARKER:
			_world.set_feature(job.tile.x, job.tile.y, TileFeature.Type.GRAVE_MARKER)
			produced_type = _Item.Type.NONE
		_Job.Type.CARVE_KNOWLEDGE_STONE:
			_world.set_feature(job.tile.x, job.tile.y, TileFeature.Type.KNOWLEDGE_STONE)
			if KnowledgeSystem != null and KnowledgeSystem.has_method("inscribe_knowledge_on_stone"):
				var pawn_knowledge: Array = []
				if KnowledgeSystem.has_method("get"):
					var carriers: Variant = KnowledgeSystem.get("knowledge_carriers")
					if carriers != null and carriers is Dictionary and carriers.has(int(data.id)):
						pawn_knowledge = carriers[int(data.id)].duplicate()
				KnowledgeSystem.inscribe_knowledge_on_stone(job.tile, pawn_knowledge, int(data.id), "knowledge_stone")
			produced_type = _Item.Type.NONE
		_Job.Type.CARVE_LEDGER_STONE:
			_world.set_feature(job.tile.x, job.tile.y, TileFeature.Type.LEDGER_STONE)
			produced_type = _Item.Type.NONE
		_Job.Type.GROW_FOOD:
			# Route into FarmingSystem so plot state (water, health) actually updates.
			# Item grants are skipped because farm crops (wheat, corn, etc.) don't
			# yet exist in Item.Type â€” only the plot mutation matters for now.
			if FarmingSystem != null and FarmingSystem.has_method("complete_farming_job_by_tile"):
				FarmingSystem.complete_farming_job_by_tile(job.tile, int(data.id))
			produced_type = _Item.Type.NONE
		_Job.Type.TEACH_SKILL, _Job.Type.APPRENTICESHIP:
			# Teaching jobs: find a nearby pawn with lower skill and transfer knowledge.
			if KnowledgeSystem != null and KnowledgeSystem.has_method("teach_knowledge"):
				var best_student: HeelKawnian = null
				var best_skill_gap: int = 0
				for p in get_tree().get_nodes_in_group("pawns"):
					if p == self or not is_instance_valid(p) or p.data == null:
						continue
					if position.distance_to(p.position) > 80.0:
						continue
					var gap: int = 0
					for sk in range(5):
						var my_level: int = data.get_skill_level(sk)
						var their_level: int = p.data.get_skill_level(sk)
						if my_level > their_level:
							gap += (my_level - their_level)
					if gap > best_skill_gap:
						best_skill_gap = gap
						best_student = p
				if best_student != null and best_skill_gap > 0:
					KnowledgeSystem.teach_knowledge(int(data.id), int(best_student.data.id), 0)
			produced_type = _Item.Type.NONE
	# If the pawn is re-fetching materials (build failed material check), don't complete the job yet.
	# The pawn will walk to the stockpile, fetch, walk back, and re-attempt the build.
	if _state == State.FETCHING_MATERIAL:
		return
	var yield_skill: int = HeelKawnianData.skill_for_job(job.type)
	if yield_skill >= 0 and produced_type != _Item.Type.NONE:
		var qmult: float = data.harvest_quality_multiplier_for_job_skill(yield_skill)
		if qmult > 1.001:
			produced_qty = maxi(1, int(round(float(produced_qty) * qmult)))
	# Trigger mood event based on job type
	match job.type:
		_Job.Type.HUNT:
			data.add_mood_event(MoodEvent.Type.TRIUMPH, 80.0, 250)  # Hunting is thrilling
		_Job.Type.MINE, _Job.Type.MINE_WALL:
			data.add_mood_event(MoodEvent.Type.CONTENTMENT, 50.0, 200)  # Solid work
		_Job.Type.CHOP, _Job.Type.FORAGE:
			data.add_mood_event(MoodEvent.Type.CONTENTMENT, 40.0, 180)  # Basic harvesting
		_Job.Type.BUILD_BED, _Job.Type.BUILD_WALL, _Job.Type.BUILD_DOOR, _Job.Type.BUILD_SHELTER:
			data.add_mood_event(MoodEvent.Type.JOY, 60.0, 220)  # Building feels productive
		_Job.Type.GATHER_FLINT, _Job.Type.GATHER_STICK:
			data.add_mood_event(MoodEvent.Type.CONTENTMENT, 30.0, 150)  # Gathering materials
		_Job.Type.CRAFT_KNIFE, _Job.Type.CRAFT_TORCH, _Job.Type.CRAFT_PICK, _Job.Type.CRAFT_SPEAR:
			data.add_mood_event(MoodEvent.Type.JOY, 70.0, 250)  # Crafting feels like progress
		_Job.Type.BUILD_FIRE_PIT:
			data.add_mood_event(MoodEvent.Type.JOY, 80.0, 300)  # Fire brings warmth and hope
		_Job.Type.BUILD_STORAGE_HUT:
			data.add_mood_event(MoodEvent.Type.CONTENTMENT, 55.0, 200)  # Security feels good
		_Job.Type.BUILD_MARKER_STONE:
			data.add_mood_event(MoodEvent.Type.PRIDE, 65.0, 280)  # Marking territory feels significant
		_Job.Type.BUILD_SHRINE:
			data.add_mood_event(MoodEvent.Type.REVERENCE, 90.0, 350)  # Sacred act
		_Job.Type.COOK_MEAT, _Job.Type.COOK_BERRIES, _Job.Type.COOK_FISH:
		_Job.Type.DRY_MEAT:
			data.add_mood_event(MoodEvent.Type.CONTENTMENT, 45.0, 180)  # Preservation feels prudent
		_Job.Type.PLANT_SEEDS:
			data.add_mood_event(MoodEvent.Type.HOPE, 70.0, 300)  # Planting is an act of faith
		_Job.Type.HARVEST_CROPS:
			data.add_mood_event(MoodEvent.Type.TRIUMPH, 75.0, 250)  # Harvest rewards patience
		_Job.Type.VISIT_GRAVE:
			data.add_mood_event(MoodEvent.Type.JOY, 40.0, 200)  # Comfort from remembrance
			if WorldMemory != null:
				WorldMemory.record_event({
					"type": "grave_visit",
					"pawn_id": int(data.id),
					"tile": {"x": job.tile.x, "y": job.tile.y},
					"tick": GameManager.tick_count
				})
	# If the pawn is re-fetching materials, skip job completion (already returned above).
	JobManager.complete(job)
	# Record job completion event for WorldMeaning pipeline
	if WorldMemory != null:
		var job_kind: int = WorldMemory.Kind.WORK_EVENT
		if job.type == _Job.Type.FORAGE or job.type == _Job.Type.HUNT or job.type == _Job.Type.FISH:
			job_kind = WorldMemory.Kind.FOOD_EVENT
		elif job.type == _Job.Type.PLANT_SEEDS or job.type == _Job.Type.HARVEST_CROPS:
			job_kind = WorldMemory.Kind.FOOD_EVENT
		elif job.type == _Job.Type.COOK_MEAT or job.type == _Job.Type.COOK_BERRIES or job.type == _Job.Type.COOK_FISH or job.type == _Job.Type.DRY_MEAT:
			job_kind = WorldMemory.Kind.FOOD_EVENT
		elif job.type == _Job.Type.BUILD_BED or job.type == _Job.Type.BUILD_WALL or job.type == _Job.Type.BUILD_DOOR or job.type == _Job.Type.BUILD_FIRE_PIT or job.type == _Job.Type.BUILD_STORAGE_HUT or job.type == _Job.Type.BUILD_SHELTER or job.type == _Job.Type.BUILD_HEARTH:
			job_kind = WorldMemory.Kind.BUILDING_CONSTRUCTED
		WorldMemory.record_event({
			"type": "job_completed",
			"k": job_kind,
			"r": _WM._region_key(job.work_tile.x, job.work_tile.y),
			"job_type": int(job.type),
			"pawn_id": data.id,
			"tick": GameManager.tick_count if GameManager != null else 0,
		})
	# Consume tool durability for tool-requiring jobs
	_consume_tool_durability(job.type)
	_clear_cohort_state()
	_current_job = null
	_state = State.IDLE   # reset before transitioning; _begin_haul will set it
	_clear_path()
	_request_redraw()
	# Evaluate life-path contribution on every completed job.
	_evaluate_life_path_on_job_complete(job.type)
	# Track building usage and door animation
	if _world != null and _world.has_method("record_building_usage") and job != null:
		var built_features: Array = [
			TileFeature.Type.BED, TileFeature.Type.WORKSHOP, TileFeature.Type.LOOM,
			TileFeature.Type.KILN, TileFeature.Type.SMELTER, TileFeature.Type.FIRE_PIT,
			TileFeature.Type.STORAGE_HUT, TileFeature.Type.SHELTER, TileFeature.Type.HEARTH,
		]
		var feat_at_tile: int = _world.data.get_feature(job.tile.x, job.tile.y) if _world.data != null else -1
		if feat_at_tile in built_features:
			_world.record_building_usage(job.tile)
		if _world.has_method("open_door") and feat_at_tile == TileFeature.Type.DOOR:
			_world.open_door(job.tile)
	# Harvest jobs put a fresh item in the pawn's hands -- haul it to the stockpile.
	# Build jobs don't produce anything haulable.
	if produced_type != _Item.Type.NONE:
		data.carrying = produced_type
		data.carrying_qty = produced_qty
		_begin_haul_to_stockpile()


## Place the right TileFeature for a build job, consuming the carried materials.
## If the pawn isn't carrying the right material, re-fetch instead of silently failing.
func _finish_build(job: Job) -> void:
	var mats: Dictionary = _materials_for_build(job.type)
	if mats.is_empty():
		return
	var item_type: int = mats.item
	var need_qty: int = mats.qty
	# Re-fetch if not carrying the right material (instead of silent failure)
	if data.carrying != item_type or data.carrying_qty < need_qty:
		# Try to re-fetch the material; if no stockpile has it, cancel the job
		if StockpileManager != null and StockpileManager.total_count_of(item_type) >= need_qty:
			# Reset work ticks so the pawn works again after fetching
			_current_job.work_ticks_done = 0
			_begin_fetching_material(item_type, need_qty)
			return
		else:
			if GameManager.verbose_logs():
				print("[HeelKawnian] %s build %s failed: no %s in stockpile" % [data.display_name, Job.describe_type(job.type), Item.name_for(item_type)])
			_unclaim_current_job("build_no_material")
			return
	data.carrying_qty -= need_qty
	if data.carrying_qty <= 0:
		data.clear_carry()
	match job.type:
		_Job.Type.BUILD_BED:
			_world.set_feature(job.tile.x, job.tile.y, TileFeature.Type.BED)
			_world.register_bed(job.tile)
		_Job.Type.BUILD_WALL:
			_world.build_wall(job.tile.x, job.tile.y)
		_Job.Type.BUILD_DOOR:
			_world.build_door(job.tile.x, job.tile.y)


func _current_settlement_center_region() -> int:
	if data == null:
		return -1
	var region_key: int = _WM._region_key(data.tile_pos.x, data.tile_pos.y)
	return SettlementMemory.get_center_region_for_region(region_key)


## Complete a tool-crafting job: consume materials from stockpile, equip the tool.
func _finish_craft(job: Job) -> void:
	var output_type: int = Job.tool_job_output(job.type)
	if output_type == _Item.Type.NONE:
		return
	if not Item.is_craftable(output_type):
		return
	
	# Consume materials from stockpile
	var recipe: Array = Item.get_recipe(output_type)
	if _target_zone != null and is_instance_valid(_target_zone):
		for ingredient in recipe:
			var item_type: int = int(ingredient["type"])
			var qty: int = int(ingredient["qty"])
			_target_zone.take_item(item_type, qty)
	else:
		# Fallback: consume from any stockpile via StockpileManager
		if StockpileManager != null:
			for ingredient in recipe:
				var item_type: int = int(ingredient["type"])
				var qty: int = int(ingredient["qty"])
				var remaining: int = qty
				for zone in StockpileManager.zones():
					if remaining <= 0:
						break
					var taken: int = zone.take_item(item_type, remaining)
					remaining -= taken
	
	# Equip the tool directly on the pawn
	data.equip_tool(output_type)
	
	WorldMemory.record_event({
		"type": "tool_crafted",
		"pawn_id": int(data.id),
		"pawn_name": data.display_name,
		"tool": output_type,
		"tool_name": Item.name_for(output_type),
		"tick": GameManager.tick_count,
		"tile": {"x": data.tile_pos.x, "y": data.tile_pos.y},
	})
	
	if GameManager.verbose_logs():
		print("[HeelKawnian] %s crafted and equipped %s (durability=%d)" % [
			data.display_name, Item.name_for(output_type), data.equipped_tool_durability
		])


## Complete a shelter/hearth/marker build job: consume materials, place feature.
## Also handles cooking/preservation jobs.
func _finish_shelter_build(job: Job) -> void:
	# Cooking jobs: consume materials and produce food
	if job.type == _Job.Type.COOK_MEAT or job.type == _Job.Type.COOK_BERRIES or job.type == _Job.Type.COOK_FISH or job.type == _Job.Type.DRY_MEAT:
		var output_type: int = Job.tool_job_output(job.type)
		var recipe: Array = Item.get_cooking_recipe(output_type)
		if recipe.is_empty():
			return
		
		# Verify and consume materials from carried items or stockpile
		for ingredient in recipe:
			var item_type: int = int(ingredient["type"])
			var qty: int = int(ingredient["qty"])
			# Check if pawn is carrying it
			if data.carrying == item_type and data.carrying_qty >= qty:
				data.carrying_qty -= qty
				if data.carrying_qty <= 0:
					data.clear_carry()
			elif _target_zone != null and is_instance_valid(_target_zone):
				_target_zone.take_item(item_type, qty)
		
		WorldMemory.record_event({
			"type": "food_cooked",
			"pawn_id": int(data.id),
			"pawn_name": data.display_name,
			"food_type": output_type,
			"food_name": Item.name_for(output_type),
			"tick": GameManager.tick_count,
			"tile": {"x": job.tile.x, "y": job.tile.y},
		})
		
		return
	
	var mats: Dictionary = _materials_for_build(job.type)
	if mats.is_empty():
		return
	var item_type: int = mats.item
	var need_qty: int = mats.qty
	
	# Re-fetch if not carrying the right material (instead of silent failure)
	if data.carrying != item_type or data.carrying_qty < need_qty:
		if StockpileManager != null and StockpileManager.total_count_of(item_type) >= need_qty:
			# Reset work ticks so the pawn works again after fetching
			_current_job.work_ticks_done = 0
			_begin_fetching_material(item_type, need_qty)
			return
		else:
			if GameManager.verbose_logs():
				print("[HeelKawnian] %s shelter build %s failed: no %s in stockpile" % [data.display_name, Job.describe_type(job.type), Item.name_for(item_type)])
			_unclaim_current_job("shelter_no_material")
			return
	
	# Consume materials
	data.carrying_qty -= need_qty
	if data.carrying_qty <= 0:
		data.clear_carry()
	
	# Place the feature
	match job.type:
		_Job.Type.BUILD_FIRE_PIT:
			_world.set_feature(job.tile.x, job.tile.y, TileFeature.Type.FIRE_PIT)
			WorldMemory.record_event({
				"type": "hearth_built",
				"pawn_id": int(data.id),
				"pawn_name": data.display_name,
				"tick": GameManager.tick_count,
				"tile": {"x": job.tile.x, "y": job.tile.y},
			})
		_Job.Type.BUILD_STORAGE_HUT:
			_world.set_feature(job.tile.x, job.tile.y, TileFeature.Type.STORAGE_HUT)
			WorldMemory.record_event({
				"type": "storage_built",
				"pawn_id": int(data.id),
				"pawn_name": data.display_name,
				"tick": GameManager.tick_count,
				"tile": {"x": job.tile.x, "y": job.tile.y},
			})
		_Job.Type.BUILD_MARKER_STONE:
			_world.set_feature(job.tile.x, job.tile.y, TileFeature.Type.MARKER_STONE)
			WorldMemory.record_event({
				"type": "marker_built",
				"pawn_id": int(data.id),
				"pawn_name": data.display_name,
				"tick": GameManager.tick_count,
				"tile": {"x": job.tile.x, "y": job.tile.y},
			})
		_Job.Type.BUILD_SHRINE:
			_world.set_feature(job.tile.x, job.tile.y, TileFeature.Type.SHRINE)
			WorldMemory.record_event({
				"type": "shrine_built",
				"pawn_id": int(data.id),
				"pawn_name": data.display_name,
				"tick": GameManager.tick_count,
				"tile": {"x": job.tile.x, "y": job.tile.y},
			})
		_Job.Type.BUILD_SHELTER:
			_world.set_feature(job.tile.x, job.tile.y, TileFeature.Type.BED)
			_world.register_bed(job.tile)
			WorldMemory.record_event({
				"type": "structure_built",
				"category": "construction",
				"severity": 2,
				"pawn_id": int(data.id),
				"pawn_name": data.display_name,
				"tick": GameManager.tick_count,
				"tile": {"x": job.tile.x, "y": job.tile.y},
			})
		_Job.Type.BUILD_HEARTH:
			_world.set_feature(job.tile.x, job.tile.y, TileFeature.Type.FIRE_PIT)
			WorldMemory.record_event({
				"type": "hearth_built",
				"pawn_id": int(data.id),
				"pawn_name": data.display_name,
				"tick": GameManager.tick_count,
				"tile": {"x": job.tile.x, "y": job.tile.y},
			})


## Data-driven building placement via BuildingRegistry.
## Looks up the building definition by job type, places the feature, records the event.
## Consumes carried materials if available; re-fetches if not.
func _finish_registry_build(job: Job) -> void:
	if BuildingRegistry == null:
		return
	var building: Dictionary = BuildingRegistry.get_building_by_job_type(job.type)
	if building.is_empty():
		return
	var feature_type: int = int(building.get("feature_type", TileFeature.Type.NONE))
	if feature_type == TileFeature.Type.NONE:
		return
	# Consume materials (same pattern as _finish_build)
	var mats: Dictionary = _materials_for_build(job.type)
	if not mats.is_empty():
		var item_type: int = mats.item
		var need_qty: int = mats.qty
		if data.carrying != item_type or data.carrying_qty < need_qty:
			# Re-fetch instead of silent failure
			if StockpileManager != null and StockpileManager.total_count_of(item_type) >= need_qty:
				# Reset work ticks so the pawn works again after fetching
				_current_job.work_ticks_done = 0
				_begin_fetching_material(item_type, need_qty)
				return
			else:
				if GameManager.verbose_logs():
					print("[HeelKawnian] %s registry build %s failed: no %s in stockpile" % [data.display_name, Job.describe_type(job.type), Item.name_for(item_type)])
				_unclaim_current_job("registry_no_material")
				return
		data.carrying_qty -= need_qty
		if data.carrying_qty <= 0:
			data.clear_carry()
	# Place the feature on the tile
	_world.set_feature(job.tile.x, job.tile.y, feature_type)
	# Register beds if this is a shelter-type building
	if feature_type == TileFeature.Type.BED:
		_world.register_bed(job.tile)
	# Record the building event
	var building_name: String = str(building.get("name", "Structure"))
	WorldMemory.record_event({
		"type": "structure_built",
		"category": "construction",
		"severity": 2,
		"pawn_id": int(data.id),
		"pawn_name": data.display_name,
		"building_name": building_name,
		"tick": GameManager.tick_count,
		"tile": {"x": job.tile.x, "y": job.tile.y},
	})
	# DORMANT WORLD: Unlock farm gate when first farm building completed
	if DiscoveryGate != null:
		var bcat: String = str(building.get("category", ""))
		if bcat == "agriculture":
			DiscoveryGate.unlock("first_farm")


## Consume 1 durability from the equipped tool if the job benefits from a tool.
func _consume_tool_durability(job_type: int) -> void:
	if not data.is_equipped_tool_valid():
		return
	# Only consume durability for jobs that the tool actually helps
	var efficacy: float = data.get_tool_efficacy(job_type)
	if efficacy > 1.0:
		data.use_tool()


func _cancel_current_job() -> void:
	if _current_job != null:
		_return_trade_cargo_to_source_if_any(_current_job)
		JobManager.cancel(_current_job, "pawn_cancel")
	_reset_to_idle()


func _unclaim_current_job(reason: String = "") -> void:
	if _current_job != null:
		var j0: Job = _current_job
		_return_trade_cargo_to_source_if_any(j0)
		JobManager.abandon(j0, reason)
	_reset_to_idle()


func _reset_to_idle() -> void:
	_clear_cohort_state()
	_last_recruitment_job_type = -2
	_invalidate_recruitment_signal_cache()
	_current_job = null
	# Drop any zone handle so the GC isn't rooted on a freed node after a
	# reroll. Each state that needs a zone re-picks one when it starts.
	_target_zone = null
	_state = State.IDLE
	_clear_path()
	_request_redraw()


func release_job_if_any() -> void:
	if _current_job != null:
		var j1: Job = _current_job
		_return_trade_cargo_to_source_if_any(j1)
		JobManager.cancel(j1, "release_job")
		_current_job = null
	_clear_cohort_state()
	# If we held a bed reservation from a previous life (world reroll), drop
	# it. The bed itself is gone too, but releasing keeps the dict tidy.
	_release_bed_if_reserved()


## Read-only accessor for the current AI state. UI / debug code uses this
## instead of poking _state directly.
func get_state() -> int:
	return _state


# ==================== hauling ====================

func _begin_haul_to_stockpile() -> void:
	if not data.is_carrying():
		_state = State.IDLE
		return
	var tick_now: int = GameManager.tick_count
	if tick_now < _next_haul_retry_tick:
		_state = State.IDLE
		return
	# Find the closest zone that accepts what we're carrying. "Accepts" also
	# covers the seed ALL pile, so old saves / worlds without specialized
	# zones keep working unchanged.
	var sp: Stockpile = StockpileManager.find_drop_zone(
		data.carrying, data.tile_pos, _world.pathfinder
	)
	if sp == null:
		# No zone exists that will take this item. Hold onto it and stay idle;
		# next tick we'll try again (maybe the player designated a zone).
		_log_haul_fail("no accepting zone")
		_next_haul_retry_tick = tick_now + HAUL_RETRY_COOLDOWN_TICKS
		_state = State.IDLE
		return
	_target_zone = sp
	var target_tile: Vector2i = sp.nearest_reachable_tile_to(data.tile_pos, _world.pathfinder)
	if data.tile_pos == target_tile:
		_deposit_at_stockpile()
		return
	var path: Array[Vector2i] = _path_for_pawn(target_tile)
	if path.is_empty():
		_log_haul_fail("no path")
		_next_haul_retry_tick = tick_now + HAUL_RETRY_COOLDOWN_TICKS
		_state = State.IDLE
		return
	_next_haul_retry_tick = 0
	_state = State.HAULING
	_start_path(path)
	_request_redraw()
	if GameManager.verbose_logs():
		print("[HeelKawnian] %s hauling %s -> zone %s (%d,%d), path_len=%d, from (%d,%d)" % [
			data.display_name, Item.name_for(data.carrying),
			Stockpile.FILTER_NAME.get(sp.filter, "?"),
			target_tile.x, target_tile.y, path.size(),
			data.tile_pos.x, data.tile_pos.y
		])


func _log_haul_fail(reason: String) -> void:
	var t: int = GameManager.tick_count
	if t - _last_haul_fail_log_tick < HAUL_FAIL_LOG_EVERY_N_TICKS:
		return
	_last_haul_fail_log_tick = t
	# For debug builds, print this information. Otherwise, remain silent.
	if OS.is_debug_build() and GameManager.verbose_logs():
		var my_comp: int = -1
		if _world != null and _world.pathfinder != null:
			my_comp = _world.pathfinder.component_of(data.tile_pos)
		var zone_count: int = StockpileManager.zones().size()
		print("[HeelKawnian] %s haul FAIL (%s): at (%d,%d) comp=%d  carrying=%s x%d  zones=%d" % [
			data.display_name, reason,
			data.tile_pos.x, data.tile_pos.y, my_comp,
			Item.name_for(data.carrying), data.carrying_qty, zone_count
		])


func _deposit_at_stockpile() -> void:
	var j_done: Job = _current_job
	var is_trade: bool = j_done != null and j_done.type == _Job.Type.TRADE_HAUL
	var sp: Stockpile
	if is_trade:
		if j_done.trade_to == null or not is_instance_valid(j_done.trade_to):
			_return_trade_cargo_to_source_if_any(j_done)
			JobManager.cancel(j_done, "trade_invalid")
			_current_job = null
			_target_zone = null
			_reset_to_idle()
			return
		if not sp.accepts(data.carrying):
			_return_trade_cargo_to_source_if_any(j_done)
			JobManager.cancel(j_done, "trade_rejected")
			_current_job = null
			_target_zone = null
			_reset_to_idle()
			return
	else:
		# Prefer the zone we planned for; fall back to nearest accepting zone
		# if that one somehow vanished (reroll, player deleted it mid-walk).
		sp = _target_zone
		if sp == null or not is_instance_valid(sp) or not sp.accepts(data.carrying):
			sp = StockpileManager.find_drop_zone(
					data.carrying, data.tile_pos, _world.pathfinder
			)
	if sp != null and data.is_carrying():
		# If carrying a tool, auto-equip it instead of depositing
		if Item.is_tool_type(data.carrying) and not data.is_equipped_tool_valid():
			data.equip_tool(data.carrying)
			if GameManager.verbose_logs():
				print("[HeelKawnian] %s equipped %s (durability=%d)" % [
					data.display_name, Item.name_for(data.carrying), data.equipped_tool_durability
				])
		else:
			sp.add_item(data.carrying, data.carrying_qty)
			if is_trade:
				data.add_profession_liking_for_trade_completion()
	data.clear_carry()
	_target_zone = null
	if is_trade and j_done != null and j_done.type == _Job.Type.TRADE_HAUL:
		JobManager.complete(j_done)
	_current_job = null
	_state = State.IDLE
	_clear_path()
	_request_redraw()


# ==================== eating ====================

func _maybe_start_eating() -> bool:
	var eat_threshold: float = HUNGER_EAT_THRESHOLD + lerpf(-5.0, 5.0, _bp(6))
	if data.neural_network != null and str(data.neural_network.get_autonomy_hint()) == "eat":
		eat_threshold += 14.0
	if data.hunger >= eat_threshold:
		return false
	if data.is_carrying():
		# Carrying something -- finish that errand first.
		return false
	var sp: Stockpile = StockpileManager.find_food_source(data.tile_pos, _world.pathfinder)
	if sp == null:
		return false
	if data.neural_network != null and str(data.neural_network.get_autonomy_hint()) == "eat":
		_notify_autonomy_feedback("go eat")
	_begin_going_to_eat(sp)
	return true


func _begin_going_to_eat(sp: Stockpile) -> void:
	_target_zone = sp
	var target_tile: Vector2i = sp.nearest_tile_to(data.tile_pos)
	if data.tile_pos == target_tile:
		_begin_eating()
		return
	var path: Array[Vector2i] = _path_for_pawn(target_tile)
	if path.is_empty():
		return
	_state = State.GOING_TO_EAT
	_start_path(path)
	_request_redraw()


func _begin_eating() -> void:
	var sp: Stockpile = _target_zone
	if sp == null or not is_instance_valid(sp) or not sp.has_any_food():
		# The zone we planned for got emptied; try another.
		sp = StockpileManager.find_food_source(data.tile_pos, _world.pathfinder)
	if sp == null:
		_target_zone = null
		_reset_to_idle()
		return
	_target_zone = sp
	_state = State.EATING
	_eat_ticks_left = EAT_TICKS
	_request_redraw()


func _finish_eating() -> void:
	var sp: Stockpile = _target_zone
	var food_type: int = _Item.Type.NONE
	var gain: float = 0.0
	if sp == null or not is_instance_valid(sp):
		sp = StockpileManager.find_food_source(data.tile_pos, _world.pathfinder)
	if sp != null:
		food_type = sp.pick_food()
		if food_type != _Item.Type.NONE:
			var taken: int = sp.take_item(food_type, 1)
			if taken > 0:
				gain = Item.hunger_restore(food_type)
				data.hunger = min(100.0, data.hunger + gain)
				data.mood = min(100.0, data.mood + MOOD_BONUS_ATE)
				_play_sfx("res://assets/audio/pawn_eat.ogg", 1.0)
				# Eating meat brings more joy than berries
				if food_type == _Item.Type.MEAT:
					data.add_mood_event(MoodEvent.Type.JOY, 70.0, 200)
				else:
					data.add_mood_event(MoodEvent.Type.JOY, 40.0, 150)
				# After eating, reset warning band so we don't re-log instantly.
				_hunger_level = _level_for(data.hunger)
	_target_zone = null
	_reset_to_idle()


# ==================== sleep ====================

## Returns true and starts sleeping if the pawn is tired enough. Called from
## _tick_idle, so this only fires when nothing more urgent is happening.
##
## Bed preference: try to reserve and walk to the nearest free bed. If no bed
## is reachable, lie down on the spot (slower recovery, but better than dying).
func _maybe_start_sleeping() -> bool:
	# Anti-oscillation: don't go back to sleep immediately after waking.
	# The wake threshold (70) is below the max possible sleep threshold (74),
	# so without this cooldown a pawn would wake and re-sleep every tick.
	if GameManager != null and (GameManager.tick_count - _woke_tick) < 20:
		return false
	# At night the threshold is raised so well-rested pawns still go to bed
	# when the sun goes down, giving the colony a real day/night rhythm.
	var base_th: float = REST_SLEEP_THRESHOLD_NIGHT if DayNightCycle.is_night_for_tick(GameManager.tick_count) else REST_SLEEP_THRESHOLD
	var threshold: float = base_th + lerpf(-7.0, 7.0, _bp(2))
	if data.neural_network != null:
		var ah: String = str(data.neural_network.get_autonomy_hint())
		if ah == "sleep":
			threshold += 12.0
		elif ah == "shelter":
			threshold += 9.0
	if data.rest > threshold:
		return false
	# Don't curl up while starving -- if there's any food path open we should
	# have taken it already in step 3, but if we got here it means no food is
	# reachable and sleeping won't fix that.
	if data.hunger <= HUNGER_EMERGENCY:
		return false
	# Don't sleep mid-haul; stockpile that item first.
	if data.is_carrying():
		return false
	var autonomy_rest_lbl: String = ""
	if data.neural_network != null:
		var ah2: String = str(data.neural_network.get_autonomy_hint())
		if ah2 == "sleep" or ah2 == "shelter":
			autonomy_rest_lbl = ah2
	if _try_walk_to_bed():
		if not autonomy_rest_lbl.is_empty():
			_notify_autonomy_feedback("rest â†’ %s" % autonomy_rest_lbl)
		return true
	_begin_sleeping()
	if not autonomy_rest_lbl.is_empty():
		_notify_autonomy_feedback("rest â†’ %s" % autonomy_rest_lbl)
	return true


## Check if pawn can teach knowledge to nearby pawn
func _maybe_start_teaching() -> bool:
	if data == null or _world == null or GameManager == null:
		return false
	# Needs enough comfort to mentor; still below eating/sleep gates in [_tick_idle].
	if data.hunger < HUNGER_EAT_THRESHOLD + 8.0:
		return false
	if data.rest < REST_SLEEP_THRESHOLD + 10.0:
		return false
	# Throttle: cheap social layer, not a per-tick O(n) scan.
	var tick: int = GameManager.tick_count
	var teach_period: int = int(round(lerpf(19.0, 29.0, 1.0 - _founding_blend())))
	if posmod(tick + int(data.id) * 7, maxi(1, teach_period)) != 0:
		return false
	var spawner: PawnSpawner = _resolve_pawn_spawner()
	if spawner == null:
		return false
	var best_peer: HeelKawnian = null
	var best_d: int = 1_000_000
	var seen: int = 0
	for p in spawner.pawns:
		seen += 1
		if seen > 24:
			break
		if p == null or not is_instance_valid(p) or p == self or p.data == null:
			continue
		var d2: int = data.tile_pos.distance_squared_to(p.data.tile_pos)
		if d2 > 81:
			continue
		if d2 < best_d:
			best_d = d2
			best_peer = p
	if best_peer == null:
		return false
	var sk: String = data.highest_affinity_skill()
	var my_xp: int = data.tracked_skill_xp(sk)
	var peer_xp: int = best_peer.data.tracked_skill_xp(sk)
	if my_xp + 6 <= peer_xp:
		return false
	var student_learned: bool = best_peer.data.gain_skill_xp(sk, 2)
	data.add_social_rapport(int(best_peer.data.id), 2)
	best_peer.data.add_social_rapport(int(data.id), 2)
	data.mood = min(100.0, data.mood + 0.4)
	best_peer.data.mood = min(100.0, best_peer.data.mood + 0.35)
	data.learn_semantic_fact(
			"action_success:teach",
			{"peer_id": int(best_peer.data.id), "skill": sk},
			0.55,
            "mentoring"
	)
	if student_learned:
		_record_teaching_memory_fact(best_peer, sk)
	return true


func _record_teaching_memory_fact(student: HeelKawnian, skill_taught: String) -> void:
	if WorldMemory == null or GameManager == null or data == null:
		return
	if student == null or not is_instance_valid(student) or student.data == null:
		return
	var tick: int = GameManager.tick_count
	if tick - _last_teaching_memory_event_tick < TEACHING_MEMORY_EVENT_MIN_INTERVAL_TICKS:
		return
	_last_teaching_memory_event_tick = tick
	var settlement_id: int = int(data.settlement_id)
	if settlement_id < 0:
		settlement_id = int(student.data.settlement_id)
	WorldMemory.record_teaching_event(
			tick,
			data.tile_pos,
			int(data.id),
			data.display_name,
			int(student.data.id),
			student.data.display_name,
			skill_taught,
			settlement_id
	)


## Check if pawn can challenge nearby pawn's authority
func _maybe_start_challenge() -> bool:
	return false


func _resolve_pawn_spawner() -> PawnSpawner:
	var main_node: Node = get_tree().get_root().get_node_or_null("Main")
	if main_node == null:
		return null
	return main_node.get_node_or_null("WorldViewport/PawnSpawner") as PawnSpawner


func _try_walk_to_bed() -> bool:
	if _world == null:
		return false
	var bed: Vector2i = _world.find_free_bed_for(self, data.tile_pos)
	if bed.x < 0:
		return false
	if not _world.reserve_bed(bed, self):
		return false
	_reserved_bed = bed
	if data.tile_pos == bed:
		_begin_sleeping()
		return true
	var path: Array[Vector2i] = _path_for_pawn(bed)
	if path.is_empty():
		# Reservation failed in practice: release it and fall back to floor.
		_world.release_bed(bed, self)
		_reserved_bed = Vector2i(-1, -1)
		return false
	_state = State.GOING_TO_BED
	_start_path(path)
	_request_redraw()
	return true


func _arrive_at_bed() -> void:
	# We may have been bumped off our reservation by a regen / world reset.
	# Re-confirm before sleeping.
	if _reserved_bed.x < 0 or not _world.is_bed_owned_by(_reserved_bed, self):
		_reserved_bed = Vector2i(-1, -1)
	_begin_sleeping()


func _begin_sleeping() -> void:
	_state = State.SLEEPING
	_clear_path()
	_request_redraw()
	# `where` string for logs could be re-added if verbose_logs are re-enabled.
	# var on_bed: bool = _reserved_bed.x >= 0 and data.tile_pos == _reserved_bed
	# var where: String = " in a bed" if on_bed else ""
	# if GameManager.verbose_logs():
	# 	print("[HeelKawnian] %s lies down to sleep%s  (rest=%.1f)" % [data.display_name, where, data.rest])


## Per-tick while in SLEEPING. The actual rest restoration / hunger decay
## happens in _decay_needs (which checks the state). Here we only handle
## the wake conditions.
func _tick_sleeping() -> void:
	# Wake up when well-rested
	if data.rest >= REST_WAKE_THRESHOLD:
		_release_bed_if_reserved()
		_woke_tick = GameManager.tick_count
		_reset_to_idle()
		return
	# Wake up early if we get critically hungry -- food trumps sleep.
	if data.hunger <= HUNGER_EMERGENCY:
		_release_bed_if_reserved()
		_woke_tick = GameManager.tick_count
		_reset_to_idle()
		return
	
	# Crisis wake-up: if housing pressure is critical, wake builders to address it.
	# Only check periodically to avoid per-tick overhead on all sleeping pawns.
	if posmod(GameManager.tick_count + int(data.id), 30) == 0:
		var housing_pressure: float = 0.0
		var food_pressure: float = 0.0
		if ColonySimServices != null:
			housing_pressure = ColonySimServices.get_housing_pressure()
			food_pressure = ColonySimServices.get_food_pressure()
		
		# Crisis threshold: housing > 80% or food > 70%
		var is_housing_crisis: bool = housing_pressure > 0.8
		var is_food_crisis: bool = food_pressure > 0.7
		
		if is_housing_crisis or is_food_crisis:
			# Wake pawns with relevant affinities to address the crisis
			var building_affinity: float = float(data.affinities.get("building", 0.5))
			var farming_affinity: float = float(data.affinities.get("farming", 0.5))
			
			# Wake builders during housing crisis, gatherers during food crisis
			var should_wake: bool = false
			if is_housing_crisis and building_affinity > 0.6:
				should_wake = true
			elif is_food_crisis and farming_affinity > 0.6:
				should_wake = true
			
			if should_wake:
				_release_bed_if_reserved()
				_woke_tick = GameManager.tick_count
				_reset_to_idle()
				return


# ==================== combat ====================

func _engage_enemies() -> void:
	# DISABLED for performance - iterates through all enemies
	return


## Drop any bed reservation we hold. Safe to call multiple times.
func _release_bed_if_reserved() -> void:
	if _reserved_bed.x < 0:
		return
	if _world != null:
		_world.release_bed(_reserved_bed, self)
	_reserved_bed = Vector2i(-1, -1)


## Emergency food path: consume one unit of whatever food the pawn is
## carrying, then drop back to IDLE. No stockpile interaction, no eating
## state -- the pawn just wolfs it down on the spot.
func _eat_from_hand() -> void:
	if not data.is_carrying() or not Item.is_food(data.carrying):
		return
	var food_type: int = data.carrying
	var gain: float = Item.hunger_restore(food_type)
	data.hunger = min(100.0, data.hunger + gain)
	data.mood = min(100.0, data.mood + MOOD_BONUS_ATE)
	data.carrying_qty -= 1
	if data.carrying_qty <= 0:
		data.clear_carry()
	_hunger_level = _level_for(data.hunger)
	_request_redraw()


# ==================== needs ====================

func _decay_needs() -> void:
	# Sleeping pawns metabolize slower and recover rest instead of losing it.
	# A bed that the pawn has reserved AND is currently standing on grants a
	# faster recovery rate -- the payoff for hauling wood and building.
	# Everything else (mood, etc.) decays normally so a 24-hour nap still
	# erodes happiness.
	
	# Get trait multipliers
	var hunger_mult: float = data.get_trait_mult("hunger_decay_mult")
	var rest_mult: float = data.get_trait_mult("rest_decay_mult")
	var mood_mult: float = data.get_trait_mult("mood_decay_mult")
	
	var pace_h: float = lerpf(0.86, 1.15, _bp(0))
	var pace_r: float = lerpf(0.86, 1.15, _bp(1))
	if _state == State.SLEEPING:
		data.hunger = data.hunger - HUNGER_DECAY_PER_TICK_SLEEPING * hunger_mult * pace_h
		var rate: float = REST_RECOVER_PER_TICK_SLEEP
		if _reserved_bed.x >= 0 and data.tile_pos == _reserved_bed and _world != null and _world.is_bed_owned_by(_reserved_bed, self):
			rate *= REST_RECOVER_BED_MULTIPLIER
		data.rest = min(100.0, data.rest + rate)
		# Health recovery while sleeping â€” injuries heal during rest
		var heal_rate: float = HEALTH_RECOVER_PER_TICK_SLEEP
		if _reserved_bed.x >= 0 and data.tile_pos == _reserved_bed and _world != null and _world.is_bed_owned_by(_reserved_bed, self):
			heal_rate *= HEALTH_RECOVER_BED_MULTIPLIER
		if data.health < data.max_health:
			data.health = min(data.max_health, data.health + heal_rate)
	else:
		data.hunger = data.hunger - HUNGER_DECAY_PER_TICK * hunger_mult * pace_h
		data.rest   = data.rest   - REST_DECAY_PER_TICK * rest_mult * pace_r
	
	# Mood: net loss when needs aren't met, net gain when they are.
	# Passive contentment outpaces decay, so a pawn whose hunger AND rest are
	# both comfortable will recover happiness on their own.
	# Mood events also contribute their own delta - throttled to every 10 ticks
	var mood_event_impact: float = 0.0
	if GameManager.tick_count % 10 == 0:
		data.process_mood_events()
		mood_event_impact = data.get_mood_event_impact()
	
	if data.hunger >= MOOD_CONTENT_FLOOR and data.rest >= MOOD_CONTENT_FLOOR:
		data.mood = clampf(data.mood + MOOD_GAIN_PER_TICK_CONTENT - MOOD_DECAY_PER_TICK * mood_mult + mood_event_impact + data.kinship_mood_bonus(), 0.0, 100.0)
	else:
		data.mood = clampf(data.mood - MOOD_DECAY_PER_TICK * mood_mult + mood_event_impact + data.kinship_mood_bonus(), 0.0, 100.0)
	# Occasional uplift â€” same world rules, but some people notice small good moments more often.
	if posmod(GameManager.tick_count + int(data.id) * 5, 211) == 0:
		var flutter: float = 0.1 + _bp(4) * 0.22
		if WorldRNG.chance_for(StringName("pawn_natural_mood:%d" % int(data.id)), flutter, GameManager.tick_count / 200):
			data.mood = min(100.0, data.mood + lerpf(0.15, 1.1, _bp(7)))
	
	# Historically used land: subtle mood drain from nearby past deaths / builds - throttled to every 30 ticks
	if GameManager.tick_count % 30 == 0:
		var wt_node: Node = get_tree().get_root().get_node_or_null("Main/WorldTrace")
		if wt_node != null and wt_node is WorldTrace:
			data.mood = max(0.0, data.mood - (wt_node as WorldTrace).get_mood_drain_at(data.tile_pos))
	
	# Phase 5: Proximity stress from being near grudge-enemies - throttled to every 10 ticks
	if GameManager.tick_count % 10 == 0:
		var stress_drain: float = get_proximity_stress_drain()
		if stress_drain > 0.0:
			data.mood = max(0.0, data.mood - stress_drain)
	
	# Stage 1: Decay stamina based on activity - throttled to every 5 ticks
	if GameManager.tick_count % 5 == 0:
		_decay_stamina()
	
	# Stage 1: Check temperature exposure - throttled to every 10 ticks
	if GameManager.tick_count % 10 == 0:
		_check_temperature()
	
	# Stage 1: Process injuries and pain - throttled to every 5 ticks
	if GameManager.tick_count % 5 == 0:
		_process_injuries()
	
	# Stage 1: Observe nearby work (learning by observation) - DISABLED for performance
	# _observe_nearby_work()
	
	# Stage 1: Update perception and location memory - throttled to every 20 ticks
	if posmod(GameManager.tick_count + int(data.id), 20) == 0:
		_update_perception()

	# PERFORMANCE: Tick rate decoupling for social AI (every 5 ticks instead of every tick)
	if _tick_rate_decoupler != null and _tick_rate_decoupler.should_update("Social"):
		# Stage 2: Co-presence using SpatialGrid for O(1) neighbor queries
		if _spatial_grid != null:
			_track_co_presence_spatial()
		else:
			# Fallback to old method if SpatialGrid not available
			if posmod(GameManager.tick_count + int(data.id) * 3, 37) == 0:
				_track_co_presence_light()

	# Stage 1: Decay unused skills (throttled to once per day)
	if GameManager.tick_count % DayNightCycle.TICKS_PER_DAY == 0:
		data.decay_unused_skills()
	
	# Stage 3-4: Track clan/settlement contributions - DISABLED for performance
	# if _state == State.WORKING and _current_job != null:
	# 	var job_type_str: String = Job.describe_type(_current_job.type).to_lower()
	# 	contribute_to_clan_labor(job_type_str)
	# 	if data.settlement_id != -1:
	# 		if _current_job.type == _Job.Type.FORAGE or _current_job.type == _Job.Type.HUNT:
	# 			record_food_production(1)
	# 		elif _current_job.type == _Job.Type.BUILD_BED or _current_job.type == _Job.Type.BUILD_WALL or _current_job.type == _Job.Type.BUILD_DOOR:
	# 			record_building_construction()
	
	# Crisis behavior: very low mood causes pawns to refuse work (strike)
	var crisis_level: float = data.get_crisis_level()
	if crisis_level > 0.8 and WorldRNG.chance_for(_pawn_stream("crisis_strike"), 0.05, _pawn_salt(41)):
		_trigger_crisis_strike()
	
	# One in-world year every SimTime.TICKS_PER_SIM_YEAR ticks (see docs/TIME_SCALE.md).
	data.age_years += 1.0 / float(SimTime.TICKS_PER_SIM_YEAR)
	if data.age_years > 70.0 and WorldRNG.chance_for(_pawn_stream("old_age"), 0.00001, _pawn_salt(43)):
		_die("old_age")
		return
	# Death from starvation, exhaustion, or injury
	_check_death_conditions()


func _publish_player_body_needs_to_hud_if_incarnated() -> void:
	if data == null or get_tree() == null:
		return
	var root: Window = get_tree().get_root()
	if root == null:
		return
	var main_node: Node = root.get_node_or_null("Main")
	if main_node == null:
		return
	if not main_node.has_method("is_player_incarnated") or not main_node.has_method("get_player_pawn_id"):
		return
	if not bool(main_node.call("is_player_incarnated")):
		return
	if int(main_node.call("get_player_pawn_id")) != int(data.id):
		return
	var hud: Node = root.get_node_or_null("Main/UI_Viewport/ColonyHUD")
	if hud == null:
		hud = root.get_node_or_null("ColonyHUD")
	if hud != null and hud.has_method("update_player_needs"):
		hud.call("update_player_needs", data.hunger, data.rest)


## Crisis strike: pawn refuses to work when mood is critical.
func _trigger_crisis_strike() -> void:
	# Release current job and enter idle state
	if _current_job != null:
		_unclaim_current_job()
	_state = State.IDLE
	# Add DESPAIR mood event
	if not data.has_trait(Trait.Type.PESSIMIST):  # Pessimists expect this already
		data.add_mood_event(MoodEvent.Type.DESPAIR, 75.0, 400)


func _check_death_conditions() -> void:
	# Grace period: newborn pawns can't die in first 1500 ticks
	# This gives them time to find food, build shelter, get oriented
	# At 100x speed, 1500 ticks = ~15 seconds real time
	var age: int = maxi(GameManager.tick_count - data.birth_tick, 0)
	if age < 1500:
		# During grace: clamp health to minimum 20, hunger to minimum -3
		if data.health < 20.0:
			data.health = 20.0
		if data.hunger < -3.0:
			data.hunger = -3.0
		return
	
	# Emergency food-seeking for AI agents
	if data.hunger < 15.0 and _state != State.GOING_TO_EAT and _state != State.EATING:
		# If carrying food, eat it right now â€” don't walk to a stockpile.
		if data.is_carrying() and Item.is_food(data.carrying):
			_eat_from_hand()
			return
		_emergency_seek_food()
		# Record near-death starvation to consciousness
		if data.hunger < 10.0:
			_record_consciousness_event("near_death", "Starving â€” hunger at %.0f" % data.hunger, -80.0, 9, "survival")
	
	# More lenient death conditions
	if data.hunger <= -5.0:  # Allow some buffer before death
		_die("")
		return
	if data.rest <= -5.0:  # Allow some buffer before death
		_die("")
		return
	if data.health <= 0.0:
		_die("")
		return

func _emergency_seek_food() -> void:
	# Release current job to prioritize survival
	if _current_job != null:
		_unclaim_current_job()
	
	var pathfinder: PathFinder = _world.pathfinder if _world != null else null
	var stockpile: Stockpile = StockpileManager.find_food_source(data.tile_pos, pathfinder)
	if stockpile != null:
		_begin_going_to_eat(stockpile)
	else:
		pass # No emergency food source found.


func _decay_stamina() -> void:
	# Stamina depletes with work, recovers with rest
	var stamina_decay: float = 0.0
	var stamina_recover: float = 0.0
	
	if _state == State.SLEEPING:
		stamina_recover = 2.0  # Fast recovery when sleeping
	elif _state == State.WORKING:
		stamina_decay = 1.5  # Moderate decay when working
	elif _state == State.WALKING_TO_JOB or _state == State.HAULING:
		stamina_decay = 0.8  # Light decay when moving
	elif _state == State.IDLE:
		stamina_recover = 0.5  # Slow recovery when idle
	
	# Apply trait modifiers
	var stamina_mult: float = data.get_trait_mult("stamina_decay_mult")
	stamina_decay *= stamina_mult
	stamina_recover *= stamina_mult
	
	# Pain reduces stamina recovery
	if data.pain > 50.0:
		stamina_recover *= 0.5
	
	data.stamina = clamp(data.stamina - stamina_decay + stamina_recover, 0.0, 100.0)


func _ambient_temperature_celsius_at_tile(tile: Vector2i) -> float:
	if _world == null or _world.data == null:
		return 18.0
	var bio: int = _world.data.get_biome(tile.x, tile.y)
	var base: float = 18.0
	match bio:
		Biome.Type.DESERT:
			base = 32.0
		Biome.Type.TUNDRA:
			base = -2.0
		Biome.Type.FOREST:
			base = 16.0
		Biome.Type.PLAINS:
			base = 18.0
		Biome.Type.MOUNTAIN:
			base = 8.0
		Biome.Type.WATER:
			base = 10.0
		Biome.Type.STONE_FLOOR:
			base = 14.0
	var elev: float = _world.data.get_elevation(tile.x, tile.y)
	base += (elev - 0.5) * 8.0
	var moist: float = _world.data.get_moisture(tile.x, tile.y)
	base -= (moist - 0.5) * 2.0
	if GameManager != null and DayNightCycle.is_night_for_tick(GameManager.tick_count):
		base -= 4.5
	# Weather effect on ambient temperature
	if _world != null:
		var weather_overlay: Node = get_node_or_null("/root/Main/WeatherOverlay")
		if weather_overlay != null and weather_overlay.has_method("get_current_weather"):
			var weather: String = weather_overlay.get_current_weather()
			match weather:
				"rain":
					base -= 4.0
				"snow":
					base -= 10.0
				"sand":
					base += 5.0
				"embers":
					base += 3.0
			# Wind chill in cold precipitation
			if weather == "rain" or weather == "snow":
				var wind_system: Node = get_node_or_null("/root/WindSystem")
				if wind_system != null and wind_system.has_method("get_wind_strength"):
					base -= wind_system.get_wind_strength() * 4.0
	return base


func _hearth_proxy_warmth_bonus(tile: Vector2i) -> float:
	if _world == null or _world.data == null:
		return 0.0
	var bonus: float = 0.0
	for dx in range(-2, 3):
		for dy in range(-2, 3):
			var t: Vector2i = tile + Vector2i(dx, dy)
			if not _world.data.in_bounds(t.x, t.y):
				continue
			var feat: int = int(_world.data.get_feature(t.x, t.y))
			# Use BuildingRegistry buffs if available
			if BuildingRegistry != null:
				var buffs: Dictionary = BuildingRegistry.buffs_for_feature(feat)
				if buffs.has("warmth"):
					bonus = maxf(bonus, float(buffs["warmth"]))
			# Fallback for known features
			if feat == TileFeature.Type.FIRE_PIT:
				bonus = maxf(bonus, 8.0)
			elif feat == TileFeature.Type.BED:
				bonus = maxf(bonus, 3.0)
	return bonus


## Gear warmth bonus from equipped armor/accessories
func _gear_warmth_bonus() -> float:
	if data == null:
		return 0.0
	var gear_stats: Dictionary = data.get_gear_stats()
	return float(gear_stats.get("warmth", 0.0))


func _check_temperature() -> void:
	if _world == null or data == null:
		return
	
	var ambient_temp: float = _ambient_temperature_celsius_at_tile(data.tile_pos)
	ambient_temp += _hearth_proxy_warmth_bonus(data.tile_pos)
	ambient_temp += _gear_warmth_bonus()
	var has_shelter: bool = false
	if _reserved_bed.x >= 0 and data.tile_pos == _reserved_bed:
		has_shelter = true
	if has_shelter:
		ambient_temp += 4.0
	
	# Wetness tracking from weather precipitation
	var is_wet: bool = false
	var weather_overlay: Node = get_node_or_null("/root/Main/WeatherOverlay")
	if weather_overlay != null and weather_overlay.has_method("is_precipitating"):
		if weather_overlay.is_precipitating():
			data.wetness = minf(100.0, data.wetness + 1.0)
			is_wet = data.wetness > 50.0
		else:
			# Shelter accelerates drying
			var dry_rate: float = 0.5
			if has_shelter:
				dry_rate = 1.5
			data.wetness = maxf(0.0, data.wetness - dry_rate)
	elif data.wetness > 0.0:
		data.wetness = maxf(0.0, data.wetness - 0.5)
	
	# When wet, cold ambient feels colder (wind chill amplification)
	if is_wet and ambient_temp < 15.0:
		ambient_temp -= 4.0
	
	# Grace period: first ticks of life, pawns resist cold
	# DORMANT WORLD: Pioneer pawns (first generation) get extended grace (5000 ticks)
	# Regular pawns get standard grace (2500 ticks)
	var age: int = maxi(GameManager.tick_count - data.birth_tick, 0)
	var grace_duration: int = 2500
	if data.is_pioneer:
		grace_duration = 5000
		# Tick down pioneer counter
		if data.pioneer_ticks_remaining > 0:
			data.pioneer_ticks_remaining -= 1
	var grace_remaining: float = clampf(1.0 - float(age) / float(grace_duration), 0.0, 1.0)
	
	var temp_change_rate: float = 0.05 if has_shelter else 0.1
	if grace_remaining > 0.0:
		# During grace: body temp drops 5x slower toward cold ambient
		if ambient_temp < data.body_temperature:
			temp_change_rate *= 0.2
		# Grace warmth: body temp stays closer to 37Â°C
		var grace_target: float = lerp(ambient_temp, 37.0, grace_remaining * 0.6)
		data.body_temperature = lerp(data.body_temperature, grace_target, temp_change_rate)
	else:
		data.body_temperature = lerp(data.body_temperature, ambient_temp, temp_change_rate)
	
	# Accumulate hypothermia/heat exhaustion risk
	if data.body_temperature < 35.0:
		# During grace period, hypothermia risk accumulates 4x slower
		var hypo_rate: float = 0.2 * (1.0 - grace_remaining * 0.75)
		# Wetness amplifies hypothermia risk
		if is_wet:
			hypo_rate *= 2.0
		data.hypothermia_risk = min(100.0, data.hypothermia_risk + hypo_rate)
	elif data.body_temperature > 38.0:
		data.heat_exhaustion_risk = min(100.0, data.heat_exhaustion_risk + 0.2)
	else:
		# Recover from temperature risks when in normal range
		data.hypothermia_risk = max(0.0, data.hypothermia_risk - 0.1)
		data.heat_exhaustion_risk = max(0.0, data.heat_exhaustion_risk - 0.1)
	
	# Hypothermia causes health damage and can lead to frostbite
	# During grace period, damage is suppressed
	if data.hypothermia_risk > 80.0:
		var dmg: float = 0.1 * (1.0 - grace_remaining * 0.9)
		data.health = max(0.0, data.health - dmg)
		data.exposure_sickness = min(100.0, data.exposure_sickness + 0.05 * (1.0 - grace_remaining * 0.8))
		# Severe hypothermia causes frostbite (suppressed during grace)
		if data.hypothermia_risk > 95.0 and GameManager.tick_count % 200 == 0 and grace_remaining < 0.1:
			BodyRiskManager.apply_injury(self, BodyRiskManager.InjuryType.FROSTBITE, 5.0, "cold_exposure")
	
	# Heat exhaustion causes health damage
	if data.heat_exhaustion_risk > 80.0:
		data.health = max(0.0, data.health - 0.1)


func _process_injuries() -> void:
	# BodyRiskManager handles all injury recovery on its own tick schedule
	# This function is kept for backwards compatibility and pain visualization
	pass


func _observe_nearby_work() -> void:
	# DISABLED for performance - iterates through all pawns
	return
	

func can_teach_skill(target_pawn: HeelKawnian) -> bool:
	# Check if teaching is allowed (cooldown, etc.)
	if GameManager.tick_count - _last_teach_tick < _teach_cooldown_ticks:
		return false
	# Can add more conditions here (distance, etc.)
	return true


func teach_skill(target_pawn: HeelKawnian, skill: int) -> bool:
	# Teach a skill to another pawn
	# Requires: teacher has skill level >= 5, target has lower skill level
	
	# Check cooldown first
	if not can_teach_skill(target_pawn):
		return false
	if data == null or target_pawn == null or not is_instance_valid(target_pawn) or target_pawn.data == null:
		return false
	var teacher_level: int = data.get_skill_level(skill)
	var target_level: int = target_pawn.data.get_skill_level(skill)
	
	if teacher_level < 5 or target_level >= teacher_level:
		return false
	
	# Grant XP to target (faster than self-learning); teaching branch boosts output.
	var te: float = data.teach_efficiency_multiplier() * data.kinship_teach_efficiency_multiplier(int(target_pawn.data.id))
	target_pawn.data.add_skill_xp(skill, HeelKawnianData.XP_PER_WORK_TICK * 2.0 * te)
	
	# Small XP bonus to teacher for teaching
	data.add_skill_xp(skill, HeelKawnianData.XP_PER_WORK_TICK * 0.5 * te)
	_record_teaching_memory_fact(target_pawn, HeelKawnianData.skill_name(skill).to_lower())
	
	# Update cooldown timestamp
	_last_teach_tick = GameManager.tick_count

	# PAWN-ACTIVATED EVENT: Record teaching for event system
	if WorldEvents != null and WorldEvents.has_method("record_pawn_action"):
		WorldEvents.record_pawn_action("teaching", int(data.id))

	# Track student progress
	var student_id: int = int(target_pawn.data.id)
	if not _students_taught.has(student_id):
		_students_taught[student_id] = {"skill": skill, "ticks_taught": 0}
	_students_taught[student_id]["ticks_taught"] = int(_students_taught[student_id].get("ticks_taught", 0)) + 1
	_students_taught[student_id]["skill"] = skill
	
	return true


func _inherit_knowledge_from_parents(_parent_a_id: int, _parent_b_id: int) -> void:
	# DISABLED for performance - iterates through all pawns
	# Children inherit some knowledge from parents
	# This is called during pawn creation
	return


func _update_perception() -> void:
	# Update perception radius based on level
	# Base radius 50, +10 per level, max 200
	data.perception_radius = clamp(50.0 + float(data.level) * 10.0, 50.0, 200.0)
	# Remember resources and dangers in perception radius.
	# Use an incremental deterministic scan budget to avoid large full-radius
	# spikes from many pawns scanning on the same tick.
	if _world == null or _world.data == null:
		return
	var radius_tiles: int = int(data.perception_radius / float(World.TILE_PIXELS))
	if radius_tiles <= 0:
		return
	var diameter: int = radius_tiles * 2 + 1
	var area: int = diameter * diameter
	if area <= 0:
		return
	var scan_budget: int = 24
	if GameManager != null:
		var gs: float = GameManager.game_speed
		if gs >= 50.0:
			scan_budget = 8
		elif gs >= 12.0:
			scan_budget = 12
		elif gs >= 6.0:
			scan_budget = 16
	var stride: int = maxi(1, int(ceil(float(area) / float(maxi(1, scan_budget)))))
	var current_tick: int = GameManager.tick_count
	var sampled: int = 0
	var idx: int = _perception_scan_cursor
	while sampled < scan_budget:
		var local_x: int = (idx % diameter) - radius_tiles
		var local_y: int = int(idx / diameter) - radius_tiles
		var tile: Vector2i = data.tile_pos + Vector2i(local_x, local_y)
		if _world.data.in_bounds(tile.x, tile.y):
			var feature: int = _world.data.get_feature(tile.x, tile.y)
			var resource_type: String = ""
			if feature == TileFeature.Type.FERTILE_SOIL:
				resource_type = "berry"
			elif feature == TileFeature.Type.TREE:
				resource_type = "wood"
			elif feature == TileFeature.Type.ORE_VEIN:
				resource_type = "stone"
			elif feature == TileFeature.Type.RABBIT or feature == TileFeature.Type.DEER:
				resource_type = "meat"
			var danger_level: float = 0.0
			if int(_world.data.get_biome(tile.x, tile.y)) == Biome.Type.WATER:
				danger_level = 0.45
			if int(feature) == TileFeature.Type.RUIN:
				danger_level = maxf(danger_level, 0.35)
			danger_level = maxf(danger_level, float(_scar_level_at_tile(tile)) / 4.0)
			if resource_type != "" or danger_level > 0.0:
				var tile_key: String = "%d,%d" % [tile.x, tile.y]
				data.location_memory[tile_key] = {
					"last_seen": current_tick,
					"resource_type": resource_type,
					"danger_level": danger_level
				}
		sampled += 1
		idx = (idx + stride) % area
	_perception_scan_cursor = idx


func _get_tiles_in_radius(radius: float) -> Array:
	# Get all tiles within perception radius
	var tiles: Array = []
	var radius_tiles: int = int(radius / 16.0)  # Assuming 16 pixels per tile
	
	for dx in range(-radius_tiles, radius_tiles + 1):
		for dy in range(-radius_tiles, radius_tiles + 1):
			var tile: Vector2i = data.tile_pos + Vector2i(dx, dy)
			if _world != null and _world.data != null and _world.data.in_bounds(tile.x, tile.y):
				tiles.append(tile)
	
	return tiles


func assess_risk(tile: Vector2i) -> float:
	# DISABLED for performance - iterates through all enemies
	return 0.0


func remember_resources(tile: Vector2i, resource_type: String) -> void:
	var tile_key: String = "%d,%d" % [tile.x, tile.y]
	var current_tick: int = GameManager.tick_count if GameManager != null else 0
	
	data.location_memory[tile_key] = {
		"last_seen": current_tick,
		"resource_type": resource_type,
		"danger_level": 0.0
	}


## Stage 2: Family & Trust system

## Get grudge intensity toward another pawn (Phase 5: Emergent Life)
func get_grudge_toward(other_pawn_id: int) -> float:
	if SocialManager.get_grudge_manager() != null and SocialManager.get_grudge_manager().has_method("get_grudge_intensity"):
		return SocialManager.get_grudge_manager().get_grudge_intensity(int(data.id), other_pawn_id)
	return 0.0

## Check if pawn has a grudge against another pawn
func has_grudge_against(other_pawn_id: int, min_intensity: float = 0.3) -> bool:
	if SocialManager.get_grudge_manager() != null and SocialManager.get_grudge_manager().has_method("has_grudge"):
		return SocialManager.get_grudge_manager().has_grudge(int(data.id), other_pawn_id, min_intensity)
	return false

## Get trust penalty from grudges (0.0 to 0.9)
func get_grudge_trust_penalty(other_pawn_id: int) -> float:
	if SocialManager.get_grudge_manager() != null and SocialManager.get_grudge_manager().has_method("get_trust_penalty"):
		return SocialManager.get_grudge_manager().get_trust_penalty(int(data.id), other_pawn_id)
	return 0.0

## Get list of pawns this pawn should avoid (grudge enemies)
func get_grudge_enemies() -> Array[int]:
	if SocialManager.get_grudge_manager() != null and SocialManager.get_grudge_manager().has_method("get_enemies_for"):
		return SocialManager.get_grudge_manager().get_enemies_for(int(data.id), 0.4)
	return []

## Check if pawn should seek revenge against target
func should_seek_revenge(other_pawn_id: int) -> bool:
	if GrudgeManager != null and GrudgeManager.has_method("should_seek_revenge"):
		return GrudgeManager.should_seek_revenge(int(data.id), other_pawn_id)
	return false

## Get reputation score for another pawn (-1.0 to 1.0)
func get_reputation_for(other_pawn_id: int) -> float:
	if SocialManager.get_gossip_manager() != null and SocialManager.get_gossip_manager().has_method("get_reputation_for"):
		return SocialManager.get_gossip_manager().get_reputation_for(other_pawn_id)
	return 0.0

## Get reputation label for another pawn (human-readable)
func get_reputation_label_for(other_pawn_id: int) -> String:
	if GossipManager != null and GossipManager.has_method("get_reputation_label"):
		return GossipManager.get_reputation_label_for(other_pawn_id)
	return "Unknown"

## Get tiles to avoid due to grudge-enemies (Phase 5: Avoidance AI)
## OPTIMIZATION: Cache enemy positions per tick, use O(1) pawn lookup
var _enemy_positions_cache: Array[Vector2i] = []
var _enemy_cache_tick: int = -1
## OPTIMIZATION: Cache enemy pawn references to avoid repeated lookups
var _enemy_pawn_cache: Array[HeelKawnian] = []
var _enemy_pawn_cache_tick: int = -1

func get_avoidance_tiles() -> Array[Vector2i]:
	# Return cached positions if still valid for this tick
	if _enemy_cache_tick == GameManager.tick_count:
		return _enemy_positions_cache

	_enemy_positions_cache.clear()
	
	# OPTIMIZATION: Cache enemy pawn references per tick
	if _enemy_pawn_cache_tick != GameManager.tick_count:
		_enemy_pawn_cache.clear()
		var enemies: Array[int] = get_grudge_enemies()
		var _ps: PawnSpawner = _resolve_pawn_spawner()
		for enemy_id in enemies:
			var enemy_pawn: HeelKawnian = _ps.get_pawn_by_id(enemy_id) if _ps != null else null
			if enemy_pawn != null and is_instance_valid(enemy_pawn) and enemy_pawn.data != null:
				_enemy_pawn_cache.append(enemy_pawn)
		_enemy_pawn_cache_tick = GameManager.tick_count

	if _enemy_pawn_cache.is_empty():
		_enemy_cache_tick = GameManager.tick_count
		return _enemy_positions_cache

	# OPTIMIZATION: Use cached pawn references, avoid repeated lookups
	for enemy_pawn in _enemy_pawn_cache:
		if enemy_pawn.data == null:
			continue
		# Add enemy's tile and 4 adjacent tiles (radius 1)
		_enemy_positions_cache.append(enemy_pawn.data.tile_pos)
		_enemy_positions_cache.append(enemy_pawn.data.tile_pos + Vector2i(1, 0))
		_enemy_positions_cache.append(enemy_pawn.data.tile_pos + Vector2i(-1, 0))
		_enemy_positions_cache.append(enemy_pawn.data.tile_pos + Vector2i(0, 1))
		_enemy_positions_cache.append(enemy_pawn.data.tile_pos + Vector2i(0, -1))

	_enemy_cache_tick = GameManager.tick_count
	return _enemy_positions_cache

## Check if a tile is near an enemy (for avoidance)
## OPTIMIZATION: Use cached pawn references, early exit on first match
func is_tile_near_enemy(tile: Vector2i) -> bool:
	# OPTIMIZATION: Use cached pawn references from get_avoidance_tiles
	if _enemy_pawn_cache_tick != GameManager.tick_count:
		# Force cache population
		get_avoidance_tiles()
	
	if _enemy_pawn_cache.is_empty():
		return false

	# OPTIMIZATION: Early exit on first match, use squared distance
	for enemy_pawn in _enemy_pawn_cache:
		if enemy_pawn.data == null:
			continue
		if tile.distance_squared_to(enemy_pawn.data.tile_pos) <= 9:  # 3 tile radius
			return true
	return false

## OPTIMIZATION: Invalidate avoidance cache for a specific enemy pawn
## Called when a pawn dies or is removed from the game
func _invalidate_avoidance_cache_for_pawn(enemy_pawn_id: int) -> void:
	# Clear cached enemy references that include this pawn
	if not _enemy_pawn_cache.is_empty():
		var changed: bool = false
		for i in range(_enemy_pawn_cache.size() - 1, -1, -1):
			var cached_pawn: HeelKawnian = _enemy_pawn_cache[i]
			if cached_pawn != null and cached_pawn.data != null and int(cached_pawn.data.id) == enemy_pawn_id:
				_enemy_pawn_cache.remove_at(i)
				changed = true
		if changed:
			_enemy_cache_tick = -1  # Force refresh next tick

## Get mood drain from being near enemies (proximity stress)
## OPTIMIZATION: Use cached pawn references, early exit
func get_proximity_stress_drain() -> float:
	# OPTIMIZATION: Use cached pawn references from get_avoidance_tiles
	if _enemy_pawn_cache_tick != GameManager.tick_count:
		# Force cache population
		get_avoidance_tiles()
	
	if _enemy_pawn_cache.is_empty():
		return 0.0

	var stress: float = 0.0
	# OPTIMIZATION: Use cached references, avoid repeated lookups
	for enemy_pawn in _enemy_pawn_cache:
		if enemy_pawn.data == null:
			continue
		var dist_sq: float = data.tile_pos.distance_squared_to(enemy_pawn.data.tile_pos)
		if dist_sq <= 9.0:  # Very close (3^2) - high stress
			stress += 0.15
		elif dist_sq <= 36.0:  # Medium close (6^2) - moderate stress
			stress += 0.05

	return clampf(stress, 0.0, 0.5)

func track_co_presence() -> void:
	_track_co_presence_light()


# PERFORMANCE: SpatialGrid-based co-presence tracking (O(1) neighbor queries)
func _track_co_presence_spatial() -> void:
	if data == null or _spatial_grid == null:
		return
	
	# Query neighbors within 13 tiles (sqrt(169) = 13)
	var neighbors: Array = _spatial_grid.query_radius(data.tile_pos, 13)
	
	for neighbor in neighbors:
		if neighbor == null or not is_instance_valid(neighbor) or neighbor == self or neighbor.data == null:
			continue
		if neighbor.is_sleeping():
			continue
		
		var oid: int = int(neighbor.data.id)
		var cur: int = int(data.co_presence.get(oid, 0)) + 1
		if cur > 60000:
			cur = 60000
		data.co_presence[oid] = cur
		
		# Phase 5: Share gossip during social proximity (every 100 ticks of co-presence)
		if cur % 100 == 0:
			_share_gossip_with(neighbor)


func _track_co_presence_light() -> void:
	if data == null:
		return
	var sp: PawnSpawner = _resolve_pawn_spawner()
	if sp == null:
		return
	var seen: int = 0
	for p in sp.pawns:
		seen += 1
		if seen > 22:
			break
		if p == null or not is_instance_valid(p) or p == self or p.data == null:
			continue
		if p.is_sleeping():
			continue
		if data.tile_pos.distance_squared_to(p.data.tile_pos) > 169:
			continue
		var oid: int = int(p.data.id)
		var cur: int = int(data.co_presence.get(oid, 0)) + 1
		if cur > 60000:
			cur = 60000
		data.co_presence[oid] = cur

		# Phase 5: Share gossip during social proximity (every 100 ticks of co-presence)
		# OPTIMIZATION: Changed from 50 to 100 to reduce frequency
		if cur % 100 == 0:
			_share_gossip_with(p)


## Share gossip with another pawn during social proximity (Phase 5)
## OPTIMIZATION: Early exits, limited gossip sharing
func _share_gossip_with(other_pawn: HeelKawnian) -> void:
	if other_pawn == null or not is_instance_valid(other_pawn):
		return
	if SocialManager.get_gossip_manager() == null or not SocialManager.get_gossip_manager().has_method("share_gossip_between"):
		return
	
	# OPTIMIZATION: Skip if either pawn has no gossip
	var my_gossip: GossipPropagation = GossipManager._get_gossip_for_pawn(int(data.id)) if GossipManager.has_method("_get_gossip_for_pawn") else null
	var other_gossip: GossipPropagation = GossipManager._get_gossip_for_pawn(int(other_pawn.data.id)) if GossipManager.has_method("_get_gossip_for_pawn") else null
	
	if my_gossip == null and other_gossip == null:
		return  # Nothing to share
	
	# Calculate trust strength from social rapport
	var other_id: int = int(other_pawn.data.id)
	var rapport: float = float(data.get_social_rapport(other_id))
	var trust_strength: float = clampf(rapport / 100.0, 0.0, 1.0)
	
	# OPTIMIZATION: Skip if trust too low for gossip sharing
	if trust_strength < 0.3:
		return
	
	# Share gossip (bidirectional)
	var shared_count: int = SocialManager.get_gossip_manager().share_gossip_between(
		int(data.id),
		other_id,
		trust_strength
	)
	
	# Mood bonus for social bonding through gossip
	if shared_count > 0:
		data.mood = min(100.0, data.mood + float(shared_count) * 0.05)
		other_pawn.data.mood = min(100.0, other_pawn.data.mood + float(shared_count) * 0.05)


func form_family_bond(other_pawn: HeelKawnian, initial_strength: float = 20.0) -> void:
	# Form a family bond with another pawn
	var other_id: int = int(other_pawn.data.id)
	data.family_bonds[other_id] = clamp(initial_strength, 0.0, 100.0)
	other_pawn.data.family_bonds[int(data.id)] = clamp(initial_strength, 0.0, 100.0)
	
	if GameManager.verbose_logs():
		print("[HeelKawnian] %s formed family bond with %s (strength %.1f)" % [
			data.display_name, other_pawn.data.display_name, initial_strength
		])


func marry(spouse: HeelKawnian) -> void:
	# Marry another pawn
	if data.spouse_id != -1:
		return  # Already married
	
	var spouse_id: int = int(spouse.data.id)
	data.spouse_id = spouse_id
	spouse.data.spouse_id = int(data.id)
	
	# Form strong family bond
	form_family_bond(spouse, 80.0)
	
	# Set high trust
	data.trust[spouse_id] = 90.0
	spouse.data.trust[int(data.id)] = 90.0
	
	# Create household if neither has one
	if data.household_id == -1 and spouse.data.household_id == -1:
		var new_household_id: int = _create_household()
		data.household_id = new_household_id
		spouse.data.household_id = new_household_id
	elif data.household_id != -1:
		spouse.data.household_id = data.household_id
	elif spouse.data.household_id != -1:
		data.household_id = spouse.data.household_id
	
	data.append_biography_line("Married %s (pawn_id=%d)" % [spouse.data.display_name, spouse_id])
	spouse.data.append_biography_line("Married %s (pawn_id=%d)" % [data.display_name, int(data.id)])
	if GameManager.verbose_logs():
		print("[HeelKawnian] %s married %s (household %d)" % [
			data.display_name, spouse.data.display_name, data.household_id
		])


## Spawn a child via [PawnSpawner] (bind, tile, lineage, [HeelKawnianData] registry). Not a raw scene instantiate:
## that would skip world placement, job safety, and [method HeelKawnianData.register_pawn_data].
func _spawn_child_pawn(parent_pawn_id: int = -1, second_parent_id: int = -1) -> HeelKawnian:
	var spawner: PawnSpawner = _resolve_pawn_spawner()
	if spawner == null or _world == null or GameManager == null or data == null:
		return null
	var pa_id: int = parent_pawn_id if parent_pawn_id >= 0 else int(data.id)
	var pb_id: int = second_parent_id if second_parent_id >= 0 else int(data.spouse_id)
	if pb_id < 0:
		return null
	var parent_a: HeelKawnianData = spawner.pawn_data_for_id(pa_id)
	var parent_b: HeelKawnianData = spawner.pawn_data_for_id(pb_id)
	if parent_a == null or parent_b == null:
		return null
	return spawner.spawn_child_pawn(_world, data.tile_pos, parent_a, parent_b, GameManager.tick_count)


## Single-parent affinity nudge: scale parent's values by 70â€“130% (deterministic) and lerp child's map.
static func _inherit_from_parent(
		child_pd: HeelKawnianData, parent_id: int, birth_tick: int, pass_index: int = 0
) -> void:
	if child_pd == null or parent_id < 0:
		return
	var parent_pd: HeelKawnianData = child_pd._get_parent_data(parent_id)
	if parent_pd == null:
		return
	for k in child_pd.affinities.keys():
		var paf: float = float(parent_pd.affinities.get(k, 0.5))
		var cur: float = float(child_pd.affinities.get(k, 0.5))
		var mul: float = WorldRNG.range_for(
				StringName(
                        "pawn:inherit_from_parent:%s:%d:%d:%d:%d"
						% [str(k), child_pd.id, parent_id, birth_tick, pass_index]
				),
				0.7,
				1.3
		)
		var target: float = clampf(paf * mul, 0.0, 1.0)
		var w: float = WorldRNG.range_for(
				StringName(
                        "pawn:inherit_from_parent_w:%s:%d:%d:%d"
						% [str(k), child_pd.id, parent_id, pass_index]
				),
				0.35,
				0.55
		)
		child_pd.affinities[k] = clampf(lerpf(cur, target, w), 0.0, 1.0)


## Apply both parents in order (after [method HeelKawnianData.initialize_affinities]).
static func _inherit_affinities(
		child_pd: HeelKawnianData, parent_a: HeelKawnianData, parent_b: HeelKawnianData, birth_tick: int
) -> void:
	if child_pd == null or parent_a == null or parent_b == null:
		return
	_inherit_from_parent(child_pd, int(parent_a.id), birth_tick, 0)
	_inherit_from_parent(child_pd, int(parent_b.id), birth_tick, 1)


func have_child(partner: HeelKawnian) -> int:
	# Have a child with partner (same path as [method attempt_reproduction] / Main tick).
	if partner == null or not is_instance_valid(partner) or partner.data == null or data == null:
		return -1
	if data.spouse_id != int(partner.data.id):
		return -1
	var child: HeelKawnian = _spawn_child_pawn(int(data.id), int(partner.data.id))
	if child == null or child.data == null:
		return -1
	return int(child.data.id)


func _create_household() -> int:
	# Create via KinshipSystem when available; keep deterministic fallback for safety.
	if data != null:
		var kin: Node = get_node_or_null("/root/KinshipSystem")
		if kin != null and kin.has_method("create_household"):
			var created: int = int(kin.call("create_household", int(data.id)))
			if created >= 0:
				return created
	return WorldRNG.stream_seed(_pawn_stream("household_id"), _pawn_salt(53)) % 10000


func join_household(household_id: int) -> void:
	# Join an existing household
	if data == null:
		return
	if household_id < 0:
		return
	if int(data.household_id) == household_id:
		return
	data.household_id = household_id
	var kin: Node = get_node_or_null("/root/KinshipSystem")
	if kin != null:
		if kin.has_method("add_to_household"):
			var joined: bool = bool(kin.call("add_to_household", household_id, int(data.id)))
			if not joined and kin.has_method("add_household_member"):
				kin.call("add_household_member", int(data.id), household_id)
		elif kin.has_method("add_household_member"):
			kin.call("add_household_member", int(data.id), household_id)
	if GameManager.verbose_logs():
		print("[HeelKawnian] %s joined household %d" % [data.display_name, household_id])


func leave_household() -> void:
	# Leave current household
	if data == null:
		return
	var old_household: int = data.household_id
	if old_household < 0:
		return
	var kin: Node = get_node_or_null("/root/KinshipSystem")
	var former_members: Array = []
	if kin != null and kin.has_method("get_household_members"):
		former_members = kin.call("get_household_members", old_household)
	data.household_id = -1
	
	# Reduce family bonds with former household members
	for other_id in former_members:
		var oid: int = int(other_id)
		if oid == int(data.id):
			continue
		if data.family_bonds.has(oid):
			data.family_bonds[oid] = max(0.0, float(data.family_bonds.get(oid, 0.0)) - 3.0)
		if data.trust.has(oid):
			data.trust[oid] = max(0.0, float(data.trust.get(oid, 0.0)) - 2.0)
	
	if GameManager.verbose_logs():
		print("[HeelKawnian] %s left household %d" % [data.display_name, old_household])


func get_household_stability() -> float:
	# Calculate household stability (0-100)
	# Based on family bonds, trust, and co-presence
	if data.household_id == -1:
		return 0.0
	
	var stability: float = 0.0
	var household_members: int = 0
	var kin: Node = get_node_or_null("/root/KinshipSystem")
	if kin != null and kin.has_method("get_household_members"):
		var members: Array = kin.call("get_household_members", int(data.household_id))
		for other_id in members:
			var oid: int = int(other_id)
			if oid == int(data.id):
				continue
			stability += float(data.family_bonds.get(oid, 0.0))
			stability += float(data.trust.get(oid, 0.0)) * 0.5
			household_members += 1
		if kin.has_method("get_household_food"):
			stability += min(25.0, float(kin.call("get_household_food", int(data.household_id))) * 0.25)
		if kin.has_method("get_household_labor"):
			stability += min(25.0, float(kin.call("get_household_labor", int(data.household_id))) * 0.05)
	else:
		# Fallback path when KinshipSystem is unavailable.
		for other_id in data.family_bonds:
			stability += float(data.family_bonds[other_id])
			household_members += 1
		for other_id in data.trust:
			stability += float(data.trust[other_id]) * 0.5
	
	if household_members > 0:
		stability /= float(household_members)
	
	return clamp(stability, 0.0, 100.0)


## Stage 3: Clan & Household Network

func join_clan(clan_id: int) -> void:
	# Join a clan
	data.clan_id = clan_id
	if GameManager.verbose_logs():
		print("[HeelKawnian] %s joined clan %d" % [data.display_name, clan_id])


func leave_clan() -> void:
	# Leave current clan
	var old_clan: int = data.clan_id
	data.clan_id = -1
	data.clan_influence = 0.0
	
	if GameManager.verbose_logs():
		print("[HeelKawnian] %s left clan %d" % [data.display_name, old_clan])


func contribute_to_clan_labor(job_type: String) -> void:
	# Record labor contribution to clan
	data.labor_contributions[job_type] = data.labor_contributions.get(job_type, 0) + 1
	
	# Increase clan influence slightly
	data.clan_influence = min(100.0, data.clan_influence + 0.5)
	
	# Increase personal reputation
	data.reputation_score = min(100.0, data.reputation_score + 0.2)


func gain_reputation(amount: float, source_clan_id: int = -1) -> void:
	# Gain reputation with a clan or generally
	data.reputation_score = min(100.0, data.reputation_score + amount)
	
	if source_clan_id != -1:
		data.clan_reputation[source_clan_id] = min(100.0, data.clan_reputation.get(source_clan_id, 50.0) + amount)


func lose_reputation(amount: float, source_clan_id: int = -1) -> void:
	# Lose reputation with a clan or generally
	data.reputation_score = max(0.0, data.reputation_score - amount)
	
	if source_clan_id != -1:
		data.clan_reputation[source_clan_id] = max(0.0, data.clan_reputation.get(source_clan_id, 50.0) - amount)


func set_leadership_role(role: int) -> void:
	# Set leadership role (0=NONE, 1=ELDER, 2=CHIEF, 3=WARRIOR_LEADER)
	data.leadership_role = role
	
	if GameManager.verbose_logs():
		var role_name: String = "NONE"
		match role:
			1: role_name = "ELDER"
			2: role_name = "CHIEF"
			3: role_name = "WARRIOR_LEADER"
		print("[HeelKawnian] %s became %s of clan %d" % [data.display_name, role_name, data.clan_id])


func challenge_for_leadership(_target_leader: HeelKawnian) -> void:
	# Challenge another pawn for leadership
	# Placeholder - needs AuthoritySystem integration
	# TODO: Implement leadership challenge mechanics
	pass


func get_clan_influence() -> float:
	return data.clan_influence


func get_total_labor_contributions() -> int:
	var total: int = 0
	for job_type in data.labor_contributions:
		total += data.labor_contributions[job_type]
	return total


## Stage 4: Settlement/Homestead

func join_settlement(settlement_id: int) -> void:
	# Join a settlement
	data.settlement_id = settlement_id
	if GameManager.verbose_logs():
		print("[HeelKawnian] %s joined settlement %d" % [data.display_name, settlement_id])


func leave_settlement() -> void:
	# Leave current settlement
	var old_settlement: int = data.settlement_id
	data.settlement_id = -1
	
	# Lose homestead if owned
	if data.homestead_tile != Vector2i(-1, -1):
		data.owned_properties.erase(data.homestead_tile)
		data.homestead_tile = Vector2i(-1, -1)
	
	if GameManager.verbose_logs():
		print("[HeelKawnian] %s left settlement %d" % [data.display_name, old_settlement])


func establish_homestead(tile: Vector2i) -> bool:
	# Establish a homestead at the given tile
	if _world == null:
		return false
	if not _world.pathfinder.is_passable(tile):
		return false
	
	data.homestead_tile = tile
	data.owned_properties[tile] = "homestead"
	
	if GameManager.verbose_logs():
		print("[HeelKawnian] %s established homestead at %s" % [data.display_name, str(tile)])
	
	return true


func record_food_production(amount: int) -> void:
	# Record food production contribution
	data.food_produced += amount


func record_building_construction() -> void:
	# Record building construction contribution
	data.buildings_constructed += 1


func establish_trade_relationship(target_settlement_id: int, initial_volume: int = 10) -> void:
	# Establish a trade relationship with another settlement
	data.trade_relationships[target_settlement_id] = initial_volume
	
	if GameManager.verbose_logs():
		print("[HeelKawnian] %s established trade with settlement %d (volume %d)" % [
			data.display_name, target_settlement_id, initial_volume
		])


func set_settlement_role(role: int) -> void:
	# Set settlement role (0=NONE, 1=FARMER, 2=BUILDER, 3=MERCHANT, 4=GUARD)
	data.settlement_role = role
	
	if GameManager.verbose_logs():
		var role_name: String = "NONE"
		match role:
			1: role_name = "FARMER"
			2: role_name = "BUILDER"
			3: role_name = "MERCHANT"
			4: role_name = "GUARD"
		print("[HeelKawnian] %s became %s of settlement %d" % [data.display_name, role_name, data.settlement_id])


## Life-path v1: map completed job types to one of four tracks (farmer, soldier,
## ruler, wanderer). Each completion increments the matching path counter;
## dominant path is re-evaluated and may switch. Milestone events are recorded
## in WorldMemory at progress thresholds (10, 25, 50, 100).
func _evaluate_life_path_on_job_complete(job_type: int) -> void:
	var path_key: String = _life_path_key_for_job(job_type)
	if path_key.is_empty():
		return
	var contribs: Dictionary = data.life_path_contributions
	contribs[path_key] = int(contribs.get(path_key, 0)) + 1
	data.life_path_contributions = contribs
	data.life_path_total += 1

	# Determine dominant path.
	var dominant: String = ""
	var dominant_count: int = 0
	for pk in ["farmer", "soldier", "ruler", "wanderer"]:
		var c: int = int(contribs.get(pk, 0))
		if c > dominant_count:
			dominant_count = c
			dominant = pk

	if dominant.is_empty():
		return

	# Convert string key to LifePath enum.
	var new_path: int = _life_path_enum(dominant)

	# If path switched, reset per-path progress.
	if new_path != data.life_path:
		var old_path_name: String = _life_path_label(data.life_path)
		data.life_path = new_path
		data.life_path_progress = 0
		if not old_path_name.is_empty():
			WorldMemory.record_event({
				"type": "life_path_switch",
				"pawn_id": int(data.id),
				"pawn_name": data.display_name,
				"old_path": old_path_name,
				"new_path": _life_path_label(new_path),
				"tick": GameManager.tick_count,
			})

	data.life_path_progress += 1

	# Ruler path: direct influence gain (leadership emergence).
	if new_path == HeelKawnianData.LifePath.RULER:
		data.influence += 1.0

	# Milestone events at 10 / 25 / 50 / 100 on current path.
	var prog: int = data.life_path_progress
	if prog in [10, 25, 50, 100]:
		WorldMemory.record_event({
			"type": "life_path_milestone",
			"pawn_id": int(data.id),
			"pawn_name": data.display_name,
			"path": _life_path_label(new_path),
			"milestone": prog,
			"total_contribs": data.life_path_total,
			"tick": GameManager.tick_count,
		})
		# Ruler path milestones trigger governance events.
		if new_path == HeelKawnianData.LifePath.RULER:
			_trigger_ruler_decision_event(prog)


static func _life_path_key_for_job(job_type: int) -> String:
	match job_type:
		_Job.Type.FORAGE, _Job.Type.HUNT, _Job.Type.FISH:
			return "farmer"
		_Job.Type.TRADE_HAUL:
			return "wanderer"
		_:
			pass
	# MINE / MINE_WALL / BUILD_* contribute to soldier (defense through
	# fortification) if settlement is in DEFEND state, otherwise farmer.
	var intent: String = ""
	var sm = SettlementMemory
	if sm != null:
		intent = sm.get_settlement_intent_for_tile(Vector2i.ZERO)  # coarse
	if intent == "DEFEND":
		match job_type:
			_Job.Type.MINE, _Job.Type.MINE_WALL, _Job.Type.BUILD_WALL, _Job.Type.BUILD_DOOR:
				return "soldier"
	# CHOP contributes to wanderer (scouting/clearing new ground).
	if job_type == _Job.Type.CHOP:
		return "wanderer"
	# Default: harvest/build â†’ farmer (food & shelter foundation).
	match job_type:
		_Job.Type.MINE, _Job.Type.MINE_WALL:
			return "farmer"
		_Job.Type.BUILD_BED, _Job.Type.BUILD_WALL, _Job.Type.BUILD_DOOR, _Job.Type.BUILD_FIRE_PIT, _Job.Type.BUILD_STORAGE_HUT, _Job.Type.BUILD_SHELTER, _Job.Type.BUILD_HEARTH, _Job.Type.BUILD_MARKER_STONE, _Job.Type.BUILD_SHRINE:
			return "soldier"
	return ""


static func _life_path_enum(key: String) -> int:
	match key:
		"farmer":    return HeelKawnianData.LifePath.FARMER
		"soldier":  return HeelKawnianData.LifePath.SOLDIER
		"ruler":    return HeelKawnianData.LifePath.RULER
		"wanderer": return HeelKawnianData.LifePath.WANDERER
	return HeelKawnianData.LifePath.NONE


static func _life_path_label(path: int) -> String:
	match path:
		HeelKawnianData.LifePath.FARMER:    return "farmer"
		HeelKawnianData.LifePath.SOLDIER:  return "soldier"
		HeelKawnianData.LifePath.RULER:    return "ruler"
		HeelKawnianData.LifePath.WANDERER: return "wanderer"
	return "none"


## Ruler path: milestone decision events that shape settlement governance.
## At 25: propose law; at 50: propose policy shift; at 100: propose expansion.
func _trigger_ruler_decision_event(milestone: int) -> void:
	var decision_type: String = ""
	match milestone:
		25: decision_type = "law_proposal"
		50: decision_type = "policy_shift"
		100: decision_type = "expansion_drive"
	if decision_type.is_empty():
		return
	var rk: int = WorldMemory._region_key(data.tile_pos.x, data.tile_pos.y)
	WorldMemory.record_event({
		"type": "ruler_decision",
		"pawn_id": int(data.id),
		"pawn_name": data.display_name,
		"milestone": milestone,
		"decision_type": decision_type,
		"region_key": rk,
		"tick": GameManager.tick_count,
	})


## Track region visits for wanderer path progression. Each new region
## discovered grants +1 wanderer contribution and triggers a discovery event.
func _track_region_visit(tile: Vector2i) -> void:
	if data == null or _world == null:
		return
	var rk: int = WorldMemory._region_key(tile.x, tile.y)
	var rk_str: String = str(rk)
	if data.regions_visited.has(rk_str):
		return
	data.regions_visited[rk_str] = true
	# Grant wanderer contribution for discovering a new region.
	var contribs: Dictionary = data.life_path_contributions
	contribs["wanderer"] = int(contribs.get("wanderer", 0)) + 1
	data.life_path_contributions = contribs
	data.life_path_total += 1
	_world_record_discovery_event(rk, tile)
	
	# PAWN-ACTIVATED EVENT: Record discovery for event system
	if WorldEvents != null and WorldEvents.has_method("record_pawn_action"):
		WorldEvents.record_pawn_action("discovery", int(data.id))
	
	# Re-evaluate dominant path after new discovery.
	_reevaluate_life_path_from_contributions()


func _world_record_discovery_event(region_key: int, tile: Vector2i) -> void:
	# Rate-limit: only record the first discovery per region globally.
	# Prevents hundreds of discovery events from flooding WorldMemory.
	if not HeelKawnian._s_discovered_regions.has(region_key):
		HeelKawnian._s_discovered_regions[region_key] = true
		WorldMemory.record_event({
			"type": "region_discovery",
			"pawn_id": int(data.id),
			"pawn_name": data.display_name,
			"region_key": region_key,
			"tile": {"x": tile.x, "y": tile.y},
			"total_regions": data.regions_visited.size(),
			"tick": GameManager.tick_count,
		})


## Re-evaluate life path from current contribution counts (used after
## exploration or other non-job contributions).
func _reevaluate_life_path_from_contributions() -> void:
	var contribs: Dictionary = data.life_path_contributions
	var dominant: String = ""
	var dominant_count: int = 0
	for pk in ["farmer", "soldier", "ruler", "wanderer"]:
		var c: int = int(contribs.get(pk, 0))
		if c > dominant_count:
			dominant_count = c
			dominant = pk
	if dominant.is_empty():
		return
	var new_path: int = _life_path_enum(dominant)
	if new_path != data.life_path:
		var old_path_name: String = _life_path_label(data.life_path)
		data.life_path = new_path
		data.life_path_progress = 0
		if not old_path_name.is_empty():
			WorldMemory.record_event({
				"type": "life_path_switch",
				"pawn_id": int(data.id),
				"pawn_name": data.display_name,
				"old_path": old_path_name,
				"new_path": _life_path_label(new_path),
				"tick": GameManager.tick_count,
			})
	data.life_path_progress += 1

	# Ruler path: direct influence gain (leadership emergence).
	if new_path == HeelKawnianData.LifePath.RULER:
		data.influence += 1.0

	var prog: int = data.life_path_progress
	if prog in [10, 25, 50, 100]:
		WorldMemory.record_event({
			"type": "life_path_milestone",
			"pawn_id": int(data.id),
			"pawn_name": data.display_name,
			"path": _life_path_label(new_path),
			"milestone": prog,
			"total_contribs": data.life_path_total,
			"tick": GameManager.tick_count,
		})


func own_property(tile: Vector2i, property_type: String) -> void:
	# Own a property at a tile
	data.owned_properties[tile] = property_type


func get_total_trade_volume() -> int:
	var total: int = 0
	for settlement_id in data.trade_relationships:
		total += data.trade_relationships[settlement_id]
	return total


## Stage 5: Region/Local Polity

func join_region(region_id: int) -> void:
	# Join a region
	data.region_id = region_id
	if GameManager.verbose_logs():
		print("[HeelKawnian] %s joined region %d" % [data.display_name, region_id])


func leave_region() -> void:
	# Leave current region
	var old_region: int = data.region_id
	data.region_id = -1
	data.citizenship_status = 0
	
	if GameManager.verbose_logs():
		print("[HeelKawnian] %s left region %d" % [data.display_name, old_region])


func build_road(tile: Vector2i) -> bool:
	# Build a road at the given tile
	if _world == null:
		return false
	if not _world.pathfinder.is_passable(tile):
		return false
	
	data.roads_built += 1
	
	if GameManager.verbose_logs():
		print("[HeelKawnian] %s built road at %s" % [data.display_name, str(tile)])
	
	return true


func learn_custom(custom_name: String, familiarity: float = 20.0) -> void:
	# Learn a regional custom or tradition
	data.known_customs[custom_name] = min(100.0, data.known_customs.get(custom_name, 0.0) + familiarity)
	
	if GameManager.verbose_logs():
		print("[HeelKawnian] %s learned custom '%s' (familiarity %.1f)" % [
			data.display_name, custom_name, data.known_customs[custom_name]
		])


func set_citizenship_status(status: int) -> void:
	# Set citizenship status (0=NONE, 1=RESIDENT, 2=CITIZEN, 3=ELDER)
	data.citizenship_status = status
	
	if GameManager.verbose_logs():
		var status_name: String = "NONE"
		match status:
			1: status_name = "RESIDENT"
			2: status_name = "CITIZEN"
			3: status_name = "ELDER"
		print("[HeelKawnian] %s became %s of region %d" % [data.display_name, status_name, data.region_id])


func pay_taxes(amount: int) -> void:
	# Pay regional taxes
	data.taxes_paid += amount
	
	if GameManager.verbose_logs():
		print("[HeelKawnian] %s paid %d in taxes to region %d" % [
			data.display_name, amount, data.region_id
		])


func update_regional_safety(safety_delta: float) -> void:
	# Update regional safety rating
	data.regional_safety = clamp(data.regional_safety + safety_delta, 0.0, 100.0)


## Stage 6: Nation/Country

func join_nation(nation_id: int) -> void:
	# Join a nation
	data.nation_id = nation_id
	if GameManager.verbose_logs():
		print("[HeelKawnian] %s joined nation %d" % [data.display_name, nation_id])


func leave_nation() -> void:
	# Leave current nation
	var old_nation: int = data.nation_id
	data.nation_id = -1
	data.national_citizenship = 0
	
	if GameManager.verbose_logs():
		print("[HeelKawnian] %s left nation %d" % [data.display_name, old_nation])


func comply_with_law(law_id: int, compliance_level: float = 100.0) -> void:
	# Record compliance with a law
	data.law_compliance[law_id] = clamp(compliance_level, 0.0, 100.0)


func violate_law(law_id: int) -> void:
	# Record violation of a law
	data.law_compliance[law_id] = max(0.0, data.law_compliance.get(law_id, 100.0) - 50.0)
	
	if GameManager.verbose_logs():
		print("[HeelKawnian] %s violated law %d" % [data.display_name, law_id])


func adopt_culture(culture_name: String, affinity: float = 50.0) -> void:
	# Adopt a cultural identity
	data.cultural_affinity[culture_name] = clamp(affinity, 0.0, 100.0)
	
	if GameManager.verbose_logs():
		print("[HeelKawnian] %s adopted culture '%s' (affinity %.1f)" % [
			data.display_name, culture_name, affinity
		])


func serve_in_military(years: int = 1) -> void:
	# Serve in the military
	data.military_service_years += years
	
	if GameManager.verbose_logs():
		print("[HeelKawnian] %s served %d years in military (total %d)" % [
			data.display_name, years, data.military_service_years
		])


func set_military_rank(rank: int) -> void:
	# Set military rank (0=NONE, 1=SOLDIER, 2=SERGEANT, 3=OFFICER, 4=GENERAL)
	data.military_rank = rank
	
	if GameManager.verbose_logs():
		var rank_name: String = "NONE"
		match rank:
			1: rank_name = "SOLDIER"
			2: rank_name = "SERGEANT"
			3: rank_name = "OFFICER"
			4: rank_name = "GENERAL"
		print("[HeelKawnian] %s became %s of nation %d" % [data.display_name, rank_name, data.nation_id])


func establish_diplomatic_relation(target_nation_id: int, standing: float = 50.0) -> void:
	# Establish diplomatic standing with another nation
	data.diplomatic_standing[target_nation_id] = clamp(standing, 0.0, 100.0)
	
	if GameManager.verbose_logs():
		print("[HeelKawnian] %s established diplomatic relation with nation %d (standing %.1f)" % [
			data.display_name, target_nation_id, standing
		])


func set_national_citizenship(citizenship: int) -> void:
	# Set national citizenship (0=NONE, 1=SUBJECT, 2=CITIZEN, 3=NOBLE)
	data.national_citizenship = citizenship
	
	if GameManager.verbose_logs():
		var citizenship_name: String = "NONE"
		match citizenship:
			1: citizenship_name = "SUBJECT"
			2: citizenship_name = "CITIZEN"
			3: citizenship_name = "NOBLE"
		print("[HeelKawnian] %s became %s of nation %d" % [data.display_name, citizenship_name, data.nation_id])


## Stage 7: World systems

func spread_influence_to_region(region_id: int, influence_amount: float = 5.0) -> void:
	# Spread influence to another region
	data.cross_region_influence[region_id] = min(100.0, data.cross_region_influence.get(region_id, 0.0) + influence_amount)
	
	# Increase legacy score
	data.legacy_score += influence_amount * 0.1
	
	if GameManager.verbose_logs():
		print("[HeelKawnian] %s spread influence to region %d (influence %.1f)" % [
			data.display_name, region_id, data.cross_region_influence[region_id]
		])


func adapt_to_climate(climate_type: String, adaptation_amount: float = 10.0) -> void:
	# Adapt to a climate type
	data.climate_adaptation[climate_type] = min(100.0, data.climate_adaptation.get(climate_type, 0.0) + adaptation_amount)
	
	if GameManager.verbose_logs():
		print("[HeelKawnian] %s adapted to climate '%s' (adaptation %.1f)" % [
			data.display_name, climate_type, data.climate_adaptation[climate_type]
		])


func learn_myth(myth_name: String, belief: float = 30.0) -> void:
	# Learn about a myth or legend
	data.myth_knowledge[myth_name] = clamp(belief, 0.0, 100.0)
	
	if GameManager.verbose_logs():
		print("[HeelKawnian] %s learned myth '%s' (belief %.1f)" % [
			data.display_name, myth_name, belief
		])


func witness_world_event(event_id: int, impact: float = 10.0) -> void:
	# Record witnessing a world event
	data.world_events_witnessed[event_id] = impact
	
	# Increase legacy score based on event impact
	data.legacy_score += impact * 0.2
	
	if GameManager.verbose_logs():
		print("[HeelKawnian] %s witnessed world event %d (impact %.1f, legacy %.1f)" % [
			data.display_name, event_id, impact, data.legacy_score
		])


func increase_legacy(amount: float) -> void:
	# Directly increase legacy score
	data.legacy_score += amount
	
	if GameManager.verbose_logs():
		print("[HeelKawnian] %s legacy increased to %.1f" % [data.display_name, data.legacy_score])


## Stage 1: Small direct actions

func gather() -> bool:
	return try_pickup_item()


func craft_simple_tool(_tool_type: int) -> bool:
	# Create a simple tool from materials
	# Requires: pawn has materials, has crafting skill
	# Placeholder - needs crafting system
	# TODO: Implement crafting
	return false


func flee_from_danger() -> bool:
	# Run from nearby danger
	# Find nearest danger and move away
	if _world == null:
		return false
	
	var nearest_danger_tile: Vector2i = Vector2i(-1, -1)
	var nearest_danger_dist: float = INF
	
	# Check for nearby enemies
	for enemy in HeelKawnian._get_enemies_cached():
		if not is_instance_valid(enemy):
			continue
		var enemy_tile: Vector2i = _world.world_to_tile(enemy.position)
		var dist: float = data.tile_pos.distance_squared_to(enemy_tile)
		if dist < 100.0 and dist < nearest_danger_dist:  # Within 10 tiles
			nearest_danger_tile = enemy_tile
			nearest_danger_dist = dist
	
	if nearest_danger_tile.x < 0:
		return false  # No danger nearby
	
	# Calculate flee direction (away from danger)
	var flee_dir: Vector2i = data.tile_pos - nearest_danger_tile
	var flee_target: Vector2i = data.tile_pos + flee_dir * 3  # Move 3 tiles away
	
	# Check if flee target is valid
	if not _world.pathfinder.is_passable(flee_target):
		# Try adjacent tiles
		for offset in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var alt_target: Vector2i = data.tile_pos + offset
			if _world.pathfinder.is_passable(alt_target):
				flee_target = alt_target
				break
	
	if not _world.pathfinder.is_passable(flee_target):
		return false  # Nowhere to flee
	
	# Start fleeing
	var path: Array[Vector2i] = _path_for_pawn(flee_target)
	if path.is_empty():
		return false
	
	_state = State.FLEEING
	_start_path(path)
	_request_redraw()
	
	if GameManager.verbose_logs():
		print("[HeelKawnian] %s fleeing from danger" % data.display_name)
	
	return true


func hide_from_threats() -> bool:
	# DISABLED for performance - _find_cover_tile function removed
	return false


func _tick_gathering() -> void:
	# Tick while gathering items from ground
	# Placeholder - needs ground item system
	# For now, just return to idle
	_state = State.IDLE


func _tick_crafting() -> void:
	# Tick while crafting
	# Placeholder - needs crafting system
	# For now, just return to idle
	_state = State.IDLE


func _tick_fleeing() -> void:
	# Tick while fleeing
	# Continue until far enough from danger or reached target
	if _path.is_empty():
		_state = State.IDLE
		return
	
	# Check if still in danger
	var danger_nearby: bool = false
	for enemy in HeelKawnian._get_enemies_cached():
		if not is_instance_valid(enemy):
			continue
		var enemy_tile: Vector2i = _world.world_to_tile(enemy.position)
		var dist: float = data.tile_pos.distance_squared_to(enemy_tile)
		if dist < 100.0:  # Within 10 tiles
			danger_nearby = true
			break
	
	if not danger_nearby:
		# Safe now, return to idle
		_clear_path()
		_state = State.IDLE
		if GameManager.verbose_logs():
			print("[HeelKawnian] %s reached safety" % data.display_name)


## Apply meaning-based behavior density modifiers (Phase 4)
## Reads region meaning from MeaningAmbianceController and adjusts movement speed,
## clustering radius, and wander bias
func _apply_meaning_behavior_modifiers() -> void:
	if _world == null or data == null:
		return
	if not is_instance_valid(MeaningAmbianceController):
		return
	
	# Get region key for current position
	var rk: int = WorldMemory._region_key(data.tile_pos.x, data.tile_pos.y)
	
	# Get movement speed multiplier from ambiance controller
	var speed_mult: float = MeaningAmbianceController.get_movement_speed_multiplier_for_region(rk)
	
	# Get clustering radius and wander bias
	var cluster_radius: float = MeaningAmbianceController.get_clustering_radius_for_region(rk)
	var wander_bias: float = MeaningAmbianceController.get_wander_bias_for_region(rk)
	
	# Cache the values for use in movement logic
	_meaning_speed_multiplier = speed_mult
	_meaning_clustering_radius = cluster_radius
	_meaning_wander_bias = wander_bias


## Cached meaning-based behavior modifiers (defaults)
var _meaning_speed_multiplier: float = 1.0
var _meaning_clustering_radius: float = 128.0
var _meaning_wander_bias: float = 0.5


func _tick_hiding() -> void:
	# Tick while hiding
	# Stay hidden until danger passes
	if _path.is_empty():
		# At hiding spot, wait for danger to pass
		var danger_nearby: bool = false
		for enemy in HeelKawnian._get_enemies_cached():
			if not is_instance_valid(enemy):
				continue
			var enemy_tile: Vector2i = _world.world_to_tile(enemy.position)
			var dist: float = data.tile_pos.distance_squared_to(enemy_tile)
			if dist < 100.0:  # Within 10 tiles
				danger_nearby = true
				break
		
		if not danger_nearby:
			# Safe now, return to idle
			_state = State.IDLE
			if GameManager.verbose_logs():
				print("[HeelKawnian] %s emerged from hiding" % data.display_name)


func die(_p_cause: String) -> void:
	_die(_p_cause)


func _die(_p_cause: String = "") -> void:
	# CRITICAL: Mark pawn as dead FIRST to prevent re-entry and duplicate death processing
	if data != null:
		data.is_dead = true
	
	# Release any held job and bed reservation
	release_job_if_any()
	_release_bed_if_reserved()

	# ARCHITECT T006: Unregister pawn from SpatialManager upon death
	if SpatialManager != null and data != null:
		SpatialManager.unregister_entity(int(data.id))

	# Drop any carried items into the nearest stockpile
	if data.is_carrying() and _world != null:
		var sp: Stockpile = StockpileManager.find_drop_zone(data.carrying, data.tile_pos, _world.pathfinder)
		if sp != null:
			sp.add_item(data.carrying, data.carrying_qty)
	data.clear_carry()

	# Trigger sorrow in nearby pawns who witness the death
	_trigger_sorrow_in_nearby_pawns()
	# Record death trauma to consciousness of nearby witnesses
	_record_witnessed_death_consciousness()
	# Record grudges for family members (kin_death)
	_record_kin_death_grudges()
	_play_sfx("res://assets/audio/pawn_die.ogg", 0.85)

	# world_trace: all deaths, including old_age
	var root_node: Node = get_tree().get_root().get_node_or_null("Main/WorldTrace")
	if root_node != null and root_node is WorldTrace:
		(root_node as WorldTrace).record_trace(global_position, "death")
	
	# WorldMemory: deterministic fact log (before node freed; data still valid).
	if data != null:
		var mem_cause: String = _p_cause
		if mem_cause.is_empty():
			if data.hunger <= 0.0:
				mem_cause = "starvation"
			elif data.rest <= 0.0:
				mem_cause = "exhaustion"
			elif data.health <= 0.0:
				mem_cause = "injury"
			else:
				mem_cause = "unknown"
		data.last_words = _derive_last_words(mem_cause)
		WorldMemory.record_pawn_death(
				GameManager.tick_count,
				data.tile_pos,
				data.id,
				data.display_name,
				mem_cause,
				int(data.current_profession),
				data.parent_a_id,
				data.parent_b_id,
				data.birth_settlement
		)
		var main_node: Node = get_tree().get_root().get_node_or_null("Main")
		if main_node != null and main_node.has_method("register_pawn_death"):
			main_node.call("register_pawn_death", int(data.id))
		
		# KnowledgeSystem: remove knowledge carrier when pawn dies
		if KnowledgeSystem != null:
			KnowledgeSystem.remove_knowledge_carrier(int(data.id), data.tile_pos)

		if MemorialSystem != null and MemorialSystem.has_method("create_death_memorial"):
			MemorialSystem.create_death_memorial(data, data.tile_pos, mem_cause in ["injury", "combat", "violence", "battle"])

		# Generate pawn memoir
		if MemorialSystem != null and MemorialSystem.has_method("generate_pawn_memoir"):
			MemorialSystem.generate_pawn_memoir(data, mem_cause)

		# Memorial obituary — record a eulogy event in WorldMemory
		var _mcause: String = mem_cause if not mem_cause.is_empty() else _p_cause if not _p_cause.is_empty() else "unknown"
		var _birth_years: float = data.age_years if data.has("age_years") else float(data.age)
		var _prof: String = "villager"
		if data.has_method("profession_label_from_enum"):
			_prof = data.profession_label_from_enum(int(data.current_profession)).to_lower()
		WorldMemory.record_event({
			"type": "memorial_created",
			"tick": GameManager.tick_count,
			"pawn_id": int(data.id),
			"pawn_name": data.display_name,
			"age": _birth_years,
			"profession": _prof,
			"cause": _mcause,
			"parent_a": data.parent_a_id,
			"parent_b": data.parent_b_id,
		})

## Trait / Krond convenience wrappers (delegates to HeelKawnianData)
func can_afford_trait(trait_res: Resource) -> bool:
	if data == null or trait_res == null:
		return false
	var cost: float = 0.0
	# Resource-backed TraitData uses `krond_cost`, legacy Trait uses same field name
	if trait_res.has("krond_cost"):
		# supports both property access and generic get
		if trait_res.has_method("get"):
			cost = float(trait_res.get("krond_cost"))
		else:
			cost = float(trait_res.krond_cost)
	return data.can_afford_trait(cost)


func apply_trait(trait_res: Resource) -> bool:
	if data == null or trait_res == null:
		return false
	return data.apply_trait(trait_res)

	# Remove from groups and free the node
	remove_from_group("pawns")
	remove_from_group("tickable")
	if TickManager != null:
		TickManager.mark_tickable_cache_dirty()
	queue_free()


## Nearby pawns get SORROW mood event when they witness death.
func _trigger_sorrow_in_nearby_pawns() -> void:
	# DISABLED for performance - iterates through all pawns
	return


func _derive_last_words(cause: String) -> String:
	var phrases: Array[String] = []
	if data != null:
		if data.hunger < 20.0:
			phrases.append("So hungry...")
			phrases.append("I should have eaten more.")
			phrases.append("At least the children will eat.")
		if data.health < 30.0:
			phrases.append("It hurts...")
			phrases.append("Make it stop.")
			phrases.append("I'm tired of fighting.")
		if data.mood > 60.0:
			phrases.append("It was a good life.")
			phrases.append("I am at peace.")
			phrases.append("Tell them I loved them.")
		if data.mood < 30.0:
			phrases.append("No one will remember me.")
			phrases.append("It was all for nothing.")
			phrases.append("I should have run.")
		# Profession-specific
		match int(data.current_profession):
			data.Profession.WARRIOR:
				phrases.append("The wall... protect the wall.")
				phrases.append("I die standing.")
			data.Profession.SCHOLAR:
				phrases.append("The knowledge must live on.")
				phrases.append("Burn my notes.")
			data.Profession.FARMER:
				phrases.append("The harvest was good this year.")
				phrases.append("Plant the seeds before rain.")
			data.Profession.BUILDER:
				phrases.append("I never finished the shrine.")
				phrases.append("Build higher walls.")
			data.Profession.HEALER:
				phrases.append("I could not save myself.")
				phrases.append("The medicine is in the chest.")
	# Fallback cause-based
	match cause:
		"starvation":
			phrases.append("If only there had been more food.")
		"exhaustion":
			phrases.append("Let me rest a moment.")
		"injury":
			phrases.append("Tell them I stood my ground.")
		"combat":
			phrases.append("Keep the hearth safe.")
		"violence":
			phrases.append("Remember my name.")
		"battle":
			phrases.append("We were here.")
		_:
			phrases.append("Carry on without me.")
	# Fallback if still empty
	if phrases.is_empty():
		phrases.append("...")
		phrases.append("Is this the end?")
		phrases.append("I see a light.")
		phrases.append("Tell my family I love them.")
	# Deterministic choice based on pawn data
	var idx: int = absi(int(data.id if data != null else 0) * 17 + GameManager.tick_count * 3) % phrases.size()
	return phrases[idx]


func _check_thresholds() -> void:
	_hunger_level = _update_level(data.hunger, _hunger_level, "hungry",  "starving")
	_rest_level   = _update_level(data.rest,   _rest_level,   "tired",   "exhausted")
	_mood_level   = _update_level(data.mood,   _mood_level,   "unhappy", "miserable")


func _update_level(value: float, prev_level: int, warn_word: String, crit_word: String) -> int:
	var new_level: int = _level_for(value)
	if new_level > prev_level:
		var word := warn_word if new_level == 1 else crit_word
		if GameManager.verbose_logs():
			print("[HeelKawnian] %s is %s  (value=%.1f)" % [data.display_name, word, value])
	return new_level


static func _level_for(value: float) -> int:
	if value <= THRESHOLD_CRIT:
		return 2
	if value <= THRESHOLD_WARN:
		return 1
	return 0


# ==================== consciousness integration ====================

## Record an event to PawnConsciousness. Lightweight â€” early-outs if system unavailable.
func _record_consciousness_event(event_type: String, description: String, emotion: float, importance: int, category: String) -> void:
	var pc: Node = get_node_or_null("/root/PawnConsciousness")
	if pc == null or not pc.has_method("record_memory"):
		return
	if data == null:
		return
	var empty_pawn_ids: Array[int] = []
	pc.record_memory(int(data.id), event_type, description, emotion, importance, category, empty_pawn_ids, data.tile_pos)

## Record witnessed death trauma in nearby pawns' consciousness
func _record_witnessed_death_consciousness() -> void:
	var pc: Node = get_node_or_null("/root/PawnConsciousness")
	if pc == null or not pc.has_method("record_memory"):
		return
	if data == null:
		return
	var sp: PawnSpawner = _resolve_pawn_spawner()
	if sp == null:
		return
	var dead_name: String = str(data.display_name)
	for p in sp.pawns:
		if p == null or not is_instance_valid(p) or p.data == null:
			continue
		if p == self:
			continue
		var dist: float = p.global_position.distance_squared_to(global_position)
		if dist > 2500.0:  # 50px radius
			continue
		var witness_pawn_ids: Array[int] = [int(data.id)]
		pc.record_memory(int(p.data.id), "witnessed_death", "Witnessed %s die" % dead_name, -70.0, 8, "trauma", witness_pawn_ids, p.data.tile_pos)

## Record kin_death grudges for family members of the dead pawn
func _record_kin_death_grudges() -> void:
	var gm: Node = get_node_or_null("/root/SocialManager")
	if gm == null or not gm.has_method("record_grudge"):
		return
	if data == null:
		return
	var sp: PawnSpawner = _resolve_pawn_spawner()
	if sp == null:
		return
	var dead_id: int = int(data.id)
	# Parents hold grudge against whoever caused the death
	for p in sp.pawns:
		if p == null or not is_instance_valid(p) or p.data == null:
			continue
		if p == self:
			continue
		var pid: int = int(p.data.id)
		# Check if this pawn is a parent of the dead pawn
		if pid == data.parent_a_id or pid == data.parent_b_id:
			gm.record_grudge(pid, dead_id, "kin_death", 1.0, 0)
		# Check if dead pawn is parent of this pawn
		if dead_id == p.data.parent_a_id or dead_id == p.data.parent_b_id:
			gm.record_grudge(pid, dead_id, "kin_death", 0.8, 0)

	# Also create gossip about the death
	var gossip: Node = get_node_or_null("/root/GossipManager")
	if gossip != null and gossip.has_method("record_gossip"):
		var cause: String = "died"
		if data.hunger <= 0.0:
			cause = "starved to death"
		elif data.rest <= 0.0:
			cause = "died of exhaustion"
		elif data.health <= 0.0:
			cause = "died from injuries"
		gossip.record_gossip(dead_id, "%s %s" % [str(data.display_name), cause], dead_id, "death", 0.8, -0.8, GameManager.tick_count)

# ==================== wander fallback ====================

## Only 4-way: the straight-line lerp between two cardinally-adjacent tile
## centers can never visually enter a neighboring tile, so pawns never appear
## to clip through an impassable corner during a wander step.
const WANDER_OFFSETS: Array[Vector2i] = [
	Vector2i( 1, 0), Vector2i(-1, 0), Vector2i(0,  1), Vector2i(0, -1),
]


func _squad_anchor_tile() -> Vector2i:
	if data == null or data.social_squad_anchor_id < 0:
		return Vector2i(-1, -1)
	if data.social_squad_anchor_id == int(data.id):
		return Vector2i(-1, -1)
	var tree: SceneTree = get_tree()
	if tree == null or tree.root == null:
		return Vector2i(-1, -1)
	var sp: Node = tree.root.find_child("PawnSpawner", true, false)
	if sp != null and sp.has_method("pawn_data_for_id"):
		var anchor: HeelKawnianData = sp.call("pawn_data_for_id", data.social_squad_anchor_id) as HeelKawnianData
		if anchor != null:
			return anchor.tile_pos
	return Vector2i(-1, -1)


func _start_wander() -> void:
	if _world == null or _world.pathfinder == null:
		return
	# Deterministic: minimize lived scar, then use regional [CulturalMemory] (weaker) as tiebreak.
	var chosen: Vector2i = Vector2i(-1, -1)
	var best_score: int = -1_000_000
	var best_sl: int = 99
	var best_cult: int = -100
	var from_rk: int = _WM._region_key(data.tile_pos.x, data.tile_pos.y)
	var from_center: int = SettlementMemory.get_center_region_for_region(from_rk)
	var from_p: float = float(IntentMemory.settlement_pressure.get(from_center, 0.5))
	var squad_anchor: Vector2i = _squad_anchor_tile()
	var dist_now: int = -1
	if squad_anchor.x >= 0:
		dist_now = absi(data.tile_pos.x - squad_anchor.x) + absi(data.tile_pos.y - squad_anchor.y)
	for offset in WANDER_OFFSETS:
		var t: Vector2i = data.tile_pos + offset
		if not _world.pathfinder.is_passable(t):
			continue
		var s: int = _scar_level_at_tile(t)
		var rk2: int = _WM._region_key(t.x, t.y)
		var crep: int = CulturalMemory.get_region_reputation(rk2)
		var ckr2: int = SettlementMemory.get_center_region_for_region(rk2)
		var intent2: int = int(IntentMemory.settlement_intent.get(ckr2, IntentMemory.INTENT_HOLD))
		var p2: float = float(IntentMemory.settlement_pressure.get(ckr2, 0.5))
		var score: int = 0
		if intent2 == IntentMemory.INTENT_GROW:
			score += 7
		elif intent2 == IntentMemory.INTENT_ABANDON:
			score -= 8
		if p2 < from_p:
			score += 2
		elif p2 > from_p + 0.12:
			score -= 2
		score += crep
		score -= s * 3
		if dist_now >= 0:
			var dist_t: int = absi(t.x - squad_anchor.x) + absi(t.y - squad_anchor.y)
			if dist_t < dist_now:
				score += 5
		# Seasonal migration bias
		if _world != null and _world.data != null:
			var _season_label: String = Biome.season_name(Biome.season_for_tick(GameManager.tick_count)).to_lower()
			var _tile_biome: int = _world.data.get_biome(t.x, t.y)
			match _season_label:
				"winter":
					if _tile_biome in [Biome.Type.TUNDRA, Biome.Type.MOUNTAIN]:
						score -= 5
					if _tile_biome in [Biome.Type.PLAINS, Biome.Type.FOREST]:
						score -= 2
				"summer":
					if _tile_biome == Biome.Type.DESERT:
						score -= 3
				"spring":
					if _tile_biome == Biome.Type.PLAINS:
						score += 3
		if score > best_score or (score == best_score and (s < best_sl or (s == best_sl and crep > best_cult))):
			best_score = score
			best_sl = s
			best_cult = crep
			chosen = t
	if chosen.x < 0:
		return
	var path: Array[Vector2i] = [chosen]
	_start_path(path)


# ==================== render ====================

func _pixel_sprite_mask() -> Array:
	# 7-wide grid: 0 empty, 1 skin, 2 hair, 3 apparel (same semantic as circle layers).
	return [
		[0, 2, 2, 2, 2, 2, 0],
		[0, 2, 1, 1, 1, 2, 0],
		[0, 1, 1, 1, 1, 1, 0],
		[0, 3, 3, 3, 3, 3, 0],
		[0, 3, 1, 3, 1, 3, 0],
		[0, 3, 3, 3, 3, 3, 0],
		[0, 0, 3, 0, 3, 0, 0],
		[0, 0, 3, 0, 3, 0, 0],
	]


func _draw_procedural_pixel_figure(origin: Vector2, body_radius: float) -> void:
	var px: float = clampf(body_radius * 0.42, 0.55, 0.95)
	var c_skin: Color = data.color
	var c_hair: Color = data.hair_color
	var c_app: Color = data.apparel_color
	if _state == State.SLEEPING:
		c_skin = c_skin.darkened(0.25)
		c_hair = c_hair.darkened(0.2)
		c_app = c_app.darkened(0.15)
	var mask: Array = _pixel_sprite_mask()
	var rows: int = mask.size()
	var cols: int = (mask[0] as Array).size()
	for y in range(rows):
		var row: Array = mask[y] as Array
		for x in range(row.size()):
			var t: int = int(row[x])
			if t == 0:
				continue
			var col: Color = c_skin if t == 1 else (c_hair if t == 2 else c_app)
			var ox: float = (float(x) - float(cols) * 0.5 + 0.5) * px
			var oy: float = (float(y) - float(rows) * 0.5 + 0.5) * px
			var p: Vector2 = origin + Vector2(ox, oy)
			draw_rect(Rect2(p, Vector2(px * 0.9, px * 0.9)), col, true)


func _draw() -> void:
	if data == null:
		return
	var body_radius: float = _body_radius()
	var bob: float = 0.0
	if not _path.is_empty() and _state != State.SLEEPING:
		bob = sin(_anim_t * 9.0) * 0.45
	var body_origin: Vector2 = Vector2(0.0, bob)
	# Sleeping pawns render slightly dimmer to read as "off duty".
	var body_color: Color = data.color
	if _state == State.SLEEPING:
		body_color = data.color.darkened(0.25)

	# Profession body tint â€” strong overlay so pawns of same role look alike
	if data.current_profession != HeelKawnianData.Profession.NONE:
		var prof_tint: Color = _profession_color(data.current_profession)
		body_color = body_color.lerp(prof_tint, 0.30)

	# Armor tint: subtle overlay from equipped armor
	var armor_gear: Variant = data.equipped_gear.get(1, null)  # Slot.ARMOR
	if armor_gear != null and armor_gear.has_method("is_broken") and not armor_gear.is_broken():
		var armor_tint: Color = Color8(140, 160, 200)  # steel blue tint
		body_color = body_color.lerp(armor_tint, 0.15)

	# --- Shadow: dark ellipse below body for depth ---
	_draw_ellipse_shape(body_origin + Vector2(1.5, 2.0), body_radius * 0.9, body_radius * 0.45, Color(0.0, 0.0, 0.0, 0.2))

	# --- Directional body: teardrop when moving, ellipse when sleeping ---
	if _state == State.SLEEPING:
		# Horizontal ellipse (laying down)
		_draw_ellipse_shape(body_origin, body_radius * 1.3, body_radius * 0.6, body_color)
		# Blanket: lighter overlay
		_draw_ellipse_shape(body_origin + Vector2(0.0, 0.15), body_radius * 1.1, body_radius * 0.4, body_color.lightened(0.15))
	else:
		# Teardrop body: circle + triangle tail pointing away from movement direction
		var facing_angle: float = atan2(_facing_dir.y, _facing_dir.x)
		# Body circle
		draw_circle(body_origin, body_radius, body_color)
		# Tail: small triangle behind the body (opposite to facing)
		var tail_angle: float = facing_angle + PI  # opposite direction
		var tail_tip: Vector2 = body_origin + Vector2(cos(tail_angle), sin(tail_angle)) * (body_radius + 1.2)
		var tail_side_a: Vector2 = body_origin + Vector2(cos(tail_angle + 0.6), sin(tail_angle + 0.6)) * body_radius * 0.7
		var tail_side_b: Vector2 = body_origin + Vector2(cos(tail_angle - 0.6), sin(tail_angle - 0.6)) * body_radius * 0.7
		draw_colored_polygon(
			PackedVector2Array([tail_tip, tail_side_a, tail_side_b]),
			body_color.darkened(0.1)
		)
		# Head: small lighter circle at the front
		var head_offset: Vector2 = Vector2(cos(facing_angle), sin(facing_angle)) * (body_radius * 0.5)
		draw_circle(body_origin + head_offset, body_radius * 0.55, body_color.lightened(0.12))
		# --- Walk animation: 2-frame leg cycle ---
		var leg_c: Color = body_color.darkened(0.2)
		var leg_len: float = body_radius * 0.6
		if not _path.is_empty():
			# Walking: alternate legs based on animation timer
			var step: int = int(_anim_t * 6.0) % 2
			var perp_x: float = -sin(facing_angle)
			var perp_y: float = cos(facing_angle)
			var fwd_x: float = cos(facing_angle)
			var fwd_y: float = sin(facing_angle)
			var leg_base: Vector2 = body_origin + Vector2(fwd_x, fwd_y) * body_radius * 0.3
			if step == 0:
				# Left leg forward, right leg back
				draw_line(leg_base + Vector2(perp_x, perp_y) * 1.0, leg_base + Vector2(perp_x, perp_y) * 1.0 + Vector2(fwd_x, fwd_y) * leg_len, leg_c, 0.8, true)
				draw_line(leg_base - Vector2(perp_x, perp_y) * 1.0, leg_base - Vector2(perp_x, perp_y) * 1.0 - Vector2(fwd_x, fwd_y) * leg_len * 0.5, leg_c, 0.8, true)
			else:
				# Right leg forward, left leg back
				draw_line(leg_base - Vector2(perp_x, perp_y) * 1.0, leg_base - Vector2(perp_x, perp_y) * 1.0 + Vector2(fwd_x, fwd_y) * leg_len, leg_c, 0.8, true)
				draw_line(leg_base + Vector2(perp_x, perp_y) * 1.0, leg_base + Vector2(perp_x, perp_y) * 1.0 - Vector2(fwd_x, fwd_y) * leg_len * 0.5, leg_c, 0.8, true)
		elif _state == State.WORKING:
			# Work animation: tool swing
			var swing: float = sin(_anim_t * 4.0) * 0.5
			var tool_angle: float = facing_angle + PI * 0.5 + swing
			var tool_base: Vector2 = body_origin + Vector2(cos(facing_angle), sin(facing_angle)) * body_radius * 0.8
			var tool_tip: Vector2 = tool_base + Vector2(cos(tool_angle), sin(tool_angle)) * body_radius * 1.2
			draw_line(tool_base, tool_tip, Color8(160, 140, 100), 0.8, true)
		elif _state == State.IDLE:
			# Idle fidget: subtle body sway (already handled by bob)
			pass
	
	# Outline color communicates state (simplified)
	var outline_c: Color = Color.BLACK
	if _state == State.WORKING:
		outline_c = Color.WHITE
	elif _state == State.EATING:
		outline_c = Color(0.2, 0.9, 0.2)
	elif _state == State.SLEEPING:
		outline_c = Color(0.49, 0.30, 0.81)
	elif _state == State.DRAFT_WALK:
		outline_c = Color(0.45, 0.95, 1.0)
	draw_arc(body_origin, body_radius, 0.0, TAU, 20, outline_c, OUTLINE_WIDTH, true)
	
	# Selection ring with pulsing glow
	if is_selected:
		var pulse: float = 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.005)
		var sel_color := Color(1.0, 0.92, 0.18, pulse)
		draw_arc(body_origin, body_radius + 3.5, 0.0, TAU, 28, sel_color, 1.4, true)
		# Outer glow ring
		var glow_alpha: float = pulse * 0.35
		draw_arc(body_origin, body_radius + 6.0, 0.0, TAU, 28, Color(1.0, 0.92, 0.18, glow_alpha), 2.0, true)

	# Weapon silhouette: tiny pixel icon beside the pawn
	var weapon_gear: Variant = data.equipped_gear.get(0, null)  # Slot.WEAPON
	if weapon_gear != null and weapon_gear.has_method("is_broken") and not weapon_gear.is_broken():
		var weapon_color: Color = Color8(200, 180, 140)  # tan weapon color
		if weapon_gear.enchantments.size() > 0:
			weapon_color = Color8(180, 140, 255)  # purple glow for enchanted
		var w_pos: Vector2 = body_origin + Vector2(body_radius + 1.5, -1.0)
		# Small weapon shape: 2px line + 1px crossguard
		draw_line(w_pos, w_pos + Vector2(0.0, 4.0), weapon_color, 1.0, true)
		draw_line(w_pos + Vector2(-1.0, 1.0), w_pos + Vector2(1.0, 1.0), weapon_color, 1.0, true)

	# --- Carrying indicator: tiny colored square showing what pawn is hauling ---
	if data.is_carrying():
		var carry_c: Color = _carrying_color(data.carrying)
		var carry_pos: Vector2 = body_origin + Vector2(body_radius + 1.0, 0.5)
		draw_rect(Rect2(carry_pos, Vector2(1.5, 1.5)), carry_c, true)
		draw_rect(Rect2(carry_pos, Vector2(1.5, 1.5)), Color(0, 0, 0, 0.4), false)

	# Profession indicator: visible badge above the pawn
	if data.current_profession != HeelKawnianData.Profession.NONE:
		var prof_color: Color = _profession_color(data.current_profession)
		var prof_pos: Vector2 = body_origin + Vector2(0.0, -body_radius - 3.5)
		var badge_r: float = 2.0
		draw_circle(prof_pos, badge_r, prof_color)
		# Draw a small profession-specific shape inside the badge
		match data.current_profession:
			HeelKawnianData.Profession.FARMER:
				# Triangle (wheat)
				var s: float = badge_r * 0.7
				draw_colored_polygon(
					PackedVector2Array([prof_pos + Vector2(0, -s), prof_pos + Vector2(-s, s), prof_pos + Vector2(s, s)]),
					Color.WHITE
				)
			HeelKawnianData.Profession.BUILDER:
				# Square (brick)
				var s: float = badge_r * 0.55
				draw_rect(Rect2(prof_pos - Vector2(s, s), Vector2(s * 2, s * 2)), Color.WHITE, true)
			HeelKawnianData.Profession.GATHERER:
				# Diamond (leaf)
				var s: float = badge_r * 0.7
				draw_colored_polygon(
					PackedVector2Array([prof_pos + Vector2(0, -s), prof_pos + Vector2(s, 0), prof_pos + Vector2(0, s), prof_pos + Vector2(-s, 0)]),
					Color.WHITE
				)
			HeelKawnianData.Profession.WARRIOR:
				# Sword chevron
				var s: float = badge_r * 0.6
				draw_line(prof_pos + Vector2(-s, s), prof_pos + Vector2(0, -s), Color.WHITE, 1.0, true)
				draw_line(prof_pos + Vector2(s, s), prof_pos + Vector2(0, -s), Color.WHITE, 1.0, true)
			HeelKawnianData.Profession.SCHOLAR:
				# Star (knowledge)
				var s: float = badge_r * 0.5
				draw_circle(prof_pos, s, Color.WHITE)
			HeelKawnianData.Profession.TRADER:
				# Circle (coin)
				var s: float = badge_r * 0.45
				draw_circle(prof_pos, s, Color.WHITE)
			HeelKawnianData.Profession.SMITH:
				# Inverted triangle (anvil)
				var s: float = badge_r * 0.7
				draw_colored_polygon(
					PackedVector2Array([prof_pos + Vector2(-s, -s), prof_pos + Vector2(s, -s), prof_pos + Vector2(0, s)]),
					Color.WHITE
				)
			HeelKawnianData.Profession.HEALER:
				# Cross (medical)
				var s: float = badge_r * 0.6
				var t: float = badge_r * 0.2
				draw_rect(Rect2(prof_pos - Vector2(t, s), Vector2(t * 2, s * 2)), Color.WHITE, true)
				draw_rect(Rect2(prof_pos - Vector2(s, t), Vector2(s * 2, t * 2)), Color.WHITE, true)

	# Draft marker only
	if draft_mode:
		var c0: Vector2 = body_origin + Vector2(-2.5, DRAFT_CHEVRON_Y)
		var c1: Vector2 = body_origin + Vector2(0.0, DRAFT_CHEVRON_Y - 2.0)
		var c2: Vector2 = body_origin + Vector2(2.5, DRAFT_CHEVRON_Y)
		draw_polyline([c0, c1, c2], Color(1.0, 0.35, 0.25), 1.0, true)

	# --- Activity status icon: tiny pixel icon above pawn ---
	if _state != State.IDLE:
		_draw_activity_icon(body_origin, body_radius)

	# Social bond lines â€” draw thin lines to bonded pawns when selected
	if is_selected and data != null:
		_draw_social_bonds(body_origin)


func _profession_color(prof: int) -> Color:
	match prof:
		HeelKawnianData.Profession.FARMER:   return Color(0.85, 0.65, 0.2)   # gold
		HeelKawnianData.Profession.BUILDER:  return Color(0.6, 0.6, 0.6)     # silver
		HeelKawnianData.Profession.GATHERER: return Color(0.2, 0.75, 0.3)    # green
		HeelKawnianData.Profession.WARRIOR:  return Color(0.9, 0.2, 0.2)     # red
		HeelKawnianData.Profession.SCHOLAR:  return Color(0.3, 0.5, 0.9)     # blue
		HeelKawnianData.Profession.TRADER:   return Color(0.85, 0.75, 0.2)   # amber
		HeelKawnianData.Profession.SMITH:    return Color(0.55, 0.55, 0.6)   # steel
		HeelKawnianData.Profession.HEALER:   return Color(0.3, 0.75, 0.65)   # teal
		_:                            return Color.WHITE


## PROFESSION PRIORITY BONUS - Builders prioritize build jobs, Warriors prioritize hunt
## INCREASED bonuses to ensure profession bias dominates over other job priority factors
func _get_profession_priority_bonus(job: Job) -> int:
	if data == null or data.current_profession == HeelKawnianData.Profession.NONE:
		return 0
	
	# Builder: +10 priority for all build jobs (critical for housing strain fix)
	if data.current_profession == HeelKawnianData.Profession.BUILDER:
		match job.type:
			Job.Type.BUILD_BED, Job.Type.BUILD_WALL, Job.Type.BUILD_DOOR, Job.Type.BUILD_SHELTER, Job.Type.BUILD_HEARTH:
				return 10  # VERY HIGH priority for builds
			Job.Type.BUILD_FIRE_PIT, Job.Type.BUILD_STORAGE_HUT, Job.Type.BUILD_SHRINE, Job.Type.BUILD_MARKER_STONE:
				return 8
			Job.Type.GATHER_STICK, Job.Type.GATHER_FLINT:  # Building materials
				return 5
			Job.Type.MINE, Job.Type.MINE_WALL:  # Stone for building
				return 4
	
	# Warrior: +10 priority for hunt/combat jobs
	if data.current_profession == HeelKawnianData.Profession.WARRIOR:
		match job.type:
			Job.Type.HUNT:
				return 10
			Job.Type.PROTECT, Job.Type.DEFEND:
				return 8
			Job.Type.CRAFT_SPEAR:  # Weapon crafting
				return 5
	
	# Gatherer: +8 priority for foraging/gathering
	if data.current_profession == HeelKawnianData.Profession.GATHERER:
		match job.type:
			Job.Type.FORAGE, Job.Type.CHOP:
				return 8
			Job.Type.GATHER_STICK, Job.Type.GATHER_FLINT:
				return 6
			Job.Type.HUNT:
				return 4
	
	# Scholar: +8 priority for teaching/crafting
	if data.current_profession == HeelKawnianData.Profession.SCHOLAR:
		match job.type:
			Job.Type.TEACH_SKILL, Job.Type.APPRENTICESHIP:
				return 10
			Job.Type.CRAFT_KNIFE, Job.Type.CRAFT_TORCH, Job.Type.CRAFT_PICK, Job.Type.CRAFT_SPEAR:
				return 6
			Job.Type.BUILD_SHRINE:
				return 8
	
	# Farmer: +8 priority for food jobs
	if data.current_profession == HeelKawnianData.Profession.FARMER:
		match job.type:
			Job.Type.FORAGE, Job.Type.PLANT_SEEDS, Job.Type.HARVEST_CROPS:
				return 10
			Job.Type.HUNT, Job.Type.COOK_MEAT, Job.Type.COOK_BERRIES, Job.Type.COOK_FISH:

	# Trader: +8 priority for trade/haul jobs
	if data.current_profession == HeelKawnianData.Profession.TRADER:
		match job.type:
			Job.Type.TRADE_HAUL:
				return 10
			Job.Type.BUILD_MARKET, Job.Type.BUILD_TRADING_POST:
				return 8
			Job.Type.FORAGE:
				return 5  # gather trade goods

	# Smith: +8 priority for craft/mine jobs
	if data.current_profession == HeelKawnianData.Profession.SMITH:
		match job.type:
			Job.Type.CRAFT_KNIFE, Job.Type.CRAFT_PICK, Job.Type.CRAFT_SPEAR:
				return 10
			Job.Type.MINE, Job.Type.MINE_WALL:
				return 8
			Job.Type.BUILD_WORKSHOP, Job.Type.BUILD_SMELTER:
				return 6

	# Healer: +8 priority for healing/cooking jobs
	if data.current_profession == HeelKawnianData.Profession.HEALER:
		match job.type:
			Job.Type.COOK_MEAT, Job.Type.COOK_BERRIES, Job.Type.COOK_FISH:
			Job.Type.BUILD_APOTHECARY:
				return 8
			Job.Type.FORAGE:
				return 5  # gather herbs

	return 0


## Merge two priority callbacks into one
func _merge_priority_callbacks(cb1: Callable, cb2: Callable) -> Callable:
	if not cb1.is_valid() and not cb2.is_valid():
		return Callable()
	if not cb1.is_valid():
		return cb2
	if not cb2.is_valid():
		return cb1
	
	# Return a merged callback that sums both bonuses
	return func(job: Job) -> int:
		var bonus1: int = int(cb1.call(job)) if cb1.is_valid() else 0
		var bonus2: int = int(cb2.call(job)) if cb2.is_valid() else 0
		return bonus1 + bonus2


## Draw thin lines to bonded pawns when this pawn is selected.
## Family bonds = gold, social squad = teal. Only draws to nearby pawns.
func _draw_social_bonds(body_origin: Vector2) -> void:
	if data == null:
		return

	# OPTIMIZATION: Stricter distance culling for smoother rendering
	const MAX_DIST_SQ: float = 10000.0  # ~100^2 tiles (reduced from 500^2)
	const FAMILY_BOND_LIMIT: int = 8  # Limit family bonds drawn

	# Family bonds â€” gold lines
	var bonds_drawn: int = 0
	for other_id in data.family_bonds:
		if bonds_drawn >= FAMILY_BOND_LIMIT:
			break
		var other_pawn: HeelKawnian = _find_pawn_by_id(int(other_id))
		if other_pawn == null or not is_instance_valid(other_pawn):
			continue
		var dist_sq: float = global_position.distance_squared_to(other_pawn.global_position)
		if dist_sq > MAX_DIST_SQ:
			continue
		var strength: float = float(data.family_bonds[other_id])
		var alpha: float = clampf(strength / 100.0, 0.15, 0.8)
		var local_end: Vector2 = to_local(other_pawn.global_position)
		draw_line(body_origin, local_end, Color(1.0, 0.85, 0.3, alpha), 1.0, true)
		bonds_drawn += 1

	# Social squad â€” teal line to anchor
	if data.social_squad_anchor_id >= 0 and data.social_squad_anchor_id != int(data.id):
		var anchor_pawn: HeelKawnian = _find_pawn_by_id(data.social_squad_anchor_id)
		if anchor_pawn != null and is_instance_valid(anchor_pawn):
			var dist_sq: float = global_position.distance_squared_to(anchor_pawn.global_position)
			if dist_sq <= MAX_DIST_SQ:
				var local_end: Vector2 = to_local(anchor_pawn.global_position)
				draw_line(body_origin, local_end, Color(0.3, 0.8, 0.8, 0.5), 1.0, true)

	# Phase 5: Enemy avoidance lines â€” red lines to grudge-enemies
	# OPTIMIZATION: Use cached enemy pawns, limit to top 3 by intensity, stricter culling
	const ENEMY_DIST_SQ: float = 6400.0  # ~80^2 tiles (stricter culling)
	var enemies: Array[int] = get_grudge_enemies()
	if enemies.is_empty():
		return
	
	# OPTIMIZATION: Avoid sorting every frame - just take first 3 if already limited
	if enemies.size() > 3:
		# Quick intensity check without full sort - take first 3 above threshold
		var high_intensity_enemies: Array[int] = []
		for enemy_id in enemies:
			if get_grudge_toward(enemy_id) >= 0.5:
				high_intensity_enemies.append(enemy_id)
				if high_intensity_enemies.size() >= 3:
					break
		if high_intensity_enemies.size() < 3:
			# Fill remaining slots with any enemies
			for enemy_id in enemies:
				if not high_intensity_enemies.has(enemy_id):
					high_intensity_enemies.append(enemy_id)
					if high_intensity_enemies.size() >= 3:
						break
		enemies = high_intensity_enemies
	else:
		enemies = enemies.slice(0, 3)

	var _ps: PawnSpawner = _resolve_pawn_spawner()
	for enemy_id in enemies:
		var enemy_pawn: HeelKawnian = _ps.get_pawn_by_id(enemy_id) if _ps != null else null
		if enemy_pawn == null or not is_instance_valid(enemy_pawn):
			continue
		var dist_sq: float = global_position.distance_squared_to(enemy_pawn.global_position)
		if dist_sq > ENEMY_DIST_SQ:
			continue
		# Get grudge intensity for line opacity
		var intensity: float = get_grudge_toward(enemy_id)
		var alpha: float = clampf(intensity, 0.3, 0.9)
		var local_end: Vector2 = to_local(enemy_pawn.global_position)
		# Red line for enemies (thicker for higher intensity)
		var width: float = 1.0 + (intensity * 1.5)
		draw_line(body_origin, local_end, Color(1.0, 0.2, 0.2, alpha), width, true)


## Short activity verb shown below the pawn. Empty string for idle.
func _activity_label() -> String:
	match _state:
		State.WALKING_TO_JOB, State.FETCHING_MATERIAL:
			if _current_job != null:
				return "â†’ %s" % Job.describe_type(_current_job.type).to_lower()
			return "walking"
		State.WORKING:
			if _current_job != null:
				return Job.describe_type(_current_job.type).to_lower()
			return "working"
		State.HAULING:
			return "hauling"
		State.GOING_TO_EAT:
			return "â†’ food"
		State.EATING:
			return "eating"
		State.SLEEPING:
			return "zzz"
		State.GOING_TO_BED:
			return "â†’ bed"
		State.TEACHING:
			return "teaching"
		State.CHALLENGE:
			return "challenging"
		State.DRAFT_WALK:
			return "marching"
		State.GATHERING:
			return "gathering"
		State.CRAFTING:
			return "crafting"
		State.FLEEING:
			return "fleeing!"
		State.HIDING:
			return "hiding"
		_:
			return ""


func _activity_label_color() -> Color:
	match _state:
		State.WORKING, State.WALKING_TO_JOB, State.FETCHING_MATERIAL:
			return Color(0.9, 0.88, 0.7)    # warm white
		State.HAULING:
			return Color(0.7, 0.7, 0.8)     # cool gray
		State.GOING_TO_EAT, State.EATING:
			return Color(0.5, 0.9, 0.5)     # green
		State.SLEEPING, State.GOING_TO_BED:
			return Color(0.6, 0.5, 0.8)     # purple
		State.TEACHING:
			return Color(0.5, 0.7, 0.95)    # blue
		State.CHALLENGE:
			return Color(1.0, 0.6, 0.3)     # orange
		State.DRAFT_WALK:
			return Color(1.0, 0.4, 0.35)    # red
		State.GATHERING:
			return Color(0.4, 0.8, 0.4)     # green
		State.CRAFTING:
			return Color(0.8, 0.7, 0.4)     # gold
		State.FLEEING, State.HIDING:
			return Color(1.0, 0.3, 0.3)     # red
		_:
			return Color(0.7, 0.7, 0.7)


## Get cached enemy list, refreshing every 30 ticks.
static func _get_enemies_cached() -> Array:
	var now: int = GameManager.tick_count if GameManager != null else 0
	if now - HeelKawnian._cached_enemies_tick >= 30:
		HeelKawnian._cached_enemies = []
		var tree: SceneTree = Engine.get_main_loop() as SceneTree
		if tree != null:
			for e in tree.get_nodes_in_group("enemies"):
				if e != null and is_instance_valid(e):
					HeelKawnian._cached_enemies.append(e)
		HeelKawnian._cached_enemies_tick = now
	return HeelKawnian._cached_enemies


## Cached job-type â†’ upper-name string. Avoids str()+to_upper() per pawn per tick.
static func _cached_job_type_name(job_type: int) -> String:
	if not HeelKawnian._job_type_name_cache_built:
		var keys: Array = _Job.Type.keys()
		for i in range(keys.size()):
			HeelKawnian._job_type_name_cache[i] = str(keys[i]).to_upper()
		HeelKawnian._job_type_name_cache_built = true
	return str(HeelKawnian._job_type_name_cache.get(job_type, "UNKNOWN"))


func _body_radius() -> float:
	if data == null:
		return DRAW_RADIUS
	match data.body_type:
		HeelKawnianData.BodyType.SLIM:
			return DRAW_RADIUS - 0.35
		HeelKawnianData.BodyType.BROAD:
			return DRAW_RADIUS + 0.45
		_:
			return DRAW_RADIUS


func _draw_hair(body_origin: Vector2, body_radius: float) -> void:
	if data == null:
		return
	var hair_c: Color = data.hair_color
	match data.hair_style:
		HeelKawnianData.HairStyle.NONE:
			return
		HeelKawnianData.HairStyle.SHORT:
			draw_arc(body_origin + Vector2(0.0, -0.2), body_radius - 0.4, PI * 1.05, PI * 1.95, 10, hair_c, 1.0, true)
		HeelKawnianData.HairStyle.MOHAWK:
			draw_line(body_origin + Vector2(0.0, -body_radius), body_origin + Vector2(0.0, body_radius * 0.2), hair_c, 1.1, true)
		HeelKawnianData.HairStyle.BUN:
			draw_circle(body_origin + Vector2(0.0, -body_radius - 0.75), 0.8, hair_c)


func _play_sfx(path: String, pitch: float = 1.0) -> void:
	if _sfx == null:
		return
	if ResourceLoader.exists(path):
		var stream: AudioStream = load(path)
		if stream != null:
			_sfx.stream = stream
			_sfx.pitch_scale = pitch
			_sfx.play()
			return
	_play_tone(660.0 * pitch, 0.045, 0.07)


func _play_tone(freq: float, duration: float, amp: float) -> void:
	if _sfx == null:
		return
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050
	gen.buffer_length = max(0.05, duration + 0.02)
	_sfx.stop()
	_sfx.stream = gen
	_sfx.pitch_scale = 1.0
	_sfx.play()
	var pb: AudioStreamGeneratorPlayback = _sfx.get_stream_playback() as AudioStreamGeneratorPlayback
	if pb == null:
		return
	var frames: int = int(gen.mix_rate * duration)
	for i in range(frames):
		var t: float = float(i) / float(gen.mix_rate)
		var sample: float = sin(TAU * freq * t) * amp
		pb.push_frame(Vector2(sample, sample))


func on_hit_feedback(damage: float) -> void:
	_hit_flash_ticks = 5
	_play_sfx("res://assets/audio/pawn_hurt.ogg", 0.9 + min(0.2, damage * 0.01))


# ---------------------------------------------------------------------------
# Public introspection (used by PawnInfoPanel / selection UI)
#
# get_state() already lives up in the AI section -- don't add another one
# down here or you'll get a "duplicate function" parse error that takes the
# whole class down with it (HeelKawnian fails to load -> JobManager signals can't
# resolve `pawn: HeelKawnian` -> every dependent script fails to load too).
# ---------------------------------------------------------------------------

## Read-only accessor for the pawn's current job, may be null.
func get_current_job() -> Job:
	return _current_job


func get_runtime_cohort_observability() -> Dictionary:
	return {
		"anchor_id": int(data.cohort_anchor_id) if data != null else -1,
		"cohort_job_type": int(data.cohort_job_type) if data != null else -1,
		"is_anchor": bool(data.is_cohort_anchor) if data != null else false,
		"active_job_type": _active_cohort_job_type(),
		"locus_tile": _cohort_locus_tile,
		"stability_ticks": _cohort_stability_ticks,
		"stability_job_type": _cohort_stability_job_type,
	}


## Returns true if the pawn is currently asleep in a registered bed.
func is_in_bed() -> bool:
	return _state == State.SLEEPING and _reserved_bed.x >= 0


## Returns true if the pawn is currently sleeping (bed or ground).
func is_sleeping() -> bool:
	return _state == State.SLEEPING


## Human-readable summary of what the pawn is doing right now.
## Used by the info panel and (optionally) tooltips.
func describe_state() -> String:
	match _state:
		State.IDLE:
			return "Idle"
		State.WALKING_TO_JOB:
			if _current_job != null:
				return "Moving to %s" % _verb_for_job(_current_job.type).to_lower()
			return "Moving"
		State.WORKING:
			if _current_job != null:
				return _verb_for_job(_current_job.type)
			return "Working"
		State.HAULING:
			if data != null and data.is_carrying():
				return "Hauling %s" % Item.name_for(data.carrying)
			return "Hauling"
		State.GOING_TO_EAT:
			return "Seeking Food"
		State.EATING:
			return "Eating"
		State.SLEEPING:
			if _reserved_bed.x >= 0:
				return "Sleeping in Bed"
			return "Sleeping (Ground)"
		State.GOING_TO_BED:
			return "Moving to Bed"
		State.FETCHING_MATERIAL:
			if _current_job != null:
				return "Gathering for %s" % _verb_for_job(_current_job.type).to_lower()
			return "Gathering Materials"
		State.DRAFT_WALK:
			return "Moving (Ordered)"
		State.TEACHING:
			return "Teaching"
		State.CHALLENGE:
			return "Challenging Authority"
		State.GATHERING:
			return "Gathering"
		State.CRAFTING:
			return "Crafting"
		State.FLEEING:
			return "Fleeing"
		State.HIDING:
			return "Hiding"
	return "Unknown State"


func _pawn_neural_autonomy_pulse() -> void:
	if data == null or data.neural_network == null:
		return
	var nn: Variant = data.neural_network
	if not nn.has_method("tick_autonomy"):
		return
	var ctx: Dictionary = {
		"hunger": data.hunger,
		"rest": data.rest,
		"mood": data.mood,
		"fear": clampf(data.pain + data.exposure_sickness * 0.35 + data.hypothermia_risk * 0.25, 0.0, 100.0),
		"shelter": 0.55,
		"social_warmth": clampf(float(data.co_presence.size()) / 12.0, 0.0, 1.0),
		"clan_bond": clampf(float(data.family_bonds.size()) / 8.0, 0.0, 1.0),
		"nation_pride": 0.42,
		"ambition": clampf(float(data.level) / 20.0, 0.0, 1.0),
		"fame": clampf(float(data.legacy_score) / 5000.0, 0.0, 1.0),
	}
	if WorldEventSystem != null:
		ctx["weather_mult"] = WorldEventSystem.get_weather_resource_mult()
		ctx["price_pressure"] = WorldEventSystem.get_price_pressure()
		ctx["world_mood"] = WorldEventSystem.get_world_mood()
		ctx["theft_pressure"] = WorldEventSystem.get_theft_pressure()
		ctx["labor_urgency"] = WorldEventSystem.get_labor_urgency_bonus()
	nn.tick_autonomy(GameManager.tick_count, int(data.id), ctx)


static func _verb_for_job(job_type: int) -> String:
	match job_type:
		_Job.Type.FORAGE:
			return "Foraging"
		_Job.Type.MINE:
			return "Mining Stone"
		_Job.Type.MINE_WALL:
			return "Mining Wall"
		_Job.Type.CHOP:
			return "Chopping Wood"
		_Job.Type.HUNT:
			return "Hunting"
		_Job.Type.BUILD_BED:
			return "Building Bed"
		_Job.Type.BUILD_WALL:
			return "Building Wall"
		_Job.Type.BUILD_DOOR:
			return "Building Door"
		_Job.Type.GATHER_FLINT:
			return "Gathering Flint"
		_Job.Type.GATHER_STICK:
			return "Gathering Stick"
		_Job.Type.CRAFT_KNIFE:
			return "Crafting Knife"
		_Job.Type.CRAFT_TORCH:
			return "Crafting Torch"
		_Job.Type.CRAFT_PICK:
			return "Crafting Pick"
		_Job.Type.CRAFT_SPEAR:
			return "Crafting Spear"
		_Job.Type.BUILD_FIRE_PIT:
			return "Building Fire Pit"
		_Job.Type.BUILD_STORAGE_HUT:
			return "Building Storage Hut"
		_Job.Type.BUILD_MARKER_STONE:
			return "Building Marker Stone"
		_Job.Type.BUILD_SHRINE:
			return "Building Shrine"
		_Job.Type.COOK_MEAT:
			return "Cooking Meat"
		_Job.Type.COOK_BERRIES:
			return "Cooking Berries"
		_Job.Type.COOK_FISH:
			return "Cooking Fish"
		_Job.Type.DRY_MEAT:
			return "Drying Meat"
		_Job.Type.PLANT_SEEDS:
			return "Planting Seeds"
		_Job.Type.HARVEST_CROPS:
			return "Harvesting Crops"
		_Job.Type.TRADE_HAUL:
			return "Trading"
	return "Working"


## Draw a tiny activity icon above the pawn showing what they're doing.
## Replaces the text activity label with a visual icon for faster recognition.
func _draw_activity_icon(body_origin: Vector2, body_radius: float) -> void:
	var icon_pos: Vector2 = body_origin + Vector2(0.0, -body_radius - 6.5)
	var icon_c: Color = _activity_label_color()
	var s: float = 1.2
	var job_type: int = _current_job.type if _current_job != null else -1
	if _state == State.SLEEPING:
		draw_line(icon_pos + Vector2(-s, -s), icon_pos + Vector2(s, -s), icon_c, 0.8, true)
		draw_line(icon_pos + Vector2(s, -s), icon_pos + Vector2(-s, s), icon_c, 0.8, true)
		draw_line(icon_pos + Vector2(-s, s), icon_pos + Vector2(s, s), icon_c, 0.8, true)
	elif _state == State.EATING or _state == State.GOING_TO_EAT:
		draw_line(icon_pos + Vector2(0.0, -s), icon_pos + Vector2(0.0, s), icon_c, 0.8, true)
		draw_line(icon_pos + Vector2(-0.5, -s), icon_pos + Vector2(-0.5, -s + 0.8), icon_c, 0.6, true)
		draw_line(icon_pos + Vector2(0.5, -s), icon_pos + Vector2(0.5, -s + 0.8), icon_c, 0.6, true)
	elif _state == State.HAULING:
		draw_rect(Rect2(icon_pos - Vector2(s, s), Vector2(s * 2, s * 2)), icon_c, false)
		draw_line(icon_pos + Vector2(-s * 0.5, -s), icon_pos + Vector2(-s * 0.5, s), icon_c, 0.5, true)
	elif _state == State.TEACHING:
		draw_rect(Rect2(icon_pos - Vector2(s, s * 0.7), Vector2(s * 2, s * 1.4)), icon_c, false)
		draw_line(icon_pos + Vector2(0.0, -s * 0.7), icon_pos + Vector2(0.0, s * 0.7), icon_c, 0.5, true)
	elif _state == State.CHALLENGE:
		draw_line(icon_pos + Vector2(-s, s), icon_pos + Vector2(s, -s), icon_c, 0.8, true)
		draw_line(icon_pos + Vector2(s, s), icon_pos + Vector2(-s, -s), icon_c, 0.8, true)
	elif _state == State.DRAFT_WALK:
		draw_line(icon_pos + Vector2(0.0, s), icon_pos + Vector2(0.0, -s), icon_c, 0.8, true)
		draw_line(icon_pos + Vector2(-s * 0.5, -s * 0.3), icon_pos + Vector2(0.0, -s), icon_c, 0.8, true)
		draw_line(icon_pos + Vector2(s * 0.5, -s * 0.3), icon_pos + Vector2(0.0, -s), icon_c, 0.8, true)
	elif _state == State.FLEEING:
		draw_line(icon_pos + Vector2(0.0, -s), icon_pos + Vector2(0.0, s * 0.3), Color(1.0, 0.3, 0.2), 1.0, true)
		draw_circle(icon_pos + Vector2(0.0, s * 0.7), 0.3, Color(1.0, 0.3, 0.2))
	elif _state == State.WORKING or _state == State.WALKING_TO_JOB or _state == State.FETCHING_MATERIAL:
		if job_type == _Job.Type.FORAGE or job_type == _Job.Type.GATHER_STICK or job_type == _Job.Type.GATHER_FLINT:
			draw_colored_polygon(PackedVector2Array([icon_pos + Vector2(0, -s), icon_pos + Vector2(s, 0), icon_pos + Vector2(0, s), icon_pos + Vector2(-s, 0)]), icon_c)
		elif job_type == _Job.Type.CHOP:
			draw_line(icon_pos + Vector2(-s, s), icon_pos + Vector2(s, -s), icon_c, 1.0, true)
			draw_line(icon_pos + Vector2(s * 0.3, -s), icon_pos + Vector2(s, -s * 0.3), icon_c, 1.0, true)
		elif job_type == _Job.Type.MINE or job_type == _Job.Type.MINE_WALL:
			draw_line(icon_pos + Vector2(0.0, s), icon_pos + Vector2(0.0, -s), icon_c, 0.8, true)
			draw_line(icon_pos + Vector2(-s, -s), icon_pos + Vector2(s, -s), icon_c, 0.8, true)
		elif job_type == _Job.Type.HUNT:
			draw_line(icon_pos + Vector2(0.0, s), icon_pos + Vector2(0.0, -s), icon_c, 0.8, true)
			draw_line(icon_pos + Vector2(-s * 0.4, -s * 0.5), icon_pos + Vector2(0.0, -s), icon_c, 0.8, true)
			draw_line(icon_pos + Vector2(s * 0.4, -s * 0.5), icon_pos + Vector2(0.0, -s), icon_c, 0.8, true)
		elif _is_structure_build_job_type(job_type):
			draw_line(icon_pos + Vector2(0.0, s), icon_pos + Vector2(0.0, -s * 0.3), icon_c, 0.8, true)
			draw_rect(Rect2(icon_pos + Vector2(-s, -s), Vector2(s * 2, s * 0.7)), icon_c, true)
		elif job_type == _Job.Type.COOK_MEAT or job_type == _Job.Type.COOK_BERRIES or job_type == _Job.Type.COOK_FISH or job_type == _Job.Type.DRY_MEAT:
			draw_arc(icon_pos, s * 0.8, 0.0, PI, 8, icon_c, 0.8, true)
			draw_line(icon_pos + Vector2(-s, 0.0), icon_pos + Vector2(s, 0.0), icon_c, 0.8, true)
		elif job_type == _Job.Type.PROTECT or job_type == _Job.Type.DEFEND:
			draw_colored_polygon(PackedVector2Array([icon_pos + Vector2(-s, -s), icon_pos + Vector2(s, -s), icon_pos + Vector2(s, 0), icon_pos + Vector2(0, s), icon_pos + Vector2(-s, 0)]), icon_c)
		elif job_type == _Job.Type.CARVE_GRAVE_MARKER or job_type == _Job.Type.CARVE_KNOWLEDGE_STONE or job_type == _Job.Type.CARVE_LEDGER_STONE:
			draw_line(icon_pos + Vector2(-s, s), icon_pos + Vector2(s, -s), icon_c, 0.8, true)
			draw_line(icon_pos + Vector2(s * 0.5, -s * 0.5), icon_pos + Vector2(s, -s * 0.5), icon_c, 0.8, true)
		elif job_type == _Job.Type.PLANT_SEEDS or job_type == _Job.Type.HARVEST_CROPS:
			draw_line(icon_pos + Vector2(0.0, s), icon_pos + Vector2(0.0, -s * 0.3), icon_c, 0.8, true)
			draw_line(icon_pos + Vector2(-s * 0.5, -s * 0.3), icon_pos + Vector2(0.0, 0.0), Color(0.3, 0.8, 0.3), 0.8, true)
			draw_line(icon_pos + Vector2(s * 0.5, -s * 0.3), icon_pos + Vector2(0.0, 0.0), Color(0.3, 0.8, 0.3), 0.8, true)
		elif job_type == _Job.Type.TRADE_HAUL:
			draw_circle(icon_pos, s * 0.7, icon_c)
			draw_circle(icon_pos, s * 0.4, icon_c.darkened(0.3))
		else:
			draw_circle(icon_pos, s * 0.5, icon_c)
	elif _state == State.CRAFTING:
		draw_circle(icon_pos, s * 0.6, icon_c)
		draw_line(icon_pos + Vector2(0.0, -s), icon_pos + Vector2(0.0, s), icon_c, 0.6, true)
		draw_line(icon_pos + Vector2(-s, 0.0), icon_pos + Vector2(s, 0.0), icon_c, 0.6, true)
	elif _state == State.GATHERING:
		draw_line(icon_pos + Vector2(-s * 0.5, s), icon_pos + Vector2(-s * 0.5, -s * 0.3), icon_c, 0.8, true)
		draw_line(icon_pos + Vector2(0.0, s), icon_pos + Vector2(0.0, -s * 0.5), icon_c, 0.8, true)
		draw_line(icon_pos + Vector2(s * 0.5, s), icon_pos + Vector2(s * 0.5, -s * 0.3), icon_c, 0.8, true)


func _is_structure_build_job_type(t: int) -> bool:
	return (t == _Job.Type.BUILD_BED or t == _Job.Type.BUILD_WALL or t == _Job.Type.BUILD_DOOR or t == _Job.Type.BUILD_FIRE_PIT or t == _Job.Type.BUILD_STORAGE_HUT or t == _Job.Type.BUILD_MARKER_STONE or t == _Job.Type.BUILD_SHRINE or t == _Job.Type.BUILD_SHELTER or t == _Job.Type.BUILD_HEARTH or t == _Job.Type.BUILD_FARM_WHEAT or t == _Job.Type.BUILD_FARM_CORN or t == _Job.Type.BUILD_FARM_VEGETABLES or t == _Job.Type.BUILD_HERB_GARDEN or t == _Job.Type.BUILD_WORKSHOP or t == _Job.Type.BUILD_LOOM or t == _Job.Type.BUILD_KILN or t == _Job.Type.BUILD_SMELTER or t == _Job.Type.BUILD_BOATYARD or t == _Job.Type.BUILD_DOCK or t == _Job.Type.BUILD_FISHERMAN_HUT or t == _Job.Type.BUILD_APOTHECARY or t == _Job.Type.BUILD_LIBRARY or t == _Job.Type.BUILD_SCHOOL or t == _Job.Type.BUILD_BARRACKS or t == _Job.Type.BUILD_WATCHTOWER or t == _Job.Type.BUILD_MARKET or t == _Job.Type.BUILD_TRADING_POST or t == _Job.Type.BUILD_ROAD or t == _Job.Type.BUILD_GRANARY or t == _Job.Type.BUILD_CELLAR)


func _carrying_color(item_type: int) -> Color:
	match item_type:
		_Item.Type.WOOD: return Color8(139, 90, 43)
		_Item.Type.STONE: return Color8(150, 150, 150)
		_Item.Type.BERRY: return Color8(200, 50, 50)
		_Item.Type.MEAT: return Color8(180, 80, 60)
		_Item.Type.FLINT: return Color8(100, 100, 110)
		_Item.Type.STICK: return Color8(170, 130, 70)
		_Item.Type.SEEDS: return Color8(180, 160, 60)
		_Item.Type.PAPER: return Color8(240, 235, 220)
		_Item.Type.LEATHER: return Color8(160, 100, 60)
		_Item.Type.INK: return Color8(40, 40, 60)
		_Item.Type.FISH: return Color8(70, 130, 180)
		_Item.Type.COOKED_FISH: return Color8(210, 140, 80)
		_Item.Type.BONE: return Color8(220, 210, 190)
		_Item.Type.STONE_ARROW: return Color8(140, 140, 150)
		_Item.Type.BONE_ARROW: return Color8(200, 185, 165)
		_: return Color8(200, 200, 200)


func _draw_ellipse_shape(center: Vector2, rx: float, ry: float, color: Color) -> void:
	draw_colored_polygon(_ellipse_points(center, rx, ry, 12), color)


func _ellipse_points(center: Vector2, rx: float, ry: float, segments: int) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	for i in range(segments):
		var angle: float = TAU * float(i) / float(segments)
		pts.append(center + Vector2(cos(angle) * rx, sin(angle) * ry))
	return pts