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

var _auto_build_loaded: bool = false
var _learning_loaded: bool = false
var _cooperation_loaded: bool = false
var _combat_progression_loaded: bool = false
var _combat_narrative_loaded: bool = false
var _squad_system_loaded: bool = false
var _battle_reporter_loaded: bool = false
var _guild_system_loaded: bool = false
var _genetics_system_loaded: bool = false
var _name_generator_loaded: bool = false
var _governor_system_loaded: bool = false
var _ai_orchestrator_loaded: bool = false

func _ready() -> void:
	pass

func _load_sub(name: String, path: String) -> Node:
	var existing: Node = get_node_or_null("/root/" + name)
	if existing != null:
		return existing
	if FileAccess.file_exists(path):
		var loaded: Node = load(path).new()
		loaded.name = name
		add_child(loaded)
		return loaded
	return null

func _ensure_auto_build() -> void:
	if not _auto_build_loaded:
		_auto_build = _load_sub("AutoBuild", "res://scripts/ai/AIAutoBuild.gd")
		_auto_build_loaded = true

func _ensure_learning() -> void:
	if not _learning_loaded:
		_learning = _load_sub("Learning", "res://scripts/ai/AILearning.gd")
		_learning_loaded = true

func _ensure_cooperation() -> void:
	if not _cooperation_loaded:
		_cooperation = _load_sub("Cooperation", "res://scripts/ai/AICooperation.gd")
		_cooperation_loaded = true

func _ensure_combat_progression() -> void:
	if not _combat_progression_loaded:
		_combat_progression = _load_sub("CombatProgression", "res://scripts/ai/AICombatProgression.gd")
		_combat_progression_loaded = true

func _ensure_combat_narrative() -> void:
	if not _combat_narrative_loaded:
		_combat_narrative = _load_sub("CombatNarrative", "res://scripts/ai/CombatNarrative.gd")
		_combat_narrative_loaded = true

func _ensure_squad_system() -> void:
	if not _squad_system_loaded:
		_squad_system = _load_sub("SquadSystem", "res://scripts/ai/SquadSystem.gd")
		_squad_system_loaded = true

func _ensure_battle_reporter() -> void:
	if not _battle_reporter_loaded:
		_battle_reporter = _load_sub("BattleReporter", "res://scripts/ai/BattleReporter.gd")
		_battle_reporter_loaded = true

func _ensure_guild_system() -> void:
	if not _guild_system_loaded:
		_guild_system = _load_sub("GuildSystem", "res://scripts/ai/GuildSystem.gd")
		_guild_system_loaded = true

func _ensure_genetics_system() -> void:
	if not _genetics_system_loaded:
		_genetics_system = _load_sub("GeneticsSystem", "res://scripts/ai/GeneticsSystem.gd")
		_genetics_system_loaded = true

func _ensure_name_generator() -> void:
	if not _name_generator_loaded:
		_name_generator = _load_sub("NameGenerator", "res://scripts/ai/NameGenerator.gd")
		_name_generator_loaded = true

func _ensure_governor_system() -> void:
	if not _governor_system_loaded:
		_governor_system = _load_sub("GovernorSystem", "res://scripts/ai/GovernorSystem.gd")
		_governor_system_loaded = true

func _ensure_ai_orchestrator() -> void:
	if not _ai_orchestrator_loaded:
		_ai_orchestrator = _load_sub("AIOrchestrator", "res://scripts/ai/HeelKawnAIOrchestrator.gd")
		_ai_orchestrator_loaded = true

## Get a specific AI subsystem (loads if not already loaded)
func get_subsystem(name: String) -> Node:
	match name:
		"auto_build": _ensure_auto_build(); return _auto_build
		"learning": _ensure_learning(); return _learning
		"cooperation": _ensure_cooperation(); return _cooperation
		"combat_progression": _ensure_combat_progression(); return _combat_progression
		"combat_narrative": _ensure_combat_narrative(); return _combat_narrative
		"squad_system": _ensure_squad_system(); return _squad_system
		"battle_reporter": _ensure_battle_reporter(); return _battle_reporter
		"guild_system": _ensure_guild_system(); return _guild_system
		"genetics_system": _ensure_genetics_system(); return _genetics_system
		"name_generator": _ensure_name_generator(); return _name_generator
		"governor_system": _ensure_governor_system(); return _governor_system
		"ai_orchestrator": _ensure_ai_orchestrator(); return _ai_orchestrator
		_: return null

## Process AI systems (called by tick system)
func process(world: World, main: Node2D) -> void:
	if WorldAI != null and WorldAI.has_method("update"):
		WorldAI.update()

## Generate a name (delegates to NameGenerator if available)
func generate_name() -> String:
	_ensure_name_generator()
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
