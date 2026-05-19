extends Node
## ChronicleExport — readable narrative history from WorldMemory events.
##
## Transforms the append-only fact log into a human-readable chronicle
## organized by era, settlement, and life arcs. Deterministic output
## for the same world state.

const TICKS_PER_YEAR: int = 7200  # SimTime.TICKS_PER_SIM_YEAR mirror

## Export mode: full chronicle, settlement-focused, or pawn-focused.
enum Mode { FULL, SETTLEMENT, PAWN }


## Generate a readable chronicle from WorldMemory events.
## [param mode] controls scope; [param settlement_id] filters to one settlement;
## [param pawn_id] filters to one pawn's life arc.
func generate_chronicle(mode: Mode = Mode.FULL, settlement_id: int = -1, pawn_id: int = -1) -> String:
	var lines: PackedStringArray = PackedStringArray()
	lines.append("═══════════════════════════════════════════")
	lines.append("       HEELKAWN — CHRONICLE OF THE WORLD")
	lines.append("═══════════════════════════════════════════")
	lines.append("")

	var tick: int = GameManager.tick_count if GameManager != null else 0
	var years: float = float(tick) / float(TICKS_PER_YEAR)
	lines.append("Simulated: %.1f years (tick %d)" % [years, tick])

	# Civilization stage header
	if CivilizationStage != null:
		var stage: int = CivilizationStage.get_civilization_stage()
		var score: int = CivilizationStage.calculate_civilization_score()
		var name: String = CivilizationStage.get_stage_name(stage)
		var desc: String = CivilizationStage.get_stage_description(stage)
		lines.append("Era: %s — %s" % [name, desc])
		lines.append("Civilization Score: %d" % score)

	lines.append("")

	# Gather events
	var events: Array = _gather_events(mode, settlement_id, pawn_id)
	if events.is_empty():
		lines.append("No events recorded yet. The world waits.")
		return "\n".join(lines)

	# Group events by era (every 500 ticks ≈ 25 days)
	var era_size: int = 500
	var eras: Dictionary = {}
	for evt in events:
		var t: int = int(evt.get("t", 0))
		var era_key: int = (t / era_size) * era_size
		if not eras.has(era_key):
			eras[era_key] = []
		eras[era_key].append(evt)

	var era_keys: Array = eras.keys()
	era_keys.sort()

	for era_start in era_keys:
		var era_events: Array = eras[era_start]
		var era_end: int = era_start + era_size
		var era_years_start: float = float(era_start) / float(TICKS_PER_YEAR)
		var era_years_end: float = float(era_end) / float(TICKS_PER_YEAR)

		lines.append("─── Year %.1f – %.1f ───" % [era_years_start, era_years_end])
		lines.append("")

		for evt in era_events:
			var narrative: String = _event_to_narrative(evt)
			if not narrative.is_empty():
				lines.append("  " + narrative)

		lines.append("")

	# Settlement summary
	if mode != Mode.PAWN:
		lines.append("═══════════════════════════════════════════")
		lines.append("       SETTLEMENT SUMMARY")
		lines.append("═══════════════════════════════════════════")
		lines.append("")
		var settlement_summary: PackedStringArray = _generate_settlement_summary()
		for line in settlement_summary:
			lines.append(line)
		lines.append("")

	# Notable lives
	if mode != Mode.SETTLEMENT:
		lines.append("═══════════════════════════════════════════")
		lines.append("       NOTABLE LIVES")
		lines.append("═══════════════════════════════════════════")
		lines.append("")
		var notable: PackedStringArray = _generate_notable_lives(pawn_id)
		for line in notable:
			lines.append(line)
		lines.append("")

	# Knowledge status
	lines.append("═══════════════════════════════════════════")
	lines.append("       KNOWLEDGE PRESERVED & LOST")
	lines.append("═══════════════════════════════════════════")
	lines.append("")
	var knowledge_summary: PackedStringArray = _generate_knowledge_summary()
	for line in knowledge_summary:
		lines.append(line)
	lines.append("")

	lines.append("── End of Chronicle ──")
	return "\n".join(lines)


## Generate a compact world seed string for sharing worlds.
## Contains: seed, tick, all autoload save dicts, and event log.
func generate_world_seed() -> Dictionary:
	var seed_data: Dictionary = {
		"version": "1.0",
		"export_tick": GameManager.tick_count if GameManager != null else 0,
		"export_timestamp": Time.get_datetime_string_from_system() if Time != null else "",
	}

	# Core state from autoloads
	if WorldMemory != null:
		var events: Variant = WorldMemory.get("_events")
		seed_data["event_count"] = (events as Array).size() if events is Array else 0

	if SettlementMemory != null and SettlementMemory.has_method("get_formal_settlements"):
		var settlements: Array = SettlementMemory.get_formal_settlements()
		seed_data["settlement_count"] = settlements.size()

	if PawnAccess != null and PawnAccess.has_method("find_alive_pawns"):
		var pawns: Array = PawnAccess.find_alive_pawns()
		seed_data["living_pawns"] = pawns.size()

	if CivilizationStage != null:
		seed_data["civilization_stage"] = CivilizationStage.get_civilization_stage()
		seed_data["civilization_score"] = CivilizationStage.calculate_civilization_score()

	# Settlement summaries
	var settlement_summaries: Array = []
	if SettlementMemory != null and SettlementMemory.has_method("get_formal_settlements"):
		for st_any in SettlementMemory.get_formal_settlements():
			if st_any is Dictionary:
				var st: Dictionary = st_any
				settlement_summaries.append({
					"name": st.get("name", "Unnamed"),
					"state": st.get("state", "unknown"),
					"center_region": st.get("center_region", -1),
				})
	seed_data["settlements"] = settlement_summaries

	return seed_data


## Save chronicle to a file in user://
func save_chronicle_to_file(mode: Mode = Mode.FULL, settlement_id: int = -1, pawn_id: int = -1) -> String:
	var chronicle: String = generate_chronicle(mode, settlement_id, pawn_id)
	var timestamp: String = _safe_timestamp()
	var file_name: String = "heelkawn_chronicle_%s.txt" % timestamp
	var file_path: String = "user://%s" % file_name

	var file: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		push_error("[ChronicleExport] Failed to write chronicle to %s" % file_path)
		return ""

	file.store_string(chronicle)
	file.close()
	print("[ChronicleExport] Chronicle saved to %s" % file_path)
	return file_path


## Save world seed to a JSON file in user://
func save_world_seed_to_file() -> String:
	var seed_data: Dictionary = generate_world_seed()
	var json_string: String = JSON.stringify(seed_data, "\t")
	var timestamp: String = _safe_timestamp()
	var file_name: String = "heelkawn_seed_%s.json" % timestamp
	var file_path: String = "user://%s" % file_name

	var file: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		push_error("[ChronicleExport] Failed to write seed to %s" % file_path)
		return ""

	file.store_string(json_string)
	file.close()
	print("[ChronicleExport] World seed saved to %s" % file_path)
	return file_path


# ─── Internal helpers ───


func _gather_events(mode: Mode, settlement_id: int, pawn_id: int) -> Array:
	if WorldMemory == null:
		return []

	var events: Array = []
	# Access private _events via iteration through public methods if available,
	# or fall back to history export parsing.
	if WorldMemory.has_method("get_history_export_string"):
		# Parse the export string back into events
		var export_str: String = WorldMemory.get_history_export_string(false)
		# We need direct access to events — try meta access
		if WorldMemory.has_method("get_events"):
			events = WorldMemory.get_events()
		else:
			# Fallback: try to access via property
			var evt_prop: Variant = WorldMemory.get("_events")
			if evt_prop is Array:
				events = evt_prop as Array

	return events


func _event_to_narrative(evt: Dictionary) -> String:
	var tick: int = int(evt.get("t", 0))
	var typ: String = str(evt.get("type", evt.get("k", "unknown")))
	var years: float = float(tick) / float(TICKS_PER_YEAR)

	# Resolve pawn names
	var pawn_name: String = _resolve_pawn_name(evt)
	var location: String = _resolve_location(evt)

	match typ:
		"pawn_death", "death", "death_event":
			var cause: String = str(evt.get("cause", evt.get("c", "unknown")))
			var age: String = str(evt.get("age", evt.get("a", "?")))
			var prof: String = str(evt.get("profession", evt.get("prof", "")))
			if not prof.is_empty():
				prof = ", " + prof
			return "Year %.1f: %s died at age %s%s (%s) [%s]" % [years, pawn_name, age, prof, cause, location]

		"birth", "pawn_birth", "generational_birth":
			var parent_a: String = str(evt.get("parent_a", evt.get("pa", "")))
			var parent_b: String = str(evt.get("parent_b", evt.get("pb", "")))
			var parents: String = ""
			if not parent_a.is_empty() and not parent_b.is_empty():
				parents = " to %s and %s" % [parent_a, parent_b]
			elif not parent_a.is_empty():
				parents = " to %s" % parent_a
			return "Year %.1f: %s was born%s [%s]" % [years, pawn_name, parents, location]

		"settlement_founded", "settlement_new_foundation", "polity_founded":
			var sname: String = str(evt.get("name", evt.get("settlement_name", pawn_name)))
			return "Year %.1f: %s was founded" % [years, sname]

		"settlement_abandoned", "settlement_collapse":
			var sname: String = str(evt.get("name", evt.get("settlement_name", "a settlement")))
			var reason: String = str(evt.get("reason", evt.get("cause", "unknown causes")))
			return "Year %.1f: %s was abandoned (%s)" % [years, sname, reason]

		"settlement_revived", "settlement_revival", "settlement_revival_with_lineage":
			var sname: String = str(evt.get("name", evt.get("settlement_name", "a settlement")))
			return "Year %.1f: %s rose from ruin" % [years, sname]

		"teaching_event", "skill_taught":
			var teacher: String = str(evt.get("teacher", evt.get("tchr", "")))
			var student: String = str(evt.get("student", evt.get("std", pawn_name)))
			var skill: String = str(evt.get("skill", evt.get("s", "something")))
			if teacher.is_empty():
				return "Year %.1f: %s learned %s [%s]" % [years, student, skill, location]
			return "Year %.1f: %s taught %s to %s [%s]" % [years, teacher, skill, student, location]

		"knowledge_inscribed", "knowledge_read":
			var knowledge_type: String = str(evt.get("knowledge_type", evt.get("kt", "knowledge")))
			var carrier: String = str(evt.get("carrier", evt.get("pid", pawn_name)))
			if typ == "knowledge_inscribed":
				return "Year %.1f: %s inscribed %s in stone [%s]" % [years, carrier, knowledge_type, location]
			return "Year %.1f: %s read inscribed %s [%s]" % [years, carrier, knowledge_type, location]

		"knowledge_lost":
			var knowledge_type: String = str(evt.get("knowledge_type", evt.get("kt", "knowledge")))
			var settlement: String = str(evt.get("settlement", evt.get("stl", "")))
			return "Year %.1f: %s was lost forever%s" % [years, knowledge_type, " in " + settlement if not settlement.is_empty() else ""]

		"building_constructed", "structure_built", "hearth_built", "storage_built", "shrine_built", "marker_built":
			var building: String = str(evt.get("building", evt.get("b", "a structure")))
			var builder: String = str(evt.get("builder", evt.get("pid", pawn_name)))
			return "Year %.1f: %s built %s [%s]" % [years, builder, building, location]

		"building_destroyed":
			var building: String = str(evt.get("building", evt.get("b", "a structure")))
			var cause: String = str(evt.get("cause", evt.get("c", "destruction")))
			return "Year %.1f: %s was destroyed (%s) [%s]" % [years, building, cause, location]

		"fire_started":
			return "Year %.1f: Fire broke out [%s]" % [years, location]

		"fire_extinguished":
			return "Year %.1f: Fire was extinguished [%s]" % [years, location]

		"grudge_formed", "grudge_inherited":
			var target: String = str(evt.get("target", evt.get("tgt", "another")))
			var reason: String = str(evt.get("reason", evt.get("c", "a wrong")))
			if typ == "grudge_inherited":
				return "Year %.1f: %s inherited a grudge against %s (%s)" % [years, pawn_name, target, reason]
			return "Year %.1f: %s formed a grudge against %s (%s)" % [years, pawn_name, target, reason]

		"war_proposed", "war_battle_spawned", "skirmish_started", "battle_resolved":
			var detail: String = str(evt.get("detail", evt.get("d", typ)))
			return "Year %.1f: %s [%s]" % [years, detail, location]

		"authority_change", "governance_change", "succession", "ruler_decision":
			var detail: String = str(evt.get("detail", evt.get("d", typ)))
			var actor: String = str(evt.get("actor", evt.get("pid", pawn_name)))
			return "Year %.1f: %s — %s" % [years, actor, detail]

		"trade_route_started", "trade_route_completed", "trade_route_opened":
			var from: String = str(evt.get("from", evt.get("a", "")))
			var to: String = str(evt.get("to", evt.get("b", "")))
			return "Year %.1f: Trade route opened between %s and %s" % [years, from, to]

		"tool_crafted", "food_cooked", "book_bound", "ink_made", "paper_made", "leather_tanned", "pen_crafted":
			var item: String = str(evt.get("item", evt.get("i", typ)))
			var crafter: String = str(evt.get("crafter", evt.get("pid", pawn_name)))
			return "Year %.1f: %s crafted %s [%s]" % [years, crafter, item, location]

		"migration_started", "migration_completed", "pawn_migrated":
			var dest: String = str(evt.get("destination", evt.get("dest", "unknown lands")))
			return "Year %.1f: %s migrated %s" % [years, pawn_name, dest]

		"legacy_record", "life_path_milestone", "life_path_switch":
			var detail: String = str(evt.get("detail", evt.get("d", "")))
			return "Year %.1f: %s — %s" % [years, pawn_name, detail]

		"bloodline_extinct":
			var bloodline: String = str(evt.get("bloodline", evt.get("bl", "")))
			return "Year %.1f: The %s bloodline ended" % [years, bloodline]

		"cultural_exposure", "cultural_building", "ritual_performed", "sacred_site_established":
			var detail: String = str(evt.get("detail", evt.get("d", typ)))
			return "Year %.1f: %s [%s]" % [years, detail, location]

		"enemy_killed", "animal_killed":
			var species: String = str(evt.get("species", evt.get("sp", "a creature")))
			return "Year %.1f: %s killed %s [%s]" % [years, pawn_name, species, location]

		"injury":
			var injury: String = str(evt.get("injury", evt.get("i", "an injury")))
			var source: String = str(evt.get("source", evt.get("c", "unknown")))
			return "Year %.1f: %s suffered %s (%s) [%s]" % [years, pawn_name, injury, source, location]

		"polity_merged":
			var detail: String = str(evt.get("detail", evt.get("d", "two polities merged")))
			return "Year %.1f: %s" % [years, detail]

		"region_discovery":
			var region: String = str(evt.get("region", evt.get("r_name", "a new region")))
			return "Year %.1f: %s was discovered" % [years, region]

		_:
			# Generic fallback
			var subject: String = str(evt.get("subject", evt.get("pid", evt.get("pawn_id", ""))))
			var detail: String = str(evt.get("detail", evt.get("cause", evt.get("action", typ))))
			if not subject.is_empty():
				return "Year %.1f: %s — %s [%s]" % [years, subject, detail, location]
			return "Year %.1f: %s [%s]" % [years, detail, location]


func _resolve_pawn_name(evt: Dictionary) -> String:
	var name: String = str(evt.get("n", evt.get("name", evt.get("pawn_name", ""))))
	if not name.is_empty():
		return name
	var pid: int = int(evt.get("pid", evt.get("pawn_id", evt.get("id", -1))))
	if pid >= 0:
		return "pawn #%d" % pid
	return "someone"


func _resolve_location(evt: Dictionary) -> String:
	var region: int = int(evt.get("r", -1))
	if region < 0:
		return "unknown"
	# Try to resolve region to settlement name
	if SettlementMemory != null and SettlementMemory.has_method("get_settlement_for_region"):
		var st: Variant = SettlementMemory.call("get_settlement_for_region", region)
		if st is Dictionary:
			return str(st.get("name", "region %d" % region))
	return "region %d" % region


func _generate_settlement_summary() -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	if SettlementMemory == null or not SettlementMemory.has_method("get_formal_settlements"):
		lines.append("  No settlements recorded.")
		return lines

	var settlements: Array = SettlementMemory.get_formal_settlements()
	if settlements.is_empty():
		lines.append("  No formal settlements yet. The world is still wild.")
		return lines

	for st_any in settlements:
		if st_any is not Dictionary:
			continue
		var st: Dictionary = st_any
		var name: String = str(st.get("name", "Unnamed"))
		var state: String = str(st.get("state", "unknown"))
		var pop: int = int(st.get("population", st.get("pop", 0)))
		var stage: String = ""
		if CivilizationStage != null:
			var sid: int = int(st.get("id", st.get("settlement_id", -1)))
			var cs: int = CivilizationStage.get_civilization_stage(sid)
			stage = " [%s]" % CivilizationStage.get_stage_name(cs)
		lines.append("  • %s (%s, pop %d)%s" % [name, state, pop, stage])

	return lines


func _generate_notable_lives(filter_pawn_id: int = -1) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	if WorldMemory == null:
		lines.append("  No records available.")
		return lines

	# Find pawns with legacy events or multiple significant events
	var pawn_events: Dictionary = {}
	var events: Variant = WorldMemory.get("_events")
	if events is Array:
		for evt in events as Array:
			if evt is not Dictionary:
				continue
			var pid: int = int(evt.get("pid", evt.get("pawn_id", -1)))
			if pid < 0:
				continue
			var typ: String = str(evt.get("type", ""))
			if typ in ["pawn_death", "legacy_record", "life_path_milestone", "teaching_event",
					   "knowledge_inscribed", "authority_change", "grudge_formed"]:
				if not pawn_events.has(pid):
					pawn_events[pid] = []
				pawn_events[pid].append(evt)

	# Sort by event count, show top 10
	var sorted_pawns: Array = []
	for pid in pawn_events:
		sorted_pawns.append({"id": pid, "count": pawn_events[pid].size()})
	sorted_pawns.sort_custom(func(a, b): return a.count > b.count)

	var limit: int = mini(10, sorted_pawns.size())
	for i in range(limit):
		var entry: Dictionary = sorted_pawns[i]
		var pid: int = entry.id
		var name: String = "pawn #%d" % pid
		var events_arr: Array = pawn_events[pid]

		# Find name from death record or first event
		for evt in events_arr:
			var n: String = str(evt.get("n", evt.get("name", "")))
			if not n.is_empty():
				name = n
				break

		var prof: String = ""
		var tier: String = ""
		if ProgressionSystem != null and ProgressionSystem.has_method("get_tier_name"):
			tier = " (%s)" % ProgressionSystem.call("get_tier_name", pid)

		lines.append("  • %s%s — %d recorded events" % [name, tier, entry.count])

	if sorted_pawns.is_empty():
		lines.append("  No notable lives yet recorded.")

	return lines


func _generate_knowledge_summary() -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	if KnowledgeSystem == null:
		lines.append("  Knowledge system not available.")
		return lines

	# Get known knowledge types
	if KnowledgeSystem.has_method("get_all_knowledge_types"):
		var types: Array = KnowledgeSystem.get_all_knowledge_types()
		if types.is_empty():
			lines.append("  No knowledge types registered.")
			return lines

		for kt in types:
			if kt is not Dictionary:
				continue
			var ktype: Dictionary = kt
			var name: String = str(ktype.get("name", ktype.get("type", "unknown")))
			var carriers: int = int(ktype.get("carriers", ktype.get("carrier_count", 0)))
			var inscribed: bool = bool(ktype.get("inscribed", ktype.get("on_stone", false)))
			var status: String = "carried by %d" % carriers
			if inscribed:
				status += ", inscribed in stone"
			if carriers == 0 and not inscribed:
				status = "LOST"
			lines.append("  • %s — %s" % [name, status])
	else:
		lines.append("  Knowledge details unavailable.")

	return lines


func _safe_timestamp() -> String:
	if Time == null:
		return "unknown"
	var dt: Dictionary = Time.get_datetime_dict_from_system()
	return "%04d%02d%02d_%02d%02d%02d" % [
		dt.get("year", 2026), dt.get("month", 1), dt.get("day", 1),
		dt.get("hour", 0), dt.get("minute", 0), dt.get("second", 0)
	]
