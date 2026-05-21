extends Node
## TechnologySystem - Research and unlock new capabilities
##
## Pawns can research technologies that unlock:
## - New buildings (storage hut, workshop, temple)
## - New jobs (smelt, craft, farm)
## - New knowledge types
## - Quality of life improvements

# Technology data structure
## {
##   "tech_id": String,
##   "name": String,
##   "description": String,
##   "prerequisites": Array[String],  # tech IDs that must be researched first
##   "cost": int,  # research points required
##   "unlock_type": String,  # "building", "job", "knowledge", "upgrade"
##   "unlock_data": Dictionary,  # what this unlocks
##   "researched_by": int,  # pawn_id who completed research
##   "researched_tick": int,
##   "status": String  # "locked", "available", "researching", "completed"
## }
var technologies: Dictionary = {}
var research_progress: Dictionary = {}  # tech_id -> current_progress
var total_research_points: int = 0
var _unallocated_research_points: int = 0
var _last_auto_selected_tech: String = ""
var _last_auto_selected_tick: int = -1

const RESEARCH_PULL_INTERVAL_TICKS: int = 120
const RESEARCH_PULL_PHASE_OFFSET: int = 19
const AUTO_SELECTION_INTERVAL_TICKS: int = 180
const AUTO_SELECTION_PHASE_OFFSET: int = 41
const MAX_PULL_PER_SETTLEMENT_STEP: int = 10
const MAX_SETTLEMENTS_PER_PULL_STEP: int = 12

# Signals for Main.gd to connect to
signal research_started(tech_id: String)
signal research_progressed(tech_id: String, progress: int, cost: int)
signal research_completed(tech_id: String)

# References
@onready var _world_memory: Node = null
@onready var _settlement_memory: Node = null
@onready var _knowledge_system: Node = null
@onready var _world_ai: Node = null


func _ready() -> void:
	GameManager.game_tick.connect(_on_game_tick)
	_world_memory = get_node_or_null("/root/WorldMemory")
	_settlement_memory = get_node_or_null("/root/SettlementMemory")
	_knowledge_system = get_node_or_null("/root/KnowledgeSystem")
	_world_ai = get_node_or_null("/root/WorldAI")
	
	# Initialize technology tree
	_initialize_technologies()
	_sync_availability_states()


func _on_game_tick(tick: int) -> void:
	# Check for completed research
	_check_research_completion(tick)
	
	# Pull settlement research points into global technology pool.
	if GameManager != null and GameManager.has_method("periodic_phase_due"):
		if GameManager.periodic_phase_due(tick, RESEARCH_PULL_INTERVAL_TICKS, RESEARCH_PULL_PHASE_OFFSET):
			_pull_research_points_from_knowledge_system()
		if GameManager.periodic_phase_due(tick, AUTO_SELECTION_INTERVAL_TICKS, AUTO_SELECTION_PHASE_OFFSET):
			_sync_availability_states()
			_auto_start_research_if_idle(tick)


func _initialize_technologies() -> void:
	# Tier 1: Basic Survival (immediate unlocks) - BALANCED COSTS (Option C)
	_add_technology({
		"tech_id": "basic_tools",
		"name": "Basic Tools",
		"description": "Craft simple tools for more efficient work",
		"prerequisites": [],
		"cost": 40,  # REDUCED from 50 - faster early progress
		"unlock_type": "upgrade",
		"unlock_data": {"work_speed_bonus": 0.15}  # INCREASED from 0.1 - more noticeable bonus
	})
	
	_add_technology({
		"tech_id": "fire_making",
		"name": "Fire Making",
		"description": "Create and maintain fire for warmth and cooking",
		"prerequisites": [],
		"cost": 60,  # REDUCED from 75
		"unlock_type": "building",
		"unlock_data": {"building": "fire_pit"}
	})
	
	# Tier 2: Settlement Foundation - BALANCED COSTS (Option C)
	_add_technology({
		"tech_id": "woodworking",
		"name": "Woodworking",
		"description": "Work wood into useful structures",
		"prerequisites": ["basic_tools"],
		"cost": 80,  # REDUCED from 100
		"unlock_type": "building",
		"unlock_data": {"buildings": ["wall", "door", "bed"]}
	})
	
	_add_technology({
		"tech_id": "food_storage",
		"name": "Food Storage",
		"description": "Store food to prevent spoilage",
		"prerequisites": ["woodworking"],
		"cost": 100,  # REDUCED from 125
		"unlock_type": "building",
		"unlock_data": {"building": "storage_hut"}
	})
	
	# Tier 3: Advanced Crafts - BALANCED COSTS (Option C)
	_add_technology({
		"tech_id": "pottery",
		"name": "Pottery",
		"description": "Create containers from clay",
		"prerequisites": ["food_storage"],
		"cost": 120,  # REDUCED from 150
		"unlock_type": "job",
		"unlock_data": {"job": "craft_pottery"}
	})
	
	_add_technology({
		"tech_id": "animal_domestication",
		"name": "Animal Domestication",
		"description": "Breed and raise animals for food",
		"prerequisites": ["food_storage"],
		"cost": 160,  # REDUCED from 200
		"unlock_type": "knowledge",
		"unlock_data": {"knowledge": "animal_husbandry"}
	})
	
	# Tier 4: Specialization - BALANCED COSTS (Option C)
	_add_technology({
		"tech_id": "metallurgy",
		"name": "Metallurgy",
		"description": "Work with metals for superior tools",
		"prerequisites": ["pottery", "fire_making"],
		"cost": 240,  # REDUCED from 300
		"unlock_type": "knowledge",
		"unlock_data": {"knowledge": "metallurgy"}
	})
	
	_add_technology({
		"tech_id": "architecture",
		"name": "Architecture",
		"description": "Design advanced buildings",
		"prerequisites": ["woodworking"],
		"cost": 200,  # REDUCED from 250
		"unlock_type": "building",
		"unlock_data": {"buildings": ["workshop", "temple"]}
	})
	
	# Tier 5: Civilization - BALANCED COSTS (Option C)
	_add_technology({
		"tech_id": "writing",
		"name": "Writing",
		"description": "Record knowledge for future generations",
		"prerequisites": ["metallurgy"],
		"cost": 320,  # REDUCED from 400
		"unlock_type": "knowledge",
		"unlock_data": {"knowledge": "writing"}
	})
	
	_add_technology({
		"tech_id": "philosophy",
		"name": "Philosophy",
		"description": "Abstract thinking and ethics",
		"prerequisites": ["writing"],
		"cost": 400,  # REDUCED from 500
		"unlock_type": "upgrade",
		"unlock_data": {"mood_bonus": 0.25}  # INCREASED from 0.2 - better late-game reward
	})


func _add_technology(tech_data: Dictionary) -> void:
	tech_data.status = "locked"
	technologies[tech_data.tech_id] = tech_data
	research_progress[tech_data.tech_id] = 0


func _sync_availability_states() -> void:
	for tech_id in technologies.keys():
		var tech: Dictionary = technologies[tech_id]
		var status: String = str(tech.get("status", "locked"))
		if status == "completed" or status == "researching":
			continue
		if _prerequisites_completed(tech):
			tech.status = "available"
		else:
			tech.status = "locked"


func _prerequisites_completed(tech: Dictionary) -> bool:
	var prereqs: Array = tech.get("prerequisites", [])
	for prereq in prereqs:
		var prereq_id: String = str(prereq)
		if not technologies.has(prereq_id):
			return false
		if str(technologies[prereq_id].get("status", "locked")) != "completed":
			return false
	return true


func _is_research_active() -> bool:
	for tech_id in technologies.keys():
		if str(technologies[tech_id].get("status", "locked")) == "researching":
			return true
	return false


func _pull_research_points_from_knowledge_system() -> void:
	if _knowledge_system == null:
		return
	if not _knowledge_system.has_method("get_research_points") or not _knowledge_system.has_method("spend_research_points"):
		return
	var active_settlements: Array[int] = _get_active_settlement_ids()
	if active_settlements.is_empty():
		return
	var pulled_total: int = 0
	var current_tech: String = get_current_research()
	var settlements_checked: int = 0
	for sid in active_settlements:
		if settlements_checked >= MAX_SETTLEMENTS_PER_PULL_STEP:
			break
		settlements_checked += 1
		var points: int = int(_knowledge_system.get_research_points(sid))
		if points <= 0:
			continue
		var pull_amount: int = mini(points, MAX_PULL_PER_SETTLEMENT_STEP)
		var spent: bool = bool(_knowledge_system.spend_research_points(sid, pull_amount, current_tech))
		if not spent:
			continue
		add_research_points(pull_amount, -1)
		pulled_total += pull_amount
	if pulled_total > 0 and _world_memory != null:
		_world_memory.record_event({
			"type": "technology_research_pull",
			"amount": pulled_total,
			"current_research": current_tech,
			"tick": GameManager.tick_count if GameManager != null else 0,
		})


func _get_active_settlement_ids() -> Array[int]:
	var out: Array[int] = []
	if _settlement_memory == null or not _settlement_memory.has_method("get_settlements"):
		return out
	var settlements: Array = _settlement_memory.get_settlements()
	for st_any in settlements:
		if not (st_any is Dictionary):
			continue
		var st: Dictionary = st_any as Dictionary
		var sid: int = int(st.get("center_region", -1))
		if sid < 0:
			continue
		var state: String = str(st.get("state", "active"))
		if state == "active" or state == "recovering" or state == "revivable":
			out.append(sid)
	return out


func _auto_start_research_if_idle(tick: int) -> void:
	if _is_research_active():
		return
	var best_tech: String = _pick_best_available_technology(tick)
	if best_tech.is_empty():
		return
	if start_research(best_tech):
		_last_auto_selected_tech = best_tech
		_last_auto_selected_tick = tick
		if _world_memory != null:
			_world_memory.record_event({
				"type": "technology_auto_selected",
				"tech_id": best_tech,
				"pressures": _estimate_research_pressures(),
				"tick": tick,
			})


func _pick_best_available_technology(tick: int) -> String:
	var available: Array = get_available_technologies()
	if available.is_empty():
		return ""
	var pressures: Dictionary = _estimate_research_pressures()
	var best_id: String = ""
	var best_score: float = -1.0e20
	for tech_id_any in available:
		var tech_id: String = str(tech_id_any)
		var score: float = _score_technology_candidate(tech_id, pressures, tick)
		if score > best_score:
			best_score = score
			best_id = tech_id
	return best_id


func _score_technology_candidate(tech_id: String, pressures: Dictionary, tick: int) -> float:
	if not technologies.has(tech_id):
		return -9999.0
	var tech: Dictionary = technologies[tech_id]
	var score: float = 1.0
	var cost: int = int(tech.get("cost", 100))
	# Prefer affordable, still-progressive research.
	score += clampf(220.0 / maxf(40.0, float(cost)), 0.0, 2.2)
	
	var food_p: float = float(pressures.get("food", 0.4))
	var defense_p: float = float(pressures.get("defense", 0.3))
	var build_p: float = float(pressures.get("construction", 0.35))
	var culture_p: float = float(pressures.get("culture", 0.25))
	var resource_p: float = float(pressures.get("resources", 0.35))
	
	match tech_id:
		"fire_making", "food_storage", "animal_domestication":
			score += food_p * 2.0
		"basic_tools", "pottery":
			score += resource_p * 1.7
		"woodworking", "architecture":
			score += build_p * 2.0
		"metallurgy":
			score += defense_p * 1.9
		"writing", "philosophy":
			score += culture_p * 1.8
	
	# Deterministic tiny noise to avoid permanent ties across runs with identical pressures.
	var noise_seed: int = tick + (tech_id.length() * 131)
	score += float(posmod(_stable_hash_int(noise_seed, cost, int(score * 100.0)), 1000)) / 100000.0
	return score


func _estimate_research_pressures() -> Dictionary:
	var food_p: float = 0.35
	var defense_p: float = 0.25
	var build_p: float = 0.35
	var culture_p: float = 0.20
	var resource_p: float = 0.35
	if _world_ai != null and _world_ai.has_method("get_neural_network_summary"):
		var summary: Dictionary = _world_ai.get_neural_network_summary()
		var collapse: float = clampf(float(summary.get("collapse_risk", 0.3)), 0.0, 1.0)
		var econ: float = clampf(float(summary.get("economic_stability", 0.5)), 0.0, 1.0)
		var military: float = clampf(float(summary.get("military_strength", 0.4)), 0.0, 1.0)
		var innovation: float = clampf(float(summary.get("innovation_rate", 0.3)), 0.0, 1.0)
		food_p = clampf(0.20 + collapse * 0.6 + (1.0 - econ) * 0.5, 0.0, 1.0)
		defense_p = clampf(0.20 + collapse * 0.45 + (1.0 - military) * 0.4, 0.0, 1.0)
		build_p = clampf(0.20 + (1.0 - econ) * 0.5, 0.0, 1.0)
		culture_p = clampf(0.10 + innovation * 0.6 + float(get_completed_count()) * 0.03, 0.0, 1.0)
		resource_p = clampf(0.25 + (1.0 - econ) * 0.4, 0.0, 1.0)
	return {
		"food": food_p,
		"defense": defense_p,
		"construction": build_p,
		"culture": culture_p,
		"resources": resource_p,
	}


func _stable_hash_int(a: int, b: int, c: int) -> int:
	var h: int = 2166136261
	h = (h ^ (a & 0xFF)) * 16777619
	h = (h ^ ((a >> 8) & 0xFF)) * 16777619
	h = (h ^ (b & 0xFF)) * 16777619
	h = (h ^ ((b >> 8) & 0xFF)) * 16777619
	h = (h ^ (c & 0xFF)) * 16777619
	h = (h ^ ((c >> 8) & 0xFF)) * 16777619
	return h & 0x7fffffff


## Add research points from scholar pawns
func add_research_points(amount: int, researcher_pawn_id: int = -1) -> void:
	total_research_points += amount
	var assigned: bool = false
	
	# Auto-assign to researching technology
	for tech_id in research_progress:
		var tech: Dictionary = technologies[tech_id]
		if tech.status == "researching":
			research_progress[tech_id] += amount
			assigned = true
			
			# Record research progress event
			if _world_memory != null:
				_world_memory.record_event({
					"type": "research_progress",
					"tech_id": tech_id,
					"progress": research_progress[tech_id],
					"cost": tech.cost,
					"pawn_id": researcher_pawn_id,
					"tick": GameManager.tick_count
				})
			
			# Emit progress signal
			research_progressed.emit(tech_id, research_progress[tech_id], tech.cost)
			
			break
	if not assigned:
		_unallocated_research_points += amount


## Start researching a technology
func start_research(tech_id: String) -> bool:
	if not technologies.has(tech_id):
		return false
	
	var tech: Dictionary = technologies[tech_id]
	
	# Check prerequisites
	for prereq in tech.prerequisites:
		if technologies[prereq].status != "completed":
			return false  # Prerequisites not met
	
	if tech.status != "locked" and tech.status != "available":
		return false  # Already researching or completed
	
	# Cancel any current research
	for other_id in research_progress:
		if technologies[other_id].status == "researching":
			technologies[other_id].status = "available"
	
	tech.status = "researching"
	research_progress[tech_id] = 0
	if _unallocated_research_points > 0:
		research_progress[tech_id] += _unallocated_research_points
		_unallocated_research_points = 0
		research_progressed.emit(tech_id, research_progress[tech_id], tech.cost)
	
	# Emit signal
	research_started.emit(tech_id)
	
	if OS.is_debug_build():
		print("[Technology] Started researching: %s" % tech.name)
	
	return true


## Check if research is complete
func _check_research_completion(tick: int) -> void:
	for tech_id in research_progress:
		var tech: Dictionary = technologies[tech_id]
		if tech.status != "researching":
			continue
		
		if research_progress[tech_id] >= tech.cost:
			_complete_research(tech_id, tick)


func _complete_research(tech_id: String, tick: int) -> void:
	var tech: Dictionary = technologies[tech_id]
	tech.status = "completed"
	tech.researched_tick = tick
	
	# Apply unlock effects
	_apply_technology_unlock(tech)
	
	# Make dependent technologies available
	_make_dependent_technologies_available(tech_id)
	
	# Record completion event
	if _world_memory != null:
		_world_memory.record_event({
			"type": "technology_completed",
			"tech_id": tech_id,
			"tech_name": tech.name,
			"unlock_type": tech.unlock_type,
			"tick": tick
		})
	
	# Emit completion signal
	research_completed.emit(tech_id)
	
	if OS.is_debug_build():
		print("[Technology] Completed: %s (%s)" % [tech.name, tech.unlock_type])


func _apply_technology_unlock(tech: Dictionary) -> void:
	match tech.unlock_type:
		"building":
			# Buildings are unlocked globally for all settlements
			pass  # Building system checks technology before allowing construction
		
		"job":
			# Jobs become available in job pool
			pass  # Job system checks technology before posting
		
		"knowledge":
			# Knowledge type becomes available to learn
			if _knowledge_system != null and tech.unlock_data.has("knowledge"):
				# Mark knowledge as discoverable
				pass
		
		"upgrade":
			# Apply global upgrade
			if tech.unlock_data.has("work_speed_bonus"):
				# Apply work speed bonus to all pawns
				pass
			if tech.unlock_data.has("mood_bonus"):
				# Apply mood bonus to all pawns
				pass


func _make_dependent_technologies_available(completed_tech_id: String) -> void:
	for tech_id in technologies:
		var tech: Dictionary = technologies[tech_id]
		if tech.status == "locked" and completed_tech_id in tech.prerequisites:
			tech.status = "available"


# ==================== Public API ====================

## Get all technologies
func get_all_technologies() -> Dictionary:
	return technologies.duplicate()

## Get research progress for a technology
func get_research_progress(tech_id: String) -> int:
	return research_progress.get(tech_id, 0)

## Get available technologies (ready to research)
func get_available_technologies() -> Array:
	var available: Array = []
	for tech_id in technologies:
		var tech: Dictionary = technologies[tech_id]
		var status: String = str(tech.get("status", "locked"))
		if status == "available":
			available.append(tech_id)
		elif status == "locked" and _prerequisites_completed(tech):
			# Defensive fallback if status drifted before next sync.
			available.append(tech_id)
	return available

## Compatibility alias used by KnowledgeSystem.get_researchable_techs()
func get_available_research(_settlement_id: int = -1) -> Array:
	return get_available_technologies()

## Get current researching technology
func get_current_research() -> String:
	for tech_id in technologies:
		if technologies[tech_id].status == "researching":
			return tech_id
	return ""

## Check if a technology is completed
func is_technology_completed(tech_id: String) -> bool:
	if not technologies.has(tech_id):
		return false
	return technologies[tech_id].status == "completed"

## Compatibility function for settlement job validation
## TODO: Implement proper settlement job type checking
func can_settle_perform_job_type(_settlement_id: int, _job_type: int, _extra: int = 0) -> bool:
	return true  # Stub: always allow for now

## Get total technologies completed
func get_completed_count() -> int:
	var count: int = 0
	for tech in technologies.values():
		if tech.status == "completed":
			count += 1
	return count

## Get statistics
func get_stats() -> Dictionary:
	var stats: Dictionary = {
		"total_technologies": technologies.size(),
		"completed": get_completed_count(),
		"researching": 0,
		"available": 0,
		"locked": 0,
		"total_research_points": total_research_points,
		"unallocated_research_points": _unallocated_research_points,
		"auto_last_selected_tech": _last_auto_selected_tech,
		"auto_last_selected_tick": _last_auto_selected_tick,
	}
	
	for tech in technologies.values():
		match tech.status:
			"researching":
				stats.researching += 1
			"available":
				stats.available += 1
			"locked":
				stats.locked += 1
	
	return stats

## Debug: Complete all technologies (for testing)
func debug_complete_all() -> void:
	for tech_id in technologies:
		technologies[tech_id].status = "completed"
		research_progress[tech_id] = technologies[tech_id].cost
	print("[Technology] Debug: All technologies completed")

## Debug: Add research points
func debug_add_research(amount: int) -> void:
	add_research_points(amount, -1)
	print("[Technology] Debug: Added %d research points" % amount)
