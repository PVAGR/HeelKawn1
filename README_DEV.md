# HEELKAWN Dev Run Guide

Quick notes to help run diagnostics and understand runtime state during development.

Dev UI
- `DevDebugUI` is autoloaded in `project.godot` and shows on-screen buttons when you run the project:
  - Start Monitor: starts `TickMonitor` diagnostic
  - Stop Monitor: stops it
  - Dump Tickables: prints nodes in group `tickable`
  - Dump Pawns: prints nodes in group `pawns` with positions
  - Count Moving Pawns: counts pawns that moved since last press

Manual TickMonitor (optional)
In the Remote Console or a script you can also control the monitor directly:

```gdscript
var m = TickMonitor.new()
get_tree().root.add_child(m)
m.monitor_start(1.0)
```

Collecting playtest logs
- Press F10 or run in the editor and open the `Output`/`Debugger` panel. Copy TickMonitor lines like:
  - `[TickMonitor] tick=123 tickables=NN pawns=26 moving=MM`

If something is broken, paste the debugger output here and I'll triage the specific systems (ticks, pawn AI, movement interpolation, LOD checks).
