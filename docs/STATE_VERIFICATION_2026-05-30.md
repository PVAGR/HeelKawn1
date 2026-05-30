# State Verification 2026-05-30

## What Changed

- **LibrarySystem.gd**: Complete rewrite from 118 → 1040 lines. Full production implementation replacing the previous minimal stub.

## New LibrarySystem Architecture

### Data Model
- **Library**: per-settlement zone with capacity, book collection, preservation factor, scholar assignments, building quality tracking, destruction state
- **Book**: knowledge_type, carrier (pawn_id), tick, preservation_factor, title, copy_of, last_restored_tick
- **Index**: `_settlement_library_index` maps center → array of library_ids (supporting multiple libraries per settlement)

### Key Systems Implemented
1. Library zone tracking with per-settlement index and multi-library support
2. Preservation factor calculated from building quality, scholar count, era tech level, population
3. Tick-based book degradation with age penalties and preservation-adaptive degradation rates
4. Scholar maintenance system that restores book preservation factors
5. Book copy system with quality variance (deterministic via WorldRNG)
6. Library destruction with partial book recovery based on preservation
7. KnowledgeSystem integration for verifying scholar knowledge and type names
8. EventBus subscription for settlement_founded, settlement_destroyed, building_constructed
9. WorldMemory event recording for all key actions
10. 4 signals: library_founded, book_added, book_destroyed, preservation_critical
11. 16 query/search functions including rare book ranking, preservation sorting, etc.

### What Was Verified
- No global RNG (`randf`, `randi`, etc.) — all randomness uses `WorldRNG.stream_seed`
- All external system references use `get_node_or_null` followed by `has_method` checks
- Deterministic construction: all seeded rolls use library_id/center/tick as salt material
- Edge cases covered: empty libraries, fully degraded books, no scholars, destroyed state, capacity limits

### What Remains Unverified/Risky
- Full integration test requires Godot runtime (bash quality gate could not execute — no WSL in this environment)
- TechnologyEras.get_settlement_era() is referenced but not verified to exist as an autoload
- save/load round-trip not tested in runtime
- Max 5 libraries per settlement hardcoded — may need tuning

---

## Second Change: ResearchSystem.gd — Complete Rewrite (158 → 1063 lines)

Full production implementation replacing the previous minimal stub.

### New ResearchSystem Architecture

**Data Model:**
- `ResearchProject` class: name, category, cost, progress, started_tick, breakthrough flag, contributing_scholars array, last_progress_tick, decay_started_tick
- `ResearchQueueEntry` class: category, name, auto_assigned, queued_tick
- `_active_projects`: center → Array[ResearchProject] (multiple concurrent, up to pop/10)
- `_project_queues`: center → Array[ResearchQueueEntry] (auto-start next on completion)
- `_category_knowledge_levels`: center → {category → float} (fallback if KnowledgeSystem.get_knowledge() missing)

**Key Systems Implemented:**
1. Multiple concurrent projects per settlement (max = population/10 + era bonus + library bonus, capped at 8)
2. Project queue with auto-start on completion — dequeue → start_research
3. Progress rate: knowledge level + scholar count (LibrarySystem) + population + era bonus + collaboration bonus
4. Breakthrough mechanic (2% via WorldRNG.chance_for) — boosts ALL 8 categories, spreads to nearby settlements
5. 8 research categories (Farming, Crafting, Warfare, Medicine, Culture, Trade, Science, Magic)
6. Collaboration: scholars from other settlements can contribute with distance-based acceptance penalty
7. Auto-pick lowest category when idle, manual via queue_research
8. Tick processing every 2000 ticks — advance active projects, check decay, auto-start
9. WorldMemory events: research_started, research_completed, breakthrough_achieved, research_cancelled, collaborator_added
10. KnowledgeSystem integration (has_method-guarded): add_knowledge, transfer_knowledge on breakthrough
11. TechnologyEras integration: era speeds up progress (+0.05 per era level) and increases concurrent project cap
12. 3 signals: research_started, research_completed, breakthrough_achieved
13. EventBus integration: subscribes to settlement_founded, scholar_arrival
14. Debug/stats: get_research_report (per-settlement), get_global_stats, get_category_breakdown, get_research_progress_summary
15. Save/load: to_save_dict / from_save_dict with full round-trip for all fields
16. Edge cases: no scholars = rate floor at 0.1; all categories maxed = skip auto-start; decay cancels stalled projects (12K tick threshold)
17. Null guards: every external reference uses get_node_or_null + has_method checks
18. Deterministic RNG: only WorldRNG.chance_for / WorldRNG.unit with seeded keys and salt material

### What Was Verified
- No global RNG — all randomness uses `WorldRNG.chance_for` or `WorldRNG.unit` with deterministic keys
- All external system references use `get_node_or_null` followed by `has_method` checks
- Edge cases: no-population settlements (rate*0.1), maxed categories (no auto-start), decay (12K+ idle → cancel)
- Breakthrough uses WorldRNG.chance_for with key "research_breakthrough:{center}:{category}" and tick+center+category salt

### What Remains Unverified/Risky
- Full integration test requires Godot runtime (bash quality gate could not execute)
- KnowledgeSystem.get_knowledge()/add_knowledge()/transfer_knowledge() referenced with has_method guards — may never be called if KS doesn't expose them (internal _category_knowledge_levels fallback exists)
- TechnologyEras integration — referenced but assumes get_settlement_era returns int
- save/load round-trip not tested in runtime
- Collaboration distance penalty uses SettlementPlanner._center_tile_of_region_key — may be expensive at scale
