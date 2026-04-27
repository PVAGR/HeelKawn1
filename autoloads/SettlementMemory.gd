extends Node
## v1: Settlement identity — 4-adjacent clusters of scarred, historically
## active regions. Derived only; read WorldMeaning, WorldPersistence, CulturalMemory.
## Does not keep references to [World] ([recompute] takes it for API symmetry with peers).
## "state" is one of: abandoned, permanently_abandoned, revivable, dormant (revival v1, not saved).

const KIND_PAWN_DEATH: int = 0
## Irreversible collapse: recent (within this window) max scar + worst rep.
const HARD_COLLAPSE_TICKS: int = 30000
## Revival tuning: moderately scarred but quiet regions may reopen.
const REVIVABLE_SCAR_MAX: int = 2
const REVIVABLE_REPUTATION_MIN: int = -1
## Deterministic peace requirements by culture branch.
const PEACE_TICKS_PER_BRANCH: Dictionary = {
	SettlementPlanner.CULTURE_OPEN: 18000,
	SettlementPlanner.CULTURE_CAUTIOUS: 30000,
	SettlementPlanner.CULTURE_DEFENSIVE: 42000,
}
## Deterministic score gates.
const REVIVAL_SCORE_RECOVERING_MIN: int = 35
const REVIVAL_SCORE_REVIVABLE_MIN: int = 70
const REVIVAL_SCORE_ACTIVE_MIN: int = 88
const INTENT_UPDATE_INTERVAL_TICKS: int = 100
const MIN_INTENT_DWELL_TICKS: int = 2000
const CRITICAL_LOCAL_FOOD_PRESSURE: float = 0.9
const LOCAL_HOUSING_PAWNS_PER_REGION: float = 2.0
const LOCAL_HOUSING_PRESSURE_THRESHOLD: float = 0.8
const FRONT_UPDATE_INTERVAL_TICKS: int = 200
const FRONT_CLUSTER_RADIUS_TILES: int = 8
const FRONT_INFLUENCE_RADIUS_TILES: int = 10
const FRONT_MAX_COUNT: int = 2
const FRONT_BIAS_MAX: float = 1.1
const FRONT_PERSISTENCE_WINDOW_TICKS: int = 600
const FRONT_DECAY_TICKS: int = 200
const MIN_FRONT_SUPPORT: int = 1
const FRONT_SUPPORT_CHECK_RADIUS_TILES: int = 8
const RESOURCE_PRESSURE_UPDATE_INTERVAL_TICKS: int = 500
const RESOURCE_PRESSURE_SATURATION: float = 0.75
## Work-focus specialization identity is derived ONLY from cached [resource_pressure]
## (job-demand proxy). It is NOT true stock scarcity; read-only for HUD/diagnostics.
const SPECIALIZATION_PHASE_UNKNOWN: String = "UNKNOWN"
const SPECIALIZATION_PHASE_CANDIDATE: String = "CANDIDATE"
const SPECIALIZATION_PHASE_LOCKED: String = "LOCKED"
const SPECIALIZATION_ENTER_THRESHOLD: float = 0.38
const SPECIALIZATION_EXIT_THRESHOLD: float = 0.22
const SPECIALIZATION_MIN_MARGIN: float = 0.12
const SPECIALIZATION_ENTER_STABILITY_TICKS: int = 2000
const SPECIALIZATION_EXIT_STABILITY_TICKS: int = 2500
const INTENT_GROW: String = "GROW"
const INTENT_HOARD: String = "HOARD"
const INTENT_DEFEND: String = "DEFEND"
const INTENT_RECOVER: String = "RECOVER"

var settlements: Array = []
## center_region -> hysteresis for settlement [state] material truth (survives settlement dict rebuilds).
var _settlement_state_truth_hysteresis: Dictionary = {}
## Align with [Main.REBIRTH_CHECK_INTERVAL_TICKS]: one hysteresis step per recompute pass.
const STATE_TRUTH_HYSTERESIS_INTERVAL_TICKS: int = 2000
## Require this many ticks at the same raw target before committing (anti-flicker).
const STATE_TRUTH_HYSTERESIS_COMMIT_TICKS: int = 4000
## --- Validation harness (debug builds): controlled lab sessions ---
## Console marker proving this binary includes the smoketest wiring; bump when observability changes.
const VALIDATION_RUNTIME_SMOKE_MARKER: String = "PVAGR/HeelKawn1-validation-smoketest-2026-04-27-r1"
## One switch: suppresses economy-distorting world events (see WorldEvents), enables settlement-truth verify logs, enables coarse specialization validation logs.
const VALIDATION_SESSION_ENABLED: bool = true
## Piecemeal: settlement truth [SETTLEMENT_VERIFY] without full session (still requires debug build).
const SETTLEMENT_STATE_TRUTH_VERIFY_MODE: bool = false
## Piecemeal: [SPECIALIZATION_VALIDATE] on resource-pressure cadence only (still requires debug build).
const SPECIALIZATION_VALIDATION_LOG_ENABLED: bool = false
## Log a one-line summary per settlement when tick aligns (no per-frame spam).
const SETTLEMENT_STATE_TRUTH_VERIFY_HEARTBEAT_TICKS: int = 20000
## Legacy alias: mirrors settlement-truth verify gate (includes VALIDATION_SESSION_ENABLED).
const SETTLEMENT_STATE_TRUTH_DIAG_ENABLED: bool = (
		SETTLEMENT_STATE_TRUTH_VERIFY_MODE or VALIDATION_SESSION_ENABLED
)
## region_key -> state string (derived cache for O(1) regional queries)
var _region_state: Dictionary = {}
## region_key -> settlement center_region key (derived cache for O(1) intent joins)
var _region_center: Dictionary = {}
## center_region -> governance snapshot hash for change detection.
var _governance_snapshot: Dictionary = {}
## center_region -> whether at-war command announcement already fired for this war state.
var _war_command_announced: Dictionary = {}
## center_region -> whether battle spawn bridge fired for current war state.
var _war_battle_spawned: Dictionary = {}
var _validation_smoketest_autoload_printed: bool = false
var _validation_smoketest_main_printed: bool = false


func _ready() -> void:
	_print_validation_smoketest("SettlementMemory.autoload")


func _print_validation_smoketest(source: String) -> void:
	if source.begins_with("Main"):
		if _validation_smoketest_main_printed:
			return
		_validation_smoketest_main_printed = true
	else:
		if _validation_smoketest_autoload_printed:
			return
		_validation_smoketest_autoload_printed = true
	var dbg: bool = OS.is_debug_build()
	var session_const: bool = VALIDATION_SESSION_ENABLED
	var project_root: String = ProjectSettings.globalize_path("res://")
	var settlement_memory_path: String = ProjectSettings.globalize_path("res://autoloads/SettlementMemory.gd")
	var clean_active: bool = WorldEvents.validation_clean_economy_events_active()
	var truth_active: bool = validation_truth_verify_armed()
	var spec_active: bool = validation_specialization_log_armed()
	print(
			(
					"[VALIDATION_SMOKETEST] marker=%s source=%s debug_build=%s VALIDATION_SESSION_ENABLED_const=%s "
					+ "clean_economy_armed=%s settlement_truth_verify_armed=%s specialization_log_armed=%s"
			)
			% [
				VALIDATION_RUNTIME_SMOKE_MARKER,
				source,
				dbg,
				session_const,
				clean_active,
				truth_active,
				spec_active,
			]
	)
	print(
			"[CANONICAL_RUNTIME_PROOF] project_root=%s settlement_memory_path=%s validation_const=%s clean=%s truth=%s specialization=%s"
			% [
				project_root,
				settlement_memory_path,
				session_const,
				clean_active,
				truth_active,
				spec_active,
			]
	)
	if dbg:
		var canonical_root_hint: String = "C:/Users/user/Documents/GitHub/HeelKawn1"
		var root_norm: String = project_root.replace("\\", "/")
		if not root_norm.contains(canonical_root_hint):
			print(
					"[CANONICAL_ROOT_MISMATCH] EXPECTED_CONTAINS=%s ACTUAL_PROJECT_ROOT=%s ACTUAL_SETTLEMENT_MEMORY=%s"
					% [canonical_root_hint, project_root, settlement_memory_path]
			)


func print_validation_smoketest_from_main() -> void:
	_print_validation_smoketest("Main.gd")


func recompute(_world: World) -> void:
	settlements.clear()
	_region_state.clear()
	_region_center.clear()
	_war_command_announced.clear()
	_war_battle_spawned.clear()
	var living_pawns: Array[Pawn] = _living_pawns()
	var active_jobs: Array[Job] = _active_jobs_snapshot()
	var eligible: Array[int] = []
	for rk_any in WorldMeaning.meaning_by_region.keys():
		var rk: int = int(rk_any)
		var m: Dictionary = WorldMeaning.get_region_meaning(rk)
		if int(m.get("total_deaths", 0)) == 0:
			continue
		if int(WorldPersistence.get_region_persistence(rk).get("scar_level", 0)) < 1:
			continue
		eligible.append(rk)
	eligible.sort()
	if eligible.is_empty():
		return
	var in_eligible: Dictionary = {}
	for e in eligible:
		in_eligible[int(e)] = true
	var visited: Dictionary = {}
	for seed_value in eligible:
		if visited.has(seed_value):
			continue
		var cluster: Array[int] = _bfs_cluster(seed_value, in_eligible, visited)
		cluster.sort()
		var st: Dictionary = _build_settlement_from_regions(cluster)
		var base_state: String = str(st.get("state", "recovering"))
		var raw_state: String = _material_activity_state_override(
				st, _world, living_pawns, active_jobs, base_state
		)
		var center_id: int = int(st.get("center_region", -1))
		st["state"] = _apply_settlement_state_truth_hysteresis(center_id, raw_state, base_state, st)
		settlements.append(st)
		var st_name: String = str(st.get("state", ""))
		var ckr: int = int(st.get("center_region", -1))
		var preg: Variant = st.get("regions", null)
		if preg is PackedInt32Array:
			var pa: PackedInt32Array = preg as PackedInt32Array
			for i in range(pa.size()):
				var rk2: int = int(pa[i])
				_region_state[rk2] = st_name
				_region_center[rk2] = ckr
	settlements.sort_custom(func(a, b) -> bool:
		var ap: Variant = (a as Dictionary).get("regions", null)
		var bp: Variant = (b as Dictionary).get("regions", null)
		if not (ap is PackedInt32Array) or not (bp is PackedInt32Array):
			return false
		var pa: PackedInt32Array = ap as PackedInt32Array
		var pb: PackedInt32Array = bp as PackedInt32Array
		if pa.is_empty() or pb.is_empty():
			return false
		return pa[0] < pb[0]
	)
	_prune_settlement_state_truth_hysteresis()
	_update_governance_state()
	_settlement_truth_verify_post_recompute_pass()


func _prune_settlement_state_truth_hysteresis() -> void:
	var present: Dictionary = {}
	for st_v in settlements:
		if not (st_v is Dictionary):
			continue
		var c: int = int((st_v as Dictionary).get("center_region", -1))
		if c >= 0:
			present[c] = true
	for k in _settlement_state_truth_hysteresis.keys():
		if not present.has(int(k)):
			if _settlement_truth_verify_active():
				print(
						"[SETTLEMENT_VERIFY] tick=%d reason=hysteresis_pruned hyst_key=center_region:%d (settlement absent this recompute)"
						% [GameManager.tick_count, int(k)]
				)
			_settlement_state_truth_hysteresis.erase(k)


func _settlement_truth_verify_active() -> bool:
	return OS.is_debug_build() and (SETTLEMENT_STATE_TRUTH_VERIFY_MODE or VALIDATION_SESSION_ENABLED)


func _specialization_validation_log_active() -> bool:
	return OS.is_debug_build() and (SPECIALIZATION_VALIDATION_LOG_ENABLED or VALIDATION_SESSION_ENABLED)


func validation_harness_flags_for_snapshot() -> Dictionary:
	return {
		"session": OS.is_debug_build() and VALIDATION_SESSION_ENABLED,
		"session_const_requested": VALIDATION_SESSION_ENABLED,
		"os_debug_build": OS.is_debug_build(),
		"settlement_truth_verify": _settlement_truth_verify_active(),
		"specialization_log": _specialization_validation_log_active(),
	}


func validation_truth_verify_armed() -> bool:
	return _settlement_truth_verify_active()


func validation_specialization_log_armed() -> bool:
	return _specialization_validation_log_active()


func _settlement_truth_verify_emit(
		tick: int,
		center_id: int,
		base_state: String,
		raw_state: String,
		committed: String,
		pending: String,
		pend_ticks: int,
		st: Dictionary,
		governance_type: String,
		reason: String
) -> void:
	if not _settlement_truth_verify_active():
		return
	var sp_hits: int = int(st.get("material_stockpile_overlap_hits", 0))
	var sp_note: String = "stockpile=designated_zone_overlap_hits_only(not_loose_items)"
	print(
			(
					"[SETTLEMENT_VERIFY] tick=%d hyst_key=center_region:%d base=%s raw=%s committed=%s pending=%s pend_ticks=%d "
					+ "liv=%d sh=%d wk=%d sp_flag=%d sp_zone_hits=%d %s gov=%s reason=%s"
			)
			% [
				tick,
				center_id,
				base_state,
				raw_state,
				committed,
				pending,
				pend_ticks,
				int(st.get("material_signal_living", 0)),
				int(st.get("material_signal_shelter", 0)),
				int(st.get("material_signal_work", 0)),
				int(st.get("material_signal_stockpile", 0)),
				sp_hits,
				sp_note,
				governance_type,
				reason,
			]
	)


func _settlement_truth_verify_post_recompute_pass() -> void:
	if not _settlement_truth_verify_active():
		return
	var tick: int = GameManager.tick_count
	if tick % SETTLEMENT_STATE_TRUTH_VERIFY_HEARTBEAT_TICKS != 0:
		return
	for st_v in settlements:
		if not (st_v is Dictionary):
			continue
		var st: Dictionary = st_v as Dictionary
		var center_id: int = int(st.get("center_region", -1))
		if center_id < 0:
			continue
		var e_v: Variant = _settlement_state_truth_hysteresis.get(center_id, {})
		var e: Dictionary = {}
		if e_v is Dictionary:
			e = e_v as Dictionary
		_settlement_truth_verify_emit(
				tick,
				center_id,
				str(st.get("state_truth_base_logged", st.get("state_truth_raw", ""))),
				str(st.get("state_truth_raw", "")),
				str(st.get("state", "")),
				str(e.get("pending", "")),
				int(e.get("ticks", 0)),
				st,
				str(st.get("governance_type", "anarchy")),
				"heartbeat"
		)


func _apply_settlement_state_truth_hysteresis(center_id: int, raw_state: String, base_state: String, st: Dictionary) -> String:
	if center_id < 0:
		return raw_state
	var tick: int = GameManager.tick_count
	var prev_committed: String = ""
	var governance_placeholder: String = "n/a_pre_governance"
	if not _settlement_state_truth_hysteresis.has(center_id):
		_settlement_state_truth_hysteresis[center_id] = {
			"committed": raw_state,
			"pending": raw_state,
			"ticks": 0,
			"last_verify_raw": raw_state,
		}
		st["state_truth_base_logged"] = base_state
		if _settlement_truth_verify_active():
			print(
					(
							"[SETTLEMENT_VERIFY] tick=%d reason=hysteresis_new_bucket hyst_key=center_region:%d "
							+ "(watch for prune+recreate churn if this repeats unexpectedly)"
					)
					% [tick, center_id]
			)
			_settlement_truth_verify_emit(
					tick,
					center_id,
					base_state,
					raw_state,
					raw_state,
					raw_state,
					0,
					st,
					governance_placeholder,
					"init"
			)
		return raw_state
	var e: Dictionary = _settlement_state_truth_hysteresis[center_id] as Dictionary
	prev_committed = str(e.get("committed", raw_state))
	var pending_before: String = str(e.get("pending", raw_state))
	var last_logged_raw: String = str(e.get("last_verify_raw", pending_before))
	var acc: int = int(e.get("ticks", 0))
	var reason: String = "steady"
	if raw_state != pending_before:
		e["pending"] = raw_state
		e["ticks"] = 0
		reason = "raw_changed_reset_pending"
	elif raw_state != str(e.get("committed", "")):
		acc += STATE_TRUTH_HYSTERESIS_INTERVAL_TICKS
		e["ticks"] = acc
		if acc >= STATE_TRUTH_HYSTERESIS_COMMIT_TICKS:
			e["committed"] = raw_state
			e["ticks"] = 0
			reason = "pending_reached_commit_threshold"
		else:
			reason = "pending_accumulate"
	else:
		e["ticks"] = 0
		reason = "raw_matches_committed_clear_pending_ticks"
	var committed: String = str(e.get("committed", raw_state))
	var pending_after: String = str(e.get("pending", raw_state))
	e["last_verify_raw"] = raw_state
	_settlement_state_truth_hysteresis[center_id] = e
	st["state_truth_base_logged"] = base_state
	if _settlement_truth_verify_active():
		var committed_changed: bool = committed != prev_committed
		var raw_changed: bool = raw_state != last_logged_raw
		if committed_changed or raw_changed:
			if committed_changed:
				reason = "committed_transition"
			elif raw_changed:
				reason = "raw_changed"
			_settlement_truth_verify_emit(
					tick,
					center_id,
					base_state,
					raw_state,
					committed,
					pending_after,
					int(e.get("ticks", 0)),
					st,
					governance_placeholder,
					reason
			)
	return committed


func _stockpile_zone_overlap_metrics(region_set: Dictionary) -> Dictionary:
	var hits: int = 0
	var overlaps: bool = false
	var max_total_hits: int = 256
	var per_zone_cap: int = 128
	for z in StockpileManager.zones():
		if z == null:
			continue
		var r: Rect2i = z.rect
		var scanned: int = 0
		for y in range(r.position.y, r.position.y + r.size.y):
			for x in range(r.position.x, r.position.x + r.size.x):
				scanned += 1
				if scanned > per_zone_cap:
					break
				var rk: int = WorldMemory._region_key(x, y)
				if region_set.has(rk):
					overlaps = true
					hits += 1
					if hits >= max_total_hits:
						return {"overlaps": overlaps, "hits": hits}
			if scanned > per_zone_cap:
				break
	return {"overlaps": overlaps, "hits": hits}


func _stockpile_zone_overlaps_region_set(region_set: Dictionary) -> bool:
	return bool(_stockpile_zone_overlap_metrics(region_set).get("overlaps", false))


func _material_activity_state_override(
		st: Dictionary,
		world: World,
		living_pawns: Array[Pawn],
		active_jobs: Array[Job],
		base_state: String
) -> String:
	var region_set: Dictionary = {}
	var regv: Variant = st.get("regions", PackedInt32Array())
	if regv is PackedInt32Array:
		for rk in regv as PackedInt32Array:
			region_set[int(rk)] = true
	if region_set.is_empty():
		st["material_signal_living"] = 0
		st["material_signal_shelter"] = 0
		st["material_signal_work"] = 0
		st["material_signal_stockpile"] = 0
		st["material_stockpile_overlap_hits"] = 0
		st["state_truth_raw"] = base_state
		return base_state
	var living_count: int = 0
	for p in living_pawns:
		if p == null or p.data == null:
			continue
		var prk: int = WorldMemory._region_key(p.data.tile_pos.x, p.data.tile_pos.y)
		if region_set.has(prk):
			living_count += 1
	var local_job_count: int = 0
	var local_bed_build_jobs: int = 0
	for j in active_jobs:
		if j == null:
			continue
		var jrk: int = WorldMemory._region_key(j.work_tile.x, j.work_tile.y)
		if not region_set.has(jrk):
			continue
		local_job_count += 1
		if int(j.type) == Job.Type.BUILD_BED:
			local_bed_build_jobs += 1
	var bed_count: int = _count_beds_in_region_set(world, region_set)
	var has_shelter_signal: bool = bed_count > 0 or local_bed_build_jobs > 0
	var has_work_signal: bool = local_job_count > 0
	var sp_metrics: Dictionary = _stockpile_zone_overlap_metrics(region_set)
	var has_stockpile_signal: bool = bool(sp_metrics.get("overlaps", false))
	st["material_stockpile_overlap_hits"] = int(sp_metrics.get("hits", 0))
	st["material_signal_living"] = living_count
	st["material_signal_shelter"] = 1 if has_shelter_signal else 0
	st["material_signal_work"] = local_job_count
	st["material_signal_stockpile"] = 1 if has_stockpile_signal else 0
	# Material colony presence: living pawn(s) plus at least one footprint signal
	# (shelter, local jobs, or stockpile zone overlap). Not stock counts / not scarcity truth.
	var material_colony: bool = (
			living_count >= 1
			and (has_shelter_signal or has_work_signal or has_stockpile_signal)
	)
	if not material_colony:
		st["state_truth_raw"] = base_state
		return base_state
	var raw: String = base_state
	if base_state == "permanently_abandoned":
		if living_count >= 1 and (has_shelter_signal or has_stockpile_signal or local_job_count >= 1):
			raw = "recovering"
		else:
			st["state_truth_raw"] = base_state
			return base_state
	elif living_count >= 1 and has_shelter_signal and (has_work_signal or has_stockpile_signal):
		raw = "active"
	elif living_count >= 2 and (has_shelter_signal or has_work_signal or has_stockpile_signal):
		raw = "active"
	elif base_state == "abandoned":
		raw = "recovering"
	elif base_state == "active" or base_state == "revivable":
		raw = base_state
	else:
		raw = "recovering"
	st["state_truth_raw"] = raw
	return raw


func _count_beds_in_region_set(world: World, region_set: Dictionary) -> int:
	if world == null or world.data == null:
		return 0
	var beds: int = 0
	for rk_any in region_set.keys():
		var rk: int = int(rk_any)
		var c: Vector2i = _coords_from_region_key(rk)
		var min_x: int = c.x * 16
		var min_y: int = c.y * 16
		for y in range(min_y, min_y + 16):
			for x in range(min_x, min_x + 16):
				if not world.data.in_bounds(x, y):
					continue
				if world.data.get_feature(x, y) == TileFeature.Type.BED:
					beds += 1
	return beds


func _bfs_cluster(seed_value: int, in_eligible: Dictionary, visited: Dictionary) -> Array[int]:
	var out: Array[int] = []
	var q: Array[int] = [seed_value]
	visited[seed_value] = true
	var qi: int = 0
	while qi < q.size():
		var rk: int = q[qi]
		qi += 1
		out.append(rk)
		var c: Vector2i = _coords_from_region_key(rk)
		var nbrs: Array[Vector2i] = [
			Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)
		]
		for d in nbrs:
			var nxt: int = _region_key_from_rx_ry(c.x + d.x, c.y + d.y)
			if not in_eligible.has(nxt) or visited.has(nxt):
				continue
			visited[nxt] = true
			q.append(nxt)
	return out


func _coords_from_region_key(rk: int) -> Vector2i:
	return Vector2i(rk & 0xFFFF, (rk >> 16) & 0xFFFF)


func _region_key_from_rx_ry(rx: int, ry: int) -> int:
	return (rx & 0xFFFF) | ((ry & 0xFFFF) << 16)


func _build_settlement_from_regions(cluster: Array) -> Dictionary:
	var total_pawn_deaths: int = 0
	var scar_max: int = 0
	var reputation_min: int = 999999
	var last_activity_tick: int = -1
	for rk_any in cluster:
		var rk: int = int(rk_any)
		var m: Dictionary = WorldMeaning.get_region_meaning(rk)
		total_pawn_deaths += int(m.get("pawn_deaths", 0))
		var sl: int = int(WorldPersistence.get_region_persistence(rk).get("scar_level", 0))
		scar_max = maxi(scar_max, sl)
		var rep: int = CulturalMemory.get_region_reputation(rk)
		reputation_min = mini(reputation_min, rep)
		var ldt: int = int(m.get("last_death_tick", -1))
		last_activity_tick = maxi(last_activity_tick, ldt)
	if reputation_min == 999999:
		reputation_min = 0
	var center_rk: int = _pick_center_region(cluster)
	var last_pawn_death_tick: int = _max_last_pawn_death_tick_in_cluster(cluster)
	var draft: Dictionary = {
		"scar_max": scar_max,
		"reputation_min": reputation_min,
	}
	var culture_type: int = SettlementPlanner.get_culture_type_for_settlement(draft)
	var state: String = _settlement_state_v1(
			scar_max, reputation_min, last_activity_tick, last_pawn_death_tick, culture_type
	)
	var peace_threshold_ticks: int = get_peace_ticks_for_culture_branch(culture_type)
	var ticks_since_collapse: int = _ticks_since_or_large(last_pawn_death_tick)
	var revival_score: int = _deterministic_revival_score(
			ticks_since_collapse, scar_max, ticks_since_collapse, culture_type, reputation_min
	)
	var packed: PackedInt32Array = PackedInt32Array()
	for rk2 in cluster:
		packed.append(int(rk2))
	return {
		"regions": packed,
		"center_region": center_rk,
		"total_pawn_deaths": total_pawn_deaths,
		"scar_max": scar_max,
		"reputation_min": reputation_min,
		"last_activity_tick": last_activity_tick,
		"last_pawn_death_tick": last_pawn_death_tick,
		"culture_type": culture_type,
		"culture_name": SettlementPlanner.get_culture_name_for_settlement(draft),
		"peace_threshold_ticks": peace_threshold_ticks,
		"revival_score": revival_score,
		"state": state,
		"war_status": {
			"state": "peace",
			"target_settlement_id": -1,
			"votes": [],
		},
		"current_intent": INTENT_GROW,
		"last_intent_tick": -1,
		"intent_lock_ticks": 0,
		"preferred_fronts": [],
		"last_front_update_tick": -1,
		"last_front_intent": INTENT_GROW,
		"resource_pressure": _default_resource_pressure(),
		"last_resource_pressure_tick": -1,
		"specialization_phase": SPECIALIZATION_PHASE_UNKNOWN,
		"specialization_channel": "",
		"specialization_candidate_channel": "",
		"specialization_candidate_ticks": 0,
		"specialization_replacement_ticks": 0,
		"specialization_confidence": 0,
	}


func _settlement_state_v1(
		scar_max: int,
		reputation_min: int,
		last_activity_tick: int,
		last_pawn_death_tick: int,
		culture_branch: int
) -> String:
	# Exclusivity:
	# permanently_abandoned > abandoned > recovering > revivable > active.
	var ticks_since_collapse: int = _ticks_since_or_large(last_pawn_death_tick)
	var regional_peace_ticks: int = ticks_since_collapse
	var peace_threshold: int = get_peace_ticks_for_culture_branch(culture_branch)
	if scar_max >= 3:
		if ticks_since_collapse <= HARD_COLLAPSE_TICKS:
			return "abandoned"
		return "permanently_abandoned"
	# Fresh moderate collapse still reads as abandoned.
	if last_activity_tick >= 0 and _ticks_since_or_large(last_activity_tick) < int(HARD_COLLAPSE_TICKS * 0.4):
		return "abandoned"
	var revival_score: int = _deterministic_revival_score(
			ticks_since_collapse, scar_max, regional_peace_ticks, culture_branch, reputation_min
	)
	if revival_score < REVIVAL_SCORE_RECOVERING_MIN:
		return "abandoned"
	if revival_score < REVIVAL_SCORE_REVIVABLE_MIN:
		return "recovering"
	if scar_max <= REVIVABLE_SCAR_MAX and regional_peace_ticks >= peace_threshold:
		if revival_score >= REVIVAL_SCORE_ACTIVE_MIN and scar_max <= 1 and regional_peace_ticks >= peace_threshold * 2:
			return "active"
		return "revivable"
	return "recovering"


func get_peace_ticks_for_culture_branch(culture_branch: int) -> int:
	return int(PEACE_TICKS_PER_BRANCH.get(culture_branch, int(PEACE_TICKS_PER_BRANCH[SettlementPlanner.CULTURE_CAUTIOUS])))


func _ticks_since_or_large(tick_value: int) -> int:
	if tick_value < 0:
		return 1_000_000_000
	return maxi(0, GameManager.tick_count - tick_value)


func _deterministic_revival_score(
		ticks_since_collapse: int,
		scar_level: int,
		regional_peace_ticks: int,
		cultural_branch: int,
		reputation_min: int
) -> int:
	var peace_threshold: int = get_peace_ticks_for_culture_branch(cultural_branch)
	var collapse_component: int = mini(100, int((float(ticks_since_collapse) / float(maxi(1, HARD_COLLAPSE_TICKS * 2))) * 100.0))
	var peace_component: int = mini(100, int((float(regional_peace_ticks) / float(maxi(1, peace_threshold))) * 100.0))
	var scar_penalty: int = scar_level * 25
	var branch_bonus: int = 0
	if cultural_branch == SettlementPlanner.CULTURE_OPEN:
		branch_bonus = 15
	elif cultural_branch == SettlementPlanner.CULTURE_CAUTIOUS:
		branch_bonus = 5
	else:
		branch_bonus = -10
	var rep_bonus: int = clampi(reputation_min * 5, -20, 20)
	return clampi(int((collapse_component + peace_component) / 2) - scar_penalty + branch_bonus + rep_bonus, 0, 100)


func get_settlement_profile(region_key: int) -> Dictionary:
	var settlement: Variant = get_settlement_at_region(region_key)
	if settlement == null or not (settlement is Dictionary):
		return _default_profile(region_key)
	var d: Dictionary = settlement as Dictionary
	var mean: Dictionary = WorldMeaning.get_region_meaning_summary(region_key)
	var pers: Dictionary = WorldPersistence.get_region_persistence(region_key)
	var profile: Dictionary = {
		"region_key": region_key,
		"center_region": int(d.get("center_region", -1)),
		"state": str(d.get("state", "")),
		"culture_type": SettlementPlanner.get_culture_type_for_settlement(d),
		"culture_name": SettlementPlanner.get_culture_name_for_settlement(d),
		"scar_max": int(d.get("scar_max", 0)),
		"reputation_min": int(d.get("reputation_min", 0)),
		"last_activity_tick": int(d.get("last_activity_tick", -1)),
		"last_pawn_death_tick": int(d.get("last_pawn_death_tick", -1)),
		"meaning_label": str(mean.get("meaning_label", "quiet")),
		"death_density": str(mean.get("death_density", "none")),
		"total_deaths": int(mean.get("total_deaths", 0)),
		"scar_level": int(pers.get("scar_level", 0)),
		"recovery_stage": int(pers.get("recovery_stage", 0)),
		"peace_threshold_ticks": int(d.get("peace_threshold_ticks", get_peace_ticks_for_culture_branch(int(d.get("culture_type", SettlementPlanner.CULTURE_CAUTIOUS))))),
		"revival_score": int(d.get("revival_score", 0)),
		"revival_ready": false,
	}
	var state_now: String = str(profile.get("state", ""))
	profile["revival_ready"] = state_now == "revivable"
	return profile


func _default_profile(region_key: int) -> Dictionary:
	return {
		"region_key": region_key,
		"center_region": -1,
		"state": "",
		"culture_type": SettlementPlanner.CULTURE_CAUTIOUS,
		"culture_name": "cautious",
		"scar_max": 0,
		"reputation_min": 0,
		"last_activity_tick": -1,
		"last_pawn_death_tick": -1,
		"meaning_label": "quiet",
		"death_density": "none",
		"total_deaths": 0,
		"scar_level": 0,
		"recovery_stage": 0,
		"peace_threshold_ticks": int(PEACE_TICKS_PER_BRANCH[SettlementPlanner.CULTURE_CAUTIOUS]),
		"revival_score": 0,
		"revival_ready": false,
	}


func _regions_from_settlement(settlement: Dictionary) -> PackedInt32Array:
	var reg: Variant = settlement.get("regions", null)
	if reg is PackedInt32Array:
		return reg as PackedInt32Array
	return PackedInt32Array()


func _max_last_pawn_death_tick_in_regions(regions: PackedInt32Array) -> int:
	if regions.is_empty():
		return -1
	var want: Dictionary = {}
	for rk_any in regions:
		want[int(rk_any)] = true
	var best: int = -1
	var ev: Variant = WorldMemory.to_save_dict().get("events", [])
	if not (ev is Array):
		return best
	for item in ev as Array:
		if not (item is Dictionary):
			continue
		var e: Dictionary = item
		if int(e.get("k", -1)) != KIND_PAWN_DEATH:
			continue
		if not e.has("r"):
			continue
		var rk: int = int(e["r"])
		if not want.has(rk):
			continue
		var t: int = int(e.get("t", 0))
		if t > best:
			best = t
	return best


## True for [abandoned] (recent hard collapse) and [permanently_abandoned] (older hard collapse).
func is_collapsed_state(state: String) -> bool:
	return state == "abandoned" or state == "permanently_abandoned"


## True if [param region_key] lies in a settlement whose current [member settlements] [code]state[/code] is collapsed.
func is_region_in_collapsed_settlement(region_key: int) -> bool:
	if _region_state.has(region_key):
		return is_collapsed_state(str(_region_state[region_key]))
	for st in settlements:
		if st is not Dictionary:
			continue
		var d: Dictionary = st as Dictionary
		if not is_collapsed_state(str(d.get("state", ""))):
			continue
		var reg: Variant = d.get("regions", null)
		if not (reg is PackedInt32Array):
			continue
		var p: PackedInt32Array = reg as PackedInt32Array
		for j in range(p.size()):
			if p[j] == region_key:
				return true
	return false


## Kept for backward compatibility: same as [method is_region_in_collapsed_settlement] (name predates the split state string).
func is_region_in_permanently_abandoned_settlement(region_key: int) -> bool:
	if _region_state.has(region_key):
		return str(_region_state[region_key]) == "permanently_abandoned"
	for st in settlements:
		if st is not Dictionary:
			continue
		var d: Dictionary = st as Dictionary
		if str(d.get("state", "")) != "permanently_abandoned":
			continue
		var reg: Variant = d.get("regions", null)
		if not (reg is PackedInt32Array):
			continue
		var p: PackedInt32Array = reg as PackedInt32Array
		for j in range(p.size()):
			if p[j] == region_key:
				return true
	return false


func get_state_at_region(region_key: int) -> String:
	if _region_state.has(region_key):
		return str(_region_state[region_key])
	return ""


func get_center_region_for_region(region_key: int) -> int:
	if _region_center.has(region_key):
		return int(_region_center[region_key])
	return -1


## Latest pawn death tick in any listed region, or -1 if none.
func _max_last_pawn_death_tick_in_cluster(cluster: Array) -> int:
	var want: Dictionary = {}
	for rk_any in cluster:
		want[int(rk_any)] = true
	var best: int = -1
	var ev: Variant = WorldMemory.to_save_dict().get("events", [])
	if not (ev is Array):
		return best
	for item in ev as Array:
		if not (item is Dictionary):
			continue
		var e: Dictionary = item
		if int(e.get("k", -1)) != KIND_PAWN_DEATH:
			continue
		if not e.has("r"):
			continue
		var rk: int = int(e["r"])
		if not want.has(rk):
			continue
		var t: int = int(e.get("t", 0))
		if t > best:
			best = t
	return best


## Highest [pawn_deaths]; tie-break: lowest [region_key].
func _pick_center_region(cluster: Array) -> int:
	if cluster.is_empty():
		return -1
	var best_k: int = -1
	var best_pd: int = -1
	for rk_any in cluster:
		var rk: int = int(rk_any)
		var pd: int = int(WorldMeaning.get_region_meaning(rk).get("pawn_deaths", 0))
		if pd > best_pd or (pd == best_pd and (best_k < 0 or rk < best_k)):
			best_pd = pd
			best_k = rk
	return best_k


func get_settlements() -> Array:
	return settlements.duplicate(true)


## Duplicated settlement dict, or [null] if this [region_key] is not in any cluster.
func get_settlement_at_region(region_key: int) -> Variant:
	for s in settlements:
		if s is Dictionary:
			var reg: Variant = (s as Dictionary).get("regions", null)
			if reg is PackedInt32Array:
				for i in range((reg as PackedInt32Array).size()):
					if (reg as PackedInt32Array)[i] == region_key:
						return (s as Dictionary).duplicate(true)
	return null


func _update_governance_state() -> void:
	var pawns: Array[Pawn] = _living_pawns()
	for i in range(settlements.size()):
		if not (settlements[i] is Dictionary):
			continue
		var st: Dictionary = settlements[i]
		var gov: Dictionary = _governance_for_settlement(st, pawns)
		var center: int = int(st.get("center_region", -1))
		st["governance_type"] = str(gov.get("type", "anarchy"))
		st["current_ruler_id"] = int(gov.get("ruler_id", -1))
		st["council_ids"] = gov.get("council_ids", PackedInt32Array())
		settlements[i] = st
		if center < 0:
			continue
		var snap: String = "%s|%d|%s" % [
			st["governance_type"],
			int(st["current_ruler_id"]),
			str(st["council_ids"]),
		]
		if str(_governance_snapshot.get(center, "")) != snap:
			_governance_snapshot[center] = snap
			WorldMemory.record_event({
				"type": "governance_change",
				"settlement_id": center,
				"new_ruler_id": int(st["current_ruler_id"]),
				"governance_type": st["governance_type"],
				"council_ids": st["council_ids"],
				"tick": GameManager.tick_count,
			})
		_process_war_state(i, pawns)


func _living_pawns() -> Array[Pawn]:
	var out: Array[Pawn] = []
	var tree: SceneTree = get_tree()
	if tree == null:
		return out
	for n in tree.get_nodes_in_group("pawns"):
		if n is Pawn and is_instance_valid(n):
			out.append(n as Pawn)
	return out


func _governance_for_settlement(st: Dictionary, pawns: Array[Pawn]) -> Dictionary:
	var regv: Variant = st.get("regions", PackedInt32Array())
	if not (regv is PackedInt32Array):
		return {"type": "anarchy", "ruler_id": -1, "council_ids": PackedInt32Array()}
	var regions: PackedInt32Array = regv as PackedInt32Array
	if regions.is_empty():
		return {"type": "anarchy", "ruler_id": -1, "council_ids": PackedInt32Array()}
	var region_set: Dictionary = {}
	for rk in regions:
		region_set[int(rk)] = true
	var ranked: Array[Dictionary] = []
	for p in pawns:
		if p.data == null:
			continue
		var rk: int = WorldMemory._region_key(p.data.tile_pos.x, p.data.tile_pos.y)
		if not region_set.has(rk):
			continue
		ranked.append({
			"id": int(p.data.id),
			"influence": float(p.data.influence),
		})
	if ranked.is_empty():
		return {"type": "anarchy", "ruler_id": -1, "council_ids": PackedInt32Array()}
	# Influence scales with local settlement population.
	for rec in ranked:
		var pid: int = int((rec as Dictionary).get("id", -1))
		for p in pawns:
			if p.data != null and int(p.data.id) == pid:
				(rec as Dictionary)["influence"] = p.data.calculate_influence(ranked.size())
				break
	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ai: float = float(a.get("influence", 0.0))
		var bi: float = float(b.get("influence", 0.0))
		if not is_equal_approx(ai, bi):
			return ai > bi
		return int(a.get("id", 0)) < int(b.get("id", 0))
	)
	if ranked.size() >= 3:
		var i0: float = float(ranked[0].influence)
		var i1: float = float(ranked[1].influence)
		var i2: float = float(ranked[2].influence)
		if absf(i0 - i2) <= maxf(5.0, i0 * 0.05):
			return {
				"type": "council",
				"ruler_id": -1,
				"council_ids": PackedInt32Array([int(ranked[0].id), int(ranked[1].id), int(ranked[2].id)]),
			}
	# Even spread over all participants => anarchy.
	var max_i: float = float(ranked[0].influence)
	var min_i: float = float(ranked[ranked.size() - 1].influence)
	if absf(max_i - min_i) <= maxf(3.0, max_i * 0.03):
		return {"type": "anarchy", "ruler_id": -1, "council_ids": PackedInt32Array()}
	return {"type": "monarchy", "ruler_id": int(ranked[0].id), "council_ids": PackedInt32Array()}


func get_governance_profile_for_region(region_key: int) -> Dictionary:
	var st_v: Variant = get_settlement_at_region(region_key)
	if not (st_v is Dictionary):
		return {"type": "anarchy", "ruler_id": -1, "council_ids": PackedInt32Array()}
	var st: Dictionary = st_v as Dictionary
	return {
		"type": str(st.get("governance_type", "anarchy")),
		"ruler_id": int(st.get("current_ruler_id", -1)),
		"council_ids": st.get("council_ids", PackedInt32Array()),
	}


func is_pawn_current_ruler(pawn_id: int) -> bool:
	for st in settlements:
		if st is Dictionary and int((st as Dictionary).get("current_ruler_id", -1)) == pawn_id:
			return true
	return false


func propose_war_for_pawn(ruler_id: int, target_settlement_id: int) -> bool:
	var src_idx: int = -1
	for i in range(settlements.size()):
		if settlements[i] is Dictionary and int((settlements[i] as Dictionary).get("current_ruler_id", -1)) == ruler_id:
			src_idx = i
			break
	if src_idx < 0 or target_settlement_id < 0 or target_settlement_id >= settlements.size() or src_idx == target_settlement_id:
		return false
	var st: Dictionary = settlements[src_idx] as Dictionary
	var ws: Dictionary = st.get("war_status", {"state": "peace", "target_settlement_id": -1, "votes": []})
	ws["state"] = "proposed"
	ws["target_settlement_id"] = target_settlement_id
	ws["votes"] = []
	st["war_status"] = ws
	settlements[src_idx] = st
	_resolve_war_votes(src_idx)
	return true


func _process_war_state(settlement_idx: int, pawns: Array[Pawn]) -> void:
	if settlement_idx < 0 or settlement_idx >= settlements.size() or not (settlements[settlement_idx] is Dictionary):
		return
	var st: Dictionary = settlements[settlement_idx] as Dictionary
	var ws: Dictionary = st.get("war_status", {"state": "peace", "target_settlement_id": -1, "votes": []})
	var set_pawns: Array[Pawn] = _pawns_in_settlement(st, pawns)
	var center: int = int(st.get("center_region", -1))
	if str(ws.get("state", "peace")) == "at_war":
		_assign_military_hierarchy(set_pawns)
		if center >= 0 and not bool(_war_command_announced.get(center, false)):
			_war_command_announced[center] = true
			print("[War] BattleMaster takes command of forces.")
		if center >= 0 and not bool(_war_battle_spawned.get(center, false)):
			var strength: float = get_settlement_military_score(settlement_idx)
			if _trigger_war_battle_spawn(center, int(ws.get("target_settlement_id", -1)), strength):
				_war_battle_spawned[center] = true
	else:
		if center >= 0:
			_war_command_announced.erase(center)
			_war_battle_spawned.erase(center)
		for p in set_pawns:
			if p.data != null:
				p.data.military_rank = "grunt"


func _resolve_war_votes(settlement_idx: int) -> void:
	if settlement_idx < 0 or settlement_idx >= settlements.size() or not (settlements[settlement_idx] is Dictionary):
		return
	var st: Dictionary = settlements[settlement_idx] as Dictionary
	var ws: Dictionary = st.get("war_status", {"state": "peace", "target_settlement_id": -1, "votes": []})
	var pawns: Array[Pawn] = _pawns_in_settlement(st, _living_pawns())
	if pawns.is_empty():
		ws["state"] = "peace"
		st["war_status"] = ws
		settlements[settlement_idx] = st
		return
	var council: Array[Pawn] = _top_influence(pawns, 5)
	var favor: int = 0
	var against: int = 0
	var vote_records: Array = []
	for p in council:
		var yes_vote: bool = _council_vote_yes(p)
		vote_records.append({"pawn_id": int(p.data.id), "body": "council", "yes": yes_vote})
		if yes_vote:
			favor += 1
		else:
			against += 1
	print("[War] Council Vote: %d-%d in favor. Preparing Messengers..." % [favor, against])
	if favor < 3:
		ws["state"] = "truce"
		ws["votes"] = vote_records
		st["war_status"] = ws
		settlements[settlement_idx] = st
		return
	ws["state"] = "mobilizing"
	var lords: Array[Pawn] = _top_influence_excluding(pawns, 20, council)
	var total_weight: float = 0.0
	var favor_weight: float = 0.0
	for p in lords:
		var loyalty: float = float(p.data.affinities.get("diplomacy", 0.5))
		var kills_proxy: float = float(p.data.tracked_skill_xp("combat")) * 0.01
		var w: float = 1.0 + loyalty + kills_proxy
		var yes_lord: bool = _senate_vote_yes(p)
		total_weight += w
		if yes_lord:
			favor_weight += w
		vote_records.append({"pawn_id": int(p.data.id), "body": "senate", "yes": yes_lord, "weight": w})
	var senate_passed: bool = total_weight > 0.0 and (favor_weight / total_weight) > 0.5
	var target_idx: int = int(ws.get("target_settlement_id", -1))
	if senate_passed and settlement_should_declare_war(settlement_idx, target_idx):
		ws["state"] = "at_war"
	else:
		ws["state"] = "truce"
	ws["votes"] = vote_records
	st["war_status"] = ws
	settlements[settlement_idx] = st
	if ws["state"] == "at_war":
		var set_pawns: Array[Pawn] = _pawns_in_settlement(st, _living_pawns())
		_assign_military_hierarchy(set_pawns)
		var center: int = int(st.get("center_region", -1))
		if center >= 0 and not bool(_war_command_announced.get(center, false)):
			_war_command_announced[center] = true
			print("[War] BattleMaster takes command of forces.")
		if center >= 0 and not bool(_war_battle_spawned.get(center, false)):
			var strength: float = get_settlement_military_score(settlement_idx)
			if _trigger_war_battle_spawn(center, int(ws.get("target_settlement_id", -1)), strength):
				_war_battle_spawned[center] = true


func _pawns_in_settlement(st: Dictionary, pawns: Array[Pawn]) -> Array[Pawn]:
	var regv: Variant = st.get("regions", PackedInt32Array())
	if not (regv is PackedInt32Array):
		return []
	var regs: PackedInt32Array = regv as PackedInt32Array
	var region_set: Dictionary = {}
	for rk in regs:
		region_set[int(rk)] = true
	var out: Array[Pawn] = []
	for p in pawns:
		if p.data == null:
			continue
		var rk: int = WorldMemory._region_key(p.data.tile_pos.x, p.data.tile_pos.y)
		if region_set.has(rk):
			out.append(p)
	return out


func _top_influence(pawns: Array[Pawn], count: int) -> Array[Pawn]:
	var arr: Array[Pawn] = pawns.duplicate()
	arr.sort_custom(func(a: Pawn, b: Pawn) -> bool:
		if a.data == null or b.data == null:
			return false
		if not is_equal_approx(a.data.influence, b.data.influence):
			return a.data.influence > b.data.influence
		return int(a.data.id) < int(b.data.id)
	)
	if arr.size() > count:
		arr.resize(count)
	return arr


func _top_influence_excluding(pawns: Array[Pawn], count: int, excluded: Array[Pawn]) -> Array[Pawn]:
	var blocked: Dictionary = {}
	for p in excluded:
		if p != null and p.data != null:
			blocked[int(p.data.id)] = true
	var filtered: Array[Pawn] = []
	for p in pawns:
		if p.data != null and not blocked.has(int(p.data.id)):
			filtered.append(p)
	return _top_influence(filtered, count)


func _council_vote_yes(p: Pawn) -> bool:
	if p == null or p.data == null:
		return false
	var pressure: float = float(ColonySimServices.get_food_pressure()) + float(ColonySimServices.get_housing_pressure())
	var score: float = p.data.influence * 0.01 + float(p.data.affinities.get("combat", 0.5)) * 1.5 - pressure * 0.3
	return score >= 1.0


func _senate_vote_yes(p: Pawn) -> bool:
	if p == null or p.data == null:
		return false
	var loyalty: float = float(p.data.affinities.get("diplomacy", 0.5))
	var kills_proxy: float = float(p.data.tracked_skill_xp("combat")) * 0.01
	return (loyalty + kills_proxy) >= 0.75


func _assign_military_hierarchy(pawns: Array[Pawn]) -> void:
	if pawns.is_empty():
		return
	var ranked: Array[Dictionary] = []
	for p in pawns:
		if p.data == null:
			continue
		var score: float = float(p.data.influence) + float(p.data.affinities.get("combat", 0.5)) * 100.0
		ranked.append({"pawn": p, "score": score, "id": int(p.data.id)})
	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var sa: float = float(a.get("score", 0.0))
		var sb: float = float(b.get("score", 0.0))
		if not is_equal_approx(sa, sb):
			return sa > sb
		return int(a.get("id", 0)) < int(b.get("id", 0))
	)
	for i in range(ranked.size()):
		var p: Pawn = ranked[i].pawn as Pawn
		if p == null or p.data == null:
			continue
		if i == 0:
			p.data.military_rank = "battlemaster"
		elif i < 4:
			p.data.military_rank = "commander"
		elif i < 14:
			p.data.military_rank = "captain"
		elif i < 34:
			p.data.military_rank = "sarj"
		else:
			p.data.military_rank = "grunt"


func settlement_should_declare_war(src_idx: int, target_idx: int) -> bool:
	if src_idx < 0 or target_idx < 0 or src_idx >= settlements.size() or target_idx >= settlements.size() or src_idx == target_idx:
		return false
	if not (settlements[src_idx] is Dictionary) or not (settlements[target_idx] is Dictionary):
		return false
	var src_st: Dictionary = settlements[src_idx] as Dictionary
	var dst_st: Dictionary = settlements[target_idx] as Dictionary
	var pressure: float = (
		float(ColonySimServices.get_food_pressure())
		+ float(ColonySimServices.get_housing_pressure())
		+ float(ColonySimServices.get_materials_pressure())
		+ float(ColonySimServices.get_haul_pressure())
	) / 4.0
	var living: Array[Pawn] = _living_pawns()
	var src_score: float = _settlement_military_score(_pawns_in_settlement(src_st, living))
	var dst_score: float = _settlement_military_score(_pawns_in_settlement(dst_st, living))
	return pressure >= 0.55 and src_score > dst_score


func _settlement_military_score(pawns: Array[Pawn]) -> float:
	var total: float = 0.0
	for p in pawns:
		if p == null or p.data == null:
			continue
		var combat_aff: float = float(p.data.affinities.get("combat", 0.5))
		var combat_skill: float = float(p.data.tracked_skill_xp("combat"))
		total += float(p.data.influence) + combat_aff * 25.0 + combat_skill * 0.1
	return total


func get_settlement_military_score(settlement_idx: int) -> float:
	if settlement_idx < 0 or settlement_idx >= settlements.size() or not (settlements[settlement_idx] is Dictionary):
		return 0.0
	var st: Dictionary = settlements[settlement_idx] as Dictionary
	return _settlement_military_score(_pawns_in_settlement(st, _living_pawns()))


func _trigger_war_battle_spawn(src_settlement_id: int, target_settlement_id: int, strength: float) -> bool:
	var tree: SceneTree = get_tree()
	if tree == null:
		return false
	var main_node: Node = tree.get_root().get_node_or_null("Main")
	if main_node == null or not main_node.has_method("trigger_war_battle_spawn"):
		return false
	return bool(main_node.call("trigger_war_battle_spawn", src_settlement_id, target_settlement_id, strength))


func get_war_profile_for_region(region_key: int) -> Dictionary:
	var st_v: Variant = get_settlement_at_region(region_key)
	if not (st_v is Dictionary):
		return {"state": "peace", "target_settlement_id": -1, "votes": []}
	var st: Dictionary = st_v as Dictionary
	var ws: Dictionary = st.get("war_status", {"state": "peace", "target_settlement_id": -1, "votes": []})
	return ws.duplicate(true)


func update_settlement_intents(tick: int) -> void:
	if tick % INTENT_UPDATE_INTERVAL_TICKS != 0:
		return
	var living_pawns: Array[Pawn] = _living_pawns()
	for i in range(settlements.size()):
		if not (settlements[i] is Dictionary):
			continue
		var st: Dictionary = settlements[i] as Dictionary
		var settlement_pawns: Array[Pawn] = _pawns_in_settlement(st, living_pawns)
		var local_food_pressure: float = _calculate_local_food_pressure(settlement_pawns)
		var local_housing_pressure: float = _calculate_local_housing_pressure(st, settlement_pawns)
		var war_state: String = str((st.get("war_status", {"state": "peace"}) as Dictionary).get("state", "peace"))
		var is_emergency: bool = local_food_pressure >= CRITICAL_LOCAL_FOOD_PRESSURE or war_state == "mobilizing" or war_state == "at_war"
		var lock_ticks: int = int(st.get("intent_lock_ticks", 0))
		if is_emergency and lock_ticks > 0:
			lock_ticks = 0
			st["intent_lock_ticks"] = 0
		elif lock_ticks > 0:
			lock_ticks = maxi(0, lock_ticks - INTENT_UPDATE_INTERVAL_TICKS)
			st["intent_lock_ticks"] = lock_ticks
			st["last_intent_tick"] = tick
			settlements[i] = st
			continue
		var old_intent: String = str(st.get("current_intent", INTENT_GROW))
		var new_intent: String = _derive_settlement_intent(st, local_food_pressure, local_housing_pressure)
		st["last_intent_tick"] = tick
		if old_intent != new_intent:
			st["current_intent"] = new_intent
			st["intent_lock_ticks"] = MIN_INTENT_DWELL_TICKS
			WorldMemory.record_event({
				"type": "settlement_intent_shift",
				"settlement_id": int(st.get("center_region", -1)),
				"old_intent": old_intent,
				"new_intent": new_intent,
				"tick": tick,
				"settlement_state": str(st.get("state", "unknown")),
				"war_state": war_state,
				"local_food_pressure": local_food_pressure,
				"local_housing_pressure": local_housing_pressure,
				"intent_lock_ticks": int(st.get("intent_lock_ticks", 0)),
			})
		settlements[i] = st


func _derive_settlement_intent(st: Dictionary, local_food_pressure: float, local_housing_pressure: float) -> String:
	var settlement_state: String = str(st.get("state", ""))
	var war_state: String = str((st.get("war_status", {"state": "peace"}) as Dictionary).get("state", "peace"))
	if settlement_state == "recovering" or settlement_state == "revivable":
		return INTENT_RECOVER
	if war_state == "mobilizing" or war_state == "at_war":
		return INTENT_DEFEND
	if local_food_pressure >= 0.55:
		return INTENT_HOARD
	if local_housing_pressure >= LOCAL_HOUSING_PRESSURE_THRESHOLD:
		return INTENT_RECOVER
	return INTENT_GROW


func _calculate_local_food_pressure(pawns: Array[Pawn]) -> float:
	if pawns.is_empty():
		return 0.0
	var hunger_sum: float = 0.0
	var count: int = 0
	for p in pawns:
		if p == null or p.data == null:
			continue
		# PawnData.hunger is 0..100 with higher=better (less hungry),
		# so pressure is inverse normalized hunger.
		hunger_sum += clamp(p.data.hunger, 0.0, 100.0)
		count += 1
	if count <= 0:
		return 0.0
	var avg_hunger: float = hunger_sum / float(count)
	return clamp(1.0 - (avg_hunger / 100.0), 0.0, 1.0)


func _calculate_local_housing_pressure(st: Dictionary, pawns: Array[Pawn]) -> float:
	if pawns.size() < 2:
		return 0.0
	var regv: Variant = st.get("regions", PackedInt32Array())
	if not (regv is PackedInt32Array):
		return 0.0
	var regions: PackedInt32Array = regv as PackedInt32Array
	var region_count: int = regions.size()
	if region_count <= 0:
		return 0.0
	# Coarse local crowding proxy: local population versus settlement footprint.
	var comfort_capacity: float = float(region_count) * LOCAL_HOUSING_PAWNS_PER_REGION
	if comfort_capacity <= 0.0:
		return 0.0
	var crowding_ratio: float = float(pawns.size()) / comfort_capacity
	return clamp(crowding_ratio - 1.0, 0.0, 1.0)


func _active_jobs_snapshot() -> Array[Job]:
	var out: Array[Job] = []
	var open_v: Variant = JobManager.get("_open")
	if open_v is Array:
		for jv in open_v as Array:
			if jv is Job:
				out.append(jv as Job)
	var claimed_v: Variant = JobManager.get("_claimed")
	if claimed_v is Array:
		for jv in claimed_v as Array:
			if jv is Job:
				out.append(jv as Job)
	return out


func _default_resource_pressure() -> Dictionary:
	return {
		# This is a local work-demand/focus proxy, not true stock scarcity.
		"wood": 0.0,
		"stone": 0.0,
		"ore_proxy": 0.0,
		"total_relevant_jobs": 0,
		"source": "job_proxy",
	}


func _resource_bucket_for_job_type(job_type: int) -> String:
	if job_type == Job.Type.CHOP or job_type == Job.Type.BUILD_BED or job_type == Job.Type.BUILD_WALL or job_type == Job.Type.BUILD_DOOR:
		return "wood"
	if job_type == Job.Type.MINE_WALL:
		return "stone"
	if job_type == Job.Type.MINE:
		return "ore_proxy"
	return ""


func _derive_settlement_resource_pressure(st: Dictionary, active_jobs: Array[Job]) -> Dictionary:
	var center: int = int(st.get("center_region", -1))
	var wood_count: int = 0
	var stone_count: int = 0
	var ore_count: int = 0
	var total_relevant: int = 0
	for j in active_jobs:
		if j == null:
			continue
		var job_rk: int = WorldMemory._region_key(j.work_tile.x, j.work_tile.y)
		if int(_region_center.get(job_rk, -1)) != center:
			continue
		var bucket: String = _resource_bucket_for_job_type(int(j.type))
		if bucket == "":
			continue
		total_relevant += 1
		match bucket:
			"wood":
				wood_count += 1
			"stone":
				stone_count += 1
			"ore_proxy":
				ore_count += 1
	var out: Dictionary = _default_resource_pressure()
	out["total_relevant_jobs"] = total_relevant
	if total_relevant <= 0:
		return out
	var denom: float = float(total_relevant)
	out["wood"] = clamp(float(wood_count) / denom, 0.0, 1.0)
	out["stone"] = clamp(float(stone_count) / denom, 0.0, 1.0)
	out["ore_proxy"] = clamp(float(ore_count) / denom, 0.0, 1.0)
	# Apply saturation damping to reduce circular job-proxy amplification.
	out["wood"] = minf(float(out.get("wood", 0.0)), RESOURCE_PRESSURE_SATURATION)
	out["stone"] = minf(float(out.get("stone", 0.0)), RESOURCE_PRESSURE_SATURATION)
	out["ore_proxy"] = minf(float(out.get("ore_proxy", 0.0)), RESOURCE_PRESSURE_SATURATION)
	return out


func _emit_specialization_validation_log_if_needed(tick: int, settlement_idx: int, st: Dictionary) -> void:
	if not _specialization_validation_log_active():
		return
	if str(st.get("state", "")) != "active":
		return
	var rp_v: Variant = st.get("resource_pressure", _default_resource_pressure())
	var rp: Dictionary = rp_v as Dictionary if rp_v is Dictionary else _default_resource_pressure()
	var fronts_v: Variant = st.get("preferred_fronts", [])
	var front_count: int = 0
	if fronts_v is Array:
		front_count = (fronts_v as Array).size()
	print(
			(
					"[SPECIALIZATION_VALIDATE] tick=%d settlement_idx=%d center_region=%d committed_state=%s "
					+ "current_intent=%s rp_wood=%.4f rp_stone=%.4f rp_ore_proxy=%.4f rp_total_relevant_jobs=%d "
					+ "specialization_phase=%s specialization_channel=%s specialization_candidate_channel=%s "
					+ "specialization_confidence=%d preferred_front_count=%d note=resource_pressure_job_proxy_not_stock_scarcity"
			)
			% [
				tick,
				settlement_idx,
				int(st.get("center_region", -1)),
				str(st.get("state", "")),
				str(st.get("current_intent", INTENT_GROW)),
				float(rp.get("wood", 0.0)),
				float(rp.get("stone", 0.0)),
				float(rp.get("ore_proxy", 0.0)),
				int(rp.get("total_relevant_jobs", 0)),
				str(st.get("specialization_phase", SPECIALIZATION_PHASE_UNKNOWN)),
				str(st.get("specialization_channel", "")),
				str(st.get("specialization_candidate_channel", "")),
				int(st.get("specialization_confidence", 0)),
				front_count,
			]
	)


func update_resource_pressures(tick: int) -> void:
	if tick % RESOURCE_PRESSURE_UPDATE_INTERVAL_TICKS != 0:
		return
	var active_jobs: Array[Job] = _active_jobs_snapshot()
	var dt: int = RESOURCE_PRESSURE_UPDATE_INTERVAL_TICKS
	for i in range(settlements.size()):
		if not (settlements[i] is Dictionary):
			continue
		var st: Dictionary = settlements[i] as Dictionary
		st["resource_pressure"] = _derive_settlement_resource_pressure(st, active_jobs)
		st["last_resource_pressure_tick"] = tick
		_update_settlement_work_focus_identity(st, dt)
		_emit_specialization_validation_log_if_needed(tick, i, st)
		settlements[i] = st


func specialization_work_focus_label(channel: String) -> String:
	match channel:
		"wood":
			return "Wood work-focus"
		"stone":
			return "Stone work-focus"
		"ore_proxy":
			return "Ore work-focus"
		_:
			return "Unspecialized"


func _specialization_sorted_channels(rp: Dictionary) -> Array[Dictionary]:
	var rows: Array[Dictionary] = [
		{"k": "wood", "v": float(rp.get("wood", 0.0))},
		{"k": "stone", "v": float(rp.get("stone", 0.0))},
		{"k": "ore_proxy", "v": float(rp.get("ore_proxy", 0.0))},
	]
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var av: float = float(a.get("v", 0.0))
		var bv: float = float(b.get("v", 0.0))
		if not is_equal_approx(av, bv):
			return av > bv
		return str(a.get("k", "")) < str(b.get("k", ""))
	)
	return rows


func _specialization_candidate_valid(top_val: float, second_val: float) -> bool:
	return top_val >= SPECIALIZATION_ENTER_THRESHOLD and (top_val - second_val) >= SPECIALIZATION_MIN_MARGIN


func _update_settlement_work_focus_identity(st: Dictionary, dt: int) -> void:
	var rp_v: Variant = st.get("resource_pressure", _default_resource_pressure())
	var rp: Dictionary = rp_v as Dictionary if rp_v is Dictionary else _default_resource_pressure()
	var rows: Array[Dictionary] = _specialization_sorted_channels(rp)
	var top_k: String = str(rows[0].get("k", ""))
	var top_v: float = float(rows[0].get("v", 0.0))
	var second_v: float = float(rows[1].get("v", 0.0)) if rows.size() > 1 else 0.0
	var phase: String = str(st.get("specialization_phase", SPECIALIZATION_PHASE_UNKNOWN))
	var locked_ch: String = str(st.get("specialization_channel", ""))
	var cand_ch: String = str(st.get("specialization_candidate_channel", ""))
	var cand_ticks: int = int(st.get("specialization_candidate_ticks", 0))
	var repl_ticks: int = int(st.get("specialization_replacement_ticks", 0))
	var conf: int = 0
	var valid_top: bool = _specialization_candidate_valid(top_v, second_v)
	if valid_top:
		conf = int(round(clampf((top_v - second_v) / 0.5, 0.0, 1.0) * 100.0))
	match phase:
		SPECIALIZATION_PHASE_UNKNOWN:
			if valid_top:
				st["specialization_phase"] = SPECIALIZATION_PHASE_CANDIDATE
				st["specialization_candidate_channel"] = top_k
				st["specialization_candidate_ticks"] = dt
				st["specialization_replacement_ticks"] = 0
				st["specialization_channel"] = ""
				conf = mini(100, int(round(float(st["specialization_candidate_ticks"]) / float(maxi(1, SPECIALIZATION_ENTER_STABILITY_TICKS)) * 100.0)))
			else:
				st["specialization_candidate_channel"] = ""
				st["specialization_candidate_ticks"] = 0
				st["specialization_replacement_ticks"] = 0
		SPECIALIZATION_PHASE_CANDIDATE:
			cand_ch = str(st.get("specialization_candidate_channel", ""))
			if not valid_top:
				st["specialization_phase"] = SPECIALIZATION_PHASE_UNKNOWN
				st["specialization_candidate_channel"] = ""
				st["specialization_candidate_ticks"] = 0
				st["specialization_replacement_ticks"] = 0
				st["specialization_channel"] = ""
				conf = 0
			elif cand_ch != top_k:
				st["specialization_candidate_channel"] = top_k
				st["specialization_candidate_ticks"] = dt
				st["specialization_replacement_ticks"] = 0
				conf = mini(100, int(round(float(st["specialization_candidate_ticks"]) / float(maxi(1, SPECIALIZATION_ENTER_STABILITY_TICKS)) * 100.0)))
			else:
				cand_ticks = int(st.get("specialization_candidate_ticks", 0)) + dt
				st["specialization_candidate_ticks"] = cand_ticks
				if cand_ticks >= SPECIALIZATION_ENTER_STABILITY_TICKS:
					st["specialization_phase"] = SPECIALIZATION_PHASE_LOCKED
					st["specialization_channel"] = cand_ch
					st["specialization_candidate_channel"] = ""
					st["specialization_candidate_ticks"] = 0
					st["specialization_replacement_ticks"] = 0
					conf = int(round(clampf((top_v - second_v) / 0.5, 0.0, 1.0) * 100.0))
				else:
					conf = mini(100, int(round(float(cand_ticks) / float(maxi(1, SPECIALIZATION_ENTER_STABILITY_TICKS)) * 100.0)))
		SPECIALIZATION_PHASE_LOCKED:
			locked_ch = str(st.get("specialization_channel", ""))
			var locked_v: float = float(rp.get(locked_ch, 0.0)) if locked_ch != "" else 0.0
			if locked_ch == "" or locked_v < SPECIALIZATION_EXIT_THRESHOLD:
				st["specialization_phase"] = SPECIALIZATION_PHASE_UNKNOWN
				st["specialization_channel"] = ""
				st["specialization_candidate_channel"] = ""
				st["specialization_candidate_ticks"] = 0
				st["specialization_replacement_ticks"] = 0
				conf = 0
			elif valid_top and top_k != locked_ch and (top_v - locked_v) >= SPECIALIZATION_MIN_MARGIN:
				repl_ticks = int(st.get("specialization_replacement_ticks", 0)) + dt
				st["specialization_replacement_ticks"] = repl_ticks
				if repl_ticks >= SPECIALIZATION_EXIT_STABILITY_TICKS:
					st["specialization_phase"] = SPECIALIZATION_PHASE_CANDIDATE
					st["specialization_candidate_channel"] = top_k
					st["specialization_candidate_ticks"] = 0
					st["specialization_replacement_ticks"] = 0
					st["specialization_channel"] = ""
					conf = 0
				else:
					st["specialization_replacement_ticks"] = repl_ticks
					conf = mini(100, int(round(float(repl_ticks) / float(maxi(1, SPECIALIZATION_EXIT_STABILITY_TICKS)) * 100.0)))
			else:
				st["specialization_replacement_ticks"] = 0
				if valid_top and top_k == locked_ch:
					conf = int(round(clampf((top_v - second_v) / 0.5, 0.0, 1.0) * 100.0))
				else:
					conf = int(round(clampf((locked_v - second_v) / 0.5, 0.0, 1.0) * 100.0)) if locked_ch != "" else 0
	st["specialization_confidence"] = conf


func _intent_allows_front_job(intent: String, job_type: int) -> bool:
	match intent:
		INTENT_HOARD:
			return (
				job_type == Job.Type.FORAGE
				or job_type == Job.Type.HUNT
				or job_type == Job.Type.TRADE_HAUL
				or job_type == Job.Type.CHOP
			)
		INTENT_DEFEND:
			return (
				job_type == Job.Type.BUILD_WALL
				or job_type == Job.Type.BUILD_DOOR
				or job_type == Job.Type.HUNT
			)
		INTENT_RECOVER:
			return (
				job_type == Job.Type.BUILD_BED
				or job_type == Job.Type.BUILD_WALL
				or job_type == Job.Type.BUILD_DOOR
				or job_type == Job.Type.TRADE_HAUL
				or job_type == Job.Type.FORAGE
			)
		_:
			return (
				job_type == Job.Type.CHOP
				or job_type == Job.Type.MINE
				or job_type == Job.Type.MINE_WALL
				or job_type == Job.Type.BUILD_BED
				or job_type == Job.Type.BUILD_WALL
				or job_type == Job.Type.BUILD_DOOR
				or job_type == Job.Type.FORAGE
			)


func _jobs_for_settlement_intent(st: Dictionary, active_jobs: Array[Job]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var intent: String = str(st.get("current_intent", INTENT_GROW))
	var center: int = int(st.get("center_region", -1))
	for j in active_jobs:
		if j == null:
			continue
		if not _intent_allows_front_job(intent, int(j.type)):
			continue
		var job_rk: int = WorldMemory._region_key(j.work_tile.x, j.work_tile.y)
		if int(_region_center.get(job_rk, -1)) != center:
			continue
		out.append({
			"id": int(j.id),
			"job_type": int(j.type),
			"tile": j.work_tile,
		})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var aid: int = int(a.get("id", 0))
		var bid: int = int(b.get("id", 0))
		return aid < bid
	)
	return out


func _local_front_support_count(front: Dictionary, compatible_jobs: Array[Dictionary], radius_sq: int) -> int:
	var front_tile: Vector2i = front.get("tile", Vector2i(-100000, -100000))
	if front_tile.x <= -99999:
		return 0
	var front_job_type: int = int(front.get("job_type", -1))
	var count: int = 0
	for jd in compatible_jobs:
		var jt: int = int(jd.get("job_type", -1))
		if jt != front_job_type:
			continue
		var t: Vector2i = jd.get("tile", Vector2i.ZERO)
		if front_tile.distance_squared_to(t) <= radius_sq:
			count += 1
	return count


func update_preferred_work_fronts(tick: int) -> void:
	var on_cadence_tick: bool = tick % FRONT_UPDATE_INTERVAL_TICKS == 0
	var has_intent_shift: bool = false
	if not on_cadence_tick:
		for st_v in settlements:
			if not (st_v is Dictionary):
				continue
			var st_probe: Dictionary = st_v as Dictionary
			var intent_probe: String = str(st_probe.get("current_intent", INTENT_GROW))
			var last_intent_probe: String = str(st_probe.get("last_front_intent", intent_probe))
			if intent_probe != last_intent_probe:
				has_intent_shift = true
				break
	if not on_cadence_tick and not has_intent_shift:
		return
	var active_jobs: Array[Job] = _active_jobs_snapshot()
	var cluster_radius_sq: int = FRONT_CLUSTER_RADIUS_TILES * FRONT_CLUSTER_RADIUS_TILES
	var support_check_radius_sq: int = FRONT_SUPPORT_CHECK_RADIUS_TILES * FRONT_SUPPORT_CHECK_RADIUS_TILES
	for i in range(settlements.size()):
		if not (settlements[i] is Dictionary):
			continue
		var st: Dictionary = settlements[i] as Dictionary
		var intent: String = str(st.get("current_intent", INTENT_GROW))
		var last_intent: String = str(st.get("last_front_intent", intent))
		var intent_changed: bool = intent != last_intent
		if intent_changed:
			st["preferred_fronts"] = []
			st["last_front_intent"] = intent
		if not on_cadence_tick and not intent_changed:
			continue
		var compatible_jobs: Array[Dictionary] = _jobs_for_settlement_intent(st, active_jobs)
		if compatible_jobs.is_empty():
			st["preferred_fronts"] = []
			st["last_front_update_tick"] = tick
			st["last_front_intent"] = intent
			settlements[i] = st
			continue
		var clusters: Array[Dictionary] = []
		for jd in compatible_jobs:
			var t: Vector2i = jd.get("tile", Vector2i.ZERO)
			var assigned: bool = false
			for c in clusters:
				var cc: int = maxi(1, int(c.get("count", 1)))
				var cx: int = int(round(float(int(c.get("sum_x", t.x))) / float(cc)))
				var cy: int = int(round(float(int(c.get("sum_y", t.y))) / float(cc)))
				var center_tile: Vector2i = Vector2i(cx, cy)
				if center_tile.distance_squared_to(t) <= cluster_radius_sq:
					c["sum_x"] = int(c.get("sum_x", 0)) + t.x
					c["sum_y"] = int(c.get("sum_y", 0)) + t.y
					c["count"] = int(c.get("count", 0)) + 1
					assigned = true
					break
			if not assigned:
				clusters.append({
					"sum_x": t.x,
					"sum_y": t.y,
					"count": 1,
					"job_type": int(jd.get("job_type", -1)),
					"first_job_id": int(jd.get("id", 0)),
				})
		clusters.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			var ac: int = int(a.get("count", 0))
			var bc: int = int(b.get("count", 0))
			if ac != bc:
				return ac > bc
			return int(a.get("first_job_id", 0)) < int(b.get("first_job_id", 0))
		)
		var existing_fronts_v: Variant = st.get("preferred_fronts", [])
		var existing_fronts: Array = existing_fronts_v as Array if existing_fronts_v is Array else []
		var unmatched_existing: Array[Dictionary] = []
		for fv in existing_fronts:
			if fv is Dictionary:
				unmatched_existing.append((fv as Dictionary).duplicate(true))
		var fronts: Array[Dictionary] = []
		for c in clusters:
			if fronts.size() >= FRONT_MAX_COUNT:
				break
			var cc: int = maxi(1, int(c.get("count", 1)))
			var fx: int = int(round(float(int(c.get("sum_x", 0))) / float(cc)))
			var fy: int = int(round(float(int(c.get("sum_y", 0))) / float(cc)))
			var cluster_tile: Vector2i = Vector2i(fx, fy)
			var cluster_job_type: int = int(c.get("job_type", -1))
			var matched_idx: int = -1
			for ei in range(unmatched_existing.size()):
				var ex: Dictionary = unmatched_existing[ei]
				if int(ex.get("job_type", -1)) != cluster_job_type:
					continue
				var ex_tile: Vector2i = ex.get("tile", Vector2i(-100000, -100000))
				if ex_tile.x <= -99999:
					continue
				if ex_tile.distance_squared_to(cluster_tile) <= cluster_radius_sq:
					matched_idx = ei
					break
			var stability_ticks: int = FRONT_PERSISTENCE_WINDOW_TICKS
			if matched_idx >= 0:
				stability_ticks = FRONT_PERSISTENCE_WINDOW_TICKS
				unmatched_existing.remove_at(matched_idx)
			fronts.append({
				"tile": Vector2i(fx, fy),
				"job_type": cluster_job_type,
				"support": cc,
				"stability_ticks": stability_ticks,
			})
		for ex in unmatched_existing:
			if fronts.size() >= FRONT_MAX_COUNT:
				break
			var support: int = _local_front_support_count(ex, compatible_jobs, support_check_radius_sq)
			if support <= 0:
				continue
			var stability: int = int(ex.get("stability_ticks", 0)) - FRONT_DECAY_TICKS
			if support < MIN_FRONT_SUPPORT or stability <= 0:
				continue
			ex["support"] = support
			ex["stability_ticks"] = stability
			fronts.append(ex)
		st["preferred_fronts"] = fronts
		st["last_front_update_tick"] = tick
		st["last_front_intent"] = intent
		settlements[i] = st


func get_preferred_front_bias_for_job(pawn_tile: Vector2i, job: Job) -> float:
	if job == null:
		return 1.0
	var pawn_rk: int = WorldMemory._region_key(pawn_tile.x, pawn_tile.y)
	var job_rk: int = WorldMemory._region_key(job.work_tile.x, job.work_tile.y)
	var pawn_center: int = int(_region_center.get(pawn_rk, -1))
	var job_center: int = int(_region_center.get(job_rk, -1))
	if pawn_center < 0 or job_center < 0 or pawn_center != job_center:
		return 1.0
	var st_v: Variant = get_settlement_at_region(pawn_rk)
	if not (st_v is Dictionary):
		return 1.0
	var st: Dictionary = st_v as Dictionary
	var fronts_v: Variant = st.get("preferred_fronts", [])
	if not (fronts_v is Array):
		return 1.0
	var radius_sq: int = FRONT_INFLUENCE_RADIUS_TILES * FRONT_INFLUENCE_RADIUS_TILES
	for fv in fronts_v as Array:
		if not (fv is Dictionary):
			continue
		var f: Dictionary = fv as Dictionary
		if int(f.get("job_type", -1)) != int(job.type):
			continue
		var ftile: Vector2i = f.get("tile", Vector2i(-100000, -100000))
		if ftile.x <= -99999:
			continue
		if ftile.distance_squared_to(job.work_tile) <= radius_sq:
			var stability_ticks: int = int(f.get("stability_ticks", FRONT_PERSISTENCE_WINDOW_TICKS))
			var stability_ratio: float = clamp(float(stability_ticks) / float(maxi(1, FRONT_PERSISTENCE_WINDOW_TICKS)), 0.0, 1.0)
			var scaled_bias: float = 1.0 + (FRONT_BIAS_MAX - 1.0) * stability_ratio
			return clamp(scaled_bias, 1.0, FRONT_BIAS_MAX)
	return 1.0


func get_settlement_intent_for_tile(tile_pos: Vector2i) -> String:
	var rk: int = WorldMemory._region_key(tile_pos.x, tile_pos.y)
	var st_v: Variant = get_settlement_at_region(rk)
	if st_v is Dictionary:
		return str((st_v as Dictionary).get("current_intent", INTENT_GROW))
	return INTENT_GROW


func get_resource_pressure_for_tile(tile_pos: Vector2i) -> Dictionary:
	var rk: int = WorldMemory._region_key(tile_pos.x, tile_pos.y)
	var st_v: Variant = get_settlement_at_region(rk)
	if st_v is Dictionary:
		var rp_v: Variant = (st_v as Dictionary).get("resource_pressure", _default_resource_pressure())
		if rp_v is Dictionary:
			return (rp_v as Dictionary).duplicate(true)
	return _default_resource_pressure()
