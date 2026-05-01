# Code Review Prompt

Use this when you want an AI to review code changes:

---

```
Review the following code changes for HeelKawn.

Context:
- This is a deterministic Godot 4.6 world simulation
- Kernel rules: no unseeded RNG, append-only memory, player is observer
- Performance matters: avoid O(n²) in tick loops, use speed-aware cadences
- Check brain/lore/canonical.md for non-negotiable rules

Review criteria:
1. Does this break determinism? (unseeded random in sim paths)
2. Does this violate append-only memory rules?
3. Does this give the player command authority (forbidden)?
4. Will this cause performance hitches at high speeds (50x/100x)?
5. Does this contradict established canon?
6. Is the GDScript idiomatic and maintainable?
7. Are there edge cases not handled?

[Insert code diff or describe the change here]
```

---

## What This Checks

- Determinism violations
- Memory rule violations
- Player role violations
- Performance regressions
- Canon contradictions
- Code quality
- Edge case coverage
