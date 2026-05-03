extends Node
## Runtime game settings registry. Provides get/set with change notifications
## so UI and simulation systems can react immediately when the player adjusts
## a slider or checkbox in the Settings panel.
##
## Each setting has a schema entry (key, label, type, default, bounds).
## Values are stored in a flat dict; no disk persistence yet — just session state.

signal setting_changed(key: String, new_value: Variant)

## Schema: defines every setting the UI can expose.
## type: "bool" | "int" | "float" | "enum"
## For int/float: "min", "max", "step" control slider range.
## For enum: "options" is an Array of String labels (index is the value).
const SCHEMA: Array[Dictionary] = [
	# ── Display ──────────────────────────────────────────
	{
		"key": "hud_mode",
		"label": "HUD Mode",
		"section": "Display",
		"type": "enum",
		"options": ["Simple", "Debug"],
		"default": 0,  # 0 = Simple
	},
	{
		"key": "hud_font_size",
		"label": "Font Size",
		"section": "Display",
		"type": "int",
		"min": 8,
		"max": 16,
		"step": 1,
		"default": 11,
	},
	{
		"key": "show_hotkey_hints",
		"label": "Hotkey Hints",
		"section": "Display",
		"type": "bool",
		"default": true,
	},
	# ── Simulation ────────────────────────────────────────
	{
		"key": "max_ticks_per_frame",
		"label": "Max Ticks/Frame",
		"section": "Simulation",
		"type": "int",
		"min": 50,
		"max": 500,
		"step": 50,
		"default": 500,
	},
	{
		"key": "frame_budget_ms",
		"label": "Frame Budget (ms)",
		"section": "Simulation",
		"type": "int",
		"min": 16,
		"max": 100,
		"step": 2,
		"default": 50,
	},
	# ── Gameplay ─────────────────────────────────────────
	{
		"key": "verbose_logs",
		"label": "Verbose Logs",
		"section": "Gameplay",
		"type": "bool",
		"default": false,
	},
	{
		"key": "show_refresh_diag",
		"label": "Refresh Diag",
		"section": "Gameplay",
		"type": "bool",
		"default": true,
	},
]

var _values: Dictionary = {}


func _ready() -> void:
	# Initialize all settings to defaults
	for entry in SCHEMA:
		_values[entry["key"]] = entry["default"]


## Get the current value of a setting. Returns the default if not set.
func get_value(key: String) -> Variant:
	if _values.has(key):
		return _values[key]
	# Fallback: find default in schema
	for entry in SCHEMA:
		if entry["key"] == key:
			return entry["default"]
	return null


## Set a setting value and emit the change signal. Clamps to bounds if numeric.
func set_value(key: String, value: Variant) -> void:
	var entry: Dictionary = _find_schema(key)
	if entry.is_empty():
		return
	# Clamp numeric values
	if entry.get("type", "") == "int":
		value = clampi(int(value), int(entry.get("min", 0)), int(entry.get("max", 9999)))
	elif entry.get("type", "") == "float":
		value = clampf(float(value), float(entry.get("min", 0.0)), float(entry.get("max", 9999.0)))
	_values[key] = value
	setting_changed.emit(key, value)


## Convenience: is HUD in simple (player-facing) mode?
func is_simple_hud() -> bool:
	return int(get_value("hud_mode")) == 0


## Convenience: is HUD in debug (full-metrics) mode?
func is_debug_hud() -> bool:
	return int(get_value("hud_mode")) == 1


## Return the ordered list of section names (for UI layout).
func get_sections() -> PackedStringArray:
	var seen: Dictionary = {}
	var result: PackedStringArray = PackedStringArray()
	for entry in SCHEMA:
		var sec: String = str(entry.get("section", ""))
		if not seen.has(sec):
			seen[sec] = true
			result.append(sec)
	return result


## Return all schema entries for a given section.
func get_entries_for_section(section: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in SCHEMA:
		if str(entry.get("section", "")) == section:
			result.append(entry)
	return result


func _find_schema(key: String) -> Dictionary:
	for entry in SCHEMA:
		if entry["key"] == key:
			return entry
	return {}
