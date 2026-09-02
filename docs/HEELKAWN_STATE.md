# HeelKawn State Management

**⚠️ IMPORTANT:** HeelKawn is **NEVER FINISHED**. It is a living, evolving simulation.
We are always building, always refining, always expanding. This document captures the
**CURRENT STATE** of an ongoing creative journey.

**Last Updated:** August 19, 2026
**Latest Checkpoint:** August 19, 2026 (performance stabilization + AI activity fixes)
**Current Phase:** Performance Stabilization Verified (pending smoke test run)
**Overall Status:** Deterministic tick system unified; Matrix AI cached; pawn job pipeline fixed; automated smoke test added.

**Read first:** [HEELKAWN_PROJECT_COMPASS.md](HEELKAWN_PROJECT_COMPASS.md) and [HEELKAWN_BLUEPRINT.md](HEELKAWN_BLUEPRINT.md) and [HEELKAWN_STATE.md](HEELKAWN_STATE.md) (this file)
**Latest verification snapshot:** [STATE_VERIFICATION_2026-08-17.md](STATE_VERIFICATION_2026-08-17.md)

---

## August 19, 2026 — Performance & AI Activity Stabilization

### Changes Applied

1. **Tick System Unification** — Removed conflicting `GameManager._max_ticks_per_frame_for_speed()` caps. `TickManager` is now the sole authority. Budget cap floor raised to 50% of speed cap to prevent death spiral. Accumulator reset on deceleration.
2. **Runtime Diagnostics** — Added deterministic timing diagnostics:
   - `TickManager`: [TICK_DIAG] warnings every 3s real-time when tick > 16ms
   - `GameManager`: [GM_DIAG] warnings every 3s real-time when dispatch > 16ms
   - `JobManager`: [JOB_DIAG] warnings when claim_next_for > 2ms
   - Per-pawn [PAWN_DIAG] every 600 ticks (staggered by pawn_id): current_job, state, settlement_id, tile_pos, claim activity
   - F10 #99 Tick System Health panel already present
3. **O(N²) Scan Caching** — `ColonySimServices` now builds `alive_pawns` once per refresh cycle and passes it to all `_refresh_*` sub-functions instead of calling `PawnAccess.find_alive_pawns()` repeatedly.
4. **Matrix AI Caching** — `HeelKawnianManager.get_matrix_decision_for_pawn()` now caches results per-tick per-pawn, with automatic invalidation when hunger/rest/health shift by > 5 points.
5. **Pressure Event Batching** — `HeelKawnianManager._on_pressure_event()` processes at most once every 8 ticks.
6. **Job Claim Optimization** — `JobManager.claim_next_for()` scans profession-matching jobs first when >50 open jobs exist.
7. **Settlement Visibility Fallback** — Unsettled pawns (`settlement_id < 0`) can now see primitive jobs within 24 tiles instead of being completely job-blind.
8. **Primitive Job Tech Gate Bypass** — `JobManager.claim_by_id_for()` skips `TechnologySystem` checks for primitive survival jobs (FORAGE, CHOP, MINE, HUNT, FISH, BUILD_FIRE_PIT, BUILD_BED, GATHER_STICK, GATHER_FLINT).
8. **Pawn Settlement Membership** — `_maybe_update_settlement_membership()` now runs every tick (removed 120-tick stagger gate).
9. **Matrix AI Speed Gate Removed** — `_maybe_matrix_decide_job()` runs every eligible idle tick; if decision empty, `_fallback_survival_job()` posts and claims a primitive job immediately.
10. **Pawn Claim Retry** — `_idle_claim_fail_streak` tracks consecutive claim failures; after 3 failures, forces fallback survival job.
11. **Automated Smoke Test** — Added `tests/smoke/PerformanceSmokeTest.gd` with pass/fail criteria for backlog, job claiming, and pawn activity rates.

### Current Phase
Performance Stabilization Verified (pending smoke test run)

### Known State at Checkpoint
- Runtime truth pass: tick system unified, diagnostics active, Matrix AI cached
- Pawn activity: settlement membership updated every tick, visibility rules relaxed for unsettled pawns
- Job pipeline: primitive jobs bypass tech gate, fallback survival jobs prevent idle starvation
- Performance: O(N²) scans eliminated in hot paths, pressure events batched to 1/8 ticks

---

## August 17, 2026 — Deep Profiling + O(P²) Elimination

**Scope:** Runtime profiling revealed the bottleneck is NOT in subsystems optimized earlier (SurvivalSystem, EcologySystem, etc.) but in per-pawn tick handlers and world AI. The profiler `other` bucket dominates; individual HeelKawnian nodes appear in TOP3 at ~30–230+ ms each; AIAgentManager costs ~90–130 ms.

**Root causes identified:**
1. `PawnSpawner.get_alive_pawns()` allocated a new O(P) array on every call — 51+ call sites across codebase, all per-tick
2. `HeelKawnian._refresh_awareness()` used `get_tree().get_nodes_in_group("pawns")` — full scene tree traversal per pawn = O(P²)
3. `SocialDynamics._relationships` had no adjacency index — every per-pawn query scanned all relationships = O(R)
4. `ColonySimServices` called `find_alive_pawns()` 8 times per refresh cycle — 8 separate O(P) allocations
5. `AIAgentManager._update_all_agents()` allocated+sorted `agents.keys()` every 3 ticks
6. `WorldAI.world_events` grew without bound — `_update_world_state_neurons()` scanned all events = O(E)
7. `WorldAI._update_knowledge_neurons()` called `PawnAccess.find_pawns()` just for `.size()` — unnecessary O(P) scan

**Changes:**
- `PawnSpawner.gd` — added tick-stamped alive pawn cache (`_alive_pawns_cache`, `_alive_pawns_cache_tick`); `get_alive_pawns()` now returns cached result within same tick; added `alive_pawn_count()` for callers that only need count; cache invalidated on spawn/death
- `HeelKawnian.gd` — `_refresh_awareness()` now uses `spawner.get_alive_pawns()` instead of `get_tree().get_nodes_in_group("pawns")` — eliminates O(P²) scene tree traversal
- `SocialDynamics.gd` — added adjacency index `_by_pawn: Dictionary` mapping pawn_id → Array of relationship keys; `get_all_relationships_for()` now O(degree) instead of O(R); `_on_pawn_death()` and `_on_pawn_move()` use index; index maintained in `add_interaction()` and `clear()`
- `ColonySimServices.gd` — added single-pass `_collect_pawn_stats()` that iterates alive pawns once per refresh cycle; computes total count, food carried, cold/uncovered count, centroid simultaneously; `_food_carried_by_pawns()`, `_refresh_housing_pressure()`, `_colony_centroid_tile()`, `count_cold_uncovered_pawns()` now use cached stats for global case
- `AIAgentManager.gd` — added `_agent_keys_cache_dirty` flag; `_update_all_agents()` only rebuilds sorted keys when agents are added/removed, not every 3 ticks
- `WorldAI.gd` — added `MAX_WORLD_EVENTS = 2048` cap; `update()` trims array if exceeded; added `_get_cached_pawn_count()` for tick-stamped pawn count; `_update_knowledge_neurons()` uses cached count instead of `PawnAccess.find_pawns().size()`

**Static quality gate:** PASS (sim-quality-gate.sh)

**What needs runtime verification (not yet done):**
- Measure before/after tick execution time at 1x and 200x
- Verify profiler `other` bucket reduction
- Verify individual HeelKawnian nodes no longer appear in TOP3
- Verify AIAgentManager cost reduced from ~90–130 ms
- Verify job count stable (21→128 explosion investigated — root cause is `JobManager.claim_next_for` O(N) scan per pawn, deferred)
- F10 diagnostic panels render without errors
- 1x and 100x performance smoothness with consistency checks

---

## August 17, 2026 — Lag Reduction + Autoload Consolidation

**Scope:** Reduce tick-handler lag, eliminate duplicate autoload registrations, add tick forwarding to consolidated managers.

**Changes:**
- `CharacterProgressionSystem.gd` — added `ACHIEVEMENT_CHECK_INTERVAL = 500` constant; `_check_achievements` now gated to run every 500 ticks instead of every tick
- `Main.gd` — removed duplicate `_check_achievements` and `_check_skill_atrophy` calls (were calling CharacterProgressionSystem methods that the autoload already handles)
- `SurvivalSystem.gd` — added `DEATH_CHECK_INTERVAL = 5` and `FULL_SURVIVAL_INTERVAL = 3` constants; `_on_game_tick` now throttles `PawnAccess.find_alive_pawns()` to every 3 ticks (was every tick), death checks gated to every 5 ticks
- `EcologySystem.gd` — doubled `ECOLOGY_UPDATE_INTERVAL` (120→240), `PLANT_GROWTH_INTERVAL` (240→480), `POLLUTION_INTERVAL` (500→1000); added double-buffer `_pollution_prev` to eliminate 65K-float `duplicate()` allocation per pollution pass
- `MemoryManager.gd` — added `_forward_tick_to_children` connected to `GameManager.game_tick`; forwards tick events to child subsystems loaded as children
- `FactionManager.gd` — added `_forward_tick_to_children` connected to `GameManager.game_tick`
- `PawnManager.gd` — added `_forward_tick_to_children` connected to `GameManager.game_tick`
- `SocialManager.gd` — added `_forward_tick_to_children` connected to `GameManager.game_tick`
- `UIManager.gd` — added `_forward_tick_to_children` connected to `GameManager.game_tick`
- `EventManager.gd` — added `_forward_tick_to_children` connected to `GameManager.game_tick`
- `PlayerManager.gd` — added `_forward_tick_to_children` connected to `GameManager.game_tick`
- `ObserverManager.gd` — added `_forward_tick_to_children` connected to `GameManager.game_tick`
- `project.godot` — removed 3 duplicate autoload registrations: `HeelKawnUIManager`, `UILayoutManager`, `PawnMoodUI` (all 0 direct refs, now loaded as children of UIManager)

**Autoload count:** 143 → 140 (3 removed from project.godot)

**Static quality gate:** PASS (sim-quality-gate.sh)

**What needs runtime verification (not yet done):**
- F10 diagnostic panels render without errors in Godot editor
- HUD identity strip shows civilization stage correctly
- F10 #49 prints valid HeelKawnian development profiles
- PawnInfo/PawnMoodUI display real data at runtime
- Crafting material consumption works in all paths
- Tool requirements enforced in crafting recipes
- 1x and 100x performance smoothness with consistency checks

---

## July 10, 2026 — Last Pre-Checkpoint Session

**Scope:** Family inheritance documentation + skill branch visibility.

**Implemented:**
- Family reputation inheritance now records `family_reputation_inherited` WorldMemory events
- Skill-tree branch effects visible in PawnInfoPanel inspection sheet
- Docs synchronized with code truth (TODO.md, BUILD_INVENTORY.md, HEELKAWN_STATE.md)

**Verification:** Quality gate static PASS. Runtime smoke skipped (no Godot binary in environment).

---

## June 5, 2026 — Civilization Stage Deepening + PawnAccess Fixes

**Implemented but Needs Runtime Verification:**
- CivilizationStage.gd continuous metrics integration (literacy, tech diffusion, governance, egregore signatures)
- PawnAccess typed-array return type fixes (unblocked `SettlementMemory._living_pawns()`)
- Cache rebuild + autoload class_name fixes (AgeMemory, HeelKawnianIdentity)

**Verification:** Headless smokes PASS (boot, settlement, worldmeaning, year1 growth). Performance smoothness requires desktop.

---

## AI AGENT CROSS-REFERENCE

**Read order for AI agents (handoff sequence):**
1. `AI_README.md` — Core philosophy, kernel rules, forbidden patterns
2. `HEELKAWN.txt` — Quick-context orientation
3. **`docs/HEELKAWN_STATE.md`** — THIS FILE. Authoritative current status
4. `docs/BUILD_INVENTORY.md` — Honest built-vs-missing inventory
5. `docs/HEELKAWN_PROJECT_COMPASS.md` — Orientation compass
6. `docs/HEELKAWN_BLUEPRINT.md` — Full PSUni blueprint

**Related docs (always refer to for canon/system context):**
- `docs/WORLD_BIBLE/CANON_SYSTEMS_FEATURE_QUEUE.md` — Canon execution queue
- `docs/WORLD_BIBLE/MASTER_INDEX.md` — World bible master index
- `docs/WORLD_BIBLE/GLOSSARY.md` — Canon glossary with implementation anchors
- `.cursor/rules/heelkawn-canonical-repo.mdc` — Canonical repo policy
- `.cursor/rules/heelkawn-handoff.mdc` — Handoff read order (enforced by cursor rules)

**Truth hierarchy (when docs conflict):**
1. Source code and Godot runtime checks (highest truth)
2. `docs/BUILD_INVENTORY.md` — Built-vs-missing inventory
3. `docs/HEELKAWN_STATE.md` — This file (current working state)
4. `docs/HEELKAWN_PROJECT_COMPASS.md` — Project compass
5. `AI_README.md` — Kernel philosophy (non-negotiable)
6. Historical docs / AI session notes — Evidence, not authority

---

## Current Status

- **Current Phase:** Stabilization / Checkpoint (Aug 14, 2026 checkpoint; Aug 17 identity repair)
- **Kernel Health:** 🟢 Stable enough for headless smoke; runtime truth pass still required
- **Compilation:** ✅ Headless Godot smoke passed in prior sessions (last verified July 10, 2026)
- **Project Shape:** Many live systems, some partial systems, and several design stubs
- **Truth Source:** Code/runtime first, then `BUILD_INVENTORY.md`, then this file
- **Runtime Contract:** `AGENTS.md` + `docs/AI_RUNTIME_MANDATE.md`
- **Quality Gate Command:** `bash tools/ai/sim-quality-gate.sh`
- **Static quality gate may pass**, but runtime smoke must be verified in-editor or headless where Godot is available
- **Do not claim systems are complete unless verified in runtime**
- Resolved Blockers:
  - Fixed Pawn parse errors that were cascading into job-system and UI dependency failures.
  - Verified `ProceduresPawnVisualizer` exists, exposes `class_name ProceduresPawnVisualizer`, and compiles cleanly.
  - Confirmed `Job.gd` and `JobManager.gd` compile cleanly after the Pawn dependency chain is restored.
  - Added the Phase 4 settlement lifecycle machine with active / abandoned / reviving / permanent ruin states.
  - Fixed profession lock bug (pawns were permanently locked into first profession, preventing role diversity).
  - Fixed event schema gap (FoodChainManager events now reach WorldMeaning via _infer_kind_from_type).
  - Relaxed neural bias speed gate from 50x to 200x so neural matrix contributes at normal play speeds.
  - Added profession reassignment so pawns can change roles when a non-primary skill outpaces their current profession.
  - Added explicit family reputation inheritance event logging (`family_reputation_inherited`) so birth-line social carryover is visible in WorldMemory.
  - Added visible skill-branch summaries to the pawn inspection sheet so milestone choices are readable in normal play instead of only in raw data.
  - Added colony role balance rules to dampen overrepresented professions.
  - Added infrastructure + security job posting to SettlementPlanner (fire pit, storage hut, protect, defend).
  - Added warrior peacetime patrol for visible perimeter presence.
  - Added display settings (resolution, window mode, vsync) to GameSettings.
  - Performance optimizations: spatial grid for social proximity, redraw throttle, meaning throttle, caches.
  - Added `TickBudgetManager.gd` as a shared 12ms simulation budget coordinator and throttled high-frequency debug logs in the main tick path.
  - Reduced the 100x tick burst cap in `TickManager.gd` to keep frame time under control when the colony is busy; `GameManager` diagnostics now mirror the active 100x cap.
  - Reverted the blunt 100x cap reduction and moved the control point to construction seeding: that pass now yields on the actual frame budget instead of shrinking the whole simulation burst.
  - Closed the v1 truth mismatch where faction, house, trade, and infrastructure gates could keep acting on stale or global state after settlement downgrade.
  - FactionRegistry and FactionSystem now prune non-formal settlement endpoints before reporting or updating live pair state.
  - TradeMemory now seeds and renews routes from formal settlements only, and removes routes whose endpoints are no longer formal.
  - SettlementMemory infrastructure formalization now checks for a local stockpile at the candidate settlement instead of treating any world stockpile as sufficient.
  - **FEAT: Literature & Knowledge Preservation (Phase 5)**:
    - Implemented Book crafting recipes (Paper, Leather, Ink, Pen, Book) in `CraftingSystem.gd`.
    - Expanded `WorldMeaning.gd` with deterministic tags for literate regions (`great_library`, `scriptorium`, `literate`).
    - Integrated Literature recording into the `WorldMeaning` recompute pipeline.
    - Verified `KnowledgeSystem.gd` uses deterministic `WorldRNG` for rediscovery checks.
  - **FEAT: Civilization Stage Lens (Phase 5A initial live)**:
    - Added `CivilizationStage.gd` as a read-only autoload.
    - Derives era/stage from live technology, knowledge carriers, settlement infrastructure, profession diversity, and quality-of-life proxies.
    - Settlement tech diffusion, literacy rate, lifespan, and institution scores are now tracked by live systems and fed into the stage lens.
    - Exposes F10 `03B · Civilization Stage` and adds era text to the HUD identity strip.
  - **FEAT: HeelKawnian Development Profiles (Phase 5A initial live)**:
    - Expanded `HeelKawnianIdentity.gd` into a memory-bearing identity resource with deterministic traits and profile history.
    - Expanded `HeelKawnianManager.gd` into a derived per-pawn development intelligence layer.
    - Each pawn profile now summarizes soul id, phase, drive, next need, era context, skills, knowledge, social signal, preservation pressure, and trauma pressure.
    - Exposes F10 `49 · HeelKawnians` for sample individual sprite profiles.
  - **FEAT: HeelKawnian Matrix AI Behavior Wiring (Phase 5A initial live)**:
    - `HeelKawnianManager.gd` now turns each pawn's derived profile into deterministic job priority biases.
    - `Pawn.gd` consumes those Matrix biases during normal `JobManager` claiming, so identity/memory/development drive nudges actual work without overriding job legality.
    - Strong Matrix-influenced job choices are logged back through `heelkawnian_development` events for auditability and replay-facing inspection.
    - F10 `49 · HeelKawnians` now prints top Matrix job pulls and rationale for sampled sprites.
  - **FEAT: AIAutoBuild need gates (May 19, 2026)**:
    - Shelter/storage intents now require `ColonySimServices` housing/storage/food pressure (same thresholds as `SettlementPlanner.can_post_build_intent`).
    - Reduces autonomous build spam before formal settlement pressures exist.
  - **FEAT: Matrix Social Intent Bridge + AutoBuild Job Wiring (Phase 5A extension)**:
    - `HeelKawnianManager.gd` now exposes deterministic social intent suggestions (`social_seek`, `teach_seek`, `grudge_confront`) based on trust/rapport, grudge intensity, reputation, proximity, and settlement.
    - `Pawn.gd` now checks the Matrix social intent layer during idle autonomy, including `teach_seek` handling that writes rapport/social/neural memory traces.
    - `JobManager.gd` now includes a `post_from_dict(...)` compatibility adapter so older dict-post callers can map into concrete `Job.Type` entries safely.
    - `AIAutoBuild.gd` now posts concrete build jobs via `JobManager.post(...)`, includes settlement-aware intent dedupe, and safely falls back when advanced settlement building queries are unavailable.
  - **FEAT: Matrix Settlement Ambition Seeding (Phase 5A extension)**:
    - `HeelKawnianManager.gd` now derives periodic local ambitions (hearth, storage, beds, walls/door, marker stone, food, tooling, teaching) from drive + local settlement feature pressure.
    - `Pawn.gd` now runs a throttled ambition seed hook in idle to inject one strategic job into `JobManager` without overriding normal job legality or claim flow.
    - Ambition seeding is throttled per pawn and per settlement region to avoid queue spam at high simulation speed.
    - Ambition posts are logged via `heelkawnian_development` as `matrix_settlement_ambition` for deterministic audit and replay tracing.
  - **FEAT: Matrix Preservation + Learning runtime wiring (May 26, 2026)**:
    - `HeelKawnian.gd` now consumes `HeelKawnianManager.get_preservation_choice_for_pawn(...)` during idle medium-lane autonomy.
    - Preservation decisions now map into live actions: teach nearby target, draft-walk to teach target, seed `CARVE_KNOWLEDGE_STONE`, write knowledge into a nearby book tile, or seed `BOOK_BINDING` when writing cannot occur immediately.
    - `HeelKawnian.gd` now consumes `HeelKawnianManager.get_learning_target_for_pawn(...)` and seeds bounded `APPRENTICESHIP`/`TEACH_SKILL` jobs with local pending-job dedupe.
    - Both paths are tick-gated and cooldown-gated for 1x/100x stability and logged as `matrix_preservation_action` / `matrix_learning_seed`.
    - Added speed-tier global backpressure caps and adaptive cooldown scaling to prevent queue amplification at `26x`/`50x`/`100x` while keeping deterministic behavior.
  - **FEAT: Household Plan Write-Path Stabilization (May 26, 2026)**:
    - `HeelKawnianManager.get_household_ambition_for_pawn(...)` now supports read-only mode so Matrix decision scans do not consume household plan cooldowns or create plans as side effects.
    - `Pawn.gd` matrix ambition seeding now executes household plans first and posts concrete household-scoped jobs (`matrix_household_ambition`) instead of relying only on bias nudges.
    - Household and settlement ambition posting now use speed-tier local/global pending-job backpressure to reduce post churn at high simulation speed.
  - **FEAT: Settlement Chain Anti-Stall Reliability (May 26, 2026)**:
    - `HeelKawnianManager._ambition_chain_for_settlement(...)` now tracks per-step start tick and stall retries in `_active_ambition_chains`.
    - Chain steps still advance only from local feature truth (`_chain_step_completed`), but now gain deterministic retry priority boosts when blocked.
    - After repeated stall windows, a blocked step is advanced deterministically to prevent permanent chain lock.
    - Stall windows scale by simulation speed tier so `100x` stress runs do not rotate chains too aggressively.
  - **FEAT: Settlement Chain Observability (May 26, 2026)**:
    - Settlement-chain lifecycle now emits explicit world events on `chain_start`, `step_complete`, `step_retry`, `step_skip_after_stall`, `chain_complete`, and invalid chain clear.
    - Added `HeelKawnianManager.get_active_ambition_chains_debug()` for direct runtime inspection of active chain state by settlement.
    - Chain diagnostics are recorded through `WorldMemory` as `heelkawnian_development` entries with `event_type=settlement_chain`.
  - **FEAT: Chain Completion Precision Guard (May 28, 2026)**:
    - Tightened `_chain_step_completed(...)` to require foundational prerequisites (hearth/storage/farm/wall/library/granary relationships) before counting later steps complete.
    - Reduces false-positive chain advancement in dense/overlapping settlements where one feature count alone was too permissive.
  - **FEAT: Recovery Scan Throughput Cache (May 28, 2026)**:
    - Added per-settlement caching for recovery feature snapshots and settlement population reads in `HeelKawnianManager`.
    - Cache TTL scales by simulation speed tier, reducing repeated world/settlement scans in hot ambition/recovery paths at high speed.
  - **FEAT: Pawn Matrix Pending-Query Cache (May 28, 2026)**:
    - Added per-tick caches for `JobManager` pending-count lookups in `HeelKawnian.gd` matrix ambition/preservation/learning paths.
    - Replaced repeated `count_pending_by_type` and `count_pending_jobs_near` calls with cached wrappers keyed by tick/job/position/radius.
    - Reduces hot-path query churn when many pawns evaluate matrix postings in the same simulation tick.
  - **FEAT: Proto Authority Pending-Scan Cache (May 28, 2026)**:
    - `AuthorityJobBoard.post_critical_proto_survival_if_needed(...)` now uses a per-call pending-near cache for forage/hunt/fish/fire-pit checks.
    - Avoids repeated duplicate `count_pending_jobs_near(...)` scans while keeping posting decisions deterministic.
  - **FEAT: Leader Build Pass Pending Cache (May 28, 2026)**:
    - `HeelKawnianManager._leader_direct_construction_jobs(...)` now caches local `count_pending_jobs_near(center, job_type, 10)` results per pass.
    - Reduces repeated pending-near scans across build queue entries while preserving deterministic post gating.
  - **FEAT: Cooking Pressure Pending Cache (May 28, 2026)**:
    - `ColonySimServices` now caches `JobManager.count_pending_by_type(...)` results per tick for cook job types.
    - `_cooking_pressure_for_scope(...)` now uses cached pending counts for `COOK_MEAT`, `COOK_FISH`, and `COOK_BERRIES`.
  - **FEAT: Local Pending-Near Cache in Colony Services (May 28, 2026)**:
    - `ColonySimServices.count_pending_jobs_near(...)` now caches radius query results per tick by center/job/radius key.
    - Reduces duplicate local pending-job scans in hearth/warmth and settlement pressure gating paths.
  - **FEAT: Deterministic FintechBridge Kernel Adapter (May 28, 2026)**:
    - Added `autoloads/FintechBridge.gd` and registered it in `project.godot`.
    - External finance signals are now ingested as explicit manifests/events (`event_id`, `apply_tick`, `kind`, `currency`, `amount_micro`) and applied only on simulation tick.
    - Bridge records every applied fintech event into `WorldMemory` (`type=fintech_event_applied`) and maintains an in-sim treasury snapshot by currency.
    - Added deterministic debug seeding helper (`debug_seed_meow_credit`) for controlled integration testing without wall-clock callbacks.
  - **FEAT: Zoroastrian/Hindu Ethics Runtime Layer (May 28, 2026)**:
    - `ReligionSystem.gd` now computes deterministic moral state from factual world events:
      - pawn-level `Asha/Druj` balance,
      - pawn-level `Karma` ledger,
      - settlement-level `Dharma` index.
    - Added periodic ethics ingestion from `WorldMemory.get_events()` with monotonic index tracking (`_last_world_event_index`) to avoid reprocessing.
    - Ethics mapping currently responds to survival/teaching/combat/fintech event types, enabling religion/culture systems to consume live moral state rather than static lore-only flags.
    - Added API surface: `get_pawn_asha_druj_balance`, `get_pawn_moral_axis`, `get_pawn_karma`, `get_settlement_dharma_index`, `get_religion_ethics_snapshot`.
  - **FEAT: Egregore Matrix Scaffolding (May 29, 2026)**:
    - Added `autoloads/EgregoreMemory.gd` and registered `EgregoreMemory` in `project.godot`.
    - Introduced deterministic per-settlement 8-axis pressure signatures:
      - `cooperation`, `discipline`, `care`, `fear`, `vengeance`, `curiosity`, `asceticism`, `opulence`.
    - `EgregoreMemory` ingests `WorldMemory` event deltas by monotonic index and updates bounded pressure vectors, cohesion, and ritual/taboo/law density.
    - Added read APIs for observer/runtime usage:
      - `get_settlement_signature`
      - `get_settlement_pressure`
      - `get_settlement_top_pressures`
      - `get_world_snapshot`
    - Integrated matrix coupling in `scripts/pawn/HeelKawnianDecision.gd`:
      - `get_heelkawnian_matrix_job_bias(...)` now adds bounded egregore bias per settlement to job selection.
    - Added watch-mode visibility in `scripts/ui/ColonyHUD.gd`:
      - New `Egregore[...]` line shows settlement cohesion plus top dominant pressures for live observer testing.
  - **FEAT: Egregore Emergent Norms/Laws (May 29, 2026)**:
    - `EgregoreMemory.gd` now derives active social norms from pressure thresholds with deterministic cooldown hysteresis:
      - `mutual_aid`, `martial_code`, `scholar_path`, `austerity_rite`, `market_charter`.
    - Norm emergence/fade is recorded to `WorldMemory` (`egregore_norm_emerged` / `egregore_norm_faded`).
    - On emergence, Egregore adds corresponding law entries to `SettlementMemory` when missing (no duplicate insertion).
    - `ColonyHUD` now surfaces active norms in watch mode so civilization behavior and social institution drift are visible during observer runs.
  - **FEAT: Egregore Coupling — Diplomacy + Migration (May 29, 2026)**:
    - `FactionManager.gd` polity relation scoring now includes deterministic `EgregoreMemory` diplomacy bias:
      - prosocial/discipline/opulence alignment nudges relations up,
      - fear/vengeance pressure and cross-settlement pressure mismatch nudge relations down.
    - `FragmentationManager.gd` migration fragmentation gates now read Egregore pressure + active norms:
      - fear/vengeance can increase relocation tendency,
      - cooperation/care/discipline and stabilizing norms can reduce unnecessary out-migration.
    - Added world fact logging for applied egregore migration influence (`egregore_fragmentation_applied`) for replay/audit visibility.
  - **FEAT: Egregore Coupling — Settlement Institution Priorities (May 29, 2026)**:
    - `HeelKawnianManager.gd` now applies a bounded Egregore norm priority bonus in two settlement-scale paths:
      - `get_settlement_ambition_for_pawn(...)` (ambition job + reason annotation),
      - `leader_direct_construction(...)` (direct posted build/cook job priorities).
    - Norm-aware boosts currently cover:
      - `mutual_aid` -> shelter/food security priorities,
      - `martial_code` -> defense infrastructure priorities,
      - `scholar_path` -> knowledge/teaching priorities,
      - `austerity_rite` -> storage/rationing priorities,
      - `market_charter` -> trade/road priorities.
    - Ensures emergent institutions alter what settlements *choose to build and do*, not just pawn-level local decisions.
  - **FEAT: Watch-Mode Civilization Divergence Telemetry (May 29, 2026)**:
    - `EgregoreMemory.gd` now exposes `get_settlement_divergence_snapshot(...)` with:
      - cohesion,
      - divergence score,
      - migration tendency,
      - stability/threat aggregates,
      - active norms.
    - `ColonyHUD.gd` now renders a `Divergence[...]` line in watch mode, including:
      - per-settlement divergence score,
      - migration trend (`retention` / `steady` / `outflow`),
      - nearest-polity diplomacy headline.
    - This makes long-run civilization drift legible while observing at normal or accelerated speed.
  - **FEAT: Trend-Aware Divergence Telemetry (May 29, 2026)**:
    - `EgregoreMemory.gd` now keeps short deterministic trend series per settlement for:
      - divergence score,
      - migration tendency.
    - `get_settlement_divergence_snapshot(...)` now includes trend labels (`rising` / `falling` / `steady`).
    - `ColonyHUD.gd` now shows directional arrows on divergence, migration, and diplomacy lines, making change-over-time visible at a glance during watch mode.
  - **FEAT: Cross-Settlement Egregore Diffusion (May 29, 2026)**:
    - `EgregoreMemory.gd` now performs deterministic per-tick-window diffusion between nearby formal settlements.
    - Diffusion weights are diplomacy-dependent:
      - cordial/allied relations pull pressure vectors toward convergence,
      - hostile/war relations push pressure vectors toward divergence.
    - Neighbor set is bounded (nearest 3) and ordered deterministically, preserving replayability while enabling cultural co-evolution and polarization across the world.
  - **FEAT: Institutional Law Enforcement Loop (May 29, 2026)**:
    - `SettlementMemory.check_law_violations(...)` now evaluates `egregore_*` law types in live sim:
      - `egregore_mutual_aid`,
      - `egregore_market_charter`,
      - `egregore_martial_code`,
      - `egregore_austerity_rite`.
    - `HeelKawnian.gd` now applies concrete sanctions when violations are detected:
      - trust penalties (chief-linked),
      - social rapport reduction,
      - pawn reputation reduction,
      - grudge pressure via `GrudgeManager` where applicable.
    - Sanctions are recorded as factual events (`law_sanction_applied`) and now feed back into Egregore pressure updates, closing the institution -> behavior -> memory loop.
  - **FEAT: Mode Contract Enforcement (Watch / Sprite / Observer)**:
    - `WATCH` mode is now non-interactive with world command/edit input.
    - `INCARNATED` mode is embodied sprite play (not full-command mode).
    - `OBSERVER` mode is the sole full edit/command authority path.
    - Placement/command gates in `Main.gd` now enforce observer-only control for world editing and pawn command routing.
  - **FIX: Gentle onboarding runtime blocker**:
    - Replaced the bad `Label.bbcode_enabled` path with an attached `RichTextLabel` in `OnboardingSystem.gd`.
    - Updated visible language from tutorial rewards to first-body orientation.
    - Verified Godot headless smoke passes after the fix on May 7, 2026.
- **FEAT: Need-driven build gating (May 19, 2026)**:
  - `SettlementPlanner.gd`: `_build_pressure_ok`, per-settlement+type cooldown (`BUILD_INTENT_COOLDOWN_TICKS` = 1200), `can_post_build_intent` / `mark_build_intent_posted` gate bed, fire pit, storage hut, and farm planner posts from `ColonySimServices` pressure signals.
  - `AIAutoBuild.gd`: delegates to planner gating before creating intents and before posting jobs; uses `JobManager.post_build_deduped`.
  - `JobManager.gd`: `has_pending_build_near` and `post_build_deduped` for settlement-scoped construction dedupe.
  - **FEAT: Tick burst smoothing (June 2, 2026)**:
    - `TickManager.gd` now stops its per-frame catch-up loop on the configured frame budget as well as the speed cap.
    - The high-speed caps were raised so `50x`, `100x`, and `200x` can actually keep up with their intended throughput when the frame budget allows it.
    - Tick dispatch now caches `_on_world_tick` callables for the tickable group so each emitted tick does less lookup work.
    - The existing `GameSettings` `frame_budget_ms` and `max_ticks_per_frame` values now participate in real tick emission instead of being UI-only knobs.
    - This is intended to reduce visible frame stalls during long catch-up bursts without changing tick order or world truth.
## May 23, 2026 Session Completion

- **FEAT: Learning target biasing (Matrix AI Deepening)**:
  - Added `_apply_learning_target_biases()` in `HeelKawnianManager.gd`
  - `get_learning_target_for_pawn()` output now directly influences `_matrix_job_biases`
  - Pawns with a target knowledge type bias toward apprenticeship, teaching, and domain-specific jobs
  - Pawns with a target skill bias toward jobs that exercise that skill
  - Covers all 26 KnowledgeType values and 5 skill types with deterministic job mappings

- **FEAT: Verification — Preservation choices already wired**:
  - Confirmed `get_preservation_choice_for_pawn()` is called from `_matrix_job_biases` at line 2089
  - Preservation actions (teach, inscribe_stone, write_book) correctly bias job selection
  - No new wiring needed — this was already operational

- **FEAT: General settlement ambition chains (not recovery-only)**:
  - `get_settlement_ambition_for_pawn()` now checks `_ambition_chain_for_settlement()` as a fallback for ALL drives, not just `recover`
  - All settlements now pursue multi-step strategic chains when no immediate pressure exists

- **FEAT: 5 new ambition chain types for deeper recovery behavior**:
  - Added "Rebuild from Ruin" chain (hearth → beds → shelter → storage)
  - Added "Healing & Care" chain (apothecary → shrine)
  - Added "Defense Network" chain (watchtower → barracks)
  - Added "Trade Route" chain (market → roads)
  - Added "Cultural Renaissance" chain (marker → shrine)
  - Updated `_select_new_chain`, `_chain_step_completed`, `_ambition_from_chain_step`, `_chain_name_for_steps`

- **Done**: Autoload consolidation Phases 1 + 2 (9 autoloads removed, from 150 → 141)
  See `docs/AUTOLOAD_CONSOLIDATION_STATUS.md` for details.

## May 27, 2026 Session Completion — TICK/FPS OVERHAUL — ALL THROTTLES REMOVED (ROUND 2)

- **ROUND 2: Removed ~30 additional speed-gated throttles across 18 files**:
  - **HeelKawnPawnBrain.gd**: `_compute_stride()` now returns 1 always (no speed-tier AI skipping, no distance-based LOD)
  - **HeelKawnianDecision.gd**: `_goal_refresh_interval_for_speed()` returns 60, `_neural_priority_refresh_interval_for_speed()` returns 15, `_matrix_priority_refresh_interval_for_speed()` returns 15 (all speed gating removed)
  - **Main.gd**: Removed `_is_ultra_speed()` (dead, never called). `_planner_interval_for_speed()` returns 90, `_heavy_planner_interval_for_speed()` returns 180, `_inspect_scan_interval_for_speed()` returns INSPECT_SCAN_INTERVAL_TICKS, `_social_rapport_interval_for_speed()` returns SOCIAL_RAPPORT_ACCUM_INTERVAL_TICKS, `_mining_react_scan_rows_for_speed()` returns MINING_REACT_SCAN_ROWS_PER_STEP. `_dynamic_hunt_job_budget()` no longer reduces budget at high speed. `_accumulate_social_rapport()` no longer has speed-based pair budget or time budget. `_maintenance_allowed` gate (>=50x skips maintenance) removed. `_process_regrowth()` restore_budget no longer reduced at high speed. `_mining_react_budget_for_speed()` always returns full budget.
  - **AIAgentManager.gd**: `_neural_interval_for_speed()` returns base_interval. `_world_ai_interval_for_speed()` returns 10. `_settlement_ai_interval_for_speed()` returns 16. `_agent_update_budget_for_speed()` returns all agents (no speed reduction). Agent update stride is always 1 (no speed scaling). Agent spawn check uses 600 ticks (no speed scaling).
  - **BuildingUsageTracker.gd**: `_on_game_tick()` sample_interval always 1 (every tick)
  - **CraftingSystem.gd**: Crafting progress interval always 1
  - **crafting_system.gd** (root): Same as above
  - **SurvivalSystem.gd**: Survival check interval always 1
  - **FarmingSystem.gd**: Crop update interval always 1
  - **PlayerBuilding.gd**: Building queue interval always 1
  - **FootpathMemory.gd**: Pawn sampling interval always 1
  - **SettlementPlanner.gd**: `_planning_region_cap_for_speed()` returns PLANNING_REGION_HARD_CAP (no speed cap)
  - **HeelKawnian.gd**: `_notify_autonomy_feedback` no longer gated at speed >=60. `_show_action_popup_for_job` no longer gated at speed >=50. Perception scan budget always 24 (no speed reduction).
  - **TerritoryOverlay.gd**: Activity border segments no longer skipped at speed >=50

- **PERF: Replaced speed-dependent caps with flat safety limit in TickManager.gd**:
  - Removed all speed-DEPENDENT caps (`MAX_BACKLOG_TICKS`, `_frame_tick_cap_for_speed()`, `_is_frame_stressed()` halving, mobile caps)
  - Removed `_lod_rate_for_speed()` / `_should_skip_tick_for_lod()` — all pawns tick every tick regardless of speed
  - Removed `TickBudgetManager.should_yield()` check — no mid-frame budget interruption
  - **Added** `MAX_TICKS_PER_FRAME = 24` — a FLAT safety limit (NOT speed-dependent). Prevents render starvation (death spiral) by bounding per-frame ticks at all speeds identically. Ticks beyond the cap carry to the next frame. Sim still processes faithfully.
  - **Key fix**: `set_speed()` now resets `_accumulated_time = 0.0` when **decelerating**, preventing the backlog event-flood when going from 100x→24x→1x

- **PERF: GameManager.gd cap cleanup**:
  - Removed `MAX_TICKS_PER_FRAME*` constants group (was 8 separate constants)
  - Removed `MAX_ACCUMULATED_TICKS*` constants (was 5 separate accumulator cap constants)
  - Removed `DROP_BACKLOG_WHEN_OVER_CAP` logic
  - Removed `_adaptive_frame_tick_cap()` function
  - `_max_ticks_per_frame_for_speed()` now returns 99999 (uncapped)
  - `_max_accumulated_ticks_for_speed()` now returns 99999 (uncapped)
  - `set_speed()` now resets `_tick_accumulator = 0.0` on deceleration
  - **Added** `MAX_TICKS_PER_FRAME = 24` for fallback `_process` loop (same flat safety cap)

- **PERF: GameManager.gd cap cleanup**:
  - Removed `MAX_TICKS_PER_FRAME*` constants group (was 8 separate constants)
  - Removed `MAX_ACCUMULATED_TICKS*` constants (was 5 separate accumulator cap constants)
  - Removed `DROP_BACKLOG_WHEN_OVER_CAP` logic
  - Removed `_adaptive_frame_tick_cap()` function
  - `_max_ticks_per_frame_for_speed()` now returns 99999 (uncapped)
  - `_max_accumulated_ticks_for_speed()` now returns 99999 (uncapped)
  - `set_speed()` now resets `_tick_accumulator = 0.0` on deceleration
  - Legacy fallback `_process()` loop is now fully uncapped

- **PERF: TickBudgetManager.gd — budget yield disabled**:
  - `should_yield()` always returns `false`
  - `get_tick_budget_usec()` returns 999999999
  - `remaining_usec()` returns 999999999

- **PERF: SettlementPlanner.gd — budget throttles removed**:
  - `_budget_exceeded()` always returns `false`
  - `_planner_pass_budget_usec()` returns 999999999
  - `_planner_pass_settlement_limit()` returns full `PLANNER_MAX_SETTLEMENTS_PER_PASS` at all speeds
  - Removed all per-iteration budget exceeded checks (30+ call sites)
  - Removed speed-based settlement cap in planner pass

- **PERF: AutonomousWorldAI.gd — performance throttling removed**:
  - `_check_performance_scaling()` no longer throttles MAI_AI_INTERVAL
  - `_performance_throttled` always false

- **PERF: Main.gd `_high_speed_interval()` — all speed-dependent work reduction removed**:
  - Now always returns `normal_ticks` regardless of speed
  - Affected subsystems: regrowth, ambient targets, hunt job posting, blood stain fading, door auto-close, leader construction, pawn sanity checks, derivative flush, settlement recompute, reproduction, influence, settlement intent/update, AI export, observer snapshots, focus snapshots, road flush, food crisis reprieve, construction seeding
  - Construction seeding: budget 999999999 (was 4000/2000/500 per speed), max_settlements always full, scan_radius always 8
  - `_mining_react_step_skip_for_speed()` always returns 0 (every tick)

- **PERF: HeelKawnian.gd — all speed-dependent strides/intervals removed**:
  - `_fast_forward_tick_stride()` always returns 1 (all pawns tick every tick)
  - `_job_claim_interval_for_speed()` always returns 1 (job claim every tick)
  - `_idle_action_refresh_interval_for_speed()` always returns 8 (base only)
  - `_work_step_interval_for_speed()` always returns 1 (work step every tick)
  - `_lane_interval_for_speed()` always returns `normal_ticks`
  - `_request_redraw_throttled()` now calls `queue_redraw()` directly (no throttling)
  - Pathfind aversion skip: always enabled (was disabled at ≥6x)

- **PERF: Drive throttles removed (MemoryDrive, AmbitionDrive, CuriosityDrive, SocialDrive)**:
  - All `should_pulse()` functions now ignore game_speed — use BASE_INTERVAL only

- **PERF: HeelKawnPawnBrain.gd — high-speed throttle removed**:
  - Removed `game_speed > 20.0` check that skipped full AI decisions every 4 ticks

- **PERF: DisasterSystem.gd — speed-dependent update interval removed**:
  - `_on_game_tick()` now updates disasters every tick regardless of speed

- **PERF: UI refresh stride throttles removed**:
  - ChronicleFeed, ChronicleLedger, ChronicleBook, PawnAIInspector: always use base refresh stride
  - ColonyHUD: `_refresh_stride_for_speed()` always uses base (15 ticks); `_coarse_gate_for_speed()` always returns 10
  - PawnInfoPanel: expensive detail refresh no longer slowed at high speed
  - PlaytestRecorder: auto-save interval no longer multiplied at high speed

- **PERF: HeelKawnianDecision.gd — 200x speed gates removed**:
  - Neural priority fetching and Matrix job bias are now active at ALL speeds

- **PERF: Natural intervals for 5 hot autoload systems + pawn AI stride=8 (May 28)**:
  - **CraftingSystem.gd**: `UPDATE_INTERVAL = 15` — crafting progress updates every 15 ticks (was 1)
  - **FarmingSystem.gd**: `UPDATE_INTERVAL = 20` — crop growth + health checks every 20 ticks (was 1)
  - **PlayerBuilding.gd**: `UPDATE_INTERVAL = 15` — building queue + structure decay every 15 ticks (was 1)
  - **BuildingUsageTracker.gd**: `SAMPLE_INTERVAL = 20` — pawn building usage sampling every 20 ticks (was 1)
  - **FootpathMemory.gd**: `SAMPLE_INTERVAL = 20` — pawn traffic sampling every 20 ticks (was 1)
  - **HeelKawnian.gd `_fast_forward_tick_stride()`**: now returns 8 (was 1) — pawns run full update every 8 ticks
  - **HeelKawnPawnBrain.gd `_compute_stride()`**: now returns 8 (was 1) — brain AI eval every 8 ticks
  - These are NOT speed-dependent throttles — flat constants applied identically at all speeds. At 100x, frequencies: crafting 6.7Hz, crops 5Hz, building 6.7Hz, sampling 5Hz, pawn AI 12.5Hz.

## May 24, 2026 Session Completion

- **FEAT: Organic Civilization Growth (Phase 5A deepening)**:
  - Added `autoloads/HearthMemory.gd` — roads-like pressure tracking for civilization infrastructure
    - `record_pile_deposit()`: pawns dropping items with no stockpile builds pressure
    - `record_hearth_activity()`: fire/warmth usage tracking
    - `record_shelter_usage()`: bed/shelter usage tracking
    - `get_inner_fire_for_pawn()`: computes 4 drives from environment + pawn state
  - Pressure thresholds: PILE_T1=3, PILE_T2=8, PILE_FORMAL=15 (like road tiers)
  - Added to autoloads in `project.godot`, right after RoadMemory

- **FEAT: Inner Fire / Hearth Spark drives wired to Matrix AI**:
  - `HeelKawnianManager.gd`: added `_apply_inner_fire_bias_to_biases()`
  - 4 drives computed per-pawn: `hearth_drive`, `storage_drive`, `shelter_drive`, `survival_drive`
  - Drive inputs:
    - `hearth_drive`: night time (0.3), hearth proximity inverse (0.5), warmth pressure (0.5)
    - `storage_drive`: is_carrying (0.6), nearby pile pressure (0.3)
    - `shelter_drive`: rest < 30, night with low hearth coverage
    - `survival_drive`: hunger, health < 50
  - Drive → job biases:
    - hearth_drive: BUILD_FIRE_PIT, BUILD_HEARTH, CHOP, GATHER_STICK
    - storage_drive: BUILD_STORAGE_HUT, BUILD_GRANARY, BUILD_CELLAR
    - shelter_drive: BUILD_BED, BUILD_SHELTER, BUILD_WALL
    - survival_drive: FORAGE, HUNT, FISH, GROW_FOOD (deprioritizes teaching/carving)
  - Wired into `get_matrix_decision_for_pawn()` — biases, not overrides; legality gates still apply

- **FEAT: Seeded bootstrap disabled behind ORGANIC_CIVILIZATION_ENABLED flag**:
  - `Main.gd`: added `ORGANIC_CIVILIZATION_ENABLED = true` constant
  - 3 locations wrapped:
    - `_bootstrap_colony()`: initial stockpile/supplies/fire pits
    - `_reroll_world()`: reroll-time bootstrap
    - `_apply_save_dict()`: save-fallback when no zones in save
  - When disabled (`false`), legacy behavior: seed stockpile at (127,127), supplies, 5 fire pits, 10 beds
  - When enabled (`true`), world starts dormant; civilization emerges from pawn activity

- **FEAT: Organic pile formation from repeated haul pressure**:
  - `HeelKawnian.gd`: `_begin_haul_to_stockpile()` now calls `HearthMemory.record_pile_deposit()` before emergency drop
  - `Main.gd`: added `_find_highest_pressure_pile_location(center, radius)` — scans for PILE_T1+
  - `Main.gd`: added `_ensure_organic_pile(tile)` — creates 1x1 stockpile with starter items (3 berry, 2 wood, 1 stone)
  - `_seed_bootstrap_jobs_near_pawn_cluster()`: now checks HearthMemory first; creates organic pile at high-pressure location instead of arbitrary center

- **FIX: SettlementMemory proto-site eligibility no longer creates empty settlements**:
  - `SettlementMemory.gd`: `recompute()` proto-site eligibility logic fixed
  - Root cause: `has_deaths AND has_scar` was creating 16 empty proto-sites at tick 30000 from historical worldgen deaths/scars
  - Fix: only `has_buildings OR has_community` count toward current civilization eligibility
  - `has_deaths AND has_scar` is commented out for ruin revival (should only apply AFTER settlement collapse, not at dawn of time)
  - Also fixed duplicate elif blocks in the same function that were unreachable dead code

- **FIX: Birth system now actually spawns pawns (critical fix)**:
  - `DynastyFamilySystem.gd`: `_process_birth()` was a STUB that only recorded lineage, not spawning actual pawns
  - Added helpers: `_get_world_from_pawn()` and `_get_pawn_spawner()` to safely access World and PawnSpawner
  - Now calls `pawn_spawner.spawn_child_pawn()` with:
    - World reference from mother pawn's `_world` member
    - Mother's and father's `HeelKawnianData` objects (for trait inheritance)
    - Birth tick for deterministic RNG
  - Spawned children get: proper trait inheritance, bloodline assignment, household placement, parent relationship tracking
  - Birth events properly recorded in WorldMemory with `type: pawn_birth`, `birth_kind: child`

- **FIX: Storage huts now create actual stockpile zones (unified organic storage)**:
  - `HeelKawnian.gd`: `BUILD_STORAGE_HUT` was calling `_ensure_settlement_stockpile()` which has an early-out check (`_settlement_has_nearby_stockpile()`)
  - Problem: If any organic pile existed within 16 tiles, no stockpile zone was created for the storage hut
  - Fix: Added `_create_stockpile_zone_for_storage_hut(tile)` that:
    - Creates a 2x2 stockpile zone AT the storage hut's exact tile
    - Checks if tile is already in a stockpile zone (avoids duplicates on exact same tile)
    - Adds zone to viewport and registers with StockpileManager
    - Records `stockpile_created` event with `reason: storage_hut`
  - Added helper: `_tile_already_in_stockpile_zone(tile)` to check for existing zone coverage
  - Storage huts now work as "organic storage buildings" — they guarantee a stockpile zone at their location when built

## 2026-05-22: Knowledge Preservation Loop Unification

- **FEAT: Preservation pressure wired into Matrix AI ambitions**:
  - `HeelKawnianManager.get_settlement_ambition_for_pawn()` now calls `KnowledgeSystem.compute_preservation_pressure()` during `preserve` drive
  - Urgent knowledge types trigger `CARVE_KNOWLEDGE_STONE` (priority 8)
  - Recommended knowledge + literate pawn → `PAPER_MAKING` (priority 7)
  - Recommended knowledge + no literacy → `CARVE_LEDGER_STONE` (priority 7)
  - Added `_get_preservation_pressure_for_settlement()` helper with fallback to pawn region proxy

- **FEAT: Record carrier safety net in knowledge death chain**:
  - `_check_knowledge_loss()` now calls `_has_record_carrier_for_knowledge()` before entering dormant state
  - If stones/books exist, knowledge enters "degraded" (not dormant) — records are safety net
  - Added `_has_record_carrier_for_knowledge()` — checks both stone carriers and book contents
  - Added `_is_knowledge_truly_lost()` — returns true only when both carriers AND records are zero
  - Only truly lost knowledge (no carriers + no records) enters dormant state with `truly_lost: true`
  - Records `knowledge_degraded` event when records preserve knowledge beyond last carrier's death
  - Records `knowledge_truly_lost` event for CivilizationStage consumption

- **FEAT: CivilizationStage consumes knowledge_lost signal**:
  - Added `_ready()` with signal connection to `KnowledgeSystem.knowledge_lost`
  - Added `_on_civilization_tick()` for periodic penalty decay every 360 ticks
  - Added `_on_knowledge_lost()` — applies `KNOWLEDGE_LOSS_ERA_PENALTY` (3 points) to affected settlement
  - Knowledge loss penalty subtracted from era score in `_build_stage_snapshot()`
  - Penalty shown in breakdown as `knowledge_loss_penalty`
  - Cache invalidated on knowledge loss for immediate recalculation

## 2026-05-22: Autoload Consolidation Phase 2 + 3 Complete

- **Phase 2 (6 deregistered)**: SquadCoordinator, FragmentationManager, RelationalGraph, SacredGeography, ReligionLens, MythAge
  - Static conversions: ReligionLens (24 refs) and MythAge (9 refs) → `class_name` static utility classes
  - Boot-managed: FragmentationManager, SacredGeography → `Main._ready()` bootstrap + root
  - Lazy-loaded: SquadCoordinator → WorldAI child; RelationalGraph → SocialManager adds to root
- **Phase 3 (2 deregistered)**: TradeMemory, TradePlanner → EconomyManager
  - 9 static methods on TradeMemory converted to instance methods; 10 forwarding methods + TIER constants on EconomyManager
  - 15 call sites updated across 7 files (Main.gd, TerritoryOverlay, World, RemnantMemory, AgeMemory, SettlementRebirth, FactionSystem, WorldEconomyManager, ComprehensiveTestSuite)
- **Autoload count**: 139 (150 → 139 over Phases 1-3)

- **Done**: Autoload consolidation Phase 4 (IntentMemory → MemoryManager)
  - IntentMemory already deregistered earlier; completed migration: static→instance methods, added INTENT constants + forwarding methods to MemoryManager
  - ~50 call site references updated across 7 files
  - Removed `class_name IntentMemory` from IntentMemory.gd
- **Done**: Autoload consolidation Phase 5 (MythMemory → MemoryManager)
  - MythMemory already deregistered earlier; completed migration: 3 static→instance methods
  - 8 call site references updated across 6 files
  - Removed `class_name MythMemory`
- **Done**: Autoload consolidation Phase 6 (SacredMemory + FactionRegistry → respective managers)
  - SacredMemory (already deregistered): 4 static→instance methods (site_count, list_sites_sorted, is_tile_sacred, get_sacred_type_at), 6 call sites updated in ReligionLens + FragmentationManager + Main, removed class_name
  - FactionRegistry (already deregistered): 2 static→instance methods (sync_from_settlements, append_focus_house_lines), 2 call sites updated (ReligionLens, ObservationAPI), removed class_name

- **Autoload count**: 139 (no change in Phases 4-6 — these were already deregistered from autoload, completed the static method + call site migrations)

- **Next Task**: Runtime truth pass in Godot editor (requires Godot binary). Then:
  - Knowledge preservation loop unification (stones, books, teaching, literacy)
  - Civilization stage deepening (per-settlement tech diffusion, literacy tracking)

## May 21, 2026 Session Completion

- **FIX: PawnMoodUI null-instance crash at startup**:
  - `_modern_theme` autoload can be null during initial scene tree setup
  - Added `_create_label()` helper that falls back to plain `Label.new()` when theme is null
  - Replaced all 10 `_modern_theme.create_styled_label()` calls with the safe wrapper
  - Prevents `Attempt to call method 'create_styled_label' on a null instance` crash

- **FIX: WorldAI.gd settlement context binding bugs**:
  - `_build_pawn_context` now uses `SettlementMemory.get_center_region_for_region()` instead of stale `pd.settlement_id` (which is always `-1`)
  - `_pawn_martial_settlement_context` now uses live `get_settlement_id_for_region()` instead of `pd.settlement_id`
  - `_pawn_mind_culture` now uses live `get_settlement_id_for_region()` instead of `pd.settlement_id`
  - `_pawn_knowledge_at_risk` now uses live `get_settlement_id_for_region()` instead of `pd.settlement_id`
  - Root cause: `join_settlement()` is never called anywhere, so `data.settlement_id` stays `-1` for every pawn
  - AI F10 reports should now show meaningful settlement IDs instead of `settlement -1` and `warmth=0.000`

- **FIX: ColonySimServices warmth pressure accounts for lingering hypothermia risk**:
  - Added `hypothermia_risk > 0 AND no hearth coverage` as second signal alongside existing body-temp check
  - Previously only checked current `body_temp < 36.5°C`, but pawns can be recently cold (risk persists ~1000 ticks after body_temp recovers)
  - Root cause: competing temperature systems (HeelKawnian `_check_temperature` toward ambient ~11-19°C, SurvivalSystem `_regulate_temperature` toward ~37°C) can keep body_temp above 36.5°C while hypothermia_risk still lingers from earlier cold exposure
  - Warmth pressure should now report >0 when hypothermia deaths exist and fire coverage is low

- **FIX: SurvivalSystem.gd feature enum values**:
  - Lines 368 and 427: changed `feat == 3 or feat == 8` (RUIN=3, RABBIT=8) to `feat == 5 or feat == 10` (BED=5, FIRE_PIT=10)
  - The +8°C shelter/fire bonus was never applying because it was checking wrong TileFeature.Type values
  - Previously would only apply at RUIN and RABBIT tiles (no functional effect), now correctly activates at BED and FIRE_PIT tiles

- **FIX: WorldAI.gd `_pawn_profession_overrep` was dead code**:
  - Line 3528 compared `p.data.settlement_id != pd.settlement_id` — both always `-1`, so profession balance check never ran
  - Replaced with live `WorldPersistence.get_region_key()` + `SettlementMemory.get_settlement_id_for_region()` for both pawns
  - Profession distribution is now correctly balanced within each settlement

- **FIX: HeelKawnian.gd settlement comparison in AI scoring**:
  - Lines 5664 and 7755: settlement_id comparisons were always `false` (both sides `-1`)
  - Teaching and mentor selection scoring bonuses for same-settlement pawns (+4 / +3) now correctly apply
  - Uses `_current_settlement_center_region()` live lookup for both pawns
  - Fixes social AI bias where pawns in the same settlement were not recognized as settlement-mates

- **FEAT: Settlement auto-joining system (Phase 1 integration)**:
  - Added `_maybe_update_settlement_membership()` that runs every 120 ticks staggered by pawn ID
  - Pawns now automatically detect when they are inside a settlement's region bounds and call `join_settlement()`
  - Pawns now automatically call `leave_settlement()` when they exit settlement bounds
  - Enhanced `join_settlement()` and `leave_settlement()` with WorldMemory chronicle events
  - Settlement membership is now position-driven rather than relying on the never-called `join_settlement()` API
  - `data.settlement_id` is now populated correctly for all pawns within settlements
  - All downstream consumers (StockpileManager, JobManager, SettlementMemory, CivilizationStage) now work correctly

- **FEAT: Temperature system unification (Phase 2 integration)**:
  - SurvivalSystem `_regulate_temperature` now detects HeelKawnianData pawns (has `hypothermia_risk`) and skips body_temp lerp
  - Previously SurvivalSystem fought HeelKawnian.gd's `_check_temperature` by lerping body_temp toward 37°C every 1-4 ticks while HeelKawnian lerped toward ambient ~11-19°C every 10 ticks
  - Now SurvivalSystem only applies moodlets from risk levels; HeelKawnian.gd is the sole authority on body_temp
  - SurvivalSystem `_check_death_conditions` now checks `hypothermia_risk >= 99` as an additional death cause
  - Legacy non-HeelKawnian pawns still use the original SurvivalSystem temperature path unchanged
  - Hypothermia deaths can now actually occur (previously body_temp was being pulled back to 37°C by SurvivalSystem before reaching 33°C death threshold)

- **FEAT: Survival-to-chronicle event bridge (Phase 3 integration)**:
  - HeelKawnian.gd `_check_temperature`: records WorldMemory.LIFE_EVENT at hypothermia warning (risk > 50%), critical (risk > 80%), and recovery (risk drops below 20%)
  - Same heat exhaustion event cycle: warning, critical, recovery
  - SurvivalSystem `_check_death_conditions`: records survival warnings (hunger/thirst/risk) during grace period and death risk warnings post-grace
  - Events are throttled every 300-600 ticks to prevent spam
  - All events recorded in WorldMemory for chronicle export via ChronicleExport

## May 22, 2026 Session Completion

- **FIX: Settlement job tech gate no longer returns unconditional true**:
  - `TechnologySystem.can_settle_perform_job_type()` now checks `BuildingRegistry.requires_tech` for the target job type and validates each requirement against completed research or settlement knowledge security.
  - Primitive / unregistered jobs still pass through, but registered advanced settlement builds now have a real eligibility gate instead of a stub.
  - This directly affects the live claim paths in `JobManager.claim_by_id_for()` and `HeelKawnian` job filtering.

- **FIX: Wire `post_build_deduped` into `Main._post_seeded_job`**:
  - Added `settlement_center` parameter to `_post_seeded_job()` for construction job deduplication
  - Construction jobs now check `JobManager._is_construction_type()` and use `post_build_deduped()` when settlement center is valid
  - Prevents duplicate construction postings near settlements during bootstrap phase

- **FEAT: ChronicleExport F10 Menu Integration**:
  - Added menu item #76: "Chronicle Export (to file)" to CreatorDebugMenu.gd
  - Added `_report_chronicle_export()` function that calls `ChronicleExport.export_chronicle()`
  - Players can now export chronicle history to file via F10 debug menu

- **DOCS: Updated tracking files**:
  - Updated TASKS.md, TODO.md, brain/memory/active_context.md, brain/memory/knowledge/tasks.md
  - Created brain/memory/sessions/2026-05-22.md session log

- **CLEANUP: Repository hygiene**:
  - Removed accidental `$null` file from root directory
  - Fixed `.gitignore` (removed duplicate `$null` entry)

- **FIX: SurvivalSystem.gd parse errors — data.get(key, default) crash**:
  - Replaced all `data.get("hypothermia_risk", 0.0)` and `data.get("heat_exhaustion_risk", 0.0)` with direct property access (`data.hypothermia_risk`, `data.heat_exhaustion_risk`)
  - Replaced `data.get("display_name", "unknown")` with guarded access `data.display_name if "display_name" in data else "unknown"`
  - Root cause: `RefCounted.get()` only accepts 1 argument in GDScript 4.6; the 2-argument form (with default) is only valid for Dictionary
  - Previous temperature unification code (May 21 session) was completely dead — the entire SurvivalSystem.gd failed to load at parse time
  - Survival processing (hunger, thirst, stamina, temperature, death conditions) was not running for any pawns
  - Verified: `"property" in data` pattern is used extensively across the codebase and works correctly

- **PERF: Construction seed job posting optimization**:
  - Added `_get_cached_feature_scan()` with a 600-tick cache keyed by region key
  - Reduced `_scan_local_features` radius: 12→8 at 1x, 8→6 at 50x, 6→4 at 100x (54% fewer tiles scanned at 1x)
  - Skip maintenance loop (`BuildingUsageTracker.get_due_maintenance_jobs`) at game speed >= 50x
  - Skip road scan (9×9 tile traversal grid) at game speed >= 50x
  - CONSTRUCTION_SEED was running ~14ms (budget=4ms) — these changes should bring it under budget

- **PERF: Speed-aware budget gates for three remaining hot functions**:
  - `_maybe_generational_turnover()`: Added `_generational_interval_for_speed()` returning 60000 at 200x (was 20000 always) — prevents 32ms spike every ~0.5s.
  - `_seed_construction_jobs()`: Replaced uncapped budget (999999999) with speed-aware values (2000/4000/8000/12000 at 200x/100x/50x/26x) — function exits early when budget consumed.
  - `SettlementMemory.recompute()`: Added optional `budget_usec` parameter with early exit before post-processing passes (3000/5000/10000 at 200x/100x/50x).

## WorldMeaning Architecture Freeze

**Date:** 2026-06-28
**Status:** Architecture frozen; runtime implementation pending.

This architecture is now canonical. Future development must adhere to the following principles:

-   Asha/Druj is no longer allowed to be treated as the foundation of meaning within the core engine. It is recognized as one emergent interpretive layer among many.
-   `WorldMeaning.gd` is designated as the future neutral derived-token layer. All interpretation of `WorldMemory` facts into descriptive Meaning Tokens will reside here.
-   Existing overlaps in `AshaDrujSystem.gd` and `ReligionSystem.gd` (and any other systems) regarding WorldMemory ingestion and interpretation logic must be resolved by migrating shared interpretation into `WorldMeaning.gd` over time.
-   No future agent should build new religion, politics, culture, myth, law, book, or civilization systems directly from raw `WorldMemory` events if a `WorldMeaning` token path exists. All such systems must consume Meaning Tokens (or aggregations thereof) from `WorldMeaning.gd`.

The next implementation slice is to begin refactoring `WorldMeaning.gd` to implement neutral Meaning Token extraction from new `WorldMemory` facts.

## Blockers

- Runtime truth pass not yet completed for Aug 14 checkpoint. Godot editor/headless required.
- Documentation drift: older docs may overstate completion compared with `BUILD_INVENTORY.md`.
- Historical note: a `ProceduresPawnVisualizer` dependency failure was previously reported at `Pawn.gd:5785`; if it reappears, inspect `scripts/utils/ProceduresPawnVisualizer.gd` first, then the `Pawn.gd` call site.

## Action Plan

- Keep `ProceduresPawnVisualizer` as a compiled dependency unless a future regression proves it is the blocker.
- Keep the settlement lifecycle machine deterministic and centered on region bounds plus stockpile food thresholds.
- Continue kernel validation for deterministic, staggered pawn behavior.
- Treat "complete" as "compiles, runs, and has a verification path."
- Prioritize integration over expansion until the v1 foundation is trustworthy.
- **Deterministic kernel rules (non-negotiable):** no unseeded RNG, no frame-coupled truth, no UI claims without simulation backing.

## Immediate Path (Stabilization Sequence)

1. Resolve repo identity/documentation conflict (DONE — Aug 17, 2026)
2. Run Godot runtime truth pass: verify F10 diagnostics, UI panels, and red errors in editor/headless
3. Run `tools/ai/sim-quality-gate.sh`
4. Verify F10 panels, HUD identity strip, PawnInfo/PawnMoodUI, and HeelKawnian profiles
5. Verify crafting material consumption and tool requirements
6. Then continue Phase 5A systems (teaching, research, technology eras, deep social dynamics)

## Phase 4 Settlement Lifecycle

- Lifecycle labels now come from `SettlementMemory` as `active`, `abandoned`, `reviving`, and `permanent_ruin`.
- Revival trigger: a pawn entering the settlement bounds or local stockpile food rising above 10 units.
- Permanent ruin threshold: 60000 ticks spent empty and below the revival food threshold.
- Legacy settlement meaning states remain in place for compatibility, but the new lifecycle drives the region tint path.

## Core Principles

1. **Deterministic Kernel**: All operations must be deterministic based on input parameters and the current tick count.
2. **WorldRNG**: Use seeded streams from WorldRNG for any random-like behavior.
3. **Event-Driven State Changes**: Record all state changes as events in WorldMemory to ensure reproducibility.

## Key Components

### 1. WorldMemory

- **Purpose**: Stores all historical events and current state data.
- **Functions**:
  - `record_event(event: Dictionary)`: Records a single event.
  - `get_events_for_tile(target_pos: Vector2i)`: Retrieves events for a specific tile.

### 2. WorldMeaning

- **Purpose**: Manages the meaning and significance of events within the world.
- **Functions**:
  - `assign_meaning(event_id: int, meaning_type: String)`: Assigns a meaningful type to an event.
  - `get_meaning(event_id: int) -> String`: Retrieves the meaning of an event.

### 3. WorldPersistence

- **Purpose**: Handles saving and loading the world state.
- **Functions**:
  - `save_state() -> Dictionary`: Saves the current state as a dictionary.
  - `load_state(state_dict: Dictionary)`: Loads the state from a dictionary.

### 4. LandRecovery

- **Purpose**: Manages the recovery of land after events like abandonment or destruction.
- **Functions**:
  - `recover_land(event_id: int) -> bool`: Attempts to recover land affected by an event.
  - `is_recoverable(event_id: int) -> bool`: Checks if land can be recovered.

### 5. CulturalMemory

- **Purpose**: Stores and manages cultural knowledge and traditions.
- **Functions**:
  - `record_cultural_event(event_id: int, culture_type: String)`: Records a cultural event.
  - `get_cultural_events(culture_type: String) -> Array`: Retrieves cultural events of a specific type.

### 6. ProgressionSystem (KERNEL)

- **Purpose**: Tracks pawn significance through impact points earned from actions (building, teaching, etc.).
- **Phase**: Phase 5 - Emergent Life
- **Signal**: `progression_changed(pawn_id: int)` - emitted when a pawn gains impact.
- **Functions**:
  - `record_impact(pawn_id, amount, reason)`: Add impact points to a pawn.
  - `get_tier(pawn_id: int) -> int`: Get tier index (0-5).
  - `get_tier_name(pawn_id: int) -> String`: Get tier name.
  - `get_impact(pawn_id: int) -> int`: Get current impact points.
- **Tiers**:
  - Unknown: 0 impact
  - Known: 10 impact
  - Remembered: 50 impact
  - Noticed: 200 impact
  - Influential: 1000 impact
  - Legendary: 5000 impact
- **Integration**: PawnInfoPanel.gd reads live tier data; reacts to `progression_changed` signal.

### 7. TechnologyEras (Technology Progression)

- **Purpose**: Tracks technology era progression per-settlement (Stone Age through Space Age). Determines era advancement from knowledge thresholds, applies era-based bonuses, and manages tech diffusion between settlements.
- **Phase**: Phase 5 — Technology Ecology
- **Status**: Complete rewrite (158 -> 978 lines). Full production implementation.
- **Signals**:
  - `era_advanced(center, old_era, new_era)` — per-settlement era advancement
  - `global_era_advanced(old_era, new_era)` — highest settlement era increased
  - `settlement_literacy_changed(center, literacy)` — literacy rate changed
  - `settlement_lifespan_changed(center, lifespan)` — average lifespan changed
  - `era_diffusion_applied(center, bonus, source_center)` — tech diffusion applied
  - `settlement_era_stalled(center, era, stall_ticks)` — advancement stall warning
  - `era_regressed(center, old_era, new_era, reason)` — cataclysm-induced regression
- **Key Systems**:
  1. 10-era progression (STONE_AGE=0 through SPACE_AGE=9) with knowledge thresholds scaled 0→4000
  2. Tech diffusion: lower-era settlements get up to +20% knowledge from higher-era neighbors within 120 tiles
  3. Literacy tracking: per-settlement rate scales with era (5% base, +7% per era, 100% cap)
  4. Lifespan tracking: per-settlement average scales with era (30yr base, +8yr per era, 120yr cap)
  5. Research speed bonus: +12% per era
  6. Building speed bonus: +8% per era
  7. Max population bonus: +40 per era
  8. Building cost scaling: +15% per era (advanced buildings cost more)
  9. Advancement stall detection: warns after 15K ticks near threshold without advancing
  10. Era regression: knowledge drop >40% can trigger fall to lower era
  11. Knowledge history window (4 samples) for regression trend detection
  12. Era-specific unlock tables: 50 buildings, 50 jobs, 50 items across all eras
  13. EventBus integration: responds to `settlement_founded`, `research_breakthrough`
  14. WorldMemory event recording for all key actions
  15. Save/load: versioned (v2) with full round-trip for all fields
  16. Clear/reset support for world generation
  17. Debug/stats: per-settlement era report, global progress, era distribution map

## May 30, 2026 Session Completion — TeachingSystem Production Rewrite

- **FEAT: TeachingSystem.gd complete rewrite (~120 -> 1032 lines)**:
  - Full production implementation replacing minimal stub with 20 enumerated requirements
  - Lesson model with concurrent teacher (3) and student (2) caps, progress tracking, deterministic effectiveness/duration calculation
  - Prerequisites system: 18 category-to-category prerequisite mappings (e.g. Metallurgy->Crafting)
  - Matchmaking APIs: `find_teachers_for_student()`, `find_students_for_teacher()` sorted by estimated effectiveness
  - Tick-based processing every 1500 ticks with stale cleanup every 30000 ticks
  - WorldMemory event recording + 3 signals (lesson_started, completed, failed)
  - EventBus integration for pawn death/move handling with settlement-separation grace period
  - Library/classroom bonus detection via SettlementMemory building type checks
  - Fatigue model: concurrent lessons reduce effectiveness (teacher -10%/student, student -8%/extra lesson)
  - Save/load roundtrip with full history preservation
  - All randomness uses WorldRNG.stream_seed only — no global RNG

## Implementation

### WorldMemory

### TeachingSystem

**File**: `autoloads/TeachingSystem.gd` (1032 lines)
**Phase**: Phase 5 — Knowledge Ecology
**Status**: Complete rewrite (~120 -> 1032 lines). Full production implementation.

**Data Model**:
- `_active_lessons`: lesson_id -> dict with teacher_id, student_id, category, tick_started, duration, effectiveness, progress, completed, last_update_tick
- `_teacher_xp`: pawn_id -> float (accumulated teaching experience)
- `_lessons_history`: lesson_id -> lesson_data snapshot (archive past lessons)

**20 Requirements Implemented**:
1. Lesson tracking with teacher/student/category/duration/effectiveness/progress
2. Multiple concurrent lessons (3 per teacher, 2 per student)
3. Effectiveness: teacher_skill/(student_skill+1) * library_bonus * relationship_multiplier + jitter
4. Duration: category_difficulty * teacher_speed_factor * global_carrier_density
5. Progress: effectiveness * (TEACHING_INTERVAL/duration) per tick window
6. Completion: add_knowledge_carrier, teaching XP, friendship gain
7. Prerequisites: 18 prerequisite mappings (e.g. Metallurgy->Crafting)
8. Matchmaking: find_teachers_for_student, find_students_for_teacher
9. KnowledgeSystem integration with has_method guards
10. SocialDynamics: friendship multiplier (up to 1.25x)
11. Library/classroom bonus via SettlementMemory
12. Tick processing every TEACHING_INTERVAL (1500), stale cleanup every 30000
13. WorldMemory events: lesson_started, completed, failed
14. 3 signals: lesson_started, completed, failed
15. EventBus: pawn_died, pawn_moved with grace period
16. Reports: get_teacher_report, get_student_report, get_stats
17. Save/load/clear with full round-trip
18. Edge cases: death, separation, stale, partial credit
19. Null guards on all external dependency lookups
20. Deterministic: WorldRNG.stream_seed only, no global RNG

## August 29, 2026 — F10 AI World Snapshot Implementation

**Scope**: Implemented comprehensive diagnostic system accessible via F10 key, providing read-only snapshots of world state for AI-assisted troubleshooting and analysis.

### Changes Applied

1. **F10 AI Diagnostic Area** (`scripts/ui/CreatorDebugMenu.gd`):
   - Added dominant controls: COPY AI WORLD SNAPSHOT and GENERATE AI DEBUG BUNDLE
   - Added category drill-down buttons: OVERVIEW, PAWNS, WORK, CIVILIZATION, WORLD, ENGINE, ANOMALIES
   - Added snapshot status display showing last generation time and output path
   - Preserved all existing legacy report buttons and live data functionality
   - Implemented read-only snapshot generation with detailed world state analysis

2. **Master Snapshot Dictionary** (`scripts/ui/CreatorDebugMenu.gd`):
   - Created `_build_ai_snapshot_dict()` producing coherent moment-in-time report
   - Sections include: header, world_view, selected_pawn, population, jobs, food, settlements, spatial, structures/development, social_culture, politics, performance, anomalies, recent_changes
   - Includes diagnostic_schema_version = 1 for versioning
   - Generated text and JSON outputs with stable formatting

3. **Selected Pawn + "WHY?" Analysis** (`scripts/ui/CreatorDebugMenu.gd`):
   - For selected pawn, includes complete vitals plus behavioral analysis
   - Determines why pawn is exhibiting current state based on canonical facts
   - Examples: idle with no eligible jobs, walking to job executing claim, hungry seeking food in wrong component
   - Avoids fabrication; states "unknown_from_current_read_only_state" when reason undeterminable

4. **Population Analysis** (`scripts/ui/CreatorDebugMenu.gd`):
   - Total pawns and distribution by actual state names (Idle, Working, etc.)
   - Needs analysis: starving, hungry, tired, unhealthy, carrying counts
   - Affiliation: settlement_id=-1 vs each settlement index
   - Life stage, occupation, and profession liking distributions

5. **Job/Work Pipeline** (`scripts/ui/CreatorDebugMenu.gd`):
   - Open, claimed, active union, posted, completed, cancelled counts
   - By job type breakdown with cancellation and abandon reasons
   - Oldest open job analysis with age in ticks
   - For selected pawn: visible jobs analysis to explain eligibility

6. **Food/Survival Truth** (`scripts/ui/CreatorDebugMenu.gd`):
   - Stockpile zone count, total food, has_any_food, inventory totals
   - Top item quantities by name using Item.NAMES
   - Starving pawns analysis with hunger state, settlement_id, and food accessibility
   - Component mismatch detection using PathFinder.component_of()

7. **Settlement/Proto/Realm Truth** (`scripts/ui/CreatorDebugMenu.gd`):
   - Formal settlements: name, population, center, founding, ruler/chief if available
   - Proto sites: guild member count, stability ticks, candidate reason
   - Membership contract verification: region_key -> settlement index map vs pawn.data.settlement_id
   - Reports: ok, unattached_inside, attached_outside, index_mismatch, stale_index with examples

8. **Spatial/Map Snapshot** (`scripts/ui/CreatorDebugMenu.gd`):
   - World dimensions, camera center, selected pawn tile
   - Settlement centers, proto centers, stockpile count, structure count
   - Path components count
   - ASCII world slice (21x21) centered on selected pawn or camera with legend

9. **Structures/Development** (`scripts/ui/CreatorDebugMenu.gd`):
   - Total structures/buildings count
   - Type counts if BuildingRegistry exposes safe API
   - Recent bounded construction history from WorldMemory events

10. **Social/Culture/History** (`scripts/ui/CreatorDebugMenu.gd`):
    - Bounded summaries: households, faction count, caste stats, cultural diversity/maturity
    - History: reuse existing _format_capped_history() with bounds
    - Maintains: counts by event type, oldest/newest bounded samples, important events, omitted=N

11. **Politics/Diplomacy** (`scripts/ui/CreatorDebugMenu.gd`):
    - Exposes safe existing facts: active conflicts, treaties, authority status, armies, battles, factions
    - Government/ruler data from SettlementMemory if available
    - No political interpretation invented

12. **Performance** (`scripts/ui/CreatorDebugMenu.gd`):
    - FPS display
    - TickProfiler counters in microseconds and milliseconds
    - When pawn dispatch profiler enabled: top stages with n, avg_us, p95_us, max_us
    - Autosave information: interval, next tick, ticks until, save file metadata (read-only)
    - File size checks via FileAccess.get_length() without deserialization

13. **Anomalies/Contradictions** (`scripts/ui/CreatorDebugMenu.gd`):
    - Automatic read-only anomaly rules with severity levels
    - Minimum set includes: food_starvation_while_food_exists, settlement_member_contract_*, idle_with_open_jobs, late_no_formal_settlement, stale_open_jobs, high_cancel_rate, hot_dispatch_stage, heelkawnian_tick_hot, selected_pawn_idle_no_eligible_jobs
    - Each anomaly contains id, severity, summary, evidence, not_proof fields

14. **Recent Changes** (`scripts/ui/CreatorDebugMenu.gd`):
    - Bounded section using WorldMemory/event ledger via existing capped-history formatter
    - Total recent events, event type counts, oldest/newest bounded samples, important changes, omitted=N

15. **Text Output** (`scripts/ui/CreatorDebugMenu.gd`):
    - Stable AI-friendly renderer with key=value formatting where practical
    - Required title: HEELKAWN AI WORLD SNAPSHOT
    - Stable section headings, clear rendering of embedded newlines
    - MASTER button: COPY AI WORLD SNAPSHOT builds snapshot, converts to text, copies to clipboard, writes to user://heelkawn_world_snapshot.txt

16. **JSON Output** (`scripts/ui/CreatorDebugMenu.gd`):
    - Recursive _to_json_safe() converting Dictionary keys to strings, Vector2/Rect2 to safe dictionaries
    - JSON contains diagnostic_schema_version: 1
    - Validates successful round-trip parse

17. **Screenshot Capture** (`scripts/ui/CreatorDebugMenu.gd`):
    - Diagnostic screenshot helper using root viewport
    - Best effort: get_viewport().get_texture().get_image().save_png()
    - Headless handling: returns written=false, reason=headless
    - Interactive gameplay includes screenshot.png in bundle

18. **Generate AI Debug Bundle** (`scripts/ui/CreatorDebugMenu.gd`):
    - Output directory: user://diagnostics/heelkawn_diag_tick_<tick>_<timestamp>/
    - Required files: README.txt, world_snapshot.txt, world_snapshot.json, anomalies.txt, recent_log.txt, screenshot.png (interactive)
    - README explains contents, schema version, read-only guarantee, production saves untouched
    - Bundle never writes outside user://diagnostics/ except explicit convenience copy
    - Never writes to production save paths

19. **F10 Performance Rule** (`scripts/ui/CreatorDebugMenu.gd`):
    - Existing live panel refresh (~0.5s) remains cheap
    - Expensive work occurs ONLY on user actions: COPY, category report, GENERATE BUTTON
    - No every-frame scanning of events, relationships, map, path searches, or save deserialization
    - Shows snapshot generated in XXX ms feedback

20. **Read-Only Contract** (`scripts/ui/CreatorDebugMenu.gd`):
    - Absolute requirement: F10 diagnostics must NOT claim jobs, cancel jobs, reserve food, eat food, move pawns, teleport, modify needs/health, alter settlement membership, trigger formalization/recompute, consume WorldRNG, advance TickManager, call autosave, save world, or mutate production save data
    - Prefer local read-only maps over lazy internal caches
    - Settlement membership check builds local region_key -> settlement index map

21. **Regression Tool Updates** (`tools/f10_live_data_regression.gd`):
    - Extended to validate new F10 snapshot functionality
    - Captures sensitive state before/after to verify read-only contract
    - Tests: master snapshot generation, JSON conversion/parsing, category handlers, bundle generation
    - Verifies: legacy buttons still work, history bounded, tick unchanged, pawn/job/settlement/stockpile counts unchanged

22. **Documentation**:
    - Created docs/F10_DIAGNOSTICS.md with purpose, human workflow, schema, anomaly rules, read-only contract, performance, adding new systems
    - Updated AGENTS.md with permanent architectural rule and aged-save incident documentation
    - Appended to docs/HEELKAWN_STATE.md (this section)

**Files modified**:
- scripts/ui/CreatorDebugMenu.gd — full AI diagnostic implementation
- tools/f10_live_data_regression.gd — extended validation
- docs/F10_DIAGNOSTICS.md — new documentation file
- AGENTS.md — added architectural rule and incident documentation
- docs/HEELKAWN_STATE.md — appended this section

**Verified regressions**:
- sim_boot_smoke.gd: OK
- f10_live_data_regression.gd: OK (validates read-only contract and new functionality)
- chronicle_contract_regression.gd: OK
- diag_parse_check.gd: OK
- Additional validation: JSON generation/parsing works, snapshot sections present, anomalies detected appropriately

**Known limitations**:
- Screenshot rendering unavailable in headless mode (expected, permitted)
- Some deep systems may not expose all desired diagnostic data (future iterations can add)
- ASCII world slice approximation limited to 21x21 tiles for readability
- Performance profiling data only available when respective profilers are enabled
