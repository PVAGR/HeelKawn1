extends Node
## ChronicleNarrativeSystem — generates Dwarf Fortress-style rich-text historical
## narratives from raw simulation events.
##
## Instead of logging "pawn 42 died", it generates:
##   "In the 3rd year of the Ashen Age, Kael of the River Clan perished
##    from wounds sustained defending the eastern wall. His brother Torvin
##    carved a grave marker at the site, and the settlement observed three
##    days of silence. The knowledge of fire-keeping that Kael carried now
##    rests with only two remaining masters."
##
## Design principles:
## - Deterministic: same events → same narrative
## - Contextual: narratives reference related events, people, places
## - Temporal: narratives span time periods, not isolated moments
## - Multi-scale: individual stories, settlement histories, world chronicles

# ============================================================
# CONSTANTS
# ============================================================

## How often to generate narrative summaries (ticks)
const NARRATIVE_INTERVAL: int = 2400  # ~4 in-game days

## How often to generate settlement histories (ticks)
const SETTLEMENT_HISTORY_INTERVAL: int = 12000  # ~20 in-game days

## How often to generate world chronicles (ticks)
const WORLD_CHRONICLE_INTERVAL: int = 48000  # ~1 sim year

## Max narrative entries to keep
const MAX_NARRATIVES: int = 500

## Event types that trigger immediate narrative
const IMMEDIATE_NARRATIVE_TYPES: PackedStringArray = [
	"death_significant",
	"settlement_founded",
	"settlement_collapsed",
	"wildfire",
	"famine",
	"battle",
	"knowledge_lost",
	"knowledge_rediscovered",
	"dynasty_formed",
	"nation_formed",
]

# ============================================================
# NARRATIVE STORAGE
# ============================================================

## Generated narratives: Array[Dictionary]
## Each: {"tick": int, "type": String, "scope": String, "text": String, "tags": PackedStringArray}
var narratives: Array[Dictionary] = []

## Pending raw events to process
var _pending_events: Array[Dictionary] = []

## Last tick a narrative was generated
var _last_narrative_tick: int = 0

## Event counters for period summaries
var _period_deaths: int = 0
var _period_births: int = 0
var _period_builds: int = 0
var _period_teachings: int = 0
var _period_conflicts: int = 0
var _period_discoveries: int = 0
var _period_start_tick: int = 0

# ============================================================
# NAME/CONTEXT RESOLUTION
# ============================================================

## Cached pawn names: pawn_id -> String
var _pawn_names: Dictionary = {}

## Cached settlement names: center_region -> String
var _settlement_names: Dictionary = {}

# ============================================================
# INITIALIZATION
# ============================================================

func _ready() -> void:
	if GameManager != null:
		GameManager.game_tick.connect(_on_game_tick)
	_period_start_tick = GameManager.tick_count if GameManager != null else 0


func _on_game_tick(tick: int) -> void:
	# Collect events from ChronicleLog
	_collect_pending_events()
	# Generate periodic narratives
	if tick - _last_narrative_tick >= NARRATIVE_INTERVAL:
		_generate_period_narrative(tick)
		_last_narrative_tick = tick
	# Generate settlement histories
	if tick % SETTLEMENT_HISTORY_INTERVAL == 0:
		_generate_settlement_histories(tick)
	# Generate world chronicle
	if tick % WORLD_CHRONICLE_INTERVAL == 0 and tick > 0:
		_generate_world_chronicle(tick)


# ============================================================
# EVENT COLLECTION
# ============================================================

func _collect_pending_events() -> void:
	"""Collect new events from ChronicleLog and WorldMemory."""
	if ChronicleLog == null:
		return
	for entry in ChronicleLog.entries:
		if entry is Dictionary:
			var tick_val: int = int(entry.get("tick", 0))
			if tick_val > _last_narrative_tick - NARRATIVE_INTERVAL:
				_pending_events.append(entry)
	# Process immediate narratives
	var to_process: Array[Dictionary] = _pending_events.duplicate()
	_pending_events.clear()
	for evt in to_process:
		_process_event(evt)


func _process_event(evt: Dictionary) -> void:
	"""Process a single event, generating immediate narrative if significant."""
	var evt_type: String = str(evt.get("type", evt.get("message", "")))
	var tick: int = int(evt.get("tick", 0))
	# Update period counters
	_update_period_counters(evt_type)
	# Check for immediate narrative triggers
	for trigger in IMMEDIATE_NARRATIVE_TYPES:
		if evt_type.contains(trigger):
			var narrative: String = _generate_immediate_narrative(evt)
			if narrative != "":
				_add_narrative(tick, "immediate", "event", narrative, [evt_type])
			break


func _update_period_counters(evt_type: String) -> void:
	if evt_type.contains("death") or evt_type.contains("killed"):
		_period_deaths += 1
	elif evt_type.contains("birth") or evt_type.contains("born"):
		_period_births += 1
	elif evt_type.contains("build") or evt_type.contains("constructed"):
		_period_builds += 1
	elif evt_type.contains("teach") or evt_type.contains("learn"):
		_period_teachings += 1
	elif evt_type.contains("conflict") or evt_type.contains("battle") or evt_type.contains("war"):
		_period_conflicts += 1
	elif evt_type.contains("discover") or evt_type.contains("innovat"):
		_period_discoveries += 1


# ============================================================
# IMMEDIATE NARRATIVE GENERATION
# ============================================================

func _generate_immediate_narrative(evt: Dictionary) -> String:
	var evt_type: String = str(evt.get("type", evt.get("message", "")))
	var tick: int = int(evt.get("tick", 0))
	var year: int = _tick_to_year(tick)
	var season: String = _tick_to_season_name(tick)
	match evt_type:
		"death_significant", "death":
			return _narrate_death(evt, year, season)
		"settlement_founded":
			return _narrate_settlement_founded(evt, year, season)
		"settlement_collapsed":
			return _narrate_settlement_collapsed(evt, year, season)
		"wildfire":
			return _narrate_wildfire(evt, year, season)
		"famine":
			return _narrate_famine(evt, year, season)
		"battle":
			return _narrate_battle(evt, year, season)
		"knowledge_lost":
			return _narrate_knowledge_lost(evt, year, season)
		"knowledge_rediscovered":
			return _narrate_knowledge_rediscovered(evt, year, season)
		"dynasty_formed":
			return _narrate_dynasty_formed(evt, year, season)
		"nation_formed":
			return _narrate_nation_formed(evt, year, season)
	return ""


func _narrate_death(evt: Dictionary, year: int, season: String) -> String:
	var name: String = str(evt.get("name", "Unknown"))
	var cause: String = str(evt.get("cause", "unknown causes"))
	var location: String = str(evt.get("location", "the wilderness"))
	var settlement: String = str(evt.get("settlement", ""))
	var knowledge: String = str(evt.get("knowledge_carried", ""))
	var narrative: String = ""
	if year > 0:
		narrative += "In %s of the %s, " % [_year_phrase(year), season.to_lower()]
	if settlement != "":
		narrative += "%s of %s perished from %s near %s. " % [name, settlement, cause, location]
	else:
		narrative += "%s perished from %s near %s. " % [name, cause, location]
	if knowledge != "":
		narrative += "The knowledge of %s that they carried now rests with fewer masters. " % knowledge
	# Check for family connections
	var family: String = str(evt.get("family", ""))
	if family != "":
		narrative += "%s mourns the loss. " % family
	return narrative


func _narrate_settlement_founded(evt: Dictionary, year: int, season: String) -> String:
	var name: String = str(evt.get("name", "A new settlement"))
	var founder: String = str(evt.get("founder", "unknown settlers"))
	var location: String = str(evt.get("location", "the wilderness"))
	var population: int = int(evt.get("population", 0))
	var narrative: String = ""
	if year > 0:
		narrative += "In %s of the %s, " % [_year_phrase(year), season.to_lower()]
	narrative += "%s was founded by %s at %s. " % [name, founder, location]
	if population > 0:
		narrative += "%d souls began their new life there. " % population
	narrative += "The land was untamed, but hope was abundant."
	return narrative


func _narrate_settlement_collapsed(evt: Dictionary, year: int, season: String) -> String:
	var name: String = str(evt.get("name", "A settlement"))
	var cause: String = str(evt.get("cause", "unknown reasons"))
	var survivors: int = int(evt.get("survivors", 0))
	var narrative: String = ""
	if year > 0:
		narrative += "In %s of the %s, " % [_year_phrase(year), season.to_lower()]
	narrative += "%s fell to %s. " % [name, cause]
	if survivors > 0:
		narrative += "%d survivors scattered to the winds, carrying memories of what once was. " % survivors
	narrative += "The ruins would remain as a testament to their struggle."
	return narrative


func _narrate_wildfire(evt: Dictionary, year: int, season: String) -> String:
	var fires: int = int(evt.get("fires", 0))
	var location: String = str(evt.get("location", "the forest"))
	var narrative: String = ""
	if year > 0:
		narrative += "In %s of the %s, " % [_year_phrase(year), season.to_lower()]
	narrative += "A wildfire consumed %d areas near %s. " % [fires, location]
	if season == "Summer" or season == "Autumn":
		narrative += "The dry season had left the land vulnerable. "
	narrative += "The scars would take years to heal."
	return narrative


func _narrate_famine(evt: Dictionary, year: int, season: String) -> String:
	var severity: String = str(evt.get("severity", "moderate"))
	var affected: String = str(evt.get("affected", "the region"))
	var deaths: int = int(evt.get("deaths", 0))
	var narrative: String = ""
	if year > 0:
		narrative += "In %s of the %s, " % [_year_phrase(year), season.to_lower()]
	narrative += "A %s famine struck %s. " % [severity, affected]
	if deaths > 0:
		narrative += "%d souls perished from hunger. " % deaths
	narrative += "The survivors would remember this season for generations."
	return narrative


func _narrate_battle(evt: Dictionary, year: int, season: String) -> String:
	var attacker: String = str(evt.get("attacker", "Unknown force"))
	var defender: String = str(evt.get("defender", "Unknown defenders"))
	var location: String = str(evt.get("location", "the battlefield"))
	var casualties: int = int(evt.get("casualties", 0))
	var outcome: String = str(evt.get("outcome", "inconclusive"))
	var narrative: String = ""
	if year > 0:
		narrative += "In %s of the %s, " % [_year_phrase(year), season.to_lower()]
	narrative += "The forces of %s clashed with %s at %s. " % [attacker, defender, location]
	if casualties > 0:
		narrative += "%d fell in the fighting. " % casualties
	narrative += "The outcome was %s. " % outcome
	narrative += "Songs would be sung of this day."
	return narrative


func _narrate_knowledge_lost(evt: Dictionary, year: int, season: String) -> String:
	var knowledge: String = str(evt.get("knowledge", "ancient wisdom"))
	var last_master: String = str(evt.get("last_master", "the last teacher"))
	var narrative: String = ""
	if year > 0:
		narrative += "In %s of the %s, " % [_year_phrase(year), season.to_lower()]
	narrative += "The knowledge of %s was lost with the passing of %s. " % [knowledge, last_master]
	narrative += "Unless rediscovered, this wisdom would fade from memory."
	return narrative


func _narrate_knowledge_rediscovered(evt: Dictionary, year: int, season: String) -> String:
	var knowledge: String = str(evt.get("knowledge", "forgotten wisdom"))
	var discoverer: String = str(evt.get("discoverer", "a curious soul"))
	var location: String = str(evt.get("location", "an old ruin"))
	var narrative: String = ""
	if year > 0:
		narrative += "In %s of the %s, " % [_year_phrase(year), season.to_lower()]
	narrative += "%s rediscovered the knowledge of %s at %s. " % [discoverer, knowledge, location]
	narrative += "What was lost to time had been found again."
	return narrative


func _narrate_dynasty_formed(evt: Dictionary, year: int, season: String) -> String:
	var name: String = str(evt.get("name", "A new dynasty"))
	var founder: String = str(evt.get("founder", "a prominent family"))
	var settlement: String = str(evt.get("settlement", ""))
	var narrative: String = ""
	if year > 0:
		narrative += "In %s of the %s, " % [_year_phrase(year), season.to_lower()]
	if settlement != "":
		narrative += "The %s dynasty was established by %s in %s. " % [name, founder, settlement]
	else:
		narrative += "The %s dynasty was established by %s. " % [name, founder]
	narrative += "Their lineage would shape the fate of the region."
	return narrative


func _narrate_nation_formed(evt: Dictionary, year: int, season: String) -> String:
	var name: String = str(evt.get("name", "A new nation"))
	var founder: String = str(evt.get("founder", "united settlements"))
	var territory: String = str(evt.get("territory", "the land"))
	var narrative: String = ""
	if year > 0:
		narrative += "In %s of the %s, " % [_year_phrase(year), season.to_lower()]
	narrative += "%s rose from %s, claiming %s as their domain. " % [name, founder, territory]
	narrative += "A new chapter in history had begun."
	return narrative


# ============================================================
# PERIOD NARRATIVE GENERATION
# ============================================================

func _generate_period_narrative(tick: int) -> void:
	"""Generate a summary narrative for the recent period."""
	if _period_deaths == 0 and _period_births == 0 and _period_builds == 0 and _period_teachings == 0:
		return
	var year: int = _tick_to_year(tick)
	var season: String = _tick_to_season_name(tick)
	var parts: PackedStringArray = []
	if year > 0:
		parts.append("The %s of %s saw" % [season.to_lower(), _year_phrase(year)])
	else:
		parts.append("This season saw")
	var events: PackedStringArray = []
	if _period_deaths > 0:
		events.append("%d deaths" % _period_deaths)
	if _period_births > 0:
		events.append("%d births" % _period_births)
	if _period_builds > 0:
		events.append("%d structures built" % _period_builds)
	if _period_teachings > 0:
		events.append("%d teachings shared" % _period_teachings)
	if _period_conflicts > 0:
		events.append("%d conflicts" % _period_conflicts)
	if _period_discoveries > 0:
		events.append("%d discoveries" % _period_discoveries)
	if events.is_empty():
		return
	parts.append(", ".join(events))
	var narrative: String = " ".join(parts) + "."
	# Add character based on overall tone
	if _period_deaths > _period_births and _period_conflicts > 0:
		narrative += " It was a dark time."
	elif _period_births > _period_deaths and _period_builds > 0:
		narrative += " Hope flourished."
	elif _period_discoveries > 0:
		narrative += " Knowledge advanced."
	else:
		narrative += " Life continued its steady rhythm."
	_add_narrative(tick, "period", "summary", narrative, ["summary"])
	# Reset counters
	_period_deaths = 0
	_period_births = 0
	_period_builds = 0
	_period_teachings = 0
	_period_conflicts = 0
	_period_discoveries = 0
	_period_start_tick = tick


# ============================================================
# SETTLEMENT HISTORY GENERATION
# ============================================================

func _generate_settlement_histories(tick: int) -> void:
	"""Generate historical narratives for each settlement."""
	if SettlementMemory == null:
		return
	for st_v in SettlementMemory.settlements:
		if not (st_v is Dictionary):
			continue
		var st: Dictionary = st_v as Dictionary
		var name: String = str(st.get("name", "Unknown"))
		var pop: int = int(st.get("population", 0))
		var age: int = int(st.get("age_ticks", 0))
		var year: int = _tick_to_year(tick)
		var narrative: String = ""
		narrative += "%s, " % name
		if age > 0:
			var age_years: int = age / TICKS_PER_YEAR
			if age_years > 0:
				narrative += "aged %d years, " % age_years
		narrative += "stands with %d souls. " % pop
		# Add notable events from ChronicleLog related to this settlement
		var notable: Array = _find_notable_settlement_events(name, tick)
		if not notable.is_empty():
			narrative += "Notable: " + "; ".join(notable) + "."
		_add_narrative(tick, "settlement", "history", narrative, ["settlement", name])


func _find_notable_settlement_events(settlement_name: String, current_tick: int) -> Array:
	"""Find notable events related to a settlement in recent history."""
	var notable: Array = []
	if ChronicleLog == null:
		return notable
	var cutoff: int = current_tick - SETTLEMENT_HISTORY_INTERVAL
	for entry in ChronicleLog.entries:
		if entry is Dictionary:
			var tick_val: int = int(entry.get("tick", 0))
			if tick_val < cutoff:
				continue
		 var msg: String = str(entry.get("message", ""))
			if msg.contains(settlement_name):
				var evt_type: String = str(entry.get("type", ""))
				if evt_type.contains("death") or evt_type.contains("build") or evt_type.contains("conflict"):
					notable.append(msg)
					if notable.size() >= 3:
						return notable
	return notable


# ============================================================
# WORLD CHRONICLE GENERATION
# ============================================================

func _generate_world_chronicle(tick: int) -> void:
	"""Generate a world-spanning chronicle narrative."""
	var year: int = _tick_to_year(tick)
	if year <= 0:
		return
	var narrative: String = ""
	narrative += "The Chronicle of Year %d: " % year
	# Count major events from the year
	var year_events: Dictionary = _count_year_events(tick)
	var parts: PackedStringArray = []
	if year_events.get("deaths", 0) > 5:
		parts.append("%d souls departed" % year_events["deaths"])
	if year_events.get("births", 0) > 5:
		parts.append("%d new lives began" % year_events["births"])
	if year_events.get("settlements_founded", 0) > 0:
		parts.append("%d settlements founded" % year_events["settlements_founded"])
	if year_events.get("settlements_lost", 0) > 0:
		parts.append("%d settlements fell" % year_events["settlements_lost"])
	if year_events.get("battles", 0) > 0:
		parts.append("%d battles fought" % year_events["battles"])
	if year_events.get("knowledge_lost", 0) > 0:
		parts.append("%d knowledges faded" % year_events["knowledge_lost"])
	if year_events.get("knowledge_found", 0) > 0:
		parts.append("%d knowledges discovered" % year_events["knowledge_found"])
	if parts.is_empty():
		narrative += "A quiet year. The world turned, and life persisted."
	else:
		narrative += ", ".join(parts) + "."
		# Add closing sentiment
		var total_events: int = 0
		for v in year_events.values():
			total_events += int(v)
		if total_events > 20:
			narrative += " History accelerated."
		elif total_events > 10:
			narrative += " The world changed steadily."
		else:
			narrative += " Change came gently."
	_add_narrative(tick, "chronicle", "world", narrative, ["chronicle", "year_%d" % year])


func _count_year_events(current_tick: int) -> Dictionary:
	"""Count major events from the current year."""
	var year_start: int = (current_tick / TICKS_PER_YEAR) * TICKS_PER_YEAR
	var counts: Dictionary = {
		"deaths": 0, "births": 0, "settlements_founded": 0,
		"settlements_lost": 0, "battles": 0, "knowledge_lost": 0,
		"knowledge_found": 0,
	}
	if ChronicleLog == null:
		return counts
	for entry in ChronicleLog.entries:
		if entry is Dictionary:
			var tick_val: int = int(entry.get("tick", 0))
			if tick_val < year_start:
				continue
			var evt_type: String = str(entry.get("type", ""))
			if evt_type.contains("death"):
				counts["deaths"] = int(counts.get("deaths", 0)) + 1
			elif evt_type.contains("birth"):
				counts["births"] = int(counts.get("births", 0)) + 1
			elif evt_type.contains("founded"):
				counts["settlements_founded"] = int(counts.get("settlements_founded", 0)) + 1
			elif evt_type.contains("collapsed"):
				counts["settlements_lost"] = int(counts.get("settlements_lost", 0)) + 1
			elif evt_type.contains("battle") or evt_type.contains("conflict"):
				counts["battles"] = int(counts.get("battles", 0)) + 1
			elif evt_type.contains("knowledge_lost"):
				counts["knowledge_lost"] = int(counts.get("knowledge_lost", 0)) + 1
			elif evt_type.contains("rediscovered") or evt_type.contains("discovered"):
				counts["knowledge_found"] = int(counts.get("knowledge_found", 0)) + 1
	return counts


# ============================================================
# HELPERS
# ============================================================

func _add_narrative(tick: int, type: String, scope: String, text: String, tags: PackedStringArray) -> void:
	narratives.append({
		"tick": tick,
		"type": type,
		"scope": scope,
		"text": text,
		"tags": tags,
	})
	if narratives.size() > MAX_NARRATIVES:
		narratives.remove_at(0)
	# Also log to ChronicleLog for UI display
	if ChronicleLog != null:
		ChronicleLog.append_entry(tick, "world", text, PackedStringArray(tags))


func _tick_to_year(tick: int) -> int:
	if tick <= 0:
		return 0
	return tick / TICKS_PER_YEAR


func _tick_to_season_name(tick: int) -> String:
	if Biome == null:
		return "Spring"
	var season: int = Biome.season_for_tick(tick)
	return Biome.season_name(season)


func _year_phrase(year: int) -> String:
	if year == 1:
		return "the 1st year"
	elif year == 2:
		return "the 2nd year"
	elif year == 3:
		return "the 3rd year"
	else:
		return "the %dth year" % year


# ============================================================
# PUBLIC API
# ============================================================

func get_narratives_since(tick: int) -> Array[Dictionary]:
	"""Get all narratives generated since the given tick."""
	var result: Array[Dictionary] = []
	for n in narratives:
		if int(n.get("tick", 0)) >= tick:
			result.append(n)
	return result


func get_narratives_by_type(type: String) -> Array[Dictionary]:
	"""Get narratives of a specific type."""
	var result: Array[Dictionary] = []
	for n in narratives:
		if str(n.get("type", "")) == type:
			result.append(n)
	return result


func get_latest_narratives(count: int = 10) -> Array[Dictionary]:
	"""Get the most recent narratives."""
	var result: Array[Dictionary] = []
	var start: int = maxi(0, narratives.size() - count)
	for i in range(start, narratives.size()):
		result.append(narratives[i])
	return result


func get_narrative_summary(tick: int) -> String:
	"""Get a summary of all narratives since the given tick."""
	var recent: Array[Dictionary] = get_narratives_since(tick)
	if recent.is_empty():
		return "No significant events."
	var parts: PackedStringArray = []
	for n in recent:
		parts.append(str(n.get("text", "")))
	return " | ".join(parts)


const TICKS_PER_YEAR: int = 48000
