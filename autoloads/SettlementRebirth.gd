extends Node
## v1: Revivable settlements may receive one new pawn per [const REBIRTH_INTERVAL_TICKS] after long peace.
## Read-only inputs; [PawnSpawner] only. Deterministic. Not saved (session-only last-rebirth keys).

# --- Playtest tuning: rebirth spawn (HUD/digest uses get_rebirth_eligibility same constants) ---
# CHECK_INTERVAL_TICKS — align with planner/memory dirty cadence (SettlementPlanner.PLANNING_INTERVAL_TICKS).
# REBIRTH_PEACE_TICKS — floor on “quiet since last pawn death” before spawn; actual threshold is max with branch peace.
# REBIRTH_INTERVAL_TICKS — session cooldown per center_region between successful spawns.
# TILE_SCORE_* — deterministic tile ordering for spawn site (structure / scar / road / trade / distance).
const CHECK_INTERVAL_TICKS: int = 1000
const REBIRTH_PEACE_TICKS: int = 5000
const REBIRTH_INTERVAL_TICKS: int = 20000
const REBIRTH_SPAWN_BASE_COUNT: int = 2
const REBIRTH_SPAWN_COUNT_VARIANCE: int = 2  # deterministic 2..3 cohort size
const TILE_SCORE_STRUCT_NEIGHBOR: int = 85
const TILE_SCORE_SCAR_WEIGHT: int = 40
const TILE_SCORE_ROAD_WEIGHT: int = 120
const TILE_SCORE_TRADE_WEIGHT: int = 90
const TILE_SCORE_DISTANCE_WEIGHT: int = 1
## Rebuild scored rebirth tiles periodically (or when settlement signature changes).
const TILE_CACHE_REFRESH_TICKS: int = 10000

## Session-only: [code]String(center_region_key) -> int[/code] last tick we spawned a rebirth pawn.
var _last_rebirth_tick_by_center: Dictionary = {}
var _last_check_tick: int = -1_000_000_000
## center_region key -> {"sig": int, "built_tick": int, "tiles": Array[Vector2i]}
var _rebirth_tiles_cache_by_center: Dictionary = {}


## Run on the same cadence as [SettlementMemory] + [SettlementPlanner] (after dirty flush, same interval gating).
func process(world: World, main: Node2D, from_memory_dirty: bool) -> void:
	if world == null or not is_instance_valid(world) or world.data == null or main == null:
		return
	if not from_memory_dirty:
		var t0: int = GameManager.tick_count
		if t0 - _last_check_tick < CHECK_INTERVAL_TICKS:
			return
	_last_check_tick = GameManager.tick_count
	var ps: PawnSpawner = main.get_node_or_null("PawnSpawner") as PawnSpawner
	if ps == null:
		return
	var alive0: int = 0
	for p in ps.pawns:
		if p != null and is_instance_valid(p) and p.data != null:
			alive0 += 1
	var eligible: Array[Dictionary] = _gather_eligible_settlements()
	if eligible.is_empty():
		return
	_prune_rebirth_tile_cache(eligible)
	_sort_settlements_rebirth_order(eligible)
	var now1: int = GameManager.tick_count
	for s in eligible:
		var gate: Dictionary = get_rebirth_eligibility(world, s)
		if not bool(gate.get("ok", false)):
			continue
		var ckey: int = int(s.get("center_region", -1))
		if ckey < 0:
			continue
		# === Assign biome-driven cultural style if not yet assigned ===
		if CulturalStyleManager != null:
			var first_region: int = -1
			var regions_var: Variant = s.get("regions", null)
			if regions_var is PackedInt32Array:
				var regions_arr: PackedInt32Array = regions_var as PackedInt32Array
				if regions_arr.size() > 0:
					first_region = int(regions_arr[0])
			if first_region >= 0:
				var style: Dictionary = CulturalStyleManager.get_or_assign_style(ckey, world, first_region)
				if OS.is_debug_build():
					print("[Culture] Settlement %d adopted style '%s' for region %d" % [ckey, style.get("style_name", "Unknown"), first_region])
		# === End style assignment ===
		var ck2: String = str(ckey)
		if _last_rebirth_tick_by_center.has(ck2):
			if (now1 - int(_last_rebirth_tick_by_center[ck2])) < REBIRTH_INTERVAL_TICKS:
				continue
		var cands0: Array[Vector2i] = _rebirth_tiles_in_order_cached(world, s)
		if cands0.is_empty():
			continue
		var center_region: int = int(s.get("center_region", -1))
		var derived: Dictionary = _derive_tradition_from_history(s)
		var inherited: Dictionary = CulturalMemory.stack_tradition(center_region, derived)
		s["tradition"] = inherited
		if OS.is_debug_build() and GameManager.verbose_logs():
			print("[Memory] Settlement %d inherited tradition: [Branch=%s, Taboo=%s]" % [
				center_region,
				str(inherited.get("preferred_tech_branch", "")),
				str(inherited.get("taboo_jobs", [])),
			])
		var spawn_target: int = _rebirth_spawn_target_count(now1, ckey)
		var seed0: int = now1 + ckey * 7 + 11
		var spawned_count: int = 0
		var attempt_index: int = 0
		for tspawn0 in cands0:
			if spawned_count >= spawn_target:
				break
			var spawn_seed: int = seed0 + attempt_index * 31 + spawned_count * 97
			attempt_index += 1
			if ps.spawn_pawn_at(world, tspawn0, spawn_seed, s, "rebirth"):
				spawned_count += 1
		if spawned_count <= 0:
			continue
		_last_rebirth_tick_by_center[ck2] = now1
		MythMemory.register_rebirth_success(ckey)
		WorldMemory.record_event({
			"type": "settlement_rebirth",
			"tick": now1,
			"center_region": ckey,
			"spawned_count": spawned_count,
			"culture_name": str(s.get("culture_name", "")),
			"state": str(s.get("state", "")),
			"tradition": inherited.duplicate(true),
		})


func _rebirth_spawn_target_count(now_tick: int, center_region: int) -> int:
	var parity: int = int((now_tick / maxi(1, REBIRTH_INTERVAL_TICKS)) + center_region)
	return REBIRTH_SPAWN_BASE_COUNT + int(abs(parity) % REBIRTH_SPAWN_COUNT_VARIANCE)


func _rebirth_tiles_in_order_cached(world: World, settlement: Dictionary) -> Array[Vector2i]:
	var center: int = int(settlement.get("center_region", -1))
	if center < 0:
		return []
	var key: String = str(center)
	var now: int = GameManager.tick_count
	var sig: int = _rebirth_tile_cache_signature(settlement)
	var rec_v: Variant = _rebirth_tiles_cache_by_center.get(key, null)
	if rec_v is Dictionary:
		var rec: Dictionary = rec_v as Dictionary
		var rec_sig: int = int(rec.get("sig", -1))
		var built_tick: int = int(rec.get("built_tick", -1_000_000_000))
		if rec_sig == sig and (now - built_tick) < TILE_CACHE_REFRESH_TICKS:
			var tiles_v: Variant = rec.get("tiles", [])
			if tiles_v is Array:
				var cached: Array[Vector2i] = []
				for t_any in tiles_v as Array:
					if t_any is Vector2i:
						cached.append(t_any as Vector2i)
				if not cached.is_empty():
					return cached
	var computed: Array[Vector2i] = _rebirth_tiles_in_order(world, settlement)
	var store_tiles: Array = []
	for tile in computed:
		store_tiles.append(tile)
	_rebirth_tiles_cache_by_center[key] = {
		"sig": sig,
		"built_tick": now,
		"tiles": store_tiles,
	}
	return computed


func _rebirth_tile_cache_signature(settlement: Dictionary) -> int:
	var sig: int = 17
	sig = sig * 31 + int(settlement.get("center_region", -1))
	sig = sig * 31 + int(settlement.get("scar_max", 0))
	sig = sig * 31 + int(settlement.get("revival_score", 0))
	sig = sig * 31 + int(settlement.get("last_pawn_death_tick", -1))
	var reg_v: Variant = settlement.get("regions", null)
	if reg_v is PackedInt32Array:
		var regs: PackedInt32Array = reg_v as PackedInt32Array
		sig = sig * 31 + regs.size()
		for rk_any in regs:
			sig = int(((sig * 1103515245) + int(rk_any) + 12345) & 0x7FFFFFFF)
	return sig


func _prune_rebirth_tile_cache(eligible: Array[Dictionary]) -> void:
	var keep: Dictionary = {}
	for st in eligible:
		var center: int = int(st.get("center_region", -1))
		if center >= 0:
			keep[str(center)] = true
	for key_any in _rebirth_tiles_cache_by_center.keys():
		var key: String = str(key_any)
		if not keep.has(key):
			_rebirth_tiles_cache_by_center.erase(key)


func get_rebirth_eligibility(world: World, settlement: Dictionary) -> Dictionary:
	var now: int = GameManager.tick_count
	var state_now: String = str(settlement.get("state", ""))
	# Accept both revivable AND recovering states for rebirth spawning
	# Canonical flow: abandoned → revivable → recovering → active
	# Both revivable and recovering settlements can receive new pawns
	if state_now != "revivable" and state_now != "recovering":
		return {"ok": false, "reason": "state_not_revivable_or_recovering"}
	var scar_max: int = int(settlement.get("scar_max", 0))
	if scar_max >= 3:
		return {"ok": false, "reason": "scar_level_gte_3"}
	var culture_type: int = int(settlement.get("culture_type", SettlementPlanner.CULTURE_CAUTIOUS))
	var branch_peace: int = SettlementMemory.get_peace_ticks_for_culture_branch(culture_type)
	var peace_threshold: int = maxi(REBIRTH_PEACE_TICKS, branch_peace)
	var last_conflict_tick: int = int(settlement.get("last_pawn_death_tick", -1))
	var recent_conflict_ticks: int = 1_000_000_000 if last_conflict_tick < 0 else maxi(0, now - last_conflict_tick)
	if recent_conflict_ticks < peace_threshold:
		return {
			"ok": false,
			"reason": "recent_conflict_under_peace_threshold",
			"recent_conflict_ticks": recent_conflict_ticks,
			"peace_threshold": peace_threshold,
		}
	# Additional hard block: cluster currently contains scar >= 3 region.
	var regv: Variant = settlement.get("regions", null)
	if regv is PackedInt32Array:
		for rk_any in regv as PackedInt32Array:
			var rk: int = int(rk_any)
			if int(WorldPersistence.get_region_persistence(rk).get("scar_level", 0)) >= 3:
				return {"ok": false, "reason": "cluster_contains_scar3"}
	return {
		"ok": true,
		"reason": "eligible",
		"recent_conflict_ticks": recent_conflict_ticks,
		"peace_threshold": peace_threshold,
	}


func _gather_eligible_settlements() -> Array[Dictionary]:
	var out2: Array[Dictionary] = []
	for st in SettlementMemory.settlements:
		if st is not Dictionary:
			continue
		var d: Dictionary = st as Dictionary
		var state_str: String = str(d.get("state", ""))
		# Accept both revivable AND recovering states (canonical flow)
		if state_str != "revivable" and state_str != "recovering":
			continue
		var reg2: Variant = d.get("regions", null)
		if not (reg2 is PackedInt32Array):
			continue
		var pack2: PackedInt32Array = reg2 as PackedInt32Array
		if pack2.is_empty():
			continue
		out2.append(d)
	return out2


func _derive_tradition_from_history(settlement: Dictionary) -> Dictionary:
	var center_region: int = int(settlement.get("center_region", -1))
	var events: Array[Dictionary] = WorldMemory.get_recent_events_for_settlement(center_region, 512, true)
	var farm_research_count: int = 0
	var metallurgy_research_count: int = 0
	var violent_deaths: int = 0
	for ev in events:
		var typ: String = str(ev.get("type", "")).to_lower()
		if typ == "technology_researched":
			var tech_id: String = str(ev.get("tech_id", ev.get("technology", ""))).to_lower()
			if tech_id.find("agri") >= 0 or tech_id.find("farm") >= 0 or tech_id.find("food") >= 0:
				farm_research_count += 1
			if tech_id.find("metal") >= 0:
				metallurgy_research_count += 1
		elif typ == "pawn_death" or typ == "enemy_death":
			violent_deaths += 1
	var preferred_branch: String = "agriculture"
	var branch_score: int = farm_research_count
	if metallurgy_research_count > farm_research_count:
		preferred_branch = "metallurgy"
		branch_score = metallurgy_research_count
	var taboo_jobs: Array[String] = []
	if violent_deaths >= 3:
		taboo_jobs = ["HUNT"]
	var naming_convention: String = "nordic"
	if preferred_branch == "metallurgy":
		naming_convention = "latin"
	elif violent_deaths >= 5:
		naming_convention = "highland"
	return {
		"preferred_tech_branch": preferred_branch,
		"taboo_jobs": taboo_jobs,
		"naming_convention": naming_convention,
		"branch_bias_score": branch_score,
		"violence_score": violent_deaths,
	}


## Smallest [code]last_activity_tick[/code] (missing/invalid -> sentinel so they sort first), then [code]center_region[/code].
func _sort_settlements_rebirth_order(arr: Array[Dictionary]) -> void:
	arr.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ac: int = int(a.get("center_region", -1))
		var bc: int = int(b.get("center_region", -1))
		var ap: float = float(IntentMemory.settlement_pressure.get(ac, 1.0))
		var bp: float = float(IntentMemory.settlement_pressure.get(bc, 1.0))
		if ap != bp:
			return ap < bp
		var ascar: int = int(a.get("scar_max", 99))
		var bscar: int = int(b.get("scar_max", 99))
		if ascar != bscar:
			return ascar < bscar
		var arep: int = int(a.get("reputation_min", -99))
		var brep: int = int(b.get("reputation_min", -99))
		if arep != brep:
			return arep > brep
		var at: int = int(a.get("last_activity_tick", -1))
		var bt: int = int(b.get("last_activity_tick", -1))
		var an: int = at if at >= 0 else -2_000_000_000
		var bn: int = bt if bt >= 0 else -2_000_000_000
		if an != bn:
			return an < bn
		ac = int(a.get("center_region", 0))
		bc = int(b.get("center_region", 0))
		return ac < bc
	)


## 4-adj to BED/WALL/DOOR first, then any valid passable non-RUIN tile. Each group: Manhattan, then y*W+x.
## Order is total [code]PawnSpawner[/code] tries; first successful spawn wins.
func _rebirth_tiles_in_order(world: World, settlement: Dictionary) -> Array[Vector2i]:
	var out_ar: Array[Vector2i] = []
	var reg1: Variant = settlement.get("regions", null)
	if not (reg1 is PackedInt32Array):
		return out_ar
	var regions0: PackedInt32Array = reg1 as PackedInt32Array
	if regions0.is_empty():
		return out_ar
	var center_rk0: int = int(settlement.get("center_region", -1))
	if center_rk0 < 0:
		return out_ar
	var cxi: int = (center_rk0 & 0xFFFF) * 16 + 8
	var cyi: int = ((center_rk0 >> 16) & 0xFFFF) * 16 + 8
	var center_t: Vector2i = Vector2i(cxi, cyi)
	var in_cluster: Dictionary = {}
	for u in range(regions0.size()):
		in_cluster[int(regions0[u])] = true
	var comp0: int = world.pathfinder.largest_component_id()
	if comp0 < 0:
		return out_ar
	var struct_tiles0: Dictionary = {}
	var by_linear: Dictionary = {}
	for rk_any in regions0:
		var rkx: int = int(rk_any)
		var srx: int = rkx & 0xFFFF
		var sry: int = (rkx >> 16) & 0xFFFF
		for dy0 in 16:
			for dx0 in 16:
				var t0: Vector2i = Vector2i(srx * 16 + dx0, sry * 16 + dy0)
				if not world.data.in_bounds(t0.x, t0.y):
					continue
				var f0: int = int(world.data.get_feature(t0.x, t0.y))
				if f0 == int(TileFeature.Type.BED) or f0 == int(TileFeature.Type.WALL) or f0 == int(TileFeature.Type.DOOR):
					struct_tiles0[t0] = true
					continue
				if not _tile_ok_base(world, t0, comp0, in_cluster):
					continue
				by_linear[t0.y * WorldData.WIDTH + t0.x] = t0
	if by_linear.is_empty():
		return out_ar
	var scored: Array[Dictionary] = []
	for idx_k in by_linear:
		var tc: Vector2i = by_linear[idx_k] as Vector2i
		scored.append({
			"tile": tc,
			"score": _score_rebirth_tile(world, tc, center_t, struct_tiles0),
			"idx": int(idx_k),
		})
	scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var sa: int = int(a.get("score", 0))
		var sb: int = int(b.get("score", 0))
		if sa != sb:
			return sa > sb
		return int(a.get("idx", 0)) < int(b.get("idx", 0))
	)
	for rec in scored:
		out_ar.append(rec.get("tile", Vector2i.ZERO) as Vector2i)
	return out_ar


func _score_rebirth_tile(
		_world: World,
		t: Vector2i,
		center: Vector2i,
		struct_tiles: Dictionary
) -> int:
	var score: int = 0
	var trk: int = WorldMemory._region_key(t.x, t.y)
	var scar_level: int = int(WorldPersistence.get_region_persistence(trk).get("scar_level", 0))
	score += maxi(0, 3 - scar_level) * TILE_SCORE_SCAR_WEIGHT
	var is_struct_neighbor: bool = false
	for d0 in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if struct_tiles.has(t + d0):
			is_struct_neighbor = true
			break
	if is_struct_neighbor:
		score += TILE_SCORE_STRUCT_NEIGHBOR
	var road_mul: float = RoadMemory.get_path_weight_mul(t.x, t.y)
	var trade_mul: float = TradeMemory.get_trade_path_weight_mul(t.x, t.y)
	score += int(round((1.12 - road_mul) * TILE_SCORE_ROAD_WEIGHT))
	score += int(round((1.10 - trade_mul) * TILE_SCORE_TRADE_WEIGHT))
	var mdist: int = abs(t.x - center.x) + abs(t.y - center.y)
	score -= mdist * TILE_SCORE_DISTANCE_WEIGHT
	return score


func _tile_ok_base(
		world: World, t: Vector2i, comp0: int, in_cluster: Dictionary
) -> bool:
	if not PawnSpawner.SPAWNABLE_BIOMES.has(world.data.get_biome(t.x, t.y)):
		return false
	if not world.pathfinder.is_passable(t):
		return false
	if int(world.data.get_feature(t.x, t.y)) == int(TileFeature.Type.RUIN):
		return false
	if world.pathfinder.component_of(t) != comp0:
		return false
	var trk0: int = WorldMemory._region_key(t.x, t.y)
	if not in_cluster.has(trk0):
		return false
	if int(WorldPersistence.get_region_persistence(trk0).get("scar_level", 0)) >= 3:
		return false
	return true
