class_name ChronicleFeed
extends CanvasLayer

## Real-time scrolling event stream. Shows the latest significant world events
## as colored, human-readable text. Always visible (toggle with C key).

const MAX_VISIBLE_LINES: int = 7  # Show only latest 7 events (was 20)
const FEED_WIDTH: float = 280.0  # Narrower (was 300)
const FEED_MARGIN_RIGHT: float = 12.0  # More margin from edge
const FEED_MARGIN_TOP: float = 80.0  # Lower from top (was 40)
const FEED_MARGIN_BOTTOM: float = 12.0
const FONT_SIZE: int = 10  # Smaller font (was 11)
const REFRESH_EVERY_N_TICKS: int = 10
const REFRESH_FAST: int = 30
const REFRESH_ULTRA: int = 60

## Event category colors
const COLOR_LIFE: String = "#dcb478"       # gold — births, bloodlines
const COLOR_DEATH: String = "#cc4444"      # red — deaths, extinction
const COLOR_KNOWLEDGE: String = "#44cccc"  # cyan — teaching, knowledge
const COLOR_AUTHORITY: String = "#bb77ee"  # purple — authority, governance
const COLOR_SETTLEMENT: String = "#66cc66" # green — structures, settlement
const COLOR_WORLD: String = "#eeaa44"      # amber — economy, collapse, rituals
const COLOR_CONFLICT: String = "#dd3333"  # dark red — war, injury, feud
const COLOR_FOOD: String = "#aaaa44"      # olive — food, farming
const COLOR_CULTURE: String = "#44aaaa"    # teal — culture, social
const COLOR_CRAFT: String = "#cc8844"     # bronze — crafting, tools
const COLOR_TRADE: String = "#88bb44"     # lime — trade routes, markets
const COLOR_DEFAULT: String = "#999999"   # gray — uncategorized

var _feed: RichTextLabel
var _bg: ColorRect
var _visible: bool = true
var _last_seen_event_count: int = 0
var _header: Label


func _ready() -> void:
	layer = 15  # Below HUD (20), above game

	# Background - more opaque for better readability
	_bg = ColorRect.new()
	_bg.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	_bg.color = Color(0.06, 0.08, 0.10, 0.92)  # More opaque (was 0.75)
	_bg.offset_left = -FEED_WIDTH - FEED_MARGIN_RIGHT
	_bg.offset_top = FEED_MARGIN_TOP
	_bg.offset_right = -FEED_MARGIN_RIGHT
	_bg.offset_bottom = -FEED_MARGIN_BOTTOM
	_bg.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_bg)

	# Header label
	_header = Label.new()
	_header.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	_header.offset_left = -FEED_WIDTH - FEED_MARGIN_RIGHT
	_header.offset_top = FEED_MARGIN_TOP
	_header.offset_right = -FEED_MARGIN_RIGHT
	_header.offset_bottom = FEED_MARGIN_TOP + 20
	_header.text = "  Chronicle"
	_header.add_theme_font_size_override("font_size", 11)
	_header.add_theme_color_override("font_color", Color(0.75, 0.70, 0.60, 0.85))
	add_child(_header)

	# Feed text - better padding and contrast
	_feed = RichTextLabel.new()
	_feed.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	_feed.offset_left = -FEED_WIDTH - FEED_MARGIN_RIGHT
	_feed.offset_top = FEED_MARGIN_TOP + 20
	_feed.offset_right = -FEED_MARGIN_RIGHT
	_feed.offset_bottom = -FEED_MARGIN_BOTTOM
	_feed.bbcode_enabled = true
	_feed.scroll_following = true
	_feed.scroll_active = true
	_feed.add_theme_font_size_override("normal_font_size", FONT_SIZE)
	_feed.add_theme_font_size_override("bold_font_size", FONT_SIZE)
	_feed.add_theme_color_override("default_color", Color(0.85, 0.82, 0.75, 0.95))  # Lighter text
	_feed.mouse_filter = Control.MOUSE_FILTER_PASS
	_feed.selection_enabled = true  # Allow copyable text
	# Fit content
	_feed.fit_content = false
	_feed.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Add internal padding
	_feed.add_theme_constant_override("margin_left", 8)
	_feed.add_theme_constant_override("margin_right", 8)
	_feed.add_theme_constant_override("line_spacing", 3)  # Better line spacing
	add_child(_feed)

	# Connect game tick
	if GameManager != null:
		GameManager.game_tick.connect(_on_tick)


func _on_tick(tick: int) -> void:
	if not _visible:
		return
	var refresh_stride: int = _refresh_stride_for_speed(GameManager.game_speed)
	if tick % refresh_stride != 0 and _last_seen_event_count > 0:
		return
	_refresh()


func _refresh_stride_for_speed(speed: float) -> int:
	if speed >= 100.0:
		return REFRESH_ULTRA
	if speed >= 50.0:
		return REFRESH_FAST
	return REFRESH_EVERY_N_TICKS


func _refresh() -> void:
	if WorldMemory == null:
		return
	var current_count: int = WorldMemory.event_count()
	if current_count == _last_seen_event_count:
		return
	_last_seen_event_count = current_count

	# Get recent events
	var events: Array = WorldMemory.get_recent_events(64)
	if events.is_empty():
		return

	# Build lines from newest events, taking the most recent MAX_VISIBLE_LINES
	var lines: Array[String] = []
	var processed: int = 0
	for i in range(events.size() - 1, -1, -1):
		if processed >= MAX_VISIBLE_LINES:
			break
		var e_any: Variant = events[i]
		if not (e_any is Dictionary):
			continue
		var e: Dictionary = e_any as Dictionary
		var line: String = _chronicle_line_for_event(e)
		if line.is_empty():
			continue
		lines.append(line)
		processed += 1

	if lines.is_empty():
		return

	# Reverse so newest is at bottom
	lines.reverse()
	_feed.clear()
	for line in lines:
		_feed.append_text(line + "\n")


func toggle() -> void:
	_visible = not _visible
	_bg.visible = _visible
	_header.visible = _visible
	_feed.visible = _visible
	if _visible:
		_last_seen_event_count = 0  # Force refresh
		_refresh()


## Color for an event type
func _color_for_type(typ: String) -> String:
	# Life
	if typ in ["birth", "pawn_birth", "bloodline_founded", "bloodline_member_added"]:
		return COLOR_LIFE
	# Death
	if typ in ["pawn_death", "animal_death", "enemy_death", "bloodline_extinct", "diaspora_grief"]:
		return COLOR_DEATH
	# Knowledge
	if typ in ["teaching_success", "teaching_failure", "knowledge_discovery", "knowledge_rediscovery",
			"knowledge_sealed", "knowledge_lost", "knowledge_at_risk", "knowledge_crisis"]:
		return COLOR_KNOWLEDGE
	# Authority
	if typ in ["authority_change", "authority_points_added", "authority_vacuum", "governance_change",
			"succession", "abdicate", "pledge_loyalty", "edict_issued", "law_added", "law_removed",
			"ruler_decision"]:
		return COLOR_AUTHORITY
	# Settlement
	if typ in ["structure_built", "cooperative_build", "settlement_intent_shift",
			"settlement_abandon", "settlement_revival", "settlement_rebirth",
			"settlement_collapse", "settlement_new_foundation", "settlement_revival_with_lineage",
			"hearth_built", "storage_built", "shrine_built", "marker_built",
			"diaspora_exile", "migration_started", "migration_completed"]:
		return COLOR_SETTLEMENT
	# World
	if typ in ["collapse_warning", "environmental_degradation", "economic_boom", "market_crash",
			"sacred_site_established", "ritual_performed", "religious_schism", "religious_conversion",
			"emergent_pattern_detected", "historical_saturation", "collapse_metric_change",
			"entity_decay", "entity_loss"]:
		return COLOR_WORLD
	# Conflict
	if typ in ["war_battle_spawned", "war_proposed", "injury", "social_fragment", "social_schism",
			"grudge_formed", "grudge_inherited"]:
		return COLOR_CONFLICT
	# Food
	if typ in ["food_spoiled", "seeds_planted", "crop_harvested", "starvation_event",
			"famine_warning", "food_cooked"]:
		return COLOR_FOOD
	# Culture
	if typ in ["cultural_exposure", "cultural_building", "social_bond_milestone", "social_meeting",
			"ritual_performed", "sacred_site_established", "legacy_record", "bloodline_extinct",
			"macro_festival"]:
		return COLOR_CULTURE
	# Craft
	if typ in ["tool_crafted", "tool_break", "food_cooked", "book_bound", "ink_made",
			"paper_made", "leather_tanned", "pen_crafted"]:
		return COLOR_CRAFT
	# Trade
	if typ in ["trade_route_started", "trade_route_completed", "macro_unrest"]:
		return COLOR_TRADE
	return COLOR_DEFAULT


## Format a single event as a BBCode chronicle line
func _chronicle_line_for_event(e: Dictionary) -> String:
	var typ: String = str(e.get("type", ""))
	var tick: int = int(e.get("tick", e.get("t", 0)))
	var text: String = _event_text(typ, e)
	if text.is_empty():
		return ""
	var color: String = _color_for_type(typ)
	# Day calculation
	var day: int = tick / 600 if tick > 0 else 0
	return "[color=#555555]d%d[/color] [color=%s]%s[/color]" % [day, color, text]


## Human-readable text for an event type
func _event_text(typ: String, e: Dictionary) -> String:
	# Filter out noisy internal events that flood the feed
	if typ in ["region_discovery", "knowledge_acquisition", "life_path_switch",
			"life_path_milestone", "unknown", "job_completed", "player_inspect"]:
		return ""

	# First-of-type milestone
	if bool(e.get("first_of_type", false)):
		return "[i]first: %s[/i]" % typ.replace("_", " ")

	match typ:
		"birth", "pawn_birth":
			var child_name: String = str(e.get("pawn_name", "a child")).strip_edges()
			if child_name.is_empty(): child_name = "a child"
			var pa: String = str(e.get("parent_a_name", "")).strip_edges()
			var pb: String = str(e.get("parent_b_name", "")).strip_edges()
			if not pa.is_empty() and not pb.is_empty():
				return "%s born to %s + %s" % [child_name, pa, pb]
			return "%s was born" % child_name

		"pawn_death":
			var nm: String = str(e.get("n", e.get("name", "someone"))).strip_edges()
			if nm.is_empty(): nm = "someone"
			var cause: String = str(e.get("cause", "")).strip_edges()
			var cause_text: String = ""
			if not cause.is_empty():
				cause_text = " of %s" % cause.replace("_", " ")
			return "%s died%s" % [nm, cause_text]

		"animal_death":
			return "wildlife was culled"

		"enemy_death":
			return "an enemy fell"

		"structure_built":
			var worker: String = str(e.get("worker_name", "")).strip_edges()
			var job_type: int = int(e.get("job_type", -1))
			var job_name: String = Job.describe_type(job_type) if Job != null else "structure"
			var tile_x: int = int(e.get("x", int(e.get("tile", {}).get("x", -1))))
			var tile_y: int = int(e.get("y", int(e.get("tile", {}).get("y", -1))))
			if worker.is_empty():
				worker = "someone"
			var loc: String = ""
			if tile_x >= 0 and tile_y >= 0:
				loc = " at (%d,%d)" % [tile_x, tile_y]
			return "%s built %s%s" % [worker, job_name, loc]

		"cooperative_build":
			var worker: String = str(e.get("worker_name", "")).strip_edges()
			var nearby: int = int(e.get("nearby_workers", 0))
			if worker.is_empty():
				worker = "a crew"
			var crew: String = " with %d nearby" % nearby if nearby > 1 else ""
			return "%s raised a structure together%s" % [worker, crew]

		"knowledge_discovery":
			var kt: String = str(e.get("knowledge_type", "?"))
			return "new knowledge discovered (%s)" % kt

		"knowledge_rediscovery":
			return "lost knowledge was rediscovered"

		"knowledge_sealed":
			var nm: String = str(e.get("carrier_name", "a scholar")).strip_edges()
			return "%s died with unfulfilled teaching obligations" % nm

		"knowledge_lost":
			var kt: String = str(e.get("knowledge_type", "knowledge")).strip_edges()
			return "%s was lost to the settlement" % kt

		"knowledge_at_risk":
			var kt: String = str(e.get("knowledge_type", "knowledge")).strip_edges()
			return "%s is at risk — only one carrier remains" % kt

		"knowledge_crisis":
			return "knowledge crisis — multiple skills at risk"

		"teaching_success":
			var teacher: String = str(e.get("teacher_name", "A")).strip_edges()
			var student: String = str(e.get("student_name", "B")).strip_edges()
			var kt: String = str(e.get("knowledge_type", "")).strip_edges()
			if not teacher.is_empty() and not student.is_empty():
				return "%s taught %s%s" % [teacher, student, " (%s)" % kt if not kt.is_empty() else ""]
			return "teaching succeeded"

		"teaching_failure":
			return "a teaching attempt failed"

		"social_bond_milestone":
			var an: String = str(e.get("a_name", "A"))
			var bn: String = str(e.get("b_name", "B"))
			return "%s and %s bond deepened" % [an, bn]

		"social_meeting":
			var ma: String = str(e.get("a_name", "A"))
			var mb: String = str(e.get("b_name", "B"))
			return "%s met %s" % [ma, mb]

		"governance_change":
			var g: String = str(e.get("governance_type", "anarchy")).replace("_", " ")
			return "governance became %s" % g

		"settlement_intent_shift":
			var old_i: String = str(e.get("old_intent", "?")).to_lower()
			var new_i: String = str(e.get("new_intent", "?")).to_lower()
			return "settlement intent shifted %s → %s" % [old_i, new_i]

		"authority_change":
			var nm: String = str(e.get("pawn_name", "someone")).strip_edges()
			var ctx: String = str(e.get("context", "")).replace("_", " ")
			return "%s gained %s authority" % [nm, ctx]

		"authority_points_added":
			return "authority recognized"

		"authority_vacuum":
			return "authority vacuum — no recognized leader"

		"diaspora_exile":
			var count: int = int(e.get("exile_count", 0))
			return "diaspora — %d pawns were exiled" % maxi(count, 1)

		"diaspora_grief":
			var nm: String = str(e.get("pawn_name", "someone")).strip_edges()
			return "%s grieved for their lost home" % nm

		"cultural_exposure":
			var nm: String = str(e.get("pawn_name", "someone")).strip_edges()
			var custom: String = str(e.get("custom_tag", "a custom")).replace("_", " ")
			return "%s absorbed a new custom: %s" % [nm, custom]

		"collapse_warning":
			return "collapse warning — settlement under strain"

		"environmental_degradation":
			return "environmental degradation detected"

		"economic_boom":
			return "economic boom — surplus detected"

		"market_crash":
			return "market crash — resources scarce"

		"religious_schism":
			return "religious schism — beliefs diverged"

		"religious_conversion":
			var nm: String = str(e.get("pawn_name", "someone")).strip_edges()
			return "%s underwent a religious conversion" % nm

		"sacred_site_established":
			return "a sacred site was established"

		"ritual_performed":
			return "a ritual was performed"

		"bloodline_founded":
			var nm: String = str(e.get("founder_name", "a founder")).strip_edges()
			return "%s founded a bloodline" % nm

		"bloodline_member_added":
			return "a bloodline gained a new member"

		"bloodline_extinct":
			var nm: String = str(e.get("bloodline_name", "a bloodline")).strip_edges()
			return "the %s bloodline went extinct" % nm

		"food_spoiled":
			return "food spoiled in storage"

		"seeds_planted":
			return "seeds were planted"

		"crop_harvested":
			return "crops were harvested"

		"starvation_event":
			return "starvation — settlement is hungry"

		"injury":
			var nm: String = str(e.get("pawn_name", "someone")).strip_edges()
			var body_part: String = str(e.get("body_part", "")).replace("_", " ")
			if not body_part.is_empty():
				return "%s was injured (%s)" % [nm, body_part]
			return "%s was injured" % nm

		"war_battle_spawned":
			return "enemies appeared — battle imminent"

		"war_proposed":
			return "war was proposed"

		"entity_decay":
			return "an entity began to decay"

		"entity_loss":
			return "an entity was lost"

		"collapse_metric_change":
			return "collapse metrics shifted"

		"emergent_pattern_detected":
			var pattern: String = str(e.get("pattern", "")).replace("_", " ")
			if not pattern.is_empty():
				return "emergent pattern: %s" % pattern
			return "emergent pattern detected"

		"historical_saturation":
			return "historical saturation — many events recorded"

		"player_intent":
			return "chronicler note recorded"

		"settlement_abandon":
			return "a settlement was abandoned"

		"settlement_revival":
			return "a settlement was revived"

		"settlement_rebirth":
			return "a settlement was reborn"

		"migration_started":
			return "migration began"

		"migration_completed":
			return "migration completed"

		"job_completed":
			# Too noisy for chronicle
			return ""

		# Craft events
		"tool_crafted":
			var tool: String = str(e.get("tool_type", "a tool")).replace("_", " ")
			return "a %s was crafted" % tool
		"tool_break":
			return "a tool broke"
		"food_cooked":
			return "food was cooked"
		"book_bound":
			return "a book was bound"
		"ink_made":
			return "ink was made"
		"paper_made":
			return "paper was made"
		"leather_tanned":
			return "leather was tanned"
		"pen_crafted":
			return "a pen was crafted"

		# Authority events
		"succession":
			var nm: String = str(e.get("new_leader_name", "someone")).strip_edges()
			return "%s assumed leadership" % nm
		"abdicate":
			var nm: String = str(e.get("pawn_name", "the leader")).strip_edges()
			return "%s abdicated" % nm
		"pledge_loyalty":
			var nm: String = str(e.get("pawn_name", "someone")).strip_edges()
			return "%s pledged loyalty" % nm
		"edict_issued":
			return "an edict was issued"
		"law_added":
			var law: String = str(e.get("law_type", "a law")).replace("_", " ")
			return "a new law was enacted: %s" % law
		"law_removed":
			return "a law was repealed"
		"ruler_decision":
			var decision: String = str(e.get("decision", "")).replace("_", " ")
			if not decision.is_empty():
				return "the ruler decided: %s" % decision
			return "the ruler made a decision"

		# Trade events
		"trade_route_started":
			return "a trade route was opened"
		"trade_route_completed":
			return "a trade route was completed"

		# Conflict events
		"grudge_formed":
			var an: String = str(e.get("pawn_name", "someone")).strip_edges()
			return "%s formed a grudge" % an
		"grudge_inherited":
			var nm: String = str(e.get("pawn_name", "someone")).strip_edges()
			return "%s inherited a grudge" % nm

		# Legacy events
		"legacy_record":
			var nm: String = str(e.get("pawn_name", "someone")).strip_edges()
			return "%s left a legacy" % nm
		"life_path_milestone":
			return ""  # too noisy
		"life_path_switch":
			return ""  # too noisy
		"bloodline_extinct":
			var nm: String = str(e.get("bloodline_name", "a bloodline")).strip_edges()
			return "the %s bloodline went extinct" % nm

		# Culture events
		"cultural_building":
			return "a cultural building was raised"
		"cultural_exposure":
			var nm: String = str(e.get("pawn_name", "someone")).strip_edges()
			var custom: String = str(e.get("custom_tag", "a custom")).replace("_", " ")
			return "%s absorbed a new custom: %s" % [nm, custom]

		# Settlement events
		"settlement_collapse":
			return "a settlement collapsed"
		"settlement_new_foundation":
			return "a new settlement was founded"
		"settlement_revival_with_lineage":
			return "a settlement was revived with lineage memory"
		"famine_warning":
			return "famine warning — food reserves critical"

		# Building subtypes
		"hearth_built":
			return "a hearth was built"
		"storage_built":
			return "storage was built"
		"shrine_built":
			return "a shrine was built"
		"marker_built":
			return "a marker was placed"
		"cooperative_build":
			return "crews raised new structures together"

		# Knowledge events
		"skill_gain":
			return ""  # too noisy

		# World events
		"macro_festival":
			return "a festival was held"
		"macro_unrest":
			return "unrest spread across the region"
		"region_discovery":
			return ""  # too noisy

		_:
			# Surface rare settlement/world events
			if typ.begins_with("settlement") or typ.contains("abandon") or typ.contains("revival") or typ.contains("rebirth"):
				return typ.replace("_", " ")
			return ""
