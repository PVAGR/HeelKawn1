# HeelKawn — Living TODO

**Last Updated:** August 17, 2026
**Source of truth:** `docs/HEELKAWN_STATE.md` and `docs/HEELKAWN_PROJECT_COMPASS.md`

> HeelKawn is **never finished**. This file tracks active work, not a destination.

---

## Immediate Path (Stabilization Sequence — Aug 17, 2026)

### 1. Repo Identity / Documentation Conflict (DONE Aug 17)
- [x] Restore `README.md` from accidental PVA Bazaar overwrite
- [x] Restore `CANONICAL_MAP.md` from accidental PVA Bazaar overwrite
- [x] Resolve merge conflict in `docs/HEELKAWN_STATE.md`
- [x] Update `docs/HEELKAWN_STATE.md` with current stabilization state
- [x] Update `TODO.md` priority order

### 1b. Lag Reduction + Autoload Consolidation (DONE Aug 17)
- [x] Fix CharacterProgressionSystem double-execution (achievements every tick → every 500 ticks)
- [x] Throttle SurvivalSystem (find_alive_pawns every tick → every 3 ticks)
- [x] Optimize EcologySystem (doubled 65K-tile intervals, double-buffer pollution)
- [x] Add tick forwarding to 8 consolidated managers
- [x] Remove 3 duplicate autoload registrations (HeelKawnUIManager, UILayoutManager, PawnMoodUI)
- [x] Static quality gate: PASS

### 1c. Deep Profiling + O(P²) Elimination (DONE Aug 17)
- [x] PawnSpawner: tick-stamped alive_pawns cache (51+ allocations/tick → 1)
- [x] HeelKawnian: awareness scan O(P²) → O(P) cached list
- [x] SocialDynamics: adjacency index (O(R) → O(degree) per pawn query)
- [x] ColonySimServices: single-pass pawn collector (8× O(P) → 1× O(P))
- [x] AIAgentManager: agent keys dirty flag (eliminate alloc+sort every 3 ticks)
- [x] WorldAI: world_events cap at 2048 + pawn count cache
- [x] Static quality gate: PASS

### 2. Runtime Truth Pass (REQUIRES GODOT)
- [ ] Run in Godot editor/headless, verify all F10 diagnostic panels render without errors
- [ ] Confirm OnboardingSystem RichTextLabel fix holds at runtime
- [ ] Capture and fix any red errors in Output panel
- [ ] Verify HUD identity strip shows civilization stage correctly
- [ ] Verify F10 #49 prints valid HeelKawnian development profiles
- [ ] Verify PawnInfo panel shows real HeelKawnian data at runtime
- [ ] Verify PawnMoodUI shows real mood/traits/needs at runtime

### 3. Quality Gate
- [ ] Run `bash tools/ai/sim-quality-gate.sh`
- [ ] Verify 1x and 100x performance smoothness with consistency checks

### 4. UI & Inspection Verification
- [ ] Verify F10 panels all render (Civilization Stage, HeelKawnians, Chronicle, etc.)
- [ ] Verify HUD identity strip shows correct civilization era
- [ ] Verify PawnInfo/PawnMoodUI panels display real data
- [ ] Verify HeelKawnian profiles in F10 #49 show valid soul id, phase, drive, skills

### 5. Material Reality Verification
- [ ] Verify crafting material consumption works in all paths
- [ ] Add tool requirements to crafting recipes (beyond player gathering)
- [ ] Verify resources are actually consumed in all crafting paths (not just checked)

### 6. Phase 5A Systems (After Stabilization)
- [ ] Continue HeelKawnian Matrix AI deepening (preservation, recovery, longer-horizon ambitions)
- [ ] Continue Knowledge Preservation Loop (stones, books, teaching, literacy unification)
- [ ] Continue Civilization Stage deepening (per-settlement tech diffusion, literacy tracking)
- [ ] Continue TeachingSystem, ResearchSystem, TechnologyEras integration

---

## Previously Completed Work

### Lineage & Progression ✅
- [x] Parent lookup: `_get_parent_data` via static registry
- [x] Child creation: `PawnSpawner.spawn_child_pawn` with inheritance, bloodline, household
- [x] Profession inheritance from parents
- [x] Skill trees: `skill_trees` dict with bonus calculations, level-based unlocking
- [x] Inheritance hooks (knowledge, reputation, grudges)
- [x] Skill tree branch effects (visual/UI for branch choices)

### Material Reality ✅ (mostly)
- [x] Crafting consumption: `_consume_ingredients` removes from stockpile
- [x] PlayerGathering tool checks: `_has_required_tool` checks carried item + stockpile
- [x] PlayerGathering skill XP: `_get_skill_level` / `_gain_skill_xp` wired to HeelKawnianData
- [x] PlayerGathering resource depletion: `_deplete_resource` removes features, schedules regrow

### Knowledge Preservation Loop ✅ DONE May 22
- [x] Knowledge inscribed on stones (KnowledgeSystem + KnowledgeStone feature)
- [x] Book crafting recipes (Paper, Leather, Ink, Pen, Book)
- [x] Knowledge death tracking (knowledge_lost events)
- [x] Unify stones, books, teaching, literacy into one system
- [x] Lost/rediscovered knowledge mechanics
- [x] Preservation pressure wired into Matrix AI ambitions

### Civilization Stage Deepening ✅ DONE June 5
- [x] Initial derived era lens
- [x] F10 #03B + HUD era text
- [x] Per-settlement tech diffusion tracking
- [x] Literacy rate tracking
- [x] Lifespan/quality-of-life metrics
- [x] Institution emergence data

### Readable Exports ✅
- [x] Promotion bundle (world_seed.json, chronicle, bloodlines, artifacts)
- [x] History export string
- [x] ChronicleExport wired into F10 menu
- [x] World seed export

### Governance / Faction / Religion (Partial)
- [x] FactionRegistry: house-per-zone with deterministic names
- [ ] Move beyond stub, wire to SchismManager/FragmentationManager
- [ ] ReligionLens: implement SacredMemory/MythMemory/DRUJ/Asha interpretation
- [ ] AuthoritySystem: deepen emergence and decay logic

---

## Autoload Consolidation (Analysis Complete — Removal Deferred)

- [x] **Analysis complete** (May 21, 2026): Full audit of all autoloads
- [ ] Phase 1: Safe removals (10 autoloads)
- [ ] Phase 2: Stub/Vision conversions (18 autoloads)
- [ ] Phase 3: Future/V2 deferral (27 autoloads)
- [ ] Phase 4: Duplicate consolidation (16 autoloads)
- [ ] Phase 5: UI lazy loading (14 autoloads)
- [ ] Verify headless smoke passes after each removal batch

---

## Documentation Hygiene (Ongoing)

- [x] Archive old/overlapping docs to `docs/archive/`
- [x] Update TODO.md to reflect actual implemented state
- [ ] Keep core five docs current: Compass, Blueprint, State, Build Inventory, Player Guide
- [ ] Update completion language: "complete" = compiles, runs, verified — not just "file exists"

---

## Technical Debt

- [x] LICENSE set to MIT
- [ ] Add basic deterministic smoke tests (same seed → same output)
- [x] Clean up root directory of accidental files
- [x] Fix .gitignore
- [ ] Consider adding CI for headless Godot validation

---

*Updated after each work session. Stale items get removed, not ignored.*
