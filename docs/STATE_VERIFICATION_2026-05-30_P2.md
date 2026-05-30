# State Verification 2026-05-30 (Part 2)

## What Changed

- **TechnologyEras.gd**: Complete rewrite from 158 -> 978 lines. Full production implementation replacing the previous minimal stub.

## New TechnologyEras Architecture

### Data Model
- `_settlement_eras`: center -> TechEra (per-settlement era tracking)
- `_global_era`: highest era among all settlements (drives diplomacy, tech diffusion)
- `_settlement_literacy`: center -> float (per-settlement literacy rate, 0.0-1.0)
- `_settlement_lifespan`: center -> float (per-settlement average lifespan in years)
- `_diffusion_bonus`: center -> float (tech diffusion multiplier, 0.0-0.20)
- `_advancement_stall`: center -> { stall_ticks, warning_sent, last_era, stalled_since_tick }
- `_settlement_prev_knowledge`: center -> float (knowledge snapshot for regression detection)
- `_knowledge_history`: center -> Array[float] (ring buffer of last 4 knowledge samples)
- `_building_cost_multiplier_cache`: center -> float (cached building cost scale)

### Key Systems Implemented
1. 10-era progression with knowledge thresholds (0, 50, 150, 300, 500, 750, 1000, 1500, 2500, 4000)
2. Per-settlement era determination via KnowledgeSystem.get_total_knowledge + fallback estimation
3. Global era tracking (highest settlement era) with diffusion effects
4. Tech diffusion: lower-era settlements get up to +20% effective knowledge from higher-era neighbors within 120-tile radius, scaled by era gap and distance
5. Era advancement effects: literacy +7%/era, lifespan +8yr/era, building speed +8%/era, research speed +12%/era, max pop +40/era
6. Era-specific unlock tables: 50 buildings, 50 jobs, 50 items across all 10 eras
7. Literacy tracking with smooth interpolation toward era-based target
8. Lifespan tracking with smooth interpolation toward era-based target
9. Building cost scaling: +15% per era with cache invalidation on advancement
10. Advancement stall detection: 15K tick threshold triggers warning signal
11. Era regression: >40% knowledge drop can trigger regression with cascading literacy/lifespan penalties
12. Knowledge history window (4 samples) prevents transient dips from triggering regression
13. EventBus integration: subscribes to settlement_founded, research_breakthrough
14. 7 signals: era_advanced, global_era_advanced, settlement_literacy_changed, settlement_lifespan_changed, era_diffusion_applied, settlement_era_stalled, era_regressed
15. WorldMemory event recording for all significant transitions
16. Debug/stats: get_era_report (per-settlement), get_global_progress, get_era_distribution_map, get_stats
17. Save/load: versioned (v2) with full round-trip for all fields including history buffers
18. Clear/reset support for world generation teardown

### What Was Verified
- No global RNG (`randf`, `randi`, etc.) — no RNG used at all in this system (diffusion is deterministic based on settlement positions and eras)
- No frame/FPS-coupled world-truth decisions — all logic runs on tick intervals
- All external system references use `get_node_or_null` followed by `has_method` checks
- All verbose_logs calls guarded with `GameManager != null and GameManager.has_method("verbose_logs")`
- Edge cases covered: empty settlement lists, missing KnowledgeSystem, knowledge regression, advancement stall, first settlement initialization
- Cataclysm regression: >40% knowledge drop triggers era fall with literacy/lifespan penalties
- Advancement stall: 15K+ ticks at >80% knowledge to next era triggers warning
- Tech diffusion: correct distance-weighted calculation with era gap scaling

### What Remains Unverified/Risky
- Full integration test requires Godot runtime (bash quality gate could not execute — no WSL in this environment)
- KnowledgeSystem.get_total_knowledge(center) referenced with has_method guard — fallback _estimate_settlement_knowledge exists if method absent
- save/load round-trip not tested in runtime
- Building cost cache invalidation relies on _building_cost_cache_dirty flag — no forced invalidation from external building system
- Tech diffusion distance calculation uses Manhattan distance on tile positions — may need adjustment for non-square world maps
- Regression threshold (40% drop) may need tuning based on simulation feel
