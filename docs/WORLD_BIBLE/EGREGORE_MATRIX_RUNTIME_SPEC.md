# EGREGORE + MATRIX RUNTIME SPEC

Status: Canon design spec (implementation-targeted, deterministic-safe)
Date: 2026-05-28
Authority alignment:
- Runtime truth authority: `docs/HEELKAWN_STATE.md`
- Canon governance: `docs/WORLD_BIBLE/README.md`
- Determinism constraints: `docs/AI_RUNTIME_MANDATE.md`

## Purpose

Define HeelKawn as one integrated machine:
- **Simulation**: material world cause/effect.
- **Matrix**: shared decision-pressure fabric across all embodied actors.
- **Egregore**: collective social-belief pressure that emerges from repeated human behavior and memory.

This spec adds no scripted destiny and no hidden randomness.
All effects must come from logged facts and deterministic derivation.

## Canon Definitions

1. **Simulation Layer (Material Truth)**
- Food, shelter, labor, migration, conflict, death, birth, trade.
- Source of truth: append-only world facts.
- If not recorded in world facts, it is not canonical truth.

2. **Matrix Layer (Decision Field)**
- The per-pawn and per-settlement pressure solver.
- Produces choices from needs, memory, role, social ties, and risk.
- Must be replayable: same seed + same inputs => same outcomes.

3. **Egregore Layer (Collective Mind Pressure)**
- Not a deity and not authored lore.
- Emerges when many people repeat the same patterns (ritual, fear, trust, taboo, law, trade norms).
- Exists as a measurable field that biases decisions, institutions, and cultural continuity.
- Can strengthen, fracture, merge, or fade with demographic/historical change.

## Deterministic Guardrails

- No unseeded RNG in canonical updates.
- No frame-dependent world-truth mutations.
- No UI-only claims of egregore/matrix states.
- Any egregore effect must map to concrete logged inputs and explicit formulas.
- Any religious/metaphysical interpretation must remain downstream of fact logs.

## Proposed Runtime Data Model (Implementation Target)

1. **EgregoreSignature (per settlement-region + optional trans-settlement group)**
- `id`
- `anchor_region`
- `cohesion` (0..1)
- `pressure_vector`:
  - `cooperation`
  - `discipline`
  - `care`
  - `fear`
  - `vengeance`
  - `curiosity`
  - `asceticism`
  - `opulence`
- `ritual_density`
- `taboo_density`
- `law_density`
- `memory_weight`
- `last_update_tick`

2. **EgregoreInput Ledger (derived from WorldMemory events)**
- repeated teaching events
- repeated betrayal/harm events
- repeated famine/survival stress
- repeated hospitality/protection actions
- repeated lawful coordination events
- repeated shrine/ritual participation events

3. **Matrix Coupling**
- Matrix score for each pawn/settlement reads egregore vector as weighted bias.
- Bias is bounded and never overrides core survival imperatives.
- Bias decays or intensifies based on recent evidence windows.

## Behavioral Targets

At scale, this should produce:
- cultures that feel distinct without scripted factions,
- institutions that emerge from pressure (not unlock trees),
- continuity across generations through teaching + taboo + memory,
- collapse/revival dynamics shaped by fear/trust cycles.

## Non-Goals

- No omniscient moral arbiter.
- No authored “chosen people.”
- No cinematic miracle overrides.
- No replacement of material simulation by symbolic lore text.

## First Implementation Slice (Safe)

1. Add `EgregoreMemory` deterministic autoload:
- consume deltas from `WorldMemory.get_events()`,
- accumulate bounded pressure vectors per settlement region,
- expose read-only snapshots.

2. Wire `WorldAI` and/or pawn decision layer to read egregore bias:
- one bounded bias path first (cooperation vs fear),
- no direct control injection.

3. Log outcomes:
- record when egregore pressure changed a selected action class,
- keep it auditable and replay-verifiable.

## Verification Requirements

Before any "active" claim:
- pass `bash tools/ai/sim-quality-gate.sh`,
- run side-by-side seed replay checks with and without egregore enabled,
- confirm no divergence beyond intentional bias formulas,
- verify `1x` and `100x` smoothness on Godot-enabled runtime host.

