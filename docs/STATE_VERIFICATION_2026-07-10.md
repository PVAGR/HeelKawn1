# HeelKawn Verification Snapshot — 2026-07-10

## Scope
- Close the family-inheritance documentation gap.
- Make bloodline reputation inheritance visible as an explicit world event.

## Environment Reality
- Godot binary is not available in this environment.
- Runtime smoke cannot be executed here.
- Validation is limited to static checks plus repository gates.

## Implemented In This Pass

1. Family reputation inheritance now records world history
- File: `scripts/pawn/HeelKawnianData.gd`
- Changed `inherit_reputation_from_bloodline(...)` so the inherited reputation delta now emits a factual `family_reputation_inherited` `WorldMemory` event.
- Event payload includes:
  - child pawn id,
  - bloodline id,
  - parent ids,
  - parent reputation values,
  - reputation delta,
  - tick.
- Effect:
  - The birth-line social carryover is now visible in the chronicle and audit trail instead of only mutating hidden pawn state.

2. Skill-tree branch effects are visible in the pawn inspection sheet
- File: `scripts/ui/PawnInfoPanel.gd`
- Added a dedicated `Skill branches` section under the identity tab.
- Each pawn now shows any chosen milestone branches plus their passive bonus summary during normal inspection play.

3. Repo docs synchronized with the code truth
- `TODO.md` now marks inheritance hooks as complete.
- `TODO.md` also marks skill branch effects and civilization-stage metrics as complete because they are already implemented in runtime code.
- `docs/BUILD_INVENTORY.md` now states that birth and kinship inheritance hooks are live.
- `docs/BUILD_INVENTORY.md` now reflects that civilization-stage deepening metrics are already implemented in code and only need runtime verification.
- `docs/HEELKAWN_STATE.md` now references this verification snapshot and the new world event.
- `docs/HEELKAWN_STATE.md` now notes the visible skill-branch summary and the live civilization-stage metrics.

## Verification
- Ran:
  ```bash
  bash tools/ai/sim-quality-gate.sh
  ```
- Result:
  - PASS
  - Runtime smoke skipped because the Godot binary is not installed in this environment.

## Determinism Notes
- No unseeded RNG was added.
- The new event is derived from existing bloodline-reputation state and the current simulation tick.
- The skill-branch UI is a read-only projection of already-existing deterministic branch state.
- No frame-time branching was introduced into canonical truth paths.

## Residual Risk
- The new event path is statically verified only here.
- Actual runtime visibility in the F10 chronicle / inspection UI still needs an in-Godot smoke pass on a machine with Godot installed.
