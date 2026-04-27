class_name ObserverHUD
extends CanvasLayer

const PANEL_BG: Color = Color(0.05, 0.06, 0.08, 0.78)
const PANEL_BORDER: Color = Color(0.85, 0.78, 0.40, 0.70)
const FONT_SIZE: int = 16

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
	if is_visible:
		print(
				"[VALIDATION_HUD] Observer overlay now VISIBLE — full world panel + [HARNESS] render on next apply_snapshot."
		)


func is_visible_state() -> bool:
	return visible


func apply_snapshot(snapshot: Dictionary) -> void:
	var full_world: String = _world_governance_block(snapshot)
	if not visible:
		if _world_text != null:
			_world_text.text = (
					"[b][HARNESS_PANEL][/b] overlay hidden — text pre-baked; toggle Observer on to view.\n"
					+ _validation_harness_hud_line(snapshot)
			)
		return
	_world_text.text = full_world
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


func _validation_harness_hud_line(s: Dictionary) -> String:
	var osdb: bool = bool(s.get("validation_os_debug_build", false))
	var sess_req: bool = bool(s.get("validation_session_const_requested", false))
	var sess_eff: bool = bool(s.get("validation_session", false))
	var clean: bool = bool(s.get("validation_clean_economy_events", false))
	var truth: bool = bool(s.get("validation_settlement_truth_verify", false))
	var spec: bool = bool(s.get("validation_specialization_log", false))
	var warn: String = ""
	if sess_req and not osdb:
		warn = " [b][!] session const ON but not a debug run — harness DISARMED[/b]"
	var os_s: String = "ON" if osdb else "off"
	var sr_s: String = "ON" if sess_req else "off"
	var se_s: String = "ON" if sess_eff else "off"
	var cl_s: String = "ON" if clean else "off"
	var tr_s: String = "ON" if truth else "off"
	var sp_s: String = "ON" if spec else "off"
	return (
			"[b][HARNESS][/b] OS_debug="
			+ os_s
			+ " session_const="
			+ sr_s
			+ " session_effective="
			+ se_s
			+ " | armed: clean_economy="
			+ cl_s
			+ " settlement_truth_verify="
			+ tr_s
			+ " specialization_log="
			+ sp_s
			+ warn
			+ "\n"
	)


func _world_governance_block(s: Dictionary) -> String:
	return (
		"[b]WORLD STATUS[/b]\n"
		+ "%s\n\n" % str(s.get("world_status_summary", "WORLD STATUS: Unknown"))
		+ "[b]WORLD / GOVERNANCE[/b]\n"
		+ "Speed: %s  Pause: %s\n" % [str(s.get("speed", "1x")), str(s.get("paused", "No"))]
		+ _validation_harness_hud_line(s)
		+ "[i]Logs: anchor continuity on center_region / hyst_key; work-focus = job-proxy, not stock scarcity.[/i]\n"
		+ "Governance (political, separate from material settlement life): %s  Ruler: %s\n"
		% [str(s.get("governance_type", "Anarchy")), str(s.get("ruler_name", "None"))]
		+ "Council Size: %d\n" % int(s.get("council_size", 0))
		+ "Settlement committed (hysteresis-smoothed): %s  [%s]\n" % [
			str(s.get("settlement_state", "Unknown")),
			str(s.get("settlement_state_label", "UNKNOWN")),
		]
		+ "Settlement truth raw (instantaneous material audit): %s\n" % str(s.get("settlement_state_truth_raw", "unknown"))
		+ "Mat: L=%d S=%d W=%d Sp=%d | Sp stockpile-zone overlap hits (bounded)=%d | hyst_key=center_region:%d\n"
		% [
			int(s.get("settlement_material_living", 0)),
			int(s.get("settlement_material_shelter", 0)),
			int(s.get("settlement_material_work", 0)),
			int(s.get("settlement_material_stockpile", 0)),
			int(s.get("settlement_material_stockpile_zone_overlap_hits", 0)),
			int(s.get("settlement_hysteresis_key_center_region", -1)),
		]
		+ "[i]Sp=Y only if a designated stockpile zone overlaps settlement regions (not loose items on ground).[/i]\n"
		+ "Work-focus (proxy): "
		+ str(s.get("work_focus_phase", "UNKNOWN"))
		+ " — "
		+ str(s.get("work_focus_display", "Unspecialized"))
		+ "  ["
		+ str(int(s.get("work_focus_confidence", 0)))
		+ "%]\n"
		+ "[i]Identity from resource-pressure proxy only; not stock scarcity.[/i]\n"
		+ "[b]Camera revival (read-only):[/b] "
		+ str(s.get("camera_revival_digest_plain", "n/a"))
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
		+ "Resource Pressure: W %.2f | S %.2f | O %.2f | F %.2f | T %.2f\n" % [
			float(s.get("resource_pressure_wood", 0.0)),
			float(s.get("resource_pressure_stone", 0.0)),
			float(s.get("resource_pressure_ore_proxy", 0.0)),
			float(s.get("resource_pressure_food", 0.0)),
			float(s.get("resource_pressure_trade", 0.0)),
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
