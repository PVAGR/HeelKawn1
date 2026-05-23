class_name DiscoveryGate
## DiscoveryGate — dormant-world controller.
## Systems check is_unlocked() before doing work. Gates unlock when
## HeelKawnians trigger the corresponding event (first settlement, first death, etc.).
## No RNG. No per-tick work outside gate checks (O(1) dictionary lookup).
##
## Converted from autoload to static utility class. Call DiscoveryGate.init()
## once at boot to wire EventBus and GameManager hooks.

static var _unlocked: Dictionary = {}  # gate_name -> true
static var _initialized: bool = false


static func is_unlocked(gate: String) -> bool:
	return _unlocked.has(gate)


static func unlock(gate: String) -> void:
	if _unlocked.has(gate):
		return
	_unlocked[gate] = true
	if EventBus != null:
		EventBus.emit("discovery_gate_unlocked", {"gate": gate})


static func get_unlocked_gates() -> Dictionary:
	return _unlocked.duplicate()


static func clear() -> void:
	_unlocked.clear()


static func init() -> void:
	if _initialized:
		return
	_initialized = true
	if GameManager != null:
		GameManager.game_tick.connect(_on_game_tick)


static func _on_game_tick(_tick: int) -> void:
	if AgeMemory != null:
		var age: int = AgeMemory.get_current_age_index()
		if age >= 1 and not is_unlocked("era_1"):
			unlock("era_1")
		if age >= 2 and not is_unlocked("era_2"):
			unlock("era_2")
