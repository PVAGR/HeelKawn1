# HeelKawn AI Resume

Use this file when context is tight or the previous model was rate-limited.

## Fast read order

1. `docs/HEELKAWN_STATE.md`
2. `docs/AI_RESUME.md` (this file)
3. `docs/SESSION_LOG.md`
4. `docs/HUMAN_SCALE_PROGRESSION_LADDER.md`
5. `docs/CURSOR_MASTER_PLANNING_SPEC.md` if you need roadmap or tier context

## Current working state

- The project is a deterministic Godot 4.6 simulation.
- The newest simulation path is a headless worker mode for benchmarking and background runs.
- The latest lightweight mode caps open jobs and pushes job access through pawn progression.
- Tooling was repaired so `Verify-Project.ps1` really reaches tick 1 and `Benchmark-Speeds.ps1` really runs the benchmark runner through the repo-pinned Godot console executable.
- Canonical simulation randomness now routes through seeded streams (`WorldRNG`) or local `RandomNumberGenerator` instances seeded from the world seed. Initial world generation is explicit (`--world-seed=...` or `20260429` default), and manual rerolls derive deterministic follow-up seeds.
- AI-origin incarnation commands are rejected from the human player incarnation channel until NPC ownership is separated.
- The world progression model now explicitly layers: individual -> family -> clan -> settlement -> region -> nation -> world.
- The repo has already been adjusted so future AI can resume from docs instead of chat history.

## Latest verified runtime facts

- 1,000 ticks at 32x in lightweight simulation mode completed in 0.491s.
- 10,000 ticks at 32x in worker mode completed under the 30s threshold.
- The benchmark timer was adjusted to start on the first emitted tick so startup time does not contaminate tick-only measurements.
- 2026-04-30 worker speed benchmark with `-TicksPerSample 20` passed every tier from 1x through 100x with 0 failures after the deterministic RNG pass.

## Core constraints

- No raw global RNG in canonical simulation/world-history paths; use `WorldRNG` named streams or clearly local seeded RNG.
- No per-tick O(N) recompute.
- Derived systems stay read-only.
- Autoloads do not use `class_name`.
- History must stay explainable after the fact.

## What to look at next

- `docs/SESSION_LOG.md` for the latest human/AI handoff notes.
- `docs/HUMAN_SCALE_PROGRESSION_LADDER.md` for the layered world design.
- `autoloads/GameManager.gd` for simulation/benchmark flags.
- `autoloads/JobManager.gd` for queue limits.
- `scripts/pawn/PawnData.gd` for lightweight progression gating.
- `autoloads/WorldRNG.gd` for deterministic stream helpers.

## If you are rate-limited

Continue from the files above. Do not rebuild the project state from chat; the repo already contains the durable handoff.
