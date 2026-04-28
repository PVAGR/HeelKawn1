extends RefCounted

## One stdout block for **long-session handoff** (1–2 sim years, paste to humans/AI).
## Deterministic facts only; no RNG. Pair with `docs/HEELKAWN_SIM_MATRIX.md`.

const BUNDLE_VERSION: String = "1.0.0"
const MATRIX_DOC_PATH: String = "res://docs/HEELKAWN_SIM_MATRIX.md"


func print_bundle(main: Node) -> void:
	var tick: int = GameManager.tick_count
	print("=== HEELKAWN_SOUL_BUNDLE v=%s tick=%d BEGIN ===" % [BUNDLE_VERSION, tick])
	print("matrix_doc=%s" % MATRIX_DOC_PATH)
	print(
			"sim_calendar: sim_year_index=%d tick_within_sim_year=%d visual_day_in_year=%d/%d abs_visual_day=%d"
			% [
				SimTime.sim_year_index(tick),
				SimTime.tick_within_sim_year(tick),
				SimTime.calendar_day_within_sim_year(tick),
				SimTime.visual_days_per_sim_year(),
				SimTime.calendar_absolute_visual_day(tick),
			]
	)
	print(
			"handoff_ticks: TICKS_PER_SIM_YEAR=%d  suggested_paste_milestones=[%d, %d] (~1yr, ~2yr)"
			% [SimTime.TICKS_PER_SIM_YEAR, SimTime.TICKS_PER_SIM_YEAR, SimTime.TICKS_PER_SIM_YEAR * 2]
	)
	print("sim_diag: %s" % str(GameManager.sim_diag()))
	print("colony_sim: stance/pressures snapshot: %s" % str(_colony_sim_line()))
	var js: Dictionary = JobManager.stats()
	print(
			"jobs: open=%s claimed=%s posted=%s completed=%s"
			% [str(js.get("open", "?")), str(js.get("claimed", "?")), str(js.get("posted", "?")), str(js.get("completed", "?"))]
	)
	print("settlements: count=%d" % SettlementMemory.settlements.size())
	print("world_memory: event_count=%d" % WorldMemory.event_count())
	if main != null and main.has_method("get_wildlife_snapshot_for_diagnostic"):
		print("wildlife: %s" % str(main.call("get_wildlife_snapshot_for_diagnostic")))
	print("--- world_memory_tail (newest last; max 40) ---")
	for e in WorldMemory.get_recent_events(40):
		print(str(e))
	print("--- history_export_snip (private_dev, first 80 lines max) ---")
	var hist: String = WorldMemory.get_history_export_string(false)
	var hist_lines: PackedStringArray = hist.split("\n")
	var cap: int = mini(80, hist_lines.size())
	for i in range(cap):
		print(hist_lines[i])
	if hist_lines.size() > cap:
		print("... (%d more lines; full export via F10 report 15)" % (hist_lines.size() - cap))
	print("SimVision: %s" % SimVision.feature_inventory_line())
	print("=== HEELKAWN_SOUL_BUNDLE v=%s tick=%d END ===" % [BUNDLE_VERSION, tick])


func _colony_sim_line() -> Dictionary:
	return {
		"stance": ColonySimServices.get_stance_display(),
		"food_p": ColonySimServices.get_food_pressure(),
		"housing_p": ColonySimServices.get_housing_pressure(),
		"materials_p": ColonySimServices.get_materials_pressure(),
	}
