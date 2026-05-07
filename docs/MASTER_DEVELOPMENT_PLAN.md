# HEELKAWN: MASTER DEVELOPMENT PLAN
## Persistent Simulation Universe Blueprint

**Status:** Canonical Vision / Not Runtime Truth
**Last Updated:** May 7, 2026
**Runtime Authority:** Godot boot status, source code, and `docs/BUILD_INVENTORY.md`

This plan describes what HeelKawn is becoming. It must not be read as proof that every system is stable, complete, or fully implemented in the current runtime.

Read this with:

1. `docs/HEELKAWN_PROJECT_COMPASS.md`
2. `docs/HEELKAWN_BLUEPRINT.md`
3. `docs/HEELKAWN_STATE.md`
4. `docs/BUILD_INVENTORY.md`

---

## Core Philosophy

> Every sprite matters. Every human matters. Every choice echoes through generations.

HeelKawn is a Persistent Simulation Universe: a living world simulation combining ECO-style sovereignty, Kenshi/Bannerlord-style combat depth, Crusader Kings-style lineage, RimWorld-style pawn readability, Songs of Syx-style city management, WorldBox-style autonomy, EVE/Stronghold-style longevity, Arma-style individual meaning, and Pax Historia-style AI ambition.

The world is not meant to be won. It is meant to endure, remember, collapse, rebuild, and argue with itself across generations.

---

## Three Pillars

| Pillar | Meaning | Design Test |
|--------|---------|-------------|
| Sovereignty | Every player chooses their path. | Can a player live alone or cooperate without being forced? |
| Autonomy | The world lives without you. | Do HeelKawnians continue acting from needs, place, memory, and knowledge? |
| Legacy | Every action is remembered. | Does meaningful impact enter the ledger and affect later life? |

---

## Non-Negotiable Laws

- Deterministic history: same tick-stable inputs produce the same outcomes.
- Facts first: `WorldMemory` records objective events before interpretation.
- Meaning is derived: `WorldMeaning` can summarize but cannot rewrite the ledger.
- Persistence is earned: ruins, bloodlines, customs, scars, tools, roads, and names survive through cause and effect.
- No chosen ones: players and NPCs begin ordinary.
- No morality meter: conflict comes from pressure, loyalty, need, accident, ideology, and memory.
- No UI lies: interface copy must reflect simulation truth.
- No random memory decay: history is lost only through deterministic destruction, forgetting systems, or broken continuity.
- No victory finality: legacy milestones replace win states.
- LLM text is presentation only unless converted into deterministic world data through approved systems.

---

## Status Labels

Use only these labels in planning and status docs:

| Label | Meaning |
|-------|---------|
| Verified Runtime Complete | Tested in Godot, boots cleanly, and has a user-facing or diagnostic verification path. |
| Implemented but Needs Runtime Verification | Code exists, but current runtime behavior is not fully verified. |
| Partial / Prototype | Some code or UI exists, but core behavior is incomplete or stubbed. |
| Vision / TODO | Canonical direction only; not built yet. |

Do not use "complete" by itself.

---

## Current Runtime Rule

Runtime stability comes before expansion.

The previously visible onboarding blocker:

```text
Invalid assignment of property or key 'bbcode_enabled' with value of type 'bool' on a base object of type 'Label'.
```

has been corrected in `autoloads/OnboardingSystem.gd` by using an attached `RichTextLabel` for BBCode copy. A Godot headless smoke passed on May 7, 2026. Full editor/playtest verification is still required before broad release claims.

---

## Corrected Build Order

1. Fix current red Godot runtime errors.
2. Verify the game boots clean.
3. Confirm which systems actually run without crashing.
4. Build AI Autonomy, starting with a minimal deterministic Auto-Build Seed.
5. Build Combat Overhaul.
6. Build Group/Guild institutions.
7. Polish Lineage/Genetics.
8. Build Governor tools.
9. Modernize UI.
10. Prepare scale tests, cataclysms, and launch gates.

The timeline is aspirational. The running world decides readiness.

---

## Phase 1A: Auto-Build Seed

After runtime is clean, the safest first expansion is a small deterministic autonomy loop.

When pawns spawn or settle:

- Scan nearby resources.
- If no shelter exists, create a shelter intent.
- If food is unsafe, create a food intent.
- If storage is missing, create a storage intent.
- Let builders choose jobs from deterministic priority.
- Record historically meaningful construction in `WorldMemory`.

Priority order:

1. Survival
2. Shelter
3. Storage
4. Hearth
5. Tools
6. Defense
7. Comfort
8. Identity
9. Ambition

Autonomy must obey place, resource availability, skill, knowledge, climate, danger, and social trust.

---

## Combat Direction

Combat is not a loot treadmill. It is human escalation under pressure.

Target systems:

- Dynamic text-based combat logs.
- Wounds, recovery, fear, fatigue, and morale.
- Soldier -> veteran -> captain -> commander -> general progression.
- Battle reports saved to `WorldMemory`.
- Witnessed heroism and cowardice as historical memory, not morality judgment.
- War memory affecting settlements, families, grudges, songs, stories, and governance.

---

## Group And Guild Direction

Groups are social institutions, not MMO aura buffs.

Target systems:

- Groups form around work, danger, kinship, trade, teaching, exploration, and defense.
- Groups carry memory, trust, reputation, leadership, debts, and betrayals.
- Leaders can fail.
- Groups can fracture under hunger, distance, death, betrayal, and fear.
- Bonuses emerge from coordination, skill, tools, location, and shared history.

---

## Lineage Direction

Lineage exists to create continuity, grief, inheritance, and responsibility.

Target systems:

- Parents, children, bloodlines, marriages, adoptions, lost heirs, and forgotten branches.
- Trait inheritance that creates individuality, not superiority.
- Family reputation, feuds, alliances, and obligations.
- Knowledge and skills preserved through teaching.
- Bloodlines survive only when protected by people and institutions.

---

## Governance Direction

Governance is labor under scale, not a menu title.

Target systems:

- Governors can be players or NPCs.
- Worker assignment, storage policy, food planning, defense posture, roads, and city identity.
- Settlement decisions derive from survival pressure, local resources, population mood, culture, memory, and threat.
- Authority is provisional and can lose legitimacy.

---

## Legacy Conditions / Historical Milestones

HeelKawn has no victory screen and no final completion.

Legacy milestones include:

- Survived a famine.
- Preserved a bloodline.
- Rebuilt after collapse.
- Founded a lasting settlement.
- Taught knowledge that survived generations.
- Created a road, ruin, custom, tool, song, or memory that survived after death.

Legacy is the reward.

---

## AI And LLM Rules

AI adapts through recorded world events and deterministic weight changes. All adaptation must be based on `WorldMemory` facts, tick-stable inputs, and replayable cause/effect.

No hidden non-auditable AI behavior belongs in the canonical simulation.

LLMs may generate summaries, reports, flavor, interpretation, and readable text. They must not override the simulation, rewrite history, or become world truth. The simulation ledger is always higher authority than generated prose.

---

## What Future AIs Must Remember

HeelKawn should feel heavy, quiet, slow, vast, human, historically layered, incomplete on purpose, tragic without being nihilistic, and meaningful without spectacle.

Before adding anything, ask:

1. Does this respect causality?
2. Does this add inertia, not convenience?
3. Does this privilege place over pawn fantasy?
4. Does this let the world say no?
5. Could a player tell a story about this without UI text?

If the answer is no, do not build it yet.
