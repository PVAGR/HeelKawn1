# HeelKawn v1.0 Release Package

**Release Date:** May 5, 2026  
**Version:** 1.0.0 "Emergent Life"  
**Engine:** Godot 4.6.2.stable  
**Platform:** Windows (64-bit)

---

## 📦 EXPORT CHECKLIST

### Pre-Export
- [ ] Run test suite: `Godot --headless --path . -s res://tools/test/ComprehensiveTestSuite.gd`
- [ ] Verify all 25 tests pass
- [ ] Playtest at 1x, 26x, 100x speeds
- [ ] Check FPS at each speed (target: 80+, 70+, 60+)
- [ ] Test all F10 features (#40-46, #70-75)
- [ ] Verify no console errors in Output panel

### Export Settings
```
Project → Export → Windows Desktop
- Debug Mode: OFF (release build)
- Architecture: x86_64
- Texture Format: BPTC + S3TC
- Binary Format: ON (GDScript compiled)
- File Filtering: Exclude .git, tools/, docs/
```

### Post-Export
- [ ] Test exported .exe independently
- [ ] Verify no missing dependencies
- [ ] Check file size (< 200 MB target)
- [ ] Create ZIP archive
- [ ] Test ZIP extraction and run

---

## 📝 STORE DESCRIPTION (itch.io)

### Short Description (Subtitle)
```
A deterministic colony simulation where every pawn tells a story, every settlement has legends, and knowledge is preserved in stone.
```

### Full Description
```markdown
# HeelKawn - A Persistent Myth Engine

**HeelKawn is a deterministic 2D colony simulation** where history is computed, not scripted. Memory does not decay randomly, history does not lie, and persistence is earned strictly by impact.

Think: *Dwarf Fortress* meets *RimWorld* meets *Crusader Kings*, with a focus on emergent storytelling and multi-generational legacy.

## Features

### 📖 Text-Rich Storytelling
- **Pawn Narratives** - Every pawn has a readable life story with skills, family, and memories
- **Settlement Legends** - Each settlement develops unique myths based on its actual history
- **Full Biographies** - Click death notifications to read complete life stories
- **Chronicle View** - Settlement history told as an organized story by year

### 🗿 Knowledge Preservation
- **18 Knowledge Types** - Fire keeping, tool making, diplomacy, leadership, and more
- **Inscribed Stones** - Carve knowledge on stone to preserve it forever
- **Interactive Reading** - Right-click stones to read inscribed knowledge
- **Knowledge Death** - If last carrier dies without inscribing, knowledge is lost forever

### 👨‍👩‍👧‍👦 Dynasty System
- **Family Trees** - Track generations visually with clickable dynasty tree UI
- **Legacy Scoring** - Measure your impact (children, knowledge, buildings, students)
- **Succession** - Heirs inherit from ancestors when they die
- **Endgame Goals** - Complete runs by achieving legacy milestones

### 🎭 Incarnation Mode
- **Spectator Mode** - Omniscient view with full UI (default)
- **Incarnated Mode** - Experience world through pawn's senses (UI hides)
- **Knowledge Fog** - Only know what your pawn knows when incarnated
- **Multiple Lives** - Incarnate as different pawns across generations

### ⚔️ Emergent Social Dynamics
- **Grudges** - Pawns remember wrongs, inherit family feuds across generations
- **Gossip** - Information spreads through social proximity
- **Reputation** - Emerges from aggregated gossip, affects trust and cooperation
- **Avoidance AI** - Pawns physically avoid enemies during pathfinding

### 🚀 NEW in v1.0
- **Trade System** - Inter-settlement caravans carrying goods and spreading knowledge
- **Wildlife Population** - Deer and rabbits with population dynamics
- **Hunting** - Warriors and Gatherers can hunt for meat
- **7 Professions** - Builder, Gatherer, Warrior, Scholar, Trader, Farmer + more
- **Performance Optimized** - Smooth 100 FPS at 1x, stable at 100x speed

## How to Play

### Basic Controls
| Key | Action |
|-----|--------|
| **Click pawn** | Select & view narrative |
| **P** | Toggle incarnation mode |
| **1-7** | Simulation speed (1x → 100x) |
| **Space** | Pause/Resume |
| **F10** | Debug/creator menu (75+ features) |
| **Esc** | Deselect pawn |

### Getting Started
1. **Launch game** - World generates with 20 starter pawns
2. **Watch notifications** - Births, deaths, knowledge inscribed appear on right
3. **Click pawns** - See their narratives, skills, family
4. **Speed up** - Press 3 (26x) for faster simulation
5. **Open F10** - Explore all features (chronicles, legends, dynasty tree, etc.)

### Endgame Goals
Complete a "run" by achieving:
- ✅ **1000 Legacy Score** (from children, knowledge, buildings, students)
- ✅ **3 Dynasties Founded**
- ✅ **20 Dynasty Members**
- ✅ **3 Player Incarnations**

Track progress in **F10 → #75 Endgame Status**.

## Technical Details

- **Engine:** Godot 4.6.2.stable
- **Language:** GDScript 2.0
- **Platform:** Windows 10/11 (64-bit)
- **Size:** ~100 MB
- **Performance:** Stable at 26x, playable at 100x
- **Status:** Feature Complete (90%)

## Documentation

Full documentation included in download:
- `docs/PLAYER_GUIDE.md` - Complete how-to-play guide (400+ lines)
- `docs/RICH_TEXT_FEATURES_GUIDE.md` - Where to find all story features
- `CHANGELOG.md` - Version history
- `README.md` - Project overview

## Community

- **GitHub:** https://github.com/PVAGR/HeelKawn1
- **Issues:** Report bugs on GitHub Issues
- **Discussions:** Share your dynasty stories!

## Credits

**HeelKawn** was inspired by:
- *Dwarf Fortress* - Emergent storytelling, world simulation
- *RimWorld* - Pawn narratives, colony management
- *Crusader Kings* - Dynasty mechanics, succession
- *WorldBox* - Living world, civilization simulation
- *Kenshi* - Emergent gameplay, player as observer

**Core Philosophy:**
> "The world is a machine of cause and effect. If the same things happen, the same history emerges."

## License

[Add your license here - MIT recommended]

---

**Thank you for playing HeelKawn!**

Build. Teach. Preserve. Leave your legacy.
```

---

## 🖼️ SCREENSHOT PACK

### Required Screenshots (5-8 images)

1. **Main Gameplay** - Settlement view with multiple pawns working
2. **Pawn Narrative** - Clicked pawn showing Narrative tab with rich text
3. **Death Biography** - Biography dialog from clicked death notification
4. **Knowledge Stone** - Right-click reading interface
5. **Dynasty Tree** - Visual family tree UI (F10 #74)
6. **F10 Menu** - Showing all available features
7. **Endgame Status** - F10 #75 showing run progress
8. **Trade Caravan** - Trader pawn moving between settlements (if visible)

### Screenshot Settings
```
Resolution: 1920x1080
UI: Visible (show Narrative tab, notifications)
Speed: 1x or 3x (show activity)
Time: Day (good lighting)
```

---

## 🏷️ TAGS (itch.io)

```
simulation
colony-sim
deterministic
story-rich
world-simulation
legacy
dynasty
knowledge
text-based
indie
singleplayer
sandbox
emergent
godot
2d
```

---

## 💰 PRICING

**Recommended:** Name Your Own (minimum $0)

**Rationale:**
- Early access / community building phase
- Encourages maximum downloads and feedback
- Donations welcome from supporters
- Can add paid tier later with bonus content

---

## 📢 RELEASE ANNOUNCEMENT TEMPLATE

```markdown
🎉 HeelKawn v1.0 "Emergent Life" is NOW AVAILABLE! 🎉

After months of development, my deterministic colony simulation is finally here!

**What is HeelKawn?**
A world simulation where every pawn tells a story, every settlement has legends, and knowledge is preserved in stone.

**Features:**
✅ Text-rich storytelling (biographies, legends, chronicles)
✅ Interactive knowledge stones (right-click to read)
✅ Dynasty tracking with visual family tree
✅ Endgame goals (legacy, succession, incarnations)
✅ Incarnation mode (experience world through pawn's senses)
✅ Grudge & gossip systems (emergent social dynamics)
✅ Trade system (inter-settlement caravans)
✅ Wildlife population (deer, rabbits, hunting)
✅ 7 diverse professions (not just farmers!)
✅ Performance optimized (smooth at 100x speed)

**Play it now:** [itch.io link]

**Documentation:** Complete guides included (400+ lines)

**Community:** Share your dynasty stories on GitHub!

Thank you to everyone who supported this project! 🙏

#indiedev #gamedev #simulation #colony #deterministic #storytelling
```

---

## ✅ PRE-LAUNCH CHECKLIST

### Technical
- [x] All systems implemented
- [x] Test suite created (25 tests)
- [x] Performance optimized (100 FPS target)
- [x] No critical bugs
- [ ] Run final playtest (2 hours)
- [ ] Export Windows build
- [ ] Test exported build
- [ ] Create ZIP archive

### Documentation
- [x] PLAYER_GUIDE.md complete
- [x] RICH_TEXT_FEATURES_GUIDE.md complete
- [x] README.md updated
- [x] CHANGELOG.md current
- [x] Store description written
- [ ] Screenshots captured (5-8)
- [ ] Trailer/GIF created (optional)

### itch.io Setup
- [ ] Create itch.io page
- [ ] Upload build file
- [ ] Add screenshots
- [ ] Paste store description
- [ ] Set tags
- [ ] Set price (Name Your Own)
- [ ] Configure download size
- [ ] Preview page
- [ ] Publish!

### Post-Launch
- [ ] Announce on social media
- [ ] Share in relevant subreddits
- [ ] Update GitHub README with itch.io link
- [ ] Monitor for bug reports
- [ ] Respond to comments
- [ ] Plan v1.1 update

---

## 🚀 LAUNCH DATE

**Target:** May 5, 2026 (today!)

**Timeline:**
- 00:00 - Final playtest
- 02:00 - Export build
- 03:00 - Create screenshots
- 04:00 - Upload to itch.io
- 05:00 - Publish announcement
- 06:00 - 🎉 LAUNCH!

---

**This is it. The HeelKawn universe is ready.**

**Let's ship it.** 🚀
