# HEELKAWN — TASK TRACKER

**Last Updated:** 2026-05-02  
**Current Phase:** Phase 4 (Identity & Meaning)  
**Focus:** Settlement revival vs permanent abandonment tuning

---

## DONE ✅

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

### Critical: Settlement State Machine Fix
- [ ] **BLOCKER**: Fix `recovering` state semantics in SettlementMemory.gd
  - Current issue: `recovering` used as intermediate state BEFORE `revivable`, contradicts REVIVAL_CONSTRAINTS.md
  - Required flow: `abandoned` → `revivable` → `recovering` → `active`
  - SettlementRebirth.gd only spawns into `revivable`, missing `recovering` settlements
  - _state_to_meaning_label() returns non-standard "recovering" instead of WorldMeaning labels
- [ ] Update _settlement_state_v1() to match canonical flow
- [ ] Update SettlementRebirth.gd to accept both `revivable` AND `recovering` states
- [ ] Fix _state_to_meaning_label() to return standard WorldMeaning labels
- [ ] Add validation tests for state transitions
- [ ] Document state machine in REVIVAL_CONSTRAINTS.md with diagram

---

## NEXT ⏭️

### Kernel Stabilization (Priority 1)
1. Complete settlement state machine fix (see IN PROGRESS)
2. Add deterministic state transition logging to WorldMemory
3. Implement state transition validation harness
4. Test scar level ≥ 3 permanent abandonment block
5. Verify 5000-tick peace gate for revival

### Lineage & Cultural Memory (Priority 2)
1. Expand BloodlineSystem with family tree visualization
2. Add cultural event inheritance to SettlementRebirth
3. Implement tradition decay over generations
4. Connect KnowledgeSystem to teaching events

### Observer Tools (Priority 3)
1. Timeline inspector for settlement history
2. Chronicle log viewer UI
3. Focus inspector enhancements
4. Regional meaning heatmap

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
