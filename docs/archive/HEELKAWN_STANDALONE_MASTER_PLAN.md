# HeelKawn Standalone Master Plan

This document is the in-repo, AI-readable order for the standalone HeelKawn product: what the game is, what the player fantasy is, which systems are required first, and which systems are deferred.

Use this as the canonical implementation order for the offline single-player build.

## 1. Product

HeelKawn is a single-player offline myth-simulation where the world lives without the player, and the player can enter it only by incarnation.

The game has two states:

Spectator state
You are outside the world, watching time pass, settlements rise and fail, bloodlines continue, wars form, knowledge spread, and ruins accumulate.

Incarnation state
You enter the world as one mortal human inside the same simulation and live under its rules until death.

This fits the locked canon: the world exists before the player, the player is ordinary, significance must be earned, and the interface must never override world truth.

## 2. Fantasy

The fantasy is not become the hero.

The fantasy is:

Watch a real world.
Enter it.
Live inside history instead of above it.
Leave traces that may or may not survive.
Return later and see whether anything you did still matters.

## 3. Core pillars

Deterministic World Kernel
One auditable simulation where cause leads to effect and the same conditions produce the same outcomes. Keep core systems event-driven and deterministic, use append-only history logs, avoid random memory decay, and keep replayable saves.

Always-Living World
The world continues whether or not the player is incarnated. Simulation ticks never depend on player control; spectator mode and incarnation mode both attach to the same world clock.

Spectator-to-Incarnation Loop
Build a world observer camera, world timeline controls, region inspection, then an incarnation entry flow that selects a newborn, child, adult, refugee, traveler, or settlement member.

Ordinary Human Start
No chosen one, no prophecy, no class fantasy. All incarnations begin with human weakness, local context, limited knowledge, and embodied constraints.

Memory Over Victory
The world’s meaning comes from what survives, not what flashes on screen. Important systems must produce traces: graves, teachings, buildings, customs, descendants, scars, reputations, renamed places, lost techniques, surviving stories.

## 4. Main loop

Spectator loop
Observe regions -> inspect settlements -> watch tensions rise -> inspect bloodlines, professions, shortages, knowledge, and conflicts -> choose a place and moment to incarnate.

Incarnation loop
Spawn as mortal -> survive body needs -> learn tools and roles -> enter family, labor, trade, teaching, warfare, ritual, or governance -> create consequences -> die -> return to spectator mode and inspect aftermath.

Legacy loop
After death, inspect what survived: children, ruins, apprentices, customs, renamed places, scars, myths, bloodlines, or nothing at all.

## 5. Essential feature list

### A. World simulation

Procedural World Generation
Generate terrain, water, climate bands, soil quality, vegetation, wildlife zones, hazard regions, and travel routes.

Region Identity
Each region needs a center identity, resource pressure, risk profile, climate character, and cultural memory anchor.

Time and Seasons
Day-night cycle, seasons, migration windows, planting windows, cold exposure, food spoilage, river behavior, disease pressure, and travel difficulty by season.

Ecology
Animals breed, migrate, are hunted out, return, or vanish. Forests recover slowly or are stripped. Water access shapes settlement survival.

Settlement Lifecycle
Settlements can form, stabilize, strain, decline, become abandoned, recover, revive, or become permanently dead.

Deterministic Revival and Collapse
Revival must emerge from resource access, survivors, governance, memory, location, and labor.

Resource Pressure Model
Wood, stone, ore proxy, food access, labor burden, storage resilience, and environmental carrying pressure shape identity and specialization.

### B. NPC civilization

Autonomous NPCs
NPCs need needs, routines, skills, memory hooks, social bonds, fears, and local knowledge.

Human Roles
Use roles such as child, elder, parent, laborer, hunter, fisher, builder, smith, trader, healer, guard, teacher, messenger, leader, record-keeper, mourner, exile, raider, refugee.

Apprenticeship
Skills pass person-to-person, not from menu unlocks.

Kinship and Household
Households store food, labor, obligation, inheritance, and grief.

Bloodlines and Descendants
Birth, kin ties, old age, inheritance, family shame, family pride, protected names, forgotten names.

Reputation by Witness
Reputation is local unless carried by trade, memory-keepers, or institutions.

Cultural Drift
Customs, taboos, naming patterns, burial practices, hospitality rules, teaching norms, and leadership expectations should change over generations.

### C. Spectator features

Living World Map
The player can zoom out and watch polities, roads, weather, migration, war fronts, and dead zones.

Historical Playback
Scrub backward through major events using deterministic logs and world snapshots.

Region Inspection
Click a region and see settlement history, deaths, shortages, lineages, cultural traits, collapse causes, and surviving landmarks.

Entity Watchlist
Track a person, family, settlement, river valley, guild, army, or bloodline over time.

Quiet Observation Mode
Let players watch the world with minimal UI and ambient signals only.

Chronicle View
Auto-generate historical summaries from the fact log.

### D. Incarnation features

Incarnation Entry
Choose region, era, life context, or lineage when available. Some entries are privileged by survival conditions, not by power fantasy.

Embodied Control
Movement, stamina, cold, hunger, load, injury, visibility, fear, sleep, pain, and clumsiness.

No Tutorial, Only Learning
Teach through world reaction, failure, and imitation.

Local Knowledge Fog
An incarnated player only knows what that human could know. Spectator knowledge cannot leak directly into mortal knowledge.

Occupation Through Doing
You become a fisher by fishing, a teacher by teaching, a mourner by burying, a guard by guarding, a healer by treating, not by selecting a class.

Mortality
Death ends that life. Spectator mode resumes.

### E. Knowledge and memory

WorldMemory Expansion
Expand the append-only fact log beyond death to buildings, fires, starvation, migrations, first occurrences, notable teachings, abandonment, revival, and war outcomes.

WorldMeaning Layer
Compute tags from facts instead of scripting them.

Human Memory Layer
NPCs remember fragments, misremember, exaggerate, omit, and inherit oral narratives.

Record Carriers
Songs, grave markers, carved stones, ledgers, shrine tablets, trade maps, household objects, road markers, schoolhouses, and archives.

Forgotten Knowledge
A technique can vanish if no living carrier or durable record remains.

Myth Formation
After enough time, facts become legends.

### F. Settlement and politics

Governance Forms
Loose elder circle, militia protectors, chief households, council rule, hereditary lords, war captains, temple archives, trader coalitions.

Intent System
Current settlement intents should become readable settlement personalities and policy pressures.

Legitimacy
Authority survives only while it feeds, protects, judges, or remembers well.

Law and Custom
No universal law menu. Each culture accumulates taboos, obligations, punishments, marriage rules, burial rules, and hospitality rules.

Diplomacy
Messengers, hostage exchange, marriage ties, seasonal truce, trade guarantees, feud settlement, oath stones.

War as Human Chaos
War is organized before battle and chaotic during it.

### G. Survival and craft

Sacred Early Order
Hand, stone or stick, fire, knife should define the earliest learning path and remain symbolically important across the whole game.

Shelter and Hearth
Shelter, storage, hearth, and markers should be the foundational civilization loop.

Food Chains
Foraging, fishing, trapping, farming, storage, spoilage, cooking, animal keeping, seed preservation, famine management.

Fire Discipline
Warmth, cooking, signaling, risk of accidental spread, winter survival, night gathering, ritual uses.

Tool Families
Stone tools, bone tools, wooden implements, metal transition, repair, specialization, and scarcity by skill not just by nodes.

Body Risk
Cuts, burns, infection, broken limbs, childbirth danger, exhaustion, exposure, and recovery time.

### H. Content and meat

Ruins
Collapsed settlements, old graves, abandoned roads, forgotten terraces, broken shrines, burned halls, dead mine shafts, weathered schoolhouses.

Historical Sites
The first bridge in a region, the massacre field, the famine granary, the teacher’s mound, the oath spring, the unmarked burial plain.

Discoverable Human Stories
Generated situations instead of authored quests.

Institutions
Schools, shrine-houses, council fires, militia barracks, trade lodges, archive rooms, orphan shelters, healer huts, communal granaries.

Taboos
Child-killing, ruin-breaking, oath-breaking, knowledge hoarding, hospitality betrayal, grave disturbance.

Generational Change
The same town should feel different fifty years later even if the buildings still stand.

Silence as Outcome
Sometimes nothing survives.

### I. Metaphysical features

Asha and Druj as Currents
Not player-facing morality bars. They should be inferred from consequence, place, ritual, and endurance.

Asha Gift
One subtle boon per living soul at most, rare, non-stackable, near-death threshold correction only.

World-Bound Grace
Excess aligned acts can become calm harbors, herbs, shrines, hills, still groves, or soft luck in a place.

Echoes of the Dead
Dreams, unease, silence, place-memory, ritual resonance, but never cheap ghost helpers.

Veil-Aware Sites
Some places feel thin or burdened, but the player never gets a clean objective overlay saying why.

### J. Export and future-online bridge

Exportable World Seeds
Let players export a world seed plus historical summary.

Exportable Chronicle
Export a timeline, notable families, major wars, dead settlements, persistent landmarks, and dominant cultural traits.

Exportable Bloodline Cards
A family, teacher-line, house, or survivor lineage can be exported as a compact record for future online canon integration.

Exportable Artifact Records
Named tools, books, shrines, roads, ruins, and famous places can become portable universe artifacts.

Canon Submission Layer
Players can nominate outcomes from their standalone worlds for future official online-era adoption.

## 6. What makes it feel alive

The world feels alive when these are true:

People are born without the player.
Settlements fail without the player.
Wars happen without the player.
Skills disappear without the player.
Roads form from repeated use.
Children inherit things no one planned.
Graves accumulate.
Ruins remain.
Names drift.
The player can return to a place decades later and feel history.

## 7. Must-have v1 systems

Deterministic world tick
Spectator mode
Incarnation mode
Human bodily needs
Settlement simulation
NPC households
Professions by doing
WorldMemory expanded beyond death
WorldMeaning prototype
Historical ruins
Birth and death
Basic kinship
Food and storage
Fire and shelter
Trade and travel
Conflict and raids
Local reputation
Region history panel
Chronicle export
World seed export

## 8. What can wait until v2 or later

Formal religion depth
Advanced naval systems
Deep metallurgy trees
Large-scale city politics
Sophisticated mounted warfare
Late-age augmentation and techno-spiritual branches
Taured / Ark branch as a fully playable later-age campaign
Full generational reincarnation systems
Massive cross-world canon sync

## 9. Production order

Stage 1: lock the kernel
Arm validation flags and do the first clean rerun. Confirm settlement memory, collapse/revival scoring, and continuity via center_region.

Stage 2: make spectator mode real
Build world map observer, timeline controls, settlement inspection, event feed, and watchlists.

Stage 3: make incarnation real
Enter one human in one living settlement. Add body needs, work roles, local knowledge fog, injury, survival, and social interaction.

Stage 4: expand memory
Upgrade WorldMemory facts and build WorldMeaning tags so the world can talk about itself through derived history.

Stage 5: add historical persistence
Ruins, settlement states, named landmarks, family memory, road traces, cultural drift.

Stage 6: add content density
More roles, more institutions, more rituals, more site types, more generated situations, more long-term variance.

Stage 7: add export loop
World seed, chronicle, bloodline, artifact, and historical snapshot export.

## 10. Hard rule

Every feature must answer all four questions:

What physical effect does it have?
What social effect does it have?
What memory trace does it leave?
What survives after the people involved are gone?

If a system cannot answer those, it probably does not belong in HeelKawn.

## 11. Short pitch

HeelKawn is a single-player living world simulator where you first witness history as an outsider, then incarnate into it as a mortal human, and when you die the world keeps going to reveal whether anything you did actually lasted.