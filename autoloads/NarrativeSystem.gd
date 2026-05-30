extends Node
## NarrativeSystem — story thread generation from world events.
##
## Scans WorldMemory for clusters of related events every 5000 ticks and
## weaves them into narrative threads. Each thread tracks tension,
## resolution progress, and involved pawns/settlements.
##
## Story types: migration, war, romance, betrayal, discovery, cataclysm,
## founding, rise_fall, rivalry, alliance, mystery, tragedy.
##
## Integrates with LegendSystem for myth formation from exceptional
## thread resolutions, and EventBus for decoupled event response.

const SCAN_INTERVAL: int = 5000
const MAX_ACTIVE_THREADS: int = 5
const COOLDOWN_PER_SETTLEMENT: int = 5000
const TENSION_MIN_START: int = 30
const TENSION_MAX_START: int = 70
const TENSION_DECAY_IF_STALE: int = 10000
const STALE_RESOLVE_TENSION: float = 15.0
const HARD_STALE_TICKS: int = 100000
const LEGEND_TENSION_THRESHOLD: int = 90
const MAX_EVENTS_PER_THREAD: int = 50
const MAX_ARCHIVED_THREADS: int = 200
const PAWN_EXCEPTIONAL_KILLS: int = 10
const PAWN_LEGACY_SCORE_THRESHOLD: float = 60.0
const ARC_DETECTION_WINDOW: int = 50000

enum ThreadStatus { ACTIVE = 0, RESOLVED = 1, ARCHIVED = 2 }

enum StoryType {
	MIGRATION = 0,
	WAR = 1,
	ROMANCE = 2,
	BETRAYAL = 3,
	DISCOVERY = 4,
	CATACLYSM = 5,
	FOUNDING = 6,
	RISE_FALL = 7,
	RIVALRY = 8,
	ALLIANCE = 9,
	MYSTERY = 10,
	TRAGEDY = 11,
}

const STORY_TYPE_NAMES: Dictionary = {
	StoryType.MIGRATION: "migration",
	StoryType.WAR: "war",
	StoryType.ROMANCE: "romance",
	StoryType.BETRAYAL: "betrayal",
	StoryType.DISCOVERY: "discovery",
	StoryType.CATACLYSM: "cataclysm",
	StoryType.FOUNDING: "founding",
	StoryType.RISE_FALL: "rise_fall",
	StoryType.RIVALRY: "rivalry",
	StoryType.ALLIANCE: "alliance",
	StoryType.MYSTERY: "mystery",
	StoryType.TRAGEDY: "tragedy",
}

const STORY_TYPE_FROM_EVENT: Dictionary = {
	"migration_started": StoryType.MIGRATION,
	"migration_completed": StoryType.MIGRATION,
	"war_declared": StoryType.WAR,
	"war_proposed": StoryType.WAR,
	"battle": StoryType.WAR,
	"battle_resolved": StoryType.WAR,
	"skirmish_started": StoryType.WAR,
	"romance": StoryType.ROMANCE,
	"marriage": StoryType.ROMANCE,
	"betrayal": StoryType.BETRAYAL,
	"betrayed": StoryType.BETRAYAL,
	"discovery": StoryType.DISCOVERY,
	"region_discovery": StoryType.DISCOVERY,
	"cataclysm_started": StoryType.CATACLYSM,
	"disaster_started": StoryType.CATACLYSM,
	"settlement_founded": StoryType.FOUNDING,
	"polity_founded": StoryType.FOUNDING,
	"rise_fall": StoryType.RISE_FALL,
	"settlement_collapse": StoryType.RISE_FALL,
	"rivalry": StoryType.RIVALRY,
	"grudge_formed": StoryType.RIVALRY,
	"diplomatic_incident": StoryType.RIVALRY,
	"alliance": StoryType.ALLIANCE,
	"trade_route_started": StoryType.ALLIANCE,
	"mystery": StoryType.MYSTERY,
	"knowledge_lost": StoryType.MYSTERY,
	"death": StoryType.TRAGEDY,
	"pawn_death": StoryType.TRAGEDY,
	"heroic_death": StoryType.TRAGEDY,
}

class NarrativeThread:
	var title: String
	var description: String
	var type: int
	var involved_pawns: Array[int]
	var involved_settlements: Array[int]
	var events: Array[Dictionary]
	var tension: float
	var resolution_progress: float
	var tick_started: int
	var tick_last_update: int
	var status: int
	var resolution_summary: String

	func _init(
			p_title: String,
			p_description: String,
			p_type: int,
			p_pawns: Array[int],
			p_settlements: Array[int],
			p_tick: int
	):
		title = p_title
		description = p_description
		type = p_type
		involved_pawns = p_pawns.duplicate()
		involved_settlements = p_settlements.duplicate()
		events = []
		tension = 0.0
		resolution_progress = 0.0
		tick_started = p_tick
		tick_last_update = p_tick
		status = ThreadStatus.ACTIVE
		resolution_summary = ""

var _threads: Array[NarrativeThread] = []
var _archived_threads: Array[NarrativeThread] = []
var _last_scan_tick: int = -999999
var _settlement_last_thread_tick: Dictionary = {}
var _stats: Dictionary = {
	"threads_generated": 0,
	"threads_resolved": 0,
	"threads_archived": 0,
	"tension_peaks": 0,
	"legends_spawned": 0,
}

signal thread_generated(title: String, type_name: String, involved_settlements: Array[int])
signal thread_tension_changed(title: String, old_tension: float, new_tension: float)
signal thread_resolved(title: String, resolution_summary: String, type_name: String)
signal thread_archived(title: String)

func _ready() -> void:
	if GameManager != null and GameManager.game_tick.is_connected(_on_game_tick):
		return
	if GameManager != null:
		GameManager.game_tick.connect(_on_game_tick)
	_bind_eventbus()

func _bind_eventbus() -> void:
	var eb := get_node_or_null("/root/EventBus")
	if eb == null or not eb.has_method("subscribe"):
		return
	eb.call("subscribe", "pawn_died", self, "_on_pawn_died")
	eb.call("subscribe", "settlement_founded", self, "_on_settlement_founded")
	eb.call("subscribe", "war_declared", self, "_on_war_declared")
	eb.call("subscribe", "disaster_started", self, "_on_disaster_started")

func _on_game_tick(tick: int) -> void:
	if tick - _last_scan_tick < SCAN_INTERVAL:
		return
	_last_scan_tick = tick
	_scan_world_memory(tick)
	_decay_stale_tension(tick)
	_check_arc_resolutions(tick)

func _on_pawn_died(payload: Dictionary) -> void:
	var pid: int = int(payload.get("pawn_id", -1))
	if pid < 0:
		return
	var tick: int = int(payload.get("tick", 0))
	for t in _threads:
		if t.status != ThreadStatus.ACTIVE:
			continue
		if pid in t.involved_pawns:
			_adjust_tension(t, 10.0 + t.tension * 0.05, tick)
	_check_pawn_tragedy_thread(payload)

func _on_settlement_founded(payload: Dictionary) -> void:
	var sid: int = int(payload.get("settlement_id", payload.get("center", -1)))
	if sid < 0:
		return
	var tick: int = int(payload.get("tick", 0))
	if not _can_create_for_settlement(sid, tick):
		return
	_register_settlement_thread_cooldown(sid, tick)
	var founder_id: int = int(payload.get("founder_id", -1))
	var name_str: String = str(payload.get("name", "New Settlement"))
	if _count_active_threads_for_settlement(sid) >= 3:
		return
	var pawns: Array[int] = [founder_id] if founder_id >= 0 else []
	_generate_thread(
		"Founding of %s" % name_str,
		"Brave pioneers established a new settlement in the wilderness.",
		StoryType.FOUNDING,
		pawns,
		[sid],
		tick
	)

func _on_war_declared(payload: Dictionary) -> void:
	var aggressor_sid: int = int(payload.get("aggressor_settlement", -1))
	var defender_sid: int = int(payload.get("defender_settlement", -1))
	var agg_id: int = int(payload.get("aggressor_id", -1))
	var def_id: int = int(payload.get("defender_id", -1))
	var tick: int = int(payload.get("tick", 0))
	var existing: NarrativeThread = _find_existing_war_thread(aggressor_sid, defender_sid)
	if existing != null:
		_adjust_tension(existing, 15.0, tick)
		return
	var agg_name: String = str(payload.get("aggressor", "Unknown"))
	if _count_active_threads() >= MAX_ACTIVE_THREADS:
		return
	var pawns: Array[int] = []
	if agg_id >= 0:
		pawns.append(agg_id)
	if def_id >= 0:
		pawns.append(def_id)
	var settlements: Array[int] = []
	if aggressor_sid >= 0:
		settlements.append(aggressor_sid)
	if defender_sid >= 0:
		settlements.append(defender_sid)
	if settlements.is_empty():
		return
	_generate_thread(
		"The %s Conflict" % agg_name,
		"War has erupted, engulfing the lands in conflict.",
		StoryType.WAR,
		pawns,
		settlements,
		tick
	)

func _on_disaster_started(payload: Dictionary) -> void:
	var sid: int = int(payload.get("settlement_id", -1))
	var tick: int = int(payload.get("tick", 0))
	var name_str: String = str(payload.get("name", "Cataclysm"))
	var severity: int = int(payload.get("severity", 0))
	if severity < 5:
		return
	var pawns: Array[int] = []
	var pid: int = int(payload.get("pawn_id", -1))
	if pid >= 0:
		pawns.append(pid)
	var settlements: Array[int] = []
	if sid >= 0:
		settlements.append(sid)
	if _count_active_threads() >= MAX_ACTIVE_THREADS:
		return
	_generate_thread(
		"The Great %s" % name_str,
		"A catastrophic disaster reshapes the world.",
		StoryType.CATACLYSM,
		pawns,
		settlements,
		tick
	)

func _scan_world_memory(tick: int) -> void:
	var wm := get_node_or_null("/root/WorldMemory")
	if wm == null or not wm.has_method("get_recent_events"):
		return
	var recent: Array = wm.call("get_recent_events", 2000)
	if recent.is_empty():
		return
	var event_clusters: Dictionary = _cluster_events(recent, tick)
	for cluster_key in event_clusters:
		var cluster: Dictionary = event_clusters[cluster_key]
		var settlement_id: int = int(cluster.get("settlement_id", -1))
		if settlement_id >= 0 and not _can_create_for_settlement(settlement_id, tick):
			continue
		if _count_active_threads() >= MAX_ACTIVE_THREADS:
			break
		_thread_from_cluster(cluster, tick)

func _cluster_events(events: Array, tick: int) -> Dictionary:
	var clusters: Dictionary = {}
	for ev in events:
		if not (ev is Dictionary):
			continue
		var ev_dict: Dictionary = ev as Dictionary
		var ev_type: String = str(ev_dict.get("type", ""))
		if ev_type.is_empty():
			continue
		var ev_tick: int = int(ev_dict.get("t", int(ev_dict.get("tick", 0))))
		if tick - ev_tick > SCAN_INTERVAL:
			continue
		var mapped_type: int = STORY_TYPE_FROM_EVENT.get(ev_type, -1)
		if mapped_type < 0:
			continue
		var settlement_id: int = int(ev_dict.get("settlement_id", ev_dict.get("center", -1)))
		if settlement_id < 0:
			var rid: int = int(ev_dict.get("r", -1))
			if rid >= 0:
				settlement_id = rid
		if settlement_id < 0:
			continue
		var cluster_key: String = "%d_%d" % [mapped_type, settlement_id]
		if not clusters.has(cluster_key):
			var pawns: Array[int] = []
			var pid: int = int(ev_dict.get("pawn_id", ev_dict.get("pid", -1)))
			if pid >= 0:
				pawns.append(pid)
			clusters[cluster_key] = {
				"type": mapped_type,
				"settlement_id": settlement_id,
				"pawns": pawns,
				"events": [ev_dict],
				"count": 1,
			}
		else:
			var c: Dictionary = clusters[cluster_key]
			c["count"] = int(c.get("count", 0)) + 1
			var evs: Array = c.get("events", [])
			if evs.size() < MAX_EVENTS_PER_THREAD:
				evs.append(ev_dict)
			var pid_: int = int(ev_dict.get("pawn_id", ev_dict.get("pid", -1)))
			if pid_ >= 0:
				var p_arr: Array = c.get("pawns", [])
				if not pid_ in p_arr:
					p_arr.append(pid_)
	return clusters

func _thread_from_cluster(cluster: Dictionary, tick: int) -> void:
	var stype: int = int(cluster.get("type", StoryType.MYSTERY))
	var settlement_id: int = int(cluster.get("settlement_id", -1))
	var pawns: Array = cluster.get("pawns", [])
	var count: int = int(cluster.get("count", 1))
	var settlements: Array[int] = []
	if settlement_id >= 0:
		settlements.append(settlement_id)
	var type_name: String = STORY_TYPE_NAMES.get(stype, "mystery")
	var title: String = _generate_title(stype, settlement_id, tick)
	var desc: String = _generate_description(stype, count)
	_register_settlement_thread_cooldown(settlement_id, tick)
	_generate_thread(title, desc, stype, pawns, settlements, tick)

func _generate_title(stype: int, settlement_id: int, tick: int) -> String:
	var type_name: String = STORY_TYPE_NAMES.get(stype, "mystery")
	var stream: StringName = StringName("narrative_title_gen")
	var roll: int = WorldRNG.index_for(stream, 4, tick + settlement_id + 1) if WorldRNG != null else 0
	match stype:
		StoryType.MIGRATION:
			match roll:
				0: return "The Great Journey"
				1: return "Exodus to New Lands"
				2: return "The Wandering Host"
				_: return "Winds of Migration"
		StoryType.WAR:
			match roll:
				0: return "The Bloody Campaign"
				1: return "War Drums on the Horizon"
				2: return "The Scouring"
				_: return "Conflict of Ages"
		StoryType.ROMANCE:
			match roll:
				0: return "A Bond Forged in Fire"
				1: return "Hearts Entwined"
				2: return "The Courtship"
				_: return "Love Amidst Ruin"
		StoryType.BETRAYAL:
			match roll:
				0: return "The Serpent's Kiss"
				1: return "Treachery Unveiled"
				2: return "Broken Oaths"
				_: return "The Knife in the Dark"
		StoryType.DISCOVERY:
			match roll:
				0: return "Uncharted Horizons"
				1: return "Secrets of the Deep"
				2: return "The Revelation"
				_: return "Lost and Found"
		StoryType.CATACLYSM:
			match roll:
				0: return "The World Breaks"
				1: return "Day of Wrath"
				2: return "The Sundering"
				_: return "Ashes and Ruin"
		StoryType.FOUNDING:
			match roll:
				0: return "A New Dawn"
				1: return "The Founding"
				2: return "Seed of Civilization"
				_: return "Cornerstone"
		StoryType.RISE_FALL:
			match roll:
				0: return "The Rise and Fall"
				1: return "Glory and Dust"
				2: return "Empire of Ashes"
				_: return "From Heights to Depths"
		StoryType.RIVALRY:
			match roll:
				0: return "The Eternal Rivalry"
				1: return "Clash of Wills"
				2: return "Bitter Contention"
				_: return "The Great Rivalry"
		StoryType.ALLIANCE:
			match roll:
				0: return "The Unlikely Alliance"
				1: return "Pact of Steel"
				2: return "Bound by Need"
				_: return "The Covenant"
		StoryType.MYSTERY:
			match roll:
				0: return "The Enigma"
				1: return "Whispers in the Dark"
				2: return "The Vanished"
				_: return "Shadows of the Past"
		StoryType.TRAGEDY:
			match roll:
				0: return "A Bitter End"
				1: return "The Fallen"
				2: return "Elegy"
				_: return "Lament for the Lost"
	return "The %s" % type_name.capitalize()

func _generate_description(stype: int, event_count: int) -> String:
	match stype:
		StoryType.MIGRATION:
			return "A large-scale movement of people reshapes the population landscape."
		StoryType.WAR:
			return "Armed conflict erupts, bringing death and destruction."
		StoryType.ROMANCE:
			return "A bond between individuals deepens into something more."
		StoryType.BETRAYAL:
			return "Trust is shattered as someone turns against their own."
		StoryType.DISCOVERY:
			return "New knowledge or lands are uncovered."
		StoryType.CATACLYSM:
			return "A world-altering disaster threatens everything."
		StoryType.FOUNDING:
			return "A new settlement rises from the wilderness."
		StoryType.RISE_FALL:
			return "A settlement or faction reaches great heights before collapsing."
		StoryType.RIVALRY:
			return "Two parties engage in a bitter, long-standing conflict."
		StoryType.ALLIANCE:
			return "Former rivals or strangers unite for mutual benefit."
		StoryType.MYSTERY:
			return "Strange events unfold with no clear explanation."
		StoryType.TRAGEDY:
			return "Loss and sorrow mark this chapter of history."
	return "Events of great significance are unfolding."

func _generate_thread(
		title: String,
		description: String,
		stype: int,
		pawns: Array,
		settlements: Array[int],
		tick: int
) -> void:
	if title.is_empty() or settlements.is_empty():
		return
	var thread := NarrativeThread.new(title, description, stype, pawns, settlements, tick)
	var stream: StringName = StringName("narrative_initial_tension")
	var tension_seed: int = tick + title.hash()
	thread.tension = clampf(
		WorldRNG.range_for(stream, float(TENSION_MIN_START), float(TENSION_MAX_START), tension_seed) if WorldRNG != null else 50.0,
		0.0, 100.0
	)
	_threads.append(thread)
	_stats["threads_generated"] = int(_stats.get("threads_generated", 0)) + 1
	var type_name: String = STORY_TYPE_NAMES.get(stype, "unknown")
	thread_generated.emit(title, type_name, settlements.duplicate())
	var wm := get_node_or_null("/root/WorldMemory")
	if wm != null and wm.has_method("record_event"):
		wm.call("record_event", {
			"type": "narrative_thread_generated",
			"title": title,
			"story_type": type_name,
			"involved_pawns": pawns.duplicate(),
			"involved_settlements": settlements.duplicate(),
			"tension": thread.tension,
			"tick": tick,
		})

func _adjust_tension(thread: NarrativeThread, delta: float, tick: int) -> void:
	var old: float = thread.tension
	thread.tension = clampf(thread.tension + delta, 0.0, 100.0)
	thread.tick_last_update = tick
	thread_tension_changed.emit(thread.title, old, thread.tension)
	if thread.tension >= 80.0 and old < 80.0:
		_stats["tension_peaks"] = int(_stats.get("tension_peaks", 0)) + 1
	if thread.tension >= LEGEND_TENSION_THRESHOLD:
		_try_spawn_legend(thread, tick)

func _try_spawn_legend(thread: NarrativeThread, tick: int) -> void:
	var ls := get_node_or_null("/root/LegendSystem")
	if ls == null or not ls.has_method("create_legend"):
		return
	var type_name: String = STORY_TYPE_NAMES.get(thread.type, "heroic")
	var legend_title: String = "The Legend of %s" % thread.title
	ls.call("create_legend", legend_title, thread.description, -1, type_name, thread.involved_pawns.duplicate(), tick)
	_stats["legends_spawned"] = int(_stats.get("legends_spawned", 0)) + 1

func _decay_stale_tension(tick: int) -> void:
	for t in _threads:
		if t.status != ThreadStatus.ACTIVE:
			continue
		var idle_ticks: int = tick - t.tick_last_update
		if idle_ticks > TENSION_DECAY_IF_STALE:
			var decay: float = -5.0 * float(idle_ticks) / float(TENSION_DECAY_IF_STALE)
			_adjust_tension(t, decay, tick)

func _check_arc_resolutions(tick: int) -> void:
	for i in range(_threads.size() - 1, -1, -1):
		var t: NarrativeThread = _threads[i]
		if t.status != ThreadStatus.ACTIVE:
			continue
		if _check_thread_resolution(t, tick):
			continue
		if t.tension <= STALE_RESOLVE_TENSION and tick - t.tick_last_update > TENSION_DECAY_IF_STALE:
			_resolve_thread(i, "The story faded into obscurity, unresolved.")
		elif tick - t.tick_started > HARD_STALE_TICKS:
			_resolve_thread(i, "Time wore away the thread until nothing remained.")

func _check_thread_resolution(t: NarrativeThread, tick: int) -> bool:
	var wm := get_node_or_null("/root/WorldMemory")
	if wm == null or not wm.has_method("get_recent_events"):
		return false
	var recent: Array = wm.call("get_recent_events", 500)
	match t.type:
		StoryType.WAR:
			return _check_war_resolution(t, recent, tick)
		StoryType.ROMANCE:
			return _check_romance_resolution(t, recent, tick)
		StoryType.FOUNDING:
			return _check_founding_resolution(t, recent, tick)
		StoryType.RIVALRY:
			return _check_rivalry_resolution(t, recent, tick)
		StoryType.ALLIANCE:
			return _check_alliance_resolution(t, recent, tick)
		StoryType.BETRAYAL:
			return _check_betrayal_resolution(t, recent, tick)
		StoryType.DISCOVERY:
			return _check_discovery_resolution(t, recent, tick)
		StoryType.CATACLYSM:
			return _check_cataclysm_resolution(t, recent, tick)
		StoryType.MIGRATION:
			return _check_migration_resolution(t, recent, tick)
		StoryType.RISE_FALL:
			return _check_rise_fall_resolution(t, recent, tick)
		StoryType.MYSTERY:
			return _check_mystery_resolution(t, recent, tick)
		StoryType.TRAGEDY:
			return _check_tragedy_resolution(t, recent, tick)
	return false

func _check_war_resolution(t: NarrativeThread, recent: Array, tick: int) -> bool:
	for ev in recent:
		if not (ev is Dictionary):
			continue
		var e: Dictionary = ev as Dictionary
		var etype: String = str(e.get("type", ""))
		if etype == "peace_treaty" or etype == "war_ended":
			var sid1: int = int(e.get("settlement_id", -1))
			var sid2: int = int(e.get("other_settlement_id", -1))
			if _both_in_settlements(t, sid1, sid2):
				var summary: String = "Peace was brokered after %s." % _event_duration_str(t.tick_started, tick)
				_resolve_thread_of(t, summary)
				return true
		if etype == "decisive_battle" and t.tension >= 70.0:
			var victor: int = int(e.get("victor_settlement_id", -1))
			if victor >= 0 and victor in t.involved_settlements:
				var summary: String = "A decisive battle ended the conflict."
				_resolve_thread_of(t, summary)
				return true
	return false

func _check_romance_resolution(t: NarrativeThread, recent: Array, tick: int) -> bool:
	var romance_ev_count: int = 0
	for ev in recent:
		if not (ev is Dictionary):
			continue
		var e: Dictionary = ev as Dictionary
		var etype: String = str(e.get("type", ""))
		if etype == "marriage" or etype == "romance_fulfilled":
			var p1: int = int(e.get("pawn_a_id", -1))
			var p2: int = int(e.get("pawn_b_id", -1))
			if p1 >= 0 and p2 >= 0 and p1 in t.involved_pawns and p2 in t.involved_pawns:
				var summary: String = "The bond was sealed in ceremony and joy."
				_resolve_thread_of(t, summary)
				return true
		if etype in ["romance_event", "courtship"]:
			romance_ev_count += 1
	if romance_ev_count >= 3 and t.tension >= 40.0:
		t.resolution_progress = clampf(t.resolution_progress + 0.1, 0.0, 1.0)
	if t.resolution_progress >= 1.0:
		var summary: String = "The romance ran its course, leaving the world changed."
		_resolve_thread_of(t, summary)
		return true
	return false

func _check_founding_resolution(t: NarrativeThread, recent: Array, tick: int) -> bool:
	for ev in recent:
		if not (ev is Dictionary):
			continue
		var e: Dictionary = ev as Dictionary
		var etype: String = str(e.get("type", ""))
		if etype == "settlement_expanded" or etype == "polity_formed":
			var sid: int = int(e.get("settlement_id", e.get("center", -1)))
			if sid >= 0 and sid in t.involved_settlements:
				t.resolution_progress = clampf(t.resolution_progress + 0.15, 0.0, 1.0)
	if t.resolution_progress >= 1.0 or tick - t.tick_started > 50000:
		var summary: String = "The settlement grew from a fledgling outpost into a thriving home."
		_resolve_thread_of(t, summary)
		return true
	return false

func _check_rivalry_resolution(t: NarrativeThread, recent: Array, tick: int) -> bool:
	for ev in recent:
		if not (ev is Dictionary):
			continue
		var e: Dictionary = ev as Dictionary
		var etype: String = str(e.get("type", ""))
		if etype == "grudge_settled" or etype == "rivalry_ended" or etype == "reconciliation":
			var sid1: int = int(e.get("settlement_a", e.get("settlement_id", -1)))
			var sid2: int = int(e.get("settlement_b", -1))
			if _both_in_settlements(t, sid1, sid2) or (sid1 >= 0 and sid1 in t.involved_settlements):
				var summary: String = "The rivalry was laid to rest."
				_resolve_thread_of(t, summary)
				return true
	if tick - t.tick_started > 80000:
		var summary: String = "The rivalry burned out over time."
		_resolve_thread_of(t, summary)
		return true
	return false

func _check_alliance_resolution(t: NarrativeThread, recent: Array, tick: int) -> bool:
	for ev in recent:
		if not (ev is Dictionary):
			continue
		var e: Dictionary = ev as Dictionary
		var etype: String = str(e.get("type", ""))
		if etype == "alliance_formed" or etype == "treaty_signed" or etype == "trade_route_established":
			var sid: int = int(e.get("settlement_id", e.get("center", -1)))
			if sid >= 0 and sid in t.involved_settlements:
				t.resolution_progress = clampf(t.resolution_progress + 0.2, 0.0, 1.0)
	if t.resolution_progress >= 1.0:
		var summary: String = "The alliance was formally sealed."
		_resolve_thread_of(t, summary)
		return true
	var ls := get_node_or_null("/root/LegendSystem")
	if ls != null and ls.has_method("create_legend"):
		ls.call("create_legend", "The Legend of %s" % t.title, t.description, -1, "alliance", t.involved_pawns.duplicate(), tick)
		return false
	return false

func _check_betrayal_resolution(t: NarrativeThread, recent: Array, tick: int) -> bool:
	for ev in recent:
		if not (ev is Dictionary):
			continue
		var e: Dictionary = ev as Dictionary
		var etype: String = str(e.get("type", ""))
		if etype == "justice_served" or etype == "betrayer_defeated" or etype == "revenge":
			var pid: int = int(e.get("pawn_id", e.get("perp_id", -1)))
			if pid >= 0 and pid in t.involved_pawns:
				var summary: String = "Justice was served against the betrayer."
				_resolve_thread_of(t, summary)
				return true
	if tick - t.tick_started > 60000:
		var summary: String = "The betrayal faded into memory, unavenged."
		_resolve_thread_of(t, summary)
		return true
	return false

func _check_discovery_resolution(t: NarrativeThread, recent: Array, tick: int) -> bool:
	for ev in recent:
		if not (ev is Dictionary):
			continue
		var e: Dictionary = ev as Dictionary
		var etype: String = str(e.get("type", ""))
		if etype == "knowledge_inscribed" or etype == "discovery_completed" or etype == "mystery_solved":
			var sid: int = int(e.get("settlement_id", e.get("center", -1)))
			if sid >= 0 and sid in t.involved_settlements:
				var summary: String = "The great discovery was fully uncovered."
				_resolve_thread_of(t, summary)
				return true
	if t.tension <= 20.0 and tick - t.tick_last_update > 20000:
		var summary: String = "The trail went cold and the discovery was forgotten."
		_resolve_thread_of(t, summary)
		return true
	return false

func _check_cataclysm_resolution(t: NarrativeThread, recent: Array, tick: int) -> bool:
	for ev in recent:
		if not (ev is Dictionary):
			continue
		var e: Dictionary = ev as Dictionary
		var etype: String = str(e.get("type", ""))
		if etype == "disaster_ended" or etype == "recovery_begun" or etype == "rebuild":
			var sid: int = int(e.get("settlement_id", -1))
			if sid >= 0 and sid in t.involved_settlements:
				var summary: String = "The cataclysm passed and survivors began to rebuild."
				_resolve_thread_of(t, summary)
				return true
	if tick - t.tick_started > 70000:
		var summary: String = "The world slowly healed from the cataclysm."
		_resolve_thread_of(t, summary)
		return true
	return false

func _check_migration_resolution(t: NarrativeThread, recent: Array, tick: int) -> bool:
	for ev in recent:
		if not (ev is Dictionary):
			continue
		var e: Dictionary = ev as Dictionary
		var etype: String = str(e.get("type", ""))
		if etype == "migration_completed":
			var to_sid: int = int(e.get("to_region", e.get("settlement_id", -1)))
			if to_sid >= 0 and to_sid in t.involved_settlements:
				var summary: String = "The migration reached its destination."
				_resolve_thread_of(t, summary)
				return true
	if t.tension <= 10.0:
		var summary: String = "The migration dispersed, its purpose lost."
		_resolve_thread_of(t, summary)
		return true
	return false

func _check_rise_fall_resolution(t: NarrativeThread, recent: Array, tick: int) -> bool:
	for ev in recent:
		if not (ev is Dictionary):
			continue
		var e: Dictionary = ev as Dictionary
		var etype: String = str(e.get("type", ""))
		if etype == "settlement_collapse" or etype == "settlement_destroyed":
			var sid: int = int(e.get("settlement_id", -1))
			if sid >= 0 and sid in t.involved_settlements:
				var summary: String = "What rose high fell hard. The settlement was no more."
				_resolve_thread_of(t, summary)
				return true
	if t.tension >= 90.0:
		var summary: String = "At the peak of tension, the thread snapped — collapse was inevitable."
		_resolve_thread_of(t, summary)
		return true
	return false

func _check_mystery_resolution(t: NarrativeThread, recent: Array, tick: int) -> bool:
	for ev in recent:
		if not (ev is Dictionary):
			continue
		var e: Dictionary = ev as Dictionary
		var etype: String = str(e.get("type", ""))
		if etype == "mystery_solved" or etype == "knowledge_rediscovered":
			var sid: int = int(e.get("settlement_id", -1))
			if sid >= 0 and sid in t.involved_settlements or sid < 0:
				var summary: String = "The mystery was finally solved."
				_resolve_thread_of(t, summary)
				return true
	if tick - t.tick_started > 90000:
		var summary: String = "The mystery remained unsolved, lost to time."
		_resolve_thread_of(t, summary)
		return true
	return false

func _check_tragedy_resolution(t: NarrativeThread, recent: Array, tick: int) -> bool:
	var death_count: int = 0
	for ev in recent:
		if not (ev is Dictionary):
			continue
		var e: Dictionary = ev as Dictionary
		var etype: String = str(e.get("type", ""))
		if etype == "funeral" or etype == "memorial" or etype == "mourning":
			var pid: int = int(e.get("pawn_id", -1))
			if pid >= 0 and pid in t.involved_pawns:
				var summary: String = "The fallen were honored and remembered."
				_resolve_thread_of(t, summary)
				return true
		if etype == "death" or etype == "pawn_death":
			death_count += 1
	if death_count >= 5:
		t.resolution_progress = clampf(t.resolution_progress + 0.2, 0.0, 1.0)
	if t.resolution_progress >= 1.0:
		var summary: String = "The tragedy claimed all it would. Silence followed."
		_resolve_thread_of(t, summary)
		return true
	return false

func _check_pawn_tragedy_thread(payload: Dictionary) -> void:
	var pid: int = int(payload.get("pawn_id", -1))
	if pid < 0:
		return
	var tick: int = int(payload.get("tick", 0))
	if _thread_involving_pawn(pid) != null:
		return
	var wm := get_node_or_null("/root/WorldMemory")
	if wm == null or not wm.has_method("get_events_of_type"):
		return
	var pawn_events: Array = wm.call("get_events_of_type", "death", 10000)
	var pawn_death_count: int = 0
	for ev in pawn_events:
		if not (ev is Dictionary):
			continue
		if int(ev.get("pawn_id", -1)) == pid:
			pawn_death_count += 1
	var legacy_score: float = float(payload.get("legacy_score", 0.0))
	if legacy_score >= PAWN_LEGACY_SCORE_THRESHOLD or pawn_death_count >= 1:
		var cause: String = str(payload.get("cause", "unknown"))
		if cause == "heroic" or legacy_score >= PAWN_LEGACY_SCORE_THRESHOLD:
			_generate_thread(
				"The Fall of %s" % str(payload.get("pawn_name", "Hero")),
				"A great figure met their end, leaving a void in the world.",
				StoryType.TRAGEDY,
				[pid],
				[],
				tick
			)

func _detect_narrative_arcs(tick: int) -> void:
	var wm := get_node_or_null("/root/WorldMemory")
	if wm == null or not wm.has_method("get_events_of_type"):
		return
	var death_events: Array = wm.call("get_events_of_type", "pawn_death", ARC_DETECTION_WINDOW)
	var foundings: Array = wm.call("get_events_of_type", "settlement_founded", ARC_DETECTION_WINDOW)
	if death_events.size() > 10 and foundings.size() > 3:
		for s in foundings:
			if not (s is Dictionary):
				continue
			var sid: int = int(s.get("settlement_id", s.get("center", -1)))
			if sid < 0:
				continue
			if _find_active_thread_of_type_for_settlement(StoryType.RISE_FALL, sid) != null:
				continue
			if _count_active_threads() >= MAX_ACTIVE_THREADS:
				break
			if not _can_create_for_settlement(sid, tick):
				continue
			var settlement_deaths: int = 0
			for d in death_events:
				if not (d is Dictionary):
					continue
				var ds: int = int(d.get("settlement_id", -1))
				if ds == sid:
					settlement_deaths += 1
			if settlement_deaths > 5:
				var name_str: String = str(s.get("name", "Settlement"))
				_register_settlement_thread_cooldown(sid, tick)
				_generate_thread(
					"The Rise and Fall of %s" % name_str,
					"A settlement that saw greatness now faces ruin.",
					StoryType.RISE_FALL,
					[],
					[sid],
					tick
				)

func _find_existing_war_thread(agg_sid: int, def_sid: int) -> NarrativeThread:
	for t in _threads:
		if t.status != ThreadStatus.ACTIVE:
			continue
		if t.type != StoryType.WAR:
			continue
		if agg_sid in t.involved_settlements or def_sid in t.involved_settlements:
			return t
	return null

func _find_active_thread_of_type_for_settlement(stype: int, sid: int) -> NarrativeThread:
	for t in _threads:
		if t.status == ThreadStatus.ACTIVE and t.type == stype and sid in t.involved_settlements:
			return t
	return null

func _thread_involving_pawn(pid: int) -> NarrativeThread:
	for t in _threads:
		if t.status == ThreadStatus.ACTIVE and pid in t.involved_pawns:
			return t
	return null

func _both_in_settlements(t: NarrativeThread, s1: int, s2: int) -> bool:
	return s1 in t.involved_settlements and s2 in t.involved_settlements

func _resolve_thread(index: int, summary: String) -> void:
	if index < 0 or index >= _threads.size():
		return
	var t: NarrativeThread = _threads[index]
	_resolve_thread_of(t, summary)

func _resolve_thread_of(t: NarrativeThread, summary: String) -> void:
	if t.status != ThreadStatus.ACTIVE:
		return
	t.status = ThreadStatus.RESOLVED
	t.resolution_summary = summary
	t.resolution_progress = 1.0
	var type_name: String = STORY_TYPE_NAMES.get(t.type, "unknown")
	_stats["threads_resolved"] = int(_stats.get("threads_resolved", 0)) + 1
	thread_resolved.emit(t.title, summary, type_name)
	var wm := get_node_or_null("/root/WorldMemory")
	if wm != null and wm.has_method("record_event"):
		wm.call("record_event", {
			"type": "narrative_thread_resolved",
			"title": t.title,
			"story_type": type_name,
			"resolution": summary,
			"tick": t.tick_last_update,
		})

func _archive_resolved_threads() -> void:
	var i: int = 0
	while i < _threads.size():
		var t: NarrativeThread = _threads[i]
		if t.status == ThreadStatus.RESOLVED:
			t.status = ThreadStatus.ARCHIVED
			_archived_threads.append(t)
			_threads.remove_at(i)
			_stats["threads_archived"] = int(_stats.get("threads_archived", 0)) + 1
			thread_archived.emit(t.title)
			if _archived_threads.size() > MAX_ARCHIVED_THREADS:
				_archived_threads.pop_front()
		else:
			i += 1

func _can_create_for_settlement(sid: int, tick: int) -> bool:
	if _count_active_threads() >= MAX_ACTIVE_THREADS:
		return false
	if _settlement_last_thread_tick.has(sid):
		var last_tick: int = int(_settlement_last_thread_tick[sid])
		if tick - last_tick < COOLDOWN_PER_SETTLEMENT:
			return false
	return true

func _register_settlement_thread_cooldown(sid: int, tick: int) -> void:
	_settlement_last_thread_tick[sid] = tick

func _count_active_threads() -> int:
	var count: int = 0
	for t in _threads:
		if t.status == ThreadStatus.ACTIVE:
			count += 1
	return count

func _count_active_threads_for_settlement(sid: int) -> int:
	var count: int = 0
	for t in _threads:
		if t.status == ThreadStatus.ACTIVE and sid in t.involved_settlements:
			count += 1
	return count

static func _event_duration_str(start_tick: int, end_tick: int) -> String:
	var dur: int = end_tick - start_tick
	if dur < 1000:
		return "a brief moment"
	elif dur < 10000:
		return "several days"
	elif dur < 50000:
		return "many weeks"
	else:
		return "long months"

func get_active_stories() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for t in _threads:
		if t.status == ThreadStatus.ACTIVE:
			out.append(_thread_to_dict(t))
	return out

func get_settlement_stories(settlement_id: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for t in _threads:
		if settlement_id in t.involved_settlements:
			out.append(_thread_to_dict(t))
	for t in _archived_threads:
		if settlement_id in t.involved_settlements:
			out.append(_thread_to_dict(t))
	return out

func get_pawn_stories(pawn_id: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for t in _threads:
		if pawn_id in t.involved_pawns:
			out.append(_thread_to_dict(t))
	for t in _archived_threads:
		if pawn_id in t.involved_pawns:
			out.append(_thread_to_dict(t))
	return out

func get_stats() -> Dictionary:
	var active: int = 0
	var resolved: int = 0
	for t in _threads:
		match t.status:
			ThreadStatus.ACTIVE:
				active += 1
			ThreadStatus.RESOLVED:
				resolved += 1
	var total_tension: float = 0.0
	for t in _threads:
		if t.status == ThreadStatus.ACTIVE:
			total_tension += t.tension
	var avg_tension: float = total_tension / float(active) if active > 0 else 0.0
	var out: Dictionary = _stats.duplicate(true)
	out["active_threads"] = active
	out["resolved_threads"] = resolved
	out["archived_threads"] = _archived_threads.size()
	out["total_threads"] = _threads.size() + _archived_threads.size()
	out["average_tension"] = avg_tension
	out["settlements_with_stories"] = _settlement_last_thread_tick.size()
	return out

func _thread_to_dict(t: NarrativeThread) -> Dictionary:
	return {
		"title": t.title,
		"description": t.description,
		"type": t.type,
		"type_name": STORY_TYPE_NAMES.get(t.type, "unknown"),
		"involved_pawns": t.involved_pawns.duplicate(),
		"involved_settlements": t.involved_settlements.duplicate(),
		"events": t.events.duplicate(),
		"tension": t.tension,
		"resolution_progress": t.resolution_progress,
		"tick_started": t.tick_started,
		"tick_last_update": t.tick_last_update,
		"status": t.status,
		"status_name": _status_name(t.status),
		"resolution_summary": t.resolution_summary,
	}

static func _status_name(s: int) -> String:
	match s:
		ThreadStatus.ACTIVE:
			return "active"
		ThreadStatus.RESOLVED:
			return "resolved"
		ThreadStatus.ARCHIVED:
			return "archived"
	return "unknown"

func add_event_to_thread(thread_index: int, event: Dictionary) -> void:
	if thread_index < 0 or thread_index >= _threads.size():
		return
	var t: NarrativeThread = _threads[thread_index]
	if t.status != ThreadStatus.ACTIVE:
		return
	if t.events.size() >= MAX_EVENTS_PER_THREAD:
		t.events.pop_front()
	t.events.append(event.duplicate())
	t.tick_last_update = int(event.get("t", int(event.get("tick", t.tick_last_update))))
	var tension_delta: float = float(event.get("tension_delta", 5.0))
	_adjust_tension(t, tension_delta, t.tick_last_update)

func resolve_thread(thread_index: int, resolution: String) -> void:
	if thread_index < 0 or thread_index >= _threads.size():
		return
	var t: NarrativeThread = _threads[thread_index]
	if t.status != ThreadStatus.ACTIVE:
		return
	_resolve_thread_of(t, resolution)

func to_save_dict() -> Dictionary:
	var active_data: Array[Dictionary] = []
	for t in _threads:
		active_data.append(_thread_to_save(t))
	var archived_data: Array[Dictionary] = []
	for t in _archived_threads:
		archived_data.append(_thread_to_save(t))
	return {
		"threads": active_data,
		"archived_threads": archived_data,
		"last_scan_tick": _last_scan_tick,
		"settlement_last_thread_tick": _settlement_last_thread_tick.duplicate(true),
		"stats": _stats.duplicate(true),
	}

func _thread_to_save(t: NarrativeThread) -> Dictionary:
	return {
		"title": t.title,
		"description": t.description,
		"type": t.type,
		"involved_pawns": t.involved_pawns.duplicate(),
		"involved_settlements": t.involved_settlements.duplicate(),
		"events": t.events.duplicate(),
		"tension": t.tension,
		"resolution_progress": t.resolution_progress,
		"tick_started": t.tick_started,
		"tick_last_update": t.tick_last_update,
		"status": t.status,
		"resolution_summary": t.resolution_summary,
	}

func from_save_dict(d: Variant) -> void:
	clear()
	if d == null or not (d is Dictionary):
		return
	var data: Dictionary = d as Dictionary
	var threads_data: Variant = data.get("threads", [])
	if threads_data is Array:
		for td in threads_data:
			if td is Dictionary:
				_threads.append(_thread_from_save(td as Dictionary))
	var archived_data: Variant = data.get("archived_threads", [])
	if archived_data is Array:
		for td in archived_data:
			if td is Dictionary:
				_archived_threads.append(_thread_from_save(td as Dictionary))
	_last_scan_tick = int(data.get("last_scan_tick", -999999))
	var sst: Variant = data.get("settlement_last_thread_tick", {})
	if sst is Dictionary:
		_settlement_last_thread_tick = (sst as Dictionary).duplicate(true)
	var st: Variant = data.get("stats", {})
	if st is Dictionary:
		_stats = (st as Dictionary).duplicate(true)

func _thread_from_save(d: Dictionary) -> NarrativeThread:
	var t := NarrativeThread.new(
		str(d.get("title", "")),
		str(d.get("description", "")),
		int(d.get("type", StoryType.MYSTERY)),
		(d.get("involved_pawns", []) as Array).duplicate(),
		(d.get("involved_settlements", []) as Array).duplicate(),
		int(d.get("tick_started", 0))
	)
	t.events = (d.get("events", []) as Array).duplicate(true)
	t.tension = float(d.get("tension", 0.0))
	t.resolution_progress = float(d.get("resolution_progress", 0.0))
	t.tick_last_update = int(d.get("tick_last_update", 0))
	t.status = int(d.get("status", ThreadStatus.ACTIVE))
	t.resolution_summary = str(d.get("resolution_summary", ""))
	return t

func clear() -> void:
	_threads.clear()
	_archived_threads.clear()
	_last_scan_tick = -999999
	_settlement_last_thread_tick.clear()
	_stats = {
		"threads_generated": 0,
		"threads_resolved": 0,
		"threads_archived": 0,
		"tension_peaks": 0,
		"legends_spawned": 0,
	}
