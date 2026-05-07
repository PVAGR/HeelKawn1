extends Node
## ChronicleExport - Auto-generates readable summaries from WorldMemory
##
## Creates human-readable chronicles of settlement history:
## - Major events (births, deaths, innovations, battles)
## - Timeline of significant moments
## - Legacy summaries for important pawns
## - Settlement achievements and milestones
##
## Output: `user://chronicles/YYYY-MM-DD_HHMMSS_chronicle.txt`

const OUTPUT_DIR: String = "user://chronicles/"
const EVENTS_PER_SECTION: int = 50  # Limit sections for readability

# Event type categories
const EVENT_CATEGORIES: Dictionary = {
	"births": ["pawn_birth", "birth"],
	"deaths": ["pawn_death", "death"],
	"innovations": ["innovation", "knowledge_discovered"],
	"settlements": ["settlement_founded", "settlement_abandoned", "settlement_revived"],
	"conflicts": ["battle", "raid", "combat"],
	"achievements": ["memorial_built", "knowledge_carrier", "teaching_session"],
	"natural": ["famine_warning", "macro_festival", "macro_unrest"],
}

var _last_export_tick: int = 0
const EXPORT_INTERVAL_TICKS: int = 3000  # Auto-export every 3000 ticks (~50 sim days)


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)
	GameManager.game_tick.connect(_on_game_tick)


func _on_game_tick(tick: int) -> void:
	# Auto-export periodically
	if tick - _last_export_tick >= EXPORT_INTERVAL_TICKS:
		export_chronicle()
		_last_export_tick = tick


## Export full chronicle to file
func export_chronicle() -> String:
	if WorldMemory == null:
		push_error("[ChronicleExport] WorldMemory not available")
		return ""
	
	var events: Array = WorldMemory.get_events()
	if events.is_empty():
		return ""
	
	var chronicle: String = _build_chronicle(events)
	var filename: String = _generate_filename()
	
	# Save to file
	var file: FileAccess = FileAccess.open(OUTPUT_DIR + filename, FileAccess.WRITE)
	if file != null:
		file.store_string(chronicle)
		file.close()
		print("[ChronicleExport] Saved chronicle: %s (%d events)" % [filename, events.size()])
		return filename
	
	push_error("[ChronicleExport] Failed to save chronicle: %s" % filename)
	return ""


func _build_chronicle(events: Array) -> String:
	var chronicle: String = ""
	
	# Header
	chronicle += "╔══════════════════════════════════════════════════════════╗\n"
	chronicle += "║           HEELKAWN CHRONICLE - SETTLEMENT HISTORY        ║\n"
	chronicle += "╚══════════════════════════════════════════════════════════╝\n\n"
	
	chronicle += "Generated: %s\n" % Time.get_datetime_string_from_system()
	chronicle += "Total Events: %d\n" % events.size()
	chronicle += "Tick Range: 0 - %d\n\n" % GameManager.tick_count
	
	# Table of Contents
	chronicle += "━━━ TABLE OF CONTENTS ━━━\n"
	chronicle += "1. Settlement Founding & Major Events\n"
	chronicle += "2. Births & Lineages\n"
	chronicle += "3. Deaths & Memorials\n"
	chronicle += "4. Innovations & Knowledge\n"
	chronicle += "5. Conflicts & Battles\n"
	chronicle += "6. Natural Events & Festivals\n\n"
	
	# Section 1: Settlement Events
	chronicle += "━━━ 1. SETTLEMENT FOUNDING & MAJOR EVENTS ━━━\n\n"
	var settlement_events: Array = _filter_events(events, EVENT_CATEGORIES.settlements)
	chronicle += _format_event_section(settlement_events, "Settlement")
	
	# Section 2: Births
	chronicle += "\n━━━ 2. BIRTHS & LINEAGES ━━━\n\n"
	var birth_events: Array = _filter_events(events, EVENT_CATEGORIES.births)
	chronicle += _format_event_section(birth_events, "Birth")
	
	# Section 3: Deaths
	chronicle += "\n━━━ 3. DEATHS & MEMORIALS ━━━\n\n"
	var death_events: Array = _filter_events(events, EVENT_CATEGORIES.deaths)
	chronicle += _format_event_section(death_events, "Death")
	
	# Section 4: Innovations
	chronicle += "\n━━━ 4. INNOVATIONS & KNOWLEDGE ━━━\n\n"
	var innovation_events: Array = _filter_events(events, EVENT_CATEGORIES.innovations)
	chronicle += _format_event_section(innovation_events, "Innovation")
	
	# Section 5: Conflicts
	chronicle += "\n━━━ 5. CONFLICTS & BATTLES ━━━\n\n"
	var conflict_events: Array = _filter_events(events, EVENT_CATEGORIES.conflicts)
	chronicle += _format_event_section(conflict_events, "Conflict")
	
	# Section 6: Natural Events
	chronicle += "\n━━━ 6. NATURAL EVENTS & FESTIVALS ━━━\n\n"
	var natural_events: Array = _filter_events(events, EVENT_CATEGORIES.natural)
	chronicle += _format_event_section(natural_events, "Event")
	
	# Summary Statistics
	chronicle += "\n━━━ SUMMARY STATISTICS ━━━\n\n"
	chronicle += _generate_statistics(events)
	
	return chronicle


func _filter_events(events: Array, categories: Dictionary) -> Array:
	var filtered: Array = []
	for event in events:
		if event is Dictionary:
			var event_type: String = str(event.get("type", ""))
			for category_name in categories.keys():
				if category_name in categories:
					var type_list: Array = categories[category_name]
					if event_type in type_list:
						filtered.append(event)
						break
	return filtered


func _format_event_section(events: Array, section_name: String) -> String:
	var output: String = ""

	if events.is_empty():
		output += "  (No %s events recorded)\n" % section_name.to_lower()
		return output

	# Limit to most recent events for readability
	var limit: int = mini(EVENTS_PER_SECTION, events.size())
	var start_idx: int = maxi(0, events.size() - limit)

	for i in range(start_idx, events.size()):
		var event: Dictionary = events[i]
		var line: String = _format_event_line(event)
		output += "  %s\n" % line

	if events.size() > EVENTS_PER_SECTION:
		output += "\n  ... and %d more %s events\n" % [events.size() - EVENTS_PER_SECTION, section_name.to_lower()]

	return output


func _format_event_line(event: Dictionary) -> String:
	var tick: int = int(event.get("tick", 0))
	var day: int = tick / 600  # Approximate sim days
	var event_type: String = str(event.get("type", "unknown"))
	
	# Format based on event type
	match event_type:
		"pawn_birth", "birth":
			var name: String = str(event.get("pawn_name", "Unknown"))
			var parents: String = ""
			if event.has("parent_a_name"):
				parents = " to %s and %s" % [event.get("parent_a_name", ""), event.get("parent_b_name", "")]
			return "Y%d D%d: %s born%s" % [day, tick % 600, name, parents]
		
		"pawn_death", "death":
			var name: String = str(event.get("pawn_name", "Unknown"))
			var cause: String = str(event.get("cause", "unknown causes"))
			return "Y%d D%d: %s died (%s)" % [day, tick % 600, name, cause]
		
		"innovation":
			var pawn_name: String = str(event.get("pawn_name", "Someone"))
			var result: String = str(event.get("result_name", "something new"))
			return "Y%d D%d: %s discovered %s" % [day, tick % 600, pawn_name, result]
		
		"settlement_founded":
			var name: String = str(event.get("settlement_name", "Unnamed"))
			return "Y%d D%d: Settlement founded: %s" % [day, tick % 600, name]
		
		"battle", "raid":
			var region: int = int(event.get("region", -1))
			return "Y%d D%d: Conflict in region %d" % [day, tick % 600, region]
		
		"famine_warning":
			var severity: int = int(event.get("severity", 0))
			return "Y%d D%d: Famine warning (severity: %d)" % [day, tick % 600, severity]
		
		"macro_festival":
			return "Y%d D%d: Grand festival celebrated" % [day, tick % 600]
		
		_:
			return "Y%d D%d: %s" % [day, tick % 600, event_type]


func _generate_statistics(events: Array) -> String:
	var stats: String = ""

	# Count by type
	var type_counts: Dictionary = {}
	for event in events:
		if event is Dictionary:
			var event_type: String = str(event.get("type", "unknown"))
			type_counts[event_type] = type_counts.get(event_type, 0) + 1

	stats += "Event Counts by Type:\n"
	for event_type in type_counts.keys():
		stats += "  • %s: %d\n" % [event_type, type_counts[event_type]]

	# Time span
	if not events.is_empty():
		var first_tick: int = int(events[0].get("tick", 0))
		var last_tick: int = int(events[-1].get("tick", 0))
		var total_days: int = (last_tick - first_tick) / 600
		stats += "\nTimeline Span: %d sim days (%d ticks)\n" % [total_days, last_tick - first_tick]

	return stats


func _generate_filename() -> String:
	var timestamp: String = Time.get_datetime_string_from_system().replace(":", "").replace(" ", "_").replace("-", "")
	return "chronicle_%s_tick_%d.txt" % [timestamp, GameManager.tick_count]


## Export single pawn biography
func export_pawn_biography(pawn_data: RefCounted) -> String:
	if pawn_data == null:
		return ""

	var bio: String = ""
	bio += "╔══════════════════════════════════════════════════════════╗\n"
	bio += "║                    LIFE CHRONICLE                        ║\n"
	bio += "╚══════════════════════════════════════════════════════════╝\n\n"

	bio += "Name: %s\n" % pawn_data.display_name
	bio += "Profession: %s\n" % pawn_data.profession_name()
	bio += "Born: Tick %d\n" % pawn_data.birth_tick
	bio += "Age: %.1f years\n\n" % (pawn_data.age / 360.0)

	# Life events would be pulled from WorldMemory
	# For now, use the pawn's built-in biography if available
	if pawn_data.has_method("compose_life_arc"):
		bio += pawn_data.call("compose_life_arc")

	return bio
