# Observer Cleanup Decisions Log

This log records cleanup decisions made from observer-run evidence.

## Session Evidence

- `logs/observer/observer_1777449742.md`
- `logs/observer/observer_1777449981.md`

Both sessions ended with `summary_end failures=0` under worker-mode observer runs.

## Keep

- `autoloads/GameManager.gd`
  - Added explicit worker/benchmark toggles used by observer harness.
- `scripts/system/speed_benchmark_runner.gd`
  - Core observer harness with timeline + canon guards + report generation.
- `tools/Benchmark-Speeds.ps1`
  - Stable entrypoint for observer runs.

## Disable by Default (De-clutter)

- `autoloads/AIAgentManager.gd`
  - `enabled=false` and `civilization_mode=false` by default for runtime stability.
- `scenes/main/Main.gd`
  - `ENABLE_AI_CONTROL_PANEL=false` to avoid non-essential panel noise and scene warnings in default path.

## Defer

- `scripts/ui/AIControlPanel.gd`
  - Kept for future tooling work, but not enabled in default simulation path.

## Notes

- Cleanup actions are deterministic-safe and do not introduce RNG behavior.
- Observer workflow remains focused on kernel/state validation rather than optional UI tooling.
