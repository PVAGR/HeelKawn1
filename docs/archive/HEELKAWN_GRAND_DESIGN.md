# HEELKAWN: GRAND DESIGN DOCUMENT

**Version:** 1.0
**Date:** May 5, 2026
**Vision:** A living world where every sprite matters, every player has agency, and thousands can coexist in a simulation that learns and grows alongside them.

**Status:** Historical vision document / Not Runtime Truth

> This file preserves an early grand vision pass. It may overstate implementation status. For current authority, read `docs/HEELKAWN_BLUEPRINT.md`, `docs/HEELKAWN_PROJECT_COMPASS.md`, `docs/HEELKAWN_STATE.md`, and `docs/BUILD_INVENTORY.md`.

---

## 🎯 **CORE PHILOSOPHY**

> *"Every sprite matters. Every human matters. Every choice echoes through generations."*

HeelKawn is not just a game — it is a **living world simulation** that combines the sovereignty of ECO, the combat depth of Kenshi/Bannerlord, the dynasty mechanics of Crusader Kings, the autonomy of WorldBox, and the AI ambition of Pax Historia into one unified experience.

### **The Three Pillars:**

| Pillar | Principle | Implementation |
|--------|-----------|----------------|
| **SOVEREIGNTY** | Every player chooses their path | ECO-style independence + cooperation |
| **AUTONOMY** | The world lives without you | WorldBox-style self-building |
| **LEGACY** | Every action is remembered | CK3-style dynasty + genetics |

---

## 🎮 **GAME INSPIRATIONS & INTEGRATION**

### **1. ECO (Sovereignty & Cooperation)**

**What We Love:**
- Each player is independent but can cooperate
- Progress faster together, but solo is viable
- Meaningful participation required
- Open-ended gameplay loops for all roles

**HeelKawn Implementation:**
```
✅ Multiplayer framework ready
✅ Profession system (9 types: Farmer, Builder, Warrior, Scholar, Trader, Smith, Healer, Gatherer, Leader)
✅ Skill-based progression
✅ Resource interdependence (farmers need builders, builders need miners, etc.)
🔶 Player contracts/treaties (TODO)
🔶 Specialization bonuses (TODO)
```

---

### **2. KENSHI (Combat & World Exploration)**

**What We Love:**
- Dynamic text-based combat
- World feels alive as you traverse it
- Start as nobody, become a general
- Squad-based combat with sprites
- Harsh, unforgiving world

**HeelKawn Implementation:**
```
✅ Basic combat system exists
✅ Enemy spawning (CombatSystem.gd)
✅ Pawn combat stats
🔶 Dynamic text-based combat log (TODO - HIGH PRIORITY)
🔶 Soldier → General progression (TODO - HIGH PRIORITY)
🔶 Squad formation system (TODO)
🔶 World reactivity to player presence (TODO)
```

---

### **3. CRUSADER KINGS 3 (Dynasty & Genetics)**

**What We Love:**
- Clan/dynasty system with lineage
- Map colors show territory control
- Beautiful UI for leaders & experienced players
- Genetics system for individual feel
- Family trees and inheritance
- Language and cultural evolution

**HeelKawn Implementation:**
```
✅ DynastyTreeUI implemented
✅ KinshipSystem (family trees)
✅ BloodlineSystem (genetics, traits)
✅ CulturalMemory (culture evolution)
✅ Settlement colors on map
🔶 Beautiful dynasty UI polish (TODO)
🔶 Genetic trait inheritance (TODO)
🔶 Language evolution (TODO)
```

---

### **4. RIMWORLD (Modern 2D Aesthetic)**

**What We Love:**
- Modern 2D sprite-based look
- Text-based mood & individual UI
- Pawns build and work together
- Job assignment system
- Individual pawn stories
- Clean, readable UI

**HeelKawn Implementation:**
```
✅ 2D sprite-based rendering
✅ Pawn mood system
✅ Job assignment (JobManager.gd)
✅ Pawn narratives (rich text)
✅ Work collaboration
🔶 Modern UI polish (TODO - HIGH PRIORITY)
🔶 Individual pawn story logs (TODO)
🔶 Construction preview (TODO)
```

---

### **5. SONGS OF SYX (City Management)**

**What We Love:**
- Governor role for city managers
- Build and assign workers
- Large-scale settlement management
- Macro-level oversight

**HeelKawn Implementation:**
```
✅ SettlementPlanner.gd
✅ SettlementMemory.gd
✅ Job assignment system
✅ Resource tracking
🔶 Governor role/UI (TODO - MEDIUM PRIORITY)
🔶 City management overlay (TODO)
🔶 Worker assignment tools (TODO)
```

---

### **6. MOUNT & BLADE / BANNERLORD (War & Combat)**

**What We Love:**
- Large-scale battles
- Soldier → General progression
- Mixed army composition
- Tactical combat system
- That anime where soldier became general

**HeelKawn Implementation:**
```
✅ Basic combat system
✅ Enemy waves
✅ Pawn combat stats
🔶 Large-scale battles (TODO - HIGH PRIORITY)
🔶 Soldier → General progression (TODO - HIGH PRIORITY)
🔶 Army composition/tactics (TODO)
🔶 Battle formations (TODO)
```

---

### **7. BALDUR'S GATE 3 / WOW (Group Content)**

**What We Love:**
- Groups for everyone (farmers, warriors, adventurers, sailors)
- Open-ended group formation
- Cooperative achievement
- Few sprites achieving together
- Something for every playstyle

**HeelKawn Implementation:**
```
✅ Basic pawn collaboration
✅ Profession system
🔶 Formal group/guild system (TODO - HIGH PRIORITY)
🔶 Role-specific groups (Farmers Guild, Warriors Guild, etc.) (TODO)
🔶 Group bonuses (TODO)
🔶 Cooperative achievements (TODO)
```

---

### **8. STRONGHOLD / EVE ONLINE (Longevity)**

**What We Love:**
- Years-long campaigns
- Indefinite gameplay (like EVE)
- World suffers cataclysms
- New expansions/content over time
- Map perceivable at thousand-player scale

**HeelKawn Implementation:**
```
✅ Save/load system
✅ World persistence (WorldMemory.gd)
✅ DisasterSystem (fire, plague, famine, earthquake)
✅ LegacySystem (multi-generational)
🔶 Thousand-player scale testing (TODO)
🔶 Cataclysm events (TODO)
🔶 Expansion framework (TODO)
```

---

### **9. ARMA REFORGER (Individual Meaning)**

**What We Love:**
- Every sprite matters
- Every human matters
- Individual impact on world

**HeelKawn Implementation:**
```
✅ Individual pawn tracking (PawnData.gd)
✅ Pawn narratives/biographies
✅ Legacy tracking
✅ GrudgeSystem (individual feuds)
✅ GossipSystem (individual reputation)
✅ Each pawn has unique stats, traits, relationships
```

---

### **10. PAX HISTORIA (AI & Scope)**

**What We Love:**
- State-of-the-art AI
- AI grows and learns with players
- Solo players can enjoy thousands of hours with AI
- Grand scope simulation

**HeelKawn Implementation:**
```
✅ 5-Layer AI Architecture (COMPLETE):
   - L1: AIMemoryChronicler (Dwarf Fortress - chronicles)
   - L2: AIPawnPsychologist (RimWorld - psychology)
   - L3: AISettlementPlanner (Songs of Syx - strategy)
   - L4: AIDiplomacyDirector (Crusader Kings - diplomacy)
   - L5: AIWorldEcosystem (WorldBox - ecosystem)
✅ LLMClient.gd (OpenAI/Ollama support)
✅ HeelKawnAIOrchestrator.gd (master controller)
🔶 AI learning from players (TODO - HIGH PRIORITY)
🔶 AI adaptation over time (TODO)
```

---

### **11. WORLDBOX (Autonomy)**

**What We Love:**
- Plop humans → they auto-build
- Autonomy based on available resources
- God simulator perspective
- Unique design elements

**HeelKawn Implementation:**
```
✅ Pawn autonomy (job selection)
✅ Auto-building (builders construct automatically)
✅ Resource-based decisions
✅ SettlementPlanner auto-zones
🔶 Full auto-build system (TODO - HIGH PRIORITY)
🔶 God mode tools (TODO)
🔶 Resource visualization (TODO)
```

---

## 🏗️ **CURRENT ARCHITECTURE**

### **Core Systems (Implemented):**

| System | File | Status | Lines |
|--------|------|--------|-------|
| World Memory | autoloads/WorldMemory.gd | ✅ Complete | 1900+ |
| Settlement Memory | autoloads/SettlementMemory.gd | ✅ Complete | 900+ |
| Knowledge System | autoloads/KnowledgeSystem.gd | ✅ Complete | 400+ |
| Legacy System | autoloads/LegacySystem.gd | ✅ Complete | 400+ |
| Grudge Manager | autoloads/GrudgeManager.gd | ✅ Complete | 400+ |
| Gossip Manager | autoloads/GossipManager.gd | ✅ Complete | 400+ |
| Trade Memory | autoloads/TradeMemory.gd | ✅ Complete | 400+ |
| Wildlife Population | autoloads/WildlifePopulation.gd | ✅ Complete | 350+ |
| Disaster System | autoloads/DisasterSystem.gd | ✅ Complete | 600+ |
| Onboarding System | autoloads/OnboardingSystem.gd | ✅ Complete | 400+ |
| Technology System | autoloads/TechnologySystem.gd | ✅ Complete | 350+ |
| Legacy Milestone System | autoloads/VictorySystem.gd (compatibility name) | Implemented / verify current runtime | 300+ |
| Faction System | autoloads/FactionSystem.gd | ✅ Complete | 320+ |
| Farming System | autoloads/FarmingSystem.gd | ✅ Complete | 450+ |
| Crafting System | autoloads/CraftingSystem.gd | ✅ Complete | 350+ |
| Object Pool | autoloads/ObjectPool.gd | ✅ Complete | 220+ |
| Tick Rate Decoupler | autoloads/TickRateDecoupler.gd | ✅ Complete | 230+ |
| Spatial Grid | autoloads/SpatialGrid.gd | ✅ Complete | 350+ |
| EventBus | autoloads/EventBus.gd | ✅ Complete | 290+ |

### **AI Systems (Implemented):**

| System | File | Status | Lines |
|--------|------|--------|-------|
| LLM Client | scripts/ai/LLMClient.gd | ✅ Complete | 570+ |
| AI Orchestrator | scripts/ai/HeelKawnAIOrchestrator.gd | ✅ Complete | 420+ |
| AI Memory Chronicler | scripts/ai/AIMemoryChronicler.gd | ✅ Complete | 200+ |
| AI Pawn Psychologist | scripts/ai/AIPawnPsychologist.gd | ✅ Complete | 190+ |
| AI Settlement Planner | scripts/ai/AISettlementPlanner.gd | ✅ Complete | 175+ |
| AI Diplomacy Director | scripts/ai/AIDiplomacyDirector.gd | ✅ Complete | 260+ |
| AI World Ecosystem | scripts/ai/AIWorldEcosystem.gd | ✅ Complete | 300+ |

### **Core Gameplay:**

| System | File | Status |
|--------|------|--------|
| Pawn System | scripts/pawn/Pawn.gd, PawnData.gd | ✅ Complete |
| Pawn Spawner | scripts/pawn/PawnSpawner.gd | ✅ Complete |
| Job Manager | autoloads/JobManager.gd | ✅ Complete |
| Combat System | scripts/combat/ | ✅ Complete |
| Enemy Spawner | scripts/combat/EnemySpawner.gd | ✅ Complete |
| Stockpile Manager | autoloads/StockpileManager.gd | ✅ Complete |
| Path Finder | scripts/world/PathFinder.gd | ✅ Complete |
| World Rendering | scenes/world/World.gd | ✅ Complete |

---

## 📊 **PROFESSION SYSTEM**

### **9 Professions (Balanced Distribution):**

| Profession | % | Role | Skills |
|------------|---|------|--------|
| **Builder** | 18% | Housing, infrastructure | Building +50 XP |
| **Gatherer** | 18% | Food foraging | Foraging +50, Hunting +30 XP |
| **Warrior** | 15% | Defense, hunting | Hunting +50 XP |
| **Scholar** | 10% | Knowledge, research | Building +30, Foraging +20 XP |
| **Trader** | 5% | Commerce, inter-settlement | Foraging +30, Hunting +30 XP |
| **Smith** | 5% | Crafting, metalworking | Mining +40, Building +20 XP |
| **Healer** | 5% | Healthcare, medicine | Foraging +30, Hunting +20 XP |
| **Farmer** | 24% | Food baseline | Foraging +50 XP |

---

## 🧬 **KNOWLEDGE SYSTEM (26 Types)**

### **Tier 1: Survival (6)**
Foraging, Hunting, Mining, Woodworking, Basic Construction, Fire Making

### **Tier 2: Settlement (6)**
Agriculture, Animal Husbandry, Pottery, Weaving, Storage, Defense

### **Tier 3: Crafts (5)**
Metalworking, Tool Crafting, Weapon Smithing, Armor Smithing, Advanced Construction

### **Tier 4: Specialization (5)**
Engineering, Medicine, Trade, Navigation, Writing

### **Tier 5: Civilization (4)**
Architecture, Philosophy, Governance, Technology

---

## ⚔️ **COMBAT SYSTEM (To Expand)**

### **Current:**
- Basic pawn combat stats
- Enemy spawning
- Combat damage/healing

### **TODO (Kenshi + Bannerlord Vision):**
- [ ] Dynamic text-based combat log
- [ ] Soldier → General progression tree
- [ ] Squad formation (5-20 pawns per squad)
- [ ] Battle formations (phalanx, skirmish, charge)
- [ ] Morale system
- [ ] Wounding/recovery
- [ ] Combat experience/skills
- [ ] Weapon types (swords, spears, bows)
- [ ] Armor types (cloth, leather, metal)
- [ ] Battle reports/history

---

## 👥 **GROUP/GUILD SYSTEM (To Build)**

### **Vision (BG3/WOW + ECO):**
Groups for every playstyle:

| Group Type | Purpose | Members | Bonus |
|------------|---------|---------|-------|
| **Farmers Guild** | Food production | 5-20 | +20% food yield |
| **Builders Guild** | Construction | 5-15 | +15% build speed |
| **Warriors Guild** | Defense/raids | 10-50 | +10% combat power |
| **Scholars Guild** | Research | 3-10 | +25% research speed |
| **Traders Guild** | Commerce | 5-20 | +15% trade value |
| **Adventurers Guild** | Exploration | 3-10 | +30% exploration yield |
| **Sailors Guild** | Naval | 5-30 | +20% naval efficiency |
| **Crafters Guild** | Crafting | 5-15 | +15% craft quality |

### **TODO:**
- [ ] Group formation UI
- [ ] Group bonuses
- [ ] Group chat/communication
- [ ] Group achievements
- [ ] Group hierarchy (leader, officers, members)
- [ ] Group storage/shared resources

---

## 🏰 **GOVERNOR SYSTEM (To Build)**

### **Vision (Songs of Syx):**
Players can take on Governor role for settlements.

### **Governor Abilities:**
- Zone designation (residential, industrial, agricultural)
- Worker assignment priorities
- Resource allocation
- Building queue management
- Tax/trade policy
- Defense posture

### **TODO:**
- [ ] Governor UI overlay
- [ ] Zone designation tools
- [ ] Worker assignment interface
- [ ] Resource allocation panel
- [ ] Policy system
- [ ] Governor elections/appointment

---

## 🎨 **UI/UX VISION (To Polish)**

### **RimWorld-Inspired:**
- Clean, readable 2D interface
- Modern aesthetic
- Text-based information dense but organized
- Individual pawn panels with full story

### **CK3-Inspired:**
- Beautiful dynasty tree
- Map mode toggles (political, economic, military)
- Character portraits with traits
- Family tree visualization

### **TODO:**
- [ ] Modern UI theme (colors, fonts, icons)
- [ ] Dynasty tree UI polish
- [ ] Map mode overlay (territory colors)
- [ ] Pawn portrait system
- [ ] Tooltip improvements
- [ ] Keyboard shortcuts
- [ ] Settings menu

---

## 🤖 **AI AUTONOMY (To Enhance)**

### **Current (5-Layer Stack):**
✅ LLM Client (OpenAI/Ollama)
✅ AI Orchestrator
✅ Memory Chronicler (chronicles)
✅ Pawn Psychologist (moods)
✅ Settlement Planner (strategy)
✅ Diplomacy Director (wars/alliances)
✅ World Ecosystem (events)

### **TODO (WorldBox + Pax Historia Vision):**
- [ ] Auto-build when player plops pawns
- [ ] AI learns from player behavior
- [ ] AI adapts strategies over time
- [ ] Player-AI cooperation
- [ ] AI-only settlements (fully autonomous)
- [ ] AI personality types
- [ ] AI memory of player interactions

---

## 🌍 **WORLD SCALE VISION**

### **EVE Online / Stronghold Inspiration:**
- Thousand-player capable
- Years-long campaigns
- World cataclysms (reset events)
- Expansions over time
- Every player feels meaningful at any scale

### **Zoom Levels:**
| Zoom | View | Information |
|------|------|-------------|
| **1:1** | Individual pawn | Mood, needs, inventory |
| **1:10** | Settlement | Buildings, jobs, resources |
| **1:100** | Region | Multiple settlements, trade routes |
| **1:1000** | Realm | Kingdoms, wars, diplomacy |
| **1:10000** | World | Civilizations, ecosystems |

### **TODO:**
- [ ] Zoom level UI
- [ ] Information density per zoom
- [ ] Performance optimization for 1000+ entities
- [ ] Cataclysm event system
- [ ] Expansion framework

---

## 📋 **DEVELOPMENT ROADMAP**

### **Phase 1: Core Polish (Current - 2 weeks)**
- [x] Fix all compile errors
- [x] Implement 5-Layer AI
- [ ] Combat system overhaul (Kenshi/Bannerlord)
- [ ] Group/Guild system (BG3/WOW)
- [ ] UI modernization (RimWorld/CK3)

### **Phase 2: Autonomy (2-4 weeks)**
- [ ] Auto-build system (WorldBox)
- [ ] AI learning from players (Pax Historia)
- [ ] Governor system (Songs of Syx)
- [ ] Full profession gameplay loops

### **Phase 3: Scale (4-8 weeks)**
- [ ] Thousand-player testing
- [ ] Performance optimization
- [ ] Multiplayer framework
- [ ] Save/load optimization

### **Phase 4: Content (8-12 weeks)**
- [ ] More knowledge types (50+)
- [ ] More professions (15+)
- [ ] More disasters (8+)
- [ ] More wildlife (10+ species)

### **Phase 5: Polish (12-16 weeks)**
- [ ] Art assets (replace placeholders)
- [ ] Sound/music
- [ ] Gentle onboarding / first-body orientation
- [ ] Bug fixing
- [ ] Balance tuning

### **Phase 6: Launch (16-20 weeks)**
- [ ] Beta testing
- [ ] Community feedback
- [ ] Final polish
- [ ] Release v1.0

---

## 🎯 **IMMEDIATE NEXT TASKS**

Based on vision alignment, here's what to build next:

### **Priority 1: Combat Overhaul** (Kenshi + Bannerlord)
**Why:** Core to player engagement, differentiates HeelKawn
**Time:** 4-6 hours
**Tasks:**
- Dynamic text-based combat log
- Soldier → General progression
- Squad formation

### **Priority 2: Group System** (BG3/WOW + ECO)
**Why:** Enables cooperation for all playstyles
**Time:** 3-4 hours
**Tasks:**
- Guild formation UI
- Role-specific guilds
- Group bonuses

### **Priority 3: AI Autonomy** (WorldBox + Pax Historia)
**Why:** Foundation already built, solo player content
**Time:** 4-6 hours
**Tasks:**
- Auto-build integration
- AI learning framework
- Player-AI cooperation

### **Priority 4: UI Polish** (RimWorld + CK3)
**Why:** First impression, accessibility
**Time:** 4-6 hours
**Tasks:**
- Modern theme
- Dynasty tree polish
- Map mode overlay

---

## 📞 **DESIGN PRINCIPLES**

### **When in doubt, ask:**

1. **"Does every sprite matter?"** (Arma)
   - If not, add individual tracking/meaning

2. **"Can players cooperate OR go solo?"** (ECO)
   - If not, add both options

3. **"Will this be remembered?"** (CK3/Legacy)
   - If not, add to WorldMemory

4. **"Does the world live without players?"** (WorldBox)
   - If not, add AI autonomy

5. **"Is this accessible yet deep?"** (RimWorld)
   - If not, simplify UI, deepen systems

---

## 🏆 **SUCCESS METRICS**

### **Player Experience:**
- [ ] Player can play solo for 100+ hours (AI content)
- [ ] Player can cooperate with others meaningfully
- [ ] Player's choices matter across generations
- [ ] Player feels their individual pawn matters
- [ ] Player can zoom from 1:1 to 1:10000 smoothly

### **Technical:**
- [ ] 1000+ entities without lag
- [ ] AI responds in <2 seconds
- [ ] Save/load <10 seconds
- [ ] 60+ FPS at 1x speed
- [ ] 30+ FPS at 100x speed

### **Content:**
- [ ] 50+ knowledge types
- [ ] 15+ professions
- [ ] 10+ disaster types
- [ ] 10+ wildlife species
- [ ] 5+ legacy conditions / historical milestones

---

## 📝 **NOTES FOR OTHER AI COLLABORATORS**

This document is being shared across multiple AI assistants. Each AI is reviewing the same vision and providing feedback.

**Current AI Implementation Status:**
- ✅ All core systems implemented
- ✅ 5-Layer AI architecture complete
- ⚠️ Runtime status must be verified in Godot before marking systems complete
- ⚠️ Combat system needs overhaul
- ⚠️ Group system needs implementation
- ⚠️ UI needs modernization
- ⚠️ AI autonomy needs enhancement

**What Each AI Should Do:**
1. Review this vision document
2. Provide feedback on gaps/opportunities
3. Suggest implementation priorities
4. Help build highest priority features

**Consensus Building:**
- All AIs will review independently
- Feedback will be synthesized
- Best ideas will be implemented
- Vision will evolve based on collective wisdom

---

## 🚀 **CONCLUSION**

HeelKawn is ambitious. It combines the best of 11 different games into one unified vision:

- **ECO's** sovereignty
- **Kenshi's** combat depth
- **CK3's** dynasty mechanics
- **RimWorld's** modern aesthetic
- **Songs of Syx's** city management
- **Bannerlord's** large-scale war
- **BG3/WOW's** group content
- **EVE's** longevity
- **Arma's** individual meaning
- **Pax Historia's** AI ambition
- **WorldBox's** autonomy

**The result:** A living world where every sprite matters, every player has agency, and thousands can coexist in a simulation that learns and grows alongside them.

**This is HeelKawn. This is the vision. Let's build it.**

---

**Document Version:** 1.0
**Last Updated:** May 5, 2026
**Next Review:** After all AI feedback synthesized
**Status:** READY FOR IMPLEMENTATION
