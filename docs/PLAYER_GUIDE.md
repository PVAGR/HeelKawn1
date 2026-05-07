# HeelKawn - Player's Guide

**Version:** 1.0 (Phase 5-7 Complete)  
**Genre:** Deterministic Colony Simulation / "Persistent Myth Engine"  

---

## 🎮 **WHAT IS HEELKAWN?**

HeelKawn is a **deterministic world simulation** where:
- Every pawn tells a story
- Every settlement has legends
- Knowledge is preserved in stone
- Your legacy spans generations

**Not a game to "win"** - it's a world to inhabit, observe, and leave your mark upon.

---

## 🎯 **HOW TO PLAY**

### **Basic Controls**
| Key | Action |
|-----|--------|
| **Click pawn** | Select & view info |
| **P** | Toggle incarnation mode |
| **1-7** | Change simulation speed (1x, 3x, 6x, 12x, 26x, 50x, 100x) |
| **Space** | Pause/Resume |
| **F10** | Open debug/creator menu |
| **Esc** | Deselect pawn |

### **Game Modes**

#### **Spectator Mode (Default)**
- Full UI visible (HUD, minimap, observer panels)
- Omniscient view of the world
- Can see all pawns, settlements, and events
- **Use this for:** Managing colonies, observing history, planning long-term

#### **Incarnation Mode (Press P)**
- **UI disappears** - you see through your pawn's eyes
- Limited knowledge (only what your pawn knows)
- Experience survival, needs, and relationships firsthand
- **Use this for:** Immersive roleplay, challenge runs, "survival mode"

> **Tip:** Incarnation feels like a DIFFERENT GAME. You lose god's-eye view and must navigate using only what your pawn can see and know.

---

## 📖 **KEY FEATURES**

### **1. Pawn Narratives**
Click any pawn → **Narrative tab** shows:
- Current activity with location
- Carrying status (items + destination)
- Skill levels
- Recent history (last 5 events)
- Family ties (parents, spouse, children)
- Legacy score

**Example:**
```
═══ XARA THE FARMER ═══
Age: 28.5 years | Level: 5 | Mood: Content

📍 CURRENTLY: Foraging at (145,89)
🎒 CARRYING: 3 berries → heading to stockpile
📊 SKILLS: Foraging 15, Building 3
📜 RECENT HISTORY: Completed foraging (2 min ago)
🏠 HOME: Ashwell Settlement (Active)
👨‍👩‍👧‍👦 FAMILY: 3 children | Child of Aldric & Brenna | Married
⭐ LEGACY SCORE: 245
```

### **2. Event Notifications**
Important events appear as **beautiful popups** on the right:
- 👶 **Births** (teal) - New pawn born
- ⚰ **Deaths** (red) - Pawn died (**click to read full biography**)
- 📜 **Knowledge Inscribed** (purple) - Stone carved
- 👑 **Succession** (gold) - Heir can inherit
- 🏗 **Buildings** (gold) - Structure completed

> **Pro Tip:** Click death notifications to see the pawn's complete life story!

### **3. Knowledge Stones**
When a pawn inscribes knowledge on stone:
- **Physical stone appears** in the world (blue sprite)
- **Right-click** → Read full inscription
- **Left-click** → Preview tooltip
- Knowledge persists even after inscriber dies

**What you'll see:**
```
═══ KNOWLEDGE STONE ═══
Inscribed by Aldric, 5 years ago

PRESERVED KNOWLEDGE:
  • Fire Keeping
  • Tool Making
  • Shelter Building

"Knowledge preserved, that it might not be lost."
```

### **4. Settlement Chronicles (F10 #71)**
Every settlement has a **readable history**:
```
═══ Ashwell Settlement ═══

Year 1:
  🏰 Ashwell Settlement was founded
  👶 Aldric was born
  📚 Taught foraging
  ⚰ Brenna died (old_age)

Year 2:
  👶 Cormac was born
  🏗 Built storage hut
```

### **5. Settlement Legends (F10 #72)**
Each settlement develops **emergent myths** based on its actual history:
- Knowledge-focused → "Beacon of wisdom"
- Building-focused → "Monument to perseverance"
- Friendship-focused → "Heart beats with friendship"
- Abandoned/Revived → "Like ember glowing in ash"

### **6. Dynasty Tree (F10 #74)**
Visual family tree showing:
- All generations
- Each member's name, profession, legacy score
- **Click any member** → Read their biography

### **7. Legacy Milestones (F10 #75)**
Track your "run" completion:
```
Legacy Score: 450 / 1000
Dynasties Founded: 1 / 3
Dynasty Members: 8 / 20
Player Incarnations: 0 / 3

OVERALL: 29.6% complete
```

**Complete all goals** to "finish" a run.

---

## 🎯 **ENDGAME CONDITIONS**

A "run" is complete when you achieve:
1. **1000 Legacy Score** (from children, knowledge, buildings, students)
2. **3 Dynasties Founded** (start 3 separate family lines)
3. **20 Dynasty Members** (descendants across all dynasties)
4. **3 Player Incarnations** (live as 3 different pawns)

**Progress tracked in F10 #75.**

---

## 🧠 **KNOWLEDGE SYSTEM**

### **18 Knowledge Types:**
1. Fire Keeping
2. Food Storage
3. Tool Making
4. Season Reading
5. Sickness Avoidance
6. Navigation
7. Shelter Building
8. Memory Preservation
9. Ruin Interpretation
10. Hospitality
11. Winter Survival
12. Teaching
13. **Hunting** *(NEW)*
14. **Farming** *(NEW)*
15. **Combat** *(NEW)*
16. **Diplomacy** *(NEW)*
17. **Crafting** *(NEW)*
18. **Leadership** *(NEW)*

### **How Knowledge Works:**
1. Pawns learn through teaching or experience
2. Knowledge dies if last carrier dies WITHOUT inscribing it
3. **Inscribe on stone** → Knowledge preserved forever
4. Other pawns can **read stones** to learn

> **Strategy:** Always inscribe important knowledge before pawns die!

---

## 🏆 **PROFESSIONS**

Pawns have 5 professions (assigned at spawn):

| Profession | % at Spawn | Priority Jobs |
|------------|------------|---------------|
| **Builder** | 20% | Build beds, walls, doors |
| **Gatherer** | 20% | Forage, chop wood |
| **Warrior** | 15% | Hunt, defend |
| **Scholar** | 10% | Teach, inscribe knowledge |
| **Farmer** | 35% | Forage, plant, harvest |

**Professions matter:** Pawns get +10 priority bonus for matching jobs.

---

## 📋 **F10 DEBUG MENU - COMPLETE LIST**

| # | Feature | What It Shows |
|---|---------|---------------|
| 40 | Grudges | All grudges & blood feuds |
| 41 | Gossip | Reputation & gossip propagation |
| 42 | Avoidance AI | Enemy avoidance patterns |
| 43 | Life Arcs | Readable pawn narratives |
| 44 | Knowledge Carriers | Who knows what |
| 45 | Myth Formation | Feared/revered regions |
| 46 | Record Carriers | All inscribed stones |
| 70 | Legacy & Dynasty | Legacy scores |
| 71 | Chronicle View | Settlement history as story |
| 72 | Settlement Legends | Emergent myths |
| 73 | Read Knowledge Stone | Read all stones |
| 74 | Dynasty Tree | Visual family tree |
| 75 | Legacy Milestones | Historical progress % |

---

## 💡 **TIPS FOR NEW PLAYERS**

### **Early Game (First 1000 Ticks)**
1. **Don't panic** - Let pawns work autonomously
2. **Watch for notifications** - Deaths, births, knowledge inscribed
3. **Click pawns** to see what they're doing
4. **Speed up to 26x** once you understand the flow

### **Mid Game (1000-10000 Ticks)**
1. **Inscribe knowledge** before important pawns die
2. **Encourage teaching** - creates knowledge carriers
3. **Watch dynasty grow** - F10 #74
4. **Try incarnation** (P) for immersive experience

### **Late Game (10000+ Ticks)**
1. **Check legacy milestone progress** - F10 #75
2. **Read settlement legends** - F10 #72
3. **Preserve knowledge** - stones outlive people
4. **Start new dynasties** if needed for legacy milestones

---

## 🐛 **KNOWN LIMITATIONS**

1. **Knowledge stones** may show colored rectangle instead of sprite (fallback art)
2. **Biography dialogs** can be long - working on scrollbar
3. **100x speed** may have frame drops during event bursts (still functional)
4. **Dynasty tree** generation estimation (not 100% accurate)

---

## 🎮 **HOW TO "WIN"**

There's no traditional "win" condition. Instead:

**Personal Goals:**
- Build a dynasty with 1000+ legacy
- Preserve 10+ knowledge types on stone
- Incarnate as 3+ different pawns
- See your settlement's legend after 50 years

**Community Goals:**
- Share interesting dynasty stories
- Create "challenge runs" (e.g., pacifist, scholar-only)
- Discover emergent stories the simulation creates

---

## 📞 **SUPPORT & COMMUNITY**

**Found a bug?** Report on GitHub issues.

**Want to share your dynasty's story?** Screenshot F10 #72 (legends) or #74 (dynasty tree).

**Questions?** Check this guide first, then ask in community discussions.

---

## 🙏 **CREDITS**

HeelKawn is a **deterministic colony simulation** inspired by:
- Dwarf Fortress (emergent storytelling)
- RimWorld (pawn narratives)
- Crusader Kings (dynasty mechanics)
- WorldBox (living world simulation)

**Core Philosophy:** *"The world is a machine of cause and effect. If the same things happen, the same history emerges."*

---

**Enjoy your time in HeelKawn. Build, teach, preserve, and leave your legacy.**
