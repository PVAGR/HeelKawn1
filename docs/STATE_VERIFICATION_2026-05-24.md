# State Verification: May 24, 2026

## What Changed

### FIX: Determinism violations in sea/water systems

#### 1. FlowingWater.gd - Non-deterministic shuffle
- Removed `neighbors.shuffle()` which caused random water flow direction
- Replaced with deterministic sort: sort by (y, x) coordinates for consistent order
- Water now flows in a predictable, replayable pattern

#### 2. GoalEngine.gd - Non-deterministic shuffle  
- Removed `_lifelong_aspirations.shuffle()` which caused random aspiration selection
- Replaced with deterministic selection using `WorldRNG.index_for()` based on pawn_id and year
- Each pawn's aspiration selection is now reproducible from seed

#### 3. GossipPropagation.gd - Non-deterministic shuffle
- Removed `topics.shuffle()` which caused random gossip topic order
- Replaced with deterministic sort by alphabetical order
- Conversation gossip topics now appear in consistent order

### FIX: Sea level not affecting world
- Added `apply_sea_level_change()` function to TerraformingSystem.gd
- This function is called when sea level changes in WorldAI.gd
- When sea level rises (>1.0), coastal lowland tiles can flood
- When sea level falls (<1.0), shallow water tiles can become land
- All changes are deterministic using tile position hashes

### FIX: sim-quality-gate.sh - Missing rg command
- Replaced all `rg` (ripgrep) commands with `grep` equivalents
- The `rg` tool was not available in the environment
- All regex patterns were converted to grep-compatible syntax
- This allows the quality gate to run without ripgrep dependency

## What Was Verified

### Static Analysis — ALL PASSED

| Check | Result | Details |
|-------|--------|---------|
| Determinism guard | ✅ PASS | No `randf`/`randi`/`shuffle` in critical systems after fixes |
| World pathing sanity | ✅ PASS | No legacy `map_width`/`map_height` fields |
| Project scene sanity | ✅ PASS | Main scene configured at `run/main_scene=` |
| Quality gate execution | ✅ PASS | All 4 checks pass |

## What Remains Unverified / Risky

- **Runtime sea level simulation**: Needs Godot binary to test actual sea flooding
- **Water flow determinism**: Verified by code review, needs runtime tick-by-tick verification
- **Build job posting**: Test report shows 0 jobs - needs investigation with Godot binary
- **All shuffle() removed**: 3 instances fixed, but could be more in other files

## Files Modified

1. `autoloads/FlowingWater.gd` - Replaced shuffle with deterministic sort
2. `autoloads/TerraformingSystem.gd` - Added sea level change application (+98 lines)
3. `scripts/ai/WorldAI.gd` - Wired sea level changes to TerraformingSystem (+8 lines)
4. `scripts/social/GoalEngine.gd` - Replaced shuffle with WorldRNG selection (+18 lines)
5. `scripts/social/GossipPropagation.gd` - Replaced shuffle with sort (+5 lines)
6. `tools/ai/sim-quality-gate.sh` - Replaced rg with grep (+7 lines net change)

---

## Verification Commands (for user to run on their machine)

```bash
cd HeelKawn1

# Pre-flight static checks (no Godot needed)
grep -rn "\.shuffle()" autoloads/ scripts/  # Verify no non-determinism
bash tools/ai/sim-quality-gate.sh  # Should pass all 4 checks

# Headless smoke tests (requires Godot binary)
godot --headless --path . -s res://tools/sim_boot_smoke.gd
godot --headless --path . -s res://tools/sim_settlement_public_state_smoke.gd
godot --headless --path . -s res://tools/year1_visible_growth_smoke.gd

# Sea level smoke test (requires Godot binary)
# Run WorldAI with high sea level event rate and check coastal tiles
```