# HeelKawn

HeelKawn is a deterministic, self-building 2D world simulation built in Godot 4.

This project is not a typical colony sim.
It is a **world with memory**.

The world:
- remembers what happened
- scars and heals
- builds settlements on its own
- diverges culturally
- sustains or collapses ecosystems
- does not rely on player micromanagement

The player is an observer, not a commander.

## Core Principles

- Determinism over randomness
- History > balance
- Systems build the world, not scripts
- No magic resets
- No hidden dice rolls

If the same things happen, the same history emerges.

## Current State

- Kernel complete (memory → meaning → persistence → culture)
- Autonomous settlements
- Deterministic animal populations
- Performance stabilized (event-driven recompute)

See `docs/HEELKAWN_STATE.md` for exact status.

## Tech

- Engine: Godot 4.6
- Language: GDScript
- Platform: PC (2D)
