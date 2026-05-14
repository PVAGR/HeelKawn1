extends Node
## Runtime game settings registry. Provides get/set with change notifications
## so UI and simulation systems can react immediately when the player adjusts
## a slider or checkbox in the Settings panel.
##
## Each setting has a schema entry (key, label, type, default, bounds).
## Values are stored in a flat dict and persisted to user://settings.json.

signal setting_changed(key: String, new_value: Variant)

const SAVE_PATH: String = "user://settings.json"

## Schema: defines every setting the UI can expose.
## type: "bool" | "int" | "float" | "enum"
## For int/float: "min", "max", "step" control slider range.
## For enum: "options" is an Array of String labels (index is the value).
const SCHEMA: Array[Dictionary] = [
	# ── Graphics ─────────────────────────────────────────
	{
		"key": "resolution",
		"label": "Resolution",
		"section": "Graphics",
		"type": "enum",
		"options": ["1280x720", "1600x900", "1920x1080", "2560x1440"],
		"default": 0,
	},
	{
		"key": "window_mode",
		"label": "Window Mode",
		"section": "Graphics",
		"type": "enum",
		"options": ["Windowed", "Borderless", "Fullscreen"],
		"default": 0,
	},
	{
		"key": "vsync",
		"label": "VSync",
		"section": "Graphics",
		"type": "bool",
		"default": true,
	},
	# ── Display ──────────────────────────────────────────
	{
		"key": "hud_mode",
		"label": "HUD Mode",
		"section": "Display",
		"type": "enum",
		"options": ["Simple", "Debug"],
		"default": 1,  # 1 = Debug (full info)
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
		"min": 10,
		"max": 200,
		"step": 10,
		"default": 200,
	},
	{
		"key": "frame_budget_ms",
		"label": "Frame Budget (ms)",
		"section": "Simulation",
		"type": "int",
		"min": 16,
		"max": 100,
		"step": 2,
		"default": 16,
	},
	{
		"key": "hud_refresh_fast",
		"label": "HUD Refresh (Fast)",
		"section": "Simulation",
		"type": "int",
		"min": 1,
		"max": 8,
		"step": 1,
		"default": 2,
	},
	{
		"key": "hud_refresh_ultra",
		"label": "HUD Refresh (Ultra)",
		"section": "Simulation",
		"type": "int",
		"min": 1,
		"max": 12,
		"step": 1,
		"default": 4,
	},
	{
		"key": "hud_refresh_extreme",
		"label": "HUD Refresh (Extreme)",
		"section": "Simulation",
		"type": "int",
		"min": 1,
		"max": 16,
		"step": 1,
		"default": 6,
	},
	{
		"key": "hud_refresh_max",
		"label": "HUD Refresh (Max)",
		"section": "Simulation",
		"type": "int",
		"min": 1,
		"max": 20,
		"step": 1,
		"default": 8,
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
	# ── Audio ────────────────────────────────────────────
	{
		"key": "master_volume",
		"label": "Master Volume",
		"section": "Audio",
		"type": "int",
		"min": 0,
		"max": 100,
		"step": 5,
		"default": 80,
	},
	{
		"key": "sfx_volume",
		"label": "SFX Volume",
		"section": "Audio",
		"type": "int",
		"min": 0,
		"max": 100,
		"step": 5,
		"default": 70,
	},
	{
		"key": "event_sounds",
		"label": "Event Sounds",
		"section": "Audio",
		"type": "bool",
		"default": true,
	},
]

var _values: Dictionary = {}


func _ready() -> void:
	# Initialize all settings to defaults first
	for entry in SCHEMA:
		_values[entry["key"]] = entry["default"]
	# Then overlay persisted values (if any)
	_load()
	# Apply display settings on startup
	_apply_display_settings()
	setting_changed.connect(_on_setting_changed)


func _on_setting_changed(key: String, _new_value: Variant) -> void:
	if key == "resolution" or key == "window_mode" or key == "vsync":
		_apply_display_settings()


const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
]


func _apply_display_settings() -> void:
	# Resolution
	var res_idx: int = int(get_value("resolution"))
	if res_idx >= 0 and res_idx < RESOLUTIONS.size():
		var res: Vector2i = RESOLUTIONS[res_idx]
		DisplayServer.window_set_size(res)
		# Center the window after resize
		var screen_size: Vector2i = DisplayServer.screen_get_size()
		var pos: Vector2i = Vector2i(
			maxi(0, (screen_size.x - res.x) / 2),
			maxi(0, (screen_size.y - res.y) / 2),
		)
		DisplayServer.window_set_position(pos)
	# Window mode
	var mode_idx: int = int(get_value("window_mode"))
	match mode_idx:
		0: DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		1: DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		2: DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	# VSync
	if bool(get_value("vsync")):
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)


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
	save()


## Persist current values to user://settings.json.
func save() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return
	var data: Dictionary = {}
	for key in _values:
		data[key] = _values[key]
	file.store_string(JSON.stringify(data, "\t"))
	file.close()


## Load persisted values from disk, overwriting defaults.
func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var text: String = file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		return
	var data: Dictionary = json.data
	for key in data:
		if _values.has(key):
			_values[key] = data[key]


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
