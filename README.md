# HeelKawn

**Official repository:** [github.com/PVAGR/HeelKawn1](https://github.com/PVAGR/HeelKawn1) (`main`)

**A deterministic myth-simulation where worlds live without the player.**

HeelKawn is a single-player offline world simulator where time flows independently, settlements rise and fall, and history accumulates whether you watch or not. Built on Godot 4.6, it implements a deterministic kernel architecture: memory → meaning → persistence → culture → behavior.

For canonical repository workflow and scope rules, see [`docs/CANONICAL_REPOSITORY.md`](docs/CANONICAL_REPOSITORY.md).

## Quick Start

### Prerequisites

- **Godot 4.6** (or later) must be installed and available in your system PATH
- Run the check script to verify:
  - **Windows**: `.\check_godot_path.bat`
  - **Linux/macOS**: `./check_godot_path.sh`

### Launch the Game

**Windows**:
```cmd
.\play.bat
```

**Linux/macOS**:
```bash
./play.sh
```

### Export Executable

**Windows**:
```cmd
.\export.bat
```

**Linux/macOS**:
```bash
./export.sh
```

### Additional Scripts

**Simulation Worker (headless)**:
- Windows: `.\play_worker.bat`
- Linux/macOS: `./play_worker.sh`

**Launch with Log Capture**:
- Windows: `.\play_capture.bat`
- Linux/macOS: `./play_capture.sh`

## Documentation

- **[HEELKAWN_STATE.md](docs/HEELKAWN_STATE.md)** — Authoritative project state (read this first)
- **[LLM_ONBOARDING.md](docs/LLM_ONBOARDING.md)** — Onboarding guide for AI assistants
- **[SESSION_LOG.md](docs/SESSION_LOG.md)** — Cross-LLM session continuity log
- **[CANONICAL_REPOSITORY.md](docs/CANONICAL_REPOSITORY.md)** — Repository scope and workflow rules
- **[CURSOR_MASTER_PLANNING_SPEC.md](docs/CURSOR_MASTER_PLANNING_SPEC.md)** — Tiered canon and planning priorities
- **[HEELKAWN_STANDALONE_MASTER_PLAN.md](docs/HEELKAWN_STANDALONE_MASTER_PLAN.md)** — Product vision and roadmap
- **[HEELKAWN_INFINITE_ARCHITECTURE.md](docs/HEELKAWN_INFINITE_ARCHITECTURE.md)** — Architecture blueprint

## Core Principles

- **Deterministic History**: No RNG in world history; same conditions produce same outcomes
- **Append-Only Memory**: Events are recorded, never deleted, always explainable
- **Derived Meaning**: Interpretation systems read facts but never write them
- **Always-Living World**: Simulation continues whether observed or not
- **Ordinary Human Start**: No chosen-one fantasy; significance must be earned

## Architecture

```
WorldMemory → WorldMeaning → WorldPersistence → Culture → Behavior
```

- **Memory** is fact (append-only event log)
- **Meaning** is derived (computed from facts)
- **Persistence** is consequence (scars, ruins, cultural drift)
- **Behavior** is response (pawns react to memory and meaning)

## Current Phase: Identity & Meaning

- Settlements build themselves, diverge culturally, can be abandoned or revived
- Animals reproduce, decline, recover, or go extinct deterministically
- Cultural memory shapes regional behavior
- Ruins and scars persist as permanent world history

## Contributing

If you're working on HeelKawn:

1. Read `docs/HEELKAWN_STATE.md` first
2. Never introduce randomness to world history
3. Never refactor kernel/autoload systems without explicit direction
4. Preserve deterministic behavior at all costs
5. Document changes in session logs

## License

See [LICENSE](LICENSE)

## Links

- Repository: https://github.com/PVAGR/HeelKawn1
- Game Vision: [docs/WORLD_BIBLE/GAME_VISION.md](docs/WORLD_BIBLE/GAME_VISION.md)
