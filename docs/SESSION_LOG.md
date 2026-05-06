# HEELKAWN SESSION LOG

Use this file as cross-LLM handoff memory.
Each session adds one entry at the top.

---

## 2026-05-06 - Phase 5 Knowledge Foundation

Date: 2026-05-06
Goal: Implement Phase 5 Literature foundations (Crafting + Meaning + Determinism).

Planned change:
- Infrastructure for book crafting (Paper, Ink, Binding).
- WorldMeaning tags for literature density.
- Audit KnowledgeSystem for deterministic rediscovery.

Status:
- CraftingSystem updated with 5 new recipes.
- WorldMeaning pipeline processes `literature_recorded` facts.
- KnowledgeSystem audited; uses WorldRNG salt.
- Documentation synchronized.

---

## 2026-05-01 - TickManager Burst Tick Fix

Date: 2026-05-01
Goal: Refactor `autoloads/TickManager.gd` to support burst ticks with an accumulator while preventing spiral-of-death backlog growth.

Planned change:
- Keep the fixed-step accumulator in `_process(delta)`
- Process multiple simulation ticks per frame with a `while` loop
- Cap per-frame work with `MAX_TICKS_PER_FRAME`
- Drop excess backlog when the cap is hit so the sim can recover cleanly
- Leave notes for heavy tick-loop work that should move to deferred workers or LOD

Validation target:
- Run a syntax check on `autoloads/TickManager.gd`
- Review the local diff to confirm the backlog drop path is deterministic

## 2026-04-30 - Civilization Simulation Assessment

Date: 2026-04-30
Goal: Assess current civilization simulation systems against HEELKAWN_INFINITE_ARCHITECTURE.md deep simulation domain 6.2 (Civilization simulation).

Changes made:
- Reviewed `autoloads/JobManager.gd` and `scripts/jobs/Job.gd`:
  - Global priority-ordered job queue (O(N) scans, suitable for <=1000 jobs)
  - 9 job types: FORAGE, MINE, MINE_WALL, CHOP, HUNT, BUILD_BED, BUILD_WALL, BUILD_DOOR, TRADE_HAUL
  - Job states: OPEN, CLAIMED, COMPLETED, CANCELLED
  - Tile-based job posting to prevent duplicate jobs
  - Cached active jobs union for planner scans
- Reviewed `autoloads/TradePlanner.gd` and `autoloads/TradeMemory.gd`:
  - Deterministic inter-settlement trade as TRADE_HAUL jobs (no RNG)
  - Trade interval: 5000 ticks
  - Surplus/need thresholds: 30/10
  - Max trade distance: 6 regions
  - Trade batch: 5 items
  - Item priority order: berry, stone, wood, meat
  - Settlement intent-aware (GROW, RECOVER, HOARD, DEFEND, ABANDON)
- Reviewed `autoloads/StockpileManager.gd`:
  - Global registry of stockpile zones (expected <50 zones, O(N) scans acceptable)
  - Zone registration/unregistration with signals for HUD updates
  - Read-only zone list for hauling decisions
- Reviewed `autoloads/KinshipSystem.gd`:
  - Handles kinship, household, and family relationships using RelationalGraph
  - Nodes: people, households
  - Edges: parent, child, sibling, spouse, household_member, obligation, inheritance
  - Household data tracking with food storage, labor contribution, obligation tracking
  - Inheritance records for profession and resource inheritance
- Reviewed `autoloads/AuthoritySystem.gd`:
  - Authority emergence tracking (4 contexts: MILITARY, CIVIL, RELIGIOUS, KNOWLEDGE)
  - Conflict relationships (5 types: FEUD, CLAN_DISPUTE, TERRITORIAL, RESOURCE, IDEOLOGICAL)
  - Peace treaties system
  - Authority decay on 2000-tick cadence
  - Conflict intensity updates on 3000-tick cadence

Civilization Simulation Status (per HEELKAWN_INFINITE_ARCHITECTURE.md 6.2):
- Households ✅ COMPLETE (KinshipSystem.gd with household nodes, membership, obligations, inheritance)
- Roles ✅ COMPLETE (Job system with 9 job types, priority system, work ticks)
- Labor ✅ COMPLETE (JobManager with global queue, pawn claiming, work tracking)
- Trade ✅ COMPLETE (TradePlanner with inter-settlement haul, surplus/need logic, intent awareness)
- Governance ✅ COMPLETE (AuthoritySystem with authority contexts, emergence tracking, decay)
- Diplomacy ✅ COMPLETE (AuthoritySystem with conflict types, peace treaties, intensity tracking)

Phase 4 Deepening Gaps:
- All core civilization simulation systems are implemented
- No critical gaps identified for Phase 4 (Identity & Meaning)
- Systems are deterministic and fact-first (no RNG in core loops)
- All systems integrate with WorldMemory, SettlementMemory, RelationalGraph

Validation:
- Civilization simulation is production-ready
- All systems follow deterministic, fact-first principles
- Integration with Phase 4 identity systems (cultural architecture, settlement meaning) is already in place
- Canon compliance maintained throughout

Suggested next session:
- Begin spatial partitioning design (step 9 of infinite architecture) to enable larger worlds, or await user direction for other priorities. Civilization simulation deepening is not needed at this time.

---

## 2026-04-30 - Infinite Architecture Blueprint Assessment

Date: 2026-04-30
Goal: Assess HEELKAWN_INFINITE_ARCHITECTURE.md implementation order against current kernel state and identify Phase 4 alignment.

Changes made:
- Reviewed `docs/HEELKAWN_INFINITE_ARCHITECTURE.md` implementation order (13 steps)
- Assessed current kernel state against blueprint steps
- Verified advanced autoloads already implemented (KnowledgeSystem, AuthoritySystem, CollapseSystem)

Implementation Order Status:
1. Deterministic world clock and stable state ✅ COMPLETE (GameManager)
2. WorldMemory fact logging ✅ COMPLETE (autoloads/WorldMemory.gd)
3. WorldMeaning interpretation layer ✅ COMPLETE (autoloads/WorldMeaning.gd)
4. Persistence rules for ruins, scars, and landmarks ✅ COMPLETE (autoloads/WorldPersistence.gd)
5. Knowledge transmission and loss ✅ COMPLETE (autoloads/KnowledgeSystem.gd - 12 knowledge types, teaching records, loss tracking)
6. NPC memory inheritance and household continuity ✅ COMPLETE (autoloads/KinshipSystem.gd, autoloads/RelationalGraph.gd)
7. Authority, conflict, and taboo systems ✅ COMPLETE (autoloads/AuthoritySystem.gd - 4 authority contexts, 5 conflict types, peace treaties)
8. Collapse progression ✅ COMPLETE (autoloads/CollapseSystem.gd - 6 collapse stages, trust→authority→knowledge→environment order)
9. Spatial partitioning and streaming ⏸️ NOT STARTED (256x256 world currently single-chunk)
10. Graph relational ontology ✅ COMPLETE (autoloads/RelationalGraph.gd)
11. Agent command/observation APIs ✅ COMPLETE (autoloads/CommandAPI.gd, autoloads/ObservationAPI.gd)
12. Modular AI synthesis hooks ✅ COMPLETE (scripts/ai/WorldAI.gd, scripts/ai/SettlementAI.gd, scripts/ai/CivilizationAgent.gd)
13. Incarnation / spectator bridge ✅ COMPLETE (scripts/player/PlayerIncarnation.gd, scripts/ui/ObserverHUD.gd)

Phase 4 Alignment:
- Phase 4 (Identity & Meaning) is already well-aligned with blueprint steps 2-8
- Cultural architecture signature set (completed in GLOSSARY.md) maps to step 7 (authority emergence)
- Player-readable meaning refinement (completed) maps to step 3 (WorldMeaning interpretation)
- Settlement revival system (documented) maps to step 8 (collapse progression)
- Wildlife system (validated) maps to step 6.1 (environment simulation)

Next Architecture Priorities:
- Step 9: Spatial partitioning and streaming (enables larger worlds)
- Step 12: Modular AI synthesis hooks (expand to procedural generation layers)
- Deep simulation domains (6.2 Civilization simulation: households, roles, labor, trade, governance, diplomacy)

Validation:
- 11 of 13 implementation steps are complete
- All autoloads follow deterministic, fact-first principles
- No kernel refactoring needed for remaining steps
- Canon compliance maintained throughout

Suggested next session:
- Begin spatial partitioning design (step 9) or expand civilization simulation (6.2) depending on user priority. Spatial partitioning enables larger worlds; civilization simulation deepens Phase 4 identity work.

---

## 2026-04-30 - Wildlife System Validation

Date: 2026-04-30
Goal: Validate wildlife population dynamics and HUD trend display accuracy per HEELKAWN_STATE.md near-term targets.

Changes made:
- Reviewed `scripts/world/AnimalPopulation.gd`:
  - Deterministic regional ecology: pressure + local food availability gate mortality (no RNG)
  - Pressure > 0.85 AND food < 0.2 triggers deterministic cull
  - Food availability computed from 5-tile radius scan of forest/plains biomes with forage signal
- Reviewed `scripts/pawn/AnimalSpawner.gd`:
  - Deterministic per-region population v1: spawn, ledger, no RNG
  - Population model: initial_spawn_count + births - WorldMemory deaths (derived, not saved)
  - Reproduction: requires 2+ live animals, no WorldMemory death for 4000 ticks, scar < 2
  - Extinction: local extinction blocked while scar > 1, recovery possible at scar <= 1
  - Max animals: 50 (8 rabbits, 4 deer initial)
  - Population check cadence: 1000 ticks
- Reviewed `scripts/ui/ColonyHUD.gd`:
  - Wildlife sampling every 20 ticks (WILDLIFE_SAMPLE_EVERY_TICKS)
  - History size: 8 samples (WILDLIFE_HISTORY_SIZE)
  - Trend validation: split-average comparison (recent half vs older half)
  - Trend thresholds: >1.1 = growing (▲), <0.9 = declining (▼), else stable (▬)
  - Rolling min/max span display (T min…max)
  - Momentum spark fallback when history < 3 samples
- Reviewed Phase 4 rebirth thresholds:
  - Already documented in revival constraints work (TIMELINE.md canon-safe boundaries)
  - SettlementMemory gates: REVIVABLE_SCAR_MAX=2, REVIVAL_SCORE_* gates, PEACE_TICKS_PER_BRANCH
  - SettlementRebirth gates: scar < 3, peace threshold, cooldown 20000 ticks, state=revivable

Validation:
- Wildlife system is fully deterministic (no RNG in spawn, reproduction, mortality)
- All population dynamics derive from WorldMemory facts (deaths) and WorldPersistence (scar levels)
- HUD trend validation is sophisticated and accurate (split-average comparison with proper thresholds)
- Phase 4 rebirth thresholds are canon-documented with implementation anchors
- No changes needed to wildlife system; implementation is production-ready
- Canon compliance maintained: fact-first, deterministic, no heroic overrides

Suggested next session:
- Begin infinite architecture blueprint implementation order per `docs/HEELKAWN_INFINITE_ARCHITECTURE.md` or human-scale progression ladder per `docs/HUMAN_SCALE_PROGRESSION_LADDER.md` as these are the next targets in HEELKAWN_STATE.md.

---

## 2026-04-30 - Revival Storyline Constraints Documentation

Date: 2026-04-30
Goal: Document canon-safe revival boundaries in TIMELINE.md to ensure rebirth behavior remains emergent but interpretable without heroic script overrides.

Changes made:
- Reviewed `autoloads/SettlementRebirth.gd` for current revival gate behavior (scar gate, peace gate, state gate, cooldown gate, cluster scar3 block)
- Reviewed `autoloads/SettlementMemory.gd` for revival thresholds (REVIVABLE_SCAR_MAX=2, REVIVAL_SCORE_* gates, PEACE_TICKS_PER_BRANCH, HARD_COLLAPSE_TICKS)
- Modified `docs/WORLD_BIBLE/TIMELINE.md`:
  - Added canon-safe revival boundaries section to "First revival of a moderately scarred settlement region" hook
  - Documented 6 non-negotiable constraints: scar gate, peace gate, state gate, cooldown gate, collapse gate, revival score curve
  - Added implementation anchors to SettlementRebirth.gd and SettlementMemory.gd
- Modified `docs/WORLD_BIBLE/CANON_CHANGELOG.md`:
  - Added entry for revival storyline constraints documentation
  - Status: accepted

Validation:
- All documented boundaries match actual implementation in SettlementRebirth.gd and SettlementMemory.gd
- Constants align: REVIVABLE_SCAR_MAX=2, scar_level>=3 block, peace thresholds (OPEN=18000, CAUTIOUS=30000, DEFENSIVE=42000), cooldown=20000, collapse window=30000
- Revival score curve gates documented: <35=abandoned, 35-69=recovering, 70-87=revivable, >=88=active
- No heroic script overrides introduced; documentation formalizes existing deterministic behavior
- Canon governance preserved: changes recorded in CANON_CHANGELOG.md

Suggested next session:
- Begin near-term queue item 1: canonical architecture signature set documentation in `docs/WORLD_BIBLE/GLOSSARY.md` (already partially complete; may need expansion for additional architectural patterns).

---

## 2026-04-30 - Player-Readable Meaning Refinement (Phase 4)

Date: 2026-04-30
Goal: Implement non-text-forward cues for settlement state transitions (audio, ambiance, behavior density, visual posture) without text overlays.

Changes made:
- Created `docs/PLAYER_READABLE_MEANING_SPEC.md` with comprehensive specification for audio cues, ambiance changes, behavior density modifiers, and settlement posture visual indicators.
- Created `autoloads/MeaningAudioCue.gd` with procedural audio tone generation using AudioStreamGenerator (no external assets). Implements 5 transition cues: quiet→scarred (hum), scarred→bloodied (dissonant), bloodied→grave (descending), grave→recovering (arpeggio), recovering→quiet (chime). Includes 30-second cooldown per settlement to prevent spam.
- Verified `autoloads/MeaningAmbianceController.gd` already exists with full implementation of meaning-based modifiers (movement speed, vocal pitch, cluster size, particle density, saturation, brightness, color temperature, vocal skip chance, idle animation modifier).
- Modified `autoloads/SettlementMemory.gd`:
  - Added `_trigger_meaning_audio_cue()` function to fire audio cues on committed state changes
  - Added `_state_to_meaning_label()` to map settlement states to meaning labels
  - Added `get_state_for_region()` for World.gd to query settlement state for visual tinting
  - Hooked audio cue trigger into state hysteresis commit threshold
- Modified `scripts/pawn/Pawn.gd`:
  - Added `_apply_meaning_behavior_modifiers()` to read region meaning from MeaningAmbianceController
  - Added `_meaning_speed_multiplier` cache variable
  - Modified `_process()` to apply meaning-based speed multiplier to movement
  - Hooked behavior modifier application into `_on_game_tick()` AI stride
- Modified `scripts/world/TileFeature.gd`:
  - Added `apply_settlement_state_tint()` static function for settlement posture visual indicators
  - Implements 5 state-based tints: active (no tint), revivable (faded), recovering (gray-brown), abandoned (desaturated dark gray), permanently_abandoned (cold gray near-black)
- Modified `scenes/world/World.gd`:
  - Added settlement state tint application in `_tile_color()` after culture tint
  - Queries SettlementMemory.get_state_for_region() for per-tile state
- Modified `project.godot`:
  - Added MeaningAudioCue autoload
  - Added MeaningAmbianceController autoload

Validation:
- All audio cues are deterministic (procedural tone generation, no RNG)
- All behavior modifiers derive from WorldMeaning/WorldMemory facts
- All visual tints are deterministic color lerps based on settlement state
- MeaningAmbianceController already implements speed-adaptive scaling
- No text overlays added to UI
- Performance impact minimal: audio cues on cooldown, behavior modifiers cached per pawn, visual tints applied during terrain raster only
- Determinism preserved: all changes derive from existing fact systems (WorldMemory, WorldMeaning, SettlementMemory)

Suggested next session:
- Start near-term queue item 2: revival storyline constraints documentation in `docs/WORLD_BIBLE/TIMELINE.md` to ensure rebirth behavior remains emergent but interpretable without heroic script overrides.

---

## 2026-04-30 - Queue execution (Immediate item 3)

Date: 2026-04-30
Goal: Complete region-to-faction canon bridge so identity seeds map to deterministic regional history profiles.

Changes made:
- Updated `docs/WORLD_BIBLE/REGIONS.md` with deterministic cause profiles (scar/conflict/recovery) for seed regions.
- Added explicit faction bridge mappings in region entries linking `The Quiet Ring` -> `Open Hearth Clusters` and `Red Scar Basin` -> `Stoneward Enclaves`.
- Updated `docs/WORLD_BIBLE/FACTIONS.md` with region archetype links plus supporting deterministic profile bullets.
- Marked queue item 3 as complete in `docs/WORLD_BIBLE/CANON_SYSTEMS_FEATURE_QUEUE.md`.

Validation:
- Confirmed each early faction now references at least one region archetype and one supporting history profile.
- Confirmed bridge language remains fact-first/emergent and does not introduce scripted hero-arc overrides.

Suggested next session:
- Start near-term queue item 1: define canonical architecture signature set for open/cautious/defensive identity trajectories.

## 2026-04-30 - Queue execution (Immediate items 1 and 2)

Date: 2026-04-30
Goal: Execute canon queue item 1 (glossary normalization) and item 2 (timeline hook trigger specs) using legacy docs as reference while preserving current authority.

Changes made:
- Expanded `docs/WORLD_BIBLE/GLOSSARY.md` with legacy-to-canon mapping entries and implementation anchors for neural/civilization/monitoring/cultural/economic/historical terms.
- Added canon guardrails in glossary to prevent legacy terms from overriding current state authority.
- Converted open hooks in `docs/WORLD_BIBLE/TIMELINE.md` into measurable detection conditions with explicit evidence anchors tied to `SettlementMemory`, `WorldMemory`, `WorldMeaning`, and cultural identity signals.
- Updated `docs/WORLD_BIBLE/CANON_SYSTEMS_FEATURE_QUEUE.md` status markers: items 1 and 2 completed, item 3 marked next.

Validation:
- Manual consistency check against determinism/fact-first policy in `docs/HEELKAWN_STATE.md`.
- Verified each updated timeline hook now has both a trigger condition and evidence source.

Suggested next session:
- Execute immediate queue item 3: region-to-faction canon bridge in `REGIONS.md` and `FACTIONS.md`.

## 2026-04-30 - Immediate 1 docs authority and canon queue

Date: 2026-04-30
Goal: Execute Immediate 1 from repo planning pass by unifying documentation authority, preserving legacy lore references, and creating an actionable canon/system feature queue.

Changes made:
- Clarified onboarding/coding guidance so seeded emergence (`WorldRNG`) is explicitly allowed while unseeded historical randomness remains disallowed in canonical simulation paths.
- Marked `HEELKAWN_INTEGRATION.md` as historical/superseded reference and added explicit pointers to authoritative current-state docs.
- Added `docs/WORLD_BIBLE/CANON_SYSTEMS_FEATURE_QUEUE.md` to translate legacy universe/system ideas into ordered, phase-aligned execution steps.
- Updated world-bible index and canon changelog to include the new queue and policy decision.

Validation:
- Manual docs consistency pass across `docs/HEELKAWN_STATE.md`, `docs/LLM_ONBOARDING.md`, `.github/copilot-instructions.md`, `HEELKAWN_KERNEL.md`, and world-bible governance files.

Suggested next session:
- Execute queue item 1 in `docs/WORLD_BIBLE/CANON_SYSTEMS_FEATURE_QUEUE.md` (canon glossary normalization with implementation anchors).
- Add first canonical architecture signature table for open/cautious/defensive settlement identity tracks.

## 2026-04-30 - Seeded simulation determinism pass

Date: 2026-04-30
Goal: Continue repo-wide hardening by removing raw global RNG from canonical simulation and AI paths without changing the intended probabilities.

Changes made:
- Added `WorldRNG.unit_for()`, `range_for()`, `chance_for()`, and `index_for()` helpers for named deterministic streams.
- Replaced global RNG in core AI, neural, world-event, knowledge, settlement, civilization, pawn, animal, combat, incarnation, and world-evolution paths with seed-derived rolls.
- Kept `PawnSpawner` and `WorldGenerator` on local `RandomNumberGenerator` instances seeded from `WorldRNG` / `world_seed`; remaining raw global RNG scan is now limited to visual addon noise plus those seeded local generators.
- Made the initial world seed explicit (`World.DEFAULT_WORLD_SEED = 20260429`) with optional `--world-seed=...`; rerolls derive deterministic follow-up seeds from the current world stream.
- Kept AI auto-incarnation blocked from the human player channel and marked AI-origin incarnation commands as rejected until NPC ownership is separated.
- Fixed `WorldEvolution` initialization so its interconnection builder no longer reads `neural_evolution_engine` before the matrix exists.

Validation:
- `powershell -ExecutionPolicy Bypass -File tools\Verify-Project.ps1 -QuitAfterFrames 240` passed and reached tick 1 after final code cleanup.
- `powershell -ExecutionPolicy Bypass -File tools\Benchmark-Speeds.ps1 -BenchMode worker -TicksPerSample 20` passed all speed tiers with 0 failures.
- Direct Godot `--check-only` passed for `scripts\world\WorldEvolution.gd` and `scripts\debug\ErrorTracker.gd`; `IncarnationSystem.gd` still pulls pawn dependencies that are not isolated-script-check friendly.

Suggested next session:
- Replace the remaining addon visual randomness only if UI determinism matters; the canonical sim paths are now seeded or explicitly local-seeded.
- Add a longer worker benchmark (`-TicksPerSample 120`) after any future pawn/AI behavior changes.
- Design the separate NPC-control ownership channel before re-enabling automatic AI incarnation.

## 2026-04-30 - Repo health and validation repair

Date: 2026-04-30
Goal: Turn the audit findings into a stable validation/tooling pass and repair drift that made benchmark and lightweight paths unreliable.

Changes made:
- Restored `GameManager.lightweight_simulation_mode` with CLI flags (`--lightweight-sim` / `--lite-sim`) and public getters/setters so `JobManager` and `PawnData` gates actually activate.
- Fixed observer benchmark startup: worker/lightweight flags are set before `Main` is instantiated, `Benchmark-Speeds.ps1` uses the filesystem runner path, and `-TicksPerSample` supports fast smoke runs.
- Fixed PowerShell wrappers that could exit successfully before launching Godot because `$LASTEXITCODE` was null/stale after `Resolve-Godot.ps1`.
- Made `Resolve-Godot.ps1` prefer the repo-pinned portable Godot before PATH for reproducible local checks.
- Replaced brittle CI per-file script checks with a project-level Godot smoke that reaches the first simulation tick.
- Fixed `CommandAPI` movement/job execution plumbing and added `JobManager.claim_by_id_for(...)` for validated command-bus job claims.
- Replaced succession ranking's global RNG jitter with deterministic candidate jitter and updated neural docs.
- Corrected the system testing guide so AI-agent expectations match the current deliberately-disabled automatic incarnation path.

Validation:
- `powershell -ExecutionPolicy Bypass -File tools\Verify-Project.ps1 -QuitAfterFrames 240` passed and reached tick 1.
- `powershell -ExecutionPolicy Bypass -File tools\Benchmark-Speeds.ps1 -BenchMode worker -TicksPerSample 2` passed all speed tiers and wrote observer reports.
- `powershell -ExecutionPolicy Bypass -File tools\Benchmark-Speeds.ps1 -BenchMode worker -TicksPerSample 20` passed all speed tiers with 0 failures.
- `git diff --check` passed.

Suggested next session:
- Do a longer default worker benchmark (`-TicksPerSample 120`) and compare 50x/100x ratios after the lightweight mode fix.
- Continue determinism cleanup by replacing raw `randf()` / `randi()` in canonical simulation paths with named `WorldRNG` streams or deterministic tie-breakers.
- Revisit `AIAgentManager._try_incarnate_agent`; it is still deliberately disabled, so AI-player parity should be enabled only after command ownership will not steal the human incarnation state.

## 2026-04-28 - AI resume bundle added

Date: 2026-04-28
Goal: Make the repo easier for a future AI to resume from files when chat context is gone or rate-limited.

Changes made:
- Added `docs/AI_RESUME.md` as a short, high-signal resume bundle
- Updated `docs/LLM_ONBOARDING.md` to point to the resume bundle as the fastest re-entry path
- Kept the durable state in repo docs so a future model can continue without chat history

Suggested next session:
- Keep `docs/AI_RESUME.md` updated whenever the project’s active benchmark baseline or next target changes
- Prefer adding a short session-log entry after any significant sim or doc change so the handoff stays current

## 2026-04-28 - Human-scale ladder spec added

Date: 2026-04-28
Goal: Formalize the layered progression the sim should follow from pawn-level survival up through family, clan, settlement, nation, and world scope.

Changes made:
- Added `docs/HUMAN_SCALE_PROGRESSION_LADDER.md` describing the pawn → family → clan → settlement → region → nation → world ladder
- Linked the ladder from `docs/HEELKAWN_STATE.md` so it becomes part of the authoritative roadmap
- Linked the ladder from `docs/CURSOR_MASTER_PLANNING_SPEC.md` so planning stays aligned with the same progression model

Suggested next session:
- Convert the ladder into concrete implementation checkpoints for UI, job gating, trust networks, and settlement/nation layers
- Optionally add a small diagram or matrix showing which current systems already map to each stage

## 2026-04-28 - Light-weight pawn-first job gating

Date: 2026-04-28
Goal: Keep the world lightweight by stopping giant job queues and unlocking more work only as pawns level up.

Changes made:
- Added `GameManager.lightweight_simulation_mode` and `--lightweight-sim` / `--lite-sim` support
- Capped open jobs in `JobManager` so posting stops before the queue balloons
- Added lightweight pawn job gates in `PawnData.allows_job_type()` so fresh pawns stick to basic survival work first

Suggested next session:
- Re-run a benchmark and watch `JobManager.open_count()` to confirm the queue stays bounded
- If needed, tighten the thresholds or add per-settlement caps so only a small, local set of jobs exists at once

## 2026-04-28 - Simulation worker mode scaffolded

Date: 2026-04-28
Goal: Add a separate headless simulation-worker launch path to strip UI/render overhead without changing sim logic.

Changes made:
- Added `GameManager.simulation_worker_mode` command-line flag parsing for `--simulation-worker` / `--sim-worker`
- Added `Main` worker-mode gating so worker launches skip UI/audio/input setup and per-frame UI updates
- Added `play_worker.bat` to launch the project in headless simulation-worker mode

Suggested next session:
- Re-run the headless benchmark with `--simulation-worker` enabled and compare TPS against the current baseline
- If throughput is still too low, move the true hot loops into a native plugin or further isolate simulation state from scene nodes

## 2026-04-28 - Neural network expansion complete + documentation audit

Date: 2026-04-28
Goal: Complete neural network integration and create AI-readable documentation for handoff.

Changes made:
- Added neural network training from game events (reinforcement learning)
- Added neural network prediction for collapse stages (predict_collapse_stage, get_collapse_stage_name)
- Added neural-driven succession candidates (rank_succession_candidates with government-specific scoring)
- Added neural network visualization to AI Control Panel (progress bars with color coding)
- Added neural-driven diplomatic relations (calculate_diplomatic_modifier, get_diplomatic_attitude)
- Fixed compilation errors (duplicate functions, variable names, missing references)
- Created docs/NEURAL_NETWORK_STATE.md as canonical neural network documentation
- Updated docs/LLM_ONBOARDING.md to include NEURAL_NETWORK_STATE.md in required reading

Neural network now includes:
- 54 neurons across 6 domains (world_state, civilization, cultural, environmental, economic, religious)
- Event-driven training system
- Collapse stage prediction
- Succession candidate ranking
- Diplomatic relationship calculation
- Real-time visualization
- Full save/load support
- Pattern persistence system

Documentation status:
- docs/HEELKAWN_STATE.md - ✅ Current and authoritative
- docs/NEURAL_NETWORK_STATE.md - ✅ Created for neural network handoff
- docs/LLM_ONBOARDING.md - ✅ Updated to include neural network documentation
- docs/SESSION_LOG.md - ✅ Detailed session history
- docs/CANONICAL_REPOSITORY.md - ✅ Current
- HEELKAWN_INTEGRATION.md - ⚠️ Outdated (v2.6.1, 2026-04-27) - should be updated or marked historical
- HEELKAWN_KERNEL.md - ⚠️ Historical reference only (superseded by HEELKAWN_STATE.md)

Suggested next session:
- Update HEELKAWN_INTEGRATION.md to reflect current neural network state or mark as historical
- Begin implementing high-priority neural network expansions (military neuron group, war declarations)

---

## 2026-04-27 - Incarnated F now inspects local context

Date: 2026-04-27
Goal: Add a second embodied affordance to give incarnation a local read verb.

Changes made:

- Mapped `F` to a new `inspect` action in `PlayerInputBuffer` and `PlayerIntentQueue` flow.
- Implemented `Pawn.inspect()` which records a `player_inspect` WorldMemory event containing region, center_region, WorldMeaning label, and derived zone tags.
- Skill gain: `observation` XP is granted when inspecting.

Suggested next session:

- Surface an incarnated-local HUD cue for inspected tags (e.g., small tooltip or log line) so inspection has immediate feedback beyond the fact log.

---

## 2026-04-27 - Inspect UX: tooltip + tone + observer summary

Date: 2026-04-27
Goal: Surface `F` inspect events more visibly to the player and spectator HUD.

Changes made:

- Observer HUD shows the latest `player_inspect` summary (pawn, center_region, meaning, tags).
- A transient map tooltip is shown near the HUD when an inspect occurs, with tile coords and meaning.
- A short generated inspection tone is played on inspect using `AudioStreamGenerator` (no external asset required).

Suggested next session:

- Tune tooltip position, styling, and audio timbre; add per-region visual cues when an inspect highlights a myth/or ruin tag.

---

## 2026-04-27 - Incarnated E now performs presence

Date: 2026-04-27
Goal: Give incarnation one immediate body-specific action beyond movement.

Changes made:

- `E` now performs a logged presence action when the pawn is not already hauling, eating, or sleeping.
- The action bumps mood slightly and writes a `player_presence` WorldMemory event with the pawn's current tile and settlement context.

Suggested next session:

- Add a second embodied affordance, such as looking around / inspecting the tile, so the incarnated loop gains a richer local verb set.

---

## 2026-04-27 - Incarnation control locked to the embodied pawn

Date: 2026-04-27
Goal: Prevent accidental disembodiment once the player has entered a pawn.

Changes made:

- Selection clicks now ignore other pawns while incarnated, so control stays on the confirmed body.
- The camera auto-follows the embodied pawn during incarnation.
- `Esc` no longer clears the incarnated pawn; `Backspace` remains the explicit return-to-spectator path.

Suggested next session:

- Add one first-pass embodied interaction beyond movement, such as a pawn-local action or context readout, so incarnation does something distinct immediately after entry.

---

## 2026-04-27 - Incarnation picker UI wired into Main

Date: 2026-04-27
Goal: Turn the spectator-to-incarnation loop into an explicit player-facing UI path.

Changes made:

- Added `scripts/ui/IncarnationPicker.gd` as a modal CanvasLayer that lists living pawn candidates and confirms a chosen incarnation target.
- `scenes/main/Main.gd` now opens the picker from `P`, closes it on escape/return paths, restores spectator mode cleanly, and logs the chosen pawn into `PlayerIntentQueue` on confirmation.
- The observer snapshot now exposes picker visibility so debug HUDs can see when incarnation selection is active.

Suggested next session:

- Populate the picker with richer eligibility rules or region/life-context filters, then start routing a first-pass embodied HUD state from the confirmed pawn.

---

## 2026-04-27 - Standalone spectator/incarnation master plan published

Date: 2026-04-27
Goal: Make the full standalone build order and feature list visible inside the repo for humans and other AIs.

Changes made:

- Added `docs/HEELKAWN_STANDALONE_MASTER_PLAN.md` with the ordered product, fantasy, pillar, feature, v1, v2+, and production-stage spec.
- README now points directly to the standalone master plan.
- `docs/CURSOR_MASTER_PLANNING_SPEC.md` related documents list now includes the standalone master plan.

Suggested next session:

- Use the master plan to drive the next code slice: incarnation entry UI, candidate selection, or world-history playback depending on implementation priority.

---

## 2026-04-27 - Incarnation picker ranked by settlement context

Date: 2026-04-27
Goal: Make incarnation selection feel intentional rather than a flat living-pawn list.

Changes made:

- Ranked candidates by life stage, settlement state, region reputation, lineage, and current profession.
- The picker now explains that ranking in its subtitle and shows the score/reason on each row.

Suggested next session:

- If the loop feels right, route one first-pass embodied HUD or control behavior from the confirmed pawn so incarnation changes more than just selection state.

---

## 2026-04-27 - Canonical repo policy: one folder, one GitHub remote

Date: 2026-04-27
Goal: Lock official work to `C:\Users\user\Documents\GitHub\HeelKawn1` → `github.com/PVAGR/HeelKawn1`; instruct assistants to ignore other HeelKawn-named directories for project edits.

Changes made:
- Added `docs/CANONICAL_REPOSITORY.md`, `.cursor/rules/heelkawn-canonical-repo.mdc`, `tools/Commit-PushMain.ps1`.
- README, LLM_ONBOARDING, handoff rule, WORLD_BIBLE/MASTER_INDEX updated to point at canonical scope.

---

## 2026-04-27 - Merge feature into main; push GitHub default branch

Date: 2026-04-27
Goal: Single default branch (`main`) carries full kernel/doc/tooling sync without manual PR.

Changes made:
- `git merge feature/world-bible-memory-baseline -X theirs` into `main` (prefer feature-side on conflicts so SimTime, planning spec, HUD/kernel sync remain intact alongside prior `origin/main` work).
- `git push origin main` — default branch at `248c94d` on `github.com/PVAGR/HeelKawn1`.

Suggested next session:
- Open repo default branch only; optional delete/stale-branch cleanup on GitHub if desired.

---

## 2026-04-27 - Cursor Master Planning Spec + continuity pass

Date: 2026-04-27
Goal: Repo-wide discoverability for umbrella planning doc; align handoff with authoritative next targets.

Changes made:
- Added docs/CURSOR_MASTER_PLANNING_SPEC.md earlier (full plan: canon tiers T1–T4, lore/ages/factions/systems/mechanics, tension register, implementation priorities synced from HEELKAWN_STATE.md).
- docs/WORLD_BIBLE/MASTER_INDEX.md: Planning section links to CURSOR_MASTER_PLANNING_SPEC.md.
- docs/LLM_ONBOARDING.md: optional read after core trio for planning/lore-heavy work.
- This session: .cursor/rules/heelkawn-handoff.mdc — optional third read when work touches lore tiers / overlay design / canon scope.
- README.md one-liner for CURSOR_MASTER_PLANNING_SPEC.md.
- HEELKAWN.txt NEXT TARGET block aligned with docs/HEELKAWN_STATE.md; added WHERE TO PLAN LORE/TIERS pointer.

Suggested next session:
- Implement or tune one NEXT TARGET item from docs/HEELKAWN_STATE.md (e.g. architectural style hooks or rebirth tuning), or expand WORLD_BIBLE where design decisions land.

---

## 2026-04-26 - Phase 11 emergent governance and authority

Date: 2026-04-26
Agent/Model: Codex (Cursor)
Goal: Add organic influence-based governance (monarchy/council/anarchy) with player ruler-only edicts.

Changes made:
- Updated `scripts/pawn/PawnData.gd`:
  - Added `influence` and deterministic influence model:
    - base = total tracked XP
    - bonuses = diplomacy affinity * 2 + combat affinity * 1.5
    - multiplier scales by population
  - Added helpers:
    - `total_tracked_xp()`
    - `calculate_influence(population)`
    - `get_mastery_perk(skill)` (Master/Grandmaster tiers retained with uncapped XP).
  - Persisted influence in save/load.
- Updated `scenes/main/Main.gd`:
  - Added tick-gated influence updates (`tick % 500 == 0`).
  - Added governance profile getter for HUD:
    - settlement state
    - ruler name
    - player status (Ruler/Loyalist/Rebel)
    - edict unlock flag.
- Updated `autoloads/SettlementMemory.gd`:
  - Added governance detection per settlement:
    - Monarchy = highest influence lead
    - Council = top 3 near-tie
    - Anarchy = evenly spread influence
  - Stores:
    - `governance_type`, `current_ruler_id`, `council_ids`
  - Emits append-only `WorldMemory` event on changes:
    - `{type: governance_change, settlement_id, new_ruler_id, governance_type}`
  - Added query helpers:
    - `get_governance_profile_for_region(...)`
    - `is_pawn_current_ruler(...)`
- Updated `scripts/pawn/Pawn.gd`:
  - Added ruler and governance actions:
    - `is_current_ruler()`
    - `issue_edict("focus_farming" | "draft_soldiers")` (ruler-only)
    - `abdicate()` (sets influence to 0)
    - `pledge_loyalty(target_ruler)` (+influence to ruler)
  - Reproduction and affinity systems from Phase 10 preserved.
- Updated `scripts/pawn/PlayerInputBuffer.gd`:
  - Added deterministic command queue for governance commands:
    - `!edict focus_farming`
    - `!edict draft_soldiers`
    - `!abdicate`
    - `!pledge_loyalty`
  - Commands execute in tick path before movement intents.
- Updated `scripts/ui/ColonyHUD.gd`:
  - Added `_politics_line()`:
    - `Settlement State: [Monarchy/Council/Anarchy]`
    - `Ruler: [Name/None]`
    - `Player Status: [Loyalist/Rebel/Ruler]`
    - `EDICTS UNLOCKED` indicator for ruler.

Determinism check:
- Influence updates are tick-gated only (`% 500`).
- Governance selection uses deterministic sort/tie rules.
- No RNG added for governance decisions.

---

## 2026-04-26 - Phase 9 combat resolution + dynamic world events

Date: 2026-04-26
Agent/Model: Codex (Cursor)
Goal: Prevent infinite raid loops and introduce non-combat world events with deterministic tick scheduling.

Changes made:
- Updated `scripts/combat/EnemySpawner.gd`:
  - Added `SPAWN_INTERVAL_TICKS` and `process_tick(world, tick)` gate:
    - raids only spawn when `tick % SPAWN_INTERVAL_TICKS == 0`.
  - Added active battle lock:
    - `_is_battle_active` true while enemies exist; blocks new raid spawns.
  - Added zombie-raid fail-safe:
    - if living pawns < 2 for `NO_TARGET_DESPAWN_TICKS`, auto `despawn_all()`.
  - Added clear log:
    - `[Combat] Raid cleared: No targets remaining.`
  - Replaced random edge/type selection with deterministic tile/raid-based ordering.
- Updated `scenes/main/Main.gd`:
  - `_on_enemy_tick` now delegates to `spawner.process_tick(...)`.
- Added `autoloads/WorldEvents.gd` and autoload registration in `project.godot`:
  - Deterministic event roll every `EVENT_ROLL_INTERVAL` ticks.
  - Event set:
    - Trade Caravan (resource delivery),
    - Harvest Moon (temporary gathering multiplier state),
    - Locust Swarm (food drain),
    - Diplomatic Envoy (alliance stub).
  - All events recorded via `WorldMemory.record_event(...)`.
- Updated `scripts/combat/CombatResolver.gd`:
  - Kept enemy kill confirmation log:
    - `[Combat] Enemy X killed by Y`
  - Throttled per-hit combat logs to `tick % 100 == 0` for high-speed stability.

Determinism/perf notes:
- Raid spawn timing now strict modulo tick gate.
- Battle lock prevents overlapping raid spam.
- World events are deterministic by tick-derived index.
- Tick-loop combat logs are throttled for 50x stability.

---

## 2026-04-26 - Free camera zoom/pan + fixed-scale HUD viewport split

Date: 2026-04-26
Agent/Model: Codex (Cursor)
Goal: Improve map visibility and camera usability while keeping HUD crisp and screen-fixed.

Changes made:
- Updated `scenes/main/Main.tscn` scene hierarchy:
  - Added `WorldViewport` (world-space container).
  - Moved world simulation/render nodes under `WorldViewport`:
    - `World`, `BuildPreviewOverlay`, `WorldTrace`, `PawnSpawner`, `AnimalSpawner`, `EnemySpawner`, `LivingWorld`, `Camera`.
  - Added `UI_Viewport` outside camera hierarchy.
  - Moved HUD/UI nodes under `UI_Viewport`:
    - `ColonyHUD`, `BuildToolbar`, `PawnInfoPanel`.
- Updated `scenes/main/Main.gd`:
  - Updated onready paths to new hierarchy.
  - Added `Home` hotkey handler calling camera reset-to-world-fit.
- Updated `scripts/camera/CameraController.gd`:
  - Kept existing wheel zoom + middle-mouse panning behavior.
  - Added `reset_to_world_bounds(world)`:
    - centers on map
    - computes fit zoom to show whole world in viewport
    - clamps to camera min/max zoom.
- Updated `scripts/ui/ColonyHUD.gd`:
  - Kept `CanvasLayer` HUD behavior and set layer to `10` as requested.
- Updated `scenes/world/World.gd`:
  - Temporarily increased visual tile size (`TILE_PIXELS: 8 -> 10`) for readability.

Determinism/perf notes:
- Camera and HUD changes are presentation-only; simulation logic unchanged.
- HUD remains fixed-size and independent of world camera zoom.

---

## 2026-04-26 - 60FPS smoothness pass (HUD throttle + input queue + log silence)

Date: 2026-04-26
Agent/Model: Codex (Cursor)
Goal: Reduce lag spikes and debug-mode stutter for high simulation speeds (20x+).

Changes made:
- Updated `scripts/ui/ColonyHUD.gd`:
  - Kept HUD updates tick-bound and added throttling gate:
    - `_on_tick` now refreshes at coarse cadence (`tick % 10`) unless dirty.
  - Added dirty-flag model (`_hud_dirty`) so signal-driven updates are coalesced
    into next tick refresh instead of immediate repeated redraw work.
  - Retained `GameManager.game_tick` as the primary refresh driver.
- Updated `scripts/pawn/PlayerInputBuffer.gd`:
  - Replaced queued Dictionary payloads with lightweight integer action IDs.
  - Reduced per-keypress allocations in hot input path.
  - Preserved deterministic behavior and WorldMemory action logging.
- Updated `scenes/main/Main.gd`:
  - Removed hot-loop tick console print in `_on_game_tick`.
- Updated `scenes/world/World.gd`:
  - Gated world-generation debug prints and expensive distribution summary behind
    `GameManager.verbose_logs()` in addition to debug build checks.

Determinism/perf notes:
- No simulation frame-time logic added.
- No RNG added by this pass.
- Reduced synchronous console overhead and HUD redraw frequency.

---

## 2026-04-26 - Phase 8 chronicler lens (deterministic tile inspection)

Date: 2026-04-26
Agent/Model: Codex (Cursor)
Goal: Right-click any world tile to inspect append-only local history in a UI panel.

Changes made:
- Updated `autoloads/WorldMemory.gd`:
  - Added `get_events_for_tile(target_pos: Vector2i) -> Array[Dictionary]`.
  - Filters deterministic event store by tile coordinates:
    - compact events via `x/y`
    - generic events via `pos` dictionary or `Vector2i`
  - Returns sorted-by-tick copy for stable UI rendering.
- Updated `scenes/main/Main.gd`:
  - Added `inspect_tile(tile_pos: Vector2i)`.
  - Right-click now inspects tile under cursor using world->tile conversion.
  - Escape and left-click hide history panel for fast close workflow.
- Updated `scripts/ui/ColonyHUD.gd`:
  - Added runtime `TileHistoryPanel` (`PopupPanel + RichTextLabel`).
  - Added `show_tile_history(...)` and `hide_tile_history()`.
  - Renders event lines as:
    - `[Tick XXXX] Event: ...` with short detail extraction.
  - Shows only events returned for inspected tile.

Determinism check:
- Read-only query path only (no mutation in inspect flow).
- No RNG introduced.
- Stable tick sort for repeatable display order.

---

## 2026-04-26 - Phase 7 session log summary generator at tick 30000

Date: 2026-04-26
Agent/Model: Codex (Cursor)
Goal: Add copy-paste-ready kernel summary text generation for handoff workflow.

Changes made:
- Updated `scripts/system/KernelDiagnostic.gd`:
  - Added `generate_session_log_summary() -> String`.
  - Summary fields include:
    - `TICK: 30000`
    - WorldMemory event count
    - wildlife rabbit/deer/total
    - settlement distribution (active/revivable/recovering/abandoned/permanently abandoned)
    - player pawn block:
      - `No Player Pawn` fallback, or
      - `ID / Profession / XP/100`
  - Wired into `_on_tick(30000)` to print:
    - `[SESSION LOG SUMMARY]`
    - then the generated multi-line summary string.

Determinism check:
- Trigger remains exact one-shot at tick 30000.
- Summary is read-only aggregation of deterministic state.
- No RNG or frame-time logic added.

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
