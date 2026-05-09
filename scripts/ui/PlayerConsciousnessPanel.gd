extends CanvasLayer
class_name PlayerConsciousnessPanel

## Player Consciousness Panel — shows the player their pawn's inner life.
## Displays memories, dreams, trauma level, self-awareness, core beliefs,
## and subconscious desires from PawnConsciousness.
##
## Attach to scene root or create on demand. Use open_for_player() to show.

signal panel_closed()

const PANEL_BG: Color = Color(0.05, 0.06, 0.08, 0.92)
const PANEL_BORDER: Color = Color(0.85, 0.78, 0.40, 0.80)
const FONT_SIZE: int = 12

var _panel: PanelContainer = null
var _title: RichTextLabel = null
var _content: RichTextLabel = null
var _close_button: Button = null
var _refresh_button: Button = null
var _player_id: String = "player"


func _ready() -> void:
	layer = 120
	visible = false
	_build_ui()


func open_for_player(player_id: String = "player") -> void:
	_player_id = player_id
	visible = true
	_refresh()


func close_panel() -> void:
	visible = false
	panel_closed.emit()


func _refresh() -> void:
	if _content == null:
		return
	
	var summary: Dictionary = IncarnationManager.get_player_consciousness_summary(_player_id)
	
	if not summary.get("incarnated", false):
		_content.text = "[color=#888888]You are not incarnated. Enter a pawn to see their consciousness.[/color]"
		return
	
	var lines: Array[String] = []
	
	var pawn_id: int = summary.get("pawn_id", -1)
	var consciousness: Dictionary = PawnConsciousness.get_consciousness(pawn_id)
	
	# Header
	lines.append("[b][color=#FFD700]=== YOUR CONSCIOUSNESS ===[/color][/b]")
	lines.append("")
	
	# Self-awareness
	var awareness_level: int = consciousness.get("self_awareness", 0)
	var awareness_name: String = PawnConsciousness.get_awareness_name(awareness_level)
	lines.append("[b]Self-Awareness:[/b] Level %d — [color=%s]%s[/color]" % [
		awareness_level, _awareness_color(awareness_level), awareness_name
	])
	lines.append("")
	
	# Trauma
	var trauma: float = consciousness.get("trauma_level", 0.0)
	var trauma_bar: String = _bar(trauma, 100.0, 20)
	lines.append("[b]Trauma:[/b] [color=%s]%.1f%%[/color] %s" % [_trauma_color(trauma), trauma, trauma_bar])
	lines.append("")
	
	# Growth
	var growth: int = consciousness.get("growth_points", 0)
	lines.append("[b]Growth Points:[/b] %d" % [growth])
	var next_level_req: int = max(1, awareness_level * awareness_level * 1000)
	lines.append("[b]Next Awareness:[/b] %d / %d" % [growth, next_level_req])
	lines.append("")
	
	# Core beliefs
	var beliefs: Array = consciousness.get("core_beliefs", [])
	lines.append("[b][color=#81C784]--- CORE BELIEFS ---[/color][/b]")
	if beliefs.is_empty():
		lines.append("  [color=#888888]No strong beliefs formed yet.[/color]")
	else:
		for belief in beliefs:
			lines.append("  • [color=#81C784]%s[/color]" % [str(belief)])
	lines.append("")
	
	# Subconscious desires
	var desires: Array = consciousness.get("subconscious_desires", [])
	lines.append("[b][color=#64B5F6]--- SUBCONSCIOUS DESIRES ---[/color][/b]")
	if desires.is_empty():
		lines.append("  [color=#888888]No deep desires formed yet.[/color]")
	else:
		for desire in desires:
			lines.append("  → [color=#64B5F6]%s[/color]" % [str(desire)])
	lines.append("")
	
	# Recent dreams
	var dreams: Array = IncarnationManager.get_player_dreams(5, _player_id)
	lines.append("[b][color=#CE93D8]--- RECENT DREAMS ---[/color][/b]")
	if dreams.is_empty():
		lines.append("  [color=#888888]No dreams recorded yet.[/color]")
	else:
		for dream in dreams:
			var content: String = str(dream.get("content", "a dream"))
			var theme: String = str(dream.get("theme", "unknown"))
			var lucid: bool = bool(dream.get("lucid", false))
			var lucid_tag: String = " [color=#FFD700][LUCID][/color]" if lucid else ""
			lines.append("  [color=#CE93D8]%s[/color] (theme: %s)%s" % [content, theme, lucid_tag])
	lines.append("")
	
	# Memories (top 10 by significance)
	lines.append("[b][color=#FF8A65]--- SIGNIFICANT MEMORIES ---[/color][/b]")
	var all_memories: Array = consciousness.get("memories", [])
	if all_memories.is_empty():
		lines.append("  [color=#888888]No memories yet. Go do something worth remembering.[/color]")
	else:
		# Sort by importance * abs(emotion)
		var sorted: Array = all_memories.duplicate()
		sorted.sort_custom(func(a, b):
			var sa: float = float(a.get("importance", 1)) * absf(float(a.get("emotion", 0.0)))
			var sb: float = float(b.get("importance", 1)) * absf(float(b.get("emotion", 0.0)))
			return sa > sb
		)
		var count: int = 0
		for mem in sorted:
			if count >= 10:
				break
			var desc: String = str(mem.get("description", "something happened"))
			var emotion: float = float(mem.get("emotion", 0.0))
			var imp: int = int(mem.get("importance", 1))
			var cat: String = str(mem.get("category", "general"))
			var emotion_str: String = ""
			if emotion > 50:
				emotion_str = "[color=#81C784]+%.0f[/color]" % emotion
			elif emotion < -50:
				emotion_str = "[color=#E57373]%.0f[/color]" % emotion
			else:
				emotion_str = "[color=#FFD54F]%.0f[/color]" % emotion
			lines.append("  [%s] [imp=%d] [cat=%s] %s" % [emotion_str, imp, cat, desc])
			count += 1
	
	_content.text = "\n".join(lines)


func _build_ui() -> void:
	var root: Control = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	
	var dim: ColorRect = ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.45)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(dim)
	
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.offset_left = -350.0
	_panel.offset_top = -280.0
	_panel.offset_right = 350.0
	_panel.offset_bottom = 280.0
	
	var pstyle: StyleBoxFlat = StyleBoxFlat.new()
	pstyle.bg_color = PANEL_BG
	pstyle.border_color = PANEL_BORDER
	pstyle.set_border_width_all(1)
	pstyle.set_corner_radius_all(6)
	pstyle.content_margin_left = 12
	pstyle.content_margin_right = 12
	pstyle.content_margin_top = 10
	pstyle.content_margin_bottom = 10
	_panel.add_theme_stylebox_override("panel", pstyle)
	root.add_child(_panel)
	
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	_panel.add_child(vbox)
	
	var header: HBoxContainer = HBoxContainer.new()
	vbox.add_child(header)
	
	_title = RichTextLabel.new()
	_title.text = "[b]Consciousness[/b]"
	_title.add_theme_font_size_override("normal_font_size", 16)
	_title.add_theme_font_size_override("bold_font_size", 16)
	header.add_child(_title)
	
	header.add_spacer(true)
	
	_refresh_button = Button.new()
	_refresh_button.text = "Refresh"
	_refresh_button.pressed.connect(_refresh)
	header.add_child(_refresh_button)
	
	_close_button = Button.new()
	_close_button.text = "Close"
	_close_button.pressed.connect(close_panel)
	header.add_child(_close_button)
	
	_content = RichTextLabel.new()
	_content.add_theme_font_size_override("normal_font_size", FONT_SIZE)
	_content.add_theme_font_size_override("bold_font_size", FONT_SIZE)
	_content.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.custom_minimum_size = Vector2(660, 460)
	_content.text = "[color=#888888]Loading...[/color]"
	vbox.add_child(_content)


func _awareness_color(level: int) -> String:
	match level:
		0: return "#888888"
		1: return "#A5D6A7"
		2: return "#66BB6A"
		3: return "#43A047"
		4: return "#FFD700"
		5: return "#FF6F00"
		_: return "#888888"


func _trauma_color(trauma: float) -> String:
	if trauma > 75: return "#E57373"
	if trauma > 50: return "#FFB74D"
	if trauma > 25: return "#FFD54F"
	return "#81C784"


func _bar(value: float, max_val: float, width: int) -> String:
	var ratio: float = clampf(value / max_val, 0.0, 1.0)
	var filled: int = int(ratio * width)
	var empty: int = width - filled
	return "[color=#81C784]%s[/color][color=#444444]%s[/color]" % ["#" * filled, "." * empty]
