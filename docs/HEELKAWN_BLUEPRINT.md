# HEELKAWN: PERSISTENT SIMULATION UNIVERSE BLUEPRINT

**Status:** Canonical Vision / Not Runtime Truth  
**Version:** 3.0 (Corrected)  
**Date:** May 5, 2026  
**Last Verified:** Pending Godot runtime verification

---

## ⚠️ DOCUMENT PURPOSE

This document describes **what HeelKawn is becoming**. It does **not** prove that every listed system is working in-game until the repo and Godot runtime verify it.

**This is a vision blueprint, not a runtime status report.**

---

## 🧭 CORE PHILOSOPHY

> "Every sprite matters. Every human matters. Every choice echoes through generations."

HeelKawn is **not just a game**. It is a **Persistent Simulation Universe**: a living world simulation that combines:

- **ECO's sovereignty** (player agency, cooperation optional)
- **Kenshi/Bannerlord's combat depth** (text-based, harsh, progression)
- **Crusader Kings 3's dynasty mechanics** (lineage, genetics, map colors)
- **RimWorld's individual pawn readability** (mood, needs, stories)
- **Songs of Syx's city management** (governors, worker assignment)
- **WorldBox's autonomy** (self-building, god-sim perspective)
- **EVE/Stronghold's longevity** (years-long campaigns, cataclysms)
- **Arma Reforger's individual meaning** (every human matters)
- **Pax Historia's AI ambition** (learning, adaptive, solo-viable)

### The Three Pillars

| Pillar | Principle | Implementation |
|--------|-----------|---------------|
| **SOVEREIGNTY** | Every player chooses their path | ECO-style independence + optional cooperation |
| **AUTONOMY** | The world lives without you | WorldBox-style self-building, AI-driven |
| **LEGACY** | Every action is remembered | CK3-style dynasty + genetics + WorldMemory |

---

## ⚖️ NON-NEGOTIABLE HEELKAWN LAWS

These laws govern the simulation engine and **cannot be violated**:

1. **Deterministic History:** Same conditions must produce same outcomes. No RNG decay of facts.
2. **Facts First:** WorldMemory records objective events before interpretation.
3. **Meaning Is Derived:** WorldMeaning may summarize but cannot rewrite facts.
4. **Persistence Is Earned:** Ruins, scars, bloodlines, reputation emerge from cause and effect.
5. **No Chosen Ones:** No prophecy destiny. No one is special by birthright alone.
6. **No Morality Meter:** No fake good/evil axis. Conflict arises from resources, loyalty, accident.
7. **No UI Lies:** Interface must reflect underlying simulation state accurately.
8. **No Random Memory Decay:** Historical records persist until actively destroyed.
9. **No Victory Screen:** No final completion. The end is another beginning.
10. **Players Begin Ordinary:** All start with ordinary skills. Authority is earned through labor.
11. **Every Sprite Matters:** Because every sprite can carry memory, labor, knowledge, bloodline, witness, or consequence.

---

## 🎮 INSPIRATION TRANSLATION (HEELKAWN-SPECIFIC)

HeelKawn does **not copy** these games. It takes their **feeling** and rebuilds it under HeelKawn's deterministic myth-engine laws.

| Game | Feeling Taken | HeelKawn Translation |
|------|---------------|---------------------|
| **ECO** | Shared responsibility, sovereignty | Player can survive alone but cooperation speeds progress. No mandatory grouping. |
| **Kenshi** | Harsh world, nobody-to-somebody | Start as ordinary. Become significant through survival, skill, leadership. |
| **Crusader Kings 3** | Dynasty, bloodlines, territory | Families become world-memory systems. Map shows clan colors, inheritance. |
| **RimWorld** | Individual pawn readability | Every pawn has daily life, needs, work, mood, consequence. |
| **Songs of Syx** | City management scale | Governors assign work, manage food, labor, buildings, populations. |
| **Bannerlord** | War as human escalation | Soldier → veteran → captain → commander → general through witnessed survival. |
| **Baldur's Gate 3 / WoW** | Group content for all playstyles | Farmers, warriors, sailors, adventurers all have group loops. |
| **EVE Online / Stronghold** | Years-long persistence | World suffers cataclysms. History outlives players. |
| **Arma Reforger** | Every human matters | No cannon fodder. Individual decisions shift outcomes. |
| **Pax Historia** | State-of-the-art AI civilization | AI grows, remembers, learns, adapts alongside players. |
| **WorldBox** | Autonomous god-map simulation | Plop humans → they auto-build based on resources, knowledge, memory. |

---

## 🔴 CURRENT RUNTIME TRUTH

**Status:** Requires Godot verification. Visible red errors must be fixed first.

### Known Runtime Blockers:

| Error | File | Line | Status |
|-------|------|------|--------|
| `bbcode_enabled` on Label | OnboardingSystem.gd | 276 | 🔶 Fix in progress |

### What Is Actually Running (Unverified):

- Basic pawn movement and interaction
- Resource gathering (wood, stone, food)
- Simple storage tracking
- Day/night cycle
- Basic job assignment

**Nothing is marked "Complete" until it boots without red errors in Godot.**

---

## 🟡 IMPLEMENTED BUT NEEDS RUNTIME VERIFICATION

These systems exist in code but **must be tested in Godot** before marking complete:

| System | File | Status | Notes |
|--------|------|--------|-------|
| WorldMemory | autoloads/WorldMemory.gd | Implemented / verify runtime | 1900+ lines. Needs clean boot test. |
| SettlementMemory | autoloads/SettlementMemory.gd | Implemented / verify runtime | Settlement lifecycle tracking. |
| KnowledgeSystem | autoloads/KnowledgeSystem.gd | Implemented / verify runtime | 26 knowledge types. |
| LegacySystem | autoloads/LegacySystem.gd | Implemented / verify runtime | Multi-generational tracking. |
| GrudgeManager | autoloads/GrudgeManager.gd | Implemented / verify runtime | Pawn feuds and conflicts. |
| GossipManager | autoloads/GossipManager.gd | Implemented / verify runtime | Reputation propagation. |
| TradeMemory | autoloads/TradeMemory.gd | Implemented / verify runtime | Inter-settlement commerce. |
| WildlifePopulation | autoloads/WildlifePopulation.gd | Implemented / verify runtime | Deer, rabbits, hunting. |
| DisasterSystem | autoloads/DisasterSystem.gd | Implemented / verify runtime | Fire, plague, famine, earthquake. |
| TechnologySystem | autoloads/TechnologySystem.gd | Implemented / verify runtime | 10 technologies, research. |
| FactionSystem | autoloads/FactionSystem.gd | Implemented / verify runtime | Diplomacy, alliances, wars. |
| FarmingSystem | autoloads/FarmingSystem.gd | Implemented / verify runtime | 4 crops, growth cycle. |
| CraftingSystem | autoloads/CraftingSystem.gd | Implemented / verify runtime | 8 recipes, workshops. |
| ObjectPool | autoloads/ObjectPool.gd | Implemented / verify runtime | Zero-GC object reuse. |
| TickRateDecoupler | autoloads/TickRateDecoupler.gd | Implemented / verify runtime | Async system updates. |
| SpatialGrid | autoloads/SpatialGrid.gd | Implemented / verify runtime | O(1) neighbor queries. |
| EventBus | autoloads/EventBus.gd | Implemented / verify runtime | Decoupled event dispatching. |

### AI Systems (Architecture Present / Learning TODO):

| System | File | Status | Notes |
|--------|------|--------|-------|
| LLMClient | scripts/ai/LLMClient.gd | Architecture present | OpenAI/Ollama/Mock support. |
| HeelKawnAIOrchestrator | scripts/ai/HeelKawnAIOrchestrator.gd | Architecture present | Master controller. |
| AIMemoryChronicler | scripts/ai/AIMemoryChronicler.gd | Architecture present | Chronicles, legends. |
| AIPawnPsychologist | scripts/ai/AIPawnPsychologist.gd | Architecture present | Pawn moods, desires. |
| AISettlementPlanner | scripts/ai/AISettlementPlanner.gd | Architecture present | Settlement strategy. |
| AIDiplomacyDirector | scripts/ai/AIDiplomacyDirector.gd | Architecture present | Diplomacy, wars. |
| AIWorldEcosystem | scripts/ai/AIWorldEcosystem.gd | Architecture present | Ecosystem events. |

**Note:** AI "learning from players" must be deterministic and auditable. All learning based on WorldMemory facts, tick-stable inputs, replayable cause/effect. No hidden non-auditable behavior.

---

## 🔵 VISION / TODO

These are **design goals**, not implemented features:

### Combat Overhaul (Kenshi + Bannerlord)
- [ ] Dynamic text-based combat log
- [ ] Wounds and recovery
- [ ] Fear, fatigue, morale tracking
- [ ] Soldier → veteran → captain → commander → general progression
- [ ] Squad formations
- [ ] Battle reports saved to WorldMemory
- [ ] Witnessed heroism/cowardice (not as morality)
- [ ] War memory affecting settlements, families, grudges

### Group/Guild System (BG3 + WOW + ECO)
- [ ] Groups form around shared work, danger, kinship, need
- [ ] Groups have memory, reputation, internal trust
- [ ] Leaders can fail
- [ ] Groups break under hunger, betrayal, death, distance
- [ ] Recorded in WorldMemory when historically meaningful
- [ ] Bonuses emerge from coordination, skill, tools, location, memory (not magic buffs)

### Lineage & Genetics (CK3)
- [ ] Track parents, children, bloodlines
- [ ] Inherited traits (individuality, not superiority)
- [ ] Names and naming customs
- [ ] Family reputation, feuds, alliances
- [ ] Lost heirs, forgotten branches
- [ ] Skills preserved through teaching
- [ ] Bloodlines survive only if protected

### Governor System (Songs of Syx)
- [ ] Player or NPC can be governor
- [ ] Zone designation (residential, industrial, agricultural)
- [ ] Worker assignment priorities
- [ ] Resource allocation
- [ ] Policy system (tax, trade, defense, culture)

### UI/UX Modernization (RimWorld + CK3)
- [ ] Modern 2D aesthetic
- [ ] Beautiful dynasty tree UI
- [ ] Map mode overlays (political, economic, military, cultural)
- [ ] Individual pawn mood panels
- [ ] Enhanced tooltips

### Scale & Cataclysms (EVE + Stronghold)
- [ ] 1000+ entity testing
- [ ] Zoom system (1:1 to 1:10000)
- [ ] Cataclysm events (plague, invasion, earthquake, meteor, civil war)
- [ ] World recovery system
- [ ] Expansion framework

---

## 🗺️ CORRECTED ROADMAP

**Do not jump into 20-week roadmap while game throws red errors.**

### Immediate Priority (Before Any Expansion):

1. **Fix current red Godot runtime errors**
2. **Verify game boots clean**
3. **Confirm which "complete" systems actually run without crashing**
4. **Then** build AI Autonomy
5. **Then** Combat Overhaul
6. **Then** Group/Guild System
7. **Then** Lineage/Genetics polish
8. **Then** Governor tools
9. **Then** UI modernization
10. **Then** scale, cataclysms, launch preparation

**The vision is correct, but runtime stability comes before expansion.**

---

## 🔧 IMMEDIATE RED ERROR FIXES

### Priority 1: OnboardingSystem.gd

**Error:**
```
Invalid assignment of property or key 'bbcode_enabled' with value of type 'bool' on a base object of type 'Label'.
```

**File:** `res://autoloads/OnboardingSystem.gd`

**Stack:**
- Line 276 at `_create_tutorial_panel`
- Line 200 at `_show_welcome_message`
- Line 81 at `_ready`

**Fix:** Change `Label.new()` to `RichTextLabel.new()` or remove `bbcode_enabled` line.

---

## 🌱 FIRST SAFE BUILD STEP

**Phase 1A — Auto-Build Seed** (After red errors fixed):

When pawns spawn:
1. Scan nearby resources
2. If no shelter exists → create shelter intent
3. If food is unsafe → create food intent
4. If storage is missing → create storage intent
5. Builders choose jobs from deterministic priority
6. Record important construction in WorldMemory

**Auto-build priority order:**
1. Survival
2. Shelter
3. Storage
4. Hearth
5. Tools
6. Defense
7. Comfort
8. Identity
9. Ambition

This matches HeelKawn's sacred civilizational order: **shelter, storage, hearth, markers**. Do not let auto-build jump straight into advanced cities without knowledge and material cause.

---

## 🏆 LONG-TERM PERSISTENT SIMULATION UNIVERSE GOALS

### Player Experience Targets (Not Current Truth):

- [ ] Player can play solo for 100+ hours through AI civilization content
- [ ] Player can cooperate with others meaningfully
- [ ] Player choices can matter across generations
- [ ] Player feels their individual pawn matters
- [ ] Player can zoom from body scale to world scale smoothly

### Technical Targets (Not Current Truth):

- [ ] 1000+ entities without unacceptable lag
- [ ] Deterministic simulation remains replayable
- [ ] Save/load remains stable
- [ ] AI response or decision layer does not block core simulation
- [ ] Performance tested at 1x, 26x, and 100x speed

### Content Targets (Not Current Truth):

- [ ] 50+ knowledge types (currently 26)
- [ ] 15+ professions (currently 9)
- [ ] 10+ disaster types (currently 4)
- [ ] 10+ wildlife species (currently 2)
- [ ] 8+ guild/institution types
- [ ] Legacy milestones instead of victory conditions

---

## 📜 LEGACY CONDITIONS (NOT VICTORY CONDITIONS)

HeelKawn is **not meant to be won, completed, or fully resolved**.

**Legacy Conditions / Historical Milestones:**

- Survived a famine
- Preserved a bloodline
- Rebuilt after collapse
- Founded a lasting settlement
- Taught knowledge that survived generations
- Created a road, ruin, custom, or memory that survived after death

**No victory screen. No final completion. No "you won HeelKawn." Legacy is the reward.**

---

## 🤖 AI & LLM USAGE RULES

### AI Learning (Must Be Deterministic):

AI adapts through recorded world events and deterministic weight changes. All learning must be:
- Based on WorldMemory facts
- Tick-stable inputs
- Replayable cause/effect
- **No hidden non-auditable behavior**

### LLM Usage (Presentation Only):

LLMs can help generate:
- Summaries
- Readable text
- Flavor
- Reports
- Interpretation

**But LLMs must NOT:**
- Override the simulation
- Rewrite history
- Become world truth

**Rule:** LLM-generated text is presentation only unless converted into deterministic world data through approved systems. **The simulation ledger is always higher authority than generated prose.**

---

## 🎭 PROTECT THE FEEL

HeelKawn should feel:

- Heavy
- Quiet
- Slow
- Vast
- Human
- Historically layered
- Incomplete on purpose
- Tragic without being nihilistic
- Meaningful without spectacle

**The plan must not drift into:**
- Generic survival crafting
- Shallow sandbox chaos
- Quest-marker theme park design
- Power fantasy

---

## 📞 AI COLLABORATOR INSTRUCTIONS

### What Each AI Should Do:

1. **Review this vision document** — Understand the full scope and kernel rules
2. **Identify gaps** — What's missing from your specialty area?
3. **Suggest optimizations** — How can we build faster/better while staying deterministic?
4. **Help build highest priority features** — Start with red error fixes, then Phase 1A
5. **Test & document** — Ensure quality, clarity, and kernel alignment

### Consensus Building Protocol:

- All AIs review independently
- Feedback synthesized by lead coordinator
- Best ideas implemented; vision evolves via collective wisdom
- **Never contradict:** Deterministic kernel, WorldMemory as source of truth, "every sprite matters"

---

## 🎯 FINAL REVISED DIRECTION

**HeelKawn's vision is ready. The runtime must now be stabilized one red error at a time.**

After the game boots cleanly, development should proceed through:

1. Deterministic AI autonomy
2. Combat memory
3. Group institutions
4. Lineage
5. Governance
6. UI clarity
7. Scale
8. Cataclysm persistence

---

## 🏁 CONCLUSION

HeelKawn is a **Persistent Simulation Universe** where:

- Every sprite matters (Arma)
- Every player has agency (ECO)
- Every action is remembered (CK3)
- Every role can become meaningful (Kenshi → General)
- Every path is valid (BG3/WOW groups for all)
- Every world tells a story (Dwarf Fortress chronicles)
- Every AI learns alongside players (Pax Historia)
- Every settlement builds autonomously (WorldBox)

**But only if the deterministic world records it, remembers it, and carries its consequences forward.**

---

**Document Version:** 3.0 (Corrected)  
**Status:** Canonical Vision / Not Runtime Truth  
**Last Updated:** May 5, 2026  
**Next Review:** After runtime verification complete  
**Shared With:** All AI Collaborators  

**Source of Truth:** This document describes the vision. Runtime truth is determined by Godot boot status and in-game verification.

---

**To begin collaboration, respond with:**

`HeelKawn brief received. Ready to collaborate. [Your specialty/feedback focus]`
