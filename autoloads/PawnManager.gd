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

var _pawn_consciousness_loaded: bool = false
var _pawn_dialogue_loaded: bool = false
var _pawn_brain_bridge_loaded: bool = false
var _heelkawnian_mind_loaded: bool = false
var _heelkawnian_identity_loaded: bool = false
var _heelkawnian_manager_loaded: bool = false
var _heelkawnian_voice_loaded: bool = false

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

func _ensure_pawn_consciousness() -> void:
	if not _pawn_consciousness_loaded:
		_pawn_consciousness = _load_sub("PawnConsciousness", "res://autoloads/PawnConsciousness.gd")
		_pawn_consciousness_loaded = true

func _ensure_pawn_dialogue() -> void:
	if not _pawn_dialogue_loaded:
		_pawn_dialogue = _load_sub("PawnDialogue", "res://autoloads/PawnDialogue.gd")
		_pawn_dialogue_loaded = true

func _ensure_pawn_brain_bridge() -> void:
	if not _pawn_brain_bridge_loaded:
		_pawn_brain_bridge = _load_sub("PawnBrainBridge", "res://autoloads/PawnBrainBridge.gd")
		_pawn_brain_bridge_loaded = true

func _ensure_heelkawnian_mind() -> void:
	if not _heelkawnian_mind_loaded:
		_heelkawnian_mind = _load_sub("HeelKawnianMind", "res://autoloads/HeelKawnianMind.gd")
		_heelkawnian_mind_loaded = true

func _ensure_heelkawnian_identity() -> void:
	if not _heelkawnian_identity_loaded:
		_heelkawnian_identity = _load_sub("HeelKawnianIdentity", "res://autoloads/HeelKawnianIdentity.gd")
		_heelkawnian_identity_loaded = true

func _ensure_heelkawnian_manager() -> void:
	if not _heelkawnian_manager_loaded:
		_heelkawnian_manager = _load_sub("HeelKawnianManager", "res://autoloads/HeelKawnianManager.gd")
		_heelkawnian_manager_loaded = true

func _ensure_heelkawnian_voice() -> void:
	if not _heelkawnian_voice_loaded:
		_heelkawnian_voice = _load_sub("HeelKawnianVoice", "res://autoloads/HeelKawnianVoice.gd")
		_heelkawnian_voice_loaded = true

## Get a specific pawn subsystem (loads if not already loaded)
func get_subsystem(name: String) -> Node:
	match name:
		"pawn_consciousness": _ensure_pawn_consciousness(); return _pawn_consciousness
		"pawn_dialogue": _ensure_pawn_dialogue(); return _pawn_dialogue
		"pawn_brain_bridge": _ensure_pawn_brain_bridge(); return _pawn_brain_bridge
		"heelkawnian_mind": _ensure_heelkawnian_mind(); return _heelkawnian_mind
		"heelkawnian_identity": _ensure_heelkawnian_identity(); return _heelkawnian_identity
		"heelkawnian_manager": _ensure_heelkawnian_manager(); return _heelkawnian_manager
		"heelkawnian_voice": _ensure_heelkawnian_voice(); return _heelkawnian_voice
		_: return null

## Process pawn consciousness (delegates to PawnConsciousness if available)
func process_consciousness(pawn: Node, world: World) -> void:
	_ensure_pawn_consciousness()
	if _pawn_consciousness != null and _pawn_consciousness.has_method("process"):
		_pawn_consciousness.process(pawn, world)

## Generate dialogue (delegates to PawnDialogue if available)
func generate_dialogue(pawn_id: int, context: String) -> String:
	_ensure_pawn_dialogue()
	if _pawn_dialogue != null and _pawn_dialogue.has_method("generate"):
		return _pawn_dialogue.generate(pawn_id, context)
	return ""

## Forward getters for subsystems
func get_pawn_consciousness() -> Node:
	return get_subsystem("pawn_consciousness")

## Get total pawn count across all managed pawns
func get_pawn_count() -> int:
	_ensure_heelkawnian_manager()
	if _heelkawnian_manager != null and _heelkawnian_manager.has_method("get_total_pawn_count"):
		return _heelkawnian_manager.get_total_pawn_count()
	# Fallback: count children if no manager method
	return get_child_count()

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
