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
const SUMMARY_INTERVAL_TICKS: int = 600  # ~1 in-game day — compose a world summary

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
var _last_summary_tick: int = -9999
var _summary_deaths: int = 0
var _summary_births: int = 0
var _summary_teaching: int = 0
var _summary_builds: int = 0
var _summary_grudges: int = 0
var _summary_innovations: int = 0
var _toast_scene: PackedScene = null
var _toast_container: VBoxContainer
var _last_toast_tick: int = -9999
const TOAST_COOLDOWN_TICKS: int = 120  # Don't spam toasts


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

	# Toast container — top-center for important event popups
	_toast_container = VBoxContainer.new()
	_toast_container.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast_container.offset_left = -160
	_toast_container.offset_right = 160
	_toast_container.offset_top = 10
	_toast_container.offset_bottom = 200
	_toast_container.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(_toast_container)

	# Load toast scene
	_toast_scene = load("res://scenes/ui/EventToast.tscn")


func _on_tick(tick: int) -> void:
	if not _visible:
		return
	var refresh_stride: int = _refresh_stride_for_speed(GameManager.game_speed)
	if tick % refresh_stride != 0 and _last_seen_event_count > 0:
		return
	# Track event counts and check for toasts in one pass
	var events: Array = []
	if WorldMemory != null:
		events = WorldMemory.get_recent_events(128)
	_track_and_toast_events(events, tick)
	# Compose periodic world summary
	if tick - _last_summary_tick >= SUMMARY_INTERVAL_TICKS and tick > 100:
		_compose_world_summary(tick)
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
			"first_hearth_in_polity", "settlement_abandoned",
			"diaspora_exile", "migration_started", "migration_completed",
			"polity_founded", "settlement_formalized", "territorial_growth"]:
		return COLOR_SETTLEMENT
	# World
	if typ in ["collapse_warning", "environmental_degradation", "economic_boom", "market_crash",
			"sacred_site_established", "ritual_performed", "religious_schism", "religious_conversion",
			"emergent_pattern_detected", "historical_saturation", "collapse_metric_change",
			"entity_decay", "entity_loss", "chronicle_summary"]:
		return COLOR_WORLD
	# Conflict
	if typ in ["war_battle_spawned", "war_proposed", "skirmish_started", "battle_resolved", "injury", "social_fragment", "social_schism",
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
	if typ in ["trade_route_started", "trade_route_completed", "trade_route_opened", "macro_unrest"]:
		return COLOR_TRADE
	# AI Ecosystem
	if typ in ["ai_migration_wave", "ai_wildlife_boom", "ai_wildlife_bust",
			"ai_climate_shift", "ai_resource_depletion"]:
		return COLOR_WORLD
	if typ in ["ai_plague_outbreak", "ai_natural_disaster"]:
		return COLOR_CONFLICT
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


## Human-readable text for an event type — narrative composition
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
				return "%s was born to %s and %s" % [child_name, pa, pb]
			return "%s was born" % child_name

		"pawn_death":
			return _pawn_death_chronicle_line(e)

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
			return "%s raised %s%s" % [worker, job_name.to_lower(), loc]

		"cooperative_build":
			var worker: String = str(e.get("worker_name", "")).strip_edges()
			var nearby: int = int(e.get("nearby_workers", 0))
			if worker.is_empty():
				worker = "a crew"
			var crew: String = " alongside %d others" % nearby if nearby > 1 else ""
			return "%s raised a structure together%s" % [worker, crew]

		"knowledge_discovery":
			var kt: String = str(e.get("knowledge_type", "?")).replace("_", " ")
			var discoverer: String = str(e.get("pawn_name", "someone")).strip_edges()
			if discoverer.is_empty(): discoverer = "someone"
			return "%s discovered the art of %s" % [discoverer, kt]

		"knowledge_rediscovery":
			var kt: String = str(e.get("knowledge_type", "lost knowledge")).replace("_", " ")
			return "the art of %s, long lost, was rediscovered" % kt

		"knowledge_sealed":
			var nm: String = str(e.get("carrier_name", "a scholar")).strip_edges()
			var kt: String = str(e.get("knowledge_type", "")).strip_edges().replace("_", " ")
			if not kt.is_empty():
				return "%s died carrying the knowledge of %s — unfulfilled teaching obligations" % [nm, kt]
			return "%s died with unfulfilled teaching obligations" % nm

		"knowledge_lost":
			var kt: String = str(e.get("knowledge_type", "knowledge")).strip_edges().replace("_", " ")
			return "the knowledge of %s was lost to the settlement" % kt

		"knowledge_at_risk":
			var kt: String = str(e.get("knowledge_type", "knowledge")).strip_edges().replace("_", " ")
			var carrier: String = str(e.get("carrier_name", "")).strip_edges()
			if not carrier.is_empty():
				return "%s is the last carrier of %s — if they fall, it dies with them" % [carrier, kt]
			return "%s is at risk — only one carrier remains" % kt

		"knowledge_crisis":
			return "knowledge crisis — multiple skills at risk of being lost forever"

		"teaching_success":
			var teacher: String = str(e.get("teacher_name", "A")).strip_edges()
			var student: String = str(e.get("student_name", "B")).strip_edges()
			var kt: String = str(e.get("knowledge_type", "")).strip_edges().replace("_", " ")
			if not teacher.is_empty() and not student.is_empty():
				if not kt.is_empty():
					return "%s taught %s the art of %s" % [teacher, student, kt]
				return "%s passed knowledge to %s" % [teacher, student]
			return "teaching succeeded"

		"teaching_failure":
			return "a teaching attempt failed — the knowledge did not take hold"

		"social_bond_milestone":
			var an: String = str(e.get("a_name", "A"))
			var bn: String = str(e.get("b_name", "B"))
			return "%s and %s grew closer" % [an, bn]

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
			return "settlement ambition shifted from %s to %s" % [old_i, new_i]

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
			return "diaspora — %d HeelKawnians were exiled from their home" % maxi(count, 1)

		"diaspora_grief":
			var nm: String = str(e.get("pawn_name", "someone")).strip_edges()
			return "%s grieved for their lost home" % nm

		"cultural_exposure":
			var nm: String = str(e.get("pawn_name", "someone")).strip_edges()
			var custom: String = str(e.get("custom_tag", "a custom")).replace("_", " ")
			return "%s absorbed a new custom: %s" % [nm, custom]

		"collapse_warning":
			return "collapse warning — the settlement is under strain"

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
			var count: int = int(e.get("death_count", 0))
			if count > 1:
				return "starvation — %d HeelKawnians perished when the stockpile ran empty" % count
			return "starvation — the settlement is hungry"

		"injury":
			var nm: String = str(e.get("pawn_name", "someone")).strip_edges()
			var body_part: String = str(e.get("body_part", "")).replace("_", " ")
			if not body_part.is_empty():
				return "%s was injured — %s" % [nm, body_part]
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
			var crafter: String = str(e.get("pawn_name", "")).strip_edges()
			if not crafter.is_empty():
				return "%s crafted %s" % [crafter, tool]
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
			var nm: String = str(e.get("new_leader_name", "")).strip_edges()
			var pol: String = str(e.get("polity_name", "the realm")).strip_edges()
			if nm.is_empty():
				return "new leadership in %s" % pol
			return "%s assumed leadership of %s" % [nm, pol]
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
			var desc: String = str(e.get("law_description", "")).strip_edges()
			var pol: String = str(e.get("polity_name", "the realm")).strip_edges()
			if not desc.is_empty():
				return "%s enacted: %s — %s" % [pol, law, desc]
			return "%s enacted: %s" % [pol, law]
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
			var target: String = str(e.get("target_name", "")).strip_edges()
			var reason: String = str(e.get("reason", "")).replace("_", " ")
			if not target.is_empty():
				if not reason.is_empty():
					return "%s swore a grudge against %s — %s" % [an, target, reason]
				return "%s swore a grudge against %s" % [an, target]
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

		# Settlement / map polity events
		"polity_founded", "settlement_formalized":
			var founding_narr: String = str(e.get("narrative", "")).strip_edges()
			if not founding_narr.is_empty():
				return founding_narr
			var polity_nm: String = str(e.get("polity_name", "a people")).strip_edges()
			return "the %s declared themselves a realm" % polity_nm
		"territorial_growth":
			var growth_narr: String = str(e.get("narrative", "")).strip_edges()
			if not growth_narr.is_empty():
				return growth_narr
			var grow_nm: String = str(e.get("polity_name", "a realm")).strip_edges()
			return "the borders of %s grew" % grow_nm

		# Settlement events
		"settlement_collapse":
			return "a settlement collapsed"
		"settlement_new_foundation":
			return "a new settlement was founded"
		"settlement_revival_with_lineage":
			return "a settlement was revived with lineage memory"
		"famine_warning":
			var fp: float = float(e.get("food_pressure", 0.0))
			var sf: int = int(e.get("stock_food", -1))
			if sf >= 0:
				return "famine warning — food pressure %.0f%% (%d in stockpiles)" % [fp * 100.0, sf]
			return "famine warning — food pressure %.0f%%" % [fp * 100.0]
		"first_hearth_in_polity":
			var pol: String = str(e.get("polity_name", "the realm")).strip_edges()
			var who: String = str(e.get("pawn_name", "someone")).strip_edges()
			return "%s lit the first hearth of %s" % [who, pol]
		"settlement_abandoned":
			var sn: String = str(e.get("settlement_name", e.get("polity_name", "a settlement"))).strip_edges()
			var why: String = str(e.get("reason", "")).replace("_", " ").strip_edges()
			if not why.is_empty():
				return "%s was abandoned — %s" % [sn, why]
			return "%s was abandoned" % sn
		"profession_mastered":
			var who: String = str(e.get("pawn_name", "someone")).strip_edges()
			var prof: String = str(e.get("profession", "laborer")).strip_edges()
			var branch: String = str(e.get("branch_skill", "")).strip_edges().replace("_", " ")
			var tier: String = str(e.get("tier", "skill")).strip_edges()
			if not branch.is_empty():
				return "%s mastered %s %s as a %s" % [who, tier, branch, prof]
			return "%s reached %s mastery as a %s" % [who, tier, prof]

		"dynasty_line":
			var line: String = str(e.get("narrative", "")).strip_edges()
			if not line.is_empty():
				return line
			var child: String = str(e.get("pawn_name", "a child")).strip_edges()
			var pa: String = str(e.get("parent_a_name", "")).strip_edges()
			var pb: String = str(e.get("parent_b_name", "")).strip_edges()
			if not pa.is_empty() and not pb.is_empty():
				return "%s was born to %s and %s" % [child, pa, pb]
			return "%s joined the dynasty" % child

		"diplomatic_incident":
			var na: String = str(e.get("polity_a_name", "one realm")).strip_edges()
			var nb: String = str(e.get("polity_b_name", "another")).strip_edges()
			return "diplomatic incident — %s and %s cross into open hostility" % [na, nb]

		"skirmish_started":
			var nar: String = str(e.get("narrative", "")).strip_edges()
			if not nar.is_empty():
				return nar
			var fa: String = str(e.get("faction_a_name", "one band")).strip_edges()
			var fb: String = str(e.get("faction_b_name", "another")).strip_edges()
			var pc: int = int(e.get("pawn_count", 0))
			var tile_d: Dictionary = e.get("tile", {}) as Dictionary
			var loc: String = ""
			if tile_d.has("x") and tile_d.has("y"):
				loc = " at (%d,%d)" % [int(tile_d.get("x", 0)), int(tile_d.get("y", 0))]
			if pc > 0:
				return "skirmish%s — %s vs %s (%d warriors)" % [loc, fa, fb, pc]
			return "skirmish%s — %s vs %s" % [loc, fa, fb]

		"battle_resolved":
			var ba: String = str(e.get("faction_a_name", "one band")).strip_edges()
			var bb: String = str(e.get("faction_b_name", "another")).strip_edges()
			var ca: int = int(e.get("casualties_a", 0))
			var cb: int = int(e.get("casualties_b", 0))
			var wounded_n: int = (e.get("wounded_pawn_ids", []) as Array).size()
			var win: String = str(e.get("winner_name", "")).strip_edges()
			if not win.is_empty():
				return "aftermath — %s held the field against %s (%d wounded)" % [win, bb if win == ba else ba, wounded_n]
			return "aftermath — %s vs %s (%d hurt on each side, %d wounded)" % [ba, bb, ca + cb, wounded_n]

		"trade_route_opened":
			var ta: String = str(e.get("polity_a_name", "one realm")).strip_edges()
			var tb: String = str(e.get("polity_b_name", "another")).strip_edges()
			return "trade opens between %s and %s" % [ta, tb]

		"officer_promoted":
			var pn: String = str(e.get("pawn_name", "a warrior")).strip_edges()
			var nr: String = str(e.get("new_rank", "officer")).strip_edges()
			return "%s rose to %s after the clash" % [pn, nr]

		"polity_merged":
			var nar: String = str(e.get("narrative", "")).strip_edges()
			if not nar.is_empty():
				return nar
			var keep: String = str(e.get("polity_name", "one realm")).strip_edges()
			var lost: String = str(e.get("absorbed_name", "another")).strip_edges()
			return "%s absorbed %s" % [keep, lost]

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

		# Combat / danger events
		"battle_started":
			return "a battle began"
		"battle_ended":
			return "a battle ended"
		"battle_report":
			return "a battle was reported"
		"pawn_injured":
			return "a pawn was injured"

		# Memorial / death events
		"memorial_created":
			return "a memorial was created"
		"death_recorded":
			return "a death was recorded"

		# Social events
		"gossip_spread":
			return ""  # too noisy

		# Chronicle summary — periodic world state
		"chronicle_summary":
			var summary: String = str(e.get("summary", "")).strip_edges()
			if not summary.is_empty():
				return "[b]— %s —[/b]" % summary
			return ""

		# AI Ecosystem events
		"ai_migration_wave":
			var species: String = str(e.get("species", "wildlife")).strip_edges()
			var region: String = str(e.get("region", "the region")).strip_edges()
			var reason: String = str(e.get("reason", "seasonal shift")).strip_edges()
			return "%s migrating to %s (%s)" % [species, region, reason]
		"ai_resource_depletion":
			var resource: String = str(e.get("resource", "resources")).strip_edges()
			var region: String = str(e.get("region", "the region")).strip_edges()
			return "%s depleted in %s" % [resource, region]
		"ai_climate_shift":
			var shift_type: String = str(e.get("shift_type", "climate shift")).strip_edges()
			var severity: String = str(e.get("severity", "moderate")).strip_edges()
			return "%s (%s)" % [shift_type, severity]
		"ai_wildlife_boom":
			var species: String = str(e.get("species", "wildlife")).strip_edges()
			var region: String = str(e.get("region", "the region")).strip_edges()
			return "%s population surging in %s" % [species, region]
		"ai_wildlife_bust":
			var species: String = str(e.get("species", "wildlife")).strip_edges()
			var region: String = str(e.get("region", "the region")).strip_edges()
			return "%s population crashing in %s" % [species, region]
		"ai_plague_outbreak":
			var plague_type: String = str(e.get("plague_type", "disease")).strip_edges()
			var region: String = str(e.get("region", "the region")).strip_edges()
			return "%s plague spreading in %s" % [plague_type, region]
		"ai_natural_disaster":
			var disaster_type: String = str(e.get("disaster_type", "disaster")).strip_edges()
			var region: String = str(e.get("region", "the region")).strip_edges()
			return "%s strikes %s" % [disaster_type, region]

		_:
			# Surface rare settlement/world events
			if typ.begins_with("settlement") or typ.contains("abandon") or typ.contains("revival") or typ.contains("rebirth"):
				return typ.replace("_", " ")
			return ""


## Track events for summary + check for toast-worthy events in one pass
func _track_and_toast_events(events: Array, tick: int) -> void:
	if events.is_empty():
		return
	var toast_text: String = ""
	for e_any in events:
		if not e_any is Dictionary:
			continue
		var e: Dictionary = e_any as Dictionary
		var e_tick: int = int(e.get("tick", 0))
		# Summary tracking
		if e_tick > _last_summary_tick:
			var typ: String = str(e.get("type", ""))
			if typ == "pawn_death" or typ == "starvation_event":
				_summary_deaths += 1
			elif typ == "birth" or typ == "pawn_birth":
				_summary_births += 1
			elif typ == "teaching_success":
				_summary_teaching += 1
			elif typ == "structure_built" or typ == "hearth_built" or typ == "storage_built" or typ == "shrine_built":
				_summary_builds += 1
			elif typ == "grudge_formed":
				_summary_grudges += 1
			elif typ == "knowledge_discovery" or typ == "knowledge_rediscovery":
				_summary_innovations += 1
		# Toast checking (only if we haven't found one yet)
		if toast_text.is_empty() and e_tick > _last_toast_tick:
			var typ: String = str(e.get("type", ""))
			match typ:
				"knowledge_at_risk":
					var kt: String = str(e.get("knowledge_type", "knowledge")).replace("_", " ")
					var carrier: String = str(e.get("carrier_name", "")).strip_edges()
					if not carrier.is_empty():
						toast_text = "%s is the last carrier of %s" % [carrier, kt]
					else:
						toast_text = "%s is at risk — only one carrier remains" % kt
				"knowledge_crisis":
					toast_text = "Knowledge crisis — multiple skills at risk"
				"knowledge_lost":
					var kt: String = str(e.get("knowledge_type", "knowledge")).replace("_", " ")
					toast_text = "The knowledge of %s has been lost" % kt
				"knowledge_discovery":
					var kt: String = str(e.get("knowledge_type", "")).replace("_", " ")
					var discoverer: String = str(e.get("pawn_name", "")).strip_edges()
					if not discoverer.is_empty() and not kt.is_empty():
						toast_text = "%s discovered %s" % [discoverer, kt]
					elif not kt.is_empty():
						toast_text = "New knowledge discovered: %s" % kt
				"grudge_formed":
					var an: String = str(e.get("pawn_name", "")).strip_edges()
					var target: String = str(e.get("target_name", "")).strip_edges()
					if not an.is_empty() and not target.is_empty():
						toast_text = "%s swore a grudge against %s" % [an, target]
				"starvation_event":
					toast_text = "Starvation — the settlement is hungry"
				"famine_warning":
					toast_text = "Famine warning — food reserves critical"
				"settlement_collapse":
					toast_text = "A settlement has collapsed"
				"settlement_new_foundation":
					toast_text = "A new settlement was founded"
				"social_schism":
					toast_text = "Social schism — a community has fractured"
	# Spawn toast if found
	if not toast_text.is_empty() and tick - _last_toast_tick >= TOAST_COOLDOWN_TICKS:
		_spawn_toast(toast_text)
		_last_toast_tick = tick


## Compose a world summary and inject it as a chronicle event
func _compose_world_summary(tick: int) -> void:
	var parts: PackedStringArray = []

	# Population snapshot
	var pop: int = 0
	var sp: Node = get_tree().get_root().get_node_or_null("Main")
	if sp != null:
		sp = sp.get_node_or_null("WorldViewport/PawnSpawner")
	if sp != null and sp.has_method("get_all_pawns"):
		pop = sp.get_all_pawns().size()

	# Settlement count
	var settlement_count: int = 0
	if SettlementMemory != null and SettlementMemory.has_method("get_settlements"):
		settlement_count = SettlementMemory.get_formal_settlement_count()

	# Knowledge at risk
	var at_risk_count: int = 0
	if KnowledgeSystem != null and KnowledgeSystem.has_method("get_dormant_knowledge_types"):
		at_risk_count = KnowledgeSystem.get_dormant_knowledge_types().size()

	# Compose narrative
	if _summary_deaths > 0:
		if _summary_deaths >= 3:
			parts.append("%d perished" % _summary_deaths)
		else:
			parts.append("%d died" % _summary_deaths)
	if _summary_births > 0:
		parts.append("%d born" % _summary_births)
	if _summary_teaching > 0:
		parts.append("%d lessons taught" % _summary_teaching)
	if _summary_builds > 0:
		parts.append("%d structures raised" % _summary_builds)
	if _summary_grudges > 0:
		parts.append("%d grudge%s formed" % [_summary_grudges, "s" if _summary_grudges > 1 else ""])
	if _summary_innovations > 0:
		parts.append("%d innovation%s" % [_summary_innovations, "s" if _summary_innovations > 1 else ""])
	if at_risk_count > 0:
		parts.append("%d knowledge%s at risk" % [at_risk_count, "s" if at_risk_count > 1 else ""])

	# Reset counters
	_summary_deaths = 0
	_summary_births = 0
	_summary_teaching = 0
	_summary_builds = 0
	_summary_grudges = 0
	_summary_innovations = 0
	_last_summary_tick = tick

	if parts.is_empty():
		return

	# Inject as a summary event into WorldMemory
	var day: int = tick / 600 if tick > 0 else 0
	var summary_text: String = ""
	if pop > 0:
		summary_text = "Pop %d · %s" % [pop, ", ".join(parts)]
	else:
		summary_text = ", ".join(parts)

	if settlement_count > 0:
		summary_text = "%d settlement%s · %s" % [settlement_count, "s" if settlement_count > 1 else "", summary_text]

	# Record as a special chronicle event
	if WorldMemory != null and WorldMemory.has_method("record_event"):
		WorldMemory.record_event({
			"type": "chronicle_summary",
			"tick": tick,
			"summary": summary_text,
		})


## Deterministic pawn_death line from recorded facts (WorldMemory.record_pawn_death).
static func _pawn_death_chronicle_line(e: Dictionary) -> String:
	var nm: String = str(e.get("n", e.get("name", "someone"))).strip_edges()
	if nm.is_empty():
		nm = "someone"
	var cause: String = str(e.get("cause", e.get("c", ""))).strip_edges()
	var age_y: int = int(e.get("age_years", -1))
	var settlement: String = str(e.get("settlement_name", "")).strip_edges()
	var killer: String = str(e.get("killer_name", "")).strip_edges()
	var profession: String = str(e.get("profession", "")).strip_edges()
	var knowledge_lost: bool = bool(e.get("knowledge_lost", false))
	var lost_knowledge: String = str(e.get("lost_knowledge_type", "")).strip_edges()
	var lead: String = nm
	if not profession.is_empty() and profession != "None":
		lead = "%s the %s" % [nm, profession]
	var tail_parts: PackedStringArray = PackedStringArray()
	if age_y >= 0:
		tail_parts.append("age %d" % age_y)
	if not settlement.is_empty():
		tail_parts.append("of %s" % settlement)
	var tail: String = ""
	if not tail_parts.is_empty():
		tail = " (%s)" % ", ".join(tail_parts)
	var obit: String = str(e.get("obituary_narrative", "")).strip_edges()
	if not obit.is_empty():
		return obit
	var lw: String = str(e.get("last_words", "")).strip_edges()
	if not killer.is_empty():
		var line: String = "%s was slain by %s%s" % [lead, killer, tail]
		if not lw.is_empty():
			line += " — \"%s\"" % lw
		return line
	if not cause.is_empty():
		var line2: String = "%s died of %s%s" % [lead, cause.replace("_", " "), tail]
		if not lw.is_empty():
			line2 += " — \"%s\"" % lw
		return line2
	if knowledge_lost and not lost_knowledge.is_empty():
		return "%s died%s — knowledge of %s was lost" % [lead, tail, lost_knowledge.replace("_", " ")]
	return "%s died%s" % [lead, tail]


func _spawn_toast(text: String) -> void:
	if _toast_scene == null or _toast_container == null:
		return
	# Safety cap: don't accumulate more than 3 toasts
	while _toast_container.get_child_count() >= 3:
		var oldest: Node = _toast_container.get_child(0)
		oldest.queue_free()
	var toast: Node = _toast_scene.instantiate()
	if toast == null:
		return
	_toast_container.add_child(toast)
	if toast.has_method("setup"):
		toast.setup(text)
