# Lore Recall Prompt

Use this when you need the AI to check universe canon before making a design change:

---

```
I'm considering a change to HeelKawn that affects [describe the area: settlement behavior / pawn AI / world events / culture / etc.].

Before we proceed, please check the canon and tell me:

1. What does brain/lore/canonical.md say about this area?
2. What does docs/WORLD_BIBLE/ say about this topic? (check MASTER_INDEX.md first)
3. Are there any non-negotiable rules (T1 — Kernel locked) that apply?
4. Is this area T1 (locked), T2 (strong), T3 (direction), or T4 (exploratory)?
5. What past decisions are relevant? (check brain/memory/knowledge/design_decisions.md)

The change I want to make is: [describe the change]

Tell me if this is compatible with canon, or what would need to change.
```

---

## What This Does

- Prevents canon violations before they happen
- Identifies which canon tier applies (how flexible the rules are)
- Surfaces relevant past decisions
- Gives a clear yes/no on compatibility
