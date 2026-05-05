# HEELKAWN — CHANGELOG

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

### Added
- **Phase 5: Emergent Life — Grudge System** (`autoloads/GrudgeManager.gd`)
  - Deterministic grudge tracking from WorldMemory events (harm, theft, betrayal, neglect, kin death)
  - Grudge inheritance: children remember wrongs done to parents (50% intensity, decays per generation)
  - Tick-based decay: minor grudges decay faster, blood feuds barely decay
  - Intensity thresholds: grudge (0.3), hatred (0.6), blood feud (0.85)
  - Integration with WorldMemory: automatic grudge generation from recorded events
  - Integration with KinshipSystem: grudge inheritance on pawn birth
  - Pawn AI integration: trust penalties, avoidance behavior, revenge seeking
  - Save/load support in Main.gd
  - F10 debug report: "40 · Grudge system" shows statistics and blood feuds
- **Phase 5: Gossip & Reputation System** (`autoloads/GossipManager.gd`, `scripts/social/GossipPropagation.gd`)
  - Gossip propagation during social proximity (pawns share news when near each other)
  - Grudge-based gossip: grudges automatically generate gossip that spreads through settlement
  - Reputation calculation: aggregate gossip sentiment creates pawn reputation (-1.0 to 1.0)
  - Reputation labels: Neutral, Good, Exemplary, Questionable, Notorious
  - Trust modifiers: pawns with bad reputation are trusted less, good reputation trusted more
  - Accuracy decay: gossip becomes less accurate as it spreads (0.1 per hop)
  - Importance levels: trivial, notable, serious, seismic (affects spread chance)
  - Save/load support in Main.gd
  - F10 debug report: "41 · Gossip & Reputation" shows active gossip and notorious pawns
- **Phase 5: Avoidance AI** (`scripts/pawn/Pawn.gd`)
  - Pathfinding avoidance: pawns path around tiles near grudge-enemies
  - Safe tile finding: if destination is near enemy, finds alternative nearby tile
  - Proximity stress: mood drain when forced near enemies (0.05-0.15 per tick based on distance)
  - Visual indicators: red lines connect pawns to their enemies (thickness = intensity)
  - F10 debug report: "42 · Avoidance AI" shows avoidance patterns and blood feuds
- Documentation: `docs/GRUDGE_SYSTEM.md` — full architecture, API, and design principles
- Documentation: `docs/GOSSIP_SYSTEM.md` — gossip propagation and reputation system

### Optimized (Performance)
- **GrudgeManager**: Decay runs every 10 ticks instead of every tick (10x reduction)
- **GossipManager**: Co-presence gossip sharing every 100 ticks instead of 50 (2x reduction)
- **Avoidance AI**: 
  - Enemy position caching per-tick (no repeated scans within same tick)
  - Limited enemy scans to first 3-5 enemies (was scanning all)
  - Safe tile search radius reduced from 6 to 5, with early exit
  - Visual enemy lines limited to top 3 by intensity (reduces draw calls)
- **Pawn.gd**: Early exits in gossip sharing when no gossip to share or trust too low

### Changed
- `WorldMemory.gd`: Added `_generate_grudges_from_event()` and `_on_event_appended()` hooks
- `KinshipSystem.gd`: `_flush_pending_births()` now calls `GrudgeManager.inherit_grudges()`
- `Pawn.gd`: Added grudge query functions (`get_grudge_toward`, `has_grudge_against`, etc.)
- `PawnData.gd`: `_calculate_social_factor()` applies grudge-based trust penalty
- `CreatorDebugMenu.gd`: Added grudge report button and handler
- `project.godot`: Registered GrudgeManager autoload

### Fixed
- DebugControlPanel.gd: Fixed Godot 4.6 compatibility - replaced deprecated `append_text()` with `text +=` for TextEdit logging
- Pawn.gd: Removed erroneous duplicate line in `_decay_needs()` that caused incorrect indentation and potential logic error (line 3907)
- Fixed remaining Pawn parser blockers so the class now reloads cleanly
- Cleaned up PawnData warning patterns and marked the unused tick parameter explicitly
- Restored `main` to the fullest verified historical snapshot (`cff67a5`)
- Fixed `PersistenceSystem` decay threshold ordering so older entities now decay more strongly than recently visited ones
- Fixed `SettlementRebirth.process()` so revival can proceed even when the world has zero living pawns

### Changed
- Added Phase 4 settlement lifecycle machine with deterministic abandoned, reviving, and permanent ruin states

### Added
- Settlement state machine semantics fix
- Documentation infrastructure (TASKS.md, CHANGELOG.md)
- Repository scan and status assessment
 - Lineage-based settlement revival naming: settlements revived by native-born pawns are now labeled `Continued <Name>`, otherwise `New <Name>`; events `settlement_revival_with_lineage` and `settlement_new_foundation` recorded to `WorldMemory`.

---

## [0.4.0] - 2026-05-02

### Current Session Focus
- Settlement state machine semantics fix
- Documentation infrastructure (TASKS.md, CHANGELOG.md)
- Repository scan and status assessment

---

## [0.3.0] - 2026-04-30

### Added
- ProgressionSystem kernel implementation with impact tiers (Unknown → Legendary)
- Cultural architecture signatures (PERIM_R, DOOR2_MIN_SPAN, PEACE_TICKS)
- Player-readable meaning audio cues via MeaningAudioCue
- Settlement revival constraints documentation (REVIVAL_CONSTRAINTS.md)
- Chronicle export functionality (F7)
- Portable character JSON export (F10→33)
- Soul bundle export (F10→32)

### Changed
- Compact UI refactor with tabbed PawnInfoPanel
- Performance intervalization for hot listeners
- Crisis response mechanism integrated into Pawn AI

### Fixed
- COPY DUMP functionality for inspect panel
- Neural AI integration stability

---

## [0.2.0] - 2026-04-15

### Added
- Neural AI integration (WorldAI matrix for pawn decision-making)
- Incarnation mode fully functional with region/life stage selection
- Save/load persistence for player state (player_mode + player_pawn_id)
- Trait system with shop UI and persistence
- Job XP system with profession locking
- Skill trees (5/10/15/20) with mastery perks
- Big Five personality traits
- Utility-based AI decision making
- Observer HUD with focus inspector
- Timeline controls
- Map modes

### Changed
- Settlement identity divergence (OPEN/CAUTIOUS/DEFENSIVE cultures)
- Revival constraints implementation (scar/peace/state/cooldown/collapse gates)

---

## [0.1.0] - 2026-03-01

### Added
- Deterministic world tick system (GodotManager.gd, WorldClock.gd)
- WorldMemory append-only fact logging
- WorldMeaning derived tag computation
- WorldPersistence scar/ruin tracking
- SettlementSimulation (SettlementMemory.gd, SettlementPlanner.gd)
- SettlementRebirth revival rules
- JobQueue + JobManager API
- Pawn behavioral AI with needs system
- Kinship/family system
- Social rapport bond system
- Wildlife emergent ecology
- Cultural architecture framework

### Core Systems Shipped
- Phase 0: Engine Survival ✅
- Phase 1: Living World Baseline (~85%) ✅
- Phase 2: The Kernel (~30%) 🔶
  - WorldMemory: 80% complete
  - WorldMeaning: Basic implementation
  - Persistence Rules: Partial

---

## Version History Summary

| Version | Date | Phase | Key Features |
|---------|------|-------|--------------|
| 0.4.0 | 2026-05-02 | Phase 4 | State machine fixes |
| 0.3.0 | 2026-04-30 | Phase 4 | Progression, cultural signatures |
| 0.2.0 | 2026-04-15 | Phase 4 | Incarnation mode, traits, skills |
| 0.1.0 | 2026-03-01 | Phase 1-2 | Core kernel systems |

---

## Upcoming (Phase 4-5)

### Kernel Stabilization
- Settlement state machine completion
- Deterministic state transition logging
- Validation harness for revival logic

### Identity & Meaning
- Lineage and family tree expansion
- Cultural memory inheritance
- Tradition decay over generations

### Observer Tools
- Timeline inspector for settlement history
- Chronicle log viewer UI
- Regional meaning heatmap

### Phase 5: Player Meaning Layer
- Partial information systems
- Myth vs truth mechanics
- Chronicler tools expansion
