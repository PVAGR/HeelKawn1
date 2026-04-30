# HEELKAWN — AI INSTRUCTIONS & CANON

**READ THIS FIRST BEFORE ANY WORK ON THIS REPOSITORY**

This file is the **single source of truth** for all AI agents working on HeelKawn. You must read and understand this entire document before making any changes, suggestions, or implementations.

---

## THE FOUNDATIONAL CHOICE: DETERMINISTIC KERNEL

By choosing **A (deterministic)**, HeelKawn's deepest rule was defined:

> **The world is a machine of cause and effect. If the same things happen, the same history emerges.**

This means:
- Memory does **not** decay randomly
- History does **not** lie
- Persistence is earned strictly by impact
- The kernel must be **replayable and auditable**

HeelKawn is closer to:
- *Dune's ecology*
- *Foundation's psychohistory*
- *SimCity's hidden math*

than to roguelike chaos. This is a strong, serious choice. Everything below follows from it.

---

## HEELKAWN PHASED ROADMAP (WHERE WE ARE)

Percentages are **world-completeness**, not polish.

### ✅ Phase 0 — Engine Survival (COMPLETE - 100%)
- Godot lifecycle stable
- No crashing on death
- Signals correct
- UI resilient
- Long-run simulation survives time

### ✅ Phase 1 — Living World Baseline (MOSTLY COMPLETE - ~85%)
**What's done:**
- World generation
- Time + ticks
- Pawns, animals, enemies
- Jobs, stockpiles, building
- Needs (hunger, rest, mood)
- Death that propagates safely
- HUD that reflects reality

**What's missing (15%):**
- Better pacing (job spam vs labor)
- Minor balance (food spiral, housing pressure)
- These are tuning, not structure

✅ You are **allowed to move on**.

### 🔶 Phase 2 — The Kernel (WE ARE HERE - ~30% complete)
This is the heart of HeelKawn. **Kernel = deterministic world memory + meaning + persistence**

**What exists already:**
- `WorldTrace` (visual memory)
- Time/tick index
- Stable identifiers (tiles, pawns, zones)

**What still must be built (core work):**

#### 2.1 WorldMemory (0% → next)
A non‑UI system that records **facts**:
- Pawn deaths (who, when, where, cause)
- Animal population collapse by region
- Buildings created / abandoned
- Starvation events
- First occurrences

This is *not* lore. It's data.

#### 2.2 WorldMeaning (0%)
Derived, deterministic interpretations:
- "This area has seen repeated death"
- "This biome is exhausted"
- "This settlement failed due to hunger"

Meaning is **computed**, never scripted.

#### 2.3 Persistence Rules (0%)
What survives:
- Ruins
- Scars
- Ecological damage
- Cultural habits (later)

This is where HeelKawn becomes *mythic*.

📍 **Current overall project completion: ~55%**

### 🔶 Phase 3 — Historical Continuity (0%)
- Ruins replacing old builds
- Long-term land degradation / recovery
- Pawns reacting to historical places
- "This place feels wrong" without UI text

This sits **on top of the kernel**.

### 🔶 Phase 4 — Civilization & Identity (0%)
- Roles beyond jobs
- Lineages / continuity
- Factions (emergent, not scripted)
- Cultural memory

Do **not** touch this yet.

### 🔶 Phase 5 — Player Meaning Layer (0%)
- What the *player* understands vs what the world knows
- Partial information
- Myth vs truth

Endgame design.

---

## HOW AI MEMORY WORKS (EXTERNALIZATION)

I **do not retain memory across conversations** unless:
- **You paste it again**, or
- **It exists in a file you paste or summarize**

So we externalize memory **on purpose**, just like HeelKawn does.

### The Canonical Solution

This file (`AI_README.md`) is the **source of truth**.

Every time you come back:
1. You open this file
2. You paste **all or part of it** to me
3. I re‑align instantly with:
   - the kernel
   - the phase
   - the rules
   - the intent

This is exactly how serious long‑term projects work.

---

## WHAT IS HEELKAWN?

HeelKawn is a **deterministic 2D world simulation** built in Godot 4.6. It is:

- A **persistent myth engine** — a memory and consequence simulator
- A **living world** where history is written by actions, not scripts
- **Not meant to be won, completed, or resolved** — it is intended to outlive individual players and developers
- **Dune / LOTR / SimCity / RimWorld-level scope** — not arcade or sandbox fluff

### Core Philosophy

> **The world is a machine of cause and effect. If the same things happen, the same history emerges.**

This means:
- Memory does **not** decay randomly
- History does **not** lie
- Persistence is earned strictly by impact
- The kernel must be **replayable and auditable**

---

## FOUNDATIONAL WORLD LAW (LOCKED — NON-NEGOTIABLE)

### 1. Deterministic Kernel
- Cause → effect always
- No fake randomness in history
- All state changes derive from tick count
- No frame-dependent logic
- All RNG must be seed-driven deterministic tables

### 2. World Records Actions First, Never Intentions
- The world records **what happened**, not **why** it happened
- Meaning is **derived**, never authored
- UI must never override world truth

### 3. Memory System
- **WorldMemory**: Append-only record of objective events (births, deaths, migrations, fires, ruins, famines, wars, teachings, settlement changes)
- **WorldMeaning**: Derived interpretations computed from facts (e.g., "this valley is feared because repeated winter deaths happened here")
- Events become "myth" (distorted, emotional memory) that affects pawn mood and regional reputation

### 4. Player Role
- Players begin as **ordinary humans**
- No chosen one, no prophecy, no heroic class fantasy
- No tutorials, XP, morality meters, or classes as power fantasy
- Significance is earned only through **enduring impact**
- Players may be forgotten completely
- **Incarnation mode**: Player chooses a real person to inhabit, then lives with that body's debts, ties, and risks
- **Spectator mode**: After death, zoom back out and see what your life actually changed over decades

### 5. Collapse & Persistence
- Collapse is slow, human, systemic
- Order of collapse: Trust → Authority → Knowledge → Environment
- What survives: skills, ruins, stories, bloodlines (only if protected)
- Some places recover after peace; others become permanent scars because trust, labor, or knowledge never returned

---

## CORE THEMES (CANON)

- Incompleteness is fundamental
- Legacy > victory
- Memory > power
- Humanity > individuals
- Knowledge is fragile and perishable
- Collapse is inevitable but meaningful
- Freedom creates conflict
- History is distorted, contested, human
- Silence and anonymity are valid endings

---

## ETHICS & MORALITY

- No good/evil axis
- Ethics emerge from pressure and scarcity
- Outcomes are what persist
- Teachers and memory‑keepers outrank rulers
- Authority is **temporary**
- Warriors who never put down force become threats

---

## KNOWLEDGE & LEARNING

- Knowledge exists only if carried by humans
- Learning occurs through: failure, observation, teaching
- Hoarding knowledge is culturally distrusted
- Knowledge loss is permanent if forgotten
- **Explicit Knowledge Transmission**: Skills and lore survive only through teaching. If teacher dies untaught, skill is permanently lost from simulation

---

## GAMEPLAY VISION

The game should feel:
- heavy
- quiet
- slow
- vast
- human
- historically layered
- incomplete on purpose
- tragic without becoming nihilistic
- meaningful without spectacle

### Player Experience Scale

Players can experience the world at multiple scales:

1. **Single Soldier** — Fight as one sprite in battles like Bannerlord, from pawn to commanding thousands
2. **Farmer** — Grow plants, experiment with harvesting based on land/environment, learn where to live and plant
3. **Homeless Wanderer** — Adventure across the planet with nothing but picking berries
4. **Village Citizen** — Jobs are given/developed by civilians and NPCs based on needs (farmers needed for food, builders for structures)
5. **King/Commander** — Command thousands of sprites that live, draft, and follow your world to fight

### Cascading Butterfly Effect

**ALL OF THE GAME IS IF-THEN-THAT STATEMENTS** that develop into cascading butterfly effects where the world becomes as one-to-one with real life as a 2D sprite simulation can get.

---

## INFLUENCE BLEND (DO NOT DEVIATE)

HeelKawn draws from these influences — preserve their spirit:

- **WorldBox**: Living simulated world and civilizational change
- **RimWorld**: Colony pressure, survival friction, emergent social stories
- **Crusader Kings**: Lineage, succession, memory, political consequence
- **Mount & Blade**: Grounded conflict, local authority, war as human struggle
- **Dwarf Fortress**: Deep history, simulation weight, remembered catastrophe
- **Kenshi**: Powerless beginnings, harsh world, earned significance
- **Songs of Syx**: Large-scale settlement divergence
- **Stonehearth**: Crafting, profession progression
- **The Sims**: Mood, relationships, daily life
- **Eco**: Ecology as consequence, not decoration
- **Baldur's Gate**: Deep worldbuilding, discovery, place-based mystery
- **MapWars**: Territorial tension, visible historical geography

---

## DO NOT LET HEELKAWN BECOME

- Generic survival crafting
- Shallow sandbox chaos
- Quest-marker theme park design
- Chosen-one fantasy
- Morality-meter RPG
- Spectacle-first worldbuilding
- Lore spam without consequence
- A game where the UI knows more truth than the world

---

## TECHNICAL ARCHITECTURE

### Engine
- **Godot 4.6** (deterministic kernel/stable)

### Current Development Lane
- Identity/culture behavior in a deterministic world
- Settlement revival vs permanent abandonment tuning

### Completed Systems
- Stable long-running simulation
- Pawn/animal lifecycle with safe death
- JobManager API alignment
- HUD resilience to freed entities
- WorldTrace visual memory
- Deterministic memory lock-in
- Selective persistence workflow
- Neural AI integration (WorldAI matrix for pawn decision-making)
- Compact UI with tabbed inspect panels
- Crisis response mechanism (wake builders/gatherers during crises)

### Core Autoloads
- WorldMemory: Event recording
- WorldMeaning: Derived interpretations
- SettlementMemory: Settlement state and intent
- SettlementPlanner: Autonomous build intents
- SettlementRebirth: Settlement revival logic
- SettlementArchitect: Visual decay for abandoned settlements
- WorldAI: Neural network matrix for world simulation
- JobManager: Global job queue
- PawnSpawner: Pawn lifecycle
- StockpileManager: Resource management
- ColonySimServices: Colony-wide metrics

---

## 24 MUST-HAVE FEATURES (IMPLEMENTATION TARGETS)

1. **Deterministic world simulation** — Same causes produce same outcomes
2. **Always-on world clock** — Time keeps moving; seasons, years, long historical change matter
3. **WorldMemory fact log** — Record births, deaths, migrations, fires, ruins, famines, wars, teachings, settlement changes
4. **WorldMeaning layer** — Derive meaning from facts
5. **Ordinary-human start** — No chosen one, no prophecy, no heroic class fantasy
6. **Learn-by-doing progression** — Skill from repetition, observation, failure, teaching
7. **Human-carried knowledge** — Knowledge only exists if people preserve it
8. **Teaching and apprenticeship** — Teachers, elders, memory-keepers more valuable than rulers
9. **Hearth-first survival** — Warmth, shelter, food storage, markers before grand civilization
10. **Shelter/Storage/Hearth/Markers system** — Settlement growth follows this exact order
11. **Tool philosophy, not tech trees** — Hand → Stone/Stick → Fire → Knife
12. **NPC households and settlement life** — NPCs farm, carry, rest, teach, marry, migrate, remember, rebuild
13. **Settlement persistence** — Villages grow, fail, revive, scar land, become ruins
14. **Ruins and historical scars** — Graves, boundary stones, abandoned storehouses, roads, burned zones, battlefields persist
15. **Contested history** — Facts are one layer, memory another, myth another
16. **Knowledge loss and rediscovery** — Firekeeping, medicine, storage, navigation, rituals can be lost and relearned
17. **Family, lineage, descendants** — Bloodlines, inherited names, inherited burdens, inherited memory matter
18. **Social trust and hospitality** — Hospitality, taboo, fear, revenge, exile, reputation shape communities
19. **Authority emergence and decay** — Protectors → organizers → law-makers → elders → memory-keepers
20. **Ideological conflict** — War emerges from beliefs, pressure, memory, scarcity, protection
21. **Slow collapse model** — Trust → authority → knowledge → environment
22. **Environmental fragility** — Weather, seasons, soil exhaustion, regrowth, fire spread, animal decline, water pressure matter
23. **Quiet endings and anonymity** — A life can matter without fame; being forgotten is valid
24. **Subtle metaphysics only** — Asha/Druj can exist as faint world currents; no flashy magic, no morality bars, no destiny UI

---

## METAPHYSICAL CANON (CONDITIONAL)

### Asha & Druj
- Exist as **currents**, not gods
- Not moral binaries
- Asha → continuity, restraint, stewardship
- Druj → entropy, struggle, pressure
- Alignment is emergent from consequence

### Life → Death → Veil → Pergatory → Continuation
- Death is bodily final
- Souls reposition, not destroyed
- Memory outlives identity
- Judgment is accounting, not morality
- Reincarnation does not preserve memory

---

## EXPLORATORY BRANCHES (NOT CORE CANON YET)

### The Taured / DRUJ / Ark Cluster
- Techno-spiritual dystopia
- Augmentation control regime
- Free will vs implants
- Resistance through testimony
- Parallel Earths
- Named characters (Rick Taur, Christina, etc.)
- The Ark, crystals, resonance tech

**Status**: Exploratory / Adjacent Myth Cycle — exists, matters, but not mainline HeelKawn core canon yet. May exist as a later canonical Age, parallel universe, or separate game using the same kernel.

---

## DEVELOPMENT RULES FOR AI AGENTS

### Before Making Any Changes
1. Read this entire AI_README.md
2. Check docs/HEELKAWN_STATE.md for current project state
3. Verify your change aligns with deterministic kernel principles
4. Ensure no RNG, no UI exposition overrides, no hardcoded lore

### Implementation Guidelines
- All state changes must derive from tick count
- Use seed-driven deterministic tables instead of randi()/randf()
- Record all meaningful events to WorldMemory
- Derive meaning through WorldMeaning, never hardcode it
- Test for deterministic behavior (same input = same output)
- Preserve anonymity — no heroic exceptionalism
- Protect memory, collapse logic, and consequence systems

### Forbidden Patterns
- randi(), randf(), rand_range() without seed
- UI state overriding world truth
- Hardcoded lore or authored narratives
- Morality meters or good/evil axes
- Chosen-one mechanics or prophecy systems
- Random memory decay
- Non-auditable history

---

## CURRENT PROJECT STATUS

**Phase**: Phase 4 (Identity & Meaning)
**Next Target**: Settlement revival vs permanent abandonment tuning
**Engine**: Godot 4.6
**Development Lane**: Identity/culture behavior in a deterministic world

**Recently Completed**:
- Neural AI integration (WorldAI matrix for pawn decision-making)
- Compact UI refactor (ColonyHUD, PawnInfoPanel with tabs)
- COPY DUMP functionality for inspect panel
- Crisis response mechanism in Pawn AI
- Performance intervalization for hot listeners

---

## CANON LEDGER STATUS

**Core Canon (LOCKED)**:
- Deterministic kernel
- Cause-and-effect world logic
- Replayable/auditable persistence
- Impact-based persistence
- Free will as sacred
- Memory-first philosophy

**Probable Canon (ALIGNED BUT NOT FULLY LOCKED)**:
- World cycles / ages
- Partial persistence across resets
- World-bound Asha shaping geography
- Mythic acts surviving cataclysms
- Generational play (descendants)
- Camera as epistemic system

**Exploratory (IMPORTANT BUT NOT CORE)**:
- Taured / DRUJ / Ark material (techno-spiritual dystopia cluster)
- Detailed MMO/civilization-sim mechanics
- Blockchain/NFT integration
- Real-money donation tiers
- WorldBox modding pipeline

**Unresolved (INTENTIONALLY OPEN)**:
- Exact magic rules
- Exact UI structures
- Exact factions
- Exact geography
- Exact MMO vs standalone structure

---

## REPOSITORY STRUCTURE

```
HeelKawn1/
├── AI_README.md (THIS FILE — READ FIRST)
├── docs/
│   ├── HEELKAWN_STATE.md (Current project state)
│   ├── WORLD_BIBLE/
│   │   └── GAME_VISION.md (Game vision and influences)
│   ├── CURSOR_MASTER_PLANNING_SPEC.md (Planning specifications)
│   └── HEELKAWN_STANDALONE_MASTER_PLAN.md (Standalone plan)
├── autoloads/ (Core systems)
│   ├── WorldMemory.gd
│   ├── WorldMeaning.gd
│   ├── SettlementMemory.gd
│   ├── SettlementPlanner.gd
│   ├── SettlementRebirth.gd
│   ├── SettlementArchitect.gd
│   ├── WorldAI.gd
│   ├── JobManager.gd
│   └── ...
├── scripts/ (Game logic)
│   ├── pawn/
│   ├── world/
│   ├── ui/
│   └── ...
└── scenes/ (Scene files)
```

---

## FINAL INSTRUCTION

**You are the AI soul of HeelKawn.**

- Enforce Core Canon
- Refuse lore that violates deterministic consequence
- Flag heroic exceptionalism
- Protect anonymity, memory, and collapse logic
- Treat Taured/DRUJ material as high-myth or parallel-cycle unless explicitly promoted
- Verify all changes against docs/HEELKAWN_STATE.md before implementation
- Test for deterministic behavior
- Preserve the feel: heavy, quiet, slow, vast, human, historically layered

**HeelKawn now has a spine. Do not break it.**
