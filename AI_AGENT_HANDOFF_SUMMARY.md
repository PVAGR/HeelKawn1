# HEELKAWN REPOSITORY ANALYSIS SUMMARY
**Generated:** May 23, 2026  
**Repository Scope:** 416 GDScript files, 53 scenes, ~79k lines of code  
**Engine:** Godot 4.6.2 | **Status:** Deep Playable Prototype (Not Release Candidate)

---

## 🎯 EXECUTIVE SUMMARY

HeelKawn is a **deterministic 2D colony simulation** and "persistent myth engine" where pawns have life stories, dynasties form, and knowledge is preserved on inscribed stones. The project has a **stable kernel** that passes headless smoke tests but requires runtime verification in Godot editor.

**Key Reality Check:** This is an ambitious, ongoing project with many implemented systems that need runtime validation. It is NOT a finished game. The codebase is large (150+ autoloads, though 35 already deregistered) with some systems fully functional, others partial/stubbed, and a few missing entirely.

---

## ✅ WHAT IS WORKING (Implemented, Needs Runtime Verification)

### Core Kernel Systems
- **WorldMemory** - Append-only factual history with dirty tracking
- **WorldMeaning** - Derived regional interpretation from world state
- **WorldPersistence** - Scars, ruins, abandonment, ironman saves
- **SettlementMemory** - Clustered regions → places, lifecycle machine (active/abandoned/reviving/ruin)
- **SettlementPlanner** - Autonomous pressure-driven construction
- **Pawn AI System** - Jobs, pathfinding, needs, skill trees, lineage
- **JobManager** - Job queue with dict compatibility adapter
- **StockpileManager** - Resource storage system
- **WorldRNG** - Seeded deterministic randomness
- **KnowledgeSystem** - 18 knowledge types, stone inscription, book crafting
- **GrudgeManager** - Persistent grudges with inheritance
- **GossipManager** - Information spread through proximity
- **SocialManager** - Rapport, reputation, household creation
- **DynastyFamilySystem** - Family trees, legacy scoring
- **MemorialSystem** - Sacred geography integration
- **CivilizationStage** - Initial live era derivation from world state (F10 #03B)
- **HeelKawnianManager** - Per-pawn development profiles with job-bias bridge (F10 #49)

### Recent Implementations (May 2026)
- **Matrix AI Behavior Wiring** - Profile-to-job-bias drives actual pawn work choices
- **Social Intent Bridge** - `social_seek`, `teach_seek`, `grudge_confront` autonomy
- **Settlement Ambition Seeding** - Strategic long-horizon job posting
- **Household Goal Planning** - Coordinated family objectives
- **Learning Target Biasing** - Pawns bias toward apprenticeship/teaching in target domains
- **Preservation Choice Wiring** - Knowledge preservation actions already integrated
- **Recovery Behavior Chains** - 5 new ambition chains for post-collapse rebuilding
- **Knowledge Preservation Loop** - Stones/books/teaching unified; lost/rediscovered mechanics
- **Knowledge Death Tracking** - `knowledge_truly_lost` vs `knowledge_degraded` events
- **CivilizationStage Penalty System** - Knowledge loss applies era score penalties
- **ChronicleExport** - Wired into F10 menu (#76)
- **Need-Driven Build Gating** - Settlement planner uses pressure + cooldowns + deduplication
- **Tool/Item Checks** - PlayerGathering validates tools, consumes resources, grants skill XP
- **Profession Reassignment** - Pawns can change roles when skills outpace profession
- **Colony Role Balance** - Diversity pressure prevents profession domination
- **Warrior Peacetime Patrol** - Visible perimeter presence
- **Mode Contract Enforcement** - WATCH/SPIRIT/OBSERVER mode gates working

### Export Systems
- World seed export (`world_seed.json`)
- Chronicle export (`chronicle.json`, `chronicle_summary.txt`)
- Bloodlines export (`bloodlines.json`)
- Artifacts export (`artifacts.json`)

---

## ❌ WHAT IS BROKEN/INCOMPLETE

### Critical Gaps (P0 - v1 Essential)
1. **Runtime Truth Pass NOT DONE** - No verification in Godot editor since May 7, 2026
   - UI panels may have red errors
   - F10 diagnostics unverified
   - OnboardingSystem fix needs runtime confirmation
   
2. **Incarnation Mode NOT IMPLEMENTED**
   - Player cannot enter world as pawn
   - No embodied control
   - No local knowledge fog
   - Player is OBSERVER only

3. **HeelKawnian Matrix AI - Partial**
   - Job-bias bridge: ✅ LIVE
   - Social intent: ✅ LIVE
   - Settlement ambition: ✅ LIVE
   - Household goals: ✅ LIVE
   - Learning targets: ✅ LIVE (May 23)
   - Preservation choices: ✅ VERIFIED (already wired)
   - Recovery behavior: ✅ LIVE (May 23 - 5 chain types)
   - **MISSING:** Longer-horizon ambitions beyond immediate settlement needs

4. **Knowledge Preservation Loop - Partial**
   - Stones/books/teaching: ✅ UNIFIED (May 22)
   - Lost/rediscovered mechanics: ✅ LIVE
   - Carrier tracking: ✅ LIVE
   - **MISSING:** Full literacy propagation, teaching mechanics depth

5. **Civilization Stage - Initial Only**
   - Basic era derivation: ✅ LIVE
   - **MISSING:** Per-settlement tech diffusion, literacy rates, lifespan metrics, institutions

### High Priority Gaps (P1)
6. **FactionRegistry - Prototype Only**
   - House-per-zone: ✅ WORKING
   - **MISSING:** CK3-style politics, diplomacy, inter-faction relations

7. **Governance & Law Systems - STUBS**
   - Governance forms: Stub ("governance_placeholder")
   - Law & custom: NOT IMPLEMENTED (no taboo system)
   - Diplomacy: NOT IMPLEMENTED (no messenger/treaty system)
   - Marriage rules: Random selection only
   - War campaigns: Stub only

8. **Religion & Metaphysics - STUBS**
   - ReligionLens: Read-only overlay (functional)
   - SacredMemory: Tile tracking (functional)
   - MythMemory: Region states (functional)
   - **MISSING:** Asha/DRUJ currents, echoes of dead, veil-aware sites, morality systems

9. **Lineage & Progression - Partial**
   - Parent lookup: ✅ LIVE
   - Child creation: ✅ LIVE with inheritance
   - Profession inheritance: ✅ LIVE
   - Skill trees: ✅ LIVE with bonus calculations
   - **MISSING:** Inheritance hooks (knowledge, reputation, grudges), skill tree branch effects UI

10. **Material Reality - Partial**
    - Crafting consumption: ✅ LIVE
    - Tool checks (player): ✅ LIVE
    - Skill XP (player): ✅ LIVE
    - Resource depletion: ✅ LIVE
    - **MISSING:** Tool requirements in all crafting paths, full resource consumption verification

### Medium Priority Gaps (P2)
11. **Trade & Travel - Stub**
    - TradePlanner exists but trade route logic stubbed
    - NO travel system implemented

12. **Conflict & Raids - Basic**
    - BattleReporter exists but effects on settlements not applied
    - EnemySpawner integration incomplete

13. **Export Import Cycle - Missing**
    - Export works: ✅
    - Import/world sharing: STUB (V2 feature)

14. **Timeline Scrubbing - NOT IMPLEMENTED**
    - Can pause/speed but no backward time travel

15. **Entity Watchlist - NOT IMPLEMENTED**

### Known Code Issues (TODOs in Source)
```gdscript
// AIAgentManager.gd
# TODO: Fix ObservationAPI initialization and re-enable

// BodyRiskManager.gd
# TODO: Re-enable when HeelKawnianData.Profession.HEALER is added

// PlayerBuilding.gd
# TODO: Implement proper skill system integration

// SettlementPlanner.gd
# TODO: check terrain moisture for crops

// HeelKawnianData.gd
# TODO: Apply perk effects (work speed bonus, quality bonus, etc.)

// ActionMenu.gd
# TODO: Implement notification system

// GuildUI.gd
# TODO: Implement proper player pawn tracking

// BattleReporter.gd
# TODO: Apply battle effects to nearby settlements

// CataclysmSystem.gd
# TODO: Integrate with EnemySpawner

// HeelKawnPawnBrain.gd
# TODO: When SpatialGrid is populated by PawnSpawner/CombatResolver...

// BloodlineSystem.gd
# TODO: Check cross-bloodline relations (marriage, etc.)

// TutorialHints.gd
# TODO: Social tracking (would need SocialManager)
```

---

## 🔧 PERFORMANCE & LAG ISSUES

### Identified Bottlenecks
1. **150+ Autoloads** (35 deregistered, 139 remaining)
   - Many autoloads are thin wrappers or stubs
   - Consolidation plan exists (5 phases) but not executed
   - Phase 1 alone would remove 10 autoloads (~287 LOC)

2. **High-Frequency System Ticks**
   - TickBudgetManager added (12ms budget coordinator)
   - Debug logs throttled in main tick path
   - Meaning throttle implemented
   - Social proximity now uses spatial grid (optimized)

3. **Known Optimization Work Done**
   - Redraw throttle added
   - Neural bias speed gate relaxed from 50x to 200x
   - Settlement-scoped build deduplication
   - Ambition seeding throttled per pawn/settlement

4. **Remaining Performance Concerns**
   - No CI for headless validation
   - No deterministic smoke tests (same seed → same output)
   - Large number of autoloads still active
   - Some systems tick every frame without throttling

---

## 📊 SYSTEM STATUS BREAKDOWN

### By Implementation Status

| Status | Count | Description |
|--------|-------|-------------|
| ✅ Verified Runtime Complete | ~45 | Compiled, runs, tested in Godot |
| 🟡 Implemented/Needs Verification | ~80 | Code exists, last verified May 7 |
| ⚠️ Partial/Prototype | ~35 | Functional but incomplete |
| ❌ Stub/Not Implemented | ~25 | File exists, mostly empty |
| 🔴 Missing Entirely | ~15 | Referenced but no file |

### By Feature Category

| Category | Completion | Notes |
|----------|-----------|-------|
| Deterministic Kernel | 95% | Core tick, memory, RNG solid |
| Pawn AI | 85% | Jobs, needs, skills, matrix AI live |
| Settlement Lifecycle | 90% | Birth/death/revival working |
| Knowledge System | 80% | Stones/books unified, teaching shallow |
| Social Dynamics | 75% | Grudges/gossip live, reputation basic |
| Dynasty/Legacy | 70% | Family trees work, inheritance partial |
| Civilization Stages | 40% | Initial lens live, depth missing |
| Governance/Politics | 15% | Mostly stubs |
| Religion/Metaphysics | 20% | Overlays work, currents missing |
| Incarnation Mode | 0% | Not implemented |
| Trade/Travel | 25% | Planner exists, routes stubbed |
| Combat/Raids | 30% | Basic systems, effects incomplete |

---

## 🎯 IMMEDIATE ACTION PLAN

### Phase 1: Runtime Verification (CRITICAL - Blocker)
**Must be done first before any other work:**
1. Open project in Godot 4.6.2 editor
2. Run game, verify no red errors in Output panel
3. Test all F10 diagnostic panels (#0-76)
4. Confirm HUD shows civilization stage correctly
5. Verify F10 #49 prints valid HeelKawnian profiles
6. Test OnboardingSystem RichTextLabel fix
7. Capture screenshot of clean runtime
8. Document any errors found

**Estimated Time:** 2-4 hours  
**Risk Level:** HIGH (may reveal cascading failures)

### Phase 2: Critical Bug Fixes
After runtime verification:
1. Fix ObservationAPI initialization in AIAgentManager
2. Add HEALER profession to HeelKawnianData
3. Implement skill system integration in PlayerBuilding
4. Complete terrain moisture check in SettlementPlanner
5. Apply perk effects in HeelKawnianData
6. Wire battle effects to settlements in BattleReporter
7. Integrate EnemySpawner in CataclysmSystem

**Estimated Time:** 8-16 hours  
**Risk Level:** MEDIUM

### Phase 3: Autoload Consolidation (Performance)
Execute the 5-phase consolidation plan:
- **Phase 1:** Remove 10 thin wrapper autoloads (~287 LOC)
- **Phase 2:** Convert 18 stub/vision autoloads to regular scripts (~2,250 LOC)
- **Phase 3:** Comment out 27 V2 systems (~7,300 LOC)
- **Phase 4:** Merge 16 duplicate autoloads (~2,100 LOC)
- **Phase 5:** Lazy-load 14 UI autoloads (~2,800 LOC)

**Total Reduction:** 85 autoloads, ~14,737 LOC  
**Estimated Time:** 12-20 hours  
**Risk Level:** MEDIUM (verify smoke tests after each phase)

### Phase 4: Missing v1 Features
Priority order:
1. **Incarnation Mode Foundation** - Player pawn entry, basic control
2. **Knowledge Teaching Mechanics** - Deepen apprentice/master relationships
3. **Civilization Stage Depth** - Literacy rates, tech diffusion, institutions
4. **Faction Politics** - Inter-faction relations, diplomacy basics
5. **Skill Tree Branch UI** - Visual choices for specialization

**Estimated Time:** 40-60 hours  
**Risk Level:** HIGH (new feature development)

### Phase 5: Polish & Optimization
1. Add deterministic smoke tests
2. Set up CI for headless Godot validation
3. Profile and optimize remaining bottlenecks
4. Complete tool requirement system
5. Verify all resource consumption paths
6. Add inheritance hooks (knowledge, reputation, grudges)

**Estimated Time:** 20-30 hours  
**Risk Level:** LOW

---

## 📁 KEY FILES TO REVIEW

### Architecture & Orientation
- `docs/HEELKAWN_PROJECT_COMPASS.md` - North star, truth hierarchy
- `docs/HEELKAWN_BLUEPRINT.md` - Full PSUni blueprint
- `docs/HEELKAWN_STATE.md` - Current working state (UPDATED May 23)
- `docs/BUILD_INVENTORY.md` - Honest built-vs-missing inventory
- `AI_README.md` - Core philosophy, forbidden patterns
- `TODO.md` - Active work tracking

### Core Systems
- `autoloads/WorldMemory.gd` - Factual history append-only
- `autoloads/WorldMeaning.gd` - Derived interpretation
- `autoloads/SettlementMemory.gd` - Lifecycle machine
- `autoloads/HeelKawnianManager.gd` - Matrix AI brain
- `scripts/pawn/HeelKawnian.gd` - Pawn behavior
- `autoloads/JobManager.gd` - Job queue system
- `autoloads/KnowledgeSystem.gd` - Knowledge preservation
- `autoloads/CivilizationStage.gd` - Era derivation

### Known Problem Files
- `autoloads/AIAgentManager.gd` - ObservationAPI disabled
- `autoloads/BodyRiskManager.gd` - HEALER missing
- `autoloads/PlayerBuilding.gd` - Skill integration TODO
- `autoloads/SettlementPlanner.gd` - Crop logic incomplete
- `scripts/ui/ActionMenu.gd` - Notification system missing
- `scripts/ui/GuildUI.gd` - Player tracking TODO

---

## 🚨 CRITICAL WARNINGS

1. **DO NOT TRUST OLD DOCUMENTATION** - Many docs say "DONE" meaning "file created", not "verified working". Always check:
   - `docs/BUILD_INVENTORY.md` for current status
   - Source code for actual implementation
   - Runtime verification in Godot

2. **GODOT RUNTIME REQUIRED** - Cannot verify anything without Godot 4.6.2 editor. Headless smoke tests pass but don't catch UI/runtime errors.

3. **AMBITION VS REALITY GAP** - This is an extremely ambitious project ( Dwarf Fortress × RimWorld × Crusader Kings × persistent myth engine). Many systems are partial implementations of grand designs.

4. **PERFORMANCE UNKNOWN** - No profiling data available. Lag complaints plausible given 150+ autoloads and complex simulation. Consolidation critical.

5. **INCARNATION MODE IS THE BIGGEST GAP** - Core vision includes player incarnation, but it's 0% implemented. This is a v1 requirement per master plan.

6. **KNOWLEDGE LOOP PARTIAL** - May 2026 work unified stones/books but teaching mechanics remain shallow. Full preservation loop needs depth.

---

## 💡 RECOMMENDATIONS FOR AI AGENT COLLABORATION

### For Your AI Agent:
1. **Start with Runtime Verification** - Nothing else matters until we know what actually runs
2. **Use Truth Hierarchy** - Code > BUILD_INVENTORY > STATE > COMPASS > BLUEPRINT > old docs
3. **Focus on P0/P1 Items** - Don't get distracted by V2 features
4. **Test Incrementally** - Verify each change in Godot before proceeding
5. **Document Rigorously** - Update STATE.md and BUILD_INVENTORY.md after each session
6. **Respect Kernel Philosophy** - Deterministic, pawn-activated, no random decay (see AI_README.md)

### Collaboration Workflow:
```
You (User) ↔ Your AI Agent ↔ Me (External Analyst)
     ↓              ↓              ↓
  Decision      Implementation   Verification
  Priority      & Coding         & Documentation
```

**Suggested Cadence:**
1. Your AI Agent implements fixes/features
2. You test in Godot, report results
3. I analyze gaps, suggest next priorities
4. Repeat

---

## 📞 NEXT STEPS

**Immediate (Today):**
1. Copy this summary to your AI agent
2. Have agent review key orientation docs
3. Plan runtime verification session
4. Schedule Godot testing time

**This Week:**
1. Complete Phase 1 (Runtime Verification)
2. Begin Phase 2 (Critical Bug Fixes)
3. Start Phase 3 (Autoload Consolidation)

**This Month:**
1. Finish Phases 1-3
2. Begin Phase 4 (Missing v1 Features)
3. Establish CI/testing pipeline

---

## 📊 METRICS SUMMARY

- **Total GDScript Files:** 416
- **Total Scenes:** 53
- **Lines of Code:** ~79,000
- **Autoloads (Active):** 139 (was 150+)
- **Autoloads (Deregistered):** 35
- **TODO Comments:** 20+ critical, 40+ total
- **Stub Systems:** ~25
- **Verified Complete:** ~45 systems
- **Implementation Date Range:** 2024-2026 (most recent: May 23, 2026)
- **Last Runtime Verification:** May 7, 2026 (OUTDATED)

---

**Bottom Line:** HeelKawn has an impressive foundation with many sophisticated systems implemented, but it requires immediate runtime verification and has significant gaps in v1-critical features (especially incarnation mode). The codebase is ambitious and complex, requiring careful, incremental validation. Performance optimization through autoload consolidation is essential before adding more features.

**Contact Points:** 
- State of Truth: `docs/HEELKAWN_STATE.md`
- Reality Check: `docs/BUILD_INVENTORY.md`
- Philosophy: `AI_README.md`
- Active Work: `TODO.md`
