# HEELKAWN — AI INSTRUCTIONS & CANON

**READ THIS FIRST BEFORE ANY WORK ON THIS REPOSITORY**

This file is the **single source of truth** for all AI agents working on HeelKawn. You must read and understand this entire document before making any changes, suggestions, or implementations.

---

**Last Updated**: May 22, 2026

## RUNTIME ENFORCEMENT (MANDATORY)

Simulation claims are invalid without verification evidence.

Before declaring simulation work complete, run:

```bash
bash tools/ai/sim-quality-gate.sh
```

Required companion docs:
- `AGENTS.md`
- `docs/AI_RUNTIME_MANDATE.md`
- `docs/HEELKAWN_STATE.md`
- `docs/STATE_VERIFICATION_YYYY-MM-DD.md`

If Godot is available, required smoke includes `1x` + `100x` performance smoothness with `consistency=ok`.

---

## AI AGENT CROSS-REFERENCE

**Read order for AI agents (handoff sequence):**

1. **AI_README.md** — THIS FILE. Core philosophy, kernel rules, forbidden patterns
2. **HEELKAWN.txt** — Quick-context orientation and latest state
3. **docs/HEELKAWN_STATE.md** — Authoritative current status, blockers, action plan
4. **docs/BUILD_INVENTORY.md** — Honest built-vs-missing inventory (build status authority)
5. **docs/HEELKAWN_PROJECT_COMPASS.md** — Orientation compass and north star
6. **docs/HEELKAWN_BLUEPRINT.md** — Full Persistent Simulation Universe blueprint

**Other key references:**
- `HEELKAWN_CANON_BIBLE.md` — Lore canon
- `.cursor/rules/heelkawn-canonical-repo.mdc` — Canonical repo policy (git push to origin/main required)
- `.cursor/rules/heelkawn-handoff.mdc` — Handoff read order (enforced by rules engine)
- `docs/WORLD_BIBLE/CANON_SYSTEMS_FEATURE_QUEUE.md` — Canon execution queue
- `docs/WORLD_BIBLE/MASTER_INDEX.md` — World bible index
- `docs/WORLD_BIBLE/GLOSSARY.md` — Canon glossary with implementation anchors
- `TASKS.md` — Current task tracking
- `TODO.md` — Detailed todo list
- `docs/PLAYTEST_CHECKLIST.md` — Playtest verification steps

**Truth hierarchy (when docs conflict):**
1. Source code and Godot runtime checks (highest truth)
2. `docs/BUILD_INVENTORY.md` — Honest built-vs-missing inventory
3. `docs/HEELKAWN_STATE.md` — Current working state
4. `docs/HEELKAWN_PROJECT_COMPASS.md` — Project compass
5. `AI_README.md` — Kernel philosophy (non-negotiable principles)
6. Older completion reports and AI session notes — Historical evidence, not authority

**Quick repo stats (as of May 21, 2026):**
- ~100+ autoload singletons registered in `project.godot`
- ~60+ script files across `scripts/` subdirectories (ai, camera, career, combat, data, debug, export, future, interfaces, items, jobs, kernel, memory, pawn, performance, persistence, player, save, social, stockpile, system, testing, tests, ui, utils, world)
- ~45+ scenes (Main, World, ColonyHUD, ObserverHUD, plus 30+ UI panels)
- ~50+ docs (active) + ~80 archive docs
- Tests in `tests/` directory
- C#/Mono integration in `dotnet/`
- Git: `origin/main` at `github.com/PVAGR/HeelKawn1`

---

## UNIVERSE ARCHITECTURE DOCTRINE

**HeelKawn is a Persistent Simulation Universe, not a global colony sim.**

1. **Deterministic ≠ Centralized**
   - Determinism means auditable cause/effect and replayable history, not centralized control.
   - Systems can exist as world rules, but actions must pass through people: households, proto-camps, guilds, settlements, leaders, architects, elders, and local authority.

2. **Every HeelKawnian is an Autonomous Person**
   - Location, memory, needs, profession, knowledge, trust, fear, ambition, relationships, and local belonging.
   - HeelKawnians make decisions based on what they can see, who they trust, what they need, their role, and their obedience to local authority.
   - Jobs are not invisible universal commands; jobs come from people and are claimed based on visibility, trust, proximity, role, and need.

3. **Access and Visibility are Earned**
   - Systems can exist in code before anyone sees them.
   - The world should not expose them until HeelKawnians or players discover, build, organize, teach, or unlock them through lived history.
   - A proto-site is not a formal settlement. A settlement only becomes formal once real authority, survival infrastructure (hearth/storage/shelter), and stable population/leadership emerge.

4. **No UI Lies**
   - No formal settlement overlays, active settlement labels, or territory boxes from proto-sites.
   - No reports saying settlements exist or are active when the formal settlement count is zero.
   - Visuals are truthful: proto-sites may exist internally but remain invisible until authority and infrastructure are established.

5. **Observer / Incarnation Inspection is Core v1 Functionality**
   - Clicking any HeelKawnian should show: current state, current job, job issuer, visible orders, last claim failure reason, carried item, needs, region/settlement/proto-camp, nearby resources, what they can see, and why they are not working.
   - Player can follow a pawn to understand their world, decisions, constraints, and agency.

6. **Jobs Must Have Source and Visibility**
   - Every job must have an issuer (pawn_id, role), reason (hunger, shelter, defense, teaching, ritual), authority_scope (household, band, proto_camp, formal_settlement), and visible_to (self, settlement, nearby, all).
   - HeelKawnians see only jobs they are eligible for and that are visible to them (within settlement, trusted leader, nearby region, or emergency override).

7. **The Game Must Play Itself First**
   - Before players build empires, HeelKawnians must survive, gather, store, build shelter, make fire, assign work, teach, reproduce, mourn, migrate, and form authority without player babysitting.
   - Fresh sim must bootstrap from wanderers → proto-camp → household networks → provisional leader → local authority orders → first survival jobs → hearth/storage/shelter → formal settlement emergence.

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

### ✅ Phase 1 — Living World Baseline (COMPLETE - 100%)
- World generation
- Time + ticks
- Pawns, animals, enemies
- Jobs, stockpiles, building
- Needs (hunger, rest, mood)
- Death that propagates safely
- HUD that reflects reality
- Job pacing and food spiral balanced
- Housing pressure responsive

### ✅ Phase 2 — The Kernel (COMPLETE - 100%)
**WorldMemory** — Append-only fact log recording:
- Pawn deaths (who, when, where, cause, profession, parents)
- Animal deaths, building construction/destruction
- Fire events, starvation events, migration events
- Teaching events, leadership challenges
- Governance changes, life path milestones
- Region discovery, neural AI decisions, player presence
- Food events (FOOD_EVENT), work events (WORK_EVENT)
- Auto-infers kind from string type via _infer_kind_from_type()

**WorldMeaning** — Derived, deterministic interpretations:
- Region tags computed from facts (hunger_place, repeated_death, safe_hearth, fertile, farmed, busy, active)
- Meaning is computed, never scripted
- Connected to the dominant event pipeline (schema gap fixed)

**Persistence Rules** — What survives:
- Ruins, scars, ecological damage
- WorldPersistence tracks persistence scores per region
- SettlementRebirth handles revival vs permanent ruin
- Cultural habits survive through CulturalMemory

### ✅ Phase 3 — Historical Continuity (COMPLETE - 100%)
- Ruins replacing old builds
- Long-term land degradation / recovery (LandRecovery)
- Pawns reacting to historical places
- Settlement lifecycle: active → abandoned → reviving → permanent_ruin
- SettlementArchitect: visual decay for abandoned settlements
- WorldPersistence: scar levels, ruin persistence
- SettlementRebirth: deterministic revival gates (food, pawn presence, cooldown)
- Graves accumulate, roads form from repeated use

### 🔶 Phase 4 — Civilization & Identity (~85% — mostly implemented, some stubs)
- Roles beyond jobs (Big Five personality, life paths, affinities)
- Lineages / continuity (KinshipSystem, BloodlineSystem)
- Factions (emergent, FactionRegistry, SchismManager, FragmentationManager)
- Cultural memory (CulturalMemory, CulturalStyleManager)
- Cultural architecture signatures (PERIM_R, DOOR2_MIN_SPAN, PEACE_TICKS)
- Settlement identity divergence (OPEN/CAUTIOUS/DEFENSIVE cultures)
- Authority emergence and decay (AuthoritySystem)
- Collapse progression (CollapseSystem: Trust → Authority → Knowledge → Environment)
- Player-readable meaning audio (MeaningAudioCue, MeaningAmbianceController)
- ProgressionSystem (impact tiers: Unknown → Known → Remembered → Noticed → Influential → Legendary)
- Religion lens, sacred memory, myth memory
- Knowledge transmission and loss (KnowledgeSystem, TechnologySystem)
- Gossip propagation, dramatic event generation, goal engine
- Display settings (resolution, window mode, vsync)
- Profession reassignment (HeelKawnians can change roles based on skill growth)
- Colony role balance (diversity pressure when one profession dominates)
- Neural bias active at all normal play speeds (gate moved from 50x to 200x)
- Settlement planner posts infrastructure + security jobs (fire pit, storage hut, protect, defend)
- Warrior peacetime patrol (visible perimeter presence instead of stockpile clustering)

> **Stubs / gaps**: FactionRegistry is stubbed (not fully wired), ReligionLens has SacredMemory/MythMemory/DRUJ/Asha interpretation paths unimplemented. SchismManager and FragmentationManager exist but need integration.

### 🔶 Phase 5 — Emergent Life (WE ARE HERE - ~10% complete)
The Truman phase. The goal: NPCs and the world live so richly and unpredictably that neither the player nor AI can predict what will happen after a few years in-world. Emergence, not scripting.

**What this means:**
- HeelKawnians develop unique life stories that no one authored
- Settlements diverge in ways that surprise even the system architect
- Social bonds, feuds, and traditions form organically from repeated interaction
- The world produces stories worth telling — not because we wrote them, but because the simulation lived them
- A HeelKawnian's 30-year life arc should be as unpredictable as a real person's

**What still must be built:**

#### 5.1 Deep Social Dynamics (~0%)
- Multi-generational grudges and alliances that persist beyond individuals
- Social norms that emerge from repeated behavior, not rules
- Gossip that actually changes how HeelKawnians treat each other
- Reputation that spreads between settlements via travelers and traders
- Pawn-driven law: taboos and obligations that form from crisis response

#### 5.2 Knowledge Ecology (~5%)
- Teaching chains that create lineages of knowledge (master → apprentice → master)
- Knowledge loss events: a skill dies with its last carrier
- Rediscovery: lost techniques found through experimentation or outside contact
- Record carriers: grave markers, carved stones, ledgers that preserve knowledge beyond death
- Technology divergence between isolated settlements

#### 5.3 Emergent Narrative (~0%)
- Situations that arise from pressure, not scripts (famine → hoarding → conflict → exile → diaspora)
- HeelKawnian life arcs that are readable as stories without authoring
- Generational change: the same town feels different 50 years later
- Silence as outcome: sometimes nothing survives, and that's meaningful

#### 5.4 World-Memory-Driven Behavior (~15%)
- HeelKawnians react to regional meaning tags (avoid death places, seek safe hearths)
- Settlement policy shaped by historical events (famine survivors hoard differently)
- Cultural drift: customs change over generations without anyone deciding
- Myth formation: after enough time, facts become legends, legends become religion

#### 5.5 Embodied Unpredictability (~5%)
- Body risk creates individual stories (injury → career change → teaching path)
- Personality-driven divergence: same situation, different HeelKawnian, different outcome
- Neural matrix produces genuinely different behavior per pawn
- Stochastic resonance: small events cascade into settlement-scale change

📍 **Current overall project completion: ~55-60%**

### 🔶 Phase 6 — Player Meaning Layer (0%)
- What the *player* understands vs what the world knows
- Partial information
- Myth vs truth
- Incarnation knowledge fog (spectator knowledge doesn't leak)

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

HeelKawn is a **deterministic 2D world simulation** built in Godot 4.6.2. It is:

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
- Events become "myth" (distorted, emotional memory) that affects HeelKawnian mood and regional reputation

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
- **Vintage Story**: Slow progression, tactile building, and rewarding material development
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
- **Godot 4.6.2** (deterministic kernel/stable)

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

### Core Autoloads (consolidation in progress)
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
- ColonySimServices: Colony-wide metrics (food/housing/materials/haul plus warmth, storage, cooking, light pressures)

### Pressure-driven construction (P2+)

Settlement seeders (`Main._seed_bootstrap_jobs`), ruler posts (`HeelKawnianManager.leader_direct_construction`), and Matrix job bias read `ColonySimServices` pressures instead of blind `pop/4` hearth counts or housing-only fire-pit nudges.

- `compute_settlement_build_priorities()` ranks warmth, cook, storage, housing, farm, ambition.
- `can_seed_fire_pit()` applies a **regional** cap so multiple formal settlements in one center region do not each queue duplicate fire pits.
- Job posts should carry `JobManager.stamp_seeder_metadata(reason, …)` (e.g. `warmth_coverage`, `storage_pressure`).
- HUD colony line: `F` food, `H` housing, `W` warmth, `S` storage, `K` cooking, `L` light (night hearth coverage).
- **Job visibility**: settlement-scoped jobs match by shared `settlement_id` or center region (not only exact center tile).
- **Raw food**: `Item.RAW_FOOD_NUTRITION_MULT` (0.62), mood penalty 8, ~14% stress event — always edible, never hard-blocked.
- **Storage split**: `BUILD_STORAGE_HUT` = wood pile; `BUILD_GRANARY` = food — seeder routes by ground spill (`wood` vs `food`).
- **Farms**: seed only when `food_press <= 0.45` and survival met; forage/hunt/fish biased when `food_press > 0.45`.
- **Contentment**: `CONTENTMENT_STREAK_TICKS` (90) @ `CONTENTMENT_MAX_PRESSURE` (0.15) gates ambition-tier builds; high-drive leaders may skip via `leader_may_skip_contentment_gate`.
- **Night**: work speed ×0.72 without hearth at night; rare `DREAD` mood when exposed.

> **Note**: Consolidation is in progress. These 11 core managers exist, but 164 autoloads are still registered in project.godot. Old autoloads have NOT been removed yet — removing them is the next consolidation step.

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

### New System Development Guidelines

Before adding morality, religion, myth, politics, culture, law, book, or civilization behavior:

-   Read `docs/WORLD_MEANING_ENGINE_ARCHITECTURE.md`
-   Do not create competing `WorldMemory` ingestion loops
-   Do not make Asha/Druj the engine root
-   Use facts first, meaning derived, interpretation later

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

**Phase**: Consolidation + Phase 5A foundation
**Next Target**: Complete autoload consolidation (remove old autoloads, finalize 11-manager structure), then Phase 5A deep social dynamics
**Engine**: Godot 4.6.2
**Development Lane**: Playable prototype under consolidation — stabilizing architecture, refactoring autoloads, building toward v1

**Recently Completed**:
- Profession reassignment (HeelKawnians can change roles based on skill growth)
- Colony role balance (diversity pressure when one profession dominates)
- Neural bias active at all normal play speeds (gate moved from 50x to 200x)
- Settlement planner posts infrastructure + security jobs (fire pit, storage hut, protect, defend)
- Warrior peacetime patrol (visible perimeter presence)
- Display settings (resolution, window mode, vsync)
- Performance optimizations (spatial grid, redraw throttle, meaning throttle, caches)
- Event schema gap fix (FoodChainManager events now reach WorldMeaning)

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
├── HEELKAWN_STATE.md (Redirect → docs/HEELKAWN_STATE.md)
├── HEELKAWN_CANON_BIBLE.md (Lore canon)
├── docs/ (Planning, specs, logs, reports)
│   ├── WORLD_BIBLE/
│   ├── AUTOLOAD_CONSOLIDATION_PLAN.md
│   ├── CURSOR_MASTER_PLANNING_SPEC.md
│   └── ...
├── autoloads/ (164 registered autoloads in project.godot; ~276 .gd files total in folder including non-autoload scripts)
│   ├── WorldMemory.gd
│   ├── WorldMeaning.gd
│   ├── SettlementMemory.gd
│   ├── SettlementPlanner.gd
│   ├── SettlementRebirth.gd
│   ├── SettlementArchitect.gd
│   ├── WorldAI.gd
│   ├── JobManager.gd
│   └── ...
├── scripts/ (Game logic by domain)
│   ├── ai/  camera/  career/  combat/
│   ├── data/  debug/  export/  future/
│   ├── interfaces/  items/  jobs/  kernel/
│   ├── memory/  pawn/  performance/  persistence/
│   ├── player/  save/  social/  stockpile/
│   ├── system/  testing/  tests/  ui/  utils/  world/
├── scenes/ (Scene files)
│   ├── main/  pawn/  stockpile/  tests/  ui/  world/
├── tests/ (Test scripts)
├── assets/ (Game assets)
├── addons/ (Godot plugins)
├── builds/ (Export builds)
├── brain/ (AI/neural data)
├── logs/ (Runtime logs)
├── rules/ (Development rules)
├── tools/ (Utility scripts)
├── project.godot
└── ...
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
