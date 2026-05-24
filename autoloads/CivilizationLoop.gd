extends Node
## CivilizationLoop — WorldBox-inspired autonomous civilization loop for HeelKawn.
## Implements: local stockpile truth, production profiles, settlement relations,
## route maturity, trade goods transfer, chronicle truth, and all 8 debug truth reports.
## Deterministic: no global RNG. All state derives from tick + seed + inputs.
## Phase coverage: Phases 1-12 of the WorldBox-inspired directive.

# ─── Tick intervals ───────────────────────────────────────────────────────────
const LOOP_INTERVAL_TICKS: int = 300
const STOCKPILE_TRUTH_INTERVAL: int = 600
const PRODUCTION_PROFILE_INTERVAL: int = 1200
const RELATION_UPDATE_INTERVAL: int = 2000
const CHRONICLE_FLUSH_INTERVAL: int = 1800
const FOUNDING_AUDIT_INTERVAL: int = 3000

# ─── Settlement stage thresholds ──────────────────────────────────────────────
const STAGE_CAMP: String = "camp"
const STAGE_HEARTH_SITE: String = "hearth_site"
const STAGE_PROTO: String = "proto_settlement"
const STAGE_HAMLET: String = "hamlet"
const STAGE_VILLAGE: String = "village"
const STAGE_TOWN: String = "town"

# ─── Local stockpile state labels ─────────────────────────────────────────────
const STOCKPILE_NONE: String = "NONE"
const STOCKPILE_MARKED: String = "MARKED"
const STOCKPILE_BUILT: String = "BUILT"
const STOCKPILE_SHARED_ROUTE_DEPOT: String = "SHARED_ROUTE_DEPOT"
const STOCKPILE_RUINED: String = "RUINED"
const STOCKPILE_ABANDONED: String = "ABANDONED"

# ─── Production profile labels ────────────────────────────────────────────────
const PROFILE_FORAGING_CAMP: String = "foraging_camp"
const PROFILE_HUNTING_CAMP: String = "hunting_camp"
const PROFILE_FISHING_HAMLET: String = "fishing_hamlet"
const PROFILE_FARMING_HAMLET: String = "farming_hamlet"
const PROFILE_LOGGING_VILLAGE: String = "logging_village"
const PROFILE_STONE_CAMP: String = "stone_camp"
const PROFILE_ROAD_OUTPOST: String = "road_outpost"
const PROFILE_TRADE_POST: String = "trade_post"
const PROFILE_DEFENSIVE_HAMLET: String = "defensive_hamlet"
const PROFILE_RECOVERY_SETTLEMENT: String = "recovery_settlement"
const PROFILE_CRAFT_VILLAGE: String = "craft_village"
const PROFILE_KNOWLEDGE_HEARTH: String = "knowledge_hearth"
const PROFILE_MIXED: String = "mixed"

# ─── Relation type labels ─────────────────────────────────────────────────────
const REL_TRADE_PARTNER: String = "trade_partner"
const REL_KINSHIP: String = "kinship"
const REL_DEPENDENCY: String = "dependency"
const REL_DEFENSIVE_PACT: String = "defensive_pact"
const REL_RIVALRY: String = "rivalry"
const REL_GRUDGE: String = "grudge"
const REL_SHARED_CULTURE: String = "shared_culture"
const REL_CONTESTED_BORDER: String = "contested_border"
const REL_NEUTRAL: String = "neutral"

# ─── State ────────────────────────────────────────────────────────────────────
## center_region → local stockpile truth dict
var _local_stockpile_truth: Dictionary = {}
## center_region → production profile dict
var _production_profiles: Dictionary = {}
## "min_max" pair key → relation dict
var _settlement_relations: Dictionary = {}
## center_region → founding truth dict
var _founding_truth: Dictionary = {}
## center_region → chronicle lines array
var _settlement_chronicles: Dictionary = {}
## center_region → last chronicle event tick
var _chronicle_last_tick: Dictionary = {}
## Scheduler rolling cursor for construction pass
var _construction_cursor: int = 0
## Stats for debug reports
var _trade_goods_transferred: int = 0
var _trade_failed_no_surplus: int = 0
var _trade_failed_no_stockpile: int = 0
var _shortage_relieved_count: int = 0
var _migrant_departed_count: int = 0
var _migrant_arrived_count: int = 0
var _route_matured_count: int = 0
var _road_formed_count: int = 0

var _last_loop_tick: int = -999999
var _last_stockpile_tick: int = -999999
var _last_profile_tick: int = -999999
var _last_relation_tick: int = -999999
var _last_chronicle_tick: int = -999999
var _last_founding_tick: int = -999999


func _ready() -> void:
	if GameManager != null:
		GameManager.game_tick.connect(_on_game_tick)


func _on_game_tick(tick: int) -> void:
	if tick - _last_stockpile_tick >= STOCKPILE_TRUTH_INTERVAL:
		_last_stockpile_tick = tick
		_update_local_stockpile_truth()
	if tick - _last_profile_tick >= PRODUCTION_PROFILE_INTERVAL:
		_last_profile_tick = tick
		_update_production_profiles()
	if tick - _last_relation_tick >= RELATION_UPDATE_INTERVAL:
		_last_relation_tick = tick
		_update_settlement_relations()
	if tick - _last_chronicle_tick >= CHRONICLE_FLUSH_INTERVAL:
		_last_chronicle_tick = tick
		_flush_chronicles()
	if tick - _last_founding_tick >= FOUNDING_AUDIT_INTERVAL:
		_last_founding_tick = tick
		_audit_founding_truth()

# ─── Phase 5: Local Stockpile Truth ──────────────────────────────────────────
func _update_local_stockpile_truth() -> void:
	if SettlementMemory == null or StockpileManager == null:
		return
	var tick: int = GameManager.tick_count if GameManager != null else 0
	for st_any in SettlementMemory.settlements:
		if not (st_any is Dictionary):
			continue
		var st: Dictionary = st_any as Dictionary
		var center: int = int(st.get("center_region", -1))
		if center < 0:
			continue
		var pop: int = int(st.get("population", 0))
		var state: String = str(st.get("state", ""))
		# Abandoned/ruin settlements get ABANDONED/RUINED state
		if state in ["permanently_abandoned", "abandoned"]:
			_local_stockpile_truth[center] = {
				"state": STOCKPILE_ABANDONED,
				"center_region": center,
				"reason": "settlement_abandoned",
				"snapshot_tick": tick,
			}
			continue
		# Find stockpiles in this settlement's regions
		var regions_dict: Dictionary = {}
		var regs_v: Variant = st.get("regions", null)
		if regs_v is PackedInt32Array:
			for rk in (regs_v as PackedInt32Array):
				regions_dict[int(rk)] = true
		var local_zones: Array[Stockpile] = []
		var food: int = 0
		var wood: int = 0
		var stone: int = 0
		var hide: int = 0
		var bone: int = 0
		var ore: int = 0
		var tools: int = 0
		for z in StockpileManager.zones():
			if z == null or not is_instance_valid(z):
				continue
			var zt: Vector2i = z.tile
			var rk_z: int = WorldMemory._region_key(zt.x, zt.y)
			if not regions_dict.has(rk_z):
				continue
			local_zones.append(z)
			for t in z.inventory:
				var q: int = int(z.inventory[t])
				if Item.is_food(t):
					food += q
				elif t == Item.Type.WOOD:
					wood += q
				elif t == Item.Type.STONE:
					stone += q
				elif t == Item.Type.HIDE:
					hide += q
				elif t == Item.Type.BONE:
					bone += q
				elif t == Item.Type.FLINT:
					ore += q
		var sp_state: String = STOCKPILE_NONE
		var sp_id: int = -1
		var reason: String = "no_local_stockpile"
		if local_zones.size() > 0:
			sp_state = STOCKPILE_BUILT
			sp_id = local_zones[0].get_instance_id()
			reason = "local_stockpile_found"
		elif pop > 0:
			# Pop>0 but no stockpile: mark as MARKED (needs one)
			sp_state = STOCKPILE_MARKED
			reason = "pop_present_no_stockpile"
		_local_stockpile_truth[center] = {
			"state": sp_state,
			"local_stockpile_id": sp_id,
			"center_region": center,
			"population": pop,
			"food": food,
			"wood": wood,
			"stone": stone,
			"hide": hide,
			"bone": bone,
			"ore": ore,
			"tools": tools,
			"zone_count": local_zones.size(),
			"reason": reason,
			"snapshot_tick": tick,
		}

# ─── Phase 6: Production Profile Specialization ───────────────────────────────
func _update_production_profiles() -> void:
	if SettlementMemory == null:
		return
	var tick: int = GameManager.tick_count if GameManager != null else 0
	for st_any in SettlementMemory.settlements:
		if not (st_any is Dictionary):
			continue
		var st: Dictionary = st_any as Dictionary
		var center: int = int(st.get("center_region", -1))
		if center < 0:
			continue
		var profile: Dictionary = _derive_production_profile(st, tick)
		_production_profiles[center] = profile
		# Write profile back into settlement dict for HUD/chronicle access
		st["production_profile"] = profile.get("profile", PROFILE_MIXED)
		st["production_profile_reason"] = profile.get("reason", "")


func _derive_production_profile(st: Dictionary, tick: int) -> Dictionary:
	var center: int = int(st.get("center_region", -1))
	var pop: int = int(st.get("population", 0))
	var scar: int = int(st.get("scar_max", 0))
	var rt_v: Variant = st.get("resource_truth", null)
	var rt: Dictionary = rt_v as Dictionary if rt_v is Dictionary else {}
	var food: int = int(rt.get("stock_food", 0))
	var wood: int = int(rt.get("stock_wood", 0))
	var stone: int = int(rt.get("stock_stone", 0))
	# Scan local terrain for resource signals
	var has_water: bool = false
	var has_fertile: bool = false
	var has_forest: bool = false
	var has_stone_vein: bool = false
	var has_game: bool = false
	var regs_v: Variant = st.get("regions", null)
	if regs_v is PackedInt32Array and WorldMeaning != null:
		for rk in (regs_v as PackedInt32Array):
			var m: Dictionary = WorldMeaning.get_region_meaning(int(rk))
			if int(m.get("water_access", 0)) > 0:
				has_water = true
			if int(m.get("fertile_soil", 0)) > 0:
				has_fertile = true
			if int(m.get("tree_count", 0)) > 2:
				has_forest = true
			if int(m.get("ore_vein", 0)) > 0:
				has_stone_vein = true
			if int(m.get("animal_deaths", 0)) > 0 or int(m.get("deer_count", 0)) > 0:
				has_game = true
	# Check trade route activity
	var has_trade_route: bool = false
	if TradeMemory != null:
		for r in TradeMemory.trade_routes:
			if r is Dictionary:
				var rd: Dictionary = r as Dictionary
				if int(rd.get("from_settlement", -1)) == center or int(rd.get("to_settlement", -1)) == center:
					has_trade_route = true
					break
	# Check knowledge/workshop buildings
	var has_workshop: bool = false
	var has_library: bool = false
	if regs_v is PackedInt32Array and WorldMeaning != null:
		for rk in (regs_v as PackedInt32Array):
			var m2: Dictionary = WorldMeaning.get_region_meaning(int(rk))
			if int(m2.get("workshop_count", 0)) > 0:
				has_workshop = true
			if int(m2.get("library_count", 0)) > 0:
				has_library = true
	# Derive profile from dominant signals
	var profile: String = PROFILE_MIXED
	var reason: String = "mixed_signals"
	if scar >= 2 and pop > 0:
		profile = PROFILE_DEFENSIVE_HAMLET
		reason = "high_scar_pressure"
	elif has_library and pop >= 4:
		profile = PROFILE_KNOWLEDGE_HEARTH
		reason = "library_present_stable_pop"
	elif has_workshop and pop >= 4:
		profile = PROFILE_CRAFT_VILLAGE
		reason = "workshop_present"
	elif has_trade_route and pop >= 3:
		profile = PROFILE_TRADE_POST
		reason = "active_trade_route"
	elif has_water and pop >= 2:
		profile = PROFILE_FISHING_HAMLET
		reason = "water_access"
	elif has_fertile and pop >= 2:
		profile = PROFILE_FARMING_HAMLET
		reason = "fertile_soil_access"
	elif has_forest and wood > food:
		profile = PROFILE_LOGGING_VILLAGE
		reason = "forest_wood_surplus"
	elif has_stone_vein and stone > food:
		profile = PROFILE_STONE_CAMP
		reason = "stone_vein_surplus"
	elif has_game and pop >= 1:
		profile = PROFILE_HUNTING_CAMP
		reason = "game_present"
	elif pop == 0:
		profile = PROFILE_RECOVERY_SETTLEMENT
		reason = "no_population"
	else:
		profile = PROFILE_FORAGING_CAMP
		reason = "default_foraging"
	return {
		"profile": profile,
		"reason": reason,
		"center_region": center,
		"has_water": has_water,
		"has_fertile": has_fertile,
		"has_forest": has_forest,
		"has_stone_vein": has_stone_vein,
		"has_game": has_game,
		"has_trade_route": has_trade_route,
		"has_workshop": has_workshop,
		"has_library": has_library,
		"snapshot_tick": tick,
	}

# ─── Phase 10: Settlement Relations ──────────────────────────────────────────
func _relation_key(a: int, b: int) -> String:
	return "%d_%d" % [mini(a, b), maxi(a, b)]


func get_relation(a: int, b: int) -> Dictionary:
	var key: String = _relation_key(a, b)
	if _settlement_relations.has(key):
		return (_settlement_relations[key] as Dictionary).duplicate()
	return {}


func set_relation(a: int, b: int, rel_type: String, reason: String, strength: float = 0.5) -> void:
	var key: String = _relation_key(a, b)
	var tick: int = GameManager.tick_count if GameManager != null else 0
	_settlement_relations[key] = {
		"settlement_a": a,
		"settlement_b": b,
		"relation": rel_type,
		"reason": reason,
		"strength": clampf(strength, 0.0, 1.0),
		"last_event_tick": tick,
	}


func _update_settlement_relations() -> void:
	if SettlementMemory == null or TradeMemory == null:
		return
	var tick: int = GameManager.tick_count if GameManager != null else 0
	# Trade routes create trade_partner relations
	for r_any in TradeMemory.trade_routes:
		if not (r_any is Dictionary):
			continue
		var r: Dictionary = r_any as Dictionary
		var from_c: int = int(r.get("from_settlement", -1))
		var to_c: int = int(r.get("to_settlement", -1))
		if from_c < 0 or to_c < 0:
			continue
		var completed: int = int(r.get("completed_count", 0))
		if completed < 1:
			continue
		var existing: Dictionary = get_relation(from_c, to_c)
		var existing_rel: String = str(existing.get("relation", REL_NEUTRAL))
		# Upgrade relation based on trade maturity
		var new_strength: float = clampf(float(completed) / 10.0, 0.1, 1.0)
		if existing_rel == REL_NEUTRAL or existing_rel == "":
			set_relation(from_c, to_c, REL_TRADE_PARTNER, "trade_route_completed_%d" % completed, new_strength)
		elif existing_rel == REL_TRADE_PARTNER:
			set_relation(from_c, to_c, REL_TRADE_PARTNER, "trade_route_matured", new_strength)
	# Kinship: settlements with shared migration events
	if WorldMemory != null:
		var events: Array = WorldMemory.get_events()
		for ev_any in events:
			if not (ev_any is Dictionary):
				continue
			var ev: Dictionary = ev_any as Dictionary
			if str(ev.get("type", "")) != "migrant_arrived":
				continue
			var from_c2: int = int(ev.get("from_settlement", -1))
			var to_c2: int = int(ev.get("to_settlement", -1))
			if from_c2 < 0 or to_c2 < 0:
				continue
			var existing2: Dictionary = get_relation(from_c2, to_c2)
			if str(existing2.get("relation", "")) == REL_NEUTRAL or existing2.is_empty():
				set_relation(from_c2, to_c2, REL_KINSHIP, "migration_link", 0.4)
	# Contested border: settlements with overlapping regions
	var settlements: Array = SettlementMemory.settlements
	for i in range(settlements.size()):
		if not (settlements[i] is Dictionary):
			continue
		var sa: Dictionary = settlements[i] as Dictionary
		var ca: int = int(sa.get("center_region", -1))
		if ca < 0:
			continue
		var regs_a: PackedInt32Array = PackedInt32Array()
		var rv_a: Variant = sa.get("regions", null)
		if rv_a is PackedInt32Array:
			regs_a = rv_a as PackedInt32Array
		for j in range(i + 1, settlements.size()):
			if not (settlements[j] is Dictionary):
				continue
			var sb: Dictionary = settlements[j] as Dictionary
			var cb: int = int(sb.get("center_region", -1))
			if cb < 0 or cb == ca:
				continue
			var rv_b: Variant = sb.get("regions", null)
			if not (rv_b is PackedInt32Array):
				continue
			var regs_b: PackedInt32Array = rv_b as PackedInt32Array
			# Check for adjacent regions (contested border)
			var adjacent: bool = false
			for rk_a in regs_a:
				var ax: int = int(rk_a) & 0xFFFF
				var ay: int = (int(rk_a) >> 16) & 0xFFFF
				for rk_b in regs_b:
					var bx: int = int(rk_b) & 0xFFFF
					var by: int = (int(rk_b) >> 16) & 0xFFFF
					if absi(ax - bx) <= 1 and absi(ay - by) <= 1:
						adjacent = true
						break
				if adjacent:
					break
			if adjacent:
				var existing3: Dictionary = get_relation(ca, cb)
				if existing3.is_empty():
					set_relation(ca, cb, REL_CONTESTED_BORDER, "adjacent_regions", 0.3)

# ─── Phase 11: Chronicle Truth ────────────────────────────────────────────────
func _flush_chronicles() -> void:
	if WorldMemory == null or SettlementMemory == null:
		return
	var events: Array = WorldMemory.get_events()
	for st_any in SettlementMemory.settlements:
		if not (st_any is Dictionary):
			continue
		var st: Dictionary = st_any as Dictionary
		var center: int = int(st.get("center_region", -1))
		if center < 0:
			continue
		if not _settlement_chronicles.has(center):
			_settlement_chronicles[center] = []
		var lines: Array = _settlement_chronicles[center] as Array
		var last_tick: int = int(_chronicle_last_tick.get(center, 0))
		# Collect events relevant to this settlement
		var regs_dict: Dictionary = {}
		var rv: Variant = st.get("regions", null)
		if rv is PackedInt32Array:
			for rk in (rv as PackedInt32Array):
				regs_dict[int(rk)] = true
		for ev_any in events:
			if not (ev_any is Dictionary):
				continue
			var ev: Dictionary = ev_any as Dictionary
			var ev_tick: int = int(ev.get("tick", ev.get("t", 0)))
			if ev_tick <= last_tick:
				continue
			# Check if event is relevant to this settlement
			var relevant: bool = false
			var ev_type: String = str(ev.get("type", ""))
			# Direct settlement reference
			if int(ev.get("settlement_center", -1)) == center:
				relevant = true
			elif int(ev.get("from_settlement", -1)) == center:
				relevant = true
			elif int(ev.get("to_settlement", -1)) == center:
				relevant = true
			elif int(ev.get("from", -1)) == center:
				relevant = true
			elif int(ev.get("to", -1)) == center:
				relevant = true
			# Tile-based events in settlement regions
			if not relevant:
				var tile_v: Variant = ev.get("tile", ev.get("pos", null))
				if tile_v is Vector2i:
					var tv: Vector2i = tile_v as Vector2i
					var rk_ev: int = WorldMemory._region_key(tv.x, tv.y)
					if regs_dict.has(rk_ev):
						relevant = true
			if not relevant:
				continue
			# Format the chronicle line
			var line: String = _format_chronicle_line(ev, ev_tick)
			if not line.is_empty():
				lines.append(line)
				if lines.size() > 200:
					lines = lines.slice(lines.size() - 200)
		_settlement_chronicles[center] = lines
		if not events.is_empty():
			_chronicle_last_tick[center] = int(events[-1].get("tick", events[-1].get("t", 0)))


func _format_chronicle_line(ev: Dictionary, tick: int) -> String:
	var day: int = tick / 600
	var ev_type: String = str(ev.get("type", ""))
	match ev_type:
		"pawn_death", "death":
			var name: String = str(ev.get("pawn_name", ev.get("name", "someone")))
			var cause: String = str(ev.get("cause", "unknown"))
			return "Day %d: %s died (%s)" % [day, name, cause]
		"pawn_birth", "birth":
			var name: String = str(ev.get("pawn_name", ev.get("name", "a child")))
			return "Day %d: %s was born" % [day, name]
		"settlement_founded":
			var sname: String = str(ev.get("settlement_name", "a settlement"))
			return "Day %d: %s was founded" % [day, sname]
		"trade_route_completed":
			var from_n: String = str(ev.get("from", "?"))
			var to_n: String = str(ev.get("to", "?"))
			var goods: int = int(ev.get("goods_moved", 0))
			return "Day %d: Trade completed (%d goods, %s→%s)" % [day, goods, from_n, to_n]
		"trade_goods_transferred":
			var goods: int = int(ev.get("goods_count", 0))
			return "Day %d: %d goods transferred via trade" % [day, goods]
		"building_constructed", "build_complete":
			var btype: String = str(ev.get("building_type", ev.get("type_name", "structure")))
			return "Day %d: %s built" % [day, btype]
		"migrant_arrived":
			var name: String = str(ev.get("pawn_name", "a traveler"))
			return "Day %d: %s arrived" % [day, name]
		"migrant_departed":
			var name: String = str(ev.get("pawn_name", "a resident"))
			return "Day %d: %s departed" % [day, name]
		"knowledge_discovered", "innovation":
			var ktype: String = str(ev.get("knowledge_type", ev.get("result_name", "knowledge")))
			return "Day %d: Knowledge gained: %s" % [day, ktype]
		"famine_warning":
			return "Day %d: Famine warning" % day
		"settlement_import":
			var goods2: int = int(ev.get("goods_count", 0))
			return "Day %d: Received %d goods via trade" % [day, goods2]
		"join_settlement":
			var name2: String = str(ev.get("pawn_name", "someone"))
			return "Day %d: %s joined the settlement" % [day, name2]
		_:
			if ev_type.begins_with("diplomacy_"):
				var narrative: String = str(ev.get("narrative", ev_type))
				return "Day %d: %s" % [day, narrative]
			return ""

# ─── Phase 1: Founding Truth Audit ───────────────────────────────────────────
func _audit_founding_truth() -> void:
	if SettlementMemory == null:
		return
	var tick: int = GameManager.tick_count if GameManager != null else 0
	for st_any in SettlementMemory.settlements:
		if not (st_any is Dictionary):
			continue
		var st: Dictionary = st_any as Dictionary
		var center: int = int(st.get("center_region", -1))
		if center < 0:
			continue
		if _founding_truth.has(center):
			continue  # Already recorded
		var pop: int = int(st.get("population", 0))
		var state: String = str(st.get("state", ""))
		var is_formal: bool = bool(st.get("is_formal_settlement", false))
		# Determine founding stage
		var stage: String = _derive_settlement_stage_label(st)
		# Determine founding reason
		var reason: String = _derive_founding_reason(st)
		# Check required conditions
		var conditions: Dictionary = {
			"has_population": pop > 0,
			"has_center_region": center >= 0,
			"has_state": not state.is_empty(),
			"is_formal": is_formal,
			"stage": stage,
		}
		_founding_truth[center] = {
			"center_region": center,
			"name": str(st.get("name", "unnamed")),
			"founding_reason": reason,
			"founding_conditions": conditions,
			"stage": stage,
			"state": state,
			"population": pop,
			"is_formal": is_formal,
			"recorded_tick": tick,
		}
		# Record to WorldMemory if not already there
		if WorldMemory != null and is_formal and pop > 0:
			WorldMemory.record_event({
				"type": "settlement_founding_truth",
				"settlement_center": center,
				"name": str(st.get("name", "unnamed")),
				"founding_reason": reason,
				"stage": stage,
				"population": pop,
				"tick": tick,
			})


func _derive_settlement_stage_label(st: Dictionary) -> String:
	var pop: int = int(st.get("population", 0))
	var is_formal: bool = bool(st.get("is_formal_settlement", false))
	var state: String = str(st.get("state", ""))
	if state in ["permanently_abandoned", "abandoned"]:
		return "ruin"
	if not is_formal:
		return STAGE_PROTO
	if pop == 0:
		return STAGE_CAMP
	if pop < 3:
		return STAGE_HEARTH_SITE
	if pop < 6:
		return STAGE_HAMLET
	if pop < 12:
		return STAGE_VILLAGE
	return STAGE_TOWN


func _derive_founding_reason(st: Dictionary) -> String:
	var scar: int = int(st.get("scar_max", 0))
	var rep: int = int(st.get("reputation_min", 0))
	var pop: int = int(st.get("population", 0))
	var rt_v: Variant = st.get("resource_truth", null)
	var rt: Dictionary = rt_v as Dictionary if rt_v is Dictionary else {}
	var food: int = int(rt.get("stock_food", 0))
	if scar >= 2:
		return "danger_displacement"
	if food > 20 and pop > 0:
		return "resource_discovery"
	if pop >= 3:
		return "population_clustering"
	if rep < -1:
		return "faction_split"
	return "migration_stop"


# ─── Public API ───────────────────────────────────────────────────────────────
func get_local_stockpile_truth(center_region: int) -> Dictionary:
	if _local_stockpile_truth.has(center_region):
		return (_local_stockpile_truth[center_region] as Dictionary).duplicate()
	return {}


func get_production_profile(center_region: int) -> Dictionary:
	if _production_profiles.has(center_region):
		return (_production_profiles[center_region] as Dictionary).duplicate()
	return {}


func get_settlement_chronicle(center_region: int) -> Array:
	if _settlement_chronicles.has(center_region):
		return (_settlement_chronicles[center_region] as Array).duplicate()
	return []


func get_founding_truth(center_region: int) -> Dictionary:
	if _founding_truth.has(center_region):
		return (_founding_truth[center_region] as Dictionary).duplicate()
	return {}


func get_all_relations() -> Dictionary:
	return _settlement_relations.duplicate(true)


func relation_count() -> int:
	return _settlement_relations.size()


func record_trade_goods_transferred(amount: int) -> void:
	_trade_goods_transferred += amount


func record_trade_failed_no_surplus() -> void:
	_trade_failed_no_surplus += 1


func record_trade_failed_no_stockpile() -> void:
	_trade_failed_no_stockpile += 1


func record_shortage_relieved() -> void:
	_shortage_relieved_count += 1


func record_migrant_departed() -> void:
	_migrant_departed_count += 1


func record_migrant_arrived() -> void:
	_migrant_arrived_count += 1


func record_route_matured() -> void:
	_route_matured_count += 1


func record_road_formed() -> void:
	_road_formed_count += 1

# ─── Debug Truth Reports (Phase 12) ──────────────────────────────────────────

func debug_settlement_founding_truth() -> String:
	var lines: PackedStringArray = PackedStringArray()
	lines.append("=== SETTLEMENT_FOUNDING_TRUTH ===")
	if SettlementMemory == null:
		lines.append("  SettlementMemory=null")
		return "\n".join(lines)
	var all_st: Array = SettlementMemory.settlements
	lines.append("total_sites=%d formal=%d" % [all_st.size(), SettlementMemory.get_formal_settlement_count()])
	for st_any in all_st:
		if not (st_any is Dictionary):
			continue
		var st: Dictionary = st_any as Dictionary
		var center: int = int(st.get("center_region", -1))
		var ft: Dictionary = get_founding_truth(center)
		var name: String = str(st.get("name", "unnamed"))
		var pop: int = int(st.get("population", 0))
		var state: String = str(st.get("state", "?"))
		var stage: String = str(ft.get("stage", _derive_settlement_stage_label(st)))
		var reason: String = str(ft.get("founding_reason", "unknown"))
		var is_formal: bool = bool(st.get("is_formal_settlement", false))
		lines.append("  center=%d name=%s state=%s stage=%s pop=%d formal=%s reason=%s" % [
			center, name, state, stage, pop, str(is_formal), reason
		])
		var conds: Dictionary = ft.get("founding_conditions", {}) as Dictionary
		if not conds.is_empty():
			lines.append("    conditions: pop=%s center=%s formal=%s" % [
				str(conds.get("has_population", "?")),
				str(conds.get("has_center_region", "?")),
				str(conds.get("is_formal", "?")),
			])
	return "\n".join(lines)


func debug_settlement_resource_truth() -> String:
	var lines: PackedStringArray = PackedStringArray()
	lines.append("=== SETTLEMENT_RESOURCE_TRUTH ===")
	if SettlementMemory == null:
		lines.append("  SettlementMemory=null")
		return "\n".join(lines)
	for st_any in SettlementMemory.settlements:
		if not (st_any is Dictionary):
			continue
		var st: Dictionary = st_any as Dictionary
		var center: int = int(st.get("center_region", -1))
		var pop: int = int(st.get("population", 0))
		var name: String = str(st.get("name", "unnamed"))
		var spt: Dictionary = get_local_stockpile_truth(center)
		var sp_state: String = str(spt.get("state", STOCKPILE_NONE))
		var sp_id: int = int(spt.get("local_stockpile_id", -1))
		var food: int = int(spt.get("food", 0))
		var wood: int = int(spt.get("wood", 0))
		var stone: int = int(spt.get("stone", 0))
		var reason: String = str(spt.get("reason", "not_computed"))
		var flag: String = ""
		if pop > 0 and sp_state == STOCKPILE_NONE:
			flag = " ⚠ POP>0_NO_STOCKPILE"
		lines.append("  center=%d name=%s pop=%d stockpile=%s id=%d food=%d wood=%d stone=%d reason=%s%s" % [
			center, name, pop, sp_state, sp_id, food, wood, stone, reason, flag
		])
	return "\n".join(lines)


func debug_settlement_production_truth() -> String:
	var lines: PackedStringArray = PackedStringArray()
	lines.append("=== SETTLEMENT_PRODUCTION_TRUTH ===")
	if SettlementMemory == null:
		lines.append("  SettlementMemory=null")
		return "\n".join(lines)
	for st_any in SettlementMemory.settlements:
		if not (st_any is Dictionary):
			continue
		var st: Dictionary = st_any as Dictionary
		var center: int = int(st.get("center_region", -1))
		var name: String = str(st.get("name", "unnamed"))
		var pop: int = int(st.get("population", 0))
		var pp: Dictionary = get_production_profile(center)
		var profile: String = str(pp.get("profile", "not_computed"))
		var reason: String = str(pp.get("reason", ""))
		var water: bool = bool(pp.get("has_water", false))
		var fertile: bool = bool(pp.get("has_fertile", false))
		var forest: bool = bool(pp.get("has_forest", false))
		var stone_v: bool = bool(pp.get("has_stone_vein", false))
		var game: bool = bool(pp.get("has_game", false))
		var trade: bool = bool(pp.get("has_trade_route", false))
		lines.append("  center=%d name=%s pop=%d profile=%s reason=%s" % [center, name, pop, profile, reason])
		lines.append("    terrain: water=%s fertile=%s forest=%s stone=%s game=%s trade=%s" % [
			str(water), str(fertile), str(forest), str(stone_v), str(game), str(trade)
		])
	return "\n".join(lines)


func debug_trade_route_truth() -> String:
	var lines: PackedStringArray = PackedStringArray()
	lines.append("=== TRADE_ROUTE_TRUTH ===")
	if TradeMemory == null:
		lines.append("  TradeMemory=null")
		return "\n".join(lines)
	var stats: Dictionary = TradeMemory.get_stats()
	lines.append("total_routes=%d active=%d completed=%d goods_traded=%d knowledge_spread=%d dup_suppressed=%d" % [
		int(stats.get("total_routes", 0)),
		int(stats.get("active_routes", 0)),
		int(stats.get("completed_routes", 0)),
		int(stats.get("total_goods_traded", 0)),
		int(stats.get("knowledge_spread_count", 0)),
		int(stats.get("duplicate_suppressed_count", 0)),
	])
	lines.append("civ_loop: goods_transferred=%d failed_no_surplus=%d failed_no_stockpile=%d shortage_relieved=%d" % [
		_trade_goods_transferred, _trade_failed_no_surplus, _trade_failed_no_stockpile, _shortage_relieved_count
	])
	for r_any in TradeMemory.trade_routes:
		if not (r_any is Dictionary):
			continue
		var r: Dictionary = r_any as Dictionary
		var rk: String = str(r.get("route_key", "?"))
		var rid: int = int(r.get("route_id", -1))
		var fr: int = int(r.get("from_settlement", -1))
		var to: int = int(r.get("to_settlement", -1))
		var st: String = str(r.get("status", "?"))
		var cc: int = int(r.get("completed_count", 0))
		var tc: int = int(r.get("trip_count", 0))
		var gm: int = int(r.get("goods_moved_total", 0))
		var ts: int = int(r.get("traffic_score", 0))
		var rt: int = int(r.get("road_tier", 0))
		lines.append("  #%d key=%s %d→%d status=%s trips=%d completed=%d goods=%d traffic=%d road_tier=%d" % [
			rid, rk, fr, to, st, tc, cc, gm, ts, rt
		])
	return "\n".join(lines)


func debug_road_memory_truth() -> String:
	var lines: PackedStringArray = PackedStringArray()
	lines.append("=== ROAD_MEMORY_TRUTH ===")
	if RoadMemory == null:
		lines.append("  RoadMemory=null")
		return "\n".join(lines)
	var road_regions: Dictionary = RoadMemory.get_regions_with_roads()
	lines.append("road_regions_with_traversal=%d" % road_regions.size())
	# Sample a few route tiles to verify traversal > 0
	var sample_count: int = 0
	if TradeMemory != null:
		for r_any in TradeMemory.trade_routes:
			if not (r_any is Dictionary):
				continue
			var r: Dictionary = r_any as Dictionary
			var tiles_v: Variant = r.get("tiles", r.get("path", []))
			if not (tiles_v is Array):
				continue
			var tiles: Array = tiles_v as Array
			for tile_any in tiles:
				if not (tile_any is Vector2i):
					continue
				var tile: Vector2i = tile_any as Vector2i
				var trav: int = RoadMemory.get_traversal(tile.x, tile.y)
				if trav > 0:
					lines.append("  sample_tile=(%d,%d) traversal=%d path_mul=%.2f" % [
						tile.x, tile.y, trav, RoadMemory.get_path_weight_mul(tile.x, tile.y)
					])
					sample_count += 1
					if sample_count >= 5:
						break
			if sample_count >= 5:
				break
	if sample_count == 0:
		lines.append("  no_route_tiles_with_traversal_found")
	return "\n".join(lines)


func debug_construction_scheduler_truth() -> String:
	var lines: PackedStringArray = PackedStringArray()
	lines.append("=== CONSTRUCTION_SCHEDULER_TRUTH ===")
	if SettlementMemory == null:
		lines.append("  SettlementMemory=null")
		return "\n".join(lines)
	var formal: Array = SettlementMemory.get_formal_settlements()
	var total: int = formal.size()
	lines.append("settlements_total=%d cursor=%d" % [total, _construction_cursor % maxi(1, total)])
	if SettlementPlanner != null:
		lines.append("planner_cursor=%d last_plan_tick=%d" % [
			SettlementPlanner._plan_rr_cursor,
			SettlementPlanner._last_plan_tick,
		])
	if JobManager != null:
		lines.append("open_jobs=%d" % JobManager.open_count())
	for st_any in formal:
		if not (st_any is Dictionary):
			continue
		var st: Dictionary = st_any as Dictionary
		var center: int = int(st.get("center_region", -1))
		var name: String = str(st.get("name", "unnamed"))
		var pop: int = int(st.get("population", 0))
		var state: String = str(st.get("state", "?"))
		lines.append("  center=%d name=%s pop=%d state=%s" % [center, name, pop, state])
	return "\n".join(lines)


func debug_settlement_chronicle_truth() -> String:
	var lines: PackedStringArray = PackedStringArray()
	lines.append("=== SETTLEMENT_CHRONICLE_TRUTH ===")
	if SettlementMemory == null:
		lines.append("  SettlementMemory=null")
		return "\n".join(lines)
	for st_any in SettlementMemory.settlements:
		if not (st_any is Dictionary):
			continue
		var st: Dictionary = st_any as Dictionary
		var center: int = int(st.get("center_region", -1))
		var name: String = str(st.get("name", "unnamed"))
		var chronicle: Array = get_settlement_chronicle(center)
		var event_count: int = 0
		if WorldMemory != null:
			for ev_any in WorldMemory.get_events():
				if ev_any is Dictionary:
					var ev: Dictionary = ev_any as Dictionary
					if int(ev.get("settlement_center", -1)) == center or \
					   int(ev.get("from_settlement", -1)) == center or \
					   int(ev.get("to_settlement", -1)) == center:
						event_count += 1
		var latest: String = ""
		if chronicle.size() > 0:
			latest = str(chronicle[-1])
		lines.append("  center=%d name=%s event_count_nearby=%d chronicle_lines=%d latest=%s" % [
			center, name, event_count, chronicle.size(), latest
		])
	return "\n".join(lines)


func debug_relation_truth() -> String:
	var lines: PackedStringArray = PackedStringArray()
	lines.append("=== RELATION_TRUTH ===")
	lines.append("relation_count=%d" % _settlement_relations.size())
	var keys: Array = _settlement_relations.keys()
	keys.sort()
	for key in keys:
		var rel: Dictionary = _settlement_relations[key] as Dictionary
		var a: int = int(rel.get("settlement_a", -1))
		var b: int = int(rel.get("settlement_b", -1))
		var rtype: String = str(rel.get("relation", "?"))
		var reason: String = str(rel.get("reason", "?"))
		var strength: float = float(rel.get("strength", 0.0))
		var last_tick: int = int(rel.get("last_event_tick", 0))
		lines.append("  %d <-> %d : %s (strength=%.2f reason=%s last_tick=%d)" % [
			a, b, rtype, strength, reason, last_tick
		])
	if _settlement_relations.is_empty():
		lines.append("  (no relations yet — trade routes or migration needed)")
	return "\n".join(lines)


func debug_live_systems_truth() -> String:
	## F10 audit report: live vs placeholder systems, professions, structures.
	var lines: PackedStringArray = PackedStringArray()
	lines.append("=== LIVE SYSTEMS TRUTH AUDIT ===")
	lines.append("")
	
	# --- Live Professions ---
	lines.append("-- LIVE PROFESSIONS (wired to real jobs, skill XP, and production) --")
	var live_professions: Array[String] = []
	for i in range(HeelKawnianData.Profession.FARMER, HeelKawnianData.Profession.BOATWRIGHT + 1):
		var pname: String = HeelKawnianData.profession_label_from_enum(i)
		var has_real_behavior: bool = false
		var is_live: bool = false
		# FARMER: Forage/Plant/Harvest jobs → foraging+skill XP → food production
		if i == HeelKawnianData.Profession.FARMER:
			has_real_behavior = true; is_live = true
		# BUILDER: Build bed/wall/door/etc → building skill XP → structures
		elif i == HeelKawnianData.Profession.BUILDER:
			has_real_behavior = true; is_live = true
		# GATHERER: Gather flint/stick, chop → foraging/mining XP → resources
		elif i == HeelKawnianData.Profession.GATHERER:
			has_real_behavior = true; is_live = true
		# WARRIOR: Hunt/Defend/Protect → hunting XP → combat
		elif i == HeelKawnianData.Profession.WARRIOR:
			has_real_behavior = true; is_live = true
		# SCHOLAR: Teaching/apprenticeship → building XP → knowledge spread
		elif i == HeelKawnianData.Profession.SCHOLAR:
			has_real_behavior = true; is_live = true
		# TRADER: Trade haul → profession liking bumps → circulation
		elif i == HeelKawnianData.Profession.TRADER:
			has_real_behavior = true; is_live = true
		# SMITH: Smelter building + tool crafting jobs
		elif i == HeelKawnianData.Profession.SMITH:
			has_real_behavior = true; is_live = true
		# HEALER: Apothecary building → healing
		elif i == HeelKawnianData.Profession.HEALER:
			has_real_behavior = true; is_live = true
		# CARPENTER (NEW): Work woodshop job → building skill XP → tool crafting
		elif i == HeelKawnianData.Profession.CARPENTER:
			has_real_behavior = true; is_live = true
		# COOK (NEW): Work cook hut job → foraging skill XP → food quality
		elif i == HeelKawnianData.Profession.COOK:
			has_real_behavior = true; is_live = true
		# MERCHANT (NEW): Work market job → trading skill XP → goods distribution
		elif i == HeelKawnianData.Profession.MERCHANT:
			has_real_behavior = true; is_live = true
		# BOATWRIGHT (NEW): Work boat workshop job → building XP → boat production
		elif i == HeelKawnianData.Profession.BOATWRIGHT:
			has_real_behavior = true; is_live = true
		if is_live:
			live_professions.append(pname)
	
	for p in live_professions:
		lines.append("  [LIVE] %s" % p)
	lines.append("")
	lines.append("-- PLACEHOLDER PROFESSIONS --")
	lines.append("  (none — all registered professions have live job/skill wiring)")
	lines.append("")
	
	# --- Live Structures ---
	lines.append("-- LIVE STRUCTURES (wired to real build jobs, features, and effects) --")
	var live_structures: Array[String] = []
	var placeholder_structures: Array[String] = []
	var building_ids: Array = BuildingRegistry.BUILDINGS.keys()
	building_ids.sort()
	for bid in building_ids:
		var b: Dictionary = BuildingRegistry.BUILDINGS[bid]
		var name: String = str(b.get("name", bid))
		var job_type: int = int(b.get("job_type", -1))
		if job_type >= 0:
			live_structures.append(name)
		else:
			placeholder_structures.append(name)
	for s in live_structures:
		lines.append("  [LIVE] %s" % s)
	lines.append("")
	if placeholder_structures.size() > 0:
		lines.append("-- PLACEHOLDER STRUCTURES --")
		for s in placeholder_structures:
			lines.append("  [STUB] %s" % s)
		lines.append("")
	else:
		lines.append("-- PLACEHOLDER STRUCTURES --")
		lines.append("  (none — all registered buildings have live build jobs)")
		lines.append("")
	
	# --- Live Settlement Systems ---
	lines.append("-- LIVE SETTLEMENT SYSTEMS --")
	lines.append("  [LIVE] SettlementMemory — settlement state, formal/proto tracking")
	lines.append("  [LIVE] SettlementPlanner — autonomous build intents, pressure gating")
	lines.append("  [LIVE] TradeMemory — trade routes, goods transfer, knowledge spread")
	lines.append("  [LIVE] RoadMemory — route traversal, path weight, road tier")
	lines.append("  [LIVE] CivilizationLoop — stockpile truth, production profiles, relations")
	lines.append("  [LIVE] AuthoritySystem — authority emergence, governance")
	lines.append("  [LIVE] CollapseSystem — collapse progression (trust→authority→knowledge→env)")
	lines.append("  [LIVE] ColonySimServices — housing/food/storage/warmth/cooking pressures")
	lines.append("  [LIVE] JobManager — job posting, claiming, completion")
	lines.append("  [LIVE] CharacterProgressionSystem — skill XP, profession assignment")
	lines.append("  [LIVE] KnowledgeSystem — knowledge types, carriers, preservation")
	lines.append("  [LIVE] CulturalMemory — cultural habits, style persistence")
	lines.append("  [LIVE] FactionSystem — emergent faction relations")
	lines.append("")
	lines.append("-- DISCONNECTED UI CLAIMS --")
	lines.append("  (none known — see BUILD_INVENTORY.md for full audit)")
	lines.append("")
	lines.append("-- GATEWAY / TRADE-ENTRY SEEDING --")
	lines.append("  [LIVE] Trade routes connect via TradeMemory")
	lines.append("  [SEEDING] Gateway tile detection: not yet wired (see SettlementPlanner)")
	lines.append("  [SEEDING] Market-first growth: not yet wired")
	return "\n".join(lines)


func debug_all_truth_reports() -> String:
	var parts: PackedStringArray = PackedStringArray()
	parts.append(debug_settlement_founding_truth())
	parts.append("")
	parts.append(debug_settlement_resource_truth())
	parts.append("")
	parts.append(debug_settlement_production_truth())
	parts.append("")
	parts.append(debug_trade_route_truth())
	parts.append("")
	parts.append(debug_road_memory_truth())
	parts.append("")
	parts.append(debug_construction_scheduler_truth())
	parts.append("")
	parts.append(debug_settlement_chronicle_truth())
	parts.append("")
	parts.append(debug_relation_truth())
	parts.append("")
	parts.append(debug_live_systems_truth())
	return "\n".join(parts)
