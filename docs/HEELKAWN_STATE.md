# HeelKawn State Management

**⚠️ IMPORTANT:** HeelKawn is **NEVER FINISHED**. It is a living, evolving simulation.
We are always building, always refining, always expanding. This document captures the
**CURRENT STATE** of an ongoing creative journey.

**Last Updated:** May 27, 2026
**Current Phase:** Consolidation + Phase 5A indefinite evolution foundation
**Overall Status:** Deep playable prototype with a stable kernel; not yet a final release candidate

**Read first:** [HEELKAWN_PROJECT_COMPASS.md](HEELKAWN_PROJECT_COMPASS.md) and [HEELKAWN_BLUEPRINT.md](HEELKAWN_BLUEPRINT.md) and [HEELKAWN_STATE.md](HEELKAWN_STATE.md) (this file)
**Latest verification snapshot:** [STATE_VERIFICATION_2026-05-27.md](STATE_VERIFICATION_2026-05-27.md)

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

- **Current Phase:** Consolidation + Phase 5A indefinite evolution foundation
- **Kernel Health:** 🟢 Stable enough for headless smoke
- **Compilation:** ✅ Headless Godot smoke passed on May 7, 2026 (re-run locally after May 19 construction/UI changes)
- **Project Shape:** Many live systems, some partial systems, and several design stubs
- **Truth Source:** Code/runtime first, then `BUILD_INVENTORY.md`, then this file
- **Runtime Contract:** `AGENTS.md` + `docs/AI_RUNTIME_MANDATE.md`
- **Quality Gate Command:** `bash tools/ai/sim-quality-gate.sh`
- Resolved Blockers:
  - Fixed Pawn parse errors that were cascading into job-system and UI dependency failures.
  - Verified `ProceduresPawnVisualizer` exists, exposes `class_name ProceduresPawnVisualizer`, and compiles cleanly.
  - Confirmed `Job.gd` and `JobManager.gd` compile cleanly after the Pawn dependency chain is restored.
  - Added the Phase 4 settlement lifecycle machine with active / abandoned / reviving / permanent ruin states.
  - Fixed profession lock bug (pawns were permanently locked into first profession, preventing role diversity).
  - Fixed event schema gap (FoodChainManager events now reach WorldMeaning via _infer_kind_from_type).
  - Relaxed neural bias speed gate from 50x to 200x so neural matrix contributes at normal play speeds.
  - Added profession reassignment so pawns can change roles when a non-primary skill outpaces their current profession.
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

## Blockers

- None currently reproducible in headless source validation.
- Documentation drift remains a project risk: older docs may overstate completion compared with `BUILD_INVENTORY.md`.
- Historical note: a `ProceduresPawnVisualizer` dependency failure was previously reported at `Pawn.gd:5785`; if it reappears, inspect `scripts/utils/ProceduresPawnVisualizer.gd` first, then the `Pawn.gd` call site.

## Action Plan

- Keep `ProceduresPawnVisualizer` as a compiled dependency unless a future regression proves it is the blocker.
- Keep the settlement lifecycle machine deterministic and centered on region bounds plus stockpile food thresholds.
- Continue kernel validation for deterministic, staggered pawn behavior.
- Treat "complete" as "compiles, runs, and has a verification path."
- Prioritize integration over expansion until the v1 foundation is trustworthy.

## Immediate Path

1. Runtime truth pass in Godot: verify F10 diagnostics, UI panels, and red errors.
2. HeelKawnian Matrix AI deepening: expand from job bias into teaching target selection, cooperation, recovery, household intent, and settlement ambitions.
3. Lineage/progression: finish parent lookup, child creation, inheritance hooks, and skill branches.
4. Material reality: connect crafting consumption to inventory/stockpile and tool requirements.
5. Knowledge preservation: unify stones, books, teaching, literacy, and rediscovery.
6. Civilization stage foundation: initial derived lens is live; deepen with per-settlement tech diffusion, literacy, lifespan, and institution data.
7. Readable exports: chronicle export and world seed/state export.

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

## Implementation

### WorldMemory
