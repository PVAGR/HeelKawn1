# HeelKawn1 — Codebase Overview & Developer Guide (Explore Mode, Partial Scan)

## Summary
HeelKawn1 is a **deterministic Godot 4.6 2D world simulation** driven by discrete **simulation ticks**. The “kernel” is built from an **append-only fact log** (`autoloads/WorldMemory.gd`) plus **derived interpretation layers** (`autoloads/WorldMeaning.gd`) and additional deterministic overlays (persistence, culture, myth, sacred, etc.). The main playable experience is primarily **observer/chronicler** in spectator mode, while “incarnated” mode routes the player’s inputs through the **same pawn/job systems** used by NPCs.

> Note: In this Explore session I did not finish scanning every subsystem file (e.g., `SettlementMemory.gd`, `WorldPersistence.gd`, `PathFinder.gd`, pawn AI internals, etc.). This report is therefore **accurate for the files inspected** and includes a clear “next investigations” list for the rest.

---

## Architecture

### Primary pattern: tick-driven orchestration + layered state (facts → derived meaning → persistence/visuals)
- **Execution loop** is centralized around `autoloads/GameManager.gd` emitting `game_tick(tick_count)` once per simulation tick.
- **Main scene** (`scenes/main/Main.gd`) attaches to that signal and performs:
  - UI/input routing (player intent dispatch, inspector snapshots),
  - maintenance tick work (regrowth, social rapport, mining “react”),
  - planning updates (settlement and trade planners at intervals),
  - deferred “kernel derivative” recomputation when `WorldMemory` has new facts.
- **Kernel data model**:
  1. **Facts**: `WorldMemory` stores events/facts in an append-only array (with indices).
  2. **Derived meaning**: `WorldMeaning.recompute()` aggregates those facts into `meaning_by_region`, plus derived settlement/bloodline/period meanings.
  3. **Persistence + visuals**: `World` uses `WorldPersistence`, `RemnantMemory`, and “player meaning tint” to render scar/abandonment/revival posture.

### Technology stack
- **Language/runtime**: GDScript on **Godot 4.6**
- **Core runtime**: Godot autoload singletons from `project.godot`
- **Sim architecture**: signal-driven tick loop + explicit tick pacing caps in `GameManager`

### How execution starts
1. Godot launches with `run/main_scene = "res://scenes/main/Main.tscn"` (in `project.godot`).
2. Autoloads initialize (e.g., `GameManager`, `WorldMemory`, `WorldMeaning`, `WorldClock`, etc.).
3. The `World` node generates the initial map in `World._ready()` and renders it.
4. `Main._ready()` connects `GameManager.game_tick` and calls `_bootstrap_colony()` to:
   - pick main passable component,
   - place seed stockpile,
   - spawn starter pawns (restricted to that component),
   - apply persistence-derived ruins, sync culture and myth layers,
   - seed/plan jobs and spawn animals.

---

## Directory Structure (meaningful subset)

```text
project-root/
├─ scenes/
│  └─ main/                      — Player/spectator/creator bootstrap + per-tick orchestration
│     └─ Main.gd
│
├─ scenes/world/                 — World node (rendering + tile feature mutation)
│  └─ World.gd
│
├─ autoloads/                     — Kernel-adjacent singletons + persistence/identity/memory layers
│  ├─ GameManager.gd              — tick loop + speed tiers
│  ├─ WorldMemory.gd             — append-only fact log
│  ├─ WorldMeaning.gd           — derived interpretation (recompute from WorldMemory)
│  ├─ ObservationAPI.gd         — programmatic Focus Inspector (read-only)
│  ├─ CommandAPI.gd             — unified command validation/execution
│  ├─ JobManager.gd             — global job queue (open/claimed)
│  └─ StockpileManager.gd      — global stockpile zones registry + queries
│  └─ (plus many additional autoloads not fully scanned yet)
│
└─ scripts/
   ├─ pawn/                      — PawnSpawner + PawnData (pawn state & save)
   │  ├─ PawnSpawner.gd
   │  └─ PawnData.gd
   └─ (other systems: planners, kernel exports, etc.)
```

---

## Key Abstractions (files inspected)

### GameManager — tick pacing + deterministic “single source of time”
- **File**: `autoloads/GameManager.gd` (line ~1)
- **Responsibility**:
  - Owns the simulation clock (`tick_count`) and controls:
    - speed tier selection (`SPEED_STEPS`)
    - pause/resume
    - per-frame tick caps (`MAX_TICKS_PER_FRAME_*`) and accumulator caps
  - Emits the only sim-loop signal: `game_tick(tick_count)`
- **Interface**:
  - `signal game_tick(tick_count)`
  - `signal speed_changed(new_speed, is_paused)`
  - `set_speed_index(i)`, `toggle_pause()`, `set_state_from_load(tick, speed, paused)`
- **Lifecycle**:
  - Autoload singleton; begins running in SceneTree startup
- **Used by**:
  - `Main.gd` listens to `game_tick` for orchestration
  - UI listens to `speed_changed`
  - Any “tick-scheduled” worker systems

**Non-obvious design meaning**: The game avoids frame-dependent logic by ensuring *all simulation systems should listen to* `game_tick` and not `_process`. The speed tier caps prevent “catch-up storms” from turning a stall into a frozen UI.

---

### Main — orchestration brain + player routing + intervalized expensive work
- **File**: `scenes/main/Main.gd`
- **Responsibility**:
  - Connects to `GameManager.game_tick` and runs `_on_game_tick(tick)`
  - Routes player intent from `PlayerIntentQueue` into selection/incarnation focus
  - Bootstraps the colony and seeds initial jobs/features
  - Performs deterministic maintenance work on cadence:
    - regrowth
    - mining-react scanning
    - social rapport accumulation (speed-interval adaptive)
    - generational pawn turnover
    - settlement memory recompute/update
  - Defers expensive “world derivative” recompute until `WorldMemory` is dirty
- **Notable subsystems inside Main**:
  - `_bootstrap_colony()` and `_bootstrap_heavy_phase2*()`:
    - spreads O(N) work across deferred calls to avoid startup stutter
  - `_flush_world_memory_derivatives()`:
    - calls `WorldMeaning.recompute()`, `WorldPersistence.recompute()`, then culture/myth/sacred sync
- **Interface highlights**:
  - `var PlayerMode { SPECTATOR, INCARNATED }`
  - `request_incarnation_entry()`, `request_spectator_return()`
  - `get_camera_settlement_revival_digest()` and camera meaning logic (read-only)
  - Many debug hotkeys and export functions (e.g., chronicle export)

**Non-obvious design meaning**:
- Main aggressively **rate-limits expensive scans** using:
  - `*_high_speed_interval()` helpers
  - tick modulus scheduling (e.g., regrowth, planners, rebirth checks)
  - “deferred flush” flags like `_world_memory_derivative_flush_queued`
- This is essential because determinism still requires performance: at high speeds it would otherwise do too much per frame.

---

### World — tile world generation, render patching, and tile feature mutation
- **File**: `scenes/world/World.gd`
- **Responsibility**:
  - Owns the world’s **rendered tile texture** and updates it in-place
  - Owns A* reachability data via `PathFinder` and connected components
  - Provides deterministic mutation operations:
    - `build_wall()`, `build_door()`, `mine_out_wall()`, `set_feature()`, `clear_feature()`
  - Maintains a fast, non-tile-scanning bed reservation model:
    - `_bed_tiles`, `_bed_occupants`
- **Interface** (inspected):
  - Rendering:
    - `_render()`, `refresh_terrain_scar_tint()`, `refresh_pawn_historic_path_weights()`
  - Mutation:
    - `apply_ruins_from_persistence()`
    - `reserve_bed() / release_bed() / find_free_bed_for()`
    - `build_wall()`, `build_door()`, `mine_out_wall()`
- **Lifecycle**:
  - In `World._ready()`: sets up sprite and calls `generate(_initial_world_seed())`

**Non-obvious design meaning**:
- Visual “scar tint” and “player meaning tint” are computed during rasterization and can be refreshed without regenerating the world.
- Bed reservation is a separate model from tile features: the bed tile feature exists, but “who is currently sleeping / walking to it” is maintained in `_bed_occupants` for performance and correctness.

---

### WorldMemory — append-only fact log + deterministic query surfaces
- **File**: `autoloads/WorldMemory.gd`
- **Responsibility**:
  - Stores world facts as an append-only list `_events: Array[Dictionary]`
  - Normalizes event payloads:
    - ensures `t` (tick), `s` schema, `type` canonical string
    - assigns monotonic `eid`
    - records `severity` and region index `r` when available
  - Maintains indexes for performance:
    - `_event_type_counts`, `_first_event_tick_by_type`
    - `_pawn_death_last_tick_by_region`
- **Interface highlights**:
  - `record_event(e: Dictionary)`
  - typed record helpers:
    - `record_pawn_death()`, `record_animal_death()`, `record_enemy_death()`, `record_starvation_event()`, etc.
  - derivatives:
    - `to_save_dict()`, `from_save_dict()`
    - `consume_dirty()` and `event_count()`
  - export/read:
    - `get_recent_events(count)`
    - `get_events_page_newest(...)`
    - `get_events_for_tile(tile_pos)`
    - `get_zone_aggregate(zone_id)` (used by WorldMeaning tags)
    - `get_history_export_string(anonymize_subjects)`
- **Lifecycle**:
  - Autoload singleton; cleared on reroll and rebuilds indexes in `from_save_dict`

**Non-obvious design meaning**:
- The kernel’s determinism and auditability hinge on “facts first”: `WorldMeaning` recomputes entirely from `WorldMemory` rather than incremental “meaning patches”.
- `MAX_EVENTS` and rotation ensure the log doesn’t explode; the kernel trades deep tail retention for runtime stability.

---

### WorldMeaning — derived interpretations recomputed from WorldMemory only
- **File**: `autoloads/WorldMeaning.gd`
- **Responsibility**:
  - Phase 2.2 derived meaning:
    - `meaning_by_region` aggregates death/build/fire/starvation/teaching/migration counts
    - assigns labels (`quiet/scarred/bloodied/grave`) and tags
    - also derives settlement, bloodline, and time period meanings
- **Interface**:
  - `recompute()` — clears and rebuilds meaning tables from `WorldMemory.to_save_dict().get("events", [])`
  - `get_region_meaning(region_key)`, `get_region_meaning_label(region_key)`
  - `get_cultural_style(region_key)` and `get_wildlife_trend(region_key)` (via tags)
  - `get_zone_tags(zone_id_string)`
- **Used by**:
  - `Main` (meaning ambiance + kernel/overlay UI)
  - `ObservationAPI` settlement/region enrichment
  - `World` raster tint logic (region meaning label drives visual tint for abandoned/revivable posture)

**Non-obvious design meaning**:
- `WorldMeaning` is “read-only derived state”. The code explicitly states it should not write to `WorldMemory`, and recompute is triggered only when `WorldMemory` becomes dirty (via Main’s deferred flush).

---

### ObservationAPI — read-only “programmatic Focus Inspector”
- **File**: `autoloads/ObservationAPI.gd`
- **Responsibility**:
  - Provides on-demand observation dictionaries for:
    - a pawn (`observe_pawn`)
    - a tile (`observe_tile`)
    - a settlement/region (`observe_settlement`, `observe_region`, `observe_region_lite`)
    - the current camera view (`observe_camera_view`)
  - Builds “Focus Inspector parity” snapshots for external agents via:
    - `build_focus_snapshot_from_focus(focus, tick)`
- **Performance contract** (explicitly documented):
  - Don’t call from `_process` every frame
  - Prefer `observe_region_lite` for cheap cadence hooks
- **Used by**:
  - `Main` focus inspector snapshotting (indirectly; Main uses internal snapshot-building too)
  - `CommandAPI.validate_command()` and AI/tooling

---

### CommandAPI — unified action bus with validation
- **File**: `autoloads/CommandAPI.gd`
- **Responsibility**:
  - Defines a generic command representation with validation and execution:
    - MOVE_PAWN, CLAIM_JOB, INSPECT_TILE, PERFORM_PRESENCE, TOGGLE_DRAFT_MODE, REQUEST_INCARNATION, RETURN_TO_SPECTATOR
  - Centralizes “can we do this?” checks using `ObservationAPI` (actor validity, walkability, job eligibility)
- **Key design detail**:
  - “Tile designation” is explicitly player-only at present:
    - `_execute_designate_tile()` returns an error (“Tile designation is player-only feature”)
- **Used by**:
  - Future AI agents (“same validation path as UI” goal)
  - Currently used by Main’s intention routing patterns indirectly (Main owns UI state; CommandAPI is designed for agent integration)

---

### PawnSpawner — deterministic colony seeding + generational spawn
- **File**: `scripts/pawn/PawnSpawner.gd`
- **Responsibility**:
  - Spawns initial colony pawns restricted to a connected component
  - Spawns generational pawns for turnover (`spawn_generational_pawn`)
  - Integrates with `/root/KinshipSystem` (adding people + parent/household relationships)
- **Determinism mechanism**:
  - Uses `WorldRNG.rng_for(...)` for seeded RNG streams in `spawn_starters`
  - Uses purely deterministic formulas in `spawn_generational_pawn` (no RNG)
- **Used by**:
  - `Main._bootstrap_colony()` and `_maybe_generational_turnover()`

---

### JobManager — global job queue (open + claimed) with job selection bias
- **File**: `autoloads/JobManager.gd`
- **Responsibility**:
  - Maintains:
    - `_open` (unclaimed jobs)
    - `_claimed` (jobs assigned to pawns)
    - `_jobs_by_tile` (prevents duplicate jobs on same tile)
  - Allows posting:
    - `post(type, tile, priority, work_ticks)`
    - `post_trade_haul(...)`
  - Allows claiming:
    - `claim_next_for(pawn, filter, priority_bonus)`
    - `claim_by_id_for(pawn, job_id)`
  - Notifies WorldAI when jobs complete:
    - `_notify_world_ai_job_completion(job)` calls `WorldAI.on_job_completed(...)` if available
- **Non-obvious design meaning**:
  - The job selection “eff” is computed as:
    - `adjusted_priority + optional bonus`
    - with distance tie-break on `Chebyshev` distance to `pawn_tile → job.work_tile`
  - The selection pipeline is shaped by an **obedience weight** from `WorldAI` if `WorldAI` exists.

---

### StockpileManager — registry + nearest-zone queries for hauling/eating/building
- **File**: `autoloads/StockpileManager.gd`
- **Responsibility**:
  - Tracks all stockpile zones in `_zones`
  - Provides:
    - inventory aggregation (`aggregate_inventory_totals`)
    - pressure snapshot proxies (`labor_pressure_stock_snapshot`)
    - nearest eligible zone queries:
      - `find_food_source(from_tile, pathfinder)`
      - `find_source_for(item_type, qty, from_tile, pathfinder)`
      - `find_drop_zone(item_type, from_tile, pathfinder)`
- **Used by**:
  - Pawn logic (eating, harvesting, build material fetching)
  - Main job seeding assumptions (seed stockpile placement)
  - Regrowth system uses `JobManager` and pathfinder reachability

---

### PawnData — pawn “source of truth” including save/load, personality, skills
- **File**: `scripts/pawn/PawnData.gd`
- **Responsibility**:
  - Pure data model for pawn identity, needs, skills, skills trees, traits, family/social structures, and save/load payloads
  - Implements deterministic personality → neural network initialization based on `WorldRNG`
  - Provides job-eligibility gating via `allows_job_type(job_type)`
- **Key persistence**:
  - `to_save_dict()` / `from_save_dict()` includes:
    - identity: `id`, `unique_id`, `lineage_id`
    - needs: hunger/rest/mood/health/max_health
    - skills and profession gating
    - work allow flags, traits
    - social rapport and opinions
    - neural network state (restored via `PawnData.create_neural_network(...).from_dict(nn_data)`)
- **Non-obvious design meaning**:
  - Save/load is “PawnData first”: even if `Pawn` node is freed/respawned, the simulation is intended to restore pawn state from `PawnData`.

---

## Data Flow (concrete “tick” path)

1. **Bootstrap / generation**
   1) `World._ready()` generates map and pathfinder data.
   2) `Main._bootstrap_colony()`:
      - chooses main component,
      - recomputes `WorldMeaning` + `WorldPersistence`,
      - places seed `Stockpile`,
      - spawns starter pawns (`PawnSpawner.spawn_starters`),
      - applies ruins from persistence (`World.apply_ruins_from_persistence()`),
      - recomputes cultural/myth/sacred layers,
      - plans: `SettlementPlanner.plan`, `TradePlanner.plan`
      - spawns animals.

2. **Tick loop**
   1) `GameManager` advances accumulator and emits `game_tick` with `tick_count`.
   2) `Main._on_game_tick(tick)` runs:
      - player intent dispatch (`PlayerIntentQueue`)
      - meaning ambiance updates
      - stabilization-gated hunt job posting
      - animal population update on cadence
      - regrowth processing (`_process_regrowth`) via due-tick buckets with budgets
      - enemy AI tick
      - deferred kernel derivative recompute when `WorldMemory.consume_dirty()` becomes true
      - planning updates at rate-limited intervals
      - rebirth and settlement architect passes on periodic boundaries
      - mining-react incremental scanning with a work budget

3. **Job lifecycle and fact recording**
   1) Systems post jobs into `JobManager`.
   2) Pawns claim jobs (job selection uses `JobManager.claim_next_for` and distance tie-break).
   3) On job completion, `Main._on_job_completed(job)` writes kernel facts into `WorldMemory`:
      - `job_completed`
      - `structure_built` / `cooperative_build`
      - `WorldMemory.record_event(...)` for labor results
   4) `JobManager.complete(job)` triggers `WorldAI.on_job_completed(...)` if `WorldAI` is present.
   5) Next time derivatives flush, `WorldMeaning.recompute()` derives region/settlement meaning from those new facts.

---

## Non-Obvious Behaviors & Design Decisions (what will surprise a new dev)

1. **Meaning is computational, not scripted**
   - `WorldMeaning.recompute()` derives meaning purely from `WorldMemory` event facts.
   - Visuals use derived meaning labels (and settlement state hysersesis/tints), but the kernel never “pretends” meaning is authoritative without facts.

2. **Expensive work is intervalized and speed-adaptive**
   - Main uses many `*_interval_for_speed` helpers and tick modulus scheduling.
   - At high speeds, the sim changes cadence rather than doing the same work every tick.

3. **WorldMemory derivatives flush is deferred and coalesced**
   - Main avoids calling `WorldMeaning.recompute()` too frequently by:
     - checking `_world_memory_derivative_flush_queued`
     - only recomputing on a cadence
     - using deferred calls so pawns can record first

4. **Regrowth and mining-react are explicitly “budgeted”**
   - Regrowth:
     - uses due-tick buckets and per-tick restore budgets to avoid one-tick spikes.
   - Mining-react:
     - scans only a number of rows per tick and stops when budget is exhausted.

5. **Bed reservation is a separate correctness model**
   - Beds are tile features, but reservation is stored in `World`’s `_bed_occupants` dictionary so two pawns can’t “race” sleeping on the same bed.

6. **CommandAPI is the intended bridge for multi-agent tooling**
   - Although UI exists today, `CommandAPI` was built to enable AI agents to act via the same validation logic.
   - Some commands are still explicitly restricted (tile designation player-only).

7. **There appears to be a missing/renamed WorldAI file**
   - `project.godot` references `WorldAI="*res://scripts/ai/WorldAI.gd"` but I saw an error when reading `autoloads/WorldAI.gd`.
   - This suggests either:
     - the file is under `scripts/ai/WorldAI.gd` (not `autoloads/WorldAI.gd`),
     - or the integration differs from the README snapshot.
   - New dev should verify `scripts/ai/WorldAI.gd` existence and confirm contracts like `get_pawn_obedience_weight()` and `on_job_completed()`.

---

## Module Reference (one-liners for inspected modules)

| File | Purpose |
|---|---|
| `autoloads/GameManager.gd` | Tick clock, speed tiers, and `game_tick` dispatch pacing |
| `scenes/main/Main.gd` | Bootstraps colony + orchestrates per-tick maintenance, planning, meaning flush, and observer/incarnation UI |
| `scenes/world/World.gd` | World generation/render raster + tile feature mutation + bed reservation model |
| `autoloads/WorldMemory.gd` | Append-only deterministic world fact log + indices + exports |
| `autoloads/WorldMeaning.gd` | Derived interpretation layer recomputed from `WorldMemory` |
| `autoloads/ObservationAPI.gd` | Read-only “programmatic Focus Inspector” for agents/tools |
| `autoloads/CommandAPI.gd` | Unified command validation/execution intended for human + AI actions |
| `autoloads/JobManager.gd` | Global open/claimed job queue + claim selection logic |
| `autoloads/StockpileManager.gd` | Registry of stockpile zones + nearest-zone queries |
| `scripts/pawn/PawnSpawner.gd` | Deterministic starter/generational pawn placement |
| `scripts/pawn/PawnData.gd` | Pawn source-of-truth state + save/load + job eligibility gates |

---

## Suggested Reading Order (based on what exists in this scan)
1. `autoloads/GameManager.gd` — understand the tick contract & pacing
2. `scenes/main/Main.gd` — see the real orchestration and where facts/meaning flushes happen
3. `autoloads/WorldMemory.gd` — learn the append-only kernel data model
4. `autoloads/WorldMeaning.gd` — learn how derived meaning is recomputed
5. `scenes/world/World.gd` — learn tile mutation ops and visual overlays
6. `autoloads/ObservationAPI.gd` + `autoloads/CommandAPI.gd` — learn how AI/tooling should observe and act safely
7. `autoloads/JobManager.gd` + `autoloads/StockpileManager.gd` — learn the labor economy primitives
8. `scripts/pawn/PawnSpawner.gd` + `scripts/pawn/PawnData.gd` — learn identity, deterministic birth, and save semantics

---

## “General Prompt” for other AI models (scan + propose improvements)

Copy/paste this prompt into the other AI models (they can use repo access/tools to inspect code):

```text
You are an “HeelKawn Improvement Scout” operating on the PVAGR/HeelKawn1 canonical repo clone.

MISSION
1) Scan the repository to understand how the deterministic Godot simulation kernel works.
2) Identify where new game features can be added without violating determinism or kernel constraints.
3) Propose improvement ideas (systems, tuning, UX, and agent tooling) that specifically fit HeelKawn’s design:
   - deterministic cause/effect
   - facts first: WorldMemory is append-only
   - derived meaning: WorldMeaning recompute from facts
   - derived layers must never overwrite facts
   - UI must not dictate world truth

READ FIRST (hard requirements)
- Read AI_README.md completely and align with its non-negotiable deterministic kernel rules.
- Read docs/HEELKAWN_STATE.md for current phase and what is “in scope”.

TECHNICAL CONTRACTS TO RESPECT
- Simulation ticks: all sim logic should be scheduled off GameManager.game_tick (not per-frame _process).
- Determinism: avoid randi()/randf() in history-driving paths unless seed-driven via WorldRNG.
- Observation vs action:
  - Use autoloads/ObservationAPI.gd for read-only “what is true now”.
  - Use autoloads/CommandAPI.gd for validated actions (or ensure you route through existing job/command systems).
- Facts:
  - Only write history through WorldMemory record_* helpers or record_event() with correct schemas/fields.
- Meaning:
  - Only compute meaning in derived systems (WorldMeaning.recompute or other derived layers).
- Performance:
  - At high speed tiers, systems must be intervalized and budgeted.

WHAT TO SCAN (prioritize these files)
- scenes/main/Main.gd (boot, tick orchestration, deferred derivative flush, regrowth/mining-react/social passes)
- autoloads/GameManager.gd (tick pacing and speed tiers)
- scenes/world/World.gd (tile raster, tile mutation, pathfinder sync, bed reservation)
- autoloads/WorldMemory.gd (event schema, indices, exports)
- autoloads/WorldMeaning.gd (derived meaning rules, tags, settlement meanings)
- autoloads/JobManager.gd (job queue semantics + how pawns pick jobs)
- autoloads/StockpileManager.gd (zone registry + hauling/eating decisions)
- autoloads/ObservationAPI.gd + autoloads/CommandAPI.gd (tooling contracts for agents)
- scripts/pawn/PawnSpawner.gd + scripts/pawn/PawnData.gd (pawn identity, deterministic birth, save/load)

DELIVERABLES (output format)
A) A concise “How it works” explanation (5–10 bullet points) describing:
   - how ticks progress
   - where facts are written
   - where derived meaning is recomputed
   - how jobs/stockpiles turn into world change

B) A prioritized list of “feature improvement opportunities”
For each opportunity include:
- What to build
- Why it improves HeelKawn (ties back to themes)
- Which phase/kernel layer it belongs to
- Where in code it likely plugs in (specific file references)
- Determinism/performance risks and how to mitigate them
- Validation approach (what tests/exports to use, e.g., F10 soul bundle, WorldMemory exports)

C) An “AI agent capability map”
- What observation surfaces exist and what they return
- What actions are currently supported by CommandAPI vs not yet supported
- What additional agent tooling is missing (if any)

QUALITY BAR
- Make statements grounded in the code you inspect.
- If you can’t verify something, say “unverified” and request the file(s) needed.
- Never propose changes that violate deterministic kernel constraints.
```

---

## Next investigations (not yet completed in this Explore session)
These are high-value missing pieces to scan next:
- `autoloads/SettlementMemory.gd` (settlement states, intents, material truth/hysteresis)
- `autoloads/WorldPersistence.gd` (scar/recovery progression + persistence rules)
- `autoloads/SettlementPlanner.gd` + `scripts/kernel/settlement_identity.gd`
- `autoloads/WorldRNG.gd` and `scripts/ai/WorldAI.gd` (verify determinism + contracts)
- `PathFinder` implementation (reachability, component building, historic scar weights)
- Pawn runtime loop (`Pawn.gd`, job claiming, needs decay, starvation/hunger overrides)
- Regrowth and mining-react interactions with persistence/walls/ore tiles