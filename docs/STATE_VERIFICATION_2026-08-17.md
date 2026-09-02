# HeelKawn Verification Snapshot — 2026-08-17

## Session 3: Deep Profiling + O(P²) Elimination (Aug 17, 2026)

### Investigation Summary

Runtime profiling data showed:
- Individual HeelKawnian nodes appearing in TOP3 with ~30–230+ ms costs
- AIAgentManager consuming ~90–130 ms per tick
- Profiler `other` bucket dominating
- Only ~24 pawns but job count growing to 128+

**Root causes traced:**
1. **`PawnSpawner.get_alive_pawns()`** — allocated new O(P) array on every call; 51+ call sites across codebase
2. **`HeelKawnian._refresh_awareness()`** — `get_tree().get_nodes_in_group("pawns")` = full scene tree traversal per pawn = O(P²)
3. **`SocialDynamics._relationships`** — no adjacency index; every per-pawn query scanned all relationships = O(R)
4. **`ColonySimServices`** — 8× `find_alive_pawns()` per refresh cycle = 8 separate O(P) allocations
5. **`AIAgentManager._update_all_agents()`** — allocated+sorted `agents.keys()` every 3 ticks
6. **`WorldAI.world_events`** — grew without bound; `_update_world_state_neurons()` scanned all events = O(E)
7. **`WorldAI._update_knowledge_neurons()`** — called `PawnAccess.find_pawns()` just for `.size()`

### Changes Made

**1. PawnSpawner alive_pawns tick cache**
- Added `_alive_pawns_cache: Array[HeelKawnian]`, `_alive_pawns_cache_tick: int`, `_alive_pawns_count_cache: int`
- `get_alive_pawns()` returns cached result within same tick; rebuilds only on tick change
- Added `alive_pawn_count()` for callers that only need count (no array allocation)
- Cache invalidated on spawn/death via `invalidate_pawn_dict()`
- **Impact:** Eliminates 51+ O(P) array allocations per tick; single allocation shared by all callers

**2. HeelKawnian awareness O(P²) → cached alive list**
- `_refresh_awareness()` now uses `spawner.get_alive_pawns()` instead of `get_tree().get_nodes_in_group("pawns")`
- **Impact:** Eliminates O(P²) scene tree traversal; uses tick-cached alive list from PawnSpawner

**3. SocialDynamics adjacency index**
- Added `_by_pawn: Dictionary` mapping pawn_id → Array of relationship keys
- `get_all_relationships_for()` now O(degree) instead of O(R) full scan
- `_on_pawn_death()` uses index for O(degree) removal instead of O(R) scan
- `_on_pawn_move()` uses index for O(degree) iteration instead of O(R) scan
- Index maintained in `add_interaction()` (add) and `clear()` (reset)
- **Impact:** Per-pawn relationship queries go from O(R) to O(degree); ~20+ callers benefit

**4. ColonySimServices single-pass collector**
- Added `_collect_pawn_stats()` — single O(P) pass computing: total count, food carried, cold/uncovered count, centroid
- `_food_carried_by_pawns()` uses cached result
- `_refresh_housing_pressure()` uses cached count instead of `.find_alive_pawns().size()`
- `_colony_centroid_tile()` uses cached centroid
- `count_cold_uncovered_pawns()` uses cached count for global case
- **Impact:** 8 separate O(P) passes → 1 O(P) pass per refresh cycle (every 30 ticks)

**5. AIAgentManager key cache**
- Added `_agent_keys_cache_dirty: bool` flag
- `_update_all_agents()` only rebuilds sorted keys when agents are added/removed
- Flag set in `_spawn_agent()` and `_remove_agent()`
- **Impact:** Eliminates array allocation + sort every 3 ticks

**6. WorldAI world_events bound + pawn count cache**
- Added `MAX_WORLD_EVENTS = 2048` constant; `update()` trims array if exceeded
- Added `_get_cached_pawn_count()` — tick-stamped, shared by all callers
- `_update_knowledge_neurons()` uses cached count instead of `PawnAccess.find_pawns().size()`
- **Impact:** Prevents unbounded O(E) scans; eliminates redundant O(P) pawn scans

### Static Quality Gate: PASS

### Complexity Improvement Summary

| Component | Before | After |
|---|---|---|
| `get_alive_pawns()` per tick | 51× O(P) allocations | 1× O(P) allocation, cached |
| HeelKawnian awareness | O(P²) scene tree | O(P) cached list |
| `get_all_relationships_for()` | O(R) full scan | O(degree) index lookup |
| ColonySimServices refresh | 8× O(P) passes | 1× O(P) pass |
| AIAgentManager keys | O(N log N) every 3 ticks | O(N log N) only on mutation |
| WorldAI pawn count | O(P) per caller | O(1) cached |
| WorldAI world_events | unbounded O(E) | capped at 2048 |

### Known Remaining Issues

1. **Job explosion** — job count grows 21→128 with 24 pawns; `JobManager.claim_next_for()` does O(N) scan per pawn (investigated, deferred)
2. **RelationalGraph** — no adjacency index; `_has_relation`, `_parent_ids`, `_child_ids` do O(E) scans (investigated, deferred)
3. **WorldMemory query methods** — most `get_events_*` methods still do linear scans despite type index existing (investigated, deferred)
4. **CivilizationLoop O(settlements²)** — deferred (medium priority, well-gated at 2000 ticks)
5. **Runtime verification** — not available in this environment; before/after tick timing not yet measured

---

## Session 2: Lag Reduction + Autoload Consolidation (Aug 17, 2026)

### Changes Made

**1. CharacterProgressionSystem double-execution fix**
- `_check_achievements` was running every tick via `_on_game_tick` AND every 2000 ticks from Main.gd
- Added `ACHIEVEMENT_CHECK_INTERVAL = 500` constant; `_on_game_tick` now gates at 500 ticks
- Removed duplicate calls from Main.gd (lines 3110-3113)
- **Impact:** Eliminates per-tick achievement iteration across all character_data × all achievements

**2. SurvivalSystem throttle**
- `PawnAccess.find_alive_pawns()` was called every tick with no gating
- Added `FULL_SURVIVAL_INTERVAL = 3` and `DEATH_CHECK_INTERVAL = 5`
- `_on_game_tick` now returns early on non-interval ticks (3 out of every 4 ticks skipped)
- Death checks gated to every 5 ticks (was every tick)
- **Impact:** Reduces pawn iteration frequency by ~75%

**3. EcologySystem interval doubling + double-buffer**
- `ECOLOGY_UPDATE_INTERVAL` doubled: 120 → 240 (65K-tile pass)
- `PLANT_GROWTH_INTERVAL` doubled: 240 → 480 (65K-tile pass)
- `POLLUTION_INTERVAL` doubled: 500 → 1000 (65K-tile pass + 8-neighbor diffusion)
- Added `_pollution_prev` double-buffer to eliminate `PackedFloat32Array.duplicate()` allocation (65K floats copied every pollution pass)
- **Impact:** Halves frequency of three heaviest 65K-tile operations; eliminates ~256KB allocation per pollution pass

**4. Manager tick forwarding (8 managers)**
- Added `_forward_tick_to_children` to MemoryManager, FactionManager, PawnManager, SocialManager, UIManager, EventManager, PlayerManager, ObserverManager
- Each manager connects to `GameManager.game_tick` and forwards tick events to child subsystems
- **Impact:** Enables safe removal of standalone autoload registrations for child subsystems

**5. Duplicate autoload removal (3 removed)**
- Removed from project.godot: `HeelKawnUIManager`, `UILayoutManager`, `PawnMoodUI`
- All 3 had 0 direct references outside their parent manager (UIManager)
- Now loaded as children of UIManager via `_load_sub` + tick forwarding
- **Autoload count:** 143 → 140

### Audit: Consolidation Reference Analysis

Comprehensive scan of all 28 child subsystems that are both standalone autoloads AND children of consolidated managers:

| Category | Autoloads | Direct Refs | Status |
|---|---|---|---|
| **CLEAN (0 refs)** | IntentMemory, SacredMemory, PawnBrainBridge, HeelKawnUIManager, UILayoutManager, PawnMoodUI | 0 | HeelKawnUIManager, UILayoutManager, PawnMoodUI removed. IntentMemory, SacredMemory, PawnBrainBridge already removed prior. |
| **LOW (1-7 refs)** | FactionSystem (1), AuthoritySystem (2), DynastyFamilySystem (4), LegacySystem (7), AgeMemory (7), RemnantMemory (7), TradeMemory (7), PawnChatterBubbles (2) | 37 | Deferred — need reference migration |
| **MEDIUM (8-15 refs)** | KinshipSystem (12), RoadMemory (12), FogOfDiscovery (8), IncarnationManager (9) | 41 | Deferred — need reference migration |
| **HIGH (16+ refs)** | HeelKawnianManager (54), ObservationAPI (39), PawnConsciousness (36), EgregoreMemory (36), CulturalMemory (38), PlayerIntentQueue (26) | 229 | Deferred — need reference migration |
| **NO PARENT MANAGER** | DynastyFamilySystem, EgregoreMemory, CulturalMemory, CulturalStyleManager | ~80 | Need new manager or keep standalone |

### Static Quality Gate: PASS

### Known Remaining Issues

1. **140 autoloads** — still high; 25 child subsystems remain as standalone autoloads with duplicate tick handlers
2. **Tick forwarding adds overhead** — managers iterate children on every tick even when no child is loaded
3. **CivilizationLoop O(settlements²)** — deferred (medium priority, well-gated at 2000 ticks)
4. **Runtime verification** — not available in this environment

---

## Session 1: Identity Repair (Aug 17, 2026)

### Scope
- Restore project identity (README.md, CANONICAL_MAP.md accidentally replaced with PVA Bazaar content)
- Resolve merge conflict in docs/HEELKAWN_STATE.md
- Update state docs for stabilization phase
- Run static quality gate

### Changes Made

1. README.md — Restored from accidental PVA Bazaar overwrite
2. CANONICAL_MAP.md — Restored from accidental PVA Bazaar overwrite
3. docs/HEELKAWN_STATE.md — Merge conflict resolved + state updated
4. TODO.md — Reprioritized for stabilization sequence
5. docs/BUILD_INVENTORY.md — Minor staleness corrections

### Static Quality Gate: PASS

### Residual Risks
1. **Runtime truth pass not completed** — F10 panels, HUD identity strip, PawnInfo/PawnMoodUI need in-editor verification
2. **140 autoloads** — consolidation plan exists; 25 child subsystems still duplicate-registered
3. **Performance smoothness at 100x** — last verified in prior sessions; needs re-verification after lag reduction changes
