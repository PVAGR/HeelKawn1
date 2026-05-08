extends Node
## v1: Settlement identity — 4-adjacent clusters of scarred, historically
## active regions. Derived only; read WorldMeaning, WorldPersistence, CulturalMemory.
## Does not keep references to [World] ([recompute] takes it for API symmetry with peers).
## "state" is one of: abandoned, permanently_abandoned, revivable, dormant (revival v1, not saved).

# --- Playtest tuning: revival / abandonment (single place to adjust “feel”) ---
# HARD_COLLAPSE_TICKS — window for “recent” worst-case collapse when scoring irreversible paths.
# REVIVABLE_SCAR_MAX — max cluster scar for revivable branch eligibility (see also SettlementRebirth scar>=3 block).
# REVIVABLE_REPUTATION_MIN — floor rep still allowed on revivable path.
# PEACE_TICKS_PER_BRANCH — ticks of quiet (no pawn deaths in cluster) before peace component maxes; branch flavor.
# REVIVAL_SCORE_* — deterministic 0..100 curve gates: recovering → revivable → active (see _deterministic_revival_score).
# These thresholds align with REVIVAL_CONSTRAINTS.md documentation.
const HARD_COLLAPSE_TICKS: int = 30000
const REVIVABLE_SCAR_MAX: int = 2  # Matches REVIVAL_CONSTRAINTS hard gate: scar level < 3
const REVIVABLE_REPUTATION_MIN: int = -1
const PEACE_TICKS_PER_BRANCH: Dictionary = {
    SettlementPlanner.CULTURE_OPEN: 18000,    # More permissive peace requirement
    SettlementPlanner.CULTURE_CAUTIOUS: 30000,  # Standard peace requirement
    SettlementPlanner.CULTURE_DEFENSIVE: 42000,  # Stricter peace requirement
}
const REVIVAL_SCORE_RECOVERING_MIN: int = 35  # Minimum score to enter recovering state
const REVIVAL_SCORE_REVIVABLE_MIN: int = 70   # Minimum score to become revivable
const REVIVAL_SCORE_ACTIVE_MIN: int = 88     # Minimum score to become active (requires scar <= 1)
const INTENT_UPDATE_INTERVAL_TICKS: int = 500
const MIN_INTENT_DWELL_TICKS: int = 2000
const CRITICAL_LOCAL_FOOD_PRESSURE: float = 0.9
const LOCAL_HOUSING_PAWNS_PER_REGION: float = 2.0
const LOCAL_HOUSING_PRESSURE_THRESHOLD: float = 0.8
const FRONT_UPDATE_INTERVAL_TICKS: int = 200
## Checking whether any settlement intent changed is expensive because it scans all
## settlements. Most ticks don't change intent (intents update on a 500-tick cadence),
## so we only perform the scan periodically to reduce normal-mode hitching.
const INTENT_SHIFT_SCAN_INTERVAL_TICKS: int = 25
const FRONT_CLUSTER_RADIUS_TILES: int = 8
const FRONT_INFLUENCE_RADIUS_TILES: int = 10
const FRONT_MAX_COUNT: int = 2
const FRONT_BIAS_MAX: float = 1.1
const FRONT_PERSISTENCE_WINDOW_TICKS: int = 600
const FRONT_DECAY_TICKS: int = 200
const MIN_FRONT_SUPPORT: int = 1
const FRONT_SUPPORT_CHECK_RADIUS_TILES: int = 8
const RESOURCE_PRESSURE_UPDATE_INTERVAL_TICKS: int = 1000
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

## Policy layer on top of derived power structure ([member settlements] also stores [code]governance_type[/code]
## as council/monarchy/anarchy from [method _governance_for_settlement]).
enum GovernanceForm {
    ELDER_COUNCIL,
    MILITIA_PROTECTORS,
    CHIEF_HOUSEHOLDS,
    COUNCIL_RULE,
}

const GOVERNANCE_FORM_DEFAULT: GovernanceForm = GovernanceForm.ELDER_COUNCIL

## center_region -> persisted governance form key string ([method governance_form_to_storage_string]).
var _governance_form_by_center: Dictionary = {}

var settlements: Array = []
## center_region -> hysteresis for settlement [state] material truth (survives settlement dict rebuilds).
var _settlement_state_truth_hysteresis: Dictionary = {}
## Align with [Main.REBIRTH_CHECK_INTERVAL_TICKS]: one hysteresis step per recompute pass.
const STATE_TRUTH_HYSTERESIS_INTERVAL_TICKS: int = 2000
## Require this many ticks at the same raw target before committing (anti-flicker).
const STATE_TRUTH_HYSTERESIS_COMMIT_TICKS: int = 4000
## --- Validation harness (debug builds): controlled lab sessions ---
## Console marker proving this binary includes the smoketest wiring; bump when observability changes.
const VALIDATION_RUNTIME_SMOKE_MARKER: String = "PVAGR/HeelKawn1-validation-smoketest-2026-04-27-r2-trade-rp"
## One switch: suppresses economy-distorting world events (see WorldEvents), enables settlement-truth verify logs, enables coarse specialization validation logs.
const VALIDATION_SESSION_ENABLED: bool = false
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

## Phase 8 HUD overlay: bundle lines for proof observability ([Main] listens in debug builds).
signal phase8_proof_bundle_emitted(bundle_line: String)
var _phase8_proof_terminal_line: String = ""
var _phase8_proof_latest_bundle_line: String = ""
var _phase8_proof_preferred_center_region: int = -1


## [code]war_status[/code] must be a Dictionary; saves or edge merges can leave a wrong-typed value
## and strict `var ws: Dictionary = st.get("war_status", …)` will hard-fail (tick-1 HUD path).
func _coerce_war_status_from_settlement(st: Dictionary) -> Dictionary:
    var raw: Variant = st.get("war_status", null)
    if raw is Dictionary:
        return (raw as Dictionary).duplicate(true)
    return {"state": "peace", "target_settlement_id": -1, "votes": []}


func _war_state_string_from_settlement(st: Dictionary) -> String:
    return str(_coerce_war_status_from_settlement(st).get("state", "peace"))


func get_phase8_proof_terminal_line() -> String:
    return _phase8_proof_terminal_line


func get_phase8_proof_latest_bundle_line() -> String:
    return _phase8_proof_latest_bundle_line


func set_phase8_proof_preferred_center_region(center_region: int) -> void:
    if _phase8_proof_preferred_center_region == center_region:
        return
    _phase8_proof_preferred_center_region = center_region
    if OS.is_debug_build():
        phase8_proof_bundle_emitted.emit(
                "[PHASE8_PROOF_BUNDLE] preferred_center=%d tick=%d" % [center_region, GameManager.tick_count]
        )


func print_resource_truth_capture(preferred_center: int, source: String) -> void:
    if not OS.is_debug_build():
        return
    var found: Dictionary = {}
    for i in range(settlements.size()):
        var sv: Variant = settlements[i]
        if not (sv is Dictionary):
            continue
        var d: Dictionary = sv as Dictionary
        if int(d.get("center_region", -1)) == preferred_center:
            found = d
            break
    if found.is_empty():
        print("[RESOURCE_TRUTH] %s center=%d note=no_settlement_match" % [source, preferred_center])
        return
    var rt_v: Variant = found.get("resource_truth", {})
    var rt: Dictionary = rt_v as Dictionary if rt_v is Dictionary else {}
    print(
            (
                    "[RESOURCE_TRUTH] %s tick=%d center_region=%d stock_food=%d stock_wood=%d "
                    + "stock_stone=%d stock_ore_proxy=%d total_units=%d"
            )
            % [
                source,
                GameManager.tick_count,
                preferred_center,
                int(rt.get("stock_food", 0)),
                int(rt.get("stock_wood", 0)),
                int(rt.get("stock_stone", 0)),
                int(rt.get("stock_ore_proxy", 0)),
                int(rt.get("total_stock_units", 0)),
            ]
    )


## Populate resource_truth on a settlement dict from StockpileManager.
## Called after settlement recomputation so the audit reads real stockpile data.
func _capture_resource_truth(st: Dictionary) -> void:
    var food: int = 0
    var wood: int = 0
    var stone: int = 0
    var ore_proxy: int = 0
    var total: int = 0
    if StockpileManager != null:
        var snap: Dictionary = StockpileManager.labor_pressure_stock_snapshot()
        food = int(snap.get("food", 0))
        wood = int(snap.get("wood", 0))
        stone = int(snap.get("stone", 0))
        # ore_proxy: count FLINT as a rough ore stand-in
        ore_proxy = StockpileManager.total_count_of(Item.Type.FLINT) if Item != null else 0
        total = food + wood + stone + ore_proxy
    st["resource_truth"] = {
        "stock_food": food,
        "stock_wood": wood,
        "stock_stone": stone,
        "stock_ore_proxy": ore_proxy,
        "total_stock_units": total,
        "snapshot_tick": GameManager.tick_count if GameManager != null else -1,
        "center_region": int(st.get("center_region", -1)),
    }
    # Derive resource_balance labels from the truth
    st["resource_balance"] = {
        "food_balance": _balance_bucket_food(food),
        "wood_balance": _balance_bucket_material(wood),
        "stone_balance": _balance_bucket_material(stone),
        "ore_proxy_balance": _balance_bucket_material(ore_proxy),
        "snapshot_tick": GameManager.tick_count if GameManager != null else -1,
        "center_region": int(st.get("center_region", -1)),
        "source": "stockpile_manager_snapshot",
    }


func _balance_bucket_food(units: int) -> String:
    if units <= 0:
        return "DEFICIT"
    if units <= 10:
        return "LOW"
    return "HIGH"


func _balance_bucket_material(units: int) -> String:
    if units <= 0:
        return "DEFICIT"
    if units <= 5:
        return "LOW"
    return "HIGH"


func resource_balance_audit_snapshot_for_settlement(st: Dictionary) -> Dictionary:
    var rt: Dictionary = {}
    var rb: Dictionary = {}
    var rt_v: Variant = st.get("resource_truth", null)
    if rt_v is Dictionary:
        rt = rt_v as Dictionary
    var rb_v: Variant = st.get("resource_balance", null)
    if rb_v is Dictionary:
        rb = rb_v as Dictionary
    var center: int = int(st.get("center_region", -1))
    var snap_tick: int = int(rb.get("snapshot_tick", rt.get("snapshot_tick", -1)))
    if snap_tick < 0:
        snap_tick = GameManager.tick_count
    var fc: int = int(rt.get("stock_food", 0))
    var wc: int = int(rt.get("stock_wood", 0))
    var sc: int = int(rt.get("stock_stone", 0))
    var oc: int = int(rt.get("stock_ore_proxy", 0))
    var food_e: String = _balance_bucket_food(fc)
    var wood_e: String = _balance_bucket_material(wc)
    var stone_e: String = _balance_bucket_material(sc)
    var ore_e: String = _balance_bucket_material(oc)
    var food_a: String = str(rb.get("food_balance", food_e))
    var wood_a: String = str(rb.get("wood_balance", wood_e))
    var stone_a: String = str(rb.get("stone_balance", stone_e))
    var ore_a: String = str(rb.get("ore_proxy_balance", ore_e))
    var pass_all: bool = food_e == food_a and wood_e == wood_a and stone_e == stone_a and ore_e == ore_a
    return {
        "result": ("PASS" if pass_all else "FAIL"),
        "snapshot_tick": snap_tick,
        "center_region": center,
        "food_count": fc,
        "food_expected": food_e,
        "food_actual": food_a,
        "wood_count": wc,
        "wood_expected": wood_e,
        "wood_actual": wood_a,
        "stone_count": sc,
        "stone_expected": stone_e,
        "stone_actual": stone_a,
        "ore_proxy_count": oc,
        "ore_proxy_expected": ore_e,
        "ore_proxy_actual": ore_a,
    }


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
    var clean_active: bool = WorldEvents.validation_clean_economy_events_active()
    var truth_active: bool = validation_truth_verify_armed()
    var spec_active: bool = validation_specialization_log_armed()
    if dbg:
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
        var bootstrap_cluster: Array = _bootstrap_presettlement_cluster(living_pawns)
        if bootstrap_cluster.is_empty():
            return
        var st0: Dictionary = _build_settlement_from_regions(bootstrap_cluster)
        var base_state0: String = str(st0.get("state", "recovering"))
        var raw_state0: String = _material_activity_state_override(
                st0, _world, living_pawns, active_jobs, base_state0
        )
        var center_id0: int = int(st0.get("center_region", -1))
        st0["state"] = _apply_settlement_state_truth_hysteresis(center_id0, raw_state0, base_state0, st0)
        # OPTIMIZATION: Force new settlements active for better early game
        st0 = _force_settlement_active_on_founding(st0)
        _apply_diaspora_founding(st0, center_id0)
        _capture_resource_truth(st0)
        settlements.append(st0)
        var st_name0: String = str(st0.get("state", ""))
        var ckr0: int = int(st0.get("center_region", -1))
        var preg0: Variant = st0.get("regions", null)
        if preg0 is PackedInt32Array:
            var pa0: PackedInt32Array = preg0 as PackedInt32Array
            for i in range(pa0.size()):
                var rk0: int = int(pa0[i])
                _region_state[rk0] = st_name0
                _region_center[rk0] = ckr0
    elif not eligible.is_empty():
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
            # OPTIMIZATION: Force new settlements active for better early game
            st = _force_settlement_active_on_founding(st)
            _apply_diaspora_founding(st, center_id)
            _capture_resource_truth(st)
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
    _apply_persisted_governance_forms()
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
            var old_committed: String = str(e.get("committed", raw_state))
            e["committed"] = raw_state
            e["ticks"] = 0
            reason = "pending_reached_commit_threshold"
            # Trigger audio cue on committed state change
            if old_committed != raw_state:
                _trigger_meaning_audio_cue(center_id, old_committed, raw_state)
                # Log deterministic state transition to WorldMemory
                if WorldMemory != null and WorldMemory.has_method("record_settlement_state_transition"):
                    WorldMemory.record_settlement_state_transition(
                        center_id, old_committed, raw_state,
                        int(st.get("revival_score", 0)),
                        int(st.get("scar_max", 0)),
                        int(st.get("peace_threshold_ticks", 0))
                    )
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


## When no region yet qualifies for history-scar settlement clustering, still anchor one derived
## settlement to registered stockpile zones plus current pawn tiles (starters rarely overlap the seed pile).
func _bootstrap_presettlement_cluster(living_pawns: Array[Pawn]) -> Array:
    var seen: Dictionary = {}
    var out: Array = []
    var max_keys: int = 512
    var per_zone_cap: int = 256
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
                var rk_z: int = WorldMemory._region_key(x, y)
                if not seen.has(rk_z):
                    seen[rk_z] = true
                    out.append(rk_z)
                if out.size() >= max_keys:
                    out.sort()
                    return out
            if scanned > per_zone_cap:
                break
    for p in living_pawns:
        if p == null or not is_instance_valid(p) or p.data == null:
            continue
        var rk_p: int = WorldMemory._region_key(p.data.tile_pos.x, p.data.tile_pos.y)
        if not seen.has(rk_p):
            seen[rk_p] = true
            out.append(rk_p)
            if out.size() >= max_keys:
                out.sort()
                return out
    out.sort()
    return out


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
        ticks_since_collapse, scar_max, ticks_since_collapse, culture_type, reputation_min, center_rk
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
        "settlement_specialization": "",
        "cultural_tags": [],
        "parent_settlement_id": -1,  # Diaspora: ID of parent settlement (-1 = original)
        "founding_pressure": "",     # Diaspora: cause chain that produced this settlement
        "founding_tick": -1,         # Diaspora: tick when this settlement was founded
    }


func _settlement_state_v1(
        scar_max: int,
        reputation_min: int,
        last_activity_tick: int,
        last_pawn_death_tick: int,
        culture_branch: int
) -> String:
    # Exclusivity:
    # permanently_abandoned > abandoned > revivable > recovering > active.
    # Canonical flow per REVIVAL_CONSTRAINTS.md:
    #   abandoned: recent collapse or very low revival score
    #   revivable: moderate scars, quiet region, recovery possible (score 70+)
    #   recovering: in active recovery phase (score 88+, scar ≤1, extended peace)
    #   active: fully functional (score 88+, scar ≤1, 2x peace threshold)
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
    # Canonical flow: abandoned → recovering → revivable → active
    # Score gates: <35=abandoned, 35-69=recovering, 70-87=revivable, 88+=active
    if scar_max <= REVIVABLE_SCAR_MAX and regional_peace_ticks >= peace_threshold:
        if revival_score >= REVIVAL_SCORE_ACTIVE_MIN and scar_max <= 1 and regional_peace_ticks >= peace_threshold * 2:
            return "active"
        if revival_score >= REVIVAL_SCORE_REVIVABLE_MIN:
            return "revivable"
        if revival_score >= REVIVAL_SCORE_RECOVERING_MIN:
            return "recovering"
    # Outside revival branch: score too low or conditions not met
    if revival_score < REVIVAL_SCORE_RECOVERING_MIN:
        return "abandoned"
    # Score >= 35 but scar > 2 or peace insufficient — still recovering
    return "recovering"
    if scar_max <= REVIVABLE_SCAR_MAX and regional_peace_ticks >= peace_threshold:
        if revival_score >= REVIVAL_SCORE_ACTIVE_MIN and scar_max <= 1 and regional_peace_ticks >= peace_threshold * 2:
            return "active"
        # recovering = revivable + sustained recovery momentum (between revivable and active)
        if revival_score >= REVIVAL_SCORE_RECOVERING_MIN:
            return "recovering"
        return "revivable"
    return "abandoned"


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
        reputation_min: int,
        center_region: int = -1
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
    var base_score: int = int((collapse_component + peace_component) / 2) - scar_penalty + branch_bonus + rep_bonus

    # Apply WorldMeaning modifiers when a center region is known
    if center_region != null and int(center_region) >= 0:
        var mean: Dictionary = WorldMeaning.get_region_meaning(int(center_region))
        var label: String = str(mean.get("meaning_label", ""))
        if label == "resilient":
            base_score += 25
        elif label == "cursed":
            base_score -= 30

    return clampi(base_score, 0, 100)


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


## ARCHITECT TASK 2: Get the settlement ID a pawn belongs to.
func get_settlement_id_for_pawn(pawn_id: int) -> int:
    # Look up the pawn's settlement_id directly from PawnData via PawnSpawner
    var sp: Node = get_node_or_null("/root/Main/WorldViewport/PawnSpawner")
    if sp != null and sp.has_method("pawn_data_for_id"):
        var pd = sp.call("pawn_data_for_id", pawn_id)
        if pd != null and "settlement_id" in pd:
            return int(pd.settlement_id)
    return -1

## ARCHITECT TASK 2: Get the ID of the current ruler of a settlement.
func get_ruler_pawn_id(settlement_id: int) -> int:
    for st_v in settlements:
        if not (st_v is Dictionary):
            continue
        var st: Dictionary = st_v as Dictionary
        if int(st.get("center_region", -1)) == settlement_id:
            return int(st.get("current_ruler_id", -1))
    return -1

## ARCHITECT TASK 2: Internal method to set a settlement's ruler and governance type.
## This function is called by AuthoritySystem to finalize leadership changes.
## It updates the internal `settlements` array and records a `governance_change` event.
func _set_settlement_ruler_and_type(settlement_id: int, new_ruler_id: int, new_governance_type: String) -> bool:
    for i in range(settlements.size()):
        if not (settlements[i] is Dictionary):
            continue
        var st: Dictionary = settlements[i] as Dictionary
        if int(st.get("center_region", -1)) == settlement_id:
            var old_ruler_id: int = int(st.get("current_ruler_id", -1))
            var old_governance_type: String = str(st.get("governance_type", "anarchy"))

            st["current_ruler_id"] = new_ruler_id
            st["governance_type"] = new_governance_type
            # If transitioning to monarchy, ensure council_ids is cleared or set appropriately.
            if new_governance_type == "monarchy":
                st["council_ids"] = PackedInt32Array() # A monarch rules alone, no council

            settlements[i] = st

            # Record governance_change event in WorldMemory
            WorldMemory.record_event({
                "type": "governance_change",
                "settlement_id": settlement_id,
                "old_ruler_id": old_ruler_id,
                "new_ruler_id": new_ruler_id,
                "old_governance_type": old_governance_type,
                "new_governance_type": new_governance_type,
                "tick": GameManager.tick_count,
            })

            return true
    return false


func _regions_from_settlement(settlement: Dictionary) -> PackedInt32Array:
    var reg: Variant = settlement.get("regions", null)
    if reg is PackedInt32Array:
        return reg as PackedInt32Array
    return PackedInt32Array()


func _max_last_pawn_death_tick_in_regions(regions: PackedInt32Array) -> int:
    return WorldMemory.get_last_pawn_death_tick_in_regions(regions)


## True for [abandoned] (recent hard collapse) and [permanently_abandoned] (older hard collapse).
func is_collapsed_state(state: String) -> bool:
    return state == "abandoned" or state == "permanently_abandoned"


## OPTIMIZATION: Force new settlements to start as "active" for better early game
func _force_settlement_active_on_founding(settlement: Dictionary) -> Dictionary:
    var current_state: String = str(settlement.get("state", "active"))
    # Only override collapsed states - let natural abandonment happen later
    if current_state == "abandoned" or current_state == "permanently_abandoned":
        settlement["state"] = "active"
        settlement["force_active_ticks"] = 10000  # Force active for first 10000 ticks
    return settlement


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
    var best: int = -1
    for rk_any in cluster:
        var rk: int = int(rk_any)
        best = maxi(best, WorldMemory.get_last_pawn_death_tick_for_region(rk))
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
    return settlements


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


var _living_pawns_cache: Array[Pawn] = []
var _living_pawns_cache_tick: int = -1
## Region-key → Array[Pawn] index, rebuilt alongside _living_pawns_cache.
## Eliminates O(S×P) governance scan — each settlement looks up its regions
## in O(1) instead of scanning all pawns.
var _pawns_by_region_cache: Dictionary = {}

func _living_pawns() -> Array[Pawn]:
    var t: int = GameManager.tick_count if GameManager != null else 0
    if t == _living_pawns_cache_tick:
        return _living_pawns_cache
    _living_pawns_cache = PawnSpawner.find_pawns()
    _living_pawns_cache_tick = t
    # Build region→pawns index in the same pass
    _pawns_by_region_cache.clear()
    for p in _living_pawns_cache:
        if p.data == null:
            continue
        var rk: int = WorldMemory._region_key(p.data.tile_pos.x, p.data.tile_pos.y)
        if not _pawns_by_region_cache.has(rk):
            _pawns_by_region_cache[rk] = []
        (_pawns_by_region_cache[rk] as Array).append(p)
    return _living_pawns_cache


## Return pawns belonging to a settlement's regions using the cached index.
## O(R) where R = number of regions in the settlement, instead of O(P).
func _pawns_in_settlement_indexed(st: Dictionary) -> Array[Pawn]:
    var regv: Variant = st.get("regions", PackedInt32Array())
    if not (regv is PackedInt32Array):
        return []
    var regs: PackedInt32Array = regv as PackedInt32Array
    var out: Array[Pawn] = []
    var seen: Dictionary = {}
    for rk in regs:
        var arr: Variant = _pawns_by_region_cache.get(int(rk), null)
        if arr is Array:
            for p in arr:
                var pid: int = int(p.data.id) if p.data != null else -1
                if pid >= 0 and not seen.has(pid):
                    seen[pid] = true
                    out.append(p)
    return out


func _governance_for_settlement(st: Dictionary, _pawns_all: Array[Pawn]) -> Dictionary:
    # Use indexed lookup instead of scanning all pawns per settlement
    var set_pawns: Array[Pawn] = _pawns_in_settlement_indexed(st)
    if set_pawns.is_empty():
        return {"type": "anarchy", "ruler_id": -1, "council_ids": PackedInt32Array()}
    var ranked: Array[Dictionary] = []
    for p in set_pawns:
        if p.data == null:
            continue
        ranked.append({
            "id": int(p.data.id),
            "influence": float(p.data.influence),
        })
    if ranked.is_empty():
        return {"type": "anarchy", "ruler_id": -1, "council_ids": PackedInt32Array()}
    # Influence scales with local settlement population.
    # Build a lookup dict from settlement pawns only.
    var pawn_by_id: Dictionary = {}
    for p in set_pawns:
        if p.data != null:
            pawn_by_id[int(p.data.id)] = p
    for rec in ranked:
        var pid: int = int((rec as Dictionary).get("id", -1))
        var p: Pawn = pawn_by_id.get(pid) as Pawn
        if p != null and p.data != null:
            (rec as Dictionary)["influence"] = p.data.calculate_influence(ranked.size())
            # Life-path ruler bonus: pawns on ruler path gain influence boost.
            if int(p.data.life_path) == 3:  # PawnData.LifePath.RULER
                var lp_prog: int = int(p.data.life_path_progress)
                var ruler_bonus: float = float(lp_prog) * 0.5  # +0.5 per progress level
                (rec as Dictionary)["influence"] = float((rec as Dictionary)["influence"]) + ruler_bonus
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


func governance_form_to_storage_string(form: GovernanceForm) -> String:
    match form:
        GovernanceForm.ELDER_COUNCIL:
            return "elder_council"
        GovernanceForm.MILITIA_PROTECTORS:
            return "militia_protectors"
        GovernanceForm.CHIEF_HOUSEHOLDS:
            return "chief_households"
        GovernanceForm.COUNCIL_RULE:
            return "council_rule"
    return "elder_council"


func governance_form_from_storage_string(s: String) -> GovernanceForm:
    match str(s):
        "militia_protectors":
            return GovernanceForm.MILITIA_PROTECTORS
        "chief_households":
            return GovernanceForm.CHIEF_HOUSEHOLDS
        "council_rule":
            return GovernanceForm.COUNCIL_RULE
        _:
            return GovernanceForm.ELDER_COUNCIL


## Numeric modifiers for downstream sim (job routing, intent glue). Multipliers scale priority-like weights.
## Ratios stay near 1.0 so defaults remain playable without tuning explosions.
func get_governance_bonus(form: GovernanceForm) -> Dictionary:
    match form:
        GovernanceForm.ELDER_COUNCIL:
            # Elder consensus: favor stabilizing food/forage and negotiated exchange over rash builds or raids.
            return {"food": 1.08, "defense": 0.94, "build": 1.02, "production": 0.98, "trade": 1.05}
        GovernanceForm.MILITIA_PROTECTORS:
            # Militia-led: favor patrol/defense work (walls, hunting threats) over civilian expansion.
            return {"food": 0.97, "defense": 1.12, "build": 1.0, "production": 0.98, "trade": 0.96}
        GovernanceForm.CHIEF_HOUSEHOLDS:
            # Kin-house hierarchy: favor shelter/construction and domestic order over distant trade.
            return {"food": 1.03, "defense": 1.0, "build": 1.1, "production": 1.02, "trade": 0.94}
        GovernanceForm.COUNCIL_RULE:
            # Formal quorum: balanced productive labor with slight bias to civic cohesion (production/trade).
            return {"food": 1.02, "defense": 1.02, "build": 1.02, "production": 1.04, "trade": 1.04}
        _:
            return {"food": 1.0, "defense": 1.0, "build": 1.0, "production": 1.0, "trade": 1.0}


func get_governance_bonus_for_storage_string(form_key: String) -> Dictionary:
    return get_governance_bonus(governance_form_from_storage_string(form_key))


## settlement_id matches other settlement APIs ([method get_ruler_pawn_id]): [code]center_region[/code] id.
func set_governance_type(settlement_id: int, form: GovernanceForm) -> void:
    if settlement_id < 0:
        return
    var s: String = governance_form_to_storage_string(form)
    _governance_form_by_center[settlement_id] = s
    SettlementRegistry.upsert_overlay_field(str(settlement_id), "governance_form", s)
    for i in range(settlements.size()):
        if not (settlements[i] is Dictionary):
            continue
        var st: Dictionary = settlements[i] as Dictionary
        if int(st.get("center_region", -1)) == settlement_id:
            st["governance_form"] = s
            settlements[i] = st
            break


func _apply_persisted_governance_forms() -> void:
    for i in range(settlements.size()):
        if not (settlements[i] is Dictionary):
            continue
        var st: Dictionary = settlements[i] as Dictionary
        var c: int = int(st.get("center_region", -1))
        if c < 0:
            continue
        var form_str: String = ""
        if _governance_form_by_center.has(c):
            form_str = str(_governance_form_by_center[c])
        else:
            var ov: Variant = SettlementRegistry.get_overlay_field(str(c), "governance_form")
            if ov != null and str(ov) != "":
                form_str = str(ov)
                _governance_form_by_center[c] = form_str
        if form_str.is_empty():
            form_str = governance_form_to_storage_string(GOVERNANCE_FORM_DEFAULT)
        st["governance_form"] = form_str
        settlements[i] = st


func to_save_dict() -> Dictionary:
    var gf: Dictionary = {}
    for k_any in _governance_form_by_center.keys():
        gf[str(k_any)] = str(_governance_form_by_center[k_any])
    return {"governance_forms": gf}


func from_save_dict(d: Variant) -> void:
    _governance_form_by_center.clear()
    if d == null or not (d is Dictionary):
        return
    var gf_v: Variant = (d as Dictionary).get("governance_forms", {})
    if not (gf_v is Dictionary):
        return
    for k_any in (gf_v as Dictionary).keys():
        var ck: int = int(str(k_any))
        var fs: String = str((gf_v as Dictionary)[k_any])
        if ck >= 0 and not fs.is_empty():
            _governance_form_by_center[ck] = fs
            SettlementRegistry.upsert_overlay_field(str(ck), "governance_form", fs)


func clear_persisted_governance_forms() -> void:
    _governance_form_by_center.clear()


func get_governance_profile_for_region(region_key: int) -> Dictionary:
    var st_v: Variant = get_settlement_at_region(region_key)
    if not (st_v is Dictionary):
        return {
            "type": "anarchy",
            "ruler_id": -1,
            "council_ids": PackedInt32Array(),
            "governance_form": governance_form_to_storage_string(GOVERNANCE_FORM_DEFAULT),
        }
    var st: Dictionary = st_v as Dictionary
    return {
        "type": str(st.get("governance_type", "anarchy")),
        "ruler_id": int(st.get("current_ruler_id", -1)),
        "council_ids": st.get("council_ids", PackedInt32Array()),
        "governance_form": str(
                st.get("governance_form", governance_form_to_storage_string(GOVERNANCE_FORM_DEFAULT))
        ),
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
    var ws: Dictionary = _coerce_war_status_from_settlement(st)
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
    var ws: Dictionary = _coerce_war_status_from_settlement(st)
    var set_pawns: Array[Pawn] = _pawns_in_settlement_indexed(st)
    var center: int = int(st.get("center_region", -1))
    if str(ws.get("state", "peace")) == "at_war":
        _assign_military_hierarchy(set_pawns)
        if center >= 0 and not bool(_war_command_announced.get(center, false)):
            _war_command_announced[center] = true
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
                p.data.military_rank_legacy = "grunt"


func _resolve_war_votes(settlement_idx: int) -> void:
    if settlement_idx < 0 or settlement_idx >= settlements.size() or not (settlements[settlement_idx] is Dictionary):
        return
    var st: Dictionary = settlements[settlement_idx] as Dictionary
    var ws: Dictionary = _coerce_war_status_from_settlement(st)
    var pawns: Array[Pawn] = _pawns_in_settlement_indexed(st)
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
        var set_pawns: Array[Pawn] = _pawns_in_settlement_indexed(st)
        _assign_military_hierarchy(set_pawns)
        var center: int = int(st.get("center_region", -1))
        if center >= 0 and not bool(_war_command_announced.get(center, false)):
            _war_command_announced[center] = true
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
    # Build index pairs, sort by influence, then pick top N — avoids array duplicate.
    var scored: Array = []
    for p in pawns:
        if p.data != null:
            scored.append({"p": p, "inf": p.data.influence, "id": int(p.data.id)})
    scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
        if not is_equal_approx(a["inf"], b["inf"]):
            return a["inf"] > b["inf"]
        return a["id"] < b["id"]
    )
    var result: Array[Pawn] = []
    var limit: int = mini(count, scored.size())
    for i in range(limit):
        result.append(scored[i]["p"])
    return result


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
            p.data.military_rank_legacy = "battlemaster"
        elif i < 4:
            p.data.military_rank_legacy = "commander"
        elif i < 14:
            p.data.military_rank_legacy = "captain"
        elif i < 34:
            p.data.military_rank_legacy = "sarj"
        else:
            p.data.military_rank_legacy = "grunt"


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
    var src_score: float = _settlement_military_score(_pawns_in_settlement_indexed(src_st))
    var dst_score: float = _settlement_military_score(_pawns_in_settlement_indexed(dst_st))
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
    return _settlement_military_score(_pawns_in_settlement_indexed(st))


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
    return _coerce_war_status_from_settlement(st)


func update_settlement_intents(tick: int) -> void:
    if tick % INTENT_UPDATE_INTERVAL_TICKS != 0:
        return
    var living_pawns: Array[Pawn] = _living_pawns()
    for i in range(settlements.size()):
        if not (settlements[i] is Dictionary):
            continue
        var st: Dictionary = settlements[i] as Dictionary
        var settlement_pawns: Array[Pawn] = _pawns_in_settlement_indexed(st)
        var local_food_pressure: float = _calculate_local_food_pressure(settlement_pawns)
        var local_housing_pressure: float = _calculate_local_housing_pressure(st, settlement_pawns)
        var war_state: String = _war_state_string_from_settlement(st)
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

        # Life-path awareness: tally dominant paths among settlement pawns.
        var lp_tally: Dictionary = _tally_settlement_life_paths(settlement_pawns)

        # Extend intent lock when ruler path is present (governance stability).
        var ruler_count: int = int(lp_tally.get("ruler", 0))
        if ruler_count > 0 and lock_ticks > 0:
            st["intent_lock_ticks"] = mini(lock_ticks + INTENT_UPDATE_INTERVAL_TICKS, 2000)
            settlements[i] = st
            continue

        var new_intent: String = _derive_settlement_intent_v2(st, local_food_pressure, local_housing_pressure, lp_tally)
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
                "life_path_tally": lp_tally,
            })
        settlements[i] = st

        # Cultural drift from meaning pressure: the world's memory shapes
        # settlement identity over time. Famine → defensive. Safety → open.
        _apply_meaning_drift(st, tick)
        settlements[i] = st

    # Diaspora pressure check: when food + housing + grudge pressure is high,
    # pawns may leave to found a daughter settlement.
    _check_diaspora_pressure(tick)
    # Pressure situation detection: name emergent crises for readability.
    _check_pressure_situations(tick)
    # Generational shift: detect when founding generation dies off.
    _check_generational_shift(tick)


## Cultural drift from meaning pressure: the world's memory shapes settlement identity.
## Settlements in famine-stricken or dangerous regions slowly drift toward DEFENSIVE.
## Settlements in safe, fertile, learned regions slowly drift toward OPEN.
## Drift is slow — culture doesn't flip overnight. It accumulates over many update cycles.
func _apply_meaning_drift(st: Dictionary, tick: int) -> void:
    var center_rk: int = int(st.get("center_region", -1))
    if center_rk < 0:
        return
    # Only drift every 3rd intent update cycle (every ~1500 ticks)
    if posmod(tick, INTENT_UPDATE_INTERVAL_TICKS * 3) != 0:
        return
    var tags: PackedStringArray = WorldMeaning.get_region_tags(center_rk)
    var drift_score: float = 0.0
    for tag in tags:
        match tag:
            # Danger/famine tags push toward DEFENSIVE
            "famine_stricken":
                drift_score -= 0.4
            "hunger_place":
                drift_score -= 0.25
            "repeated_death", "blood_soaked":
                drift_score -= 0.3
            "graveyard":
                drift_score -= 0.35
            "cursed":
                drift_score -= 0.5
            "fire_prone":
                drift_score -= 0.15
            "ruined":
                drift_score -= 0.1
            # Myth formation: ancient danger drives stronger defensive drift
            "old_death_place":
                drift_score -= 0.35
            "ancient_death_place":
                drift_score -= 0.5
            "old_famine":
                drift_score -= 0.3
            "ancient_famine":
                drift_score -= 0.45
            # Safety/abundance tags push toward OPEN
            "safe_hearth":
                drift_score += 0.3
            "fertile":
                drift_score += 0.2
            "learned":
                drift_score += 0.15
            "welcoming":
                drift_score += 0.1
            "resilient":
                drift_score += 0.2
            "educated":
                drift_score += 0.1
            # Myth formation: ancient safety drives stronger open drift
            "old_heart":
                drift_score += 0.35
            "ancient_heart":
                drift_score += 0.5
            "old_wisdom":
                drift_score += 0.25
            "ancient_wisdom":
                drift_score += 0.35
            # Ritual Echo System: active customs push toward OPEN (community bonds)
            "burial_grove":
                drift_score += 0.15  # shared grief = community
            "teaching_ground":
                drift_score += 0.2   # knowledge sharing = openness
            "feast_ground":
                drift_score += 0.15  # shared food = trust
            "builder_yard":
                drift_score += 0.1   # construction = investment
            "gathering_place":
                drift_score += 0.2   # crossroads = cosmopolitanism
            # Faded customs: weaker but still present
            "faded_burial_grove":
                drift_score += 0.05
            "faded_teaching_ground":
                drift_score += 0.08
            "faded_feast_ground":
                drift_score += 0.05
            "faded_builder_yard":
                drift_score += 0.04
            "faded_gathering_place":
                drift_score += 0.08
            # New meaning pipeline: conflict tags push toward DEFENSIVE
            "war_torn":
                drift_score -= 0.4
            "grudge_haunted":
                drift_score -= 0.2
            "war_echo":
                drift_score -= 0.25
            "dangerous_ground":
                drift_score -= 0.2
            "blood_stained":
                drift_score -= 0.1
            "old_battleground":
                drift_score -= 0.25
            "ancient_battleground":
                drift_score -= 0.4
            "faded_war_echo":
                drift_score -= 0.08
            # New meaning pipeline: craft/trade/culture/authority push toward OPEN
            "craftsman_quarter":
                drift_score += 0.15  # industry = investment
            "industrial":
                drift_score += 0.1
            "forge_echo":
                drift_score += 0.12
            "faded_forge_echo":
                drift_score += 0.04
            "governed":
                drift_score += 0.1   # governance = stability
            "seat_of_power":
                drift_score += 0.2   # authority center = confidence
            "trading_post":
                drift_score += 0.15  # trade = openness
            "merchant_quarter":
                drift_score += 0.2
            "market_echo":
                drift_score += 0.12
            "faded_market_echo":
                drift_score += 0.04
            "sacred":
                drift_score += 0.15  # sacred = community
            "hallowed":
                drift_score += 0.25
            "sanctuary_echo":
                drift_score += 0.15
            "faded_sanctuary_echo":
                drift_score += 0.05
            "storied":
                drift_score += 0.1   # legacy = pride
            "ancient_lineage":
                drift_score += 0.2
            "world_touched":
                drift_score += 0.1
            # Myth-amplified new tags
            "old_forge":
                drift_score += 0.08
            "ancient_forge":
                drift_score += 0.15
            "old_throne":
                drift_score += 0.1
            "ancient_throne":
                drift_score += 0.2
            "old_market":
                drift_score += 0.08
            "ancient_market":
                drift_score += 0.15
            "old_sanctuary":
                drift_score += 0.1
            "ancient_sanctuary":
                drift_score += 0.2
    # Apply drift as tiny adjustments to scar_max and reputation_min
    # These are the inputs to _derive_culture_type_v1_for_age
    # Positive drift → more open → lower scar, higher reputation
    # Negative drift → more defensive → higher scar, lower reputation
    var scar_max: int = int(st.get("scar_max", 0))
    var rep_min: int = int(st.get("reputation_min", 0))
    if drift_score > 0.2:
        # Drift toward OPEN: reduce scar, increase reputation
        scar_max = maxi(0, scar_max - 1)
        rep_min = mini(rep_min + 1, 5)
    elif drift_score < -0.2:
        # Drift toward DEFENSIVE: increase scar, decrease reputation
        scar_max = mini(scar_max + 1, 5)
        rep_min = maxi(rep_min - 1, -5)
    st["scar_max"] = scar_max
    st["reputation_min"] = rep_min
    # Knowledge ecology: settlements with lost knowledge drift toward DEFENSIVE
    # (knowledge sealed = cultural loss = fear of forgetting)
    if KnowledgeSystem != null and KnowledgeSystem.has_method("get_knowledge_security_for_settlement"):
        var ksec: Dictionary = KnowledgeSystem.get_knowledge_security_for_settlement(center_rk)
        var lost_count: int = (ksec.get("lost", []) as Array).size()
        if lost_count >= 2:
            scar_max = mini(scar_max + 1, 5)  # Lost knowledge = cultural scar
            rep_min = maxi(rep_min - 1, -5)
        elif lost_count >= 1:
            scar_max = mini(scar_max + 1, 5)  # Mild scar from knowledge loss
    st["scar_max"] = scar_max
    st["reputation_min"] = rep_min
    # Recalculate culture type from the drifted values
    st["culture_type"] = SettlementPlanner.get_culture_type_for_settlement(st)


# === Diaspora Pressure Architecture ===
# When a settlement reaches critical pressure (food + housing + social tension),
# one or more pawns may leave to found a daughter settlement.
# This is not scripted — it emerges from threshold crossing.

const DIASPORA_CHECK_INTERVAL_TICKS: int = 2000
const DIASPORA_CHECK_PHASE_OFFSET: int = 311
const DIASPORA_FOOD_PRESSURE_THRESHOLD: float = 0.7
const DIASPORA_HOUSING_PRESSURE_THRESHOLD: float = 0.7
const DIASPORA_MIN_POPULATION: int = 8  # Settlement must have 8+ pawns for exile to happen
const DIASPORA_MIN_EXILES: int = 2       # At least 2 pawns must leave together
const DIASPORA_MAX_EXILES: int = 5       # Cap on group size
const DIASPORA_GRUDGE_THRESHOLD: float = 0.3  # 30% of pawns must have active grudges

## Check all settlements for diaspora pressure and trigger exile events.
func _check_diaspora_pressure(tick: int) -> void:
    if not GameManager.periodic_phase_due(tick, DIASPORA_CHECK_INTERVAL_TICKS, DIASPORA_CHECK_PHASE_OFFSET):
        return
    if ColonySimServices == null:
        return
    var food_pressure: float = ColonySimServices.get_food_pressure()
    var housing_pressure: float = ColonySimServices.get_housing_pressure()
    # Both pressures must be high simultaneously
    if food_pressure < DIASPORA_FOOD_PRESSURE_THRESHOLD or housing_pressure < DIASPORA_HOUSING_PRESSURE_THRESHOLD:
        return
    # Find settlements with enough population and sufficient grudge density
    for i in range(settlements.size()):
        if not (settlements[i] is Dictionary):
            continue
        var st: Dictionary = settlements[i] as Dictionary
        var center_rk: int = int(st.get("center_region", -1))
        # Count living pawns in this settlement
        var settlement_pawns: Array = []
        var grudge_pawns: Array = []
        for n in PawnSpawner.find_pawns():
            if n == null or not is_instance_valid(n):
                continue
            if not n.has_method("get"):
                continue
            var data_v: Variant = n.get("data")
            if data_v == null:
                continue
            var pawn_sid: int = data_v.settlement_id
            if pawn_sid != center_rk:
                continue
            settlement_pawns.append(n)
            # Check for active grudges
            var nn = data_v.get("neural_network") if data_v != null else null
            if nn != null and nn.has_method("get_strongest_grudge_target_id"):
                if nn.get_strongest_grudge_target_id() >= 0:  # Has an active grudge target
                    grudge_pawns.append(n)
        if settlement_pawns.size() < DIASPORA_MIN_POPULATION:
            continue
        # Grudge density check
        var grudge_ratio: float = float(grudge_pawns.size()) / float(settlement_pawns.size())
        if grudge_ratio < DIASPORA_GRUDGE_THRESHOLD:
            continue
        # Diaspora pressure triggered! Select exile group
        _trigger_exile(st, settlement_pawns, grudge_pawns, tick, food_pressure, housing_pressure)


## Trigger an exile event: select a group of pawns to leave and found a daughter settlement.
func _trigger_exile(parent_settlement: Dictionary, all_pawns: Array, grudge_pawns: Array, tick: int, food_pressure: float, housing_pressure: float) -> void:
    var center_rk: int = int(parent_settlement.get("center_region", -1))
    # Select exile group: prioritize pawns with strongest grudges
    # Deterministic: sort by pawn id, then pick from grudge_pawns
    var candidates: Array = []
    for n in grudge_pawns:
        if n == null or not is_instance_valid(n):
            continue
        var data_v: Variant = n.get("data")
        if data_v == null:
            continue
        candidates.append({"node": n, "id": int(data_v.id)})
    candidates.sort_custom(func(a, b): return int(a["id"]) < int(b["id"]))
    # Pick exile group size (2-5, capped by available candidates)
    var group_size: int = mini(DIASPORA_MAX_EXILES, maxi(DIASPORA_MIN_EXILES, candidates.size() / 2))
    if candidates.size() < DIASPORA_MIN_EXILES:
        return  # Not enough candidates
    var exile_group: Array = []
    for j in range(mini(group_size, candidates.size())):
        exile_group.append(candidates[j]["node"])
    if exile_group.size() < DIASPORA_MIN_EXILES:
        return
    # Find a suitable founding location (unclaimed region, 15+ tiles from parent)
    var parent_center: Vector2i = SettlementPlanner._center_tile_of_region_key(center_rk)
    var founding_tile: Vector2i = _find_exile_founding_tile(parent_center, tick)
    if founding_tile.x < 0:
        return  # No suitable location found
    # Record the exile event in WorldMemory
    var exile_ids: Array = []
    for n in exile_group:
        var data_v: Variant = n.get("data")
        if data_v != null:
            exile_ids.append(int(data_v.id))
    var founding_rk: int = WorldMemory._region_key(founding_tile.x, founding_tile.y)
    var pressure_chain: String = "food:%.2f+housing:%.2f+grudge:%.2f" % [food_pressure, housing_pressure, float(grudge_pawns.size()) / float(all_pawns.size())]
    WorldMemory.record_event({
        "type": "diaspora_exile",
        "k": WorldMemory.Kind.MIGRATION_STARTED,
        "r": founding_rk,
        "t": tick,
        "from_region": center_rk,
        "to_region": founding_rk,
        "exile_pawn_ids": exile_ids,
        "parent_settlement": center_rk,
        "pressure_chain": pressure_chain,
    })
    # Mark exiled pawns with diaspora state
    for n in exile_group:
        var data_v: Variant = n.get("data")
        if data_v == null:
            continue
        data_v.settlement_id = -1  # Remove from parent settlement
        data_v._diaspora_origin = center_rk  # Track origin for homesickness
        data_v._diaspora_tick = tick
        # Path the pawn toward the founding location
        if n.has_method("autonomy_draft_goto"):
            n.autonomy_draft_goto(founding_tile, "diaspora_exile", 0)
    # Record founding pressure on the new settlement (will be created when pawns arrive)
    _pending_diaspora_foundings[founding_rk] = {
        "parent_settlement_id": center_rk,
        "founding_pressure": pressure_chain,
        "founding_tick": tick,
        "exile_ids": exile_ids,
    }


## Pending diaspora foundings: region_key -> founding info
## When pawns arrive and settle, the settlement is created with parent info.
var _pending_diaspora_foundings: Dictionary = {}


## Find a suitable tile for exile founding.
## Must be unclaimed, passable, and 15+ tiles from parent center.
func _find_exile_founding_tile(parent_center: Vector2i, tick: int) -> Vector2i:
    var wd_node = get_node_or_null("/root/World")
    if wd_node == null:
        return Vector2i(-1, -1)
    var wd = wd_node.get("data") if wd_node.has_method("get") else null
    if wd == null:
        return Vector2i(-1, -1)
    if not wd.has_method("in_bounds"):
        return Vector2i(-1, -1)
    # Deterministic search: spiral outward from a seed offset
    var seed_val: int = posmod(tick * 31 + parent_center.x * 9176 + parent_center.y * 131, 1000)
    var angle_offset: float = float(seed_val % 360) * PI / 180.0
    for dist in range(15, 40):
        for angle_step in range(8):
            var angle: float = angle_offset + float(angle_step) * PI / 4.0
            var tx: int = int(round(parent_center.x + float(dist) * cos(angle)))
            var ty: int = int(round(parent_center.y + float(dist) * sin(angle)))
            if not wd.in_bounds(tx, ty):
                continue
            if not wd.is_passable(tx, ty):
                continue
            var rk: int = WorldMemory._region_key(tx, ty)
            # Check if region is unclaimed
            if _region_state.has(rk):
                continue
            return Vector2i(tx, ty)
    return Vector2i(-1, -1)


## When a settlement is built from regions, check if it's a diaspora founding
## and apply parent settlement info.
func _apply_diaspora_founding(st: Dictionary, center_rk: int) -> void:
    if _pending_diaspora_foundings.has(center_rk):
        var info: Dictionary = _pending_diaspora_foundings[center_rk]
        st["parent_settlement_id"] = int(info.get("parent_settlement_id", -1))
        st["founding_pressure"] = str(info.get("founding_pressure", ""))
        st["founding_tick"] = int(info.get("founding_tick", -1))
        # Copy degraded cultural tags from parent
        var parent_id: int = int(info.get("parent_settlement_id", -1))
        if parent_id >= 0:
            var parent_st: Variant = get_settlement_at_region(parent_id)
            if parent_st != null and parent_st is Dictionary:
                var parent_tags: Variant = (parent_st as Dictionary).get("cultural_tags", [])
                if parent_tags is Array:
                    # Degraded copy: keep 60% of tags (deterministic based on tick)
                    var kept_tags: Array = []
                    var tick_salt: int = int(info.get("founding_tick", 0))
                    for idx in range(parent_tags.size()):
                        if posmod(tick_salt + idx * 7, 10) < 6:  # 60% retention
                            kept_tags.append(parent_tags[idx])
                    st["cultural_tags"] = kept_tags
        # Add founding pressure tag
        var pressure: String = str(info.get("founding_pressure", ""))
        if not pressure.is_empty():
            var tags: Variant = st.get("cultural_tags", [])
            if tags is Array:
                tags.append("founded_by_exile:" + pressure)
                st["cultural_tags"] = tags
        _pending_diaspora_foundings.erase(center_rk)


## Derive settlement intent with life-path awareness. This is a v2 version
## that factors in the dominant life paths of settlement pawns.
## - Farmers bias toward GROW (food production)
## - Soldiers bias toward DEFEND (lower mobilization threshold)
## - Wanderers bias toward exploration-driven RECOVER exit
## - Rulers bias toward governance stability (intent lock extension)
func _derive_settlement_intent_v2(
    st: Dictionary,
    local_food_pressure: float,
    local_housing_pressure: float,
    life_path_tally: Dictionary,
) -> String:
    var settlement_state: String = str(st.get("state", ""))
    var war_state: String = _war_state_string_from_settlement(st)

    # Recovering states are sticky unless wanderers push exploration.
    if settlement_state == "recovering" or settlement_state == "revivable":
        var wanderer_count: int = int(life_path_tally.get("wanderer", 0))
        # Enough wanderers can break recovery early through scouting.
        if wanderer_count >= 3:
            return INTENT_GROW
        return INTENT_RECOVER

    # War states: soldiers reinforce defense, but rulers can negotiate peace.
    if war_state == "mobilizing" or war_state == "at_war":
        return INTENT_DEFEND

    # Food pressure: farmers mitigate hoarding by producing food.
    var farmer_count: int = int(life_path_tally.get("farmer", 0))
    var effective_food_pressure: float = local_food_pressure
    if farmer_count > 0:
        # Each farmer reduces effective food pressure by 5% (diminishing returns).
        var relief: float = float(farmer_count) * 0.05
        relief = min(relief, 0.3)  # Cap at 30% relief
        effective_food_pressure = maxf(0.0, effective_food_pressure - relief)
    if effective_food_pressure >= 0.55:
        return INTENT_HOARD

    # Housing pressure: soldiers build fortifications, reducing urgency.
    var soldier_count: int = int(life_path_tally.get("soldier", 0))
    var effective_housing_pressure: float = local_housing_pressure
    if soldier_count > 0:
        var relief: float = float(soldier_count) * 0.03
        relief = min(relief, 0.2)
        effective_housing_pressure = maxf(0.0, effective_housing_pressure - relief)
    if effective_housing_pressure >= LOCAL_HOUSING_PRESSURE_THRESHOLD:
        return INTENT_RECOVER

    return INTENT_GROW


## Tally the life paths of all pawns in a settlement. Returns a dictionary
## with keys "farmer", "soldier", "ruler", "wanderer" and integer counts.
func _tally_settlement_life_paths(pawns: Array[Pawn]) -> Dictionary:
    var tally: Dictionary = {"farmer": 0, "soldier": 0, "ruler": 0, "wanderer": 0}
    for p in pawns:
        if p == null or p.data == null:
            continue
        var lp: int = int(p.data.life_path)
        match lp:
            1: tally["farmer"] = int(tally["farmer"]) + 1
            2: tally["soldier"] = int(tally["soldier"]) + 1
            3: tally["ruler"] = int(tally["ruler"]) + 1
            4: tally["wanderer"] = int(tally["wanderer"]) + 1
    return tally


func _derive_settlement_intent(st: Dictionary, local_food_pressure: float, local_housing_pressure: float) -> String:
    var settlement_state: String = str(st.get("state", ""))
    var war_state: String = _war_state_string_from_settlement(st)
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
    return JobManager.get_active_jobs_union()


func _default_resource_pressure() -> Dictionary:
    return {
        # This is a local work-demand/focus proxy, not true stock scarcity.
        "wood": 0.0,
        "stone": 0.0,
        "ore_proxy": 0.0,
        "food": 0.0,
        "trade": 0.0,
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
    if job_type == Job.Type.FORAGE or job_type == Job.Type.HUNT:
        return "food"
    if job_type == Job.Type.TRADE_HAUL:
        return "trade"
    return ""


func _derive_settlement_resource_pressure(st: Dictionary, active_jobs: Array[Job]) -> Dictionary:
    var center: int = int(st.get("center_region", -1))
    var wood_count: int = 0
    var stone_count: int = 0
    var ore_count: int = 0
    var food_count: int = 0
    var trade_count: int = 0
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
            "food":
                food_count += 1
            "trade":
                trade_count += 1
    var out: Dictionary = _default_resource_pressure()
    out["total_relevant_jobs"] = total_relevant
    if total_relevant <= 0:
        return out
    var denom: float = float(total_relevant)
    out["wood"] = clamp(float(wood_count) / denom, 0.0, 1.0)
    out["stone"] = clamp(float(stone_count) / denom, 0.0, 1.0)
    out["ore_proxy"] = clamp(float(ore_count) / denom, 0.0, 1.0)
    out["food"] = clamp(float(food_count) / denom, 0.0, 1.0)
    out["trade"] = clamp(float(trade_count) / denom, 0.0, 1.0)
    # Apply saturation damping to reduce circular job-proxy amplification.
    out["wood"] = minf(float(out.get("wood", 0.0)), RESOURCE_PRESSURE_SATURATION)
    out["stone"] = minf(float(out.get("stone", 0.0)), RESOURCE_PRESSURE_SATURATION)
    out["ore_proxy"] = minf(float(out.get("ore_proxy", 0.0)), RESOURCE_PRESSURE_SATURATION)
    out["food"] = minf(float(out.get("food", 0.0)), RESOURCE_PRESSURE_SATURATION)
    out["trade"] = minf(float(out.get("trade", 0.0)), RESOURCE_PRESSURE_SATURATION)
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
                    + "current_intent=%s rp_wood=%.4f rp_stone=%.4f rp_ore_proxy=%.4f rp_food=%.4f rp_trade=%.4f rp_total_relevant_jobs=%d "
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
                float(rp.get("food", 0.0)),
                float(rp.get("trade", 0.0)),
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
        "food":
            return "Food work-focus"
        "trade":
            return "Trade work-focus"
        _:
            return "Unspecialized"


func _channel_to_settlement_specialization_label(channel: String) -> String:
    match channel:
        "wood":
            return "Logging"
        "stone":
            return "Quarry"
        "ore_proxy":
            return "Mining"
        "food":
            return "Farming"
        "trade":
            return "Trade"
        _:
            return "Unspecialized"


func _sync_soul_society_settlement_fields(st: Dictionary) -> void:
    var ch: String = str(st.get("specialization_channel", ""))
    st["settlement_specialization"] = _channel_to_settlement_specialization_label(ch)
    var tags: Array[String] = []
    var cult: int = int(st.get("culture_type", SettlementPlanner.CULTURE_CAUTIOUS))
    if cult == SettlementPlanner.CULTURE_DEFENSIVE:
        tags.append("Martial")
        tags.append("Walled")
    elif cult == SettlementPlanner.CULTURE_OPEN:
        tags.append("Pacifist")
        tags.append("Mercantile")
    else:
        tags.append("Cautious")
    st["cultural_tags"] = tags


func _specialization_sorted_channels(rp: Dictionary) -> Array[Dictionary]:
    var rows: Array[Dictionary] = [
        {"k": "wood", "v": float(rp.get("wood", 0.0))},
        {"k": "stone", "v": float(rp.get("stone", 0.0))},
        {"k": "ore_proxy", "v": float(rp.get("ore_proxy", 0.0))},
        {"k": "food", "v": float(rp.get("food", 0.0))},
        {"k": "trade", "v": float(rp.get("trade", 0.0))},
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
    _sync_soul_society_settlement_fields(st)


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
        # Intents only shift when `update_settlement_intents` runs, so avoid
        # scanning all settlements every tick.
        if tick % INTENT_SHIFT_SCAN_INTERVAL_TICKS != 0:
            return
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


## Trigger audio cue for settlement meaning transition
## Maps settlement state changes to meaning labels for audio cue system
func _trigger_meaning_audio_cue(center_id: int, old_state: String, new_state: String) -> void:
    if not is_instance_valid(MeaningAudioCue):
        return
    
    # Map settlement states to meaning labels
    var from_label: String = _state_to_meaning_label(old_state)
    var to_label: String = _state_to_meaning_label(new_state)
    
    # Only trigger if meaning label actually changed
    if from_label == to_label:
        return
    
    MeaningAudioCue.play_cue(center_id, from_label, to_label)


## Map settlement state to meaning label for audio cues
func _state_to_meaning_label(state: String) -> String:
    match state:
        "active":
            return "quiet"
        "revivable":
            return "scarred"
        "recovering":
            return "scarred"  # recovering settlements are still scarred but healing
        "abandoned":
            return "bloodied"
        "permanently_abandoned":
            return "grave"
    return "quiet"


func get_settlement_intent_for_tile(tile_pos: Vector2i) -> String:
    var rk: int = WorldMemory._region_key(tile_pos.x, tile_pos.y)
    var st_v: Variant = get_settlement_at_region(rk)
    if st_v is Dictionary:
        return str((st_v as Dictionary).get("current_intent", INTENT_GROW))
    return INTENT_GROW


## Get settlement state for a region (Phase 4: posture visual indicators)
## Returns empty string if region is not part of any settlement
func get_state_for_region(region_key: int) -> String:
    if _region_state.has(region_key):
        return str(_region_state[region_key])
    return ""


func get_resource_pressure_for_tile(tile_pos: Vector2i) -> Dictionary:
    var rk: int = WorldMemory._region_key(tile_pos.x, tile_pos.y)
    var st_v: Variant = get_settlement_at_region(rk)
    if st_v is Dictionary:
        var rp_v: Variant = (st_v as Dictionary).get("resource_pressure", _default_resource_pressure())
        if rp_v is Dictionary:
            return (rp_v as Dictionary).duplicate(true)
    return _default_resource_pressure()


# ============================================================
## Law & Custom System
# ============================================================

## Laws affect: behavior, penalties, rewards
## Structure: settlement_id -> Array of law dictionaries

var _laws: Dictionary = {}  ## settlement_id -> Array[Dictionary]
var _law_id_counter: int = 1


## Add a law to a settlement
## law_data should contain: type, description, penalties, rewards
func add_law(settlement_id: int, law_data: Dictionary) -> int:
    if settlement_id < 0:
        push_error("[SettlementMemory] Invalid settlement_id for add_law")
        return -1
    
    if not _laws.has(settlement_id):
        _laws[settlement_id] = []
    
    var law_id: int = _law_id_counter
    _law_id_counter += 1
    
    var law: Dictionary = {
        "id": law_id,
        "settlement_id": settlement_id,
        "type": law_data.get("type", "custom"),
        "description": law_data.get("description", ""),
        "penalties": law_data.get("penalties", []),
        "rewards": law_data.get("rewards", []),
        "created_tick": GameManager.tick_count if (GameManager != null) else 0,
        "active": true,
    }
    
    (_laws[settlement_id] as Array).append(law)
    
    ## Record in WorldMemory
    if WorldMemory != null and WorldMemory.has_method("record_event"):
        WorldMemory.record_event({
            "type": "law_added",
            "settlement_id": settlement_id,
            "law_id": law_id,
            "law_type": law.get("type", "custom"),
            "tick": GameManager.tick_count if (GameManager != null) else 0,
        })
    
    return law_id


## Remove a law from a settlement
func remove_law(settlement_id: int, law_id: int) -> bool:
    if not _laws.has(settlement_id):
        return false
    
    var laws_array: Array = _laws[settlement_id] as Array
    for i in range(laws_array.size() - 1, -1, -1):
        var law: Dictionary = laws_array[i] as Dictionary
        if int(law.get("id", -1)) == law_id:
            laws_array.remove_at(i)
            ## Record in WorldMemory
            if WorldMemory != null and WorldMemory.has_method("record_event"):
                WorldMemory.record_event({
                    "type": "law_removed",
                    "settlement_id": settlement_id,
                    "law_id": law_id,
                    "tick": GameManager.tick_count if (GameManager != null) else 0,
                })
            return true
    return false


## Get all laws for a settlement
func get_laws(settlement_id: int) -> Array:
    if not _laws.has(settlement_id):
        return []
    return (_laws[settlement_id] as Array).duplicate(true)


## Get a specific law by ID
func get_law(settlement_id: int, law_id: int) -> Dictionary:
    if not _laws.has(settlement_id):
        return {}
    
    var laws_array: Array = _laws[settlement_id] as Array
    for law_v in laws_array:
        if law_v is Dictionary:
            var law: Dictionary = law_v as Dictionary
            if int(law.get("id", -1)) == law_id:
                return law.duplicate(true)
    return {}


## Check if a pawn violates any laws
## Returns: Array of violated law IDs
func check_law_violations(settlement_id: int, pawn_data: Dictionary) -> Array:
    var violations: Array = []
    if not _laws.has(settlement_id):
        return violations
    
    var laws_array: Array = _laws[settlement_id] as Array
    for law_v in laws_array:
        if law_v is not Dictionary:
            continue
        var law: Dictionary = law_v as Dictionary
        if not law.get("active", true):
            continue
        
        ## Check penalties (simplified check)
        var penalties = law.get("penalties", [])
        ## This is where you'd check pawn_data against penalties
        ## For now, just return the law ID if active
        violations.append(int(law.get("id", -1)))
    
    return violations


## Save/Load support
func _laws_to_save_dict() -> Dictionary:
    return {
        "laws": _laws.duplicate(true),
        "law_id_counter": _law_id_counter,
    }

func _laws_from_save_dict(d: Dictionary) -> void:
    _laws.clear()
    _law_id_counter = 1

    if d.has("laws"):
        _laws = d["laws"].duplicate(true)
    if d.has("law_id_counter"):
        _law_id_counter = int(d["law_id_counter"])


# === Pressure Situation Detector ===
# When multiple pressures converge, detect and name the situation.
# This makes emergent crises readable to the player.

const SITUATION_CHECK_INTERVAL_TICKS: int = 500
const SITUATION_CHECK_PHASE_OFFSET: int = 73

## Current active situations per settlement: center_rk -> Array of { name, severity, tick }
var _active_situations: Dictionary = {}

## Detect pressure convergence situations for all settlements.
func _check_pressure_situations(tick: int) -> void:
    if not GameManager.periodic_phase_due(tick, SITUATION_CHECK_INTERVAL_TICKS, SITUATION_CHECK_PHASE_OFFSET):
        return
    if ColonySimServices == null:
        return
    var food_pressure: float = ColonySimServices.get_food_pressure()
    var housing_pressure: float = ColonySimServices.get_housing_pressure()

    for i in range(settlements.size()):
        if not (settlements[i] is Dictionary):
            continue
        var st: Dictionary = settlements[i] as Dictionary
        var center_rk: int = int(st.get("center_region", -1))
        var situations: Array = []

        # Count living pawns and check various pressures
        var pop: int = 0
        var elder_count: int = 0
        var youth_count: int = 0
        var grudge_count: int = 0
        for n in PawnSpawner.find_pawns():
            if n == null or not is_instance_valid(n):
                continue
            if not n.has_method("get"):
                continue
            var data_v: Variant = n.get("data")
            if data_v == null:
                continue
            if int(data_v.settlement_id) != center_rk:
                continue
            pop += 1
            var pawn_age: int = int(data_v.age)
            if pawn_age >= 60:
                elder_count += 1
            elif pawn_age < 18:
                youth_count += 1
            var nn = data_v.get("neural_network") if data_v != null else null
            if nn != null and nn.has_method("get_strongest_grudge_target_id"):
                if nn.get_strongest_grudge_target_id() >= 0:
                    grudge_count += 1

        # Famine situation
        if food_pressure >= 0.8:
            situations.append({"name": "famine", "severity": 1.0, "tick": tick})
        elif food_pressure >= 0.5:
            situations.append({"name": "food_shortage", "severity": 0.5, "tick": tick})

        # Overcrowding situation
        if housing_pressure >= 0.8:
            situations.append({"name": "overcrowding", "severity": 1.0, "tick": tick})
        elif housing_pressure >= 0.5:
            situations.append({"name": "housing_strain", "severity": 0.5, "tick": tick})

        # Knowledge crisis
        if KnowledgeSystem != null and KnowledgeSystem.has_method("get_knowledge_security_for_settlement"):
            var ksec: Dictionary = KnowledgeSystem.get_knowledge_security_for_settlement(center_rk)
            var lost_count: int = (ksec.get("lost", []) as Array).size()
            var at_risk_count: int = (ksec.get("at_risk", []) as Array).size()
            if lost_count >= 2:
                situations.append({"name": "knowledge_crisis", "severity": 1.0, "tick": tick})
            elif at_risk_count >= 3:
                situations.append({"name": "knowledge_at_risk", "severity": 0.6, "tick": tick})

        # Social tension
        if pop > 0 and grudge_count > 0:
            var grudge_ratio: float = float(grudge_count) / float(pop)
            if grudge_ratio >= 0.5:
                situations.append({"name": "social_crisis", "severity": 1.0, "tick": tick})
            elif grudge_ratio >= 0.3:
                situations.append({"name": "social_tension", "severity": 0.5, "tick": tick})

        # Generational shift: elder majority dying off
        if pop > 0 and elder_count >= pop / 2 and elder_count >= 3:
            situations.append({"name": "generational_shift", "severity": 0.7, "tick": tick})

        # Composite situations: when two or more pressures converge
        var high_severity: int = 0
        for s in situations:
            if float(s.get("severity", 0.0)) >= 0.8:
                high_severity += 1
        if high_severity >= 2:
            situations.append({"name": "convergence_crisis", "severity": 1.0, "tick": tick})

        # Record new situations to WorldMemory
        var prev_situations: Array = _active_situations.get(center_rk, [])
        var prev_names: Dictionary = {}
        for ps in prev_situations:
            prev_names[str(ps.get("name", ""))] = true
        for s in situations:
            var s_name: String = str(s.get("name", ""))
            if not prev_names.has(s_name):
                # New situation detected — record it
                WorldMemory.record_event({
                    "type": "pressure_situation",
                    "k": WorldMemory.Kind.SETTLEMENT_EVENT,
                    "r": center_rk,
                    "t": tick,
                    "situation": s_name,
                    "severity": float(s.get("severity", 0.0)),
                })

        _active_situations[center_rk] = situations


## Get active situations for a settlement.
func get_active_situations(center_rk: int) -> Array:
    return _active_situations.get(center_rk, [])


# === Generational Shift Tracker ===
# Tracks when the founding generation dies off and a new generation takes over.

## Founding generation: tick -> pawn_ids born within 1000 ticks of settlement founding
var _founding_generation: Dictionary = {}  # center_rk -> Array of pawn_ids

## Check for generational shifts. When the founding generation is mostly dead,
## record a generational shift event.
func _check_generational_shift(tick: int) -> void:
    if not GameManager.periodic_phase_due(tick, 3000, 431):
        return
    for i in range(settlements.size()):
        if not (settlements[i] is Dictionary):
            continue
        var st: Dictionary = settlements[i] as Dictionary
        var center_rk: int = int(st.get("center_region", -1))
        var founding_tick: int = int(st.get("founding_tick", -1))
        if founding_tick < 0:
            # Use birth_tick of oldest living pawn as proxy
            var oldest_tick: int = 999999999
            for n in PawnSpawner.find_pawns():
                if n == null or not is_instance_valid(n):
                    continue
                if not n.has_method("get"):
                    continue
                var data_v: Variant = n.get("data")
                if data_v == null:
                    continue
                if int(data_v.settlement_id) != center_rk:
                    continue
                if int(data_v.birth_tick) < oldest_tick:
                    oldest_tick = int(data_v.birth_tick)
            if oldest_tick < 999999999:
                founding_tick = oldest_tick
            else:
                continue
        # Identify founding generation: pawns born within 2000 ticks of founding
        if not _founding_generation.has(center_rk):
            var founders: Array = []
            for n in PawnSpawner.find_pawns():
                if n == null or not is_instance_valid(n):
                    continue
                if not n.has_method("get"):
                    continue
                var data_v: Variant = n.get("data")
                if data_v == null:
                    continue
                if int(data_v.settlement_id) != center_rk:
                    continue
                if absi(int(data_v.birth_tick) - founding_tick) <= 2000:
                    founders.append(int(data_v.id))
            if founders.size() >= 2:
                _founding_generation[center_rk] = founders
        # Check if most founders are dead
        if _founding_generation.has(center_rk):
            var founders: Array = _founding_generation[center_rk]
            var alive_count: int = 0
            for fid in founders:
                for n in PawnSpawner.find_pawns():
                    if n == null or not is_instance_valid(n):
                        continue
                    if not n.has_method("get"):
                        continue
                    var data_v: Variant = n.get("data")
                    if data_v == null:
                        continue
                    if int(data_v.id) == int(fid):
                        alive_count += 1
                        break
            # If 75%+ of founders are dead, generational shift
            if founders.size() >= 2 and alive_count <= founders.size() / 4:
                WorldMemory.record_event({
                    "type": "generational_shift",
                    "k": WorldMemory.Kind.SETTLEMENT_EVENT,
                    "r": center_rk,
                    "t": tick,
                    "founders_total": founders.size(),
                    "founders_alive": alive_count,
                })
                # Clear founding generation — shift recorded once
                _founding_generation.erase(center_rk)
