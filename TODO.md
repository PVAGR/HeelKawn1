# HeelKawn — Living TODO

**Last Updated:** May 15, 2026
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
- [ ] Extend profile-to-job-bias into learning target selection
- [ ] Add teaching target selection (who teaches whom, what knowledge)
- [ ] Add preservation choices (what knowledge to inscribe vs keep oral)
- [ ] Add recovery behavior (what to do after disaster/famine/collapse)
- [ ] Add household intent logic (coordinated group plans)
- [ ] Add settlement ambition chains (longer-horizon objectives)

### 3. Lineage & Progression
- [ ] Finish parent lookup (reliable, not stubbed)
- [ ] Finish child creation with inherited traits
- [ ] Add skill tree branch effects
- [ ] Add inheritance hooks (knowledge, reputation, grudges)

### 4. Material Reality
- [ ] Connect crafting consumption to inventory/stockpile
- [ ] Add tool requirements to crafting recipes
- [ ] Verify resources are actually consumed (not just checked)

### 5. Knowledge Preservation Loop
- [ ] Unify stones, books, teaching, literacy into one system
- [ ] Add lost/rediscovered knowledge mechanics
- [ ] Verify knowledge death when last carrier dies untaught

### 6. Civilization Stage Deepening
- [ ] Add per-settlement tech diffusion tracking
- [ ] Add literacy rate tracking
- [ ] Add lifespan/quality-of-life metrics
- [ ] Add institution emergence data

### 7. Readable Exports
- [ ] Chronicle export (world history as readable text)
- [ ] World seed/state export (share worlds)

### 8. Governance / Faction / Religion (after core loop is reliable)
- [ ] FactionRegistry: move beyond stub, wire to SchismManager/FragmentationManager
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
- [ ] Keep core five docs current: Compass, Blueprint, State, Build Inventory, Player Guide
- [ ] Update completion language: "complete" = compiles, runs, verified — not just "file exists"

---

## Technical Debt

- [ ] Set proper LICENSE (currently placeholder)
- [ ] Add basic deterministic smoke tests (same seed → same output)
- [ ] Clean up root directory of accidental files
- [ ] Fix .gitignore (remove markdown code fence wrappers)
- [ ] Consider adding CI for headless Godot validation

---

*Updated after each work session. Stale items get removed, not ignored.*
