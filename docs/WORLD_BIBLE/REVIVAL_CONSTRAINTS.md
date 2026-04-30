# REVIVAL STORYLINE CONSTRAINTS

This document defines canon-safe revival boundaries for HeelKawn. Rebirth behavior must remain emergent but interpretable, with no heroic script overrides.

## Core Principle

**The world exists before the player.** Revival is a natural process of the simulation, not a player-driven narrative override. Settlements may revive or die based on deterministic conditions, not heroic intervention.

## Revival State Machine

Settlements follow a deterministic revival curve with these states:

1. **permanently_abandoned** - Scar level ≥ 3, no recovery possible
2. **abandoned** - Scar level 2, recovery possible but unlikely
3. **revivable** - Moderate scar profile, quiet region, recovery active
4. **recovering** - In active recovery phase
5. **active** - Fully functional settlement

## Revival Gate Conditions

A settlement can only revive (transition from abandoned/revivable to recovering/active) if ALL of the following conditions are met:

### Hard Gates (must pass)

1. **Scar Level < 3**
   - Permanently abandoned settlements (scar ≥ 3) cannot revive
   - This is irreversible within the current world timeline

2. **No Recent Conflict**
   - No conflict events in the region within the last 5000 ticks
   - Conflict includes: war_proposed, war_battle_spawned, enemy_death clusters
   - Evidence: WorldMemory conflict facts + IntentMemory settlement intent

3. **Revivable State**
   - Settlement state must be `revivable` or `abandoned`
   - `permanently_abandoned` blocks revival entirely
   - Evidence: SettlementMemory state curve

### Soft Gates (influence probability)

1. **Quiet Region**
   - Death density must be "none" or "low"
   - WorldMeaning label must be "quiet" or "scarred" (not "bloodied" or "grave")
   - Evidence: WorldMeaning regional meaning

2. **Resource Access**
   - At least one viable resource type in region (food, wood, stone)
   - Resource pressure < 0.8 (not critical shortage)
   - Evidence: SettlementMemory resource pressure

3. **Survivor Potential**
   - Population capacity > 0 (can support new pawns)
   - Housing capacity > 0 (structures available or buildable)
   - Evidence: SettlementMemory settlement profile

## Revival Process

When gates pass, revival proceeds deterministically:

1. **Trigger Detection**
   - System checks revival gates every 2000 ticks
   - Only regions meeting all conditions are considered

2. **Rebirth Tick**
   - Peace-gated: requires 5000 ticks of no conflict
   - Tick-only: no player input or heroic override
   - Evidence: GameManager.tick_count + conflict-free window

3. **State Transition**
   - `abandoned` → `revivable` (if gates pass and resources available)
   - `revivable` → `recovering` (if gates pass and survivor potential met)
   - `recovering` → `active` (after sustained recovery period)

4. **Recovery Period**
   - Minimum 10000 ticks in `recovering` state before `active`
   - Must maintain scar level < 3 throughout
   - Must avoid conflict events during recovery
   - Evidence: SettlementMemory state tracking + WorldMemory events

## Canon-Safe Boundaries

### What Revival IS

- **Emergent**: Results from simulation conditions, not scripted narrative
- **Deterministic**: Same conditions produce same outcomes (seed + tick)
- **Auditable**: All revival decisions trace to facts in WorldMemory/SettlementMemory
- **Limited**: Scar level ≥ 3 is permanent; no heroic resurrection
- **Natural**: Revival follows ecological and resource constraints

### What Revival IS NOT

- **Heroic Override**: Player cannot force revival of permanently abandoned settlements
- **Scripted Narrative**: No "chosen one" revival mechanics
- **Hidden Magic**: No secret revival tables or non-auditable state
- **Rewrite History**: Revival does not erase past deaths or scars
- **Guaranteed**: Even with gates passed, revival may fail if conditions deteriorate

## Player Interaction

### Spectator Mode
- Player can observe revival states via RegionInspector
- Player can see revival gates via WorldMeaning tags
- Player cannot intervene or force revival

### Incarnation Mode
- Player can incarnate in reviving settlements as a normal pawn
- Player has no special revival powers
- Player death does not trigger or block revival

## Evidence Anchors

All revival decisions must be traceable to:

1. **WorldMemory**
   - Death events (pawn_death, animal_death)
   - Conflict events (war_proposed, war_battle_spawned, enemy_death)
   - Building events (building_constructed, building_destroyed)
   - Resource events (forage, consumption)

2. **SettlementMemory**
   - State curve (permanently_abandoned → active)
   - Resource pressure (food, wood, stone)
   - Population capacity
   - Housing capacity
   - Intent shifts (grow, hold, abandon)

3. **WorldMeaning**
   - Regional meaning labels (quiet, scarred, bloodied, grave)
   - Death density classification
   - Regional tags (built_up, ruined, famine_stricken, etc.)

4. **WorldPersistence**
   - Scar level (0-3)
   - Recovery stage
   - Last death tick
   - Next recovery tick

## Implementation Notes

- Revival gates are checked in `SettlementMemory._on_game_tick` with throttling
- Revival state transitions are logged in WorldMemory as events
- Scar level never decreases (WorldPersistence invariant)
- Recovery stage can decrease if conditions deteriorate
- All revival logic uses deterministic WorldRNG streams for consistency

## Testing Validation

To validate revival constraints:

1. Create a world with multiple settlements
2. Let some settlements become abandoned (conflict, starvation)
3. Verify scar level ≥ 3 blocks revival permanently
4. Verify conflict events block revival for 5000 ticks
5. Verify quiet regions with resources can revive
6. Verify revival state transitions are logged in WorldMemory
7. Verify no heroic override or player-forced revival
