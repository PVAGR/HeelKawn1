extends Node
## EpicChronicle — long-term historical narrative of civilizations.
##
## Records the rise and fall of settlements, dynasties, and eras into
## a structured chronicle with generational memory preservation.
## Older entries lose significance over time and are pruned when full.
## Chapters group entries by era with summary. Per-civilization chronicle
## with global overview and turning point detection.
##
## Integrations: WorldMemory (event sourcing), TechnologyEras (era context),
## KnowledgeSystem (knowledge levels per era), EventBus (major events),
## DynastyFamilySystem (dynasty tracking).

const CHRONICLE_INTERVAL: int = 10000
const MIN_SIGNIFICANCE: float = 20.0
const MAX_ENTRIES: int = 500
const SIGNIFICANCE_DECAY_PER_10000_TICKS: float = 5.0
const SIGNIFICANCE_DECAY_INTERVAL: int = 10000
const TURNING_POINT_WINDOW: int = 5000
const DYNASTY_CHECK_INTERVAL: int = 12000
const CHAPTER_MIN_ENTRIES: int = 3
const SAVE_VERSION: int = 1

enum EntryType {
	ERA_ADVANCEMENT,
	SETTLEMENT_FOUNDED,
	SETTLEMENT_DESTROYED,
	WAR_STARTED,
	WAR_ENDED,
	CATACLYSM,
	DISCOVERY,
	HERO_DEATH,
	TURNING_POINT,
	DYNASTY_FOUNDED,
	DYNASTY_ENDED,
}

const ENTRY_TYPE_NAMES: Dictionary = {
	EntryType.ERA_ADVANCEMENT: "era_advancement",
	EntryType.SETTLEMENT_FOUNDED: "settlement_founded",
	EntryType.SETTLEMENT_DESTROYED: "settlement_destroyed",
	EntryType.WAR_STARTED: "war_started",
	EntryType.WAR_ENDED: "war_ended",
	EntryType.CATACLYSM: "cataclysm",
	EntryType.DISCOVERY: "discovery",
	EntryType.HERO_DEATH: "hero_death",
	EntryType.TURNING_POINT: "turning_point",
	EntryType.DYNASTY_FOUNDED: "dynasty_founded",
	EntryType.DYNASTY_ENDED: "dynasty_ended",
}

class ChronicleEntry:
	var tick: int
	var entry_type: int
	var description: String
	var involved_pawns: Array[int]
	var involved_settlements: Array[int]
	var significance: float
	var era_at_time: int
	var forced: bool

	func _init(p_tick: int, p_type: int, p_desc: String, p_sig: float, p_era: int,
			p_pawns: Array[int] = [], p_settlements: Array[int] = [], p_forced: bool = false):
		tick = p_tick
		entry_type = p_type
		description = p_desc
		significance = clampf(p_sig, 0.0, 100.0)
		era_at_time = p_era
		involved_pawns = p_pawns.duplicate()
		involved_settlements = p_settlements.duplicate()
		forced = p_forced

class ChronicleChapter:
	var era: int
	var era_name: String
	var start_tick: int
	var end_tick: int
	var entry_indices: Array[int]
	var summary: String

	func _init(p_era: int, p_era_name: String, p_start: int):
		era = p_era
		era_name = p_era_name
		start_tick = p_start
		end_tick = p_start
		entry_indices = []
		summary = ""

var _chronicle: Array[ChronicleEntry] = []
var _chapters: Array[ChronicleChapter] = []
var _last_chronicle_tick: int = -999999
var _last_dynasty_check_tick: int = -999999
var _last_turning_point_tick: int = -999999
var _last_decay_tick: int = -999999
var _last_era_change_tick: int = 0
var _last_era: int = -1
var _entry_id_counter: int = 0
var _turning_points: Array[Dictionary] = []
var _dynasty_tracker: Dictionary = {}  # dynasty_name -> { first_seen_tick, last_prestige, peak_prestige, fallen }
var _knowledge_snapshots: Array[Dictionary] = []
var _knowledge_snapshot_interval: int = 20000
var _last_knowledge_snapshot_tick: int = -999999

signal chronicle_entry_added(entry_index: int, entry_type: int, description: String, significance: float, tick: int)
signal chapter_closed(era: int, era_name: String, entry_count: int, summary: String)
signal chronicle_exported(text: String)
signal knowledge_level_recorded(era: int, active_types: int, total_carriers: int, tick: int)
signal dynasty_status_changed(dynasty_name: String, status: String, tick: int)
signal turning_point_detected(description: String, tick: int, significance: float)

func _ready() -> void:
	if GameManager != null:
		GameManager.game_tick.connect(_on_game_tick)
	var eb := get_node_or_null("/root/EventBus")
	if eb != null:
		eb.subscribe("settlement_founded", self, "_on_event_settlement_founded")
		eb.subscribe("settlement_destroyed", self, "_on_event_settlement_destroyed")
		eb.subscribe("war_declared", self, "_on_event_war_declared")
		eb.subscribe("war_ended", self, "_on_event_war_ended")
		eb.subscribe("cataclysm_started", self, "_on_event_cataclysm")
		eb.subscribe("discovery_major", self, "_on_event_discovery")
		eb.subscribe("pawn_died_significant", self, "_on_event_hero_death")
		eb.subscribe("dynasty_formed", self, "_on_event_dynasty_founded")
		eb.subscribe("dynasty_ended", self, "_on_event_dynasty_ended")

func _on_game_tick(tick: int) -> void:
	if tick - _last_chronicle_tick >= CHRONICLE_INTERVAL:
		_last_chronicle_tick = tick
		_scan_for_chronicle_events(tick)
		_detect_turning_points(tick)
	if tick - _last_decay_tick >= SIGNIFICANCE_DECAY_INTERVAL:
		_last_decay_tick = tick
		_apply_significance_decay(tick)
		_prune_old_entries(tick)
	if tick - _last_dynasty_check_tick >= DYNASTY_CHECK_INTERVAL:
		_last_dynasty_check_tick = tick
		_check_dynasty_status(tick)
	if tick - _last_knowledge_snapshot_tick >= _knowledge_snapshot_interval:
		_last_knowledge_snapshot_tick = tick
		record_knowledge_snapshot(tick)
	_rebuild_chapters()
	_emit_chapter_closures()

## ─── EventBus Handlers ────────────────────────────────────────

func _on_event_settlement_founded(payload: Dictionary) -> void:
	var tick: int = int(payload.get("tick", GameManager.tick_count))
	var name: String = str(payload.get("name", "Unnamed Settlement"))
	var sid: int = int(payload.get("settlement_id", -1))
	var founder: String = str(payload.get("founder", "Unknown"))
	record_entry("Settlement Founded: %s" % name,
		"%s founded a new settlement: %s" % [founder, name],
		EntryType.SETTLEMENT_FOUNDED, 30.0, tick, [], [sid] if sid >= 0 else [])

func _on_event_settlement_destroyed(payload: Dictionary) -> void:
	var tick: int = int(payload.get("tick", GameManager.tick_count))
	var name: String = str(payload.get("name", "Unnamed Settlement"))
	var sid: int = int(payload.get("settlement_id", -1))
	var cause: String = str(payload.get("cause", "unknown"))
	var survivor_count: int = int(payload.get("survivors", 0))
	var desc: String = "%s was destroyed by %s" % [name, cause]
	if survivor_count > 0:
		desc += ". Only %d survivors remained." % survivor_count
	record_entry("Settlement Destroyed: %s" % name, desc,
		EntryType.SETTLEMENT_DESTROYED, 75.0, tick, [], [sid] if sid >= 0 else [])

func _on_event_war_declared(payload: Dictionary) -> void:
	var tick: int = int(payload.get("tick", GameManager.tick_count))
	var aggressor: String = str(payload.get("aggressor", "Unknown"))
	var defender: String = str(payload.get("defender", "Unknown"))
	var cause: String = str(payload.get("cause", "dispute"))
	var ag_id: int = int(payload.get("aggressor_id", -1))
	var def_id: int = int(payload.get("defender_id", -1))
	record_entry("War Declared: %s vs %s" % [aggressor, defender],
		"%s declared war on %s over %s" % [aggressor, defender, cause],
		EntryType.WAR_STARTED, 50.0, tick, [], [ag_id, def_id])

func _on_event_war_ended(payload: Dictionary) -> void:
	var tick: int = int(payload.get("tick", GameManager.tick_count))
	var victor: String = str(payload.get("victor", "Unknown"))
	var loser: String = str(payload.get("loser", "Unknown"))
	var outcome: String = str(payload.get("outcome", "stalemate"))
	var vic_id: int = int(payload.get("victor_id", -1))
	var los_id: int = int(payload.get("loser_id", -1))
	record_entry("War Ended: %s defeats %s" % [victor, loser],
		"The war between %s and %s ended in %s" % [victor, loser, outcome],
		EntryType.WAR_ENDED, 50.0, tick, [], [vic_id, los_id])

func _on_event_cataclysm(payload: Dictionary) -> void:
	var tick: int = int(payload.get("tick", GameManager.tick_count))
	var name: String = str(payload.get("name", "Unknown Cataclysm"))
	var severity: int = int(payload.get("severity", 0))
	var affected: Array = payload.get("affected_regions", [])
	var sig: float = clampf(30.0 + float(severity) * 5.0, 30.0, 100.0)
	record_entry("Cataclysm: %s" % name,
		"A %s (severity %d) struck the land, devastating %d regions" % [name, severity, affected.size()],
		EntryType.CATACLYSM, sig, tick, [], affected)

func _on_event_discovery(payload: Dictionary) -> void:
	var tick: int = int(payload.get("tick", GameManager.tick_count))
	var pawn_name: String = str(payload.get("pawn_name", "Someone"))
	var discovery: String = str(payload.get("discovery", "something new"))
	var pawn_id: int = int(payload.get("pawn_id", -1))
	var sids: Array = payload.get("settlement_ids", [])
	record_entry("Discovery: %s" % discovery,
		"%s discovered %s, advancing civilization's knowledge" % [pawn_name, discovery],
		EntryType.DISCOVERY, 35.0, tick, [pawn_id] if pawn_id >= 0 else [], sids)

func _on_event_hero_death(payload: Dictionary) -> void:
	var tick: int = int(payload.get("tick", GameManager.tick_count))
	var pawn_name: String = str(payload.get("pawn_name", "Unknown Hero"))
	var cause: String = str(payload.get("cause", "unknown causes"))
	var pawn_id: int = int(payload.get("pawn_id", -1))
	var sid: int = int(payload.get("settlement_id", -1))
	var legacy: String = str(payload.get("legacy", ""))
	var desc: String = "%s, a great hero, perished from %s" % [pawn_name, cause]
	if not legacy.is_empty():
		desc += ". Their legacy: %s" % legacy
	record_entry("Hero Death: %s" % pawn_name, desc,
		EntryType.HERO_DEATH, 70.0, tick, [pawn_id] if pawn_id >= 0 else [],
		[sid] if sid >= 0 else [])

func _on_event_dynasty_founded(payload: Dictionary) -> void:
	var tick: int = int(payload.get("tick", GameManager.tick_count))
	var dynasty_name: String = str(payload.get("dynasty_name", "Unnamed Dynasty"))
	var founder: String = str(payload.get("founder_name", "Unknown"))
	var sid: int = int(payload.get("settlement_id", -1))
	var f_id: int = int(payload.get("founder_id", -1))
	record_entry("Dynasty Founded: %s" % dynasty_name,
		"The %s dynasty was established by %s" % [dynasty_name, founder],
		EntryType.DYNASTY_FOUNDED, 40.0, tick, [f_id] if f_id >= 0 else [],
		[sid] if sid >= 0 else [])

func _on_event_dynasty_ended(payload: Dictionary) -> void:
	var tick: int = int(payload.get("tick", GameManager.tick_count))
	var dynasty_name: String = str(payload.get("dynasty_name", "Unnamed Dynasty"))
	var cause: String = str(payload.get("cause", "unknown"))
	var sid: int = int(payload.get("settlement_id", -1))
	record_entry("Dynasty Ended: %s" % dynasty_name,
		"The %s dynasty came to an end: %s" % [dynasty_name, cause],
		EntryType.DYNASTY_ENDED, 65.0, tick, [], [sid] if sid >= 0 else [])

## ─── Core Recording ────────────────────────────────────────────

func record_entry(headline: String, description: String, entry_type: int, significance: float,
		tick: int, involved_pawns: Array[int] = [], involved_settlements: Array[int] = [],
		force: bool = false) -> int:
	if not force and significance < MIN_SIGNIFICANCE:
		return -1
	var te := get_node_or_null("/root/TechnologyEras")
	var era: int = te.get_global_era() if te != null and te.has_method("get_global_era") else 0
	var entry := ChronicleEntry.new(tick, entry_type, description, significance, era,
		involved_pawns, involved_settlements, force)
	_chronicle.append(entry)
	var idx: int = _chronicle.size() - 1
	if era != _last_era and _last_era >= 0:
		_last_era_change_tick = tick
	_handle_era_advancement(era, tick)
	_last_era = era
	chronicle_entry_added.emit(idx, entry_type, description, significance, tick)
	if WorldMemory != null:
		WorldMemory.record_event({
			"type": "chronicle_entry",
			"entry_type": ENTRY_TYPE_NAMES.get(entry_type, "unknown"),
			"headline": headline,
			"description": description,
			"era": era,
			"significance": significance,
			"tick": tick,
		})
	return idx

func _handle_era_advancement(current_era: int, tick: int) -> void:
	if _last_era < 0 or current_era <= _last_era:
		return
	var te := get_node_or_null("/root/TechnologyEras")
	var era_name: String = "Unknown Era"
	if te != null and te.has_method("get_era_name"):
		era_name = te.get_era_name(current_era)
	var desc: String = "Civilization advanced to the %s" % era_name
	record_entry("Era Advancement: %s" % era_name, desc,
		EntryType.ERA_ADVANCEMENT, 80.0, tick, [], [], false)
	_chapters.append(ChronicleChapter.new(current_era, era_name, tick))

## ─── WorldMemory Scanning ─────────────────────────────────────

func _scan_for_chronicle_events(tick: int) -> void:
	var wm := get_node_or_null("/root/WorldMemory")
	if wm == null:
		return
	var recent_events: Array = []
	if wm.has_method("get_recent_events"):
		recent_events = wm.get_recent_events(5000)
	for event in recent_events:
		if not (event is Dictionary):
			continue
		var ev: Dictionary = event as Dictionary
		var ev_type: String = str(ev.get("type", ""))
		var ev_tick: int = int(ev.get("tick", 0))
		if _entry_exists_at_tick(ev_tick):
			continue
		var sig: float = _compute_significance(ev_type, ev)
		if sig < MIN_SIGNIFICANCE:
			continue
		match ev_type:
			"settlement_founded":
				record_entry("Settlement Founded",
					"A new settlement was established at %s" % str(ev.get("center", "unknown")),
					EntryType.SETTLEMENT_FOUNDED, sig, ev_tick)
			"cataclysm_started":
				record_entry("Cataclysm: %s" % str(ev.get("name", "Unknown")),
					"A devastating cataclysm of severity %d has begun" % int(ev.get("severity", 0)),
					EntryType.CATACLYSM, sig, ev_tick)
			"war_declared":
				record_entry("War Declared",
					"%s declared war on %s" % [str(ev.get("aggressor", "?")), str(ev.get("defender", "?"))],
					EntryType.WAR_STARTED, sig, ev_tick)
			"global_era_advanced":
				var new_era: int = int(ev.get("new_era", 0))
				var te := get_node_or_null("/root/TechnologyEras")
				var era_name: String = te.get_era_name(new_era) if te != null and te.has_method("get_era_name") else "Era %d" % new_era
				record_entry("Era Advancement: %s" % era_name,
					"Civilization has entered the %s" % era_name,
					EntryType.ERA_ADVANCEMENT, sig, ev_tick)
			"battle_major", "battle":
				var attacker: String = str(ev.get("attacker", "Unknown"))
				var defender: String = str(ev.get("defender", "Unknown"))
				var casualties: int = int(ev.get("casualties", 0))
				if casualties >= 5:
					record_entry("Major Battle: %s vs %s" % [attacker, defender],
						"A major battle between %s and %s resulted in %d casualties" % [attacker, defender, casualties],
						EntryType.WAR_STARTED, sig, ev_tick)
			"knowledge_truly_lost":
				var kt: int = int(ev.get("knowledge_type", -1))
				var ks := get_node_or_null("/root/KnowledgeSystem")
				var kname: String = ks._get_knowledge_type_name(kt) if ks != null and ks.has_method("_get_knowledge_type_name") else "knowledge type %d" % kt
				record_entry("Knowledge Lost: %s" % kname,
					"The knowledge of %s was lost when its last carrier died" % kname,
					EntryType.DISCOVERY, sig, ev_tick)
			"knowledge_rediscovered":
				var kt: int = int(ev.get("knowledge_type", -1))
				var ks := get_node_or_null("/root/KnowledgeSystem")
				var kname: String = ks._get_knowledge_type_name(kt) if ks != null and ks.has_method("_get_knowledge_type_name") else "knowledge type %d" % kt
				record_entry("Knowledge Rediscovered: %s" % kname,
					"The lost knowledge of %s was rediscovered by a new generation" % kname,
					EntryType.DISCOVERY, sig, ev_tick)
			"settlement_collapsed", "settlement_abandoned":
				record_entry("Settlement Lost",
					"A settlement at %s was abandoned or collapsed" % str(ev.get("center", "unknown")),
					EntryType.SETTLEMENT_DESTROYED, sig, ev_tick)
			"famine_started", "famine_warning":
				var sev: int = int(ev.get("severity", 0))
				if sev >= 3:
					record_entry("Famine Strikes",
						"A severe famine (severity %d) threatens the population" % sev,
						EntryType.CATACLYSM, sig, ev_tick)

func _compute_significance(ev_type: String, ev: Dictionary) -> float:
	var base_map: Dictionary = {
		"settlement_founded": 30.0,
		"cataclysm_started": 70.0,
		"war_declared": 40.0,
		"global_era_advanced": 80.0,
		"battle_major": 35.0,
		"battle": 20.0,
		"knowledge_truly_lost": 60.0,
		"knowledge_rediscovered": 40.0,
		"settlement_collapsed": 65.0,
		"settlement_abandoned": 55.0,
		"famine_started": 45.0,
		"famine_warning": 30.0,
	}
	var base: float = base_map.get(ev_type, 10.0)
	var casualties: int = int(ev.get("casualties", 0))
	base += float(casualties) * 1.5
	var severity: int = int(ev.get("severity", 0))
	base += float(severity) * 3.0
	return clampf(base, 0.0, 100.0)

## ─── Generational Memory ──────────────────────────────────────

func _apply_significance_decay(tick: int) -> void:
	for entry in _chronicle:
		var age_ticks: int = tick - entry.tick
		var decay_intervals: int = age_ticks / SIGNIFICANCE_DECAY_INTERVAL
		if decay_intervals > 0:
			var decay: float = float(decay_intervals) * SIGNIFICANCE_DECAY_PER_10000_TICKS
			if not entry.forced:
				entry.significance = maxf(entry.significance - decay, 0.0)

func _prune_old_entries(tick: int) -> void:
	if _chronicle.size() <= MAX_ENTRIES:
		return
	_chronicle.sort_custom(func(a: ChronicleEntry, b: ChronicleEntry) -> bool:
		if absf(a.significance - b.significance) > 0.001:
			return a.significance > b.significance
		return a.tick > b.tick)
	var kept: int = MAX_ENTRIES * 3 / 4
	_chronicle = _chronicle.slice(0, kept)
	_chronicle.sort_custom(func(a: ChronicleEntry, b: ChronicleEntry) -> bool:
		return a.tick < b.tick)

## ─── Chapter Management ───────────────────────────────────────

func _rebuild_chapters() -> void:
	_chapters.clear()
	if _chronicle.is_empty():
		return
	var era_groups: Dictionary = {}
	for entry in _chronicle:
		var e_era: int = entry.era_at_time
		if not era_groups.has(e_era):
			era_groups[e_era] = []
		era_groups[e_era].append(entry)
	var era_order: Array[int] = []
	for k in era_groups:
		era_order.append(k)
	era_order.sort()
	var te := get_node_or_null("/root/TechnologyEras")
	for era in era_order:
		var entries: Array = era_groups[era]
		if entries.is_empty():
			continue
		var era_name: String = "Unknown Era"
		if te != null and te.has_method("get_era_name"):
			era_name = te.get_era_name(era)
		var first_tick: int = entries[0].tick
		var last_tick: int = entries[-1].tick
		var ch := ChronicleChapter.new(era, era_name, first_tick)
		ch.end_tick = last_tick
		var sig_count: int = 0
		var sig_total: float = 0.0
		var type_counts: Dictionary = {}
		for i in range(_chronicle.size()):
			if _chronicle[i].era_at_time == era:
				ch.entry_indices.append(i)
				sig_total += _chronicle[i].significance
				sig_count += 1
				var tn: String = ENTRY_TYPE_NAMES.get(_chronicle[i].entry_type, "unknown")
				type_counts[tn] = type_counts.get(tn, 0) + 1
		if sig_count > 0:
			var avg_sig: float = sig_total / float(sig_count)
			var dominant_type: String = ""
			var dominant_count: int = 0
			for t in type_counts:
				if type_counts[t] > dominant_count:
					dominant_count = type_counts[t]
					dominant_type = t
			var summary_parts: PackedStringArray = []
			summary_parts.append("The %s spanned %d entries" % [era_name, sig_count])
			if not dominant_type.is_empty():
				summary_parts.append("dominated by %s events" % dominant_type)
			summary_parts.append("with average significance %.0f" % avg_sig)
			ch.summary = ", ".join(summary_parts) + "."
		_chapters.append(ch)

func get_chapter_summary(chapter_index: int) -> Dictionary:
	if chapter_index < 0 or chapter_index >= _chapters.size():
		return {}
	var ch: ChronicleChapter = _chapters[chapter_index]
	return {
		"era": ch.era,
		"era_name": ch.era_name,
		"start_tick": ch.start_tick,
		"end_tick": ch.end_tick,
		"entry_count": ch.entry_indices.size(),
		"summary": ch.summary,
	}

func get_chapters() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for ch in _chapters:
		out.append(get_chapter_summary(_chapters.find(ch)))
	return out

func _emit_chapter_closures() -> void:
	var closed_set: Dictionary = {}
	for ch in _chapters:
		var key: int = ch.era
		if not closed_set.has(key) and ch.entry_indices.size() >= CHAPTER_MIN_ENTRIES:
			var last_entry_tick: int = 0
			for idx in ch.entry_indices:
				if idx >= 0 and idx < _chronicle.size():
					if _chronicle[idx].tick > last_entry_tick:
						last_entry_tick = _chronicle[idx].tick
			var closed_era_ticks_ago: int = GameManager.tick_count - last_entry_tick
			if closed_era_ticks_ago >= CHRONICLE_INTERVAL * 2:
				closed_set[key] = true
				chapter_closed.emit(ch.era, ch.era_name, ch.entry_indices.size(), ch.summary)

## ─── Era Context Annotation ──────────────────────────────────

func get_era_context(tick: int) -> Dictionary:
	var te := get_node_or_null("/root/TechnologyEras")
	if te == null or not te.has_method("get_global_era"):
		return {"era": 0, "era_name": "Unknown"}
	var current_era: int = te.get_global_era()
	var era_name: String = "Unknown"
	if te.has_method("get_era_name"):
		era_name = te.get_era_name(current_era)
	var era_duration: int = 0
	if _last_era_change_tick > 0:
		era_duration = tick - _last_era_change_tick
	return {
		"era": current_era,
		"era_name": era_name,
		"era_duration_ticks": era_duration,
		"entries_in_era": count_entries_in_era(current_era),
	}

func count_entries_in_era(era: int) -> int:
	var count: int = 0
	for entry in _chronicle:
		if entry.era_at_time == era:
			count += 1
	return count

## ─── Global Overview ──────────────────────────────────────────

func get_global_overview() -> Dictionary:
	var stats: Dictionary = get_stats()
	var te := get_node_or_null("/root/TechnologyEras")
	var current_era: int = te.get_global_era() if te != null and te.has_method("get_global_era") else 0
	var era_name: String = "Unknown"
	if te != null and te.has_method("get_era_name"):
		era_name = te.get_era_name(current_era)
	var overview: Dictionary = {
		"current_era": current_era,
		"current_era_name": era_name,
		"total_entries": stats.get("total_entries", 0),
		"total_chapters": stats.get("total_chapters", 0),
		"turning_points": _turning_points.size(),
		"active_dynasties": 0,
		"fallen_dynasties": 0,
	}
	for dname in _dynasty_tracker:
		if _dynasty_tracker[dname].get("fallen", false):
			overview["fallen_dynasties"] = int(overview["fallen_dynasties"]) + 1
		else:
			overview["active_dynasties"] = int(overview["active_dynasties"]) + 1
	return overview

## ─── Turning Point Detection ──────────────────────────────────

func _detect_turning_points(tick: int) -> void:
	if _last_era < 0:
		return
	if _chronicle.size() < 2:
		return
	var recent_era_shift: bool = (tick - _last_era_change_tick) <= TURNING_POINT_WINDOW
	if not recent_era_shift:
		return
	if tick - _last_turning_point_tick < TURNING_POINT_WINDOW:
		return
	var major_events: int = 0
	for entry in _chronicle:
		var age: int = tick - entry.tick
		if age <= TURNING_POINT_WINDOW and entry.significance >= 60.0:
			major_events += 1
	if major_events >= 2:
		_last_turning_point_tick = tick
		var tp_desc: String = "A convergence of era advancement and major events reshaped civilization's trajectory"
		var idx: int = record_entry("Turning Point Detected", tp_desc,
			EntryType.TURNING_POINT, 90.0, tick, [], [])
		_turning_points.append({
			"tick": tick,
			"description": tp_desc,
			"entry_index": idx,
			"era_at_time": _last_era,
			"major_event_count": major_events,
		})
		if _turning_points.size() > 10:
			_turning_points.pop_front()
		turning_point_detected.emit(tp_desc, tick, 90.0)

## ─── Dynasty Tracking ─────────────────────────────────────────

func _check_dynasty_status(tick: int) -> void:
	var dfs := get_node_or_null("/root/DynastyFamilySystem")
	if dfs == null:
		return
	if dfs.has_method("get_active_dynasties"):
		var dynasties: Array = dfs.get_active_dynasties()
		for dyn in dynasties:
			if not (dyn is Dictionary):
				continue
			var d: Dictionary = dyn as Dictionary
			var dyn_id: int = int(d.get("id", -1))
			var name: String = str(d.get("name", "Unknown"))
			var sid: int = int(d.get("settlement_id", -1))
			var prestige: float = float(d.get("prestige", 0.0))
			var formed_tick: int = int(d.get("formed_tick", 0))
			if not _dynasty_tracker.has(name):
			_dynasty_tracker[name] = {
				"first_seen_tick": tick,
				"last_prestige": 0.0,
				"peak_prestige": 0.0,
				"fallen": false,
				"settlement_id": sid,
				"dynasty_id": dyn_id,
			}
		var dt: Dictionary = _dynasty_tracker[name]
		dt["last_prestige"] = prestige
		if prestige > dt.get("peak_prestige", 0.0):
			dt["peak_prestige"] = prestige
		if prestige >= 70.0:
			var found: bool = false
			for entry in _chronicle:
				if entry.entry_type == EntryType.DYNASTY_FOUNDED and name in entry.description:
					found = true
					break
			if not found:
				record_entry("Dynasty Rises: %s" % name,
					"The %s dynasty gained prominence with prestige %.0f" % [name, prestige],
					EntryType.DYNASTY_FOUNDED, 40.0, tick, [dyn_id] if dyn_id >= 0 else [],
					[sid] if sid >= 0 else [])
				dynasty_status_changed.emit(name, "founded", tick)
		if prestige <= 5.0 and tick - formed_tick > DYNASTY_CHECK_INTERVAL and not dt.get("fallen", false):
			var record_entry_exists: bool = false
			for entry in _chronicle:
				if entry.entry_type == EntryType.DYNASTY_ENDED and name in entry.description:
					record_entry_exists = true
					break
			if not record_entry_exists and formed_tick > 0:
				record_entry("Dynasty Falls: %s" % name,
					"The %s dynasty faded into obscurity as its influence waned" % name,
					EntryType.DYNASTY_ENDED, 65.0, tick, [dyn_id] if dyn_id >= 0 else [],
					[sid] if sid >= 0 else [])
				dt["fallen"] = true
				dynasty_status_changed.emit(name, "ended", tick)

## ─── KnowledgeSystem Integration ─────────────────────────────

func record_knowledge_snapshot(tick: int) -> void:
	var ks := get_node_or_null("/root/KnowledgeSystem")
	if ks == null:
		return
	if not ks.has_method("get_knowledge_status"):
		return
	var status: Dictionary = ks.get_knowledge_status()
	var total_carriers: int = 0
	var total_types: int = 0
	var carrier_count: int = 0
	if ks.has_method("get_total_carrier_count"):
		carrier_count = ks.get_total_carrier_count()
	for k in status:
		var info: Dictionary = status[k]
		var c: int = int(info.get("carriers", 0))
		total_carriers += c
		if c > 0:
			total_types += 1
	var te := get_node_or_null("/root/TechnologyEras")
	var era: int = te.get_global_era() if te != null and te.has_method("get_global_era") else 0
	var ks_entry := {
		"tick": tick,
		"era": era,
		"total_carriers": total_carriers,
		"active_knowledge_types": total_types,
		"total_types": status.size(),
		"carrier_count": carrier_count,
	}
	_knowledge_snapshots.append({
		"tick": tick,
		"era": era,
		"era_name": te.get_era_name(era) if te != null and te.has_method("get_era_name") else "Unknown",
		"total_carriers": total_carriers,
		"active_types": total_types,
	})
	if _knowledge_snapshots.size() > 50:
		_knowledge_snapshots.pop_front()
	if WorldMemory != null:
		WorldMemory.record_event({
			"type": "chronicle_knowledge_snapshot",
			"tick": tick,
			"era": era,
			"total_carriers": total_carriers,
			"active_knowledge_types": total_types,
		})
	knowledge_level_recorded.emit(era, total_types, total_carriers, tick)

func get_knowledge_snapshots() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for s in _knowledge_snapshots:
		out.append(s.duplicate())
	return out

func get_knowledge_trend(era: int) -> Dictionary:
	var relevant: Array[Dictionary] = []
	for s in _knowledge_snapshots:
		if s.get("era", -1) == era:
			relevant.append(s)
	if relevant.is_empty():
		return {"era": era, "snapshots": 0, "trend": "stable"}
	var first: int = relevant[0].get("active_types", 0)
	var last: int = relevant[-1].get("active_types", 0)
	var trend: String = "stable"
	if last > first + 2:
		trend = "growing"
	elif last < first - 2:
		trend = "declining"
	return {
		"era": era,
		"snapshots": relevant.size(),
		"first_active_types": first,
		"last_active_types": last,
		"trend": trend,
	}

func get_turning_points() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for tp in _turning_points:
		out.append(tp.duplicate())
	return out

func get_dynasty_history() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for dname in _dynasty_tracker:
		var dt: Dictionary = _dynasty_tracker[dname]
		out.append({
			"name": dname,
			"first_seen_tick": dt.get("first_seen_tick", 0),
			"last_prestige": dt.get("last_prestige", 0.0),
			"peak_prestige": dt.get("peak_prestige", 0.0),
			"fallen": dt.get("fallen", false),
			"settlement_id": dt.get("settlement_id", -1),
		})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.get("peak_prestige", 0.0) > b.get("peak_prestige", 0.0))
	return out

## ─── Chronicle Export ─────────────────────────────────────────

func export_chronicle() -> String:
	var lines: PackedStringArray = []
	lines.append("╔══════════════════════════════════════════════════════════╗")
	lines.append("║          EPIC CHRONICLE — CIVILIZATION HISTORY          ║")
	lines.append("╚══════════════════════════════════════════════════════════╝")
	lines.append("")
	lines.append("Generated: %s" % Time.get_datetime_string_from_system())
	lines.append("Simulation Tick: %d" % GameManager.tick_count)
	lines.append("Total Entries: %d" % _chronicle.size())
	lines.append("Total Chapters: %d" % _chapters.size())
	lines.append("")
	if _chapters.is_empty():
		if _chronicle.is_empty():
			lines.append("No chronicle entries recorded yet. The world is young.")
		else:
			lines.append("Uncatalogued Events:")
			for entry in _chronicle:
				lines.append(_format_export_entry(entry))
	else:
		for ch in _chapters:
			lines.append("")
			lines.append("━━━ CHAPTER: %s ━━━" % ch.era_name)
			lines.append("Tick Range: %d – %d" % [ch.start_tick, ch.end_tick])
			if not ch.summary.is_empty():
				lines.append("Summary: %s" % ch.summary)
			lines.append("")
			var ch_entries: int = 0
			for idx in ch.entry_indices:
				if idx >= 0 and idx < _chronicle.size():
					lines.append("  " + _format_export_entry(_chronicle[idx]))
					ch_entries += 1
			if ch_entries == 0:
				lines.append("  (No detailed entries in this chapter)")
	if _chronicle.is_empty():
		lines.append("  No events recorded.")
	if _turning_points.size() > 0:
		lines.append("")
		lines.append("━━━ TURNING POINTS ━━━")
		lines.append("")
		var tp_eras := get_node_or_null("/root/TechnologyEras")
		for tp in _turning_points:
			var tp_desc: String = str(tp.get("description", ""))
			var tp_tick: int = int(tp.get("tick", 0))
			var tp_era: int = int(tp.get("era_at_time", -1))
			var tp_era_name: String = tp_eras.get_era_name(tp_era) if tp_eras != null and tp_eras.has_method("get_era_name") else "Era %d" % tp_era
			lines.append("  [Tick %d][%s] %s" % [tp_tick, tp_era_name, tp_desc])
	var text: String = "\n".join(lines)
	chronicle_exported.emit(text)
	return text

func export_civilization_chronicle(settlement_id: int) -> String:
	var lines: PackedStringArray = []
	var sm := get_node_or_null("/root/SettlementMemory")
	var sname: String = "Settlement %d" % settlement_id
	if sm != null and sm.has_method("get_settlement_name"):
		var raw: String = sm.get_settlement_name(settlement_id)
		if not raw.is_empty():
			sname = raw
	lines.append("╔══════════════════════════════════════════════════════════╗")
	lines.append("║     CIVILIZATION CHRONICLE — %s" % sname)
	lines.append("╚══════════════════════════════════════════════════════════╝")
	lines.append("")
	var civ_entries: Array[ChronicleEntry] = []
	for entry in _chronicle:
		if settlement_id in entry.involved_settlements:
			civ_entries.append(entry)
	if civ_entries.is_empty():
		lines.append("No chronicle entries for this settlement.")
	else:
		var te := get_node_or_null("/root/TechnologyEras")
		var current_era: int = -1
		for entry in civ_entries:
			if entry.era_at_time != current_era:
				current_era = entry.era_at_time
				var era_name: String = "Unknown Era"
				if te != null and te.has_method("get_era_name"):
					era_name = te.get_era_name(current_era)
				lines.append("[%s]" % era_name)
			lines.append("  %s" % _format_export_entry(entry))
	return "\n".join(lines)

func _format_export_entry(entry: ChronicleEntry) -> String:
	var tname: String = ENTRY_TYPE_NAMES.get(entry.entry_type, "unknown")
	var sig_label: String = ""
	if entry.significance >= 80.0:
		sig_label = " ★"
	elif entry.significance >= 50.0:
		sig_label = " ◆"
	return "[Tick %d][%s%s] %s" % [entry.tick, tname, sig_label, entry.description]

func get_chronicle_as_text(limit: int = 50) -> String:
	var sorted: Array[ChronicleEntry] = _chronicle.duplicate()
	sorted.sort_custom(func(a: ChronicleEntry, b: ChronicleEntry) -> bool:
		return a.tick > b.tick)
	var lines: PackedStringArray = []
	var count: int = 0
	for entry in sorted:
		if count >= limit:
			break
		lines.append(_format_export_entry(entry))
		count += 1
	if lines.is_empty():
		return "Chronicle is empty."
	return "\n".join(lines)

## ─── Query / Stats ────────────────────────────────────────────

func get_chronicle(filter_type: int = -1, max_count: int = 50) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for entry in _chronicle:
		if filter_type >= 0 and entry.entry_type != filter_type:
			continue
		out.append(_entry_to_dict(entry))
		if out.size() >= max_count:
			break
	return out

func get_recent_entries(count: int = 10) -> Array[Dictionary]:
	var sorted: Array[ChronicleEntry] = _chronicle.duplicate()
	sorted.sort_custom(func(a: ChronicleEntry, b: ChronicleEntry) -> bool:
		return a.tick > b.tick)
	var out: Array[Dictionary] = []
	for i in range(mini(count, sorted.size())):
		out.append(_entry_to_dict(sorted[i]))
	return out

func get_entries_by_era(era: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for entry in _chronicle:
		if entry.era_at_time == era:
			out.append(_entry_to_dict(entry))
	return out

func get_entries_by_type(entry_type: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for entry in _chronicle:
		if entry.entry_type == entry_type:
			out.append(_entry_to_dict(entry))
	return out

func get_entries_for_settlement(settlement_id: int, max_count: int = 50) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for entry in _chronicle:
		if settlement_id in entry.involved_settlements:
			out.append(_entry_to_dict(entry))
			if out.size() >= max_count:
				break
	return out

func get_entries_for_pawn(pawn_id: int, max_count: int = 20) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for entry in _chronicle:
		if pawn_id in entry.involved_pawns:
			out.append(_entry_to_dict(entry))
			if out.size() >= max_count:
				break
	return out

func get_entry(index: int) -> Dictionary:
	if index < 0 or index >= _chronicle.size():
		return {}
	return _entry_to_dict(_chronicle[index])

func find_entries_by_text(query: String, max_count: int = 20) -> Array[Dictionary]:
	if query.is_empty():
		return []
	var lower_query: String = query.to_lower()
	var out: Array[Dictionary] = []
	for entry in _chronicle:
		if entry.description.to_lower().contains(lower_query):
			out.append(_entry_to_dict(entry))
			if out.size() >= max_count:
				break
	return out

func get_stats() -> Dictionary:
	var type_counts: Dictionary = {}
	var era_counts: Dictionary = {}
	var total_sig: float = 0.0
	var max_sig: float = 0.0
	var min_sig: float = 100.0
	for entry in _chronicle:
		var tn: int = entry.entry_type
		type_counts[tn] = type_counts.get(tn, 0) + 1
		var en: int = entry.era_at_time
		era_counts[en] = era_counts.get(en, 0) + 1
		total_sig += entry.significance
		if entry.significance > max_sig:
			max_sig = entry.significance
		if entry.significance < min_sig:
			min_sig = entry.significance
	return {
		"total_entries": _chronicle.size(),
		"total_chapters": _chapters.size(),
		"type_counts": type_counts,
		"era_counts": era_counts,
		"oldest_tick": _chronicle[0].tick if _chronicle.size() > 0 else 0,
		"newest_tick": _chronicle[_chronicle.size() - 1].tick if _chronicle.size() > 0 else 0,
		"avg_significance": (total_sig / float(_chronicle.size())) if _chronicle.size() > 0 else 0.0,
		"max_significance": max_sig,
		"min_significance": min_sig,
	}

## ─── Save / Load / Clear ──────────────────────────────────────

func clear() -> void:
	_chronicle.clear()
	_chapters.clear()
	_last_chronicle_tick = -999999
	_last_dynasty_check_tick = -999999
	_last_turning_point_tick = -999999
	_last_decay_tick = -999999
	_last_era_change_tick = 0
	_last_era = -1
	_entry_id_counter = 0
	_turning_points.clear()
	_dynasty_tracker.clear()
	_knowledge_snapshots.clear()
	_last_knowledge_snapshot_tick = -999999

func to_save_dict() -> Dictionary:
	var entries_arr: Array[Dictionary] = []
	for entry in _chronicle:
		entries_arr.append(_entry_to_save_dict(entry))
	var chapters_arr: Array[Dictionary] = []
	for ch in _chapters:
		chapters_arr.append({
			"era": ch.era,
			"era_name": ch.era_name,
			"start_tick": ch.start_tick,
			"end_tick": ch.end_tick,
			"entry_indices": ch.entry_indices.duplicate(),
			"summary": ch.summary,
		})
	return {
		"version": SAVE_VERSION,
		"chronicle": entries_arr,
		"chapters": chapters_arr,
		"last_chronicle_tick": _last_chronicle_tick,
		"last_dynasty_check_tick": _last_dynasty_check_tick,
		"last_turning_point_tick": _last_turning_point_tick,
		"last_decay_tick": _last_decay_tick,
		"last_era_change_tick": _last_era_change_tick,
		"last_era": _last_era,
		"entry_id_counter": _entry_id_counter,
	}

func from_save_dict(data: Variant) -> void:
	clear()
	if data == null or not (data is Dictionary):
		return
	var d: Dictionary = data as Dictionary
	var version: int = int(d.get("version", 0))
	if version < 1:
		return
	var raw_entries: Array = d.get("chronicle", [])
	for raw in raw_entries:
		if not (raw is Dictionary):
			continue
		var rd: Dictionary = raw as Dictionary
		var entry := ChronicleEntry.new(
			int(rd.get("tick", 0)),
			int(rd.get("entry_type", 0)),
			str(rd.get("description", "")),
			float(rd.get("significance", 0.0)),
			int(rd.get("era_at_time", 0)),
			rd.get("involved_pawns", []) as Array[int],
			rd.get("involved_settlements", []) as Array[int],
			bool(rd.get("forced", false))
		)
		_chronicle.append(entry)
	var raw_chapters: Array = d.get("chapters", [])
	for raw in raw_chapters:
		if not (raw is Dictionary):
			continue
		var cd: Dictionary = raw as Dictionary
		var ch := ChronicleChapter.new(
			int(cd.get("era", 0)),
			str(cd.get("era_name", "")),
			int(cd.get("start_tick", 0))
		)
		ch.end_tick = int(cd.get("end_tick", 0))
		ch.entry_indices = (cd.get("entry_indices", []) as Array).duplicate()
		ch.summary = str(cd.get("summary", ""))
		_chapters.append(ch)
	_last_chronicle_tick = int(d.get("last_chronicle_tick", -999999))
	_last_dynasty_check_tick = int(d.get("last_dynasty_check_tick", -999999))
	_last_turning_point_tick = int(d.get("last_turning_point_tick", -999999))
	_last_decay_tick = int(d.get("last_decay_tick", -999999))
	_last_era_change_tick = int(d.get("last_era_change_tick", 0))
	_last_era = int(d.get("last_era", -1))
	_entry_id_counter = int(d.get("entry_id_counter", 0))

## ─── Internal Helpers ─────────────────────────────────────────

func _entry_exists_at_tick(tick: int) -> bool:
	for entry in _chronicle:
		if entry.tick == tick:
			return true
	return false

func _entry_to_dict(entry: ChronicleEntry) -> Dictionary:
	return {
		"tick": entry.tick,
		"entry_type": entry.entry_type,
		"entry_type_name": ENTRY_TYPE_NAMES.get(entry.entry_type, "unknown"),
		"description": entry.description,
		"involved_pawns": entry.involved_pawns.duplicate(),
		"involved_settlements": entry.involved_settlements.duplicate(),
		"significance": entry.significance,
		"era_at_time": entry.era_at_time,
		"forced": entry.forced,
	}

func _entry_to_save_dict(entry: ChronicleEntry) -> Dictionary:
	return {
		"tick": entry.tick,
		"entry_type": entry.entry_type,
		"description": entry.description,
		"involved_pawns": entry.involved_pawns.duplicate(),
		"involved_settlements": entry.involved_settlements.duplicate(),
		"significance": entry.significance,
		"era_at_time": entry.era_at_time,
		"forced": entry.forced,
	}

func get_total_entries() -> int:
	return _chronicle.size()

func get_total_chapters() -> int:
	return _chapters.size()
