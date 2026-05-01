# TIMELINE

This timeline tracks deterministic world history.

## Era 0 - Pre-Settlement Silence

- Baseline ecology patterns established.
- No player-directed civilization layer.

## Era 1 - First Settled Traces

- Autonomous settlement memory and persistence systems begin shaping identity.
- Regions begin accumulating scars, ruins, and recoveries.

## Era 2 - Meaningful Regions (Current)

- Regional meaning readable as quiet, scarred, bloodied, or grave.
- Settlement identity diverges by behavior and architecture over time.

## Open Timeline Hooks

- First long-lived culture with recognizable architectural signature.
  - Detection condition: one settlement identity trajectory (open/cautious/defensive) remains dominant in the same region across multiple planner/rebuild cycles while preserving matching architecture markers.
  - Evidence anchors: `SettlementMemory` state/identity history + planner-built structure patterns + `WorldMeaning` regional tags.
- First revival of a moderately scarred settlement region.
  - Detection condition: a settlement region with moderate scar profile transitions from `abandoned`/`revivable` into sustained `recovering` or `active` status without immediate relapse into conflict gating.
  - Evidence anchors: settlement revival state curve in `SettlementMemory` + rebirth gate outcomes + scar/conflict facts in `WorldMemory`.
  - Canon-safe revival boundaries (non-negotiable constraints):
    - **Scar gate:** cluster scar_max must be < 3 (REVIVABLE_SCAR_MAX); scar_level >= 3 in any region blocks revival permanently
    - **Peace gate:** no pawn deaths for max(5000 ticks, culture-specific branch peace): OPEN=18000, CAUTIOUS=30000, DEFENSIVE=42000
    - **State gate:** settlement must be in `revivable` state (revival_score >= 70, scar_max <= 2)
    - **Cooldown gate:** 20000 ticks between successful rebirth spawns per settlement center
    - **Collapse gate:** scar_max >= 3 within 30000 ticks of last_pawn_death → `abandoned`; beyond that → `permanently_abandoned`
    - **Revival score curve:** 0-100 deterministic score gates: <35 = abandoned, 35-69 = recovering, 70-87 = revivable, >=88 = active (requires scar <= 1 and 2x peace threshold)
  - Implementation anchors: `autoloads/SettlementRebirth.gd` (gates), `autoloads/SettlementMemory.gd` (state curve, thresholds)
- First enduring conflict pattern between distinct cultural identities.
  - Detection condition: repeated conflict/death clusters occur between at least two divergent identity profiles in overlapping neighboring regions over a sustained tick window.
  - Evidence anchors: regional conflict/death facts in `WorldMemory` + identity divergence context from CulturalMemory/settlement behavior tags.
