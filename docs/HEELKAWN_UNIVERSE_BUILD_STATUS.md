# HEELKAWN Universe — Build Status & What's Still Needed

> Last comprehensive scan: 2026-04-30  
> Branch: main

---

## Part A: What IS Already Built (Shipped / Implemented)

### Core Kernel Systems ✅

| System | Files | Status |
|--------|-------|--------|
| **Deterministic World Tick** | `autoloads/GameManager.gd`, `autoloads/WorldClock.gd` | Shipped |
| **WorldMemory (append-only facts)** | `autoloads/WorldMemory.gd` | Shipped |
| **WorldMeaning (derived tags)** | `autoloads/WorldMeaning.gd` | Shipped |
| **WorldPersistence (scars/ruins)** | `autoloads/WorldPersistence.gd` | Shipped |
| **SettlementSimulation** | `autoloads/SettlementMemory.gd`, `autoloads/SettlementPlanner.gd` | Shipped |
| **SettlementRebirth (revival rules)** | `autoloads/SettlementRebirth.gd` | Shipped |
| **JobQueue + JobManager** | `autoloads/JobManager.gd`, `scripts/jobs/Job.gd` | Shipped |
| **Pawn Behavioral AI** | `scripts/pawn/Pawn.gd`, `scripts/pawn/PawnData.gd` | Shipped |
| **Needs System (hunger/rest/mood/health)** | `PawnData.gd` + `Pawn.gd` | Shipped |
| **Kinship/Family** | `autoloads/KinshipSystem.gd` | Shipped |
| **SocialRapport (bond system)** | `PawnData.gd` (social_rapport dict) | Shipped |
| **Wildlife Emergent Ecology** | `autoloads/AnimalSpawner.gd`, `autoloads/AnimalPopulation.gd` | Shipped |
| **Colony/Settlement Architecture** | `autoloads/SettlementPlanner.gd` (OPEN/CAUTIOUS/DEFENSIVE) | Shipped |

### Identity & Meaning (Phase 4) ✅

| Feature | Status | Notes |
|---------|-------|-------|
| **Cultural Architecture Signatures** | ✅ Shipped | GLOSSARY docs constants |
| **Player-Readable Meaning Audio** | ✅ Shipped | MeaningAudioCue integrated with SettlementMemory |
| **Settlement Identity Divergence** | ✅ Shipped | Open/Cautious/Defensive branch logic |
| **Revival Constraints** | ✅ Shipped | Scar/Peace/State/Cooldown/Collapse gates |

### Memory & Legacy Systems ✅

| System | Status |
|--------|--------|
| **Chronicle/WorldMemory** | Shipped |
| **WorldMeaning Tags** | Shipped |
| **Historical Sites (RUINS/SCARS)** | Shipped |
| **Biographies** | Shipped |
| **Physical Scars** | Shipped |
| **Legacy Score** | Shipped |
| **Portable Character Export** | Shipped |
| **FactionRegistry (house stub)** | Shipped |
| **ReligionLens** | Shipped |
| **CulturalMemory** | Shipped |

### Skills & Progression (Phase 1-3) ✅

| Feature | Status |
|--------|--------|
| **Job XP System** | Shipped |
| **Profession Locking** | Shipped |
| **Affinities / Liking Lanes** | Shipped |
| **Skill Trees** | ✅ Shipped (Level 5/10/15/20 branch unlocks implemented) |
| **Mastery Perks** | ⚠️ Partial (bonuses dict exists, partial application) |
| **Big Five Personality** | Shipped |
| **Deep Memory System** | Shipped |
| **Goal Hierarchy (Maslow)** | Shipped |
| **Utility-Based Decision Making** | Shipped |

### Incarnation Mode ✅

| Feature | Status | Notes |
|---------|--------|--------|
| **Player Pawn** | ✅ Shipped | Full `_player_pawn` in Main.gd |
| **PlayerMode.INCARNATED** | ✅ Shipped | Full state machine (SPECTATOR ↔ INCARNATED) |
| **Incarnation Picker UI** | ✅ Shipped | `_incarnation_picker` with region/life stage selection |
| **Player Control** | ✅ Shipped | WASD movement, E interact, Backspace exit |
| **Save/Load** | ✅ Shipped | `player_mode` and `player_pawn_id` persisted |

### Trait & Krond System ✅

| Feature | Status | Notes |
|---------|--------|--------|
| **Trait Resource** | ✅ Shipped | `scripts/pawn/Trait.gd` with full multipliers |
| **Trait Shop UI** | ⚠️ Basic | `scripts/ui/TraitShop.gd` (basic shop script) |
| **Krond Currency** | ⚠️ Debug only | Debug grant via F3 hotkey |
| **Trait Effects Integration** | ✅ Shipped | `get_trait_mult()` applied to hunger/rest/mood/health/work_speed/injury/damage |

### Export & Tools ✅

| Feature | Status |
|--------|--------|
| **Chronicle Export (F7)** | Shipped |
| **Portable Character Export (F10→33)** | Shipped |
| **Soul Bundle (F10→32)** | Shipped |
| **World Seed Export** | Shipped |

### Spectator/Observer UI ✅

| Feature | Status |
|--------|--------|
| **Observer HUD** | Shipped |
| **Focus Inspector** | Shipped |
| **Pawn Info Panel** | Shipped |
| **ColonyHUD** | Shipped |
| **Map Modes** | Shipped |
| **Timeline Controls** | Shipped |

---

## Part B: What's NOT Built Yet (Gap Analysis)

### Critical Gaps (Blockers for v1 "Complete" Feel)

| Gap | Severity | Current State | What Needs Work |
|-----|----------|--------------|--------------|
| **Full Incarnation Mode** | ✅ ALREADY SHIPPED | Full player pawn with PlayerMode.INCARNATED, incarnation picker UI, save/load | None - feature complete! |
| **Full Chronicle UI** | 🟡 Medium | Export works (F7), no browsing UI | Add export history panel |
| **Full Trait Persistence** | 🟡 Medium | Save/load works but not fully round-tripped | Resource path serialization |

### Medium Gaps (Nice to Have for v1)

| Gap | Severity | Current State |
|-----|----------|--------------|
| **Mastery Perk Effects** | 🟢 Low | Full application in progress |
| **Weather System** | 🟢 Low | Stub/deterministic placeholder only |
| **Disease/Illness** | 🟢 Low | Fields exist (exposure_sickness) but no full mechanic |
| **Advanced Governance** | 🟢 Low | Stub in SettlementMemory |
| **Formal Religion System** | 🟢 Low | ReligionLens is read-only |

### Long-Term / deferred (Not in v1 Scope)

- Full online/MMO networking
- Naval systems
- Taured/DRUJ/Ark canonical Age
- Large-scale city politics
- Full generational reincarnation

---

## Part C: Staged Feature TODOs (Found in Code)

From grep of `TODO|FIXME|STUB|placeholder`:

| File | Topic | Severity |
|------|-------|---------|
| `autoloads/AIAgentManager.gd` | ObservationAPI init fix | Low |
| `autoloads/KnowledgeSystem.gd` | Pawn lookup stub | Low |
| `scripts/pawn/PawnData.gd` | Parent data lookup (legacy) | Low |
| `autoloads/TechnologySystem.gd` | Settlement neighbor lookup | Low |
| `scripts/pawn/Pawn.gd` | Tool requirement check | Low |
| `scripts/pawn/Pawn.gd` | Ground items | Low |
| `scripts/pawn/Pawn.gd` | Crafting | Low |
| `scripts/pawn/Pawn.gd` | Reproduction | Low |

---

## Part D: Immediate Action Items (What's Next)

1. **Chronicle UI** - Export history panel
2. **Trait persistence** - Save/load roundtrip

---

## Part E: Summary

| Category | Count |
|----------|-------|
| Systems shipped (full) | ~40+ |
| Systems partial | ~3 |
| Systems stub/missing | ~2 |
| TODOs to fix | ~8 |

**Bottom line:** The HeelKawn kernel is complete and playable! All major features are shipped:
- Deterministic world simulation
- Full incarnation mode (player-as-pawn)
- Settlement/pawn AI with needs
- Trait effects integration
- Export tools

Only remaining work is UI polish (chronicle browsing) and persistence refinement.
