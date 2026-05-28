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
