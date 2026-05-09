extends Node
## DiscoveryGate — dormant-world controller.
## Systems check is_unlocked() before doing work. Gates unlock when
## HeelKawnians trigger the corresponding event (first settlement, first death, etc.).
## No RNG. No per-tick work outside gate checks (O(1) dictionary lookup).

var _unlocked: Dictionary = {}  # gate_name -> true


func is_unlocked(gate: String) -> bool:
	return _unlocked.has(gate)


func unlock(gate: String) -> void:
	if _unlocked.has(gate):
		return
	_unlocked[gate] = true
	if EventBus != null:
		EventBus.emit("discovery_gate_unlocked", {"gate": gate})


func get_unlocked_gates() -> Dictionary:
	return _unlocked.duplicate()


func clear() -> void:
	_unlocked.clear()


func _ready() -> void:
	if GameManager != null:
		GameManager.game_tick.connect(_on_game_tick)


func _exit_tree() -> void:
	if GameManager != null and GameManager.game_tick.is_connected(_on_game_tick):
		GameManager.game_tick.disconnect(_on_game_tick)


func _on_game_tick(_tick: int) -> void:
	# Auto-detect era gates from AgeMemory
	if AgeMemory != null:
		var age: int = AgeMemory.get_current_age_index()
		if age >= 1 and not is_unlocked("era_1"):
			unlock("era_1")
		if age >= 2 and not is_unlocked("era_2"):
			unlock("era_2")
