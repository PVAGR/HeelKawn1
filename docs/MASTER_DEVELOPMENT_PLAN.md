# HeelKawn Master Development Plan

**Generated:** May 5, 2026  
**Current Phase:** Phase 5 - Emergent Life  
**Status:** 90% Complete - Polish & Integration Phase

---

## 🎯 EXECUTIVE SUMMARY

**HeelKawn** is a deterministic colony simulation where history is computed, not scripted. The kernel is **COMPLETE** with 45+ shipped systems. All critical blockers resolved. Current focus: polish, integration, and player experience.

---

## 📊 SYSTEM STATUS OVERVIEW

### ✅ **COMPLETE SYSTEMS** (No Work Needed)

| System | Status | Files | Notes |
|--------|--------|-------|-------|
| **Deterministic Kernel** | ✅ Complete | WorldMemory, WorldMeaning, WorldPersistence | Core philosophy implemented |
| **Pawn System** | ✅ Complete | Pawn.gd, PawnData.gd, PawnSpawner.gd | Full AI, needs, skills, professions |
| **Profession Heterogeneity** | ✅ Complete | PawnSpawner.gd | 5 professions with weighted spawn |
| **Job System** | ✅ Complete | Job.gd, JobManager.gd | Claim/work/haul pipeline |
| **Settlement Memory** | ✅ Complete | SettlementMemory.gd | Active/abandoned/reviving states |
| **Knowledge System** | ✅ Complete | KnowledgeSystem.gd | 18 knowledge types, inscribing |
| **Grudge System** | ✅ Complete | GrudgeManager.gd | Inherited feuds |
| **Gossip System** | ✅ Complete | GossipManager.gd | Reputation spread |
| **Legacy System** | ✅ Complete | LegacySystem.gd | Multi-generational tracking |
| **Dynasty Tree UI** | ✅ Complete | DynastyTreeUI.gd | Visual family tree |
| **Event Notifications** | ✅ Complete | EventNotificationOverlay.gd | Clickable popups |
| **Pawn Biographies** | ✅ Complete | WorldMemory.gd | Full life stories on death |
| **Settlement Legends** | ✅ Complete | SettlementLegend.gd | Emergent myths |
| **Knowledge Stones** | ✅ Complete | KnowledgeStone.gd | Right-click to read |
| **Narrative Tab** | ✅ Complete | PawnInfoPanel.gd | Real-time pawn stories |
| **Performance Optimizations** | ✅ Complete | Multiple | Adaptive throttling |

---

### 🔶 **NEEDS POLISH** (Minor Work)

| System | Issue | Priority | Effort |
|--------|-------|----------|--------|
| **Incarnation Mode** | UI hides but needs visual feedback | Medium | 2 hours |
| **Local Knowledge Fog** | Partial implementation | Medium | 4 hours |
| **Succession Mechanics** | Notification exists, inheritance needs work | Low | 3 hours |
| **F10 Menu Organization** | 75+ options, needs categorization | Low | 1 hour |

---

### ❌ **MISSING/INCOMPLETE** (Future Phases)

| Feature | Phase | Priority | Effort |
|---------|-------|----------|--------|
| **Trade System** | Phase 4 | High | 8 hours |
| **Wildlife Population** | Phase 4 | Medium | 4 hours |
| **Combat System** | Phase 5 | Low | 12 hours |
| **Magic System** | Phase 6 | Low | 16 hours |
| **Full Endgame** | Phase 7 | Medium | 8 hours |

---

## 🎮 PLAYER EXPERIENCE FLOW

### **First 5 Minutes (New Player)**
```
1. Game launches → 20 pawns spawn with diverse professions
2. Player clicks pawn → Sees Narrative tab with story
3. Event notifications appear (births, work completions)
4. Player presses F10 → Discovers 75+ debug features
5. First pawn dies → Biography prints, notification appears
6. Scholar inscribes knowledge → Blue stone spawns
7. Player right-clicks stone → Reads full inscription
```

### **First Hour (Engaged Player)**
```
1. Settlement grows → Legends emerge (F10 #72)
2. Grudges form → Blood feuds between families
3. Dynasty tree visible (F10 #74)
4. Player incarnates (P key) → UI hides, immersion increases
5. Knowledge spreads → Stones read, knowledge preserved
6. Endgame goals visible (F10 #75)
```

---

## 📁 FILE ORGANIZATION

### **Core Autoloads** (Load Order Critical)
```
autoloads/
├── GameManager.gd          # Game speed, pause, tick management
├── WorldMemory.gd          # Event storage (THE SOURCE OF TRUTH)
├── WorldMeaning.gd         # Event significance
├── WorldPersistence.gd     # Save/load
├── SettlementMemory.gd     # Settlement states
├── KnowledgeSystem.gd      # Knowledge types & carriers
├── LegacySystem.gd         # Multi-generational tracking
├── GrudgeManager.gd        # Grudges & feuds
├── GossipManager.gd        # Reputation spread
└── ... (120+ autoloads)
```

### **Key Scripts**
```
scripts/
├── pawn/
│   ├── Pawn.gd             # Main pawn logic (6700+ lines)
│   ├── PawnData.gd         # Pawn data container (3300+ lines)
│   └── PawnSpawner.gd      # Spawning & professions
├── ui/
│   ├── PawnInfoPanel.gd    # Right-side info panel
│   ├── EventNotificationOverlay.gd  # Popup notifications
│   ├── DynastyTreeUI.gd    # Family tree window
│   └── CreatorDebugMenu.gd # F10 menu (2600+ lines)
├── world/
│   ├── KnowledgeStone.gd   # Interactive stones
│   └── SettlementLegend.gd # Legend generation
└── ...
```

### **Documentation**
```
docs/
├── HEELKAWN_STATE.md       # Current authoritative state
├── PLAYER_GUIDE.md         # How to play (400+ lines)
├── RICH_TEXT_FEATURES_GUIDE.md  # Where features are
├── RELEASE_CHECKLIST.md    # itch.io workflow
└── ...
```

---

## 🚀 IMMEDIATE ACTION PLAN (Next 7 Days)

### **Day 1-2: Trade System** (HIGH PRIORITY)
```
Files to modify:
- autoloads/TradeMemory.gd (create)
- autoloads/TradePlanner.gd (enhance)
- scripts/jobs/Job.gd (add TRADE jobs)

Features:
- Inter-settlement trade routes
- Caravan spawning
- Resource exchange
- Trade-based knowledge spread
```

### **Day 3-4: Wildlife Population** (MEDIUM PRIORITY)
```
Files to modify:
- scripts/world/AnimalPopulation.gd (enhance)
- scripts/pawn/Pawn.gd (add hunting jobs)
- autoloads/FoodChainManager.gd (integrate)

Features:
- Deer, rabbits spawn in biomes
- Pawns can hunt for food
- Population dynamics (birth/death)
- Impact on food supply
```

### **Day 5-7: Polish Pass** (LOW PRIORITY)
```
Tasks:
- Incarnation UI feedback (show current mode)
- F10 menu reorganization (group by phase)
- Knowledge fog visual indicator
- Succession inheritance mechanics
- Performance profiling at 100x
```

---

## 📈 METRICS & SUCCESS CRITERIA

### **Technical Metrics**
| Metric | Target | Current | Status |
|--------|--------|---------|--------|
| FPS at 1x | 60 | 60-70 | ✅ |
| FPS at 26x | 40+ | 50-60 | ✅ |
| FPS at 100x | 30+ | 35-45 | ✅ |
| Event volume | <100/tick | ~40/tick | ✅ |
| Memory usage | <500MB | ~300MB | ✅ |

### **Player Experience Metrics**
| Metric | Target | Measurement |
|--------|--------|-------------|
| Time to first story | <2 min | Pawn narrative tab |
| Time to first death | <10 min | Biography appears |
| Time to first legend | <30 min | F10 #72 shows myth |
| Feature discoverability | 80%+ | F10 usage tracking |

---

## 🎨 VISUAL IDENTITY

### **Current State**
- Procedural pixel pawns (colored circles with details)
- Knowledge stones (colored rectangles: blue/gray/tan)
- Event notifications (emoji + colored borders)
- No custom sprites yet

### **Future Needs** (Post-1.0)
- Custom pawn sprites
- Building sprites
- Terrain tiles
- UI icons
- Particle effects

---

## 🔧 TECHNICAL DEBT

### **Known Issues**
1. **Pawn.gd is 6700+ lines** - Should be split into components
2. **CreatorDebugMenu.gd is 2600+ lines** - Needs modularization
3. **No unit tests** - Manual testing only
4. **No automated builds** - Manual export process

### **Refactoring Priorities**
1. Split Pawn.gd into components (AI, movement, rendering, needs)
2. Create test suite for core systems
3. Set up CI/CD pipeline
4. Add performance profiling tools

---

## 📝 GIT WORKFLOW

```bash
# Standard workflow
git add -A
git commit -m "fix: [description]"  # Or "feat:", "perf:", "docs:"
git pull --rebase origin main
git push

# Release workflow
git tag v1.0.0
git push origin v1.0.0
# Export build → Upload to itch.io
```

---

## 🎯 LONG-TERM VISION (Post-1.0)

### **Phase 8: Multiplayer** (Future Product)
- LAN co-op
- Hot-seat mode
- Online asynchronous

### **Phase 9: Modding Support**
- JSON configuration
- Custom events
- Script hooks

### **Phase 10: Commercial Release**
- Steam deployment
- Achievement system
- Cloud saves
- Workshop support

---

## 📞 COMMUNICATION

### **For AI Assistants**
- Read `docs/HEELKAWN_STATE.md` for current status
- Check `HEELKAWN.txt` for immediate context
- Use `F10 → 35 · Backbone / first-play` to verify live systems

### **For Human Collaborators**
- `README.md` - Project overview
- `docs/PLAYER_GUIDE.md` - How to play
- `CHANGELOG.md` - Version history

---

## ✅ CHECKLIST FOR 1.0 RELEASE

- [ ] All Phase 5 systems complete
- [ ] Trade system implemented
- [ ] Wildlife population working
- [ ] Performance stable at 100x
- [ ] No critical bugs
- [ ] Documentation complete
- [ ] itch.io page ready
- [ ] Trailer/screenshot pack
- [ ] Community guidelines
- [ ] Support channel setup

---

**This document is living. Update as systems are completed.**

**Last Updated:** May 5, 2026  
**Next Review:** May 12, 2026
