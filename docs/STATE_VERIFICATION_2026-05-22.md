# State Verification — Knowledge Preservation Loop Unification
**Date:** 2026-05-22
**Task:** Unify stones, books, teaching, literacy into one coherent knowledge preservation loop; add lost/rediscovered mechanics; verify knowledge death chain.

## What Changed

### 1. Wire preservation pressure into Matrix AI ambitions
- `HeelKawnianManager.get_settlement_ambition_for_pawn()` now calls `KnowledgeSystem.compute_preservation_pressure()` to check for urgent/recommended knowledge
- Urgent knowledge types trigger `CARVE_KNOWLEDGE_STONE` or `CARVE_LEDGER_STONE` ambitions
- Critical knowledge triggers `TEACH_SKILL` ambition to spread before lost
- Literate pawns with at-risk knowledge trigger `PAPER_MAKING` to write books

### 2. Verify knowledge death chain against record carriers
- `KnowledgeSystem._check_knowledge_loss()` now also checks for record carriers (stones/books) before entering dormant state
- If record carriers exist for the knowledge, it does NOT enter dormant but is marked "degraded"
- Only enters dormant when both living carriers AND record carriers are zero (truly lost)
- New `_is_knowledge_truly_lost()` helper validates carrier count + record carrier count

### 3. CivilizationStage consumes knowledge_lost signal
- Added `_on_knowledge_lost()` handler that applies `KNOWLEDGE_LOSS_ERA_PENALTY` to the affected settlement
- Added `_on_civilization_tick` for periodic penalty decay
- Knowledge loss now meaningfully impacts the civilization era score

### 4. "Truly lost" knowledge path
- When knowledge enters dormant from last carrier death AND no records exist, WorldMemory records `TRULY_LOST` event
- Rediscovery from truly lost state requires higher difficulty (reduced base chance, higher threshold)

## What Was Verified
- `compute_preservation_pressure()` returns sorted urgent/recommended/stable lists
- Preservation pressure is passed into ambition result payload
- Knowledge death chain checks record carriers before dormancy
- Civilization stage responds to knowledge loss events
- All existing tick handlers remain deterministic (seed-based checking)

## What Remains Risky/Unverified
- Runtime truth pass in Godot editor still needed for full verification
- Teaching chain depth calculation may have edge cases at very low pawn counts
- Preservation pressure ambition may trigger too frequently at default cooldown settings