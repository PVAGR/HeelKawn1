# HEELKAWN SESSION LOG

Use this file as cross-LLM handoff memory.
Each session adds one entry at the top.

---

## 2026-04-26 - Phase 7 deterministic history export + kernel diagnostic

Date: 2026-04-26
Agent/Model: Codex (Cursor)
Goal: Add tick-gated diagnostic at 30000 and runtime history export string for copy/paste auditing.

Changes made:
- Updated `autoloads/WorldMemory.gd`:
  - Added `get_history_export_string() -> String`:
    - read-only string export, no file IO.
    - includes tick/type/subject/cause/impact/provenance hash stub per event.
  - Added `_provenance_hash_stub(...)` deterministic hash helper for audit tracing.
- Added `scripts/system/KernelDiagnostic.gd`:
  - One-shot gate at `DIAGNOSTIC_TICK = 30000`.
  - Prints structured console report with:
    - memory event count + append-only check status
    - settlement state distribution
    - wildlife totals
    - player profession/xp lock status
    - determinism summary (rng-event scan + tick-locked flags)
  - Exposes `is_complete()` + `status_text()`.
- Updated `scenes/main/Main.gd`:
  - Instantiates `KernelDiagnostic` runtime node in `_ready()`.
  - Added diagnostic helper getters used by reporter/HUD:
    - `get_wildlife_snapshot_for_diagnostic()`
    - `get_player_profession_name()`
    - `get_player_profession_xp()`
    - `is_kernel_diagnostic_complete()`
- Updated `scripts/ui/ColonyHUD.gd`:
  - Added export status line:
    - `📜 Export: Ready at Tick 30000 | Status: [Waiting/Complete]`
  - Appended line to regular HUD refresh output.

Determinism check:
- Diagnostic trigger is exact tick equality (`tick == 30000`) and one-shot.
- Export is generated from in-memory append-only events only.
- No RNG added.
- No frame-time gated diagnostic logic added.

---

## 2026-04-26 - Phase 6 deterministic skill XP + profession lock

Date: 2026-04-26
Agent/Model: Codex (Cursor)
Goal: Add deterministic skill/profession progression driven by tick-executed player actions, with append-only skill gain logs.

Changes made:
- Updated `scripts/pawn/PawnData.gd`:
  - Added Phase 6 skill buckets:
    - `movement`, `farming`, `building`, `gathering`, `combat`
  - Added profession enum + state:
    - `NONE`, `FARMER`, `BUILDER`, `GATHERER`, `WARRIOR`, `SCHOLAR`
  - Added deterministic XP/profession API:
    - `gain_skill_xp(skill_name, amount)`
    - lock profession when first tracked skill reaches `100`
    - block XP in non-primary skills after profession lock
    - helper methods for profession name + progress.
  - Added save/load persistence for `skills` + `current_profession`.
- Updated `scripts/pawn/Pawn.gd`:
  - Added `record_skill_gain(skill, amount)` to call `PawnData.gain_skill_xp(...)`.
  - Emits append-only `WorldMemory.record_event(...)` with:
    - `type: skill_gain`, `pawn_id`, `skill`, `amount`, `tick`, `total_xp`, `profession`.
- Updated `scripts/pawn/PlayerInputBuffer.gd`:
  - On successful tick-executed movement:
    - grants `movement +1`.
  - On successful tick-executed interact:
    - grants `gathering +2`.
  - XP grants only happen after action success in tick processing.
- Updated `scripts/ui/ColonyHUD.gd`:
  - Added `_skill_line()` rendering:
    - `👤 Pawn [ID]: Profession [Name] | XP: [Current]/100`

Determinism check:
- Fixed XP values only (`1`, `2` in this phase).
- No RNG.
- XP mutation occurs only inside tick-driven intent execution path.
- WorldMemory skill logs are append-only events.

---

## 2026-04-26 - Phase 5 visual feedback: deterministic intent marker

Date: 2026-04-26
Agent/Model: Codex (Cursor)
Goal: Add deterministic target marker for the first queued player input action.

Changes made:
- Updated `scripts/pawn/PlayerInputBuffer.gd`:
  - Added `get_queued_target(pawn_pos: Vector2i) -> Variant`.
  - Peeks first queued intent and deterministically returns movement target tile (or `null`).
- Updated `scripts/ui/ColonyHUD.gd`:
  - Added `_draw_intent_marker()` rendered from HUD `_draw()`.
  - Marker position derives from:
    - current player pawn tile
    - first queued intent delta
  - Draw style:
    - semi-transparent yellow circle + arrowhead/shaft
    - no animation; purely state-based draw.
  - Added `set_player_control_refs(...)` and signal hookup for immediate redraw on queue enqueue.
- Updated `scenes/main/Main.gd`:
  - HUD now receives live refs to `_player_input` and `_player_pawn`.
  - Re-synced references on pawn selection changes.

Determinism check:
- No frame-time logic added.
- Marker appears/disappears based only on queue state and deterministic pawn tile.
- Queue pop on tick immediately clears marker when queue empties.

---

## 2026-04-26 - Phase 5 deterministic player input queue (WASD/Arrows/Space)

Date: 2026-04-26
Agent/Model: Codex (Cursor)
Goal: Add deterministic local pawn control where keyboard input is queued and consumed on game ticks only.

Changes made:
- Added `scripts/pawn/PlayerInputBuffer.gd`:
  - Captures WASD/Arrows/Space via `_unhandled_input`.
  - Buffers intents in FIFO with hard cap `MAX_QUEUE_SIZE = 10` (drops oldest when full).
  - Executes at most one intent per tick via `process_next_tick(...)`.
  - Records every attempted action to `WorldMemory.record_event(...)` with:
    - `type: player_action`, `action`, `pawn_id`, `tick`, `pos`, `executed`.
- Updated `autoloads/WorldMemory.gd`:
  - Added generic append-only `record_event(e: Dictionary)` for deterministic non-core events.
- Updated `scripts/pawn/Pawn.gd`:
  - Added `move(tile_delta: Vector2i) -> bool` for one-tile player step orders.
  - Added `interact() -> bool` contextual action (haul/eat/sleep checks).
- Updated `scenes/main/Main.gd`:
  - Added `_player_input`, `_player_pawn`, `_player_action_state`.
  - Instantiates `PlayerInputBuffer` in `_ready()` as attached runtime node.
  - Consumes exactly one queued action each `_on_game_tick(...)`.
  - Binds player-controlled pawn to current selection.
  - Added HUD-facing getters for queue size, pawn id, and action state.
- Updated `scripts/ui/ColonyHUD.gd`:
  - Added line: `PLAYER PAWN: [ID] | QUEUE: [Count] | STATE: [Action]`.

Determinism check:
- No frame-time execution of player actions.
- Input press only enqueues.
- Action execution runs on tick clock only.
- No RNG introduced.

---

## 2026-04-25 - Phase 4 deterministic revival + peace-gated rebirth

Date: 2026-04-25
Agent/Model: Codex (Cursor)
Goal: Implement deterministic settlement-state curve and peace-gated rebirth flow.

Changes made:
- `autoloads/SettlementMemory.gd`
  - Replaced hard-threshold revival with deterministic arithmetic curve over:
    - ticks_since_collapse
    - scar level
    - regional peace ticks
    - culture branch (open/cautious/defensive)
  - Added deterministic output states:
    - `permanently_abandoned`, `abandoned`, `recovering`, `revivable`, `active`
  - Added config constants:
    - `REVIVABLE_SCAR_MAX`, `HARD_COLLAPSE_TICKS`, `PEACE_TICKS_PER_BRANCH`
- `autoloads/SettlementRebirth.gd`
  - Added `get_rebirth_eligibility(...) -> {ok, reason, ...}` deterministic gate.
  - Enforced `REBIRTH_PEACE_TICKS` + branch peace threshold before spawn.
  - Block conditions:
    - scar >= 3
    - recent conflict below peace threshold
    - settlement state != `revivable`
  - Replaced tile ordering with deterministic tile scoring favoring:
    - low scar
    - near road/trade paths
    - near existing structure neighbors
- `scenes/main/Main.gd`
  - Added `REBIRTH_CHECK_INTERVAL_TICKS = 2000`
  - Wired tick-gated execution (`tick % interval == 0`) for:
    - `SettlementMemory.recompute(_world)`
    - `SettlementRebirth.process(_world, self, false)`
  - Removed non-gated rebirth calls from bootstrap/load/reroll/dirty flush paths.
- `docs/HEELKAWN_STATE.md`
  - Updated Phase 4 status bullets for deterministic revival and peace-gated rebirth.

Determinism check:
- Zero RNG added.
- Zero `_process(delta)` introduced.
- Tick-gated only for rebirth/revival loop.

---

## 2026-04-25 - Wildlife momentum sparkline (8-sample deterministic trend)

Date: 2026-04-25
Agent/Model: Codex (Cursor)
Goal: Replace single wildlife delta arrow with short-window deterministic momentum history.

Changes made:
- Updated `scripts/ui/ColonyHUD.gd`:
  - Added `WILDLIFE_HISTORY_SIZE = 8`.
  - Added bounded wildlife history buffer (`_wildlife_history`) and momentum string (`_momentum_spark`).
  - Replaced `_sample_wildlife(current_tick)` with history-based sampling:
    - still tick-gated by `WILDLIFE_SAMPLE_EVERY_TICKS`.
    - computes per-sample delta arrows (`↑`, `↓`, `→`) and pads to fixed width.
  - Updated `_wildlife_line()` to render:
    - `🦌 Wildlife: R:x D:y T:z [spark]`
    - initial scan line before first sample.
- Kept deterministic behavior:
  - No RNG usage.
  - No frame-time dependence.
  - Pure arithmetic over bounded tick-sampled history.

Decisions:
- Keep history in HUD layer only (diagnostic visibility) rather than persisting to save data.

Next concrete step:
- Add optional compact numeric delta suffix (`Δ+/-n`) per sample window for faster balancing decisions.

Files touched:
- scripts/ui/ColonyHUD.gd
- docs/SESSION_LOG.md

---

## 2026-04-25 - Deterministic live wildlife HUD counters

Date: 2026-04-25
Agent/Model: Codex (Cursor)
Goal: Add real-time wildlife trend visibility without UI spam or non-deterministic timing.

Changes made:
- Added `get_live_wildlife_snapshot()` to `scripts/pawn/AnimalSpawner.gd` (read-only rabbit/deer/total counts).
- Added deterministic tick-sampled wildlife telemetry to `scripts/ui/ColonyHUD.gd`:
  - `WILDLIFE_SAMPLE_EVERY_TICKS = 20`
  - Cached current/previous snapshots and trend arrow (`^`, `v`, `->`)
  - Added `_sample_wildlife(current_tick)` and `_wildlife_line()`
  - Added wildlife line into `_refresh()` output.
- Wired HUD to resolve `AnimalSpawner` through world metadata (`_world.get_meta("animal_spawner")`) set by Main.

Decisions:
- Keep sampling strictly tick-gated (no frame-time sampling) to avoid visual churn and preserve deterministic diagnostics.

Next concrete step:
- Add optional HUD mini-history (last N sampled totals) so trend direction is backed by recent sample sequence.

Files touched:
- scripts/pawn/AnimalSpawner.gd
- scripts/ui/ColonyHUD.gd
- docs/SESSION_LOG.md

---

## 2026-04-25 - Stability tuning pass from 08203eb audit

Date: 2026-04-25
Agent/Model: Codex (Cursor)
Goal: Apply audit-backed ecosystem tuning and remove determinism/perf warning hotspots.

Changes made:
- Applied wildlife pressure tuning in `scenes/main/Main.gd`:
  - `HUNT_JOB_PER_ANIMALS_DIVISOR`: `4 -> 6`
  - `MAX_DYNAMIC_HUNT_JOBS_PER_PASS`: `8 -> 4`
  - `HUNT_MEAT_STOCKPILE_SOFT_CAP`: `28 -> 18`
  - `MIN_RABBIT_RESERVE`: `10 -> 16`
  - `MIN_DEER_RESERVE`: `5 -> 8`
  - Dynamic hunt posting cadence: `10/30` -> `20/30/45` (normal/fast/ultra).
- Applied fauna recovery cadence tuning in `scripts/pawn/AnimalSpawner.gd`:
  - `POPULATION_CHECK_TICKS`: `2000 -> 1000`
  - `REPRO_TICKS`: `8000 -> 4000`
- Applied metabolism safety tuning in `scripts/pawn/Animal.gd`:
  - Rabbit `hunger_decay`: `0.06 -> 0.045`
  - Deer `hunger_decay`: `0.05 -> 0.035`
- Fixed static-call warning root in `autoloads/WorldMemory.gd` by restoring `_region_key` to `static`.
- Made `scripts/world/LivingWorldController.gd` tick-deterministic:
  - Removed `randomize()` and frame-based `_process` pressure timing.
  - Switched to `GameManager.game_tick` cadence.

Decisions:
- Preserve feature set (hunting/wildlife/revival) and improve balance + determinism quality.
- Prioritize stable long-run ecosystems and reduced warning/log overhead.

Next concrete step:
- Implement Phase 4 moderate-scar revival window in `autoloads/SettlementMemory.gd` `_settlement_state_v1`.

Files touched:
- scenes/main/Main.gd
- scripts/pawn/AnimalSpawner.gd
- scripts/pawn/Animal.gd
- autoloads/WorldMemory.gd
- scripts/world/LivingWorldController.gd
- docs/SESSION_LOG.md

---

## 2026-04-25 - Wildlife survival hardening (anti-starvation wave)

Date: 2026-04-25
Agent/Model: Codex (Cursor)
Goal: Stop recurring fast wildlife die-off while preserving hunt/gameplay features.

Changes made:
- Updated `scripts/pawn/Animal.gd`:
  - Animal foraging no longer consumes colony forage nodes; wildlife now feeds without depleting itself into starvation cascades.
- Updated `scenes/main/Main.gd`:
  - Added `_live_wildlife_counts()` helper.
  - Applied species reserve checks to all hunt seeding paths:
    - `_seed_jobs_from_world`
    - `_post_wildlife_hunt_jobs_after_stabilization`
    - `_post_hunting_jobs_for_animals` (kept existing reserve logic, now unified via helper)

Decisions:
- Keep all core systems (hunting, regrowth, wildlife) and stabilize by balancing pressure rather than removing mechanics.

Open questions:
- Should wildlife feeding be decoupled from tile forage permanently, or reintroduced later with a separate ecosystem resource pool?

Next concrete step:
- Add runtime counters in HUD for live rabbits/deer and active hunt jobs to validate long-run stability.

Files touched:
- scripts/pawn/Animal.gd
- scenes/main/Main.gd
- docs/SESSION_LOG.md

---

## 2026-04-25 - Wildlife QoL pass (no-feature-removal balancing)

Date: 2026-04-25
Agent/Model: Codex (Cursor)
Goal: Keep hunting/animal systems intact while preventing repeated wildlife collapse.

Changes made:
- Updated `scripts/pawn/Animal.gd` for survival-first behavior:
  - Reduced species hunger decay (rabbit/deer).
  - Increased passive grazing gain.
  - Added hungry-state action bias so animals prioritize foraging before wandering.
- Updated `scenes/main/Main.gd` hunting pressure logic:
  - Added species wildlife reserve floors (`MIN_RABBIT_RESERVE`, `MIN_DEER_RESERVE`).
  - Added reserve-aware dynamic hunt posting for live animals.
  - Reduced initial/one-shot wildlife hunt seeding caps to dynamic budget limits.

Decisions:
- Preserve all existing systems (hunting, regrowth, dynamic wildlife) and rebalance instead of disabling features.
- Favor sustained ecosystem behavior over short-term meat overproduction.

Open questions:
- Should reserve floors scale with map size / colony population instead of fixed constants?

Next concrete step:
- Add simple HUD debug counters for live rabbit/deer counts and posted HUNT jobs per pass.

Files touched:
- scripts/pawn/Animal.gd
- scenes/main/Main.gd
- docs/SESSION_LOG.md

---

## 2026-04-25 - Emergency anti-lag stabilization pass

Date: 2026-04-25
Agent/Model: Codex (Cursor)
Goal: Stop severe hitch/freeze cycles reported during normal and high-speed runtime.

Changes made:
- Added accumulator backlog clamp in `autoloads/GameManager.gd`:
  - New `MAX_ACCUMULATED_TICKS` cap prevents runaway catch-up storms after a hitch.
- Added high-speed throttling for heavy planners in `scenes/main/Main.gd`:
  - `SettlementPlanner.plan` + `TradePlanner.plan`: every 2 ticks at 6x, every 4 ticks at 12x.
  - `SettlementRebirth.process`: every 3 ticks at 6x, every 6 ticks at 12x.
- Tightened log gate in `autoloads/GameManager.gd` so verbose logs are only controlled by the local constant (no implicit debug-build logging).

Decisions:
- Prefer stable frame pacing over full catch-up during transient stalls.
- Keep deterministic ordering while reducing frequency of expensive non-critical passes at fast-forward speeds.

Open questions:
- Should planner intervals become user-configurable in the debug HUD for quick tuning?

Next concrete step:
- Add per-system tick-time counters in `Main._on_game_tick` to identify the top remaining hitch source.

Files touched:
- autoloads/GameManager.gd
- scenes/main/Main.gd
- docs/SESSION_LOG.md

---

## 2026-04-25 - Wildlife survival rebalance + hunt pressure control

Date: 2026-04-25
Agent/Model: Codex (Cursor)
Goal: Stop early mass wildlife die-off and reduce freeze spikes around haul/hunt churn.

Changes made:
- Rebalanced animal hunger in `scripts/pawn/Animal.gd`:
  - Added species-specific hunger decay (`rabbit 0.12`, `deer 0.09`) instead of a hard `0.5` per tick.
  - Added passive grazing gain on plains/forest when no forage node is present.
- Reduced hunt pressure in `scenes/main/Main.gd`:
  - Added meat stock soft-cap gate before posting more hunt jobs.
  - Added dynamic per-pass hunt budget based on live animal count (plus tighter cap at ultra speed).
- Fixed remaining unconditional pawn build logs in `scripts/pawn/Pawn.gd` so verbose flag is consistently respected.

Decisions:
- Keep hunting active but bounded; avoid queue flooding and full-herd wipeouts.
- Prioritize smoother fast-forward behavior while preserving deterministic simulation rules.

Open questions:
- Should we expose hunt pressure (meat soft-cap, budget divisor) as debug sliders in the HUD?

Next concrete step:
- Add debug counters for per-tick posted/cancelled HUNT jobs and failed haul-path retries to validate stability over long runs.

Files touched:
- scripts/pawn/Animal.gd
- scenes/main/Main.gd
- scripts/pawn/Pawn.gd
- docs/SESSION_LOG.md

---

## 2026-04-25 - Haul freeze mitigation during fast-forward

Date: 2026-04-25
Agent/Model: Codex (Cursor)
Goal: Reduce long stalls seen after haul path-selection messages (e.g. Quinn hauling Meat).

Changes made:
- Updated pawn path selection in `scripts/pawn/Pawn.gd` so high-speed simulation (`>= 6x`) uses regular pathfinding instead of per-call historic-aversion path weighting.
- Added short haul retry cooldown in `scripts/pawn/Pawn.gd` (`HAUL_RETRY_COOLDOWN_TICKS`) so unreachable haul targets do not trigger repeated immediate re-path attempts every tick.

Decisions:
- Keep lower-speed behavior unchanged (historic aversion still active below the high-speed threshold).
- Prioritize frame stability during fast-forward over nuanced scar-avoidance route preferences.

Open questions:
- If we still see freezes, should we move all heavy weighted path requests to a per-tick budget queue in `Main`?

Next concrete step:
- Add pathfinding timing counters (debug-only) around pawn haul/work/eat route calls to identify any remaining outlier spikes.

Files touched:
- scripts/pawn/Pawn.gd
- docs/SESSION_LOG.md

---

## 2026-04-25 - 12x speed stutter reduction (hot-path + warning cleanup)

Date: 2026-04-25
Agent/Model: Codex (Cursor)
Goal: Reduce freeze/stutter bursts at 12x sim speed and lower debugger warning noise.

Changes made:
- Reduced expensive live-animal hunt job scan cadence at ultra speed in `scenes/main/Main.gd`:
  - normal speed: every 10 ticks
  - 12x speed: every 30 ticks
- Wrapped remaining high-frequency pawn debug logs behind `GameManager.verbose_logs()` in `scripts/pawn/Pawn.gd` (haul/deposit/failure/death/threshold/hazard and related spam points).
- Fixed static call warning source by making `WorldMemory._region_key` instance-bound in `autoloads/WorldMemory.gd`.
- Fixed narrowing warnings in `autoloads/SettlementPlanner.gd` by using explicit int casts for age-derived adjustments.

Decisions:
- Keep simulation behavior deterministic while reducing expensive non-critical work frequency at 12x.
- Prioritize runtime smoothness and editor usability over verbose per-action console traces.

Open questions:
- Should we add a dedicated "performance mode" toggle that temporarily disables additional non-critical planners at 12x+?

Next concrete step:
- Profile `Main._on_game_tick` branches in a heavy population save and bucket non-essential updates across alternating tick groups.

Files touched:
- scenes/main/Main.gd
- scripts/pawn/Pawn.gd
- autoloads/WorldMemory.gd
- autoloads/SettlementPlanner.gd
- docs/SESSION_LOG.md

---

## 2026-04-25 - Debug log throttling for smoother editor runtime

Date: 2026-04-25
Agent/Model: Codex (Cursor)
Goal: Reduce run-time stutter caused by heavy console spam during simulation.

Changes made:
- Added global verbose logging switch in `autoloads/GameManager.gd` (`VERBOSE_SIM_LOGS`, default false).
- Wrapped noisy hot-path logs behind `GameManager.verbose_logs()` in:
  - `scripts/pawn/Pawn.gd`
  - `scripts/pawn/Animal.gd`
  - `scripts/pawn/PawnSpawner.gd`
  - `scripts/pawn/AnimalSpawner.gd`

Decisions:
- Keep important behavior unchanged; only suppress spam logs by default.
- Leave verbose tracing available with a single toggle.

Open questions:
- Should we expose verbose toggle via HUD/debug hotkey instead of code constant?

Next concrete step:
- Clean static-call warnings (`STATIC_CALLED_ON_INSTANCE`) to reduce editor warning load.

Files touched:
- autoloads/GameManager.gd
- scripts/pawn/Pawn.gd
- scripts/pawn/Animal.gd
- scripts/pawn/PawnSpawner.gd
- scripts/pawn/AnimalSpawner.gd
- docs/SESSION_LOG.md

---

## 2026-04-25 - Tick smoothing pass (frame spike guard)

Date: 2026-04-25
Agent/Model: Codex (Cursor)
Goal: Reduce gameplay stutter when simulation runs at high speed.

Changes made:
- Added `MAX_TICKS_PER_FRAME` guard in `autoloads/GameManager.gd`.
- Updated tick loop to process at most 6 ticks per rendered frame.
- Kept deterministic tick order and existing speed model intact.

Decisions:
- Prefer smooth frame pacing over aggressive single-frame catch-up bursts.

Open questions:
- Should we expose max ticks/frame as a player setting in UI for low-end machines?

Next concrete step:
- Profile `Main._on_game_tick` heavy branches and add optional staggered update buckets.

Files touched:
- autoloads/GameManager.gd
- docs/SESSION_LOG.md

---

## 2026-04-25 - Safe runtime wiring for imported memory systems

Date: 2026-04-25
Agent/Model: Codex (Cursor)
Goal: Activate imported systems in low-risk path so testing covers merged content.

Changes made:
- Registered new autoloads in `project.godot`: `SacredMemory`, `ChronicleLog`, `WorldClock`.
- Wired sacred-site sync into world-derivative recompute flow in `scenes/main/Main.gd`.
- Added `sacred` and `chronicle` persistence fields to save/load payload in `scenes/main/Main.gd`.
- Added explicit clear/reset for sacred/chronicle state on reroll/load prep.

Decisions:
- Integrate only safe deterministic memory systems first; defer high-risk social migration managers until APIs are aligned.

Open questions:
- Should sacred-site state drive immediate visual overlays, or remain a logic-only layer for now?

Next concrete step:
- Add first ChronicleLog producers from existing deterministic events (settlement collapse/revival markers).

Files touched:
- project.godot
- scenes/main/Main.gd
- docs/SESSION_LOG.md

---

## 2026-04-25 - Legacy project import and stabilization

Date: 2026-04-25
Agent/Model: Codex (Cursor)
Goal: Merge richer non-git OneDrive project into GitHub repo and keep runtime safe.

Changes made:
- Synced old project content from OneDrive into repo (addons/assets/resources/new systems).
- Kept git safety by excluding `.git`, `.godot`, `.cursor`, and `.sixth` folders.
- Fixed imported scripts using nonexistent `GameManager.sim_tick` to `GameManager.tick_count`.
- Removed leaked addon secret config and replaced with `config.example.cfg`.
- Added ignore rule for local addon secret config in `.gitignore`.

Decisions:
- Import all useful content first, then integrate runtime systems in controlled slices.
- Do not commit real API keys or local secret config files.

Open questions:
- Which imported addon/plugin folders should remain part of the game repo versus dev-only tooling?

Next concrete step:
- Validate imported runtime scripts in-editor and integrate new systems one at a time (Chronicle/Sacred/Fragmentation path).

Files touched:
- .gitignore
- autoloads/ChronicleLog.gd
- scripts/kernel/history_compressor.gd
- scripts/kernel/settlement_persistence.gd
- addons/godotassistant/config.example.cfg
- docs/SESSION_LOG.md

---

## 2026-04-25 - Settlement style expression pass

Date: 2026-04-25
Agent/Model: Codex (Cursor)
Goal: Advance Phase 4 identity target with deeper non-text settlement expression.

Changes made:
- Added public culture helpers to `autoloads/SettlementPlanner.gd` (`get_culture_type_for_settlement`, `get_culture_name_for_settlement`, `get_culture_audio_bias_for_settlement`).
- Wired settlement style into ambient generation in `scenes/main/Main.gd` with subtle deterministic bias (open vs defensive tonal shift).
- Added `docs/WORLD_BIBLE/GAME_VISION.md` to preserve long-horizon design direction.

Decisions:
- Keep expression subtle and non-intrusive (no text overlays, no gameplay stat changes).
- Derive style strictly from existing deterministic settlement data.

Open questions:
- Should style also influence architectural material palettes (future visual pass) or remain behavior/audio only?

Next concrete step:
- Add deterministic architectural palette/rule variants per style (open/cautious/defensive) beyond current placement order differences.

Files touched:
- autoloads/SettlementPlanner.gd
- autoloads/SettlementMemory.gd
- scenes/main/Main.gd
- docs/WORLD_BIBLE/GAME_VISION.md
- docs/WORLD_BIBLE/MASTER_INDEX.md
- docs/SESSION_LOG.md

---

## 2026-04-25 - Cross-LLM continuity baseline

Date: 2026-04-25
Agent/Model: Codex (Cursor)
Goal: Stop rebuild loops and establish stable memory/canon workflow.

Changes made:
- Expanded `docs/LLM_ONBOARDING.md` with free-forever stack and required session workflow.
- Created `docs/WORLD_BIBLE/` with index, timeline, regions, factions, characters, glossary, and canon changelog.
- Updated `README.md` to point to continuity docs.

Decisions:
- Repo files are the memory system; chat threads are temporary.
- Canon changes must be tracked explicitly.

Open questions:
- Which first culture/architecture style should be treated as canonical seed?

Next concrete step:
- Implement first cultural architecture pass in code and mirror outcomes in world bible files.

Files touched:
- README.md
- docs/LLM_ONBOARDING.md
- docs/SESSION_LOG.md
- docs/WORLD_BIBLE/*

---

## SESSION TEMPLATE

Date:
Agent/Model:
Goal:

Changes made:
- 

Decisions:
- 

Open questions:
- 

Next concrete step:
- 

Files touched:
- 
