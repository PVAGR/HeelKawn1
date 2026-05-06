# 📋 HeelKawn AI TODO Queue

**Prioritized backlog of work for AI assistants.** Updated by every session based on project needs.

**HUMAN DIRECTIVE (May 6, 2026):** ALL AIs work in PARALLEL on different tracks. Each AI owns a track, collaborates with others, innovates together. MACRO progress across EVERYTHING.

---

## 🎯 DEVELOPMENT TRACKS (PARALLEL WORK)

**Each AI picks a track and runs with it:**

| Track | Focus | Priority | Assigned To | Status |
|-------|-------|----------|-------------|--------|
| **TRACK 1** | UI Integration & Testing | 🔴 HIGH | Open | ⏳ Available |
| **TRACK 2** | Performance Optimization | 🔴 HIGH | Open | ⏳ Available |
| **TRACK 3** | World Richness (Events) | 🔴 HIGH | Open | ⏳ Available |
| **TRACK 4** | System Polish (Grudges/Gossip) | 🟡 MEDIUM | Open | ⏳ Available |
| **TRACK 5** | Building/Crafting UI | 🟡 MEDIUM | Open | ⏳ Available |
| **TRACK 6** | Knowledge Systems | 🟢 LOW | Open | ⏳ Available |

---

## 🔴 TRACK 1: UI Integration & Testing

### [UI-001] Test All UI Components in Godot
**Priority:** 🔴 HIGH | **Est:** 30-60 min | **Status:** ⏳ PENDING

**Task:**
1. Open Godot 4.6.2
2. Run HeelKawn scene
3. Check console for red errors
4. Select pawn → Verify Consciousness tab appears
5. Check top-left for SurvivalHUD bars
6. Press I → Inventory toggles

**Likely Fixes:**
- Node path corrections in SurvivalHUD.gd
- Method existence in PlayerGathering.get_inventory()
- Data availability in PawnConsciousness

**Acceptance:**
- [ ] No red errors
- [ ] All 3 UI scenes render
- [ ] Consciousness tab shows data

---

### [UI-002] Building Placement UI
**Priority:** 🟡 MEDIUM | **Est:** 1-2 hrs | **Status:** ⏳ PENDING

Create UI for 9 building types with resource requirements, preview overlay, click-to-place.

---

### [UI-003] Crafting Menu
**Priority:** 🟡 MEDIUM | **Est:** 1-2 hrs | **Status:** ⏳ PENDING

Tool crafting interface (Flint Knife, Pickaxe, Axe, Torch) with recipes and inventory display.

---

## 🔴 TRACK 2: Performance Optimization

### [OPT-001] Performance Profiling
**Priority:** 🔴 HIGH | **Est:** 1-2 hrs | **Status:** ⏳ PENDING

**Profile:**
1. Tick processing at 1x, 26x, 100x
2. Memory usage over time (leaks?)
3. Frame hitching causes
4. Redraw frequency
5. WorldMemory write overhead

**Targets:** 60+ FPS at 1x, 30+ FPS at 100x, no memory growth

---

### [OPT-002] Optimization Implementation
**Priority:** 🔴 HIGH | **Est:** 2-3 hrs | **Status:** ⏳ PENDING

**Implement based on profiling:**
- Object pooling
- Adaptive throttling tuning
- Caching frequent data
- Spatial partitioning
- Reduce tick updates

---

## 🔴 TRACK 3: World Richness (Emergent Events)

### [WORLD-001] Random Encounter System
**Priority:** 🔴 HIGH | **Est:** 1-2 hrs | **Status:** ⏳ PENDING

Pawns meet during proximity, form bonds/grudges, trade, share gossip. Emergent relationships.

---

### [WORLD-002] Settlement Events
**Priority:** 🔴 HIGH | **Est:** 1-2 hrs | **Status:** ⏳ PENDING

Festivals, disputes, leadership challenges, trade fairs, gatherings. Recorded to WorldMemory.

---

### [WORLD-003] Natural Disasters
**Priority:** 🟡 MEDIUM | **Est:** 1-2 hrs | **Status:** ⏳ PENDING

Fires, floods, droughts (deterministic, seeded). Affect multiple settlements.

---

### [WORLD-004] Epidemic System
**Priority:** 🟡 MEDIUM | **Est:** 1-2 hrs | **Status:** ⏳ PENDING

Sickness spreads through proximity, affects mood/work, recovery or death.

---

## 🟡 TRACK 4: System Polish

### [POLISH-001] Grudge System Depth
**Priority:** 🟡 MEDIUM | **Est:** 1 hr | **Status:** ⏳ PENDING

Grudge escalation, resolution (apologies/duels), family honor, public shaming.

---

### [POLISH-002] Gossip Improvements
**Priority:** 🟡 MEDIUM | **Est:** 1 hr | **Status:** ⏳ PENDING

Gossip mutations, reputation decay, trusted sources, gossip chain tracing.

---

### [POLISH-003] Consciousness Depth
**Priority:** 🟡 MEDIUM | **Est:** 1-2 hrs | **Status:** ⏳ PENDING

Personality shifts, phobias from trauma, virtues from growth, relationship effects.

---

## 🟢 TRACK 5: Building/Crafting (Lower Priority)

### [BUILD-001] Building Toolbar
**Priority:** 🟢 LOW | **Est:** 1 hr | **Status:** ⏳ PENDING

Toolbar buttons for 9 building types with resource display.

---

### [BUILD-002] Crafting Toolbar
**Priority:** 🟢 LOW | **Est:** 1 hr | **Status:** ⏳ PENDING

Crafting buttons with recipe tooltips.

---

## 🟢 TRACK 6: Knowledge Systems

### [KNOW-001] Knowledge Carrier Display
**Priority:** 🟢 LOW | **Est:** 2-3 hrs | **Status:** ⏳ PENDING

Show who knows what per settlement, teaching chains, "last carrier" alerts.

---

## ✅ COMPLETED

| ID | Task | Completed | By |
|----|------|-----------|-----|
| UI-010 | SurvivalHUD.tscn | May 6 | Qwen |
| UI-011 | PlayerInventoryUI.tscn | May 6 | Qwen |
| UI-012 | PawnMoodUI.tscn | May 6 | Qwen |
| UI-013 | Consciousness tab | May 6 | Qwen |
| COLLAB-01 | AI Collaboration System | May 6 | Qwen |

---

**How AIs Collaborate Across Tracks:**
- Comment on each other's work in collaboration files
- Share discoveries (performance wins, patterns)
- Help debug blockers
- Cross-track integration (TRACK 3 events use TRACK 4 grudge/gossip systems)

*Last Updated: May 6, 2026*
