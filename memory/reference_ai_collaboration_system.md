---
name: AI Collaboration System
description: OpenClaw-style multi-session AI workspace with handoffs, decisions, and task tracking
type: reference
---

**AI Collaboration System** created May 6, 2026.

**What:** Complete multi-session AI coordination workspace modeled after OpenClaw collaborative development patterns.

**Why:** HeelKawn development spans many AI sessions. Without continuity mechanisms, each session starts from zero. This system ensures:
- Every AI knows what previous sessions built
- Decisions are recorded and respected
- Bugs are tracked across sessions
- Handoffs are smooth and informative
- Human priorities are clear

**Components:**

1. **AI_COLLABORATION_HUB.md** - Central coordination point
   - Current project state
   - Session priorities
   - Handoff messages between AIs
   - File structure index

2. **AI_TODO_QUEUE.md** - Prioritized backlog
   - HIGH/MEDIUM/LOW priority tasks
   - Acceptance criteria for each task
   - Completed work tracking
   - Long-term vision gaps

3. **AI_BUG_REPORTS.md** - Issue tracking
   - Critical/High/Medium/Low severity
   - Reproduction steps
   - Fix status tracking
   - Known quirks (not bugs)

4. **AI_SESSIONS/** - Session reports
   - current.md (in-progress)
   - latest.md (points to most recent archive)
   - archive/ (historical reports)
   - Detailed work logs per session

5. **AI_DECISIONS/README.md** - Architectural decisions
   - Decision log with rationale
   - Alternatives considered
   - Implications for future work
   - Locked vs active decisions

6. **AI_DESIGN_DISCUSSIONS/** - Open design proposals
   - Topic-specific discussions
   - Options with pros/cons
   - Decisions recorded when closed

7. **AI_BLOCKERS/README.md** - Human decisions needed
   - Issues AI cannot decide
   - Options with recommendations
   - Impact of delay

8. **AI_COLLABORATION_README.md** - System documentation
   - How to use the system
   - Session workflow
   - Best practices
   - Emergency procedures

**How to apply:**

**For AI starting a session:**
1. Read AI_COLLABORATION_HUB.md
2. Read AI_SESSIONS/latest.md
3. Check AI_TODO_QUEUE.md
4. Begin work, update current.md

**For AI during a session:**
1. Update AI_SESSIONS/current.md with progress
2. Log bugs in AI_BUG_REPORTS.md
3. Raise blockers in AI_BLOCKERS/README.md
4. Propose designs in AI_DESIGN_DISCUSSIONS/

**For AI ending a session:**
1. Complete AI_SESSIONS/current.md
2. Archive to AI_SESSIONS/archive/
3. Update AI_COLLABORATION_HUB.md with handoff
4. Update AI_TODO_QUEUE.md with completed work

**CRITICAL: PERMANENT RECORDS**
- **NEVER DELETE session reports** — All AI work in collaboration files is PERMANENT
- Other AIs read these to understand what was built, why, and how
- When starting new session, APPEND below existing content, never overwrite
- Permanent records enable async collaboration across timezones/sessions
- This is how OpenClaw-style teams coordinate without direct communication

**For humans:**
1. Review AI_SESSIONS/ to see what AI built
2. Clear AI_BLOCKERS/ when decisions needed
3. Update AI_TODO_QUEUE.md priorities
4. Comment on AI_DESIGN_DISCUSSIONS/ proposals

**Related memories:**
- Documentation Structure (reference_documentation_structure.md) - Where this fits in repo
- Honest Status Reporting (feedback_honest_status.md) - Accuracy in bug reports
- Prefer Forward Progress (feedback_forward_progress.md) - Efficient handoffs
