# HeelKawn Verification Snapshot — 2026-05-22

## Scope
- Add enforceable runtime quality contract for AI contributors.
- Wire deterministic + smoothness checks into CI.

## Repository Snapshot
- Branch: `main`
- Verification date: 2026-05-22 (UTC)
- `project.godot` main scene: `res://scenes/main/Main.tscn`

## Implemented In This Pass

1. Added repo agent contract
- File: `AGENTS.md`
- Result: future contributors now have explicit non-negotiable runtime requirements.

2. Added AI runtime mandate
- File: `docs/AI_RUNTIME_MANDATE.md`
- Result: defined deterministic/speed/stability contract and simulation definition-of-done.

3. Added simulation quality gate script
- File: `tools/ai/sim-quality-gate.sh`
- Result:
  - checks critical RNG usage in deterministic systems,
  - checks legacy world dimension usage in critical paths,
  - validates configured main scene,
  - runs headless smoke tests when Godot exists,
  - enforces `sim_performance_smoothness_smoke.gd` pass markers and `consistency=ok`.

4. Added CI enforcement
- File: `.github/workflows/sim-quality-gate.yml`
- Result: runs quality gate on push/PR for `main` and `develop`.

5. Determinism hardening in active catastrophe path
- File: `scripts/world/CataclysmSystem.gd`
- Result:
  - replaced global `randi()`/`randi_range()` cataclysm rolls with deterministic helpers,
  - deterministic region generation for affected areas,
  - deterministic earthquake/meteor damage rolls.

6. Wildlife world-dimension/pathing alignment
- File: `autoloads/WildlifePopulation.gd`
- Result:
  - world node lookup now uses `WorldViewport/World` with fallback,
  - replaced legacy `map_width/map_height` with canonical `WorldData.WIDTH/HEIGHT`.

## Local Verification In This Environment
- Command run: `bash tools/ai/sim-quality-gate.sh`
- Result: pass (Godot binary unavailable here, so runtime smoke is skipped by design in local environment).

## Residual Risk
- Full runtime smoke evidence depends on CI runner or local machine with Godot installed.
