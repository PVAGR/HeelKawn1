# Canonical Map

This file is the shortest truthful map of the repo.
Use it first when you need to know what this project is and where to edit it.

## What this repo is

HeelKawn is a deterministic 2D persistent simulation universe built in Godot 4.6.2.
It is a memory and consequence simulator where HeelKawnians live, build, teach, migrate, and form authority through emergent behavior.

## Repository root

- `project.godot` -- Godot project file (144 autoloads registered, Godot 4.6.2)
- `AI_README.md` -- AI agent source of truth (read first)
- `AGENTS.md` -- mandatory agent operating contract
- `HEELKAWN.txt` -- quick-context orientation
- `TODO.md` -- active work tracking
- `README.md` -- project overview

## Where to edit

- Core simulation: `autoloads/` (WorldMemory, WorldMeaning, SettlementMemory, HeelKawnianManager, JobManager, etc.)
- Pawn behavior: `scripts/pawn/` (HeelKawnian.gd, HeelKawnianData.gd)
- AI logic: `scripts/ai/` (WorldAI.gd, HeelKawnPawnBrain.gd, HeelKawnianDecision.gd)
- UI: `scripts/ui/` (ColonyHUD, PawnInfoPanel, PawnMoodUI, etc.)
- World systems: `scripts/world/` (ZoomSystem, CataclysmSystem, etc.)
- Kernel: `scripts/kernel/` (WorldMemory, ObserverLens)
- Jobs: `scripts/jobs/` (Job.gd and subclasses)
- Scenes: `scenes/` (Main, Pawn, Stockpile, UI, World)
- Tests: `tests/` and `tools/` (smoke tests, quality gate)
- Documentation: `docs/` (state, verification, world bible)
- Canon: `docs/WORLD_BIBLE/` (glossary, master index, canon queue)

## Truth hierarchy (when docs conflict)

1. Source code and Godot runtime checks (highest truth)
2. `docs/BUILD_INVENTORY.md` -- built-vs-missing inventory
3. `docs/HEELKAWN_STATE.md` -- current working state
4. `docs/HEELKAWN_PROJECT_COMPASS.md` -- project compass
5. `AI_README.md` -- kernel philosophy (non-negotiable)
6. Historical docs / AI session notes -- evidence, not authority

## Quality gate

```bash
bash tools/ai/sim-quality-gate.sh
```

When Godot is available, runtime smoke includes boot, settlement, world meaning, and 1x/100x performance checks.

## Simple rule

One deterministic world. Code is truth. Runtime verifies. Docs track reality.
