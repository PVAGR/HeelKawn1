class_name PawnAIInspector
extends CanvasLayer

## Detailed panel showing selected pawn's complete AI state
## Displays personality, memories, goals, neural network, and utility decisions

const REFRESH_EVERY_N_TICKS: int = 5
const REFRESH_EVERY_N_TICKS_FAST: int = 20

@onready var _panel: PanelContainer = $Panel
@onready var _close_button: Button = $Panel/Margin/VBox/Header/CloseButton
@onready var _content: RichTextLabel = $Panel/Margin/VBox/Scroll/Content

var _selected_pawn: HeelKawnian = null
var _visible: bool = false
var _last_refresh_tick: int = 0
var _hud_dirty: bool = true


func _ready() -> void:
	_panel.visible = false
	_close_button.pressed.connect(_toggle_visibility)
	GameManager.game_tick.connect(_on_tick)
	GameManager.speed_changed.connect(_on_speed_changed)
	_apply_panel_style()


func set_selected_pawn(pawn: HeelKawnian) -> void:
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


func _settlement_state_color(state: String) -> String:
	match state:
		"active":
			return "#66bb6a"
		"reviving", "revivable":
			return "#ffd166"
		"abandoned", "recovering":
			return "#b0bec5"
		"permanent_ruin", "permanently_abandoned":
			return "#ef5350"
		_:
			return "#aaaaaa"


func _refresh() -> void:
	if _content == null or _selected_pawn == null or not is_instance_valid(_selected_pawn):
		_content.text = "[color=#888888]No pawn selected.[/color]"
		return
	
	var d: HeelKawnianData = _selected_pawn.data
	if d == null:
		_content.text = "[color=#888888]HeelKawnian data not available.[/color]"
		return
	
	var lines: Array[String] = []
	
	# Header
	lines.append("[b]=== %s (ID %d) ===[/b]" % [d.display_name, d.id])
	lines.append("Age: %.1f · Profession: %s" % [d.age, d.profession_name()])

	# Settlement mind
	var st_rk: int = WorldMemory._region_key(d.tile_pos.x, d.tile_pos.y) if WorldMemory != null else -1
	var st_sm: Node = get_node_or_null("/root/SettlementMemory")
	if st_sm != null:
		var st_center: int = st_sm.get_center_region_for_region(st_rk) if st_sm.has_method("get_center_region_for_region") else -1
		if st_center >= 0:
			var st_state: String = st_sm.get_state_at_region(st_center) if st_sm.has_method("get_state_at_region") else "unknown"
			var st_profile: Dictionary = st_sm.get_settlement_profile(st_center) if st_sm.has_method("get_settlement_profile") else {}
			var st_name: String = str(st_profile.get("name", st_profile.get("settlement_name", "Settlement")))
			lines.append("Settlement: [color=#66bb6a]%s[/color] ([color=%s]%s[/color])" % [st_name, _settlement_state_color(st_state), st_state])
			var woai: Node = get_node_or_null("/root/WorldAI")
			if woai != null:
				var active_settlements_v: Variant = woai.get("active_settlements")
				var sai = active_settlements_v.get(st_center) if active_settlements_v is Dictionary else null
				if sai != null:
					var gov_names: Array = ["Tribal", "Chiefdom", "Monarchy", "Republic", "Theocracy", "Technocracy", "Anarchy"]
					var focus_names: Array = ["Survival", "Expansion", "Trade", "Knowledge", "Military", "Artistic", "Balanced"]
					var gv: int = sai.get("government_type", 0)
					var fc: int = sai.get("development_focus", 0)
					lines.append("  Gov: [color=#bb77ee]%s[/color] · Focus: [color=#81c784]%s[/color]" % [
						gov_names[gv] if gv >= 0 and gv < gov_names.size() else "?",
						focus_names[fc] if fc >= 0 and fc < focus_names.size() else "?"
					])
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
	
	# Life timeline from PawnConsciousness
	var pc: Node = get_node_or_null("/root/PawnConsciousness")
	if pc != null:
		var pid: int = d.id
		var memories: Array = pc.get_memories(pid, "", 8)
		if memories.size() > 0:
			lines.append("")
			lines.append("[b]--- LIFE TIMELINE (last 8 memories) ---[/b]")
			for m in memories:
				if m is Dictionary:
					var tick: int = int(m.get("tick", 0))
					var etype: String = str(m.get("event_type", "event"))
					var desc: String = str(m.get("description", ""))
					var imp: int = int(m.get("importance", 3))
					var imp_color: String = "#888888"
					if imp >= 8: imp_color = "#ff6b6b"
					elif imp >= 5: imp_color = "#ffd93d"
					elif imp >= 3: imp_color = "#6bcbff"
					lines.append("  [color=%s][T%d][/color] [b]%s[/b] - %s" % [imp_color, tick, etype.capitalize(), desc])
		
		var dreams: Array = pc.get_dreams(pid, 3)
		if dreams.size() > 0:
			lines.append("")
			lines.append("[b]--- RECENT DREAMS ---[/b]")
			for dr in dreams:
				if dr is Dictionary:
					lines.append("  [color=#aa88ff]Dream:[/color] %s" % str(dr.get("description", "")))

		var trauma: float = pc.get_trauma_level(pid)
		if trauma > 0:
			lines.append("")
			lines.append("[b]--- TRAUMA ---[/b]")
			var tcolor: String = "#ff6b6b" if trauma > 0.5 else "#ffd93d"
			lines.append("  Trauma level: [color=%s]%.1f%%[/color]" % [tcolor, trauma * 100])

	# Relationships
	lines.append("")
	lines.append("[b]--- RELATIONSHIPS ---[/b]")
	var gm: Node = get_node_or_null("/root/GrudgeManager")
	var km: Node = get_node_or_null("/root/KinshipSystem")
	var pid2: int = d.id
	var rels: Array[String] = []
	if km != null and km.has_method("get_relationship_with"):
		rels.append("Family: [color=#66bb6a]%s[/color]" % str(km.call("get_family_members", pid2) if km.has_method("get_family_members") else []))
	if gm != null and gm.has_method("get_grudges_for"):
		var grudges: Array = gm.call("get_grudges_for", pid2)
		if grudges.size() > 0:
			for g in grudges:
				if g is Dictionary:
					var target: String = str(g.get("target_name", "unknown"))
					var reason: String = str(g.get("reason", ""))
					rels.append("Grudge vs [color=#ef5350]%s[/color]: %s" % [target, reason])
		else:
			rels.append("[color=#888888]No active grudges[/color]")
	if rels.is_empty():
		rels.append("[color=#888888]No relationship data[/color]")
	for rl in rels:
		lines.append("  %s" % rl)

	# Dream journal from consciousness
	var dream_pc: Node = get_node_or_null("/root/PawnConsciousness")
	if dream_pc != null:
		var all_dreams: Array = dream_pc.get_dreams(int(d.id), 5)
		if all_dreams.size() > 0:
			lines.append("")
			lines.append("[b]--- DREAMS (last 5) ---[/b]")
			for dr in all_dreams:
				if dr is Dictionary:
					var desc: String = str(dr.get("description", str(dr.get("content", ""))))
					var theme: String = str(dr.get("theme", ""))
					if not desc.is_empty():
						lines.append("  [color=#ce93d8]%s[/color]" % desc)
					if not theme.is_empty():
						lines.append("    [color=#888888](theme: %s)[/color]" % theme)

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
