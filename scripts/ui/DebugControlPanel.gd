class_name DebugControlPanel
extends Control

# Expanded debug panel anchored at bottom-left. Provides clickable controls
# for most dev/test commands and a log area for copy/export to feed external AI.

var _expanded: bool = false
var _panel: PanelContainer = null
var _content: VBoxContainer = null
var _log: TextEdit = null
var _krond_amount_input: LineEdit = null

func _ready() -> void:
	self.name = "DebugControlPanel"
	# Anchor bottom-left and allow wide panel similar to worldbox
	anchor_left = 0.0
	anchor_top = 1.0
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_left = 8
	offset_top = -220
	offset_right = -8
	offset_bottom = 8

	# Panel container
	_panel = PanelContainer.new()
	_panel.name = "Panel"
	_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_panel.size_flags_vertical = Control.SIZE_FILL
	add_child(_panel)

	var hbox := HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_panel.add_child(hbox)

	var left_v := VBoxContainer.new()
	left_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_v.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox.add_child(left_v)

	var right_v := VBoxContainer.new()
	right_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_v.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox.add_child(right_v)

	# Controls column
	_content = VBoxContainer.new()
	_content.name = "Content"
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_v.add_child(_content)

	# Row: Export / Trait Shop / Save/Load
	var row := HBoxContainer.new()
	_content.add_child(row)
	var b_export := Button.new(); b_export.text = "Export Chronicle"; b_export.connect("pressed", Callable(self, "_action_export")); row.add_child(b_export)
	var b_shop := Button.new(); b_shop.text = "Open Trait Shop"; b_shop.connect("pressed", Callable(self, "_action_trait_shop")); row.add_child(b_shop)
	var b_save := Button.new(); b_save.text = "Save"; b_save.connect("pressed", Callable(self, "_action_save")); row.add_child(b_save)
	var b_load := Button.new(); b_load.text = "Load"; b_load.connect("pressed", Callable(self, "_action_load")); row.add_child(b_load)

	# Grant krond controls
	var gr := HBoxContainer.new()
	gr.name = "GrantRow"
	var amt := LineEdit.new(); amt.name = "KrondAmount"; amt.text = "25"; amt.size_flags_horizontal = Control.SIZE_EXPAND_FILL; gr.add_child(amt)
	_krond_amount_input = amt
	var b_grant := Button.new(); b_grant.text = "Grant Krond"; b_grant.connect("pressed", Callable(self, "_action_grant_krond")); gr.add_child(b_grant)
	_content.add_child(gr)

	# Simulation and inspection controls
	_add_button_to(_content, "Reroll World", "_action_reroll")
	_add_button_to(_content, "Print HeelKawnian Stats", "_action_pawn_stats")
	_add_button_to(_content, "Dump Jobs", "_action_dump_jobs")
	_add_button_to(_content, "Print Stockpile", "_action_stockpile")
	_add_button_to(_content, "Toggle Draft Mode", "_action_toggle_draft")
	_add_button_to(_content, "Toggle Region Inspector", "_action_region_inspector")
	_add_button_to(_content, "Toggle Timeline", "_action_timeline")
	_add_button_to(_content, "Toggle Chronicle Ledger", "_action_ledger")
	_add_button_to(_content, "Capture Resource Truth", "_action_capture_resource_truth")
	_add_button_to(_content, "Start Kernel Diagnostic", "_action_kernel_diag")
	_add_button_to(_content, "Start Settlement Verify", "_action_settlement_verify")
	_add_button_to(_content, "Run TestTraitSystem", "_action_run_testtrait")
	_add_button_to(_content, "Save Chronicle", "_action_save_chronicle")
	_add_button_to(_content, "Save World Seed", "_action_save_world_seed")

	# Hotkey enable toggle
	var hk := CheckBox.new(); hk.text = "Enable Hotkeys"; hk.name = "HotkeyToggle"; hk.button_pressed = true; hk.connect("toggled", Callable(self, "_on_hotkey_toggled")); _content.add_child(hk)

	# Right column: Log and export
	var label := Label.new(); label.text = "Debug Log"; right_v.add_child(label)
	_log = TextEdit.new(); _log.editable = false; _log.size_flags_vertical = Control.SIZE_EXPAND_FILL; right_v.add_child(_log)
	var h2 := HBoxContainer.new(); right_v.add_child(h2)
	var b_copy := Button.new(); b_copy.text = "Copy Log"; b_copy.connect("pressed", Callable(self, "_action_copy_log")); h2.add_child(b_copy)
	var b_export_log := Button.new(); b_export_log.text = "Export Log"; b_export_log.connect("pressed", Callable(self, "_action_export_log")); h2.add_child(b_export_log)
	var b_clear := Button.new(); b_clear.text = "Clear"; b_clear.connect("pressed", Callable(self, "_action_clear_log")); h2.add_child(b_clear)

	# Initial log entry
	_log_message("Debug panel ready")

func _add_button_to(parent: Node, text: String, method_name: String) -> void:
	var btn := Button.new()
	btn.text = text
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.connect("pressed", Callable(self, method_name))
	parent.add_child(btn)

func _get_main() -> Node:
	return get_tree().get_root().get_node_or_null("Main")

func _log_message(msg: String) -> void:
	var t := "[%s] %s\n" % [str(Time.get_unix_time_from_system()), msg]
	if _log != null:
		_log.text += t
		# TextEdit scroll API differs across Godot versions; force to bottom safely.
		_log.scroll_vertical = _log.get_line_count()
	print(t)

func _action_export() -> void:
	var main := _get_main()
	if main != null and main.has_method("_export_chronicle"):
		main._export_chronicle()
		_log_message("Exported chronicle via Main")
	else:
		_log_message("Export chronicle not available")

func _action_trait_shop() -> void:
	var main := _get_main()
	if main != null and main.has_method("_toggle_trait_shop"):
		main._toggle_trait_shop()
		_log_message("Toggled trait shop")

func _action_save() -> void:
	var main := _get_main()
	if main != null and main.has_method("_colony_save"):
		main._colony_save()
		_log_message("Colony save requested")

func _action_load() -> void:
	var main := _get_main()
	if main != null and main.has_method("_colony_load"):
		main._colony_load()
		_log_message("Colony load requested")

func _action_grant_krond() -> void:
	var amount := 25.0
	if _krond_amount_input != null and is_instance_valid(_krond_amount_input):
		amount = float(_krond_amount_input.text)
	var main := _get_main()
	if main != null and main.has_method("_debug_grant_krond"):
		main._debug_grant_krond(amount)
		_log_message("Granted %g Krond via Main" % amount)
	else:
		_log_message("Grant Krond not available")

func _action_reroll() -> void:
	var main := _get_main()
	if main != null and main.has_method("_reroll_world"):
		main._reroll_world()
		_log_message("Rerolled world")

func _action_pawn_stats() -> void:
	var ps := get_node_or_null("/root/Main/WorldViewport/PawnSpawner")
	if ps != null and ps.has_method("print_stats"):
		ps.print_stats()
		_log_message("PawnSpawner.print_stats() called")
	else:
		_log_message("PawnSpawner.print_stats not found")

func _action_dump_jobs() -> void:
	if JobManager != null and JobManager.has_method("print_debug"):
		JobManager.print_debug()
		_log_message("JobManager.print_debug() called")
	else:
		_log_message("JobManager.print_debug not available")

func _action_stockpile() -> void:
	if ColonySimServices != null and ColonySimServices.has_method("print_stockpile"):
		ColonySimServices.print_stockpile()
		_log_message("ColonySimServices.print_stockpile() called")
	else:
		if get_tree().get_root().has_node("Main"):
			var main := _get_main()
			if main != null and main.has_method("_print_stockpile"):
				main._print_stockpile()
				_log_message("Main._print_stockpile() called")
				return
		_log_message("Print stockpile not available")

func _action_toggle_draft() -> void:
	var main := _get_main()
	if main != null and main.has_method("_toggle_draft_mode"):
		main._toggle_draft_mode()
		_log_message("Toggled draft mode")
	else:
		_log_message("Toggle draft mode not available")

func _action_region_inspector() -> void:
	var main := _get_main()
	if main != null and main.has_method("_toggle_region_inspector"):
		main._toggle_region_inspector()
		_log_message("Toggled region inspector")

func _action_timeline() -> void:
	var main := _get_main()
	if main != null and main.has_method("_toggle_timeline_controls"):
		main._toggle_timeline_controls()
		_log_message("Toggled timeline controls")

func _action_ledger() -> void:
	var main := _get_main()
	if main != null and main.has_method("_toggle_chronicle_ledger"):
		main._toggle_chronicle_ledger()
		_log_message("Toggled chronicle ledger")

func _action_capture_resource_truth() -> void:
	var main := _get_main()
	if main != null and main.has_method("_debug_capture_resource_truth"):
		main._debug_capture_resource_truth()
		_log_message("Captured resource truth")

func _action_kernel_diag() -> void:
	var main := _get_main()
	if main != null and main.has_method("_kernel_diagnostic"):
		if main._kernel_diagnostic != null and main._kernel_diagnostic.has_method("start_settlement_truth_verification"):
			main._kernel_diagnostic.start_settlement_truth_verification()
			_log_message("Kernel diagnostic started")
			return
	_log_message("Kernel diagnostic not available")

func _action_settlement_verify() -> void:
	var main := _get_main()
	if main != null and main.has_method("_kernel_diagnostic"):
		if main._kernel_diagnostic != null and main._kernel_diagnostic.has_method("start_settlement_truth_verification"):
			main._kernel_diagnostic.start_settlement_truth_verification()
			_log_message("Settlement truth verification started")
			return
	_log_message("Settlement verify not available")

func _action_run_testtrait() -> void:
	var test_path := "res://scripts/tests/TestTraitSystem.gd"
	if ResourceLoader.exists(test_path):
		var s := load(test_path)
		if s != null:
			var node: Node = null
			if s is Script:
				node = (s as Script).new()
			if node != null:
				add_child(node)
				if node.has_method("run_test"):
					var ok: Variant = node.call("run_test")
					_log_message("TestTraitSystem.run_test() -> %s" % str(ok))
				else:
					_log_message("TestTraitSystem instantiated (no run_test method)")
			else:
				_log_message("Failed to instantiate TestTraitSystem")
		else:
			_log_message("Failed to load TestTraitSystem script")
	else:
		_log_message("TestTraitSystem not found at %s" % test_path)

func _action_save_chronicle() -> void:
	if ChronicleExport != null and ChronicleExport.has_method("save_chronicle_to_file"):
		var path: String = ChronicleExport.save_chronicle_to_file()
		if not path.is_empty():
			_log_message("Chronicle saved to %s" % path)
		else:
			_log_message("Failed to save chronicle")
	else:
		_log_message("ChronicleExport.save_chronicle_to_file not available")

func _action_save_world_seed() -> void:
	if ChronicleExport != null and ChronicleExport.has_method("save_world_seed_to_file"):
		var path: String = ChronicleExport.save_world_seed_to_file()
		if not path.is_empty():
			_log_message("World seed saved to %s" % path)
		else:
			_log_message("Failed to save world seed")
	else:
		_log_message("ChronicleExport.save_world_seed_to_file not available")

func _action_copy_log() -> void:
	if _log != null:
		DisplayServer.clipboard_set(_log.text)
		_log_message("Copied log to clipboard")

func _action_export_log() -> void:
	var path := "user://debug_log.txt"
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(_log.text)
		f.close()
		_log_message("Exported log to %s" % path)
	else:
		_log_message("Failed to open export path %s" % path)

func _action_clear_log() -> void:
	if _log != null:
		_log.clear()
		_log_message("Log cleared")

func _on_hotkey_toggled(pressed: bool) -> void:
	var main := _get_main()
	if main != null and main.has_method("_set_hotkeys_enabled"):
		main._set_hotkeys_enabled(pressed)
		_log_message("Hotkeys set to %s" % str(pressed))
