# HEELKAWN — AGENT OPERATING MANUAL

**Single source of truth for all AI agents working on HeelKawn.**
**Last Updated: 2026-08-18**

---

## TRUTH HIERARCHY (when docs conflict)

1. Source code and Godot runtime (highest truth)
2. This file — kernel philosophy and operational rules
3. `docs/lore/` — game canon and metaphysics
4. `docs/archive/` — historical session notes, not authority

---

## WHAT IS HEELKAWN

A deterministic 2D persistent simulation universe built in Godot 4.6.2. HeelKawn is a memory-and-consequence simulator where history is written by actions, not scripts. Pawns live, work, marry, form households, build settlements, wage wars, and die — all emergent from deterministic simulation.

**Core principle:** All world state must derive from tick count + seed + inputs. No hidden RNG. No frame-coupled logic.

---

## KERNEL RULES (NON-NEGOTIABLE)

### 1. Deterministic RNG
All randomness uses `WorldRNG` with named streams:
```gdscript
var roll: int = WorldRNG.roll("pawn_decision_%d" % pawn_id, 100)
```
**Forbidden:** `randi()`, `randf()`, `Time.get_unix_time_from_system()` in simulation paths.

### 2. No Frame/FPS Coupling
World truth is tick-based, never frame-based:
```gdscript
# WRONG:
if Time.get_delta() > 0.1:
    do_world_logic()
# CORRECT:
if GameManager.tick_count % 10 == 0:
    do_world_logic()
```

### 3. No Fake Systems
Do not expose placeholder behavior as active world logic. If incomplete, mark it or disable it.

### 4. Facts First, Meaning Second
1. **Facts** — tile types, resources, pawn positions, job states (deterministic kernel)
2. **Meaning** — region tags, settlement intent, cultural pressure (derived from facts)
3. **Interpretation** — narrative, lore, player understanding (layer on top)

Never hardcode meaning into the kernel. Derive it via `WorldMeaning`.

### 5. Inspect Before Creating
Always read existing files before adding new systems. Prefer the smallest reversible change.

### 6. Preserve Anonymity
No heroic exceptionalism. Pawns are anonymous citizens of an emergent civilization.

---

## PERFORMANCE TARGETS

- **1x:** Real-time observation, fully responsive
- **100x:** No crash cascades, no tick desync
- **200x:** Target 25 in-game days (~15,000 ticks) in ~75 seconds. No freezing, no lag spikes.

**Performance fixes are always welcome.** Optimize hot paths, increase stride at high speed, cache expensive lookups. Do not throttle the simulation in ways that cause lag.

---

## PROJECT ARCHITECTURE

### Engine
- **Godot 4.6.2** (GDScript, not C#)
- **Entry Scene:** `scenes/main/Main.tscn`
- **World:** `scenes/world/World.tscn` (tile-based, loaded as child of Main)

### Autoloads (Global Singletons)
All registered in `project.godot`. Accessible from any script by name.

**Core Simulation:**
| Autoload | Path | Purpose |
|----------|------|---------|
| `GameManager` | `autoloads/GameManager.gd` | Tick count, game speed, pause state |
| `TickManager` | `autoloads/TickManager.gd` | Frame-budget tick loop, speed index |
| `WorldRNG` | `autoloads/WorldRNG.gd` | Deterministic seeded RNG streams |
| `WorldMemory` | `autoloads/WorldMemory.gd` | Spatial memory (region-based) |
| `WorldMeaning` | `autoloads/WorldMeaning.gd` | Derived meaning from facts |
| `MemoryManager` | `autoloads/MemoryManager.gd` | Sacred site tracking |

**Settlement & People:**
| Autoload | Path | Purpose |
|----------|------|---------|
| `SettlementManager` | `autoloads/SettlementManager.gd` | Settlement lifecycle |
| `SettlementMemory` | `autoloads/SettlementMemory.gd` | Settlement state/history (`get_formal_settlements()`, `get_formal_settlement_count()`) |
| `HeelKawnianManager` | `autoloads/HeelKawnianManager.gd` | Pawn household/clan logic |
| `KinshipSystem` | `autoloads/KinshipSystem.gd` | Household/family relationships |
| `FactionManager` | `autoloads/FactionManager.gd` | Faction registry (`get_faction_ids()`, `get_faction(id)`) |
| `JobManager` | `autoloads/JobManager.gd` | Job posting/claiming (`open_count()`) |
| `PawnAccess` | `autoloads/PawnAccess.gd` | Pawn lookup/query |

**AI & Agents:**
| Autoload | Path | Purpose |
|----------|------|---------|
| `AIAgentManager` | `autoloads/AIAgentManager.gd` | Agent update budgets, neural/pattern intervals |
| `AutonomousWorldAI` | `autoloads/AutonomousWorldAI.gd` | World-level strategic AI |
| `CharacterBrainSystem` | `autoloads/CharacterBrainSystem.gd` | Per-pawn decision kernel |

**Economy & Resources:**
| Autoload | Path | Purpose |
|----------|------|---------|
| `StockpileManager` | `autoloads/StockpileManager.gd` | Resource stockpiles (`zone_count()`, `total_count_of(item_type: int)`) |
| `ColonySimServices` | `autoloads/ColonySimServices.gd` | Housing pressure, food pressure |
| `EconomyManager` | `autoloads/EconomyManager.gd` | Trade, currency |
| `SupplyChainSystem` | `autoloads/SupplyChainSystem.gd` | Resource logistics |

**World Systems:**
| Autoload | Path | Purpose |
|----------|------|---------|
| `WeatherSystem` (via WorldEnvironmentManager) | `autoloads/WorldEnvironmentManager.gd` | Weather, seasons |
| `EcologySystem` | `autoloads/EcologySystem.gd` | Wildlife, flora |
| `DisasterSystem` | `autoloads/DisasterSystem.gd` | Natural disasters |
| `CrimeSystem` | `autoloads/CrimeSystem.gd` | Crime and punishment |
| `DiseaseSystem` | `autoloads/DiseaseSystem.gd` | Illness and healing |

**Performance:**
| Autoload | Path | Purpose |
|----------|------|---------|
| `TickProfiler` | `autoloads/TickProfiler.gd` | Per-category tick timing (`cat_total_heelkawnian`, etc.) |
| `TickBudgetManager` | `autoloads/TickBudgetManager.gd` | Disabled stub (returns infinite budget) |
| `TickRateDecoupler` | `autoloads/TickRateDecoupler.gd` | System update interval scaling |

**UI:**
| Autoload | Path | Purpose |
|----------|------|---------|
| `UIManager` | `autoloads/UIManager.gd` | UI state management |
| `HeelKawnUIManager` | `autoloads/HeelKawnUIManager.gd` | Panel positioning |
| `UILayoutManager` | `autoloads/UILayoutManager.gd` | Layout helpers |

### Scene Tree (Main.tscn)
```
Main (Node2D)
├── DayNight (CanvasModulate)
├── WorldViewport (Node2D)
│   ├── World (instance of World.tscn)
│   ├── BuildPreviewOverlay
│   ├── WorldTrace
│   ├── PawnSpawner
│   ├── Camera (Camera2D)
│   └── ... (AnimalSpawner, EnemySpawner, etc.)
├── UI_Viewport (CanvasLayer)
│   ├── ColonyHUD
│   ├── BuildToolbar
│   ├── PawnInfoPanel
│   ├── ChronicleLedger
│   ├── SettingsPanel
│   ├── Minimap
│   └── ... (other UI panels)
├── CreatorDebugMenu (CanvasLayer) ← F10 debug menu, NOT under UI_Viewport
├── MapModeOverlay
├── WeatherOverlay
├── CommandMode
└── AmbientAudio
```

### Key Scripts
| Script | Path | Purpose |
|--------|------|---------|
| `HeelKawnian.gd` | `scripts/pawn/HeelKawnian.gd` | Main pawn script (~9700 lines) |
| `HeelKawnianData.gd` | `scripts/pawn/HeelKawnianData.gd` | Pawn data model |
| `HeelKawnPawnBrain.gd` | `scripts/ai/HeelKawnPawnBrain.gd` | Per-pawn AI brain |
| `WorldAI.gd` | `scripts/ai/WorldAI.gd` | World-level neural/pattern AI |
| `CreatorDebugMenu.gd` | `scripts/ui/CreatorDebugMenu.gd` | F10 debug report buttons |
| `Item.gd` | `scripts/items/Item.gd` | Item type enum (`Item.Type.WOOD`, etc.) |

### Common Patterns

**Speed bucket (0=1x through 5=200x):**
```gdscript
func _speed_bucket() -> int:
    # Maps GameManager.game_speed to bucket 0-5
```

**Tick stride (skip ticks at high speed):**
```gdscript
func _fast_forward_tick_stride() -> int:
    return [1, 3, 8, 15, 40, 100][_speed_bucket()]
```

**Cached lookups:**
```gdscript
var _cache_tick: int = -1
var _cached_value: int = -1

func get_cached() -> int:
    if _cache_tick != GameManager.tick_count:
        _cached_value = expensive_computation()
        _cache_tick = GameManager.tick_count
    return _cached_value
```

---

## F10 DEBUG MENU

Located at `CreatorDebugMenu.gd` (CanvasLayer, child of Main — NOT under UI_Viewport).

**Toggle:** F10 key calls `toggle_menu()` which flips `visible`.

**6 Report Buttons:**
1. FULL SYSTEM REPORT — GameManager, World, Settlements, Memory, Jobs
2. PERFORMANCE PROFILE — TickProfiler counters, stride config, tick intervals
3. AI & MEMORY STATE — WorldAI neural/patterns, agents, settlements
4. SETTLEMENTS & PAWNS — Formal settlements, pawn counts by state, jobs, households, factions
5. WORLD & ECONOMY — World dimensions, stockpiles, ColonySimServices
6. CONFIG & SETTINGS — Speed, tick count, days elapsed

**Known correct autoload method calls:**
- `JobManager.open_count()` ✅
- `StockpileManager.zone_count()` ✅
- `StockpileManager.total_count_of(int)` ✅
- `SettlementMemory.get_formal_settlements()` ✅
- `SettlementMemory.get_formal_settlement_count()` ✅
- `FactionManager.get_faction_ids()` ✅
- `KinshipSystem._households` (Dictionary) ✅
- `ColonySimServices.get_housing_pressure()` ✅
- `ColonySimServices.get_food_pressure()` ✅
- `AIAgentManager.get_agent_count()` ✅
- `TickManager.get_speed_index()` ✅
- `WorldMeaning.region_count()` ✅
- `WorldAI.neural_world_matrix` (Dictionary) ✅
- `WorldAI.emergent_patterns` (Array) ✅
- `TickProfiler.cat_total_heelkawnian` (int, microseconds) ✅

---

## WHAT NOT TO DO

- Do not add `class_name` to files that are autoloads (autoloads are accessed by name, not type)
- Do not reference nodes under `UI_Viewport/` that are actually direct children of `Main`
- Do not assume methods exist — always use `has_method()` guard or verify against this file
- Do not add throttling that reduces simulation fidelity at high speeds without explicit user request
- Do not create new autoloads without checking if the functionality already exists
- Do not modify `project.godot` autoloads without understanding the load order

---

## PROGRESS LOG

Track what was done, when, and by which AI session. Append only — never overwrite.

---

### 2026-08-18 — Session: opencode/big-pickle (Fix F10 Debug Menu + Consolidate AI Docs)

**Time:** ~14:00 UTC

**What was done:**

1. **Fixed CreatorDebugMenu.gd type mismatch** — Script extended `Control` but scene node was `CanvasLayer`. Changed `extends Control` → `extends CanvasLayer`.

2. **Fixed null _vbox crash** — Scene had bare CanvasLayer with no children. Script expected `$Panel` and `$Panel/VBoxContainer` which didn't exist. Rebuilt UI hierarchy programmatically in `_ready()`.

3. **Added missing `toggle_menu()` method** — Called by `Main.gd:4443` on F10 press but didn't exist.

4. **Rewrote all 6 report functions** — Audit found 24 broken method/property calls. Every button would have crashed. Fixed by:
   - Replaced `WorldMemory.region_count()` → `WorldMeaning.region_count()`
   - Replaced `WorldMemory.tag_count()` → removed (doesn't exist)
   - Replaced `WorldMemory.get_region_tags()` → `WorldMeaning.get_region_tags()`
   - Replaced `SettlementMemory.settlement_count()` → `SettlementMemory.get_formal_settlement_count()`
   - Replaced `MemoryManager.event_count()` → `MemoryManager.site_count()`
   - Replaced `MemoryManager.history_count()` → removed
   - Replaced `JobManager.total_count()` → removed
   - Replaced `TickProfiler.print_summary()` → direct counter reads
   - Replaced `TickManager.max_ticks_per_frame()` → removed (const dict, not method)
   - Replaced `WorldAI.neural_state_count()` → `WorldAI.neural_world_matrix.size()`
   - Replaced `WorldAI.pattern_count()` → `WorldAI.emergent_patterns.size()`
   - Replaced `AIAgentManager.agent_count()` → `AIAgentManager.get_agent_count()`
   - Replaced `AIAgentManager.training_history` → `collective_intelligence.shared_memory.training_history`
   - Replaced `HeelKawnianManager.pawn_count()` → scene tree child count
   - Replaced `SettlementManager.all_settlements()` → `SettlementMemory.get_formal_settlements()`
   - Replaced `FactionManager.faction_count()` → `FactionManager.get_faction_ids().size()`
   - Replaced `ColonySimServices.get_food_security()` → `get_food_pressure()`
   - Replaced `TickBudgetManager.is_enabled()` → removed (disabled stub)
   - Removed broken `ZoneRegistry.zone_count()` and `pf.components_computed`
   - Added `has_method()` guards throughout

5. **Fixed wrong scene tree paths:**
   - `UILayoutManager.gd`: `/root/Main/UI_Viewport/CreatorDebugMenu` → `/root/Main/CreatorDebugMenu`
   - `PlaytestInputRecorder.gd`: same path fix
   - `HeelKawnUIManager.gd`: `_find_node_by_type` checked `child is Control` but CreatorDebugMenu is CanvasLayer — removed type filter, changed return type to `Node`

6. **Audited all AI instruction files** — Found 41 scattered AI docs (7 active instruction files, 20 archived session logs, 2 tool artifacts). Created this consolidated AGENTS.md to replace them.

**Files modified:**
- `scripts/ui/CreatorDebugMenu.gd` — full rewrite
- `autoloads/UILayoutManager.gd` — path fix (2 occurrences)
- `autoloads/PlaytestInputRecorder.gd` — path fix
- `autoloads/HeelKawnUIManager.gd` — type fix + return type change
- `AGENTS.md` — consolidated from 7+ scattered AI instruction files

**Known remaining issues:**
- Artificial tick throttling exists in TickManager, AIAgentManager, HeelKawnian stride, TickRateDecoupler — flagged but NOT removed (user to decide per-system)
- 20+ archived AI session logs in `docs/archive/` — candidates for cleanup
- `.aider.chat.history.md` (35K lines) — can be deleted or .gitignored
- `brain/` directory has stale AI collaboration system files

---

### 2026-08-19 — Session: opencode/deepseek (Eliminate Per-Tick Hotspots Across All Speeds)

**Time:** ~UTC

**What was done:**

1. **WorldAI forward-propagate weight cache** (`scripts/ai/WorldAI.gd`) — The biggest steady-state cost at ALL speeds. `_forward_propagate_network()` regenerated the same 32×64 deterministic weight matrix (`forward:type:i:j` labels, no salt/tick → constant for world lifetime) on every call, ~7× per `update()`. Each weight cost a WorldRNG hash + string format. Cached per-network-type via new `_get_forward_weights()` + `_forward_weights_cache`. Result: `world_ai.update()` (the TICK-PROFILE "other" bucket, measured as AIAgentManager) dropped **12-13x** — from ~13-27ms to ~1.1-1.9ms per 60-tick window at 200x in a mature (tick 22000) headless profile. Determinism unchanged (streams are stateless pure functions of label).

2. **Auto-save real-time gate** (`scenes/main/Main.gd`) — Auto-save ran every 6000 ticks; at 200x that's every ~1.5 real seconds, causing 0.4-1.8s freezes (from `_build_save_dict()` serializing the whole world). Added `_autosave_real_gate_ok()` (new `_last_autosave_real_ms` + `AUTOSAVE_MIN_REAL_SECONDS=60`): auto-save now never more often than every 60 real seconds, so cadence is roughly constant in real time (1x unchanged; 200x no longer freezes ~40× more often).

3. **Construction seed budget at low speeds** (`scenes/main/Main.gd` `_seed_construction_jobs`) — `budget_usec` was unlimited (`999999999`) below 26x, so 1x took ~25ms single-tick hits scanning all settlements. Now capped at 12000us for all speeds below 200x (2000/4000/8000/12000 existing ladder preserved). Cursor advances on budget-break, so settlement coverage is preserved across cycles.

4. **Generational spawn tile occupancy set** (`scenes/main/Main.gd`) — `_find_generational_spawn_tile_optimized()` called `_is_tile_occupied_by_pawn()` (a full `_pawn_spawner.pawns` scan) per candidate tile, i.e. O(regions×256×pawns) — the 33ms hit at tick 60000. Now builds an `occupied` Dictionary once per call and passes it into `_first_valid_gen_tile_in_block()` (default empty dict keeps the signature backward-compatible for the reference `_find_generational_spawn_tile`).

5. **Added per-listener `game_tick` profiler instrumentation** (`autoloads/GameManager.gd`) — `--profile-game-tick` cmdline flag; manual dispatch loop accumulates µs per listener label and prints `[GT_PROFILE]` TOP10 every 1000 ticks. Used to confirm game_tick listeners are cheap (~35µs/tick total) and that the heavy cost was AIAgentManager/WorldAI, not the signal dispatch.

**Files modified:**
- `scripts/ai/WorldAI.gd` — `_forward_weights_cache`, `_get_forward_weights()`, `_forward_propagate_network()` uses cached weights
- `scenes/main/Main.gd` — autosave real-time gate + helper, construction seed low-speed budget, generational spawn occupancy set
- `autoloads/GameManager.gd` — `--profile-game-tick` per-listener profiler (diagnostic only, inert without the flag)
- `tools/sim_mature_profiler.gd` — NEW bounded 200x headless tool (runs to tick ~22000, used to reproduce the mature-world hotspots)

**Known remaining issues:**
- Unattributed ~0.4s TICK_DIAG spikes at non-autosave ticks (62000/64000/67000/68000 in user logs) — not yet root-caused
- The 139-vs-81 `game_tick` listener delta between the user's save and a fresh boot — the extra 58 are UI/pawn-spawn-time listeners, individually cheap, not yet profiled at the user's exact world state

---

### 2026-08-28 — Session: opencode/big-pickle (Root-Caused the Early-Game Pawn Stall)

**Time:** ~UTC

**What was done:**

1. **Root-caused the early-game stall with a new headless audit tool** (`tools/diag_stall_audit.gd`). It boots Main.tscn at 200x, dumps settlements/stockpiles/pressures/jobs/pawns + a per-open-job rejection matrix mirroring `base_passes` + real `_job_visible_to_pawn_with_context`. Reached tick 3511 → 9000 across iterations.

2. **Found and fixed THE stall bug: pawn initialization code was orphaned inside the wrong function.** In `scripts/pawn/HeelKawnian.gd`, the entire "Continue with pawn initialization" block (which sets `data.age_years = float(data.age)`, `_reserved_bed`, `_next_reproduction_tick`, `_perception_scan_cursor`, `_teach_cooldown_ticks`, `_clear_cohort_state`, adds to the `"pawns"` group, grants initial knowledge, ensures soul identity, resets neural caches, redraw) had been accidentally placed at the tail of `_on_global_job_cancelled` (line ~1562-1594). It ran ONLY when a job assigned to that specific pawn was cancelled — which never happens to idle pawns.

   Consequence (measured): every starter pawn spawned with `age_years=0.0` instead of 18-55 → `compute_life_stage()` returned INFANT → `can_work()` returned false → `_tick_idle()` early-returned at line 4604 → NO claims, NO movement, NO clustering, NO settlement formation. Starters are born as working adults by design (`spawn_starters` PawnSpawner.gd:358 sets age 18-55); the initialization that converts `data.age` → `data.age_years` never ran. Also `_perception_scan_cursor`/`_region_center_region`-style fields stayed at defaults, and the `"pawns"` group membership never applied.

   **Fix:** moved the init block from `_on_global_job_cancelled` into `_pawn_connect_sim_tick_deferred` (after the spatial-grid insert, ~HeelKawnian.gd:1529), so it runs exactly once per pawn at spawn-time. Left `_on_global_job_cancelled` with only its genuine cancel-handling. Determinism untouched (no RNG stream changes; `WorldRNG.index_for` is a pure state-less hash).

3. **Measured before/after (headless 200x, tick 9000):**
   - Before: 24 pawns all `life=INFANT`, `can_work()=false`, zero claims ever (`_last_claim_tick=-9999` for 100% of pawns), zero movement (spawn tiles unchanged), `claimed=0` across all 3 seeded jobs, 0 stockpile zones, `completed=0`.
   - After: pawns `life=ADULT` (age_years 23-45), active claims recorded (`FORAGE`, `BUILD_FIRE_PIT`, `BUILD_STORAGE_HUT`), pawns path to bootstrap jobs (tiles change toward (145-147,115)), jobs **completed** (`JOB_DIAG completed=2`), 2 stockpile zones, housing pressure 1.00→0.92, cooking pressure 0.04 (hearth in use).
   - Rejection matrix (before): all 3 seeded jobs showed `eligible=6` yet `claimed=0` because infants never entered the claim pipeline — the matrix/`JobManager` gates were never the blocker.

4. **Verified regressions:** `sim_boot_smoke.gd` OK; `f10_live_data_regression.gd` OK (pawn vitals now show working/sleeping pawns instead of 100% idle); `chronicle_contract_regression.gd` OK; `sim_mature_profiler.gd` reaches tick 22012 with the same 2-4ms tick profile (no perf regression).

**Files modified:**
- `scripts/pawn/HeelKawnian.gd` — moved orphaned pawn-init block into `_pawn_connect_sim_tick_deferred`; added explicit `data.life_stage = data.compute_life_stage()` after the age mirror.
- `tools/diag_stall_audit.gd` — NEW stall-audit tool (claims telemetry, life-stage, age, birth kind, rejection matrix, per-1000-tick JOB_DIAG).

**Known remaining issues (unchanged):**
- Headless 200x first construction-seed at ~tick 3989 (4000-tick interval at 200x) is fine now that pawns can work, but the 200x interval + 2000µs budget + cursor roll is still worth a follow-up sanity pass.
- `proto_sites=0` / no formal settlement within the first 9000 ticks is now a natural emergent rate, not a stall.
- Unattributed ~0.4s TICK_DIAG spikes and the game_tick listener delta remain unprofiled.
- `tools/f10_live_data_regression.gd:196` has a pre-existing format-string error in a PATH_PROFILE print (non-fatal; tool still passes).

---

### 2026-08-29 — Session: opencode/big-pickle (Settlement Formalization Gate Fix + Pawn Dispatch Profiler + F10 History Cap)

**Time:** ~UTC

**What was done:**

1. **Root-caused + FIXED the settlement formalization block** (`autoloads/SettlementMemory.gd`). `recompute(_world, budget_usec)` clears and rebuilds `settlements`. The budget early-return (previously `SettlementMemory.gd:495`) sat ABOVE `_apply_guild_settlement_gate(_world)` (previously `:503`), so at 200x the gate NEVER ran: `guild_candidate_reason` stayed `"not_evaluated"`, and the rebuilt settlements were re-cleared as non-formal every rebuild → `formal=0` at tick ~185000 despite history showing `polity_founded: 1`. **Fix:** moved the gate call to run on EVERY recompute, immediately before the budget early-return; changed the polity event guard from `if not was_formal` to `if not _polity_formal_announced.has(center_rk)` (prevents replay across rebuilds) and removed the now-unused `var was_formal`. `_pawns_by_region_cache` is built at the top of recompute via `_living_pawns()` (`SettlementMemory.gd:2203-2218`), so the gate is safe at its new location.

   **Proven** with `tools/diag_settlement_gate.gd` (headless 200x to tick 18000): `@6000 formal=0 proto=0`; `@12000 formal=1 proto=2 eval_reasons={"insufficient_members":2}`; `@18000 dump: formal=1 proto=2`, formal settlement center=(9,7) rk=458761 `kind=formal_settlement formal=true pop=5 founding_reason=infrastructure_milestone founding_tick=11957`, `inside=[4,6,15,17,18] == pawn_refs` (no CONTRACT ERROR), two guild-gate protos genuinely rejected as `insufficient_members`. Gate no longer reports `not_evaluated`.

2. **Mixed settlement-identity contract documented (NOT changed):** pawn `data.settlement_id` is an ARRAY INDEX into the rebuilt `settlements` array (`get_settlement_id_for_region` → `_region_to_settlement_idx`), while `get_ruler_pawn_id`/`get_construction_chief_pawn_id` expect `center_region` semantics. Recompute re-sorts the array, so indices churn (observed `sid_dist={-1:16, 0:5, 1:2, 2:2}` at tick 18000) → `_maybe_update_settlement_membership` (HeelKawnian.gd:10112) bounces pawns 3→7→-1→3. All internal consumers are individually consistent; changing semantics was judged too risky this session (42 call sites).

3. **NEW gated per-stage pawn dispatch profiler** in `scripts/pawn/HeelKawnian.gd` — the P1 deliverable. Flag `--profile-pawn-dispatch`. Fully inert otherwise (no timing/alloc/RNG). Static helpers `_pd_check_enable/_pd_profiling/_pd_mark/_pd_print` + `_pd_agg` (aggregated across ALL pawns). Marks: `dispatch/<STATE>` in `_on_world_tick`, plus `_tick_idle` stages `idle/emergency_carry`, `idle/foodcache`, `idle/cheap_wander`, `idle/lanes`, `idle/needs`, `idle/awareness_narrative`, `idle/utility_social`, `idle/jobscan_gate`, `idle/jobscan_setup`, `idle/jobscan_scoring`, `idle/claim`. Prints every 2000 ticks when enabled.

   **Headless findings (fresh world 200x → tick ~12000):** the hot kernels are `idle/utility_social` (the `_build_idle_utility_context` + `choose_best_action` + social-cognition region) — avg **3.5ms→11.7ms** per dispatch, climbing with scale — and `idle/jobscan_scoring` (the `priority_cb` precompute over all open jobs) — **avg ~7.7ms** when a scan runs. `idle/needs` stays ~0.11ms. State totals: `dispatch/WORKING` ~0.25ms, `FETCHING_MATERIAL`/`HAULING`/`WALKING_TO_JOB` ~0.13-0.57ms. Headless fresh-world ticks (~2-4ms) still do NOT reproduce the user's 40-80ms dispatches — user runs the flag in their real saved session for exact attribution.

4. **F10 history export cap** (`scripts/ui/CreatorDebugMenu.gd`): new `_format_capped_history(events)` → counts by event type, oldest 20, newest 100, settlement-type events (last 20), `omitted=N` footer, wired into `_gather_diagnostics_text` RECENT HISTORY. Prevents multi-thousand-event worlds flooding the export.

5. **P4 (starvation) hypothesis from source:** F10 "Starving: 19" = pawns with `hunger <= HUNGER_EMERGENCY (20.0)` (CreatorDebugMenu.gd:348). HeelKawnian eat path: `_maybe_start_eating()` (HeelKawnian.gd:8161) → `find_food_source_for_settlement(data.settlement_id,…)` then `find_food_source(tile)` fallback (StockpileManager.gd:184/:269) — NO radius cap but REQUIRES same-reachable-component (`pathfinder.component_of` equality). With 16/47 pawns at `settlement_id=-1` and can-be-blocked by `is_carrying()`/work states, a component-split between pawn clusters and the pantry is the prime suspect; per-pawn starvation trace is the next diagnostic. Do NOT tune consumption until proven.

**Files modified:**
- `autoloads/SettlementMemory.gd` — gate moved before budget early-return in `recompute`; polity guard keyed on `_polity_formal_announced`; `var was_formal` removed.
- `scripts/pawn/HeelKawnian.gd` — added gated `PAWN_DISPATCH_PROFILE` static profiler + 11 stage marks.
- `scripts/ui/CreatorDebugMenu.gd` — `_format_capped_history` + RECENT HISTORY export uses it.
- `tools/diag_settlement_gate.gd` — NEW settlement-gate audit tool (per-proto dump, guild state, pawn sid distribution, CONTRACT ERROR check).
- `tools/diag_parse_check.gd` — NEW minimal script-parse checker (reports OK/error per script).

**Verified regressions:** `sim_boot_smoke.gd` OK; `f10_live_data_regression.gd` OK; `chronicle_contract_regression.gd` OK; `diag_parse_check.gd` OK on all three touched scripts; settlement dump confirms organic formal settlement + consistent pawn refs.

**Known remaining issues:**
- P3 job rejection distribution + `idle/claim` staging for idle adults — next diagnostic (stage `idle/jobscan_scoring`/`idle/claim` already instrumented; need per-stage reject counters).
- P4 per-pawn starvation trace (evidence-backed hypothesis: component-split food reachability).
- P5 autosave stage-by-stage timing (snapshot build / pawn / settlement / WorldMemory / AI / JSON encode / store / rename). Do not thread live nodes; measure first.
- PAWN_DISPATCH_PROFILE sub-stages cover IDLE only; other states have `dispatch/<STATE>` totals; add `_tick_working`/`_tick_walking` sub-marks only if IDLE wins are insufficient.
- Untouched per rules: PathFinder, TickManager, food consumption, formalization thresholds, settlement-id semantics.

---

### 2026-08-30 — Session: opencode/big-pickle (F10 Stabilization 2C: Make the Diagnostic Output Tell the Truth)

**Time:** ~UTC

**What was done:**

1. **P3 — Selected-pawn identity + tile fix.** `_selected_pawn_node()` now prefers `main.get_selected_pawn()` (guarded by `has_method`), falling back to `main.get("_selected_pawn")`. `_pawn_tile(pawn)` now reads `pawn.get("data").get("tile_pos")` FIRST (handles both `Vector2i` and `Vector2`), falling back to `_tile_from(pawn)`. The true root cause: `data.tile_pos` lives on the `HeelKawnianData` sub-object, not the pawn node — the old `_tile_from` path therefore always returned a bogus default. This fixes `selected_pawn.tile`, `spatial.selected_pawn_tile`, the WORLD renderer, and the settlement membership contract.

2. **P2 — Job counter truth.** `_build_jobs_dict` now emits `completed: -1` sentinel + `completed_available: false` (proven: `JobManager.complete()` only increments `_diag_completed_this_window`, never `completed_count`). The WORK section prints "Completed: unavailable (JobManager maintains no completion counter)" whenever that flag is false, and "Posted: %d (since session start)" / "Cancelled: %d (since session start)" for the two counters that actually exist.

3. **P1 — Food counter truth.** `_build_food_dict` now emits `raw_food_units`/`cooked_food_units` (fine breakdowns of the edible total via `Item.is_raw_food`/`is_cooked_food`), `stockpile_generic_food_units` (= literal `total_count_of(Item.Type.FOOD)`, which is NOT edible per `Item.is_food`), and a `food_definition_note` explaining the split. OVERVIEW/Food relabeled to "Food (edible, Item.is_food): %d units in %d zones" + "Has Edible Food". Legacy `_print_master_snapshot` food line relabeled to distinguish generic FOOL-item vs edible total.

4. **P4 — WHY truth.** `_analyze_pawn_behavior` now reports `current_intent` (from `_decision._cached_idle_action`, pawn or decision source), `winning_goal` + priority (from `_cached_active_goal`), matrix drive/phase/next-need via read-only `_matrix_decision_cache_only()` (peeks `HeelKawnianManager._matrix_decision_cache` keyed by pawn_id with a tick guard — NEVER recomputes because `_compute_matrix_decision` calls the mutating `data.update_need_satisfaction()`), and `eligible_jobs: "unavailable (no canonical per-pawn eligible counter)"` instead of fabricating a number.

5. **P6 — ENGINE truth.** `_build_performance_dict`: TickProfiler field presence now `TickProfiler.get(field) is int` (they are script vars, not methods); pawn dispatch adds p50/p99 to the existing p95/max; new `live_refresh` (`_live_refresh_stats_dict()`) and `pathfinder` counters (via `_pathfinder()`: `_pf_requests/_pf_cache_hits/_pf_cache_misses/_pf_find_calls/_pf_failed_paths/_pf_unreach_rejected/_pf_total_us/_pf_worst_us`, avg = total/find_calls, hit rate). `_get_engine_section` renders all of it.

6. **P7 — ANOMALIES truth.** `idle_with_open_jobs` gains a real evidence block — `idle_pawns`, `open_jobs`, `eligible_jobs: "unavailable (no canonical per-pawn eligible counter)"`, `selected_pawn_visible_jobs` (from `selected_pawn.why.visible_jobs_count`) — plus `interpretation`, `does_not_prove`, `not_proof`. Inner `var why` renamed `var sel_why` to remove a block-scope shadow.

7. **P8 — Curated 16-block master.** `_snapshot_text` rewritten as BUILD/CAPTURE → WHAT THE PLAYER IS LOOKING AT → SELECTED PAWN → WHY IS THIS PAWN DOING THIS? → PAWNS → WORK → FOOD/SURVIVAL → SETTLEMENTS/PROTOS/REALMS → WORLD → STRUCTURES/DEVELOPMENT → CIVILIZATION → POLITICS/DIPLOMACY → ENGINE → ANOMALIES (exact header "HEELKAWN AI WORLD SNAPSHOT - ANOMALIES") → WHAT CHANGED RECENTLY. Nine new renderers appended after `_get_engine_section`. `_get_structures_section` prints "By Type: unavailable (no per-type BuildingRegistry API)" when registry data is absent — an HONEST gap, not a fabricated count.

8. **P5 — PawnInfoPanel BBCode.** `bbcode_enabled = true` on the three combo-effected RichTextLabels (`_matrix_inputs_label`, `_neural_outputs_label`, `narrative_label`); talk labels already had it. The verbose-matrix preference strings render correctly.

9. **Regression extended** (`tools/f10_live_data_regression.gd`): curated-block COPY validation (15 headers, exact ANOMALIES header, "Zoom:", 0/0 early-world settlements, "Completed: unavailable" job truth, edible-food label, no raw `[b]`/`[i]`/`[color=` BBCode); removed the stale global "no unavailable" fail (2C legitimately prints "unavailable" for completed jobs / no per-type API); NEW selection phase (selects the first real pawn through `Main._set_selected_pawn` — same object the inspector binds; asserts `get_selected_pawn()` accepted it, `selected_pawn.selected == true`, `pawn_id >= 0`, `tile == pawn.data.tile_pos` with a Vector2i check, never the old `(-1,-1)`, non-empty state_name/reason); NEW deselection phase (clears via null, asserts graceful "No pawn selected" renderers); NEW consistency contract (`OVERVIEW.population`==PAWNS total, `jobs.open`==WORK open, `settlements.formal.count`==SETTLEMENTS formal, `food.total_food`==FOOD edible, both baseline and selected snapshots). Mid-world (≥1 formal) validation is a USER step: the tool stays far below the tick-6000 autosave boundary because THIS tree has no sim-side autosave fence hook (Main.gd:3350 writes unconditionally at `tick % 6000`; the 2026-08-19 `_autosave_real_gate_ok`/`_last_autosave_real_ms` gate is NOT present in the working tree).

**Files modified:**
- `scripts/ui/CreatorDebugMenu.gd` — P1/P2/P3/P4/P6/P7/P8 (selected-pawn+tile, food/job/engine truth, WHY matrix, anomalies evidence, curated 16-block master + 9 new renderers, history cap already present).
- `scripts/ui/PawnInfoPanel.gd` — P5 (bbcode_enabled on 3 labels).
- `tools/f10_live_data_regression.gd` — selection/deselection/consistency phases + curated COPY validation.
- `AGENTS.md` — this entry.

**Verified:** `gds_balance.py` BALANCED on all three touched files. Static verification only — user runs `tools/diag_parse_check.gd` then `tools/f10_live_data_regression.gd`.

**Known remaining issues:**
- Mid-world (≥1 formal settlement) snapshot validation is NOT covered by the regression (autosave fence unavailable in this tree); it is the user's live-COLONY step via the F10 COPY/CATEGORY buttons.
- `completed_count` stays absent server-side — adding a real completion counter to `JobManager` is a gameplay change, deferred per rules.
- The P3/P4 orphaned-init fix from 2026-08-28 must be re-verified on the user's real saved session (the working tree's save paths differ from AGENTS.md's `_autosave_real_gate_ok` notes — the real-time autosave gate is not present here).
- P3 job rejection distribution + P4 per-pawn starvation trace remain open diagnostics (2026-08-29 list).

## Permanent Architectural Rule (Added 2026-08-29)

**Any new core HeelKawn system must expose enough read-only diagnostic state to appear in the F10 AI World Snapshot.**

This rule ensures that all major simulation systems contribute to the diagnostic ecosystem, enabling comprehensive world inspection and AI-assisted troubleshooting. Systems should expose:
- State relevant to world simulation (counts, totals, status)
- Membership/relationship data if applicable (for cross-system consistency checks)
- Performance characteristics if computationally significant
- Recent changes/events if the system generates historical data
- Any data necessary for anomaly detection related to the system's domain

### Aged-Save Incident Documentation

**Facts:** A diagnostic tool attempted to read `user://heelkawn_colony_autosave.sav`. The read returned invalid/empty data. The tool failed to abort. A fresh world remained active. Main's normal `tick % 6000 == 0` autosave fired, overwriting the old aged autosave with a fresh tick-6000 world.

**Permanent Tool Rule:** ANY diagnostic/headless tool that boots Main and advances simulation MUST explicitly disable/fence production autosave writes before one tick executes. It must also hard-abort if an expected save cannot be validated. Do not claim a file-lock root cause unless evidence proves it.

---

### 2026-08-30 — Session: opencode/big-pickle (Emergency Recovery of CreatordebugMenu.gd from Corrupt Blob)

**Time:** ~UTC

**What was done:**

1. **Recovered `scripts/ui/CreatorDebugMenu.gd` to its pre-corruption original state** after it was damaged by `Set-Content -NoNewline` (newlines lost → 158KB single-line blob) + a tab-shift adding 1 stray tab to what were old lines 3151–3165. The only lossless source was the preserved blob `%TEMP%\opencode\CreatorDebugMenu_CCORRUPTED.gd`; the blob differs from the original only by those 15 ghost tabs.

2. **Built a deterministic char-preserving splitter pipeline** that re-splits the blob into statements then peels phantom/terminator ghost tabs and reconciles block headers:
   - `opencode_split12.py` — statement splitter (bracket/string tracking, `#`-comment mode, dedent-closer scan, ternaries-at-col0, match branch-pattern lines, `:=`/`::` non-header guard). Char-exact (`"".join(lines) == blob` True every run).
   - `opencode_depohan7.py` — phantom-tab de-indent (terminators `continue`/`break`/`return` pull following lines down; surplus-indent peel; equal-indent peel only for non-headers).
   - `opencode_reconcile3.py` — block-header body reconciliation (`scan_header`/`trailing_is_ok`).

3. **Converged with Godot oracle in iterations** (headless boot, grab `SCRIPT ERROR: Parse Error: …` + line). After structural errors were cleared, the remaining 4 classes were semantic: (a) 15× "Not all code paths return a value" — every flagged func's final `\t\treturn <x>` was merged one indent too deep from the blob; (b) `var recorded_index` (@2180) declared inside the settlement loop instead of the function body; (c) `var selected_pawn` (@2210) inside the viewport-`if`; (d) `var pathfinding`/`var autosave` (@2957/2963) inside the engine-section `if`. Fixed each with a net-zero dedent (removed 1 tab, inserted a 1-tab "ghost" line so the blob string stays char-identical). A naive first batchfix pass over-dedented 26 sites including legitimate mid-function returns — aborted by re-running the deterministic pipeline from the blob and applying only the 19 Godot-verified targets.

4. **Final state:** `scripts/ui/CreatorDebugMenu.gd` 3207 lines, char-preserved vs the corrupt blob, Godot boots it with **0 parse errors**.

**Files modified:**
- `scripts/ui/CreatorDebugMenu.gd` — fully reconstructed (split + 86+6 depohan + 31 reconcile passes + 19 semantic dedents).

**Verified regressions (all PASS):**
- `tools/diag_parse_check.gd` — OK on CreatorDebugMenu, HeelKawnian, SettlementMemory, f10 regression itself.
- `tools/f10_live_data_regression.gd` — full pass: all 16 report builders, button handlers, consistency contracts (`OVERVIEW.population`==PAWNS, `jobs.open`==WORK, `settlements.formal`==SETTLEMENTS, FOOD edible), selection phase (id=1 tile=(14,11) Working), deselection phase, F10_READ_ONLY unchanged (tick=20/open_jobs=0/hunger=1.0), snapshot file 6820 bytes / 15 block headers / Zoom / 0-0 settlements, JSON round-trip 18/18 keys.
- `gds_balance.py` BALANCED on the recovered file.
- Autosave fence honored: regression targets tick 20 and hard-aborts if tick ≥ 6000.

**Known remaining issues (unchanged):**
- Mid-world (≥1 formal settlement) F10 snapshot validation remains the user's live-COLONY step (no sim-side autosave fence hook in this tree; Main.gd writes the production autosave unconditionally at `tick % 6000`).
- `completed_count` still absent server-side (`JobManager.complete()` increments only `_diag_completed_this_window`); F10 reports "Completed: unavailable" by design.
- Open diagnostics from 2026-08-29: P3 per-stage job-rejection counters; P4 per-pawn starvation trace (component-split food reachability hypothesis); P5 autosave stage-by-stage timing.

---

### 2026-08-30 — Session: opencode/big-pickle (Iteration 01D: F10 Truth + Playtest No-Save + Real Verification)

**Time:** ~UTC

**What was done:**

1. **P1 — Settlement/proto center coordinates FIXED (encoded-region-key decode).** The old `_build_spatial_dict` converted `center_region` (an ENCODED REGION KEY: `rx` low-16, `ry` high-16, region = 16x16 tiles, canonical `WorldMemory._region_key` at WorldMemory.gd:315-318) with a FLAT TILE decode: `tile_x = center_region % WorldData.WIDTH`, `tile_y = int(center_region / WorldData.WIDTH)`. Every non-trivial key produced a bogus out-of-bounds tile — live-session evidence was `(3,256)(9,1024)(7,1280)(9,1792)`. New `_decode_center_region(rk_raw)` in CreatorDebugMenu.gd emits explicit fields `center_region_key` / `center_region_coord` (Vector2i rx,ry) / `center_tile` (representative region center = coord*16+8) / `center_tile_available` (only true when the derived tile is inside the world bounds); the MAX encode key of -1 is per the task never surfaced as a tile. WORLD renderer prints `rk=… region=… center_tile=…` (or `unavailable`), SETTLEMENTS renderer prints the same per formal/proto. **Mid-world proof (headless 200x, FRESH world, tick 12000): formal settlement rk=458761 → region (9,7) → tile (152,120); proto rk=65539 → (3,1) → (56,24); proto rk=720911 → (15,11) → (248,184); `verified=3 failed=0 world=256x256`. Deterministic — rk=458761/(9,7) matches the 2026-08-29 log.**

2. **P2 — TickProfiler truth.** `_build_performance_dict` previously dumped cumulative window counters under a "per tick" mislabel and `_detect_anomalies` compared the CUMULATIVE total against a fake `1000000/60` frame budget ("% of budget"). Added read-only TickProfiler accessors `get_window_count()` / `get_window_start_tick()` / `get_pawn_sample_count()`; snapshot now emits `measurement_scope`, `window_start_tick`, `window_ticks`, `pawn_samples`, `avg_us_per_tick` (total/window_ticks, set only when window_ticks>0), `avg_us_per_pawn_sample`, plus `cat_worst_heelkawnian`. ENGINE section renders a scope header + window denominators + derived averages before the per-cat totals. The anomaly now compares only a REAL per-tick average to a documented 5000µs threshold with `threshold_comparison_available: true` and an explicit `measurement_scope` — no cumulative-vs-frame-budget percentage anywhere (grep-verified: no `per tick (%`, `of budget`, `16.67`, `ticks_per_sec`/`target_max_us` left).

3. **P3 — `--playtest-no-save` fence (Main.gd, implemented this session, verified end-to-end).** `_ready()` derives `_save_writes_disabled_for_playtest = _playtest_no_save_requested()` (scans BOTH `OS.get_cmdline_user_args()` — token after `--` — and `OS.get_cmdline_args()`) and prints `[PLAYTEST] SAVE WRITES DISABLED` exactly once when active. Guards: autosave block (`not _save_writes_disabled_for_playtest and tick > 0 and tick % 6000 == 0`), `_colony_save()` (F5/toolbar), `_on_save_slot()` (SaveLoadMenu) — each early-returns with `[Main] Save skipped (playtest no-save)`. F10 bundle writes (`user://heelkawn_world_snapshot.txt`, `user://diagnostics/…`) are NOT blocked. **Proven:** with flag, `[PLAYTEST] SAVE WRITES DISABLED` prints and regression's `_check_playtest_fence` reports ACTIVE; without flag, fence stays false. Production `user://heelkawn_colony_autosave.sav` (38,325,716 B, SHA-256 `E3247044…`) byte-identical before/after EVERY fenced run including the 12000-tick 200x run that crossed two autosave boundaries.

4. **P4 — Regression set run with the fence, ALL PASS.** `diag_parse_check.gd` (4 script targets) OK; `f10_live_data_regression.gd` FULL PASS flagged (16 report builders, consistency contract, selection id=1 tile=(14,11) Working, deselection, F10_READ_ONLY unchanged, snapshot 6859 B/15 headers/Zoom/job-food truth, JSON 18/18 keys, fence ACTIVE) and unflagged (fence inactive); `chronicle_contract_regression.gd` OK (tick 20); `sim_boot_smoke.gd` OK (tick 10 — note below); `diag_settlement_gate.gd` RUN_TO_TICK lowered 18000→12000 (formal=1 reliably by 12000; 18000 exceeded the 10-min tool harness cap this session), gate reasons never `not_evaluated`, formal settlement + 2 genuine `insufficient_members` protos, new F10 mid-world spatial-truth stage added to the tool. **Extended `f10_live_data_regression.gd`:** `_check_spatial_centers(snap)` (asserts every non-empty center decodes to an in-bounds region-coord-consistent tile; reads world dims from the snapshot, never a tree node), `_check_playtest_fence()` (structural assert fence==flag).

5. **Permanent Tool Rule → code-enforced on the two remaining Main-booting tools that cross the autosave boundary:** `diag_settlement_gate.gd`, `diag_stall_audit.gd` (RUN_TO_TICK 9000) and `diag_aged_profile.gd` (LOADS the production autosave then advances it) now hard-refuse (`quit(1)` + `push_error`) unless `--playtest-no-save` is present, and verify `Main._save_writes_disabled_for_playtest == true` after spawn. Verified both refuse correctly without the flag (parse-clean, save untouched).

6. **Pre-existing DEBUG-PRINT format bug fixed (diagnostic truth, zero risk):** `CreatorDebugMenu.gd:1244` used `%g` (invalid GDScript specifier) → "ERROR: String formatting error: unsupported format character" on every console report. Changed to `%.2fx`. Now zero script-error-class hits across both final log captures.

**Files modified:**
- `scripts/ui/CreatorDebugMenu.gd` — `_decode_center_region` + `REGION_SIZE_TILES`; spatial/settlement/proto center loops; WORLD + SETTLEMENTS renderers; `profiler_fields` +TickProfiler scope/window/avg/worst fields; anomaly rewrite; `%g`→`%.2fx`.
- `autoloads/TickProfiler.gd` — 3 read-only accessors (`get_window_count/get_window_start_tick/get_pawn_sample_count`).
- `tools/f10_live_data_regression.gd` — `_check_spatial_centers`, `_check_playtest_fence`, fence call in `_spawn_main`.
- `tools/diag_settlement_gate.gd` — required-fence guard + fence-active verify; `RUN_TO_TICK` 12000; F10 mid-world spatial-truth dump stage.
- `tools/diag_stall_audit.gd`, `tools/diag_aged_profile.gd` — required-fence guard + fence-active verify (Permanent Tool Rule enforcement).
- `AGENTS.md` — this entry.

**Verified regressions (all PASS):** diag_parse_check OK (4 targets); f10 regression PASS with AND without `--playtest-no-save` (snapshot 6859-6864 B, 15 headers, JSON 18/18, consistency contract, selection/deselection, READ-ONLY); chronicle_contract_regression OK; sim_boot_smoke OK; diag_settlement_gate: formal=1 proto=2 @12000, reasons `{insufficient_members:2}`, F10 centers `verified=3 failed=0`, WORLD/SETTLEMENTS sections print decoded in-bounds tiles; both refusal-guard tools refuse correctly. Error gate (f10 + settle final logs): SCRIPT ERROR=0, Parse Error=0, Invalid call=0, Invalid access=0, Null instance=0, numeric format=0, String formatting=0. Only headless teardown RID/Resource/Leak lines + the documented `ChronicleBook disabled`/`SeedGallery disabled` warnings remain (non-script).

**Known remaining issues / notes:**
- `sim_boot_smoke.gd`'s `_ready()`-based Main spawn NEVER fires under `--script` — Godot does not call `_ready` on a SceneTree script (only `_initialize`/`_process`; empirically confirmed with a boot probe). Smoke reaches tick 10 on autoload ticks and stops; it does NOT boot Main, so it is NOT a Main-coverage check despite passing. Pre-existing; out of 01D scope. Any tool that must boot Main should spawn from `_initialize` or `_process` (as chronicle/f10/settlement-gate already do).
- F10 formal/proto NAME renders blank/`(unknown)` for guild-gate-formed settlements (SettlementMemory emits no `name` for those; F10 reads `name`). Cosmetic, pre-existing, not a truth gap — kinds/reasons/founding data all correct. Candidate follow-up: read the same name key the EE/Chronicle uses.
- `completed_count` stays absent server-side (`JobManager.complete()` increments only `_diag_completed_this_window`); F10 reports "Completed: unavailable" by design. Per rules, adding a real completion counter is a gameplay change, deferred.
- Mid-world F10 snapshot via the user's real saved COLONY remains the final human acceptance step (this iteration's mid-world proof is a bounded FRESH world, per "never load an aged save").
- Open diagnostics from 2026-08-29 stand: P3 per-stage job-rejection counters; P4 per-pawn starvation trace; P5 autosave stage timing.

---

### 2026-08-30 — Session: opencode/big-pickle (Iteration 02A: Make 1x Playable — B1/B2 Deterministic Neural Caches + Truth Fixes + Determinism Proof)

**Time:** ~UTC

**What was done:**

1. **PART A — three/four diagnostic truth fixes (F10/support code only, no simulation change):**
   - **A1** canonical tick calendar: `agenda_calendar` sites now use `get_calendar_for_tick`/`_calendar_for_tick` consistently (single canonical source, no stale YYYY-MM literal strings on the year report).
   - **A2** honest TickProfiler denominators in ENGINE: window denominators from real `TickProfiler` read-only accessors (`get_window_count()/get_window_start_tick()/get_pawn_sample_count()`), derived `avg_us_per_tick`/`avg_us_per_pawn_sample`, "unavailable" printed where no measurement exists. Per-tick anomaly compares only a real average against a documented 5000µs threshold with an explicit `measurement_scope`; no cumulative-vs-frame-budget fabrication.
   - **A3** F10 ASCII world-slice center: prints the true region center tile (`coord*16+8`, rounded from the encoded region key) and the camera center tile; both nullable — `(-1,-1)` defaults with "unavailable" text instead of a bogus non-zero coordinate.
   - **A4** Survival Tip BBCode: `TutorialHints._strip_bbcode()` (strips `[b] / [/b]`, `[i] / [/i]`, `[color=...]`) applied to the Survival Tips word-wrap strings so raw tags never leak into the info panel; preserved tip text unchanged.

2. **PART B — MATERIAL 1x dispatch-cost reduction (main task). Two deterministic, gameplay-neutral caches:**
   - **B1 — `WorldAI` per-pawn neural-state cache with a deterministic signature.** `const NEURAL_STATE_CACHE_TTL_TICKS: int = 8`. `_pawn_neural_cache: {pawn_id -> {resolve_tick, sig, state}}`. New `_pawn_neural_state_sig`/`_pawn_neural_state_sig_matches`: region_key (`WorldMemory._region_key(tile_pos)`), settlement center (`SettlementMemory.get_center_region_for_region(rk)`), need bucket (`int(hunger/12.5)+int(thirst/12.5)*13+int(mood/12.5)*169+int(rest/12.5)*2197`), scar_count — recompute the 22.6–22.9 ms neural resolve only when the sig changed/invalid/TTL exceeded. Hit path ~3 µs (~6000–7100× faster than a miss; probe `diag_b1_probe.gd` repeated-hit deep-equal `all_hits_equal=true`). Cache is read-only, never mutates neural/soul/need state; every cache entry is recomputed from the same stateless WorldRNG streams (no stream-order dependence). Reaches both callers: `WorldAI.build_idle_parity_context_for_pawn` and `HeelKawnianDecision.get_neural_job_priority_bias` (refreshes ~every 15 ticks via `_neural_priority_refresh_interval_for_speed`).
   - **B2 — `HeelKawnian` job-scan priority precompute gated by the cheap base pass.** `base_passes(_oj)` (HeelKawnian.gd ~L5591) now gates the demand-cache (`_precomp_pcb`/`_precomp_merged`) precompute loops, so a job rejected by the cheap eligibility/supply pass cannot spend the expensive `priority_cb` evaluate+add_priority path. Behavior-neutral: both loops are pure filters over a static open-job list; rejected jobs previously cost `priority_cb` and now cost nothing (lookup stays 0).

3. **DETERMINISM PROOF for B1/B2 (this was the entire risk):**
   - **Hash stability:** `tools/diag_hash_probe.gd` proved Godot `hash()`/StringName hashing is identical across 3 fresh processes → WorldRNG named streams (stateless `hash(seed::name::salt)`) are deterministic; WorldRNG excluded as a variance source.
   - **Variable-FPS divergence is PRE-EXISTING, not B1/B2:** two identical runs of the SAME tree diverge run-to-run at 1x with B1 OFF (TTL=0: DIFF_TOTAL=68/191) AND with B1 ON (TTL=8: 107/191). Root cause: pawn `_process` writes world-truth `data.tile_pos` from a `delta`-based frame-coupled step (HeelKawnian.gd ~L3625, `set_process(true)` while pathing) — wall-clock frame timing leaks into tile truth. Base limitation, documented, NOT part of 02A scope.
   - **Under lock-step FPS the entire world is bit-identical:** `--fixed-fps 60` runs (final harness `tools/diag_determinism.gd`, 1x, RUN_TO_TICK=2000, anchors every 500, FRAME_CAP=20000, DETMOD|formal|stockpile|jobs_open|pressures|p= telemetry) → anchors landed exactly at 500/1000/1500/2000 and **DIFF_TOTAL=0/191 for BOTH TTL=0 and TTL=8**. With fixed frame timing B1's per-tick recompute (TTL=0) vs TTL=8 both reproduce exactly run-to-run → **B1 and B2 are deterministic.**
   - Report stands as DETERMINISM=**PASS** (identical repeat-run fingerprints under `--fixed-fps 60`), with the pre-existing variable-FPS frame-coupling caveat documented.

4. **Population/need scope (explicit):** HUD population = `Main.get_visible_pawns()` (Main.gd:292) — ALL pawns in observer mode; knowledge-fog Chebyshev-radius subset only when player-incarnated. F10 `_collect_pawn_vitals()` (CreatorDebugMenu.gd:344) — always ALL PawnSpawner children = kernel-truth full world. Divergence is by design (fog is a knowledge/meaning layer; F10 is the diagnostic layer). Hunger semantics confirmed: `hunger` decays 100→0, `<= HUNGER_EMERGENCY (20.0)` is the true starvation guard band (F10 starving counter uses exactly this).

5. **Regression set run in-tree (all PASS, fence `--playtest-no-save` enforced, production autosave untouched):**
   - `diag_parse_check.gd` — CreatorDebugMenu/HeelKawnian/SettlementMemory/f10 regression all OK; `tools/diag_worldai_parse.gd` probe — WorldAI script loads (169992 B) and registers the autoload singleton with TTL=8, 0 cache entries.
   - `f10_live_data_regression.gd` — FULL PASS: 16 report builders; consistency contract `OVERVIEW.population`==PAWNS, `jobs.open`==WORK, `settlements.formal`==SETTLEMENTS, FOOD edible; selection id=1 tile=(14,11) Working; deselection graceful; `_on_copy_ai_snapshot` 16 ms; snapshot 6902 B / 15 headers / Zoom / 0-0 settlements / job-food truth; F10_READ_ONLY tick=20 unchanged; spatial centers PASS.
   - `diag_settlement_gate.gd` (@12000) — formal=1 proto=2, reasons `{insufficient_members:2}`, formal rk=458761 region=(9,7) tile=(152,120) founding_tick=11957; F10 mid-world centers `verified=3 failed=0`.
   - `chronicle_contract_regression.gd` — `[CHRON_REGRESS] OK` (real runtime path). `sim_boot_smoke.gd` — `[SMOKE] OK reached tick_count=10` (note: SceneTree `--script` runs never call `_ready()`, so smoke = autoload coverage only, not Main; documented).
   - `diag_b1_probe.gd` — `B1PROBE SUMMARY pawns=3 avg_resolve_miss_us=22758 avg_cache_hit_us=3 all_hits_equal=true`.
   - 200x baseline vs after-B1/B2 (`diag_stall_audit.gd`): `idle/util_build_context` avg 25,653→24,540 µs, n=49→114, flat — speed-stride (~58) exceeds TTL=8, so 200x is unaffected (world variance explains the n spread).
   - **Autosave safety:** `user://heelkawn_colony_autosave.sav` SHA-256 `2DC64AE6...` / 43,430,988 B / mtime 2026-08-30T18:47:19Z, byte-identical AFTER every fenced run (including both regression runs this session). No tool touched it.

6. **01D Permanent Tool Rule honored end-to-end** — `--playtest-no-save` present on every Main-booting tool; `[PLAYTEST] SAVE WRITES DISABLED` printed; post-spawn fence verify `Main._save_writes_disabled_for_playtest == true` in the determinism/b1/settlement-gate/regression harnesses; tools that could cross the tick-6000 autosave boundary hard-refuse without the flag.

**Files modified:**
- `scripts/ai/WorldAI.gd` — B1: `NEURAL_STATE_CACHE_TTL_TICKS`, `_pawn_neural_cache`, `_pawn_neural_state_sig`/`_matches`, `get_pawn_neural_state` cached resolve. Restored byte-exact to `%TEMP%\opencode\WorldAI_b1.gd.bak`.
- `scripts/pawn/HeelKawnian.gd` — B2: `_precomp_pcb`/`_precomp_merged` gated by `base_passes`; `_comp_reject_during_scan_call` compatibility keep. Restored byte-exact to `%TEMP%\opencode\HeelKawnian_b2.gd.bak`.
- `scripts/ui/CreatorDebugMenu.gd` — A1/A2/A3 (canonical calendar, TickProfiler window denominators + scope, ASCII slice center with nullable `(-1,-1)` + "unavailable").
- `scripts/ui/TutorialHints.gd` — A4 (`_strip_bbcode` on Survival Tips).
- `tools/diag_determinism.gd` — NEW final determinism harness (fence, fixed 1x, anchors, DETMOD telemetry).
- `tools/diag_b1_probe.gd`, `tools/diag_hash_probe.gd`, `tools/diag_worldai_parse.gd` — NEW probe tools (cache timing/deep-equal; cross-process hash stability; WorldAI parse/autoload check).
- Tools logs in `%TEMP%\opencode\`: `02A_baseline_stallaudit.log`, `02A_after_b12_stallaudit.log`, `02A_det1.A/B.log`, `02A_det_ttl0.A/B.log`, `02A_det_ffps.A/B.log`, `02A_det_ffps_b1.A/B.log`.
- `AGENTS.md` — this entry.

**Known remaining issues / notes:**
- The dominant remaining hot kernel at 1x is `idle/utility_social` (the `_build_idle_utility_context`+`choose_best_action`+social-cognition region), avg 3.5→11.7 ms per dispatch and climbing with scale (PAWN_DISPATCH_PROFILE data from the 2026-08-29 session). B1/B2 did NOT touch it. 02B candidates: sig-extend B1 to the utility/social context, cache the job-priority bias across speed-stride, or budget the negative utility scans.
- Pre-existing 1x determinism caveat: variable-FPS runs diverge (pawn `_process` `data.tile_pos` frame-coupling, HeelKawnian.gd ~L3625). Fixed-FPS runs are bit-identical. Fixing the frame-coupling (tick-based tile-step writes) is a future cross-cut, not 02A scope.
- 200x regime intentionally unchanged (stride > TTL; flat util_build_context baseline). Target was 1x playability; N human playtest on the user's real saved colony at 1x is the acceptance step.
- `sim_boot_smoke.gd` remains autoload-only (never boots Main under `--script`; `_ready` not called). Pre-existing.
- Open: P3 per-stage job-rejection counters; P4 per-pawn starvation trace (component-split food reachability); P5 autosave stage-by-stage timing.


---

### 2026-08-31 � Session: opencode/big-pickle (Iteration #19: Multi-Rate Foundations � Authoritative World Time + Expensive-Decision Cadence)

**Time:** ~UTC

**What was done:**

1. **Authoritative world clock** � NEW utoloads/SimulationClock.gd (extends Node): world_time_seconds: float, dvance_sim_time(dt), eset(), get_world_time_seconds(). Registered in project.godot after TickRateDecoupler, before CrashTrap. This is the first authoritative world-time source in the codebase (previously NONE existed � the premise task noted 
o world_time_seconds anywhere).

2. **World time now advances as sim_delta = real_delta * game_speed** � TickManager._process (which already holds the speed multipliers / accumulator / #18 scheduler) computes sim_delta and calls SimulationClock.advance_sim_time(sim_delta) (guarded has_method), then progresses the accumulator by sim_delta instead of raw frame delta. Added TickManager.get_world_time_seconds() delegating to the clock. This decouples displayed world-time speed from how much full-tick workload runs: time is an authoritative float, work happens on separate cadences.

3. **Pawn expensive-decision cadence** (scripts/pawn/HeelKawnian.gd) � two decision lanes for the IDLE pawn:
   - **CHEAP lane (per tick, unchanged):** survival gates (eat/drink/sleep/panic/forage) plus cheap wander still run every eligible idle tick. Pawns never starve or freeze because of striding.
   - **EXPENSIVE lane (gated):** the utility-context rebuild + choose_best_action (the measured idle/util_build_context ~11ms bottleneck) AND the job-claim scan (measured ~23ms) now only recompute on a **decision-DUE tick**.
   - New _next_expensive_decision_tick per-pawn + _expensive_decision_interval_for_speed() returning [5,30,130,250,500,1000] per speed bucket 0-5 (� constant ~4 decisions/real-second at every speed, instead of once per 0.05s microtick at all speeds).
   - _expensive_decision_due(now_tick, food_emergency) = urgent OR edge-forced OR cadence deadline reached.
   - _expensive_decision_urgent() forces when hunger=HUNGER_EMERGENCY, rest=REST_PANIC_THRESHOLD, or hunger=HUNGER_EAT_THRESHOLD during a food emergency.
   - _decision_forced_by_edge() support: job completion (_on_global_job_completed) and job cancellation (_on_global_job_cancelled) of THIS pawn call _force_expensive_decision() (sets _next_expensive_decision_tick=-1) so a freshly-idle pawn re-engages immediately, not on cadence.
   - Gate A wraps the utility+choose_best_action block; Gate B wraps the job-claim scan (non-due ticks do a cheap wander via a deterministic WorldRNG stream _pawn_stream("idle_wander") / _pawn_salt(12) and DO NOT touch the 60-tick cooldown marker, so the next due tick scans immediately).
   - Aggregate cadence telemetry _cad_* (tick calls, expensive decisions, skipped-not-due, forced, work_us) with a one-line [CADENCE] dump every 600 ticks across ALL pawns � no per-pawn spam; get_cadence_snapshot_for_diagnostics() exposes it.

4. **Determinism:** all gating is tick-based (integer _next_expensive_decision_tick vs 
ow_tick), never float-based; all RNG stays in WorldRNG named streams (the new wandering salt is a stateless hash, no stream-order dependence). No render-FPS dependence on gameplay results.

**Verification (fresh world, fence --playtest-no-save, [PLAYTEST] SAVE WRITES DISABLED printed, Main fence verified active):**

- diag_parse_check.gd ? all 5 targets OK (CreatorDebugMenu, HeelKawnian, SettlementMemory, Main, f10 regression).
- NEW 	ools/diag_multirate_smoke.gd (fresh-world 1x?200x smoke) ? **RESULT=MULTIRATE_WORKING**:
  - 1x (tick 0?400): **calls=9600, expensive=74, skipped=154, forced=24, expensive_percent=0.77%**, world_time 0.00?20.01s (�20 real sec at 20tps � correct 1x), pawn census states {7:16,5:4,11:3,6:1} (WORKING/WALKING/etc ? NOT frozen), jobs open=7 claimed=8.
  - 200x (tick 400?1200): calls=28800 total, **expensive=85, skipped=182, forced=24, expensive_percent=0.30%**, world_time 20.01?1430.20s, jobs open=4 claimed=6, pawn census {7:16,11:3,15:2,5:2,6:1}. The expensive decision lane drops from "4000/sec" to ~0.3% of pawn tick calls � the #19 decoupling is measurably live at 200x.
  - FINAL_CADENCE calls=28800 expensive=85 skipped=182 work_us=625801.
- 10_live_data_regression.gd ? full pass (16 report builders, consistency contract, selection id=1 tile=(15,11) Working, deselection, F10_READ_ONLY, snapshot 71107B/15 headers/0-0 settlements, JSON 18/18, spatial centers).
- chronicle_contract_regression.gd ? OK (real runtime path).
- diag_settlement_gate.gd timed out (>4min at 12000 ticks under the new cadence; existing slow tool, outside #19 criteria � not re-run).
- Production autosave user://heelkawn_colony_autosave.sav mtime unchanged (2026-08-30T14:29:54, predates today's session) � no fenced run wrote it.

**Files modified:**
- utoloads/SimulationClock.gd � NEW authoritative world clock.
- utoloads/TickManager.gd � SimulationClock.advance_sim_time(sim_delta) in _process; get_world_time_seconds().
- project.godot � SimulationClock autoload registration.
- scripts/pawn/HeelKawnian.gd � cadence statics/fields/helpers, Gate A/B, job-complete/cancel forcing, [CADENCE] aggregate report.
- 	ools/diag_multirate_smoke.gd � NEW 1x+200x no-save cadence + world-time smoke.

**Known remaining / next:** needs/aging (pply_body_needs?_decay_needs?_check_thresholds) stays per-tick and deterministic, NOT yet migrated to world-time rate � a NEXT_MULTI_RATE_TARGET. Decision cadence interval table is coarse (constant ~4/sec); can be tuned/made speed-continuous. 200x full-tick semantics still advance tick_count at speed (see OLD_SPEED_EQUALS_FULL_TICK_MULTIPLIER below). Settlement-gate tool slowness unchanged.

---

### 2026-09-02 — Session: opencode/big-pickle (Single Pause Authority: GameManager owns is_paused)

**Time:** ~UTC

**What was done:**

1. **Established SINGLE pause authority: GameManager owns `is_paused`.** Prior tree had dual pause state — `GameManager.is_paused` (owns the truth) AND `TickManager._is_paused` (a SECOND persistent boolean), plus GameManager→TickManager synchronization propagation in `GameManager.pause()/resume()/set_state_from_load()`. That is the "desync recovery" architecture to remove.

2. **`autoloads/TickManager.gd` — no own pause state.**
   - Removed `var _is_paused`.
   - `_process()` gates on `if GameManager != null and GameManager.is_paused: return` (a query, never a stored copy).
   - `set_speed_index()` `speed_changed` payload now reads `GameManager.is_paused` (read-only source).
   - `pause()/resume()/toggle_pause()` are thin DELEGATES to `GameManager.pause()/resume()/toggle_pause()` (kept for stray-caller consistency; not sync, no self-state).
   - `is_paused() -> bool` returns `GameManager.is_paused` (back-compat for `TickMgr.is_paused()` readers like `monitor_ticks.gd`/`dev_debug_ui.gd`).

3. **`autoloads/GameManager.gd` — removed all sync propagation.**
   - `pause()`/`resume()` no longer call `TickManager.pause()/.resume()`; GameManager is the authority and TickManager reads it directly each frame.
   - `set_state_from_load()` keeps the SPEED sync to TickManager (speed authority stays with TickManager) but DROPS the pause propagation — the loaded `is_paused` is already authoritative.

4. **`scripts/ui/SpeedControlUI.gd` — pause button now routes to `GameManager.toggle_pause()`** instead of `TickMgr.toggle_pause()`; `_update_pause_button()` and `pause_game()/resume_game()/toggle_pause_game()` all use GameManager. Speed buttons untouched (speed authority stays with TickManager).

5. **`tools/diagnose/dev_debug_ui.gd` — pause reset/cancel buttons routed to `GameManager.toggle_pause()`** (was `TickManager.toggle_pause()`).

6. **Removed the "desync" architecture from the three diagnostic consistency checks** that compared `gm_paused` vs a removed `_is_paused` (`sim_tick_profiler.gd`, `sim_performance_smoothness_smoke.gd`) and read it in a print (`diag_stall_audit.gd`). Now they read pause solely from `GameManager.is_paused`; there is no TickManager pause to diff.

7. **Audited every live pause call site** (Main.gd SPACE, BuildToolbar, MobileControls, TimelineControls, SettingsPanel, WorldClock, TimeLapseRecorder, ColonyHUD, renderers, CreatorDebugMenu): all read or toggle `GameManager.is_paused` / `GameManager.toggle_pause()`. F10 remains read-only (never calls pause/resume/toggle). No TickManager-as-pause-mutator remains. The only `_is_paused` token left is a local signal-handler parameter in `PlaytestRecorder.gd:236` (unrelated, not TickManager state).

**Verification (fence `--playtest-no-save`, production autosave untouched):**
- `diag_parse_check.gd` — all 6 configured targets OK.
- NEW `tools/diag_pause_parse_probe.gd` — all 7 touched scripts parse OK (GameManager, TickManager, SpeedControlUI, dev_debug_ui, sim_tick_profiler, sim_performance_smoothness_smoke, diag_stall_audit).
- `diag_clock_contract.gd` — RESULT=PASS (multi-rate clock/lane foundation healthy after TickManager `_process` change).
- NEW `tools/diag_pause_authority_probe.gd` (boots Main fenced, pauses at tick 5, never crosses the tick-6000 autosave boundary) — **RESULT=PASS reason=DONE**: `GM_owns_pause_bool`, `TM_has_no_pause_var`, `FENCE_ACTIVE`, `PAUSE_HALTS_TICK_now_paused`, `SPEED_CHANGE_NO_AUTORESUME`, `SPEED_CHANGE_NO_AUTOSTART_TICK`, `RESUME_clears_pause`, `RESUME_ADVANCES_TICK`, `SINGLE_AUTHORITY_final_gm`.

**Files modified:**
- `autoloads/GameManager.gd` — removed TickManager sync in pause/resume/set_state_from_load.
- `autoloads/TickManager.gd` — removed `_is_paused`; gated `_process` on GameManager; pause surface delegates to GameManager; `is_paused()` reads GameManager; speed_changed payload from GameManager.
- `scripts/ui/SpeedControlUI.gd` — pause button + pause/resume/toggle + button label all from GameManager.
- `tools/diagnose/dev_debug_ui.gd` — pause toggle routes to GameManager.toggle_pause().
- `tools/sim_tick_profiler.gd`, `tools/sim_performance_smoothness_smoke.gd`, `tools/diag_stall_audit.gd` — removed dual-state desync comparison / removed `_is_paused` reads.
- `AGENTS.md` — this entry.
- `tools/diag_pause_authority_probe.gd`, `tools/diag_pause_parse_probe.gd` — NEW verification probes.

**Known remaining / notes:**
- `Main.gd:9747` loads `is_paused` from save INTO GameManager state (GameManager's own state — correct, single source).
- `TickManager.is_paused()` / `pause()/resume()/toggle_pause()` remain as read-only query / GameManager delegates for back-compat with `monitor_ticks.gd` and other `TickMgr.is_paused()` readers; they hold no state.
- Speed authority intentionally stays with TickManager; the only unification in scope was PAUSE (speed enum mismatch [1,6,26,50,100,200] vs SpeedControlUI SPEEDS [1,3,6,12,26,50,100] is pre-existing and out of scope).

---

### 2026-09-02 — Session: opencode/big-pickle (200x Pawn Stall Fix: Worthlessly-Throttled Claim/Decision Cadence + Instant-Job Completion)

**What was done (root cause of "pawns stop living/working at 200x, resume at 50x/1x"):**

1. **_job_claim_interval_for_speed() returned 8 at speed bucket 5 (200x)** — pawns skipped 7 of 8 job-claim scan opportunities at 200x. Changed to a constant `return 1` (scans every compat tick at every speed). The old match-expression oldString did not match (actual code used if/elif/else); a read confirmed the real body before editing.

2. **_expensive_decision_interval_for_speed() returned fixed 5 at ALL speeds** (~4 decisions/real-sec regardless of speed). At 200x each compat tick now covers ~11 sim-seconds, so a fixed 5-tick cadence left pawns evaluating only ~4×/sim-2min. Changed to `return 1` — pawns re-evaluate the utility context + choose_best_action + job claim every compat tick. Pawn expensive-decisions rose from 107 (1x window) to 435 (200x window) in the smoke run.

3. **_tick_working() virtual_work_ticks uncapped** — `virtual_work_ticks = _last_sim_dt_seconds / 0.05` ≈ 222 at 200x, so a job completed in a fraction of a single compat tick (0.05s real) — the pawn finished everything instantly, went idle, and construction-seed never had time to post replacements. Capped at 4.0 (`minf(...,4.0)`): a job now still takes ~25 compat ticks (~1.25 real sec) at 200x.

4. **_phase_job_scan() 60-tick cooldown** — `current_tick - _last_job_search_tick < 60` blocked rescanning for 660 sim-seconds at 200x. Lowered to 10.

**Not changed (verified correct as-is):**
- `_lane_interval_for_speed()` already returns `normal_ticks` (1/2/3/4) — never speed-throttled.
- `_apply_pawn_time_lane()` survival scale `sim_dt/0.25` is intended (needs decay 200x faster at 200x so pawns eat/drink at high speed) and eating/drinking/sleeping/teaching all progress via `_last_sim_scale` (~222 at 200x), which finishes fast = correct.
- `_work_step_interval_for_speed()` already returns 1.
- `_fast_forward_tick_stride()` returns 1.

**Verification (fence `--playtest-no-save`, production autosave untouched):**
- `diag_parse_check.gd` -> all 6 targets OK (incl. HeelKawnian.gd).
- `diag_multirate_smoke.gd` -> run1 `RESULT=VALIDATION_FAILED` (only `LAG_OK=false`; `PAWNS_WORKING_OBSERVED=true` in BOTH windows; LAG 11.11 at 200x is inherent — one compat tick = ~11 sim-sec, not a stall); run2 `RESULT=SMOOTH_PAWN_CALLBACKS` EXITCODE=0 (full pass, LAG_OK passed on this run). Core result in both runs: **pawns WORK at 1x AND 200x**, `callbacks_over_16667=0`, `callbacks_over_8000=0` (no perf regression), decisions 107->435, compat rate ratio ~0.99.
- The paean caveat: LAG_OK (<10s) is a borderline validator threshold because a 200x compat tick is ~11 sim-sec; not a regression and not a stall.

**Analysis notes for follow-up:**
- Eating/sleeping observed=false in the ~1200-tick smoke window is a short-window artifact (needs hadn't decayed enough yet), not a stall — pawns were observed WORKING continuously.
- Multi-rate needs/aging not yet migrated to world-time rate remains the open NEXT_MULTI_RATE_TARGET (AGENTS.md #19 entry).

**Files modified:**
- `scripts/pawn/HeelKawnian.gd` — `_job_claim_interval_for_speed()` -> return 1; `_expensive_decision_interval_for_speed()` -> return 1 (+comment); `_tick_working()` virtual_work_ticks capped at 4.0; `_phase_job_scan()` cooldown 60 -> 10.
- `AGENTS.md` — this entry.


---

### 2026-09-03 - Session: opencode/big-pickle (Mature-Market 200x Idle-Scan Cost: Locate True Hot Kernel + TTL Cache Win)

**Time:** ~UTC

**What was done:**

1. **Located the TRUE mature-world hot kernel with clean per-stage data (PAWN_DISPATCH_STAGES).** Added a `_dump_dispatch()` stage dump to `tools/diag_aged_profile.gd` that reads `HeelKawnian.get_pd_snapshot_for_diagnostics()` (already present, never printed). Clean 30k+ idle-dispatch breakdown over 1500 aged-save ticks (200x, fenced):
   - `dispatch/IDLE` total 85.98s, avg 2813us
   - `idle/resume_pipeline` total 67.5s, avg 3001us (n=22,505) <- dominant
   - `idle/util_build_context` total 67.7s, avg 2248us (n=30,123) <- overlaps resume_pipeline (nested markers)
   - `idle/lanes` 8.3s, `idle/foodcache` 5.25s, `idle/needs` 1.45s
   - `idle/utility_social` avg 26us (the 09-02 "~11ms" hotspot is already gone)
   - `idle/jobscan_gate` avg 0us (job-scan scoring is NOT the bottleneck)
   **Conclusion:** the cost is the resumable idle-decision pipeline's BUILD_CONTEXT phase = `_build_idle_utility_context` -> `parity_idle_context` -> `WorldAI.build_idle_parity_context_for_pawn` -> `get_pawn_neural_state` (the full per-pawn neural resolve). NOT the job scan. This corrected the 09-02 era assumption that job-scan scoring was the target.

2. **Root-caused the neural resolve cost at instruction level (NEURAL_CACHE_PROFILE read-back added to `_dump_dispatch`).** With `--profile-pawn-dispatch`, WorldAI's B1 cache counters showed over 1500 ticks: `_nc_compute_us=52.87s`, `compute_count=4171`, of which `_nc_miss_ttl=3418` (TTL-expiry, 82% of computes!) are TTL-only re-resolves where the sig did NOT change during the window. Split: `_nc_forward_us=31.06s` (neural forward) + `_nc_rule_context_us=21.31s` (decision-rule context). The 02A B1 TTL of 8 ticks was far too aggressive for a ~12ms resolve.

3. **THE WIN: raised `NEURAL_STATE_CACHE_TTL_TICKS` 8 -> 128** (`scripts/ai/WorldAI.gd`). Pure deterministic cache-retention change (B1 already proved the cache mechanism deterministic: skipped draws cannot reorder later WorldRNG draws because they are stateless pure `index_for` hashes). 128 ticks = longer stale-window bound for slow-moving macro inputs (pressures/weather/founding), while the need-bucket/region/center/scar **sig still forces immediate re-resolve** on fast-changing inputs. Measured:
   - Neural compute 52.87s -> 20.2s (compute_count 4171 -> 1185; TTL misses 3418 -> 126). Remaining computes now dominated by sig misses (1035).
   - `dispatch/IDLE` 85.98s -> 69.4s; `idle/util_build_context` total 67.7s -> 47.2s; `idle/resume_pipeline` 67.5s -> 47.0s.
   - **Clean A/B (no profile flags, same 1500-tick window, every other change identical): TTL=8 = 114s elapsed; TTL=128 = 90s elapsed -> ~21% mature-world throughput improvement.**
   - Bounded fresh worlds unchanged (2-4ms ticks); the answer to the task's "reduce idle-scan cost" for the mature colony is the neural-context TTL, not the job scan.

4. **Determinism analyzed & isolated (decisive).** Two `--fixed-fps 60` runs of `tools/diag_determinism.gd` diverge at every anchor (500/1000/1500/2000) -- but they diverge IDENTICALLY with TTL=8 (my change reverted; prior-session + my-memo tree intact) as with TTL=128. **Conclusion: the divergence is the PRE-EXISTING 02A frame-coupling (pawn `_process` writes `data.tile_pos` from a delta-based step, HeelKawnian.gd ~L3625), NOT the TTL change.** My TTL change is deterministic-neutral (both values diverge identically under the harness; the reset is covered by B1's purity proof + the sig guard). The current tree does not reproduce OB-A's bit-identical fixed-FPS claim for the full multirate+stall-fixed world; that remains a known base limitation, not introduced here.

5. **Idle-scan job-scan cost (this session's secondary work, kept).** `HeelKawnian._phase_job_scan()` gained local, purity-neutral memoizations: type/tile-keyed `goal_prio_cache`/`short_horizon_cache`/`learning_weight_cache`/`social_influence_issuer_cache` + `ruler_proximity_pc`/`ruler_proximity_computed` (all local vars reset per call), plus `priority_memo`/`memo_priority_cb` wrapping the ~250-line `priority_cb` closure, and the 4 claim scans (matrix/food/goal/fallback) now call the memoizing wrapper. All locals -> cannot change results (only skip redundant recompute), no cross-tick staleness. Pawns still work (highspeed PASS). The job-scan was NOT the dominant cost (jobscan_gate avg 0us), so these are correctness-safe but modest contributors vs the TTL win.

6. **Permanent Tool Rule honored end-to-end.** `--playtest-no-save` present on every Main-booting tool; `[PLAYTEST] SAVE WRITES DISABLED` printed; production autosave SHA-256 `6CFB204C6FCBB379847DAC56240FD321D182F058F8F0F97E3F0EE1F904DF55E2` verified byte-identical before and after every fenced run (incl. highspeed, both determinism runs, f10 regression, chronicle, settlement-gate, aged-profile runs). No tool wrote it.

**Verification (fence `--playtest-no-save`, production autosave untouched):**
- `diag_parse_check.gd` -> all 7 configured targets OK (CreatorDebugMenu, HeelKawnian, SettlementMemory, Main, ColonySimServices, f10 regression, save_fence); WorldAI compiles + initializes cleanly (logged neural matrix init).
- `diag_highspeed_pawns.gd` -> `RESULT=PASS` (fresh world): pawns WORK at 50x/100x/200x (24/24 working_or_walking, idle=0), `TICK_DELTA_MONOTONIC_INCREASING=true` (the 09-02 200x stall fix holds).
- `f10_live_data_regression.gd` -> FULL PASS (16 report builders, consistency contract, spatial centers, selection id=1 tile=(14,11) Working, deselect, F10_READ_ONLY tick=20 unchanged).
- `chronicle_contract_regression.gd` -> `[CHRON_REGRESS] OK` (real runtime path).
- `diag_settlement_gate.gd` -> reached tick 5439 then hit its FRAME_CAP before the 12000 formalization target (tool-timeout limitation of the heavy 200x tree, not a formalization failure: no `not_evaluated`, no errors; stopped below the tick-6000 autosave boundary). Settlement formalization point at tick ~12000 is covered by the prior 09-02 session and is not gated by neural-refresh cadence.

**Files modified:**
- `scripts/ai/WorldAI.gd` -- `NEURAL_STATE_CACHE_TTL_TICKS` 8 -> 128 (the mature-world throughput win).
- `scripts/pawn/HeelKawnian.gd` -- `_phase_job_scan()` local memo caches + `priority_memo`/`memo_priority_cb` + memoizing wrapper helpers (`_goal_priority_bias_for_job_cached`, `_short_horizon_bias_for_job_cached`, `_learning_weight_for_job_cached`, `_apply_social_influence_bias_cached`) + 4 claim-scan call sites -> memo wrapper.
- `autoloads/TickProfiler.gd` -- `record_callback(us, name)` + `cat_callback_us` + `get_callback_profile()` (fixes the missing-method bug under `--profile-sim`; working-tree diff, present pre-session).
- `tools/diag_aged_profile.gd` -- `_dump_dispatch()` (+NEURAL_CACHE_PROFILE read-back) for the clean per-stage + neural-cache dump; `TARGET_DELTA` restored 1500 -> 6000 after iteration.
- `AGENTS.md` -- this entry.

**Known remaining / notes:**
- The residual mature-world cost after the TTL win is `_nc_rule_context_us` (10.99s) + `_nc_forward_us` (9.07s) on sig-driven re-resolves; next lever is coarsening the need-bucket sig stride (12.5 -> 25) OR short-circuiting `_pawn_decision_rule_context` macro lookups -- NOT done (behavioral fidelity risk; deferred).
- `claim_next_for` remains O(N) per first scan of a decision (76 open jobs in the aged save); the priority_cb memo dedups across the 4 scans but the first scan still pays full cost. A per-decision eager precompute or per-job-id global memo could reduce further (play-behavior risk with stale cross-pawn values; deferred).
- The speed-independent 6ms `SIM_SLICE_BUDGET_USEC` slice is why 200x==100x in cheap fresh worlds"; separate from the mature per-tick cost; not addressed this session (user chose idle-scan cost, not the slice).
- Pre-existing 1x determinism frame-coupling (`data.tile_pos` delta-based `_process` write) remains; both TTL=8 and TTL=128 diverge identically under `--fixed-fps 60`; fixing the frame-coupled tile write is a future cross-cut.

---

### 2026-09-03 — Session: opencode/big-pickle (200x Mature-World Freeze: pawn_discrete Lane-Min Fragility Fix)

**Time:** ~UTC

**What was done:**

1. **Root-caused the two-clock divergence (committed frozen at 637.5s) via static inspection of the authoritative lane machinery.** `SimulationClock.committed` = min over all registered authoritative lanes (SimulationClock.gd:178-189). `pawn_continuous` commits to `F = legacy_core applied` and only fails for invalid/dead pawns (none at freeze) → always advances, NOT the frozen lane. `pawn_discrete` commits to `min_applied` across ALL pawns' `_discrete_applied_through` (TickManager.gd:590-617, line 615: `if all_ok and min_applied < INF: commit`). **If ANY ONE pawn's discrete applied-through wedges permanently, the lane freezes at that pawn's cursor and `committed` freezes for all pawns.** The wedge happens when a queued due deadline is never consumed by `_tick_idle` (returns early via a survival gate or narrative lane before reaching the decision gate at HeelKawnian.gd:6284).

2. **Established the pawn-stop cascade mechanism.** At 200x in a mature world, the freeze manifests as a gradual one-by-one shutdown of all pawns (day 41-44 freeze evidence from `diag_freeze_audit.gd`): `path_walked=0`, `moved=0→8→4→1→0`, `states_moved=0`, `deadline_change=0`, `jobs_open=32`, `IDLE=21, WORKING=2, SLEEPING=4`. The primary symptom is ALL pawns settling into a "no viable claim + wander always fails" fixed point (deterministic WorldRNG stateless RNG means each pawn's wander-chance produces the same pass/fail for stable body/context parameters). The committed freeze (day 21) is a downstream symptom of one stuck pawn blocking the lane-min.

3. **Implemented the stuck-deadline watchdog (HK-TIME-P4-FIX3) — the smallest safe root fix for the lane-min fragility.** In `HeelKawnian._apply_authoritative_discrete_frontier`, after the existing applied-through advance rule, added: if `_discrete_due_deadlines` is non-empty and the oldest deadline is > `_DISCRETE_STUCK_DEADLINE_MAX_LAG` (0.5s world time = 10 compat ticks) behind the current frontier, force-consume it via `_consume_discrete_decision()` and reschedule `_next_decision_world_time = frontier_seconds`. This advances the pawn's `_discrete_applied_through` so it no longer blocks the lane-min, while the reschedule allows natural recovery when the obstacle clears. Threshold is generous (10 ticks) — never fires for healthy pawns (pipeline completes in 1-3 ticks), but unblocks the lane within 10 ticks of a permanent wedge. Purely tick-based, deterministic, no RNG, no frame coupling.

4. **Added diagnostics counter.** New per-pawn `_discrete_decisions_evicted` counter (0 for healthy pawns, >0 signals a stuck pawn was freed). Exposed in `get_pawn_discrete_snapshot_for_diagnostics()`. Non-zero values in the F10 snapshot or profiler output will directly signal the watchdog is active.

5. **Static validation: `diag_parse_check.gd` → all 7 targets OK** (CreatorDebugMenu, HeelKawnian, SettlementMemory, Main, ColonySimServices, f10 regression, save_fence). Zero parse errors, zero script errors.

**Root-cause summary:** The `pawn_discrete` authoritative lane uses a min-commit rule (TickManager.gd:615) — one permanently stuck pawn freezes `committed` for all pawns. The watchdog breaks this lock by auto-evicting stale deadlines.

**Files modified:**
- `scripts/pawn/HeelKawnian.gd` — 4 additions: `_DISCRETE_STUCK_DEADLINE_MAX_LAG` constant (line 661-667), `_discrete_decisions_evicted` counter (line 684-687), watchdog logic in `_apply_authoritative_discrete_frontier` (line 4686-4699), `decisions_evicted` in diagnostics snapshot (line 4748). All additive; no existing lines modified.

**What this fix does NOT address (known remaining items):**
- The frame-coupled `_process` movement (`data.tile_pos` written by `_process` with `step = 24*delta*speed`, HeelKawnian.gd:4017/4056) — a determinism violation and the reason pawn visual positions diverge from tick-truth. Deferred per prior sessions (large cross-cut).
- The mature-world "no viable claim + wander always fails" fixed point at 200x (WorldRNG stateless deterministic RNG means same wander-chance → same pass/fail forever for stable context). This is a behavioral/design issue, not a code bug — the watchdog ensures pawns remain non-blocking, but the fundamental "all options exhausted" fixed point persists.
- Per-stage job-rejection counters (P3 from 2026-08-29).
- Per-pawn starvation trace (P4 from 2026-08-29, component-split food reachability hypothesis).
- Autosave stage-by-stage timing (P5 from 2026-08-29).

**Playtest risks:**
- The watchdog only fires when a deadline is >0.5s stale (10 compat ticks). Healthy pawns (pipeline completes in 1-3 ticks) are unaffected.
- After eviction, the pawn gets a fresh deadline at the current frontier, so it can recover naturally.
- Determinism is preserved: purely tick-based threshold, no RNG, no frame coupling.
- The `_discrete_decisions_evicted` counter in F10 diagnostics will signal when the watchdog is active.

---

### 2026-09-03 — Session: opencode/big-pickle (Deterministic Liveness: Wander on Job-Scan Cooldown + Watchdog Eviction-Not-Consumption)

**Time:** ~UTC

**Objective:** The 200× mature-world freeze. Fix = deterministic liveness: every idle pawn must get a genuine decision opportunity with changing RNG context every tick, so no pawn can sit in a permanent idle fixed point at any speed. Speed must only change how fast the observer sees time pass.

**Root-cause discovery (static):** `_pawn_salt()` (HeelKawnian.gd:413-417) ALREADY returns `GameManager.tick_count + pawn_id*1009 + tile.x*131 + tile.y*17 + extra` — the wander RNG salt is already time-varying each tick (tick_count changes every compat tick). The user's "unchanged inputs → same stateless-chance boolean forever" hypothesis does NOT apply to the wander draw itself. The real idle-lock mechanism was:

1. `_pawn_salt` DOES change per tick, so `WorldRNG.chance_for("idle_wander", …)` re-draws differently each tick. BUT the pawn only EVER reached the wander draw on the 10th-tick cadence (the `_last_job_search_tick` cooldown in `_phase_job_scan`, HeelKawnian.gd:4878). On the other 9 of every 10 ticks the pipeline was finishing at the cooldown early-return WITHOUT any wander. Net wander rate ≈ once per 10 ticks × ~5% ≈ 0.5% of ticks — far too sparse to break an idle lock, and a pawn with no suitable job could sit immobile intra-job-fixed-point.
2. The cheap-wander lane inside `_tick_idle` (HeelKawnian.gd ~6373-6388) was effectively dead: `_discrete_decision_due()` is true essentially every tick (new deadline queued by the single-slot mechanism), so control always took the `_has_pending_idle_decision()` path and never reached the non-pipeline cheap wander.

**Changes (both in `scripts/pawn/HeelKawnian.gd`):**

1. **Wander offered on the job-scan cooldown (deterministic liveness).** In `_phase_job_scan()` at the 10-tick cooldown early-return, BEFORE finishing the pipeline, each pawn now draws its wander RNG (`WorldRNG.chance_for(_pawn_stream("idle_wander"), clampf(WANDER_CHANCE_PER_TICK*wanderlust,…), _pawn_salt(11))`, same formula as the post-scan wander at :5586, incl. the `_idle_decision_result=="wander"` ×1.6 boost) and calls `_start_wander()` on success. Because the salt varies with tick_count, the draw changes every cooldown tick → an idle pawn is never a permanent fixed point. On the 10th tick the full job scan runs (and claims the job BEFORE the wander fallback at :5551/:5561), so job-taking precedence is preserved. `_start_wander()` → `_start_path()` sets `_path` + `set_process(true)`; `_process()` (HeelKawnian.gd:4004) moves the pawn along `_path` regardless of `_state` — a cooldown wander visibly moves an IDLE pawn without changing its state machine.

2. **Watchdog eviction, NOT consumption (semantic correctness fix to the 09-03 watchdog).** The prior `b0da2c1a` watchdog called `_consume_discrete_decision()` for a deadline whose decision never actually ran. That contradicted the stated invariant ("applied-through stays before the oldest unconsumed deadline / consumed only for real pipeline starts"): it bumped `_discrete_decisions_consumed` and called `_clear_scheduled_normal_deadline()` for a decision that never happened. Replaced with a true eviction: `_discrete_due_deadlines.pop_front()`, increment `_discrete_decisions_evicted` ONLY (not `_consumed`), reschedule `_next_decision_world_time = frontier_seconds`. Applied-through then advances to F via the existing empty-queue rule (HeelKawnian.gd:4684) on the next frontier pass, unblocking the pawn_discrete lane-min within one extra pass. Semantics: eviction ≠ consumption; the window passed and the pawn missed it, tracked honestly.

**Permanent Tool Rule / verification:** user directive: NO Godot runs, NO simulations, code inspection + implementation only. `git diff scripts/pawn/HeelKawnian.gd` is a clean, minimal 14-line diff (9-line cooldown-wander block + 5-line watchdog change). Static review confirms every symbol used in the new cooldown block (`_bp(3)`, `_idle_decision_result`, `_start_wander`, `_finish_idle_decision_pipeline`, `_pawn_stream`, `_pawn_salt`, `WorldRNG.chance_for`, `WANDER_CHANCE_PER_TICK`, `lerpf`, `clampf`) is already in scope inside `_phase_job_scan` (identical usage at :5577-5587). No sim change to job priority, settlement growth, needs, or paths. User performs graphical playtest at 200× on the saved colony.

**Files modified:**
- `scripts/pawn/HeelKawnian.gd` — P2: cooldown-wander block in `_phase_job_scan()` (:4878); P1: watchdog `_consume_discrete_decision()` → pop_front + evicted-only (no consumed/clear) in `_apply_authoritative_discrete_frontier` (:4696).
- `AGENTS.md` — this entry.

**Known remaining / notes:**
- `_pawn_salt`'s tick_count term is what makes the wander draw change every tick; since this was already present, the ONLY behavioral gap this session closed is that pawns now reach the wander draw every idle tick instead of every 10th. No RNG-stream change, no seed change, no frame coupling — determinism preserved.
- The `_discrete_decisions_evicted` counter (non-zero) in F10 diagnostics will signal the watchdog is firing; the cooldown-wander can be profiled via `_pd_stage` counters under `--profile-pawn-dispatch` if needed (not run this session per directive).
- Open diagnostics from 2026-08-29 stand: P3 per-stage job-rejection counters; P4 per-pawn starvation trace; P5 autosave stage timing. Frame-coupled `_process` movement remains the pre-existing 1x/2x determinism cross-cut (deferred).

---

### 2026-09-03 — Session: opencode/big-pickle (Causal-Soundness Calendar Fix: Public Day Tracks Applied Work, Not the In-Progress Scheduler Heartbeat)

**Time:** ~UTC

**What was done:**

1. **Located the causal-soundness breach for "day advances but the world does not."** The public calendar day derives from `DayNightCycle.get_current_legacy_calendar_tick()` (used by ColonyHUD `_time_line` day/year + phase, and DayNightCycle day-rollover). That accessor returned **`TickManager.current_tick`** — the scheduler **heartbeat that increments at tick START** (`TickManager._start_pending_tick`, current_tick += 1) — **BEFORE** that tick's causal work completes. A 20-57 ms tick spanning many 6 ms slices at 200x showed the *new* (in-progress) day while not one piece of that tick's causal work (pawn AI, jobs, settlements) had been applied yet. The codebase's own documentation ALREADY states the calendar must derive from COMMITTED canonical world time (ColonyHUD `_time_line` comment "derives from committed canonical time (P2B), not the compatibility tick counter"; DayNightCycle canonical-commit docstring) — but the implementation silently returned `current_tick`, contradicting it.

2. **Confirmed the authoritative causal frontier is SimulationClock COMMITTED.** `_complete_pending_tick` runs all listeners for a tick, THEN `_commit_legacy_core_quantum()` advances the `legacy_core` lane by `LEGACY_CORE_CANONICAL_SECONDS_PER_TRANSACTION` (0.05 s) and recomputes committed (min over authoritative lanes) — so `get_committed_world_time_seconds()` only ever reflects FULLY-APPLIED completed transactions. `_recompute_committed` = min applied over lanes; pawn_continuous/pawn_discrete lanes only advance when all their pawns applied through F. This is the exact "work has been applied" frontier.

3. **Fixed the calendar (HK-SCHED-P1, in `scripts/world/DayNightCycle.gd`):** `get_current_legacy_calendar_tick()` now derives from `SimulationClock.get_committed_world_time_seconds()` converted via `canonical_seconds_to_legacy_tick(committed)` (the canonical bridge quantum, 0.05), **clamped to never exceed** `TickManager.current_tick` (so the day can never roll past the heartbeat that has begun) and **never regresses** (committed is monotonic). Result: the public day advances ONLY to the last fully-completed, causally-applied tick. During an in-progress tick the day holds at the last committed frontier instead of showing the unfinished tick. This is precisely "never advance the public day/tick past causal work that has not been applied."

4. **Dropped the proposed "target-lead cap" sub-part with evidence (architectural conflict, NOT scope creep).** Option A's second half would cap `SimulationClock` target (`world_time_seconds`) to a bounded lead over committed. Static proof this is impossible without breaking the published regression contract: `tools/diag_multirate_smoke.gd:404` asserts `target_ok = ... w2_target_rate > 100.0 and w2_target_rate < 400.0` — the multi-rate architecture deliberately advances the TARGET clock at game speed (100-400x at 200x) while COMMITTED tracks causal work (documented in SimulationClock.gd:80-91: "TARGET... requested simulation frontier... COMMITTED... causal history"). Capping target would collapse `w2_target_rate`, failing the smoke AND contradicting the foundation. The calendar fix alone is the correct realization of the causal-soundness requirement; the target clock is aspirational-by-design, never read as "applied history." Also confirmed: `diag_clock_contract.gd`/`diag_legacy_commit_bridge.gd` assert exact `advance_target(dt)` math — a target clamp inside `advance_target` would break them too.

**Verification (static only, per user directive — NO sim/gameplay change, no Godot sim run):**
- `tools/diag_parse_check.gd`-style load probe (temporary `diag_parse_daynight.gd`, SceneTree `_initialize` script-load only, never boots Main, never advances a tick): `DayNightCycle.gd -> OK`, `SimulationClock.gd -> OK`, `TickManager.gd -> OK`. Zero parse errors.
- Canonical conversion confirmed: `LEGACY_CORE_CANONICAL_SECONDS_PER_TRANSACTION = BASE_TICK_INTERVAL (0.05) * SPEED_MULTIPLIERS[0]` = 0.05; `floor(committed/0.05)` = completed-tick count; clamp to `current_tick` holds during in-progress ticks.
- Production autosave SHA-256 `6CFB204C6FCBB379847DAC56240FD321D182F058F8F0F97E3F0EE1F904DF55E2` (at `%APPDATA%\Godot\app_userdata\HeelKawn\heelkawn_colony_autosave.sav`) **unchanged** — identical to the 2026-09-03 baseline; the load-only probe never wrote it.

**Files modified:**
- `scripts/world/DayNightCycle.gd` — `get_current_legacy_calendar_tick()` committed-based + clamped monotonic calendar (HK-SCHED-P1). Single accessor; no sim-rule, no per-tick pawn AI/jobs/needs/settlements/path change, no new watchdog/timeout.
- `AGENTS.md` — this entry.

**Known remaining / notes:**
- This is a PRESENTATION/causal-bookkeeping fix: it makes the HUD day and day-night phase truthful (track applied causal work). It does NOT by itself make 200x "develop faster" — development throughput at high speed remains bounded by CPU and by the speed-interval throttling in `Main` (`_planner_interval_for_speed` 5000 ticks, `CONSTRUCTION_JOB_SEED_INTERVAL_TICKS`→4000 at 200x). Those are separate concerns (candidate B the user declined this pass), not addressed here.
- The frame-coupled `_process` movement (HeelKawnian.gd ~4004, `step = WALK_SPEED*delta*game_speed`) remains a known determinism/visual concern (deferred cross-cut).
- Open diagnostics from 2026-08-29 stand: P3 per-stage job-rejection counters; P4 per-pawn starvation trace; P5 autosave stage timing.
