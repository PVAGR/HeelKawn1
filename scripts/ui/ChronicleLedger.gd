class_name ChronicleLedger
extends CanvasLayer

## Tabbed ledger UI for displaying AI system data
## Shows personalities/memories, history/ruins, technology, and evolution stats

const REFRESH_EVERY_N_TICKS: int = 10
const REFRESH_EVERY_N_TICKS_FAST: int = 30
const REFRESH_EVERY_N_TICKS_ULTRA: int = 60

@onready var _panel: PanelContainer = $Panel
@onready var _tab_container: TabContainer = $Panel/Margin/VBox/TabContainer
@onready var _close_button: Button = $Panel/Margin/VBox/Header/CloseButton
@onready var _personalities_text: RichTextLabel = $Panel/Margin/VBox/TabContainer/Personalities/PersonalitiesContent/PersonalitiesScroll/PersonalitiesText
@onready var _history_text: RichTextLabel = $Panel/Margin/VBox/TabContainer/History/HistoryContent/HistoryScroll/HistoryText
@onready var _technology_text: RichTextLabel = $Panel/Margin/VBox/TabContainer/Technology/TechnologyContent/TechnologyScroll/TechnologyText
@onready var _evolution_text: RichTextLabel = $Panel/Margin/VBox/TabContainer/Evolution/EvolutionContent/EvolutionScroll/EvolutionText

var _spawner: PawnSpawner = null
var _visible: bool = false
var _last_refresh_tick: int = 0
var _hud_dirty: bool = true


func _ready() -> void:
	_panel.visible = false
	_close_button.pressed.connect(_toggle_visibility)
	GameManager.game_tick.connect(_on_tick)
	GameManager.speed_changed.connect(_on_speed_changed)
	_apply_panel_style()


func bind(spawner: PawnSpawner) -> void:
	_spawner = spawner
	_hud_dirty = true


func _toggle_visibility() -> void:
	_visible = not _visible
	_panel.visible = _visible
	if _visible:
		_hud_dirty = true
		_refresh()


func _on_tick(tick: int) -> void:
	if not _visible:
		return
	
	var refresh_stride: int = _refresh_stride_for_speed(GameManager.game_speed)
	if tick % refresh_stride == 0 or _hud_dirty:
		_refresh()
		_hud_dirty = false
		_last_refresh_tick = tick


func _on_speed_changed(_s: float, _p: bool) -> void:
	_hud_dirty = true


func _refresh_stride_for_speed(speed: float) -> int:
	if speed >= 100.0:
		return REFRESH_EVERY_N_TICKS_ULTRA
	if speed >= 50.0:
		return REFRESH_EVERY_N_TICKS_FAST
	return REFRESH_EVERY_N_TICKS


func _apply_panel_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.06, 0.08, 0.92)
	style.border_color = Color(0.85, 0.78, 0.40, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	_panel.add_theme_stylebox_override("panel", style)


func _refresh() -> void:
	_refresh_personalities_tab()
	_refresh_history_tab()
	_refresh_technology_tab()
	_refresh_evolution_tab()


func _refresh_personalities_tab() -> void:
	if _personalities_text == null or _spawner == null:
		return
	
	var lines: Array[String] = []
	lines.append("[b]=== PERSONALITIES & MEMORIES ===[/b]")
	lines.append("")
	
	var pawn_count: int = 0
	for pawn in _spawner.pawns:
		if not is_instance_valid(pawn) or pawn.data == null:
			continue
		pawn_count += 1
		var d: PawnData = pawn.data
		
		lines.append("[color=#dcb478][b]%s[/b] (ID %d)[/color]" % [d.display_name, d.id])
		lines.append("  [b]Personality:[/b]")
		lines.append("    Openness: %.2f" % d.openness)
		lines.append("    Conscientiousness: %.2f" % d.conscientiousness)
		lines.append("    Extraversion: %.2f" % d.extraversion)
		lines.append("    Agreeableness: %.2f" % d.agreeableness)
		lines.append("    Neuroticism: %.2f" % d.neuroticism)
		
		# Behavior modifiers
		lines.append("  [b]Behavior Modifiers:[/b]")
		lines.append("    Job Preference: %.2f" % d.get_job_preference_modifier("farming"))
		lines.append("    Social Propensity: %.2f" % d.get_social_propensity())
		lines.append("    Risk Tolerance: %.2f" % d.get_risk_tolerance())
		lines.append("    Learning Speed: %.2f" % d.get_learning_speed_modifier())
		lines.append("    Mood Stability: %.2f" % d.get_mood_stability())
		
		# Memory summary
		lines.append("  [b]Memories:[/b]")
		lines.append("    Episodic: %d entries" % d.episodic_memory.size())
		lines.append("    Semantic: %d facts" % d.semantic_memory.size())
		lines.append("    Spatial: %d locations" % d.spatial_memory.size())
		lines.append("    Social: %d relationships" % d.social_memory.size())
		
		# Goals
		lines.append("  [b]Active Goals:[/b]")
		if d.active_goals.is_empty():
			lines.append("    None")
		else:
			for goal_id in d.active_goals:
				var goal = d.active_goals[goal_id]
				lines.append("    %s (priority %.1f, progress %.0f%%)" % [goal.type, goal.priority, goal.progress * 100])
		
		# Need satisfaction
		lines.append("  [b]Need Satisfaction:[/b]")
		for need in d.need_satisfaction:
			lines.append("    %s: %.0f%%" % [need, d.need_satisfaction[need]])
		
		lines.append("")
	
	if pawn_count == 0:
		lines.append("[color=#888888]No pawns found.[/color]")
	
	_personalities_text.text = "\n".join(lines)


func _refresh_history_tab() -> void:
	if _history_text == null:
		return
	
	var lines: Array[String] = []
	lines.append("[b]=== HISTORY & RUINS ===[/b]")
	lines.append("")
	
	# Check if HistoricalSimulation is loaded
	if not has_node("/root/HistoricalSimulation"):
		lines.append("[color=#888888]HistoricalSimulation not loaded.[/color]")
		_history_text.text = "\n".join(lines)
		return
	
	var hist_sim: HistoricalSimulation = get_node("/root/HistoricalSimulation")
	
	# Time info
	lines.append("[b]Time Depth:[/b]")
	lines.append("  Historical ticks: %d" % hist_sim.historical_ticks)
	lines.append("  Years elapsed: %d" % hist_sim.years_elapsed)
	lines.append("")
	
	# Events
	lines.append("[b]Recent Events (last 10):[/b]")
	var recent_events: Array = hist_sim.historical_events.slice(max(0, hist_sim.historical_events.size() - 10))
	if recent_events.is_empty():
		lines.append("  None")
	else:
		for event in recent_events:
			var tick: int = event.get("tick", 0)
			var type: String = event.get("type", "unknown")
			lines.append("  [T%d] %s" % [tick, type])
	lines.append("")
	
	# Ruins
	lines.append("[b]Ruins (%d):[/b]" % hist_sim.ruins.size())
	var ruin_count: int = 0
	for ruin_id in hist_sim.ruins:
		if ruin_count >= 10:
			lines.append("  ... and %d more" % (hist_sim.ruins.size() - 10))
			break
		var ruin = hist_sim.ruins[ruin_id]
		lines.append("  %s at %s (age: %d, decay: %.0f%%)" % [
			ruin.get("original_settlement", "Unknown"),
			str(ruin.get("location", Vector2i.ZERO)),
			ruin.get("age", 0),
			ruin.get("decay_state", 0.0) * 100
		])
		ruin_count += 1
	lines.append("")
	
	# Artifacts
	lines.append("[b]Artifacts (%d):[/b]" % hist_sim.artifacts.size())
	var artifact_count: int = 0
	for artifact_id in hist_sim.artifacts:
		if artifact_count >= 10:
			lines.append("  ... and %d more" % (hist_sim.artifacts.size() - 10))
			break
		var artifact = hist_sim.artifacts[artifact_id]
		lines.append("  %s at %s (power: %.2f)" % [
			artifact.get("type", "unknown"),
			str(artifact.get("location", Vector2i.ZERO)),
			artifact.get("power", 0.0)
		])
		artifact_count += 1
	lines.append("")
	
	# Myths
	lines.append("[b]Prominent Myths (belief > 0.5):[/b]")
	var prominent_myths: Array = hist_sim.get_prominent_myths(0.5)
	if prominent_myths.is_empty():
		lines.append("  None")
	else:
		for myth_data in prominent_myths:
			var myth = myth_data.myth
			lines.append("  %s (belief: %.2f)" % [myth.get("name", "Unknown"), myth.get("belief_level", 0.0)])
	
	_history_text.text = "\n".join(lines)


func _refresh_technology_tab() -> void:
	if _technology_text == null:
		return
	
	var lines: Array[String] = []
	lines.append("[b]=== TECHNOLOGY TREE ===[/b]")
	lines.append("")
	
	# Check if TechnologySystem is loaded
	if not has_node("/root/TechnologySystem"):
		lines.append("[color=#888888]TechnologySystem not loaded.[/color]")
		_technology_text.text = "\n".join(lines)
		return
	
	var tech_sys: TechnologySystem = get_node("/root/TechnologySystem")
	
	# Discovered technologies
	lines.append("[b]Discovered Technologies (%d):[/b]" % tech_sys.knowledge_graph.size())
	var tech_count: int = 0
	for tech_id in tech_sys.knowledge_graph:
		if tech_count >= 20:
			lines.append("  ... and %d more" % (tech_sys.knowledge_graph.size() - 20))
			break
		var tech = tech_sys.knowledge_graph[tech_id]
		if tech.get("discovered", false):
			lines.append("  %s" % tech.get("name", tech_id))
			tech_count += 1
	lines.append("")
	
	# Hidden nodes
	lines.append("[b]Undiscovered Technologies (%d):[/b]" % tech_sys.hidden_nodes.size())
	lines.append("")
	
	# Active research
	lines.append("[b]Active Research (%d):[/b]" % tech_sys.active_research.size())
	if tech_sys.active_research.is_empty():
		lines.append("  None")
	else:
		for settlement_id in tech_sys.active_research:
			var research = tech_sys.active_research[settlement_id]
			lines.append("  Settlement %d: %s (%.0f%%)" % [
				settlement_id,
				research.tech_id,
				research.progress
			])
	lines.append("")
	
	# Innovations
	lines.append("[b]Innovations (%d):[/b]" % tech_sys.innovations.size())
	if tech_sys.innovations.is_empty():
		lines.append("  None")
	else:
		for innovation in tech_sys.innovations:
			lines.append("  %s from %s" % [innovation.tech_id, str(innovation.parent_techs)])
	lines.append("")
	
	# Innovation candidates
	lines.append("[b]Innovation Candidates (%d):[/b]" % tech_sys.innovation_candidates.size())
	if tech_sys.innovation_candidates.is_empty():
		lines.append("  None")
	else:
		for candidate in tech_sys.innovation_candidates:
			lines.append("  Potential: %.2f from %s" % [candidate.potential, str(candidate.parent_techs)])
	
	_technology_text.text = "\n".join(lines)


func _refresh_evolution_tab() -> void:
	if _evolution_text == null:
		return
	
	var lines: Array[String] = []
	lines.append("[b]=== GENETIC EVOLUTION ===[/b]")
	lines.append("")
	
	# Check if GeneticEvolution is loaded
	if not has_node("/root/GeneticEvolution"):
		lines.append("[color=#888888]GeneticEvolution not loaded.[/color]")
		_evolution_text.text = "\n".join(lines)
		return
	
	var gen_evo: GeneticEvolution = get_node("/root/GeneticEvolution")
	
	# Population stats
	lines.append("[b]Population Stats:[/b]")
	lines.append("  Population size: %d" % gen_evo.population_size)
	lines.append("  Current generation: %d" % gen_evo.current_generation)
	lines.append("  Mutation rate: %.3f" % gen_evo.mutation_rate)
	lines.append("  Crossover rate: %.3f" % gen_evo.crossover_rate)
	lines.append("  Elite count: %d" % gen_evo.elite_count)
	lines.append("")
	
	# Fitness stats
	var stats: Dictionary = gen_evo.get_fitness_stats()
	lines.append("[b]Fitness Stats (Generation %d):[/b]" % gen_evo.current_generation)
	lines.append("  Min: %.3f" % stats.get("min", 0.0))
	lines.append("  Max: %.3f" % stats.get("max", 0.0))
	lines.append("  Average: %.3f" % stats.get("average", 0.0))
	lines.append("  Median: %.3f" % stats.get("median", 0.0))
	lines.append("")
	
	# Best individual
	lines.append("[b]Best Individual:[/b]")
	var best = gen_evo.get_best_individual()
	if best.is_empty():
		lines.append("  None")
	else:
		lines.append("  Fitness: %.3f" % best.get("fitness", 0.0))
		lines.append("  Generation: %d" % best.get("generation", 0))
		var personality = best.get("personality", {})
		if not personality.is_empty():
			lines.append("  Personality:")
			lines.append("    Openness: %.2f" % personality.get("openness", 0.5))
			lines.append("    Conscientiousness: %.2f" % personality.get("conscientiousness", 0.5))
			lines.append("    Extraversion: %.2f" % personality.get("extraversion", 0.5))
			lines.append("    Agreeableness: %.2f" % personality.get("agreeableness", 0.5))
			lines.append("    Neuroticism: %.2f" % personality.get("neuroticism", 0.5))
	lines.append("")
	
	# Fitness history
	lines.append("[b]Fitness History (last 10 generations):[/b]")
	var history: Array = gen_evo.fitness_history.slice(max(0, gen_evo.fitness_history.size() - 10))
	if history.is_empty():
		lines.append("  None")
	else:
		for entry in history:
			lines.append("  Gen %d: avg %.3f, best %.3f" % [
				entry.get("generation", 0),
				entry.get("average_fitness", 0.0),
				entry.get("best_fitness", 0.0)
			])
	
	_evolution_text.text = "\n".join(lines)
