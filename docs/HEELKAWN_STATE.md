# HEELKAWN — AUTHORITATIVE PROJECT STATE

This file is the single source of truth for where the project is.

Anyone (human or AI) working on HeelKawn MUST read this file first.

## ENGINE

- Godot 4.6
- Project parses cleanly
- Known reload-time warnings exist (Godot 4.6 static/autoload noise)
- Runtime is stable

## KERNEL (COMPLETE)

- WorldMemory (append-only factual history, saved)
- WorldMeaning (derived regional interpretation)
- WorldPersistence (scars, ruins, abandonment)
- Land Recovery (visual healing, ruins permanent)
- CulturalMemory (inherited regional reputation)
- Pawn Behavioral Response (path/job/wander bias)
- SettlementMemory (clustered regions → places)
- SettlementPlanner (autonomous building)
- Animal Population Dynamics (seeded / emergent ecology)

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
- Reproduce, decline, recover under simulation rules (emergent outcomes per world)
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
2. **Next:** May graduate to **parallel expression** (same kernel *constraints*, separate game/universe lane or codebase).
3. **Later:** May graduate to **a canonical Age inside HeelKawn** once core game and parallel track justify integration.

Do not merge heroic/named-arc assumptions into kernel or WorldMemory semantics until step 3 is explicitly activated.

## DESIGN RULES (LIVING WORLD — EMERGENCE FIRST)

- **Worlds diverge.** Different seeds and stochastic rolls produce **different** histories, maps, and societies — HeelKawn is not a single replayable rail.
- **Recorded truth.** `WorldMemory` and colony saves remain **append-only factual logs** of what happened (deaths, births, jobs, events). Rolls **produce** those facts; they do not silently erase or rewrite past entries.
- **Seeded streams.** Subsystems use **`WorldRNG`** (`world_seed` + named streams) so emergence stays tunable and debug sessions can pin a seed when needed — prefer named streams over raw global `randf()` for new work.
- **Derived interpretation.** Layers like `WorldMeaning` **compute labels** from facts; they may use RNG only for **non-canonical presentation** if explicitly documented — they never replace the underlying fact log.
- **Performance discipline.** Avoid full-world **per-tick O(N)** work; keep chunking, intervals, and tick budgets (`GameManager` caps, `Main` `_high_speed_interval` patterns).
- **Autoloads do not use `class_name`** (engine/project convention).
- **Explainability.** After the fact, one should still trace *why* something happened via facts + seed/stream policy — not hidden magic tables.

## NEXT TARGET

- Infinite architecture blueprint and implementation order: [docs/HEELKAWN_INFINITE_ARCHITECTURE.md](HEELKAWN_INFINITE_ARCHITECTURE.md)
- Human-scale progression ladder: [docs/HUMAN_SCALE_PROGRESSION_LADDER.md](HUMAN_SCALE_PROGRESSION_LADDER.md)
- Cultural architectural styles
- Player-readable meaning refinement (audio + settlement identity depth, no text overlay)
- Wildlife HUD trend validation + Phase 4 rebirth threshold tuning passes
- Grand-strategy map/UI bridge + NPC–player parity: see `docs/HEELKAWN_SIM_MATRIX.md` (CK3 routing, observation/command API order)
- Standalone spectator/incarnation build order and full feature plan: `docs/HEELKAWN_STANDALONE_MASTER_PLAN.md`
