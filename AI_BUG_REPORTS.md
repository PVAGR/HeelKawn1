# 🐛 HeelKawn AI Bug Reports

**Known issues, errors, and bugs found by AI assistants.** Track reproduction steps, severity, and fixes.

---

## 🔴 CRITICAL (Game-Breaking)

*No critical bugs currently known.*

---

## 🟡 HIGH (Major Features Broken)

### BUG-001: Unverified - New UI May Have Runtime Errors
**Reported:** May 6, 2026  
**Reported By:** Qwen  
**Severity:** High (if true)  
**Status:** ⚠️ NEEDS VERIFICATION

**Description:**
New UI components (SurvivalHUD, PlayerInventoryUI, PawnMoodUI, Consciousness tab) were created but not tested in Godot runtime. May have:
- Node path mismatches
- Missing method calls
- Null reference errors

**Reproduction:**
1. Open Godot 4.6.2
2. Run HeelKawn scene
3. Watch console for red errors
4. Select pawn → check PawnInfoPanel

**Expected:** No errors, UI renders correctly  
**Actual:** Unknown (not yet tested)

**Likely Culprits:**
- `SurvivalHUD.gd` line ~140: `_get_player_pawn()` may have wrong path
- `PlayerInventoryUI.gd`: `PlayerGathering.get_inventory()` method may not exist
- `PawnConsciousness` autoload may be empty (needs pawns to accumulate data)

**Fix Status:**
- [ ] Verified in Godot
- [ ] Errors identified
- [ ] Fix implemented
- [ ] Retested clean

---

## 🟢 LOW (Minor Issues, Polish)

### BUG-002: Consciousness Tab May Show Empty Data
**Reported:** May 6, 2026  
**Reported By:** Qwen  
**Severity:** Low (cosmetic)  
**Status:** ⚠️ KNOWN LIMITATION

**Description:**
Pawn Consciousness tab may show "No recent dreams" / "No significant memories" if pawns haven't lived long enough to accumulate experiences.

**Reproduction:**
1. Start new game
2. Select pawn immediately
3. Open Consciousness tab

**Expected:** Graceful "no data yet" message (already implemented)  
**Actual:** Works as intended, but may confuse players

**Fix Options:**
1. **Design choice:** Leave as-is (realistic - pawns need to live first)
2. **Debug mode:** Add F10 cheat to add memories/dreams for testing
3. **Tutorial text:** Explain that consciousness develops over time

**Recommended:** Option 1 + Option 3 (design choice, not a real bug)

---

## ✅ RESOLVED (This Week)

| ID | Bug | Resolved | Fix | By |
|----|-----|----------|-----|-----|
| BUG-010 | 30+ compile errors from autoload parse failure | May 6 | Fixed tabs in WorldMemory.gd, type casts | Qwen |
| BUG-011 | KnowledgeStone sprite type mismatch | May 6 | Changed Sprite2D → Node2D | Qwen |
| BUG-012 | Profession lock bug (pawns stuck in first job) | May 5 | Fixed reassignment logic | AI Session |
| BUG-013 | FoodChainManager events not reaching WorldMeaning | May 5 | Fixed schema gap | AI Session |

---

## 📝 How to Report Bugs

### Template for New Bugs:

```markdown
### BUG-XXX: [Short Description]
**Reported:** [Date]  
**Reported By:** [AI Name]  
**Severity:** Critical / High / Medium / Low  
**Status:** NEW / INVESTIGATING / FIXED / WONTFIX

**Description:**
[What's broken]

**Reproduction:**
1. [Step 1]
2. [Step 2]
3. [Step 3]

**Expected:** [What should happen]  
**Actual:** [What actually happens]

**Files Involved:**
- `path/to/file.gd`

**Fix Status:**
- [ ] Reproduced
- [ ] Root cause identified
- [ ] Fix implemented
- [ ] Retested

**Notes:**
[Any additional context]
```

---

## 🔍 Known Quirks (Not Bugs)

These are intentional behaviors that might seem like bugs:

| Quirk | Why It's Intentional |
|-------|---------------------|
| Pawns don't have memories at game start | Consciousness develops through experience (design) |
| SurvivalHUD only shows when player pawn exists | Spectator mode has no survival needs (design) |
| Dreams only happen during sleep | Realistic simulation (design) |
| Trauma decays slowly over time | Natural recovery is part of pawn psychology (design) |

---

## 📊 Bug Statistics

| Severity | Open | Closed |
|----------|------|--------|
| Critical | 0 | _count_ |
| High | 1 (unverified) | _count_ |
| Medium | 0 | _count_ |
| Low | 1 (known limitation) | _count_ |

---

*Last Updated: May 6, 2026 (Qwen)*
