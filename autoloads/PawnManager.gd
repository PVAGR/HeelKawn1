extends Node
## Consolidated Pawn Manager
## Combines pawn consciousness and dialogue systems into one autoload
## Reduces autoload count while preserving pawn functionality

# Child nodes for pawn subsystems (loaded on-demand)
var _pawn_consciousness: Node
var _pawn_dialogue: Node
var _pawn_brain_bridge: Node
var _heelkawnian_mind: Node
var _heelkawnian_identity: Node
var _heelkawnian_manager: Node
var _heelkawnian_voice: Node

var _subsystems_loaded: bool = false

func _ready() -> void:
	add_to_group("tickable")
	print("[PawnManager] Initialized")

## Load pawn subsystems on-demand (not at startup)
func _load_subsystems() -> void:
	if _subsystems_loaded:
		return
	
	# Load pawn subsystems as children
	if FileAccess.file_exists("res://autoloads/PawnConsciousness.gd"):
		_pawn_consciousness = load("res://autoloads/PawnConsciousness.gd").new()
		_pawn_consciousness.name = "PawnConsciousness"
		add_child(_pawn_consciousness)
	
	if FileAccess.file_exists("res://autoloads/PawnDialogue.gd"):
		_pawn_dialogue = load("res://autoloads/PawnDialogue.gd").new()
		_pawn_dialogue.name = "PawnDialogue"
		add_child(_pawn_dialogue)
	
	if FileAccess.file_exists("res://autoloads/PawnBrainBridge.gd"):
		_pawn_brain_bridge = load("res://autoloads/PawnBrainBridge.gd").new()
		_pawn_brain_bridge.name = "PawnBrainBridge"
		add_child(_pawn_brain_bridge)
	
	if FileAccess.file_exists("res://autoloads/HeelKawnianMind.gd"):
		_heelkawnian_mind = load("res://autoloads/HeelKawnianMind.gd").new()
		_heelkawnian_mind.name = "HeelKawnianMind"
		add_child(_heelkawnian_mind)
	
	if FileAccess.file_exists("res://autoloads/HeelKawnianIdentity.gd"):
		_heelkawnian_identity = load("res://autoloads/HeelKawnianIdentity.gd").new()
		_heelkawnian_identity.name = "HeelKawnianIdentity"
		add_child(_heelkawnian_identity)
	
	if FileAccess.file_exists("res://autoloads/HeelKawnianManager.gd"):
		_heelkawnian_manager = load("res://autoloads/HeelKawnianManager.gd").new()
		_heelkawnian_manager.name = "HeelKawnianManager"
		add_child(_heelkawnian_manager)
	
	if FileAccess.file_exists("res://autoloads/HeelKawnianVoice.gd"):
		_heelkawnian_voice = load("res://autoloads/HeelKawnianVoice.gd").new()
		_heelkawnian_voice.name = "HeelKawnianVoice"
		add_child(_heelkawnian_voice)
	
	_subsystems_loaded = true
	print("[PawnManager] Pawn subsystems loaded")

## Get a specific pawn subsystem (loads if not already loaded)
func get_subsystem(name: String) -> Node:
	_load_subsystems()
	match name:
		"pawn_consciousness": return _pawn_consciousness
		"pawn_dialogue": return _pawn_dialogue
		"pawn_brain_bridge": return _pawn_brain_bridge
		"heelkawnian_mind": return _heelkawnian_mind
		"heelkawnian_identity": return _heelkawnian_identity
		"heelkawnian_manager": return _heelkawnian_manager
		"heelkawnian_voice": return _heelkawnian_voice
		_: return null

## Process pawn consciousness (delegates to PawnConsciousness if available)
func process_consciousness(pawn: Node, world: World) -> void:
	if _pawn_consciousness == null:
		_load_subsystems()
	if _pawn_consciousness != null and _pawn_consciousness.has_method("process"):
		_pawn_consciousness.process(pawn, world)

## Generate dialogue (delegates to PawnDialogue if available)
func generate_dialogue(pawn_id: int, context: String) -> String:
	if _pawn_dialogue == null:
		_load_subsystems()
	if _pawn_dialogue != null and _pawn_dialogue.has_method("generate"):
		return _pawn_dialogue.generate(pawn_id, context)
	return ""

## Forward getters for subsystems
func get_pawn_consciousness() -> Node:
	return get_subsystem("pawn_consciousness")

func get_pawn_dialogue() -> Node:
	return get_subsystem("pawn_dialogue")

func get_pawn_brain_bridge() -> Node:
	return get_subsystem("pawn_brain_bridge")

func get_heelkawnian_mind() -> Node:
	return get_subsystem("heelkawnian_mind")

func get_heelkawnian_identity() -> Node:
	return get_subsystem("heelkawnian_identity")

func get_heelkawnian_manager() -> Node:
	return get_subsystem("heelkawnian_manager")

func get_heelkawnian_voice() -> Node:
	return get_subsystem("heelkawnian_voice")
