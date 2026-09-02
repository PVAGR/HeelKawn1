extends SceneTree

## Regression: F10 CreatorDebugMenu live-data, AI-snapshot, and anomalies path
## must run against REAL HeelKawnian nodes without raising "Invalid call" /
## "Nonexistent function 'get' in base 'Nil'" (regressions for the old
## `_count_working_pawns` `.has()`-on-Node2D crash AND the 2A
## `oldest_open_job.get(...)`-on-Nil crash in `_detect_anomalies`).
##
## Boots Main, waits for pawns+sim ticks, forces two known pawn states, then
## exercises _collect_pawn_vitals / _count_working_pawns / _update_live_data
## (exact path of the live-panel crash), the SETTLEMENTS & PAWNS report, the
## full `_build_ai_snapshot_dict` -> `_detect_anomalies` snapshot (all 13
## sections + anomalies + section timings), every category formatter and report
## button, the COPY path (clipboard skipped in headless), and re-verifies the
## F10 read-only contract (tick / open jobs / a pawn's hunger unchanged).
##
## 2B: drives every report button through the REAL `_on_ai_button_pressed`
## dispatcher and runs `_on_copy_ai_snapshot` via it — the exact master path of
## the "%a number is required in operator '%'" crash at the old
## `_get_world_section` "Zoom: %.2f" % camera.zoom(Vector2) line. It then
## validates the written `user://heelkawn_world_snapshot.txt` (exists, non-zero,
## snapshot title + every section header + the WORLD section), requires the
## early-world WORLD section to render explicit "Settlement Centers (0)" /
## "Proto Site Centers (0)" counts, and round-trips the snapshot through
## `_to_json` (JSON.stringify) + JSON.parse_string back to a Dictionary.
##
## 2C: curated 16-block COPY master. Selects a REAL HeelKawnian through
## Main's actual `_set_selected_pawn` path (same object the pawn inspector
## binds), rebuilds the snapshot, and asserts the SELECTED PAWN block proves
## id != -1 and tile == pawn.data.tile_pos (never a bogus (-1,-1)); deselects
## and asserts every renderer degrades cleanly. Cross-checks the consistency
## contract (OVERVIEW population/jobs/settlements/food == the POPULATION /
## WORK / SETTLEMENTS / FOOD blocks), validates the COPY file contains the now-
## curated block headers, the "Completed: unavailable" job truth, the selected
## pawn's real tile, and no raw "[b]" BBCode. Mid-world (>=1 formal settlement)
## validation is the USER's step: this tool stops far below the tick-6000
## autosave boundary (there is no sim-side fence hook in this tree), so it can
## only ever exercise the early/zero-settlement world deterministically.
##
## AUTOSAVE FENCE (Permanent Tool Rule): Main writes the production autosave
## only at tick % 6000. This tool boots a FRESH world and stops at TARGET_TICK
## (<< 6000), so no autosave can fire; the tool still hard-aborts if it ever
## observed tick >= 6000 before pausing, so an aged user autosave can never be
## overwritten by a runaway run.
##
## IMPORTANT: this tool must NOT reference the `HeelKawnian` class_name
## statically. Scripts passed via `--script` are compiled before autoloads
## register, and HeelKawnian.gd depends on the `BuildingRegistry` autoload
## identifier — a static reference would break HeelKawnian's compile for the
## whole session and prevent pawn spawn during boot.
##
## Run: Godot --path . -s res://tools/f10_live_data_regression.gd --headless

const TARGET_TICK: int = 20
const MAX_WALL_MS: int = 90000

var _main: Node = null
var _menu: Node = null
var _pawns_node: Node = null
var _done: bool = false
var _started_wall_ms: int = 0
var _all_ok: bool = true
var _stage: int = 0
## Wall-ms timestamp when the menu was made visible for the _process-path check.
var _visible_at_ms: int = -1
var _last_vitals: Dictionary = {}

## 2C: selected-pawn state captured for COPY-file validation.
var _sel_pawn: Node = null
var _sel_id: int = -1
var _sel_tile: Vector2i = Vector2i(-1, -1)

## Read-only contract baselines captured before any menu snapshot call and
## re-verified afterwards (F10 must never move pawns, jobs, hunger, or tick).
var _ro_tick: int = -1
var _ro_open_jobs: int = -1
var _ro_hunger: float = -1.0
var _ro_hunger_pawn: Node = null
## HK-TIME read-only baselines: target / committed / 3 lane-applied cursors must
## be unchanged by F10 snapshot builds (F10 must never advance or mutate time).
var _ro_target: float = -1.0
var _ro_committed: float = -1.0
var _ro_lane_legacy: float = -1.0
var _ro_lane_cont: float = -1.0
var _ro_lane_disc: float = -1.0
var _ro_speed_index: int = -1


func _log(line: String) -> void:
	print("[F10_REGRESS] %s" % line)


func _fail(line: String) -> void:
	_all_ok = false
	print("[F10_REGRESS] FAIL %s" % line)


func _initialize() -> void:
	var gm: Node = root.get_node_or_null("GameManager")
	if gm != null:
		if gm.has_method("set_game_tick_trace_enabled"):
			gm.call("set_game_tick_trace_enabled", false)
		if gm.has_method("set_game_speed"):
			gm.call("set_game_speed", 1)
	_log("initialize; booting Main")
	call_deferred("_spawn_main")


func _spawn_main() -> void:
	var packed: PackedScene = load("res://scenes/main/Main.tscn") as PackedScene
	if packed == null:
		_fail("could not load Main.tscn")
		quit(1)
		return
	_main = packed.instantiate()
	root.add_child(_main)
	_menu = _main.get_node_or_null("CreatorDebugMenu")
	_pawns_node = _main.get_node_or_null("WorldViewport/PawnSpawner")
	if _menu == null:
		_fail("CreatorDebugMenu not found under Main")
		quit(1)
		return
	if _pawns_node == null:
		_fail("PawnSpawner not found under Main")
		quit(1)
		return
	_started_wall_ms = Time.get_ticks_msec()
	## 01D/P3: prove the no-save fence matches the presence/absence of the flag
	## BEFORE any sim tick runs.
	_check_playtest_fence()
	_log("Main instantiated; awaiting tick %d (menu=%s)" % [TARGET_TICK, str(_menu)])


func _process(_delta: float) -> bool:
	if _done:
		return false
	if _main == null or _menu == null or _pawns_node == null:
		return false
	if Time.get_ticks_msec() - _started_wall_ms > MAX_WALL_MS:
		_fail("wall cap reached before target tick")
		_finish()
		return true
	var gm: Node = root.get_node_or_null("GameManager")
	if gm == null:
		return false
	if _stage == 0:
		var tick: int = int(gm.get("tick_count"))
		if tick < TARGET_TICK:
			return false
		if _collect_heels().is_empty():
			return false
		_run_checks()
		return false
	if _stage == 1:
		## Menu is visible; its own _process feeds _update_live_data on a 0.5s
		## timer. Give it time to fire at least once, then verify labels.
		if Time.get_ticks_msec() - _visible_at_ms > 1500:
			_check_visible_path()
			_finish()
			return true
	return false


func _collect_heels() -> Array:
	var out: Array = []
	if _pawns_node == null:
		return out
	for child in _pawns_node.get_children():
		if child != null and child.get("data") != null and child.has_method("get_pawn_data") and child.has_method("get_state"):
			out.append(child)
	return out


func _force_pawn(pawn: Node, state_value: int, expected_name: String, hunger: float) -> void:
	pawn.set("_state", state_value)
	var state_name: String = str(pawn.call("get_state_name"))
	if state_name != expected_name:
		_fail("forced state %d resolved to '%s', expected '%s' — enum drift" % [state_value, state_name, expected_name])
	var pd = pawn.get("data")
	if pd != null:
		pd.set("hunger", hunger)


func _run_checks() -> void:
	var gm: Node = root.get_node_or_null("GameManager")
	if gm != null:
		if gm.has_method("pause"):
			gm.call("pause")
	var tm: Node = root.get_node_or_null("TickManager")
	if tm != null:
		if tm.has_method("pause"):
			tm.call("pause")

	## Autosave fence: Main writes the production autosave only at tick % 6000.
	## This tool boots a FRESH world and stops at TARGET_TICK (far below 6000),
	## so no autosave can fire; still, hard-abort if we ever crossed a write
	## boundary before pausing (protects any aged user autosave).
	var current_tick: int = int(gm.get("tick_count")) if gm != null else 0
	if current_tick >= 6000:
		_fail("crossed autosave boundary (tick >= 6000) before pausing — aborting")
		_finish()
		return

	var heels: Array = _collect_heels()
	_log("pawns_with_data=%d" % heels.size())
	if heels.size() < 2:
		_fail("need >= 2 HeelKawnian nodes to force known states")
		return
	_capture_readonly_baseline(gm, heels)
	## State values mirror HeelKawnian.State (WORKING=6, SLEEPING=10); verified
	## at runtime via get_state_name() so enum drift fails loudly.
	_force_pawn(heels[0], 6, "Working", 1.0)
	_force_pawn(heels[1], 10, "Sleeping", 90.0)
	## Baseline is re-captured AFTER the harness's own state-forcing (which
	## mutates pawn0/pawn1 on purpose), so the read-only check measures only
	## whether the F10 menu path changed anything.
	_capture_readonly_baseline(gm, heels)
	_log("forced pawn0 state=%s hunger=1.0 ; pawn1 state=%s hunger=90.0" % [
		str(heels[0].call("get_state_name")), str(heels[1].call("get_state_name"))])

	if not _menu.has_method("_collect_pawn_vitals"):
		_fail("missing _collect_pawn_vitals")
		return
	var vitals: Dictionary = _menu.call("_collect_pawn_vitals")
	if not (vitals is Dictionary):
		_fail("_collect_pawn_vitals did not return Dictionary")
		return
	_log("vitals=%s" % str(vitals))
	if int(vitals.get("total", -1)) != heels.size():
		_fail("total mismatch: vitals=%s expected=%d" % [str(vitals.get("total")), heels.size()])
	if int(vitals.get("working", 0)) < 1:
		_fail("expected >=1 working pawn, got %s" % str(vitals.get("working")))
	if int(vitals.get("sleeping", 0)) < 1:
		_fail("expected >=1 sleeping pawn, got %s" % str(vitals.get("sleeping")))
	if int(vitals.get("starving", 0)) < 1:
		_fail("expected >=1 starving pawn (hunger <= HUNGER_EMERGENCY), got %s" % str(vitals.get("starving")))

	if not _menu.has_method("_count_working_pawns"):
		_fail("missing _count_working_pawns")
		return
	var active: int = int(_menu.call("_count_working_pawns"))
	_log("count_working_pawns=%d" % active)
	if active < 1:
		_fail("_count_working_pawns expected > 0, got %d" % active)

	if not _menu.has_method("_update_live_data"):
		_fail("missing _update_live_data")
		return
	_menu.call("_update_live_data")
	var working_label: String = str(_menu.get("_working_pawns_label").get("text"))
	var sleeping_label: String = str(_menu.get("_sleeping_pawns_label").get("text"))
	var starving_label: String = str(_menu.get("_starving_pawns_label").get("text"))
	_log("labels live -> %s | %s | %s" % [working_label, sleeping_label, starving_label])
	if not working_label.contains(str(vitals.get("working"))):
		_fail("Working label mismatch: %s vs vitals %s" % [working_label, str(vitals.get("working"))])
	if not sleeping_label.contains(str(vitals.get("sleeping"))):
		_fail("Sleeping label mismatch: %s vs vitals %s" % [sleeping_label, str(vitals.get("sleeping"))])
	if not starving_label.contains(str(vitals.get("starving"))):
		_fail("Starving label mismatch: %s vs vitals %s" % [starving_label, str(vitals.get("starving"))])

	if _menu.has_method("_print_settlements_pawns"):
		_menu.call("_print_settlements_pawns")
		_log("_print_settlements_pawns ran without error")
	else:
		_fail("missing _print_settlements_pawns")

	if _menu.has_method("_run_all_reports"):
		_menu.call("_run_all_reports")
		_log("_run_all_reports ran without error")
	else:
		_fail("missing _run_all_reports")

	## Regression for the 2A crash: `_build_ai_snapshot_dict` -> `_detect_anomalies`
	## ("Invalid call... Nonexistent function 'get' in base 'Nil'" at the old
	## `oldest_open_job.get("age_ticks")` line). Exercises the full COPY-AI-SNAPSHOT
	## path (minus headless clipboard), every section formatter, the anomalies
	## button, and asserts the menu never mutated simulation state.
	_run_snapshot_checks()

	## Stage 1: flip the menu visible so its own _process drives _update_live_data
	## (the exact entry path of the reported crash), then verify labels still update.
	_last_vitals = vitals
	_menu.set("visible", true)
	_visible_at_ms = Time.get_ticks_msec()
	_stage = 1
	_log("menu visible; waiting for _process-driven update…")


func _capture_readonly_baseline(gm: Node, heels: Array) -> void:
	_ro_tick = int(gm.get("tick_count")) if gm != null else -1
	var jm: Node = root.get_node_or_null("JobManager")
	if jm != null and jm.has_method("open_count"):
		_ro_open_jobs = int(jm.call("open_count"))
	for raw in heels:
		if raw is Node and raw.get("data") != null:
			_ro_hunger_pawn = raw
			_ro_hunger = float(raw.get("data").get("hunger"))
			break
	## HK-TIME read-only baselines (SimulationClock / TickManager).
	var sc: Node = root.get_node_or_null("SimulationClock")
	if sc != null:
		if sc.has_method("get_target_world_time_seconds"):
			_ro_target = float(sc.call("get_target_world_time_seconds"))
		if sc.has_method("get_committed_world_time_seconds"):
			_ro_committed = float(sc.call("get_committed_world_time_seconds"))
		if sc.has_method("get_lane_applied_world_time_seconds"):
			_ro_lane_legacy = float(sc.call("get_lane_applied_world_time_seconds", &"legacy_core"))
			_ro_lane_cont = float(sc.call("get_lane_applied_world_time_seconds", &"pawn_continuous"))
			_ro_lane_disc = float(sc.call("get_lane_applied_world_time_seconds", &"pawn_discrete"))
	var tm: Node = root.get_node_or_null("TickManager")
	if tm != null and tm.has_method("get_speed_index"):
		_ro_speed_index = int(tm.call("get_speed_index"))


func _verify_readonly() -> void:
	var gm: Node = root.get_node_or_null("GameManager")
	var tick_after: int = int(gm.get("tick_count")) if gm != null else -1
	var jm: Node = root.get_node_or_null("JobManager")
	var open_after: int = int(jm.call("open_count")) if jm != null and jm.has_method("open_count") else -1
	var hunger_after: float = float(_ro_hunger_pawn.get("data").get("hunger")) if _ro_hunger_pawn != null else -1.0
	var ro_ok := true
	if _ro_tick >= 0 and tick_after != _ro_tick:
		_fail("F10 moved the tick: %d -> %d" % [_ro_tick, tick_after])
		ro_ok = false
	if _ro_open_jobs >= 0 and open_after != _ro_open_jobs:
		_fail("F10 changed open jobs: %d -> %d" % [_ro_open_jobs, open_after])
		ro_ok = false
	if _ro_hunger >= 0.0 and hunger_after >= 0.0 and absf(hunger_after - _ro_hunger) > 0.0001:
		_fail("F10 changed pawn hunger: %f -> %f" % [_ro_hunger, hunger_after])
		ro_ok = false
	if ro_ok:
		_log("F10_READ_ONLY PASS (tick=%d open_jobs=%d hunger=%.1f unchanged)" % [tick_after, open_after, hunger_after])

	## HK-TIME read-only: target / committed / lane-applied cursors unchanged.
	var sc: Node = root.get_node_or_null("SimulationClock")
	var tm: Node = root.get_node_or_null("TickManager")
	var t_ok := true
	if _ro_target >= 0.0 and sc != null and sc.has_method("get_target_world_time_seconds"):
		var t_after: float = float(sc.call("get_target_world_time_seconds"))
		if absf(t_after - _ro_target) > 1e-6:
			_fail("F10 moved TARGET world time: %.6f -> %.6f" % [_ro_target, t_after])
			t_ok = false
	if _ro_committed >= 0.0 and sc != null and sc.has_method("get_committed_world_time_seconds"):
		var c_after: float = float(sc.call("get_committed_world_time_seconds"))
		if absf(c_after - _ro_committed) > 1e-6:
			_fail("F10 moved COMMITTED world time: %.6f -> %.6f" % [_ro_committed, c_after])
			t_ok = false
	if sc != null and sc.has_method("get_lane_applied_world_time_seconds"):
		if _ro_lane_legacy >= 0.0:
			var l_after: float = float(sc.call("get_lane_applied_world_time_seconds", &"legacy_core"))
			if absf(l_after - _ro_lane_legacy) > 1e-6:
				_fail("F10 moved legacy_core lane cursor: %.6f -> %.6f" % [_ro_lane_legacy, l_after])
				t_ok = false
		if _ro_lane_cont >= 0.0:
			var c2_after: float = float(sc.call("get_lane_applied_world_time_seconds", &"pawn_continuous"))
			if absf(c2_after - _ro_lane_cont) > 1e-6:
				_fail("F10 moved pawn_continuous lane cursor: %.6f -> %.6f" % [_ro_lane_cont, c2_after])
				t_ok = false
		if _ro_lane_disc >= 0.0:
			var d_after: float = float(sc.call("get_lane_applied_world_time_seconds", &"pawn_discrete"))
			if absf(d_after - _ro_lane_disc) > 1e-6:
				_fail("F10 moved pawn_discrete lane cursor: %.6f -> %.6f" % [_ro_lane_disc, d_after])
				t_ok = false
	if _ro_speed_index >= 0 and tm != null and tm.has_method("get_speed_index"):
		var s_after: int = int(tm.call("get_speed_index"))
		if s_after != _ro_speed_index:
			_fail("F10 changed speed index: %d -> %d" % [_ro_speed_index, s_after])
			t_ok = false
	if t_ok:
		_log("F10_TIME_DIAGNOSTICS=%s (target/committed/3-lane/speed unchanged)" % str(ro_ok))


func _run_snapshot_checks() -> void:
	## Regression for the 2A crash: `_build_ai_snapshot_dict` -> `_detect_anomalies`
	## threw "Invalid call. Nonexistent function 'get' in base 'Nil'" at the old
	## `oldest_open_job.get("age_ticks", 0)` line when no open jobs had become
	## stale. Builds the FULL snapshot (all 13 sections + anomalies + section
	## timings), runs anomaly detection twice (idempotence), formats every
	## section, drives the report buttons, and re-verifies the read-only
	## contract that F10 must never change sim state.
	if not _menu.has_method("_build_ai_snapshot_dict"):
		_fail("missing _build_ai_snapshot_dict")
		return
	var snap: Variant = _menu.call("_build_ai_snapshot_dict")
	if not (snap is Dictionary):
		_fail("_build_ai_snapshot_dict returned non-Dictionary: %s" % str(typeof(snap)))
		return
	_log("snapshot built: %d keys" % (snap as Dictionary).size())

	if not (snap.get("anomalies") is Array):
		_fail("snapshot['anomalies'] is not Array: %s" % str(snap.get("anomalies")))
	if not (snap.get("generated_ms") is float):
		_fail("snapshot['generated_ms'] is not float: %s" % str(snap.get("generated_ms")))
	var section_times: Variant = snap.get("section_timings_ms")
	if not (section_times is Dictionary):
		_fail("snapshot['section_timings_ms'] is not Dictionary")
	else:
		_log("section timings (ms): %s" % str(section_times))
	var lr_stats: Variant = snap.get("live_refresh_stats")
	if not (lr_stats is Dictionary):
		_fail("snapshot['live_refresh_stats'] is not Dictionary")

	if not _menu.has_method("_detect_anomalies"):
		_fail("missing _detect_anomalies")
		return
	var anomalies: Variant = _menu.call("_detect_anomalies", snap)
	if not (anomalies is Array):
		_fail("_detect_anomalies(snapshot) returned non-Array")
		return
	var anomalies2: Variant = _menu.call("_detect_anomalies", snap)
	if (anomalies as Array).size() != (anomalies2 as Array).size():
		_fail("_detect_anomalies not idempotent: %d vs %d" % [anomalies.size(), anomalies2.size()])
	_log("anomalies=%d (idempotent OK)" % anomalies.size())

	## An empty-dict call (the old placeholder) must not raise either.
	var empty_anomalies: Variant = _menu.call("_detect_anomalies", {})
	if not (empty_anomalies is Array):
		_fail("_detect_anomalies({}) returned non-Array")
	_log("_detect_anomalies({}) ok (%d items)" % (empty_anomalies as Array).size())

	## Every category report formatter must render from the snapshot.
	var sections := [
		"_get_overview_section",
		"_get_pawns_section",
		"_get_work_section",
		"_get_civilization_section",
		"_get_world_section",
		"_get_engine_section",
		## 2C curated-master renderers
		"_get_build_capture_section",
		"_get_looking_at_section",
		"_get_selected_pawn_section",
		"_get_why_section",
		"_get_food_section",
		"_get_settlements_section",
		"_get_structures_section",
		"_get_politics_section",
		"_get_time_section",
		"_get_recent_changes_section",
	]
	for section_name in sections:
		if not _menu.has_method(section_name):
			_fail("missing %s" % section_name)
			continue
		var text: Variant = _menu.call(section_name, snap)
		if not (text is String):
			_fail("%s returned non-String" % section_name)
			continue
		if (text as String).is_empty():
			_fail("%s returned empty String" % section_name)
			continue
		_log("%s ok (%d chars)" % [section_name, (text as String).length()])

	## Anomalies formatter (the extra renderer the snapshot text expects).
	if _menu.has_method("_format_anomalies"):
		var anomalies_text: Variant = _menu.call("_format_anomalies", anomalies as Array)
		if not (anomalies_text is String) or (anomalies_text as String).is_empty():
			_fail("_format_anomalies returned non-String or empty")
		else:
			_log("_format_anomalies ok (%d chars)" % (anomalies_text as String).length())

	## 2B: REAL button dispatcher — the exact user-click path.
	if not _menu.has_method("_on_ai_button_pressed"):
		_fail("missing _on_ai_button_pressed")
		return
	for method_name in [
		"_on_ai_overview", "_on_ai_pawns", "_on_ai_work", "_on_ai_civilization",
		"_on_ai_world", "_on_ai_engine", "_on_ai_anomalies",
	]:
		if not _menu.has_method(method_name):
			_fail("missing %s" % method_name)
			continue
		_menu.call("_on_ai_button_pressed", method_name)
		_log("%s (via button) ran without error" % method_name)

	## Direct _snapshot_text (kept as an independent unit check; the master copy
	## path below re-exercises it through the real button). A runtime error
	## inside any renderer aborts the call and returns null, so the non-String
	## / empty assertions are the script-error detector for this path.
	if _menu.has_method("_snapshot_text"):
		var snapshot_text: Variant = _menu.call("_snapshot_text", snap)
		if not (snapshot_text is String) or (snapshot_text as String).is_empty():
			_fail("_snapshot_text returned non-String or empty")

	## 2C: consistency contract. Every overview line is derived from the SAME
	## snapshot dicts as the dedicated blocks — a mismatch means wiring broke.
	_check_consistency_contract(snap)

	## 01D/P1: spatial center truth. `center_region` is an ENCODED REGION KEY,
	## never a tile index. Wherever a center exists it must decode to a region
	## coord and an in-bounds representative center tile; nothing may ever report
	## an encoded key as a world tile.
	_check_spatial_centers(snap)

	## HK-TIME: the TIME / SCHEDULER section fields must exist in the snapshot.
	_check_time_scheduler(snap)

	## 2C: SELECT a real pawn through Main's actual selection path (the same
	## object the pawn inspector binds), rebuild, and prove the snapshot now
	## describes that pawn: id != -1 and tile == pawn.data.tile_pos (never the
	## old bogus (-1,-1)). Deselection degradation is checked afterwards.
	_run_selection_checks()

	## 2B: THE crash path. `_on_ai_button_pressed("_on_copy_ai_snapshot")` runs
	## the FULL master chain: _build_ai_snapshot_dict -> _snapshot_text (all
	## sections incl. _get_world_section) -> DisplayServer.clipboard_set
	## (headless-safe no-op) -> write user://heelkawn_world_snapshot.txt.
	if not _menu.has_method("_on_copy_ai_snapshot"):
		_fail("missing _on_copy_ai_snapshot")
		return
	var copy_t0: int = Time.get_ticks_msec()
	_menu.call("_on_ai_button_pressed", "_on_copy_ai_snapshot")
	var copy_ms: int = Time.get_ticks_msec() - copy_t0
	_log("_on_copy_ai_snapshot (via button) ran without error (%d ms)" % copy_ms)
	_validate_copy_output()

	## 2B: JSON round-trip through the bundle serializer (_to_json = JSON.stringify
	## with tab indent, per _snapshot_text consumers).
	if _menu.has_method("_to_json"):
		var json_str: String = str(_menu.call("_to_json", snap))
		var parsed: Variant = JSON.parse_string(json_str)
		if not (parsed is Dictionary):
			_fail("JSON round-trip: parse_string did not return Dictionary (len=%d)" % json_str.length())
		else:
			var built_keys: int = (snap as Dictionary).size()
			var parsed_keys: int = (parsed as Dictionary).size()
			if parsed_keys < built_keys:
				_fail("JSON round-trip lost keys: parsed=%d built=%d" % [parsed_keys, built_keys])
			_log("JSON round-trip OK: %d bytes, %d keys parsed (built=%d)" % [json_str.length(), parsed_keys, built_keys])

	## The COPY button also gate-kept a live-refresh stats block; verify the
	## menu's 0.5s live path reports sane counters after this build.
	var lr_after: Variant = _menu.call("_live_refresh_stats_dict") if _menu.has_method("_live_refresh_stats_dict") else null
	_log("live_refresh_stats (tool-side): %s" % str(lr_after))

	## 2C: deselect (same UI path) and prove every renderer degrades cleanly
	## to "No pawn selected" instead of raising or emitting bogus data.
	_run_deselect_checks()

	_verify_readonly()


## 2C: select a real pawn via Main's actual `_set_selected_pawn` (the exact
## object path the pawn inspector binds), rebuild the snapshot, and assert the
## SELECTED PAWN/WHY blocks prove id != -1 and tile == data.tile_pos. Stores
## the selected pawn for the COPY-file validation that follows.
func _run_selection_checks() -> void:
	if _pawns_node == null or _main == null or _menu == null:
		_fail("selection checks: missing nodes")
		return
	var target: Node = null
	for child in _pawns_node.get_children():
		if child != null and child.get("data") != null:
			target = child
			break
	if target == null:
		_fail("selection checks: no pawn to select")
		return
	if not _main.has_method("_set_selected_pawn"):
		_fail("selection checks: _set_selected_pawn missing")
		return
	_main.call("_set_selected_pawn", target)
	var main_sel: Variant = _main.call("get_selected_pawn") if _main.has_method("get_selected_pawn") else _main.get("_selected_pawn")
	if main_sel != target:
		_fail("selection checks: Main ignored _set_selected_pawn (incarnation lock?)")
		return
	_sel_pawn = target
	var pd: Variant = target.get("data")
	if pd == null or not pd.has_method("get"):
		_fail("selection checks: selected pawn has no data")
		return
	_sel_id = int(pd.get("id"))
	_sel_tile = pd.get("tile_pos")
	if not (_sel_tile is Vector2i):
		_fail("selection checks: pawn.data.tile_pos is %s, not Vector2i" % str(typeof(_sel_tile)))
		return
	var snap: Variant = _menu.call("_build_ai_snapshot_dict")
	if not (snap is Dictionary):
		_fail("selection checks: snapshot build failed")
		return
	var selected: Variant = snap.get("selected_pawn")
	if not (selected is Dictionary) or selected.get("selected", false) != true:
		_fail("selection checks: snapshot selected_pawn.selected != true with a pawn selected")
		return
	if _sel_id < 0:
		_fail("selection checks: pawn id %d should be >= 0" % _sel_id)
	elif int(selected.get("pawn_id", -1)) != _sel_id:
		_fail("selection checks: snapshot pawn_id %d != selected pawn id %d" % [int(selected.get("pawn_id", -1)), _sel_id])
	var snap_tile: Variant = selected.get("tile")
	if not (snap_tile is Vector2i) or snap_tile == Vector2i(-1, -1):
		_fail("selection checks: snapshot tile %s must match real pawn tile %s" % [str(snap_tile), str(_sel_tile)])
	elif snap_tile != _sel_tile:
		_fail("selection checks: snapshot tile %s != pawn.data.tile_pos %s" % [str(snap_tile), str(_sel_tile)])
	if str(selected.get("state_name", "")) == "":
		_fail("selection checks: selected pawn state_name empty")
	var why: Variant = selected.get("why")
	if not (why is Dictionary):
		_fail("selection checks: selected_pawn.why is not a Dictionary")
	elif str(why.get("reason", "")) == "":
		_fail("selection checks: selected_pawn.why.reason empty")
	_log("selection checks PASS: id=%d tile=%s state=%s reason=%s" % [
		_sel_id, str(_sel_tile), str(selected.get("state_name")), str(why.get("reason", "") if why is Dictionary else "")])
	## Consistency contract on the SELECTED snapshot too (same builders).
	_check_consistency_contract(snap)


func _run_deselect_checks() -> void:
	if _main == null or _menu == null:
		return
	if _sel_pawn != null:
		if _main.has_method("_set_selected_pawn"):
			_main.call("_set_selected_pawn", null)
	var main_sel: Variant = _main.call("get_selected_pawn") if _main.has_method("get_selected_pawn") else _main.get("_selected_pawn")
	if main_sel != null:
		_fail("deselect checks: Main still reports a selected pawn")
		return
	var snap: Variant = _menu.call("_build_ai_snapshot_dict")
	if not (snap is Dictionary):
		_fail("deselect checks: snapshot build failed")
		return
	var selected: Variant = snap.get("selected_pawn")
	if selected is Dictionary and selected.get("selected", false) != false:
		_fail("deselect checks: snapshot still claims a selected pawn")
		return
	## Every selection/why-sensitive renderer must still return a non-empty String.
	for section_name in ["_get_selected_pawn_section", "_get_why_section", "_get_looking_at_section", "_snapshot_text"]:
		if not _menu.has_method(section_name):
			_fail("deselect checks: missing %s" % section_name)
			continue
		var text: Variant = _menu.call(section_name, snap)
		if not (text is String) or (text as String).is_empty():
			_fail("deselect checks: %s returned non-String/empty with no pawn selected" % section_name)
	_log("deselect checks PASS: renderers degrade cleanly with no pawn selected")


## 2C: consistency contract — the OVERVIEW block is only truthful if its
## population/jobs/settlements/food lines equal the dedicated blocks' values.
## 01D/P1: spatial center truth. Settlement/proto `center_region` values are
## ENCODED REGION KEYS (rx low-16, ry high-16, region = 16x16 tiles) — never
## tile indexes. The snapshot must expose explicit decoded fields, and any
## reported center tile must be inside world bounds. An encoded key must never
## be surfaced as a world tile, and -1 entries are never acceptable output.
func _check_spatial_centers(snap: Dictionary) -> void:
	if _menu == null:
		return
	var spatial: Dictionary = snap.get("spatial", {})
	var world_dims: Dictionary = spatial.get("world", {})
	var world_x: int = int(world_dims.get("width", 0))
	var world_y: int = int(world_dims.get("height", 0))
	var lists: Array = [
		["Settlement Centers", spatial.get("settlement_centers", null)],
		["Proto Site Centers", spatial.get("proto_centers", null)],
	]
	for pair in lists:
		var label: String = str(pair[0])
		var centers: Variant = pair[1]
		if centers == null:
			_fail("spatial centers: %s missing from snapshot" % label)
			continue
		if not (centers is Array):
			_fail("spatial centers: %s is not an Array" % label)
			continue
		if (centers as Array).is_empty():
			_log("spatial centers: %s (0) — early world, nothing to decode" % label)
			continue
		for center in (centers as Array):
			if not (center is Dictionary):
				_fail("spatial centers: %s contains a non-Dictionary entry" % label)
				continue
			var entry: Dictionary = center as Dictionary
			var rk: int = int(entry.get("center_region_key", -1))
			var coord: Variant = entry.get("center_region_coord", Vector2i(-1, -1))
			var avail: bool = bool(entry.get("center_tile_available", false))
			var tile: Variant = entry.get("center_tile", Vector2i(-1, -1))
			if rk < 0:
				_fail("spatial centers: %s has center_region_key %d (must be >= 0)" % [label, rk])
				continue
			if not (coord is Vector2i):
				_fail("spatial centers: %s missing Vector2i center_region_coord" % label)
				continue
			if coord.x < 0 or coord.y < 0:
				_fail("spatial centers: %s region coord %s out of bounds" % [label, str(coord)])
				continue
			if not avail:
				_fail("spatial centers: %s center tile unavailable (center_region_key=%d) — every center must resolve to an in-bounds tile" % [label, rk])
				continue
			if not (tile is Vector2i):
				_fail("spatial centers: %s missing Vector2i center_tile" % label)
				continue
			if tile.x < 0 or tile.y < 0:
				_fail("spatial centers: %s center tile %s is a sentinel, not a real tile" % [label, str(tile)])
				continue
			if world_x > 0 and world_y > 0 and (tile.x >= world_x or tile.y >= world_y):
				_fail("spatial centers: %s center tile %s outside world %dx%d" % [label, str(tile), world_x, world_y])
				continue
			## The old 01D bug surfaced encoded keys as flat tile indexes
			## (e.g. (3,256) / (9,1024)); a decoded region coord times the region
			## size must reproduce the reported center tile.
			var expected_tile_x: int = coord.x * 16 + 8
			var expected_tile_y: int = coord.y * 16 + 8
			if tile.x != expected_tile_x or tile.y != expected_tile_y:
				_fail("spatial centers: %s tile %s does not match region coord %s (expect %s)" % [label, str(tile), str(coord), str(Vector2i(expected_tile_x, expected_tile_y))])
	_log("spatial centers PASS (settlement_centers=%d proto_centers=%d world=%dx%d)" % [int((lists[0][1] as Array).size() if lists[0][1] is Array else 0), int((lists[1][1] as Array).size() if lists[1][1] is Array else 0), world_x, world_y])


## 01D/P3 + 02A-R/P0: the save fence must be structurally active on Main
## exactly when save writes are expected to be disabled. Since 02A-R, DEBUG
## builds default to disabled (unless --allow-save-writes); --playtest-no-save
## forces disabled; RELEASE builds default to enabled.
func _check_playtest_fence() -> void:
	if _main == null:
		return
	var fence: bool = bool(_main.get("_save_writes_disabled_for_playtest"))
	var wants_disabled: bool = OS.get_cmdline_user_args().has("--playtest-no-save") or (
		OS.is_debug_build() and not OS.get_cmdline_user_args().has("--allow-save-writes"))
	var wants_enabled: bool = (not OS.is_debug_build() and not OS.get_cmdline_user_args().has("--playtest-no-save")) or (
		OS.get_cmdline_user_args().has("--allow-save-writes"))
	if wants_disabled and not fence:
		_fail("save writes expected disabled but Main._save_writes_disabled_for_playtest is false (fence not applied)")
	elif wants_enabled and fence:
		_fail("save writes expected enabled but Main._save_writes_disabled_for_playtest is true (fence over-applied)")
	else:
		_log("playtest fence %s (expected-disabled=%s)" % ["ACTIVE" if fence else "inactive", str(wants_disabled)])


func _check_consistency_contract(snap: Dictionary) -> void:
	if _menu == null:
		return
	var pop_total: int = int(snap.get("population", {}).get("total_pawns", -1))
	var jobs_open: int = int(snap.get("jobs", {}).get("open", -1))
	var formal_count: int = int(snap.get("settlements", {}).get("formal", {}).get("count", -1))
	var food_edible: int = int(snap.get("food", {}).get("total_food", -1))
	if pop_total < 0 or jobs_open < 0 or formal_count < 0 or food_edible < 0:
		_fail("consistency: snapshot missing expected section values")
		return
	var ov: String = str(_menu.call("_get_overview_section", snap))
	if not ov.contains("Population: %d pawns" % pop_total):
		_fail("consistency: OVERVIEW population != POPULATION (%d)" % pop_total)
	if not ov.contains("Jobs: %d open" % jobs_open):
		_fail("consistency: OVERVIEW open jobs != WORK (%d)" % jobs_open)
	if not ov.contains("Settlements: %d formal" % formal_count):
		_fail("consistency: OVERVIEW formal settlements != SETTLEMENTS (%d)" % formal_count)
	if not ov.contains("Food (edible, Item.is_food): %d units" % food_edible):
		_fail("consistency: OVERVIEW edible food != FOOD (%d)" % food_edible)
	if not str(_menu.call("_get_pawns_section", snap)).contains("Total Pawns: %d" % pop_total):
		_fail("consistency: PAWNS total != population (%d)" % pop_total)
	if not str(_menu.call("_get_work_section", snap)).contains("Open Jobs: %d" % jobs_open):
		_fail("consistency: WORK open != jobs (%d)" % jobs_open)
	if not str(_menu.call("_get_settlements_section", snap)).contains("Formal: %d" % formal_count):
		_fail("consistency: SETTLEMENTS formal != settlements (%d)" % formal_count)
	if not str(_menu.call("_get_food_section", snap)).contains("Edible Food (Item.is_food): %d units" % food_edible):
		_fail("consistency: FOOD edible != food (%d)" % food_edible)
	_log("consistency contract PASS (pop=%d jobs=%d formal=%d edible=%d)" % [pop_total, jobs_open, formal_count, food_edible])


## HK-TIME: assert every TIME / SCHEDULER field the objective requires actually
## exists in the snapshot (read-only; this check itself never mutates time).
func _check_time_scheduler(snap: Dictionary) -> void:
	var time: Variant = snap.get("time")
	if not (time is Dictionary):
		_fail("snapshot missing 'time' section (got %s)" % str(typeof(time)))
		return
	var required := [
		"requested_speed", "target_world_seconds", "committed_world_seconds",
		"target_committed_lag_seconds", "legacy_core_applied",
		"pawn_continuous_applied", "pawn_discrete_applied", "compat_tick",
		"compat_tick_rate_real_sec", "scheduler_pending", "paused"
	]
	for f in required:
		if not (time as Dictionary).has(f):
			_fail("time section missing required field '%s'" % f)
	## The objective names these flat fields for the bounded aggregate; guarantee
	## they exist and are numeric.
	var flat := [
		"pawn_discrete_min_applied", "pawn_discrete_max_applied",
		"pawn_discrete_total_queued", "pawn_discrete_max_queued",
		"pawn_discrete_total_consumed",
	]
	for f in flat:
		if not (time as Dictionary).has(f):
			_fail("time section missing pawn_discrete field '%s'" % f)
	## Sanity: committed never exceeds target, lag = target - committed (>=0).
	var target: float = float(time.get("target_world_seconds", 0.0))
	var committed: float = float(time.get("committed_world_seconds", 0.0))
	var lag: float = float(time.get("target_committed_lag_seconds", 0.0))
	if committed > target + 1e-6:
		_fail("time contract broken: committed %.6f > target %.6f" % [committed, target])
	if lag < 0.0 or absf(lag - maxf(0.0, target - committed)) > 1e-3:
		_fail("time contract broken: lag %.6f != max(0, target-committed)=%.6f" % [lag, maxf(0.0, target - committed)])
	## Render the section (exercises the formatter crash-free).
	if _menu != null and _menu.has_method("_get_time_section"):
		var text: Variant = _menu.call("_get_time_section", snap)
		if not (text is String) or (text as String).is_empty():
			_fail("_get_time_section returned non-String or empty")
		else:
			_log("time section renders ok (%d chars)" % (text as String).length())
	if _all_ok:
		_log("F10_TIME_DIAGNOSTICS=PASS (time/scheduler fields present, contract sane, renderer ok)")
	else:
		_log("F10_TIME_DIAGNOSTICS=FAIL (see above)")


func _validate_copy_output() -> void:
	## 2B/2C: the master copy path must have produced user://heelkawn_world_snapshot.txt
	## (a runtime error anywhere in the chain aborts the write, so a
	## missing/empty file is the crash detector), containing every curated
	## block header, the "Completed: unavailable" job truth, the selected pawn's
	## REAL tile (never (-1,-1)), and no raw BBCode.
	var path := "user://heelkawn_world_snapshot.txt"
	if not FileAccess.file_exists(path):
		_fail("copy path did not write %s" % path)
		return
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		_fail("cannot read %s" % path)
		return
	var text: String = f.get_as_text()
	f.close()
	if text.is_empty():
		_fail("%s is empty" % path)
		return
	if not text.contains("HEELKAWN AI WORLD SNAPSHOT"):
		_fail("%s missing snapshot title" % path)
	var expected_titles := [
		"HEELKAWN AI WORLD SNAPSHOT - BUILD / CAPTURE",
		"HEELKAWN AI WORLD SNAPSHOT - WHAT THE PLAYER IS LOOKING AT",
		"HEELKAWN AI WORLD SNAPSHOT - SELECTED PAWN",
		"HEELKAWN AI WORLD SNAPSHOT - WHY IS THIS PAWN DOING THIS?",
		"HEELKAWN AI WORLD SNAPSHOT - PAWNS",
		"HEELKAWN AI WORLD SNAPSHOT - WORK",
		"HEELKAWN AI WORLD SNAPSHOT - FOOD / SURVIVAL",
		"HEELKAWN AI WORLD SNAPSHOT - SETTLEMENTS / PROTOS / REALMS",
		"HEELKAWN AI WORLD SNAPSHOT - WORLD",
		"HEELKAWN AI WORLD SNAPSHOT - STRUCTURES / DEVELOPMENT",
		"HEELKAWN AI WORLD SNAPSHOT - CIVILIZATION",
		"HEELKAWN AI WORLD SNAPSHOT - POLITICS / DIPLOMACY",
		"HEELKAWN AI WORLD SNAPSHOT - TIME / SCHEDULER",
		"HEELKAWN AI WORLD SNAPSHOT - ENGINE",
		"HEELKAWN AI WORLD SNAPSHOT - ANOMALIES",
		"HEELKAWN AI WORLD SNAPSHOT - WHAT CHANGED RECENTLY",
	]
	for title in expected_titles:
		if not text.contains(title):
			_fail("%s missing curated section header: %s" % [path, title])
	## The exact line that crashed in the human session ("Zoom: %.2f" % camera.zoom).
	if not text.contains("Zoom:"):
		_fail("%s missing camera Zoom line" % path)
	## Early-world requirement: fresh boot has 0 formal / 0 proto settlements;
	## the world section must render explicit counts, NOT "unavailable".
	if not text.contains("Settlement Centers (0)"):
		_fail("early-world world section did not render 'Settlement Centers (0)': %s" % path)
	if not text.contains("Proto Site Centers (0)"):
		_fail("early-world world section did not render 'Proto Site Centers (0)': %s" % path)
	## 2C job truth: completed is a documented gap, never a misleading 0.
	if not text.contains("Completed: unavailable (JobManager maintains no completion counter)"):
		_fail("%s missing 'Completed: unavailable' job truth" % path)
	## 2C food truth: edible-vs-generic split must be labeled.
	if not text.contains("Edible Food (Item.is_food)"):
		_fail("%s missing edible-food definition label" % path)
	## 2C selected pawn: with a pawn selected for this copy, the COPY must show
	## its real tile (tile_pos), not the old bogus (-1,-1).
	if _sel_pawn != null and _sel_tile != Vector2i(-1, -1):
		if not text.contains("(%d, %d)" % [_sel_tile.x, _sel_tile.y]):
			_fail("%s missing selected pawn real tile %s" % [path, str(_sel_tile)])
		if not text.contains("Selected Pawn Tile: (%d, %d)" % [_sel_tile.x, _sel_tile.y]):
			_fail("%s world section missing real selected-pawn tile %s" % [path, str(_sel_tile)])
	## No raw BBCode may leak into the plain-text copy.
	if text.contains("[b]") or text.contains("[i]") or text.contains("[color="):
		_fail("%s contains raw BBCode (should be plain text)" % path)
	_log("%s validated: %d bytes, %d block headers, Zoom line, 0/0 settlements, job-food truth, selected tile %s" % [
		path, text.length(), expected_titles.size(), str(_sel_tile)])


func _check_visible_path() -> void:
	var working_label: String = str(_menu.get("_working_pawns_label").get("text"))
	var sleeping_label: String = str(_menu.get("_sleeping_pawns_label").get("text"))
	var starving_label: String = str(_menu.get("_starving_pawns_label").get("text"))
	_log("visible-path labels -> %s | %s | %s" % [working_label, sleeping_label, starving_label])
	if working_label.contains("--"):
		_fail("visible path never updated Working label: %s" % working_label)
	if sleeping_label.contains("--"):
		_fail("visible path never updated Sleeping label: %s" % sleeping_label)
	if starving_label.contains("--"):
		_fail("visible path never updated Starving label: %s" % starving_label)
	if not working_label.contains(str(_last_vitals.get("working"))):
		_fail("visible-path Working mismatch: %s vs %s" % [working_label, str(_last_vitals.get("working"))])


func _finish() -> void:
	_done = true
	if _all_ok:
		_log("OK all live-data + report checks passed")
		quit(0)
	else:
		_log("REGRESSION FAILED")
		quit(2)