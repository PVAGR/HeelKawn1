extends PanelContainer
## FirstLaunchWelcome.gd — First-time player welcome popup
##
## Shows on first game launch:
## - Welcome message
## - Keybinds overview (WASD, B, C, I, K, etc.)
## - "Don't show again" checkbox
## - Dismissable, persists to user://

const SAVE_PATH: String = "user://first_launch_shown.json"

var _title_label: Label = null
var _content_label: RichTextLabel = null
var _dont_show_cb: CheckBox = null
var _close_btn: Button = null


func _ready() -> void:
	# Check if already shown
	if _has_been_shown():
		queue_free()
		return
	
	# Build UI
	_build_ui()
	
	# Show on top
	layer = 200
	visible = true


func _build_ui() -> void:
	custom_minimum_size = Vector2(600, 500)
	
	# Style
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.07, 0.09, 0.98)
	style.border_color = Color(0.85, 0.78, 0.40, 0.90)
	style.set_border_width_all(3)
	style.set_corner_radius_all(8)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 20
	style.content_margin_bottom = 20
	add_theme_stylebox_override("panel", style)
	
	# Main layout
	var main_vbox: VBoxContainer = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 15)
	add_child(main_vbox)
	
	# Title
	_title_label = Label.new()
	_title_label.text = "🎮 Welcome to HeelKawn!"
	_title_label.add_theme_font_size_override("font_size", 24)
	_title_label.add_theme_color_override("font_color", Color(0.85, 0.78, 0.40, 1.0))
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(_title_label)
	
	# Subtitle
	var subtitle: Label = Label.new()
	subtitle.text = "A Persistent Myth Engine"
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75, 1.0))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(subtitle)
	
	# Content
	_content_label = RichTextLabel.new()
	_content_label.custom_minimum_size = Vector2(560, 280)
	_content_label.bbcode_enabled = true
	_content_label.fit_content = true
	_content_label.scroll_active = true
	_content_label.add_theme_font_size_override("normal_font_size", 13)
	_content_label.text = _get_welcome_text()
	main_vbox.add_child(_content_label)
	
	# Don't show again
	var cb_row: HBoxContainer = HBoxContainer.new()
	_dont_show_cb = CheckBox.new()
	_dont_show_cb.button_pressed = true  # Default: don't show again
	_dont_show_cb.text = "Don't show this again"
	_dont_show_cb.add_theme_font_size_override("font_size", 12)
	cb_row.add_child(_dont_show_cb)
	main_vbox.add_child(cb_row)
	
	# Close button
	_close_btn = Button.new()
	_close_btn.text = "Start Playing"
	_close_btn.custom_minimum_size = Vector2(200, 40)
	_close_btn.add_theme_font_size_override("font_size", 14)
	_close_btn.pressed.connect(_on_close_pressed)
	main_vbox.add_child(_close_btn)


func _get_welcome_text() -> String:
	return """
[color=#FFD166][b]HeelKawn[/b][/color] is a deterministic world simulation where [i]every sprite matters, every choice echoes.[/i]

[color=#FFD166][b]Essential Keybinds:[/b][/color]
• [color=#44FF44]WASD / Right-click drag[/color] — Move camera
• [color=#44FF44]Mouse wheel[/color] — Zoom in/out
• [color=#44FF44]SPACE[/color] — Pause/Unpause
• [color=#44FF44]1 / 2 / 3[/color] — Game speed (1x, 26x, 100x)

[color=#FFD166][b]Player Actions:[/b][/color]
• [color=#44CCFF]B[/color] — Building menu (9 types: foundation, walls, shelter, etc.)
• [color=#44CCFF]C[/color] — Crafting menu (tools, weapons, torches)
• [color=#44CCFF]I[/color] — Inventory (see what you're carrying)
• [color=#44CCFF]K[/color] — Knowledge panel (see who knows what)
• [color=#44CCFF]Click[/color] — Select pawns, gather resources, interact

[color=#FFD166][b]Tips:[/b][/color]
• Pawns are [b]conscious beings[/b] — they remember, dream, and grow
• Knowledge is [color=#FF4444]fragile[/color] — if the last carrier dies untaught, it's lost forever
• Visit [b]memorials[/b] to read pawn stories and find closure
• [color=#44FF44]F10[/color] opens debug menu with 48+ reports

[color=#888888]This popup won't show again (you can re-enable it in Settings).[/color]
"""


func _has_been_shown() -> bool:
	if FileAccess.file_exists(SAVE_PATH):
		var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
		var json: JSON = JSON.new()
		var error: Error = json.parse(file.get_as_text())
		file.close()
		if error == OK:
			return json.data.get("shown", false)
	return false


func _save_shown() -> void:
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	var json: JSON = JSON.new()
	var data: Dictionary = {"shown": true}
	file.store_string(json.stringify(data))
	file.close()


func _on_close_pressed() -> void:
	if _dont_show_cb.button_pressed:
		_save_shown()
		print("[FirstLaunchWelcome] Will not show again (can reset in Settings)")
	
	visible = false
	queue_free()


## Show welcome popup (called from Main.gd on first launch)
static func show_if_first_launch() -> void:
	# This is handled by _ready() check
	pass
