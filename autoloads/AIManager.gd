extends Node
## Consolidated AI Manager
## Combines multiple AI systems into one autoload
## Reduces autoload count while preserving AI functionality

# Core AI system (kept separate as it's essential)
@onready var WorldAI = get_node_or_null("/root/WorldAI")

# Child nodes for AI subsystems (loaded on-demand)
var _auto_build: Node
var _learning: Node
var _cooperation: Node
var _combat_progression: Node
var _combat_narrative: Node
var _squad_system: Node
var _battle_reporter: Node
var _guild_system: Node
var _genetics_system: Node
var _name_generator: Node
var _governor_system: Node
var _ai_orchestrator: Node

var _subsystems_loaded: bool = false

func _ready() -> void:
	add_to_group("tickable")
	print("[AIManager] Initialized")

## Load AI subsystems on-demand (not at startup)
func _load_subsystems() -> void:
	if _subsystems_loaded:
		return
	
	# Load AI subsystems as children
	if FileAccess.file_exists("res://scripts/ai/AIAutoBuild.gd"):
		_auto_build = load("res://scripts/ai/AIAutoBuild.gd").new()
		_auto_build.name = "AutoBuild"
		add_child(_auto_build)
	
	if FileAccess.file_exists("res://scripts/ai/AILearning.gd"):
		_learning = load("res://scripts/ai/AILearning.gd").new()
		_learning.name = "Learning"
		add_child(_learning)
	
	if FileAccess.file_exists("res://scripts/ai/AICooperation.gd"):
		_cooperation = load("res://scripts/ai/AICooperation.gd").new()
		_cooperation.name = "Cooperation"
		add_child(_cooperation)
	
	if FileAccess.file_exists("res://scripts/ai/AICombatProgression.gd"):
		_combat_progression = load("res://scripts/ai/AICombatProgression.gd").new()
		_combat_progression.name = "CombatProgression"
		add_child(_combat_progression)
	
	if FileAccess.file_exists("res://scripts/ai/CombatNarrative.gd"):
		_combat_narrative = load("res://scripts/ai/CombatNarrative.gd").new()
		_combat_narrative.name = "CombatNarrative"
		add_child(_combat_narrative)
	
	if FileAccess.file_exists("res://scripts/ai/SquadSystem.gd"):
		_squad_system = load("res://scripts/ai/SquadSystem.gd").new()
		_squad_system.name = "SquadSystem"
		add_child(_squad_system)
	
	if FileAccess.file_exists("res://scripts/ai/BattleReporter.gd"):
		_battle_reporter = load("res://scripts/ai/BattleReporter.gd").new()
		_battle_reporter.name = "BattleReporter"
		add_child(_battle_reporter)
	
	if FileAccess.file_exists("res://scripts/ai/GuildSystem.gd"):
		_guild_system = load("res://scripts/ai/GuildSystem.gd").new()
		_guild_system.name = "GuildSystem"
		add_child(_guild_system)
	
	if FileAccess.file_exists("res://scripts/ai/GeneticsSystem.gd"):
		_genetics_system = load("res://scripts/ai/GeneticsSystem.gd").new()
		_genetics_system.name = "GeneticsSystem"
		add_child(_genetics_system)
	
	if FileAccess.file_exists("res://scripts/ai/NameGenerator.gd"):
		_name_generator = load("res://scripts/ai/NameGenerator.gd").new()
		_name_generator.name = "NameGenerator"
		add_child(_name_generator)
	
	if FileAccess.file_exists("res://scripts/ai/GovernorSystem.gd"):
		_governor_system = load("res://scripts/ai/GovernorSystem.gd").new()
		_governor_system.name = "GovernorSystem"
		add_child(_governor_system)
	
	if FileAccess.file_exists("res://scripts/ai/HeelKawnAIOrchestrator.gd"):
		_ai_orchestrator = load("res://scripts/ai/HeelKawnAIOrchestrator.gd").new()
		_ai_orchestrator.name = "AIOrchestrator"
		add_child(_ai_orchestrator)
	
	_subsystems_loaded = true
	print("[AIManager] AI subsystems loaded")

## Get a specific AI subsystem (loads if not already loaded)
func get_subsystem(name: String) -> Node:
	_load_subsystems()
	match name:
		"auto_build": return _auto_build
		"learning": return _learning
		"cooperation": return _cooperation
		"combat_progression": return _combat_progression
		"combat_narrative": return _combat_narrative
		"squad_system": return _squad_system
		"battle_reporter": return _battle_reporter
		"guild_system": return _guild_system
		"genetics_system": return _genetics_system
		"name_generator": return _name_generator
		"governor_system": return _governor_system
		"ai_orchestrator": return _ai_orchestrator
		_: return null

## Process AI systems (called by tick system)
func process(world: World, main: Node2D) -> void:
	# Only load subsystems when actually needed
	if not _subsystems_loaded:
		_load_subsystems()
	
	# WorldAI is the core AI system and should always run
	if WorldAI != null and WorldAI.has_method("process"):
		WorldAI.process(world, main)

## Generate a name (delegates to NameGenerator if available)
func generate_name() -> String:
	if _name_generator == null:
		_load_subsystems()
	if _name_generator != null and _name_generator.has_method("generate_name"):
		return _name_generator.generate_name()
	return "Unknown"

## Forward other common AI methods as needed
func get_auto_build() -> Node:
	return get_subsystem("auto_build")

func get_learning() -> Node:
	return get_subsystem("learning")

func get_cooperation() -> Node:
	return get_subsystem("cooperation")
