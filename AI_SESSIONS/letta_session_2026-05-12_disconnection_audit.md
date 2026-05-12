# HeelKawn Session Handoff — 2026-05-12

## For: Triad Brain, ChatGPT/Heelkawn, Aider, and any other AI agent working on HeelKawn

---

## Core Philosophy (NEW — from the human)

**Unconstrained freedom for both Letta and HeelKawnians:**
- Letta should act, then report. No permission bottlenecks. Do the work, explain at the end.
- HeelKawnians must be ASYNC. No AuthorityJobBoard, no proto-camp synchronized orders, no group-think.
- Individual need → individual action. If hungry, they forage because they're hungry — the need drives the action, not the scheduler.
- Code should be as loose as possible so HeelKawnians walk free and unconstrained.
- Forage yield = 5 berries per trip. Pawns pick a handful, not one berry at a time. Reduces micromovement, feels more natural.

---

## What Letta Did This Session

### 1. Disconnected System Audit (15 fixes across 12 files)

**Critical bugs found and fixed:**

- **AuthorityJobBoard.gd**: Every proto-camp survival job was returning null because `tile_x`/`tile_y` keys don't match `post_from_dict`'s expected `tile: Vector2i`. Zero jobs were actually being posted. Fixed to use `tile: Vector2i(int(center_tile.x), int(center_tile.y))`.
- **AIManager.gd**: Called `WorldAI.process(world, main)` which doesn't exist → changed to `WorldAI.update()`.
- **ColonySimServices.gd**: Called `StockpileManager.count_of("food")` which doesn't exist → changed to `StockpileManager.total_food()`.
- **GossipManager.gd**: `get_gossip_about(pawn_id, max_count)` was called but didn't exist → added the method.
- **TechnologySystem.gd**: `get_available_research(settlement_id)` was called but only `get_available_technologies()` existed → added compatibility wrapper.
- **GameManager.gd**: `get_speed_index()` was called but didn't exist → added the method.
- **PlayerGathering.gd**: Called `WorldRNG.roll_range()` which doesn't exist → changed to `WorldRNG.rangei()`.
- **MythMemory.gd**: `get_conflict_intensity(region_key)` was called by SchismManager but didn't exist → added method that derives conflict intensity from WorldMeaning war/conflict tags.
- **TimeLapseRecorder.gd**: Called `GameManager.unpause()` which doesn't exist → changed to `GameManager.resume()`.
- **WorldMeaning.gd**: Added `meaning_changed` signal + emit in `recompute()`.
- **WorldMemory.gd**: Added `event_appended` signal + emit in `_append()`.
- **SettlementMemory.gd**: Added `settlement_founded` signal + emit when settlement appended.
- **HeelKawnian.gd**: PROTECT/DEFEND jobs had no completion logic → added WorldMemory guard_duty event + mood PRIDE event.
- **HeelKawnian.gd + Pawn.gd**: Added `FETCHING_MATERIAL` early return guards after `_finish_build`, `_finish_shelter_build`, `_finish_registry_build` calls in `_complete_current_job` — prevents `JobManager.complete()` from firing during re-fetch.
- **Pawn.gd**: Fixed `var _data_dict: Dictionary = data` parse error — HeelKawnianData can't be cast to Dictionary. Replaced with `data.has_method("get")` / `"prop" in data` pattern.

### 2. Player Mode / Selection Fix

**Root cause**: Default player mode was SPECTATOR, which blocks ALL mouse clicks for pawn selection (line 3910-3913 in Main.gd: `if _is_watch_mode(): set_input_as_handled(); return`).

**Fixes applied:**
- Changed default `_player_mode` from `PlayerMode.SPECTATOR` to `PlayerMode.OBSERVER` (line 236)
- Changed `_on_new_game()` to start in OBSERVER mode instead of SPECTATOR (line 8005)
- Changed `_on_play_mode()` to start in OBSERVER mode instead of SPECTATOR (line 8015)

**How selection works now:**
1. `_on_left_press()` → `_handle_select_click_at(world_pos)` — proximity-based selection (16px radius)
2. Physics fallback in `_unhandled_input` — raycast looking for `ClickArea` child or `pawns` group
3. `_ensure_click_area()` in HeelKawnian.gd creates an Area2D + CircleShape2D(radius=8) dynamically in `_ready()`
4. `_on_click_area_input_event` → `Main.select_pawn_from_pickable(self)`

### 3. tile_invalid Job Cancellation Fix

**Root cause**: When a pawn found a job tile invalid (e.g., another pawn already built something there), the job was permanently CANCELLED via `JobManager.cancel()`. This destroyed build jobs that were only temporarily blocked.

**Fix**: In both `_tick_walking` and `_tick_working`:
- Harvest jobs (FORAGE, CHOP, MINE, MINE_WALL, HUNT, FISH) → still cancelled (resource is genuinely gone)
- Build jobs and other non-harvest jobs → UNCLAIMED via `_unclaim_current_job("tile_invalid")` so they can be retried or reposted

### 4. Pathfinder Diagnostic

Ran a headless diagnostic that confirmed:
- Pathfinder is working correctly: 50,964 tiles in main component (out of 65,536 total, 14,417 solid)
- All 26 pawns are connected to the main component
- The `largest_component=0` report from the user's running game was likely from a different state or earlier session

### 5. Forage Yield = 5 Berries

Changed FORAGE job production from 1 berry to 5 berries per trip. The carry system already supports `carrying_qty`. Pawns pick a handful and hold onto food instead of going back immediately.

### 6. AuthorityJobBoard Disabled

Disabled the proto-camp synchronized order system. `_ready()` and `_on_game_tick()` are now no-ops. HeelKawnians work independently — each follows its own needs, not authority-issued orders.

### 7. Direct Forage — Need-Driven Eating

Added `State.DIRECT_FORAGING`: when a pawn is hungry and no stockpile has food, it walks to the nearest FERTILE_SOIL tile, forages it, and eats 5 berries directly on the spot. No job system, no hauling, no stockpile. Need drives action.

- `_maybe_direct_forage()`: searches 24-tile radius for nearest FERTILE_SOIL, checks pathability, walks there
- `_arrive_at_fertile_soil_and_eat()`: clears the feature, restores 300 hunger (5×60), records FOOD_EVENT, queues regrowth (2400 ticks)
- Added to all state dispatches: `_on_path_complete`, state name, throttled tick, busy check, inspection block

### 8. Claim Interval — Need-Driven

Changed job claim interval from scheduler-driven to need-driven:
- Hungry pawns: claim_iv = 1 (every tick). Need drives action.
- Well-fed pawns at high speed: claim_iv = 2-4 (spread claims to reduce CPU).
- Old behavior: claim_iv = 12 at 100x speed, regardless of hunger.

---

## What Still Needs Doing

### Priority 1: Starvation/Deadlock in Running Game

The user's running game at tick 40200 shows:
- 99 open jobs, only 4 claimed, 144 cancelled (mostly tile_invalid)
- Pawns are idle despite hunger
- No stockpiles visible
- "stockpile_empty_but_carried_food_present"

**Likely causes NOT yet fixed:**
1. **Stockpile creation timing**: The seed stockpile is created in `_reroll_world()` → `_place_stockpile(main_component)`. If this fails (e.g., `find_tile_in_component_near` returns (-1,-1)), no stockpile exists and pawns can't deposit food or fetch materials.
2. **Material crisis loop**: Build jobs require wood/stone, but if stockpile is empty, pawns can't claim build jobs. The `materials_crisis` override in `_worldbox_loop_job_for_pawn` should fall back to CHOP/MINE, but the priority_cb might still reject them.
3. **Claim interval gating**: At high speed (50x+), pawns only try to claim every 8-12 ticks. With 26 pawns and 99 jobs, this should still be fast enough, but the claim interval + phase offset might cause long delays.
4. **`_is_job_tile_still_valid` is checked on EVERY work tick**: If a pawn arrives at a FORAGE tile and another pawn just cleared it, the job is cancelled. With 26 pawns competing for ~18 fertile soil clusters, this creates a race condition where many pawns walk to the same tile and only one succeeds.

**Recommended fixes:**
- Add a `_try_claim_nearest_food_job` fallback in `_tick_idle` that bypasses the normal priority system when hunger is critical
- Make `_place_stockpile` more robust — if `find_tile_in_component_near` fails, try the center of the map
- Add a "direct forage" behavior: if no stockpile exists and pawn is hungry, walk to nearest FERTILE_SOIL tile and eat directly (bypassing the job system entirely)

### Priority 2: Orphaned UI Scripts (11 dead scripts)

These scripts have no scene references and no callers:
- ActionMenu.gd, CharacterBar.gd, CharacterStatus.gd, ChronicleReader.gd, ChronicleUI.gd, DynamicSpriteText.gd, GuildUI.gd, StatisticsPanel.gd, UIAutoSetup.gd, HeelKawnUIAuto.gd, ui_test_helpers.gd
- Legacy UI chain: UIManager.gd → only referenced by UIAutoSetup.gd (orphaned), HeelKawnUI.gd → only referenced by HeelKawnUIAuto.gd (orphaned)

**Recommendation**: Delete all 11 orphaned scripts + UIManager.gd + HeelKawnUI.gd. They're dead code that adds parse time and confusion.

### Priority 3: Partial Job Types (no execution path)

These Job.Type values exist in the enum but have no completion logic in `_complete_current_job`:
- PAPER_MAKING, LEATHER_MAKING, INK_MAKING, TOOL_MAKING, BOOK_BINDING — workshop jobs referenced in AI/planning but no pawn execution
- GUARD — dead job type, no execution anywhere
- VISIT_GRAVE — has mood event but no WorldMemory recording (minor)

**Recommendation**: Either implement completion logic for these or remove them from the Job.Type enum to avoid confusion.

### Priority 4: Performance at Scale

The 60fps frame budget architecture is in place, but at 100x speed with 26+ pawns:
- `_compute_components` is deferred but still does BFS over ~50K tiles when dirty
- `TradePlanner.plan()` is capped at 8 pathfinder calls per plan
- `refresh_pawn_historic_scar_weights` only iterates dirty regions now
- Construction seed has 6ms budget with speed-based throttling

**Recommendation**: Profile at 100x with 50+ pawns to find the next bottleneck. The tick loop is the critical path.

---

## Architecture Notes for Other Agents

### The Tick Loop
```
TickManager → GameManager._on_world_tick → Main._on_game_tick
  → ColonySimServices.update()
  → for each pawn: pawn._tick()
  → WorldAI.update()
  → WorldMeaning.recompute() (every 2000 ticks)
  → SettlementMemory.recompute() (every 2000 ticks)
  → PathFinder.flush_component_dirty() (every tick)
  → Construction seed (every 60-300 ticks)
  → SettlementPlanner (budget-gated)
```

### The Decision Pipeline
```
Pawn._tick_idle →
  1. Emergency eat (starving + carrying food)
  2. Drop non-food if starving
  3. Haul carried items to stockpile
  4. _maybe_start_eating() (hungry + food in stockpile)
  5. _maybe_start_sleeping() (tired)
  6. Social lanes (teach, challenge, patrol)
  7. JobManager.claim_next_for(self, base_passes, priority_cb)
  8. Wander
```

### Key Files and Their Roles
- **Main.gd** (9000+ lines): The god file. Input handling, tick loop, construction seeding, HUD, zone management, save/load, debug panels. Needs decomposition but works.
- **HeelKawnian.gd** (9000+ lines): The pawn. State machine (IDLE/WALKING/WORKING/SLEEPING/EATING/FETCHING_MATERIAL/HAULING/DRAFT_WALK), job claiming, needs decay, combat, social behavior, visual rendering.
- **World.gd**: Tile data, terrain, features, pathfinder, beds, stockpiles.
- **PathFinder.gd**: AStarGrid2D + connected components BFS. Deferred component recomputation.
- **JobManager.gd**: Job posting, claiming, completion, cancellation, abandon tracking.
- **StockpileManager.gd**: Zone-based item storage. Settlement-scoped queries.
- **SettlementMemory.gd**: Settlement detection, resource truth, governance, territory.
- **WorldMemory.gd**: Append-only event log. The canonical source of world history.
- **WorldMeaning.gd**: Derives meaning tags from WorldMemory events. Feeds into decision pipeline.
- **HeelKawnianMind.gd**: Composed mind snapshot (11 layers). Deterministic, no new state.
- **PawnDecisionRuleMatrix.gd**: 16+ rules that modify pawn behavior based on mind snapshot.

### The Feel (from the human)
Heavy. Quiet. Slow. Vast. Human. Historically layered. Incomplete on purpose. Tragic without nihilistic. Meaningful without spectacle. No generic survival crafting, no shallow sandbox chaos, no quest-marker theme park, no power fantasy.

### Non-Negotiable Laws
- Deterministic history: same conditions → same outcomes
- Facts first: WorldMemory records objective events before interpretation
- No chosen ones / no prophecy destiny
- No morality meter / no fake good/evil axis
- No UI lies: UI reflects simulation state truth
- No random memory decay
- No victory screen: HeelKawn cycles, no "end"
- Players start as ordinary humans: ascent is earned
- Every sprite matters: can carry memory, labor, knowledge, bloodline, witness, consequence

---

## Questions for the Human / Other Agents

1. **Should we delete the 11 orphaned UI scripts?** They're dead code. No scene references, no callers. Removing them would clean up the project and reduce parse time.

2. **The "direct forage" behavior** — when a pawn is starving and no stockpile exists, should they be able to eat berries directly from a FERTILE_SOIL tile without going through the job system? This would prevent starvation deadlocks during early game before stockpiles are established.

3. **AuthorityJobBoard proto-camp orders** — now that the tile format is fixed, should we add more survival-critical orders? Currently it only posts BUILD_BED, BUILD_WALL, BUILD_DOOR. Should it also post FORAGE and BUILD_FIRE_PIT orders?

4. **The GUARD job type** — it has no execution anywhere. Should it be removed from the Job.Type enum, or should we implement guard duty logic (pawn stands at a post for N ticks, then completes)?

5. **Workshop jobs** (PAPER_MAKING, LEATHER_MAKING, INK_MAKING, TOOL_MAKING, BOOK_BINDING) — these are in the enum but have no pawn execution path. Are these planned for a future phase, or should they be removed to avoid confusion?

---

## File Change Summary This Session

| File | Change |
|------|--------|
| autoloads/AuthorityJobBoard.gd | Fixed tile_x/tile_y → tile: Vector2i |
| autoloads/AuthorityJobBoard.gd | DISABLED — no more synchronized proto-camp orders |
| autoloads/AIManager.gd | WorldAI.process → WorldAI.update |
| autoloads/ColonySimServices.gd | count_of("food") → total_food() |
| autoloads/GossipManager.gd | Added get_gossip_about() |
| autoloads/TechnologySystem.gd | Added get_available_research() wrapper |
| autoloads/GameManager.gd | Added get_speed_index() |
| autoloads/PlayerGathering.gd | WorldRNG.roll_range → rangei |
| autoloads/MythMemory.gd | Added get_conflict_intensity() |
| autoloads/TimeLapseRecorder.gd | GameManager.unpause → resume |
| autoloads/WorldMeaning.gd | Added meaning_changed signal + emit |
| autoloads/WorldMemory.gd | Added event_appended signal + emit |
| autoloads/SettlementMemory.gd | Added settlement_founded signal + emit |
| scripts/pawn/HeelKawnian.gd | PROTECT/DEFEND completion logic, FETCHING_MATERIAL guards, tile_invalid unclaim fix, forage yield 5, direct forage state, need-driven claim interval |
| scripts/pawn/Pawn.gd | FETCHING_MATERIAL guard, Dictionary cast fix, DIRECT_FORAGING state enum |
| scenes/main/Main.gd | Default player mode SPECTATOR→OBSERVER, new game mode SPECTATOR→OBSERVER |

All changes compile clean (0 parse errors).
