extends Node
## Phase 5: Infinite Technology Tree and Knowledge Discovery
## Knowledge graph system, research system, technology diffusion, innovation system

## Knowledge graph: technologies as nodes with prerequisites
var knowledge_graph: Dictionary = {}  # tech_id -> {name, description, prerequisites, discovered, discovery_tick, discoverer}
var hidden_nodes: Array = []  # Undiscovered technologies waiting to be found

## Research tracking
var active_research: Dictionary = {}  # settlement_id -> {tech_id, progress, researchers, resources}
var research_history: Array = []  # {tech_id, settlement_id, tick, success}

## Technology diffusion
var tech_diffusion: Dictionary = {}  # tech_id -> {known_by: [settlement_ids], diffusion_rate}
var cultural_secrets: Dictionary = {}  # tech_id -> {holding_settlements, secrecy_level}

## Innovation system
var innovations: Array = []  # {tech_id, parent_techs, innovation_tick, innovator_settlement}
var innovation_candidates: Array = []  # Potential new tech combinations

## Base technologies (always available)
var base_technologies: Array = [
	"stone_tools",
	"fire",
	"shelter",
	"foraging",
	"basic_clothing"
]

func _ready() -> void:
	_initialize_knowledge_graph()
	_generate_hidden_nodes()


## Initialize knowledge graph with base technologies
func _initialize_knowledge_graph() -> void:
	for tech_id in base_technologies:
		knowledge_graph[tech_id] = {
			"name": _format_tech_name(tech_id),
			"description": _generate_tech_description(tech_id),
			"prerequisites": [],
			"discovered": true,
			"discovery_tick": 0,
			"discoverer": "ancient_knowledge"
		}
		
		# Initialize diffusion
		tech_diffusion[tech_id] = {
			"known_by": [],
			"diffusion_rate": 0.01
		}


## Generate hidden technology nodes
func _generate_hidden_nodes() -> void:
	# Generate a pool of potential technologies
	var tech_categories: Array = ["tools", "agriculture", "construction", "crafting", "warfare", "medicine", "magic", "exploration"]
	
	for category in tech_categories:
		for i in range(20):  # 20 potential techs per category
			var tech_id: String = "%s_%d" % [category, i]
			var prerequisites: Array = _generate_prerequisites(tech_id, category)
			
			hidden_nodes.append({
				"tech_id": tech_id,
				"name": _generate_procedural_name(category),
				"description": _generate_procedural_description(category),
				"prerequisites": prerequisites,
				"category": category
			})


## Generate prerequisites for a technology
func _generate_prerequisites(tech_id: String, category: String) -> Array:
	var prerequisites: Array = []
	var num_prereqs: int = WorldRNG.rangei(1, 3)
	
	# Sometimes require base technologies
	if WorldRNG.range_for(StringName("tech:prereq_base:%s" % tech_id), 0.0, 1.0) < 0.3:
		prerequisites.append(base_technologies[WorldRNG.rangei(0, base_technologies.size() - 1)])
	
	# Generate procedural prerequisites
	for i in range(num_prereqs):
		var prereq_category: String = _get_related_category(category)
		var prereq_id: String = "%s_%d" % [prereq_category, WorldRNG.rangei(0, 19)]
		prerequisites.append(prereq_id)
	
	return prerequisites


## Get related category for prerequisites
func _get_related_category(category: String) -> String:
	var relations: Dictionary = {
		"tools": ["crafting", "construction"],
		"agriculture": ["tools", "construction"],
		"construction": ["tools", "crafting"],
		"crafting": ["tools", "agriculture"],
		"warfare": ["tools", "crafting"],
		"medicine": ["crafting", "agriculture"],
		"magic": ["medicine", "exploration"],
		"exploration": ["tools", "construction"]
	}
	
	var related: Array = relations.get(category, ["tools"])
	return related[WorldRNG.rangei(0, related.size() - 1)]


## Start research on a technology
func start_research(settlement_id: int, tech_id: String, researchers: Array, resources: Dictionary) -> bool:
	# Check if tech exists or is hidden
	var tech_data: Dictionary = _get_tech_data(tech_id)
	if tech_data.is_empty():
		return false
	
	# Check if already discovered
	if tech_data.get("discovered", false):
		return false
	
	# Check prerequisites
	var prerequisites: Array = tech_data.get("prerequisites", [])
	for prereq in prerequisites:
		if not _is_tech_discovered(prereq):
			return false
	
	# Start research
	active_research[settlement_id] = {
		"tech_id": tech_id,
		"progress": 0.0,
		"researchers": researchers,
		"resources": resources,
		"start_tick": GameManager.tick_count if GameManager != null else 0
	}
	
	return true


## Update research progress
func update_research() -> void:
	var to_complete: Array = []
	
	for settlement_id in active_research:
		var research = active_research[settlement_id]
		
		# Calculate progress based on researchers and resources
		var researcher_count: int = research.researchers.size()
		var resource_bonus: float = research.resources.get("bonus", 0.0)
		var progress_increment: float = (researcher_count * 0.01) + resource_bonus
		
		research.progress = clamp(research.progress + progress_increment, 0.0, 100.0)
		
		# Check for completion
		if research.progress >= 100.0:
			to_complete.append(settlement_id)
	
	# Complete research
	for settlement_id in to_complete:
		_complete_research(settlement_id)


## Complete research
func _complete_research(settlement_id: int) -> void:
	var research = active_research[settlement_id]
	var tech_id: String = research.tech_id
	
	# Discover technology
	_discover_technology(tech_id, settlement_id)
	
	# Record in history
	research_history.append({
		"tech_id": tech_id,
		"settlement_id": settlement_id,
		"tick": GameManager.tick_count if GameManager != null else 0,
		"success": true
	})
	
	# Remove from active research
	active_research.erase(settlement_id)
	
	# Generate innovation candidates
	_generate_innovation_candidates(tech_id)


## Discover a technology
func _discover_technology(tech_id: String, discoverer: int) -> void:
	var tech_data: Dictionary = _get_tech_data(tech_id)
	if tech_data.is_empty():
		return
	
	# Move from hidden to discovered if needed
	if not knowledge_graph.has(tech_id):
		var hidden_index: int = -1
		for i in range(hidden_nodes.size()):
			if hidden_nodes[i].tech_id == tech_id:
				hidden_index = i
				break
		
		if hidden_index >= 0:
			var hidden_data = hidden_nodes[hidden_index]
			knowledge_graph[tech_id] = {
				"name": hidden_data.name,
				"description": hidden_data.description,
				"prerequisites": hidden_data.prerequisites,
				"discovered": true,
				"discovery_tick": GameManager.tick_count if GameManager != null else 0,
				"discoverer": str(discoverer)
			}
			hidden_nodes.remove_at(hidden_index)
	else:
		knowledge_graph[tech_id].discovered = true
		knowledge_graph[tech_id].discovery_tick = GameManager.tick_count if GameManager != null else 0
		knowledge_graph[tech_id].discoverer = str(discoverer)
	
	# Initialize diffusion
	if not tech_diffusion.has(tech_id):
		tech_diffusion[tech_id] = {
			"known_by": [discoverer],
			"diffusion_rate": 0.01
		}
	else:
		if not discoverer in tech_diffusion[tech_id].known_by:
			tech_diffusion[tech_id].known_by.append(discoverer)


## Check if technology is discovered
func _is_tech_discovered(tech_id: String) -> bool:
	if knowledge_graph.has(tech_id):
		return knowledge_graph[tech_id].get("discovered", false)
	return false


## Get technology data (from graph or hidden nodes)
func _get_tech_data(tech_id: String) -> Dictionary:
	if knowledge_graph.has(tech_id):
		return knowledge_graph[tech_id]
	
	for hidden in hidden_nodes:
		if hidden.tech_id == tech_id:
			return hidden
	
	return {}


## Generate innovation candidates based on newly discovered tech
func _generate_innovation_candidates(new_tech_id: String) -> void:
	# Find combinations with existing techs
	for existing_tech_id in knowledge_graph:
		if existing_tech_id == new_tech_id:
			continue
		
		if knowledge_graph[existing_tech_id].discovered:
			# Potential innovation from combining these
			var innovation_chance: float = WorldRNG.range_for(StringName("tech:innov:%s_%s" % [new_tech_id, existing_tech_id]), 0.0, 1.0)
			
			if innovation_chance < 0.1:  # 10% chance of innovation candidate
				innovation_candidates.append({
					"parent_techs": [new_tech_id, existing_tech_id],
					"category": _determine_innovation_category(new_tech_id, existing_tech_id),
					"potential": WorldRNG.range_for(StringName("tech:innov_pot:%s_%s" % [new_tech_id, existing_tech_id]), 0.0, 1.0)
				})


## Determine innovation category from parent techs
func _determine_innovation_category(tech1: String, tech2: String) -> String:
	var categories: Array = ["tools", "agriculture", "construction", "crafting", "warfare", "medicine", "magic", "exploration"]
	
	# Extract category from tech IDs
	var cat1: String = tech1.split("_")[0] if "_" in tech1 else "tools"
	var cat2: String = tech2.split("_")[0] if "_" in tech2 else "tools"
	
	# Return blended category or random
	if cat1 == cat2:
		return cat1
	
	# Return one of the parent categories
	return cat1 if WorldRNG.range_for(StringName("tech:innov_cat:%s_%s" % [tech1, tech2]), 0.0, 1.0) < 0.5 else cat2


## Attempt innovation
func attempt_innovation(settlement_id: int) -> String:
	if innovation_candidates.is_empty():
		return ""
	
	# Select highest potential candidate
	innovation_candidates.sort_custom(func(a, b): return a.potential > b.potential)
	var candidate = innovation_candidates[0]
	
	# Innovation success based on potential and randomness
	var success_chance: float = candidate.potential * 0.3
	if WorldRNG.range_for(StringName("tech:innov_success:%d" % (GameManager.tick_count if GameManager != null else 0)), 0.0, 1.0) < success_chance:
		# Create new technology
		var new_tech_id: String = "innovation_%d" % innovations.size()
		var tech_name: String = _generate_procedural_name(candidate.category)
		
		knowledge_graph[new_tech_id] = {
			"name": tech_name,
			"description": "An innovative technology combining %s and %s" % [candidate.parent_techs[0], candidate.parent_techs[1]],
			"prerequisites": candidate.parent_techs,
			"discovered": true,
			"discovery_tick": GameManager.tick_count if GameManager != null else 0,
			"discoverer": str(settlement_id)
		}
		
		innovations.append({
			"tech_id": new_tech_id,
			"parent_techs": candidate.parent_techs,
			"innovation_tick": GameManager.tick_count if GameManager != null else 0,
			"innovator_settlement": settlement_id
		})
		
		# Remove from candidates
		innovation_candidates.remove_at(0)
		
		return new_tech_id
	
	return ""


## Diffuse technology between settlements
func diffuse_technologies() -> void:
	for tech_id in tech_diffusion:
		var diffusion = tech_diffusion[tech_id]
		
		# Skip if this is a secret
		if cultural_secrets.has(tech_id):
			continue
		
		# Spread to nearby settlements
		var known_by: Array = diffusion.known_by.duplicate()
		
		for known_settlement in known_by:
			# Find neighboring settlements
			var neighbors: Array = _get_neighboring_settlements(known_settlement)
			
			for neighbor in neighbors:
				if not neighbor in diffusion.known_by:
					# Chance to learn based on diffusion rate
					if WorldRNG.range_for(StringName("tech:diffuse:%s_%d" % [tech_id, neighbor]), 0.0, 1.0) < diffusion.diffusion_rate:
						diffusion.known_by.append(neighbor)


## Other settlements as diffusion peers (real [SettlementMemory] centers, not random IDs).
## Geographic adjacency graph is future work; v1 spreads among coexisting places.
func _get_neighboring_settlements(settlement_center_or_index: int) -> Array:
	var neighbors: Array = []
	if SettlementMemory == null:
		return neighbors
	var centers: Array[int] = []
	for st_any in SettlementMemory.settlements:
		if not (st_any is Dictionary):
			continue
		var c: int = int((st_any as Dictionary).get("center_region", -1))
		if c < 0:
			continue
		if c == settlement_center_or_index:
			continue
		if not c in centers:
			centers.append(c)
	centers.sort()
	if centers.is_empty():
		return neighbors
	var salt: int = settlement_center_or_index * 1009 + WorldRNG.current_seed()
	var start: int = posmod(salt, centers.size())
	var want: int = mini(3, centers.size())
	for k in range(want):
		var pick: int = int(centers[(start + k) % centers.size()])
		if not pick in neighbors:
			neighbors.append(pick)
	return neighbors


## Set technology as cultural secret
func set_cultural_secret(tech_id: String, settlement_id: int, secrecy_level: float = 0.8) -> void:
	cultural_secrets[tech_id] = {
		"holding_settlements": [settlement_id],
		"secrecy_level": secrecy_level
	}


## Get available technologies for research
func get_available_research(settlement_id: int) -> Array:
	var available: Array = []
	
	# Check discovered techs for undiscovered dependents
	for tech_id in knowledge_graph:
		if knowledge_graph[tech_id].discovered:
			# Find techs that have this as prerequisite
			for hidden in hidden_nodes:
				if tech_id in hidden.prerequisites:
					# Check if all prerequisites are met
					var all_prereqs_met: bool = true
					for prereq in hidden.prerequisites:
						if not _is_tech_discovered(prereq):
							all_prereqs_met = false
							break
					
					if all_prereqs_met:
						available.append({
							"tech_id": hidden.tech_id,
							"name": hidden.name,
							"description": hidden.description,
							"category": hidden.category
						})
	
	return available


## Get discovered technologies
func get_discovered_technologies() -> Array:
	var discovered: Array = []
	
	for tech_id in knowledge_graph:
		if knowledge_graph[tech_id].discovered:
			discovered.append({
				"tech_id": tech_id,
				"name": knowledge_graph[tech_id].name,
				"description": knowledge_graph[tech_id].description,
				"discovery_tick": knowledge_graph[tech_id].discovery_tick
			})
	
	return discovered


## Helper: Format tech name
func _format_tech_name(tech_id: String) -> String:
	return tech_id.replace("_", " ").capitalize()


## Helper: Generate procedural name
func _generate_procedural_name(category: String) -> String:
	var prefixes: Dictionary = {
		"tools": ["Advanced", "Improved", "Masterwork", "Precision"],
		"agriculture": ["Irrigated", "Fertilized", "Rotational", "Domesticated"],
		"construction": ["Reinforced", "Multi-story", "Fortified", "Architectural"],
		"crafting": ["Artisan", "Fine", "Decorated", "Enchanted"],
		"warfare": ["Tactical", "Siege", "Heavy", "Elite"],
		"medicine": ["Herbal", "Surgical", "Preventative", "Restorative"],
		"magic": ["Arcane", "Divine", "Elemental", "Ritual"],
		"exploration": ["Deep", "Long-range", "Expeditionary", "Navigational"]
	}
	
	var nouns: Dictionary = {
		"tools": ["implements", "mechanisms", "devices", "instruments"],
		"agriculture": ["farming", "cultivation", "harvesting", "husbandry"],
		"construction": ["architecture", "engineering", "masonry", "carpentry"],
		"crafting": ["smithing", "weaving", "pottery", "jewelry"],
		"warfare": ["tactics", "weaponry", "armor", "siegecraft"],
		"medicine": ["remedies", "treatments", "diagnostics", "surgery"],
		"magic": ["enchantments", "rituals", "spells", "conjurations"],
		"exploration": ["mapping", "navigation", "cartography", "surveying"]
	}
	
	var category_prefixes: Array = prefixes.get(category, ["Advanced"])
	var category_nouns: Array = nouns.get(category, ["techniques"])
	
	return "%s %s" % [category_prefixes[WorldRNG.rangei(0, category_prefixes.size() - 1)], category_nouns[WorldRNG.rangei(0, category_nouns.size() - 1)]]


## Helper: Generate procedural description
func _generate_procedural_description(category: String) -> String:
	var descriptions: Array = [
		"A significant advancement in %s",
		"An innovative approach to %s",
		"A revolutionary technique for %s",
		"A refined method of %s"
	]
	
	return descriptions[WorldRNG.rangei(0, descriptions.size() - 1)] % category


## Helper: Generate tech description
func _generate_tech_description(tech_id: String) -> String:
	match tech_id:
		"stone_tools":
			return "Basic tools made from stone for cutting and shaping"
		"fire":
			return "The controlled use of fire for warmth and cooking"
		"shelter":
			return "Basic structures for protection from the elements"
		"foraging":
			return "Knowledge of edible plants and gathering techniques"
		"basic_clothing":
			return "Simple garments made from available materials"
		_:
			return "A technology related to %s" % tech_id


## Save technology state
func to_dict() -> Dictionary:
	return {
		"knowledge_graph": knowledge_graph,
		"hidden_nodes": hidden_nodes,
		"active_research": active_research,
		"research_history": research_history,
		"tech_diffusion": tech_diffusion,
		"cultural_secrets": cultural_secrets,
		"innovations": innovations,
		"innovation_candidates": innovation_candidates
	}


## Load technology state
func from_dict(data: Dictionary) -> void:
	knowledge_graph = data.get("knowledge_graph", {})
	hidden_nodes = data.get("hidden_nodes", [])
	active_research = data.get("active_research", {})
	research_history = data.get("research_history", [])
	tech_diffusion = data.get("tech_diffusion", {})
	cultural_secrets = data.get("cultural_secrets", {})
	innovations = data.get("innovations", [])
	innovation_candidates = data.get("innovation_candidates", [])
