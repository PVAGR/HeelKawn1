# Architecture

## System Overview

HeelKawn is a deterministic Godot 4.6 world simulation with ~75 autoload systems.

### Core Architecture Layers

```
┌─────────────────────────────────────────────┐
│  OBSERVER LAYER (Player-facing)              │
│  ColonyHUD, PawnInfoPanel, ObserverHUD,      │
│  CreatorDebugMenu, FocusInspector            │
├─────────────────────────────────────────────┤
│  AI / DECISION LAYER                         │
│  WorldAI, AIAgentManager, SettlementAI,      │
│  SettlementPlanner, TradePlanner             │
├─────────────────────────────────────────────┤
│  MEANING LAYER (Phase 3-4)                   │
│  WorldMeaning, CulturalMemory, MythMemory,   │
│  SacredMemory, FactionRegistry, ReligionLens │
├─────────────────────────────────────────────┤
│  MEMORY LAYER (Kernel)                       │
│  WorldMemory, SettlementMemory,              │
│  WorldPersistence, AgeMemory, RemnantMemory  │
├─────────────────────────────────────────────┤
│  SIMULATION LAYER                            │
│  Main (tick loop), Pawn, JobManager,         │
│  StockpileManager, ColonySimServices,        │
│  AnimalSpawner, WorldRNG                     │
├─────────────────────────────────────────────┤
│  SPECIALIZED SYSTEMS                         │
│  BloodlineSystem, KnowledgeSystem,           │
│  TechnologySystem, KinshipSystem,            │
│  CollapseSystem, GeneticEvolution,           │
│  HistoricalSimulation, AuthoritySystem       │
└─────────────────────────────────────────────┘
```

### Key Autoloads (the core 11)

| Autoload | Purpose |
|----------|---------|
| `WorldMemory` | Append-only fact storage — the world's memory |
| `WorldMeaning` | Interprets facts into meaning and culture |
| `WorldPersistence` | Save/load — serializes world state |
| `GameManager` | Speed control, tick emission, frame caps |
| `JobManager` | Work queue system for pawns |
| `StockpileManager` | Inventory and resource tracking |
| `ColonySimServices` | Demand calculation (food, materials, housing) |
| `SettlementMemory` | Per-settlement memory and identity |
| `SettlementPlanner` | Settlement autonomous decision-making |
| `WorldClock` | Time tracking (ticks → hours → seasons → ages) |
| `WorldRNG` | Seeded randomness (deterministic variety) |

### Tick Architecture

The main game loop in `Main.gd`:
1. Emit ticks from GameManager (variable per frame based on speed)
2. Each tick: pawn AI → job processing → stockpile updates → settlement planning
3. Periodic tasks: regrowth, mining, wildlife, social rapport, replanning
4. Speed-aware throttling prevents hitches at high speeds (12x, 26x, 50x, 100x)

### Data Flow

```
Pawn actions → WorldMemory (facts) → WorldMeaning (interpretation)
     ↓                                    ↓
SettlementMemory                    CulturalMemory
     ↓                                    ↓
SettlementPlanner → Jobs → Pawns     FactionRegistry
     ↓                                    ↓
TradePlanner → TradeMemory          ReligionLens → MythMemory
```

### Performance Architecture

- Adaptive tick caps per frame (GameManager)
- Speed-aware cadences for all periodic tasks
- Rolling cursors for scan-heavy operations (regrowth, mining)
- Phase-staggered planning (SettlementPlanner vs TradePlanner offset)
- Social rapport budget capping
- Emergent pattern emission gates
