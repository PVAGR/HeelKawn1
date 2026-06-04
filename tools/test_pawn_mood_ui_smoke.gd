extends SceneTree

## PawnMoodUI runtime smoke.
## Verifies that PawnKawnianData-aware UI reads real HeelKawnianData
## (no silent nulls from missing fields, no fake empty arrays).
## Run: Godot --path . -s res://tools/test_pawn_mood_ui_smoke.gd --headless

var _failures: Array[String] = []


func _initialize() -> void:
	_run()


func _run() -> void:
	print("[PMUI_SMOKE] starting")
	_test_updates_use_real_data()
	if _failures.is_empty():
		print("[PMUI_SMOKE] PASS")
		quit(0)
	else:
		for f in _failures:
			printerr("[PMUI_SMOKE] FAIL: " + f)
		print("[PMUI_SMOKE] FAILED (%d failures)" % _failures.size())
		quit(1)


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		_failures.append(msg)


func _make_pawn_data():
	# Build a HeelKawnianData with realistic non-default values.
	# Load scripts at call time so the class_name registry / script cache
	# is fully populated by the autoloads that have already started.
	var data_script: Script = load("res://scripts/pawn/HeelKawnianData.gd")
	var data = data_script.new()
	data.display_name = "Tester"
	data.mood = 73.0
	data.health = 80.0
	data.hunger = 60.0
	data.rest = 65.0
	data.pain = 25.0
	data.need_satisfaction = {
		"survival": 60.0,
		"safety": 70.0,
		"belonging": 55.0,
		"esteem": 50.0,
		"self_actualization": 30.0,
	}
	var tr_script: Script = load("res://scripts/pawn/Trait.gd")
	var tr = tr_script.new(tr_script.Type.WORKHORSE)
	data.traits = [tr]
	var me_script: Script = load("res://scripts/pawn/MoodEvent.gd")
	var me = me_script.new(me_script.Type.JOY, 80.0, 500)
	data.mood_events = [me]
	data.injuries = {"cut": 30.0, "burn": 15.0}
	return data


func _test_updates_use_real_data() -> void:
	var pawn_data = _make_pawn_data()

	# Instantiate the UI and add it to the tree so _build_ui's add_child works.
	var ui_script: Script = load("res://scripts/ui/PawnMoodUI.gd")
	var ui = ui_script.new()
	root.add_child(ui)
	if ui.has_method("_build_ui"):
		ui.call("_build_ui")

	# Inject data directly (skip the Main/PawnSpawner lookup; we are testing the
	# update_* methods, not the scene path).
	ui.set("_pawn_id", pawn_data.id)
	ui.set("_pawn_data", pawn_data)

	# Run the update methods and assert they reflect the real data.
	ui.call("_update_mood")
	ui.call("_update_needs")
	ui.call("_update_thoughts")
	ui.call("_update_traits")
	ui.call("_update_health")

	# Mood label: "%d/100" with int(mood).
	var mood_label: Label = ui.get("_mood_label")
	_expect(mood_label != null, "mood_label not created")
	if mood_label != null:
		_expect(mood_label.text == "73/100", "mood_label.text was '%s' expected '73/100'" % mood_label.text)

	# Mood bar value.
	var mood_bar: ProgressBar = ui.get("_mood_bar")
	_expect(mood_bar != null, "mood_bar not created")
	if mood_bar != null:
		_expect(mood_bar.value == 73.0, "mood_bar.value was %f expected 73.0" % mood_bar.value)

	# Need bars: each maps to a real source.
	# hunger -> data.hunger (60), rest -> data.rest (65),
	# social -> need_satisfaction.belonging (55), safety -> need_satisfaction.safety (70),
	# comfort -> 100 - data.pain (75).
	var need_expectations: Dictionary = {
		"hunger": 60.0,
		"rest": 65.0,
		"social": 55.0,
		"safety": 70.0,
		"comfort": 75.0,
	}
	var needs_container: VBoxContainer = ui.get("_needs_container")
	_expect(needs_container != null, "needs_container not created")
	if needs_container != null:
		for need_name in need_expectations:
			var expected: float = float(need_expectations[need_name])
			var bar: ProgressBar = needs_container.get_node_or_null("Need_" + need_name) as ProgressBar
			_expect(bar != null, "need bar missing: Need_" + need_name)
			if bar != null:
				_expect(
					is_equal_approx(bar.value, expected),
					"need %s: bar.value was %f expected %f" % [need_name, bar.value, expected]
				)

	# Thoughts: one mood_event -> one label with the event's description.
	var thoughts_container: VBoxContainer = ui.get("_thoughts_container")
	_expect(thoughts_container != null, "thoughts_container not created")
	if thoughts_container != null:
		var thought_children: Array = thoughts_container.get_children()
		_expect(thought_children.size() == 1, "thoughts_container children = %d expected 1" % thought_children.size())
		if thought_children.size() == 1:
			var lbl: Label = thought_children[0] as Label
			_expect(lbl != null and lbl.text.contains("Joyful"), "thought label text was '%s' expected to contain 'Joyful'" % (lbl.text if lbl != null else "<null>"))

	# Traits: one WORKHORSE -> one chip with display_name "Workhorse".
	var traits_container: FlowContainer = ui.get("_traits_container")
	_expect(traits_container != null, "traits_container not created")
	if traits_container != null:
		var trait_children: Array = traits_container.get_children()
		_expect(trait_children.size() == 1, "traits_container children = %d expected 1" % trait_children.size())
		if trait_children.size() == 1:
			var chip: Label = trait_children[0] as Label
			_expect(chip != null and chip.text == "Workhorse", "trait chip text was '%s' expected 'Workhorse'" % (chip.text if chip != null else "<null>"))

	# Health label: 2 injuries -> "Wounded (2 injuries)".
	var health_label: Label = ui.get("_health_label")
	_expect(health_label != null, "health_label not created")
	if health_label != null:
		_expect(health_label.text == "Wounded (2 injuries)", "health_label.text was '%s' expected 'Wounded (2 injuries)'" % health_label.text)


