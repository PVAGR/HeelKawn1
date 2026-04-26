class_name ObserverHUD
extends CanvasLayer

const PANEL_BG: Color = Color(0.05, 0.06, 0.08, 0.78)
const PANEL_BORDER: Color = Color(0.85, 0.78, 0.40, 0.70)
const FONT_SIZE: int = 13

@onready var _world_text: RichTextLabel = $WorldGovernancePanel/Margin/Text
@onready var _demo_text: RichTextLabel = $DemoEconomyPanel/Margin/Text
@onready var _conflict_text: RichTextLabel = $ConflictWarPanel/Margin/Text
@onready var _kernel_text: RichTextLabel = $KernelMemoryPanel/Margin/Text


func _ready() -> void:
	layer = 20
	_apply_panel_style($WorldGovernancePanel)
	_apply_panel_style($DemoEconomyPanel)
	_apply_panel_style($ConflictWarPanel)
	_apply_panel_style($KernelMemoryPanel)
	visible = false


func set_visible_state(is_visible: bool) -> void:
	visible = is_visible


func is_visible_state() -> bool:
	return visible


func apply_snapshot(snapshot: Dictionary) -> void:
	if not visible:
		return
	_world_text.text = _world_governance_block(snapshot)
	_demo_text.text = _demo_economy_block(snapshot)
	_conflict_text.text = _conflict_block(snapshot)
	_kernel_text.text = _kernel_block(snapshot)


func _apply_panel_style(panel: PanelContainer) -> void:
	if panel == null:
		return
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
	var label: RichTextLabel = panel.get_node_or_null("Margin/Text")
	if label != null:
		label.add_theme_font_size_override("normal_font_size", FONT_SIZE)
		label.add_theme_font_size_override("bold_font_size", FONT_SIZE)


func _world_governance_block(s: Dictionary) -> String:
	return (
		"[b]WORLD STATUS[/b]\n"
		+ "%s\n\n" % str(s.get("world_status_summary", "WORLD STATUS: Unknown"))
		+ "[b]WORLD / GOVERNANCE[/b]\n"
		+ "Speed: %s  Pause: %s\n" % [str(s.get("speed", "1x")), str(s.get("paused", "No"))]
		+ "Governance: %s  Ruler: %s\n" % [str(s.get("governance_type", "Anarchy")), str(s.get("ruler_name", "None"))]
		+ "Council Size: %d\n" % int(s.get("council_size", 0))
		+ "Settlement: %s  [%s]" % [
			str(s.get("settlement_state", "Unknown")),
			str(s.get("settlement_state_label", "UNKNOWN")),
		]
	)


func _demo_economy_block(s: Dictionary) -> String:
	return (
		"[b]DEMOGRAPHICS / ECONOMY[/b]\n"
		+ "Pawns: %d  Children: %d\n" % [int(s.get("total_pawns", 0)), int(s.get("children_count", 0))]
		+ "Wildlife: R:%d D:%d T:%d\n" % [
			int(s.get("wild_rabbit", 0)),
			int(s.get("wild_deer", 0)),
			int(s.get("wild_total", 0)),
		]
		+ "Jobs Open: %d  Claimed: %d\n" % [int(s.get("jobs_open", 0)), int(s.get("jobs_claimed", 0))]
		+ "Food Pressure: %d%% [%s]\n" % [
			int(round(float(s.get("food_pressure", 0.0)) * 100.0)),
			str(s.get("food_pressure_label", "LOW")),
		]
		+ "Housing Pressure: %d%% [%s]\n" % [
			int(round(float(s.get("housing_pressure", 0.0)) * 100.0)),
			str(s.get("housing_pressure_label", "LOW")),
		]
		+ "Resource Pressure: W %.2f | S %.2f | O %.2f\n" % [
			float(s.get("resource_pressure_wood", 0.0)),
			float(s.get("resource_pressure_stone", 0.0)),
			float(s.get("resource_pressure_ore_proxy", 0.0)),
		]
		+ "Intent: %s" % str(s.get("intent_summary", "n/a"))
	)


func _conflict_block(s: Dictionary) -> String:
	var history_lines: PackedStringArray = s.get("recent_history_lines", PackedStringArray())
	var history_text: String = "No recent high-signal events."
	if history_lines is PackedStringArray and not history_lines.is_empty():
		history_text = "\n".join(history_lines)
	return (
		"[b]CONFLICT / WAR[/b]\n"
		+ "War State: %s  [%s]\n" % [str(s.get("war_state", "peace")), str(s.get("war_state_label", "PEACE"))]
		+ "Target Settlement: %s\n" % str(s.get("war_target", "None"))
		+ "BattleMaster: %s\n" % str(s.get("battlemaster_name", "None"))
		+ "Active Enemies: %d\n" % int(s.get("active_enemies", 0))
		+ "Battlefield Mode: %s\n\n" % str(s.get("battlefield_mode", "Idle"))
		+ "[b]RECENT HISTORY[/b]\n"
		+ history_text
	)


func _kernel_block(s: Dictionary) -> String:
	return (
		"[b]SYSTEM STAMP[/b]\n"
		+ "[font=monospace]%s[/font]" % str(s.get("footer_stamp", "Tick 0 | Day 1 | Determinism Pending"))
	)
