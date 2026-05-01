# Life-Path System Test Checklist

## Overview
This checklist validates that the four life-paths (Farmer, Soldier, Ruler, Wanderer) produce distinct, deterministic outcomes in the simulation.

## Prerequisites
- Game is running with at least 3 pawns
- Verbose logs enabled (`GameManager.verbose_logs() == true`)
- Settlement established with at least one region

---

## 1. Farmer Path Validation

### Setup
- Direct pawns to repeatedly complete FORAGE and HUNT jobs (10+ times)
- Ensure settlement has GROW intent

### Expected Outcomes
- [ ] `data.life_path` == `PawnData.LifePath.FARMER` (value 1)
- [ ] `data.life_path_contributions["farmer"]` >= 10
- [ ] `data.life_path_progress` increments on each aligned job
- [ ] Settlement intent remains GROW (or shifts to GROW if it wasn't)
- [ ] `settlement_intent_shift` event logged with `life_path_tally` showing farmer majority
- [ ] At milestone 10/25/50/100: `life_path_milestone` event recorded

### Verification Commands
```gdscript
# In Godot debugger or console:
for p in get_tree().get_nodes_in_group("pawns"):
    print("%s: life_path=%d, contributions=%s" % [p.data.display_name, p.data.life_path, p.data.life_path_contributions])
```

---

## 2. Soldier Path Validation

### Setup
- Set settlement to DEFEND intent (trigger war state or build walls/doors during mobilization)
- Direct pawns to complete BUILD_WALL, BUILD_DOOR, MINE, MINE_WALL jobs

### Expected Outcomes
- [ ] `data.life_path` == `PawnData.LifePath.SOLDIER` (value 2)
- [ ] `data.life_path_contributions["soldier"]` increases during DEFEND state
- [ ] Settlement intent stays DEFEND longer with soldier presence
- [ ] `life_path_milestone` events at thresholds
- [ ] Governance calculation shows soldier influence in defense decisions

### Verification
- Check `SettlementMemory._tally_settlement_life_paths()` returns soldier count > 0
- Verify `get_settlement_intent_for_tile()` returns "DEFEND" during soldier-heavy period

---

## 3. Wanderer Path Validation

### Setup
- Allow pawns to explore new regions (path to unvisited tiles)
- Assign CHOP, TRADE_PICKUP, TRADE_HAUL jobs

### Expected Outcomes
- [ ] `data.life_path` == `PawnData.LifePath.WANDERER` (value 4)
- [ ] `data.regions_visited.size()` increases with each new region
- [ ] `region_discovery` events logged for each new region
- [ ] `data.life_path_contributions["wanderer"]` includes both job and exploration credits
- [ ] Settlement in RECOVER state exits early if wanderer count >= 3

### Verification
```gdscript
# Check region discovery events:
var events = WorldMemory.get_events_by_type("region_discovery")
print("Total discoveries: ", events.size())
```

---

## 4. Ruler Path Validation

### Setup
- Single pawn completes mixed jobs that don't strongly favor other paths
- Monitor influence growth and governance emergence

### Expected Outcomes
- [ ] `data.life_path` == `PawnData.LifePath.RULER` (value 3)
- [ ] `data.influence` increases by +1.0 per ruler-path progression
- [ ] Governance profile shifts to "monarchy" with this pawn as `ruler_id`
- [ ] At milestone 25: `ruler_decision` event with `decision_type = "law_proposal"`
- [ ] At milestone 50: `ruler_decision` event with `decision_type = "policy_shift"`
- [ ] At milestone 100: `ruler_decision` event with `decision_type = "expansion_drive"`
- [ ] Settlement intent lock extended when ruler present

### Verification
```gdscript
# Check governance:
var gov = SettlementMemory.get_governance_profile_for_region(region_key)
print("Governance: %s, ruler_id: %d" % [gov["type"], gov["ruler_id"]])
```

---

## 5. Cross-Path Interaction Tests

### Path Switching
- [ ] When a pawn's contributions shift (e.g., farmer → soldier), `life_path_switch` event is recorded
- [ ] `data.life_path_progress` resets on switch
- [ ] Old path name and new path name logged in event

### Settlement Intent Shifts
- [ ] `settlement_intent_shift` events include `life_path_tally` dictionary
- [ ] Intent shifts align with dominant path predictions:
  - Farmer majority → GROW/HOARD
  - Soldier majority → DEFEND
  - Wanderer presence → faster RECOVER exit
  - Ruler presence → longer intent lock duration

### Save/Load Persistence
- [ ] After save and reload:
  - `data.life_path` matches pre-save value
  - `data.life_path_contributions` preserved
  - `data.regions_visited` preserved
  - `data.life_path_progress` and `data.life_path_total` match

---

## 6. Determinism Verification

### Seed Consistency
- [ ] Two runs with same seed produce identical:
  - Life-path assignments at tick N
  - Contribution counts at tick N
  - Settlement intent states at tick N

### No Randomness
- [ ] No `randi()` or `randf()` calls in life-path evaluation
- [ ] All outcomes driven by job completions and tile visits
- [ ] WorldRNG used only for personality generation (not life-paths)

---

## Pass/Fail Criteria
- All checkbox items must pass for the life-path system to be considered complete
- Any failure indicates a bug in the deterministic simulation loop
- Log output should contain `[Pawn]` entries for all life-path events when verbose mode is enabled
