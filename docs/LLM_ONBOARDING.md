# HEELKAWN — LLM ONBOARDING

If you are an AI assisting with this project:

## READ THESE FIRST

1. docs/HEELKAWN_STATE.md
2. README.md
3. docs/SESSION_LOG.md (history only)
4. HEELKAWN.txt (pointer/handoff only)

## AUTHORITY LOCK

- `docs/HEELKAWN_STATE.md` is the only canonical live-state authority.
- `docs/SESSION_LOG.md` is historical continuity only (append-only log).
- `HEELKAWN.txt` and `docs/HEELKAWN_SNAPSHOT.md` are handoff aids, not equal authority.
- `HEELKAWN_KERNEL.md` is historical reference only.
- If any doc conflicts with `docs/HEELKAWN_STATE.md`, follow `docs/HEELKAWN_STATE.md`.

## LIVE STATE LOCK (MUST MATCH docs/HEELKAWN_STATE.md)

- Active lane is Phase 8 (Resource Truth / Settlement Economy).
- Phase 7 canonical validation milestone is locked and proven.
- Validation harness in debug is proven.
- Clean suppression is proven.
- `[SETTLEMENT_VERIFY]` is live with `center_region` continuity keying.
- `[SPECIALIZATION_VALIDATE]` is live.
- Phase 8 stock-truth observational layer exists.
- First runtime proof pass for stock-truth overlap safety has been achieved.
- Specialization remains proxy/job-pressure based, NOT stock-scarcity truth.
- Next target: cached per-settlement surplus/deficit interpretation on top of proven stock truth.

## ACTIVE RUNTIME SURFACE (CANONICAL AUTOLOADS)

- `WorldMemory`, `WorldMeaning`, `WorldPersistence`, `CulturalMemory`
- `SettlementMemory`, `IntentMemory`, `AgeMemory`
- `SettlementPlanner`, `SettlementRebirth`
- `TradePlanner`, `TradeMemory`
- `RemnantMemory`, `MythMemory`, `RoadMemory`
- `SacredMemory`, `ChronicleLog`, `WorldClock`, `WorldEvents`

## DO NOT:

- introduce randomness
- refactor kernel systems
- add UI explanations
- change determinism
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

## EXPLORATORY / INACTIVE CLARITY

Treat these as non-canonical runtime unless explicitly promoted in `docs/HEELKAWN_STATE.md`:
- `autoloads/FragmentationManager.gd`
- `autoloads/SchismManager.gd`
- `scripts/kernel/settlement_persistence.gd`

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
3. Before coding, confirm whether the target file is canonical, historical, or exploratory from `docs/HEELKAWN_STATE.md`.
4. Before coding, write a short intent note in `docs/SESSION_LOG.md`.
5. After coding, append:
   - what changed
   - why it changed
   - what to do next
6. If a model context is full or credits run out, continue from `docs/SESSION_LOG.md` instead of rebuilding context from memory.

## CANON SAFETY RULE

- Stable truth belongs in `docs/HEELKAWN_STATE.md`.
- Temporary ideas belong in `docs/SESSION_LOG.md`.
- Do not treat chat output as canonical until it is written to repo files.
- Do not change determinism rules without explicit user approval.
- Do not reinterpret specialization as stock scarcity truth unless explicitly approved and canonical docs are updated first.

## DETERMINISM SCOPE HONESTY

- Do not overclaim full-repo determinism completion if known randomness risks still exist in other subsystems.
- Report validated deterministic lanes precisely, and separate remaining randomness cleanup as pending work.
