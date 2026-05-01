# HEELKAWN Universe — Build Status & What's Still Needed

> Last comprehensive scan: 2026-04-30  
> Branch: main (git status shows staged changes pending commit)

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
| **Cultural Architecture Signatures** | ✅ Shipped | GLOSSARY docs constants (PERIM_R, DOOR2_MIN_SPAN, OPEN_VILLAGE_WALL, PEACE_TICKS per culture type) |
| **Player-Readable Meaning** | ⚠️ Partial | Audio cues (`autoloads/MeaningAudioCue.gd`) + spec doc (`docs/PLAYER_READABLE_MEANING_SPEC.md`) |
| **Settlement Identity Divergence** | ✅ Shipped | Open/Cautious/Defensive branch logic in `SettlementPlanner.gd` |
| **Revival Constraints** | ✅ Shipped | Scar/Peace/State/Cooldown/Collapse/RevivalScore gates in `SettlementRebirth.gd` + docs |

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
| **Skill Trees** | ⚠️ **IMPLEMENTED in this pass** (Level 5/10/15/20 branch unlocks now have actual logic, not stubs) |
| **Mastery Perks** | ⚠️ **STUB** — perks are granted but effect application has TODO |
| **Big Five Personality** | Shipped |
| **Deep Memory System** | Shipped |
| **Goal Hierarchy (Maslow)** | Shipped |
| **Utility-Based Decision Making** | Shipped |

### Trait & Krond System ⚠️

| Feature | Status | Notes |
|--------|--------|--------|
| **Trait Resource** | ⚠️ Basic | `resources/traits/` + `scripts/data/Trait.gd` exists |
| **Trait Shop UI** | ⚠️ Basic | `scripts/ui/TraitShop.gd` (basic shop script) |
| **Krond Currency** | ⚠️ Debug only | Debug grant via F3 hotkey |
| **Trait Effects Integration** | ❌ Not wired | Trait effects dict NOT applied to Pawn stats yet |

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
| **Player-Readable Meaning Audio** | 🟡 Medium | AudioCue autoload exists but hookup incomplete | Wire `MeaningAudioCue` into `Main.gd` tick → settlement meaning |
| **Trait Effect Application** | 🟡 Medium | Traits store but don't modify pawn stats | Wire `Pawn.apply_trait_effects()` into tick processing |
| **Full Chroncle UI** | 🟡 Medium | Export works, no browsing UI | Add export history panel |
| **Full Trait Persistence** | 🟡 Medium | Save/load not fully round-tripped | Resource path serialization |

### Medium Gaps (Nice to Have for v1)

| Gap | Severity | Current State |
|-----|----------|--------------|
| **Mastery Perk Effects** | 🟢 Low | Perks granted but bonus not applied |
| **Weather System** | 🟢 Low | Stub/deterministic placeholder only |
| **Disease/Illness** | 🟢 Low | Fields exist (exposure_sickness) but no mechanic |
| **Advanced Governance** | 🟢 Low | Stub in SettlementMemory |
| **Formal Religion System** | 🟢 Low | ReligionLens is read-only |

### Long-Term / deferred (Not in v1 Scope)

These are explicitly deferred per `docs/HEELKAWN_STANDALONE_MASTER_PLAN.md`:

- Full online/MMO networking
- Naval systems
- Taured/DRUJ/Ark canonical Age
- Large-scale city politics
- Full generational reincarnation

---

## Part C: Staged Feature TODOs (Found in Code)

From grep of `TODO|FIXME|STUB|placeholder`:

### PawnData.gd ⚠️ (This was fixed in this pass)

```gdscript
# WAS: TODO stubs at level 5/10/15/20 skill branch unlocks
# NOW: Full _unlock_basic_skill_branch(), _unlock_intermediate_skill_branch(), etc.
```

### Other TODOs in codebase:

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
| `scripts/ui/AIControlPanel.gd` | AI activation comment | N/A |

---

## Part D: Immediate Action Items (What's Next)

Per `docs/HEELKAWN_STATE.md` NEXT TARGET section and `docs/REPO_FEATURE_TODO.md`:

1. **Player-readable meaning refinement** (audio + settlement identity depth)
   - Status: spec complete (`docs/PLAYER_READABLE_MEANING_SPEC.md`)
   - Action: wire `MeaningAudioCue` into tick
2. **Wildlife HUD trend validation**
3. **Phase 4 rebirth threshold tuning**
4. **Trait persistence roundtrip** (save/load robust)
5. **Trait effect application** (wire into pawn tick)

---

## Part E: Universe Architecture Summary

The HeelKawn universe follows a **tiered simulation kernel**:

```
Layer 0: Deterministic World Kernel (TICK, SAVE, SEED)
    ↓ append-only facts → Layer 1: WorldMemory
Layer 1: Derived Meaning → Layer 2: WorldMeaning (tags)
Layer 2: Persistence → Layer 3: WorldPersistence (scars, ruins)
Layer 3: Agent Simulation → SettlementPlanner, PawnAI, JobQueue
Layer 4: Emergent Civilization → Settlement identity, kinship, reputation
Layer 5: Player Interaction → Observer HUD, exports, incarnation (future)
```

---

## Part F: Canon References

| Doc | Purpose |
|-----|---------|
| `docs/HEELKAWN_STATE.md` | **Sole authoritative state** |
| `HEELKAWN.txt` | Active changelog |
| `docs/HEELKAWN_STANDALONE_MASTER_PLAN.md` | Feature ordering for v1 |
| `docs/HEELKAWN_INFINITE_ARCHITECTURE.md` | Long-term blueprint |
| `docs/WORLD_BIBLE/GLOSSARY.md` | Canonical terms + legacy mapping |
| `docs/WORLD_BIBLE/CANON_SYSTEMS_FEATURE_QUEUE.md` | Execution queue (immediate + near-term) |
| `docs/WORLD_BIBLE/TIMELINE.md` | World history hooks |
| `docs/WORLD_BIBLE/CANON_CHANGELOG.md` | Canon change log |

---

## Part G: Summary

| Category | Count |
|----------|-------|
| Systems shipped (full) | ~35 |
| Systems partial | ~8 |
| Systems stub/missing | ~5 |
| TODOs to fix | ~15 |
| Feature specs documented | ~12 |

**Bottom line:** The HeelKawn kernel is solid and playable. The main gaps are:
1. Full incarnation mode (player-as-pawn)
2. Trait effect integration
3. Some polish on export/browse UI

All critical simulation logic is deterministic and reproducible. The remaining work is connecting hooks and UI polish.
