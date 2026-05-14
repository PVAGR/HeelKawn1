# HeelKawn - A Deterministic World Simulation

> **"The world is a machine of cause and effect. If the same things happen, the same history emerges."**

HeelKawn is a **persistent myth engine** — a deterministic 2D colony simulation where history is computed, not scripted. Memory does not decay randomly, history does not lie, and persistence is earned strictly by impact.

**⚠️ IMPORTANT:** HeelKawn is **never finished**. It is a living, evolving simulation. We are always building, always refining, always expanding. This repository captures the current state of an ongoing creative journey.

---

## 🎮 **WHAT IS HEELKAWN?**

HeelKawn is NOT:
- ❌ A game to "win"
- ❌ A sandbox with no purpose
- ❌ A roguelike with random events
- ❌ A finished product

HeelKawn IS:
- ✅ A **living world** that continues without you
- ✅ A **story generator** where every HeelKawnian has a life story
- ✅ A **legacy builder** where knowledge outlives its carriers
- ✅ A **deterministic simulation** where same inputs = same history
- ✅ An **ongoing project** — always evolving, never complete

**Think:** Dwarf Fortress meets RimWorld meets Crusader Kings, with a focus on emergent storytelling and multi-generational legacy.

---

## 🚧 **CURRENT STATUS**

| Metric | Status |
|--------|--------|
| **Current Focus** | Consolidation toward a truthful v1 foundation |
| **Kernel Health** | 🟢 Godot headless smoke passes |
| **Last Updated** | May 7, 2026 |
| **Project Shape** | Large playable prototype, not a final release candidate |
| **North Star** | Indefinite deterministic civilization simulation |

**What Works Now:**
- ✅ Pawn AI with needs, skills, jobs, and professions
- ✅ Settlement lifecycle (active → abandoned → reviving)
- ✅ Knowledge system (18 types, inscribe on stones, read them)
- ✅ Grudge & gossip systems (emergent social dynamics)
- ✅ Legacy, memory, and dynasty-facing systems in active development
- ✅ Text-rich storytelling (biographies, legends, chronicles)
- ✅ Performance work and diagnostics are present
- ✅ Civilization stage lens derives a live era label from world state
- ✅ HeelKawnian development profiles derive per-pawn phase, drive, next need, skills, knowledge, and era context

**What's Next:**
- 🔶 Runtime truth pass in Godot: verify UI, F10 diagnostics, and red errors
- 🔶 Wire HeelKawnian profiles into pawn behavior: learn, teach, preserve, practice, innovate, and recover
- 🔶 Lineage/progression: parent lookup, child creation, skill branches
- 🔶 Material reality: crafting consumes real inventory/stockpile resources
- 🔶 Indefinite evolution foundation: deepen era/stage tracking from real world state

**Start with:** [`docs/HEELKAWN_PROJECT_COMPASS.md`](docs/HEELKAWN_PROJECT_COMPASS.md) and [`docs/HEELKAWN_BLUEPRINT.md`](docs/HEELKAWN_BLUEPRINT.md)
**Then see:** [`docs/HEELKAWN_STATE.md`](docs/HEELKAWN_STATE.md), [`docs/BUILD_INVENTORY.md`](docs/BUILD_INVENTORY.md), and [`docs/HEELKAWNIAN_EVOLUTION_SYSTEM.md`](docs/HEELKAWNIAN_EVOLUTION_SYSTEM.md)

---

## 🏆 **KEY FEATURES**

### **📖 Text-Rich Storytelling**
- **HeelKawnian Narratives** - Every HeelKawnian has a readable life story
- **Settlement Legends** - Each settlement develops unique myths
- **Chronicle View** - Settlement history told as a story
- **Full Biographies** - Click death notifications to read complete life stories

### **🗿 Knowledge Preservation**
- **18 Knowledge Types** - Fire keeping, tool making, diplomacy, leadership, and more
- **Inscribed Stones** - Carve knowledge on stone to preserve it forever
- **Interactive Reading** - Right-click stones to read inscribed knowledge
- **Knowledge Death** - If last carrier dies without inscribing, knowledge is lost forever

### **HeelKawnian Development AI**
- **Stable Soul Identity** - HeelKawnians receive deterministic identity anchors that can carry memory and traits
- **Development Profiles** - Each HeelKawnian gets a derived phase, drive, next need, knowledge summary, and skill summary
- **Era Context** - Individual profiles include the current civilization stage so personal growth stays rooted in the world
- **Debug Visibility** - F10 #49 prints sample HeelKawnian profiles for inspection

### **👨‍👩‍👧‍👦 Dynasty System**
- **Family Trees** - Track generations visually
- **Legacy Scoring** - Measure your impact (children, knowledge, buildings, students)
- **Succession** - Heirs inherit from ancestors
- **Legacy Milestones** - Historical markers replace final win states

### **🎭 Incarnation Mode Roadmap**
- **Spectator Mode** - Omniscient view with full UI
- **Incarnated Mode** - Target experience is world-through-a-HeelKawnian perception
- **Knowledge Fog** - Target experience is only knowing what the HeelKawnian knows
- **Multiple Lives** - Target experience is moving through generations without owning the world

### **⚔️ Emergent Social Dynamics**
- **Grudges** - HeelKawnians remember wrongs, inherit family feuds
- **Gossip** - Information spreads through proximity
- **Reputation** - Emerges from aggregated gossip
- **Avoidance AI** - HeelKawnians physically avoid enemies

---

## 🎯 **HOW TO PLAY**

### **Basic Controls**
| Key | Action |
|-----|--------|
| **Click pawn** | Select & view narrative |
| **P** | Toggle incarnation mode |
| **1-7** | Simulation speed (1x → 100x) |
| **Space** | Pause/Resume |
| **F10** | Debug/creator menu |
| **Esc** | Deselect pawn |

### **Getting Started**
1. **Launch game** - World generates with 20 starter pawns
2. **Watch notifications** - Births, deaths, knowledge inscribed
3. **Click pawns** - See their narratives, skills, family
4. **Speed up** - Press 3 (26x) for faster simulation
5. **Open F10** - Explore all features

### **Legacy Milestones**
HeelKawn is not won or completed. Track historical milestones such as:
- **1000 Legacy Score** (from children, knowledge, buildings, students)
- **3 Dynasties Founded**
- **20 Dynasty Members**
- **3 Player Incarnations**

Track progress in **F10 #75**.

---

## 📖 **DOCUMENTATION**

### **For Players:**
| Document | Purpose |
|----------|---------|
| [`docs/PLAYER_GUIDE.md`](docs/PLAYER_GUIDE.md) | **Start here** - How to play, all features explained |
| [`docs/RICH_TEXT_FEATURES_GUIDE.md`](docs/RICH_TEXT_FEATURES_GUIDE.md) | Where to find all story features |
| [`PLAYTEST_REPORT.md`](PLAYTEST_REPORT.md) | Comprehensive playtest results |

### **For AI Assistants & Developers:**
| Document | Purpose |
|----------|---------|
| [`docs/HEELKAWN_PROJECT_COMPASS.md`](docs/HEELKAWN_PROJECT_COMPASS.md) | **READ FIRST** - Truth hierarchy, north star, immediate path |
| [`docs/HEELKAWN_BLUEPRINT.md`](docs/HEELKAWN_BLUEPRINT.md) | Canonical Persistent Simulation Universe blueprint, not runtime truth |
| [`docs/HEELKAWN_STATE.md`](docs/HEELKAWN_STATE.md) | Current working state, blockers, next tasks |
| [`docs/BUILD_INVENTORY.md`](docs/BUILD_INVENTORY.md) | Built-vs-missing reality check |
| [`docs/HEELKAWNIAN_EVOLUTION_SYSTEM.md`](docs/HEELKAWNIAN_EVOLUTION_SYSTEM.md) | Long-range indefinite evolution vision |
| [`docs/MASTER_DEVELOPMENT_PLAN.md`](docs/MASTER_DEVELOPMENT_PLAN.md) | Historical/comprehensive roadmap |
| [`HEELKAWN.txt`](HEELKAWN.txt) | Quick context (what we're working on now) |
| [`AI_README.md`](AI_README.md) | Development guidelines, canon, principles |

### **For Contributors:**
| Document | Purpose |
|----------|---------|
| [`CHANGELOG.md`](CHANGELOG.md) | Version history |
| [`docs/RELEASE_CHECKLIST.md`](docs/RELEASE_CHECKLIST.md) | How to release to itch.io |

---

## 🤖 **FOR AI ASSISTANTS**

**If you are an AI assistant reading this repository:**

1. **READ FIRST:** [`docs/HEELKAWN_PROJECT_COMPASS.md`](docs/HEELKAWN_PROJECT_COMPASS.md) - North star, truth hierarchy, immediate path
2. **CANON BLUEPRINT:** [`docs/HEELKAWN_BLUEPRINT.md`](docs/HEELKAWN_BLUEPRINT.md) - Persistent Simulation Universe laws, not runtime truth
3. **THEN READ:** [`docs/HEELKAWN_STATE.md`](docs/HEELKAWN_STATE.md) - Current working state
4. **REALITY CHECK:** [`docs/BUILD_INVENTORY.md`](docs/BUILD_INVENTORY.md) - What is live, partial, stubbed, or missing
5. **LONG VISION:** [`docs/HEELKAWNIAN_EVOLUTION_SYSTEM.md`](docs/HEELKAWNIAN_EVOLUTION_SYSTEM.md) - Indefinite civilization evolution
6. **PRINCIPLES:** [`AI_README.md`](AI_README.md) - Core kernel philosophy

**Key Principles:**
- **Deterministic Kernel:** History is computed, not scripted. Same inputs = same history.
- **Pawn-Activated:** Events trigger from HeelKawnian actions, NOT global timers.
- **No Random Decay:** Memory does not decay randomly. Persistence by impact only.
- **Ongoing Project:** HeelKawn is never finished. We are always building.

**Git Workflow:**
```bash
cd c:\Users\user\Documents\GitHub\HeelKawn1
git add -A
git commit -m "fix: [description]"  # Or "feat:", "perf:", "docs:"
git pull --rebase origin main
git push
```

**Verify Systems:**
- In-game: Press **F10** → **35 · Backbone / first-play** — prints what is LIVE vs DEFERRED
- Check [`docs/HEELKAWN_STATE.md`](docs/HEELKAWN_STATE.md) section "Current Status"

---

## 🛠️ **TECHNICAL DETAILS**

**Engine:** Godot 4.6.2  
**Language:** GDScript  
**Status:** Playable prototype under consolidation
**Performance:** Optimized paths and diagnostics are present; verify per build

### **Current Phase:** Consolidation + Phase 5A foundation
- ✅ Core deterministic simulation foundation exists
- ✅ Emergent life systems are partially/live integrated
- ✅ Initial civilization-stage and HeelKawnian development profile lenses are live
- 🔶 Player meaning, lineage depth, material reality, and indefinite era progression need verification and build-out

### **Features Implemented:**
| System | Status | Access |
|--------|--------|--------|
| Grudge System | Implemented / verify current runtime | F10 #40 |
| Gossip & Reputation | Implemented / verify current runtime | F10 #41 |
| Avoidance AI | Implemented / verify current runtime | F10 #42 |
| Pawn Narratives | Implemented / verify current runtime | F10 #43 / Click pawn |
| Knowledge System | Implemented / verify current runtime (18 types) | F10 #44 |
| Myth Formation | Implemented / verify current runtime | F10 #45 |
| Knowledge Stones | Implemented / verify current runtime | F10 #46 / Right-click |
| Settlement Legends | Implemented / verify current runtime | F10 #72 |
| Chronicle View | Implemented / verify current runtime | F10 #71 |
| Legacy System | Implemented / verify current runtime | F10 #70 |
| Dynasty Tree | Implemented / verify current runtime | F10 #74 |
| Legacy Milestones | Implemented / verify current runtime | F10 #75 |
| Civilization Stage Lens | ✅ Initial live | F10 #03B / HUD |
| HeelKawnian Development Profiles | ✅ Initial live | F10 #49 |
| Incarnation Mode | ⚠️ Needs runtime truth pass | Press P |
| Event Notifications | ✅ Complete (clickable) | Automatic popups |

---

## 🎮 **QUICK START**

### **Windows**
```bash
# Clone repository
git clone https://github.com/PVAGR/HeelKawn1.git
cd HeelKawn1

# Open in Godot 4.6.2
# Run project from Godot editor
```

### **First 10 Minutes**
1. **Watch** - Let simulation run at 1x, observe pawns
2. **Speed up** - Press 3 (26x) for faster gameplay
3. **Click** - Select pawns, read narratives
4. **Wait** - Let first death occur, click notification
5. **Read** - See full biography
6. **F10** - Open menu, try #71, #72, #74, #75
7. **Press P** - Try incarnation mode
8. **Right-click stone** - When knowledge inscribed, read it

---

## 📊 **PROJECT STATUS**

HeelKawn should be described as a deep playable prototype with a stable kernel, active systems, and major v1 gaps still being consolidated. Older docs may use "complete" to mean "implemented as a file" or "planned by an AI session"; current docs should reserve complete for behavior that compiles, runs, and has a verification path.

**Current consolidation gates:**
- [ ] Runtime UI truth pass in Godot
- [ ] Lineage and child creation depth
- [ ] Skill tree branch effects
- [ ] Crafting resource consumption and tool requirements
- [ ] Chronicle/seed export
- [x] Civilization stage tracking from real world state (initial derived lens)
- [ ] Civilization stage deepening with institutions, literacy, lifespan, and per-settlement tech diffusion

---

## 🙏 **CREDITS & INSPIRATIONS**

**Influences:**
- *Dwarf Fortress* - Emergent storytelling, world simulation
- *RimWorld* - Pawn narratives, colony management
- *Crusader Kings* - Dynasty mechanics, succession
- *WorldBox* - Living world, civilization simulation
- *Kenshi* - Emergent gameplay, player as observer

**Core Philosophy:**
> *"Memory does not decay randomly. History does not lie. Persistence is earned strictly by impact."*

---

## 📞 **COMMUNITY & SUPPORT**

**Found a bug?** → Open GitHub issue  
**Want to share your dynasty?** → Screenshot F10 #72 or #74  
**Questions?** → Check [`docs/PLAYER_GUIDE.md`](docs/PLAYER_GUIDE.md)

---

## 📜 **LICENSE**

[Add your license here]

---

**HeelKawn is a "persistent myth engine" where every HeelKawnian tells a story, every settlement has legends, and knowledge is preserved in stone.**

**Build. Teach. Preserve. Leave your legacy.**
