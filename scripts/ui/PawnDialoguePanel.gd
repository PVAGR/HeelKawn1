extends Control
class_name PawnDialoguePanel

const PANEL_WIDTH: int = 400
const PANEL_HEIGHT: int = 500
const MARGIN: int = 10

var _pawn_id: int = -1
var _pawn_name: String = ""
var _background: ColorRect
var _title_label: Label
var _chat_log: RichTextLabel
var _input_box: LineEdit
var _send_button: Button
var _close_button: Button
var _thinking_label: Label

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	_initialize_ui()

func _initialize_ui() -> void:
	anchor_right = 0
	anchor_bottom = 0
	size = Vector2(PANEL_WIDTH, PANEL_HEIGHT)
	position = Vector2(
		get_viewport_rect().size.x - PANEL_WIDTH - MARGIN,
		MARGIN
	)
	_background = ColorRect.new()
	_background.color = Color(0.05, 0.05, 0.1, 0.92)
	_background.anchor_right = 1
	_background.anchor_bottom = 1
	add_child(_background)
	_title_label = Label.new()
	_title_label.text = "Conversation"
	_title_label.add_theme_color_override("font_color", Color(0.8, 0.8, 1.0))
	_title_label.add_theme_font_size_override("font_size", 16)
	_title_label.position = Vector2(10, 8)
	_title_label.size = Vector2(PANEL_WIDTH - 80, 24)
	add_child(_title_label)
	_close_button = Button.new()
	_close_button.text = "X"
	_close_button.position = Vector2(PANEL_WIDTH - 30, 5)
	_close_button.size = Vector2(24, 24)
	_close_button.pressed.connect(_on_close)
	add_child(_close_button)
	_chat_log = RichTextLabel.new()
	_chat_log.position = Vector2(10, 36)
	_chat_log.size = Vector2(PANEL_WIDTH - 20, PANEL_HEIGHT - 90)
	_chat_log.bbcode_enabled = true
	_chat_log.scroll_active = true
	_chat_log.add_theme_color_override("default_color", Color(0.9, 0.9, 0.95))
	add_child(_chat_log)
	_thinking_label = Label.new()
	_thinking_label.text = ""
	_thinking_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.7))
	_thinking_label.position = Vector2(10, PANEL_HEIGHT - 52)
	_thinking_label.size = Vector2(PANEL_WIDTH - 20, 16)
	add_child(_thinking_label)
	_input_box = LineEdit.new()
	_input_box.position = Vector2(10, PANEL_HEIGHT - 34)
	_input_box.size = Vector2(PANEL_WIDTH - 80, 28)
	_input_box.placeholder_text = "Say something..."
	_input_box.text_submitted.connect(_on_text_submitted)
	add_child(_input_box)
	_send_button = Button.new()
	_send_button.text = "Send"
	_send_button.position = Vector2(PANEL_WIDTH - 65, PANEL_HEIGHT - 35)
	_send_button.size = Vector2(55, 28)
	_send_button.pressed.connect(_on_send)
	add_child(_send_button)
	visible = false
	var dialogue: Node = get_node_or_null("/root/PawnDialogue")
	if dialogue != null:
		if dialogue.has_signal("message_received"):
			dialogue.message_received.connect(_on_message_received)
		if dialogue.has_signal("thinking_started"):
			dialogue.thinking_started.connect(_on_thinking_started)
		if dialogue.has_signal("error_occurred"):
			dialogue.error_occurred.connect(_on_error_occurred)

func open_for_pawn(pawn_id: int, pawn_name: String) -> void:
	_pawn_id = pawn_id
	_pawn_name = pawn_name
	_title_label.text = "Talking to %s" % pawn_name
	_chat_log.clear()
	_input_box.clear()
	_show_system_message("Conversation started with %s." % pawn_name)
	visible = true
	_input_box.grab_focus()
	var dialogue: Node = get_node_or_null("/root/PawnDialogue")
	if dialogue != null and dialogue.has_method("start_conversation"):
		dialogue.start_conversation(pawn_id, pawn_name)

func close_panel() -> void:
	var dialogue: Node = get_node_or_null("/root/PawnDialogue")
	if dialogue != null and dialogue.has_method("end_conversation") and _pawn_id > 0:
		dialogue.end_conversation(_pawn_id)
	_pawn_id = -1
	visible = false

func _on_close() -> void:
	close_panel()

func _on_text_submitted(text: String) -> void:
	_send_message(text)

func _on_send() -> void:
	_send_message(_input_box.text)

func _send_message(text: String) -> void:
	text = text.strip_edges()
	if text.is_empty() or _pawn_id < 0:
		return
	_input_box.clear()
	_append_chat_text("You", text, Color(0.4, 0.8, 1.0))
	var dialogue: Node = get_node_or_null("/root/PawnDialogue")
	if dialogue != null and dialogue.has_method("send_message"):
		dialogue.send_message(_pawn_id, text)

func _on_message_received(pawn_id: int, speaker: String, text: String) -> void:
	if pawn_id != _pawn_id:
		return
	_thinking_label.text = ""
	_append_chat_text(speaker, text, Color(0.6, 1.0, 0.6))

func _on_thinking_started(pawn_id: int) -> void:
	if pawn_id != _pawn_id:
		return
	_thinking_label.text = "%s is thinking..." % _pawn_name

func _on_error_occurred(pawn_id: int, message: String) -> void:
	if pawn_id != _pawn_id:
		return
	_thinking_label.text = ""
	_show_system_message("Error: %s" % message)

func _append_chat_text(speaker: String, text: String, color: Color) -> void:
	_chat_log.append_text("[color=#%s]%s:[/color] %s\n" % [color.to_html(false), speaker, text])

func _show_system_message(text: String) -> void:
	_chat_log.append_text("[color=#666666][i]%s[/i][/color]\n" % text)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		position = Vector2(
			get_viewport_rect().size.x - PANEL_WIDTH - MARGIN,
			MARGIN
		)
