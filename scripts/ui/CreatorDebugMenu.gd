class_name CreatorDebugMenu
extends CanvasLayer
## F10 Diagnostics Panel â€” hidden by default, toggled via F10.
## Displays live diagnostic data and allows exporting to clipboard.

var _panel: PanelContainer
var _vbox: VBoxContainer
var _data_vbox: VBoxContainer
var _update_timer: float = 0.0
var _update_interval: float = 0.5  # Update twice per second

# Labels for live data
var _fps_label: Label
var _total_pawns_label: Label
var _active_jobs_label: Label
var _open_jobs_label: Label
var _tick_count_label: Label
var _year_day_label: Label
var _settlements_label: Label
var _idle_pawns_label: Label
var _working_pawns_label: Label
var _starving_pawns_label: Label
var _sleeping_pawns_label: Label
var _recent_events_label: Label
var _report_status_label: Label
var _snapshot_status_label: Label = null
var _hover_tile: Vector2i = Vector2i(-1, -1)
var _designation_mode: String = ""

func _ready() -> void:
	layer = 10
	visible = false
	# CRITICAL: CanvasLayer must process input even when game is at 200x
	# or paused â€” otherwise GUI events are starved by simulation ticks.
	process_mode = Node.PROCESS_MODE_ALWAYS

	_panel = PanelContainer.new()
	_panel.name = "Panel"
	_panel.custom_minimum_size = Vector2(500, 0)
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.anchor_left = 0.5
	_panel.anchor_top = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_bottom = 0.5
	_panel.offset_left = -250
	_panel.offset_top = -300
	_panel.offset_right = 250
	_panel.offset_bottom = 0
	_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.06, 0.1, 0.92)
	style.border_color = Color(0.3, 0.35, 0.45, 0.8)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	_panel.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	_panel.add_child(margin)

	var scroll := ScrollContainer.new()
	scroll.name = "ScrollContainer"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(480, 400)
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	margin.add_child(scroll)

	_vbox = VBoxContainer.new()
	_vbox.name = "VBoxContainer"
	_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_vbox.add_theme_constant_override("separation", 6)
	scroll.add_child(_vbox)

	_build_header()
	_build_ai_diagnostic_area()
	_build_live_data_display()
	_build_report_buttons()
	_build_export_button()

func toggle_menu() -> void:
	visible = not visible

func _build_header() -> void:
	var title := Label.new()
	title.text = "AI WORLD SNAPSHOT (read-only diagnostic)"
	title.add_theme_font_size_override("font_size", 16)
	_vbox.add_child(title)

	var sep := HSeparator.new()
	_vbox.add_child(sep)

func _build_live_data_display() -> void:
	# Performance & Scale
	var perf_label := Label.new()
	perf_label.text = "PERFORMANCE & SCALE"
	perf_label.add_theme_font_size_override("font_size", 14)
	perf_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.2))
	_vbox.add_child(perf_label)
	
	_fps_label = Label.new()
	_fps_label.text = "FPS: --"
	_fps_label.add_theme_font_size_override("font_size", 12)
	_vbox.add_child(_fps_label)
	
	_total_pawns_label = Label.new()
	_total_pawns_label.text = "Total Pawns: --"
	_total_pawns_label.add_theme_font_size_override("font_size", 12)
	_vbox.add_child(_total_pawns_label)
	
	_active_jobs_label = Label.new()
	_active_jobs_label.text = "Active Jobs: --"
	_active_jobs_label.add_theme_font_size_override("font_size", 12)
	_vbox.add_child(_active_jobs_label)
	
	_open_jobs_label = Label.new()
	_open_jobs_label.text = "Open Jobs: --"
	_open_jobs_label.add_theme_font_size_override("font_size", 12)
	_vbox.add_child(_open_jobs_label)
	
	var sep1 := HSeparator.new()
	_vbox.add_child(sep1)
	
	# Simulation State
	var sim_label := Label.new()
	sim_label.text = "SIMULATION STATE"
	sim_label.add_theme_font_size_override("font_size", 14)
	sim_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.2))
	_vbox.add_child(sim_label)
	
	_tick_count_label = Label.new()
	_tick_count_label.text = "Tick: --"
	_tick_count_label.add_theme_font_size_override("font_size", 12)
	_vbox.add_child(_tick_count_label)
	
	_year_day_label = Label.new()
	_year_day_label.text = "Year/Day: --"
	_year_day_label.add_theme_font_size_override("font_size", 12)
	_vbox.add_child(_year_day_label)
	
	_settlements_label = Label.new()
	_settlements_label.text = "Settlements: --"
	_settlements_label.add_theme_font_size_override("font_size", 12)
	_vbox.add_child(_settlements_label)
	
	var sep2 := HSeparator.new()
	_vbox.add_child(sep2)
	
	# Pawn Vitals
	var vitals_label := Label.new()
	vitals_label.text = "PAWN VITALS"
	vitals_label.add_theme_font_size_override("font_size", 14)
	vitals_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.2))
	_vbox.add_child(vitals_label)
	
	_idle_pawns_label = Label.new()
	_idle_pawns_label.text = "Idle: --"
	_idle_pawns_label.add_theme_font_size_override("font_size", 12)
	_vbox.add_child(_idle_pawns_label)
	
	_working_pawns_label = Label.new()
	_working_pawns_label.text = "Working: --"
	_working_pawns_label.add_theme_font_size_override("font_size", 12)
	_vbox.add_child(_working_pawns_label)
	
	_starving_pawns_label = Label.new()
	_starving_pawns_label.text = "Starving: --"
	_starving_pawns_label.add_theme_font_size_override("font_size", 12)
	_vbox.add_child(_starving_pawns_label)
	
	_sleeping_pawns_label = Label.new()
	_sleeping_pawns_label.text = "Sleeping: --"
	_sleeping_pawns_label.add_theme_font_size_override("font_size", 12)
	_vbox.add_child(_sleeping_pawns_label)
	
	var sep3 := HSeparator.new()
	_vbox.add_child(sep3)
	
	# Recent History
	var history_label := Label.new()
	history_label.text = "RECENT HISTORY"
	history_label.add_theme_font_size_override("font_size", 14)
	history_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.2))
	_vbox.add_child(history_label)
	
	_recent_events_label = Label.new()
	_recent_events_label.text = "Recent Events: --"
	_recent_events_label.add_theme_font_size_override("font_size", 12)
	_recent_events_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_recent_events_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_vbox.add_child(_recent_events_label)

func _build_export_button() -> void:
	var sep := HSeparator.new()
	_vbox.add_child(sep)
	
	var export_btn := Button.new()
	export_btn.text = "Export Diagnostics to Clipboard"
	export_btn.custom_minimum_size = Vector2(460, 36)
	export_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	export_btn.add_theme_font_size_override("font_size", 14)
	export_btn.pressed.connect(_on_export_button_pressed)
	_vbox.add_child(export_btn)
	
	var hint := Label.new()
	hint.text = "Data updates every 0.5s\nPress F10 to close."
	hint.add_theme_font_size_override("font_size", 10)
	hint.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_vbox.add_child(hint)
	
	# Add AI Diagnostic Area
	# (function defined below)

func _build_ai_diagnostic_area() -> void:
	var sep := HSeparator.new()
	_vbox.add_child(sep)
	
	var title := Label.new()
	title.text = "AI DIAGNOSTICS"
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(0.45, 0.9, 0.55))
	_vbox.add_child(title)
	
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 4)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_vbox.add_child(grid)
	
	var ai_reports := [
		["COPY AI WORLD SNAPSHOT", "_on_copy_ai_snapshot"],
		["GENERATE AI DEBUG BUNDLE", "_on_generate_ai_bundle"],
		["OVERVIEW", "_on_ai_overview"],
		["PAWNS", "_on_ai_pawns"],
		["WORK", "_on_ai_work"],
		["CIVILIZATION", "_on_ai_civilization"],
		["WORLD", "_on_ai_world"],
		["ENGINE", "_on_ai_engine"],
		["ANOMALIES", "_on_ai_anomalies"]
	]
	
	for r in ai_reports:
		var btn := Button.new()
		btn.text = str(r[0])
		btn.custom_minimum_size = Vector2(220, 32)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.add_theme_font_size_override("font_size", 12)
		btn.pressed.connect(_on_ai_button_pressed.bind(str(r[1])))
		grid.add_child(btn)
	
	_snapshot_status_label = Label.new()
	_snapshot_status_label.text = "last snapshot: none"
	_snapshot_status_label.add_theme_font_size_override("font_size", 11)
	_snapshot_status_label.add_theme_color_override("font_color", Color(0.5, 0.85, 0.6))
	_vbox.add_child(_snapshot_status_label)

func _process(delta: float) -> void:
	if not visible:
		return
		
	_update_timer += delta
	if _update_timer >= _update_interval:
		_update_timer = 0.0
		_update_live_data()

func _update_live_data() -> void:
	# Performance & Scale
	var fps = Engine.get_frames_per_second()
	_fps_label.text = "FPS: %d" % fps
	
	# Total Pawns
	var total_pawns = 0
	var pawns_node = get_node_or_null("/root/Main/WorldViewport/PawnSpawner")
	if pawns_node != null:
		total_pawns = pawns_node.get_child_count()
	_total_pawns_label.text = "Total Pawns: %d" % total_pawns
	
	# Jobs
	var open_jobs = 0
	if JobManager != null and JobManager.has_method("open_count"):
		open_jobs = JobManager.open_count()
	_open_jobs_label.text = "Open Jobs: %d" % open_jobs
	
	# Active Jobs (total jobs - open jobs would be claimed/active jobs)
	var active_jobs = 0
	if JobManager != null:
		# We'll approximate active jobs as total pawns working for now
		# A more accurate count would require tracking job claims
		active_jobs = _count_working_pawns()
	_active_jobs_label.text = "Active Jobs: %d" % active_jobs
	
	# Simulation State
	var tick_count = 0
	var days_elapsed = 0.0
	if GameManager != null:
		tick_count = GameManager.tick_count
		days_elapsed = tick_count / 1000.0  # 1000 ticks per day
	_tick_count_label.text = "Tick: %d" % tick_count
	
	var year = int(days_elapsed / 365)
	var day = int(fmod(days_elapsed, 365))
	_year_day_label.text = "Year/Day: %d/%d" % [year, day]
	
	# Settlements
	var settlements = 0
	if SettlementMemory != null and SettlementMemory.has_method("get_formal_settlement_count"):
		settlements = SettlementMemory.get_formal_settlement_count()
	_settlements_label.text = "Settlements: %d" % settlements
	
	# Pawn Vitals
	var vitals := _collect_pawn_vitals()
	_idle_pawns_label.text = "Idle: %d" % vitals["idle"]
	_working_pawns_label.text = "Working: %d" % vitals["working"]
	_starving_pawns_label.text = "Starving: %d" % vitals["starving"]
	_sleeping_pawns_label.text = "Sleeping: %d" % vitals["sleeping"]
	
	# Recent History
	var recent_events = "No events recorded."
	if WorldMemory != null:
		var events = []
		if WorldMemory.has_method("get_recent_events"):
			events = WorldMemory.get_recent_events(5)  # Get last 5 events
		elif WorldMemory.has_method("get_events"):
			var all_events = WorldMemory.get_events()
			if all_events is Array:
				events = all_events.slice(-5)  # Last 5 events
		elif WorldMemory.get("events") is Array:
			var all_events = WorldMemory.events
			events = all_events.slice(-5)  # Last 5 events
		
		if events.size() > 0:
			var event_strings := PackedStringArray()
			for event in events:
				if event is Dictionary:
					var desc = event.get("description", str(event))
					event_strings.append("- %s" % desc)
				else:
					event_strings.append("- %s" % str(event))
			recent_events = "\n".join(event_strings)
		_recent_events_label.text = "Recent Events:\n%s" % recent_events
	else:
		_recent_events_label.text = "Recent Events: --"

## Read-only live vitals over every live HeelKawnian pawn under PawnSpawner.
## Uses the canonical typed HeelKawnian API (get_pawn_data/get_state) and never
## mutates simulation state. Hunger semantics: hunger decays from 100 toward 0;
## at/below HUNGER_EMERGENCY a pawn is in the true starvation guard band.
func _collect_pawn_vitals() -> Dictionary:
	var vitals := {
		"total": 0,
		"idle": 0,
		"walking": 0,
		"working": 0,
		"sleeping": 0,
		"eating": 0,
		"starving": 0,
	}
	var pawns_node = get_node_or_null("/root/Main/WorldViewport/PawnSpawner")
	if pawns_node == null:
		return vitals
	for child in pawns_node.get_children():
		var pawn = child as HeelKawnian
		if pawn == null:
			continue
		var pawn_data = pawn.get_pawn_data()
		if pawn_data == null:
			continue
		vitals["total"] += 1
		match pawn.get_state():
			HeelKawnian.State.IDLE:
				vitals["idle"] += 1
			HeelKawnian.State.WALKING_TO_JOB:
				vitals["walking"] += 1
			HeelKawnian.State.WORK, HeelKawnian.State.WORKING, HeelKawnian.State.HAULING:
				vitals["working"] += 1
			HeelKawnian.State.SLEEP, HeelKawnian.State.SLEEPING:
				vitals["sleeping"] += 1
			HeelKawnian.State.EATING:
				vitals["eating"] += 1
		if pawn_data.hunger <= HeelKawnian.HUNGER_EMERGENCY:
			vitals["starving"] += 1
	return vitals

func _count_working_pawns() -> int:
	return int(_collect_pawn_vitals()["working"])

func _on_export_button_pressed() -> void:
	var diagnostics_text = _gather_diagnostics_text()
	
	# Copy to clipboard
	DisplayServer.clipboard_set(diagnostics_text)
	
	# Save to file
	var file = FileAccess.open("user://heelkawn_diagnostics.txt", FileAccess.WRITE)
	if file != null:
		file.store_string(diagnostics_text)
		file.close()
	
	# Provide visual feedback
	var btn = Button.new()
	btn.text = "Exported!"
	btn.disabled = true
	btn.custom_minimum_size = Vector2(460, 30)
	
	# Replace the export button temporarily
	var index = _vbox.get_child_count() - 2  # Before the hint label
	if index >= 0:
		var old_btn = _vbox.get_child(index)
		if old_btn is Button and old_btn.text == "Export Diagnostics to Clipboard":
			_vbox.remove_child(old_btn)
			_vbox.add_child(btn)
			_vbox.move_child(btn, index)
			
			# Restore after 2 seconds
			call_deferred("_restore_export_button", old_btn, index)

# AI Diagnostic Methods
func _on_copy_ai_snapshot() -> void:
	var snapshot_dict = _build_ai_snapshot_dict()
	var snapshot_text = _snapshot_text(snapshot_dict)
	DisplayServer.clipboard_set(snapshot_text)
	var file = FileAccess.open("user://heelkawn_world_snapshot.txt", FileAccess.WRITE)
	if file != null:
		file.store_string(snapshot_text)
		file.close()
	_snapshot_status_label.text = "Copied snapshot to clipboard and file"
	call_deferred("_clear_status_label", 2.0)

func _on_generate_ai_bundle() -> void:
	var bundle_dir = "user://diagnostics/heelkawn_diag_tick_%d_%s" % [GameManager.tick_count, Time.get_datetime_string_from_system().replace(":", "-")]
	var dir_access = DirAccess.open(bundle_dir)
	if dir_access == null:
		DirAccess.make_dir_absolute(bundle_dir)
	
	# Create required files
	var snapshot_dict = _build_ai_snapshot_dict()
	var snapshot_text = _snapshot_text(snapshot_dict)
	var snapshot_json = _to_json(snapshot_dict)
	
	var anomalies = _detect_anomalies(snapshot_dict)
	var anomalies_text = _format_anomalies(anomalies)
	var recent_log = _read_recent_log()
	var screenshot_saved = _save_screenshot(bundle_dir)
	
	# Write files
	var readme = _generate_readme(snapshot_dict, screenshot_saved)
	var files_to_write = [
		["README.txt", readme],
		["world_snapshot.txt", snapshot_text],
		["world_snapshot.json", snapshot_json],
		["anomalies.txt", anomalies_text],
		["recent_log.txt", recent_log]
	]
	
	if screenshot_saved:
		files_to_write.append(["screenshot.png", null])  # Already saved by _save_screenshot
	
	for file_info in files_to_write:
		var file_path = bundle_dir + "/" + file_info[0]
		var file = FileAccess.open(file_path, FileAccess.WRITE)
		if file != null:
			if file_info[1] != null:
				file.store_string(file_info[1])
			file.close()
	
	_snapshot_status_label.text = "Bundle generated: %s" % bundle_dir
	call_deferred("_clear_status_label", 3.0)

func _on_ai_overview() -> void:
	var snapshot_dict = _build_ai_snapshot_dict()
	var overview = _get_overview_section(snapshot_dict)
	print(overview)
	_snapshot_status_label.text = "Overview printed to log"
	call_deferred("_clear_status_label", 1.5)

func _on_ai_pawns() -> void:
	var snapshot_dict = _build_ai_snapshot_dict()
	var pawns_section = _get_pawns_section(snapshot_dict)
	print(pawns_section)
	_snapshot_status_label.text = "Pawns section printed to log"
	call_deferred("_clear_status_label", 1.5)

func _on_ai_work() -> void:
	var snapshot_dict = _build_ai_snapshot_dict()
	var work_section = _get_work_section(snapshot_dict)
	print(work_section)
	_snapshot_status_label.text = "Work section printed to log"
	call_deferred("_clear_status_label", 1.5)

func _on_ai_civilization() -> void:
	var snapshot_dict = _build_ai_snapshot_dict()
	var civ_section = _get_civilization_section(snapshot_dict)
	print(civ_section)
	_snapshot_status_label.text = "Civilization section printed to log"
	call_deferred("_clear_status_label", 1.5)

func _on_ai_world() -> void:
	var snapshot_dict = _build_ai_snapshot_dict()
	var world_section = _get_world_section(snapshot_dict)
	print(world_section)
	_snapshot_status_label.text = "World section printed to log"
	call_deferred("_clear_status_label", 1.5)

func _on_ai_engine() -> void:
	var snapshot_dict = _build_ai_snapshot_dict()
	var engine_section = _get_engine_section(snapshot_dict)
	print(engine_section)
	_snapshot_status_label.text = "Engine section printed to log"
	call_deferred("_clear_status_label", 1.5)

func _on_ai_anomalies() -> void:
	var snapshot_dict = _build_ai_snapshot_dict()
	var anomalies = _detect_anomalies(snapshot_dict)
	var anomalies_text = _format_anomalies(anomalies)
	print(anomalies_text)
	_snapshot_status_label.text = "Anomalies printed to log"
	call_deferred("_clear_status_label", 1.5)

func _on_ai_button_pressed(method_name: String) -> void:
	if has_method(method_name):
		call(method_name)
	else:
		print("[F10] No such AI diagnostic method: %s" % method_name)

func _clear_status_label(seconds: float) -> void:
	var timer := get_tree().create_timer(seconds)
	timer.timeout.connect(func():
		if is_instance_valid(_snapshot_status_label):
			_snapshot_status_label.text = "last snapshot: none"
	)

func _restore_export_button(original_btn: Button, index: int) -> void:
	var current_btn = _vbox.get_child(index)
	if current_btn is Button and current_btn.text == "Exported!":
		_vbox.remove_child(current_btn)
		_vbox.add_child(original_btn)
		_vbox.move_child(original_btn, index)

func _gather_diagnostics_text() -> String:
	var text := PackedStringArray()
	text.append("HEELKAWN DIAGNOSTICS REPORT")
	text.append("=".repeat(50))
	text.append("")
	
	# Performance & Scale
	text.append("PERFORMANCE & SCALE")
	text.append("-".repeat(20))
	var fps = Engine.get_frames_per_second()
	text.append("FPS: %d" % fps)
	
	var total_pawns = 0
	var pawns_node = get_node_or_null("/root/Main/WorldViewport/PawnSpawner")
	if pawns_node != null:
		total_pawns = pawns_node.get_child_count()
	text.append("Total Pawns: %d" % total_pawns)
	
	var open_jobs = 0
	if JobManager != null and JobManager.has_method("open_count"):
		open_jobs = JobManager.open_count()
	text.append("Open Jobs: %d" % open_jobs)
	
	var active_jobs = _count_working_pawns()
	text.append("Active Jobs: %d" % active_jobs)
	text.append("")
	
	# Simulation State
	text.append("SIMULATION STATE")
	text.append("-".repeat(20))
	var tick_count = 0
	var days_elapsed = 0.0
	if GameManager != null:
		tick_count = GameManager.tick_count
		days_elapsed = tick_count / 1000.0
	text.append("Tick: %d" % tick_count)
	
	var year = int(days_elapsed / 365)
	var day = int(fmod(days_elapsed, 365))
	text.append("Year/Day: %d/%d" % [year, day])
	
	var settlements = 0
	if SettlementMemory != null and SettlementMemory.has_method("get_formal_settlement_count"):
		settlements = SettlementMemory.get_formal_settlement_count()
	text.append("Settlements: %d" % settlements)
	text.append("")
	
	# Pawn Vitals
	text.append("PAWN VITALS")
	text.append("-".repeat(20))
	var vitals := _collect_pawn_vitals()
	text.append("Idle: %d" % vitals["idle"])
	text.append("Working: %d" % vitals["working"])
	text.append("Starving: %d" % vitals["starving"])
	text.append("Sleeping: %d" % vitals["sleeping"])
	text.append("")
	
	# Recent History (capped: counts by type + oldest 20 + newest 100 + settlement events + omitted=N)
	text.append("RECENT HISTORY")
	text.append("-".repeat(20))
	if WorldMemory != null and WorldMemory.has_method("get_events"):
		var cap_lines: PackedStringArray = _format_capped_history(WorldMemory.get_events())
		if cap_lines.is_empty():
			text.append("No events recorded.")
		else:
			text.append_array(cap_lines)
	else:
		text.append("No events recorded.")

	return "\n".join(text)

## Capped history block: counts by event type, oldest 20, newest 100,
## important settlement events, and an omitted=N footer. Prevents a multi-
## thousand-event world history from flooding F10 exports or the log.
func _format_capped_history(events: Array) -> PackedStringArray:
	var out := PackedStringArray()
	if events.is_empty():
		return out
	var total: int = events.size()
	var by_type: Dictionary = {}
	for e in events:
		if not e is Dictionary:
			continue
		var ev: Dictionary = e as Dictionary
		var typ: String = str(ev.get("type", ev.get("k", "unknown")))
		by_type[typ] = int(by_type.get(typ, 0)) + 1
	var type_keys: Array = by_type.keys()
	type_keys.sort()
	out.append("Total events: %d" % total)
	var type_pairs := PackedStringArray()
	for k in type_keys:
		type_pairs.append("%s=%d" % [k, by_type[k]])
	out.append("By type: %s" % ", ".join(type_pairs))
	var OLDEST_CAP: int = 20
	var NEWEST_CAP: int = 100
	var shown: int = 0
	var omitted: int = maxi(0, total - OLDEST_CAP - NEWEST_CAP)
	out.append("Oldest %d:" % OLDEST_CAP)
	for i in range(mini(OLDEST_CAP, total)):
		var ev: Dictionary = events[i] as Dictionary
		out.append("- [%d] %s" % [int(ev.get("t", ev.get("eid", 0))), str(ev.get("type", ev.get("k", "unknown")))])
		shown += 1
	out.append("Newest %d:" % NEWEST_CAP)
	var start: int = maxi(0, total - NEWEST_CAP)
	for i in range(start, total):
		var ev: Dictionary = events[i] as Dictionary
		out.append("- [%d] %s" % [int(ev.get("t", ev.get("eid", 0))), str(ev.get("type", ev.get("k", "unknown")))])
		shown += 1
	var settlement_events: Array = []
	for e in events:
		if e is Dictionary and str((e as Dictionary).get("type", (e as Dictionary).get("k", ""))).find("settlement") >= 0:
			settlement_events.append(e)
	if settlement_events.size() > 0:
		out.append("Settlement events (%d):" % settlement_events.size())
		var s_start: int = maxi(0, settlement_events.size() - 20)
		for i in range(s_start, settlement_events.size()):
			var ev: Dictionary = settlement_events[i] as Dictionary
			out.append("- [%d] %s" % [int(ev.get("t", ev.get("eid", 0))), str(ev.get("type", ev.get("k", "unknown")))])
	omitted += maxi(0, total - shown)
	out.append("omitted=%d" % omitted)
	return out

# ============================================================================
# REPORTS â€” all output goes to Godot log via print()
# ============================================================================

func _print_full_system_report() -> void:
	print("\n" + "=".repeat(80))
	print("  FULL SYSTEM REPORT")
	print("=".repeat(80))

	# --- GameManager ---
	print("\n--- GameManager ---")
	if GameManager != null:
		print("  tick_count    : %d" % GameManager.tick_count)
		print("  game_speed    : %dx" % GameManager.game_speed)
		print("  is_paused     : %s" % str(GameManager.is_paused))
		print("  days_elapsed  : %.1f" % (GameManager.tick_count / 1000.0))
	else:
		print("  NOT LOADED")

	# --- TickManager ---
	print("\n--- TickManager ---")
	if TickManager != null:
		print("  speed_index   : %d" % TickManager.get_speed_index())
		print("  current_tick  : %d" % TickManager.current_tick)
	else:
		print("  NOT LOADED")

	# --- World ---
	print("\n--- World ---")
	var wn := get_node_or_null("/root/Main/WorldViewport/World")
	if wn != null:
		if wn.get("data") != null:
			print("  dimensions    : %dx%d" % [WorldData.WIDTH, WorldData.HEIGHT])
			print("  total_tiles   : %d" % (WorldData.WIDTH * WorldData.HEIGHT))
		if wn.has_method("settlement_count"):
			print("  settlements   : %d" % wn.settlement_count())
	else:
		print("  World node not found")

	# --- WorldMemory ---
	print("\n--- WorldMemory ---")
	if WorldMemory != null:
		print("  loaded        : yes")
	else:
		print("  NOT LOADED")

	# --- WorldMeaning ---
	print("\n--- WorldMeaning ---")
	if WorldMeaning != null:
		print("  regions       : %d" % WorldMeaning.region_count())
	else:
		print("  NOT LOADED")

	# --- SettlementMemory ---
	print("\n--- SettlementMemory ---")
	if SettlementMemory != null:
		if SettlementMemory.has_method("get_formal_settlement_count"):
			print("  formal        : %d" % SettlementMemory.get_formal_settlement_count())
		if SettlementMemory.has_method("get_formal_settlements"):
			var sarr: Array = SettlementMemory.get_formal_settlements()
			for s in sarr:
				if s is Dictionary and s.has("name"):
					print("    - %s" % s["name"])
		if SettlementMemory.has_method("get_proto_sites"):
			print("  proto_sites   : %d" % SettlementMemory.get_proto_sites().size())
		if SettlementMemory.has_method("get_active_polity_count"):
			print("  polities      : %d" % SettlementMemory.get_active_polity_count())
	else:
		print("  NOT LOADED")

	# --- MemoryManager ---
	print("\n--- MemoryManager ---")
	if MemoryManager != null:
		if MemoryManager.has_method("site_count"):
			print("  sacred_sites  : %d" % MemoryManager.site_count())
	else:
		print("  NOT LOADED")

	# --- JobManager ---
	print("\n--- JobManager ---")
	if JobManager != null:
		print("  open_jobs     : %d" % JobManager.open_count())
	else:
		print("  NOT LOADED")

	# --- StockpileManager ---
	print("\n--- StockpileManager ---")
	if StockpileManager != null:
		print("  zones         : %d" % StockpileManager.zone_count())
		if StockpileManager.has_method("total_count_of"):
			print("  wood          : %d" % StockpileManager.total_count_of(Item.Type.WOOD))
			print("  stone         : %d" % StockpileManager.total_count_of(Item.Type.STONE))
			print("  food          : %d" % StockpileManager.total_count_of(Item.Type.FOOD))
	else:
		print("  NOT LOADED")

	# --- ColonySimServices ---
	print("\n--- ColonySimServices ---")
	if ColonySimServices != null:
		if ColonySimServices.has_method("get_housing_pressure"):
			print("  housing_press : %.3f" % ColonySimServices.get_housing_pressure())
		if ColonySimServices.has_method("get_food_pressure"):
			print("  food_pressure : %.3f" % ColonySimServices.get_food_pressure())
	else:
		print("  NOT LOADED")

	# --- KinshipSystem ---
	print("\n--- KinshipSystem ---")
	if KinshipSystem != null:
		print("  households    : %d" % KinshipSystem._households.size())
	else:
		print("  NOT LOADED")

	# --- FactionManager ---
	print("\n--- FactionManager ---")
	if FactionManager != null:
		if FactionManager.has_method("get_faction_ids"):
			print("  factions      : %d" % FactionManager.get_faction_ids().size())
	else:
		print("  NOT LOADED")

	# --- AIAgentManager ---
	print("\n--- AIAgentManager ---")
	if AIAgentManager != null:
		if AIAgentManager.has_method("get_agent_count"):
			print("  agents        : %d" % AIAgentManager.get_agent_count())
	else:
		print("  NOT LOADED")

	# --- WorldAI ---
	print("\n--- WorldAI ---")
	if WorldAI != null:
		print("  loaded        : yes")
		if WorldAI.get("neural_world_matrix") != null:
			print("  neural_states : %d" % WorldAI.neural_world_matrix.size())
		if WorldAI.get("emergent_patterns") != null:
			print("  patterns      : %d" % WorldAI.emergent_patterns.size())
	else:
		print("  NOT LOADED")

	# --- EcologySystem ---
	print("\n--- EcologySystem ---")
	if EcologySystem != null:
		print("  loaded        : yes")
	else:
		print("  NOT LOADED")

	# --- DiseaseSystem ---
	print("\n--- DiseaseSystem ---")
	if DiseaseSystem != null:
		print("  loaded        : yes")
	else:
		print("  NOT LOADED")

	# --- CrimeSystem ---
	print("\n--- CrimeSystem ---")
	if CrimeSystem != null:
		print("  loaded        : yes")
	else:
		print("  NOT LOADED")

	# --- DisasterSystem ---
	print("\n--- DisasterSystem ---")
	if DisasterSystem != null:
		print("  loaded        : yes")
	else:
		print("  NOT LOADED")

	# --- EconomyManager ---
	print("\n--- EconomyManager ---")
	if EconomyManager != null:
		print("  loaded        : yes")
	else:
		print("  NOT LOADED")

	# --- Weather ---
	print("\n--- WeatherSystem ---")
	if WorldEnvironmentManager != null:
		print("  loaded        : yes")
	else:
		print("  NOT LOADED")

	print("\n" + "=".repeat(80))
	print("  END FULL SYSTEM REPORT")
	print("=".repeat(80) + "\n")

func _print_performance_profile() -> void:
	print("\n" + "=".repeat(80))
	print("  PERFORMANCE PROFILE")
	print("=".repeat(80))

	# --- TickProfiler ---
	print("\n--- TickProfiler ---")
	if TickProfiler != null:
		print("  heelkawnian_total_us  : %d (%.2f ms)" % [TickProfiler.cat_total_heelkawnian, float(TickProfiler.cat_total_heelkawnian) / 1000.0])
		print("  bookkeeping_us        : %d (%.2f ms)" % [TickProfiler.cat_bookkeeping, float(TickProfiler.cat_bookkeeping) / 1000.0])
		print("  needs_us              : %d (%.2f ms)" % [TickProfiler.cat_needs, float(TickProfiler.cat_needs) / 1000.0])
		print("  survival_health_us    : %d (%.2f ms)" % [TickProfiler.cat_survival_health, float(TickProfiler.cat_survival_health) / 1000.0])
		print("  cognition_us          : %d (%.2f ms)" % [TickProfiler.cat_cognition, float(TickProfiler.cat_cognition) / 1000.0])
		print("  awareness_us          : %d (%.2f ms)" % [TickProfiler.cat_awareness, float(TickProfiler.cat_awareness) / 1000.0])
		print("  matrix_ai_us          : %d (%.2f ms)" % [TickProfiler.cat_matrix_ai, float(TickProfiler.cat_matrix_ai) / 1000.0])
		print("  social_us             : %d (%.2f ms)" % [TickProfiler.cat_social, float(TickProfiler.cat_social) / 1000.0])
		print("  household_us          : %d (%.2f ms)" % [TickProfiler.cat_household, float(TickProfiler.cat_household) / 1000.0])
		print("  settlement_us         : %d (%.2f ms)" % [TickProfiler.cat_settlement, float(TickProfiler.cat_settlement) / 1000.0])
		print("  state_dispatch_us     : %d (%.2f ms)" % [TickProfiler.cat_state_dispatch, float(TickProfiler.cat_state_dispatch) / 1000.0])
		print("  misc_us               : %d (%.2f ms)" % [TickProfiler.cat_misc, float(TickProfiler.cat_misc) / 1000.0])
		print("  ai_total_us           : %d (%.2f ms)" % [TickProfiler.cat_ai_total, float(TickProfiler.cat_ai_total) / 1000.0])
		print("  main_dispatch_us      : %d (%.2f ms)" % [TickProfiler.cat_main_dispatch, float(TickProfiler.cat_main_dispatch) / 1000.0])
	else:
		print("  NOT LOADED")

	# --- Pawn stride sample ---
	print("\n--- Pawn Stride (sample: HeelKawnian_0) ---")
	var sp := get_node_or_null("/root/Main/WorldViewport/PawnSpawner/HeelKawnian_0")
	if sp != null and sp.has_method("_speed_bucket"):
		print("  speed_bucket           : %d" % sp._speed_bucket())
		print("  fast_forward_stride    : %d" % sp._fast_forward_tick_stride())
		print("  job_claim_interval     : %d" % sp._job_claim_interval_for_speed())
		print("  idle_action_refresh    : %d" % sp._idle_action_refresh_interval_for_speed())
		print("  work_step_interval     : %d" % sp._work_step_interval_for_speed())
	else:
		print("  No sample pawn found")

	# --- TickManager ---
	print("\n--- TickManager ---")
	if TickManager != null:
		print("  speed_index   : %d" % TickManager.get_speed_index())
		print("  current_tick  : %d" % TickManager.current_tick)
		print("  last_tick_us  : %d" % TickManager._last_tick_usec)
	else:
		print("  NOT LOADED")

	# --- AIAgentManager intervals ---
	print("\n--- AIAgentManager ---")
	if AIAgentManager != null:
		if AIAgentManager.has_method("_world_ai_interval_for_speed"):
			print("  world_ai_interval    : %d" % AIAgentManager._world_ai_interval_for_speed())
		if AIAgentManager.has_method("_settlement_ai_interval_for_speed"):
			print("  settlement_ai_int    : %d" % AIAgentManager._settlement_ai_interval_for_speed())
	else:
		print("  NOT LOADED")

	# --- TickRateDecoupler ---
	print("\n--- TickRateDecoupler ---")
	if TickRateDecoupler != null:
		print("  systems_registered   : %d" % TickRateDecoupler.system_intervals.size())
		for sys_name in TickRateDecoupler.system_intervals:
			print("    %s : interval=%d" % [sys_name, TickRateDecoupler.system_intervals[sys_name]])
	else:
		print("  NOT LOADED")

	# --- Pawn counts ---
	print("\n--- Pawn Counts ---")
	var pn := get_node_or_null("/root/Main/WorldViewport/PawnSpawner")
	if pn != null:
		print("  total_in_scene : %d" % pn.get_child_count())
	else:
		print("  pawns node not found")

	print("\n" + "=".repeat(80))
	print("  END PERFORMANCE PROFILE")
	print("=".repeat(80) + "\n")

func _print_ai_memory_state() -> void:
	print("\n" + "=".repeat(80))
	print("  AI & MEMORY STATE")
	print("=".repeat(80))

	# --- WorldAI ---
	print("\n--- WorldAI ---")
	if WorldAI != null:
		if WorldAI.get("neural_world_matrix") != null:
			print("  neural_states     : %d" % WorldAI.neural_world_matrix.size())
			# Show first few keys as sample
			var keys: Array = WorldAI.neural_world_matrix.keys()
			var show: int = mini(keys.size(), 5)
			if show > 0:
				print("  sample_keys       : %s" % str(keys.slice(0, show)))
		if WorldAI.get("emergent_patterns") != null:
			print("  patterns          : %d" % WorldAI.emergent_patterns.size())
			for p in WorldAI.emergent_patterns:
				if p is Dictionary:
					print("    - %s (conf=%.2f)" % [p.get("type", "?"), p.get("confidence", 0.0)])
		if WorldAI.get("civilization_neural_network") != null:
			print("  civ_neural        : %d" % WorldAI.civilization_neural_network.size())
		if WorldAI.get("environmental_neural_network") != null:
			print("  env_neural        : %d" % WorldAI.environmental_neural_network.size())
		if WorldAI.get("cultural_neural_network") != null:
			print("  cultural_neural   : %d" % WorldAI.cultural_neural_network.size())
		if WorldAI.get("economic_neural_network") != null:
			print("  economic_neural   : %d" % WorldAI.economic_neural_network.size())
	else:
		print("  NOT LOADED")

	# --- AIAgentManager ---
	print("\n--- AIAgentManager ---")
	if AIAgentManager != null:
		if AIAgentManager.has_method("get_agent_count"):
			print("  agents            : %d" % AIAgentManager.get_agent_count())
		var ci = AIAgentManager.get("collective_intelligence")
		if ci is Dictionary:
			if ci.has("shared_memory") and ci["shared_memory"] is Dictionary:
				var sm: Dictionary = ci["shared_memory"]
				if sm.has("training_history") and sm["training_history"] is Array:
					print("  training_history  : %d records" % sm["training_history"].size())
	else:
		print("  NOT LOADED")

	# --- CharacterBrainSystem ---
	print("\n--- CharacterBrainSystem ---")
	if CharacterBrainSystem != null:
		print("  loaded            : yes")
	else:
		print("  NOT LOADED")

	# --- PawnAccess ---
	print("\n--- PawnAccess ---")
	if PawnAccess != null:
		print("  loaded            : yes")
		if PawnAccess.has_method("find_alive_pawns"):
			var alive: Array = PawnAccess.find_alive_pawns()
			print("  alive_pawns       : %d" % alive.size())
	else:
		print("  NOT LOADED")

	# --- WorldMemory ---
	print("\n--- WorldMemory ---")
	if WorldMemory != null:
		print("  loaded            : yes")
	else:
		print("  NOT LOADED")

	# --- WorldMeaning ---
	print("\n--- WorldMeaning ---")
	if WorldMeaning != null:
		print("  regions           : %d" % WorldMeaning.region_count())
	else:
		print("  NOT LOADED")

	# --- SettlementMemory ---
	print("\n--- SettlementMemory ---")
	if SettlementMemory != null:
		if SettlementMemory.has_method("get_formal_settlement_count"):
			print("  formal            : %d" % SettlementMemory.get_formal_settlement_count())
		if SettlementMemory.has_method("get_active_polity_count"):
			print("  polities          : %d" % SettlementMemory.get_active_polity_count())
	else:
		print("  NOT LOADED")

	# --- HeelKawnianManager ---
	print("\n--- HeelKawnianManager ---")
	if HeelKawnianManager != null:
		print("  loaded            : yes")
	else:
		print("  NOT LOADED")

	print("\n" + "=".repeat(80))
	print("  END AI & MEMORY STATE")
	print("=".repeat(80) + "\n")

func _print_settlements_pawns() -> void:
	print("\n" + "=".repeat(80))
	print("  SETTLEMENTS & PAWNS")
	print("=".repeat(80))

	# --- Settlements ---
	print("\n--- Settlements ---")
	if SettlementMemory != null:
		if SettlementMemory.has_method("get_formal_settlements"):
			var sarr: Array = SettlementMemory.get_formal_settlements()
			print("  formal_count : %d" % sarr.size())
			for s in sarr:
				if s is Dictionary:
					var sname: String = s.get("name", "?")
					var pop: int = s.get("population", 0)
					print("    - %s (pop=%d)" % [sname, pop])
		if SettlementMemory.has_method("get_proto_sites"):
			var proto: Array = SettlementMemory.get_proto_sites()
			print("  proto_count  : %d" % proto.size())
			for p in proto:
				if p is Dictionary:
					var members: int = p.get("guild_member_count", -1)
					var stable: int = p.get("guild_candidate_stability_ticks", -1)
					var reason: Variant = p.get("guild_candidate_reason", "?")
					print("    - %s (members=%d stability=%d gate=%s)" % [p.get("name", "?"), members, stable, reason])
	else:
		print("  SettlementMemory NOT LOADED")

	# --- Pawns ---
	print("\n--- Pawns ---")
	var vitals := _collect_pawn_vitals()
	print("  total        : %d" % vitals["total"])
	print("  idle         : %d" % vitals["idle"])
	print("  walking      : %d" % vitals["walking"])
	print("  working      : %d" % vitals["working"])
	print("  sleeping     : %d" % vitals["sleeping"])
	print("  eating       : %d" % vitals["eating"])

	# --- Jobs ---
	print("\n--- Jobs ---")
	if JobManager != null:
		print("  open          : %d" % JobManager.open_count())
	else:
		print("  NOT LOADED")

	# --- Households ---
	print("\n--- Households ---")
	if KinshipSystem != null:
		print("  count         : %d" % KinshipSystem._households.size())
	else:
		print("  NOT LOADED")

	# --- Factions ---
	print("\n--- Factions ---")
	if FactionManager != null:
		if FactionManager.has_method("get_faction_ids"):
			var fids: Array = FactionManager.get_faction_ids()
			print("  count         : %d" % fids.size())
			for fid in fids:
				if FactionManager.has_method("get_faction"):
					var fdata: Dictionary = FactionManager.get_faction(fid)
					print("    - id=%d name=%s" % [fid, fdata.get("name", "?")])
	else:
		print("  NOT LOADED")

	# --- MarriageSystem ---
	print("\n--- MarriageSystem ---")
	if MarriageSystem != null:
		print("  loaded        : yes")
	else:
		print("  NOT LOADED")

	# --- PrisonerManager ---
	print("\n--- PrisonerManager ---")
	if PrisonerManager != null:
		print("  loaded        : yes")
	else:
		print("  NOT LOADED")

	print("\n" + "=".repeat(80))
	print("  END SETTLEMENTS & PAWNS")
	print("=".repeat(80) + "\n")

func _print_world_economy() -> void:
	print("\n" + "=".repeat(80))
	print("  WORLD & ECONOMY")
	print("=".repeat(80))

	# --- World ---
	print("\n--- World ---")
	var wn := get_node_or_null("/root/Main/WorldViewport/World")
	if wn != null:
		if wn.get("data") != null:
			print("  dimensions    : %dx%d" % [WorldData.WIDTH, WorldData.HEIGHT])
			print("  total_tiles   : %d" % (WorldData.WIDTH * WorldData.HEIGHT))
	else:
		print("  NOT FOUND")

	# --- StockpileManager ---
	print("\n--- StockpileManager ---")
	if StockpileManager != null:
		print("  zones         : %d" % StockpileManager.zone_count())
		if StockpileManager.has_method("total_count_of"):
			print("  wood          : %d" % StockpileManager.total_count_of(Item.Type.WOOD))
			print("  stone         : %d" % StockpileManager.total_count_of(Item.Type.STONE))
			print("  food          : %d" % StockpileManager.total_count_of(Item.Type.FOOD))
			print("  berry         : %d" % StockpileManager.total_count_of(Item.Type.BERRY))
			print("  meat          : %d" % StockpileManager.total_count_of(Item.Type.MEAT))
			print("  flint         : %d" % StockpileManager.total_count_of(Item.Type.FLINT))
			print("  stick         : %d" % StockpileManager.total_count_of(Item.Type.STICK))
			print("  leather       : %d" % StockpileManager.total_count_of(Item.Type.LEATHER))
			print("  paper         : %d" % StockpileManager.total_count_of(Item.Type.PAPER))
			print("  book          : %d" % StockpileManager.total_count_of(Item.Type.BOOK))
	else:
		print("  NOT LOADED")

	# --- ColonySimServices ---
	print("\n--- ColonySimServices ---")
	if ColonySimServices != null:
		if ColonySimServices.has_method("get_housing_pressure"):
			print("  housing_pressure : %.3f" % ColonySimServices.get_housing_pressure())
		if ColonySimServices.has_method("get_food_pressure"):
			print("  food_pressure    : %.3f" % ColonySimServices.get_food_pressure())
	else:
		print("  NOT LOADED")

	# --- EconomyManager ---
	print("\n--- EconomyManager ---")
	if EconomyManager != null:
		print("  loaded        : yes")
	else:
		print("  NOT LOADED")

	# --- SupplyChainSystem ---
	print("\n--- SupplyChainSystem ---")
	if SupplyChainSystem != null:
		print("  loaded        : yes")
	else:
		print("  NOT LOADED")

	# --- TradeMemory ---
	print("\n--- TradeMemory ---")
	if TradeMemory != null:
		print("  loaded        : yes")
	else:
		print("  NOT LOADED")

	# --- FarmingSystem ---
	print("\n--- FarmingSystem ---")
	if FarmingSystem != null:
		print("  loaded        : yes")
	else:
		print("  NOT LOADED")

	# --- CraftingSystem ---
	print("\n--- CraftingSystem ---")
	if CraftingSystem != null:
		print("  loaded        : yes")
	else:
		print("  NOT LOADED")

	# --- EcologySystem ---
	print("\n--- EcologySystem ---")
	if EcologySystem != null:
		print("  loaded        : yes")
	else:
		print("  NOT LOADED")

	# --- BuildingRegistry ---
	print("\n--- BuildingRegistry ---")
	if BuildingRegistry != null:
		print("  loaded        : yes")
	else:
		print("  NOT LOADED")

	print("\n" + "=".repeat(80))
	print("  END WORLD & ECONOMY")
	print("=".repeat(80) + "\n")

func _print_config_settings() -> void:
	print("\n" + "=".repeat(80))
	print("  CONFIG & SETTINGS")
	print("=".repeat(80))

	# --- GameManager ---
	print("\n--- GameManager ---")
	if GameManager != null:
		print("  speed         : %dx" % GameManager.game_speed)
		print("  tick_count    : %d" % GameManager.tick_count)
		print("  days_elapsed  : %.1f" % (GameManager.tick_count / 1000.0))
		print("  is_paused     : %s" % str(GameManager.is_paused))
		print("  worker_mode   : %s" % str(GameManager.get("simulation_worker_mode")))
		print("  lightweight   : %s" % str(GameManager.get("lightweight_mode")))
	else:
		print("  NOT LOADED")

	# --- TickManager ---
	print("\n--- TickManager ---")
	if TickManager != null:
		print("  speed_index   : %d" % TickManager.get_speed_index())
		print("  speed_label   : %s" % TickManager.get_speed_label())
		print("  current_tick  : %d" % TickManager.current_tick)
	else:
		print("  NOT LOADED")

	# --- GameSettings ---
	print("\n--- GameSettings ---")
	if GameSettings != null:
		print("  loaded        : yes")
	else:
		print("  NOT LOADED")

	# --- TickBudgetManager ---
	print("\n--- TickBudgetManager ---")
	if TickBudgetManager != null:
		print("  loaded        : yes (disabled stub)")
	else:
		print("  NOT LOADED")

	# --- Platform ---
	print("\n--- Platform ---")
	print("  os            : %s" % OS.get_name())
	print("  debug_build   : %s" % str(OS.is_debug_build()))
	print("  fps           : %d" % Engine.get_frames_per_second())
	print("  physics_fps   : %d" % Engine.physics_ticks_per_second)

	# --- Autoload count ---
	print("\n--- Autoloads ---")
	var autoload_count := 0
	var root := get_node_or_null("/root")
	if root != null:
		for child in root.get_children():
			autoload_count += 1
		print("  total         : %d" % autoload_count)

	print("\n" + "=".repeat(80))
	print("  END CONFIG & SETTINGS")
	print("=".repeat(80) + "\n")

func _print_tick_system_health() -> void:
	print("\n" + "=".repeat(80))
	print("  #99 â€” TICK SYSTEM HEALTH")
	print("=".repeat(80))

	# --- GameManager ---
	print("\n--- GameManager ---")
	if GameManager != null:
		print("  tick_count                : %d" % GameManager.tick_count)
		print("  game_speed                : %dx" % int(GameManager.game_speed))
		var gm_queued: float = float(GameManager._tick_accumulator) / float(GameManager.TICK_INTERVAL_SECONDS)
		print("  _tick_accumulator         : %.4f" % GameManager._tick_accumulator)
		print("  TICK_INTERVAL_SECONDS     : %f" % GameManager.TICK_INTERVAL_SECONDS)
		print("  queued_ticks (est)       : %.2f" % gm_queued)
		print("  last_frame_tick_cap_backlog : %s" % str(GameManager.last_frame_tick_cap_backlog))
		print("  ticks_emitted_last_frame  : %d" % GameManager.ticks_emitted_last_frame)
		print("  last_frame_game_tick_ms   : %.2f" % (float(GameManager.last_frame_game_tick_usecs) / 1000.0))
		var gm_cap: int = -1
		if TickManager != null and TickManager.has_method("_max_ticks_per_frame_for_speed"):
			gm_cap = TickManager._max_ticks_per_frame_for_speed()
		print("  max_ticks_per_frame cap   : %d" % gm_cap)
	else:
		print("  NOT LOADED")

	# --- TickManager ---
	print("\n--- TickManager ---")
	if TickManager != null:
		print("  current_tick              : %d" % TickManager.current_tick)
		print("  _speed_index              : %d" % TickManager._speed_index)
		var tm_queued: float = float(TickManager._accumulated_time) / float(TickManager.BASE_TICK_INTERVAL)
		print("  _accumulated_time         : %.4f" % TickManager._accumulated_time)
		print("  BASE_TICK_INTERVAL        : %f" % TickManager.BASE_TICK_INTERVAL)
		print("  queued_ticks (est)       : %.2f" % tm_queued)
		var speed_label: String = TickManager.get_speed_label() if TickManager.has_method("get_speed_label") else "?"
		print("  speed_label               : %s" % speed_label)
		print("  MAX_TICKS_PER_FRAME       : %d" % TickManager.MAX_TICKS_PER_FRAME.get(TickManager._speed_index, 4))
	else:
		print("  NOT LOADED")

	# --- TickBudgetManager (disabled stub check) ---
	print("\n--- TickBudgetManager ---")
	if TickBudgetManager != null:
		print("  loaded                   : yes (disabled stub â€” returns infinite budget)")
	else:
		print("  NOT LOADED")

	# --- TickRateDecoupler ---
	print("\n--- TickRateDecoupler ---")
	if TickRateDecoupler != null:
		print("  loaded                   : yes")
		if TickRateDecoupler.has_method("system_intervals"):
			print("  systems_registered       : %d" % TickRateDecoupler.system_intervals.size())
	else:
		print("  NOT LOADED")

	# --- TickProfiler ---
	print("\n--- TickProfiler ---")
	if TickProfiler != null:
		if TickProfiler.has_method("cat_total_heelkawnian"):
			print("  cat_total_heelkawnian_us : %d (%.2f ms)" % [TickProfiler.cat_total_heelkawnian, float(TickProfiler.cat_total_heelkawnian) / 1000.0])
		var root := get_node_or_null("/root/Main/WorldViewport/PawnSpawner")
		if root != null:
			print("  pawns_in_scene           : %d" % root.get_child_count())
	else:
		print("  NOT LOADED")

	print("\n" + "=".repeat(80))
	print("  END TICK SYSTEM HEALTH")
	print("=".repeat(80) + "\n")

# ============================================================================
# REPORT BUTTONS â€” hooked to a live dump toolkit. Every function reads CURRENT
# state at press time, so reports stay accurate at tick 100 or tick 5,000,000.
# All output goes to the Godot log via print().
# ============================================================================

const USAGE_SCRIPT_VAR: int = 16  # Object.PROPERTY_USAGE_SCRIPT_VARIABLE
const METHOD_FLAG_NORMAL: int = 1  # Object.METHOD_FLAG_NORMAL

func _build_report_buttons() -> void:
	var sep := HSeparator.new()
	_vbox.add_child(sep)

	var title := Label.new()
	title.text = "REPORT BUTTONS â€” dump deep state to the Godot log"
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(0.45, 0.9, 0.55))
	_vbox.add_child(title)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 4)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_vbox.add_child(grid)

	var reports := [
		["MASTER SNAPSHOT", "_print_master_snapshot"],
		["FULL SYSTEM REPORT", "_print_full_system_report"],
		["PERFORMANCE PROFILE", "_print_performance_profile"],
		["AI & MEMORY STATE", "_print_ai_memory_state"],
		["SETTLEMENTS & PAWNS", "_print_settlements_pawns"],
		["WORLD & ECONOMY", "_print_world_economy"],
		["CONFIG & SETTINGS", "_print_config_settings"],
		["TICK SYSTEM HEALTH", "_print_tick_system_health"],
		["RECENT EVENTS (40)", "_print_recent_events"],
		["CIVILIZATION & WORLD AI", "_print_civilization_summary"],
		["MILITARY & POLITICS", "_print_military_politics"],
		["CULTURE & SOCIETY", "_print_culture_society"],
		["ECONOMY DEEP", "_print_economy_deep"],
		["ENVIRONMENT & LIFE", "_print_environment_deep"],
		["HISTORY & CHRONICLE", "_print_history_deep"],
		["RELIGION & MYTH", "_print_religion_deep"],
		["PAWNS: FIRST 25", "_print_pawns_sample"],
		["PAWNS: ALL STATE", "_print_pawns_all"],
		["AUTOLOAD INVENTORY", "_print_autoload_inventory"],
		["DUMP EVERYTHING", "_run_all_reports"],
	]
	for r in reports:
		var btn := Button.new()
		btn.text = str(r[0])
		btn.custom_minimum_size = Vector2(250, 28)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.add_theme_font_size_override("font_size", 12)
		btn.pressed.connect(_on_report_button_pressed.bind(str(r[1])))
		grid.add_child(btn)

	_report_status_label = Label.new()
	_report_status_label.text = "last report: none"
	_report_status_label.add_theme_font_size_override("font_size", 11)
	_report_status_label.add_theme_color_override("font_color", Color(0.5, 0.85, 0.6))
	_vbox.add_child(_report_status_label)

func _on_report_button_pressed(method_name: String) -> void:
	_run_report(method_name)

func _run_report(method_name: String) -> void:
	if not has_method(method_name):
		print("[F10] No such report: %s" % method_name)
		return
	var _t0 := Time.get_ticks_usec()
	call(method_name)
	var _elapsed_ms := (Time.get_ticks_usec() - _t0) / 1000.0
	if _report_status_label != null:
		_report_status_label.text = "last: %s @tick %s (%.0f ms)" % [method_name, str(_get_or("GameManager", "tick_count")), _elapsed_ms]

func _run_all_reports() -> void:
	var list := [
		"_print_master_snapshot",
		"_print_full_system_report",
		"_print_settlements_pawns",
		"_print_world_economy",
		"_print_ai_memory_state",
		"_print_performance_profile",
		"_print_config_settings",
		"_print_tick_system_health",
		"_print_recent_events",
		"_print_civilization_summary",
		"_print_military_politics",
		"_print_culture_society",
		"_print_economy_deep",
		"_print_environment_deep",
		"_print_history_deep",
		"_print_religion_deep",
		"_print_pawns_sample",
		"_print_pawns_all",
		"_print_autoload_inventory",
	]
	for fn in list:
		_run_report(str(fn))
	print("")
	print("=".repeat(88))
	print("  END FULL DUMP (all reports)")
	print("=".repeat(88) + "\n")

# ---------------------------------------------------------------------------
# Safe access helpers (never crash on a missing autoload / method / property)
# ---------------------------------------------------------------------------

func _auto(name: String) -> Node:
	return get_node_or_null("/root/" + name)

func _get_or(name: String, prop: String) -> Variant:
	var n := _auto(name)
	if n == null:
		return null
	return n.get(prop)

func _call_or(name: String, method: String, args: Array = []) -> Variant:
	var n := _auto(name)
	if n == null or not n.has_method(method):
		return null
	return n.callv(method, args)

func _short(v: Variant) -> String:
	var s := str(v)
	if s.length() > 220:
		return s.substr(0, 220) + "...[+%d]" % (s.length() - 220)
	return s

func _autoload_names() -> PackedStringArray:
	var out := PackedStringArray()
	var root_node := get_node_or_null("/root")
	if root_node == null:
		return out
	for child in root_node.get_children():
		var val: Variant = ProjectSettings.get_setting("autoload/" + child.name)
		if val != null:
			out.append(String(child.name))
	return out

func _script_var_count(node: Node) -> int:
	var count := 0
	for p in node.get_property_list():
		if int(p.get("usage", 0)) & USAGE_SCRIPT_VAR != 0:
			count += 1
	return count

func _dump_system_vars(name: String) -> void:
	var n := _auto(name)
	print("--- %s ---" % name)
	if n == null:
		print("  NOT LOADED")
		return
	var total := 0
	for p in n.get_property_list():
		if int(p.get("usage", 0)) & USAGE_SCRIPT_VAR == 0:
			continue
		total += 1
		var v: Variant = n.get(p.name)
		print("  %s = %s" % [p.name, _short(v)])
	print("  (script vars: %d)" % total)

func _dump_system_methods(name: String) -> void:
	var n := _auto(name)
	if n == null:
		return
	var cmds := PackedStringArray()
	for m in n.get_method_list():
		if int(m.get("flags", 0)) & METHOD_FLAG_NORMAL == 0:
			continue
		var mname := str(m.get("name", ""))
		if mname == "" or mname.begins_with("_"):
			continue
		var args_variant: Variant = m.get("args", [])
		var nargs := 0
		if args_variant is Array:
			nargs = args_variant.size()
		cmds.append("%s(%d)" % [mname, nargs])
	print("  methods (%d): %s" % [cmds.size(), ", ".join(cmds)])

func _print_report_header(title: String) -> void:
	print("")
	print("=".repeat(88))
	var tick := 0
	var days := 0.0
	if GameManager != null and GameManager.tick_count > 0:
		tick = int(GameManager.tick_count)
		days = float(tick) / 1000.0
	var year := int(days / 365.0)
	var day := int(fmod(days, 365.0))
	print("  %s" % title)
	print("  probe context: tick=%d  year/day=%d/%d  fps=%d  speed=%s" % [tick, year, day, Engine.get_frames_per_second(), str(_get_or("GameManager", "game_speed"))])
	print("=".repeat(88))

# ---------------------------------------------------------------------------
# NEW REPORTS
# ---------------------------------------------------------------------------

func _print_master_snapshot() -> void:
	_print_report_header("MASTER SNAPSHOT â€” THE WHOLE SIM AT A GLANCE")
	print("  fps=%d" % Engine.get_frames_per_second())
	print("  paused=%s" % str(_get_or("GameManager", "is_paused")))

	var pn := get_node_or_null("/root/Main/WorldViewport/PawnSpawner")
	var pawn_total := 0
	if pn != null:
		pawn_total = pn.get_child_count()
	print("  pawns (in scene)=%d" % pawn_total)
	var dist := {"idle": 0, "working": 0, "sleeping": 0, "other": 0}
	if pn != null:
		for ch in pn.get_children():
			var st: Variant = ch.get("_state")
			if st != null:
				match int(st):
					0: dist["idle"] += 1
					2: dist["working"] += 1
					3: dist["sleeping"] += 1
					_: dist["other"] += 1
	print("  state distribution: %s" % str(dist))

	var s_count := 0
	if SettlementMemory != null and SettlementMemory.has_method("get_formal_settlement_count"):
		s_count = SettlementMemory.get_formal_settlement_count()
	print("  formal settlements=%d" % s_count)
	var open_jobs := 0
	if JobManager != null and JobManager.has_method("open_count"):
		open_jobs = JobManager.open_count()
	print("  open jobs=%d" % open_jobs)
	if StockpileManager != null and StockpileManager.has_method("total_count_of"):
		print("  stockpile food=%d wood=%d stone=%d" % [StockpileManager.total_count_of(Item.Type.FOOD), StockpileManager.total_count_of(Item.Type.WOOD), StockpileManager.total_count_of(Item.Type.STONE)])
	if ColonySimServices != null:
		if ColonySimServices.has_method("get_housing_pressure"):
			print("  housing pressure=%.3f" % ColonySimServices.get_housing_pressure())
		if ColonySimServices.has_method("get_food_pressure"):
			print("  food pressure=%.3f" % ColonySimServices.get_food_pressure())
	if WorldMemory != null and WorldMemory.has_method("event_count"):
		print("  world events recorded=%d" % WorldMemory.event_count())
	if CivilizationStage != null and CivilizationStage.has_method("get_world_score"):
		print("  civilization world score=%d" % CivilizationStage.get_world_score())
	if AIAgentManager != null and AIAgentManager.has_method("get_agent_count"):
		print("  AI agents=%d" % AIAgentManager.get_agent_count())
	if BuildingRegistry != null and BuildingRegistry.has_method("total_building_count"):
		print("  buildings=%d" % BuildingRegistry.total_building_count())
	var wn := get_node_or_null("/root/Main/WorldViewport/World")
	if wn != null and wn.get("data") != null:
		print("  world dims: %dx%d" % [WorldData.WIDTH, WorldData.HEIGHT])

	print("  --- autoload census (script vars per system) ---")
	for nm in _autoload_names():
		var n := _auto(nm)
		if n == null:
			print("  %s: NOT LOADED" % nm)
			continue
		print("  %s: script_vars=%d" % [nm, _script_var_count(n)])
	print("  --- end census (AUTOLOAD INVENTORY button flushes every value) ---")

func _print_recent_events() -> void:
	_print_report_header("RECENT EVENTS & WORLD HISTORY")
	if WorldMemory == null:
		print("  WorldMemory NOT LOADED")
		return
	print("  total events recorded: %d" % WorldMemory.event_count())
	var counts: Variant = WorldMemory.get_event_type_counts()
	if counts is Dictionary:
		print("  events by type:")
		for k in counts:
			print("    %s : %d" % [k, int(counts[k])])
	var evs: Array = WorldMemory.get_recent_events(40)
	print("  latest %d events:" % evs.size())
	for e in evs:
		if e is Dictionary:
			print("    [t=%s][%s] %s" % [str(e.get("tick", "?")), str(e.get("type", "?")), str(e.get("description", e.get("summary", str(e))))])
	if WorldMemory.has_method("get_history_export_string"):
		print("  --- history export string ---")
		print(WorldMemory.get_history_export_string())

func _print_pawns_sample() -> void:
	_print_pawn_dump(25)

func _print_pawns_all() -> void:
	_print_pawn_dump(1 << 30)

func _print_pawn_dump(max_count: int) -> void:
	_print_report_header("PAWN SCRIPT-STATE DUMP")
	var pn := get_node_or_null("/root/Main/WorldViewport/PawnSpawner")
	if pn == null:
		print("  /root/Main/WorldViewport/PawnSpawner not found")
		return
	var total := pn.get_child_count()
	var shown := mini(total, max_count)
	print("  total pawns in scene: %d  (dumping %d)" % [total, shown])
	for i in range(shown):
		var c := pn.get_child(i)
		print("!! PAWN[%d] ============" % i)
		var pd: Variant = c.get("data")
		var bits := PackedStringArray()
		bits.append("node=%s" % c.name)
		var pos: Variant = c.get("position")
		if pos != null:
			bits.append("pos=%s" % str(pos))
		for key in ["pawn_id", "pawn_name", "age", "gender", "state", "_state", "current_job", "job_title", "hunger", "health", "mood", "happiness", "faction_id", "settlement_id", "home_tile", "occupation", "alive"]:
			var v: Variant = null
			if is_instance_valid(pd) and pd is Object:
				v = pd.get(key)
			if v == null:
				v = c.get(key)
			if v != null:
				bits.append("%s=%s" % [key, _short(v)])
		print("    %s" % "  ".join(bits))
		if is_instance_valid(pd) and pd is Object:
			print("    -- data script props --")
			for p in pd.get_property_list():
				if int(p.get("usage", 0)) & USAGE_SCRIPT_VAR == 0:
					continue
				var v: Variant = pd.get(p.name)
				print("      %s = %s" % [p.name, _short(v)])

func _print_civilization_summary() -> void:
	_print_report_header("CIVILIZATION STAGE & WORLD AI")
	if CivilizationStage != null and CivilizationStage.has_method("get_world_score"):
		print("  world score: %d" % CivilizationStage.get_world_score())
	if CivilizationStage != null and CivilizationStage.has_method("get_world_stage_snapshot"):
		print("  world stage snapshot: %s" % _short(CivilizationStage.get_world_stage_snapshot()))
	if CivilizationStage != null and CivilizationStage.has_method("get_stage_snapshot"):
		print("  stage snapshot: %s" % _short(CivilizationStage.get_stage_snapshot()))
	if AIAgentManager != null:
		if AIAgentManager.has_method("get_agent_count"):
			print("  AI agents: %d" % AIAgentManager.get_agent_count())
		if AIAgentManager.has_method("get_civilization_status"):
			print("  civilization status: %s" % _short(AIAgentManager.get_civilization_status()))
		if AIAgentManager.has_method("get_all_agent_status"):
			var stats: Array = AIAgentManager.get_all_agent_status()
			print("  agent status list (%d):" % stats.size())
			for a in stats:
				if a is Dictionary:
					print("    %s" % _short(a))
	if AutonomousWorldAI != null and AutonomousWorldAI.has_method("get_ai_stats"):
		print("  world AI stats: %s" % _short(AutonomousWorldAI.get_ai_stats()))

func _print_military_politics() -> void:
	_print_report_header("MILITARY & POLITICS")
	if ArmyBattleSystem != null and ArmyBattleSystem.has_method("get_army_count") and ArmyBattleSystem.has_method("get_battle_count"):
		print("  armies=%d  active battles=%d" % [ArmyBattleSystem.get_army_count(), ArmyBattleSystem.get_battle_count()])
	if ArmyBattleSystem != null and ArmyBattleSystem.has_method("get_active_armies"):
		for army in ArmyBattleSystem.get_active_armies():
			if army is Dictionary:
				print("  ARMY %s" % _short(army))
	if ArmyBattleSystem != null and ArmyBattleSystem.has_method("get_active_battles"):
		for b in ArmyBattleSystem.get_active_battles():
			if b is Dictionary:
				print("  BATTLE %s" % _short(b))
	if AuthoritySystem != null and AuthoritySystem.has_method("get_active_conflict_count") and AuthoritySystem.has_method("get_active_treaty_count"):
		print("  conflicts=%d  treaties=%d" % [AuthoritySystem.get_active_conflict_count(), AuthoritySystem.get_active_treaty_count()])
	if AuthoritySystem != null and AuthoritySystem.has_method("get_authority_status"):
		print("  authority: %s" % _short(AuthoritySystem.get_authority_status()))
	if AuthoritySystem != null and AuthoritySystem.has_method("get_conflict_status"):
		print("  conflict status: %s" % _short(AuthoritySystem.get_conflict_status()))
	if FactionManager != null and FactionManager.has_method("get_faction_ids"):
		var fids: Array = FactionManager.get_faction_ids()
		print("  factions: %d" % fids.size())
		for fid in fids:
			if FactionManager.has_method("get_faction"):
				var fd: Variant = FactionManager.get_faction(fid)
				if fd is Dictionary:
					print("    id=%s name=%s pop=%s" % [str(fid), str(fd.get("name", "?")), str(fd.get("population", "?"))])
	if WarProductionSystem != null:
		print("  war production system script vars: %d" % _script_var_count(WarProductionSystem))

func _print_culture_society() -> void:
	_print_report_header("CULTURE & SOCIETY")
	if CasteSystem != null and CasteSystem.has_method("get_stats"):
		print("  caste stats: %s" % _short(CasteSystem.get_stats()))
	if CulturalMemory != null and CulturalMemory.has_method("get_diversity_index") and CulturalMemory.has_method("get_maturity_level"):
		print("  cultural diversity=%.3f  maturity=%.3f" % [CulturalMemory.get_diversity_index(), CulturalMemory.get_maturity_level()])
	if CulturalMemory != null and CulturalMemory.has_method("get_learnings"):
		print("  cultural learnings: %d" % CulturalMemory.get_learnings().size())
	if CulturalExchange != null and CulturalExchange.has_method("get_cultural_diversity_score"):
		print("  exchange diversity=%.3f" % CulturalExchange.get_cultural_diversity_score())
	if CulturalExchange != null and CulturalExchange.has_method("get_stats"):
		print("  exchange stats: %s" % _short(CulturalExchange.get_stats()))
	if CharacterProgressionSystem != null and CharacterProgressionSystem.has_method("get_character_count"):
		print("  characters: %d" % CharacterProgressionSystem.get_character_count())
	if KnowledgeSystem != null:
		print("  knowledge system script vars: %d" % _script_var_count(KnowledgeSystem))
	if SocialStratification != null:
		print("  social stratification script vars: %d" % _script_var_count(SocialStratification))
	if CraftingSystem != null:
		print("  crafting system script vars: %d" % _script_var_count(CraftingSystem))

func _print_economy_deep() -> void:
	_print_report_header("ECONOMY, STOCKPILES & TRADE")
	for nm in ["StockpileManager", "ZoneRegistry", "BuildingRegistry", "EconomyManager", "WorldEconomyManager", "TradeMemory", "SupplyChainSystem", "CraftingSystem", "FarmingSystem"]:
		_dump_system_vars(nm)

func _print_environment_deep() -> void:
	_print_report_header("ENVIRONMENT & LIFE")
	for nm in ["WorldEnvironmentManager", "Weather", "EcologySystem", "WildlifePopulation", "DisasterSystem", "DiseaseSystem", "CrimeSystem", "SurvivalSystem", "BodyRiskManager", "BodyPartWounds", "CataclysmSystem", "TerraformingSystem", "NavalSystem", "UndergroundSystem", "FlowingWater"]:
		_dump_system_vars(nm)

func _print_history_deep() -> void:
	_print_report_header("HISTORY & CHRONICLE")
	for nm in ["WorldMemory", "HistoricalSimulation", "ChronicleLog", "ChronicleNarrativeSystem", "EpicChronicle", "NarrativeSystem", "LegendSystem", "WorldEvents", "WorldEventSystem", "MemorialSystem", "LegacySystem"]:
		_dump_system_vars(nm)
	if WorldMemory != null and WorldMemory.has_method("get_history_export_string"):
		print("=== history export string ===")
		print(WorldMemory.get_history_export_string())

func _print_religion_deep() -> void:
	_print_report_header("RELIGION & MYTH")
	for nm in ["ReligionSystem", "VeilSystem", "AshaDrujSystem", "EgregoreMemory", "MemoryManager", "MeaningAudioCue", "EchoSystem", "SacredMemory", "MythMemory", "MythAge"]:
		_dump_system_vars(nm)
	if AshaDrujSystem != null and AshaDrujSystem.has_method("get_stats"):
		print("  asha_druj stats: %s" % _short(AshaDrujSystem.get_stats()))
	if AshaDrujSystem != null and AshaDrujSystem.has_method("get_balance"):
		print("  asha/druj balance: %s" % _short(AshaDrujSystem.get_balance()))

func _print_autoload_inventory() -> void:
	_print_report_header("AUTOLOAD INVENTORY â€” EVERY SCRIPT VARIABLE + PUBLIC METHOD")
	var names := _autoload_names()
	print("  registered autoloads: %d" % names.size())
	for nm in names:
		var n := _auto(nm)
		if n == null:
			print("== %s : NOT LOADED" % nm)
			continue
		print("== %s ==" % nm)
		_dump_system_vars(nm)
		_dump_system_methods(nm)

# AI DIAGNOSTIC METHODS
const DIAGNOSTIC_SCHEMA_VERSION: int = 1

func _build_ai_snapshot_dict() -> Dictionary:
	var start_time = Time.get_ticks_usec()
	
	var snapshot := {
		"diagnostic_schema_version": DIAGNOSTIC_SCHEMA_VERSION,
		"header": _build_header_dict(),
		"world_view": _build_world_view_dict(),
		"selected_pawn": _build_selected_pawn_dict(),
		"population": _build_population_dict(),
		"jobs": _build_jobs_dict(),
		"food": _build_food_dict(),
		"settlements": _build_settlements_dict(),
		"spatial": _build_spatial_dict(),
		"structures_development": _build_structures_development_dict(),
		"social_culture": _build_social_culture_dict(),
		"politics": _build_politics_dict(),
		"time": _build_time_scheduler_dict(),
		"performance": _build_performance_dict(),
		"anomalies": [],
		"recent_changes": _build_recent_changes_dict(),
		"section_timings_ms": {},
		"live_refresh_stats": {},
		"generated_ms": 0
	}
	
	# Time each section build
	var section_times := {}
	var section_start = Time.get_ticks_usec()
	snapshot["anomalies"] = _detect_anomalies(snapshot)
	section_times["anomalies"] = (Time.get_ticks_usec() - section_start) / 1000.0
	
	snapshot["section_timings_ms"] = section_times
	
	var end_time = Time.get_ticks_usec()
	snapshot["generated_ms"] = (end_time - start_time) / 1000.0
	
	return snapshot

func _build_header_dict() -> Dictionary:
	var tick = GameManager.tick_count if GameManager != null else 0
	var _main_node = get_node_or_null("/root/Main")
	var header := {
		"title": "HEELKAWN AI WORLD SNAPSHOT",
		"diagnostic_schema_version": DIAGNOSTIC_SCHEMA_VERSION,
		"godot_version": Engine.get_version_info().string,
		"build": "debug" if OS.is_debug_build() else "release",
		"os": OS.get_name(),
		"fps": Engine.get_frames_per_second(),
		"tick": tick,
		"year": SimTime.sim_year_index(tick),
		"day": SimTime.visual_day_within_sim_year(tick),
		"elapsed_days": float(tick) / SimTime.TICKS_PER_VISUAL_DAY,
		"game_speed": GameManager.game_speed if GameManager != null else 1,
		"paused": GameManager.is_paused if GameManager != null else false,
		"generated_ms": 0,
		"save_writes_disabled": _main_node != null and _main_node.get("_save_writes_disabled_for_playtest") == true
	}
	
	return header

func _build_world_view_dict() -> Dictionary:
	var world_view := {
		"camera": {
			"global_position": Vector2(0, 0),
			"tile": Vector2i(0, 0),
			"zoom": 1.0,
			"visible_bounds": Rect2i(0, 0, 0, 0)
		},
		"hovered_tile": Vector2i(-1, -1),
		"designation_mode": "",
		"selected_pawn_entity": null,
		"visual_selection_truth": false
	}
	
	var viewport_node := get_node_or_null("/root/Main/WorldViewport")
	if viewport_node != null:
		var camera := viewport_node.get_node_or_null("Camera")
		if camera != null:
			world_view["camera"]["global_position"] = camera.global_position
			world_view["camera"]["tile"] = WorldToMap(camera.global_position)
			world_view["camera"]["zoom"] = camera.zoom
			# Approximate visible bounds - use actual Viewport API
			var vp := get_viewport()
			var viewport_size = vp.get_visible_rect().size if vp != null else Vector2(0, 0)
			var world_size_px = Vector2(WorldData.WIDTH * 8, WorldData.HEIGHT * 8)  # 8px per tile
			var visible_rect = Rect2(
				camera.global_position - viewport_size / 2 / camera.zoom,
				viewport_size / camera.zoom
			)
			world_view["camera"]["visible_bounds"] = _rect2i_clip_visible_bounds(visible_rect)
	
	# Hovered tile
	world_view["hovered_tile"] = _hover_tile

	# Designation mode
	world_view["designation_mode"] = _designation_mode
	
	# Selected pawn/entity
	var selected_pawn = getSelectedPawn()
	if selected_pawn != null:
		world_view["selected_pawn_entity"] = {
			"id": _safe_int_get(selected_pawn, "pawn_id", -1),
			"name": _safe_get(selected_pawn, "pawn_name", "Unknown"),
			"type": "pawn"
		}
	
	# Visual selection truth
	world_view["visual_selection_truth"] = getVisualSelectionTruth()

	return world_view

func _build_selected_pawn_dict() -> Dictionary:
	var selected_pawn = getSelectedPawn()
	if selected_pawn == null:
		return {
			"selected": false,
			"reason": "No pawn selected"
		}

	var pawn_data = selected_pawn.get_pawn_data() if selected_pawn.has_method("get_pawn_data") else null
	var state = selected_pawn.get_state() if selected_pawn.has_method("get_state") else -1
	var state_name = selected_pawn.get_state_name() if selected_pawn.has_method("get_state_name") else "Unknown"
	var current_job = selected_pawn.get_current_job() if selected_pawn.has_method("get_current_job") else null
	var current_job_label = selected_pawn.get_current_job_label() if selected_pawn.has_method("get_current_job_label") else ""

	var result = {
		"selected": true,
		"pawn_id": _safe_int_get(pawn_data, "id", -1),
		"name": _safe_get(pawn_data, "display_name", "Unknown"),
		"age": _safe_int_get(pawn_data, "age", 0),
		"age_years": pawn_data.age_years if pawn_data != null else 0.0,
		"life_stage": pawn_data.life_stage if pawn_data != null else -1,
		"gender": _safe_int_get(pawn_data, "gender", 0),
		"occupation": _pawn_occupation_label(pawn_data),
		"profession_liking": _pawn_profession_liking(pawn_data),
		"health": pawn_data.health if pawn_data != null else 0.0,
		"hunger": pawn_data.hunger if pawn_data != null else 0.0,
		"rest": pawn_data.rest if pawn_data != null else 0.0,
		"mood": pawn_data.mood if pawn_data != null else 0.0,
		"tile": Vector2i(
			_safe_tile_x(pawn_data),
			_safe_tile_y(pawn_data)
		),
		"settlement_id": pawn_data.settlement_id if pawn_data != null else -1,
		"state": state,
		"state_int": state,
		"state_name": state_name,
		"current_job": current_job,
		"current_job_label": current_job_label,
		"carrying": _pawn_is_carrying(selected_pawn),
		"can_work": selected_pawn.can_work() if selected_pawn.has_method("can_work") else false
	}
	
	# Add WHY_IS_THIS_PAWN_DOING_THIS analysis
	var why_analysis := _analyze_pawn_behavior(selected_pawn, pawn_data)
	result["why"] = why_analysis
	
	return result

func _analyze_pawn_behavior(pawn: Node, pawn_data: Object) -> Dictionary:
	if pawn == null or pawn_data == null:
		return {"reason": "invalid_pawn_or_data"}

	var state = pawn.get_state()
	var state_name = pawn.get_state_name()
	var hunger = pawn_data.hunger if pawn_data != null else 100.0
	var current_job = pawn.get_current_job()
	var carrying = _pawn_is_carrying(pawn)
	var can_work = pawn.can_work() if pawn.has_method("can_work") else (pawn_data.can_work() if pawn_data != null and pawn_data.has_method("can_work") else true)

	var analysis = {
		"state": state_name,
		"state_int": state,
		"hunger": hunger,
		"carrying": carrying,
		"can_work": can_work
	}

	# Analyze based on state
	match state:
		HeelKawnian.State.IDLE:
			var visible_jobs = 0
			var visible_job_details = []
			if JobManager != null and JobManager.has_method("visible_jobs_for_pawn"):
				var jobs = JobManager.visible_jobs_for_pawn(pawn, pawn_data)
				visible_jobs = jobs.size() if jobs is Array else 0
				if jobs is Array:
					for job in jobs:
						if job is Dictionary:
							visible_job_details.append({
								"id": job.get("id", -1),
								"type": job.get("type", -1),
								"label": Job.describe_type(job.get("type", -1)),
								"tile": job.get("tile", Vector2i(-1, -1))
							})

			analysis["visible_jobs_count"] = visible_jobs
			analysis["visible_jobs"] = visible_job_details

			if visible_jobs == 0:
				# Check for food-related reasons if hungry
				if hunger <= HeelKawnian.HUNGER_EMERGENCY:
					var food_analysis = _analyze_food_situation(pawn, pawn_data)
					analysis["food_related"] = food_analysis
					if food_analysis["has_food_in_component"]:
						analysis["reason"] = "idle_with_food_available_but_not_hungry_enough_to_eat"
					else:
						analysis["reason"] = "idle_no_eligible_visible_jobs"
				else:
					analysis["reason"] = "idle_no_eligible_visible_jobs"
			else:
				analysis["reason"] = "idle_has_visible_jobs_but_not_claiming"  # Would need deeper analysis

		HeelKawnian.State.WALKING_TO_JOB:
			if current_job != null:
				analysis["reason"] = "executing_claimed_job"
				analysis["target_tile"] = current_job.get("work_tile", Vector2i(-1, -1)) if current_job is Dictionary else Vector2i(-1, -1)
				analysis["job_type"] = current_job.get("type", -1) if current_job is Dictionary else -1
				analysis["job_label"] = Job.describe_type(current_job.get("type", -1)) if current_job is Dictionary else "Unknown"
			else:
				analysis["reason"] = "walking_to_job_no_current_job"

		HeelKawnian.State.WORK, HeelKawnian.State.WORKING, HeelKawnian.State.HAULING:
			if current_job != null:
				analysis["reason"] = "executing_claimed_job"
				analysis["job_type"] = current_job.get("type", -1) if current_job is Dictionary else -1
				analysis["job_label"] = Job.describe_type(current_job.get("type", -1)) if current_job is Dictionary else "Unknown"
				analysis["progress"] = "{} / {} ticks".format(
					[current_job.get("work_ticks_done", 0) if current_job is Dictionary else 0,
					current_job.get("work_ticks_needed", 0) if current_job is Dictionary else 0]
				) if current_job is Dictionary else "unknown"
			else:
				analysis["reason"] = "working_state_no_current_job"

		HeelKawnian.State.GOING_TO_EAT, HeelKawnian.State.EATING:
			analysis["reason"] = "seeking_or_consuming_food"
			analysis["hunger"] = hunger

		HeelKawnian.State.SLEEP, HeelKawnian.State.SLEEPING:
			analysis["reason"] = "seeking_or_in_sleep"
			analysis["rest"] = pawn_data.rest if pawn_data != null else 0.0

		HeelKawnian.State.FETCHING_MATERIAL:
			if current_job != null:
				analysis["reason"] = "fetching_materials_for_job"
				analysis["job_type"] = current_job.get("type", -1) if current_job is Dictionary else -1
				analysis["job_label"] = Job.describe_type(current_job.get("type", -1)) if current_job is Dictionary else "Unknown"
			else:
				analysis["reason"] = "fetching_materials_no_job"
				
		HeelKawnian.State.DIRECT_FORAGING:
			analysis["reason"] = "directly_foraging_for_food"
			analysis["hunger"] = hunger

		_:
			analysis["reason"] = "state_" + str(state_name).to_lower().replace(" ", "_")
	
	return analysis

func _analyze_food_situation(pawn: Node, pawn_data: Object) -> Dictionary:
	var hunger = pawn_data.hunger if pawn_data != null else 100.0
	var result = {
		"hunger": hunger,
		"starving": hunger <= HeelKawnian.HUNGER_EMERGENCY,
		"has_food_anywhere": false,
		"has_food_in_component": false,
		"food_component_match": false
	}
	
	if StockpileManager != null and StockpileManager.has_method("has_any_food"):
		result["has_food_anywhere"] = StockpileManager.has_any_food()
	
	# Check component match if we have pathfinder and stockpiles
	if result["has_food_anywhere"] and _get_pathfinder() != null:
		var pawn_tile = Vector2i(
			_safe_tile_x(pawn.get_pawn_data()),
			_safe_tile_y(pawn.get_pawn_data())
		)
		var pawn_component = _get_pathfinder().component_of(pawn_tile) if _get_pathfinder() != null else -1
		
		# Check if any stockpile is in same component
		var stockpiles := []  # Would need to get from StockpileManager
		if StockpileManager != null and StockpileManager.has_method("zones"):
			stockpiles = StockpileManager.zones() if StockpileManager.zones() is Array else []
		
		for stockpile in stockpiles:
			if stockpile is Dictionary:
				var stockpile_tile = stockpile.get("tile", Vector2i(-1, -1))
				var stockpile_component = _get_pathfinder().component_of(stockpile_tile) if _get_pathfinder() != null else -1
				if stockpile_component == pawn_component and pawn_component != -1:
					result["has_food_in_component"] = true
					break
			elif stockpile is Node and stockpile.has_method("get") and stockpile.has_method("tile"):
				var stockpile_tile = stockpile.tile
				var stockpile_component = _get_pathfinder().component_of(stockpile_tile) if _get_pathfinder() != null else -1
				if stockpile_component == pawn_component and pawn_component != -1:
					result["has_food_in_component"] = true
					break
	
	result["food_component_match"] = result["has_food_in_component"]
	return result

func _build_population_dict() -> Dictionary:
	var population := {
		"total_pawns": 0,
		"by_state": {},
		"needs": {
			"starving": 0,
			"hungry": 0,
			"tired": 0,
			"unhealthy": 0,
			"carrying": 0
		},
		"affiliation": {
			"unattached": 0,
			"by_settlement": {}
		},
		"life_stage": {},
		"occupation": {},
		"profession_liking": {}
	}
	
	var pawns_node = get_node_or_null("/root/Main/WorldViewport/PawnSpawner")
	if pawns_node == null:
		return population
	
	var state_counts := {}
	var need_counts := {
		"starving": 0,
		"hungry": 0,
		"tired": 0,
		"unhealthy": 0,
		"carrying": 0
	}
	var affiliation_counts := {
		"unattached": 0
	}
	var life_stage_counts := {}
	var occupation_counts := {}
	var profession_liking_counts := {}
	
	for child in pawns_node.get_children():
		var pawn = child as HeelKawnian
		if pawn == null:
			continue
		
		population["total_pawns"] += 1
		
		# State
		var state = pawn.get_state()
		var state_name = pawn.get_state_name()
		state_counts[state_name] = state_counts.get(state_name, 0) + 1
		
		# Needs
		var pawn_data = pawn.get_pawn_data()
		if pawn_data != null:
			var hunger = pawn_data.hunger if pawn_data != null else 100.0
			var rest = pawn_data.rest if pawn_data != null else 0.0
			var health = pawn_data.health if pawn_data != null else 0.0
			
			if hunger <= HeelKawnian.HUNGER_EMERGENCY:
				need_counts["starving"] += 1
			if hunger < 30:  # Arbitrary hungry threshold
				need_counts["hungry"] += 1
			if rest < 20:  # Arbitrary tired threshold
				need_counts["tired"] += 1
			if health < 80:  # Arbitrary unhealthy threshold
				need_counts["unhealthy"] += 1
			if _pawn_is_carrying(pawn):
				need_counts["carrying"] += 1
		
		# Affiliation
		var settlement_id = pawn_data.settlement_id if pawn_data != null else -1
		if settlement_id == -1:
			affiliation_counts["unattached"] += 1
		else:
			var settlement_key := "settlement_%d" % settlement_id
			affiliation_counts[settlement_key] = affiliation_counts.get(settlement_key, 0) + 1
		
		# Life stage
		var life_stage = pawn_data.life_stage if pawn_data != null else -1
		life_stage_counts[life_stage] = life_stage_counts.get(life_stage, 0) + 1
		
		# Occupation
		var occupation = _safe_get(pawn, "occupation", "")
		if occupation != "":
			occupation_counts[occupation] = occupation_counts.get(occupation, 0) + 1
		
		# Profession liking
		var profession_liking = _safe_float_get(pawn, "profession_liking", 0.0)
		var liking_key := "liking_%d" % int(profession_liking * 10)  # Bucket by 0.1 increments
		profession_liking_counts[liking_key] = profession_liking_counts.get(liking_key, 0) + 1
	
	population["by_state"] = state_counts
	population["needs"] = need_counts
	population["affiliation"]["unattached"] = affiliation_counts["unattached"]
	
	# Convert affiliation counts to proper format
	var by_settlement := {}
	for key in affiliation_counts:
		if key != "unattached":
			by_settlement[key] = affiliation_counts[key]
	population["affiliation"]["by_settlement"] = by_settlement
	
	population["life_stage"] = life_stage_counts
	population["occupation"] = occupation_counts
	population["profession_liking"] = profession_liking_counts
	
	return population

func _build_jobs_dict() -> Dictionary:
	var jobs := {
		"open": 0,
		"claimed": 0,
		"active_union": 0,
		"posted": 0,
		"completed": 0,
		"cancelled": 0,
		"by_type": {},
		"cancellation_reasons": {},
		"abandon_reasons": {},
		"oldest_open_job": null
	}
	
	if JobManager != null:
		if JobManager.has_method("open_count"):
			jobs["open"] = JobManager.open_count()
		if JobManager.has_method("claimed_count"):
			jobs["claimed"] = JobManager.claimed_count()
		if JobManager.has_method("get_active_jobs_union"):
			var active_union = JobManager.get_active_jobs_union()
			jobs["active_union"] = active_union.size() if active_union is Array else 0
		if JobManager.has_method("posted_count"):
			jobs["posted"] = JobManager.posted_count
		if JobManager.has_method("completed_count"):
			jobs["completed"] = JobManager.completed_count
		if JobManager.has_method("cancelled_count"):
			jobs["cancelled"] = JobManager.cancelled_count
		
		# By type
		if JobManager.has_method("get_open_jobs_snapshot"):
			var open_jobs = JobManager.get_open_jobs_snapshot()
			if open_jobs is Array:
				for job in open_jobs:
					if job is Dictionary:
						var job_type = job.get("type", -1)
						var type_label = Job.describe_type(job_type) if job_type >= 0 else "Type_%d" % job_type
						var current_count = jobs["by_type"].get(type_label, 0)
						jobs["by_type"][type_label] = current_count + 1
						
						# Track oldest open job
						var posted_tick = job.get("posted_tick", 0)
						var age_ticks = GameManager.tick_count - posted_tick if GameManager != null else 0
						if jobs["oldest_open_job"] == null or age_ticks > jobs["oldest_open_job"].get("age_ticks", 0):
							jobs["oldest_open_job"] = {
								"id": job.get("id", -1),
								"type": job_type,
								"type_label": type_label,
								"tile": job.get("tile", Vector2i(-1, -1)),
								"work_tile": job.get("work_tile", Vector2i(-1, -1)),
								"posted_tick": posted_tick,
								"age_ticks": age_ticks,
								"priority": job.get("priority", 0),
								"required_tool": job.get("required_tool", -1)
							}
		
		# Cancellation reasons
		if JobManager.has_method("get_cancel_stats"):
			var cancel_stats = JobManager.get_cancel_stats()
			if cancel_stats is Dictionary:
				jobs["cancellation_reasons"] = cancel_stats
		
		# Abandon reasons
		if JobManager.has_method("get_abandon_stats"):
			var abandon_stats = JobManager.get_abandon_stats()
			if abandon_stats is Dictionary:
				jobs["abandon_reasons"] = abandon_stats
	
	return jobs

func _build_food_dict() -> Dictionary:
	var food := {
		"stockpile_zone_count": 0,
		"total_food": 0,
		"has_any_food": false,
		"inventory_totals": {},
		"top_items": [],
		"starving_pawns": []
	}
	
	if StockpileManager != null:
		if StockpileManager.has_method("zone_count"):
			food["stockpile_zone_count"] = StockpileManager.zone_count()
		if StockpileManager.has_method("total_food"):
			food["total_food"] = StockpileManager.total_food()
		if StockpileManager.has_method("has_any_food"):
			food["has_any_food"] = StockpileManager.has_any_food()
		if StockpileManager.has_method("aggregate_inventory_totals"):
			var totals = StockpileManager.aggregate_inventory_totals()
			if totals is Dictionary:
				for item_type in totals:
					var count = totals[item_type]
					var item_name = Item.NAMES[item_type] if item_type >= 0 and item_type < Item.NAMES.size() else "Item_%d" % item_type
					food["inventory_totals"][item_name] = count
			
				# Get top 5 items by count
				var sorted_items := []
				for item_name in food["inventory_totals"]:
					sorted_items.append([item_name, food["inventory_totals"][item_name]])
				sorted_items.sort_custom(func(a, b): return b[1] - a[1])  # Descending by count
				var top_count := mini(5, sorted_items.size())
				for i in range(top_count):
					food["top_items"].append({
						"item": sorted_items[i][0],
						"count": sorted_items[i][1]
					})
	
	# Find starving pawns for detailed analysis
	if StockpileManager != null and _get_pathfinder() != null:
		var pawns_node = get_node_or_null("/root/Main/WorldViewport/PawnSpawner")
		if pawns_node != null:
			for child in pawns_node.get_children():
				var pawn = child as HeelKawnian
				if pawn == null:
					continue
				
				var pawn_data = pawn.get_pawn_data()
				if pawn_data == null:
					continue
				
				var hunger = pawn_data.hunger if pawn_data != null else 100.0
				if hunger <= HeelKawnian.HUNGER_EMERGENCY:
					var pawn_tile := Vector2i(
						_safe_tile_x(pawn.get_pawn_data()),
						_safe_tile_y(pawn.get_pawn_data())
					)
					var pawn_component = _get_pathfinder().component_of(pawn_tile) if _get_pathfinder() != null else -1
					
					var food_analysis := _analyze_food_situation(pawn, pawn_data)
					var starving_entry := {
						"pawn_id": _safe_int_get(pawn, "pawn_id", -1),
						"name": _safe_get(pawn, "pawn_name", "Unknown"),
						"hunger": hunger,
						"state": pawn.get_state_name(),
						"tile": pawn_tile,
						"settlement_id": pawn_data.settlement_id if pawn_data != null else -1,
						"reason": food_analysis
					}
					food["starving_pawns"].append(starving_entry)
				
					# Limit to prevent huge outputs
					if food["starving_pawns"].size() >= 10:
						break
	
	return food

func _build_settlements_dict() -> Dictionary:
	var settlements := {
		"formal": {
			"count": 0,
			"list": []
		},
		"proto": {
			"count": 0,
			"list": []
		},
		"realms": {
			"count": 0
		},
		"membership_contract": {
			"total_checked": 0,
			"ok": 0,
			"unattached_inside": 0,
			"attached_outside": 0,
			"index_mismatch": 0,
			"stale_index": 0,
			"examples": []
		}
	}
	
	if SettlementMemory != null:
		if SettlementMemory.has_method("get_formal_settlement_count"):
			settlements["formal"]["count"] = SettlementMemory.get_formal_settlement_count()
		if SettlementMemory.has_method("get_formal_settlements"):
			var formal_list = SettlementMemory.get_formal_settlements()
			if formal_list is Array:
				for settlement in formal_list:
					if settlement is Dictionary:
						settlements["formal"]["list"].append({
							"name": settlement.get("name", "Unknown"),
							"population": settlement.get("population", 0),
							"center_region": settlement.get("center_region", -1),
							"founding_tick": settlement.get("founding_tick", 0),
							"founding_reason": settlement.get("founding_reason", "unknown"),
							"kind": settlement.get("kind", "unknown"),
							"formal": settlement.get("formal", false)
						})
		
		if SettlementMemory.has_method("get_proto_sites"):
			var proto_list = SettlementMemory.get_proto_sites()
			if proto_list is Array:
				settlements["proto"]["count"] = proto_list.size()
				for site in proto_list:
					if site is Dictionary:
						settlements["proto"]["list"].append({
							"name": site.get("name", "Unknown"),
							"guild_member_count": site.get("guild_member_count", 0),
							"guild_candidate_stability_ticks": site.get("guild_candidate_stability_ticks", 0),
							"guild_candidate_reason": site.get("guild_candidate_reason", "unknown")
						})
		
		if SettlementMemory.has_method("get_active_polity_count"):
			settlements["realms"]["count"] = SettlementMemory.get_active_polity_count()
	
	# Membership contract analysis
	var membership_analysis := _analyze_settlement_membership_contract()
	settlements["membership_contract"] = membership_analysis
	
	return settlements

func _analyze_settlement_membership_contract() -> Dictionary:
	var result := {
		"total_checked": 0,
		"ok": 0,
		"unattached_inside": 0,
		"attached_outside": 0,
		"index_mismatch": 0,
		"stale_index": 0,
		"examples": []
	}
	
	if SettlementMemory == null:
		return result
	
	var settlements_array := []  # Will hold [region_key, index] pairs
	if SettlementMemory.has_method("get_settlements"):
		var settlements_list = SettlementMemory.get_settlements()
		if settlements_list is Array:
			for i in range(settlements_list.size()):
				var settlement = settlements_list[i]
				if settlement is Dictionary and settlement.has("regions"):
					var regions = settlement.regions
					if regions is Array:
						for region in regions:
							if region is int:
								settlements_array.append([region, i])  # [region_key, settlement_index]
	
	if settlements_array.is_empty():
		return result
	
	var pawns_node = get_node_or_null("/root/Main/WorldViewport/PawnSpawner")
	if pawns_node == null:
		return result
	
	var examples = []
	
	for child in pawns_node.get_children():
		var pawn = child as HeelKawnian
		if pawn == null:
			continue
		
		var pawn_data = pawn.get_pawn_data()
		if pawn_data == null:
			continue
		
		result["total_checked"] += 1
		
		var pawn_tile := Vector2i(
			_safe_tile_x(pawn.get_pawn_data()),
			_safe_tile_y(pawn.get_pawn_data())
		)
		var pawn_region = WorldMemory._region_key(pawn_tile.x, pawn_tile.y) if WorldMemory != null else -1
		
		# Find geometric settlement index for this region
		var geometric_index := -1
		for entry in settlements_array:
			if entry[0] == pawn_region:  # region_key matches
				geometric_index = entry[1]
				break
		
		var recorded_index = pawn_data.settlement_id if pawn_data != null else -1
		
		if geometric_index == -1:
			# Region not part of any settlement
			if recorded_index == -1:
				result["ok"] += 1  # Correctly unattached
			else:
				result["attached_outside"] += 1  # Claims settlement but region not in any settlement
				if result["examples"].size() < 5:
					result["examples"].append({
						"pawn_id": _safe_int_get(pawn, "pawn_id", -1),
						"name": _safe_get(pawn, "pawn_name", "Unknown"),
						"pawn_region": pawn_region,
						"recorded_index": recorded_index,
						"geometric_index": geometric_index,
						"type": "attached_outside"
					})
		else:
			# Region is part of a settlement
			if recorded_index == -1:
				result["unattached_inside"] += 1  # Should be attached but isn't
				if result["examples"].size() < 5:
					result["examples"].append({
						"pawn_id": _safe_int_get(pawn, "pawn_id", -1),
						"name": _safe_get(pawn, "pawn_name", "Unknown"),
						"pawn_region": pawn_region,
						"recorded_index": recorded_index,
						"geometric_index": geometric_index,
						"type": "unattached_inside"
					})
			elif recorded_index == geometric_index:
				result["ok"] += 1  # Correctly attached
			else:
				result["index_mismatch"] += 1  # Attached to wrong settlement
				if result["examples"].size() < 5:
					result["examples"].append({
						"pawn_id": _safe_int_get(pawn, "pawn_id", -1),
						"name": _safe_get(pawn, "pawn_name", "Unknown"),
						"pawn_region": pawn_region,
						"recorded_index": recorded_index,
						"geometric_index": geometric_index,
						"type": "index_mismatch"
					})
	
	return result

func _build_spatial_dict() -> Dictionary:
	var spatial := {
		"world": {
			"width": WorldData.WIDTH if WorldData != null else 256,
			"height": WorldData.HEIGHT if WorldData != null else 256,
			"tile_size_px": 8
		},
		"camera": {
			"center_tile": Vector2i(0, 0),
			"zoom": 1.0
		},
		"selected_pawn_tile": Vector2i(-1, -1),
		"settlement_centers": [],
		"proto_centers": [],
		"stockpile_count": 0,
		"structure_count": 0,
		"path_components": 0,
		"ascii_slice": {
			"center": Vector2i(0, 0),
			"size": Vector2i(21, 21),
			"data": ""
		}
	}
	
	var viewport := get_node_or_null("/root/Main/WorldViewport")
	if viewport != null:
		var camera := viewport.get_node_or_null("Camera")
		if camera != null:
			spatial["camera"]["center_tile"] = WorldToMap(camera.global_position)
			spatial["camera"]["zoom"] = camera.zoom
	
	var selected_pawn = getSelectedPawn()
	if selected_pawn != null:
		var pawn_data = selected_pawn.get_pawn_data() if selected_pawn.has_method("get_pawn_data") else null
		if pawn_data != null:
			spatial["selected_pawn_tile"] = Vector2i(
				int(pawn_data.tile_pos.x) if pawn_data != null and pawn_data.tile_pos is Vector2i else 0,
				int(pawn_data.tile_pos.y) if pawn_data != null and pawn_data.tile_pos is Vector2i else 0
			)
	
	if SettlementMemory != null and SettlementMemory.has_method("get_formal_settlements"):
		var settlements = SettlementMemory.get_formal_settlements()
		if settlements is Array:
			for settlement in settlements:
				if settlement is Dictionary and settlement.has("center_region"):
					var center_region_key = settlement.center_region
					if WorldData != null:
						# center_region is an ENCODED REGION KEY: rx low-16, ry high-16 (region = 16x16 tiles)
						# Decode: rx = center_region_key & 0xFFFF, ry = (center_region_key >> 16) & 0xFFFF
						var rx = center_region_key & 0xFFFF
						var ry = (center_region_key >> 16) & 0xFFFF
						# Representative region center tile = coord * 16 + 8
						var center_tile = Vector2i(rx * 16 + 8, ry * 16 + 8)
						# Validate tile is within world bounds
						var tile_available = (center_tile.x >= 0 and center_tile.x < WorldData.WIDTH and
							center_tile.y >= 0 and center_tile.y < WorldData.HEIGHT)
						spatial["settlement_centers"].append({
							"name": settlement.get("name", "Unknown"),
							"center_region_key": center_region_key,
							"center_region_coord": Vector2i(rx, ry),
							"center_tile": center_tile,
							"center_tile_available": tile_available
						})
	
	if SettlementMemory != null and SettlementMemory.has_method("get_proto_sites"):
		var proto_sites = SettlementMemory.get_proto_sites()
		if proto_sites is Array:
			for site in proto_sites:
				if site is Dictionary and site.has("center_region"):
					var center_region_key = site.center_region
					if WorldData != null:
						var rx = center_region_key & 0xFFFF
						var ry = (center_region_key >> 16) & 0xFFFF
						var center_tile = Vector2i(rx * 16 + 8, ry * 16 + 8)
						var tile_available = (center_tile.x >= 0 and center_tile.x < WorldData.WIDTH and
							center_tile.y >= 0 and center_tile.y < WorldData.HEIGHT)
						spatial["proto_centers"].append({
							"name": site.get("name", "Unknown"),
							"center_region_key": center_region_key,
							"center_region_coord": Vector2i(rx, ry),
							"center_tile": center_tile,
							"center_tile_available": tile_available
						})
	
	if StockpileManager != null and StockpileManager.has_method("zone_count"):
		spatial["stockpile_count"] = StockpileManager.zone_count()
	
	if BuildingRegistry != null and BuildingRegistry.has_method("total_building_count"):
		spatial["structure_count"] = BuildingRegistry.total_building_count()
	
	if _get_pathfinder() != null and _get_pathfinder() != null and _get_pathfinder().has_method("component_count"):
		spatial["path_components"] = _get_pathfinder().component_count() if _get_pathfinder() != null else 0
	
	# Generate ASCII slice
	var ascii_center = spatial["selected_pawn_tile"]
	if ascii_center.x == -1 and ascii_center.y == -1:
		ascii_center = spatial["camera"]["center_tile"]
	if ascii_center.x == -1 and ascii_center.y == -1:
		ascii_center = Vector2i(int(WorldData.WIDTH / 2), int(WorldData.HEIGHT / 2)) if WorldData != null else Vector2i(128, 128)
	
	spatial["ascii_slice"]["center"] = ascii_center
	spatial["ascii_slice"]["size"] = Vector2i(21, 21)
	spatial["ascii_slice"]["data"] = _generate_ascii_world_slice(ascii_center, 10)  # 10 tile radius = 21x21
	
	return spatial

func _generate_ascii_world_slice(center: Vector2i, radius: int) -> String:
	var lines = []
	var start_y = center.y - radius
	var end_y = center.y + radius
	var start_x = center.x - radius
	var end_x = center.x + radius
	
	for y in range(start_y, end_y + 1):
		var line_chars = []
		for x in range(start_x, end_x + 1):
			var in_bounds = _get_world_data() != null and _get_world_data().in_bounds(x, y)
			var char = " "
			
			if in_bounds:
				var biome = _get_world_data().get_biome(x, y) if _get_world_data() != null else -1
				var feature = _get_world_data().get_feature(x, y) if _get_world_data() != null else -1
				
				# Check for pawns first
				var pawn_here = false
				var pawns_node = get_node_or_null("/root/Main/WorldViewport/PawnSpawner")
				if pawns_node != null:
					for child in pawns_node.get_children():
						var pawn = child as HeelKawnian
						if pawn != null:
							var pawn_data = pawn.get_pawn_data()
							if pawn_data != null:
								var pawn_tile_x = int(pawn_data.tile_pos.x) if pawn_data != null and pawn_data.tile_pos is Vector2i else 0
								var pawn_tile_y = int(pawn_data.tile_pos.y) if pawn_data != null and pawn_data.tile_pos is Vector2i else 0
								if pawn_tile_x == x and pawn_tile_y == y:
									pawn_here = true
									break
				if pawn_here:
					char = "P"
				elif feature != -1:
					# Structures/features
					char = "#"
				else:
					# Biomes
					match biome:
						Biome.Type.PLAINS:
							char = "."
						Biome.Type.FOREST:
							char = "F"
						Biome.Type.DESERT:
							char = ","
						Biome.Type.TUNDRA:
							char = "t"
						Biome.Type.MOUNTAIN:
							char = "^"
						Biome.Type.WATER, Biome.Type.OCEAN:
							char = "~"
						Biome.Type.FERTILE_SOIL:
							char = "+"
						Biome.Type.GRASS:
							char = ","
						Biome.Type.STONE_FLOOR:
							char = ":"
						_:
							char = "?"
			else:
				char = " "  # Out of bounds
			
			line_chars.append(char)
		lines.append("".join(line_chars))
	
	return "\n".join(lines)

# ============================================================================
# HELPER FUNCTIONS FOR SAFE ACCESS
# ============================================================================

func _get_world() -> Node:
	var main = get_tree().get_root().get_node_or_null("Main")
	if main == null:
		return null
	return main.get_node_or_null("WorldViewport/World")

func _get_world_data() -> Object:
	var world = _get_world()
	if world == null:
		return null
	return world.get("data") if world.has_method("get") else null

func _get_pathfinder() -> Object:
	var world = _get_world()
	if world == null:
		return null
	return world.get("pathfinder") if world.has_method("get") else null

func _safe_get(obj: Variant, prop: String, default_val: Variant) -> Variant:
	if obj == null:
		return default_val
	if obj is Dictionary:
		return obj.get(prop, default_val)
	if obj is Object:
		var v = obj.get(prop)
		return v if v != null else default_val
	return default_val

func _safe_int_get(obj: Variant, prop: String, default_val: int) -> int:
	var v = _safe_get(obj, prop, default_val)
	return int(v) if v != null else default_val

func _safe_float_get(obj: Variant, prop: String, default_val: float) -> float:
	var v = _safe_get(obj, prop, default_val)
	return float(v) if v != null else default_val

func _safe_tile_x(pawn_data: Variant) -> int:
	if pawn_data == null:
		return 0
	var tile_pos = pawn_data.get("tile_pos") if pawn_data is Object else null
	if tile_pos == null:
		return 0
	return int(tile_pos.x) if tile_pos is Vector2i else 0

func _safe_tile_y(pawn_data: Variant) -> int:
	if pawn_data == null:
		return 0
	var tile_pos = pawn_data.get("tile_pos") if pawn_data is Object else null
	if tile_pos == null:
		return 0
	return int(tile_pos.y) if tile_pos is Vector2i else 0

func _pawn_is_carrying(pawn: Node) -> bool:
	"""Safe diagnostic helper to check if pawn is carrying an item."""
	if pawn == null:
		return false
	var pawn_data = pawn.get_pawn_data() if pawn.has_method("get_pawn_data") else null
	if pawn_data == null:
		return false
	if pawn_data.has_method("is_carrying"):
		return pawn_data.is_carrying()
	# Fallback: check carrying fields directly
	return pawn_data.get("carrying", 0) != 0 and pawn_data.get("carrying_qty", 0) > 0

func _pawn_occupation_label(pawn_data: Object) -> String:
	if pawn_data == null:
		return ""
	if pawn_data.has_method("profession_name"):
		return str(pawn_data.profession_name())
	var prof = pawn_data.get("current_profession") if pawn_data.get("current_profession") != null else 0
	if prof is int and prof > 0 and pawn_data.has_method("profession_label_from_enum"):
		return str(pawn_data.profession_label_from_enum(prof))
	return "laborer"

func _pawn_profession_liking(pawn_data: Object) -> float:
	if pawn_data == null:
		return 0.0
	var liking = pawn_data.get("profession_liking") if pawn_data.get("profession_liking") != null else {}
	if not (liking is Dictionary):
		return 0.0
	var total := 0.0
	var count := 0
	for key in liking:
		var v = liking[key]
		if v is float or v is int:
			total += float(v)
			count += 1
	return total / float(count) if count > 0 else 0.0

func _rect2i_clip_visible_bounds(visible_rect: Rect2) -> Rect2i:
	var raw = Rect2i(
		int(visible_rect.position.x / 8),
		int(visible_rect.position.y / 8),
		int(visible_rect.size.x / 8),
		int(visible_rect.size.y / 8)
	)
	var world_rect = Rect2i(0, 0, 256, 256)  # WorldData.WIDTH, WorldData.HEIGHT
	var x1 = maxi(raw.position.x, world_rect.position.x)
	var y1 = maxi(raw.position.y, world_rect.position.y)
	var x2 = mini(raw.position.x + raw.size.x, world_rect.position.x + world_rect.size.x)
	var y2 = mini(raw.position.y + raw.size.y, world_rect.position.y + world_rect.size.y)
	return Rect2i(x1, y1, maxi(0, x2 - x1), maxi(0, y2 - y1))

func WorldToMap(world_pos: Vector2) -> Vector2i:
	return Vector2i(int(world_pos.x / 8), int(world_pos.y / 8))

func getSelectedPawn() -> Node:
	var selection_node = get_node_or_null("/root/Main/SelectionManager")
	if selection_node != null and selection_node.has_method("get_selected_pawn"):
		return selection_node.get_selected_pawn()
	var main = get_tree().get_root().get_node_or_null("Main")
	if main != null and main.has_method("get_selected_pawn"):
		return main.get_selected_pawn()
	return null

func getVisualSelectionTruth() -> bool:
	var selected = getSelectedPawn()
	return selected != null and is_instance_valid(selected)

func _snapshot_text(snapshot_dict: Dictionary) -> String:
	var lines = []
	lines.append("HEELKAWN AI WORLD SNAPSHOT")
	lines.append("Generated at tick %d" % snapshot_dict.get("header", {}).get("tick", 0))
	lines.append("")
	lines.append(_get_build_capture_section(snapshot_dict))
	lines.append("")
	lines.append(_get_looking_at_section(snapshot_dict))
	lines.append("")
	lines.append(_get_selected_pawn_section(snapshot_dict))
	lines.append("")
	lines.append(_get_why_section(snapshot_dict))
	lines.append("")
	lines.append(_get_pawns_section(snapshot_dict))
	lines.append("")
	lines.append(_get_work_section(snapshot_dict))
	lines.append("")
	lines.append(_get_food_section(snapshot_dict))
	lines.append("")
	lines.append(_get_settlements_section(snapshot_dict))
	lines.append("")
	lines.append(_get_world_section(snapshot_dict))
	lines.append("")
	lines.append(_get_structures_section(snapshot_dict))
	lines.append("")
	lines.append(_get_civilization_section(snapshot_dict))
	lines.append("")
	lines.append(_get_politics_section(snapshot_dict))
	lines.append("")
	lines.append(_get_time_section(snapshot_dict))
	lines.append("")
	lines.append(_get_engine_section(snapshot_dict))
	lines.append("")
	lines.append(_get_anomalies_section(snapshot_dict))
	lines.append("")
	lines.append(_get_recent_changes_section(snapshot_dict))
	# Hard line cap: never exceed 300 lines in the snapshot to prevent
	# console/print overflow (Godot's [output overflow] at ~2MB).
	const MAX_SNAPSHOT_LINES: int = 300
	if lines.size() > MAX_SNAPSHOT_LINES:
		var truncated: PackedStringArray = PackedStringArray()
		for i in range(MAX_SNAPSHOT_LINES - 3):
			truncated.append(lines[i])
		truncated.append("... [truncated at %d lines of %d total]" % [MAX_SNAPSHOT_LINES, lines.size()])
		truncated.append("End of HEELKAWN AI WORLD SNAPSHOT (truncated)")
		return "\n".join(truncated)
	return "\n".join(lines)

func _to_json(snapshot_dict: Dictionary) -> String:
	return JSON.stringify(snapshot_dict, "  ", false)

func _build_structures_development_dict() -> Dictionary:
	var structures := {
		"total_count": 0,
		"by_type": {},
		"recent_constructions": []  # Would need WorldMemory events
	}
	
	if BuildingRegistry != null and BuildingRegistry.has_method("total_building_count"):
		structures["total_count"] = BuildingRegistry.total_building_count()
	
	# Type counts would require more detailed BuildingRegistry API
	
	return structures

func _build_social_culture_dict() -> Dictionary:
	var social := {
		"households": 0,
		"factions": 0,
		"caste_stats": {},
		"cultural_diversity": 0.0,
		"cultural_maturity": 0.0,
		"character_progression": 0
	}
	
	if KinshipSystem != null and KinshipSystem.has_method("_households"):
		var households := KinshipSystem._households
		social["households"] = households.size() if households is Dictionary else 0
	
	if FactionManager != null and FactionManager.has_method("get_faction_ids"):
		var faction_ids := FactionManager.get_faction_ids()
		social["factions"] = faction_ids.size() if faction_ids is Array else 0
	
	if CasteSystem != null and CasteSystem.has_method("get_stats"):
		social["caste_stats"] = CasteSystem.get_stats() if CasteSystem.get_stats() is Dictionary else {}
	
	if CulturalMemory != null:
		if CulturalMemory.has_method("get_diversity_index"):
			social["cultural_diversity"] = CulturalMemory.get_diversity_index()
		if CulturalMemory.has_method("get_maturity_level"):
			social["cultural_maturity"] = CulturalMemory.get_maturity_level()
	
	if CharacterProgressionSystem != null and CharacterProgressionSystem.has_method("get_character_count"):
		social["character_progression"] = CharacterProgressionSystem.get_character_count()
	
	return social

func _build_politics_dict() -> Dictionary:
	var politics := {
		"active_conflicts": 0,
		"active_treaties": 0,
		"authority_status": "unknown",
		"active_armies": 0,
		"active_battles": 0,
		"factions": 0,
		"government": {}
	}
	
	if AuthoritySystem != null:
		if AuthoritySystem.has_method("get_active_conflict_count"):
			politics["active_conflicts"] = AuthoritySystem.get_active_conflict_count()
		if AuthoritySystem.has_method("get_active_treaty_count"):
			politics["active_treaties"] = AuthoritySystem.get_active_treaty_count()
		if AuthoritySystem.has_method("get_authority_status"):
			politics["authority_status"] = AuthoritySystem.get_authority_status()
	
	if ArmyBattleSystem != null:
		if ArmyBattleSystem.has_method("get_army_count"):
			politics["active_armies"] = ArmyBattleSystem.get_army_count()
		if ArmyBattleSystem.has_method("get_battle_count"):
			politics["active_battles"] = ArmyBattleSystem.get_battle_count()
	
	if FactionManager != null and FactionManager.has_method("get_faction_ids"):
		var faction_ids := FactionManager.get_faction_ids()
		politics["factions"] = faction_ids.size() if faction_ids is Array else 0
	
	# Government/ruler data would come from SettlementMemory
	
	return politics

func _build_performance_dict() -> Dictionary:
	var performance := {
		"fps": Engine.get_frames_per_second(),
		"tickprofiler": {},
		"pawn_dispatch": {},
		"autosave": {
			"interval_ticks": 6000,
			"next_autosave_tick": 0,
			"ticks_until_autosave": 0,
			"save_files": []
		}
	}
	
	# TickProfiler counters
	if TickProfiler != null:
		var profiler_enabled: bool = TickProfiler.get("_profile_sim_enabled") == true
		performance["tickprofiler_available"] = profiler_enabled
		performance["tickprofiler_measurement_scope"] = "deep (--profile-sim active)" if profiler_enabled else "deep DISABLED (passive zeros; run with --profile-sim for per-pawn timing)"
		var profiler_fields := [
			"cat_total_heelkawnian", "cat_bookkeeping", "cat_needs", "cat_survival_health",
			"cat_cognition", "cat_awareness", "cat_matrix_ai", "cat_social", "cat_household",
			"cat_settlement", "cat_state_dispatch", "cat_misc", "cat_ai_total", "cat_main_dispatch"
		]
		for field in profiler_fields:
			if TickProfiler.get(field) is int:
				var value = TickProfiler.get(field)
				performance["tickprofiler"][field] = {
					"us": value if value is int else 0,
					"ms": (value if value is int else 0) / 1000.0
				}
	
	# Pawn dispatch profiling
	# Pawn dispatch profiling (requires a HeelKawnian instance)
	var _pd_pawn = null
	var _ps_node = get_node_or_null("/root/Main/WorldViewport/PawnSpawner")
	if _ps_node != null and _ps_node.get_child_count() > 0:
		_pd_pawn = _ps_node.get_child(0)
	if _pd_pawn != null and _pd_pawn.get("_pd_enabled") != null and _pd_pawn.get("_pd_enabled"):
		var agg = _pd_pawn.get("_pd_agg") if _pd_pawn != null else {}
		var samples_raw = _pd_pawn.get("_pd_samples") if _pd_pawn != null else []
		var samples = samples_raw.duplicate() if samples_raw is Array else []
		if samples is Array:
			samples.sort_custom(func(a, b): return b - a)
			var sample_count = samples.size()
			if sample_count > 0:
				for stage in agg:
					var stage_data = agg[stage]
					if stage_data is Array and stage_data.size() >= 2:
						var total_time = stage_data[0]
						var count = stage_data[1]
						var avg_us = total_time / count if count > 0 else 0
						var p95_index = int(sample_count * 0.95)
						var p95_us = samples[p95_index] if p95_index < sample_count else (samples[sample_count - 1] if sample_count > 0 else 0)
						var max_us = samples[0] if sample_count > 0 else 0
						performance["pawn_dispatch"][stage] = {
							"label": stage,
							"n": count,
							"avg_us": avg_us,
							"p95_us": p95_us,
							"max_us": max_us
						}
	
	# Autosave info
	if GameManager != null:
		performance["autosave"]["next_autosave_tick"] = (int(GameManager.tick_count / 6000) + 1) * 6000
		performance["autosave"]["ticks_until_autosave"] = performance["autosave"]["next_autosave_tick"] - GameManager.tick_count
	
		# Check save files
		var save_paths = [
			"user://heelkawn_colony.sav",
			"user://heelkawn_colony_autosave.sav"
		]
		for path in save_paths:
			var file = FileAccess.open(path, FileAccess.READ)
			if file != null:
				performance["autosave"]["save_files"].append({
					"path": path,
					"exists": true,
					"size": file.get_length()
				})
				file.close()
			else:
				performance["autosave"]["save_files"].append({
					"path": path,
					"exists": false,
				})
	
	return performance

func _build_time_scheduler_dict() -> Dictionary:
	## HK-TIME: authoritative world-clock + scheduler state, fully READ-ONLY.
	## Never advances simulation, never changes a lane, never calls RNG, never
	## saves. Missing upstream data => N/A (or a sensible default), never a crash.
	var time_dict := {
		"requested_speed": 1,
		"speed_label": "1x",
		"target_world_seconds": 0.0,
		"committed_world_seconds": 0.0,
		"target_committed_lag_seconds": 0.0,
		"legacy_core_applied": 0.0,
		"pawn_continuous_applied": 0.0,
		"pawn_discrete_applied": 0.0,
		"compat_tick": 0,
		"compat_tick_rate_real_sec": 0.0,
		"effective_world_speed": 0.0,
		"batch_factor_active": 1,
		"scheduler_pending": false,
		"paused": false,
		"pawn_discrete_bounded": {
			"min_applied": 0.0,
			"max_applied": 0.0,
			"total_queued": 0,
			"max_queued": 0,
			"total_consumed": 0,
			"count": 0,
			"available": false
		},
		"pawn_discrete_min_applied": 0.0,
		"pawn_discrete_max_applied": 0.0,
		"pawn_discrete_total_queued": 0,
		"pawn_discrete_max_queued": 0,
		"pawn_discrete_total_consumed": 0
	}

	if GameManager != null:
		time_dict["requested_speed"] = int(GameManager.game_speed)
		time_dict["paused"] = bool(GameManager.is_paused)

	if TickManager != null:
		time_dict["speed_label"] = str(TickManager.get_speed_label()) if TickManager.has_method("get_speed_label") else (str(TickManager.get_speed_index()) + "x")
		time_dict["compat_tick"] = int(TickManager.current_tick)
		time_dict["compat_tick_rate_real_sec"] = float(TickManager.get_compat_tick_rate_per_real_second()) if TickManager.has_method("get_compat_tick_rate_per_real_second") else float(TickManager.compat_tick_rate_per_real_second)
		time_dict["effective_world_speed"] = float(TickManager.get_effective_world_speed()) if TickManager.has_method("get_effective_world_speed") else 0.0
		time_dict["batch_factor_active"] = int(TickManager.get_batch_factor_active()) if TickManager.has_method("get_batch_factor_active") else 1
		time_dict["scheduler_pending"] = bool(TickManager.get("_pending_tick_active"))

	if SimulationClock != null:
		if SimulationClock.has_method("get_target_world_time_seconds"):
			time_dict["target_world_seconds"] = float(SimulationClock.get_target_world_time_seconds())
		if SimulationClock.has_method("get_committed_world_time_seconds"):
			time_dict["committed_world_seconds"] = float(SimulationClock.get_committed_world_time_seconds())
		if SimulationClock.has_method("get_simulation_lag_seconds"):
			time_dict["target_committed_lag_seconds"] = float(SimulationClock.get_simulation_lag_seconds())
		if SimulationClock.has_method("get_lane_applied_world_time_seconds"):
			time_dict["legacy_core_applied"] = float(SimulationClock.get_lane_applied_world_time_seconds(&"legacy_core"))
			time_dict["pawn_continuous_applied"] = float(SimulationClock.get_lane_applied_world_time_seconds(&"pawn_continuous"))
			time_dict["pawn_discrete_applied"] = float(SimulationClock.get_lane_applied_world_time_seconds(&"pawn_discrete"))

	time_dict["pawn_discrete_bounded"] = _time_pawn_discrete_bounded()
	time_dict["pawn_discrete_min_applied"] = time_dict["pawn_discrete_bounded"].get("min_applied", 0.0)
	time_dict["pawn_discrete_max_applied"] = time_dict["pawn_discrete_bounded"].get("max_applied", 0.0)
	time_dict["pawn_discrete_total_queued"] = time_dict["pawn_discrete_bounded"].get("total_queued", 0)
	time_dict["pawn_discrete_max_queued"] = time_dict["pawn_discrete_bounded"].get("max_queued", 0)
	time_dict["pawn_discrete_total_consumed"] = time_dict["pawn_discrete_bounded"].get("total_consumed", 0)
	return time_dict

func _time_pawn_discrete_bounded() -> Dictionary:
	## READ-ONLY aggregate over ALL live pawns of their per-pawn discrete-decision
	## pipeline state (pawns expose get_pawn_discrete_snapshot_for_diagnostics()).
	## Bounded by construction: runs a single pass, never stores per-pawn.
	var agg := {
		"min_applied": 0.0,
		"max_applied": 0.0,
		"total_queued": 0,
		"max_queued": 0,
		"total_consumed": 0,
		"count": 0,
		"available": false
	}
	var pawns: Array = get_tree().get_nodes_in_group("pawns") if get_tree() != null else []
	if pawns.is_empty():
		return agg
	var found: int = 0
	var min_applied := -1.0
	var max_applied := 0.0
	var total_queued := 0
	var max_queued := 0
	var total_consumed := 0
	for p in pawns:
		if p == null or not p.has_method("get_pawn_discrete_snapshot_for_diagnostics"):
			continue
		var sn: Variant = p.call("get_pawn_discrete_snapshot_for_diagnostics")
		if not (sn is Dictionary):
			continue
		var applied := float(sn.get("applied_through_world_time", 0.0))
		var queued: int = int(sn.get("pending_normal_count", 0))
		var deadlines: Array = sn.get("queued_due_deadlines", [])
		if deadlines is Array:
			queued = maxi(queued, deadlines.size())
		min_applied = applied if min_applied < 0.0 else minf(min_applied, applied)
		max_applied = maxf(max_applied, applied)
		total_queued += queued
		max_queued = maxi(max_queued, queued)
		total_consumed += int(sn.get("decisions_consumed", 0))
		found += 1
	if found == 0:
		return agg
	agg["min_applied"] = min_applied
	agg["max_applied"] = max_applied
	agg["total_queued"] = total_queued
	agg["max_queued"] = max_queued
	agg["total_consumed"] = total_consumed
	agg["count"] = found
	agg["available"] = true
	return agg

func _build_recent_changes_dict() -> Dictionary:
	var recent := {
		"total_events": 0,
		"by_type": {},
		"oldest": [],
		"newest": [],
		"important_changes": [],
		"omitted": 0
	}
	
	if WorldMemory != null and WorldMemory.has_method("get_events"):
		var events = WorldMemory.get_events()
		if events is Array:
			recent["total_events"] = events.size()
			
			# Count by type
			var type_counts := {}
			for event in events:
				if event is Dictionary:
					var event_type = event.get("type", event.get("k", "unknown"))
					type_counts[event_type] = type_counts.get(event_type, 0) + 1
			recent["by_type"] = type_counts
			
			# Oldest 20
			var oldest_count := mini(20, events.size())
			for i in range(oldest_count):
				if events[i] is Dictionary:
					var ev = events[i]
					recent["oldest"].append({
						"tick": ev.get("t", ev.get("eid", 0)),
						"type": ev.get("type", ev.get("k", "unknown")),
						"description": ev.get("description", ev.get("summary", str(ev)))
					})
			
			# Newest 100
			var newest_start := maxi(0, events.size() - 100)
			var newest_count := mini(100, events.size() - newest_start)
			for i in range(newest_start, newest_start + newest_count):
				if events[i] is Dictionary:
					var ev = events[i]
					recent["newest"].append({
						"tick": ev.get("t", ev.get("eid", 0)),
						"type": ev.get("type", ev.get("k", "unknown")),
						"description": ev.get("description", ev.get("summary", str(ev)))
					})
			
			# Calculate omitted
			var shown := oldest_count + newest_count
			var settlement_events := 0
			for event in events:
				if event is Dictionary:
					var event_type := str(event.get("type", event.get("k", "")))
					if event_type.find("settlement") >= 0:
						settlement_events += 1
			# Add settlement events (last 20)
			var settlement_shown := mini(20, settlement_events)
			shown += settlement_shown
			recent["omitted"] = maxi(0, events.size() - shown)
	
	return recent

func _detect_anomalies(snapshot: Dictionary) -> Array:
	var anomalies := []
	
	# Food starvation while food exists
	var food = snapshot.get("food", {})
	var total_food = food.get("total_food", 0)
	var starving_pawns = food.get("starving_pawns", [])
	if total_food > 0 and starving_pawns.size() > 0:
		var component_mismatch := 0
		var carrying := 0
		var no_food_anywhere := 0
		var unknown := 0
		
		for pawn in starving_pawns:
			var reason = pawn.get("reason", {})
			if reason is Dictionary:
				if reason.get("has_food_in_component") == false and reason.get("has_food_anywhere") == true:
					component_mismatch += 1
				elif reason.get("carrying") == true:
					carrying += 1
				elif reason.get("has_food_anywhere") == false:
					no_food_anywhere += 1
				else:
					unknown += 1
		
		if component_mismatch > 0 or carrying > 0 or no_food_anywhere > 0 or unknown > 0:
			anomalies.append({
				"id": "food_starvation_while_food_exists",
				"severity": "WARNING",
				"summary": "%d pawns starving while %d food units exist" % [starving_pawns.size(), total_food],
				"evidence": {
					"reachable": starving_pawns.size() - component_mismatch - carrying - unknown,
					"component_mismatch": component_mismatch,
					"carrying": carrying,
					"no_food_anywhere": no_food_anywhere,
					"unknown": unknown
				},
				"not_proof": "food may still be reserved, queued, or blocked by another canonical gate"
			})
	
	# Settlement member contract violations
	var settlements = snapshot.get("settlements", {})
	var membership = settlements.get("membership_contract", {})
	var unattached_inside = membership.get("unattached_inside", 0)
	var attached_outside = membership.get("attached_outside", 0)
	var index_mismatch = membership.get("index_mismatch", 0)
	
	if unattached_inside > 0:
		anomalies.append({
			"id": "settlement_member_contract_unattached_inside",
			"severity": "WARNING",
			"summary": "%d pawns unattached while inside settlement regions" % unattached_inside,
			"evidence": membership.get("examples", []),
			"not_proof": "does not itself prove SettlementMemory failure"
		})
	
	if attached_outside > 0:
		anomalies.append({
			"id": "settlement_member_contract_attached_outside",
			"severity": "WARNING",
			"summary": "%d pawns attached to settlements but physically outside" % attached_outside,
			"evidence": membership.get("examples", []),
			"not_proof": "does not itself prove SettlementMemory failure"
		})
	
	if index_mismatch > 0:
		anomalies.append({
			"id": "settlement_member_contract_index_mismatch",
			"severity": "WARNING",
			"summary": "%d pawns have incorrect settlement indices" % index_mismatch,
			"evidence": membership.get("examples", []),
			"not_proof": "does not itself prove SettlementMemory failure - index churn during recompute is expected"
		})
	
	# Idle with open jobs
	var population = snapshot.get("population", {})
	var idle_count = population.get("by_state", {}).get("Idle", 0)
	var jobs = snapshot.get("jobs", {})
	var open_jobs = jobs.get("open", 0)
	
	if idle_count > 0 and open_jobs > 0:
		anomalies.append({
			"id": "idle_with_open_jobs",
			"severity": "INFO",
			"summary": "%d Idle pawns while %d jobs are open" % [idle_count, open_jobs],
			"evidence": {},
			"not_proof": "does not itself prove JobManager failure"
		})
	
	# Late formal settlement
	var settlements_count = settlements.get("formal", {}).get("count", 0)
	var tick = snapshot.get("header", {}).get("tick", 0)
	if settlements_count == 0 and tick > 18000:  # ~18 days at 1000 ticks/day
		anomalies.append({
			"id": "late_no_formal_settlement",
			"severity": "WARNING",
			"summary": "No formal settlement by tick %d" % tick,
			"evidence": {},
			"not_proof": "may be legitimate slow start or unfavorable conditions"
		})
	
	# Stale open jobs
	var raw_oldest: Variant = jobs.get("oldest_open_job", null)
	var oldest_job: Dictionary = {}
	if raw_oldest is Dictionary:
		oldest_job = raw_oldest
	var oldest_age = oldest_job.get("age_ticks", 0)
	if oldest_age > 360000:  # More than 1 year old
		anomalies.append({
			"id": "stale_open_jobs",
			"severity": "WARNING",
			"summary": "Open job %d (%s) has been open for %d ticks (%d days)" % [oldest_job.get("id", -1), oldest_job.get("type_label", "Unknown"), oldest_age, int(oldest_age / 1000)],
			"evidence": oldest_job,
			"not_proof": "may be legitimate due to unmet requirements or pawn unavailability"
		})
	
	# High cancel rate
	var posted = jobs.get("posted", 0)
	var cancelled = jobs.get("cancelled", 0)
	var cancel_rate := 0.0
	if posted > 0:
		cancel_rate = cancelled / posted
	if cancel_rate > 0.5:  # More than 50% cancellation rate
		anomalies.append({
			"id": "high_cancel_rate",
			"severity": "WARNING",
			"summary": "High job cancellation rate: %.1f%% (%d cancelled / %d posted)" % [cancel_rate * 100, cancelled, posted],
			"evidence": jobs.get("cancellation_reasons", {}),
			"not_proof": "may be legitimate due to changing conditions or pawn unavailability"
		})
	
	# Hot dispatch stage (if profiler enabled)
	var performance = snapshot.get("performance", {})
	var pawn_dispatch = performance.get("pawn_dispatch", {})
	var max_avg_us := 0
	var hot_stage := ""
	for stage in pawn_dispatch:
		var data = pawn_dispatch[stage]
		if data is Dictionary:
			var avg_us = data.get("avg_us", 0)
			if avg_us > max_avg_us:
				max_avg_us = avg_us
				hot_stage = stage
	if max_avg_us > 5000:  # More than 5ms average
		anomalies.append({
			"id": "hot_dispatch_stage",
			"severity": "WARNING",
			"summary": "Hot pawn dispatch stage: %s (avg %d ms)" % [hot_stage, int(max_avg_us / 1000)],
			"evidence": pawn_dispatch.get(hot_stage, {}),
			"not_proof": "indicates performance bottleneck, not necessarily incorrect behavior"
		})
	
	# HeelKawnian tick hot (overall performance)
	var tickprofiler = performance.get("tickprofiler", {})
	var cat_data = tickprofiler.get("cat_total_heelkawnian") if tickprofiler is Dictionary else null
	var heelkawnian_us = 0
	if cat_data is Dictionary:
		heelkawnian_us = cat_data.get("us", 0)
	var ticks_per_sec := 60  # Assume 60 FPS for rough calculation
	var target_max_us := 1000000 / ticks_per_sec  # Microseconds per tick budget
	if heelkawnian_us > target_max_us * 0.8:  # Using more than 80% of budget
		anomalies.append({
			"id": "heelkawnian_tick_hot",
			"severity": "WARNING",
			"summary": "HeelKawnian simulation using %d us per tick (%.1f%% of budget)" % [heelkawnian_us, (heelkawnian_us * 100.0) / (target_max_us)],
			"evidence": {},
			"not_proof": "may be legitimate during complex simulation periods"
		})
	
	# Selected pawn specific anomaly
	var selected_pawn = snapshot.get("selected_pawn", {})
	if selected_pawn.get("selected", false):
		var state = selected_pawn.get("state_name", "")
		var why = selected_pawn.get("why", {})
		var reason = why.get("reason", "")
		if state == "Idle" and reason == "idle_no_eligible_visible_jobs":
			var visible_jobs = why.get("visible_jobs_count", 0)
			if visible_jobs == 0:
				anomalies.append({
					"id": "selected_pawn_idle_no_eligible_jobs",
					"severity": "INFO",
					"summary": "Selected pawn is idle with no eligible visible jobs",
					"evidence": {
						"pawn_id": _safe_int_get(selected_pawn, "pawn_id", -1),
						"name": selected_pawn.get("name", "Unknown"),
						"state": state,
						"hunger": selected_pawn.get("hunger", 0),
						"visible_jobs": visible_jobs
					},
					"not_proof": "selected pawn may have non-visible eligible jobs or be correctly idle"
				})
	
	return anomalies

func _format_anomalies(anomalies: Array) -> String:
	if anomalies.is_empty():
		return "No anomalies detected."
	
	var lines = []
	for anomaly in anomalies:
		if anomaly is Dictionary:
			var id = anomaly.get("id", "unknown")
			var severity = anomaly.get("severity", "UNKNOWN")
			var summary = anomaly.get("summary", "No summary")
			var evidence = anomaly.get("evidence", {})
			var not_proof = anomaly.get("not_proof", "")
			
			lines.append("[%s] %s" % [severity, summary])
			lines.append("  evidence:")
			if evidence is Dictionary:
				for key in evidence:
					var value = evidence[key]
					lines.append("    %s: %s" % [key, str(value)])
			elif evidence is Array:
				for i in evidence:
					var value = evidence[i]
					lines.append("    [%d]: %s" % [i, str(value)])
			else:
				lines.append("    %s" % [str(evidence)])
			if not_proof != "":
				lines.append("  not_proof: %s" % [not_proof])
			lines.append("")
	
	return "\n".join(lines)

func _read_recent_log() -> String:
	var log_paths := [
		"user://logs/godot.log",
		"user://godot.log"
	]
	
	for path in log_paths:
		var file := FileAccess.open(path, FileAccess.READ)
		if file != null:
			var size := file.get_length()
			var read_size := mini(200 * 80, size)  # Approximate 200 lines of 80 chars
			var start_pos := maxi(0, size - read_size)
			file.seek(start_pos)
			var content := file.get_as_text()
			file.close()
			
			# Return last ~200 lines
			var lines := content.split("\n")
			var start_line := maxi(0, lines.size() - 200)
			return "\n".join(lines.slice(start_line))
	
	return "No log file found at standard locations."

func _save_screenshot(bundle_dir: String) -> bool:
	var viewport := get_viewport()
	if viewport == null:
		return false
	
	var texture := viewport.get_texture()
	if texture == null:
		return false
	
	var image := texture.get_image()
	if image == null:
		return false
	
	var screenshot_path := bundle_dir + "/screenshot.png"
	var error := image.save_png(screenshot_path)
	return error == OK

func _generate_readme(snapshot_dict: Dictionary, screenshot_saved: bool) -> String:
	var tick = snapshot_dict.get("header", {}).get("tick", 0)
	var generated_ms = snapshot_dict.get("generated_ms", 0)
	
	var readme := """HEELKAWN AI DIAGNOSTIC BUNDLE
===========================

This bundle contains diagnostic information for HeelKawn world state analysis.
All data is read-only and does not affect simulation state.

Bundle Contents:
- world_snapshot.txt: Human-readable world snapshot
- world_snapshot.json: Machine-readable JSON version
- anomalies.txt: Detected anomalies and contradictions
- recent_log.txt: Recent game log excerpts
- screenshot.png: Visual world state (if available in interactive mode)

Snapshot Information:
- Game Tick: %d
- Generated: %.2f ms
- Diagnostic Schema Version: %d

READ-ONLY GUARANTEE:
This diagnostic bundle was generated using only read-only queries.
No simulation state was modified during generation:
- No jobs were claimed or cancelled
- No food was reserved or consumed
- No pawns were moved or had their needs altered
- No settlement membership was changed
- No WorldRNG was consumed
- No autosave was triggered
- No save files were modified

PRODUCTION SAVES ARE UNTOUCHED:
The following files were NOT modified by this diagnostic:
- user://heelkawn_colony.sav
- user://heelkawn_colony_autosave.sav
- user://heelkawn_slot_*.sav

SCREENSHOT NOTE:
%s
"""% [tick, generated_ms, DIAGNOSTIC_SCHEMA_VERSION, "Screenshot included: screenshot.png" if screenshot_saved else "Screenshot omitted"]
	
	return readme

func _get_overview_section(snapshot: Dictionary) -> String:
	var header = snapshot.get("header", {})
	var pop = snapshot.get("population", {})
	var jobs = snapshot.get("jobs", {})
	var food = snapshot.get("food", {})
	var settlements = snapshot.get("settlements", {})
	
	var lines = []
	lines.append("HEELKAWN AI WORLD SNAPSHOT - OVERVIEW")
	lines.append("=".repeat(50))
	lines.append("Tick: %d (Year %d, Day %d)" % [header.get("tick", 0), header.get("year", 0), header.get("day", 0)])
	lines.append("Game Speed: %dx" % header.get("game_speed", 1))
	lines.append("Paused: %s" % [str(header.get("paused", false))])
	lines.append("")
	lines.append("Population: %d pawns" % pop.get("total_pawns", 0))
	var state_dist = pop.get("by_state", {})
	if state_dist:
		lines.append("State Distribution:")
		for state in state_dist:
			var count = state_dist[state]
			lines.append("  %s: %d" % [state, count])
	lines.append("")
	lines.append("Jobs: %d open, %d claimed, %d active" % [jobs.get("open", 0), jobs.get("claimed", 0), jobs.get("active_union", 0)])
	lines.append("")
	lines.append("Food (edible, Item.is_food): %d units in %d zones" % [food.get("total_food", 0), food.get("stockpile_zone_count", 0)])
	lines.append("Has Edible Food: %s" % [str(food.get("has_any_food", false))])
	lines.append("")
	lines.append("Settlements: %d formal, %d proto, %d realms" % [
		settlements.get("formal", {}).get("count", 0),
		settlements.get("proto", {}).get("count", 0),
		settlements.get("realms", {}).get("count", 0)
	])
	lines.append("")
	lines.append("FPS: %d" % header.get("fps", 0))
	
	return "\n".join(lines)

func _get_pawns_section(snapshot: Dictionary) -> String:
	var pop = snapshot.get("population", {})
	
	var lines = []
	lines.append("HEELKAWN AI WORLD SNAPSHOT - PAWNS")
	lines.append("=".repeat(50))
	lines.append("Total Pawns: %d" % pop.get("total_pawns", 0))
	lines.append("")
	
	var state_dist = pop.get("by_state", {})
	if state_dist:
		lines.append("State Distribution:")
		for state in state_dist:
			var count = state_dist[state]
			lines.append("  %s: %d" % [state, count])
	lines.append("")
	
	var needs = pop.get("needs", {})
	if needs:
		lines.append("Needs:")
		for need in needs:
			var count = needs[need]
			lines.append("  %s: %d" % [need, count])
	lines.append("")
	
	var affiliation = pop.get("affiliation", {})
	if affiliation:
		lines.append("Affiliation:")
		lines.append("  Unattached: %d" % affiliation.get("unattached", 0))
		var by_settlement = affiliation.get("by_settlement", {})
		if by_settlement:
			for settlement in by_settlement:
				var count = by_settlement[settlement]
				lines.append("  %s: %d" % [settlement, count])
	lines.append("")
	
	var life_stage = pop.get("life_stage", {})
	if life_stage:
		lines.append("Life Stage Distribution:")
		for stage in life_stage:
			var count = life_stage[stage]
			lines.append("  Stage %d: %d" % [stage, count])
	lines.append("")
	
	var occupation = pop.get("occupation", {})
	if occupation:
		lines.append("Top Occupations:")
		var sorted_occ := []
		for occ in occupation:
			sorted_occ.append([occ, occupation[occ]])
		sorted_occ.sort_custom(func(a, b): return b[1] - a[1])
		var top_count := mini(5, sorted_occ.size())
		for i in range(top_count):
			lines.append("  %s: %d" % [sorted_occ[i][0], sorted_occ[i][1]])
	
	return "\n".join(lines)

func _get_work_section(snapshot: Dictionary) -> String:
	var jobs = snapshot.get("jobs", {})
	
	var lines = []
	lines.append("HEELKAWN AI WORLD SNAPSHOT - WORK")
	lines.append("=".repeat(50))
	lines.append("Open Jobs: %d" % jobs.get("open", 0))
	lines.append("Claimed Jobs: %d" % jobs.get("claimed", 0))
	lines.append("Active Union: %d" % jobs.get("active_union", 0))
	lines.append("Posted: %d" % jobs.get("posted", 0))
	lines.append("Completed: unavailable (JobManager maintains no completion counter)")
	lines.append("Cancelled: %d" % jobs.get("cancelled", 0))
	lines.append("")
	
	var by_type = jobs.get("by_type", {})
	if by_type:
		lines.append("Jobs by Type:")
		var sorted_types := []
		for type_label in by_type:
			sorted_types.append([type_label, by_type[type_label]])
		sorted_types.sort_custom(func(a, b): return b[1] - a[1])
		for entry in sorted_types:
			lines.append("  %s: %d" % [entry[0], entry[1]])
	lines.append("")
	
	var oldest = jobs.get("oldest_open_job", {})
	if oldest and oldest.get("id", -1) != -1:
		lines.append("Oldest Open Job:")
		lines.append("  ID: %d" % oldest.get("id", -1))
		lines.append("  Type: %s (%d)" % [oldest.get("type_label", "Unknown"), oldest.get("type", -1)])
		lines.append("  Tile: %s" % [str(oldest.get("tile", Vector2i(-1, -1)))])
		lines.append("  Work Tile: %s" % [str(oldest.get("work_tile", Vector2i(-1, -1)))])
		lines.append("  Posted Tick: %d" % oldest.get("posted_tick", 0))
		lines.append("  Age: %d ticks" % oldest.get("age_ticks", 0))
		lines.append("  Priority: %d" % oldest.get("priority", 0))
		lines.append("  Required Tool: %d" % oldest.get("required_tool", -1))
	
	return "\n".join(lines)

func _get_civilization_section(snapshot: Dictionary) -> String:
	var social = snapshot.get("social_culture", {})
	var politics = snapshot.get("politics", {})
	
	var lines = []
	lines.append("HEELKAWN AI WORLD SNAPSHOT - CIVILIZATION")
	lines.append("=".repeat(50))
	lines.append("Households: %d" % social.get("households", 0))
	lines.append("Factions: %d" % social.get("factions", 0))
	lines.append("")
	
	var caste = social.get("caste_stats", {})
	if caste:
		lines.append("Caste Stats:")
		for key in caste:
			lines.append("  %s: %s" % [key, str(caste[key])])
	lines.append("")
	
	lines.append("Cultural Diversity: %.3f" % social.get("cultural_diversity", 0.0))
	lines.append("Cultural Maturity: %.3f" % social.get("cultural_maturity", 0.0))
	lines.append("Character Progression: %d" % social.get("character_progression", 0))
	lines.append("")
	
	lines.append("Politics:")
	lines.append("  Active Conflicts: %d" % politics.get("active_conflicts", 0))
	lines.append("  Active Treaties: %d" % politics.get("active_treaties", 0))
	lines.append("  Authority Status: %s" % politics.get("authority_status", "unknown"))
	lines.append("  Active Armies: %d" % politics.get("active_armies", 0))
	lines.append("  Active Battles: %d" % politics.get("active_battles", 0))
	
	return "\n".join(lines)

func _get_world_section(snapshot: Dictionary) -> String:
	var world_view = snapshot.get("world_view", {})
	var spatial = snapshot.get("spatial", {})
	var world = snapshot.get("header", {})
	
	var lines = []
	lines.append("HEELKAWN AI WORLD SNAPSHOT - WORLD")
	lines.append("=".repeat(50))
	lines.append("World Dimensions: %dx%d tiles (%dx%d meters)" % [
		world_view.get("camera", {}).get("world", {}).get("width", 256),
		world_view.get("camera", {}).get("world", {}).get("height", 256),
		world_view.get("camera", {}).get("world", {}).get("width", 256) * 8,
		world_view.get("camera", {}).get("world", {}).get("height", 256) * 8
	])
	lines.append("")
	
	var cam = world_view.get("camera", {})
	lines.append("Camera:")
	lines.append("  Center Tile: %s" % [str(cam.get("center_tile", Vector2i(0, 0)))])
	var zoom = cam.get("zoom", Vector2(1.0, 1.0))
	lines.append("  Zoom: (%.2f, %.2f)" % [zoom.x, zoom.y])
	lines.append("  Visible Bounds: %s" % [str(cam.get("visible_bounds", Rect2i(0, 0, 0, 0)))])
	lines.append("")
	
	lines.append("Selected Pawn Tile: %s" % [str(spatial.get("selected_pawn_tile", Vector2i(-1, -1)))])
	lines.append("")
	
	var settlements = spatial.get("settlement_centers", [])
	lines.append("Settlement Centers (%d):" % settlements.size())
	for settlement in settlements:
		if settlement is Dictionary:
			lines.append("  %s: %s" % [settlement.get("name", "Unknown"), str(settlement.get("center_tile", Vector2i(-1, -1)))])
	lines.append("")

	var protos = spatial.get("proto_centers", [])
	lines.append("Proto Site Centers (%d):" % protos.size())
	for proto in protos:
		if proto is Dictionary:
			lines.append("  %s: %s" % [proto.get("name", "Unknown"), str(proto.get("center_tile", Vector2i(-1, -1)))])
	lines.append("")
	
	lines.append("Stockpile Zones: %d" % spatial.get("stockpile_count", 0))
	lines.append("Structures: %d" % spatial.get("structure_count", 0))
	lines.append("Path Components: %d" % spatial.get("path_components", 0))
	lines.append("")
	
	lines.append("ASCII World Slice (21x21 tiles):")
	lines.append("Center: %s" % [str(spatial.get("ascii_slice", {}).get("center", Vector2i(0, 0)))])
	lines.append(spatial.get("ascii_slice", {}).get("data", ""))
	
	return "\n".join(lines)

func _get_engine_section(snapshot: Dictionary) -> String:
	var performance = snapshot.get("performance", {})
	
	var lines = []
	lines.append("HEELKAWN AI WORLD SNAPSHOT - ENGINE")
	lines.append("=".repeat(50))
	lines.append("FPS: %d" % performance.get("fps", 0))
	lines.append("")
	
	var tickprofiler = performance.get("tickprofiler", {})
	var profiler_scope: String = str(performance.get("tickprofiler_measurement_scope", ""))
	if not profiler_scope.is_empty():
		lines.append("Profiler Scope: %s" % profiler_scope)
	if tickprofiler and tickprofiler is Dictionary and not tickprofiler.is_empty():
		lines.append("TickProfiler (cumulative window us/ms):")
		var sorted_cats := []
		for cat in tickprofiler:
			var data = tickprofiler[cat]
			if data is Dictionary:
				var us = data.get("us", 0)
				var ms = data.get("ms", 0.0)
				sorted_cats.append([cat, us, ms])
		sorted_cats.sort_custom(func(a, b): return b[1] - a[1])  # Sort by us descending
		for entry in sorted_cats:
			lines.append("  %s: %d us (%.2f ms)" % [entry[0], entry[1], entry[2]])
	lines.append("")
	
	var pawn_dispatch = performance.get("pawn_dispatch", {})
	if pawn_dispatch:
		lines.append("Pawn Dispatch Stages:")
		var sorted_stages := []
		for stage in pawn_dispatch:
			var data = pawn_dispatch[stage]
			if data is Dictionary:
				var label = data.get("label", "unknown")
				var n = data.get("n", 0)
				var avg_us = data.get("avg_us", 0)
				var p95_us = data.get("p95_us", 0)
				var max_us = data.get("max_us", 0)
				sorted_stages.append([label, n, avg_us, p95_us, max_us])
		sorted_stages.sort_custom(func(a, b): return b[2] - a[2])  # Sort by avg_us descending
		for entry in sorted_stages:
			lines.append("  %s: n=%d, avg=%d us, p95=%d us, max=%d us" % [entry[0], entry[1], entry[2], entry[3], entry[4]])
	lines.append("")
	
	var autosave = performance.get("autosave", {})
	if autosave:
		lines.append("Autosave:")
		lines.append("  Interval: %d ticks" % autosave.get("interval_ticks", 6000))
		lines.append("  Next Autosave: Tick %d" % autosave.get("next_autosave_tick", 0))
		lines.append("  Ticks Until: %d" % autosave.get("ticks_until_autosave", 0))
		lines.append("  Save Files:")
		for save_file in autosave.get("save_files", []):
			if save_file is Dictionary:
				var exists = save_file.get("exists", false)
				var size = save_file.get("size", 0)
				lines.append("    %s: %s (%d bytes)" % [save_file.get("path", "unknown"), "exists" if exists else "missing", size])
	
	return "\n".join(lines)

func _get_time_section(snapshot: Dictionary) -> String:
	var time = snapshot.get("time", {})
	var lines = []
	lines.append("HEELKAWN AI WORLD SNAPSHOT - TIME / SCHEDULER")
	lines.append("=".repeat(50))
	lines.append("Requested Speed: %d (%s)" % [time.get("requested_speed", 1), time.get("speed_label", "1x")])
	lines.append("Target World Seconds: %.4f" % time.get("target_world_seconds", 0.0))
	lines.append("Committed World Seconds: %.4f" % time.get("committed_world_seconds", 0.0))
	lines.append("Target-Committed Lag: %.4f s" % time.get("target_committed_lag_seconds", 0.0))
	lines.append("Lanes Applied (s):")
	lines.append("  legacy_core   : %.4f" % time.get("legacy_core_applied", 0.0))
	lines.append("  pawn_continuous: %.4f" % time.get("pawn_continuous_applied", 0.0))
	lines.append("  pawn_discrete : %.4f" % time.get("pawn_discrete_applied", 0.0))
	lines.append("Compat Tick: %d" % time.get("compat_tick", 0))
	lines.append("Compat Tick Rate: %.2f / real s" % time.get("compat_tick_rate_real_sec", 0.0))
	lines.append("Effective World Speed: %.2fx (committed world-s / real s, CPU-bounded)" % time.get("effective_world_speed", 0.0))
	lines.append("Batch Factor Active: %d (canonical world-s / transaction \u00f7 base quantum)" % int(time.get("batch_factor_active", 1)))
	lines.append("Scheduler Pending: %s" % str(time.get("scheduler_pending", false)))
	lines.append("Paused: %s" % str(time.get("paused", false)))
	var pd = time.get("pawn_discrete_bounded", {})
	if pd is Dictionary and bool(pd.get("available", false)):
		lines.append("Pawn Discrete (bounded aggregate across %d pawns):" % int(pd.get("count", 0)))
		lines.append("  min applied: %.4f s ; max applied: %.4f s" % [pd.get("min_applied", 0.0), pd.get("max_applied", 0.0)])
		lines.append("  total queued: %d ; max per pawn: %d ; total consumed: %d" % [pd.get("total_queued", 0), pd.get("max_queued", 0), pd.get("total_consumed", 0)])
	else:
		lines.append("Pawn Discrete: N/A (no pawn exposes a bounded snapshot)")
	return "\n".join(lines)

func _get_build_capture_section(snapshot: Dictionary) -> String:
	var header = snapshot.get("header", {})
	var lines = []
	lines.append("HEELKAWN AI WORLD SNAPSHOT - BUILD / CAPTURE")
	lines.append("=".repeat(50))
	lines.append("Tick: %d (Year %d, Day %d)" % [header.get("tick", 0), header.get("year", 0), header.get("day", 0)])
	lines.append("Game Speed: %dx" % header.get("game_speed", 1))
	lines.append("Paused: %s" % [str(header.get("paused", false))])
	lines.append("Save Writes Disabled: %s" % [str(header.get("save_writes_disabled", false))])
	lines.append("Schema Version: %d" % snapshot.get("diagnostic_schema_version", 0))
	lines.append("Generated: %.1fms" % snapshot.get("generated_ms", 0.0))
	return "\n".join(lines)

func _get_looking_at_section(snapshot: Dictionary) -> String:
	var world_view = snapshot.get("world_view", {})
	var cam = world_view.get("camera", {})
	var lines = []
	lines.append("HEELKAWN AI WORLD SNAPSHOT - WHAT THE PLAYER IS LOOKING AT")
	lines.append("=".repeat(50))
	lines.append("Camera Center Tile: %s" % [str(cam.get("tile", Vector2i(0, 0)))])
	var zoom = cam.get("zoom", Vector2(1.0, 1.0))
	lines.append("Zoom: (%.2f, %.2f)" % [zoom.x, zoom.y])
	lines.append("Visible Bounds: %s" % [str(cam.get("visible_bounds", Rect2i(0, 0, 0, 0)))])
	lines.append("Hovered Tile: %s" % [str(world_view.get("hovered_tile", Vector2i(-1, -1)))])
	lines.append("Designation Mode: %s" % str(world_view.get("designation_mode", "")))
	return "\n".join(lines)

func _get_selected_pawn_section(snapshot: Dictionary) -> String:
	var selected = snapshot.get("selected_pawn", {})
	var lines = []
	lines.append("HEELKAWN AI WORLD SNAPSHOT - SELECTED PAWN")
	lines.append("=".repeat(50))
	if not selected.get("selected", false):
		lines.append("No pawn selected")
		return "\n".join(lines)
	lines.append("Pawn ID: %d" % selected.get("pawn_id", -1))
	lines.append("Name: %s" % str(selected.get("name", "Unknown")))
	lines.append("Age: %d" % selected.get("age", 0))
	lines.append("Tile: %s" % [str(selected.get("tile", Vector2i(-1, -1)))])
	lines.append("State: %s" % str(selected.get("state_name", "Unknown")))
	lines.append("Hunger: %.1f" % selected.get("hunger", 0.0))
	lines.append("Health: %.1f" % selected.get("health", 0.0))
	lines.append("Mood: %.1f" % selected.get("mood", 0.0))
	lines.append("Rest: %.1f" % selected.get("rest", 0.0))
	lines.append("Carrying: %s" % str(selected.get("carrying", false)))
	lines.append("Can Work: %s" % str(selected.get("can_work", false)))
	return "\n".join(lines)

func _get_why_section(snapshot: Dictionary) -> String:
	var selected = snapshot.get("selected_pawn", {})
	var lines = []
	lines.append("HEELKAWN AI WORLD SNAPSHOT - WHY IS THIS PAWN DOING THIS?")
	lines.append("=".repeat(50))
	if not selected.get("selected", false):
		lines.append("No pawn selected")
		return "\n".join(lines)
	var why = selected.get("why", {})
	if not (why is Dictionary):
		lines.append("No behavior analysis available")
		return "\n".join(lines)
	lines.append("Reason: %s" % str(why.get("reason", "unknown")))
	lines.append("State: %s" % str(why.get("state", "Unknown")))
	lines.append("Hunger: %.1f" % why.get("hunger", 0.0))
	lines.append("Carrying: %s" % str(why.get("carrying", false)))
	lines.append("Can Work: %s" % str(why.get("can_work", false)))
	if why.has("visible_jobs_count"):
		lines.append("Visible Jobs: %d" % why.get("visible_jobs_count", 0))
	if why.has("job_label"):
		lines.append("Job Label: %s" % str(why.get("job_label", "")))
	if why.has("target_tile"):
		lines.append("Target Tile: %s" % [str(why.get("target_tile", Vector2i(-1, -1)))])
	return "\n".join(lines)

func _get_food_section(snapshot: Dictionary) -> String:
	var food = snapshot.get("food", {})
	var lines = []
	lines.append("HEELKAWN AI WORLD SNAPSHOT - FOOD / SURVIVAL")
	lines.append("=".repeat(50))
	lines.append("Edible Food (Item.is_food): %d units" % food.get("total_food", 0))
	lines.append("Stockpile Zones: %d" % food.get("stockpile_zone_count", 0))
	lines.append("Has Edible Food: %s" % str(food.get("has_any_food", false)))
	var top_items = food.get("top_items", [])
	if top_items:
		lines.append("Top Items:")
		for item in top_items:
			if item is Dictionary:
				lines.append("  %s: %d" % [item.get("item", "?"), item.get("count", 0)])
	var starving = food.get("starving_pawns", [])
	lines.append("Starving Pawns: %d" % starving.size())
	if starving:
		for pawn in starving:
			if pawn is Dictionary:
				lines.append("  %s (id=%d) hunger=%.1f" % [pawn.get("name", "?"), pawn.get("pawn_id", -1), pawn.get("hunger", 0.0)])
	return "\n".join(lines)

func _get_settlements_section(snapshot: Dictionary) -> String:
	var settlements = snapshot.get("settlements", {})
	var lines = []
	lines.append("HEELKAWN AI WORLD SNAPSHOT - SETTLEMENTS / PROTOS / REALMS")
	lines.append("=".repeat(50))
	var formal = settlements.get("formal", {})
	lines.append("Formal: %d" % formal.get("count", 0))
	var formal_list = formal.get("list", [])
	if formal_list:
		for s in formal_list:
			if s is Dictionary:
				lines.append("  %s (pop=%d, reason=%s)" % [s.get("name", "Unknown"), s.get("population", 0), s.get("founding_reason", "unknown")])
	lines.append("Proto: %d" % settlements.get("proto", {}).get("count", 0))
	var proto_list = settlements.get("proto", {}).get("list", [])
	if proto_list:
		for p in proto_list:
			if p is Dictionary:
				lines.append("  %s (members=%d, reason=%s)" % [p.get("name", "Unknown"), p.get("guild_member_count", 0), p.get("guild_candidate_reason", "unknown")])
	lines.append("Realms: %d" % settlements.get("realms", {}).get("count", 0))
	var membership = settlements.get("membership_contract", {})
	if membership:
		lines.append("Membership Contract: total=%d ok=%d unattached_inside=%d attached_outside=%d" % [
			membership.get("total_checked", 0), membership.get("ok", 0),
			membership.get("unattached_inside", 0), membership.get("attached_outside", 0)])
	return "\n".join(lines)

func _get_structures_section(snapshot: Dictionary) -> String:
	var structures = snapshot.get("structures_development", {})
	var lines = []
	lines.append("HEELKAWN AI WORLD SNAPSHOT - STRUCTURES / DEVELOPMENT")
	lines.append("=".repeat(50))
	lines.append("Total Structures: %d" % structures.get("total_count", 0))
	lines.append("By Type: unavailable (no per-type BuildingRegistry API)")
	return "\n".join(lines)

func _get_politics_section(snapshot: Dictionary) -> String:
	var politics = snapshot.get("politics", {})
	var lines = []
	lines.append("HEELKAWN AI WORLD SNAPSHOT - POLITICS / DIPLOMACY")
	lines.append("=".repeat(50))
	lines.append("Active Conflicts: %d" % politics.get("active_conflicts", 0))
	lines.append("Active Treaties: %d" % politics.get("active_treaties", 0))
	lines.append("Authority Status: %s" % str(politics.get("authority_status", "unknown")))
	lines.append("Active Armies: %d" % politics.get("active_armies", 0))
	lines.append("Active Battles: %d" % politics.get("active_battles", 0))
	lines.append("Factions: %d" % politics.get("factions", 0))
	return "\n".join(lines)

func _get_anomalies_section(snapshot: Dictionary) -> String:
	var anomalies = snapshot.get("anomalies", [])
	var lines = []
	lines.append("HEELKAWN AI WORLD SNAPSHOT - ANOMALIES")
	lines.append("=".repeat(50))
	if anomalies.is_empty():
		lines.append("No anomalies detected.")
	else:
		for anomaly in anomalies:
			if anomaly is Dictionary:
				lines.append("[%s] %s" % [anomaly.get("severity", "?"), anomaly.get("summary", "?")])
				var evidence = anomaly.get("evidence", {})
				if evidence is Dictionary and evidence.size() > 0:
					lines.append("  evidence:")
					for key in evidence:
						lines.append("    %s: %s" % [key, str(evidence[key])])
				var not_proof = anomaly.get("not_proof", "")
				if not_proof != "":
					lines.append("  not_proof: %s" % not_proof)
	return "\n".join(lines)

func _get_recent_changes_section(snapshot: Dictionary) -> String:
	var recent = snapshot.get("recent_changes", {})
	var lines = []
	lines.append("HEELKAWN AI WORLD SNAPSHOT - WHAT CHANGED RECENTLY")
	lines.append("=".repeat(50))
	lines.append("Total Events: %d" % recent.get("total_events", 0))
	var by_type = recent.get("by_type", {})
	if by_type:
		lines.append("Events by Type:")
		for type_name in by_type:
			lines.append("  %s: %d" % [type_name, by_type[type_name]])
	var newest = recent.get("newest", [])
	if newest:
		lines.append("Recent Events (newest %d):" % newest.size())
		for ev in newest:
			if ev is Dictionary:
				lines.append("  [%d] %s: %s" % [ev.get("tick", 0), ev.get("type", "unknown"), ev.get("description", "")])
	var omitted = recent.get("omitted", 0)
	if omitted > 0:
		lines.append("Omitted: %d events" % omitted)
	return "\n".join(lines)
