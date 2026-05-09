extends Node
## Deterministic append-only world fact log (Phase 2.1). No RNG; no UI.
## Events are plain Dictionaries for trivial save/load via Main snapshot.
## Connected to HeelKawn Universe Neural Network Matrix
## CANON SOURCE: See docs/lore/UNIVERSE_CONSTITUTION.md

const SCHEMA: int = 1
## Text/history export line format; bump when column order or provenance rules change.
const HISTORY_EXPORT_FORMAT: String = "1.0.0"
## Keep a long chronology by default; older entries rotate out only after this cap.
const MAX_EVENTS: int = 50000
const CONSTITUTION_PATH: String = "res://docs/lore/UNIVERSE_CONSTITUTION.md"

enum Kind {
	PAWN_DEATH = 0,
	ANIMAL_DEATH = 1,
	ENEMY_DEATH = 2,
	SOCIAL_FRAGMENT = 3,
	SOCIAL_SCHISM = 4,
	BUILDING_CONSTRUCTED = 5,
	BUILDING_DESTROYED = 6,
	FIRE_STARTED = 7,
	FIRE_EXTINGUISHED = 8,
	STARVATION_EVENT = 9,
	MIGRATION_STARTED = 10,
	MIGRATION_COMPLETED = 11,
	TEACHING_EVENT = 12,
	FOOD_EVENT = 13,
	WORK_EVENT = 14,
	SETTLEMENT_EVENT = 15,
	CRAFT_EVENT = 16,
	AUTHORITY_EVENT = 17,
	TRADE_EVENT = 18,
	CONFLICT_EVENT = 19,
	LEGACY_EVENT = 20,
	CULTURE_EVENT = 21,
	INJURY_EVENT = 22,
	WORLD_EVENT = 23,
}

var _events: Array[Dictionary] = []
var _dirty: bool = false
## Set when events are evicted (swap-pop); signals WorldMeaning to full-rebuild.
var _eviction_occurred: bool = false
## event_type -> first tick observed in this session/save timeline.
var _first_event_tick_by_type: Dictionary = {}
## event_type -> total retained events (O(1) counters for large timelines).
var _event_type_counts: Dictionary = {}
## region_key -> latest pawn-death tick (hot-path settlement/rebirth query index).
var _pawn_death_last_tick_by_region: Dictionary = {}
## Per-pawn death throttle: pawn_id -> last death record tick. Prevents
## duplicate death events and caps the recording rate during mass-death events.
var _pawn_death_last_tick_by_id: Dictionary = {}
const PAWN_DEATH_THROTTLE_TICKS: int = 30  # Same pawn can't die twice within 30 ticks
## Monotonic event id (stable cursor for paging/query surfaces).
var _next_event_id: int = 1
var _constitution_text: String = ""
var _constitution_loaded: bool = false

## Persistence rules configuration
const PERSISTENCE_RULES: Dictionary = {
	## Event types to persist across saves (core world history)
	"core_events": ["pawn_death", "birth", "settlement_founded", "settlement_destroyed", "leadership_change"],
	## Event types with regional retention (pruned by region)
	"regional_events": ["pawn_death", "animal_death", "building_constructed", "building_destroyed"],
	## Event types with time-based retention (older events pruned)
	"time_based_events": ["social_meeting", "mood_event", "foraging"],
	## Maximum events to retain per type (0 = unlimited)
	"max_per_type": {
		"pawn_death": 50000,
		"birth": 20000,
		"leadership_change": 5000,
		"social_meeting": 10000,
	},
	## Time-based retention: ticks before pruning (0 = never)
	"retention_ticks": {
		"mood_event": 10000,
		"foraging": 5000,
		"social_meeting": 20000,
	},
}


func _ready() -> void:
	add_to_group("tickable")
	if TickManager != null:
		TickManager.mark_tickable_cache_dirty()
	_load_constitution_text()


func _on_world_tick(tick_number: int) -> void:
	# WorldMemory is primarily a data store; no per-tick logic required.
	# This method satisfies the tickable interface for deterministic ordering.
	pass

# ARCHITECT TASK 2: Record a leadership challenge attempt.
# This is called regardless of outcome.
func record_leadership_challenge_attempt(
		tick: int,
		settlement_id: int,
		challenger_id: int,
		challenger_name: String,
		leader_id: int,
		leader_name: String,
		challenger_score: float,
		leader_score: float,
		challenger_chance: float,
		outcome_seed: int,
		success: bool
	) -> void:
	_append({
		"s": SCHEMA,
		"type": "leadership_challenge_attempt",
		"t": tick,
		"settlement_id": settlement_id,
		"challenger_id": challenger_id,
		"challenger_name": challenger_name,
		"leader_id": leader_id,
		"leader_name": leader_name,
		"challenger_score": challenger_score,
		"leader_score": leader_score,
		"challenger_chance": challenger_chance,
		"outcome_seed": outcome_seed,
		"success": success,
	})

# ARCHITECT TASK 2: Record a leadership change after a successful challenge.
func record_leadership_change(
		tick: int,
		settlement_id: int,
		old_leader_id: int,
		old_leader_name: String,
		new_leader_id: int,
		new_leader_name: String
	) -> void:
	_append({
		"s": SCHEMA,
		"type": "leadership_change",
		"t": tick,
		"settlement_id": settlement_id,
		"old_leader_id": old_leader_id,
		"old_leader_name": old_leader_name,
		"new_leader_id": new_leader_id,
		"new_leader_name": new_leader_name,
	})

# ARCHITECT TASK 2: Record a failed leadership challenge.
func record_leadership_challenge_failed(
		tick: int,
		settlement_id: int,
		challenger_id: int,
		challenger_name: String,
		leader_id: int,
		leader_name: String
	) -> void:
	_append({
		"s": SCHEMA,
		"type": "leadership_challenge_failed",
		"t": tick,
		"settlement_id": settlement_id,
		"challenger_id": challenger_id,
		"challenger_name": challenger_name,
		"leader_id": leader_id,
		"leader_name": leader_name,
	})

# ARCHITECT TASK 2: Record a leadership resolution failure (e.g., SettlementMemory update issue).
func record_leadership_resolution_failed(
		tick: int,
		settlement_id: int,
		challenger_id: int,
		old_ruler_id: int,
		reason: String
	) -> void:
	_append({
		"s": SCHEMA,
		"type": "leadership_resolution_failed",
		"t": tick,
		"settlement_id": settlement_id,
		"challenger_id": challenger_id,
		"old_ruler_id": old_ruler_id,
		"reason": reason,
	})

# === Neural Network Matrix Connections ===

func get_world_stability() -> float:
	# Dynamic neural network matrix calculation of world stability
	var base_stability: float = 0.7
	var death_count: int = 0
	var conflict_count: int = 0
	var disaster_count: int = 0
	
	# Analyze recent events for stability factors
	for i in range(max(0, _events.size() - 100), _events.size()):
		var event: Dictionary = _events[i]
		var event_type: String = event.get("type", "")
		
		match event_type:
			"death":
				death_count += 1
			"conflict":
				conflict_count += 1
			"disaster":
				disaster_count += 1
	
	# Calculate stability modifiers
	var death_penalty: float = min(death_count / 50.0, 0.3)
	var conflict_penalty: float = min(conflict_count / 20.0, 0.2)
	var disaster_penalty: float = min(disaster_count / 10.0, 0.2)
	
	var final_stability: float = base_stability - death_penalty - conflict_penalty - disaster_penalty
	return max(0.1, final_stability)

func get_cultural_event_count() -> int:
	# Count cultural events in neural network matrix
	var cultural_count: int = 0
	for event in _events:
		var event_type: String = event.get("type", "")
		if event_type in ["cultural", "religious", "artistic", "diplomatic"]:
			cultural_count += 1
	return cultural_count

func store_forage_data(x: int, y: int, amount: int, signature: String) -> void:
	# Store forage data in neural network matrix
	var forage_data: Dictionary = {
		"location": Vector2i(x, y),
		"amount": amount,
		"signature": signature,
		"tick": GameManager.tick_count
	}
	
	if not has_meta("forage_matrix"):
		set_meta("forage_matrix", [])
	
	var forage_matrix: Array = get_meta("forage_matrix")
	forage_matrix.append(forage_data)
	
	# Limit matrix size
	if forage_matrix.size() > 1000:
		forage_matrix.pop_front()

func consume_forage(x: int, y: int, amount: int, impact: float, delay: int) -> void:
	# Record forage consumption in neural network matrix
	var consumption_data: Dictionary = {
		"location": Vector2i(x, y),
		"amount": amount,
		"impact": impact,
		"regeneration_delay": delay,
		"tick": GameManager.tick_count,
		"neural_signature": "NM_CONSUME_%08X" % [x * 1000 + y + GameManager.tick_count]
	}
	
	if not has_meta("consumption_matrix"):
		set_meta("consumption_matrix", [])
	
	var consumption_matrix: Array = get_meta("consumption_matrix")
	consumption_matrix.append(consumption_data)
	
	# Limit matrix size
	if consumption_matrix.size() > 500:
		consumption_matrix.pop_front()

func record_ecosystem_event(data: Dictionary) -> void:
	# Record ecosystem events in neural network matrix
	if not has_meta("ecosystem_matrix"):
		set_meta("ecosystem_matrix", [])
	
	var ecosystem_matrix: Array = get_meta("ecosystem_matrix")
	ecosystem_matrix.append(data)
	
	# Limit matrix size
	if ecosystem_matrix.size() > 200:
		ecosystem_matrix.pop_front()

func get_resource_at_tile(tile_pos: Vector2i) -> Dictionary:
	# Get resource data from neural network matrix
	if not has_meta("resource_matrix"):
		return {}
	
	var resource_matrix: Array = get_meta("resource_matrix")
	for resource_data in resource_matrix:
		var location: Vector2i = resource_data.get("location", Vector2i(-1, -1))
		if location == tile_pos:
			return resource_data
	
	return {}


func clear() -> void:
	_events.clear()
	_first_event_tick_by_type.clear()
	_event_type_counts.clear()
	_pawn_death_last_tick_by_region.clear()
	_pawn_death_last_tick_by_id.clear()
	_next_event_id = 1
	_dirty = false


## Returns whether new historical facts were recorded since last consume; clears the flag.
func consume_dirty() -> bool:
	var was_dirty: bool = _dirty
	_dirty = false
	return was_dirty


static func _region_key(tx: int, ty: int) -> int:
	var rx: int = int(tx) >> 4
	var ry: int = int(ty) >> 4
	return (rx & 0xFFFF) | ((ry & 0xFFFF) << 16)


func _append(e: Dictionary) -> void:
	if not validate_event_against_constitution(e):
		return
	_dirty = true
	if _events.size() >= MAX_EVENTS:
		# O(1) eviction: swap oldest with last, pop back instead of O(n) shift
		var dropped: Dictionary = _events[0]
		_events[0] = _events[_events.size() - 1]
		_events.pop_back()
		_on_event_removed_from_indexes(dropped)
		_eviction_occurred = true
	_events.append(e)
	_on_event_added_to_indexes(e)
	# Phase 5: Generate grudges from events
	_on_event_appended(e)


func _load_constitution_text() -> void:
	_constitution_text = ""
	_constitution_loaded = false
	if not FileAccess.file_exists(CONSTITUTION_PATH):
		push_warning("[WorldMemory] Constitution file missing: %s" % CONSTITUTION_PATH)
		return
	var f: FileAccess = FileAccess.open(CONSTITUTION_PATH, FileAccess.READ)
	if f == null:
		push_warning("[WorldMemory] Failed to open constitution file: %s" % CONSTITUTION_PATH)
		return
	_constitution_text = f.get_as_text()
	_constitution_loaded = not _constitution_text.strip_edges().is_empty()


func validate_event_against_constitution(event_dict: Dictionary) -> bool:
	var type_s: String = _canonical_event_type(event_dict).to_lower()
	var payload: String = JSON.stringify(event_dict).to_lower()
	var violations: Array[String] = []
	# Deterministic Kernel gate: reject random/luck/chosen-one flavored history claims.
	if event_dict.has("random") \
			or event_dict.has("rng") \
			or event_dict.has("luck") \
			or event_dict.has("chosen_one") \
			or payload.find("random_luck") >= 0 \
			or payload.find("\"chosen_one\"") >= 0 \
			or payload.find("chosen one") >= 0 \
			or payload.find("destiny_override") >= 0 \
			or payload.find("miracle") >= 0:
		violations.append("Deterministic Kernel / No Chosen Ones")
	# Type-level guard rails for direct event names.
	if type_s.find("chosen") >= 0 or type_s.find("luck") >= 0 or type_s.find("random") >= 0:
		violations.append("Deterministic Kernel event naming")
	# Optional constitution-presence hint for easier diagnostics.
	if not _constitution_loaded:
		push_warning("[WorldMemory] Constitution not loaded; applying fallback deterministic validator.")
	if not violations.is_empty():
		push_warning(
				"[WorldMemory][CanonViolation] Rejected event type=%s laws=%s payload=%s" % [
					type_s,
					", ".join(violations),
					JSON.stringify(event_dict),
				]
		)
		return false
	return true


func _on_event_added_to_indexes(evt: Dictionary) -> void:
	var typ: String = _canonical_event_type(evt)
	_event_type_counts[typ] = int(_event_type_counts.get(typ, 0)) + 1
	if typ == "pawn_death":
		_on_pawn_death_added_to_index(evt)
	var tick: int = int(evt.get("t", 0))
	if not _first_event_tick_by_type.has(typ):
		_first_event_tick_by_type[typ] = tick


func _on_event_removed_from_indexes(evt: Dictionary) -> void:
	var typ: String = _canonical_event_type(evt)
	if typ == "pawn_death":
		_on_pawn_death_removed_from_index(evt)
	var next_count: int = maxi(0, int(_event_type_counts.get(typ, 1)) - 1)
	if next_count <= 0:
		_event_type_counts.erase(typ)
		_first_event_tick_by_type.erase(typ)
		return
	_event_type_counts[typ] = next_count
	if not _first_event_tick_by_type.has(typ):
		return
	var dropped_tick: int = int(evt.get("t", 0))
	if int(_first_event_tick_by_type.get(typ, dropped_tick)) != dropped_tick:
		return
	_recompute_first_tick_for_type(typ)


func _recompute_first_tick_for_type(typ: String) -> void:
	var best: int = -1
	for evt in _events:
		if _canonical_event_type(evt) != typ:
			continue
		var tick: int = int(evt.get("t", 0))
		if best < 0 or tick < best:
			best = tick
	if best < 0:
		_first_event_tick_by_type.erase(typ)
	else:
		_first_event_tick_by_type[typ] = best


func _on_pawn_death_added_to_index(evt: Dictionary) -> void:
	var rk: int = _region_from_event_payload(evt)
	if rk < 0:
		return
	var tick: int = int(evt.get("t", -1))
	if tick < 0:
		return
	if tick > int(_pawn_death_last_tick_by_region.get(rk, -1)):
		_pawn_death_last_tick_by_region[rk] = tick


func _on_pawn_death_removed_from_index(evt: Dictionary) -> void:
	var rk: int = _region_from_event_payload(evt)
	if rk < 0:
		return
	var removed_tick: int = int(evt.get("t", -1))
	if removed_tick < int(_pawn_death_last_tick_by_region.get(rk, -1)):
		return
	_recompute_last_pawn_death_tick_for_region(rk)


func _recompute_last_pawn_death_tick_for_region(rk: int) -> void:
	var best: int = -1
	for evt in _events:
		if int(evt.get("k", -1)) != int(Kind.PAWN_DEATH):
			continue
		if int(evt.get("r", -1)) != rk:
			continue
		best = maxi(best, int(evt.get("t", -1)))
	if best < 0:
		_pawn_death_last_tick_by_region.erase(rk)
	else:
		_pawn_death_last_tick_by_region[rk] = best


## Generic deterministic event appender for non-core typed events (e.g. player input).
## PHASE 4: Added skill-gated probability to reduce event spam
## ARCHITECTURE: Also emits through EventBus for decoupled system communication
func record_event(e: Dictionary) -> void:
	# PERFORMANCE: Event noise reduction - skip low-significance events
	if not _event_passes_significance_threshold(e):
		return

	var payload: Dictionary = _normalize_event_payload(e)
	_append(payload)

	# DORMANT WORLD: Unlock DiscoveryGate when HeelKawnians trigger key events
	_check_discovery_gates(payload)

	# ARCHITECTURE: Emit through EventBus for decoupled listeners
	if EventBus != null:
		var event_type: String = str(payload.get("type", "unknown"))
		EventBus.emit(event_type, payload)


## PHASE 4: Skill-gated event significance filter
## Events are only recorded if they represent meaningful thresholds
## ARCHITECTURE: Stricter filtering to prevent event spam
## DORMANT WORLD: Unlock DiscoveryGate when HeelKawnians trigger key events
func _check_discovery_gates(payload: Dictionary) -> void:
	if DiscoveryGate == null:
		return
	var typ: String = str(payload.get("type", "")).to_lower()
	if typ == "death" or typ == "death_witnessed":
		DiscoveryGate.unlock("first_death")
	elif typ == "birth":
		DiscoveryGate.unlock("first_birth")
	elif typ == "settlement":
		DiscoveryGate.unlock("first_settlement")
	elif typ == "teaching" or typ == "knowledge_inscribed":
		DiscoveryGate.unlock("first_teaching")
		DiscoveryGate.unlock("first_knowledge")
	elif typ == "trade_route":
		DiscoveryGate.unlock("first_trade")
	elif typ == "injury":
		var source: String = str(payload.get("source", "")).to_lower()
		if source == "combat" or source == "war":
			DiscoveryGate.unlock("first_war")


func _event_passes_significance_threshold(e: Dictionary) -> bool:
	var typ: String = str(e.get("type", "")).to_lower()

	# ALWAYS record these (core kernel events)
	var core_events: Array = ["pawn_death", "birth", "pawn_birth", "settlement_founded",
							  "settlement_destroyed", "settlement_revived", "settlement_abandoned",
							  "knowledge_inscribed", "knowledge_read", "teaching_event", "skill_taught",
							  "generational_birth", "ai_chronicle_written", "ai_layer_decision",
							  "chronicle_summary"]
	if core_events.has(typ):
		return true

	# Work events: only record if pawn has skill level >= 5 (mastery threshold)
	if typ == "work_event" or typ == "job_completed":
		var pawn_id: int = int(e.get("pawn_id", -1))
		if pawn_id >= 0:
			var ps: Node = _get_pawn_spawner()
			if ps != null and ps.has_method("pawn_data_for_id"):
				var pawn_data: HeelKawnianData = ps.call("pawn_data_for_id", pawn_id)
				if pawn_data != null:
					# Only record work events for skilled pawns (level 5+)
					var highest_skill: int = pawn_data.get_highest_skill_level()
					return highest_skill >= 5
		# If we can't find pawn data, SKIP the event (stricter filtering)
		return false

	# Building events: always record (visible infrastructure changes)
	if typ.begins_with("building_"):
		return true

	# Social events: only record milestone situations (severity >= 3, increased from 2)
	if typ.begins_with("social_"):
		var severity: int = int(e.get("severity", 0))
		return severity >= 3

	# Movement/wander events: SKIP (too spammy)
	if typ.begins_with("movement_") or typ == "wander_step" or typ == "pathfinding":
		return false

	# Resource gathering: only record significant quantities
	if typ == "resource_gathered" or typ == "forage_event":
		var quantity: int = int(e.get("quantity", 0))
		return quantity >= 5  # Only record hauls of 5+ items

	# Combat events: always record (significant)
	if typ.begins_with("combat_") or typ == "enemy_killed" or typ == "pawn_injured":
		return true

	# Craft events: always record (visible material culture)
	if typ in ["tool_crafted", "tool_break", "food_cooked", "book_bound", "ink_made",
			   "paper_made", "leather_tanned", "pen_crafted"]:
		return true

	# Authority events: always record (governance changes are historical)
	if typ in ["authority_change", "governance_change", "succession", "abdicate",
			   "pledge_loyalty", "edict_issued", "law_added", "law_removed", "ruler_decision"]:
		return true

	# Trade events: always record (economic infrastructure)
	if typ in ["trade_route_started", "trade_route_completed"]:
		return true

	# Conflict events: always record (wars and grudges shape the world)
	if typ in ["war_proposed", "war_battle_spawned", "grudge_formed", "grudge_inherited"]:
		return true

	# Legacy events: always record (lineage and life arcs are core history)
	if typ in ["legacy_record", "life_path_milestone", "life_path_switch", "bloodline_extinct"]:
		return true

	# Culture events: always record (rituals and sacred sites are meaning)
	if typ in ["cultural_exposure", "cultural_building", "ritual_performed", "sacred_site_established"]:
		return true

	# Injury events: always record (bodily consequence matters)
	if typ == "injury":
		return true

	# World events: always record (macro-scale history)
	if typ in ["macro_festival", "macro_unrest", "region_discovery"]:
		return true

	# Knowledge events (non-teaching): always record (knowledge loss is critical)
	if typ in ["knowledge_at_risk", "knowledge_lost", "skill_gain"]:
		return true

	# Settlement events: always record (civilizational milestones)
	if typ in ["settlement_collapse", "settlement_revival", "settlement_revival_with_lineage",
			   "settlement_new_foundation", "famine_warning", "food_spoiled"]:
		return true

	# Building subtypes: always record (infrastructure is visible)
	if typ in ["hearth_built", "storage_built", "shrine_built", "marker_built",
			   "structure_built", "cooperative_build"]:
		return true

	# Default: SKIP unknown event types (stricter than before)
	return false


func _normalize_event_payload(e: Dictionary) -> Dictionary:
	# Shallow copy is sufficient — callers pass fresh dict literals,
	# and we only add top-level keys. Deep copy was defensive but expensive.
	var payload: Dictionary = {}
	for k in e:
		payload[k] = e[k]
	payload["eid"] = _next_event_id
	_next_event_id += 1
	payload["s"] = SCHEMA
	if not payload.has("t"):
		payload["t"] = GameManager.tick_count
	var typ: String = _canonical_event_type(payload)
	payload["type"] = typ
	var sev: int = _severity_for_type(typ)
	payload["severity"] = sev
	var rr: int = _region_from_event_payload(payload)
	if rr >= 0:
		payload["r"] = rr
	# Bridge: if event lacks "k" (Kind int), infer it from the string "type".
	# This connects FoodChainManager and other string-typed events to the
	# WorldMeaning pipeline which requires "k" to process events.
	if not payload.has("k"):
		var inferred_k: int = _infer_kind_from_type(typ)
		if inferred_k >= 0:
			payload["k"] = inferred_k
	var first_tick: int = int(payload.get("t", 0))
	if not _first_event_tick_by_type.has(typ):
		_first_event_tick_by_type[typ] = first_tick
		payload["first_of_type"] = true
	return payload


## Map string event types to Kind ints so WorldMeaning can process them.
## Returns -1 if no mapping exists (event stays invisible to meaning pipeline).
func _infer_kind_from_type(typ: String) -> int:
	match typ:
		"food_spoiled", "famine_warning":
			return Kind.STARVATION_EVENT
		"seeds_planted", "crop_harvested":
			return Kind.FOOD_EVENT
		"job_completed", "job_claimed":
			return Kind.WORK_EVENT
		"pawn_death", "starvation_death":
			return Kind.PAWN_DEATH
		"animal_killed":
			return Kind.ANIMAL_DEATH
		"enemy_killed":
			return Kind.ENEMY_DEATH
		"building_constructed", "bed_built", "wall_built", "door_built":
			return Kind.BUILDING_CONSTRUCTED
		"building_destroyed", "fire_destroyed_building":
			return Kind.BUILDING_DESTROYED
		"fire_started":
			return Kind.FIRE_STARTED
		"fire_extinguished":
			return Kind.FIRE_EXTINGUISHED
		"teaching_event", "skill_taught":
			return Kind.TEACHING_EVENT
		"migration_started", "pawn_migrated":
			return Kind.MIGRATION_STARTED
		"migration_completed":
			return Kind.MIGRATION_COMPLETED
		"social_fragment", "schism_event":
			return Kind.SOCIAL_FRAGMENT
		"pressure_situation", "generational_shift", "diaspora_exile", "diaspora_grief", "knowledge_sealed":
			return Kind.SETTLEMENT_EVENT
		"settlement_collapse", "settlement_revival", "settlement_revival_with_lineage", "settlement_new_foundation":
			return Kind.SETTLEMENT_EVENT
		"tool_crafted", "tool_break", "food_cooked", "book_bound":
			return Kind.CRAFT_EVENT
		"ink_made", "paper_made", "leather_tanned", "pen_crafted":
			return Kind.CRAFT_EVENT
		"authority_change", "governance_change", "succession", "abdicate":
			return Kind.AUTHORITY_EVENT
		"pledge_loyalty", "edict_issued", "law_added", "law_removed", "ruler_decision":
			return Kind.AUTHORITY_EVENT
		"trade_route_started", "trade_route_completed":
			return Kind.TRADE_EVENT
		"war_proposed", "war_battle_spawned", "grudge_formed", "grudge_inherited":
			return Kind.CONFLICT_EVENT
		"legacy_record", "life_path_milestone", "life_path_switch", "bloodline_extinct":
			return Kind.LEGACY_EVENT
		"cultural_exposure", "cultural_building", "ritual_performed", "sacred_site_established":
			return Kind.CULTURE_EVENT
		"injury":
			return Kind.INJURY_EVENT
		"macro_festival", "macro_unrest", "region_discovery":
			return Kind.WORLD_EVENT
		# Knowledge events (not teaching) map to TEACHING_EVENT category
		"knowledge_at_risk", "knowledge_lost", "skill_gain":
			return Kind.TEACHING_EVENT
		# Building subtypes map to BUILDING_CONSTRUCTED
		"hearth_built", "storage_built", "shrine_built", "marker_built", "structure_built":
			return Kind.BUILDING_CONSTRUCTED
		"cooperative_build":
			return Kind.BUILDING_CONSTRUCTED
		_:
			return -1


func _canonical_event_type(payload: Dictionary) -> String:
	var typ: String = str(payload.get("type", "")).strip_edges()
	if not typ.is_empty():
		return typ
	var k: int = int(payload.get("k", -1))
	match k:
		int(Kind.PAWN_DEATH):
			return "pawn_death"
		int(Kind.ANIMAL_DEATH):
			return "animal_death"
		int(Kind.ENEMY_DEATH):
			return "enemy_death"
		int(Kind.SOCIAL_FRAGMENT):
			return "social_fragment"
		int(Kind.SOCIAL_SCHISM):
			return "social_schism"
		int(Kind.BUILDING_CONSTRUCTED):
			return "building_constructed"
		int(Kind.BUILDING_DESTROYED):
			return "building_destroyed"
		int(Kind.FIRE_STARTED):
			return "fire_started"
		int(Kind.FIRE_EXTINGUISHED):
			return "fire_extinguished"
		int(Kind.STARVATION_EVENT):
			return "starvation_event"
		int(Kind.MIGRATION_STARTED):
			return "migration_started"
		int(Kind.MIGRATION_COMPLETED):
			return "migration_completed"
		int(Kind.TEACHING_EVENT):
			return "teaching_event"
	return "event"


func _severity_for_type(typ: String) -> int:
	match typ:
		"pawn_death", "knowledge_loss", "social_schism", "starvation_event", "fire_started":
			return 3
		"enemy_death", "war_proposed", "war_battle_spawned", "governance_change", "birth", "pawn_birth", "building_destroyed":
			return 2
		"social_bond_milestone", "social_meeting", "structure_built", "job_completed", "knowledge_discovery", "knowledge_rediscovery", "teaching_success", "settlement_intent_shift", "building_constructed", "fire_extinguished", "migration_started", "migration_completed", "teaching_event", "leadership_change": # ARCHITECT TASK 2: Add leadership_change to moderate severity
			return 1
		_:
			return 0


func _region_from_event_payload(payload: Dictionary) -> int:
	if payload.has("r"):
		return int(payload.get("r", -1))
	if payload.has("region"):
		return int(payload.get("region", -1))
	if payload.has("x") and payload.has("y"):
		return _region_key(int(payload.get("x", -1)), int(payload.get("y", -1)))
	var tile_v: Variant = payload.get("tile", null)
	if tile_v is Dictionary:
		var td: Dictionary = tile_v as Dictionary
		if td.has("x") and td.has("y"):
			return _region_key(int(td.get("x", -1)), int(td.get("y", -1)))
	var pos_v: Variant = payload.get("pos", null)
	if pos_v is Dictionary:
		var pd: Dictionary = pos_v as Dictionary
		if pd.has("x") and pd.has("y"):
			return _region_key(int(pd.get("x", -1)), int(pd.get("y", -1)))
	elif pos_v is Vector2i:
		var p: Vector2i = pos_v as Vector2i
		return _region_key(p.x, p.y)
	return -1


## Record after `data` is still valid; use primitive fields only.
## Record a pawn death event. The [param settlement_id] is the center_region of the settlement
## where the pawn was born (used for lineage-based cultural memory and revival naming).
func record_pawn_death(
		tick: int,
		tile: Vector2i,
		pawn_id: int,
		pawn_name: String,
		cause: String,
		prof_at_death: int = -1,
		parent_a_snapshot: int = -1,
		parent_b_snapshot: int = -1,
		settlement_id: int = -1
	) -> void:
	# Throttle: skip if this pawn was already recorded dead recently
	var pid_key: int = pawn_id
	var is_first_death: bool = true
	if _pawn_death_last_tick_by_id.has(pid_key):
		if tick - int(_pawn_death_last_tick_by_id[pid_key]) < PAWN_DEATH_THROTTLE_TICKS:
			return  # Skip duplicate death within throttle window
		is_first_death = false  # This pawn died before, but outside throttle window
	_pawn_death_last_tick_by_id[pid_key] = tick
	
	var e: Dictionary = {
		"s": SCHEMA,
		"k": int(Kind.PAWN_DEATH),
		"t": tick,
		"x": tile.x,
		"y": tile.y,
		"r": WorldMemory._region_key(tile.x, tile.y),
		"pid": pawn_id,
		"n": pawn_name,
		"c": cause,
	}
	if prof_at_death >= 0:
		e["prof"] = prof_at_death
	if parent_a_snapshot >= 0:
		e["pa"] = parent_a_snapshot
	if parent_b_snapshot >= 0:
		e["pb"] = parent_b_snapshot
	if settlement_id >= 0:
		e["sid"] = settlement_id
	_append(e)

	# PHASE 7: Record legacy for this pawn
	# Get pawn data first (needed for legacy, notification, and biography)
	var pawn_data: HeelKawnianData = null
	var ps: Node = _get_pawn_spawner()
	if ps != null and ps.has_method("pawn_data_for_id"):
		pawn_data = ps.call("pawn_data_for_id", pawn_id)

	var legacy_sys: Node = get_node_or_null("/root/LegacySystem")
	if legacy_sys != null and legacy_sys.has_method("record_legacy"):
		legacy_sys.call("record_legacy", pawn_id, pawn_data, cause)

	# TEXT-RICH: Show death notification
	var event_overlay: Node = get_node_or_null("/root/EventNotificationOverlay")
	if event_overlay != null and event_overlay.has_method("notify_death"):
		var age_years: float = 0.0
		if pawn_data != null:
			age_years = pawn_data.age / 360.0
		event_overlay.call("notify_death", pawn_name, age_years, cause, pawn_id)

	# TEXT-RICH: Generate and show full pawn biography (ONLY ON FIRST DEATH, DEBUG ONLY)
	# Disabled by default to prevent console spam during normal play
	if OS.is_debug_build() and GameManager != null and GameManager.verbose_logs() and pawn_data != null and is_first_death:
		var biography: String = _generate_pawn_biography(pawn_data, cause)
		print("\n[color=#FFD166][b]━━━ BIOGRAPHY: %s ━━━[/b][/color]" % pawn_name)
		print(biography)
		print("[color=#666666]━━━ END BIOGRAPHY ━━━[/color]\n")


func record_animal_death(
		tick: int,
		tile: Vector2i,
		species: int,
		species_name: String
	) -> void:
	_append({
		"s": SCHEMA,
		"k": int(Kind.ANIMAL_DEATH),
		"t": tick,
		"x": tile.x,
		"y": tile.y,
		"r": WorldMemory._region_key(tile.x, tile.y),
		"sp": species,
		"sn": species_name,
	})


func record_enemy_death(
		tick: int,
		tile: Vector2i,
		enemy_name: String,
		attacker_name: String,
		total_kills: int
	) -> void:
	_append({
		"s": SCHEMA,
		"k": int(Kind.ENEMY_DEATH),
		"type": "enemy_death",
		"t": tick,
		"x": tile.x,
		"y": tile.y,
		"r": WorldMemory._region_key(tile.x, tile.y),
		"enemy": enemy_name,
		"attacker": attacker_name,
		"kill_count": total_kills,
	})


## Deterministic social relocation (fragment / schism); [param regions] is the source cluster pack.
func record_social(
		tick: int,
		kind: int,
		center_rk: int,
		target_tile: Vector2i,
		moved_count: int,
		regions: PackedInt32Array
	) -> void:
	var reg_copy: PackedInt32Array = regions.duplicate()
	_append({
		"s": SCHEMA,
		"k": kind,
		"t": tick,
		"ckr": center_rk,
		"x": target_tile.x,
		"y": target_tile.y,
		"r": WorldMemory._region_key(target_tile.x, target_tile.y),
		"mv": moved_count,
		"rp": reg_copy,
	})


## Record building construction
func record_building_constructed(
		tick: int,
		tile: Vector2i,
		building_type: String,
		builder_id: int = -1,
		settlement_id: int = -1
	) -> void:
	var e: Dictionary = {
		"s": SCHEMA,
		"k": int(Kind.BUILDING_CONSTRUCTED),
		"t": tick,
		"x": tile.x,
		"y": tile.y,
		"r": WorldMemory._region_key(tile.x, tile.y),
		"building_type": building_type,
	}
	if builder_id >= 0:
		e["builder_id"] = builder_id
	if settlement_id >= 0:
		e["settlement_id"] = settlement_id
	_append(e)


## Record building destruction
func record_building_destroyed(
		tick: int,
		tile: Vector2i,
		building_type: String,
		cause: String = "unknown",
		settlement_id: int = -1
	) -> void:
	var e: Dictionary = {
		"s": SCHEMA,
		"k": int(Kind.BUILDING_DESTROYED),
		"t": tick,
		"x": tile.x,
		"y": tile.y,
		"r": WorldMemory._region_key(tile.x, tile.y),
		"building_type": building_type,
		"cause": cause,
	}
	if settlement_id >= 0:
		e["settlement_id"] = settlement_id
	_append(e)


## Record fire started
func record_fire_started(
		tick: int,
		tile: Vector2i,
		cause: String = "unknown",
		settlement_id: int = -1
	) -> void:
	var e: Dictionary = {
		"s": SCHEMA,
		"k": int(Kind.FIRE_STARTED),
		"t": tick,
		"x": tile.x,
		"y": tile.y,
		"r": WorldMemory._region_key(tile.x, tile.y),
		"cause": cause,
	}
	if settlement_id >= 0:
		e["settlement_id"] = settlement_id
	_append(e)


## Record fire extinguished
func record_fire_extinguished(
		tick: int,
		tile: Vector2i,
		duration_ticks: int = 0,
		settlement_id: int = -1
	) -> void:
	var e: Dictionary = {
		"s": SCHEMA,
		"k": int(Kind.FIRE_EXTINGUISHED),
		"t": tick,
		"x": tile.x,
		"y": tile.y,
		"r": WorldMemory._region_key(tile.x, tile.y),
		"duration": duration_ticks,
	}
	if settlement_id >= 0:
		e["settlement_id"] = settlement_id
	_append(e)


## Record starvation event
func record_starvation_event(
		tick: int,
		tile: Vector2i,
		pawn_id: int,
		pawn_name: String,
		severity: String = "moderate",
		settlement_id: int = -1
	) -> void:
	var e: Dictionary = {
		"s": SCHEMA,
		"k": int(Kind.STARVATION_EVENT),
		"t": tick,
		"x": tile.x,
		"y": tile.y,
		"r": WorldMemory._region_key(tile.x, tile.y),
		"pawn_id": pawn_id,
		"pawn_name": pawn_name,
		"severity": severity,
	}
	if settlement_id >= 0:
		e["settlement_id"] = settlement_id
	_append(e)


## Record migration started
func record_migration_started(
		tick: int,
		from_region: int,
		to_region: int,
		migrant_count: int,
		reason: String = "unknown"
	) -> void:
	_append({
		"s": SCHEMA,
		"k": int(Kind.MIGRATION_STARTED),
		"t": tick,
		"from_region": from_region,
		"to_region": to_region,
		"migrant_count": migrant_count,
		"reason": reason,
	})


## Record migration completed
func record_migration_completed(
		tick: int,
		from_region: int,
		to_region: int,
		migrant_count: int,
		successful: bool = true
	) -> void:
	_append({
		"s": SCHEMA,
		"k": int(Kind.MIGRATION_COMPLETED),
		"t": tick,
		"from_region": from_region,
		"to_region": to_region,
		"migrant_count": migrant_count,
		"successful": successful,
	})


## Record teaching event
func record_teaching_event(
		tick: int,
		tile: Vector2i,
		teacher_id: int,
		teacher_name: String,
		student_id: int,
		student_name: String,
		skill_taught: String,
		settlement_id: int = -1
	) -> void:
	var e: Dictionary = {
		"s": SCHEMA,
		"k": int(Kind.TEACHING_EVENT),
		"t": tick,
		"x": tile.x,
		"y": tile.y,
		"r": WorldMemory._region_key(tile.x, tile.y),
		"teacher_id": teacher_id,
		"teacher_name": teacher_name,
		"student_id": student_id,
		"student_name": student_name,
		"skill": skill_taught,
	}
	if settlement_id >= 0:
		e["settlement_id"] = settlement_id
	_append(e)


func to_save_dict() -> Dictionary:
	return {
		"schema": SCHEMA,
		"events": _events.duplicate(true),
	}


## Return the live event array (read-only reference, no copy).
## Use this instead of to_save_dict()["events"] for iteration — avoids
## deep-copying the entire 50K event array on every call.
func get_events() -> Array[Dictionary]:
	return _events


func from_save_dict(d: Variant) -> void:
	clear()
	if d == null or not (d is Dictionary):
		return
	var ev: Variant = (d as Dictionary).get("events", [])
	var max_eid: int = 0
	if ev is Array:
		for e in ev:
			if e is Dictionary:
				var copy: Dictionary = (e as Dictionary).duplicate(true)
				if not copy.has("eid"):
					copy["eid"] = _next_event_id
					_next_event_id += 1
				max_eid = maxi(max_eid, int(copy.get("eid", 0)))
				_events.append(copy)
	if max_eid > 0:
		_next_event_id = max_eid + 1
	_rebuild_first_event_index()


func _rebuild_first_event_index() -> void:
	_first_event_tick_by_type.clear()
	_event_type_counts.clear()
	_pawn_death_last_tick_by_region.clear()
	for evt in _events:
		var typ: String = _canonical_event_type(evt)
		var tick: int = int(evt.get("t", 0))
		_event_type_counts[typ] = int(_event_type_counts.get(typ, 0)) + 1
		if not _first_event_tick_by_type.has(typ):
			_first_event_tick_by_type[typ] = tick
		if typ == "pawn_death":
			_on_pawn_death_added_to_index(evt)


func event_count() -> int:
	return _events.size()


## Last `count` events in append order (oldest first, newest last). Read-only; for soul-bundle / AI handoff.
func get_recent_events(count: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if count <= 0:
		return out
	var n: int = mini(count, _events.size())
	var start: int = _events.size() - n
	for i in range(start, _events.size()):
		var ev_any: Variant = _events[i]
		if not ev_any is Dictionary:
			continue
		out.append((ev_any as Dictionary).duplicate(true))
	return out


## Export a chronicle file (JSON). Returns true if write succeeded.
func export_chronicle(file_path: String) -> bool:
	var out_obj: Dictionary = {
		"schema": SCHEMA,
		"exported_at_tick": GameManager.tick_count if GameManager != null else 0,
		"events": _events.duplicate(true),
	}
	var serialized: String = ""
	# Use JSON printing if available; fall back to rudimentary string dump
	var ok: bool = true
	var js: Variant = null
	# Use JSON.stringify
	js = JSON.stringify(out_obj)
	serialized = str(js)

	var f := FileAccess.open(file_path, FileAccess.WRITE)
	if f == null:
		return false
	# Write a compact JSON-like string; ensure newline
	f.store_string(serialized)
	f.close()
	return true


func get_recent_event_summaries(max_items: int = 3) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if max_items <= 0 or _events.is_empty():
		return out
	var start: int = maxi(0, _events.size() - max_items)
	for i in range(_events.size() - 1, start - 1, -1):
		var evt_any: Variant = _events[i]
		if not evt_any is Dictionary:
			continue
		var evt: Dictionary = evt_any as Dictionary
		var kind: String = str(evt.get("type", ""))
		if kind == "":
			var k: int = int(evt.get("k", -1))
			if k == int(Kind.PAWN_DEATH):
				kind = "pawn_death"
			elif k == int(Kind.ANIMAL_DEATH):
				kind = "animal_death"
			elif k == int(Kind.ENEMY_DEATH):
				kind = "enemy_death"
			elif k == int(Kind.SOCIAL_FRAGMENT):
				kind = "social_fragment"
			elif k == int(Kind.SOCIAL_SCHISM):
				kind = "social_schism"
			else:
				kind = "event"
		var line: String = "%d: %s" % [int(evt.get("t", 0)), kind.replace("_", " ")]
		if kind == "war_battle_spawned":
			line += " (battle spawned)"
		elif kind == "war_proposed":
			line += " (war proposed)"
		elif kind == "governance_change":
			line += " (ruler/governance changed)"
		out.append(line)
	return out


## Plain-text chronicle for promotion, streams, or “what happened” UI. Deterministic given the same event log.
func build_readable_chronicle_summary(max_tail_lines: int = 20) -> String:
	var sb: PackedStringArray = PackedStringArray()
	var tick: int = GameManager.tick_count if GameManager != null else 0
	var wseed: int = WorldRNG.current_seed() if WorldRNG != null else 0
	sb.append("HEELKAWN_CHRONICLE_SUMMARY")
	sb.append("tick=%d  world_seed=%d  events_retained=%d" % [tick, wseed, _events.size()])
	# Bucket counts (indexed types)
	var counts: Dictionary = get_event_type_counts()
	if not counts.is_empty():
		var pairs: Array = []
		for kt in counts.keys():
			pairs.append({"k": str(kt), "n": int(counts[kt])})
		pairs.sort_custom(func(a: Variant, b: Variant) -> bool: return int(a["n"]) > int(b["n"]))
		sb.append("event_types_top:")
		var limit: int = mini(14, pairs.size())
		for i in range(limit):
			sb.append("  • %s × %d" % [str(pairs[i]["k"]).replace("_", " "), int(pairs[i]["n"])])
	sb.append("newest_facts_tail:")
	var tail: PackedStringArray = get_recent_event_summaries(maxi(1, max_tail_lines))
	for j in range(tail.size()):
		sb.append("  • %s" % tail[j])
	var out: String = ""
	for si in range(sb.size()):
		if si > 0:
			out += "\n"
		out += sb[si]
	return out


## Latest tick of an [enum Kind.ANIMAL_DEATH] in [param rk] for [param species] (Animal enum), or -1.
func get_last_animal_death_tick_in_region(rk: int, species: int) -> int:
	var best: int = -1
	for e in _events:
		if int(e.get("k", -1)) != int(Kind.ANIMAL_DEATH):
			continue
		if int(e.get("r", 0)) != rk:
			continue
		if int(e.get("sp", -1)) != species:
			continue
		best = maxi(best, int(e.get("t", 0)))
	return best


## Count of [enum Kind.ANIMAL_DEATH] in [param rk] for [param species] (read-only; for derived population v1).
func get_animal_death_count_in_region(rk: int, species: int) -> int:
	var n: int = 0
	for e in _events:
		if int(e.get("k", -1)) != int(Kind.ANIMAL_DEATH):
			continue
		if int(e.get("r", 0)) != rk:
			continue
		if int(e.get("sp", -1)) != species:
			continue
		n += 1
	return n


## Latest [enum Kind.PAWN_DEATH] tick in any of the given 16x16 [param regions], or -1.
func get_last_pawn_death_tick_in_regions(regions: PackedInt32Array) -> int:
	if regions.is_empty():
		return -1
	var best: int = -1
	for j in range(regions.size()):
		var rk: int = int(regions[j])
		best = maxi(best, int(_pawn_death_last_tick_by_region.get(rk, -1)))
	return best


## O(1) latest [enum Kind.PAWN_DEATH] tick for one region key, or -1.
func get_last_pawn_death_tick_for_region(rk: int) -> int:
	return int(_pawn_death_last_tick_by_region.get(rk, -1))


func get_all_region_keys() -> PackedInt32Array:
	var seen: Dictionary = {}
	for rk in _pawn_death_last_tick_by_region:
		seen[int(rk)] = true
	for e in _events:
		if e.has("r"):
			seen[int(e["r"])] = true
	var out: PackedInt32Array = PackedInt32Array()
	for rk in seen:
		out.append(int(rk))
	out.sort()
	return out


## Region keys (16x16) that have at least one animal death event, sorted ascending (deterministic).
func get_region_keys_with_animal_deaths() -> Array[int]:
	var seen: Dictionary = {}
	for e in _events:
		if int(e.get("k", -1)) != int(Kind.ANIMAL_DEATH):
			continue
		seen[int(e.get("r", 0))] = true
	var out: Array[int] = []
	for rr in seen:
		out.append(int(rr))
	out.sort()
	return out


## One pass over [member _events] for [enum Kind.ANIMAL_DEATH] only. Key format matches [code]AnimalSpawner._rsk[/code] ([code]"rk#species"[/code]).
## Use from hot paths (e.g. [method AnimalSpawner.update_population_dynamics]) instead of many calls to
## [method get_animal_death_count_in_region] / [method get_last_animal_death_tick_in_region] (each O(n) over all events).
func get_animal_death_ledger() -> Dictionary:
	var out: Dictionary = {}
	for e in _events:
		if int(e.get("k", -1)) != int(Kind.ANIMAL_DEATH):
			continue
		var rk: int = int(e.get("r", 0))
		var sp: int = int(e.get("sp", -1))
		var key: String = "%d#%d" % [rk, sp]
		var tt: int = int(e.get("t", 0))
		if not out.has(key):
			out[key] = {"count": 1, "last_t": tt}
		else:
			var rec: Dictionary = out[key]
			rec["count"] = int(rec["count"]) + 1
			rec["last_t"] = maxi(int(rec["last_t"]), tt)
	return out


func _provenance_hash_stub(evt: Dictionary) -> String:
	var payload: String = "%s|%s|%s|%s|%s|%s|%s" % [
		str(evt.get("t", 0)),
		str(evt.get("type", "unknown")),
		str(evt.get("pawn_id", evt.get("pid", "n/a"))),
		str(evt.get("action", evt.get("c", evt.get("reason", "")))),
		str(evt.get("amount", evt.get("total_xp", evt.get("sp", 0)))),
		str(evt.get("r", "n/a")),
		str(evt.get("s", SCHEMA)),
	]
	var h: int = abs(payload.hash())
	return "h%08x" % h


func _export_subject_redacted(subject: Variant, anonymize: bool) -> String:
	var s: String = str(subject)
	if not anonymize:
		return s
	var st: String = s.strip_edges()
	if st.is_valid_int():
		var vi: int = int(st)
		return "anon_%08x" % (abs(vi * 486187739) & 0xFFFFFFFF)
	return s


## Read-only deterministic export snapshot (no file IO).
## Pass [code]anonymize_subjects[/code] for pvabazaar-style sharing (numeric ids hashed in SUB column).
func get_history_export_string(anonymize_subjects: bool = false) -> String:
	var out: PackedStringArray = []
	out.append("HEELKAWN_HISTORY_EXPORT v=%s schema=%d" % [HISTORY_EXPORT_FORMAT, SCHEMA])
	out.append(
		"EXPORT_MODE: %s" % ("public_redacted" if anonymize_subjects else "private_dev")
	)
	out.append("TICKS_PER_SIM_YEAR: %d" % SimTime.TICKS_PER_SIM_YEAR)
	out.append("TICK_RANGE: 0 to %d" % GameManager.tick_count)
	out.append("EVENT_COUNT: %d" % _events.size())
	out.append("COLUMNS: tick | type | subject | cause | impact | provenance_hash")
	out.append("==============================================================")
	for evt in _events:
		var tick: int = int(evt.get("t", 0))
		var type_name: String = str(evt.get("type", "unknown"))
		if type_name == "unknown":
			var k: int = int(evt.get("k", -1))
			if k == int(Kind.PAWN_DEATH):
				type_name = "pawn_death"
			elif k == int(Kind.ANIMAL_DEATH):
				type_name = "animal_death"
			elif k == int(Kind.SOCIAL_FRAGMENT):
				type_name = "social_fragment"
			elif k == int(Kind.SOCIAL_SCHISM):
				type_name = "social_schism"
		var subject: String = _export_subject_redacted(
			evt.get("pawn_id", evt.get("pid", evt.get("sp", "n/a"))),
			anonymize_subjects
		)
		var cause: String = str(evt.get("cause", evt.get("action", evt.get("c", evt.get("reason", "n/a")))))
		var impact: String = str(evt.get("impact", evt.get("amount", evt.get("total_xp", evt.get("executed", "n/a")))))
		out.append("[T:%d] %s | SUB:%s | CAUSE:%s | IMP:%s | PROV:%s" % [
			tick, type_name, subject, cause, impact, _provenance_hash_stub(evt),
		])
	return "\n".join(out)


## Impact buckets for [param zone_id] (center region id as decimal string). Uses [SettlementMemory] region packs when present.
## Latest pawn-death event for [param pawn_id], or empty dict (newest matching record).
func pawn_death_fact(pawn_id: int) -> Dictionary:
	if pawn_id < 0:
		return {}
	for i in range(_events.size() - 1, -1, -1):
		var e: Dictionary = _events[i]
		if int(e.get("k", -1)) != int(Kind.PAWN_DEATH):
			continue
		if int(e.get("pid", -1)) != pawn_id:
			continue
		return e.duplicate(true)
	return {}


## Last recorded name for a pawn id from a pawn death fact, or empty.
func last_known_name_from_death_record(pawn_id: int) -> String:
	return str(pawn_death_fact(pawn_id).get("n", ""))


func get_zone_aggregate(zone_id: String) -> Dictionary:
	var empty: Dictionary = {
		"builds": 0,
		"monuments": 0,
		"trade_routes": 0,
		"death_clusters": 0,
		"biome_exhaustion": 0,
	}
	if zone_id.is_empty() or not zone_id.is_valid_int():
		return empty
	var ckr: int = int(zone_id)
	var want: Dictionary = {}
	for s in SettlementMemory.settlements:
		if s is not Dictionary:
			continue
		var d: Dictionary = s
		if int(d.get("center_region", -2)) != ckr:
			continue
		var regv: Variant = d.get("regions", null)
		if regv is PackedInt32Array:
			var pack: PackedInt32Array = regv as PackedInt32Array
			for j in range(pack.size()):
				want[int(pack[j])] = true
		break
	if want.is_empty():
		want[ckr] = true
	var deaths: int = 0
	var governance_events: int = 0
	var intent_shifts: int = 0
	for e in _events:
		var k: int = int(e.get("k", -1))
		if k == int(Kind.PAWN_DEATH):
			var rr: int = int(e.get("r", -1))
			if want.has(rr):
				deaths += 1
			continue
		var typ: String = str(e.get("type", ""))
		if typ == "governance_change" and int(e.get("settlement_id", -2)) == ckr:
			governance_events += 1
		elif typ == "settlement_intent_shift" and int(e.get("settlement_id", -2)) == ckr:
			intent_shifts += 1
	# Lightweight proxies for revival scoring (deterministic, no RNG).
	return {
		"builds": mini(8, governance_events / 4),
		"monuments": mini(6, intent_shifts / 6),
		"trade_routes": 0,
		"death_clusters": deaths,
		"biome_exhaustion": 0,
	}


func get_events_for_tile(target_pos: Vector2i) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for evt in _events:
		var matched: bool = false
		# Compact typed events store x/y.
		if evt.has("x") and evt.has("y"):
			if int(evt.get("x", -999999)) == target_pos.x and int(evt.get("y", -999999)) == target_pos.y:
				matched = true
		# Generic events may store pos as Dictionary {x,y} or Vector2i.
		elif evt.has("pos"):
			var pv: Variant = evt.get("pos", null)
			if pv is Dictionary:
				var pd: Dictionary = pv as Dictionary
				if int(pd.get("x", -999999)) == target_pos.x and int(pd.get("y", -999999)) == target_pos.y:
					matched = true
			elif pv is Vector2i:
				if (pv as Vector2i) == target_pos:
					matched = true
		if matched:
			results.append(evt.duplicate(true))
	results.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("t", 0)) < int(b.get("t", 0))
	)
	return results


func get_first_event_tick(event_type: String) -> int:
	var key: String = event_type.strip_edges()
	if key.is_empty():
		return -1
	return int(_first_event_tick_by_type.get(key, -1))


func get_event_type_counts() -> Dictionary:
	return _event_type_counts.duplicate(true)


## Recent events scoped to a settlement center region (optionally includes all packed settlement regions).
func get_recent_events_for_settlement(center_region: int, max_items: int = 64, include_settlement_regions: bool = true) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if center_region < 0 or max_items <= 0:
		return out
	var wanted: Dictionary = {center_region: true}
	if include_settlement_regions:
		for s_any in SettlementMemory.settlements:
			if s_any is not Dictionary:
				continue
			var st: Dictionary = s_any as Dictionary
			if int(st.get("center_region", -1)) != center_region:
				continue
			var reg_v: Variant = st.get("regions", PackedInt32Array())
			if reg_v is PackedInt32Array:
				for rk in reg_v as PackedInt32Array:
					wanted[int(rk)] = true
			break
	for i in range(_events.size() - 1, -1, -1):
		if out.size() >= max_items:
			break
		var evt_any: Variant = _events[i]
		if not evt_any is Dictionary:
			continue
		var evt: Dictionary = evt_any as Dictionary
		var rk: int = _region_from_event_payload(evt)
		if rk < 0:
			continue
		if not wanted.has(rk):
			continue
		out.append(evt.duplicate(true))
	out.reverse()
	return out


## Cursor-like page from newest to oldest. Pass before_eid to continue pagination.
func get_events_page_newest(max_items: int = 100, before_eid: int = -1) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if max_items <= 0:
		return out
	for i in range(_events.size() - 1, -1, -1):
		if out.size() >= max_items:
			break
		var evt_any: Variant = _events[i]
		if not evt_any is Dictionary:
			continue
		var evt: Dictionary = evt_any as Dictionary
		var eid: int = int(evt.get("eid", 0))
		if before_eid > 0 and eid >= before_eid:
			continue
		out.append(evt.duplicate(true))
	return out


## Recent events involving a specific pawn id. Matches direct subject keys and
## pair/family fields where present.
func get_recent_events_for_pawn(pawn_id: int, max_items: int = 64) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if pawn_id < 0 or max_items <= 0:
		return out
	for i in range(_events.size() - 1, -1, -1):
		if out.size() >= max_items:
			break
		var evt_any: Variant = _events[i]
		if not evt_any is Dictionary:
			continue
		var evt: Dictionary = evt_any as Dictionary
		var hit: bool = false
		if int(evt.get("pawn_id", -1)) == pawn_id:
			hit = true
		elif int(evt.get("pid", -1)) == pawn_id:
			hit = true
		elif int(evt.get("a", -1)) == pawn_id or int(evt.get("b", -1)) == pawn_id:
			hit = true
		elif int(evt.get("parent_a_id", -1)) == pawn_id or int(evt.get("parent_b_id", -1)) == pawn_id:
			hit = true
		if not hit:
			continue
		out.append(evt.duplicate(true))
	out.reverse()
	return out


## Focused relationship timeline between two pawns (meetings, bond milestones,
## and shared family records) in append order.
func get_relationship_timeline(a_id: int, b_id: int, max_items: int = 64) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if a_id < 0 or b_id < 0 or max_items <= 0:
		return out
	var lo: int = mini(a_id, b_id)
	var hi: int = maxi(a_id, b_id)
	for i in range(_events.size() - 1, -1, -1):
		if out.size() >= max_items:
			break
		var evt_any: Variant = _events[i]
		if not evt_any is Dictionary:
			continue
		var evt: Dictionary = evt_any as Dictionary
		var typ: String = _canonical_event_type(evt)
		var include: bool = false
		if typ == "social_meeting" or typ == "social_bond_milestone":
			var ea: int = int(evt.get("a", -1))
			var eb: int = int(evt.get("b", -1))
			include = mini(ea, eb) == lo and maxi(ea, eb) == hi
		elif typ == "birth" or typ == "pawn_birth":
			var pa: int = int(evt.get("parent_a_id", -1))
			var pb: int = int(evt.get("parent_b_id", -1))
			include = mini(pa, pb) == lo and maxi(pa, pb) == hi
		if not include:
			continue
		out.append(evt.duplicate(true))
	out.reverse()
	return out


## ============================================================
## World Seed Export + Chronicle Summary
## ============================================================

func export_world_seed(file_path: String) -> bool:
	var world_seed: int = 0
	var wr: Node = get_node_or_null("/root/WorldRNG")
	if wr != null and wr.has_method("current_seed"):
		world_seed = int(wr.call("current_seed"))
	var export_tick: int = 0
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm != null and "tick_count" in gm:
		export_tick = int(gm.tick_count)
	var cal: Dictionary = _get_calendar_data()
	var year: int = int(cal.get("year", 1))
	var day: int = int(cal.get("day", 1))
	var settlements: Array = _get_settlement_snapshot()
	var total_pawns: int = _get_total_pawns()
	var biomes: Array = _get_biomes_data()
	var export_data := {
		"schema": "heelkawn_v1",
		"world_seed": world_seed,
		"export_tick": export_tick,
		"calendar": {"year": year, "day": day},
		"settlements": settlements,
		"population": {"total": total_pawns},
		"biomes": biomes,
	}
	var json := JSON.stringify(export_data, "  ")
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file:
		file.store_string(json)
		file.close()
		return true
	return false


func get_chronicle_summary() -> String:
	var lines = []
	lines.append("=== HEELKAWN CHRONICLE ===")
	var year: int = 1
	var day: int = 1
	if has_node("/root/WorldClock"):
		year = get_node("/root/WorldClock").current_year
		day = get_node("/root/WorldClock").current_day
	lines.append("Year %d, Day %d" % [year, day])
	var total_pawns: int = _get_total_pawns()
	lines.append("Population: %d" % total_pawns)
	if has_node("/root/SettlementMemory"):
		var sm = get_node("/root/SettlementMemory")
		if sm.has_method("get_settlement_count"):
			lines.append("Settlements: %d" % sm.get_settlement_count())
	return "\n".join(lines)


## ---- Internal helpers for export/chronicle ----

func _get_world_seed() -> int:
	var w: Node = get_node_or_null("/root/WorldRNG")
	if w != null:
		if w.has_method("current_seed"):
			return int(w.call("current_seed"))
		if w.has_method("get_current_seed"):
			return int(w.call("get_current_seed"))
	return 0


func _get_tick_count() -> int:
	if get_node_or_null("/root/GameManager") != null:
		var gm = get_node_or_null("/root/GameManager")
		if gm and "tick_count" in gm:
			return gm.tick_count
	return 0


func _get_calendar_data() -> Dictionary:
	var cal: Dictionary = {"year": 1, "day": 1}
	if get_node_or_null("/root/WorldClock") != null:
		var wc = get_node_or_null("/root/WorldClock")
		if "current_year" in wc:
			cal["year"] = wc.current_year
		if "current_day" in wc:
			cal["day"] = wc.current_day
	return cal


func _get_settlement_snapshot() -> Array:
	if get_node_or_null("/root/SettlementMemory") != null:
		var sm = get_node_or_null("/root/SettlementMemory")
		if sm and sm.has_method("get_snapshot"):
			return sm.get_snapshot()
	return []


func _get_pawn_spawner() -> Node:
	var _main: Node = get_tree().get_root().get_node_or_null("Main")
	if _main == null:
		return null
	return _main.get_node_or_null("WorldViewport/PawnSpawner")


func _get_total_pawns() -> int:
	var spawner = _get_pawn_spawner()
	if spawner and "pawns" in spawner:
		return spawner.pawns.size()
	return 0


func _get_settlement_count() -> int:
	if get_node_or_null("/root/SettlementMemory") != null:
		var sm = get_node_or_null("/root/SettlementMemory")
		if sm and sm.has_method("get_settlement_count"):
			return sm.get_settlement_count()
	return 0


func _get_biomes_data() -> Array:
	## Chronicle export: full biome raster not exposed on WorldMemory; keep empty until needed.
	return []


func _get_recent_events(max_items: int = 10) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var start = max(0, _events.size() - max_items)
	for i in range(start, _events.size()):
		var evt = _events[i]
		if evt is Dictionary:
			out.append(evt.duplicate(true))
	return out

func record_settlement_state_transition(center_id: int, old_state: String, new_state: String, score: int, scar: int, peace_ticks: int) -> void:
	if not is_instance_valid(GameManager):
		return
	var e: Dictionary = {
		"s": SCHEMA,
		"k": -1,  # reserved for future Kind.SETTLEMENT_STATE_CHANGE
		"type": "settlement_state_change",
		"t": GameManager.tick_count,
		"center_id": center_id,
		"old_state": old_state,
		"new_state": new_state,
		"revival_score": score,
		"scar_max": scar,
		"peace_ticks": peace_ticks,
	}
	_append(e)


# === Grudge Generation (Phase 5: Emergent Life) ===

## Generate grudges from recorded events
## Called automatically when events are appended to the log
func _generate_grudges_from_event(e: Dictionary) -> void:
	var GrudgeMgr: Node = get_node_or_null("/root/GrudgeManager")
	if GrudgeMgr == null:
		return
	
	var tick: int = int(e.get("t", GameManager.tick_count))
	var event_type: String = e.get("type", "")
	
	# HeelKawnian death -> grudges against killer (if recorded)
	if event_type == "pawn_death":
		var victim_id: int = int(e.get("pid", -1))
		var killer_id: int = int(e.get("killer_id", -1))
		var cause: String = e.get("c", "")
		
		if victim_id >= 0 and killer_id >= 0 and killer_id != victim_id:
			# Determine grudge type based on cause
			var grudge_type: String = "kin_death"
			if cause.find("combat") >= 0 or cause.find("attack") >= 0:
				grudge_type = "kin_death"
			elif cause.find("betrayal") >= 0:
				grudge_type = "betrayal"
			
			# Generate grudge for victim's kin
			_generate_grudges_for_victim_kin(victim_id, killer_id, grudge_type, int(e.get("eid", 0)), event_type, tick, GrudgeMgr)
	
	# HeelKawnian harmed -> direct grudge
	elif event_type == "pawn_harmed":
		var victim_id: int = int(e.get("victim_id", -1))
		var aggressor_id: int = int(e.get("aggressor_id", -1))
		var harm_type: String = e.get("harm_type", "minor_harm")
		
		if victim_id >= 0 and aggressor_id >= 0 and aggressor_id != victim_id:
			GrudgeMgr.record_grudge(victim_id, aggressor_id, harm_type, int(e.get("eid", 0)), event_type, tick)
	
	# Theft event -> grudge against thief
	elif event_type == "theft":
		var victim_id: int = int(e.get("victim_id", -1))
		var thief_id: int = int(e.get("thief_id", -1))
		
		if victim_id >= 0 and thief_id >= 0 and thief_id != victim_id:
			GrudgeMgr.record_grudge(victim_id, thief_id, "theft", int(e.get("eid", 0)), event_type, tick)
	
	# Betrayal event -> grudge
	elif event_type == "betrayal":
		var betrayed_id: int = int(e.get("betrayed_id", -1))
		var betrayer_id: int = int(e.get("betrayer_id", -1))
		
		if betrayed_id >= 0 and betrayer_id >= 0 and betrayer_id != betrayed_id:
			GrudgeMgr.record_grudge(betrayed_id, betrayer_id, "betrayal", int(e.get("eid", 0)), event_type, tick)
	
	# Abandonment event -> grudge
	elif event_type == "abandonment":
		var abandoned_id: int = int(e.get("abandoned_id", -1))
		var abandoner_id: int = int(e.get("abandoner_id", -1))
		
		if abandoned_id >= 0 and abandoner_id >= 0 and abandoner_id != abandoned_id:
			GrudgeMgr.record_grudge(abandoned_id, abandoner_id, "abandonment", int(e.get("eid", 0)), event_type, tick)
	
	# Conflict start -> mutual grudges
	elif event_type == "conflict_start":
		var pawn_a: int = int(e.get("pawn_id_a", -1))
		var pawn_b: int = int(e.get("pawn_id_b", -1))
		var conflict_type: String = e.get("conflict_type", "minor_harm")
		
		if pawn_a >= 0 and pawn_b >= 0 and pawn_a != pawn_b:
			GrudgeMgr.record_grudge(pawn_a, pawn_b, conflict_type, int(e.get("eid", 0)), event_type, tick)
			GrudgeMgr.record_grudge(pawn_b, pawn_a, conflict_type, int(e.get("eid", 0)), event_type, tick)


## Generate grudges for victim's kin when a pawn dies
func _generate_grudges_for_victim_kin(
	victim_id: int, killer_id: int, grudge_type: String, event_id: int, event_type: String, tick: int, GrudgeMgr: Node
) -> void:
	var Kinship: Node = get_node_or_null("/root/KinshipSystem")
	if Kinship == null:
		return
	
	# Get victim's immediate family
	var parents: Array = Kinship.get_parents(victim_id) if Kinship.has_method("get_parents") else []
	var children: Array = Kinship.get_children(victim_id) if Kinship.has_method("get_children") else []
	var spouse: Array = Kinship.get_spouses(victim_id) if Kinship.has_method("get_spouses") else []
	
	# Parents grudge for child's death
	for parent_id in parents:
		if int(parent_id) >= 0 and int(parent_id) != killer_id:
			GrudgeMgr.record_grudge(int(parent_id), killer_id, grudge_type, event_id, event_type, tick)
	
	# Children grudge for parent's death
	for child_id in children:
		if int(child_id) >= 0 and int(child_id) != killer_id:
			GrudgeMgr.record_grudge(int(child_id), killer_id, grudge_type, event_id, event_type, tick)
	
	# Spouse grudge
	for spouse_id in spouse:
		if int(spouse_id) >= 0 and int(spouse_id) != killer_id:
			GrudgeMgr.record_grudge(int(spouse_id), killer_id, grudge_type, event_id, event_type, tick)


# ==================== TEXT-RICH: HeelKawnian Biography Generator ====================

## Generate a complete life biography for a pawn.
func _generate_pawn_biography(d: HeelKawnianData, death_cause: String) -> String:
	var text: String = ""
	
	# Header
	text += "[color=#888888]Born: Year %d, Day %d[/color]\n" % [int(d.birth_tick / 360) + 1, int((d.birth_tick % 360) / 10) + 1]
	text += "[color=#888888]Died: Year %d, Day %d (%.1f years old)[/color]\n\n" % [int(GameManager.tick_count / 360) + 1, int((GameManager.tick_count % 360) / 10) + 1, d.age / 360.0]
	
	# Identity
	text += "[color=#FFD166][b]IDENTITY[/b][/color]\n"
	text += "  Profession: %s\n" % d.profession_name()
	text += "  Level: %d | Legacy Score: %d\n" % [d.level, _get_pawn_legacy_score(d.id)]
	text += "  Traits: %s\n\n" % d.traits_display()
	
	# Family
	text += "[color=#FF9F6B][b]FAMILY[/b][/color]\n"
	if d.parent_a_id >= 0 or d.parent_b_id >= 0:
		var parents: Array[String] = []
		if d.parent_a_id >= 0:
			var pa = d._get_parent_data(d.parent_a_id)
			if pa != null:
				parents.append(pa.display_name)
		if d.parent_b_id >= 0:
			var pb = d._get_parent_data(d.parent_b_id)
			if pb != null:
				parents.append(pb.display_name)
		if not parents.is_empty():
			text += "  Parents: %s\n" % " & ".join(parents)
	if d.spouse_id >= 0:
		var spouse = d._get_parent_data(d.spouse_id)
		if spouse != null:
			text += "  Spouse: %s\n" % spouse.display_name
	if d.children_count > 0:
		text += "  Children: %d\n" % d.children_count
	text += "\n"
	
	# Skills
	text += "[color=#B084CC][b]SKILLS & KNOWLEDGE[/b][/color]\n"
	var skills_text: String = _get_biography_skills(d)
	text += "  %s\n\n" % skills_text
	
	# Life events
	text += "[color=#B084CC][b]LIFE EVENTS[/b][/color]\n"
	var events_text: String = _get_biography_events(d.id)
	if events_text != "":
		text += events_text
	else:
		text += "  [color=#666666]No recorded events[/color]\n"
	text += "\n"
	
	# Legacy
	text += "[color=#FFD166][b]LEGACY[/b][/color]\n"
	var legacy_sys: Node = get_node_or_null("/root/LegacySystem")
	if legacy_sys != null and legacy_sys.has_method("get_legacy_entry"):
		var legacy: Dictionary = legacy_sys.call("get_legacy_entry", int(d.id))
		if not legacy.is_empty():
			text += "  Legacy Score: %d\n" % int(legacy.get("legacy_score", 0))
			text += "  Children: %d | Grandchildren: %d\n" % [int(legacy.get("children_count", 0)), int(legacy.get("grandchildren_count", 0))]
			text += "  Knowledge Preserved: %d types\n" % int(legacy.get("knowledge_preserved", []).size())
			text += "  Students Taught: %d\n" % int(legacy.get("students_taught", 0))
	else:
		text += "  [color=#666666]No legacy data available[/color]"
	
	return text


## Get formatted skills string for biography.
func _get_biography_skills(d: HeelKawnianData) -> String:
	var lines: Array[String] = []
	
	for skill_idx in range(5):
		var skill_name: String = HeelKawnianData.skill_name(skill_idx)
		var level: int = d.get_skill_level(skill_idx)
		if level > 0:
			lines.append("%s %d" % [skill_name, level])
	
	if lines.is_empty():
		return "[color=#666666]No skills trained[/color]"
	
	return ", ".join(lines)


## Get life events for biography.
func _get_biography_events(pawn_id: int) -> String:
	var events: Array[Dictionary] = _get_pawn_events_limited(pawn_id, 10)
	if events.is_empty():
		return ""
	
	var text: String = ""
	for ev in events:
		var event_type: String = str(ev.get("type", "unknown"))
		var tick: int = int(ev.get("t", 0))
		var year: int = tick / 360
		var day: int = (tick % 360) / 10
		
		var event_text: String = _format_biography_event(event_type, ev)
		if event_text != "":
			text += "  [color=#888888]Y%d D%d:[/color] %s\n" % [year + 1, day + 1, event_text]
	
	return text


## Format a single event for biography.
func _format_biography_event(event_type: String, ev: Dictionary) -> String:
	match event_type:
		"work_event":
			var job_type: String = str(ev.get("job_type", "work"))
			return "Completed %s" % job_type
		"teaching_event":
			var skill: String = str(ev.get("skill", "skill"))
			return "Taught %s" % skill
		"social_meeting":
			return "Formed friendship"
		"social_bond_milestone":
			var milestone: int = int(ev.get("milestone", 0))
			return "Friendship milestone (%d)" % milestone
		"knowledge_acquisition":
			var knowledge: String = str(ev.get("knowledge_type", "knowledge"))
			return "Learned %s" % knowledge
		"knowledge_inscribed":
			return "Inscribed knowledge on stone"
		"knowledge_read":
			var gained: int = int(ev.get("gained_knowledge", []).size())
			return "Read ancient stone (+%d knowledge)" % gained
		"building_constructed":
			var building: String = str(ev.get("building_type", "structure"))
			return "Built %s" % building
		_:
			return event_type.capitalize()
	
	return ""


## Get recent events for a pawn (limited count).
func _get_pawn_events_limited(pawn_id: int, count: int) -> Array[Dictionary]:
	var all_events: Array[Dictionary] = get_events()
	var pawn_events: Array[Dictionary] = []
	
	for i in range(all_events.size() - 1, -1, -1):
		if pawn_events.size() >= count:
			break
		
		var ev: Dictionary = all_events[i]
		var ev_pawn_id: int = int(ev.get("pawn_id", ev.get("pid", -1)))
		
		if ev_pawn_id == pawn_id:
			pawn_events.append(ev)
	
	pawn_events.reverse()
	return pawn_events


## Get pawn legacy score.
func _get_pawn_legacy_score(pawn_id: int) -> int:
	var legacy_sys: Node = get_node_or_null("/root/LegacySystem")
	if legacy_sys == null:
		return 0
	
	if legacy_sys.has_method("get_legacy_entry"):
		var legacy: Dictionary = legacy_sys.call("get_legacy_entry", pawn_id)
		if not legacy.is_empty():
			return int(legacy.get("legacy_score", 0))
	
	return 0


## Hook into event appending to generate grudges and memorials
func _on_event_appended(e: Dictionary) -> void:
	_generate_grudges_from_event(e)
	
	# MEMORIAL SYSTEM: Auto-create memorials for significant events
	_create_memorials_from_event(e)


## MEMORIAL SYSTEM: Create memorials from world events
func _create_memorials_from_event(e: Dictionary) -> void:
	var ms: Node = get_node_or_null("/root/MemorialSystem")
	if ms == null:
		return
	
	var typ: String = str(e.get("type", "")).to_lower()
	
	match typ:
		"pawn_death":
			var pawn_id: int = int(e.get("pawn_id", e.get("pid", -1)))
			# Reconstruct tile from x,y keys (death events store x/y, not "tile")
			var death_tile: Vector2i = Vector2i(int(e.get("x", 0)), int(e.get("y", 0)))
			var violent: bool = e.get("violent", false) or e.get("cause", "") in ["killed", "battle", "murder"]
			
			if pawn_id >= 0:
				# Pass pawn_id directly — pawn_data_for_id returns null for dead pawns
				ms.call("create_death_memorial", pawn_id, death_tile, violent)
		
		"battle", "war_battle", "conflict_event":
			var casualties: int = int(e.get("casualties", 0))
			var battle_tile: Vector2i = Vector2i(int(e.get("x", 0)), int(e.get("y", 0)))
			var participants: Array = e.get("participants", [])
			
			# Create mass memorial for battles with 3+ casualties
			if casualties >= 3:
				var ps: Node = _get_pawn_spawner()
				var deceased_pawns: Array = []
				
				# Find deceased pawns from battle
				for participant_id in participants:
					if ps != null and ps.has_method("pawn_data_for_id"):
						var pawn_data = ps.call("pawn_data_for_id", int(participant_id))
						if pawn_data != null and pawn_data.health <= 0.0:
							deceased_pawns.append(pawn_data)
				
				if deceased_pawns.size() > 0:
					var event_name: String = e.get("name", "Battle")
					var event_desc: String = e.get("description", "Here %d fell in battle" % casualties)
					ms.call("create_mass_memorial", battle_tile, deceased_pawns, event_name, event_desc)
		
		"settlement_founded":
			var found_tile: Vector2i = Vector2i(int(e.get("x", 0)), int(e.get("y", 0)))
			var settlement_name: String = e.get("settlement_name", "Unknown Settlement")
			
			ms.call("create_memorial", {
				"tile": found_tile,
				"type": "founding_stone",
				"inscription": "Here %s was founded\nYear %d" % [settlement_name, int(e.get("tick", 0)) / 3600],
				"built_by": "auto"
			})
		
		"disaster_event", "fire_started", "flood_event":
			var disaster_tile: Vector2i = Vector2i(int(e.get("x", 0)), int(e.get("y", 0)))
			var casualties: int = int(e.get("casualties", 0))
			
			if casualties > 0:
				var disaster_name: String = e.get("name", "Disaster")
				var disaster_desc: String = e.get("description", "Here %d perished" % casualties)
				ms.call("create_memorial", {
					"tile": disaster_tile,
					"type": "ruin_marker",
					"inscription": "%s\n%d perished here" % [disaster_name, casualties],
					"built_by": "auto"
				})


# === Quality of Life Tracking ===
# Lifespan and literacy metrics for civilization stage calculation.

## Calculate average lifespan from recorded death events (in ticks).
func get_average_lifespan(settlement_id: int = -1) -> int:
	var total_age: int = 0
	var count: int = 0
	for event in _events:
		if not (event is Dictionary):
			continue
		var typ: String = str(event.get("type", ""))
		if typ != "pawn_death":
			continue
		# Filter by settlement if specified
		if settlement_id >= 0:
			var region: int = int(event.get("region", -1))
			if region != settlement_id:
				continue
		var birth_tick: int = int(event.get("birth_tick", -1))
		var death_tick: int = int(event.get("tick", -1))
		if birth_tick >= 0 and death_tick >= 0 and death_tick > birth_tick:
			total_age += (death_tick - birth_tick)
			count += 1
	if count <= 0:
		return 0
	return total_age / count


## Calculate literacy rate for a settlement.
func get_literacy_rate(settlement_id: int = -1) -> float:
	var ks: Node = get_node_or_null("/root/KnowledgeSystem")
	if ks == null or not ks.has_method("has_knowledge"):
		return 0.0
	var total: int = 0
	var literate: int = 0
	# Get pawns for settlement
	var spawner: Node = null
	var main_node: Node = get_tree().get_root().get_node_or_null("Main") if get_tree() != null else null
	if main_node != null:
		spawner = main_node.get_node_or_null("WorldViewport/PawnSpawner")
	if spawner == null:
		return 0.0
	var pawns_v: Variant = spawner.get("pawns")
	if not (pawns_v is Array):
		return 0.0
	var pawns: Array = pawns_v as Array
	for pawn in pawns:
		if pawn == null or not is_instance_valid(pawn) or pawn.data == null:
			continue
		# Filter by settlement
		if settlement_id >= 0:
			var pawn_sid: int = int(pawn.data.settlement_id)
			if pawn_sid != settlement_id:
				continue
		total += 1
		if bool(ks.call("has_knowledge", int(pawn.data.id), 24)):  # WRITING = 24
			literate += 1
	if total <= 0:
		return 0.0
	return float(literate) / float(total)


## Get average health for a settlement.
func get_average_health(settlement_id: int = -1) -> float:
	var total_health: float = 0.0
	var count: int = 0
	var main_node: Node = get_tree().get_root().get_node_or_null("Main") if get_tree() != null else null
	if main_node == null:
		return 0.0
	var spawner: Node = main_node.get_node_or_null("WorldViewport/PawnSpawner")
	if spawner == null:
		return 0.0
	var pawns_v: Variant = spawner.get("pawns")
	if not (pawns_v is Array):
		return 0.0
	var pawns: Array = pawns_v as Array
	for pawn in pawns:
		if pawn == null or not is_instance_valid(pawn) or pawn.data == null:
			continue
		if settlement_id >= 0:
			var pawn_sid: int = int(pawn.data.settlement_id)
			if pawn_sid != settlement_id:
				continue
		total_health += float(pawn.data.health)
		count += 1
	if count <= 0:
		return 0.0
	return total_health / float(count)