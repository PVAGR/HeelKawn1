# HeelKawn Autonomous Life AI Execution Plan

Date: 2026-05-10
Status: Execution blueprint
Scope: Build fully autonomous HeelKawnian lives with observer/incarnation play, and civilization progression from primitive survival to advanced civilization.

## 1) Vision translation (what you are asking for)

You want HeelKawn to run as a true living world where:
- Every HeelKawnian has their own life, mind, goals, relationships, and long-term arc.
- The world progresses with zero player intervention.
- The player can zoom out as spectator, then zoom in and inhabit one life, then zoom out again.
- Civilization can climb from stone and sticks to boats/navies, warships, spaceships, and advanced belief/magic systems.
- Progress is not fake scripting. It is emergent from AI behavior and deterministic world rules.

This is aligned with HeelKawn canon and current architecture.

## 2) Non-negotiable constraints

- Determinism first: all chance-like outcomes must use WorldRNG named streams.
- Facts first: all meaningful actions/events logged to WorldMemory.
- Meaning second: WorldMeaning derives interpretation from facts.
- No god-hand hacks: player observation/incarnation must not break autonomous simulation.
- No disconnected feature islands: each new system must wire into jobs, memory, knowledge, settlements, and UI diagnostics.

## 3) Current foundation we will build on

Live systems already present:
- Per-pawn profile and identity layer: HeelKawnianManager + HeelKawnianIdentity.
- Mind snapshot layer: HeelKawnianMind.
- Per-pawn brain runtime: HeelKawnPawnBrain + PawnBrainBridge.
- Social memory substrate: GrudgeManager, GossipManager, KinshipSystem, RelationalGraph.
- Knowledge substrate: KnowledgeSystem + stones/books beginnings.
- Settlement and world substrate: SettlementMemory, SettlementPlanner, WorldAI, CivilizationStage.
- Observer/incarnation framework: Main mode contract and incarnation systems.

## 4) Target AI architecture (full autonomy)

### A. Individual Life Engine (per pawn)

Each pawn runs a deterministic loop:
1. Sense: body, nearby world, social context, institution obligations.
2. Remember: short-term context + long-term memory retrieval.
3. Prioritize: survival, duty, kinship, ambition, ideology, creativity.
4. Plan: pick action chain (single action and multi-step goal plans).
5. Act: execute through existing command/job legality surfaces.
6. Record: WorldMemory fact events + profile updates.

Implementation anchor files:
- scripts/ai/HeelKawnPawnBrain.gd
- autoloads/HeelKawnianMind.gd
- autoloads/HeelKawnianManager.gd
- autoloads/PawnBrainBridge.gd
- scripts/pawn/HeelKawnian.gd

### B. Social and Institution Engine

Autonomous institutions emerge from pawn behavior:
- Households and kin groups
- Guilds and teaching circles
- Governance and military chains
- Religious/cultural factions
- Trade alliances and war blocs

Implementation anchor files:
- autoloads/KinshipSystem.gd
- autoloads/AuthoritySystem.gd
- scripts/ai/GuildSystem.gd
- autoloads/TradePlanner.gd
- scripts/ai/SettlementAI.gd

### C. Civilization Progression Engine

Civilization progression uses measurable gates:
- Knowledge spread
- Infrastructure density
- Institution complexity
- Energy/material sophistication
- Quality-of-life metrics (lifespan, literacy, health, security)

Stages remain derived, not scripted cutscenes.

Implementation anchor files:
- autoloads/CivilizationStage.gd
- autoloads/KnowledgeSystem.gd
- autoloads/TechnologySystem.gd
- scripts/ai/WorldAI.gd

### D. Advanced Domains (boats, ships, spaceships, magic)

All advanced domains are extensions of the same base loop:
- New knowledge branches
- New material/tool prerequisites
- New jobs/buildings/institutions
- New risks and logistics chains

No special-case cheats. Boats, warships, spacecraft, and magic all require deterministic progression preconditions.

## 5) Progression model: Stone -> Navy -> Space -> Arcane science

### Era track
- Era 0 Primitive survival
- Era 1 Agrarian and craft
- Era 2 Metal and city-state
- Era 3 Early empires and naval logistics
- Era 4 Industrial and mechanized warships
- Era 5 Information and automation
- Era 6 Orbital and spacecraft industry
- Era 7 Arcane-material synthesis (magic system implemented as disciplined knowledge and ritual technology)

### Magic design rule
Magic is treated as a formal knowledge domain with:
- Discovery prerequisites
- Crafting/ritual inputs
- Institutional carriers
- Failure modes and social consequences
- Full event logging and replay determinism

## 6) Execution phases (what to build in order)

### Phase 1: Life autonomy hardening (now)
Goal: every pawn truly runs an independent life loop.

Build:
- Expand HeelKawnPawnBrain from action selection into multi-step personal plans.
- Add per-pawn life agendas (daily, seasonal, lifetime).
- Add memory retrieval scoring into decision context.
- Add profile-to-behavior bridge beyond job bias (learn/teach/preserve/recover/innovate).

Acceptance:
- At least 90 percent of alive pawns always have a non-idle active agenda unless physically blocked.
- F10 diagnostics show per-pawn current goal, reason, and memory driver.

### Phase 2: Household and kinship autonomy
Goal: social reproduction and household economics become autonomous.

Build:
- Household role planner (providers, caregivers, builders, defenders).
- Kinship obligations and inheritance effects on choices.
- Child development lifecycle and skill inheritance stabilization.

Acceptance:
- Households form, split, merge, and recover without user commands.
- Child-to-adult transitions generate stable new workers and identities.

### Phase 3: Institutions and governance
Goal: coordinated collective behavior.

Build:
- Deterministic institution jobs (guild work, teaching cycles, governance tasks).
- Authority legitimacy, challenge, succession, and reform loops.
- Settlement-level strategic planning tied to real constraints.

Acceptance:
- Settlements can maintain order and recover from leadership loss.
- Institution events visibly alter labor allocation and outcomes.

### Phase 4: Economy and logistics depth
Goal: material reality drives choices.

Build:
- End-to-end crafting consumption and tool dependencies.
- Route-aware trade and naval logistics prerequisites.
- Production chains from raw extraction to complex goods.

Acceptance:
- No high-tier build without full material and logistics chain.
- Trade disruptions measurably impact settlement stability.

### Phase 5: Innovation and tech emergence
Goal: true world-driven technological growth.

Build:
- Innovation candidates from knowledge combinations and experimentation outcomes.
- Research institutions with throughput tied to talent, resources, stability.
- Cross-settlement diffusion and knowledge loss/recovery pressure.

Acceptance:
- New technologies appear from simulated conditions, not manual unlocks.
- Tech progress can stall, regress, and recover.

### Phase 6: Naval and warfare ecosystems
Goal: from boats to warships as emergent military-economic systems.

Build:
- Water transport jobs and ports.
- Fleet construction and maintenance logistics.
- Strategic warfare AI tied to economy, doctrine, and risk.

Acceptance:
- Fleet power correlates with industry and institutions, not spawn rules.
- Wars produce lasting demographic, cultural, and infrastructure effects.

### Phase 7: Spacefaring civilization
Goal: spacecraft as culmination of prior systems.

Build:
- High-energy, high-material industrial chains.
- Orbital infrastructure and mission institutions.
- Inter-settlement strategic specialization for large projects.

Acceptance:
- Space projects require long-horizon planning and multi-settlement coordination.
- Collapses can interrupt programs and force recovery arcs.

### Phase 8: Arcane and metaphysical layer
Goal: magic integrated without breaking determinism.

Build:
- Arcane knowledge graph and ritual institutions.
- Resource and risk model for ritual work.
- Cultural/religious/political interactions with arcane systems.

Acceptance:
- Magic outcomes are deterministic from seed + conditions.
- Arcane systems interact with governance, warfare, and social trust.

## 7) Observer and incarnation product model

Required mode behavior:
- Spectator mode: omniscient dashboard and timeline tools.
- Incarnation mode: live one-life perspective with limited knowledge.
- Seamless transition: player can zoom out and back in without pausing world autonomy.

Implementation details:
- Keep mode contract strict in Main (observer commands only in observer mode).
- Expose per-pawn life timeline, current intentions, major memories, and social web.
- Add "follow life" camera and reversible handoff with zero sim authority bleed.

## 8) Metrics and quality gates

We should treat this like a civilization AI product with measurable gates.

Autonomy metrics:
- Goal continuity rate per pawn.
- Idle ratio per pawn and per settlement.
- Plan completion ratio.
- Social interaction diversity index.

Civilization metrics:
- Technology diffusion speed.
- Institution stability.
- Logistics robustness.
- Demographic resilience.

Determinism metrics:
- Same-seed replay divergence count must stay zero for canonical events.
- WorldMemory audit completeness for all major actions.

## 9) Immediate implementation sprint (next 10 days)

Day 1-2:
- Add Life Agenda data model to HeelKawnianManager and brain context.
- Add F10 diagnostics row for active brains vs alive pawns.

Day 3-4:
- Implement multi-step personal plans in HeelKawnPawnBrain.
- Wire memory-retrieval scoring from PawnConsciousness and WorldMemory summaries.

Day 5-6:
- Add institution obligations (household/guild/governance) to decision scoring.
- Add deterministic plan failure handling and recovery planning.

Day 7-8:
- Add settlement-level autonomous objective queue with explicit ownership.
- Ensure objectives post only legal jobs through JobManager/Command API path.

Day 9-10:
- Add diagnostics and replay validation pass.
- Tune for high-speed simulation behavior at 26x/50x/100x.

## 10) Definition of done for this vision

HeelKawn reaches the intended autonomy threshold when:
- The world can run indefinitely with no human interventions and remain coherent.
- Pawn lives are inspectable and meaningfully different over generations.
- Civilization growth emerges through integrated systems from survival to advanced domains.
- Observer/incarnation mode becomes a first-class way to experience those lives.
- Deterministic replay remains intact through all layers.

This is the execution path that converts the stream-of-consciousness vision into concrete, testable, and code-driven HeelKawn reality.
