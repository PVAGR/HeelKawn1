# HeelKawn - Complete Feature Documentation

**Version:** 1.0 "Emergent Life"  
**Last Updated:** May 14, 2026  
**Status:** Feature Complete

---

## 🎮 **CORE GAMEPLAY**

### **Deterministic Simulation**
- Same inputs = same history every time
- No random decay or scripted events
- All outcomes computed from pawn actions
- World seed determines initial conditions

### **Game Modes**
| Mode | Description |
|------|-------------|
| **Spectator** | Omniscient view, full UI, control time speed |
| **Incarnated** | Experience through one pawn's senses, UI hidden |
| **God** | Debug mode, full control over world |

### **Time Control**
| Key | Speed | Description |
|-----|-------|-------------|
| **1** | 1x | Normal speed (60 FPS) |
| **2** | 3x | Fast forward |
| **3** | 6x | Very fast |
| **4** | 12x | Extreme |
| **5** | 26x | Ultra (stable) |
| **6** | 50x | Maximum (playable) |
| **7** | 100x | Debug speed (optimized) |
| **Space** | Pause | Freeze time |

---

## 👥 **PAWN SYSTEM**

### **6 Professions**
| Profession | Spawn % | Role | Starting Skills |
|------------|---------|------|-----------------|
| **Builder** | 20% | Construction | Building +50 |
| **Gatherer** | 20% | Food diversity | Foraging +50, Hunting +30 |
| **Warrior** | 15% | Defense, hunting | Hunting +50 |
| **Scholar** | 10% | Knowledge, research | Building +30, Foraging +20 |
| **Trader** | 5% | Commerce | Foraging +30, Hunting +30 |
| **Farmer** | 30% | Food baseline | Foraging +50 |

### **Pawn Needs**
- **Hunger** (0-100) - Must eat regularly
- **Rest** (0-100) - Must sleep in beds
- **Mood** (0-100) - Affected by conditions
- **Health** (0-100) - Injuries, illness

### **5 Skills**
1. **Foraging** - Gather berries, plants
2. **Mining** - Extract stone, ore
3. **Chopping** - Harvest wood
4. **Building** - Construct structures
5. **Hunting** - Kill animals for meat

### **Life Stages**
- **Child** (0-12 years) - Cannot work
- **Teen** (13-17 years) - Limited work
- **Adult** (18-59 years) - Full productivity
- **Elder** (60+ years) - Reduced productivity

---

## 🏛️ **SETTLEMENT SYSTEM**

### **Settlement States**
| State | Description |
|-------|-------------|
| **Active** | Thriving, pawns present |
| **Abandoned** | Empty, can be revived |
| **Revivable** | Shows signs of recovery |
| **Permanent Ruin** | Irreversibly destroyed |

### **Lifecycle**
1. **Foundation** - First pawn settles
2. **Growth** - More pawns join, buildings constructed
3. **Maturity** - Stable population, established culture
4. **Decline** - Population loss, buildings decay
5. **Abandonment** - Last pawn leaves/dies
6. **Revival or Ruin** - New settlers or permanent decay

### **Buildings**
- **Beds** - Improve rest recovery
- **Walls** - Defense, impassable barriers
- **Doors** - Controlled passage
- **Fire Pit** - Warmth, cooking, gathering point
- **Storage Hut** - Increased capacity, slower spoilage
- **Workshop** - Advanced crafting (requires technology)
- **Temple** - Cultural memory, mood recovery

---

## 📚 **KNOWLEDGE SYSTEM (18 Types)**

### **Tier 1: Survival**
1. Fire Keeping
2. Food Storage
3. Tool Making
4. Season Reading
5. Sickness Avoidance

### **Tier 2: Civilization**
6. Navigation
7. Shelter Building
8. Memory Preservation
9. Ruin Interpretation
10. Hospitality

### **Tier 3: Advanced**
11. Winter Survival
12. Teaching
13. Hunting
14. Farming
15. Combat

### **Tier 4: Specialization**
16. Diplomacy
17. Crafting
18. Leadership

### **Knowledge Preservation**
- **Inscribe on Stone** - Carve knowledge for permanence
- **Teach** - Pass to other pawns
- **Read Stones** - Learn from inscriptions
- **Trade** - Spread between settlements
- **Death** - Knowledge lost if last carrier dies without preserving

---

## ⚔️ **COMBAT & DEFENSE**

### **Enemy System**
- **EnemySpawner** - Manages waves and difficulty
- **Enemy** - Hostile entities that attack pawns
- **Raids** - Periodic attacks (every ~5 minutes at 1x)
- **War** - Settlement vs settlement conflicts

### **Defense Mechanics**
- **Warriors** - +20% combat effectiveness
- **Walls** - Block enemy movement
- **Combat Skill** - Improves with experience
- **Numbers** - Outnumbering provides bonus

---

## 🌪️ **DISASTER SYSTEM**

### **4 Disaster Types**

#### **Fire**
- **Cause:** Random (15% chance per 10000 ticks)
- **Spread:** 30% chance per update to adjacent buildings
- **Duration:** 2000-3600 ticks
- **Effect:** Destroys wooden buildings
- **Response:** Pawns flee, rebuild after

#### **Plague**
- **Cause:** Random outbreak
- **Spread:** 50% infection rate to nearby pawns
- **Duration:** 5000 ticks
- **Effect:** Reduces work efficiency, can kill
- **Response:** Infected pawns marked, may recover

#### **Famine**
- **Cause:** Food spoilage event
- **Effect:** 30-60% of food stockpiles spoiled
- **Duration:** 3000 ticks
- **Response:** Increased foraging/hunting priority

#### **Earthquake**
- **Cause:** Random geological event
- **Effect:** Destroys buildings in radius = severity
- **Duration:** Instant (500 tick aftermath)
- **Response:** Rebuild destroyed structures

---

## 🦌 **WILDLIFE SYSTEM**

### **2 Animal Types**
| Animal | Biome | Population | Meat | Hunt Time |
|--------|-------|------------|------|-----------|
| **Rabbit** | Forest | 3-8 per region | 1 | 20 ticks |
| **Deer** | Plains | 3-8 per region | 4 | 45 ticks |

### **Population Dynamics**
- **Birth Rate:** 15% per 500 tick check
- **Death Rate:** 8% per 500 tick check
- **Carrying Capacity:** 50 per region
- **Minimum Viable:** 5 for breeding

### **Hunting Mechanics**
- **Base Success:** 40%
- **Warrior Bonus:** +20%
- **Skill Bonus:** +2% per hunting level
- **Maximum:** 95% cap

---

## 💰 **TRADE SYSTEM**

### **Trade Routes**
- **Automatic:** Forms between active settlements
- **Frequency:** Check every 1000 ticks
- **Duration:** 5000 ticks per route
- **Goods:** 10 units based on surplus

### **Traders**
- **Profession:** 5% spawn chance
- **Skills:** Balanced (Foraging +30, Hunting +30)
- **Role:** Caravan duty, knowledge spread

### **Knowledge Spread**
- Trade routes spread knowledge types
- Food storage → Food Storage knowledge
- Wood/Stone → Tool Making knowledge
- Enables cultural exchange between settlements

---

## 🏆 **VICTORY CONDITIONS**

### **5 Victory Types**

#### **Legacy Victory**
- **Goal:** 1000 Legacy Score
- **How:** Children, knowledge, buildings, students
- **Multiplier:** 1.5x for player incarnations

#### **Dynasty Victory**
- **Goal:** 3 dynasties with 20+ members each
- **How:** Have children, track generations
- **Time:** Multi-generational effort

#### **Knowledge Victory**
- **Goal:** Preserve all 18 knowledge types
- **How:** Inscribe on stones, teach, trade
- **Challenge:** Prevent knowledge death

#### **Population Victory**
- **Goal:** 100 pawns alive simultaneously
- **How:** Encourage reproduction, low mortality
- **Requirements:** Food, housing, healthcare

#### **Culture Victory**
- **Goal:** 5 active settlements
- **How:** Found new colonies, maintain existing
- **Challenge:** Resource management across settlements

---

## 🎓 **TECHNOLOGY SYSTEM**

### **5 Technology Tiers**

#### **Tier 1: Basic Survival**
- **Basic Tools** - +10% work speed
- **Fire Making** - Unlock fire pit

#### **Tier 2: Settlement Foundation**
- **Woodworking** - Walls, doors, beds
- **Food Storage** - Storage huts

#### **Tier 3: Advanced Crafts**
- **Pottery** - Craft pottery job
- **Animal Domestication** - Animal husbandry knowledge

#### **Tier 4: Specialization**
- **Metallurgy** - Metalworking knowledge
- **Architecture** - Workshop, temple buildings

#### **Tier 5: Civilization**
- **Writing** - Writing knowledge
- **Philosophy** - +20% mood bonus

### **Research Mechanics**
- **Scholars** generate research points
- **Cost:** 50-500 points per technology
- **Prerequisites:** Must research in order
- **Auto-assign:** Points go to current research

---

## 📖 **RICH TEXT FEATURES**

### **Pawn Narratives**
- Click any pawn → "Narrative" tab
- Shows: Current activity, carrying, skills, family, history, legacy
- Updates in real-time
- Dwarf Fortress-style storytelling

### **Event Notifications**
- **Automatic popups** on right side
- **Color-coded:** Birth (teal), Death (red), Knowledge (purple), etc.
- **Clickable:** Death notifications show full biography
- **Throttled:** Max 3 visible, 0.3s minimum between

### **Pawn Biographies**
- **On Death:** Full life story prints to Output panel
- **Sections:** Birth/death dates, identity, family, skills, events, legacy
- **Interactive:** Click death notification for dialog view

### **Knowledge Stones**
- **Spawn:** When pawn completes CARVE_KNOWLEDGE_STONE job
- **Visual:** Blue stone sprite in world
- **Interact:** Right-click to read full inscription
- **Content:** Inscriber name, knowledge types, epitaph

### **Settlement Legends**
- **F10 → #72:** View emergent myths
- **Generated:** From actual settlement history
- **Sections:** Founding, character, trials, heroes, legacy
- **Unique:** Each settlement has different legend

### **Chronicle View**
- **F10 → #71:** Settlement history as story
- **Organized:** By year (360 ticks = 1 year)
- **Events:** Births, deaths, buildings, teaching
- **Icons:** Color-coded event types

### **Dynasty Tree**
- **F10 → #74:** Visual family tree UI
- **Generations:** Organized vertically
- **Clickable:** Click member for biography
- **Stats:** Shows profession, legacy score

### **Legacy Milestones**
- **F10 → #75:** Victory condition progress
- **Percentage:** Overall completion %
- **Goals:** Historical milestones tracked without a final win state
- **Messages:** Encouragement based on progress

---

## 🎯 **F10 DEBUG MENU (75+ Features)**

### **Phase 4-5 (ID 40-46)**
- **40:** Grudges & blood feuds
- **41:** Gossip & reputation
- **42:** Avoidance AI patterns
- **43:** Life arcs (pawn narratives)
- **44:** Knowledge carriers
- **45:** Myth formation
- **46:** Record carriers

### **Phase 6-7 (ID 70-75)**
- **70:** Legacy & dynasty tracking
- **71:** Chronicle view (settlement history)
- **72:** Settlement legends (emergent myths)
- **73:** Read knowledge stones
- **74:** Dynasty tree (visual family tree)
- **75:** Legacy milestone status (historical progress)

### **Utilities**
- **50:** Force building (instant construction)
- **27-30:** Vision scope, player intents, factions, religion

---

## 🎮 **HOW TO PLAY**

### **First 5 Minutes**
1. **Watch pawns spawn** - 20 starters with diverse professions
2. **Click a pawn** - See their narrative, skills, family
3. **Watch notifications** - Births, deaths, knowledge inscribed
4. **Speed up** - Press 3 for 26x speed
5. **Open F10** - Explore all debug features

### **First Hour**
1. **Settlement forms** - Pawns build beds, walls, storage
2. **Knowledge preserved** - Scholar inscribes first stone
3. **First death** - Click notification for biography
4. **Dynasty grows** - Children born, family tree expands
5. **Trade begins** - Caravans between settlements

### **Long-Term Goals**
1. **Reach legacy milestone** - Historical impact, not final completion
2. **Preserve all knowledge** - Prevent any from dying out
3. **Build thriving civilization** - 100+ pawns, 5+ settlements
4. **Create lasting legacy** - Multi-generational dynasty

---

## ⚙️ **TECHNICAL SPECS**

### **Performance**
| Speed | Target FPS | Actual | Status |
|-------|------------|--------|--------|
| **1x** | 60 | 80-100 | ✅ Excellent |
| **26x** | 40 | 70-90 | ✅ Excellent |
| **100x** | 30 | 60-80 | ✅ Excellent |

### **Optimizations**
- Frame budget: 10ms (100 FPS target)
- Adaptive visual throttling
- Deferred heavy operations
- Spatial grid for social proximity
- Event significance filtering

### **System Requirements**
- **OS:** Windows 10/11 (64-bit)
- **Engine:** Godot 4.6.2
- **RAM:** 2 GB minimum
- **Storage:** 200 MB
- **Display:** 1280x720 minimum

---

## 📁 **FILE STRUCTURE**

```
HeelKawn1/
├── autoloads/           # 164 autoload systems
│   ├── WorldMemory.gd   # Event storage (source of truth)
│   ├── SettlementMemory.gd
│   ├── KnowledgeSystem.gd
│   ├── LegacySystem.gd
│   ├── TradeMemory.gd
│   ├── WildlifePopulation.gd
│   ├── DisasterSystem.gd
│   ├── TechnologySystem.gd
│   ├── VictorySystem.gd
│   └── ... (120+ more)
├── scripts/
│   ├── pawn/            # Pawn AI, data, spawning
│   ├── jobs/            # Job system
│   ├── world/           # World gen, terrain
│   ├── ui/              # UI components
│   └── combat/          # Combat system
├── scenes/
│   ├── main/            # Main scene
│   └── world/           # World scene
├── docs/                # 40+ documentation files
│   ├── PLAYER_GUIDE.md
│   ├── RICH_TEXT_FEATURES_GUIDE.md
│   ├── MASTER_DEVELOPMENT_PLAN.md
│   └── ...
└── tools/
    └── test/            # Test suites
        └── ComprehensiveTestSuite.gd
```

---

## 🎓 **LEARNING RESOURCES**

### **For New Players**
1. **Gentle Onboarding / First-Body Orientation** - Light guidance (first launch)
2. **docs/PLAYER_GUIDE.md** - Complete how-to-play (400+ lines)
3. **docs/RICH_TEXT_FEATURES_GUIDE.md** - Where features are
4. **F10 Menu** - All features accessible

### **For Developers**
1. **docs/HEELKAWN_STATE.md** - Authoritative current state
2. **docs/MASTER_DEVELOPMENT_PLAN.md** - Full roadmap
3. **../AI_README.md** - Core kernel philosophy
4. **../CHANGELOG.md** - Version history

---

## 🚀 **FUTURE CONTENT (Post-1.0)**

### **Potential Additions**
- More professions (Smith, Healer, Artist)
- More wildlife (bears, wolves, birds)
- More disasters (flood, volcanic eruption)
- Magic system (mana, spells, rituals)
- Multiplayer (LAN co-op, hot-seat)
- Modding support (JSON configs, script hooks)

### **Quality of Life**
- Better tooltips
- Search/filter in F10
- Save game improvements
- Performance profiling tools
- Automated testing suite

---

**This documentation covers the major implemented systems.**

**For questions, issues, or suggestions:**
- GitHub: https://github.com/PVAGR/HeelKawn1
- Issues: Report bugs here
- Discussions: Share stories, strategies

**Build. Teach. Preserve. Leave your legacy.** 🎮
