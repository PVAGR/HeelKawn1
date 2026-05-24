class_name GoalEngine
extends RefCounted

## Phase 4: Goal & Aspiration Engine
## NPCs have personal goals they actively pursue

enum GoalScope {
	IMMEDIATE = 0,    # "Finish harvesting this wheat"
	TODAY = 1,         # "Get enough food for winter"
	THIS_YEAR = 3,     # "Build a proper house"
	LIFELONG = 4,      # "Become the settlement's healer"
}

enum GoalStatus {
	ACTIVE = 0,
	COMPLETED = 1,
	FAILED = 2,
	ABANDONED = 3,
}

const MAX_GOALS_PER_SCOPE: int = 2
const MAX_TOTAL_GOALS: int = 6
const DAILY_GOAL_REFRESH_TICKS: int = 1000  # ~1 in-game day

var _pawn_id: int = -1
var _goals: Array[Dictionary] = []
var _tick_last_daily_refresh: int = 0
var _lifelong_aspirations: Array = []


func _init(pawn_id: int) -> void:
	_pawn_id = pawn_id


## Add a new goal
func add_goal(
	goal_key: String,
	scope: GoalScope,
	stakes: String = "",
	obstacles: Array = [],
	hope_level: float = 0.5,
	external_dependencies: Array = []
) -> void:
	# Check scope limits
	var same_scope_count: int = 0
	for g in _goals:
		if g.scope == scope:
			same_scope_count += 1
	
	if same_scope_count >= MAX_GOALS_PER_SCOPE:
		return
	if _goals.size() >= MAX_TOTAL_GOALS:
		_remove_lowest_priority_goal()
	
	var goal: Dictionary = {
		"key": goal_key,
		"scope": scope,
		"status": GoalStatus.ACTIVE,
		"stakes": stakes,
		"obstacles": obstacles.duplicate(),
		"hope_level": hope_level,
		"external_dependencies": external_dependencies.duplicate(),
		"tick_created": _current_tick(),
		"tick_updated": _current_tick(),
		"progress": 0.0,
		"difficulty": _estimate_difficulty(goal_key),
	}
	
	_goals.append(goal)


## Remove goal by key
func remove_goal(goal_key: String, status: GoalStatus = GoalStatus.ABANDONED) -> void:
	for g in _goals:
		if g.key == goal_key:
			g.status = status
			g.tick_updated = _current_tick()


## Update goal progress
func update_progress(goal_key: String, progress_delta: float) -> void:
	for g in _goals:
		if g.key == goal_key and g.status == GoalStatus.ACTIVE:
			g.progress = clampf(g.progress + progress_delta, 0.0, 1.0)
			g.tick_updated = _current_tick()
			
			if g.progress >= 1.0:
				g.status = GoalStatus.COMPLETED
				add_memory_event("goal_completed_%s" % goal_key)
			break


## Set lifelong aspiration
func set_lifelong_aspiration(aspiration: String, hope: float = 0.5) -> void:
	# Keep only one per career track
	_lifelong_aspirations = _lifelong_aspirations.filter(func(a): return a != aspiration)
	_lifelong_aspirations.append({
		"key": aspiration,
		"hope": hope,
		"tick_set": _current_tick(),
	})


## Pick daily goals (called each morning)
## Accepts optional neural_summary: Dictionary from WorldAI.get_neural_network_summary()
func pick_daily_goals(survival_importance: float = 0.7, neural_summary: Dictionary = {}) -> Array[Dictionary]:
	var tick_now: int = _current_tick()

	# Only refresh once per day
	if tick_now - _tick_last_daily_refresh < DAILY_GOAL_REFRESH_TICKS:
		return get_active_goals()

	_tick_last_daily_refresh = tick_now

	# Keep completed goals, remove failed ones
	var filtered: Array[Dictionary] = []
	for g in _goals:
		if g.status == GoalStatus.ACTIVE or g.progress < 1.0:
			filtered.append(g)
	_goals = filtered

	# Neural-driven goal bias
	var collapse_risk: float = float(neural_summary.get("collapse_risk", 0.5))
	var economic_stability: float = float(neural_summary.get("economic_stability", 0.5))
	var religious_fervor: float = float(neural_summary.get("religious_fervor", 0.5))
	var knowledge_scarcity: float = float(neural_summary.get("knowledge_scarcity", 0.5))

	# High collapse risk → prioritize survival
	if collapse_risk > 0.6:
		survival_importance = minf(1.0, survival_importance + 0.2)

	# Add survival goal if needed
	if survival_importance > 0.6:
		add_goal(
			"survive_today",
			GoalScope.TODAY,
			"Don't starve",
			[],
			survival_importance
		)

	# Neural-driven goal additions
	if economic_stability < 0.4:
		add_goal(
			"improve_economy",
			GoalScope.THIS_YEAR,
			"Stabilize local economy",
			[],
			0.6
		)
	if knowledge_scarcity > 0.6:
		add_goal(
			"preserve_knowledge",
			GoalScope.THIS_YEAR,
			"Record and preserve knowledge",
			[],
			0.7
		)
	if religious_fervor > 0.7:
		add_goal(
			"religious_unity",
			GoalScope.THIS_YEAR,
			"Strengthen faith community",
			[],
			religious_fervor
		)

	# Add variation from lifelong aspirations - use WorldRNG for deterministic selection
	var total: int = _lifelong_aspirations.size()
	if total > 0:
		# Select 1 aspiration deterministically based on pawn_id and year
		var seed_for_year: int = GameManager.tick_count / SimTime.TICKS_PER_SIM_YEAR if GameManager != null else 0
		var sel_idx: int = WorldRNG.index_for(StringName("aspire_select:%d:%d" % [_pawn_id, seed_for_year]), 0, total)
		var selected_aspirations = [_lifelong_aspirations[sel_idx]]
		for asp in selected_aspirations:
			var key: String = asp.key
			if WorldRNG.chance_for(StringName("aspire:%d" % _pawn_id), asp.hope, 1.0):
				add_goal(key, GoalScope.THIS_YEAR, "Aspiration", [], asp.hope)

	return get_active_goals()


## Get active goals
func get_active_goals() -> Array[Dictionary]:
	var active: Array[Dictionary] = []
	for g in _goals:
		if g.status == GoalStatus.ACTIVE:
			active.append(g)
	return active


## Get most urgent goal
func get_most_urgent_goal() -> Dictionary:
	var goals = get_active_goals()
	if goals.is_empty():
		return {}
	
	# Priority: IMMEDIATE > TODAY > THIS_YEAR > LIFELONG
	var by_scope: Array = goals.filter(func(g): return g.scope == GoalScope.IMMEDIATE)
	if not by_scope.is_empty():
		return by_scope[0]
	
	by_scope = goals.filter(func(g): return g.scope == GoalScope.TODAY)
	if not by_scope.is_empty():
		return by_scope[0]
	
	return goals[0] if goals else {}


## Check if goal blocked
func is_goal_blocked(goal_key: String) -> bool:
	for g in _goals:
		if g.key == goal_key:
			# Check dependencies
			for dep in g.external_dependencies:
				if dep < 0:  # Blocked by negative relationship
					return true
			return not g.obstacles.is_empty()
	return false


func _remove_lowest_priority_goal() -> void:
	if _goals.is_empty():
		return
	
	var lowest: int = -1
	var lowest_priority: float = -1.0
	
	for i in range(_goals.size()):
		var g = _goals[i]
		# Priority: higher hope = higher priority
		var priority: float = g.hope_level * (1.0 - g.progress)
		if priority > lowest_priority:
			lowest_priority = priority
			lowest = i
	
	if lowest >= 0:
		_goals.remove_at(lowest)


func _estimate_difficulty(goal_key: String) -> float:
	# Simple difficulty estimation
	match goal_key:
		"survive_today": return 0.3
		"build_shelter": return 0.6
		"learn_healing": return 0.8
		"become_leader": return 0.9
		_: return 0.5


func add_memory_event(event_key: String) -> void:
	# Could integrate with LongTermMemory here
	pass


func _current_tick() -> int:
	return GameManager.tick_count if GameManager != null else 0


func get_state() -> Dictionary:
	return {
		"pawn_id": _pawn_id,
		"goals": _goals,
		"tick_last_daily_refresh": _tick_last_daily_refresh,
		"lifelong_aspirations": _lifelong_aspirations,
	}


func load_state(state: Dictionary) -> void:
	var raw_goals = state.get("goals", [])
	_goals.clear()
	for g in raw_goals:
		if g is Dictionary:
			_goals.append(g)
	_tick_last_daily_refresh = int(state.get("tick_last_daily_refresh", 0))
	var raw_asp = state.get("lifelong_aspirations", [])
	_lifelong_aspirations.clear()
	for a in raw_asp:
		_lifelong_aspirations.append(a)


func active_goal_count() -> int:
	return get_active_goals().size()