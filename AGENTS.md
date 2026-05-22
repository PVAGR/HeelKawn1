# HEELKAWN AGENT OPERATING CONTRACT

This file is mandatory for all AI contributors in this repository.

## Mission

Protect simulation integrity first. HeelKawn must remain:
- deterministic,
- replayable from seed + inputs,
- stable at `1x` and `100x`,
- truthful (no placeholder systems presented as live behavior).

## Read Order Before Editing

1. `AI_README.md`
2. `docs/AI_RUNTIME_MANDATE.md`
3. `docs/HEELKAWN_STATE.md`
4. Latest `docs/STATE_VERIFICATION_YYYY-MM-DD.md`

## Non-Negotiable Runtime Rules

1. No untracked global RNG in canonical systems.
2. No frame/FPS-coupled world-truth decisions.
3. No world-state claims in UI that are not backed by active simulation.
4. No "stable at 100x" claims without verification evidence.

## Required Verification Before Declaring Work Done

Run:

```bash
bash tools/ai/sim-quality-gate.sh
```

When Godot is available, this includes:
- boot smoke,
- settlement public state smoke,
- world meaning region tag smoke,
- `1x` + `100x` performance smoothness smoke with consistency checks.

## Documentation Obligation

Every non-trivial simulation change must update:
- `docs/HEELKAWN_STATE.md`
- a dated verification note: `docs/STATE_VERIFICATION_YYYY-MM-DD.md`

Include:
- what changed,
- what was verified,
- what remains unverified/risky.

