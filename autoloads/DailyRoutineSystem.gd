extends Node
## DailyRoutineSystem â€” KCD-style daily schedules for every HeelKawnian.
##
## Every pawn has a daily routine based on:
## - Profession (blacksmith works forge hours, farmer works dawn-dusk)
## - Personality (early riser vs night owl, social vs solitary)
## - Season (shorter work days in winter, longer in summer)
## - Needs (hunger overrides schedule, exhaustion forces rest)
## - Social obligations (family meals, community events)
##
## Design principles:
## - Routines are deterministic but flexible
## - Emergencies override schedules
## - Social routines create community cohesion
## - Seasons affect daily rhythms
## - Every pawn has a "home base" to return to

# ============================================================
# CONSTANTS
# ============================================================

## Ticks per visual day
const TICKS_PER_DAY: int = 960

## Routine update interval (ticks)
const ROUTINE_UPDATE_INTERVAL: int = 60

## How often to recompute routines (ticks)
const ROUTINE_RECOMPUTE_INTERVAL: int = 2400

## Time slots in a day (mapped to tick ranges)
enum TimeSlot {
	DAWN,       # 0-15% of day
	MORNING,    # 15-35%
	MIDDAY,     # 35-50%
	AFTERNOON,  # 50-70%
	EVENING,    # 70-85%
	NIGHT,      # 85-100%
}

## Activity types
enum Activity {
	WORK,       # Professional labor
	EAT,        # Meal time
	REST,       # Sleep/recovery
	SOCIAL,     # Interact with others
	PERSONAL,   # Hobbies, self-care
	TRAVEL,     # Moving between locations
	IDLE,       # Free time
	EMERGENCY,  # Urgent need (override)
}

## Profession-based schedule templates (TimeSlot -> Activity as integers)
## TimeSlot: DAWN=0, MORNING=1, MIDDAY=2, AFTERNOON=3, EVENING=4, NIGHT=5
## Activity: WORK=0, EAT=1, REST=2, SOCIAL=3, PERSONAL=4, TRAVEL=5, IDLE=6, EMERGENCY=7
var PROFESSION_SCHEDULES: Dictionary = {
	"farmer": {
		0: 0,  # DAWN: WORK
		1: 0,  # MORNING: WORK
		2: 1,  # MIDDAY: EAT
		3: 0,  # AFTERNOON: WORK
		4: 3,  # EVENING: SOCIAL
		5: 2,  # NIGHT: REST
	},
	"blacksmith": {
		0: 2,  # DAWN: REST
		1: 0,  # MORNING: WORK
		2: 1,  # MIDDAY: EAT
		3: 0,  # AFTERNOON: WORK
		4: 4,  # EVENING: PERSONAL
		5: 2,  # NIGHT: REST
	},
	"builder": {
		0: 0,  # DAWN: WORK
		1: 0,  # MORNING: WORK
		2: 1,  # MIDDAY: EAT
		3: 0,  # AFTERNOON: WORK
		4: 2,  # EVENING: REST
		5: 2,  # NIGHT: REST
	},
	"guard": {
		0: 0,  # DAWN: WORK
		1: 0,  # MORNING: WORK
		2: 1,  # MIDDAY: EAT
		3: 0,  # AFTERNOON: WORK
		4: 0,  # EVENING: WORK
		5: 2,  # NIGHT: REST
	},
	"scholar": {
		0: 4,  # DAWN: PERSONAL
		1: 0,  # MORNING: WORK
		2: 1,  # MIDDAY: EAT
		3: 0,  # AFTERNOON: WORK
		4: 3,  # EVENING: SOCIAL
		5: 2,  # NIGHT: REST
	},
	"trader": {
		0: 5,  # DAWN: TRAVEL
		1: 0,  # MORNING: WORK
		2: 1,  # MIDDAY: EAT
		3: 0,  # AFTERNOON: WORK
		4: 3,  # EVENING: SOCIAL
		5: 2,  # NIGHT: REST
	},
	"healer": {
		0: 4,  # DAWN: PERSONAL
		1: 0,  # MORNING: WORK
		2: 1,  # MIDDAY: EAT
		3: 0,  # AFTERNOON: WORK
		4: 3,  # EVENING: SOCIAL
		5: 2,  # NIGHT: REST
	},
	"hunter": {
		0: 0,  # DAWN: WORK
		1: 0,  # MORNING: WORK
		2: 1,  # MIDDAY: EAT
		3: 0,  # AFTERNOON: WORK
		4: 4,  # EVENING: PERSONAL
		5: 2,  # NIGHT: REST
	},
	"fisher": {
		0: 0,  # DAWN: WORK
		1: 0,  # MORNING: WORK
		2: 1,  # MIDDAY: EAT
		3: 0,  # AFTERNOON: WORK
		4: 3,  # EVENING: SOCIAL
		5: 2,  # NIGHT: REST
	},
	"leader": {
		0: 4,  # DAWN: PERSONAL
		1: 0,  # MORNING: WORK
		2: 1,  # MIDDAY: EAT
		3: 0,  # AFTERNOON: WORK
		4: 3,  # EVENING: SOCIAL
		5: 2,  # NIGHT: REST
	},
}

## Default schedule for unassigned pawns
var DEFAULT_SCHEDULE: Dictionary = {
	0: 0,  # DAWN: WORK
	1: 0,  # MORNING: WORK
	2: 1,  # MIDDAY: EAT
	3: 0,  # AFTERNOON: WORK
	4: 3,  # EVENING: SOCIAL
	5: 2,  # NIGHT: REST
}

## Seasonal schedule modifiers
var SEASON_MODIFIERS: Dictionary = {
	0: {  # SPRING
		"work_extension": 0.1,  # Longer work days
		"social_bonus": 0.1,    # More socializing
	},
	1: {  # SUMMER
		"work_extension": 0.2,  # Longest work days
		"rest_reduction": 0.1,  # Less sleep needed
	},
	2: {  # AUTUMN
		"work_extension": 0.05, # Slightly longer
		"personal_bonus": 0.1,  # More personal time
	},
	3: {  # WINTER
		"work_reduction": -0.2, # Shorter work days
		"social_bonus": 0.2,    # More indoor socializing
		"rest_extension": 0.15, # More sleep
	},
}

# ============================================================
# ROUTINE DATA
# ============================================================

## pawn_id -> routine data
## {
##   "schedule": Dictionary,  # TimeSlot -> Activity
##   "current_activity": Activity,
##   "current_timeslot": TimeSlot,
##   "home_tile": Vector2i,
##   "work_tile": Vector2i,
##   "social_tile": Vector2i,
##   "last_routine_tick": int,
##   "routine_adherence": float,  # 0.0-1.0, how well they follow routine
##   "personality_profile": Dictionary,
## }
var pawn_routines: Dictionary = {}

## Cached time slot for current tick
var _cached_timeslot: int = -1
var _cached_timeslot_tick: int = -1

# ============================================================
# INITIALIZATION
# ============================================================

func _ready() -> void:
	if GameManager != null:
		GameManager.game_tick.connect(_on_game_tick)


func _on_game_tick(tick: int) -> void:
	# Update routines periodically
	if tick % ROUTINE_UPDATE_INTERVAL == 0:
		_update_current_activities(tick)
	# Recompute routines for new pawns
	if tick % ROUTINE_RECOMPUTE_INTERVAL == 0:
		_recompute_all_routines(tick)


# ============================================================
# ROUTINE GENERATION
# ============================================================

func _recompute_all_routines(tick: int) -> void:
	"""Generate or update routines for all alive pawns."""
	if PawnAccess == null:
		return
	var pawns: Array = PawnAccess.find_alive_pawns()
	for p in pawns:
		if p == null or not is_instance_valid(p) or p.data == null:
			continue
		var pawn_id: int = int(p.data.id)
		if not pawn_routines.has(pawn_id):
			_create_routine_for_pawn(p, tick)
		else:
			_update_routine_for_pawn(p, tick)


func _create_routine_for_pawn(pawn: Node, tick: int) -> void:
	"""Create a new routine for a pawn."""
	var pawn_id: int = int(pawn.data.id)
	var profession: String = _get_pawn_profession(pawn)
	var personality: Dictionary = _get_pawn_personality(pawn)
	var season: int = Biome.season_for_tick(tick) if Biome != null else 0
	# Build schedule from profession template
	var base_schedule: Dictionary = PROFESSION_SCHEDULES.get(profession, DEFAULT_SCHEDULE).duplicate()
	# Apply personality modifiers
	_apply_personality_modifiers(base_schedule, personality)
	# Apply seasonal modifiers
	_apply_season_modifiers(base_schedule, season)
	# Determine location preferences
	var home_tile: Vector2i = _find_home_tile(pawn)
	var work_tile: Vector2i = _find_work_tile(pawn, profession)
	var social_tile: Vector2i = _find_social_tile(pawn)
	pawn_routines[pawn_id] = {
		"schedule": base_schedule,
		"current_activity": int(base_schedule.get(_get_current_timeslot(tick), 0)),  # 0=WORK
		"current_timeslot": _get_current_timeslot(tick),
		"home_tile": home_tile,
		"work_tile": work_tile,
		"social_tile": social_tile,
		"last_routine_tick": tick,
		"routine_adherence": 0.8,
		"personality_profile": personality,
		"profession": profession,
	}


func _update_routine_for_pawn(pawn: Node, tick: int) -> void:
	"""Update an existing routine (season change, profession change, etc.)."""
	var pawn_id: int = int(pawn.data.id)
	var routine: Dictionary = pawn_routines.get(pawn_id, {})
	if routine.is_empty():
		_create_routine_for_pawn(pawn, tick)
		return
	var season: int = Biome.season_for_tick(tick) if Biome != null else 0
	var last_season: int = Biome.season_for_tick(int(routine.get("last_routine_tick", 0))) if Biome != null else 0
	if season != last_season:
		# Season changed, update schedule
		var base_schedule: Dictionary = PROFESSION_SCHEDULES.get(str(routine.get("profession", "")), DEFAULT_SCHEDULE).duplicate()
		_apply_personality_modifiers(base_schedule, routine.get("personality_profile", {}))
		_apply_season_modifiers(base_schedule, season)
		routine["schedule"] = base_schedule
	routine["last_routine_tick"] = tick


# ============================================================
# ACTIVITY UPDATES
# ============================================================

func _update_current_activities(tick: int) -> void:
	"""Update each pawn's current activity based on their routine."""
	var current_slot: int = _get_current_timeslot(tick)
	for pawn_id in pawn_routines.keys():
		var routine: Dictionary = pawn_routines[pawn_id]
		var schedule: Dictionary = routine.get("schedule", {})
		var planned_activity: int = int(schedule.get(current_slot, 0))
		# Check for emergency overrides
		var pawn: Node = _get_pawn_by_id(pawn_id)
		if pawn == null or pawn.data == null:
			continue
		var actual_activity: int = _apply_emergency_overrides(planned_activity, pawn, tick)
		routine["current_activity"] = actual_activity
		routine["current_timeslot"] = current_slot
		# Track adherence
		if actual_activity != planned_activity:
			routine["routine_adherence"] = maxf(0.0, float(routine.get("routine_adherence", 0.8)) - 0.01)
		else:
			routine["routine_adherence"] = minf(1.0, float(routine.get("routine_adherence", 0.8)) + 0.005)


func _apply_emergency_overrides(planned_activity: int, pawn: Node, tick: int) -> int:
	"""Override planned activity based on urgent needs."""
	if pawn.data == null:
		return planned_activity
	# Hunger override
	if float(pawn.data.get("hunger", 100.0)) < 20.0:
		return int(1)
	# Exhaustion override
	if float(pawn.data.get("rest", 100.0)) < 10.0:
		return int(2)
	# Injury override
	if float(pawn.data.get("health", 100.0)) < 30.0:
		return int(2)
	# Emergency: fire, attack, etc.
	if _is_emergency_situation(pawn, tick):
		return int(7)
	return planned_activity


func _is_emergency_situation(pawn: Node, tick: int) -> bool:
	"""Check if there's an emergency requiring immediate action."""
	# Check for nearby fires
	if EcologySystem != null:
		var tile: Vector2i = pawn.data.tile_pos if pawn.data != null else Vector2i.ZERO
		if EcologySystem.is_tile_on_fire(tile.x, tile.y):
			return true
	# Check for combat
	if pawn.data != null:
		var in_combat: bool = bool(pawn.data.get("in_combat", false))
		if in_combat:
			return true
	return false


# ============================================================
# SCHEDULE MODIFIERS
# ============================================================

func _apply_personality_modifiers(schedule: Dictionary, personality: Dictionary) -> void:
	"""Adjust schedule based on personality traits."""
	var early_riser: float = float(personality.get("early_riser", 0.5))
	var social: float = float(personality.get("social", 0.5))
	var work_ethic: float = float(personality.get("work_ethic", 0.5))
	# Early risers start work at dawn
	if early_riser > 0.7:
		schedule[0] = 0
	# Night owls sleep later
	elif early_riser < 0.3:
		schedule[0] = 2
	# Social pawns prioritize evening socializing
	if social > 0.7:
		schedule[4] = 3
	# Solitary pawns prefer personal time
	elif social < 0.3:
		schedule[4] = 4
	# High work ethic extends work hours
	if work_ethic > 0.8:
		schedule[4] = 0
	# Low work ethic adds more idle time
	elif work_ethic < 0.3:
		schedule[3] = 6


func _apply_season_modifiers(schedule: Dictionary, season: int) -> void:
	"""Adjust schedule based on current season."""
	var modifiers: Dictionary = SEASON_MODIFIERS.get(season, {})
	# Winter: shorter work days, more social/rest
	if modifiers.has("work_reduction"):
		if schedule.get(0) == 0:
			schedule[0] = 2
	if modifiers.has("social_bonus"):
		if schedule.get(4) == 6:
			schedule[4] = 3
	if modifiers.has("rest_extension"):
		if schedule.get(5) == 2:
			pass  # Already resting, extend implicitly
	# Summer: longer work days
	if modifiers.has("work_extension"):
		if schedule.get(0) == 2:
			schedule[0] = 0


# ============================================================
# LOCATION RESOLUTION
# ============================================================

func _find_home_tile(pawn: Node) -> Vector2i:
	"""Find the pawn's home tile (bed, shelter, or current position)."""
	if pawn.data == null:
		return Vector2i.ZERO
	# Check for reserved bed
	var reserved_bed: Vector2i = pawn.data.get("reserved_bed", Vector2i(-1, -1))
	if reserved_bed.x >= 0:
		return reserved_bed
	# Fall back to current position
	return pawn.data.tile_pos


func _find_work_tile(pawn: Node, profession: String) -> Vector2i:
	"""Find the pawn's primary work location."""
	if pawn.data == null:
		return Vector2i.ZERO
	# For now, use current position; in full implementation,
	# this would resolve to profession-specific buildings
	return pawn.data.tile_pos


func _find_social_tile(pawn: Node) -> Vector2i:
	"""Find the pawn's preferred social location (fire pit, gathering spot)."""
	if pawn.data == null:
		return Vector2i.ZERO
	# Search for nearby fire pit or gathering spot
	var center: Vector2i = pawn.data.tile_pos
	if _world != null and _world.data != null:
		for dx in range(-8, 9):
			for dy in range(-8, 9):
				var tx: int = center.x + dx
				var ty: int = center.y + dy
				if not _world.data.in_bounds(tx, ty):
					continue
				var feat: int = _world.data.get_feature(tx, ty)
				if feat == TileFeature.Type.FIRE_PIT:
					return Vector2i(tx, ty)
	return center


# ============================================================
# TIME SLOT RESOLUTION
# ============================================================

func _get_current_timeslot(tick: int) -> int:
	"""Get the current time slot for a given tick."""
	if tick == _cached_timeslot_tick:
		return _cached_timeslot
	var day_tick: int = tick % TICKS_PER_DAY
	var progress: float = float(day_tick) / float(TICKS_PER_DAY)
	var slot: int
	if progress < 0.15:
		slot = int(0)
	elif progress < 0.35:
		slot = int(1)
	elif progress < 0.50:
		slot = int(2)
	elif progress < 0.70:
		slot = int(3)
	elif progress < 0.85:
		slot = int(4)
	else:
		slot = int(5)
	_cached_timeslot = slot
	_cached_timeslot_tick = tick
	return slot


func get_timeslot_name(slot: int) -> String:
	match slot:
		int(0): return "Dawn"
		int(1): return "Morning"
		int(2): return "Midday"
		int(3): return "Afternoon"
		int(4): return "Evening"
		int(5): return "Night"
		_: return "Unknown"


func get_activity_name(activity: int) -> String:
	match activity:
		int(0): return "Working"
		int(1): return "Eating"
		int(2): return "Resting"
		int(3): return "Socializing"
		int(4): return "Personal time"
		int(5): return "Traveling"
		int(6): return "Idle"
		int(7): return "Emergency!"
		_: return "Unknown"


# ============================================================
# PROFESSION RESOLUTION
# ============================================================

func _get_pawn_profession(pawn: Node) -> String:
	"""Get the pawn's organic profession (developed via skill XP & liking lanes)."""
	if pawn.data == null:
		return "unassigned"
	# HeelKawnianData already tracks organic profession via current_profession enum
	# and profession_name() returns the human-readable label.
	if pawn.data.has_method("profession_name"):
		var prof: String = pawn.data.profession_name()
		if prof != "" and prof != "none":
			return prof
	return "unassigned"


func _get_pawn_personality(pawn: Node) -> Dictionary:
	"""Get the pawn's personality profile."""
	if pawn.data == null:
		return {"early_riser": 0.5, "social": 0.5, "work_ethic": 0.5}
	var personality: Dictionary = pawn.data.get("personality", {})
	return {
		"early_riser": float(personality.get("early_riser", 0.5)),
		"social": float(personality.get("social", 0.5)),
		"work_ethic": float(personality.get("work_ethic", 0.5)),
	}


# ============================================================
# HELPERS
# ============================================================

func _get_pawn_by_id(pawn_id: int) -> Node:
	if PawnAccess == null:
		return null
	var pawns: Array = PawnAccess.find_alive_pawns()
	for p in pawns:
		if p != null and is_instance_valid(p) and p.data != null:
			if int(p.data.id) == pawn_id:
				return p
	return null


var _world: Node = null

func _get_world() -> Node:
	if _world == null or not is_instance_valid(_world):
		var main: Node = get_node_or_null("/root/Main")
		if main != null:
			_world = main.get_node_or_null("World") if main.has_node("World") else null
	return _world


# ============================================================
# PUBLIC API
# ============================================================

func get_routine_for_pawn(pawn_id: int) -> Dictionary:
	return pawn_routines.get(pawn_id, {})


func get_current_activity_for_pawn(pawn_id: int) -> int:
	var routine: Dictionary = pawn_routines.get(pawn_id, {})
	return int(routine.get("current_activity", 0))


func get_current_timeslot_for_tick(tick: int) -> int:
	return _get_current_timeslot(tick)


func get_routine_adherence(pawn_id: int) -> float:
	var routine: Dictionary = pawn_routines.get(pawn_id, {})
	return float(routine.get("routine_adherence", 0.8))


func get_pawn_home_tile(pawn_id: int) -> Vector2i:
	var routine: Dictionary = pawn_routines.get(pawn_id, {})
	return routine.get("home_tile", Vector2i.ZERO)


func get_pawn_work_tile(pawn_id: int) -> Vector2i:
	var routine: Dictionary = pawn_routines.get(pawn_id, {})
	return routine.get("work_tile", Vector2i.ZERO)


func get_pawn_social_tile(pawn_id: int) -> Vector2i:
	var routine: Dictionary = pawn_routines.get(pawn_id, {})
	return routine.get("social_tile", Vector2i.ZERO)


func get_routine_count() -> int:
	return pawn_routines.size()


func get_pawns_by_activity(activity: int) -> Array[int]:
	var result: Array[int] = []
	for pawn_id in pawn_routines.keys():
		var routine: Dictionary = pawn_routines[pawn_id]
		if int(routine.get("current_activity", -1)) == activity:
			result.append(pawn_id)
	return result
