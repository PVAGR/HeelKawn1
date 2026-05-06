# 🤖 HeelKawn AI Collaboration System

**OpenClaw-style multi-session AI workspace for HeelKawn development.**

---

## 📚 Quick Navigation

| File | Purpose | Who Uses |
|------|---------|----------|
| [`AI_COLLABORATION_HUB.md`](AI_COLLABORATION_HUB.md) | **START HERE** - Central coordination, current status, handoff messages | All AI (every session) |
| [`AI_TODO_QUEUE.md`](AI_TODO_QUEUE.md) | Prioritized backlog of work | AI choosing what to build |
| [`AI_BUG_REPORTS.md`](AI_BUG_REPORTS.md) | Known issues and fixes | AI debugging |
| [`AI_SESSIONS/current.md`](AI_SESSIONS/current.md) | In-progress session work | AI during session |
| [`AI_DECISIONS/README.md`](AI_DECISIONS/README.md) | Architectural decisions | AI making design choices |
| [`AI_DESIGN_DISCUSSIONS/`](AI_DESIGN_DISCUSSIONS/) | Open design discussions | AI proposing changes |
| [`AI_BLOCKERS/README.md`](AI_BLOCKERS/README.md) | Issues needing human input | AI stuck on decisions |

---

## 🎯 How AI Assistants Use This System

### Session Workflow

```
┌─────────────────────────────────────────────────────────────┐
│ 1. SESSION START                                             │
│    ├─ Read AI_COLLABORATION_HUB.md (current status)         │
│    ├─ Read AI_SESSIONS/latest.md (previous session)         │
│    ├─ Read AI_SESSIONS/current.md (if exists, in-progress)  │
│    └─ Check AI_TODO_QUEUE.md (what to build)                │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│ 2. DURING SESSION                                            │
│    ├─ Update AI_SESSIONS/current.md (progress)              │
│    ├─ Log bugs in AI_BUG_REPORTS.md (if found)              │
│    ├─ Propose designs in AI_DESIGN_DISCUSSIONS/ (if needed) │
│    └─ Raise blockers in AI_BLOCKERS/ (if stuck)             │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│ 3. SESSION END                                               │
│    ├─ Complete AI_SESSIONS/current.md                       │
│    ├─ Archive to AI_SESSIONS/archive/YYYY-MM-DD_name.md     │
│    ├─ Update AI_COLLABORATION_HUB.md (status, handoff)      │
│    └─ Update AI_TODO_QUEUE.md (mark done, add new tasks)    │
└─────────────────────────────────────────────────────────────┘
```

---

## 📁 File Structure

```
HeelKawn1/
├── AI_COLLABORATION_HUB.md          ← Central hub (READ FIRST)
├── AI_COLLABORATION.md              ← Legacy log (still useful)
├── AI_TODO_QUEUE.md                 ← Prioritized backlog
├── AI_BUG_REPORTS.md                ← Known bugs
├── AI_SESSIONS/
│   ├── current.md                   ← Active session work
│   ├── latest.md                    ← Points to latest archive
│   └── archive/
│       └── 2026-05-06_Session.md    ← Archived reports
├── AI_DECISIONS/
│   └── README.md                    ← Decision log
├── AI_DESIGN_DISCUSSIONS/
│   └── topic_name.md                ← Design proposals
├── AI_BLOCKERS/
│   └── README.md                    ← Human decisions needed
└── QWEN.md                          ← Project context (AI memory)
```

---

## 🏷️ Priority Labels

| Label | Meaning | Action |
|-------|---------|--------|
| 🔴 HIGH | Critical, do first | Fix immediately |
| 🟡 MEDIUM | Important | Do after HIGH |
| 🟢 LOW | Nice to have | If time permits |

---

## 📊 Status Indicators

| Status | Meaning |
|--------|---------|
| ✅ Complete | Done, tested, working |
| 🔄 In Progress | Being worked on |
| ⚠️ Needs Testing | Implemented, not verified |
| 🚧 Blocked | Waiting on human input |
| ❌ Reversed | Undone, don't repeat |

---

## 💬 Leaving Handoff Messages

Every session ends with a handoff message in `AI_COLLABORATION_HUB.md`:

```markdown
## 💬 Messages Between Sessions

### From: [AI Name] ([Date])

**What I Built:**
- [Thing 1]
- [Thing 2]

**What Needs Doing:**
1. 🔴 **CRITICAL:** [Must-do task]
2. 🟡 **Important:** [Should-do task]
3. 🟢 **If time:** [Nice-to-have]

**Tips:**
- [Gotcha to avoid]
- [Helpful hint]

**Questions for Next AI:**
- [Thing you want to know]
```

---

## 🎓 Best Practices

### For AI Assistants

1. **Read first, code second** - Understand context before changing
2. **Leave breadcrumbs** - Explain why, not just what
3. **Test when possible** - Verify before marking complete
4. **Ask when unsure** - Use AI_BLOCKERS for human decisions
5. **Update as you go** - Don't batch updates at end

### For Humans

1. **Review AI_SESSIONS/** - See what was built
2. **Clear AI_BLOCKERS/** - Unstick AI decisions
3. **Update priorities** - Move tasks in AI_TODO_QUEUE.md
4. **Respond to design discussions** - Comment in AI_DESIGN_DISCUSSIONS/

---

## 🚀 Getting Started (New AI Session)

**5-Minute Orientation:**

1. **Read** `AI_COLLABORATION_HUB.md` (2 min)
   - Current project state
   - Handoff messages
   - Session priorities

2. **Check** `AI_TODO_QUEUE.md` (1 min)
   - What's high priority
   - What's available to work on

3. **Read** `AI_SESSIONS/latest.md` (2 min)
   - What previous session did
   - What they learned

4. **Start working!**
   - Update `AI_SESSIONS/current.md` as you go
   - Ask for help via `AI_BLOCKERS/` if needed

---

## 📞 Emergency Procedures

### If You Break Something

1. **Log it** in `AI_BUG_REPORTS.md`
2. **Note it** in `AI_SESSIONS/current.md`
3. **Fix it** if you have time
4. **Handoff** to next AI if you don't

### If You're Stuck

1. **Check** if it's a known issue (`AI_BUG_REPORTS.md`)
2. **Research** the problem (read related files)
3. **Ask** via `AI_BLOCKERS/README.md` if still stuck
4. **Suggest** options for human to choose

### If You Disagree with a Decision

1. **Check** `AI_DECISIONS/` - may already be decided
2. **Open** design discussion in `AI_DESIGN_DISCUSSIONS/`
3. **Propose** alternative with rationale
4. **Wait** for human response before changing

---

## 🏆 Success Metrics

**Good AI Collaboration:**

- ✅ Every session knows what previous session did
- ✅ No duplicated work (two sessions building same thing)
- ✅ Bugs tracked and fixed systematically
- ✅ Decisions documented for future reference
- ✅ Human priorities clearly communicated
- ✅ AI suggestions influence project direction

---

## 📚 Related Documentation

| Doc | For | Purpose |
|-----|-----|---------|
| `AI_README.md` | AI | Core philosophy, non-negotiable principles |
| `QWEN.md` | AI | Project context, system overview |
| `docs/HEELKAWN_STATE.md` | AI + Human | Authoritative project state |
| `CHANGELOG.md` | Human + Players | Version history |
| `README.md` | Players | Project overview |

---

*HeelKawn AI Collective — "Continuity through documentation, excellence through collaboration."*
