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

- Settlement revival vs permanent abandonment tuning
- Cultural architectural styles
- Player-readable meaning (visual/audio, no text)
