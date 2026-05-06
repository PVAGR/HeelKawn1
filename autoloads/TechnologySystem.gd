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

# Signals for Main.gd to connect to
signal research_started(tech_id: String)
signal research_progressed(tech_id: String, progress: int, cost: int)
signal research_completed(tech_id: String)

# References
@onready var _world_memory: Node = null
@onready var _settlement_memory: Node = null
@onready var _knowledge_system: Node = null


func _ready() -> void:
	GameManager.game_tick.connect(_on_game_tick)
	_world_memory = get_node_or_null("/root/WorldMemory")
	_settlement_memory = get_node_or_null("/root/SettlementMemory")
	_knowledge_system = get_node_or_null("/root/KnowledgeSystem")
	
	# Initialize technology tree
	_initialize_technologies()


func _on_game_tick(tick: int) -> void:
	# Check for completed research
	_check_research_completion(tick)


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


## Add research points from scholar pawns
func add_research_points(amount: int, researcher_pawn_id: int = -1) -> void:
	total_research_points += amount
	
	# Auto-assign to researching technology
	for tech_id in research_progress:
		var tech: Dictionary = technologies[tech_id]
		if tech.status == "researching":
			research_progress[tech_id] += amount
			
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
		if technologies[tech_id].status == "available":
			available.append(tech_id)
	return available

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
func can_settle_perform_job_type(_settlement_id: int, _job_type: String) -> bool:
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
		"total_research_points": total_research_points
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
