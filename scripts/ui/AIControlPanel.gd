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
	
	# Initialize toggle state
	enhanced_ai_enabled = AIAgentManager.civilization_mode if AIAgentManager else false
	if enhanced_ai_toggle:
		enhanced_ai_toggle.button_pressed = enhanced_ai_enabled
	
	# Initialize tick rate
	current_tick_rate = GameManager.tick_interval if GameManager else 0.05
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
		AIAgentManager.civilization_mode = enabled
		if enabled:
			_enable_enhanced_ai_systems()
		else:
			_disable_enhanced_ai_systems()
	
	enhanced_ai_toggled.emit(enabled)
	_update_status()

func _on_tick_rate_changed(value: float) -> void:
	var new_frequency: float = value
	var new_interval: float = 1.0 / new_frequency
	
	current_tick_rate = clamp(new_interval, 0.01, 0.2)  # 50x to 5x speed
	
	if GameManager:
		GameManager.tick_interval = current_tick_rate
	
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
		
		# Increase AI update frequency for enhanced systems
		AIAgentManager.update_frequency = max(5, 15 - ai_potential_level)
		
		# Enable more agents for complex civilizations
		AIAgentManager.max_agents = min(20, 10 + ai_potential_level)

func _disable_enhanced_ai_systems() -> void:
	if AIAgentManager:
		AIAgentManager.civilization_mode = false
		
		# Reset to base configuration
		AIAgentManager.update_frequency = 15
		AIAgentManager.max_agents = 10

func _apply_ai_potential() -> void:
	if not AIAgentManager:
		return
	
	# Adjust AI parameters based on potential level
	if ai_potential_level >= 1 and ai_potential_level <= 3:  # Basic AI
		AIAgentManager.update_frequency = 15
		AIAgentManager.max_agents = 10
	elif ai_potential_level >= 4 and ai_potential_level <= 6:  # Enhanced AI
		AIAgentManager.update_frequency = 10
		AIAgentManager.max_agents = 15
	elif ai_potential_level >= 7 and ai_potential_level <= 9:  # Advanced AI
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
		status_text = "Enhanced AI: ACTIVE | "
		status_text += "Potential: %d/10 | " % ai_potential_level
		status_text += "Agents: %d | " % (AIAgentManager.agents.size() if AIAgentManager else 0)
		status_text += "Civilization: Building..."
	else:
		status_text = "Enhanced AI: INACTIVE | "
		status_text += "Base AI: %d agents | " % (AIAgentManager.agents.size() if AIAgentManager else 0)
		status_text += "Standard Mode"
	
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

func _calculate_civilization_score() -> float:
	var score: float = 0.0
	
	# Base score from settlements
	if SettlementMemory:
		score += SettlementMemory.settlements.size() * 10.0
	
	# Score from world events
	if WorldMemory:
		score += WorldMemory.event_count() * 0.5
	
	# Score from cultural development
	if CulturalMemory:
		score += CulturalMemory.reputation_by_region.size() * 5.0
	
	# Bonus for enhanced AI
	if enhanced_ai_enabled:
		score += ai_potential_level * 10.0
	
	return clamp(score, 0.0, 100.0)

func _process(_delta: float) -> void:
	# Only update display if panel is visible and all components are ready
	if visible and status_label != null:
		_update_display()

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
