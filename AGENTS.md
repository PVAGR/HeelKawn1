# HEELKAWN AGENT OPERATING CONTRACT

## Mission

Protect simulation integrity first. HeelKawn must remain:
- deterministic,
- replayable from seed + inputs,
- stable at all speeds including 200x,
- truthful (no placeholder systems presented as live behavior).

## Core Rules

1. No untracked global RNG in canonical systems. Use `WorldRNG` streams.
2. No frame/FPS-coupled world-truth decisions.
3. No world-state claims in UI that are not backed by active simulation.
4. Facts first, meaning second.
5. Inspect existing files before creating new systems.
6. Prefer the smallest reversible change.

## Performance

The game must run smoothly at 200x speed. Performance fixes are always welcome. Do not throttle the simulation in ways that cause lag or freezing. Optimize hot paths, increase stride at high speed, cache expensive lookups.
