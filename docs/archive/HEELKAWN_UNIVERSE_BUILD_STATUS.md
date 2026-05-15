# HEELKAWN Universe — Build Status & What's Still Needed

> Last comprehensive scan: 2026-04-30  
> Branch: main (merged PR #10)

---

## Part A: What IS Already Shipped ✅

### Core Kernel Systems ✅

| System | Files | Status |
|--------|-------|--------|
| **Deterministic World Tick** | `GodotManager.gd`, `WorldClock.gd` | Shipped |
| **WorldMemory (append-only facts)** | `autoloads/WorldMemory.gd` | Shipped |
| **WorldMeaning (derived tags)** | `autoloads/WorldMeaning.gd` | Shipped |
| **WorldPersistence (scars/ruins)** | `autoloads/WorldPersistence.gd` | Shipped |
| **SettlementSimulation** | `SettlementMemory.gd`, `SettlementPlanner.gd` | Shipped |
| **SettlementRebirth (revival rules)** | `SettlementRebirth.gd` | Shipped |
| **JobQueue + JobManager** | `JobManager.gd`, `Job.gd` | Shipped |
| **Pawn Behavioral AI** | `Pawn.gd`, `PawnData.gd` | Shipped |
| **Needs System** | `PawnData.gd` + `Pawn.gd` | Shipped |
| **Kinship/Family** | `KinshipSystem.gd` | Shipped |
| **SocialRapport (bond system)** | `PawnData.gd` (social_rapport) | Shipped |
| **Wildlife Emergent Ecology** | `AnimalSpawner.gd`, `AnimalPopulation.gd` | Shipped |
| **Cultural Architecture** | `SettlementPlanner.gd` | Shipped |

### Identity & Meaning (Phase 4) ✅ COMPLETE

| Feature | Status | Notes |
|---------|-------|-------|
| **Cultural Architecture Signatures** | ✅ Shipped | PERIM_R, DOOR2_MIN_SPAN, PEACE_TICKS |
| **Player-Readable Meaning Audio** | ✅ Shipped | `_trigger_meaning_audio_cue()` → `MeaningAudioCue` |
| **Settlement Identity Divergence** | ✅ Shipped | OPEN/CAUTIOUS/DEFENSIVE |
| **Revival Constraints** | ✅ Shipped | Scar/Peace/State/Cooldown/Collapse gates |
| **Profession Reassignment** | ✅ Shipped | Pawns change roles when non-primary skill outpaces primary |
| **Colony Role Balance** | ✅ Shipped | Diversity pressure dampens overrepresented professions |
| **Neural Bias at All Speeds** | ✅ Shipped | Gate moved from 50x to 200x |
| **Infrastructure Job Posting** | ✅ Shipped | Fire pit, storage hut, protect, defend in SettlementPlanner |
| **Warrior Peacetime Patrol** | ✅ Shipped | Visible perimeter presence instead of stockpile clustering |
| **Display Settings** | ✅ Shipped | Resolution, window mode, vsync in GameSettings |

### Emergent Life (Phase 5) 🔶 IN PROGRESS

| Feature | Status | Notes |
|---------|-------|-------|
| **Multi-generational grudges** | ❌ NOT | Social bonds don't persist beyond individuals |
| **Emergent social norms** | ❌ NOT | Norms are scripted, not emergent from behavior |
| **Reputation spread between settlements** | ❌ NOT | Reputation is local only |
| **Knowledge loss events** | ❌ NOT | Skills don't die with last carrier |
| **Teaching lineages** | ❌ NOT | No master→apprentice→master chains |
| **Record carriers** | ❌ NOT | No grave markers, carved stones preserving knowledge |
| **Pawn-driven law** | ❌ NOT | Taboos don't form from crisis response |
| **Myth formation** | ❌ NOT | Facts don't become legends over time |
| **Cultural drift** | ⚠️ Partial | CulturalStyleManager exists but doesn't drift autonomously |
| **World-memory-driven behavior** | ⚠️ Partial | Meaning tags exist but pawns don't react to them |

### Player Systems ✅

| Feature | Status | Notes |
|---------|-------|-------|
| **Player Pawn** | ✅ Shipped | `_player_pawn` in Main |
| **PlayerMode.INCARNATED** | ✅ Shipped | Full state machine |
| **Incarnation Picker UI** | ✅ Shipped | Region/life stage selection |
| **Player Controls** | ✅ Shipped | WASD + E + Backspace |
| **Save/Load Persistence** | ✅ Shipped | `player_mode` + `player_pawn_id` |

### Traits & Currency ✅

| Feature | Status | Notes |
|---------|--------|--------|
| **Trait Resource** | ✅ Shipped | `Trait.gd` with multipliers |
| **Trait Shop UI** | ✅ Shipped | TraitShop.gd |
| **Trait Persistence** | ✅ Shipped | Save/load via `to_dict()` |
| **Trait Effects** | ✅ Shipped | `get_trait_mult()` → stats |
| **Krond Currency** | ✅ Shipped | Debug grant (F3 hotkey) |

### Skills & Progression ✅

| Feature | Status |
|---------|--------|
| **Job XP System** | Shipped |
| **Profession Locking** | Shipped (now dynamic — pawns can reassign) |
| **Affinities/Liking Lanes** | Shipped |
| **Skill Trees (5/10/15/20)** | Shipped |
| **Mastery Perks** | Shipped |
| **Big Five Personality** | Shipped |
| **Utility-Based AI** | Shipped |

### Export & Tools ✅

| Feature | Status |
|---------|--------|
| **Chronicle Export (F7)** | Shipped |
| **Portable Character (F10→33)** | Shipped |
| **Soul Bundle (F10→32)** | Shipped |
| **World Seed Export** | Shipped |

### Spectator/Observer UI ✅

| Feature | Status |
|---------|--------|
| **Observer HUD** | Shipped |
| **Focus Inspector** | Shipped |
| **Pawn Info Panel** | Shipped |
| **ColonyHUD** | Shipped |
| **Map Modes** | Shipped |
| **Timeline Controls** | Shipped |

---

## Part B: What's NOT Shipped (Gap Analysis)

### TODOs in Codebase (Low Priority Stubs)

These are design placeholders, not blockers:

| File | Topic | Priority |
|------|-------|-----------|
| `Pawn.gd` | Tool requirement check | Low |
| `Pawn.gd` | Ground items | Low |
| `Pawn.gd` | Crafting | Low |
| `Pawn.gd` | Reproduction | Low |
| `KnowledgeSystem.gd` | Pawn lookup | Low |
| `TechnologySystem.gd` | Settlement neighbors | Low |

### Nice-to-Have (Not v1)

- Chronicle UI (export history panel) - Nice to have, not blocker
- Weather/disease - Already have exposure_sickness fields
- Advanced governance - Already have governance_profile stubs

### Long-Term / Deferred

- Full online/MMO networking
- Naval systems
- Taured/DRUJ/Ark canonical Age
- Large-scale city politics
- Full generational reincarnation

---

## Part C: Summary

| Category | Count |
|----------|-------|
| Systems shipped | ~45 |
| TODOs/stubs | ~6 |
| Blockers | 0 |

**Bottom line:** The HeelKawn kernel is **complete and playable**. Phases 0-4 are shipped. All major systems are shipped:
- Deterministic world simulation
- Full incarnation mode
- Trait effects integration
- Save/load persistence
- Export tools
- Profession reassignment and colony role balance
- Infrastructure and security job posting
- Warrior peacetime patrol
- Display settings

The next frontier is Phase 5 (Emergent Life): making NPCs live unpredictable, unique lives where the simulation produces stories worth telling without anyone authoring them.
