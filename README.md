# HeelKawn

**Official repository:** [github.com/PVAGR/HeelKawn1](https://github.com/PVAGR/HeelKawn1) (`main`).  
**This machine:** work only in this clone (the folder that contains this repo's `.git/`) for this project—do not split edits across other HeelKawn-named folders. Scope and push workflow: [`docs/CANONICAL_REPOSITORY.md`](docs/CANONICAL_REPOSITORY.md). One-command save: `powershell -File tools/Commit-PushMain.ps1 -Message "your message"`.

---

> **⚠️ AI AGENTS: READ AI_README.md FIRST**
>
> Before working on this repository, you MUST read `AI_README.md` at the repository root. It contains the canonical source of truth for:
> - The deterministic kernel choice
> - Current development phase (Phase 5: Emergent Life)
> - Core world laws and philosophy
> - Implementation rules and forbidden patterns
>
> **All AI agents must align with AI_README.md before making any changes.**

---

HeelKawn is a deterministic Godot 4.6 world simulation.

- The world remembers facts and evolves without RNG in history.
- Settlements and ecology evolve autonomously.
- The player is an observer/chronicler, not a commander.

Kernel status: complete (memory -> meaning -> persistence -> culture).

**Macro simulation:** `WorldEventSystem` (autoload) advances economy pressure, aggregate **world mood**, and weather-linked modifiers on a slow cadence (~every 1000 sim ticks) while `TickManager` drives the kernel. `LivingWorldController` remains the light pressure hook on `GameManager.game_tick`; pair it with `StockpileManager`/`WorldEventSystem` for supply-aware narratives.

**Documentation:**
- `AI_README.md` — Canonical AI instructions and kernel rules (READ FIRST for all AI agents)
- `docs/HEELKAWN_STATE.md` — Canonical project state
- `docs/LLM_ONBOARDING.md` — Cross-LLM continuity
- `docs/SESSION_LOG.md` — Session tracking
- `docs/CURSOR_MASTER_PLANNING_SPEC.md` — Tiered canon, lore vs kernel scope, planning priorities
- `docs/HEELKAWN_STANDALONE_MASTER_PLAN.md` — Standalone spectator/incarnation build order and feature master plan
- `docs/OBSERVER_TOOLKIT.md` — Observer automation (speed sweeps, timeline, canon guards)
- `docs/OBSERVER_CLEANUP_LOG.md` — Observer-driven cleanup decisions
