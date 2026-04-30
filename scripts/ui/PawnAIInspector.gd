class_name PawnAIInspector
extends CanvasLayer

## Detailed panel showing selected pawn's complete AI state
## Displays personality, memories, goals, neural network, and utility decisions

const REFRESH_EVERY_N_TICKS: int = 5
const REFRESH_EVERY_N_TICKS_FAST: int = 20

@onready var _panel: PanelContainer = $Panel
@onready var _close_button: Button = $Panel/Margin/VBox/Header/CloseButton
@onready var _content: RichTextLabel = $Panel/Margin/VBox/Scroll/Content

var _selected_pawn: Pawn = null
var _visible: bool = false
var _last_refresh_tick: int = 0
var _hud_dirty: bool = true


func _ready() -> void:
	_panel.visible = false
	_close_button.pressed.connect(_toggle_visibility)
	GameManager.game_tick.connect(_on_tick)
	GameManager.speed_changed.connect(_on_speed_changed)
	_apply_panel_style()


func set_selected_pawn(pawn: Pawn) -> void:
	_selected_pawn = pawn
	_hud_dirty = true
	if _visible:
		_refresh()


func _toggle_visibility() -> void:
	_visible = not _visible
	_panel.visible = _visible
	if _visible:
		_hud_dirty = true
		_refresh()


func _on_tick(tick: int) -> void:
	if not _visible or _selected_pawn == null:
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
	if _content == null or _selected_pawn == null or not is_instance_valid(_selected_pawn):
		_content.text = "[color=#888888]No pawn selected.[/color]"
		return
	
	var d: PawnData = _selected_pawn.data
	if d == null:
		_content.text = "[color=#888888]Pawn data not available.[/color]"
		return
	
	var lines: Array[String] = []
	
	# Header
	lines.append("[b]=== %s (ID %d) ===[/b]" % [d.display_name, d.id])
	lines.append("Age: %.1f · Profession: %s" % [d.age, d.profession_name()])
	lines.append("")
	
	# Personality
	lines.append("[b]--- PERSONALITY (Big Five) ---[/b]")
	lines.append("Openness: [color=%s]%.2f[/color] %s" % [_trait_color(d.openness), d.openness, _trait_desc(d.openness)])
	lines.append("Conscientiousness: [color=%s]%.2f[/color] %s" % [_trait_color(d.conscientiousness), d.conscientiousness, _trait_desc(d.conscientiousness)])
	lines.append("Extraversion: [color=%s]%.2f[/color] %s" % [_trait_color(d.extraversion), d.extraversion, _trait_desc(d.extraversion)])
	lines.append("Agreeableness: [color=%s]%.2f[/color] %s" % [_trait_color(d.agreeableness), d.agreeableness, _trait_desc(d.agreeableness)])
	lines.append("Neuroticism: [color=%s]%.2f[/color] %s" % [_trait_color(d.neuroticism), d.neuroticism, _trait_desc(d.neuroticism)])
	lines.append("")
	
	# Behavior modifiers
	lines.append("[b]--- BEHAVIOR MODIFIERS ---[/b]")
	lines.append("Job Preference (farming): %.2f" % d.get_job_preference_modifier("farming"))
	lines.append("Social Propensity: %.2f" % d.get_social_propensity())
	lines.append("Risk Tolerance: %.2f" % d.get_risk_tolerance())
	lines.append("Learning Speed: %.2f" % d.get_learning_speed_modifier())
	lines.append("Mood Stability: %.2f" % d.get_mood_stability())
	lines.append("")
	
	# Needs
	lines.append("[b]--- NEED SATISFACTION ---[/b]")
	for need in d.need_satisfaction:
		var sat: float = d.need_satisfaction[need]
		lines.append("%s: [color=%s]%.0f%%[/color]" % [need.capitalize(), _need_color(sat), sat * 100])
	lines.append("")
	
	# Goals
	lines.append("[b]--- ACTIVE GOALS ---[/b]")
	if d.active_goals.is_empty():
		lines.append("[color=#888888]No active goals.[/color]")
	else:
		for goal_id in d.active_goals:
			var goal = d.active_goals[goal_id]
			lines.append("%s (priority: %.1f, progress: %.0f%%)" % [
				goal.type.capitalize(),
				goal.priority,
				goal.progress * 100
			])
	lines.append("")
	
	# Memories
	lines.append("[b]--- MEMORIES ---[/b]")
	lines.append("Episodic: %d entries" % d.episodic_memory.size())
	lines.append("Semantic: %d facts" % d.semantic_memory.size())
	lines.append("Spatial: %d locations" % d.spatial_memory.size())
	lines.append("Social: %d relationships" % d.social_memory.size())
	
	# Recent episodic memories
	if not d.episodic_memory.is_empty():
		lines.append("")
		lines.append("[b]Recent Episodic Memories (last 5):[/b]")
		var memory_keys: Array = d.episodic_memory.keys()
		memory_keys.sort_custom(func(a, b): return int(d.episodic_memory[b].get("tick", 0)) - int(d.episodic_memory[a].get("tick", 0)))
		var count: int = 0
		for key in memory_keys:
			if count >= 5:
				break
			var mem = d.episodic_memory[key]
			var tick: int = mem.get("tick", 0)
			var type: String = mem.get("type", "unknown")
			lines.append("  [T%d] %s" % [tick, type])
			count += 1
	lines.append("")
	
	# Neural Network
	if d.neural_network != null:
		lines.append("[b]--- NEURAL NETWORK ---[/b]")
		lines.append("Layers: %d" % d.neural_network.layers.size())
		lines.append("Connections: %d" % d.neural_network.connections.size())
		lines.append("Learning Rate: %.4f" % d.neural_network.learning_rate)
		lines.append("Evolution Generation: %d" % d.neural_network.evolution_generation)
		lines.append("")
	
	# Recent utility decisions
	lines.append("[b]--- RECENT DECISION FACTORS ---[/b]")
	if d.decision_history.is_empty():
		lines.append("[color=#888888]No decisions recorded yet.[/color]")
	else:
		var recent_decisions = d.decision_history.slice(max(0, d.decision_history.size() - 5))
		for decision in recent_decisions:
			var action: String = decision.get("action", "unknown")
			var utility: float = decision.get("utility", 0.0)
			var factors: Dictionary = decision.get("factors", {})
			lines.append("Action: %s (utility: %.2f)" % [action, utility])
			for factor_name in factors:
				lines.append("  %s: %.2f" % [factor_name, factors[factor_name]])
	
	_content.text = "\n".join(lines)


func _trait_color(value: float) -> String:
	if value < 0.3:
		return "#e57373"  # Low - red
	elif value < 0.7:
		return "#ffd54f"  # Medium - yellow
	return "#81c784"  # High - green


func _trait_desc(value: float) -> String:
	if value < 0.3:
		return "(low)"
	elif value < 0.7:
		return "(moderate)"
	return "(high)"


func _need_color(value: float) -> String:
	if value < 0.3:
		return "#e57373"  # Critical - red
	elif value < 0.6:
		return "#ffd54f"  # Warning - yellow
	return "#81c784"  # Good - green
