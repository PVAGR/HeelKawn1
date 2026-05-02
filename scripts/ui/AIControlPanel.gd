extends Control
class_name AIControlPanel
## Compact AI Control Panel - Enhanced AI Systems Control Interface
## Provides sleek, efficient controls for AI matrix management

signal enhanced_ai_toggled(enabled: bool)
signal tick_rate_changed(new_rate: float)
signal ai_potential_changed(level: int)

# UI References - will be set safely in _ready
var enhanced_ai_toggle: CheckBox
var tick_rate_slider: HSlider
var tick_rate_label: Label
var ai_potential_slider: HSlider
var ai_potential_label: Label
var civilization_progress: ProgressBar
var status_label: Label

# Neural Network Visualization UI
var neural_network_container: VBoxContainer
var world_state_label: Label
var civilization_label: Label
var cultural_label: Label
var environmental_label: Label
var economic_label: Label
var religious_label: Label
var collapse_risk_bar: ProgressBar
var trust_level_bar: ProgressBar
var economic_stability_bar: ProgressBar
var religious_fervor_bar: ProgressBar

# AI System State
var enhanced_ai_enabled: bool = false
var current_tick_rate: float = 0.05
var ai_potential_level: int = 1  # 1-10 scale
var civilization_score: float = 0.0

func _ready() -> void:
	_setup_ui()
	_connect_signals()
	_update_display()

func _setup_ui() -> void:
	# Safely get UI nodes
	enhanced_ai_toggle = get_node_or_null("VBoxContainer/EnhancedAIToggle")
	tick_rate_slider = get_node_or_null("VBoxContainer/TickRateContainer/TickRateSlider")
	tick_rate_label = get_node_or_null("VBoxContainer/TickRateContainer/TickRateLabel")
	ai_potential_slider = get_node_or_null("VBoxContainer/AIPotentialContainer/AIPotentialSlider")
	ai_potential_label = get_node_or_null("VBoxContainer/AIPotentialContainer/AIPotentialLabel")
	civilization_progress = get_node_or_null("VBoxContainer/CivilizationProgress")
	status_label = get_node_or_null("VBoxContainer/StatusLabel")
	
	# Neural network visualization UI
	neural_network_container = get_node_or_null("VBoxContainer/NeuralNetworkContainer")
	world_state_label = get_node_or_null("VBoxContainer/NeuralNetworkContainer/WorldStateLabel")
	civilization_label = get_node_or_null("VBoxContainer/NeuralNetworkContainer/CivilizationLabel")
	cultural_label = get_node_or_null("VBoxContainer/NeuralNetworkContainer/CulturalLabel")
	environmental_label = get_node_or_null("VBoxContainer/NeuralNetworkContainer/EnvironmentalLabel")
	economic_label = get_node_or_null("VBoxContainer/NeuralNetworkContainer/EconomicLabel")
	religious_label = get_node_or_null("VBoxContainer/NeuralNetworkContainer/ReligiousLabel")
	collapse_risk_bar = get_node_or_null("VBoxContainer/NeuralNetworkContainer/CollapseRiskBar")
	trust_level_bar = get_node_or_null("VBoxContainer/NeuralNetworkContainer/TrustLevelBar")
	economic_stability_bar = get_node_or_null("VBoxContainer/NeuralNetworkContainer/EconomicStabilityBar")
	religious_fervor_bar = get_node_or_null("VBoxContainer/NeuralNetworkContainer/ReligiousFervorBar")
	
	# Initialize toggle state
	enhanced_ai_enabled = AIAgentManager.civilization_mode if AIAgentManager else false
	if enhanced_ai_toggle:
		enhanced_ai_toggle.button_pressed = enhanced_ai_enabled
	
	# Initialize tick rate
	current_tick_rate = float(GameManager.get("TICK_INTERVAL_SECONDS")) if GameManager else 0.1
	if tick_rate_slider:
		tick_rate_slider.value = 1.0 / current_tick_rate  # Convert to frequency
	if tick_rate_label:
		tick_rate_label.text = "Tick Rate: %.1fx" % (1.0 / current_tick_rate)
	
	# Initialize AI potential
	if ai_potential_slider:
		ai_potential_slider.value = ai_potential_level
	if ai_potential_label:
		ai_potential_label.text = "AI Potential: %d/10" % ai_potential_level
	
	# Initialize civilization progress
	if civilization_progress:
		civilization_progress.value = civilization_score
		civilization_progress.max_value = 100.0

func _connect_signals() -> void:
	if enhanced_ai_toggle and not enhanced_ai_toggle.is_connected("toggled", _on_enhanced_ai_toggled):
		enhanced_ai_toggle.toggled.connect(_on_enhanced_ai_toggled)
	if tick_rate_slider and not tick_rate_slider.is_connected("value_changed", _on_tick_rate_changed):
		tick_rate_slider.value_changed.connect(_on_tick_rate_changed)
	if ai_potential_slider and not ai_potential_slider.is_connected("value_changed", _on_ai_potential_changed):
		ai_potential_slider.value_changed.connect(_on_ai_potential_changed)

func _on_enhanced_ai_toggled(enabled: bool) -> void:
	enhanced_ai_enabled = enabled
	
	if AIAgentManager:
		if enabled:
			_enable_enhanced_ai_systems()
		else:
			_disable_enhanced_ai_systems()
	
	enhanced_ai_toggled.emit(enabled)
	_update_status()

func _on_tick_rate_changed(value: float) -> void:
	var new_frequency: float = value
	var new_interval: float = 1.0 / new_frequency
	
	if GameManager:
		if GameManager.has_method("set_tick_interval_seconds"):
			GameManager.call("set_tick_interval_seconds", new_interval)
	
	current_tick_rate = new_interval
	if tick_rate_label:
		tick_rate_label.text = "Tick Rate: %.1fx" % new_frequency
	tick_rate_changed.emit(new_frequency)

func _on_ai_potential_changed(value: float) -> void:
	ai_potential_level = int(value)
	if ai_potential_label:
		ai_potential_label.text = "AI Potential: %d/10" % ai_potential_level
	
	_apply_ai_potential()
	ai_potential_changed.emit(ai_potential_level)
	_update_status()

func _enable_enhanced_ai_systems() -> void:
	if AIAgentManager:
		# Enhanced AI systems are already built, just need to activate
		AIAgentManager.civilization_mode = true
		
		# Enable more agents for complex civilizations
		AIAgentManager.max_agents = min(20, 10 + ai_potential_level)

func _disable_enhanced_ai_systems() -> void:
	if AIAgentManager:
		AIAgentManager.civilization_mode = false
		
		# Reset to default agent count
		AIAgentManager.update_frequency = 15
		AIAgentManager.max_agents = 10

func _apply_ai_potential() -> void:
	if not AIAgentManager:
		return
	
	# Apply AI potential settings based on level
	if ai_potential_level >= 1 and ai_potential_level <= 3:
		AIAgentManager.update_frequency = 15
		AIAgentManager.max_agents = 10
	elif ai_potential_level >= 4 and ai_potential_level <= 6:
		AIAgentManager.update_frequency = 10
		AIAgentManager.max_agents = 15
	elif ai_potential_level >= 7 and ai_potential_level <= 9:
		AIAgentManager.update_frequency = 5
		AIAgentManager.max_agents = 20
	elif ai_potential_level == 10:  # Maximum AI
		AIAgentManager.update_frequency = 3
		AIAgentManager.max_agents = 25
	else:
		# Reset to default if invalid level
		AIAgentManager.update_frequency = 15
		AIAgentManager.max_agents = 10

func _update_status() -> void:
	var status_text: String = ""
	
	if enhanced_ai_enabled:
		status_text += "Enhanced AI: ACTIVE\n"
		status_text += "AI Potential: %d/10\n" % ai_potential_level
		status_text += "Tick Rate: %.1fx\n" % (1.0 / current_tick_rate)
	else:
		status_text += "Enhanced AI: INACTIVE\n"
		status_text += "AI Potential: %d/10\n" % ai_potential_level
		status_text += "Tick Rate: %.1fx\n" % (1.0 / current_tick_rate)
	
	if status_label:
		status_label.text = status_text

func _update_display() -> void:
	# Safe status update
	if status_label != null:
		_update_status()
	
	# Update civilization progress based on world state
	if WorldMemory and civilization_progress != null:
		civilization_score = _calculate_civilization_score()
		civilization_progress.value = civilization_score
	
	# Update neural network visualization
	_update_neural_network_display()

func _calculate_civilization_score() -> float:
	var score: float = 0.0
	
	# Base score from settlements
	if SettlementMemory:
		score += SettlementMemory.settlements.size() * 10.0
	
	# Add AI potential contribution
	score += ai_potential_level * 10.0
	
	return clamp(score, 0.0, 100.0)

func _update_neural_network_display() -> void:
	if not WorldAI:
		return
	
	var summary = WorldAI.get_neural_network_summary() if WorldAI.has_method("get_neural_network_summary") else {}
	
	if world_state_label:
		var collapse_risk = summary.get("collapse_risk", 0.0)
		var trust_level = summary.get("trust_level", 0.0)
		world_state_label.text = "World: Collapse %.2f | Trust %.2f" % [collapse_risk, trust_level]
	
	if civilization_label:
		var civil_auth = summary.get("civil_authority", 0.0)
		var military_auth = summary.get("military_authority", 0.0)
		civilization_label.text = "Civ: Civil %.2f | Military %.2f" % [civil_auth, military_auth]
	
	if cultural_label:
		var knowledge_scarcity = summary.get("knowledge_scarcity", 0.0)
		var teaching_activity = summary.get("teaching_activity", 0.0)
		cultural_label.text = "Culture: Knowledge %.2f | Teaching %.2f" % [knowledge_scarcity, teaching_activity]
	
	if environmental_label:
		var ruin_density = summary.get("ruin_density", 0.0)
		var resource_depletion = summary.get("resource_depletion", 0.0)
		environmental_label.text = "Env: Ruins %.2f | Depletion %.2f" % [ruin_density, resource_depletion]
	
	if economic_label:
		var production_eff = summary.get("production_efficiency", 0.0)
		var econ_stability = summary.get("economic_stability", 0.0)
		economic_label.text = "Econ: Production %.2f | Stability %.2f" % [production_eff, econ_stability]
	
	if religious_label:
		var religious_fervor = summary.get("religious_fervor", 0.0)
		var religious_influence = summary.get("religious_influence", 0.0)
		religious_label.text = "Rel: Fervor %.2f | Influence %.2f" % [religious_fervor, religious_influence]
	
	# Update progress bars
	if collapse_risk_bar:
		collapse_risk_bar.value = summary.get("collapse_risk", 0.0) * 100
		# Color code collapse risk
		var risk = summary.get("collapse_risk", 0.0)
		if risk < 0.3:
			collapse_risk_bar.modulate = Color.GREEN
		elif risk < 0.6:
			collapse_risk_bar.modulate = Color.YELLOW
		else:
			collapse_risk_bar.modulate = Color.RED
	
	if trust_level_bar:
		trust_level_bar.value = summary.get("trust_level", 0.0) * 100
	
	if economic_stability_bar:
		economic_stability_bar.value = summary.get("economic_stability", 0.0) * 100
	
	if religious_fervor_bar:
		religious_fervor_bar.value = summary.get("religious_fervor", 0.0) * 100

var _update_timer: float = 0.0
const UPDATE_INTERVAL: float = 1.0  # Update every 1 second instead of every frame

func _process(delta: float) -> void:
	# Only update display if panel is visible and all components are ready
	if not visible or status_label == null:
		return
	
	_update_timer += delta
	if _update_timer >= UPDATE_INTERVAL:
		_update_display()
		_update_timer = 0.0

# === Public Interface ===

func toggle_panel() -> void:
	visible = not visible

func set_enhanced_ai(enabled: bool) -> void:
	if enhanced_ai_toggle:
		enhanced_ai_toggle.button_pressed = enabled

func set_tick_rate(frequency: float) -> void:
	if tick_rate_slider:
		tick_rate_slider.value = frequency

func set_ai_potential(level: int) -> void:
	if ai_potential_slider:
		ai_potential_slider.value = level
