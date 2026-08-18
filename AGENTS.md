# HEELKAWN — AGENT OPERATING MANUAL

**Single source of truth for all AI agents working on HeelKawn.**
**Last Updated: 2026-08-18**

---

## TRUTH HIERARCHY (when docs conflict)

1. Source code and Godot runtime (highest truth)
2. This file — kernel philosophy and operational rules
3. `docs/lore/` — game canon and metaphysics
4. `docs/archive/` — historical session notes, not authority

---

## WHAT IS HEELKAWN

A deterministic 2D persistent simulation universe built in Godot 4.6.2. HeelKawn is a memory-and-consequence simulator where history is written by actions, not scripts. Pawns live, work, marry, form households, build settlements, wage wars, and die — all emergent from deterministic simulation.

**Core principle:** All world state must derive from tick count + seed + inputs. No hidden RNG. No frame-coupled logic.

---

## KERNEL RULES (NON-NEGOTIABLE)

### 1. Deterministic RNG
All randomness uses `WorldRNG` with named streams:
```gdscript
var roll: int = WorldRNG.roll("pawn_decision_%d" % pawn_id, 100)
```
**Forbidden:** `randi()`, `randf()`, `Time.get_unix_time_from_system()` in simulation paths.

### 2. No Frame/FPS Coupling
World truth is tick-based, never frame-based:
```gdscript
# WRONG:
if Time.get_delta() > 0.1:
    do_world_logic()
# CORRECT:
if GameManager.tick_count % 10 == 0:
    do_world_logic()
```

### 3. No Fake Systems
Do not expose placeholder behavior as active world logic. If incomplete, mark it or disable it.

### 4. Facts First, Meaning Second
1. **Facts** — tile types, resources, pawn positions, job states (deterministic kernel)
2. **Meaning** — region tags, settlement intent, cultural pressure (derived from facts)
3. **Interpretation** — narrative, lore, player understanding (layer on top)

Never hardcode meaning into the kernel. Derive it via `WorldMeaning`.

### 5. Inspect Before Creating
Always read existing files before adding new systems. Prefer the smallest reversible change.

### 6. Preserve Anonymity
No heroic exceptionalism. Pawns are anonymous citizens of an emergent civilization.

---

## PERFORMANCE TARGETS

- **1x:** Real-time observation, fully responsive
- **100x:** No crash cascades, no tick desync
- **200x:** Target 25 in-game days (~15,000 ticks) in ~75 seconds. No freezing, no lag spikes.

**Performance fixes are always welcome.** Optimize hot paths, increase stride at high speed, cache expensive lookups. Do not throttle the simulation in ways that cause lag.

---

## PROJECT ARCHITECTURE

### Engine
- **Godot 4.6.2** (GDScript, not C#)
- **Entry Scene:** `scenes/main/Main.tscn`
- **World:** `scenes/world/World.tscn` (tile-based, loaded as child of Main)

### Autoloads (Global Singletons)
All registered in `project.godot`. Accessible from any script by name.

**Core Simulation:**
| Autoload | Path | Purpose |
|----------|------|---------|
| `GameManager` | `autoloads/GameManager.gd` | Tick count, game speed, pause state |
| `TickManager` | `autoloads/TickManager.gd` | Frame-budget tick loop, speed index |
| `WorldRNG` | `autoloads/WorldRNG.gd` | Deterministic seeded RNG streams |
| `WorldMemory` | `autoloads/WorldMemory.gd` | Spatial memory (region-based) |
| `WorldMeaning` | `autoloads/WorldMeaning.gd` | Derived meaning from facts |
| `MemoryManager` | `autoloads/MemoryManager.gd` | Sacred site tracking |

**Settlement & People:**
| Autoload | Path | Purpose |
|----------|------|---------|
| `SettlementManager` | `autoloads/SettlementManager.gd` | Settlement lifecycle |
| `SettlementMemory` | `autoloads/SettlementMemory.gd` | Settlement state/history (`get_formal_settlements()`, `get_formal_settlement_count()`) |
| `HeelKawnianManager` | `autoloads/HeelKawnianManager.gd` | Pawn household/clan logic |
| `KinshipSystem` | `autoloads/KinshipSystem.gd` | Household/family relationships |
| `FactionManager` | `autoloads/FactionManager.gd` | Faction registry (`get_faction_ids()`, `get_faction(id)`) |
| `JobManager` | `autoloads/JobManager.gd` | Job posting/claiming (`open_count()`) |
| `PawnAccess` | `autoloads/PawnAccess.gd` | Pawn lookup/query |

**AI & Agents:**
| Autoload | Path | Purpose |
|----------|------|---------|
| `AIAgentManager` | `autoloads/AIAgentManager.gd` | Agent update budgets, neural/pattern intervals |
| `AutonomousWorldAI` | `autoloads/AutonomousWorldAI.gd` | World-level strategic AI |
| `CharacterBrainSystem` | `autoloads/CharacterBrainSystem.gd` | Per-pawn decision kernel |

**Economy & Resources:**
| Autoload | Path | Purpose |
|----------|------|---------|
| `StockpileManager` | `autoloads/StockpileManager.gd` | Resource stockpiles (`zone_count()`, `total_count_of(item_type: int)`) |
| `ColonySimServices` | `autoloads/ColonySimServices.gd` | Housing pressure, food pressure |
| `EconomyManager` | `autoloads/EconomyManager.gd` | Trade, currency |
| `SupplyChainSystem` | `autoloads/SupplyChainSystem.gd` | Resource logistics |

**World Systems:**
| Autoload | Path | Purpose |
|----------|------|---------|
| `WeatherSystem` (via WorldEnvironmentManager) | `autoloads/WorldEnvironmentManager.gd` | Weather, seasons |
| `EcologySystem` | `autoloads/EcologySystem.gd` | Wildlife, flora |
| `DisasterSystem` | `autoloads/DisasterSystem.gd` | Natural disasters |
| `CrimeSystem` | `autoloads/CrimeSystem.gd` | Crime and punishment |
| `DiseaseSystem` | `autoloads/DiseaseSystem.gd` | Illness and healing |

**Performance:**
| Autoload | Path | Purpose |
|----------|------|---------|
| `TickProfiler` | `autoloads/TickProfiler.gd` | Per-category tick timing (`cat_total_heelkawnian`, etc.) |
| `TickBudgetManager` | `autoloads/TickBudgetManager.gd` | Disabled stub (returns infinite budget) |
| `TickRateDecoupler` | `autoloads/TickRateDecoupler.gd` | System update interval scaling |

**UI:**
| Autoload | Path | Purpose |
|----------|------|---------|
| `UIManager` | `autoloads/UIManager.gd` | UI state management |
| `HeelKawnUIManager` | `autoloads/HeelKawnUIManager.gd` | Panel positioning |
| `UILayoutManager` | `autoloads/UILayoutManager.gd` | Layout helpers |

### Scene Tree (Main.tscn)
```
Main (Node2D)
├── DayNight (CanvasModulate)
├── WorldViewport (Node2D)
│   ├── World (instance of World.tscn)
│   ├── BuildPreviewOverlay
│   ├── WorldTrace
│   ├── PawnSpawner
│   ├── Camera (Camera2D)
│   └── ... (AnimalSpawner, EnemySpawner, etc.)
├── UI_Viewport (CanvasLayer)
│   ├── ColonyHUD
│   ├── BuildToolbar
│   ├── PawnInfoPanel
│   ├── ChronicleLedger
│   ├── SettingsPanel
│   ├── Minimap
│   └── ... (other UI panels)
├── CreatorDebugMenu (CanvasLayer) ← F10 debug menu, NOT under UI_Viewport
├── MapModeOverlay
├── WeatherOverlay
├── CommandMode
└── AmbientAudio
```

### Key Scripts
| Script | Path | Purpose |
|--------|------|---------|
| `HeelKawnian.gd` | `scripts/pawn/HeelKawnian.gd` | Main pawn script (~9700 lines) |
| `HeelKawnianData.gd` | `scripts/pawn/HeelKawnianData.gd` | Pawn data model |
| `HeelKawnPawnBrain.gd` | `scripts/ai/HeelKawnPawnBrain.gd` | Per-pawn AI brain |
| `WorldAI.gd` | `scripts/ai/WorldAI.gd` | World-level neural/pattern AI |
| `CreatorDebugMenu.gd` | `scripts/ui/CreatorDebugMenu.gd` | F10 debug report buttons |
| `Item.gd` | `scripts/items/Item.gd` | Item type enum (`Item.Type.WOOD`, etc.) |

### Common Patterns

**Speed bucket (0=1x through 5=200x):**
```gdscript
func _speed_bucket() -> int:
    # Maps GameManager.game_speed to bucket 0-5
```

**Tick stride (skip ticks at high speed):**
```gdscript
func _fast_forward_tick_stride() -> int:
    return [1, 3, 8, 15, 40, 100][_speed_bucket()]
```

**Cached lookups:**
```gdscript
var _cache_tick: int = -1
var _cached_value: int = -1

func get_cached() -> int:
    if _cache_tick != GameManager.tick_count:
        _cached_value = expensive_computation()
        _cache_tick = GameManager.tick_count
    return _cached_value
```

---

## F10 DEBUG MENU

Located at `CreatorDebugMenu.gd` (CanvasLayer, child of Main — NOT under UI_Viewport).

**Toggle:** F10 key calls `toggle_menu()` which flips `visible`.

**6 Report Buttons:**
1. FULL SYSTEM REPORT — GameManager, World, Settlements, Memory, Jobs
2. PERFORMANCE PROFILE — TickProfiler counters, stride config, tick intervals
3. AI & MEMORY STATE — WorldAI neural/patterns, agents, settlements
4. SETTLEMENTS & PAWNS — Formal settlements, pawn counts by state, jobs, households, factions
5. WORLD & ECONOMY — World dimensions, stockpiles, ColonySimServices
6. CONFIG & SETTINGS — Speed, tick count, days elapsed

**Known correct autoload method calls:**
- `JobManager.open_count()` ✅
- `StockpileManager.zone_count()` ✅
- `StockpileManager.total_count_of(int)` ✅
- `SettlementMemory.get_formal_settlements()` ✅
- `SettlementMemory.get_formal_settlement_count()` ✅
- `FactionManager.get_faction_ids()` ✅
- `KinshipSystem._households` (Dictionary) ✅
- `ColonySimServices.get_housing_pressure()` ✅
- `ColonySimServices.get_food_pressure()` ✅
- `AIAgentManager.get_agent_count()` ✅
- `TickManager.get_speed_index()` ✅
- `WorldMeaning.region_count()` ✅
- `WorldAI.neural_world_matrix` (Dictionary) ✅
- `WorldAI.emergent_patterns` (Array) ✅
- `TickProfiler.cat_total_heelkawnian` (int, microseconds) ✅

---

## WHAT NOT TO DO

- Do not add `class_name` to files that are autoloads (autoloads are accessed by name, not type)
- Do not reference nodes under `UI_Viewport/` that are actually direct children of `Main`
- Do not assume methods exist — always use `has_method()` guard or verify against this file
- Do not add throttling that reduces simulation fidelity at high speeds without explicit user request
- Do not create new autoloads without checking if the functionality already exists
- Do not modify `project.godot` autoloads without understanding the load order

---

## PROGRESS LOG

Track what was done, when, and by which AI session. Append only — never overwrite.

---

### 2026-08-18 — Session: opencode/big-pickle (Fix F10 Debug Menu + Consolidate AI Docs)

**Time:** ~14:00 UTC

**What was done:**

1. **Fixed CreatorDebugMenu.gd type mismatch** — Script extended `Control` but scene node was `CanvasLayer`. Changed `extends Control` → `extends CanvasLayer`.

2. **Fixed null _vbox crash** — Scene had bare CanvasLayer with no children. Script expected `$Panel` and `$Panel/VBoxContainer` which didn't exist. Rebuilt UI hierarchy programmatically in `_ready()`.

3. **Added missing `toggle_menu()` method** — Called by `Main.gd:4443` on F10 press but didn't exist.

4. **Rewrote all 6 report functions** — Audit found 24 broken method/property calls. Every button would have crashed. Fixed by:
   - Replaced `WorldMemory.region_count()` → `WorldMeaning.region_count()`
   - Replaced `WorldMemory.tag_count()` → removed (doesn't exist)
   - Replaced `WorldMemory.get_region_tags()` → `WorldMeaning.get_region_tags()`
   - Replaced `SettlementMemory.settlement_count()` → `SettlementMemory.get_formal_settlement_count()`
   - Replaced `MemoryManager.event_count()` → `MemoryManager.site_count()`
   - Replaced `MemoryManager.history_count()` → removed
   - Replaced `JobManager.total_count()` → removed
   - Replaced `TickProfiler.print_summary()` → direct counter reads
   - Replaced `TickManager.max_ticks_per_frame()` → removed (const dict, not method)
   - Replaced `WorldAI.neural_state_count()` → `WorldAI.neural_world_matrix.size()`
   - Replaced `WorldAI.pattern_count()` → `WorldAI.emergent_patterns.size()`
   - Replaced `AIAgentManager.agent_count()` → `AIAgentManager.get_agent_count()`
   - Replaced `AIAgentManager.training_history` → `collective_intelligence.shared_memory.training_history`
   - Replaced `HeelKawnianManager.pawn_count()` → scene tree child count
   - Replaced `SettlementManager.all_settlements()` → `SettlementMemory.get_formal_settlements()`
   - Replaced `FactionManager.faction_count()` → `FactionManager.get_faction_ids().size()`
   - Replaced `ColonySimServices.get_food_security()` → `get_food_pressure()`
   - Replaced `TickBudgetManager.is_enabled()` → removed (disabled stub)
   - Removed broken `ZoneRegistry.zone_count()` and `pf.components_computed`
   - Added `has_method()` guards throughout

5. **Fixed wrong scene tree paths:**
   - `UILayoutManager.gd`: `/root/Main/UI_Viewport/CreatorDebugMenu` → `/root/Main/CreatorDebugMenu`
   - `PlaytestInputRecorder.gd`: same path fix
   - `HeelKawnUIManager.gd`: `_find_node_by_type` checked `child is Control` but CreatorDebugMenu is CanvasLayer — removed type filter, changed return type to `Node`

6. **Audited all AI instruction files** — Found 41 scattered AI docs (7 active instruction files, 20 archived session logs, 2 tool artifacts). Created this consolidated AGENTS.md to replace them.

**Files modified:**
- `scripts/ui/CreatorDebugMenu.gd` — full rewrite
- `autoloads/UILayoutManager.gd` — path fix (2 occurrences)
- `autoloads/PlaytestInputRecorder.gd` — path fix
- `autoloads/HeelKawnUIManager.gd` — type fix + return type change
- `AGENTS.md` — consolidated from 7+ scattered AI instruction files

**Known remaining issues:**
- Artificial tick throttling exists in TickManager, AIAgentManager, HeelKawnian stride, TickRateDecoupler — flagged but NOT removed (user to decide per-system)
- 20+ archived AI session logs in `docs/archive/` — candidates for cleanup
- `.aider.chat.history.md` (35K lines) — can be deleted or .gitignored
- `brain/` directory has stale AI collaboration system files
