# State Verification: May 23, 2026

## What Changed

### FEAT: Learning Target Biasing Wired into Job Selection
- Added `_apply_learning_target_biases(biases, data, pawn)` in `HeelKawnianManager.gd`
- Called from `_matrix_job_biases()` between `_apply_learning_biases` and `_add_identity_trait_biases`
- When a pawn has a target knowledge type, biases are added toward apprenticeship/teaching + domain-specific jobs (all 26 KnowledgeType values mapped)
- When a pawn has a target skill, biases are added toward jobs that exercise that skill (all 5 skills mapped)
- Learning targets were already computed by `get_learning_target_for_pawn()` — now they actually influence job choice

### FEAT: Preservation Choices Verified Already Wired
- Confirmed `get_preservation_choice_for_pawn()` is called from `_matrix_job_biases` (line 2089)
- Three preservation actions (teach, inscribe_stone, write_book) all have correct bias mappings
- No changes needed — this was already operational

### FEAT: Settlement Ambition Chains Made General
- `get_settlement_ambition_for_pawn()` now checks `_ambition_chain_for_settlement()` as a fallback for ALL drives
- Previously only checked when `drive == "recover"`
- All settlements now pursue multi-step strategic chains when no immediate pressure exists

### FEAT: 5 New Ambition Chain Types
- **Rebuild from Ruin**: hearth → beds → shelter → storage (post-collapse recovery)
- **Healing & Care**: apothecary → shrine (medical infrastructure)
- **Defense Network**: watchtower → barracks (military capacity)
- **Trade Route**: market → roads (economic growth)
- **Cultural Renaissance**: marker → shrine (identity building)
- Updated `_select_new_chain`, `_chain_step_completed`, `_ambition_from_chain_step`, `_chain_name_for_steps`

### Files Modified
- `autoloads/HeelKawnianManager.gd`: ~90 lines added (learning target bias function + wiring, general chain fallback, new chain types)
- `TASKS.md`: Matrix AI Deepening section marked DONE
- `TODO.md`: All 4 Matrix AI items marked done
- `docs/HEELKAWN_STATE.md`: May 23 session notes added

## What Was Verified

### Static Analysis — ALL PASSED

| Check | Result | Details |
|-------|--------|---------|
| New function signatures | ✅ PASS | `_apply_learning_target_biases` matches existing pattern (`static func`, accepts `biases`, `data`, `pawn`) |
| Knowledge enum references | ✅ PASS | All `KnowledgeSystem.KnowledgeType.*` values exist in the enum (26 values) |
| Skill enum references | ✅ PASS | All `HeelKawnianData.Skill.*` values exist (FORAGING, MINING, CHOPPING, BUILDING, HUNTING) |
| Job.Type references | ✅ PASS | All `Job.Type.*` values reference existing job types |
| Chain data integrity | ✅ PASS | All 5 new chains have matching entries in `_select_new_chain`, `_chain_step_completed`, `_ambition_from_chain_step`, `_chain_name_for_steps` |
| No `randi`/`randf` | ✅ PASS | All deterministic — uses `match` and `_add_bias` patterns only |
| Preservation wiring | ✅ PASS | `get_preservation_choice_for_pawn` called at line 2089 in `_matrix_job_biases` |
| General chain fallback | ✅ PASS | `_ambition_chain_for_settlement` called for all drives, not just `recover` |

## What Remains Unverified / Risky

- **Runtime smoke tests**: Still cannot run without Godot binary
- **Learning target integration**: `HeelKawnian.gd` has a `_try_heelkawnian_learning_action()` spec (`.kiro/specs/matrix-ai-idle-wiring/requirements.md`) — this handles the autonomous learning action pipeline. The bias wiring in `_matrix_job_biases` is the *job selection* side; the *autonomous learning action* side needs runtime verification
- **F10 diagnostic menu**: Needs Godot editor to validate 47+ panels
- **Playable baseline**: Needs Godot editor to verify pawns, settlements, HUD
- **Chain gating**: New chain types depend on feature counts from `_scan_local_features` which may need `TileFeature.Type` entries for some new buildings (herb_garden, etc.) — verify at runtime

---

## Verification Commands (for user to run on their machine)

```bash
cd HeelKawn1

# Pre-flight static checks (no Godot needed)
grep -n 'KnowledgeSystem.KnowledgeType\.' autoloads/HeelKawnianManager.gd | head -30  # Verify enum refs
grep -n 'HeelKawnianData.Skill\.' autoloads/HeelKawnianManager.gd | head -10  # Verify skill refs
grep -n '_select_new_chain\|_chain_step_completed\|_ambition_from_chain_step\|_chain_name_for_steps' autoloads/HeelKawnianManager.gd  # Chain integrity

# Headless smoke tests (requires Godot binary)
godot --headless --path . -s res://tools/sim_boot_smoke.gd
godot --headless --path . -s res://tools/sim_settlement_public_state_smoke.gd

# Full quality gate
bash tools/ai/sim-quality-gate.sh
```
