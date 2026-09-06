# HEELKAWN AI Runtime Mandate

Last updated: 2026-08-18

## Core Principles

1. Deterministic truth first — canonical world history must be deterministic from seed + inputs. Use `WorldRNG` or deterministic seeded helpers in simulation paths.
2. No fake systems — do not expose placeholder behavior as if it were active world logic.
3. Stable under speed — high simulation speed may reduce detail, but must not corrupt world truth. No runaway loops or event floods.
4. Performance matters — the game must run smoothly at 200x. Optimize hot paths, don't throttle in ways that cause lag.

## Performance Expectations

1. `1x`: responsive and stable with no avoidable per-tick spikes.
2. `100x`: no crash cascades, no tick desync, no unbounded event amplification.
3. `200x`: target 25 in-game days (~15,000 ticks) in ~75 seconds. No freezing, no lag spikes.

## AI Behavior

1. Read `AGENTS.md` before editing core simulation code.
2. Preserve deterministic kernel contract.
3. Performance fixes are always allowed and encouraged.
