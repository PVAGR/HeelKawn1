# HeelKawn — Living TODO

**Last Updated:** May 19, 2026
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
- [ ] Extend profile-to-job-bias into learning target selection
- [ ] Add preservation choices (what knowledge to inscribe vs keep oral)
- [x] Recovery drive ambition chain (shelter/hearth/storage/maintain after trauma pressure)
- [x] `teach_seek` autonomy calls `execute_teach_seek` on arrival
- [ ] Deepen recovery behavior (post-collapse settlement rebuild chains)
- [ ] Add settlement ambition chains (longer-horizon objectives)

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

### 5. Knowledge Preservation Loop
- [x] Knowledge inscribed on stones (KnowledgeSystem + KnowledgeStone feature)
- [x] Book crafting recipes (Paper, Leather, Ink, Pen, Book)
- [x] Knowledge death tracking (knowledge_lost events)
- [ ] Unify stones, books, teaching, literacy into one system
- [ ] Add lost/rediscovered knowledge mechanics
- [ ] Verify knowledge death when last carrier dies untaught

### 6. Civilization Stage Deepening
- [x] Initial derived era lens: `CivilizationStage.gd` reads live world state
- [x] F10 `03B · Civilization Stage` and HUD era text
- [ ] Add per-settlement tech diffusion tracking
- [ ] Add literacy rate tracking
- [ ] Add lifespan/quality-of-life metrics
- [ ] Add institution emergence data

### 7. Readable Exports
- [x] Promotion bundle: `ExportSystem.export_promotion_bundle()` → world_seed.json, chronicle_summary.txt, chronicle.json, bloodlines.json, artifacts.json
- [x] History export string: `WorldMemory.get_history_export_string()`
- [x] ChronicleExport.gd: narrative prose chronicle organized by era
- [ ] Wire ChronicleExport into F10 menu for in-game access
- [ ] World seed/state export for sharing worlds (seed JSON exists, needs import path)

### 8. Governance / Faction / Religion (after core loop is reliable)
- [x] FactionRegistry: house-per-zone with deterministic names
- [ ] Move beyond stub, wire to SchismManager/FragmentationManager
- [ ] ReligionLens: implement SacredMemory/MythMemory/DRUJ/Asha interpretation
- [ ] AuthoritySystem: deepen emergence and decay logic

---

## Autoload Consolidation (Ongoing)

- [ ] Reduce 164 autoloads to ~11 core managers
- [ ] Identify and remove duplicate/unused autoloads
- [ ] Convert non-essential autoloads to regular scripts or service objects
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
- [ ] Clean up root directory of accidental files (`$null`)
- [ ] Fix .gitignore (remove markdown code fence wrappers)
- [ ] Consider adding CI for headless Godot validation

---

## May 19, 2026 session

- [x] Need-driven build gating: `SettlementPlanner` + `AIAutoBuild` use `_build_pressure_ok`, 1200-tick cooldown per settlement+type, and `JobManager.has_pending_build_near` / `post_build_deduped` to skip duplicate construction posts (bed, hearth, storage, farm).
- [ ] Wire `post_build_deduped` into `Main._post_seeded_job` for bootstrap seeders.

---

*Updated after each work session. Stale items get removed, not ignored.*
