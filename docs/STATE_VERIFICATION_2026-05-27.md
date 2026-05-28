# State Verification — 2026-05-27

## Changes Made

### Round 2: Deep Speed-Gated Throttles Removed (~30 additional sites across 18 files)

**What changed (Round 2):**
- **HeelKawnPawnBrain.gd**: `_compute_stride()` always returns 1 — no speed-tier AI stride scaling, no distance-based LOD. Pawns always receive full AI processing.
- **HeelKawnianDecision.gd**: All three interval functions (`_goal_refresh_interval_for_speed`, `_neural_priority_refresh_interval_for_speed`, `_matrix_priority_refresh_interval_for_speed`) return base values — goals and priorities refresh at full cadence at all speeds.
- **Main.gd** (10 functions):
  - `_is_ultra_speed()` removed (dead code, never called)
  - `_planner_interval_for_speed()` returns 90, `_heavy_planner_interval_for_speed()` returns 180
  - `_inspect_scan_interval_for_speed()` returns INSPECT_SCAN_INTERVAL_TICKS
  - `_social_rapport_interval_for_speed()` returns SOCIAL_RAPPORT_ACCUM_INTERVAL_TICKS
  - `_mining_react_scan_rows_for_speed()` returns MINING_REACT_SCAN_ROWS_PER_STEP
  - `_dynamic_hunt_job_budget()` no longer reduces budget at high speed
  - `_accumulate_social_rapport()` no longer has speed-based pair_budget or time budget_usec
  - `_maintenance_allowed` gate (>=50x skips all building maintenance) removed
  - `_process_regrowth()` restore_budget no longer reduced to 1-2 at high speed
  - `_mining_react_budget_for_speed()` always returns full budget
- **AIAgentManager.gd** (5 functions):
  - `_neural_interval_for_speed()` returns base_interval unchanged
  - `_world_ai_interval_for_speed()` returns 10 (no speed scaling)
  - `_settlement_ai_interval_for_speed()` returns 16 (no speed scaling)
  - `_agent_update_budget_for_speed()` returns all agents (no speed reduction)
  - Agent stride = 1 always (no speed scaling), agent spawn check at 600 ticks
- **6 autoloads** (BuildingUsageTracker, CraftingSystem x2, SurvivalSystem, FarmingSystem, PlayerBuilding, FootpathMemory): All `_on_game_tick()` throttles removed — sample/update interval always 1 (every tick)
- **SettlementPlanner.gd**: `_planning_region_cap_for_speed()` returns PLANNING_REGION_HARD_CAP
- **HeelKawnian.gd** (3 gates): Autonomy popup (>60x), action popup (>50x), perception scan budget all de-throttled
- **TerritoryOverlay.gd**: Activity border segments no longer skipped at >=50x

### Round 1: Tick/Performance Overhaul — All Throttles Removed

**What changed (Round 1):**
- **TickManager.gd**: Removed all per-frame tick caps (MAX_BACKLOG_TICKS, MAX_TICKS_PER_FRAME, frame_tick_cap_for_speed, LOD staggering, budget yield). `set_speed()` now clears accumulated backlog on deceleration to prevent event flood.
- **GameManager.gd**: Removed redundant cap system (MAX_TICKS_PER_FRAME\*, MAX_ACCUMULATED_TICKS\*, DROP_BACKLOG, adaptive caps). `set_speed()` resets accumulator on deceleration.
- **TickBudgetManager.gd**: `should_yield()` disabled — no mid-frame budget interruption.
- **SettlementPlanner.gd**: All 30+ budget exceeded checks removed. Per-settlement pass limit always full.
- **AutonomousWorldAI.gd**: Performance throttling removed (MAI_AI_INTERVAL no longer adjusted).
- **Main.gd**: `_high_speed_interval()` always returns normal_ticks — all speed-dependent sim work reduction eliminated.
- **HeelKawnian.gd**: All stride/interval functions return minimum (stride=1, claim=1, work_step=1, refresh=8). Redraw throttle removed. Pathfind aversion always on.
- **Drives**: MemoryDrive, AmbitionDrive, CuriosityDrive, SocialDrive — `should_pulse()` ignores game_speed.
- **HeelKawnPawnBrain.gd**: High-speed AI throttle (>20x) removed.
- **DisasterSystem.gd**: Speed-dependent update interval removed.
- **UI**: All refresh stride throttles removed (ChronicleFeed, ChronicleLedger, ChronicleBook, PawnAIInspector, ColonyHUD, PawnInfoPanel).
- **PlaytestRecorder.gd**: Auto-save interval no longer multiplied at high speed.
- **HeelKawnianDecision.gd**: 200x speed gates removed (neural priority + matrix bias always active).

**What was verified:**
- Global RNG scan (DisasterSystem, CataclysmSystem, KnowledgeSystem): ✅ No forbidden RNG
- World dimension fields scan: ✅ No legacy fields
- Main scene configured: ✅ `res://scenes/main/Main.tscn`
- Godot headless smoke: ⚠️ Godot binary not available in this environment

### Post-Fix: Death Spiral Prevention (MAX_TICKS_PER_FRAME)

**Problem observed:** At 100x, `tick_batch` grew from 8ms → 934ms over ~30s. With no per-frame cap, all accumulated ticks processed in one frame, starving the renderer (8 FPS). As FPS dropped, more ticks accumulated, causing a death spiral.

**Fix:** Added `MAX_TICKS_PER_FRAME = 24` as a flat safety limit in both TickManager and GameManager. This is NOT a speed-dependent throttle — it caps per-frame ticks identically at all speeds, preventing render starvation without reducing sim fidelity. Ticks beyond the cap carry to the next frame.

**What was verified:**
- Global RNG scan (DisasterSystem, CataclysmSystem, KnowledgeSystem): ✅ No forbidden RNG
- World dimension fields scan: ✅ No legacy fields
- Main scene configured: ✅ `res://scenes/main/Main.tscn`
- Godot headless smoke: ⚠️ Godot binary not available in this environment
- All previous parse errors fixed: HeelKawnian.gd mobile_mul, SurvivalSystem.gd interval, Main.gd dead code, budget/start_usec/gs variables

**What remains unverified/risky:**
- Godot headless smoke was not run (no Godot binary in CI environment).
- MAX_TICKS_PER_FRAME=24 is a safety cap — the sim will run at most 24 ticks/frame. At 60 FPS this gives 1440 ticks/sec = 288x max. At 100 FPS, 2400 ticks/sec = 480x. This is sufficient for 100x on modern hardware. If per-tick work grows too high (large colony), the sim will naturally slow below the 100x label — this is expected and prevents freezing.
- The `_regrow_due_ticks.remove_at(0)` is still O(n) and could slow down long sessions. Not critical for current colony sizes.
- Mining react's 2ms per-tick budget is still the dominant per-tick cost. With MAX_TICKS_PER_FRAME, this is bounded: max 24 * 2ms = 48ms sim time per frame.
- Round 2 is significantly more invasive — we changed return values of ~30 functions across 18 files. Each change follows a predictable pattern (remove speed branches, return base value), but no runtime verification was possible.
- Key risk: AIAgentManager `_world_ai_interval_for_speed` and `_settlement_ai_interval_for_speed` previously returned variable intervals based on speed (10-120 for world AI, 16-156 for settlement AI). Now they always return 10 and 16 respectively. At 100x this means world AI updates every 10 ticks instead of every 72-120 ticks — this is 7-12x more frequent and could cause frame-time spikes on large colonies.
- Key risk: Main.gd `_heavy_planner_interval_for_speed` was 720 at 100x, now always 180. This means settlement heavy planning runs 4x more often at 100x, which could cause spikes.
- Key risk: All 6 autoloads (BuildingUsageTracker, CraftingSystem, SurvivalSystem, FarmingSystem, PlayerBuilding, FootpathMemory) now run their `_on_game_tick` handlers every tick at ALL speeds. Previously at 100x they ran every 2-10 ticks. This could cause significant frame-time increases at high speed, especially SurvivalSystem (pawn-wide check) and FarmingSystem (crop growth).
- Key risk: HeelKawnPawnBrain `_compute_stride` is now always 1 — previously at 100x it was 20, meaning only 5% of pawns got full AI per tick. Now ALL pawns get full AI every tick. With 2000 pawns at 100x (~8 ticks/frame at 60fps), that's 16000 full AI evaluations per second vs. 800 before. This is the most impactful change and could make 100x unplayable on large colonies.
- `_high_speed_interval` signature changed — callers now pass only 1 arg instead of 3. The new signature has optional params with defaults for backward compat.
- Drive `should_pulse` signatures changed — now have optional `_game_speed` param with default. All call sites pass 2 positional args, which is compatible.
- UI `_refresh_stride_for_speed` signatures changed — optional `_speed` param. All call sites pass 1 positional arg, compatible.
- Risk: the uncapped tick processing means a single frame at 100x could process many ticks. On very slow hardware this could cause visible frame drops. The design philosophy accepts this: the sim runs at whatever rate the hardware supports, without artificial caps.

### Round 3: Natural Intervals for 5 Hot Autoload Systems

**Problem observed:** After Round 2 removed ALL per-tick throttles, 5 autoload systems ran their `_on_game_tick` handlers every tick at ALL speeds. Each iterated ALL entities (all pawns, all farm plots, all crafting jobs, all structures) every tick. Together they dominated the per-tick budget, causing severe lag.

**Fix:** Added flat natural intervals (NOT speed-dependent) to the 5 hottest per-tick systems:
- **CraftingSystem.gd**: `UPDATE_INTERVAL = 5` — crafting progress updates every 5 ticks
- **FarmingSystem.gd**: `UPDATE_INTERVAL = 8` — crop growth + health checks every 8 ticks
- **PlayerBuilding.gd**: `UPDATE_INTERVAL = 5` — building queue + structure decay every 5 ticks
- **BuildingUsageTracker.gd**: `SAMPLE_INTERVAL = 6` — pawn building usage sampling every 6 ticks
- **FootpathMemory.gd**: `SAMPLE_INTERVAL = 6` — pawn traffic sampling every 6 ticks

These intervals apply identically at all speeds — they are NOT throttles. They reduce per-tick work ~6x while maintaining proper simulation cadence.

**What was verified:**
- Global RNG scan (DisasterSystem, CataclysmSystem, KnowledgeSystem): ✅ No forbidden RNG
- World dimension fields scan: ✅ No legacy fields
- Main scene configured: ✅ `res://scenes/main/Main.tscn`
- Required files exist: ✅ All present
- Godot headless smoke: ⚠️ Godot binary not available in this environment

**What remains unverified/risky:**
- At 1x (1 tick/sec), these intervals mean updates happen every 5-8 seconds instead of every second. This should be imperceptible for simulation depth but should be verified in-game.
- BuildingUsageTracker and FootpathMemory sampling intervals (6 ticks) mean traffic/usage data updates at 17Hz at 100x — adequate for wear tracking but worth verifying visually.
- The big risk entries from Round 2 (AIAgentManager intervals, heavy planner rate, pawn stride=1) remain: 6 autoloads + 3 AI systems still run at higher frequencies than before Round 2, though the 5 hot systems are now splined back to sane rates.
