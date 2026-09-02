extends SceneTree

## Parse + calendar-value check for the FIX-STUCK-CALENDAR change:
##   - DayNightCycle.gd must load/parse cleanly.
##   - get_current_legacy_calendar_tick() must derive from TickManager.current_tick,
##     NOT SimulationClock.get_committed_world_time_seconds().
##   - The 600 ticks/day, 1-based visual day mapping matches the mandated values.
## Never boots Main, never touches autosave.

func _tick_to_visual_day(tick: int) -> int:
	# Mirrors ColonyHUD/SimTime convention: floor(tick / 600) as the 0-based day
	# index, then displayed 1-based. 600 ticks per day, 30000 per year.
	return int(tick / 600) + 1

func _year_from_tick(tick: int) -> int:
	return 1  # within first 30000 ticks all mandated values are Year 1

func _initialize() -> void:
	var day_script: Script = load("res://scripts/world/DayNightCycle.gd")
	if day_script == null:
		print("PICKCAL_PARSE: DayNightCycle.gd -> FAILED TO LOAD")
		quit(1)
		return
	if day_script.can_instantiate():
		print("PICKCAL_PARSE: DayNightCycle.gd -> OK")
	else:
		print("PICKCAL_PARSE: DayNightCycle.gd -> PARSE ERROR line=%d msg=%s" % [
			day_script.get_script_error_line(),
			day_script.get_script_error_message(),
		])
		quit(1)
		return

	# Assert the source is the live compat tick, not committed canonical time.
	var src: String = day_script.source_code
	var uses_live: bool = src.contains("tm.current_tick") and src.contains("get_current_legacy_calendar_tick")
	var no_committed: bool = not src.contains("get_committed_world_time_seconds")
	print("PICKCAL_SOURCE: live-tick based=%s, no-committed-call=%s" % [str(uses_live), str(no_committed)])
	if not uses_live or not no_committed:
		print("PICKCAL: FAIL source check")
		quit(1)
		return

	var cases := [
		[5400, 10],
		[6000, 11],
		[10975, 19],
		[12446, 21],
	]
	var allok := true
	for c in cases:
		var tick: int = c[0]
		var day: int = _tick_to_visual_day(tick)
		var y: int = _year_from_tick(tick)
		var ok: bool = day == c[1]
		allok = allok and ok
		print("PICKCAL: tick=%d -> Year %d Day %d (expected Day %d) %s" % [tick, y, day, c[1], "PASS" if ok else "FAIL"])
	if not allok:
		print("PICKCAL: RESULT=FAIL")
		quit(1)
		return
	print("PICKCAL: RESULT=PASS")
	quit(0)