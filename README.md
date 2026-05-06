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
- ✅ A **story generator** where every pawn has a life story
- ✅ A **legacy builder** where knowledge outlives its carriers
- ✅ A **deterministic simulation** where same inputs = same history
- ✅ An **ongoing project** — always evolving, never complete

**Think:** Dwarf Fortress meets RimWorld meets Crusader Kings, with a focus on emergent storytelling and multi-generational legacy.

---

## 🚧 **CURRENT STATUS**

| Metric | Status |
|--------|--------|
| **Current Phase** | Phase 5 - Emergent Life |
| **Overall Progress** | ~90% complete |
| **Kernel Health** | 🟢 Stable |
| **Last Updated** | May 5, 2026 |
| **Shipped Systems** | 45+ |

**What Works Now:**
- ✅ Full pawn AI with needs, skills, professions (5 diverse roles)
- ✅ Settlement lifecycle (active → abandoned → reviving)
- ✅ Knowledge system (18 types, inscribe on stones, read them)
- ✅ Grudge & gossip systems (emergent social dynamics)
- ✅ Legacy & dynasty tracking (multi-generational)
- ✅ Text-rich storytelling (biographies, legends, chronicles)
- ✅ Performance optimized (stable at 100x speed)

**What's Next:**
- 🔶 Trade system (inter-settlement caravans)
- 🔶 Wildlife population (hunt-able animals)
- 🔶 Polish pass (incarnation UI, F10 organization)

**See full plan:** [`docs/MASTER_DEVELOPMENT_PLAN.md`](docs/MASTER_DEVELOPMENT_PLAN.md)

---

## 🏆 **KEY FEATURES**

### **📖 Text-Rich Storytelling**
- **Pawn Narratives** - Every pawn has a readable life story
- **Settlement Legends** - Each settlement develops unique myths
- **Chronicle View** - Settlement history told as a story
- **Full Biographies** - Click death notifications to read complete life stories

### **🗿 Knowledge Preservation**
- **18 Knowledge Types** - Fire keeping, tool making, diplomacy, leadership, and more
- **Inscribed Stones** - Carve knowledge on stone to preserve it forever
- **Interactive Reading** - Right-click stones to read inscribed knowledge
- **Knowledge Death** - If last carrier dies without inscribing, knowledge is lost forever

### **👨‍👩‍👧‍👦 Dynasty System**
- **Family Trees** - Track generations visually
- **Legacy Scoring** - Measure your impact (children, knowledge, buildings, students)
- **Succession** - Heirs inherit from ancestors
- **Endgame Goals** - Complete runs by achieving legacy milestones

### **🎭 Incarnation Mode**
- **Spectator Mode** - Omniscient view with full UI
- **Incarnated Mode** - Experience world through pawn's senses (UI hides)
- **Knowledge Fog** - Only know what your pawn knows
- **Multiple Lives** - Incarnate as different pawns across generations

### **⚔️ Emergent Social Dynamics**
- **Grudges** - Pawns remember wrongs, inherit family feuds
- **Gossip** - Information spreads through proximity
- **Reputation** - Emerges from aggregated gossip
- **Avoidance AI** - Pawns physically avoid enemies

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

### **Endgame Goals**
Complete a "run" by achieving:
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
| [`docs/HEELKAWN_STATE.md`](docs/HEELKAWN_STATE.md) | **AUTHORITATIVE STATE** - Current phase, blockers, next tasks |
| [`docs/MASTER_DEVELOPMENT_PLAN.md`](docs/MASTER_DEVELOPMENT_PLAN.md) | **COMPREHENSIVE PLAN** - Full system inventory, roadmap |
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

1. **READ FIRST:** [`docs/HEELKAWN_STATE.md`](docs/HEELKAWN_STATE.md) - This is the authoritative source for current status
2. **THEN READ:** [`docs/MASTER_DEVELOPMENT_PLAN.md`](docs/MASTER_DEVELOPMENT_PLAN.md) - Full context and roadmap
3. **QUICK CONTEXT:** [`HEELKAWN.txt`](HEELKAWN.txt) - What we're working on right now
4. **PRINCIPLES:** [`AI_README.md`](AI_README.md) - Core kernel philosophy (NON-NEGOTIABLE)

**Key Principles:**
- **Deterministic Kernel:** History is computed, not scripted. Same inputs = same history.
- **Pawn-Activated:** Events trigger from pawn actions, NOT global timers.
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
**Status:** Feature Complete (98%)  
**Performance:** Stable at 26x, playable at 100x  

### **Current Phase:** Phase 5-7 Complete
- ✅ Phase 5: Emergent Life (grudges, gossip, narratives, legends)
- ✅ Phase 6: Player Meaning Layer (incarnation, knowledge fog)
- ✅ Phase 7: Endgame (dynasty tree, succession, legacy goals)

### **Features Implemented:**
| System | Status | Access |
|--------|--------|--------|
| Grudge System | ✅ Complete | F10 #40 |
| Gossip & Reputation | ✅ Complete | F10 #41 |
| Avoidance AI | ✅ Complete | F10 #42 |
| Pawn Narratives | ✅ Complete | F10 #43 / Click pawn |
| Knowledge System | ✅ Complete (18 types) | F10 #44 |
| Myth Formation | ✅ Complete | F10 #45 |
| Knowledge Stones | ✅ Complete (interactive) | F10 #46 / Right-click |
| Settlement Legends | ✅ Complete | F10 #72 |
| Chronicle View | ✅ Complete | F10 #71 |
| Legacy System | ✅ Complete | F10 #70 |
| Dynasty Tree | ✅ Complete | F10 #74 |
| Endgame Goals | ✅ Complete | F10 #75 |
| Incarnation Mode | ✅ Complete | Press P |
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

```
Phase 0-4: ████████████████████ 100% ✅
Phase 5:   ████████████████████ 100% ✅
Phase 6:   ████████████████████ 100% ✅
Phase 7:   ████████████████████ 100% ✅

Overall:   ████████████████████ 98% COMPLETE
```

**Remaining (Minor):**
- [ ] Knowledge stone cursor feedback
- [ ] Biography dialog scrollbar
- [ ] Notification stacking polish

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

**HeelKawn is a "persistent myth engine" where every pawn tells a story, every settlement has legends, and knowledge is preserved in stone.**

**Build. Teach. Preserve. Leave your legacy.**
