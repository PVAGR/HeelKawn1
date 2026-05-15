# 🔗 Cross-Track Integration Contract

**Document:** CROSS-001 — System Integration Map  
**Date:** May 6, 2026  
**Author:** Qwen Code (TRACK 5 → TRACK 6 handoff)

---

## 📋 Purpose

This document maps how all development tracks integrate with each other. Ensures future AI work maintains system coherence and doesn't break existing integrations.

**Tracks Covered:**
- TRACK 1: UI Integration & Testing
- TRACK 2: Performance Optimization
- TRACK 3: World Richness (Memorial System)
- TRACK 4: System Polish (Grudge/Gossip)
- TRACK 5: Building/Crafting UI
- TRACK 6: Knowledge Systems (remaining)

---

## 🗺️ System Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                        PLAYER-FACING UI                         │
│  (TRACK 1 + TRACK 5)                                            │
│  - SurvivalHUD (hunger, thirst, temp, health)                  │
│  - Inventory (I key)                                            │
│  - BuildingToolbar (B key) → 9 building types                  │
│  - CraftingMenu (C key) → 6 tool recipes                       │
│  - MemorialInscription (click memorial)                        │
│  - PawnInfoPanel (select pawn) → Consciousness tab             │
└─────────────────────────────────────────────────────────────────┘
                              ↕
┌─────────────────────────────────────────────────────────────────┐
│                      CORE SIMULATION LAYER                      │
│  (TRACK 3 + TRACK 4 + TRACK 6)                                  │
│  - MemorialSystem ←→ GrudgeManager (closure)                   │
│  - MemorialSystem ←→ GossipManager (gatherings)                │
│  - MemorialSystem ←→ SacredGeography (density → significance)  │
│  - PawnConsciousness ←→ Pawn.gd (pilgrimage AI)                │
│  - KnowledgeSystem ←→ RecordCarriers (inscribed stones)        │
│  - WorldMemory (append-only event log)                         │
└─────────────────────────────────────────────────────────────────┘
                              ↕
┌─────────────────────────────────────────────────────────────────┐
│                    PERFORMANCE LAYER (TRACK 2)                  │
│  - SacredGeography tile cache (95% call reduction)             │
│  - Pathfinding cache (70-80% call reduction)                   │
│  - Adaptive visual throttling (game speed scaling)             │
│  - Event significance filtering (WorldMemory)                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 🔌 Integration Points by Track

### TRACK 1 (UI Testing) → Other Tracks

**Dependencies:**
| UI Component | Depends On | Integration Point |
|--------------|------------|-------------------|
| SurvivalHUD | SurvivalSystem.gd | Reads `pawn.data.hunger`, `thirst`, `body_temperature` |
| PlayerInventory | PlayerGathering.gd | Reads `player_inventory` dictionary |
| PawnInfoPanel | PawnConsciousness.gd | Calls `get_awareness_level()`, `get_trauma_level()`, `get_dreams()`, `get_memories()` |
| MemorialInscription | MemorialSystem.gd | Calls `get_memorial_at_tile()`, shows inscription |
| BuildingToolbar | PlayerBuilding.gd | Calls `place_[building_type]()`, deducts resources |
| CraftingMenu | PlayerGathering.gd | Checks inventory, deducts resources, adds crafted item |

**Testing Checklist:** `TESTING_CHECKLIST.md` (created May 6, 2026)

**Breaks If:**
- Autoload names change
- Data structure keys change (e.g., `pawn.data.hunger` → `pawn.data.needs.hunger`)
- Method signatures change without backward compatibility

---

### TRACK 2 (Performance) → Other Tracks

**Optimizations Applied:**
| Optimization | Affects | Savings |
|--------------|---------|---------|
| SacredGeography tile cache | Pawn.gd `_process()` | 95% fewer calls |
| Pathfinding cache | Pawn.gd pathfinding | 70-80% fewer calls |
| Visual frame throttling | Pawn.gd `_process()` | 67-98% fewer updates |
| Event significance filter | WorldMemory.gd | Reduces event spam |

**Integration Rules:**
1. All caches must invalidate correctly (on tile change, on target change)
2. Throttling must scale with game speed (`GameManager.game_speed`)
3. Performance optimizations cannot change behavior (only frequency)

**Breaks If:**
- Cache invalidation logic removed
- Throttling constants hardcoded (must scale with game speed)
- Event filter thresholds changed without testing

---

### TRACK 3 (Memorial System) → Other Tracks

**Files:**
- `autoloads/MemorialSystem.gd` (~500 lines)
- `autoloads/SacredGeography.gd` (~300 lines)
- `scripts/pawn/Pawn.gd` (PILGRIMAGE state, ~50 lines added)
- `autoloads/WorldMemory.gd` (auto-create on events, ~80 lines added)

**Integration Points:**
| System | How Memorial Integrates |
|--------|------------------------|
| WorldMemory | Auto-creates memorials on `pawn_death`, `battle`, `settlement_founded`, `disaster_event` |
| SacredGeography | Calculates tile significance from memorial density (1-2=remembered, 3-4=sacred, 5+=holy_ground) |
| Pawn.gd | Pilgrimage AI (pawns visit family/grudge/profession memorials when idle) |
| GrudgeManager | Grudge closure when pawn visits enemy's memorial (30% chance for graves, less for mass graves) |
| GossipManager | Gossip spreads 2x faster at memorial gatherings (3+ pawns at tile) |
| UI (MemorialInscription) | Clickable inscriptions, F10 report #47 |

**Breaks If:**
- `MemorialSystem` autoload not loaded before Pawn.gd ticks
- `WorldMemory._on_event_appended()` disconnected
- SacredGeography tile cache not invalidated on memorial creation

---

### TRACK 4 (Grudge/Gossip) → Other Tracks

**Files:**
- `autoloads/GrudgeManager.gd` (~100 lines added for memorial integration)
- `autoloads/GossipManager.gd` (~80 lines added for memorial integration)

**Integration Points:**
| System | How Grudge/Gossip Integrates |
|--------|------------------------------|
| MemorialSystem | Grudge closure on memorial visit (50% intensity reduction) |
| MemorialSystem | Gossip spreads at gatherings (2x chance when 3+ pawns at memorial) |
| Pawn.gd | Avoidance AI (pawns path around enemies with high grudges) |
| WorldMemory | Grudges only form from recorded events (Facts First principle) |

**Breaks If:**
- Grudge closure logic removed from MemorialSystem tick
- Gossip spread chance hardcoded (must be 2x at gatherings)
- Event significance filter blocks grudge-forming events

---

### TRACK 5 (Building/Crafting UI) → Other Tracks

**Files:**
- `scenes/ui/BuildingToolbar.tscn`
- `scripts/ui/BuildingToolbar.gd` (~250 lines)
- `scenes/ui/CraftingMenu.tscn`
- `scripts/ui/CraftingMenu.gd` (~200 lines)

**Integration Points:**
| System | How Building/Crafting Integrates |
|--------|----------------------------------|
| PlayerBuilding.gd | BuildingToolbar calls `place_[type]()`, deducts resources |
| PlayerGathering.gd | CraftingMenu reads `player_inventory`, deducts resources, adds crafted items |
| Main.tscn | Both UI components added to UI_Viewport |
| Input handling | `B` key toggles BuildingToolbar, `C` key toggles CraftingMenu |

**Breaks If:**
- `PlayerBuilding.BUILDING_CONFIG` keys change (button names won't match)
- `PlayerGathering.player_inventory` structure changes
- Resource icons dictionary not updated with new items

---

### TRACK 6 (Knowledge Systems) → Other Tracks

**Status:** ⏳ NOT YET STARTED

**Planned Integration Points:**
| System | How Knowledge Will Integrate |
|--------|------------------------------|
| KnowledgeSystem.gd | Existing autoload (inscribed stones, teaching) |
| RecordCarriers | Stones preserve knowledge (grave markers, knowledge stones, ledger stones) |
| PawnConsciousness | Knowledge affects consciousness (learning = growth) |
| MemorialSystem | Knowledge carriers can be listed on memorials ("Here lies the last master of X") |
| UI (planned) | Knowledge carrier panel (who knows what per settlement) |
| UI (planned) | "Last carrier" alerts (when master dies untaught) |

**Files to Create/Modify:**
- `scripts/ui/KnowledgePanel.tscn` (knowledge carriers per settlement)
- `scripts/ui/KnowledgePanel.gd` (display logic)
- `autoloads/KnowledgeSystem.gd` (may need "last carrier" tracking)
- `AI_TODO_QUEUE.md` TRACK 6 section

**Design Constraints:**
- Knowledge is fragile (can be lost forever if carrier dies untaught)
- Knowledge spreads through teaching (PawnConsciousness growth)
- Knowledge preserved in stones (RecordCarriers)
- Player only sees knowledge their pawn has learned (knowledge fog)

---

## 🧪 Cross-Track Testing Flow

**Example: Testing Memorial + Grudge Integration**

1. **Setup:** Let pawn die (creates grave via WorldMemory → MemorialSystem)
2. **Trigger:** Enemy pawn visits grave (Pilgrimage AI)
3. **Check:** Grudge intensity reduced by 50% (GrudgeManager closure)
4. **Verify:** F10 → 47 shows memorial count + sacred geography stats

**Example: Testing Building + Knowledge Integration (Future)**

1. **Setup:** Player crafts Flint Knife (CraftingMenu)
2. **Trigger:** Player teaches pawn knife-making (KnowledgeSystem teaching)
3. **Check:** Pawn now has "Tool Making" knowledge (KnowledgePanel)
4. **Verify:** If teacher dies, pawn is now only carrier (Last Carrier alert)

---

## 📊 Data Flow Diagrams

### Memorial System Data Flow
```
WorldMemory.event_appended()
        ↓
MemorialSystem._create_memorials_from_event()
        ↓
MemorialSystem.memorials[] ←→ SacredGeography.sacred_tiles{}
        ↓                                ↓
Pawn._try_start_pilgrimage()    GrudgeManager._process_memorial_grudges()
        ↓                                ↓
Pawn.pathfind_to(memorial_tile)   Grudge intensity reduced 50%
        ↓
GossipManager._process_memorial_gossip_spread()
        ↓
Gossip shared 2x faster among 3+ pawns at memorial
```

### Building/Crafting Data Flow
```
Player presses B/C key
        ↓
BuildingToolbar/CraftingMenu.toggle()
        ↓
Player clicks recipe/building type
        ↓
Check PlayerGathering.player_inventory
        ↓
[Has resources?] → Yes: Deduct, Add item/place building
               → No: Show error, disable button
```

---

## 🚨 Known Coupling Risks

| Risk | Severity | Mitigation |
|------|----------|------------|
| Autoload load order | HIGH | All autoloads use `get_node_or_null()` with null checks |
| Data structure changes | MEDIUM | Dictionary keys documented in this contract |
| Performance cache invalidation | MEDIUM | All caches have explicit invalidation logic |
| UI hardcoded keybinds | LOW | Keybinds in UI scripts, can be made configurable |

---

## ✅ Acceptance Criteria (CROSS-001 Complete)

- [x] Integration map documented (this file)
- [x] Data flow diagrams drawn
- [x] Coupling risks identified
- [x] Testing flows documented
- [x] TRACK 6 integration planned

---

*Document created: May 6, 2026*  
*Next review: When TRACK 6 (Knowledge) implementation starts*
