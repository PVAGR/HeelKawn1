# HeelKawn Verification Snapshot — 2026-05-29

## Scope
- Add speed-aware budget gates to three remaining hot functions causing lag at 200x

## Environment Reality
- Godot runtime binary is not available in this environment.
- Runtime smoke/perf scenes cannot be executed here.
- Validation is limited to static checks + repository gates.

## Implemented In This Pass

### 1. Speed-aware generational turnover interval
- **File:** `scenes/main/Main.gd`
- Added `_generational_interval_for_speed()` returning 60000/40000/30000/25000 ticks at 200x/100x/50x/26x (was always 20000).
- `_maybe_generational_turnover()` now uses this speed-scaled interval instead of `GENERATION_TICKS` directly.
- Prevents 32ms spike from firing every ~0.5s at 200x.

### 2. Real budget for construction seed job posting
- **File:** `scenes/main/Main.gd`
- `_seed_construction_jobs()` had `budget_usec = 999999999` (uncapped), making internal budget checks meaningless.
- Now sets budget_usec to 2000/4000/8000/12000 at 200x/100x/50x/26x — function exits early when budget consumed.

### 3. Budget gate in SettlementMemory.recompute
- **File:** `autoloads/SettlementMemory.gd`
- Added optional `budget_usec` parameter to `recompute()`.
- Tracks wall-clock start time and checks budget after settlement sort but before post-processing passes (merge, governance, clans, names, etc.).
- Tick-loop caller passes 3000/5000/10000 at 200x/100x/50x.
- Other callers (startup, save load, reroll) pass no budget, running full recompute.

## Determinism Notes
- No unseeded RNG added. All changes are wall-clock budget gates that skip post-processing work when budget is exceeded — core settlement computation is unaffected within a single pass.
- No frame-time branching added to canonical truth paths.

## Residual Risk
- Real frame-time smoothness at `1x/26x/50x/100x` remains unverified in this environment without Godot runtime.
- Pawn AI is spread across dozens of autoload `_on_game_tick` handlers — a global skip mechanic would need careful design and is not addressed here.
- 1x baseline FPS (reported 11-20) is likely a rendering/UI bottleneck and is not addressed here.

## Verification
- `bash tools/ai/sim-quality-gate.sh` → PASS
