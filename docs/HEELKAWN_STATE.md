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

Validation milestone (canonical runtime, 2026-04-26):
- Phase 7 validation proof is now confirmed in canonical repo runtime.
- Validation harness arming is proven ON in debug runs (`VALIDATION_SESSION_ENABLED` path).
- Clean-economy suppression proof is confirmed (`VALIDATION_EVENT_ROLL_PROOF` reports skipped roll; no dirty economy event lines observed in validation run).
- Settlement-truth verification is confirmed live (`[SETTLEMENT_VERIFY]` with hysteresis transitions and center_region continuity key).
- Specialization validation logs are confirmed live (`[SPECIALIZATION_VALIDATE]` on coarse resource-pressure cadence).
- Specialization identity remains explicitly proxy-derived from resource-pressure/job-demand, not stock scarcity truth.
- Kernel diagnostic at tick 30000 reports PASS (`append_only=PASS`, determinism PASS, settlements active=1, export_ready=true).

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
