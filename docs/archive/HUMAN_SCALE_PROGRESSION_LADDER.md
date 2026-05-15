# HeelKawn Human-Scale Progression Ladder

This document defines the intended layered structure for the world: the sim begins with an individual pawn, then grows outward through trust, family, clan, settlement, nation, and world scope.

It is a design ladder, not a replacement for `docs/HEELKAWN_STATE.md`.

## Core principle

The world should feel like a real place inside a fantasy myth-world, but the sim should still run through the same deterministic kernel rules.

The important pattern is:

1. The pawn is the first active unit.
2. Relationships grow before institutions.
3. Institutions grow before states.
4. States grow before world-scale systems.
5. Higher layers are mostly background structure unless the player, NPCs, or world events need them.

## Ladder stages

### 1. Individual

Scope: pawn, player, sprite.

What matters:

- Survival
- Hunger, rest, mood, health
- Learning by doing
- Small direct actions
- Local perception of the world

What this stage unlocks:

- Basic movement
- Basic work
- Basic social contact
- Tiny visible progression

### 2. Family and trust

Scope: who you trust, who you build with, who you share space with.

What matters:

- Bonds
- Co-presence
- Rapport
- Parent / child / sibling lines
- Household-level stability

What this stage unlocks:

- Shared work routines
- Care and survival support
- Early specialization
- Small social groups forming naturally

### 3. Clan and household network

Scope: several families that unite around mutual safety and work.

What matters:

- Reputation across families
- Shared labor patterns
- Mutual defense
- Settlement identity emerging from the network
- Trust-based task delegation

What this stage unlocks:

- Multi-house coordination
- Broader job pools
- Stable production chains
- Leadership or anchor roles

### 4. Settlement / homestead

Scope: the place where most jobs happen.

What matters:

- Food production
- Gathering, hauling, building, defense
- Beds, walls, doors, stockpiles
- Trade, recovery, and cultural tone
- Local meaning and memory

What this stage unlocks:

- Settlement planning
- Labor specialization
- Better build priorities
- Local policy / intent
- Visible settlement identity

### 5. Region / local polity

Scope: multiple settlements and their shared economy.

What matters:

- Roads
- Regional safety
- Regional reputation
- Resource balance
- Shared customs

What this stage unlocks:

- Inter-settlement movement
- Regional crisis and recovery logic
- Larger-scale memory and meaning
- Trade routes and land pressure

### 6. Nation / country

Scope: a coherent political body formed from multiple regions.

What matters:

- Laws and legitimacy
- Culture at scale
- Military / defense posture
- Economic coordination
- Diplomatic identity

What this stage unlocks:

- Large policy structures
- Governance tiers
- Nation-level faction identity
- Broader conflict and alliance systems

### 7. World

Scope: the whole map, the whole history, the whole mythic frame.

What matters:

- Cross-region consequence
- Civilizational memory
- Climate, ecology, collapse, recovery
- Global belief and myth pressure
- Long arcs that survive individual pawns

What this stage unlocks:

- World-scale events
- Global history interpretation
- Mythic branches if canon promotes them
- Late-stage civilization systems

## Implementation rule

Each higher layer should be built on top of the lower layer, not instead of it.

That means:

- A clan still depends on individual pawn needs.
- A settlement still depends on family trust and labor.
- A nation still depends on settlement production and memory.
- The world still depends on local consequence.

## Progression rule

Pawns and NPCs should not instantly access everything.

They should:

- start with survival and simple work,
- unlock more work as they level up and build trust,
- gain broader responsibilities only after they prove capable,
- and keep older systems available in the background as the world grows.

## Design outcome

This makes the sim feel like a living world rather than a giant queue of disconnected tasks.

The player, pawns, NPCs, families, clans, and nations all participate in the same world truth, but at different scales.