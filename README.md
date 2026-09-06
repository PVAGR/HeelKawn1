# HeelKawn

A deterministic 2D persistent simulation universe built in Godot 4.6.2.

HeelKawn is a memory and consequence simulator where history is written by actions, not scripts. HeelKawnians survive, gather, build, teach, migrate, and form authority without player babysitting. The world is replayable from seed + inputs.

## Project Identity

- **Engine**: Godot 4.6.2 (GL Compatibility renderer)
- **Language**: GDScript (with C#/Mono integration in `dotnet/`)
- **Repository**: `github.com/PVAGR/HeelKawn1`
- **License**: MIT

## Getting Started

1. Open `project.godot` in Godot 4.6.2
2. Run the main scene (`scenes/main/Main.tscn`)
3. Use F10 for debug diagnostics and observation tools

## Read Order (AI Agents)

1. `AGENTS.md` -- operating manual, kernel rules, progress log (single source of truth)
2. `docs/HEELKAWN_STATE.md` -- authoritative current status
3. `docs/PHASE_TRACKER.md` -- 0.1 → 1.0 phase plan and current position
4. `docs/lore/` -- game canon

## Quality Gate

```bash
bash tools/ai/sim-quality-gate.sh
```

## Structure

- `autoloads/` -- core singleton managers (WorldMemory, WorldMeaning, SettlementMemory, etc.)
- `scripts/` -- game logic by domain (ai, camera, career, combat, data, kernel, memory, pawn, ui, world, etc.)
- `scenes/` -- scene files (main, pawn, stockpile, ui, world)
- `tests/` -- test scripts
- `tools/` -- utility and verification scripts
- `docs/` -- planning, specs, verification notes
- `docs/WORLD_BIBLE/` -- canon, glossary, master index

## Core Principles

- **Deterministic kernel**: same causes produce same outcomes
- **No unseeded RNG**: all randomness through WorldRNG seeded streams
- **No UI lies**: UI claims must be backed by active simulation
- **Impact-based persistence**: memory persists by impact, not random decay
