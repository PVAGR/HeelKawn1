# HEELKAWN AI Runtime Mandate (Non-Negotiable)

Last updated: 2026-05-22

This file is a hard contract for all future AI contributors.

HeelKawn must run coherently at both:
- `1x` real-time observation/play
- `100x` stress simulation for large-scale testing

## 1. Core Principles

1. Deterministic truth first
- Canonical world history must be deterministic from seed + inputs.
- Use `WorldRNG` or deterministic seeded helpers in simulation paths.

2. No fake systems
- Do not expose placeholder behavior as if it were active world logic.

3. Stable under speed
- High simulation speed may reduce detail, but must not corrupt world truth.
- No runaway loops or event floods.

4. Evidence over claims
- Every meaningful simulation change must record verification notes.

## 2. Definition Of Done (Simulation Work)

A simulation change is not done until:

1. Determinism guard passes:
```bash
bash tools/ai/sim-quality-gate.sh
```

2. Runtime smoke is executed if Godot is present.

3. State docs are updated with:
- implementation delta,
- verification evidence,
- remaining risk.

## 3. Performance Expectations

1. `1x`:
- responsive and stable with no avoidable per-tick spikes.

2. `100x`:
- no crash cascades,
- no tick desync,
- no unbounded event amplification.

## 4. Required AI Behavior

Every AI must:
1. Read `AI_README.md` and this file before editing core simulation code.
2. Preserve deterministic kernel contract.
3. Avoid claiming runtime stability without evidence.
