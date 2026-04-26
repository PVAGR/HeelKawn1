@tool
extends Control

# ========================================
# EXPORTS
# ========================================

@export_group("UI")
@export var model_dropdown: OptionButton

@export_group("GdScript Tab")
@export var gdscript_output: TextEdit
@export var gdscript_output_copy: Button
@export var gdscript_output_clear: Button
@export var gdscript_output_save: Button
@export var gdscript_output_saveas: Button
@export var gdscript_input: TextEdit
@export var gdscript_input_open: Button
@export var gdscript_input_copy: Button
@export var gdscript_input_clear: Button
@export var gdscript_input_run: Button

@export_group("SceneGenerator Tab")
@export var scene_output: TextEdit
@export var scene_output_copy: Button
@export var scene_output_clear: Button
@export var scene_output_save: Button
@export var scene_output_saveas: Button
@export var scene_input: TextEdit
@export var scene_input_open: Button
@export var scene_input_copy: Button
@export var scene_input_clear: Button
@export var scene_input_run: Button

@export_group("Chat Tab")
@export var chat_output: TextEdit
@export var chat_input: TextEdit
@export var chat_input_open: Button
@export var chat_input_copy: Button
@export var chat_input_clear: Button
@export var chat_input_run: Button

# ========================================
# CONSTANTS
# ========================================

const CONFIG_PATH      = "res://addons/godotassistant/config.cfg"
const GROQ_CHAT_URL    = "https://api.groq.com/openai/v1/chat/completions"
const GROQ_MODELS_URL  = "https://api.groq.com/openai/v1/models"

# Fallback model list if API fetch fails
# Format: [display_name, model_id]
const FALLBACK_MODELS = [
	["Llama 3.3 70B — Default",        "llama-3.3-70b-versatile"],
	["Llama 3.1 8B — Fastest",         "llama-3.1-8b-instant"],
	["GPT-OSS 120B — Best Quality",    "openai/gpt-oss-120b"],
	["GPT-OSS 20B — Balanced",         "openai/gpt-oss-20b"],
	["Qwen 3 32B — Reasoning",         "qwen/qwen3-32b"],
	["Kimi K2 — Coding",               "moonshotai/kimi-k2-instruct"],
	["Llama 4 Maverick — 128K",        "meta-llama/llama-4-maverick-17b-128e-instruct"],
	["Llama 4 Scout — Fast",           "meta-llama/llama-4-scout-17b-16e-instruct"],
]

# Models to exclude from dynamic list (audio, moderation, etc.)
const EXCLUDE_KEYWORDS = [
	"whisper", "guard", "vision", "distil", "tts", "embed"
]

const SYSTEM_GDSCRIPT = """You are a Godot 4 GDScript expert.
Your response must be a complete, valid, runnable .gd file and nothing else.
No explanations. No markdown. No backticks. No code blocks. No extra text before or after.
Start directly with extends or class_name. End with the last line of code.
Do NOT add @tool at the top unless the user explicitly asks for a tool script or editor plugin.
If given an existing script, modify or extend it as instructed and return the full updated script.

STRICT GODOT 4 RULES — never break these:
- CharacterBody3D and CharacterBody2D use the built-in `velocity` property directly. NEVER declare `var velocity` — it already exists.
- move_and_slide() takes NO arguments in Godot 4. NEVER write move_and_slide(velocity, Vector3.UP).
- For gravity use: velocity.y -= ProjectSettings.get_setting("physics/3d/default_gravity") * delta
- For WASD input use Input.get_vector("ui_left","ui_right","ui_up","ui_down") for clean movement.
- @export replaces export keyword. @onready replaces onready.
- Signals: signal my_signal, emit: my_signal.emit(), connect: node.my_signal.connect(callable).
- Use typed variables where possible: var speed: float = 5.0"""

const SYSTEM_TSCN = """You are a Godot 4 scene file expert.
Your response must be a complete, valid .tscn file and nothing else.
No explanations. No markdown. No backticks. No code blocks. No extra text before or after.

=== REAL EXAMPLE — study this format carefully and follow it exactly ===

[gd_scene format=3 uid="uid://3lafummasqcd"]

[node name="Control" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2

[node name="VBoxContainer" type="VBoxContainer" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2

[node name="Label" type="Label" parent="VBoxContainer"]
layout_mode = 2
text = "Hello World"
horizontal_alignment = 1

=== END EXAMPLE ===

STRICT RULES (never break these):
- uid must use format uid://xxxxxxxxxxxx - alphanumeric only, NO dashes, NO UUID format
- Only include load_steps if there are ext_resource or sub_resource entries. Count them exactly.
- Root node has NO parent= field.
- Direct children of root use parent="."
- Deeper nodes use the full path e.g. parent="VBoxContainer/HBoxContainer"
- NEVER use parent="$NodeName" - the $ prefix is invalid in .tscn files
- layout_mode = 2 for children inside containers
- layout_mode = 1 for a container that fills its parent with anchors
- layout_mode = 3 for the root Control node
- Do NOT add script references. No ExtResource for .gd files. No script = on any node.
- Only use built-in Godot 4 node types.
- NEVER use name = "..." as a property inside a node block."""

const SYSTEM_CHAT = """You are a helpful Godot 4 game development assistant.
Help developers with GDScript, scene structure, game logic, and Godot editor features.
Be concise and practical. Always use Godot 4 GDScript syntax.

Key Godot 4 rules to always follow:
- CharacterBody2D/3D have a built-in velocity property — never redeclare it.
- move_and_slide() takes no arguments in Godot 4.
- Use @export, @onready, @tool instead of Godot 3 keywords.
- Signals: signal_name.emit() and signal_name.connect(callable).
- For gravity: velocity.y -= ProjectSettings.get_setting("physics/3d/default_gravity") * delta"""

# ========================================
# STATE
# ========================================

var _api_key: String = ""
var _selected_model: String = "llama-3.3-70b-versatile"
var _model_ids: Array = []
var _gdscript_open_path: String = ""
var _scene_open_path: String = ""
var _current_mode: String = ""
var _chat_history: Array = []
var _http_request: HTTPRequest
var _models_http_request: HTTPRequest

# ========================================
# LIFECYCLE
# ========================================

func _ready() -> void:
	# Main request node
	_http_request = HTTPRequest.new()
	add_child(_http_request)
	_http_request.request_completed.connect(_on_request_completed)

	# Separate node just for fetching model list
	_models_http_request = HTTPRequest.new()
	add_child(_models_http_request)
	_models_http_request.request_completed.connect(_on_models_fetched)

	_load_config()
	_connect_signals()

	# Populate dropdown with fallback first, then try to fetch live list
	_populate_dropdown_fallback()
	_fetch_models()

func _reset_ui_state() -> void:
	_chat_history.clear()
	_gdscript_open_path = ""
	_scene_open_path    = ""

	if gdscript_output: gdscript_output.text = ""
	if gdscript_input:  gdscript_input.text  = ""
	if scene_output:    scene_output.text    = ""
	if scene_input:     scene_input.text     = ""
	if chat_output:     chat_output.text     = ""
	if chat_input:      chat_input.text      = ""

	_set_run_buttons_disabled(false)
	print("[GodotAssistant] UI reset to fresh state")

# ========================================
# CONFIG
# ========================================

func _load_config() -> void:
	var cfg = ConfigFile.new()
	var err = cfg.load(CONFIG_PATH)
	if err != OK:
		push_error("[GodotAssistant] Could not load config.cfg (error %d)" % err)
		return
	_api_key = cfg.get_value("keys", "groq_api_key", "")
	print("[GodotAssistant] Config loaded. Groq key length: %d" % _api_key.length())

# ========================================
# MODEL DROPDOWN
# ========================================

func _populate_dropdown_fallback() -> void:
	if not model_dropdown: return
	model_dropdown.clear()
	_model_ids.clear()
	for entry in FALLBACK_MODELS:
		model_dropdown.add_item(entry[0])
		_model_ids.append(entry[1])
	model_dropdown.selected = 0
	_selected_model = _model_ids[0]
	print("[GodotAssistant] Dropdown populated with fallback models")

func _fetch_models() -> void:
	if _api_key.is_empty(): return
	var headers = [
		"Authorization: Bearer " + _api_key,
		"Content-Type: application/json"
	]
	var err = _models_http_request.request(GROQ_MODELS_URL, headers, HTTPClient.METHOD_GET)
	if err != OK:
		print("[GodotAssistant] Could not fetch model list, using fallback")

func _on_models_fetched(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		print("[GodotAssistant] Model fetch failed (code %d), using fallback list" % response_code)
		return

	var json = JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		print("[GodotAssistant] Could not parse model list JSON, using fallback")
		return

	var data = json.get_data()
	var models_raw: Array = data.get("data", [])
	if models_raw.is_empty():
		return

	# Filter to chat-compatible text models only
	var filtered: Array = []
	for m in models_raw:
		var id: String = m.get("id", "")
		if id.is_empty(): continue
		var skip = false
		for kw in EXCLUDE_KEYWORDS:
			if kw in id.to_lower():
				skip = true
				break
		if not skip:
			filtered.append(id)

	if filtered.is_empty():
		return

	# Sort alphabetically
	filtered.sort()

	# Repopulate dropdown
	if not model_dropdown: return
	model_dropdown.clear()
	_model_ids.clear()

	for id in filtered:
		model_dropdown.add_item(id)
		_model_ids.append(id)

	# Try to restore llama-3.3-70b-versatile as default
	var default_idx = _model_ids.find("llama-3.3-70b-versatile")
	if default_idx >= 0:
		model_dropdown.selected = default_idx
		_selected_model = _model_ids[default_idx]
	else:
		model_dropdown.selected = 0
		_selected_model = _model_ids[0]

	print("[GodotAssistant] Loaded %d models from Groq API" % filtered.size())

func _on_model_selected(index: int) -> void:
	if index >= 0 and index < _model_ids.size():
		_selected_model = _model_ids[index]
		print("[GodotAssistant] Model: %s" % _selected_model)

# ========================================
# SIGNAL CONNECTIONS
# ========================================

func _connect_signals() -> void:
	if model_dropdown:
		model_dropdown.item_selected.connect(_on_model_selected)

	if gdscript_input_run:     gdscript_input_run.pressed.connect(_on_gdscript_run)
	if gdscript_input_open:    gdscript_input_open.pressed.connect(_on_gdscript_open)
	if gdscript_input_copy:    gdscript_input_copy.pressed.connect(func(): _copy_text(gdscript_input))
	if gdscript_input_clear:   gdscript_input_clear.pressed.connect(func(): _clear_text(gdscript_input))
	if gdscript_output_copy:   gdscript_output_copy.pressed.connect(func(): _copy_text(gdscript_output))
	if gdscript_output_clear:  gdscript_output_clear.pressed.connect(func(): _clear_text(gdscript_output))
	if gdscript_output_save:   gdscript_output_save.pressed.connect(_on_gdscript_save)
	if gdscript_output_saveas: gdscript_output_saveas.pressed.connect(_on_gdscript_saveas)

	if scene_input_run:        scene_input_run.pressed.connect(_on_scene_run)
	if scene_input_open:       scene_input_open.pressed.connect(_on_scene_open)
	if scene_input_copy:       scene_input_copy.pressed.connect(func(): _copy_text(scene_input))
	if scene_input_clear:      scene_input_clear.pressed.connect(func(): _clear_text(scene_input))
	if scene_output_copy:      scene_output_copy.pressed.connect(func(): _copy_text(scene_output))
	if scene_output_clear:     scene_output_clear.pressed.connect(func(): _clear_text(scene_output))
	if scene_output_save:      scene_output_save.pressed.connect(_on_scene_save)
	if scene_output_saveas:    scene_output_saveas.pressed.connect(_on_scene_saveas)

	if chat_input_run:         chat_input_run.pressed.connect(_on_chat_run)
	if chat_input_open:        chat_input_open.pressed.connect(_on_chat_open)
	if chat_input_copy:        chat_input_copy.pressed.connect(func(): _copy_text(chat_input))
	if chat_input_clear:       chat_input_clear.pressed.connect(func(): _clear_text(chat_input))

# ========================================
# GDSCRIPT TAB
# ========================================

func _on_gdscript_open() -> void:
	_open_file_dialog(["*.gd ; GDScript Files", "*.tscn ; Scene Files"], func(path: String):
		_gdscript_open_path = path
		gdscript_input.text = FileAccess.get_file_as_string(path)
	)

func _on_gdscript_run() -> void:
	if not _validate_credentials(): return
	var prompt = gdscript_input.text.strip_edges()
	if prompt.is_empty():
		_show_error("Prompt is empty.")
		return
	gdscript_output.text = "Generating..."
	_set_run_buttons_disabled(true)
	_send_request(SYSTEM_GDSCRIPT, prompt, "gdscript")

func _on_gdscript_save() -> void:
	if gdscript_output.text.is_empty():
		_show_error("Nothing to save.")
		return
	if _gdscript_open_path.is_empty():
		_on_gdscript_saveas()
		return
	_write_file(_gdscript_open_path, gdscript_output.text)

func _on_gdscript_saveas() -> void:
	if gdscript_output.text.is_empty():
		_show_error("Nothing to save.")
		return
	_save_file_dialog("*.gd ; GDScript Files", func(path: String):
		if not path.ends_with(".gd"):
			path += ".gd"
		_gdscript_open_path = path
		_write_file(path, gdscript_output.text)
	)

# ========================================
# SCENE TAB
# ========================================

func _on_scene_open() -> void:
	_open_file_dialog(["*.tscn ; Scene Files"], func(path: String):
		_scene_open_path = path
		scene_input.text = FileAccess.get_file_as_string(path)
	)

func _on_scene_run() -> void:
	if not _validate_credentials(): return
	var prompt = scene_input.text.strip_edges()
	if prompt.is_empty():
		_show_error("Prompt is empty.")
		return
	scene_output.text = "Generating..."
	_set_run_buttons_disabled(true)
	_send_request(SYSTEM_TSCN, prompt, "scene")

func _on_scene_save() -> void:
	if scene_output.text.is_empty():
		_show_error("Nothing to save.")
		return
	if _scene_open_path.is_empty():
		_on_scene_saveas()
		return
	_write_file(_scene_open_path, scene_output.text)

func _on_scene_saveas() -> void:
	if scene_output.text.is_empty():
		_show_error("Nothing to save.")
		return
	_save_file_dialog("*.tscn ; Scene Files", func(path: String):
		if not path.ends_with(".tscn"):
			path += ".tscn"
		_scene_open_path = path
		_write_file(path, scene_output.text)
	)

# ========================================
# CHAT TAB
# ========================================

func _on_chat_open() -> void:
	_open_file_dialog(["*.gd ; GDScript Files", "*.tscn ; Scene Files"], func(path: String):
		var file_content = FileAccess.get_file_as_string(path)
		chat_input.text = "[File: %s]\n%s\n\n%s" % [path.get_file(), file_content, chat_input.text]
	)

func _on_chat_run() -> void:
	if not _validate_credentials(): return
	var prompt = chat_input.text.strip_edges()
	if prompt.is_empty():
		_show_error("Prompt is empty.")
		return
	_chat_history.append({"role": "user", "content": prompt})
	chat_output.text += "\n\nYou:\n%s\n\nThinking..." % prompt
	_set_run_buttons_disabled(true)
	_send_request(SYSTEM_CHAT, prompt, "chat")

# ========================================
# REQUEST
# ========================================

func _send_request(system_prompt: String, user_prompt: String, mode: String) -> void:
	_current_mode = mode

	var messages: Array = [{"role": "system", "content": system_prompt}]
	if mode == "chat" and _chat_history.size() > 1:
		for i in range(_chat_history.size() - 1):
			messages.append(_chat_history[i])
	messages.append({"role": "user", "content": user_prompt})

	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer " + _api_key
	]
	var body = {
		"model":       _selected_model,
		"messages":    messages,
		"max_tokens":  4096,
		"temperature": 0.2
	}

	print("[GodotAssistant] Sending | model: %s | mode: %s" % [_selected_model, mode])
	var error = _http_request.request(GROQ_CHAT_URL, headers, HTTPClient.METHOD_POST, JSON.stringify(body))
	if error != OK:
		_on_request_failed("HTTP request error: %s" % error)

# ========================================
# RESPONSE
# ========================================

func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_set_run_buttons_disabled(false)

	if result != HTTPRequest.RESULT_SUCCESS:
		_on_request_failed("HTTP transport error: %s" % result)
		return

	var raw = body.get_string_from_utf8()

	if response_code != 200:
		push_error("[GodotAssistant] API error %d: %s" % [response_code, raw])
		match response_code:
			401: _on_request_failed("Invalid Groq API key — check config.cfg")
			429: _on_request_failed("Rate limit hit — try a different model or wait")
			400: _on_request_failed("Model not supported — try a different model")
			_:   _on_request_failed("API error %d" % response_code)
		return

	var json = JSON.new()
	if json.parse(raw) != OK:
		_on_request_failed("Failed to parse API response.")
		return

	var choices = json.data.get("choices", [])
	if choices.is_empty():
		_on_request_failed("No choices in response.")
		return

	var content: String = choices[0].get("message", {}).get("content", "").strip_edges()
	if content.is_empty():
		_on_request_failed("Empty response from Groq.")
		return

	_handle_response(content)

func _handle_response(content: String) -> void:
	match _current_mode:
		"gdscript":
			content = _strip_code_fences(content)
			if not (content.begins_with("extends") or content.begins_with("class_name") or content.begins_with("@tool")):
				content = _extract_code_block(content)
				if content.is_empty():
					_on_request_failed("AI returned invalid GDScript. Try rephrasing.")
					return
			gdscript_output.text = content
		"scene":
			content = _strip_code_fences(content)
			content = _sanitize_tscn(content)
			if not content.begins_with("[gd_scene"):
				_on_request_failed("AI returned invalid .tscn. Try rephrasing.")
				return
			scene_output.text = content
		"chat":
			_chat_history.append({"role": "assistant", "content": content})
			var out = chat_output.text.trim_suffix("Thinking...")
			chat_output.text = out + "\nAssistant:\n%s" % content
			chat_input.text = ""

func _on_request_failed(message: String) -> void:
	push_error("[GodotAssistant] %s" % message)
	_set_run_buttons_disabled(false)
	match _current_mode:
		"gdscript": gdscript_output.text = "Error: %s" % message
		"scene":    scene_output.text    = "Error: %s" % message
		"chat":     chat_output.text    += "\nError: %s" % message

# ========================================
# SANITIZERS
# ========================================

func _strip_code_fences(text: String) -> String:
	var lines = text.split("\n")
	var result: PackedStringArray = []
	var in_code_block = false
	for line in lines:
		var stripped = line.strip_edges()
		if stripped.begins_with("```"):
			in_code_block = !in_code_block
			continue
		if not in_code_block and stripped.begins_with("`") and stripped.ends_with("`"):
			continue
		result.append(line)
	return "\n".join(result).strip_edges()

func _extract_code_block(text: String) -> String:
	var lines = text.split("\n")
	var in_code_block = false
	var code_lines = []
	for line in lines:
		if line.strip_edges().begins_with("```"):
			in_code_block = !in_code_block
			continue
		if in_code_block:
			code_lines.append(line)
	if code_lines.size() > 0:
		return "\n".join(code_lines).strip_edges()
	return ""

func _sanitize_tscn(tscn: String) -> String:
	var lines = tscn.split("\n")
	var cleaned: PackedStringArray = []
	for line in lines:
		var s = line.strip_edges()
		var skip = false
		if s.begins_with("[ext_resource") and ".gd" in s:
			skip = true
		if s.begins_with("script =") and ("ExtResource" in s or ".gd" in s):
			skip = true
		if s.begins_with("name = "):
			skip = true
		if not skip:
			var fixed = line
			if fixed.contains("uid=\"") and not fixed.contains("uid=\"uid://"):
				var uid_start = fixed.find("uid=\"") + 5
				var uid_end   = fixed.find("\"", uid_start)
				if uid_end > uid_start:
					var old_uid = fixed.substr(uid_start, uid_end - uid_start)
					var new_uid = "uid://" + old_uid.replace("-", "").left(12)
					fixed = fixed.substr(0, uid_start - 5) + "uid=\"" + new_uid + "\"" + fixed.substr(uid_end + 1)
			if fixed.contains("parent=\"$"):
				fixed = fixed.replace("parent=\"$", "parent=\"")
			if fixed.contains("load_steps=0"):
				fixed = fixed.replace(" load_steps=0", "")
			cleaned.append(fixed)
	return "\n".join(cleaned).strip_edges()

# ========================================
# HELPERS
# ========================================

func _set_run_buttons_disabled(disabled: bool) -> void:
	if gdscript_input_run: gdscript_input_run.disabled = disabled
	if scene_input_run:    scene_input_run.disabled    = disabled
	if chat_input_run:     chat_input_run.disabled     = disabled

func _validate_credentials() -> bool:
	if _api_key.is_empty():
		_show_error("Groq API key missing. Add groq_api_key to config.cfg.")
		return false
	return true

func _open_file_dialog(filters: Array, callback: Callable) -> void:
	var dialog = EditorFileDialog.new()
	dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	dialog.access = EditorFileDialog.ACCESS_RESOURCES
	for f in filters:
		dialog.add_filter(f)
	dialog.file_selected.connect(callback)
	dialog.canceled.connect(func(): dialog.queue_free())
	EditorInterface.get_base_control().add_child(dialog)
	dialog.popup_centered_ratio(0.7)

func _save_file_dialog(filter: String, callback: Callable) -> void:
	var dialog = EditorFileDialog.new()
	dialog.file_mode = EditorFileDialog.FILE_MODE_SAVE_FILE
	dialog.access = EditorFileDialog.ACCESS_RESOURCES
	dialog.add_filter(filter)
	dialog.file_selected.connect(callback)
	dialog.canceled.connect(func(): dialog.queue_free())
	EditorInterface.get_base_control().add_child(dialog)
	dialog.popup_centered_ratio(0.7)

func _write_file(path: String, content: String) -> void:
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(content)
		file.close()
		EditorInterface.get_resource_filesystem().scan()
		print("[GodotAssistant] Saved: %s" % path)
	else:
		_show_error("Failed to write file: %s" % path)

func _copy_text(target: TextEdit) -> void:
	if target and not target.text.is_empty():
		DisplayServer.clipboard_set(target.text)

func _clear_text(target: TextEdit) -> void:
	if target:
		target.text = ""

func _show_error(message: String) -> void:
	push_error("[GodotAssistant] %s" % message)
	var dialog = AcceptDialog.new()
	dialog.title = "GodotAssistant"
	dialog.dialog_text = message
	dialog.confirmed.connect(func(): dialog.queue_free())
	EditorInterface.get_base_control().add_child(dialog)
	dialog.popup_centered()
