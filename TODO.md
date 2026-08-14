# HeelKawn — Living TODO

**Last Updated:** June 5, 2026
**Source of truth:** `docs/HEELKAWN_STATE.md` and `docs/HEELKAWN_PROJECT_COMPASS.md`

> HeelKawn is **never finished**. This file tracks active work, not a destination.

---

## Immediate Path (Consolidation Sequence)

### 1. Runtime Truth Pass
- [ ] Run in Godot editor, verify all F10 diagnostic panels render without errors
- [ ] Confirm OnboardingSystem RichTextLabel fix holds at runtime
- [ ] Capture and fix any red errors in Output panel
- [ ] Verify HUD identity strip shows civilization stage correctly
- [ ] Verify F10 #49 prints valid HeelKawnian development profiles

### 2. HeelKawnian Matrix AI Deepening
- [x] Settlement planner infra gates: pressure + per-settlement/type cooldown (1000t) + pending dedupe (`Main.gd`, `JobManager.gd`)
- [x] AIAutoBuild shelter/storage intents gated on colony pressure (May 19)
- [x] `HeelKawnianDecision.idle_settlement_pressure` reads `IntentMemory` via `MemoryManager` (not stale autoload refs)
- [x] Job-bias bridge: profile-to-job-bias drives real job choice
- [x] Social intent bridge: `social_seek` / `teach_seek` / `grudge_confront`
- [x] Settlement ambition seeding: periodic local ambitions from drive + pressure
- [x] Household goal planning: `HOUSEHOLD_GOALS` with coordinated job lists
- [x] Extend profile-to-job-bias into learning target selection (May 23)
- [x] Add preservation choices (what knowledge to inscribe vs keep oral) (verified May 23 — already wired)
- [x] Recovery drive ambition chain (shelter/hearth/storage/maintain after trauma pressure)
- [x] `teach_seek` autonomy calls `execute_teach_seek` on arrival
- [x] Deepen recovery behavior (post-collapse settlement rebuild chains) (May 23 — 5 new chain types)
- [x] Add settlement ambition chains (longer-horizon objectives) (May 23 — made general, not recovery-only)

### 3. Lineage & Progression
- [x] Parent lookup: `_get_parent_data` via static registry
- [x] Child creation: `PawnSpawner.spawn_child_pawn` with inheritance, bloodline, household
- [x] Profession inheritance from parents
- [x] Skill trees: `skill_trees` dict with bonus calculations, level-based unlocking
- [ ] Add inheritance hooks (knowledge, reputation, grudges)
- [ ] Add skill tree branch effects (visual/UI for branch choices)

### 4. Material Reality
- [x] Crafting consumption: `_consume_ingredients` removes from stockpile
- [x] PlayerGathering tool checks: `_has_required_tool` checks carried item + stockpile
- [x] PlayerGathering skill XP: `_get_skill_level` / `_gain_skill_xp` wired to HeelKawnianData
- [x] PlayerGathering resource depletion: `_deplete_resource` removes features, schedules regrow
- [ ] Add tool requirements to crafting recipes (beyond player gathering)
- [ ] Verify resources are actually consumed in all crafting paths (not just checked)

### 5. Knowledge Preservation Loop ✅ DONE May 22
- [x] Knowledge inscribed on stones (KnowledgeSystem + KnowledgeStone feature)
- [x] Book crafting recipes (Paper, Leather, Ink, Pen, Book)
- [x] Knowledge death tracking (knowledge_lost events)
- [x] Unify stones, books, teaching, literacy into one system — `get_knowledge_preservation_state()` + `compute_preservation_pressure()` composites all carrier types
- [x] Add lost/rediscovered knowledge mechanics — `_has_record_carrier_for_knowledge()` + `_is_knowledge_truly_lost()` guard dormancy; record carriers prevent "lost" state
- [x] Verify knowledge death when last carrier dies untaught — `_check_knowledge_loss()` now checks record carriers before entering dormant; `knowledge_degraded` vs `knowledge_truly_lost` events emitted
- [x] Wire preservation pressure into Matrix AI ambitions — `HeelKawnianManager.get_settlement_ambition_for_pawn()` calls `compute_preservation_pressure()` during `preserve` drive

### 6. Civilization Stage Deepening �� DONE June 5, 2026
- [x] Initial derived era lens: `CivilizationStage.gd` reads live world state
- [x] F10 `03B · Civilization Stage` and HUD era text
- [x] Add per-settlement tech diffusion tracking — uses KnowledgeSystem.pre-computed `tech_diffusion_by_settlement` + EgregoreMemory pressure vectors
- [x] Add literacy rate tracking — uses KnowledgeSystem.pre-computed `literacy_rate_by_settlement`
- [x] Add lifespan/quality-of-life metrics — continuous tracking via `_continuous_metrics` cache
- [x] Add institution emergence data — integrates EgregoreMemory active norms (mutual_aid, martial_code, scholar_path, austerity_rite, market_charter), law density, governance forms, and guild data from SettlementMemory
- [x] Added continuous metrics API: `get_continuous_metrics`, `get_literacy_rate`, `get_tech_diffusion_score`, `get_egregore_signature`, `get_active_norms`, `get_divergence_snapshot`, `get_governance_form`, `get_guild_data`
- [x] Periodic continuous metrics update every 300 ticks via `_update_continuous_metrics()`

### 7. Readable Exports
- [x] Promotion bundle: `ExportSystem.export_promotion_bundle()` → world_seed.json, chronicle_summary.txt, chronicle.json, bloodlines.json, artifacts.json
- [x] History export string: `WorldMemory.get_history_export_string()`
- [x] ChronicleExport.gd: narrative prose chronicle organized by era
- [x] Wire ChronicleExport into F10 menu for in-game access ✅ DONE May 22
- [x] World seed export: `export_world_seed()` and promotion bundle write world_seed.json ✅ DONE
- [ ] World seed/state import for sharing worlds (stub exists, full restore needs integration - V2 feature)

### 8. Governance / Faction / Religion (after core loop is reliable)
- [x] FactionRegistry: house-per-zone with deterministic names
- [ ] Move beyond stub, wire to SchismManager/FragmentationManager
- [ ] ReligionLens: implement SacredMemory/MythMemory/DRUJ/Asha interpretation
- [ ] AuthoritySystem: deepen emergence and decay logic

---

## Autoload Consolidation (Analysis Complete — Removal Deferred)

- [x] **Analysis complete** (May 21, 2026): Full audit of all 159 autoloads in `project.godot`
  - See `docs/AUTOLOAD_CONSOLIDATION_PLAN.md` for detailed breakdown
  - 15 Core Kernel autoloads identified (11 irreducible + 4 strong candidates)
  - 42 Active Systems to keep for now
  - 18 Stub/Vision candidates for conversion to regular scripts
  - 16 Duplicate/Redundant candidates for consolidation
  - 12 UI-only candidates for lazy loading
  - 24 Future/V2 systems not needed for v1
  - 35 files already deregistered from project.godot
  - ~14,737 LOC of autoload registrations can be safely removed over 5 phases
- [ ] Phase 1: Safe removals (10 autoloads, ~287 LOC) — thin wrappers and explicit stubs
- [ ] Phase 2: Stub/Vision conversions (18 autoloads, ~2,250 LOC) — convert to regular scripts
- [ ] Phase 3: Future/V2 deferral (27 autoloads, ~7,300 LOC) — comment out or make optional
- [ ] Phase 4: Duplicate consolidation (16 autoloads, ~2,100 LOC) — merge into primary systems
- [ ] Phase 5: UI lazy loading (14 autoloads, ~2,800 LOC) — convert to scene-owned
- [ ] Verify headless smoke passes after each removal batch

---

## Documentation Hygiene (Ongoing)

- [x] Archive old/overlapping docs to `docs/archive/`
- [x] Update TODO.md to reflect actual implemented state (May 19, 2026)
- [x] Needs-driven planner: `compute_settlement_build_priorities` + variable 500–2000t cooldowns
- [x] Formal settlement UI gate (mind panel + country view) per AI_README infrastructure doctrine
- [x] Territory overlay draws formal settlements only (no proto-site fill)
- [ ] Keep core five docs current: Compass, Blueprint, State, Build Inventory, Player Guide
- [ ] Update completion language: "complete" = compiles, runs, verified — not just "file exists"

---

## Technical Debt

- [x] LICENSE set to MIT
- [ ] Add basic deterministic smoke tests (same seed → same output)
- [x] Clean up root directory of accidental files (`$null`) ✅ DONE May 22
- [x] Fix .gitignore (remove duplicate `$null` entry) ✅ DONE May 22
- [ ] Consider adding CI for headless Godot validation

---

## May 19, 2026 session

- [x] Need-driven build gating: `SettlementPlanner` + `AIAutoBuild` use `_build_pressure_ok`, 1200-tick cooldown per settlement+type, and `JobManager.has_pending_build_near` / `post_build_deduped` to skip duplicate construction posts (bed, hearth, storage, farm).
- [x] Wire `post_build_deduped` into `Main._post_seeded_job` for bootstrap seeders. ✅ DONE May 22

## May 22, 2026 session

- [x] ChronicleExport F10 wiring (added menu item #76 "Chronicle Export (to file)").

## June 5, 2026 session — Civilization Stage Deepening Complete

- [x] Integrated KnowledgeSystem pre-computed `literacy_rate_by_settlement` and `tech_diffusion_by_settlement` into CivilizationStage
- [x] Integrated EgregoreMemory pressure signatures, active norms (mutual_aid, martial_code, scholar_path, austerity_rite, market_charter), divergence, and migration tendency
- [x] Integrated SettlementMemory governance forms (Elder Council, Militia Protectors, Chief Households, Council Rule) and guild data
- [x] Added continuous per-settlement metrics cache updated every 300 ticks via `_update_continuous_metrics()`
- [x] Added public API: `get_continuous_metrics`, `get_all_continuous_metrics`, `get_literacy_rate`, `get_tech_diffusion_score`, `get_egregore_signature`, `get_active_norms`, `get_divergence_snapshot`, `get_governance_form`, `get_guild_data`
- [x] Updated `_build_stage_snapshot` to use pre-computed continuous metrics instead of on-demand recomputation
- [x] All headless smoke tests pass (boot, settlement, worldmeaning, year1 growth)
- [x] Compile check passes

---

*Updated after each work session. Stale items get removed, not ignored.*
