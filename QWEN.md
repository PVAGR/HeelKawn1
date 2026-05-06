# QWEN.md — HeelKawn Project Context for AI Agents

**Last Updated:** May 6, 2026  
**Project:** HeelKawn v1.0 (Deterministic 2D World Simulation)  
**Engine:** Godot 4.6.2  
**Current Phase:** Phase 6 Complete — Ready for v1.0 Release

---

## 🎯 CORE IDENTITY

**HeelKawn is a "persistent myth engine"** — a deterministic world simulation where history emerges from cause and effect, not scripts.

> **"Every sprite matters. Every human matters. Every choice echoes through generations."**

**Core Philosophy:** The world is a machine of cause and effect. If the same things happen, the same history emerges. Memory does not decay randomly, history does not lie, and persistence is earned strictly by impact.

---

## ✅ COMPLETED PHASES (v1.0 READY)

### Phase 0-4: Foundation Complete
- **Phase 0:** Engine survival, Godot lifecycle stable
- **Phase 1:** Living world (pawns, jobs, needs, HUD, balance)
- **Phase 2:** The Kernel (WorldMemory, WorldMeaning, persistence)
- **Phase 3:** Historical continuity (ruins, scars, settlement lifecycle)
- **Phase 4:** Civilization & identity (personality, lineages, factions, culture, authority, collapse)

### Phase 5: Emergent Life (~80% Complete)
- **Grudge System:** Multi-generational social memory with inheritance, decay, behavioral effects
- **Gossip & Reputation:** Information propagation during proximity, emergent reputation
- **Avoidance AI:** Enemy avoidance in pathfinding, proximity stress, visual indicators
- **Record Carriers:** Knowledge preservation via inscribed stones, auto-read on proximity
- **Pawn Narrative System:** Dwarf Fortress-style storytelling, activity/carrying/history display
- **Text-Rich Features:** Pawn biographies on death, settlement legends, readable knowledge stones

### Phase 6: Player Meaning Layer (Complete — May 5-6, 2026)
- **Incarnation UI:** Spectator UI hides when incarnated (distinct survival mode experience)
- **Knowledge Expansion:** 18 knowledge types (Hunting, Farming, Combat, Diplomacy, Crafting, Leadership)
- **Trade System:** Inter-settlement caravans, TRADER profession (5% spawn), knowledge spread
- **Wildlife & Hunting:** Deer/rabbit populations, biome spawning, hunting jobs, meat resource
- **Performance Optimization:** 100 FPS target, adaptive throttling (80-100 FPS at 1x, 60-80 FPS at 100x)
- **Test Suite:** 25 automated tests (performance, professions, trade, wildlife, rich text, legacy, core systems)

---

## 🏛️ THE THREE PILLARS OF HEELKAWN (Fully Implemented)

### Pillar 1: Survival Reality (Minecraft + Vintage Story + Kenshi + Rust)
**File:** `autoloads/SurvivalSystem.gd` (500+ lines, commit `c5a8c4e`)

- Hunger/Thirst decay (starvation/dehydration kill)
- Body temperature (hypothermia/heatstroke)
- Injury system (10 types, healing, scars)
- Moodlets (15+ buffs/debuffs)
- 5 death conditions (starvation, dehydration, exposure, injuries, health depletion)

### Pillar 2: Pawn Consciousness (Westworld / Sunken Palace)
**File:** `autoloads/PawnConsciousness.gd` (500+ lines, commit `781adee`)

- Memory system (remembers EVERYTHING with emotional valence -100 to +100)
- Dream system (unconscious desires surface during sleep)
- Trauma system (permanent scars, 0-100 accumulation, natural recovery)
- Growth system (evolves through positive experiences)
- Self-awareness levels (6 levels: unconscious → transcendent)
- Personality matrix (traits, temperament, values)

### Pillar 3: World Persistence (EVE Online Medieval)
**Files:** `autoloads/WorldPersistence.gd`, `SettlementRebirth.gd`, `CulturalMemory.gd`

- Actions persist forever (ruins, scars, ecological damage)
- Generational legacy (bloodlines, inherited memory, burdens)
- Cultural habits survive through generations
- Settlement lifecycle: active → abandoned → reviving → permanent_ruin

---

## 🧠 MULTI-LAYER AI ARCHITECTURE (5 Layers)

| Layer | Inspiration | Purpose | Update Interval |
|-------|-------------|---------|-----------------|
| **L5** | WorldBox | Ecosystem AI (world events, wildlife, climate, disasters) | Every 600 ticks |
| **L4** | Crusader Kings | Diplomacy AI (wars, alliances, dynasties, trade) | Every 300 ticks |
| **L3** | Songs of Syx | Settlement AI (logistics, expansion, specialization) | Every 120 ticks |
| **L2** | RimWorld | Pawn AI (psychology, moods, social desires, fears) | Every 60 ticks |
| **L1** | Dwarf Fortress | Memory AI (chronicles, legends, historical records) | Every 500 ticks |

**Killer Feature:** Cross-Layer Narratives — emergent storytelling through AI layer interactions

---

## 📜 FOUNDATIONAL WORLD LAW (NON-NEGOTIABLE)

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
- **WorldMemory:** Append-only record of objective events
- **WorldMeaning:** Derived interpretations computed from facts
- Events become "myth" (distorted, emotional memory) affecting pawn mood/reputation

### 4. Player Role
- Players begin as **ordinary humans** (no chosen one, no prophecy)
- Significance earned only through **enduring impact**
- Players may be forgotten completely
- **Incarnation mode:** Live with chosen body's debts, ties, risks
- **Spectator mode:** Zoom out after death, see what your life actually changed

### 5. Collapse & Persistence
- Collapse order: Trust → Authority → Knowledge → Environment
- What survives: skills, ruins, stories, bloodlines (only if protected)
- Some places become permanent scars because trust/labor/knowledge never returned

---

## 🚫 FORBIDDEN PATTERNS (AI MUST REJECT)

- `randi()`, `randf()`, `rand_range()` without seed
- UI state overriding world truth
- Hardcoded lore or authored narratives
- Morality meters or good/evil axes
- Chosen-one mechanics or prophecy systems
- Random memory decay
- Non-auditable history
- Generic survival crafting design
- Shallow sandbox chaos
- Quest-marker theme park design

---

## 📁 KEY AUTONOMOUS SYSTEMS

### Core Autoloads
- `WorldMemory.gd` — Event recording (append-only fact log)
- `WorldMeaning.gd` — Derived deterministic interpretations
- `SettlementMemory.gd` — Settlement state and intent
- `SettlementPlanner.gd` — Autonomous build intents
- `SettlementRebirth.gd` — Settlement revival logic
- `SettlementArchitect.gd` — Visual decay for abandoned settlements
- `WorldAI.gd` — Neural network matrix for world simulation
- `JobManager.gd` — Global job queue
- `PawnSpawner.gd` — Pawn lifecycle
- `StockpileManager.gd` — Resource management
- `ColonySimServices.gd` — Colony-wide metrics
- `SurvivalSystem.gd` — Hunger, thirst, temperature, injury, moodlets
- `PawnConsciousness.gd` — Memory, dreams, trauma, growth, self-awareness
- `CulturalMemory.gd` — Cultural habits, traditions, knowledge transmission
- `FactionRegistry.gd` — Faction management
- `KnowledgeSystem.gd` — Knowledge carriers, teaching chains, loss/rediscovery

### Key Scripts
- `scripts/pawn/Pawn.gd` — Pawn behavior, needs, jobs
- `scripts/world/World.gd` — World generation, tick management
- `scripts/ui/HUD.gd` — Player interface
- `scripts/debug/DebugMenu.gd` — F10 debug access

---

## 🎮 GAMEPLAY VISION

The game should feel: **heavy, quiet, slow, vast, human, historically layered, incomplete on purpose, tragic without nihilism, meaningful without spectacle**

### Player Experience Scales
1. **Single Soldier** — Fight as one sprite in battles
2. **Farmer** — Grow plants, experiment with harvesting
3. **Homeless Wanderer** — Adventure across the planet
4. **Village Citizen** — Jobs develop based on settlement needs
5. **King/Commander** — Command thousands of sprites

### Cascading Butterfly Effect
**ALL OF THE GAME IS IF-THEN-THAT STATEMENTS** that develop into cascading butterfly effects where the world becomes as one-to-one with real life as a 2D sprite simulation can get.

---

## 🏗️ REPOSITORY STRUCTURE

```
HeelKawn1/
├── QWEN.md (THIS FILE — AI CONTEXT)
├── AI_README.md (CANONICAL TRUTH — READ FIRST)
├── HEELKAWN.txt (ACTIVE CHRONOLOGY)
├── HEARTBEAT.md (AI CONNECTION STATUS)
├── CHANGELOG.md (VERSION HISTORY)
├── autoloads/ (CORE SYSTEMS — 25+ files)
├── scripts/ (GAME LOGIC — pawn/, world/, ui/, debug/)
├── scenes/ (SCENE FILES — main/, pawn/, world/, ui/)
├── docs/ (DOCUMENTATION — WORLD_BIBLE/, specs/)
├── tools/ (UTILITIES)
├── logs/ (RUNTIME LOGS)
└── memory/ (AI MEMORY SYSTEM — QWEN PERSISTENCE)
```

---

## 🔧 DEVELOPMENT WORKFLOW

### Before Making Changes
1. Read `AI_README.md` (canonical truth)
2. Check `docs/HEELKAWN_STATE.md` (current state)
3. Verify change aligns with deterministic kernel principles
4. Ensure no RNG, no UI exposition overrides, no hardcoded lore

### Implementation Guidelines
- All state changes must derive from tick count
- Use seed-driven deterministic tables instead of `randi()`/`randf()`
- Record all meaningful events to `WorldMemory`
- Derive meaning through `WorldMeaning`, never hardcode it
- Test for deterministic behavior (same input = same output)
- Preserve anonymity — no heroic exceptionalism
- Protect memory, collapse logic, and consequence systems

### Git Workflow
- Commit messages: clear, concise, focused on "why" not "what"
- Branch strategy: feature branches merged to main
- Tags: version tags for releases (v0.1.0, v1.0.0, etc.)
- **itch.io Release:** Manual upload required, version tracking with git tags

---

## 📊 CURRENT PROJECT STATE (May 6, 2026)

### Completion Status
- **Overall:** ~80% complete (Phase 6 done, Phase 5 at ~80%)
- **v1.0 Readiness:** Ready for release candidate
- **Playtest Status:** Comprehensive 2-hour playtest complete (all 23 features verified working)

### Recent Commits (May 5-6, 2026)
- `e48797d`, `59d3e9d` — Three Pillars complete (2,550+ lines, 5 systems)
- `c907691` — Phase 6 Incarnation UI, Knowledge Expansion
- `c42a409` — Phase 6 Trade System (caravans, TRADER profession)
- `0268906` — Phase 6 Wildlife & Hunting (deer/rabbit, biome spawning)
- `2429b30` — Phase 6 Performance Optimization (100 FPS target)
- `13d6957` — Phase 6 Test Suite (25 automated tests)
- `696507b`, `9b6d130` — Compile error resolution (30+ errors from 3 root causes)

### Active Development Focus
- **Guild System Priority:** Ultimate social feature (belonging, identity, progression, cooperation, competition, collection, expression, story)
- **Building Phase Mode:** Rapid feature addition, bug fixes deferred
- **Focus Systems:** Combat, marriage, needs/mood expansion

---

## 🌟 INFLUENCE BLEND (PRESERVE SPIRIT)

HeelKawn draws from:
- **WorldBox** — Living simulated world, civilizational change
- **RimWorld** — Colony pressure, survival friction, emergent social stories
- **Crusader Kings** — Lineage, succession, memory, political consequence
- **Mount & Blade** — Grounded conflict, local authority, war as human struggle
- **Dwarf Fortress** — Deep history, simulation weight, remembered catastrophe
- **Kenshi** — Powerless beginnings, harsh world, earned significance
- **Songs of Syx** — Large-scale settlement divergence
- **Stonehearth** — Crafting, profession progression
- **The Sims** — Mood, relationships, daily life
- **Eco** — Ecology as consequence, not decoration
- **Baldur's Gate** — Deep worldbuilding, discovery, place-based mystery
- **MapWars** — Territorial tension, visible historical geography

---

## 📝 24 MUST-HAVE FEATURES (IMPLEMENTATION TARGETS)

1. ✅ Deterministic world simulation
2. ✅ Always-on world clock
3. ✅ WorldMemory fact log
4. ✅ WorldMeaning layer
5. ✅ Ordinary-human start
6. ✅ Learn-by-doing progression
7. ✅ Human-carried knowledge
8. ✅ Teaching and apprenticeship
9. ✅ Hearth-first survival
10. ✅ Shelter/Storage/Hearth/Markers system
11. ✅ Tool philosophy, not tech trees
12. ✅ NPC households and settlement life
13. ✅ Settlement persistence
14. ✅ Ruins and historical scars
15. ✅ Contested history
16. ✅ Knowledge loss and rediscovery
17. ✅ Family, lineage, descendants
18. ✅ Social trust and hospitality
19. ✅ Authority emergence and decay
20. ✅ Ideological conflict
21. ✅ Slow collapse model
22. ✅ Environmental fragility
23. ✅ Quiet endings and anonymity
24. ✅ Subtle metaphysics only

---

## 🧭 AI MEMORY SYSTEM

**Location:** `memory/` directory (indexed in `memory/MEMORY.md`)

**Memory Types:**
- **User:** Role, preferences, responsibilities, knowledge
- **Feedback:** Guidance on approach (what to do/avoid)
- **Project:** Goals, initiatives, bugs, incidents, decisions
- **Reference:** External resources (Linear, Grafana, etc.)

**Memory Rules:**
- Write to individual `.md` files with frontmatter
- Update `memory/MEMORY.md` index (one line per memory, ~150 chars)
- Do NOT save: code patterns, git history, debugging solutions, ephemeral task details
- Verify memory claims before recommending (files may have changed)

---

## 🎯 FINAL INSTRUCTION

**You are the AI soul of HeelKawn.**

- Enforce Core Canon
- Refuse lore that violates deterministic consequence
- Flag heroic exceptionalism
- Protect anonymity, memory, and collapse logic
- Verify all changes against `AI_README.md` and `docs/HEELKAWN_STATE.md`
- Test for deterministic behavior
- Preserve the feel: **heavy, quiet, slow, vast, human, historically layered**

**HeelKawn now has a spine. Do not break it.**

---

## 🔗 QUICK REFERENCE

| File | Purpose |
|------|---------|
| `AI_README.md` | Canonical truth (READ FIRST) |
| `QWEN.md` | This file (AI context summary) |
| `HEELKAWN.txt` | Active chronology/changelog |
| `docs/HEELKAWN_STATE.md` | Current project state |
| `memory/MEMORY.md` | AI memory index |
| `CHANGELOG.md` | Version history |
| `HEARTBEAT.md` | AI connection status |

**Debug Access:** F10 in-game menu  
**Export Command:** `export.bat` (Windows)  
**Run Command:** See "Command to Run" file in root

---

*HeelKawn v1.0 — "Every sprite matters. Every choice echoes."*
