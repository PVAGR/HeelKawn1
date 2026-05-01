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

### Skills & Progression (Phase 1-3) ⚠️

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
| **Full Incarnation Mode** | 🔴 High | Player is observer only | Need: actual playerpawn spawn, body, camera-bind, UI input routing |
| **Full Chronicle UI** | 🟡 Medium | Export works, no browsing UI | Add export history panel |
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

1. **Full Incarnation Mode** - Player-as-pawn spawning
2. **Chronicle UI** - Export history panel
3. **Trait persistence** - Save/load roundtrip

---

## Part E: Summary

| Category | Count |
|----------|-------|
| Systems shipped (full) | ~38+ |
| Systems partial | ~5 |
| Systems stub/missing | ~3 |
| TODOs to fix | ~8 |

**Bottom line:** The HeelKawn kernel is solid and playable. Main gaps are:
1. Full incarnation mode (player-as-pawn)
2. Some polish on export/browse UI
3. Trait persistence refinement
