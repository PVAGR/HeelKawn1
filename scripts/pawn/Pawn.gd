
class_name Pawn
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
## Tiny deterministic pixel figure (skin / hair / apparel from `PawnData`) — reads as a “sprite”
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
const HUNGER_EAT_THRESHOLD: float = 50.0
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
const REST_SLEEP_THRESHOLD: float = 35.0
const REST_SLEEP_THRESHOLD_NIGHT: float = 75.0
## Below this, the pawn is so exhausted they abandon whatever they were doing
## (job, eating, hauling) and collapse. Without this, busy pawns happily ride
## rest down to 0 because they never reach the IDLE priority chain.
const REST_PANIC_THRESHOLD: float = 12.0

# -------------------- food-supply tuning --------------------

## When the stockpile food count drops below this, idle pawns will preferentially
## claim FORAGE jobs even if other harvest types are closer. Without this safety
## net the colony can starve while pawns happily mine stone (which is exactly
## what a previous tuning pass caused). Tuned to ~2 berries per pawn -- roughly
## one in-flight emergency snack each.
const STOCKPILE_FOOD_LOW_THRESHOLD: int = 10
## Sleep ends and the pawn wakes once rest climbs above this.
const REST_WAKE_THRESHOLD: float = 90.0
## Rest restored per tick while in SLEEPING state. ~7x the normal decay rate
## so a full sleep takes ~120 ticks (12 in-game hours) to go from crit to wake.
const REST_RECOVER_PER_TICK_SLEEP: float = 0.6
## Multiplier applied to REST_RECOVER_PER_TICK_SLEEP when the sleeping pawn is
## standing on a bed they own. Beds make sleep ~67% faster.
const REST_RECOVER_BED_MULTIPLIER: float = 1.67
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
		Job.Type.BUILD_BED:  return {"item": Item.Type.WOOD, "qty": BED_WOOD_COST}
		Job.Type.BUILD_WALL: return {"item": Item.Type.WOOD, "qty": WALL_WOOD_COST}
		Job.Type.BUILD_DOOR: return {"item": Item.Type.WOOD, "qty": DOOR_WOOD_COST}
	return {}

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
## ~11.5 tiles at 10px/tile — cohabiting workers can still pair without pixel-perfect overlap.
const REPRODUCTION_MATE_RANGE_PX: float = 115.0
## When there are no bed tiles on the map, widen pairing distance so abandoned/collapse
## play can still repopulate (same path component + rapport gates still apply).
const REPRODUCTION_MATE_RANGE_NO_BEDS_MIN_TILES: float = 22.0
## Softer than general job hunger gates so pairs can raise children under colony stress.
const REPRODUCTION_MIN_HUNGER: float = 48.0
const REPRODUCTION_MIN_REST: float = 42.0
## Requires [member PawnData.social_rapport] built from co-presence (Main._accumulate_social_rapport).
const REPRODUCTION_MIN_RAPPORT: int = 72
const COHORT_UPDATE_TICKS: int = 200
const COHORT_MATCH_RADIUS_TILES: int = 8
const COHORT_BREAK_DISTANCE_TILES: int = 16
const COHORT_MIN_SIZE: int = 2
const COHORT_COHESION_BIAS_WEIGHT: float = 0.12
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
}

# -------------------- runtime --------------------

var data: PawnData

var _world: World
var _state: int = State.IDLE
var _current_job: Job = null
## Set by Main when the player clicks this pawn. Drives the selection ring
## in _draw and unlocks the side info panel.
var is_selected: bool = false
## Set by Main when pawn is in draft mode (combat). Pawns stop working and respond to click-to-move orders.
var draft_mode: bool = false

## Active path: list of tiles AFTER the current tile that must be visited in
## order. Empty means stationary.
var _path: Array[Vector2i] = []
var _path_index: int = 0
var _target_tile: Vector2i = Vector2i.ZERO
var _target_world_pos: Vector2 = Vector2.ZERO

## Ticks remaining in the EATING state.
var _eat_ticks_left: int = 0

## Teaching state variables
var _teaching_target: Pawn = null
var _teaching_ticks_left: int = 0
var _teaching_knowledge_type: int = -1

## Challenge state variables
var _challenge_target: Pawn = null
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
var _last_recruitment_job_type: int = -2
var _recruitment_signal_cache: Array[Dictionary] = []
var _cohort_stability_ticks: int = 0
var _cohort_locus_tile: Vector2i = Vector2i(-1, -1)
var _cohort_stability_job_type: int = -1
var _anim_t: float = 0.0
var _sfx: AudioStreamPlayer2D = null
var _hit_flash_ticks: int = 0
var _last_inspect_msg: String = ""
var _last_inspect_tick: int = -999999

## Autoloads (e.g. JobManager) should call these instead of `pawn.data` — the
## parser can fail to resolve the `data` member on class_name Pawn in autoload scripts.
func get_pawn_data() -> PawnData:
	return data


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
	var rk: int = preload("res://autoloads/WorldMemory.gd")._region_key(tile.x, tile.y)
	return SettlementMemory.get_center_region_for_region(rk)


func _cohort_anchor_node() -> Pawn:
	if _cohort_anchor_ref == null:
		return null
	var n: Object = _cohort_anchor_ref.get_ref()
	if n == null or not (n is Pawn):
		return null
	return n as Pawn


func _job_locus_world_pos(p: Pawn) -> Variant:
	if p == null or p.data == null or p._current_job == null or p._world == null:
		return null
	if p._active_cohort_job_type() < 0:
		return null
	return p._world.tile_to_world(p._current_job.work_tile)


func _cohort_locus_world_pos() -> Variant:
	var anchor: Pawn = _cohort_anchor_node()
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
	if data == null:
		return
	var job_type: int = _active_cohort_job_type()
	if job_type < 0:
		_clear_cohort_state()
		return
	var tick_now: int = GameManager.tick_count
	if not force and tick_now < _next_cohort_update_tick:
		return
	_next_cohort_update_tick = tick_now + COHORT_UPDATE_TICKS
	var my_center: int = _cohort_settlement_center_for_tile(data.tile_pos)
	var radius_sq: int = COHORT_MATCH_RADIUS_TILES * COHORT_MATCH_RADIUS_TILES
	var members: Array[Pawn] = []
	for n in get_tree().get_nodes_in_group("pawns"):
		if not (n is Pawn):
			continue
		var p: Pawn = n as Pawn
		if p == null or p.data == null:
			continue
		if p._active_cohort_job_type() != job_type:
			continue
		var p_center: int = p._cohort_settlement_center_for_tile(p.data.tile_pos)
		if my_center >= 0 and p_center >= 0 and p_center != my_center:
			continue
		if data.tile_pos.distance_squared_to(p.data.tile_pos) > radius_sq:
			continue
		members.append(p)
	if members.size() < COHORT_MIN_SIZE:
		_clear_cohort_state()
		return
	var anchor: Pawn = members[0]
	for p in members:
		if int(p.data.id) < int(anchor.data.id):
			anchor = p
	data.cohort_anchor_id = int(anchor.data.id)
	data.cohort_job_type = job_type
	data.is_cohort_anchor = int(data.id) == int(anchor.data.id)
	_cohort_anchor_ref = weakref(anchor)


func _validate_or_dissolve_cohort() -> void:
	if data == null:
		return
	if data.cohort_anchor_id < 0:
		return
	var job_type: int = _active_cohort_job_type()
	if job_type < 0 or data.cohort_job_type != job_type:
		_clear_cohort_state()
		return
	var anchor: Pawn = _cohort_anchor_node()
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
	var anchor: Pawn = _cohort_anchor_node()
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
		var anchor: Pawn = _cohort_anchor_node()
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


func _refresh_recruitment_signal_cache(force: bool = false) -> void:
	if data == null:
		return
	var tick_now: int = GameManager.tick_count
	if not force and tick_now < _next_recruitment_cache_tick:
		return
	_next_recruitment_cache_tick = tick_now + COHORT_RECRUITMENT_CACHE_UPDATE_TICKS
	_recruitment_signal_cache.clear()
	var radius_sq: int = COHORT_RECRUITMENT_SCAN_RADIUS_TILES * COHORT_RECRUITMENT_SCAN_RADIUS_TILES
	var my_center: int = _cohort_settlement_center_for_tile(data.tile_pos)
	var candidates: Array[Pawn] = []
	for n in get_tree().get_nodes_in_group("pawns"):
		if not (n is Pawn):
			continue
		var p: Pawn = n as Pawn
		if p == null or p == self or p.data == null:
			continue
		if p.data.tile_pos.distance_squared_to(data.tile_pos) > radius_sq:
			continue
		candidates.append(p)
	candidates.sort_custom(func(a: Pawn, b: Pawn) -> bool:
		return int(a.data.id) < int(b.data.id)
	)
	var inspected: int = 0
	var seen_keys: Dictionary = {}
	for p in candidates:
		if inspected >= COHORT_RECRUITMENT_MAX_PAWNS:
			break
		inspected += 1
		var active_job_type: int = p._active_cohort_job_type()
		if active_job_type < 0:
			continue
		if int(p.data.cohort_job_type) != active_job_type:
			continue
		if int(p.data.cohort_anchor_id) < 0:
			continue
		var p_center: int = _cohort_settlement_center_for_tile(p.data.tile_pos)
		if my_center >= 0 and p_center >= 0 and my_center != p_center:
			continue
		var locus_tile: Vector2i = p.data.tile_pos
		if p._current_job != null:
			locus_tile = p._current_job.work_tile
		var key: String = "%d:%d:%d:%d" % [active_job_type, p_center, locus_tile.x, locus_tile.y]
		if seen_keys.has(key):
			continue
		seen_keys[key] = true
		_recruitment_signal_cache.append({
			"job_type": active_job_type,
			"center": p_center,
			"locus_tile": locus_tile,
		})
		if _recruitment_signal_cache.size() >= COHORT_RECRUITMENT_MAX_SIGNALS:
			break


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


static func is_job_history_critical(job_type: int) -> bool:
	return job_type == Job.Type.FORAGE or job_type == Job.Type.HUNT


func _scar_level_at_tile(t: Vector2i) -> int:
	var rk: int = preload("res://autoloads/WorldMemory.gd")._region_key(t.x, t.y)
	return int(WorldPersistence.get_region_persistence(rk).get("scar_level", 0))


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
	var from_rk: int = preload("res://autoloads/WorldMemory.gd")._region_key(data.tile_pos.x, data.tile_pos.y)
	var to_rk: int = preload("res://autoloads/WorldMemory.gd")._region_key(j.work_tile.x, j.work_tile.y)
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
	if GameManager.game_speed >= FAST_PATHFIND_SPEED_THRESHOLD:
		return _world.pathfinder.find_path(data.tile_pos, to)
	return _world.pathfinder.find_path_pawn_historic_aversion(data.tile_pos, to)


func _ready() -> void:
	GameManager.game_tick.connect(_on_game_tick)
	_sfx = AudioStreamPlayer2D.new()
	_sfx.max_distance = 320.0
	_sfx.volume_db = -5.0
	add_child(_sfx)
	
	# KnowledgeSystem: grant initial knowledge based on profession
	if KnowledgeSystem != null and data != null:
		_grant_initial_knowledge()


## Called by PawnSpawner immediately after instantiation.
func bind(p_data: PawnData, world_pos: Vector2, world: World) -> void:
	data = p_data
	_world = world
	position = world_pos
	_state = State.IDLE
	_clear_path()
	_reserved_bed = Vector2i(-1, -1)
	# New spawns: align fractional age with integer `age` (loads set age_years in PawnData).
	if data != null and data.age_years < 0.0001 and data.age > 0:
		data.age_years = float(data.age)
	_clear_cohort_state()
	add_to_group("pawns")
	refresh_inherited_cultural_reputation()
	_grant_initial_knowledge()
	queue_redraw()


## Re-read the spawn tile’s [CulturalMemory] entry (e.g. after load once ruins are applied). Does not run every tick.
func refresh_inherited_cultural_reputation() -> void:
	if data == null:
		initial_region_reputation = 0
		return
	var rk: int = preload("res://autoloads/WorldMemory.gd")._region_key(data.tile_pos.x, data.tile_pos.y)
	initial_region_reputation = CulturalMemory.get_region_reputation(rk)


## KnowledgeSystem: grant initial knowledge based on profession
func _grant_initial_knowledge() -> void:
	var pawn_id: int = int(data.id)
	
	# Basic knowledge all pawns start with
	KnowledgeSystem.add_knowledge_carrier(pawn_id, KnowledgeSystem.KnowledgeType.FOOD_STORAGE)
	KnowledgeSystem.add_knowledge_carrier(pawn_id, KnowledgeSystem.KnowledgeType.NAVIGATION)
	
	# Profession-specific knowledge
	match int(data.current_profession):
		PawnData.Profession.FARMER:
			KnowledgeSystem.add_knowledge_carrier(pawn_id, KnowledgeSystem.KnowledgeType.SEASON_READING)
			KnowledgeSystem.add_knowledge_carrier(pawn_id, KnowledgeSystem.KnowledgeType.FIRE_KEEPING)
		PawnData.Profession.BUILDER:
			KnowledgeSystem.add_knowledge_carrier(pawn_id, KnowledgeSystem.KnowledgeType.SHELTER_BUILDING)
			KnowledgeSystem.add_knowledge_carrier(pawn_id, KnowledgeSystem.KnowledgeType.TOOL_MAKING)
		PawnData.Profession.GATHERER:
			KnowledgeSystem.add_knowledge_carrier(pawn_id, KnowledgeSystem.KnowledgeType.TOOL_MAKING)
		PawnData.Profession.WARRIOR:
			KnowledgeSystem.add_knowledge_carrier(pawn_id, KnowledgeSystem.KnowledgeType.NAVIGATION)
			KnowledgeSystem.add_knowledge_carrier(pawn_id, KnowledgeSystem.KnowledgeType.SICKNESS_AVOIDANCE)


## Player-ordered direct move. Cancels a claimed work job, drops bed/zone
## holds, and paths to a passable tile (Kenshi / RimWorld "draft" feel).
func draft_goto(world_tile: Vector2i) -> void:
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
		queue_redraw()
		return
	var path: Array[Vector2i] = _path_for_pawn(world_tile)
	if path.is_empty():
		_state = State.IDLE
		queue_redraw()
		return
	_start_path(path)
	queue_redraw()


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


## Contextual player action hook used by deterministic player input queue.
func interact() -> bool:
	if data == null:
		return false
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
	var rk: int = preload("res://autoloads/WorldMemory.gd")._region_key(data.tile_pos.x, data.tile_pos.y)
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
	if GameManager.verbose_logs():
		print("[Pawn] %s grounds themselves at region=%d state=%s (mood=%.1f)" % [data.display_name, rk, settlement_state, data.mood])
	queue_redraw()


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
	var rk: int = preload("res://autoloads/WorldMemory.gd")._region_key(data.tile_pos.x, data.tile_pos.y)
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
	if GameManager.verbose_logs():
		print("[Pawn] %s inspects region=%d meaning=%s tags=%s" % [data.display_name, region_key_for_meaning, meaning_label, str(tags)])
	# Record ephemeral inspect message for immediate HUD feedback
	_last_inspect_msg = "%s — %s" % [meaning_label, (", ".join(tags) if tags.size() > 0 else "no notable tags")]
	_last_inspect_tick = GameManager.tick_count
	queue_redraw()


## Player interaction: teach knowledge to nearby pawn
func teach_knowledge_to_nearby(knowledge_type: int) -> bool:
	if KnowledgeSystem == null:
		return false
	
	var my_id: int = int(data.id)
	
	# Find nearby pawn to teach
	var nearby_distance: float = 50.0
	for pawn in get_tree().get_nodes_in_group("pawns"):
		if pawn == self or not is_instance_valid(pawn):
			continue
		var dist: float = position.distance_to(pawn.position)
		if dist > nearby_distance:
			continue
		
		var their_id: int = int(pawn.data.id)
		KnowledgeSystem.teach_knowledge(my_id, their_id, knowledge_type)
		
		if GameManager.verbose_logs():
			print("[Pawn] Player teaching %s knowledge type %d to %s" % [data.display_name, knowledge_type, pawn.data.display_name])
		
		return true
	
	return false


## Player interaction: challenge nearby pawn's authority
func challenge_authority_nearby(context: int) -> bool:
	if AuthoritySystem == null:
		return false
	
	var my_id: int = int(data.id)
	
	# Find nearby pawn to challenge
	var nearby_distance: float = 50.0
	for pawn in get_tree().get_nodes_in_group("pawns"):
		if pawn == self or not is_instance_valid(pawn):
			continue
		var dist: float = position.distance_to(pawn.position)
		if dist > nearby_distance:
			continue
		
		var their_id: int = int(pawn.data.id)
		AuthoritySystem.resolve_conflict(my_id, their_id, context)
		
		if GameManager.verbose_logs():
			print("[Pawn] Player challenging %s authority in context %d" % [pawn.data.display_name, context])
		
		return true
	
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
			print("[Pawn] Player visiting persistent entity %d at %s" % [entity_id, str(data.tile_pos)])
	
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


## Called from World when a wall appears under this pawn — step off solid tiles.
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
	queue_redraw()


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
	queue_redraw()


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
				if _current_job != null and _current_job.type == Job.Type.TRADE_HAUL and _current_job.trade_to != null:
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
	if not _reported_stuck:
		_reported_stuck = true
		if GameManager.verbose_logs():
			print("[Pawn] WARN: %s on impassable sim tile (%d,%d)  state=%d - forcing nudge" % [
				data.display_name, data.tile_pos.x, data.tile_pos.y, int(_state),
			])
	nudge_if_standing_on_solid()


# ==================== per-frame movement ====================

func _process(delta: float) -> void:
	if data == null or GameManager.is_paused:
		return
	_anim_t += delta * (0.5 + GameManager.game_speed * 0.25)
	if _path.is_empty():
		return
	var step: float = WALK_SPEED_WORLD_UNITS_PER_SEC * delta * GameManager.game_speed
	var to_target: Vector2 = _target_world_pos - position
	if to_target.length() <= step:
		position = _target_world_pos
		var from_step: Vector2i = data.tile_pos
		data.tile_pos = _target_tile
		if from_step != _target_tile:
			RoadMemory.record_step(from_step, _target_tile, _world)
		_advance_path()
	else:
		position += to_target.normalized() * step
	var cohort_bias: Vector2 = _cohort_cohesion_bias(step)
	if cohort_bias != Vector2.ZERO:
		position += cohort_bias
	var persist_bias: Vector2 = _cohort_locus_persistence_bias(step)
	if persist_bias != Vector2.ZERO:
		position += persist_bias


func _start_path(path: Array[Vector2i]) -> void:
	_path = path
	_path_index = 0
	if _path.is_empty():
		_clear_path()
		_on_path_complete()
		return
	_target_tile = _path[0]
	_target_world_pos = _world.tile_to_world(_target_tile)


func _advance_path() -> void:
	_path_index += 1
	if _path_index < _path.size():
		_target_tile = _path[_path_index]
		_target_world_pos = _world.tile_to_world(_target_tile)
	else:
		_clear_path()
		_on_path_complete()


func _clear_path() -> void:
	_path = []
	_path_index = 0
	_target_tile = data.tile_pos if data != null else Vector2i.ZERO
	_target_world_pos = position


func _on_path_complete() -> void:
	match _state:
		State.DRAFT_WALK:
			_state = State.IDLE
			queue_redraw()
		State.WALKING_TO_JOB:
			if _current_job != null and data.tile_pos == _current_job.work_tile:
				_state = State.WORKING
				queue_redraw()
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

func _on_game_tick(_tick: int) -> void:
	if data == null:
		return
	if _hit_flash_ticks > 0:
		_hit_flash_ticks -= 1
	_decay_needs()
	_check_thresholds()
	var stride: int = _fast_forward_tick_stride()
	var run_full_ai: bool = stride <= 1 or (_tick % stride == 0)
	if run_full_ai:
		var active_job_type: int = _active_cohort_job_type()
		if active_job_type != _last_recruitment_job_type:
			_last_recruitment_job_type = active_job_type
			_invalidate_recruitment_signal_cache()
			_refresh_or_decay_cohort_stability(true)
		_refresh_recruitment_signal_cache()
		update_cohort_membership()
		_validate_or_dissolve_cohort()
		_refresh_or_decay_cohort_stability()
		if draft_mode:
			_engage_enemies()
	# Panic-sleep interrupt: if rest is critically low and we're not already
	# resolving a true emergency (asleep, eating, or fed/in-hand), abandon
	# what we're doing and collapse. Beats the eat/haul cycle that otherwise
	# keeps a pawn busy until rest hits 0.
	if _should_panic_sleep():
		_force_panic_sleep()
		return
	if not run_full_ai:
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
		return
	match _state:
		State.IDLE:
			_tick_idle()
		State.WALKING_TO_JOB:
			_tick_walking()
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


func _fast_forward_tick_stride() -> int:
	if GameManager == null:
		return 1
	if GameManager.game_speed >= 4096.0:
		return 64
	if GameManager.game_speed >= 1024.0:
		return 32
	if GameManager.game_speed >= 256.0:
		return 16
	if GameManager.game_speed >= 64.0:
		return 8
	if GameManager.game_speed >= 16.0:
		return 4
	if GameManager.game_speed >= 4.0:
		return 2
	return 1


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
	if GameManager.verbose_logs():
		print("[Pawn] %s collapses from exhaustion  (rest=%.1f hunger=%.1f)" %
			[data.display_name, data.rest, data.hunger])
	_begin_sleeping()


func _tick_idle() -> void:
	if _world == null or _world.pathfinder == null:
		return
	if draft_mode:
		if data.is_carrying():
			if _current_job != null and _current_job.type == Job.Type.TRADE_HAUL and _current_job.trade_to != null:
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
	# 2. If we're still holding something from a prior task, deliver it first.
	if data.is_carrying():
		if _current_job != null and _current_job.type == Job.Type.TRADE_HAUL and _current_job.trade_to != null:
			_begin_haul_to_forced_zone(_current_job.trade_to)
		else:
			_begin_haul_to_stockpile()
		return
	# 3. Need-driven: hungry + food nearby -> go eat
	if _maybe_start_eating():
		return
	# 4. Tired -> sleep. Skipped if we're starving (food first, sleep when full).
	if _maybe_start_sleeping():
		return
	# 5. Teaching: if we have knowledge and a nearby pawn doesn't, teach them
	if _maybe_start_teaching():
		return
	# 6. Challenge: if we have low authority and a nearby pawn has high authority, challenge them
	if _maybe_start_challenge():
		return
	# 7. Job queue: take the best reachable job. We additionally skip build
	# jobs whose required materials aren't on hand at the stockpile -- this
	# prevents pawns from claim/abort looping when wood is empty.
	#
	# Food-emergency override: if the stockpile is almost out of food, do
	# *one* preferential pass restricted to FORAGE jobs, then fall back to the
	# normal filter if no forage is available. Stops the colony from happily
	# mining stone while everyone starves.
	var my_component: int = _world.pathfinder.component_of(data.tile_pos)
	# Treat the whole pantry (berries + meat + any future food) as one number
	# summed across every registered zone. Counting only berries was fine
	# before HUNT existed; now a colony living on hunted meat would have
	# looked like it was starving. And with Phase-10 multi-zone stockpiles
	# we have to sum across zones, not peek at one hardcoded pile.
	var food_emergency: bool = StockpileManager.total_food() < STOCKPILE_FOOD_LOW_THRESHOLD
	var priority_cb: Callable = func(j: Job) -> int:
		var base_bias: int = int(ColonySimServices.job_priority_stance_bias(j)) + _job_history_scar_priority_offset(j)
		var intent_mult: float = get_settlement_intent_job_multiplier(j)
		var intent_bonus: int = int(round((intent_mult - 1.0) * 10.0))
		var front_mult: float = get_preferred_front_bias(j)
		var front_bonus: int = int(round((front_mult - 1.0) * 10.0))
		var cohort_mult: float = get_cohort_recruitment_bias(j)
		var cohort_bonus: int = int(round((cohort_mult - 1.0) * 10.0))
		var resource_mult: float = get_resource_pressure_bias(j)
		var resource_bonus: int = int(round((resource_mult - 1.0) * 10.0))
		return base_bias + intent_bonus + front_bonus + cohort_bonus + resource_bonus
	var base_passes: Callable = func(j: Job) -> bool:
		if Pawn._world_hunt_stabilization_blocks() and j.type == Job.Type.HUNT:
			return false
		if not data.allows_job_type(j.type):
			return false
		if _job_region_scar_blocks_noncritical(j):
			return false
		if _world.pathfinder.component_of(j.work_tile) != my_component:
			return false
		var mats: Dictionary = _materials_for_build(j.type)
		if not mats.is_empty():
			# Any zone with the material is fine -- the pawn will walk to
			# the closest one in _begin_fetching_material.
			if StockpileManager.total_count_of(mats.item) < mats.qty:
				return false
		return true
	if food_emergency:
		# Either harvest type fills the pantry; let pawns pick whichever is
		# nearest by deferring to JobManager's distance tiebreak. `base_passes`
		# already enforces per-pawn work toggles (work_forage / work_hunt).
		var food_only: Callable = func(j: Job) -> bool:
			if Pawn._world_hunt_stabilization_blocks() and j.type == Job.Type.HUNT:
				return false
			if j.type != Job.Type.FORAGE and j.type != Job.Type.HUNT:
				return false
			return base_passes.call(j)
		var food_job: Job = JobManager.claim_next_for(self, food_only, priority_cb)
		if food_job != null:
			_begin_job(food_job)
			return
	var affinity_key: String = data.highest_affinity_skill() if data != null else ""
	var affinity_passes := func(j: Job) -> bool:
		return base_passes.call(j) and _job_matches_affinity(j.type, affinity_key)
	var affinity_job: Job = JobManager.claim_next_for(self, affinity_passes, priority_cb)
	if affinity_job != null:
		_begin_job(affinity_job)
		return
	var job: Job = JobManager.claim_next_for(self, base_passes, priority_cb)
	if job != null:
		_begin_job(job)
		return
	# 6. Nothing to do: idle wander
	if randf() < WANDER_CHANCE_PER_TICK:
		_start_wander()


func _job_matches_affinity(job_type: int, affinity_key: String) -> bool:
	match affinity_key:
		"building":
			return job_type == Job.Type.BUILD_BED or job_type == Job.Type.BUILD_WALL or job_type == Job.Type.BUILD_DOOR
		"farming":
			return job_type == Job.Type.FORAGE or job_type == Job.Type.CHOP  # Chop supports farming
		"combat":
			return job_type == Job.Type.HUNT
		"crafting":
			return job_type == Job.Type.CHOP or job_type == Job.Type.MINE or job_type == Job.Type.MINE_WALL
		"diplomacy":
			return job_type == Job.Type.TRADE_HAUL
		"gathering":
			return job_type == Job.Type.FORAGE or job_type == Job.Type.CHOP or job_type == Job.Type.MINE
		"construction":
			return job_type == Job.Type.BUILD_BED or job_type == Job.Type.BUILD_WALL or job_type == Job.Type.BUILD_DOOR or job_type == Job.Type.MINE_WALL
		_:
			return false


func get_settlement_intent_job_multiplier(job: Job) -> float:
	if data == null or job == null:
		return 1.0
	var intent: String = SettlementMemory.get_settlement_intent_for_tile(data.tile_pos)
	match intent:
		SettlementMemory.INTENT_HOARD:
			if job.type == Job.Type.FORAGE or job.type == Job.Type.HUNT or job.type == Job.Type.TRADE_HAUL:
				return 1.2
			if job.type == Job.Type.CHOP or job.type == Job.Type.MINE or job.type == Job.Type.MINE_WALL:
				return 1.05
		SettlementMemory.INTENT_DEFEND:
			if job.type == Job.Type.HUNT:
				return 1.2
			if job.type == Job.Type.BUILD_WALL or job.type == Job.Type.BUILD_DOOR:
				return 1.1
		SettlementMemory.INTENT_RECOVER:
			if job.type == Job.Type.BUILD_BED or job.type == Job.Type.BUILD_WALL or job.type == Job.Type.BUILD_DOOR:
				return 1.15
			if job.type == Job.Type.TRADE_HAUL:
				return 1.1
		SettlementMemory.INTENT_GROW:
			if job.type == Job.Type.FORAGE or job.type == Job.Type.CHOP:
				return 1.05
	return 1.0


func get_preferred_front_bias(job: Job) -> float:
	if data == null or job == null:
		return 1.0
	return float(SettlementMemory.get_preferred_front_bias_for_job(data.tile_pos, job))


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
		Job.Type.CHOP, Job.Type.BUILD_BED, Job.Type.BUILD_WALL, Job.Type.BUILD_DOOR:
			intensity = wood_p
		Job.Type.MINE_WALL:
			intensity = stone_p
		Job.Type.MINE:
			intensity = ore_p
		Job.Type.FORAGE, Job.Type.HUNT:
			intensity = food_p
		Job.Type.TRADE_HAUL:
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
		# No furniture anywhere — allow "ground" pairing instead of hard-blocking births.
		has_shelter = true
	if not has_shelter:
		return false
	var mate: Pawn = _find_compatible_mate()
	if mate == null or mate.data == null:
		return false
	if data.get_social_rapport(int(mate.data.id)) < REPRODUCTION_MIN_RAPPORT:
		return false
	if int(data.id) > int(mate.data.id):
		return false
	var main_node: Node = get_tree().get_root().get_node_or_null("Main")
	if main_node == null:
		return false
	var spawner: PawnSpawner = main_node.get_node_or_null("WorldViewport/PawnSpawner") as PawnSpawner
	if spawner == null:
		return false
	var did_spawn: bool = spawner.spawn_child_pawn(_world, data.tile_pos, data, mate.data, now)
	if did_spawn:
		_next_reproduction_tick = now + REPRODUCTION_COOLDOWN_TICKS
		mate._next_reproduction_tick = now + REPRODUCTION_COOLDOWN_TICKS
	return did_spawn


func _reproduction_mate_range_px() -> float:
	if _world == null:
		return REPRODUCTION_MATE_RANGE_PX
	var r: float = REPRODUCTION_MATE_RANGE_PX
	if _world.bed_count() <= 0:
		r = maxf(r, float(World.TILE_PIXELS) * REPRODUCTION_MATE_RANGE_NO_BEDS_MIN_TILES)
	return r


func _find_compatible_mate() -> Pawn:
	var mate_r: float = _reproduction_mate_range_px()
	var mate_r2: float = mate_r * mate_r
	var best: Pawn = null
	var best_d2: float = INF
	for n in get_tree().get_nodes_in_group("pawns"):
		if n == null or not (n is Pawn):
			continue
		var p: Pawn = n as Pawn
		if p == self or p.data == null:
			continue
		if p.data.hunger <= REPRODUCTION_MIN_HUNGER or p.data.rest <= REPRODUCTION_MIN_REST:
			continue
		if p._next_reproduction_tick > GameManager.tick_count:
			continue
		var compatible: bool = (
			data.gender == PawnData.Gender.OTHER
			or p.data.gender == PawnData.Gender.OTHER
			or data.gender != p.data.gender
		)
		if not compatible:
			continue
		var d2: float = position.distance_squared_to(p.position)
		if d2 <= mate_r2 and d2 < best_d2:
			best = p
			best_d2 = d2
	return best


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
	# Dynamic neural network matrix connection for settlement effects
	_nearby_pawn_edict_influence(edict_key)
	return true


func _nearby_pawn_edict_influence(edict_key: String) -> void:
	# Dynamic neural network matrix connection for settlement edict influence
	var influence_radius: float = 90.0
	var affected_pawns: Array[Pawn] = []
	
	for n in get_tree().get_nodes_in_group("pawns"):
		if not (n is Pawn):
			continue
		var p: Pawn = n as Pawn
		if p == self or p.data == null:
			continue
		if p.position.distance_squared_to(position) > influence_radius * influence_radius:
			continue
		affected_pawns.append(p)
	
	# Apply neural network matrix influence based on edict type
	for p in affected_pawns:
		var influence_strength: float = 1.0 - (p.position.distance_to(position) / influence_radius)
		var neural_signature: String = "NM_EDICT_%08X" % [int(data.id) * 1000 + int(p.data.id) + GameManager.tick_count]
		
		match edict_key:
			"focus_farming":
				p.data.skills["farming"] = int(p.data.skills.get("farming", 0)) + int(influence_strength * 2)
				p.data.add_liking_from_action_skill("farming", influence_strength)
			"draft_soldiers":
				p.data.skills["combat"] = int(p.data.skills.get("combat", 0)) + int(influence_strength * 2)
				p.data.add_liking_from_action_skill("combat", influence_strength)
			"promote_crafting":
				p.data.skills["crafting"] = int(p.data.skills.get("crafting", 0)) + int(influence_strength * 2)
				p.data.add_liking_from_action_skill("crafting", influence_strength)
			"encourage_trade":
				p.data.skills["diplomacy"] = int(p.data.skills.get("diplomacy", 0)) + int(influence_strength * 2)
				p.data.add_liking_from_action_skill("diplomacy", influence_strength)
		
		# Record neural network matrix influence
		if WorldMemory != null:
			WorldMemory.record_event({
				"type": "edict_influence",
				"ruler_id": int(data.id),
				"affected_pawn_id": int(p.data.id),
				"edict": edict_key,
				"influence_strength": influence_strength,
				"neural_signature": neural_signature,
				"tick": GameManager.tick_count
			})


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


func pledge_loyalty(target_ruler: Pawn) -> bool:
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
	if _current_job == null:
		_state = State.IDLE
		return
	if _current_job.type == Job.Type.HUNT and Pawn._world_hunt_stabilization_blocks():
		_unclaim_current_job()
		return
	# Starving: let go of non-harvest work so the next tick can path to food.
	if data.hunger <= HUNGER_EMERGENCY and _current_job != null:
		if _current_job.type != Job.Type.FORAGE and _current_job.type != Job.Type.HUNT:
			_unclaim_current_job()
			return
	if not _is_job_tile_still_valid(_current_job):
		_cancel_current_job()
		return
	
	# Stage 1: Calculate work efficiency based on proficiency, stamina, pain, injuries
	var efficiency: float = _calculate_work_efficiency()
	
	# Skill-modulated work rate: progress per tick = work_speed_for(skill).
	# Always at least 1 progress per tick (a fresh pawn isn't slower than the
	# old constant-rate baseline). XP accrues only while actually working.
	var skill: int = PawnData.skill_for_job(_current_job.type)
	var speed: float = data.effective_labor_mult()
	if skill >= 0:
		speed *= data.work_speed_for(skill)
		# Apply efficiency modifier
		speed *= efficiency
		var leveled_up: bool = data.add_skill_xp(skill, PawnData.XP_PER_WORK_TICK)
		if leveled_up:
			if GameManager.verbose_logs():
				print("[Pawn] %s's %s went up to %d" % [
					data.display_name,
					PawnData.skill_name(skill),
					data.get_skill_level(skill),
				])
		var w: int = maxi(1, int(ceil(speed)))
		data.add_profession_liking_for_job(_current_job.type, w)
		_current_job.work_ticks_done += int(ceil(speed))
	if _current_job.work_ticks_done >= _current_job.work_ticks_needed:
		if _current_job.type == Job.Type.TRADE_HAUL:
			_complete_trade_pickup()
		else:
			_complete_current_job()
	# Mining and wall-mining are hazardous. Small chance of injury each tick.
	_apply_work_hazards()


func _calculate_work_efficiency() -> float:
	var efficiency: float = 1.0
	
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
	
	# Injury penalty (severe injuries reduce efficiency)
	var total_injury_severity: float = 0.0
	for injury_type in data.injuries:
		total_injury_severity += data.injuries[injury_type]
	if total_injury_severity > 50.0:
		efficiency *= 0.5
	elif total_injury_severity > 30.0:
		efficiency *= 0.75
	
	# Tool requirement check (placeholder - needs Item system integration)
	# TODO: Check if pawn has required tool equipped or nearby
	# if _current_job.required_tool != 0 and not _has_required_tool():
	# 	efficiency *= 0.25  # Severe penalty for missing tool
	
	return clamp(efficiency, 0.1, 2.0)


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


func _apply_work_hazards() -> void:
	if _current_job == null:
		return
	if _current_job.type == Job.Type.TRADE_HAUL:
		return
	# Mining and wall-mining expose pawns to injury risk.
	# Chance = 2% base, reduced by skill level (miners get safer as they level).
	# Unskilled pawn (lvl 0): 2% per tick. Skilled (lvl 20): 0.2% per tick.
	var hazard_chance: float = 0.0
	if _current_job.type == Job.Type.MINE or _current_job.type == Job.Type.MINE_WALL:
		var mining_level: int = data.get_skill_level(PawnData.Skill.MINING)
		hazard_chance = 0.02 * max(0.1, 1.0 - (mining_level / 20.0))
		# Traits can modify injury chance
		hazard_chance *= data.get_trait_mult("injury_chance_mult")
	if hazard_chance > 0.0 and randf() < hazard_chance:
		var damage: float = randf_range(3.0, 8.0)
		# Traits can reduce damage taken
		damage *= data.get_trait_mult("damage_taken_mult")
		data.health = max(0.0, data.health - damage)
		_play_sfx("res://assets/audio/pawn_hurt.ogg", 0.9)
		# Trigger stress mood event from injury
		data.add_mood_event(MoodEvent.Type.STRESS, 60.0, 300)
		if GameManager.verbose_logs():
			print("[Pawn] %s injured while working  (damage=%.1f health=%.1f)" %
				[data.display_name, damage, data.health])


# ==================== jobs (FORAGE / MINE) ====================

func _begin_job(job: Job) -> void:
	_current_job = job
	_invalidate_recruitment_signal_cache()
	_refresh_recruitment_signal_cache(true)
	update_cohort_membership(true)
	_refresh_or_decay_cohort_stability(true)
	# Build jobs need raw materials in hand before we walk to the build site.
	# If we don't already have the right item in sufficient quantity, bounce
	# to the stockpile first.
	var mats: Dictionary = _materials_for_build(job.type)
	if not mats.is_empty():
		var item_type: int = mats.item
		var need_qty: int = mats.qty
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
		queue_redraw()
		return
	var path: Array[Vector2i] = _path_for_pawn(job.work_tile)
	if path.is_empty():
		_unclaim_current_job()
		return
	_state = State.WALKING_TO_JOB
	_start_path(path)
	queue_redraw()


func _return_trade_cargo_to_source_if_any(j: Job) -> void:
	if j == null or j.type != Job.Type.TRADE_HAUL:
		return
	if not data.is_carrying() or j.trade_from == null or not is_instance_valid(j.trade_from):
		return
	if j.trade_item == data.carrying:
		j.trade_from.add_item(data.carrying, data.carrying_qty)
		data.clear_carry()


func _complete_trade_pickup() -> void:
	var job: Job = _current_job
	if job == null or job.type != Job.Type.TRADE_HAUL:
		_unclaim_current_job()
		return
	var from_sp: Stockpile = job.trade_from
	var to_sp: Stockpile = job.trade_to
	if from_sp == null or not is_instance_valid(from_sp) or to_sp == null or not is_instance_valid(to_sp):
		_unclaim_current_job()
		return
	var want: int = mini(job.trade_batch, from_sp.count_of(job.trade_item))
	if want <= 0:
		_unclaim_current_job()
		return
	var taken: int = from_sp.take_item(job.trade_item, want)
	if taken <= 0:
		_unclaim_current_job()
		return
	if not to_sp.accepts(job.trade_item):
		from_sp.add_item(job.trade_item, taken)
		_unclaim_current_job()
		return
	data.carrying = job.trade_item
	data.carrying_qty = taken
	_begin_haul_to_forced_zone(to_sp)
	queue_redraw()


func _begin_haul_to_forced_zone(sp: Stockpile) -> void:
	if not data.is_carrying() or sp == null or not is_instance_valid(sp) or not sp.accepts(data.carrying):
		_unclaim_current_job()
		return
	_target_zone = sp
	var target_tile: Vector2i = sp.nearest_tile_to(data.tile_pos)
	if data.tile_pos == target_tile:
		_deposit_at_stockpile()
		return
	var path2: Array[Vector2i] = _path_for_pawn(target_tile)
	if path2.is_empty():
		_log_haul_fail("no path")
		_return_trade_cargo_to_source_if_any(_current_job)
		_unclaim_current_job()
		return
	_state = State.HAULING
	_start_path(path2)
	queue_redraw()


# ==================== material fetch (build jobs) ====================

## Walk to the nearest stockpile zone that has the requested materials and
## pick up `qty` of `item_type` for the active job. Aborts the job (with a
## one-line log) if no reachable zone has enough.
func _begin_fetching_material(item_type: int, qty: int) -> void:
	var sp: Stockpile = StockpileManager.find_source_for(
		item_type, qty, data.tile_pos, _world.pathfinder
	)
	if sp == null:
		if GameManager.verbose_logs():
			print("[Pawn] %s aborts build job: no reachable zone has %d %s" %
				[data.display_name, qty, Item.name_for(item_type)])
		_unclaim_current_job()
		return
	_target_zone = sp
	var target_tile: Vector2i = sp.nearest_tile_to(data.tile_pos)
	if data.tile_pos == target_tile:
		_pickup_material(item_type, qty)
		return
	var path: Array[Vector2i] = _path_for_pawn(target_tile)
	if path.is_empty():
		_unclaim_current_job()
		return
	_state = State.FETCHING_MATERIAL
	_start_path(path)
	queue_redraw()


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
		_unclaim_current_job()
		return
	var taken: int = sp.take_item(item_type, qty)
	if taken < qty:
		# Partial take: put it back so we don't strand items in our hand.
		if taken > 0:
			sp.add_item(item_type, taken)
		if GameManager.verbose_logs():
			print("[Pawn] %s aborts build job: zone ran out of %s mid-fetch" %
				[data.display_name, Item.name_for(item_type)])
		_target_zone = null
		_unclaim_current_job()
		return
	# Stack onto existing carry of the same type, otherwise replace.
	if data.carrying == item_type:
		data.carrying_qty += taken
	else:
		data.carrying = item_type
		data.carrying_qty = taken
	_target_zone = null
	queue_redraw()
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
		Job.Type.FORAGE:
			return _world.data.get_feature(job.tile.x, job.tile.y) == TileFeature.Type.FERTILE_SOIL
		Job.Type.MINE:
			return _world.data.get_feature(job.tile.x, job.tile.y) == TileFeature.Type.ORE_VEIN
		Job.Type.MINE_WALL:
			return _world.data.get_biome(job.tile.x, job.tile.y) == Biome.Type.MOUNTAIN
		Job.Type.CHOP:
			return _world.data.get_feature(job.tile.x, job.tile.y) == TileFeature.Type.TREE
		Job.Type.HUNT:
			# Animals are tile features; the hunt's still valid as long as the
			# critter hasn't already been killed (cleared) by someone else.
			return TileFeature.is_wildlife(_world.data.get_feature(job.tile.x, job.tile.y))
		Job.Type.TRADE_HAUL:
			var tf: Stockpile = job.trade_from
			var tt: Stockpile = job.trade_to
			if tf == null or not is_instance_valid(tf) or tt == null or not is_instance_valid(tt):
				return false
			if not _world.pathfinder.is_passable(job.work_tile):
				return false
			if not tt.accepts(job.trade_item):
				return false
			return tf.count_of(job.trade_item) > 0
		Job.Type.BUILD_BED, Job.Type.BUILD_WALL:
			# Build sites are still valid if the tile is empty (no feature) and
			# the underlying biome is passable. We DON'T check pathfinder
			# passability for walls -- the wall tile itself is always passable
			# until the moment the wall snaps in (work_tile is adjacent).
			var f1: int = _world.data.get_feature(job.tile.x, job.tile.y)
			if f1 != TileFeature.Type.NONE:
				return false
			return Biome.is_passable(_world.data.get_biome(job.tile.x, job.tile.y))
		Job.Type.BUILD_DOOR:
			# Fresh door: empty tile. Replace-door: still a WALL (worker stands
			# on a neighbor; job completes into build_door swap).
			var f2: int = _world.data.get_feature(job.tile.x, job.tile.y)
			if f2 == TileFeature.Type.WALL or f2 == TileFeature.Type.NONE:
				return Biome.is_passable(_world.data.get_biome(job.tile.x, job.tile.y))
			return false
	return false


## Work finished successfully. Produce the item into the pawn's hands and
## transition to HAULING (walk it to the stockpile).
func _complete_current_job() -> void:
	var job: Job = _current_job
	if job != null and job.type == Job.Type.TRADE_HAUL:
		return
	if job != null and job.type == Job.Type.HUNT and Pawn._world_hunt_stabilization_blocks():
		_unclaim_current_job()
		return
	
	# Stage 1: Increase job proficiency for completed job
	var job_type_str: String = Job.describe_type(job.type).to_lower()
	var current_proficiency: float = data.job_proficiency.get(job_type_str, 0.0)
	data.job_proficiency[job_type_str] = min(100.0, current_proficiency + 2.0)  # +2 proficiency per job
	
	var produced_type: int = Item.Type.NONE
	# Most harvests yield 1; only HUNT (deer) yields more, but plumbing it as a
	# variable keeps room for future high-yield jobs without re-plumbing again.
	var produced_qty: int = 1
	match job.type:
		Job.Type.FORAGE:
			produced_type = Item.Type.BERRY
			_world.clear_feature(job.tile.x, job.tile.y)
			if GameManager.verbose_logs():
				print("[Pawn] %s foraged berries @(%d,%d)" % [data.display_name, job.tile.x, job.tile.y])
		Job.Type.MINE:
			produced_type = Item.Type.STONE
			_world.clear_feature(job.tile.x, job.tile.y)
			if GameManager.verbose_logs():
				print("[Pawn] %s mined stone @(%d,%d)" % [data.display_name, job.tile.x, job.tile.y])
		Job.Type.MINE_WALL:
			produced_type = Item.Type.STONE
			# This converts MOUNTAIN -> STONE_FLOOR and rebuilds the components
			# map, which can cascade-unlock sealed ore veins.
			_world.mine_out_wall(job.tile.x, job.tile.y)
			if GameManager.verbose_logs():
				print("[Pawn] %s mined wall @(%d,%d) -> stone floor" % [data.display_name, job.tile.x, job.tile.y])
		Job.Type.CHOP:
			produced_type = Item.Type.WOOD
			_world.clear_feature(job.tile.x, job.tile.y)
			if GameManager.verbose_logs():
				print("[Pawn] %s chopped tree @(%d,%d)" % [data.display_name, job.tile.x, job.tile.y])
		Job.Type.HUNT:
			produced_type = Item.Type.MEAT
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
			_world.clear_feature(job.tile.x, job.tile.y)
			if GameManager.verbose_logs():
				print("[Pawn] %s hunted %s @(%d,%d) -> %d meat" % [
					data.display_name, TileFeature.name_for(animal_feat),
					job.tile.x, job.tile.y, produced_qty])
		Job.Type.BUILD_BED, Job.Type.BUILD_WALL, Job.Type.BUILD_DOOR:
			_finish_build(job)
	# Trigger mood event based on job type
	match job.type:
		Job.Type.HUNT:
			data.add_mood_event(MoodEvent.Type.TRIUMPH, 80.0, 250)  # Hunting is thrilling
		Job.Type.MINE, Job.Type.MINE_WALL:
			data.add_mood_event(MoodEvent.Type.CONTENTMENT, 50.0, 200)  # Solid work
		Job.Type.CHOP, Job.Type.FORAGE:
			data.add_mood_event(MoodEvent.Type.CONTENTMENT, 40.0, 180)  # Basic harvesting
		Job.Type.BUILD_BED, Job.Type.BUILD_WALL, Job.Type.BUILD_DOOR:
			data.add_mood_event(MoodEvent.Type.JOY, 60.0, 220)  # Building feels productive
	JobManager.complete(job)
	_clear_cohort_state()
	_current_job = null
	_state = State.IDLE   # reset before transitioning; _begin_haul will set it
	_clear_path()
	queue_redraw()
	# Harvest jobs put a fresh item in the pawn's hands -- haul it to the stockpile.
	# Build jobs don't produce anything haulable.
	if produced_type != Item.Type.NONE:
		data.carrying = produced_type
		data.carrying_qty = produced_qty
		_begin_haul_to_stockpile()


## Place the right TileFeature for a build job, consuming the carried materials.
## Bails out cleanly if we somehow arrived without the wood in hand.
func _finish_build(job: Job) -> void:
	var mats: Dictionary = _materials_for_build(job.type)
	if mats.is_empty():
		return
	var item_type: int = mats.item
	var need_qty: int = mats.qty
	if data.carrying != item_type or data.carrying_qty < need_qty:
		if GameManager.verbose_logs():
			print("[Pawn] %s missing material at completion -- %s not built @(%d,%d)" %
				[data.display_name, Job.describe_type(job.type), job.tile.x, job.tile.y])
		return
	data.carrying_qty -= need_qty
	if data.carrying_qty <= 0:
		data.clear_carry()
	match job.type:
		Job.Type.BUILD_BED:
			_world.set_feature(job.tile.x, job.tile.y, TileFeature.Type.BED)
			_world.register_bed(job.tile)
			if GameManager.verbose_logs():
				print("[Pawn] %s built a bed @(%d,%d)" % [data.display_name, job.tile.x, job.tile.y])
		Job.Type.BUILD_WALL:
			_world.build_wall(job.tile.x, job.tile.y)
			if GameManager.verbose_logs():
				print("[Pawn] %s built a wall @(%d,%d)" % [data.display_name, job.tile.x, job.tile.y])
		Job.Type.BUILD_DOOR:
			_world.build_door(job.tile.x, job.tile.y)
			if GameManager.verbose_logs():
				print("[Pawn] %s placed a door @(%d,%d)" % [data.display_name, job.tile.x, job.tile.y])


func _cancel_current_job() -> void:
	if _current_job != null:
		_return_trade_cargo_to_source_if_any(_current_job)
		JobManager.cancel(_current_job)
	_reset_to_idle()


func _unclaim_current_job() -> void:
	if _current_job != null:
		var j0: Job = _current_job
		_return_trade_cargo_to_source_if_any(j0)
		JobManager.abandon(j0)
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
	queue_redraw()


func release_job_if_any() -> void:
	if _current_job != null:
		var j1: Job = _current_job
		_return_trade_cargo_to_source_if_any(j1)
		JobManager.cancel(j1)
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
	var target_tile: Vector2i = sp.nearest_tile_to(data.tile_pos)
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
	queue_redraw()
	if GameManager.verbose_logs():
		print("[Pawn] %s hauling %s -> zone %s (%d,%d), path_len=%d, from (%d,%d)" % [
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
	var my_comp: int = -1
	if _world != null and _world.pathfinder != null:
		my_comp = _world.pathfinder.component_of(data.tile_pos)
	var zone_count: int = StockpileManager.zones().size()
	if GameManager.verbose_logs():
		print("[Pawn] %s haul FAIL (%s): at (%d,%d) comp=%d  carrying=%s x%d  zones=%d" % [
			data.display_name, reason,
			data.tile_pos.x, data.tile_pos.y, my_comp,
			Item.name_for(data.carrying), data.carrying_qty, zone_count
		])


func _deposit_at_stockpile() -> void:
	var j_done: Job = _current_job
	var is_trade: bool = j_done != null and j_done.type == Job.Type.TRADE_HAUL
	var sp: Stockpile
	if is_trade:
		if j_done.trade_to == null or not is_instance_valid(j_done.trade_to):
			_return_trade_cargo_to_source_if_any(j_done)
			JobManager.cancel(j_done)
			_current_job = null
			_target_zone = null
			_reset_to_idle()
			return
		sp = j_done.trade_to
		if not sp.accepts(data.carrying):
			_return_trade_cargo_to_source_if_any(j_done)
			JobManager.cancel(j_done)
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
		sp.add_item(data.carrying, data.carrying_qty)
		if is_trade:
			data.add_profession_liking_for_trade_completion()
		if not is_trade:
			if GameManager.verbose_logs():
				print("[Pawn] %s deposited %d %s into %s zone (zone now has %d)" % [
					data.display_name, data.carrying_qty,
					Item.name_for(data.carrying),
					Stockpile.FILTER_NAME.get(sp.filter, "?"),
					sp.count_of(data.carrying)
				])
	data.clear_carry()
	_target_zone = null
	if is_trade and j_done != null and j_done.type == Job.Type.TRADE_HAUL:
		JobManager.complete(j_done)
	_current_job = null
	_state = State.IDLE
	_clear_path()
	queue_redraw()


# ==================== eating ====================

func _maybe_start_eating() -> bool:
	if data.hunger >= HUNGER_EAT_THRESHOLD:
		return false
	if data.is_carrying():
		# Carrying something -- finish that errand first.
		return false
	var sp: Stockpile = StockpileManager.find_food_source(data.tile_pos, _world.pathfinder)
	if sp == null:
		return false
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
	queue_redraw()


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
	queue_redraw()


func _finish_eating() -> void:
	var sp: Stockpile = _target_zone
	var food_type: int = Item.Type.NONE
	var gain: float = 0.0
	if sp == null or not is_instance_valid(sp):
		sp = StockpileManager.find_food_source(data.tile_pos, _world.pathfinder)
	if sp != null:
		food_type = sp.pick_food()
		if food_type != Item.Type.NONE:
			var taken: int = sp.take_item(food_type, 1)
			if taken > 0:
				gain = Item.hunger_restore(food_type)
				data.hunger = min(100.0, data.hunger + gain)
				data.mood = min(100.0, data.mood + MOOD_BONUS_ATE)
				_play_sfx("res://assets/audio/pawn_eat.ogg", 1.0)
				# Eating meat brings more joy than berries
				if food_type == Item.Type.MEAT:
					data.add_mood_event(MoodEvent.Type.JOY, 70.0, 200)
				else:
					data.add_mood_event(MoodEvent.Type.JOY, 40.0, 150)
				# After eating, reset warning band so we don't re-log instantly.
				_hunger_level = _level_for(data.hunger)
	if GameManager.verbose_logs() and food_type != Item.Type.NONE and gain > 0.0:
		print("[Pawn] %s ate 1 %s  (+%.0f hunger -> %.1f, mood %.1f)" % [
			data.display_name, Item.name_for(food_type), gain, data.hunger, data.mood
		])
	_target_zone = null
	_reset_to_idle()


# ==================== sleep ====================

## Returns true and starts sleeping if the pawn is tired enough. Called from
## _tick_idle, so this only fires when nothing more urgent is happening.
##
## Bed preference: try to reserve and walk to the nearest free bed. If no bed
## is reachable, lie down on the spot (slower recovery, but better than dying).
func _maybe_start_sleeping() -> bool:
	# At night the threshold is raised so well-rested pawns still go to bed
	# when the sun goes down, giving the colony a real day/night rhythm.
	var threshold: float = REST_SLEEP_THRESHOLD_NIGHT if DayNightCycle.is_night_for_tick(GameManager.tick_count) else REST_SLEEP_THRESHOLD
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
	if _try_walk_to_bed():
		return true
	_begin_sleeping()
	return true


## Check if pawn can teach knowledge to nearby pawn
func _maybe_start_teaching() -> bool:
	if KnowledgeSystem == null:
		return false
	
	var my_id: int = int(data.id)
	var my_knowledge = KnowledgeSystem.get_pawn_knowledge(my_id)
	
	if my_knowledge.is_empty():
		return false  # Nothing to teach
	
	# Find nearby pawn who lacks knowledge we have
	var nearby_distance: float = 50.0
	for pawn in get_tree().get_nodes_in_group("pawns"):
		if pawn == self or not is_instance_valid(pawn):
			continue
		var dist: float = position.distance_to(pawn.position)
		if dist > nearby_distance:
			continue
		
		var their_id: int = int(pawn.data.id)
		var their_knowledge = KnowledgeSystem.get_pawn_knowledge(their_id)
		
		# Find a knowledge type we have but they don't
		for ktype in my_knowledge:
			if not their_knowledge.has(ktype):
				# Start teaching this knowledge
				_teaching_target = pawn
				_teaching_knowledge_type = ktype
				_teaching_ticks_left = 10  # Teaching takes 10 ticks
				_state = State.TEACHING
				if GameManager.verbose_logs():
					print("[Pawn] %s teaching %s knowledge type %d" % [data.display_name, pawn.data.display_name, ktype])
				return true
	
	return false


## Check if pawn can challenge nearby pawn's authority
func _maybe_start_challenge() -> bool:
	if AuthoritySystem == null:
		return false
	
	var my_id: int = int(data.id)
	
	# Find nearby pawn with higher authority in some context
	var nearby_distance: float = 50.0
	for pawn in get_tree().get_nodes_in_group("pawns"):
		if pawn == self or not is_instance_valid(pawn):
			continue
		var dist: float = position.distance_to(pawn.position)
		if dist > nearby_distance:
			continue
		
		var their_id: int = int(pawn.data.id)
		
		# Check each authority context
		for context in [AuthoritySystem.AuthorityContext.CIVIL, AuthoritySystem.AuthorityContext.MILITARY, AuthoritySystem.AuthorityContext.RELIGIOUS, AuthoritySystem.AuthorityContext.KNOWLEDGE]:
			var my_auth: float = AuthoritySystem.get_authority_level(my_id, context)
			var their_auth: float = AuthoritySystem.get_authority_level(their_id, context)
			
			# Challenge if they have significantly more authority (0.2 difference)
			# and we're not already in conflict with them
			if their_auth > my_auth + 0.2:
				var is_in_conflict: bool = AuthoritySystem.get_conflict_state(my_id, their_id) != AuthoritySystem.ConflictState.NONE
				if not is_in_conflict:
					# Start challenge
					_challenge_target = pawn
					_challenge_context = context
					_challenge_ticks_left = 8  # Challenge takes 8 ticks
					_state = State.CHALLENGE
					if GameManager.verbose_logs():
						print("[Pawn] %s challenging %s authority in context %d" % [data.display_name, pawn.data.display_name, context])
					return true
	
	return false


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
	queue_redraw()
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
	queue_redraw()
	var on_bed: bool = _reserved_bed.x >= 0 and data.tile_pos == _reserved_bed
	var where: String = " in a bed" if on_bed else ""
	if GameManager.verbose_logs():
		print("[Pawn] %s lies down to sleep%s  (rest=%.1f)" % [data.display_name, where, data.rest])


## Per-tick while in SLEEPING. The actual rest restoration / hunger decay
## happens in _decay_needs (which checks the state). Here we only handle
## the wake conditions.
func _tick_sleeping() -> void:
	# Wake up early if we get critically hungry -- food trumps sleep.
	if data.hunger <= HUNGER_EMERGENCY:
		if GameManager.verbose_logs():
			print("[Pawn] %s wakes hungry  (hunger=%.1f rest=%.1f)" %
				[data.display_name, data.hunger, data.rest])
		_release_bed_if_reserved()
		_reset_to_idle()
		return


# ==================== combat ====================

func _engage_enemies() -> void:
	if _world == null or _world.pathfinder == null:
		return
	if _state != State.IDLE and _state != State.DRAFT_WALK:
		return
	var closest_enemy: Enemy = null
	var closest_dist_sq: float = INF
	for enemy_node in get_tree().get_nodes_in_group("enemies"):
		var enemy: Enemy = enemy_node as Enemy
		if enemy == null or not is_instance_valid(enemy):
			continue
		var dist_sq: float = position.distance_squared_to(enemy.position)
		if dist_sq < closest_dist_sq:
			closest_enemy = enemy
			closest_dist_sq = dist_sq
	if closest_enemy == null:
		return
	if closest_dist_sq <= 110.0:
		if randf() < 0.45:
			CombatResolver.resolve_attack(self, closest_enemy)
		return
	if _state == State.IDLE:
		var target_tile: Vector2i = _world.world_to_tile(closest_enemy.position)
		if not _world.pathfinder.is_passable(target_tile):
			target_tile = _world.pathfinder.find_adjacent_passable(target_tile)
		if target_tile.x < 0:
			return
		var path: Array[Vector2i] = _path_for_pawn(target_tile)
		if path.is_empty():
			return
		_state = State.DRAFT_WALK
		_start_path(path)
	# Normal wake on rest restored.
	if data.rest >= REST_WAKE_THRESHOLD:
		data.mood = min(100.0, data.mood + MOOD_BONUS_WOKE_REFRESHED)
		if GameManager.verbose_logs():
			print("[Pawn] %s wakes refreshed  (rest=%.1f, mood %.1f)" %
				[data.display_name, data.rest, data.mood])
		_release_bed_if_reserved()
		_reset_to_idle()
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
	if GameManager.verbose_logs():
		print("[Pawn] %s ate 1 %s FROM HAND (emergency, +%.0f hunger -> %.1f, mood %.1f)" % [
			data.display_name, Item.name_for(food_type), gain, data.hunger, data.mood
		])
	queue_redraw()


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
	
	if _state == State.SLEEPING:
		data.hunger = max(0.0, data.hunger - HUNGER_DECAY_PER_TICK_SLEEPING * hunger_mult)
		var rate: float = REST_RECOVER_PER_TICK_SLEEP
		if _reserved_bed.x >= 0 and data.tile_pos == _reserved_bed and \
				_world != null and _world.is_bed_owned_by(_reserved_bed, self):
			rate *= REST_RECOVER_BED_MULTIPLIER
		data.rest = min(100.0, data.rest + rate)
	else:
		data.hunger = max(0.0, data.hunger - HUNGER_DECAY_PER_TICK * hunger_mult)
		data.rest   = max(0.0, data.rest   - REST_DECAY_PER_TICK * rest_mult)
	
	# Mood: net loss when needs aren't met, net gain when they are.
	# Passive contentment outpaces decay, so a pawn whose hunger AND rest are
	# both comfortable will recover happiness on their own.
	# Mood events also contribute their own delta.
	data.process_mood_events()
	var mood_event_impact: float = data.get_mood_event_impact()
	
	if data.hunger >= MOOD_CONTENT_FLOOR and data.rest >= MOOD_CONTENT_FLOOR:
		data.mood = min(100.0, data.mood + MOOD_GAIN_PER_TICK_CONTENT - MOOD_DECAY_PER_TICK * mood_mult + mood_event_impact)
	else:
		data.mood = max(0.0, data.mood - MOOD_DECAY_PER_TICK * mood_mult + mood_event_impact)
	
	# Historically used land: subtle mood drain from nearby past deaths / builds.
	if get_tree().get_root().has_node("Main/WorldTrace"):
		var wt: WorldTrace = get_tree().get_root().get_node("Main/WorldTrace") as WorldTrace
		data.mood = max(0.0, data.mood - wt.get_mood_drain_at(data.tile_pos))
	
	# Stage 1: Decay stamina based on activity
	_decay_stamina()
	
	# Stage 1: Check temperature exposure
	_check_temperature()
	
	# Stage 1: Process injuries and pain
	_process_injuries()
	
	# Stage 1: Observe nearby work (learning by observation)
	_observe_nearby_work()
	
	# Stage 1: Update perception and location memory
	_update_perception()
	
	# Stage 2: Track co-presence with nearby pawns
	track_co_presence()
	
	# Stage 3: Track clan labor contributions
	if _state == State.WORKING and _current_job != null:
		var job_type_str: String = Job.describe_type(_current_job.type).to_lower()
		contribute_to_clan_labor(job_type_str)
		
		# Stage 4: Track settlement contributions
		if data.settlement_id != -1:
			if _current_job.type == Job.Type.FORAGE or _current_job.type == Job.Type.HUNT:
				record_food_production(1)
			elif _current_job.type == Job.Type.BUILD_BED or _current_job.type == Job.Type.BUILD_WALL or _current_job.type == Job.Type.BUILD_DOOR:
				record_building_construction()
	
	# Crisis behavior: very low mood causes pawns to refuse work (strike)
	var crisis_level: float = data.get_crisis_level()
	if crisis_level > 0.8 and randf() < 0.05:  # 5% chance per tick to strike when desperate
		_trigger_crisis_strike()
	
	# One in-world year every SimTime.TICKS_PER_SIM_YEAR ticks (see docs/TIME_SCALE.md).
	data.age_years += 1.0 / float(SimTime.TICKS_PER_SIM_YEAR)
	if data.age_years > 70.0 and randf() < 0.00001:
		_die("old_age")
		return
	# Death from starvation, exhaustion, or injury
	_check_death_conditions()


## Crisis strike: pawn refuses to work when mood is critical.
func _trigger_crisis_strike() -> void:
	# Release current job and enter idle state
	if _current_job != null:
		_unclaim_current_job()
	_state = State.IDLE
	# Add DESPAIR mood event
	if not data.has_trait(Trait.Type.PESSIMIST):  # Pessimists expect this already
		data.add_mood_event(MoodEvent.Type.DESPAIR, 75.0, 400)
	if GameManager.verbose_logs():
		print("[Pawn] %s is on strike due to critical morale (mood=%.1f)" %
			[data.display_name, data.mood])


func _check_death_conditions() -> void:
	# Emergency food-seeking for AI agents
	if data.hunger < 15.0 and _state != State.GOING_TO_EAT and _state != State.EATING:
		if GameManager.verbose_logs():
			print("[Pawn] %s seeking emergency food (hunger=%.1f)" % [data.display_name, data.hunger])
		_emergency_seek_food()
	
	# More lenient death conditions
	if data.hunger <= -5.0:  # Allow some buffer before death
		if GameManager.verbose_logs():
			print("[Pawn] %s died of starvation  (hunger=%.1f)" % [data.display_name, data.hunger])
		_die("")
		return
	if data.rest <= -5.0:  # Allow some buffer before death
		if GameManager.verbose_logs():
			print("[Pawn] %s died from exhaustion  (rest=%.1f)" % [data.display_name, data.rest])
		_die("")
		return
	if data.health <= 0.0:
		if GameManager.verbose_logs():
			print("[Pawn] %s died from injuries  (health=%.1f)" % [data.display_name, data.health])
		_die("")
		return

func _emergency_seek_food() -> void:
	# Release current job to prioritize survival
	if _current_job != null:
		_unclaim_current_job()
	
	# Look for food in stockpile - use the correct method
	var stockpile: Stockpile = StockpileManager.find_drop_zone(Item.Type.BERRY, data.tile_pos, _world.pathfinder)
	if stockpile != null and stockpile.has_any_food():
		_state = State.GOING_TO_EAT
		if GameManager.verbose_logs():
			print("[Pawn] %s going to stockpile for emergency food" % data.display_name)
	else:
		# If no stockpile found, try to find any stockpile
		if GameManager.verbose_logs():
			print("[Pawn] %s cannot find stockpile for emergency food" % data.display_name)


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


func _check_temperature() -> void:
	if _world == null:
		return
	
	# Get tile temperature from world (placeholder - needs World temperature data)
	var ambient_temp: float = 20.0  # Default to 20°C if no temperature data
	
	# Adjust based on shelter (being indoors helps)
	var has_shelter: bool = false
	if _reserved_bed.x >= 0 and data.tile_pos == _reserved_bed:
		has_shelter = true
	
	# Body temperature moves toward ambient, slower with shelter
	var temp_change_rate: float = 0.05 if has_shelter else 0.1
	var target_temp: float = ambient_temp
	
	# Fire/hearths increase local temperature (placeholder)
	# TODO: Check for nearby hearth/fire
	
	data.body_temperature = lerp(data.body_temperature, target_temp, temp_change_rate)
	
	# Accumulate hypothermia/heat exhaustion risk
	if data.body_temperature < 35.0:
		data.hypothermia_risk = min(100.0, data.hypothermia_risk + 0.2)
	elif data.body_temperature > 38.0:
		data.heat_exhaustion_risk = min(100.0, data.heat_exhaustion_risk + 0.2)
	else:
		# Recover from temperature risks when in normal range
		data.hypothermia_risk = max(0.0, data.hypothermia_risk - 0.1)
		data.heat_exhaustion_risk = max(0.0, data.heat_exhaustion_risk - 0.1)
	
	# Hypothermia causes health damage
	if data.hypothermia_risk > 80.0:
		data.health = max(0.0, data.health - 0.1)
		data.exposure_sickness = min(100.0, data.exposure_sickness + 0.05)
	
	# Heat exhaustion causes health damage
	if data.heat_exhaustion_risk > 80.0:
		data.health = max(0.0, data.health - 0.1)


func _process_injuries() -> void:
	# Pain decays slowly over time
	data.pain = max(0.0, data.pain - 0.05)
	
	# Process each injury
	var injuries_to_remove: Array = []
	for injury_type in data.injuries:
		var severity: float = data.injuries[injury_type]
		
		# Injuries heal slowly when resting
		if _state == State.SLEEPING or _state == State.IDLE:
			severity -= 0.02
		else:
			severity -= 0.005  # Very slow healing when active
		
		# Pain from injury
		if severity > 30.0:
			data.pain = min(100.0, data.pain + severity * 0.01)
		
		# Remove healed injuries
		if severity <= 0.0:
			injuries_to_remove.append(injury_type)
		else:
			data.injuries[injury_type] = severity
	
	# Remove healed injuries
	for injury_type in injuries_to_remove:
		data.injuries.erase(injury_type)
	
	# Severe injuries cause health damage
	for injury_type in data.injuries:
		var severity: float = data.injuries[injury_type]
		if severity > 70.0:
			data.health = max(0.0, data.health - 0.02)


func _observe_nearby_work() -> void:
	# Pawns can learn by watching others work nearby
	# Observation radius: 50 pixels
	# Throttled to every 15 ticks to avoid lag (0.25 seconds at 1x speed)
	if GameManager.tick_count % 15 != 0:
		return
	
	var observation_radius: float = 50.0
	
	for pawn in get_tree().get_nodes_in_group("pawns"):
		if pawn == self or not is_instance_valid(pawn):
			continue
		var dist: float = position.distance_to(pawn.position)
		if dist > observation_radius:
			continue
		
		# Only learn if the other pawn is working
		if pawn._state != State.WORKING or pawn._current_job == null:
			continue
		
		# Get the skill being used
		var observed_skill: int = PawnData.skill_for_job(pawn._current_job.type)
		if observed_skill < 0:
			continue
		
		# Small chance to learn from observation (5% per tick)
		if randf() < 0.05:
			# Grant small XP from observation (0.25x normal XP)
			data.add_skill_xp(observed_skill, PawnData.XP_PER_WORK_TICK * 0.25)
			if GameManager.verbose_logs():
				print("[Pawn] %s observed %s working on %s" % [
					data.display_name,
					pawn.data.display_name,
					Job.describe_type(pawn._current_job.type)
				])


func teach_skill(target_pawn: Pawn, skill: int) -> bool:
	# Teach a skill to another pawn
	# Requires: teacher has skill level >= 5, target has lower skill level
	var teacher_level: int = data.get_skill_level(skill)
	var target_level: int = target_pawn.data.get_skill_level(skill)
	
	if teacher_level < 5 or target_level >= teacher_level:
		return false
	
	# Grant XP to target (faster than self-learning)
	target_pawn.data.add_skill_xp(skill, PawnData.XP_PER_WORK_TICK * 2.0)
	
	# Small XP bonus to teacher for teaching
	data.add_skill_xp(skill, PawnData.XP_PER_WORK_TICK * 0.5)
	
	if GameManager.verbose_logs():
		print("[Pawn] %s taught %s in %s" % [
			data.display_name,
			target_pawn.data.display_name,
			PawnData.skill_name(skill)
		])
	
	return true


func inherit_knowledge(parent_a_id: int, parent_b_id: int) -> void:
	# Children inherit some knowledge from parents
	# This is called during pawn creation
	
	# Find parent pawns
	var parent_a: Pawn = null
	var parent_b: Pawn = null
	
	for pawn in get_tree().get_nodes_in_group("pawns"):
		if int(pawn.data.id) == parent_a_id:
			parent_a = pawn
		elif int(pawn.data.id) == parent_b_id:
			parent_b = pawn
	
	# Inherit 10% of parent XP in each skill
	if parent_a != null:
		for skill in parent_a.data.skill_xp:
			var inherited_xp: float = parent_a.data.skill_xp[skill] * 0.1
			data.skill_xp[skill] = data.skill_xp.get(skill, 0.0) + inherited_xp
	
	if parent_b != null:
		for skill in parent_b.data.skill_xp:
			var inherited_xp: float = parent_b.data.skill_xp[skill] * 0.1
			data.skill_xp[skill] = data.skill_xp.get(skill, 0.0) + inherited_xp
	
	# Update level based on inherited XP
	data._check_level_up()


func _update_perception() -> void:
	# Update perception radius based on level
	# Base radius 50, +10 per level, max 200
	data.perception_radius = clamp(50.0 + float(data.level) * 10.0, 50.0, 200.0)
	
	# Throttled to every 20 ticks to avoid lag (0.33 seconds at 1x speed)
	if GameManager.tick_count % 20 != 0:
		return
	
	# Remember resources and dangers in perception radius
	if _world == null:
		return
	
	var perception_tiles: Array = _get_tiles_in_radius(data.perception_radius)
	
	for tile in perception_tiles:
		var tile_key: String = "%d,%d" % [tile.x, tile.y]
		var current_tick: int = GameManager.tick_count if "tick_count" in GameManager else 0
		
		# Check for resources
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
		
		# Check for dangers
		var danger_level: float = 0.0
		# TODO: Check for enemies, dangerous terrain, etc.
		
		# Update location memory
		if resource_type != "" or danger_level > 0.0:
			data.location_memory[tile_key] = {
				"last_seen": current_tick,
				"resource_type": resource_type,
				"danger_level": danger_level
			}


func _get_tiles_in_radius(radius: float) -> Array:
	# Get all tiles within perception radius
	var tiles: Array = []
	var radius_tiles: int = int(radius / 16.0)  # Assuming 16 pixels per tile
	
	for dx in range(-radius_tiles, radius_tiles + 1):
		for dy in range(-radius_tiles, radius_tiles + 1):
			var tile: Vector2i = data.tile_pos + Vector2i(dx, dy)
			if _world != null and _world.is_valid_tile(tile.x, tile.y):
				tiles.append(tile)
	
	return tiles


func assess_risk(tile: Vector2i) -> float:
	# Assess danger level of a tile (0-100)
	var risk: float = 0.0
	
	if _world == null:
		return risk
	
	# Check for nearby enemies
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		var enemy_tile: Vector2i = _world.world_to_tile(enemy.position)
		var dist: float = tile.distance_squared_to(enemy_tile)
		if dist < 25.0:  # Within 5 tiles
			risk += 30.0
	
	# Check for dangerous terrain
	var feature: int = _world.data.get_feature(tile.x, tile.y)
	# Note: MOUNTAIN not in TileFeature.Type, checking for impassable features instead
	if feature == TileFeature.Type.WALL:
		risk += 10.0
	
	# Check location memory
	var tile_key: String = "%d,%d" % [tile.x, tile.y]
	if tile_key in data.location_memory:
		var memory: Dictionary = data.location_memory[tile_key]
		risk += memory.get("danger_level", 0.0)
	
	return clamp(risk, 0.0, 100.0)


func remember_resources(tile: Vector2i, resource_type: String) -> void:
	var tile_key: String = "%d,%d" % [tile.x, tile.y]
	var current_tick: int = GameManager.tick_count if "tick_count" in GameManager else 0
	
	data.location_memory[tile_key] = {
		"last_seen": current_tick,
		"resource_type": resource_type,
		"danger_level": 0.0
	}


## Stage 2: Family & Trust system

func track_co_presence() -> void:
	# Track time spent near other pawns
	# Co-presence builds family bonds and trust
	# Throttled to every 10 ticks to avoid lag (0.16 seconds at 1x speed)
	if GameManager.tick_count % 10 != 0:
		return
	
	var co_presence_radius: float = 30.0  # Pixels
	
	for pawn in get_tree().get_nodes_in_group("pawns"):
		if pawn == self or not is_instance_valid(pawn):
			continue
		var dist: float = position.distance_to(pawn.position)
		if dist > co_presence_radius:
			continue
		
		var other_id: int = int(pawn.data.id)
		
		# Increment co-presence counter
		data.co_presence[other_id] = data.co_presence.get(other_id, 0) + 1
		
		# Build family bond if related
		if other_id == data.parent_a_id or other_id == data.parent_b_id:
			data.family_bonds[other_id] = min(100.0, data.family_bonds.get(other_id, 0.0) + 0.1)
		
		# Build trust gradually
		data.trust[other_id] = min(100.0, data.trust.get(other_id, 0.0) + 0.05)


func form_family_bond(other_pawn: Pawn, initial_strength: float = 20.0) -> void:
	# Form a family bond with another pawn
	var other_id: int = int(other_pawn.data.id)
	data.family_bonds[other_id] = clamp(initial_strength, 0.0, 100.0)
	other_pawn.data.family_bonds[int(data.id)] = clamp(initial_strength, 0.0, 100.0)
	
	if GameManager.verbose_logs():
		print("[Pawn] %s formed family bond with %s (strength %.1f)" % [
			data.display_name, other_pawn.data.display_name, initial_strength
		])


func marry(spouse: Pawn) -> void:
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
	
	if GameManager.verbose_logs():
		print("[Pawn] %s married %s (household %d)" % [
			data.display_name, spouse.data.display_name, data.household_id
		])


func have_child(partner: Pawn) -> int:
	# Have a child with partner
	# Returns the new child's pawn ID
	if data.spouse_id != int(partner.data.id):
		return -1  # Not married to this partner
	
	# This would typically be called by a reproduction system
	# For now, just return -1 as placeholder
	# TODO: Implement actual child creation
	return -1


func _create_household() -> int:
	# Create a new household
	# Placeholder - needs HouseholdSystem
	# For now, return a random ID
	return randi() % 10000


func join_household(household_id: int) -> void:
	# Join an existing household
	data.household_id = household_id
	if GameManager.verbose_logs():
		print("[Pawn] %s joined household %d" % [data.display_name, household_id])


func leave_household() -> void:
	# Leave current household
	var old_household: int = data.household_id
	data.household_id = -1
	
	# Reduce family bonds with former household members
	for other_id in data.family_bonds:
		# Check if other pawn is in same household
		# Placeholder - needs HouseholdSystem to check
		pass
	
	if GameManager.verbose_logs():
		print("[Pawn] %s left household %d" % [data.display_name, old_household])


func get_household_stability() -> float:
	# Calculate household stability (0-100)
	# Based on family bonds, trust, and co-presence
	if data.household_id == -1:
		return 0.0
	
	var stability: float = 0.0
	var household_members: int = 0
	
	# Sum family bonds with household members
	for other_id in data.family_bonds:
		var bond_strength: float = data.family_bonds[other_id]
		stability += bond_strength
		household_members += 1
	
	# Sum trust with household members
	for other_id in data.trust:
		var trust_level: float = data.trust[other_id]
		stability += trust_level * 0.5
	
	if household_members > 0:
		stability /= float(household_members)
	
	return clamp(stability, 0.0, 100.0)


## Stage 3: Clan & Household Network

func join_clan(clan_id: int) -> void:
	# Join a clan
	data.clan_id = clan_id
	if GameManager.verbose_logs():
		print("[Pawn] %s joined clan %d" % [data.display_name, clan_id])


func leave_clan() -> void:
	# Leave current clan
	var old_clan: int = data.clan_id
	data.clan_id = -1
	data.clan_influence = 0.0
	
	if GameManager.verbose_logs():
		print("[Pawn] %s left clan %d" % [data.display_name, old_clan])


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
		print("[Pawn] %s became %s of clan %d" % [data.display_name, role_name, data.clan_id])


func challenge_for_leadership(target_leader: Pawn) -> void:
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
		print("[Pawn] %s joined settlement %d" % [data.display_name, settlement_id])


func leave_settlement() -> void:
	# Leave current settlement
	var old_settlement: int = data.settlement_id
	data.settlement_id = -1
	
	# Lose homestead if owned
	if data.homestead_tile != Vector2i(-1, -1):
		data.owned_properties.erase(data.homestead_tile)
		data.homestead_tile = Vector2i(-1, -1)
	
	if GameManager.verbose_logs():
		print("[Pawn] %s left settlement %d" % [data.display_name, old_settlement])


func establish_homestead(tile: Vector2i) -> bool:
	# Establish a homestead at the given tile
	if _world == null:
		return false
	if not _world.pathfinder.is_passable(tile):
		return false
	
	data.homestead_tile = tile
	data.owned_properties[tile] = "homestead"
	
	if GameManager.verbose_logs():
		print("[Pawn] %s established homestead at %s" % [data.display_name, str(tile)])
	
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
		print("[Pawn] %s established trade with settlement %d (volume %d)" % [
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
		print("[Pawn] %s became %s of settlement %d" % [data.display_name, role_name, data.settlement_id])


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
		print("[Pawn] %s joined region %d" % [data.display_name, region_id])


func leave_region() -> void:
	# Leave current region
	var old_region: int = data.region_id
	data.region_id = -1
	data.citizenship_status = 0
	
	if GameManager.verbose_logs():
		print("[Pawn] %s left region %d" % [data.display_name, old_region])


func build_road(tile: Vector2i) -> bool:
	# Build a road at the given tile
	if _world == null:
		return false
	if not _world.pathfinder.is_passable(tile):
		return false
	
	data.roads_built += 1
	
	if GameManager.verbose_logs():
		print("[Pawn] %s built road at %s" % [data.display_name, str(tile)])
	
	return true


func learn_custom(custom_name: String, familiarity: float = 20.0) -> void:
	# Learn a regional custom or tradition
	data.known_customs[custom_name] = min(100.0, data.known_customs.get(custom_name, 0.0) + familiarity)
	
	if GameManager.verbose_logs():
		print("[Pawn] %s learned custom '%s' (familiarity %.1f)" % [
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
		print("[Pawn] %s became %s of region %d" % [data.display_name, status_name, data.region_id])


func pay_taxes(amount: int) -> void:
	# Pay regional taxes
	data.taxes_paid += amount
	
	if GameManager.verbose_logs():
		print("[Pawn] %s paid %d in taxes to region %d" % [
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
		print("[Pawn] %s joined nation %d" % [data.display_name, nation_id])


func leave_nation() -> void:
	# Leave current nation
	var old_nation: int = data.nation_id
	data.nation_id = -1
	data.national_citizenship = 0
	
	if GameManager.verbose_logs():
		print("[Pawn] %s left nation %d" % [data.display_name, old_nation])


func comply_with_law(law_id: int, compliance_level: float = 100.0) -> void:
	# Record compliance with a law
	data.law_compliance[law_id] = clamp(compliance_level, 0.0, 100.0)


func violate_law(law_id: int) -> void:
	# Record violation of a law
	data.law_compliance[law_id] = max(0.0, data.law_compliance.get(law_id, 100.0) - 50.0)
	
	if GameManager.verbose_logs():
		print("[Pawn] %s violated law %d" % [data.display_name, law_id])


func adopt_culture(culture_name: String, affinity: float = 50.0) -> void:
	# Adopt a cultural identity
	data.cultural_affinity[culture_name] = clamp(affinity, 0.0, 100.0)
	
	if GameManager.verbose_logs():
		print("[Pawn] %s adopted culture '%s' (affinity %.1f)" % [
			data.display_name, culture_name, affinity
		])


func serve_in_military(years: int = 1) -> void:
	# Serve in the military
	data.military_service_years += years
	
	if GameManager.verbose_logs():
		print("[Pawn] %s served %d years in military (total %d)" % [
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
		print("[Pawn] %s became %s of nation %d" % [data.display_name, rank_name, data.nation_id])


func establish_diplomatic_relation(target_nation_id: int, standing: float = 50.0) -> void:
	# Establish diplomatic standing with another nation
	data.diplomatic_standing[target_nation_id] = clamp(standing, 0.0, 100.0)
	
	if GameManager.verbose_logs():
		print("[Pawn] %s established diplomatic relation with nation %d (standing %.1f)" % [
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
		print("[Pawn] %s became %s of nation %d" % [data.display_name, citizenship_name, data.nation_id])


## Stage 7: World systems

func spread_influence_to_region(region_id: int, influence_amount: float = 5.0) -> void:
	# Spread influence to another region
	data.cross_region_influence[region_id] = min(100.0, data.cross_region_influence.get(region_id, 0.0) + influence_amount)
	
	# Increase legacy score
	data.legacy_score += influence_amount * 0.1
	
	if GameManager.verbose_logs():
		print("[Pawn] %s spread influence to region %d (influence %.1f)" % [
			data.display_name, region_id, data.cross_region_influence[region_id]
		])


func adapt_to_climate(climate_type: String, adaptation_amount: float = 10.0) -> void:
	# Adapt to a climate type
	data.climate_adaptation[climate_type] = min(100.0, data.climate_adaptation.get(climate_type, 0.0) + adaptation_amount)
	
	if GameManager.verbose_logs():
		print("[Pawn] %s adapted to climate '%s' (adaptation %.1f)" % [
			data.display_name, climate_type, data.climate_adaptation[climate_type]
		])


func learn_myth(myth_name: String, belief: float = 30.0) -> void:
	# Learn about a myth or legend
	data.myth_knowledge[myth_name] = clamp(belief, 0.0, 100.0)
	
	if GameManager.verbose_logs():
		print("[Pawn] %s learned myth '%s' (belief %.1f)" % [
			data.display_name, myth_name, belief
		])


func witness_world_event(event_id: int, impact: float = 10.0) -> void:
	# Record witnessing a world event
	data.world_events_witnessed[event_id] = impact
	
	# Increase legacy score based on event impact
	data.legacy_score += impact * 0.2
	
	if GameManager.verbose_logs():
		print("[Pawn] %s witnessed world event %d (impact %.1f, legacy %.1f)" % [
			data.display_name, event_id, impact, data.legacy_score
		])


func increase_legacy(amount: float) -> void:
	# Directly increase legacy score
	data.legacy_score += amount
	
	if GameManager.verbose_logs():
		print("[Pawn] %s legacy increased to %.1f" % [data.display_name, data.legacy_score])


## Stage 1: Small direct actions

func gather() -> bool:
	# Pick up items from ground at current tile
	if _world == null:
		return false
	
	# Check for items on ground (placeholder - needs ground item system)
	# TODO: Check for dropped items on current tile
	# For now, just return false
	return false


func craft_simple_tool(tool_type: int) -> bool:
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
	for enemy in get_tree().get_nodes_in_group("enemies"):
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
	queue_redraw()
	
	if GameManager.verbose_logs():
		print("[Pawn] %s fleeing from danger" % data.display_name)
	
	return true


func hide_from_threats() -> bool:
	# Take cover from threats
	# Find nearby cover (walls, trees, etc.)
	if _world == null:
		return false
	
	var cover_tile: Vector2i = Vector2i(-1, -1)
	var best_cover_score: float = -INF
	
	# Check nearby tiles for cover
	var radius: int = 3
	for dx in range(-radius, radius + 1):
		for dy in range(-radius, radius + 1):
			var tile: Vector2i = data.tile_pos + Vector2i(dx, dy)
			if not _world.pathfinder.is_passable(tile):
				continue  # Can't hide in impassable terrain
			
			var feature: int = _world.data.get_feature(tile.x, tile.y)
			var cover_score: float = 0.0
			
			# Trees provide cover
			if feature == TileFeature.Type.TREE:
				cover_score += 5.0
			# Walls provide good cover
			# TODO: Check for nearby walls
			
			# Prefer closer tiles
			var dist: float = data.tile_pos.distance_to(tile)
			cover_score -= dist * 0.5
			
			if cover_score > best_cover_score:
				best_cover_score = cover_score
				cover_tile = tile
	
	if cover_tile.x < 0 or best_cover_score <= 0.0:
		return false  # No cover nearby
	
	# Move to cover
	var path: Array[Vector2i] = _path_for_pawn(cover_tile)
	if path.is_empty():
		return false
	
	_state = State.HIDING
	_start_path(path)
	queue_redraw()
	
	if GameManager.verbose_logs():
		print("[Pawn] %s hiding from threats" % data.display_name)
	
	return true


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
	for enemy in get_tree().get_nodes_in_group("enemies"):
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
			print("[Pawn] %s reached safety" % data.display_name)


func _tick_hiding() -> void:
	# Tick while hiding
	# Stay hidden until danger passes
	if _path.is_empty():
		# At hiding spot, wait for danger to pass
		var danger_nearby: bool = false
		for enemy in get_tree().get_nodes_in_group("enemies"):
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
				print("[Pawn] %s emerged from hiding" % data.display_name)


func die(_p_cause: String) -> void:
	_die(_p_cause)


func _die(_p_cause: String = "") -> void:
	# Release any held job and bed reservation
	release_job_if_any()
	_release_bed_if_reserved()
	# Drop any carried items into the nearest stockpile
	if data.is_carrying() and _world != null:
		var sp: Stockpile = StockpileManager.find_drop_zone(data.carrying, data.tile_pos, _world.pathfinder)
		if sp != null:
			sp.add_item(data.carrying, data.carrying_qty)
	data.clear_carry()
	
	# Trigger sorrow in nearby pawns who witness the death
	_trigger_sorrow_in_nearby_pawns()
	_play_sfx("res://assets/audio/pawn_die.ogg", 0.85)

	# world_trace: all deaths, including old_age
	if get_tree().get_root().has_node("Main/WorldTrace"):
		var world_trace: WorldTrace = get_tree().get_root().get_node("Main/WorldTrace")
		if world_trace != null:
			world_trace.record_trace(global_position, "death")
	
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
		WorldMemory.record_pawn_death(
				GameManager.tick_count,
				data.tile_pos,
				data.id,
				data.display_name,
				mem_cause,
				int(data.current_profession),
				data.parent_a_id,
				data.parent_b_id,
		)
		var main_node: Node = get_tree().get_root().get_node_or_null("Main")
		if main_node != null and main_node.has_method("register_pawn_death"):
			main_node.call("register_pawn_death", int(data.id))
		
		# KnowledgeSystem: remove knowledge carrier when pawn dies
		if KnowledgeSystem != null:
			KnowledgeSystem.remove_knowledge_carrier(int(data.id))
		
		# PersistenceSystem: create grave entity
		if PersistenceSystem != null:
			var entity_id: int = PersistenceSystem.create_persistent_entity(
				PersistenceSystem.EntityType.GRAVE_FIELD,
				data.tile_pos,
				"%s's grave" % data.display_name,
				0.4
			)
			# Record visitation (the deceased's location is visited by mourners)
			PersistenceSystem.record_visitation(entity_id, int(data.id))
	
	# Remove from groups and free the node
	remove_from_group("pawns")
	queue_free()


## Nearby pawns get SORROW mood event when they witness death.
func _trigger_sorrow_in_nearby_pawns() -> void:
	var nearby_distance: float = 50.0  # pixels
	for pawn in get_tree().get_nodes_in_group("pawns"):
		if pawn == self or not is_instance_valid(pawn):
			continue
		var dist: float = position.distance_to(pawn.position)
		if dist < nearby_distance:
			pawn.data.add_mood_event(MoodEvent.Type.SORROW, 70.0, 500)
			if GameManager.verbose_logs():
				print("[Pawn] %s mourns %s's death" % [pawn.data.display_name, data.display_name])


func _check_thresholds() -> void:
	_hunger_level = _update_level(data.hunger, _hunger_level, "hungry",  "starving")
	_rest_level   = _update_level(data.rest,   _rest_level,   "tired",   "exhausted")
	_mood_level   = _update_level(data.mood,   _mood_level,   "unhappy", "miserable")


func _update_level(value: float, prev_level: int, warn_word: String, crit_word: String) -> int:
	var new_level: int = _level_for(value)
	if new_level > prev_level:
		var word := warn_word if new_level == 1 else crit_word
		if GameManager.verbose_logs():
			print("[Pawn] %s is %s  (value=%.1f)" % [data.display_name, word, value])
	return new_level


static func _level_for(value: float) -> int:
	if value <= THRESHOLD_CRIT:
		return 2
	if value <= THRESHOLD_WARN:
		return 1
	return 0


# ==================== wander fallback ====================

## Only 4-way: the straight-line lerp between two cardinally-adjacent tile
## centers can never visually enter a neighboring tile, so pawns never appear
## to clip through an impassable corner during a wander step.
const WANDER_OFFSETS: Array[Vector2i] = [
	Vector2i( 1, 0), Vector2i(-1, 0), Vector2i(0,  1), Vector2i(0, -1),
]


func _start_wander() -> void:
	if _world == null or _world.pathfinder == null:
		return
	# Deterministic: minimize lived scar, then use regional [CulturalMemory] (weaker) as tiebreak.
	var chosen: Vector2i = Vector2i(-1, -1)
	var best_score: int = -1_000_000
	var best_sl: int = 99
	var best_cult: int = -100
	var from_rk: int = preload("res://autoloads/WorldMemory.gd")._region_key(data.tile_pos.x, data.tile_pos.y)
	var from_center: int = SettlementMemory.get_center_region_for_region(from_rk)
	var from_p: float = float(IntentMemory.settlement_pressure.get(from_center, 0.5))
	for offset in WANDER_OFFSETS:
		var t: Vector2i = data.tile_pos + offset
		if not _world.pathfinder.is_passable(t):
			continue
		var s: int = _scar_level_at_tile(t)
		var rk2: int = preload("res://autoloads/WorldMemory.gd")._region_key(t.x, t.y)
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
	if PROCEDURAL_PIXEL_PAWN:
		_draw_procedural_pixel_figure(body_origin, body_radius)
	else:
		draw_circle(body_origin, body_radius, body_color)
		# Apparel ring gives each pawn a readable outfit color.
		draw_arc(body_origin, body_radius - 0.9, PI * 0.12, PI * 0.88, 16, data.apparel_color, 1.0, true)
		# Hair style overlays near the top of the head.
		_draw_hair(body_origin, body_radius)
	if is_selected:
		# Bright yellow ring sits just outside the body and the busy outline so
		# it reads even when the pawn is mid-task.
		var sel_color := Color(1.0, 0.92, 0.18)
		draw_arc(
			body_origin,
			body_radius + 3.5,
			0.0,
			TAU,
			28,
			sel_color,
			1.4,
			true
		)
	# Outline color/width communicates state.
	var busy: bool = (
		_state == State.WORKING
		or _state == State.EATING
		or _state == State.DRAFT_WALK
	)
	var outline_c: Color = Color.BLACK
	if _state == State.WORKING:
		outline_c = Color.WHITE
	elif _state == State.EATING:
		outline_c = Color(0.2, 0.9, 0.2)  # green
	elif _state == State.GOING_TO_EAT:
		outline_c = Color(1.0, 0.85, 0.2)  # amber
	elif _state == State.SLEEPING:
		outline_c = Color(0.49, 0.30, 0.81)  # purple
	elif _state == State.GOING_TO_BED:
		outline_c = Color(0.78, 0.66, 1.0)  # light purple
	elif _state == State.FETCHING_MATERIAL:
		outline_c = Color(0.95, 0.65, 0.35)  # warm orange -- "carrying back"
	elif _state == State.DRAFT_WALK:
		outline_c = Color(0.45, 0.95, 1.0)  # bright cyan
	var outline_w: float = OUTLINE_WIDTH_BUSY if busy else OUTLINE_WIDTH
	draw_arc(body_origin, body_radius, 0.0, TAU, 20, outline_c, outline_w, true)
	# Sleep "Z" mark: tiny purple zig-zag floating above a sleeping pawn.
	if _state == State.SLEEPING:
		var z_color := Color(0.78, 0.66, 1.0)
		var z_top := body_origin + Vector2(2.0, -8.0)
		var z_mid_r := body_origin + Vector2(5.0, -8.0)
		var z_mid_l := body_origin + Vector2(2.0, -5.0)
		var z_bot := body_origin + Vector2(5.0, -5.0)
		draw_line(z_top, z_mid_r, z_color, 0.7, true)
		draw_line(z_mid_r, z_mid_l, z_color, 0.7, true)
		draw_line(z_mid_l, z_bot, z_color, 0.7, true)
	# Teaching "T" mark: tiny blue T floating above a teaching pawn.
	if _state == State.TEACHING:
		var t_color := Color(0.45, 0.95, 1.0)
		var t_top := body_origin + Vector2(0.0, -8.0)
		var t_bottom := body_origin + Vector2(0.0, -5.0)
		var t_left := body_origin + Vector2(-1.5, -8.0)
		var t_right := body_origin + Vector2(1.5, -8.0)
		draw_line(t_left, t_right, t_color, 0.7, true)
		draw_line(t_top, t_bottom, t_color, 0.7, true)
	# Challenge "X" mark: tiny red X floating above a challenging pawn.
	if _state == State.CHALLENGE:
		var c_color := Color(1.0, 0.35, 0.25)
		var c_tl := body_origin + Vector2(-1.5, -8.0)
		var c_tr := body_origin + Vector2(1.5, -8.0)
		var c_bl := body_origin + Vector2(-1.5, -5.0)
		var c_br := body_origin + Vector2(1.5, -5.0)
		draw_line(c_tl, c_br, c_color, 0.7, true)
		draw_line(c_tr, c_bl, c_color, 0.7, true)
	# Draft marker is always visible when pawn is player-controlled.
	if draft_mode:
		var c0: Vector2 = body_origin + Vector2(-2.5, DRAFT_CHEVRON_Y)
		var c1: Vector2 = body_origin + Vector2(0.0, DRAFT_CHEVRON_Y - 2.0)
		var c2: Vector2 = body_origin + Vector2(2.5, DRAFT_CHEVRON_Y)
		draw_polyline([c0, c1, c2], Color(1.0, 0.35, 0.25), 1.0, true)
	# Health bar under the pawn for quick survivability read.
	var hp_ratio: float = clamp(data.health / 100.0, 0.0, 1.0)
	var hb_bg := Rect2(
		body_origin + Vector2(-HEALTH_BAR_W * 0.5, HEALTH_BAR_Y),
		Vector2(HEALTH_BAR_W, HEALTH_BAR_H)
	)
	draw_rect(hb_bg, Color(0, 0, 0, 0.65), true)
	if hp_ratio > 0.0:
		draw_rect(Rect2(hb_bg.position, Vector2(HEALTH_BAR_W * hp_ratio, HEALTH_BAR_H)), Color(0.25, 0.95, 0.35), true)
	# Mood dot above head: green/gold/red for stable/strained/crisis.
	var mood_dot: Color = Color(0.25, 0.9, 0.35)
	if data.mood < 50.0:
		mood_dot = Color(1.0, 0.78, 0.2)
	if data.mood < 25.0:
		mood_dot = Color(1.0, 0.25, 0.2)
	draw_circle(body_origin + Vector2(0.0, MOOD_DOT_Y), 0.85, mood_dot)
	# Action glyphs: tiny symbols to read activity without opening UI.
	var glyph_pos: Vector2 = body_origin + Vector2(0.0, -6.5)
	if _state == State.WORKING:
		draw_line(glyph_pos + Vector2(-1.2, -0.6), glyph_pos + Vector2(1.2, 1.0), Color(1.0, 1.0, 1.0), 0.9, true)
		draw_line(glyph_pos + Vector2(1.2, -0.6), glyph_pos + Vector2(-1.2, 1.0), Color(1.0, 1.0, 1.0), 0.9, true)
	elif _state == State.EATING:
		draw_circle(glyph_pos, 0.9, Color(0.3, 1.0, 0.35))
	elif _state == State.DRAFT_WALK:
		draw_arc(glyph_pos, 1.5, PI * 0.2, PI * 1.8, 10, Color(0.45, 0.95, 1.0), 0.8, true)
	if _hit_flash_ticks > 0:
		var a: float = 0.18 + 0.08 * float(_hit_flash_ticks)
		draw_circle(body_origin, body_radius + 0.7, Color(1.0, 0.2, 0.2, min(0.75, a)))
	# Carry indicator: small colored swatch above the head.
	if data.is_carrying():
		var c: Color = Item.color_for(data.carrying)
		var rect := Rect2(
			body_origin + CARRY_OFFSET - CARRY_SIZE * 0.5,
			CARRY_SIZE
		)
		draw_rect(rect, c, true)
		draw_rect(rect, Color.BLACK, false, 0.6)


func _body_radius() -> float:
	if data == null:
		return DRAW_RADIUS
	match data.body_type:
		PawnData.BodyType.SLIM:
			return DRAW_RADIUS - 0.35
		PawnData.BodyType.BROAD:
			return DRAW_RADIUS + 0.45
		_:
			return DRAW_RADIUS


func _draw_hair(body_origin: Vector2, body_radius: float) -> void:
	if data == null:
		return
	var hair_c: Color = data.hair_color
	match data.hair_style:
		PawnData.HairStyle.NONE:
			return
		PawnData.HairStyle.SHORT:
			draw_arc(body_origin + Vector2(0.0, -0.2), body_radius - 0.4, PI * 1.05, PI * 1.95, 10, hair_c, 1.0, true)
		PawnData.HairStyle.MOHAWK:
			draw_line(body_origin + Vector2(0.0, -body_radius), body_origin + Vector2(0.0, body_radius * 0.2), hair_c, 1.1, true)
		PawnData.HairStyle.BUN:
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
# whole class down with it (Pawn fails to load -> JobManager signals can't
# resolve `pawn: Pawn` -> every dependent script fails to load too).
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


## Human-readable summary of what the pawn is doing right now.
## Used by the info panel and (optionally) tooltips.
func describe_state() -> String:
	match _state:
		State.IDLE:
			return "Idle"
		State.WALKING_TO_JOB:
			if _current_job != null:
				return "Heading out: %s" % _verb_for_job(_current_job.type).to_lower()
			return "Walking"
		State.WORKING:
			if _current_job != null:
				return _verb_for_job(_current_job.type)
			return "Working"
		State.HAULING:
			if data != null and data.is_carrying():
				return "Hauling %s" % Item.name_for(data.carrying)
			return "Hauling"
		State.GOING_TO_EAT:
			return "Heading to eat"
		State.EATING:
			return "Eating"
		State.SLEEPING:
			if _reserved_bed.x >= 0:
				return "Sleeping in bed"
			return "Sleeping on the ground"
		State.GOING_TO_BED:
			return "Heading to bed"
		State.FETCHING_MATERIAL:
			if _current_job != null:
				return "Fetching wood for %s" % \
					_verb_for_job(_current_job.type).to_lower()
			return "Fetching materials"
		State.DRAFT_WALK:
			return "Moving (direct order)"
	return "?"


static func _verb_for_job(job_type: int) -> String:
	match job_type:
		Job.Type.FORAGE:
			return "Foraging berries"
		Job.Type.MINE:
			return "Mining stone"
		Job.Type.MINE_WALL:
			return "Tunneling"
		Job.Type.CHOP:
			return "Chopping wood"
		Job.Type.HUNT:
			return "Hunting"
		Job.Type.BUILD_BED:
			return "Building bed"
		Job.Type.BUILD_WALL:
			return "Building wall"
		Job.Type.BUILD_DOOR:
			return "Building door"
	return "Working"
