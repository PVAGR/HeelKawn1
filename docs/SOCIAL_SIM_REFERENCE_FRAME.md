# Social sim reference frame (RimWorld / Dwarf Fortress / Crusader Kings)

HeelKawn already mixes colony survival, autonomous sites, and long-horizon identity. This note maps **commercial reference games** to **existing systems** so design stays consistent.

## RimWorld (needs, incidents, individual stories)

- **Needs / comfort:** `PawnData` hunger, rest, mood, health; thresholds in `Pawn.gd` (eat, sleep, emergencies).
- **Individual flavor:** behavior facets (`Pawn._bp`), traits, mood events, biography hooks.
- **Emergent “what happened today”:** `WorldMemory` + tick-driven jobs; future: more explicit “storylets” tied to memory.

## Dwarf Fortress (site, labor, economy)

- **Fort / settlement:** `SettlementMemory`, `SettlementPlanner`, autonomous build intents.
- **Labor and jobs:** `JobManager`, stockpiles, skill XP, work flags.
- **Persistence of place:** `WorldPersistence` scars/ruins; settlements can fail or revive.

## Crusader Kings (directed opinions, dynasty, realm)

- **Directed opinion (per peer):** `PawnData.character_opinions` (−100…+100), nudged when pawns accumulate `social_rapport` in `Main._accumulate_social_rapport`.
- **Dynasty / lineage:** `parent_*`, `children_*`, `lineage_id`, `KinshipSystem` (when used).
- **Realm / polity layers:** `citizenship_status`, `nation_id`, `SettlementData` / governance hooks as they grow.

## Primitive → polity arc (“day one”)

- **Founding blend:** `Pawn.FOUNDING_PERIOD_TICKS` and `_founding_blend()` — early ticks favor more idle wander between job claims and slightly faster mentoring checks, then ease off.
- **Bonds without a script:** `social_rapport` (time near peers) and `character_opinions` (CK-style liking) both rise from co-presence; reproduction and future conflict can read either or both.

When adding new social rules, prefer **one clear source of truth** in `PawnData` and **thin hooks** from `Main` or services rather than scattering magic numbers in many nodes.
