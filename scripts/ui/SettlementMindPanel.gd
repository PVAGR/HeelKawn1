extends CanvasLayer
class_name SettlementMindPanel

signal panel_closed()

const PANEL_BG: Color = Color(0.05, 0.06, 0.08, 0.92)
const PANEL_BORDER: Color = Color(0.4, 0.7, 0.4, 0.8)
const FONT_SIZE: int = 11

var _panel: PanelContainer = null
var _content: RichTextLabel = null

func _ready() -> void:
	layer = 110
	visible = false
	_build_ui()

func open_for_settlement(center_region: int) -> void:
	visible = true
	_refresh(center_region)

func close_panel() -> void:
	visible = false
	panel_closed.emit()

func _refresh(center_region: int) -> void:
	if _content == null:
		return
	var sm: Node = get_node_or_null("/root/SettlementMemory")
	if sm == null:
		_content.text = "[color=#888888]SettlementMemory not available.[/color]"
		return
	var st: Dictionary = _find_settlement(center_region, sm)
	if st.is_empty():
		_content.text = "[color=#888888]No settlement found at region %d.[/color]" % center_region
		return
	var lines: Array[String] = []
	var name: String = str(st.get("name", "Unnamed"))
	var state: String = str(st.get("state", "unknown"))
	var center: int = int(st.get("center_region", -1))
	var pop: int = 0
	var sp: Node = get_node_or_null("/root/WorldAI")
	var active_settlements = sp.get("active_settlements") if sp != null else {}
	var sai: Node = active_settlements.get(center) if active_settlements is Dictionary else null
	lines.append("[b][color=#81c784]=== %s ===[/color][/b]" % [name])
	lines.append("State: [color=%s]%s[/color] | ID: %d" % [_state_color(state), state, center])
	var regions_val = st.get("regions")
	var regions: Array = regions_val if regions_val != null else []
	var total_regions: int = 0
	for r in regions:
		if r is PackedInt32Array:
			total_regions += r.size()
	lines.append("Regions: %d clusters" % regions.size())

	# SettlementAI mind
	if sai != null:
		var gov_val = sai.get("government_type")
		var gov: int = gov_val if gov_val != null else 0
		var gov_names: Array = ["Tribal", "Chiefdom", "Monarchy", "Republic", "Theocracy", "Technocracy", "Anarchy"]
		var gov_name: String = gov_names[gov] if gov >= 0 and gov < gov_names.size() else "Unknown"
		var focus_val = sai.get("development_focus")
		var focus: int = focus_val if focus_val != null else 0
		var focus_names: Array = ["Survival", "Expansion", "Trade", "Knowledge", "Military", "Artistic", "Balanced"]
		var focus_name: String = focus_names[focus] if focus >= 0 and focus < focus_names.size() else "Unknown"
		lines.append("")
		lines.append("[b]--- GOVERNMENT & FOCUS ---[/b]")
		lines.append("Government: [color=#bb77ee]%s[/color]" % gov_name)
		lines.append("Development Focus: [color=#66bb6a]%s[/color]" % focus_name)
		var leader_val = sai.get("leader_id")
		var leader: int = leader_val if leader_val != null else -1
		if leader > 0:
			lines.append("Leader ID: %d" % leader)
		var goals_val = sai.get("collective_goals")
		var goals: Array = goals_val if goals_val != null else []
		if goals.size() > 0:
			lines.append("")
			lines.append("[b]--- COLLECTIVE GOALS ---[/b]")
			for g in goals:
				var gt_val = g.get("goal_type")
				var gt: String = str(gt_val if gt_val != null else "unknown")
				var prio_val = g.get("priority")
				var prio: int = int(prio_val if prio_val != null else 0)
				lines.append("  [color=#ffd54f]%s[/color] (priority: %d)" % [gt, prio])
		var norms_val = sai.get("cultural_norms")
		var norms: Array = norms_val if norms_val != null else []
		if norms.size() > 0:
			lines.append("")
			lines.append("[b]--- CULTURAL NORMS ---[/b]")
			for n in norms:
				var nn_val = n.get("norm_name")
				var nn: String = str(nn_val if nn_val != null else "")
				if not nn.is_empty():
					lines.append("  • [color=#81c784]%s[/color]" % nn)
		var treaties_val = sai.get("active_treaties")
		var treaties: Array = treaties_val if treaties_val != null else []
		if treaties.size() > 0:
			lines.append("")
			lines.append("[b]--- DIPLOMACY (%d treaties) ---[/b]" % treaties.size())
	else:
		lines.append("")
		lines.append("[color=#888888]SettlementAI not initialized for this settlement.[/color]")
	lines.append("")
	lines.append("[color=#555555]Press J to close[/color]")
	_content.text = "\n".join(lines)

func _find_settlement(center_region: int, sm: Node) -> Dictionary:
	var settlements_val = sm.get("settlements") if sm != null else null
	var settlements: Array = settlements_val if settlements_val != null else []
	for s in settlements:
		if s is Dictionary:
			var center_val = s.get("center_region")
			var center_reg = int(center_val if center_val != null else -1)
			if center_reg == center_region:
			return s
	return {}

func _state_color(state: String) -> String:
	match state:
		"flourishing": return "#66bb6a"
		"stable": return "#81c784"
		"declining": return "#ffd54f"
		"collapsed": return "#ef5350"
		_: return "#888888"

func _build_ui() -> void:
	var root: Control = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	var dim: ColorRect = ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.35)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(dim)
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.offset_left = -300.0
	_panel.offset_top = -220.0
	_panel.offset_right = 300.0
	_panel.offset_bottom = 220.0
	var pstyle: StyleBoxFlat = StyleBoxFlat.new()
	pstyle.bg_color = PANEL_BG
	pstyle.border_color = PANEL_BORDER
	pstyle.set_border_width_all(1)
	pstyle.set_corner_radius_all(6)
	pstyle.content_margin_left = 10
	pstyle.content_margin_right = 10
	pstyle.content_margin_top = 8
	pstyle.content_margin_bottom = 8
	_panel.add_theme_stylebox_override("panel", pstyle)
	root.add_child(_panel)
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	_panel.add_child(vbox)
	var header: HBoxContainer = HBoxContainer.new()
	vbox.add_child(header)
	var title: Label = Label.new()
	title.text = "Settlement Mind"
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9))
	header.add_child(title)
	header.add_spacer(true)
	var close_btn: Button = Button.new()
	close_btn.text = "Close"
	close_btn.pressed.connect(func(): close_panel())
	header.add_child(close_btn)
	_content = RichTextLabel.new()
	_content.add_theme_font_size_override("normal_font_size", FONT_SIZE)
	_content.add_theme_font_size_override("bold_font_size", FONT_SIZE)
	_content.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.custom_minimum_size = Vector2(560, 360)
	_content.text = "[color=#888888]Open with J when a pawn is selected (shows their settlement)[/color]"
	vbox.add_child(_content)
