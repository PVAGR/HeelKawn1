# HEELKAWN — AUTHORITATIVE PROJECT STATE

This file is the single source of truth for where the project is.

Anyone (human or AI) working on HeelKawn MUST read this file first.

## ENGINE

- Godot 4.6
- Project parses cleanly
- Known reload-time warnings exist (Godot 4.6 static/autoload noise)
- Runtime is stable

## KERNEL (COMPLETE)

- WorldMemory (deterministic, append-only, saved)
- WorldMeaning (derived regional interpretation)
- WorldPersistence (scars, ruins, abandonment)
- Land Recovery (visual healing, ruins permanent)
- CulturalMemory (inherited regional reputation)
- Pawn Behavioral Response (path/job/wander bias)
- SettlementMemory (clustered regions → places)
- SettlementPlanner (autonomous building)
- Animal Population Dynamics (deterministic ecology)

## CURRENT PHASE

**Phase 4 — Identity & Meaning**

Settlements:
- Build themselves
- Diverge culturally (open / cautious / defensive)
- Can be abandoned or revivable
- Revival tuning is active for moderately scarred, quiet regions
- Deterministic Phase 4 revival curve now emits: permanently_abandoned / abandoned / recovering / revivable / active
- Rebirth is peace-gated (tick-only) and blocked by scar>=3, recent conflict, or non-revivable state
- Player-readable settlement meaning now distinguishes quiet / scarred / bloodied / grave regions
- Expand walls, beds, doors, zones autonomously

Animals:
- Do not die instantly on spawn
- Reproduce, decline, recover deterministically
- Can go locally extinct

## PLAYER ROLE

Observer/chronicler.
No required micromanagement.

## KNOWN ENGINE NOTES

- Godot 4.6 may emit reload-time warnings for static autoload calls
- These do not indicate logic errors
- Do not refactor to silence them unless they break runtime

## CANON: TAURED / DRUJ / ARK (PROMOTION LADDER)

Creator decision — treat as locked intent until revised:

1. **Now:** **Exploratory myth-cycle only** — Taured / DRUJ / Ark material does not constrain Godot simulation design; no requirement to implement it here.
2. **Next:** May graduate to **parallel expression** (same deterministic kernel rules, separate game/universe lane or codebase).
3. **Later:** May graduate to **a canonical Age inside HeelKawn** once core game and parallel track justify integration.

Do not merge heroic/named-arc assumptions into kernel or WorldMemory semantics until step 3 is explicitly activated.

## DESIGN RULES (NON-NEGOTIABLE)

- No RNG in world history
- No per-tick O(N) recompute
- Derived systems never write to memory
- Autoloads do not use class_name
- History must be explainable after the fact

## NEXT TARGET

- Cultural architectural styles
- Player-readable meaning refinement (audio + settlement identity depth, no text overlay)
- Wildlife HUD trend validation + Phase 4 rebirth threshold tuning passes
