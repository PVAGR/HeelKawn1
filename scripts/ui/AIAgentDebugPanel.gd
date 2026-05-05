extends Control
## AI Agent Debug Panel - Monitor and control AI agents during development

@onready var agent_list: ItemList = $VBoxContainer/AgentList
@onready var agent_details: RichTextLabel = $VBoxContainer/AgentDetails
@onready var spawn_button: Button = $VBoxContainer/Controls/SpawnButton
@onready var enable_checkbox: CheckBox = $VBoxContainer/Controls/EnableCheckbox
@onready var refresh_button: Button = $VBoxContainer/Controls/RefreshButton

var selected_agent_id: int = -1
var refresh_interval: float = 1.0
var time_since_refresh: float = 0.0
var _last_refresh_agents: Array[Dictionary] = []

func _ready() -> void:
	# Connect button signals
	if spawn_button:
		spawn_button.pressed.connect(_on_spawn_pressed)
	if enable_checkbox:
		enable_checkbox.toggled.connect(_on_enable_toggled)
	if refresh_button:
		refresh_button.pressed.connect(_refresh_agent_list)
	
	# Initialize UI state (safe check for autoload)
	if enable_checkbox and AIAgentManager != null:
		enable_checkbox.button_pressed = AIAgentManager.enabled
	
	# Initial refresh
	_refresh_agent_list()

func _process(delta: float) -> void:
	time_since_refresh += delta
	if time_since_refresh >= refresh_interval:
		_refresh_agent_list()
		time_since_refresh = 0.0

func _refresh_agent_list() -> void:
	if agent_list == null or AIAgentManager == null:
		return
	
	# Get agent status efficiently
	var agents: Array[Dictionary] = AIAgentManager.get_all_agent_status()
	
	# Early exit if no changes detected
	if _last_refresh_agents.size() == agents.size():
		var changed = false
		for i in range(agents.size()):
			if agents[i].get("agent_id", -1) != _last_refresh_agents[i].get("agent_id", -1):
				changed = true
				break
		if not changed:
			return
	
	_last_refresh_agents = agents.duplicate(true)
	
	agent_list.clear()
	
	for agent_status in agents:
		var agent_id: int = agent_status.get("agent_id", -1)
		var agent_type: int = agent_status.get("agent_type", 0)
		var controlled_pawn_id: int = agent_status.get("controlled_pawn_id", -1)
		var goal_count: int = agent_status.get("current_goals", 0)
		
		var type_name: String = "Unknown"
		match agent_type:
			0: type_name = "Strategic"
			1: type_name = "Tactical"
			2: type_name = "Reactive"
		
		var status_text: String = "Agent %d (%s) - Goals: %d" % [agent_id, type_name, goal_count]
		if controlled_pawn_id >= 0:
			status_text += " - Pawn: %d" % controlled_pawn_id
		else:
			status_text += " - Spectator"
		
		agent_list.add_item(status_text)
		agent_list.set_item_metadata(agent_list.get_item_count() - 1, agent_id)

func _on_agent_selected(index: int) -> void:
	if agent_list == null:
		return
	
	selected_agent_id = agent_list.get_item_metadata(index)
	_update_agent_details()

func _update_agent_details() -> void:
	if selected_agent_id < 0 or agent_details == null or AIAgentManager == null:
		return
	
	var agent_status: Dictionary = AIAgentManager.get_agent_status(selected_agent_id)
	
	if agent_status.has("error"):
		agent_details.text = "Error: %s" % agent_status.get("error", "Unknown error")
		return
	
	var agent_type: int = agent_status.get("agent_type", 0)
	var controlled_pawn_id: int = agent_status.get("controlled_pawn_id", -1)
	var goal_count: int = agent_status.get("current_goals", 0)
	var memory_size: int = agent_status.get("memory_size", 0)
	var last_decision: int = agent_status.get("last_decision_tick", 0)
	
	var personality: Dictionary = agent_status.get("personality", {})
	var aggressiveness: float = personality.get("aggressiveness", 0.0)
	var caution: float = personality.get("caution", 0.0)
	var social_tendency: float = personality.get("social_tendency", 0.0)
	var exploration_drive: float = personality.get("exploration_drive", 0.0)
	var self_preservation: float = personality.get("self_preservation", 0.0)
	
	var type_name: String = "Unknown"
	match agent_type:
		0: type_name = "Strategic"
		1: type_name = "Tactical"
		2: type_name = "Reactive"
	
	var details_text: String = ""
	details_text += "[b]Agent %d (%s)[/b]\n\n" % [selected_agent_id, type_name]
	details_text += "[b]Status:[/b]\n"
	details_text += "Controlled Pawn: %d\n" % (controlled_pawn_id if controlled_pawn_id >= 0 else "None (Spectator)")
	details_text += "Active Goals: %d\n" % goal_count
	details_text += "Memory Size: %d observations\n" % memory_size
	details_text += "Last Decision: Tick %d\n\n" % last_decision
	
	details_text += "[b]Personality:[/b]\n"
	details_text += "Aggressiveness: %.1f\n" % aggressiveness
	details_text += "Caution: %.1f\n" % caution
	details_text += "Social Tendency: %.1f\n" % social_tendency
	details_text += "Exploration Drive: %.1f\n" % exploration_drive
	details_text += "Self Preservation: %.1f\n\n" % self_preservation
	
	# Add pawn details if controlled
	if controlled_pawn_id >= 0:
		var pawn_obs: Dictionary = ObservationAPI.observe_pawn(controlled_pawn_id)
		if not pawn_obs.has("error"):
			details_text += "[b]Controlled Pawn:[/b]\n"
			details_text += "Name: %s\n" % pawn_obs.get("display_name", "Unknown")
			details_text += "Health: %d%%\n" % pawn_obs.get("health_percentage", 0)
			details_text += "Hunger: %.0f\n" % pawn_obs.get("hunger", 0)
			details_text += "Mood: %.0f\n" % pawn_obs.get("mood", 0)
			details_text += "Current Job: %s\n" % pawn_obs.get("current_job", "None")
			details_text += "State: %s\n" % pawn_obs.get("state", "Unknown")
	
	agent_details.text = details_text

func _on_spawn_pressed() -> void:
	if AIAgentManager == null:
		return
	
	# Spawn a random tactical agent
	var AIAgentClass = preload("res://scripts/ai/AIAgent.gd")
	var agent_id: int = AIAgentManager.force_spawn_agent(AIAgentClass.AgentType.TACTICAL)
	if agent_id >= 0:
		print("Spawned AI Agent %d" % agent_id)
		_refresh_agent_list()

func _on_enable_toggled(enabled: bool) -> void:
	if AIAgentManager != null:
		AIAgentManager.set_enabled(enabled)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			# Check if click is on agent list
			if agent_list != null and agent_list.get_global_rect().has_point(get_global_mouse_position()):
				var local_pos: Vector2 = agent_list.to_local(event.position)
				var clicked_item: int = agent_list.get_item_at_position(local_pos)
				if clicked_item >= 0:
					_on_agent_selected(clicked_item)
