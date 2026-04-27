# HeelKawn Kernel Notes (Historical)

This document is historical reference only.
It is superseded by docs/HEELKAWN_STATE.md, which is the authoritative project state file.

DO NOT use this file as live state, active phase, or next-target authority.
Use `docs/HEELKAWN_STATE.md` for all canonical current-state decisions.
Any phase table or roadmap text below is retained for historical context only.

---

## Kernel type: **A — deterministic**

- The world is a machine of cause and effect. Same conditions → same history (replayable, auditable).
- Memory does not decay at random. History does not lie. Persistence is earned by impact.

---

## Project phase (where we are)

| Phase | Name | World-completeness (not polish) |
|-------|------|---------------------------------|
| 0 | Engine survival | **100%** — done |
| 1 | Living world baseline | **~85%** — allowed to move on |
| 2 | **The kernel** (here) | **~30%** — core build-out |
| 3 | Historical continuity | 0% |
| 4 | Civilization & identity | 0% |
| 5 | Player meaning layer | 0% |

**Overall project (rough): ~55%** world-completeness.

### Phase 2 — The kernel (deterministic world memory + meaning + persistence)

**Already in repo:**

- `WorldTrace` (visual memory)
- Time / tick index
- Stable handles (tiles, pawns, zones)
- **WorldMemory v1** ([`autoloads/WorldMemory.gd`](autoloads/WorldMemory.gd)): append-only pawn/animal death facts, `MAX_EVENTS` cap, included in colony save (v2).

**To build (core):**

- **2.1 WorldMemory** — extend with more fact types (builds, starvation as world event, first occurrences); deaths + save path are in.
- **2.2 WorldMeaning** — derived, computed interpretations (e.g. “repeated death here”, “exhausted biome”). Never scripted.
- **2.3 Persistence rules** — what survives (ruins, scars, damage, later culture).

### Phase 1 gaps (tuning, not structure)

- Job vs labor pacing, food spiral, housing pressure — balance later.

---

## World principles

- The world remembers **facts**, not intentions.
- **Meaning is computed**, not scripted.
- **Persistence** is earned by **impact**.
- **UI must never dictate world truth.**

---

## Open questions (for later)

- Thresholds: “scar” vs “noise”
- How many repetitions count as history
- When land recovers vs stays damaged

---

## Last observed state (update when you ship or hit milestones)

- Long-run sim stable; deaths/signals/HUD no longer fragile.
- WorldTrace + WorldMemory v1 (death log + persist); WorldMeaning / persistence rules not implemented yet.
- (Fill in: e.g. “stable past Day N”, “food pressure …”, “job pressure high — tune later”.)

---

## Next build step

- **WorldMeaning** (derived tags from WorldMemory + world state), or extend **WorldMemory** with non-death fact types.
- **Not** coding the whole kernel at once.

---

## How the assistant “remembers”

The assistant does not retain long-term memory between threads unless you **paste context** or point at **files in this repo**. This file is the canonical handoff. Re-paste or `@`-reference `HEELKAWN_KERNEL.md` when starting a new session.
