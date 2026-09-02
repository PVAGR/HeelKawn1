# State Verification — August 17, 2026 (Session 2: Idle Short-Circuit + Throttle)

## What Changed
1. **FIX 1 — `open_count() <= 0` short-circuit** (`HeelKawnian.gd:4702-4709`): When `JobManager.open_count() <= 0`, `_tick_idle` returns immediately after recording `job_search` time. Skips the entire expensive job-search setup (priority_cb lambda, base_passes lambda, 20+ variable declarations, 5 inner lambdas). This eliminates ~23ms per idle tick for all pawns with no jobs to claim.

2. **FIX 2 — Job claim throttle** (`HeelKawnian.gd:3926-3927`): `_job_claim_interval_for_speed()` returns `3` instead of `1`. Idle pawns only do a full job scan every 3rd tick (staggered by pawn ID), reducing scan frequency by 67%.

## Verification
- Compile check: PASS (zero errors, headless `--script-check` succeeded)
- Headless 301-tick profiler windows captured (2 windows)

## Before vs After (Headless, 24 pawns, 301 ticks)

| Metric | Before | After | Change |
|--------|--------|-------|--------|
| HeelKawnian avg/pawn/tick | 2.72ms | 0.12ms | **-96%** |
| IDLE job_search calls | 801 | 7 | **-99%** |
| IDLE job_search total | 19,037ms | 180ms | **-99%** |
| IDLE job_search avg/call | 23.8ms | 25.8ms | same (intrinsic) |

## Remaining Bottlenecks
- **AIAgentManager**: ~584ms per 301-tick window (~1.9ms/tick). Dominated by `world_ai` subcategory.
- **state_dispatch**: ~609ms per 301-tick window (~0.086ms/dispatch). 7000+ dispatches across all states.
- **priority_cb lambda**: When a pawn DOES enter the full scan, the 430-line lambda + 5 inner lambdas still cost ~25-39ms. This now happens so rarely (7 times per 301 ticks) that it's negligible.

## Risk Assessment
- **Determinism**: Preserved. `open_count() <= 0` is a pure read with no state mutation. Throttle uses `posmod(now_tick + pid*37, interval)` for stable staggering.
- **Behavioral change**: Pawns with no open jobs no longer allocate lambda objects every tick. Pawns with jobs available still scan every 3rd tick — minor delay in claiming new jobs (~2 tick latency) but no missed claims.
- **Regression risk**: Low. The short-circuit is gated on `JobManager.open_count() == 0` — identical behavior to before when jobs exist.

## Unverified/Risky
- The inner resolve_* lambdas (5 closures per idle tick) still allocate when the full scan runs. Would benefit from extraction to member functions in a future pass.
- `priority_cb` and `base_passes` lambda definitions (430+50 lines) still recreated when full scan runs. Member function extraction would eliminate this but is a larger refactor.
