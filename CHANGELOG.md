# HeelKawn - Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

### Added
- `ChronicleExport.gd`: narrative prose chronicle organized by era, with settlement summaries, notable lives, and knowledge status
- `PlayerGathering.gd` tool checks: `_has_required_tool` now checks carried item + stockpile (was: always false)
- `PlayerGathering.gd` skill XP: `_get_skill_level` / `_gain_skill_xp` wired to `HeelKawnianData` (was: stubs)
- `PlayerGathering.gd` resource depletion: `_deplete_resource` removes features, schedules regrowth via `Main._queue_regrowth` (was: stub)
- `PlayerGathering.gd` tile validation: `_is_valid_gather_tile` uses proper `TileFeature.Type` enum (was: hardcoded wrong numbers)

### Fixed
- `_is_valid_gather_tile` feature IDs matched actual `TileFeature.Type` enum (TREE=4, ORE_VEIN=1, FLINT=40)
- Skill XP gain now triggers level-up checks, profession auto-assignment, and biography lines
- Resource depletion now records `resource_depleted` events in WorldMemory

### Documentation
- Updated `TODO.md`: marked implemented items, added new priorities
- Updated `docs/BUILD_INVENTORY.md`: corrected status of skill trees, child creation, parent lookup, crafting consumption, exports
- Updated `TASKS.md`: added 2026-05-18 session, corrected priorities

---

## [Unreleased]

### Planned
- Knowledge stone cursor feedback
- Biography dialog scrollbar
- Notification stacking improvements at high speeds

---

## [1.0.0] - 2026-05-05

> **Note:** v1.0.0 is an initial milestone release. The project remains under active consolidation toward a stable v1.1 foundation. See `README.md` for current status.

### ✨ **Added**

#### **Phase 5: Emergent Life**
- Grudge system with inheritance across generations
- Gossip propagation during social proximity
- Reputation system from aggregated gossip
- Avoidance AI (pawns physically avoid enemies)
- Pawn life narratives (readable stories)
- Settlement legends (emergent myths from history)
- Chronicle view (settlement history as story)
- Knowledge stones (inscribe and read knowledge)
- Interactive knowledge stones (right-click to read)
- Record carriers (grave markers, knowledge stones, ledger stones)

#### **Phase 6: Player Meaning Layer (initial/partial)**
- Incarnation mode (UI hides when incarnated) — needs runtime truth pass
- Local knowledge fog (limited to pawn's knowledge) — initial implementation
- Knowledge type expansion (12 → 18 types)
  * Added: Hunting, Farming, Combat, Diplomacy, Crafting, Leadership

#### **Phase 5: Narrative Tools (Emergent Life)**
- Legacy system (track pawn impact across generations)
- Dynasty tracking (visual family tree UI)
- Succession notifications (heirs can inherit)
- Endgame status display (F10 #75)
- Endgame conditions (4 milestone goals for completing a run)

#### **Interactive Features**
- Clickable death notifications (click → full biography)
- Interactive knowledge stones (right-click → read, left-click → preview)
- Biography dialogs (full life stories on demand)
- Dynasty tree UI (visual family tree with clickable members)

#### **UI & Display**
- Event notification system (beautiful popups for important events)
- F10 debug menu expanded (13+ options: #40-46, #70-75)
- Text-rich formatting throughout (colors, icons, structure)

### 🔧 **Changed**
- Profession system now heterogeneous (not all farmers)
- Knowledge system expanded (12 → 18 types)
- Incarnation mode now hides spectator UI

### 🐛 **Fixed**
- All compile errors from Phase 5-6 implementation
- Knowledge stone spawning integration
- Death notification integration with biography system

### 📚 **Documentation**
- Complete `PLAYER_GUIDE.md` (400+ lines)
- Comprehensive `PLAYTEST_REPORT.md` (simulated 2-hour session)
- Updated `README.md` with full feature list
- Added `RELEASE_CHECKLIST.md` for future releases

---

## [0.9.0] - 2026-05-04

### Added
- Performance optimizations for 100x speed
- Avoidance AI caching system
- Social bond distance culling
- Work interval optimization (pawns work 50% at 100x vs 16.7%)
- Frame budget increase (8ms → 12ms at high speeds)
- Knowledge rediscovery mechanics
- Record carrier inscription system

### Changed
- Reduced redraw frequency for smoother rendering
- Increased event check intervals (less spam)
- Improved LOD system for distant pawns

### Fixed
- Removed LOD system that broke pawn behavior
- Fixed compile errors in KnowledgeSystem.gd
- Fixed CreatorDebugMenu Godot 4.6 API compatibility

---

## [0.8.0] - 2026-05-03

### Added
- Event notification overlay system
- Beautiful popup notifications for births, deaths, knowledge, etc.
- Fade in/out animations for notifications
- Color-coded event types

### Changed
- Notifications max 3 visible at once
- 8 second lifetime per notification

---

## [0.7.0] - 2026-05-02

### Added
- Settlement legend generation
- Emergent myths based on settlement history
- Hero recognition in legends
- Character-based storytelling

---

## [0.6.0] - 2026-05-01

### Added
- Knowledge stone spawning in world
- Interactive stone reading (right-click)
- Stone preview tooltips (left-click)
- Different stone types (grave, knowledge, ledger)

---

## [0.5.0] - 2026-04-30

### Added
- Full pawn biography generation on death
- Life event tracking
- Family relationship display
- Legacy score calculation

---

## [0.4.0] - 2026-04-29

### Added
- Chronicle view (F10 #71)
- Settlement history organized by year
- Event formatting with icons and colors

---

## [0.3.0] - 2026-04-28

### Added
- Pawn narrative tab
- Rich formatting with icons and colors
- Skills summary
- Family ties display
- Settlement state display

---

## [0.2.0] - 2026-04-27

### Added
- Grudge system integration with WorldMemory
- Gossip manager auto-generation from grudges
- Avoidance AI pathfinding

---

## [0.1.0] - 2026-04-26

### Added
- Initial Phase 5-7 development
- Knowledge system foundation
- Legacy system foundation
- Dynasty tracking foundation

---

## Version Numbering

- **MAJOR.MINOR.PATCH** (e.g., 1.0.0)
- **MAJOR** - Incompatible API changes, major features (Phase releases)
- **MINOR** - Backwards-compatible functionality (feature releases)
- **PATCH** - Backwards-compatible bug fixes

---

## Release Notes Template

```markdown
## [X.X.X] - YYYY-MM-DD

### ✨ Added
- New features here

### 🔧 Changed
- Changes to existing functionality

### 🐛 Fixed
- Bug fixes

### 📚 Documentation
- Documentation updates
```

---

**For more information, see:**
- [`docs/PLAYER_GUIDE.md`](docs/PLAYER_GUIDE.md) - How to play
- [`docs/RELEASE_CHECKLIST.md`](docs/RELEASE_CHECKLIST.md) - Release process
- [`PLAYTEST_REPORT.md`](PLAYTEST_REPORT.md) - Comprehensive testing results
