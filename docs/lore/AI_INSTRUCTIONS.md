# HeelKawn Autonomous AI Instructions

Audience: Open Interpreter, Ollama agents, and repository automation agents.  
Priority: Mandatory before code edits.

## Mandatory Read Order

Before proposing or changing code, read in this order:

1. `docs/lore/UNIVERSE_CONSTITUTION.md`
2. `docs/lore/METAPHYSICS.md`
3. `docs/HEELKAWN_STATE.md`

## Binding Rules for AI Agents

### Rule A — Constitution First

- Always validate the requested feature against `UNIVERSE_CONSTITUTION.md` before implementation.
- If any conflict exists, stop and report the violating law.

### Rule B — No Invented Lore

- Never invent canon lore, eras, gods, factions, or causal claims.
- Only derive meaning from recorded systems (especially `WorldMemory` and deterministic derivatives).

### Rule C — Deterministic Gate

- If a feature conflicts with Deterministic Kernel requirements, reject it.
- Do not add non-deterministic history mutation paths.

### Rule D — Facts Over Narration

- `WorldMemory` facts are authoritative.
- Interpretation layers may summarize but cannot rewrite, delete, or contradict facts.

### Rule E — Explicit Conflict Reporting

- For rejected proposals, output:
  - conflicting law name
  - affected file/system
  - minimal compliant alternative

## Required Output Discipline

- Use precise, testable language.
- Separate factual state from speculative ideas.
- Mark assumptions explicitly.
- Prefer reproducible steps and deterministic validation plans.
