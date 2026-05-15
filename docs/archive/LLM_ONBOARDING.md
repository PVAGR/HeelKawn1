# HEELKAWN — LLM ONBOARDING

If you are an AI assisting with this project:

## READ THESE FIRST

1. docs/HEELKAWN_STATE.md
2. docs/NEURAL_NETWORK_STATE.md (if working on neural network features)
3. HEELKAWN.txt
4. README.md
5. docs/CANONICAL_REPOSITORY.md — **which folder and remote are authoritative** (ignore other HeelKawn paths unless migrating here)
6. docs/AI_RESUME.md — fastest re-entry point when context is small or rate-limited

For planning, tiered canon, lore vs kernel scope, or roadmap-heavy work, also read **docs/CURSOR_MASTER_PLANNING_SPEC.md** after the files above.

## DO NOT:

- introduce unseeded/random historical state in canonical simulation paths
- refactor kernel systems
- add UI explanations
- break determinism contracts (seeded `WorldRNG` streams are allowed)
- "simplify" systems

## ARCHITECTURE SUMMARY

WorldMemory → WorldMeaning → WorldPersistence → Culture → Behavior

Memory is fact.
Meaning is derived.
Persistence is consequence.
Behavior is response.

Autoloads are global truth.
Do not add class_name to autoload scripts.

If you are unsure, do nothing and ask.

## HISTORICAL DOCS POLICY

- Older design docs can be used as **universe-history and canon-reference material**.
- Engineering authority for what to build now still comes from:
  1) `docs/HEELKAWN_STATE.md`
  2) `HEELKAWN.txt`
  3) active phase/roadmap docs under `docs/`
- If a historical doc conflicts with current state docs, follow current state docs and record canon decisions in world-bible/canon logs.

## RECOMMENDED STACK (FREE-FOREVER FRIENDLY)

### Coding stack (primary)

- Godot 4.6 + GDScript for gameplay and world simulation
- GitHub repo as source of truth for all code and design decisions
- Cursor for implementation and refactoring

### Conversation + memory stack (primary)

- Repo-first memory: facts must live in files, not chat history
- Qwen Studio (or any free chat model) for brainstorming and writing passes
- Cursor for code execution and project-aware edits

### Optional zero-credit fallback

- Ollama local model for continuity/handoff summarization when hosted models are rate-limited
- Keep prompts grounded by attaching only relevant project files

## REQUIRED MEMORY WORKFLOW (EVERY SESSION)

1. Read `docs/HEELKAWN_STATE.md` and this file first.
2. Read `docs/WORLD_BIBLE/MASTER_INDEX.md` if the task touches lore/history.
3. Before coding, write a short intent note in `docs/SESSION_LOG.md`.
4. After coding, append:
   - what changed
   - why it changed
   - what to do next
5. If a model context is full or credits run out, continue from `docs/SESSION_LOG.md` instead of rebuilding context from memory.
6. If you need the shortest possible resume path, read `docs/AI_RESUME.md` and then `docs/SESSION_LOG.md`.

## CANON SAFETY RULE

- Stable truth belongs in `docs/HEELKAWN_STATE.md`.
- Temporary ideas belong in `docs/SESSION_LOG.md`.
- Do not treat chat output as canonical until it is written to repo files.
