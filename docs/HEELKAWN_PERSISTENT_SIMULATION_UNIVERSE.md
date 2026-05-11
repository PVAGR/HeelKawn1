# HEELKAWN: PERSISTENT SIMULATION UNIVERSE

**Version:** 2.0
**Date:** May 11, 2026
**Status:** Canonical Vision / Not Runtime Truth

This document describes what HeelKawn is becoming. It does not prove that every listed system is working in-game until the repo and Godot runtime verify it. No system should be treated as fully implemented unless it boots cleanly in Godot without red errors.

---

## I. CORE PHILOSOPHY

> *"Every sprite matters. Every human matters. Every choice echoes through generations."*

HeelKawn is a **Persistent Simulation Universe**. It is not a traditional RPG, a survival crafting game, or a scripted world. It is a living engine of civilizational history where the passage of time, environmental pressures, social organization, and individual choices accumulate into irreversible consequences — scars on the landscape, grudges in the bloodlines, and stories recorded in memory.

The player does not *win*. They witness, participate, and are consumed by history. Every action has weight; every loss is a lesson; every generation starts with a backlog of consequence.

### The Three Pillars

| Pillar | Principle | Meaning |
|--------|-----------|---------|
| **SOVEREIGNTY** | Every player chooses their path | Independent or cooperative. Solo viable. Progress faster together, but never forced. |
| **AUTONOMY** | The world lives without you | HeelKawnians build, work, teach, fight, grieve, and continue even when players are absent. |
| **LEGACY** | Every action is remembered | Ruins, bloodlines, grudges, customs, and knowledge persist through cause and effect. |

---

## II. NON-NEGOTIABLE LAWS

These constraints govern the simulation engine and cannot be violated by any system, AI, or feature:

1. **Deterministic History:** Given identical initial conditions and inputs, the world must produce the same history. Same seed, same outcome.
2. **Facts First:** WorldMemory records objective, verifiable events before interpretation. Memory is a supplement to fact.
3. **Meaning Is Derived:** WorldMeaning may summarize or contextualize facts, but it can never rewrite the recorded truth of the world.
4. **Persistence Is Earned:** Ruins, scars, bloodlines, reputation, and customs must emerge directly from cause and effect — not from scripts, timers, or designer intent.
5. **No Chosen Ones:** Individuals are defined by circumstance, labor, failure, or survival — never by divine mandate, prophecy, or destiny.
6. **No Morality Meter:** Conflict arises from resource scarcity, competing loyalties, ideological differences, and simple accident. No fake good/evil axis.
7. **No UI Lies:** The user interface must reflect the underlying simulation state accurately. A starving pawn is physically failing, not "low on morale."
8. **No Random Memory Decay:** Historical memory persists unless explicitly destroyed by time, conflict, or the death of its last carrier.
9. **No Victory Screen:** HeelKawn cycles. There is no "end." Legacy milestones replace victory conditions.
10. **Players Start as Ordinary Humans:** All characters begin with ordinary skills and limited knowledge. Ascent to authority is earned through labor and survival.
11. **Every Sprite Matters:** Every pawn can carry memory, labor, knowledge, bloodline, witness, or consequence. No cannon fodder.

---

## III. THE FEEL

HeelKawn should feel:

- **Heavy** — decisions have weight
- **Quiet** — the world doesn't narrate itself
- **Slow** — civilization takes time
- **Vast** — the map is larger than any one story
- **Human** — every pawn is a person
- **Historically layered** — the present sits on top of the past
- **Incomplete on purpose** — the world doesn't explain itself
- **Tragic without being nihilistic** — loss is meaningful, not meaningless
- **Meaningful without spectacle** — consequence, not fireworks

HeelKawn must not drift into:
- Generic survival crafting
- Shallow sandbox chaos
- Quest-marker theme park design
- Power fantasy
- Eugenics gameplay
- MMO buff mechanics

---

## IV. INSPIRATION TRANSLATION

HeelKawn does not copy these games. It takes the *feeling* of their mechanics and rebuilds them under HeelKawn's deterministic myth-engine laws.

### ECO — Sovereignty & Cooperation
**Feeling:** Players can survive alone, but progress faster through cooperation. Farmers, builders, sailors, teachers, rulers, warriors, traders, and wanderers all matter because the world is too large for one person to master.
**HeelKawn Translation:** Sovereignty plus interdependence. No forced grouping. Every profession is a valid life path. Cooperation accelerates; isolation is viable but slower.

### KENSHI — Harsh World & Combat
**Feeling:** Players begin as ordinary people, not heroes. They wander, suffer, train, fight, lose limbs, gain followers, and slowly become important through survival.
**HeelKawn Translation:** Powerless beginnings, earned significance, dangerous travel, small-group combat. Combat remembers humanity — wounds, recovery, fear, fatigue, morale. Battle reports saved to WorldMemory. Warriors who never relinquish force can become threats.

### CRUSADER KINGS 3 — Dynasty & Lineage
**Feeling:** Dynasty, lineage, blood, family, and political memory. The map communicates clans, kingdoms, colors, borders, bloodlines, rulers, inheritance, and history.
**HeelKawn Translation:** Families and bloodlines become world-memory systems, not just UI decoration. Lineage tracks parents, children, bloodlines, inherited traits, names, naming customs, family reputation, feuds, alliances, lost heirs, forgotten branches, and skills preserved through teaching. Genetics give individuality, not chosen-one superiority. Family is memory, inheritance, burden, obligation, grief, and continuity.

### RIMWORLD — Modern 2D Readability
**Feeling:** Sprites feel individual through mood, text, work, relationships, injury, hunger, exhaustion, fear, and memory. Modern 2D aesthetic. Clean, readable UI.
**HeelKawn Translation:** Every pawn has daily life, needs, work, mood, and consequence. UI reflects computed meaning. Moods derive from environment, events, and social ties. The player can read a pawn's life like a story.

### SONGS OF SYX — City Management
**Feeling:** Some players want to govern, assign work, manage food, labor, buildings, and populations.
**HeelKawn Translation:** Governors and organizers become real roles inside civilization, not menu-only abstractions. Governor decisions are backed by deterministic resource/need graphs.

### MOUNT & BLADE: BANNERLORD — War & Escalation
**Feeling:** A soldier can begin as nobody, survive battles, gain trust, lead squads, command companies, and eventually become a general. War as human escalation.
**HeelKawn Translation:** Battlefield rank is earned through witnessed survival, leadership, and consequence. Soldier → Veteran → Captain → Commander → General. Large-scale battles with theater delegation. Combat progression is Kenshi-slow, not RPG-fast.

### BALDUR'S GATE 3 / WORLD OF WARCRAFT — Group Content
**Feeling:** Small groups of players forming parties to do meaningful things together. Groups for every playstyle — farmers, warriors, adventurers, sailors, builders, teachers.
**HeelKawn Translation:** No single "main loop." Every life path can become a social loop. Groups form around shared work, danger, kinship, settlement need, trade, teaching, or survival. Groups have memory, reputation, internal trust, and leaders who can fail. Groups break apart under hunger, betrayal, death, or distance. Bonuses emerge from coordination, skill, tools, location, and memory — not magic MMO aura buffs. Groups are recorded in WorldMemory when historically meaningful.

### STRONGHOLD KINGDOMS / EVE ONLINE — Longevity
**Feeling:** Years-long campaigns. The map feels massive. Players zoom out and realize they are part of something ancient, political, fragile, and bigger than themselves. Cataclysms function like world-shaping eras or expansions, not simple resets.
**HeelKawn Translation:** Long-lived worlds, political memory, collapse, rebirth, and history that outlives players. Cataclysms rewrite WorldMeaning, not reset the simulation.

### ARMA REFORGER — Every Human Matters
**Feeling:** Every sprite matters. Not because every human is special, but because every human can carry knowledge, witness history, preserve a skill, die in a meaningful place, or change the outcome of a settlement.
**HeelKawn Translation:** Every pawn is a person in the ledger. Death propagates safely. Casualties alter supply lines, morale, and regional stability.

### PAX HISTORIA — AI Civilization
**Feeling:** HeelKawnians should grow, remember, learn, react, govern, farm, migrate, teach, rebuild, grieve, and continue even when players ignore them. AI civilization must be capable of thousands of hours of play even for solo players.
**HeelKawn Translation:** AI adapts through recorded world events and deterministic weight changes. All learning must be based on WorldMemory facts, tick-stable inputs, and replayable cause/effect. No hidden non-auditable behavior. No black-box ML. Pattern-weighted decision trees + deterministic memory.

### WORLDBOX — Autonomous God-Map
**Feeling:** Tiny people build based on what exists around them. They don't wait for the player to command every action. Civilization emerges from available resources, geography, memory, and pressure.
**HeelKawn Translation:** Autonomous sprites plus deeper history, memory, families, combat, AI, and player sovereignty. Auto-build priority: Survival → Shelter → Storage → Hearth → Tools → Defense → Comfort → Identity → Ambition. No jumping to advanced cities without knowledge and material cause.

---

## V. LLM USAGE RULES

LLMs can help generate summaries, readable text, flavor, reports, or interpretation, but they must not override the simulation.

**Rule:** LLM-generated text is presentation only unless converted into deterministic world data through approved systems. The simulation ledger is always higher authority than generated prose. The world records facts first. Meaning is derived from facts. UI and AI text must never rewrite history.

---

## VI. STATUS LABELS

Every system in this document uses one of these labels. Do not use "Complete" unless Godot has verified it.

| Label | Meaning |
|-------|---------|
| **Verified Runtime Complete** | Tested in Godot. No red errors. Boots clean. Functions as described. |
| **Implemented / Needs Verification** | Code exists. May work. Not yet tested or may have known issues. |
| **Partial / Prototype** | Some logic in place. Not production-ready. May have gaps. |
| **Vision / TODO** | Design only. No working code yet. |

---

## VII. CURRENT SYSTEM STATUS

### Core Simulation (Verified Runtime Complete)
- Deterministic tick loop (TickManager → GameManager → ColonySimServices)
- Pawn movement, needs, jobs, death, birth
- Job system (JobManager, priority queue, claim/complete/abandon)
- Stockpile management (StockpileManager)
- Pathfinding (PathFinder)
- World terrain, biomes, features (World.gd, Biome.gd)
- Day/night cycle, seasons (DayNightCycle, SimTime)
- Resource collection and consumption

### Memory & Meaning (Implemented / Needs Verification)
- WorldMemory — event recording, append-only
- WorldMeaning — derives meaning tags from events
- CulturalMemory — regional cultural identity
- SettlementMemory — settlement state tracking
- KnowledgeSystem — knowledge carriers, transmission, loss, rediscovery

### Social Systems (Implemented / Needs Verification)
- KinshipSystem — family relationships, clans, nations
- GrudgeManager — inter-pawn grudges from death/injury events
- GossipManager — event-driven gossip propagation
- ReputationSystem — pawn and settlement reputation

### Pawn AI (Implemented / Needs Verification)
- HeelKawnianMind — 11-layer deterministic mind snapshot
- PawnConsciousness — dreams, trauma, awareness, growth, beliefs
- PawnDecisionRuleMatrix — 30+ rules feeding from mind, memory, meaning
- WorldAI — context building, meaning-driven behavior nudges
- HeelKawnianManager — worldbox loop, profession balance, construction seeding

### Visual Systems (Implemented / Needs Verification)
- Terrain micro-textures per biome
- Fire pit and chimney smoke (GPUParticles2D)
- Pawn walk/work animation
- Night window glow
- Seasonal terrain and tree color shifts
- Sun/moon directional light
- Ambient biome particles
- Construction scaffolding
- Bloom post-processing
- Territory overlay with clan/nation colors
- Minimap with territory layer

### Building & Economy (Implemented / Needs Verification)
- BuildingRegistry — 20+ data-driven building types
- SettlementPlanner — auto-zoning, construction seeding
- FarmingSystem — farming plots, crop cycles
- CraftingSystem — basic recipes (paper, leather, ink, pen, book)
- TradeMemory — inter-settlement trade planning
- FogOfDiscovery — per-capita needs-based economy

### Combat (Partial / Prototype)
- Basic combat resolution (CombatResolver)
- CombatNarrative — Kenshi-style text combat → WorldMemory
- BattleReporter — combat death recording
- Enemy spawning and wildlife
- **Needs:** Soldier→General progression, squad formations, large-scale battles, war memory affecting settlements/families/grudges

### Groups & Guilds (Vision / TODO)
- Basic pawn collaboration exists through job system
- **Needs:** Formal group/guild system with memory, reputation, trust, leaders who can fail, dissolution mechanics, WorldMemory recording

### Lineage & Genetics (Partial / Prototype)
- KinshipSystem tracks family relationships
- BloodlineSystem exists
- DynastyTreeUI exists
- **Needs:** Genetic trait inheritance, naming customs, family reputation propagation, lost heirs, forgotten branches, map-color integration

### Governor System (Partial / Prototype)
- SettlementPlanner auto-zones
- GovernorSystem auto-appoints oldest HeelKawnian
- **Needs:** Governor UI, city management tools, policy decisions, worker assignment interface

### AI Learning (Vision / TODO)
- 5-layer AI architecture exists (Chronicler, Psychologist, Planner, Diplomat, Ecosystem)
- HeelKawnAIOrchestrator registered as autoload
- **Needs:** Deterministic learning from WorldMemory events, weight adjustment, auditable adaptation. No hidden state. No non-replayable changes.

### Player Modes (Implemented / Needs Verification)
- SPECTATOR — watch, paint zones, observe HUD
- INCARNATED — play as one pawn, WASD/E, knowledge fog, command by authority rank
- GOD — full command, place structures, no fog

---

## VIII. LEGACY MILESTONES (Not Victory Conditions)

HeelKawn has no victory screen. No final completion. No "you won HeelKawn." Legacy is the reward.

**Legacy Milestones:**
- Survived a famine
- Preserved a bloodline through three generations
- Rebuilt a settlement after collapse
- Founded a lasting settlement (50+ ticks active)
- Taught knowledge that survived the teacher's death
- Created a road, ruin, custom, or memory that outlived its maker
- Led a group through a catastrophe
- A bloodline's last carrier died — knowledge lost forever
- A settlement was abandoned and became a permanent ruin
- A grudge persisted across three generations
- A pawn rose from nobody to general through combat survival

These are recorded in WorldMemory. They are not scored. They are not ranked. They simply happened.

---

## IX. ONBOARDING (Not Tutorial)

HeelKawn should not become a tutorialized power fantasy. The player can learn controls, UI, and basic body interaction, but the world does not explain itself like a quest game. Learning comes from observation, failure, teaching, and consequence.

**Gentle onboarding / first-body orientation:**
- Learn movement, camera, basic interaction
- Understand the HUD and pawn info panels
- Observe HeelKawnians working, building, and surviving
- Discover that the world operates without you
- Find your own path — farmer, warrior, builder, wanderer, governor

No quest markers. No hand-holding. No "now go do X." The world is the teacher.

---

## X. CORRECTED BUILD ORDER

This is an aspirational track, dependent on runtime stability, testing, performance, and scope control. Runtime stability comes before expansion.

### Phase 0: Stabilize Core Runtime
- Fix all red Godot runtime errors
- Boot cleanly with zero red errors
- Confirm which "complete" systems actually run without crashing
- Run smoke test: `--headless --script tools/sim_boot_smoke.gd`

### Phase 1: AI Autonomy Seed (Deterministic, Auditable)
- **Phase 1A — Auto-Build Seed:** When pawns spawn, scan nearby resources. If no shelter exists, create a shelter intent. If food is unsafe, create a food intent. If storage is missing, create a storage intent. Builders choose jobs from deterministic priority (Survival → Shelter → Storage → Hearth). Record important construction in WorldMemory.
- **Phase 1B — AI Decision Refinement:** Review world events every N ticks. Identify patterns (starvation, combat deaths, resource gaps). Adjust AI decision weights deterministically. Store learnings in CulturalMemory. All changes auditable and replayable.

### Phase 2: Combat Memory Overhaul (Kenshi + Bannerlord)
- Dynamic text-based combat log
- Wounds, recovery, fear, fatigue, morale
- Soldier → Veteran → Captain → Commander → General progression
- Squad formations
- Battle reports saved to WorldMemory
- Witnessed heroism and cowardice (not morality — observation)
- War memory affecting settlements, families, grudges, and songs/stories
- Warriors who never relinquish force can become threats

### Phase 3: Group/Guild System (BG3/WOW + ECO)
- Groups form around shared work, danger, kinship, settlement need, trade, teaching, or survival
- Groups have memory, reputation, internal trust
- Leaders can fail
- Groups break apart under hunger, betrayal, death, or distance
- Bonuses emerge from coordination, skill, tools, location, and memory — not aura buffs
- Recorded in WorldMemory when historically meaningful

### Phase 4: Lineage & Genetics Polish (CK3)
- Genetic trait inheritance (deterministic)
- Naming customs and family names
- Family reputation propagation
- Lost heirs, forgotten branches
- Feuds and alliances across generations
- Map-color integration for dynasties and territories
- Family = memory, burden, obligation, grief, continuity

### Phase 5: Governor Tools (Songs of Syx)
- Governor UI with city management
- Policy decisions backed by deterministic resource/need graphs
- Worker assignment interface
- Governor reputation and consequences
- Macro-level settlement oversight

### Phase 6: UI Modernization (RimWorld + CK3)
- Clean, readable 2D aesthetic
- Pawn mood and personality UI
- Dynasty tree polish
- Map mode overlays (political, cultural, resource, danger)
- Zoom from body scale to world scale

### Phase 7: Scale & Persistence
- Performance testing for 1000+ entities
- LOD simulation (close = full tick, distant = aggregated state)
- Zoom changes UI, not simulation fidelity
- Long-term persistence verification
- Save/load stability under heavy load

### Phase 8: Cataclysms & Expansions
- World-shaping disasters that rewrite WorldMeaning, not reset simulation
- Content cadence to sustain long-term engagement
- Cataclysms as eras, not wipes

---

## XI. TARGETS (Not Current Truth)

These are goals. They are not achieved until verified.

### Player Experience Targets
- Player can play solo for 100+ hours through AI civilization content
- Player can cooperate with others meaningfully
- Player choices can matter across generations
- Player feels their individual pawn matters
- Player can zoom from body scale to world scale

### Technical Targets
- 1000+ entities without unacceptable lag
- Deterministic simulation remains replayable
- Save/load remains stable
- AI decision layer does not block core simulation
- Performance tested at 1x, 26x, and 100x speed
- 60+ FPS at 1x speed, 30+ FPS at 100x speed

### Content Targets
- 50+ knowledge types (currently 26)
- 15+ professions (currently 9)
- 10+ disaster types (currently 4)
- 10+ wildlife species (currently 2)
- 8+ guild/institution types (currently 0)
- Legacy milestones instead of victory conditions

---

## XII. DESIGN PRINCIPLES

### When in Doubt, Ask:
1. **"Does every sprite matter?"** (Arma) — If not, add individual tracking/meaning
2. **"Can players cooperate OR go solo?"** (ECO) — If not, add both options
3. **"Will this be remembered?"** (CK3/Legacy) — If not, log to WorldMemory
4. **"Does the world live without players?"** (WorldBox) — If not, add AI autonomy
5. **"Is this accessible yet deep?"** (RimWorld) — If not, simplify UI, deepen systems

### Code Standards (All New Systems Must):
1. Be deterministic (same inputs → same outputs)
2. Log to WorldMemory (facts first)
3. Support 1000+ entities (performance tested)
4. Have undo/rollback (safe failure)
5. Be documented (inline comments + docs/)
6. Use `stable_hash()` instead of `randi()`/`randf()`
7. Never override WorldMemory facts

---

## XIII. AI COLLABORATOR INSTRUCTIONS

If you are an AI reading this document:

1. **Review this vision** — Understand the full roadmap and kernel rules
2. **Respect the non-negotiables** — Never contradict deterministic kernel, WorldMemory as source of truth, "every sprite matters"
3. **Use correct status labels** — Never claim "Complete" unless Godot verifies it
4. **Start small** — One safe, deterministic improvement at a time
5. **Make it auditable** — Every change must be traceable to WorldMemory facts
6. **LLM text is presentation** — Never let generated prose override simulation state
7. **Test before claiming** — Run the smoke test. Boot the game. Verify.

---

## XIV. FINAL STATEMENT

HeelKawn is a Persistent Simulation Universe where:

- Every sprite matters (Arma)
- Every player has agency (ECO)
- Every action is remembered (CK3)
- Every role can become meaningful (Kenshi → General)
- Every path is valid (BG3/WOW groups for all)
- Every world tells a story (Dwarf Fortress chronicles)
- Every AI learns alongside players — deterministically (Pax Historia)
- Every settlement builds autonomously from local resources (WorldBox)

HeelKawn's vision is ready. The runtime must now be stabilized one red error at a time. After the game boots cleanly, development should proceed through deterministic AI autonomy, combat memory, group institutions, lineage, governance, UI clarity, scale, and cataclysm persistence.

**This is HeelKawn. This is the vision. Now we build it.**

---

**Document Version:** 2.0
**Last Updated:** May 11, 2026
**Status:** Canonical Vision / Not Runtime Truth
**Replaces:** HEELKAWN_GRAND_DESIGN.md (v1.0), HEELKAWN_MASTER_DEVELOPMENT_PLAN_REVISED.md, HEELKAWN_STANDALONE_MASTER_PLAN.md
