class_name CareerXP
extends RefCounted

## Phase 4: Career & XP Progression System
## NPCs have careers they advance in over time

enum CareerTrack {
	NONE = -1,
	FORAGER = 0,
	HUNTER = 1,
	BUILDER = 2,
	HEALER = 3,
	FIGHTER = 4,
	CRAFTSMAN = 5,
	SAGE = 6,      # Knowledge keeper
	LEADER = 7,   # Settlement authority
	COOK = 8,
	HERBALIST = 9,
}

const CAREER_TITLES: Dictionary = {
	CareerTrack.NONE: "unemployed",
	CareerTrack.FORAGER: {
		0: "forager_apprentice",
		1: "forager",
		2: "master_forager",
		3: "legendary_harvester",
	},
	CareerTrack.HUNTER: {
		0: "hunter_apprentice",
		1: "hunter",
		2: "master_hunter",
		3: "beast_legender",
	},
	CareerTrack.BUILDER: {
		0: "apprentice_builder",
		1: "builder",
		2: "master_builder",
		3: "architect",
	},
	CareerTrack.HEALER: {
		0: "healer_apprentice",
		1: "healer",
		2: "master_healer",
		3: "sage_healer",
	},
	CareerTrack.FIGHTER: {
		0: "warrior_apprentice",
		1: "warrior",
		2: "master_warrior",
		3: "champion",
	},
	CareerTrack.CRAFTSMAN: {
		0: "apprentice_craftsman",
		1: "craftsman",
		2: "master_craftsman",
		3: "artisan",
	},
	CareerTrack.SAGE: {
		0: "learner",
		1: "sage",
		2: "elder_sage",
		3: "oracle",
	},
	CareerTrack.LEADER: {
		0: "citizen",
		1: "councilor",
		2: "leader",
		3: "ruler",
	},
	CareerTrack.COOK: {
		0: "cook_apprentice",
		1: "cook",
		2: "master_cook",
		3: "chef",
	},
	CareerTrack.HERBALIST: {
		0: "herbalist_apprentice",
		1: "herbalist",
		2: "master_herbalist",
		3: "herb_master",
	},
}

const XP_PER_LEVEL: int = 100
const MAX_LEVEL: int = 3

var _pawn_id: int = -1
var _career_track: CareerTrack = CareerTrack.NONE
var _xp_total: int = 0
var _xp_level: int = 0
var _master_id: int = -1
var _known_by: Array = []
var _proud_moments: Array = []
var _tick_career_started: int = 0


func _init(pawn_id: int) -> void:
	_pawn_id = pawn_id


## Set career track
func set_career(track: CareerTrack, master_id: int = -1) -> void:
	_career_track = track
	_master_id = master_id
	_tick_career_started = GameManager.tick_count if GameManager != null else 0
	add_memory_event("career_started")


## Gain XP from action
func gain_xp(amount: int, action_type: String) -> bool:
	if _career_track == CareerTrack.NONE:
		return false
	
	var old_level: int = _xp_level
	_xp_total += amount
	_update_level()
	
	# Level up event
	if _xp_level > old_level:
		add_memory_event("level_up_%d" % _xp_level)
		return true
	
	# Check for proud moment
	if _xp_total >= 100 and _xp_total - amount < 100:
		add_memory_event("first_milestone")
	
	return _xp_level > old_level


## Get current title
func get_title() -> String:
	if _career_track == CareerTrack.NONE:
		return "unemployed"
	
	var titles: Dictionary = CAREER_TITLES.get(_career_track, {})
	return titles.get(_xp_level, "unknown")


## Get career info for UI
func get_career_info() -> Dictionary:
	return {
		"track": _career_track,
		"xp": _xp_total,
		"level": _xp_level,
		"title": get_title(),
		"master_id": _master_id,
	}


## Can teach others?
func can_teach() -> bool:
	return _xp_level >= 2 and _master_id < 0


## Get teaching XP bonus for student
func get_teaching_xp() -> int:
	match _xp_level:
		0: return 5
		1: return 10
		2: return 20
		3: return 35
	return 0


func _update_level() -> void:
	_xp_level = mini(int(sqrt(float(_xp_total) / float(XP_PER_LEVEL))), MAX_LEVEL)


func add_memory_event(event_key: String) -> void:
	_proud_moments.append({
		"event": event_key,
		"tick": GameManager.tick_count if GameManager != null else 0,
		"xp": _xp_total,
	})
	# Keep only recent moments
	if _proud_moments.size() > 10:
		_proud_moments = _proud_moments.slice(_proud_moments.size() - 10)


func get_state() -> Dictionary:
	return {
		"pawn_id": _pawn_id,
		"career_track": _career_track,
		"xp_total": _xp_total,
		"xp_level": _xp_level,
		"master_id": _master_id,
		"known_by": _known_by,
		"proud_moments": _proud_moments,
		"tick_career_started": _tick_career_started,
	}


func load_state(state: Dictionary) -> void:
	_career_track = state.get("career_track", CareerTrack.NONE)
	_xp_total = state.get("xp_total", 0)
	_xp_level = state.get("xp_level", 0)
	_master_id = state.get("master_id", -1)
	_known_by = state.get("known_by", [])
	_proud_moments = state.get("proud_moments", [])
	_tick_career_started = state.get("tick_career_started", 0)