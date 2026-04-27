class_name FocusInspector
extends CanvasLayer

const PANEL_BG: Color = Color(0.05, 0.06, 0.08, 0.78)
const PANEL_BORDER: Color = Color(0.85, 0.78, 0.40, 0.70)
const FONT_SIZE: int = 13

@onready var _title: RichTextLabel = $Card/Margin/VBox/Title
@onready var _type: RichTextLabel = $Card/Margin/VBox/Type
@onready var _body: RichTextLabel = $Card/Margin/VBox/Body
@onready var _footer: RichTextLabel = $Card/Margin/VBox/Footer


func _ready() -> void:
	layer = 21
	_apply_panel_style($Card)
	visible = false


func set_visible_state(is_visible: bool) -> void:
	visible = is_visible


func is_visible_state() -> bool:
	return visible


func apply_snapshot(snapshot: Dictionary) -> void:
	if not visible:
		return
	_title.text = "[b]%s[/b]" % str(snapshot.get("title", "FOCUS INSPECTOR"))
	_type.text = "Type: [b]%s[/b]" % str(snapshot.get("focus_type", "NONE"))
	var lines: PackedStringArray = snapshot.get("main_lines", PackedStringArray())
	_body.text = "\n".join(lines) if lines is PackedStringArray and not lines.is_empty() else "NO FOCUS\nMove cursor over a pawn, settlement, or tile."
	_footer.text = str(snapshot.get("footer", ""))


func _apply_panel_style(panel: PanelContainer) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_BG
	style.border_color = PANEL_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	panel.add_theme_stylebox_override("panel", style)
	for node in [_title, _type, _body, _footer]:
		if node != null:
			node.add_theme_font_size_override("normal_font_size", FONT_SIZE)
			node.add_theme_font_size_override("bold_font_size", FONT_SIZE)
