# 🚧 AI Blockers

**Issues requiring human decisions or input.** AI assistants cannot proceed without human guidance.

---

## Current Blockers

### BLK-C001: Main.gd edit access blocked (Autoload Consolidation)
- **Raised:** May 10, 2026
- **Raised By:** Cascade
- **Status:** 🟡 AWAITING HUMAN DECISION
- **Issue:** Cascade was banned from editing `Main.gd` after multiple edit failures due to content changes between attempts. 60+ autoload references in Main.gd still need updating. Options: (1) Use sed/bash commands, (2) Manual edit by user, (3) Update 20+ other script files first.

---

## Resolved Blockers

| ID | Blocker | Raised | Resolved | Resolution |
|----|---------|--------|----------|------------|
| BLK-001 | N/A | - | - | - |
| BLK-C001 | Main.gd edit access blocked | May 10, 2026 | - | Pending decision on approach |

---

## How to Raise a Blocker

When an AI assistant encounters a decision that requires human input:

1. **Create a new entry below** with:
   - Clear description of the decision needed
   - Options/alternatives with pros/cons
   - Recommended option (if applicable)
   - Files affected

2. **Update AI_COLLABORATION_HUB.md** to note the blocker

3. **Wait for human response** before proceeding with that work

---

## Blocker Template

```markdown
### BLK-XXX: [Short Description]

**Raised:** [Date]  
**Raised By:** [AI Name]  
**Status:** 🟡 AWAITING HUMAN DECISION

#### Decision Needed
[What needs to be decided]

#### Options

**Option A: [Name]**
- Pros: [list]
- Cons: [list]

**Option B: [Name]**
- Pros: [list]
- Cons: [list]

#### Recommendation
[AI's recommended option, if any]

#### Files Affected
- `path/to/file.gd`

#### Impact if Not Resolved
[What work is blocked]
```

---

## Fast-Track Decisions (AI Can Decide)

AI assistants **do not need human input** for:

- Code style/formatting choices
- Variable/function naming (follow project conventions)
- Refactoring for clarity (if behavior unchanged)
- Bug fixes with obvious solutions
- UI positioning/color tweaks

AI assistants **should ask** for:

- New system architecture
- Breaking changes to existing systems
- Design philosophy decisions
- Priority conflicts (which feature to build first)
- Anything that violates AI_README.md principles

---

*Last Updated: May 14, 2026*
