# HeelKawn Universe v1.0 Complete Roadmap

> Comprehensive implementation plan for reaching version 1.0 - a polished, promotable build

**Created:** 2026-04-30  
**Target:** v1.0 - Player-ready release  
**Based on:** BUILD_INVENTORY.md, HEELKAWN_STANDALONE_MASTER_PLAN.md

---

## Executive Summary

The HeelKawn kernel is solid and deterministic. The simulation runs well with ~45 systems shipped. Phases 0-4 are now **complete**. What remains for v1.0 is:

1. **Emergent Life** — Deep social dynamics, knowledge ecology, emergent narrative, world-memory-driven behavior
2. **Player Meaning Layer** — Knowledge fog, partial information, myth vs truth
3. **Performance** — Reduce SIM_HITCH from 25-55ms to <16ms (partially addressed)
4. **Content Polish** — Tutorial, save/load verification, clean .exe

---

## PHASE 0: Foundation Stabilization (Critical Path)

### Issues to Fix Now

| # | Issue | File | Current State | Fix Required |
|---|-------|------|---------------|--------------|
| 0.1 | Skill tree structure exists but bonuses not applied | `PawnData.gd` | Structure at levels 5/10/15/20 | Apply actual `_unlock_basic_skill_branch()`, `_unlock_advanced_skill_branch()`, `_unlock_mastery_skill_branch()` with working bonuses |
| 0.2 | Parent lookup returns null | `PawnData.gd` `_get_parent_data()` | TODO stub | Implement proper PawnManager lookup for lineage |
| 0.3 | Child spawning is placeholder | `Pawn.gd` `_spawn_child_pawn()` | TODO stub | Implement actual child pawn creation with inheritance |
| 0.4 | World seed export missing | `WorldMemory.gd`, `Main.gd` | No function | Add `export_world_seed(file_path)` function |
| 0.5 | Chronicle auto-summary | `WorldMemory.gd` | Manual F10 | Auto-generate readable summaries |

### Implementation Week 1

```gdscript
# PawnData.gd - Apply skill tree bonuses
func _unlock_basic_skill_branch() -> void:
    # Add work_speed_mult bonus
    skill_trees[primary_skill + "_basic"]["bonuses"]["work_speed_mult"] = 1.1
    # Apply to actual job calculation
    data.work_speed_multiplier *= 1.1

# PawnData.gd - Parent lookup
func _get_parent_data(parent_id: int) -> PawnData:
    if parent_id < 0:
        return null
    var pawn_manager = get_tree().get_first_node_in_group("pawn_manager")
    if pawn_manager:
        return pawn_manager.get_pawn_data(parent_id)
    return null
```

---

## PHASE 1: NPC Depth & Lineage

### Goal: Give NPCs real heritage and progression

### Features

| # | Feature | File | Priority | Dependencies |
|---|---------|------|----------|--------------|
| 1.1 | Full kinship system | `KinshipSystem.gd` | P0 | Phase 0.2 |
| 1.2 | Lineage display | `PawnData.gd` | P0 | 1.1 |
| 1.3 | Inheritance logic | `PawnData.gd` | P0 | 1.2 |
| 1.4 | Bloodline tracking | `BloodlineSystem.gd` | P1 | 1.3 |
| 1.5 | Household system | `Pawn.gd` | P1 | 1.1 |

### Implementation Week 2-3

```
1.1 KinshipSystem.gd
- Connect parent_id to actual PawnData
- Store children_count properly
- Implement get_children(), get_siblings()
- Add inheritance queries

1.2 Lineage Display
- Show parent's profession when viewing pawn
- Display lineage tree in Focus Inspector
- Add "born to [parent] of [profession]"

1.3 Inheritance Logic
- Pass affinities (scaled 0.5-1.5x) to children
- Pass known skills with decay
- Inherit starting profession preference
```

---

## PHASE 2: Player Incarnation Complete

### Goal: Full embodied player experience

### Current State

| # | Feature | Status | Gap |
|---|---------|--------|-----|
| 2.1 | Incarnation picker UI | ✅ Works | - |
| 2.2 | Player pawn assignment | ✅ Works | - |
| 2.3 | WASD movement | ✅ Works | - |
| 2.4 | Body needs (hunger/rest) | ⚠️ NPC only | Not applied to player |
| 2.5 | Local knowledge fog | ❌ NOT | Player sees all |
| 2.6 | Skill teaching | ⚠️ Partial | Needs polish |

### Implementation Week 4

```
2.4 Player Body Needs
- Apply needs system to _player_pawn
- When player_mode == INCARNATED, apply hunger/rest decay
- Show needs in HUD for player

2.5 Local Knowledge Fog
- When incarnated: hide settlement info, other pawn stats
- Only show what pawn could see (tile in perception radius)
- Spectator knowledge doesn't leak

2.6 Skill Teaching Polish
- Verify teaching with level 15+ pawns works
- Add teaching cooldown
- Track student progress
```

---

## PHASE 3: Crafting & Tools

### Goal: Physical interaction with world

### Features

| # | Feature | File | Priority | Dependencies |
|---|---------|------|----------|--------------|
| 3.1 | Tool requirements | `Pawn.gd` | P0 | Phase 0 |
| 3.2 | Ground items | `Pawn.gd` | P0 | 3.1 |
| 3.3 | Crafting system | `CraftingSystem.gd` | P1 | 3.2 |
| 3.4 | Material tracking | `StockpileManager.gd` | P1 | 3.3 |

### Implementation Week 5

```
3.1 Tool Requirements
- Check if pawn.has_tool_required(job_type)
- Add tool inventory to PawnData
- Jobs fail or slow without tools

3.2 Ground Items
- _check_for_items_on_ground() returns items
- Pick up with E key
- Drop with Q key

3.3 Crafting Integration
- Connect _consume_pawn_material() to stockpile
- Recipe system for basic items
- Tool requirement by recipe
```

---

## PHASE 4: Governance & Politics

### Goal: Social organization

### Features

| # | Feature | File | Priority | Dependencies |
|---|---------|------|----------|--------------|
| 4.1 | Governance forms | `SettlementMemory.gd` | P1 | Phase 2 |
| 4.2 | Leadership challenge | `Pawn.gd` | P1 | 4.1 |
| 4.3 | Law & custom | `SettlementMemory.gd` | P2 | 4.2 |
| 4.4 | Full factions | `FactionRegistry.gd` | P2 | 4.1 |

### Implementation Week 6

```
4.1 Governance Forms
- ELDER_COUNCIL, MILITIA_PROTECTORS, CHIEF_HOUSEHOLDS, COUNCIL_RULE
- Leader election by reputation/age/strength
- Governance affects settlement behavior

4.2 Leadership Challenge
- Challenge current leader (if allowed)
- Authority affects job assignment
- Reputation bonus for leaders
```

---

## PHASE 5: Knowledge & Technology

### Goal: Information propagation

### Features

| # | Feature | File | Priority | Dependencies |
|---|---------|------|----------|--------------|
| 5.1 | Knowledge propagation | `KnowledgeSystem.gd` | P2 | Phase 3 |
| 5.2 | Technology sharing | `TechnologySystem.gd` | P2 | 5.1 |
| 5.3 | Teaching expansion | `Pawn.gd` | P1 | Phase 2.6 |

---

## PHASE 6: Export & Sharing (Critical for Promotion)

### Goal: One-click exports for sharing/promotion

### Features

| # | Feature | File | Priority | Status |
|---|---------|------|----------|--------|
| 6.1 | World seed export | `WorldMemory.gd` | P0 | ❌ NOT |
| 6.2 | Chronicle export UI | `CharacterExport.gd` | P0 | ⚠️ Manual |
| 6.3 | Portable character | `CharacterExport.gd` | P1 | ✅ Works |
| 6.4 | Soul bundle | `CharacterExport.gd` | P1 | ✅ Works |

### Implementation Week 7

```
6.1 World Seed Export
func export_world_seed(file_path: String) -> bool:
    var export_data = {
        "schema": SCHEMA,
        "world_seed": WorldRNG.current_seed(),
        "export_tick": GameManager.tick_count,
        "calendar": { "year": year, "day": day },
        "settlements": SettlementMemory.get_snapshot(),
        "population": get_total_pawns()
    }
    # Write JSON to file_path

6.2 Chronicle Export UI
- Add "Export Chronicle" button to F10 menu
- Generate readable narrative summary
- Include major events, births, deaths, settlements
```

---

## PHASE 7: Performance Optimization

### Current Issues

| Issue | Evidence | Target |
|-------|----------|---------|
| SIM_HITCH 25-55ms | Log shows slow ticks | <16ms (60 FPS) |
| 100x speed lag | Ticks queuing | Smooth at 100x |

### Implementation Week 8

```
Performance Fixes:
1. Profile tick listeners - identify slowest
2. Reduce redundant checks in Main._game_tick()
3. Batch WorldMemory queries
4. Optimize PathFinder A* 
5. Add tick budget monitoring

Priority Order:
- Pawn AI (most expensive)
- Main listener
- Job assignment
- Memory indexing
```

---

## PHASE 8: Content Polish (Ready for Promotion)

### Features

| # | Feature | Priority |
|---|---------|-----------|
| 8.1 | Tutorial/intro flow | P0 |
| 8.2 | Save/load verification | P0 |
| 8.3 | Graphics polish | P1 |
| 8.4 | Sound/music pass | P1 |
| 8.5 | Build clean .exe | P0 |

### Implementation Week 9-10

```
8.1 Tutorial Flow
- First-time player intro
- Explain spectator mode
- Explain incarnation
- Show how to use controls

8.2 Save/Load Verification
- Test F5 save at multiple points
- Test load and verify state
- Test cross-session continuity

8.5 Build Clean .exe
- Remove debug prints in release
- Verify all autoloads load
- Test on clean machine
```

---

## Production Timeline

| Week | Phase | Milestone |
|------|-------|----------|
| 1 | Phase 0 | Foundation bugs fixed |
| 2-3 | Phase 1 | NPC lineage complete |
| 4 | Phase 2 | Incarnation polished |
| 5 | Phase 3 | Crafting working |
| 6 | Phase 4 | Governance basic |
| 7 | Phase 6 | Exports ready |
| 8 | Phase 7 | Performance optimized |
| 9-10 | Phase 8 | Polish & promotion prep |

**Total: ~10 weeks to v1.0**

---

## v1.0 Definition of Done

### Must Have

- [x] All skill trees working with bonuses
- [x] Parent lookup and child spawning
- [x] Full kinship system
- [x] Player incarnation with body needs
- [ ] Local knowledge fog
- [x] Tool requirements and ground items
- [x] Crafting material system
- [x] Governance forms
- [x] World seed export
- [x] Chronicle export
- [ ] SIM_HITCH <16ms at 1x
- [x] 100x speed runs smoothly
- [ ] Save/load verified
- [ ] Clean .exe builds

### Nice to Have (v1.0+)

- [x] Full faction system
- [x] Law & custom (AuthoritySystem, CollapseSystem)
- [x] Technology sharing (KnowledgeSystem, TechnologySystem)
- [ ] Tutorial flow
- [ ] Graphics polish

---

## Post-v1.0 (v2+)

From HEELKAWN_STANDALONE_MASTER_PLAN.md:
- Formal religion depth
- Advanced naval systems
- Deep metallurgy trees
- Large-scale city politics
- Sophisticated mounted warfare
- Full generational reincarnation
- Cross-world canon sync

---

## Hard Rule (From Master Plan)

Every feature must answer all four questions:

1. **What physical effect does it have?**
2. **What social effect does it have?**
3. **What memory trace does it leave?**
4. **What survives after the people involved are gone?**

If a system cannot answer those, it probably does not belong in HeelKawn.

---

## Short Pitch (For Promotion)

> HeelKawn is a single-player living world simulator where you first witness history as an outsider, then incarnate into it as a mortal human, and when you die the world keeps going to reveal whether anything you did actually lasted.

---

## Next Immediate Actions

1. **Today**: Apply skill tree bonuses in `PawnData.gd`
2. **Tomorrow**: Fix parent lookup in `PawnData.gd`
3. **This Week**: Implement child spawning, world seed export

---

*Last Updated: 2026-04-30*
*Based on: BUILD_INVENTORY.md, HEELKAWN_STANDALONE_MASTER_PLAN.md*
