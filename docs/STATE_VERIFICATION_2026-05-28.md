# HeelKawn Verification Snapshot — 2026-05-28

## Scope (Session 1 / 5)
- Establish a current performance/stability baseline from this environment.
- Apply one low-risk precision fix that reduces false chain progression and downstream churn.

## Environment Reality
- Godot runtime binary is not available in this environment.
- Runtime smoke/perf scenes cannot be executed here.
- Validation is limited to static checks + repository gates.

## Baseline Evidence Collected
- Branch: `main`
- Starting commit for this session: `0103a9fd`
- Main scene configured: `res://scenes/main/Main.tscn`
- Required gate:
  - `bash tools/ai/sim-quality-gate.sh` → PASS
  - Runtime smoke portion skipped by gate due missing Godot binary.

## Implemented In This Pass

1. Chain completion precision guard
- File: `autoloads/HeelKawnianManager.gd`
- Updated `_chain_step_completed(...)` with prerequisite-aware conditions.
- Examples:
  - `Found Settlement/build_storage` now requires hearth + beds + storage, not storage alone.
  - `Found Settlement/build_farm` now requires hearth + storage/granary context + farm.
  - `Fortify/build_door` now requires wall context + door.
  - `Knowledge Hub/build_marker` now requires library + school + marker.
  - `Food Security/build_cellar` now requires farm + granary + cellar.
- Effect:
  - Reduces false-positive step completion in dense settlements where nearby unrelated features previously satisfied single-count checks.
  - Keeps chain progression tied to coherent local development order.

## Determinism Notes
- No unseeded RNG added.
- No frame-time branching added to canonical truth paths.
- Change is purely stricter boolean gating over existing deterministic feature scans.

## Residual Risk
- Real frame-time smoothness at `1x/26x/50x/100x` remains unverified in this environment without Godot runtime.
- Next sessions should execute in-engine perf scenes and tick profilers on a machine with Godot installed.

## Session 2 Update (Core Throughput)

2. Reduced repeated settlement scans in ambition/recovery hot paths
- File: `autoloads/HeelKawnianManager.gd`
- Changes:
  - Added `_recovery_feature_cache` and `_recovery_population_cache` keyed by settlement id.
  - `_scan_recovery_features(...)` now uses a deterministic tick TTL cache.
  - `_recovery_population(...)` now uses the same style cache.
  - Added `_recovery_cache_ttl_ticks_for_speed()` so cache lifetime scales by speed tier (`6x/12x/26x/50x/100x`).
- Expected effect:
  - Fewer repeated local feature scans and settlement list walks when many pawns query ambitions in the same window.
  - Lower overhead in `_recovery_phase(...)` and `_ambition_chain_for_settlement(...)`.

Verification:
- Re-ran `bash tools/ai/sim-quality-gate.sh` after cache optimization: PASS.

## Session 3 Update (Pawn AI Throughput)

3. Cached matrix pending-job queries in pawn hot paths
- File: `scripts/pawn/HeelKawnian.gd`
- Changes:
  - Added `_pending_count_cache_tick` and `_pending_count_cache` to cache pending-job query results per simulation tick.
  - Added `_pending_count_cached(job_type)` wrapper for `JobManager.count_pending_by_type(...)`.
  - Added `_pending_near_cached(center_tile, job_type, radius)` wrapper for `JobManager.count_pending_jobs_near(...)`.
  - Replaced repeated direct pending-count calls in:
    - `_try_heelkawnian_matrix_ambition_seed(...)`
    - `_try_heelkawnian_matrix_preservation_action(...)`
    - `_try_heelkawnian_matrix_learning_seed(...)`
- Expected effect:
  - Lower repeated pending-job scan overhead under high pawn counts and high simulation speeds.
  - Keeps deterministic behavior while reducing same-tick duplicate query work.

Verification:
- Re-ran `bash tools/ai/sim-quality-gate.sh` after pawn query caching: PASS.

## Session 4 Update (Proto Survival Throughput)

4. Cached proto authority pending-near scans during survival posting
- File: `autoloads/AuthorityJobBoard.gd`
- Changes:
  - Added static helper `_pending_near_cached(...)` to reuse `count_pending_jobs_near(...)` results within the same posting pass.
  - `post_critical_proto_survival_if_needed(...)` now uses a local per-call cache for `FORAGE`, `HUNT`, `FISH`, and `BUILD_FIRE_PIT` checks.
  - Cache entries are invalidated after a successful post for that specific job type to keep same-pass follow-up checks accurate.
- Expected effect:
  - Reduces repeated pending-near scans in proto bootstrap survival seeding.
  - Keeps deterministic behavior unchanged while reducing redundant query work.

Verification:
- Re-ran `bash tools/ai/sim-quality-gate.sh` after proto cache optimization: PASS.

## Session 5 Update (Leader Construction Throughput)

5. Cached leader construction pending-near checks per posting pass
- File: `autoloads/HeelKawnianManager.gd`
- Changes:
  - Added a local `pending_near_cache` inside `_leader_direct_construction_jobs(...)`.
  - Replaced repeated direct `JobManager.count_pending_jobs_near(center, job_type, 10)` calls with cache lookups keyed by center/job/radius.
  - Preserves behavior: still blocks posting when pending local jobs already exist for that type.
- Expected effect:
  - Reduces repeated pending-near scans while iterating settlement build queue entries.
  - Improves high-speed settlement construction throughput without altering canonical decisions.

Verification:
- Re-ran `bash tools/ai/sim-quality-gate.sh` after leader build-pass cache optimization: PASS.

## Session 6 Update (Cooking Pressure Throughput)

6. Cached pending cook-job counts in colony pressure calculations
- File: `autoloads/ColonySimServices.gd`
- Changes:
  - Added per-tick pending count cache fields and helper `_pending_by_type_cached(job_type)`.
  - `_cooking_pressure_for_scope(...)` now uses cached counts instead of repeated direct `count_pending_by_type(...)` calls.
- Expected effect:
  - Reduces repeated pending-count scans in demand refresh loops, especially at high speeds.
  - Keeps deterministic behavior unchanged; values still resolve from the same tick snapshot.

Verification:
- Re-ran `bash tools/ai/sim-quality-gate.sh` after cooking-pressure cache optimization: PASS.

## Session 7 Update (Local Pending Radius Throughput)

7. Cached local pending-near job counts per tick in colony services
- File: `autoloads/ColonySimServices.gd`
- Changes:
  - Added per-tick near-query cache fields (`_pending_near_cache_tick`, `_pending_near_cache`).
  - `count_pending_jobs_near(center_tile, job_type, radius)` now caches by center/job/radius key.
  - Applies both when delegating to `JobManager.count_pending_jobs_near(...)` and fallback union scans.
- Expected effect:
  - Reduces duplicate local pending-radius scans during pressure and hearth-gating checks.
  - Preserves deterministic behavior by keeping cache scoped to current simulation tick.

Verification:
- Re-ran `bash tools/ai/sim-quality-gate.sh` after local pending-near cache optimization: PASS.

## Session 8 Update (Fintech Determinism Bridge)

8. Added deterministic external-finance adapter for simulation-safe ingestion
- Files:
  - `autoloads/FintechBridge.gd`
  - `project.godot`
- Changes:
  - Added new `FintechBridge` autoload.
  - External-finance inputs are accepted only as explicit manifests/events with stable ids and `apply_tick`.
  - Events are sorted and applied during `_on_game_tick` only (no wall-clock mutation of world truth).
  - Applied events are recorded in `WorldMemory` (`type=fintech_event_applied`) and mirrored to internal treasury totals by currency.
  - Added deterministic debug helper `debug_seed_meow_credit(...)` for controlled integration tests.
- Expected effect:
  - Establishes a kernel-safe path to integrate real fintech rails (Meow/PVA Bazaar) without violating replayability.
  - Enables future game-economic features (treasury, payouts, institutions) to consume external settlements deterministically.

Verification:
- Re-ran `bash tools/ai/sim-quality-gate.sh` after FintechBridge integration: PASS.

## Session 9 Update (Religious Ethics Determinism Layer)

9. Added deterministic Zoroastrian/Hindu ethics accumulation on top of existing emergent religion
- Files:
  - `autoloads/ReligionSystem.gd`
  - `docs/HEELKAWN_STATE.md`
- Changes:
  - Added periodic ethics scan (`ETHICS_SCAN_INTERVAL`) driven by game ticks only.
  - Added deterministic ingestion of `WorldMemory.get_events()` deltas (tracked by `_last_world_event_index`).
  - Added pawn-level moral state:
    - `_asha_druj_balance` (continuous axis; positive=order/cooperation, negative=entropy/harm pressure)
    - `_karma_score` (integer cumulative consequence score)
  - Added settlement-level moral pressure:
    - `_dharma_index` keyed by settlement center region, normalized by settlement population on each ethics pass.
  - Added finite event→ethics mapping for currently-known event classes:
    - social/prosocial (`teach_skill`, `apprenticeship`, `shelter_built`, `settlement_founded`)
    - collapse/harm (`famine_warning`, `starvation`, `death_starvation`, `death_combat`, `murder`)
    - fintech bridge consequences (`fintech_event_applied` with payout/credit/debit branches)
  - Added read APIs for runtime/diagnostics:
    - `get_pawn_asha_druj_balance(...)`
    - `get_pawn_moral_axis(...)`
    - `get_pawn_karma(...)`
    - `get_settlement_dharma_index(...)`
    - `get_religion_ethics_snapshot()`
- Expected effect:
  - Aligns live simulation behavior with canon pressure model (Asha/Druj, Karma, Dharma) without introducing authored outcomes or nondeterministic branches.
  - Keeps religious/metaphysical interpretation derived from logged events, not direct UI claims.

Verification:
- Re-ran `bash tools/ai/sim-quality-gate.sh` after ReligionSystem ethics integration: PASS.

Residual Risk:
- Runtime behavior under long `100x` runs remains unverified here due missing Godot binary; requires in-engine smoke/perf execution on a Godot-enabled machine.

## Session 10 Update (Egregore + Matrix Runtime Coupling)

10. Added deterministic per-settlement egregore scaffolding and live matrix coupling
- Files:
  - `autoloads/EgregoreMemory.gd`
  - `project.godot`
  - `scripts/pawn/HeelKawnianDecision.gd`
  - `scripts/ui/ColonyHUD.gd`
  - `docs/HEELKAWN_STATE.md`
- Changes:
  - Added new `EgregoreMemory` autoload with tick-gated updates (`UPDATE_INTERVAL_TICKS`) and monotonic `WorldMemory` delta ingestion (`_last_event_index`).
  - Added 8-axis pressure vector per settlement:
    - cooperation, discipline, care, fear, vengeance, curiosity, asceticism, opulence.
  - Added bounded deterministic pressure accumulation + light decay + cohesion calculation from positive/negative pressure balance.
  - Added read APIs for diagnostics and UI:
    - `get_settlement_signature(...)`
    - `get_settlement_pressure(...)`
    - `get_settlement_top_pressures(...)`
    - `get_world_snapshot()`
  - Integrated egregore into live pawn decision pipeline:
    - `HeelKawnianDecision.get_heelkawnian_matrix_job_bias(...)` now adds a bounded settlement egregore bias (clamped) to matrix job bias.
    - Bias mapping currently affects teaching, food/care, defense/fortification, and trade classes.
  - Added observer/watch visibility:
    - `ColonyHUD` now renders an `Egregore[...]` line with cohesion + top 3 dominant pressures for current/nearest formal settlement.

Verification:
- Re-ran `bash tools/ai/sim-quality-gate.sh` after EgregoreMemory and matrix/HUD integration: PASS.

Residual Risk:
- Long-run 1x/100x behavior and visual smoothness for this new layer still require Godot runtime validation in an environment with headless/editor binary available.

## Session 11 Update (Egregore Norm Emergence)

11. Added deterministic emergent taboos/laws from collective pressure
- Files:
  - `autoloads/EgregoreMemory.gd`
  - `scripts/ui/ColonyHUD.gd`
  - `docs/HEELKAWN_STATE.md`
- Changes:
  - Added deterministic norm emergence pass (`_update_emergent_norms`) over per-settlement pressure vectors with tick cooldown hysteresis (`NORM_COOLDOWN_TICKS`).
  - Added active norm state and change tracking:
    - `_active_norms` (per settlement)
    - `_norm_change_tick` (per settlement+norm)
  - Added five first norm types:
    - `mutual_aid`
    - `martial_code`
    - `scholar_path`
    - `austerity_rite`
    - `market_charter`
  - Norm transitions now emit deterministic world facts:
    - `egregore_norm_emerged`
    - `egregore_norm_faded`
  - On norm emergence, `SettlementMemory.add_law(...)` is invoked only when corresponding `egregore_*` law type is absent.
  - Observer HUD now displays active norm list in the `Egregore[...]` line.

Verification:
- Re-ran `bash tools/ai/sim-quality-gate.sh` after emergent norm integration: PASS.

Residual Risk:
- Runtime throughput and long-run institutional oscillation at sustained `100x` still require in-engine verification on a machine with Godot runtime available.

## Session 12 Update (Egregore Migration + Diplomacy Coupling)

12. Wired egregore pressures into cross-settlement relations and migration decisions
- Files:
  - `autoloads/FactionManager.gd`
  - `autoloads/FragmentationManager.gd`
  - `docs/HEELKAWN_STATE.md`
- Changes:
  - Added `_egregore_diplomacy_bias(...)` to `FactionManager` and integrated into `_compute_polity_relation_score(...)`.
  - Bias now derives from per-settlement egregore pressure vectors:
    - increases from prosocial/disciplined/opulent alignment,
    - decreases from fear/vengeance pressure and inter-settlement pressure mismatch.
  - Added `_egregore_migration_bias(...)` to `FragmentationManager` and integrated into fragmentation gates:
    - adjusts pressure gate, population threshold, and migrant move count deterministically.
    - uses both pressure axes and active norms to stabilize or accelerate out-migration.
  - Added audit event `egregore_fragmentation_applied` when egregore migration influence is used in a relocation decision.

Verification:
- Re-ran `bash tools/ai/sim-quality-gate.sh` after migration+diplomacy coupling: PASS.

Residual Risk:
- Sustained high-population (`100x`) behavior still needs runtime verification on a Godot-enabled host to confirm smoothness and population drift shape under prolonged runs.

## Session 13 Update (Institutional Job Priority Coupling)

13. Applied egregore norms to settlement-level ambition and construction priorities
- Files:
  - `autoloads/HeelKawnianManager.gd`
  - `docs/HEELKAWN_STATE.md`
- Changes:
  - Added `_egregore_settlement_priority_bonus(settlement_id, job_type)` in `HeelKawnianManager`.
  - Integrated this bonus into:
    - `get_settlement_ambition_for_pawn(...)` (priority + reason annotation),
    - `leader_direct_construction(...)` (job posting priority before bayes/slot checks).
  - Norm mappings now influence institutional agenda categories:
    - mutual aid: beds/hearth/storage/granary/cooking,
    - martial code: walls/doors/barracks/watchtowers/defense,
    - scholar path: library/school/teaching/knowledge recording,
    - austerity rite: storage and survival gathering,
    - market charter: market/trading post/roads/trade haul.
  - Bonuses are bounded (`clampi`) to keep survival-first behavior stable.

Verification:
- Re-ran `bash tools/ai/sim-quality-gate.sh` after institutional coupling: PASS.

Residual Risk:
- In-engine watch-mode confirmation at prolonged `100x` is still required to verify behavioral readability and pacing in live simulation.
