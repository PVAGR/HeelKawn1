# Session Start Prompt

**Last updated:** 2026-05-14

Copy this prompt when starting a new AI session:

---

```
I'm working on HeelKawn, a deterministic Godot 4.6.2 world simulation.

Please follow this read order before doing any work:

1. brain/README.md — How the Universe Brain works
2. brain/memory/active_context.md — What we're currently working on
3. brain/memory/index.json — Knowledge map
4. brain/memory/knowledge/architecture.md — System structure
5. brain/memory/knowledge/design_decisions.md — Why things were built this way
6. brain/lore/canonical.md — Universe canon (non-negotiable rules)
7. docs/HEELKAWN_STATE.md — Authoritative project state (wins on conflicts)
8. HEELKAWN.txt — Last session handoff
9. AI_README.md — Master AI instructions

After reading these, tell me:
- What you understand about the current project state
- What tasks are pending
- What you recommend we work on next

Then wait for my instruction.
```

---

## What This Does

1. Loads all context about the project
2. Ensures the AI knows the canon rules before touching code
3. Aligns the AI with current work priorities
4. Prevents the AI from making assumptions
