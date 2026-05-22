# HEELKAWN — TASK TRACKER

**Last Updated:** 2026-05-22  
**Current Phase:** Phase 5A (Indefinite Evolution Foundation)  
**Focus:** Consolidation, runtime truth, Matrix AI deepening

---

## DONE ✅

### Session 2026-05-22
- [x] Repository cleanup: removed accidental `$null` file from root
- [x] Fixed .gitignore (removed duplicate `$null` entry)
- [x] Wired `post_build_deduped` into `Main._post_seeded_job` for construction job deduplication
- [x] Added ChronicleExport to F10 menu (item #76 "Chronicle Export (to file)")
- [x] Updated brain/memory files with session progress

### Session 2026-05-18
- [x] Full repository scan: identified many "TODO" items already implemented
- [x] Created `ChronicleExport.gd`: narrative prose chronicle organized by era, settlement summaries, notable lives, knowledge status
- [x] Fixed `PlayerGathering.gd` stubs:
  - `_has_required_tool`: now checks carried item + stockpile (was: always false)
  - `_get_skill_level`: wired to `HeelKawnianData.get_skill_level()` (was: always 0)
  - `_gain_skill_xp`: wired to `HeelKawnianData.add_skill_xp()` (was: no-op)
  - `_deplete_resource`: removes features, schedules regrowth via `Main._queue_regrowth` (was: no-op)
- [x] Fixed `_is_valid_gather_tile`: uses proper `TileFeature.Type` enum (was: hardcoded wrong numbers)
- [x] Updated `TODO.md`: marked implemented items, added new priorities
- [x] Updated `docs/BUILD_INVENTORY.md`: corrected status of skill trees, child creation, parent lookup, crafting consumption, exports

### Session 2026-05-02 (Continued)
- [x] Fixed DebugControlPanel.gd Godot 4.6 compatibility: replaced deprecated `append_text()` with `text +=` for TextEdit logging
- [x] Fixed Pawn.gd compilation error: removed erroneous duplicate line in `_decay_needs()` (line 3907)
- [x] Updated CHANGELOG.md with latest fix
- [x] Scanned for duplicate variable declarations across codebase (found several in CombatResolver, WorldGenerator, etc. - noted for future cleanup)

### Session 2026-05-02
- [x] Repository scan completed
- [x] Documentation review (AI_README.md, HEELKAWN_STATE.md, REVIVAL_CONSTRAINTS.md)
- [x] Status report generated
- [x] TASKS.md created
- [x] CHANGELOG.md created
- [x] docs/lore/MAP_OF_PROMETHEUS.md created
- [x] docs/WORLD_BIBLE/FACTIONS.md expanded
- [x] Settlement state machine fixed in SettlementMemory.gd
- [x] SettlementRebirth.gd updated to accept revivable AND recovering states
- [x] _state_to_meaning_label() fixed to return standard WorldMeaning labels
- [x] REVIVAL_CONSTRAINTS.md updated with canonical state flow diagram

### From origin/main
- [x] Restored the repository to the fullest known historical snapshot on `main`
- [x] Re-established the deterministic kernel authoring context for future sessions
- [x] Synced the visible workspace with the restored repository snapshot
- [x] Fixed persistence decay threshold ordering in `autoloads/PersistenceSystem.gd`
- [x] Fixed settlement rebirth so revival can run even when no living pawns remain
- [x] Fixed Pawn parser blockers and added PawnData cleanup for warning reduction
- [x] Added the Phase 4 settlement lifecycle machine with deterministic revival and ruin thresholds
- [x] Canonical startup documentation cleanup
- [x] Kernel contract review for WorldMemory / WorldMeaning / WorldPersistence
- [x] Full-run validation of the settlement lifecycle transition path

### Previous Sessions
- [x] Neural AI integration (WorldAI matrix for pawn decision-making)
- [x] Compact UI refactor (ColonyHUD, PawnInfoPanel with tabs)
- [x] COPY DUMP functionality for inspect panel
- [x] Crisis response mechanism in Pawn AI
- [x] Performance intervalization for hot listeners
- [x] ProgressionSystem kernel implementation
- [x] Settlement revival constraints documented (REVIVAL_CONSTRAINTS.md)
- [x] Cultural architecture signatures shipped
- [x] Player-readable meaning audio cues
- [x] Incarnation mode fully functional
- [x] Save/load persistence for player state

---

## IN PROGRESS 🔶

### Kernel Hardening
- [ ] Harden the kernel contract where meaning and persistence read from world facts
- [ ] Add missing kernel-facing documentation if a code path lacks an authoritative spec
- [ ] Verify settlement lifecycle boundaries against the current canonical constraints

### Runtime Truth Pass (requires Godot editor)
- [ ] Run in Godot editor, verify all F10 diagnostic panels render without errors
- [ ] Confirm OnboardingSystem RichTextLabel fix holds at runtime
- [ ] Capture and fix any red errors in Output panel
- [ ] Verify HUD identity strip shows civilization stage correctly
- [ ] Verify F10 #49 prints valid HeelKawnian development profiles

---

## NEXT ⏭️

### Matrix AI Deepening (Priority 1)
1. Add preservation choices (what knowledge to inscribe vs keep oral)
2. Add recovery behavior (what to do after disaster/famine/collapse)
3. Extend profile-to-job-bias into learning target selection
4. Add settlement ambition chains (longer-horizon objectives)

### Knowledge Preservation Loop (Priority 2)
1. Unify stones, books, teaching, literacy into one system
2. Add lost/rediscovered knowledge mechanics
3. Verify knowledge death when last carrier dies untaught

### Civilization Stage Deepening (Priority 3)
1. Add per-settlement tech diffusion tracking
2. Add literacy rate tracking
3. Add lifespan/quality-of-life metrics
4. Add institution emergence data

### Chronicle Export Wiring (Priority 3)
1. Wire `ChronicleExport.gd` into F10 menu
2. Add in-game chronicle save button
3. Add world seed import path for sharing worlds

### Documentation & Infrastructure
1. Clean up root directory of accidental files (`$null`)
2. Add basic deterministic smoke tests (same seed → same output)
3. Consider adding CI for headless Godot validation
4. Autoload consolidation: reduce 164 → ~11 core managers

---

## FUTURE 📋

### Phase 5: Player Meaning Layer
- Partial information systems
- Myth vs truth mechanics
- Chronicler tools expansion

### Civilizational Systems
- War system integration
- Magic system (faint currents only)
- Large-scale politics
- Trade networks

### Technical Improvements
- Spatial partitioning optimization
- 1000+ pawn performance targets
- Save/load compression
- Deterministic replay system
- Lineage and cultural continuity polish

---

## BLOCKERS 🚫

**None currently** — All major systems are shipped and functional. The settlement state machine issue is a logic inconsistency, not a blocker.

---

## NOTES

- Keep changes deterministic and auditable
- All state changes must derive from tick count
- Use WorldRNG for any variation
- Document all changes in CHANGELOG.md
- Update REVIVAL_CONSTRAINTS.md when modifying revival logic
- Many "TODO" items in old docs are already implemented — verify before working
