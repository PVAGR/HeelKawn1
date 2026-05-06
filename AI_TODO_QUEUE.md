# 📋 HeelKawn AI TODO Queue

**Prioritized backlog of work for AI assistants.** Updated by every session based on project needs.

---

## 🔴 HIGH PRIORITY (Do First)

### [UI-001] Test & Fix New UI Components in Godot
**Created:** May 6, 2026  
**Created By:** Qwen  
**Estimated Time:** 30-60 min  
**Dependencies:** None

**Task:**
1. Open Godot 4.6.2
2. Run HeelKawn scene
3. Check for red errors in console
4. Select a pawn → Verify PawnInfoPanel has "Consciousness" tab
5. Check top-left for SurvivalHUD bars
6. Press I (or configured key) → Inventory should toggle

**Likely Fixes Needed:**
- Node path corrections in SurvivalHUD.gd
- Method existence checks in PlayerInventoryUI.gd
- Data availability in PawnConsciousness (may need pawns to live longer)

**Acceptance Criteria:**
- [ ] No red errors in Godot console
- [ ] All 3 new UI scenes render without errors
- [ ] Consciousness tab shows data (or graceful "no data" message)

---

### [UI-002] Building Placement UI
**Created:** May 6, 2026  
**Created By:** Qwen  
**Estimated Time:** 1-2 hours  
**Dependencies:** PlayerBuilding.gd exists (✅ Complete)

**Task:**
Create UI for placing buildings from PlayerBuilding.gd:
- Foundation, Wall (wood/stone), Door, Roof, Shelter, Storage Hut, Fire Pit, Workshop
- Show resource requirements before placement
- Preview placement (green/red highlight)
- Click to place, right-click to cancel

**Files to Create/Modify:**
- `scenes/ui/BuildingPlacementUI.tscn`
- `scripts/ui/BuildingPlacementUI.gd`
- Integrate into `BuildToolbar.gd` or create new toolbar

**Acceptance Criteria:**
- [ ] All 9 building types selectable
- [ ] Resource requirements shown
- [ ] Preview overlay on valid tiles
- [ ] Resources deducted on placement

---

### [UI-003] Crafting Menu
**Created:** May 6, 2026  
**Created By:** Qwen  
**Estimated Time:** 1-2 hours  
**Dependencies:** PlayerGathering.gd crafting logic (✅ Exists)

**Task:**
Create crafting interface for tools:
- Flint Knife, Flint Pickaxe, Wooden Axe, Torch
- Show recipes (resources required)
- Show player inventory alongside
- Grey out uncraftable items (missing resources)

**Files to Create/Modify:**
- `scenes/ui/CraftingMenu.tscn`
- `scripts/ui/CraftingMenu.gd`

**Acceptance Criteria:**
- [ ] All craftable tools listed
- [ ] Recipes visible
- [ ] Craft button enabled only when resources available
- [ ] Items added to inventory on craft

---

## 🟡 MEDIUM PRIORITY (Important but Not Critical)

### [UI-004] Knowledge System Visualization
**Created:** May 6, 2026  
**Created By:** Qwen  
**Estimated Time:** 2-3 hours  
**Dependencies:** KnowledgeSystem.gd, Record Carriers (✅ Complete)

**Task:**
Make knowledge preservation visible:
- Show knowledge carriers per settlement (who knows what)
- Visualize teaching chains (master → apprentice)
- Alert when last carrier of a skill is dying/old
- Show knowledge stones on map (inscribed stones)

**Files to Create/Modify:**
- `scenes/ui/KnowledgePanel.tscn`
- `scripts/ui/KnowledgePanel.gd`
- Map overlay for knowledge stones

**Acceptance Criteria:**
- [ ] Knowledge carriers list per settlement
- [ ] Teaching chain visualization
- [ ] "Last carrier" alerts
- [ ] Knowledge stones clickable/readable

---

### [UI-005] ChronicleLedger → Three Pillars Integration
**Created:** May 6, 2026  
**Created By:** Qwen  
**Estimated Time:** 1 hour  
**Dependencies:** ChronicleLedger.tscn exists (✅ In Main.tscn)

**Task:**
Connect ChronicleLedger to new systems:
- Survival events (near-death, hypothermia, severe injuries)
- Consciousness events (first dream, trauma milestone, growth spurt)
- Persistence events (building erected, knowledge carved, ruin formed)

**Files to Modify:**
- `scripts/ui/ChronicleLedger.gd`
- Event type filters

**Acceptance Criteria:**
- [ ] Survival events appear in chronicle
- [ ] Consciousness events appear in chronicle
- [ ] Filter toggles for event types

---

### [UI-006] Grudge/Reputation Visual Indicators
**Created:** May 6, 2026  
**Created By:** Qwen  
**Estimated Time:** 2 hours  
**Dependencies:** GrudgeManager.gd, GossipManager.gd (✅ Complete)

**Task:**
Visualize social dynamics:
- Colored lines between pawns with grudges (red = feud, green = friendship)
- Reputation score on hover
- Avoidance behavior visualization (show path detours around enemies)

**Files to Modify:**
- `scripts/pawn/Pawn.gd` (existing `_draw_social_bonds()` already has red lines)
- `scripts/ui/PawnInfoPanel.gd` (add reputation display)

**Acceptance Criteria:**
- [ ] Grudge lines visible when pawn selected
- [ ] Reputation score in PawnInfoPanel
- [ ] Avoidance paths shown (optional, nice-to-have)

---

## 🟢 LOW PRIORITY (Nice to Have)

### [UI-007] Consciousness Status Icon Above Pawns
**Created:** May 6, 2026  
**Created By:** Qwen  
**Estimated Time:** 1 hour  
**Dependencies:** PawnConsciousness.gd (✅ Complete)

**Task:**
Small icon above pawn heads showing consciousness level:
- 💫 Transcendent
- 🌟 Enlightened
- 💡 Reflective
- 👁️ Aware
- 🧠 Instinctive
- 😶 Unconscious

Color by trauma level (green = stable, red = traumatized).

**Files to Modify:**
- `scripts/pawn/Pawn.gd` (_draw() method)
- `scripts/ui/PawnNameLabels.gd` (integrate there)

**Acceptance Criteria:**
- [ ] Icon renders above each pawn
- [ ] Icon matches consciousness level
- [ ] Color reflects trauma level
- [ ] Click to open PawnInfoPanel

---

### [UI-008] Player Building/Crafting Tutorial Hints
**Created:** May 6, 2026  
**Created By:** Qwen  
**Estimated Time:** 30 min  
**Dependencies:** Building/Crafting UI (✅ After UI-002, UI-003)

**Task:**
First-time player hints:
- "Click tree to gather wood"
- "Press B to place foundation"
- "Press C to craft tools"

Show once, dismissable, re-enable in settings.

**Files to Create/Modify:**
- `scripts/ui/TutorialHints.gd`
- Settings toggle

**Acceptance Criteria:**
- [ ] Hints appear on first actions
- [ ] Dismissable
- [ ] Re-enable in settings

---

## ✅ COMPLETED (This Week)

| ID | Task | Completed | By |
|----|------|-----------|-----|
| UI-010 | SurvivalHUD.tscn creation | May 6 | Qwen |
| UI-011 | PlayerInventoryUI.tscn creation | May 6 | Qwen |
| UI-012 | PawnMoodUI.tscn creation | May 6 | Qwen |
| UI-013 | Integrate UI into Main.tscn | May 6 | Qwen |
| UI-014 | Consciousness tab in PawnInfoPanel | May 6 | Qwen |
| SYS-001 | Three Pillars implementation | May 6 | Qwen |

---

## 📝 How to Use This Queue

### For AI Assistants:
1. **Starting work:** Pick from HIGH priority, top to bottom
2. **Finishing task:** Move to COMPLETED table
3. **Discovering new work:** Add new entry at appropriate priority
4. **Blocked:** Move to AI_BLOCKERS/ and note here

### For Humans:
1. **Reprioritize:** Drag tasks between priority levels
2. **Add requests:** Create new entries anytime
3. **Review completed:** Check COMPLETED table each session

---

## 🎯 Long-Term Vision (Phase 5 Gaps)

These are bigger features still needing work:

| Feature | Completion | Notes |
|---------|------------|-------|
| Deep Social Dynamics | ~60% | Grudges ✅, Gossip ✅, Norms ❌, Reputation ❌ |
| Knowledge Ecology | ~70% | Carriers ✅, Teaching ❌, Loss/Rediscovery ❌ |
| Embodied Unpredictability | ~50% | Body risk ✅, Personality divergence ❌ |

See `docs/HEELKAWN_STATE.md` for full Phase 5 status.

---

*Last Updated: May 6, 2026 (Qwen)*
