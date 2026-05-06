# 🐛 HeelKawn AI Bug Reports

**Known issues, errors, and bugs found by AI assistants.** Track reproduction steps, severity, and fixes.

---

## 🔴 CRITICAL (Game-Breaking)

*No critical bugs currently known.*

---

## 🟡 HIGH (Major Features Broken)

### BUG-003: WorldMeaning.gd Duplicate `var typ` — Parse Error Prevents Autoload
**Reported:** May 6, 2026
**Reported By:** Letta Code
**Severity:** High (meaning tags not computing)
**Status:** ⚠️ CONFIRMED

**Description:**
`WorldMeaning.gd` has `var typ: String = str(e.get("type", "")).to_lower()` declared twice in the same for-loop scope — at line 143 and line 174. GDScript doesn't allow duplicate variable declarations in the same scope. This causes a parse error that prevents the autoload from loading, meaning **meaning tags are not computing during runtime**.

**Reproduction:**
1. Run: `Godot_v4.6.2-stable_win64_console.exe --headless --check-only --script autoloads/WorldMeaning.gd`
2. Error: `Parse Error: There is already a variable named "typ" declared in this scope.` at line 174

**Root Cause:**
Lines 173-181 are a near-duplicate of lines 142-153. Both blocks process string-typed WorldMemory events for lineage/stranger tracking. The second block was likely added without noticing the first already exists.

**Fix:**
Remove lines 173-181 (the duplicate block). The first block at lines 142-153 already handles `settlement_revival_with_lineage`, `settlement_new_foundation`, and `pawn_death` string types.

**Fix Status:**
- [x] Reproduced
- [x] Root cause identified
- [ ] Fix implemented (waiting for approval)
- [ ] Retested

---

### BUG-004: JobManager.gd Compilation Failure — `TickManager` Not Found
**Reported:** May 6, 2026
**Reported By:** Letta Code
**Severity:** Medium (game still runs, autoload recovers)
**Status:** ⚠️ CONFIRMED

**Description:**
`JobManager.gd` line 18 references `TickManager` as a bare identifier. Godot reports `Identifier not found: TickManager` during compilation. The game still runs because autoloads load in order and Godot recovers, but this produces an error on every boot.

**Reproduction:**
1. Run: `Godot_v4.6.2-stable_win64_console.exe --headless --check-only --script autoloads/JobManager.gd`
2. Error: `Compile Error: Identifier not found: TickManager` at line 18

**Root Cause:**
JobManager.gd uses `TickManager` as a bare identifier at line 18 (`if TickManager != null:`). The autoload is registered in project.godot but the script compilation fails to resolve it. This is a pre-existing issue, not from Qwen's recent work.

**Fix:**
Add `@onready var TickManager = get_node_or_null("/root/TickManager")` like other autoload references, or use `get_node_or_null("/root/TickManager")` inline.

**Fix Status:**
- [x] Reproduced
- [x] Root cause identified
- [ ] Fix implemented
- [ ] Retested

---

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
| BUG-003 | WorldMeaning.gd duplicate `var typ` parse error | May 6 | Removed duplicate block at lines 173-181 | Letta Code |
| BUG-004 | JobManager.gd `TickManager` not found compile error | May 6 | Added `@onready var TickManager = get_node_or_null(...)` | Letta Code |
| BUG-005 | OnboardingSystem.gd null add_child crash | May 6 | Added null/child_count guards to all 3 button methods | Letta Code |
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
