# HEELKAWN Infinite Architecture Blueprint

This document translates the user's simulation-framework blueprint into an implementation order that fits the current Godot kernel.

Use this alongside [docs/HEELKAWN_STATE.md](HEELKAWN_STATE.md) and [docs/HEELKAWN_STANDALONE_MASTER_PLAN.md](HEELKAWN_STANDALONE_MASTER_PLAN.md).

## 1. Non-negotiable constraints

- Deterministic history only.
- No random world-history decay.
- No per-tick O(N) recompute in the live kernel.
- Derived meaning never writes facts.
- UI reflects truth; it never overrides truth.
- Autoloads remain simple Node scripts; no `class_name` on autoload singletons.

## 2. The actual product shape

HeelKawn is not a pure content generator. It is a deterministic simulation kernel with optional higher-level generation layers attached to it.

That means the stack should be treated as:

1. World truth kernel.
2. Spatial streaming / partitioning.
3. Relational graph layer.
4. Procedural generation and AI synthesis.
5. Agent command/observation layer.
6. Spectator/incarnation UX.

The live Godot build already runs the world clock, settlement loops, memory systems, and tick-speed controls. This blueprint describes how to extend that foundation without breaking the current playable sim.

## 3. Infinite extensibility architecture

### 3.1 Procedural world generation

World generation should be layered, not monolithic.

- Layer 1: deterministic terrain and biome generation.
- Layer 2: settlement, road, ruin, and landmark placement.
- Layer 3: biome-specific style variation.
- Layer 4: AI-augmented synthesis for rare or custom content.

The rule is simple: classic procedural methods provide structure, while AI models add variation only inside those deterministic boundaries.

### 3.2 Real-time world modification

Agents should be able to request changes to the world through validated commands.

- If the world already contains a matching asset or rule, use it.
- If not, synthesize a new object or style through a controlled generation path.
- Every modification becomes a recorded fact before it becomes a visual result.

### 3.3 Modular AI framework

AI should be split by job.

- Terrain generation model.
- Biome style model.
- Narrative interpretation model.
- Dialogue model.
- Planning model.
- Asset synthesis model.

These modules must be swappable and independently rate-limited.

## 4. Scalable data model

### 4.1 Spatial partitioning

Use chunking / quadtree-style streaming for world space.

- Only active or nearby regions stay fully simulated.
- Distant regions fall back to summary state.
- Historical records remain available even when a region is not loaded.

### 4.2 Relational graph layer

Use graph structures for non-spatial systems.

- Nodes: people, households, settlements, regions, items, beliefs, treaties.
- Edges: kinship, trade, hostility, teaching, migration, loyalty, trauma, memory.

This is the correct home for graph neural network style reasoning, because relationships are not tile data.

## 5. Agent architecture

### 5.1 Hierarchical action space

Each agent should translate intent into execution through layers.

1. Natural language or high-level goal.
2. Planning module.
3. Validated primitive action chain.
4. Simulation-side execution.

That preserves player freedom without allowing invalid commands to corrupt the kernel.

### 5.2 Composable tool use

Agents should be able to build, combine, and repurpose tools through the same action framework used for jobs and crafting.

### 5.3 Personality and social evolution

Agents need stable traits plus mutable relationships.

- Stable baseline personality.
- Memory of repeated interaction.
- Social pressure and group behavior.
- Learning from observation and teaching.

## 6. Deep simulation domains

These are the long-form feature families the user requested.

### 6.1 World generation and environment

- Terrain
- Climate
- Seasonal pressure
- Water and fertility
- Fire behavior
- Wildlife systems
- Regrowth and exhaustion

### 6.2 Civilization simulation

- Households
- Roles
- Labor
- Trade
- Governance
- Diplomacy
- Authority emergence and decay
- Conflict and treaty cycles

### 6.3 Knowledge and memory

- Observation-based learning
- Apprenticeship
- Teaching chains
- Memory inheritance
- Loss through death or neglect
- Rediscovery after loss

### 6.4 Collapse and persistence

- Trust decay
- Authority decay
- Knowledge loss
- Environmental exhaustion
- Ruins, scars, graves, roads, and customs that survive

## 7. Interaction and embodiment

### 7.1 Unified observation API

The same information surfaced to the player should be available to bots and external tools through a structured API.

### 7.2 Unified command API

Player input, AI intent, and external commands should converge on the same validators.

### 7.3 Embodiment

The engine should support bodies that differ in form but share rules.

- Humanoid bodies.
- Animal bodies.
- Vehicle-like bodies.
- Future specialized bodies.

## 8. Implementation order

This is the practical build sequence for the blueprint.

1. Deterministic world clock and stable state.
2. WorldMemory fact logging.
3. WorldMeaning interpretation layer.
4. Persistence rules for ruins, scars, and landmarks.
5. Knowledge transmission and loss.
6. NPC memory inheritance and household continuity.
7. Authority, conflict, and taboo systems.
8. Collapse progression.
9. Spatial partitioning and streaming.
10. Graph relational ontology.
11. Agent command/observation APIs.
12. Modular AI synthesis hooks.
13. Incarnation / spectator bridge.

## 9. Current live status

The existing build already supports:

- deterministic ticking via `GameManager`
- live pause and speed changes
- a HUD that reflects current speed and pause state
- a headless Godot smoke-test path

That means the tick-rate system is runnable now; future passes should preserve that contract while adding deeper simulation layers.

## 10. Safe expansion rule

If a new system cannot be expressed as either:

- a fact written into memory,
- a derived interpretation of facts,
- a validated command that mutates world state,

then it does not belong in the kernel yet.

That rule keeps the universe infinite without making it incoherent.