extends Node

## WorldHistoryManager - Consolidated historical and cultural systems.
## Houses AgeMemory, CulturalMemory, MythAge, and other deep-time systems.

# === Age & Era Tracking ===
var _current_age_id: int = 1
var _age_names: Dictionary = {1: "Age of Roots"}

# === Cultural Memory ===
var _cultural_values: Dictionary = {}

func _ready() -> void:
	if GameManager != null:
		GameManager.game_tick.connect(_on_game_tick)

func _on_game_tick(_tick: int) -> void:
	pass

# --- Age Logic ---
func get_current_age_name() -> String:
	return _age_names.get(_current_age_id, "Unknown Age")

func advance_age(new_name: String) -> void:
	_current_age_id += 1
	_age_names[_current_age_id] = new_name
	WorldMemory.record_event({
		"type": "age_advanced",
		"age_id": _current_age_id,
		"age_name": new_name,
		"tick": GameManager.tick_count if GameManager != null else 0
	})

# --- Cultural Logic ---
func record_cultural_shift(settlement_id: int, value_type: String, delta: float) -> void:
	var current: float = _cultural_values.get(settlement_id, {}).get(value_type, 0.0)
	if not _cultural_values.has(settlement_id):
		_cultural_values[settlement_id] = {}
	_cultural_values[settlement_id][value_type] = current + delta
