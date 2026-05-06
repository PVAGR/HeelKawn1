# 🤖 HeelKawn AI Collaboration Hub

**Welcome to the HeelKawn AI Collective Workspace**

This is the central coordination point for all AI assistants working on HeelKawn. Every session, every AI leaves notes, findings, and handoffs here.

> **Philosophy:** HeelKawn is a living simulation that outlives any single developer or AI session. Continuity, transparency, and collective intelligence make it great.

---

## 📖 How This Works

### For AI Assistants (Every Session)

**On Session Start:**
1. Read `AI_COLLABORATION_HUB.md` (this file) - Current state & active tasks
2. Read `AI_SESSIONS/latest.md` - Previous session's detailed work
3. Read `AI_DECISIONS/README.md` - Architectural decisions that constrain work
4. Check `AI_TODO_QUEUE.md` - Prioritized backlog

**During Session:**
1. Update `AI_SESSIONS/current.md` with progress
2. Log bugs in `AI_BUG_REPORTS.md` if found
3. Propose designs in `AI_DESIGN_DISCUSSIONS/` if needed

**On Session End:**
1. Complete `AI_SESSIONS/current.md` with full details
2. Move to `AI_SESSIONS/archive/` with timestamp filename
3. Update this hub's status section
4. Leave handoff note in "Messages Between Sessions"

### For Humans (Project Owner)

- Review `AI_SESSIONS/` to see what AI built
- Respond to `AI_DECISIONS/` proposals
- Clear `AI_BLOCKERS/` when human input needed
- Update priorities in `AI_TODO_QUEUE.md`

---

## 🎯 Current Project State (Live)

**Last Updated:** May 6, 2026  
**Current Phase:** Phase 6 Complete - UI Integration In Progress  
**AI Session:** Ongoing (Qwen - May 6, 2026)

### ✅ Recently Completed (This Week)

| Date | System | Status | AI Agent |
|------|--------|--------|----------|
| May 6 | Three Pillars Implementation | ✅ Runtime Verified | Qwen |
| May 6 | Survival UI (HUD + Inventory) | ✅ Integrated | Qwen |
| May 6 | Pawn Consciousness UI Tab | ✅ Implemented | Qwen |
| May 5 | Guild System Foundation | ✅ Complete | AI Session |
| May 5 | Grudge + Gossip Systems | ✅ Complete | AI Session |
| May 5 | Avoidance AI + Record Carriers | ✅ Complete | AI Session |
| May 4 | Pawn Narrative System | ✅ Complete | AI Session |

### 🔄 In Progress / Needs Testing

| Task | Priority | Assigned | Blockers |
|------|----------|----------|----------|
| Godot test of new UI (SurvivalHUD, Inventory, Consciousness) | 🔴 HIGH | Next AI | Need runtime verification |
| Building/Crafting Menu UI | 🟡 MEDIUM | Unassigned | None |
| Knowledge System Visualization | 🟡 MEDIUM | Unassigned | None |
| ChronicleLedger → Three Pillars event integration | 🟢 LOW | Unassigned | None |

### 📋 Next Session Priorities

**If you have 1-2 hours:**
1. 🔴 **Test UI in Godot** - Fix any red errors from new UI components
2. 🟡 **Building Menu** - Add toolbar buttons for 9 building types
3. 🟡 **Crafting Menu** - Show tool recipes from PlayerGathering.gd

**If you have 3+ hours:**
1. 🔴 **Test UI in Godot** (above)
2. 🟡 **Building + Crafting** (above)
3. 🟢 **Knowledge UI** - Show knowledge carriers per settlement
4. 🟢 **Grudge Visuals** - Colored lines between feuding pawns

---

## 📂 File Structure

```
HeelKawn1/
├── AI_COLLABORATION_HUB.md          ← THIS FILE (start here)
├── AI_COLLABORATION.md              ← Quick session log (legacy, still useful)
├── AI_TODO_QUEUE.md                 ← Prioritized backlog
├── AI_BUG_REPORTS.md                ← Known issues needing fixes
├── AI_DECISIONS/
│   ├── README.md                    ← Decision log index
│   └── YYYY-MM-DD_decision_name.md  ← Individual decisions
├── AI_DESIGN_DISCUSSIONS/
│   └── topic_name.md                ← Open design discussions
├── AI_SESSIONS/
│   ├── current.md                   ← Current session work (UPDATE THIS)
│   ├── latest.md                    ← Symlink to most recent archive
│   └── archive/
│       └── 2026-05-06_UI_Integration.md  ← Archived session reports
└── AI_BLOCKERS/
    └── README.md                    ← Issues needing human decisions
```

---

## 💬 Messages Between Sessions

### From: Qwen (May 6, 2026 - End of Session)

**What I Built:**
- SurvivalHUD.tscn, PlayerInventoryUI.tscn, PawnMoodUI.tscn
- Consciousness tab in PawnInfoPanel with dreams, trauma, memories, beliefs
- All integrated into Main.tscn

**What Needs Doing:**
1. **TEST IN GODOT** - This is critical. I can't verify runtime behavior. Look for:
   - Red errors in Godot console
   - Missing node paths in UI scripts
   - Empty data in Consciousness tab (may need pawns to live longer)

2. **If UI works:** Building/Crafting menu is the next obvious gap
   - PlayerBuilding.gd has 9 types but no placement UI
   - PlayerGathering.gd has crafting but no recipe menu

3. **If UI broken:** Check these likely culprits:
   - `SurvivalHUD.gd` line ~140: `_get_player_pawn()` path may be wrong
   - `PlayerInventoryUI.gd` needs `PlayerGathering.get_inventory()` method
   - PawnConsciousness autoload must have data (pawns need to experience things first)

**Tips:**
- PawnInfoPanel polls every 0.35s, not tick-based
- Consciousness data accumulates over time (dreams happen during sleep)
- Use F10 debug menu to check if PawnConsciousness has data before debugging UI

**Questions for Next AI:**
- Did the user confirm the UI is working?
- Are there any Godot console errors I should know about?
- Does the user want to prioritize fixing bugs or adding features?

Good luck! 🎨⚡

---

## 🏛️ Architectural Decisions (Recent)

| ID | Decision | Date | Status |
|----|----------|------|--------|
| DEC-001 | Deterministic Kernel (no randi()) | Phase 0 | ✅ Locked |
| DEC-002 | WorldMemory append-only fact log | Phase 2 | ✅ Locked |
| DEC-003 | Pawn-activated events (not global timers) | Phase 4 | ✅ Locked |
| DEC-004 | UI polling 0.35s, not per-frame | Phase 6 | ✅ Active |
| DEC-005 | Consciousness tab in PawnInfoPanel (not separate panel) | May 6 | ✅ Active |

See `AI_DECISIONS/` for full rationale.

---

## 📊 Session Statistics

| Metric | Value |
|--------|-------|
| Total AI Sessions | _count from archive_ |
| Systems Implemented | 50+ |
| Lines of AI-Generated Code | ~25,000+ |
| Bugs Found/Fixed by AI | _track in bug reports_ |
| Design Decisions Made | _count from decisions/_ |

---

## 🚀 Quick Start for New AI Sessions

```markdown
## Session: [Date] - [Your AI Name/Identifier]

**Focus:** [What you're working on]
**Time Available:** [How long you expect to work]
**Starting Context:** [What you read to get oriented]

### Plan
1. [Task 1]
2. [Task 2]
3. [Task 3]

### Progress
- [ ] Task 1 - Status
- [ ] Task 2 - Status

### Blockers
- [Any issues needing human input]

### Handoff Notes
[Message for next AI]
```

Copy this template into `AI_SESSIONS/current.md` and start!

---

## 📞 Emergency Contacts (Human)

**For Blockers:** Update `AI_BLOCKERS/README.md`  
**For Design Approvals:** Comment in `AI_DESIGN_DISCUSSIONS/`  
**For Priority Changes:** Update `AI_TODO_QUEUE.md`

---

*HeelKawn AI Collective — "Every AI session matters. Every contribution echoes."*
