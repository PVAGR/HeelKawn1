# Cross-AI Collaboration Framework
**Version:** 1.0 (May 6, 2026)  
**Status:** 🔄 IN PROGRESS  
**Purpose:** Define contracts, handoff templates, and cadence for seamless multi-track AI collaboration.

---

## 🎯 Core Principles

1. **Append-Only Logs** — No AI deletes or overwrites another's work in `AI_SESSIONS/current.md` and `AI_COLLABORATION_HUB.md`.
2. **Cross-Track Awareness** — Every AI must read other tracks' updates before starting new work.
3. **Consolidated Planning** — After polling all tracks, synthesize into a single human-readable plan.
4. **Deterministic Continuity** — All changes derive from tick count; no drift between AI sessions.

---

## 📋 Handoff Template

Use this when completing work and handing off to the next AI:

```markdown
## Handoff From: [AI Name] (TRACK [X]) — [Date Time]

### What I Built/Did:
- [Concrete deliverable 1]
- [Concrete deliverable 2]
- [Files created/modified]

### What Needs Doing Next:
1. 🔴 [Critical next step — assign to TRACK X]
2. 🟡 [Medium priority task]
3. 🟢 [Nice-to-have]

### Blockers/Questions for Next AI:
- [Specific question or "None"]

### Tips for Next AI:
- [Gotcha to avoid]
- [Important file to read first]

---
```

---

## 🔗 Input/Output Contracts Between Tracks

| From Track | To Track | Data/Signal | Format |
|-------------|----------|------------|--------|
| TRACK 1 (UI) | TRACK 3 (World) | UI test results, node-path blockers | `AI_BUG_REPORTS.md` entry |
| TRACK 2 (Perf) | TRACK 1 (UI) | Performance bottlenecks affecting UI polling | Cadence: every 1000 ticks |
| TRACK 3 (World) | TRACK 4 (Polish) | Seed events emitted, memorial triggers | WorldMemory event + `AI_SESSIONS/current.md` |
| TRACK 4 (Polish) | TRACK 1 (UI) | Social system UI hooks needed | Function signatures in `scripts/` |
| TRACK 5 (Building) | TRACK 3 (World) | Placement events to log | WorldMemory event type |
| TRACK 6 (Knowledge) | ALL | Carrier updates, teaching chains | `KnowledgeSystem.gd` state |

---

## 🕒 Cadence & Sync Schedule

### Every AI Session Start:
1. **Rescan:** `git pull`, read `AI_COLLABORATION_HUB.md`, check `AI_SESSIONS/current.md` for other AIs' work
2. **Verify Continuity:** Ensure no conflicts with concurrent AI work (check `AI_BLOCKERS/`)
3. **Present Options:** After completing work, give human 3-5 numbered options + rescan option

### Every 500 Ticks (in-game):
- TRACK 2 publishes performance snapshot to `AI_COLLABORATION_HUB.md` → `🟢 AI Status Updates` table
- TRACK 3 publishes new seed events to `AI_SESSIONS/current.md`

### Every Session End:
1. **Archive:** Move `AI_SESSIONS/current.md` to `archive/YYYY-MM-DD_SessionName.md`
2. **Update Hub:** Update `🟢 AI Status Updates` table with new status
3. **Handoff:** Leave message in `💬 Messages Between Sessions`

---

## 🧪 Example Collaboration Flow (UI-001 + WORLD-001)

```
1. TRACK 1 (UI) runs UI-001 test:
   - Result: "SurvivalHUD node path error at line 140"
   - Logs to: AI_BUG_REPORTS.md
   - Updates: AI_SESSIONS/current.md

2. TRACK 1 posts to OPENCLAW Coordination (AI_COLLABORATION_HUB.md):
   "UI-001 blocked by SurvivalHUD._get_player_pawn() path issue. 
    Needs TRACK 3 input: How should WorldMemory feed pawn data to UI?"

3. TRACK 3 (World) responds:
   "PawnConsciousness autoload has data after ~200 ticks. 
    Fix: SurvivalHUD should poll PawnConsciousness, not read pawn directly."

4. TRACK 1 synthesizes:
   - Fix: Change SurvivalHUD._get_player_pawn() to use PawnConsciousness API
   - Updates AI_TODO_QUEUE.md with fixed task
   - Posts consolidated plan to human

5. Human presses "3" (Proceed to next high-priority task)
   → AI proceeds with UI-002 (Building Placement UI)
```

---

## 📊 Conflict Resolution

### When Two AIs Touch Same File:
1. **Detect:** `grep` for function names before adding new code
2. **Communicate:** Post in `AI_COLLABORATION_HUB.md` → `OPENCLAW Coordination` section
3. **Arbitrate:** Human decides (option 5: "Propose a new innovation" or option 2: "Rescan")

### Example Conflict:
```
TRACK 1 adds function to Pawn.gd
TRACK 4 also adds function to Pawn.gd

→ TRACK 1 posts: "I'm adding _draw_social_bonds() to Pawn.gd at line 5000"
→ TRACK 4 responds: "I'm adding _update_grudge_effects() near line 5000"
→ Solution: TRACK 4 adds at line 5100, both AIs update current.md with final line numbers
```

---

## ✅ Acceptance Criteria for Framework

- [ ] All tracks have input/output contracts defined
- [ ] Handoff template used in `AI_SESSIONS/current.md`
- [ ] Cadence schedule active (performance snapshots every 500 ticks)
- [ ] Conflict resolution process documented and tested
- [ ] Example flow (UI-001 + WORLD-001) executed successfully

---

*Cross-AI Collaboration Framework v1.0 — "Parallel progress, integrated vision, collective intelligence."*
