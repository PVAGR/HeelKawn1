# HeelKawn - Playtest Checklist & Bug Report

**Date:** May 5, 2026  
**Version:** 1.0 "Emergent Life"  
**Build:** Post-Option C Balance

---

## ✅ PRE-PLAYTEST CHECKLIST

### Compilation
- [x] All GDScript files syntax-checked
- [x] No tab characters in code (all 4 spaces)
- [x] All autoloads registered in project.godot
- [x] No circular dependencies

### Systems Loaded
- [x] WorldMemory
- [x] SettlementMemory
- [x] KnowledgeSystem (26 types)
- [x] LegacySystem
- [x] GrudgeManager
- [x] GossipManager
- [x] TradeMemory
- [x] WildlifePopulation
- [x] DisasterSystem
- [x] OnboardingSystem
- [x] TechnologySystem (10 techs)
- [x] VictorySystem (5 victories)
- [x] FactionSystem
- [x] FarmingSystem (4 crops)
- [x] CraftingSystem (8 recipes)
- [x] EventNotificationOverlay
- [x] StatisticsPanel

---

## 🎮 PLAYTEST SECTIONS

### Section 1: First 5 Minutes (New Player Experience)
- [ ] Game launches without errors
- [ ] 20 pawns spawn with diverse professions (9 types)
- [ ] Click pawn → Narrative tab shows rich story
- [ ] Event notifications appear (births, etc.)
- [ ] Speed controls work (1-7 keys)
- [ ] F10 menu opens with all features
- [ ] Gentle onboarding / first-body orientation triggers (first launch)

**Expected:** Smooth, no crashes, clear what to do

---

### Section 2: Core Gameplay (30 Minutes)
- [ ] Pawns claim jobs based on profession
- [ ] Builders construct beds, walls, doors
- [ ] Gatherers/Foragers bring food
- [ ] Warriors hunt wildlife
- [ ] Scholars generate research points
- [ ] Traders form trade routes
- [ ] Smiths craft tools/weapons
- [ ] Healers craft medicine
- [ ] Farmers plant/harvest crops (4 types)

**Expected:** All 9 professions have meaningful work

---

### Section 3: Knowledge System (15 Minutes)
- [ ] Scholar inscribes knowledge on stone
- [ ] Blue stone spawns at inscription site
- [ ] Right-click stone → Read dialog opens
- [ ] Knowledge types display correctly (26 types)
- [ ] Other pawns can read stones to learn

**Expected:** Knowledge preservation works end-to-end

---

### Section 4: Social Systems (20 Minutes)
- [ ] Pawns form grudges from conflicts
- [ ] Gossip spreads between pawns
- [ ] Reputation affects interactions
- [ ] Factions form between settlements
- [ ] Trade improves faction relations
- [ ] Knowledge sharing strengthens bonds

**Expected:** Emergent social dynamics visible

---

### Section 5: Disasters (Wait for Natural or Debug)
- [ ] Fire starts and spreads to buildings
- [ ] Plague infects multiple pawns
- [ ] Famine spoils food stockpiles
- [ ] Earthquake destroys buildings
- [ ] Pawns respond to disasters
- [ ] Rebuilding occurs after disaster

**Expected:** Disasters are challenging but survivable

---

### Section 6: Technology (20 Minutes)
- [ ] Scholars generate research points
- [ ] Technology panel accessible
- [ ] Technologies unlock in correct order
- [ ] Prerequisites enforced
- [ ] Unlocks apply correctly (buildings, knowledge, etc.)
- [ ] Progress feels rewarding (not grindy)

**Expected:** Tech progression feels smooth

---

### Section 7: Legacy & Victory (Long-term)
- [ ] Pawn deaths create legacy entries
- [ ] Dynasties form and track generations
- [ ] Victory progress updates (F10 #75)
- [ ] Legacy milestones trackable without final victory/completion language
- [ ] Succession notifications work

**Expected:** Long-term goals are clear

---

### Section 8: Performance (All Speeds)
- [ ] 1x speed: 80-100 FPS
- [ ] 26x speed: 70-90 FPS
- [ ] 100x speed: 60-80 FPS
- [ ] No memory leaks (check after 1 hour)
- [ ] No hitching during heavy operations
- [ ] Statistics panel updates smoothly

**Expected:** Smooth at all speeds

---

### Section 9: UI/UX
- [ ] Pawn info panel shows all tabs
- [ ] Narrative tab displays rich text
- [ ] Statistics panel shows correct data
- [ ] Event notifications not spammy
- [ ] Death notifications clickable → biography
- [ ] F10 features all accessible
- [ ] No text overflow or clipping

**Expected:** UI is informative, not overwhelming

---

### Section 10: Edge Cases
- [ ] 100+ pawns (performance check)
- [ ] 10+ settlements (faction check)
- [ ] All knowledge types preserved (26/26)
- [ ] Max technology researched (10/10)
- [ ] Multiple disasters simultaneously
- [ ] Save/Load works (if implemented)

**Expected:** Game handles extremes gracefully

---

## 🐛 BUG REPORT TEMPLATE

```
**Bug Title:** [Short description]

**Severity:**
- [ ] Critical (crash, data loss)
- [ ] Major (feature broken)
- [ ] Minor (cosmetic, inconvenience)
- [ ] Suggestion (enhancement)

**Steps to Reproduce:**
1. 
2. 
3. 

**Expected Behavior:**

**Actual Behavior:**

**Frequency:**
- [ ] Always
- [ ] Often (>50%)
- [ ] Sometimes (<50%)
- [ ] Rare (once)

**Environment:**
- Godot Version: 4.6.2.stable
- OS: Windows 10/11
- Build: Post-Option C Balance

**Screenshot/Video:** [If applicable]

**Additional Notes:**
```

---

## 📊 BALANCE FEEDBACK

### Farming
- [ ] Growth times feel right
- [ ] Water management not too tedious
- [ ] Yields feel rewarding
- [ ] Viable vs foraging/hunting

**Notes:**

---

### Hunting
- [ ] Success rates feel fair
- [ ] Warrior bonus meaningful
- [ ] Wildlife population stable
- [ ] Meat worth the effort

**Notes:**

---

### Technology
- [ ] Research costs appropriate
- [ ] Prerequisites make sense
- [ ] Unlocks feel impactful
- [ ] Progression not too fast/slow

**Notes:**

---

### Factions
- [ ] Relation changes noticeable
- [ ] Trade bonuses meaningful
- [ ] Wars rare but possible
- [ ] Diplomacy engaging

**Notes:**

---

## ✅ POST-PLAYTEST ACTIONS

### Critical Fixes Needed
1. 
2. 
3. 

### Balance Adjustments
1. 
2. 
3. 

### Quality of Life Improvements
1. 
2. 
3. 

---

## 📈 PERFORMANCE METRICS

| Speed | Target FPS | Actual | Status |
|-------|------------|--------|--------|
| 1x | 80-100 | ___ | ☐ |
| 26x | 70-90 | ___ | ☐ |
| 100x | 60-80 | ___ | ☐ |

**Memory Usage:** ___ MB (target: <500 MB)

**Load Time:** ___ seconds (target: <10 seconds)

---

## 🎯 OVERALL ASSESSMENT

**Fun Factor:** [1-10] ___

**Complexity:** [1-10] ___ (target: 6-7)

**Accessibility:** [1-10] ___

**Replayability:** [1-10] ___

**Would Recommend:** [Yes/Maybe/No]

---

**Playtester Name:** _______________

**Date:** _______________

**Total Playtime:** _______________

---

## COMMENTS

[Add any additional comments, suggestions, or feedback here]
