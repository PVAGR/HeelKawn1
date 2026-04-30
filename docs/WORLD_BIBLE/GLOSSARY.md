# GLOSSARY

## Canon Terms

- Deterministic history: identical conditions produce identical outcomes.
- WorldMemory: append-only factual record of impactful events.
- WorldMeaning: derived interpretation of regional historical patterns.
- WorldPersistence: lasting consequence in land/settlement state.
- CulturalMemory: inherited regional reputation affecting behavior.
- Scar: persistent marker of repeated impactful damage.
- Ruin: permanent structural consequence of settlement collapse.
- Recovery: gradual visual/ecological healing without erasing history.

## Legacy -> Canon Mapping (With Implementation Anchors)

- Neural matrix (legacy): simulation-wide adaptive AI influence layer; canon term is `WorldAI` + neural/state analysis systems.
  - Anchor: `scripts/ai/WorldAI.gd`, `docs/NEURAL_NETWORK_STATE.md`
- Civilization layer (legacy): no separate omniscient controller; civilization emerges from settlement behavior, memory, and planner outputs.
  - Anchor: `autoloads/SettlementMemory.gd`, `scripts/ai/SettlementAI.gd`, `scenes/main/Main.gd`
- Monitoring (legacy): runtime observability and diagnostics surfaces, not lore authority.
  - Anchor: `scripts/debug/ErrorTracker.gd`, `scripts/ui/CreatorDebugMenu.gd`, `docs/SESSION_REPORT_FOR_AI.md`
- Cultural system (legacy broad term): canon stack is CulturalMemory + ReligionLens + settlement identity divergence.
  - Anchor: `autoloads/CulturalMemory.gd`, `autoloads/ReligionLens.gd`, `docs/HEELKAWN_STATE.md`
- Economic system (legacy broad term): canon scope is stockpiles, labor pressure, trade planning, and resource flow behavior.
  - Anchor: `autoloads/StockpileManager.gd`, `scripts/stockpile/Stockpile.gd`, `scripts/ai/TradePlanner.gd`
- Historical simulation: world truth is fact-first (`WorldMemory`) with derived labels (`WorldMeaning`) and persistence outcomes.
  - Anchor: `autoloads/WorldMemory.gd`, `autoloads/WorldMeaning.gd`, `autoloads/WorldPersistence.gd`

## Cultural Architecture (Phase 4 Identity)

- **Culture type**: deterministic identity derived from settlement `scar_max` + `reputation_min` + Age index. Values: 0 = OPEN, 1 = CAUTIOUS, 2 = DEFENSIVE.
- **Architecture markers**: deterministic building behavior rules per culture type.
- **OPEN (0)**: sprawling build order, beds placed farthest from center, large perimeter radius (3), growth-first intent priority.
- **CAUTIOUS (1)**: compact 5x5 core, moderate perimeter radius (2), balanced build order.
- **DEFENSIVE (2)**: tight perimeter radius (1), nearest bed placement, defensive-first intent priority.

### Architecture Signature Constants

| Culture | PERIM_R | DOOR2_MIN_SPAN | OPEN_VILLAGE_WALL | PEACE_TICKS |
|---------|--------|---------------|------------------|------------|
| OPEN    | 3      | 7              | 10             | 18000      |
| CAUTIOUS| 2      | 7              | 6              | 30000      |
| DEFENSIVE| 1      | 4              | 3              | 42000      |

Implementation Anchor: `autoloads/SettlementPlanner.gd` (`_derive_culture_type_v1_for_age`, `_plan_one_settlement_culture`, constants from lines 5-16)

## Canon Guardrails

- Legacy terms may inform world flavor and canon framing, but they do not override current implementation authority.
- If a legacy term conflicts with current state docs, align to `docs/HEELKAWN_STATE.md` and record canon updates in `docs/WORLD_BIBLE/CANON_CHANGELOG.md`.
